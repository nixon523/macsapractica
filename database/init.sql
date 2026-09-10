/* ============================================================================
   MACSA CMMS - Sistema de Gestión de Mantenimiento Grupo Macsa
   init.sql : Base de Datos SQL Server con Tablas y Columnas en Español
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
    dbo.uspDashboardObtenerEstadisticas;
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
    dbo.SolicitudReinicioPassword, dbo.Usuario, dbo.RolPermiso, dbo.Permiso, dbo.Rol, dbo.Contador;
GO

DROP TYPE IF EXISTS dbo.TipoListaTexto;
DROP TYPE IF EXISTS dbo.TipoMaterialOrdenTrabajo;
DROP TYPE IF EXISTS dbo.TipoMaterialPreventivo;
DROP TYPE IF EXISTS dbo.StringListType;
DROP TYPE IF EXISTS dbo.WorkOrderMaterialType;
DROP TYPE IF EXISTS dbo.PreventiveMaterialType;
GO

/* ==========================================================================
   1. TABLAS CON COLUMNAS EN ESPAÑOL
   ========================================================================== */
CREATE TABLE dbo.Rol (
    CodigoRol           NVARCHAR(20) NOT NULL CONSTRAINT PK_Rol PRIMARY KEY,
    Nombre              NVARCHAR(50) NOT NULL
);

CREATE TABLE dbo.Permiso (
    CodigoPermiso       NVARCHAR(50) NOT NULL CONSTRAINT PK_Permiso PRIMARY KEY
);

CREATE TABLE dbo.RolPermiso (
    CodigoRol           NVARCHAR(20) NOT NULL,
    CodigoPermiso       NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_RolPermiso PRIMARY KEY (CodigoRol, CodigoPermiso),
    CONSTRAINT FK_RolPermiso_Rol     FOREIGN KEY (CodigoRol)     REFERENCES dbo.Rol(CodigoRol),
    CONSTRAINT FK_RolPermiso_Permiso FOREIGN KEY (CodigoPermiso) REFERENCES dbo.Permiso(CodigoPermiso)
);

CREATE TABLE dbo.Contador (
    Nombre              NVARCHAR(30) NOT NULL CONSTRAINT PK_Contador PRIMARY KEY,
    SiguienteNumero     INT          NOT NULL CONSTRAINT DF_Contador_SiguienteNumero DEFAULT (1),
    CONSTRAINT CK_Contador_SiguienteNumero CHECK (SiguienteNumero > 0)
);
GO

CREATE TABLE dbo.Usuario (
    UsuarioId                INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Usuario PRIMARY KEY,
    NombreUsuario            NVARCHAR(50)  COLLATE Latin1_General_CI_AI NOT NULL CONSTRAINT UQ_Usuario_NombreUsuario UNIQUE,
    NombreCompleto           NVARCHAR(100) NOT NULL,
    CodigoRol                NVARCHAR(20)  NOT NULL,
    PasswordSalt             NVARCHAR(64)  NOT NULL,
    PasswordHash             NVARCHAR(128) NOT NULL,
    IteracionesPassword      INT           NOT NULL CONSTRAINT DF_Usuario_Iteraciones DEFAULT (20000),
    Deshabilitado            BIT           NOT NULL CONSTRAINT DF_Usuario_Deshabilitado DEFAULT (0),
    DebeCambiarPassword      BIT           NOT NULL CONSTRAINT DF_Usuario_DebeCambiar DEFAULT (0),
    SolicitudReinicioPassword BIT          NOT NULL CONSTRAINT DF_Usuario_SolicitudReinicio DEFAULT (0),
    SolicitadoEn             DATETIME2(3)  NULL,
    IntentosFallidos         INT           NOT NULL CONSTRAINT DF_Usuario_IntentosFallidos DEFAULT (0),
    BloqueadoHasta           DATETIME2(3)  NULL,
    CreadoEn                 DATETIME2(3)  NOT NULL CONSTRAINT DF_Usuario_CreadoEn DEFAULT (SYSUTCDATETIME()),
    ActualizadoEn            DATETIME2(3)  NULL,
    CONSTRAINT CK_Usuario_Iteraciones CHECK (IteracionesPassword >= 10000),
    CONSTRAINT FK_Usuario_Rol FOREIGN KEY (CodigoRol) REFERENCES dbo.Rol(CodigoRol)
);
GO

CREATE TABLE dbo.UsuarioPermiso (
    UsuarioId          INT          NOT NULL,
    CodigoPermiso      NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_UsuarioPermiso PRIMARY KEY (UsuarioId, CodigoPermiso),
    CONSTRAINT FK_UP_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuario(UsuarioId) ON DELETE CASCADE,
    CONSTRAINT FK_UP_Permiso FOREIGN KEY (CodigoPermiso) REFERENCES dbo.Permiso(CodigoPermiso)
);

CREATE TABLE dbo.SolicitudReinicioPassword (
    SolicitudId       BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SolicitudReinicioPassword PRIMARY KEY,
    UsuarioId         INT           NOT NULL,
    NombreUsuario     NVARCHAR(50)  NOT NULL,
    NombreCompleto    NVARCHAR(100) NOT NULL,
    CodigoRol         NVARCHAR(20)  NOT NULL,
    Estado            NVARCHAR(15)  NOT NULL CONSTRAINT DF_SRP_Estado DEFAULT ('pending'),
    SolicitadoEn      DATETIME2(3)  NOT NULL CONSTRAINT DF_SRP_SolicitadoEn DEFAULT (SYSUTCDATETIME()),
    Detalles          NVARCHAR(500) NULL,
    CONSTRAINT CK_SRP_Estado CHECK (Estado IN ('pending', 'resolved', 'cancelled')),
    CONSTRAINT FK_SRP_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuario(UsuarioId)
);

CREATE TABLE dbo.Area (
    AreaId             NVARCHAR(15)  COLLATE Latin1_General_CI_AI NOT NULL CONSTRAINT PK_Area PRIMARY KEY,
    Nombre             NVARCHAR(100) COLLATE Latin1_General_CI_AI NOT NULL,
    CentroCosto        NVARCHAR(50)  NOT NULL,
    ContadorActivos    INT           NOT NULL CONSTRAINT DF_Area_ContadorActivos DEFAULT (0),
    CreadoEn           DATETIME2(3)  NOT NULL CONSTRAINT DF_Area_CreadoEn DEFAULT (SYSUTCDATETIME()),
    ActualizadoEn      DATETIME2(3)  NULL
);
GO

CREATE TABLE dbo.Activo (
    CodigoActivo               NVARCHAR(60) COLLATE Latin1_General_CI_AI NOT NULL CONSTRAINT PK_Activo PRIMARY KEY,
    Nombre                     NVARCHAR(200) COLLATE Latin1_General_CI_AI NOT NULL,
    Marca                      NVARCHAR(100) COLLATE Latin1_General_CI_AI NULL,
    Modelo                     NVARCHAR(100) COLLATE Latin1_General_CI_AI NULL,
    AreaId                     NVARCHAR(15)  NOT NULL,
    EstacionId                 NVARCHAR(100) NOT NULL CONSTRAINT DF_Activo_EstacionId DEFAULT (''),
    CodigoActivoPadre          NVARCHAR(60)  NULL,
    Nivel                      NVARCHAR(20)  NOT NULL,
    RutaAncestros              NVARCHAR(400) NOT NULL CONSTRAINT DF_Activo_RutaAncestros DEFAULT (''),
    Estado                     NVARCHAR(25)  NOT NULL CONSTRAINT DF_Activo_Estado DEFAULT ('active'),
    TraspasadoACodigo          NVARCHAR(60)  NULL,
    Serie                      NVARCHAR(100) NULL,
    AtributosDinamicos         NVARCHAR(MAX) NULL,
    DatosImagen                NVARCHAR(MAX) NULL,
    ContadorHijos              INT           NOT NULL CONSTRAINT DF_Activo_ContadorHijos DEFAULT (0),
    EliminadoEn                DATETIME2(3)  NULL,
    EliminadoPorUsuarioId      INT           NULL,
    EliminadoPorNombreUsuario  NVARCHAR(100) NULL,
    TextoBusqueda              AS (CONCAT(CodigoActivo,' ',Nombre,' ',Marca,' ',Modelo,' ',Serie)) PERSISTED,
    CreadoEn                   DATETIME2(3)  NOT NULL CONSTRAINT DF_Activo_CreadoEn DEFAULT (SYSUTCDATETIME()),
    ActualizadoEn              DATETIME2(3)  NULL,
    VersionFila                ROWVERSION,
    CONSTRAINT CK_Activo_Nivel   CHECK (Nivel IN ('equipment','subEquipment','part','subPart')),
    CONSTRAINT CK_Activo_Estado  CHECK (Estado IN ('active','transferredDeactivated','inactive','deleted')),
    CONSTRAINT CK_Activo_Imagen  CHECK (DatosImagen IS NULL OR LEN(DatosImagen) < 1100000),
    CONSTRAINT CK_Activo_Json    CHECK (AtributosDinamicos IS NULL OR ISJSON(AtributosDinamicos) = 1),
    CONSTRAINT FK_Activo_Area    FOREIGN KEY (AreaId) REFERENCES dbo.Area(AreaId),
    CONSTRAINT FK_Activo_Padre   FOREIGN KEY (CodigoActivoPadre) REFERENCES dbo.Activo(CodigoActivo),
    CONSTRAINT FK_Activo_BajaPor FOREIGN KEY (EliminadoPorUsuarioId) REFERENCES dbo.Usuario(UsuarioId)
);

CREATE TABLE dbo.HistorialEstadoActivo (
    HistorialId        BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_HistorialEstadoActivo PRIMARY KEY,
    CodigoActivo       NVARCHAR(60)  NOT NULL,
    Estado             NVARCHAR(25)  NOT NULL,
    IniciadoEn         DATETIME2(3)  NOT NULL,
    FinalizadoEn       DATETIME2(3)  NULL,
    AreaId             NVARCHAR(15)  NOT NULL,
    Motivo             NVARCHAR(500) NULL,
    UsuarioId          INT           NULL,
    NombreUsuario      NVARCHAR(100) NULL,
    CONSTRAINT CK_HEA_Estado CHECK (Estado IN ('active','transferredDeactivated','inactive','deleted')),
    CONSTRAINT FK_HEA_Activo  FOREIGN KEY (CodigoActivo) REFERENCES dbo.Activo(CodigoActivo),
    CONSTRAINT FK_HEA_Usuario FOREIGN KEY (UsuarioId)    REFERENCES dbo.Usuario(UsuarioId)
);

