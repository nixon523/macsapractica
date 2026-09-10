/* ============================================================================
   MACSA CMMS - Grupo Macsa
   database/fase3_averias_ots_correctivas.sql
   Fase 3: Circuito Completo de Averías, OTs Correctivas y Trazabilidad Kardex
   - Flexibilización de Tipos de Trabajo (Español / Inglés / Tipos Industriales)
   - Procedimiento Robusto de Creación y Sincronización de OTs y Averías
   - Procedimiento de Actualización de Estado con Cierre Automático y Bitácora
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ============================================================================
-- 1. Flexibilizar constraint de tipos de trabajo en OrdenTrabajo
-- ============================================================================
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_TTOT_Tipo')
BEGIN
    ALTER TABLE dbo.TipoTrabajoOrdenTrabajo DROP CONSTRAINT CK_TTOT_Tipo;
END;
GO

-- Permitir tipos de trabajo comunes en español, inglés o texto descriptivo no vacío
ALTER TABLE dbo.TipoTrabajoOrdenTrabajo WITH CHECK
ADD CONSTRAINT CK_TTOT_Tipo CHECK (LEN(LTRIM(RTRIM(TipoTrabajo))) > 0);
GO

-- ============================================================================
-- 2. Asegurar estado y sincronización de OTs y Reportes de Avería
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoActualizarEstado
    @WorkOrderId NVARCHAR(20),
    @NewStatus   NVARCHAR(15),
    @UserId      INT = NULL,
    @UserName    NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @cur NVARCHAR(15), @rid BIGINT, @assetCode NVARCHAR(60);
        SELECT @cur = Estado, @rid = ReporteId, @assetCode = CodigoActivo
          FROM dbo.OrdenTrabajo WITH (UPDLOCK, HOLDLOCK)
         WHERE OrdenTrabajoId = @WorkOrderId;

        IF @cur IS NULL
            RAISERROR(N'La orden de trabajo no existe.', 16, 1);

        -- Actualizar estado de la OT
        UPDATE dbo.OrdenTrabajo 
           SET Estado = @NewStatus 
         WHERE OrdenTrabajoId = @WorkOrderId;

        -- Sincronizar reporte de avería si nació de uno
        IF @NewStatus = 'completed' AND @rid IS NOT NULL
        BEGIN
            UPDATE dbo.ReporteAveria 
               SET Estado = 'resolved', 
                   ResueltoPorUsuarioId = @UserId, 
                   ResueltoPorNombreUsuario = @UserName, 
                   ResueltoEn = SYSUTCDATETIME() 
             WHERE ReporteId = @rid;

            INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
            VALUES (@UserId, @UserName, 'BREAKDOWN_RESOLVED', 'BREAKDOWNS', CAST(@rid AS NVARCHAR(30)),
                    CONCAT(N'Avería #', @rid, N' resuelta automáticamente por cierre de la OT ', @WorkOrderId, N'.'));
        END
        ELSE IF @NewStatus = 'cancelled' AND @rid IS NOT NULL
        BEGIN
            UPDATE dbo.ReporteAveria 
               SET Estado = 'reported', 
                   OrdenTrabajoId = NULL 
             WHERE ReporteId = @rid;

            INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
            VALUES (@UserId, @UserName, 'BREAKDOWN_UNLINKED', 'BREAKDOWNS', CAST(@rid AS NVARCHAR(30)),
                    CONCAT(N'Avería #', @rid, N' liberada a estado "reported" por cancelación de la OT ', @WorkOrderId, N'.'));
        END;

        -- Sincronizar plan preventivo si fue generada de un plan
        IF @NewStatus = 'completed'
        BEGIN
            UPDATE dbo.PlanPreventivo
               SET UltimaCompletada = SYSUTCDATETIME()
             WHERE UltimaOrdenTrabajoId = @WorkOrderId;
        END;

        -- Registrar cambio de estado en Kardex
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'WORK_ORDER_STATUS_CHANGED', 'WORK_ORDERS', @WorkOrderId,
                CONCAT(N'OT ', @WorkOrderId, N': estado cambiado de "', @cur, N'" a "', @NewStatus, N'".'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT N'Fase 3: Procedimientos y validaciones de Averías y OTs Correctivas aplicados exitosamente.';
GO
