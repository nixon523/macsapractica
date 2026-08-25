/* ============================================================================
   MACSA CMMS - Sistema de Gestión de Mantenimiento Grupo Macsa
   init.sql : Creación completa de base de datos SQL Server (T-SQL) en Español
   ============================================================================ */

IF DB_ID(N'MacsaCMMS') IS NULL
BEGIN
    CREATE DATABASE MacsaCMMS COLLATE Latin1_General_CI_AI;
END;
GO
USE MacsaCMMS;
GO

IF DB_NAME() <> N'MacsaCMMS'
BEGIN
    RAISERROR(N'El login actual no tiene acceso a la base de datos MacsaCMMS. Ejecuta como administrador o solicita acceso (rol db_owner).', 16, 1);
    RETURN;
END;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
GO

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'MacsaCMMS')
   AND (SELECT compatibility_level FROM sys.databases WHERE name = N'MacsaCMMS') < 130
BEGIN
    ALTER DATABASE MacsaCMMS SET COMPATIBILITY_LEVEL = 150;
END;
GO

/* ==========================================================================
   LIMPIEZA (re-ejecución segura)
   ========================================================================== */
DROP PROCEDURE IF EXISTS
    dbo.uspUsuarioObtenerParaLogin, dbo.uspLoginRegistrarFallo, dbo.uspLoginReiniciarIntentos, dbo.uspLoginMigrarHash,
    dbo.uspUsuarioCrear, dbo.uspUsuarioActualizar, dbo.uspUsuarioAlternarDeshabilitado,
    dbo.uspUsuarioCambiarPassword, dbo.uspUsuarioReiniciarTemporal,
    dbo.uspSolicitudReinicioPasswordCrear, dbo.uspSolicitudReinicioPasswordListarPendientes, dbo.uspSolicitudReinicioPasswordMarcarResuelta,
    dbo.uspUsuarioObtenerTodos, dbo.uspUsuarioObtenerPorId,
    dbo.uspAreaObtenerTodas, dbo.uspAreaCrear, dbo.uspAreaActualizar,
    dbo.uspActivoObtenerHijos, dbo.uspActivoObtenerRaicesPorArea, dbo.uspActivoBuscar, dbo.uspActivoBuscarPorSerie,
    dbo.uspActivoCrear, dbo.uspActivoActualizar, dbo.uspActivoTraspasar, dbo.uspActivoReactivar,
    dbo.uspActivoAlternarEstado,
    dbo.uspSolicitudBajaCrear, dbo.uspSolicitudBajaObtenerPendientes, dbo.uspSolicitudBajaObtenerTodas,
    dbo.uspSolicitudBajaObtenerPendientePorActivo, dbo.uspSolicitudBajaAprobar, dbo.uspSolicitudBajaRechazar,
    dbo.uspOrdenTrabajoObtenerTodas, dbo.uspOrdenTrabajoObtenerAbiertas, dbo.uspOrdenTrabajoCrear,
    dbo.uspOrdenTrabajoActualizarEstado, dbo.uspOrdenTrabajoActualizarDetalles,
    dbo.uspReporteAveriaCrear, dbo.uspReporteAveriaObtenerTodos, dbo.uspReporteAveriaObtenerPorUsuario,
    dbo.uspReporteAveriaObtenerAbiertos, dbo.uspReporteAveriaVincularOrdenTrabajo,
    dbo.uspReporteAveriaResolver, dbo.uspReporteAveriaRechazar,
    dbo.uspPlanPreventivoObtenerTodos, dbo.uspPlanPreventivoCrear,
    dbo.uspPlanPreventivoModificar, dbo.uspPlanPreventivoRegistrarEjecucion,
    dbo.uspPlanPreventivoAlternarEstado,
    dbo.uspKardexAgregar, dbo.uspKardexObtenerTodos, dbo.uspKardexObtenerPorEntidad,
    dbo.uspDashboardObtenerEstadisticas,
    -- Procedimientos anteriores en inglés
    dbo.uspUserGetForLogin, dbo.uspLoginRegisterFailure, dbo.uspLoginResetAttempts,
    dbo.uspUserCreate, dbo.uspUserUpdate, dbo.uspUserToggleDisabled,
    dbo.uspUserChangePassword, dbo.uspUserResetTemporary,
    dbo.uspPasswordResetRequest, dbo.uspPasswordResetPendingList, dbo.uspPasswordResetMarkResolved,
    dbo.uspUserGetAll, dbo.uspUserGetById,
    dbo.uspAreaGetAll, dbo.uspAssetGetByParent, dbo.uspAssetGetAllByArea, dbo.uspAssetSearch, dbo.uspAssetFindBySerial,
    dbo.uspAssetCreate, dbo.uspAssetUpdate, dbo.uspAssetTransfer, dbo.uspAssetReactivate, dbo.uspAssetToggleStatus,
    dbo.uspDeletionRequestCreate, dbo.uspDeletionRequestGetPending, dbo.uspDeletionRequestGetAll,
    dbo.uspDeletionRequestGetPendingByAsset, dbo.uspDeletionRequestApprove, dbo.uspDeletionRequestReject,
    dbo.uspWorkOrderGetAll, dbo.uspWorkOrderGetOpen, dbo.uspWorkOrderCreate,
    dbo.uspWorkOrderUpdateStatus, dbo.uspWorkOrderUpdateDetails,
    dbo.uspBreakdownReportCreate, dbo.uspBreakdownReportGetAll, dbo.uspBreakdownReportGetByUser,
    dbo.uspBreakdownReportGetOpen, dbo.uspBreakdownReportLinkWorkOrder,
    dbo.uspBreakdownReportResolve, dbo.uspBreakdownReportReject,
    dbo.uspPreventiveScheduleGetAll, dbo.uspPreventiveScheduleCreate,
    dbo.uspPreventiveScheduleAmend, dbo.uspPreventiveScheduleRecordExecution, dbo.uspPreventiveRecordExecution,
    dbo.uspPreventiveScheduleToggleStatus, dbo.uspKardexLogAppend, dbo.uspKardexAppend, dbo.uspDashboardGetStats;
GO

DROP FUNCTION IF EXISTS dbo.fnFrecuenciaDias;
DROP FUNCTION IF EXISTS dbo.fnFrecuenciaEtiqueta;
DROP FUNCTION IF EXISTS dbo.fnFrequencyDays;
DROP FUNCTION IF EXISTS dbo.fnFrequencyLabel;
GO

IF OBJECT_ID(N'dbo.OrdenTrabajo', N'U') IS NOT NULL
    ALTER TABLE dbo.OrdenTrabajo DROP CONSTRAINT IF EXISTS FK_OT_Reporte;
IF OBJECT_ID(N'dbo.ReporteAveria', N'U') IS NOT NULL
    ALTER TABLE dbo.ReporteAveria DROP CONSTRAINT IF EXISTS FK_RA_OrdenTrabajo;
IF OBJECT_ID(N'dbo.WorkOrder', N'U') IS NOT NULL
    ALTER TABLE dbo.WorkOrder DROP CONSTRAINT IF EXISTS FK_WO_Report;
IF OBJECT_ID(N'dbo.BreakdownReport', N'U') IS NOT NULL
    ALTER TABLE dbo.BreakdownReport DROP CONSTRAINT IF EXISTS FK_BR_WorkOrder;
GO

