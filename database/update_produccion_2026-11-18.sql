-- ============================================================================
-- MACSA CMMS - SCRIPT CONSOLIDADO DE ACTUALIZACIÓN A PRODUCCIÓN
-- Fecha: 2026-11-18
--
-- Este script es 100% IDEMPOTENTE y seguro de ejecutar en la base de datos de producción.
-- Contiene:
--   1. Catálogo de Atributos Técnicos y Unidades de Medida (con tildes corregidas)
--   2. Campo Observaciones opcional en activos
--   3. Tablas para Plantillas de Activos (PlantillaActivo y PlantillaActivoNodo)
--   4. Catálogo y tabla de Marcas (dbo.Marca)
--   5. Procedimientos de clonación e instanciación de plantillas (sin conflicto de collation)
--   6. Procedimiento de traspaso de activos (sin conflicto de collation)
--   7. Edición de N° de serie en equipos con unicidad y auditoría en Bitácora Kardex
--   8. Métricas de mantenimientos por Centro de Costo (Dashboard)
--   9. Correcciones en alternar estado y creación de OT desde averías
--  10. Permisos de ejecución para macsa_app
-- ============================================================================

USE [MacsaCMMS];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'>> Iniciando actualización integral de MacsaCMMS (2026-11-18)...';
GO

-- ----------------------------------------------------------------------------
-- 1. TABLA dbo.UnidadMedida
-- ----------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.UnidadMedida', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.UnidadMedida (
        UnidadMedidaId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_UnidadMedida PRIMARY KEY,
        Codigo         NVARCHAR(20) NOT NULL CONSTRAINT UQ_UnidadMedida_Codigo UNIQUE,
        Nombre         NVARCHAR(100) NOT NULL,
        Activo         BIT NOT NULL CONSTRAINT DF_UnidadMedida_Activo DEFAULT (1),
        CreadoEn       DATETIME2(3) NOT NULL CONSTRAINT DF_UnidadMedida_CreadoEn DEFAULT (SYSUTCDATETIME()),
        ActualizadoEn  DATETIME2(3) NOT NULL CONSTRAINT DF_UnidadMedida_ActualizadoEn DEFAULT (SYSUTCDATETIME())
    );

    CREATE NONCLUSTERED INDEX IX_UnidadMedida_Activo_Codigo
        ON dbo.UnidadMedida (Activo, Codigo);

    PRINT N'  - Tabla dbo.UnidadMedida creada.';
END
GO

-- ----------------------------------------------------------------------------
-- 2. TABLA dbo.AtributoCatalogo
-- ----------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.AtributoCatalogo', N'U') IS NULL
BEGIN
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

    CREATE NONCLUSTERED INDEX IX_AtributoCatalogo_Activo_Nombre
        ON dbo.AtributoCatalogo (Activo, Nombre);

    PRINT N'  - Tabla dbo.AtributoCatalogo creada.';
END
GO

-- Sembrado / Corrección de caracteres en Unidades de Medida
MERGE INTO dbo.UnidadMedida AS Target
USING (VALUES
    (N'V',     N'Voltios'),
    (N'A',     N'Amperios'),
    (N'kW',    N'Kilovatios'),
    (N'HP',    N'Caballos de fuerza'),
    (N'RPM',   N'Revoluciones por minuto'),
    (N'PSI',   N'Libras por pulgada cuadrada'),
    (N'bar',   N'Bares'),
    (N'°C',    N'Grados Celsius'),
    (N'°F',    N'Grados Fahrenheit'),
    (N'Hz',    N'Hercios'),
    (N'BTU/h', N'BTU por hora'),
    (N'TR',    N'Toneladas de refrigeración'),
    (N'CFM',   N'Pies cúbicos por minuto'),
    (N'm³/h',  N'Metros cúbicos por hora'),
    (N'GPM',   N'Galones por minuto'),
    (N'L',     N'Litros'),
    (N'kg',    N'Kilogramos'),
    (N'lb',    N'Libras'),
    (N'm',     N'Metros'),
    (N'mm',    N'Milímetros'),
    (N'pulg',  N'Pulgadas'),
    (N'kVA',   N'Kilovoltiamperios')
) AS Source (Codigo, Nombre)
ON Target.Codigo = Source.Codigo
WHEN MATCHED THEN
    UPDATE SET Target.Nombre = Source.Nombre, Target.Activo = 1, Target.ActualizadoEn = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (Codigo, Nombre, Activo) VALUES (Source.Codigo, Source.Nombre, 1);
GO

