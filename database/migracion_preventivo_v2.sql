/* ============================================================================
   MACSA CMMS - Grupo Macsa
   migracion_preventivo_v2.sql
   Correcciones al Mantenimiento Preventivo Jerárquico:
   - uspPlanPreventivoRegistrarEjecucion avanza ProximaFecha de hijos
   - uspGenerarOrdenTrabajoPreventivaMes avanza ProximaFecha de hijos
   - AreaId nullable para planes transversales
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ============================================================================
-- 1. Permitir AreaId nullable en PlanPreventivo para planes transversales
-- ============================================================================
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.PlanPreventivo') AND name = N'AreaId' AND is_nullable = 0)
BEGIN
    ALTER TABLE dbo.PlanPreventivo ALTER COLUMN AreaId NVARCHAR(15) NULL;
    ALTER TABLE dbo.PlanPreventivo ALTER COLUMN NombreArea NVARCHAR(200) NULL;
    PRINT 'AreaId y NombreArea ahora permiten NULL en PlanPreventivo.';
END;
GO

-- ============================================================================
-- 2. Actualizar uspPlanPreventivoRegistrarEjecucion
--    Ahora avanza ProximaFecha de las actividades hijas involucradas
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoRegistrarEjecucion
    @ScheduleId NVARCHAR(20),
    @WorkOrderId NVARCHAR(20),
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @freq NVARCHAR(15);
        SELECT @freq = Frecuencia FROM dbo.PlanPreventivo WHERE PlanId = @ScheduleId;

        IF @freq IS NULL
        BEGIN
            IF @@TRANCOUNT > 0 ROLLBACK;
            RETURN;
        END;

        -- Avanzar ProximaFecha de cada actividad hija activa
        UPDATE ppa
           SET ProximaFecha = dbo.fnCalcularProximaFechaPreventiva(
                   ppa.ProximaFecha, ppa.IntervaloFrecuencia, ppa.UnidadFrecuencia),
               FechaUltimaEjecucion = SYSUTCDATETIME()
          FROM dbo.PlanPreventivoActividad ppa
         WHERE ppa.PlanId = @ScheduleId
           AND ppa.Estado = 'active';

        -- Recalcular ProximaFecha de la cabecera como el MIN de las actividades hijas
        DECLARE @minNext DATETIME2(3);
        SELECT @minNext = MIN(ProximaFecha)
          FROM dbo.PlanPreventivoActividad
         WHERE PlanId = @ScheduleId AND Estado = 'active';

        -- Si no hay actividades hijas, usar la frecuencia global de la cabecera
        IF @minNext IS NULL
        BEGIN
            DECLARE @interval INT, @unit NVARCHAR(20);
            SELECT @interval = ISNULL(IntervaloFrecuencia, 1),
                   @unit = ISNULL(UnidadFrecuencia, 'meses')
              FROM dbo.PlanPreventivo
             WHERE PlanId = @ScheduleId;

            SET @minNext = dbo.fnCalcularProximaFechaPreventiva(
                SYSUTCDATETIME(), @interval, @unit);
        END;

        UPDATE dbo.PlanPreventivo
           SET UltimaCompletada = SYSUTCDATETIME(),
               UltimaOrdenTrabajoId = @WorkOrderId,
               ProximaFecha = @minNext
         WHERE PlanId = @ScheduleId;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'PREVENTIVE_SCHEDULE_UPDATED', 'PREVENTIVE', @ScheduleId,
                CONCAT(N'Plan preventivo ', @ScheduleId, N' ejecutado mediante OT ', @WorkOrderId,
                       N'. Próxima fecha recalculada: ', CONVERT(NVARCHAR(20), @minNext, 23), N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 3. Actualizar uspGenerarOrdenTrabajoPreventivaMes
--    Ahora avanza ProximaFecha de las actividades hijas involucradas
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

        DECLARE @CodigoPadre NVARCHAR(60), @NombrePadre NVARCHAR(200),
                @AreaId NVARCHAR(15), @NombreArea NVARCHAR(200);
        SELECT
            @CodigoPadre = p.CodigoActivo,
            @NombrePadre = p.NombreActivo,
            @AreaId      = p.AreaId,
            @NombreArea  = p.NombreArea
        FROM dbo.PlanPreventivo p
        WHERE p.PlanId = @PlanId;

        IF @CodigoPadre IS NULL
            RAISERROR('El plan preventivo no existe.', 16, 1);

        DECLARE @ActividadesMes TABLE (
            ActividadId BIGINT, CodigoHijo NVARCHAR(60), NombreHijo NVARCHAR(200),
            Tarea NVARCHAR(300), Horas DECIMAL(5,2)
        );

        INSERT INTO @ActividadesMes
        SELECT ActividadId, CodigoActivoHijo, NombreActivoHijo, DescripcionActividad, HorasEstimadas
        FROM dbo.PlanPreventivoActividad
        WHERE PlanId = @PlanId AND Estado = 'active'
          AND YEAR(ProximaFecha) = @Anio AND MONTH(ProximaFecha) = @Mes;

        IF NOT EXISTS (SELECT 1 FROM @ActividadesMes)
        BEGIN
            INSERT INTO @ActividadesMes
            SELECT ActividadId, CodigoActivoHijo, NombreActivoHijo, DescripcionActividad, HorasEstimadas
            FROM dbo.PlanPreventivoActividad
            WHERE PlanId = @PlanId AND Estado = 'active';
        END;

        DECLARE @cTable TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT deleted.SiguienteNumero INTO @cTable(v)
          WHERE Nombre = 'work_orders';

        DECLARE @n INT; SELECT @n = v FROM @cTable;
        SET @NuevaOrdenId = CONCAT('OT-', @Anio, '-', FORMAT(@n, '0000'));

        DECLARE @Desc NVARCHAR(MAX) =
            CONCAT(N'Mantenimiento Preventivo Programado (Plan ', @PlanId, N') - ', @NombrePadre, CHAR(13), CHAR(10),
                   N'Período: ', FORMAT(DATEFROMPARTS(@Anio, @Mes, 1), 'MMMM yyyy', 'es-ES'), CHAR(13), CHAR(10),
                   N'Actividades en Componentes:', CHAR(13), CHAR(10));

        SELECT @Desc += CONCAT(N' • [', CodigoHijo, N' - ', NombreHijo, N']: ', Tarea, CHAR(13), CHAR(10))
        FROM @ActividadesMes;

        INSERT INTO dbo.OrdenTrabajo (
            OrdenTrabajoId, CodigoActivo, NombreActivo, AreaId, NombreArea,
            Descripcion, Estado, Prioridad, CreadoPorUsuarioId, CreadoPorNombreUsuario,
            FechaProgramada, CreadoEn)
        VALUES (
            @NuevaOrdenId, @CodigoPadre, @NombrePadre, @AreaId, @NombreArea,
            @Desc, 'pending', 'medium', @CreadoPorUsuarioId, @CreadoPorNombre,
            DATEFROMPARTS(@Anio, @Mes, 1), SYSUTCDATETIME());

        INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
        SELECT @NuevaOrdenId, ROW_NUMBER() OVER (ORDER BY m.MaterialId),
               CONCAT(m.NombreMaterial, N' (para ', act.NombreHijo, N')'), m.Cantidad, m.Unidad
        FROM dbo.PlanPreventivoMaterial m
        INNER JOIN @ActividadesMes act ON act.ActividadId = m.ActividadId;

        -- *** Avanzar ProximaFecha de las actividades hijas involucradas ***
        UPDATE ppa
           SET ProximaFecha = dbo.fnCalcularProximaFechaPreventiva(
                   ppa.ProximaFecha, ppa.IntervaloFrecuencia, ppa.UnidadFrecuencia),
               FechaUltimaEjecucion = SYSUTCDATETIME()
          FROM dbo.PlanPreventivoActividad ppa
         INNER JOIN @ActividadesMes am ON am.ActividadId = ppa.ActividadId;

        -- Recalcular cabecera
        DECLARE @minNextDate DATETIME2(3);
        SELECT @minNextDate = MIN(ProximaFecha)
          FROM dbo.PlanPreventivoActividad
         WHERE PlanId = @PlanId AND Estado = 'active';

        UPDATE dbo.PlanPreventivo
           SET UltimaOrdenTrabajoId = @NuevaOrdenId,
               UltimaCompletada = SYSUTCDATETIME(),
               ProximaFecha = ISNULL(@minNextDate, ProximaFecha)
         WHERE PlanId = @PlanId;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreadoPorUsuarioId, @CreadoPorNombre, 'WORK_ORDER_CREATED', 'WORK_ORDERS', @NuevaOrdenId,
                CONCAT(N'OT preventiva consolidada ', @NuevaOrdenId, N' generada para ', @CodigoPadre, N' (Plan ', @PlanId, N').'));

        COMMIT TRANSACTION;
        SELECT @NuevaOrdenId AS NewWorkOrderId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 4. Actualizar uspPlanPreventivoCrear para permitir AreaId NULL
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoCrear
    @Title                  NVARCHAR(200) = NULL,
    @AssetCode              NVARCHAR(60),
    @AssetName              NVARCHAR(200),
    @AreaId                 NVARCHAR(15)  = NULL,
    @AreaName               NVARCHAR(200) = NULL,
    @MaintenanceType        NVARCHAR(100),
    @Frequency              NVARCHAR(15)  = 'monthly',
    @IntervaloFrecuencia    INT           = 1,
    @UnidadFrecuencia       NVARCHAR(20)  = 'meses',
    @Description            NVARCHAR(MAX) = NULL,
    @EstimatedHours         DECIMAL(6,2)  = NULL,
    @StartDate              DATETIME2(3),
    @NextDate               DATETIME2(3),
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

        DECLARE @cTable TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT deleted.SiguienteNumero INTO @cTable(v)
          WHERE Nombre = 'preventive_schedules';

        DECLARE @n INT; SELECT @n = v FROM @cTable;
        DECLARE @id NVARCHAR(20) = CONCAT('PM-', YEAR(SYSUTCDATETIME()), '-', FORMAT(@n, '0000'));
        DECLARE @FinalTitle NVARCHAR(200) =
            CASE WHEN LTRIM(ISNULL(@Title, N'')) = N'' THEN CONCAT(N'Plan Preventivo ', @id) ELSE @Title END;

        IF @NextDate IS NULL
            SET @NextDate = dbo.fnCalcularProximaFechaPreventiva(@StartDate, @IntervaloFrecuencia, @UnidadFrecuencia);

        INSERT INTO dbo.PlanPreventivo
            (PlanId, Titulo, CodigoActivo, NombreActivo, AreaId, NombreArea, TipoMantenimiento, Frecuencia,
             IntervaloFrecuencia, UnidadFrecuencia, Descripcion, HorasEstimadas, FechaInicio, ProximaFecha,
             UltimaCompletada, UltimaOrdenTrabajoId, Estado, Notas, CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn)
        VALUES
            (@id, @FinalTitle, @AssetCode, @AssetName, @AreaId, @AreaName, @MaintenanceType, @Frequency,
             @IntervaloFrecuencia, @UnidadFrecuencia, @Description, @EstimatedHours, @StartDate, @NextDate,
             @LastCompleted, @LastWorkOrderId, @Status, @Notes, @CreatedByUserId, @CreatedByUserName, SYSUTCDATETIME());

        INSERT INTO dbo.MaterialPreventivo (PlanId, NumeroLinea, Nombre, Cantidad, Unidad)
        SELECT @id, ROW_NUMBER() OVER (ORDER BY NumeroLinea), Nombre, Cantidad, ISNULL(Unidad, 'pza')
          FROM @Materials;

        IF @ActividadesJson IS NOT NULL AND ISJSON(@ActividadesJson) = 1
        BEGIN
            DECLARE @ActividadTemp TABLE (
                TempId INT IDENTITY(1,1), CodigoActivoHijo NVARCHAR(60), NombreActivoHijo NVARCHAR(200),
                NivelActivoHijo NVARCHAR(20), DescripcionActividad NVARCHAR(300),
                IntervaloFrecuencia INT, UnidadFrecuencia NVARCHAR(20), HorasEstimadas DECIMAL(5,2),
                FechaInicio DATETIME2(3), ProximaFecha DATETIME2(3), MaterialesJson NVARCHAR(MAX)
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
                SELECT @id, CodigoActivoHijo, NombreActivoHijo, NivelActivoHijo, DescripcionActividad,
                    IntervaloFrecuencia, UnidadFrecuencia, HorasEstimadas, FechaInicio, ProximaFecha, 'active'
                FROM @ActividadTemp WHERE TempId = @tId;

                SET @actId = SCOPE_IDENTITY();

                IF @mJson IS NOT NULL AND ISJSON(@mJson) = 1
                    INSERT INTO dbo.PlanPreventivoMaterial (ActividadId, NombreMaterial, Cantidad, Unidad)
                    SELECT @actId, JSON_VALUE(value, '$.nombre'),
                           ISNULL(CAST(JSON_VALUE(value, '$.cantidad') AS DECIMAL(10,2)), 1),
                           ISNULL(JSON_VALUE(value, '$.unidad'), 'pza')
                    FROM OPENJSON(@mJson);

                FETCH NEXT FROM curAct INTO @tId, @mJson;
            END;
            CLOSE curAct;
            DEALLOCATE curAct;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreatedByUserId, @CreatedByUserName, 'PREVENTIVE_SCHEDULE_CREATED', 'PREVENTIVE', @id,
                CONCAT(N'Plan preventivo ', @id, N' creado para ', @AssetCode, N' - ', @AssetName, N'.'));

        COMMIT TRANSACTION;
        SELECT @id AS NewScheduleId, @id AS PlanId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT 'Migración Preventivo v2 ejecutada exitosamente.';
GO
