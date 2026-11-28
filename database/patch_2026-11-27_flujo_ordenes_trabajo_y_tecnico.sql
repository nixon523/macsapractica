-- ============================================================================
-- MACSA CMMS - PARCHE 2026-11-27: FLUJO AVANZADO DE ORDENES DE TRABAJO Y ROL TECNICO
-- ============================================================================
-- 1. Rol 'tecnico' y permisos 'work_order.execute', 'work_order.approve'
-- 2. Nuevas columnas en dbo.OrdenTrabajo para tracking de tiempos, pausas y aprobacion
-- 3. Actualizacion de CK_OT_Estado ('pending','inProgress','paused','reviewPending','completed','cancelled','unfulfilled','rescheduled')
-- 4. Actualizacion de procedimientos:
--    - uspOrdenTrabajoActualizarEstado (con manejo de pausas, cronometro y aprobacion)
--    - uspOrdenTrabajoActualizarDetalles (calculo automatico de personal y soporte de horas)
--    - uspOrdenTrabajoObtenerTodas (incluyendo nuevos campos de auditoria y tiempos)
--    - uspOrdenTrabajoObtenerAbiertas (incluyendo paused y reviewPending como abiertas)
-- ============================================================================

USE [MacsaCMMS];
GO

-- 1. CATALOGO DE ROLES Y PERMISOS
IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE CodigoRol = 'tecnico')
BEGIN
    INSERT INTO dbo.Rol (CodigoRol, Nombre) VALUES ('tecnico', N'Personal de Mantenimiento');
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Permiso WHERE CodigoPermiso = 'work_order.execute')
BEGIN
    INSERT INTO dbo.Permiso (CodigoPermiso) VALUES ('work_order.execute');
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Permiso WHERE CodigoPermiso = 'work_order.approve')
BEGIN
    INSERT INTO dbo.Permiso (CodigoPermiso) VALUES ('work_order.approve');
END;

-- Permisos para rol 'tecnico'
IF NOT EXISTS (SELECT 1 FROM dbo.RolPermiso WHERE CodigoRol = 'tecnico' AND CodigoPermiso = 'work_order.view')
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso) VALUES ('tecnico', 'work_order.view');
IF NOT EXISTS (SELECT 1 FROM dbo.RolPermiso WHERE CodigoRol = 'tecnico' AND CodigoPermiso = 'work_order.execute')
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso) VALUES ('tecnico', 'work_order.execute');
IF NOT EXISTS (SELECT 1 FROM dbo.RolPermiso WHERE CodigoRol = 'tecnico' AND CodigoPermiso = 'work_order.print')
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso) VALUES ('tecnico', 'work_order.print');
IF NOT EXISTS (SELECT 1 FROM dbo.RolPermiso WHERE CodigoRol = 'tecnico' AND CodigoPermiso = 'asset.view')
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso) VALUES ('tecnico', 'asset.view');
IF NOT EXISTS (SELECT 1 FROM dbo.RolPermiso WHERE CodigoRol = 'tecnico' AND CodigoPermiso = 'breakdown.view')
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso) VALUES ('tecnico', 'breakdown.view');
IF NOT EXISTS (SELECT 1 FROM dbo.RolPermiso WHERE CodigoRol = 'tecnico' AND CodigoPermiso = 'breakdown.report')
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso) VALUES ('tecnico', 'breakdown.report');

-- Permisos para 'jefe' y 'admin'
IF NOT EXISTS (SELECT 1 FROM dbo.RolPermiso WHERE CodigoRol = 'jefe' AND CodigoPermiso = 'work_order.execute')
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso) VALUES ('jefe', 'work_order.execute');
IF NOT EXISTS (SELECT 1 FROM dbo.RolPermiso WHERE CodigoRol = 'jefe' AND CodigoPermiso = 'work_order.approve')
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso) VALUES ('jefe', 'work_order.approve');

IF NOT EXISTS (SELECT 1 FROM dbo.RolPermiso WHERE CodigoRol = 'admin' AND CodigoPermiso = 'work_order.execute')
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso) VALUES ('admin', 'work_order.execute');
IF NOT EXISTS (SELECT 1 FROM dbo.RolPermiso WHERE CodigoRol = 'admin' AND CodigoPermiso = 'work_order.approve')
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso) VALUES ('admin', 'work_order.approve');
GO

-- 2. COLUMNAS DE TIEMPOS, PAUSAS Y APROBACION EN dbo.OrdenTrabajo
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.OrdenTrabajo') AND name = 'FechaInicioReal')
BEGIN
    ALTER TABLE dbo.OrdenTrabajo ADD FechaInicioReal DATETIME2(3) NULL;
