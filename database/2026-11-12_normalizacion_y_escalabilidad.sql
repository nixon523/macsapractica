-- ============================================================================
-- MIGRACIÓN: Normalización (3NF), Índices de Escalabilidad, Paginación y Catálogos
-- Fecha: 2026-11-12
-- Autor: Grupo MACSA - Sistema CMMS
-- ============================================================================
-- 1. Normaliza dbo.Empleado -> dbo.Puesto mediante FK PuestoId (con backfill).
-- 2. Sincroniza NombreArea y Puesto en tiempo real con JOINs en SPs de lectura.
-- 3. Crea índices faltantes para consultas jerárquicas, OTs, usuarios y resets.
-- 4. Agrega paginación opcional (@Limit / @Offset) en SPs de listado masivo
--    manteniendo 100% compatibilidad hacia atrás cuando @Limit IS NULL.
-- 5. Crea uspCatalogosObtener para servir roles, permisos y puestos desde BD
--    evitando hardcoding en API/Frontend.
-- ============================================================================

USE [MacsaCMMS];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

PRINT 'Iniciando migración: Normalización y Escalabilidad...';
GO

-- ============================================================================
-- 1. NORMALIZACIÓN: dbo.Empleado.PuestoId -> dbo.Puesto(PuestoId)
-- ============================================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
     WHERE object_id = OBJECT_ID(N'dbo.Empleado') AND name = N'PuestoId'
)
BEGIN
    ALTER TABLE dbo.Empleado ADD PuestoId INT NULL;
    ALTER TABLE dbo.Empleado ADD CONSTRAINT FK_Empleado_Puesto
        FOREIGN KEY (PuestoId) REFERENCES dbo.Puesto(PuestoId);
    PRINT 'Columna PuestoId y FK_Empleado_Puesto agregadas a dbo.Empleado.';
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
     WHERE object_id = OBJECT_ID(N'dbo.Empleado') AND name = N'IX_Empleado_PuestoId'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Empleado_PuestoId
        ON dbo.Empleado (PuestoId)
        INCLUDE (Activo, EsMantenimiento);
    PRINT 'Índice IX_Empleado_PuestoId creado.';
END;
GO

-- Backfill: crear en dbo.Puesto cualquier cargo existente en dbo.Empleado que falte
INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
SELECT DISTINCT
       LTRIM(RTRIM(e.Puesto)),
       MAX(CAST(e.EsMantenimiento AS INT)),
       1,
       SYSUTCDATETIME(),
       SYSUTCDATETIME()
  FROM dbo.Empleado e
 WHERE NULLIF(LTRIM(RTRIM(e.Puesto)), N'') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM dbo.Puesto p
        WHERE UPPER(LTRIM(RTRIM(p.Nombre))) = UPPER(LTRIM(RTRIM(e.Puesto)))
   )
 GROUP BY LTRIM(RTRIM(e.Puesto));
GO

-- Backfill: enlazar PuestoId en dbo.Empleado
UPDATE e
   SET e.PuestoId = p.PuestoId
  FROM dbo.Empleado e
  JOIN dbo.Puesto p
    ON UPPER(LTRIM(RTRIM(p.Nombre))) = UPPER(LTRIM(RTRIM(e.Puesto)))
 WHERE e.PuestoId IS NULL;
GO

