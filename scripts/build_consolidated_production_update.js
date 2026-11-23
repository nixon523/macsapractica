import fs from 'fs';
import path from 'path';

const initSql = fs.readFileSync('database/init.sql', 'utf8');
const marcasSql = fs.readFileSync('database/patch_2026-11-17_marcas_y_mantenimientos_centro_costo.sql', 'utf8');
const combinedSql = initSql + '\n' + marcasSql;

function extractProcedure(sql, procName) {
  const regex = new RegExp(`CREATE OR ALTER PROCEDURE\\s+dbo\\.${procName}[\\s\\S]*?(?=\\r?\\nGO)`, 'i');
  const match = sql.match(regex);
  if (!match) {
    throw new Error(`Procedure ${procName} not found in sql`);
  }
  return match[0];
}

const procsToInclude = [
  'uspCatalogosObtener',
  'uspAtributoCatalogoListar',
  'uspAtributoCatalogoCrear',
  'uspAtributoCatalogoActualizar',
  'uspAtributoCatalogoEliminar',
  'uspUnidadMedidaListar',
  'uspUnidadMedidaCrear',
  'uspUnidadMedidaActualizar',
  'uspUnidadMedidaEliminar',
  'uspMarcaListar',
  'uspMarcaCrear',
  'uspMarcaActualizar',
  'uspMarcaEliminar',
  'uspReporteMantenimientosPorCentroCosto',
  'uspReporteMantenimientosPorCentroCostoDetalle',
  'uspActivoCrear',
  'uspActivoActualizar',
  'uspActivoAlternarEstado',
  'uspActivoTraspasar',
  'uspActivoClonarArbol',
  'uspPlantillaActivoGuardarDesdeActivo',
  'uspPlantillaActivoListar',
  'uspPlantillaActivoObtenerDetalle',
  'uspPlantillaActivoInstanciar',
  'uspPlantillaActivoEliminar',
  'uspOrdenTrabajoCrear',
  'uspPlanPreventivoCrear',
  'uspReporteAveriaVincularOrdenTrabajo'
];

