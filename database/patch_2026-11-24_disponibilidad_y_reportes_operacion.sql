-- ============================================================================
-- MACSA CMMS - PARCHE 2026-11-24: FIX REPORTE OPERACION, DISPONIBILIDAD Y METRICAS
-- ============================================================================
-- Resuelve:
-- 1. Error 500 al guardar reporte diario de equipo de proceso (manejo de AreaId nulo,
--    nombre de usuario vacio, fallback transaccional y retorno del registro con SELECT).
-- 2. Metricas completas (dias con reporte, horas desglosadas, disponibilidad %, MTBF y MTTR).
-- 3. Semanal con disponibilidad calculada y aliases consistentes.
-- 4. Definicion garantizada de uspEquipoProcesoListarPorArea.
-- ============================================================================

USE [MacsaCMMS];
GO

-- 1. PROCEDIMIENTO: REGISTRAR REPORTE DE OPERACION DIARIA
CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionRegistrar
    @CodigoActivo               NVARCHAR(60),
    @FechaOperacion             DATE,
    @HorasTotalesJornada        DECIMAL(5,2) = 24.0,
    @HorasOperacion             DECIMAL(5,2) = 0.0,
    @HorasParoFalla             DECIMAL(5,2) = 0.0,
    @HorasParoMantPrev          DECIMAL(5,2) = 0.0,
    @HorasParoMantCorr          DECIMAL(5,2) = 0.0,
    @HorasParoPlanificado       DECIMAL(5,2) = 0.0,
    @HorasParoExterno           DECIMAL(5,2) = 0.0,
    @HorasParoOtros             DECIMAL(5,2) = 0.0,
    @Observaciones              NVARCHAR(1000) = NULL,
    @Comentarios                NVARCHAR(1000) = NULL,
    @UsuarioId                  INT = NULL,
    @NombreUsuario              NVARCHAR(200) = N'',
    @RegistradoPorUsuarioId     INT = NULL,
    @RegistradoPorNombreUsuario NVARCHAR(200) = N'',
    @AreaId                     NVARCHAR(15) = NULL,
    @UnidadesProducidas         DECIMAL(12,2) = NULL,
    @UnidadesEsperadas          DECIMAL(12,2) = NULL,
    @UnidadesConformes          DECIMAL(12,2) = NULL,
    @RendimientoDirectoPct      DECIMAL(5,2) = NULL,
    @CalidadDirectoPct          DECIMAL(5,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1.1 Determinar ÁreaId con fallback seguro
        DECLARE @ResAreaId NVARCHAR(15) = @AreaId;
        IF @ResAreaId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @ResAreaId)
        BEGIN
            SELECT @ResAreaId = AreaId FROM dbo.Activo WHERE CodigoActivo = @CodigoActivo;
        END;
        IF @ResAreaId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @ResAreaId)
        BEGIN
            SELECT TOP 1 @ResAreaId = AreaId FROM dbo.Area ORDER BY AreaId ASC;
        END;

        -- 1.2 Sanitizar observaciones y usuario
        DECLARE @Obs NVARCHAR(1000) = COALESCE(@Observaciones, @Comentarios);
        DECLARE @UID INT = COALESCE(@RegistradoPorUsuarioId, @UsuarioId);
        DECLARE @UName NVARCHAR(200) = COALESCE(NULLIF(LTRIM(RTRIM(@RegistradoPorNombreUsuario)), N''),
                                                NULLIF(LTRIM(RTRIM(@NombreUsuario)), N''),
                                                N'Sistema');

        -- 1.3 Upsert de ReporteOperacionDiaria
        IF EXISTS (SELECT 1 FROM dbo.ReporteOperacionDiaria WHERE CodigoActivo = @CodigoActivo AND FechaOperacion = @FechaOperacion)
        BEGIN
            UPDATE dbo.ReporteOperacionDiaria
               SET AreaId                     = COALESCE(@ResAreaId, AreaId),
                   HorasTotalesJornada        = @HorasTotalesJornada,
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
                 HorasParoExterno, Observaciones, RegistradoPorUsuarioId, RegistradoPorNombreUsuario, RegistradoEn)
            VALUES
                (@CodigoActivo, @ResAreaId, @FechaOperacion, @HorasTotalesJornada, @HorasOperacion,
                 @HorasParoFalla, @HorasParoMantPrev, @HorasParoMantCorr, @HorasParoPlanificado,
                 @HorasParoExterno, @Obs, @UID, @UName, SYSUTCDATETIME());
        END;

        COMMIT TRANSACTION;

        -- 1.4 Retornar el registro persistido al cliente (requerido por API y Frontend)
        SELECT TOP 1
            r.ReporteId,
            r.CodigoActivo,
            COALESCE(a.Nombre, r.CodigoActivo) AS NombreActivo,
            r.AreaId,
            COALESCE(ar.Nombre, r.AreaId) AS NombreArea,
            r.FechaOperacion,
            r.HorasTotalesJornada,
            r.HorasOperacion,
            r.HorasParoFalla,
            r.HorasParoMantPrev,
            r.HorasParoMantCorr,
            r.HorasParoPlanificado,
            r.HorasParoExterno,
            r.Observaciones,
            CONCAT(DATEPART(YEAR, r.FechaOperacion), '-W', RIGHT('0' + CAST(DATEPART(ISO_WEEK, r.FechaOperacion) AS VARCHAR(2)), 2)) AS SemanaISO,
            r.RegistradoPorUsuarioId,
            r.RegistradoPorNombreUsuario,
            r.RegistradoEn,
            r.ActualizadoEn,
            CAST(ROUND(CASE WHEN r.HorasTotalesJornada > 0 THEN (r.HorasOperacion / r.HorasTotalesJornada) * 100.0 ELSE 0.0 END, 2) AS DECIMAL(5,2)) AS DisponibilidadPct
        FROM dbo.ReporteOperacionDiaria r
        LEFT JOIN dbo.Activo a ON a.CodigoActivo = r.CodigoActivo
        LEFT JOIN dbo.Area ar ON ar.AreaId = r.AreaId
        WHERE r.CodigoActivo = @CodigoActivo AND r.FechaOperacion = @FechaOperacion;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 2. PROCEDIMIENTO: METRICAS DE OPERACION (MTBF, MTTR, DISPONIBILIDAD)
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
        COUNT(1)                                    AS DiasConReporte,
        @CodigoActivo                               AS CodigoActivo,
        @Inicio                                     AS FechaDesde,
        @Fin                                        AS FechaHasta,
        COUNT(DISTINCT r.CodigoActivo)              AS TotalEquiposMonitoreados,
        COALESCE(SUM(r.HorasTotalesJornada), 0.00)  AS TotalHorasJornada,
        COALESCE(SUM(r.HorasOperacion), 0.00)       AS TotalHorasOperacion,
        COALESCE(SUM(r.HorasParoFalla), 0.00)       AS TotalParoFalla,
        COALESCE(SUM(r.HorasParoMantPrev), 0.00)    AS TotalParoMantPrev,
        COALESCE(SUM(r.HorasParoMantCorr), 0.00)    AS TotalParoMantCorr,
        COALESCE(SUM(r.HorasParoPlanificado), 0.00) AS TotalParoPlanificado,
        COALESCE(SUM(r.HorasParoExterno), 0.00)     AS TotalParoExterno,
        -- Aliases de compatibilidad adicional
        COALESCE(SUM(r.HorasParoMantPrev), 0.00)    AS TotalHorasParoPreventivo,
        COALESCE(SUM(r.HorasParoMantCorr), 0.00)    AS TotalHorasParoCorrectivo,
        CASE WHEN SUM(r.HorasTotalesJornada) > 0
             THEN ROUND((SUM(r.HorasOperacion) / SUM(r.HorasTotalesJornada)) * 100.0, 2)
             ELSE 0.00 END AS DisponibilidadPct,
        CASE WHEN SUM(r.HorasTotalesJornada) > 0
             THEN ROUND((SUM(r.HorasOperacion) / SUM(r.HorasTotalesJornada)) * 100.0, 2)
             ELSE 0.00 END AS PorcentajeDisponibilidadGlobal,
        -- MTBF: Horas de operación / eventos de falla
        CASE WHEN SUM(CASE WHEN r.HorasParoFalla > 0 THEN 1 ELSE 0 END) > 0
             THEN ROUND(SUM(r.HorasOperacion) / NULLIF(SUM(CASE WHEN r.HorasParoFalla > 0 THEN 1 ELSE 0 END), 0), 2)
             ELSE NULL END AS MTBF_Horas,
        -- MTTR: Horas de paro por falla / eventos de falla
        CASE WHEN SUM(CASE WHEN r.HorasParoFalla > 0 THEN 1 ELSE 0 END) > 0
             THEN ROUND(SUM(r.HorasParoFalla) / NULLIF(SUM(CASE WHEN r.HorasParoFalla > 0 THEN 1 ELSE 0 END), 0), 2)
             ELSE NULL END AS MTTR_Horas
      FROM dbo.ReporteOperacionDiaria r
     WHERE (@CodigoActivo IS NULL OR r.CodigoActivo = @CodigoActivo)
       AND (@AreaId IS NULL OR r.AreaId = @AreaId)
       AND r.FechaOperacion BETWEEN @Inicio AND @Fin;
