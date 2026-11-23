const fs = require('fs');
const path = require('path');

// 1. Update 04_activos_bajas_sp.sql
let f4 = fs.readFileSync('scripts/sql_modules/04_activos_bajas_sp.sql', 'utf8');

// uspActivoObtenerHijos: add ParentAssetCode, ParentCode, AreaId
f4 = f4.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspActivoObtenerHijos[\s\S]*?AS\s+BEGIN[\s\S]*?WHERE CodigoActivoPadre = @ParentCode[\s\S]*?ORDER BY CodigoActivo ASC;\s*END;/i,
  `CREATE OR ALTER PROCEDURE dbo.uspActivoObtenerHijos
    @ParentAssetCode NVARCHAR(60) = NULL,
    @ParentCode      NVARCHAR(60) = NULL,
    @AreaId          NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TargetParent NVARCHAR(60) = COALESCE(@ParentAssetCode, @ParentCode);
    SELECT CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId,
           CodigoActivoPadre, Nivel, RutaAncestros, Estado, Serie,
           AtributosDinamicos, DatosImagen, ContadorHijos, CreadoEn, ActualizadoEn,
           EsEquipoProceso
      FROM dbo.Activo
     WHERE (@TargetParent IS NULL AND CodigoActivoPadre IS NULL OR CodigoActivoPadre = @TargetParent)
       AND (@AreaId IS NULL OR AreaId = @AreaId)
       AND Estado <> 'deleted'
     ORDER BY CodigoActivo ASC;
END;`
);

// uspActivoActualizar: add Status
f4 = f4.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspActivoActualizar[\s\S]*?@UserName\s+NVARCHAR\(100\)\s*=\s*N''\s*AS/i,
  `CREATE OR ALTER PROCEDURE dbo.uspActivoActualizar
    @AssetCode NVARCHAR(60),
    @Name NVARCHAR(200),
    @Brand NVARCHAR(100) = NULL,
    @Model NVARCHAR(100) = NULL,
    @StationId NVARCHAR(100) = '',
    @Serial NVARCHAR(100) = NULL,
    @DynamicAttributes NVARCHAR(MAX) = NULL,
    @ImageData NVARCHAR(500) = NULL,
    @Status NVARCHAR(25) = NULL,
    @Estado NVARCHAR(25) = NULL,
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS`
);

// uspActivoAlternarEstado: add NewStatus
f4 = f4.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspActivoAlternarEstado[\s\S]*?AS\s+BEGIN/i,
  `CREATE OR ALTER PROCEDURE dbo.uspActivoAlternarEstado
    @AssetCode NVARCHAR(60),
    @NewStatus NVARCHAR(25) = NULL,
    @Status    NVARCHAR(25) = NULL,
    @Reason    NVARCHAR(500) = NULL,
    @UserId    INT = NULL,
    @UserName  NVARCHAR(100) = N''
AS
BEGIN`
);
f4 = f4.replace(
  /UPDATE dbo\.Activo\s+SET Estado = @Status,/i,
  `DECLARE @TargetStatus NVARCHAR(25) = COALESCE(@NewStatus, @Status);
        UPDATE dbo.Activo
           SET Estado = @TargetStatus,`
);

// uspActivoActualizarEsEquipoProceso: add CodigoActivo, UsuarioId, NombreUsuario
f4 = f4.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspActivoActualizarEsEquipoProceso[\s\S]*?AS\s+BEGIN/i,
  `CREATE OR ALTER PROCEDURE dbo.uspActivoActualizarEsEquipoProceso
    @CodigoActivo NVARCHAR(60) = NULL,
    @AssetCode NVARCHAR(60) = NULL,
    @EsEquipoProceso BIT = 1,
    @UsuarioId INT = NULL,
    @UserId INT = NULL,
    @NombreUsuario NVARCHAR(100) = N'',
    @UserName NVARCHAR(100) = N''
AS
BEGIN`
);
f4 = f4.replace(
  /WHERE CodigoActivo = @AssetCode;/i,
  `WHERE CodigoActivo = COALESCE(@CodigoActivo, @AssetCode);`
);

// uspSolicitudBajaCrear: add UserId, UserName
f4 = f4.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspSolicitudBajaCrear[\s\S]*?AS\s+BEGIN/i,
  `CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaCrear
    @AssetCode NVARCHAR(60),
    @Reason NVARCHAR(1000),
    @RequesterUserId INT = NULL,
    @RequesterUserName NVARCHAR(100) = N'',
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN`
);
f4 = f4.replace(
  /@RequesterUserId,\s*@RequesterUserName,\s*SYSUTCDATETIME\(\)/i,
  `COALESCE(@RequesterUserId, @UserId), COALESCE(NULLIF(@RequesterUserName, N''), @UserName, N''), SYSUTCDATETIME()`
);

