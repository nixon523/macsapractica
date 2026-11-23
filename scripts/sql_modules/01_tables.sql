-- ============================================================================
-- MACSA CMMS - SISTEMA DE GESTIÓN DE MANTENIMIENTO (GRUPO MACSA)
-- SCRIPT MAESTRO DE INICIALIZACIÓN Y DESPLIEGUE A PRODUCCIÓN
-- Fecha de Generación: 2026-11-13
-- Entorno: PRODUCCIÓN (SQL Server 2019 / 2022)
-- Base de Datos: MacsaCMMS
-- ============================================================================
-- CONTENIDO Y CARACTERÍSTICAS:
-- 1. Creación/Conexión limpia a MacsaCMMS.
-- 2. Esquema relacional completo en 3NF con integridad referencial y restricciones.
-- 3. Catálogo oficial de las 30 Áreas Operativas de Grupo Macsa (A001 a A030).
-- 4. Catálogo dinámico de Puestos / Cargos (dbo.Puesto).
-- 5. Módulo de Empleados y Personal Técnico (dbo.Empleado con FK PuestoId y AreaId).
-- 6. Matriz de Seguridad RBAC con 5 Roles jerárquicos y 20 permisos granulares:
--    - admin: Administrador General (Nivel 1 - Acceso Total)
--    - jefe: Jefe de Mantenimiento (Nivel 2 - Gestión técnica y operativa)
--    - jefe_area: Jefe de Área / Operaciones (Nivel 3 - Supervisión local y averías)
--    - reportador: Supervisor de Turno (Nivel 4 - Reporte y seguimiento de fallas)
--    - lector: Gerente / Auditoría (Nivel 5 - Solo lectura, reportes, KPIs y OEE)
-- 7. Registro Oficial de Administrador:
--    - Empleado: Nixon Manuel Mendez Galo, Desarrollador, Área TIC'S (A025)
--    - Usuario: NMENDEZ, Rol admin, Contraseña ADMIN123 (PBKDF2-HMAC-SHA256, 20.000 iters)
-- 8. Base de datos 100% limpia de datos de prueba:
--    - Sin activos, sin OTs, sin averías, sin preventivos ni reportes temporales.
--    - Contadores reseteados listos para operación real.
-- 9. Procedimientos Almacenados completos con todas las optimizaciones:
--    - Evidencia fotográfica en Reportes de Avería e inspección en OTs.
--    - Blindaje contra OTs duplicadas en el mismo activo.
--    - Blindaje de bajas y traspasos con OTs abiertas.
--    - Traspaso atómico de subárbol completo (4 niveles).
--    - Paginación de alto rendimiento (@Limit / @Offset) en listados masivos.
--    - Catálogos unificados (uspCatalogosObtener).
-- 10. Kardex inmutable append-only con auditoría integral.
-- 11. Concesión de permisos al usuario/rol macsa_app.
-- ============================================================================

IF DB_ID(N'MacsaCMMS') IS NULL
BEGIN
    CREATE DATABASE MacsaCMMS;
    PRINT N'Base de datos MacsaCMMS creada.';
END;
GO

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NOCOUNT ON;
GO

IF (SELECT compatibility_level FROM sys.databases WHERE name = N'MacsaCMMS') < 130
BEGIN
    ALTER DATABASE MacsaCMMS SET COMPATIBILITY_LEVEL = 150;
END;
GO

PRINT N'============================================================================';
PRINT N'Iniciando limpieza y despliegue del esquema de Producción...';
PRINT N'============================================================================';
GO

