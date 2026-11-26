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

-- 5.7.1 Catálogo de Unidades de Medida
CREATE TABLE dbo.UnidadMedida (
    UnidadMedidaId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_UnidadMedida PRIMARY KEY,
    Codigo         NVARCHAR(20) NOT NULL CONSTRAINT UQ_UnidadMedida_Codigo UNIQUE,
    Nombre         NVARCHAR(100) NOT NULL,
    Activo         BIT NOT NULL CONSTRAINT DF_UnidadMedida_Activo DEFAULT (1),
    CreadoEn       DATETIME2(3) NOT NULL CONSTRAINT DF_UnidadMedida_CreadoEn DEFAULT (SYSUTCDATETIME()),
    ActualizadoEn  DATETIME2(3) NOT NULL CONSTRAINT DF_UnidadMedida_ActualizadoEn DEFAULT (SYSUTCDATETIME())
);
GO

CREATE NONCLUSTERED INDEX IX_UnidadMedida_Activo_Codigo
    ON dbo.UnidadMedida (Activo, Codigo);
GO

-- 5.7.2 Catálogo de Atributos Técnicos para Activos
CREATE TABLE dbo.AtributoCatalogo (
    AtributoId            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AtributoCatalogo PRIMARY KEY,
    Nombre                NVARCHAR(100) NOT NULL CONSTRAINT UQ_AtributoCatalogo_Nombre UNIQUE,
    Descripcion           NVARCHAR(255) NULL,
    UnidadMedidaIdDefecto INT NULL CONSTRAINT FK_AtributoCatalogo_UnidadMedida
                          REFERENCES dbo.UnidadMedida (UnidadMedidaId),
    Activo                BIT NOT NULL CONSTRAINT DF_AtributoCatalogo_Activo DEFAULT (1),
    CreadoEn              DATETIME2(3) NOT NULL CONSTRAINT DF_AtributoCatalogo_CreadoEn DEFAULT (SYSUTCDATETIME()),
    ActualizadoEn         DATETIME2(3) NOT NULL CONSTRAINT DF_AtributoCatalogo_ActualizadoEn DEFAULT (SYSUTCDATETIME())
);
GO

CREATE NONCLUSTERED INDEX IX_AtributoCatalogo_Activo_Nombre
    ON dbo.AtributoCatalogo (Activo, Nombre);
GO

-- 5.7.3 Catálogo de Marcas para Activos
CREATE TABLE dbo.Marca (
    MarcaId       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Marca PRIMARY KEY,
    Nombre        NVARCHAR(100) NOT NULL CONSTRAINT UQ_Marca_Nombre UNIQUE,
    Descripcion   NVARCHAR(250) NULL,
    Activo        BIT NOT NULL CONSTRAINT DF_Marca_Activo DEFAULT (1),
    CreadoEn      DATETIME2(3) NOT NULL CONSTRAINT DF_Marca_CreadoEn DEFAULT (SYSUTCDATETIME()),
    ActualizadoEn DATETIME2(3) NOT NULL CONSTRAINT DF_Marca_ActualizadoEn DEFAULT (SYSUTCDATETIME())
);
GO

CREATE NONCLUSTERED INDEX IX_Marca_Activo_Nombre
    ON dbo.Marca (Activo, Nombre);
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

-- 5.11 Tabla de Sesiones de Usuario (Control de Concurrencia - Máximo 2 Simultáneas)
CREATE TABLE dbo.SesionUsuario (
    SesionId          BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SesionUsuario PRIMARY KEY,
    UsuarioId         INT NOT NULL,
    TokenId           NVARCHAR(64) NOT NULL,
    IpOrigen          NVARCHAR(45) NULL,
    UserAgent         NVARCHAR(255) NULL,
    CreadoEn          DATETIME2(3) NOT NULL CONSTRAINT DF_SesionUsuario_CreadoEn DEFAULT (SYSUTCDATETIME()),
    UltimaActividad   DATETIME2(3) NOT NULL CONSTRAINT DF_SesionUsuario_UltimaActividad DEFAULT (SYSUTCDATETIME()),
    Activa            BIT NOT NULL CONSTRAINT DF_SesionUsuario_Activa DEFAULT (1),
    CONSTRAINT FK_SesionUsuario_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuario(UsuarioId) ON DELETE CASCADE
);
GO

CREATE NONCLUSTERED INDEX IX_SesionUsuario_Usuario_Activa
    ON dbo.SesionUsuario (UsuarioId, Activa, CreadoEn DESC);
GO

CREATE UNIQUE NONCLUSTERED INDEX UX_SesionUsuario_TokenId
    ON dbo.SesionUsuario (TokenId);
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
    Observaciones              NVARCHAR(MAX) NULL,
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

-- 5.11.1 Tablas de Plantillas de Activos
CREATE TABLE dbo.PlantillaActivo (
    PlantillaId    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PlantillaActivo PRIMARY KEY,
    Nombre         NVARCHAR(150) NOT NULL CONSTRAINT UQ_PlantillaActivo_Nombre UNIQUE,
    Descripcion    NVARCHAR(255) NULL,
    NivelRaiz      NVARCHAR(20)  NOT NULL CONSTRAINT DF_PlantillaActivo_NivelRaiz DEFAULT ('equipment'),
    TotalNodos     INT           NOT NULL CONSTRAINT DF_PlantillaActivo_TotalNodos DEFAULT (1),
    Activo         BIT           NOT NULL CONSTRAINT DF_PlantillaActivo_Activo DEFAULT (1),
    CreadoEn       DATETIME2(3)  NOT NULL CONSTRAINT DF_PlantillaActivo_CreadoEn DEFAULT (SYSUTCDATETIME()),
    ActualizadoEn  DATETIME2(3)  NOT NULL CONSTRAINT DF_PlantillaActivo_ActualizadoEn DEFAULT (SYSUTCDATETIME())
);
GO

CREATE NONCLUSTERED INDEX IX_PlantillaActivo_Activo_Nombre
    ON dbo.PlantillaActivo (Activo, Nombre);
GO

CREATE TABLE dbo.PlantillaActivoNodo (
    NodoId             INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PlantillaActivoNodo PRIMARY KEY,
    PlantillaId        INT NOT NULL CONSTRAINT FK_PlantillaNodo_Plantilla REFERENCES dbo.PlantillaActivo (PlantillaId) ON DELETE CASCADE,
    NodoPadreId        INT NULL CONSTRAINT FK_PlantillaNodo_Padre REFERENCES dbo.PlantillaActivoNodo (NodoId),
    Nombre             NVARCHAR(200) NOT NULL,
    Marca              NVARCHAR(100) NULL,
    Modelo             NVARCHAR(100) NULL,
    Nivel              NVARCHAR(20)  NOT NULL,
    Orden              INT           NOT NULL CONSTRAINT DF_PlantillaNodo_Orden DEFAULT (1),
    AtributosDinamicos NVARCHAR(MAX) NULL,
    Observaciones      NVARCHAR(MAX) NULL
);
GO

CREATE NONCLUSTERED INDEX IX_PlantillaNodo_Plantilla_Padre
    ON dbo.PlantillaActivoNodo (PlantillaId, NodoPadreId);
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


