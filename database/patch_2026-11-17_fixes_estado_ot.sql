-- ============================================================================
-- PARCHE 2026-11-17: CORRECCIÓN DE CAMBIO DE ESTADO DE ACTIVOS Y CREACIÓN DE OT
-- Grupo Macsa - CMMS
-- ============================================================================
-- 1. Corrige dbo.uspActivoAlternarEstado:
--    - Elimina inserción NULL en HistorialEstadoActivo.Estado
--    - Soporta de forma unificada @NewStatus y @Status
--    - Soporta de forma unificada @AssetCode y @CodigoActivo
--    - Compilado con SET ANSI_NULLS ON y SET QUOTED_IDENTIFIER ON
--
-- 2. Corrige dbo.uspActivoActualizar:
--    - Actualiza el Estado si se modifica en el formulario de edición de activo
--    - Inserta registro en HistorialEstadoActivo si el estado cambia
--    - Evita violación de restricción NOT NULL en EstacionId
--    - Compilado con SET ANSI_NULLS ON y SET QUOTED_IDENTIFIER ON
--
-- 3. Corrige dbo.uspOrdenTrabajoCrear:
--    - Auto-resuelve AreaId y NombreArea a partir de CodigoActivo si vienen vacíos
--    - Evita violación de FK_OT_Area ante strings vacíos ('' -> NULL)
--    - Inicializa correlativo Contador si la fila no existe
--    - Compilado con SET ANSI_NULLS ON y SET QUOTED_IDENTIFIER ON
-- ============================================================================

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ----------------------------------------------------------------------------
-- 1. ALTER dbo.uspActivoAlternarEstado
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.uspActivoAlternarEstado
    @AssetCode    NVARCHAR(60) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @NewStatus    NVARCHAR(25) = NULL,
    @Status       NVARCHAR(25) = NULL,
    @Reason       NVARCHAR(500) = NULL,
    @UserId       INT = NULL,
    @UserName     NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Code NVARCHAR(60) = COALESCE(NULLIF(LTRIM(RTRIM(@AssetCode)), N''), NULLIF(LTRIM(RTRIM(@CodigoActivo)), N''));
        DECLARE @TargetStatus NVARCHAR(25) = COALESCE(NULLIF(LTRIM(RTRIM(@NewStatus)), N''), NULLIF(LTRIM(RTRIM(@Status)), N''));

        IF @Code IS NULL
            RAISERROR(N'Debe especificarse el código del activo.', 16, 1);

        IF @TargetStatus IS NULL
            RAISERROR(N'Debe especificarse el nuevo estado del activo.', 16, 1);

        DECLARE @currStatus NVARCHAR(25), @ar NVARCHAR(15), @nm NVARCHAR(200);
        SELECT @currStatus = Estado, @ar = AreaId, @nm = Nombre
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @Code;

        IF @currStatus IS NULL
            RAISERROR(N'El activo no existe.', 16, 1);

        UPDATE dbo.Activo
           SET Estado = @TargetStatus,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @Code;

        UPDATE dbo.HistorialEstadoActivo
           SET FinalizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @Code AND FinalizadoEn IS NULL;

        INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        VALUES (@Code, @TargetStatus, SYSUTCDATETIME(), @ar, @Reason, @UserId, COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA'));

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA'), 'ASSET_STATUS_CHANGED', 'ASSETS', @Code,
                CONCAT(N'Estado de ', @Code, N' cambiado a: ', @TargetStatus, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 2. ALTER dbo.uspActivoActualizar
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.uspActivoActualizar
    @CodigoActivo NVARCHAR(60) = NULL,
    @AssetCode NVARCHAR(60) = NULL,
    @Name NVARCHAR(200) = NULL,
    @Brand NVARCHAR(100) = NULL,
    @Model NVARCHAR(100) = NULL,
    @StationId NVARCHAR(100) = NULL,
    @Serial NVARCHAR(100) = NULL,
    @DynamicAttributes NVARCHAR(MAX) = NULL,
    @ImageData NVARCHAR(500) = NULL,
    @Status NVARCHAR(25) = NULL,
    @Estado NVARCHAR(25) = NULL,
    @Observaciones NVARCHAR(MAX) = NULL,
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @TargetCode NVARCHAR(60) = COALESCE(NULLIF(LTRIM(RTRIM(@AssetCode)), ''), NULLIF(LTRIM(RTRIM(@CodigoActivo)), ''));

        IF @TargetCode IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Activo WHERE CodigoActivo = @TargetCode)
            RAISERROR(N'El activo no existe.', 16, 1);

        IF @Serial IS NOT NULL AND LTRIM(RTRIM(@Serial)) <> ''
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Activo WHERE Serie = @Serial AND CodigoActivo <> @TargetCode AND Estado <> 'deleted')
                RAISERROR(N'El número de serie ya está en uso por otro activo activo.', 16, 1);
        END;

        DECLARE @currStatus NVARCHAR(25), @currArea NVARCHAR(15);
        SELECT @currStatus = Estado, @currArea = AreaId
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @TargetCode;

        DECLARE @DesiredStatus NVARCHAR(25) = COALESCE(NULLIF(LTRIM(RTRIM(@Status)), N''), NULLIF(LTRIM(RTRIM(@Estado)), N''));

        UPDATE dbo.Activo
           SET Nombre             = COALESCE(@Name, Nombre),
               Marca              = @Brand,
               Modelo             = @Model,
               EstacionId         = COALESCE(@StationId, EstacionId, ''),
               Serie              = NULLIF(@Serial, ''),
               AtributosDinamicos = COALESCE(@DynamicAttributes, AtributosDinamicos),
               DatosImagen        = COALESCE(@ImageData, DatosImagen),
               Observaciones      = COALESCE(@Observaciones, Observaciones),
               Estado             = COALESCE(@DesiredStatus, Estado),
               ActualizadoEn      = SYSUTCDATETIME()
         WHERE CodigoActivo = @TargetCode;

        -- Si el estado deseado es válido y difiere del actual, actualizar historial
        IF @DesiredStatus IS NOT NULL AND @DesiredStatus <> @currStatus
        BEGIN
            UPDATE dbo.HistorialEstadoActivo
               SET FinalizadoEn = SYSUTCDATETIME()
             WHERE CodigoActivo = @TargetCode AND FinalizadoEn IS NULL;

            INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
            VALUES (@TargetCode, @DesiredStatus, SYSUTCDATETIME(), @currArea, N'Modificación de estado en edición de activo', @UserId, COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA'));
        END;

        IF @UserId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UserId)
        BEGIN
            SELECT @UserId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@UserName)));
            IF @UserId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UserId)
                SET @UserId = NULL;
        END;

        DECLARE @UNameAuditUpd NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UNameAuditUpd, 'ASSET_UPDATED', 'ASSETS', @TargetCode,
                CONCAT(N'Activo actualizado: ', @TargetCode, N' (', COALESCE(@Name, @TargetCode), N').'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 3. ALTER dbo.uspOrdenTrabajoCrear
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.uspOrdenTrabajoCrear
    @AssetCode NVARCHAR(60) = N'',
    @AssetName NVARCHAR(200),
    @AreaId NVARCHAR(15) = NULL,
    @AreaName NVARCHAR(200) = NULL,
    @Description NVARCHAR(MAX),
    @Priority NVARCHAR(10) = N'medium',
    @AssignedTo NVARCHAR(200) = NULL,
    @AssignedStaffCount INT = NULL,
    @EstimatedHours DECIMAL(6,2) = NULL,
    @ScheduledDate DATETIME2(3) = NULL,
    @ReportId BIGINT = NULL,
    @CreatedByUserId INT = NULL,
    @CreatedByUserName NVARCHAR(100) = N'',
    @Materials dbo.TipoMaterialOrdenTrabajo READONLY,
    @WorkTypes dbo.TipoListaTexto READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        SET @AssetCode = NULLIF(LTRIM(RTRIM(@AssetCode)), N'');
        SET @AreaId = NULLIF(LTRIM(RTRIM(@AreaId)), N'');
        SET @AreaName = NULLIF(LTRIM(RTRIM(@AreaName)), N'');

        -- Auto-resolución de Área si viene vacía pero viene el activo
        IF @AreaId IS NULL AND @AssetCode IS NOT NULL
        BEGIN
            SELECT @AreaId = a.AreaId,
                   @AreaName = COALESCE(@AreaName, ar.Nombre)
              FROM dbo.Activo a
              LEFT JOIN dbo.Area ar ON ar.AreaId = a.AreaId
             WHERE a.CodigoActivo = @AssetCode;
        END;

        IF @AreaName IS NULL AND @AreaId IS NOT NULL
        BEGIN
            SELECT @AreaName = Nombre FROM dbo.Area WHERE AreaId = @AreaId;
        END;

        IF @AssetCode IS NOT NULL
        BEGIN
            DECLARE @OTExistenteId NVARCHAR(20);
            SELECT TOP 1 @OTExistenteId = OrdenTrabajoId
              FROM dbo.OrdenTrabajo WITH (UPDLOCK, HOLDLOCK)
             WHERE CodigoActivo = @AssetCode
               AND Estado IN (N'pending', N'inProgress', N'in_progress', N'paused');

            IF @OTExistenteId IS NOT NULL
            BEGIN
                DECLARE @MsgOT NVARCHAR(250) = CONCAT(N'El activo ', @AssetCode, N' ya cuenta con una orden de trabajo abierta (', @OTExistenteId, N'). Debe concluirse o cancelarse antes de emitir una nueva.');
                RAISERROR(@MsgOT, 16, 1);
            END;
        END;

        DECLARE @cCount TABLE (v INT NOT NULL);
        UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
           SET SiguienteNumero += 1
         OUTPUT deleted.SiguienteNumero INTO @cCount(v)
          WHERE Nombre = 'work_orders';

        DECLARE @seq INT; SELECT @seq = v FROM @cCount;
        IF @seq IS NULL
        BEGIN
            INSERT INTO dbo.Contador (Nombre, SiguienteNumero) VALUES ('work_orders', 2);
            SET @seq = 1;
        END;

        DECLARE @woId NVARCHAR(20) = CONCAT('OT-', YEAR(SYSUTCDATETIME()), '-', FORMAT(@seq, '0000'));

        INSERT INTO dbo.OrdenTrabajo
            (OrdenTrabajoId, CodigoActivo, NombreActivo, AreaId, NombreArea, Descripcion,
             Estado, Prioridad, AsignadoA, CantidadPersonalAsignado, HorasEstimadas,
             FechaProgramada, ReporteId, CreadoPorUsuarioId, CreadoPorNombreUsuario, CreadoEn)
        VALUES
            (@woId, @AssetCode, @AssetName, @AreaId, @AreaName, @Description,
             'pending', @Priority, @AssignedTo, @AssignedStaffCount, @EstimatedHours,
             @ScheduledDate, @ReportId, @CreatedByUserId, COALESCE(NULLIF(LTRIM(RTRIM(@CreatedByUserName)), N''), N'SISTEMA'), SYSUTCDATETIME());

        INSERT INTO dbo.MaterialOrdenTrabajo (OrdenTrabajoId, NumeroLinea, Descripcion, Cantidad, Unidad)
        SELECT @woId, ROW_NUMBER() OVER (ORDER BY NumeroLinea), Descripcion, Cantidad, ISNULL(Unidad, 'pz')
          FROM @Materials;

        INSERT INTO dbo.TipoTrabajoOrdenTrabajo (OrdenTrabajoId, TipoTrabajo)
        SELECT DISTINCT @woId, LTRIM(RTRIM(Valor)) FROM @WorkTypes WHERE LTRIM(RTRIM(Valor)) <> '';

        IF @ReportId IS NOT NULL
        BEGIN
            UPDATE dbo.ReporteAveria
               SET OrdenTrabajoId = @woId, Estado = 'inWorkOrder'
             WHERE ReporteId = @ReportId;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@CreatedByUserId, COALESCE(NULLIF(LTRIM(RTRIM(@CreatedByUserName)), N''), N'SISTEMA'), 'WORK_ORDER_CREATED', 'WORK_ORDERS', @woId,
                CONCAT(N'OT creada: ', @woId, N' para ', @AssetName, N' (Prioridad: ', @Priority, N').'));

        COMMIT TRANSACTION;
        SELECT @woId AS WorkOrderId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT 'Parche 2026-11-17 aplicado correctamente en MacsaCMMS.';
GO