-- ----------------------------------------------------------------------------
-- 1. ELIMINACIÓN DE PROCEDIMIENTOS Y FUNCIONES PREVIAS
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS
    dbo.uspUsuarioObtenerParaLogin, dbo.uspLoginRegistrarFallo, dbo.uspLoginReiniciarIntentos, dbo.uspLoginMigrarHash,
    dbo.uspUsuarioCrear, dbo.uspUsuarioActualizar, dbo.uspUsuarioAlternarDeshabilitado,
    dbo.uspUsuarioCambiarPassword, dbo.uspUsuarioReiniciarTemporal,
    dbo.uspSolicitudReinicioPasswordCrear, dbo.uspSolicitudReinicioPasswordListarPendientes, dbo.uspSolicitudReinicioPasswordMarcarResuelta,
    dbo.uspUsuarioObtenerTodos, dbo.uspUsuarioObtenerPorId, dbo.uspCatalogosObtener,
    dbo.uspAreaObtenerTodas, dbo.uspAreaCrear, dbo.uspAreaActualizar, dbo.uspAreaEliminar,
    dbo.uspPuestoListar, dbo.uspPuestoCrear, dbo.uspPuestoActualizar, dbo.uspPuestoEliminar,
    dbo.uspEmpleadoListar, dbo.uspEmpleadoCrear, dbo.uspEmpleadoActualizar, dbo.uspEmpleadoCambiarEstado,
    dbo.uspActivoObtenerHijos, dbo.uspActivoObtenerRaicesPorArea, dbo.uspActivoBuscar, dbo.uspActivoBuscarPorSerie,
    dbo.uspActivoCrear, dbo.uspActivoActualizar, dbo.uspActivoTraspasar, dbo.uspActivoReactivar,
    dbo.uspActivoAlternarEstado, dbo.uspActivoActualizarEsEquipoProceso, dbo.uspEquipoProcesoListarPorArea,
    dbo.uspSolicitudBajaCrear, dbo.uspSolicitudBajaObtenerPendientes, dbo.uspSolicitudBajaObtenerTodas,
    dbo.uspSolicitudBajaObtenerPendientePorActivo, dbo.uspSolicitudBajaAprobar, dbo.uspSolicitudBajaRechazar,
    dbo.uspOrdenTrabajoObtenerTodas, dbo.uspOrdenTrabajoObtenerAbiertas, dbo.uspOrdenTrabajoCrear,
    dbo.uspOrdenTrabajoActualizarEstado, dbo.uspOrdenTrabajoActualizarDetalles,
    dbo.uspGenerarOrdenTrabajoPreventiva, dbo.uspGenerarOrdenesTrabajoPreventivasVencidas,
    dbo.uspReporteAveriaCrear, dbo.uspReporteAveriaObtenerTodos, dbo.uspReporteAveriaObtenerPorUsuario,
    dbo.uspReporteAveriaObtenerAbiertos, dbo.uspReporteAveriaVincularOrdenTrabajo,
    dbo.uspReporteAveriaResolver, dbo.uspReporteAveriaRechazar,
    dbo.uspPlanPreventivoObtenerTodos, dbo.uspPlanPreventivoCrear,
    dbo.uspPlanPreventivoModificar, dbo.uspPlanPreventivoRegistrarEjecucion,
    dbo.uspPlanPreventivoAlternarEstado, dbo.uspPlanPreventivoObtenerIndicadores,
    dbo.uspReporteOperacionRegistrar, dbo.uspReporteOperacionObtenerPorActivo,
    dbo.uspReporteOperacionObtenerPorSemana, dbo.uspReporteOperacionMetricas,
    dbo.uspReporteHistorialActivo, dbo.uspReporteEstacionalidadAverias,
    dbo.uspReporteTopEquiposFallas, dbo.uspReporteConsumoRepuestos, dbo.uspReporteOEEGeneral,
    dbo.uspKardexAgregar, dbo.uspKardexObtenerTodos, dbo.uspKardexObtenerPorEntidad,
    dbo.uspDashboardObtenerEstadisticas, dbo.uspActualizacionAndroidObtener, dbo.uspActualizacionAndroidRegistrar;
GO

DROP FUNCTION IF EXISTS dbo.fnFrecuenciaDias;
DROP FUNCTION IF EXISTS dbo.fnFrecuenciaEtiqueta;
DROP FUNCTION IF EXISTS dbo.fnFrequencyDays;
DROP FUNCTION IF EXISTS dbo.fnFrequencyLabel;
GO

-- ----------------------------------------------------------------------------
-- 2. ELIMINACIÓN DE CLAVES FORÁNEAS Y TABLAS
-- ----------------------------------------------------------------------------
DECLARE @dropFks NVARCHAR(MAX) =
    (SELECT STRING_AGG(N'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id))
                     + N'.' + QUOTENAME(OBJECT_NAME(parent_object_id))
                     + N' DROP CONSTRAINT ' + QUOTENAME(name), N'; ')
       FROM sys.foreign_keys
      WHERE OBJECT_SCHEMA_NAME(parent_object_id) = N'dbo');
IF @dropFks IS NOT NULL EXEC (@dropFks);
GO

DROP TABLE IF EXISTS
    dbo.ActualizacionesAndroid,
    dbo.ReporteOperacionDiaria,
    dbo.MaterialPreventivo,
    dbo.PlanPreventivo,
    dbo.MaterialOrdenTrabajo,
    dbo.TipoTrabajoOrdenTrabajo,
    dbo.OrdenTrabajo,
    dbo.ReporteAveria,
    dbo.SolicitudBaja,
    dbo.CandadoBaja,
    dbo.HistorialEstadoActivo,
    dbo.Activo,
    dbo.UsuarioPermiso,
    dbo.SolicitudReinicioPassword,
    dbo.Usuario,
    dbo.Empleado,
    dbo.Puesto,
    dbo.Area,
    dbo.RolPermiso,
    dbo.Permiso,
    dbo.Rol,
    dbo.Contador,
    dbo.BitacoraKardex;
GO

-- ----------------------------------------------------------------------------
-- 3. TIPOS DE TABLA DEFINIDOS POR EL USUARIO (TVPs)
-- ----------------------------------------------------------------------------
IF TYPE_ID(N'dbo.TipoListaTexto') IS NULL
    CREATE TYPE dbo.TipoListaTexto AS TABLE (
        Valor NVARCHAR(100) NOT NULL
    );
GO

IF TYPE_ID(N'dbo.TipoMaterialOrdenTrabajo') IS NULL
    CREATE TYPE dbo.TipoMaterialOrdenTrabajo AS TABLE (
        NumeroLinea INT            NOT NULL,
        Descripcion NVARCHAR(200)  NOT NULL,
        Cantidad    DECIMAL(10,2)  NOT NULL,
        Unidad      NVARCHAR(20)   NULL
    );
GO

