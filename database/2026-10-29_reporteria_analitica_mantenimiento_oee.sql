/* ============================================================================
   MACSA CMMS - Grupo Macsa
   database/2026-10-29_reporteria_analitica_mantenimiento_oee.sql
   
   Módulo: Reportería y Analítica de Mantenimiento + Indicador OEE
   Fecha: 2026-10-29
   
   DESCRIPCIÓN:
   1. Extiende dbo.ReporteOperacionDiaria con soporte para métricas OEE:
      - UnidadesProducidas, UnidadesEsperadas, UnidadesConformes
      - RendimientoDirectoPct, CalidadDirectoPct
   2. Actualiza SPs de operación para registrar y calcular Disponibilidad,
      Rendimiento, Calidad y OEE (Overall Equipment Effectiveness).
   3. Procedimiento uspReporteHistorialActivo:
      - Hoja de vida completa por equipo / subárbol jerárquico.
      - KPIs (MTBF en días, MTTR en horas, horas taller).
      - Timeline cronológico de intervenciones (Averías + OTs).
      - Consumo y frecuencia en días de reemplazo de piezas/repuestos.
   4. Procedimiento uspReporteEstacionalidadAverias:
      - Distribución mensual de fallos y paros para análisis de estacionalidad anual.
   5. Procedimiento uspReporteTopEquiposFallas:
      - Ranking Pareto (Top equipos y componentes con mayor recurrencia de averías).
   6. Procedimiento uspReporteConsumoRepuestos:
      - Reporte de repuestos de mayor rotación y su intervalo de recambio.
   7. Procedimiento uspReporteOEEGeneral:
      - Consolidado OEE por equipo de proceso y por área.
   8. Concede permisos EXECUTE a macsa_app.
   ============================================================================ */

USE [MacsaCMMS];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'=== Iniciando migración: Reportería, Analítica y OEE ===';
GO

-- ============================================================================
-- 1. Agregar columnas OEE a dbo.ReporteOperacionDiaria
-- ============================================================================
IF COL_LENGTH('dbo.ReporteOperacionDiaria', 'UnidadesProducidas') IS NULL
BEGIN
    ALTER TABLE dbo.ReporteOperacionDiaria
        ADD UnidadesProducidas DECIMAL(12,2) NULL;
    PRINT N'  [OK] Columna UnidadesProducidas agregada.';
END
ELSE
    PRINT N'  [SKIP] Columna UnidadesProducidas ya existe.';
GO

IF COL_LENGTH('dbo.ReporteOperacionDiaria', 'UnidadesEsperadas') IS NULL
BEGIN
    ALTER TABLE dbo.ReporteOperacionDiaria
        ADD UnidadesEsperadas DECIMAL(12,2) NULL;
    PRINT N'  [OK] Columna UnidadesEsperadas agregada.';
END
ELSE
    PRINT N'  [SKIP] Columna UnidadesEsperadas ya existe.';
GO

IF COL_LENGTH('dbo.ReporteOperacionDiaria', 'UnidadesConformes') IS NULL
BEGIN
    ALTER TABLE dbo.ReporteOperacionDiaria
        ADD UnidadesConformes DECIMAL(12,2) NULL;
    PRINT N'  [OK] Columna UnidadesConformes agregada.';
END
ELSE
    PRINT N'  [SKIP] Columna UnidadesConformes ya existe.';
GO

IF COL_LENGTH('dbo.ReporteOperacionDiaria', 'RendimientoDirectoPct') IS NULL
BEGIN
    ALTER TABLE dbo.ReporteOperacionDiaria
        ADD RendimientoDirectoPct DECIMAL(5,2) NULL;
    PRINT N'  [OK] Columna RendimientoDirectoPct agregada.';
END
ELSE
    PRINT N'  [SKIP] Columna RendimientoDirectoPct ya existe.';
GO

IF COL_LENGTH('dbo.ReporteOperacionDiaria', 'CalidadDirectoPct') IS NULL
BEGIN
    ALTER TABLE dbo.ReporteOperacionDiaria
        ADD CalidadDirectoPct DECIMAL(5,2) NULL;
    PRINT N'  [OK] Columna CalidadDirectoPct agregada.';
END
ELSE
    PRINT N'  [SKIP] Columna CalidadDirectoPct ya existe.';
GO