-- ----------------------------------------------------------------------------
-- 12. PROCEDIMIENTOS ALMACENADOS: AUTENTICACIÓN, USUARIOS Y RBAC
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspUsuarioObtenerParaLogin
    @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UsuarioId AS UserId, 
           u.NombreUsuario AS Username, 
           u.NombreCompleto AS DisplayName,
           u.CodigoRol AS RoleCode, 
           u.PasswordSalt, 
           u.PasswordHash,
           u.IteracionesPassword AS PasswordIterations, 
           u.Deshabilitado AS Disabled,
           u.DebeCambiarPassword AS MustChangePassword, 
           u.SolicitudReinicioPassword AS PasswordResetRequested,
           u.IntentosFallidos AS FailedLoginAttempts, 
           u.BloqueadoHasta AS LockedUntil,
           u.EmpleadoId AS EmployeeId,
           (SELECT STRING_AGG(CodigoPermiso, ',') FROM dbo.UsuarioPermiso WHERE UsuarioId = u.UsuarioId) AS PermissionsCsv
      FROM dbo.Usuario u
     WHERE u.NombreUsuario = @Username;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspLoginRegistrarFallo
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuario
       SET IntentosFallidos = IntentosFallidos + 1,
           BloqueadoHasta   = CASE WHEN IntentosFallidos + 1 >= 5 THEN DATEADD(MINUTE, 15, SYSUTCDATETIME()) ELSE BloqueadoHasta END,
           ActualizadoEn    = SYSUTCDATETIME()
     WHERE UsuarioId = @UserId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspLoginReiniciarIntentos
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuario
       SET IntentosFallidos = 0,
           BloqueadoHasta   = NULL,
           ActualizadoEn    = SYSUTCDATETIME()
     WHERE UsuarioId = @UserId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspLoginMigrarHash
    @UserId INT,
    @NewSalt NVARCHAR(64),
    @NewHash NVARCHAR(128),
    @Iterations INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuario
       SET PasswordSalt        = @NewSalt,
           PasswordHash        = @NewHash,
           IteracionesPassword = @Iterations,
           ActualizadoEn       = SYSUTCDATETIME()
     WHERE UsuarioId = @UserId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSesionRegistrar
    @UsuarioId INT,
    @TokenId   NVARCHAR(64),
    @IpOrigen  NVARCHAR(45) = NULL,
    @UserAgent NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Insertar nueva sesión como activa
        INSERT INTO dbo.SesionUsuario (UsuarioId, TokenId, IpOrigen, UserAgent, CreadoEn, UltimaActividad, Activa)
        VALUES (@UsuarioId, @TokenId, @IpOrigen, @UserAgent, SYSUTCDATETIME(), SYSUTCDATETIME(), 1);

        -- Desplazar sesiones anteriores que superen el límite de 2 activas (FIFO)
        ;WITH SesionesOrdenadas AS (
            SELECT SesionId,
                   ROW_NUMBER() OVER (ORDER BY CreadoEn DESC, SesionId DESC) AS Fila
              FROM dbo.SesionUsuario
             WHERE UsuarioId = @UsuarioId
               AND Activa = 1
        )
        UPDATE s
           SET Activa = 0
          FROM dbo.SesionUsuario s
          JOIN SesionesOrdenadas o ON s.SesionId = o.SesionId
         WHERE o.Fila > 2;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSesionVerificar
    @UsuarioId INT,
    @TokenId   NVARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Activa BIT = 0;

    SELECT TOP (1) @Activa = Activa
      FROM dbo.SesionUsuario
     WHERE UsuarioId = @UsuarioId
       AND TokenId = @TokenId;

    IF @Activa = 1
    BEGIN
        UPDATE dbo.SesionUsuario
           SET UltimaActividad = SYSUTCDATETIME()
         WHERE UsuarioId = @UsuarioId
           AND TokenId = @TokenId;
    END;

    SELECT ISNULL(@Activa, 0) AS Activa;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSesionCerrar
    @UsuarioId INT,
    @TokenId   NVARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.SesionUsuario
       SET Activa = 0,
           UltimaActividad = SYSUTCDATETIME()
     WHERE UsuarioId = @UsuarioId
       AND TokenId = @TokenId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspUsuarioCrear
    @Username NVARCHAR(50), 
    @DisplayName NVARCHAR(100), 
    @RoleCode NVARCHAR(20),
    @PasswordSalt NVARCHAR(64), 
    @PasswordHash NVARCHAR(128), 
    @PasswordIterations INT = 20000,
    @MustChangePassword BIT = 1,
    @HasCustomPermissions BIT = 0,
    @Permissions dbo.TipoListaTexto READONLY,
    @EmployeeId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF EXISTS (SELECT 1 FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@Username))))
        BEGIN
            RAISERROR(N'El nombre de usuario ya está en uso.', 16, 1);
        END;

        IF @EmployeeId IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.Usuario WHERE EmpleadoId = @EmployeeId)
        BEGIN
            RAISERROR(N'El empleado seleccionado ya cuenta con un usuario asignado en el sistema.', 16, 1);
        END;

        INSERT INTO dbo.Usuario
            (NombreUsuario, NombreCompleto, CodigoRol, PasswordSalt, PasswordHash,
             IteracionesPassword, DebeCambiarPassword, SolicitudReinicioPassword, SolicitadoEn,
             IntentosFallidos, BloqueadoHasta, EmpleadoId, CreadoEn, ActualizadoEn)
        VALUES
            (LTRIM(RTRIM(@Username)), LTRIM(RTRIM(@DisplayName)), @RoleCode, @PasswordSalt, @PasswordHash,
             @PasswordIterations, @MustChangePassword, 0, NULL,
             0, NULL, @EmployeeId, SYSUTCDATETIME(), SYSUTCDATETIME());

        DECLARE @uid INT = SCOPE_IDENTITY();

        IF @HasCustomPermissions = 1 AND EXISTS (SELECT 1 FROM @Permissions)
        BEGIN
            INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
            SELECT DISTINCT @uid, Valor FROM @Permissions WHERE Valor IS NOT NULL AND LTRIM(RTRIM(Valor)) <> '';
        END
        ELSE
        BEGIN
            INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
            SELECT @uid, CodigoPermiso FROM dbo.RolPermiso WHERE CodigoRol = @RoleCode;
        END

        COMMIT TRANSACTION;
        
        SELECT u.UsuarioId AS UserId, 
               u.NombreUsuario AS Username, 
               u.NombreCompleto AS DisplayName,
               u.CodigoRol AS RoleCode, 
               u.Deshabilitado AS Disabled, 
               u.DebeCambiarPassword AS MustChangePassword,
               u.SolicitudReinicioPassword AS PasswordResetRequested, 
               u.SolicitadoEn AS PasswordResetRequestedAt,
               u.CreadoEn AS CreatedAt,
               u.EmpleadoId AS EmployeeId,
               e.Puesto AS EmployeePosition,
               e.AreaId AS EmployeeAreaId,
               e.NombreArea AS EmployeeAreaName,
               (SELECT STRING_AGG(CodigoPermiso, ',') FROM dbo.UsuarioPermiso WHERE UsuarioId = u.UsuarioId) AS PermissionsCsv
          FROM dbo.Usuario u
          LEFT JOIN dbo.Empleado e ON u.EmpleadoId = e.EmpleadoId
         WHERE u.UsuarioId = @uid;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspUsuarioActualizar
    @UserId INT, 
    @DisplayName NVARCHAR(100) = NULL, 
    @NewRoleCode NVARCHAR(20) = NULL,
    @NewSalt NVARCHAR(64) = NULL, 
    @NewHash NVARCHAR(128) = NULL, 
    @NewIterations INT = NULL,
    @MustChangePassword BIT = NULL,
    @HasCustomPermissions BIT = 0,
    @Permissions dbo.TipoListaTexto READONLY,
    @EmployeeId INT = NULL,
    @Username NVARCHAR(50) = NULL
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

        DECLARE @NuevoUsuario NVARCHAR(50) = UPPER(LTRIM(RTRIM(ISNULL(@Username, N''))));
        IF NULLIF(@NuevoUsuario, N'') IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Usuario WHERE UPPER(NombreUsuario) = @NuevoUsuario AND UsuarioId <> @UserId)
            BEGIN
                RAISERROR(N'Ya existe otro usuario con ese nombre de usuario.', 16, 1);
            END;
        END;

        IF @EmployeeId IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.Usuario WHERE EmpleadoId = @EmployeeId AND UsuarioId <> @UserId)
        BEGIN
            RAISERROR(N'El empleado seleccionado ya está vinculado a otro usuario.', 16, 1);
        END;

        IF @NewSalt IS NOT NULL
        BEGIN
            UPDATE dbo.Usuario
               SET NombreUsuario       = COALESCE(NULLIF(@NuevoUsuario, N''), NombreUsuario),
                   NombreCompleto      = COALESCE(NULLIF(LTRIM(RTRIM(@DisplayName)), ''), NombreCompleto),
                   CodigoRol           = COALESCE(@NewRoleCode, CodigoRol),
                   PasswordSalt        = @NewSalt,
                   PasswordHash        = @NewHash,
                   IteracionesPassword = COALESCE(@NewIterations, IteracionesPassword, 20000),
                   DebeCambiarPassword = 1,
                   SolicitudReinicioPassword = 0,
                   SolicitadoEn        = NULL,
                   IntentosFallidos    = 0,
                   BloqueadoHasta      = NULL,
                   EmpleadoId          = COALESCE(@EmployeeId, EmpleadoId),
                   ActualizadoEn       = SYSUTCDATETIME()
             WHERE UsuarioId = @UserId;

            UPDATE dbo.SolicitudReinicioPassword
               SET Estado = 'resolved'
             WHERE UsuarioId = @UserId AND Estado = 'pending';
        END
        ELSE
        BEGIN
            UPDATE dbo.Usuario
               SET NombreUsuario       = COALESCE(NULLIF(@NuevoUsuario, N''), NombreUsuario),
                   NombreCompleto      = COALESCE(NULLIF(LTRIM(RTRIM(@DisplayName)), ''), NombreCompleto),
                   CodigoRol           = COALESCE(@NewRoleCode, CodigoRol),
                   DebeCambiarPassword = COALESCE(@MustChangePassword, DebeCambiarPassword),
                   EmpleadoId          = COALESCE(@EmployeeId, EmpleadoId),
                   ActualizadoEn       = SYSUTCDATETIME()
             WHERE UsuarioId = @UserId;
        END

        IF @HasCustomPermissions = 1 AND EXISTS (SELECT 1 FROM @Permissions)
        BEGIN
            DELETE FROM dbo.UsuarioPermiso WHERE UsuarioId = @UserId;
            INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
            SELECT DISTINCT @UserId, Valor FROM @Permissions WHERE Valor IS NOT NULL AND LTRIM(RTRIM(Valor)) <> '';
        END
        ELSE IF @NewRoleCode IS NOT NULL
        BEGIN
            DELETE FROM dbo.UsuarioPermiso WHERE UsuarioId = @UserId;
            INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
            SELECT @UserId, CodigoPermiso FROM dbo.RolPermiso WHERE CodigoRol = @NewRoleCode;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspUsuarioAlternarDeshabilitado
    @UserId INT,
    @Disabled BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuario
       SET Deshabilitado = @Disabled,
           ActualizadoEn = SYSUTCDATETIME()
     WHERE UsuarioId = @UserId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspUsuarioCambiarPassword
    @UserId INT,
    @PasswordSalt NVARCHAR(64),
    @PasswordHash NVARCHAR(128),
    @PasswordIterations INT = NULL,
    @Iterations INT = NULL,
    @MustChangePassword BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IteracionesFinales INT = COALESCE(@PasswordIterations, @Iterations, 20000);
    UPDATE dbo.Usuario
       SET PasswordSalt        = @PasswordSalt,
           PasswordHash        = @PasswordHash,
           IteracionesPassword = @IteracionesFinales,
           DebeCambiarPassword = @MustChangePassword,
           ActualizadoEn       = SYSUTCDATETIME()
     WHERE UsuarioId = @UserId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspUsuarioReiniciarTemporal
    @UserId INT,
    @PasswordSalt NVARCHAR(64),
    @PasswordHash NVARCHAR(128),
    @PasswordIterations INT = NULL,
    @Iterations INT = NULL,
    @UpdatedByUserId INT = NULL,
    @UpdatedByUserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @IteracionesFinales INT = COALESCE(@PasswordIterations, @Iterations, 20000);
        UPDATE dbo.Usuario
           SET PasswordSalt        = @PasswordSalt,
               PasswordHash        = @PasswordHash,
               IteracionesPassword = @IteracionesFinales,
               DebeCambiarPassword = 1,
               SolicitudReinicioPassword = 0,
               SolicitadoEn        = NULL,
               ActualizadoEn       = SYSUTCDATETIME()
         WHERE UsuarioId = @UserId;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UpdatedByUserId, @UpdatedByUserName, 'PASSWORD_RESET', 'USERS', CAST(@UserId AS NVARCHAR(20)),
                CONCAT(N'Contraseña temporal generada para el usuario ID ', @UserId, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudReinicioPasswordCrear
    @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @uid INT, @fn NVARCHAR(150), @rc NVARCHAR(20);
        SELECT @uid = UsuarioId, @fn = NombreCompleto, @rc = CodigoRol
          FROM dbo.Usuario WHERE NombreUsuario = @Username;

        IF @uid IS NULL
            RAISERROR(N'El usuario no existe.', 16, 1);

        INSERT INTO dbo.SolicitudReinicioPassword (UsuarioId, NombreUsuario, NombreCompleto, CodigoRol, Estado, SolicitadoEn)
        VALUES (@uid, @Username, @fn, @rc, 'pending', SYSUTCDATETIME());

        UPDATE dbo.Usuario
           SET SolicitudReinicioPassword = 1,
               SolicitadoEn = SYSUTCDATETIME()
         WHERE UsuarioId = @uid;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudReinicioPasswordListarPendientes
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SolicitudId, UsuarioId, NombreUsuario, NombreCompleto, CodigoRol, Estado, SolicitadoEn, Detalles
      FROM dbo.SolicitudReinicioPassword
     WHERE Estado = 'pending'
     ORDER BY SolicitadoEn DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudReinicioPasswordMarcarResuelta
    @RequestId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.SolicitudReinicioPassword
       SET Estado = 'resolved'
     WHERE SolicitudId = @RequestId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspUsuarioObtenerTodos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UsuarioId AS UserId, 
           u.NombreUsuario AS Username, 
           u.NombreCompleto AS DisplayName,
           u.CodigoRol AS RoleCode, 
           u.Deshabilitado AS Disabled, 
           u.DebeCambiarPassword AS MustChangePassword,
           u.SolicitudReinicioPassword AS PasswordResetRequested, 
           u.SolicitadoEn AS PasswordResetRequestedAt,
           u.CreadoEn AS CreatedAt,
           u.EmpleadoId AS EmployeeId,
           e.Puesto AS EmployeePosition,
           e.AreaId AS EmployeeAreaId,
           e.NombreArea AS EmployeeAreaName,
           (SELECT STRING_AGG(CodigoPermiso, ',') FROM dbo.UsuarioPermiso WHERE UsuarioId = u.UsuarioId) AS PermissionsCsv
      FROM dbo.Usuario u
      LEFT JOIN dbo.Empleado e ON u.EmpleadoId = e.EmpleadoId
     ORDER BY u.NombreUsuario;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspUsuarioObtenerPorId
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UsuarioId AS UserId, 
           u.NombreUsuario AS Username, 
           u.NombreCompleto AS DisplayName,
           u.CodigoRol AS RoleCode, 
           u.PasswordSalt, 
           u.PasswordHash,
           u.IteracionesPassword AS PasswordIterations, 
           u.Deshabilitado AS Disabled,
           u.DebeCambiarPassword AS MustChangePassword, 
           u.SolicitudReinicioPassword AS PasswordResetRequested,
           u.SolicitadoEn AS PasswordResetRequestedAt, 
           u.IntentosFallidos AS FailedLoginAttempts,
           u.BloqueadoHasta AS LockedUntil, 
           u.CreadoEn AS CreatedAt,
           u.EmpleadoId AS EmployeeId,
           e.Puesto AS EmployeePosition,
           e.AreaId AS EmployeeAreaId,
           e.NombreArea AS EmployeeAreaName,
           (SELECT STRING_AGG(CodigoPermiso, ',') FROM dbo.UsuarioPermiso WHERE UsuarioId = u.UsuarioId) AS PermissionsCsv
      FROM dbo.Usuario u
      LEFT JOIN dbo.Empleado e ON u.EmpleadoId = e.EmpleadoId
     WHERE u.UsuarioId = @UserId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspCatalogosObtener
AS
BEGIN
    SET NOCOUNT ON;
    -- 1. Roles
    SELECT CodigoRol, Nombre
      FROM dbo.Rol
     ORDER BY CASE CodigoRol 
                WHEN 'admin' THEN 1 
                WHEN 'jefe' THEN 2 
                WHEN 'jefe_area' THEN 3 
                WHEN 'reportador' THEN 4 
                WHEN 'lector' THEN 5 
                ELSE 6 END;

    -- 2. Permisos
    SELECT CodigoPermiso
      FROM dbo.Permiso
     ORDER BY CodigoPermiso ASC;

    -- 3. Matriz Rol-Permiso
    SELECT CodigoRol, CodigoPermiso
      FROM dbo.RolPermiso
     ORDER BY CodigoRol, CodigoPermiso;

    -- 4. Puestos Activos
    SELECT PuestoId, Nombre, EsMantenimiento
      FROM dbo.Puesto
     WHERE Activo = 1
     ORDER BY Nombre ASC;

    -- 5. Unidades de Medida Activas
    SELECT UnidadMedidaId AS id, Codigo AS code, Nombre AS name
      FROM dbo.UnidadMedida
     WHERE Activo = 1
     ORDER BY Codigo ASC;

    -- 6. Atributos de Catálogo Activos
    SELECT a.AtributoId AS id, a.Nombre AS name, a.Descripcion AS description,
           a.UnidadMedidaIdDefecto AS defaultUnitId, u.Codigo AS defaultUnitCode
      FROM dbo.AtributoCatalogo a
      LEFT JOIN dbo.UnidadMedida u ON a.UnidadMedidaIdDefecto = u.UnidadMedidaId
     WHERE a.Activo = 1
     ORDER BY a.Nombre ASC;

    -- 7. Marcas Activas
    SELECT MarcaId AS id, Nombre AS name, Descripcion AS description
      FROM dbo.Marca
     WHERE Activo = 1
     ORDER BY Nombre ASC;
END;
GO

-- ----------------------------------------------------------------------------
-- 12.1 PROCEDIMIENTOS ALMACENADOS: UNIDADES DE MEDIDA Y ATRIBUTOS DE CATÁLOGO
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspUnidadMedidaListar
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        UnidadMedidaId AS id,
        UnidadMedidaId,
        Codigo AS code,
        Codigo,
        Nombre AS name,
        Nombre,
        Activo AS isActive,
        Activo,
        CreadoEn AS createdAt,
        ActualizadoEn AS updatedAt
    FROM dbo.UnidadMedida
    WHERE (@IncludeInactive = 1 OR Activo = 1)
    ORDER BY Codigo ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspUnidadMedidaCrear
    @Codigo NVARCHAR(20),
    @Nombre NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @CleanCode NVARCHAR(20) = LTRIM(RTRIM(@Codigo));
        DECLARE @CleanName NVARCHAR(100) = LTRIM(RTRIM(@Nombre));

        IF @CleanCode IS NULL OR @CleanCode = N''
            RAISERROR(N'El código o símbolo de la unidad de medida es obligatorio.', 16, 1);
        IF @CleanName IS NULL OR @CleanName = N''
            RAISERROR(N'El nombre de la unidad de medida es obligatorio.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.UnidadMedida WHERE UPPER(Codigo) = UPPER(@CleanCode))
        BEGIN
            UPDATE dbo.UnidadMedida
               SET Nombre = @CleanName,
                   Activo = 1,
                   ActualizadoEn = SYSUTCDATETIME()
             WHERE UPPER(Codigo) = UPPER(@CleanCode);

            SELECT UnidadMedidaId AS id, UnidadMedidaId, Codigo AS code, Codigo, Nombre AS name, Nombre, Activo AS isActive
              FROM dbo.UnidadMedida
             WHERE UPPER(Codigo) = UPPER(@CleanCode);
            RETURN;
        END;

        INSERT INTO dbo.UnidadMedida (Codigo, Nombre, Activo, CreadoEn, ActualizadoEn)
        VALUES (@CleanCode, @CleanName, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

        DECLARE @NewId INT = SCOPE_IDENTITY();
        SELECT UnidadMedidaId AS id, UnidadMedidaId, Codigo AS code, Codigo, Nombre AS name, Nombre, Activo AS isActive
          FROM dbo.UnidadMedida
         WHERE UnidadMedidaId = @NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspUnidadMedidaActualizar
    @UnidadMedidaId INT,
    @Codigo NVARCHAR(20),
    @Nombre NVARCHAR(100),
    @Activo BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @CleanCode NVARCHAR(20) = LTRIM(RTRIM(@Codigo));
        DECLARE @CleanName NVARCHAR(100) = LTRIM(RTRIM(@Nombre));

        IF NOT EXISTS (SELECT 1 FROM dbo.UnidadMedida WHERE UnidadMedidaId = @UnidadMedidaId)
            RAISERROR(N'La unidad de medida especificada no existe.', 16, 1);

        IF @CleanCode IS NULL OR @CleanCode = N''
            RAISERROR(N'El código o símbolo de la unidad de medida es obligatorio.', 16, 1);
        IF @CleanName IS NULL OR @CleanName = N''
            RAISERROR(N'El nombre de la unidad de medida es obligatorio.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.UnidadMedida WHERE UPPER(Codigo) = UPPER(@CleanCode) AND UnidadMedidaId <> @UnidadMedidaId)
            RAISERROR(N'Ya existe otra unidad de medida con el código especificado.', 16, 1);

        UPDATE dbo.UnidadMedida
           SET Codigo = @CleanCode,
               Nombre = @CleanName,
               Activo = COALESCE(@Activo, Activo),
               ActualizadoEn = SYSUTCDATETIME()
         WHERE UnidadMedidaId = @UnidadMedidaId;

        SELECT UnidadMedidaId AS id, UnidadMedidaId, Codigo AS code, Codigo, Nombre AS name, Nombre, Activo AS isActive
          FROM dbo.UnidadMedida
         WHERE UnidadMedidaId = @UnidadMedidaId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspUnidadMedidaEliminar
    @UnidadMedidaId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.UnidadMedida WHERE UnidadMedidaId = @UnidadMedidaId)
            RAISERROR(N'La unidad de medida no existe.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.AtributoCatalogo WHERE UnidadMedidaIdDefecto = @UnidadMedidaId AND Activo = 1)
        BEGIN
            UPDATE dbo.UnidadMedida
               SET Activo = 0,
                   ActualizadoEn = SYSUTCDATETIME()
             WHERE UnidadMedidaId = @UnidadMedidaId;

            SELECT 1 AS success, N'La unidad de medida fue desactivada porque está vinculada a atributos del catálogo.' AS message;
            RETURN;
        END;

        UPDATE dbo.UnidadMedida
           SET Activo = 0,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE UnidadMedidaId = @UnidadMedidaId;

        SELECT 1 AS success, N'Unidad de medida eliminada exitosamente.' AS message;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspAtributoCatalogoListar
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        a.AtributoId AS id,
        a.AtributoId,
        a.Nombre AS name,
        a.Nombre,
        a.Descripcion AS description,
        a.Descripcion,
        a.UnidadMedidaIdDefecto AS defaultUnitId,
        a.UnidadMedidaIdDefecto,
        u.Codigo AS defaultUnitCode,
        u.Nombre AS defaultUnitName,
        a.Activo AS isActive,
        a.Activo,
        a.CreadoEn AS createdAt,
        a.ActualizadoEn AS updatedAt
    FROM dbo.AtributoCatalogo a
    LEFT JOIN dbo.UnidadMedida u ON a.UnidadMedidaIdDefecto = u.UnidadMedidaId
    WHERE (@IncludeInactive = 1 OR a.Activo = 1)
    ORDER BY a.Nombre ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspAtributoCatalogoCrear
    @Nombre NVARCHAR(100),
    @Descripcion NVARCHAR(255) = NULL,
    @UnidadMedidaIdDefecto INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @CleanName NVARCHAR(100) = LTRIM(RTRIM(@Nombre));
        DECLARE @CleanDesc NVARCHAR(255) = NULLIF(LTRIM(RTRIM(@Descripcion)), N'');

        IF @CleanName IS NULL OR @CleanName = N''
            RAISERROR(N'El nombre del atributo es obligatorio.', 16, 1);

        IF @UnidadMedidaIdDefecto IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.UnidadMedida WHERE UnidadMedidaId = @UnidadMedidaIdDefecto)
            SET @UnidadMedidaIdDefecto = NULL;

        IF EXISTS (SELECT 1 FROM dbo.AtributoCatalogo WHERE UPPER(Nombre) = UPPER(@CleanName))
        BEGIN
            UPDATE dbo.AtributoCatalogo
               SET Descripcion = @CleanDesc,
                   UnidadMedidaIdDefecto = @UnidadMedidaIdDefecto,
                   Activo = 1,
                   ActualizadoEn = SYSUTCDATETIME()
             WHERE UPPER(Nombre) = UPPER(@CleanName);

            SELECT a.AtributoId AS id, a.AtributoId, a.Nombre AS name, a.Nombre, a.Descripcion AS description,
                   a.UnidadMedidaIdDefecto AS defaultUnitId, u.Codigo AS defaultUnitCode, a.Activo AS isActive
              FROM dbo.AtributoCatalogo a
              LEFT JOIN dbo.UnidadMedida u ON a.UnidadMedidaIdDefecto = u.UnidadMedidaId
             WHERE UPPER(a.Nombre) = UPPER(@CleanName);
            RETURN;
        END;

        INSERT INTO dbo.AtributoCatalogo (Nombre, Descripcion, UnidadMedidaIdDefecto, Activo, CreadoEn, ActualizadoEn)
        VALUES (@CleanName, @CleanDesc, @UnidadMedidaIdDefecto, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

        DECLARE @NewId INT = SCOPE_IDENTITY();
        SELECT a.AtributoId AS id, a.AtributoId, a.Nombre AS name, a.Nombre, a.Descripcion AS description,
               a.UnidadMedidaIdDefecto AS defaultUnitId, u.Codigo AS defaultUnitCode, a.Activo AS isActive
          FROM dbo.AtributoCatalogo a
          LEFT JOIN dbo.UnidadMedida u ON a.UnidadMedidaIdDefecto = u.UnidadMedidaId
         WHERE a.AtributoId = @NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspAtributoCatalogoActualizar
    @AtributoId INT,
    @Nombre NVARCHAR(100),
    @Descripcion NVARCHAR(255) = NULL,
    @UnidadMedidaIdDefecto INT = NULL,
    @Activo BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @CleanName NVARCHAR(100) = LTRIM(RTRIM(@Nombre));
        DECLARE @CleanDesc NVARCHAR(255) = NULLIF(LTRIM(RTRIM(@Descripcion)), N'');

        IF NOT EXISTS (SELECT 1 FROM dbo.AtributoCatalogo WHERE AtributoId = @AtributoId)
            RAISERROR(N'El atributo especificado no existe.', 16, 1);

        IF @CleanName IS NULL OR @CleanName = N''
            RAISERROR(N'El nombre del atributo es obligatorio.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.AtributoCatalogo WHERE UPPER(Nombre) = UPPER(@CleanName) AND AtributoId <> @AtributoId)
            RAISERROR(N'Ya existe otro atributo con el nombre especificado.', 16, 1);

        IF @UnidadMedidaIdDefecto IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.UnidadMedida WHERE UnidadMedidaId = @UnidadMedidaIdDefecto)
            SET @UnidadMedidaIdDefecto = NULL;

        UPDATE dbo.AtributoCatalogo
           SET Nombre = @CleanName,
               Descripcion = @CleanDesc,
               UnidadMedidaIdDefecto = @UnidadMedidaIdDefecto,
               Activo = COALESCE(@Activo, Activo),
               ActualizadoEn = SYSUTCDATETIME()
         WHERE AtributoId = @AtributoId;

        SELECT a.AtributoId AS id, a.AtributoId, a.Nombre AS name, a.Nombre, a.Descripcion AS description,
               a.UnidadMedidaIdDefecto AS defaultUnitId, u.Codigo AS defaultUnitCode, a.Activo AS isActive
          FROM dbo.AtributoCatalogo a
          LEFT JOIN dbo.UnidadMedida u ON a.UnidadMedidaIdDefecto = u.UnidadMedidaId
         WHERE a.AtributoId = @AtributoId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspAtributoCatalogoEliminar
    @AtributoId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.AtributoCatalogo WHERE AtributoId = @AtributoId)
            RAISERROR(N'El atributo no existe.', 16, 1);

        UPDATE dbo.AtributoCatalogo
           SET Activo = 0,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE AtributoId = @AtributoId;

        SELECT 1 AS success, N'Atributo retirado del catálogo exitosamente.' AS message;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 12.3 PROCEDIMIENTOS ALMACENADOS: CATÁLOGO DE MARCAS
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspMarcaListar
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT MarcaId AS id,
           MarcaId,
           Nombre AS name,
           Nombre,
           Descripcion AS description,
           Descripcion,
           Activo AS isActive,
           Activo,
           CreadoEn,
           ActualizadoEn,
           (SELECT COUNT(*) FROM dbo.Activo WHERE UPPER(LTRIM(RTRIM(Marca))) = UPPER(LTRIM(RTRIM(m.Nombre))) AND Estado <> 'deleted') AS TotalActivosAsociados
      FROM dbo.Marca m
     WHERE (@IncludeInactive = 1 OR Activo = 1)
     ORDER BY Nombre ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspMarcaCrear
    @Nombre      NVARCHAR(100),
    @Descripcion NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @CleanName NVARCHAR(100) = LTRIM(RTRIM(@Nombre));
        IF @CleanName IS NULL OR @CleanName = ''
            RAISERROR(N'El nombre de la marca es obligatorio.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Marca WHERE UPPER(Nombre) = UPPER(@CleanName))
            RAISERROR(N'Ya existe una marca con ese nombre.', 16, 1);

        INSERT INTO dbo.Marca (Nombre, Descripcion, Activo, CreadoEn, ActualizadoEn)
        VALUES (@CleanName, NULLIF(LTRIM(RTRIM(@Descripcion)), ''), 1, SYSUTCDATETIME(), SYSUTCDATETIME());

        DECLARE @NewId INT = SCOPE_IDENTITY();
        SELECT MarcaId AS id, MarcaId, Nombre AS name, Nombre, Descripcion AS description, Descripcion, Activo AS isActive, Activo
          FROM dbo.Marca
         WHERE MarcaId = @NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspMarcaActualizar
    @MarcaId     INT,
    @Nombre      NVARCHAR(100),
    @Descripcion NVARCHAR(250) = NULL,
    @Activo      BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @CleanName NVARCHAR(100) = LTRIM(RTRIM(@Nombre));
        IF @CleanName IS NULL OR @CleanName = ''
            RAISERROR(N'El nombre de la marca es obligatorio.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM dbo.Marca WHERE MarcaId = @MarcaId)
            RAISERROR(N'La marca no existe.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Marca WHERE UPPER(Nombre) = UPPER(@CleanName) AND MarcaId <> @MarcaId)
            RAISERROR(N'Ya existe otra marca con ese nombre.', 16, 1);

        DECLARE @OldName NVARCHAR(100);
        SELECT @OldName = Nombre FROM dbo.Marca WHERE MarcaId = @MarcaId;

        UPDATE dbo.Marca
           SET Nombre        = @CleanName,
               Descripcion   = NULLIF(LTRIM(RTRIM(@Descripcion)), ''),
               Activo        = @Activo,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE MarcaId = @MarcaId;

        IF @OldName <> @CleanName
        BEGIN
            UPDATE dbo.Activo
               SET Marca = @CleanName
             WHERE UPPER(LTRIM(RTRIM(Marca))) = UPPER(LTRIM(RTRIM(@OldName)));
        END;

        SELECT MarcaId AS id, MarcaId, Nombre AS name, Nombre, Descripcion AS description, Descripcion, Activo AS isActive, Activo
          FROM dbo.Marca
         WHERE MarcaId = @MarcaId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspMarcaEliminar
    @MarcaId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @BrandName NVARCHAR(100);
        SELECT @BrandName = Nombre FROM dbo.Marca WHERE MarcaId = @MarcaId;

        IF @BrandName IS NULL
            RAISERROR(N'La marca especificada no existe.', 16, 1);

        DECLARE @ActivosEnUso INT = 0;
        SELECT @ActivosEnUso = COUNT(*)
          FROM dbo.Activo
         WHERE UPPER(LTRIM(RTRIM(Marca))) = UPPER(LTRIM(RTRIM(@BrandName)))
           AND Estado <> 'deleted';

        IF @ActivosEnUso > 0
        BEGIN
            UPDATE dbo.Marca
               SET Activo = 0,
                   ActualizadoEn = SYSUTCDATETIME()
             WHERE MarcaId = @MarcaId;

            SELECT 1 AS success, 1 AS inactivatedOnly, @ActivosEnUso AS assetsCount,
                   CONCAT(N'La marca está en uso por ', @ActivosEnUso, N' activo(s). Se ha desactivado del catálogo para preservar la integridad.') AS message;
            RETURN;
        END;

        DELETE FROM dbo.Marca WHERE MarcaId = @MarcaId;

        SELECT 1 AS success, 0 AS inactivatedOnly, 0 AS assetsCount, N'Marca eliminada correctamente.' AS message;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


-- ----------------------------------------------------------------------------
-- 13. PROCEDIMIENTOS ALMACENADOS: ÁREAS, PUESTOS Y EMPLEADOS
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspAreaObtenerTodas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        AreaId,
        Nombre AS Name,
        CentroCosto AS CostCenter,
        ContadorActivos AS AssetCounter,
        Nombre,
        CentroCosto,
        ContadorActivos,
        Activo,
        CreadoEn,
        ActualizadoEn
      FROM dbo.Area
     WHERE Activo = 1
     ORDER BY AreaId ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspAreaCrear
    @Name NVARCHAR(100),
    @CostCenter NVARCHAR(50),
    @AreaId NVARCHAR(15) = NULL,
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N'',
    @UsuarioId INT = NULL,
    @NombreUsuario NVARCHAR(100) = N''
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
            SET @FinalId = CONCAT('A', FORMAT(@nextVal, '000'));
        END;

        IF EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @FinalId)
            RAISERROR(N'Ya existe un área con ese identificador.', 16, 1);

        INSERT INTO dbo.Area (AreaId, Nombre, CentroCosto, ContadorActivos, Activo, CreadoEn)
        VALUES (@FinalId, @Name, @NormCC, 0, 1, SYSUTCDATETIME());

        DECLARE @UID INT = COALESCE(@UserId, @UsuarioId);
        IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID)
        BEGIN
            SELECT @UID = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N''))));
            IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID) SET @UID = NULL;
        END;
    IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID)
    BEGIN
        SELECT @UID = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N''))));
        IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID) SET @UID = NULL;
    END;
        IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID)
        BEGIN
            SELECT @UID = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N''))));
            IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID) SET @UID = NULL;
        END;
        DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N'');
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UID, @UName, 'AREA_CREATED', 'AREAS', @FinalId,
                CONCAT(N'Área creada: ', @FinalId, N' - ', @Name, N' (', @NormCC, N').'));

        COMMIT TRANSACTION;
        SELECT @FinalId AS AreaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspAreaActualizar
    @AreaId NVARCHAR(15),
    @Name NVARCHAR(100),
    @CostCenter NVARCHAR(50) = NULL,
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N'',
    @UsuarioId INT = NULL,
    @NombreUsuario NVARCHAR(100) = N''
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
        RAISERROR(N'El área especificada no existe.', 16, 1);

    DECLARE @UID INT = COALESCE(@UserId, @UsuarioId);
    DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N'');
    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
    VALUES (@UID, @UName, 'AREA_UPDATED', 'AREAS', @AreaId,
            CONCAT(N'Área actualizada: ', @AreaId, N' - ', @Name, N'.'));
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspAreaEliminar
    @AreaId        NVARCHAR(15),
    @UserId        INT = NULL,
    @UserName      NVARCHAR(100) = N'',
    @UsuarioId     INT = NULL,
    @NombreUsuario NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @AreaId)
            RAISERROR(N'El área especificada no existe.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Activo WHERE AreaId = @AreaId AND Estado <> 'deleted')
            RAISERROR(N'No se puede eliminar el área porque contiene activos no eliminados.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Empleado WHERE AreaId = @AreaId AND Activo = 1)
            RAISERROR(N'No se puede eliminar el área porque tiene empleados activos asignados.', 16, 1);

        UPDATE dbo.Area
           SET Activo = 0,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE AreaId = @AreaId;

        DECLARE @UID INT = COALESCE(@UserId, @UsuarioId);
        DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N'');
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UID, @UName, 'AREA_DELETED', 'AREAS', @AreaId,
                CONCAT(N'Área dada de baja lógica: ', @AreaId, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPuestoListar
    @SoloActivos BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PuestoId, Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn
      FROM dbo.Puesto
     WHERE (@SoloActivos = 0 OR Activo = 1)
     ORDER BY Nombre ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPuestoCrear
    @Nombre          NVARCHAR(100),
    @EsMantenimiento BIT = 1,
    @UsuarioId       INT = NULL,
    @NombreUsuario   NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NombreLimpio NVARCHAR(100) = LTRIM(RTRIM(@Nombre));
        IF NULLIF(@NombreLimpio, N'') IS NULL
            RAISERROR(N'El nombre del puesto o cargo es obligatorio.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = @NombreLimpio AND Activo = 1)
            RAISERROR(N'Ya existe un puesto registrado con ese mismo nombre.', 16, 1);

        DECLARE @ExistenteInactivoId INT;
        SELECT @ExistenteInactivoId = PuestoId FROM dbo.Puesto WHERE Nombre = @NombreLimpio AND Activo = 0;

        DECLARE @NuevoId INT;
        IF @ExistenteInactivoId IS NOT NULL
        BEGIN
            UPDATE dbo.Puesto
               SET Activo = 1,
                   EsMantenimiento = @EsMantenimiento,
                   ActualizadoEn = SYSUTCDATETIME()
             WHERE PuestoId = @ExistenteInactivoId;
            SET @NuevoId = @ExistenteInactivoId;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
            VALUES (@NombreLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
            SET @NuevoId = SCOPE_IDENTITY();
        END;

        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId) SET @UsuarioId = NULL;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'POSITION_CREATED', 'POSITIONS', CAST(@NuevoId AS NVARCHAR(20)),
                CONCAT(N'Puesto registrado: ', @NombreLimpio, N' (Mantenimiento: ', CASE WHEN @EsMantenimiento = 1 THEN N'Sí' ELSE N'No' END, N').'));

        COMMIT TRANSACTION;

        SELECT PuestoId, Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn
          FROM dbo.Puesto
         WHERE PuestoId = @NuevoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPuestoActualizar
    @PuestoId        INT,
    @Nombre          NVARCHAR(100),
    @EsMantenimiento BIT = 1,
    @Activo          BIT = 1,
    @UsuarioId       INT = NULL,
    @NombreUsuario   NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE PuestoId = @PuestoId)
            RAISERROR(N'El puesto o cargo no existe.', 16, 1);

        DECLARE @NombreLimpio NVARCHAR(100) = LTRIM(RTRIM(@Nombre));
        IF NULLIF(@NombreLimpio, N'') IS NULL
            RAISERROR(N'El nombre del puesto o cargo es obligatorio.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = @NombreLimpio AND PuestoId <> @PuestoId AND Activo = 1)
            RAISERROR(N'Ya existe otro puesto con ese mismo nombre.', 16, 1);

        UPDATE dbo.Puesto
           SET Nombre          = @NombreLimpio,
               EsMantenimiento = @EsMantenimiento,
               Activo          = @Activo,
               ActualizadoEn   = SYSUTCDATETIME()
         WHERE PuestoId = @PuestoId;

        UPDATE dbo.Empleado
           SET Puesto          = @NombreLimpio,
               EsMantenimiento = @EsMantenimiento,
               ActualizadoEn   = SYSUTCDATETIME()
         WHERE PuestoId = @PuestoId;

        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId) SET @UsuarioId = NULL;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'POSITION_UPDATED', 'POSITIONS', CAST(@PuestoId AS NVARCHAR(20)),
                CONCAT(N'Puesto actualizado: ', @NombreLimpio, N' (Activo: ', CASE WHEN @Activo = 1 THEN N'Sí' ELSE N'No' END, N').'));

        COMMIT TRANSACTION;

        SELECT PuestoId, Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn
          FROM dbo.Puesto
         WHERE PuestoId = @PuestoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPuestoEliminar
    @PuestoId      INT,
    @UsuarioId     INT = NULL,
    @NombreUsuario NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NombreActual NVARCHAR(100);
        SELECT @NombreActual = Nombre FROM dbo.Puesto WHERE PuestoId = @PuestoId;

        IF @NombreActual IS NULL
            RAISERROR(N'El puesto o cargo no existe.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Empleado WHERE PuestoId = @PuestoId AND Activo = 1)
            RAISERROR(N'No se puede desactivar el puesto porque hay empleados activos que lo ocupan.', 16, 1);

        UPDATE dbo.Puesto
           SET Activo = 0,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE PuestoId = @PuestoId;

        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId) SET @UsuarioId = NULL;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'POSITION_DEACTIVATED', 'POSITIONS', CAST(@PuestoId AS NVARCHAR(20)),
                CONCAT(N'Puesto desactivado: ', @NombreActual, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspEmpleadoListar
    @SoloActivos     BIT = 1,
    @EsMantenimiento BIT = NULL,
    @AreaId          NVARCHAR(15) = NULL,
    @Busqueda        NVARCHAR(100) = NULL,
    @Limit           INT = NULL,
    @Offset          INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.EmpleadoId,
        e.NombreCompleto,
        e.AreaId,
        COALESCE(a.Nombre, e.NombreArea, N'Sin Área Asignada') AS NombreArea,
        e.PuestoId,
        COALESCE(p.Nombre, e.Puesto) AS Puesto,
        COALESCE(p.EsMantenimiento, e.EsMantenimiento) AS EsMantenimiento,
        e.Activo,
        e.CreadoEn,
        e.ActualizadoEn
    FROM dbo.Empleado e
    LEFT JOIN dbo.Puesto p ON e.PuestoId = p.PuestoId
    LEFT JOIN dbo.Area a ON e.AreaId = a.AreaId
    WHERE (@SoloActivos = 0 OR e.Activo = 1)
      AND (@EsMantenimiento IS NULL OR COALESCE(p.EsMantenimiento, e.EsMantenimiento) = @EsMantenimiento)
      AND (@AreaId IS NULL OR e.AreaId = @AreaId)
      AND (
          @Busqueda IS NULL
          OR LTRIM(RTRIM(@Busqueda)) = N''
          OR e.NombreCompleto LIKE CONCAT(N'%', LTRIM(RTRIM(@Busqueda)), N'%')
          OR COALESCE(p.Nombre, e.Puesto) LIKE CONCAT(N'%', LTRIM(RTRIM(@Busqueda)), N'%')
      )
    ORDER BY COALESCE(p.EsMantenimiento, e.EsMantenimiento) DESC, e.NombreCompleto ASC
    OFFSET @Offset ROWS
    FETCH NEXT CASE WHEN @Limit IS NULL OR @Limit <= 0 THEN 2147483647 ELSE @Limit END ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspEmpleadoCrear
    @NombreCompleto   NVARCHAR(150),
    @AreaId           NVARCHAR(15) = NULL,
    @Puesto           NVARCHAR(100) = NULL,
    @PuestoId         INT = NULL,
    @EsMantenimiento  BIT = 1,
    @UsuarioId        INT = NULL,
    @NombreUsuario    NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NombreLimpio NVARCHAR(150) = LTRIM(RTRIM(ISNULL(@NombreCompleto, N'')));
        DECLARE @PuestoLimpio NVARCHAR(100) = LTRIM(RTRIM(ISNULL(@Puesto, N'')));

        IF NULLIF(@NombreLimpio, N'') IS NULL
            RAISERROR(N'El nombre completo del empleado es obligatorio.', 16, 1);

        IF @PuestoId IS NOT NULL
        BEGIN
            SELECT @PuestoLimpio = Nombre,
                   @EsMantenimiento = EsMantenimiento
              FROM dbo.Puesto
             WHERE PuestoId = @PuestoId AND Activo = 1;

            IF NULLIF(@PuestoLimpio, N'') IS NULL
                RAISERROR(N'El puesto especificado no existe o está inactivo.', 16, 1);
        END
        ELSE
        BEGIN
            IF NULLIF(@PuestoLimpio, N'') IS NULL
                RAISERROR(N'El puesto o cargo del empleado es obligatorio.', 16, 1);

            SELECT @PuestoId = PuestoId,
                   @PuestoLimpio = Nombre
              FROM dbo.Puesto
             WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio);

            IF @PuestoId IS NULL
            BEGIN
                INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
                VALUES (@PuestoLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
                SET @PuestoId = SCOPE_IDENTITY();
            END
            ELSE
            BEGIN
                UPDATE dbo.Puesto
                   SET Activo = 1, ActualizadoEn = SYSUTCDATETIME()
                 WHERE PuestoId = @PuestoId AND Activo = 0;
            END;
        END;

        DECLARE @NombreArea NVARCHAR(200) = NULL;
        IF @AreaId IS NOT NULL
        BEGIN
            SELECT @NombreArea = Nombre FROM dbo.Area WHERE AreaId = @AreaId;
        END;

        INSERT INTO dbo.Empleado (NombreCompleto, AreaId, NombreArea, PuestoId, Puesto, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
        VALUES (@NombreLimpio, @AreaId, @NombreArea, @PuestoId, @PuestoLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

        DECLARE @NuevoId INT = SCOPE_IDENTITY();

        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId) SET @UsuarioId = NULL;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'EMPLOYEE_CREATED', 'EMPLOYEES', CAST(@NuevoId AS NVARCHAR(20)),
                CONCAT(N'Empleado registrado: ', @NombreLimpio, N' (Puesto: ', @PuestoLimpio, N').'));

        COMMIT TRANSACTION;

        SELECT
            e.EmpleadoId,
            e.NombreCompleto,
            e.AreaId,
            COALESCE(a.Nombre, e.NombreArea, N'Sin Área') AS NombreArea,
            e.PuestoId,
            COALESCE(p.Nombre, e.Puesto) AS Puesto,
            COALESCE(p.EsMantenimiento, e.EsMantenimiento) AS EsMantenimiento,
            e.Activo,
            e.CreadoEn,
            e.ActualizadoEn
        FROM dbo.Empleado e
        LEFT JOIN dbo.Puesto p ON e.PuestoId = p.PuestoId
        LEFT JOIN dbo.Area a ON e.AreaId = a.AreaId
        WHERE e.EmpleadoId = @NuevoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspEmpleadoActualizar
    @EmpleadoId       INT,
    @NombreCompleto   NVARCHAR(150),
    @AreaId           NVARCHAR(15) = NULL,
    @Puesto           NVARCHAR(100) = NULL,
    @PuestoId         INT = NULL,
    @EsMantenimiento  BIT = 1,
    @Activo           BIT = 1,
    @UsuarioId        INT = NULL,
    @NombreUsuario    NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Empleado WHERE EmpleadoId = @EmpleadoId)
            RAISERROR(N'El empleado no existe.', 16, 1);

        DECLARE @NombreLimpio NVARCHAR(150) = LTRIM(RTRIM(ISNULL(@NombreCompleto, N'')));
        DECLARE @PuestoLimpio NVARCHAR(100) = LTRIM(RTRIM(ISNULL(@Puesto, N'')));

        IF NULLIF(@NombreLimpio, N'') IS NULL
            RAISERROR(N'El nombre completo del empleado es obligatorio.', 16, 1);

        IF @PuestoId IS NOT NULL
        BEGIN
            SELECT @PuestoLimpio = Nombre
              FROM dbo.Puesto
             WHERE PuestoId = @PuestoId;

            IF NULLIF(@PuestoLimpio, N'') IS NULL
                RAISERROR(N'El puesto especificado no existe.', 16, 1);
        END
        ELSE
        BEGIN
            IF NULLIF(@PuestoLimpio, N'') IS NULL
                RAISERROR(N'El puesto o cargo del empleado es obligatorio.', 16, 1);

            SELECT TOP 1 @PuestoId = PuestoId,
                         @PuestoLimpio = Nombre
              FROM dbo.Puesto
             WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio)
                OR Nombre = @PuestoLimpio;

            IF @PuestoId IS NULL
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio))
                BEGIN
                    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
                    VALUES (@PuestoLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
                    SET @PuestoId = SCOPE_IDENTITY();
                END
                ELSE
                BEGIN
                    SELECT TOP 1 @PuestoId = PuestoId, @PuestoLimpio = Nombre
                      FROM dbo.Puesto
                     WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio);
                END;
            END;
        END;

        DECLARE @NombreArea NVARCHAR(200) = NULL;
        IF @AreaId IS NOT NULL
        BEGIN
            SELECT @NombreArea = Nombre FROM dbo.Area WHERE AreaId = @AreaId;
        END;

        UPDATE dbo.Empleado
           SET NombreCompleto  = @NombreLimpio,
               AreaId          = @AreaId,
               NombreArea      = @NombreArea,
               PuestoId        = @PuestoId,
               Puesto          = @PuestoLimpio,
               EsMantenimiento = @EsMantenimiento,
               Activo          = @Activo,
               ActualizadoEn   = SYSUTCDATETIME()
         WHERE EmpleadoId = @EmpleadoId;

        -- Validar UsuarioId para auditoría
        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
                SET @UsuarioId = NULL;
        END;

        DECLARE @UNameAudit NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@NombreUsuario)), N''), N'SISTEMA');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @UNameAudit, 'EMPLOYEE_UPDATED', 'EMPLOYEES', CAST(@EmpleadoId AS NVARCHAR(20)),
                CONCAT(N'Empleado actualizado: ', @NombreLimpio, N' (Puesto: ', @PuestoLimpio, N', Activo: ', CASE WHEN @Activo = 1 THEN N'Sí' ELSE N'No' END, N').'));

        COMMIT TRANSACTION;

        SELECT
            e.EmpleadoId,
            e.NombreCompleto,
            e.AreaId,
            COALESCE(a.Nombre, e.NombreArea, N'Sin Área Asignada') AS NombreArea,
            e.PuestoId,
            COALESCE(p.Nombre, e.Puesto) AS Puesto,
            e.EsMantenimiento,
            e.Activo,
            e.CreadoEn,
            e.ActualizadoEn
        FROM dbo.Empleado e
        LEFT JOIN dbo.Puesto p ON e.PuestoId = p.PuestoId
        LEFT JOIN dbo.Area a ON e.AreaId = a.AreaId
        WHERE e.EmpleadoId = @EmpleadoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspEmpleadoCambiarEstado
    @EmpleadoId    INT,
    @Activo        BIT,
    @UsuarioId     INT = NULL,
    @NombreUsuario NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Empleado
           SET Activo = @Activo,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE EmpleadoId = @EmpleadoId;

        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId) SET @UsuarioId = NULL;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'EMPLOYEE_STATUS_CHANGED', 'EMPLOYEES', CAST(@EmpleadoId AS NVARCHAR(20)),
                CONCAT(N'Estado de empleado ID ', @EmpleadoId, N' cambiado a: ', CASE WHEN @Activo = 1 THEN N'Activo' ELSE N'Inactivo' END, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- ----------------------------------------------------------------------------
-- 14. PROCEDIMIENTOS ALMACENADOS: ACTIVOS, JERARQUÍA Y TRASPASOS
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspActivoObtenerRaicesPorArea
    @AreaId NVARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CodigoActivo, CodigoActivo AS assetCode,
           Nombre, Nombre AS name,
           Marca, Marca AS brand,
           Modelo, Modelo AS model,
           AreaId, AreaId AS areaId,
           EstacionId, EstacionId AS stationId,
           CodigoActivoPadre, CodigoActivoPadre AS parentAssetCode, CodigoActivoPadre AS parentAssetId,
           Nivel, Nivel AS [level],
           RutaAncestros, RutaAncestros AS ancestorsPath,
           Estado, Estado AS [status],
           Serie, Serie AS [serial],
           AtributosDinamicos, AtributosDinamicos AS dynamicAttributes,
           DatosImagen, DatosImagen AS imageData,
           ContadorHijos, ContadorHijos AS childCounter,
           CreadoEn, CreadoEn AS createdAt,
           ActualizadoEn, ActualizadoEn AS updatedAt,
           EsEquipoProceso, EsEquipoProceso AS isProcessEquipment
      FROM dbo.Activo
     WHERE AreaId = @AreaId
       AND CodigoActivoPadre IS NULL
       AND Estado <> 'deleted'
     ORDER BY CodigoActivo ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoObtenerHijos
    @ParentAssetCode NVARCHAR(60) = NULL,
    @ParentCode      NVARCHAR(60) = NULL,
    @AreaId          NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TargetParent NVARCHAR(60) = COALESCE(@ParentAssetCode, @ParentCode);
    SELECT CodigoActivo, CodigoActivo AS assetCode,
           Nombre, Nombre AS name,
           Marca, Marca AS brand,
           Modelo, Modelo AS model,
           AreaId, AreaId AS areaId,
           EstacionId, EstacionId AS stationId,
           CodigoActivoPadre, CodigoActivoPadre AS parentAssetCode, CodigoActivoPadre AS parentAssetId,
           Nivel, Nivel AS [level],
           RutaAncestros, RutaAncestros AS ancestorsPath,
           Estado, Estado AS [status],
           Serie, Serie AS [serial],
           AtributosDinamicos, AtributosDinamicos AS dynamicAttributes,
           DatosImagen, DatosImagen AS imageData,
           ContadorHijos, ContadorHijos AS childCounter,
           CreadoEn, CreadoEn AS createdAt,
           ActualizadoEn, ActualizadoEn AS updatedAt,
           EsEquipoProceso, EsEquipoProceso AS isProcessEquipment
      FROM dbo.Activo
     WHERE (@TargetParent IS NULL AND CodigoActivoPadre IS NULL OR CodigoActivoPadre = @TargetParent)
       AND (@AreaId IS NULL OR AreaId = @AreaId)
       AND Estado <> 'deleted'
     ORDER BY CodigoActivo ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoBuscar
    @Query NVARCHAR(100),
    @AreaId NVARCHAR(15) = NULL,
    @Level NVARCHAR(20) = NULL,
    @Status NVARCHAR(25) = NULL,
    @Limit INT = NULL,
    @Offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CleanQuery NVARCHAR(100) = LTRIM(RTRIM(@Query));

    SELECT CodigoActivo, CodigoActivo AS assetCode,
           Nombre, Nombre AS name,
           Marca, Marca AS brand,
           Modelo, Modelo AS model,
           AreaId, AreaId AS areaId,
           EstacionId, EstacionId AS stationId,
           CodigoActivoPadre, CodigoActivoPadre AS parentAssetCode, CodigoActivoPadre AS parentAssetId,
           Nivel, Nivel AS [level],
           RutaAncestros, RutaAncestros AS ancestorsPath,
           Estado, Estado AS [status],
           Serie, Serie AS [serial],
           AtributosDinamicos, AtributosDinamicos AS dynamicAttributes,
           DatosImagen, DatosImagen AS imageData,
           ContadorHijos, ContadorHijos AS childCounter,
           CreadoEn, CreadoEn AS createdAt,
           ActualizadoEn, ActualizadoEn AS updatedAt,
           EsEquipoProceso, EsEquipoProceso AS isProcessEquipment
      FROM dbo.Activo
     WHERE (@AreaId IS NULL OR AreaId = @AreaId)
       AND (@Level IS NULL OR Nivel = @Level)
       AND (@Status IS NULL OR Estado = @Status)
       AND (
           @CleanQuery IS NULL
           OR @CleanQuery = ''
           OR TextoBusqueda LIKE CONCAT('%', @CleanQuery, '%')
       )
     ORDER BY CodigoActivo ASC
     OFFSET @Offset ROWS
     FETCH NEXT CASE WHEN @Limit IS NULL OR @Limit <= 0 THEN 2147483647 ELSE @Limit END ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoBuscarPorSerie
    @Serial NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CodigoActivo, CodigoActivo AS assetCode,
           Nombre, Nombre AS name,
           Marca, Marca AS brand,
           Modelo, Modelo AS model,
           AreaId, AreaId AS areaId,
           EstacionId, EstacionId AS stationId,
           CodigoActivoPadre, CodigoActivoPadre AS parentAssetCode, CodigoActivoPadre AS parentAssetId,
           Nivel, Nivel AS [level],
           RutaAncestros, RutaAncestros AS ancestorsPath,
           Estado, Estado AS [status],
           Serie, Serie AS [serial],
           AtributosDinamicos, AtributosDinamicos AS dynamicAttributes,
           DatosImagen, DatosImagen AS imageData,
           ContadorHijos, ContadorHijos AS childCounter,
           CreadoEn, CreadoEn AS createdAt,
           ActualizadoEn, ActualizadoEn AS updatedAt,
           EsEquipoProceso, EsEquipoProceso AS isProcessEquipment
      FROM dbo.Activo
     WHERE Serie = @Serial AND Estado <> 'deleted';
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoCrear
    @Name NVARCHAR(200),
    @Brand NVARCHAR(100) = NULL,
    @Model NVARCHAR(100) = NULL,
    @AreaId NVARCHAR(15),
    @StationId NVARCHAR(100) = '',
    @Level NVARCHAR(20),
    @ParentAssetCode NVARCHAR(60) = NULL,
    @Status NVARCHAR(25) = 'active',
    @Serial NVARCHAR(100) = NULL,
    @DynamicAttributes NVARCHAR(MAX) = NULL,
    @ImageData NVARCHAR(500) = NULL,
    @Observaciones NVARCHAR(MAX) = NULL,
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Serial IS NOT NULL AND LTRIM(RTRIM(@Serial)) <> ''
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Activo WHERE Serie = @Serial AND Estado <> 'deleted')
                RAISERROR(N'El número de serie ya está en uso por otro activo activo.', 16, 1);
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
                RAISERROR(N'El área no existe.', 16, 1);

            SET @NewAssetCode = CONCAT(@AreaId, '-', FORMAT(@ac, '000'));
        END
        ELSE
        BEGIN
            DECLARE @parentStatus NVARCHAR(25), @parentAncestors NVARCHAR(400);
            DECLARE @pcTable TABLE (val INT NOT NULL);

            SELECT @parentStatus = Estado, @parentAncestors = RutaAncestros
              FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
             WHERE CodigoActivo = @ParentAssetCode;

            IF @parentStatus IS NULL
                RAISERROR(N'El activo padre no existe.', 16, 1);
            IF @parentStatus <> 'active'
                RAISERROR(N'El activo padre no está activo.', 16, 1);
            IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE CodigoActivo = @ParentAssetCode AND EstadoCandado = 'pending')
                RAISERROR(N'El activo padre tiene una solicitud de baja pendiente.', 16, 1);

            UPDATE dbo.Activo WITH (UPDLOCK, HOLDLOCK)
               SET ContadorHijos += 1
             OUTPUT inserted.ContadorHijos INTO @pcTable(val)
              WHERE CodigoActivo = @ParentAssetCode;

            DECLARE @pc INT; SELECT @pc = val FROM @pcTable;
            SET @NewAssetCode = CONCAT(@ParentAssetCode, '-', FORMAT(@pc, '00'));
            SET @AncestorsPath = CASE WHEN @parentAncestors = '' THEN @ParentAssetCode
                                      ELSE CONCAT(@parentAncestors, '/', @ParentAssetCode) END;
        END;

        DECLARE @CleanStation NVARCHAR(100) = ISNULL(@StationId, '');

        INSERT INTO dbo.Activo
            (CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, CodigoActivoPadre,
             Nivel, RutaAncestros, Estado, Serie, AtributosDinamicos, DatosImagen,
             Observaciones, ContadorHijos, CreadoEn)
        VALUES
            (@NewAssetCode, @Name, @Brand, @Model, @AreaId, @CleanStation, @ParentAssetCode,
             @Level, @AncestorsPath, @Status, NULLIF(@Serial, ''), @DynamicAttributes, @ImageData,
             @Observaciones,
             0, SYSUTCDATETIME());

        IF @UserId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UserId)
        BEGIN
            SELECT @UserId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@UserName)));
            IF @UserId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UserId)
                SET @UserId = NULL;
        END;

        DECLARE @UNameAudit NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA');

        INSERT INTO dbo.HistorialEstadoActivo
            (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        VALUES
            (@NewAssetCode, @Status, SYSUTCDATETIME(), @AreaId, N'Alta inicial del activo', @UserId, @UNameAudit);

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UNameAudit, 'ASSET_CREATED', 'ASSETS', @NewAssetCode,
                CONCAT(N'Activo creado: ', @NewAssetCode, N' (', @Name, N') en área ', @AreaId, N'.'));

        COMMIT TRANSACTION;
        SELECT @NewAssetCode AS CodigoActivo, 
               @NewAssetCode AS assetCode, 
               @NewAssetCode AS NewAssetCode,
               @NewAssetCode AS newAssetCode;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoActualizar
    @CodigoActivo NVARCHAR(60) = NULL,
    @AssetCode NVARCHAR(60) = NULL,
    @Name NVARCHAR(200) = NULL,
    @Brand NVARCHAR(100) = NULL,
    @Model NVARCHAR(100) = NULL,
    @StationId NVARCHAR(100) = NULL,
    @Serial NVARCHAR(100) = NULL,
    @DynamicAttributes NVARCHAR(MAX) = NULL,
    @ImageData NVARCHAR(500) = NULL,
    @Status NVARCHAR(25) = NULL,
    @Estado NVARCHAR(25) = NULL,
    @Observaciones NVARCHAR(MAX) = NULL,
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @TargetCode NVARCHAR(60) = COALESCE(NULLIF(LTRIM(RTRIM(@AssetCode)), ''), NULLIF(LTRIM(RTRIM(@CodigoActivo)), ''));

        IF @TargetCode IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Activo WHERE CodigoActivo = @TargetCode)
            RAISERROR(N'El activo no existe.', 16, 1);

        DECLARE @currStatus NVARCHAR(25), @currArea NVARCHAR(15), @oldSerial NVARCHAR(100);
        SELECT @currStatus = Estado, @currArea = AreaId, @oldSerial = Serie
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @TargetCode;

        DECLARE @NewCleanSerial NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@Serial)), '');

        -- Validar unicidad del número de serie
        IF @NewCleanSerial IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Activo WHERE Serie = @NewCleanSerial AND CodigoActivo <> @TargetCode AND Estado <> 'deleted')
                RAISERROR(N'El número de serie ya está en uso por otro activo activo.', 16, 1);
        END;

        DECLARE @DesiredStatus NVARCHAR(25) = COALESCE(NULLIF(LTRIM(RTRIM(@Status)), N''), NULLIF(LTRIM(RTRIM(@Estado)), N''));

        UPDATE dbo.Activo
           SET Nombre             = COALESCE(@Name, Nombre),
               Marca              = @Brand,
               Modelo             = @Model,
               EstacionId         = COALESCE(@StationId, EstacionId, ''),
               Serie              = @NewCleanSerial,
               AtributosDinamicos = COALESCE(@DynamicAttributes, AtributosDinamicos),
               DatosImagen        = COALESCE(@ImageData, DatosImagen),
               Observaciones      = COALESCE(@Observaciones, Observaciones),
               Estado             = COALESCE(@DesiredStatus, Estado),
               ActualizadoEn      = SYSUTCDATETIME()
         WHERE CodigoActivo = @TargetCode;

        IF @DesiredStatus IS NOT NULL AND @DesiredStatus <> @currStatus
        BEGIN
            UPDATE dbo.HistorialEstadoActivo
               SET FinalizadoEn = SYSUTCDATETIME()
             WHERE CodigoActivo = @TargetCode AND FinalizadoEn IS NULL;

            INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
            VALUES (@TargetCode, @DesiredStatus, SYSUTCDATETIME(), @currArea, N'Modificación de estado en edición de activo', @UserId, COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA'));
        END;

        IF @UserId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UserId)
        BEGIN
            SELECT @UserId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@UserName)));
            IF @UserId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UserId)
                SET @UserId = NULL;
        END;

        DECLARE @UNameAuditUpd NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA');

        -- Auditoría obligatoria en Bitácora Kardex si el número de serie cambió
        IF ISNULL(@NewCleanSerial, N'') <> ISNULL(@oldSerial, N'')
        BEGIN
            INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
            VALUES (@UserId, @UNameAuditUpd, 'ASSET_SERIAL_CHANGED', 'ASSETS', @TargetCode,
                    CONCAT(N'Número de serie del activo ', @TargetCode, N' modificado de "', ISNULL(@oldSerial, N'(sin serie)'), N'" a "', ISNULL(@NewCleanSerial, N'(sin serie)'), N'".'));
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UNameAuditUpd, 'ASSET_UPDATED', 'ASSETS', @TargetCode,
                CONCAT(N'Activo actualizado: ', @TargetCode, N' (', COALESCE(@Name, @TargetCode), N').'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoTraspasar
    @SourceAssetCode NVARCHAR(60),
    @TargetAreaId    NVARCHAR(15),
    @UserId          INT = NULL,
    @UserName        NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @srcArea NVARCHAR(15), @srcName NVARCHAR(200), @srcStatus NVARCHAR(25), @srcLevel NVARCHAR(20);
        SELECT @srcArea = AreaId, @srcName = Nombre, @srcStatus = Estado, @srcLevel = Nivel
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @SourceAssetCode;

        IF @srcArea IS NULL OR @srcStatus = 'deleted'
            RAISERROR(N'El activo origen no existe o está eliminado.', 16, 1);

        IF @srcStatus = 'transferredDeactivated'
            RAISERROR(N'El activo ya fue transferido anteriormente y se encuentra desactivado. Debe gestionarlo desde su nueva área.', 16, 1);

        IF @srcArea = @TargetAreaId
            RAISERROR(N'El área destino debe ser distinta al área actual del activo.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @TargetAreaId)
            RAISERROR(N'El área destino especificada no existe.', 16, 1);

        -- Validar que no existan OTs abiertas en el activo ni en sus descendientes
        DECLARE @OTAbiertaId NVARCHAR(20);
        SELECT TOP 1 @OTAbiertaId = ot.OrdenTrabajoId
          FROM dbo.OrdenTrabajo ot WITH (UPDLOCK, HOLDLOCK)
          JOIN dbo.Activo a WITH (NOLOCK) ON ot.CodigoActivo = a.CodigoActivo
         WHERE a.AreaId = @srcArea
           AND (a.CodigoActivo = @SourceAssetCode OR CHARINDEX(CONCAT(N',', @SourceAssetCode, N','), CONCAT(N',', a.RutaAncestros, N',')) > 0)
           AND ot.Estado IN (N'pending', N'inProgress', N'in_progress', N'paused');

        IF @OTAbiertaId IS NOT NULL
        BEGIN
            DECLARE @MsgTraspaso NVARCHAR(250) = CONCAT(N'No se puede transferir el activo: cuenta con la orden de trabajo abierta (', @OTAbiertaId, N'). Debe concluirse o cancelarse antes del traspaso.');
            RAISERROR(@MsgTraspaso, 16, 1);
        END;

        -- Retorno a área original si ya había sido transferido
        DECLARE @PreviousOriginCode NVARCHAR(60);
        SELECT @PreviousOriginCode = CodigoActivo
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE AreaId = @TargetAreaId
           AND TraspasadoACodigo = @SourceAssetCode
           AND Estado = 'transferredDeactivated'
           AND Nivel = 'equipment';

        IF @PreviousOriginCode IS NOT NULL
        BEGIN
            UPDATE a
               SET a.Estado = 'active',
                   a.TraspasadoACodigo = NULL,
                   a.ActualizadoEn = SYSUTCDATETIME()
              FROM dbo.Activo a
             WHERE a.CodigoActivo = @PreviousOriginCode
                OR a.RutaAncestros = @PreviousOriginCode
                OR a.RutaAncestros LIKE @PreviousOriginCode + ',%';

            UPDATE a
               SET a.Estado = 'transferredDeactivated',
                   a.TraspasadoACodigo = @PreviousOriginCode,
                   a.ActualizadoEn = SYSUTCDATETIME()
              FROM dbo.Activo a
             WHERE a.CodigoActivo = @SourceAssetCode
                OR a.RutaAncestros = @SourceAssetCode
                OR a.RutaAncestros LIKE @SourceAssetCode + ',%';

            UPDATE hea
               SET FinalizadoEn = SYSUTCDATETIME()
              FROM dbo.HistorialEstadoActivo hea
             WHERE (hea.CodigoActivo = @SourceAssetCode OR hea.CodigoActivo LIKE @SourceAssetCode + '-%')
               AND hea.FinalizadoEn IS NULL;

            INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
            VALUES (@PreviousOriginCode, 'active', SYSUTCDATETIME(), @TargetAreaId,
                    CONCAT(N'Retorno a su área original desde ', @srcArea, N' (código intermedio: ', @SourceAssetCode, N')'),
                    @UserId, @UserName);

            UPDATE dbo.PlanPreventivo
               SET Estado = 'active',
                   Notas = ISNULL(Notas, '') + CONCAT(CHAR(13), CHAR(10), N'[Sistema]: Plan reactivado automáticamente por retorno a su área original.')
             WHERE CodigoActivo = @PreviousOriginCode AND Estado = 'paused';

            INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
            VALUES (@UserId, @UserName, 'ASSET_TRANSFER', 'ASSETS', @SourceAssetCode,
                    CONCAT(N'Activo ', @SourceAssetCode, N' retornado a su área y código original ', @PreviousOriginCode, N' en ', @TargetAreaId, N'.'));

            COMMIT TRANSACTION;
            SELECT @PreviousOriginCode AS NewAssetCode, @PreviousOriginCode AS CodigoActivo;
            RETURN;
        END;

        -- Subárbol nuevo en destino (CTE Recursiva con COLLATE DATABASE_DEFAULT)
        CREATE TABLE #ArbolOrigen (
            OldCode       NVARCHAR(60) COLLATE DATABASE_DEFAULT PRIMARY KEY,
            Nombre        NVARCHAR(200) COLLATE DATABASE_DEFAULT,
            Marca         NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Modelo        NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            EstacionId    NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            OldParentCode NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            Nivel         NVARCHAR(20) COLLATE DATABASE_DEFAULT,
            RutaAncestros NVARCHAR(400) COLLATE DATABASE_DEFAULT,
            Serie         NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Atributos     NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            DatosImagen   NVARCHAR(500) COLLATE DATABASE_DEFAULT,
            Observaciones NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            Depth         INT,
            ChildOrder    INT,
            NewCode       NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            NewParentCode NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            NewRuta       NVARCHAR(400) COLLATE DATABASE_DEFAULT
        );

        WITH SubTree AS (
            SELECT 
                a.CodigoActivo, a.Nombre, a.Marca, a.Modelo, a.EstacionId,
                a.CodigoActivoPadre, a.Nivel, a.RutaAncestros, a.Serie,
                a.AtributosDinamicos, a.DatosImagen, a.Observaciones,
                0 AS Depth,
                1 AS ChildOrder
            FROM dbo.Activo a WITH (UPDLOCK, HOLDLOCK)
            WHERE a.CodigoActivo = @SourceAssetCode

            UNION ALL

            SELECT 
                c.CodigoActivo, c.Nombre, c.Marca, c.Modelo, c.EstacionId,
                c.CodigoActivoPadre, c.Nivel, c.RutaAncestros, c.Serie,
                c.AtributosDinamicos, c.DatosImagen, c.Observaciones,
                p.Depth + 1 AS Depth,
                CAST(ROW_NUMBER() OVER (PARTITION BY c.CodigoActivoPadre ORDER BY c.CodigoActivo) AS INT) AS ChildOrder
            FROM dbo.Activo c WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN SubTree p ON c.CodigoActivoPadre = p.CodigoActivo
            WHERE c.Estado <> 'deleted'
        )
        INSERT INTO #ArbolOrigen (
            OldCode, Nombre, Marca, Modelo, EstacionId, OldParentCode, Nivel,
            RutaAncestros, Serie, Atributos, DatosImagen, Observaciones, Depth, ChildOrder
        )
        SELECT 
            CodigoActivo, Nombre, Marca, Modelo, EstacionId, CodigoActivoPadre, Nivel,
            RutaAncestros, Serie, AtributosDinamicos, DatosImagen, Observaciones, Depth, ChildOrder
        FROM SubTree;

        IF EXISTS (
            SELECT 1 FROM dbo.CandadoBaja cb
            INNER JOIN #ArbolOrigen o ON o.OldCode = cb.CodigoActivo
            WHERE cb.EstadoCandado = 'pending'
        )
        BEGIN
            RAISERROR(N'El activo o alguno de sus componentes tiene una solicitud de baja pendiente.', 16, 1);
        END;

        DECLARE @targetCounter TABLE (val INT NOT NULL);
        UPDATE dbo.Area WITH (UPDLOCK, HOLDLOCK)
           SET ContadorActivos += 1
         OUTPUT inserted.ContadorActivos INTO @targetCounter(val)
          WHERE AreaId = @TargetAreaId;

        DECLARE @nextRoot INT; SELECT @nextRoot = val FROM @targetCounter;
        DECLARE @NewRootCode NVARCHAR(60) = CONCAT(@TargetAreaId, '-', FORMAT(@nextRoot, '000'));

        UPDATE #ArbolOrigen 
           SET NewCode = @NewRootCode, 
               NewParentCode = NULL,
               NewRuta = ''
         WHERE Depth = 0;

        DECLARE @currentDepth INT = 1;
        WHILE @currentDepth <= 3
        BEGIN
            UPDATE child
               SET child.NewParentCode = parent.NewCode,
                   child.NewCode = CONCAT(parent.NewCode, '-', FORMAT(child.ChildOrder, '00')),
                   child.NewRuta = CASE WHEN parent.NewRuta = '' THEN parent.NewCode ELSE CONCAT(parent.NewRuta, ',', parent.NewCode) END
              FROM #ArbolOrigen child
              INNER JOIN #ArbolOrigen parent ON child.OldParentCode = parent.OldCode
             WHERE child.Depth = @currentDepth;

            SET @currentDepth += 1;
        END;

        DECLARE @d INT = 0;
        WHILE @d <= 3
        BEGIN
            INSERT INTO dbo.Activo (
                CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId,
                CodigoActivoPadre, Nivel, RutaAncestros, Estado, Serie,
                AtributosDinamicos, DatosImagen, Observaciones, ContadorHijos, CreadoEn
            )
            SELECT 
                o.NewCode, o.Nombre, o.Marca, o.Modelo, @TargetAreaId, o.EstacionId,
                o.NewParentCode, o.Nivel, o.NewRuta, 'active', o.Serie,
                o.Atributos, o.DatosImagen, o.Observaciones,
                (SELECT COUNT(*) FROM #ArbolOrigen c WHERE c.OldParentCode = o.OldCode),
                SYSUTCDATETIME()
            FROM #ArbolOrigen o
            WHERE o.Depth = @d;

            SET @d += 1;
        END;

        UPDATE a
           SET a.Estado = 'transferredDeactivated',
               a.TraspasadoACodigo = o.NewCode,
               a.ActualizadoEn = SYSUTCDATETIME()
          FROM dbo.Activo a
          INNER JOIN #ArbolOrigen o ON a.CodigoActivo = o.OldCode;

        UPDATE hea
           SET FinalizadoEn = SYSUTCDATETIME()
          FROM dbo.HistorialEstadoActivo hea
          INNER JOIN #ArbolOrigen o ON hea.CodigoActivo = o.OldCode
         WHERE hea.FinalizadoEn IS NULL;

        INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        SELECT 
            o.NewCode, 'active', SYSUTCDATETIME(), @TargetAreaId,
            CONCAT(N'Traspaso de subárbol desde área ', @srcArea, N' (código anterior: ', o.OldCode, N')'),
            @UserId, @UserName
        FROM #ArbolOrigen o;

        UPDATE dbo.PlanPreventivo
           SET Estado = 'paused',
               Notas = ISNULL(Notas, '') + CONCAT(CHAR(13), CHAR(10), N'[Sistema]: Plan pausado automáticamente por traspaso del equipo a otra área.')
         WHERE CodigoActivo = @SourceAssetCode AND Estado = 'active';

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_TRANSFER', 'ASSETS', @SourceAssetCode,
                CONCAT(N'Subárbol de ', @SourceAssetCode, N' transferido desde ', @srcArea, N' a ', @TargetAreaId, N' con nuevo código raíz ', @NewRootCode, N'.'));

        DROP TABLE #ArbolOrigen;

        COMMIT TRANSACTION;
        SELECT @NewRootCode AS NewAssetCode, @NewRootCode AS CodigoActivo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoReactivar
    @AssetCode    NVARCHAR(60) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @UserId       INT = NULL,
    @UserName     NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @TargetCode NVARCHAR(60) = COALESCE(@AssetCode, @CodigoActivo);
        DECLARE @st NVARCHAR(25), @ar NVARCHAR(15), @nm NVARCHAR(200);
        SELECT @st = Estado, @ar = AreaId, @nm = Nombre
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @TargetCode;

        IF @st IS NULL
            RAISERROR(N'El activo no existe.', 16, 1);

        IF @st <> 'transferredDeactivated' AND @st <> 'inactive'
            RAISERROR(N'El activo no se encuentra en estado inactivo o desactivado por traspaso.', 16, 1);

        UPDATE dbo.Activo
           SET Estado = 'active',
               ActualizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @TargetCode;

        INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        VALUES (@TargetCode, 'active', SYSUTCDATETIME(), @ar, N'Reactivación de activo', @UserId, @UserName);

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_REACTIVATED', 'ASSETS', @TargetCode,
                CONCAT(N'Activo reactivado: ', @TargetCode, N' (', @nm, N').'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoAlternarEstado
    @AssetCode    NVARCHAR(60) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @NewStatus    NVARCHAR(25) = NULL,
    @Status       NVARCHAR(25) = NULL,
    @Reason       NVARCHAR(500) = NULL,
    @UserId       INT = NULL,
    @UserName     NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Code NVARCHAR(60) = COALESCE(NULLIF(LTRIM(RTRIM(@AssetCode)), N''), NULLIF(LTRIM(RTRIM(@CodigoActivo)), N''));
        DECLARE @TargetStatus NVARCHAR(25) = COALESCE(NULLIF(LTRIM(RTRIM(@NewStatus)), N''), NULLIF(LTRIM(RTRIM(@Status)), N''));

        IF @Code IS NULL
            RAISERROR(N'Debe especificarse el código del activo.', 16, 1);

        IF @TargetStatus IS NULL
            RAISERROR(N'Debe especificarse el nuevo estado del activo.', 16, 1);

        DECLARE @currStatus NVARCHAR(25), @ar NVARCHAR(15), @nm NVARCHAR(200);
        SELECT @currStatus = Estado, @ar = AreaId, @nm = Nombre
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @Code;

        IF @currStatus IS NULL
            RAISERROR(N'El activo no existe.', 16, 1);

        UPDATE dbo.Activo
           SET Estado = @TargetStatus,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @Code;

        UPDATE dbo.HistorialEstadoActivo
           SET FinalizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @Code AND FinalizadoEn IS NULL;

        INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        VALUES (@Code, @TargetStatus, SYSUTCDATETIME(), @ar, @Reason, @UserId, COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA'));

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA'), 'ASSET_STATUS_CHANGED', 'ASSETS', @Code,
                CONCAT(N'Estado de ', @Code, N' cambiado a: ', @TargetStatus, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoActualizarEsEquipoProceso
    @CodigoActivo NVARCHAR(60) = NULL,
    @AssetCode NVARCHAR(60) = NULL,
    @EsEquipoProceso BIT = 1,
    @UsuarioId INT = NULL,
    @UserId INT = NULL,
    @NombreUsuario NVARCHAR(100) = N'',
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Activo
       SET EsEquipoProceso = @EsEquipoProceso,
           ActualizadoEn = SYSUTCDATETIME()
     WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);
END;
GO

-- ----------------------------------------------------------------------------
-- 4. PROCEDIMIENTO TRANSACCIONAL: CLONAR ÁRBOL COMPLETO DE ACTIVO
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.uspActivoClonarArbol
    @CodigoActivoOrigen NVARCHAR(60),
    @AreaDestinoId      NVARCHAR(15),
    @NuevoNombreRaiz    NVARCHAR(200) = NULL,
    @NuevoSerialRaiz    NVARCHAR(100) = NULL,
    @Observaciones      NVARCHAR(MAX) = NULL,
    @CopiarAtributos    BIT = 1,
    @UserId             INT = NULL,
    @UserName           NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validar que exista el activo de origen
        IF NOT EXISTS (SELECT 1 FROM dbo.Activo WHERE CodigoActivo = @CodigoActivoOrigen AND Estado <> 'deleted')
            RAISERROR(N'El activo de origen no existe o se encuentra eliminado.', 16, 1);

        -- 2. Validar que exista el área destino
        IF NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @AreaDestinoId AND Activo = 1)
            RAISERROR(N'El área destino especificada no existe o se encuentra inactiva.', 16, 1);

        -- 3. Validar serial si fue especificado para la nueva raíz
        IF @NuevoSerialRaiz IS NOT NULL AND LTRIM(RTRIM(@NuevoSerialRaiz)) <> ''
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Activo WHERE Serie = @NuevoSerialRaiz AND Estado <> 'deleted')
                RAISERROR(N'El número de serie indicado para la nueva raíz ya está en uso por otro activo activo.', 16, 1);
        END;

        -- 4. Obtener datos de la raíz de origen
        DECLARE @OrigNombre NVARCHAR(200), @OrigMarca NVARCHAR(100), @OrigModelo NVARCHAR(100);
        DECLARE @OrigNivel NVARCHAR(20), @OrigEstacion NVARCHAR(100), @OrigAtributos NVARCHAR(MAX);
        DECLARE @OrigObservaciones NVARCHAR(MAX);

        SELECT @OrigNombre = Nombre,
               @OrigMarca = Marca,
               @OrigModelo = Modelo,
               @OrigNivel = Nivel,
               @OrigEstacion = EstacionId,
               @OrigAtributos = AtributosDinamicos,
               @OrigObservaciones = Observaciones
          FROM dbo.Activo
         WHERE CodigoActivo = @CodigoActivoOrigen;

        -- 5. Generar código correlativo para la nueva raíz en el área destino
        DECLARE @acTable TABLE (val INT NOT NULL);
        UPDATE dbo.Area WITH (UPDLOCK, HOLDLOCK)
           SET ContadorActivos += 1
         OUTPUT inserted.ContadorActivos INTO @acTable(val)
          WHERE AreaId = @AreaDestinoId;

        DECLARE @ac INT; SELECT @ac = val FROM @acTable;
        DECLARE @NuevoCodigoRaiz NVARCHAR(60) = CONCAT(@AreaDestinoId, '-', FORMAT(@ac, '000'));

        DECLARE @NombreFinalRaiz NVARCHAR(200) = COALESCE(NULLIF(LTRIM(RTRIM(@NuevoNombreRaiz)), N''), @OrigNombre);
        DECLARE @ObsFinalRaiz NVARCHAR(MAX) = COALESCE(@Observaciones, @OrigObservaciones);
        DECLARE @AtributosRaiz NVARCHAR(MAX) = CASE WHEN @CopiarAtributos = 1 THEN @OrigAtributos ELSE NULL END;

        -- 6. Insertar activo raíz clonado (sin imagen y con serial opcional)
        INSERT INTO dbo.Activo (
            CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, CodigoActivoPadre,
            Nivel, RutaAncestros, Estado, Serie, AtributosDinamicos, DatosImagen,
            Observaciones, ContadorHijos, CreadoEn
        )
        VALUES (
            @NuevoCodigoRaiz, @NombreFinalRaiz, @OrigMarca, @OrigModelo, @AreaDestinoId,
            @OrigEstacion, NULL, @OrigNivel, '', 'active', NULLIF(@NuevoSerialRaiz, ''),
            @AtributosRaiz, NULL, @ObsFinalRaiz, 0, SYSUTCDATETIME()
        );

        -- Tabla de mapeo de códigos Origen -> Nuevo
        DECLARE @Mapeo TABLE (
            CodigoOrigen NVARCHAR(60) COLLATE DATABASE_DEFAULT PRIMARY KEY,
            CodigoNuevo  NVARCHAR(60) COLLATE DATABASE_DEFAULT NOT NULL,
            RutaAncestros NVARCHAR(400) COLLATE DATABASE_DEFAULT NOT NULL
        );
        INSERT INTO @Mapeo (CodigoOrigen, CodigoNuevo, RutaAncestros)
        VALUES (@CodigoActivoOrigen, @NuevoCodigoRaiz, '');

        -- Tabla temporal de descendientes con COLLATE DATABASE_DEFAULT
        CREATE TABLE #Descendientes (
            Orden         INT IDENTITY(1,1),
            CodigoOrigen  NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            PadreOrigen   NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            Nombre        NVARCHAR(200) COLLATE DATABASE_DEFAULT,
            Marca         NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Modelo        NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Nivel         NVARCHAR(20) COLLATE DATABASE_DEFAULT,
            Observaciones NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            Atributos     NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            Profundidad   INT
        );

        -- Recorrido jerárquico por niveles de profundidad
        WITH ArbolDesc AS (
            SELECT CodigoActivo, CodigoActivoPadre, Nombre, Marca, Modelo, Nivel, Observaciones, AtributosDinamicos, 1 AS Profundidad
              FROM dbo.Activo
             WHERE CodigoActivoPadre = @CodigoActivoOrigen
               AND Estado <> 'deleted'
            UNION ALL
            SELECT c.CodigoActivo, c.CodigoActivoPadre, c.Nombre, c.Marca, c.Modelo, c.Nivel, c.Observaciones, c.AtributosDinamicos, a.Profundidad + 1
              FROM dbo.Activo c
              INNER JOIN ArbolDesc a ON c.CodigoActivoPadre = a.CodigoActivo
             WHERE c.Estado <> 'deleted'
        )
        INSERT INTO #Descendientes (CodigoOrigen, PadreOrigen, Nombre, Marca, Modelo, Nivel, Observaciones, Atributos, Profundidad)
        SELECT CodigoActivo, CodigoActivoPadre, Nombre, Marca, Modelo, Nivel, Observaciones, AtributosDinamicos, Profundidad
          FROM ArbolDesc
         ORDER BY Profundidad ASC, CodigoActivo ASC;

        -- Clonar cada descendiente asignándole su nuevo padre
        DECLARE @MaxOrden INT = (SELECT ISNULL(MAX(Orden), 0) FROM #Descendientes);
        DECLARE @i INT = 1;
        DECLARE @TotalClonados INT = 1; -- contando la raíz

        WHILE @i <= @MaxOrden
        BEGIN
            DECLARE @cOrigen NVARCHAR(60), @pOrigen NVARCHAR(60), @cNombre NVARCHAR(200);
            DECLARE @cMarca NVARCHAR(100), @cModelo NVARCHAR(100), @cNivel NVARCHAR(20);
            DECLARE @cObs NVARCHAR(MAX), @cAttr NVARCHAR(MAX);

            SELECT @cOrigen = CodigoOrigen,
                   @pOrigen = PadreOrigen,
                   @cNombre = Nombre,
                   @cMarca = Marca,
                   @cModelo = Modelo,
                   @cNivel = Nivel,
                   @cObs = Observaciones,
                   @cAttr = Atributos
              FROM #Descendientes
             WHERE Orden = @i;

            DECLARE @NuevoPadreCode NVARCHAR(60);
            DECLARE @RutaAncestrosPadre NVARCHAR(400);

            SELECT @NuevoPadreCode = CodigoNuevo,
                   @RutaAncestrosPadre = RutaAncestros
              FROM @Mapeo
             WHERE CodigoOrigen = @pOrigen;

            IF @NuevoPadreCode IS NOT NULL
            BEGIN
                DECLARE @childCounterTable TABLE (cnt INT NOT NULL);
                UPDATE dbo.Activo WITH (UPDLOCK, HOLDLOCK)
                   SET ContadorHijos += 1
                 OUTPUT inserted.ContadorHijos INTO @childCounterTable(cnt)
                  WHERE CodigoActivo = @NuevoPadreCode;

                DECLARE @chCnt INT; SELECT @chCnt = cnt FROM @childCounterTable;
                DELETE FROM @childCounterTable;

                DECLARE @NuevoCodigoHijo NVARCHAR(60) = CONCAT(@NuevoPadreCode, '-', FORMAT(@chCnt, '00'));
                DECLARE @RutaAncestrosHijo NVARCHAR(400) = CASE 
                    WHEN @RutaAncestrosPadre = '' THEN @NuevoPadreCode 
                    ELSE CONCAT(@RutaAncestrosPadre, '/', @NuevoPadreCode) 
                END;

                DECLARE @AtributosHijo NVARCHAR(MAX) = CASE WHEN @CopiarAtributos = 1 THEN @cAttr ELSE NULL END;

                INSERT INTO dbo.Activo (
                    CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, CodigoActivoPadre,
                    Nivel, RutaAncestros, Estado, Serie, AtributosDinamicos, DatosImagen,
                    Observaciones, ContadorHijos, CreadoEn
                )
                VALUES (
                    @NuevoCodigoHijo, @cNombre, @cMarca, @cModelo, @AreaDestinoId,
                    '', @NuevoPadreCode, @cNivel, @RutaAncestrosHijo, 'active', NULL,
                    @AtributosHijo, NULL, @cObs, 0, SYSUTCDATETIME()
                );

                INSERT INTO @Mapeo (CodigoOrigen, CodigoNuevo, RutaAncestros)
                VALUES (@cOrigen, @NuevoCodigoHijo, @RutaAncestrosHijo);

                SET @TotalClonados += 1;
            END;

            SET @i += 1;
        END;

        DROP TABLE #Descendientes;

        -- Registrar en Historial y Bitácora Kardex
        DECLARE @AuditUser INT = @UserId;
        IF @AuditUser IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @AuditUser)
            SET @AuditUser = NULL;
        DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA');

        INSERT INTO dbo.HistorialEstadoActivo (
            CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario
        )
        SELECT CodigoNuevo, 'active', SYSUTCDATETIME(), @AreaDestinoId,
               CONCAT(N'Clonado desde el activo ', CodigoOrigen), @AuditUser, @UName
          FROM @Mapeo;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (
            @AuditUser, @UName, 'ASSET_TREE_CLONED', 'ASSETS', @NuevoCodigoRaiz,
            CONCAT(N'Árbol completo clonado desde ', @CodigoActivoOrigen, N' hacia ', @NuevoCodigoRaiz, 
                   N' en área ', @AreaDestinoId, N' con ', @TotalClonados, N' elementos en total.')
        );

        COMMIT TRANSACTION;

        SELECT @NuevoCodigoRaiz AS CodigoActivo,
               @NuevoCodigoRaiz AS assetCode,
               @NuevoCodigoRaiz AS id,
               @NombreFinalRaiz AS Nombre,
               @AreaDestinoId   AS AreaId,
               @TotalClonados   AS totalNodos;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#Descendientes') IS NOT NULL DROP TABLE #Descendientes;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 5. PROCEDIMIENTOS DE PLANTILLAS DE ACTIVOS
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.uspPlantillaActivoListar
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PlantillaId AS id,
           PlantillaId,
           Nombre AS name,
           Nombre,
           Descripcion AS description,
           Descripcion,
           NivelRaiz AS rootLevel,
           NivelRaiz,
           TotalNodos AS totalNodes,
           TotalNodos,
           Activo AS isActive,
           Activo,
           CreadoEn AS createdAt,
           ActualizadoEn AS updatedAt
      FROM dbo.PlantillaActivo
     WHERE (@IncludeInactive = 1 OR Activo = 1)
     ORDER BY Nombre ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPlantillaActivoObtenerDetalle
    @PlantillaId INT
