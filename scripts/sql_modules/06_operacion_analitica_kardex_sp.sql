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