CREATE TABLE dbo.CandadoBaja (
    CodigoActivo       NVARCHAR(60) NOT NULL CONSTRAINT PK_CandadoBaja PRIMARY KEY,
    EstadoCandado      NVARCHAR(10) NOT NULL,
    ActualizadoEn      DATETIME2(3) NOT NULL CONSTRAINT DF_CB_ActualizadoEn DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT CK_CB_Estado CHECK (EstadoCandado IN ('pending','approved','rejected')),
    CONSTRAINT FK_CB_Activo FOREIGN KEY (CodigoActivo) REFERENCES dbo.Activo(CodigoActivo)
);

CREATE TABLE dbo.SolicitudBaja (
    SolicitudId                  BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SolicitudBaja PRIMARY KEY,
    CodigoActivo                 NVARCHAR(60)  NOT NULL,
    NombreActivo                 NVARCHAR(200) NOT NULL,
    AreaId                       NVARCHAR(15)  NOT NULL,
    Estado                       NVARCHAR(10)  NOT NULL CONSTRAINT DF_SB_Estado DEFAULT ('pending'),
    Motivo                       NVARCHAR(1000) NOT NULL,
    SolicitadoPorUsuarioId       INT           NOT NULL,
    SolicitadoPorNombreUsuario   NVARCHAR(100) NOT NULL,
    SolicitadoEn                 DATETIME2(3)  NOT NULL CONSTRAINT DF_SB_SolicitadoEn DEFAULT (SYSUTCDATETIME()),
    DecididoPorUsuarioId         INT           NULL,
    DecididoPorNombreUsuario     NVARCHAR(100) NULL,
    DecididoEn                   DATETIME2(3)  NULL,
    MotivoDecision               NVARCHAR(500) NULL,
    VersionFila                  ROWVERSION,
    CONSTRAINT CK_SB_Estado CHECK (Estado IN ('pending','approved','rejected')),
    CONSTRAINT FK_SB_Activo     FOREIGN KEY (CodigoActivo)           REFERENCES dbo.Activo(CodigoActivo),
    CONSTRAINT FK_SB_Area       FOREIGN KEY (AreaId)                 REFERENCES dbo.Area(AreaId),
    CONSTRAINT FK_SB_Solicitante FOREIGN KEY (SolicitadoPorUsuarioId) REFERENCES dbo.Usuario(UsuarioId),
    CONSTRAINT FK_SB_Decisor    FOREIGN KEY (DecididoPorUsuarioId)   REFERENCES dbo.Usuario(UsuarioId)
);

CREATE TABLE dbo.ReporteAveria (
    ReporteId                  BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ReporteAveria PRIMARY KEY,
    CodigoActivo               NVARCHAR(60)  NOT NULL,
    NombreActivo               NVARCHAR(200) NOT NULL,
    AreaId                     NVARCHAR(15)  NOT NULL,
    Descripcion                NVARCHAR(MAX) NOT NULL,
    Severidad                  NVARCHAR(10)  NOT NULL,
    ReportadoPorUsuarioId      INT           NULL,
    ReportadoPorNombreUsuario  NVARCHAR(100) NOT NULL,
    ReportadoEn                DATETIME2(3)  NOT NULL CONSTRAINT DF_RA_ReportadoEn DEFAULT (SYSUTCDATETIME()),
    Estado                     NVARCHAR(15)  NOT NULL CONSTRAINT DF_RA_Estado DEFAULT ('reported'),
    OrdenTrabajoId             NVARCHAR(20)  NULL,
    ResueltoPorUsuarioId       INT           NULL,
    ResueltoPorNombreUsuario   NVARCHAR(100) NULL,
    ResueltoEn                 DATETIME2(3)  NULL,
    MotivoRechazo              NVARCHAR(500) NULL,
    RechazadoPorUsuarioId      INT           NULL,
    RechazadoPorNombreUsuario  NVARCHAR(100) NULL,
    RechazadoEn                DATETIME2(3)  NULL,
    VersionFila                ROWVERSION,
    CONSTRAINT CK_RA_Severidad CHECK (Severidad IN ('low','medium','high','critical')),
    CONSTRAINT CK_RA_Estado    CHECK (Estado IN ('reported','inWorkOrder','resolved','rejected','pending','inProgress')),
    CONSTRAINT FK_RA_Activo     FOREIGN KEY (CodigoActivo)          REFERENCES dbo.Activo(CodigoActivo),
    CONSTRAINT FK_RA_Reportador FOREIGN KEY (ReportadoPorUsuarioId) REFERENCES dbo.Usuario(UsuarioId),
    CONSTRAINT FK_RA_Resolutor  FOREIGN KEY (ResueltoPorUsuarioId)  REFERENCES dbo.Usuario(UsuarioId),
    CONSTRAINT FK_RA_Rechazador FOREIGN KEY (RechazadoPorUsuarioId) REFERENCES dbo.Usuario(UsuarioId)
);

CREATE TABLE dbo.OrdenTrabajo (
    OrdenTrabajoId              NVARCHAR(20)  NOT NULL CONSTRAINT PK_OrdenTrabajo PRIMARY KEY,
    CodigoActivo                NVARCHAR(60)  NULL,
    NombreActivo                NVARCHAR(200) NOT NULL,
    AreaId                      NVARCHAR(15)  NULL,
    NombreArea                  NVARCHAR(200) NULL,
    Descripcion                 NVARCHAR(MAX) NOT NULL,
    Estado                      NVARCHAR(15)  NOT NULL CONSTRAINT DF_OT_Estado DEFAULT ('pending'),
    Prioridad                   NVARCHAR(10)  NOT NULL CONSTRAINT DF_OT_Prioridad DEFAULT ('medium'),
    AsignadoA                   NVARCHAR(200) NULL,
    CantidadPersonalAsignado    INT           NULL,
    HorasEstimadas              DECIMAL(6,2)  NULL,
    HorasReales                 DECIMAL(6,2)  NULL,
    DescripcionTrabajoRealizado NVARCHAR(MAX) NULL,
    EstaCompletada              BIT           NULL,
    MotivoIncumplimiento        NVARCHAR(500) NULL,
    FechaReprogramacion         DATETIME2(3)  NULL,
    ResponsableAccHaccp         NVARCHAR(200) NULL,
    ResponsableMantenimiento    NVARCHAR(200) NULL,
    ResponsableJefeArea         NVARCHAR(200) NULL,
    ResponsableJefeMantenimiento NVARCHAR(200) NULL,
    FechaProgramada             DATETIME2(3)  NULL,
    ReporteId                   BIGINT        NULL,
    CreadoPorUsuarioId          INT           NULL,
    CreadoPorNombreUsuario      NVARCHAR(100) NULL,
    CreadoEn                    DATETIME2(3)  NOT NULL CONSTRAINT DF_OT_CreadoEn DEFAULT (SYSUTCDATETIME()),
    VersionFila                 ROWVERSION,
    CONSTRAINT CK_OT_Estado      CHECK (Estado IN ('pending','inProgress','completed','cancelled','unfulfilled')),
    CONSTRAINT CK_OT_Prioridad   CHECK (Prioridad IN ('low','medium','high')),
    CONSTRAINT CK_OT_Descripcion CHECK (LTRIM(Descripcion) <> ''),
    CONSTRAINT FK_OT_Activo    FOREIGN KEY (CodigoActivo)       REFERENCES dbo.Activo(CodigoActivo),
    CONSTRAINT FK_OT_Area      FOREIGN KEY (AreaId)             REFERENCES dbo.Area(AreaId),
    CONSTRAINT FK_OT_Creador   FOREIGN KEY (CreadoPorUsuarioId) REFERENCES dbo.Usuario(UsuarioId),
    CONSTRAINT FK_OT_Reporte   FOREIGN KEY (ReporteId)          REFERENCES dbo.ReporteAveria(ReporteId)
);

ALTER TABLE dbo.ReporteAveria ADD CONSTRAINT FK_RA_OrdenTrabajo
    FOREIGN KEY (OrdenTrabajoId) REFERENCES dbo.OrdenTrabajo(OrdenTrabajoId);

CREATE TABLE dbo.MaterialOrdenTrabajo (
    OrdenTrabajoId NVARCHAR(20)   NOT NULL,
    NumeroLinea    INT            NOT NULL,
    Descripcion    NVARCHAR(200)  NOT NULL,
    Cantidad       DECIMAL(10,2)  NOT NULL CONSTRAINT DF_MOT_Cantidad DEFAULT (1),
    Unidad         NVARCHAR(10)   NOT NULL CONSTRAINT DF_MOT_Unidad DEFAULT ('pz'),
    CONSTRAINT PK_MaterialOrdenTrabajo PRIMARY KEY (OrdenTrabajoId, NumeroLinea),
    CONSTRAINT FK_MOT_Orden FOREIGN KEY (OrdenTrabajoId) REFERENCES dbo.OrdenTrabajo(OrdenTrabajoId)
);

CREATE TABLE dbo.TipoTrabajoOrdenTrabajo (
    OrdenTrabajoId NVARCHAR(20) NOT NULL,
    TipoTrabajo    NVARCHAR(30) NOT NULL,
    CONSTRAINT PK_TipoTrabajoOrdenTrabajo PRIMARY KEY (OrdenTrabajoId, TipoTrabajo),
    CONSTRAINT CK_TTOT_Tipo CHECK (TipoTrabajo IN
        ('electric','mechanical','urgency','refrigeration','plumbing','preventive','corrective','scheduled')),
    CONSTRAINT FK_TTOT_Orden FOREIGN KEY (OrdenTrabajoId) REFERENCES dbo.OrdenTrabajo(OrdenTrabajoId)
);
GO

