-- ============================================================================
-- Migración: Blindaje anti-duplicados de órdenes de trabajo por activo
-- Fecha: 2026-10-20
-- Autor: Antigravity / Nixon
-- Probado en DEV: [X] Sí  [ ] No
-- Aplicado en PROD: [ ] Sí  [ ] No  Fecha: ____
-- ============================================================================
-- DESCRIPCIÓN:
--   Actualiza el procedimiento almacenado dbo.uspOrdenTrabajoCrear para validar
--   que un activo no posea órdenes de trabajo abiertas (estados 'pending',
--   'inProgress', 'in_progress', 'paused') antes de permitir registrar una nueva OT.
--   Esto impide duplicación operativa y garantiza el flujo de mantenimiento.
-- ============================================================================

USE [MacsaCMMS]; -- En producción puede ser [bdMacsaCMMS] o [MacsaCMMS_DEV], ajustar según entorno
GO

PRINT '============================================================================';
PRINT 'Iniciando migración: Blindaje anti-duplicados de OTs por activo...';
PRINT '============================================================================';
GO

-- 1. Actualización del Procedimiento Almacenado
CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoCrear
    @AssetCode NVARCHAR(60) = N'', @AssetName NVARCHAR(200),
    @AreaId NVARCHAR(15) = NULL, @AreaName NVARCHAR(200) = NULL,
    @Description NVARCHAR(MAX), @Priority NVARCHAR(10) = N'medium',
    @AssignedTo NVARCHAR(200) = NULL, @AssignedStaffCount INT = NULL,
    @EstimatedHours DECIMAL(6,2) = NULL,
    @ScheduledDate DATETIME2(3) = NULL, @ReportId BIGINT = NULL,
    @CreatedByUserId INT = NULL, @CreatedByUserName NVARCHAR(100) = N'',
    @Materials dbo.TipoMaterialOrdenTrabajo READONLY,
    @WorkTypes dbo.TipoListaTexto READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar si el activo ya cuenta con una orden de trabajo abierta
        IF NULLIF(@AssetCode, '') IS NOT NULL
        BEGIN
            DECLARE @OTExistenteId NVARCHAR(20);
            SELECT TOP 1 @OTExistenteId = OrdenTrabajoId
              FROM dbo.OrdenTrabajo WITH (UPDLOCK, HOLDLOCK)
             WHERE CodigoActivo = @AssetCode
               AND Estado IN (N'pending', N'inProgress', N'in_progress', N'paused');

            IF @OTExistenteId IS NOT NULL
            BEGIN
                DECLARE @MsgOT NVARCHAR(250) = CONCAT(N'El activo ', @AssetCode, N' ya cuenta con una orden de trabajo abierta (', @OTExistenteId, N'). Debe concluirse o cancelarse antes de emitir una nueva.');
                RAISERROR(@MsgOT, 16, 1);
            END;
        END;

        DECLARE @cCount TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT deleted.SiguienteNumero INTO @cCount(v)
          WHERE Nombre = 'work_orders';

        DECLARE @seq INT; SELECT @seq = v FROM @cCount;
        DECLARE @woId NVARCHAR(20) = CONCAT('OT-', YEAR(SYSUTCDATETIME()), '-', FORMAT(@seq, '0000'));

        INSERT INTO dbo.OrdenTrabajo
            (OrdenTrabajoId, CodigoActivo, NombreActivo, AreaId, NombreArea, Descripcion,
             Estado, Prioridad, AsignadoA, CantidadPersonalAsignado, HorasEstimadas,
             FechaProgramada, ReporteId, CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn)
        VALUES
            (@woId, NULLIF(@AssetCode, ''), @AssetName, @AreaId, @AreaName, @Description,
             'pending', @Priority, @AssignedTo, @AssignedStaffCount, @EstimatedHours,
             @ScheduledDate, @ReportId, @CreatedByUserId, @CreatedByUserName, SYSUTCDATETIME());

        INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
        SELECT @woId, ROW_NUMBER() OVER (ORDER BY NumeroLinea), Descripcion, Cantidad, ISNULL(Unidad, 'pz')
          FROM @Materials;

        INSERT INTO dbo.TipoTrabajoOrdenTrabajo (OrdenTrabajoId, TipoTrabajo)
        SELECT DISTINCT @woId, LTRIM(RTRIM(Valor)) FROM @WorkTypes WHERE LTRIM(RTRIM(Valor)) <> '';

        IF @ReportId IS NOT NULL
        BEGIN
            UPDATE dbo.ReporteAveria SET Estado = 'inWorkOrder', OrdenTrabajoId = @woId WHERE ReporteId = @ReportId;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreatedByUserId, @CreatedByUserName, 'WORK_ORDER_CREATED', 'WORK_ORDERS', @woId,
                CONCAT(N'Orden de trabajo ', @woId, N' creada para ', @AssetName, N'.'));

        COMMIT TRANSACTION;
        SELECT @woId AS WorkOrderNumber, @woId AS NewWorkOrderId, @woId AS OrdenTrabajoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 2. Permisos para la aplicación
GRANT EXECUTE ON dbo.uspOrdenTrabajoCrear TO macsa_app;
GO

-- 3. Verificación post-migración
SELECT 'Verificación:' AS Info,
       ROUTINE_NAME,
       LAST_ALTERED
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_NAME = 'uspOrdenTrabajoCrear' AND ROUTINE_TYPE = 'PROCEDURE';
GO

PRINT '🏁 Migración [2026-10-20_blindaje_ot_abierta_activo.sql] completada exitosamente.';
GO
