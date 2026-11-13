-- ============================================================================
-- Migración: Módulo y Catálogo de Empleados (Personal Técnico y de Planta)
-- Fecha: 2026-11-06
-- Autor: Grupo Macsa / Antigravity
-- ============================================================================
-- DESCRIPCIÓN:
-- 1. Crea la tabla dbo.Empleado para almacenar el personal operativo y técnico.
-- 2. Permite clasificar al personal de mantenimiento para asignación ágil en OTs.
-- 3. Permite vincular empleados para la futura creación y control de usuarios.
-- 4. Soporta baja lógica (Activo = 1 / 0) para trazabilidad histórica.
-- 5. Incluye procedimientos almacenados para Listar, Crear, Editar y Cambiar Estado.
-- 6. Siembra datos iniciales de técnicos y supervisores de Grupo Macsa.
-- ============================================================================

USE [MacsaCMMS];
GO

PRINT '============================================================================';
PRINT 'Iniciando migración: Catálogo de Empleados...';
PRINT '============================================================================';
GO

-- 1. Creación de la Tabla dbo.Empleado
IF OBJECT_ID('dbo.Empleado', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Empleado (
        EmpleadoId           INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Empleado PRIMARY KEY,
        NombreCompleto       NVARCHAR(150) NOT NULL,
        AreaId               NVARCHAR(15) NULL CONSTRAINT FK_Empleado_Area REFERENCES dbo.Area(AreaId),
        NombreArea           NVARCHAR(200) NULL,
        Puesto               NVARCHAR(100) NOT NULL,
        EsMantenimiento      BIT NOT NULL CONSTRAINT DF_Empleado_EsMantenimiento DEFAULT 1,
        Activo               BIT NOT NULL CONSTRAINT DF_Empleado_Activo DEFAULT 1,
        CreadoEn             DATETIME2(3) NOT NULL CONSTRAINT DF_Empleado_CreadoEn DEFAULT SYSUTCDATETIME(),
        ActualizadoEn        DATETIME2(3) NOT NULL CONSTRAINT DF_Empleado_ActualizadoEn DEFAULT SYSUTCDATETIME()
    );

    CREATE NONCLUSTERED INDEX IX_Empleado_Activo_Mantenimiento
        ON dbo.Empleado (Activo, EsMantenimiento, NombreCompleto);

    CREATE NONCLUSTERED INDEX IX_Empleado_Area
        ON dbo.Empleado (AreaId);

    PRINT 'Tabla dbo.Empleado creada exitosamente.';
END
ELSE
BEGIN
    PRINT 'La tabla dbo.Empleado ya existe.';
END;
GO

-- 2. Procedimiento Almacenado: Listar Empleados
CREATE OR ALTER PROCEDURE dbo.uspEmpleadoListar
    @SoloActivos     BIT = 1,
    @EsMantenimiento BIT = NULL,
    @AreaId          NVARCHAR(15) = NULL,
    @Busqueda        NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        e.EmpleadoId,
        e.NombreCompleto,
        e.AreaId,
        COALESCE(e.NombreArea, a.Nombre, N'Sin Área Asignada') AS NombreArea,
        e.Puesto,
        e.EsMantenimiento,
        e.Activo,
        e.CreadoEn,
        e.ActualizadoEn
    FROM dbo.Empleado e
    LEFT JOIN dbo.Area a ON e.AreaId = a.AreaId
    WHERE (@SoloActivos = 0 OR e.Activo = 1)
      AND (@EsMantenimiento IS NULL OR e.EsMantenimiento = @EsMantenimiento)
      AND (@AreaId IS NULL OR e.AreaId = @AreaId)
      AND (
          @Busqueda IS NULL 
          OR LTRIM(RTRIM(@Busqueda)) = N''
          OR e.NombreCompleto LIKE CONCAT(N'%', LTRIM(RTRIM(@Busqueda)), N'%')
          OR e.Puesto LIKE CONCAT(N'%', LTRIM(RTRIM(@Busqueda)), N'%')
      )
    ORDER BY e.EsMantenimiento DESC, e.NombreCompleto ASC;
END;
GO

-- 3. Procedimiento Almacenado: Crear Empleado
CREATE OR ALTER PROCEDURE dbo.uspEmpleadoCrear
    @NombreCompleto   NVARCHAR(150),
    @AreaId           NVARCHAR(15) = NULL,
    @Puesto           NVARCHAR(100),
    @EsMantenimiento  BIT = 1,
    @UsuarioId        INT = NULL,
    @NombreUsuario    NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NULLIF(LTRIM(RTRIM(@NombreCompleto)), N'') IS NULL
        BEGIN
            RAISERROR(N'El nombre completo del empleado es obligatorio.', 16, 1);
        END;

        IF NULLIF(LTRIM(RTRIM(@Puesto)), N'') IS NULL
        BEGIN
            RAISERROR(N'El puesto o cargo del empleado es obligatorio.', 16, 1);
        END;

        DECLARE @NombreArea NVARCHAR(200) = NULL;
        IF @AreaId IS NOT NULL
        BEGIN
            SELECT @NombreArea = Nombre FROM dbo.Area WHERE AreaId = @AreaId;
        END;

        INSERT INTO dbo.Empleado (NombreCompleto, AreaId, NombreArea, Puesto, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
        VALUES (LTRIM(RTRIM(@NombreCompleto)), @AreaId, @NombreArea, LTRIM(RTRIM(@Puesto)), @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

        DECLARE @NuevoId INT = SCOPE_IDENTITY();

        -- Auditoría en Kardex
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'EMPLOYEE_CREATED', 'EMPLOYEES', CAST(@NuevoId AS NVARCHAR(20)),
                CONCAT(N'Empleado registrado: ', @NombreCompleto, N' (Puesto: ', @Puesto, N').'));

        COMMIT TRANSACTION;

        SELECT 
            e.EmpleadoId,
            e.NombreCompleto,
            e.AreaId,
            COALESCE(e.NombreArea, a.Nombre, N'Sin Área') AS NombreArea,
            e.Puesto,
            e.EsMantenimiento,
            e.Activo,
            e.CreadoEn,
            e.ActualizadoEn
        FROM dbo.Empleado e
        LEFT JOIN dbo.Area a ON e.AreaId = a.AreaId
        WHERE e.EmpleadoId = @NuevoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 4. Procedimiento Almacenado: Actualizar Empleado
CREATE OR ALTER PROCEDURE dbo.uspEmpleadoActualizar
    @EmpleadoId       INT,
    @NombreCompleto   NVARCHAR(150),
    @AreaId           NVARCHAR(15) = NULL,
    @Puesto           NVARCHAR(100),
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
        BEGIN
            RAISERROR(N'El empleado especificado no existe.', 16, 1);
        END;

        DECLARE @NombreArea NVARCHAR(200) = NULL;
        IF @AreaId IS NOT NULL
        BEGIN
            SELECT @NombreArea = Nombre FROM dbo.Area WHERE AreaId = @AreaId;
        END;

        UPDATE dbo.Empleado
           SET NombreCompleto  = LTRIM(RTRIM(@NombreCompleto)),
               AreaId          = @AreaId,
               NombreArea      = @NombreArea,
               Puesto          = LTRIM(RTRIM(@Puesto)),
               EsMantenimiento = @EsMantenimiento,
               Activo          = @Activo,
               ActualizadoEn   = SYSUTCDATETIME()
         WHERE EmpleadoId      = @EmpleadoId;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'EMPLOYEE_UPDATED', 'EMPLOYEES', CAST(@EmpleadoId AS NVARCHAR(20)),
                CONCAT(N'Empleado actualizado: ', @NombreCompleto, N' (Puesto: ', @Puesto, N', Activo: ', @Activo, N').'));

        COMMIT TRANSACTION;

        SELECT 
            e.EmpleadoId,
            e.NombreCompleto,
            e.AreaId,
            COALESCE(e.NombreArea, a.Nombre, N'Sin Área') AS NombreArea,
            e.Puesto,
            e.EsMantenimiento,
            e.Activo,
            e.CreadoEn,
            e.ActualizadoEn
        FROM dbo.Empleado e
        LEFT JOIN dbo.Area a ON e.AreaId = a.AreaId
        WHERE e.EmpleadoId = @EmpleadoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 5. Procedimiento Almacenado: Cambiar Estado (Baja Lógica / Reactivación)
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

        DECLARE @Nombre NVARCHAR(150);
        SELECT @Nombre = NombreCompleto FROM dbo.Empleado WITH (UPDLOCK, HOLDLOCK) WHERE EmpleadoId = @EmpleadoId;

        IF @Nombre IS NULL
        BEGIN
            RAISERROR(N'El empleado no existe.', 16, 1);
        END;

        UPDATE dbo.Empleado
           SET Activo = @Activo,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE EmpleadoId = @EmpleadoId;

        DECLARE @AccionTxt NVARCHAR(50) = IIF(@Activo = 1, N'EMPLOYEE_REACTIVATED', N'EMPLOYEE_DEACTIVATED');
        DECLARE @DetalleTxt NVARCHAR(250) = IIF(@Activo = 1, 
            CONCAT(N'Empleado reactivado en sistema: ', @Nombre),
            CONCAT(N'Empleado dado de baja lógica: ', @Nombre));

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, @AccionTxt, 'EMPLOYEES', CAST(@EmpleadoId AS NVARCHAR(20)), @DetalleTxt);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 6. Semilla de Empleados Iniciales (Técnicos y Personal Clave)
IF NOT EXISTS (SELECT 1 FROM dbo.Empleado)
BEGIN
    -- Semilla inicial de técnicos de mantenimiento y supervisores
    INSERT INTO dbo.Empleado (NombreCompleto, AreaId, Puesto, EsMantenimiento, Activo)
    VALUES 
        (N'Ing. Nixon Mejía', NULL, N'Jefe de Mantenimiento', 1, 1),
        (N'Carlos Hernández', NULL, N'Técnico Mecánico Industrial', 1, 1),
        (N'Jorge Morales', NULL, N'Técnico Electricista / Automatización', 1, 1),
        (N'Roberto Rivas', NULL, N'Técnico Soldador / Estructuras', 1, 1),
        (N'Miguel Ángel Castillo', NULL, N'Técnico Electromecánico', 1, 1),
        (N'Luis Alberto Fuentes', NULL, N'Técnico en Refrigeración y Calderas', 1, 1),
        (N'Guillermo Pineda', NULL, N'Supervisor de Planta y Producción', 0, 1),
        (N'Sandra Marroquín', NULL, N'Jefe de Aseguramiento de Calidad / HACCP', 0, 1);

    PRINT 'Semilla inicial de empleados registrada.';
END;
GO

PRINT '============================================================================';
PRINT 'Migración de Catálogo de Empleados finalizada con éxito.';
PRINT '============================================================================';
GO