CREATE TABLE dbo.PlanPreventivo (
    PlanId                      NVARCHAR(20)  NOT NULL CONSTRAINT PK_PlanPreventivo PRIMARY KEY,
    Titulo                      NVARCHAR(200) NOT NULL,
    CodigoActivo                NVARCHAR(60)  NOT NULL,
    NombreActivo                NVARCHAR(200) NOT NULL,
    AreaId                      NVARCHAR(15)  NOT NULL,
    NombreArea                  NVARCHAR(200) NOT NULL,
    TipoMantenimiento           NVARCHAR(100) NOT NULL,
    Frecuencia                  NVARCHAR(15)  NOT NULL,
    Descripcion                 NVARCHAR(MAX) NULL,
    HorasEstimadas              DECIMAL(6,2)  NULL,
    FechaInicio                 DATETIME2(3)  NOT NULL,
    ProximaFecha                DATETIME2(3)  NOT NULL,
    UltimaCompletada            DATETIME2(3)  NULL,
    UltimaOrdenTrabajoId        NVARCHAR(20)  NULL,
    Estado                      NVARCHAR(10)  NOT NULL CONSTRAINT DF_PP_Estado DEFAULT ('active'),
    Notas                       NVARCHAR(500) NULL,
    CreadoPorUsuarioId          INT           NULL,
    CreadoPorNombreUsuario      NVARCHAR(100) NULL,
    CreadoEn                    DATETIME2(3)  NOT NULL CONSTRAINT DF_PP_CreadoEn DEFAULT (SYSUTCDATETIME()),
    NumeroDocumentoModificacion NVARCHAR(50)  NULL,
    ModificadoPor               NVARCHAR(250) NULL,
    ModificadoEn                DATETIME2(3)  NULL,
    MotivoModificacion          NVARCHAR(500) NULL,
    VersionFila                 ROWVERSION,
    CONSTRAINT CK_PP_Frecuencia CHECK (Frecuencia IN
        ('daily','weekly','biweekly','monthly','bimonthly','quarterly','semiannual','annual',
         'Diaria','Semanal','Quincenal','Mensual','Bimestral','Trimestral','Semestral','Anual',
         'diaria','semanal','quincenal','mensual','bimestral','trimestral','semestral','anual')),
    CONSTRAINT CK_PP_Estado CHECK (Estado IN ('active','paused','completed')),
    CONSTRAINT FK_PP_Activo   FOREIGN KEY (CodigoActivo)         REFERENCES dbo.Activo(CodigoActivo),
    CONSTRAINT FK_PP_Area     FOREIGN KEY (AreaId)               REFERENCES dbo.Area(AreaId),
    CONSTRAINT FK_PP_Creador  FOREIGN KEY (CreadoPorUsuarioId)   REFERENCES dbo.Usuario(UsuarioId),
    CONSTRAINT FK_PP_UltimaOT FOREIGN KEY (UltimaOrdenTrabajoId) REFERENCES dbo.OrdenTrabajo(OrdenTrabajoId)
);

CREATE TABLE dbo.MaterialPreventivo (
    PlanId      NVARCHAR(20)  NOT NULL,
    NumeroLinea INT           NOT NULL,
    Nombre      NVARCHAR(200) NOT NULL,
    Cantidad    DECIMAL(10,2) NOT NULL CONSTRAINT DF_MP_Cantidad DEFAULT (1),
    Unidad      NVARCHAR(10)  NOT NULL CONSTRAINT DF_MP_Unidad DEFAULT ('pza'),
    CONSTRAINT PK_MaterialPreventivo PRIMARY KEY (PlanId, NumeroLinea),
    CONSTRAINT FK_MP_Plan FOREIGN KEY (PlanId) REFERENCES dbo.PlanPreventivo(PlanId)
);

CREATE TABLE dbo.BitacoraKardex (
    BitacoraId   BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_BitacoraKardex PRIMARY KEY,
    RegistradoEn DATETIME2(3)  NOT NULL CONSTRAINT DF_BK_RegistradoEn DEFAULT (SYSUTCDATETIME()),
    UsuarioId    INT           NULL,
    NombreUsuario NVARCHAR(100) NOT NULL,
    Accion       NVARCHAR(40)  NOT NULL,
    Modulo       NVARCHAR(20)  NOT NULL,
    EntidadId    NVARCHAR(60)  NOT NULL,
    Detalles     NVARCHAR(MAX) NOT NULL,
    CONSTRAINT CK_BK_Modulo CHECK (Modulo IN ('ASSETS','WORK_ORDERS','BREAKDOWNS','PREVENTIVE')),
    CONSTRAINT FK_BK_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuario(UsuarioId)
);
GO

/* ==========================================================================
   2. TIPOS DE TABLA (TVPs)
   ========================================================================== */
CREATE TYPE dbo.TipoListaTexto AS TABLE (
    Valor NVARCHAR(30) NOT NULL
);
GO

CREATE TYPE dbo.TipoMaterialOrdenTrabajo AS TABLE (
    NumeroLinea INT            NOT NULL,
    Descripcion NVARCHAR(200)  NOT NULL,
    Cantidad    DECIMAL(10,2)  NOT NULL,
    Unidad      NVARCHAR(10)   NULL
);
GO