DECLARE @dropFks NVARCHAR(MAX) =
    (SELECT STRING_AGG(N'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id))
                     + N'.' + QUOTENAME(OBJECT_NAME(parent_object_id))
                     + N' DROP CONSTRAINT ' + QUOTENAME(name), N'; ')
       FROM sys.foreign_keys
      WHERE OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo');
IF @dropFks IS NOT NULL EXEC (@dropFks);
GO

DROP TABLE IF EXISTS
    dbo.MaterialPreventivo, dbo.PlanPreventivo, dbo.MaterialOrdenTrabajo, dbo.TipoTrabajoOrdenTrabajo,
    dbo.ReporteAveria, dbo.OrdenTrabajo, dbo.SolicitudBaja, dbo.CandadoBaja,
    dbo.BitacoraKardex, dbo.HistorialEstadoActivo, dbo.Activo, dbo.Area, dbo.UsuarioPermiso,
    dbo.SolicitudReinicioPassword, dbo.Usuario, dbo.RolPermiso, dbo.Permiso, dbo.Rol, dbo.Contador,
    dbo.PreventiveMaterial, dbo.PreventiveSchedule, dbo.WorkOrderMaterial, dbo.WorkOrderWorkType,
    dbo.BreakdownReport, dbo.WorkOrder, dbo.DeletionRequest, dbo.DeletionLock,
    dbo.KardexLog, dbo.AssetStatusHistory, dbo.Asset, dbo.UserPermission,
    dbo.PasswordResetRequest, dbo.AppUser, dbo.RolePermission, dbo.Permission, dbo.Role, dbo.Counter;
GO

DROP TYPE IF EXISTS dbo.TipoListaTexto;
DROP TYPE IF EXISTS dbo.TipoMaterialOrdenTrabajo;
DROP TYPE IF EXISTS dbo.TipoMaterialPreventivo;
DROP TYPE IF EXISTS dbo.StringListType;
DROP TYPE IF EXISTS dbo.WorkOrderMaterialType;
DROP TYPE IF EXISTS dbo.PreventiveMaterialType;
GO

/* ==========================================================================
   1. TABLAS EN ESPAÑOL
   ========================================================================== */
CREATE TABLE dbo.Rol (
    RoleCode        NVARCHAR(20) NOT NULL CONSTRAINT PK_Rol PRIMARY KEY,
    Label           NVARCHAR(50) NOT NULL
);

CREATE TABLE dbo.Permiso (
    PermissionCode  NVARCHAR(50) NOT NULL CONSTRAINT PK_Permiso PRIMARY KEY
);

CREATE TABLE dbo.RolPermiso (
    RoleCode        NVARCHAR(20) NOT NULL,
    PermissionCode  NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_RolPermiso PRIMARY KEY (RoleCode, PermissionCode),
    CONSTRAINT FK_RolPermiso_Rol     FOREIGN KEY (RoleCode)       REFERENCES dbo.Rol(RoleCode),
    CONSTRAINT FK_RolPermiso_Permiso FOREIGN KEY (PermissionCode) REFERENCES dbo.Permiso(PermissionCode)
);

CREATE TABLE dbo.Contador (
    Name        NVARCHAR(30) NOT NULL CONSTRAINT PK_Contador PRIMARY KEY,
    NextNumber  INT          NOT NULL CONSTRAINT DF_Contador_NextNumber DEFAULT (1),
    CONSTRAINT CK_Contador_NextNumber CHECK (NextNumber > 0)
);
GO

CREATE TABLE dbo.Usuario (
    UserId                   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Usuario PRIMARY KEY,
    Username                 NVARCHAR(50)  COLLATE Latin1_General_CI_AI NOT NULL CONSTRAINT UQ_Usuario_Username UNIQUE,
    DisplayName              NVARCHAR(100) NOT NULL,
    RoleCode                 NVARCHAR(20)  NOT NULL,
    PasswordSalt             NVARCHAR(64)  NOT NULL,
    PasswordHash             NVARCHAR(128) NOT NULL,
    PasswordIterations       INT           NOT NULL CONSTRAINT DF_Usuario_Iters DEFAULT (20000),
    Disabled                 BIT           NOT NULL CONSTRAINT DF_Usuario_Disabled DEFAULT (0),
    MustChangePassword       BIT           NOT NULL CONSTRAINT DF_Usuario_MustChange DEFAULT (0),
    PasswordResetRequested   BIT           NOT NULL CONSTRAINT DF_Usuario_ResetReq DEFAULT (0),
    PasswordResetRequestedAt DATETIME2(3)  NULL,
    FailedLoginAttempts      INT           NOT NULL CONSTRAINT DF_Usuario_Failed DEFAULT (0),
    LockedUntil              DATETIME2(3)  NULL,
    CreatedAt                DATETIME2(3)  NOT NULL CONSTRAINT DF_Usuario_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt                DATETIME2(3)  NULL,
    CONSTRAINT CK_Usuario_Iters CHECK (PasswordIterations >= 10000),
    CONSTRAINT FK_Usuario_Rol FOREIGN KEY (RoleCode) REFERENCES dbo.Rol(RoleCode)
);
GO

CREATE TABLE dbo.UsuarioPermiso (
    UserId         INT          NOT NULL,
    PermissionCode NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_UsuarioPermiso PRIMARY KEY (UserId, PermissionCode),
    CONSTRAINT FK_UP_Usuario FOREIGN KEY (UserId) REFERENCES dbo.Usuario(UserId) ON DELETE CASCADE,
    CONSTRAINT FK_UP_Permiso FOREIGN KEY (PermissionCode) REFERENCES dbo.Permiso(PermissionCode)
);

CREATE TABLE dbo.SolicitudReinicioPassword (
    RequestId   BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SolicitudReinicioPassword PRIMARY KEY,
    UserId      INT           NOT NULL,
    Username    NVARCHAR(50)  NOT NULL,
    DisplayName NVARCHAR(100) NOT NULL,
    RoleCode    NVARCHAR(20)  NOT NULL,
    Status      NVARCHAR(15)  NOT NULL CONSTRAINT DF_SRP_Status DEFAULT ('pending'),
    RequestedAt DATETIME2(3)  NOT NULL CONSTRAINT DF_SRP_RequestedAt DEFAULT (SYSUTCDATETIME()),
    Details     NVARCHAR(500) NULL,
    CONSTRAINT CK_SRP_Status CHECK (Status IN ('pending', 'resolved', 'cancelled')),
    CONSTRAINT FK_SRP_Usuario FOREIGN KEY (UserId) REFERENCES dbo.Usuario(UserId)
);

CREATE TABLE dbo.Area (
    AreaId       NVARCHAR(15)  COLLATE Latin1_General_CI_AI NOT NULL CONSTRAINT PK_Area PRIMARY KEY,
    Name         NVARCHAR(100) COLLATE Latin1_General_CI_AI NOT NULL,
    CostCenter   NVARCHAR(50)  NOT NULL,
    AssetCounter INT           NOT NULL CONSTRAINT DF_Area_AssetCounter DEFAULT (0),
    CreatedAt    DATETIME2(3)  NOT NULL CONSTRAINT DF_Area_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt    DATETIME2(3)  NULL
);
GO

CREATE TABLE dbo.Activo (
    AssetCode         NVARCHAR(60) COLLATE Latin1_General_CI_AI NOT NULL CONSTRAINT PK_Activo PRIMARY KEY,
    Name              NVARCHAR(200) COLLATE Latin1_General_CI_AI NOT NULL,
    Brand             NVARCHAR(100) COLLATE Latin1_General_CI_AI NULL,
    Model             NVARCHAR(100) COLLATE Latin1_General_CI_AI NULL,
    AreaId            NVARCHAR(15)  NOT NULL,
    StationId         NVARCHAR(100) NOT NULL CONSTRAINT DF_Activo_StationId DEFAULT (''),
    ParentAssetCode   NVARCHAR(60)  NULL,
    Level             NVARCHAR(20)  NOT NULL,
    AncestorsPath     NVARCHAR(400) NOT NULL CONSTRAINT DF_Activo_AncestorsPath DEFAULT (''),
    Status            NVARCHAR(25)  NOT NULL CONSTRAINT DF_Activo_Status DEFAULT ('active'),
    TransferredToId   NVARCHAR(60)  NULL,
    Serial            NVARCHAR(100) NULL,
    DynamicAttributes NVARCHAR(MAX) NULL,
    ImageData         NVARCHAR(MAX) NULL,
    ChildCounter      INT           NOT NULL CONSTRAINT DF_Activo_ChildCounter DEFAULT (0),
    DeletedAt         DATETIME2(3)  NULL,
    DeletedByUserId   INT           NULL,
    DeletedByUserName NVARCHAR(100) NULL,
    SearchText        AS (CONCAT(AssetCode,' ',Name,' ',Brand,' ',Model,' ',Serial)) PERSISTED,
    CreatedAt         DATETIME2(3)  NOT NULL CONSTRAINT DF_Activo_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt         DATETIME2(3)  NULL,
    RowVersion        ROWVERSION,
    CONSTRAINT CK_Activo_Level   CHECK (Level IN ('equipment','subEquipment','part','subPart')),
    CONSTRAINT CK_Activo_Status  CHECK (Status IN ('active','transferredDeactivated','inactive','deleted')),
    CONSTRAINT CK_Activo_Image   CHECK (ImageData IS NULL OR LEN(ImageData) < 1100000),
    CONSTRAINT CK_Activo_Json    CHECK (DynamicAttributes IS NULL OR ISJSON(DynamicAttributes) = 1),
    CONSTRAINT FK_Activo_Area    FOREIGN KEY (AreaId) REFERENCES dbo.Area(AreaId),
    CONSTRAINT FK_Activo_Padre   FOREIGN KEY (ParentAssetCode) REFERENCES dbo.Activo(AssetCode),
    CONSTRAINT FK_Activo_BajaPor FOREIGN KEY (DeletedByUserId) REFERENCES dbo.Usuario(UserId)
);

CREATE TABLE dbo.HistorialEstadoActivo (
    HistoryId  BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_HistorialEstadoActivo PRIMARY KEY,
    AssetCode  NVARCHAR(60)  NOT NULL,
    Status     NVARCHAR(25)  NOT NULL,
    StartedAt  DATETIME2(3)  NOT NULL,
    EndedAt    DATETIME2(3)  NULL,
    AreaId     NVARCHAR(15)  NOT NULL,
    Reason     NVARCHAR(500) NULL,
    UserId     INT           NULL,
    UserName   NVARCHAR(100) NULL,
    CONSTRAINT CK_HEA_Status CHECK (Status IN ('active','transferredDeactivated','inactive','deleted')),
    CONSTRAINT FK_HEA_Activo  FOREIGN KEY (AssetCode) REFERENCES dbo.Activo(AssetCode),
    CONSTRAINT FK_HEA_Usuario FOREIGN KEY (UserId)    REFERENCES dbo.Usuario(UserId)
);

CREATE TABLE dbo.CandadoBaja (
    AssetCode   NVARCHAR(60) NOT NULL CONSTRAINT PK_CandadoBaja PRIMARY KEY,
    LockStatus  NVARCHAR(10) NOT NULL,
    UpdatedAt   DATETIME2(3) NOT NULL CONSTRAINT DF_CB_UpdatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT CK_CB_Status CHECK (LockStatus IN ('pending','approved','rejected')),
    CONSTRAINT FK_CB_Activo FOREIGN KEY (AssetCode) REFERENCES dbo.Activo(AssetCode)
);

CREATE TABLE dbo.SolicitudBaja (
    RequestId            BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SolicitudBaja PRIMARY KEY,
    AssetCode            NVARCHAR(60)  NOT NULL,
    AssetName            NVARCHAR(200) NOT NULL,
    AreaId               NVARCHAR(15)  NOT NULL,
    Status               NVARCHAR(10)  NOT NULL CONSTRAINT DF_SB_Status DEFAULT ('pending'),
    Reason               NVARCHAR(1000) NOT NULL,
    RequestedByUserId    INT           NOT NULL,
    RequestedByUserName  NVARCHAR(100) NOT NULL,
    RequestedAt          DATETIME2(3)  NOT NULL CONSTRAINT DF_SB_RequestedAt DEFAULT (SYSUTCDATETIME()),
    DecidedByUserId      INT           NULL,
    DecidedByUserName    NVARCHAR(100) NULL,
    DecidedAt            DATETIME2(3)  NULL,
    DecisionReason       NVARCHAR(500) NULL,
    RowVersion           ROWVERSION,
    CONSTRAINT CK_SB_Status CHECK (Status IN ('pending','approved','rejected')),
    CONSTRAINT FK_SB_Activo     FOREIGN KEY (AssetCode)         REFERENCES dbo.Activo(AssetCode),
    CONSTRAINT FK_SB_Area       FOREIGN KEY (AreaId)            REFERENCES dbo.Area(AreaId),
    CONSTRAINT FK_SB_Solicitante FOREIGN KEY (RequestedByUserId) REFERENCES dbo.Usuario(UserId),
    CONSTRAINT FK_SB_Decisor    FOREIGN KEY (DecidedByUserId)   REFERENCES dbo.Usuario(UserId)
);

CREATE TABLE dbo.ReporteAveria (
    ReportId            BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ReporteAveria PRIMARY KEY,
    AssetCode           NVARCHAR(60)  NOT NULL,
    AssetName           NVARCHAR(200) NOT NULL,
    AreaId              NVARCHAR(15)  NOT NULL,
    Description         NVARCHAR(MAX) NOT NULL,
    Severity            NVARCHAR(10)  NOT NULL,
    ReportedByUserId    INT           NULL,
    ReportedByUserName  NVARCHAR(100) NOT NULL,
    ReportedAt          DATETIME2(3)  NOT NULL CONSTRAINT DF_RA_ReportedAt DEFAULT (SYSUTCDATETIME()),
    Status              NVARCHAR(15)  NOT NULL CONSTRAINT DF_RA_Status DEFAULT ('reported'),
    WorkOrderId         NVARCHAR(20)  NULL,
    ResolvedByUserId    INT           NULL,
    ResolvedByUserName  NVARCHAR(100) NULL,
    ResolvedAt          DATETIME2(3)  NULL,
    RejectionReason     NVARCHAR(500) NULL,
    RejectedByUserId    INT           NULL,
    RejectedByUserName  NVARCHAR(100) NULL,
    RejectedAt          DATETIME2(3)  NULL,
    RowVersion          ROWVERSION,
    CONSTRAINT CK_RA_Severity CHECK (Severity IN ('low','medium','high','critical')),
    CONSTRAINT CK_RA_Status   CHECK (Status IN ('reported','inWorkOrder','resolved','rejected','pending','inProgress')),
    CONSTRAINT FK_RA_Activo    FOREIGN KEY (AssetCode)        REFERENCES dbo.Activo(AssetCode),
    CONSTRAINT FK_RA_Reportador FOREIGN KEY (ReportedByUserId) REFERENCES dbo.Usuario(UserId),
    CONSTRAINT FK_RA_Resolutor FOREIGN KEY (ResolvedByUserId) REFERENCES dbo.Usuario(UserId),
    CONSTRAINT FK_RA_Rechazador FOREIGN KEY (RejectedByUserId) REFERENCES dbo.Usuario(UserId)
);

CREATE TABLE dbo.OrdenTrabajo (
    WorkOrderId                NVARCHAR(20)  NOT NULL CONSTRAINT PK_OrdenTrabajo PRIMARY KEY,
    AssetCode                  NVARCHAR(60)  NULL,
    AssetName                  NVARCHAR(200) NOT NULL,
    AreaId                     NVARCHAR(15)  NULL,
    AreaName                   NVARCHAR(200) NULL,
    Description                NVARCHAR(MAX) NOT NULL,
    Status                     NVARCHAR(15)  NOT NULL CONSTRAINT DF_OT_Status DEFAULT ('pending'),
    Priority                   NVARCHAR(10)  NOT NULL CONSTRAINT DF_OT_Priority DEFAULT ('medium'),
    AssignedTo                 NVARCHAR(200) NULL,
    AssignedStaffCount         INT           NULL,
    EstimatedHours             DECIMAL(6,2)  NULL,
    ActualHours                DECIMAL(6,2)  NULL,
    WorkDoneDescription        NVARCHAR(MAX) NULL,
    IsCompleted                BIT           NULL,
    UnfulfillmentReason        NVARCHAR(500) NULL,
    ReprogramDate              DATETIME2(3)  NULL,
    AccHaccpResponsible        NVARCHAR(200) NULL,
    MaintenanceResponsible     NVARCHAR(200) NULL,
    AreaHeadResponsible        NVARCHAR(200) NULL,
    MaintenanceHeadResponsible NVARCHAR(200) NULL,
    ScheduledDate              DATETIME2(3)  NULL,
    ReportId                   BIGINT        NULL,
    CreatedByUserId            INT           NULL,
    CreatedByUserName          NVARCHAR(100) NULL,
    CreatedAt                  DATETIME2(3)  NOT NULL CONSTRAINT DF_OT_CreatedAt DEFAULT (SYSUTCDATETIME()),
    RowVersion                 ROWVERSION,
    CONSTRAINT CK_OT_Status      CHECK (Status IN ('pending','inProgress','completed','cancelled','unfulfilled')),
    CONSTRAINT CK_OT_Priority    CHECK (Priority IN ('low','medium','high')),
    CONSTRAINT CK_OT_Description CHECK (LTRIM(Description) <> ''),
    CONSTRAINT FK_OT_Activo    FOREIGN KEY (AssetCode)        REFERENCES dbo.Activo(AssetCode),
    CONSTRAINT FK_OT_Area      FOREIGN KEY (AreaId)           REFERENCES dbo.Area(AreaId),
    CONSTRAINT FK_OT_Creador   FOREIGN KEY (CreatedByUserId)  REFERENCES dbo.Usuario(UserId),
    CONSTRAINT FK_OT_Reporte   FOREIGN KEY (ReportId)         REFERENCES dbo.ReporteAveria(ReportId)
);

ALTER TABLE dbo.ReporteAveria ADD CONSTRAINT FK_RA_OrdenTrabajo
    FOREIGN KEY (WorkOrderId) REFERENCES dbo.OrdenTrabajo(WorkOrderId);

CREATE TABLE dbo.MaterialOrdenTrabajo (
    WorkOrderId NVARCHAR(20)   NOT NULL,
    LineNum      INT            NOT NULL,
    Description NVARCHAR(200)  NOT NULL,
    Quantity    DECIMAL(10,2)  NOT NULL CONSTRAINT DF_MOT_Quantity DEFAULT (1),
    Unit        NVARCHAR(10)   NOT NULL CONSTRAINT DF_MOT_Unit DEFAULT ('pz'),
    CONSTRAINT PK_MaterialOrdenTrabajo PRIMARY KEY (WorkOrderId, LineNum),
    CONSTRAINT FK_MOT_Orden FOREIGN KEY (WorkOrderId) REFERENCES dbo.OrdenTrabajo(WorkOrderId)
);

CREATE TABLE dbo.TipoTrabajoOrdenTrabajo (
    WorkOrderId NVARCHAR(20) NOT NULL,
    WorkType    NVARCHAR(30) NOT NULL,
    CONSTRAINT PK_TipoTrabajoOrdenTrabajo PRIMARY KEY (WorkOrderId, WorkType),
    CONSTRAINT CK_TTOT_Tipo CHECK (WorkType IN
        ('electric','mechanical','urgency','refrigeration','plumbing','preventive','corrective','scheduled')),
    CONSTRAINT FK_TTOT_Orden FOREIGN KEY (WorkOrderId) REFERENCES dbo.OrdenTrabajo(WorkOrderId)
);
GO

CREATE TABLE dbo.PlanPreventivo (
    ScheduleId         NVARCHAR(20)  NOT NULL CONSTRAINT PK_PlanPreventivo PRIMARY KEY,
    Title              NVARCHAR(200) NOT NULL,
    AssetCode          NVARCHAR(60)  NOT NULL,
    AssetName          NVARCHAR(200) NOT NULL,
    AreaId             NVARCHAR(15)  NOT NULL,
    AreaName           NVARCHAR(200) NOT NULL,
    MaintenanceType    NVARCHAR(100) NOT NULL,
    Frequency          NVARCHAR(15)  NOT NULL,
    Description        NVARCHAR(MAX) NULL,
    EstimatedHours     DECIMAL(6,2)  NULL,
    StartDate          DATETIME2(3)  NOT NULL,
    NextDate           DATETIME2(3)  NOT NULL,
    LastCompleted      DATETIME2(3)  NULL,
    LastWorkOrderId    NVARCHAR(20)  NULL,
    Status             NVARCHAR(10)  NOT NULL CONSTRAINT DF_PP_Status DEFAULT ('active'),
    Notes              NVARCHAR(500) NULL,
    CreatedByUserId    INT           NULL,
    CreatedByUserName  NVARCHAR(100) NULL,
    CreatedAt          DATETIME2(3)  NOT NULL CONSTRAINT DF_PP_CreatedAt DEFAULT (SYSUTCDATETIME()),
    AmendmentDocNumber NVARCHAR(50)  NULL,
    AmendedBy          NVARCHAR(250) NULL,
    AmendedAt          DATETIME2(3)  NULL,
    AmendmentReason    NVARCHAR(500) NULL,
    RowVersion         ROWVERSION,
    CONSTRAINT CK_PP_Frecuencia CHECK (Frequency IN
        ('daily','weekly','biweekly','monthly','bimonthly','quarterly','semiannual','annual',
         'Diaria','Semanal','Quincenal','Mensual','Bimestral','Trimestral','Semestral','Anual',
         'diaria','semanal','quincenal','mensual','bimestral','trimestral','semestral','anual')),
    CONSTRAINT CK_PP_Status CHECK (Status IN ('active','paused','completed')),
    CONSTRAINT FK_PP_Activo   FOREIGN KEY (AssetCode)       REFERENCES dbo.Activo(AssetCode),
    CONSTRAINT FK_PP_Area     FOREIGN KEY (AreaId)          REFERENCES dbo.Area(AreaId),
    CONSTRAINT FK_PP_Creador  FOREIGN KEY (CreatedByUserId) REFERENCES dbo.Usuario(UserId),
    CONSTRAINT FK_PP_UltimaOT FOREIGN KEY (LastWorkOrderId) REFERENCES dbo.OrdenTrabajo(WorkOrderId)
);

CREATE TABLE dbo.MaterialPreventivo (
    ScheduleId NVARCHAR(20)  NOT NULL,
    LineNum     INT           NOT NULL,
    Name       NVARCHAR(200) NOT NULL,
    Quantity   DECIMAL(10,2) NOT NULL CONSTRAINT DF_MP_Quantity DEFAULT (1),
    Unit       NVARCHAR(10)  NOT NULL CONSTRAINT DF_MP_Unit DEFAULT ('pza'),
    CONSTRAINT PK_MaterialPreventivo PRIMARY KEY (ScheduleId, LineNum),
    CONSTRAINT FK_MP_Plan FOREIGN KEY (ScheduleId) REFERENCES dbo.PlanPreventivo(ScheduleId)
);

CREATE TABLE dbo.BitacoraKardex (
    LogId     BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_BitacoraKardex PRIMARY KEY,
    LoggedAt  DATETIME2(3)  NOT NULL CONSTRAINT DF_BK_LoggedAt DEFAULT (SYSUTCDATETIME()),
    UserId    INT           NULL,
    UserName  NVARCHAR(100) NOT NULL,
    Action    NVARCHAR(40)  NOT NULL,
    Module    NVARCHAR(20)  NOT NULL,
    EntityId  NVARCHAR(60)  NOT NULL,
    Details   NVARCHAR(MAX) NOT NULL,
    CONSTRAINT CK_BK_Modulo CHECK (Module IN ('ASSETS','WORK_ORDERS','BREAKDOWNS','PREVENTIVE')),
    CONSTRAINT FK_BK_Usuario FOREIGN KEY (UserId) REFERENCES dbo.Usuario(UserId)
);
GO

/* ==========================================================================
   2. TIPOS DE TABLA (TVPs)
   ========================================================================== */
CREATE TYPE dbo.TipoListaTexto AS TABLE (
    Value NVARCHAR(30) NOT NULL
);
GO

CREATE TYPE dbo.TipoMaterialOrdenTrabajo AS TABLE (
    LineNum     INT            NOT NULL,
    Description NVARCHAR(200)  NOT NULL,
    Quantity    DECIMAL(10,2)  NOT NULL,
    Unit        NVARCHAR(10)   NULL
);
GO

CREATE TYPE dbo.TipoMaterialPreventivo AS TABLE (
    LineNum  INT            NOT NULL,
    Name     NVARCHAR(200)  NOT NULL,
    Quantity DECIMAL(10,2)  NOT NULL,
    Unit     NVARCHAR(10)   NULL
);
GO

CREATE TYPE dbo.StringListType AS TABLE ( Value NVARCHAR(30) NOT NULL );
CREATE TYPE dbo.WorkOrderMaterialType AS TABLE ( LineNum INT NOT NULL, Description NVARCHAR(200) NOT NULL, Quantity DECIMAL(10,2) NOT NULL, Unit NVARCHAR(10) NULL );
CREATE TYPE dbo.PreventiveMaterialType AS TABLE ( LineNum INT NOT NULL, Name NVARCHAR(200) NOT NULL, Quantity DECIMAL(10,2) NOT NULL, Unit NVARCHAR(10) NULL );
GO

/* ==========================================================================
   3. FUNCIONES
   ========================================================================== */
CREATE FUNCTION dbo.fnFrecuenciaDias (@Frecuencia NVARCHAR(15))
RETURNS INT
AS
BEGIN
    RETURN CASE LOWER(LTRIM(RTRIM(@Frecuencia)))
        WHEN 'daily'      THEN 1
        WHEN 'diaria'     THEN 1
        WHEN 'weekly'     THEN 7
        WHEN 'semanal'    THEN 7
        WHEN 'biweekly'   THEN 15
        WHEN 'quincenal'  THEN 15
        WHEN 'monthly'    THEN 30
        WHEN 'mensual'    THEN 30
        WHEN 'bimonthly'  THEN 60
        WHEN 'bimestral'  THEN 60
        WHEN 'quarterly'  THEN 90
        WHEN 'trimestral' THEN 90
        WHEN 'semiannual' THEN 180
        WHEN 'semestral'  THEN 180
        WHEN 'annual'     THEN 365
        WHEN 'anual'      THEN 365
        ELSE 30 END;
END;
GO

CREATE FUNCTION dbo.fnFrecuenciaEtiqueta (@Frecuencia NVARCHAR(15))
RETURNS NVARCHAR(20)
AS
BEGIN
    RETURN CASE LOWER(LTRIM(RTRIM(@Frecuencia)))
        WHEN 'daily'      THEN N'Diaria'
        WHEN 'diaria'     THEN N'Diaria'
        WHEN 'weekly'     THEN N'Semanal'
        WHEN 'semanal'    THEN N'Semanal'
        WHEN 'biweekly'   THEN N'Quincenal'
        WHEN 'quincenal'  THEN N'Quincenal'
        WHEN 'monthly'    THEN N'Mensual'
        WHEN 'mensual'    THEN N'Mensual'
        WHEN 'bimonthly'  THEN N'Bimestral'
        WHEN 'bimestral'  THEN N'Bimestral'
        WHEN 'quarterly'  THEN N'Trimestral'
        WHEN 'trimestral' THEN N'Trimestral'
        WHEN 'semiannual' THEN N'Semestral'
        WHEN 'semestral'  THEN N'Semestral'
        WHEN 'annual'     THEN N'Anual'
        WHEN 'anual'      THEN N'Anual'
        ELSE N'Mensual' END;
END;
GO

CREATE FUNCTION dbo.fnFrequencyDays (@Frequency NVARCHAR(15)) RETURNS INT AS BEGIN RETURN dbo.fnFrecuenciaDias(@Frequency); END;
GO
CREATE FUNCTION dbo.fnFrequencyLabel (@Frequency NVARCHAR(15)) RETURNS NVARCHAR(20) AS BEGIN RETURN dbo.fnFrecuenciaEtiqueta(@Frequency); END;
GO

/* ==========================================================================
   4. ÍNDICES
   ========================================================================== */
CREATE NONCLUSTERED INDEX IX_Activo_Area_Nombre     ON dbo.Activo(AreaId, Name);
CREATE NONCLUSTERED INDEX IX_Activo_Area_Estado     ON dbo.Activo(AreaId, Status, Name);
CREATE NONCLUSTERED INDEX IX_Activo_Serie          ON dbo.Activo(Serial) WHERE Serial IS NOT NULL;
CREATE UNIQUE NONCLUSTERED INDEX UX_HEA_PeriodoAbierto ON dbo.HistorialEstadoActivo(AssetCode) WHERE EndedAt IS NULL;
CREATE NONCLUSTERED INDEX IX_OT_Estado_Fecha       ON dbo.OrdenTrabajo(Status, CreatedAt DESC);
CREATE NONCLUSTERED INDEX IX_OT_Activo_Fecha       ON dbo.OrdenTrabajo(AssetCode, CreatedAt DESC);
CREATE NONCLUSTERED INDEX IX_OT_Area_Fecha         ON dbo.OrdenTrabajo(AreaId, CreatedAt DESC);
CREATE NONCLUSTERED INDEX IX_BK_Entidad_Fecha      ON dbo.BitacoraKardex(EntityId, LoggedAt DESC);
CREATE NONCLUSTERED INDEX IX_BK_Modulo_Fecha       ON dbo.BitacoraKardex(Module, LoggedAt DESC);
CREATE NONCLUSTERED INDEX IX_BK_Usuario_Fecha      ON dbo.BitacoraKardex(UserId, LoggedAt DESC);
CREATE NONCLUSTERED INDEX IX_PP_Area_Estado_Prox   ON dbo.PlanPreventivo(AreaId, Status, NextDate);
CREATE NONCLUSTERED INDEX IX_PP_Estado_Prox        ON dbo.PlanPreventivo(Status, NextDate);
CREATE NONCLUSTERED INDEX IX_SB_Estado_Fecha       ON dbo.SolicitudBaja(Status, RequestedAt DESC);
CREATE NONCLUSTERED INDEX IX_SB_Activo_Estado      ON dbo.SolicitudBaja(AssetCode, Status);
CREATE NONCLUSTERED INDEX IX_RA_Reportador_Fecha   ON dbo.ReporteAveria(ReportedByUserId, ReportedAt DESC);
CREATE NONCLUSTERED INDEX IX_RA_Estado_Fecha       ON dbo.ReporteAveria(Status, ReportedAt DESC);
CREATE NONCLUSTERED INDEX IX_RA_Area_Estado_Fecha  ON dbo.ReporteAveria(AreaId, Status, ReportedAt DESC);
GO

/* ==========================================================================
   5. TRIGGERS DE INTEGRIDAD
   ========================================================================== */
CREATE OR ALTER TRIGGER dbo.trBitacoraKardex_Inmutable
ON dbo.BitacoraKardex
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    RAISERROR(N'La bitácora de Kardex es append-only: no se permite modificar ni eliminar registros.', 16, 1);
    ROLLBACK TRANSACTION;
    RETURN;
END;
GO

CREATE OR ALTER TRIGGER dbo.trActivo_Inmutable
ON dbo.Activo
INSTEAD OF UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
          FROM inserted i
          JOIN deleted d ON i.AssetCode = d.AssetCode
         WHERE i.AreaId          <> d.AreaId
            OR i.Level           <> d.Level
            OR i.AncestorsPath   <> d.AncestorsPath
            OR (i.ParentAssetCode <> d.ParentAssetCode
                OR (i.ParentAssetCode IS NULL AND d.ParentAssetCode IS NOT NULL)
                OR (i.ParentAssetCode IS NOT NULL AND d.ParentAssetCode IS NULL))
            OR (d.Serial IS NOT NULL AND i.Serial <> d.Serial)
    )
    BEGIN
        RAISERROR(N'Violación de inmutabilidad: no se pueden modificar AreaId, Level, AncestorsPath, ParentAssetCode ni Serial tras la creación.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    UPDATE a
       SET Name              = i.Name,
           Brand             = i.Brand,
           Model             = i.Model,
           StationId         = i.StationId,
           Status            = i.Status,
           TransferredToId   = i.TransferredToId,
           Serial            = i.Serial,
           DynamicAttributes = i.DynamicAttributes,
           ImageData         = i.ImageData,
           ChildCounter      = i.ChildCounter,
           DeletedAt         = i.DeletedAt,
           DeletedByUserId   = i.DeletedByUserId,
           DeletedByUserName = i.DeletedByUserName,
           UpdatedAt         = SYSUTCDATETIME()
      FROM dbo.Activo a
      JOIN inserted i ON a.AssetCode = i.AssetCode;
END;
GO

CREATE OR ALTER TRIGGER dbo.trUsuario_NombreInmutable
ON dbo.Usuario
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(Username)
    BEGIN
        IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.UserId = d.UserId WHERE i.Username <> d.Username)
        BEGIN
            RAISERROR(N'El nombre de usuario (Username) es inmutable y no se puede modificar.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;
    END;
END;
GO

/* ==========================================================================
   6. PROCEDIMIENTOS ALMACENADOS EN ESPAÑOL
   ========================================================================== */

-- --- AUTH Y USUARIOS ---
CREATE PROCEDURE dbo.uspUsuarioObtenerParaLogin @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT UserId, Username, DisplayName, RoleCode, PasswordSalt, PasswordHash,
           PasswordIterations, Disabled, MustChangePassword, PasswordResetRequested,
           FailedLoginAttempts, LockedUntil
      FROM dbo.Usuario
     WHERE Username = @Username;
END;
GO

CREATE PROCEDURE dbo.uspLoginRegistrarFallo @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuario
       SET FailedLoginAttempts = FailedLoginAttempts + 1,
           LockedUntil = CASE WHEN FailedLoginAttempts + 1 >= 5
                              THEN DATEADD(MINUTE, 5, SYSUTCDATETIME())
                              ELSE LockedUntil END
     WHERE UserId = @UserId;
END;
GO

CREATE PROCEDURE dbo.uspLoginReiniciarIntentos @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuario
       SET FailedLoginAttempts = 0, LockedUntil = NULL
     WHERE UserId = @UserId;
END;
GO

CREATE PROCEDURE dbo.uspLoginMigrarHash
    @UserId INT, @PasswordSalt NVARCHAR(64), @PasswordHash NVARCHAR(128), @PasswordIterations INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuario
       SET PasswordSalt = @PasswordSalt, PasswordHash = @PasswordHash,
           PasswordIterations = @PasswordIterations, UpdatedAt = SYSUTCDATETIME()
     WHERE UserId = @UserId;
END;
GO

CREATE PROCEDURE dbo.uspUsuarioCrear
    @Username NVARCHAR(50), @DisplayName NVARCHAR(100), @RoleCode NVARCHAR(20),
    @PasswordSalt NVARCHAR(64), @PasswordHash NVARCHAR(128), @PasswordIterations INT = 20000,
    @MustChangePassword BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF EXISTS (SELECT 1 FROM dbo.Usuario WHERE Username = @Username)
        BEGIN
            RAISERROR(N'El nombre de usuario ya está en uso.', 16, 1);
        END;

        INSERT INTO dbo.Usuario
            (Username, DisplayName, RoleCode, PasswordSalt, PasswordHash,
             PasswordIterations, MustChangePassword)
        VALUES
            (@Username, @DisplayName, @RoleCode, @PasswordSalt, @PasswordHash,
             @PasswordIterations, @MustChangePassword);

        DECLARE @uid INT = SCOPE_IDENTITY();

        INSERT INTO dbo.UsuarioPermiso (UserId, PermissionCode)
        SELECT @uid, PermissionCode FROM dbo.RolPermiso WHERE RoleCode = @RoleCode;

        COMMIT TRANSACTION;
        SELECT @uid AS NewUserId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspUsuarioActualizar
    @UserId INT, @DisplayName NVARCHAR(100) = NULL, @NewRoleCode NVARCHAR(20) = NULL,
    @NewSalt NVARCHAR(64) = NULL, @NewHash NVARCHAR(128) = NULL, @NewIterations INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UserId = @UserId)
        BEGIN
            RAISERROR(N'El usuario especificado no existe.', 16, 1);
        END;

        UPDATE dbo.Usuario
           SET DisplayName        = COALESCE(@DisplayName, DisplayName),
               RoleCode           = COALESCE(@NewRoleCode, RoleCode),
               PasswordSalt       = COALESCE(@NewSalt, PasswordSalt),
               PasswordHash       = COALESCE(@NewHash, PasswordHash),
               PasswordIterations = COALESCE(@NewIterations, PasswordIterations),
               UpdatedAt          = SYSUTCDATETIME()
         WHERE UserId = @UserId;

        IF @NewRoleCode IS NOT NULL
        BEGIN
            DELETE FROM dbo.UsuarioPermiso WHERE UserId = @UserId;
            INSERT INTO dbo.UsuarioPermiso (UserId, PermissionCode)
            SELECT @UserId, PermissionCode FROM dbo.RolPermiso WHERE RoleCode = @NewRoleCode;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspUsuarioAlternarDeshabilitado @UserId INT, @Disabled BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuario SET Disabled = @Disabled, UpdatedAt = SYSUTCDATETIME() WHERE UserId = @UserId;
    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR(N'El usuario especificado no existe.', 16, 1);
        RETURN;
    END;
