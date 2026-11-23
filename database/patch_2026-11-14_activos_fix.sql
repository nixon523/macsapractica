-- ============================================================================
-- MACSA CMMS - PARCHE DE REPARACIÓN: PROCEDIMIENTOS DE ACTIVOS
-- Fecha: 2026-11-14
--
-- Motivo:
-- 1. Resolver el problema donde el activo recién creado se mostraba sin datos
--    y al intentar editarlo devolvía "Ruta no encontrada: PUT /api/activos/".
-- 2. Garantizar alias bilingües (PascalCase español y camelCase/inglés) en los
--    procedimientos de consulta de activos para total compatibilidad.
-- 3. Retornar CodigoActivo, assetCode y NewAssetCode en dbo.uspActivoCrear.
-- 4. Blindar auditoría y parámetros en dbo.uspActivoCrear y dbo.uspActivoActualizar.
-- ============================================================================

USE [MacsaCMMS];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'Iniciando aplicación del parche de activos 2026-11-14...';
GO

-- ----------------------------------------------------------------------------
-- 1. dbo.uspActivoObtenerRaicesPorArea
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

-- ----------------------------------------------------------------------------
-- 2. dbo.uspActivoObtenerHijos
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- 3. dbo.uspActivoBuscar
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- 4. dbo.uspActivoBuscarPorSerie
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- 5. dbo.uspActivoCrear
-- ----------------------------------------------------------------------------
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

        INSERT INTO dbo.Activo
            (CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, CodigoActivoPadre,
             Nivel, RutaAncestros, Estado, Serie, AtributosDinamicos, DatosImagen,
             ContadorHijos, CreadoEn)
        VALUES
            (@NewAssetCode, @Name, @Brand, @Model, @AreaId, @StationId, @ParentAssetCode,
             @Level, @AncestorsPath, @Status, NULLIF(@Serial, ''), @DynamicAttributes, @ImageData,
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

-- ----------------------------------------------------------------------------
-- 6. dbo.uspActivoActualizar
-- ----------------------------------------------------------------------------
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
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 7. PERMISOS DE EJECUCIÓN
-- ----------------------------------------------------------------------------
IF USER_ID('macsa_app') IS NOT NULL
BEGIN
    GRANT EXECUTE ON dbo.uspActivoObtenerRaicesPorArea TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoObtenerHijos TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoBuscar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoBuscarPorSerie TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoCrear TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoActualizar TO [macsa_app];
END;
GO

PRINT N'============================================================';
PRINT N'PARCHE DE ACTIVOS 2026-11-14 APLICADO EXITOSAMENTE.';
PRINT N'============================================================';
GO