IF TYPE_ID(N'dbo.TipoMaterialPreventivo') IS NULL
    CREATE TYPE dbo.TipoMaterialPreventivo AS TABLE (
        NumeroLinea INT            NOT NULL,
        Nombre      NVARCHAR(200)  NOT NULL,
        Cantidad    DECIMAL(10,2)  NOT NULL,
        Unidad      NVARCHAR(20)   NULL
    );
GO

IF TYPE_ID(N'dbo.StringListType') IS NULL
    CREATE TYPE dbo.StringListType AS TABLE ( Value NVARCHAR(100) NOT NULL );
GO

IF TYPE_ID(N'dbo.WorkOrderMaterialType') IS NULL
    CREATE TYPE dbo.WorkOrderMaterialType AS TABLE ( LineNum INT NOT NULL, Description NVARCHAR(200) NOT NULL, Quantity DECIMAL(10,2) NOT NULL, Unit NVARCHAR(20) NULL );
GO

IF TYPE_ID(N'dbo.PreventiveMaterialType') IS NULL
    CREATE TYPE dbo.PreventiveMaterialType AS TABLE ( LineNum INT NOT NULL, Name NVARCHAR(200) NOT NULL, Quantity DECIMAL(10,2) NOT NULL, Unit NVARCHAR(20) NULL );
GO

-- ----------------------------------------------------------------------------
-- 4. FUNCIONES AUXILIARES DE FRECUENCIA PREVENTIVA
-- ----------------------------------------------------------------------------
CREATE FUNCTION dbo.fnFrecuenciaDias (@Frecuencia NVARCHAR(20))
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

CREATE FUNCTION dbo.fnFrecuenciaEtiqueta (@Frecuencia NVARCHAR(20))
RETURNS NVARCHAR(25)
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

CREATE FUNCTION dbo.fnFrequencyDays (@Frequency NVARCHAR(20))
RETURNS INT AS BEGIN RETURN dbo.fnFrecuenciaDias(@Frequency); END;
GO

CREATE FUNCTION dbo.fnFrequencyLabel (@Frequency NVARCHAR(20))
RETURNS NVARCHAR(25) AS BEGIN RETURN dbo.fnFrecuenciaEtiqueta(@Frequency); END;
GO

-- ----------------------------------------------------------------------------
-- 5. TABLAS MAESTRAS Y ESTRUCTURA DE SEGURIDAD
-- ----------------------------------------------------------------------------

-- 5.1 Catálogo de Roles
CREATE TABLE dbo.Rol (
    CodigoRol           NVARCHAR(20) NOT NULL CONSTRAINT PK_Rol PRIMARY KEY,
    Nombre              NVARCHAR(60) NOT NULL
);
GO

-- 5.2 Catálogo de Permisos Granulares
CREATE TABLE dbo.Permiso (
    CodigoPermiso       NVARCHAR(50) NOT NULL CONSTRAINT PK_Permiso PRIMARY KEY
);
GO

-- 5.3 Matriz Rol-Permiso
CREATE TABLE dbo.RolPermiso (
    CodigoRol           NVARCHAR(20) NOT NULL,
    CodigoPermiso       NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_RolPermiso PRIMARY KEY (CodigoRol, CodigoPermiso),
    CONSTRAINT FK_RolPermiso_Rol     FOREIGN KEY (CodigoRol)     REFERENCES dbo.Rol(CodigoRol) ON DELETE CASCADE,
    CONSTRAINT FK_RolPermiso_Permiso FOREIGN KEY (CodigoPermiso) REFERENCES dbo.Permiso(CodigoPermiso) ON DELETE CASCADE
);
GO

-- 5.4 Contadores Transaccionales
CREATE TABLE dbo.Contador (
    Nombre              NVARCHAR(30) NOT NULL CONSTRAINT PK_Contador PRIMARY KEY,
    SiguienteNumero     INT          NOT NULL CONSTRAINT DF_Contador_SiguienteNumero DEFAULT (1),
    CONSTRAINT CK_Contador_SiguienteNumero CHECK (SiguienteNumero > 0)
);
GO

-- 5.5 Catálogo de Áreas
CREATE TABLE dbo.Area (
    AreaId             NVARCHAR(15)  NOT NULL CONSTRAINT PK_Area PRIMARY KEY,
    Nombre             NVARCHAR(100) NOT NULL,
    CentroCosto        NVARCHAR(50)  NOT NULL,
    ContadorActivos    INT           NOT NULL CONSTRAINT DF_Area_ContadorActivos DEFAULT (0),
    Activo             BIT           NOT NULL CONSTRAINT DF_Area_Activo DEFAULT (1),
    CreadoEn           DATETIME2(3)  NOT NULL CONSTRAINT DF_Area_CreadoEn DEFAULT (SYSUTCDATETIME()),
    ActualizadoEn      DATETIME2(3)  NULL
);
GO

