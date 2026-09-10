/* ============================================================================
   MACSA CMMS - Grupo Macsa
   database/migracion_ots_preventivas_consolidacion.sql
   Fase 5: Vinculación Formal Plan Preventivo <-> Orden de Trabajo (OT)
   Generación Estricta por Frecuencia/Periodo y Emisión Masiva
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Agregar columna PlanPreventivoId a dbo.OrdenTrabajo si no existe
IF NOT EXISTS (
    SELECT 1 FROM sys.columns 
    WHERE object_id = OBJECT_ID(N'dbo.OrdenTrabajo') 
      AND name = N'PlanPreventivoId'
)
BEGIN
    ALTER TABLE dbo.OrdenTrabajo 
    ADD PlanPreventivoId NVARCHAR(20) NULL;

    ALTER TABLE dbo.OrdenTrabajo 
    ADD CONSTRAINT FK_OT_PlanPreventivo 
    FOREIGN KEY (PlanPreventivoId) REFERENCES dbo.PlanPreventivo(PlanId);

    CREATE NONCLUSTERED INDEX IX_OT_PlanPreventivoId 
    ON dbo.OrdenTrabajo(PlanPreventivoId);
END;
GO

-- 2. Procedimiento Almacenado: uspGenerarOrdenTrabajoPreventivaMes
-- Genera una OT consolidada para el equipo principal, incluyendo ÚNICAMENTE
-- las actividades de componentes hijos cuya fecha programada caiga en el mes/año indicado.
CREATE OR ALTER PROCEDURE dbo.uspGenerarOrdenTrabajoPreventivaMes
    @PlanId             NVARCHAR(20),
    @Anio               INT,
    @Mes                INT,
    @CreadoPorUsuarioId INT = NULL,
    @CreadoPorNombre    NVARCHAR(100) = N'',
    @NuevaOrdenId       NVARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Obtener datos del Equipo Principal y Plan
        DECLARE @CodigoPadre NVARCHAR(60), 
                @NombrePadre NVARCHAR(200), 
                @AreaId NVARCHAR(15), 
                @NombreArea NVARCHAR(200),
                @EstadoPlan NVARCHAR(10);

        SELECT 
            @CodigoPadre = p.CodigoActivo,
            @NombrePadre = p.NombreActivo,
            @AreaId      = p.AreaId,
            @NombreArea  = p.NombreArea,
            @EstadoPlan  = p.Estado
        FROM dbo.PlanPreventivo p
        WHERE p.PlanId = @PlanId;

        IF @CodigoPadre IS NULL
        BEGIN
            RAISERROR('El plan preventivo no existe.', 16, 1);
        END;

        IF @EstadoPlan <> 'active'
        BEGIN
            RAISERROR('No se pueden generar Órdenes de Trabajo para un plan preventivo en estado inactivo o pausado.', 16, 1);
        END;

        -- 2. Identificar si ya existe una OT activa para este plan en el mes seleccionado (Idempotencia)
        DECLARE @OtExistente NVARCHAR(20);
        SELECT TOP 1 @OtExistente = OrdenTrabajoId
        FROM dbo.OrdenTrabajo
        WHERE PlanPreventivoId = @PlanId
          AND YEAR(FechaProgramada) = @Anio
          AND MONTH(FechaProgramada) = @Mes
          AND Estado IN ('pending', 'inProgress');

        IF @OtExistente IS NOT NULL
        BEGIN
            SET @NuevaOrdenId = @OtExistente;
            COMMIT TRANSACTION;
            IF @@NESTLEVEL <= 1
            BEGIN
                SELECT @NuevaOrdenId AS NewWorkOrderId, CAST(1 AS BIT) AS YaExistia;
            END;
            RETURN;
        END;

        -- 3. Identificar actividades que vencen estrictamente en el mes/año seleccionado
        DECLARE @ActividadesMes TABLE (
            ActividadId BIGINT,
            CodigoHijo  NVARCHAR(60),
            NombreHijo  NVARCHAR(200),
            Tarea       NVARCHAR(300),
            Horas       DECIMAL(5,2),
            ProximaFecha DATETIME2(3)
        );

        INSERT INTO @ActividadesMes
        SELECT ActividadId, CodigoActivoHijo, NombreActivoHijo, DescripcionActividad, HorasEstimadas, ProximaFecha
        FROM dbo.PlanPreventivoActividad
        WHERE PlanId = @PlanId
          AND Estado = 'active'
          AND YEAR(ProximaFecha) = @Anio
          AND MONTH(ProximaFecha) = @Mes;

        -- Regla de negocio estricta: Si no hay actividades en este mes, NO se genera la OT
        IF NOT EXISTS (SELECT 1 FROM @ActividadesMes)
        BEGIN
            -- Verificar si el plan no tiene actividades hijas registradas y la cabecera vence en este mes
            IF NOT EXISTS (SELECT 1 FROM dbo.PlanPreventivoActividad WHERE PlanId = @PlanId AND Estado = 'active')
            BEGIN
                DECLARE @NextDateCabecera DATETIME2(3), @DescCabecera NVARCHAR(MAX);
                SELECT @NextDateCabecera = ProximaFecha, @DescCabecera = Descripcion
                FROM dbo.PlanPreventivo
                WHERE PlanId = @PlanId;

                IF YEAR(@NextDateCabecera) <> @Anio OR MONTH(@NextDateCabecera) <> @Mes
                BEGIN
                    RAISERROR('El plan preventivo no tiene tareas programadas para el periodo seleccionado.', 16, 1);
                END;
            END
            ELSE
            BEGIN
                RAISERROR('El plan preventivo no tiene actividades de componentes que venzan en el mes seleccionado.', 16, 1);
            END;
        END;

        -- 4. Generar número correlativo de OT: OT-{Año}-{0001}
        DECLARE @cTable TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT deleted.SiguienteNumero INTO @cTable(v)
          WHERE Nombre = 'work_orders';

        DECLARE @n INT; SELECT @n = v FROM @cTable;
        SET @NuevaOrdenId = CONCAT('OT-', @Anio, '-', FORMAT(@n, '0000'));

        -- 5. Construir descripción consolidada para el equipo principal
        DECLARE @DescripcionConsolidada NVARCHAR(MAX) = 
            CONCAT(N'Mantenimiento Preventivo Programado (Plan ', @PlanId, N') - ', @NombrePadre, CHAR(13), CHAR(10),
                   N'Periodo: ', FORMAT(DATEFROMPARTS(@Anio, @Mes, 1), 'MMMM yyyy', 'es-ES'), CHAR(13), CHAR(10),
                   N'Actividades en Componentes:', CHAR(13), CHAR(10));

        IF EXISTS (SELECT 1 FROM @ActividadesMes)
        BEGIN
            SELECT @DescripcionConsolidada += CONCAT(N' - [', CodigoHijo, N' - ', NombreHijo, N']: ', Tarea, 
                N' (Prog: ', FORMAT(ProximaFecha, 'dd/MM/yyyy'), N')', CHAR(13), CHAR(10))
            FROM @ActividadesMes;
        END
        ELSE
        BEGIN
            SELECT @DescripcionConsolidada += CONCAT(N' - Mantenimiento General de Equipo: ', ISNULL(p.Descripcion, p.TipoMantenimiento), CHAR(13), CHAR(10))
            FROM dbo.PlanPreventivo p WHERE p.PlanId = @PlanId;
        END;

        -- 6. Insertar la Orden de Trabajo dirigida al Equipo Padre con PlanPreventivoId
        INSERT INTO dbo.OrdenTrabajo (
            OrdenTrabajoId, CodigoActivo, NombreActivo, AreaId, NombreArea,
            Descripcion, Estado, Prioridad, CreadoPorUsuarioId, CreadoPorNombreUsuario,
            FechaProgramada, PlanPreventivoId, CreadoEn
        )
        VALUES (
            @NuevaOrdenId, @CodigoPadre, @NombrePadre, @AreaId, @NombreArea,
            @DescripcionConsolidada, 'pending', 'medium', @CreadoPorUsuarioId, @CreadoPorNombre,
            DATEFROMPARTS(@Anio, @Mes, 1), @PlanId, SYSUTCDATETIME()
        );

        -- Registrar tipos de trabajo 'preventive' y 'scheduled'
        INSERT INTO dbo.TipoTrabajoOrdenTrabajo (OrdenTrabajoId, TipoTrabajo)
        VALUES (@NuevaOrdenId, 'preventive'), (@NuevaOrdenId, 'scheduled');

        -- 7. Consolidar materiales de las actividades que SÍ corresponden al mes
        IF EXISTS (SELECT 1 FROM @ActividadesMes)
        BEGIN
            INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
            SELECT 
                @NuevaOrdenId,
                ROW_NUMBER() OVER (ORDER BY m.MaterialId),
                CONCAT(m.NombreMaterial, N' (para ', act.NombreHijo, N')'),
                m.Cantidad,
                m.Unidad
            FROM dbo.PlanPreventivoMaterial m
            INNER JOIN @ActividadesMes act ON act.ActividadId = m.ActividadId;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
            SELECT 
                @NuevaOrdenId,
                NumeroLinea,
                Nombre,
                Cantidad,
                Unidad
            FROM dbo.MaterialPreventivo
            WHERE PlanId = @PlanId;
        END;

        -- 8. Actualizar el plan preventivo con la última OT generada
        UPDATE dbo.PlanPreventivo
           SET UltimaOrdenTrabajoId = @NuevaOrdenId
         WHERE PlanId = @PlanId;

        -- 9. Bitácora Kardex
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreadoPorUsuarioId, @CreadoPorNombre, 'WORK_ORDER_CREATED', 'WORK_ORDERS', @NuevaOrdenId,
                CONCAT(N'OT preventiva consolidada ', @NuevaOrdenId, N' generada para ', @CodigoPadre, N' (Plan ', @PlanId, N', Periodo: ', @Mes, N'/', @Anio, N')'));

        COMMIT TRANSACTION;
        IF @@NESTLEVEL <= 1
        BEGIN
            SELECT @NuevaOrdenId AS NewWorkOrderId, CAST(0 AS BIT) AS YaExistia;
        END;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 3. Procedimiento Almacenado: uspGenerarOrdenesTrabajoPreventivasMasivas
-- Evalúa todos los planes activos (opcionalmente filtrados por área) y genera
-- una OT para cada equipo que tenga actividades venciendo en el periodo.
CREATE OR ALTER PROCEDURE dbo.uspGenerarOrdenesTrabajoPreventivasMasivas
    @Anio               INT,
    @Mes                INT,
    @AreaId             NVARCHAR(15) = NULL,
    @CreadoPorUsuarioId INT = NULL,
    @CreadoPorNombre    NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PlanesElegibles TABLE (PlanId NVARCHAR(20));

    -- Encontrar planes activos con actividades en ese mes
    INSERT INTO @PlanesElegibles (PlanId)
    SELECT DISTINCT p.PlanId
    FROM dbo.PlanPreventivo p
    INNER JOIN dbo.PlanPreventivoActividad ppa ON ppa.PlanId = p.PlanId
    WHERE p.Estado = 'active'
      AND ppa.Estado = 'active'
      AND YEAR(ppa.ProximaFecha) = @Anio
      AND MONTH(ppa.ProximaFecha) = @Mes
      AND (@AreaId IS NULL OR p.AreaId = @AreaId);

    -- También planes sin sub-actividades cuya cabecera venza en ese mes
    INSERT INTO @PlanesElegibles (PlanId)
    SELECT p.PlanId
    FROM dbo.PlanPreventivo p
    WHERE p.Estado = 'active'
      AND (@AreaId IS NULL OR p.AreaId = @AreaId)
      AND YEAR(p.ProximaFecha) = @Anio
      AND MONTH(p.ProximaFecha) = @Mes
      AND NOT EXISTS (SELECT 1 FROM dbo.PlanPreventivoActividad WHERE PlanId = p.PlanId)
      AND p.PlanId NOT IN (SELECT PlanId FROM @PlanesElegibles);

    DECLARE @Resultados TABLE (
        PlanId NVARCHAR(20),
        WorkOrderId NVARCHAR(20),
        Exitoso BIT,
        Mensaje NVARCHAR(500)
    );

    DECLARE @CurrentPlanId NVARCHAR(20);
    DECLARE plan_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT PlanId FROM @PlanesElegibles;

    OPEN plan_cursor;
    FETCH NEXT FROM plan_cursor INTO @CurrentPlanId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @NuevaOT NVARCHAR(20) = NULL;
        BEGIN TRY
            EXEC dbo.uspGenerarOrdenTrabajoPreventivaMes
                @PlanId = @CurrentPlanId,
                @Anio = @Anio,
                @Mes = @Mes,
                @CreadoPorUsuarioId = @CreadoPorUsuarioId,
                @CreadoPorNombre = @CreadoPorNombre,
                @NuevaOrdenId = @NuevaOT OUTPUT;

            INSERT INTO @Resultados (PlanId, WorkOrderId, Exitoso, Mensaje)
            VALUES (@CurrentPlanId, @NuevaOT, 1, N'Orden procesada correctamente');
        END TRY
        BEGIN CATCH
            INSERT INTO @Resultados (PlanId, WorkOrderId, Exitoso, Mensaje)
            VALUES (@CurrentPlanId, NULL, 0, ERROR_MESSAGE());
        END CATCH;

        FETCH NEXT FROM plan_cursor INTO @CurrentPlanId;
    END;

    CLOSE plan_cursor;
    DEALLOCATE plan_cursor;

    SELECT * FROM @Resultados;
END;
GO

PRINT N'Migración de OTs Preventivas y Consolidación por Periodo creada exitosamente.';
GO
