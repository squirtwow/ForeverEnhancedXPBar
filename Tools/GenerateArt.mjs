// The addon's art, drawn from scratch: the logo (a thick rising chevron over a segmented XP bar, the last segment the
// darker purple of the part still to earn) for the CurseForge avatar, the window header, the AddOns list icon and the
// minimap button; the amber stripes for the XP waiting in finished quests (when stripes are chosen); the end-cap masks
// that round the bar's corners (a left and a right one per size); and the heart for the credit line.
// A tiny rasteriser: rounded rectangles and stroked segments with round caps, painted in order, 4 x 4 samples a pixel.
// TGA files are uncompressed 32-bit with a top-left origin; the PNG uses node:zlib and its own CRC32.
// Run from the addon's folder with: node Tools/GenerateArt.mjs
import { writeFileSync } from 'node:fs';
import { deflateSync } from 'node:zlib';

const hex = h => [parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255, 1];
const DARK = hex('#111015'), PURPLE = hex('#b07df0'), SECOND = hex('#5b4386');
const AMBER = hex('#ffa500'), AMBER_DARK = hex('#cc8400'); // the bar's solid amber, and a darker one for the stripes
const WHITE = [1, 1, 1, 1], CLEAR = [0, 0, 0, 0];

// Shapes: each has inside(x, y) in its own units and a colour. -------------------------------------------------------------
function segDist(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay, L = dx * dx + dy * dy;
  const t = L > 0 ? Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / L)) : 0;
  return Math.hypot(px - (ax + dx * t), py - (ay + dy * t));
}
const stroke = (a, b, w, colour) => ({ colour, inside: (x, y) => segDist(x, y, a[0], a[1], b[0], b[1]) <= w / 2 });
// Signed distance to a rounded rectangle (negative inside).
function roundedSd(x, y, x0, y0, w, h, r) {
  const cx = x0 + w / 2, cy = y0 + h / 2;
  const qx = Math.abs(x - cx) - (w / 2 - r), qy = Math.abs(y - cy) - (h / 2 - r);
  return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
}
const rounded = (x0, y0, w, h, r, colour, grow = 0) => ({ colour, inside: (x, y) => roundedSd(x, y, x0, y0, w, h, r) <= grow });
const roundedBand = (x0, y0, w, h, r, half, colour) => ({ colour, inside: (x, y) => Math.abs(roundedSd(x, y, x0, y0, w, h, r)) <= half });
// A chevron pointing up: two strokes from the arms' ends to the apex.
const chevron = (apex, left, right, w, colour) => [stroke(left, apex, w, colour), stroke(apex, right, w, colour)];

// Drawing ------------------------------------------------------------------------------------------------------------------
// Pixels of width x height over the view box [vx, vy, vw, vh] of the shapes' units. The last shape holding a point wins.
function rasterRect(width, height, shapes, view, ss = 4) {
  const [vx, vy, vw, vh] = view;
  const px = new Float64Array(width * height * 4);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < ss; sy++) {
        for (let sx = 0; sx < ss; sx++) {
          const ux = vx + (x + (sx + .5) / ss) / width * vw, uy = vy + (y + (sy + .5) / ss) / height * vh;
          let c = CLEAR;
          for (const shape of shapes) if (shape.inside(ux, uy)) c = shape.colour;
          r += c[0] * c[3]; g += c[1] * c[3]; b += c[2] * c[3]; a += c[3];
        }
      }
      const at = (y * width + x) * 4;
      if (a > 0) { px[at] = r / a; px[at + 1] = g / a; px[at + 2] = b / a; }
      px[at + 3] = a / (ss * ss);
    }
  }
  return px;
}
// Square art: size x size.
const raster = (size, shapes, view, ss = 4) => rasterRect(size, size, shapes, view, ss);
const byte = v => Math.max(0, Math.min(255, Math.round(v * 255)));

function writeTga(name, width, height, px) {
  const data = Buffer.alloc(18 + width * height * 4);
  data[2] = 2; // uncompressed true colour
  data.writeUInt16LE(width, 12);
  data.writeUInt16LE(height, 14);
  data[16] = 32;
  data[17] = 0x28; // 8 alpha bits, top-left origin
  for (let i = 0; i < width * height; i++) {
    data[18 + i * 4] = byte(px[i * 4 + 2]);
    data[18 + i * 4 + 1] = byte(px[i * 4 + 1]);
    data[18 + i * 4 + 2] = byte(px[i * 4]);
    data[18 + i * 4 + 3] = byte(px[i * 4 + 3]);
  }
  writeFileSync(new URL(`../Media/${name}.tga`, import.meta.url), data);
}

