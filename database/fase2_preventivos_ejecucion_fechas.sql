/* ============================================================================
   MACSA CMMS - Grupo Macsa
   fase2_preventivos_ejecucion_fechas.sql
   Fase 2: Consolidación Total del Mantenimiento Preventivo Jerárquico
   - Cálculo dinámico de fechas por componente (días, semanas, meses, años, bianual)
   - Creación y edición de planes con actividades y materiales por hijo
   - Generación de OTs consolidadas mensuales (Idempotente)
   - Avance automático de fechas por componente y recálculo del padre al ejecutar
   - Sincronización al completar la OT preventiva
   - Panel de KPIs e Indicadores de Cumplimiento (PM Compliance)
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ============================================================================
-- 1. Función de Cálculo de Próxima Fecha Preventiva
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fnCalcularProximaFechaPreventiva (
    @FechaBase    DATETIME2(3),
    @Intervalo    INT,
    @Unidad       NVARCHAR(20)
)
RETURNS DATETIME2(3)
AS
BEGIN
    DECLARE @Resultado DATETIME2(3) = @FechaBase;
    DECLARE @Int INT = ISNULL(@Intervalo, 1);
    DECLARE @Uni NVARCHAR(20) = LOWER(LTRIM(RTRIM(ISNULL(@Unidad, 'meses'))));

    IF @Int <= 0 SET @Int = 1;

    IF @Uni IN ('dias', 'dia', 'days', 'day', 'diaria', 'daily')
        SET @Resultado = DATEADD(day, @Int, @FechaBase);
    ELSE IF @Uni IN ('semanas', 'semana', 'weeks', 'week', 'semanal', 'weekly')
        SET @Resultado = DATEADD(week, @Int, @FechaBase);
    ELSE IF @Uni IN ('meses', 'mes', 'months', 'month', 'mensual', 'monthly')
        SET @Resultado = DATEADD(month, @Int, @FechaBase);
    ELSE IF @Uni IN ('anios', 'anio', 'anos', 'ano', 'years', 'year', 'anual', 'annual')
        SET @Resultado = DATEADD(year, @Int, @FechaBase);
    ELSE IF @Uni IN ('bianual', 'biannual', '2anios', '2anos')
        SET @Resultado = DATEADD(year, @Int * 2, @FechaBase);
    ELSE
        SET @Resultado = DATEADD(month, @Int, @FechaBase);

    RETURN @Resultado;
END;
GO

-- ============================================================================
-- 2. Procedimiento Almacenado: uspPlanPreventivoCrear (Cabecera + Hijos JSON)
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoCrear
    @Title                  NVARCHAR(200) = NULL,
    @AssetCode              NVARCHAR(60),          -- Código del Equipo Padre
    @AssetName              NVARCHAR(200),
    @AreaId                 NVARCHAR(15)  = NULL,  -- NULL para planes transversales
    @AreaName               NVARCHAR(200) = NULL,
    @MaintenanceType        NVARCHAR(100),
    @Frequency              NVARCHAR(15)  = 'monthly',
    @IntervaloFrecuencia    INT           = 1,
    @UnidadFrecuencia       NVARCHAR(20)  = 'meses',
    @Description            NVARCHAR(MAX) = NULL,
    @EstimatedHours         DECIMAL(6,2)  = NULL,
    @StartDate              DATETIME2(3),
    @NextDate               DATETIME2(3)  = NULL,
    @LastCompleted          DATETIME2(3)  = NULL,
    @LastWorkOrderId        NVARCHAR(20)  = NULL,
    @Status                 NVARCHAR(10)  = 'active',
    @Notes                  NVARCHAR(500) = NULL,
    @CreatedByUserId        INT           = NULL,
    @CreatedByUserName      NVARCHAR(100) = N'',
    @Materials              dbo.TipoMaterialPreventivo READONLY,
    @ActividadesJson        NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validar que el equipo padre exista y no esté eliminado
        IF NOT EXISTS (SELECT 1 FROM dbo.Activo WHERE CodigoActivo = @AssetCode AND Estado <> 'deleted')
            RAISERROR('El equipo principal asignado al plan no existe o está eliminado.', 16, 1);

        -- 2. Generar correlativo PM-{Año}-{0001}
        DECLARE @cTable TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT deleted.SiguienteNumero INTO @cTable(v)
          WHERE Nombre = 'preventive_schedules';

        DECLARE @n INT; SELECT @n = v FROM @cTable;
        DECLARE @id NVARCHAR(20) = CONCAT('PM-', YEAR(SYSUTCDATETIME()), '-', FORMAT(@n, '0000'));
        DECLARE @FinalTitle NVARCHAR(200) =
            CASE WHEN LTRIM(ISNULL(@Title, N'')) = N'' THEN CONCAT(N'Plan Preventivo ', @id, N' - ', @AssetName) ELSE @Title END;

        IF @NextDate IS NULL
            SET @NextDate = dbo.fnCalcularProximaFechaPreventiva(@StartDate, @IntervaloFrecuencia, @UnidadFrecuencia);

        -- 3. Insertar Cabecera del Plan
        INSERT INTO dbo.PlanPreventivo
            (PlanId, Titulo, CodigoActivo, NombreActivo, AreaId, NombreArea, TipoMantenimiento, Frecuencia,
             IntervaloFrecuencia, UnidadFrecuencia, Descripcion, HorasEstimadas, FechaInicio, ProximaFecha,
             UltimaCompletada, UltimaOrdenTrabajoId, Estado, Notas, CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn)
        VALUES
            (@id, @FinalTitle, @AssetCode, @AssetName, @AreaId, @AreaName, @MaintenanceType, @Frequency,
             @IntervaloFrecuencia, @UnidadFrecuencia, @Description, @EstimatedHours, @StartDate, @NextDate,
             @LastCompleted, @LastWorkOrderId, @Status, @Notes, @CreatedByUserId, @CreatedByUserName, SYSUTCDATETIME());

        -- 4. Materiales directos de cabecera si existen
        INSERT INTO dbo.MaterialPreventivo (PlanId, NumeroLinea, Nombre, Cantidad, Unidad)
        SELECT @id, ROW_NUMBER() OVER (ORDER BY NumeroLinea), Nombre, Cantidad, ISNULL(Unidad, 'pza')
          FROM @Materials;

        -- 5. Procesar Actividades por Componente Hijo desde JSON
        IF @ActividadesJson IS NOT NULL AND ISJSON(@ActividadesJson) = 1
        BEGIN
            DECLARE @ActividadTemp TABLE (
                TempId               INT IDENTITY(1,1),
                CodigoActivoHijo     NVARCHAR(60) COLLATE database_default,
                NombreActivoHijo     NVARCHAR(200) COLLATE database_default,
                NivelActivoHijo      NVARCHAR(20) COLLATE database_default,
                DescripcionActividad NVARCHAR(300) COLLATE database_default,
                IntervaloFrecuencia  INT,
                UnidadFrecuencia     NVARCHAR(20) COLLATE database_default,
                HorasEstimadas       DECIMAL(5,2),
                FechaInicio          DATETIME2(3),
                ProximaFecha         DATETIME2(3),
                MaterialesJson       NVARCHAR(MAX) COLLATE database_default
            );

            INSERT INTO @ActividadTemp
            SELECT 
                JSON_VALUE(value, '$.codigoActivoHijo'),
                JSON_VALUE(value, '$.nombreActivoHijo'),
                ISNULL(JSON_VALUE(value, '$.nivelActivoHijo'), 'subEquipment'),
                JSON_VALUE(value, '$.descripcionActividad'),
                ISNULL(CAST(JSON_VALUE(value, '$.intervaloFrecuencia') AS INT), 1),
                ISNULL(JSON_VALUE(value, '$.unidadFrecuencia'), 'meses'),
                CAST(JSON_VALUE(value, '$.horasEstimadas') AS DECIMAL(5,2)),
                ISNULL(CAST(JSON_VALUE(value, '$.fechaInicio') AS DATETIME2(3)), @StartDate),
                ISNULL(CAST(JSON_VALUE(value, '$.proximaFecha') AS DATETIME2(3)), 
                       dbo.fnCalcularProximaFechaPreventiva(
                           ISNULL(CAST(JSON_VALUE(value, '$.fechaInicio') AS DATETIME2(3)), @StartDate),
                           ISNULL(CAST(JSON_VALUE(value, '$.intervaloFrecuencia') AS INT), 1),
                           ISNULL(JSON_VALUE(value, '$.unidadFrecuencia'), 'meses')
                       )),
                JSON_QUERY(value, '$.materiales')
            FROM OPENJSON(@ActividadesJson);

            DECLARE @tId INT, @actId BIGINT, @mJson NVARCHAR(MAX);
            DECLARE curAct CURSOR LOCAL FAST_FORWARD FOR
                SELECT TempId, MaterialesJson FROM @ActividadTemp;

            OPEN curAct;
            FETCH NEXT FROM curAct INTO @tId, @mJson;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO dbo.PlanPreventivoActividad
                    (PlanId, CodigoActivoHijo, NombreActivoHijo, NivelActivoHijo, DescripcionActividad,
                     IntervaloFrecuencia, UnidadFrecuencia, HorasEstimadas, FechaInicio, ProximaFecha, Estado)
                SELECT 
                    @id, CodigoActivoHijo, NombreActivoHijo, NivelActivoHijo, DescripcionActividad,
                    IntervaloFrecuencia, UnidadFrecuencia, HorasEstimadas, FechaInicio, ProximaFecha, 'active'
                FROM @ActividadTemp
                WHERE TempId = @tId;

                SET @actId = SCOPE_IDENTITY();

                IF @mJson IS NOT NULL AND ISJSON(@mJson) = 1
                BEGIN
                    INSERT INTO dbo.PlanPreventivoMaterial (ActividadId, NombreMaterial, Cantidad, Unidad)
                    SELECT 
                        @actId,
                        JSON_VALUE(value, '$.nombre'),
                        ISNULL(CAST(JSON_VALUE(value, '$.cantidad') AS DECIMAL(10,2)), 1),
                        ISNULL(JSON_VALUE(value, '$.unidad'), 'pza')
                    FROM OPENJSON(@mJson);
                END;

                FETCH NEXT FROM curAct INTO @tId, @mJson;
            END;

            CLOSE curAct;
            DEALLOCATE curAct;

            -- Ajustar ProximaFecha de la cabecera como el MIN de las actividades hijas
            DECLARE @minNextDate DATETIME2(3);
            SELECT @minNextDate = MIN(ProximaFecha) 
              FROM dbo.PlanPreventivoActividad 
             WHERE PlanId = @id AND Estado = 'active';

            IF @minNextDate IS NOT NULL
                UPDATE dbo.PlanPreventivo SET ProximaFecha = @minNextDate WHERE PlanId = @id;
        END;

        -- 6. Bitácora Kardex inmutable
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreatedByUserId, @CreatedByUserName, 'PREVENTIVE_SCHEDULE_CREATED', 'PREVENTIVE', @id,
                CONCAT(N'Plan preventivo ', @id, N' (', @FinalTitle, N') creado para ', @AssetCode, N'.'));

        COMMIT TRANSACTION;
        SELECT @id AS ScheduleNumber, @id AS NewScheduleId, @id AS PlanId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 3. Procedimiento Almacenado: uspGenerarOrdenTrabajoPreventivaMes (Idempotente)
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

        IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE CodigoActivo = @CodigoPadre AND EstadoCandado = 'pending')
            RAISERROR('El equipo principal tiene un trámite de baja pendiente. No se pueden emitir órdenes.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Activo WHERE CodigoActivo = @CodigoPadre AND Estado IN ('inactive', 'deleted', 'transferredDeactivated'))
            RAISERROR('El equipo principal se encuentra inactivo, dado de baja o traspasado.', 16, 1);

        -- 2. Idempotencia: Verificar si ya existe una OT abierta para este período
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
            SET @NuevaOrdenId = @OTExistente;
            COMMIT TRANSACTION;
            SELECT @NuevaOrdenId AS NewWorkOrderId, 1 AS WasExisting;
            RETURN;
        END;

        -- 3. Identificar actividades de componentes que vencen en el mes
        DECLARE @ActividadesMes TABLE (
            ActividadId BIGINT, CodigoHijo NVARCHAR(60) COLLATE database_default,
            NombreHijo NVARCHAR(200) COLLATE database_default,
            Tarea NVARCHAR(300) COLLATE database_default, Horas DECIMAL(5,2)
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

        -- Si ninguna tiene fecha específica del mes, tomar todas las actividades activas
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
-- 4. Procedimiento Almacenado: uspOrdenTrabajoActualizarEstado
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoActualizarEstado
    @WorkOrderId NVARCHAR(20),
    @NewStatus   NVARCHAR(15),
    @UserId      INT = NULL,
    @UserName    NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @cur NVARCHAR(15), @rid BIGINT, @desc NVARCHAR(MAX);
        SELECT @cur = Estado, @rid = ReporteId, @desc = Descripcion 
          FROM dbo.OrdenTrabajo WITH (UPDLOCK, HOLDLOCK)
         WHERE OrdenTrabajoId = @WorkOrderId;

        IF @cur IS NULL
            RAISERROR(N'La orden de trabajo no existe.', 16, 1);

        UPDATE dbo.OrdenTrabajo 
           SET Estado = @NewStatus 
         WHERE OrdenTrabajoId = @WorkOrderId;

        -- Sincronizar reporte de avería si nació de uno
        IF @NewStatus = 'completed' AND @rid IS NOT NULL
            UPDATE dbo.ReporteAveria 
               SET Estado = 'resolved', ResueltoPorUsuarioId = @UserId, 
                   ResueltoPorNombreUsuario = @UserName, ResueltoEn = SYSUTCDATETIME() 
             WHERE ReporteId = @rid;
        ELSE IF @NewStatus = 'cancelled' AND @rid IS NOT NULL
            UPDATE dbo.ReporteAveria 
               SET Estado = 'reported', OrdenTrabajoId = NULL 
             WHERE ReporteId = @rid;

        -- Sincronizar plan preventivo si fue una OT generada de un plan
        IF @NewStatus = 'completed'
        BEGIN
            UPDATE dbo.PlanPreventivo
               SET UltimaCompletada = SYSUTCDATETIME()
             WHERE UltimaOrdenTrabajoId = @WorkOrderId;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'WORK_ORDER_STATUS_CHANGED', 'WORK_ORDERS', @WorkOrderId,
                CONCAT(N'OT ', @WorkOrderId, N': estado "', @cur, N'" -> "', @NewStatus, N'".'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT 'Migración Fase 2 (Consolidación Total de Preventivos y OTs) ejecutada exitosamente.';
GO
