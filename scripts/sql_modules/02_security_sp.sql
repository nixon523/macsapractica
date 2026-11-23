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
           BloqueadoHasta   = CASE WHEN IntentosFallidos + 1 >= 5 THEN DATEADD(MINUTE, 5, SYSUTCDATETIME()) ELSE BloqueadoHasta END,
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
END;
GO