// uspSolicitudBajaObtenerPendientes: add StartDate, EndDate
f4 = f4.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspSolicitudBajaObtenerPendientes[\s\S]*?AS\s+BEGIN[\s\S]*?WHERE Estado = 'pending'[\s\S]*?ORDER BY SolicitadoEn DESC;\s*END;/i,
  `CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaObtenerPendientes
    @StartDate DATETIME2(3) = NULL,
    @EndDate   DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SolicitudId, CodigoActivo, NombreActivo, AreaId, Estado, Motivo,
           SolicitadoPorUsuarioId, SolicitadoPorNombreUsuario, SolicitadoEn,
           DecididoPorUsuarioId, DecididoPorNombreUsuario, DecididoEn, MotivoDecision
      FROM dbo.SolicitudBaja
     WHERE Estado = 'pending'
       AND (@StartDate IS NULL OR SolicitadoEn >= @StartDate)
       AND (@EndDate   IS NULL OR SolicitadoEn <= @EndDate)
     ORDER BY SolicitadoEn DESC;
END;`
);

// uspSolicitudBajaObtenerTodas: add StartDate, EndDate
f4 = f4.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspSolicitudBajaObtenerTodas[\s\S]*?AS\s+BEGIN[\s\S]*?WHERE \(@StatusFilter IS NULL OR Estado = @StatusFilter\)[\s\S]*?ORDER BY SolicitadoEn DESC;\s*END;/i,
  `CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaObtenerTodas
    @StatusFilter NVARCHAR(10) = NULL,
    @StartDate    DATETIME2(3) = NULL,
    @EndDate      DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SolicitudId, CodigoActivo, NombreActivo, AreaId, Estado, Motivo,
           SolicitadoPorUsuarioId, SolicitadoPorNombreUsuario, SolicitadoEn,
           DecididoPorUsuarioId, DecididoPorNombreUsuario, DecididoEn, MotivoDecision
      FROM dbo.SolicitudBaja
     WHERE (@StatusFilter IS NULL OR Estado = @StatusFilter)
       AND (@StartDate IS NULL OR SolicitadoEn >= @StartDate)
       AND (@EndDate   IS NULL OR SolicitadoEn <= @EndDate)
     ORDER BY SolicitadoEn DESC;
END;`
);

// uspSolicitudBajaRechazar: add Reason, RejectedByUserId, RejectedByUserName
f4 = f4.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspSolicitudBajaRechazar[\s\S]*?AS\s+BEGIN/i,
  `CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaRechazar
    @RequestId BIGINT,
    @Reason NVARCHAR(500) = NULL,
    @RejectReason NVARCHAR(500) = NULL,
    @RejectedByUserId INT = NULL,
    @ApproverUserId INT = NULL,
    @RejectedByUserName NVARCHAR(100) = N'',
    @ApproverUserName NVARCHAR(100) = N''
AS
BEGIN`
);

fs.writeFileSync('scripts/sql_modules/04_activos_bajas_sp.sql', f4, 'utf8');

// 2. Update 05_averias_ots_preventivos_sp.sql
let f5 = fs.readFileSync('scripts/sql_modules/05_averias_ots_preventivos_sp.sql', 'utf8');

// uspReporteAveriaVincularOrdenTrabajo: add UserId, UserName
f5 = f5.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspReporteAveriaVincularOrdenTrabajo[\s\S]*?AS\s+BEGIN/i,
  `CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaVincularOrdenTrabajo
    @ReportId BIGINT,
    @WorkOrderId NVARCHAR(20),
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN`
);

// uspReporteAveriaRechazar: add Reason
f5 = f5.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspReporteAveriaRechazar[\s\S]*?AS\s+BEGIN/i,
  `CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaRechazar
    @ReportId BIGINT,
    @Reason NVARCHAR(500) = NULL,
    @RejectReason NVARCHAR(500) = NULL,
    @RejectedByUserId INT = NULL,
    @RejectedByUserName NVARCHAR(100) = N''
AS
BEGIN`
);

