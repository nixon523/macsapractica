USE MacsaCMMS;
GO

-- =========================================================================
-- Migración: Actualización y corrección de SPs de Usuarios y Reset Password
-- =========================================================================

-- 1. uspUsuarioCrear
CREATE OR ALTER PROCEDURE dbo.uspUsuarioCrear
    @Username NVARCHAR(50), 
    @DisplayName NVARCHAR(100), 
    @RoleCode NVARCHAR(20),
    @PasswordSalt NVARCHAR(64), 
    @PasswordHash NVARCHAR(128), 
    @PasswordIterations INT = 20000,
    @MustChangePassword BIT = 1,
    @HasCustomPermissions BIT = 0,
    @Permissions dbo.TipoListaTexto READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF EXISTS (SELECT 1 FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@Username))))
        BEGIN
            RAISERROR(N'El nombre de usuario ya está en uso.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN -1;
        END;

        INSERT INTO dbo.Usuario
            (NombreUsuario, NombreCompleto, CodigoRol, PasswordSalt, PasswordHash,
             IteracionesPassword, DebeCambiarPassword, SolicitudReinicioPassword, SolicitadoEn, IntentosFallidos, BloqueadoHasta, CreadoEn, ActualizadoEn)
        VALUES
            (LTRIM(RTRIM(@Username)), LTRIM(RTRIM(@DisplayName)), @RoleCode, @PasswordSalt, @PasswordHash,
             @PasswordIterations, @MustChangePassword, 0, NULL, 0, NULL, SYSUTCDATETIME(), SYSUTCDATETIME());

        DECLARE @uid INT = SCOPE_IDENTITY();

        IF @HasCustomPermissions = 1 AND EXISTS (SELECT 1 FROM @Permissions)
        BEGIN
            INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
            SELECT @uid, Valor FROM @Permissions WHERE Valor IS NOT NULL AND LTRIM(RTRIM(Valor)) <> '';
        END
        ELSE
        BEGIN
            INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
            SELECT @uid, CodigoPermiso FROM dbo.RolPermiso WHERE CodigoRol = @RoleCode;
        END

        COMMIT TRANSACTION;
        
        -- Return created user row
        SELECT u.UsuarioId AS UserId, u.NombreUsuario AS Username, u.NombreCompleto AS DisplayName,
               u.CodigoRol AS RoleCode, u.Deshabilitado AS Disabled, u.DebeCambiarPassword AS MustChangePassword,
               u.SolicitudReinicioPassword AS PasswordResetRequested, u.SolicitadoEn AS PasswordResetRequestedAt,
               u.CreadoEn AS CreatedAt,
               (SELECT STRING_AGG(CodigoPermiso, ',') FROM dbo.UsuarioPermiso WHERE UsuarioId = u.UsuarioId) AS PermissionsCsv
          FROM dbo.Usuario u
         WHERE u.UsuarioId = @uid;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 2. uspUsuarioActualizar
CREATE OR ALTER PROCEDURE dbo.uspUsuarioActualizar
    @UserId INT, 
    @DisplayName NVARCHAR(100) = NULL, 
    @NewRoleCode NVARCHAR(20) = NULL,
    @NewSalt NVARCHAR(64) = NULL, 
    @NewHash NVARCHAR(128) = NULL, 
    @NewIterations INT = NULL,
    @MustChangePassword BIT = NULL,
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
            ROLLBACK TRANSACTION;
            RETURN -1;
        END;

        -- If new password is provided, reset lockout and mark pending requests resolved
        IF @NewSalt IS NOT NULL
        BEGIN
            UPDATE dbo.Usuario
               SET NombreCompleto      = COALESCE(NULLIF(LTRIM(RTRIM(@DisplayName)), ''), NombreCompleto),
                   CodigoRol           = COALESCE(@NewRoleCode, CodigoRol),
                   PasswordSalt        = @NewSalt,
                   PasswordHash        = @NewHash,
                   IteracionesPassword = COALESCE(@NewIterations, IteracionesPassword, 20000),
                   DebeCambiarPassword = 1,
                   SolicitudReinicioPassword = 0,
                   SolicitadoEn        = NULL,
                   IntentosFallidos    = 0,
                   BloqueadoHasta      = NULL,
                   ActualizadoEn       = SYSUTCDATETIME()
             WHERE UsuarioId = @UserId;

            UPDATE dbo.SolicitudReinicioPassword
               SET Estado = 'resolved'
             WHERE UsuarioId = @UserId AND Estado = 'pending';
        END
        ELSE
        BEGIN
            UPDATE dbo.Usuario
               SET NombreCompleto      = COALESCE(NULLIF(LTRIM(RTRIM(@DisplayName)), ''), NombreCompleto),
                   CodigoRol           = COALESCE(@NewRoleCode, CodigoRol),
                   DebeCambiarPassword = COALESCE(@MustChangePassword, DebeCambiarPassword),
                   ActualizadoEn       = SYSUTCDATETIME()
             WHERE UsuarioId = @UserId;
        END

        IF @HasCustomPermissions = 1 AND EXISTS (SELECT 1 FROM @Permissions)
        BEGIN
            DELETE FROM dbo.UsuarioPermiso WHERE UsuarioId = @UserId;
            INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
            SELECT @UserId, Valor FROM @Permissions WHERE Valor IS NOT NULL AND LTRIM(RTRIM(Valor)) <> '';
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

-- 3. uspUsuarioReiniciarTemporal
CREATE OR ALTER PROCEDURE dbo.uspUsuarioReiniciarTemporal
    @UserId INT, 
    @PasswordSalt NVARCHAR(64), 
    @PasswordHash NVARCHAR(128), 
    @PasswordIterations INT = 20000
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UserId)
        BEGIN
            RAISERROR(N'El usuario especificado no existe.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN -1;
        END;

        UPDATE dbo.Usuario
           SET PasswordSalt = @PasswordSalt, 
               PasswordHash = @PasswordHash,
               IteracionesPassword = COALESCE(@PasswordIterations, 20000), 
               DebeCambiarPassword = 1,
               SolicitudReinicioPassword = 0, 
               SolicitadoEn = NULL,
               IntentosFallidos = 0, 
               BloqueadoHasta = NULL, 
               ActualizadoEn = SYSUTCDATETIME()
         WHERE UsuarioId = @UserId;

        UPDATE dbo.SolicitudReinicioPassword
           SET Estado = 'resolved'
         WHERE UsuarioId = @UserId AND Estado = 'pending';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 4. uspUsuarioObtenerTodos
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
           (SELECT STRING_AGG(CodigoPermiso, ',') FROM dbo.UsuarioPermiso WHERE UsuarioId = u.UsuarioId) AS PermissionsCsv
      FROM dbo.Usuario u
     ORDER BY u.NombreUsuario;
END;
GO