AS
BEGIN
    SET NOCOUNT ON;
    -- 1. Encabezado de la plantilla
    SELECT PlantillaId AS id,
           PlantillaId,
           Nombre AS name,
           Nombre,
           Descripcion AS description,
           Descripcion,
           NivelRaiz AS rootLevel,
           NivelRaiz,
           TotalNodos AS totalNodes,
           TotalNodos,
           Activo AS isActive,
           Activo,
           CreadoEn AS createdAt,
           ActualizadoEn AS updatedAt
      FROM dbo.PlantillaActivo
     WHERE PlantillaId = @PlantillaId;

    -- 2. Nodos del árbol
    SELECT NodoId AS id,
           NodoId,
           PlantillaId,
           NodoPadreId AS parentNodeId,
           NodoPadreId,
           Nombre AS name,
           Nombre,
           Marca AS brand,
           Marca,
           Modelo AS model,
           Modelo,
           Nivel AS [level],
           Nivel,
           Orden AS [order],
           Orden,
           AtributosDinamicos AS dynamicAttributes,
           AtributosDinamicos,
           Observaciones AS observations,
           Observaciones
      FROM dbo.PlantillaActivoNodo
     WHERE PlantillaId = @PlantillaId
     ORDER BY Orden ASC, NodoId ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPlantillaActivoGuardarDesdeActivo
    @CodigoActivoOrigen NVARCHAR(60),
    @NombrePlantilla    NVARCHAR(150),
    @Descripcion        NVARCHAR(255) = NULL,
    @UserId             INT = NULL,
    @UserName           NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CleanName NVARCHAR(150) = LTRIM(RTRIM(@NombrePlantilla));
        IF @CleanName IS NULL OR @CleanName = N''
            RAISERROR(N'El nombre de la plantilla es obligatorio.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM dbo.Activo WHERE CodigoActivo = @CodigoActivoOrigen AND Estado <> 'deleted')
            RAISERROR(N'El activo de origen no existe.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.PlantillaActivo WHERE UPPER(Nombre) = UPPER(@CleanName) AND Activo = 1)
            RAISERROR(N'Ya existe una plantilla activa con ese nombre.', 16, 1);

        DECLARE @OrigNivelRaiz NVARCHAR(20);
        SELECT @OrigNivelRaiz = Nivel FROM dbo.Activo WHERE CodigoActivo = @CodigoActivoOrigen;

        -- 1. Crear cabecera
        INSERT INTO dbo.PlantillaActivo (Nombre, Descripcion, NivelRaiz, TotalNodos, Activo, CreadoEn, ActualizadoEn)
        VALUES (@CleanName, NULLIF(LTRIM(RTRIM(@Descripcion)), N''), @OrigNivelRaiz, 1, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

        DECLARE @NewPlantillaId INT = SCOPE_IDENTITY();

        -- 2. Insertar nodo raíz de la plantilla
        DECLARE @NodoRaizId INT;
        INSERT INTO dbo.PlantillaActivoNodo (
            PlantillaId, NodoPadreId, Nombre, Marca, Modelo, Nivel, Orden, AtributosDinamicos, Observaciones
        )
        SELECT @NewPlantillaId, NULL, Nombre, Marca, Modelo, Nivel, 1, AtributosDinamicos, Observaciones
          FROM dbo.Activo
         WHERE CodigoActivo = @CodigoActivoOrigen;

        SET @NodoRaizId = SCOPE_IDENTITY();

        -- Mapeo de CodigoActivo -> NodoId
        DECLARE @MapeoNodos TABLE (
            CodigoActivo NVARCHAR(60) COLLATE DATABASE_DEFAULT PRIMARY KEY,
            NodoId       INT NOT NULL
        );
        INSERT INTO @MapeoNodos (CodigoActivo, NodoId) VALUES (@CodigoActivoOrigen, @NodoRaizId);

        -- Tabla temporal de descendientes con COLLATE DATABASE_DEFAULT
        CREATE TABLE #DescPlantilla (
            Orden         INT IDENTITY(2,1),
            CodigoActivo  NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            PadreCodigo   NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            Nombre        NVARCHAR(200) COLLATE DATABASE_DEFAULT,
            Marca         NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Modelo        NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Nivel         NVARCHAR(20) COLLATE DATABASE_DEFAULT,
            Atributos     NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            Observaciones NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            Profundidad   INT
        );

        WITH ArbolDesc AS (
            SELECT CodigoActivo, CodigoActivoPadre, Nombre, Marca, Modelo, Nivel, AtributosDinamicos, Observaciones, 1 AS Profundidad
              FROM dbo.Activo
             WHERE CodigoActivoPadre = @CodigoActivoOrigen AND Estado <> 'deleted'
            UNION ALL
            SELECT c.CodigoActivo, c.CodigoActivoPadre, c.Nombre, c.Marca, c.Modelo, c.Nivel, c.AtributosDinamicos, c.Observaciones, a.Profundidad + 1
              FROM dbo.Activo c
              INNER JOIN ArbolDesc a ON c.CodigoActivoPadre = a.CodigoActivo
             WHERE c.Estado <> 'deleted'
        )
        INSERT INTO #DescPlantilla (CodigoActivo, PadreCodigo, Nombre, Marca, Modelo, Nivel, Atributos, Observaciones, Profundidad)
        SELECT CodigoActivo, CodigoActivoPadre, Nombre, Marca, Modelo, Nivel, AtributosDinamicos, Observaciones, Profundidad
          FROM ArbolDesc
         ORDER BY Profundidad ASC, CodigoActivo ASC;

        DECLARE @MaxDesc INT = (SELECT ISNULL(MAX(Orden), 1) FROM #DescPlantilla);
        DECLARE @curr INT = 2;
        DECLARE @TotalNodos INT = 1;

        WHILE @curr <= @MaxDesc
        BEGIN
            DECLARE @ca NVARCHAR(60), @cp NVARCHAR(60), @nm NVARCHAR(200);
            DECLARE @mc NVARCHAR(100), @md NVARCHAR(100), @nv NVARCHAR(20);
            DECLARE @at NVARCHAR(MAX), @ob NVARCHAR(MAX);

            SELECT @ca = CodigoActivo, @cp = PadreCodigo, @nm = Nombre,
                   @mc = Marca, @md = Modelo, @nv = Nivel,
                   @at = Atributos, @ob = Observaciones
              FROM #DescPlantilla
             WHERE Orden = @curr;

            DECLARE @ParentNodoId INT;
            SELECT @ParentNodoId = NodoId FROM @MapeoNodos WHERE CodigoActivo = @cp;

            IF @ParentNodoId IS NOT NULL
            BEGIN
                INSERT INTO dbo.PlantillaActivoNodo (
                    PlantillaId, NodoPadreId, Nombre, Marca, Modelo, Nivel, Orden, AtributosDinamicos, Observaciones
                )
                VALUES (
                    @NewPlantillaId, @ParentNodoId, @nm, @mc, @md, @nv, @curr, @at, @ob
                );

                DECLARE @NewNodoId INT = SCOPE_IDENTITY();
                INSERT INTO @MapeoNodos (CodigoActivo, NodoId) VALUES (@ca, @NewNodoId);
                SET @TotalNodos += 1;
            END;

            SET @curr += 1;
        END;

        DROP TABLE #DescPlantilla;

        -- Actualizar contador total en la plantilla
        UPDATE dbo.PlantillaActivo
           SET TotalNodos = @TotalNodos,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE PlantillaId = @NewPlantillaId;

        -- Auditoría Kardex
        DECLARE @AuditUser INT = @UserId;
        IF @AuditUser IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @AuditUser)
            SET @AuditUser = NULL;
        DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (
            @AuditUser, @UName, 'TEMPLATE_CREATED', 'ASSETS', CAST(@NewPlantillaId AS NVARCHAR(30)),
            CONCAT(N'Plantilla "', @CleanName, N'" guardada desde activo ', @CodigoActivoOrigen, N' con ', @TotalNodos, N' partes.')
        );

        COMMIT TRANSACTION;

        SELECT PlantillaId AS id, PlantillaId, Nombre, TotalNodos, CreadoEn
          FROM dbo.PlantillaActivo
         WHERE PlantillaId = @NewPlantillaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#DescPlantilla') IS NOT NULL DROP TABLE #DescPlantilla;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPlantillaActivoInstanciar
    @PlantillaId     INT,
    @AreaDestinoId   NVARCHAR(15),
    @NuevoNombreRaiz NVARCHAR(200) = NULL,
    @NuevoSerialRaiz NVARCHAR(100) = NULL,
    @Observaciones   NVARCHAR(MAX) = NULL,
    @CopiarAtributos BIT = 1,
    @UserId          INT = NULL,
    @UserName        NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.PlantillaActivo WHERE PlantillaId = @PlantillaId AND Activo = 1)
            RAISERROR(N'La plantilla especificada no existe o se encuentra inactiva.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @AreaDestinoId AND Activo = 1)
            RAISERROR(N'El área destino especificada no existe o se encuentra inactiva.', 16, 1);

        IF @NuevoSerialRaiz IS NOT NULL AND LTRIM(RTRIM(@NuevoSerialRaiz)) <> ''
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Activo WHERE Serie = @NuevoSerialRaiz AND Estado <> 'deleted')
                RAISERROR(N'El número de serie indicado ya está en uso por otro activo activo.', 16, 1);
        END;

        -- 1. Obtener nodo raíz de la plantilla
        DECLARE @RootNodoId INT, @RootNombre NVARCHAR(200), @RootMarca NVARCHAR(100), @RootModelo NVARCHAR(100);
        DECLARE @RootNivel NVARCHAR(20), @RootAtributos NVARCHAR(MAX), @RootObs NVARCHAR(MAX);

        SELECT @RootNodoId = NodoId,
               @RootNombre = Nombre,
               @RootMarca = Marca,
               @RootModelo = Modelo,
               @RootNivel = Nivel,
               @RootAtributos = AtributosDinamicos,
               @RootObs = Observaciones
          FROM dbo.PlantillaActivoNodo
         WHERE PlantillaId = @PlantillaId AND NodoPadreId IS NULL;

        -- 2. Generar correlativo para la nueva raíz
        DECLARE @acTable TABLE (val INT NOT NULL);
        UPDATE dbo.Area WITH (UPDLOCK, HOLDLOCK)
           SET ContadorActivos += 1
         OUTPUT inserted.ContadorActivos INTO @acTable(val)
          WHERE AreaId = @AreaDestinoId;

        DECLARE @ac INT; SELECT @ac = val FROM @acTable;
        DECLARE @NuevoCodigoRaiz NVARCHAR(60) = CONCAT(@AreaDestinoId, '-', FORMAT(@ac, '000'));

        DECLARE @NombreFinalRaiz NVARCHAR(200) = COALESCE(NULLIF(LTRIM(RTRIM(@NuevoNombreRaiz)), N''), @RootNombre);
        DECLARE @ObsFinalRaiz NVARCHAR(MAX) = COALESCE(@Observaciones, @RootObs);
        DECLARE @AtributosRaiz NVARCHAR(MAX) = CASE WHEN @CopiarAtributos = 1 THEN @RootAtributos ELSE NULL END;

        -- 3. Insertar raíz en dbo.Activo
        INSERT INTO dbo.Activo (
            CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, CodigoActivoPadre,
            Nivel, RutaAncestros, Estado, Serie, AtributosDinamicos, DatosImagen,
            Observaciones, ContadorHijos, CreadoEn
        )
        VALUES (
            @NuevoCodigoRaiz, @NombreFinalRaiz, @RootMarca, @RootModelo, @AreaDestinoId,
            '', NULL, @RootNivel, '', 'active', NULLIF(@NuevoSerialRaiz, ''),
            @AtributosRaiz, NULL, @ObsFinalRaiz, 0, SYSUTCDATETIME()
        );

        -- Tabla de mapeo NodoId -> CodigoActivo
        DECLARE @Mapeo TABLE (
            NodoId        INT PRIMARY KEY,
            CodigoActivo  NVARCHAR(60) COLLATE DATABASE_DEFAULT NOT NULL,
            RutaAncestros NVARCHAR(400) COLLATE DATABASE_DEFAULT NOT NULL
        );
        INSERT INTO @Mapeo (NodoId, CodigoActivo, RutaAncestros)
        VALUES (@RootNodoId, @NuevoCodigoRaiz, '');

        -- Tabla temporal para procesar descendientes en orden con COLLATE DATABASE_DEFAULT
        CREATE TABLE #NodosInstanciar (
            Orden         INT IDENTITY(1,1),
            NodoId        INT,
            NodoPadreId   INT,
            Nombre        NVARCHAR(200) COLLATE DATABASE_DEFAULT,
            Marca         NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Modelo        NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Nivel         NVARCHAR(20) COLLATE DATABASE_DEFAULT,
            Atributos     NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            Observaciones NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            Profundidad   INT
        );

        WITH ArbolNodos AS (
            SELECT NodoId, NodoPadreId, Nombre, Marca, Modelo, Nivel, Orden, AtributosDinamicos, Observaciones, 1 AS Profundidad
              FROM dbo.PlantillaActivoNodo
             WHERE PlantillaId = @PlantillaId AND NodoPadreId = @RootNodoId
            UNION ALL
            SELECT c.NodoId, c.NodoPadreId, c.Nombre, c.Marca, c.Modelo, c.Nivel, c.Orden, c.AtributosDinamicos, c.Observaciones, a.Profundidad + 1
              FROM dbo.PlantillaActivoNodo c
              INNER JOIN ArbolNodos a ON c.NodoPadreId = a.NodoId
             WHERE c.PlantillaId = @PlantillaId
        )
        INSERT INTO #NodosInstanciar (NodoId, NodoPadreId, Nombre, Marca, Modelo, Nivel, Atributos, Observaciones, Profundidad)
        SELECT NodoId, NodoPadreId, Nombre, Marca, Modelo, Nivel, AtributosDinamicos, Observaciones, Profundidad
          FROM ArbolNodos
         ORDER BY Profundidad ASC, Orden ASC;

        DECLARE @MaxNodos INT = (SELECT ISNULL(MAX(Orden), 0) FROM #NodosInstanciar);
        DECLARE @k INT = 1;
        DECLARE @TotalInstanciados INT = 1;

        WHILE @k <= @MaxNodos
        BEGIN
            DECLARE @nId INT, @pId INT, @nName NVARCHAR(200);
            DECLARE @nBrand NVARCHAR(100), @nModel NVARCHAR(100), @nLevel NVARCHAR(20);
            DECLARE @nAttr NVARCHAR(MAX), @nObs NVARCHAR(MAX);

            SELECT @nId = NodoId, @pId = NodoPadreId, @nName = Nombre,
                   @nBrand = Marca, @nModel = Modelo, @nLevel = Nivel,
                   @nAttr = Atributos, @nObs = Observaciones
              FROM #NodosInstanciar
             WHERE Orden = @k;

            DECLARE @PadreCode NVARCHAR(60);
            DECLARE @PadreRuta NVARCHAR(400);

            SELECT @PadreCode = CodigoActivo,
                   @PadreRuta = RutaAncestros
              FROM @Mapeo
             WHERE NodoId = @pId;

            IF @PadreCode IS NOT NULL
            BEGIN
                DECLARE @chTable TABLE (cnt INT NOT NULL);
                UPDATE dbo.Activo WITH (UPDLOCK, HOLDLOCK)
                   SET ContadorHijos += 1
                 OUTPUT inserted.ContadorHijos INTO @chTable(cnt)
                  WHERE CodigoActivo = @PadreCode;

                DECLARE @chCnt INT; SELECT @chCnt = cnt FROM @chTable;
                DELETE FROM @chTable;

                DECLARE @HijoCode NVARCHAR(60) = CONCAT(@PadreCode, '-', FORMAT(@chCnt, '00'));
                DECLARE @HijoRuta NVARCHAR(400) = CASE 
                    WHEN @PadreRuta = '' THEN @PadreCode 
                    ELSE CONCAT(@PadreRuta, '/', @PadreCode) 
                END;

                DECLARE @HijoAttr NVARCHAR(MAX) = CASE WHEN @CopiarAtributos = 1 THEN @nAttr ELSE NULL END;

                INSERT INTO dbo.Activo (
                    CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, CodigoActivoPadre,
                    Nivel, RutaAncestros, Estado, Serie, AtributosDinamicos, DatosImagen,
                    Observaciones, ContadorHijos, CreadoEn
                )
                VALUES (
                    @HijoCode, @nName, @nBrand, @nModel, @AreaDestinoId,
                    '', @PadreCode, @nLevel, @HijoRuta, 'active', NULL,
                    @HijoAttr, NULL, @nObs, 0, SYSUTCDATETIME()
                );

                INSERT INTO @Mapeo (NodoId, CodigoActivo, RutaAncestros)
                VALUES (@nId, @HijoCode, @HijoRuta);

                SET @TotalInstanciados += 1;
            END;

            SET @k += 1;
        END;

        DROP TABLE #NodosInstanciar;

        -- Auditoría e historial
        DECLARE @AuditUser INT = @UserId;
        IF @AuditUser IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @AuditUser)
            SET @AuditUser = NULL;
        DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA');

        INSERT INTO dbo.HistorialEstadoActivo (
            CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario
        )
        SELECT CodigoActivo, 'active', SYSUTCDATETIME(), @AreaDestinoId,
               CONCAT(N'Creado a partir de plantilla ID ', @PlantillaId), @AuditUser, @UName
          FROM @Mapeo;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (
            @AuditUser, @UName, 'ASSET_CREATED_FROM_TEMPLATE', 'ASSETS', @NuevoCodigoRaiz,
            CONCAT(N'Activo ', @NuevoCodigoRaiz, N' y su estructura creados a partir de plantilla ID ', 
                   @PlantillaId, N' en área ', @AreaDestinoId, N' con ', @TotalInstanciados, N' elementos.')
        );

        COMMIT TRANSACTION;

        SELECT @NuevoCodigoRaiz AS CodigoActivo,
               @NuevoCodigoRaiz AS assetCode,
               @NuevoCodigoRaiz AS id,
               @NombreFinalRaiz AS Nombre,
               @AreaDestinoId   AS AreaId,
               @TotalInstanciados AS totalNodos;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#NodosInstanciar') IS NOT NULL DROP TABLE #NodosInstanciar;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPlantillaActivoEliminar
    @PlantillaId INT,
    @UserId      INT = NULL,
    @UserName    NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.PlantillaActivo WHERE PlantillaId = @PlantillaId)
            RAISERROR(N'La plantilla no existe.', 16, 1);

        UPDATE dbo.PlantillaActivo
           SET Activo = 0,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE PlantillaId = @PlantillaId;

        SELECT 1 AS success, N'Plantilla retirada exitosamente.' AS message;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------


