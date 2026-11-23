-- ============================================================================
-- PARCHE 2026-11-17: TABLA DE MARCAS Y MÉTRICAS DE MANTENIMIENTO POR CENTRO DE COSTO
-- Grupo Macsa - CMMS
-- ============================================================================

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ----------------------------------------------------------------------------
-- 1. TABLA dbo.Marca
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Marca' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.Marca (
        MarcaId       INT           IDENTITY(1,1) NOT NULL,
        Nombre        NVARCHAR(100) NOT NULL,
        Descripcion   NVARCHAR(250) NULL,
        Activo        BIT           NOT NULL CONSTRAINT DF_Marca_Activo DEFAULT (1),
        CreadoEn      DATETIME2(3)  NOT NULL CONSTRAINT DF_Marca_CreadoEn DEFAULT (SYSUTCDATETIME()),
        ActualizadoEn DATETIME2(3)  NOT NULL CONSTRAINT DF_Marca_ActualizadoEn DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_Marca PRIMARY KEY CLUSTERED (MarcaId),
        CONSTRAINT UQ_Marca_Nombre UNIQUE NONCLUSTERED (Nombre)
    );
    PRINT 'Tabla dbo.Marca creada exitosamente.';
END;
GO

-- ----------------------------------------------------------------------------
-- 2. SEED INICIAL DE MARCAS
-- ----------------------------------------------------------------------------
-- Sembrar marcas que ya existan en dbo.Activo más las marcas industriales habituales
INSERT INTO dbo.Marca (Nombre, Descripcion)
SELECT DISTINCT LTRIM(RTRIM(a.Marca)), N'Marca registrada previamente en activos'
  FROM dbo.Activo a
 WHERE a.Marca IS NOT NULL 
   AND LTRIM(RTRIM(a.Marca)) <> ''
   AND NOT EXISTS (SELECT 1 FROM dbo.Marca m WHERE UPPER(m.Nombre) = UPPER(LTRIM(RTRIM(a.Marca))));