CREATE TYPE dbo.TipoMaterialPreventivo AS TABLE (
    NumeroLinea INT            NOT NULL,
    Nombre      NVARCHAR(200)  NOT NULL,
    Cantidad    DECIMAL(10,2)  NOT NULL,
    Unidad      NVARCHAR(10)   NULL
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
CREATE NONCLUSTERED INDEX IX_Activo_Area_Nombre     ON dbo.Activo(AreaId, Nombre);
CREATE NONCLUSTERED INDEX IX_Activo_Area_Estado     ON dbo.Activo(AreaId, Estado, Nombre);
CREATE NONCLUSTERED INDEX IX_Activo_Serie          ON dbo.Activo(Serie) WHERE Serie IS NOT NULL;
CREATE UNIQUE NONCLUSTERED INDEX UX_HEA_PeriodoAbierto ON dbo.HistorialEstadoActivo(CodigoActivo) WHERE FinalizadoEn IS NULL;
CREATE NONCLUSTERED INDEX IX_OT_Estado_Fecha       ON dbo.OrdenTrabajo(Estado, CreadoEn DESC);
CREATE NONCLUSTERED INDEX IX_OT_Activo_Fecha       ON dbo.OrdenTrabajo(CodigoActivo, CreadoEn DESC);
CREATE NONCLUSTERED INDEX IX_OT_Area_Fecha         ON dbo.OrdenTrabajo(AreaId, CreadoEn DESC);
CREATE NONCLUSTERED INDEX IX_BK_Entidad_Fecha      ON dbo.BitacoraKardex(EntidadId, RegistradoEn DESC);
CREATE NONCLUSTERED INDEX IX_BK_Modulo_Fecha       ON dbo.BitacoraKardex(Modulo, RegistradoEn DESC);
CREATE NONCLUSTERED INDEX IX_BK_Usuario_Fecha      ON dbo.BitacoraKardex(UsuarioId, RegistradoEn DESC);
CREATE NONCLUSTERED INDEX IX_PP_Area_Estado_Prox   ON dbo.PlanPreventivo(AreaId, Estado, ProximaFecha);
CREATE NONCLUSTERED INDEX IX_PP_Estado_Prox        ON dbo.PlanPreventivo(Estado, ProximaFecha);
CREATE NONCLUSTERED INDEX IX_SB_Estado_Fecha       ON dbo.SolicitudBaja(Estado, SolicitadoEn DESC);
CREATE NONCLUSTERED INDEX IX_SB_Activo_Estado      ON dbo.SolicitudBaja(CodigoActivo, Estado);
CREATE NONCLUSTERED INDEX IX_RA_Reportador_Fecha   ON dbo.ReporteAveria(ReportadoPorUsuarioId, ReportadoEn DESC);
CREATE NONCLUSTERED INDEX IX_RA_Estado_Fecha       ON dbo.ReporteAveria(Estado, ReportadoEn DESC);
CREATE NONCLUSTERED INDEX IX_RA_Area_Estado_Fecha  ON dbo.ReporteAveria(AreaId, Estado, ReportadoEn DESC);
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
          JOIN deleted d ON i.CodigoActivo = d.CodigoActivo
         WHERE i.AreaId            <> d.AreaId
            OR i.Nivel             <> d.Nivel
            OR i.RutaAncestros     <> d.RutaAncestros
            OR (i.CodigoActivoPadre <> d.CodigoActivoPadre
                OR (i.CodigoActivoPadre IS NULL AND d.CodigoActivoPadre IS NOT NULL)
                OR (i.CodigoActivoPadre IS NOT NULL AND d.CodigoActivoPadre IS NULL))
            OR (d.Serie IS NOT NULL AND i.Serie <> d.Serie)
    )
    BEGIN
        RAISERROR(N'Violación de inmutabilidad: no se pueden modificar AreaId, Nivel, RutaAncestros, CodigoActivoPadre ni Serie tras la creación.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    UPDATE a
       SET Nombre                    = i.Nombre,
           Marca                     = i.Marca,
           Modelo                    = i.Modelo,
           EstacionId                = i.EstacionId,
           Estado                    = i.Estado,
           TraspasadoACodigo         = i.TraspasadoACodigo,
           Serie                     = i.Serie,
           AtributosDinamicos        = i.AtributosDinamicos,
           DatosImagen               = i.DatosImagen,
           ContadorHijos             = i.ContadorHijos,
           EliminadoEn               = i.EliminadoEn,
           EliminadoPorUsuarioId     = i.EliminadoPorUsuarioId,
           EliminadoPorNombreUsuario = i.EliminadoPorNombreUsuario,
           EsEquipoProceso           = i.EsEquipoProceso,
           ActualizadoEn             = SYSUTCDATETIME()
      FROM dbo.Activo a
      JOIN inserted i ON a.CodigoActivo = i.CodigoActivo;
END;
GO

CREATE OR ALTER TRIGGER dbo.trUsuario_NombreInmutable
ON dbo.Usuario
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(NombreUsuario)
    BEGIN
        IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.UsuarioId = d.UsuarioId WHERE i.NombreUsuario <> d.NombreUsuario)
        BEGIN
            RAISERROR(N'El nombre de usuario (NombreUsuario) es inmutable y no se puede modificar.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;
    END;
END;
GO

/* ==========================================================================
   6. PROCEDIMIENTOS ALMACENADOS
   ========================================================================== */

-- --- AUTH Y USUARIOS ---
CREATE PROCEDURE dbo.uspUsuarioObtenerParaLogin @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UsuarioId AS UserId, u.NombreUsuario AS Username, u.NombreCompleto AS DisplayName,
           u.CodigoRol AS RoleCode, u.PasswordSalt, u.PasswordHash,
           u.IteracionesPassword AS PasswordIterations, u.Deshabilitado AS Disabled,
           u.DebeCambiarPassword AS MustChangePassword, u.SolicitudReinicioPassword AS PasswordResetRequested,
           u.IntentosFallidos AS FailedLoginAttempts, u.BloqueadoHasta AS LockedUntil,
           (SELECT STRING_AGG(CodigoPermiso, ',') FROM dbo.UsuarioPermiso WHERE UsuarioId = u.UsuarioId) AS PermissionsCsv
      FROM dbo.Usuario u
     WHERE u.NombreUsuario = @Username;
END;
GO

CREATE PROCEDURE dbo.uspLoginRegistrarFallo @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuario
       SET IntentosFallidos = IntentosFallidos + 1,
           BloqueadoHasta = CASE WHEN IntentosFallidos + 1 >= 5
                                 THEN DATEADD(MINUTE, 5, SYSUTCDATETIME())
                                 ELSE BloqueadoHasta END
     WHERE UsuarioId = @UserId;
END;
GO

CREATE PROCEDURE dbo.uspLoginReiniciarIntentos @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuario
       SET IntentosFallidos = 0, BloqueadoHasta = NULL
     WHERE UsuarioId = @UserId;
END;
GO

CREATE PROCEDURE dbo.uspLoginMigrarHash
    @UserId INT, @PasswordSalt NVARCHAR(64), @PasswordHash NVARCHAR(128), @PasswordIterations INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuario
       SET PasswordSalt = @PasswordSalt, PasswordHash = @PasswordHash,
           IteracionesPassword = @PasswordIterations, ActualizadoEn = SYSUTCDATETIME()
     WHERE UsuarioId = @UserId;
END;
GO

CREATE PROCEDURE dbo.uspUsuarioCrear
    @Username NVARCHAR(50), @DisplayName NVARCHAR(100), @RoleCode NVARCHAR(20),
    @PasswordSalt NVARCHAR(64), @PasswordHash NVARCHAR(128), @PasswordIterations INT = 20000,
    @MustChangePassword BIT = 0,
    @Permissions dbo.TipoListaTexto READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF EXISTS (SELECT 1 FROM dbo.Usuario WHERE NombreUsuario = @Username)
        BEGIN
            RAISERROR(N'El nombre de usuario ya está en uso.', 16, 1);
        END;

        INSERT INTO dbo.Usuario
            (NombreUsuario, NombreCompleto, CodigoRol, PasswordSalt, PasswordHash,
             IteracionesPassword, DebeCambiarPassword)
        VALUES
            (@Username, @DisplayName, @RoleCode, @PasswordSalt, @PasswordHash,
             @PasswordIterations, @MustChangePassword);

        DECLARE @uid INT = SCOPE_IDENTITY();

        IF EXISTS (SELECT 1 FROM @Permissions)
        BEGIN
            INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
            SELECT DISTINCT @uid, Valor FROM @Permissions;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
            SELECT @uid, CodigoPermiso FROM dbo.RolPermiso WHERE CodigoRol = @RoleCode;
        END;

        COMMIT TRANSACTION;
        SELECT @uid AS NewUserId, @uid AS UsuarioId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.uspUsuarioActualizar
    @UserId INT, @DisplayName NVARCHAR(100) = NULL, @NewRoleCode NVARCHAR(20) = NULL,
    @NewSalt NVARCHAR(64) = NULL, @NewHash NVARCHAR(128) = NULL, @NewIterations INT = NULL,
    @HasCustomPermissions BIT = 0,
    @Permissions dbo.TipoListaTexto READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UserId)
        BEGIN
            RAISERROR(N'El usuario especificado no existe.', 16, 1);
        END;

        UPDATE dbo.Usuario
           SET NombreCompleto      = COALESCE(@DisplayName, NombreCompleto),
               CodigoRol           = COALESCE(@NewRoleCode, CodigoRol),
               PasswordSalt        = COALESCE(@NewSalt, PasswordSalt),
               PasswordHash        = COALESCE(@NewHash, PasswordHash),
               IteracionesPassword = COALESCE(@NewIterations, IteracionesPassword),
               ActualizadoEn       = SYSUTCDATETIME()
         WHERE UsuarioId = @UserId;

        IF @HasCustomPermissions = 1
        BEGIN
            DELETE FROM dbo.UsuarioPermiso WHERE UsuarioId = @UserId;
            INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
            SELECT DISTINCT @UserId, Valor FROM @Permissions;
        END
        ELSE IF @NewRoleCode IS NOT NULL
        BEGIN
            DELETE FROM dbo.UsuarioPermiso WHERE UsuarioId = @UserId;
            INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
            SELECT @UserId, CodigoPermiso FROM dbo.RolPermiso WHERE CodigoRol = @NewRoleCode;
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
    UPDATE dbo.Usuario SET Deshabilitado = @Disabled, ActualizadoEn = SYSUTCDATETIME() WHERE UsuarioId = @UserId;
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
           IteracionesPassword = @PasswordIterations, DebeCambiarPassword = 0,
           SolicitudReinicioPassword = 0, SolicitadoEn = NULL,
           IntentosFallidos = 0, BloqueadoHasta = NULL, ActualizadoEn = SYSUTCDATETIME()
     WHERE UsuarioId = @UserId;
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
           IteracionesPassword = @PasswordIterations, DebeCambiarPassword = 1,
           SolicitudReinicioPassword = 0, SolicitadoEn = NULL,
           IntentosFallidos = 0, BloqueadoHasta = NULL, ActualizadoEn = SYSUTCDATETIME()
     WHERE UsuarioId = @UserId;
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
    SELECT @UserId = UsuarioId, @DisplayName = NombreCompleto, @RoleCode = CodigoRol,
           @AlreadyRequested = SolicitudReinicioPassword
      FROM dbo.Usuario WHERE NombreUsuario = @Username;

    IF @UserId IS NULL
    BEGIN
        RAISERROR(N'Usuario no encontrado.', 16, 1);
        RETURN;
    END;

    IF @AlreadyRequested = 0
    BEGIN
        UPDATE dbo.Usuario
           SET SolicitudReinicioPassword = 1, SolicitadoEn = SYSUTCDATETIME()
         WHERE UsuarioId = @UserId;

        INSERT INTO dbo.SolicitudReinicioPassword (UsuarioId, NombreUsuario, NombreCompleto, CodigoRol, Estado, Detalles)
        VALUES (@UserId, @Username, @DisplayName, @RoleCode, 'pending', N'Solicitud enviada desde pantalla de login.');
    END;
END;
GO

CREATE PROCEDURE dbo.uspSolicitudReinicioPasswordListarPendientes
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SolicitudId AS RequestId, UsuarioId AS UserId, NombreUsuario AS Username,
           NombreCompleto AS DisplayName, CodigoRol AS RoleCode, SolicitadoEn AS RequestedAt, Detalles AS Details
      FROM dbo.SolicitudReinicioPassword
     WHERE Estado = 'pending'
     ORDER BY SolicitadoEn DESC;
END;
GO

CREATE PROCEDURE dbo.uspSolicitudReinicioPasswordMarcarResuelta @RequestId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.SolicitudReinicioPassword SET Estado = 'resolved'
     WHERE SolicitudId = @RequestId AND Estado = 'pending';
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
    SELECT u.UsuarioId AS UserId, u.NombreUsuario AS Username, u.NombreCompleto AS DisplayName,
           u.CodigoRol AS RoleCode, u.Deshabilitado AS Disabled, u.DebeCambiarPassword AS MustChangePassword,
           u.SolicitudReinicioPassword AS PasswordResetRequested, u.SolicitadoEn AS PasswordResetRequestedAt,
           u.CreadoEn AS CreatedAt,
           (SELECT STRING_AGG(CodigoPermiso, ',') FROM dbo.UsuarioPermiso WHERE UsuarioId = u.UsuarioId) AS PermissionsCsv
      FROM dbo.Usuario u
     ORDER BY u.NombreUsuario;
END;
GO

CREATE PROCEDURE dbo.uspUsuarioObtenerPorId @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UsuarioId AS UserId, u.NombreUsuario AS Username, u.NombreCompleto AS DisplayName,
           u.CodigoRol AS RoleCode, u.PasswordSalt, u.PasswordHash,
           u.IteracionesPassword AS PasswordIterations, u.Deshabilitado AS Disabled,
           u.DebeCambiarPassword AS MustChangePassword, u.SolicitudReinicioPassword AS PasswordResetRequested,
           u.SolicitadoEn AS PasswordResetRequestedAt, u.IntentosFallidos AS FailedLoginAttempts,
           u.BloqueadoHasta AS LockedUntil, u.CreadoEn AS CreatedAt,
           (SELECT STRING_AGG(CodigoPermiso, ',') FROM dbo.UsuarioPermiso WHERE UsuarioId = u.UsuarioId) AS PermissionsCsv
      FROM dbo.Usuario u
     WHERE u.UsuarioId = @UserId;
END;
GO

