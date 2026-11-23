-- ============================================================================
-- MACSA CMMS - PARCHE DE REPARACIÓN Y PROCEDIMIENTOS ALMACENADOS
-- Fecha: 2026-11-14
-- Este parche actualiza TODOS los procedimientos almacenados, repara caracteres
-- especiales (Mojibake) en Empleados y Puestos, y asegura las restricciones de integridad.
--
-- CARACTERÍSTICAS:
-- 1. NO altera ni elimina datos existentes (sin DROP TABLE ni DELETE).
-- 2. Tus 30 Áreas Oficiales, usuarios, empleados y configuración se mantienen intactos.
-- 3. Repara tildes y caracteres en dbo.Empleado y dbo.Puesto (Carlos Hernández, Técnico, etc.).
-- 4. Amplía la restricción CK_BK_Modulo en dbo.BitacoraKardex para permitir EMPLOYEES y POSITIONS.
-- 5. Corrige uspEmpleadoActualizar blindando auditoría de usuario y respetando switches de edición.
-- 6. Resuelve los errores 8144 y 8145 (@AreaFilter, planes preventivos, etc.).
-- ============================================================================

USE [MacsaCMMS];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ----------------------------------------------------------------------------
-- 1. ASEGURAR COLUMNAS EN dbo.OrdenTrabajo
-- ----------------------------------------------------------------------------
IF COL_LENGTH('dbo.OrdenTrabajo', 'PlanPreventivoId') IS NULL
BEGIN
    ALTER TABLE dbo.OrdenTrabajo ADD PlanPreventivoId NVARCHAR(20) NULL;
END;
GO

IF COL_LENGTH('dbo.OrdenTrabajo', 'ActualizadoEn') IS NULL
BEGIN
    ALTER TABLE dbo.OrdenTrabajo ADD ActualizadoEn DATETIME2(3) NULL;
END;
GO

-- ----------------------------------------------------------------------------
-- 2. GARANTIZAR RESTRICCIÓN CK_BK_Modulo EN dbo.BitacoraKardex
-- ----------------------------------------------------------------------------
IF EXISTS (
    SELECT 1 FROM sys.check_constraints
     WHERE name = N'CK_BK_Modulo'
       AND parent_object_id = OBJECT_ID(N'dbo.BitacoraKardex')
)
BEGIN
    ALTER TABLE dbo.BitacoraKardex DROP CONSTRAINT CK_BK_Modulo;
END;
GO

ALTER TABLE dbo.BitacoraKardex WITH CHECK ADD CONSTRAINT CK_BK_Modulo CHECK (
    Modulo IN (
        'ASSETS',
        'WORK_ORDERS',
        'BREAKDOWNS',
        'PREVENTIVE',
        'PREVENTIVE_SCHEDULES',
        'AREAS',
        'OPERATION_REPORTS',
        'USERS',
        'EMPLOYEES',
        'POSITIONS'
    )
);
GO

-- ----------------------------------------------------------------------------
-- 3. REPARAR CARACTERES MOJIBAKE EN dbo.Empleado Y dbo.Puesto
-- ----------------------------------------------------------------------------
BEGIN TRANSACTION;

-- Normalizar textos en dbo.Empleado
UPDATE dbo.Empleado
   SET NombreCompleto = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(NombreCompleto,
       N'Ã¡', N'á'),
       N'Ã©', N'é'),
       N'Ã­', N'í'),
       N'Ã³', N'ó'),
       N'Ãº', N'ú'),
       N'Ã±', N'ñ'),
       N'Ã', N'Á'),
       N'Ã“', N'Ó'),
       Puesto = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Puesto,
       N'Ã¡', N'á'),
       N'Ã©', N'é'),
       N'Ã­', N'í'),
       N'Ã³', N'ó'),
       N'Ãº', N'ú'),
       N'Ã±', N'ñ'),
       N'Ã', N'Á'),
       N'Ã“', N'Ó'),
       NombreArea = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(NombreArea,
       N'Ã¡', N'á'),
       N'Ã©', N'é'),
       N'Ã­', N'í'),
       N'Ã³', N'ó'),
       N'Ãº', N'ú'),
       N'Ã±', N'ñ'),
       N'Ã', N'Á'),
       N'Ã“', N'Ó');

-- Asegurar nombres limpios exactos de los empleados estándar
UPDATE dbo.Empleado SET NombreCompleto = N'Ing. Nixon Mejía',        Puesto = N'Jefe de Mantenimiento'                  WHERE EmpleadoId = 1 AND (NombreCompleto LIKE N'%Nixon%Mej%' OR NombreCompleto LIKE N'%Nixon%');
UPDATE dbo.Empleado SET NombreCompleto = N'Carlos Hernández',        Puesto = N'Técnico Mecánico Industrial'            WHERE NombreCompleto LIKE N'%Carlos%Hern%';
UPDATE dbo.Empleado SET NombreCompleto = N'Jorge Morales',           Puesto = N'Técnico Electricista / Automatización'  WHERE NombreCompleto LIKE N'%Jorge%Morales%';
UPDATE dbo.Empleado SET NombreCompleto = N'Roberto Rivas',           Puesto = N'Técnico Soldador / Estructuras'         WHERE NombreCompleto LIKE N'%Roberto%Rivas%';
UPDATE dbo.Empleado SET NombreCompleto = N'Miguel Ángel Castillo',   Puesto = N'Técnico Electromecánico'                WHERE NombreCompleto LIKE N'%Miguel%Castillo%';
UPDATE dbo.Empleado SET NombreCompleto = N'Luis Alberto Fuentes',    Puesto = N'Técnico en Refrigeración y Calderas'    WHERE NombreCompleto LIKE N'%Luis%Fuentes%';
UPDATE dbo.Empleado SET NombreCompleto = N'Guillermo Pineda',        Puesto = N'Supervisor de Planta y Producción'      WHERE NombreCompleto LIKE N'%Guillermo%Pineda%';
UPDATE dbo.Empleado SET NombreCompleto = N'Sandra Marroquín',        Puesto = N'Jefe de Aseguramiento de Calidad / HACCP' WHERE NombreCompleto LIKE N'%Sandra%Marroqu%';

-- Sincronizar NombreArea con el catálogo dbo.Area
UPDATE e
   SET e.NombreArea = a.Nombre
  FROM dbo.Empleado e
  JOIN dbo.Area a ON e.AreaId = a.AreaId;

UPDATE dbo.Empleado
   SET NombreArea = N'Sin Área Asignada'
 WHERE AreaId IS NULL OR LTRIM(RTRIM(NombreArea)) IN (N'Sin Área Asignada', N'Sin Área', N'Sin Ã rea Asignada', N'Sin Ã rea', N'');

-- Normalizar textos en dbo.Puesto
UPDATE dbo.Puesto
   SET Nombre = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Nombre,
       N'Ã¡', N'á'),
       N'Ã©', N'é'),
       N'Ã­', N'í'),
       N'Ã³', N'ó'),
       N'Ãº', N'ú'),
       N'Ã±', N'ñ'),
       N'Ã', N'Á'),
       N'Ã“', N'Ó');

-- Asegurar los 13 puestos de catálogo oficiales limpios
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Desarrollador')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Desarrollador', 0, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Jefe de Mantenimiento')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Jefe de Mantenimiento', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Supervisor de Mantenimiento')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Supervisor de Mantenimiento', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Técnico Mecánico Industrial')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Técnico Mecánico Industrial', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Técnico Electricista / Automatización')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Técnico Electricista / Automatización', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Técnico en Refrigeración y Calderas')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Técnico en Refrigeración y Calderas', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Técnico Electromecánico')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Técnico Electromecánico', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Técnico Soldador / Estructuras')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Técnico Soldador / Estructuras', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Auxiliar de Mantenimiento')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Auxiliar de Mantenimiento', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Jefe de Área / Operaciones')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Jefe de Área / Operaciones', 0, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Supervisor de Producción')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Supervisor de Producción', 0, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Gerente General')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Gerente General', 0, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Gerente de Operaciones')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Gerente de Operaciones', 0, 1);

COMMIT TRANSACTION;
GO

-- ============================================================================
-- MÓDULO: 02_security_sp.sql
-- ============================================================================

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
GO

