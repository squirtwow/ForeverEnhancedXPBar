// Runs every test: each Tools/Test*.lua in fengari (a pass is its last line saying "TestName: N checks passed", since a
// failure can still exit 0), then the node tests (Lua limits and the rules). Exits 1 if any fails.
// Run from the addon's folder with: node Tools/RunTests.mjs
import { readdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const kit = join(root, '..', '_Toolchain', 'lua-check', 'node_modules');
const fengari = join(kit, '.bin', process.platform === 'win32' ? 'fengari.cmd' : 'fengari');
let failed = 0;

for (const file of readdirSync(join(root, 'Tools')).filter(name => /^Test\w*\.lua$/.test(name)).sort()) {
  const run = spawnSync(fengari, [`Tools/${file}`], { cwd: root, encoding: 'utf8', shell: process.platform === 'win32', timeout: 300000 });
  const output = `${run.stdout || ''}${run.stderr || ''}`.trim();
  const last = output.split(/\r?\n/).pop() || '';
  const name = file.replace(/\.lua$/, '');
  if (new RegExp(`^${name}: \\d+ checks passed$`).test(last)) {
    console.log(`pass  ${last}`);
  } else {
    failed++;
    console.log(`FAIL  ${file}\n${output}`);
  }
}

for (const file of ['TestLuaLimits.mjs', 'TestRules.mjs']) {
  const run = spawnSync(process.execPath, ['--test', `Tools/${file}`], { cwd: root, encoding: 'utf8',
    env: { ...process.env, FENGARI: process.env.FENGARI || join(kit, 'fengari') }, timeout: 300000 });
  const output = `${run.stdout || ''}${run.stderr || ''}`;
  if (run.status === 0) {
    console.log(`pass  ${file}`);
  } else {
    failed++;
    console.log(`FAIL  ${file}\n${output}`);
  }
}

console.log(failed ? `${failed} failed` : 'all passed');
process.exit(failed ? 1 : 0);