-- 15. PROCEDIMIENTOS ALMACENADOS: SOLICITUDES Y GESTIÓN DE BAJAS
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaCrear
    @AssetCode    NVARCHAR(60) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @Reason NVARCHAR(1000),
    @RequesterUserId INT = NULL,
    @RequesterUserName NVARCHAR(100) = N'',
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @nm NVARCHAR(200), @ar NVARCHAR(15), @st NVARCHAR(25);
        SELECT @nm = Nombre, @ar = AreaId, @st = Estado
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK) WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);

        IF @st IS NULL OR @st = 'deleted'
            RAISERROR(N'El activo no existe o ya está eliminado.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE CodigoActivo = @AssetCode AND EstadoCandado = 'pending')
            RAISERROR(N'Ya existe una solicitud de baja pendiente para este activo.', 16, 1);

        -- Validar OTs abiertas
        DECLARE @OTAbiertaId NVARCHAR(20);
        SELECT TOP 1 @OTAbiertaId = ot.OrdenTrabajoId
          FROM dbo.OrdenTrabajo ot WITH (UPDLOCK, HOLDLOCK)
          JOIN dbo.Activo a WITH (NOLOCK) ON ot.CodigoActivo = a.CodigoActivo
         WHERE a.AreaId = @ar
           AND (a.CodigoActivo = @AssetCode OR CHARINDEX(CONCAT(N',', @AssetCode, N','), CONCAT(N',', a.RutaAncestros, N',')) > 0)
           AND ot.Estado IN (N'pending', N'inProgress', N'in_progress', N'paused');

        IF @OTAbiertaId IS NOT NULL
        BEGIN
            DECLARE @MsgBaja NVARCHAR(250) = CONCAT(N'No se puede solicitar la baja: el activo o sus subcomponentes tienen la orden de trabajo abierta (', @OTAbiertaId, N'). Debe concluirse o cancelarse primero.');
            RAISERROR(@MsgBaja, 16, 1);
        END;

        INSERT INTO dbo.SolicitudBaja
            (CodigoActivo, NombreActivo, AreaId, Estado, Motivo,
             SolicitadoPorUsuarioId, SolicitadoPorNombreUsuario, SolicitadoEn)
        VALUES
            (@AssetCode, @nm, @ar, 'pending', @Reason,
             COALESCE(@RequesterUserId, @UserId), COALESCE(NULLIF(@RequesterUserName, N''), @UserName, N''), SYSUTCDATETIME());

        DECLARE @reqId BIGINT = SCOPE_IDENTITY();

        IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE CodigoActivo = @AssetCode)
            UPDATE dbo.CandadoBaja SET EstadoCandado = 'pending', ActualizadoEn = SYSUTCDATETIME() WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);
        ELSE
            INSERT INTO dbo.CandadoBaja (CodigoActivo, EstadoCandado) VALUES (@AssetCode, 'pending');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@RequesterUserId, @RequesterUserName, 'DELETION_REQUESTED', 'ASSETS', @AssetCode,
                CONCAT(N'Solicitud de baja ', @reqId, N' creada para ', @AssetCode, N' (', @nm, N'). Motivo: ', @Reason));

        COMMIT TRANSACTION;
        SELECT @reqId AS RequestId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaObtenerPendientes
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
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaObtenerTodas
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
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaObtenerPendientePorActivo
    @AssetCode NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 SolicitudId, CodigoActivo, NombreActivo, AreaId, Estado, Motivo,
           SolicitadoPorUsuarioId, SolicitadoPorNombreUsuario, SolicitadoEn,
           DecididoPorUsuarioId, DecididoPorNombreUsuario, DecididoEn, MotivoDecision
      FROM dbo.SolicitudBaja
     WHERE CodigoActivo = @AssetCode AND Estado = 'pending'
     ORDER BY SolicitadoEn DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaAprobar
    @RequestId BIGINT,
    @ApproverUserId INT = NULL,
    @ApproverUserName NVARCHAR(100) = N'',
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
            RAISERROR(N'Esta solicitud ya fue resuelta o no está pendiente.', 16, 1);

        DECLARE @OTAbiertaId NVARCHAR(20);
        SELECT TOP 1 @OTAbiertaId = ot.OrdenTrabajoId
          FROM dbo.OrdenTrabajo ot WITH (UPDLOCK, HOLDLOCK)
          JOIN dbo.Activo a WITH (NOLOCK) ON ot.CodigoActivo = a.CodigoActivo
         WHERE a.AreaId = @ar
           AND (a.CodigoActivo = @c OR CHARINDEX(CONCAT(N',', @c, N','), CONCAT(N',', a.RutaAncestros, N',')) > 0)
           AND ot.Estado IN (N'pending', N'inProgress', N'in_progress', N'paused');

        IF @OTAbiertaId IS NOT NULL
        BEGIN
            DECLARE @MsgBaja NVARCHAR(250) = CONCAT(N'No se puede dar de baja: el activo o sus subcomponentes tienen la orden de trabajo abierta (', @OTAbiertaId, N'). Debe concluirse o cancelarse primero.');
            RAISERROR(@MsgBaja, 16, 1);
        END;

        UPDATE a
           SET Estado = 'deleted',
               EliminadoEn = SYSUTCDATETIME(),
               EliminadoPorUsuarioId = @ApproverUserId,
               EliminadoPorNombreUsuario = @ApproverUserName,
               ActualizadoEn = SYSUTCDATETIME()
          FROM dbo.Activo a
         WHERE a.AreaId = @ar AND a.Estado <> 'deleted'
           AND (a.CodigoActivo = @c OR CHARINDEX(CONCAT(N',', @c, N','), CONCAT(N',', a.RutaAncestros, N',')) > 0);

        UPDATE dbo.PlanPreventivo
           SET Estado = 'paused',
               Notas = ISNULL(Notas, '') + CONCAT(CHAR(13), CHAR(10), N'[Sistema]: Plan preventivo pausado automáticamente por baja del activo.')
         WHERE CodigoActivo = @c AND Estado = 'active';

        UPDATE dbo.SolicitudBaja
           SET Estado = 'approved',
               DecididoPorUsuarioId = @ApproverUserId,
               DecididoPorNombreUsuario = @ApproverUserName,
               DecididoEn = SYSUTCDATETIME(),
               MotivoDecision = COALESCE(@ApproveReason, N'')
         WHERE SolicitudId = @RequestId;

        UPDATE dbo.CandadoBaja SET EstadoCandado = 'approved', ActualizadoEn = SYSUTCDATETIME() WHERE CodigoActivo = @c;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@ApproverUserId, @ApproverUserName, 'ASSET_DELETED', 'ASSETS', @c,
                CONCAT(N'Aprobada la solicitud de baja ', @RequestId, N' para ', @c, N' (', @nm, N'). Planes preventivos pausados.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaRechazar
    @RequestId BIGINT,
    @Reason NVARCHAR(500) = NULL,
    @RejectReason NVARCHAR(500) = NULL,
    @RejectedByUserId INT = NULL,
    @ApproverUserId INT = NULL,
    @RejectedByUserName NVARCHAR(100) = N'',
    @ApproverUserName NVARCHAR(100) = N''
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
            RAISERROR(N'Esta solicitud ya fue resuelta o no está pendiente.', 16, 1);

        UPDATE dbo.SolicitudBaja
           SET Estado = 'rejected',
               DecididoPorUsuarioId = @ApproverUserId,
               DecididoPorNombreUsuario = @ApproverUserName,
               DecididoEn = SYSUTCDATETIME(),
               MotivoDecision = @RejectReason
         WHERE SolicitudId = @RequestId;

        UPDATE dbo.CandadoBaja SET EstadoCandado = 'rejected', ActualizadoEn = SYSUTCDATETIME() WHERE CodigoActivo = @c;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@ApproverUserId, @ApproverUserName, 'DELETION_REJECTED', 'ASSETS', @c,
                CONCAT(N'Rechazada la solicitud de baja ', @RequestId, N' para ', @c, N' (', @nm, N'). Motivo: ', @RejectReason));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


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

    -- Validar que la orden de trabajo exista para evitar conflicto de clave foránea FK_RA_OrdenTrabajo
    IF NOT EXISTS (SELECT 1 FROM dbo.OrdenTrabajo WHERE OrdenTrabajoId = @WorkOrderId)
    BEGIN
        -- Si la OT no existe, salimos sin error para no interrumpir el flujo del cliente
        RETURN;
    END;

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
           ra.ImagenUrl AS BreakdownImageData
      FROM dbo.OrdenTrabajo ot
      LEFT JOIN dbo.ReporteAveria ra ON ot.ReporteId = ra.ReporteId
     WHERE ot.Estado IN ('pending', 'inProgress', 'in_progress', 'paused')
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

        SET @AssetCode = NULLIF(LTRIM(RTRIM(@AssetCode)), N'');
        SET @AreaId = NULLIF(LTRIM(RTRIM(@AreaId)), N'');
        SET @AreaName = NULLIF(LTRIM(RTRIM(@AreaName)), N'');

        -- Auto-resolución de Área si viene vacía pero viene el activo
        IF @AreaId IS NULL AND @AssetCode IS NOT NULL
        BEGIN
            SELECT @AreaId = a.AreaId,
                   @AreaName = COALESCE(@AreaName, ar.Nombre)
              FROM dbo.Activo a
              LEFT JOIN dbo.Area ar ON ar.AreaId = a.AreaId
             WHERE a.CodigoActivo = @AssetCode;
        END;

        IF @AreaName IS NULL AND @AreaId IS NOT NULL
        BEGIN
            SELECT @AreaName = Nombre FROM dbo.Area WHERE AreaId = @AreaId;
        END;

        IF @AssetCode IS NOT NULL
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

        DECLARE @year INT = YEAR(SYSUTCDATETIME());
        DECLARE @prefix NVARCHAR(10) = CONCAT('OT-', @year, '-');

        -- Obtener el número correlativo máximo real en OrdenTrabajo para el año actual
        DECLARE @maxNum INT = 0;
        SELECT @maxNum = ISNULL(MAX(
            TRY_CAST(SUBSTRING(OrdenTrabajoId, 9, 10) AS INT)
        ), 0)
        FROM dbo.OrdenTrabajo WITH (UPDLOCK, HOLDLOCK)
        WHERE OrdenTrabajoId LIKE @prefix + '%';

        DECLARE @seq INT;
        DECLARE @cCount TABLE (v INT NOT NULL);

        -- Sincronizar y avanzar Contador de forma atómica y auto-reparable
        IF NOT EXISTS (SELECT 1 FROM dbo.Contador WITH (UPDLOCK, HOLDLOCK) WHERE Nombre = 'work_orders')
        BEGIN
            SET @seq = @maxNum + 1;
            INSERT INTO dbo.Contador (Nombre, SiguienteNumero) VALUES ('work_orders', @seq + 1);
        END
        ELSE
        BEGIN
            UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
               SET SiguienteNumero = CASE 
                   WHEN SiguienteNumero <= @maxNum THEN @maxNum + 2
                   ELSE SiguienteNumero + 1
               END
             OUTPUT deleted.SiguienteNumero INTO @cCount(v)
              WHERE Nombre = 'work_orders';

            SELECT @seq = v FROM @cCount;
            IF @seq <= @maxNum
            BEGIN
                SET @seq = @maxNum + 1;
            END;
        END;

        DECLARE @woId NVARCHAR(20) = CONCAT(@prefix, FORMAT(@seq, '0000'));

        -- Bucle de seguridad anti-colisión estricto
        WHILE EXISTS (SELECT 1 FROM dbo.OrdenTrabajo WHERE OrdenTrabajoId = @woId)
        BEGIN
            SET @seq += 1;
            SET @woId = CONCAT(@prefix, FORMAT(@seq, '0000'));
            UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
               SET SiguienteNumero = @seq + 1
             WHERE Nombre = 'work_orders';
        END;

        INSERT INTO dbo.OrdenTrabajo
            (OrdenTrabajoId, CodigoActivo, NombreActivo, AreaId, NombreArea, Descripcion,
             Estado, Prioridad, AsignadoA, CantidadPersonalAsignado, HorasEstimadas,
             FechaProgramada, ReporteId, CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn)
        VALUES
            (@woId, @AssetCode, @AssetName, @AreaId, @AreaName, @Description,
             'pending', @Priority, @AssignedTo, @AssignedStaffCount, @EstimatedHours,
             @ScheduledDate, @ReportId, @CreatedByUserId, COALESCE(NULLIF(LTRIM(RTRIM(@CreatedByUserName)), N''), N'SISTEMA'), SYSUTCDATETIME());

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
        VALUES (@CreatedByUserId, COALESCE(NULLIF(LTRIM(RTRIM(@CreatedByUserName)), N''), N'SISTEMA'), 'WORK_ORDER_CREATED', 'WORK_ORDERS', @woId,
                CONCAT(N'OT creada: ', @woId, N' para ', @AssetName, N' (Prioridad: ', @Priority, N').'));

        COMMIT TRANSACTION;
        SELECT @woId AS WorkOrderId, @woId AS workOrderId, @woId AS id, @woId AS WorkOrderNumber, @woId AS workOrderNumber;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoActualizarEstado
    @WorkOrderId NVARCHAR(20),
    @NewStatus NVARCHAR(15),
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.OrdenTrabajo
           SET Estado = @NewStatus
         WHERE OrdenTrabajoId = @WorkOrderId;

        IF @NewStatus = 'completed'
        BEGIN
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
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'WORK_ORDER_STATUS_CHANGED', 'WORK_ORDERS', @WorkOrderId,
                CONCAT(N'Estado de OT ', @WorkOrderId, N' cambiado a: ', @NewStatus, N'.'));

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

        DECLARE @yearPM INT = YEAR(SYSUTCDATETIME());
        DECLARE @prefixPM NVARCHAR(10) = CONCAT('PM-', @yearPM, '-');

        DECLARE @maxNumPM INT = 0;
        SELECT @maxNumPM = ISNULL(MAX(
            TRY_CAST(SUBSTRING(PlanId, 9, 10) AS INT)
        ), 0)
        FROM dbo.PlanPreventivo WITH (UPDLOCK, HOLDLOCK)
        WHERE PlanId LIKE @prefixPM + '%';

        DECLARE @seq INT;
        DECLARE @pCount TABLE (v INT NOT NULL);

        IF NOT EXISTS (SELECT 1 FROM dbo.Contador WITH (UPDLOCK, HOLDLOCK) WHERE Nombre = 'preventive_schedules')
        BEGIN
            SET @seq = @maxNumPM + 1;
            INSERT INTO dbo.Contador (Nombre, SiguienteNumero) VALUES ('preventive_schedules', @seq + 1);
        END
        ELSE
        BEGIN
            UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
               SET SiguienteNumero = CASE 
                   WHEN SiguienteNumero <= @maxNumPM THEN @maxNumPM + 2
                   ELSE SiguienteNumero + 1
               END
             OUTPUT deleted.SiguienteNumero INTO @pCount(v)
              WHERE Nombre = 'preventive_schedules';

            SELECT @seq = v FROM @pCount;
            IF @seq <= @maxNumPM
            BEGIN
                SET @seq = @maxNumPM + 1;
            END;
        END;

        DECLARE @pId NVARCHAR(20) = CONCAT(@prefixPM, FORMAT(@seq, '0000'));

        WHILE EXISTS (SELECT 1 FROM dbo.PlanPreventivo WHERE PlanId = @pId)
        BEGIN
            SET @seq += 1;
            SET @pId = CONCAT(@prefixPM, FORMAT(@seq, '0000'));
            UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
               SET SiguienteNumero = @seq + 1
             WHERE Nombre = 'preventive_schedules';
        END;

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
        SELECT @woId AS WorkOrderId, @woId AS workOrderId, @woId AS id, @woId AS WorkOrderNumber, @woId AS workOrderNumber;
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