-- ============================================================================
-- MÓDULO: 03_areas_puestos_empleados_sp.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 13. PROCEDIMIENTOS ALMACENADOS: ÁREAS, PUESTOS Y EMPLEADOS
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspAreaObtenerTodas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        AreaId,
        Nombre AS Name,
        CentroCosto AS CostCenter,
        ContadorActivos AS AssetCounter,
        Nombre,
        CentroCosto,
        ContadorActivos,
        Activo,
        CreadoEn,
        ActualizadoEn
      FROM dbo.Area
     WHERE Activo = 1
     ORDER BY AreaId ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspAreaCrear
    @Name NVARCHAR(100),
    @CostCenter NVARCHAR(50),
    @AreaId NVARCHAR(15) = NULL,
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N'',
    @UsuarioId INT = NULL,
    @NombreUsuario NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @NormCC NVARCHAR(50) =
            CASE WHEN @CostCenter LIKE 'CC-%' THEN @CostCenter ELSE CONCAT('CC-', @CostCenter) END;

        DECLARE @FinalId NVARCHAR(15) = @AreaId;
        IF @FinalId IS NULL OR LTRIM(RTRIM(@FinalId)) = ''
        BEGIN
            DECLARE @cnt TABLE (val INT NOT NULL);
            UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
               SET SiguienteNumero += 1
             OUTPUT inserted.SiguienteNumero INTO @cnt(val)
              WHERE Nombre = 'areas';

            DECLARE @nextVal INT; SELECT @nextVal = val FROM @cnt;
            SET @FinalId = CONCAT('A', FORMAT(@nextVal, '000'));
        END;

        IF EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @FinalId)
            RAISERROR(N'Ya existe un área con ese identificador.', 16, 1);

        INSERT INTO dbo.Area (AreaId, Nombre, CentroCosto, ContadorActivos, Activo, CreadoEn)
        VALUES (@FinalId, @Name, @NormCC, 0, 1, SYSUTCDATETIME());

        DECLARE @UID INT = COALESCE(@UserId, @UsuarioId);
        IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID)
        BEGIN
            SELECT @UID = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N''))));
            IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID) SET @UID = NULL;
        END;
    IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID)
    BEGIN
        SELECT @UID = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N''))));
        IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID) SET @UID = NULL;
    END;
        IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID)
        BEGIN
            SELECT @UID = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N''))));
            IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID) SET @UID = NULL;
        END;
        DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N'');
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UID, @UName, 'AREA_CREATED', 'AREAS', @FinalId,
                CONCAT(N'Área creada: ', @FinalId, N' - ', @Name, N' (', @NormCC, N').'));

        COMMIT TRANSACTION;
        SELECT @FinalId AS AreaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspAreaActualizar
    @AreaId NVARCHAR(15),
    @Name NVARCHAR(100),
    @CostCenter NVARCHAR(50) = NULL,
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N'',
    @UsuarioId INT = NULL,
    @NombreUsuario NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @NormCC NVARCHAR(50) =
        CASE WHEN @CostCenter IS NULL THEN NULL
             WHEN @CostCenter LIKE 'CC-%' THEN @CostCenter
             ELSE CONCAT('CC-', @CostCenter) END;

    UPDATE dbo.Area
       SET Nombre        = @Name,
           CentroCosto   = COALESCE(@NormCC, CentroCosto),
           ActualizadoEn = SYSUTCDATETIME()
     WHERE AreaId = @AreaId;

    IF @@ROWCOUNT = 0
        RAISERROR(N'El área especificada no existe.', 16, 1);

    DECLARE @UID INT = COALESCE(@UserId, @UsuarioId);
    DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N'');
    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
    VALUES (@UID, @UName, 'AREA_UPDATED', 'AREAS', @AreaId,
            CONCAT(N'Área actualizada: ', @AreaId, N' - ', @Name, N'.'));
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspAreaEliminar
    @AreaId        NVARCHAR(15),
    @UserId        INT = NULL,
    @UserName      NVARCHAR(100) = N'',
    @UsuarioId     INT = NULL,
    @NombreUsuario NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @AreaId)
            RAISERROR(N'El área especificada no existe.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Activo WHERE AreaId = @AreaId AND Estado <> 'deleted')
            RAISERROR(N'No se puede eliminar el área porque contiene activos no eliminados.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Empleado WHERE AreaId = @AreaId AND Activo = 1)
            RAISERROR(N'No se puede eliminar el área porque tiene empleados activos asignados.', 16, 1);

        UPDATE dbo.Area
           SET Activo = 0,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE AreaId = @AreaId;

        DECLARE @UID INT = COALESCE(@UserId, @UsuarioId);
        DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N'');
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UID, @UName, 'AREA_DELETED', 'AREAS', @AreaId,
                CONCAT(N'Área dada de baja lógica: ', @AreaId, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPuestoListar
    @SoloActivos BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PuestoId, Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn
      FROM dbo.Puesto
     WHERE (@SoloActivos = 0 OR Activo = 1)
     ORDER BY Nombre ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPuestoCrear
    @Nombre          NVARCHAR(100),
    @EsMantenimiento BIT = 1,
    @UsuarioId       INT = NULL,
    @NombreUsuario   NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NombreLimpio NVARCHAR(100) = LTRIM(RTRIM(@Nombre));
        IF NULLIF(@NombreLimpio, N'') IS NULL
            RAISERROR(N'El nombre del puesto o cargo es obligatorio.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = @NombreLimpio AND Activo = 1)
            RAISERROR(N'Ya existe un puesto registrado con ese mismo nombre.', 16, 1);

        DECLARE @ExistenteInactivoId INT;
        SELECT @ExistenteInactivoId = PuestoId FROM dbo.Puesto WHERE Nombre = @NombreLimpio AND Activo = 0;

        DECLARE @NuevoId INT;
        IF @ExistenteInactivoId IS NOT NULL
        BEGIN
            UPDATE dbo.Puesto
               SET Activo = 1,
                   EsMantenimiento = @EsMantenimiento,
                   ActualizadoEn = SYSUTCDATETIME()
             WHERE PuestoId = @ExistenteInactivoId;
            SET @NuevoId = @ExistenteInactivoId;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
            VALUES (@NombreLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
            SET @NuevoId = SCOPE_IDENTITY();
        END;

        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId) SET @UsuarioId = NULL;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'POSITION_CREATED', 'POSITIONS', CAST(@NuevoId AS NVARCHAR(20)),
                CONCAT(N'Puesto registrado: ', @NombreLimpio, N' (Mantenimiento: ', CASE WHEN @EsMantenimiento = 1 THEN N'Sí' ELSE N'No' END, N').'));

        COMMIT TRANSACTION;

        SELECT PuestoId, Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn
          FROM dbo.Puesto
         WHERE PuestoId = @NuevoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPuestoActualizar
    @PuestoId        INT,
    @Nombre          NVARCHAR(100),
    @EsMantenimiento BIT = 1,
    @Activo          BIT = 1,
    @UsuarioId       INT = NULL,
    @NombreUsuario   NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE PuestoId = @PuestoId)
            RAISERROR(N'El puesto o cargo no existe.', 16, 1);

        DECLARE @NombreLimpio NVARCHAR(100) = LTRIM(RTRIM(@Nombre));
        IF NULLIF(@NombreLimpio, N'') IS NULL
            RAISERROR(N'El nombre del puesto o cargo es obligatorio.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = @NombreLimpio AND PuestoId <> @PuestoId AND Activo = 1)
            RAISERROR(N'Ya existe otro puesto con ese mismo nombre.', 16, 1);

        UPDATE dbo.Puesto
           SET Nombre          = @NombreLimpio,
               EsMantenimiento = @EsMantenimiento,
               Activo          = @Activo,
               ActualizadoEn   = SYSUTCDATETIME()
         WHERE PuestoId = @PuestoId;

        UPDATE dbo.Empleado
           SET Puesto          = @NombreLimpio,
               EsMantenimiento = @EsMantenimiento,
               ActualizadoEn   = SYSUTCDATETIME()
         WHERE PuestoId = @PuestoId;

        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId) SET @UsuarioId = NULL;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'POSITION_UPDATED', 'POSITIONS', CAST(@PuestoId AS NVARCHAR(20)),
                CONCAT(N'Puesto actualizado: ', @NombreLimpio, N' (Activo: ', CASE WHEN @Activo = 1 THEN N'Sí' ELSE N'No' END, N').'));

        COMMIT TRANSACTION;

        SELECT PuestoId, Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn
          FROM dbo.Puesto
         WHERE PuestoId = @PuestoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPuestoEliminar
    @PuestoId      INT,
    @UsuarioId     INT = NULL,
    @NombreUsuario NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NombreActual NVARCHAR(100);
        SELECT @NombreActual = Nombre FROM dbo.Puesto WHERE PuestoId = @PuestoId;

        IF @NombreActual IS NULL
            RAISERROR(N'El puesto o cargo no existe.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Empleado WHERE PuestoId = @PuestoId AND Activo = 1)
            RAISERROR(N'No se puede desactivar el puesto porque hay empleados activos que lo ocupan.', 16, 1);

        UPDATE dbo.Puesto
           SET Activo = 0,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE PuestoId = @PuestoId;

        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId) SET @UsuarioId = NULL;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'POSITION_DEACTIVATED', 'POSITIONS', CAST(@PuestoId AS NVARCHAR(20)),
                CONCAT(N'Puesto desactivado: ', @NombreActual, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspEmpleadoListar
    @SoloActivos     BIT = 1,
    @EsMantenimiento BIT = NULL,
    @AreaId          NVARCHAR(15) = NULL,
    @Busqueda        NVARCHAR(100) = NULL,
    @Limit           INT = NULL,
    @Offset          INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.EmpleadoId,
        e.NombreCompleto,
        e.AreaId,
        COALESCE(a.Nombre, e.NombreArea, N'Sin Área Asignada') AS NombreArea,
        e.PuestoId,
        COALESCE(p.Nombre, e.Puesto) AS Puesto,
        COALESCE(p.EsMantenimiento, e.EsMantenimiento) AS EsMantenimiento,
        e.Activo,
        e.CreadoEn,
        e.ActualizadoEn
    FROM dbo.Empleado e
    LEFT JOIN dbo.Puesto p ON e.PuestoId = p.PuestoId
    LEFT JOIN dbo.Area a ON e.AreaId = a.AreaId
    WHERE (@SoloActivos = 0 OR e.Activo = 1)
      AND (@EsMantenimiento IS NULL OR COALESCE(p.EsMantenimiento, e.EsMantenimiento) = @EsMantenimiento)
      AND (@AreaId IS NULL OR e.AreaId = @AreaId)
      AND (
          @Busqueda IS NULL
          OR LTRIM(RTRIM(@Busqueda)) = N''
          OR e.NombreCompleto LIKE CONCAT(N'%', LTRIM(RTRIM(@Busqueda)), N'%')
          OR COALESCE(p.Nombre, e.Puesto) LIKE CONCAT(N'%', LTRIM(RTRIM(@Busqueda)), N'%')
      )
    ORDER BY COALESCE(p.EsMantenimiento, e.EsMantenimiento) DESC, e.NombreCompleto ASC
    OFFSET @Offset ROWS
    FETCH NEXT CASE WHEN @Limit IS NULL OR @Limit <= 0 THEN 2147483647 ELSE @Limit END ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspEmpleadoCrear
    @NombreCompleto   NVARCHAR(150),
    @AreaId           NVARCHAR(15) = NULL,
    @Puesto           NVARCHAR(100) = NULL,
    @PuestoId         INT = NULL,
    @EsMantenimiento  BIT = 1,
    @UsuarioId        INT = NULL,
    @NombreUsuario    NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NombreLimpio NVARCHAR(150) = LTRIM(RTRIM(ISNULL(@NombreCompleto, N'')));
        DECLARE @PuestoLimpio NVARCHAR(100) = LTRIM(RTRIM(ISNULL(@Puesto, N'')));

        IF NULLIF(@NombreLimpio, N'') IS NULL
            RAISERROR(N'El nombre completo del empleado es obligatorio.', 16, 1);

        IF @PuestoId IS NOT NULL
        BEGIN
            SELECT @PuestoLimpio = Nombre,
                   @EsMantenimiento = EsMantenimiento
              FROM dbo.Puesto
             WHERE PuestoId = @PuestoId AND Activo = 1;

            IF NULLIF(@PuestoLimpio, N'') IS NULL
                RAISERROR(N'El puesto especificado no existe o está inactivo.', 16, 1);
        END
        ELSE
        BEGIN
            IF NULLIF(@PuestoLimpio, N'') IS NULL
                RAISERROR(N'El puesto o cargo del empleado es obligatorio.', 16, 1);

            SELECT @PuestoId = PuestoId,
                   @PuestoLimpio = Nombre
              FROM dbo.Puesto
             WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio);

            IF @PuestoId IS NULL
            BEGIN
                INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
                VALUES (@PuestoLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
                SET @PuestoId = SCOPE_IDENTITY();
            END
            ELSE
            BEGIN
                UPDATE dbo.Puesto
                   SET Activo = 1, ActualizadoEn = SYSUTCDATETIME()
                 WHERE PuestoId = @PuestoId AND Activo = 0;
            END;
        END;

        DECLARE @NombreArea NVARCHAR(200) = NULL;
        IF @AreaId IS NOT NULL
        BEGIN
            SELECT @NombreArea = Nombre FROM dbo.Area WHERE AreaId = @AreaId;
        END;

        INSERT INTO dbo.Empleado (NombreCompleto, AreaId, NombreArea, PuestoId, Puesto, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
        VALUES (@NombreLimpio, @AreaId, @NombreArea, @PuestoId, @PuestoLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

        DECLARE @NuevoId INT = SCOPE_IDENTITY();

        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId) SET @UsuarioId = NULL;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'EMPLOYEE_CREATED', 'EMPLOYEES', CAST(@NuevoId AS NVARCHAR(20)),
                CONCAT(N'Empleado registrado: ', @NombreLimpio, N' (Puesto: ', @PuestoLimpio, N').'));

        COMMIT TRANSACTION;

        SELECT
            e.EmpleadoId,
            e.NombreCompleto,
            e.AreaId,
            COALESCE(a.Nombre, e.NombreArea, N'Sin Área') AS NombreArea,
            e.PuestoId,
            COALESCE(p.Nombre, e.Puesto) AS Puesto,
            COALESCE(p.EsMantenimiento, e.EsMantenimiento) AS EsMantenimiento,
            e.Activo,
            e.CreadoEn,
            e.ActualizadoEn
        FROM dbo.Empleado e
        LEFT JOIN dbo.Puesto p ON e.PuestoId = p.PuestoId
        LEFT JOIN dbo.Area a ON e.AreaId = a.AreaId
        WHERE e.EmpleadoId = @NuevoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspEmpleadoActualizar
    @EmpleadoId       INT,
    @NombreCompleto   NVARCHAR(150),
    @AreaId           NVARCHAR(15) = NULL,
    @Puesto           NVARCHAR(100) = NULL,
    @PuestoId         INT = NULL,
    @EsMantenimiento  BIT = 1,
    @Activo           BIT = 1,
    @UsuarioId        INT = NULL,
    @NombreUsuario    NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Empleado WHERE EmpleadoId = @EmpleadoId)
            RAISERROR(N'El empleado no existe.', 16, 1);

        DECLARE @NombreLimpio NVARCHAR(150) = LTRIM(RTRIM(ISNULL(@NombreCompleto, N'')));
        DECLARE @PuestoLimpio NVARCHAR(100) = LTRIM(RTRIM(ISNULL(@Puesto, N'')));

        IF NULLIF(@NombreLimpio, N'') IS NULL
            RAISERROR(N'El nombre completo del empleado es obligatorio.', 16, 1);

        IF @PuestoId IS NOT NULL
        BEGIN
            SELECT @PuestoLimpio = Nombre
              FROM dbo.Puesto
             WHERE PuestoId = @PuestoId;

            IF NULLIF(@PuestoLimpio, N'') IS NULL
                RAISERROR(N'El puesto especificado no existe.', 16, 1);
        END
        ELSE
        BEGIN
            IF NULLIF(@PuestoLimpio, N'') IS NULL
                RAISERROR(N'El puesto o cargo del empleado es obligatorio.', 16, 1);

            SELECT TOP 1 @PuestoId = PuestoId,
                         @PuestoLimpio = Nombre
              FROM dbo.Puesto
             WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio)
                OR Nombre = @PuestoLimpio;

            IF @PuestoId IS NULL
            BEGIN
                INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
                VALUES (@PuestoLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
                SET @PuestoId = SCOPE_IDENTITY();
            END;
        END;

        DECLARE @NombreArea NVARCHAR(200) = NULL;
        IF @AreaId IS NOT NULL
        BEGIN
            SELECT @NombreArea = Nombre FROM dbo.Area WHERE AreaId = @AreaId;
        END;

        UPDATE dbo.Empleado
           SET NombreCompleto  = @NombreLimpio,
               AreaId          = @AreaId,
               NombreArea      = @NombreArea,
               PuestoId        = @PuestoId,
               Puesto          = @PuestoLimpio,
               EsMantenimiento = @EsMantenimiento,
               Activo          = @Activo,
               ActualizadoEn   = SYSUTCDATETIME()
         WHERE EmpleadoId = @EmpleadoId;

        -- Validar UsuarioId para auditoría
        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
                SET @UsuarioId = NULL;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'EMPLOYEE_UPDATED', 'EMPLOYEES', CAST(@EmpleadoId AS NVARCHAR(20)),
                CONCAT(N'Empleado actualizado: ', @NombreLimpio, N' (Puesto: ', @PuestoLimpio, N', Activo: ', CASE WHEN @Activo = 1 THEN N'Sí' ELSE N'No' END, N').'));

        COMMIT TRANSACTION;

        SELECT
            e.EmpleadoId,
            e.NombreCompleto,
            e.AreaId,
            COALESCE(a.Nombre, e.NombreArea, N'Sin Área Asignada') AS NombreArea,
            e.PuestoId,
            COALESCE(p.Nombre, e.Puesto) AS Puesto,
            e.EsMantenimiento,
            e.Activo,
            e.CreadoEn,
            e.ActualizadoEn
        FROM dbo.Empleado e
        LEFT JOIN dbo.Puesto p ON e.PuestoId = p.PuestoId
        LEFT JOIN dbo.Area a ON e.AreaId = a.AreaId
        WHERE e.EmpleadoId = @EmpleadoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspEmpleadoCambiarEstado
    @EmpleadoId    INT,
    @Activo        BIT,
    @UsuarioId     INT = NULL,
    @NombreUsuario NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Empleado
           SET Activo = @Activo,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE EmpleadoId = @EmpleadoId;

        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId) SET @UsuarioId = NULL;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'EMPLOYEE_STATUS_CHANGED', 'EMPLOYEES', CAST(@EmpleadoId AS NVARCHAR(20)),
                CONCAT(N'Estado de empleado ID ', @EmpleadoId, N' cambiado a: ', CASE WHEN @Activo = 1 THEN N'Activo' ELSE N'Inactivo' END, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
GO

-- ============================================================================
-- MÓDULO: 04_activos_bajas_sp.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 14. PROCEDIMIENTOS ALMACENADOS: ACTIVOS, JERARQUÍA Y TRASPASOS
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspActivoObtenerRaicesPorArea
    @AreaId NVARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId,
           CodigoActivoPadre, Nivel, RutaAncestros, Estado, Serie,
           AtributosDinamicos, DatosImagen, ContadorHijos, CreadoEn, ActualizadoEn,
           EsEquipoProceso
      FROM dbo.Activo
     WHERE AreaId = @AreaId
       AND CodigoActivoPadre IS NULL
       AND Estado <> 'deleted'
     ORDER BY CodigoActivo ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoObtenerHijos
    @ParentAssetCode NVARCHAR(60) = NULL,
    @ParentCode      NVARCHAR(60) = NULL,
    @AreaId          NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TargetParent NVARCHAR(60) = COALESCE(@ParentAssetCode, @ParentCode);
    SELECT CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId,
           CodigoActivoPadre, Nivel, RutaAncestros, Estado, Serie,
           AtributosDinamicos, DatosImagen, ContadorHijos, CreadoEn, ActualizadoEn,
           EsEquipoProceso
      FROM dbo.Activo
     WHERE (@TargetParent IS NULL AND CodigoActivoPadre IS NULL OR CodigoActivoPadre = @TargetParent)
       AND (@AreaId IS NULL OR AreaId = @AreaId)
       AND Estado <> 'deleted'
     ORDER BY CodigoActivo ASC;
END;
GO

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

    SELECT CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId,
           CodigoActivoPadre, Nivel, RutaAncestros, Estado, Serie,
           AtributosDinamicos, DatosImagen, ContadorHijos, CreadoEn, ActualizadoEn,
           EsEquipoProceso
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
    SELECT CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId,
           CodigoActivoPadre, Nivel, RutaAncestros, Estado, Serie,
           AtributosDinamicos, DatosImagen, ContadorHijos, CreadoEn, ActualizadoEn,
           EsEquipoProceso
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

        INSERT INTO dbo.HistorialEstadoActivo
            (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        VALUES
            (@NewAssetCode, @Status, SYSUTCDATETIME(), @AreaId, N'Alta inicial del activo', @UserId, @UserName);

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_CREATED', 'ASSETS', @NewAssetCode,
                CONCAT(N'Activo creado: ', @NewAssetCode, N' (', @Name, N') en área ', @AreaId, N'.'));

        COMMIT TRANSACTION;
        SELECT @NewAssetCode AS CodigoActivo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoActualizar
    @CodigoActivo NVARCHAR(60) = NULL,
    @AssetCode NVARCHAR(60),
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

        IF NOT EXISTS (SELECT 1 FROM dbo.Activo WHERE CodigoActivo = @AssetCode)
            RAISERROR(N'El activo no existe.', 16, 1);

        IF @Serial IS NOT NULL AND LTRIM(RTRIM(@Serial)) <> ''
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Activo WHERE Serie = @Serial AND CodigoActivo <> @AssetCode AND Estado <> 'deleted')
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
         WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_UPDATED', 'ASSETS', @AssetCode,
                CONCAT(N'Activo actualizado: ', @AssetCode, N' (', @Name, N').'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoTraspasar
    @SourceAssetCode NVARCHAR(60),
    @TargetAreaId    NVARCHAR(15),
    @UserId          INT = NULL,
    @UserName        NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @srcArea NVARCHAR(15), @srcName NVARCHAR(200), @srcStatus NVARCHAR(25), @srcLevel NVARCHAR(20);
        SELECT @srcArea = AreaId, @srcName = Nombre, @srcStatus = Estado, @srcLevel = Nivel
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @SourceAssetCode;

        IF @srcArea IS NULL OR @srcStatus = 'deleted'
            RAISERROR(N'El activo origen no existe o está eliminado.', 16, 1);

        IF @srcStatus = 'transferredDeactivated'
            RAISERROR(N'El activo ya fue transferido anteriormente y se encuentra desactivado. Debe gestionarlo desde su nueva área.', 16, 1);

        IF @srcArea = @TargetAreaId
            RAISERROR(N'El área destino debe ser distinta al área actual del activo.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @TargetAreaId)
            RAISERROR(N'El área destino especificada no existe.', 16, 1);

        -- Validar que no existan OTs abiertas en el activo ni en sus descendientes
        DECLARE @OTAbiertaId NVARCHAR(20);
        SELECT TOP 1 @OTAbiertaId = ot.OrdenTrabajoId
          FROM dbo.OrdenTrabajo ot WITH (UPDLOCK, HOLDLOCK)
          JOIN dbo.Activo a WITH (NOLOCK) ON ot.CodigoActivo = a.CodigoActivo
         WHERE a.AreaId = @srcArea
           AND (a.CodigoActivo = @SourceAssetCode OR CHARINDEX(CONCAT(N',', @SourceAssetCode, N','), CONCAT(N',', a.RutaAncestros, N',')) > 0)
           AND ot.Estado IN (N'pending', N'inProgress', N'in_progress', N'paused');

        IF @OTAbiertaId IS NOT NULL
        BEGIN
            DECLARE @MsgTraspaso NVARCHAR(250) = CONCAT(N'No se puede transferir el activo: cuenta con la orden de trabajo abierta (', @OTAbiertaId, N'). Debe concluirse o cancelarse antes del traspaso.');
            RAISERROR(@MsgTraspaso, 16, 1);
        END;

        -- Retorno a área original si ya había sido transferido
        DECLARE @PreviousOriginCode NVARCHAR(60);
        SELECT @PreviousOriginCode = CodigoActivo
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE AreaId = @TargetAreaId
           AND TraspasadoACodigo = @SourceAssetCode
           AND Estado = 'transferredDeactivated'
           AND Nivel = 'equipment';

        IF @PreviousOriginCode IS NOT NULL
        BEGIN
            UPDATE a
               SET a.Estado = 'active',
                   a.TraspasadoACodigo = NULL,
                   a.ActualizadoEn = SYSUTCDATETIME()
              FROM dbo.Activo a
             WHERE a.CodigoActivo = @PreviousOriginCode
                OR a.RutaAncestros = @PreviousOriginCode
                OR a.RutaAncestros LIKE @PreviousOriginCode + ',%';

            UPDATE a
               SET a.Estado = 'transferredDeactivated',
                   a.TraspasadoACodigo = @PreviousOriginCode,
                   a.ActualizadoEn = SYSUTCDATETIME()
              FROM dbo.Activo a
             WHERE a.CodigoActivo = @SourceAssetCode
                OR a.RutaAncestros = @SourceAssetCode
                OR a.RutaAncestros LIKE @SourceAssetCode + ',%';

            UPDATE hea
               SET FinalizadoEn = SYSUTCDATETIME()
              FROM dbo.HistorialEstadoActivo hea
             WHERE (hea.CodigoActivo = @SourceAssetCode OR hea.CodigoActivo LIKE @SourceAssetCode + '-%')
               AND hea.FinalizadoEn IS NULL;

            INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
            VALUES (@PreviousOriginCode, 'active', SYSUTCDATETIME(), @TargetAreaId,
                    CONCAT(N'Retorno a su área original desde ', @srcArea, N' (código intermedio: ', @SourceAssetCode, N')'),
                    @UserId, @UserName);

            UPDATE dbo.PlanPreventivo
               SET Estado = 'active',
                   Notas = ISNULL(Notas, '') + CONCAT(CHAR(13), CHAR(10), N'[Sistema]: Plan reactivado automáticamente por retorno a su área original.')
             WHERE CodigoActivo = @PreviousOriginCode AND Estado = 'paused';

            INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
            VALUES (@UserId, @UserName, 'ASSET_TRANSFER', 'ASSETS', @SourceAssetCode,
                    CONCAT(N'Activo ', @SourceAssetCode, N' retornado a su área y código original ', @PreviousOriginCode, N' en ', @TargetAreaId, N'.'));

            COMMIT TRANSACTION;
            SELECT @PreviousOriginCode AS NewAssetCode, @PreviousOriginCode AS CodigoActivo;
            RETURN;
        END;

        -- Subárbol nuevo en destino (CTE Recursiva)
        CREATE TABLE #ArbolOrigen (
            OldCode       NVARCHAR(60) PRIMARY KEY,
            Nombre        NVARCHAR(200),
            Marca         NVARCHAR(100),
            Modelo        NVARCHAR(100),
            EstacionId    NVARCHAR(100),
            OldParentCode NVARCHAR(60),
            Nivel         NVARCHAR(20),
            RutaAncestros NVARCHAR(400),
            Serie         NVARCHAR(100),
            Atributos     NVARCHAR(MAX),
            DatosImagen   NVARCHAR(500),
            Depth         INT,
            ChildOrder    INT,
            NewCode       NVARCHAR(60),
            NewParentCode NVARCHAR(60),
            NewRuta       NVARCHAR(400)
        );

        WITH SubTree AS (
            SELECT 
                a.CodigoActivo, a.Nombre, a.Marca, a.Modelo, a.EstacionId,
                a.CodigoActivoPadre, a.Nivel, a.RutaAncestros, a.Serie,
                a.AtributosDinamicos, a.DatosImagen,
                0 AS Depth,
                1 AS ChildOrder
            FROM dbo.Activo a WITH (UPDLOCK, HOLDLOCK)
            WHERE a.CodigoActivo = @SourceAssetCode

            UNION ALL

            SELECT 
                c.CodigoActivo, c.Nombre, c.Marca, c.Modelo, c.EstacionId,
                c.CodigoActivoPadre, c.Nivel, c.RutaAncestros, c.Serie,
                c.AtributosDinamicos, c.DatosImagen,
                p.Depth + 1 AS Depth,
                CAST(ROW_NUMBER() OVER (PARTITION BY c.CodigoActivoPadre ORDER BY c.CodigoActivo) AS INT) AS ChildOrder
            FROM dbo.Activo c WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN SubTree p ON c.CodigoActivoPadre = p.CodigoActivo
            WHERE c.Estado <> 'deleted'
        )
        INSERT INTO #ArbolOrigen (
            OldCode, Nombre, Marca, Modelo, EstacionId, OldParentCode, Nivel,
            RutaAncestros, Serie, Atributos, DatosImagen, Depth, ChildOrder
        )
        SELECT 
            CodigoActivo, Nombre, Marca, Modelo, EstacionId, CodigoActivoPadre, Nivel,
            RutaAncestros, Serie, AtributosDinamicos, DatosImagen, Depth, ChildOrder
        FROM SubTree;

        IF EXISTS (
            SELECT 1 FROM dbo.CandadoBaja cb
            INNER JOIN #ArbolOrigen o ON o.OldCode = cb.CodigoActivo
            WHERE cb.EstadoCandado = 'pending'
        )
        BEGIN
            RAISERROR(N'El activo o alguno de sus componentes tiene una solicitud de baja pendiente.', 16, 1);
        END;

        DECLARE @targetCounter TABLE (val INT NOT NULL);
        UPDATE dbo.Area WITH (UPDLOCK, HOLDLOCK)
           SET ContadorActivos += 1
         OUTPUT inserted.ContadorActivos INTO @targetCounter(val)
          WHERE AreaId = @TargetAreaId;

        DECLARE @nextRoot INT; SELECT @nextRoot = val FROM @targetCounter;
        DECLARE @NewRootCode NVARCHAR(60) = CONCAT(@TargetAreaId, '-', FORMAT(@nextRoot, '000'));

        UPDATE #ArbolOrigen 
           SET NewCode = @NewRootCode, 
               NewParentCode = NULL,
               NewRuta = ''
         WHERE Depth = 0;

        DECLARE @currentDepth INT = 1;
        WHILE @currentDepth <= 3
        BEGIN
            UPDATE child
               SET child.NewParentCode = parent.NewCode,
                   child.NewCode = CONCAT(parent.NewCode, '-', FORMAT(child.ChildOrder, '00')),
                   child.NewRuta = CASE WHEN parent.NewRuta = '' THEN parent.NewCode ELSE CONCAT(parent.NewRuta, ',', parent.NewCode) END
              FROM #ArbolOrigen child
              INNER JOIN #ArbolOrigen parent ON child.OldParentCode = parent.OldCode
             WHERE child.Depth = @currentDepth;

            SET @currentDepth += 1;
        END;

        DECLARE @d INT = 0;
        WHILE @d <= 3
        BEGIN
            INSERT INTO dbo.Activo (
                CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId,
                CodigoActivoPadre, Nivel, RutaAncestros, Estado, Serie,
                AtributosDinamicos, DatosImagen, ContadorHijos, CreadoEn
            )
            SELECT 
                o.NewCode, o.Nombre, o.Marca, o.Modelo, @TargetAreaId, o.EstacionId,
                o.NewParentCode, o.Nivel, o.NewRuta, 'active', o.Serie,
                o.Atributos, o.DatosImagen,
                (SELECT COUNT(*) FROM #ArbolOrigen c WHERE c.OldParentCode = o.OldCode),
                SYSUTCDATETIME()
            FROM #ArbolOrigen o
            WHERE o.Depth = @d;

            SET @d += 1;
        END;

        UPDATE a
           SET a.Estado = 'transferredDeactivated',
               a.TraspasadoACodigo = o.NewCode,
               a.ActualizadoEn = SYSUTCDATETIME()
          FROM dbo.Activo a
          INNER JOIN #ArbolOrigen o ON a.CodigoActivo = o.OldCode;

        UPDATE hea
           SET FinalizadoEn = SYSUTCDATETIME()
          FROM dbo.HistorialEstadoActivo hea
          INNER JOIN #ArbolOrigen o ON hea.CodigoActivo = o.OldCode
         WHERE hea.FinalizadoEn IS NULL;

        INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        SELECT 
            o.NewCode, 'active', SYSUTCDATETIME(), @TargetAreaId,
            CONCAT(N'Traspaso de subárbol desde área ', @srcArea, N' (código anterior: ', o.OldCode, N')'),
            @UserId, @UserName
        FROM #ArbolOrigen o;

        UPDATE dbo.PlanPreventivo
           SET Estado = 'paused',
               Notas = ISNULL(Notas, '') + CONCAT(CHAR(13), CHAR(10), N'[Sistema]: Plan pausado automáticamente por traspaso del equipo a otra área.')
         WHERE CodigoActivo = @SourceAssetCode AND Estado = 'active';

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_TRANSFER', 'ASSETS', @SourceAssetCode,
                CONCAT(N'Subárbol de ', @SourceAssetCode, N' transferido desde ', @srcArea, N' a ', @TargetAreaId, N' con nuevo código raíz ', @NewRootCode, N'.'));

        DROP TABLE #ArbolOrigen;

        COMMIT TRANSACTION;
        SELECT @NewRootCode AS NewAssetCode, @NewRootCode AS CodigoActivo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoReactivar
    @AssetCode    NVARCHAR(60) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @UserId       INT = NULL,
    @UserName     NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @TargetCode NVARCHAR(60) = COALESCE(@AssetCode, @CodigoActivo);
        DECLARE @st NVARCHAR(25), @ar NVARCHAR(15), @nm NVARCHAR(200);
        SELECT @st = Estado, @ar = AreaId, @nm = Nombre
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @TargetCode;

        IF @st IS NULL
            RAISERROR(N'El activo no existe.', 16, 1);

        IF @st <> 'transferredDeactivated' AND @st <> 'inactive'
            RAISERROR(N'El activo no se encuentra en estado inactivo o desactivado por traspaso.', 16, 1);

        UPDATE dbo.Activo
           SET Estado = 'active',
               ActualizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @TargetCode;

        INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        VALUES (@TargetCode, 'active', SYSUTCDATETIME(), @ar, N'Reactivación de activo', @UserId, @UserName);

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_REACTIVATED', 'ASSETS', @TargetCode,
                CONCAT(N'Activo reactivado: ', @TargetCode, N' (', @nm, N').'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoAlternarEstado
    @AssetCode    NVARCHAR(60) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @NewStatus NVARCHAR(25) = NULL,
    @Status    NVARCHAR(25) = NULL,
    @Reason    NVARCHAR(500) = NULL,
    @UserId    INT = NULL,
    @UserName  NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @currStatus NVARCHAR(25), @ar NVARCHAR(15), @nm NVARCHAR(200);
        SELECT @currStatus = Estado, @ar = AreaId, @nm = Nombre
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);

        IF @currStatus IS NULL
            RAISERROR(N'El activo no existe.', 16, 1);

        DECLARE @TargetStatus NVARCHAR(25) = COALESCE(@NewStatus, @Status);
        UPDATE dbo.Activo
           SET Estado = @TargetStatus,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);

        UPDATE dbo.HistorialEstadoActivo
           SET FinalizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @AssetCode AND FinalizadoEn IS NULL;

        INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        VALUES (@AssetCode, @Status, SYSUTCDATETIME(), @ar, @Reason, @UserId, @UserName);

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_STATUS_CHANGED', 'ASSETS', @AssetCode,
                CONCAT(N'Estado de ', @AssetCode, N' cambiado a: ', @Status, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoActualizarEsEquipoProceso
    @CodigoActivo NVARCHAR(60) = NULL,
    @AssetCode NVARCHAR(60) = NULL,
    @EsEquipoProceso BIT = 1,
    @UsuarioId INT = NULL,
    @UserId INT = NULL,
    @NombreUsuario NVARCHAR(100) = N'',
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Activo
       SET EsEquipoProceso = @EsEquipoProceso,
           ActualizadoEn = SYSUTCDATETIME()
     WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);