-- ============================================================================
-- 2. SP: uspReporteOperacionRegistrar (con soporte OEE)
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionRegistrar
    @CodigoActivo              NVARCHAR(60),
    @FechaOperacion            DATE,
    @HorasTotalesJornada       DECIMAL(5,2)   = 24.00,
    @HorasOperacion            DECIMAL(5,2),
    @HorasParoFalla            DECIMAL(5,2)   = 0.00,
    @HorasParoMantPrev         DECIMAL(5,2)   = 0.00,
    @HorasParoMantCorr         DECIMAL(5,2)   = 0.00,
    @HorasParoPlanificado      DECIMAL(5,2)   = 0.00,
    @HorasParoExterno          DECIMAL(5,2)   = 0.00,
    @Observaciones             NVARCHAR(1000) = NULL,
    @UsuarioId                 INT            = NULL,
    @NombreUsuario             NVARCHAR(200)  = N'',
    @UnidadesProducidas        DECIMAL(12,2)  = NULL,
    @UnidadesEsperadas         DECIMAL(12,2)  = NULL,
    @UnidadesConformes         DECIMAL(12,2)  = NULL,
    @RendimientoDirectoPct     DECIMAL(5,2)   = NULL,
    @CalidadDirectoPct         DECIMAL(5,2)   = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @AreaId NVARCHAR(15), @Nivel NVARCHAR(20), @Estado NVARCHAR(25), @EsProc BIT;
        SELECT @AreaId = AreaId, @Nivel = Nivel, @Estado = Estado, @EsProc = EsEquipoProceso
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @CodigoActivo;

        IF @Nivel IS NULL  THROW 50404, N'Activo no encontrado.', 1;
        IF @Nivel <> 'equipment'
            THROW 50400, N'Solo activos de primer nivel (equipo) pueden recibir reportes de operación.', 1;
        IF ISNULL(@EsProc, 0) = 0
            THROW 50400, N'El activo no está marcado como equipo de proceso.', 1;
        IF @Estado IN ('deleted','transferredDeactivated')
            THROW 50400, N'El activo está eliminado o transferido.', 1;
        IF @FechaOperacion > CAST(SYSUTCDATETIME() AS DATE)
            THROW 50400, N'No se puede registrar un reporte con fecha futura.', 1;

        DECLARE @Suma DECIMAL(5,2) = @HorasOperacion + @HorasParoFalla + @HorasParoMantPrev
                                   + @HorasParoMantCorr + @HorasParoPlanificado + @HorasParoExterno;
        IF @Suma > @HorasTotalesJornada
            THROW 50400, N'La suma de horas de operación y paros supera las horas totales de jornada.', 1;

        MERGE dbo.ReporteOperacionDiaria WITH (HOLDLOCK) AS dst
        USING (SELECT @CodigoActivo AS ca, @FechaOperacion AS fo) AS src
           ON dst.CodigoActivo = src.ca AND dst.FechaOperacion = src.fo
        WHEN MATCHED THEN UPDATE SET
            HorasTotalesJornada        = @HorasTotalesJornada,
            HorasOperacion             = @HorasOperacion,
            HorasParoFalla             = @HorasParoFalla,
            HorasParoMantPrev          = @HorasParoMantPrev,
            HorasParoMantCorr          = @HorasParoMantCorr,
            HorasParoPlanificado       = @HorasParoPlanificado,
            HorasParoExterno           = @HorasParoExterno,
            Observaciones              = @Observaciones,
            RegistradoPorUsuarioId     = @UsuarioId,
            RegistradoPorNombreUsuario = @NombreUsuario,
            RegistradoEn               = SYSUTCDATETIME(),
            UnidadesProducidas         = @UnidadesProducidas,
            UnidadesEsperadas          = @UnidadesEsperadas,
            UnidadesConformes          = @UnidadesConformes,
            RendimientoDirectoPct      = @RendimientoDirectoPct,
            CalidadDirectoPct          = @CalidadDirectoPct
        WHEN NOT MATCHED THEN INSERT (
            CodigoActivo, AreaId, FechaOperacion,
            HorasTotalesJornada, HorasOperacion,
            HorasParoFalla, HorasParoMantPrev, HorasParoMantCorr,
            HorasParoPlanificado, HorasParoExterno,
            Observaciones, RegistradoPorUsuarioId, RegistradoPorNombreUsuario,
            UnidadesProducidas, UnidadesEsperadas, UnidadesConformes,
            RendimientoDirectoPct, CalidadDirectoPct
        ) VALUES (
            @CodigoActivo, @AreaId, @FechaOperacion,
            @HorasTotalesJornada, @HorasOperacion,
            @HorasParoFalla, @HorasParoMantPrev, @HorasParoMantCorr,
            @HorasParoPlanificado, @HorasParoExterno,
            @Observaciones, @UsuarioId, @NombreUsuario,
            @UnidadesProducidas, @UnidadesEsperadas, @UnidadesConformes,
            @RendimientoDirectoPct, @CalidadDirectoPct
        );

        DECLARE @DispPct DECIMAL(5,2) =
            CAST(@HorasOperacion * 100.0 / NULLIF(@HorasTotalesJornada, 0) AS DECIMAL(5,2));

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (
            @UsuarioId, @NombreUsuario,
            N'OPERATION_REPORT_SAVED', N'OPERATION_REPORTS', @CodigoActivo,
            CONCAT(
                N'Reporte ', CONVERT(NVARCHAR,@FechaOperacion,23),
                N' | Op: ',  CAST(@HorasOperacion AS NVARCHAR), N'h',
                N' | Falla: ', CAST(@HorasParoFalla AS NVARCHAR), N'h',
                N' | Disp: ', CAST(@DispPct AS NVARCHAR), N'%'
            )
        );

        COMMIT TRANSACTION;

        SELECT TOP 1
            r.ReporteId, r.CodigoActivo, r.AreaId, r.FechaOperacion,
            r.HorasTotalesJornada, r.HorasOperacion,
            r.HorasParoFalla, r.HorasParoMantPrev, r.HorasParoMantCorr,
            r.HorasParoPlanificado, r.HorasParoExterno,
            r.Observaciones, r.SemanaISO,
            r.RegistradoPorUsuarioId, r.RegistradoPorNombreUsuario, r.RegistradoEn,
            r.UnidadesProducidas, r.UnidadesEsperadas, r.UnidadesConformes,
            r.RendimientoDirectoPct, r.CalidadDirectoPct,
            CAST(CAST((r.HorasOperacion / NULLIF(r.HorasTotalesJornada,0))*100 AS DECIMAL(5,2)) AS FLOAT) AS DisponibilidadPct,
            CAST(COALESCE(
                r.RendimientoDirectoPct,
                CASE WHEN ISNULL(r.UnidadesEsperadas, 0) > 0
                     THEN CAST((r.UnidadesProducidas * 100.0 / r.UnidadesEsperadas) AS DECIMAL(5,2))
                     ELSE NULL END
            ) AS FLOAT) AS RendimientoPct,
            CAST(COALESCE(
                r.CalidadDirectoPct,
                CASE WHEN ISNULL(r.UnidadesProducidas, 0) > 0
                     THEN CAST((r.UnidadesConformes * 100.0 / r.UnidadesProducidas) AS DECIMAL(5,2))
                     ELSE NULL END
            ) AS FLOAT) AS CalidadPct,
            CAST(CASE 
                WHEN (r.HorasTotalesJornada > 0)
                     AND (r.RendimientoDirectoPct IS NOT NULL OR (r.UnidadesEsperadas > 0 AND r.UnidadesProducidas IS NOT NULL))
                     AND (r.CalidadDirectoPct IS NOT NULL OR (r.UnidadesProducidas > 0 AND r.UnidadesConformes IS NOT NULL))
                THEN CAST(
                    ((r.HorasOperacion * 100.0 / r.HorasTotalesJornada)
                    * COALESCE(r.RendimientoDirectoPct, (r.UnidadesProducidas * 100.0 / NULLIF(r.UnidadesEsperadas,0)))
                    * COALESCE(r.CalidadDirectoPct, (r.UnidadesConformes * 100.0 / NULLIF(r.UnidadesProducidas,0)))
                    ) / 10000.0 AS DECIMAL(5,2))
                ELSE NULL
            END AS FLOAT) AS OeePct
          FROM dbo.ReporteOperacionDiaria r
         WHERE r.CodigoActivo = @CodigoActivo AND r.FechaOperacion = @FechaOperacion;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; THROW;
    END CATCH