let script = `-- ============================================================================
-- MACSA CMMS - SCRIPT CONSOLIDADO DE ACTUALIZACIÓN A PRODUCCIÓN
-- Fecha: 2026-11-18
--
-- Este script es 100% IDEMPOTENTE y seguro de ejecutar en la base de datos de producción.
-- Contiene:
--   1. Catálogo de Atributos Técnicos y Unidades de Medida (con tildes corregidas)
--   2. Campo Observaciones opcional en activos
--   3. Tablas para Plantillas de Activos (PlantillaActivo y PlantillaActivoNodo)
--   4. Catálogo y tabla de Marcas (dbo.Marca)
--   5. Procedimientos de clonación e instanciación de plantillas (sin conflicto de collation)
--   6. Procedimiento de traspaso de activos (sin conflicto de collation)
--   7. Edición de N° de serie en equipos con unicidad y auditoría en Bitácora Kardex
--   8. Métricas de mantenimientos por Centro de Costo (Dashboard)
--   9. Correcciones en alternar estado y creación de OT desde averías
--  10. Permisos de ejecución para macsa_app
-- ============================================================================

USE [MacsaCMMS];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'>> Iniciando actualización integral de MacsaCMMS (2026-11-18)...';
GO

-- ----------------------------------------------------------------------------
-- 1. TABLA dbo.UnidadMedida
-- ----------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.UnidadMedida', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.UnidadMedida (
        UnidadMedidaId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_UnidadMedida PRIMARY KEY,
        Codigo         NVARCHAR(20) NOT NULL CONSTRAINT UQ_UnidadMedida_Codigo UNIQUE,
        Nombre         NVARCHAR(100) NOT NULL,
        Activo         BIT NOT NULL CONSTRAINT DF_UnidadMedida_Activo DEFAULT (1),
        CreadoEn       DATETIME2(3) NOT NULL CONSTRAINT DF_UnidadMedida_CreadoEn DEFAULT (SYSUTCDATETIME()),
        ActualizadoEn  DATETIME2(3) NOT NULL CONSTRAINT DF_UnidadMedida_ActualizadoEn DEFAULT (SYSUTCDATETIME())
    );

    CREATE NONCLUSTERED INDEX IX_UnidadMedida_Activo_Codigo
        ON dbo.UnidadMedida (Activo, Codigo);

    PRINT N'  - Tabla dbo.UnidadMedida creada.';
END
GO

-- ----------------------------------------------------------------------------
-- 2. TABLA dbo.AtributoCatalogo
-- ----------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.AtributoCatalogo', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AtributoCatalogo (
        AtributoId            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AtributoCatalogo PRIMARY KEY,
        Nombre                NVARCHAR(100) NOT NULL CONSTRAINT UQ_AtributoCatalogo_Nombre UNIQUE,
        Descripcion           NVARCHAR(255) NULL,
        UnidadMedidaIdDefecto INT NULL CONSTRAINT FK_AtributoCatalogo_UnidadMedida
                              REFERENCES dbo.UnidadMedida (UnidadMedidaId),
        Activo                BIT NOT NULL CONSTRAINT DF_AtributoCatalogo_Activo DEFAULT (1),
        CreadoEn              DATETIME2(3) NOT NULL CONSTRAINT DF_AtributoCatalogo_CreadoEn DEFAULT (SYSUTCDATETIME()),
        ActualizadoEn         DATETIME2(3) NOT NULL CONSTRAINT DF_AtributoCatalogo_ActualizadoEn DEFAULT (SYSUTCDATETIME())
    );

    CREATE NONCLUSTERED INDEX IX_AtributoCatalogo_Activo_Nombre
        ON dbo.AtributoCatalogo (Activo, Nombre);

    PRINT N'  - Tabla dbo.AtributoCatalogo creada.';
END
GO

-- Sembrado / Corrección de caracteres en Unidades de Medida
MERGE INTO dbo.UnidadMedida AS Target
USING (VALUES
    (N'V',     N'Voltios'),
    (N'A',     N'Amperios'),
    (N'kW',    N'Kilovatios'),
    (N'HP',    N'Caballos de fuerza'),
    (N'RPM',   N'Revoluciones por minuto'),
    (N'PSI',   N'Libras por pulgada cuadrada'),
    (N'bar',   N'Bares'),
    (N'°C',    N'Grados Celsius'),
    (N'°F',    N'Grados Fahrenheit'),
    (N'Hz',    N'Hercios'),
    (N'BTU/h', N'BTU por hora'),
    (N'TR',    N'Toneladas de refrigeración'),
    (N'CFM',   N'Pies cúbicos por minuto'),
    (N'm³/h',  N'Metros cúbicos por hora'),
    (N'GPM',   N'Galones por minuto'),
    (N'L',     N'Litros'),
    (N'kg',    N'Kilogramos'),
    (N'lb',    N'Libras'),
    (N'm',     N'Metros'),
    (N'mm',    N'Milímetros'),
    (N'pulg',  N'Pulgadas'),
    (N'kVA',   N'Kilovoltiamperios')
) AS Source (Codigo, Nombre)
ON Target.Codigo = Source.Codigo
WHEN MATCHED THEN
    UPDATE SET Target.Nombre = Source.Nombre, Target.Activo = 1, Target.ActualizadoEn = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (Codigo, Nombre, Activo) VALUES (Source.Codigo, Source.Nombre, 1);
GO

-- Sembrado / Corrección de caracteres en Atributos Técnicos
MERGE INTO dbo.AtributoCatalogo AS Target
USING (
    SELECT s.Nombre, s.Descripcion, u.UnidadMedidaId
    FROM (VALUES
        (N'Potencia',               N'Potencia nominal del activo o motor',               N'kW'),
        (N'Voltaje de Operación',   N'Tensión eléctrica nominal de alimentación',         N'V'),
        (N'Corriente / Amperaje',   N'Consumo de corriente nominal',                      N'A'),
        (N'Velocidad de Giro',      N'Velocidad nominal de rotación',                     N'RPM'),
        (N'Presión de Trabajo',     N'Presión nominal operativa de diseño',               N'PSI'),
        (N'Temperatura Máxima',     N'Límite térmico operativo recomendado',              N'°C'),
        (N'Caudal de Aire / Fluido',N'Flujo volumétrico nominal',                         N'CFM'),
        (N'Capacidad Térmica',      N'Capacidad de enfriamiento / calefacción',           N'BTU/h'),
        (N'Frecuencia',             N'Frecuencia eléctrica nominal',                      N'Hz'),
        (N'Número de Fases',        N'Monofásico (1F), Bifásico (2F) o Trifásico (3F)',   NULL),
        (N'Peso',                   N'Peso neto del equipo',                              N'kg')
    ) AS s (Nombre, Descripcion, UnidadCodigo)
    LEFT JOIN dbo.UnidadMedida u ON u.Codigo = s.UnidadCodigo
) AS Source
ON Target.Nombre = Source.Nombre
WHEN MATCHED THEN
    UPDATE SET Target.Descripcion = Source.Descripcion, Target.UnidadMedidaIdDefecto = Source.UnidadMedidaId, Target.Activo = 1, Target.ActualizadoEn = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (Nombre, Descripcion, UnidadMedidaIdDefecto, Activo) VALUES (Source.Nombre, Source.Descripcion, Source.UnidadMedidaId, 1);
GO

-- ----------------------------------------------------------------------------
-- 3. CAMPO Observaciones EN dbo.Activo
-- ----------------------------------------------------------------------------
IF COL_LENGTH(N'dbo.Activo', N'Observaciones') IS NULL
BEGIN
    ALTER TABLE dbo.Activo ADD Observaciones NVARCHAR(MAX) NULL;
    PRINT N'  - Columna Observaciones agregada a dbo.Activo.';
END
GO

-- ----------------------------------------------------------------------------
-- 4. TABLAS DE PLANTILLAS: dbo.PlantillaActivo y dbo.PlantillaActivoNodo
-- ----------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.PlantillaActivo', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PlantillaActivo (
        PlantillaId   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PlantillaActivo PRIMARY KEY,
        Nombre        NVARCHAR(150) NOT NULL CONSTRAINT UQ_PlantillaActivo_Nombre UNIQUE,
        Descripcion   NVARCHAR(255) NULL,
        NivelRaiz     NVARCHAR(20) NOT NULL CONSTRAINT DF_PlantillaActivo_NivelRaiz DEFAULT ('equipment'),
        TotalNodos    INT NOT NULL CONSTRAINT DF_PlantillaActivo_TotalNodos DEFAULT (1),
        Activo        BIT NOT NULL CONSTRAINT DF_PlantillaActivo_Activo DEFAULT (1),
        CreadoEn      DATETIME2(3) NOT NULL CONSTRAINT DF_PlantillaActivo_CreadoEn DEFAULT (SYSUTCDATETIME()),
        ActualizadoEn DATETIME2(3) NOT NULL CONSTRAINT DF_PlantillaActivo_ActualizadoEn DEFAULT (SYSUTCDATETIME())
    );
    PRINT N'  - Tabla dbo.PlantillaActivo creada.';
END
GO

IF OBJECT_ID(N'dbo.PlantillaActivoNodo', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PlantillaActivoNodo (
        NodoId            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PlantillaActivoNodo PRIMARY KEY,
        PlantillaId       INT NOT NULL CONSTRAINT FK_PlantillaActivoNodo_Plantilla FOREIGN KEY REFERENCES dbo.PlantillaActivo(PlantillaId) ON DELETE CASCADE,
        NodoPadreId       INT NULL CONSTRAINT FK_PlantillaActivoNodo_Padre FOREIGN KEY REFERENCES dbo.PlantillaActivoNodo(NodoId),
        Nombre            NVARCHAR(200) NOT NULL,
        Marca             NVARCHAR(100) NULL,
        Modelo            NVARCHAR(100) NULL,
        Nivel             NVARCHAR(20) NOT NULL,
        Orden             INT NOT NULL CONSTRAINT DF_PlantillaActivoNodo_Orden DEFAULT (1),
        AtributosDinamicos NVARCHAR(MAX) NULL,
        Observaciones     NVARCHAR(MAX) NULL,
        CreadoEn          DATETIME2(3) NOT NULL CONSTRAINT DF_PlantillaActivoNodo_CreadoEn DEFAULT (SYSUTCDATETIME())
    );
    CREATE NONCLUSTERED INDEX IX_PlantillaActivoNodo_PlantillaId ON dbo.PlantillaActivoNodo (PlantillaId, NodoPadreId);
    PRINT N'  - Tabla dbo.PlantillaActivoNodo creada.';
END
GO

-- ----------------------------------------------------------------------------
-- 5. TABLA dbo.Marca
-- ----------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.Marca', N'U') IS NULL
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
    PRINT N'  - Tabla dbo.Marca creada.';
END
GO

-- Sembrado inicial de Marcas
INSERT INTO dbo.Marca (Nombre, Descripcion)
SELECT DISTINCT LTRIM(RTRIM(a.Marca)), N'Marca registrada previamente en activos'
  FROM dbo.Activo a
 WHERE a.Marca IS NOT NULL 
   AND LTRIM(RTRIM(a.Marca)) <> ''
   AND NOT EXISTS (SELECT 1 FROM dbo.Marca m WHERE UPPER(m.Nombre) = UPPER(LTRIM(RTRIM(a.Marca))));
GO

MERGE INTO dbo.Marca AS Target
USING (VALUES
    (N'Siemens',       N'Automatización industrial y motores'),
    (N'Schneider',     N'Equipos eléctricos y arrancadores'),
    (N'ABB',           N'Robótica, variadores y motores'),
    (N'WEG',           N'Motores eléctricos y generadores'),
    (N'Danfoss',       N'Variadores de frecuencia y refrigeración'),
    (N'Festo',         N'Neumática y automatización'),
    (N'SMC',           N'Componentes neumáticos industriales'),
    (N'SKF',           N'Rodamientos y sistemas de lubricación'),
    (N'Sew Eurodrive', N'Motorreductores y transmisión'),
    (N'Allen-Bradley', N'PLCs y control industrial Rockwell'),
    (N'Mitsubishi',    N'Automatización y servomotores'),
    (N'Omron',         N'Sensores, relevadores y visión'),
    (N'Caterpillar',   N'Generadores y maquinaria pesada'),
    (N'Ingersoll Rand',N'Compresores de aire industrial'),
    (N'Atlas Copco',   N'Compresores y generadores de nitrógeno')
) AS Source (Nombre, Descripcion)
ON UPPER(Target.Nombre) = UPPER(Source.Nombre)
WHEN NOT MATCHED THEN
    INSERT (Nombre, Descripcion, Activo) VALUES (Source.Nombre, Source.Descripcion, 1);
GO

-- ----------------------------------------------------------------------------
-- 6. SINCRONIZACIÓN DE CONTADORES (PREVENCIÓN DE CLAVE DUPLICADA PK_OrdenTrabajo)
-- ----------------------------------------------------------------------------
DECLARE @realMaxOT INT = 0;
SELECT @realMaxOT = ISNULL(MAX(TRY_CAST(SUBSTRING(OrdenTrabajoId, 9, 10) AS INT)), 0)
  FROM dbo.OrdenTrabajo
 WHERE OrdenTrabajoId LIKE CONCAT('OT-', YEAR(SYSUTCDATETIME()), '-%');

IF NOT EXISTS (SELECT 1 FROM dbo.Contador WHERE Nombre = 'work_orders')
BEGIN
    INSERT INTO dbo.Contador (Nombre, SiguienteNumero) VALUES ('work_orders', @realMaxOT + 1);
END
ELSE
BEGIN
    UPDATE dbo.Contador
       SET SiguienteNumero = CASE WHEN SiguienteNumero <= @realMaxOT THEN @realMaxOT + 1 ELSE SiguienteNumero END
     WHERE Nombre = 'work_orders';
END;

DECLARE @realMaxPM INT = 0;
SELECT @realMaxPM = ISNULL(MAX(TRY_CAST(SUBSTRING(PlanId, 9, 10) AS INT)), 0)
  FROM dbo.PlanPreventivo
 WHERE PlanId LIKE CONCAT('PM-', YEAR(SYSUTCDATETIME()), '-%');

IF NOT EXISTS (SELECT 1 FROM dbo.Contador WHERE Nombre = 'preventive_schedules')
BEGIN
    INSERT INTO dbo.Contador (Nombre, SiguienteNumero) VALUES ('preventive_schedules', @realMaxPM + 1);
END
ELSE
BEGIN
    UPDATE dbo.Contador
       SET SiguienteNumero = CASE WHEN SiguienteNumero <= @realMaxPM THEN @realMaxPM + 1 ELSE SiguienteNumero END
     WHERE Nombre = 'preventive_schedules';
END;
PRINT N'  - Contadores transaccionales sincronizados correctamente con los datos existentes.';
GO

PRINT N'>> Tablas y datos de catálogo listos. Procediendo a actualizar procedimientos almacenados...';
GO
`;