-- 5.6 Catálogo Dinámico de Puestos / Cargos
CREATE TABLE dbo.Puesto (
    PuestoId           INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Puesto PRIMARY KEY,
    Nombre             NVARCHAR(100) NOT NULL CONSTRAINT UQ_Puesto_Nombre UNIQUE,
    EsMantenimiento    BIT NOT NULL CONSTRAINT DF_Puesto_EsMantenimiento DEFAULT (1),
    Activo             BIT NOT NULL CONSTRAINT DF_Puesto_Activo DEFAULT (1),
    CreadoEn           DATETIME2(3) NOT NULL CONSTRAINT DF_Puesto_CreadoEn DEFAULT (SYSUTCDATETIME()),
    ActualizadoEn      DATETIME2(3) NOT NULL CONSTRAINT DF_Puesto_ActualizadoEn DEFAULT (SYSUTCDATETIME())
);
GO

CREATE NONCLUSTERED INDEX IX_Puesto_Activo_Nombre
    ON dbo.Puesto (Activo, Nombre);
GO

-- 5.7 Catálogo de Empleados
CREATE TABLE dbo.Empleado (
    EmpleadoId         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Empleado PRIMARY KEY,
    NombreCompleto     NVARCHAR(150) NOT NULL,
    PuestoId           INT NULL,
    Puesto             NVARCHAR(100) NOT NULL,
    AreaId             NVARCHAR(15) NULL,
    NombreArea         NVARCHAR(200) NULL,
    EsMantenimiento    BIT NOT NULL CONSTRAINT DF_Empleado_EsMantenimiento DEFAULT (1),
    Activo             BIT NOT NULL CONSTRAINT DF_Empleado_Activo DEFAULT (1),
    CreadoEn           DATETIME2(3) NOT NULL CONSTRAINT DF_Empleado_CreadoEn DEFAULT (SYSUTCDATETIME()),
    ActualizadoEn      DATETIME2(3) NOT NULL CONSTRAINT DF_Empleado_ActualizadoEn DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT FK_Empleado_Puesto FOREIGN KEY (PuestoId) REFERENCES dbo.Puesto(PuestoId),
    CONSTRAINT FK_Empleado_Area   FOREIGN KEY (AreaId)   REFERENCES dbo.Area(AreaId)
);
GO

CREATE NONCLUSTERED INDEX IX_Empleado_PuestoId
    ON dbo.Empleado (PuestoId) INCLUDE (Activo, EsMantenimiento);
GO

CREATE NONCLUSTERED INDEX IX_Empleado_Activo_Mantenimiento
    ON dbo.Empleado (Activo, EsMantenimiento, NombreCompleto);
GO

CREATE NONCLUSTERED INDEX IX_Empleado_Area
    ON dbo.Empleado (AreaId);
GO

-- 5.8 Tabla de Usuarios
CREATE TABLE dbo.Usuario (
    UsuarioId                 INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Usuario PRIMARY KEY,
    NombreUsuario             NVARCHAR(50)  NOT NULL CONSTRAINT UQ_Usuario_NombreUsuario UNIQUE,
    NombreCompleto            NVARCHAR(150) NOT NULL,
    CodigoRol                 NVARCHAR(20)  NOT NULL,
    EmpleadoId                INT           NULL,
    PasswordSalt              NVARCHAR(64)  NOT NULL,
    PasswordHash              NVARCHAR(128) NOT NULL,
    IteracionesPassword       INT           NOT NULL CONSTRAINT DF_Usuario_Iteraciones DEFAULT (20000),
    Deshabilitado             BIT           NOT NULL CONSTRAINT DF_Usuario_Deshabilitado DEFAULT (0),
    DebeCambiarPassword       BIT           NOT NULL CONSTRAINT DF_Usuario_DebeCambiar DEFAULT (0),
    SolicitudReinicioPassword BIT           NOT NULL CONSTRAINT DF_Usuario_SolicitudReinicio DEFAULT (0),
    SolicitadoEn              DATETIME2(3)  NULL,
    IntentosFallidos          INT           NOT NULL CONSTRAINT DF_Usuario_IntentosFallidos DEFAULT (0),
    BloqueadoHasta            DATETIME2(3)  NULL,
    CreadoEn                  DATETIME2(3)  NOT NULL CONSTRAINT DF_Usuario_CreadoEn DEFAULT (SYSUTCDATETIME()),
    ActualizadoEn             DATETIME2(3)  NULL,
    CONSTRAINT CK_Usuario_Iteraciones CHECK (IteracionesPassword >= 10000),
    CONSTRAINT FK_Usuario_Rol      FOREIGN KEY (CodigoRol) REFERENCES dbo.Rol(CodigoRol),
    CONSTRAINT FK_Usuario_Empleado FOREIGN KEY (EmpleadoId) REFERENCES dbo.Empleado(EmpleadoId)
);
GO

CREATE NONCLUSTERED INDEX IX_Usuario_EmpleadoId
    ON dbo.Usuario (EmpleadoId);
GO

CREATE NONCLUSTERED INDEX IX_Usuario_CodigoRol_Activo
    ON dbo.Usuario (CodigoRol, Deshabilitado);
GO

-- 5.9 Permisos Granulares por Usuario
CREATE TABLE dbo.UsuarioPermiso (
    UsuarioId          INT          NOT NULL,
    CodigoPermiso      NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_UsuarioPermiso PRIMARY KEY (UsuarioId, CodigoPermiso),
    CONSTRAINT FK_UP_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuario(UsuarioId) ON DELETE CASCADE,
    CONSTRAINT FK_UP_Permiso FOREIGN KEY (CodigoPermiso) REFERENCES dbo.Permiso(CodigoPermiso)
);
GO

