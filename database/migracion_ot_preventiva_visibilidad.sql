USE MacsaCMMS;
GO

-- ============================================================================
-- 1. Agregar columna PlanPreventivoId a dbo.OrdenTrabajo si no existe
-- ============================================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.columns 
    WHERE object_id = OBJECT_ID(N'dbo.OrdenTrabajo') 
      AND name = N'PlanPreventivoId'
)
BEGIN
    ALTER TABLE dbo.OrdenTrabajo
    ADD PlanPreventivoId NVARCHAR(20) NULL;
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys 
    WHERE name = N'FK_OT_PlanPreventivo'
)
BEGIN
    ALTER TABLE dbo.OrdenTrabajo
    ADD CONSTRAINT FK_OT_PlanPreventivo 
    FOREIGN KEY (PlanPreventivoId) REFERENCES dbo.PlanPreventivo(PlanId);
END;
GO

-- ============================================================================
-- 2. Actualizar dbo.uspOrdenTrabajoObtenerTodas para retornar PlanPreventivoId
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoObtenerTodas
    @StatusFilter NVARCHAR(15) = NULL, @AreaFilter NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.OrdenTrabajoId AS WorkOrderId, w.CodigoActivo AS AssetCode, w.NombreActivo AS AssetName,
           w.AreaId, w.NombreArea AS AreaName, w.Descripcion AS Description,
           w.Estado AS Status, w.Prioridad AS Priority, w.AsignadoA AS AssignedTo,
           w.CantidadPersonalAsignado AS AssignedStaffCount, w.HorasEstimadas AS EstimatedHours,
           w.HorasReales AS ActualHours, w.DescripcionTrabajoRealizado AS WorkDoneDescription,
           w.EstaCompletada AS IsCompleted, w.MotivoIncumplimiento AS UnfulfillmentReason,
           w.FechaReprogramacion AS ReprogramDate, w.ResponsableAccHaccp AS AccHaccpResponsible,
           w.ResponsableMantenimiento AS MaintenanceResponsible, w.ResponsableJefeArea AS AreaHeadResponsible,
           w.ResponsableJefeMantenimiento AS MaintenanceHeadResponsible, w.FechaProgramada AS ScheduledDate,
           w.ReporteId AS ReportId, 
           w.PlanPreventivoId AS PreventiveScheduleId,
           w.PlanPreventivoId,
           w.CreadoPorUsuarioId AS CreatedByUserId,
           w.CreadoPorNombreUsuario AS CreatedByUserName, w.CreadoEn AS CreatedAt,
           m.MaterialsJson,
           t.WorkTypesCsv
      FROM dbo.OrdenTrabajo w
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

-- ============================================================================
-- 3. Actualizar dbo.uspOrdenTrabajoObtenerAbiertas
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoObtenerAbiertas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.OrdenTrabajoId AS WorkOrderId, w.CodigoActivo AS AssetCode, w.NombreActivo AS AssetName,
           w.AreaId, w.NombreArea AS AreaName, w.Descripcion AS Description,
           w.Estado AS Status, w.Prioridad AS Priority, w.AsignadoA AS AssignedTo,
           w.CantidadPersonalAsignado AS AssignedStaffCount, w.HorasEstimadas AS EstimatedHours,
           w.FechaProgramada AS ScheduledDate, w.ReporteId AS ReportId, 
           w.PlanPreventivoId AS PreventiveScheduleId,
           w.PlanPreventivoId,
           w.CreadoEn AS CreatedAt,
           t.WorkTypesCsv
      FROM dbo.OrdenTrabajo w
     OUTER APPLY (SELECT STRING_AGG(TipoTrabajo, ',') AS WorkTypesCsv
                    FROM dbo.TipoTrabajoOrdenTrabajo
                   WHERE OrdenTrabajoId = w.OrdenTrabajoId) t
     WHERE w.Estado IN ('pending', 'inProgress')
     ORDER BY w.CreadoEn DESC;
END;
GO

