/* ============================================================================
   MACSA CMMS - Grupo Macsa
   database/migracion_plan_preventivo_unico_por_equipo.sql
   Restricción de Negocio: Un solo Plan Preventivo por Equipo Principal.
   Modificaciones mediante Edición con Autorización Gerencial.
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- 0. Permitir 'deleted' en el CHECK constraint de Estado de PlanPreventivo si no está incluido
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_PP_Estado' AND parent_object_id = OBJECT_ID('dbo.PlanPreventivo'))
BEGIN
    ALTER TABLE dbo.PlanPreventivo DROP CONSTRAINT CK_PP_Estado;
END;
ALTER TABLE dbo.PlanPreventivo 
ADD CONSTRAINT CK_PP_Estado CHECK (Estado IN ('active', 'paused', 'completed', 'deleted'));
GO

-- 1. Limpieza de planes duplicados existentes en datos de prueba:
-- Para cada equipo con más de 1 plan no eliminado, conservar el plan con más actividades o más reciente,
-- y marcar los duplicados anteriores como 'deleted'.
WITH PlanesNumerados AS (
    SELECT 
        p.PlanId,
        p.CodigoActivo,
        p.Estado,
        p.CreadoEn,
        COUNT(ppa.ActividadId) AS TotalActividades,
        ROW_NUMBER() OVER (
            PARTITION BY p.CodigoActivo 
            ORDER BY 
                CASE WHEN p.Estado = 'active' THEN 1 ELSE 2 END,
                COUNT(ppa.ActividadId) DESC, 
                p.CreadoEn DESC
        ) AS Fila
    FROM dbo.PlanPreventivo p
    LEFT JOIN dbo.PlanPreventivoActividad ppa ON ppa.PlanId = p.PlanId
    WHERE p.Estado <> 'deleted'
    GROUP BY p.PlanId, p.CodigoActivo, p.Estado, p.CreadoEn
)
UPDATE p
   SET p.Estado = 'deleted',
       p.Notas = CONCAT(ISNULL(p.Notas, N''), N' [Depurado por duplicidad de plan para el mismo equipo]')
  FROM dbo.PlanPreventivo p
  INNER JOIN PlanesNumerados pn ON pn.PlanId = p.PlanId
 WHERE pn.Fila > 1;
GO

-- 2. Índice Único Filtrado para garantizar la integridad a nivel motor de base de datos
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_PlanPreventivo_CodigoActivo' AND object_id = OBJECT_ID('dbo.PlanPreventivo'))
BEGIN
    DROP INDEX UX_PlanPreventivo_CodigoActivo ON dbo.PlanPreventivo;
END;
GO

CREATE UNIQUE NONCLUSTERED INDEX UX_PlanPreventivo_CodigoActivo
ON dbo.PlanPreventivo(CodigoActivo)
WHERE Estado <> 'deleted';
GO

-- 3. Actualizar procedimiento dbo.uspPlanPreventivoCrear con validación explícita
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
        BEGIN
            RAISERROR('El equipo principal asignado al plan no existe o está eliminado.', 16, 1);
        END;

        -- 2. Validar que el equipo NO tenga ya un plan preventivo activo o registrado
        IF EXISTS (
            SELECT 1 
            FROM dbo.PlanPreventivo 
            WHERE CodigoActivo = @AssetCode 
              AND Estado <> 'deleted'
        )
        BEGIN
            DECLARE @ExistingPlanId NVARCHAR(20);
            SELECT TOP 1 @ExistingPlanId = PlanId
            FROM dbo.PlanPreventivo
            WHERE CodigoActivo = @AssetCode AND Estado <> 'deleted';

            RAISERROR('El equipo %s ya cuenta con el Plan de Mantenimiento Preventivo %s. No se permite crear múltiples planes para un mismo equipo; utilice la opción de editar plan con autorización gerencial.', 16, 1, @AssetCode, @ExistingPlanId);
        END;

        -- 3. Generar correlativo PM-{Año}-{0001}
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

        -- 4. Insertar Cabecera del Plan
        INSERT INTO dbo.PlanPreventivo
            (PlanId, Titulo, CodigoActivo, NombreActivo, AreaId, NombreArea, TipoMantenimiento, Frecuencia,
             IntervaloFrecuencia, UnidadFrecuencia, Descripcion, HorasEstimadas, FechaInicio, ProximaFecha,
             UltimaCompletada, UltimaOrdenTrabajoId, Estado, Notas, CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn)
        VALUES
            (@id, @FinalTitle, @AssetCode, @AssetName, @AreaId, @AreaName, @MaintenanceType, @Frequency,
             @IntervaloFrecuencia, @UnidadFrecuencia, @Description, @EstimatedHours, @StartDate, @NextDate,
             @LastCompleted, @LastWorkOrderId, @Status, @Notes, @CreatedByUserId, @CreatedByUserName, SYSUTCDATETIME());

        -- 5. Materiales directos de cabecera si existen
        INSERT INTO dbo.MaterialPreventivo (PlanId, NumeroLinea, Nombre, Cantidad, Unidad)
        SELECT @id, ROW_NUMBER() OVER (ORDER BY NumeroLinea), Nombre, Cantidad, ISNULL(Unidad, 'pza')
          FROM @Materials;

        -- 6. Procesar Actividades por Componente Hijo desde JSON
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
                ISNULL(JSON_VALUE(value, '$.nivelActivoHijo'), 'part'),
                JSON_VALUE(value, '$.descripcionActividad'),
                CAST(ISNULL(JSON_VALUE(value, '$.intervaloFrecuencia'), '1') AS INT),
                ISNULL(JSON_VALUE(value, '$.unidadFrecuencia'), 'meses'),
                CAST(ISNULL(JSON_VALUE(value, '$.horasEstimadas'), '1.0') AS DECIMAL(5,2)),
                CAST(ISNULL(JSON_VALUE(value, '$.fechaInicio'), CONVERT(NVARCHAR(30), @StartDate, 126)) AS DATETIME2(3)),
                CAST(ISNULL(JSON_VALUE(value, '$.proximaFecha'), CONVERT(NVARCHAR(30), @NextDate, 126)) AS DATETIME2(3)),
                JSON_QUERY(value, '$.materiales')
            FROM OPENJSON(@ActividadesJson);

            -- Insertar actividades en dbo.PlanPreventivoActividad
            DECLARE @IdMapping TABLE (TempId INT, ActividadId BIGINT);

            MERGE dbo.PlanPreventivoActividad AS TARGET
            USING (
                SELECT 
                    TempId, CodigoActivoHijo, NombreActivoHijo, NivelActivoHijo,
                    DescripcionActividad, IntervaloFrecuencia, UnidadFrecuencia,
                    HorasEstimadas, FechaInicio, ProximaFecha
                FROM @ActividadTemp
            ) AS SOURCE
            ON 1 = 0
            WHEN NOT MATCHED THEN
                INSERT (PlanId, CodigoActivoHijo, NombreActivoHijo, NivelActivoHijo,
                        DescripcionActividad, IntervaloFrecuencia, UnidadFrecuencia,
                        HorasEstimadas, FechaInicio, ProximaFecha, Estado, CreadoEn)
                VALUES (@id, SOURCE.CodigoActivoHijo, SOURCE.NombreActivoHijo, SOURCE.NivelActivoHijo,
                        SOURCE.DescripcionActividad, SOURCE.IntervaloFrecuencia, SOURCE.UnidadFrecuencia,
                        SOURCE.HorasEstimadas, SOURCE.FechaInicio, SOURCE.ProximaFecha, 'active', SYSUTCDATETIME())
            OUTPUT SOURCE.TempId, INSERTED.ActividadId INTO @IdMapping (TempId, ActividadId);

            -- Insertar materiales asociados a cada actividad
            INSERT INTO dbo.PlanPreventivoMaterial (ActividadId, NombreMaterial, Cantidad, Unidad)
            SELECT 
                m.ActividadId,
                JSON_VALUE(mat.value, '$.name'),
                CAST(ISNULL(JSON_VALUE(mat.value, '$.quantity'), '1') AS DECIMAL(10,2)),
                ISNULL(JSON_VALUE(mat.value, '$.unit'), 'pza')
            FROM @ActividadTemp t
            INNER JOIN @IdMapping m ON m.TempId = t.TempId
            CROSS APPLY OPENJSON(t.MaterialesJson) AS mat
            WHERE t.MaterialesJson IS NOT NULL AND ISJSON(t.MaterialesJson) = 1;
        END;

        -- 7. Registrar evento en Kardex
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreatedByUserId, @CreatedByUserName, 'PREVENTIVE_PLAN_CREATED', 'PREVENTIVE_SCHEDULES', @id,
                CONCAT(N'Plan Preventivo ', @id, N' creado para el equipo ', @AssetCode, N' (', @AssetName, N') con ', 
                       (SELECT COUNT(*) FROM dbo.PlanPreventivoActividad WHERE PlanId = @id), N' componentes configurados.'));

        COMMIT TRANSACTION;
        SELECT @id AS PlanId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT N'Restricción de 1 Plan Preventivo por Equipo Principal creada exitosamente.';
GO
