-- ============================================================================
-- SCRIPT DE MIGRACIÓN: Matriz RBAC Optimizada (5 Roles) + Vínculo Empleado-Usuario
-- Fecha: 2026-11-11
-- Autor: Grupo MACSA - Sistema CMMS
-- ============================================================================
-- 1. Agrega nuevos permisos granulares a dbo.Permiso.
-- 2. Configura los 5 roles exactos en dbo.Rol y dbo.RolPermiso:
--      - admin      (Administrador)
--      - jefe       (Jefe de Mantenimiento)
--      - jefe_area  (Jefe de Área)
--      - reportador (Supervisor / Reportador)
--      - lector     (Gerente / Solo Lectura / KPIs)
-- 3. Agrega la columna EmpleadoId (nullable, FK a dbo.Empleado) a dbo.Usuario.
-- 4. Actualiza uspUsuarioCrear, uspUsuarioActualizar, uspUsuarioObtenerTodos,
--    uspUsuarioObtenerPorId y uspUsuarioObtenerParaLogin.
-- 5. Actualiza los permisos base de los usuarios ya existentes acorde a su rol.
-- ============================================================================

USE [MacsaCMMS];
GO

SET NOCOUNT ON;
GO

PRINT 'Iniciando migración RBAC (5 Roles) y vínculo Empleado-Usuario...';
GO

-- 1. Nuevos códigos de permiso en dbo.Permiso
DECLARE @NuevosPermisos TABLE (Codigo NVARCHAR(50));
INSERT INTO @NuevosPermisos (Codigo)
VALUES 
    (N'preventive.manage'),
    (N'operation_report.view'),
    (N'operation_report.edit'),
    (N'employee.manage');

INSERT INTO dbo.Permiso (CodigoPermiso)
SELECT np.Codigo
  FROM @NuevosPermisos np
 WHERE NOT EXISTS (SELECT 1 FROM dbo.Permiso p WHERE p.CodigoPermiso = np.Codigo);
GO

-- 2. Actualizar catálogo de Roles en dbo.Rol
MERGE dbo.Rol AS target
USING (
    VALUES
        (N'admin',      N'Administrador'),
        (N'jefe',       N'Jefe de Mantenimiento'),
        (N'jefe_area',  N'Jefe de Área'),
        (N'reportador', N'Supervisor (Reportador)'),
        (N'lector',     N'Gerente (Solo Lectura / KPIs)')
) AS src (CodigoRol, Nombre)
ON target.CodigoRol = src.CodigoRol
WHEN MATCHED THEN
    UPDATE SET Nombre = src.Nombre
WHEN NOT MATCHED THEN
    INSERT (CodigoRol, Nombre) VALUES (src.CodigoRol, src.Nombre);
GO

-- 3. Reconstruir dbo.RolPermiso con los permisos exactos por rol
DELETE FROM dbo.RolPermiso;
GO

-- admin: TODOS los permisos del sistema
INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
SELECT N'admin', CodigoPermiso FROM dbo.Permiso;

-- jefe (Jefe de Mantenimiento): Todo el flujo operativo de mantenimiento y activos,
-- EXCEPTO user.manage y asset.delete.approve (exclusivos del Administrador).
INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
VALUES
    (N'jefe', N'dashboard.view'),
    (N'jefe', N'asset.view'),
    (N'jefe', N'asset.create'),
    (N'jefe', N'asset.edit'),
    (N'jefe', N'asset.transfer'),
    (N'jefe', N'asset.delete.request'),
    (N'jefe', N'work_order.view'),
    (N'jefe', N'work_order.create'),
    (N'jefe', N'work_order.print'),
    (N'jefe', N'preventive.view'),
    (N'jefe', N'preventive.manage'),
    (N'jefe', N'kardex.view'),
    (N'jefe', N'breakdown.report'),
    (N'jefe', N'breakdown.view'),
    (N'jefe', N'breakdown.manage'),
    (N'jefe', N'operation_report.view'),
    (N'jefe', N'operation_report.edit'),
    (N'jefe', N'employee.manage');

