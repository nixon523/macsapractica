-- ----------------------------------------------------------------------------
-- 16. PROCEDIMIENTOS ALMACENADOS: AVERÍAS Y ÓRDENES DE TRABAJO
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaCrear
    @AssetCode NVARCHAR(60), 
    @AssetName NVARCHAR(200), 
    @AreaId NVARCHAR(15),
    @Description NVARCHAR(MAX), 
    @Severity NVARCHAR(10),
    @ReporterUserId INT = NULL, 
    @ReporterUserName NVARCHAR(100) = N'',
    @ImageData NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.Activo WHERE CodigoActivo = @AssetCode)
            RAISERROR(N'El activo no existe.', 16, 1);

        DECLARE @ReporteExistenteId BIGINT;
        SELECT TOP 1 @ReporteExistenteId = ReporteId
          FROM dbo.ReporteAveria WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @AssetCode
           AND Estado IN (N'reported', N'inWorkOrder');

        IF @ReporteExistenteId IS NOT NULL
        BEGIN
            DECLARE @MsgError NVARCHAR(250) = CONCAT(N'El activo ', @AssetCode, N' ya cuenta con un reporte de avería pendiente o en orden de trabajo (#', @ReporteExistenteId, N').');
            RAISERROR(@MsgError, 16, 1);
        END;

        INSERT INTO dbo.ReporteAveria (
            CodigoActivo, NombreActivo, AreaId, Descripcion, Severidad,
            ReportadoPorUsuarioId, ReportadoPorNombreUsuario, ImagenUrl
        )
        VALUES (
            @AssetCode, @AssetName, @AreaId, @Description, @Severity,
            @ReporterUserId, @ReporterUserName, @ImageData
        );
        DECLARE @rid BIGINT = SCOPE_IDENTITY();

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@ReporterUserId, @ReporterUserName, 'BREAKDOWN_REPORTED', 'BREAKDOWNS', @AssetCode,
                CONCAT(N'Reporte ', @rid, N': avería en ', @AssetCode, N' (', @AssetName, N'). Severidad: ', @Severity,
                       CASE WHEN @ImageData IS NOT NULL AND LEN(@ImageData) > 0 THEN N' [Con evidencia fotográfica]' ELSE N'' END));

        COMMIT TRANSACTION;
        SELECT @rid AS NewReportId, @rid AS ReporteId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaObtenerTodos
    @StatusFilter NVARCHAR(15) = NULL,
    @StartDate DATETIME2(3) = NULL, 
    @EndDate DATETIME2(3) = NULL,
    @Limit INT = NULL,
    @Offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ReporteId, 
           CodigoActivo AS AssetCode, 
           NombreActivo AS AssetName, 
           AreaId,
           Descripcion AS Description, 
           Severidad AS Severity,
           ReportadoPorUsuarioId AS ReportedByUserId, 
           ReportadoPorNombreUsuario AS ReportedByUserName,
           ReportadoEn AS ReportedAt, 
           Estado AS Status, 
           OrdenTrabajoId AS WorkOrderId,
           ResueltoPorUsuarioId AS ResolvedByUserId, 
           ResueltoPorNombreUsuario AS ResolvedByUserName,
           ResueltoEn AS ResolvedAt, 
           MotivoRechazo AS RejectionReason,
           RechazadoPorUsuarioId AS RejectedByUserId, 
           RechazadoPorNombreUsuario AS RejectedByUserName,
           RechazadoEn AS RejectedAt,
           ImagenUrl AS ImageData
      FROM dbo.ReporteAveria
     WHERE (@StatusFilter IS NULL OR Estado = @StatusFilter)
       AND (@StartDate IS NULL OR ReportadoEn >= @StartDate)
       AND (@EndDate   IS NULL OR ReportadoEn <= @EndDate)
     ORDER BY ReportadoEn DESC
     OFFSET @Offset ROWS
     FETCH NEXT CASE WHEN @Limit IS NULL OR @Limit <= 0 THEN 2147483647 ELSE @Limit END ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaObtenerPorUsuario
    @ReporterUserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ReporteId, CodigoActivo AS AssetCode, NombreActivo AS AssetName, AreaId,
           Descripcion AS Description, Severidad AS Severity,
           ReportadoPorUsuarioId AS ReportedByUserId, ReportadoPorNombreUsuario AS ReportedByUserName,
           ReportadoEn AS ReportedAt, Estado AS Status, OrdenTrabajoId AS WorkOrderId,
           ResueltoPorUsuarioId AS ResolvedByUserId, ResueltoPorNombreUsuario AS ResolvedByUserName,
           ResueltoEn AS ResolvedAt, MotivoRechazo AS RejectionReason,
           RechazadoPorUsuarioId AS RejectedByUserId, RechazadoPorNombreUsuario AS RejectedByUserName,
           RechazadoEn AS RejectedAt, ImagenUrl AS ImageData
      FROM dbo.ReporteAveria
     WHERE ReportadoPorUsuarioId = @ReporterUserId
     ORDER BY ReportadoEn DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaObtenerAbiertos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ReporteId, CodigoActivo AS AssetCode, NombreActivo AS AssetName, AreaId,
           Descripcion AS Description, Severidad AS Severity,
           ReportadoPorUsuarioId AS ReportedByUserId, ReportadoPorNombreUsuario AS ReportedByUserName,
           ReportadoEn AS ReportedAt, Estado AS Status, OrdenTrabajoId AS WorkOrderId,
           ResueltoPorUsuarioId AS ResolvedByUserId, ResueltoPorNombreUsuario AS ResolvedByUserName,
           ResueltoEn AS ResolvedAt, MotivoRechazo AS RejectionReason,
           RechazadoPorUsuarioId AS RejectedByUserId, RechazadoPorNombreUsuario AS RejectedByUserName,
           RechazadoEn AS RejectedAt, ImagenUrl AS ImageData
      FROM dbo.ReporteAveria
     WHERE Estado IN ('reported', 'inWorkOrder', 'pending', 'inProgress')
     ORDER BY CASE Severidad WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
              ReportadoEn ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaVincularOrdenTrabajo
    @ReportId BIGINT,
    @WorkOrderId NVARCHAR(20),
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.ReporteAveria
       SET OrdenTrabajoId = @WorkOrderId,
           Estado = 'inWorkOrder'
     WHERE ReporteId = @ReportId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaResolver
    @ReportId BIGINT,
    @ResolvedByUserId INT = NULL,
    @ResolvedByUserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.ReporteAveria
       SET Estado = 'resolved',
           ResueltoPorUsuarioId = @ResolvedByUserId,
           ResueltoPorNombreUsuario = @ResolvedByUserName,
           ResueltoEn = SYSUTCDATETIME()
     WHERE ReporteId = @ReportId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaRechazar
    @ReportId BIGINT,
    @Reason NVARCHAR(500) = NULL,
    @RejectReason NVARCHAR(500) = NULL,
    @RejectedByUserId INT = NULL,
    @RejectedByUserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @MotivoRechazo NVARCHAR(500) = COALESCE(@Reason, @RejectReason, N'');

        UPDATE dbo.ReporteAveria
           SET Estado = 'rejected',
                MotivoRechazo = @MotivoRechazo,
                RechazadoPorUsuarioId = @RejectedByUserId,
                RechazadoPorNombreUsuario = @RejectedByUserName,
                RechazadoEn = SYSUTCDATETIME()
          WHERE ReporteId = @ReportId;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@RejectedByUserId, @RejectedByUserName, 'BREAKDOWN_REJECTED', 'BREAKDOWNS', CAST(@ReportId AS NVARCHAR(20)),
                CONCAT(N'Reporte de avería ', @ReportId, N' rechazado. Motivo: ', @MotivoRechazo));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

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
           ot.FechaProgramada,
           ot.CreadoEn
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
           ra.ImagenUrl AS BreakdownImageData,
           -- Aliases camelCase
           ot.OrdenTrabajoId AS WorkOrderId,
           ot.CodigoActivo AS AssetCode,
           ot.NombreActivo AS AssetName,
           ot.Descripcion AS Description,
           ot.Estado AS Status,
           ot.Prioridad AS Priority
      FROM dbo.OrdenTrabajo ot
      LEFT JOIN dbo.ReporteAveria ra ON ot.ReporteId = ra.ReporteId
     WHERE ot.Estado IN ('pending', 'inProgress', 'paused', 'reviewPending')
     ORDER BY CASE ot.Prioridad WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
              ot.CreadoEn ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoCrear
    @AssetCode NVARCHAR(60) = N'',
    @AssetName NVARCHAR(200),
    @AreaId NVARCHAR(15) = NULL,
    @AreaName NVARCHAR(200) = NULL,
    @Description NVARCHAR(MAX),
    @Priority NVARCHAR(10) = N'medium',
    @AssignedTo NVARCHAR(200) = NULL,
    @AssignedStaffCount INT = NULL,
    @EstimatedHours DECIMAL(6,2) = NULL,
    @ScheduledDate DATETIME2(3) = NULL,
    @ReportId BIGINT = NULL,
    @CreatedByUserId INT = NULL,
    @CreatedByUserName NVARCHAR(100) = N'',
    @Materials dbo.TipoMaterialOrdenTrabajo READONLY,
    @WorkTypes dbo.TipoListaTexto READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

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
            UPDATE dbo.ReporteAveria
               SET OrdenTrabajoId = @woId, Estado = 'inWorkOrder'
             WHERE ReporteId = @ReportId;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreatedByUserId, @CreatedByUserName, 'WORK_ORDER_CREATED', 'WORK_ORDERS', @woId,
                CONCAT(N'OT creada: ', @woId, N' para ', @AssetName, N' (Prioridad: ', @Priority, N').'));

        COMMIT TRANSACTION;
        SELECT @woId AS WorkOrderId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

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

CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoActualizarDetalles
    @WorkOrderId                 NVARCHAR(20),
    @Description                 NVARCHAR(MAX) = NULL,
    @Priority                    NVARCHAR(10) = NULL,
    @AssignedTo                  NVARCHAR(200) = NULL,
    @AssignedStaffCount          INT = NULL,
    @EstimatedHours              DECIMAL(6,2) = NULL,
    @ActualHours                 DECIMAL(6,2) = NULL,
    @WorkDoneDescription         NVARCHAR(MAX) = NULL,
    @WorkDescription             NVARCHAR(MAX) = NULL,
    @IsCompleted                 BIT = NULL,
    @UnfulfillmentReason         NVARCHAR(500) = NULL,
    @UnfulfilledReason           NVARCHAR(500) = NULL,
    @ReprogramDate               DATETIME2(3) = NULL,
    @RescheduledDate             DATETIME2(3) = NULL,
    @AccHaccpResponsible        NVARCHAR(200) = NULL,
    @ResponsableAccHaccp         NVARCHAR(200) = NULL,
    @MaintenanceResponsible      NVARCHAR(200) = NULL,
    @ResponsableMantenimiento    NVARCHAR(200) = NULL,
    @ResponsableJefeArea         NVARCHAR(200) = NULL,
    @ResponsableJefeMantenimiento NVARCHAR(200) = NULL,
    @ScheduledDate               DATETIME2(3) = NULL,
    @UserId                      INT = NULL,
    @UserName                    NVARCHAR(100) = N'',
    @Materials                   dbo.TipoMaterialOrdenTrabajo READONLY,
    @WorkTypes                   dbo.TipoListaTexto READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.OrdenTrabajo
           SET Descripcion                  = COALESCE(@Description, Descripcion),
               Prioridad                    = COALESCE(@Priority, Prioridad),
               AsignadoA                    = COALESCE(@AssignedTo, AsignadoA),
               CantidadPersonalAsignado     = COALESCE(@AssignedStaffCount, CantidadPersonalAsignado),
               HorasEstimadas               = COALESCE(@EstimatedHours, HorasEstimadas),
               HorasReales                  = COALESCE(@ActualHours, HorasReales),
               DescripcionTrabajoRealizado  = COALESCE(@WorkDoneDescription, @WorkDescription, DescripcionTrabajoRealizado),
               EstaCompletada               = COALESCE(@IsCompleted, EstaCompletada),
               MotivoIncumplimiento         = COALESCE(@UnfulfillmentReason, @UnfulfilledReason, MotivoIncumplimiento),
               FechaReprogramacion          = COALESCE(@ReprogramDate, @RescheduledDate, FechaReprogramacion),
               ResponsableAccHaccp          = COALESCE(@AccHaccpResponsible, @ResponsableAccHaccp, ResponsableAccHaccp),
               ResponsableMantenimiento     = COALESCE(@MaintenanceResponsible, @ResponsableMantenimiento, ResponsableMantenimiento),
               ResponsableJefeArea          = COALESCE(@ResponsableJefeArea, ResponsableJefeArea),
               ResponsableJefeMantenimiento = COALESCE(@ResponsableJefeMantenimiento, ResponsableJefeMantenimiento),
               FechaProgramada              = COALESCE(@ScheduledDate, FechaProgramada),
               ActualizadoEn                = SYSUTCDATETIME()
         WHERE OrdenTrabajoId = @WorkOrderId;

        IF EXISTS (SELECT 1 FROM @Materials)
        BEGIN
            DELETE FROM dbo.MaterialOrdenTrabajo WHERE OrdenTrabajoId = @WorkOrderId;
            INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
            SELECT @WorkOrderId, NumeroLinea, Descripcion, Cantidad, Unidad FROM @Materials;
        END;

        IF EXISTS (SELECT 1 FROM @WorkTypes)
        BEGIN
            DELETE FROM dbo.TipoTrabajoOrdenTrabajo WHERE OrdenTrabajoId = @WorkOrderId;
            INSERT INTO dbo.TipoTrabajoOrdenTrabajo (OrdenTrabajoId, TipoTrabajo)
            SELECT @WorkOrderId, Valor FROM @WorkTypes;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 17. PROCEDIMIENTOS ALMACENADOS: PLANES PREVENTIVOS Y GENERACIÓN DE OTS
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoObtenerTodos
    @AreaFilter   NVARCHAR(15) = NULL,
    @StatusFilter NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        p.PlanId                      AS ScheduleId,
        p.Titulo                      AS Title,
        p.CodigoActivo                AS AssetCode,
        p.NombreActivo                AS AssetName,
        p.AreaId,
        COALESCE(ar.Nombre, p.NombreArea) AS AreaName,
        p.TipoMantenimiento           AS MaintenanceType,
        p.Frecuencia                  AS Frequency,
        p.Descripcion                 AS Description,
        p.HorasEstimadas              AS EstimatedHours,
        p.FechaInicio                 AS StartDate,
        p.ProximaFecha                AS NextDate,
        p.UltimaCompletada            AS LastCompleted,
        p.UltimaOrdenTrabajoId        AS LastWorkOrderId,
        p.Estado                      AS Status,
        p.Notas                       AS Notes,
        p.CreadoPorUsuarioId          AS CreatedByUserId,
        p.CreadoPorNombreUsuario      AS CreatedByUserName,
        p.CreadoEn                    AS CreatedAt,
        p.NumeroDocumentoModificacion AS AmendmentDocNumber,
        p.ModificadoPor               AS AmendedBy,
        p.ModificadoEn                AS AmendedAt,
        p.MotivoModificacion          AS AmendmentReason,
        m.MaterialsJson,
        p.PlanId,
        p.Titulo,
        p.CodigoActivo,
        p.NombreActivo,
        p.NombreArea,
        p.TipoMantenimiento,
        p.Frecuencia,
        p.Descripcion,
        p.HorasEstimadas,
        p.FechaInicio,
        p.ProximaFecha,
        p.UltimaCompletada,
        p.UltimaOrdenTrabajoId,
        p.Estado,
        p.Notas,
        p.CreadoPorUsuarioId,
        p.CreadoPorNombreUsuario,
        p.CreadoEn
    FROM dbo.PlanPreventivo p
    LEFT JOIN dbo.Area ar ON p.AreaId = ar.AreaId
    OUTER APPLY (
        SELECT (
            SELECT NumeroLinea AS LineNum, Nombre AS Name, Cantidad AS Quantity, Unidad AS Unit
            FROM dbo.MaterialPreventivo
            WHERE PlanId = p.PlanId
            ORDER BY NumeroLinea
            FOR JSON PATH
        ) AS MaterialsJson
    ) m
    WHERE (@StatusFilter IS NULL OR p.Estado = @StatusFilter)
      AND (@AreaFilter   IS NULL OR p.AreaId = @AreaFilter)
    ORDER BY p.ProximaFecha ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoCrear
    @Title NVARCHAR(200),
    @AssetCode NVARCHAR(60),
    @AssetName NVARCHAR(200),
    @AreaId NVARCHAR(15),
    @AreaName NVARCHAR(200),
    @MaintenanceType NVARCHAR(100),
    @Frequency NVARCHAR(20),
    @Description NVARCHAR(MAX) = NULL,
    @EstimatedHours DECIMAL(6,2) = NULL,
    @StartDate DATETIME2(3),
    @NextDate DATETIME2(3),
    @LastCompleted DATETIME2(3) = NULL,
    @LastWorkOrderId NVARCHAR(20) = NULL,
    @Status NVARCHAR(15) = 'active',
    @Notes NVARCHAR(500) = NULL,
    @CreatedByUserId INT = NULL,
    @CreatedByUserName NVARCHAR(100) = N'',
    @IntervaloFrecuencia INT = 1,
    @UnidadFrecuencia NVARCHAR(20) = 'meses',
    @ActividadesJson NVARCHAR(MAX) = NULL,
    @Materials dbo.TipoMaterialPreventivo READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Regla de Integridad: Solo 1 plan preventivo activo por activo
        IF EXISTS (SELECT 1 FROM dbo.PlanPreventivo WHERE CodigoActivo = @AssetCode AND Estado = 'active')
        BEGIN
            DECLARE @ExistingPlanId NVARCHAR(20);
            SELECT TOP 1 @ExistingPlanId = PlanId FROM dbo.PlanPreventivo WHERE CodigoActivo = @AssetCode AND Estado = 'active';
            DECLARE @MsgPrev NVARCHAR(250) = CONCAT(N'El activo ', @AssetCode, N' ya cuenta con el plan preventivo activo ', @ExistingPlanId, N'. No se permiten múltiples planes preventivos simultáneos.');
            RAISERROR(@MsgPrev, 16, 1);
        END;

        DECLARE @pCount TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT deleted.SiguienteNumero INTO @pCount(v)
          WHERE Nombre = 'preventive_schedules';

        DECLARE @seq INT; SELECT @seq = v FROM @pCount;
        DECLARE @pId NVARCHAR(20) = CONCAT('PM-', YEAR(SYSUTCDATETIME()), '-', FORMAT(@seq, '0000'));

        INSERT INTO dbo.PlanPreventivo
            (PlanId, Titulo, CodigoActivo, NombreActivo, AreaId, NombreArea,
             TipoMantenimiento, Frecuencia, Descripcion, HorasEstimadas,
             FechaInicio, ProximaFecha, Estado, Notas,
             CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn)
        VALUES
            (@pId, @Title, @AssetCode, @AssetName, @AreaId, @AreaName,
             @MaintenanceType, @Frequency, @Description, @EstimatedHours,
             @StartDate, @NextDate, 'active', @Notes,
             @CreatedByUserId, @CreatedByUserName, SYSUTCDATETIME());

        INSERT INTO dbo.MaterialPreventivo (PlanId, NumeroLinea, Nombre, Cantidad, Unidad)
        SELECT @pId, ROW_NUMBER() OVER (ORDER BY NumeroLinea), Nombre, Cantidad, ISNULL(Unidad, 'pza')
          FROM @Materials;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreatedByUserId, @CreatedByUserName, 'PREVENTIVE_PLAN_CREATED', 'PREVENTIVE', @pId,
                CONCAT(N'Plan preventivo creado: ', @pId, N' (', @Title, N') para ', @AssetCode, N'. Frecuencia: ', @Frequency));

        COMMIT TRANSACTION;
        SELECT @pId AS PlanId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoModificar
    @ScheduleId          NVARCHAR(20) = NULL,
    @PlanId              NVARCHAR(20) = NULL,
    @Title               NVARCHAR(200) = NULL,
    @MaintenanceType     NVARCHAR(100) = NULL,
    @Frequency           NVARCHAR(20) = NULL,
    @Description         NVARCHAR(MAX) = NULL,
    @EstimatedHours      DECIMAL(6,2) = NULL,
    @StartDate           DATETIME2(3) = NULL,
    @NextDate            DATETIME2(3) = NULL,
    @Notes               NVARCHAR(500) = NULL,
    @AmendmentDocNumber  NVARCHAR(50) = NULL,
    @ModifiedDocNumber   NVARCHAR(50) = NULL,
    @AuthorizedByManager BIT = 0,
    @AmendmentReason     NVARCHAR(500) = NULL,
    @ModifyReason        NVARCHAR(500) = NULL,
    @UserId              INT = NULL,
    @UserName            NVARCHAR(100) = N'',
    @Materials           dbo.TipoMaterialPreventivo READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @TargetPlan NVARCHAR(20) = COALESCE(@ScheduleId, @PlanId);

        UPDATE dbo.PlanPreventivo
           SET Titulo                      = COALESCE(@Title, Titulo),
               TipoMantenimiento           = COALESCE(@MaintenanceType, TipoMantenimiento),
               Frecuencia                  = COALESCE(@Frequency, Frecuencia),
               Descripcion                 = COALESCE(@Description, Descripcion),
               HorasEstimadas              = COALESCE(@EstimatedHours, HorasEstimadas),
               FechaInicio                 = COALESCE(@StartDate, FechaInicio),
               ProximaFecha                = COALESCE(@NextDate, ProximaFecha),
               Notas                       = COALESCE(@Notes, Notas),
               NumeroDocumentoModificacion = COALESCE(@AmendmentDocNumber, @ModifiedDocNumber, NumeroDocumentoModificacion),
               ModificadoPor               = COALESCE(@UserName, ModificadoPor),
               ModificadoEn                = SYSUTCDATETIME(),
               MotivoModificacion          = COALESCE(@AmendmentReason, @ModifyReason, MotivoModificacion)
         WHERE PlanId = @TargetPlan;

        IF EXISTS (SELECT 1 FROM @Materials)
        BEGIN
            DELETE FROM dbo.MaterialPreventivo WHERE PlanId = @TargetPlan;
            INSERT INTO dbo.MaterialPreventivo (PlanId, NumeroLinea, Nombre, Cantidad, Unidad)
            SELECT @TargetPlan, ROW_NUMBER() OVER (ORDER BY NumeroLinea), Nombre, Cantidad, ISNULL(Unidad, 'pza') FROM @Materials;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'PREVENTIVE_PLAN_MODIFIED', 'PREVENTIVE', @TargetPlan,
                CONCAT(N'Plan preventivo ', @TargetPlan, N' modificado. Motivo: ', ISNULL(COALESCE(@AmendmentReason, @ModifyReason), N'N/A')));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoRegistrarEjecucion
    @ScheduleId    NVARCHAR(20) = NULL,
    @PlanId        NVARCHAR(20) = NULL,
    @WorkOrderId   NVARCHAR(20),
    @CompletedDate DATETIME2(3) = NULL,
    @UserId        INT = NULL,
    @UserName      NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @TargetPlanExec NVARCHAR(20) = COALESCE(@ScheduleId, @PlanId);
        DECLARE @DateFinal DATETIME2(3) = COALESCE(@CompletedDate, SYSUTCDATETIME());

        UPDATE dbo.PlanPreventivo
           SET UltimaCompletada = @DateFinal,
               UltimaOrdenTrabajoId = @WorkOrderId
         WHERE PlanId = @TargetPlanExec;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'PREVENTIVE_PLAN_EXECUTED', 'PREVENTIVE', @TargetPlanExec,
                CONCAT(N'Ejecución del plan preventivo ', @TargetPlanExec, N' registrada con OT ', @WorkOrderId, N'. Fecha: ', CONVERT(NVARCHAR(30), @DateFinal, 120)));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoAlternarEstado
    @ScheduleId          NVARCHAR(20) = NULL,
    @PlanId              NVARCHAR(20) = NULL,
    @NewStatus           NVARCHAR(15) = NULL,
    @NuevoEstado         NVARCHAR(15) = NULL,
    @AmendmentDocNumber  NVARCHAR(50) = NULL,
    @AuthorizedByManager BIT = 0,
    @Reason              NVARCHAR(500) = NULL,
    @Motivo              NVARCHAR(500) = NULL,
    @UserId              INT = NULL,
    @UserName            NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TargetPlanAlt NVARCHAR(20) = COALESCE(@ScheduleId, @PlanId);
    DECLARE @TargetStatusAlt NVARCHAR(15) = COALESCE(@NewStatus, @NuevoEstado);

    UPDATE dbo.PlanPreventivo
       SET Estado = @TargetStatusAlt,
           NumeroDocumentoModificacion = COALESCE(@AmendmentDocNumber, NumeroDocumentoModificacion),
           MotivoModificacion = COALESCE(@Reason, @Motivo, MotivoModificacion),
           ModificadoPor = COALESCE(@UserName, ModificadoPor),
           ModificadoEn = SYSUTCDATETIME()
     WHERE PlanId = @TargetPlanAlt;

    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
    VALUES (@UserId, @UserName, 'PREVENTIVE_PLAN_STATUS', 'PREVENTIVE', @TargetPlanAlt,
            CONCAT(N'Estado de plan preventivo ', @TargetPlanAlt, N' cambiado a: ', @TargetStatusAlt, N'.'));
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspGenerarOrdenTrabajoPreventiva
    @PlanId NVARCHAR(20),
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @AssetCode NVARCHAR(60), @AssetName NVARCHAR(200), @AreaId NVARCHAR(15), @AreaName NVARCHAR(200);
        DECLARE @Desc NVARCHAR(MAX), @Hours DECIMAL(6,2), @NextDate DATETIME2(3), @Freq NVARCHAR(20);
        DECLARE @Title NVARCHAR(200);

        SELECT @AssetCode = CodigoActivo, @AssetName = NombreActivo, @AreaId = AreaId, @AreaName = NombreArea,
               @Desc = Descripcion, @Hours = HorasEstimadas, @NextDate = ProximaFecha, @Freq = Frecuencia,
               @Title = Titulo
          FROM dbo.PlanPreventivo WITH (UPDLOCK, HOLDLOCK)
         WHERE PlanId = @PlanId AND Estado = 'active';

        IF @AssetCode IS NULL
            RAISERROR(N'El plan preventivo no existe o no se encuentra activo.', 16, 1);

        -- Generar ID de Orden de Trabajo
        DECLARE @cCount TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT deleted.SiguienteNumero INTO @cCount(v)
          WHERE Nombre = 'work_orders';

        DECLARE @seq INT; SELECT @seq = v FROM @cCount;
        DECLARE @woId NVARCHAR(20) = CONCAT('OT-', YEAR(SYSUTCDATETIME()), '-', FORMAT(@seq, '0000'));

        INSERT INTO dbo.OrdenTrabajo
            (OrdenTrabajoId, CodigoActivo, NombreActivo, AreaId, NombreArea, Descripcion,
             Estado, Prioridad, HorasEstimadas, FechaProgramada, CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn)
        VALUES
            (@woId, @AssetCode, @AssetName, @AreaId, @AreaName,
             CONCAT(N'[Preventivo ', @PlanId, N']: ', @Title, CHAR(13), CHAR(10), ISNULL(@Desc, N'')),
             'pending', 'medium', @Hours, @NextDate, @UserId, @UserName, SYSUTCDATETIME());

        INSERT INTO dbo.TipoTrabajoOrdenTrabajo (OrdenTrabajoId, TipoTrabajo)
        VALUES (@woId, 'preventive');

        INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
        SELECT @woId, NumeroLinea, Nombre, Cantidad, Unidad
          FROM dbo.MaterialPreventivo
         WHERE PlanId = @PlanId;

        DECLARE @DaysToAdd INT = dbo.fnFrecuenciaDias(@Freq);
        DECLARE @NewNextDate DATETIME2(3) = DATEADD(DAY, @DaysToAdd, @NextDate);

        UPDATE dbo.PlanPreventivo
           SET UltimaOrdenTrabajoId = @woId,
               UltimaCompletada     = SYSUTCDATETIME(),
               ProximaFecha         = @NewNextDate
         WHERE PlanId = @PlanId;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'WORK_ORDER_CREATED', 'WORK_ORDERS', @woId,
                CONCAT(N'OT Preventiva generada: ', @woId, N' a partir del plan ', @PlanId, N'. Próxima fecha programada: ', CONVERT(NVARCHAR(30), @NewNextDate, 120)));

        COMMIT TRANSACTION;
        SELECT @woId AS WorkOrderId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