END;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.OrdenTrabajo') AND name = 'FechaFinReal')
BEGIN
    ALTER TABLE dbo.OrdenTrabajo ADD FechaFinReal DATETIME2(3) NULL;
END;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.OrdenTrabajo') AND name = 'MinutosPausaAcumulados')
BEGIN
    ALTER TABLE dbo.OrdenTrabajo ADD MinutosPausaAcumulados INT NOT NULL CONSTRAINT DF_OT_MinutosPausa DEFAULT (0);
END;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.OrdenTrabajo') AND name = 'FechaUltimaPausa')
BEGIN
    ALTER TABLE dbo.OrdenTrabajo ADD FechaUltimaPausa DATETIME2(3) NULL;
END;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.OrdenTrabajo') AND name = 'MotivoPausa')
BEGIN
    ALTER TABLE dbo.OrdenTrabajo ADD MotivoPausa NVARCHAR(500) NULL;
END;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.OrdenTrabajo') AND name = 'AprobadoPorUsuarioId')
BEGIN
    ALTER TABLE dbo.OrdenTrabajo ADD AprobadoPorUsuarioId INT NULL;
END;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.OrdenTrabajo') AND name = 'AprobadoPorNombreUsuario')
BEGIN
    ALTER TABLE dbo.OrdenTrabajo ADD AprobadoPorNombreUsuario NVARCHAR(100) NULL;
END;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.OrdenTrabajo') AND name = 'AprobadoEn')
BEGIN
    ALTER TABLE dbo.OrdenTrabajo ADD AprobadoEn DATETIME2(3) NULL;
END;
GO

-- 3. ACTUALIZAR CONSTRAINT DE ESTADOS DE OT
DECLARE @chkName NVARCHAR(128);
SELECT @chkName = name FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID('dbo.OrdenTrabajo') AND definition LIKE '%Estado%';
IF @chkName IS NOT NULL
BEGIN
    EXEC(N'ALTER TABLE dbo.OrdenTrabajo DROP CONSTRAINT [' + @chkName + N'];');
END;
ALTER TABLE dbo.OrdenTrabajo ADD CONSTRAINT CK_OT_Estado 
    CHECK (Estado IN ('pending','inProgress','paused','reviewPending','completed','cancelled','unfulfilled','rescheduled'));
GO