-- jefe_area (Jefe de Área): Acceso operativo limitado de supervisión de su área.
-- Puede ver dashboard, consultar equipos, consultar OTs e imprimir, ver calendario preventivo,
-- reportar y dar seguimiento a averías, y registrar/consultar reportes de operación.
INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
VALUES
    (N'jefe_area', N'dashboard.view'),
    (N'jefe_area', N'asset.view'),
    (N'jefe_area', N'work_order.view'),
    (N'jefe_area', N'work_order.print'),
    (N'jefe_area', N'preventive.view'),
    (N'jefe_area', N'breakdown.report'),
    (N'jefe_area', N'breakdown.view'),
    (N'jefe_area', N'operation_report.view'),
    (N'jefe_area', N'operation_report.edit');

-- reportador (Supervisor): Reportar averías y consultar estado de averías.
INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
VALUES
    (N'reportador', N'breakdown.report'),
    (N'reportador', N'breakdown.view');

-- lector (Gerente): Ver TODO el sistema (dashboards, KPIs, OEE, Kardex, activos, OTs, preventivos, averías)
-- y generar reportes PDF/Excel/impresión, SIN poder modificar ni gestionar nada.
INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
VALUES
    (N'lector', N'dashboard.view'),
    (N'lector', N'asset.view'),
    (N'lector', N'work_order.view'),
    (N'lector', N'work_order.print'),
    (N'lector', N'preventive.view'),
    (N'lector', N'kardex.view'),
    (N'lector', N'breakdown.view'),
    (N'lector', N'operation_report.view');
GO

-- Sincronizar permisos nuevos faltantes en usuarios existentes de roles jefe y lector
INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
SELECT u.UsuarioId, rp.CodigoPermiso
  FROM dbo.Usuario u
  JOIN dbo.RolPermiso rp ON u.CodigoRol = rp.CodigoRol
 WHERE u.CodigoRol IN (N'admin', N'jefe', N'lector')
   AND NOT EXISTS (
       SELECT 1 FROM dbo.UsuarioPermiso up
        WHERE up.UsuarioId = u.UsuarioId AND up.CodigoPermiso = rp.CodigoPermiso
   );
GO

-- 4. Agregar columna EmpleadoId a dbo.Usuario si no existe
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
     WHERE object_id = OBJECT_ID(N'dbo.Usuario') AND name = N'EmpleadoId'
)
BEGIN
    ALTER TABLE dbo.Usuario ADD EmpleadoId INT NULL;
    ALTER TABLE dbo.Usuario ADD CONSTRAINT FK_Usuario_Empleado
        FOREIGN KEY (EmpleadoId) REFERENCES dbo.Empleado(EmpleadoId);
    PRINT 'Columna EmpleadoId agregada a dbo.Usuario.';
END
ELSE
BEGIN
    PRINT 'Columna EmpleadoId ya existe en dbo.Usuario.';
END
GO

-- 5. Actualizar Stored Procedures de Usuarios para soportar EmpleadoId y nuevas consultas

CREATE OR ALTER PROCEDURE dbo.uspUsuarioObtenerParaLogin @Username NVARCHAR(50)
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

CREATE OR ALTER PROCEDURE dbo.uspUsuarioObtenerPorId @UserId INT
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
    @EmployeeId INT = NULL
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

        IF @EmployeeId IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.Usuario WHERE EmpleadoId = @EmployeeId AND UsuarioId <> @UserId)
        BEGIN
            RAISERROR(N'El empleado seleccionado ya está vinculado a otro usuario.', 16, 1);
        END;

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
               SET NombreCompleto      = COALESCE(NULLIF(LTRIM(RTRIM(@DisplayName)), ''), NombreCompleto),
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

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'macsa_app')
BEGIN
    GRANT SELECT ON dbo.Rol TO macsa_app;
    GRANT SELECT ON dbo.Permiso TO macsa_app;
    GRANT SELECT ON dbo.RolPermiso TO macsa_app;
    GRANT EXECUTE ON dbo.uspUsuarioObtenerParaLogin TO macsa_app;
    GRANT EXECUTE ON dbo.uspUsuarioObtenerTodos TO macsa_app;
    GRANT EXECUTE ON dbo.uspUsuarioObtenerPorId TO macsa_app;
    GRANT EXECUTE ON dbo.uspUsuarioCrear TO macsa_app;
    GRANT EXECUTE ON dbo.uspUsuarioActualizar TO macsa_app;
END
GO

PRINT 'Migración RBAC y vínculo Empleado-Usuario finalizada exitosamente.';
GO