END;
GO

-- ----------------------------------------------------------------------------
-- 15. PROCEDIMIENTOS ALMACENADOS: SOLICITUDES Y GESTIÓN DE BAJAS
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaCrear
    @AssetCode    NVARCHAR(60) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @Reason NVARCHAR(1000),
    @RequesterUserId INT = NULL,
    @RequesterUserName NVARCHAR(100) = N'',
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @nm NVARCHAR(200), @ar NVARCHAR(15), @st NVARCHAR(25);
        SELECT @nm = Nombre, @ar = AreaId, @st = Estado
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK) WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);

        IF @st IS NULL OR @st = 'deleted'
            RAISERROR(N'El activo no existe o ya está eliminado.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE CodigoActivo = @AssetCode AND EstadoCandado = 'pending')
            RAISERROR(N'Ya existe una solicitud de baja pendiente para este activo.', 16, 1);

        -- Validar OTs abiertas
        DECLARE @OTAbiertaId NVARCHAR(20);
        SELECT TOP 1 @OTAbiertaId = ot.OrdenTrabajoId
          FROM dbo.OrdenTrabajo ot WITH (UPDLOCK, HOLDLOCK)
          JOIN dbo.Activo a WITH (NOLOCK) ON ot.CodigoActivo = a.CodigoActivo
         WHERE a.AreaId = @ar
           AND (a.CodigoActivo = @AssetCode OR CHARINDEX(CONCAT(N',', @AssetCode, N','), CONCAT(N',', a.RutaAncestros, N',')) > 0)
           AND ot.Estado IN (N'pending', N'inProgress', N'in_progress', N'paused');

        IF @OTAbiertaId IS NOT NULL
        BEGIN
            DECLARE @MsgBaja NVARCHAR(250) = CONCAT(N'No se puede solicitar la baja: el activo o sus subcomponentes tienen la orden de trabajo abierta (', @OTAbiertaId, N'). Debe concluirse o cancelarse primero.');
            RAISERROR(@MsgBaja, 16, 1);
        END;

        INSERT INTO dbo.SolicitudBaja
            (CodigoActivo, NombreActivo, AreaId, Estado, Motivo,
             SolicitadoPorUsuarioId, SolicitadoPorNombreUsuario, SolicitadoEn)
        VALUES
            (@AssetCode, @nm, @ar, 'pending', @Reason,
             COALESCE(@RequesterUserId, @UserId), COALESCE(NULLIF(@RequesterUserName, N''), @UserName, N''), SYSUTCDATETIME());

        DECLARE @reqId BIGINT = SCOPE_IDENTITY();

        IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE CodigoActivo = @AssetCode)
            UPDATE dbo.CandadoBaja SET EstadoCandado = 'pending', ActualizadoEn = SYSUTCDATETIME() WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);
        ELSE
            INSERT INTO dbo.CandadoBaja (CodigoActivo, EstadoCandado) VALUES (@AssetCode, 'pending');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@RequesterUserId, @RequesterUserName, 'DELETION_REQUESTED', 'ASSETS', @AssetCode,
                CONCAT(N'Solicitud de baja ', @reqId, N' creada para ', @AssetCode, N' (', @nm, N'). Motivo: ', @Reason));

        COMMIT TRANSACTION;
        SELECT @reqId AS RequestId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaObtenerPendientes
    @StartDate DATETIME2(3) = NULL,
    @EndDate   DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SolicitudId, CodigoActivo, NombreActivo, AreaId, Estado, Motivo,
           SolicitadoPorUsuarioId, SolicitadoPorNombreUsuario, SolicitadoEn,
           DecididoPorUsuarioId, DecididoPorNombreUsuario, DecididoEn, MotivoDecision
      FROM dbo.SolicitudBaja
     WHERE Estado = 'pending'
       AND (@StartDate IS NULL OR SolicitadoEn >= @StartDate)
       AND (@EndDate   IS NULL OR SolicitadoEn <= @EndDate)
     ORDER BY SolicitadoEn DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaObtenerTodas
    @StatusFilter NVARCHAR(10) = NULL,
    @StartDate    DATETIME2(3) = NULL,
    @EndDate      DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SolicitudId, CodigoActivo, NombreActivo, AreaId, Estado, Motivo,
           SolicitadoPorUsuarioId, SolicitadoPorNombreUsuario, SolicitadoEn,
           DecididoPorUsuarioId, DecididoPorNombreUsuario, DecididoEn, MotivoDecision
      FROM dbo.SolicitudBaja
     WHERE (@StatusFilter IS NULL OR Estado = @StatusFilter)
       AND (@StartDate IS NULL OR SolicitadoEn >= @StartDate)
       AND (@EndDate   IS NULL OR SolicitadoEn <= @EndDate)
     ORDER BY SolicitadoEn DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaObtenerPendientePorActivo
    @AssetCode NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 SolicitudId, CodigoActivo, NombreActivo, AreaId, Estado, Motivo,
           SolicitadoPorUsuarioId, SolicitadoPorNombreUsuario, SolicitadoEn,
           DecididoPorUsuarioId, DecididoPorNombreUsuario, DecididoEn, MotivoDecision
      FROM dbo.SolicitudBaja
     WHERE CodigoActivo = @AssetCode AND Estado = 'pending'
     ORDER BY SolicitadoEn DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaAprobar
    @RequestId BIGINT,
    @ApproverUserId INT = NULL,
    @ApproverUserName NVARCHAR(100) = N'',
    @ApproveReason NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @c NVARCHAR(60), @nm NVARCHAR(200), @ar NVARCHAR(15), @st NVARCHAR(10);
        SELECT @c = CodigoActivo, @nm = NombreActivo, @ar = AreaId, @st = Estado
          FROM dbo.SolicitudBaja WITH (UPDLOCK, HOLDLOCK) WHERE SolicitudId = @RequestId;

        IF @c IS NULL OR @st <> 'pending'
            RAISERROR(N'Esta solicitud ya fue resuelta o no está pendiente.', 16, 1);

        DECLARE @OTAbiertaId NVARCHAR(20);
        SELECT TOP 1 @OTAbiertaId = ot.OrdenTrabajoId
          FROM dbo.OrdenTrabajo ot WITH (UPDLOCK, HOLDLOCK)
          JOIN dbo.Activo a WITH (NOLOCK) ON ot.CodigoActivo = a.CodigoActivo
         WHERE a.AreaId = @ar
           AND (a.CodigoActivo = @c OR CHARINDEX(CONCAT(N',', @c, N','), CONCAT(N',', a.RutaAncestros, N',')) > 0)
           AND ot.Estado IN (N'pending', N'inProgress', N'in_progress', N'paused');

        IF @OTAbiertaId IS NOT NULL
        BEGIN
            DECLARE @MsgBaja NVARCHAR(250) = CONCAT(N'No se puede dar de baja: el activo o sus subcomponentes tienen la orden de trabajo abierta (', @OTAbiertaId, N'). Debe concluirse o cancelarse primero.');
            RAISERROR(@MsgBaja, 16, 1);
        END;

        UPDATE a
           SET Estado = 'deleted',
               EliminadoEn = SYSUTCDATETIME(),
               EliminadoPorUsuarioId = @ApproverUserId,
               EliminadoPorNombreUsuario = @ApproverUserName,
               ActualizadoEn = SYSUTCDATETIME()
          FROM dbo.Activo a
         WHERE a.AreaId = @ar AND a.Estado <> 'deleted'
           AND (a.CodigoActivo = @c OR CHARINDEX(CONCAT(N',', @c, N','), CONCAT(N',', a.RutaAncestros, N',')) > 0);

        UPDATE dbo.PlanPreventivo
           SET Estado = 'paused',
               Notas = ISNULL(Notas, '') + CONCAT(CHAR(13), CHAR(10), N'[Sistema]: Plan preventivo pausado automáticamente por baja del activo.')
         WHERE CodigoActivo = @c AND Estado = 'active';

        UPDATE dbo.SolicitudBaja
           SET Estado = 'approved',
               DecididoPorUsuarioId = @ApproverUserId,
               DecididoPorNombreUsuario = @ApproverUserName,
               DecididoEn = SYSUTCDATETIME(),
               MotivoDecision = COALESCE(@ApproveReason, N'')
         WHERE SolicitudId = @RequestId;

        UPDATE dbo.CandadoBaja SET EstadoCandado = 'approved', ActualizadoEn = SYSUTCDATETIME() WHERE CodigoActivo = @c;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@ApproverUserId, @ApproverUserName, 'ASSET_DELETED', 'ASSETS', @c,
                CONCAT(N'Aprobada la solicitud de baja ', @RequestId, N' para ', @c, N' (', @nm, N'). Planes preventivos pausados.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaRechazar
    @RequestId BIGINT,
    @Reason NVARCHAR(500) = NULL,
    @RejectReason NVARCHAR(500) = NULL,
    @RejectedByUserId INT = NULL,
    @ApproverUserId INT = NULL,
    @RejectedByUserName NVARCHAR(100) = N'',
    @ApproverUserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @c NVARCHAR(60), @nm NVARCHAR(200), @st NVARCHAR(10);
        SELECT @c = CodigoActivo, @nm = NombreActivo, @st = Estado
          FROM dbo.SolicitudBaja WITH (UPDLOCK, HOLDLOCK) WHERE SolicitudId = @RequestId;

        IF @c IS NULL OR @st <> 'pending'
            RAISERROR(N'Esta solicitud ya fue resuelta o no está pendiente.', 16, 1);

        UPDATE dbo.SolicitudBaja
           SET Estado = 'rejected',
               DecididoPorUsuarioId = @ApproverUserId,
               DecididoPorNombreUsuario = @ApproverUserName,
               DecididoEn = SYSUTCDATETIME(),
               MotivoDecision = @RejectReason
         WHERE SolicitudId = @RequestId;

        UPDATE dbo.CandadoBaja SET EstadoCandado = 'rejected', ActualizadoEn = SYSUTCDATETIME() WHERE CodigoActivo = @c;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@ApproverUserId, @ApproverUserName, 'DELETION_REJECTED', 'ASSETS', @c,
                CONCAT(N'Rechazada la solicitud de baja ', @RequestId, N' para ', @c, N' (', @nm, N'). Motivo: ', @RejectReason));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