END;
GO
PRINT N'  [OK] SP uspReporteOperacionRegistrar actualizado con soporte OEE.';
GO

-- ============================================================================
-- 3. SP: uspReporteOperacionObtenerPorActivo (con OEE)
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionObtenerPorActivo
    @CodigoActivo       NVARCHAR(60),
    @FechaDesde         DATE = NULL,
    @FechaHasta         DATE = NULL,
    @Pagina             INT  = 1,
    @RegistrosPorPagina INT  = 30
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Offset INT = (@Pagina - 1) * @RegistrosPorPagina;

    SELECT
        r.ReporteId, r.CodigoActivo, a.Nombre AS NombreActivo,
        r.AreaId, ar.Nombre AS NombreArea,
        r.FechaOperacion, r.HorasTotalesJornada, r.HorasOperacion,
        r.HorasParoFalla, r.HorasParoMantPrev, r.HorasParoMantCorr,
        r.HorasParoPlanificado, r.HorasParoExterno,
        r.Observaciones, r.SemanaISO,
        r.RegistradoPorUsuarioId, r.RegistradoPorNombreUsuario, r.RegistradoEn,
        r.UnidadesProducidas, r.UnidadesEsperadas, r.UnidadesConformes,
        r.RendimientoDirectoPct, r.CalidadDirectoPct,
        CAST(CAST((r.HorasOperacion / NULLIF(r.HorasTotalesJornada,0))*100 AS DECIMAL(5,2)) AS FLOAT) AS DisponibilidadPct,
        CAST(COALESCE(
            r.RendimientoDirectoPct,
            CASE WHEN ISNULL(r.UnidadesEsperadas, 0) > 0
                 THEN CAST((r.UnidadesProducidas * 100.0 / r.UnidadesEsperadas) AS DECIMAL(5,2))
                 ELSE NULL END
        ) AS FLOAT) AS RendimientoPct,
        CAST(COALESCE(
            r.CalidadDirectoPct,
            CASE WHEN ISNULL(r.UnidadesProducidas, 0) > 0
                 THEN CAST((r.UnidadesConformes * 100.0 / r.UnidadesProducidas) AS DECIMAL(5,2))
                 ELSE NULL END
        ) AS FLOAT) AS CalidadPct,
        CAST(CASE 
            WHEN (r.HorasTotalesJornada > 0)
                 AND (r.RendimientoDirectoPct IS NOT NULL OR (r.UnidadesEsperadas > 0 AND r.UnidadesProducidas IS NOT NULL))
                 AND (r.CalidadDirectoPct IS NOT NULL OR (r.UnidadesProducidas > 0 AND r.UnidadesConformes IS NOT NULL))
            THEN CAST(
                ((r.HorasOperacion * 100.0 / r.HorasTotalesJornada)
                * COALESCE(r.RendimientoDirectoPct, (r.UnidadesProducidas * 100.0 / NULLIF(r.UnidadesEsperadas,0)))
                * COALESCE(r.CalidadDirectoPct, (r.UnidadesConformes * 100.0 / NULLIF(r.UnidadesProducidas,0)))
                ) / 10000.0 AS DECIMAL(5,2))
            ELSE NULL
        END AS FLOAT) AS OeePct
    FROM dbo.ReporteOperacionDiaria r
    INNER JOIN dbo.Activo a  ON a.CodigoActivo = r.CodigoActivo
    INNER JOIN dbo.Area   ar ON ar.AreaId      = r.AreaId
    WHERE r.CodigoActivo = @CodigoActivo
      AND (@FechaDesde IS NULL OR r.FechaOperacion >= @FechaDesde)
      AND (@FechaHasta IS NULL OR r.FechaOperacion <= @FechaHasta)
    ORDER BY r.FechaOperacion DESC
    OFFSET @Offset ROWS FETCH NEXT @RegistrosPorPagina ROWS ONLY;
END;
GO
PRINT N'  [OK] SP uspReporteOperacionObtenerPorActivo actualizado.';
GO

