-- ============================================================================
-- MACSA CMMS - PARCHE: CLONACIÓN DE ÁRBOLES DE ACTIVOS, PLANTILLAS Y OBSERVACIONES
-- Fecha: 2026-11-16
--
-- Contenido:
-- 1. Agregado de columna Observaciones en dbo.Activo (opcional).
-- 2. Tablas dbo.PlantillaActivo y dbo.PlantillaActivoNodo para biblioteca de plantillas.
-- 3. Actualización de procedimientos CRUD de activos para soportar Observaciones.
-- 4. Procedimiento dbo.uspActivoClonarArbol para duplicar estructuras completas.
-- 5. Procedimientos CRUD para catálogo e instanciación de plantillas.
-- 6. Concesión de permisos al usuario/rol macsa_app.
-- ============================================================================

USE [MacsaCMMS];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'Iniciando aplicación del parche de clonación, plantillas y observaciones 2026-11-16...';
GO

-- ----------------------------------------------------------------------------
-- 1. COLUMNA Observaciones EN dbo.Activo
-- ----------------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.columns 
     WHERE object_id = OBJECT_ID(N'dbo.Activo') 
       AND name = 'Observaciones'
)
BEGIN
    ALTER TABLE dbo.Activo
      ADD Observaciones NVARCHAR(MAX) NULL;

    PRINT N'Columna Observaciones agregada exitosamente a dbo.Activo.';
END;
GO

-- ----------------------------------------------------------------------------
-- 2. TABLAS DE PLANTILLAS DE ACTIVOS
-- ----------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.PlantillaActivo', N'U') IS NULL
BEGIN
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

    CREATE NONCLUSTERED INDEX IX_PlantillaActivo_Activo_Nombre
        ON dbo.PlantillaActivo (Activo, Nombre);

    PRINT N'Tabla dbo.PlantillaActivo creada exitosamente.';
END;
GO

IF OBJECT_ID(N'dbo.PlantillaActivoNodo', N'U') IS NULL
BEGIN
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

    CREATE NONCLUSTERED INDEX IX_PlantillaNodo_Plantilla_Padre
        ON dbo.PlantillaActivoNodo (PlantillaId, NodoPadreId);

    PRINT N'Tabla dbo.PlantillaActivoNodo creada exitosamente.';
END;
GO

