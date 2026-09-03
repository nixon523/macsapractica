/* ============================================================================
   MACSA CMMS - Grupo Macsa
   migracion_preventivo_jerarquico.sql
   Mantenimiento Preventivo Jerárquico por Componentes (Padre -> Hijos)
   Frecuencias Personalizadas y Consolidación Mensual de Órdenes de Trabajo
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Función para calcular la próxima fecha según intervalo y unidad personalizada
CREATE OR ALTER FUNCTION dbo.fnCalcularProximaFechaPreventiva (
    @FechaBase           DATETIME2(3),
    @Intervalo           INT,
    @UnidadFrecuencia    NVARCHAR(20) -- 'dias', 'semanas', 'meses', 'anios', 'anos'
)
RETURNS DATETIME2(3)
AS
BEGIN
    DECLARE @Proxima DATETIME2(3);
    SET @Intervalo = ISNULL(@Intervalo, 1);
    IF @FechaBase IS NULL SET @FechaBase = SYSUTCDATETIME();
    
    SET @Proxima = CASE LOWER(LTRIM(RTRIM(@UnidadFrecuencia)))
        WHEN 'dias'    THEN DATEADD(day, @Intervalo, @FechaBase)
        WHEN 'semanas' THEN DATEADD(week, @Intervalo, @FechaBase)
        WHEN 'meses'   THEN DATEADD(month, @Intervalo, @FechaBase)
        WHEN 'anios'   THEN DATEADD(year, @Intervalo, @FechaBase)
        WHEN 'anos'    THEN DATEADD(year, @Intervalo, @FechaBase)
        ELSE DATEADD(month, @Intervalo, @FechaBase)
    END;
    
    RETURN @Proxima;
END;
GO

-- 2. Asegurar campos de frecuencia flexible en dbo.PlanPreventivo (cabecera del equipo padre)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.PlanPreventivo') AND name = N'IntervaloFrecuencia')
BEGIN
    ALTER TABLE dbo.PlanPreventivo ADD 
        IntervaloFrecuencia INT NULL CONSTRAINT DF_PP_Intervalo DEFAULT (1),
        UnidadFrecuencia    NVARCHAR(20) NULL CONSTRAINT DF_PP_Unidad DEFAULT ('meses');
END;
GO

-- 3. Crear tabla dbo.PlanPreventivoActividad para las tareas específicas de cada Activo Hijo
IF OBJECT_ID(N'dbo.PlanPreventivoActividad', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PlanPreventivoActividad (
        ActividadId             BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PlanPreventivoActividad PRIMARY KEY,
        PlanId                  NVARCHAR(20)  NOT NULL,
        CodigoActivoHijo        NVARCHAR(60)  NOT NULL,
        NombreActivoHijo        NVARCHAR(200) NOT NULL,
        NivelActivoHijo         NVARCHAR(20)  NOT NULL CONSTRAINT DF_PPA_Nivel DEFAULT ('subEquipment'),
        DescripcionActividad    NVARCHAR(300) NOT NULL,
        ProcedimientoEstandar   NVARCHAR(MAX) NULL,
        IntervaloFrecuencia     INT           NOT NULL CONSTRAINT DF_PPA_Intervalo DEFAULT (1),
        UnidadFrecuencia        NVARCHAR(20)  NOT NULL CONSTRAINT DF_PPA_UnidadFrecuencia DEFAULT ('meses'),
        HorasEstimadas          DECIMAL(5,2)  NULL,
        FechaInicio             DATETIME2(3)  NOT NULL,
        ProximaFecha            DATETIME2(3)  NOT NULL,
        FechaUltimaEjecucion    DATETIME2(3)  NULL,
        Estado                  NVARCHAR(15)  NOT NULL CONSTRAINT DF_PPA_Estado DEFAULT ('active'),
        CreadoEn                DATETIME2(3)  NOT NULL CONSTRAINT DF_PPA_CreadoEn DEFAULT (SYSUTCDATETIME()),
        
        CONSTRAINT CK_PPA_Unidad CHECK (UnidadFrecuencia IN ('dias','semanas','meses','anios','anos')),
        CONSTRAINT CK_PPA_Intervalo CHECK (IntervaloFrecuencia > 0),
        CONSTRAINT CK_PPA_Estado CHECK (Estado IN ('active','paused')),
        CONSTRAINT FK_PPA_Plan FOREIGN KEY (PlanId) REFERENCES dbo.PlanPreventivo(PlanId) ON DELETE CASCADE,
        CONSTRAINT FK_PPA_ActivoHijo FOREIGN KEY (CodigoActivoHijo) REFERENCES dbo.Activo(CodigoActivo)
    );

    CREATE NONCLUSTERED INDEX IX_PPA_PlanId ON dbo.PlanPreventivoActividad(PlanId);
    CREATE NONCLUSTERED INDEX IX_PPA_ActivoHijo ON dbo.PlanPreventivoActividad(CodigoActivoHijo);
    CREATE NONCLUSTERED INDEX IX_PPA_ProximaFecha ON dbo.PlanPreventivoActividad(ProximaFecha, Estado);
END;
GO

-- 4. Crear tabla dbo.PlanPreventivoMaterial para repuestos/materiales por actividad del hijo
IF OBJECT_ID(N'dbo.PlanPreventivoMaterial', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PlanPreventivoMaterial (
        MaterialId              BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PlanPreventivoMaterial PRIMARY KEY,
        ActividadId             BIGINT        NOT NULL,
        NombreMaterial          NVARCHAR(200) NOT NULL,
        Cantidad                DECIMAL(10,2) NOT NULL CONSTRAINT DF_PPM_Cantidad DEFAULT (1),
        Unidad                  NVARCHAR(15)  NOT NULL CONSTRAINT DF_PPM_Unidad DEFAULT ('pza'),
        
        CONSTRAINT FK_PPM_Actividad FOREIGN KEY (ActividadId) REFERENCES dbo.PlanPreventivoActividad(ActividadId) ON DELETE CASCADE
    );

    CREATE NONCLUSTERED INDEX IX_PPM_ActividadId ON dbo.PlanPreventivoMaterial(ActividadId);
END;
GO

-- 5. Procedimiento Almacenado: uspPlanPreventivoCrear (con soporte para JSON de Actividades y Materiales de Hijos)
CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoCrear
    @Title                  NVARCHAR(200) = NULL,
    @AssetCode              NVARCHAR(60),          -- Código del Equipo Padre
    @AssetName              NVARCHAR(200),
    @AreaId                 NVARCHAR(15),
    @AreaName               NVARCHAR(200),
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
    @ActividadesJson        NVARCHAR(MAX) = NULL   -- JSON de actividades por hijo con sus materiales
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Generar ID correlativo PM-{Año}-{0001}
        DECLARE @cTable TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT deleted.SiguienteNumero INTO @cTable(v)
          WHERE Nombre = 'preventive_schedules';

        DECLARE @n INT; SELECT @n = v FROM @cTable;
        DECLARE @id NVARCHAR(20) = CONCAT('PM-', YEAR(SYSUTCDATETIME()), '-', FORMAT(@n, '0000'));
        DECLARE @FinalTitle NVARCHAR(200) =
            CASE WHEN LTRIM(ISNULL(@Title, N'')) = N'' THEN CONCAT(N'Plan Preventivo ', @id) ELSE @Title END;

        -- Si NextDate no viene especificado, se calcula automáticamente
        IF @NextDate IS NULL
        BEGIN
            SET @NextDate = dbo.fnCalcularProximaFechaPreventiva(@StartDate, @IntervaloFrecuencia, @UnidadFrecuencia);
        END;

        -- Insertar cabecera del Plan para el Equipo Padre
        INSERT INTO dbo.PlanPreventivo
            (PlanId, Titulo, CodigoActivo, NombreActivo, AreaId, NombreArea, TipoMantenimiento, Frecuencia,
             IntervaloFrecuencia, UnidadFrecuencia, Descripcion, HorasEstimadas, FechaInicio, ProximaFecha,
             UltimaCompletada, UltimaOrdenTrabajoId, Estado, Notas, CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn)
        VALUES
            (@id, @FinalTitle, @AssetCode, @AssetName, @AreaId, @AreaName, @MaintenanceType, @Frequency,
             @IntervaloFrecuencia, @UnidadFrecuencia, @Description, @EstimatedHours, @StartDate, @NextDate,
             @LastCompleted, @LastWorkOrderId, @Status, @Notes, @CreatedByUserId, @CreatedByUserName, SYSUTCDATETIME());

        -- Compatibilidad: Materiales directos a nivel de plan si existen
        INSERT INTO dbo.MaterialPreventivo (PlanId, NumeroLinea, Nombre, Cantidad, Unidad)
        SELECT @id, ROW_NUMBER() OVER (ORDER BY NumeroLinea), Nombre, Cantidad, ISNULL(Unidad, 'pza')
          FROM @Materials;

        -- Procesar Actividades por Componente Hijo desde JSON si se proporcionan
        IF @ActividadesJson IS NOT NULL AND ISJSON(@ActividadesJson) = 1
        BEGIN
            DECLARE @ActividadTemp TABLE (
                TempId               INT IDENTITY(1,1),
                CodigoActivoHijo     NVARCHAR(60),
                NombreActivoHijo     NVARCHAR(200),
                NivelActivoHijo      NVARCHAR(20),
                DescripcionActividad NVARCHAR(300),
                IntervaloFrecuencia  INT,
                UnidadFrecuencia     NVARCHAR(20),
                HorasEstimadas       DECIMAL(5,2),
                FechaInicio          DATETIME2(3),
                ProximaFecha         DATETIME2(3),
                MaterialesJson       NVARCHAR(MAX)
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

            -- Cursor o loop para insertar actividades y sus respectivos materiales
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

                -- Si la actividad del hijo tiene materiales definidos
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
        END;

        -- Registrar en Bitácora Kardex
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

-- 6. Procedimiento Almacenado: uspPlanPreventivoObtenerTodos (con Actividades y Materiales de Hijos)
CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoObtenerTodos
    @AreaFilter   NVARCHAR(15) = NULL,
    @StatusFilter NVARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        p.PlanId                      AS ScheduleId,
        p.Titulo                      AS Title,
        p.CodigoActivo                AS AssetCode,
        p.NombreActivo                AS AssetName,
        p.AreaId,
        p.NombreArea                  AS AreaName,
        p.TipoMantenimiento           AS MaintenanceType,
        p.Frecuencia                  AS Frequency,
        p.IntervaloFrecuencia         AS IntervaloFrecuencia,
        p.UnidadFrecuencia            AS UnidadFrecuencia,
        p.Descripcion                 AS Description,
        p.HorasEstimadas              AS EstimatedHours,
        p.FechaInicio                 AS StartDate,
        p.ProximaFecha                AS NextDate,
        p.UltimaCompletada            AS LastCompleted,
        p.UltimaOrdenTrabajoId        AS LastWorkOrderId,
        p.Estado                      AS Status,
        p.Notas                       AS Notes,
        p.CreadoPorUsuarioId          AS CreatedByUserId,
        p.CreadoPorNombreUsuario      AS CreatedByUserName,
        p.CreadoEn                    AS CreatedAt,
        p.NumeroDocumentoModificacion AS AmendmentDocNumber,
        p.ModificadoPor               AS AmendedBy,
        p.ModificadoEn                AS AmendedAt,
        p.MotivoModificacion          AS AmendmentReason,
        m.MaterialsJson,
        act.ActividadesJson
    FROM dbo.PlanPreventivo p
    OUTER APPLY (
        SELECT (
            SELECT Nombre AS Name, Cantidad AS Quantity, Unidad AS Unit
            FROM dbo.MaterialPreventivo
            WHERE PlanId = p.PlanId
            ORDER BY NumeroLinea
            FOR JSON PATH
        ) AS MaterialsJson
    ) m
    OUTER APPLY (
        SELECT (
            SELECT 
                ppa.ActividadId          AS actividadId,
                ppa.CodigoActivoHijo     AS codigoActivoHijo,
                ppa.NombreActivoHijo     AS nombreActivoHijo,
                ppa.NivelActivoHijo      AS nivelActivoHijo,
                ppa.DescripcionActividad AS descripcionActividad,
                ppa.IntervaloFrecuencia  AS intervaloFrecuencia,
                ppa.UnidadFrecuencia     AS unidadFrecuencia,
                ppa.HorasEstimadas       AS horasEstimadas,
                ppa.FechaInicio          AS fechaInicio,
                ppa.ProximaFecha         AS proximaFecha,
                ppa.FechaUltimaEjecucion AS fechaUltimaEjecucion,
                ppa.Estado               AS estado,
                (
                    SELECT 
                        ppm.MaterialId     AS materialId,
                        ppm.NombreMaterial AS nombre,
                        ppm.Cantidad       AS cantidad,
                        ppm.Unidad         AS unidad
                    FROM dbo.PlanPreventivoMaterial ppm
                    WHERE ppm.ActividadId = ppa.ActividadId
                    FOR JSON PATH
                ) AS materiales
            FROM dbo.PlanPreventivoActividad ppa
            WHERE ppa.PlanId = p.PlanId
            ORDER BY ppa.ProximaFecha ASC
            FOR JSON PATH
        ) AS ActividadesJson
    ) act
    WHERE (@AreaFilter   IS NULL OR p.AreaId = @AreaFilter)
      AND (@StatusFilter IS NULL OR p.Estado = @StatusFilter)
    ORDER BY p.ProximaFecha ASC;
END;
GO

-- 7. Procedimiento Almacenado: uspGenerarOrdenTrabajoPreventivaMes
-- Agrupa en una sola Orden de Trabajo a nombre del Padre todas las actividades de hijos que vencen en el mes/año
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
        DECLARE @CodigoPadre NVARCHAR(60), @NombrePadre NVARCHAR(200), @AreaId NVARCHAR(15), @NombreArea NVARCHAR(200);
        SELECT 
            @CodigoPadre = p.CodigoActivo,
            @NombrePadre = p.NombreActivo,
            @AreaId      = p.AreaId,
            @NombreArea  = p.NombreArea
        FROM dbo.PlanPreventivo p
        WHERE p.PlanId = @PlanId;

        IF @CodigoPadre IS NULL
        BEGIN
            RAISERROR('El plan preventivo no existe.', 16, 1);
        END;

        -- 2. Identificar actividades de hijos que vencen en el mes/año dado
        DECLARE @ActividadesMes TABLE (
            ActividadId BIGINT,
            CodigoHijo  NVARCHAR(60),
            NombreHijo  NVARCHAR(200),
            Tarea       NVARCHAR(300),
            Horas       DECIMAL(5,2)
        );

        INSERT INTO @ActividadesMes
        SELECT ActividadId, CodigoActivoHijo, NombreActivoHijo, DescripcionActividad, HorasEstimadas
        FROM dbo.PlanPreventivoActividad
        WHERE PlanId = @PlanId
          AND Estado = 'active'
          AND YEAR(ProximaFecha) = @Anio
          AND MONTH(ProximaFecha) = @Mes;

        -- Si no hay específicas de hijos en ese mes, verificar si la cabecera misma vence en ese mes
        IF NOT EXISTS (SELECT 1 FROM @ActividadesMes)
        BEGIN
            -- Incluir todas las actividades activas del plan si se forzó la generación
            INSERT INTO @ActividadesMes
            SELECT ActividadId, CodigoActivoHijo, NombreActivoHijo, DescripcionActividad, HorasEstimadas
            FROM dbo.PlanPreventivoActividad
            WHERE PlanId = @PlanId AND Estado = 'active';
        END;

        -- 3. Generar número correlativo de OT: OT-{Año}-{0001}
        DECLARE @cTable TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT deleted.SiguienteNumero INTO @cTable(v)
          WHERE Nombre = 'work_orders';

        DECLARE @n INT; SELECT @n = v FROM @cTable;
        SET @NuevaOrdenId = CONCAT('OT-', @Anio, '-', FORMAT(@n, '0000'));

        -- 4. Construir descripción consolidada para el equipo principal
        DECLARE @DescripcionConsolidada NVARCHAR(MAX) = 
            CONCAT(N'Mantenimiento Preventivo Programado (Plan ', @PlanId, N') - ', @NombrePadre, CHAR(13), CHAR(10),
                   N'Período: ', FORMAT(DATEFROMPARTS(@Anio, @Mes, 1), 'MMMM yyyy', 'es-ES'), CHAR(13), CHAR(10),
                   N'Actividades en Componentes:', CHAR(13), CHAR(10));

        SELECT @DescripcionConsolidada += CONCAT(N' • [', CodigoHijo, N' - ', NombreHijo, N']: ', Tarea, CHAR(13), CHAR(10))
        FROM @ActividadesMes;

        -- 5. Insertar la Orden de Trabajo dirigida al Equipo Padre
        INSERT INTO dbo.OrdenTrabajo (
            OrdenTrabajoId, CodigoActivo, NombreActivo, AreaId, NombreArea,
            Descripcion, Estado, Prioridad, CreadoPorUsuarioId, CreadoPorNombreUsuario,
            FechaProgramada, CreadoEn
        )
        VALUES (
            @NuevaOrdenId, @CodigoPadre, @NombrePadre, @AreaId, @NombreArea,
            @DescripcionConsolidada, 'pending', 'medium', @CreadoPorUsuarioId, @CreadoPorNombre,
            DATEFROMPARTS(@Anio, @Mes, 1), SYSUTCDATETIME()
        );

        -- 6. Consolidar materiales de todos los hijos en la Orden de Trabajo
        INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
        SELECT 
            @NuevaOrdenId,
            ROW_NUMBER() OVER (ORDER BY m.MaterialId),
            CONCAT(m.NombreMaterial, N' (para ', act.NombreHijo, N')'),
            m.Cantidad,
            m.Unidad
        FROM dbo.PlanPreventivoMaterial m
        INNER JOIN @ActividadesMes act ON act.ActividadId = m.ActividadId;

        -- 7. Actualizar el plan preventivo con la última OT generada
        UPDATE dbo.PlanPreventivo
           SET UltimaOrdenTrabajoId = @NuevaOrdenId
         WHERE PlanId = @PlanId;

        -- 8. Bitácora Kardex
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreadoPorUsuarioId, @CreadoPorNombre, 'WORK_ORDER_CREATED', 'WORK_ORDERS', @NuevaOrdenId,
                CONCAT(N'OT preventiva consolidada ', @NuevaOrdenId, N' generada para ', @CodigoPadre, N' (Plan ', @PlanId, N')'));

        COMMIT TRANSACTION;
        SELECT @NuevaOrdenId AS NewWorkOrderId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT 'Migración de Mantenimiento Preventivo Jerárquico ejecutada exitosamente.';
GO
