/* ============================================================================
   MACSA CMMS - Grupo Macsa
   database/migracion_disponibilidad_operacion.sql
   Módulo: Disponibilidad y Tiempos de Operación de Activos de Proceso
   Aplica SOLO a activos de primer nivel (Nivel = 'equipment')
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'=== Iniciando migración: Disponibilidad y Tiempos de Operación ===';
GO

-- ============================================================================
-- 1. Agregar columna EsEquipoProceso a dbo.Activo
-- ============================================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.Activo')
      AND name = 'EsEquipoProceso'
)
BEGIN
    ALTER TABLE dbo.Activo
        ADD EsEquipoProceso BIT NOT NULL CONSTRAINT DF_Activo_EsEquipoProceso DEFAULT (0);
    PRINT N'  [OK] Columna EsEquipoProceso agregada a dbo.Activo.';
END
ELSE
    PRINT N'  [SKIP] Columna EsEquipoProceso ya existe en dbo.Activo.';
GO

-- ============================================================================
-- 2. Crear tabla dbo.ReporteOperacionDiaria
-- ============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('dbo.ReporteOperacionDiaria') AND type = 'U')
BEGIN
    CREATE TABLE dbo.ReporteOperacionDiaria (
        ReporteId                    BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_ReporteOperacionDiaria PRIMARY KEY,
        CodigoActivo                 NVARCHAR(60)   NOT NULL,
        AreaId                       NVARCHAR(15)   NOT NULL,
        FechaOperacion               DATE           NOT NULL,
        HorasTotalesJornada          DECIMAL(5,2)   NOT NULL CONSTRAINT DF_ROD_HorasJornada DEFAULT (24.00),
        HorasOperacion               DECIMAL(5,2)   NOT NULL,
        HorasParoFalla               DECIMAL(5,2)   NOT NULL CONSTRAINT DF_ROD_ParoFalla    DEFAULT (0.00),
        HorasParoMantPrev            DECIMAL(5,2)   NOT NULL CONSTRAINT DF_ROD_ParoPrev     DEFAULT (0.00),
        HorasParoMantCorr            DECIMAL(5,2)   NOT NULL CONSTRAINT DF_ROD_ParoCorr     DEFAULT (0.00),
        HorasParoPlanificado         DECIMAL(5,2)   NOT NULL CONSTRAINT DF_ROD_ParoPlan     DEFAULT (0.00),
        HorasParoExterno             DECIMAL(5,2)   NOT NULL CONSTRAINT DF_ROD_ParoExt      DEFAULT (0.00),
        Observaciones                NVARCHAR(1000) NULL,
        RegistradoPorUsuarioId       INT            NULL,
        RegistradoPorNombreUsuario   NVARCHAR(200)  NOT NULL,
        RegistradoEn                 DATETIME2(3)   NOT NULL CONSTRAINT DF_ROD_RegistradoEn DEFAULT (SYSUTCDATETIME()),
        SemanaISO AS (
            CAST(YEAR(FechaOperacion) AS NVARCHAR(4))
            + N'-W'
            + RIGHT(N'0' + CAST(DATEPART(ISO_WEEK, FechaOperacion) AS NVARCHAR(2)), 2)
        ) PERSISTED,
        CONSTRAINT UQ_ROD_Activo_Fecha UNIQUE (CodigoActivo, FechaOperacion),
        CONSTRAINT CK_ROD_HorasOp     CHECK (HorasOperacion        >= 0 AND HorasOperacion        <= 24),
        CONSTRAINT CK_ROD_Jornada     CHECK (HorasTotalesJornada   >  0 AND HorasTotalesJornada   <= 24),
        CONSTRAINT CK_ROD_ParoFalla   CHECK (HorasParoFalla        >= 0),
        CONSTRAINT CK_ROD_ParoPrev    CHECK (HorasParoMantPrev     >= 0),
        CONSTRAINT CK_ROD_ParoCorr    CHECK (HorasParoMantCorr     >= 0),
        CONSTRAINT CK_ROD_ParoPlan    CHECK (HorasParoPlanificado  >= 0),
        CONSTRAINT CK_ROD_ParoExt     CHECK (HorasParoExterno      >= 0),
        CONSTRAINT CK_ROD_SumaHoras   CHECK (
            HorasOperacion + HorasParoFalla + HorasParoMantPrev
            + HorasParoMantCorr + HorasParoPlanificado + HorasParoExterno
            <= HorasTotalesJornada
        ),
        CONSTRAINT FK_ROD_Activo  FOREIGN KEY (CodigoActivo)            REFERENCES dbo.Activo(CodigoActivo),
        CONSTRAINT FK_ROD_Area    FOREIGN KEY (AreaId)                  REFERENCES dbo.Area(AreaId),
        CONSTRAINT FK_ROD_Usuario FOREIGN KEY (RegistradoPorUsuarioId)  REFERENCES dbo.Usuario(UsuarioId)
    );
    PRINT N'  [OK] Tabla dbo.ReporteOperacionDiaria creada.';
END
ELSE
    PRINT N'  [SKIP] Tabla dbo.ReporteOperacionDiaria ya existe.';
GO

-- ============================================================================
-- 3. Índices
-- ============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_ROD_Area_Fecha'   AND object_id=OBJECT_ID('dbo.ReporteOperacionDiaria'))
    CREATE NONCLUSTERED INDEX IX_ROD_Area_Fecha   ON dbo.ReporteOperacionDiaria (AreaId, FechaOperacion DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_ROD_Activo_Fecha' AND object_id=OBJECT_ID('dbo.ReporteOperacionDiaria'))
    CREATE NONCLUSTERED INDEX IX_ROD_Activo_Fecha ON dbo.ReporteOperacionDiaria (CodigoActivo, FechaOperacion DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_ROD_Semana'       AND object_id=OBJECT_ID('dbo.ReporteOperacionDiaria'))
    CREATE NONCLUSTERED INDEX IX_ROD_Semana       ON dbo.ReporteOperacionDiaria (SemanaISO, AreaId)
        INCLUDE (CodigoActivo, HorasOperacion, HorasTotalesJornada);
GO
PRINT N'  [OK] Índices de ReporteOperacionDiaria creados.';
GO

-- ============================================================================
-- 4. Actualizar CHECK constraint de BitacoraKardex para incluir OPERATION_REPORTS
-- ============================================================================
IF EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.BitacoraKardex') AND name = 'CK_BK_Modulo'
)
    ALTER TABLE dbo.BitacoraKardex DROP CONSTRAINT CK_BK_Modulo;
GO
ALTER TABLE dbo.BitacoraKardex
    ADD CONSTRAINT CK_BK_Modulo
        CHECK (Modulo IN ('ASSETS','AREAS','PREVENTIVE','BREAKDOWNS','WORK_ORDERS','OPERATION_REPORTS'));
GO
PRINT N'  [OK] Constraint CK_BK_Modulo actualizado (incluye OPERATION_REPORTS).';
GO

-- ============================================================================
-- 5. SP: uspActivoActualizarEsEquipoProceso
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspActivoActualizarEsEquipoProceso
    @CodigoActivo        NVARCHAR(60),
    @EsEquipoProceso     BIT,
    @UsuarioId           INT,
    @NombreUsuario       NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Nivel NVARCHAR(20), @Estado NVARCHAR(25), @Nombre NVARCHAR(200);
        SELECT @Nivel = Nivel, @Estado = Estado, @Nombre = Nombre
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @CodigoActivo;

        IF @Nivel IS NULL  THROW 50404, N'Activo no encontrado.', 1;
        IF @Nivel <> 'equipment'
            THROW 50400, N'Solo los activos de primer nivel pueden ser marcados como equipos de proceso.', 1;
        IF @Estado IN ('deleted','transferredDeactivated')
            THROW 50400, N'El activo está eliminado o transferido y no puede modificarse.', 1;
        IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WITH (UPDLOCK,HOLDLOCK)
                    WHERE CodigoActivo = @CodigoActivo AND EstadoCandado = 'pending')
            THROW 50409, N'El activo tiene una solicitud de baja pendiente.', 1;

        UPDATE dbo.Activo
           SET EsEquipoProceso = @EsEquipoProceso, ActualizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @CodigoActivo;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (
            @UsuarioId, @NombreUsuario,
            CASE @EsEquipoProceso WHEN 1 THEN N'ASSET_MARKED_PROCESS' ELSE N'ASSET_UNMARKED_PROCESS' END,
            N'ASSETS', @CodigoActivo,
            CASE @EsEquipoProceso
                WHEN 1 THEN N'Activo marcado como equipo de proceso. Disponibilidad operativa habilitada.'
                ELSE        N'Activo desmarcado como equipo de proceso. Disponibilidad operativa deshabilitada.'
            END
        );

        COMMIT TRANSACTION;
        SELECT @CodigoActivo AS CodigoActivo, @EsEquipoProceso AS EsEquipoProceso;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; THROW;
    END CATCH
END;
GO
PRINT N'  [OK] SP uspActivoActualizarEsEquipoProceso creado.';
GO

-- ============================================================================
-- 6. SP: uspReporteOperacionRegistrar  (MERGE: INSERT o UPDATE + Kardex)
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionRegistrar
    @CodigoActivo         NVARCHAR(60),
    @FechaOperacion       DATE,
    @HorasTotalesJornada  DECIMAL(5,2) = 24.00,
    @HorasOperacion       DECIMAL(5,2),
    @HorasParoFalla       DECIMAL(5,2) = 0.00,
    @HorasParoMantPrev    DECIMAL(5,2) = 0.00,
    @HorasParoMantCorr    DECIMAL(5,2) = 0.00,
    @HorasParoPlanificado DECIMAL(5,2) = 0.00,
    @HorasParoExterno     DECIMAL(5,2) = 0.00,
    @Observaciones        NVARCHAR(1000) = NULL,
    @UsuarioId            INT,
    @NombreUsuario        NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Nivel NVARCHAR(20), @EsProc BIT, @Estado NVARCHAR(25),
                @AreaId NVARCHAR(15), @NombreActivo NVARCHAR(200);

        SELECT @Nivel = Nivel, @EsProc = EsEquipoProceso, @Estado = Estado,
               @AreaId = AreaId, @NombreActivo = Nombre
          FROM dbo.Activo WITH (HOLDLOCK)
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
            HorasTotalesJornada      = @HorasTotalesJornada,
            HorasOperacion           = @HorasOperacion,
            HorasParoFalla           = @HorasParoFalla,
            HorasParoMantPrev        = @HorasParoMantPrev,
            HorasParoMantCorr        = @HorasParoMantCorr,
            HorasParoPlanificado     = @HorasParoPlanificado,
            HorasParoExterno         = @HorasParoExterno,
            Observaciones            = @Observaciones,
            RegistradoPorUsuarioId   = @UsuarioId,
            RegistradoPorNombreUsuario = @NombreUsuario,
            RegistradoEn             = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN INSERT (
            CodigoActivo, AreaId, FechaOperacion,
            HorasTotalesJornada, HorasOperacion,
            HorasParoFalla, HorasParoMantPrev, HorasParoMantCorr,
            HorasParoPlanificado, HorasParoExterno,
            Observaciones, RegistradoPorUsuarioId, RegistradoPorNombreUsuario
        ) VALUES (
            @CodigoActivo, @AreaId, @FechaOperacion,
            @HorasTotalesJornada, @HorasOperacion,
            @HorasParoFalla, @HorasParoMantPrev, @HorasParoMantCorr,
            @HorasParoPlanificado, @HorasParoExterno,
            @Observaciones, @UsuarioId, @NombreUsuario
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
                N' | MP: ', CAST(@HorasParoMantPrev AS NVARCHAR), N'h',
                N' | MC: ', CAST(@HorasParoMantCorr AS NVARCHAR), N'h',
                N' | Plan: ', CAST(@HorasParoPlanificado AS NVARCHAR), N'h',
                N' | Ext: ', CAST(@HorasParoExterno AS NVARCHAR), N'h',
                N' | Jornada: ', CAST(@HorasTotalesJornada AS NVARCHAR), N'h',
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
            CAST(CAST((r.HorasOperacion / NULLIF(r.HorasTotalesJornada,0))*100 AS DECIMAL(5,2)) AS FLOAT) AS DisponibilidadPct
          FROM dbo.ReporteOperacionDiaria r
         WHERE r.CodigoActivo = @CodigoActivo AND r.FechaOperacion = @FechaOperacion;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; THROW;
    END CATCH
END;
GO
PRINT N'  [OK] SP uspReporteOperacionRegistrar creado.';
GO

-- ============================================================================
-- 7. SP: uspReporteOperacionObtenerPorActivo
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
        CAST(CAST((r.HorasOperacion / NULLIF(r.HorasTotalesJornada,0))*100 AS DECIMAL(5,2)) AS FLOAT) AS DisponibilidadPct
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
PRINT N'  [OK] SP uspReporteOperacionObtenerPorActivo creado.';
GO

-- ============================================================================
-- 8. SP: uspReporteOperacionObtenerPorSemana
--    Activos de proceso de un área × 7 días (lunes a domingo), LEFT JOIN reportes.
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionObtenerPorSemana
    @AreaId          NVARCHAR(15),
    @LunesDeLaSemana DATE
AS
BEGIN
    SET NOCOUNT ON;

    WITH Dias AS (
        SELECT DATEADD(day, n, @LunesDeLaSemana) AS Dia
        FROM (VALUES (0),(1),(2),(3),(4),(5),(6)) t(n)
    ),
    ActivosProceso AS (
        SELECT CodigoActivo, Nombre
          FROM dbo.Activo
         WHERE AreaId = @AreaId
           AND Nivel = 'equipment'
           AND EsEquipoProceso = 1
           AND Estado = 'active'
    )
    SELECT
        ap.CodigoActivo, ap.Nombre AS NombreActivo, d.Dia AS FechaOperacion,
        r.ReporteId,
        ISNULL(r.HorasTotalesJornada, 24)  AS HorasTotalesJornada,
        ISNULL(r.HorasOperacion, 0)        AS HorasOperacion,
        ISNULL(r.HorasParoFalla, 0)        AS HorasParoFalla,
        ISNULL(r.HorasParoMantPrev, 0)     AS HorasParoMantPrev,
        ISNULL(r.HorasParoMantCorr, 0)     AS HorasParoMantCorr,
        ISNULL(r.HorasParoPlanificado, 0)  AS HorasParoPlanificado,
        ISNULL(r.HorasParoExterno, 0)      AS HorasParoExterno,
        r.Observaciones,
        r.RegistradoPorNombreUsuario,
        r.RegistradoEn,
        CASE WHEN r.ReporteId IS NULL THEN NULL
             ELSE CAST(CAST((r.HorasOperacion / NULLIF(r.HorasTotalesJornada,0))*100 AS DECIMAL(5,2)) AS FLOAT)
        END AS DisponibilidadPct
    FROM ActivosProceso ap
    CROSS JOIN Dias d
    LEFT JOIN dbo.ReporteOperacionDiaria r
           ON r.CodigoActivo   = ap.CodigoActivo
          AND r.FechaOperacion = d.Dia
    ORDER BY ap.Nombre, d.Dia;
END;
GO
PRINT N'  [OK] SP uspReporteOperacionObtenerPorSemana creado.';
GO

-- ============================================================================
-- 9. SP: uspReporteOperacionMetricas
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
        CAST(CAST(
            SUM(r.HorasOperacion) * 100.0
            / NULLIF(SUM(r.HorasTotalesJornada), 0)
        AS DECIMAL(5,2)) AS FLOAT)            AS DisponibilidadPct,
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
PRINT N'  [OK] SP uspReporteOperacionMetricas creado.';
GO

-- ============================================================================
-- 10. SP: uspEquipoProcesoListarPorArea
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspEquipoProcesoListarPorArea
    @AreaId NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        a.CodigoActivo, a.Nombre, a.Marca, a.Modelo,
        a.AreaId, ar.Nombre AS NombreArea,
        a.Estado, a.EsEquipoProceso, a.CreadoEn
    FROM dbo.Activo a
    INNER JOIN dbo.Area ar ON ar.AreaId = a.AreaId
    WHERE a.Nivel = 'equipment'
      AND a.EsEquipoProceso = 1
      AND a.Estado = 'active'
      AND (@AreaId IS NULL OR a.AreaId = @AreaId)
    ORDER BY ar.Nombre, a.Nombre;
END;
GO
PRINT N'  [OK] SP uspEquipoProcesoListarPorArea creado.';
GO

-- ============================================================================
-- 11. Actualizar uspDashboardObtenerEstadisticas (incluye disponibilidad promedio)
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspDashboardObtenerEstadisticas
    @AreaId NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TotalAssets INT = 0;
    SELECT @TotalAssets = COUNT(*) FROM dbo.Activo
     WHERE Estado = 'active' AND (@AreaId IS NULL OR AreaId = @AreaId);

    DECLARE @PendingWO INT=0, @InProgressWO INT=0, @CompletedWO INT=0;
    SELECT @PendingWO    = COUNT(CASE WHEN Estado='pending'     THEN 1 END),
           @InProgressWO = COUNT(CASE WHEN Estado='inProgress'  THEN 1 END),
           @CompletedWO  = COUNT(CASE WHEN Estado='completed'   THEN 1 END)
      FROM dbo.OrdenTrabajo WHERE (@AreaId IS NULL OR AreaId=@AreaId);

    DECLARE @ActivePM INT=0, @UrgentPM INT=0, @OverduePM INT=0;
    SELECT @ActivePM  = COUNT(CASE WHEN Estado='active' THEN 1 END),
           @UrgentPM  = COUNT(CASE WHEN Estado='active' AND DATEDIFF(day,CAST(SYSUTCDATETIME() AS DATE),CAST(ProximaFecha AS DATE)) BETWEEN 0 AND 7 THEN 1 END),
           @OverduePM = COUNT(CASE WHEN Estado='active' AND DATEDIFF(day,CAST(SYSUTCDATETIME() AS DATE),CAST(ProximaFecha AS DATE)) < 0 THEN 1 END)
      FROM dbo.PlanPreventivo WHERE (@AreaId IS NULL OR AreaId=@AreaId);

    DECLARE @OpenBD INT=0;
    SELECT @OpenBD=COUNT(*) FROM dbo.ReporteAveria
     WHERE Estado IN ('reported','inWorkOrder') AND (@AreaId IS NULL OR AreaId=@AreaId);

    DECLARE @Kardex INT=0;
    SELECT @Kardex=COUNT(*) FROM dbo.BitacoraKardex;

    DECLARE @TotalPM INT=0, @CompPM INT=0, @PmRate DECIMAL(5,2)=100.0;
    SELECT @TotalPM=COUNT(*), @CompPM=COUNT(CASE WHEN Estado='completed' THEN 1 END)
      FROM dbo.OrdenTrabajo WHERE Descripcion LIKE N'%Plan PM-%' AND (@AreaId IS NULL OR AreaId=@AreaId);
    IF @TotalPM > 0 SET @PmRate=CAST((@CompPM*100.0)/@TotalPM AS DECIMAL(5,2));

    DECLARE @DispPct DECIMAL(5,2) = 0.0;
    SELECT @DispPct = CAST(SUM(HorasOperacion)*100.0/NULLIF(SUM(HorasTotalesJornada),0) AS DECIMAL(5,2))
      FROM dbo.ReporteOperacionDiaria
     WHERE FechaOperacion >= DATEADD(day,-7,CAST(SYSUTCDATETIME() AS DATE))
       AND (@AreaId IS NULL OR AreaId=@AreaId);

    DECLARE @TotalProc INT=0;
    SELECT @TotalProc=COUNT(*) FROM dbo.Activo
     WHERE Nivel='equipment' AND EsEquipoProceso=1 AND Estado='active'
       AND (@AreaId IS NULL OR AreaId=@AreaId);

    SELECT
        @TotalAssets   AS TotalAssets,
        @PendingWO     AS PendingWorkOrders,
        @InProgressWO  AS InProgressWorkOrders,
        @CompletedWO   AS CompletedWorkOrders,
        @ActivePM      AS ActivePreventiveSchedules,
        @UrgentPM      AS UrgentPreventiveSchedules,
        @OverduePM     AS OverduePreventiveSchedules,
        @OpenBD        AS OpenBreakdowns,
        @Kardex        AS TotalKardexLogs,
        @PmRate        AS PmComplianceRate,
        ISNULL(@DispPct,0.0) AS AvgDisponibilidadPct,
        @TotalProc     AS TotalEquiposProceso;
END;
GO
PRINT N'  [OK] uspDashboardObtenerEstadisticas actualizado con métricas de disponibilidad.';
GO

PRINT N'';
PRINT N'=== Migración Disponibilidad y Tiempos de Operación completada con éxito ===';
GO