-- 5.10 Solicitudes de Reinicio de Contraseña
CREATE TABLE dbo.SolicitudReinicioPassword (
    SolicitudId       BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SolicitudReinicioPassword PRIMARY KEY,
    UsuarioId         INT           NOT NULL,
    NombreUsuario     NVARCHAR(50)  NOT NULL,
    NombreCompleto    NVARCHAR(150) NOT NULL,
    CodigoRol         NVARCHAR(20)  NOT NULL,
    Estado            NVARCHAR(15)  NOT NULL CONSTRAINT DF_SRP_Estado DEFAULT ('pending'),
    SolicitadoEn      DATETIME2(3)  NOT NULL CONSTRAINT DF_SRP_SolicitadoEn DEFAULT (SYSUTCDATETIME()),
    Detalles          NVARCHAR(500) NULL,
    CONSTRAINT CK_SRP_Estado CHECK (Estado IN ('pending', 'resolved', 'cancelled')),
    CONSTRAINT FK_SRP_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuario(UsuarioId)
);
GO

CREATE NONCLUSTERED INDEX IX_SRP_Estado_Fecha
    ON dbo.SolicitudReinicioPassword (Estado, SolicitadoEn DESC);
GO

-- ----------------------------------------------------------------------------
-- 6. MÓDULO DE ACTIVOS Y JERARQUÍA
-- ----------------------------------------------------------------------------
CREATE TABLE dbo.Activo (
    CodigoActivo               NVARCHAR(60) NOT NULL CONSTRAINT PK_Activo PRIMARY KEY,
    Nombre                     NVARCHAR(200) NOT NULL,
    Marca                      NVARCHAR(100) NULL,
    Modelo                     NVARCHAR(100) NULL,
    AreaId                     NVARCHAR(15)  NOT NULL,
    EstacionId                 NVARCHAR(100) NOT NULL CONSTRAINT DF_Activo_EstacionId DEFAULT (''),
    CodigoActivoPadre          NVARCHAR(60)  NULL,
    Nivel                      NVARCHAR(20)  NOT NULL,
    RutaAncestros              NVARCHAR(400) NOT NULL CONSTRAINT DF_Activo_RutaAncestros DEFAULT (''),
    Estado                     NVARCHAR(25)  NOT NULL CONSTRAINT DF_Activo_Estado DEFAULT ('active'),
    TraspasadoACodigo          NVARCHAR(60)  NULL,
    Serie                      NVARCHAR(100) NULL,
    AtributosDinamicos         NVARCHAR(MAX) NULL,
    DatosImagen                NVARCHAR(500) NULL,
    EsEquipoProceso            BIT           NOT NULL CONSTRAINT DF_Activo_EsEquipoProceso DEFAULT (0),
    ContadorHijos              INT           NOT NULL CONSTRAINT DF_Activo_ContadorHijos DEFAULT (0),
    EliminadoEn                DATETIME2(3)  NULL,
    EliminadoPorUsuarioId      INT           NULL,
    EliminadoPorNombreUsuario  NVARCHAR(100) NULL,
    TextoBusqueda              AS (CONCAT(CodigoActivo,' ',Nombre,' ',ISNULL(Marca,''),' ',ISNULL(Modelo,''),' ',ISNULL(Serie,''))) PERSISTED,
    CreadoEn                   DATETIME2(3)  NOT NULL CONSTRAINT DF_Activo_CreadoEn DEFAULT (SYSUTCDATETIME()),
    ActualizadoEn              DATETIME2(3)  NULL,
    VersionFila                ROWVERSION,
    CONSTRAINT CK_Activo_Nivel   CHECK (Nivel IN ('equipment','subEquipment','part','subPart')),
    CONSTRAINT CK_Activo_Estado  CHECK (Estado IN ('active','transferredDeactivated','inactive','deleted')),
    CONSTRAINT CK_Activo_Json    CHECK (AtributosDinamicos IS NULL OR ISJSON(AtributosDinamicos) = 1),
    CONSTRAINT FK_Activo_Area    FOREIGN KEY (AreaId) REFERENCES dbo.Area(AreaId),
    CONSTRAINT FK_Activo_Padre   FOREIGN KEY (CodigoActivoPadre) REFERENCES dbo.Activo(CodigoActivo),
    CONSTRAINT FK_Activo_BajaPor FOREIGN KEY (EliminadoPorUsuarioId) REFERENCES dbo.Usuario(UsuarioId)
);
GO

CREATE NONCLUSTERED INDEX IX_Activo_CodigoActivoPadre
    ON dbo.Activo (CodigoActivoPadre)
    INCLUDE (AreaId, Nivel, Estado, Nombre)
    WHERE CodigoActivoPadre IS NOT NULL;
GO

CREATE NONCLUSTERED INDEX IX_Activo_Area_Nivel_Estado
    ON dbo.Activo (AreaId, Nivel, Estado)
    INCLUDE (Nombre, Marca, Modelo, Serie, ContadorHijos);
GO

CREATE NONCLUSTERED INDEX IX_Activo_Serie
    ON dbo.Activo (Serie)
    WHERE Serie IS NOT NULL AND Estado <> 'deleted';
GO