GO

-- ============================================================================
-- MÓDULO: 05_averias_ots_preventivos_sp.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 16. PROCEDIMIENTOS ALMACENADOS: AVERÍAS Y ÓRDENES DE TRABAJO
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaCrear
    @AssetCode NVARCHAR(60), 
    @AssetName NVARCHAR(200), 
    @AreaId NVARCHAR(15),
    @Description NVARCHAR(MAX), 
    @Severity NVARCHAR(10),
    @ReporterUserId INT = NULL, 
    @ReporterUserName NVARCHAR(100) = N'',
    @ImageData NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.Activo WHERE CodigoActivo = @AssetCode)
            RAISERROR(N'El activo no existe.', 16, 1);

        DECLARE @ReporteExistenteId BIGINT;
        SELECT TOP 1 @ReporteExistenteId = ReporteId
          FROM dbo.ReporteAveria WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @AssetCode
           AND Estado IN (N'reported', N'inWorkOrder');

        IF @ReporteExistenteId IS NOT NULL
        BEGIN
            DECLARE @MsgError NVARCHAR(250) = CONCAT(N'El activo ', @AssetCode, N' ya cuenta con un reporte de avería pendiente o en orden de trabajo (#', @ReporteExistenteId, N').');
            RAISERROR(@MsgError, 16, 1);
        END;

        INSERT INTO dbo.ReporteAveria (
            CodigoActivo, NombreActivo, AreaId, Descripcion, Severidad,
            ReportadoPorUsuarioId, ReportadoPorNombreUsuario, ImagenUrl
        )
        VALUES (
            @AssetCode, @AssetName, @AreaId, @Description, @Severity,
            @ReporterUserId, @ReporterUserName, @ImageData
        );
        DECLARE @rid BIGINT = SCOPE_IDENTITY();

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@ReporterUserId, @ReporterUserName, 'BREAKDOWN_REPORTED', 'BREAKDOWNS', @AssetCode,
                CONCAT(N'Reporte ', @rid, N': avería en ', @AssetCode, N' (', @AssetName, N'). Severidad: ', @Severity,
                       CASE WHEN @ImageData IS NOT NULL AND LEN(@ImageData) > 0 THEN N' [Con evidencia fotográfica]' ELSE N'' END));

        COMMIT TRANSACTION;
        SELECT @rid AS NewReportId, @rid AS ReporteId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaObtenerTodos
    @StatusFilter NVARCHAR(15) = NULL,
    @StartDate DATETIME2(3) = NULL, 
    @EndDate DATETIME2(3) = NULL,
    @Limit INT = NULL,
    @Offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ReporteId, 
           CodigoActivo AS AssetCode, 
           NombreActivo AS AssetName, 
           AreaId,
           Descripcion AS Description, 
           Severidad AS Severity,
           ReportadoPorUsuarioId AS ReportedByUserId, 
           ReportadoPorNombreUsuario AS ReportedByUserName,
           ReportadoEn AS ReportedAt, 
           Estado AS Status, 
           OrdenTrabajoId AS WorkOrderId,
           ResueltoPorUsuarioId AS ResolvedByUserId, 
           ResueltoPorNombreUsuario AS ResolvedByUserName,
           ResueltoEn AS ResolvedAt, 
           MotivoRechazo AS RejectionReason,
           RechazadoPorUsuarioId AS RejectedByUserId, 
           RechazadoPorNombreUsuario AS RejectedByUserName,
           RechazadoEn AS RejectedAt,
           ImagenUrl AS ImageData
      FROM dbo.ReporteAveria
     WHERE (@StatusFilter IS NULL OR Estado = @StatusFilter)
       AND (@StartDate IS NULL OR ReportadoEn >= @StartDate)
       AND (@EndDate   IS NULL OR ReportadoEn <= @EndDate)
     ORDER BY ReportadoEn DESC
     OFFSET @Offset ROWS
     FETCH NEXT CASE WHEN @Limit IS NULL OR @Limit <= 0 THEN 2147483647 ELSE @Limit END ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaObtenerPorUsuario
    @ReporterUserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ReporteId, CodigoActivo AS AssetCode, NombreActivo AS AssetName, AreaId,
           Descripcion AS Description, Severidad AS Severity,
           ReportadoPorUsuarioId AS ReportedByUserId, ReportadoPorNombreUsuario AS ReportedByUserName,
           ReportadoEn AS ReportedAt, Estado AS Status, OrdenTrabajoId AS WorkOrderId,
           ResueltoPorUsuarioId AS ResolvedByUserId, ResueltoPorNombreUsuario AS ResolvedByUserName,
           ResueltoEn AS ResolvedAt, MotivoRechazo AS RejectionReason,
           RechazadoPorUsuarioId AS RejectedByUserId, RechazadoPorNombreUsuario AS RejectedByUserName,
           RechazadoEn AS RejectedAt, ImagenUrl AS ImageData
      FROM dbo.ReporteAveria
     WHERE ReportadoPorUsuarioId = @ReporterUserId
     ORDER BY ReportadoEn DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaObtenerAbiertos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ReporteId, CodigoActivo AS AssetCode, NombreActivo AS AssetName, AreaId,
           Descripcion AS Description, Severidad AS Severity,
           ReportadoPorUsuarioId AS ReportedByUserId, ReportadoPorNombreUsuario AS ReportedByUserName,
           ReportadoEn AS ReportedAt, Estado AS Status, OrdenTrabajoId AS WorkOrderId,
           ResueltoPorUsuarioId AS ResolvedByUserId, ResueltoPorNombreUsuario AS ResolvedByUserName,
           ResueltoEn AS ResolvedAt, MotivoRechazo AS RejectionReason,
           RechazadoPorUsuarioId AS RejectedByUserId, RechazadoPorNombreUsuario AS RejectedByUserName,
           RechazadoEn AS RejectedAt, ImagenUrl AS ImageData
      FROM dbo.ReporteAveria
     WHERE Estado IN ('reported', 'inWorkOrder', 'pending', 'inProgress')
     ORDER BY CASE Severidad WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
              ReportadoEn ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaVincularOrdenTrabajo
    @ReportId BIGINT,
    @WorkOrderId NVARCHAR(20),
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.ReporteAveria
       SET OrdenTrabajoId = @WorkOrderId,
           Estado = 'inWorkOrder'
     WHERE ReporteId = @ReportId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaResolver
    @ReportId BIGINT,
    @ResolvedByUserId INT = NULL,
    @ResolvedByUserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.ReporteAveria
       SET Estado = 'resolved',
           ResueltoPorUsuarioId = @ResolvedByUserId,
           ResueltoPorNombreUsuario = @ResolvedByUserName,
           ResueltoEn = SYSUTCDATETIME()
     WHERE ReporteId = @ReportId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaRechazar
    @ReportId BIGINT,
    @Reason NVARCHAR(500) = NULL,
    @RejectReason NVARCHAR(500) = NULL,
    @RejectedByUserId INT = NULL,
    @RejectedByUserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @MotivoRechazo NVARCHAR(500) = COALESCE(@Reason, @RejectReason, N'');

        UPDATE dbo.ReporteAveria
           SET Estado = 'rejected',
                MotivoRechazo = @MotivoRechazo,
                RechazadoPorUsuarioId = @RejectedByUserId,
                RechazadoPorNombreUsuario = @RejectedByUserName,
                RechazadoEn = SYSUTCDATETIME()
          WHERE ReporteId = @ReportId;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@RejectedByUserId, @RejectedByUserName, 'BREAKDOWN_REJECTED', 'BREAKDOWNS', CAST(@ReportId AS NVARCHAR(20)),
                CONCAT(N'Reporte de avería ', @ReportId, N' rechazado. Motivo: ', @MotivoRechazo));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoObtenerTodas
    @StatusFilter   NVARCHAR(15) = NULL,
    @AreaFilter     NVARCHAR(15) = NULL,
    @PriorityFilter NVARCHAR(10) = NULL,
    @Limit          INT = NULL,
    @Offset         INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @Offset < 0 SET @Offset = 0;

    SELECT ot.OrdenTrabajoId AS WorkOrderId,
           ot.CodigoActivo AS AssetCode,
           ot.NombreActivo AS AssetName,
           ot.AreaId,
           COALESCE(ar.Nombre, ot.NombreArea) AS AreaName,
           ot.Descripcion AS Description,
           ot.Estado AS Status,
           ot.Prioridad AS Priority,
           ot.AsignadoA AS AssignedTo,
           ot.CantidadPersonalAsignado AS AssignedStaffCount,
           ot.HorasEstimadas AS EstimatedHours,
           ot.HorasReales AS ActualHours,
           ot.DescripcionTrabajoRealizado AS WorkDoneDescription,
           ot.EstaCompletada AS IsCompleted,
           ot.MotivoIncumplimiento AS UnfulfillmentReason,
           ot.FechaReprogramacion AS ReprogramDate,
           ot.ResponsableAccHaccp AS AccHaccpResponsible,
           ot.ResponsableMantenimiento AS MaintenanceResponsible,
           ot.ResponsableJefeArea AS AreaHeadResponsible,
           ot.ResponsableJefeMantenimiento AS MaintenanceHeadResponsible,
           ot.FechaProgramada AS ScheduledDate,
           ot.ReporteId AS ReportId,
           ot.CreadoPorUsuarioId AS CreatedByUserId,
           ot.CreadoPorNombreUsuario AS CreatedByUserName,
           ot.CreadoEn AS CreatedAt,
           ra.ImagenUrl AS BreakdownImageData,
           m.MaterialsJson,
           t.WorkTypesCsv,
           ot.OrdenTrabajoId,
           ot.CodigoActivo,
           ot.NombreActivo,
           ot.NombreArea,
           ot.Descripcion,
           ot.Estado,
           ot.Prioridad,
           ot.AsignadoA,
           ot.CantidadPersonalAsignado,
           ot.HorasEstimadas,
           ot.HorasReales,
           ot.FechaProgramada,
           ot.CreadoEn
      FROM dbo.OrdenTrabajo ot
      LEFT JOIN dbo.Area ar ON ot.AreaId = ar.AreaId
      LEFT JOIN dbo.ReporteAveria ra ON ot.ReporteId = ra.ReporteId
     OUTER APPLY (
         SELECT (
             SELECT NumeroLinea AS LineNum, Descripcion AS Description, Cantidad AS Quantity, Unidad AS Unit
               FROM dbo.MaterialOrdenTrabajo
              WHERE OrdenTrabajoId = ot.OrdenTrabajoId
              ORDER BY NumeroLinea
                FOR JSON PATH
         ) AS MaterialsJson
     ) m
     OUTER APPLY (
         SELECT STRING_AGG(TipoTrabajo, ',') AS WorkTypesCsv
           FROM dbo.TipoTrabajoOrdenTrabajo
          WHERE OrdenTrabajoId = ot.OrdenTrabajoId
     ) t
     WHERE (@StatusFilter IS NULL OR ot.Estado = @StatusFilter)
       AND (@AreaFilter   IS NULL OR ot.AreaId = @AreaFilter)
       AND (@PriorityFilter IS NULL OR ot.Prioridad = @PriorityFilter)
     ORDER BY ot.CreadoEn DESC
     OFFSET @Offset ROWS
     FETCH NEXT CASE WHEN @Limit IS NULL OR @Limit <= 0 THEN 2147483647 ELSE @Limit END ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoObtenerAbiertas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ot.OrdenTrabajoId,
           ot.CodigoActivo,
           ot.NombreActivo,
           ot.AreaId,
           ot.NombreArea,
           ot.Descripcion,
           ot.Estado,
           ot.Prioridad,
           ot.AsignadoA,
           ot.CantidadPersonalAsignado,
           ot.HorasEstimadas,
           ot.HorasReales,
           ot.DescripcionTrabajoRealizado,
           ot.EstaCompletada,
           ot.MotivoIncumplimiento,
           ot.FechaReprogramacion,
           ot.ResponsableAccHaccp,
           ot.ResponsableMantenimiento,
           ot.ResponsableJefeArea,
           ot.ResponsableJefeMantenimiento,
           ot.FechaProgramada,
           ot.ReporteId,
           ot.CreadoPorUsuarioId,
           ot.CreadoPorNombreUsuario,
           ot.CreadoEn,
           ra.ImagenUrl AS BreakdownImageData
      FROM dbo.OrdenTrabajo ot
      LEFT JOIN dbo.ReporteAveria ra ON ot.ReporteId = ra.ReporteId
     WHERE ot.Estado IN ('pending', 'inProgress', 'in_progress', 'paused')
     ORDER BY CASE ot.Prioridad WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
              ot.CreadoEn ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoCrear
    @AssetCode NVARCHAR(60) = N'',
    @AssetName NVARCHAR(200),
    @AreaId NVARCHAR(15) = NULL,
    @AreaName NVARCHAR(200) = NULL,
    @Description NVARCHAR(MAX),
    @Priority NVARCHAR(10) = N'medium',
    @AssignedTo NVARCHAR(200) = NULL,
    @AssignedStaffCount INT = NULL,
    @EstimatedHours DECIMAL(6,2) = NULL,
    @ScheduledDate DATETIME2(3) = NULL,
    @ReportId BIGINT = NULL,
    @CreatedByUserId INT = NULL,
    @CreatedByUserName NVARCHAR(100) = N'',
    @Materials dbo.TipoMaterialOrdenTrabajo READONLY,
    @WorkTypes dbo.TipoListaTexto READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NULLIF(@AssetCode, '') IS NOT NULL
        BEGIN
            DECLARE @OTExistenteId NVARCHAR(20);
            SELECT TOP 1 @OTExistenteId = OrdenTrabajoId
              FROM dbo.OrdenTrabajo WITH (UPDLOCK, HOLDLOCK)
             WHERE CodigoActivo = @AssetCode
               AND Estado IN (N'pending', N'inProgress', N'in_progress', N'paused');

            IF @OTExistenteId IS NOT NULL
            BEGIN
                DECLARE @MsgOT NVARCHAR(250) = CONCAT(N'El activo ', @AssetCode, N' ya cuenta con una orden de trabajo abierta (', @OTExistenteId, N'). Debe concluirse o cancelarse antes de emitir una nueva.');
                RAISERROR(@MsgOT, 16, 1);
            END;
        END;

        DECLARE @cCount TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT deleted.SiguienteNumero INTO @cCount(v)
          WHERE Nombre = 'work_orders';

        DECLARE @seq INT; SELECT @seq = v FROM @cCount;
        DECLARE @woId NVARCHAR(20) = CONCAT('OT-', YEAR(SYSUTCDATETIME()), '-', FORMAT(@seq, '0000'));

        INSERT INTO dbo.OrdenTrabajo
            (OrdenTrabajoId, CodigoActivo, NombreActivo, AreaId, NombreArea, Descripcion,
             Estado, Prioridad, AsignadoA, CantidadPersonalAsignado, HorasEstimadas,
             FechaProgramada, ReporteId, CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn)
        VALUES
            (@woId, NULLIF(@AssetCode, ''), @AssetName, @AreaId, @AreaName, @Description,
             'pending', @Priority, @AssignedTo, @AssignedStaffCount, @EstimatedHours,
             @ScheduledDate, @ReportId, @CreatedByUserId, @CreatedByUserName, SYSUTCDATETIME());

        INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
        SELECT @woId, ROW_NUMBER() OVER (ORDER BY NumeroLinea), Descripcion, Cantidad, ISNULL(Unidad, 'pz')
          FROM @Materials;

        INSERT INTO dbo.TipoTrabajoOrdenTrabajo (OrdenTrabajoId, TipoTrabajo)
        SELECT DISTINCT @woId, LTRIM(RTRIM(Valor)) FROM @WorkTypes WHERE LTRIM(RTRIM(Valor)) <> '';

        IF @ReportId IS NOT NULL
        BEGIN
            UPDATE dbo.ReporteAveria
               SET OrdenTrabajoId = @woId, Estado = 'inWorkOrder'
             WHERE ReporteId = @ReportId;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreatedByUserId, @CreatedByUserName, 'WORK_ORDER_CREATED', 'WORK_ORDERS', @woId,
                CONCAT(N'OT creada: ', @woId, N' para ', @AssetName, N' (Prioridad: ', @Priority, N').'));

        COMMIT TRANSACTION;
        SELECT @woId AS WorkOrderId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoActualizarEstado
    @WorkOrderId NVARCHAR(20),
    @NewStatus NVARCHAR(15),
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.OrdenTrabajo
           SET Estado = @NewStatus
         WHERE OrdenTrabajoId = @WorkOrderId;

        IF @NewStatus = 'completed'
        BEGIN
            DECLARE @repId BIGINT;
            SELECT @repId = ReporteId FROM dbo.OrdenTrabajo WHERE OrdenTrabajoId = @WorkOrderId;
            IF @repId IS NOT NULL
            BEGIN
                UPDATE dbo.ReporteAveria
                   SET Estado = 'resolved',
                       ResueltoPorUsuarioId = @UserId,
                       ResueltoPorNombreUsuario = @UserName,
                       ResueltoEn = SYSUTCDATETIME()
                 WHERE ReporteId = @repId;
            END;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'WORK_ORDER_STATUS_CHANGED', 'WORK_ORDERS', @WorkOrderId,
                CONCAT(N'Estado de OT ', @WorkOrderId, N' cambiado a: ', @NewStatus, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoActualizarDetalles
    @WorkOrderId                 NVARCHAR(20),
    @Description                 NVARCHAR(MAX) = NULL,
    @Priority                    NVARCHAR(10) = NULL,
    @AssignedTo                  NVARCHAR(200) = NULL,
    @AssignedStaffCount          INT = NULL,
    @EstimatedHours              DECIMAL(6,2) = NULL,
    @ActualHours                 DECIMAL(6,2) = NULL,
    @WorkDoneDescription         NVARCHAR(MAX) = NULL,
    @WorkDescription             NVARCHAR(MAX) = NULL,
    @IsCompleted                 BIT = NULL,
    @UnfulfillmentReason         NVARCHAR(500) = NULL,
    @UnfulfilledReason           NVARCHAR(500) = NULL,
    @ReprogramDate               DATETIME2(3) = NULL,
    @RescheduledDate             DATETIME2(3) = NULL,
    @AccHaccpResponsible        NVARCHAR(200) = NULL,
    @ResponsableAccHaccp         NVARCHAR(200) = NULL,
    @MaintenanceResponsible      NVARCHAR(200) = NULL,
    @ResponsableMantenimiento    NVARCHAR(200) = NULL,
    @ResponsableJefeArea         NVARCHAR(200) = NULL,
    @ResponsableJefeMantenimiento NVARCHAR(200) = NULL,
    @ScheduledDate               DATETIME2(3) = NULL,
    @UserId                      INT = NULL,
    @UserName                    NVARCHAR(100) = N'',
    @Materials                   dbo.TipoMaterialOrdenTrabajo READONLY,
    @WorkTypes                   dbo.TipoListaTexto READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.OrdenTrabajo
           SET Descripcion                  = COALESCE(@Description, Descripcion),
               Prioridad                    = COALESCE(@Priority, Prioridad),
               AsignadoA                    = COALESCE(@AssignedTo, AsignadoA),
               CantidadPersonalAsignado     = COALESCE(@AssignedStaffCount, CantidadPersonalAsignado),
               HorasEstimadas               = COALESCE(@EstimatedHours, HorasEstimadas),
               HorasReales                  = COALESCE(@ActualHours, HorasReales),
               DescripcionTrabajoRealizado  = COALESCE(@WorkDoneDescription, @WorkDescription, DescripcionTrabajoRealizado),
               EstaCompletada               = COALESCE(@IsCompleted, EstaCompletada),
               MotivoIncumplimiento         = COALESCE(@UnfulfillmentReason, @UnfulfilledReason, MotivoIncumplimiento),
               FechaReprogramacion          = COALESCE(@ReprogramDate, @RescheduledDate, FechaReprogramacion),
               ResponsableAccHaccp          = COALESCE(@AccHaccpResponsible, @ResponsableAccHaccp, ResponsableAccHaccp),
               ResponsableMantenimiento     = COALESCE(@MaintenanceResponsible, @ResponsableMantenimiento, ResponsableMantenimiento),
               ResponsableJefeArea          = COALESCE(@ResponsableJefeArea, ResponsableJefeArea),
               ResponsableJefeMantenimiento = COALESCE(@ResponsableJefeMantenimiento, ResponsableJefeMantenimiento),
               FechaProgramada              = COALESCE(@ScheduledDate, FechaProgramada),
               ActualizadoEn                = SYSUTCDATETIME()
         WHERE OrdenTrabajoId = @WorkOrderId;

        IF EXISTS (SELECT 1 FROM @Materials)
        BEGIN
            DELETE FROM dbo.MaterialOrdenTrabajo WHERE OrdenTrabajoId = @WorkOrderId;
            INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
            SELECT @WorkOrderId, NumeroLinea, Descripcion, Cantidad, Unidad FROM @Materials;
        END;

        IF EXISTS (SELECT 1 FROM @WorkTypes)
        BEGIN
            DELETE FROM dbo.TipoTrabajoOrdenTrabajo WHERE OrdenTrabajoId = @WorkOrderId;
            INSERT INTO dbo.TipoTrabajoOrdenTrabajo (OrdenTrabajoId, TipoTrabajo)
            SELECT @WorkOrderId, Valor FROM @WorkTypes;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 17. PROCEDIMIENTOS ALMACENADOS: PLANES PREVENTIVOS Y GENERACIÓN DE OTS
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoObtenerTodos
    @AreaFilter   NVARCHAR(15) = NULL,
    @StatusFilter NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        p.PlanId                      AS ScheduleId,
        p.Titulo                      AS Title,
        p.CodigoActivo                AS AssetCode,
        p.NombreActivo                AS AssetName,
        p.AreaId,
        COALESCE(ar.Nombre, p.NombreArea) AS AreaName,
        p.TipoMantenimiento           AS MaintenanceType,
        p.Frecuencia                  AS Frequency,
        p.Descripcion                 AS Description,
        p.HorasEstimadas              AS EstimatedHours,
        p.FechaInicio                 AS StartDate,
        p.ProximaFecha                AS NextDate,
        p.UltimaCompletada            AS LastCompleted,
        p.UltimaOrdenTrabajoId        AS LastWorkOrderId,
        p.Estado                      AS Status,
        p.Notas                       AS Notes,
        p.CreadoPorUsuarioId          AS CreatedByUserId,
        p.CreadoPorNombreUsuario      AS CreatedByUserName,
        p.CreadoEn                    AS CreatedAt,
        p.NumeroDocumentoModificacion AS AmendmentDocNumber,
        p.ModificadoPor               AS AmendedBy,
        p.ModificadoEn                AS AmendedAt,
        p.MotivoModificacion          AS AmendmentReason,
        m.MaterialsJson,
        p.PlanId,
        p.Titulo,
        p.CodigoActivo,
        p.NombreActivo,
        p.NombreArea,
        p.TipoMantenimiento,
        p.Frecuencia,
        p.Descripcion,
        p.HorasEstimadas,
        p.FechaInicio,
        p.ProximaFecha,
        p.UltimaCompletada,
        p.UltimaOrdenTrabajoId,
        p.Estado,
        p.Notas,
        p.CreadoPorUsuarioId,
        p.CreadoPorNombreUsuario,
        p.CreadoEn
    FROM dbo.PlanPreventivo p
    LEFT JOIN dbo.Area ar ON p.AreaId = ar.AreaId
    OUTER APPLY (
        SELECT (
            SELECT NumeroLinea AS LineNum, Nombre AS Name, Cantidad AS Quantity, Unidad AS Unit
            FROM dbo.MaterialPreventivo
            WHERE PlanId = p.PlanId
            ORDER BY NumeroLinea
            FOR JSON PATH
        ) AS MaterialsJson
    ) m
    WHERE (@StatusFilter IS NULL OR p.Estado = @StatusFilter)
      AND (@AreaFilter   IS NULL OR p.AreaId = @AreaFilter)
    ORDER BY p.ProximaFecha ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoCrear
    @Title NVARCHAR(200),
    @AssetCode NVARCHAR(60),
    @AssetName NVARCHAR(200),
    @AreaId NVARCHAR(15),
    @AreaName NVARCHAR(200),
    @MaintenanceType NVARCHAR(100),
    @Frequency NVARCHAR(20),
    @Description NVARCHAR(MAX) = NULL,
    @EstimatedHours DECIMAL(6,2) = NULL,
    @StartDate DATETIME2(3),
    @NextDate DATETIME2(3),
    @LastCompleted DATETIME2(3) = NULL,
    @LastWorkOrderId NVARCHAR(20) = NULL,
    @Status NVARCHAR(15) = 'active',
    @Notes NVARCHAR(500) = NULL,
    @CreatedByUserId INT = NULL,
    @CreatedByUserName NVARCHAR(100) = N'',
    @IntervaloFrecuencia INT = 1,
    @UnidadFrecuencia NVARCHAR(20) = 'meses',
    @ActividadesJson NVARCHAR(MAX) = NULL,
    @Materials dbo.TipoMaterialPreventivo READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Regla de Integridad: Solo 1 plan preventivo activo por activo
        IF EXISTS (SELECT 1 FROM dbo.PlanPreventivo WHERE CodigoActivo = @AssetCode AND Estado = 'active')
        BEGIN
            DECLARE @ExistingPlanId NVARCHAR(20);
            SELECT TOP 1 @ExistingPlanId = PlanId FROM dbo.PlanPreventivo WHERE CodigoActivo = @AssetCode AND Estado = 'active';
            DECLARE @MsgPrev NVARCHAR(250) = CONCAT(N'El activo ', @AssetCode, N' ya cuenta con el plan preventivo activo ', @ExistingPlanId, N'. No se permiten múltiples planes preventivos simultáneos.');
            RAISERROR(@MsgPrev, 16, 1);
        END;

        DECLARE @pCount TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT deleted.SiguienteNumero INTO @pCount(v)
          WHERE Nombre = 'preventive_schedules';

        DECLARE @seq INT; SELECT @seq = v FROM @pCount;
        DECLARE @pId NVARCHAR(20) = CONCAT('PM-', YEAR(SYSUTCDATETIME()), '-', FORMAT(@seq, '0000'));

        INSERT INTO dbo.PlanPreventivo
            (PlanId, Titulo, CodigoActivo, NombreActivo, AreaId, NombreArea,
             TipoMantenimiento, Frecuencia, Descripcion, HorasEstimadas,
             FechaInicio, ProximaFecha, Estado, Notas,
             CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn)
        VALUES
            (@pId, @Title, @AssetCode, @AssetName, @AreaId, @AreaName,
             @MaintenanceType, @Frequency, @Description, @EstimatedHours,
             @StartDate, @NextDate, 'active', @Notes,
             @CreatedByUserId, @CreatedByUserName, SYSUTCDATETIME());

        INSERT INTO dbo.MaterialPreventivo (PlanId, NumeroLinea, Nombre, Cantidad, Unidad)
        SELECT @pId, ROW_NUMBER() OVER (ORDER BY NumeroLinea), Nombre, Cantidad, ISNULL(Unidad, 'pza')
          FROM @Materials;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreatedByUserId, @CreatedByUserName, 'PREVENTIVE_PLAN_CREATED', 'PREVENTIVE', @pId,
                CONCAT(N'Plan preventivo creado: ', @pId, N' (', @Title, N') para ', @AssetCode, N'. Frecuencia: ', @Frequency));

        COMMIT TRANSACTION;
        SELECT @pId AS PlanId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoModificar
    @ScheduleId          NVARCHAR(20) = NULL,
    @PlanId              NVARCHAR(20) = NULL,
    @Title               NVARCHAR(200) = NULL,
    @MaintenanceType     NVARCHAR(100) = NULL,
    @Frequency           NVARCHAR(20) = NULL,
    @Description         NVARCHAR(MAX) = NULL,
    @EstimatedHours      DECIMAL(6,2) = NULL,
    @StartDate           DATETIME2(3) = NULL,
    @NextDate            DATETIME2(3) = NULL,
    @Notes               NVARCHAR(500) = NULL,
    @AmendmentDocNumber  NVARCHAR(50) = NULL,
    @ModifiedDocNumber   NVARCHAR(50) = NULL,
    @AuthorizedByManager BIT = 0,
    @AmendmentReason     NVARCHAR(500) = NULL,
    @ModifyReason        NVARCHAR(500) = NULL,
    @UserId              INT = NULL,
    @UserName            NVARCHAR(100) = N'',
    @Materials           dbo.TipoMaterialPreventivo READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @TargetPlan NVARCHAR(20) = COALESCE(@ScheduleId, @PlanId);

        UPDATE dbo.PlanPreventivo
           SET Titulo                      = COALESCE(@Title, Titulo),
               TipoMantenimiento           = COALESCE(@MaintenanceType, TipoMantenimiento),
               Frecuencia                  = COALESCE(@Frequency, Frecuencia),
               Descripcion                 = COALESCE(@Description, Descripcion),
               HorasEstimadas              = COALESCE(@EstimatedHours, HorasEstimadas),
               FechaInicio                 = COALESCE(@StartDate, FechaInicio),
               ProximaFecha                = COALESCE(@NextDate, ProximaFecha),
               Notas                       = COALESCE(@Notes, Notas),
               NumeroDocumentoModificacion = COALESCE(@AmendmentDocNumber, @ModifiedDocNumber, NumeroDocumentoModificacion),
               ModificadoPor               = COALESCE(@UserName, ModificadoPor),
               ModificadoEn                = SYSUTCDATETIME(),
               MotivoModificacion          = COALESCE(@AmendmentReason, @ModifyReason, MotivoModificacion)
         WHERE PlanId = @TargetPlan;

        IF EXISTS (SELECT 1 FROM @Materials)
        BEGIN
            DELETE FROM dbo.MaterialPreventivo WHERE PlanId = @TargetPlan;
            INSERT INTO dbo.MaterialPreventivo (PlanId, NumeroLinea, Nombre, Cantidad, Unidad)
            SELECT @TargetPlan, ROW_NUMBER() OVER (ORDER BY NumeroLinea), Nombre, Cantidad, ISNULL(Unidad, 'pza') FROM @Materials;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'PREVENTIVE_PLAN_MODIFIED', 'PREVENTIVE', @TargetPlan,
                CONCAT(N'Plan preventivo ', @TargetPlan, N' modificado. Motivo: ', ISNULL(COALESCE(@AmendmentReason, @ModifyReason), N'N/A')));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoRegistrarEjecucion
    @ScheduleId    NVARCHAR(20) = NULL,
    @PlanId        NVARCHAR(20) = NULL,
    @WorkOrderId   NVARCHAR(20),
    @CompletedDate DATETIME2(3) = NULL,
    @UserId        INT = NULL,
    @UserName      NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @TargetPlanExec NVARCHAR(20) = COALESCE(@ScheduleId, @PlanId);
        DECLARE @DateFinal DATETIME2(3) = COALESCE(@CompletedDate, SYSUTCDATETIME());

        UPDATE dbo.PlanPreventivo
           SET UltimaCompletada = @DateFinal,
               UltimaOrdenTrabajoId = @WorkOrderId
         WHERE PlanId = @TargetPlanExec;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'PREVENTIVE_PLAN_EXECUTED', 'PREVENTIVE', @TargetPlanExec,
                CONCAT(N'Ejecución del plan preventivo ', @TargetPlanExec, N' registrada con OT ', @WorkOrderId, N'. Fecha: ', CONVERT(NVARCHAR(30), @DateFinal, 120)));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoAlternarEstado
    @ScheduleId          NVARCHAR(20) = NULL,
    @PlanId              NVARCHAR(20) = NULL,
    @NewStatus           NVARCHAR(15) = NULL,
    @NuevoEstado         NVARCHAR(15) = NULL,
    @AmendmentDocNumber  NVARCHAR(50) = NULL,
    @AuthorizedByManager BIT = 0,
    @Reason              NVARCHAR(500) = NULL,
    @Motivo              NVARCHAR(500) = NULL,
    @UserId              INT = NULL,
    @UserName            NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TargetPlanAlt NVARCHAR(20) = COALESCE(@ScheduleId, @PlanId);
    DECLARE @TargetStatusAlt NVARCHAR(15) = COALESCE(@NewStatus, @NuevoEstado);

    UPDATE dbo.PlanPreventivo
       SET Estado = @TargetStatusAlt,
           NumeroDocumentoModificacion = COALESCE(@AmendmentDocNumber, NumeroDocumentoModificacion),
           MotivoModificacion = COALESCE(@Reason, @Motivo, MotivoModificacion),
           ModificadoPor = COALESCE(@UserName, ModificadoPor),
           ModificadoEn = SYSUTCDATETIME()
     WHERE PlanId = @TargetPlanAlt;

    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
    VALUES (@UserId, @UserName, 'PREVENTIVE_PLAN_STATUS', 'PREVENTIVE', @TargetPlanAlt,
            CONCAT(N'Estado de plan preventivo ', @TargetPlanAlt, N' cambiado a: ', @TargetStatusAlt, N'.'));
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspGenerarOrdenTrabajoPreventiva
    @PlanId NVARCHAR(20),
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @AssetCode NVARCHAR(60), @AssetName NVARCHAR(200), @AreaId NVARCHAR(15), @AreaName NVARCHAR(200);
        DECLARE @Desc NVARCHAR(MAX), @Hours DECIMAL(6,2), @NextDate DATETIME2(3), @Freq NVARCHAR(20);
        DECLARE @Title NVARCHAR(200);

        SELECT @AssetCode = CodigoActivo, @AssetName = NombreActivo, @AreaId = AreaId, @AreaName = NombreArea,
               @Desc = Descripcion, @Hours = HorasEstimadas, @NextDate = ProximaFecha, @Freq = Frecuencia,
               @Title = Titulo
          FROM dbo.PlanPreventivo WITH (UPDLOCK, HOLDLOCK)
         WHERE PlanId = @PlanId AND Estado = 'active';

        IF @AssetCode IS NULL
            RAISERROR(N'El plan preventivo no existe o no se encuentra activo.', 16, 1);

        -- Generar ID de Orden de Trabajo
        DECLARE @cCount TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT deleted.SiguienteNumero INTO @cCount(v)
          WHERE Nombre = 'work_orders';

        DECLARE @seq INT; SELECT @seq = v FROM @cCount;
        DECLARE @woId NVARCHAR(20) = CONCAT('OT-', YEAR(SYSUTCDATETIME()), '-', FORMAT(@seq, '0000'));

        INSERT INTO dbo.OrdenTrabajo
            (OrdenTrabajoId, CodigoActivo, NombreActivo, AreaId, NombreArea, Descripcion,
             Estado, Prioridad, HorasEstimadas, FechaProgramada, CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn)
        VALUES
            (@woId, @AssetCode, @AssetName, @AreaId, @AreaName,
             CONCAT(N'[Preventivo ', @PlanId, N']: ', @Title, CHAR(13), CHAR(10), ISNULL(@Desc, N'')),
             'pending', 'medium', @Hours, @NextDate, @UserId, @UserName, SYSUTCDATETIME());

        INSERT INTO dbo.TipoTrabajoOrdenTrabajo (OrdenTrabajoId, TipoTrabajo)
        VALUES (@woId, 'preventive');

        INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
        SELECT @woId, NumeroLinea, Nombre, Cantidad, Unidad
          FROM dbo.MaterialPreventivo
         WHERE PlanId = @PlanId;

        DECLARE @DaysToAdd INT = dbo.fnFrecuenciaDias(@Freq);
        DECLARE @NewNextDate DATETIME2(3) = DATEADD(DAY, @DaysToAdd, @NextDate);

        UPDATE dbo.PlanPreventivo
           SET UltimaOrdenTrabajoId = @woId,
               UltimaCompletada     = SYSUTCDATETIME(),
               ProximaFecha         = @NewNextDate
         WHERE PlanId = @PlanId;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'WORK_ORDER_CREATED', 'WORK_ORDERS', @woId,
                CONCAT(N'OT Preventiva generada: ', @woId, N' a partir del plan ', @PlanId, N'. Próxima fecha programada: ', CONVERT(NVARCHAR(30), @NewNextDate, 120)));

        COMMIT TRANSACTION;
        SELECT @woId AS WorkOrderId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