const CRC = new Uint32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
function crc32(buf) { let c = 0xffffffff; for (const v of buf) c = CRC[(c ^ v) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}
function writePng(path, size, px) {
  const raw = Buffer.alloc(size * (size * 4 + 1));
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0;
    for (let x = 0; x < size; x++) for (let k = 0; k < 4; k++) raw[y * (size * 4 + 1) + 1 + x * 4 + k] = byte(px[(y * size + x) * 4 + k]);
  }
  const head = Buffer.alloc(13);
  head.writeUInt32BE(size, 0); head.writeUInt32BE(size, 4); head[8] = 8; head[9] = 6; head[10] = 0; head[11] = 0; head[12] = 0;
  writeFileSync(new URL(path, import.meta.url), Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', head), chunk('IDAT', deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]));
}

// The logo, in its 240 view box --------------------------------------------------------------------------------------------
const square = border => [rounded(9, 9, 222, 222, 46, DARK, border / 2), roundedBand(9, 9, 222, 222, 46, border / 2, PURPLE)];
// Three segments with 8 px gaps across the lower third: two earned, the last still to earn.
const segments3 = [
  rounded(46, 158, 44, 28, 8, PURPLE),
  rounded(98, 158, 44, 28, 8, PURPLE),
  rounded(150, 158, 44, 28, 8, SECOND),
];
const bigChevron = chevron([120, 58], [70, 112], [170, 112], 24, PURPLE);
// Full size: a second, smaller chevron under the first.
const logoFull = [...square(14), ...segments3, ...bigChevron, ...chevron([120, 100], [90, 132], [150, 132], 16, SECOND)];
// 128 px (the window header): one chevron, a little heavier.
const logo128 = [...square(16), ...segments3, ...chevron([120, 56], [68, 114], [172, 114], 28, PURPLE)];
// 32 px and below: one heavy chevron and two segments.
const emblemSmall = [
  rounded(44, 150, 72, 40, 10, PURPLE),
  rounded(124, 150, 72, 40, 10, SECOND),
  ...chevron([120, 50], [60, 114], [180, 114], 34, PURPLE),
];
const logo32 = [...square(20), ...emblemSmall];
const VIEW = [0, 0, 240, 240];

writePng('../Tools/CurseForgeAvatar.png', 400, raster(400, logoFull, VIEW));
writeTga('Logo', 128, 128, raster(128, logo128, VIEW));
writeTga('Icon', 64, 64, raster(64, logo32, VIEW));
writeTga('MinimapIcon', 64, 64, raster(64, emblemSmall, [20, 12, 200, 200]));

// The stripes: 16 x 16, "/" stripes 8 px apart in the two ambers, tiled along the quest part. -------------------------------
{
  const px = new Float64Array(16 * 16 * 4);
  for (let y = 0; y < 16; y++) {
    for (let x = 0; x < 16; x++) {
      const c = (x + y) % 16 < 8 ? AMBER : AMBER_DARK;
      const at = (y * 16 + x) * 4;
      px[at] = c[0]; px[at + 1] = c[1]; px[at + 2] = c[2]; px[at + 3] = 1;
    }
  }
  writeTga('Stripes', 16, 16, px);
}

// The end caps: one mask over each end of a piece of the bar, as wide as the corners' radius and as tall as the piece, so
// a texture needs two (the game allows three at most). Per size, in the bar's own units (radius r, height h, as RADIUS in
// Bar.lua and F.SIZES in Core.lua): white everywhere but outside a quarter circle of radius r at the top and at the
// bottom of the outer end. Drawn 32 x 128 (powers of two, as the game's art has always been), so the arcs are stretched
// in the file and come out round once the cap is r wide and h tall. Past the cap the game treats it as white
// (CLAMPTOWHITE), and its inner side is white anyway, so the rest of the bar is never cut.
const CAPS = { thin: [2, 10], normal: [4, 18], thick: [5, 26], large: [7, 34] };
for (const [size, [r, h]] of Object.entries(CAPS)) {
  // The left cap: the arcs' centres on its inner side, r in from the top and bottom.
  const left = (x, y) => (y >= r && y <= h - r) || Math.hypot(x - r, y - (y < r ? r : h - r)) <= r;
  writeTga(`CapL_${size}`, 32, 128, rasterRect(32, 128, [{ colour: WHITE, inside: left }], [0, 0, r, h]));
  writeTga(`CapR_${size}`, 32, 128, rasterRect(32, 128, [{ colour: WHITE, inside: (x, y) => left(r - x, y) }], [0, 0, r, h]));
}

// Heart: the curve (x^2 + y^2 - 1)^3 = x^2 y^3, for the credit line (white, tinted in game).
writeTga('Heart', 32, 32, raster(32, [{ colour: WHITE, inside: (x, y) => {
  const u = (x - 16) / (32 * .36), v = -(y - 32 * .54) / (32 * .36);
  const k = u * u + v * v - 1; return k * k * k - u * u * v * v * v <= 0;
} }], [0, 0, 32, 32]));
console.log('art written');