-- --- ÁREAS ---
CREATE PROCEDURE dbo.uspAreaObtenerTodas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT AreaId, Nombre AS Name, CentroCosto AS CostCenter, ContadorActivos AS AssetCounter,
           CreadoEn AS CreatedAt, ActualizadoEn AS UpdatedAt
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
               SET SiguienteNumero += 1
             OUTPUT inserted.SiguienteNumero INTO @cnt(val)
              WHERE Nombre = 'areas';

            DECLARE @nextVal INT; SELECT @nextVal = val FROM @cnt;
            SET @FinalId = CONCAT('A', @nextVal);
        END;

        IF EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @FinalId)
        BEGIN
            RAISERROR(N'Ya existe un área con ese identificador.', 16, 1);
        END;

        INSERT INTO dbo.Area (AreaId, Nombre, CentroCosto, ContadorActivos, CreadoEn)
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
       SET Nombre        = @Name,
           CentroCosto   = COALESCE(@NormCC, CentroCosto),
           ActualizadoEn = SYSUTCDATETIME()
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
    SELECT CodigoActivo AS AssetCode, Nombre AS Name, Marca AS Brand, Modelo AS Model,
           AreaId, EstacionId AS StationId, CodigoActivoPadre AS ParentAssetCode,
           Nivel AS Level, RutaAncestros AS AncestorsPath, Estado AS Status,
           TraspasadoACodigo AS TransferredToId, Serie AS Serial,
           AtributosDinamicos AS DynamicAttributes, DatosImagen AS ImageData,
           ContadorHijos AS ChildCounter, CreadoEn AS CreatedAt, ActualizadoEn AS UpdatedAt,
           EsEquipoProceso AS EsEquipoProceso
      FROM dbo.Activo
     WHERE AreaId = @AreaId AND CodigoActivoPadre IS NULL AND Estado <> 'deleted'
     ORDER BY Nombre ASC;
END;
GO

CREATE PROCEDURE dbo.uspActivoObtenerHijos
    @AreaId NVARCHAR(15) = NULL, @ParentAssetCode NVARCHAR(60) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CodigoActivo AS AssetCode, Nombre AS Name, Marca AS Brand, Modelo AS Model,
           AreaId, EstacionId AS StationId, CodigoActivoPadre AS ParentAssetCode,
           Nivel AS Level, RutaAncestros AS AncestorsPath, Estado AS Status,
           TraspasadoACodigo AS TransferredToId, Serie AS Serial,
           AtributosDinamicos AS DynamicAttributes, DatosImagen AS ImageData,
           ContadorHijos AS ChildCounter, CreadoEn AS CreatedAt, ActualizadoEn AS UpdatedAt,
           EsEquipoProceso AS EsEquipoProceso
      FROM dbo.Activo
     WHERE (@AreaId IS NULL OR AreaId = @AreaId)
       AND ((@ParentAssetCode IS NULL AND CodigoActivoPadre IS NULL) OR CodigoActivoPadre = @ParentAssetCode)
       AND Estado <> 'deleted'
     ORDER BY Nombre ASC;
END;
GO

CREATE PROCEDURE dbo.uspActivoBuscar
    @AreaId NVARCHAR(15) = NULL, @Query NVARCHAR(200), @Status NVARCHAR(25) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT a.CodigoActivo AS AssetCode, a.Nombre AS Name, a.Marca AS Brand, a.Modelo AS Model,
           a.AreaId, a.EstacionId AS StationId, a.CodigoActivoPadre AS ParentAssetCode,
           a.Nivel AS Level, a.RutaAncestros AS AncestorsPath, a.Estado AS Status,
           a.TraspasadoACodigo AS TransferredToId, a.Serie AS Serial,
           a.AtributosDinamicos AS DynamicAttributes, a.DatosImagen AS ImageData,
           a.ContadorHijos AS ChildCounter, a.CreadoEn AS CreatedAt, a.ActualizadoEn AS UpdatedAt,
           a.EsEquipoProceso AS EsEquipoProceso
      FROM dbo.Activo a
     CROSS APPLY (SELECT COUNT(*) AS TokenCount FROM STRING_SPLIT(@Query, ' ') WHERE LTRIM(RTRIM(value)) <> '') cnt
     WHERE (@AreaId IS NULL OR a.AreaId = @AreaId)
       AND a.Estado <> 'deleted'
       AND (@Status IS NULL OR a.Estado = @Status)
       AND (cnt.TokenCount = 0 OR
            (SELECT COUNT(*) FROM STRING_SPLIT(@Query, ' ') t
              WHERE t.value <> '' AND a.TextoBusqueda LIKE '%' + t.value + '%') = cnt.TokenCount)
     ORDER BY a.Nombre ASC;
END;
GO

CREATE PROCEDURE dbo.uspActivoBuscarPorSerie @Serial NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) CodigoActivo AS AssetCode, Nombre AS Name, Marca AS Brand, Modelo AS Model,
           AreaId, EstacionId AS StationId, CodigoActivoPadre AS ParentAssetCode,
           Nivel AS Level, RutaAncestros AS AncestorsPath, Estado AS Status,
           TraspasadoACodigo AS TransferredToId, Serie AS Serial,
           AtributosDinamicos AS DynamicAttributes, DatosImagen AS ImageData,
           ContadorHijos AS ChildCounter, CreadoEn AS CreatedAt, ActualizadoEn AS UpdatedAt,
           EsEquipoProceso AS EsEquipoProceso
      FROM dbo.Activo
     WHERE Serie = @Serial AND Estado <> 'deleted'
     ORDER BY CASE WHEN Estado = 'active' THEN 0 ELSE 1 END, CreadoEn DESC;
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
            IF EXISTS (SELECT 1 FROM dbo.Activo WHERE Serie = @Serial AND Estado <> 'deleted')
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
               SET ContadorActivos += 1
             OUTPUT inserted.ContadorActivos INTO @acTable(val)
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
            IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE CodigoActivo = @ParentAssetCode AND EstadoCandado = 'pending')
            BEGIN
                RAISERROR(N'El activo padre tiene una solicitud de baja pendiente.', 16, 1);
            END;

            DECLARE @parentStatus NVARCHAR(25), @parentPath NVARCHAR(400);
            DECLARE @ccTable TABLE (val INT NOT NULL);

            UPDATE dbo.Activo WITH (UPDLOCK, HOLDLOCK)
               SET ContadorHijos += 1
             OUTPUT inserted.ContadorHijos INTO @ccTable(val)
              WHERE CodigoActivo = @ParentAssetCode;

            SELECT @parentStatus = Estado, @parentPath = RutaAncestros
              FROM dbo.Activo WHERE CodigoActivo = @ParentAssetCode;

            IF @parentStatus IS NULL OR @parentStatus = 'deleted'
            BEGIN
                RAISERROR(N'El activo padre no existe o está eliminado.', 16, 1);
            END;

            DECLARE @cc INT; SELECT @cc = val FROM @ccTable;
            SET @NewAssetCode = CONCAT(@ParentAssetCode, '-', FORMAT(@cc, '00'));
            SET @AncestorsPath = CASE WHEN @parentPath = '' THEN @ParentAssetCode ELSE CONCAT(@parentPath, ',', @ParentAssetCode) END;
        END;

        INSERT INTO dbo.Activo
            (CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, CodigoActivoPadre,
             Nivel, RutaAncestros, Estado, Serie, AtributosDinamicos, DatosImagen,
             ContadorHijos, CreadoEn)
        VALUES
            (@NewAssetCode, @Name, @Brand, @Model, @AreaId, ISNULL(@StationId, ''),
             @ParentAssetCode, @Level, @AncestorsPath, @Status, @Serial,
             @DynamicAttributes, @ImageData, 0, SYSUTCDATETIME());

        INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        VALUES (@NewAssetCode, @Status, SYSUTCDATETIME(), @AreaId, N'Alta inicial del activo', @UserId, @UserName);

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_CREATED', 'ASSETS', @NewAssetCode,
                CONCAT(N'Activo ', @NewAssetCode, N' (', @Name, N') creado en área ', @AreaId, N'.'));

        COMMIT TRANSACTION;
        SELECT @NewAssetCode AS NewAssetCode, @NewAssetCode AS CodigoActivo;
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
        IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE CodigoActivo = @AssetCode AND EstadoCandado = 'pending')
        BEGIN
            RAISERROR(N'El activo tiene una solicitud de baja pendiente.', 16, 1);
        END;

        UPDATE dbo.Activo
           SET Nombre = @Name, Marca = @Brand, Modelo = @Model, EstacionId = ISNULL(@StationId, ''),
               Estado = @Status, AtributosDinamicos = @DynamicAttributes, DatosImagen = @ImageData,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @AssetCode AND Estado <> 'deleted';

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR(N'El activo no existe o está eliminado.', 16, 1);
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
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
        SELECT @srcArea = AreaId, @srcName = Nombre, @srcStatus = Estado
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @SourceAssetCode;

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
           SET ContadorActivos += 1
         OUTPUT inserted.ContadorActivos INTO @targetCounter(val)
          WHERE AreaId = @TargetAreaId;

        DECLARE @nextRoot INT; SELECT @nextRoot = val FROM @targetCounter;
        IF @nextRoot IS NULL
        BEGIN
            RAISERROR(N'El área destino no existe.', 16, 1);
        END;

        DECLARE @newRootCode NVARCHAR(60) = CONCAT(@TargetAreaId, '-', FORMAT(@nextRoot, '000'));

        INSERT INTO dbo.Activo
            (CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, CodigoActivoPadre,
             Nivel, RutaAncestros, Estado, Serie, AtributosDinamicos, DatosImagen, ContadorHijos, CreadoEn)
        SELECT @newRootCode, Nombre, Marca, Modelo, @TargetAreaId, EstacionId, NULL,
               Nivel, '', 'active', Serie, AtributosDinamicos, DatosImagen, ContadorHijos, SYSUTCDATETIME()
          FROM dbo.Activo WHERE CodigoActivo = @SourceAssetCode;

        UPDATE dbo.Activo
           SET Estado = 'transferredDeactivated', TraspasadoACodigo = @newRootCode, ActualizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @SourceAssetCode;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_TRANSFER', 'ASSETS', @SourceAssetCode,
                CONCAT(N'Activo ', @SourceAssetCode, N' traspasado a ', @TargetAreaId, N' como ', @newRootCode, N'.'));

        COMMIT TRANSACTION;
        SELECT @newRootCode AS NewAssetCode, @newRootCode AS CodigoActivo;
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
           SET Estado = 'active', TraspasadoACodigo = NULL, ActualizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @AssetCode AND Estado = 'transferredDeactivated';

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR(N'Solo se pueden reactivar activos en estado desactivado por traspaso.', 16, 1);
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
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
        SELECT @AreaId = AreaId FROM dbo.Activo WHERE CodigoActivo = @AssetCode;
        IF @AreaId IS NULL
        BEGIN
            RAISERROR(N'El activo no existe.', 16, 1);
        END;

        UPDATE dbo.HistorialEstadoActivo SET FinalizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @AssetCode AND FinalizadoEn IS NULL;

        UPDATE dbo.Activo SET Estado = @NewStatus, ActualizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @AssetCode;

        INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        VALUES (@AssetCode, @NewStatus, SYSUTCDATETIME(), @AreaId, @Reason, @UserId, @UserName);

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
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
        SELECT @AssetName = Nombre, @AreaId = AreaId, @Status = Estado
          FROM dbo.Activo WHERE CodigoActivo = @AssetCode;

        IF @AssetName IS NULL OR @Status = 'deleted'
        BEGIN
            RAISERROR(N'El activo no existe o ya está eliminado.', 16, 1);
        END;

        IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE CodigoActivo = @AssetCode AND EstadoCandado = 'pending')
        BEGIN
            RAISERROR(N'El activo ya tiene una solicitud de baja pendiente.', 16, 1);
        END;

        INSERT INTO dbo.SolicitudBaja (CodigoActivo, NombreActivo, AreaId, Estado, Motivo, SolicitadoPorUsuarioId, SolicitadoPorNombreUsuario)
        VALUES (@AssetCode, @AssetName, @AreaId, 'pending', @Reason, @UserId, @UserName);
        DECLARE @rid BIGINT = SCOPE_IDENTITY();

        IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE CodigoActivo = @AssetCode)
            UPDATE dbo.CandadoBaja SET EstadoCandado = 'pending', ActualizadoEn = SYSUTCDATETIME() WHERE CodigoActivo = @AssetCode;
        ELSE
            INSERT INTO dbo.CandadoBaja (CodigoActivo, EstadoCandado) VALUES (@AssetCode, 'pending');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_DELETE_REQUESTED', 'ASSETS', @AssetCode,
                CONCAT(N'Solicitud de baja ', @rid, N' creada para ', @AssetCode, N'. Motivo: "', @Reason, N'".'));

        COMMIT TRANSACTION;
        SELECT @rid AS NewRequestId, @rid AS SolicitudId;
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
    SELECT SolicitudId AS RequestId, CodigoActivo AS AssetCode, NombreActivo AS AssetName, AreaId,
           Estado AS Status, Motivo AS Reason, SolicitadoPorUsuarioId AS RequestedByUserId,
           SolicitadoPorNombreUsuario AS RequestedByUserName, SolicitadoEn AS RequestedAt,
           DecididoPorUsuarioId AS DecidedByUserId, DecididoPorNombreUsuario AS DecidedByUserName,
           DecididoEn AS DecidedAt, MotivoDecision AS DecisionReason
      FROM dbo.SolicitudBaja
     WHERE Estado = 'pending'
       AND (@StartDate IS NULL OR SolicitadoEn >= @StartDate)
       AND (@EndDate   IS NULL OR SolicitadoEn <= @EndDate)
     ORDER BY SolicitadoEn DESC;
