const fs = require('fs');
const path = require('path');

function walk(dir) {
  let results = [];
  const list = fs.readdirSync(dir);
  list.forEach(file => {
    const fullPath = path.join(dir, file);
    const stat = fs.statSync(fullPath);
    if (stat && stat.isDirectory()) {
      results = results.concat(walk(fullPath));
    } else if (file.endsWith('.js')) {
      results.push(fullPath);
    }
  });
  return results;
}

const apiFiles = walk(path.resolve(__dirname, '../../macsa-api/src'));
const apiCalls = {};

apiFiles.forEach(f => {
  const content = fs.readFileSync(f, 'utf8');
  const regex = /execProc\(\s*['"]([^'"]+)['"]\s*(?:,\s*(\{[\s\S]*?\}|[^,\)]+))?/g;
  let match;
  while ((match = regex.exec(content)) !== null) {
    const proc = match[1];
    const argsStr = match[2] || '';
    if (!apiCalls[proc]) apiCalls[proc] = new Set();
    if (argsStr.startsWith('{')) {
      const keyRegex = /\b([a-zA-Z_][a-zA-Z0-9_]*)\s*:/g;
      let k;
      while ((k = keyRegex.exec(argsStr)) !== null) {
        apiCalls[proc].add(k[1]);
      }
    }
  }
});

const sqlDir = path.resolve(__dirname, 'sql_modules');
const sqlFiles = fs.readdirSync(sqlDir).filter(f => f.endsWith('.sql'));
const sqlProcs = {};

sqlFiles.forEach(f => {
  const content = fs.readFileSync(path.join(sqlDir, f), 'utf8');
  const spRegex = /CREATE\s+OR\s+ALTER\s+PROCEDURE\s+dbo\.([a-zA-Z0-9_]+)([\s\S]*?)AS\s+BEGIN/gi;
  let spMatch;
  while ((spMatch = spRegex.exec(content)) !== null) {
    const proc = spMatch[1];
    const paramsBlock = spMatch[2];
    const paramRegex = /@([a-zA-Z0-9_]+)/g;
    const params = new Set();
    let pm;
    while ((pm = paramRegex.exec(paramsBlock)) !== null) {
      params.add(pm[1].toLowerCase());
    }
    sqlProcs[proc.toLowerCase()] = { originalName: proc, params, file: f };
  }
});

console.log('=== AUDITORIA COMPLETA DE PARÁMETROS SQL VS API ===');
for (const [proc, apiParams] of Object.entries(apiCalls)) {
  const sql = sqlProcs[proc.toLowerCase()];
  if (!sql) {
    console.log(`[PROCEDIMIENTO NO ENCONTRADO EN SQL]: ${proc}`);
    continue;
  }
  const missing = [];
  for (const p of apiParams) {
    if (!sql.params.has(p.toLowerCase())) {
      missing.push(p);
    }
  }
  if (missing.length > 0) {
    console.log(`[MISMATCH EN ${proc}] (${sql.file}):`);
    console.log(`   Parámetros que la API envía pero el SP no tiene: @${missing.join(', @')}`);
  }
}
console.log('=== FIN AUDITORIA ===');
