-- ============================================================================
-- MACSA CMMS - PARCHE: CATÁLOGO DINÁMICO DE ATRIBUTOS Y UNIDADES DE MEDIDA
-- Fecha: 2026-11-15 (Actualizado con corrección integral de tildes y caracteres especiales)
--
-- Contenido:
-- 1. Tablas dbo.UnidadMedida y dbo.AtributoCatalogo con integridad referencial.
-- 2. Población / Corrección idempotente con tildes y caracteres especiales (UTF-8 con BOM).
-- 3. Procedimientos almacenados para CRUD seguro con control de integridad referencial.
-- 4. Actualización de dbo.uspCatalogosObtener para incluir atributos y unidades.
-- 5. Concesión de permisos al usuario/rol macsa_app.
-- ============================================================================

USE [MacsaCMMS];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'Iniciando aplicación del parche de atributos y unidades 2026-11-15 (con soporte completo de tildes)...';
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

    PRINT N'Tabla dbo.UnidadMedida creada exitosamente.';
END;
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

    PRINT N'Tabla dbo.AtributoCatalogo creada exitosamente.';
END;
GO

-- ----------------------------------------------------------------------------
-- 3. POBLACIÓN Y CORRECCIÓN IDEMPOTENTE DE UNIDADES DE MEDIDA (Tildes y Símbolos)
-- ----------------------------------------------------------------------------
-- Reparar códigos y nombres distorsionados por lecturas ANSI previas (Â°C, mÂ³/h, etc.)
UPDATE dbo.UnidadMedida
   SET Codigo = N'°C', Nombre = N'Grados Celsius'
 WHERE Codigo IN (N'°C', N'Â°C') OR Nombre LIKE N'Grados Celsius%';

UPDATE dbo.UnidadMedida
   SET Codigo = N'°F', Nombre = N'Grados Fahrenheit'
 WHERE Codigo IN (N'°F', N'Â°F') OR Nombre LIKE N'Grados Fahrenheit%';

UPDATE dbo.UnidadMedida
   SET Codigo = N'm³/h', Nombre = N'Metros cúbicos por hora'
 WHERE Codigo IN (N'm³/h', N'mÂ³/h') OR Codigo LIKE N'm%3/h%' OR Nombre LIKE N'Metros c%bicos por hora%';

