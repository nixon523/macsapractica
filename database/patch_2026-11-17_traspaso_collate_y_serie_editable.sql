-- ============================================================================
-- PATCH: Corrección de Collation en Traspaso/Clonación/Plantillas y Edición de N° de Serie con Kardex
-- Fecha: 2026-11-17
-- Autor: Antigravity
-- ============================================================================

USE [MacsaCMMS];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- 1. CORRECCIÓN DE uspActivoTraspasar:
-- Se agrega COLLATE DATABASE_DEFAULT a todas las columnas de la tabla temporal #ArbolOrigen
-- para evitar conflicto de intercalación (Collation Conflict 468) entre tempdb y la BD.
-- Se incluye el traspaso de Observaciones.
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

        -- Subárbol nuevo en destino (CTE Recursiva con COLLATE DATABASE_DEFAULT)
        CREATE TABLE #ArbolOrigen (
            OldCode       NVARCHAR(60) COLLATE DATABASE_DEFAULT PRIMARY KEY,
            Nombre        NVARCHAR(200) COLLATE DATABASE_DEFAULT,
            Marca         NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Modelo        NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            EstacionId    NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            OldParentCode NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            Nivel         NVARCHAR(20) COLLATE DATABASE_DEFAULT,
            RutaAncestros NVARCHAR(400) COLLATE DATABASE_DEFAULT,
            Serie         NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Atributos     NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            DatosImagen   NVARCHAR(500) COLLATE DATABASE_DEFAULT,
            Observaciones NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            Depth         INT,
            ChildOrder    INT,
            NewCode       NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            NewParentCode NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            NewRuta       NVARCHAR(400) COLLATE DATABASE_DEFAULT
        );

        WITH SubTree AS (
            SELECT 
                a.CodigoActivo, a.Nombre, a.Marca, a.Modelo, a.EstacionId,
                a.CodigoActivoPadre, a.Nivel, a.RutaAncestros, a.Serie,
                a.AtributosDinamicos, a.DatosImagen, a.Observaciones,
                0 AS Depth,
                1 AS ChildOrder
            FROM dbo.Activo a WITH (UPDLOCK, HOLDLOCK)
            WHERE a.CodigoActivo = @SourceAssetCode

            UNION ALL

            SELECT 
                c.CodigoActivo, c.Nombre, c.Marca, c.Modelo, c.EstacionId,
                c.CodigoActivoPadre, c.Nivel, c.RutaAncestros, c.Serie,
                c.AtributosDinamicos, c.DatosImagen, c.Observaciones,
                p.Depth + 1 AS Depth,
                CAST(ROW_NUMBER() OVER (PARTITION BY c.CodigoActivoPadre ORDER BY c.CodigoActivo) AS INT) AS ChildOrder
            FROM dbo.Activo c WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN SubTree p ON c.CodigoActivoPadre = p.CodigoActivo
            WHERE c.Estado <> 'deleted'
        )
        INSERT INTO #ArbolOrigen (
            OldCode, Nombre, Marca, Modelo, EstacionId, OldParentCode, Nivel,
            RutaAncestros, Serie, Atributos, DatosImagen, Observaciones, Depth, ChildOrder
        )
        SELECT 
            CodigoActivo, Nombre, Marca, Modelo, EstacionId, CodigoActivoPadre, Nivel,
            RutaAncestros, Serie, AtributosDinamicos, DatosImagen, Observaciones, Depth, ChildOrder
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
                AtributosDinamicos, DatosImagen, Observaciones, ContadorHijos, CreadoEn
            )
            SELECT 
                o.NewCode, o.Nombre, o.Marca, o.Modelo, @TargetAreaId, o.EstacionId,
                o.NewParentCode, o.Nivel, o.NewRuta, 'active', o.Serie,
                o.Atributos, o.DatosImagen, o.Observaciones,
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
        IF OBJECT_ID('tempdb..#ArbolOrigen') IS NOT NULL DROP TABLE #ArbolOrigen;
        THROW;
    END CATCH
END;
GO