-- ============================================================================
-- 2. ÍNDICES DE ESCALABILIDAD
-- ============================================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
     WHERE object_id = OBJECT_ID(N'dbo.Activo') AND name = N'IX_Activo_CodigoActivoPadre'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Activo_CodigoActivoPadre
        ON dbo.Activo (CodigoActivoPadre)
        INCLUDE (AreaId, Nivel, Estado, Nombre)
        WHERE CodigoActivoPadre IS NOT NULL;
    PRINT 'Índice IX_Activo_CodigoActivoPadre creado.';
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
     WHERE object_id = OBJECT_ID(N'dbo.Activo') AND name = N'IX_Activo_Area_Nivel_Estado'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Activo_Area_Nivel_Estado
        ON dbo.Activo (AreaId, Nivel, Estado)
        INCLUDE (Nombre, CodigoActivoPadre, EsEquipoProceso);
    PRINT 'Índice IX_Activo_Area_Nivel_Estado creado.';
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
     WHERE object_id = OBJECT_ID(N'dbo.OrdenTrabajo') AND name = N'IX_OrdenTrabajo_ReporteId'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_OrdenTrabajo_ReporteId
        ON dbo.OrdenTrabajo (ReporteId)
        WHERE ReporteId IS NOT NULL;
    PRINT 'Índice IX_OrdenTrabajo_ReporteId creado.';
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
     WHERE object_id = OBJECT_ID(N'dbo.OrdenTrabajo') AND name = N'IX_OrdenTrabajo_Area_Estado_Fecha'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_OrdenTrabajo_Area_Estado_Fecha
        ON dbo.OrdenTrabajo (AreaId, Estado, CreadoEn DESC);
    PRINT 'Índice IX_OrdenTrabajo_Area_Estado_Fecha creado.';
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
     WHERE object_id = OBJECT_ID(N'dbo.Usuario') AND name = N'IX_Usuario_EmpleadoId'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Usuario_EmpleadoId
        ON dbo.Usuario (EmpleadoId)
        WHERE EmpleadoId IS NOT NULL;
    PRINT 'Índice IX_Usuario_EmpleadoId creado.';
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
     WHERE object_id = OBJECT_ID(N'dbo.SolicitudReinicioPassword') AND name = N'IX_SRP_Estado_Fecha'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_SRP_Estado_Fecha
        ON dbo.SolicitudReinicioPassword (Estado, SolicitadoEn DESC)
        INCLUDE (UsuarioId);
    PRINT 'Índice IX_SRP_Estado_Fecha creado.';
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
     WHERE object_id = OBJECT_ID(N'dbo.ActualizacionesAndroid') AND name = N'IX_ActualizacionesAndroid_Fecha_Id'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_ActualizacionesAndroid_Fecha_Id
        ON dbo.ActualizacionesAndroid (Fecha DESC, IdApp DESC);
    PRINT 'Índice IX_ActualizacionesAndroid_Fecha_Id creado.';
END;
GO