-- Upsert de las 22 unidades de medida con nombres exactos en español
MERGE dbo.UnidadMedida AS Target
USING (VALUES
    (N'kW',    N'Kilovatios'),
    (N'HP',    N'Caballos de fuerza'),
    (N'V',     N'Voltios'),
    (N'A',     N'Amperios'),
    (N'PSI',   N'Libras por pulgada cuadrada'),
    (N'bar',   N'Bar'),
    (N'RPM',   N'Revoluciones por minuto'),
    (N'Hz',    N'Hertz'),
    (N'°C',    N'Grados Celsius'),
    (N'°F',    N'Grados Fahrenheit'),
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
    UPDATE SET Target.Nombre = Source.Nombre,
               Target.Activo = 1,
               Target.ActualizadoEn = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (Codigo, Nombre, Activo, CreadoEn, ActualizadoEn)
    VALUES (Source.Codigo, Source.Nombre, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

PRINT N'Catálogo dbo.UnidadMedida sincronizado y corregido con tildes.';
GO

-- ----------------------------------------------------------------------------
-- 4. POBLACIÓN Y CORRECCIÓN IDEMPOTENTE DE ATRIBUTOS (Tildes y Descripciones)
-- ----------------------------------------------------------------------------
-- Normalizar nombres con caracteres distorsionados que pudieran existir
UPDATE dbo.AtributoCatalogo SET Nombre = N'Presión de Trabajo' WHERE Nombre IN (N'PresiÃ³n de Trabajo', N'Presión de Trabajo') OR Nombre LIKE N'Presi%n de Trabajo%';
UPDATE dbo.AtributoCatalogo SET Nombre = N'Capacidad Térmica' WHERE Nombre IN (N'Capacidad TÃ©rmica', N'Capacidad Térmica') OR Nombre LIKE N'Capacidad T%rmica%';
UPDATE dbo.AtributoCatalogo SET Nombre = N'Temperatura Máxima' WHERE Nombre IN (N'Temperatura MÃ¡xima', N'Temperatura Máxima') OR Nombre LIKE N'Temperatura M%xima%';
UPDATE dbo.AtributoCatalogo SET Nombre = N'Número de Fases' WHERE Nombre IN (N'NÃºmero de Fases', N'Número de Fases') OR Nombre LIKE N'N%mero de Fases%';

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

MERGE dbo.AtributoCatalogo AS Target
USING (VALUES
    (N'Potencia',                    N'Potencia nominal del activo o motor',                        @uKW),
    (N'Voltaje',                     N'Tensión eléctrica de operación',                             @uV),
    (N'Corriente / Amperaje',        N'Consumo de corriente nominal',                               @uA),
    (N'Frecuencia',                  N'Frecuencia eléctrica nominal',                               @uHz),
    (N'Presión de Trabajo',          N'Presión operativa o de descarga',                            @uPSI),
    (N'Capacidad Térmica',           N'Capacidad de enfriamiento / calefacción',                    @uBTU),
    (N'Velocidad de Giro',           N'Velocidad angular de rotación',                              @uRPM),
    (N'Temperatura Máxima',          N'Límite térmico admisible',                                   @uC),
    (N'Caudal de Aire / Fluido',     N'Flujo volumétrico nominal',                                  @uCFM),
    (N'Peso',                        N'Peso neto del equipo',                                       @uKG),
    (N'Tipo de Refrigerante',        N'Gas refrigerante utilizado (R-410A, R-134a, R-22...)',       NULL),
    (N'Tipo de Lubricante / Aceite', N'Aceite o grasa recomendada para mantenimiento',              NULL),
    (N'Número de Fases',             N'Monofásico (1F), Bifásico (2F) o Trifásico (3F)',            NULL)
) AS Source (Nombre, Descripcion, UnidadId)
ON Target.Nombre = Source.Nombre
WHEN MATCHED THEN
    UPDATE SET Target.Descripcion = Source.Descripcion,
               Target.UnidadMedidaIdDefecto = Source.UnidadId,
               Target.Activo = 1,
               Target.ActualizadoEn = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (Nombre, Descripcion, UnidadMedidaIdDefecto, Activo, CreadoEn, ActualizadoEn)
    VALUES (Source.Nombre, Source.Descripcion, Source.UnidadId, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

PRINT N'Catálogo dbo.AtributoCatalogo sincronizado y corregido con tildes.';
GO

-- ----------------------------------------------------------------------------
-- 5. PROCEDIMIENTOS: UNIDADES DE MEDIDA
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

        -- Si existía inactiva, la reactivamos actualizando su nombre
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

        -- Validación de integridad referencial:
        -- Si está asignada como unidad por defecto en algún atributo activo, protegemos con baja lógica
        IF EXISTS (SELECT 1 FROM dbo.AtributoCatalogo WHERE UnidadMedidaIdDefecto = @UnidadMedidaId AND Activo = 1)
        BEGIN
            UPDATE dbo.UnidadMedida
               SET Activo = 0,
                   ActualizadoEn = SYSUTCDATETIME()
             WHERE UnidadMedidaId = @UnidadMedidaId;

            SELECT 1 AS success, N'La unidad de medida fue desactivada porque está vinculada a atributos del catálogo.' AS message;
            RETURN;
        END;

        -- Si no tiene dependencias activas, se inactiva
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

-- ----------------------------------------------------------------------------
-- 6. PROCEDIMIENTOS: ATRIBUTOS DE CATÁLOGO
-- ----------------------------------------------------------------------------
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

        -- Si existía inactivo, lo reactivamos
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

        -- Baja lógica para conservar integridad en activos ya registrados
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
-- 7. ACTUALIZACIÓN DE dbo.uspCatalogosObtener
-- ----------------------------------------------------------------------------
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
END;
GO

-- ----------------------------------------------------------------------------
-- 8. CONCESIÓN DE PERMISOS
-- ----------------------------------------------------------------------------
IF USER_ID('macsa_app') IS NOT NULL
BEGIN
    GRANT SELECT, INSERT, UPDATE ON dbo.UnidadMedida TO [macsa_app];
    GRANT SELECT, INSERT, UPDATE ON dbo.AtributoCatalogo TO [macsa_app];
    GRANT EXECUTE ON dbo.uspUnidadMedidaListar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspUnidadMedidaCrear TO [macsa_app];
    GRANT EXECUTE ON dbo.uspUnidadMedidaActualizar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspUnidadMedidaEliminar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspAtributoCatalogoListar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspAtributoCatalogoCrear TO [macsa_app];
    GRANT EXECUTE ON dbo.uspAtributoCatalogoActualizar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspAtributoCatalogoEliminar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspCatalogosObtener TO [macsa_app];
END;
GO

PRINT N'============================================================';
PRINT N'PARCHE DE ATRIBUTOS Y UNIDADES APLICADO EXITOSAMENTE.';
PRINT N'============================================================';
GO