CREATE NONCLUSTERED INDEX IX_Activo_TextoBusqueda
    ON dbo.Activo (TextoBusqueda)
    INCLUDE (AreaId, Estado, Nivel);
GO

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
GO

CREATE NONCLUSTERED INDEX IX_HEA_Activo_IniciadoEn
    ON dbo.HistorialEstadoActivo (CodigoActivo, IniciadoEn DESC);
GO

CREATE TABLE dbo.CandadoBaja (
    CodigoActivo       NVARCHAR(60) NOT NULL CONSTRAINT PK_CandadoBaja PRIMARY KEY,
    EstadoCandado      NVARCHAR(10) NOT NULL,
    ActualizadoEn      DATETIME2(3) NOT NULL CONSTRAINT DF_CB_ActualizadoEn DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT CK_CB_Estado CHECK (EstadoCandado IN ('pending','approved','rejected')),
    CONSTRAINT FK_CB_Activo FOREIGN KEY (CodigoActivo) REFERENCES dbo.Activo(CodigoActivo)
);
GO

CREATE TABLE dbo.SolicitudBaja (
    SolicitudId                  BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SolicitudBaja PRIMARY KEY,
    CodigoActivo                 NVARCHAR(60)   NOT NULL,
    NombreActivo                 NVARCHAR(200)  NOT NULL,
    AreaId                       NVARCHAR(15)   NOT NULL,
    Estado                       NVARCHAR(10)   NOT NULL CONSTRAINT DF_SB_Estado DEFAULT ('pending'),
    Motivo                       NVARCHAR(1000) NOT NULL,
    SolicitadoPorUsuarioId       INT            NOT NULL,
    SolicitadoPorNombreUsuario   NVARCHAR(100)  NOT NULL,
    SolicitadoEn                 DATETIME2(3)   NOT NULL CONSTRAINT DF_SB_SolicitadoEn DEFAULT (SYSUTCDATETIME()),
    DecididoPorUsuarioId         INT            NULL,
    DecididoPorNombreUsuario     NVARCHAR(100)  NULL,
    DecididoEn                   DATETIME2(3)   NULL,
    MotivoDecision               NVARCHAR(500)  NULL,
    VersionFila                  ROWVERSION,
    CONSTRAINT CK_SB_Estado CHECK (Estado IN ('pending','approved','rejected')),
    CONSTRAINT FK_SB_Activo      FOREIGN KEY (CodigoActivo)           REFERENCES dbo.Activo(CodigoActivo),
    CONSTRAINT FK_SB_Area        FOREIGN KEY (AreaId)                 REFERENCES dbo.Area(AreaId),
    CONSTRAINT FK_SB_Solicitante FOREIGN KEY (SolicitadoPorUsuarioId) REFERENCES dbo.Usuario(UsuarioId),
    CONSTRAINT FK_SB_Decisor     FOREIGN KEY (DecididoPorUsuarioId)   REFERENCES dbo.Usuario(UsuarioId)
);
GO

CREATE NONCLUSTERED INDEX IX_SB_Estado_SolicitadoEn
    ON dbo.SolicitudBaja (Estado, SolicitadoEn DESC);
GO

-- ----------------------------------------------------------------------------
-- 7. MÓDULO DE AVERÍAS Y ÓRDENES DE TRABAJO
-- ----------------------------------------------------------------------------
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
    ImagenUrl                  NVARCHAR(MAX) NULL,
    VersionFila                ROWVERSION,
    CONSTRAINT CK_RA_Severidad CHECK (Severidad IN ('low','medium','high','critical')),
    CONSTRAINT CK_RA_Estado    CHECK (Estado IN ('reported','inWorkOrder','resolved','rejected','pending','inProgress')),
    CONSTRAINT FK_RA_Activo     FOREIGN KEY (CodigoActivo)          REFERENCES dbo.Activo(CodigoActivo),
    CONSTRAINT FK_RA_Reportador FOREIGN KEY (ReportadoPorUsuarioId) REFERENCES dbo.Usuario(UsuarioId),
    CONSTRAINT FK_RA_Resolutor  FOREIGN KEY (ResueltoPorUsuarioId)  REFERENCES dbo.Usuario(UsuarioId),
    CONSTRAINT FK_RA_Rechazador FOREIGN KEY (RechazadoPorUsuarioId) REFERENCES dbo.Usuario(UsuarioId)
);
GO

CREATE NONCLUSTERED INDEX IX_ReporteAveria_Estado_ReportadoEn
    ON dbo.ReporteAveria (Estado, ReportadoEn DESC)
    INCLUDE (CodigoActivo, Severidad, AreaId);
GO

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
    PlanPreventivoId            NVARCHAR(20)  NULL,
    ActualizadoEn               DATETIME2(3)  NULL,
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
GO

ALTER TABLE dbo.ReporteAveria ADD CONSTRAINT FK_RA_OrdenTrabajo
    FOREIGN KEY (OrdenTrabajoId) REFERENCES dbo.OrdenTrabajo(OrdenTrabajoId);
GO

CREATE NONCLUSTERED INDEX IX_OrdenTrabajo_Estado_Fecha
    ON dbo.OrdenTrabajo (Estado, CreadoEn DESC)
    INCLUDE (CodigoActivo, Prioridad, AsignadoA, AreaId);
