/* ============================================================================
   MACSA CMMS - Migración de Procedimientos de Usuarios y Permisos
   database/migrate_permissions.sql
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Obtener usuario para Login (incluye PermissionsCsv)
CREATE OR ALTER PROCEDURE dbo.uspUsuarioObtenerParaLogin @Username NVARCHAR(50)
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

-- 2. Crear Usuario (soporta TVP de permisos personalizados)
CREATE OR ALTER PROCEDURE dbo.uspUsuarioCrear
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

-- 3. Actualizar Usuario (soporta TVP de permisos personalizados)
CREATE OR ALTER PROCEDURE dbo.uspUsuarioActualizar
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

-- 4. Obtener Todos los Usuarios (incluye PermissionsCsv)
CREATE OR ALTER PROCEDURE dbo.uspUsuarioObtenerTodos
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

PRINT 'Migración de procedimientos de usuarios y permisos completada con éxito.';
GO