// uspOrdenTrabajoObtenerTodas: add AreaFilter, return WorkOrderId & aliases
f5 = f5.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspOrdenTrabajoObtenerTodas[\s\S]*?AS\s+BEGIN[\s\S]*?WHERE \(@StatusFilter IS NULL OR ot\.Estado = @StatusFilter\)[\s\S]*?ORDER BY ot\.CreadoEn DESC[\s\S]*?FETCH NEXT CASE WHEN @Limit IS NULL OR @Limit <= 0 THEN 2147483647 ELSE @Limit END ROWS ONLY;\s*END;/i,
  `CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoObtenerTodas
    @StatusFilter   NVARCHAR(15) = NULL,
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
           ra.ImagenUrl AS BreakdownImageData,
           m.MaterialsJson,
           t.WorkTypesCsv,
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
             SELECT NumeroLinea AS LineNum, Descripcion AS Description, Cantidad AS Quantity, Unidad AS Unit
               FROM dbo.MaterialOrdenTrabajo
              WHERE OrdenTrabajoId = ot.OrdenTrabajoId
              ORDER BY NumeroLinea
                FOR JSON PATH
         ) AS MaterialsJson
     ) m
     OUTER APPLY (
         SELECT STRING_AGG(TipoTrabajo, ',') AS WorkTypesCsv
           FROM dbo.TipoTrabajoOrdenTrabajo
          WHERE OrdenTrabajoId = ot.OrdenTrabajoId
     ) t
     WHERE (@StatusFilter IS NULL OR ot.Estado = @StatusFilter)
       AND (@AreaFilter   IS NULL OR ot.AreaId = @AreaFilter)
       AND (@PriorityFilter IS NULL OR ot.Prioridad = @PriorityFilter)
     ORDER BY ot.CreadoEn DESC
     OFFSET @Offset ROWS
     FETCH NEXT CASE WHEN @Limit IS NULL OR @Limit <= 0 THEN 2147483647 ELSE @Limit END ROWS ONLY;
END;`
);

// uspOrdenTrabajoActualizarDetalles: match all API parameters
f5 = f5.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspOrdenTrabajoActualizarDetalles[\s\S]*?AS\s+BEGIN[\s\S]*?WHERE OrdenTrabajoId = @WorkOrderId;\s*END;/i,
  `CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoActualizarDetalles
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
            SELECT @WorkOrderId, LineNum, Description, Quantity, Unit FROM @Materials;
        END;

        IF EXISTS (SELECT 1 FROM @WorkTypes)
        BEGIN
            DELETE FROM dbo.TipoTrabajoOrdenTrabajo WHERE OrdenTrabajoId = @WorkOrderId;
            INSERT INTO dbo.TipoTrabajoOrdenTrabajo (OrdenTrabajoId, TipoTrabajo)
            SELECT @WorkOrderId, Value FROM @WorkTypes;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;`
);

// uspPlanPreventivoObtenerTodos: add AreaFilter and all projection aliases
f5 = f5.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspPlanPreventivoObtenerTodos[\s\S]*?AS\s+BEGIN[\s\S]*?ORDER BY ProximaFecha ASC;\s*END;/i,
  `CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoObtenerTodos
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
END;`
);

// uspPlanPreventivoCrear: add all optional API params
f5 = f5.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspPlanPreventivoCrear[\s\S]*?@Materials\s+dbo\.TipoMaterialPreventivo\s+READONLY\s*AS/i,
  `CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoCrear
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
AS`
);

// uspPlanPreventivoModificar: add ScheduleId, StartDate, AmendmentDocNumber, AuthorizedByManager, AmendmentReason, Materials
f5 = f5.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspPlanPreventivoModificar[\s\S]*?AS\s+BEGIN[\s\S]*?WHERE PlanId = @PlanId;\s*COMMIT TRANSACTION;\s*END TRY/i,
  `CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoModificar
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
    @AuthorizedByManager BIT = 0,
    @AmendmentReason     NVARCHAR(500) = NULL,
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
               NumeroDocumentoModificacion = COALESCE(@AmendmentDocNumber, NumeroDocumentoModificacion),
               ModificadoPor               = COALESCE(@UserName, ModificadoPor),
               ModificadoEn                = SYSUTCDATETIME(),
               MotivoModificacion          = COALESCE(@AmendmentReason, MotivoModificacion)
         WHERE PlanId = @TargetPlan;

        IF EXISTS (SELECT 1 FROM @Materials)
        BEGIN
            DELETE FROM dbo.MaterialPreventivo WHERE PlanId = @TargetPlan;
            INSERT INTO dbo.MaterialPreventivo (PlanId, NumeroLinea, Nombre, Cantidad, Unidad)
            SELECT @TargetPlan, ROW_NUMBER() OVER (ORDER BY LineNum), Name, Quantity, ISNULL(Unit, 'pza')
            FROM @Materials;
        END;

        COMMIT TRANSACTION;
    END TRY`
);