-- 2. CORRECCIÓN DE uspActivoClonarArbol:
-- Se agrega COLLATE DATABASE_DEFAULT a las columnas de #Descendientes y @Mapeo
CREATE OR ALTER PROCEDURE dbo.uspActivoClonarArbol
    @CodigoActivoOrigen NVARCHAR(60),
    @AreaDestinoId      NVARCHAR(15),
    @NuevoNombreRaiz    NVARCHAR(200) = NULL,
    @NuevoSerialRaiz    NVARCHAR(100) = NULL,
    @Observaciones      NVARCHAR(MAX) = NULL,
    @CopiarAtributos    BIT = 1,
    @UserId             INT = NULL,
    @UserName           NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validaciones origen
        DECLARE @srcArea NVARCHAR(15), @srcName NVARCHAR(200), @srcStatus NVARCHAR(25), @srcLevel NVARCHAR(20);
        DECLARE @srcMarca NVARCHAR(100), @srcModelo NVARCHAR(100), @srcEstacion NVARCHAR(100);
        DECLARE @srcAtributos NVARCHAR(MAX), @srcObservaciones NVARCHAR(MAX);

        SELECT @srcArea = AreaId, @srcName = Nombre, @srcStatus = Estado, @srcLevel = Nivel,
               @srcMarca = Marca, @srcModelo = Modelo, @srcEstacion = EstacionId,
               @srcAtributos = AtributosDinamicos, @srcObservaciones = Observaciones
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @CodigoActivoOrigen;

        IF @srcArea IS NULL OR @srcStatus = 'deleted'
            RAISERROR(N'El activo origen no existe o está eliminado.', 16, 1);

        IF @srcLevel <> 'equipment'
            RAISERROR(N'Solo se pueden clonar árboles completos a partir de un equipo raíz (equipment).', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @AreaDestinoId)
            RAISERROR(N'El área destino especificada no existe.', 16, 1);

        -- Validar serial raíz único si fue provisto
        IF @NuevoSerialRaiz IS NOT NULL AND LTRIM(RTRIM(@NuevoSerialRaiz)) <> ''
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Activo WHERE Serie = @NuevoSerialRaiz AND Estado <> 'deleted')
                RAISERROR(N'El número de serie ingresado para la nueva máquina ya está registrado.', 16, 1);
        END;

        -- Generar nuevo código raíz
        DECLARE @targetCounter TABLE (val INT NOT NULL);
        UPDATE dbo.Area WITH (UPDLOCK, HOLDLOCK)
           SET ContadorActivos += 1
         OUTPUT inserted.ContadorActivos INTO @targetCounter(val)
          WHERE AreaId = @AreaDestinoId;

        DECLARE @nextRoot INT; SELECT @nextRoot = val FROM @targetCounter;
        DECLARE @NuevoCodigoRaiz NVARCHAR(60) = CONCAT(@AreaDestinoId, '-', FORMAT(@nextRoot, '000'));

        -- Preparar atributos y observaciones de raíz
        DECLARE @rootName NVARCHAR(200) = COALESCE(NULLIF(LTRIM(RTRIM(@NuevoNombreRaiz)), ''), @srcName);
        DECLARE @rootAttr NVARCHAR(MAX) = CASE WHEN @CopiarAtributos = 1 THEN @srcAtributos ELSE NULL END;
        DECLARE @rootObs NVARCHAR(MAX) = COALESCE(@Observaciones, @srcObservaciones);

        -- Insertar el nuevo equipo raíz clonado
        INSERT INTO dbo.Activo (
            CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId,
            CodigoActivoPadre, Nivel, RutaAncestros, Estado, Serie,
            AtributosDinamicos, DatosImagen, Observaciones, ContadorHijos, CreadoEn
        )
        VALUES (
            @NuevoCodigoRaiz, @rootName, @srcMarca, @srcModelo, @AreaDestinoId, @srcEstacion,
            NULL, 'equipment', '', 'active', NULLIF(@NuevoSerialRaiz, ''),
            @rootAttr, NULL, @rootObs, 0, SYSUTCDATETIME()
        );

        -- Bitácora de estado inicial para raíz
        INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        VALUES (@NuevoCodigoRaiz, 'active', SYSUTCDATETIME(), @AreaDestinoId,
                CONCAT(N'Equipo clonado a partir de la plantilla/estructura de ', @CodigoActivoOrigen),
                @UserId, @UserName);

        -- Mapeo de códigos viejos a nuevos
        DECLARE @Mapeo TABLE (
            CodigoOrigen NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            CodigoNuevo  NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            RutaAncestros NVARCHAR(400) COLLATE DATABASE_DEFAULT
        );
        INSERT INTO @Mapeo (CodigoOrigen, CodigoNuevo, RutaAncestros)
        VALUES (@CodigoActivoOrigen, @NuevoCodigoRaiz, '');

        -- Tabla temporal de descendientes con COLLATE DATABASE_DEFAULT
        CREATE TABLE #Descendientes (
            Orden         INT IDENTITY(1,1),
            CodigoOrigen  NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            PadreOrigen   NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            Nombre        NVARCHAR(200) COLLATE DATABASE_DEFAULT,
            Marca         NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Modelo        NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Nivel         NVARCHAR(20) COLLATE DATABASE_DEFAULT,
            Observaciones NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            Atributos     NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            Profundidad   INT
        );

        -- Recorrido jerárquico por niveles de profundidad
        WITH ArbolDesc AS (
            SELECT CodigoActivo, CodigoActivoPadre, Nombre, Marca, Modelo, Nivel, Observaciones, AtributosDinamicos, 1 AS Profundidad
              FROM dbo.Activo
             WHERE CodigoActivoPadre = @CodigoActivoOrigen
               AND Estado <> 'deleted'
            UNION ALL
            SELECT c.CodigoActivo, c.CodigoActivoPadre, c.Nombre, c.Marca, c.Modelo, c.Nivel, c.Observaciones, c.AtributosDinamicos, a.Profundidad + 1
              FROM dbo.Activo c
              INNER JOIN ArbolDesc a ON c.CodigoActivoPadre = a.CodigoActivo
             WHERE c.Estado <> 'deleted'
        )
        INSERT INTO #Descendientes (CodigoOrigen, PadreOrigen, Nombre, Marca, Modelo, Nivel, Observaciones, Atributos, Profundidad)
        SELECT CodigoActivo, CodigoActivoPadre, Nombre, Marca, Modelo, Nivel, Observaciones, AtributosDinamicos, Profundidad
          FROM ArbolDesc
         ORDER BY Profundidad ASC, CodigoActivo ASC;

        -- Clonar cada descendiente asignándole su nuevo padre
        DECLARE @MaxOrden INT = (SELECT ISNULL(MAX(Orden), 0) FROM #Descendientes);
        DECLARE @i INT = 1;
        DECLARE @TotalClonados INT = 1; -- contando la raíz

        WHILE @i <= @MaxOrden
        BEGIN
            DECLARE @cOrigen NVARCHAR(60), @pOrigen NVARCHAR(60), @cNombre NVARCHAR(200);
            DECLARE @cMarca NVARCHAR(100), @cModelo NVARCHAR(100), @cNivel NVARCHAR(20);
            DECLARE @cObs NVARCHAR(MAX), @cAttr NVARCHAR(MAX);

            SELECT @cOrigen = CodigoOrigen,
                   @pOrigen = PadreOrigen,
                   @cNombre = Nombre,
                   @cMarca = Marca,
                   @cModelo = Modelo,
                   @cNivel = Nivel,
                   @cObs = Observaciones,
                   @cAttr = Atributos
              FROM #Descendientes
             WHERE Orden = @i;

            DECLARE @NuevoPadreCode NVARCHAR(60);
            DECLARE @RutaAncestrosPadre NVARCHAR(400);

            SELECT @NuevoPadreCode = CodigoNuevo,
                   @RutaAncestrosPadre = RutaAncestros
              FROM @Mapeo
             WHERE CodigoOrigen = @pOrigen;

            IF @NuevoPadreCode IS NOT NULL
            BEGIN
                DECLARE @childCounterTable TABLE (cnt INT NOT NULL);
                DELETE FROM @childCounterTable;

                UPDATE dbo.Activo WITH (UPDLOCK, HOLDLOCK)
                   SET ContadorHijos += 1
                 OUTPUT inserted.ContadorHijos INTO @childCounterTable(cnt)
                  WHERE CodigoActivo = @NuevoPadreCode;

                DECLARE @nextChild INT;
                SELECT @nextChild = cnt FROM @childCounterTable;

                DECLARE @NuevoHijoCode NVARCHAR(60) = CONCAT(@NuevoPadreCode, '-', FORMAT(@nextChild, '00'));
                DECLARE @NuevaRuta NVARCHAR(400) = CASE 
                    WHEN @RutaAncestrosPadre = '' THEN @NuevoPadreCode
                    ELSE CONCAT(@RutaAncestrosPadre, ',', @NuevoPadreCode)
                END;

                INSERT INTO dbo.Activo (
                    CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId,
                    CodigoActivoPadre, Nivel, RutaAncestros, Estado, Serie,
                    AtributosDinamicos, DatosImagen, Observaciones, ContadorHijos, CreadoEn
                )
                VALUES (
                    @NuevoHijoCode, @cNombre, @cMarca, @cModelo, @AreaDestinoId, @srcEstacion,
                    @NuevoPadreCode, @cNivel, @NuevaRuta, 'active', NULL,
                    CASE WHEN @CopiarAtributos = 1 THEN @cAttr ELSE NULL END, NULL, @cObs, 0, SYSUTCDATETIME()
                );

                INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
                VALUES (@NuevoHijoCode, 'active', SYSUTCDATETIME(), @AreaDestinoId,
                        CONCAT(N'Componente clonado a partir de ', @cOrigen),
                        @UserId, @UserName);

                INSERT INTO @Mapeo (CodigoOrigen, CodigoNuevo, RutaAncestros)
                VALUES (@cOrigen, @NuevoHijoCode, @NuevaRuta);

                SET @TotalClonados += 1;
            END;

            SET @i += 1;
        END;

        -- Registrar en Kardex
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_CREATED', 'ASSETS', @NuevoCodigoRaiz,
                CONCAT(N'Árbol completo clonado a partir de ', @CodigoActivoOrigen, N' hacia área ', @AreaDestinoId, N' con nuevo código ', @NuevoCodigoRaiz, N' (total ', @TotalClonados, N' activos generados).'));

        DROP TABLE #Descendientes;

        COMMIT TRANSACTION;

        SELECT @NuevoCodigoRaiz AS CodigoActivo,
               @NuevoCodigoRaiz AS assetCode,
               @NuevoCodigoRaiz AS id,
               @rootName        AS Nombre,
               @AreaDestinoId   AS AreaId,
               @TotalClonados   AS totalNodos;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#Descendientes') IS NOT NULL DROP TABLE #Descendientes;
        THROW;
    END CATCH