-- ============================================================================
-- 4. SP: uspReporteOperacionMetricas (con OEE consolidado)
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionMetricas
    @CodigoActivo NVARCHAR(60),
    @FechaDesde   DATE,
    @FechaHasta   DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        @CodigoActivo                         AS CodigoActivo,
        @FechaDesde                           AS FechaDesde,
        @FechaHasta                           AS FechaHasta,
        COUNT(*)                              AS DiasConReporte,
        SUM(r.HorasTotalesJornada)            AS TotalHorasJornada,
        SUM(r.HorasOperacion)                 AS TotalHorasOperacion,
        SUM(r.HorasParoFalla)                 AS TotalParoFalla,
        SUM(r.HorasParoMantPrev)              AS TotalParoMantPrev,
        SUM(r.HorasParoMantCorr)              AS TotalParoMantCorr,
        SUM(r.HorasParoPlanificado)           AS TotalParoPlanificado,
        SUM(r.HorasParoExterno)               AS TotalParoExterno,
        SUM(ISNULL(r.UnidadesProducidas,0))   AS TotalUnidadesProducidas,
        SUM(ISNULL(r.UnidadesEsperadas,0))    AS TotalUnidadesEsperadas,
        SUM(ISNULL(r.UnidadesConformes,0))    AS TotalUnidadesConformes,
        -- Disponibilidad %
        CAST(CAST(
            SUM(r.HorasOperacion) * 100.0
            / NULLIF(SUM(r.HorasTotalesJornada), 0)
        AS DECIMAL(5,2)) AS FLOAT)            AS DisponibilidadPct,
        -- Rendimiento % promedio
        CAST(CAST(
            CASE 
                WHEN SUM(ISNULL(r.UnidadesEsperadas,0)) > 0
                THEN SUM(r.UnidadesProducidas) * 100.0 / NULLIF(SUM(r.UnidadesEsperadas),0)
                ELSE AVG(r.RendimientoDirectoPct)
            END
        AS DECIMAL(5,2)) AS FLOAT)            AS RendimientoPct,
        -- Calidad % promedio
        CAST(CAST(
            CASE 
                WHEN SUM(ISNULL(r.UnidadesProducidas,0)) > 0
                THEN SUM(r.UnidadesConformes) * 100.0 / NULLIF(SUM(r.UnidadesProducidas),0)
                ELSE AVG(r.CalidadDirectoPct)
            END
        AS DECIMAL(5,2)) AS FLOAT)            AS CalidadPct,
        -- OEE % consolidado
        CAST(CAST(
            (
                (SUM(r.HorasOperacion) * 100.0 / NULLIF(SUM(r.HorasTotalesJornada), 0))
                * COALESCE(
                    CASE WHEN SUM(ISNULL(r.UnidadesEsperadas,0)) > 0
                         THEN SUM(r.UnidadesProducidas) * 100.0 / NULLIF(SUM(r.UnidadesEsperadas),0)
                         ELSE AVG(r.RendimientoDirectoPct) END,
                    100.0
                  )
                * COALESCE(
                    CASE WHEN SUM(ISNULL(r.UnidadesProducidas,0)) > 0
                         THEN SUM(r.UnidadesConformes) * 100.0 / NULLIF(SUM(r.UnidadesProducidas),0)
                         ELSE AVG(r.CalidadDirectoPct) END,
                    100.0
                  )
            ) / 10000.0
        AS DECIMAL(5,2)) AS FLOAT)            AS OeePct,
        CAST(CASE WHEN SUM(CASE WHEN r.HorasParoFalla > 0 THEN 1 ELSE 0 END) = 0 THEN NULL
             ELSE SUM(r.HorasOperacion) * 1.0
                  / NULLIF(SUM(CASE WHEN r.HorasParoFalla > 0 THEN 1 ELSE 0 END), 0)
             END AS FLOAT)                    AS MTBF_Horas,
        CAST(CASE WHEN SUM(CASE WHEN r.HorasParoFalla > 0 THEN 1 ELSE 0 END) = 0 THEN NULL
             ELSE SUM(r.HorasParoFalla) * 1.0
                  / NULLIF(SUM(CASE WHEN r.HorasParoFalla > 0 THEN 1 ELSE 0 END), 0)
             END AS FLOAT)                    AS MTTR_Horas
    FROM dbo.ReporteOperacionDiaria r
    WHERE r.CodigoActivo   = @CodigoActivo
      AND r.FechaOperacion >= @FechaDesde
      AND r.FechaOperacion <= @FechaHasta;
END;
GO
PRINT N'  [OK] SP uspReporteOperacionMetricas actualizado.';
GO

