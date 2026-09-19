-- ============================================================================
-- FIX ALL MOJIBAKE AND ENCODING ARTIFACTS IN DATABASE
-- ============================================================================
USE MacsaCMMS;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Limpiar OrdenTrabajo.Descripcion (reemplazar asteriscos y mojibake con '-')
UPDATE dbo.OrdenTrabajo
   SET Descripcion = REPLACE(
                        REPLACE(
                           REPLACE(
                              REPLACE(
                                 REPLACE(
                                    REPLACE(
                                       REPLACE(
                                          REPLACE(
                                             REPLACE(Descripcion, N'â€¢', N'- '),
                                          NCHAR(226) + NCHAR(8364) + NCHAR(162), N'- '),
                                       NCHAR(226) + NCHAR(128) + NCHAR(162), N'- '),
                                    N'â€”', N' - '),
                                 N'â€“', N' - '),
                              N'•', N'- '),
                           N'* ', N'- '),
                        N'â€', N''),
                     N'  ', N' ')
 WHERE Descripcion IS NOT NULL;
GO

-- 2. Limpiar PlanPreventivoActividad.DescripcionActividad
UPDATE dbo.PlanPreventivoActividad
   SET DescripcionActividad = REPLACE(
                                 REPLACE(
                                    REPLACE(
                                       REPLACE(
                                          REPLACE(DescripcionActividad, N'â€¢', N'- '),
                                       NCHAR(226) + NCHAR(8364) + NCHAR(162), N'- '),
                                    NCHAR(226) + NCHAR(128) + NCHAR(162), N'- '),
                                 N'•', N'- '),
                              N'* ', N'- ')
 WHERE DescripcionActividad IS NOT NULL;
GO

-- 3. Limpiar PlanPreventivo.Descripcion
UPDATE dbo.PlanPreventivo
   SET Descripcion = REPLACE(
                        REPLACE(
                           REPLACE(
                              REPLACE(
                                 REPLACE(Descripcion, N'â€¢', N'- '),
                              NCHAR(226) + NCHAR(8364) + NCHAR(162), N'- '),
                           NCHAR(226) + NCHAR(128) + NCHAR(162), N'- '),
                        N'•', N'- '),
                     N'* ', N'- ')
 WHERE Descripcion IS NOT NULL;
GO

-- 4. Asegurar que uspGenerarOrdenTrabajoPreventivaMes use estrictamente ASCII estándar
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

        -- 5. Construir descripción consolidada limpia y legible (sin bullets multi-byte)
        DECLARE @NombreMes NVARCHAR(30) = FORMAT(DATEFROMPARTS(@Anio, @Mes, 1), 'MMMM yyyy', 'es-ES');
        DECLARE @Desc NVARCHAR(MAX) =
            CONCAT(N'Mantenimiento Preventivo Programado (Plan ', @PlanId, N') - ', @NombrePadre, CHAR(13), CHAR(10),
                   N'Periodo: ', UPPER(LEFT(@NombreMes, 1)) + SUBSTRING(@NombreMes, 2, LEN(@NombreMes)), CHAR(13), CHAR(10),
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

        COMMIT TRANSACTION;

        SELECT @NuevaOrdenId AS NewWorkOrderId, 0 AS WasExisting;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

GRANT EXECUTE ON dbo.uspGenerarOrdenTrabajoPreventivaMes TO macsa_app;
GO