GO

CREATE NONCLUSTERED INDEX IX_OrdenTrabajo_CodigoActivo
    ON dbo.OrdenTrabajo (CodigoActivo, Estado);
GO

CREATE TABLE dbo.MaterialOrdenTrabajo (
    OrdenTrabajoId NVARCHAR(20)   NOT NULL,
    NumeroLinea    INT            NOT NULL,
    Descripcion    NVARCHAR(200)  NOT NULL,
    Cantidad       DECIMAL(10,2)  NOT NULL CONSTRAINT DF_MOT_Cantidad DEFAULT (1),
    Unidad         NVARCHAR(20)   NOT NULL CONSTRAINT DF_MOT_Unidad DEFAULT ('pz'),
    CONSTRAINT PK_MaterialOrdenTrabajo PRIMARY KEY (OrdenTrabajoId, NumeroLinea),
    CONSTRAINT FK_MOT_Orden FOREIGN KEY (OrdenTrabajoId) REFERENCES dbo.OrdenTrabajo(OrdenTrabajoId) ON DELETE CASCADE
);
GO

CREATE TABLE dbo.TipoTrabajoOrdenTrabajo (
    OrdenTrabajoId NVARCHAR(20) NOT NULL,
    TipoTrabajo    NVARCHAR(30) NOT NULL,
    CONSTRAINT PK_TipoTrabajoOrdenTrabajo PRIMARY KEY (OrdenTrabajoId, TipoTrabajo),
    CONSTRAINT CK_TTOT_Tipo CHECK (TipoTrabajo IN
        ('electric','mechanical','urgency','refrigeration','plumbing','preventive','corrective','scheduled')),
    CONSTRAINT FK_TTOT_Orden FOREIGN KEY (OrdenTrabajoId) REFERENCES dbo.OrdenTrabajo(OrdenTrabajoId) ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------------------------
-- 8. MÓDULO DE MANTENIMIENTO PREVENTIVO
-- ----------------------------------------------------------------------------
CREATE TABLE dbo.PlanPreventivo (
    PlanId                      NVARCHAR(20)  NOT NULL CONSTRAINT PK_PlanPreventivo PRIMARY KEY,
    Titulo                      NVARCHAR(200) NOT NULL,
    CodigoActivo                NVARCHAR(60)  NOT NULL,
    NombreActivo                NVARCHAR(200) NOT NULL,
    AreaId                      NVARCHAR(15)  NOT NULL,
    NombreArea                  NVARCHAR(200) NOT NULL,
    TipoMantenimiento           NVARCHAR(100) NOT NULL,
    Frecuencia                  NVARCHAR(20)  NOT NULL,
    Descripcion                 NVARCHAR(MAX) NULL,
    HorasEstimadas              DECIMAL(6,2)  NULL,
    FechaInicio                 DATETIME2(3)  NOT NULL,
    ProximaFecha                DATETIME2(3)  NOT NULL,
    UltimaCompletada            DATETIME2(3)  NULL,
    UltimaOrdenTrabajoId        NVARCHAR(20)  NULL,
    Estado                      NVARCHAR(15)  NOT NULL CONSTRAINT DF_PP_Estado DEFAULT ('active'),
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
    CONSTRAINT CK_PP_Estado CHECK (Estado IN ('active','paused','completed','deleted')),
    CONSTRAINT FK_PP_Activo   FOREIGN KEY (CodigoActivo)         REFERENCES dbo.Activo(CodigoActivo),
    CONSTRAINT FK_PP_Area     FOREIGN KEY (AreaId)               REFERENCES dbo.Area(AreaId),
    CONSTRAINT FK_PP_Creador  FOREIGN KEY (CreadoPorUsuarioId)   REFERENCES dbo.Usuario(UsuarioId),
    CONSTRAINT FK_PP_UltimaOT FOREIGN KEY (UltimaOrdenTrabajoId) REFERENCES dbo.OrdenTrabajo(OrdenTrabajoId)
);
GO

CREATE NONCLUSTERED INDEX IX_PlanPreventivo_ProximaFecha
    ON dbo.PlanPreventivo (Estado, ProximaFecha ASC)
    INCLUDE (CodigoActivo, Titulo, AreaId, Frecuencia);
GO

CREATE TABLE dbo.MaterialPreventivo (
    PlanId      NVARCHAR(20)  NOT NULL,
    NumeroLinea INT           NOT NULL,
    Nombre      NVARCHAR(200) NOT NULL,
    Cantidad    DECIMAL(10,2) NOT NULL CONSTRAINT DF_MP_Cantidad DEFAULT (1),
    Unidad      NVARCHAR(20)  NOT NULL CONSTRAINT DF_MP_Unidad DEFAULT ('pza'),
    CONSTRAINT PK_MaterialPreventivo PRIMARY KEY (PlanId, NumeroLinea),
    CONSTRAINT FK_MP_Plan FOREIGN KEY (PlanId) REFERENCES dbo.PlanPreventivo(PlanId) ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------------------------
-- 9. MÓDULO DE OPERACIÓN DIARIA, INDICADORES Y DISPONIBILIDAD (OEE)
-- ----------------------------------------------------------------------------
CREATE TABLE dbo.ReporteOperacionDiaria (
    ReporteId                    BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ReporteOperacionDiaria PRIMARY KEY,
    CodigoActivo                 NVARCHAR(60)   NOT NULL,
    AreaId                       NVARCHAR(15)   NOT NULL,
    FechaOperacion               DATE           NOT NULL,
    HorasTotalesJornada          DECIMAL(5,2)   NOT NULL CONSTRAINT DF_ROD_HorasJornada DEFAULT (24.00),
    HorasOperacion               DECIMAL(5,2)   NOT NULL,
    HorasParoFalla               DECIMAL(5,2)   NOT NULL CONSTRAINT DF_ROD_ParoFalla    DEFAULT (0.00),
    HorasParoMantPrev            DECIMAL(5,2)   NOT NULL CONSTRAINT DF_ROD_ParoPrev     DEFAULT (0.00),
    HorasParoMantCorr            DECIMAL(5,2)   NOT NULL CONSTRAINT DF_ROD_ParoCorr     DEFAULT (0.00),
    HorasParoPlanificado         DECIMAL(5,2)   NOT NULL CONSTRAINT DF_ROD_ParoPlan     DEFAULT (0.00),
    HorasParoExterno             DECIMAL(5,2)   NOT NULL CONSTRAINT DF_ROD_ParoExt      DEFAULT (0.00),
    Observaciones                NVARCHAR(1000) NULL,
    RegistradoPorUsuarioId       INT            NULL,
    RegistradoPorNombreUsuario   NVARCHAR(200)  NOT NULL,
    RegistradoEn                 DATETIME2(0)   NOT NULL CONSTRAINT DF_ROD_RegistradoEn DEFAULT (SYSUTCDATETIME()),
    ActualizadoEn                DATETIME2(0)   NULL,
    CONSTRAINT UQ_ROD_Activo_Fecha UNIQUE (CodigoActivo, FechaOperacion),
    CONSTRAINT FK_ROD_Activo FOREIGN KEY (CodigoActivo) REFERENCES dbo.Activo(CodigoActivo),
    CONSTRAINT FK_ROD_Area   FOREIGN KEY (AreaId)       REFERENCES dbo.Area(AreaId)
);
GO

CREATE NONCLUSTERED INDEX IX_ROD_Fecha_Activo
    ON dbo.ReporteOperacionDiaria (FechaOperacion DESC, CodigoActivo);
GO

-- ----------------------------------------------------------------------------
-- 10. CONTROL DE ACTUALIZACIONES ANDROID (MÓVIL)
-- ----------------------------------------------------------------------------
CREATE TABLE dbo.ActualizacionesAndroid (
    IdApp       INT IDENTITY(1,1) NOT NULL,
    VersionApp  NVARCHAR(50)      NOT NULL,
    Fecha       DATE              NOT NULL CONSTRAINT DF_ActualizacionesAndroid_Fecha DEFAULT (CAST(GETDATE() AS DATE)),
    Obligatorio BIT               NOT NULL CONSTRAINT DF_ActualizacionesAndroid_Obligatorio DEFAULT (0),
    CreadoEn    DATETIME2(0)      NOT NULL CONSTRAINT DF_ActualizacionesAndroid_CreadoEn DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_ActualizacionesAndroid PRIMARY KEY CLUSTERED (IdApp ASC)
);
GO

-- ----------------------------------------------------------------------------
-- 11. BITÁCORA KARDEX (AUDITORÍA APPEND-ONLY)
-- ----------------------------------------------------------------------------
CREATE TABLE dbo.BitacoraKardex (
    BitacoraId   BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_BitacoraKardex PRIMARY KEY,
    RegistradoEn DATETIME2(3)  NOT NULL CONSTRAINT DF_BK_RegistradoEn DEFAULT (SYSUTCDATETIME()),
    UsuarioId    INT           NULL,
    NombreUsuario NVARCHAR(100) NOT NULL,
    Accion       NVARCHAR(40)  NOT NULL,
    Modulo       NVARCHAR(30)  NOT NULL,
    EntidadId    NVARCHAR(60)  NOT NULL,
    Detalles     NVARCHAR(MAX) NOT NULL,
    CONSTRAINT CK_BK_Modulo CHECK (Modulo IN (
        'ASSETS',
        'WORK_ORDERS',
        'BREAKDOWNS',
        'PREVENTIVE',
        'PREVENTIVE_SCHEDULES',
        'AREAS',
        'OPERATION_REPORTS',
        'USERS',
        'EMPLOYEES',
        'POSITIONS'
    )),
    CONSTRAINT FK_BK_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuario(UsuarioId)
);
GO

CREATE NONCLUSTERED INDEX IX_BitacoraKardex_Modulo_Fecha
    ON dbo.BitacoraKardex (Modulo, RegistradoEn DESC)
    INCLUDE (Accion, EntidadId, NombreUsuario);
GO

CREATE OR ALTER TRIGGER dbo.TR_BitacoraKardex_SoloInsercion
ON dbo.BitacoraKardex
FOR UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    RAISERROR(N'La tabla BitacoraKardex es de solo inserción (Append-Only). No se permiten modificaciones ni eliminaciones.', 16, 1);
    ROLLBACK TRANSACTION;
END;
GO
