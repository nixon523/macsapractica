-- ----------------------------------------------------------------------------
-- 14. PROCEDIMIENTOS ALMACENADOS: ACTIVOS, JERARQUÍA Y TRASPASOS
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspActivoObtenerRaicesPorArea
    @AreaId NVARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CodigoActivo, CodigoActivo AS assetCode,
           Nombre, Nombre AS name,
           Marca, Marca AS brand,
           Modelo, Modelo AS model,
           AreaId, AreaId AS areaId,
           EstacionId, EstacionId AS stationId,
           CodigoActivoPadre, CodigoActivoPadre AS parentAssetCode, CodigoActivoPadre AS parentAssetId,
           Nivel, Nivel AS [level],
           RutaAncestros, RutaAncestros AS ancestorsPath,
           Estado, Estado AS [status],
           Serie, Serie AS [serial],
           AtributosDinamicos, AtributosDinamicos AS dynamicAttributes,
           DatosImagen, DatosImagen AS imageData,
           ContadorHijos, CreadoEn, ActualizadoEn,
           EsEquipoProceso
      FROM dbo.Activo
     WHERE AreaId = @AreaId
       AND CodigoActivoPadre IS NULL
       AND Estado <> 'deleted'
     ORDER BY CodigoActivo ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoObtenerHijos
    @ParentAssetCode NVARCHAR(60) = NULL,
    @ParentCode      NVARCHAR(60) = NULL,
    @AreaId          NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TargetParent NVARCHAR(60) = COALESCE(@ParentAssetCode, @ParentCode);
    SELECT CodigoActivo, CodigoActivo AS assetCode,
           Nombre, Nombre AS name,
           Marca, Marca AS brand,
           Modelo, Modelo AS model,
           AreaId, AreaId AS areaId,
           EstacionId, EstacionId AS stationId,
           CodigoActivoPadre, CodigoActivoPadre AS parentAssetCode, CodigoActivoPadre AS parentAssetId,
           Nivel, Nivel AS [level],
           RutaAncestros, RutaAncestros AS ancestorsPath,
           Estado, Estado AS [status],
           Serie, Serie AS [serial],
           AtributosDinamicos, AtributosDinamicos AS dynamicAttributes,
           DatosImagen, DatosImagen AS imageData,
           ContadorHijos, CreadoEn, ActualizadoEn,
           EsEquipoProceso
      FROM dbo.Activo
     WHERE (@TargetParent IS NULL AND CodigoActivoPadre IS NULL OR CodigoActivoPadre = @TargetParent)
       AND (@AreaId IS NULL OR AreaId = @AreaId)
       AND Estado <> 'deleted'
     ORDER BY CodigoActivo ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoBuscar
    @Query NVARCHAR(100),
    @AreaId NVARCHAR(15) = NULL,
    @Level NVARCHAR(20) = NULL,
    @Status NVARCHAR(25) = NULL,
    @Limit INT = NULL,
    @Offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CleanQuery NVARCHAR(100) = LTRIM(RTRIM(@Query));

    SELECT CodigoActivo, CodigoActivo AS assetCode,
           Nombre, Nombre AS name,
           Marca, Marca AS brand,
           Modelo, Modelo AS model,
           AreaId, AreaId AS areaId,
           EstacionId, EstacionId AS stationId,
           CodigoActivoPadre, CodigoActivoPadre AS parentAssetCode, CodigoActivoPadre AS parentAssetId,
           Nivel, Nivel AS [level],
           RutaAncestros, RutaAncestros AS ancestorsPath,
           Estado, Estado AS [status],
           Serie, Serie AS [serial],
           AtributosDinamicos, AtributosDinamicos AS dynamicAttributes,
           DatosImagen, DatosImagen AS imageData,
           ContadorHijos, CreadoEn, ActualizadoEn,
           EsEquipoProceso
      FROM dbo.Activo
     WHERE (@AreaId IS NULL OR AreaId = @AreaId)
       AND (@Level IS NULL OR Nivel = @Level)
       AND (@Status IS NULL OR Estado = @Status)
       AND (
           @CleanQuery IS NULL
           OR @CleanQuery = ''
           OR TextoBusqueda LIKE CONCAT('%', @CleanQuery, '%')
       )
     ORDER BY CodigoActivo ASC
     OFFSET @Offset ROWS
     FETCH NEXT CASE WHEN @Limit IS NULL OR @Limit <= 0 THEN 2147483647 ELSE @Limit END ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoBuscarPorSerie
    @Serial NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CodigoActivo, CodigoActivo AS assetCode,
           Nombre, Nombre AS name,
           Marca, Marca AS brand,
           Modelo, Modelo AS model,
           AreaId, AreaId AS areaId,
           EstacionId, EstacionId AS stationId,
           CodigoActivoPadre, CodigoActivoPadre AS parentAssetCode, CodigoActivoPadre AS parentAssetId,
           Nivel, Nivel AS [level],
           RutaAncestros, RutaAncestros AS ancestorsPath,
           Estado, Estado AS [status],
           Serie, Serie AS [serial],
           AtributosDinamicos, AtributosDinamicos AS dynamicAttributes,
           DatosImagen, DatosImagen AS imageData,
           ContadorHijos, CreadoEn, ActualizadoEn,
           EsEquipoProceso
      FROM dbo.Activo
     WHERE Serie = @Serial AND Estado <> 'deleted';
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoCrear
    @Name NVARCHAR(200),
    @Brand NVARCHAR(100) = NULL,
    @Model NVARCHAR(100) = NULL,
    @AreaId NVARCHAR(15),
    @StationId NVARCHAR(100) = '',
    @Level NVARCHAR(20),
    @ParentAssetCode NVARCHAR(60) = NULL,
    @Status NVARCHAR(25) = 'active',
    @Serial NVARCHAR(100) = NULL,
    @DynamicAttributes NVARCHAR(MAX) = NULL,
    @ImageData NVARCHAR(500) = NULL,
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Serial IS NOT NULL AND LTRIM(RTRIM(@Serial)) <> ''
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Activo WHERE Serie = @Serial AND Estado <> 'deleted')
                RAISERROR(N'El número de serie ya está en uso por otro activo activo.', 16, 1);
        END;

        DECLARE @NewAssetCode NVARCHAR(60);
        DECLARE @AncestorsPath NVARCHAR(400) = '';

        IF @ParentAssetCode IS NULL OR LTRIM(RTRIM(@ParentAssetCode)) = ''
        BEGIN
            DECLARE @acTable TABLE (val INT NOT NULL);
            UPDATE dbo.Area WITH (UPDLOCK, HOLDLOCK)
               SET ContadorActivos += 1
             OUTPUT inserted.ContadorActivos INTO @acTable(val)
              WHERE AreaId = @AreaId;

            DECLARE @ac INT; SELECT @ac = val FROM @acTable;
            IF @ac IS NULL
                RAISERROR(N'El área no existe.', 16, 1);

            SET @NewAssetCode = CONCAT(@AreaId, '-', FORMAT(@ac, '000'));
        END
        ELSE
        BEGIN
            DECLARE @parentStatus NVARCHAR(25), @parentAncestors NVARCHAR(400);
            DECLARE @pcTable TABLE (val INT NOT NULL);

            SELECT @parentStatus = Estado, @parentAncestors = RutaAncestros
              FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
             WHERE CodigoActivo = @ParentAssetCode;

            IF @parentStatus IS NULL
                RAISERROR(N'El activo padre no existe.', 16, 1);
            IF @parentStatus <> 'active'
                RAISERROR(N'El activo padre no está activo.', 16, 1);
            IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE CodigoActivo = @ParentAssetCode AND EstadoCandado = 'pending')
                RAISERROR(N'El activo padre tiene una solicitud de baja pendiente.', 16, 1);

            UPDATE dbo.Activo WITH (UPDLOCK, HOLDLOCK)
               SET ContadorHijos += 1
             OUTPUT inserted.ContadorHijos INTO @pcTable(val)
              WHERE CodigoActivo = @ParentAssetCode;

            DECLARE @pc INT; SELECT @pc = val FROM @pcTable;
            SET @NewAssetCode = CONCAT(@ParentAssetCode, '-', FORMAT(@pc, '00'));
            SET @AncestorsPath = CASE WHEN @parentAncestors = '' THEN @ParentAssetCode
                                      ELSE CONCAT(@parentAncestors, '/', @ParentAssetCode) END;
        END;

        INSERT INTO dbo.Activo
            (CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, CodigoActivoPadre,
             Nivel, RutaAncestros, Estado, Serie, AtributosDinamicos, DatosImagen,
             ContadorHijos, CreadoEn)
        VALUES
            (@NewAssetCode, @Name, @Brand, @Model, @AreaId, @StationId, @ParentAssetCode,
             @Level, @AncestorsPath, @Status, NULLIF(@Serial, ''), @DynamicAttributes, @ImageData,
             0, SYSUTCDATETIME());

        IF @UserId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UserId)
        BEGIN
            SELECT @UserId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@UserName)));
            IF @UserId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UserId)
                SET @UserId = NULL;
        END;

        DECLARE @UNameAudit NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA');

        INSERT INTO dbo.HistorialEstadoActivo
            (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        VALUES
            (@NewAssetCode, @Status, SYSUTCDATETIME(), @AreaId, N'Alta inicial del activo', @UserId, @UNameAudit);

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UNameAudit, 'ASSET_CREATED', 'ASSETS', @NewAssetCode,
                CONCAT(N'Activo creado: ', @NewAssetCode, N' (', @Name, N') en área ', @AreaId, N'.'));

        COMMIT TRANSACTION;
        SELECT @NewAssetCode AS CodigoActivo, @NewAssetCode AS assetCode, @NewAssetCode AS NewAssetCode;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoActualizar
    @CodigoActivo NVARCHAR(60) = NULL,
    @AssetCode NVARCHAR(60),
    @Name NVARCHAR(200),
    @Brand NVARCHAR(100) = NULL,
    @Model NVARCHAR(100) = NULL,
    @StationId NVARCHAR(100) = '',
    @Serial NVARCHAR(100) = NULL,
    @DynamicAttributes NVARCHAR(MAX) = NULL,
    @ImageData NVARCHAR(500) = NULL,
    @Status NVARCHAR(25) = NULL,
    @Estado NVARCHAR(25) = NULL,
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Activo WHERE CodigoActivo = @AssetCode)
            RAISERROR(N'El activo no existe.', 16, 1);

        IF @Serial IS NOT NULL AND LTRIM(RTRIM(@Serial)) <> ''
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Activo WHERE Serie = @Serial AND CodigoActivo <> @AssetCode AND Estado <> 'deleted')
                RAISERROR(N'El número de serie ya está en uso por otro activo activo.', 16, 1);
        END;

        UPDATE dbo.Activo
           SET Nombre             = @Name,
               Marca              = @Brand,
               Modelo             = @Model,
               EstacionId         = @StationId,
               Serie              = NULLIF(@Serial, ''),
               AtributosDinamicos = @DynamicAttributes,
               DatosImagen        = COALESCE(@ImageData, DatosImagen),
               ActualizadoEn      = SYSUTCDATETIME()
         WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);

        IF @UserId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UserId)
        BEGIN
            SELECT @UserId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@UserName)));
            IF @UserId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UserId)
                SET @UserId = NULL;
        END;

        DECLARE @UNameAuditUpd NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UNameAuditUpd, 'ASSET_UPDATED', 'ASSETS', @AssetCode,
                CONCAT(N'Activo actualizado: ', @AssetCode, N' (', @Name, N').'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoTraspasar
    @SourceAssetCode NVARCHAR(60),
    @TargetAreaId    NVARCHAR(15),
    @UserId          INT = NULL,
    @UserName        NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @srcArea NVARCHAR(15), @srcName NVARCHAR(200), @srcStatus NVARCHAR(25), @srcLevel NVARCHAR(20);
        SELECT @srcArea = AreaId, @srcName = Nombre, @srcStatus = Estado, @srcLevel = Nivel
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @SourceAssetCode;

        IF @srcArea IS NULL OR @srcStatus = 'deleted'
            RAISERROR(N'El activo origen no existe o está eliminado.', 16, 1);

        IF @srcStatus = 'transferredDeactivated'
            RAISERROR(N'El activo ya fue transferido anteriormente y se encuentra desactivado. Debe gestionarlo desde su nueva área.', 16, 1);

        IF @srcArea = @TargetAreaId
            RAISERROR(N'El área destino debe ser distinta al área actual del activo.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @TargetAreaId)
            RAISERROR(N'El área destino especificada no existe.', 16, 1);

        -- Validar que no existan OTs abiertas en el activo ni en sus descendientes
        DECLARE @OTAbiertaId NVARCHAR(20);
        SELECT TOP 1 @OTAbiertaId = ot.OrdenTrabajoId
          FROM dbo.OrdenTrabajo ot WITH (UPDLOCK, HOLDLOCK)
          JOIN dbo.Activo a WITH (NOLOCK) ON ot.CodigoActivo = a.CodigoActivo
         WHERE a.AreaId = @srcArea
           AND (a.CodigoActivo = @SourceAssetCode OR CHARINDEX(CONCAT(N',', @SourceAssetCode, N','), CONCAT(N',', a.RutaAncestros, N',')) > 0)
           AND ot.Estado IN (N'pending', N'inProgress', N'in_progress', N'paused');

        IF @OTAbiertaId IS NOT NULL
        BEGIN
            DECLARE @MsgTraspaso NVARCHAR(250) = CONCAT(N'No se puede transferir el activo: cuenta con la orden de trabajo abierta (', @OTAbiertaId, N'). Debe concluirse o cancelarse antes del traspaso.');
            RAISERROR(@MsgTraspaso, 16, 1);
        END;

        -- Retorno a área original si ya había sido transferido
        DECLARE @PreviousOriginCode NVARCHAR(60);
        SELECT @PreviousOriginCode = CodigoActivo
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE AreaId = @TargetAreaId
           AND TraspasadoACodigo = @SourceAssetCode
           AND Estado = 'transferredDeactivated'
           AND Nivel = 'equipment';

        IF @PreviousOriginCode IS NOT NULL
        BEGIN
            UPDATE a
               SET a.Estado = 'active',
                   a.TraspasadoACodigo = NULL,
                   a.ActualizadoEn = SYSUTCDATETIME()
              FROM dbo.Activo a
             WHERE a.CodigoActivo = @PreviousOriginCode
                OR a.RutaAncestros = @PreviousOriginCode
                OR a.RutaAncestros LIKE @PreviousOriginCode + ',%';

            UPDATE a
               SET a.Estado = 'transferredDeactivated',
                   a.TraspasadoACodigo = @PreviousOriginCode,
                   a.ActualizadoEn = SYSUTCDATETIME()
              FROM dbo.Activo a
             WHERE a.CodigoActivo = @SourceAssetCode
                OR a.RutaAncestros = @SourceAssetCode
                OR a.RutaAncestros LIKE @SourceAssetCode + ',%';

            UPDATE hea
               SET FinalizadoEn = SYSUTCDATETIME()
              FROM dbo.HistorialEstadoActivo hea
             WHERE (hea.CodigoActivo = @SourceAssetCode OR hea.CodigoActivo LIKE @SourceAssetCode + '-%')
               AND hea.FinalizadoEn IS NULL;

            INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
            VALUES (@PreviousOriginCode, 'active', SYSUTCDATETIME(), @TargetAreaId,
                    CONCAT(N'Retorno a su área original desde ', @srcArea, N' (código intermedio: ', @SourceAssetCode, N')'),
                    @UserId, @UserName);

            UPDATE dbo.PlanPreventivo
               SET Estado = 'active',
                   Notas = ISNULL(Notas, '') + CONCAT(CHAR(13), CHAR(10), N'[Sistema]: Plan reactivado automáticamente por retorno a su área original.')
             WHERE CodigoActivo = @PreviousOriginCode AND Estado = 'paused';

            INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
            VALUES (@UserId, @UserName, 'ASSET_TRANSFER', 'ASSETS', @SourceAssetCode,
                    CONCAT(N'Activo ', @SourceAssetCode, N' retornado a su área y código original ', @PreviousOriginCode, N' en ', @TargetAreaId, N'.'));

            COMMIT TRANSACTION;
            SELECT @PreviousOriginCode AS NewAssetCode, @PreviousOriginCode AS CodigoActivo;
            RETURN;
        END;

        -- Subárbol nuevo en destino (CTE Recursiva)
        CREATE TABLE #ArbolOrigen (
            OldCode       NVARCHAR(60) PRIMARY KEY,
            Nombre        NVARCHAR(200),
            Marca         NVARCHAR(100),
            Modelo        NVARCHAR(100),
            EstacionId    NVARCHAR(100),
            OldParentCode NVARCHAR(60),
            Nivel         NVARCHAR(20),
            RutaAncestros NVARCHAR(400),
            Serie         NVARCHAR(100),
            Atributos     NVARCHAR(MAX),
            DatosImagen   NVARCHAR(500),
            Depth         INT,
            ChildOrder    INT,
            NewCode       NVARCHAR(60),
            NewParentCode NVARCHAR(60),
            NewRuta       NVARCHAR(400)
        );

        WITH SubTree AS (
            SELECT 
                a.CodigoActivo, a.Nombre, a.Marca, a.Modelo, a.EstacionId,
                a.CodigoActivoPadre, a.Nivel, a.RutaAncestros, a.Serie,
                a.AtributosDinamicos, a.DatosImagen,
                0 AS Depth,
                1 AS ChildOrder
            FROM dbo.Activo a WITH (UPDLOCK, HOLDLOCK)
            WHERE a.CodigoActivo = @SourceAssetCode

            UNION ALL

            SELECT 
                c.CodigoActivo, c.Nombre, c.Marca, c.Modelo, c.EstacionId,
                c.CodigoActivoPadre, c.Nivel, c.RutaAncestros, c.Serie,
                c.AtributosDinamicos, c.DatosImagen,
                p.Depth + 1 AS Depth,
                CAST(ROW_NUMBER() OVER (PARTITION BY c.CodigoActivoPadre ORDER BY c.CodigoActivo) AS INT) AS ChildOrder
            FROM dbo.Activo c WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN SubTree p ON c.CodigoActivoPadre = p.CodigoActivo
            WHERE c.Estado <> 'deleted'
        )
        INSERT INTO #ArbolOrigen (
            OldCode, Nombre, Marca, Modelo, EstacionId, OldParentCode, Nivel,
            RutaAncestros, Serie, Atributos, DatosImagen, Depth, ChildOrder
        )
        SELECT 
            CodigoActivo, Nombre, Marca, Modelo, EstacionId, CodigoActivoPadre, Nivel,
            RutaAncestros, Serie, AtributosDinamicos, DatosImagen, Depth, ChildOrder
        FROM SubTree;

        IF EXISTS (
            SELECT 1 FROM dbo.CandadoBaja cb
            INNER JOIN #ArbolOrigen o ON o.OldCode = cb.CodigoActivo
            WHERE cb.EstadoCandado = 'pending'
        )
        BEGIN
            RAISERROR(N'El activo o alguno de sus componentes tiene una solicitud de baja pendiente.', 16, 1);
        END;

        DECLARE @targetCounter TABLE (val INT NOT NULL);
        UPDATE dbo.Area WITH (UPDLOCK, HOLDLOCK)
           SET ContadorActivos += 1
         OUTPUT inserted.ContadorActivos INTO @targetCounter(val)
          WHERE AreaId = @TargetAreaId;

        DECLARE @nextRoot INT; SELECT @nextRoot = val FROM @targetCounter;
        DECLARE @NewRootCode NVARCHAR(60) = CONCAT(@TargetAreaId, '-', FORMAT(@nextRoot, '000'));

        UPDATE #ArbolOrigen 
           SET NewCode = @NewRootCode, 
               NewParentCode = NULL,
               NewRuta = ''
         WHERE Depth = 0;

        DECLARE @currentDepth INT = 1;
        WHILE @currentDepth <= 3
        BEGIN
            UPDATE child
               SET child.NewParentCode = parent.NewCode,
                   child.NewCode = CONCAT(parent.NewCode, '-', FORMAT(child.ChildOrder, '00')),
                   child.NewRuta = CASE WHEN parent.NewRuta = '' THEN parent.NewCode ELSE CONCAT(parent.NewRuta, ',', parent.NewCode) END
              FROM #ArbolOrigen child
              INNER JOIN #ArbolOrigen parent ON child.OldParentCode = parent.OldCode
             WHERE child.Depth = @currentDepth;

            SET @currentDepth += 1;
        END;

        DECLARE @d INT = 0;
        WHILE @d <= 3
        BEGIN
            INSERT INTO dbo.Activo (
                CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId,
                CodigoActivoPadre, Nivel, RutaAncestros, Estado, Serie,
                AtributosDinamicos, DatosImagen, ContadorHijos, CreadoEn
            )
            SELECT 
                o.NewCode, o.Nombre, o.Marca, o.Modelo, @TargetAreaId, o.EstacionId,
                o.NewParentCode, o.Nivel, o.NewRuta, 'active', o.Serie,
                o.Atributos, o.DatosImagen,
                (SELECT COUNT(*) FROM #ArbolOrigen c WHERE c.OldParentCode = o.OldCode),
                SYSUTCDATETIME()
            FROM #ArbolOrigen o
            WHERE o.Depth = @d;

            SET @d += 1;
        END;

        UPDATE a
           SET a.Estado = 'transferredDeactivated',
               a.TraspasadoACodigo = o.NewCode,
               a.ActualizadoEn = SYSUTCDATETIME()
          FROM dbo.Activo a
          INNER JOIN #ArbolOrigen o ON a.CodigoActivo = o.OldCode;

        UPDATE hea
           SET FinalizadoEn = SYSUTCDATETIME()
          FROM dbo.HistorialEstadoActivo hea
          INNER JOIN #ArbolOrigen o ON hea.CodigoActivo = o.OldCode
         WHERE hea.FinalizadoEn IS NULL;

        INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        SELECT 
            o.NewCode, 'active', SYSUTCDATETIME(), @TargetAreaId,
            CONCAT(N'Traspaso de subárbol desde área ', @srcArea, N' (código anterior: ', o.OldCode, N')'),
            @UserId, @UserName
        FROM #ArbolOrigen o;

        UPDATE dbo.PlanPreventivo
           SET Estado = 'paused',
               Notas = ISNULL(Notas, '') + CONCAT(CHAR(13), CHAR(10), N'[Sistema]: Plan pausado automáticamente por traspaso del equipo a otra área.')
         WHERE CodigoActivo = @SourceAssetCode AND Estado = 'active';

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_TRANSFER', 'ASSETS', @SourceAssetCode,
                CONCAT(N'Subárbol de ', @SourceAssetCode, N' transferido desde ', @srcArea, N' a ', @TargetAreaId, N' con nuevo código raíz ', @NewRootCode, N'.'));

        DROP TABLE #ArbolOrigen;

        COMMIT TRANSACTION;
        SELECT @NewRootCode AS NewAssetCode, @NewRootCode AS CodigoActivo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoReactivar
    @AssetCode    NVARCHAR(60) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @UserId       INT = NULL,
    @UserName     NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @TargetCode NVARCHAR(60) = COALESCE(@AssetCode, @CodigoActivo);
        DECLARE @st NVARCHAR(25), @ar NVARCHAR(15), @nm NVARCHAR(200);
        SELECT @st = Estado, @ar = AreaId, @nm = Nombre
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @TargetCode;

        IF @st IS NULL
            RAISERROR(N'El activo no existe.', 16, 1);

        IF @st <> 'transferredDeactivated' AND @st <> 'inactive'
            RAISERROR(N'El activo no se encuentra en estado inactivo o desactivado por traspaso.', 16, 1);

        UPDATE dbo.Activo
           SET Estado = 'active',
               ActualizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @TargetCode;

        INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        VALUES (@TargetCode, 'active', SYSUTCDATETIME(), @ar, N'Reactivación de activo', @UserId, @UserName);

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_REACTIVATED', 'ASSETS', @TargetCode,
                CONCAT(N'Activo reactivado: ', @TargetCode, N' (', @nm, N').'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoAlternarEstado
    @AssetCode    NVARCHAR(60) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @NewStatus NVARCHAR(25) = NULL,
    @Status    NVARCHAR(25) = NULL,
    @Reason    NVARCHAR(500) = NULL,
    @UserId    INT = NULL,
    @UserName  NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @currStatus NVARCHAR(25), @ar NVARCHAR(15), @nm NVARCHAR(200);
        SELECT @currStatus = Estado, @ar = AreaId, @nm = Nombre
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);

        IF @currStatus IS NULL
            RAISERROR(N'El activo no existe.', 16, 1);

        DECLARE @TargetStatus NVARCHAR(25) = COALESCE(@NewStatus, @Status);
        UPDATE dbo.Activo
           SET Estado = @TargetStatus,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);

        UPDATE dbo.HistorialEstadoActivo
           SET FinalizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @AssetCode AND FinalizadoEn IS NULL;

        INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        VALUES (@AssetCode, @Status, SYSUTCDATETIME(), @ar, @Reason, @UserId, @UserName);

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_STATUS_CHANGED', 'ASSETS', @AssetCode,
                CONCAT(N'Estado de ', @AssetCode, N' cambiado a: ', @Status, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspActivoActualizarEsEquipoProceso
    @CodigoActivo NVARCHAR(60) = NULL,
    @AssetCode NVARCHAR(60) = NULL,
    @EsEquipoProceso BIT = 1,
    @UsuarioId INT = NULL,
    @UserId INT = NULL,
    @NombreUsuario NVARCHAR(100) = N'',
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Activo
       SET EsEquipoProceso = @EsEquipoProceso,
           ActualizadoEn = SYSUTCDATETIME()
     WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);
