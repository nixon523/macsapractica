USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'=== Actualizando trigger y procedimientos para EsEquipoProceso ===';
GO

-- 1. Actualizar Trigger trActivo_Inmutable para incluir EsEquipoProceso
CREATE OR ALTER TRIGGER dbo.trActivo_Inmutable
ON dbo.Activo
INSTEAD OF UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
          FROM inserted i
          JOIN deleted d ON i.CodigoActivo = d.CodigoActivo
         WHERE i.AreaId            <> d.AreaId
            OR i.Nivel             <> d.Nivel
            OR i.RutaAncestros     <> d.RutaAncestros
            OR (i.CodigoActivoPadre <> d.CodigoActivoPadre
                OR (i.CodigoActivoPadre IS NULL AND d.CodigoActivoPadre IS NOT NULL)
                OR (i.CodigoActivoPadre IS NOT NULL AND d.CodigoActivoPadre IS NULL))
            OR (d.Serie IS NOT NULL AND i.Serie <> d.Serie)
    )
    BEGIN
        RAISERROR(N'Violación de inmutabilidad: no se pueden modificar AreaId, Nivel, RutaAncestros, CodigoActivoPadre ni Serie tras la creación.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    UPDATE a
       SET Nombre                    = i.Nombre,
           Marca                     = i.Marca,
           Modelo                    = i.Modelo,
           EstacionId                = i.EstacionId,
           Estado                    = i.Estado,
           TraspasadoACodigo         = i.TraspasadoACodigo,
           Serie                     = i.Serie,
           AtributosDinamicos        = i.AtributosDinamicos,
           DatosImagen               = i.DatosImagen,
           ContadorHijos             = i.ContadorHijos,
           EliminadoEn               = i.EliminadoEn,
           EliminadoPorUsuarioId     = i.EliminadoPorUsuarioId,
           EliminadoPorNombreUsuario = i.EliminadoPorNombreUsuario,
           EsEquipoProceso           = i.EsEquipoProceso,
           ActualizadoEn             = SYSUTCDATETIME()
      FROM dbo.Activo a
      JOIN inserted i ON a.CodigoActivo = i.CodigoActivo;
END;
GO
PRINT N'  [OK] Trigger trActivo_Inmutable actualizado.';
GO

-- 2. Actualizar uspActivoObtenerRaicesPorArea
CREATE OR ALTER PROCEDURE dbo.uspActivoObtenerRaicesPorArea @AreaId NVARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CodigoActivo AS AssetCode, Nombre AS Name, Marca AS Brand, Modelo AS Model,
           AreaId, EstacionId AS StationId, CodigoActivoPadre AS ParentAssetCode,
           Nivel AS Level, RutaAncestros AS AncestorsPath, Estado AS Status,
           TraspasadoACodigo AS TransferredToId, Serie AS Serial,
           AtributosDinamicos AS DynamicAttributes, DatosImagen AS ImageData,
           ContadorHijos AS ChildCounter, CreadoEn AS CreatedAt, ActualizadoEn AS UpdatedAt,
           EsEquipoProceso AS EsEquipoProceso
      FROM dbo.Activo
     WHERE AreaId = @AreaId AND CodigoActivoPadre IS NULL AND Estado <> 'deleted'
     ORDER BY Nombre ASC;
END;
GO
PRINT N'  [OK] SP uspActivoObtenerRaicesPorArea actualizado.';
GO

-- 3. Actualizar uspActivoObtenerHijos
CREATE OR ALTER PROCEDURE dbo.uspActivoObtenerHijos
    @AreaId NVARCHAR(15) = NULL, @ParentAssetCode NVARCHAR(60) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CodigoActivo AS AssetCode, Nombre AS Name, Marca AS Brand, Modelo AS Model,
           AreaId, EstacionId AS StationId, CodigoActivoPadre AS ParentAssetCode,
           Nivel AS Level, RutaAncestros AS AncestorsPath, Estado AS Status,
           TraspasadoACodigo AS TransferredToId, Serie AS Serial,
           AtributosDinamicos AS DynamicAttributes, DatosImagen AS ImageData,
           ContadorHijos AS ChildCounter, CreadoEn AS CreatedAt, ActualizadoEn AS UpdatedAt,
           EsEquipoProceso AS EsEquipoProceso
      FROM dbo.Activo
     WHERE (@AreaId IS NULL OR AreaId = @AreaId)
       AND ((@ParentAssetCode IS NULL AND CodigoActivoPadre IS NULL) OR CodigoActivoPadre = @ParentAssetCode)
       AND Estado <> 'deleted'
     ORDER BY Nombre ASC;
END;
GO
PRINT N'  [OK] SP uspActivoObtenerHijos actualizado.';
GO

-- 4. Actualizar uspActivoBuscar
CREATE OR ALTER PROCEDURE dbo.uspActivoBuscar
    @AreaId NVARCHAR(15) = NULL, @Query NVARCHAR(200), @Status NVARCHAR(25) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT a.CodigoActivo AS AssetCode, a.Nombre AS Name, a.Marca AS Brand, a.Modelo AS Model,
           a.AreaId, a.EstacionId AS StationId, a.CodigoActivoPadre AS ParentAssetCode,
           a.Nivel AS Level, a.RutaAncestros AS AncestorsPath, a.Estado AS Status,
           a.TraspasadoACodigo AS TransferredToId, a.Serie AS Serial,
           a.AtributosDinamicos AS DynamicAttributes, a.DatosImagen AS ImageData,
           a.ContadorHijos AS ChildCounter, a.CreadoEn AS CreatedAt, a.ActualizadoEn AS UpdatedAt,
           a.EsEquipoProceso AS EsEquipoProceso
      FROM dbo.Activo a
     CROSS APPLY (SELECT COUNT(*) AS TokenCount FROM STRING_SPLIT(@Query, ' ') WHERE LTRIM(RTRIM(value)) <> '') cnt
     WHERE (@AreaId IS NULL OR a.AreaId = @AreaId)
       AND a.Estado <> 'deleted'
       AND (@Status IS NULL OR a.Estado = @Status)
       AND (cnt.TokenCount = 0 OR
            (SELECT COUNT(*) FROM STRING_SPLIT(@Query, ' ') t
              WHERE t.value <> '' AND a.TextoBusqueda LIKE '%' + t.value + '%') = cnt.TokenCount)
     ORDER BY a.Nombre ASC;
END;
GO
PRINT N'  [OK] SP uspActivoBuscar actualizado.';
GO

-- 5. Actualizar uspActivoBuscarPorSerie
CREATE OR ALTER PROCEDURE dbo.uspActivoBuscarPorSerie @Serial NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) CodigoActivo AS AssetCode, Nombre AS Name, Marca AS Brand, Modelo AS Model,
           AreaId, EstacionId AS StationId, CodigoActivoPadre AS ParentAssetCode,
           Nivel AS Level, RutaAncestros AS AncestorsPath, Estado AS Status,
           TraspasadoACodigo AS TransferredToId, Serie AS Serial,
           AtributosDinamicos AS DynamicAttributes, DatosImagen AS ImageData,
           ContadorHijos AS ChildCounter, CreadoEn AS CreatedAt, ActualizadoEn AS UpdatedAt,
           EsEquipoProceso AS EsEquipoProceso
      FROM dbo.Activo
     WHERE Serie = @Serial AND Estado <> 'deleted'
     ORDER BY CASE WHEN Estado = 'active' THEN 0 ELSE 1 END, CreadoEn DESC;