-- ----------------------------------------------------------------------------
-- 3. ACTUALIZACIÓN DE PROCEDIMIENTOS DE CONSULTA Y EDICIÓN DE ACTIVOS
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.uspActivoObtenerRaicesPorArea
    @AreaId NVARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CodigoActivo, CodigoActivo AS assetCode, CodigoActivo AS id,
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
           Observaciones, Observaciones AS observations, Observaciones AS observaciones,
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
    @AreaId NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CodigoActivo, CodigoActivo AS assetCode, CodigoActivo AS id,
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
           Observaciones, Observaciones AS observations, Observaciones AS observaciones,
           CreadoEn, CreadoEn AS createdAt,
           ActualizadoEn, ActualizadoEn AS updatedAt,
           EsEquipoProceso, EsEquipoProceso AS isProcessEquipment
      FROM dbo.Activo
     WHERE (@ParentAssetCode IS NULL OR CodigoActivoPadre = @ParentAssetCode)
       AND (@AreaId IS NULL OR AreaId = @AreaId)
       AND Estado <> 'deleted'
     ORDER BY CodigoActivo ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoBuscar
    @Query NVARCHAR(200) = '',
    @AreaId NVARCHAR(15) = NULL,
    @Level NVARCHAR(20) = NULL,
    @Status NVARCHAR(25) = NULL,
    @Limit INT = 200,
    @Offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CleanQuery NVARCHAR(200) = LTRIM(RTRIM(@Query));

    SELECT CodigoActivo, CodigoActivo AS assetCode, CodigoActivo AS id,
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
           Observaciones, Observaciones AS observations, Observaciones AS observaciones,
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
    SELECT CodigoActivo, CodigoActivo AS assetCode, CodigoActivo AS id,
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
           Observaciones, Observaciones AS observations, Observaciones AS observaciones,
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
             @Observaciones, 0, SYSUTCDATETIME());

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
    @Name NVARCHAR(200),
    @Brand NVARCHAR(100) = NULL,
    @Model NVARCHAR(100) = NULL,
    @StationId NVARCHAR(100) = '',
    @Serial NVARCHAR(100) = NULL,
    @DynamicAttributes NVARCHAR(MAX) = NULL,
    @ImageData NVARCHAR(500) = NULL,
    @Observaciones NVARCHAR(MAX) = NULL,
    @Status NVARCHAR(25) = NULL,
    @Estado NVARCHAR(25) = NULL,
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

        IF @Serial IS NOT NULL AND LTRIM(RTRIM(@Serial)) <> ''
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Activo WHERE Serie = @Serial AND CodigoActivo <> @TargetCode AND Estado <> 'deleted')
                RAISERROR(N'El número de serie ya está en uso por otro activo activo.', 16, 1);
        END;

        UPDATE dbo.Activo
           SET Nombre             = @Name,
               Marca              = @Brand,
               Modelo             = @Model,
               EstacionId         = @StationId,
               Serie              = NULLIF(@Serial, ''),
               AtributosDinamicos = @DynamicAttributes,
               DatosImagen        = COALESCE(@ImageData, DatosImagen),
               Observaciones      = @Observaciones,
               ActualizadoEn      = SYSUTCDATETIME()
         WHERE CodigoActivo = @TargetCode;

        IF @UserId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UserId)
        BEGIN
            SELECT @UserId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@UserName)));
            IF @UserId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UserId)
                SET @UserId = NULL;
        END;

        DECLARE @UNameAuditUpd NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UNameAuditUpd, 'ASSET_UPDATED', 'ASSETS', @TargetCode,
                CONCAT(N'Activo actualizado: ', @TargetCode, N' (', @Name, N').'));

        COMMIT TRANSACTION;
        SELECT 1 AS success;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
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
            CodigoOrigen NVARCHAR(60) PRIMARY KEY,
            CodigoNuevo  NVARCHAR(60) NOT NULL,
            RutaAncestros NVARCHAR(400) NOT NULL
        );
        INSERT INTO @Mapeo (CodigoOrigen, CodigoNuevo, RutaAncestros)
        VALUES (@CodigoActivoOrigen, @NuevoCodigoRaiz, '');

        -- Tabla temporal de descendientes
        CREATE TABLE #Descendientes (
            Orden         INT IDENTITY(1,1),
            CodigoOrigen  NVARCHAR(60),
            PadreOrigen   NVARCHAR(60),
            Nombre        NVARCHAR(200),
            Marca         NVARCHAR(100),
            Modelo        NVARCHAR(100),
            Nivel         NVARCHAR(20),
            Observaciones NVARCHAR(MAX),
            Atributos     NVARCHAR(MAX),
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
            CodigoActivo NVARCHAR(60) PRIMARY KEY,
            NodoId       INT NOT NULL
        );
        INSERT INTO @MapeoNodos (CodigoActivo, NodoId) VALUES (@CodigoActivoOrigen, @NodoRaizId);

        -- Tabla temporal de descendientes
        CREATE TABLE #DescPlantilla (
            Orden         INT IDENTITY(2,1),
            CodigoActivo  NVARCHAR(60),
            PadreCodigo   NVARCHAR(60),
            Nombre        NVARCHAR(200),
            Marca         NVARCHAR(100),
            Modelo        NVARCHAR(100),
            Nivel         NVARCHAR(20),
            Atributos     NVARCHAR(MAX),
            Observaciones NVARCHAR(MAX),
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
            CodigoActivo  NVARCHAR(60) NOT NULL,
            RutaAncestros NVARCHAR(400) NOT NULL
        );
        INSERT INTO @Mapeo (NodoId, CodigoActivo, RutaAncestros)
        VALUES (@RootNodoId, @NuevoCodigoRaiz, '');

        -- Tabla temporal para procesar descendientes en orden
        CREATE TABLE #NodosInstanciar (
            Orden         INT IDENTITY(1,1),
            NodoId        INT,
            NodoPadreId   INT,
            Nombre        NVARCHAR(200),
            Marca         NVARCHAR(100),
            Modelo        NVARCHAR(100),
            Nivel         NVARCHAR(20),
            Atributos     NVARCHAR(MAX),
            Observaciones NVARCHAR(MAX),
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
-- 6. CONCESIÓN DE PERMISOS AL USUARIO macsa_app
-- ----------------------------------------------------------------------------
IF USER_ID('macsa_app') IS NOT NULL
BEGIN
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.PlantillaActivo TO [macsa_app];
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.PlantillaActivoNodo TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoClonarArbol TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlantillaActivoListar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlantillaActivoObtenerDetalle TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlantillaActivoGuardarDesdeActivo TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlantillaActivoInstanciar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlantillaActivoEliminar TO [macsa_app];
END;
GO

PRINT N'============================================================';
PRINT N'PARCHE DE CLONACIÓN Y PLANTILLAS APLICADO EXITOSAMENTE.';
PRINT N'============================================================';
GO
