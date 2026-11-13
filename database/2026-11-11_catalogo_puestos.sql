-- ============================================================================
-- SCRIPT DE MIGRACIÓN: Catálogo Dinámico de Puestos / Cargos de Empleados
-- Fecha: 2026-11-11
-- Autor: Grupo MACSA - Sistema CMMS
-- ============================================================================
-- 1. Crea la tabla dbo.Puesto para el catálogo dinámico de cargos.
-- 2. Procedimientos almacenados para Listar, Crear, Actualizar y Eliminar puestos.
-- 3. Semilla inicial de puestos técnicos y operativos.
-- 4. Permisos de ejecución para macsa_app.
-- ============================================================================

USE [MacsaCMMS];
GO

SET NOCOUNT ON;
GO

PRINT 'Iniciando migración: Catálogo de Puestos y Cargos...';
GO

-- 1. Creación de la Tabla dbo.Puesto
IF OBJECT_ID('dbo.Puesto', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Puesto (
        PuestoId        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Puesto PRIMARY KEY,
        Nombre          NVARCHAR(100) NOT NULL CONSTRAINT UQ_Puesto_Nombre UNIQUE,
        EsMantenimiento BIT NOT NULL CONSTRAINT DF_Puesto_EsMantenimiento DEFAULT 1,
        Activo          BIT NOT NULL CONSTRAINT DF_Puesto_Activo DEFAULT 1,
        CreadoEn        DATETIME2(3) NOT NULL CONSTRAINT DF_Puesto_CreadoEn DEFAULT SYSUTCDATETIME(),
        ActualizadoEn   DATETIME2(3) NOT NULL CONSTRAINT DF_Puesto_ActualizadoEn DEFAULT SYSUTCDATETIME()
    );

    CREATE NONCLUSTERED INDEX IX_Puesto_Activo_Nombre
        ON dbo.Puesto (Activo, Nombre);

    PRINT 'Tabla dbo.Puesto creada exitosamente.';
END
ELSE
BEGIN
    PRINT 'La tabla dbo.Puesto ya existe.';
END
GO

-- 2. Procedimiento Almacenado: Listar Puestos
CREATE OR ALTER PROCEDURE dbo.uspPuestoListar
    @SoloActivos BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        p.PuestoId,
        p.Nombre,
        p.EsMantenimiento,
        p.Activo,
        p.CreadoEn,
        p.ActualizadoEn
    FROM dbo.Puesto p
    WHERE (@SoloActivos = 0 OR p.Activo = 1)
    ORDER BY p.Nombre ASC;
END;
GO

-- 3. Procedimiento Almacenado: Crear Puesto
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
        BEGIN
            RAISERROR(N'El nombre del puesto o cargo es obligatorio.', 16, 1);
        END;

        IF EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = @NombreLimpio AND Activo = 1)
        BEGIN
            RAISERROR(N'Ya existe un puesto registrado con ese mismo nombre.', 16, 1);
        END;

        -- Si existía inactivo con ese nombre, reactivarlo
        DECLARE @ExistenteInactivoId INT;
        SELECT @ExistenteInactivoId = PuestoId 
          FROM dbo.Puesto 
         WHERE Nombre = @NombreLimpio AND Activo = 0;

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

        -- Registrar en Kardex
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'POSITION_CREATED', 'EMPLOYEES', CAST(@NuevoId AS NVARCHAR(20)),
                CONCAT(N'Puesto creado/reactivado: ', @NombreLimpio, 
                       CASE WHEN @EsMantenimiento = 1 THEN N' (Técnico Mantenimiento)' ELSE N' (General/Planta)' END));

        COMMIT TRANSACTION;

        SELECT 
            p.PuestoId,
            p.Nombre,
            p.EsMantenimiento,
            p.Activo,
            p.CreadoEn,
            p.ActualizadoEn
        FROM dbo.Puesto p
        WHERE p.PuestoId = @NuevoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 4. Procedimiento Almacenado: Actualizar Puesto