-- ============================================================================
-- 5. SP: uspReporteHistorialActivo
--    Hoja de Vida Completa del Activo y su subárbol:
--    ResultSet 1: KPIs y Métricas del Equipo (Averías, OTs, MTBF, MTTR, Disponibilidad)
--    ResultSet 2: Timeline cronológico de intervenciones (Averías y OTs)
--    ResultSet 3: Historial de repuestos y frecuencia promedio de cambio
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspReporteHistorialActivo
    @CodigoActivo NVARCHAR(60),
    @FechaDesde   DATE = NULL,
    @FechaHasta   DATE = NULL,
    @IncluirHijos BIT  = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Identificar universo de activos (el activo seleccionado + sus componentes)
    DECLARE @Codigos TABLE (CodigoActivo NVARCHAR(60) PRIMARY KEY);

    IF @IncluirHijos = 1
    BEGIN
        INSERT INTO @Codigos (CodigoActivo)
        SELECT CodigoActivo
          FROM dbo.Activo
         WHERE CodigoActivo = @CodigoActivo
            OR RutaAncestros = @CodigoActivo
            OR RutaAncestros LIKE @CodigoActivo + N'/%';
    END
    ELSE
    BEGIN
        INSERT INTO @Codigos (CodigoActivo) VALUES (@CodigoActivo);
    END;

    -- Fechas por defecto si son nulas (último año)
    DECLARE @FInicio DATETIME2(3) = ISNULL(CAST(@FechaDesde AS DATETIME2(3)), DATEADD(year, -1, SYSUTCDATETIME()));
    DECLARE @FFin    DATETIME2(3) = ISNULL(DATEADD(day, 1, CAST(@FechaHasta AS DATETIME2(3))), SYSUTCDATETIME());

    -- RESULTSET 1: Resumen y KPIs del Equipo
    SELECT
        a.CodigoActivo,
        a.Nombre                   AS NombreActivo,
        a.Marca,
        a.Modelo,
        a.Serie,
        a.Nivel,
        a.AreaId,
        ar.Nombre                  AS NombreArea,
        a.Estado                   AS EstadoActivo,
        a.EsEquipoProceso,
        -- Conteo de averías
        COUNT(DISTINCT r.ReporteId) AS TotalAverias,
        SUM(CASE WHEN r.Severidad = 'critical' THEN 1 ELSE 0 END) AS TotalAveriasCriticas,
        SUM(CASE WHEN r.Estado = 'resolved' THEN 1 ELSE 0 END)    AS TotalAveriasResueltas,
        -- Conteo de OTs
        COUNT(DISTINCT ot.OrdenTrabajoId) AS TotalOrdenesTrabajo,
        SUM(CASE WHEN ot.PlanPreventivoId IS NOT NULL THEN 1 ELSE 0 END) AS TotalOTsPreventivas,
        SUM(CASE WHEN ot.ReporteId IS NOT NULL THEN 1 ELSE 0 END)        AS TotalOTsCorrectivas,
        SUM(CASE WHEN ot.EstaCompletada = 1 THEN 1 ELSE 0 END)           AS TotalOTsCompletadas,
        -- Horas invertidas
        ISNULL(SUM(ot.HorasReales), 0.0) AS HorasTotalesTaller,
        -- MTTR: Tiempo promedio de reparación (horas reales de trabajo de OTs correctivas completadas)
        CAST(AVG(CASE WHEN ot.ReporteId IS NOT NULL AND ot.EstaCompletada = 1 AND ot.HorasReales > 0
                      THEN ot.HorasReales ELSE NULL END) AS FLOAT) AS MTTR_HorasPromedio,
        -- MTBF en días: Días del periodo dividido entre el número de averías
        CAST(CASE 
            WHEN COUNT(DISTINCT r.ReporteId) > 0 
            THEN DATEDIFF(day, @FInicio, @FFin) * 1.0 / COUNT(DISTINCT r.ReporteId)
            ELSE NULL 
        END AS FLOAT) AS MTBF_DiasEstimado,
        -- Disponibilidad promedio (si aplica reporte diario de operación)
        CAST((
            SELECT AVG(CAST((rod.HorasOperacion * 100.0 / NULLIF(rod.HorasTotalesJornada,0)) AS DECIMAL(5,2)))
              FROM dbo.ReporteOperacionDiaria rod
             WHERE rod.CodigoActivo = @CodigoActivo
               AND rod.FechaOperacion >= CAST(@FInicio AS DATE)
               AND rod.FechaOperacion <= CAST(@FFin AS DATE)
        ) AS FLOAT) AS DisponibilidadPromedioPct,
        -- OEE promedio
        CAST((
            SELECT AVG(CAST(
                ((rod.HorasOperacion * 100.0 / NULLIF(rod.HorasTotalesJornada,0))
                * ISNULL(rod.RendimientoDirectoPct, 100.0)
                * ISNULL(rod.CalidadDirectoPct, 100.0)) / 10000.0 AS DECIMAL(5,2)))
              FROM dbo.ReporteOperacionDiaria rod
             WHERE rod.CodigoActivo = @CodigoActivo
               AND rod.FechaOperacion >= CAST(@FInicio AS DATE)
               AND rod.FechaOperacion <= CAST(@FFin AS DATE)
               AND rod.RendimientoDirectoPct IS NOT NULL
        ) AS FLOAT) AS OeePromedioPct
    FROM dbo.Activo a
    INNER JOIN dbo.Area ar ON ar.AreaId = a.AreaId
    LEFT JOIN dbo.ReporteAveria r 
           ON r.CodigoActivo IN (SELECT CodigoActivo FROM @Codigos)
          AND r.ReportadoEn >= @FInicio AND r.ReportadoEn < @FFin
    LEFT JOIN dbo.OrdenTrabajo ot
           ON ot.CodigoActivo IN (SELECT CodigoActivo FROM @Codigos)
          AND ot.CreadoEn >= @FInicio AND ot.CreadoEn < @FFin
    WHERE a.CodigoActivo = @CodigoActivo
    GROUP BY a.CodigoActivo, a.Nombre, a.Marca, a.Modelo, a.Serie, a.Nivel, a.AreaId, ar.Nombre, a.Estado, a.EsEquipoProceso;

    -- RESULTSET 2: Timeline de Intervenciones (Averías y Órdenes de Trabajo)
    SELECT
        Intervenciones.TipoIntervencion,
        Intervenciones.Id,
        Intervenciones.CodigoActivo,
        act.Nombre AS NombreActivo,
        act.Nivel  AS NivelActivo,
        Intervenciones.Fecha,
        Intervenciones.Titulo,
        Intervenciones.Descripcion,
        Intervenciones.Estado,
        Intervenciones.SeveridadOPrioridad,
        Intervenciones.HorasReales,
        Intervenciones.AsignadoA,
        Intervenciones.Responsable,
        Intervenciones.OrdenTrabajoVinculadaId
    FROM (
        -- Averías
        SELECT
            N'AVERIA'                      AS TipoIntervencion,
            CAST(r.ReporteId AS NVARCHAR)  AS Id,
            r.CodigoActivo,
            r.ReportadoEn                  AS Fecha,
            N'Reporte de Avería'           AS Titulo,
            r.Descripcion,
            r.Estado,
            r.Severidad                    AS SeveridadOPrioridad,
            CAST(NULL AS DECIMAL(6,2))     AS HorasReales,
            r.ReportadoPorNombreUsuario    AS AsignadoA,
            r.ResueltoPorNombreUsuario     AS Responsable,
            r.OrdenTrabajoId               AS OrdenTrabajoVinculadaId
        FROM dbo.ReporteAveria r
        WHERE r.CodigoActivo IN (SELECT CodigoActivo FROM @Codigos)
          AND r.ReportadoEn >= @FInicio AND r.ReportadoEn < @FFin

        UNION ALL

        -- Órdenes de Trabajo
        SELECT
            CASE 
                WHEN ot.PlanPreventivoId IS NOT NULL THEN N'OT_PREVENTIVA'
                WHEN ot.ReporteId IS NOT NULL        THEN N'OT_CORRECTIVA'
                ELSE N'OT_GENERAL'
            END                            AS TipoIntervencion,
            ot.OrdenTrabajoId              AS Id,
            ot.CodigoActivo,
            ot.CreadoEn                    AS Fecha,
            ot.Descripcion                 AS Titulo,
            ISNULL(ot.DescripcionTrabajoRealizado, ot.Descripcion) AS Descripcion,
            ot.Estado,
            ot.Prioridad                   AS SeveridadOPrioridad,
            ot.HorasReales,
            ot.AsignadoA,
            ISNULL(ot.ResponsableMantenimiento, ot.CreadoPorNombreUsuario) AS Responsable,
            ot.OrdenTrabajoId              AS OrdenTrabajoVinculadaId
        FROM dbo.OrdenTrabajo ot
        WHERE ot.CodigoActivo IN (SELECT CodigoActivo FROM @Codigos)
          AND ot.CreadoEn >= @FInicio AND ot.CreadoEn < @FFin
    ) Intervenciones
    INNER JOIN dbo.Activo act ON act.CodigoActivo = Intervenciones.CodigoActivo
    ORDER BY Intervenciones.Fecha DESC;

    -- RESULTSET 3: Historial y Frecuencia de Reemplazo de Piezas y Repuestos
    WITH MaterialesConsumidos AS (
        SELECT
            mot.Descripcion                 AS Repuesto,
            mot.Cantidad,
            mot.Unidad,
            ot.CodigoActivo,
            act.Nombre                      AS NombreActivo,
            ot.CreadoEn                     AS FechaCambio,
            ot.OrdenTrabajoId,
            ROW_NUMBER() OVER(PARTITION BY mot.Descripcion ORDER BY ot.CreadoEn ASC) AS NumReemplazo
        FROM dbo.MaterialOrdenTrabajo mot
        INNER JOIN dbo.OrdenTrabajo ot ON ot.OrdenTrabajoId = mot.OrdenTrabajoId
        INNER JOIN dbo.Activo act      ON act.CodigoActivo  = ot.CodigoActivo
        WHERE ot.CodigoActivo IN (SELECT CodigoActivo FROM @Codigos)
          AND ot.CreadoEn >= @FInicio AND ot.CreadoEn < @FFin
          AND ot.EstaCompletada = 1
    )
    SELECT
        mc.Repuesto,
        ISNULL(mc.Unidad, N'UND') AS Unidad,
        SUM(mc.Cantidad)          AS CantidadTotalConsumida,
        COUNT(DISTINCT mc.OrdenTrabajoId) AS VecesReemplazado,
        MIN(mc.FechaCambio)       AS PrimerReemplazo,
        MAX(mc.FechaCambio)       AS UltimoReemplazo,
        -- Días promedio entre cada reemplazo
        CAST(CASE 
            WHEN COUNT(DISTINCT mc.OrdenTrabajoId) > 1 
            THEN DATEDIFF(day, MIN(mc.FechaCambio), MAX(mc.FechaCambio)) * 1.0 
                 / (COUNT(DISTINCT mc.OrdenTrabajoId) - 1)
            ELSE NULL 
        END AS FLOAT) AS DiasPromedioEntreReemplazos
    FROM MaterialesConsumidos mc
    GROUP BY mc.Repuesto, mc.Unidad
    ORDER BY VecesReemplazado DESC, CantidadTotalConsumida DESC;
