USE MacsaCMMS;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

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

GRANT EXECUTE ON dbo.uspUsuarioObtenerParaLogin TO macsa_app;
GO
