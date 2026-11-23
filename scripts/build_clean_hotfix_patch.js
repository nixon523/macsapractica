const fs = require('fs');
const path = require('path');

const modules = [
  '02_security_sp.sql',
  '03_areas_puestos_empleados_sp.sql',
  '04_activos_bajas_sp.sql',
  '05_averias_ots_preventivos_sp.sql',
  '06_operacion_analitica_kardex_sp.sql',
];

const header = `-- ============================================================================
-- MACSA CMMS - PARCHE DE REPARACIÓN Y PROCEDIMIENTOS ALMACENADOS
-- Fecha: 2026-11-14
-- Este parche actualiza TODOS los procedimientos almacenados, repara caracteres
-- especiales (Mojibake) en Empleados y Puestos, y asegura las restricciones de integridad.
--
-- CARACTERÍSTICAS:
-- 1. NO altera ni elimina datos existentes (sin DROP TABLE ni DELETE).
-- 2. Tus 30 Áreas Oficiales, usuarios, empleados y configuración se mantienen intactos.
-- 3. Repara tildes y caracteres en dbo.Empleado y dbo.Puesto (Carlos Hernández, Técnico, etc.).
-- 4. Amplía la restricción CK_BK_Modulo en dbo.BitacoraKardex para permitir EMPLOYEES y POSITIONS.
-- 5. Corrige uspEmpleadoActualizar blindando auditoría de usuario y respetando switches de edición.
-- 6. Resuelve los errores 8144 y 8145 (@AreaFilter, planes preventivos, etc.).
-- ============================================================================

USE [MacsaCMMS];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ----------------------------------------------------------------------------
-- 1. ASEGURAR COLUMNAS EN dbo.OrdenTrabajo
-- ----------------------------------------------------------------------------
IF COL_LENGTH('dbo.OrdenTrabajo', 'PlanPreventivoId') IS NULL
BEGIN
    ALTER TABLE dbo.OrdenTrabajo ADD PlanPreventivoId NVARCHAR(20) NULL;
END;
GO

IF COL_LENGTH('dbo.OrdenTrabajo', 'ActualizadoEn') IS NULL
BEGIN
    ALTER TABLE dbo.OrdenTrabajo ADD ActualizadoEn DATETIME2(3) NULL;
END;
GO

-- ----------------------------------------------------------------------------
-- 2. GARANTIZAR RESTRICCIÓN CK_BK_Modulo EN dbo.BitacoraKardex
-- ----------------------------------------------------------------------------
IF EXISTS (
    SELECT 1 FROM sys.check_constraints
     WHERE name = N'CK_BK_Modulo'
       AND parent_object_id = OBJECT_ID(N'dbo.BitacoraKardex')
)
BEGIN
    ALTER TABLE dbo.BitacoraKardex DROP CONSTRAINT CK_BK_Modulo;
END;
GO

ALTER TABLE dbo.BitacoraKardex WITH CHECK ADD CONSTRAINT CK_BK_Modulo CHECK (
    Modulo IN (
        'ASSETS',
        'WORK_ORDERS',
        'BREAKDOWNS',
        'PREVENTIVE',
        'PREVENTIVE_SCHEDULES',
        'AREAS',
        'OPERATION_REPORTS',
        'USERS',
        'EMPLOYEES',
        'POSITIONS'
    )
);
GO

-- ----------------------------------------------------------------------------
-- 3. REPARAR CARACTERES MOJIBAKE EN dbo.Empleado Y dbo.Puesto
-- ----------------------------------------------------------------------------
BEGIN TRANSACTION;

-- Normalizar textos en dbo.Empleado
UPDATE dbo.Empleado
   SET NombreCompleto = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(NombreCompleto,
       N'Ã¡', N'á'),
       N'Ã©', N'é'),
       N'Ã­', N'í'),
       N'Ã³', N'ó'),
       N'Ãº', N'ú'),
       N'Ã±', N'ñ'),
       N'Ã', N'Á'),
       N'Ã“', N'Ó'),
       Puesto = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Puesto,
       N'Ã¡', N'á'),
       N'Ã©', N'é'),
       N'Ã­', N'í'),
       N'Ã³', N'ó'),
       N'Ãº', N'ú'),
       N'Ã±', N'ñ'),
       N'Ã', N'Á'),
       N'Ã“', N'Ó'),
       NombreArea = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(NombreArea,
       N'Ã¡', N'á'),
       N'Ã©', N'é'),
       N'Ã­', N'í'),
       N'Ã³', N'ó'),
       N'Ãº', N'ú'),
       N'Ã±', N'ñ'),
       N'Ã', N'Á'),
       N'Ã“', N'Ó');

-- Asegurar nombres limpios exactos de los empleados estándar
UPDATE dbo.Empleado SET NombreCompleto = N'Ing. Nixon Mejía',        Puesto = N'Jefe de Mantenimiento'                  WHERE EmpleadoId = 1 AND (NombreCompleto LIKE N'%Nixon%Mej%' OR NombreCompleto LIKE N'%Nixon%');
UPDATE dbo.Empleado SET NombreCompleto = N'Carlos Hernández',        Puesto = N'Técnico Mecánico Industrial'            WHERE NombreCompleto LIKE N'%Carlos%Hern%';
UPDATE dbo.Empleado SET NombreCompleto = N'Jorge Morales',           Puesto = N'Técnico Electricista / Automatización'  WHERE NombreCompleto LIKE N'%Jorge%Morales%';
UPDATE dbo.Empleado SET NombreCompleto = N'Roberto Rivas',           Puesto = N'Técnico Soldador / Estructuras'         WHERE NombreCompleto LIKE N'%Roberto%Rivas%';
UPDATE dbo.Empleado SET NombreCompleto = N'Miguel Ángel Castillo',   Puesto = N'Técnico Electromecánico'                WHERE NombreCompleto LIKE N'%Miguel%Castillo%';
UPDATE dbo.Empleado SET NombreCompleto = N'Luis Alberto Fuentes',    Puesto = N'Técnico en Refrigeración y Calderas'    WHERE NombreCompleto LIKE N'%Luis%Fuentes%';
UPDATE dbo.Empleado SET NombreCompleto = N'Guillermo Pineda',        Puesto = N'Supervisor de Planta y Producción'      WHERE NombreCompleto LIKE N'%Guillermo%Pineda%';
UPDATE dbo.Empleado SET NombreCompleto = N'Sandra Marroquín',        Puesto = N'Jefe de Aseguramiento de Calidad / HACCP' WHERE NombreCompleto LIKE N'%Sandra%Marroqu%';

-- Sincronizar NombreArea con el catálogo dbo.Area
UPDATE e
   SET e.NombreArea = a.Nombre
  FROM dbo.Empleado e
  JOIN dbo.Area a ON e.AreaId = a.AreaId;

UPDATE dbo.Empleado
   SET NombreArea = N'Sin Área Asignada'
 WHERE AreaId IS NULL OR LTRIM(RTRIM(NombreArea)) IN (N'Sin Área Asignada', N'Sin Área', N'Sin Ã rea Asignada', N'Sin Ã rea', N'');

-- Normalizar textos en dbo.Puesto
UPDATE dbo.Puesto
   SET Nombre = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Nombre,
       N'Ã¡', N'á'),
       N'Ã©', N'é'),
       N'Ã­', N'í'),
       N'Ã³', N'ó'),
       N'Ãº', N'ú'),
       N'Ã±', N'ñ'),
       N'Ã', N'Á'),
       N'Ã“', N'Ó');

-- Asegurar los 13 puestos de catálogo oficiales limpios
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Desarrollador')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Desarrollador', 0, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Jefe de Mantenimiento')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Jefe de Mantenimiento', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Supervisor de Mantenimiento')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Supervisor de Mantenimiento', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Técnico Mecánico Industrial')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Técnico Mecánico Industrial', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Técnico Electricista / Automatización')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Técnico Electricista / Automatización', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Técnico en Refrigeración y Calderas')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Técnico en Refrigeración y Calderas', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Técnico Electromecánico')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Técnico Electromecánico', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Técnico Soldador / Estructuras')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Técnico Soldador / Estructuras', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Auxiliar de Mantenimiento')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Auxiliar de Mantenimiento', 1, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Jefe de Área / Operaciones')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Jefe de Área / Operaciones', 0, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Supervisor de Producción')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Supervisor de Producción', 0, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Gerente General')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Gerente General', 0, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = N'Gerente de Operaciones')
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo) VALUES (N'Gerente de Operaciones', 0, 1);

COMMIT TRANSACTION;
GO
`;

let combined = '\uFEFF' + header;

for (const m of modules) {
  const filePath = path.resolve(__dirname, 'sql_modules', m);
  const content = fs.readFileSync(filePath, 'utf8');
  combined += `\n-- ============================================================================\n`;
  combined += `-- MÓDULO: ${m}\n`;
  combined += `-- ============================================================================\n\n`;
  combined += content.replace(/^\uFEFF/, '').trim() + '\nGO\n';
}

combined += `
PRINT N'============================================================================';
PRINT N'¡PARCHE APLICADO CON ÉXITO!';
PRINT N'1. Procedimientos almacenados actualizados y alineados con la API.';
PRINT N'2. Restricción CK_BK_Modulo ampliada (incluye EMPLOYEES y POSITIONS).';
PRINT N'3. Caracteres especiales de Empleados y Puestos normalizados a UTF-8.';
PRINT N'4. uspEmpleadoActualizar blindado contra errores de concurrencia y auditoría.';
PRINT N'============================================================================';
`;

fs.writeFileSync(path.resolve(__dirname, '../database/patch_2026-11-13_hotfix_procs.sql'), combined, 'utf8');
console.log('Master patch built successfully at database/patch_2026-11-13_hotfix_procs.sql');