END;
GO

CREATE PROCEDURE dbo.uspUsuarioCambiarPassword
    @UserId INT, @PasswordSalt NVARCHAR(64), @PasswordHash NVARCHAR(128), @PasswordIterations INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuario
       SET PasswordSalt = @PasswordSalt, PasswordHash = @PasswordHash,
           PasswordIterations = @PasswordIterations, MustChangePassword = 0,
           PasswordResetRequested = 0, PasswordResetRequestedAt = NULL,
           FailedLoginAttempts = 0, LockedUntil = NULL, UpdatedAt = SYSUTCDATETIME()
     WHERE UserId = @UserId;
    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR(N'El usuario especificado no existe.', 16, 1);
        RETURN;
    END;
END;
GO

CREATE PROCEDURE dbo.uspUsuarioReiniciarTemporal
    @UserId INT, @PasswordSalt NVARCHAR(64), @PasswordHash NVARCHAR(128), @PasswordIterations INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuario
       SET PasswordSalt = @PasswordSalt, PasswordHash = @PasswordHash,
           PasswordIterations = @PasswordIterations, MustChangePassword = 1,
           PasswordResetRequested = 0, PasswordResetRequestedAt = NULL,
           FailedLoginAttempts = 0, LockedUntil = NULL, UpdatedAt = SYSUTCDATETIME()
     WHERE UserId = @UserId;
    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR(N'El usuario especificado no existe.', 16, 1);
        RETURN;
    END;