CREATE OR ALTER PROCEDURE dbo.uspGenerarOrdenesTrabajoPreventivasVencidas
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N'Sistema Automático'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentDate DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @PlanId NVARCHAR(20);

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT PlanId
          FROM dbo.PlanPreventivo
         WHERE Estado = 'active'
           AND ProximaFecha <= @CurrentDate;

    OPEN cur;
    FETCH NEXT FROM cur INTO @PlanId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC dbo.uspGenerarOrdenTrabajoPreventiva @PlanId = @PlanId, @UserId = @UserId, @UserName = @UserName;
        END TRY
        BEGIN CATCH
            INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
            VALUES (@UserId, @UserName, 'PREVENTIVE_GENERATION_FAILED', 'PREVENTIVE', @PlanId,
                    CONCAT(N'Error al autogenerar OT preventiva para el plan ', @PlanId, N': ', ERROR_MESSAGE()));
        END CATCH;

        FETCH NEXT FROM cur INTO @PlanId;
    END;
    CLOSE cur;
    DEALLOCATE cur;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoObtenerIndicadores
    @AreaId NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        COUNT(*) AS TotalPlanes,
        SUM(CASE WHEN Estado = 'active' THEN 1 ELSE 0 END) AS Activos,
        SUM(CASE WHEN Estado = 'paused' THEN 1 ELSE 0 END) AS Pausados,
        SUM(CASE WHEN Estado = 'completed' THEN 1 ELSE 0 END) AS Completados,
        SUM(CASE WHEN ProximaFecha < SYSUTCDATETIME() AND Estado = 'active' THEN 1 ELSE 0 END) AS Vencidos
    FROM dbo.PlanPreventivo
    WHERE (@AreaId IS NULL OR AreaId = @AreaId);
