/* ============================================================================
   MACSA CMMS - Grupo Macsa
   migracion_transferencia_subarbol_completo.sql
   Fase 1: Traspaso Jerárquico Atómico de Subárbol Completo y Blindaje de Integridad
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ============================================================================
-- 1. Procedimiento Almacenado de Traspaso de Subárbol Completo (4 Niveles)
-- ============================================================================
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

        -- 1. Validar activo raíz origen
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

        -- 2. Validar que el área destino exista
        IF NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @TargetAreaId)
            RAISERROR(N'El área destino especificada no existe.', 16, 1);

        -- ====================================================================
        -- 2.1 RETORNO A ÁREA DE ORIGEN (Restauración de Activo Original)
        -- ====================================================================
        -- Si este activo proviene originalmente de @TargetAreaId, restauramos
        -- el registro original en lugar de crear un código duplicado.
        DECLARE @PreviousOriginCode NVARCHAR(60);
        SELECT @PreviousOriginCode = CodigoActivo
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE AreaId = @TargetAreaId
           AND TraspasadoACodigo = @SourceAssetCode
           AND Estado = 'transferredDeactivated'
           AND Nivel = 'equipment';

        IF @PreviousOriginCode IS NOT NULL
        BEGIN
            -- 1. Reactivar el árbol original en @TargetAreaId
            UPDATE a
               SET a.Estado = 'active',
                   a.TraspasadoACodigo = NULL,
                   a.ActualizadoEn = SYSUTCDATETIME()
              FROM dbo.Activo a
             WHERE a.CodigoActivo = @PreviousOriginCode
                OR a.RutaAncestros = @PreviousOriginCode
                OR a.RutaAncestros LIKE @PreviousOriginCode + ',%';

            -- 2. Desactivar el árbol intermedio en el área actual (@SourceAssetCode)
            UPDATE a
               SET a.Estado = 'transferredDeactivated',
                   a.TraspasadoACodigo = @PreviousOriginCode,
                   a.ActualizadoEn = SYSUTCDATETIME()
              FROM dbo.Activo a
             WHERE a.CodigoActivo = @SourceAssetCode
                OR a.RutaAncestros = @SourceAssetCode
                OR a.RutaAncestros LIKE @SourceAssetCode + ',%';

            -- 3. Cerrar historiales de estado en el área intermedia y abrir en destino
            UPDATE hea
               SET FinalizadoEn = SYSUTCDATETIME()
              FROM dbo.HistorialEstadoActivo hea
             WHERE (hea.CodigoActivo = @SourceAssetCode 
                    OR hea.CodigoActivo LIKE @SourceAssetCode + '-%')
               AND hea.FinalizadoEn IS NULL;

            INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
            VALUES (@PreviousOriginCode, 'active', SYSUTCDATETIME(), @TargetAreaId,
                    CONCAT(N'Retorno a su área original desde ', @srcArea, N' (código intermedio: ', @SourceAssetCode, N')'),
                    @UserId, @UserName);

            -- 4. Reactivar planes preventivos del equipo original si estaban pausados por traspaso
            UPDATE dbo.PlanPreventivo
               SET Estado = 'active',
                   Notas = ISNULL(Notas, '') + CONCAT(CHAR(13), CHAR(10), N'[Sistema]: Plan reactivado automáticamente por retorno del equipo a su área original.')
             WHERE CodigoActivo = @PreviousOriginCode AND Estado = 'paused';

            -- 5. Registrar en Bitácora Kardex
            INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
            VALUES (@UserId, @UserName, 'ASSET_TRANSFER', 'ASSETS', @SourceAssetCode,
                    CONCAT(N'Activo ', @SourceAssetCode, N' retornado a su área y código original ', @PreviousOriginCode, N' en ', @TargetAreaId, N'.'));

            COMMIT TRANSACTION;
            SELECT @PreviousOriginCode AS NewAssetCode, @PreviousOriginCode AS CodigoActivo;
            RETURN;
        END;

        -- 3. Obtener todo el subárbol (Padre + Hijos + Nietos + Bisnietos) para área nueva
        CREATE TABLE #ArbolOrigen (
            OldCode       NVARCHAR(60) COLLATE database_default PRIMARY KEY,
            Nombre        NVARCHAR(200) COLLATE database_default,
            Marca         NVARCHAR(100) COLLATE database_default,
            Modelo        NVARCHAR(100) COLLATE database_default,
            EstacionId    NVARCHAR(100) COLLATE database_default,
            OldParentCode NVARCHAR(60) COLLATE database_default,
            Nivel         NVARCHAR(20) COLLATE database_default,
            RutaAncestros NVARCHAR(400) COLLATE database_default,
            Serie         NVARCHAR(100) COLLATE database_default,
            Atributos     NVARCHAR(MAX) COLLATE database_default,
            DatosImagen   NVARCHAR(MAX),
            Depth         INT,
            ChildOrder    INT,
            NewCode       NVARCHAR(60) COLLATE database_default,
            NewParentCode NVARCHAR(60) COLLATE database_default,
            NewRuta       NVARCHAR(400) COLLATE database_default
        );

        -- CTE Recursiva para identificar todos los descendientes
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

        -- 4. Verificar candados de baja en cualquier nodo del árbol
        IF EXISTS (
            SELECT 1 FROM dbo.CandadoBaja cb
            INNER JOIN #ArbolOrigen o ON o.OldCode = cb.CodigoActivo
            WHERE cb.EstadoCandado = 'pending'
        )
        BEGIN
            RAISERROR(N'El activo o alguno de sus componentes tiene una solicitud de baja pendiente.', 16, 1);
        END;

        -- 5. Generar correlativo raíz en el área destino
        DECLARE @targetCounter TABLE (val INT NOT NULL);
        UPDATE dbo.Area WITH (UPDLOCK, HOLDLOCK)
           SET ContadorActivos += 1
         OUTPUT inserted.ContadorActivos INTO @targetCounter(val)
          WHERE AreaId = @TargetAreaId;

        DECLARE @nextRoot INT; SELECT @nextRoot = val FROM @targetCounter;
        DECLARE @NewRootCode NVARCHAR(60) = CONCAT(@TargetAreaId, '-', FORMAT(@nextRoot, '000'));

        -- Mapear nuevo código del equipo raíz
        UPDATE #ArbolOrigen 
           SET NewCode = @NewRootCode, 
               NewParentCode = NULL,
               NewRuta = ''
         WHERE Depth = 0;

        -- 6. Mapear nuevos códigos para Niveles 1, 2 y 3 (BFS por profundidad)
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

        -- 7. Insertar el nuevo subárbol completo en el Área Destino
        INSERT INTO dbo.Activo (
            CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, CodigoActivoPadre,
            Nivel, RutaAncestros, Estado, Serie, AtributosDinamicos, DatosImagen,
            ContadorHijos, CreadoEn
        )
        SELECT 
            t.NewCode, t.Nombre, t.Marca, t.Modelo, @TargetAreaId, t.EstacionId, t.NewParentCode,
            t.Nivel, t.NewRuta, 'active', t.Serie, t.Atributos, t.DatosImagen,
            (SELECT COUNT(*) FROM #ArbolOrigen ch WHERE ch.OldParentCode = t.OldCode),
            SYSUTCDATETIME()
        FROM #ArbolOrigen t
        ORDER BY t.Depth ASC;

        -- 8. Desactivar todo el subárbol origen (transferredDeactivated) y apuntar al nuevo código
        UPDATE a
           SET a.Estado = 'transferredDeactivated',
               a.TraspasadoACodigo = t.NewCode,
               a.ActualizadoEn = SYSUTCDATETIME()
          FROM dbo.Activo a
          INNER JOIN #ArbolOrigen t ON a.CodigoActivo = t.OldCode;

        -- 9. Cerrar historiales de estado origen y abrir nuevos en el destino
        UPDATE hea
           SET FinalizadoEn = SYSUTCDATETIME()
          FROM dbo.HistorialEstadoActivo hea
          INNER JOIN #ArbolOrigen t ON hea.CodigoActivo = t.OldCode
         WHERE hea.FinalizadoEn IS NULL;

        INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, UsuarioId, NombreUsuario)
        SELECT t.NewCode, 'active', SYSUTCDATETIME(), @TargetAreaId,
               CONCAT(N'Alta por transferencia desde área ', @srcArea, N' (código anterior: ', t.OldCode, N')'),
               @UserId, @UserName
          FROM #ArbolOrigen t;

        -- 10. Pausar planes preventivos asociados al código padre origen
        UPDATE dbo.PlanPreventivo
           SET Estado = 'paused',
               Notas = ISNULL(Notas, '') + CONCAT(CHAR(13), CHAR(10), N'[Sistema]: Plan pausado automáticamente por transferencia del equipo a ', @TargetAreaId, N' como ', @NewRootCode, N'.')
         WHERE CodigoActivo = @SourceAssetCode AND Estado = 'active';

        -- 11. Registrar en la Bitácora Kardex inmutable
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_TRANSFER', 'ASSETS', @SourceAssetCode,
                CONCAT(N'Activo ', @SourceAssetCode, N' y su subárbol completo (', (SELECT COUNT(*) FROM #ArbolOrigen), N' componentes) transferidos a ', @TargetAreaId, N' como ', @NewRootCode, N'.'));

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

-- ============================================================================
-- 2. Procedimiento Almacenado de Blindaje de Reactivación
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.uspActivoReactivar
    @AssetCode NVARCHAR(60),
    @UserId    INT = NULL,
    @UserName  NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @targetCode NVARCHAR(60);
        SELECT @targetCode = TraspasadoACodigo
          FROM dbo.Activo WITH (UPDLOCK, HOLDLOCK)
         WHERE CodigoActivo = @AssetCode;

        IF @targetCode IS NOT NULL
        BEGIN
            -- Si el activo destino sigue existiendo y no está eliminado, bloquear reactivación arbitraria
            IF EXISTS (SELECT 1 FROM dbo.Activo WHERE CodigoActivo = @targetCode AND Estado <> 'deleted')
            BEGIN
                RAISERROR(N'No se puede reactivar directamente: este activo ya opera en otra área bajo el código %s. Si desea regresarlo a esta área, realice una transferencia formal desde el activo actual.', 16, 1, @targetCode);
            END;
        END;

        UPDATE dbo.Activo
           SET Estado = 'active', TraspasadoACodigo = NULL, ActualizadoEn = SYSUTCDATETIME()
         WHERE CodigoActivo = @AssetCode AND Estado = 'transferredDeactivated';

        IF @@ROWCOUNT = 0
            RAISERROR(N'Solo se pueden reactivar activos en estado desactivado por traspaso.', 16, 1);

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'ASSET_REACTIVATE', 'ASSETS', @AssetCode,
                CONCAT(N'Activo ', @AssetCode, N' reactivado.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT 'Migración Fase 1 (Traspaso Jerárquico Atómico y Blindaje) ejecutada exitosamente.';
GO