END;
GO

CREATE PROCEDURE dbo.uspSolicitudBajaObtenerTodas
    @StartDate DATETIME2(3) = NULL, @EndDate DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SolicitudId AS RequestId, CodigoActivo AS AssetCode, NombreActivo AS AssetName, AreaId,
           Estado AS Status, Motivo AS Reason, SolicitadoPorUsuarioId AS RequestedByUserId,
           SolicitadoPorNombreUsuario AS RequestedByUserName, SolicitadoEn AS RequestedAt,
           DecididoPorUsuarioId AS DecidedByUserId, DecididoPorNombreUsuario AS DecidedByUserName,
           DecididoEn AS DecidedAt, MotivoDecision AS DecisionReason
      FROM dbo.SolicitudBaja
     WHERE (@StartDate IS NULL OR SolicitadoEn >= @StartDate)
       AND (@EndDate   IS NULL OR SolicitadoEn <= @EndDate)
     ORDER BY SolicitadoEn DESC;
END;
GO

CREATE PROCEDURE dbo.uspSolicitudBajaObtenerPendientePorActivo @AssetCode NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) SolicitudId AS RequestId, CodigoActivo AS AssetCode, NombreActivo AS AssetName, AreaId,
           Estado AS Status, Motivo AS Reason, SolicitadoPorUsuarioId AS RequestedByUserId,
           SolicitadoPorNombreUsuario AS RequestedByUserName, SolicitadoEn AS RequestedAt,
           DecididoPorUsuarioId AS DecidedByUserId, DecididoPorNombreUsuario AS DecidedByUserName,
           DecididoEn AS DecidedAt, MotivoDecision AS DecisionReason
      FROM dbo.SolicitudBaja
     WHERE CodigoActivo = @AssetCode AND Estado = 'pending'
     ORDER BY SolicitadoEn DESC;
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
        SELECT @c = CodigoActivo, @nm = NombreActivo, @ar = AreaId, @st = Estado
          FROM dbo.SolicitudBaja WITH (UPDLOCK, HOLDLOCK) WHERE SolicitudId = @RequestId;

        IF @c IS NULL OR @st <> 'pending'
        BEGIN
            RAISERROR(N'Esta solicitud ya fue resuelta o no está pendiente.', 16, 1);
        END;

        UPDATE a
           SET Estado = 'deleted', EliminadoEn = SYSUTCDATETIME(),
               EliminadoPorUsuarioId = @ApproverUserId, EliminadoPorNombreUsuario = @ApproverUserName,
               ActualizadoEn = SYSUTCDATETIME()
          FROM dbo.Activo a
         WHERE a.AreaId = @ar AND a.Estado <> 'deleted'
           AND (a.CodigoActivo = @c OR CHARINDEX(CONCAT(N',', @c, N','), CONCAT(N',', a.RutaAncestros, N',')) > 0);

        UPDATE dbo.SolicitudBaja
           SET Estado = 'approved', DecididoPorUsuarioId = @ApproverUserId,
               DecididoPorNombreUsuario = @ApproverUserName, DecididoEn = SYSUTCDATETIME(),
               MotivoDecision = COALESCE(@ApproveReason, N'')
         WHERE SolicitudId = @RequestId;

        UPDATE dbo.CandadoBaja SET EstadoCandado = 'approved', ActualizadoEn = SYSUTCDATETIME() WHERE CodigoActivo = @c;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
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
        SELECT @c = CodigoActivo, @nm = NombreActivo, @st = Estado
          FROM dbo.SolicitudBaja WITH (UPDLOCK, HOLDLOCK) WHERE SolicitudId = @RequestId;

        IF @c IS NULL OR @st <> 'pending'
        BEGIN
            RAISERROR(N'Esta solicitud ya no está pendiente de resolución.', 16, 1);
        END;

        UPDATE dbo.SolicitudBaja
           SET Estado = 'rejected', DecididoPorUsuarioId = @RejectedByUserId,
               DecididoPorNombreUsuario = @RejectedByUserName, DecididoEn = SYSUTCDATETIME(),
               MotivoDecision = @RejectReason
         WHERE SolicitudId = @RequestId;

        UPDATE dbo.CandadoBaja SET EstadoCandado = 'rejected', ActualizadoEn = SYSUTCDATETIME() WHERE CodigoActivo = @c;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
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
    SELECT w.OrdenTrabajoId AS WorkOrderId, w.CodigoActivo AS AssetCode, w.NombreActivo AS AssetName,
           w.AreaId, w.NombreArea AS AreaName, w.Descripcion AS Description,
           w.Estado AS Status, w.Prioridad AS Priority, w.AsignadoA AS AssignedTo,
           w.CantidadPersonalAsignado AS AssignedStaffCount, w.HorasEstimadas AS EstimatedHours,
           w.HorasReales AS ActualHours, w.DescripcionTrabajoRealizado AS WorkDoneDescription,
           w.EstaCompletada AS IsCompleted, w.MotivoIncumplimiento AS UnfulfillmentReason,
           w.FechaReprogramacion AS ReprogramDate, w.ResponsableAccHaccp AS AccHaccpResponsible,
           w.ResponsableMantenimiento AS MaintenanceResponsible, w.ResponsableJefeArea AS AreaHeadResponsible,
           w.ResponsableJefeMantenimiento AS MaintenanceHeadResponsible, w.FechaProgramada AS ScheduledDate,
           w.ReporteId AS ReportId, w.CreadoPorUsuarioId AS CreatedByUserId,
           w.CreadoPorNombreUsuario AS CreatedByUserName, w.CreadoEn AS CreatedAt,
           m.MaterialsJson,
           t.WorkTypesCsv
      FROM dbo.OrdenTrabajo w
     OUTER APPLY (SELECT (SELECT NumeroLinea AS LineNum, Descripcion AS Description, Cantidad AS Quantity, Unidad AS Unit
                            FROM dbo.MaterialOrdenTrabajo
                           WHERE OrdenTrabajoId = w.OrdenTrabajoId
                           ORDER BY NumeroLinea
                             FOR JSON PATH) AS MaterialsJson) m
     OUTER APPLY (SELECT STRING_AGG(TipoTrabajo, ',') AS WorkTypesCsv
                    FROM dbo.TipoTrabajoOrdenTrabajo
                   WHERE OrdenTrabajoId = w.OrdenTrabajoId) t
     WHERE (@StatusFilter IS NULL OR w.Estado = @StatusFilter)
       AND (@AreaFilter   IS NULL OR w.AreaId = @AreaFilter)
     ORDER BY w.CreadoEn DESC;
END;
GO