-- ============================================================================
-- 3. PROCEDIMIENTOS DE EMPLEADOS Y PUESTOS NORMALIZADOS
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspEmpleadoListar
    @SoloActivos     BIT = 1,
    @EsMantenimiento BIT = NULL,
    @AreaId          NVARCHAR(15) = NULL,
    @Busqueda        NVARCHAR(100) = NULL,
    @Limit           INT = NULL,
    @Offset          INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @Offset < 0 SET @Offset = 0;

    SELECT
        e.EmpleadoId,
        e.NombreCompleto,
        e.AreaId,
        COALESCE(a.Nombre, e.NombreArea, N'Sin Área Asignada') AS NombreArea,
        e.PuestoId,
        COALESCE(p.Nombre, e.Puesto) AS Puesto,
        COALESCE(p.EsMantenimiento, e.EsMantenimiento) AS EsMantenimiento,
        e.Activo,
        e.CreadoEn,
        e.ActualizadoEn
    FROM dbo.Empleado e
    LEFT JOIN dbo.Area a ON e.AreaId = a.AreaId
    LEFT JOIN dbo.Puesto p ON e.PuestoId = p.PuestoId
    WHERE (@SoloActivos = 0 OR e.Activo = 1)
      AND (@EsMantenimiento IS NULL OR COALESCE(p.EsMantenimiento, e.EsMantenimiento) = @EsMantenimiento)
      AND (@AreaId IS NULL OR e.AreaId = @AreaId)
      AND (
          @Busqueda IS NULL
          OR LTRIM(RTRIM(@Busqueda)) = N''
          OR e.NombreCompleto LIKE CONCAT(N'%', LTRIM(RTRIM(@Busqueda)), N'%')
          OR COALESCE(p.Nombre, e.Puesto) LIKE CONCAT(N'%', LTRIM(RTRIM(@Busqueda)), N'%')
      )
    ORDER BY COALESCE(p.EsMantenimiento, e.EsMantenimiento) DESC, e.NombreCompleto ASC
    OFFSET @Offset ROWS
    FETCH NEXT CASE WHEN @Limit IS NULL OR @Limit <= 0 THEN 2147483647 ELSE @Limit END ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspEmpleadoCrear
    @NombreCompleto   NVARCHAR(150),
    @AreaId           NVARCHAR(15) = NULL,
    @Puesto           NVARCHAR(100) = NULL,
    @PuestoId         INT = NULL,
    @EsMantenimiento  BIT = 1,
    @UsuarioId        INT = NULL,
    @NombreUsuario    NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NombreLimpio NVARCHAR(150) = LTRIM(RTRIM(ISNULL(@NombreCompleto, N'')));
        DECLARE @PuestoLimpio NVARCHAR(100) = LTRIM(RTRIM(ISNULL(@Puesto, N'')));

        IF NULLIF(@NombreLimpio, N'') IS NULL
        BEGIN
            RAISERROR(N'El nombre completo del empleado es obligatorio.', 16, 1);
        END;

        -- Resolver PuestoId <-> Nombre desde catálogo dbo.Puesto
        IF @PuestoId IS NOT NULL
        BEGIN
            SELECT @PuestoLimpio = Nombre,
                   @EsMantenimiento = EsMantenimiento
              FROM dbo.Puesto
             WHERE PuestoId = @PuestoId AND Activo = 1;

            IF NULLIF(@PuestoLimpio, N'') IS NULL
            BEGIN
                RAISERROR(N'El puesto especificado no existe o está inactivo.', 16, 1);
            END;
        END
        ELSE
        BEGIN
            IF NULLIF(@PuestoLimpio, N'') IS NULL
            BEGIN
                RAISERROR(N'El puesto o cargo del empleado es obligatorio.', 16, 1);
            END;

            SELECT @PuestoId = PuestoId,
                   @PuestoLimpio = Nombre
              FROM dbo.Puesto
             WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio);

            IF @PuestoId IS NULL
            BEGIN
                INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
                VALUES (@PuestoLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
                SET @PuestoId = SCOPE_IDENTITY();
            END
            ELSE
            BEGIN
                UPDATE dbo.Puesto
                   SET Activo = 1,
                       ActualizadoEn = SYSUTCDATETIME()
                 WHERE PuestoId = @PuestoId AND Activo = 0;
            END;
        END;

        DECLARE @NombreArea NVARCHAR(200) = NULL;
        IF @AreaId IS NOT NULL
        BEGIN
            SELECT @NombreArea = Nombre FROM dbo.Area WHERE AreaId = @AreaId;
        END;

        INSERT INTO dbo.Empleado (NombreCompleto, AreaId, NombreArea, PuestoId, Puesto, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
        VALUES (@NombreLimpio, @AreaId, @NombreArea, @PuestoId, @PuestoLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

        DECLARE @NuevoId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'EMPLOYEE_CREATED', 'EMPLOYEES', CAST(@NuevoId AS NVARCHAR(20)),
                CONCAT(N'Empleado registrado: ', @NombreLimpio, N' (Puesto: ', @PuestoLimpio, N').'));

        COMMIT TRANSACTION;

        SELECT
            e.EmpleadoId,
            e.NombreCompleto,
            e.AreaId,
            COALESCE(a.Nombre, e.NombreArea, N'Sin Área') AS NombreArea,
            e.PuestoId,
            COALESCE(p.Nombre, e.Puesto) AS Puesto,
            COALESCE(p.EsMantenimiento, e.EsMantenimiento) AS EsMantenimiento,
            e.Activo,
            e.CreadoEn,
            e.ActualizadoEn
        FROM dbo.Empleado e
        LEFT JOIN dbo.Area a ON e.AreaId = a.AreaId
        LEFT JOIN dbo.Puesto p ON e.PuestoId = p.PuestoId
        WHERE e.EmpleadoId = @NuevoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspEmpleadoActualizar
    @EmpleadoId       INT,
    @NombreCompleto   NVARCHAR(150),
    @AreaId           NVARCHAR(15) = NULL,
    @Puesto           NVARCHAR(100) = NULL,
    @PuestoId         INT = NULL,
    @EsMantenimiento  BIT = 1,
    @Activo           BIT = 1,
    @UsuarioId        INT = NULL,
    @NombreUsuario    NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Empleado WHERE EmpleadoId = @EmpleadoId)
        BEGIN
            RAISERROR(N'El empleado especificado no existe.', 16, 1);
        END;

        DECLARE @NombreLimpio NVARCHAR(150) = LTRIM(RTRIM(ISNULL(@NombreCompleto, N'')));
        DECLARE @PuestoLimpio NVARCHAR(100) = LTRIM(RTRIM(ISNULL(@Puesto, N'')));

        IF NULLIF(@NombreLimpio, N'') IS NULL
        BEGIN
            RAISERROR(N'El nombre completo del empleado es obligatorio.', 16, 1);
        END;

        IF @PuestoId IS NOT NULL
        BEGIN
            SELECT @PuestoLimpio = Nombre,
                   @EsMantenimiento = EsMantenimiento
              FROM dbo.Puesto
             WHERE PuestoId = @PuestoId;

            IF NULLIF(@PuestoLimpio, N'') IS NULL
            BEGIN
                RAISERROR(N'El puesto especificado no existe.', 16, 1);
            END;
        END
        ELSE
        BEGIN
            IF NULLIF(@PuestoLimpio, N'') IS NULL
            BEGIN
                RAISERROR(N'El puesto o cargo del empleado es obligatorio.', 16, 1);
            END;

            SELECT @PuestoId = PuestoId,
                   @PuestoLimpio = Nombre
              FROM dbo.Puesto
             WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio);

            IF @PuestoId IS NULL
            BEGIN
                INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
                VALUES (@PuestoLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
                SET @PuestoId = SCOPE_IDENTITY();
            END;
        END;

        DECLARE @NombreArea NVARCHAR(200) = NULL;
        IF @AreaId IS NOT NULL
        BEGIN
            SELECT @NombreArea = Nombre FROM dbo.Area WHERE AreaId = @AreaId;
        END;

        UPDATE dbo.Empleado
           SET NombreCompleto  = @NombreLimpio,
               AreaId          = @AreaId,
               NombreArea      = @NombreArea,
               PuestoId        = @PuestoId,
               Puesto          = @PuestoLimpio,
               EsMantenimiento = @EsMantenimiento,
               Activo          = @Activo,
               ActualizadoEn   = SYSUTCDATETIME()
         WHERE EmpleadoId      = @EmpleadoId;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'EMPLOYEE_UPDATED', 'EMPLOYEES', CAST(@EmpleadoId AS NVARCHAR(20)),
                CONCAT(N'Empleado actualizado: ', @NombreLimpio, N' (Puesto: ', @PuestoLimpio, N', Activo: ', @Activo, N').'));

        COMMIT TRANSACTION;

        SELECT
            e.EmpleadoId,
            e.NombreCompleto,
            e.AreaId,
            COALESCE(a.Nombre, e.NombreArea, N'Sin Área') AS NombreArea,
            e.PuestoId,
            COALESCE(p.Nombre, e.Puesto) AS Puesto,
            COALESCE(p.EsMantenimiento, e.EsMantenimiento) AS EsMantenimiento,
            e.Activo,
            e.CreadoEn,
            e.ActualizadoEn
        FROM dbo.Empleado e
        LEFT JOIN dbo.Area a ON e.AreaId = a.AreaId
        LEFT JOIN dbo.Puesto p ON e.PuestoId = p.PuestoId
        WHERE e.EmpleadoId = @EmpleadoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPuestoActualizar
    @PuestoId        INT,
    @Nombre          NVARCHAR(100),
    @EsMantenimiento BIT,
    @UsuarioId       INT = NULL,
    @NombreUsuario   NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NombreLimpio NVARCHAR(100) = LTRIM(RTRIM(@Nombre));

        IF NULLIF(@NombreLimpio, N'') IS NULL
        BEGIN
            RAISERROR(N'El nombre del puesto es obligatorio.', 16, 1);
        END;

        DECLARE @NombreAntiguo NVARCHAR(100);
        SELECT @NombreAntiguo = Nombre
          FROM dbo.Puesto WITH (UPDLOCK, HOLDLOCK)
         WHERE PuestoId = @PuestoId;

        IF @NombreAntiguo IS NULL
        BEGIN
            RAISERROR(N'El puesto especificado no existe.', 16, 1);
        END;

        IF EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = @NombreLimpio AND PuestoId <> @PuestoId AND Activo = 1)
        BEGIN
            RAISERROR(N'Ya existe otro puesto con el nombre especificado.', 16, 1);
        END;

        UPDATE dbo.Puesto
           SET Nombre          = @NombreLimpio,
               EsMantenimiento = @EsMantenimiento,
               ActualizadoEn   = SYSUTCDATETIME()
         WHERE PuestoId        = @PuestoId;

        -- Mantener sincronizados los empleados ligados por PuestoId o nombre antiguo
        UPDATE dbo.Empleado
           SET PuestoId        = @PuestoId,
               Puesto          = @NombreLimpio,
               EsMantenimiento = @EsMantenimiento,
               ActualizadoEn   = SYSUTCDATETIME()
         WHERE PuestoId = @PuestoId
            OR (PuestoId IS NULL AND Puesto = @NombreAntiguo);

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'POSITION_UPDATED', 'EMPLOYEES', CAST(@PuestoId AS NVARCHAR(20)),
                CONCAT(N'Puesto modificado: "', @NombreAntiguo, N'" -> "', @NombreLimpio, N'". Mantenimiento: ', @EsMantenimiento));

        COMMIT TRANSACTION;

        SELECT
            p.PuestoId,
            p.Nombre,
            p.EsMantenimiento,
            p.Activo,
            p.CreadoEn,
            p.ActualizadoEn
        FROM dbo.Puesto p
        WHERE p.PuestoId = @PuestoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 4. PAGINACIÓN OPCIONAL EN LISTADOS MASIVOS (Backwards-compatible)
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspKardexObtenerTodos
    @ModuleFilter NVARCHAR(20) = NULL,
    @ActionFilter NVARCHAR(40) = NULL,
    @UserFilter   INT = NULL,
    @StartDate    DATETIME2(3) = NULL,
    @EndDate      DATETIME2(3) = NULL,
    @Limit        INT = 200,
    @Offset       INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @Offset < 0 SET @Offset = 0;
    IF @Limit IS NULL OR @Limit <= 0 SET @Limit = 200;

    SELECT BitacoraId AS LogId,
           RegistradoEn AS LoggedAt,
           UsuarioId AS UserId,
           NombreUsuario AS UserName,
           Accion AS Action,
           Modulo AS Module,
           EntidadId AS EntityId,
           Detalles AS Details
      FROM dbo.BitacoraKardex
     WHERE (@ModuleFilter IS NULL OR Modulo = @ModuleFilter)
       AND (@ActionFilter IS NULL OR Accion = @ActionFilter)
       AND (@UserFilter   IS NULL OR UsuarioId = @UserFilter)
       AND (@StartDate    IS NULL OR RegistradoEn >= @StartDate)
       AND (@EndDate      IS NULL OR RegistradoEn <= @EndDate)
     ORDER BY RegistradoEn DESC
    OFFSET @Offset ROWS
    FETCH NEXT @Limit ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoObtenerTodas
    @StatusFilter NVARCHAR(15) = NULL,
    @AreaFilter   NVARCHAR(15) = NULL,
    @Limit        INT = NULL,
    @Offset       INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @Offset < 0 SET @Offset = 0;

    SELECT w.OrdenTrabajoId AS WorkOrderId,
           w.CodigoActivo AS AssetCode,
           w.NombreActivo AS AssetName,
           w.AreaId,
           COALESCE(ar.Nombre, w.NombreArea) AS AreaName,
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
      LEFT JOIN dbo.Area ar ON w.AreaId = ar.AreaId
      LEFT JOIN dbo.ReporteAveria ra ON w.ReporteId = ra.ReporteId
     OUTER APPLY (
         SELECT (
             SELECT NumeroLinea AS LineNum,
                    Descripcion AS Description,
                    Cantidad AS Quantity,
                    Unidad AS Unit
               FROM dbo.MaterialOrdenTrabajo
              WHERE OrdenTrabajoId = w.OrdenTrabajoId
              ORDER BY NumeroLinea
                FOR JSON PATH
         ) AS MaterialsJson
     ) m
     OUTER APPLY (
         SELECT STRING_AGG(TipoTrabajo, ',') AS WorkTypesCsv
           FROM dbo.TipoTrabajoOrdenTrabajo
          WHERE OrdenTrabajoId = w.OrdenTrabajoId
     ) t
     WHERE (@StatusFilter IS NULL OR w.Estado = @StatusFilter)
       AND (@AreaFilter   IS NULL OR w.AreaId = @AreaFilter)
     ORDER BY w.CreadoEn DESC
    OFFSET @Offset ROWS
    FETCH NEXT CASE WHEN @Limit IS NULL OR @Limit <= 0 THEN 2147483647 ELSE @Limit END ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaObtenerTodos
    @StatusFilter NVARCHAR(15) = NULL,
    @StartDate    DATETIME2(3) = NULL,
    @EndDate      DATETIME2(3) = NULL,
    @Limit        INT = NULL,
    @Offset       INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @Offset < 0 SET @Offset = 0;

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
     ORDER BY ReportadoEn DESC
    OFFSET @Offset ROWS
    FETCH NEXT CASE WHEN @Limit IS NULL OR @Limit <= 0 THEN 2147483647 ELSE @Limit END ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoBuscar
    @AreaId NVARCHAR(15) = NULL,
    @Query  NVARCHAR(200),
    @Status NVARCHAR(25) = NULL,
    @Limit  INT = 200,
    @Offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @Offset < 0 SET @Offset = 0;
    IF @Limit IS NULL OR @Limit <= 0 SET @Limit = 200;

    SELECT a.CodigoActivo AS AssetCode,
           a.Nombre AS Name,
           a.Marca AS Brand,
           a.Modelo AS Model,
           a.AreaId,
           a.EstacionId AS StationId,
           a.CodigoActivoPadre AS ParentAssetCode,
           a.Nivel AS Level,
           a.RutaAncestros AS AncestorsPath,
           a.Estado AS Status,
           a.TraspasadoACodigo AS TransferredToId,
           a.Serie AS Serial,
           a.AtributosDinamicos AS DynamicAttributes,
           a.DatosImagen AS ImageData,
           a.ContadorHijos AS ChildCounter,
           a.CreadoEn AS CreatedAt,
           a.ActualizadoEn AS UpdatedAt,
           a.EsEquipoProceso AS EsEquipoProceso
      FROM dbo.Activo a
     CROSS APPLY (SELECT COUNT(*) AS TokenCount FROM STRING_SPLIT(@Query, ' ') WHERE LTRIM(RTRIM(value)) <> '') cnt
     WHERE (@AreaId IS NULL OR a.AreaId = @AreaId)
       AND a.Estado <> 'deleted'
       AND (@Status IS NULL OR a.Estado = @Status)
       AND (cnt.TokenCount = 0 OR
            (SELECT COUNT(*) FROM STRING_SPLIT(@Query, ' ') t
              WHERE t.value <> '' AND a.TextoBusqueda LIKE '%' + t.value + '%') = cnt.TokenCount)
     ORDER BY a.Nombre ASC
    OFFSET @Offset ROWS
    FETCH NEXT @Limit ROWS ONLY;