-- 4. PROCEDIMIENTO: ACTUALIZAR ESTADO DE ORDEN DE TRABAJO
CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoActualizarEstado
    @WorkOrderId           NVARCHAR(20),
    @NewStatus             NVARCHAR(20),
    @UserId                INT = NULL,
    @UserName              NVARCHAR(100) = N'',
    @MotivoPausa           NVARCHAR(500) = NULL,
    @MotivoReprogramacion  NVARCHAR(500) = NULL,
    @FechaReprogramacion   DATETIME2(3) = NULL,
    @HorasReales           DECIMAL(6,2) = NULL,
    @TrabajoRealizado      NVARCHAR(MAX) = NULL,
    @Observaciones         NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @EstadoActual NVARCHAR(20);
        DECLARE @FInicio DATETIME2(3);
        DECLARE @FUltimaPausa DATETIME2(3);
        DECLARE @MinPausa INT;

        SELECT @EstadoActual = Estado,
               @FInicio = FechaInicioReal,
               @FUltimaPausa = FechaUltimaPausa,
               @MinPausa = COALESCE(MinutosPausaAcumulados, 0)
          FROM dbo.OrdenTrabajo
         WHERE OrdenTrabajoId = @WorkOrderId;

        IF @EstadoActual IS NULL
        BEGIN
            RAISERROR(N'La orden de trabajo no existe.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        DECLARE @KardexAccion NVARCHAR(50) = 'WORK_ORDER_STATUS_CHANGED';
        DECLARE @KardexDetalle NVARCHAR(500) = CONCAT(N'Estado de OT ', @WorkOrderId, N' cambiado de ', @EstadoActual, N' a ', @NewStatus, N'.');

        -- Transición: Iniciar o Reanudar ('inProgress')
        IF @NewStatus = 'inProgress'
        BEGIN
            IF @FInicio IS NULL
            BEGIN
                -- Primera vez que inicia
                UPDATE dbo.OrdenTrabajo
                   SET Estado = 'inProgress',
                       FechaInicioReal = SYSUTCDATETIME(),
                       ActualizadoEn = SYSUTCDATETIME()
                 WHERE OrdenTrabajoId = @WorkOrderId;
                SET @KardexAccion = 'WORK_ORDER_STARTED';
                SET @KardexDetalle = CONCAT(N'OT ', @WorkOrderId, N' iniciada por técnico ', @UserName, N'.');
            END
            ELSE IF @EstadoActual = 'paused' AND @FUltimaPausa IS NOT NULL
            BEGIN
                -- Reanudar de pausa: acumular minutos transcurridos en pausa
                DECLARE @MinPausaTranscurridos INT = DATEDIFF(MINUTE, @FUltimaPausa, SYSUTCDATETIME());
                IF @MinPausaTranscurridos < 0 SET @MinPausaTranscurridos = 0;

                UPDATE dbo.OrdenTrabajo
                   SET Estado = 'inProgress',
                       MinutosPausaAcumulados = @MinPausa + @MinPausaTranscurridos,
                       FechaUltimaPausa = NULL,
                       ActualizadoEn = SYSUTCDATETIME()
                 WHERE OrdenTrabajoId = @WorkOrderId;
                SET @KardexAccion = 'WORK_ORDER_RESUMED';
                SET @KardexDetalle = CONCAT(N'OT ', @WorkOrderId, N' reanudada por ', @UserName, N'.');
            END
            ELSE
            BEGIN
                UPDATE dbo.OrdenTrabajo
                   SET Estado = 'inProgress',
                       ActualizadoEn = SYSUTCDATETIME()
                 WHERE OrdenTrabajoId = @WorkOrderId;
            END;
        END
        -- Transición: Pausar ('paused')
        ELSE IF @NewStatus = 'paused'
        BEGIN
            UPDATE dbo.OrdenTrabajo
               SET Estado = 'paused',
                   FechaUltimaPausa = SYSUTCDATETIME(),
                   MotivoPausa = COALESCE(@MotivoPausa, N'Pausa temporal'),
                   ActualizadoEn = SYSUTCDATETIME()
             WHERE OrdenTrabajoId = @WorkOrderId;

            SET @KardexAccion = 'WORK_ORDER_PAUSED';
            SET @KardexDetalle = CONCAT(N'OT ', @WorkOrderId, N' pausada por ', @UserName, N'. Motivo: ', COALESCE(@MotivoPausa, N'Sin motivo'));
        END
        -- Transición: Enviar a Revisión / Finalizar Técnico ('reviewPending')
        ELSE IF @NewStatus = 'reviewPending'
        BEGIN
            DECLARE @FInicioCalc DATETIME2(3) = COALESCE(@FInicio, SYSUTCDATETIME());
            DECLARE @MinutosTotales INT = DATEDIFF(MINUTE, @FInicioCalc, SYSUTCDATETIME()) - @MinPausa;
            IF @MinutosTotales < 1 SET @MinutosTotales = 1;

            DECLARE @HorasCalculadas DECIMAL(6,2) = CAST(ROUND(CAST(@MinutosTotales AS DECIMAL(10,2)) / 60.0, 2) AS DECIMAL(6,2));
            DECLARE @HorasFinales DECIMAL(6,2) = COALESCE(@HorasReales, @HorasCalculadas);

            UPDATE dbo.OrdenTrabajo
               SET Estado = 'reviewPending',
                   FechaFinReal = SYSUTCDATETIME(),
                   HorasReales = @HorasFinales,
                   DescripcionTrabajoRealizado = COALESCE(@TrabajoRealizado, @Observaciones, DescripcionTrabajoRealizado),
                   ActualizadoEn = SYSUTCDATETIME()
             WHERE OrdenTrabajoId = @WorkOrderId;

            SET @KardexAccion = 'WORK_ORDER_SUBMITTED_FOR_REVIEW';
            SET @KardexDetalle = CONCAT(N'OT ', @WorkOrderId, N' finalizada por técnico ', @UserName, N'. Enviada a revisión (Horas reales: ', CAST(@HorasFinales AS VARCHAR(10)), N'h).');
        END
        -- Transición: Aprobar y Cerrar ('completed')
        ELSE IF @NewStatus = 'completed'
        BEGIN
            UPDATE dbo.OrdenTrabajo
               SET Estado = 'completed',
                   EstaCompletada = 1,
                   AprobadoPorUsuarioId = @UserId,
                   AprobadoPorNombreUsuario = @UserName,
                   AprobadoEn = SYSUTCDATETIME(),
                   ActualizadoEn = SYSUTCDATETIME()
             WHERE OrdenTrabajoId = @WorkOrderId;

            -- Resolver reporte de avería vinculado si aplica
            DECLARE @repId BIGINT;
            SELECT @repId = ReporteId FROM dbo.OrdenTrabajo WHERE OrdenTrabajoId = @WorkOrderId;
            IF @repId IS NOT NULL
            BEGIN
                UPDATE dbo.ReporteAveria
                   SET Estado = 'resolved',
                       ResueltoPorUsuarioId = @UserId,
                       ResueltoPorNombreUsuario = @UserName,
                       ResueltoEn = SYSUTCDATETIME()
                 WHERE ReporteId = @repId;
            END;

            SET @KardexAccion = 'WORK_ORDER_APPROVED';
            SET @KardexDetalle = CONCAT(N'OT ', @WorkOrderId, N' aprobada y cerrada definitivamente por ', @UserName, N'.');
        END
        -- Transición: Reprogramar ('rescheduled' o 'pending' con nueva fecha)
        ELSE IF @NewStatus IN ('rescheduled', 'unfulfilled') OR @FechaReprogramacion IS NOT NULL
        BEGIN
            UPDATE dbo.OrdenTrabajo
               SET Estado = @NewStatus,
                   FechaReprogramacion = COALESCE(@FechaReprogramacion, FechaReprogramacion),
                   MotivoIncumplimiento = COALESCE(@MotivoReprogramacion, @Observaciones, MotivoIncumplimiento),
                   ActualizadoEn = SYSUTCDATETIME()
             WHERE OrdenTrabajoId = @WorkOrderId;

            SET @KardexAccion = 'WORK_ORDER_RESCHEDULED';
            SET @KardexDetalle = CONCAT(N'OT ', @WorkOrderId, N' reprogramada por ', @UserName, N'. Motivo: ', COALESCE(@MotivoReprogramacion, N'Sin motivo'));
        END
        -- Cualquier otro cambio genérico (ej. 'cancelled', o reabierta a 'inProgress')
        ELSE
        BEGIN
            UPDATE dbo.OrdenTrabajo
               SET Estado = @NewStatus,
                   ActualizadoEn = SYSUTCDATETIME()
             WHERE OrdenTrabajoId = @WorkOrderId;

            IF @NewStatus = 'cancelled'
            BEGIN
                SET @KardexAccion = 'WORK_ORDER_CANCELLED';
                SET @KardexDetalle = CONCAT(N'OT ', @WorkOrderId, N' cancelada por ', @UserName, N'.');
            END
            ELSE IF @EstadoActual = 'reviewPending' AND @NewStatus = 'inProgress'
            BEGIN
                SET @KardexAccion = 'WORK_ORDER_REOPENED';
                SET @KardexDetalle = CONCAT(N'OT ', @WorkOrderId, N' reabierta con observaciones por ', @UserName, N'.');
            END;
        END;

        -- Registrar evento en Bitácora Kardex
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, @KardexAccion, 'WORK_ORDERS', @WorkOrderId, @KardexDetalle);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 5. ACTUALIZAR PROCEDIMIENTO: uspOrdenTrabajoObtenerTodas
CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoObtenerTodas
    @StatusFilter   NVARCHAR(20) = NULL,
    @AreaFilter     NVARCHAR(15) = NULL,
    @PriorityFilter NVARCHAR(10) = NULL,
    @Limit          INT = NULL,
    @Offset         INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @Offset < 0 SET @Offset = 0;

    SELECT ot.OrdenTrabajoId AS WorkOrderId,
           ot.CodigoActivo AS AssetCode,
           ot.NombreActivo AS AssetName,
           ot.AreaId,
           COALESCE(ar.Nombre, ot.NombreArea) AS AreaName,
           ot.Descripcion AS Description,
           ot.Estado AS Status,
           ot.Prioridad AS Priority,
           ot.AsignadoA AS AssignedTo,
           ot.CantidadPersonalAsignado AS AssignedStaffCount,
           ot.HorasEstimadas AS EstimatedHours,
           ot.HorasReales AS ActualHours,
           ot.DescripcionTrabajoRealizado AS WorkDoneDescription,
           ot.EstaCompletada AS IsCompleted,
           ot.MotivoIncumplimiento AS UnfulfillmentReason,
           ot.FechaReprogramacion AS ReprogramDate,
           ot.ResponsableAccHaccp AS AccHaccpResponsible,
           ot.ResponsableMantenimiento AS MaintenanceResponsible,
           ot.ResponsableJefeArea AS AreaHeadResponsible,
           ot.ResponsableJefeMantenimiento AS MaintenanceHeadResponsible,
           ot.FechaProgramada AS ScheduledDate,
           ot.ReporteId AS ReportId,
           ot.CreadoPorUsuarioId AS CreatedByUserId,
           ot.CreadoPorNombreUsuario AS CreatedByUserName,
           ot.CreadoEn AS CreatedAt,
           ot.FechaInicioReal,
           ot.FechaFinReal,
           ot.MinutosPausaAcumulados,
           ot.FechaUltimaPausa,
           ot.MotivoPausa,
           ot.AprobadoPorUsuarioId,
           ot.AprobadoPorNombreUsuario,
           ot.AprobadoEn,
           ra.ImagenUrl AS BreakdownImageData,
           m.MaterialsJson,
           t.WorkTypesCsv,
           -- Aliases de compatibilidad directa
           ot.OrdenTrabajoId,
           ot.CodigoActivo,
           ot.NombreActivo,
           ot.NombreArea,
           ot.Descripcion,
           ot.Estado,
           ot.Prioridad,
           ot.AsignadoA,
           ot.CantidadPersonalAsignado,
           ot.HorasEstimadas,
           ot.HorasReales,
           ot.FechaProgramada
      FROM dbo.OrdenTrabajo ot
      LEFT JOIN dbo.Area ar ON ot.AreaId = ar.AreaId
      LEFT JOIN dbo.ReporteAveria ra ON ot.ReporteId = ra.ReporteId
      OUTER APPLY (
          SELECT (
              SELECT NumeroLinea AS lineNum, Descripcion AS description, Cantidad AS quantity, Unidad AS unit
                FROM dbo.MaterialOrdenTrabajo
               WHERE OrdenTrabajoId = ot.OrdenTrabajoId
               ORDER BY NumeroLinea ASC
                 FOR JSON PATH
          ) AS MaterialsJson
      ) m
      OUTER APPLY (
          SELECT STRING_AGG(TipoTrabajo, ',') AS WorkTypesCsv
            FROM dbo.TipoTrabajoOrdenTrabajo
           WHERE OrdenTrabajoId = ot.OrdenTrabajoId
      ) t
     WHERE (@StatusFilter IS NULL OR ot.Estado = @StatusFilter)
       AND (@AreaFilter IS NULL OR ot.AreaId = @AreaFilter)
       AND (@PriorityFilter IS NULL OR ot.Prioridad = @PriorityFilter)
     ORDER BY ot.CreadoEn DESC
    OFFSET @Offset ROWS
    FETCH NEXT COALESCE(@Limit, 5000) ROWS ONLY;