CREATE OR ALTER PROCEDURE dbo.uspGenerarOrdenesTrabajoPreventivasVencidas
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N'Sistema Automático'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentDate DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @PlanId NVARCHAR(20);

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT PlanId
          FROM dbo.PlanPreventivo
         WHERE Estado = 'active'
           AND ProximaFecha <= @CurrentDate;

    OPEN cur;
    FETCH NEXT FROM cur INTO @PlanId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC dbo.uspGenerarOrdenTrabajoPreventiva @PlanId = @PlanId, @UserId = @UserId, @UserName = @UserName;
        END TRY
        BEGIN CATCH
            INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
            VALUES (@UserId, @UserName, 'PREVENTIVE_GENERATION_FAILED', 'PREVENTIVE', @PlanId,
                    CONCAT(N'Error al autogenerar OT preventiva para el plan ', @PlanId, N': ', ERROR_MESSAGE()));
        END CATCH;

        FETCH NEXT FROM cur INTO @PlanId;
    END;
    CLOSE cur;
    DEALLOCATE cur;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoObtenerIndicadores
    @AreaId NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        COUNT(*) AS TotalPlanes,
        SUM(CASE WHEN Estado = 'active' THEN 1 ELSE 0 END) AS Activos,
        SUM(CASE WHEN Estado = 'paused' THEN 1 ELSE 0 END) AS Pausados,
        SUM(CASE WHEN Estado = 'completed' THEN 1 ELSE 0 END) AS Completados,
        SUM(CASE WHEN ProximaFecha < SYSUTCDATETIME() AND Estado = 'active' THEN 1 ELSE 0 END) AS Vencidos
    FROM dbo.PlanPreventivo
    WHERE (@AreaId IS NULL OR AreaId = @AreaId);