END;
GO
PRINT N'  [OK] SP uspReporteHistorialActivo creado.';
GO

-- ============================================================================
-- 6. SP: uspReporteEstacionalidadAverias
--    Análisis mensual de fallos para detectar meses críticos
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspReporteEstacionalidadAverias
    @AreaId NVARCHAR(15) = NULL,
    @Anio   INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Anio IS NULL SET @Anio = YEAR(SYSUTCDATETIME());

    WITH Meses AS (
        SELECT 1 AS Mes, N'Enero' AS NombreMes UNION ALL
        SELECT 2, N'Febrero' UNION ALL
        SELECT 3, N'Marzo' UNION ALL
        SELECT 4, N'Abril' UNION ALL
        SELECT 5, N'Mayo' UNION ALL
        SELECT 6, N'Junio' UNION ALL
        SELECT 7, N'Julio' UNION ALL
        SELECT 8, N'Agosto' UNION ALL
        SELECT 9, N'Septiembre' UNION ALL
        SELECT 10, N'Octubre' UNION ALL
        SELECT 11, N'Noviembre' UNION ALL
        SELECT 12, N'Diciembre'
    )
    SELECT
        @Anio            AS Anio,
        m.Mes            AS MesNumero,
        m.NombreMes,
        -- Averías
        COUNT(DISTINCT r.ReporteId)                               AS TotalAverias,
        SUM(CASE WHEN r.Severidad = 'low'      THEN 1 ELSE 0 END) AS AveriasBajas,
        SUM(CASE WHEN r.Severidad = 'medium'   THEN 1 ELSE 0 END) AS AveriasMedias,
        SUM(CASE WHEN r.Severidad = 'high'     THEN 1 ELSE 0 END) AS AveriasAltas,
        SUM(CASE WHEN r.Severidad = 'critical' THEN 1 ELSE 0 END) AS AveriasCriticas,
        -- Órdenes de Trabajo en ese mes
        COUNT(DISTINCT ot.OrdenTrabajoId)                                   AS TotalOrdenesTrabajo,
        SUM(CASE WHEN ot.PlanPreventivoId IS NOT NULL THEN 1 ELSE 0 END)    AS OTsPreventivas,
        SUM(CASE WHEN ot.ReporteId IS NOT NULL THEN 1 ELSE 0 END)           AS OTsCorrectivas,
        ISNULL(SUM(ot.HorasReales), 0.0)                                    AS HorasTotalesTaller,
        -- Horas de paro por falla registradas en reporte de operación diaria
        ISNULL((
            SELECT SUM(rod.HorasParoFalla)
              FROM dbo.ReporteOperacionDiaria rod
             WHERE YEAR(rod.FechaOperacion)  = @Anio
               AND MONTH(rod.FechaOperacion) = m.Mes
               AND (@AreaId IS NULL OR rod.AreaId = @AreaId)
        ), 0.0) AS HorasParoFallaOperacion
    FROM Meses m
    LEFT JOIN dbo.ReporteAveria r
           ON YEAR(r.ReportadoEn)  = @Anio
          AND MONTH(r.ReportadoEn) = m.Mes
          AND (@AreaId IS NULL OR r.AreaId = @AreaId)
    LEFT JOIN dbo.OrdenTrabajo ot
           ON YEAR(ot.CreadoEn)  = @Anio
          AND MONTH(ot.CreadoEn) = m.Mes
          AND (@AreaId IS NULL OR ot.AreaId = @AreaId)
    GROUP BY m.Mes, m.NombreMes
    ORDER BY m.Mes;