// uspPlanPreventivoRegistrarEjecucion: accept ScheduleId
f5 = f5.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspPlanPreventivoRegistrarEjecucion[\s\S]*?AS\s+BEGIN/i,
  `CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoRegistrarEjecucion
    @ScheduleId NVARCHAR(20) = NULL,
    @PlanId NVARCHAR(20) = NULL,
    @WorkOrderId NVARCHAR(20),
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN`
);
f5 = f5.replace(
  /UPDATE dbo\.PlanPreventivo[\s\S]*?WHERE PlanId = @PlanId;/i,
  `DECLARE @TargetPlanExec NVARCHAR(20) = COALESCE(@ScheduleId, @PlanId);
        UPDATE dbo.PlanPreventivo
           SET UltimaCompletada = SYSUTCDATETIME(),
               UltimaOrdenTrabajoId = @WorkOrderId
         WHERE PlanId = @TargetPlanExec;`
);

// uspPlanPreventivoAlternarEstado: accept ScheduleId, NewStatus, etc.
f5 = f5.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspPlanPreventivoAlternarEstado[\s\S]*?AS\s+BEGIN/i,
  `CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoAlternarEstado
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
BEGIN`
);
f5 = f5.replace(
  /UPDATE dbo\.PlanPreventivo\s+SET Estado = @NuevoEstado/i,
  `DECLARE @TargetPlanAlt NVARCHAR(20) = COALESCE(@ScheduleId, @PlanId);
        DECLARE @TargetStatusAlt NVARCHAR(15) = COALESCE(@NewStatus, @NuevoEstado);
        UPDATE dbo.PlanPreventivo
           SET Estado = @TargetStatusAlt,
               NumeroDocumentoModificacion = COALESCE(@AmendmentDocNumber, NumeroDocumentoModificacion),
               MotivoModificacion = COALESCE(@Reason, @Motivo, MotivoModificacion),
               ModificadoPor = COALESCE(@UserName, ModificadoPor),
               ModificadoEn = SYSUTCDATETIME()`
);
f5 = f5.replace(
  /WHERE PlanId = @PlanId;/i,
  `WHERE PlanId = @TargetPlanAlt;`
);

// uspPlanPreventivoObtenerIndicadores: add AreaId
f5 = f5.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspPlanPreventivoObtenerIndicadores[\s\S]*?AS\s+BEGIN[\s\S]*?FROM dbo\.PlanPreventivo;?\s*END;/i,
  `CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoObtenerIndicadores
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
END;`
);

// Add uspGenerarOrdenTrabajoPreventivaMes & uspGenerarOrdenesTrabajoPreventivasMasivas if not in f5
if (!f5.includes('uspGenerarOrdenTrabajoPreventivaMes')) {
  f5 += `
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
`;
}

fs.writeFileSync('scripts/sql_modules/05_averias_ots_preventivos_sp.sql', f5, 'utf8');

// 3. Update 06_operacion_analitica_kardex_sp.sql
let f6 = fs.readFileSync('scripts/sql_modules/06_operacion_analitica_kardex_sp.sql', 'utf8');

// uspReporteOperacionRegistrar: add extra params
f6 = f6.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspReporteOperacionRegistrar[\s\S]*?AS\s+BEGIN/i,
  `CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionRegistrar
    @CodigoActivo         NVARCHAR(60),
    @FechaOperacion       DATE,
    @HorasTotalesJornada  DECIMAL(5,2) = 24.0,
    @HorasOperacion       DECIMAL(5,2) = 0.0,
    @HorasParoFalla       DECIMAL(5,2) = 0.0,
    @HorasParoMantPrev    DECIMAL(5,2) = 0.0,
    @HorasParoOtros       DECIMAL(5,2) = 0.0,
    @Comentarios          NVARCHAR(500) = NULL,
    @UsuarioId            INT = NULL,
    @NombreUsuario        NVARCHAR(100) = N'',
    @UnidadesProducidas   DECIMAL(12,2) = NULL,
    @UnidadesEsperadas    DECIMAL(12,2) = NULL,
    @UnidadesConformes    DECIMAL(12,2) = NULL,
    @RendimientoDirectoPct DECIMAL(5,2) = NULL,
    @CalidadDirectoPct    DECIMAL(5,2) = NULL
AS
BEGIN`
);

