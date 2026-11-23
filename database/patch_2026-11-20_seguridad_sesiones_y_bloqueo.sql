-- ============================================================================
-- PARCHE 2026-11-20: SEGURIDAD, CONTROL DE SESIONES SIMULTÁNEAS Y BLOQUEO EXTENDIDO
-- 1. Actualizar bloqueo temporal por intentos fallidos a 15 minutos (antes 5 min)
-- 2. Crear tabla dbo.SesionUsuario para trazabilidad y límite de 2 sesiones concurrentes (FIFO)
-- 3. Crear SPs: dbo.uspSesionRegistrar, dbo.uspSesionVerificar, dbo.uspSesionCerrar
-- ============================================================================

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Actualizar procedimiento de registro de fallo de login (15 minutos de bloqueo)
CREATE OR ALTER PROCEDURE dbo.uspLoginRegistrarFallo
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Usuario
       SET IntentosFallidos = IntentosFallidos + 1,
           BloqueadoHasta   = CASE WHEN IntentosFallidos + 1 >= 5 THEN DATEADD(MINUTE, 15, SYSUTCDATETIME()) ELSE BloqueadoHasta END,
           ActualizadoEn    = SYSUTCDATETIME()
     WHERE UsuarioId = @UserId;
END;
GO

-- 2. Crear tabla de sesiones si no existe
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'SesionUsuario' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.SesionUsuario (
        SesionId          BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SesionUsuario PRIMARY KEY,
        UsuarioId         INT NOT NULL,
        TokenId           NVARCHAR(64) NOT NULL,
        IpOrigen          NVARCHAR(45) NULL,
        UserAgent         NVARCHAR(255) NULL,
        CreadoEn          DATETIME2(3) NOT NULL CONSTRAINT DF_SesionUsuario_CreadoEn DEFAULT (SYSUTCDATETIME()),
        UltimaActividad   DATETIME2(3) NOT NULL CONSTRAINT DF_SesionUsuario_UltimaActividad DEFAULT (SYSUTCDATETIME()),
        Activa            BIT NOT NULL CONSTRAINT DF_SesionUsuario_Activa DEFAULT (1),
        CONSTRAINT FK_SesionUsuario_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuario(UsuarioId) ON DELETE CASCADE
    );

    CREATE NONCLUSTERED INDEX IX_SesionUsuario_Usuario_Activa
        ON dbo.SesionUsuario (UsuarioId, Activa, CreadoEn DESC);

    CREATE UNIQUE NONCLUSTERED INDEX UX_SesionUsuario_TokenId
        ON dbo.SesionUsuario (TokenId);
END;
GO

-- 3. Registrar nueva sesión y aplicar política de máximo 2 sesiones simultáneas (FIFO)
CREATE OR ALTER PROCEDURE dbo.uspSesionRegistrar
    @UsuarioId INT,
    @TokenId   NVARCHAR(64),
    @IpOrigen  NVARCHAR(45) = NULL,
    @UserAgent NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Insertar la nueva sesión como activa
        INSERT INTO dbo.SesionUsuario (UsuarioId, TokenId, IpOrigen, UserAgent, CreadoEn, UltimaActividad, Activa)
        VALUES (@UsuarioId, @TokenId, @IpOrigen, @UserAgent, SYSUTCDATETIME(), SYSUTCDATETIME(), 1);

        -- Desplazar (inactivar) cualquier sesión previa que supere el límite de 2 activas más recientes
        ;WITH SesionesOrdenadas AS (
            SELECT SesionId,
                   ROW_NUMBER() OVER (ORDER BY CreadoEn DESC, SesionId DESC) AS Fila
              FROM dbo.SesionUsuario
             WHERE UsuarioId = @UsuarioId
               AND Activa = 1
        )
        UPDATE s
           SET Activa = 0
          FROM dbo.SesionUsuario s
          JOIN SesionesOrdenadas o ON s.SesionId = o.SesionId
         WHERE o.Fila > 2;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 4. Verificar si la sesión sigue activa y actualizar última actividad
CREATE OR ALTER PROCEDURE dbo.uspSesionVerificar
    @UsuarioId INT,
    @TokenId   NVARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Activa BIT = 0;

    SELECT TOP (1) @Activa = Activa
      FROM dbo.SesionUsuario
     WHERE UsuarioId = @UsuarioId
       AND TokenId = @TokenId;

    IF @Activa = 1
    BEGIN
        UPDATE dbo.SesionUsuario
           SET UltimaActividad = SYSUTCDATETIME()
         WHERE UsuarioId = @UsuarioId
           AND TokenId = @TokenId;
    END;

    SELECT ISNULL(@Activa, 0) AS Activa;
END;
GO

-- 5. Cerrar sesión explícitamente (Logout)
CREATE OR ALTER PROCEDURE dbo.uspSesionCerrar
    @UsuarioId INT,
    @TokenId   NVARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.SesionUsuario
       SET Activa = 0,
           UltimaActividad = SYSUTCDATETIME()
     WHERE UsuarioId = @UsuarioId
       AND TokenId = @TokenId;
END;
GO