END;
GO
PRINT N'  [OK] SP uspReporteEstacionalidadAverias creado.';
GO

-- ============================================================================
-- 7. SP: uspReporteTopEquiposFallas (Pareto de Fallas)
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspReporteTopEquiposFallas
    @AreaId     NVARCHAR(15) = NULL,
    @FechaDesde DATE         = NULL,
    @FechaHasta DATE         = NULL,
    @Top        INT          = 10
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FInicio DATETIME2(3) = ISNULL(CAST(@FechaDesde AS DATETIME2(3)), DATEADD(year, -1, SYSUTCDATETIME()));
    DECLARE @FFin    DATETIME2(3) = ISNULL(DATEADD(day, 1, CAST(@FechaHasta AS DATETIME2(3))), SYSUTCDATETIME());

    DECLARE @TotalAveriasGlobal FLOAT;
    SELECT @TotalAveriasGlobal = NULLIF(COUNT(*), 0)
      FROM dbo.ReporteAveria r
     WHERE r.ReportadoEn >= @FInicio AND r.ReportadoEn < @FFin
       AND (@AreaId IS NULL OR r.AreaId = @AreaId);

    SELECT TOP (@Top)
        a.CodigoActivo,
        a.Nombre                   AS NombreActivo,
        a.Nivel,
        a.AreaId,
        ar.Nombre                  AS NombreArea,
        COUNT(DISTINCT r.ReporteId) AS TotalAverias,
        SUM(CASE WHEN r.Severidad = 'critical' THEN 1 ELSE 0 END) AS AveriasCriticas,
        COUNT(DISTINCT ot.OrdenTrabajoId) AS OTsCorrectivas,
        ISNULL(SUM(ot.HorasReales), 0.0)  AS HorasTallerInvertidas,
        CAST(CAST((COUNT(DISTINCT r.ReporteId) * 100.0 / ISNULL(@TotalAveriasGlobal, 1)) AS DECIMAL(5,2)) AS FLOAT) AS PorcentajeDelTotalFallas
    FROM dbo.Activo a
    INNER JOIN dbo.Area ar ON ar.AreaId = a.AreaId
    LEFT JOIN dbo.ReporteAveria r
           ON r.CodigoActivo = a.CodigoActivo
          AND r.ReportadoEn >= @FInicio AND r.ReportadoEn < @FFin
    LEFT JOIN dbo.OrdenTrabajo ot
           ON ot.CodigoActivo = a.CodigoActivo
          AND ot.ReporteId IS NOT NULL
          AND ot.CreadoEn >= @FInicio AND ot.CreadoEn < @FFin
    WHERE (@AreaId IS NULL OR a.AreaId = @AreaId)
      AND a.Estado = 'active'
    GROUP BY a.CodigoActivo, a.Nombre, a.Nivel, a.AreaId, ar.Nombre
    HAVING COUNT(DISTINCT r.ReporteId) > 0 OR COUNT(DISTINCT ot.OrdenTrabajoId) > 0
    ORDER BY TotalAverias DESC, HorasTallerInvertidas DESC;
END;
GO
PRINT N'  [OK] SP uspReporteTopEquiposFallas creado.';
GO

-- ============================================================================
-- 8. SP: uspReporteConsumoRepuestos
--    Consumo agregado de materiales y piezas de recambio
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspReporteConsumoRepuestos
    @AreaId       NVARCHAR(15) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @FechaDesde   DATE         = NULL,
    @FechaHasta   DATE         = NULL,
    @Top          INT          = 20
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FInicio DATETIME2(3) = ISNULL(CAST(@FechaDesde AS DATETIME2(3)), DATEADD(year, -1, SYSUTCDATETIME()));
    DECLARE @FFin    DATETIME2(3) = ISNULL(DATEADD(day, 1, CAST(@FechaHasta AS DATETIME2(3))), SYSUTCDATETIME());

    SELECT TOP (@Top)
        mot.Descripcion                    AS Repuesto,
        ISNULL(mot.Unidad, N'UND')         AS Unidad,
        SUM(mot.Cantidad)                  AS CantidadTotalConsumida,
        COUNT(DISTINCT ot.OrdenTrabajoId)  AS TotalIntervenciones,
        COUNT(DISTINCT ot.CodigoActivo)    AS TotalActivosDistintos,
        MIN(ot.CreadoEn)                   AS PrimerUso,
        MAX(ot.CreadoEn)                   AS UltimoUso,
        CAST(CASE 
            WHEN COUNT(DISTINCT ot.OrdenTrabajoId) > 1 
            THEN DATEDIFF(day, MIN(ot.CreadoEn), MAX(ot.CreadoEn)) * 1.0 
                 / (COUNT(DISTINCT ot.OrdenTrabajoId) - 1)
            ELSE NULL 
        END AS FLOAT) AS DiasPromedioEntreReemplazos
    FROM dbo.MaterialOrdenTrabajo mot
    INNER JOIN dbo.OrdenTrabajo ot ON ot.OrdenTrabajoId = mot.OrdenTrabajoId
    WHERE ot.EstaCompletada = 1
      AND ot.CreadoEn >= @FInicio AND ot.CreadoEn < @FFin
      AND (@AreaId IS NULL OR ot.AreaId = @AreaId)
      AND (@CodigoActivo IS NULL OR ot.CodigoActivo = @CodigoActivo)
    GROUP BY mot.Descripcion, mot.Unidad
    ORDER BY CantidadTotalConsumida DESC, TotalIntervenciones DESC;
