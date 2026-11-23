-- ============================================================================
-- MACSA CMMS - PARCHE DE REPARACIÓN: EMPLEADOS, USUARIOS Y ACTUALIZACIONES ANDROID
-- Fecha: 2026-11-14
--
-- Contenido del parche:
-- 1. Garantiza la tabla dbo.Puesto y su catálogo base de puestos de trabajo.
-- 2. Asegura la columna PuestoId en dbo.Empleado.
-- 3. Inserta la versión inicial de Android 1.0.1+2 en dbo.ActualizacionesAndroid.
-- 4. Amplía la restricción CK_BK_Modulo en dbo.BitacoraKardex ('EMPLOYEES', 'POSITIONS').
-- 5. Actualiza dbo.uspEmpleadoActualizar, dbo.uspEmpleadoCrear y dbo.uspEmpleadoCambiarEstado
--    blindando la auditoría contra valores nulos o usuarios desvinculados (evita HTTP 500).
-- 6. Actualiza dbo.uspUsuarioActualizar permitiendo modificar el nombre de usuario (NombreUsuario)
--    con validación de unicidad en servidor.
-- ============================================================================

USE [MacsaCMMS];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'Iniciando aplicación del parche 2026-11-14...';
GO

-- ----------------------------------------------------------------------------
-- 1. TABLA dbo.Puesto Y CATÁLOGO INICIAL
-- ----------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.Puesto', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Puesto (
        PuestoId           INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Puesto PRIMARY KEY,
        Nombre             NVARCHAR(100) NOT NULL CONSTRAINT UQ_Puesto_Nombre UNIQUE,
        EsMantenimiento    BIT NOT NULL CONSTRAINT DF_Puesto_EsMantenimiento DEFAULT (1),
        Activo             BIT NOT NULL CONSTRAINT DF_Puesto_Activo DEFAULT (1),
        CreadoEn           DATETIME2(3) NOT NULL CONSTRAINT DF_Puesto_CreadoEn DEFAULT (SYSUTCDATETIME()),
        ActualizadoEn      DATETIME2(3) NOT NULL CONSTRAINT DF_Puesto_ActualizadoEn DEFAULT (SYSUTCDATETIME())
    );

    CREATE NONCLUSTERED INDEX IX_Puesto_Activo_Nombre
        ON dbo.Puesto (Activo, Nombre);

    PRINT N'Tabla dbo.Puesto creada exitosamente.';
END;
GO

-- Población segura de puestos iniciales si no existen
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto)
BEGIN
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo)
    VALUES
        (N'Desarrollador', 0, 1),
        (N'Jefe de Mantenimiento', 1, 1),
        (N'Supervisor de Mantenimiento', 1, 1),
        (N'Técnico Mecánico Industrial', 1, 1),
        (N'Técnico Electricista / Automatización', 1, 1),
        (N'Técnico en Refrigeración y Calderas', 1, 1),
        (N'Técnico Electromecánico', 1, 1),
        (N'Técnico Soldador / Estructuras', 1, 1),
        (N'Auxiliar de Mantenimiento', 1, 1),
        (N'Jefe de Área / Operaciones', 0, 1),
        (N'Supervisor de Producción', 0, 1),
        (N'Gerente General', 0, 1),
        (N'Gerente de Operaciones', 0, 1);
    PRINT N'Catálogo base de dbo.Puesto poblado.';
END;
GO

-- ----------------------------------------------------------------------------
-- 2. ASEGURAR COLUMNA PuestoId EN dbo.Empleado
-- ----------------------------------------------------------------------------
IF COL_LENGTH('dbo.Empleado', 'PuestoId') IS NULL
BEGIN
    ALTER TABLE dbo.Empleado ADD PuestoId INT NULL;
    ALTER TABLE dbo.Empleado ADD CONSTRAINT FK_Empleado_Puesto
        FOREIGN KEY (PuestoId) REFERENCES dbo.Puesto(PuestoId);
    PRINT N'Columna PuestoId agregada a dbo.Empleado.';
END;
GO