END;
GO

-- 3. PROCEDIMIENTO: REPORTE POR SEMANA CON DISPONIBILIDAD
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

    SELECT r.ReporteId,
           r.CodigoActivo,
           COALESCE(a.Nombre, r.CodigoActivo) AS NombreActivo,
           r.AreaId,
           COALESCE(ar.Nombre, r.AreaId) AS NombreArea,
           r.FechaOperacion,
           r.HorasTotalesJornada,
           r.HorasOperacion,
           r.HorasParoFalla,
           r.HorasParoMantPrev,
           r.HorasParoMantCorr,
           r.HorasParoPlanificado,
           r.HorasParoExterno,
           r.Observaciones,
           CONCAT(DATEPART(YEAR, r.FechaOperacion), '-W', RIGHT('0' + CAST(DATEPART(ISO_WEEK, r.FechaOperacion) AS VARCHAR(2)), 2)) AS SemanaISO,
           r.RegistradoPorUsuarioId,
           r.RegistradoPorNombreUsuario,
           r.RegistradoEn,
           r.ActualizadoEn,
           CAST(ROUND(CASE WHEN r.HorasTotalesJornada > 0 THEN (r.HorasOperacion / r.HorasTotalesJornada) * 100.0 ELSE 0.0 END, 2) AS DECIMAL(5,2)) AS DisponibilidadPct
      FROM dbo.ReporteOperacionDiaria r
      LEFT JOIN dbo.Activo a ON r.CodigoActivo = a.CodigoActivo
      LEFT JOIN dbo.Area ar ON r.AreaId = ar.AreaId
     WHERE (@AreaId IS NULL OR r.AreaId = @AreaId)
       AND r.FechaOperacion BETWEEN @Lunes AND @Domingo
     ORDER BY r.FechaOperacion DESC, r.CodigoActivo ASC;
END;
GO

-- 4. PROCEDIMIENTO: LISTAR EQUIPOS DE PROCESO POR AREA
CREATE OR ALTER PROCEDURE dbo.uspEquipoProcesoListarPorArea
    @AreaId NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT a.CodigoActivo,
           a.Nombre,
           a.Marca,
           a.Modelo,
           a.AreaId,
           ar.Nombre AS NombreArea,
           a.EsEquipoProceso
      FROM dbo.Activo a
      LEFT JOIN dbo.Area ar ON ar.AreaId = a.AreaId
     WHERE (@AreaId IS NULL OR a.AreaId = @AreaId)
       AND a.Nivel = 'equipment'
       AND a.Estado <> 'deleted'
       AND a.EsEquipoProceso = 1
     ORDER BY a.CodigoActivo ASC;
END;
GO