END;
GO

CREATE PROCEDURE dbo.uspSolicitudReinicioPasswordCrear @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @UserId INT, @DisplayName NVARCHAR(100), @RoleCode NVARCHAR(20), @AlreadyRequested BIT;
    SELECT @UserId = UserId, @DisplayName = DisplayName, @RoleCode = RoleCode,
           @AlreadyRequested = PasswordResetRequested
      FROM dbo.Usuario WHERE Username = @Username;

    IF @UserId IS NULL
    BEGIN
        RAISERROR(N'Usuario no encontrado.', 16, 1);
        RETURN;
    END;

    IF @AlreadyRequested = 0
    BEGIN
        UPDATE dbo.Usuario
           SET PasswordResetRequested = 1, PasswordResetRequestedAt = SYSUTCDATETIME()
         WHERE UserId = @UserId;

        INSERT INTO dbo.SolicitudReinicioPassword (UserId, Username, DisplayName, RoleCode, Status, Details)
        VALUES (@UserId, @Username, @DisplayName, @RoleCode, 'pending', N'Solicitud enviada desde pantalla de login.');
    END;
END;
GO

CREATE PROCEDURE dbo.uspSolicitudReinicioPasswordListarPendientes
AS
BEGIN
    SET NOCOUNT ON;
    SELECT RequestId, UserId, Username, DisplayName, RoleCode, RequestedAt, Details
      FROM dbo.SolicitudReinicioPassword
     WHERE Status = 'pending'
     ORDER BY RequestedAt DESC;
END;
GO

CREATE PROCEDURE dbo.uspSolicitudReinicioPasswordMarcarResuelta @RequestId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.SolicitudReinicioPassword SET Status = 'resolved'
     WHERE RequestId = @RequestId AND Status = 'pending';
    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR(N'La solicitud ya fue procesada.', 16, 1);
        RETURN;
    END;
END;
GO

CREATE PROCEDURE dbo.uspUsuarioObtenerTodos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT UserId, Username, DisplayName, RoleCode, Disabled, MustChangePassword,
           PasswordResetRequested, PasswordResetRequestedAt, CreatedAt
      FROM dbo.Usuario
     ORDER BY Username;
END;
GO

CREATE PROCEDURE dbo.uspUsuarioObtenerPorId @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UserId, u.Username, u.DisplayName, u.RoleCode, u.PasswordSalt, u.PasswordHash,
           u.PasswordIterations, u.Disabled, u.MustChangePassword, u.PasswordResetRequested,
           u.PasswordResetRequestedAt, u.FailedLoginAttempts, u.LockedUntil, u.CreatedAt,
           (SELECT STRING_AGG(PermissionCode, ',') FROM dbo.UsuarioPermiso WHERE UserId = u.UserId) AS PermissionsCsv
      FROM dbo.Usuario u
     WHERE u.UserId = @UserId;
END;
GO

-- --- ÁREAS ---
CREATE PROCEDURE dbo.uspAreaObtenerTodas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT AreaId, Name, CostCenter, AssetCounter, CreatedAt, UpdatedAt
      FROM dbo.Area
     ORDER BY AreaId ASC;
END;
GO

CREATE PROCEDURE dbo.uspAreaCrear
    @Name NVARCHAR(100), @CostCenter NVARCHAR(50), @AreaId NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @NormCC NVARCHAR(50) =
            CASE WHEN @CostCenter LIKE 'CC-%' THEN @CostCenter ELSE CONCAT('CC-', @CostCenter) END;

        DECLARE @FinalId NVARCHAR(15) = @AreaId;
        IF @FinalId IS NULL OR LTRIM(RTRIM(@FinalId)) = ''
        BEGIN
            DECLARE @cnt TABLE (val INT NOT NULL);
            UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
               SET NextNumber += 1
             OUTPUT inserted.NextNumber INTO @cnt(val)
              WHERE Name = 'areas';

            DECLARE @nextVal INT; SELECT @nextVal = val FROM @cnt;
            SET @FinalId = CONCAT('A', @nextVal);
        END;

        IF EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @FinalId)
        BEGIN
            RAISERROR(N'Ya existe un área con ese identificador.', 16, 1);
        END;

        INSERT INTO dbo.Area (AreaId, Name, CostCenter, AssetCounter, CreatedAt)
        VALUES (@FinalId, @Name, @NormCC, 0, SYSUTCDATETIME());

        COMMIT TRANSACTION;
        SELECT @FinalId AS AreaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspAreaActualizar
    @AreaId NVARCHAR(15), @Name NVARCHAR(100), @CostCenter NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @NormCC NVARCHAR(50) =
        CASE WHEN @CostCenter IS NULL THEN NULL
             WHEN @CostCenter LIKE 'CC-%' THEN @CostCenter
             ELSE CONCAT('CC-', @CostCenter) END;

    UPDATE dbo.Area
       SET Name       = @Name,
           CostCenter = COALESCE(@NormCC, CostCenter),
           UpdatedAt  = SYSUTCDATETIME()
     WHERE AreaId = @AreaId;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR(N'El área especificada no existe.', 16, 1);
        RETURN;
    END;