-- Sembrado / Corrección de caracteres en Atributos Técnicos
MERGE INTO dbo.AtributoCatalogo AS Target
USING (
    SELECT s.Nombre, s.Descripcion, u.UnidadMedidaId
    FROM (VALUES
        (N'Potencia',               N'Potencia nominal del activo o motor',               N'kW'),
        (N'Voltaje de Operación',   N'Tensión eléctrica nominal de alimentación',         N'V'),
        (N'Corriente / Amperaje',   N'Consumo de corriente nominal',                      N'A'),
        (N'Velocidad de Giro',      N'Velocidad nominal de rotación',                     N'RPM'),
        (N'Presión de Trabajo',     N'Presión nominal operativa de diseño',               N'PSI'),
        (N'Temperatura Máxima',     N'Límite térmico operativo recomendado',              N'°C'),
        (N'Caudal de Aire / Fluido',N'Flujo volumétrico nominal',                         N'CFM'),
        (N'Capacidad Térmica',      N'Capacidad de enfriamiento / calefacción',           N'BTU/h'),
        (N'Frecuencia',             N'Frecuencia eléctrica nominal',                      N'Hz'),
        (N'Número de Fases',        N'Monofásico (1F), Bifásico (2F) o Trifásico (3F)',   NULL),
        (N'Peso',                   N'Peso neto del equipo',                              N'kg')
    ) AS s (Nombre, Descripcion, UnidadCodigo)
    LEFT JOIN dbo.UnidadMedida u ON u.Codigo = s.UnidadCodigo
) AS Source
ON Target.Nombre = Source.Nombre
WHEN MATCHED THEN
    UPDATE SET Target.Descripcion = Source.Descripcion, Target.UnidadMedidaIdDefecto = Source.UnidadMedidaId, Target.Activo = 1, Target.ActualizadoEn = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (Nombre, Descripcion, UnidadMedidaIdDefecto, Activo) VALUES (Source.Nombre, Source.Descripcion, Source.UnidadMedidaId, 1);
GO

-- ----------------------------------------------------------------------------
-- 3. CAMPO Observaciones EN dbo.Activo
-- ----------------------------------------------------------------------------
IF COL_LENGTH(N'dbo.Activo', N'Observaciones') IS NULL
BEGIN
    ALTER TABLE dbo.Activo ADD Observaciones NVARCHAR(MAX) NULL;
    PRINT N'  - Columna Observaciones agregada a dbo.Activo.';
END
GO

-- ----------------------------------------------------------------------------
-- 4. TABLAS DE PLANTILLAS: dbo.PlantillaActivo y dbo.PlantillaActivoNodo
-- ----------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.PlantillaActivo', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PlantillaActivo (
        PlantillaId   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PlantillaActivo PRIMARY KEY,
        Nombre        NVARCHAR(150) NOT NULL CONSTRAINT UQ_PlantillaActivo_Nombre UNIQUE,
        Descripcion   NVARCHAR(255) NULL,
        NivelRaiz     NVARCHAR(20) NOT NULL CONSTRAINT DF_PlantillaActivo_NivelRaiz DEFAULT ('equipment'),
        TotalNodos    INT NOT NULL CONSTRAINT DF_PlantillaActivo_TotalNodos DEFAULT (1),
        Activo        BIT NOT NULL CONSTRAINT DF_PlantillaActivo_Activo DEFAULT (1),
        CreadoEn      DATETIME2(3) NOT NULL CONSTRAINT DF_PlantillaActivo_CreadoEn DEFAULT (SYSUTCDATETIME()),
        ActualizadoEn DATETIME2(3) NOT NULL CONSTRAINT DF_PlantillaActivo_ActualizadoEn DEFAULT (SYSUTCDATETIME())
    );
    PRINT N'  - Tabla dbo.PlantillaActivo creada.';
END
GO

