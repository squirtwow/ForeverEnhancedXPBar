// The addon's rules, checked straight from its source: the TOC lists every Lua file once, in the harness's order; no em
// dash anywhere; no key binding changed and no frame taking the keyboard; GameTooltip never named; no text run as code;
// the game's frames only touched in GameBar.lua, and there only read, faded with SetAlpha and post-hooked (the
// containers' UpdateDividers, ApplyPendingBarToShow and UpdateShownState, and scripts), never the containers' alpha, the reputation bar or the vehicle bar; no key written on a game or EraUI frame or table,
// GameBar's own state in weak tables; the addon's frames anchored to UIParent (and the minimap button to the minimap);
// no CVar written, system chat never read, played time asked only behind askPlayed; every timer callback guarded;
// chat output only through Core.lua;
// settings changed only from their allowed places; every file's header names the settings it serves; British spelling in
// player text and quiet tags; no other addon named; the licence; and the art the code names.
// Run with: node --test Tools/TestRules.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';

const root = new URL('../', import.meta.url);
const read = name => readFile(new URL(name, root), 'utf8');

// Every Lua file the addon ships.
async function luaFiles() {
  return (await readdir(root, { withFileTypes: true })).filter(e => e.isFile() && /\.lua$/i.test(e.name)).map(e => e.name).sort();
}

// Lua with its comments and strings blanked out (lines kept), so only code is checked.
function codeOnly(lua) {
  let out = '';
  let i = 0;
  const blank = text => text.replace(/[^\n]/g, ' ');
  while (i < lua.length) {
    const rest = lua.slice(i);
    let match;
    if ((match = rest.match(/^--\[(=*)\[[\s\S]*?\]\1\]/)) || (match = rest.match(/^--[^\n]*/))) {
      out += blank(match[0]);
    } else if ((match = rest.match(/^\[(=*)\[[\s\S]*?\]\1\]/))) {
      out += '""' + blank(match[0].slice(2));
    } else if ((match = rest.match(/^"(?:[^"\\\n]|\\.)*"/)) || (match = rest.match(/^'(?:[^'\\\n]|\\.)*'/))) {
      out += '""' + blank(match[0].slice(2));
    } else {
      match = [lua[i]];
      out += lua[i];
    }
    i += match[0].length;
  }
  return out;
}

// The text in a Lua file's strings (comments left out).
function literals(lua) {
  const found = [];
  let i = 0;
  while (i < lua.length) {
    const rest = lua.slice(i);
    let match;
    if ((match = rest.match(/^--\[(=*)\[[\s\S]*?\]\1\]/)) || (match = rest.match(/^--[^\n]*/))) {
      // a comment
    } else if ((match = rest.match(/^\[(=*)\[([\s\S]*?)\]\1\]/))) {
      found.push({ text: match[2], index: i });
    } else if ((match = rest.match(/^"((?:[^"\\\n]|\\.)*)"/)) || (match = rest.match(/^'((?:[^'\\\n]|\\.)*)'/))) {
      found.push({ text: match[1], index: i });
    } else {
      match = [lua[i]];
    }
    i += match[0].length;
  }
  return found;
}

const lineOf = (text, index) => text.slice(0, index).split('\n').length;

async function addonCode() {
  const files = await luaFiles();
  assert.ok(files.length >= 10, 'the addon files found');
  return Promise.all(files.map(async name => {
    const source = await read(name);
    return { name, source, code: codeOnly(source) };
  }));
}

function find(files, pattern, skip = () => false) {
  const found = [];
  for (const { name, code } of files) {
    if (skip(name)) continue;
    for (const match of code.matchAll(pattern)) found.push(`${name}:${lineOf(code, match.index)} ${match[0].trim()}`);
  }
  return found;
}

const ORDER = ['Core.lua', 'Theme.lua', 'Track.lua', 'Quests.lua', 'Kills.lua', 'Tip.lua', 'Bar.lua', 'GameBar.lua', 'Window.lua',
  'MinimapButton.lua'];

