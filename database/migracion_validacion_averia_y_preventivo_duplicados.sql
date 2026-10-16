-- ============================================================================
-- SCRIPT DE PRODUCCIÓN: CONTROL ANTI-DUPLICADOS (AVERÍAS Y OTs PREVENTIVAS)
-- Base de datos: macsa_db
-- Descripción:
--   1. dbo.uspReporteAveriaCrear: Impide registrar un nuevo reporte de avería
--      si el activo ya cuenta con una avería en estado 'reported' o 'inWorkOrder'.
--   2. dbo.uspGenerarOrdenTrabajoPreventivaMes: Asegura idempotencia estricta,
--      impidiendo generar una nueva Orden de Trabajo si ya existe una orden
--      abierta ('pending', 'in_progress', 'paused') para el plan en el período.
-- ============================================================================

USE macsa_db;
GO

PRINT '============================================================================';
PRINT 'Iniciando aplicación de validaciones anti-duplicados en macsa_db...';
PRINT '============================================================================';
GO

-- ============================================================================
-- 1. Actualizar uspReporteAveriaCrear
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaCrear
    @AssetCode NVARCHAR(60), @AssetName NVARCHAR(200), @AreaId NVARCHAR(15),
    @Description NVARCHAR(MAX), @Severity NVARCHAR(10),
    @ReporterUserId INT = NULL, @ReporterUserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.Activo WHERE CodigoActivo = @AssetCode)
        BEGIN
            RAISERROR(N'El activo no existe.', 16, 1);
        END;

        -- Validar que no exista ya un reporte de avería previo pendiente o en proceso para este activo
        DECLARE @ReporteExistenteId BIGINT;
        SELECT TOP 1 @ReporteExistenteId = ReporteId
          FROM dbo.ReporteAveria WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @AssetCode
           AND Estado IN (N'reported', N'inWorkOrder');

        IF @ReporteExistenteId IS NOT NULL
        BEGIN
            DECLARE @MsgError NVARCHAR(250) = CONCAT(N'El activo ', @AssetCode, N' ya cuenta con un reporte de avería pendiente o en orden de trabajo (#', @ReporteExistenteId, N').');
            RAISERROR(@MsgError, 16, 1);
        END;

        INSERT INTO dbo.ReporteAveria (CodigoActivo, NombreActivo, AreaId, Descripcion, Severidad, ReportadoPorUsuarioId, ReportadoPorNombreUsuario)
        VALUES (@AssetCode, @AssetName, @AreaId, @Description, @Severity, @ReporterUserId, @ReporterUserName);
        DECLARE @rid BIGINT = SCOPE_IDENTITY();

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@ReporterUserId, @ReporterUserName, 'BREAKDOWN_REPORTED', 'BREAKDOWNS', @AssetCode,
                CONCAT(N'Reporte ', @rid, N': avería en ', @AssetCode, N' (', @AssetName, N'). Severidad: ', @Severity, N'.'));

        COMMIT TRANSACTION;
        SELECT @rid AS NewReportId, @rid AS ReporteId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 2. Actualizar uspGenerarOrdenTrabajoPreventivaMes
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspGenerarOrdenTrabajoPreventivaMes
    @PlanId             NVARCHAR(20),
    @Anio               INT,
    @Mes                INT,
    @CreadoPorUsuarioId INT,
    @CreadoPorNombre    NVARCHAR(100),
    @NuevaOrdenId       NVARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Obtener datos del Equipo Padre
        DECLARE @CodigoPadre NVARCHAR(60), @NombrePadre NVARCHAR(200),
                @AreaId NVARCHAR(15), @NombreArea NVARCHAR(200), @EstadoPlan NVARCHAR(10);
        SELECT
            @CodigoPadre = p.CodigoActivo,
            @NombrePadre = p.NombreActivo,
            @AreaId      = p.AreaId,
            @NombreArea  = p.NombreArea,
            @EstadoPlan  = p.Estado
        FROM dbo.PlanPreventivo p WITH (UPDLOCK, HOLDLOCK)
        WHERE p.PlanId = @PlanId;

        IF @CodigoPadre IS NULL
            RAISERROR('El plan preventivo no existe.', 16, 1);

        IF @EstadoPlan = 'paused'
            RAISERROR('El plan preventivo se encuentra pausado/suspendido. Reactívelo antes de generar una OT.', 16, 1);

        -- Verificar que el equipo no esté bloqueado por solicitud de baja pendiente
        IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE CodigoActivo = @CodigoPadre AND EstadoCandado = 'pending')
            RAISERROR('El equipo principal tiene un trámite de baja pendiente. No se pueden emitir órdenes.', 16, 1);

        -- Verificar si el activo principal sigue activo
        IF EXISTS (SELECT 1 FROM dbo.Activo WHERE CodigoActivo = @CodigoPadre AND Estado IN ('inactive', 'deleted', 'transferredDeactivated'))
            RAISERROR('El equipo principal se encuentra inactivo, dado de baja o traspasado.', 16, 1);

        -- 2. IDEMPOTENCIA: Verificar si ya existe una OT abierta generada para este plan en este período
        DECLARE @OTExistente NVARCHAR(20);
        SELECT TOP 1 @OTExistente = ot.OrdenTrabajoId
        FROM dbo.OrdenTrabajo ot
        WHERE ot.CodigoActivo = @CodigoPadre
          AND ot.Estado IN ('pending', 'in_progress', 'paused')
          AND YEAR(ot.FechaProgramada) = @Anio
          AND MONTH(ot.FechaProgramada) = @Mes
          AND ot.Descripcion LIKE CONCAT('%Plan ', @PlanId, '%');

        IF @OTExistente IS NOT NULL
        BEGIN
            -- Ya existe una OT abierta para este período, retornar la existente sin duplicar
            SET @NuevaOrdenId = @OTExistente;
            COMMIT TRANSACTION;
            SELECT @NuevaOrdenId AS NewWorkOrderId, 1 AS WasExisting, 1 AS YaExistia;
            RETURN;
        END;

        -- 3. Identificar actividades de componentes hijos activos que vencen en el mes/año
        DECLARE @ActividadesMes TABLE (
            ActividadId BIGINT, CodigoHijo NVARCHAR(60), NombreHijo NVARCHAR(200),
            Tarea NVARCHAR(300), Horas DECIMAL(5,2)
        );

        INSERT INTO @ActividadesMes
        SELECT ppa.ActividadId, ppa.CodigoActivoHijo, ppa.NombreActivoHijo, ppa.DescripcionActividad, ppa.HorasEstimadas
        FROM dbo.PlanPreventivoActividad ppa
        INNER JOIN dbo.Activo a ON a.CodigoActivo = ppa.CodigoActivoHijo
        WHERE ppa.PlanId = @PlanId
          AND ppa.Estado = 'active'
          AND a.Estado = 'active'
          AND YEAR(ppa.ProximaFecha) = @Anio
          AND MONTH(ppa.ProximaFecha) = @Mes;

        -- Si no hay específicas de ese mes, incluir todas las actividades activas del plan
        IF NOT EXISTS (SELECT 1 FROM @ActividadesMes)
        BEGIN
            INSERT INTO @ActividadesMes
            SELECT ppa.ActividadId, ppa.CodigoActivoHijo, ppa.NombreActivoHijo, ppa.DescripcionActividad, ppa.HorasEstimadas
            FROM dbo.PlanPreventivoActividad ppa
            INNER JOIN dbo.Activo a ON a.CodigoActivo = ppa.CodigoActivoHijo
            WHERE ppa.PlanId = @PlanId
              AND ppa.Estado = 'active'
              AND a.Estado = 'active';
        END;

        -- 4. Generar correlativo de OT
        DECLARE @cTable TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT deleted.SiguienteNumero INTO @cTable(v)
          WHERE Nombre = 'work_orders';

        DECLARE @n INT; SELECT @n = v FROM @cTable;
        SET @NuevaOrdenId = CONCAT('OT-', @Anio, '-', FORMAT(@n, '0000'));

        -- 5. Construir descripción consolidada
        DECLARE @Desc NVARCHAR(MAX) =
            CONCAT(N'Mantenimiento Preventivo Programado (Plan ', @PlanId, N') - ', @NombrePadre, CHAR(13), CHAR(10),
                   N'Período: ', FORMAT(DATEFROMPARTS(@Anio, @Mes, 1), 'MMMM yyyy', 'es-ES'), CHAR(13), CHAR(10),
                   N'Actividades en Componentes:', CHAR(13), CHAR(10));

        SELECT @Desc += CONCAT(N' • [', CodigoHijo, N' - ', NombreHijo, N']: ', Tarea, CHAR(13), CHAR(10))
        FROM @ActividadesMes;

        -- 6. Insertar la OT
        INSERT INTO dbo.OrdenTrabajo (
            OrdenTrabajoId, CodigoActivo, NombreActivo, AreaId, NombreArea,
            Descripcion, Estado, Prioridad, CreadoPorUsuarioId, CreadoPorNombreUsuario,
            FechaProgramada, CreadoEn)
        VALUES (
            @NuevaOrdenId, @CodigoPadre, @NombrePadre, @AreaId, @NombreArea,
            @Desc, 'pending', 'medium', @CreadoPorUsuarioId, @CreadoPorNombre,
            DATEFROMPARTS(@Anio, @Mes, 1), SYSUTCDATETIME());

        -- 7. Consolidar materiales
        INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
        SELECT @NuevaOrdenId, ROW_NUMBER() OVER (ORDER BY m.MaterialId),
               CONCAT(m.NombreMaterial, N' (para ', act.NombreHijo, N')'), m.Cantidad, m.Unidad
        FROM dbo.PlanPreventivoMaterial m
        INNER JOIN @ActividadesMes act ON act.ActividadId = m.ActividadId;

        -- 8. Avanzar ProximaFecha de las actividades hijas involucradas
        UPDATE ppa
           SET ProximaFecha = dbo.fnCalcularProximaFechaPreventiva(
                   ppa.ProximaFecha, ppa.IntervaloFrecuencia, ppa.UnidadFrecuencia),
               FechaUltimaEjecucion = SYSUTCDATETIME()
          FROM dbo.PlanPreventivoActividad ppa
         INNER JOIN @ActividadesMes am ON am.ActividadId = ppa.ActividadId;

        -- 9. Recalcular cabecera del plan
        DECLARE @minNextDate DATETIME2(3);
        SELECT @minNextDate = MIN(ProximaFecha)
          FROM dbo.PlanPreventivoActividad
         WHERE PlanId = @PlanId AND Estado = 'active';

        UPDATE dbo.PlanPreventivo
           SET UltimaOrdenTrabajoId = @NuevaOrdenId,
               UltimaCompletada = SYSUTCDATETIME(),
               ProximaFecha = ISNULL(@minNextDate, ProximaFecha)
         WHERE PlanId = @PlanId;

        -- 10. Bitácora Kardex
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreadoPorUsuarioId, @CreadoPorNombre, 'WORK_ORDER_CREATED', 'WORK_ORDERS', @NuevaOrdenId,
                CONCAT(N'OT preventiva consolidada ', @NuevaOrdenId, N' generada para ', @CodigoPadre, N' (Plan ', @PlanId, N').'));

        COMMIT TRANSACTION;
        SELECT @NuevaOrdenId AS NewWorkOrderId, 0 AS WasExisting, 0 AS YaExistia;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 3. Permisos de Ejecución
-- ============================================================================
GRANT EXECUTE ON dbo.uspReporteAveriaCrear TO macsa_app;
GRANT EXECUTE ON dbo.uspGenerarOrdenTrabajoPreventivaMes TO macsa_app;
GO

PRINT '============================================================================';
PRINT 'Migración completada exitosamente en Producción.';
PRINT '1. dbo.uspReporteAveriaCrear: Bloqueo anti-duplicados para averías activo.';
PRINT '2. dbo.uspGenerarOrdenTrabajoPreventivaMes: Idempotencia para preventivos activa.';
PRINT '============================================================================';
GO