for (const proc of procsToInclude) {
  const procCode = extractProcedure(combinedSql, proc);
  script += `\n-- ============================================================================\n-- PROCEDIMIENTO: ${proc}\n-- ============================================================================\nSET ANSI_NULLS ON;\nGO\nSET QUOTED_IDENTIFIER ON;\nGO\n${procCode}\nGO\n`;
}

script += `
-- ----------------------------------------------------------------------------
-- PERMISOS PARA macsa_app
-- ----------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'macsa_app')
BEGIN
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.UnidadMedida TO [macsa_app];
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.AtributoCatalogo TO [macsa_app];
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.PlantillaActivo TO [macsa_app];
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.PlantillaActivoNodo TO [macsa_app];
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Marca TO [macsa_app];

    GRANT EXECUTE ON dbo.uspCatalogosObtener TO [macsa_app];
    GRANT EXECUTE ON dbo.uspAtributoCatalogoListar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspAtributoCatalogoCrear TO [macsa_app];
    GRANT EXECUTE ON dbo.uspAtributoCatalogoActualizar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspAtributoCatalogoEliminar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspUnidadMedidaListar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspUnidadMedidaCrear TO [macsa_app];
    GRANT EXECUTE ON dbo.uspUnidadMedidaActualizar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspUnidadMedidaEliminar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspMarcaListar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspMarcaCrear TO [macsa_app];
    GRANT EXECUTE ON dbo.uspMarcaActualizar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspMarcaEliminar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspReporteMantenimientosPorCentroCosto TO [macsa_app];
    GRANT EXECUTE ON dbo.uspReporteMantenimientosPorCentroCostoDetalle TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoCrear TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoActualizar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoAlternarEstado TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoTraspasar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspActivoClonarArbol TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlantillaActivoGuardarDesdeActivo TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlantillaActivoListar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlantillaActivoObtenerDetalle TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlantillaActivoInstanciar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlantillaActivoEliminar TO [macsa_app];
    GRANT EXECUTE ON dbo.uspOrdenTrabajoCrear TO [macsa_app];
    GRANT EXECUTE ON dbo.uspPlanPreventivoCrear TO [macsa_app];
    GRANT EXECUTE ON dbo.uspReporteAveriaVincularOrdenTrabajo TO [macsa_app];

    PRINT N'  - Permisos otorgados exitosamente a macsa_app.';
END
GO

PRINT N'>> ACTUALIZACIÓN COMPLETADA CON ÉXITO.';
GO
`;

fs.writeFileSync('database/update_produccion_2026-11-18.sql', script, 'utf8');
console.log('Script database/update_produccion_2026-11-18.sql generated successfully.');