test('the TOC: the right fields, and every Lua file once, in the harness\'s order', async () => {
  const toc = await read('ForeverEnhancedXPBar.toc');
  assert.match(toc, /^## Interface: 16001\r?$/m);
  assert.match(toc, /^## Title: Forever Enhanced XP Bar\r?$/m);
  assert.match(toc, /^## Author: Squirt\r?$/m);
  assert.match(toc, /^## SavedVariables: ForeverEnhancedXPBarDB\r?$/m);
  assert.match(toc, /^## Category: UI\r?$/m);
  // The version comes from the release tag (CurseForge's packager fills in
  // @project-version@), so the changelog's newest entry is a version number,
  // or "Unreleased" until the user approves one.
  assert.match(toc, /^## Version: @project-version@\r?$/m, 'the version is the tag\'s');
  assert.match(await read('CHANGELOG.txt'), /^# Changelog\r?\n\r?\n## (\d+\.\d+\.\d+|Unreleased)\r?$/m,
    'the changelog starts with a version number, or Unreleased');
  const icon = toc.match(/^## IconTexture: Interface\\AddOns\\ForeverEnhancedXPBar\\(.+?)\r?$/m);
  assert.ok(icon, 'an icon');
  assert.ok((await stat(new URL(icon[1].replace(/\\/g, '/'), root))).isFile(), 'and its file is there');
  const listed = toc.split(/\r?\n/).map(line => line.trim()).filter(line => line && !line.startsWith('#'));
  assert.deepEqual([...listed].sort(), await luaFiles(), 'every Lua file, once, and nothing else');
  assert.deepEqual(listed, ORDER, 'in the planned order');
  const harness = await read('Tools/Harness.lua');
  const files = harness.match(/H\.FILES = \{([\s\S]*?)\}/)[1].match(/"[^"]+"/g).map(name => name.slice(1, -1));
  assert.deepEqual(listed, files, 'the harness loads them in the TOC\'s order');
});

test('no em dash anywhere, even as an escape', async () => {
  // (This file is left out: it holds the pattern.)
  const names = [...await luaFiles(), 'ForeverEnhancedXPBar.toc', 'README.md', 'CHANGELOG.txt', 'LICENSE.txt', 'Tools/Notes.md',
    ...(await readdir(new URL('Tools/', root))).filter(n => /\.(lua|mjs)$/.test(n) && n !== 'TestRules.mjs').map(n => 'Tools/' + n)];
  const found = [];
  for (const name of names) {
    let text;
    try { text = await read(name) } catch { continue }
    text.split('\n').forEach((line, i) => {
      if (/—|\\226\\128\\148|\\u\{2014\}|&mdash;/.test(line)) found.push(`${name}:${i + 1}`);
    });
  }
  assert.deepEqual(found, []);
});

test('no key binding changed, no frame taking the keyboard', async () => {
  const files = await addonCode();
  assert.deepEqual(find(files, /\b(SetOverrideBinding\w*|ClearOverrideBindings|SetBinding\w*|SaveBindings|LoadBindings)\b/g), []);
  assert.deepEqual(find(files, /\b(EnableKeyboard|SetPropagateKeyboardInput|EnableGamePadButton)\s*\(/g), []);
});

test('GameTooltip never named: the addon\'s hover box is its own', async () => {
  const files = await addonCode();
  const found = find(files, /\bGameTooltip\w*/g);
  for (const { name, source } of files) {
    for (const { text, index } of literals(source)) if (/GameTooltip/.test(text)) found.push(`${name}:${lineOf(source, index)} "${text}"`);
  }
  assert.deepEqual(found, []);
});

test('no text run as code, nothing secure called, hooksecurefunc only on the containers\' passes in GameBar.lua', async () => {
  const files = await addonCode();
  const pattern = /(?<![\w.:])(loadstring|load|loadfile|dofile|RunScript|RunMacroText|setfenv|getfenv|rawset|securecall|secureexecuterange|issecurevariable)\s*\(/g;
  assert.deepEqual(find(files, pattern), []);
  assert.deepEqual(find(files, /\bhooksecurefunc\b/g, name => name === 'GameBar.lua'), [], 'no hook outside GameBar.lua');
  const gameBar = await read('GameBar.lua');
  const hooks = [...gameBar.matchAll(/hooksecurefunc\s*\(([^)]*)\)/g)].map(m => m[1].replace(/\s+/g, ' '));
  assert.deepEqual(hooks, ['container, name, Update'], 'one post-hook call, on each container pass in CONTAINER_HOOKS');
  const list = gameBar.match(/local CONTAINER_HOOKS = \{([^}]*)\}/);
  assert.ok(list, 'the list of container passes');
  assert.deepEqual([...list[1].matchAll(/"(\w+)"/g)].map(m => m[1]),
    ['UpdateDividers', 'ApplyPendingBarToShow', 'UpdateShownState'],
    'the dividers rebuilt, a container taking its new bar, a container showing or hiding');
});

// The game's frames and tables the addon names (and EraUI's).
const BLIZZARD = String.raw`(?:UIParent|WorldFrame|Minimap|MinimapCluster|StatusTrackingBarManager|MainStatusTrackingBarContainer|`
  + String.raw`SecondaryStatusTrackingBarContainer|StatusTrackingBarInfo|MainActionBar|MultiBarBottomLeft|MultiBarBottomRight|`
  + String.raw`StanceBar|PetActionBar|PossessActionBar|OverrideActionBar|PlayerCastingBarFrame|EraUI|EraUIClassicBar|PixelUtil|`
  + String.raw`UISpecialFrames|DEFAULT_CHAT_FRAME|ChatFrame\d+|SettingsPanel|EditModeManagerFrame|C_QuestLog)`;
const CHAIN = String.raw`((?:\s*(?:\.\s*[A-Za-z_]\w*|\[[^\]\n]*\]))*)`;
const FORBIDDEN = new Set(['Show', 'Hide', 'SetShown', 'SetScale', 'SetSize', 'SetWidth', 'SetHeight', 'SetPoint',
  'ClearAllPoints', 'SetAllPoints', 'SetParent', 'SetScript', 'SetFrameStrata', 'SetFrameLevel', 'EnableMouse',
  'SetAttribute', 'RegisterEvent', 'UnregisterEvent', 'UnregisterAllEvents', 'SetMovable', 'StartMoving',
  'StopMovingOrSizing', 'SetClampedToScreen', 'SetUserPlaced', 'SetToplevel', 'Raise', 'Lower', 'Click', 'SetAlpha',
  'SetMouseClickEnabled', 'SetMouseMotionEnabled', 'UpdateBarsShown', 'SetShownBar', 'ApplySystemAnchor', 'UpdateDividers']);

test('the game\'s frames named in the code are never shown, hidden, moved, faded, scripted or registered', async () => {
  const call = new RegExp(String.raw`(?<![\w.:])(${BLIZZARD})${CHAIN}\s*:\s*([A-Za-z_]\w*)\s*\(`, 'g');
  const found = [];
  for (const { name, code } of await addonCode()) {
    for (const match of code.matchAll(call)) {
      if (FORBIDDEN.has(match[3])) found.push(`${name}:${lineOf(code, match.index)} ${match[1]}${match[2]}:${match[3]}`);
    }
  }
  assert.deepEqual(found, []);
  assert.deepEqual(find(await addonCode(), /\b(OverrideActionBar|ReputationStatusBar|ExhaustionTick)\b/g), [],
    'never the vehicle bar, the reputation bar or the XP bar\'s rested marker');
});

// GameBar.lua has no frames of its own: every method it calls is on the game's frames, so it may only read them, fade
// them, hook their scripts and look through the dividers in use.
const READ = /^(Get|Is|Has|Can|Enumerate|Num|Does)/;
test('GameBar.lua only reads the game\'s frames, fades them with SetAlpha and hooks their scripts', async () => {
  const code = codeOnly(await read('GameBar.lua'));
  const found = [];
  for (const match of code.matchAll(/:\s*([A-Za-z_]\w*)\s*\(/g)) {
    const method = match[1];
    if (READ.test(method) || method === 'SetAlpha' || method === 'HookScript') continue;
    if (['Apply', 'BandActive', 'Blocked', 'Active', 'Get', 'Notify', 'DevLog', 'On', 'Listen', 'Guard'].includes(method)) continue;
    found.push(`GameBar.lua:${lineOf(code, match.index)} ${method}`);
  }
  assert.deepEqual(found, []);
  const hooked = [...code.matchAll(/HookScript\s*\(\s*""/g)].length;
  const scripts = [...(await read('GameBar.lua')).matchAll(/HookScript\s*\(\s*"(\w+)"/g)].map(m => m[1]);
  assert.equal(hooked, 3, 'three script hooks');
  assert.deepEqual(scripts, ['OnShow', 'OnHide', 'OnShow'], 'the XP bars showing and hiding, and a container showing');
  assert.deepEqual(find([{ name: 'GameBar.lua', code }], /\b(CreateFrame|EnableMouse|SetMouse\w*)\b/g), [],
    'no frames of its own, the mouse left alone');
});

test('no key written on a game or EraUI frame or table; GameBar\'s state in weak tables', async () => {
  const write = new RegExp(String.raw`(?<![\w.:])(${BLIZZARD})((?:\s*(?:\.\s*[A-Za-z_]\w*|\[[^\]\n]*\]))+)\s*=(?!=)`, 'g');
  const found = [];
  for (const { name, code } of await addonCode()) {
    for (const match of code.matchAll(write)) found.push(`${name}:${lineOf(code, match.index)} ${match[1]}${match[2]} =`);
  }
  assert.deepEqual(found, []);
  // GameBar.lua: every write into a table is into its own (or the addon's namespace).
  const own = new Set(['barAlpha', 'artAlpha', 'artOwner', 'hooked', 'out', 'list', 'F']);
  const code = codeOnly(await read('GameBar.lua'));
  const writes = [];
  for (const match of code.matchAll(/(?<![\w.:])([A-Za-z_]\w*)((?:\s*(?:\.\s*[A-Za-z_]\w*|\[[^\]\n]*\]))+)\s*(?:,\s*[\w.\[\]]+\s*)*=(?!=)/g)) {
    if (!own.has(match[1])) writes.push(`GameBar.lua:${lineOf(code, match.index)} ${match[1]}${match[2]} =`);
  }
  assert.deepEqual(writes, []);
  assert.match(await read('GameBar.lua'), /setmetatable\(\{\}, \{ __mode = "k" \}\)/, 'weak tables keyed by frame');
  // The one sanctioned list: the settings window joins the game's Escape list, as the family's windows do.
  const inserts = find(await addonCode(), /table\.insert\s*\(\s*UISpecialFrames[^)]*\)/g);
  assert.deepEqual(inserts.map(s => s.split(' ')[0].split(':')[0]), ['Window.lua'], 'only the settings window, once');
});

test('the addon\'s frames anchored to UIParent (the minimap button to the minimap), never to the game\'s bars', async () => {
  const found = [];
  for (const { name, code, source } of await addonCode()) {
    for (const match of source.matchAll(/:SetPoint\(([^)\n]*)\)/g)) {
      if (/\b(MainActionBar|MultiBar\w+|StanceBar|PetActionBar|PossessActionBar|EraUIClassicBar|StatusTrackingBarManager|\w+StatusTrackingBarContainer|PlayerCastingBarFrame)\b/.test(match[1])) {
        found.push(`${name}:${lineOf(source, match.index)} ${match[0]}`);
      }
    }
    if (name === 'Bar.lua') {
      for (const match of code.matchAll(/\b(bar|mover)\s*:\s*SetPoint\s*\(\s*""\s*,\s*([A-Za-z_]\w*)/g)) {
        if (match[2] !== 'UIParent') found.push(`${name}:${lineOf(code, match.index)} ${match[1]} anchored to ${match[2]}`);
      }
    }
  }
  assert.deepEqual(found, []);
  const bar = codeOnly(await read('Bar.lua'));
  assert.ok(/CreateFrame\s*\(\s*""\s*,\s*""\s*,\s*UIParent\s*\)/.test(bar), 'the bar is made under UIParent');
});

test('no CVar written, system chat never read, played time asked only behind askPlayed', async () => {
  const files = await addonCode();
  assert.deepEqual(find(files, /\b(SetCVar|ConsoleExec)\b/g), []);
  const found = [];
  for (const { name, source } of files) {
    for (const { text, index } of literals(source)) if (/CHAT_MSG_SYSTEM/.test(text)) found.push(`${name}:${lineOf(source, index)}`);
  }
  assert.deepEqual(found, [], 'CHAT_MSG_SYSTEM is secret in fights: never listened to');
  const asks = find(files, /\bRequestTimePlayed\s*\(/g);
  assert.deepEqual(asks.map(s => s.split(':')[0]), ['Track.lua'], 'played time asked in one place');
  const track = (await read('Track.lua')).split('\n');
  const line = Number(asks[0].split(':')[1].split(' ')[0]);
  assert.match(track[line - 1], /F:Get\("askPlayed"\)/, 'behind the askPlayed tick');
});

// Event handlers run under the event hub's pcall; a timer's callback must go through F:Guard to get the same (an error
// said once in chat, not the game's error popup): inline, or a local made with F:Guard in the same file.
test('every timer callback goes through F:Guard', async () => {
  const found = [];
  let timers = 0;
  for (const { name, code } of await addonCode()) {
    for (const match of code.matchAll(/\bC_Timer\s*\.\s*(After|NewTicker)\s*\(([^,()]+),\s*/g)) {
      timers++;
      const rest = code.slice(match.index + match[0].length);
      if (/^F\s*:\s*Guard\s*\(/.test(rest)) continue;
      const named = rest.match(/^(\w+)\s*\)/);
      if (named && new RegExp(String.raw`\blocal\s+${named[1]}\s*=\s*F\s*:\s*Guard\s*\(`).test(code)) continue;
      found.push(`${name}:${lineOf(code, match.index)}`);
    }
  }
  assert.ok(timers >= 10, `the timers found (${timers})`);
  assert.deepEqual(found, []);
});

test('chat output only through Core.lua', async () => {
  const files = await addonCode();
  assert.deepEqual(find(files, /(?<![\w.:])print\s*\(|:\s*AddMessage\s*\(/g, name => name === 'Core.lua'), []);
  assert.deepEqual(find(files, /\b(SendChatMessage|SendAddonMessage\w*)\b/g), [], 'nothing sent anywhere');
});

// Settings change only from the window; the minimap button saves its own angle and shows or hides the bar; Core's
// /xpbar minimap; the bar's placing saves its width.
const OWN_SETTINGS = { 'MinimapButton.lua': ['minimapAngle', 'showBar'], 'Core.lua': ['minimap'], 'Bar.lua': ['width'] };
test('settings and the reset only from their allowed places', async () => {
  const found = [];
  for (const { name, source, code } of await addonCode()) {
    if (name === 'Window.lua') continue;
    for (const match of code.matchAll(/\bF\s*:\s*(Set|Reset)\s*\(/g)) {
      if (name === 'Core.lua' && /function\s+$/.test(code.slice(Math.max(0, match.index - 12), match.index))) continue;
      const key = match[1] === 'Set' && source.slice(match.index).match(/^F\s*:\s*Set\s*\(\s*"(\w+)"/);
      if (key && (OWN_SETTINGS[name] || []).includes(key[1])) continue;
      found.push(`${name}:${lineOf(code, match.index)} F:${match[1]}`);
    }
  }
  assert.deepEqual(found, []);
  const window = codeOnly(await read('Window.lua'));
  assert.equal([...window.matchAll(/\bF\s*:\s*Reset\s*\(/g)].length, 1, 'one reset, from the window\'s own Reset button');
});

// Which file serves which setting: its header names each one.
const SERVES = {
  'Bar.lua': ['showBar', 'questSegment', 'restedSegment', 'lineUnder', 'questStripes', 'showAtMax', 'border', 'size', 'width',
    'textShow', 'textFormat'],
  'GameBar.lua': ['hideGameBar'], 'Track.lua': ['rateWindow', 'askPlayed'], 'MinimapButton.lua': ['minimap', 'minimapAngle', 'showBar'],
  'Tip.lua': ['dXP', 'dRested', 'dQuests', 'dDone', 'dLevelTime', 'dSession', 'dRate', 'dEta', 'dKills', 'dToQuests'],
};
test('every file\'s header names the settings it serves, and every setting is served', async () => {
  const core = await read('Core.lua');
  const options = new Set(['thin', 'normal', 'thick', 'large', 'always', 'hover', 'never', 'numbers', 'percent', 'both', '15m',
    '1h', 'session', 'bar', 'details', 'extras', 'limits', 'move', 'putBack', 'newSession']);
  const keys = [...core.matchAll(/\{ key = "(\w+)", label =/g)].map(m => m[1]).filter(k => !options.has(k));
  assert.equal(keys.length, 25, 'the 25 settings rows');
  const served = new Set(Object.values(SERVES).flat());
  assert.deepEqual(keys.filter(k => !served.has(k)), [], 'every setting has a file');
  for (const [file, list] of Object.entries(SERVES)) {
    const header = (await read(file)).match(/^(?:--[^\n]*\n)+/)[0];
    for (const key of list) assert.match(header, new RegExp(String.raw`\b${key}\b`), `${file}'s header names ${key}`);
  }
});

test('player text in British spelling, quiet tags only', async () => {
  const found = [];
  for (const { name, source } of await addonCode()) {
    for (const { text, index } of literals(source)) {
      const match = text.match(/\b(color|colors|colored|favorite|center|centered|gray|behavior|realize|organize|customize|honor|leveled|leveling|traveled|canceled|meter|meters)\b/i);
      if (match && !/^(CENTER|LEFT|RIGHT)$/.test(text)) found.push(`${name}:${lineOf(source, index)} ${match[1]}`);
      if (/\b(NEW|NEEDS TESTING|BETA)\b/.test(text)) found.push(`${name}:${lineOf(source, index)} boxed caps tag`);
    }
  }
  assert.deepEqual(found, []);
});

// Other addons' names are kept here as hashes only (sha1 of the lower-case name, first 16 hex digits), so this file names
// none either.
const OTHERS = new Set([
  '6fc79fada620a1c9', 'e52a90bc5daa975e', '02aca0a6f01611ce', 'af6d017462ed41ba', '5cab34c79b0b9875',
  'c5e50d412e7141ae', '88ed36849a168ebc', '8b416b70399abb68', '9dc7c8b069f26776', '85101e8dbaeeae36',
  '7f466e6770936442', 'fdd508e96907f59b', 'd8242d1e1459c6f5', '9f7ffe1ac0b90e2d', 'f6642857381c08dc',
  '16614b5df8db4ed3', '8e1fd1320c1ec0c9', '7b841cc1685b8265', 'c92ae2f85364c65b', '70298b52a39e477e',
  '7f0b6579f039a557', '0ca346c962ada50e', '1d5f29d807ee33b3', '4eb4424db53f0b18', 'ed937450d94b798d',
  '3ef3b2b382a5fafe', '940b3e148ba157e8', '9441a3fa00716ca6', 'e27e6ec1d1647816',
]);
const hash = text => createHash('sha1').update(text).digest('hex').slice(0, 16);

test('no other addon named', async () => {
  const names = [...await luaFiles(), 'ForeverEnhancedXPBar.toc', 'README.md', 'CHANGELOG.txt', 'Tools/Notes.md',
    ...(await readdir(new URL('Tools/', root))).filter(n => /\.(lua|mjs)$/.test(n)).map(n => 'Tools/' + n)];
  const found = [];
  for (const name of names) {
    let text;
    try { text = await read(name) } catch { continue }
    text.split('\n').forEach((line, i) => {
      const words = line.toLowerCase().split(/[^a-z0-9!]+/).filter(Boolean);
      for (let n = 1; n <= 3; n++) {
        for (let w = 0; w + n <= words.length; w++) {
          if (OTHERS.has(hash(words.slice(w, w + n).join(' ')))) found.push(`${name}:${i + 1} word ${w + 1}`);
        }
      }
    });
  }
  assert.deepEqual(found, []);
  assert.equal(OTHERS.size, 29, 'the whole list');
  assert.ok(!OTHERS.has(hash('forever enhanced xp bar')), 'our own name is not on it');
});

test('the licence, and every piece of art the code names', async () => {
  assert.match(await read('LICENSE.txt'), /Copyright \(c\) 2026 Squirt\. All rights reserved\./);
  const named = new Set();
  for (const { source } of await addonCode()) {
    for (const match of source.matchAll(/(?:%s)?([A-Z]\w*)\.tga/g)) named.add(match[1]); // also "%sHeart.tga"
  }
  named.add('Icon'); // the TOC's
  const SIZES = ['large', 'normal', 'thick', 'thin'];
  const caps = SIZES.flatMap(size => [`CapL_${size}`, `CapR_${size}`]);
  assert.deepEqual([...named].sort(), [...caps, 'Heart', 'Icon', 'Logo', 'MinimapIcon', 'Stripes'].sort(), 'the art found');
  const media = (await readdir(new URL('Media/', root))).map(n => n.replace(/\.tga$/, '')).sort();
  assert.deepEqual(media, [...named].sort(), 'and nothing else in Media (no art left over)');
  for (const art of named) {
    const file = await readFile(new URL('Media/' + art + '.tga', root));
    assert.equal(file[2], 2, `${art}: uncompressed true colour`);
    assert.equal(file[16], 32, `${art}: 32-bit`);
    assert.equal(file[17], 0x28, `${art}: top-left origin`);
    assert.equal(file.length, 18 + file.readUInt16LE(12) * file.readUInt16LE(14) * 4, `${art}: whole`);
  }
  const stripes = await readFile(new URL('Media/Stripes.tga', root));
  assert.equal(stripes.readUInt16LE(12) + 'x' + stripes.readUInt16LE(14), '16x16', 'the stripes repeat every 16 px');
  // The end caps (two masks a texture: the game allows three at most): 32 x 128, clear outside the arcs at the outer
  // end's top and bottom, solid down the inner side (so a cap that stops at its edge cuts nothing else of the bar) and
  // solid between the arcs. Each arc takes radius / height of the file's height, from Bar.lua's RADIUS and Core's
  // F.SIZES, so it comes out round once the cap is the radius wide and the bar tall.
  const bar = await read('Bar.lua'), core = await read('Core.lua');
  const radius = Object.fromEntries([...bar.match(/local RADIUS = \{([^}]*)\}/)[1].matchAll(/(\w+) = (\d+)/g)].map(m => [m[1], +m[2]]));
  const height = Object.fromEntries([...core.match(/F\.SIZES = \{([^}]*)\}/)[1].matchAll(/(\w+) = (\d+)/g)].map(m => [m[1], +m[2]]));
  assert.deepEqual(Object.keys(radius).sort(), SIZES, 'a radius for every size');
  assert.deepEqual(Object.keys(height).sort(), SIZES, 'a height for every size');
  for (const size of SIZES) {
    for (const side of ['L', 'R']) {
      const name = `Cap${side}_${size}`;
      const file = await readFile(new URL('Media/' + name + '.tga', root));
      const w = file.readUInt16LE(12), h = file.readUInt16LE(14);
      assert.equal(w + 'x' + h, '32x128', `${name}: 32 x 128`);
      const alpha = (x, y) => file[18 + (y * w + x) * 4 + 3];
      const outer = side === 'L' ? 0 : w - 1, inner = w - 1 - outer;
      assert.equal(alpha(outer, 0), 0, `${name}: clear in its top corner`);
      assert.equal(alpha(outer, h - 1), 0, `${name}: and its bottom corner`);
      for (let y = 0; y < h; y++) assert.equal(alpha(inner, y), 255, `${name}: the inner side solid (row ${y})`);
      const arc = h * radius[size] / height[size];
      for (let y = Math.ceil(arc); y < h - Math.ceil(arc); y++) {
        for (let x = 0; x < w; x++) assert.equal(alpha(x, y), 255, `${name}: solid between the arcs (${x}, ${y})`);
      }
      // Every pixel against the arcs worked out here, in the bar's units (r wide, the size's height tall): one inside by
      // more than half its diagonal (with a little to spare) is solid, one as far outside is clear.
      const r = radius[size], tall = height[size];
      const margin = .6 * Math.hypot(r / w, tall / h);
      let tested = 0;
      for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
          const u = (x + .5) / w * r, v = (y + .5) / h * tall;
          const from = side === 'L' ? u : r - u, down = Math.min(v, tall - v);
          const d = down >= r ? -Infinity : Math.hypot(from - r, down - r) - r;
          if (d > -Infinity && Math.abs(d) > margin) tested++;
          if (d < -margin) assert.equal(alpha(x, y), 255, `${name}: (${x}, ${y}) inside the arc, solid`);
          if (d > margin) assert.equal(alpha(x, y), 0, `${name}: (${x}, ${y}) outside the arc, clear`);
        }
      }
      assert.ok(tested > 500, `${name}: the arcs' pixels checked (${tested})`);
    }
  }
  const png = await readFile(new URL('Tools/CurseForgeAvatar.png', root));
  assert.equal(png.readUInt32BE(16) + 'x' + png.readUInt32BE(20), '400x400', 'the CurseForge avatar is 400 x 400');
});