END;
GO

-- ============================================================================
-- 5. CATÁLOGOS DINÁMICOS DESDE BASE DE DATOS (Evita hardcoding en API/App)
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspCatalogosObtener
AS
BEGIN
    SET NOCOUNT ON;

    -- Result set 0: Roles
    SELECT CodigoRol, Nombre
      FROM dbo.Rol
     ORDER BY CASE CodigoRol
         WHEN N'admin' THEN 1
         WHEN N'jefe' THEN 2
         WHEN N'jefe_area' THEN 3
         WHEN N'reportador' THEN 4
         WHEN N'lector' THEN 5
         ELSE 99
     END, Nombre;

    -- Result set 1: Permisos disponibles
    SELECT CodigoPermiso
      FROM dbo.Permiso
     ORDER BY CodigoPermiso;

    -- Result set 2: Matriz Rol -> Permiso
    SELECT CodigoRol, CodigoPermiso
      FROM dbo.RolPermiso
     ORDER BY CodigoRol, CodigoPermiso;

    -- Result set 3: Puestos activos
    SELECT PuestoId, Nombre, EsMantenimiento
      FROM dbo.Puesto
     WHERE Activo = 1
     ORDER BY Nombre;
END;
GO

GRANT EXECUTE ON dbo.uspCatalogosObtener TO macsa_app;
GRANT EXECUTE ON dbo.uspEmpleadoListar TO macsa_app;
GRANT EXECUTE ON dbo.uspEmpleadoCrear TO macsa_app;
GRANT EXECUTE ON dbo.uspEmpleadoActualizar TO macsa_app;
GRANT EXECUTE ON dbo.uspPuestoActualizar TO macsa_app;
GRANT EXECUTE ON dbo.uspKardexObtenerTodos TO macsa_app;
GRANT EXECUTE ON dbo.uspOrdenTrabajoObtenerTodas TO macsa_app;
GRANT EXECUTE ON dbo.uspReporteAveriaObtenerTodos TO macsa_app;
GRANT EXECUTE ON dbo.uspActivoBuscar TO macsa_app;
GO

PRINT 'Migración de Normalización y Escalabilidad completada exitosamente.';
GO