CREATE PROCEDURE dbo.uspOrdenTrabajoObtenerAbiertas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT OrdenTrabajoId AS WorkOrderId, CodigoActivo AS AssetCode, NombreActivo AS AssetName,
           AreaId, NombreArea AS AreaName, Descripcion AS Description,
           Estado AS Status, Prioridad AS Priority, AsignadoA AS AssignedTo,
           CantidadPersonalAsignado AS AssignedStaffCount, HorasEstimadas AS EstimatedHours,
           FechaProgramada AS ScheduledDate, ReporteId, CreadoEn AS CreatedAt
      FROM dbo.OrdenTrabajo
     WHERE Estado IN ('pending', 'inProgress')
     ORDER BY CreadoEn DESC;
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
        SELECT @cur = Estado, @rid = ReporteId FROM dbo.OrdenTrabajo WITH (UPDLOCK, HOLDLOCK)
         WHERE OrdenTrabajoId = @WorkOrderId;

        IF @cur IS NULL
        BEGIN
            RAISERROR(N'La orden de trabajo ya no existe.', 16, 1);
        END;

        UPDATE dbo.OrdenTrabajo SET Estado = @NewStatus WHERE OrdenTrabajoId = @WorkOrderId;

        IF @NewStatus = 'completed' AND @rid IS NOT NULL
            UPDATE dbo.ReporteAveria SET Estado = 'resolved', ResueltoPorUsuarioId = @UserId, ResueltoPorNombreUsuario = @UserName, ResueltoEn = SYSUTCDATETIME() WHERE ReporteId = @rid;
        ELSE IF @NewStatus = 'cancelled' AND @rid IS NOT NULL
            UPDATE dbo.ReporteAveria SET Estado = 'reported', OrdenTrabajoId = NULL WHERE ReporteId = @rid;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
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
           SET Descripcion = @Description, Prioridad = @Priority,
               AsignadoA = @AssignedTo, CantidadPersonalAsignado = @AssignedStaffCount,
               HorasEstimadas = @EstimatedHours, HorasReales = @ActualHours,
               DescripcionTrabajoRealizado = @WorkDoneDescription, EstaCompletada = @IsCompleted,
               MotivoIncumplimiento = @UnfulfillmentReason, FechaReprogramacion = @ReprogramDate,
               ResponsableAccHaccp = @AccHaccpResponsible, ResponsableMantenimiento = @MaintenanceResponsible,
               FechaProgramada = @ScheduledDate
         WHERE OrdenTrabajoId = @WorkOrderId;

        DELETE FROM dbo.MaterialOrdenTrabajo WHERE OrdenTrabajoId = @WorkOrderId;
        DELETE FROM dbo.TipoTrabajoOrdenTrabajo WHERE OrdenTrabajoId = @WorkOrderId;

        INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
        SELECT @WorkOrderId, ROW_NUMBER() OVER (ORDER BY NumeroLinea), Descripcion, Cantidad, ISNULL(Unidad, 'pz')
          FROM @Materials;

        INSERT INTO dbo.TipoTrabajoOrdenTrabajo (OrdenTrabajoId, TipoTrabajo)
        SELECT DISTINCT @WorkOrderId, LTRIM(RTRIM(Valor)) FROM @WorkTypes WHERE LTRIM(RTRIM(Valor)) <> '';

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
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
        IF NOT EXISTS (SELECT 1 FROM dbo.Activo WHERE CodigoActivo = @AssetCode)
        BEGIN
            RAISERROR(N'El activo no existe.', 16, 1);
        END;

        INSERT INTO dbo.ReporteAveria (CodigoActivo, NombreActivo, AreaId, Descripcion, Severidad, ReportadoPorUsuarioId, ReportadoPorNombreUsuario)
        VALUES (@AssetCode, @AssetName, @AreaId, @Description, @Severity, @ReporterUserId, @ReporterUserName);
        DECLARE @rid BIGINT = SCOPE_IDENTITY();

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@ReporterUserId, @ReporterUserName, 'BREAKDOWN_REPORTED', 'BREAKDOWNS', @AssetCode,
                CONCAT(N'Reporte ', @rid, N': avería en ', @AssetCode, N' (', @AssetName, N'). Severidad: ', @Severity, N'.'));

        COMMIT TRANSACTION;
        SELECT @rid AS NewReportId, @rid AS ReporteId;
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
    SELECT ReporteId, CodigoActivo AS AssetCode, NombreActivo AS AssetName, AreaId,
           Descripcion AS Description, Severidad AS Severity,
           ReportadoPorUsuarioId AS ReportedByUserId, ReportadoPorNombreUsuario AS ReportedByUserName,
           ReportadoEn AS ReportedAt, Estado AS Status, OrdenTrabajoId AS WorkOrderId,
           ResueltoPorUsuarioId AS ResolvedByUserId, ResueltoPorNombreUsuario AS ResolvedByUserName,
           ResueltoEn AS ResolvedAt, MotivoRechazo AS RejectionReason,
           RechazadoPorUsuarioId AS RejectedByUserId, RechazadoPorNombreUsuario AS RejectedByUserName,
           RechazadoEn AS RejectedAt
      FROM dbo.ReporteAveria
     WHERE (@StatusFilter IS NULL OR Estado = @StatusFilter)
       AND (@StartDate IS NULL OR ReportadoEn >= @StartDate)
       AND (@EndDate   IS NULL OR ReportadoEn <= @EndDate)
     ORDER BY ReportadoEn DESC;
END;
GO

CREATE PROCEDURE dbo.uspReporteAveriaObtenerPorUsuario @ReporterUserId INT
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
           RechazadoEn AS RejectedAt
      FROM dbo.ReporteAveria
     WHERE ReportadoPorUsuarioId = @ReporterUserId
     ORDER BY ReportadoEn DESC;
END;
GO

