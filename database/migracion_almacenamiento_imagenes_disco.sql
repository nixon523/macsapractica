/* ============================================================================
   MACSA CMMS - Migración: Almacenamiento de Imágenes en Disco y Rutas en BD
   database/migracion_almacenamiento_imagenes_disco.sql
   
   Objetivo:
     1. Purgar los datos Base64 pesados existentes en dbo.Activo.
     2. Eliminar la restricción LOB CK_Activo_Imagen.
     3. Reducir la columna DatosImagen a NVARCHAR(500) NULL para almacenar
        únicamente la ruta relativa (ej: /image/img_1726790000_abcd.jpg).
     4. Actualizar los procedimientos almacenados correspondientes.
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    PRINT N'1. Purgando datos Base64 existentes en dbo.Activo...';
    UPDATE dbo.Activo SET DatosImagen = NULL WHERE DatosImagen IS NOT NULL;

    PRINT N'2. Eliminando restricciones sobre la columna DatosImagen si existen...';
    IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Activo_Imagen')
    BEGIN
        ALTER TABLE dbo.Activo DROP CONSTRAINT CK_Activo_Imagen;
        PRINT N'   Constraint CK_Activo_Imagen eliminado.';
    END;

    PRINT N'3. Modificando columna DatosImagen a NVARCHAR(500) NULL...';
    ALTER TABLE dbo.Activo ALTER COLUMN DatosImagen NVARCHAR(500) NULL;

    COMMIT TRANSACTION;
    PRINT N'¡Migración de estructura completada con éxito!';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'Error durante la migración de tabla:';
    THROW;
END CATCH;
GO

-- ============================================================================
-- Actualización de Procedimientos Almacenados de Activos
-- ============================================================================

CREATE OR ALTER PROCEDURE dbo.uspActivoCrear
    @Name NVARCHAR(200), @Brand NVARCHAR(100) = NULL, @Model NVARCHAR(100) = NULL,
    @AreaId NVARCHAR(15), @StationId NVARCHAR(100) = '', @Level NVARCHAR(20),
    @ParentAssetCode NVARCHAR(60) = NULL, @Status NVARCHAR(25) = 'active',
    @Serial NVARCHAR(100) = NULL, @DynamicAttributes NVARCHAR(MAX) = NULL,
    @ImageData NVARCHAR(500) = NULL,
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
            DECLARE @parentStatus NVARCHAR(25), @parentAncestors NVARCHAR(400);
            DECLARE @pcTable TABLE (val INT NOT NULL);

            SELECT @parentStatus = Estado, @parentAncestors = RutaAncestros
              FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
             WHERE CodigoActivo = @ParentAssetCode;

            IF @parentStatus IS NULL
            BEGIN
                RAISERROR(N'El activo padre ya no existe.', 16, 1);
            END;
            IF @parentStatus <> 'active'
            BEGIN
                RAISERROR(N'El activo padre no está activo.', 16, 1);
            END;
            IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE CodigoActivo = @ParentAssetCode AND EstadoCandado = 'pending')
            BEGIN
                RAISERROR(N'El activo padre tiene una solicitud de baja pendiente.', 16, 1);
            END;

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
            (@NewAssetCode, @Name, @Brand, @Model, @AreaId, ISNULL(@StationId, ''), @ParentAssetCode,
             @Level, @AncestorsPath, @Status, @Serial, @DynamicAttributes, @ImageData,
             0, SYSUTCDATETIME());

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_CREATED', 'ASSETS', @NewAssetCode,
                CONCAT(N'Activo ', @NewAssetCode, N' (', @Name, N') creado en nivel ', @Level, N'.'));

        COMMIT TRANSACTION;

        SELECT CodigoActivo AS AssetCode, Nombre AS Name, Marca AS Brand, Modelo AS Model,
               AreaId, EstacionId AS StationId, CodigoActivoPadre AS ParentAssetCode,
               Nivel AS Level, RutaAncestros AS AncestorsPath, Estado AS Status,
               TraspasadoACodigo AS TransferredToId, Serie AS Serial,
               AtributosDinamicos AS DynamicAttributes, DatosImagen AS ImageData,
               ContadorHijos AS ChildCounter, CreadoEn AS CreatedAt, ActualizadoEn AS UpdatedAt,
               EsEquipoProceso AS EsEquipoProceso
          FROM dbo.Activo
         WHERE CodigoActivo = @NewAssetCode;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoActualizar
    @AssetCode NVARCHAR(60), @Name NVARCHAR(200), @Brand NVARCHAR(100) = NULL,
    @Model NVARCHAR(100) = NULL, @StationId NVARCHAR(100) = '', @Status NVARCHAR(25),
    @DynamicAttributes NVARCHAR(MAX) = NULL, @ImageData NVARCHAR(500) = NULL,
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