END;
GO

-- --- ACTIVOS ---
CREATE PROCEDURE dbo.uspActivoObtenerRaicesPorArea @AreaId NVARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.Activo
     WHERE AreaId = @AreaId AND ParentAssetCode IS NULL AND Status <> 'deleted'
     ORDER BY Name ASC;
END;
GO

CREATE PROCEDURE dbo.uspActivoObtenerHijos
    @AreaId NVARCHAR(15) = NULL, @ParentAssetCode NVARCHAR(60) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.Activo
     WHERE (@AreaId IS NULL OR AreaId = @AreaId)
       AND ((@ParentAssetCode IS NULL AND ParentAssetCode IS NULL) OR ParentAssetCode = @ParentAssetCode)
       AND Status <> 'deleted'
     ORDER BY Name ASC;
END;
GO

CREATE PROCEDURE dbo.uspActivoBuscar
    @AreaId NVARCHAR(15) = NULL, @Query NVARCHAR(200), @Status NVARCHAR(25) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT a.*
      FROM dbo.Activo a
     CROSS APPLY (SELECT COUNT(*) AS TokenCount FROM STRING_SPLIT(@Query, ' ') WHERE LTRIM(RTRIM(value)) <> '') cnt
     WHERE (@AreaId IS NULL OR a.AreaId = @AreaId)
       AND a.Status <> 'deleted'
       AND (@Status IS NULL OR a.Status = @Status)
       AND (cnt.TokenCount = 0 OR
            (SELECT COUNT(*) FROM STRING_SPLIT(@Query, ' ') t
              WHERE t.value <> '' AND a.SearchText LIKE '%' + t.value + '%') = cnt.TokenCount)
     ORDER BY a.Name ASC;
END;
GO

CREATE PROCEDURE dbo.uspActivoBuscarPorSerie @Serial NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) * FROM dbo.Activo
     WHERE Serial = @Serial AND Status <> 'deleted'
     ORDER BY CASE WHEN Status = 'active' THEN 0 ELSE 1 END, CreatedAt DESC;
END;
GO

CREATE PROCEDURE dbo.uspActivoCrear
    @Name NVARCHAR(200), @Brand NVARCHAR(100) = NULL, @Model NVARCHAR(100) = NULL,
    @AreaId NVARCHAR(15), @StationId NVARCHAR(100) = '', @Level NVARCHAR(20),
    @ParentAssetCode NVARCHAR(60) = NULL, @Status NVARCHAR(25) = 'active',
    @Serial NVARCHAR(100) = NULL, @DynamicAttributes NVARCHAR(MAX) = NULL,
    @ImageData NVARCHAR(MAX) = NULL,
    @UserId INT = NULL, @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Serial IS NOT NULL AND LTRIM(RTRIM(@Serial)) <> ''
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Activo WHERE Serial = @Serial AND Status <> 'deleted')
            BEGIN
                RAISERROR(N'El número de serie ya está en uso por otro activo activo.', 16, 1);
            END;
        END;

        DECLARE @NewAssetCode NVARCHAR(60);
        DECLARE @AncestorsPath NVARCHAR(400) = '';

        IF @ParentAssetCode IS NULL OR LTRIM(RTRIM(@ParentAssetCode)) = ''
        BEGIN
            DECLARE @acTable TABLE (val INT NOT NULL);
            UPDATE dbo.Area WITH (UPDLOCK, HOLDLOCK)
               SET AssetCounter += 1
             OUTPUT inserted.AssetCounter INTO @acTable(val)
              WHERE AreaId = @AreaId;

            DECLARE @ac INT; SELECT @ac = val FROM @acTable;
            IF @ac IS NULL
            BEGIN
                RAISERROR(N'El área no existe.', 16, 1);
            END;

            SET @NewAssetCode = CONCAT(@AreaId, '-', FORMAT(@ac, '000'));
        END
        ELSE
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE AssetCode = @ParentAssetCode AND LockStatus = 'pending')
            BEGIN
                RAISERROR(N'El activo padre tiene una solicitud de baja pendiente.', 16, 1);
            END;

            DECLARE @parentStatus NVARCHAR(25), @parentPath NVARCHAR(400);
            DECLARE @ccTable TABLE (val INT NOT NULL);

            UPDATE dbo.Activo WITH (UPDLOCK, HOLDLOCK)
               SET ChildCounter += 1
             OUTPUT inserted.ChildCounter INTO @ccTable(val)
              WHERE AssetCode = @ParentAssetCode;

            SELECT @parentStatus = Status, @parentPath = AncestorsPath
              FROM dbo.Activo WHERE AssetCode = @ParentAssetCode;

            IF @parentStatus IS NULL OR @parentStatus = 'deleted'
            BEGIN
                RAISERROR(N'El activo padre no existe o está eliminado.', 16, 1);
            END;

            DECLARE @cc INT; SELECT @cc = val FROM @ccTable;
            SET @NewAssetCode = CONCAT(@ParentAssetCode, '-', FORMAT(@cc, '00'));
            SET @AncestorsPath = CASE WHEN @parentPath = '' THEN @ParentAssetCode ELSE CONCAT(@parentPath, ',', @ParentAssetCode) END;
        END;

        INSERT INTO dbo.Activo
            (AssetCode, Name, Brand, Model, AreaId, StationId, ParentAssetCode,
             Level, AncestorsPath, Status, Serial, DynamicAttributes, ImageData,
             ChildCounter, CreatedAt)
        VALUES
            (@NewAssetCode, @Name, @Brand, @Model, @AreaId, ISNULL(@StationId, ''),
             @ParentAssetCode, @Level, @AncestorsPath, @Status, @Serial,
             @DynamicAttributes, @ImageData, 0, SYSUTCDATETIME());

        INSERT INTO dbo.HistorialEstadoActivo (AssetCode, Status, StartedAt, AreaId, Reason, UserId, UserName)
        VALUES (@NewAssetCode, @Status, SYSUTCDATETIME(), @AreaId, N'Alta inicial del activo', @UserId, @UserName);

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@UserId, @UserName, 'ASSET_CREATED', 'ASSETS', @NewAssetCode,
                CONCAT(N'Activo ', @NewAssetCode, N' (', @Name, N') creado en área ', @AreaId, N'.'));

        COMMIT TRANSACTION;
        SELECT @NewAssetCode AS NewAssetCode;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspActivoActualizar
    @AssetCode NVARCHAR(60), @Name NVARCHAR(200), @Brand NVARCHAR(100) = NULL,
    @Model NVARCHAR(100) = NULL, @StationId NVARCHAR(100) = '', @Status NVARCHAR(25),
    @DynamicAttributes NVARCHAR(MAX) = NULL, @ImageData NVARCHAR(MAX) = NULL,
    @UserId INT = NULL, @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE AssetCode = @AssetCode AND LockStatus = 'pending')
        BEGIN
            RAISERROR(N'El activo tiene una solicitud de baja pendiente.', 16, 1);
        END;

        UPDATE dbo.Activo
           SET Name = @Name, Brand = @Brand, Model = @Model, StationId = ISNULL(@StationId, ''),
               Status = @Status, DynamicAttributes = @DynamicAttributes, ImageData = @ImageData,
               UpdatedAt = SYSUTCDATETIME()
         WHERE AssetCode = @AssetCode AND Status <> 'deleted';

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR(N'El activo no existe o está eliminado.', 16, 1);
        END;

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@UserId, @UserName, 'ASSET_UPDATED', 'ASSETS', @AssetCode,
                CONCAT(N'Activo ', @AssetCode, N' (', @Name, N') actualizado.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspActivoTraspasar
    @SourceAssetCode NVARCHAR(60), @TargetAreaId NVARCHAR(15),
    @UserId INT = NULL, @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @srcArea NVARCHAR(15), @srcName NVARCHAR(200), @srcStatus NVARCHAR(25);
        SELECT @srcArea = AreaId, @srcName = Name, @srcStatus = Status
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE AssetCode = @SourceAssetCode;

        IF @srcArea IS NULL OR @srcStatus = 'deleted'
        BEGIN
            RAISERROR(N'El activo origen no existe o está eliminado.', 16, 1);
        END;
        IF @srcArea = @TargetAreaId
        BEGIN
            RAISERROR(N'El área destino debe ser distinta al área actual.', 16, 1);
        END;

        DECLARE @targetCounter TABLE (val INT NOT NULL);
        UPDATE dbo.Area WITH (UPDLOCK, HOLDLOCK)
           SET AssetCounter += 1
         OUTPUT inserted.AssetCounter INTO @targetCounter(val)
          WHERE AreaId = @TargetAreaId;

        DECLARE @nextRoot INT; SELECT @nextRoot = val FROM @targetCounter;
        IF @nextRoot IS NULL
        BEGIN
            RAISERROR(N'El área destino no existe.', 16, 1);
        END;

        DECLARE @newRootCode NVARCHAR(60) = CONCAT(@TargetAreaId, '-', FORMAT(@nextRoot, '000'));

        INSERT INTO dbo.Activo
            (AssetCode, Name, Brand, Model, AreaId, StationId, ParentAssetCode,
             Level, AncestorsPath, Status, Serial, DynamicAttributes, ImageData, ChildCounter, CreatedAt)
        SELECT @newRootCode, Name, Brand, Model, @TargetAreaId, StationId, NULL,
               Level, '', 'active', Serial, DynamicAttributes, ImageData, ChildCounter, SYSUTCDATETIME()
          FROM dbo.Activo WHERE AssetCode = @SourceAssetCode;

        UPDATE dbo.Activo
           SET Status = 'transferredDeactivated', TransferredToId = @newRootCode, UpdatedAt = SYSUTCDATETIME()
         WHERE AssetCode = @SourceAssetCode;

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@UserId, @UserName, 'ASSET_TRANSFER', 'ASSETS', @SourceAssetCode,
                CONCAT(N'Activo ', @SourceAssetCode, N' traspasado a ', @TargetAreaId, N' como ', @newRootCode, N'.'));

        COMMIT TRANSACTION;
        SELECT @newRootCode AS NewAssetCode;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspActivoReactivar
    @AssetCode NVARCHAR(60), @UserId INT = NULL, @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.Activo
           SET Status = 'active', TransferredToId = NULL, UpdatedAt = SYSUTCDATETIME()
         WHERE AssetCode = @AssetCode AND Status = 'transferredDeactivated';

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR(N'Solo se pueden reactivar activos en estado desactivado por traspaso.', 16, 1);
        END;

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@UserId, @UserName, 'ASSET_REACTIVATE', 'ASSETS', @AssetCode,
                CONCAT(N'Activo ', @AssetCode, N' reactivado en su área original.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspActivoAlternarEstado
    @AssetCode NVARCHAR(60), @NewStatus NVARCHAR(25), @Reason NVARCHAR(500) = NULL,
    @UserId INT = NULL, @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @AreaId NVARCHAR(15);
        SELECT @AreaId = AreaId FROM dbo.Activo WHERE AssetCode = @AssetCode;
        IF @AreaId IS NULL
        BEGIN
            RAISERROR(N'El activo no existe.', 16, 1);
        END;

        UPDATE dbo.HistorialEstadoActivo SET EndedAt = SYSUTCDATETIME()
         WHERE AssetCode = @AssetCode AND EndedAt IS NULL;

        UPDATE dbo.Activo SET Status = @NewStatus, UpdatedAt = SYSUTCDATETIME()
         WHERE AssetCode = @AssetCode;

        INSERT INTO dbo.HistorialEstadoActivo (AssetCode, Status, StartedAt, AreaId, Reason, UserId, UserName)
        VALUES (@AssetCode, @NewStatus, SYSUTCDATETIME(), @AreaId, @Reason, @UserId, @UserName);

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@UserId, @UserName, 'ASSET_STATUS_CHANGED', 'ASSETS', @AssetCode,
                CONCAT(N'Estado de ', @AssetCode, N' cambiado a ', @NewStatus, N'. Motivo: ', ISNULL(@Reason, N'N/A')));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- --- SOLICITUDES DE BAJA ---
