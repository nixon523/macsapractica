/* ============================================================================
   MACSA CMMS - Control de Versiones de la Aplicación Android
   database/migracion_actualizaciones_android.sql
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Crear tabla si no existe
IF OBJECT_ID(N'dbo.ActualizacionesAndroid', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ActualizacionesAndroid (
        IdApp       INT IDENTITY(1,1) NOT NULL,
        VersionApp  NVARCHAR(50)      NOT NULL,
        UrlDescarga NVARCHAR(500)     NULL,
        NotasCambio NVARCHAR(MAX)     NULL,
        Obligatorio BIT               NOT NULL CONSTRAINT DF_ActualizacionesAndroid_Obligatorio DEFAULT (0),
        Fecha       DATE              NOT NULL CONSTRAINT DF_ActualizacionesAndroid_Fecha DEFAULT (CAST(GETDATE() AS DATE)),
        CreadoEn    DATETIME2(0)      NOT NULL CONSTRAINT DF_ActualizacionesAndroid_CreadoEn DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_ActualizacionesAndroid PRIMARY KEY CLUSTERED (IdApp ASC)
    );

    PRINT N'Tabla dbo.ActualizacionesAndroid creada con éxito.';
END
ELSE
BEGIN
    PRINT N'La tabla dbo.ActualizacionesAndroid ya existe.';
END;
GO

-- 2. Stored Procedure para obtener la última versión registrada
CREATE OR ALTER PROCEDURE dbo.uspActualizacionAndroidObtenerUltima
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        IdApp,
        VersionApp,
        UrlDescarga,
        NotasCambio,
        Obligatorio,
        Fecha
    FROM dbo.ActualizacionesAndroid
    ORDER BY IdApp DESC;
END;
GO

-- 3. Stored Procedure opcional para registrar una nueva versión
CREATE OR ALTER PROCEDURE dbo.uspActualizacionAndroidRegistrar
    @VersionApp  NVARCHAR(50),
    @UrlDescarga NVARCHAR(500) = NULL,
    @NotasCambio NVARCHAR(MAX) = NULL,
    @Obligatorio BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.ActualizacionesAndroid (VersionApp, UrlDescarga, NotasCambio, Obligatorio)
    VALUES (@VersionApp, @UrlDescarga, @NotasCambio, @Obligatorio);

    SELECT SCOPE_IDENTITY() AS IdApp;
END;
GO

-- 4. Permisos para el usuario de la aplicación
IF USER_ID('macsa_app') IS NOT NULL
BEGIN
    GRANT SELECT, INSERT ON dbo.ActualizacionesAndroid TO macsa_app;
    GRANT EXECUTE ON dbo.uspActualizacionAndroidObtenerUltima TO macsa_app;
    GRANT EXECUTE ON dbo.uspActualizacionAndroidRegistrar TO macsa_app;
    PRINT N'Permisos otorgados a macsa_app.';
END;
GO

-- 5. Semilla inicial con la versión actual si está vacía
IF NOT EXISTS (SELECT 1 FROM dbo.ActualizacionesAndroid)
BEGIN
    INSERT INTO dbo.ActualizacionesAndroid (VersionApp, UrlDescarga, NotasCambio, Obligatorio)
    VALUES ('1.0.0', NULL, N'Versión base de la aplicación Grupo Macsa.', 0);

    PRINT N'Semilla inicial de versión Android registrada (1.0.0).';
END;
GO
