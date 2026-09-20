/* ============================================================================
   MACSA CMMS - Control de Versiones de la Aplicación Android (Simplificado)
   database/migracion_actualizaciones_android.sql
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Si existen columnas UrlDescarga o NotasCambio, las eliminamos para simplificar la tabla
IF COL_LENGTH('dbo.ActualizacionesAndroid', 'UrlDescarga') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ActualizacionesAndroid DROP COLUMN UrlDescarga;
    PRINT N'Columna UrlDescarga eliminada.';
END;

IF COL_LENGTH('dbo.ActualizacionesAndroid', 'NotasCambio') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ActualizacionesAndroid DROP COLUMN NotasCambio;
    PRINT N'Columna NotasCambio eliminada.';
END;
GO

-- 2. Si la tabla no existe, la creamos con la estructura limpia
IF OBJECT_ID(N'dbo.ActualizacionesAndroid', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ActualizacionesAndroid (
        IdApp       INT IDENTITY(1,1) NOT NULL,
        VersionApp  NVARCHAR(50)      NOT NULL,
        Fecha       DATE              NOT NULL CONSTRAINT DF_ActualizacionesAndroid_Fecha DEFAULT (CAST(GETDATE() AS DATE)),
        Obligatorio BIT               NOT NULL CONSTRAINT DF_ActualizacionesAndroid_Obligatorio DEFAULT (0),
        CreadoEn    DATETIME2(0)      NOT NULL CONSTRAINT DF_ActualizacionesAndroid_CreadoEn DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_ActualizacionesAndroid PRIMARY KEY CLUSTERED (IdApp ASC)
    );
    PRINT N'Tabla dbo.ActualizacionesAndroid creada.';
END;
GO

-- 3. Stored Procedure para consultar la última versión
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

-- 4. Stored Procedure para registrar una nueva versión
CREATE OR ALTER PROCEDURE dbo.uspActualizacionAndroidRegistrar
    @VersionApp  NVARCHAR(50),
    @Obligatorio BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.ActualizacionesAndroid (VersionApp, Obligatorio)
    VALUES (@VersionApp, @Obligatorio);

    SELECT SCOPE_IDENTITY() AS IdApp;
END;
GO

-- 5. Permisos
IF USER_ID('macsa_app') IS NOT NULL
BEGIN
    GRANT SELECT, INSERT ON dbo.ActualizacionesAndroid TO macsa_app;
    GRANT EXECUTE ON dbo.uspActualizacionAndroidObtenerUltima TO macsa_app;
    GRANT EXECUTE ON dbo.uspActualizacionAndroidRegistrar TO macsa_app;
END;
GO
