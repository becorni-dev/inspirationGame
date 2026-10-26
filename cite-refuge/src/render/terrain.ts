// Le décor fixe en coupe : sous-sol en strates, montagne et terrasses, galeries, remparts, champs, arbres.
// Les parties qui changent avec la saison sont dessinées en blanc puis teintées (tint).
import { Container, Graphics } from "pixi.js";
import { hash01 } from "../engine/rng";
import { shade } from "./util";

export const WORLD_W = 3200;
export const WORLD_H = 1600;
export const GROUND = 1050;

// Contour de la montagne (au-dessus du sol), avec les trois corniches des terrasses
export const MOUNTAIN = [
  1440, GROUND, 1550, 1000, 1580, 900, 1585, 840, 1810, 840, 1822, 760, 1832, 650, 2060, 650, 2070, 560, 2082, 470,
  2260, 470, 2300, 400, 2380, 300, 2460, 205, 2530, 140, 2585, 170, 2660, 235, 2760, 300, 2880, 365, 3000, 420, 3200, 470,
  3200, GROUND,
];

export const GALLERIES = [
  { x0: 1440, x1: 2300, y0: 1150, y1: 1260 },
  { x0: 1660, x1: 2640, y0: 1320, y1: 1430 },
];

export interface Terrain {
  root: Container;
  grass: Graphics; // teinté par la saison
  foliage: Graphics;
  snow: Graphics; // alpha = neige
  peakSnow: Graphics;
  lightSpots: { x: number; y: number; size: number; color: number; flicker: boolean }[];
}

function stoneLines(g: Graphics, x0: number, y0: number, w: number, h: number, color: number, seed: number): void {
  for (let row = 0; row * 14 < h; row++) {
    const y = y0 + row * 14;
    g.moveTo(x0, y).lineTo(x0 + w, y);
    for (let x = x0 + ((row % 2) * 11 + hash01(seed + row) * 6); x < x0 + w; x += 22) {
      g.moveTo(x, y).lineTo(x, Math.min(y + 14, y0 + h));
    }
  }
  g.stroke({ width: 1, color, alpha: 0.5 });
}