CREATE PROCEDURE dbo.uspSolicitudBajaCrear
    @AssetCode NVARCHAR(60), @Reason NVARCHAR(1000),
    @UserId INT, @UserName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @AssetName NVARCHAR(200), @AreaId NVARCHAR(15), @Status NVARCHAR(25);
        SELECT @AssetName = Name, @AreaId = AreaId, @Status = Status
          FROM dbo.Activo WHERE AssetCode = @AssetCode;

        IF @AssetName IS NULL OR @Status = 'deleted'
        BEGIN
            RAISERROR(N'El activo no existe o ya está eliminado.', 16, 1);
        END;

        IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE AssetCode = @AssetCode AND LockStatus = 'pending')
        BEGIN
            RAISERROR(N'El activo ya tiene una solicitud de baja pendiente.', 16, 1);
        END;

        INSERT INTO dbo.SolicitudBaja (AssetCode, AssetName, AreaId, Status, Reason, RequestedByUserId, RequestedByUserName)
        VALUES (@AssetCode, @AssetName, @AreaId, 'pending', @Reason, @UserId, @UserName);
        DECLARE @rid BIGINT = SCOPE_IDENTITY();

        IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE AssetCode = @AssetCode)
            UPDATE dbo.CandadoBaja SET LockStatus = 'pending', UpdatedAt = SYSUTCDATETIME() WHERE AssetCode = @AssetCode;
        ELSE
            INSERT INTO dbo.CandadoBaja (AssetCode, LockStatus) VALUES (@AssetCode, 'pending');

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@UserId, @UserName, 'ASSET_DELETE_REQUESTED', 'ASSETS', @AssetCode,
                CONCAT(N'Solicitud de baja ', @rid, N' creada para ', @AssetCode, N'. Motivo: "', @Reason, N'".'));

        COMMIT TRANSACTION;
        SELECT @rid AS NewRequestId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspSolicitudBajaObtenerPendientes
    @StartDate DATETIME2(3) = NULL, @EndDate DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.SolicitudBaja
     WHERE Status = 'pending'
       AND (@StartDate IS NULL OR RequestedAt >= @StartDate)
       AND (@EndDate   IS NULL OR RequestedAt <= @EndDate)
     ORDER BY RequestedAt DESC;
END;
GO

CREATE PROCEDURE dbo.uspSolicitudBajaObtenerTodas
    @StartDate DATETIME2(3) = NULL, @EndDate DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.SolicitudBaja
     WHERE (@StartDate IS NULL OR RequestedAt >= @StartDate)
       AND (@EndDate   IS NULL OR RequestedAt <= @EndDate)
     ORDER BY RequestedAt DESC;
END;
GO

CREATE PROCEDURE dbo.uspSolicitudBajaObtenerPendientePorActivo @AssetCode NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) * FROM dbo.SolicitudBaja
     WHERE AssetCode = @AssetCode AND Status = 'pending'
     ORDER BY RequestedAt DESC;
END;
GO