END;
GO

-- 3. CORRECCIÓN DE uspPlantillaActivoGuardarDesdeActivo:
-- Se agrega COLLATE DATABASE_DEFAULT a las columnas de #DescPlantilla
CREATE OR ALTER PROCEDURE dbo.uspPlantillaActivoGuardarDesdeActivo
    @CodigoActivoOrigen NVARCHAR(60),
    @NombrePlantilla    NVARCHAR(150),
    @Descripcion        NVARCHAR(255) = NULL,
    @UserId             INT = NULL,
    @UserName           NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CleanName NVARCHAR(150) = LTRIM(RTRIM(@NombrePlantilla));
        IF @CleanName IS NULL OR @CleanName = N''
            RAISERROR(N'El nombre de la plantilla es obligatorio.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM dbo.Activo WHERE CodigoActivo = @CodigoActivoOrigen AND Estado <> 'deleted')
            RAISERROR(N'El activo de origen no existe.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.PlantillaActivo WHERE UPPER(Nombre) = UPPER(@CleanName) AND Activo = 1)
            RAISERROR(N'Ya existe una plantilla activa con ese nombre.', 16, 1);

        DECLARE @OrigNivelRaiz NVARCHAR(20);
        SELECT @OrigNivelRaiz = Nivel FROM dbo.Activo WHERE CodigoActivo = @CodigoActivoOrigen;

        -- 1. Crear cabecera
        INSERT INTO dbo.PlantillaActivo (Nombre, Descripcion, NivelRaiz, TotalNodos, Activo, CreadoEn, ActualizadoEn)
        VALUES (@CleanName, NULLIF(LTRIM(RTRIM(@Descripcion)), N''), @OrigNivelRaiz, 1, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

        DECLARE @NewPlantillaId INT = SCOPE_IDENTITY();

        -- 2. Insertar nodo raíz de la plantilla
        DECLARE @NodoRaizId INT;
        INSERT INTO dbo.PlantillaActivoNodo (
            PlantillaId, NodoPadreId, Nombre, Marca, Modelo, Nivel, Orden, AtributosDinamicos, Observaciones
        )
        SELECT @NewPlantillaId, NULL, Nombre, Marca, Modelo, Nivel, 1, AtributosDinamicos, Observaciones
          FROM dbo.Activo
         WHERE CodigoActivo = @CodigoActivoOrigen;

        SET @NodoRaizId = SCOPE_IDENTITY();

        -- Mapeo de CodigoActivo -> NodoId
        DECLARE @MapeoNodos TABLE (
            CodigoActivo NVARCHAR(60) COLLATE DATABASE_DEFAULT PRIMARY KEY,
            NodoId       INT NOT NULL
        );
        INSERT INTO @MapeoNodos (CodigoActivo, NodoId) VALUES (@CodigoActivoOrigen, @NodoRaizId);

        -- Tabla temporal de descendientes con COLLATE DATABASE_DEFAULT
        CREATE TABLE #DescPlantilla (
            Orden         INT IDENTITY(2,1),
            CodigoActivo  NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            PadreCodigo   NVARCHAR(60) COLLATE DATABASE_DEFAULT,
            Nombre        NVARCHAR(200) COLLATE DATABASE_DEFAULT,
            Marca         NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Modelo        NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Nivel         NVARCHAR(20) COLLATE DATABASE_DEFAULT,
            Atributos     NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            Observaciones NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            Profundidad   INT
        );

        WITH ArbolDesc AS (
            SELECT CodigoActivo, CodigoActivoPadre, Nombre, Marca, Modelo, Nivel, AtributosDinamicos, Observaciones, 1 AS Profundidad
              FROM dbo.Activo
             WHERE CodigoActivoPadre = @CodigoActivoOrigen AND Estado <> 'deleted'
            UNION ALL
            SELECT c.CodigoActivo, c.CodigoActivoPadre, c.Nombre, c.Marca, c.Modelo, c.Nivel, c.AtributosDinamicos, c.Observaciones, a.Profundidad + 1
              FROM dbo.Activo c
              INNER JOIN ArbolDesc a ON c.CodigoActivoPadre = a.CodigoActivo
             WHERE c.Estado <> 'deleted'
        )
        INSERT INTO #DescPlantilla (CodigoActivo, PadreCodigo, Nombre, Marca, Modelo, Nivel, Atributos, Observaciones, Profundidad)
        SELECT CodigoActivo, CodigoActivoPadre, Nombre, Marca, Modelo, Nivel, AtributosDinamicos, Observaciones, Profundidad
          FROM ArbolDesc
         ORDER BY Profundidad ASC, CodigoActivo ASC;

        DECLARE @MaxDesc INT = (SELECT ISNULL(MAX(Orden), 1) FROM #DescPlantilla);
        DECLARE @curr INT = 2;
        DECLARE @TotalNodos INT = 1;

        WHILE @curr <= @MaxDesc
        BEGIN
            DECLARE @ca NVARCHAR(60), @cp NVARCHAR(60), @nm NVARCHAR(200);
            DECLARE @mc NVARCHAR(100), @md NVARCHAR(100), @nv NVARCHAR(20);
            DECLARE @at NVARCHAR(MAX), @ob NVARCHAR(MAX);

            SELECT @ca = CodigoActivo, @cp = PadreCodigo, @nm = Nombre,
                   @mc = Marca, @md = Modelo, @nv = Nivel,
                   @at = Atributos, @ob = Observaciones
              FROM #DescPlantilla
             WHERE Orden = @curr;

            DECLARE @ParentNodoId INT;
            SELECT @ParentNodoId = NodoId FROM @MapeoNodos WHERE CodigoActivo = @cp;

            IF @ParentNodoId IS NOT NULL
            BEGIN
                INSERT INTO dbo.PlantillaActivoNodo (
                    PlantillaId, NodoPadreId, Nombre, Marca, Modelo, Nivel, Orden, AtributosDinamicos, Observaciones
                )
                VALUES (
                    @NewPlantillaId, @ParentNodoId, @nm, @mc, @md, @nv, @curr, @at, @ob
                );

                DECLARE @NewNodoId INT = SCOPE_IDENTITY();
                INSERT INTO @MapeoNodos (CodigoActivo, NodoId) VALUES (@ca, @NewNodoId);
                SET @TotalNodos += 1;
            END;

            SET @curr += 1;
        END;

        DROP TABLE #DescPlantilla;

        -- Actualizar contador total en la plantilla
        UPDATE dbo.PlantillaActivo
           SET TotalNodos = @TotalNodos,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE PlantillaId = @NewPlantillaId;

        -- Auditoría Kardex
        DECLARE @AuditUser INT = @UserId;
        IF @AuditUser IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @AuditUser)
            SET @AuditUser = NULL;
        DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (
            @AuditUser, @UName, 'TEMPLATE_CREATED', 'ASSETS', CAST(@NewPlantillaId AS NVARCHAR(30)),
            CONCAT(N'Plantilla "', @CleanName, N'" guardada desde activo ', @CodigoActivoOrigen, N' con ', @TotalNodos, N' partes.')
        );

        COMMIT TRANSACTION;

        SELECT PlantillaId AS id, PlantillaId, Nombre, TotalNodos, CreadoEn
          FROM dbo.PlantillaActivo
         WHERE PlantillaId = @NewPlantillaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#DescPlantilla') IS NOT NULL DROP TABLE #DescPlantilla;
        THROW;
    END CATCH
END;
GO

-- 4. CORRECCIÓN DE uspPlantillaActivoInstanciar:
-- Se agrega COLLATE DATABASE_DEFAULT a las columnas de #NodosInstanciar
CREATE OR ALTER PROCEDURE dbo.uspPlantillaActivoInstanciar
    @PlantillaId     INT,
    @AreaDestinoId   NVARCHAR(15),
    @NuevoNombreRaiz NVARCHAR(200) = NULL,
    @NuevoSerialRaiz NVARCHAR(100) = NULL,
    @Observaciones   NVARCHAR(MAX) = NULL,
    @CopiarAtributos BIT = 1,
    @UserId          INT = NULL,
    @UserName        NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.PlantillaActivo WHERE PlantillaId = @PlantillaId AND Activo = 1)
            RAISERROR(N'La plantilla especificada no existe o se encuentra inactiva.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @AreaDestinoId AND Activo = 1)
            RAISERROR(N'El área destino especificada no existe o se encuentra inactiva.', 16, 1);

        IF @NuevoSerialRaiz IS NOT NULL AND LTRIM(RTRIM(@NuevoSerialRaiz)) <> ''
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Activo WHERE Serie = @NuevoSerialRaiz AND Estado <> 'deleted')
                RAISERROR(N'El número de serie indicado ya está en uso por otro activo activo.', 16, 1);
        END;

        -- 1. Obtener nodo raíz de la plantilla
        DECLARE @RootNodoId INT, @RootNombre NVARCHAR(200), @RootMarca NVARCHAR(100), @RootModelo NVARCHAR(100);
        DECLARE @RootNivel NVARCHAR(20), @RootAtributos NVARCHAR(MAX), @RootObs NVARCHAR(MAX);

        SELECT @RootNodoId = NodoId,
               @RootNombre = Nombre,
               @RootMarca = Marca,
               @RootModelo = Modelo,
               @RootNivel = Nivel,
               @RootAtributos = AtributosDinamicos,
               @RootObs = Observaciones
          FROM dbo.PlantillaActivoNodo
         WHERE PlantillaId = @PlantillaId AND NodoPadreId IS NULL;

        -- 2. Generar correlativo para la nueva raíz
        DECLARE @acTable TABLE (val INT NOT NULL);
        UPDATE dbo.Area WITH (UPDLOCK, HOLDLOCK)
           SET ContadorActivos += 1
         OUTPUT inserted.ContadorActivos INTO @acTable(val)
          WHERE AreaId = @AreaDestinoId;

        DECLARE @ac INT; SELECT @ac = val FROM @acTable;
        DECLARE @NuevoCodigoRaiz NVARCHAR(60) = CONCAT(@AreaDestinoId, '-', FORMAT(@ac, '000'));

        DECLARE @NombreFinalRaiz NVARCHAR(200) = COALESCE(NULLIF(LTRIM(RTRIM(@NuevoNombreRaiz)), N''), @RootNombre);
        DECLARE @ObsFinalRaiz NVARCHAR(MAX) = COALESCE(@Observaciones, @RootObs);
        DECLARE @AtributosRaiz NVARCHAR(MAX) = CASE WHEN @CopiarAtributos = 1 THEN @RootAtributos ELSE NULL END;

        -- 3. Insertar raíz en dbo.Activo
        INSERT INTO dbo.Activo (
            CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, CodigoActivoPadre,
            Nivel, RutaAncestros, Estado, Serie, AtributosDinamicos, DatosImagen,
            Observaciones, ContadorHijos, CreadoEn
        )
        VALUES (
            @NuevoCodigoRaiz, @NombreFinalRaiz, @RootMarca, @RootModelo, @AreaDestinoId,
            '', NULL, @RootNivel, '', 'active', NULLIF(@NuevoSerialRaiz, ''),
            @AtributosRaiz, NULL, @ObsFinalRaiz, 0, SYSUTCDATETIME()
        );

        -- Tabla de mapeo NodoId -> CodigoActivo
        DECLARE @Mapeo TABLE (
            NodoId        INT PRIMARY KEY,
            CodigoActivo  NVARCHAR(60) COLLATE DATABASE_DEFAULT NOT NULL,
            RutaAncestros NVARCHAR(400) COLLATE DATABASE_DEFAULT NOT NULL
        );
        INSERT INTO @Mapeo (NodoId, CodigoActivo, RutaAncestros)
        VALUES (@RootNodoId, @NuevoCodigoRaiz, '');

        -- Tabla temporal para procesar descendientes en orden con COLLATE DATABASE_DEFAULT
        CREATE TABLE #NodosInstanciar (
            Orden         INT IDENTITY(1,1),
            NodoId        INT,
            NodoPadreId   INT,
            Nombre        NVARCHAR(200) COLLATE DATABASE_DEFAULT,
            Marca         NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Modelo        NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            Nivel         NVARCHAR(20) COLLATE DATABASE_DEFAULT,
            Atributos     NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            Observaciones NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
            Profundidad   INT
        );

        WITH ArbolNodos AS (
            SELECT NodoId, NodoPadreId, Nombre, Marca, Modelo, Nivel, Orden, AtributosDinamicos, Observaciones, 1 AS Profundidad
              FROM dbo.PlantillaActivoNodo
             WHERE PlantillaId = @PlantillaId AND NodoPadreId = @RootNodoId
            UNION ALL
            SELECT c.NodoId, c.NodoPadreId, c.Nombre, c.Marca, c.Modelo, c.Nivel, c.Orden, c.AtributosDinamicos, c.Observaciones, a.Profundidad + 1
              FROM dbo.PlantillaActivoNodo c
              INNER JOIN ArbolNodos a ON c.NodoPadreId = a.NodoId
             WHERE c.PlantillaId = @PlantillaId
        )
        INSERT INTO #NodosInstanciar (NodoId, NodoPadreId, Nombre, Marca, Modelo, Nivel, Atributos, Observaciones, Profundidad)
        SELECT NodoId, NodoPadreId, Nombre, Marca, Modelo, Nivel, AtributosDinamicos, Observaciones, Profundidad
          FROM ArbolNodos
         ORDER BY Profundidad ASC, Orden ASC;

        DECLARE @MaxNodos INT = (SELECT ISNULL(MAX(Orden), 0) FROM #NodosInstanciar);
        DECLARE @k INT = 1;
        DECLARE @TotalInstanciados INT = 1;

        WHILE @k <= @MaxNodos
        BEGIN
            DECLARE @nId INT, @pId INT, @nName NVARCHAR(200);
            DECLARE @nBrand NVARCHAR(100), @nModel NVARCHAR(100), @nLevel NVARCHAR(20);
            DECLARE @nAttr NVARCHAR(MAX), @nObs NVARCHAR(MAX);

            SELECT @nId = NodoId, @pId = NodoPadreId, @nName = Nombre,
                   @nBrand = Marca, @nModel = Modelo, @nLevel = Nivel,
                   @nAttr = Atributos, @nObs = Observaciones
              FROM #NodosInstanciar
             WHERE Orden = @k;

            DECLARE @PadreCode NVARCHAR(60);
            DECLARE @PadreRuta NVARCHAR(400);

            SELECT @PadreCode = CodigoActivo,
                   @PadreRuta = RutaAncestros
              FROM @Mapeo
             WHERE NodoId = @pId;

            IF @PadreCode IS NOT NULL
            BEGIN
                DECLARE @chTable TABLE (cnt INT NOT NULL);
                UPDATE dbo.Activo WITH (UPDLOCK, HOLDLOCK)
                   SET ContadorHijos += 1
                 OUTPUT inserted.ContadorHijos INTO @chTable(cnt)
                  WHERE CodigoActivo = @PadreCode;

                DECLARE @chCnt INT; SELECT @chCnt = cnt FROM @chTable;
                DELETE FROM @chTable;

                DECLARE @HijoCode NVARCHAR(60) = CONCAT(@PadreCode, '-', FORMAT(@chCnt, '00'));
                DECLARE @HijoRuta NVARCHAR(400) = CASE 
                    WHEN @PadreRuta = '' THEN @PadreCode 
                    ELSE CONCAT(@PadreRuta, '/', @PadreCode) 
                END;

                DECLARE @HijoAttr NVARCHAR(MAX) = CASE WHEN @CopiarAtributos = 1 THEN @nAttr ELSE NULL END;

                INSERT INTO dbo.Activo (
                    CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, CodigoActivoPadre,
                    Nivel, RutaAncestros, Estado, Serie, AtributosDinamicos, DatosImagen,
                    Observaciones, ContadorHijos, CreadoEn
                )
                VALUES (
                    @HijoCode, @nName, @nBrand, @nModel, @AreaDestinoId,
                    '', @PadreCode, @nLevel, @HijoRuta, 'active', NULL,
                    @HijoAttr, NULL, @nObs, 0, SYSUTCDATETIME()
                );

                INSERT INTO @Mapeo (NodoId, CodigoActivo, RutaAncestros)
                VALUES (@nId, @HijoCode, @HijoRuta);

                SET @TotalInstanciados += 1;
            END;

            SET @k += 1;
        END;

        DROP TABLE #NodosInstanciar;

        -- Auditoría e historial
        DECLARE @AuditUser INT = @UserId;
        IF @AuditUser IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @AuditUser)
            SET @AuditUser = NULL;
        DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@UserName)), N''), N'SISTEMA');

        INSERT INTO dbo.HistorialEstadoActivo (
            CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario
        )
        SELECT CodigoActivo, 'active', SYSUTCDATETIME(), @AreaDestinoId,
               CONCAT(N'Creado a partir de plantilla ID ', @PlantillaId), @AuditUser, @UName
          FROM @Mapeo;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (
            @AuditUser, @UName, 'ASSET_CREATED_FROM_TEMPLATE', 'ASSETS', @NuevoCodigoRaiz,
            CONCAT(N'Activo ', @NuevoCodigoRaiz, N' y su estructura creados a partir de plantilla ID ', 
                   @PlantillaId, N' en área ', @AreaDestinoId, N' con ', @TotalInstanciados, N' elementos.')
        );

        COMMIT TRANSACTION;

        SELECT @NuevoCodigoRaiz AS CodigoActivo,
               @NuevoCodigoRaiz AS assetCode,
               @NuevoCodigoRaiz AS id,
               @NombreFinalRaiz AS Nombre,
               @AreaDestinoId   AS AreaId,
               @TotalInstanciados AS totalNodos;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#NodosInstanciar') IS NOT NULL DROP TABLE #NodosInstanciar;
        THROW;
    END CATCH