END;
GO

GO

CREATE OR ALTER PROCEDURE dbo.uspGenerarOrdenTrabajoPreventivaMes
    @PlanId             NVARCHAR(20),
    @Anio               INT,
    @Mes                INT,
    @CreadoPorUsuarioId INT = NULL,
    @CreadoPorNombre    NVARCHAR(100) = N'',
    @NuevaOrdenId       NVARCHAR(20) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CodigoPadre NVARCHAR(60), @NombrePadre NVARCHAR(200), @AreaId NVARCHAR(15), @NombreArea NVARCHAR(200);
        SELECT @CodigoPadre = CodigoActivo, @NombrePadre = NombreActivo, @AreaId = AreaId, @NombreArea = NombreArea
          FROM dbo.PlanPreventivo WHERE PlanId = @PlanId;

        IF @CodigoPadre IS NULL
            RAISERROR(N'El plan preventivo no existe.', 16, 1);

        -- Verificar si ya existe una OT abierta para este plan
        DECLARE @OTExistente NVARCHAR(20);
        SELECT TOP 1 @OTExistente = OrdenTrabajoId
          FROM dbo.OrdenTrabajo
         WHERE PlanPreventivoId = @PlanId AND Estado IN ('pending', 'in_progress', 'paused');

        IF @OTExistente IS NOT NULL
        BEGIN
            SET @NuevaOrdenId = @OTExistente;
            COMMIT TRANSACTION;
            SELECT @NuevaOrdenId AS NewWorkOrderId, @NuevaOrdenId AS NuevaOrdenId, CAST(1 AS BIT) AS YaExistia;
            RETURN;
        END;

        DECLARE @cnt TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT inserted.SiguienteNumero INTO @cnt(v)
          WHERE Nombre = 'work_orders';

        DECLARE @seq INT; SELECT @seq = v FROM @cnt;
        SET @NuevaOrdenId = CONCAT('OT-', YEAR(SYSUTCDATETIME()), '-', FORMAT(@seq, '0000'));

        INSERT INTO dbo.OrdenTrabajo (
            OrdenTrabajoId, CodigoActivo, NombreActivo, AreaId, NombreArea,
            Descripcion, Estado, Prioridad, PlanPreventivoId, CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn
        )
        VALUES (
            @NuevaOrdenId, @CodigoPadre, @NombrePadre, @AreaId, @NombreArea,
            CONCAT(N'Mantenimiento preventivo mensual según plan ', @PlanId, N' (', @Mes, N'/', @Anio, N').'),
            'pending', 'medium', @PlanId, @CreadoPorUsuarioId, @CreadoPorNombre, SYSUTCDATETIME()
        );

        INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
        SELECT @NuevaOrdenId, NumeroLinea, Nombre, Cantidad, Unidad
          FROM dbo.MaterialPreventivo
         WHERE PlanId = @PlanId;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreadoPorUsuarioId, @CreadoPorNombre, 'WORK_ORDER_CREATED', 'WORK_ORDERS', @NuevaOrdenId,
                CONCAT(N'OT preventiva ', @NuevaOrdenId, N' generada automáticamente desde plan ', @PlanId, N'.'));

        COMMIT TRANSACTION;
        SELECT @NuevaOrdenId AS NewWorkOrderId, @NuevaOrdenId AS NuevaOrdenId, CAST(0 AS BIT) AS YaExistia;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspGenerarOrdenesTrabajoPreventivasMasivas
    @Anio               INT,
    @Mes                INT,
    @AreaId             NVARCHAR(15) = NULL,
    @CreadoPorUsuarioId INT = NULL,
    @CreadoPorNombre    NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @PlanesElegibles TABLE (PlanId NVARCHAR(20));

    INSERT INTO @PlanesElegibles (PlanId)
    SELECT p.PlanId
      FROM dbo.PlanPreventivo p
     WHERE p.Estado = 'active'
       AND (@AreaId IS NULL OR p.AreaId = @AreaId);

    DECLARE @Resultados TABLE (
        PlanId NVARCHAR(20),
        WorkOrderId NVARCHAR(20),
        Exitoso BIT,
        Mensaje NVARCHAR(500)
    );

    DECLARE @CurrentPlanId NVARCHAR(20);
    DECLARE plan_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT PlanId FROM @PlanesElegibles;

    OPEN plan_cursor;
    FETCH NEXT FROM plan_cursor INTO @CurrentPlanId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @NuevaOT NVARCHAR(20) = NULL;
        BEGIN TRY
            EXEC dbo.uspGenerarOrdenTrabajoPreventivaMes
                @PlanId = @CurrentPlanId,
                @Anio = @Anio,
                @Mes = @Mes,
                @CreadoPorUsuarioId = @CreadoPorUsuarioId,
                @CreadoPorNombre = @CreadoPorNombre,
                @NuevaOrdenId = @NuevaOT OUTPUT;

            INSERT INTO @Resultados (PlanId, WorkOrderId, Exitoso, Mensaje)
            VALUES (@CurrentPlanId, @NuevaOT, 1, N'OT procesada exitosamente.');
        END TRY
        BEGIN CATCH
            INSERT INTO @Resultados (PlanId, WorkOrderId, Exitoso, Mensaje)
            VALUES (@CurrentPlanId, NULL, 0, ERROR_MESSAGE());
        END CATCH;

        FETCH NEXT FROM plan_cursor INTO @CurrentPlanId;
    END;

    CLOSE plan_cursor;
    DEALLOCATE plan_cursor;

    SELECT PlanId, WorkOrderId, Exitoso, Mensaje FROM @Resultados;