END;
GO
PRINT N'  [OK] SP uspReporteConsumoRepuestos creado.';
GO

-- ============================================================================
-- 9. SP: uspReporteOEEGeneral
--    Consolidado de Disponibilidad, Rendimiento, Calidad y OEE por equipo/área
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspReporteOEEGeneral
    @AreaId       NVARCHAR(15) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @FechaDesde   DATE         = NULL,
    @FechaHasta   DATE         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaDesde IS NULL SET @FechaDesde = CAST(DATEADD(month, -1, SYSUTCDATETIME()) AS DATE);
    IF @FechaHasta IS NULL SET @FechaHasta = CAST(SYSUTCDATETIME() AS DATE);

    SELECT
        a.CodigoActivo,
        a.Nombre                                AS NombreActivo,
        a.AreaId,
        ar.Nombre                               AS NombreArea,
        COUNT(rod.ReporteId)                    AS DiasConReporte,
        SUM(rod.HorasTotalesJornada)            AS TotalHorasJornada,
        SUM(rod.HorasOperacion)                 AS TotalHorasOperacion,
        SUM(rod.HorasParoFalla)                 AS TotalParoFalla,
        SUM(rod.HorasParoMantPrev + rod.HorasParoMantCorr) AS TotalParoMantenimiento,
        -- Disponibilidad %
        CAST(CAST(
            SUM(rod.HorasOperacion) * 100.0
            / NULLIF(SUM(rod.HorasTotalesJornada), 0)
        AS DECIMAL(5,2)) AS FLOAT)              AS DisponibilidadPct,
        -- Rendimiento %
        CAST(CAST(
            COALESCE(
                CASE WHEN SUM(ISNULL(rod.UnidadesEsperadas,0)) > 0
                     THEN SUM(rod.UnidadesProducidas) * 100.0 / NULLIF(SUM(rod.UnidadesEsperadas),0)
                     ELSE AVG(rod.RendimientoDirectoPct) END,
                100.0
            )
        AS DECIMAL(5,2)) AS FLOAT)              AS RendimientoPct,
        -- Calidad %
        CAST(CAST(
            COALESCE(
                CASE WHEN SUM(ISNULL(rod.UnidadesProducidas,0)) > 0
                     THEN SUM(rod.UnidadesConformes) * 100.0 / NULLIF(SUM(rod.UnidadesProducidas),0)
                     ELSE AVG(rod.CalidadDirectoPct) END,
                100.0
            )
        AS DECIMAL(5,2)) AS FLOAT)              AS CalidadPct,
        -- OEE %
        CAST(CAST(
            (
                (SUM(rod.HorasOperacion) * 100.0 / NULLIF(SUM(rod.HorasTotalesJornada), 0))
                * COALESCE(
                    CASE WHEN SUM(ISNULL(rod.UnidadesEsperadas,0)) > 0
                         THEN SUM(rod.UnidadesProducidas) * 100.0 / NULLIF(SUM(rod.UnidadesEsperadas),0)
                         ELSE AVG(rod.RendimientoDirectoPct) END,
                    100.0
                  )
                * COALESCE(
                    CASE WHEN SUM(ISNULL(rod.UnidadesProducidas,0)) > 0
                         THEN SUM(rod.UnidadesConformes) * 100.0 / NULLIF(SUM(rod.UnidadesProducidas),0)
                         ELSE AVG(rod.CalidadDirectoPct) END,
                    100.0
                  )
            ) / 10000.0
        AS DECIMAL(5,2)) AS FLOAT)              AS OeePct
    FROM dbo.Activo a
    INNER JOIN dbo.Area ar ON ar.AreaId = a.AreaId
    INNER JOIN dbo.ReporteOperacionDiaria rod ON rod.CodigoActivo = a.CodigoActivo
    WHERE a.Nivel = 'equipment'
      AND a.EsEquipoProceso = 1
      AND a.Estado = 'active'
      AND (@AreaId IS NULL OR a.AreaId = @AreaId)
      AND (@CodigoActivo IS NULL OR a.CodigoActivo = @CodigoActivo)
      AND rod.FechaOperacion >= @FechaDesde
      AND rod.FechaOperacion <= @FechaHasta
    GROUP BY a.CodigoActivo, a.Nombre, a.AreaId, ar.Nombre
    ORDER BY ar.Nombre, a.Nombre;
END;
GO
PRINT N'  [OK] SP uspReporteOEEGeneral creado.';
GO

-- ============================================================================
-- 10. Conceder permisos de ejecución al usuario de la API (macsa_app)
-- ============================================================================
GRANT EXECUTE ON dbo.uspReporteOperacionRegistrar        TO macsa_app;
GRANT EXECUTE ON dbo.uspReporteOperacionObtenerPorActivo TO macsa_app;
GRANT EXECUTE ON dbo.uspReporteOperacionMetricas         TO macsa_app;
GRANT EXECUTE ON dbo.uspReporteHistorialActivo           TO macsa_app;
GRANT EXECUTE ON dbo.uspReporteEstacionalidadAverias     TO macsa_app;
GRANT EXECUTE ON dbo.uspReporteTopEquiposFallas          TO macsa_app;
GRANT EXECUTE ON dbo.uspReporteConsumoRepuestos          TO macsa_app;
GRANT EXECUTE ON dbo.uspReporteOEEGeneral                TO macsa_app;
GO
PRINT N'  [OK] Permisos concedidos a macsa_app.';
GO

PRINT N'=== Migración completada exitosamente ===';
GO
