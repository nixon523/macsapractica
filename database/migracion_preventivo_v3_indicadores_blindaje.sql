/* ============================================================================
   MACSA CMMS - Grupo Macsa
   migracion_preventivo_v3_indicadores_blindaje.sql
   Mejoras de Blindaje, Idempotencia y Métricas de Mantenimiento Preventivo
   - Verificación de CandadoBaja y Estado Activo
   - Idempotencia en uspGenerarOrdenTrabajoPreventivaMes (evita duplicar OTs)
   - Procedimiento de Indicadores y Cumplimiento (KPIs)
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ============================================================================
-- 1. Actualizar uspGenerarOrdenTrabajoPreventivaMes con IDEMPOTENCIA y BLINDAJE
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
            SELECT @NuevaOrdenId AS NewWorkOrderId, 1 AS WasExisting;
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
        SELECT @NuevaOrdenId AS NewWorkOrderId, 0 AS WasExisting;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 2. Procedimiento Almacenado de Indicadores y Cumplimiento (KPIs PM)
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoObtenerIndicadores
    @AreaId NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TotalPlanes INT = 0;
    DECLARE @PlanesActivos INT = 0;
    DECLARE @PlanesPausados INT = 0;
    DECLARE @PlanesAlDia INT = 0;
    DECLARE @PlanesProximos INT = 0;
    DECLARE @PlanesUrgentes INT = 0;
    DECLARE @PlanesVencidos INT = 0;

    DECLARE @OTsPreventivasGeneradas INT = 0;
    DECLARE @OTsPreventivasCompletadas INT = 0;
    DECLARE @OTsPreventivasPendientes INT = 0;
    DECLARE @PorcentajeCumplimiento DECIMAL(5,2) = 0.0;

    -- Conteo de planes según estado y días restantes
    SELECT
        @TotalPlanes = COUNT(*),
        @PlanesActivos = COUNT(CASE WHEN Estado = 'active' THEN 1 END),
        @PlanesPausados = COUNT(CASE WHEN Estado = 'paused' THEN 1 END),
        @PlanesAlDia = COUNT(CASE WHEN Estado = 'active' AND DATEDIFF(day, CAST(SYSUTCDATETIME() AS DATE), CAST(ProximaFecha AS DATE)) > 7 THEN 1 END),
        @PlanesProximos = COUNT(CASE WHEN Estado = 'active' AND DATEDIFF(day, CAST(SYSUTCDATETIME() AS DATE), CAST(ProximaFecha AS DATE)) BETWEEN 3 AND 7 THEN 1 END),
        @PlanesUrgentes = COUNT(CASE WHEN Estado = 'active' AND DATEDIFF(day, CAST(SYSUTCDATETIME() AS DATE), CAST(ProximaFecha AS DATE)) BETWEEN 0 AND 2 THEN 1 END),
        @PlanesVencidos = COUNT(CASE WHEN Estado = 'active' AND DATEDIFF(day, CAST(SYSUTCDATETIME() AS DATE), CAST(ProximaFecha AS DATE)) < 0 THEN 1 END)
    FROM dbo.PlanPreventivo
    WHERE (@AreaId IS NULL OR AreaId = @AreaId);

    -- Conteo de OTs preventivas en el año actual
    SELECT
        @OTsPreventivasGeneradas = COUNT(*),
        @OTsPreventivasCompletadas = COUNT(CASE WHEN Estado = 'completed' THEN 1 END),
        @OTsPreventivasPendientes = COUNT(CASE WHEN Estado IN ('pending', 'in_progress', 'paused') THEN 1 END)
    FROM dbo.OrdenTrabajo
    WHERE YEAR(CreadoEn) = YEAR(SYSUTCDATETIME())
      AND (Descripcion LIKE '%Mantenimiento Preventivo Programado%' OR Descripcion LIKE '%[Mantenimiento Preventivo%')
      AND (@AreaId IS NULL OR AreaId = @AreaId);

    IF @OTsPreventivasGeneradas > 0
    BEGIN
        SET @PorcentajeCumplimiento = CAST((@OTsPreventivasCompletadas * 100.0) / @OTsPreventivasGeneradas AS DECIMAL(5,2));
    END
    ELSE
    BEGIN
        SET @PorcentajeCumplimiento = 100.0;
    END;

    SELECT
        @TotalPlanes               AS TotalPlanes,
        @PlanesActivos             AS PlanesActivos,
        @PlanesPausados            AS PlanesPausados,
        @PlanesAlDia               AS PlanesAlDia,
        @PlanesProximos            AS PlanesProximos,
        @PlanesUrgentes            AS PlanesUrgentes,
        @PlanesVencidos            AS PlanesVencidos,
        @OTsPreventivasGeneradas   AS OTsPreventivasGeneradas,
        @OTsPreventivasCompletadas AS OTsPreventivasCompletadas,
        @OTsPreventivasPendientes  AS OTsPreventivasPendientes,
        @PorcentajeCumplimiento    AS PorcentajeCumplimiento;
END;
GO

PRINT 'Migración Preventivo v3 (Blindaje e Indicadores) ejecutada exitosamente.';
GO
