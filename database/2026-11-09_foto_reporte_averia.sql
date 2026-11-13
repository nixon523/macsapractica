-- ============================================================================
-- SCRIPT DE MIGRACIÓN: Fotografía Opcional en Reportes de Avería y Órdenes de Trabajo
-- Fecha: 2026-11-09
-- Autor: Grupo MACSA - Sistema CMMS
-- ============================================================================
-- 1. Agregar columna ImagenUrl a dbo.ReporteAveria si no existe.
-- 2. Actualizar dbo.uspReporteAveriaCrear para recibir e insertar @ImageData / @ImagenUrl.
-- 3. Actualizar dbo.uspReporteAveriaObtenerTodos para retornar ImagenUrl AS ImageData.
-- 4. Actualizar dbo.uspReporteAveriaObtenerPorUsuario para retornar ImagenUrl AS ImageData.
-- 5. Actualizar dbo.uspReporteAveriaObtenerAbiertos para retornar ImagenUrl AS ImageData.
-- 6. Actualizar dbo.uspOrdenTrabajoObtenerTodas para relacionar dbo.ReporteAveria
--    y proyectar ra.ImagenUrl AS BreakdownImageData, permitiendo que el personal
--    de mantenimiento vea la fotografía del reporte original desde la OT.
-- ============================================================================

USE [MacsaCMMS];
GO

SET NOCOUNT ON;
GO

-- 1. Alter Table
IF NOT EXISTS (
    SELECT 1 
    FROM sys.columns 
    WHERE object_id = OBJECT_ID(N'dbo.ReporteAveria') 
      AND name = N'ImagenUrl'
)
BEGIN
    ALTER TABLE dbo.ReporteAveria ADD ImagenUrl NVARCHAR(MAX) NULL;
    PRINT 'Columna ImagenUrl agregada exitosamente a dbo.ReporteAveria.';
END
ELSE
BEGIN
    PRINT 'La columna ImagenUrl ya existe en dbo.ReporteAveria.';
END
GO

-- 2. Procedimiento uspReporteAveriaCrear
CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaCrear
    @AssetCode NVARCHAR(60), 
    @AssetName NVARCHAR(200), 
    @AreaId NVARCHAR(15),
    @Description NVARCHAR(MAX), 
    @Severity NVARCHAR(10),
    @ReporterUserId INT = NULL, 
    @ReporterUserName NVARCHAR(100) = N'',
    @ImageData NVARCHAR(MAX) = NULL
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

        INSERT INTO dbo.ReporteAveria (
            CodigoActivo, 
            NombreActivo, 
            AreaId, 
            Descripcion, 
            Severidad, 
            ReportadoPorUsuarioId, 
            ReportadoPorNombreUsuario, 
            ImagenUrl
        )
        VALUES (
            @AssetCode, 
            @AssetName, 
            @AreaId, 
            @Description, 
            @Severity, 
            @ReporterUserId, 
            @ReporterUserName, 
            @ImageData
        );
        DECLARE @rid BIGINT = SCOPE_IDENTITY();

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (
            @ReporterUserId, 
            @ReporterUserName, 
            'BREAKDOWN_REPORTED', 
            'BREAKDOWNS', 
            @AssetCode,
            CONCAT(N'Reporte ', @rid, N': avería en ', @AssetCode, N' (', @AssetName, N'). Severidad: ', @Severity, 
                   CASE WHEN @ImageData IS NOT NULL AND LEN(@ImageData) > 0 THEN N' [Con evidencia fotográfica]' ELSE N'' END)
        );

        COMMIT TRANSACTION;
        SELECT @rid AS NewReportId, @rid AS ReporteId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 3. Procedimiento uspReporteAveriaObtenerTodos
CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaObtenerTodos
    @StatusFilter NVARCHAR(15) = NULL,
    @StartDate DATETIME2(3) = NULL, 
    @EndDate DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ReporteId, 
           CodigoActivo AS AssetCode, 
           NombreActivo AS AssetName, 
           AreaId,
           Descripcion AS Description, 
           Severidad AS Severity,
           ReportadoPorUsuarioId AS ReportedByUserId, 
           ReportadoPorNombreUsuario AS ReportedByUserName,
           ReportadoEn AS ReportedAt, 
           Estado AS Status, 
           OrdenTrabajoId AS WorkOrderId,
           ResueltoPorUsuarioId AS ResolvedByUserId, 
           ResueltoPorNombreUsuario AS ResolvedByUserName,
           ResueltoEn AS ResolvedAt, 
           MotivoRechazo AS RejectionReason,
           RechazadoPorUsuarioId AS RejectedByUserId, 
           RechazadoPorNombreUsuario AS RejectedByUserName,
           RechazadoEn AS RejectedAt,
           ImagenUrl AS ImageData
      FROM dbo.ReporteAveria
     WHERE (@StatusFilter IS NULL OR Estado = @StatusFilter)
       AND (@StartDate IS NULL OR ReportadoEn >= @StartDate)
       AND (@EndDate   IS NULL OR ReportadoEn <= @EndDate)
     ORDER BY ReportadoEn DESC;
END;
GO

-- 4. Procedimiento uspReporteAveriaObtenerPorUsuario
CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaObtenerPorUsuario 
    @ReporterUserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ReporteId, 
           CodigoActivo AS AssetCode, 
           NombreActivo AS AssetName, 
           AreaId,
           Descripcion AS Description, 
           Severidad AS Severity,
           ReportadoPorUsuarioId AS ReportedByUserId, 
           ReportadoPorNombreUsuario AS ReportedByUserName,
           ReportadoEn AS ReportedAt, 
           Estado AS Status, 
           OrdenTrabajoId AS WorkOrderId,
           ResueltoPorUsuarioId AS ResolvedByUserId, 
           ResueltoPorNombreUsuario AS ResolvedByUserName,
           ResueltoEn AS ResolvedAt, 
           MotivoRechazo AS RejectionReason,
           RechazadoPorUsuarioId AS RejectedByUserId, 
           RechazadoPorNombreUsuario AS RejectedByUserName,
           RechazadoEn AS RejectedAt,
           ImagenUrl AS ImageData
      FROM dbo.ReporteAveria
     WHERE ReportadoPorUsuarioId = @ReporterUserId
     ORDER BY ReportadoEn DESC;
END;
GO

-- 5. Procedimiento uspReporteAveriaObtenerAbiertos
CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaObtenerAbiertos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ReporteId, 
           CodigoActivo AS AssetCode, 
           NombreActivo AS AssetName, 
           AreaId,
           Descripcion AS Description, 
           Severidad AS Severity,
           ReportadoPorUsuarioId AS ReportedByUserId, 
           ReportadoPorNombreUsuario AS ReportedByUserName,
           ReportadoEn AS ReportedAt, 
           Estado AS Status, 
           OrdenTrabajoId AS WorkOrderId,
           ImagenUrl AS ImageData
      FROM dbo.ReporteAveria
     WHERE Estado IN ('reported', 'inWorkOrder');
END;
GO