-- ----------------------------------------------------------------------------
-- 3. TABLA dbo.ActualizacionesAndroid E INSERCIÓN DE VERSIÓN INICIAL
-- ----------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.ActualizacionesAndroid', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ActualizacionesAndroid (
        IdApp              INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ActualizacionesAndroid PRIMARY KEY,
        VersionApp         NVARCHAR(50) NOT NULL,
        Fecha              DATE NOT NULL CONSTRAINT DF_ActAndroid_Fecha DEFAULT (CAST(SYSUTCDATETIME() AS DATE)),
        Obligatorio        BIT NOT NULL CONSTRAINT DF_ActAndroid_Obligatorio DEFAULT (0),
        CreadoEn           DATETIME2(3) NOT NULL CONSTRAINT DF_ActAndroid_CreadoEn DEFAULT (SYSUTCDATETIME())
    );

    CREATE NONCLUSTERED INDEX IX_ActualizacionesAndroid_IdApp
        ON dbo.ActualizacionesAndroid (IdApp DESC);

    PRINT N'Tabla dbo.ActualizacionesAndroid creada.';
END;
GO

-- Semilla de versión inicial requerida: 1.0.1+2
IF NOT EXISTS (SELECT 1 FROM dbo.ActualizacionesAndroid WHERE VersionApp = N'1.0.1+2')
BEGIN
    INSERT INTO dbo.ActualizacionesAndroid (VersionApp, Fecha, Obligatorio)
    VALUES (N'1.0.1+2', CAST(GETDATE() AS DATE), 0);
    PRINT N'Versión 1.0.1+2 insertada en dbo.ActualizacionesAndroid.';
END;
GO

-- ----------------------------------------------------------------------------
-- 4. GARANTIZAR RESTRICCIÓN CK_BK_Modulo EN dbo.BitacoraKardex
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
-- 5. PROCEDIMIENTOS ALMACENADOS DE EMPLEADOS
-- ----------------------------------------------------------------------------
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
                IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio))
                BEGIN
                    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
                    VALUES (@PuestoLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
                    SET @PuestoId = SCOPE_IDENTITY();
                END
                ELSE
                BEGIN
                    SELECT TOP 1 @PuestoId = PuestoId, @PuestoLimpio = Nombre
                      FROM dbo.Puesto
                     WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio);
                END;
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

        DECLARE @UNameAudit NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@NombreUsuario)), N''), N'SISTEMA');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @UNameAudit, 'EMPLOYEE_UPDATED', 'EMPLOYEES', CAST(@EmpleadoId AS NVARCHAR(20)),
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
                IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio))
                BEGIN
                    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
                    VALUES (@PuestoLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
                    SET @PuestoId = SCOPE_IDENTITY();
                END
                ELSE
                BEGIN
                    SELECT TOP 1 @PuestoId = PuestoId, @PuestoLimpio = Nombre
                      FROM dbo.Puesto
                     WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio);
                END;
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

        DECLARE @UNameAudit NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@NombreUsuario)), N''), N'SISTEMA');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @UNameAudit, 'EMPLOYEE_CREATED', 'EMPLOYEES', CAST(@NuevoId AS NVARCHAR(20)),
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

        DECLARE @UNameAudit NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@NombreUsuario)), N''), N'SISTEMA');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @UNameAudit, 'EMPLOYEE_STATUS_CHANGED', 'EMPLOYEES', CAST(@EmpleadoId AS NVARCHAR(20)),
                CONCAT(N'Estado de empleado ID ', @EmpleadoId, N' cambiado a: ', CASE WHEN @Activo = 1 THEN N'Activo' ELSE N'Inactivo' END, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 6. ACTUALIZAR PROCEDIMIENTO dbo.uspUsuarioActualizar (SOPORTE DE CAMBIO DE USERNAME)
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- 7. PERMISOS DE EJECUCIÓN
-- ----------------------------------------------------------------------------
GRANT EXECUTE ON dbo.uspEmpleadoListar TO PUBLIC;
GRANT EXECUTE ON dbo.uspEmpleadoCrear TO PUBLIC;
GRANT EXECUTE ON dbo.uspEmpleadoActualizar TO PUBLIC;
GRANT EXECUTE ON dbo.uspEmpleadoCambiarEstado TO PUBLIC;
GRANT EXECUTE ON dbo.uspUsuarioActualizar TO PUBLIC;
GRANT EXECUTE ON dbo.uspActualizacionAndroidObtenerUltima TO PUBLIC;
GRANT EXECUTE ON dbo.uspActualizacionAndroidRegistrar TO PUBLIC;
GO

PRINT N'============================================================================';
PRINT N'PARCHE 2026-11-14 APLICADO EXITOSAMENTE.';
PRINT N'============================================================================';
GO