CREATE OR ALTER PROCEDURE dbo.uspPuestoActualizar
    @PuestoId        INT,
    @Nombre          NVARCHAR(100),
    @EsMantenimiento BIT,
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
        BEGIN
            RAISERROR(N'El nombre del puesto es obligatorio.', 16, 1);
        END;

        DECLARE @NombreAntiguo NVARCHAR(100);
        SELECT @NombreAntiguo = Nombre 
          FROM dbo.Puesto WITH (UPDLOCK, HOLDLOCK)
         WHERE PuestoId = @PuestoId;

        IF @NombreAntiguo IS NULL
        BEGIN
            RAISERROR(N'El puesto especificado no existe.', 16, 1);
        END;

        IF EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = @NombreLimpio AND PuestoId <> @PuestoId AND Activo = 1)
        BEGIN
            RAISERROR(N'Ya existe otro puesto con el nombre especificado.', 16, 1);
        END;

        UPDATE dbo.Puesto
           SET Nombre          = @NombreLimpio,
               EsMantenimiento = @EsMantenimiento,
               ActualizadoEn   = SYSUTCDATETIME()
         WHERE PuestoId        = @PuestoId;

        -- Si el nombre cambió, sincronizar en los empleados que tengan el nombre antiguo
        IF @NombreAntiguo <> @NombreLimpio
        BEGIN
            UPDATE dbo.Empleado
               SET Puesto = @NombreLimpio,
                   ActualizadoEn = SYSUTCDATETIME()
             WHERE Puesto = @NombreAntiguo;
        END;

        -- Registrar en Kardex
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'POSITION_UPDATED', 'EMPLOYEES', CAST(@PuestoId AS NVARCHAR(20)),
                CONCAT(N'Puesto modificado: "', @NombreAntiguo, N'" -> "', @NombreLimpio, N'". Mantenimiento: ', @EsMantenimiento));

        COMMIT TRANSACTION;

        SELECT 
            p.PuestoId,
            p.Nombre,
            p.EsMantenimiento,
            p.Activo,
            p.CreadoEn,
            p.ActualizadoEn
        FROM dbo.Puesto p
        WHERE p.PuestoId = @PuestoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 5. Procedimiento Almacenado: Eliminar Puesto (Baja Lógica)
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

        DECLARE @Nombre NVARCHAR(100);
        SELECT @Nombre = Nombre 
          FROM dbo.Puesto WITH (UPDLOCK, HOLDLOCK)
         WHERE PuestoId = @PuestoId;

        IF @Nombre IS NULL
        BEGIN
            RAISERROR(N'El puesto no existe.', 16, 1);
        END;

        -- Baja lógica para no romper integridad histórica
        UPDATE dbo.Puesto
           SET Activo = 0,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE PuestoId = @PuestoId;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'POSITION_DELETED', 'EMPLOYEES', CAST(@PuestoId AS NVARCHAR(20)),
                CONCAT(N'Puesto eliminado del catálogo: ', @Nombre));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 6. Semilla Inicial de Puestos
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto)
BEGIN
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo)
    VALUES 
        (N'Técnico Mecánico Industrial', 1, 1),
        (N'Técnico Electricista / Automatización', 1, 1),
        (N'Técnico Electromecánico', 1, 1),
        (N'Técnico Soldador / Estructuras', 1, 1),
        (N'Técnico en Refrigeración y Calderas', 1, 1),
        (N'Jefe de Mantenimiento', 1, 1),
        (N'Supervisor de Mantenimiento', 1, 1),
        (N'Supervisor de Planta y Producción', 0, 1),
        (N'Jefe de Aseguramiento de Calidad', 0, 1);

    PRINT 'Semilla inicial de puestos registrada.';
END
GO

-- 7. Permisos para el usuario de la aplicación
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'macsa_app')
BEGIN
    GRANT SELECT, INSERT, UPDATE ON dbo.Puesto TO macsa_app;
    GRANT EXECUTE ON dbo.uspPuestoListar TO macsa_app;
    GRANT EXECUTE ON dbo.uspPuestoCrear TO macsa_app;
    GRANT EXECUTE ON dbo.uspPuestoActualizar TO macsa_app;
    GRANT EXECUTE ON dbo.uspPuestoEliminar TO macsa_app;
    PRINT 'Permisos concedidos a macsa_app para el catálogo de puestos.';
END
GO

PRINT 'Migración de Catálogo de Puestos finalizada con éxito.';
GO