END;
GO

-- ----------------------------------------------------------------------------
-- 15. PROCEDIMIENTOS ALMACENADOS: SOLICITUDES Y GESTIÓN DE BAJAS
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaCrear
    @AssetCode    NVARCHAR(60) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,
    @Reason NVARCHAR(1000),
    @RequesterUserId INT = NULL,
    @RequesterUserName NVARCHAR(100) = N'',
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @nm NVARCHAR(200), @ar NVARCHAR(15), @st NVARCHAR(25);
        SELECT @nm = Nombre, @ar = AreaId, @st = Estado
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK) WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);

        IF @st IS NULL OR @st = 'deleted'
            RAISERROR(N'El activo no existe o ya está eliminado.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE CodigoActivo = @AssetCode AND EstadoCandado = 'pending')
            RAISERROR(N'Ya existe una solicitud de baja pendiente para este activo.', 16, 1);

        -- Validar OTs abiertas
        DECLARE @OTAbiertaId NVARCHAR(20);
        SELECT TOP 1 @OTAbiertaId = ot.OrdenTrabajoId
          FROM dbo.OrdenTrabajo ot WITH (UPDLOCK, HOLDLOCK)
          JOIN dbo.Activo a WITH (NOLOCK) ON ot.CodigoActivo = a.CodigoActivo
         WHERE a.AreaId = @ar
           AND (a.CodigoActivo = @AssetCode OR CHARINDEX(CONCAT(N',', @AssetCode, N','), CONCAT(N',', a.RutaAncestros, N',')) > 0)
           AND ot.Estado IN (N'pending', N'inProgress', N'in_progress', N'paused');

        IF @OTAbiertaId IS NOT NULL
        BEGIN
            DECLARE @MsgBaja NVARCHAR(250) = CONCAT(N'No se puede solicitar la baja: el activo o sus subcomponentes tienen la orden de trabajo abierta (', @OTAbiertaId, N'). Debe concluirse o cancelarse primero.');
            RAISERROR(@MsgBaja, 16, 1);
        END;

        INSERT INTO dbo.SolicitudBaja
            (CodigoActivo, NombreActivo, AreaId, Estado, Motivo,
             SolicitadoPorUsuarioId, SolicitadoPorNombreUsuario, SolicitadoEn)
        VALUES
            (@AssetCode, @nm, @ar, 'pending', @Reason,
             COALESCE(@RequesterUserId, @UserId), COALESCE(NULLIF(@RequesterUserName, N''), @UserName, N''), SYSUTCDATETIME());

        DECLARE @reqId BIGINT = SCOPE_IDENTITY();

        IF EXISTS (SELECT 1 FROM dbo.CandadoBaja WHERE CodigoActivo = @AssetCode)
            UPDATE dbo.CandadoBaja SET EstadoCandado = 'pending', ActualizadoEn = SYSUTCDATETIME() WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);
        ELSE
            INSERT INTO dbo.CandadoBaja (CodigoActivo, EstadoCandado) VALUES (@AssetCode, 'pending');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@RequesterUserId, @RequesterUserName, 'DELETION_REQUESTED', 'ASSETS', @AssetCode,
                CONCAT(N'Solicitud de baja ', @reqId, N' creada para ', @AssetCode, N' (', @nm, N'). Motivo: ', @Reason));

        COMMIT TRANSACTION;
        SELECT @reqId AS RequestId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaObtenerPendientes
    @StartDate DATETIME2(3) = NULL,
    @EndDate   DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SolicitudId, CodigoActivo, NombreActivo, AreaId, Estado, Motivo,
           SolicitadoPorUsuarioId, SolicitadoPorNombreUsuario, SolicitadoEn,
           DecididoPorUsuarioId, DecididoPorNombreUsuario, DecididoEn, MotivoDecision
      FROM dbo.SolicitudBaja
     WHERE Estado = 'pending'
       AND (@StartDate IS NULL OR SolicitadoEn >= @StartDate)
       AND (@EndDate   IS NULL OR SolicitadoEn <= @EndDate)
     ORDER BY SolicitadoEn DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaObtenerTodas
    @StatusFilter NVARCHAR(10) = NULL,
    @StartDate    DATETIME2(3) = NULL,
    @EndDate      DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SolicitudId, CodigoActivo, NombreActivo, AreaId, Estado, Motivo,
           SolicitadoPorUsuarioId, SolicitadoPorNombreUsuario, SolicitadoEn,
           DecididoPorUsuarioId, DecididoPorNombreUsuario, DecididoEn, MotivoDecision
      FROM dbo.SolicitudBaja
     WHERE (@StatusFilter IS NULL OR Estado = @StatusFilter)
       AND (@StartDate IS NULL OR SolicitadoEn >= @StartDate)
       AND (@EndDate   IS NULL OR SolicitadoEn <= @EndDate)
     ORDER BY SolicitadoEn DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaObtenerPendientePorActivo
    @AssetCode NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 SolicitudId, CodigoActivo, NombreActivo, AreaId, Estado, Motivo,
           SolicitadoPorUsuarioId, SolicitadoPorNombreUsuario, SolicitadoEn,
           DecididoPorUsuarioId, DecididoPorNombreUsuario, DecididoEn, MotivoDecision
      FROM dbo.SolicitudBaja
     WHERE CodigoActivo = @AssetCode AND Estado = 'pending'
     ORDER BY SolicitadoEn DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaAprobar
    @RequestId BIGINT,
    @ApproverUserId INT = NULL,
    @ApproverUserName NVARCHAR(100) = N'',
    @ApproveReason NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @c NVARCHAR(60), @nm NVARCHAR(200), @ar NVARCHAR(15), @st NVARCHAR(10);
        SELECT @c = CodigoActivo, @nm = NombreActivo, @ar = AreaId, @st = Estado
          FROM dbo.SolicitudBaja WITH (UPDLOCK, HOLDLOCK) WHERE SolicitudId = @RequestId;

        IF @c IS NULL OR @st <> 'pending'
            RAISERROR(N'Esta solicitud ya fue resuelta o no está pendiente.', 16, 1);

        DECLARE @OTAbiertaId NVARCHAR(20);
        SELECT TOP 1 @OTAbiertaId = ot.OrdenTrabajoId
          FROM dbo.OrdenTrabajo ot WITH (UPDLOCK, HOLDLOCK)
          JOIN dbo.Activo a WITH (NOLOCK) ON ot.CodigoActivo = a.CodigoActivo
         WHERE a.AreaId = @ar
           AND (a.CodigoActivo = @c OR CHARINDEX(CONCAT(N',', @c, N','), CONCAT(N',', a.RutaAncestros, N',')) > 0)
           AND ot.Estado IN (N'pending', N'inProgress', N'in_progress', N'paused');

        IF @OTAbiertaId IS NOT NULL
        BEGIN
            DECLARE @MsgBaja NVARCHAR(250) = CONCAT(N'No se puede dar de baja: el activo o sus subcomponentes tienen la orden de trabajo abierta (', @OTAbiertaId, N'). Debe concluirse o cancelarse primero.');
            RAISERROR(@MsgBaja, 16, 1);
        END;

        UPDATE a
           SET Estado = 'deleted',
               EliminadoEn = SYSUTCDATETIME(),
               EliminadoPorUsuarioId = @ApproverUserId,
               EliminadoPorNombreUsuario = @ApproverUserName,
               ActualizadoEn = SYSUTCDATETIME()
          FROM dbo.Activo a
         WHERE a.AreaId = @ar AND a.Estado <> 'deleted'
           AND (a.CodigoActivo = @c OR CHARINDEX(CONCAT(N',', @c, N','), CONCAT(N',', a.RutaAncestros, N',')) > 0);

        UPDATE dbo.PlanPreventivo
           SET Estado = 'paused',
               Notas = ISNULL(Notas, '') + CONCAT(CHAR(13), CHAR(10), N'[Sistema]: Plan preventivo pausado automáticamente por baja del activo.')
         WHERE CodigoActivo = @c AND Estado = 'active';

        UPDATE dbo.SolicitudBaja
           SET Estado = 'approved',
               DecididoPorUsuarioId = @ApproverUserId,
               DecididoPorNombreUsuario = @ApproverUserName,
               DecididoEn = SYSUTCDATETIME(),
               MotivoDecision = COALESCE(@ApproveReason, N'')
         WHERE SolicitudId = @RequestId;

        UPDATE dbo.CandadoBaja SET EstadoCandado = 'approved', ActualizadoEn = SYSUTCDATETIME() WHERE CodigoActivo = @c;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@ApproverUserId, @ApproverUserName, 'ASSET_DELETED', 'ASSETS', @c,
                CONCAT(N'Aprobada la solicitud de baja ', @RequestId, N' para ', @c, N' (', @nm, N'). Planes preventivos pausados.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaRechazar
    @RequestId BIGINT,
    @Reason NVARCHAR(500) = NULL,
    @RejectReason NVARCHAR(500) = NULL,
    @RejectedByUserId INT = NULL,
    @ApproverUserId INT = NULL,
    @RejectedByUserName NVARCHAR(100) = N'',
    @ApproverUserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @c NVARCHAR(60), @nm NVARCHAR(200), @st NVARCHAR(10);
        SELECT @c = CodigoActivo, @nm = NombreActivo, @st = Estado
          FROM dbo.SolicitudBaja WITH (UPDLOCK, HOLDLOCK) WHERE SolicitudId = @RequestId;

        IF @c IS NULL OR @st <> 'pending'
            RAISERROR(N'Esta solicitud ya fue resuelta o no está pendiente.', 16, 1);

        UPDATE dbo.SolicitudBaja
           SET Estado = 'rejected',
               DecididoPorUsuarioId = @ApproverUserId,
               DecididoPorNombreUsuario = @ApproverUserName,
               DecididoEn = SYSUTCDATETIME(),
               MotivoDecision = @RejectReason
         WHERE SolicitudId = @RequestId;

        UPDATE dbo.CandadoBaja SET EstadoCandado = 'rejected', ActualizadoEn = SYSUTCDATETIME() WHERE CodigoActivo = @c;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@ApproverUserId, @ApproverUserName, 'DELETION_REJECTED', 'ASSETS', @c,
                CONCAT(N'Rechazada la solicitud de baja ', @RequestId, N' para ', @c, N' (', @nm, N'). Motivo: ', @RejectReason));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