// uspReporteOperacionObtenerPorActivo: add FechaDesde, FechaHasta, Pagina, RegistrosPorPagina
f6 = f6.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspReporteOperacionObtenerPorActivo[\s\S]*?AS\s+BEGIN[\s\S]*?ORDER BY r\.FechaOperacion DESC;\s*END;/i,
  `CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionObtenerPorActivo
    @CodigoActivo       NVARCHAR(60),
    @FechaDesde         DATE = NULL,
    @FechaHasta         DATE = NULL,
    @Pagina             INT = 1,
    @RegistrosPorPagina INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Offset INT = CASE WHEN @Pagina > 1 THEN (@Pagina - 1) * @RegistrosPorPagina ELSE 0 END;

    SELECT
        r.ReporteOpId, r.CodigoActivo, a.Nombre AS NombreActivo, r.AreaId,
        r.FechaOperacion, r.HorasTotalesJornada, r.HorasOperacion,
        r.HorasParoFalla, r.HorasParoMantPrev, r.HorasParoOtros,
        r.DisponibilidadPct, r.Comentarios, r.RegistradoPorNombreUsuario, r.RegistradoEn
    FROM dbo.ReporteOperacionDiaria r
    JOIN dbo.Activo a ON r.CodigoActivo = a.CodigoActivo
    WHERE r.CodigoActivo = @CodigoActivo
      AND (@FechaDesde IS NULL OR r.FechaOperacion >= @FechaDesde)
      AND (@FechaHasta IS NULL OR r.FechaOperacion <= @FechaHasta)
    ORDER BY r.FechaOperacion DESC
    OFFSET @Offset ROWS
    FETCH NEXT @RegistrosPorPagina ROWS ONLY;
END;`
);

// uspReporteOperacionObtenerPorSemana: add LunesDeLaSemana
f6 = f6.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspReporteOperacionObtenerPorSemana[\s\S]*?AS\s+BEGIN/i,
  `CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionObtenerPorSemana
    @AreaId          NVARCHAR(15),
    @LunesDeLaSemana DATE = NULL,
    @FechaInicio     DATE = NULL
AS
BEGIN`
);
f6 = f6.replace(
  /DECLARE @Lunes DATE = DATEADD\(DAY, - \(DATEPART\(WEEKDAY, @FechaInicio\) \+ 5\) % 7, @FechaInicio\);/i,
  `DECLARE @BaseDate DATE = COALESCE(@LunesDeLaSemana, @FechaInicio, CAST(SYSUTCDATETIME() AS DATE));
    DECLARE @Lunes DATE = DATEADD(DAY, - (DATEPART(WEEKDAY, @BaseDate) + 5) % 7, @BaseDate);`
);

// uspReporteOperacionMetricas: add CodigoActivo, FechaDesde, FechaHasta
f6 = f6.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspReporteOperacionMetricas[\s\S]*?AS\s+BEGIN/i,
  `CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionMetricas
    @CodigoActivo NVARCHAR(60) = NULL,
    @FechaDesde   DATE = NULL,
    @FechaHasta   DATE = NULL,
    @FechaInicio  DATE = NULL,
    @FechaFin     DATE = NULL
AS
BEGIN`
);
f6 = f6.replace(
  /WHERE r\.FechaOperacion BETWEEN @FechaInicio AND @FechaFin/i,
  `WHERE (@CodigoActivo IS NULL OR r.CodigoActivo = @CodigoActivo)
      AND r.FechaOperacion BETWEEN COALESCE(@FechaDesde, @FechaInicio, DATEADD(DAY, -30, CAST(SYSUTCDATETIME() AS DATE)))
                               AND COALESCE(@FechaHasta, @FechaFin, CAST(SYSUTCDATETIME() AS DATE))`
);

// Add uspActualizacionAndroidObtenerUltima
if (!f6.includes('uspActualizacionAndroidObtenerUltima')) {
  f6 += `
GO

CREATE OR ALTER PROCEDURE dbo.uspActualizacionAndroidObtenerUltima
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1)
        IdApp,
        VersionApp,
        Fecha,
        Obligatorio
    FROM dbo.ActualizacionesAndroid
    ORDER BY IdApp DESC;
END;
`;
}

fs.writeFileSync('scripts/sql_modules/06_operacion_analitica_kardex_sp.sql', f6, 'utf8');

console.log('Módulos SQL actualizados.');