CREATE PROCEDURE dbo.uspSolicitudBajaAprobar
    @RequestId BIGINT, @ApproverUserId INT = NULL, @ApproverUserName NVARCHAR(100) = N'',
    @ApproveReason NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @c NVARCHAR(60), @nm NVARCHAR(200), @ar NVARCHAR(15), @st NVARCHAR(10);
        SELECT @c = AssetCode, @nm = AssetName, @ar = AreaId, @st = Status
          FROM dbo.SolicitudBaja WITH (UPDLOCK, HOLDLOCK) WHERE RequestId = @RequestId;

        IF @c IS NULL OR @st <> 'pending'
        BEGIN
            RAISERROR(N'Esta solicitud ya fue resuelta o no está pendiente.', 16, 1);
        END;

        UPDATE a
           SET Status = 'deleted', DeletedAt = SYSUTCDATETIME(),
               DeletedByUserId = @ApproverUserId, DeletedByUserName = @ApproverUserName,
               UpdatedAt = SYSUTCDATETIME()
          FROM dbo.Activo a
         WHERE a.AreaId = @ar AND a.Status <> 'deleted'
           AND (a.AssetCode = @c OR CHARINDEX(CONCAT(N',', @c, N','), CONCAT(N',', a.AncestorsPath, N',')) > 0);

        UPDATE dbo.SolicitudBaja
           SET Status = 'approved', DecidedByUserId = @ApproverUserId,
               DecidedByUserName = @ApproverUserName, DecidedAt = SYSUTCDATETIME(),
               DecisionReason = COALESCE(@ApproveReason, N'')
         WHERE RequestId = @RequestId;

        UPDATE dbo.CandadoBaja SET LockStatus = 'approved', UpdatedAt = SYSUTCDATETIME() WHERE AssetCode = @c;

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@ApproverUserId, @ApproverUserName, 'ASSET_DELETED', 'ASSETS', @c,
                CONCAT(N'Aprobada la solicitud de baja ', @RequestId, N' para ', @c, N' (', @nm, N').'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspSolicitudBajaRechazar
    @RequestId BIGINT, @RejectedByUserId INT = NULL, @RejectedByUserName NVARCHAR(100) = N'',
    @RejectReason NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @c NVARCHAR(60), @nm NVARCHAR(200), @st NVARCHAR(10);
        SELECT @c = AssetCode, @nm = AssetName, @st = Status
          FROM dbo.SolicitudBaja WITH (UPDLOCK, HOLDLOCK) WHERE RequestId = @RequestId;

        IF @c IS NULL OR @st <> 'pending'
        BEGIN
            RAISERROR(N'Esta solicitud ya no está pendiente de resolución.', 16, 1);
        END;

        UPDATE dbo.SolicitudBaja
           SET Status = 'rejected', DecidedByUserId = @RejectedByUserId,
               DecidedByUserName = @RejectedByUserName, DecidedAt = SYSUTCDATETIME(),
               DecisionReason = @RejectReason
         WHERE RequestId = @RequestId;

        UPDATE dbo.CandadoBaja SET LockStatus = 'rejected', UpdatedAt = SYSUTCDATETIME() WHERE AssetCode = @c;

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@RejectedByUserId, @RejectedByUserName, 'ASSET_DELETE_REJECTED', 'ASSETS', @c,
                CONCAT(N'Rechazada la solicitud ', @RequestId, N' para ', @c, N': "', @RejectReason, N'".'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- --- ÓRDENES DE TRABAJO ---
CREATE PROCEDURE dbo.uspOrdenTrabajoObtenerTodas
    @StatusFilter NVARCHAR(15) = NULL, @AreaFilter NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.*,
           m.MaterialsJson,
           t.WorkTypesCsv
      FROM dbo.OrdenTrabajo w
     OUTER APPLY (SELECT (SELECT LineNum, Description, Quantity, Unit
                            FROM dbo.MaterialOrdenTrabajo
                           WHERE WorkOrderId = w.WorkOrderId
                           ORDER BY LineNum
                             FOR JSON PATH) AS MaterialsJson) m
     OUTER APPLY (SELECT STRING_AGG(WorkType, ',') AS WorkTypesCsv
                    FROM dbo.TipoTrabajoOrdenTrabajo
                   WHERE WorkOrderId = w.WorkOrderId) t
     WHERE (@StatusFilter IS NULL OR w.Status = @StatusFilter)
       AND (@AreaFilter   IS NULL OR w.AreaId = @AreaFilter)
     ORDER BY w.CreatedAt DESC;
END;
GO

CREATE PROCEDURE dbo.uspOrdenTrabajoObtenerAbiertas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.OrdenTrabajo
     WHERE Status IN ('pending', 'inProgress')
     ORDER BY CreatedAt DESC;
END;
GO

CREATE PROCEDURE dbo.uspOrdenTrabajoCrear
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
        DECLARE @cCount TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET NextNumber += 1
         OUTPUT deleted.NextNumber INTO @cCount(v)
          WHERE Name = 'work_orders';

        DECLARE @seq INT; SELECT @seq = v FROM @cCount;
        DECLARE @woId NVARCHAR(20) = CONCAT('OT-', YEAR(SYSUTCDATETIME()), '-', FORMAT(@seq, '0000'));

        INSERT INTO dbo.OrdenTrabajo
            (WorkOrderId, AssetCode, AssetName, AreaId, AreaName, Description,
             Status, Priority, AssignedTo, AssignedStaffCount, EstimatedHours,
             ScheduledDate, ReportId, CreatedByUserId, CreatedByUserName, CreatedAt)
        VALUES
            (@woId, NULLIF(@AssetCode, ''), @AssetName, @AreaId, @AreaName, @Description,
             'pending', @Priority, @AssignedTo, @AssignedStaffCount, @EstimatedHours,
             @ScheduledDate, @ReportId, @CreatedByUserId, @CreatedByUserName, SYSUTCDATETIME());

        INSERT INTO dbo.MaterialOrdenTrabajo (WorkOrderId, LineNum, Description, Quantity, Unit)
        SELECT @woId, ROW_NUMBER() OVER (ORDER BY LineNum), Description, Quantity, ISNULL(Unit, 'pz')
          FROM @Materials;

        INSERT INTO dbo.TipoTrabajoOrdenTrabajo (WorkOrderId, WorkType)
        SELECT DISTINCT @woId, LTRIM(RTRIM(Value)) FROM @WorkTypes WHERE LTRIM(RTRIM(Value)) <> '';

        IF @ReportId IS NOT NULL
        BEGIN
            UPDATE dbo.ReporteAveria SET Status = 'inWorkOrder', WorkOrderId = @woId WHERE ReportId = @ReportId;
        END;

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@CreatedByUserId, @CreatedByUserName, 'WORK_ORDER_CREATED', 'WORK_ORDERS', @woId,
                CONCAT(N'Orden de trabajo ', @woId, N' creada para ', @AssetName, N'.'));

        COMMIT TRANSACTION;
        SELECT @woId AS WorkOrderNumber, @woId AS NewWorkOrderId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspOrdenTrabajoActualizarEstado
    @WorkOrderId NVARCHAR(20), @NewStatus NVARCHAR(15),
    @UserId INT = NULL, @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @cur NVARCHAR(15), @rid BIGINT;
        SELECT @cur = Status, @rid = ReportId FROM dbo.OrdenTrabajo WITH (UPDLOCK, HOLDLOCK)
         WHERE WorkOrderId = @WorkOrderId;

        IF @cur IS NULL
        BEGIN
            RAISERROR(N'La orden de trabajo ya no existe.', 16, 1);
        END;

        UPDATE dbo.OrdenTrabajo SET Status = @NewStatus WHERE WorkOrderId = @WorkOrderId;

        IF @NewStatus = 'completed' AND @rid IS NOT NULL
            UPDATE dbo.ReporteAveria SET Status = 'resolved', ResolvedByUserId = @UserId, ResolvedByUserName = @UserName, ResolvedAt = SYSUTCDATETIME() WHERE ReportId = @rid;
        ELSE IF @NewStatus = 'cancelled' AND @rid IS NOT NULL
            UPDATE dbo.ReporteAveria SET Status = 'reported', WorkOrderId = NULL WHERE ReportId = @rid;

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@UserId, @UserName, 'WORK_ORDER_STATUS_CHANGED', 'WORK_ORDERS', @WorkOrderId,
                CONCAT(N'OT ', @WorkOrderId, N': estado "', @cur, N'" -> "', @NewStatus, N'".'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspOrdenTrabajoActualizarDetalles
    @WorkOrderId NVARCHAR(20), @Description NVARCHAR(MAX), @Priority NVARCHAR(10),
    @AssignedTo NVARCHAR(200) = NULL, @AssignedStaffCount INT = NULL,
    @EstimatedHours DECIMAL(6,2) = NULL, @ActualHours DECIMAL(6,2) = NULL,
    @WorkDoneDescription NVARCHAR(MAX) = NULL, @IsCompleted BIT = NULL,
    @UnfulfillmentReason NVARCHAR(500) = NULL, @ReprogramDate DATETIME2(3) = NULL,
    @AccHaccpResponsible NVARCHAR(200) = NULL, @MaintenanceResponsible NVARCHAR(200) = NULL,
    @ScheduledDate DATETIME2(3) = NULL,
    @UserId INT = NULL, @UserName NVARCHAR(100) = N'',
    @Materials dbo.TipoMaterialOrdenTrabajo READONLY,
    @WorkTypes dbo.TipoListaTexto READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.OrdenTrabajo
           SET Description = @Description, Priority = @Priority,
               AssignedTo = @AssignedTo, AssignedStaffCount = @AssignedStaffCount,
               EstimatedHours = @EstimatedHours, ActualHours = @ActualHours,
               WorkDoneDescription = @WorkDoneDescription, IsCompleted = @IsCompleted,
               UnfulfillmentReason = @UnfulfillmentReason, ReprogramDate = @ReprogramDate,
               AccHaccpResponsible = @AccHaccpResponsible, MaintenanceResponsible = @MaintenanceResponsible,
               ScheduledDate = @ScheduledDate
         WHERE WorkOrderId = @WorkOrderId;

        DELETE FROM dbo.MaterialOrdenTrabajo WHERE WorkOrderId = @WorkOrderId;
        DELETE FROM dbo.TipoTrabajoOrdenTrabajo WHERE WorkOrderId = @WorkOrderId;

        INSERT INTO dbo.MaterialOrdenTrabajo (WorkOrderId, LineNum, Description, Quantity, Unit)
        SELECT @WorkOrderId, ROW_NUMBER() OVER (ORDER BY LineNum), Description, Quantity, ISNULL(Unit, 'pz')
          FROM @Materials;

        INSERT INTO dbo.TipoTrabajoOrdenTrabajo (WorkOrderId, WorkType)
        SELECT DISTINCT @WorkOrderId, LTRIM(RTRIM(Value)) FROM @WorkTypes WHERE LTRIM(RTRIM(Value)) <> '';

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@UserId, @UserName, 'WORK_ORDER_UPDATED', 'WORK_ORDERS', @WorkOrderId,
                CONCAT(N'Detalles de OT ', @WorkOrderId, N' actualizados.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- --- REPORTES DE AVERÍAS ---
CREATE PROCEDURE dbo.uspReporteAveriaCrear
    @AssetCode NVARCHAR(60), @AssetName NVARCHAR(200), @AreaId NVARCHAR(15),
    @Description NVARCHAR(MAX), @Severity NVARCHAR(10),
    @ReporterUserId INT = NULL, @ReporterUserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.Activo WHERE AssetCode = @AssetCode)
        BEGIN
            RAISERROR(N'El activo no existe.', 16, 1);
        END;

        INSERT INTO dbo.ReporteAveria (AssetCode, AssetName, AreaId, Description, Severity, ReportedByUserId, ReportedByUserName)
        VALUES (@AssetCode, @AssetName, @AreaId, @Description, @Severity, @ReporterUserId, @ReporterUserName);
        DECLARE @rid BIGINT = SCOPE_IDENTITY();

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@ReporterUserId, @ReporterUserName, 'BREAKDOWN_REPORTED', 'BREAKDOWNS', @AssetCode,
                CONCAT(N'Reporte ', @rid, N': avería en ', @AssetCode, N' (', @AssetName, N'). Severidad: ', @Severity, N'.'));

        COMMIT TRANSACTION;
        SELECT @rid AS NewReportId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspReporteAveriaObtenerTodos
    @StatusFilter NVARCHAR(15) = NULL,
    @StartDate DATETIME2(3) = NULL, @EndDate DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.ReporteAveria
     WHERE (@StatusFilter IS NULL OR Status = @StatusFilter)
       AND (@StartDate IS NULL OR ReportedAt >= @StartDate)
       AND (@EndDate   IS NULL OR ReportedAt <= @EndDate)
     ORDER BY ReportedAt DESC;
END;
GO

CREATE PROCEDURE dbo.uspReporteAveriaObtenerPorUsuario @ReporterUserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.ReporteAveria WHERE ReportedByUserId = @ReporterUserId ORDER BY ReportedAt DESC;
END;
GO

CREATE PROCEDURE dbo.uspReporteAveriaObtenerAbiertos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.ReporteAveria WHERE Status IN ('reported', 'inWorkOrder') ORDER BY ReportedAt DESC;
END;
GO

CREATE PROCEDURE dbo.uspReporteAveriaVincularOrdenTrabajo
    @ReportId BIGINT, @WorkOrderId NVARCHAR(20), @UserId INT = NULL, @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.ReporteAveria SET Status = 'inWorkOrder', WorkOrderId = @WorkOrderId WHERE ReportId = @ReportId;
        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR(N'El reporte ya no existe.', 16, 1);
        END;

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@UserId, @UserName, 'BREAKDOWN_LINKED_WORK_ORDER', 'BREAKDOWNS', @ReportId,
                CONCAT(N'Reporte ', @ReportId, N' vinculado a la OT ', @WorkOrderId, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspReporteAveriaResolver
    @ReportId BIGINT, @ResolvedByUserId INT = NULL, @ResolvedByUserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.ReporteAveria
       SET Status = 'resolved', ResolvedByUserId = @ResolvedByUserId,
           ResolvedByUserName = @ResolvedByUserName, ResolvedAt = SYSUTCDATETIME()
     WHERE ReportId = @ReportId;
    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR(N'El reporte ya no existe.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
    VALUES (@ResolvedByUserId, @ResolvedByUserName, 'BREAKDOWN_RESOLVED', 'BREAKDOWNS', @ReportId,
            CONCAT(N'Reporte ', @ReportId, N' resuelto.'));
END;
GO

CREATE PROCEDURE dbo.uspReporteAveriaRechazar
    @ReportId BIGINT, @Reason NVARCHAR(500), @RejectedByUserId INT = NULL, @RejectedByUserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.ReporteAveria
       SET Status = 'rejected', RejectionReason = @Reason,
           RejectedByUserId = @RejectedByUserId, RejectedByUserName = @RejectedByUserName,
           RejectedAt = SYSUTCDATETIME()
     WHERE ReportId = @ReportId;
    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR(N'El reporte ya no existe.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
    VALUES (@RejectedByUserId, @RejectedByUserName, 'BREAKDOWN_REJECTED', 'BREAKDOWNS', @ReportId,
            CONCAT(N'Reporte ', @ReportId, N' rechazado: "', @Reason, N'".'));
END;
GO

-- --- PLANES PREVENTIVOS ---
CREATE PROCEDURE dbo.uspPlanPreventivoObtenerTodos
    @AreaFilter NVARCHAR(15) = NULL, @StatusFilter NVARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.*, m.MaterialsJson
      FROM dbo.PlanPreventivo p
     OUTER APPLY (SELECT (SELECT Name, Quantity, Unit
                            FROM dbo.MaterialPreventivo
                           WHERE ScheduleId = p.ScheduleId
                           ORDER BY LineNum
                             FOR JSON PATH) AS MaterialsJson) m
     WHERE (@AreaFilter   IS NULL OR p.AreaId = @AreaFilter)
       AND (@StatusFilter IS NULL OR p.Status = @StatusFilter)
     ORDER BY p.NextDate ASC;
END;
GO

CREATE PROCEDURE dbo.uspPlanPreventivoCrear
    @Title NVARCHAR(200) = NULL, @AssetCode NVARCHAR(60), @AssetName NVARCHAR(200),
    @AreaId NVARCHAR(15), @AreaName NVARCHAR(200),
    @MaintenanceType NVARCHAR(100), @Frequency NVARCHAR(15),
    @Description NVARCHAR(MAX) = NULL, @EstimatedHours DECIMAL(6,2) = NULL,
    @StartDate DATETIME2(3), @NextDate DATETIME2(3),
    @LastCompleted DATETIME2(3) = NULL, @LastWorkOrderId NVARCHAR(20) = NULL,
    @Status NVARCHAR(10) = 'active', @Notes NVARCHAR(500) = NULL,
    @CreatedByUserId INT = NULL, @CreatedByUserName NVARCHAR(100) = N'',
    @Materials dbo.TipoMaterialPreventivo READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @cTable TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET NextNumber += 1
         OUTPUT deleted.NextNumber INTO @cTable(v)
          WHERE Name = 'preventive_schedules';

        DECLARE @n INT; SELECT @n = v FROM @cTable;
        DECLARE @id NVARCHAR(20) = CONCAT('PM-', YEAR(SYSUTCDATETIME()), '-', FORMAT(@n, '0000'));
        DECLARE @FinalTitle NVARCHAR(200) =
            CASE WHEN LTRIM(ISNULL(@Title, N'')) = N'' THEN CONCAT(N'Plan Preventivo ', @id) ELSE @Title END;

        INSERT INTO dbo.PlanPreventivo
            (ScheduleId, Title, AssetCode, AssetName, AreaId, AreaName, MaintenanceType, Frequency,
             Description, EstimatedHours, StartDate, NextDate, LastCompleted, LastWorkOrderId,
             Status, Notes, CreatedByUserId, CreatedByUserName, CreatedAt)
        VALUES
            (@id, @FinalTitle, @AssetCode, @AssetName, @AreaId, @AreaName, @MaintenanceType, @Frequency,
             @Description, @EstimatedHours, @StartDate, @NextDate, @LastCompleted, @LastWorkOrderId,
             @Status, @Notes, @CreatedByUserId, @CreatedByUserName, SYSUTCDATETIME());

        INSERT INTO dbo.MaterialPreventivo (ScheduleId, LineNum, Name, Quantity, Unit)
        SELECT @id, ROW_NUMBER() OVER (ORDER BY LineNum), Name, Quantity, ISNULL(Unit, 'pza')
          FROM @Materials;

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@CreatedByUserId, @CreatedByUserName, 'PREVENTIVE_SCHEDULE_CREATED', 'PREVENTIVE', @id,
                CONCAT(N'Plan preventivo ', @id, N' creado para ', @AssetCode, N' - Frecuencia: ', dbo.fnFrecuenciaEtiqueta(@Frequency), N'.'));

        COMMIT TRANSACTION;
        SELECT @id AS NewScheduleId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspPlanPreventivoModificar
    @ScheduleId NVARCHAR(20), @Title NVARCHAR(200), @MaintenanceType NVARCHAR(100), @Frequency NVARCHAR(15),
    @Description NVARCHAR(MAX) = NULL, @EstimatedHours DECIMAL(6,2) = NULL,
    @StartDate DATETIME2(3), @NextDate DATETIME2(3), @Notes NVARCHAR(500) = NULL,
    @AmendmentDocNumber NVARCHAR(50) = NULL, @AuthorizedByManager BIT = 1, @AmendmentReason NVARCHAR(500) = NULL,
    @UserId INT = NULL, @UserName NVARCHAR(100) = N'',
    @Materials dbo.TipoMaterialPreventivo READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.PlanPreventivo
           SET Title = @Title, MaintenanceType = @MaintenanceType, Frequency = @Frequency,
               Description = @Description, EstimatedHours = @EstimatedHours,
               StartDate = @StartDate, NextDate = @NextDate, Notes = @Notes,
               AmendmentDocNumber = @AmendmentDocNumber,
               AmendedBy = @UserName,
               AmendedAt = SYSUTCDATETIME(),
               AmendmentReason = @AmendmentReason
         WHERE ScheduleId = @ScheduleId;

        DELETE FROM dbo.MaterialPreventivo WHERE ScheduleId = @ScheduleId;
        INSERT INTO dbo.MaterialPreventivo (ScheduleId, LineNum, Name, Quantity, Unit)
        SELECT @ScheduleId, ROW_NUMBER() OVER (ORDER BY LineNum), Name, Quantity, ISNULL(Unit, 'pza')
          FROM @Materials;

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@UserId, @UserName, 'PREVENTIVE_SCHEDULE_UPDATED', 'PREVENTIVE', @ScheduleId,
                CONCAT(N'Plan preventivo ', @ScheduleId, N' modificado.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspPlanPreventivoRegistrarEjecucion
    @ScheduleId NVARCHAR(20), @WorkOrderId NVARCHAR(20),
    @UserId INT = NULL, @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @freq NVARCHAR(15);
    SELECT @freq = Frequency FROM dbo.PlanPreventivo WHERE ScheduleId = @ScheduleId;
    IF @freq IS NOT NULL
    BEGIN
        DECLARE @next DATETIME2(3) = DATEADD(DAY, dbo.fnFrecuenciaDias(@freq), SYSUTCDATETIME());
        UPDATE dbo.PlanPreventivo
           SET LastCompleted = SYSUTCDATETIME(), LastWorkOrderId = @WorkOrderId, NextDate = @next
         WHERE ScheduleId = @ScheduleId;

        INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
        VALUES (@UserId, @UserName, 'PREVENTIVE_SCHEDULE_UPDATED', 'PREVENTIVE', @ScheduleId,
                CONCAT(N'Plan preventivo ', @ScheduleId, N' ejecutado mediante OT ', @WorkOrderId, N'.'));
    END;
END;
GO

CREATE PROCEDURE dbo.uspPlanPreventivoAlternarEstado
    @ScheduleId NVARCHAR(20), @NewStatus NVARCHAR(10),
    @AmendmentDocNumber NVARCHAR(50) = NULL, @AuthorizedByManager BIT = 1, @Reason NVARCHAR(500) = NULL,
    @UserId INT = NULL, @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.PlanPreventivo
       SET Status = @NewStatus,
           AmendmentDocNumber = @AmendmentDocNumber,
           AmendedBy = @UserName,
           AmendedAt = SYSUTCDATETIME(),
           AmendmentReason = @Reason
     WHERE ScheduleId = @ScheduleId;

    INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
    VALUES (@UserId, @UserName, 'PREVENTIVE_SCHEDULE_STATUS_CHANGED', 'PREVENTIVE', @ScheduleId,
            CONCAT(N'Estado de plan preventivo ', @ScheduleId, N' cambiado a "', @NewStatus, N'".'));
END;
GO

-- --- KARDEX Y DASHBOARD ---
CREATE PROCEDURE dbo.uspKardexAgregar
    @Action NVARCHAR(40), @Module NVARCHAR(20), @EntityId NVARCHAR(60), @Details NVARCHAR(MAX),
    @UserId INT = NULL, @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.BitacoraKardex (UserId, UserName, Action, Module, EntityId, Details)
    VALUES (@UserId, @UserName, @Action, @Module, @EntityId, @Details);
END;
GO

CREATE PROCEDURE dbo.uspKardexObtenerTodos
    @ModuleFilter NVARCHAR(20) = NULL, @ActionFilter NVARCHAR(40) = NULL, @UserFilter INT = NULL,
    @StartDate DATETIME2(3) = NULL, @EndDate DATETIME2(3) = NULL,
    @Limit INT = 200
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Limit) *
      FROM dbo.BitacoraKardex
     WHERE (@ModuleFilter IS NULL OR Module = @ModuleFilter)
       AND (@ActionFilter IS NULL OR Action = @ActionFilter)
       AND (@UserFilter   IS NULL OR UserId = @UserFilter)
       AND (@StartDate    IS NULL OR LoggedAt >= @StartDate)
       AND (@EndDate      IS NULL OR LoggedAt <= @EndDate)
     ORDER BY LoggedAt DESC;
END;
GO

CREATE PROCEDURE dbo.uspKardexObtenerPorEntidad @EntityId NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.BitacoraKardex WHERE EntityId = @EntityId ORDER BY LoggedAt DESC;
END;
GO

CREATE PROCEDURE dbo.uspDashboardObtenerEstadisticas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM dbo.Activo         WHERE Status <> 'deleted')                    AS TotalAssets,
        (SELECT COUNT(*) FROM dbo.OrdenTrabajo   WHERE Status = 'pending')                     AS PendingWorkOrders,
        (SELECT COUNT(*) FROM dbo.OrdenTrabajo   WHERE Status = 'inProgress')                  AS InProgressWorkOrders,
        (SELECT COUNT(*) FROM dbo.OrdenTrabajo   WHERE Status = 'completed')                   AS CompletedWorkOrders,
        (SELECT COUNT(*) FROM dbo.PlanPreventivo WHERE Status = 'active')                      AS ActivePreventiveSchedules,
        (SELECT COUNT(*) FROM dbo.BitacoraKardex)                                              AS TotalKardexLogs;
END;
GO

/* ==========================================================================
   7. SEGURIDAD
   ========================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'macsa_app' AND type = 'R')
BEGIN
    EXEC sp_executesql N'CREATE ROLE macsa_app;';
END;
GO
DENY INSERT, UPDATE, DELETE ON SCHEMA::dbo TO macsa_app;
GRANT EXECUTE ON SCHEMA::dbo TO macsa_app;
GO

/* ==========================================================================
   8. DATOS SEMILLA
   ========================================================================== */
BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.Rol (RoleCode, Label) VALUES
        ('admin',      N'Administrador'),
        ('jefe',       N'Jefe de Mantenimiento'),
        ('reportador', N'Reportador'),
        ('lector',     N'Lector');

    INSERT INTO dbo.Permiso (PermissionCode) VALUES
        ('dashboard.view'), ('asset.view'), ('asset.create'), ('asset.edit'),
        ('asset.transfer'), ('asset.delete.request'), ('asset.delete.approve'),
        ('work_order.view'), ('work_order.create'), ('work_order.print'),
        ('preventive.view'), ('kardex.view'),
        ('breakdown.report'), ('breakdown.view'), ('breakdown.manage'),
        ('user.manage');

    INSERT INTO dbo.RolPermiso (RoleCode, PermissionCode)
    SELECT 'admin', PermissionCode FROM dbo.Permiso;

    INSERT INTO dbo.RolPermiso (RoleCode, PermissionCode) VALUES
        ('jefe', 'dashboard.view'), ('jefe', 'asset.view'),
        ('jefe', 'work_order.view'), ('jefe', 'work_order.create'), ('jefe', 'work_order.print'),
        ('jefe', 'preventive.view'), ('jefe', 'kardex.view'),
        ('jefe', 'breakdown.view'), ('jefe', 'breakdown.manage');

    INSERT INTO dbo.RolPermiso (RoleCode, PermissionCode) VALUES
        ('reportador', 'breakdown.report'), ('reportador', 'breakdown.view');

    INSERT INTO dbo.RolPermiso (RoleCode, PermissionCode) VALUES
        ('lector', 'dashboard.view'), ('lector', 'asset.view'),
        ('lector', 'work_order.view'), ('lector', 'preventive.view'),
        ('lector', 'kardex.view'), ('lector', 'breakdown.view');

    INSERT INTO dbo.Contador (Name, NextNumber) VALUES
        ('areas', 4),
        ('work_orders', 2),
        ('preventive_schedules', 1);

    INSERT INTO dbo.Usuario
        (Username, DisplayName, RoleCode, PasswordSalt, PasswordHash,
         PasswordIterations, Disabled, MustChangePassword)
    VALUES
        ('admin',      N'Administrador General',            'admin',      'Rx1dwPY0zyqg1mfPfwMcSg==',
         'o9h4+o4D7+n7VmRYx0ZU+JtDShclDmIHid7jFfOm+sM=', 20000, 0, 0),
        ('lector',     N'Lector de Información',            'lector',     'Rx1dwPY0zyqg1mfPfwMcSg==',
         'o9h4+o4D7+n7VmRYx0ZU+JtDShclDmIHid7jFfOm+sM=', 20000, 0, 0),
        ('reportador', N'Reportador de Averías',            'reportador', 'Rx1dwPY0zyqg1mfPfwMcSg==',
         'o9h4+o4D7+n7VmRYx0ZU+JtDShclDmIHid7jFfOm+sM=', 20000, 0, 0),
        ('jefe',       N'Jefe de Área (legado)',            'lector',     'Rx1dwPY0zyqg1mfPfwMcSg==',
         'o9h4+o4D7+n7VmRYx0ZU+JtDShclDmIHid7jFfOm+sM=', 20000, 1, 0),
        ('gerente',    N'Gerente de Operaciones (legado)',  'lector',     'Rx1dwPY0zyqg1mfPfwMcSg==',
         'o9h4+o4D7+n7VmRYx0ZU+JtDShclDmIHid7jFfOm+sM=', 20000, 1, 0);

    INSERT INTO dbo.UsuarioPermiso (UserId, PermissionCode)
    SELECT u.UserId, p.PermissionCode
      FROM dbo.Usuario u
      JOIN (VALUES
        ('admin', 'dashboard.view'), ('admin', 'asset.view'),
        ('admin', 'asset.create'),   ('admin', 'asset.edit'),
        ('admin', 'asset.transfer'), ('admin', 'asset.delete.request'),
        ('admin', 'asset.delete.approve'),
        ('admin', 'work_order.view'),('admin', 'work_order.create'),
        ('admin', 'preventive.view'),('admin', 'kardex.view'),
        ('admin', 'breakdown.report'),('admin', 'breakdown.view'),
        ('admin', 'user.manage'),
        ('lector', 'dashboard.view'), ('lector', 'asset.view'),
        ('lector', 'work_order.view'), ('lector', 'preventive.view'),
        ('lector', 'kardex.view'), ('lector', 'breakdown.view'),
        ('reportador', 'asset.view'), ('reportador', 'breakdown.report')
      ) AS p(Username, PermissionCode)
        ON p.Username = u.Username;

    INSERT INTO dbo.Area (AreaId, Name, CostCenter, AssetCounter)
    VALUES
        ('A1', N'Planta de Procesamiento', 'CC-01', 2),
        ('A2', N'Empacadora',              'CC-02', 0),
        ('A3', N'Cámaras de Frío',         'CC-03', 0);

    INSERT INTO dbo.Activo
        (AssetCode, Name, Brand, Model, AreaId, StationId, ParentAssetCode, Level,
         AncestorsPath, Status, Serial, ChildCounter, DynamicAttributes, CreatedAt)
    VALUES
        ('A1-001',          N'Bomba centrífuga',       N'KSB',        N'Etanorm 80',   'A1', 'S1', NULL,            'equipment',    '',                              'active', NULL, 2,
         N'{"potencia":"7.5 kW","caudal":"60 m3/h"}', SYSUTCDATETIME()),
        ('A1-002',          N'Compresor de aire',      N'Atlas Copco',N'GA 30',        'A1', 'S2', NULL,            'equipment',    '',                              'active', NULL, 0,
         N'{"presion":"10 bar"}', SYSUTCDATETIME()),
        ('A1-001-01',       N'Motor eléctrico',        N'Siemens',    N'SIMATIC S7-1200','A1','S1', 'A1-001',        'subEquipment', 'A1-001',                        'active', NULL, 1,
         N'{"potencia":"5.5 kW","voltaje":"440V"}', SYSUTCDATETIME()),
        ('A1-001-02',       N'Sello mecánico',         N'John Crane', N'Type 21',      'A1', 'S1', 'A1-001',        'subEquipment', 'A1-001',                        'active', NULL, 0,
         N'{"material":"Carburo de silicio"}', SYSUTCDATETIME()),
        ('A1-001-01-01',    N'Rodamiento del motor',   N'SKF',        N'6205-2RS',     'A1', 'S1', 'A1-001-01',     'part',         'A1-001,A1-001-01',              'active', NULL, 1,
         N'{"dimension":"25x52x15 mm"}', SYSUTCDATETIME()),
        ('A1-001-01-01-01', N'Rótula del rodamiento',  N'SKF',        N'BALL-6205',    'A1', 'S1', 'A1-001-01-01',  'subPart',      'A1-001,A1-001-01,A1-001-01-01', 'active', NULL, 0,
         N'{"material":"Acero cromado"}', SYSUTCDATETIME());

    INSERT INTO dbo.HistorialEstadoActivo (AssetCode, Status, StartedAt, AreaId, Reason, UserName)
    SELECT a.AssetCode, a.Status, SYSUTCDATETIME(), a.AreaId, N'Alta inicial del activo', N'admin'
      FROM dbo.Activo a;

    DECLARE @uidAdmin INT, @uidReportador INT;
    SELECT @uidAdmin = UserId FROM dbo.Usuario WHERE Username = 'admin';
    SELECT @uidReportador = UserId FROM dbo.Usuario WHERE Username = 'reportador';

    INSERT INTO dbo.OrdenTrabajo
        (WorkOrderId, AssetCode, AssetName, Description, Status, Priority,
         CreatedByUserId, CreatedByUserName, CreatedAt)
    VALUES
        ('OT-0001', 'A1-001', N'Bomba centrífuga', N'Fuga de aceite en el sello mecánico.',
         'pending', 'high', @uidAdmin, N'Administrador General', DATEADD(DAY, -2, SYSUTCDATETIME()));

    INSERT INTO dbo.ReporteAveria
        (AssetCode, AssetName, AreaId, Description, Severity,
         ReportedByUserId, ReportedByUserName, ReportedAt, Status, WorkOrderId,
         RejectionReason, RejectedByUserId, RejectedByUserName, RejectedAt)
    VALUES
        ('A1-001',     N'Bomba centrífuga',  'A1', N'Fuga de aceite en el sello mecánico.',        'high',   @uidReportador, N'reportador', DATEADD(DAY, -3, SYSUTCDATETIME()), 'inWorkOrder', 'OT-0001',
         NULL, NULL, NULL, NULL),
        ('A1-002',     N'Compresor de aire', 'A1', N'Ruido excesivo y vibración al arrancar.',     'medium', @uidReportador, N'reportador', DATEADD(DAY, -1, SYSUTCDATETIME()), 'reported',    NULL,
         NULL, NULL, NULL, NULL),
        ('A1-001-01',  N'Motor eléctrico',   'A1', N'Ligera vibración detectada en el motor.',     'low',    @uidReportador, N'reportador', DATEADD(HOUR, -20, SYSUTCDATETIME()), 'rejected',   NULL,
         N'Vibración dentro de rango aceptable; sin avería.', @uidAdmin, N'Administrador General', DATEADD(HOUR, -18, SYSUTCDATETIME()));

    UPDATE dbo.OrdenTrabajo SET ReportId = 1 WHERE WorkOrderId = 'OT-0001';

    COMMIT TRANSACTION;
    PRINT N'Seed completado en español: roles, permisos, contadores, usuarios (1234), areas A1-A3, jerarquia de activos (4 niveles), averias y OT-0001.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'Error durante el seed:';
    THROW;
END CATCH
GO

PRINT N'MacsaCMMS inicializada correctamente en Español.';
GO