-- ============================================================================
-- 4. Actualizar dbo.uspGenerarOrdenTrabajoPreventivaMes
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
          AND ot.Estado IN ('pending', 'in_progress', 'inProgress', 'paused')
          AND YEAR(ot.FechaProgramada) = @Anio
          AND MONTH(ot.FechaProgramada) = @Mes
          AND (ot.PlanPreventivoId = @PlanId OR ot.Descripcion LIKE CONCAT('%Plan ', @PlanId, '%'));

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

        -- 5. Construir descripción consolidada limpia y legible
        DECLARE @NombreMes NVARCHAR(30) = FORMAT(DATEFROMPARTS(@Anio, @Mes, 1), 'MMMM yyyy', 'es-ES');
        DECLARE @Desc NVARCHAR(MAX) =
            CONCAT(N'Mantenimiento Preventivo Programado (Plan ', @PlanId, N') - ', @NombrePadre, CHAR(13), CHAR(10),
                   N'Período: ', UPPER(LEFT(@NombreMes, 1)) + SUBSTRING(@NombreMes, 2, LEN(@NombreMes)), CHAR(13), CHAR(10),
                   N'Actividades por componente:', CHAR(13), CHAR(10));

        SELECT @Desc += CONCAT(N'- ', CodigoHijo, N' - ', NombreHijo, N': ', Tarea, CHAR(13), CHAR(10))
        FROM @ActividadesMes;

        -- 6. Insertar la OT con PlanPreventivoId
        INSERT INTO dbo.OrdenTrabajo (
            OrdenTrabajoId, CodigoActivo, NombreActivo, AreaId, NombreArea,
            Descripcion, Estado, Prioridad, CreadoPorUsuarioId, CreadoPorNombreUsuario,
            FechaProgramada, PlanPreventivoId, CreadoEn)
        VALUES (
            @NuevaOrdenId, @CodigoPadre, @NombrePadre, @AreaId, @NombreArea,
            @Desc, 'pending', 'medium', @CreadoPorUsuarioId, @CreadoPorNombre,
            DATEFROMPARTS(@Anio, @Mes, 1), @PlanId, SYSUTCDATETIME());

        -- 7. Insertar tipos de trabajo: preventive y scheduled
        INSERT INTO dbo.TipoTrabajoOrdenTrabajo (OrdenTrabajoId, TipoTrabajo)
        VALUES (@NuevaOrdenId, 'preventive'), (@NuevaOrdenId, 'scheduled');

        -- 8. Consolidar materiales
        INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
        SELECT @NuevaOrdenId, ROW_NUMBER() OVER (ORDER BY m.MaterialId),
               CONCAT(m.NombreMaterial, N' (para ', act.NombreHijo, N')'), m.Cantidad, m.Unidad
        FROM dbo.PlanPreventivoMaterial m
        INNER JOIN @ActividadesMes act ON act.ActividadId = m.ActividadId;

        -- 9. Avanzar ProximaFecha de las actividades hijas involucradas
        UPDATE ppa
           SET ProximaFecha = dbo.fnCalcularProximaFechaPreventiva(
                   ppa.ProximaFecha, ppa.IntervaloFrecuencia, ppa.UnidadFrecuencia),
               FechaUltimaEjecucion = SYSUTCDATETIME()
          FROM dbo.PlanPreventivoActividad ppa
         INNER JOIN @ActividadesMes am ON am.ActividadId = ppa.ActividadId;

        -- 10. Recalcular cabecera del plan
        DECLARE @minNextDate DATETIME2(3);
        SELECT @minNextDate = MIN(ProximaFecha)
          FROM dbo.PlanPreventivoActividad
         WHERE PlanId = @PlanId AND Estado = 'active';

        UPDATE dbo.PlanPreventivo
           SET UltimaOrdenTrabajoId = @NuevaOrdenId,
               UltimaCompletada = SYSUTCDATETIME(),
               ProximaFecha = ISNULL(@minNextDate, ProximaFecha)
         WHERE PlanId = @PlanId;

        -- 11. Bitácora Kardex
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
-- 5. Backfill de OTs existentes generadas desde planes preventivos
-- ============================================================================
UPDATE dbo.OrdenTrabajo
   SET PlanPreventivoId = 'PM-2026-0004'
 WHERE Descripcion LIKE '%PM-2026-0004%' AND PlanPreventivoId IS NULL;

UPDATE dbo.OrdenTrabajo
   SET PlanPreventivoId = 'PM-2026-0005'
 WHERE Descripcion LIKE '%PM-2026-0005%' AND PlanPreventivoId IS NULL;

UPDATE dbo.OrdenTrabajo
   SET PlanPreventivoId = 'PM-2026-0006'
 WHERE Descripcion LIKE '%PM-2026-0006%' AND PlanPreventivoId IS NULL;

-- Asignar tipo de trabajo preventive y scheduled si faltaban
INSERT INTO dbo.TipoTrabajoOrdenTrabajo (OrdenTrabajoId, TipoTrabajo)
SELECT ot.OrdenTrabajoId, 'preventive'
  FROM dbo.OrdenTrabajo ot
 WHERE ot.PlanPreventivoId IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM dbo.TipoTrabajoOrdenTrabajo tt
        WHERE tt.OrdenTrabajoId = ot.OrdenTrabajoId AND tt.TipoTrabajo = 'preventive'
   );

INSERT INTO dbo.TipoTrabajoOrdenTrabajo (OrdenTrabajoId, TipoTrabajo)
SELECT ot.OrdenTrabajoId, 'scheduled'
  FROM dbo.OrdenTrabajo ot
 WHERE ot.PlanPreventivoId IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM dbo.TipoTrabajoOrdenTrabajo tt
        WHERE tt.OrdenTrabajoId = ot.OrdenTrabajoId AND tt.TipoTrabajo = 'scheduled'
   );
GO

-- Limpiar formato y mojibake de descripciones existentes
UPDATE dbo.OrdenTrabajo
   SET Descripcion = REPLACE(
                        REPLACE(
                           REPLACE(
                              REPLACE(
                                 REPLACE(
                                    REPLACE(
                                       REPLACE(
                                          REPLACE(Descripcion, N'â€¢', N'* '),
                                       N'â€”', N' - '),
                                    N'â€“', N' - '),
                                 N'•', N'* '),
                              N'—', N' - '),
                           N' - [', N'* '),
                        N'[A', N'A'),
                     N']: ', N': ')
 WHERE Descripcion IS NOT NULL;

-- Permisos
GRANT EXECUTE ON dbo.uspOrdenTrabajoObtenerTodas TO macsa_app;
GRANT EXECUTE ON dbo.uspOrdenTrabajoObtenerAbiertas TO macsa_app;
GRANT EXECUTE ON dbo.uspGenerarOrdenTrabajoPreventivaMes TO macsa_app;
GO