END;
GO
PRINT N'  [OK] SP uspActivoBuscarPorSerie actualizado.';
GO

-- 6. Actualizar uspReporteOperacionObtenerPorSemana
CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionObtenerPorSemana
    @AreaId          NVARCHAR(15),
    @LunesDeLaSemana DATE
AS
BEGIN
    SET NOCOUNT ON;

    WITH Dias AS (
        SELECT DATEADD(day, n, @LunesDeLaSemana) AS Dia
        FROM (VALUES (0),(1),(2),(3),(4),(5),(6)) t(n)
    ),
    ActivosProceso AS (
        SELECT CodigoActivo, Nombre
          FROM dbo.Activo
         WHERE AreaId = @AreaId
           AND Nivel = 'equipment'
           AND EsEquipoProceso = 1
           AND Estado NOT IN ('deleted', 'transferredDeactivated')
    )
    SELECT
        ap.CodigoActivo, ap.Nombre AS NombreActivo, d.Dia AS FechaOperacion,
        r.ReporteId,
        ISNULL(r.HorasTotalesJornada, 24)  AS HorasTotalesJornada,
        ISNULL(r.HorasOperacion, 0)        AS HorasOperacion,
        ISNULL(r.HorasParoFalla, 0)        AS HorasParoFalla,
        ISNULL(r.HorasParoMantPrev, 0)     AS HorasParoMantPrev,
        ISNULL(r.HorasParoMantCorr, 0)     AS HorasParoMantCorr,
        ISNULL(r.HorasParoPlanificado, 0)  AS HorasParoPlanificado,
        ISNULL(r.HorasParoExterno, 0)      AS HorasParoExterno,
        r.Observaciones,
        r.RegistradoPorNombreUsuario,
        r.RegistradoEn,
        CASE WHEN r.ReporteId IS NULL THEN NULL
             ELSE CAST(CAST((r.HorasOperacion / NULLIF(r.HorasTotalesJornada,0))*100 AS DECIMAL(5,2)) AS FLOAT)
        END AS DisponibilidadPct
    FROM ActivosProceso ap
    CROSS JOIN Dias d
    LEFT JOIN dbo.ReporteOperacionDiaria r
           ON r.CodigoActivo   = ap.CodigoActivo
          AND r.FechaOperacion = d.Dia
    ORDER BY ap.Nombre, d.Dia;
END;
GO
PRINT N'  [OK] SP uspReporteOperacionObtenerPorSemana actualizado.';
GO
