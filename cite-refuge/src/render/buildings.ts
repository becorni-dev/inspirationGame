// Les bâtiments dessinés en 2.5D (façade, côté, toit) en attendant les images de l'atelier.
// Chaque bâtiment donne aussi ses fenêtres et ses feux, allumés la nuit par la couche de lumière.
import { Container, Graphics, Sprite, Texture } from "pixi.js";
import type { Slot } from "../engine/city";
import { hash01 } from "../engine/rng";
import { shade } from "./util";

export interface LightSpot {
  x: number;
  y: number;
  size: number;
  color: number;
  flicker: boolean;
  window?: boolean; // fenêtre : allumée seulement la nuit, au hasard
}

export interface BuildingView {
  root: Container;
  snow: Graphics;
  crops?: Graphics; // cultures, teintées selon la saison par la scène
  lights: LightSpot[];
  smoke: { x: number; y: number }[];
  topY: number;
}

const DEPTH_X = 12;
const DEPTH_Y = -8;
const PLASTER = [0xd8c9a8, 0xcbb894, 0xe0d4b8, 0xbfae8e];
const ROOFS = [0x4a3a34, 0x5a4636, 0x3f3a3c, 0x6b4a32];

// Boîte vue de face avec son côté droit et son dessus
function box(g: Graphics, x: number, ground: number, w: number, h: number, color: number, top = true): void {
  g.rect(x, ground - h, w, h).fill(color);
  g.poly([x + w, ground, x + w + DEPTH_X, ground + DEPTH_Y, x + w + DEPTH_X, ground - h + DEPTH_Y, x + w, ground - h]).fill(shade(color, -0.28));
  if (top) g.poly([x, ground - h, x + w, ground - h, x + w + DEPTH_X, ground - h + DEPTH_Y, x + DEPTH_X, ground - h + DEPTH_Y]).fill(shade(color, 0.12));
}

// Toit à deux pans : pignon de face et pan latéral
function gable(g: Graphics, snow: Graphics, x: number, base: number, w: number, rise: number, color: number): number {
  const over = 5;
  g.poly([x - over, base, x + w / 2, base - rise, x + w + over, base]).fill(color);
  g.poly([x + w / 2, base - rise, x + w + over, base, x + w + over + DEPTH_X, base + DEPTH_Y, x + w / 2 + DEPTH_X, base - rise + DEPTH_Y]).fill(shade(color, -0.25));
  g.moveTo(x - over, base).lineTo(x + w / 2, base - rise).lineTo(x + w + over, base).stroke({ width: 2, color: shade(color, -0.4) });
  snow.poly([x - over, base, x + w / 2, base - rise, x + w + over, base, x + w - 2, base - 3, x + w / 2, base - rise + 5, x + 2, base - 3]).fill(0xf8fafc);
  snow.poly([x + w / 2, base - rise, x + w + over, base, x + w + over + DEPTH_X, base + DEPTH_Y, x + w / 2 + DEPTH_X, base - rise + DEPTH_Y]).fill({ color: 0xeef2f6, alpha: 0.9 });
  return base - rise;
}

function windowAt(g: Graphics, lights: LightSpot[], x: number, y: number, w: number, h: number, frame: number): void {
  g.rect(x - 1.5, y - 1.5, w + 3, h + 3).fill(frame);
  g.rect(x, y, w, h).fill(0x1d2430);
  g.rect(x + w / 2 - 0.5, y, 1, h).fill(frame);
  lights.push({ x: x + w / 2, y: y + h / 2, size: 34, color: 0xffb35a, flicker: false, window: true });
}