-- ----------------------------------------------------------------------------
-- 18. PROCEDIMIENTOS ALMACENADOS: OPERACIÓN, DISPONIBILIDAD (OEE) Y ANALÍTICA
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionRegistrar
    @CodigoActivo               NVARCHAR(60),
    @FechaOperacion             DATE,
    @HorasTotalesJornada        DECIMAL(5,2) = 24.0,
    @HorasOperacion             DECIMAL(5,2) = 0.0,
    @HorasParoFalla             DECIMAL(5,2) = 0.0,
    @HorasParoMantPrev          DECIMAL(5,2) = 0.0,
    @HorasParoMantCorr          DECIMAL(5,2) = 0.0,
    @HorasParoPlanificado       DECIMAL(5,2) = 0.0,
    @HorasParoExterno           DECIMAL(5,2) = 0.0,
    @HorasParoOtros             DECIMAL(5,2) = 0.0,
    @Observaciones              NVARCHAR(1000) = NULL,
    @Comentarios                NVARCHAR(1000) = NULL,
    @UsuarioId                  INT = NULL,
    @NombreUsuario              NVARCHAR(200) = N'',
    @RegistradoPorUsuarioId     INT = NULL,
    @RegistradoPorNombreUsuario NVARCHAR(200) = N'',
    @AreaId                     NVARCHAR(15) = NULL,
    @UnidadesProducidas         DECIMAL(12,2) = NULL,
    @UnidadesEsperadas          DECIMAL(12,2) = NULL,
    @UnidadesConformes          DECIMAL(12,2) = NULL,
    @RendimientoDirectoPct      DECIMAL(5,2) = NULL,
    @CalidadDirectoPct          DECIMAL(5,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Determinar ÁreaId con fallback seguro
        DECLARE @ResAreaId NVARCHAR(15) = @AreaId;
        IF @ResAreaId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @ResAreaId)
        BEGIN
            SELECT @ResAreaId = AreaId FROM dbo.Activo WHERE CodigoActivo = @CodigoActivo;
        END;
        IF @ResAreaId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @ResAreaId)
        BEGIN
            SELECT TOP 1 @ResAreaId = AreaId FROM dbo.Area ORDER BY AreaId ASC;
        END;

        -- Sanitizar observaciones y usuario
        DECLARE @Obs NVARCHAR(1000) = COALESCE(@Observaciones, @Comentarios);
        DECLARE @UID INT = COALESCE(@RegistradoPorUsuarioId, @UsuarioId);
        DECLARE @UName NVARCHAR(200) = COALESCE(NULLIF(LTRIM(RTRIM(@RegistradoPorNombreUsuario)), N''),
                                                NULLIF(LTRIM(RTRIM(@NombreUsuario)), N''),
                                                N'Sistema');

        -- Upsert de ReporteOperacionDiaria
        IF EXISTS (SELECT 1 FROM dbo.ReporteOperacionDiaria WHERE CodigoActivo = @CodigoActivo AND FechaOperacion = @FechaOperacion)
        BEGIN
            UPDATE dbo.ReporteOperacionDiaria
               SET AreaId                     = COALESCE(@ResAreaId, AreaId),
                   HorasTotalesJornada        = @HorasTotalesJornada,
                   HorasOperacion             = @HorasOperacion,
                   HorasParoFalla             = @HorasParoFalla,
                   HorasParoMantPrev          = @HorasParoMantPrev,
                   HorasParoMantCorr          = @HorasParoMantCorr,
                   HorasParoPlanificado       = @HorasParoPlanificado,
                   HorasParoExterno           = @HorasParoExterno,
                   Observaciones              = @Obs,
                   RegistradoPorUsuarioId     = @UID,
                   RegistradoPorNombreUsuario = @UName,
                   ActualizadoEn              = SYSUTCDATETIME()
             WHERE CodigoActivo = @CodigoActivo AND FechaOperacion = @FechaOperacion;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.ReporteOperacionDiaria
                (CodigoActivo, AreaId, FechaOperacion, HorasTotalesJornada, HorasOperacion,
                 HorasParoFalla, HorasParoMantPrev, HorasParoMantCorr, HorasParoPlanificado,
                 HorasParoExterno, Observaciones, RegistradoPorUsuarioId, RegistradoPorNombreUsuario, RegistradoEn)
            VALUES
                (@CodigoActivo, @ResAreaId, @FechaOperacion, @HorasTotalesJornada, @HorasOperacion,
                 @HorasParoFalla, @HorasParoMantPrev, @HorasParoMantCorr, @HorasParoPlanificado,
                 @HorasParoExterno, @Obs, @UID, @UName, SYSUTCDATETIME());
        END;

        COMMIT TRANSACTION;

        -- Retornar el registro persistido al cliente (requerido por API y Frontend)
        SELECT TOP 1
            r.ReporteId,
            r.CodigoActivo,
            COALESCE(a.Nombre, r.CodigoActivo) AS NombreActivo,
            r.AreaId,
            COALESCE(ar.Nombre, r.AreaId) AS NombreArea,
            r.FechaOperacion,
            r.HorasTotalesJornada,
            r.HorasOperacion,
            r.HorasParoFalla,
            r.HorasParoMantPrev,
            r.HorasParoMantCorr,
            r.HorasParoPlanificado,
            r.HorasParoExterno,
            r.Observaciones,
            CONCAT(DATEPART(YEAR, r.FechaOperacion), '-W', RIGHT('0' + CAST(DATEPART(ISO_WEEK, r.FechaOperacion) AS VARCHAR(2)), 2)) AS SemanaISO,
            r.RegistradoPorUsuarioId,
            r.RegistradoPorNombreUsuario,
            r.RegistradoEn,
            r.ActualizadoEn,
            CAST(ROUND(CASE WHEN r.HorasTotalesJornada > 0 THEN (r.HorasOperacion / r.HorasTotalesJornada) * 100.0 ELSE 0.0 END, 2) AS DECIMAL(5,2)) AS DisponibilidadPct
        FROM dbo.ReporteOperacionDiaria r
        LEFT JOIN dbo.Activo a ON a.CodigoActivo = r.CodigoActivo
        LEFT JOIN dbo.Area ar ON ar.AreaId = r.AreaId
        WHERE r.CodigoActivo = @CodigoActivo AND r.FechaOperacion = @FechaOperacion;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionObtenerPorActivo
    @CodigoActivo       NVARCHAR(60),
    @FechaDesde         DATE = NULL,
    @FechaHasta         DATE = NULL,
    @FechaInicio        DATE = NULL,
    @FechaFin           DATE = NULL,
    @Pagina             INT = 1,
    @RegistrosPorPagina INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATE = COALESCE(@FechaDesde, @FechaInicio, DATEADD(MONTH, -1, CAST(SYSUTCDATETIME() AS DATE)));
    DECLARE @Fin DATE = COALESCE(@FechaHasta, @FechaFin, CAST(SYSUTCDATETIME() AS DATE));
    DECLARE @Offset INT = CASE WHEN @Pagina > 1 THEN (@Pagina - 1) * @RegistrosPorPagina ELSE 0 END;

    SELECT ReporteId, CodigoActivo, AreaId, FechaOperacion, HorasTotalesJornada,
           HorasOperacion, HorasParoFalla, HorasParoMantPrev, HorasParoMantCorr,
           HorasParoPlanificado, HorasParoExterno, Observaciones,
           RegistradoPorUsuarioId, RegistradoPorNombreUsuario, RegistradoEn, ActualizadoEn
      FROM dbo.ReporteOperacionDiaria
     WHERE CodigoActivo = @CodigoActivo
       AND FechaOperacion BETWEEN @Inicio AND @Fin
     ORDER BY FechaOperacion DESC
     OFFSET @Offset ROWS
     FETCH NEXT @RegistrosPorPagina ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionObtenerPorSemana
    @AreaId          NVARCHAR(15),
    @LunesDeLaSemana DATE = NULL,
    @FechaInicio     DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @BaseDate DATE = COALESCE(@LunesDeLaSemana, @FechaInicio, CAST(SYSUTCDATETIME() AS DATE));
    DECLARE @Lunes DATE = DATEADD(DAY, - (DATEPART(WEEKDAY, @BaseDate) + 5) % 7, @BaseDate);
    DECLARE @Domingo DATE = DATEADD(DAY, 6, @Lunes);

    SELECT r.ReporteId,
           r.CodigoActivo,
           COALESCE(a.Nombre, r.CodigoActivo) AS NombreActivo,
           r.AreaId,
           COALESCE(ar.Nombre, r.AreaId) AS NombreArea,
           r.FechaOperacion,
           r.HorasTotalesJornada,
           r.HorasOperacion,
           r.HorasParoFalla,
           r.HorasParoMantPrev,
           r.HorasParoMantCorr,
           r.HorasParoPlanificado,
           r.HorasParoExterno,
           r.Observaciones,
           CONCAT(DATEPART(YEAR, r.FechaOperacion), '-W', RIGHT('0' + CAST(DATEPART(ISO_WEEK, r.FechaOperacion) AS VARCHAR(2)), 2)) AS SemanaISO,
           r.RegistradoPorUsuarioId,
           r.RegistradoPorNombreUsuario,
           r.RegistradoEn,
           r.ActualizadoEn,
           CAST(ROUND(CASE WHEN r.HorasTotalesJornada > 0 THEN (r.HorasOperacion / r.HorasTotalesJornada) * 100.0 ELSE 0.0 END, 2) AS DECIMAL(5,2)) AS DisponibilidadPct
      FROM dbo.ReporteOperacionDiaria r
      LEFT JOIN dbo.Activo a ON r.CodigoActivo = a.CodigoActivo
      LEFT JOIN dbo.Area ar ON r.AreaId = ar.AreaId
     WHERE (@AreaId IS NULL OR r.AreaId = @AreaId)
       AND r.FechaOperacion BETWEEN @Lunes AND @Domingo
     ORDER BY r.FechaOperacion DESC, r.CodigoActivo ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionMetricas
    @CodigoActivo NVARCHAR(60) = NULL,
    @AreaId       NVARCHAR(15) = NULL,
    @FechaDesde   DATE = NULL,
    @FechaHasta   DATE = NULL,
    @FechaInicio  DATE = NULL,
    @FechaFin     DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATE = COALESCE(@FechaDesde, @FechaInicio, DATEADD(DAY, -30, CAST(SYSUTCDATETIME() AS DATE)));
    DECLARE @Fin DATE = COALESCE(@FechaHasta, @FechaFin, CAST(SYSUTCDATETIME() AS DATE));

    SELECT
        COUNT(1)                                    AS DiasConReporte,
        @CodigoActivo                               AS CodigoActivo,
        @Inicio                                     AS FechaDesde,
        @Fin                                        AS FechaHasta,
        COUNT(DISTINCT r.CodigoActivo)              AS TotalEquiposMonitoreados,
        COALESCE(SUM(r.HorasTotalesJornada), 0.00)  AS TotalHorasJornada,
        COALESCE(SUM(r.HorasOperacion), 0.00)       AS TotalHorasOperacion,
        COALESCE(SUM(r.HorasParoFalla), 0.00)       AS TotalParoFalla,
        COALESCE(SUM(r.HorasParoMantPrev), 0.00)    AS TotalParoMantPrev,
        COALESCE(SUM(r.HorasParoMantCorr), 0.00)    AS TotalParoMantCorr,
        COALESCE(SUM(r.HorasParoPlanificado), 0.00) AS TotalParoPlanificado,
        COALESCE(SUM(r.HorasParoExterno), 0.00)     AS TotalParoExterno,
        -- Aliases de compatibilidad adicional
        COALESCE(SUM(r.HorasParoMantPrev), 0.00)    AS TotalHorasParoPreventivo,
        COALESCE(SUM(r.HorasParoMantCorr), 0.00)    AS TotalHorasParoCorrectivo,
        CASE WHEN SUM(r.HorasTotalesJornada) > 0
             THEN ROUND((SUM(r.HorasOperacion) / SUM(r.HorasTotalesJornada)) * 100.0, 2)
             ELSE 0.00 END AS DisponibilidadPct,
        CASE WHEN SUM(r.HorasTotalesJornada) > 0
             THEN ROUND((SUM(r.HorasOperacion) / SUM(r.HorasTotalesJornada)) * 100.0, 2)
             ELSE 0.00 END AS PorcentajeDisponibilidadGlobal,
        -- MTBF: Horas de operación / eventos de falla
        CASE WHEN SUM(CASE WHEN r.HorasParoFalla > 0 THEN 1 ELSE 0 END) > 0
             THEN ROUND(SUM(r.HorasOperacion) / NULLIF(SUM(CASE WHEN r.HorasParoFalla > 0 THEN 1 ELSE 0 END), 0), 2)
             ELSE NULL END AS MTBF_Horas,
        -- MTTR: Horas de paro por falla / eventos de falla
        CASE WHEN SUM(CASE WHEN r.HorasParoFalla > 0 THEN 1 ELSE 0 END) > 0
             THEN ROUND(SUM(r.HorasParoFalla) / NULLIF(SUM(CASE WHEN r.HorasParoFalla > 0 THEN 1 ELSE 0 END), 0), 2)
             ELSE NULL END AS MTTR_Horas
      FROM dbo.ReporteOperacionDiaria r
     WHERE (@CodigoActivo IS NULL OR r.CodigoActivo = @CodigoActivo)
       AND (@AreaId IS NULL OR r.AreaId = @AreaId)
       AND r.FechaOperacion BETWEEN @Inicio AND @Fin;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteHistorialActivo
    @CodigoActivo NVARCHAR(60),
    @FechaDesde DATETIME2(3) = NULL,
    @FechaHasta DATETIME2(3) = NULL,
    @IncluirHijos BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    -- 1. Historial de Estado
    SELECT HistorialId, CodigoActivo, Estado, IniciadoEn, FinalizadoEn, AreaId, Motivo, NombreUsuario
      FROM dbo.HistorialEstadoActivo
     WHERE CodigoActivo = @CodigoActivo
       AND (@FechaDesde IS NULL OR IniciadoEn >= @FechaDesde)
       AND (@FechaHasta IS NULL OR IniciadoEn <= @FechaHasta)
     ORDER BY IniciadoEn DESC;

    -- 2. Reportes de Avería
    SELECT ReporteId, AreaId, Descripcion, Severidad, ReportadoEn, Estado, OrdenTrabajoId, ReportadoPorNombreUsuario
      FROM dbo.ReporteAveria
     WHERE CodigoActivo = @CodigoActivo
       AND (@FechaDesde IS NULL OR ReportadoEn >= @FechaDesde)
       AND (@FechaHasta IS NULL OR ReportadoEn <= @FechaHasta)
     ORDER BY ReportadoEn DESC;

    -- 3. Órdenes de Trabajo
    SELECT OrdenTrabajoId, Descripcion, Estado, Prioridad, AsignadoA, HorasReales, FechaProgramada, CreadoEn
      FROM dbo.OrdenTrabajo
     WHERE CodigoActivo = @CodigoActivo
       AND (@FechaDesde IS NULL OR CreadoEn >= @FechaDesde)
       AND (@FechaHasta IS NULL OR CreadoEn <= @FechaHasta)
     ORDER BY CreadoEn DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteEstacionalidadAverias
    @AreaId NVARCHAR(15) = NULL,
    @Anio INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TargetYear INT = COALESCE(@Anio, YEAR(SYSUTCDATETIME()));

    SELECT
        MONTH(ReportadoEn) AS Mes,
        DATENAME(MONTH, ReportadoEn) AS NombreMes,
        COUNT(*) AS TotalAverias,
        SUM(CASE WHEN Severidad = 'critical' THEN 1 ELSE 0 END) AS Criticas,
        SUM(CASE WHEN Severidad = 'high' THEN 1 ELSE 0 END) AS Altas,
        SUM(CASE WHEN Severidad = 'medium' THEN 1 ELSE 0 END) AS Medias,
        SUM(CASE WHEN Severidad = 'low' THEN 1 ELSE 0 END) AS Bajas
    FROM dbo.ReporteAveria
    WHERE YEAR(ReportadoEn) = @TargetYear
      AND (@AreaId IS NULL OR AreaId = @AreaId)
    GROUP BY MONTH(ReportadoEn), DATENAME(MONTH, ReportadoEn)
    ORDER BY Mes ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteTopEquiposFallas
    @AreaId NVARCHAR(15) = NULL,
    @FechaDesde DATETIME2(3) = NULL,
    @FechaHasta DATETIME2(3) = NULL,
    @Top INT = 10,
    @TopCount INT = NULL,
    @DiasAtras INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LimitTop INT = COALESCE(@Top, @TopCount, 10);
    DECLARE @Desde DATETIME2(3) = COALESCE(@FechaDesde, CASE WHEN @DiasAtras IS NOT NULL THEN DATEADD(DAY, -@DiasAtras, SYSUTCDATETIME()) ELSE DATEADD(DAY, -90, SYSUTCDATETIME()) END);

    SELECT TOP (@LimitTop)
        ra.CodigoActivo,
        ra.NombreActivo,
        ar.Nombre AS NombreArea,
        COUNT(*) AS TotalAverias,
        SUM(CASE WHEN ra.Severidad IN ('high', 'critical') THEN 1 ELSE 0 END) AS AveriasGraves
    FROM dbo.ReporteAveria ra
    JOIN dbo.Area ar ON ra.AreaId = ar.AreaId
    WHERE ra.ReportadoEn >= @Desde
      AND (@FechaHasta IS NULL OR ra.ReportadoEn <= @FechaHasta)
      AND (@AreaId IS NULL OR ra.AreaId = @AreaId)
    GROUP BY ra.CodigoActivo, ra.NombreActivo, ar.Nombre
    ORDER BY TotalAverias DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteConsumoRepuestos
    @AreaId NVARCHAR(15) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @FechaDesde DATETIME2(3) = NULL,
    @FechaHasta DATETIME2(3) = NULL,
    @Top INT = 20,
    @FechaInicio DATETIME2(3) = NULL,
    @FechaFin DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME2(3) = COALESCE(@FechaDesde, @FechaInicio, DATEADD(MONTH, -1, SYSUTCDATETIME()));
    DECLARE @Fin DATETIME2(3) = COALESCE(@FechaHasta, @FechaFin, SYSUTCDATETIME());
    DECLARE @LimitTop INT = COALESCE(@Top, 20);

    SELECT TOP (@LimitTop)
        mot.Descripcion AS RepuestoMaterial,
        mot.Unidad,
        SUM(mot.Cantidad) AS TotalConsumido,
        COUNT(DISTINCT mot.OrdenTrabajoId) AS TotalOrdenesInvolucradas
    FROM dbo.MaterialOrdenTrabajo mot
    JOIN dbo.OrdenTrabajo ot ON mot.OrdenTrabajoId = ot.OrdenTrabajoId
    WHERE ot.CreadoEn BETWEEN @Inicio AND @Fin
      AND (@AreaId IS NULL OR ot.AreaId = @AreaId)
      AND (@CodigoActivo IS NULL OR ot.CodigoActivo = @CodigoActivo)
    GROUP BY mot.Descripcion, mot.Unidad
    ORDER BY TotalConsumido DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteOEEGeneral
    @AreaId NVARCHAR(15) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @FechaDesde DATE = NULL,
    @FechaHasta DATE = NULL,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATE = COALESCE(@FechaDesde, @FechaInicio, DATEADD(MONTH, -1, CAST(SYSUTCDATETIME() AS DATE)));
    DECLARE @Fin DATE = COALESCE(@FechaHasta, @FechaFin, CAST(SYSUTCDATETIME() AS DATE));

    SELECT
        r.AreaId,
        ar.Nombre AS NombreArea,
        SUM(r.HorasTotalesJornada) AS HorasTotales,
        SUM(r.HorasOperacion) AS HorasOperativas,
        SUM(r.HorasParoFalla) AS ParosPorFalla,
        SUM(r.HorasParoMantPrev) AS ParosPreventivos,
        CASE WHEN SUM(r.HorasTotalesJornada) > 0
             THEN ROUND((SUM(r.HorasOperacion) / SUM(r.HorasTotalesJornada)) * 100.0, 2)
             ELSE 0.00 END AS DisponibilidadPorcentaje
    FROM dbo.ReporteOperacionDiaria r
    JOIN dbo.Area ar ON r.AreaId = ar.AreaId
    WHERE r.FechaOperacion BETWEEN @Inicio AND @Fin
      AND (@AreaId IS NULL OR r.AreaId = @AreaId)
      AND (@CodigoActivo IS NULL OR r.CodigoActivo = @CodigoActivo)
    GROUP BY r.AreaId, ar.Nombre
    ORDER BY DisponibilidadPorcentaje ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspKardexAgregar
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N'',
    @Action NVARCHAR(40),
    @Module NVARCHAR(30),
    @EntityId NVARCHAR(60),
    @Details NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
    VALUES (@UserId, @UserName, @Action, @Module, @EntityId, @Details);
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspKardexObtenerTodos
    @ModuleFilter NVARCHAR(30) = NULL,
    @ActionFilter NVARCHAR(40) = NULL,
    @UserFilter INT = NULL,
    @StartDate DATETIME2(3) = NULL,
    @EndDate DATETIME2(3) = NULL,
    @Limit INT = 200,
    @Offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        BitacoraId AS LogId,
        RegistradoEn AS LoggedAt,
        UsuarioId AS UserId,
        NombreUsuario AS UserName,
        Accion AS [Action],
        Modulo AS [Module],
        EntidadId,
        Detalles AS Details,
        BitacoraId,
        RegistradoEn,
        UsuarioId,
        NombreUsuario,
        Accion,
        Modulo,
        Detalles
      FROM dbo.BitacoraKardex
     WHERE (@ModuleFilter IS NULL OR Modulo = @ModuleFilter)
       AND (@ActionFilter IS NULL OR Accion = @ActionFilter)
       AND (@UserFilter IS NULL OR UsuarioId = @UserFilter)
       AND (@StartDate IS NULL OR RegistradoEn >= @StartDate)
       AND (@EndDate IS NULL OR RegistradoEn <= @EndDate)
     ORDER BY RegistradoEn DESC
     OFFSET @Offset ROWS
     FETCH NEXT CASE WHEN @Limit IS NULL OR @Limit <= 0 THEN 2147483647 ELSE @Limit END ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspKardexObtenerPorEntidad
    @EntityId NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        BitacoraId AS LogId,
        RegistradoEn AS LoggedAt,
        UsuarioId AS UserId,
        NombreUsuario AS UserName,
        Accion AS [Action],
        Modulo AS [Module],
        EntidadId,
        Detalles AS Details,
        BitacoraId,
        RegistradoEn,
        UsuarioId,
        NombreUsuario,
        Accion,
        Modulo,
        Detalles
      FROM dbo.BitacoraKardex
     WHERE EntidadId = @EntityId
     ORDER BY RegistradoEn DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspDashboardObtenerEstadisticas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM dbo.Activo         WHERE Estado = 'active')                      AS ActiveAssets,
        (SELECT COUNT(*) FROM dbo.Activo         WHERE Estado <> 'deleted')                    AS TotalAssets,
        (SELECT COUNT(*) FROM dbo.ReporteAveria  WHERE Estado IN ('reported', 'inWorkOrder'))  AS PendingBreakdowns,
        (SELECT COUNT(*) FROM dbo.OrdenTrabajo   WHERE Estado IN ('pending', 'inProgress'))    AS OpenWorkOrders,
        (SELECT COUNT(*) FROM dbo.OrdenTrabajo   WHERE Estado = 'completed')                   AS CompletedWorkOrders,
        (SELECT COUNT(*) FROM dbo.PlanPreventivo WHERE Estado = 'active')                      AS ActivePreventiveSchedules,
        (SELECT COUNT(*) FROM dbo.BitacoraKardex)                                              AS TotalKardexLogs;