IF OBJECT_ID(N'dbo.PlantillaActivoNodo', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PlantillaActivoNodo (
        NodoId            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PlantillaActivoNodo PRIMARY KEY,
        PlantillaId       INT NOT NULL CONSTRAINT FK_PlantillaActivoNodo_Plantilla FOREIGN KEY REFERENCES dbo.PlantillaActivo(PlantillaId) ON DELETE CASCADE,
        NodoPadreId       INT NULL CONSTRAINT FK_PlantillaActivoNodo_Padre FOREIGN KEY REFERENCES dbo.PlantillaActivoNodo(NodoId),
        Nombre            NVARCHAR(200) NOT NULL,
        Marca             NVARCHAR(100) NULL,
        Modelo            NVARCHAR(100) NULL,
        Nivel             NVARCHAR(20) NOT NULL,
        Orden             INT NOT NULL CONSTRAINT DF_PlantillaActivoNodo_Orden DEFAULT (1),
        AtributosDinamicos NVARCHAR(MAX) NULL,
        Observaciones     NVARCHAR(MAX) NULL,
        CreadoEn          DATETIME2(3) NOT NULL CONSTRAINT DF_PlantillaActivoNodo_CreadoEn DEFAULT (SYSUTCDATETIME())
    );
    CREATE NONCLUSTERED INDEX IX_PlantillaActivoNodo_PlantillaId ON dbo.PlantillaActivoNodo (PlantillaId, NodoPadreId);
    PRINT N'  - Tabla dbo.PlantillaActivoNodo creada.';
END
GO

-- ----------------------------------------------------------------------------
-- 5. TABLA dbo.Marca
-- ----------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.Marca', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Marca (
        MarcaId       INT           IDENTITY(1,1) NOT NULL,
        Nombre        NVARCHAR(100) NOT NULL,
        Descripcion   NVARCHAR(250) NULL,
        Activo        BIT           NOT NULL CONSTRAINT DF_Marca_Activo DEFAULT (1),
        CreadoEn      DATETIME2(3)  NOT NULL CONSTRAINT DF_Marca_CreadoEn DEFAULT (SYSUTCDATETIME()),
        ActualizadoEn DATETIME2(3)  NOT NULL CONSTRAINT DF_Marca_ActualizadoEn DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_Marca PRIMARY KEY CLUSTERED (MarcaId),
        CONSTRAINT UQ_Marca_Nombre UNIQUE NONCLUSTERED (Nombre)
    );
    PRINT N'  - Tabla dbo.Marca creada.';
END
GO

-- Sembrado inicial de Marcas
INSERT INTO dbo.Marca (Nombre, Descripcion)
SELECT DISTINCT LTRIM(RTRIM(a.Marca)), N'Marca registrada previamente en activos'
  FROM dbo.Activo a
 WHERE a.Marca IS NOT NULL 
   AND LTRIM(RTRIM(a.Marca)) <> ''
   AND NOT EXISTS (SELECT 1 FROM dbo.Marca m WHERE UPPER(m.Nombre) = UPPER(LTRIM(RTRIM(a.Marca))));
GO

MERGE INTO dbo.Marca AS Target
USING (VALUES
    (N'Siemens',       N'Automatización industrial y motores'),
    (N'Schneider',     N'Equipos eléctricos y arrancadores'),
    (N'ABB',           N'Robótica, variadores y motores'),
    (N'WEG',           N'Motores eléctricos y generadores'),
    (N'Danfoss',       N'Variadores de frecuencia y refrigeración'),
    (N'Festo',         N'Neumática y automatización'),
    (N'SMC',           N'Componentes neumáticos industriales'),
    (N'SKF',           N'Rodamientos y sistemas de lubricación'),
    (N'Sew Eurodrive', N'Motorreductores y transmisión'),
    (N'Allen-Bradley', N'PLCs y control industrial Rockwell'),
    (N'Mitsubishi',    N'Automatización y servomotores'),
    (N'Omron',         N'Sensores, relevadores y visión'),
    (N'Caterpillar',   N'Generadores y maquinaria pesada'),
    (N'Ingersoll Rand',N'Compresores de aire industrial'),
    (N'Atlas Copco',   N'Compresores y generadores de nitrógeno')
) AS Source (Nombre, Descripcion)
ON UPPER(Target.Nombre) = UPPER(Source.Nombre)
WHEN NOT MATCHED THEN
    INSERT (Nombre, Descripcion, Activo) VALUES (Source.Nombre, Source.Descripcion, 1);
GO

-- ----------------------------------------------------------------------------
-- 6. SINCRONIZACIÓN DE CONTADORES (PREVENCIÓN DE CLAVE DUPLICADA PK_OrdenTrabajo)
-- ----------------------------------------------------------------------------
DECLARE @realMaxOT INT = 0;
SELECT @realMaxOT = ISNULL(MAX(TRY_CAST(SUBSTRING(OrdenTrabajoId, 9, 10) AS INT)), 0)
  FROM dbo.OrdenTrabajo
 WHERE OrdenTrabajoId LIKE CONCAT('OT-', YEAR(SYSUTCDATETIME()), '-%');

IF NOT EXISTS (SELECT 1 FROM dbo.Contador WHERE Nombre = 'work_orders')
BEGIN
    INSERT INTO dbo.Contador (Nombre, SiguienteNumero) VALUES ('work_orders', @realMaxOT + 1);
END
ELSE
BEGIN
    UPDATE dbo.Contador
       SET SiguienteNumero = CASE WHEN SiguienteNumero <= @realMaxOT THEN @realMaxOT + 1 ELSE SiguienteNumero END
     WHERE Nombre = 'work_orders';