export function drawBuilding(type: string, slot: Slot, seed: number, image: Texture | null): BuildingView {
  const root = new Container();
  const g = new Graphics();
  const snow = new Graphics();
  const lights: LightSpot[] = [];
  const smoke: { x: number; y: number }[] = [];
  const r = (k: number) => hash01(seed * 97 + k);
  const ground = slot.y;
  const cx = slot.x - DEPTH_X / 2;
  let topY = ground - 60;

  if (image) {
    // Image de l'atelier : posée au sol, à la largeur de l'emplacement
    const s = new Sprite(image);
    s.anchor.set(0.5, 1);
    s.width = slot.width * 0.95;
    s.scale.y = s.scale.x;
    s.position.set(slot.x, ground + 2);
    root.addChild(s, snow);
    return { root, snow, lights, smoke, topY: ground - s.height };
  }

  let crops: Graphics | undefined;
  switch (type) {
    case "ferme": {
      // Champ en planches, petite grange et meule de foin
      const w = slot.width * 0.92;
      const x = slot.x - w / 2;
      crops = new Graphics();
      crops.poly([x, ground - 1, x + w * 0.66, ground - 1, x + w * 0.66 + 10, ground - 16, x + 10, ground - 16]).fill(0xffffff);
      for (let k = 0; k < 7; k++) {
        const fx = x + 3 + k * (w * 0.66 - 6) / 6;
        crops.moveTo(fx, ground - 2).lineTo(fx + 9, ground - 15);
      }
      crops.stroke({ width: 1.5, color: 0xb0b0b0 });
      snow.poly([x, ground - 1, x + w * 0.66, ground - 1, x + w * 0.66 + 10, ground - 16, x + 10, ground - 16]).fill({ color: 0xf6f8fc, alpha: 0.95 });
      const bx = x + w * 0.7;
      const bw = w * 0.28;
      box(g, bx, ground, bw, 20, 0x6e4a2e, false);
      for (let k = 3; k < bw; k += 5) g.rect(bx + k, ground - 20, 1.2, 20).fill(0x55381f);
      g.rect(bx + bw / 2 - 4, ground - 12, 8, 12).fill(0x3a2616);
      windowAt(g, lights, bx + 3, ground - 17, 5, 5, 0x55381f);
      topY = gable(g, snow, bx, ground - 20, bw, 14, 0x5a3e2c);
      // Épouvantail
      const sx = x + w * 0.35;
      g.rect(sx - 0.8, ground - 30, 1.6, 22).fill(0x4a3424);
      g.rect(sx - 7, ground - 25, 14, 1.6).fill(0x4a3424);
      g.circle(sx, ground - 31, 2.6).fill(0xc9a650);
      g.poly([sx - 4, ground - 32, sx + 4, ground - 32, sx, ground - 37]).fill(0x3a2a20);
      root.addChild(crops);
      break;
    }
    case "bucheron": {
      // Cabane de rondins, bûches empilées, quelques pins à abattre
      for (let k = 0; k < 3; k++) {
        const px = slot.x - slot.width * 0.32 + k * 14 + r(30 + k) * 6;
        const h = 44 + r(40 + k) * 26;
        g.rect(px - 2, ground - 8, 4, 8).fill(0x3a2a1e);
        g.poly([px - h * 0.3, ground - 6, px + h * 0.3, ground - 6, px, ground - h]).fill(shade(0x2f4a35, -r(50 + k) * 0.3));
        snow.poly([px - h * 0.16, ground - h * 0.55, px + h * 0.16, ground - h * 0.55, px, ground - h]).fill(0xf6f8fc);
      }
      const w = slot.width * 0.42;
      const x = slot.x - w / 2 + 8;
      box(g, x, ground, w, 22, 0x6a4a30, false);
      for (let y = ground - 4; y > ground - 22; y -= 4.5) g.rect(x, y, w, 1.2).fill(0x4a3220);
      g.rect(x + w / 2 - 4, ground - 14, 8, 14).fill(0x2f1f12);
      windowAt(g, lights, x + w - 10, ground - 17, 6, 6, 0x4a3220);
      topY = gable(g, snow, x, ground - 22, w, 16, 0x4a3a30);
      g.rect(x + 4, ground - 36, 6, 12).fill(0x6b5d52);
      smoke.push({ x: x + 7, y: ground - 37 });
      // Bûches
      const lx = x + w + 10;
      for (let row = 0; row < 3; row++) for (let k = 0; k < 3 - row; k++) {
        const cx2 = lx + k * 7 + row * 3.5;
        const cy2 = ground - 3.5 - row * 6.5;
        g.circle(cx2, cy2, 3.4).fill(0x8a6a44);
        g.circle(cx2, cy2, 1.6).fill(0xb89464);
      }
      // Souche et hache
      g.rect(x - 14, ground - 7, 9, 7).fill(0x6a4a30);
      g.rect(x - 9, ground - 15, 1.4, 9).fill(0x4a3424);
      g.rect(x - 11, ground - 15, 5, 3).fill(0x9aa0a6);
      break;
    }
    case "maison": {
      const inside = slot.zone === "galeries";
      const w = slot.width * (0.55 + r(1) * 0.15);
      const h = inside ? 54 : 46 + Math.floor(r(2) * 2) * 26;
      const x = cx - w / 2;
      if (inside) {
        // Maison naine taillée dans la roche : façade de pierre, porte ronde
        box(g, x, ground, w, h, 0x7a6d5e, false);
        g.roundRect(x + w / 2 - 9, ground - 30, 18, 30, 9).fill(0x5b3a20);
        g.circle(x + w / 2 + 4, ground - 14, 1.5).fill(0xd9b26a);
        windowAt(g, lights, x + 7, ground - 42, 10, 12, 0x4a3f34);
        windowAt(g, lights, x + w - 17, ground - 42, 10, 12, 0x4a3f34);
        g.rect(x - 4, ground - h - 6, w + 8, 8).fill(0x5d5246);
        topY = ground - h - 6;
        smoke.push({ x: x + w - 6, y: ground - h - 6 });
      } else {
        const wall = PLASTER.at(Math.floor(r(3) * PLASTER.length)) ?? PLASTER[0];
        const roof = ROOFS.at(Math.floor(r(4) * ROOFS.length)) ?? ROOFS[0];
        box(g, x, ground, w, h, wall, false);
        // Colombages
        const beam = 0x4a3324;
        g.rect(x, ground - h, w, 3).fill(beam);
        g.rect(x, ground - 3, w, 3).fill(beam);
        g.rect(x, ground - h, 3, h).fill(beam);
        g.rect(x + w - 3, ground - h, 3, h).fill(beam);
        if (h > 50) g.rect(x, ground - h / 2, w, 3).fill(beam);
        g.moveTo(x + 3, ground - 3).lineTo(x + w / 2, ground - h / 2).lineTo(x + w - 3, ground - 3).stroke({ width: 2.5, color: beam });
        g.rect(x + w / 2 - 7, ground - 24, 14, 24).fill(0x3a2616);
        const floors = h > 50 ? 2 : 1;
        for (let f = 0; f < floors; f++) {
          const wy = ground - h + 10 + f * (h / 2);
          windowAt(g, lights, x + 7, wy, 9, 11, beam);
          windowAt(g, lights, x + w - 16, wy, 9, 11, beam);
        }
        const peak = gable(g, snow, x, ground - h, w, 22 + r(5) * 14, roof);
        // Cheminée
        const chx = x + w * 0.72;
        g.rect(chx, ground - h - 22, 8, 18).fill(0x6b5d52);
        snow.rect(chx - 1, ground - h - 25, 10, 4).fill(0xffffff);
        smoke.push({ x: chx + 4, y: ground - h - 24 });
        topY = peak;
      }
      break;
    }
    case "grenier": {
      const w = slot.width * 0.82;
      const h = 44;
      const x = cx - w / 2;
      box(g, x, ground, w, h, 0x7a5434, false);
      for (let k = 0; k < w; k += 7) g.rect(x + k, ground - h, 1.5, h).fill(0x5a3c24);
      g.rect(x + w / 2 - 15, ground - 34, 30, 34).fill(0x4a301c);
      g.moveTo(x + w / 2 - 15, ground - 34).lineTo(x + w / 2 + 15, ground).moveTo(x + w / 2 + 15, ground - 34).lineTo(x + w / 2 - 15, ground).stroke({ width: 2, color: 0x7a5434 });
      // Bottes de foin
      g.roundRect(x - 12, ground - 12, 14, 12, 3).fill(0xc9a650);
      g.roundRect(x - 4, ground - 22, 14, 11, 3).fill(0xd6b45a);
      windowAt(g, lights, x + w / 2 - 6, ground - h - 2, 12, 10, 0x5a3c24);
      topY = gable(g, snow, x, ground - h, w, 34, 0x5a4a3a);
      break;
    }
    case "phare": {
      const w = 30;
      const h = slot.zone === "terrasses" ? 120 : 150;
      const x = cx - w / 2;
      box(g, x, ground, w, h, 0x8a857c);
      for (let y = ground - 14; y > ground - h; y -= 14) g.moveTo(x, y).lineTo(x + w, y);
      g.stroke({ width: 1, color: 0x5f5b54, alpha: 0.6 });
      g.roundRect(x + w / 2 - 5, ground - 22, 10, 22, 5).fill(0x3a2616);
      windowAt(g, lights, x + w / 2 - 3, ground - h * 0.55, 6, 10, 0x5f5b54);
      // Couronne et brasier
      g.rect(x - 6, ground - h - 6, w + 12, 8).fill(0x77736c);
      for (let k = 0; k < 4; k++) g.rect(x - 6 + k * 11, ground - h - 16, 7, 10).fill(0x77736c);
      g.poly([x + 4, ground - h - 6, x + w - 4, ground - h - 6, x + w / 2 + 6, ground - h - 18, x + w / 2 - 6, ground - h - 18]).fill(0x3a2f26);
      g.poly([x + w / 2 - 8, ground - h - 18, x + w / 2, ground - h - 40, x + w / 2 + 8, ground - h - 18]).fill(0xffa23a);
      g.poly([x + w / 2 - 4, ground - h - 18, x + w / 2, ground - h - 30, x + w / 2 + 4, ground - h - 18]).fill(0xfff0b0);
      snow.rect(x - 6, ground - h - 9, w + 12, 4).fill(0xffffff);
      lights.push({ x: x + w / 2, y: ground - h - 26, size: 420, color: 0xff9a3a, flicker: true });
      topY = ground - h - 40;
      break;
    }
    case "hall": {
      const w = slot.width * 0.95;
      const h = 70;
      const x = cx - w / 2;
      box(g, x, ground, w, h, 0x8b7d68, false);
      for (let y = ground - 12; y > ground - h; y -= 12) g.moveTo(x, y).lineTo(x + w, y);
      g.stroke({ width: 1, color: 0x5e5446, alpha: 0.5 });
      g.roundRect(x + w / 2 - 12, ground - 40, 24, 40, 12).fill(0x3a2616);
      // Bannières des cinq peuples
      const banners = [0x7a1f22, 0x2f5a3a, 0x3a4f7a, 0x6b5a2a, 0x4a3a5a];
      banners.forEach((c, k) => {
        const bx = x + 6 + k * ((w - 20) / 5);
        if (Math.abs(bx + 5 - (x + w / 2)) < 16) return;
        g.rect(bx, ground - h + 8, 9, 26).fill(c);
        g.poly([bx, ground - h + 34, bx + 9, ground - h + 34, bx + 4.5, ground - h + 28]).fill(shade(c, -0.3));
      });
      windowAt(g, lights, x + w / 2 - 6, ground - h + 10, 12, 16, 0x5e5446);
      topY = gable(g, snow, x, ground - h, w, 44, 0x3f3634);
      g.rect(x + w / 2 - 1, topY - 18, 2, 18).fill(0x2a2a2a);
      g.poly([x + w / 2 + 1, topY - 18, x + w / 2 + 14, topY - 14, x + w / 2 + 1, topY - 10]).fill(0x7a1f22);
      topY -= 18;
      break;
    }
    case "serre": {
      const w = slot.width * 0.8;
      const h = 34;
      const x = cx - w / 2;
      g.rect(x, ground - h, w, h).fill({ color: 0xbfe3d0, alpha: 0.35 });
      g.poly([x, ground - h, x + w / 2, ground - h - 22, x + w, ground - h]).fill({ color: 0xd2f0e0, alpha: 0.4 });
      // Plantes
      for (let k = 0; k < 6; k++) {
        const px = x + 6 + k * ((w - 12) / 5);
        g.ellipse(px, ground - 8, 6, 9 + r(10 + k) * 6).fill(shade(0x4a8a52, r(20 + k) * 0.3));
      }
      for (let k = 0; k <= 4; k++) g.rect(x + (k * w) / 4 - 1, ground - h, 2, h).fill(0xd8d2c0);
      g.rect(x, ground - h, w, 2).fill(0xd8d2c0);
      g.moveTo(x, ground - h).lineTo(x + w / 2, ground - h - 22).lineTo(x + w, ground - h).stroke({ width: 2, color: 0xd8d2c0 });
      snow.poly([x, ground - h, x + w / 2, ground - h - 22, x + w, ground - h, x + w / 2, ground - h - 17]).fill({ color: 0xffffff, alpha: 0.8 });
      lights.push({ x: x + w / 2, y: ground - 18, size: 110, color: 0x7dffb0, flicker: false });
      topY = ground - h - 22;
      break;
    }
    case "forge": {
      const w = slot.width * 0.85;
      const h = 70;
      const x = cx - w / 2;
      box(g, x, ground, w, h - 16, 0x5a4a3e, false);
      for (let y = ground - 12; y > ground - h + 16; y -= 12) g.moveTo(x, y).lineTo(x + w, y);
      g.stroke({ width: 1, color: 0x3a2f26, alpha: 0.6 });
      // Foyer embrasé
      g.roundRect(x + w * 0.2, ground - 34, w * 0.4, 30, 14).fill(0x1a0e08);
      g.roundRect(x + w * 0.24, ground - 26, w * 0.32, 22, 10).fill(0xff7a1a);
      g.roundRect(x + w * 0.3, ground - 18, w * 0.2, 14, 6).fill(0xffd27a);
      // Hotte et conduit dans la roche
      g.poly([x + w * 0.15, ground - h + 16, x + w * 0.65, ground - h + 16, x + w * 0.5, ground - h - 6, x + w * 0.3, ground - h - 6]).fill(0x4a3d32);
      g.rect(x + w * 0.34, ground - h - 40, w * 0.12, 36).fill(0x3e332a);
      // Enclume
      g.rect(x + w * 0.72, ground - 12, 16, 5).fill(0x2f3236);
      g.rect(x + w * 0.76, ground - 7, 8, 7).fill(0x2f3236);
      lights.push({ x: x + w * 0.4, y: ground - 18, size: 260, color: 0xff6a1a, flicker: true });
      topY = ground - h;
      break;
    }
  }
  root.addChild(g, snow);
  return { root, snow, crops, lights, smoke, topY };
}