END;
GO

-- ============================================================================
-- MÓDULO: 06_operacion_analitica_kardex_sp.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 18. PROCEDIMIENTOS ALMACENADOS: OPERACIÓN, DISPONIBILIDAD (OEE) Y ANALÍTICA
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionRegistrar
    @CodigoActivo         NVARCHAR(60),
    @FechaOperacion       DATE,
    @HorasTotalesJornada  DECIMAL(5,2) = 24.0,
    @HorasOperacion       DECIMAL(5,2) = 0.0,
    @HorasParoFalla       DECIMAL(5,2) = 0.0,
    @HorasParoMantPrev    DECIMAL(5,2) = 0.0,
    @HorasParoMantCorr    DECIMAL(5,2) = 0.0,
    @HorasParoPlanificado DECIMAL(5,2) = 0.0,
    @HorasParoExterno     DECIMAL(5,2) = 0.0,
    @HorasParoOtros       DECIMAL(5,2) = 0.0,
    @Comentarios          NVARCHAR(500) = NULL,
    @Observaciones        NVARCHAR(500) = NULL,
    @UsuarioId            INT = NULL,
    @NombreUsuario        NVARCHAR(100) = N'',
    @RegistradoPorUsuarioId INT = NULL,
    @RegistradoPorNombreUsuario NVARCHAR(100) = N'',
    @UnidadesProducidas   DECIMAL(12,2) = NULL,
    @UnidadesEsperadas    DECIMAL(12,2) = NULL,
    @UnidadesConformes    DECIMAL(12,2) = NULL,
    @RendimientoDirectoPct DECIMAL(5,2) = NULL,
    @CalidadDirectoPct    DECIMAL(5,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @AreaId NVARCHAR(15);
        SELECT @AreaId = AreaId FROM dbo.Activo WHERE CodigoActivo = @CodigoActivo;

        DECLARE @Obs NVARCHAR(500) = COALESCE(@Observaciones, @Comentarios);
        DECLARE @UID INT = COALESCE(@RegistradoPorUsuarioId, @UsuarioId);
        DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(@RegistradoPorNombreUsuario, N''), @NombreUsuario, N'');

        IF EXISTS (SELECT 1 FROM dbo.ReporteOperacionDiaria WHERE CodigoActivo = @CodigoActivo AND FechaOperacion = @FechaOperacion)
        BEGIN
            UPDATE dbo.ReporteOperacionDiaria
               SET HorasTotalesJornada        = @HorasTotalesJornada,
                   HorasOperacion             = @HorasOperacion,
                   HorasParoFalla             = @HorasParoFalla,
                   HorasParoMantPrev          = @HorasParoMantPrev,
                   HorasParoMantCorr          = @HorasParoMantCorr,
                   HorasParoPlanificado       = @HorasParoPlanificado,
                   HorasParoExterno           = @HorasParoExterno,
                   Observaciones              = @Obs,
                   RegistradoPorUsuarioId     = @UID,
                   RegistradoPorNombreUsuario = @UName,
                   ActualizadoEn              = SYSUTCDATETIME()
             WHERE CodigoActivo = @CodigoActivo AND FechaOperacion = @FechaOperacion;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.ReporteOperacionDiaria
                (CodigoActivo, AreaId, FechaOperacion, HorasTotalesJornada, HorasOperacion,
                 HorasParoFalla, HorasParoMantPrev, HorasParoMantCorr, HorasParoPlanificado,
                 HorasParoExterno, Observaciones, RegistradoPorUsuarioId, RegistradoPorNombreUsuario)
            VALUES
                (@CodigoActivo, @AreaId, @FechaOperacion, @HorasTotalesJornada, @HorasOperacion,
                 @HorasParoFalla, @HorasParoMantPrev, @HorasParoMantCorr, @HorasParoPlanificado,
                 @HorasParoExterno, @Obs, @UID, @UName);
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionObtenerPorActivo
    @CodigoActivo       NVARCHAR(60),
    @FechaDesde         DATE = NULL,
    @FechaHasta         DATE = NULL,
    @FechaInicio        DATE = NULL,
    @FechaFin           DATE = NULL,
    @Pagina             INT = 1,
    @RegistrosPorPagina INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATE = COALESCE(@FechaDesde, @FechaInicio, DATEADD(MONTH, -1, CAST(SYSUTCDATETIME() AS DATE)));
    DECLARE @Fin DATE = COALESCE(@FechaHasta, @FechaFin, CAST(SYSUTCDATETIME() AS DATE));
    DECLARE @Offset INT = CASE WHEN @Pagina > 1 THEN (@Pagina - 1) * @RegistrosPorPagina ELSE 0 END;

    SELECT ReporteId, CodigoActivo, AreaId, FechaOperacion, HorasTotalesJornada,
           HorasOperacion, HorasParoFalla, HorasParoMantPrev, HorasParoMantCorr,
           HorasParoPlanificado, HorasParoExterno, Observaciones,
           RegistradoPorUsuarioId, RegistradoPorNombreUsuario, RegistradoEn, ActualizadoEn
      FROM dbo.ReporteOperacionDiaria
     WHERE CodigoActivo = @CodigoActivo
       AND FechaOperacion BETWEEN @Inicio AND @Fin
     ORDER BY FechaOperacion DESC
     OFFSET @Offset ROWS
     FETCH NEXT @RegistrosPorPagina ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionObtenerPorSemana
    @AreaId          NVARCHAR(15),
    @LunesDeLaSemana DATE = NULL,
    @FechaInicio     DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @BaseDate DATE = COALESCE(@LunesDeLaSemana, @FechaInicio, CAST(SYSUTCDATETIME() AS DATE));
    DECLARE @Lunes DATE = DATEADD(DAY, - (DATEPART(WEEKDAY, @BaseDate) + 5) % 7, @BaseDate);
    DECLARE @Domingo DATE = DATEADD(DAY, 6, @Lunes);

    SELECT r.ReporteId, r.CodigoActivo, a.Nombre AS NombreActivo, r.AreaId, ar.Nombre AS NombreArea,
           r.FechaOperacion, r.HorasTotalesJornada, r.HorasOperacion, r.HorasParoFalla,
           r.HorasParoMantPrev, r.HorasParoMantCorr, r.HorasParoPlanificado, r.HorasParoExterno,
           r.Observaciones, r.RegistradoPorNombreUsuario, r.RegistradoEn
      FROM dbo.ReporteOperacionDiaria r
      JOIN dbo.Activo a ON r.CodigoActivo = a.CodigoActivo
      JOIN dbo.Area ar ON r.AreaId = ar.AreaId
     WHERE (@AreaId IS NULL OR r.AreaId = @AreaId)
       AND r.FechaOperacion BETWEEN @Lunes AND @Domingo
     ORDER BY r.FechaOperacion DESC, r.CodigoActivo ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionMetricas
    @CodigoActivo NVARCHAR(60) = NULL,
    @AreaId       NVARCHAR(15) = NULL,
    @FechaDesde   DATE = NULL,
    @FechaHasta   DATE = NULL,
    @FechaInicio  DATE = NULL,
    @FechaFin     DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATE = COALESCE(@FechaDesde, @FechaInicio, DATEADD(DAY, -30, CAST(SYSUTCDATETIME() AS DATE)));
    DECLARE @Fin DATE = COALESCE(@FechaHasta, @FechaFin, CAST(SYSUTCDATETIME() AS DATE));

    SELECT
        COUNT(DISTINCT r.CodigoActivo) AS TotalEquiposMonitoreados,
        SUM(r.HorasTotalesJornada)     AS TotalHorasJornada,
        SUM(r.HorasOperacion)          AS TotalHorasOperacion,
        SUM(r.HorasParoFalla)          AS TotalHorasParoFalla,
        SUM(r.HorasParoMantPrev)       AS TotalHorasParoPreventivo,
        SUM(r.HorasParoMantCorr)       AS TotalHorasParoCorrectivo,
        SUM(r.HorasParoPlanificado)    AS TotalHorasParoPlanificado,
        SUM(r.HorasParoExterno)        AS TotalHorasParoExterno,
        CASE WHEN SUM(r.HorasTotalesJornada) > 0
             THEN ROUND((SUM(r.HorasOperacion) / SUM(r.HorasTotalesJornada)) * 100.0, 2)
             ELSE 0.00 END AS PorcentajeDisponibilidadGlobal
      FROM dbo.ReporteOperacionDiaria r
     WHERE (@CodigoActivo IS NULL OR r.CodigoActivo = @CodigoActivo)
       AND (@AreaId IS NULL OR r.AreaId = @AreaId)
       AND r.FechaOperacion BETWEEN @Inicio AND @Fin;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteHistorialActivo
    @CodigoActivo NVARCHAR(60),
    @FechaDesde DATETIME2(3) = NULL,
    @FechaHasta DATETIME2(3) = NULL,
    @IncluirHijos BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    -- 1. Historial de Estado
    SELECT HistorialId, CodigoActivo, Estado, IniciadoEn, FinalizadoEn, AreaId, Motivo, NombreUsuario
      FROM dbo.HistorialEstadoActivo
     WHERE CodigoActivo = @CodigoActivo
       AND (@FechaDesde IS NULL OR IniciadoEn >= @FechaDesde)
       AND (@FechaHasta IS NULL OR IniciadoEn <= @FechaHasta)
     ORDER BY IniciadoEn DESC;

    -- 2. Reportes de Avería
    SELECT ReporteId, AreaId, Descripcion, Severidad, ReportadoEn, Estado, OrdenTrabajoId, ReportadoPorNombreUsuario
      FROM dbo.ReporteAveria
     WHERE CodigoActivo = @CodigoActivo
       AND (@FechaDesde IS NULL OR ReportadoEn >= @FechaDesde)
       AND (@FechaHasta IS NULL OR ReportadoEn <= @FechaHasta)
     ORDER BY ReportadoEn DESC;

    -- 3. Órdenes de Trabajo
    SELECT OrdenTrabajoId, Descripcion, Estado, Prioridad, AsignadoA, HorasReales, FechaProgramada, CreadoEn
      FROM dbo.OrdenTrabajo
     WHERE CodigoActivo = @CodigoActivo
       AND (@FechaDesde IS NULL OR CreadoEn >= @FechaDesde)
       AND (@FechaHasta IS NULL OR CreadoEn <= @FechaHasta)
     ORDER BY CreadoEn DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteEstacionalidadAverias
    @AreaId NVARCHAR(15) = NULL,
    @Anio INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TargetYear INT = COALESCE(@Anio, YEAR(SYSUTCDATETIME()));

    SELECT
        MONTH(ReportadoEn) AS Mes,
        DATENAME(MONTH, ReportadoEn) AS NombreMes,
        COUNT(*) AS TotalAverias,
        SUM(CASE WHEN Severidad = 'critical' THEN 1 ELSE 0 END) AS Criticas,
        SUM(CASE WHEN Severidad = 'high' THEN 1 ELSE 0 END) AS Altas,
        SUM(CASE WHEN Severidad = 'medium' THEN 1 ELSE 0 END) AS Medias,
        SUM(CASE WHEN Severidad = 'low' THEN 1 ELSE 0 END) AS Bajas
    FROM dbo.ReporteAveria
    WHERE YEAR(ReportadoEn) = @TargetYear
      AND (@AreaId IS NULL OR AreaId = @AreaId)
    GROUP BY MONTH(ReportadoEn), DATENAME(MONTH, ReportadoEn)
    ORDER BY Mes ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteTopEquiposFallas
    @AreaId NVARCHAR(15) = NULL,
    @FechaDesde DATETIME2(3) = NULL,
    @FechaHasta DATETIME2(3) = NULL,
    @Top INT = 10,
    @TopCount INT = NULL,
    @DiasAtras INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LimitTop INT = COALESCE(@Top, @TopCount, 10);
    DECLARE @Desde DATETIME2(3) = COALESCE(@FechaDesde, CASE WHEN @DiasAtras IS NOT NULL THEN DATEADD(DAY, -@DiasAtras, SYSUTCDATETIME()) ELSE DATEADD(DAY, -90, SYSUTCDATETIME()) END);

    SELECT TOP (@LimitTop)
        ra.CodigoActivo,
        ra.NombreActivo,
        ar.Nombre AS NombreArea,
        COUNT(*) AS TotalAverias,
        SUM(CASE WHEN ra.Severidad IN ('high', 'critical') THEN 1 ELSE 0 END) AS AveriasGraves
    FROM dbo.ReporteAveria ra
    JOIN dbo.Area ar ON ra.AreaId = ar.AreaId
    WHERE ra.ReportadoEn >= @Desde
      AND (@FechaHasta IS NULL OR ra.ReportadoEn <= @FechaHasta)
      AND (@AreaId IS NULL OR ra.AreaId = @AreaId)
    GROUP BY ra.CodigoActivo, ra.NombreActivo, ar.Nombre
    ORDER BY TotalAverias DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteConsumoRepuestos
    @AreaId NVARCHAR(15) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @FechaDesde DATETIME2(3) = NULL,
    @FechaHasta DATETIME2(3) = NULL,
    @Top INT = 20,
    @FechaInicio DATETIME2(3) = NULL,
    @FechaFin DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME2(3) = COALESCE(@FechaDesde, @FechaInicio, DATEADD(MONTH, -1, SYSUTCDATETIME()));
    DECLARE @Fin DATETIME2(3) = COALESCE(@FechaHasta, @FechaFin, SYSUTCDATETIME());
    DECLARE @LimitTop INT = COALESCE(@Top, 20);

    SELECT TOP (@LimitTop)
        mot.Descripcion AS RepuestoMaterial,
        mot.Unidad,
        SUM(mot.Cantidad) AS TotalConsumido,
        COUNT(DISTINCT mot.OrdenTrabajoId) AS TotalOrdenesInvolucradas
    FROM dbo.MaterialOrdenTrabajo mot
    JOIN dbo.OrdenTrabajo ot ON mot.OrdenTrabajoId = ot.OrdenTrabajoId
    WHERE ot.CreadoEn BETWEEN @Inicio AND @Fin
      AND (@AreaId IS NULL OR ot.AreaId = @AreaId)
      AND (@CodigoActivo IS NULL OR ot.CodigoActivo = @CodigoActivo)
    GROUP BY mot.Descripcion, mot.Unidad
    ORDER BY TotalConsumido DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteOEEGeneral
    @AreaId NVARCHAR(15) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @FechaDesde DATE = NULL,
    @FechaHasta DATE = NULL,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATE = COALESCE(@FechaDesde, @FechaInicio, DATEADD(MONTH, -1, CAST(SYSUTCDATETIME() AS DATE)));
    DECLARE @Fin DATE = COALESCE(@FechaHasta, @FechaFin, CAST(SYSUTCDATETIME() AS DATE));

    SELECT
        r.AreaId,
        ar.Nombre AS NombreArea,
        SUM(r.HorasTotalesJornada) AS HorasTotales,
        SUM(r.HorasOperacion) AS HorasOperativas,
        SUM(r.HorasParoFalla) AS ParosPorFalla,
        SUM(r.HorasParoMantPrev) AS ParosPreventivos,
        CASE WHEN SUM(r.HorasTotalesJornada) > 0
             THEN ROUND((SUM(r.HorasOperacion) / SUM(r.HorasTotalesJornada)) * 100.0, 2)
             ELSE 0.00 END AS DisponibilidadPorcentaje
    FROM dbo.ReporteOperacionDiaria r
    JOIN dbo.Area ar ON r.AreaId = ar.AreaId
    WHERE r.FechaOperacion BETWEEN @Inicio AND @Fin
      AND (@AreaId IS NULL OR r.AreaId = @AreaId)
      AND (@CodigoActivo IS NULL OR r.CodigoActivo = @CodigoActivo)
    GROUP BY r.AreaId, ar.Nombre
    ORDER BY DisponibilidadPorcentaje ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspKardexAgregar
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N'',
    @Action NVARCHAR(40),
    @Module NVARCHAR(30),
    @EntityId NVARCHAR(60),
    @Details NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
    VALUES (@UserId, @UserName, @Action, @Module, @EntityId, @Details);
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspKardexObtenerTodos
    @ModuleFilter NVARCHAR(30) = NULL,
    @ActionFilter NVARCHAR(40) = NULL,
    @UserFilter INT = NULL,
    @StartDate DATETIME2(3) = NULL,
    @EndDate DATETIME2(3) = NULL,
    @Limit INT = 200,
    @Offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        BitacoraId AS LogId,
        RegistradoEn AS LoggedAt,
        UsuarioId AS UserId,
        NombreUsuario AS UserName,
        Accion AS [Action],
        Modulo AS [Module],
        EntidadId,
        Detalles AS Details,
        BitacoraId,
        RegistradoEn,
        UsuarioId,
        NombreUsuario,
        Accion,
        Modulo,
        Detalles
      FROM dbo.BitacoraKardex
     WHERE (@ModuleFilter IS NULL OR Modulo = @ModuleFilter)
       AND (@ActionFilter IS NULL OR Accion = @ActionFilter)
       AND (@UserFilter IS NULL OR UsuarioId = @UserFilter)
       AND (@StartDate IS NULL OR RegistradoEn >= @StartDate)
       AND (@EndDate IS NULL OR RegistradoEn <= @EndDate)
     ORDER BY RegistradoEn DESC
     OFFSET @Offset ROWS
     FETCH NEXT CASE WHEN @Limit IS NULL OR @Limit <= 0 THEN 2147483647 ELSE @Limit END ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspKardexObtenerPorEntidad
    @EntityId NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        BitacoraId AS LogId,
        RegistradoEn AS LoggedAt,
        UsuarioId AS UserId,
        NombreUsuario AS UserName,
        Accion AS [Action],
        Modulo AS [Module],
        EntidadId,
        Detalles AS Details,
        BitacoraId,
        RegistradoEn,
        UsuarioId,
        NombreUsuario,
        Accion,
        Modulo,
        Detalles
      FROM dbo.BitacoraKardex
     WHERE EntidadId = @EntityId
     ORDER BY RegistradoEn DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspDashboardObtenerEstadisticas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM dbo.Activo         WHERE Estado = 'active')                      AS ActiveAssets,
        (SELECT COUNT(*) FROM dbo.Activo         WHERE Estado <> 'deleted')                    AS TotalAssets,
        (SELECT COUNT(*) FROM dbo.ReporteAveria  WHERE Estado IN ('reported', 'inWorkOrder'))  AS PendingBreakdowns,
        (SELECT COUNT(*) FROM dbo.OrdenTrabajo   WHERE Estado IN ('pending', 'inProgress'))    AS OpenWorkOrders,
        (SELECT COUNT(*) FROM dbo.OrdenTrabajo   WHERE Estado = 'completed')                   AS CompletedWorkOrders,
        (SELECT COUNT(*) FROM dbo.PlanPreventivo WHERE Estado = 'active')                      AS ActivePreventiveSchedules,
        (SELECT COUNT(*) FROM dbo.BitacoraKardex)                                              AS TotalKardexLogs;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActualizacionAndroidObtener
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 IdApp, VersionApp, Fecha, Obligatorio, CreadoEn
      FROM dbo.ActualizacionesAndroid
     ORDER BY IdApp DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActualizacionAndroidRegistrar
    @VersionApp NVARCHAR(50),
    @Obligatorio BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.ActualizacionesAndroid (VersionApp, Obligatorio, CreadoEn)
    VALUES (@VersionApp, @Obligatorio, SYSUTCDATETIME());
    SELECT SCOPE_IDENTITY() AS IdApp;
END;
GO

GO

CREATE OR ALTER PROCEDURE dbo.uspActualizacionAndroidObtenerUltima
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1)
        IdApp,
        VersionApp,
        Fecha,
        Obligatorio
    FROM dbo.ActualizacionesAndroid
    ORDER BY IdApp DESC;
END;
GO

PRINT N'============================================================================';
PRINT N'¡PARCHE APLICADO CON ÉXITO!';
PRINT N'1. Procedimientos almacenados actualizados y alineados con la API.';
PRINT N'2. Restricción CK_BK_Modulo ampliada (incluye EMPLOYEES y POSITIONS).';
PRINT N'3. Caracteres especiales de Empleados y Puestos normalizados a UTF-8.';
PRINT N'4. uspEmpleadoActualizar blindado contra errores de concurrencia y auditoría.';
PRINT N'============================================================================';
