/* ============================================================================
   MACSA CMMS - Creación / Actualización de Usuario ADMIN en Mayúsculas
   database/crear_usuario_admin.sql

   Credenciales:
     - Usuario:    ADMIN
     - Contraseña: ADMIN123   (o 1234 si prefieres)
     - Rol:        admin
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @UserId INT;

    -- Si ya existe un usuario 'ADMIN' o 'admin', lo buscamos
    SELECT @UserId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = 'ADMIN';

    IF @UserId IS NOT NULL
    BEGIN
        -- Actualizamos el usuario existente a 'ADMIN' con clave 'ADMIN123'
        -- Salt y Hash generados con PBKDF2-HMAC-SHA256 (20,000 iteraciones)
        UPDATE dbo.Usuario
           SET NombreUsuario             = 'ADMIN',
               NombreCompleto            = N'Administrador General',
               CodigoRol                 = 'admin',
               PasswordSalt              = 'esPJbm6PdewlxkEviSaS2Q==',
               PasswordHash              = 'xEHs3B7nYyZOFuZd7lB8QzY4J04Kxgfw9xRUu9OcMIg=',
               IteracionesPassword       = 20000,
               Deshabilitado             = 0,
               DebeCambiarPassword       = 0,
               SolicitudReinicioPassword = 0,
               IntentosFallidos          = 0,
               BloqueadoHasta            = NULL,
               ActualizadoEn             = SYSUTCDATETIME()
         WHERE UsuarioId = @UserId;

        PRINT N'Usuario ADMIN existente actualizado con éxito.';
    END
    ELSE
    BEGIN
        -- Insertamos el usuario nuevo 'ADMIN' con clave 'ADMIN123'
        INSERT INTO dbo.Usuario
            (NombreUsuario, NombreCompleto, CodigoRol, PasswordSalt, PasswordHash,
             IteracionesPassword, Deshabilitado, DebeCambiarPassword, SolicitudReinicioPassword,
             IntentosFallidos, BloqueadoHasta, CreadoEn)
        VALUES
            ('ADMIN', N'Administrador General', 'admin', 'esPJbm6PdewlxkEviSaS2Q==',
             'xEHs3B7nYyZOFuZd7lB8QzY4J04Kxgfw9xRUu9OcMIg=', 20000, 0, 0, 0,
             0, NULL, SYSUTCDATETIME());

        SET @UserId = SCOPE_IDENTITY();
        PRINT N'Usuario ADMIN creado con éxito.';
    END;

    -- Garantizamos que tenga todos los permisos en UsuarioPermiso
    DELETE FROM dbo.UsuarioPermiso WHERE UsuarioId = @UserId;
    INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
    SELECT @UserId, CodigoPermiso FROM dbo.Permiso;

    COMMIT TRANSACTION;

    SELECT UsuarioId, NombreUsuario, NombreCompleto, CodigoRol, Deshabilitado, DebeCambiarPassword
      FROM dbo.Usuario
     WHERE UsuarioId = @UserId;

    PRINT N'Permisos asignados y proceso completado. Ya puedes iniciar sesión con ADMIN / ADMIN123';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'Error al registrar el usuario:';
    THROW;
END CATCH;
GO
