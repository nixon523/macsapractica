// scripts/build_clean_production_sql.js
// Concatena y valida los módulos SQL para generar el script de producción

const fs = require('fs');
const path = require('path');

const modulesDir = path.join(__dirname, 'sql_modules');
const outputPath = path.join(__dirname, '..', 'database', 'deploy_produccion_2026-11-13.sql');
const initPath = path.join(__dirname, '..', 'database', 'init.sql');

const moduleFiles = [
    '01_tables.sql',
    '02_security_sp.sql',
    '03_areas_puestos_empleados_sp.sql',
    '04_activos_bajas_sp.sql',
    '05_averias_ots_preventivos_sp.sql',
    '06_operacion_analitica_kardex_sp.sql',
    '07_seed_data.sql'
];

console.log('Uniendo módulos SQL...');

let combinedSql = '';
for (const file of moduleFiles) {
    const fullPath = path.join(modulesDir, file);
    console.log(`- Leyendo ${file}...`);
    const content = fs.readFileSync(fullPath, 'utf8');
    combinedSql += content + '\n\n';
}

fs.writeFileSync(outputPath, combinedSql, { encoding: 'utf8' });
console.log(`Script maestro generado exitosamente en: ${outputPath}`);

fs.writeFileSync(initPath, combinedSql, { encoding: 'utf8' });
console.log(`init.sql sincronizado exitosamente en: ${initPath}`);