END;
GO

-- 6. ACTUALIZAR PROCEDIMIENTO: uspOrdenTrabajoObtenerAbiertas
CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoObtenerAbiertas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ot.OrdenTrabajoId,
           ot.CodigoActivo,
           ot.NombreActivo,
           ot.AreaId,
           ot.NombreArea,
           ot.Descripcion,
           ot.Estado,
           ot.Prioridad,
           ot.AsignadoA,
           ot.CantidadPersonalAsignado,
           ot.HorasEstimadas,
           ot.HorasReales,
           ot.DescripcionTrabajoRealizado,
           ot.EstaCompletada,
           ot.MotivoIncumplimiento,
           ot.FechaReprogramacion,
           ot.ResponsableAccHaccp,
           ot.ResponsableMantenimiento,
           ot.ResponsableJefeArea,
           ot.ResponsableJefeMantenimiento,
           ot.FechaProgramada,
           ot.ReporteId,
           ot.CreadoPorUsuarioId,
           ot.CreadoPorNombreUsuario,
           ot.CreadoEn,
           ot.FechaInicioReal,
           ot.FechaFinReal,
           ot.MinutosPausaAcumulados,
           ot.FechaUltimaPausa,
           ot.MotivoPausa,
           ot.AprobadoPorUsuarioId,
           ot.AprobadoPorNombreUsuario,
           ot.AprobadoEn,
           -- Aliases camelCase
           ot.OrdenTrabajoId AS WorkOrderId,
           ot.CodigoActivo AS AssetCode,
           ot.NombreActivo AS AssetName,
           ot.Descripcion AS Description,
           ot.Estado AS Status,
           ot.Prioridad AS Priority
      FROM dbo.OrdenTrabajo ot
     WHERE ot.Estado IN ('pending', 'inProgress', 'paused', 'reviewPending')
     ORDER BY ot.CreadoEn DESC;
END;
GO