END;

DECLARE @realMaxPM INT = 0;
SELECT @realMaxPM = ISNULL(MAX(TRY_CAST(SUBSTRING(PlanId, 9, 10) AS INT)), 0)
  FROM dbo.PlanPreventivo
 WHERE PlanId LIKE CONCAT('PM-', YEAR(SYSUTCDATETIME()), '-%');

IF NOT EXISTS (SELECT 1 FROM dbo.Contador WHERE Nombre = 'preventive_schedules')
BEGIN
    INSERT INTO dbo.Contador (Nombre, SiguienteNumero) VALUES ('preventive_schedules', @realMaxPM + 1);
END
ELSE
BEGIN
    UPDATE dbo.Contador
       SET SiguienteNumero = CASE WHEN SiguienteNumero <= @realMaxPM THEN @realMaxPM + 1 ELSE SiguienteNumero END
     WHERE Nombre = 'preventive_schedules';
END;
PRINT N'  - Contadores transaccionales sincronizados correctamente con los datos existentes.';
GO

PRINT N'>> Tablas y datos de catálogo listos. Procediendo a actualizar procedimientos almacenados...';
GO

-- ============================================================================
-- PROCEDIMIENTO: uspCatalogosObtener
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspAtributoCatalogoListar
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspAtributoCatalogoCrear
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspAtributoCatalogoActualizar
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspAtributoCatalogoEliminar
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspUnidadMedidaListar
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
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

-- ============================================================================
-- PROCEDIMIENTO: uspUnidadMedidaCrear
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspUnidadMedidaActualizar
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspUnidadMedidaEliminar
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspMarcaListar
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
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

-- ============================================================================
-- PROCEDIMIENTO: uspMarcaCrear
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspMarcaActualizar
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspMarcaEliminar
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspReporteMantenimientosPorCentroCosto
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
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

-- ============================================================================
-- PROCEDIMIENTO: uspReporteMantenimientosPorCentroCostoDetalle
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspActivoCrear
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspActivoActualizar
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspActivoAlternarEstado
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspActivoTraspasar
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspActivoClonarArbol
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
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

-- ============================================================================
-- PROCEDIMIENTO: uspPlantillaActivoGuardarDesdeActivo
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspPlantillaActivoListar
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
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

-- ============================================================================
-- PROCEDIMIENTO: uspPlantillaActivoObtenerDetalle
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspPlantillaActivoInstanciar
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspPlantillaActivoEliminar
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspOrdenTrabajoCrear
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspPlanPreventivoCrear
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ============================================================================
-- PROCEDIMIENTO: uspReporteAveriaVincularOrdenTrabajo
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

-- ----------------------------------------------------------------------------
-- PERMISOS PARA macsa_app
-- ----------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'macsa_app')
BEGIN
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.UnidadMedida TO [macsa_app];
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.AtributoCatalogo TO [macsa_app];
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.PlantillaActivo TO [macsa_app];
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.PlantillaActivoNodo TO [macsa_app];
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Marca TO [macsa_app];

    GRANT EXECUTE ON dbo.uspCatalogosObtener TO [macsa_app];
    GRANT EXECUTE ON dbo.uspAtributoCatalogoListar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspAtributoCatalogoCrear TO [macsa_app];
    GRANT EXECUTE ON dbo.uspAtributoCatalogoActualizar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspAtributoCatalogoEliminar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspUnidadMedidaListar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspUnidadMedidaCrear TO [macsa_app];
    GRANT EXECUTE ON dbo.uspUnidadMedidaActualizar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspUnidadMedidaEliminar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspMarcaListar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspMarcaCrear TO [macsa_app];
    GRANT EXECUTE ON dbo.uspMarcaActualizar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspMarcaEliminar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspReporteMantenimientosPorCentroCosto TO [macsa_app];
    GRANT EXECUTE ON dbo.uspReporteMantenimientosPorCentroCostoDetalle TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoCrear TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoActualizar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoAlternarEstado TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoTraspasar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoClonarArbol TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlantillaActivoGuardarDesdeActivo TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlantillaActivoListar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlantillaActivoObtenerDetalle TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlantillaActivoInstanciar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlantillaActivoEliminar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspOrdenTrabajoCrear TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlanPreventivoCrear TO [macsa_app];
    GRANT EXECUTE ON dbo.uspReporteAveriaVincularOrdenTrabajo TO [macsa_app];

    PRINT N'  - Permisos otorgados exitosamente a macsa_app.';
END
GO

PRINT N'>> ACTUALIZACIÓN COMPLETADA CON ÉXITO.';
GO