MERGE dbo.Marca AS target
USING (VALUES
    (N'Siemens',              N'Equipos eléctricos, automatización, motores y variadores'),
    (N'ABB',                  N'Robótica, potencia, motores y accionamientos industriales'),
    (N'Schneider Electric',   N'Tableros eléctricos, arrancadores y protecciones'),
    (N'Danfoss',              N'Compresores, variadores de frecuencia y válvulas'),
    (N'Caterpillar',          N'Generadores y motores diésel industriales'),
    (N'Baldor',               N'Motores eléctricos industriales y reductores'),
    (N'WEG',                  N'Motores eléctricos, arrancadores y transformadores'),
    (N'York',                 N'Chillers, compresores y sistemas de refrigeración'),
    (N'Carrier',              N'Sistemas de climatización y cuartos fríos'),
    (N'Hobart',               N'Maquinaria de corte, empaque y procesamiento'),
    (N'Mettler Toledo',       N'Básculas industriales, pesadoras y celdas de carga'),
    (N'Festo',                N'Componentes y actuadores neumáticos industriales'),
    (N'SEW-Eurodrive',        N'Motorreductores y variadores mecánicos'),
    (N'Ingersoll Rand',       N'Compresores de aire y bombas industriales'),
    (N'Graco',                N'Bombas y sistemas de lubricación/fluido industrial')
) AS source (Nombre, Descripcion)
ON UPPER(target.Nombre) = UPPER(source.Nombre)
WHEN NOT MATCHED THEN
    INSERT (Nombre, Descripcion, Activo, CreadoEn, ActualizadoEn)
    VALUES (source.Nombre, source.Descripcion, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
GO

-- ----------------------------------------------------------------------------
-- 3. PROCEDIMIENTOS ALMACENADOS PARA MARCAS
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspMarcaListar
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT MarcaId AS id,
           MarcaId,
           Nombre AS name,
           Nombre,
           Descripcion AS description,
           Descripcion,
           Activo AS isActive,
           Activo,
           CreadoEn,
           ActualizadoEn,
           (SELECT COUNT(*) FROM dbo.Activo WHERE UPPER(LTRIM(RTRIM(Marca))) = UPPER(LTRIM(RTRIM(m.Nombre))) AND Estado <> 'deleted') AS TotalActivosAsociados
      FROM dbo.Marca m
     WHERE (@IncludeInactive = 1 OR Activo = 1)
     ORDER BY Nombre ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspMarcaCrear
    @Nombre      NVARCHAR(100),
    @Descripcion NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @CleanName NVARCHAR(100) = LTRIM(RTRIM(@Nombre));
        IF @CleanName IS NULL OR @CleanName = ''
            RAISERROR(N'El nombre de la marca es obligatorio.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Marca WHERE UPPER(Nombre) = UPPER(@CleanName))
            RAISERROR(N'Ya existe una marca con ese nombre.', 16, 1);

        INSERT INTO dbo.Marca (Nombre, Descripcion, Activo, CreadoEn, ActualizadoEn)
        VALUES (@CleanName, NULLIF(LTRIM(RTRIM(@Descripcion)), ''), 1, SYSUTCDATETIME(), SYSUTCDATETIME());

        DECLARE @NewId INT = SCOPE_IDENTITY();
        SELECT MarcaId AS id, MarcaId, Nombre AS name, Nombre, Descripcion AS description, Descripcion, Activo AS isActive, Activo
          FROM dbo.Marca
         WHERE MarcaId = @NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspMarcaActualizar
    @MarcaId     INT,
    @Nombre      NVARCHAR(100),
    @Descripcion NVARCHAR(250) = NULL,
    @Activo      BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @CleanName NVARCHAR(100) = LTRIM(RTRIM(@Nombre));
        IF @CleanName IS NULL OR @CleanName = ''
            RAISERROR(N'El nombre de la marca es obligatorio.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM dbo.Marca WHERE MarcaId = @MarcaId)
            RAISERROR(N'La marca no existe.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Marca WHERE UPPER(Nombre) = UPPER(@CleanName) AND MarcaId <> @MarcaId)
            RAISERROR(N'Ya existe otra marca con ese nombre.', 16, 1);

        DECLARE @OldName NVARCHAR(100);
        SELECT @OldName = Nombre FROM dbo.Marca WHERE MarcaId = @MarcaId;

        UPDATE dbo.Marca
           SET Nombre        = @CleanName,
               Descripcion   = NULLIF(LTRIM(RTRIM(@Descripcion)), ''),
               Activo        = @Activo,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE MarcaId = @MarcaId;

        -- Si el nombre cambió, actualizar en cascada en dbo.Activo para mantener la referencia sincronizada
        IF @OldName <> @CleanName
        BEGIN
            UPDATE dbo.Activo
               SET Marca = @CleanName
             WHERE UPPER(LTRIM(RTRIM(Marca))) = UPPER(LTRIM(RTRIM(@OldName)));
        END;

        SELECT MarcaId AS id, MarcaId, Nombre AS name, Nombre, Descripcion AS description, Descripcion, Activo AS isActive, Activo
          FROM dbo.Marca
         WHERE MarcaId = @MarcaId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspMarcaEliminar
    @MarcaId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        DECLARE @BrandName NVARCHAR(100);
        SELECT @BrandName = Nombre FROM dbo.Marca WHERE MarcaId = @MarcaId;

        IF @BrandName IS NULL
            RAISERROR(N'La marca especificada no existe.', 16, 1);

        -- Validación de integridad referencial: activos usando la marca
        DECLARE @ActivosEnUso INT = 0;
        SELECT @ActivosEnUso = COUNT(*)
          FROM dbo.Activo
         WHERE UPPER(LTRIM(RTRIM(Marca))) = UPPER(LTRIM(RTRIM(@BrandName)))
           AND Estado <> 'deleted';

        IF @ActivosEnUso > 0
        BEGIN
            -- Si está en uso, inactivar lógicamente en lugar de romper integridad
            UPDATE dbo.Marca
               SET Activo = 0,
                   ActualizadoEn = SYSUTCDATETIME()
             WHERE MarcaId = @MarcaId;

            SELECT 1 AS success, 1 AS inactivatedOnly, @ActivosEnUso AS assetsCount,
                   CONCAT(N'La marca está en uso por ', @ActivosEnUso, N' activo(s). Se ha desactivado del catálogo para preservar la integridad.') AS message;
            RETURN;
        END;

        -- Si no está en uso por ningún activo, eliminación completa
        DELETE FROM dbo.Marca WHERE MarcaId = @MarcaId;

        SELECT 1 AS success, 0 AS inactivatedOnly, 0 AS assetsCount, N'Marca eliminada correctamente.' AS message;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 4. ACTUALIZAR dbo.uspCatalogosObtener (INCLUYENDO MARCAS)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.uspCatalogosObtener
AS
BEGIN
    SET NOCOUNT ON;
    -- 1. Roles
    SELECT CodigoRol, Nombre
      FROM dbo.Rol
     ORDER BY CASE CodigoRol 
                WHEN 'admin' THEN 1 
                WHEN 'jefe' THEN 2 
                WHEN 'jefe_area' THEN 3 
                WHEN 'reportador' THEN 4 
                WHEN 'lector' THEN 5 
                ELSE 6 END;

    -- 2. Permisos
    SELECT CodigoPermiso
      FROM dbo.Permiso
     ORDER BY CodigoPermiso ASC;

    -- 3. Matriz Rol-Permiso
    SELECT CodigoRol, CodigoPermiso
      FROM dbo.RolPermiso
     ORDER BY CodigoRol, CodigoPermiso;

    -- 4. Puestos Activos
    SELECT PuestoId, Nombre, EsMantenimiento
      FROM dbo.Puesto
     WHERE Activo = 1
     ORDER BY Nombre ASC;

    -- 5. Unidades de Medida Activas
    SELECT UnidadMedidaId AS id, Codigo AS code, Nombre AS name
      FROM dbo.UnidadMedida
     WHERE Activo = 1
     ORDER BY Codigo ASC;

    -- 6. Atributos de Catálogo Activos
    SELECT a.AtributoId AS id, a.Nombre AS name, a.Descripcion AS description,
           a.UnidadMedidaIdDefecto AS defaultUnitId, u.Codigo AS defaultUnitCode
      FROM dbo.AtributoCatalogo a
      LEFT JOIN dbo.UnidadMedida u ON u.UnidadMedidaId = a.UnidadMedidaIdDefecto
     WHERE a.Activo = 1
     ORDER BY a.Nombre ASC;

    -- 7. Marcas Activas
    SELECT MarcaId AS id, Nombre AS name, Descripcion AS description
      FROM dbo.Marca
     WHERE Activo = 1
     ORDER BY Nombre ASC;
END;
GO

-- ----------------------------------------------------------------------------
-- 5. PROCEDIMIENTOS ALMACENADOS PARA MÉTRICAS DE MANTENIMIENTO POR CENTRO DE COSTO
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspReporteMantenimientosPorCentroCosto
    @FechaInicio              DATETIME2(3) = NULL,
    @FechaFin                 DATETIME2(3) = NULL,
    @SoloConMantenimiento     BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH OTMantenimiento AS (
        SELECT 
            ot.OrdenTrabajoId,
            ot.AreaId,
            ot.Estado,
            ot.HorasReales,
            ot.HorasEstimadas,
            ot.CreadoEn,
            CASE 
                WHEN ot.PlanPreventivoId IS NOT NULL OR tt.EsPreventivo = 1 THEN 'preventive'
                WHEN ot.ReporteId IS NOT NULL OR tt.EsCorrectivo = 1 THEN 'corrective'
                ELSE COALESCE(tt.PrimerTipo, 'other')
            END AS TipoMantenimientoPrincipal,
            ISNULL(tt.EsCorrectivo, CASE WHEN ot.ReporteId IS NOT NULL THEN 1 ELSE 0 END) AS EsCorrectivo,
            ISNULL(tt.EsPreventivo, CASE WHEN ot.PlanPreventivoId IS NOT NULL THEN 1 ELSE 0 END) AS EsPreventivo,
            ISNULL(tt.EsPredictivo, 0) AS EsPredictivo,
            ISNULL(tt.EsMejora, 0) AS EsMejora,
            ISNULL(tt.EsOtro, 0) AS EsOtro
        FROM dbo.OrdenTrabajo ot
        OUTER APPLY (
            SELECT 
                MAX(CASE WHEN LOWER(TipoTrabajo) LIKE '%correctiv%' THEN 1 ELSE 0 END) AS EsCorrectivo,
                MAX(CASE WHEN LOWER(TipoTrabajo) LIKE '%preventiv%' THEN 1 ELSE 0 END) AS EsPreventivo,
                MAX(CASE WHEN LOWER(TipoTrabajo) LIKE '%predictiv%' THEN 1 ELSE 0 END) AS EsPredictivo,
                MAX(CASE WHEN LOWER(TipoTrabajo) LIKE '%mejor%' OR LOWER(TipoTrabajo) LIKE '%improvement%' THEN 1 ELSE 0 END) AS EsMejora,
                MAX(CASE WHEN LOWER(TipoTrabajo) NOT LIKE '%correctiv%' AND LOWER(TipoTrabajo) NOT LIKE '%preventiv%' THEN 1 ELSE 0 END) AS EsOtro,
                MIN(TipoTrabajo) AS PrimerTipo
            FROM dbo.TipoTrabajoOrdenTrabajo
            WHERE OrdenTrabajoId = ot.OrdenTrabajoId
        ) tt
        WHERE (@FechaInicio IS NULL OR ot.CreadoEn >= @FechaInicio)
          AND (@FechaFin IS NULL OR ot.CreadoEn <= @FechaFin)
    )
    SELECT 
        ar.CentroCosto                                                          AS costCenter,
        ar.CentroCosto,
        ar.AreaId                                                               AS areaId,
        ar.AreaId,
        ar.Nombre                                                               AS areaName,
        ar.Nombre,
        COUNT(m.OrdenTrabajoId)                                                 AS totalMaintenance,
        COUNT(m.OrdenTrabajoId)                                                 AS TotalMantenimientos,
        SUM(CASE WHEN m.Estado = 'completed' THEN 1 ELSE 0 END)                 AS completed,
        SUM(CASE WHEN m.Estado = 'completed' THEN 1 ELSE 0 END)                 AS Completados,
        SUM(CASE WHEN m.Estado IN ('pending', 'inProgress', 'in_progress', 'paused') THEN 1 ELSE 0 END) AS inProgress,
        SUM(CASE WHEN m.Estado IN ('pending', 'inProgress', 'in_progress', 'paused') THEN 1 ELSE 0 END) AS EnProceso,
        SUM(CASE WHEN m.Estado = 'cancelled' THEN 1 ELSE 0 END)                 AS cancelled,
        SUM(CASE WHEN m.Estado = 'cancelled' THEN 1 ELSE 0 END)                 AS Canceladas,
        SUM(CASE WHEN m.EsCorrectivo = 1 THEN 1 ELSE 0 END)                     AS corrective,
        SUM(CASE WHEN m.EsCorrectivo = 1 THEN 1 ELSE 0 END)                     AS Correctivos,
        SUM(CASE WHEN m.EsPreventivo = 1 THEN 1 ELSE 0 END)                     AS preventive,
        SUM(CASE WHEN m.EsPreventivo = 1 THEN 1 ELSE 0 END)                     AS Preventivos,
        SUM(CASE WHEN m.EsPredictivo = 1 THEN 1 ELSE 0 END)                     AS predictive,
        SUM(CASE WHEN m.EsPredictivo = 1 THEN 1 ELSE 0 END)                     AS Predictivos,
        SUM(CASE WHEN m.EsMejora = 1 THEN 1 ELSE 0 END)                         AS improvement,
        SUM(CASE WHEN m.EsMejora = 1 THEN 1 ELSE 0 END)                         AS Mejoras,
        SUM(CASE WHEN (m.EsOtro = 1 AND m.EsCorrectivo = 0 AND m.EsPreventivo = 0) THEN 1 ELSE 0 END) AS otherTypes,
        SUM(CASE WHEN (m.EsOtro = 1 AND m.EsCorrectivo = 0 AND m.EsPreventivo = 0) THEN 1 ELSE 0 END) AS OtrosTipos,
        CAST(ISNULL(SUM(m.HorasReales), 0) AS DECIMAL(10, 2))                   AS totalRealHours,
        CAST(ISNULL(SUM(m.HorasReales), 0) AS DECIMAL(10, 2))                   AS HorasRealesTotales,
        CAST(ISNULL(SUM(m.HorasEstimadas), 0) AS DECIMAL(10, 2))                AS totalEstimatedHours
    FROM dbo.Area ar
    LEFT JOIN OTMantenimiento m ON m.AreaId = ar.AreaId
    WHERE (@SoloConMantenimiento = 0 OR m.OrdenTrabajoId IS NOT NULL)
    GROUP BY ar.CentroCosto, ar.AreaId, ar.Nombre
    ORDER BY TotalMantenimientos DESC, ar.CentroCosto ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteMantenimientosPorCentroCostoDetalle
    @CentroCosto              NVARCHAR(50) = NULL,
    @AreaId                   NVARCHAR(15) = NULL,
    @FechaInicio              DATETIME2(3) = NULL,
    @FechaFin                 DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        ot.OrdenTrabajoId                                      AS workOrderId,
        ot.OrdenTrabajoId,
        ot.CodigoActivo                                        AS assetCode,
        ot.CodigoActivo,
        ot.NombreActivo                                        AS assetName,
        ot.NombreActivo,
        ar.AreaId                                              AS areaId,
        ar.AreaId,
        ar.Nombre                                              AS areaName,
        ar.Nombre                                              AS NombreArea,
        ar.CentroCosto                                         AS costCenter,
        ar.CentroCosto,
        ot.Descripcion                                         AS description,
        ot.Descripcion,
        ot.Estado                                              AS status,
        ot.Estado,
        ot.Prioridad                                           AS priority,
        ot.Prioridad,
        ot.AsignadoA                                           AS assignedTo,
        ot.AsignadoA,
        ot.HorasEstimadas                                      AS estimatedHours,
        ot.HorasReales                                         AS actualHours,
        ot.CreadoEn                                            AS createdAt,
        ot.CreadoEn,
        ot.FechaProgramada                                     AS scheduledDate,
        ot.ReporteId                                           AS reportId,
        ot.PlanPreventivoId                                    AS preventiveScheduleId,
        CASE 
            WHEN ot.PlanPreventivoId IS NOT NULL OR tt.EsPreventivo = 1 THEN 'preventive'
            WHEN ot.ReporteId IS NOT NULL OR tt.EsCorrectivo = 1 THEN 'corrective'
            ELSE COALESCE(tt.PrimerTipo, 'other')
        END AS mainMaintenanceType,
        tt.TiposTrabajoConcatenados AS workTypesText
    FROM dbo.OrdenTrabajo ot
    INNER JOIN dbo.Area ar ON ar.AreaId = ot.AreaId
    OUTER APPLY (
        SELECT 
            MAX(CASE WHEN LOWER(TipoTrabajo) LIKE '%correctiv%' THEN 1 ELSE 0 END) AS EsCorrectivo,
            MAX(CASE WHEN LOWER(TipoTrabajo) LIKE '%preventiv%' THEN 1 ELSE 0 END) AS EsPreventivo,
            MIN(TipoTrabajo) AS PrimerTipo,
            STRING_AGG(TipoTrabajo, ', ') AS TiposTrabajoConcatenados
        FROM dbo.TipoTrabajoOrdenTrabajo
        WHERE OrdenTrabajoId = ot.OrdenTrabajoId
    ) tt
    WHERE (@CentroCosto IS NULL OR UPPER(LTRIM(RTRIM(ar.CentroCosto))) = UPPER(LTRIM(RTRIM(@CentroCosto))))
      AND (@AreaId IS NULL OR ar.AreaId = @AreaId)
      AND (@FechaInicio IS NULL OR ot.CreadoEn >= @FechaInicio)
      AND (@FechaFin IS NULL OR ot.CreadoEn <= @FechaFin)
    ORDER BY ot.CreadoEn DESC;
END;
GO

PRINT 'Parche 2026-11-17 de Marcas y Mantenimientos por Centro de Costo aplicado exitosamente.';
GO