END;
GO

-- 5. ACTUALIZACIÓN DE uspActivoActualizar:
-- Permite modificar el número de serie de los equipos garantizando unicidad global
-- entre activos no eliminados y registrando siempre el cambio en dbo.BitacoraKardex (ASSET_SERIAL_CHANGED)
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

        DECLARE @currStatus NVARCHAR(25), @currArea NVARCHAR(15), @oldSerial NVARCHAR(100);
        SELECT @currStatus = Estado, @currArea = AreaId, @oldSerial = Serie
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @TargetCode;

        DECLARE @NewCleanSerial NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@Serial)), '');

        -- Validar unicidad del número de serie
        IF @NewCleanSerial IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Activo WHERE Serie = @NewCleanSerial AND CodigoActivo <> @TargetCode AND Estado <> 'deleted')
                RAISERROR(N'El número de serie ya está en uso por otro activo activo.', 16, 1);
        END;

        DECLARE @DesiredStatus NVARCHAR(25) = COALESCE(NULLIF(LTRIM(RTRIM(@Status)), N''), NULLIF(LTRIM(RTRIM(@Estado)), N''));

        UPDATE dbo.Activo
           SET Nombre             = COALESCE(@Name, Nombre),
               Marca              = @Brand,
               Modelo             = @Model,
               EstacionId         = COALESCE(@StationId, EstacionId, ''),
               Serie              = @NewCleanSerial,
               AtributosDinamicos = COALESCE(@DynamicAttributes, AtributosDinamicos),
               DatosImagen        = COALESCE(@ImageData, DatosImagen),
               Observaciones      = COALESCE(@Observaciones, Observaciones),
               Estado             = COALESCE(@DesiredStatus, Estado),
               ActualizadoEn      = SYSUTCDATETIME()
         WHERE CodigoActivo = @TargetCode;

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

        -- Auditoría obligatoria en Bitácora Kardex si el número de serie cambió
        IF ISNULL(@NewCleanSerial, N'') <> ISNULL(@oldSerial, N'')
        BEGIN
            INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
            VALUES (@UserId, @UNameAuditUpd, 'ASSET_SERIAL_CHANGED', 'ASSETS', @TargetCode,
                    CONCAT(N'Número de serie del activo ', @TargetCode, N' modificado de "', ISNULL(@oldSerial, N'(sin serie)'), N'" a "', ISNULL(@NewCleanSerial, N'(sin serie)'), N'".'));
        END;

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
