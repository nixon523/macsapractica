/* ============================================================================
   MACSA CMMS - Grupo Macsa
   database/fase4_dashboard_indicadores_trazabilidad.sql
   Fase 4: Panel de Indicadores y Trazabilidad en Tiempo Real (Dashboard & KPIs)
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ============================================================================
-- 1. Procedimiento Almacenado de Estadísticas Enriquecidas del Dashboard
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspDashboardObtenerEstadisticas
    @AreaId NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Conteo de Activos Activos
    DECLARE @TotalAssets INT = 0;
    SELECT @TotalAssets = COUNT(*) 
      FROM dbo.Activo 
     WHERE Estado = 'active'
       AND (@AreaId IS NULL OR AreaId = @AreaId);

    -- Órdenes de Trabajo
    DECLARE @PendingWorkOrders INT = 0;
    DECLARE @InProgressWorkOrders INT = 0;
    DECLARE @CompletedWorkOrders INT = 0;
    SELECT 
        @PendingWorkOrders    = COUNT(CASE WHEN Estado = 'pending' THEN 1 END),
        @InProgressWorkOrders = COUNT(CASE WHEN Estado = 'inProgress' THEN 1 END),
        @CompletedWorkOrders  = COUNT(CASE WHEN Estado = 'completed' THEN 1 END)
      FROM dbo.OrdenTrabajo
     WHERE (@AreaId IS NULL OR AreaId = @AreaId);

    -- Planes Preventivos e Indicadores de Salud
    DECLARE @ActivePreventiveSchedules INT = 0;
    DECLARE @UrgentPreventiveSchedules INT = 0;
    DECLARE @OverduePreventiveSchedules INT = 0;
    SELECT 
        @ActivePreventiveSchedules  = COUNT(CASE WHEN Estado = 'active' THEN 1 END),
        @UrgentPreventiveSchedules  = COUNT(CASE WHEN Estado = 'active' AND DATEDIFF(day, CAST(SYSUTCDATETIME() AS DATE), CAST(ProximaFecha AS DATE)) BETWEEN 0 AND 7 THEN 1 END),
        @OverduePreventiveSchedules = COUNT(CASE WHEN Estado = 'active' AND DATEDIFF(day, CAST(SYSUTCDATETIME() AS DATE), CAST(ProximaFecha AS DATE)) < 0 THEN 1 END)
      FROM dbo.PlanPreventivo
     WHERE (@AreaId IS NULL OR AreaId = @AreaId);

    -- Averías Abiertas
    DECLARE @OpenBreakdowns INT = 0;
    SELECT @OpenBreakdowns = COUNT(*)
      FROM dbo.ReporteAveria
     WHERE Estado IN ('reported', 'inWorkOrder')
       AND (@AreaId IS NULL OR AreaId = @AreaId);

    -- Bitácora Kardex Total
    DECLARE @TotalKardexLogs INT = 0;
    SELECT @TotalKardexLogs = COUNT(*) FROM dbo.BitacoraKardex;

    -- Cumplimiento Preventivo %
    DECLARE @TotalPreventivas INT = 0;
    DECLARE @CompletadasPreventivas INT = 0;
    DECLARE @PmComplianceRate DECIMAL(5,2) = 100.0;

    SELECT 
        @TotalPreventivas = COUNT(*),
        @CompletadasPreventivas = COUNT(CASE WHEN Estado = 'completed' THEN 1 END)
      FROM dbo.OrdenTrabajo
     WHERE Descripcion LIKE '%Plan PM-%'
       AND (@AreaId IS NULL OR AreaId = @AreaId);

    IF @TotalPreventivas > 0
    BEGIN
        SET @PmComplianceRate = CAST((@CompletadasPreventivas * 100.0) / @TotalPreventivas AS DECIMAL(5,2));
    END;

    SELECT
        @TotalAssets                AS TotalAssets,
        @PendingWorkOrders          AS PendingWorkOrders,
        @InProgressWorkOrders       AS InProgressWorkOrders,
        @CompletedWorkOrders        AS CompletedWorkOrders,
        @ActivePreventiveSchedules  AS ActivePreventiveSchedules,
        @UrgentPreventiveSchedules  AS UrgentPreventiveSchedules,
        @OverduePreventiveSchedules AS OverduePreventiveSchedules,
        @OpenBreakdowns             AS OpenBreakdowns,
        @TotalKardexLogs            AS TotalKardexLogs,
        @PmComplianceRate           AS PmComplianceRate;
END;
GO

PRINT N'Fase 4: Procedimiento de Estadísticas y Trazabilidad de Dashboard actualizado con éxito.';
GO