export function buildTerrain(): Terrain {
  const root = new Container();
  const lightSpots: Terrain["lightSpots"] = [];

  // --- Sous-sol en strates ---
  const under = new Graphics();
  const strata = [0x4b3a2b, 0x3f3226, 0x352b22, 0x2c251f, 0x241f1b, 0x1d1916];
  for (let i = 0; i < strata.length; i++) {
    const top = GROUND + i * 95;
    const pts: number[] = [];
    for (let x = 0; x <= WORLD_W; x += 80) pts.push(x, top + (i === 0 ? 0 : Math.sin(x * 0.004 + i * 1.7) * 14 + Math.sin(x * 0.013 + i) * 5));
    pts.push(WORLD_W, WORLD_H, 0, WORLD_H);
    under.poly(pts).fill(strata.at(i) ?? 0x1d1916);
  }
  // Cailloux et racines
  for (let i = 0; i < 260; i++) {
    const x = hash01(i * 3) * WORLD_W;
    const y = GROUND + 20 + hash01(i * 7 + 1) * (WORLD_H - GROUND - 20);
    const r = 3 + hash01(i * 11) * 9;
    under.ellipse(x, y, r * 1.6, r).fill({ color: shade(0x4b3a2b, -0.1 - hash01(i) * 0.3), alpha: 0.7 });
  }
  for (let i = 0; i < 40; i++) {
    const x = hash01(i * 13 + 5) * 1400;
    under.moveTo(x, GROUND + 6).bezierCurveTo(x + 8, GROUND + 25, x - 10, GROUND + 40, x + 4, GROUND + 60 + hash01(i) * 30);
  }
  under.stroke({ width: 1.5, color: 0x2a1f16, alpha: 0.6 });
  root.addChild(under);

  // --- Galeries creusées ---
  const gal = new Graphics();
  for (const c of GALLERIES) {
    gal.roundRect(c.x0, c.y0, c.x1 - c.x0, c.y1 - c.y0 + 6, 36).fill(0x16100c);
    gal.roundRect(c.x0 + 6, c.y0 + 6, c.x1 - c.x0 - 12, c.y1 - c.y0 - 6, 30).fill(0x21170f);
    // Voûtes et piliers taillés
    for (let x = c.x0 + 70; x < c.x1 - 40; x += 130) {
      gal.rect(x - 7, c.y0 + 18, 14, c.y1 - c.y0 - 18).fill(0x2e2219);
      gal.rect(x - 10, c.y0 + 14, 20, 8).fill(0x3a2b1f);
    }
    gal.rect(c.x0 + 6, c.y1 - 4, c.x1 - c.x0 - 12, 10).fill(0x4a3828);
    stoneLines(gal, c.x0 + 10, c.y1 - 4, c.x1 - c.x0 - 20, 10, 0x2a1d14, c.x0);
    // Lanternes accrochées aux voûtes
    for (let x = c.x0 + 135; x < c.x1 - 40; x += 260) {
      gal.moveTo(x, c.y0 + 10).lineTo(x, c.y0 + 34).stroke({ width: 1, color: 0x6b5a44 });
      gal.rect(x - 4, c.y0 + 34, 8, 10).fill(0xffc070);
      lightSpots.push({ x, y: c.y0 + 40, size: 120, color: 0xffa64d, flicker: true });
    }
  }
  // Puits d'escalier : de la cité vers la première galerie, puis vers la seconde
  gal.rect(1440, GROUND, 46, 1160 - GROUND).fill(0x1c140e);
  gal.rect(2250, 1255, 46, 1330 - 1255).fill(0x1c140e);
  for (let y = GROUND + 8; y < 1160; y += 14) gal.moveTo(1446, y).lineTo(1480, y + 6);
  for (let y = 1262; y < 1330; y += 14) gal.moveTo(2256, y).lineTo(2290, y + 6);
  gal.stroke({ width: 2, color: 0x5a4532 });
  // Monte-charge
  gal.moveTo(2600, 470).lineTo(2600, 1320).stroke({ width: 1.5, color: 0x8a7458, alpha: 0.4 });
  root.addChild(gal);

  // --- La montagne (Mont Hautbourg) ---
  const mountain = new Graphics();
  mountain.poly(MOUNTAIN).fill(0x5b6068);
  // Ombrage : face droite plus sombre, arêtes
  const ridge = [2530, 140, 2585, 170, 2660, 235, 2760, 300, 2880, 365, 3000, 420, 3200, 470, 3200, GROUND, 2600, GROUND, 2560, 600];
  mountain.poly(ridge).fill({ color: 0x3e434b, alpha: 0.55 });
  // Pans de roche : facettes claires et sombres pour casser l'aplat
  const tones = [0x6b7079, 0x4d525a, 0x737068, 0x464b53];
  for (let i = 0; i < 70; i++) {
    const x = 1550 + hash01(i * 7 + 1) * 1650;
    const y = 220 + hash01(i * 11 + 3) * 800;
    if (!insideMountain(x, y) || !insideMountain(x + 60, y + 50)) continue;
    const w = 40 + hash01(i * 13) * 120;
    const h = 30 + hash01(i * 17) * 90;
    const t = tones[Math.floor(hash01(i * 19) * tones.length)];
    mountain.poly([x, y, x + w * 0.6, y - h * 0.15, x + w, y + h * 0.4, x + w * 0.7, y + h, x + w * 0.1, y + h * 0.8])
      .fill({ color: t, alpha: 0.25 });
  }
  // Fissures courtes, en zigzag et d'angles variés
  for (let i = 0; i < 45; i++) {
    let x = 1600 + hash01(i * 5) * 1550;
    let y = 260 + hash01(i * 9) * 740;
    if (!insideMountain(x, y)) continue;
    mountain.moveTo(x, y);
    const dir = (hash01(i * 23) - 0.5) * 1.6;
    for (let k = 0; k < 3; k++) {
      x += Math.sin(dir + (hash01(i * 31 + k) - 0.5) * 1.4) * 9;
      y += 6 + hash01(i * 37 + k) * 10;
      mountain.lineTo(x, y);
    }
  }
  mountain.stroke({ width: 1.2, color: 0x2f333a, alpha: 0.3 });
  // Corniches des terrasses : dalle de pierre et parapet
  const ledges = [
    { x0: 1585, x1: 1810, y: 840 },
    { x0: 1832, x1: 2060, y: 650 },
    { x0: 2082, x1: 2260, y: 470 },
  ];
  for (const l of ledges) {
    mountain.rect(l.x0, l.y, l.x1 - l.x0, 16).fill(0x7a7670);
    mountain.poly([l.x0, l.y, l.x1, l.y, l.x1 + 10, l.y - 8, l.x0 + 10, l.y - 8]).fill(0x8f8a82);
    stoneLines(mountain, l.x0, l.y, l.x1 - l.x0, 16, 0x4c4842, l.y);
    // Parapet de bois
    for (let x = l.x0 + 4; x < l.x1; x += 16) mountain.rect(x, l.y - 18, 2, 18).fill(0x5a4330);
    mountain.rect(l.x0, l.y - 18, l.x1 - l.x0, 2).fill(0x6b5038);
  }
  // Escaliers taillés entre la cité et les terrasses
  const stairs = [
    [1560, 1000, 1590, 840],
    [1812, 840, 1836, 650],
    [2062, 650, 2085, 470],
  ];
  for (const [x0, y0, x1, y1] of stairs) {
    for (let k = 0; k <= 10; k++) {
      const t = k / 10;
      const x = x0 + (x1 - x0) * t;
      const y = y0 + (y1 - y0) * t;
      mountain.rect(x - 8, y, 16, 3).fill(0x8a857c);
    }
  }
  root.addChild(mountain);

  const peakSnow = new Graphics();
  peakSnow.poly([2380, 300, 2460, 205, 2530, 140, 2585, 170, 2660, 235, 2700, 262, 2640, 280, 2590, 250, 2540, 290, 2480, 270, 2420, 320]).fill(0xf4f6fa);
  root.addChild(peakSnow);

  // --- Herbe de la plaine et du plateau (teintée selon la saison) ---
  const grass = new Graphics();
  const grassPts: number[] = [];
  for (let x = 0; x <= 1450; x += 30) grassPts.push(x, GROUND - 2 - (x < 640 ? Math.sin(x * 0.01) * 3 : 0));
  grassPts.push(1450, GROUND + 16);
  for (let x = 1450; x >= 0; x -= 30) grassPts.push(x, GROUND + 12 + Math.sin(x * 0.05) * 3);
  grass.poly(grassPts).fill(0xffffff);
  for (let i = 0; i < 400; i++) {
    const x = hash01(i * 17) * 1440;
    const h = 4 + hash01(i * 3 + 2) * 7;
    grass.moveTo(x, GROUND).lineTo(x + (hash01(i) - 0.5) * 4, GROUND - h);
  }
  grass.stroke({ width: 1.5, color: 0xdddddd });
  root.addChild(grass);

  // --- Remparts et porte, face à la plaine ---
  const wall = new Graphics();
  wall.rect(690, 905, 70, GROUND - 905).fill(0x77736c);
  wall.poly([760, 905, 774, 895, 774, GROUND - 6, 760, GROUND]).fill(0x5d5a54);
  for (let k = 0; k < 4; k++) wall.rect(690 + k * 18, 891, 12, 14).fill(0x77736c);
  wall.rect(655, 860, 50, GROUND - 860).fill(0x6e6a63);
  for (let k = 0; k < 3; k++) wall.rect(655 + k * 18, 846, 12, 14).fill(0x6e6a63);
  stoneLines(wall, 655, 860, 50, GROUND - 860, 0x45423d, 3);
  stoneLines(wall, 705, 905, 55, GROUND - 905, 0x45423d, 9);
  wall.roundRect(708, 985, 34, 65, 16).fill(0x2a1d14);
  wall.rect(712, 992, 26, 58).fill(0x5a3e26);
  for (let k = 0; k < 4; k++) wall.rect(714 + k * 6.5, 992, 1.5, 58).fill(0x3a2716);
  // Bannière sur la tour
  wall.rect(676, 874, 10, 34).fill(0x7a1f22);
  wall.poly([676, 908, 686, 908, 681, 900]).fill(0x5a1416);
  // Braseros sur le chemin de ronde
  for (const x of [663, 697]) {
    wall.rect(x - 4, 840, 8, 6).fill(0x3a2f26);
    lightSpots.push({ x, y: 836, size: 140, color: 0xff8a2a, flicker: true });
  }
  root.addChild(wall);

  // --- Arbres : plaine (feuillus) et flancs de la montagne (sapins) ---
  const trunks = new Graphics();
  const foliage = new Graphics();
  const pines = new Graphics();
  const treeSpots: { x: number; y: number; r: number }[] = [];
  for (let i = 0; i < 26; i++) {
    const x = 20 + hash01(i * 31 + 7) * 620;
    if (x > 80 && x < 660) continue; // la plaine est laissée aux fermes et aux bûcherons
    const r = 14 + hash01(i * 5) * 12;
    const y = GROUND - 4;
    trunks.rect(x - 2.5, y - r * 1.6, 5, r * 1.6).fill(0x4a3424);
    treeSpots.push({ x, y: y - r * 1.7, r });
    foliage.circle(x, y - r * 1.8, r).fill(0xffffff);
    foliage.circle(x - r * 0.6, y - r * 1.4, r * 0.7).fill(0xeeeeee);
    foliage.circle(x + r * 0.6, y - r * 1.45, r * 0.75).fill(0xdddddd);
  }
  for (let i = 0; i < 70; i++) {
    const x = 2560 + hash01(i * 19 + 3) * 630;
    const t = (x - 2530) / (3200 - 2530);
    const surface = 140 + t * 330;
    const y = surface + 40 + hash01(i * 23) * (GROUND - surface - 60);
    const h = 26 + hash01(i * 7) * 22;
    pines.rect(x - 2, y - 6, 4, 8).fill(0x3a2a1e);
    pines.poly([x - h * 0.32, y - 4, x + h * 0.32, y - 4, x, y - h]).fill(shade(0x2f4a35, -hash01(i) * 0.3));
    treeSpots.push({ x, y: y - h * 0.8, r: h * 0.22 });
  }
  root.addChild(trunks, foliage, pines);

  // --- Neige : au sol, sur les corniches, sur la montagne et les arbres ---
  const snow = new Graphics();
  const snowPts: number[] = [];
  for (let x = 0; x <= 1450; x += 30) snowPts.push(x, GROUND - 6 - Math.sin(x * 0.03) * 2);
  snowPts.push(1450, GROUND + 4, 0, GROUND + 4);
  snow.poly(snowPts).fill(0xf6f8fc);
  for (const l of ledges) snow.poly([l.x0, l.y + 2, l.x1, l.y + 2, l.x1 + 10, l.y - 10, l.x0 + 10, l.y - 10]).fill(0xf6f8fc);
  snow.poly([1690, 760, 1830, 640, 2080, 470, 2290, 400, 2460, 205, 2530, 140, 2585, 170, 2760, 300, 3000, 420, 3200, 470, 3200, 560, 2900, 480, 2700, 420, 2520, 330, 2350, 470, 2150, 560, 1950, 700]).fill({ color: 0xf2f4f8, alpha: 0.75 });
  for (const s of treeSpots) snow.ellipse(s.x, s.y - s.r * 0.4, s.r * 0.9, s.r * 0.35).fill(0xffffff);
  snow.rect(690, 899, 70, 6).fill(0xffffff);
  snow.rect(655, 854, 50, 6).fill(0xffffff);
  root.addChild(snow);

  return { root, grass, foliage, snow, peakSnow, lightSpots };
}

// Chaînes lointaines, dessinées pour un plan qui défile plus lentement (parallaxe)
export function buildRange(seed: number, baseY: number, amp: number, color: number): Graphics {
  const g = new Graphics();
  const pts: number[] = [-800, WORLD_H];
  for (let x = -800; x <= WORLD_W + 800; x += 60) {
    const n = Math.sin(x * 0.0021 + seed) * 0.5 + Math.sin(x * 0.0057 + seed * 2.1) * 0.3 + Math.sin(x * 0.013 + seed * 3.3) * 0.2;
    pts.push(x, baseY - Math.abs(n) * amp - amp * 0.2);
  }
  pts.push(WORLD_W + 800, WORLD_H);
  g.poly(pts).fill(color);
  return g;
}

// Le point est-il dans la silhouette de la montagne ? (test pair-impair)
function insideMountain(x: number, y: number): boolean {
  let inside = false;
  for (let i = 0, j = MOUNTAIN.length - 2; i < MOUNTAIN.length; j = i, i += 2) {
    const xi = MOUNTAIN[i], yi = MOUNTAIN[i + 1], xj = MOUNTAIN[j], yj = MOUNTAIN[j + 1];
    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}