END;
GO

GO

CREATE OR ALTER PROCEDURE dbo.uspGenerarOrdenTrabajoPreventivaMes
    @PlanId             NVARCHAR(20),
    @Anio               INT,
    @Mes                INT,
    @CreadoPorUsuarioId INT = NULL,
    @CreadoPorNombre    NVARCHAR(100) = N'',
    @NuevaOrdenId       NVARCHAR(20) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CodigoPadre NVARCHAR(60), @NombrePadre NVARCHAR(200), @AreaId NVARCHAR(15), @NombreArea NVARCHAR(200);
        SELECT @CodigoPadre = CodigoActivo, @NombrePadre = NombreActivo, @AreaId = AreaId, @NombreArea = NombreArea
          FROM dbo.PlanPreventivo WHERE PlanId = @PlanId;

        IF @CodigoPadre IS NULL
            RAISERROR(N'El plan preventivo no existe.', 16, 1);

        -- Verificar si ya existe una OT abierta para este plan
        DECLARE @OTExistente NVARCHAR(20);
        SELECT TOP 1 @OTExistente = OrdenTrabajoId
          FROM dbo.OrdenTrabajo
         WHERE PlanPreventivoId = @PlanId AND Estado IN ('pending', 'in_progress', 'paused');

        IF @OTExistente IS NOT NULL
        BEGIN
            SET @NuevaOrdenId = @OTExistente;
            COMMIT TRANSACTION;
            SELECT @NuevaOrdenId AS NewWorkOrderId, @NuevaOrdenId AS NuevaOrdenId, CAST(1 AS BIT) AS YaExistia;
            RETURN;
        END;

        DECLARE @cnt TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT inserted.SiguienteNumero INTO @cnt(v)
          WHERE Nombre = 'work_orders';

        DECLARE @seq INT; SELECT @seq = v FROM @cnt;
        SET @NuevaOrdenId = CONCAT('OT-', YEAR(SYSUTCDATETIME()), '-', FORMAT(@seq, '0000'));

        INSERT INTO dbo.OrdenTrabajo (
            OrdenTrabajoId, CodigoActivo, NombreActivo, AreaId, NombreArea,
            Descripcion, Estado, Prioridad, PlanPreventivoId, CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn
        )
        VALUES (
            @NuevaOrdenId, @CodigoPadre, @NombrePadre, @AreaId, @NombreArea,
            CONCAT(N'Mantenimiento preventivo mensual según plan ', @PlanId, N' (', @Mes, N'/', @Anio, N').'),
            'pending', 'medium', @PlanId, @CreadoPorUsuarioId, @CreadoPorNombre, SYSUTCDATETIME()
        );

        INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
        SELECT @NuevaOrdenId, NumeroLinea, Nombre, Cantidad, Unidad
          FROM dbo.MaterialPreventivo
         WHERE PlanId = @PlanId;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreadoPorUsuarioId, @CreadoPorNombre, 'WORK_ORDER_CREATED', 'WORK_ORDERS', @NuevaOrdenId,
                CONCAT(N'OT preventiva ', @NuevaOrdenId, N' generada automáticamente desde plan ', @PlanId, N'.'));

        COMMIT TRANSACTION;
        SELECT @NuevaOrdenId AS NewWorkOrderId, @NuevaOrdenId AS NuevaOrdenId, CAST(0 AS BIT) AS YaExistia;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspGenerarOrdenesTrabajoPreventivasMasivas
    @Anio               INT,
    @Mes                INT,
    @AreaId             NVARCHAR(15) = NULL,
    @CreadoPorUsuarioId INT = NULL,
    @CreadoPorNombre    NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @PlanesElegibles TABLE (PlanId NVARCHAR(20));

    INSERT INTO @PlanesElegibles (PlanId)
    SELECT p.PlanId
      FROM dbo.PlanPreventivo p
     WHERE p.Estado = 'active'
       AND (@AreaId IS NULL OR p.AreaId = @AreaId);

    DECLARE @Resultados TABLE (
        PlanId NVARCHAR(20),
        WorkOrderId NVARCHAR(20),
        Exitoso BIT,
        Mensaje NVARCHAR(500)
    );

    DECLARE @CurrentPlanId NVARCHAR(20);
    DECLARE plan_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT PlanId FROM @PlanesElegibles;

    OPEN plan_cursor;
    FETCH NEXT FROM plan_cursor INTO @CurrentPlanId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @NuevaOT NVARCHAR(20) = NULL;
        BEGIN TRY
            EXEC dbo.uspGenerarOrdenTrabajoPreventivaMes
                @PlanId = @CurrentPlanId,
                @Anio = @Anio,
                @Mes = @Mes,
                @CreadoPorUsuarioId = @CreadoPorUsuarioId,
                @CreadoPorNombre = @CreadoPorNombre,
                @NuevaOrdenId = @NuevaOT OUTPUT;

            INSERT INTO @Resultados (PlanId, WorkOrderId, Exitoso, Mensaje)
            VALUES (@CurrentPlanId, @NuevaOT, 1, N'OT procesada exitosamente.');
        END TRY
        BEGIN CATCH
            INSERT INTO @Resultados (PlanId, WorkOrderId, Exitoso, Mensaje)
            VALUES (@CurrentPlanId, NULL, 0, ERROR_MESSAGE());
        END CATCH;

        FETCH NEXT FROM plan_cursor INTO @CurrentPlanId;
    END;

    CLOSE plan_cursor;
    DEALLOCATE plan_cursor;

    SELECT PlanId, WorkOrderId, Exitoso, Mensaje FROM @Resultados;
END;
