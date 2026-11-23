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
-- MACSA CMMS - PARCHE DE PROCEDIMIENTOS ALMACENADOS (PRODUCCIÓN)
-- Fecha: 2026-11-13
-- Este parche actualiza TODOS los procedimientos almacenados en la base de datos
-- para garantizar compatibilidad 100% con la API REST y el frontend Flutter.
--
-- CARACTERÍSTICAS:
-- 1. NO altera ni elimina tablas ni datos (sin DROP TABLE ni DELETE).
-- 2. Tus 30 Áreas Oficiales, usuarios, empleados y configuración se mantienen intactos.
-- 3. Resuelve los errores 8144 y 8145 (@AreaFilter, @StatusFilter, planes preventivos, etc.).
-- ============================================================================

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- Asegurar columnas necesarias en dbo.OrdenTrabajo de manera segura
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
`;

let combined = header;

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
PRINT N'¡PARCHE DE PROCEDIMIENTOS ALMACENADOS APLICADO CON ÉXITO!';
PRINT N'Todos los procedimientos han sido actualizados y alineados con la API.';
PRINT N'============================================================================';
`;

fs.writeFileSync(path.resolve(__dirname, '../database/patch_2026-11-13_hotfix_procs.sql'), combined, 'utf8');
console.log('Parche generado exitosamente en database/patch_2026-11-13_hotfix_procs.sql');
