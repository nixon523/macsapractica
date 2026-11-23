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

const files = walk(path.resolve(__dirname, '../../macsa-api/src'));
const procs = {};

files.forEach(f => {
  const content = fs.readFileSync(f, 'utf8');
  const regex = /execProc\(\s*['"]([^'"]+)['"]\s*(?:,\s*(\{[\s\S]*?\}|[^,\)]+))?/g;
  let match;
  while ((match = regex.exec(content)) !== null) {
    const procName = match[1];
    const argsStr = match[2] || '';
    if (!procs[procName]) procs[procName] = [];
    procs[procName].push({ file: path.relative(path.resolve(__dirname, '../../macsa-api'), f), rawArgs: argsStr.replace(/\s+/g, ' ').substring(0, 140) });
  }
});

for (const [name, calls] of Object.entries(procs)) {
  console.log(`\n=== ${name} ===`);
  calls.forEach(c => console.log(`  [${c.file}] ${c.rawArgs}`));
}