CREATE PROCEDURE dbo.uspReporteAveriaObtenerAbiertos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ReporteId, CodigoActivo AS AssetCode, NombreActivo AS AssetName, AreaId,
           Descripcion AS Description, Severidad AS Severity,
           ReportadoPorUsuarioId AS ReportedByUserId, ReportadoPorNombreUsuario AS ReportedByUserName,
           ReportadoEn AS ReportedAt, Estado AS Status, OrdenTrabajoId AS WorkOrderId
      FROM dbo.ReporteAveria
     WHERE Estado IN ('reported', 'inWorkOrder')
     ORDER BY ReportadoEn DESC;
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
        UPDATE dbo.ReporteAveria SET Estado = 'inWorkOrder', OrdenTrabajoId = @WorkOrderId WHERE ReporteId = @ReportId;
        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR(N'El reporte ya no existe.', 16, 1);
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
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
       SET Estado = 'resolved', ResueltoPorUsuarioId = @ResolvedByUserId,
           ResueltoPorNombreUsuario = @ResolvedByUserName, ResueltoEn = SYSUTCDATETIME()
     WHERE ReporteId = @ReportId;
    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR(N'El reporte ya no existe.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
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
       SET Estado = 'rejected', MotivoRechazo = @Reason,
           RechazadoPorUsuarioId = @RejectedByUserId, RechazadoPorNombreUsuario = @RejectedByUserName,
           RechazadoEn = SYSUTCDATETIME()
     WHERE ReporteId = @ReportId;
    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR(N'El reporte ya no existe.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
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
    SELECT p.PlanId AS ScheduleId, p.Titulo AS Title, p.CodigoActivo AS AssetCode,
           p.NombreActivo AS AssetName, p.AreaId, p.NombreArea AS AreaName,
           p.TipoMantenimiento AS MaintenanceType, p.Frecuencia AS Frequency,
           p.Descripcion AS Description, p.HorasEstimadas AS EstimatedHours,
           p.FechaInicio AS StartDate, p.ProximaFecha AS NextDate,
           p.UltimaCompletada AS LastCompleted, p.UltimaOrdenTrabajoId AS LastWorkOrderId,
           p.Estado AS Status, p.Notas AS Notes, p.CreadoPorUsuarioId AS CreatedByUserId,
           p.CreadoPorNombreUsuario AS CreatedByUserName, p.CreadoEn AS CreatedAt,
           p.NumeroDocumentoModificacion AS AmendmentDocNumber, p.ModificadoPor AS AmendedBy,
           p.ModificadoEn AS AmendedAt, p.MotivoModificacion AS AmendmentReason,
           m.MaterialsJson
      FROM dbo.PlanPreventivo p
     OUTER APPLY (SELECT (SELECT Nombre AS Name, Cantidad AS Quantity, Unidad AS Unit
                            FROM dbo.MaterialPreventivo
                           WHERE PlanId = p.PlanId
                           ORDER BY NumeroLinea
                             FOR JSON PATH) AS MaterialsJson) m
     WHERE (@AreaFilter   IS NULL OR p.AreaId = @AreaFilter)
       AND (@StatusFilter IS NULL OR p.Estado = @StatusFilter)
     ORDER BY p.ProximaFecha ASC;
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
           SET SiguienteNumero += 1
         OUTPUT deleted.SiguienteNumero INTO @cTable(v)
          WHERE Nombre = 'preventive_schedules';

        DECLARE @n INT; SELECT @n = v FROM @cTable;
        DECLARE @id NVARCHAR(20) = CONCAT('PM-', YEAR(SYSUTCDATETIME()), '-', FORMAT(@n, '0000'));
        DECLARE @FinalTitle NVARCHAR(200) =
            CASE WHEN LTRIM(ISNULL(@Title, N'')) = N'' THEN CONCAT(N'Plan Preventivo ', @id) ELSE @Title END;

        INSERT INTO dbo.PlanPreventivo
            (PlanId, Titulo, CodigoActivo, NombreActivo, AreaId, NombreArea, TipoMantenimiento, Frecuencia,
             Descripcion, HorasEstimadas, FechaInicio, ProximaFecha, UltimaCompletada, UltimaOrdenTrabajoId,
             Estado, Notas, CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn)
        VALUES
            (@id, @FinalTitle, @AssetCode, @AssetName, @AreaId, @AreaName, @MaintenanceType, @Frequency,
             @Description, @EstimatedHours, @StartDate, @NextDate, @LastCompleted, @LastWorkOrderId,
             @Status, @Notes, @CreatedByUserId, @CreatedByUserName, SYSUTCDATETIME());

        INSERT INTO dbo.MaterialPreventivo (PlanId, NumeroLinea, Nombre, Cantidad, Unidad)
        SELECT @id, ROW_NUMBER() OVER (ORDER BY NumeroLinea), Nombre, Cantidad, ISNULL(Unidad, 'pza')
          FROM @Materials;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreatedByUserId, @CreatedByUserName, 'PREVENTIVE_SCHEDULE_CREATED', 'PREVENTIVE', @id,
                CONCAT(N'Plan preventivo ', @id, N' creado para ', @AssetCode, N' - Frecuencia: ', dbo.fnFrecuenciaEtiqueta(@Frequency), N'.'));

        COMMIT TRANSACTION;
        SELECT @id AS NewScheduleId, @id AS PlanId;
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
           SET Titulo = @Title, TipoMantenimiento = @MaintenanceType, Frecuencia = @Frequency,
               Descripcion = @Description, HorasEstimadas = @EstimatedHours,
               FechaInicio = @StartDate, ProximaFecha = @NextDate, Notas = @Notes,
               NumeroDocumentoModificacion = @AmendmentDocNumber,
               ModificadoPor = @UserName,
               ModificadoEn = SYSUTCDATETIME(),
               MotivoModificacion = @AmendmentReason
         WHERE PlanId = @ScheduleId;

        DELETE FROM dbo.MaterialPreventivo WHERE PlanId = @ScheduleId;
        INSERT INTO dbo.MaterialPreventivo (PlanId, NumeroLinea, Nombre, Cantidad, Unidad)
        SELECT @ScheduleId, ROW_NUMBER() OVER (ORDER BY NumeroLinea), Nombre, Cantidad, ISNULL(Unidad, 'pza')
          FROM @Materials;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
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
    SELECT @freq = Frecuencia FROM dbo.PlanPreventivo WHERE PlanId = @ScheduleId;
    IF @freq IS NOT NULL
    BEGIN
        DECLARE @next DATETIME2(3) = DATEADD(DAY, dbo.fnFrecuenciaDias(@freq), SYSUTCDATETIME());
        UPDATE dbo.PlanPreventivo
           SET UltimaCompletada = SYSUTCDATETIME(), UltimaOrdenTrabajoId = @WorkOrderId, ProximaFecha = @next
         WHERE PlanId = @ScheduleId;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
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
       SET Estado = @NewStatus,
           NumeroDocumentoModificacion = @AmendmentDocNumber,
           ModificadoPor = @UserName,
           ModificadoEn = SYSUTCDATETIME(),
           MotivoModificacion = @Reason
     WHERE PlanId = @ScheduleId;

    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
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
    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
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
    SELECT TOP (@Limit) BitacoraId AS LogId, RegistradoEn AS LoggedAt, UsuarioId AS UserId,
           NombreUsuario AS UserName, Accion AS Action, Modulo AS Module, EntidadId AS EntityId,
           Detalles AS Details
      FROM dbo.BitacoraKardex
     WHERE (@ModuleFilter IS NULL OR Modulo = @ModuleFilter)
       AND (@ActionFilter IS NULL OR Accion = @ActionFilter)
       AND (@UserFilter   IS NULL OR UsuarioId = @UserFilter)
       AND (@StartDate    IS NULL OR RegistradoEn >= @StartDate)
       AND (@EndDate      IS NULL OR RegistradoEn <= @EndDate)
     ORDER BY RegistradoEn DESC;
END;
GO

CREATE PROCEDURE dbo.uspKardexObtenerPorEntidad @EntityId NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT BitacoraId AS LogId, RegistradoEn AS LoggedAt, UsuarioId AS UserId,
           NombreUsuario AS UserName, Accion AS Action, Modulo AS Module, EntidadId AS EntityId,
           Detalles AS Details
      FROM dbo.BitacoraKardex
     WHERE EntidadId = @EntityId
     ORDER BY RegistradoEn DESC;
END;
GO

CREATE PROCEDURE dbo.uspDashboardObtenerEstadisticas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM dbo.Activo         WHERE Estado <> 'deleted')                    AS TotalAssets,
        (SELECT COUNT(*) FROM dbo.OrdenTrabajo   WHERE Estado = 'pending')                     AS PendingWorkOrders,
        (SELECT COUNT(*) FROM dbo.OrdenTrabajo   WHERE Estado = 'inProgress')                  AS InProgressWorkOrders,
        (SELECT COUNT(*) FROM dbo.OrdenTrabajo   WHERE Estado = 'completed')                   AS CompletedWorkOrders,
        (SELECT COUNT(*) FROM dbo.PlanPreventivo WHERE Estado = 'active')                      AS ActivePreventiveSchedules,
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

    INSERT INTO dbo.Rol (CodigoRol, Nombre) VALUES
        ('admin',      N'Administrador'),
        ('jefe',       N'Jefe de Mantenimiento'),
        ('reportador', N'Reportador'),
        ('lector',     N'Lector');

    INSERT INTO dbo.Permiso (CodigoPermiso) VALUES
        ('dashboard.view'), ('asset.view'), ('asset.create'), ('asset.edit'),
        ('asset.transfer'), ('asset.delete.request'), ('asset.delete.approve'),
        ('work_order.view'), ('work_order.create'), ('work_order.print'),
        ('preventive.view'), ('kardex.view'),
        ('breakdown.report'), ('breakdown.view'), ('breakdown.manage'),
        ('user.manage');

    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
    SELECT 'admin', CodigoPermiso FROM dbo.Permiso;

    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso) VALUES
        ('jefe', 'dashboard.view'), ('jefe', 'asset.view'),
        ('jefe', 'work_order.view'), ('jefe', 'work_order.create'), ('jefe', 'work_order.print'),
        ('jefe', 'preventive.view'), ('jefe', 'kardex.view'),
        ('jefe', 'breakdown.view'), ('jefe', 'breakdown.manage');

    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso) VALUES
        ('reportador', 'breakdown.report'), ('reportador', 'breakdown.view');

    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso) VALUES
        ('lector', 'dashboard.view'), ('lector', 'asset.view'),
        ('lector', 'work_order.view'), ('lector', 'preventive.view'),
        ('lector', 'kardex.view'), ('lector', 'breakdown.view');

    INSERT INTO dbo.Contador (Nombre, SiguienteNumero) VALUES
        ('areas', 4),
        ('work_orders', 2),
        ('preventive_schedules', 1);

    INSERT INTO dbo.Usuario
        (NombreUsuario, NombreCompleto, CodigoRol, PasswordSalt, PasswordHash,
         IteracionesPassword, Deshabilitado, DebeCambiarPassword)
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

    INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
    SELECT u.UsuarioId, p.CodigoPermiso
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
      ) AS p(NombreUsuario, CodigoPermiso)
        ON p.NombreUsuario = u.NombreUsuario;

    INSERT INTO dbo.Area (AreaId, Nombre, CentroCosto, ContadorActivos)
    VALUES
        ('A1', N'Planta de Procesamiento', 'CC-01', 2),
        ('A2', N'Empacadora',              'CC-02', 0),
        ('A3', N'Cámaras de Frío',         'CC-03', 0);

    INSERT INTO dbo.Activo
        (CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, CodigoActivoPadre, Nivel,
         RutaAncestros, Estado, Serie, ContadorHijos, AtributosDinamicos, CreadoEn)
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

    INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, NombreUsuario)
    SELECT a.CodigoActivo, a.Estado, SYSUTCDATETIME(), a.AreaId, N'Alta inicial del activo', N'admin'
      FROM dbo.Activo a;

    DECLARE @uidAdmin INT, @uidReportador INT;
    SELECT @uidAdmin = UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'admin';
    SELECT @uidReportador = UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'reportador';

    INSERT INTO dbo.OrdenTrabajo
        (OrdenTrabajoId, CodigoActivo, NombreActivo, Descripcion, Estado, Prioridad,
         CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn)
    VALUES
        ('OT-0001', 'A1-001', N'Bomba centrífuga', N'Fuga de aceite en el sello mecánico.',
         'pending', 'high', @uidAdmin, N'Administrador General', DATEADD(DAY, -2, SYSUTCDATETIME()));

    INSERT INTO dbo.ReporteAveria
        (CodigoActivo, NombreActivo, AreaId, Descripcion, Severidad,
         ReportadoPorUsuarioId, ReportadoPorNombreUsuario, ReportadoEn, Estado, OrdenTrabajoId,
         MotivoRechazo, RechazadoPorUsuarioId, RechazadoPorNombreUsuario, RechazadoEn)
    VALUES
        ('A1-001',     N'Bomba centrífuga',  'A1', N'Fuga de aceite en el sello mecánico.',        'high',   @uidReportador, N'reportador', DATEADD(DAY, -3, SYSUTCDATETIME()), 'inWorkOrder', 'OT-0001',
         NULL, NULL, NULL, NULL),
        ('A1-002',     N'Compresor de aire', 'A1', N'Ruido excesivo y vibración al arrancar.',     'medium', @uidReportador, N'reportador', DATEADD(DAY, -1, SYSUTCDATETIME()), 'reported',    NULL,
         NULL, NULL, NULL, NULL),
        ('A1-001-01',  N'Motor eléctrico',   'A1', N'Ligera vibración detectada en el motor.',     'low',    @uidReportador, N'reportador', DATEADD(HOUR, -20, SYSUTCDATETIME()), 'rejected',   NULL,
         N'Vibración dentro de rango aceptable; sin avería.', @uidAdmin, N'Administrador General', DATEADD(HOUR, -18, SYSUTCDATETIME()));

    UPDATE dbo.OrdenTrabajo SET ReporteId = 1 WHERE OrdenTrabajoId = 'OT-0001';

    COMMIT TRANSACTION;
    PRINT N'Seed completado en español: roles, permisos, contadores, usuarios (1234), areas A1-A3, jerarquia de activos (4 niveles), averias y OT-0001.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'Error durante el seed:';
    THROW;
END CATCH
GO

PRINT N'MacsaCMMS inicializada correctamente con campos en Español.';
GO