END;
GO

-- ----------------------------------------------------------------------------
-- MÉTRICAS DE MANTENIMIENTO POR CENTRO DE COSTO Y TIPO
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspReporteMantenimientosPorCentroCosto
    @FechaInicio              DATETIME2(3) = NULL,
    @FechaFin                 DATETIME2(3) = NULL,
    @SoloConMantenimiento     BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH OTMantenimiento AS (
        SELECT 
            ot.OrdenTrabajoId,
            ot.AreaId,
            ot.Estado,
            ot.HorasReales,
            ot.HorasEstimadas,
            ot.CreadoEn,
            CASE 
                WHEN ot.PlanPreventivoId IS NOT NULL OR tt.EsPreventivo = 1 THEN 'preventive'
                WHEN ot.ReporteId IS NOT NULL OR tt.EsCorrectivo = 1 THEN 'corrective'
                ELSE COALESCE(tt.PrimerTipo, 'other')
            END AS TipoMantenimientoPrincipal,
            ISNULL(tt.EsCorrectivo, CASE WHEN ot.ReporteId IS NOT NULL THEN 1 ELSE 0 END) AS EsCorrectivo,
            ISNULL(tt.EsPreventivo, CASE WHEN ot.PlanPreventivoId IS NOT NULL THEN 1 ELSE 0 END) AS EsPreventivo,
            ISNULL(tt.EsPredictivo, 0) AS EsPredictivo,
            ISNULL(tt.EsMejora, 0) AS EsMejora,
            ISNULL(tt.EsOtro, 0) AS EsOtro
        FROM dbo.OrdenTrabajo ot
        OUTER APPLY (
            SELECT 
                MAX(CASE WHEN LOWER(TipoTrabajo) LIKE '%correctiv%' THEN 1 ELSE 0 END) AS EsCorrectivo,
                MAX(CASE WHEN LOWER(TipoTrabajo) LIKE '%preventiv%' THEN 1 ELSE 0 END) AS EsPreventivo,
                MAX(CASE WHEN LOWER(TipoTrabajo) LIKE '%predictiv%' THEN 1 ELSE 0 END) AS EsPredictivo,
                MAX(CASE WHEN LOWER(TipoTrabajo) LIKE '%mejor%' OR LOWER(TipoTrabajo) LIKE '%improvement%' THEN 1 ELSE 0 END) AS EsMejora,
                MAX(CASE WHEN LOWER(TipoTrabajo) NOT LIKE '%correctiv%' AND LOWER(TipoTrabajo) NOT LIKE '%preventiv%' THEN 1 ELSE 0 END) AS EsOtro,
                MIN(TipoTrabajo) AS PrimerTipo
            FROM dbo.TipoTrabajoOrdenTrabajo
            WHERE OrdenTrabajoId = ot.OrdenTrabajoId
        ) tt
        WHERE (@FechaInicio IS NULL OR ot.CreadoEn >= @FechaInicio)
          AND (@FechaFin IS NULL OR ot.CreadoEn <= @FechaFin)
    )
    SELECT 
        ar.CentroCosto                                                          AS costCenter,
        ar.CentroCosto,
        ar.AreaId                                                               AS areaId,
        ar.AreaId,
        ar.Nombre                                                               AS areaName,
        ar.Nombre,
        COUNT(m.OrdenTrabajoId)                                                 AS totalMaintenance,
        COUNT(m.OrdenTrabajoId)                                                 AS TotalMantenimientos,
        SUM(CASE WHEN m.Estado = 'completed' THEN 1 ELSE 0 END)                 AS completed,
        SUM(CASE WHEN m.Estado = 'completed' THEN 1 ELSE 0 END)                 AS Completados,
        SUM(CASE WHEN m.Estado IN ('pending', 'inProgress', 'in_progress', 'paused') THEN 1 ELSE 0 END) AS inProgress,
        SUM(CASE WHEN m.Estado IN ('pending', 'inProgress', 'in_progress', 'paused') THEN 1 ELSE 0 END) AS EnProceso,
        SUM(CASE WHEN m.Estado = 'cancelled' THEN 1 ELSE 0 END)                 AS cancelled,
        SUM(CASE WHEN m.Estado = 'cancelled' THEN 1 ELSE 0 END)                 AS Canceladas,
        SUM(CASE WHEN m.EsCorrectivo = 1 THEN 1 ELSE 0 END)                     AS corrective,
        SUM(CASE WHEN m.EsCorrectivo = 1 THEN 1 ELSE 0 END)                     AS Correctivos,
        SUM(CASE WHEN m.EsPreventivo = 1 THEN 1 ELSE 0 END)                     AS preventive,
        SUM(CASE WHEN m.EsPreventivo = 1 THEN 1 ELSE 0 END)                     AS Preventivos,
        SUM(CASE WHEN m.EsPredictivo = 1 THEN 1 ELSE 0 END)                     AS predictive,
        SUM(CASE WHEN m.EsPredictivo = 1 THEN 1 ELSE 0 END)                     AS Predictivos,
        SUM(CASE WHEN m.EsMejora = 1 THEN 1 ELSE 0 END)                         AS improvement,
        SUM(CASE WHEN m.EsMejora = 1 THEN 1 ELSE 0 END)                         AS Mejoras,
        SUM(CASE WHEN (m.EsOtro = 1 AND m.EsCorrectivo = 0 AND m.EsPreventivo = 0) THEN 1 ELSE 0 END) AS otherTypes,
        SUM(CASE WHEN (m.EsOtro = 1 AND m.EsCorrectivo = 0 AND m.EsPreventivo = 0) THEN 1 ELSE 0 END) AS OtrosTipos,
        CAST(ISNULL(SUM(m.HorasReales), 0) AS DECIMAL(10, 2))                   AS totalRealHours,
        CAST(ISNULL(SUM(m.HorasReales), 0) AS DECIMAL(10, 2))                   AS HorasRealesTotales,
        CAST(ISNULL(SUM(m.HorasEstimadas), 0) AS DECIMAL(10, 2))                AS totalEstimatedHours
    FROM dbo.Area ar
    LEFT JOIN OTMantenimiento m ON m.AreaId = ar.AreaId
    WHERE (@SoloConMantenimiento = 0 OR m.OrdenTrabajoId IS NOT NULL)
    GROUP BY ar.CentroCosto, ar.AreaId, ar.Nombre
    ORDER BY TotalMantenimientos DESC, ar.CentroCosto ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteMantenimientosPorCentroCostoDetalle
    @CentroCosto              NVARCHAR(50) = NULL,
    @AreaId                   NVARCHAR(15) = NULL,
    @FechaInicio              DATETIME2(3) = NULL,
    @FechaFin                 DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        ot.OrdenTrabajoId                                      AS workOrderId,
        ot.OrdenTrabajoId,
        ot.CodigoActivo                                        AS assetCode,
        ot.CodigoActivo,
        ot.NombreActivo                                        AS assetName,
        ot.NombreActivo,
        ar.AreaId                                              AS areaId,
        ar.AreaId,
        ar.Nombre                                              AS areaName,
        ar.Nombre                                              AS NombreArea,
        ar.CentroCosto                                         AS costCenter,
        ar.CentroCosto,
        ot.Descripcion                                         AS description,
        ot.Descripcion,
        ot.Estado                                              AS status,
        ot.Estado,
        ot.Prioridad                                           AS priority,
        ot.Prioridad,
        ot.AsignadoA                                           AS assignedTo,
        ot.AsignadoA,
        ot.HorasEstimadas                                      AS estimatedHours,
        ot.HorasReales                                         AS actualHours,
        ot.CreadoEn                                            AS createdAt,
        ot.CreadoEn,
        ot.FechaProgramada                                     AS scheduledDate,
        ot.ReporteId                                           AS reportId,
        ot.PlanPreventivoId                                    AS preventiveScheduleId,
        CASE 
            WHEN ot.PlanPreventivoId IS NOT NULL OR tt.EsPreventivo = 1 THEN 'preventive'
            WHEN ot.ReporteId IS NOT NULL OR tt.EsCorrectivo = 1 THEN 'corrective'
            ELSE COALESCE(tt.PrimerTipo, 'other')
        END AS mainMaintenanceType,
        tt.TiposTrabajoConcatenados AS workTypesText
    FROM dbo.OrdenTrabajo ot
    INNER JOIN dbo.Area ar ON ar.AreaId = ot.AreaId
    OUTER APPLY (
        SELECT 
            MAX(CASE WHEN LOWER(TipoTrabajo) LIKE '%correctiv%' THEN 1 ELSE 0 END) AS EsCorrectivo,
            MAX(CASE WHEN LOWER(TipoTrabajo) LIKE '%preventiv%' THEN 1 ELSE 0 END) AS EsPreventivo,
            MIN(TipoTrabajo) AS PrimerTipo,
            STRING_AGG(TipoTrabajo, ', ') AS TiposTrabajoConcatenados
        FROM dbo.TipoTrabajoOrdenTrabajo
        WHERE OrdenTrabajoId = ot.OrdenTrabajoId
    ) tt
    WHERE (@CentroCosto IS NULL OR UPPER(LTRIM(RTRIM(ar.CentroCosto))) = UPPER(LTRIM(RTRIM(@CentroCosto))))
      AND (@AreaId IS NULL OR ar.AreaId = @AreaId)
      AND (@FechaInicio IS NULL OR ot.CreadoEn >= @FechaInicio)
      AND (@FechaFin IS NULL OR ot.CreadoEn <= @FechaFin)
    ORDER BY ot.CreadoEn DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActualizacionAndroidObtener
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 IdApp, VersionApp, Fecha, Obligatorio, CreadoEn
      FROM dbo.ActualizacionesAndroid
     ORDER BY IdApp DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActualizacionAndroidRegistrar
    @VersionApp NVARCHAR(50),
    @Obligatorio BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.ActualizacionesAndroid (VersionApp, Obligatorio, CreadoEn)
    VALUES (@VersionApp, @Obligatorio, SYSUTCDATETIME());
    SELECT SCOPE_IDENTITY() AS IdApp;
