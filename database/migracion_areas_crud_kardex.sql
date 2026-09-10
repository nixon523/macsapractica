/* ============================================================================
   MACSA CMMS - Grupo Macsa
   database/migracion_areas_crud_kardex.sql
   Manejo Delicado de CRUD de Áreas con Trazabilidad Kardex y Blindaje de Integridad
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ============================================================================
-- 0. Ajustar restricción CK_BK_Modulo para permitir 'AREAS'
-- ============================================================================
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_BK_Modulo' AND parent_object_id = OBJECT_ID('dbo.BitacoraKardex'))
BEGIN
    ALTER TABLE dbo.BitacoraKardex DROP CONSTRAINT CK_BK_Modulo;
END;
GO

ALTER TABLE dbo.BitacoraKardex ADD CONSTRAINT CK_BK_Modulo 
    CHECK (Modulo IN ('ASSETS', 'AREAS', 'PREVENTIVE', 'BREAKDOWNS', 'WORK_ORDERS'));
GO

-- ============================================================================
-- 1. uspAreaCrear con Trazabilidad Kardex y Normalización en MAYÚSCULAS
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspAreaCrear
    @Name               NVARCHAR(100),
    @CostCenter         NVARCHAR(50),
    @AreaId             NVARCHAR(15) = NULL,
    @UserId             INT = NULL,
    @UserName           NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @CleanName NVARCHAR(100) = UPPER(LTRIM(RTRIM(@Name)));
        DECLARE @RawCC     NVARCHAR(50)  = UPPER(LTRIM(RTRIM(@CostCenter)));
        DECLARE @NormCC    NVARCHAR(50)  =
            CASE WHEN @RawCC LIKE 'CC-%' THEN @RawCC 
                 WHEN @RawCC LIKE 'CC%' THEN CONCAT('CC-', SUBSTRING(@RawCC, 3, LEN(@RawCC)))
                 ELSE CONCAT('CC-', @RawCC) END;

        DECLARE @FinalId NVARCHAR(15) = UPPER(LTRIM(RTRIM(ISNULL(@AreaId, ''))));
        IF @FinalId = ''
        BEGIN
            -- Obtener el número máximo existente en dbo.Area para auto-sincronizar el contador
            DECLARE @maxExisting INT = 0;
            SELECT @maxExisting = ISNULL(MAX(TRY_CAST(SUBSTRING(AreaId, 2, 10) AS INT)), 0)
              FROM dbo.Area
             WHERE AreaId LIKE 'A[0-9]%';

            DECLARE @cnt TABLE (val INT NOT NULL);
            UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
               SET SiguienteNumero = CASE WHEN SiguienteNumero < @maxExisting THEN @maxExisting + 1 ELSE SiguienteNumero + 1 END
             OUTPUT inserted.SiguienteNumero INTO @cnt(val)
              WHERE Nombre = 'areas';

            DECLARE @nextVal INT; SELECT @nextVal = val FROM @cnt;
            SET @FinalId = CONCAT('A', FORMAT(@nextVal, '000'));
        END;

        IF EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @FinalId)
        BEGIN
            RAISERROR(N'Ya existe un área con el identificador "%s".', 16, 1, @FinalId);
        END;

        INSERT INTO dbo.Area (AreaId, Nombre, CentroCosto, ContadorActivos, CreadoEn)
        VALUES (@FinalId, @CleanName, @NormCC, 0, SYSUTCDATETIME());

        -- Registro inmutable en BitacoraKardex
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, ISNULL(NULLIF(@UserName, ''), N'SISTEMA'), 'AREA_CREATED', 'AREAS', @FinalId,
                CONCAT(N'Área ', @FinalId, N' (', @CleanName, N' | Centro de Costo: ', @NormCC, N') creada exitosamente.'));

        COMMIT TRANSACTION;
        SELECT @FinalId AS AreaId, @FinalId AS NewAreaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 2. uspAreaActualizar con Trazabilidad Kardex y Normalización en MAYÚSCULAS
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspAreaActualizar
    @AreaId     NVARCHAR(15),
    @Name       NVARCHAR(100),
    @CostCenter NVARCHAR(50) = NULL,
    @UserId     INT = NULL,
    @UserName   NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CleanAreaId NVARCHAR(15) = UPPER(LTRIM(RTRIM(@AreaId)));
        DECLARE @CleanName   NVARCHAR(100) = UPPER(LTRIM(RTRIM(@Name)));
        DECLARE @RawCC       NVARCHAR(50)  = UPPER(LTRIM(RTRIM(ISNULL(@CostCenter, ''))));

        DECLARE @OldName NVARCHAR(100), @OldCC NVARCHAR(50);
        SELECT @OldName = Nombre, @OldCC = CentroCosto
          FROM dbo.Area WITH (UPDLOCK, HOLDLOCK)
         WHERE AreaId = @CleanAreaId;

        IF @OldName IS NULL
            RAISERROR(N'El área especificada no existe.', 16, 1);

        DECLARE @NormCC NVARCHAR(50) =
            CASE WHEN @RawCC = '' THEN @OldCC
                 WHEN @RawCC LIKE 'CC-%' THEN @RawCC
                 WHEN @RawCC LIKE 'CC%' THEN CONCAT('CC-', SUBSTRING(@RawCC, 3, LEN(@RawCC)))
                 ELSE CONCAT('CC-', @RawCC) END;

        UPDATE dbo.Area
           SET Nombre        = @CleanName,
               CentroCosto   = @NormCC,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE AreaId = @CleanAreaId;

        -- Sincronizar nombre de área en planes preventivos y órdenes de trabajo si cambió
        IF @OldName <> @CleanName
        BEGIN
            UPDATE dbo.PlanPreventivo SET NombreArea = @CleanName WHERE AreaId = @CleanAreaId;
            UPDATE dbo.OrdenTrabajo   SET NombreArea = @CleanName WHERE AreaId = @CleanAreaId;
        END;

        -- Registro inmutable en BitacoraKardex
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, ISNULL(NULLIF(@UserName, ''), N'SISTEMA'), 'AREA_UPDATED', 'AREAS', @CleanAreaId,
                CONCAT(N'Área ', @CleanAreaId, N' modificada. Nombre: "', @OldName, N'" -> "', @CleanName, 
                       N'", Centro de Costo: "', @OldCC, N'" -> "', @NormCC, N'".'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 3. uspAreaEliminar con Blindaje Delicado e Integridad Referencial
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspAreaEliminar
    @AreaId     NVARCHAR(15),
    @UserId     INT = NULL,
    @UserName   NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CleanAreaId NVARCHAR(15) = UPPER(LTRIM(RTRIM(@AreaId)));
        DECLARE @AreaName NVARCHAR(100), @CC NVARCHAR(50);
        SELECT @AreaName = Nombre, @CC = CentroCosto
          FROM dbo.Area WITH (UPDLOCK, HOLDLOCK)
         WHERE AreaId = @CleanAreaId;

        IF @AreaName IS NULL
            RAISERROR(N'El área especificada no existe.', 16, 1);

        -- 1. Validar que no tenga activos asignados (en cualquier nivel o estado)
        DECLARE @ActivosAsignados INT = 0;
        SELECT @ActivosAsignados = COUNT(*)
          FROM dbo.Activo
         WHERE AreaId = @CleanAreaId;

        IF @ActivosAsignados > 0
        BEGIN
            RAISERROR(N'No se puede eliminar el área "%s" porque tiene %d activo(s) vinculado(s). Debe transferirlos a otra área o tramitar su baja primero.', 16, 1, @CleanAreaId, @ActivosAsignados);
        END;

        -- 2. Validar que no tenga planes preventivos registrados
        IF EXISTS (SELECT 1 FROM dbo.PlanPreventivo WHERE AreaId = @CleanAreaId)
        BEGIN
            RAISERROR(N'No se puede eliminar el área "%s" porque tiene planes de mantenimiento preventivo registrados. Debe pausarlos o reasignarlos primero.', 16, 1, @CleanAreaId);
        END;

        -- 3. Validar que no tenga órdenes de trabajo registradas
        IF EXISTS (SELECT 1 FROM dbo.OrdenTrabajo WHERE AreaId = @CleanAreaId)
        BEGIN
            RAISERROR(N'No se puede eliminar el área "%s" porque tiene órdenes de trabajo registradas.', 16, 1, @CleanAreaId);
        END;

        -- 4. Validar que no tenga solicitudes de baja registradas
        IF EXISTS (SELECT 1 FROM dbo.SolicitudBaja WHERE AreaId = @CleanAreaId)
        BEGIN
            RAISERROR(N'No se puede eliminar el área "%s" porque tiene solicitudes de baja históricas registradas.', 16, 1, @CleanAreaId);
        END;

        -- 5. Eliminar el área
        DELETE FROM dbo.Area WHERE AreaId = @CleanAreaId;

        -- 6. Registro inmutable en BitacoraKardex
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, ISNULL(NULLIF(@UserName, ''), N'SISTEMA'), 'AREA_DELETED', 'AREAS', @CleanAreaId,
                CONCAT(N'Área ', @CleanAreaId, N' (', @AreaName, N' - ', @CC, N') eliminada del sistema.'));

        COMMIT TRANSACTION;
        SELECT @CleanAreaId AS DeletedAreaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Normalizar datos existentes a MAYÚSCULAS
UPDATE dbo.Area 
   SET Nombre = UPPER(LTRIM(RTRIM(Nombre))), 
       CentroCosto = UPPER(LTRIM(RTRIM(CentroCosto)));
GO

UPDATE dbo.PlanPreventivo
   SET NombreArea = UPPER(LTRIM(RTRIM(NombreArea)))
 WHERE NombreArea IS NOT NULL;
GO

UPDATE dbo.OrdenTrabajo
   SET NombreArea = UPPER(LTRIM(RTRIM(NombreArea)))
 WHERE NombreArea IS NOT NULL;
GO

GRANT EXECUTE ON dbo.uspAreaCrear TO PUBLIC;
GRANT EXECUTE ON dbo.uspAreaActualizar TO PUBLIC;
GRANT EXECUTE ON dbo.uspAreaEliminar TO PUBLIC;
GO