-- 6. Procedimiento uspOrdenTrabajoObtenerTodas (incluyendo foto de la avería si aplica)
CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoObtenerTodas
    @StatusFilter NVARCHAR(15) = NULL, 
    @AreaFilter NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.OrdenTrabajoId AS WorkOrderId, 
           w.CodigoActivo AS AssetCode, 
           w.NombreActivo AS AssetName,
           w.AreaId, 
           w.NombreArea AS AreaName, 
           w.Descripcion AS Description,
           w.Estado AS Status, 
           w.Prioridad AS Priority, 
           w.AsignadoA AS AssignedTo,
           w.CantidadPersonalAsignado AS AssignedStaffCount, 
           w.HorasEstimadas AS EstimatedHours,
           w.HorasReales AS ActualHours, 
           w.DescripcionTrabajoRealizado AS WorkDoneDescription,
           w.EstaCompletada AS IsCompleted, 
           w.MotivoIncumplimiento AS UnfulfillmentReason,
           w.FechaReprogramacion AS ReprogramDate, 
           w.ResponsableAccHaccp AS AccHaccpResponsible,
           w.ResponsableMantenimiento AS MaintenanceResponsible, 
           w.ResponsableJefeArea AS AreaHeadResponsible,
           w.ResponsableJefeMantenimiento AS MaintenanceHeadResponsible, 
           w.FechaProgramada AS ScheduledDate,
           w.ReporteId AS ReportId, 
           w.CreadoPorUsuarioId AS CreatedByUserId,
           w.CreadoPorNombreUsuario AS CreatedByUserName, 
           w.CreadoEn AS CreatedAt,
           ra.ImagenUrl AS BreakdownImageData,
           m.MaterialsJson,
           t.WorkTypesCsv
      FROM dbo.OrdenTrabajo w
      LEFT JOIN dbo.ReporteAveria ra ON w.ReporteId = ra.ReporteId
     OUTER APPLY (SELECT (SELECT NumeroLinea AS LineNum, Descripcion AS Description, Cantidad AS Quantity, Unidad AS Unit
                            FROM dbo.MaterialOrdenTrabajo
                           WHERE OrdenTrabajoId = w.OrdenTrabajoId
                           ORDER BY NumeroLinea
                             FOR JSON PATH) AS MaterialsJson) m
     OUTER APPLY (SELECT STRING_AGG(TipoTrabajo, ',') AS WorkTypesCsv
                    FROM dbo.TipoTrabajoOrdenTrabajo
                   WHERE OrdenTrabajoId = w.OrdenTrabajoId) t
     WHERE (@StatusFilter IS NULL OR w.Estado = @StatusFilter)
       AND (@AreaFilter   IS NULL OR w.AreaId = @AreaFilter)
     ORDER BY w.CreadoEn DESC;
END;
GO

-- 7. Procedimiento uspOrdenTrabajoObtenerAbiertas
CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoObtenerAbiertas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.OrdenTrabajoId AS WorkOrderId, 
           w.CodigoActivo AS AssetCode, 
           w.NombreActivo AS AssetName,
           w.AreaId, 
           w.NombreArea AS AreaName, 
           w.Descripcion AS Description,
           w.Estado AS Status, 
           w.Prioridad AS Priority, 
           w.AsignadoA AS AssignedTo,
           w.CantidadPersonalAsignado AS AssignedStaffCount, 
           w.HorasEstimadas AS EstimatedHours,
           w.FechaProgramada AS ScheduledDate, 
           w.ReporteId, 
           w.CreadoEn AS CreatedAt,
           ra.ImagenUrl AS BreakdownImageData
      FROM dbo.OrdenTrabajo w
      LEFT JOIN dbo.ReporteAveria ra ON w.ReporteId = ra.ReporteId
     WHERE w.Estado IN ('pending', 'inProgress')
     ORDER BY w.CreadoEn DESC;
END;
GO

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'macsa_app')
BEGIN
    GRANT EXECUTE ON dbo.uspReporteAveriaCrear TO macsa_app;
    GRANT EXECUTE ON dbo.uspReporteAveriaObtenerTodos TO macsa_app;
    GRANT EXECUTE ON dbo.uspReporteAveriaObtenerPorUsuario TO macsa_app;
    GRANT EXECUTE ON dbo.uspReporteAveriaObtenerAbiertos TO macsa_app;
    GRANT EXECUTE ON dbo.uspOrdenTrabajoObtenerTodas TO macsa_app;
    GRANT EXECUTE ON dbo.uspOrdenTrabajoObtenerAbiertas TO macsa_app;
END;
GO

PRINT 'Migración para fotografía de evidencia en averías y órdenes de trabajo finalizada exitosamente.';
GO