END;
GO

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


-- ----------------------------------------------------------------------------
-- 19. SEGURIDAD Y CONCESIÓN DE PERMISOS PARA LA API (macsa_app)
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'macsa_app')
BEGIN
    CREATE USER [macsa_app] FOR LOGIN [macsa_app];
    PRINT N'Usuario de base de datos macsa_app creado.';
END;
GO

GRANT EXECUTE ON SCHEMA::dbo TO [macsa_app];
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [macsa_app];
GO

PRINT N'Permisos de ejecución y acceso a datos concedidos a macsa_app.';
GO

-- ----------------------------------------------------------------------------
-- 20. SIEMBRA DE DATOS OFICIALES PARA PRODUCCIÓN
-- ----------------------------------------------------------------------------
PRINT N'============================================================================';
PRINT N'Iniciando siembra de datos maestros de producción...';
PRINT N'============================================================================';
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- 20.1 Catálogo de Roles (5 Roles Jerárquicos)
    INSERT INTO dbo.Rol (CodigoRol, Nombre)
    VALUES
        (N'admin',      N'Administrador General'),
        (N'jefe',       N'Jefe de Mantenimiento'),
        (N'jefe_area',  N'Jefe de Área / Operaciones'),
        (N'reportador', N'Supervisor (Reportador)'),
        (N'lector',     N'Gerente (Solo Lectura / Auditoría)');

    -- 20.2 Catálogo de Permisos Granulares (20 Permisos)
    INSERT INTO dbo.Permiso (CodigoPermiso)
    VALUES
        (N'dashboard.view'),
        (N'asset.view'),
        (N'asset.create'),
        (N'asset.edit'),
        (N'asset.transfer'),
        (N'asset.delete.request'),
        (N'asset.delete.approve'),
        (N'work_order.view'),
        (N'work_order.create'),
        (N'work_order.print'),
        (N'preventive.view'),
        (N'preventive.manage'),
        (N'breakdown.report'),
        (N'breakdown.view'),
        (N'breakdown.manage'),
        (N'operation_report.view'),
        (N'operation_report.edit'),
        (N'kardex.view'),
        (N'user.manage'),
        (N'employee.manage');

    -- 20.3 Matriz de Permisos por Rol (dbo.RolPermiso)
    -- admin: Acceso Total
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
    SELECT N'admin', CodigoPermiso FROM dbo.Permiso;

    -- jefe: Gestión Técnica Completa (excepto user.manage y asset.delete.approve)
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
    VALUES
        (N'jefe', N'dashboard.view'),
        (N'jefe', N'asset.view'),
        (N'jefe', N'asset.create'),
        (N'jefe', N'asset.edit'),
        (N'jefe', N'asset.transfer'),
        (N'jefe', N'asset.delete.request'),
        (N'jefe', N'work_order.view'),
        (N'jefe', N'work_order.create'),
        (N'jefe', N'work_order.print'),
        (N'jefe', N'preventive.view'),
        (N'jefe', N'preventive.manage'),
        (N'jefe', N'breakdown.report'),
        (N'jefe', N'breakdown.view'),
        (N'jefe', N'breakdown.manage'),
        (N'jefe', N'operation_report.view'),
        (N'jefe', N'operation_report.edit'),
        (N'jefe', N'kardex.view'),
        (N'jefe', N'employee.manage');

    -- jefe_area: Operaciones y Supervisión Local
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
    VALUES
        (N'jefe_area', N'dashboard.view'),
        (N'jefe_area', N'asset.view'),
        (N'jefe_area', N'work_order.view'),
        (N'jefe_area', N'work_order.print'),
        (N'jefe_area', N'preventive.view'),
        (N'jefe_area', N'breakdown.report'),
        (N'jefe_area', N'breakdown.view'),
        (N'jefe_area', N'operation_report.view'),
        (N'jefe_area', N'operation_report.edit');

    -- reportador: Reporte y Seguimiento de Fallas
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
    VALUES
        (N'reportador', N'breakdown.report'),
        (N'reportador', N'breakdown.view');

    -- lector: Solo Lectura, Reportes y Auditoría
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
    VALUES
        (N'lector', N'dashboard.view'),
        (N'lector', N'asset.view'),
        (N'lector', N'work_order.view'),
        (N'lector', N'work_order.print'),
        (N'lector', N'preventive.view'),
        (N'lector', N'kardex.view'),
        (N'lector', N'breakdown.view'),
        (N'lector', N'operation_report.view');

    -- 20.4 Las 30 Áreas Oficiales de Grupo Macsa
    INSERT INTO dbo.Area (AreaId, Nombre, CentroCosto, ContadorActivos, Activo, CreadoEn)
    VALUES 
        ('A001', N'ADMINISTRACION',                 'CC-37', 0, 1, SYSUTCDATETIME()),
        ('A002', N'AREA DE DESPACHO',               'CC-38', 0, 1, SYSUTCDATETIME()),
        ('A003', N'EMPAQUE - MASTERIZADO',          'CC-39', 0, 1, SYSUTCDATETIME()),
        ('A004', N'CAFETERIA',                      'CC-40', 0, 1, SYSUTCDATETIME()),
        ('A005', N'CLASIFICADO',                    'CC-41', 0, 1, SYSUTCDATETIME()),
        ('A006', N'COCINADO',                       'CC-42', 0, 1, SYSUTCDATETIME()),
        ('A007', N'CONTABILIDAD',                   'CC-43', 0, 1, SYSUTCDATETIME()),
        ('A008', N'DESCABEZADO',                    'CC-44', 0, 1, SYSUTCDATETIME()),
        ('A009', N'EMPAQUE BLOCK',                  'CC-45', 0, 1, SYSUTCDATETIME()),
        ('A010', N'EMPAQUE IQF',                    'CC-46', 0, 1, SYSUTCDATETIME()),
        ('A011', N'GERENCIA',                       'CC-47', 0, 1, SYSUTCDATETIME()),
        ('A012', N'IMPORT & EXPORT',                'CC-48', 0, 1, SYSUTCDATETIME()),
        ('A013', N'INOCUIDAD',                      'CC-49', 0, 1, SYSUTCDATETIME()),
        ('A014', N'RECEPCION',                      'CC-50', 0, 1, SYSUTCDATETIME()),
        ('A015', N'LABORATORIO',                    'CC-51', 0, 1, SYSUTCDATETIME()),
        ('A016', N'LAVANDERIA',                     'CC-52', 0, 1, SYSUTCDATETIME()),
        ('A017', N'MANTENIMIENTO',                  'CC-53', 0, 1, SYSUTCDATETIME()),
        ('A018', N'PLANTA DE HIELO',                'CC-54', 0, 1, SYSUTCDATETIME()),
        ('A019', N'POES',                           'CC-55', 0, 1, SYSUTCDATETIME()),
        ('A020', N'AREA ENVIO-PRODUCTO TERMINADO',  'CC-56', 0, 1, SYSUTCDATETIME()),
        ('A021', N'RECEPCION PLANTA',               'CC-57', 0, 1, SYSUTCDATETIME()),
        ('A022', N'RECURSOS HUMANOS',               'CC-58', 0, 1, SYSUTCDATETIME()),
        ('A023', N'SALMUERA',                       'CC-59', 0, 1, SYSUTCDATETIME()),
        ('A024', N'SALUD & SEGURIDAD OCUPACIONAL',  'CC-60', 0, 1, SYSUTCDATETIME()),
        ('A025', N'TIC''S',                         'CC-61', 0, 1, SYSUTCDATETIME()),
        ('A026', N'VIGILANCIA',                     'CC-62', 0, 1, SYSUTCDATETIME()),
        ('A027', N'PELADO',                         'CC-63', 0, 1, SYSUTCDATETIME()),
        ('A028', N'TRATAMIENTO-PELADO',             'CC-64', 0, 1, SYSUTCDATETIME()),
        ('A029', N'LIMPIEZA -EXTERIORES',           'CC-65', 0, 1, SYSUTCDATETIME()),
        ('A030', N'PRODUCCION',                     'CC-98', 0, 1, SYSUTCDATETIME());

    -- 20.5 Contadores Transaccionales
    INSERT INTO dbo.Contador (Nombre, SiguienteNumero)
    VALUES
        ('areas', 31),
        ('work_orders', 1),
        ('preventive_schedules', 1);

    -- 20.6 Catálogo Inicial de Puestos / Cargos
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
    VALUES
        (N'Desarrollador',                        0, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Jefe de Mantenimiento',                1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Supervisor de Mantenimiento',          1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Técnico Mecánico Industrial',          1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Técnico Electricista / Automatización', 1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Técnico en Refrigeración y Calderas',  1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Técnico Electromecánico',              1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Técnico Soldador / Estructuras',       1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Auxiliar de Mantenimiento',            1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Jefe de Área / Operaciones',           0, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Supervisor de Producción',             0, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Gerente General',                      0, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Gerente de Operaciones',               0, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

    -- 20.6.1 Catálogo Inicial de Unidades de Medida
    IF NOT EXISTS (SELECT 1 FROM dbo.UnidadMedida)
    BEGIN
        INSERT INTO dbo.UnidadMedida (Codigo, Nombre, Activo, CreadoEn, ActualizadoEn)
        VALUES
            (N'kW',    N'Kilovatios',                  1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'HP',    N'Caballos de fuerza',          1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'V',     N'Voltios',                     1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'A',     N'Amperios',                    1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'PSI',   N'Libras por pulgada cuadrada', 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'bar',   N'Bar',                         1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'RPM',   N'Revoluciones por minuto',     1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Hz',    N'Hertz',                       1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'°C',    N'Grados Celsius',              1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'°F',    N'Grados Fahrenheit',           1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'BTU/h', N'BTU por hora',                1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'TR',    N'Toneladas de refrigeración',  1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'CFM',   N'Pies cúbicos por minuto',     1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'm³/h',  N'Metros cúbicos por hora',     1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'GPM',   N'Galones por minuto',          1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'L',     N'Litros',                      1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'kg',    N'Kilogramos',                  1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'lb',    N'Libras',                      1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'm',     N'Metros',                      1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'mm',    N'Milímetros',                  1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'pulg',  N'Pulgadas',                    1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'kVA',   N'Kilovoltiamperios',           1, SYSUTCDATETIME(), SYSUTCDATETIME());
    END;

    -- 20.6.2 Catálogo Inicial de Atributos Técnicos
    IF NOT EXISTS (SELECT 1 FROM dbo.AtributoCatalogo)
    BEGIN
        DECLARE @uKW INT  = (SELECT TOP 1 UnidadMedidaId FROM dbo.UnidadMedida WHERE Codigo = N'kW');
        DECLARE @uV  INT  = (SELECT TOP 1 UnidadMedidaId FROM dbo.UnidadMedida WHERE Codigo = N'V');
        DECLARE @uA  INT  = (SELECT TOP 1 UnidadMedidaId FROM dbo.UnidadMedida WHERE Codigo = N'A');
        DECLARE @uHz INT  = (SELECT TOP 1 UnidadMedidaId FROM dbo.UnidadMedida WHERE Codigo = N'Hz');
        DECLARE @uPSI INT = (SELECT TOP 1 UnidadMedidaId FROM dbo.UnidadMedida WHERE Codigo = N'PSI');
        DECLARE @uBTU INT = (SELECT TOP 1 UnidadMedidaId FROM dbo.UnidadMedida WHERE Codigo = N'BTU/h');
        DECLARE @uRPM INT = (SELECT TOP 1 UnidadMedidaId FROM dbo.UnidadMedida WHERE Codigo = N'RPM');
        DECLARE @uC   INT = (SELECT TOP 1 UnidadMedidaId FROM dbo.UnidadMedida WHERE Codigo = N'°C');
        DECLARE @uCFM INT = (SELECT TOP 1 UnidadMedidaId FROM dbo.UnidadMedida WHERE Codigo = N'CFM');
        DECLARE @uKG  INT = (SELECT TOP 1 UnidadMedidaId FROM dbo.UnidadMedida WHERE Codigo = N'kg');

        INSERT INTO dbo.AtributoCatalogo (Nombre, Descripcion, UnidadMedidaIdDefecto, Activo, CreadoEn, ActualizadoEn)
        VALUES
            (N'Potencia',                    N'Potencia nominal del activo o motor',                  @uKW,  1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Voltaje',                     N'Tensión eléctrica de operación',                       @uV,   1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Corriente / Amperaje',        N'Consumo de corriente nominal',                         @uA,   1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Frecuencia',                  N'Frecuencia eléctrica nominal',                         @uHz,  1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Presión de Trabajo',          N'Presión operativa o de descarga',                      @uPSI, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Capacidad Térmica',           N'Capacidad de enfriamiento / calefacción',              @uBTU, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Velocidad de Giro',           N'Velocidad angular de rotación',                        @uRPM, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Temperatura Máxima',          N'Límite térmico admisible',                             @uC,   1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Caudal de Aire / Fluido',     N'Flujo volumétrico nominal',                            @uCFM, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Peso',                        N'Peso neto del equipo',                                 @uKG,  1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Tipo de Refrigerante',        N'Gas refrigerante utilizado (R-410A, R-134a, R-22...)', NULL,  1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Tipo de Lubricante / Aceite', N'Aceite o grasa recomendada para mantenimiento',        NULL,  1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Número de Fases',             N'Monofásico (1F), Bifásico (2F) o Trifásico (3F)',      NULL,  1, SYSUTCDATETIME(), SYSUTCDATETIME());
    END;

    -- 20.6.3 Catálogo de Marcas Inicial
    IF NOT EXISTS (SELECT 1 FROM dbo.Marca)
    BEGIN
        INSERT INTO dbo.Marca (Nombre, Descripcion, Activo, CreadoEn, ActualizadoEn)
        VALUES
            (N'Siemens',              N'Equipos eléctricos, automatización, motores y variadores', 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'ABB',                  N'Robótica, potencia, motores y accionamientos industriales', 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Schneider Electric',   N'Tableros eléctricos, arrancadores y protecciones', 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Danfoss',              N'Compresores, variadores de frecuencia y válvulas', 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Caterpillar',          N'Generadores y motores diésel industriales', 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Baldor',               N'Motores eléctricos industriales y reductores', 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'WEG',                  N'Motores eléctricos, arrancadores y transformadores', 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'York',                 N'Chillers, compresores y sistemas de refrigeración', 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Carrier',              N'Sistemas de climatización y cuartos fríos', 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Hobart',               N'Maquinaria de corte, empaque y procesamiento', 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Mettler Toledo',       N'Básculas industriales, pesadoras y celdas de carga', 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Festo',                N'Componentes y actuadores neumáticos industriales', 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'SEW-Eurodrive',        N'Motorreductores y variadores mecánicos', 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Ingersoll Rand',       N'Compresores de aire y bombas industriales', 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
            (N'Graco',                N'Bombas y sistemas de lubricación/fluido industrial', 1, SYSUTCDATETIME(), SYSUTCDATETIME());
    END;

    -- 20.7 Empleado Administrador Oficial: Nixon Manuel Mendez Galo
    DECLARE @PuestoDevId INT;
    SELECT @PuestoDevId = PuestoId FROM dbo.Puesto WHERE Nombre = N'Desarrollador';

    INSERT INTO dbo.Empleado
        (NombreCompleto, PuestoId, Puesto, AreaId, NombreArea, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
    VALUES
        (N'Nixon Manuel Mendez Galo', @PuestoDevId, N'Desarrollador', 'A025', N'TIC''S', 0, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

    DECLARE @AdminEmpleadoId INT = SCOPE_IDENTITY();

    -- 20.8 Usuario Administrador Oficial: NMENDEZ (Contraseña: ADMIN123)
    -- Hash PBKDF2-HMAC-SHA256 con 20.000 iteraciones verificado
    INSERT INTO dbo.Usuario (
        NombreUsuario, NombreCompleto, CodigoRol, EmpleadoId,
        PasswordSalt, PasswordHash, IteracionesPassword,
        Deshabilitado, DebeCambiarPassword, SolicitudReinicioPassword,
        IntentosFallidos, BloqueadoHasta, CreadoEn
    )
    VALUES (
        N'NMENDEZ',
        N'Nixon Manuel Mendez Galo',
        N'admin',
        @AdminEmpleadoId,
        N'W434BLHgQkv2WatVO1Hzlw==',
        N'QdrlzoourSpIVUo3ngYVav0mKo4VfQFvlja40iuXbAU=',
        20000,
        0, 0, 0,
        0, NULL, SYSUTCDATETIME()
    );

    DECLARE @AdminUserId INT = SCOPE_IDENTITY();

    -- 20.9 Asignar Todos los Permisos al Administrador
    INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
    SELECT @AdminUserId, CodigoPermiso FROM dbo.Permiso;

    -- 20.10 Registro Inicial de Auditoría en Bitácora Kardex
    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
    VALUES (
        @AdminUserId,
        N'NMENDEZ',
        'SYSTEM_INITIALIZED',
        'USERS',
        'MacsaCMMS',
        N'Inicialización oficial de base de datos en producción. 30 Áreas Oficiales sembradas, esquema relacional desplegado y Administrador General NMENDEZ registrado.'
    );

    COMMIT TRANSACTION;
    PRINT N'============================================================================';
    PRINT N'¡DESPLIEGUE A PRODUCCIÓN COMPLETADO CON ÉXITO!';
    PRINT N'30 Áreas Oficiales creadas (A001 a A030).';
    PRINT N'13 Puestos de catálogo registrados.';
    PRINT N'Empleado Nixon Manuel Mendez Galo registrado en TIC''S.';
    PRINT N'Usuario Administrador NMENDEZ activo con acceso total.';
    PRINT N'Base de datos limpia de datos de prueba, lista para operación real.';
    PRINT N'============================================================================';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'Error durante la inicialización de datos de producción:';
    THROW;
END CATCH;
GO


