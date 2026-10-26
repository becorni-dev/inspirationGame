// La scène complète : ciel, plans lointains, décor en coupe, bâtiments, habitants, météo, Ombre, nuit.
import { Application, Container, Graphics, Sprite, Texture } from "pixi.js";
import { type CalendarView, daylight, shadowReach, snowCover } from "../engine/calendar";
import { BUILDINGS, type CityState, SLOTS, type Slot } from "../engine/city";
import { hash01, mulberry32 } from "../engine/rng";
import { type BuildingView, type LightSpot, drawBuilding } from "./buildings";
import { seasonPalette, skyColors } from "./palette";
import { GALLERIES, GROUND, WORLD_H, WORLD_W, buildRange, buildTerrain, type Terrain } from "./terrain";
import { blobTexture, clamp01, glowTexture, lerp, mix, paintGradient, shade, smooth } from "./util";

interface Walker {
  g: Graphics;
  x: number;
  y: number;
  min: number;
  max: number;
  speed: number;
  phase: number;
  inside: boolean;
  lantern: Sprite | null;
}

interface Particle {
  s: Sprite;
  vx: number;
  vy: number;
  spin: number;
}

export class Scene {
  app: Application;
  sky = new Sprite();
  skyCanvas = document.createElement("canvas");
  stars = new Graphics();
  moon = new Graphics();
  far: Graphics;
  mid: Graphics;
  world = new Container();
  terrain: Terrain;
  buildingLayer = new Container();
  walkersLayer = new Container();
  smokeLayer = new Container();
  shadowLayer = new Container();
  markerLayer = new Graphics();
  night = new Graphics();
  lightLayer = new Container();
  weatherLayer = new Container();

  views = new Map<string, { key: string; view: BuildingView; born: number; ground: number }>();
  lightSprites: { spot: LightSpot; s: Sprite; seed: number }[] = [];
  walkers: Walker[] = [];
  particles: Particle[] = [];
  smoke: { s: Sprite; life: number; vx: number }[] = [];
  fog: { s: Sprite; base: number; phase: number; row: number }[] = [];
  eyes: { g: Graphics; x: number; y: number; phase: number }[] = [];
  images = new Map<string, Texture>();

  cam = { x: 1550, y: 880, zoom: 0.8 };
  time = 0;
  private lastSkyKey = "";
  private lastLook = "";
  private rng = mulberry32(7);

  constructor(app: Application) {
    this.app = app;
    this.skyCanvas.width = 4;
    this.skyCanvas.height = 256;
    this.sky.texture = Texture.from(this.skyCanvas);
    this.far = buildRange(1.3, 1000, 330, 0xffffff);
    this.mid = buildRange(4.1, 1040, 150, 0xffffff);
    this.terrain = buildTerrain();

    const stage = app.stage;
    stage.addChild(this.sky, this.stars, this.moon, this.far, this.mid, this.world, this.weatherLayer);
    this.world.addChild(this.terrain.root, this.shadowLayer, this.buildingLayer, this.smokeLayer, this.walkersLayer, this.markerLayer, this.night, this.lightLayer);
    this.lightLayer.blendMode = "add";

    // Étoiles (fixes à l'écran)
    for (let i = 0; i < 260; i++) {
      const r = hash01(i * 3 + 1) < 0.08 ? 1.6 : 0.9;
      this.stars.circle(hash01(i * 7) * 2560, hash01(i * 11 + 3) * 900, r).fill({ color: 0xffffff, alpha: 0.4 + hash01(i) * 0.6 });
    }
    this.moon.circle(0, 0, 26).fill(0xe8ecf4);
    this.moon.circle(-8, -6, 5).fill({ color: 0xc8ccd6, alpha: 0.8 });
    this.moon.circle(9, 7, 7).fill({ color: 0xc8ccd6, alpha: 0.6 });

    // Nuit : un voile sombre sur le monde, les lumières par-dessus
    this.night.rect(-1000, -1000, WORLD_W + 2000, WORLD_H + 2000).fill(0x0a0d1c);
    for (const spot of this.terrain.lightSpots) this.addLight(spot);

    this.buildFog();
    this.buildWalkers();
  }

  addLight(spot: LightSpot): Sprite {
    const s = new Sprite(glowTexture());
    s.anchor.set(0.5);
    s.tint = spot.color;
    s.width = s.height = spot.size;
    s.position.set(spot.x, spot.y);
    this.lightLayer.addChild(s);
    this.lightSprites.push({ spot, s, seed: this.lightSprites.length });
    return s;
  }

  // --- L'Ombre : nappes de brume sur la plaine ---
  buildFog(): void {
    for (let i = 0; i < 26; i++) {
      const s = new Sprite(blobTexture());
      s.anchor.set(0.5);
      const row = i % 3;
      s.width = 380 + hash01(i * 5) * 260;
      s.height = 220 + row * 60;
      s.tint = row === 2 ? 0x1a1022 : 0x24182e;
      this.shadowLayer.addChild(s);
      this.fog.push({ s, base: -500 + i * 70, phase: hash01(i) * 6.28, row });
    }
    for (let i = 0; i < 8; i++) {
      const g = new Graphics();
      g.ellipse(-4, 0, 2.4, 1.2).fill(0xd04aff).ellipse(4, 0, 2.4, 1.2).fill(0xd04aff);
      this.shadowLayer.addChild(g);
      this.eyes.push({ g, x: 0, y: GROUND - 40 - hash01(i * 3) * 80, phase: hash01(i * 13) * 20 });
    }
  }

  // --- Habitants ---
  buildWalkers(): void {
    const paths = [
      { y: GROUND, min: 770, max: 1640, n: 14, inside: false },
      { y: 840, min: 1600, max: 1800, n: 3, inside: false },
      { y: 650, min: 1840, max: 2050, n: 3, inside: false },
      { y: GALLERIES[0].y1, min: GALLERIES[0].x0 + 20, max: GALLERIES[0].x1 - 20, n: 7, inside: true },
      { y: GALLERIES[1].y1, min: GALLERIES[1].x0 + 20, max: GALLERIES[1].x1 - 20, n: 7, inside: true },
    ];
    const coats = [0x6b3b2a, 0x3a4a5a, 0x5a5a3a, 0x7a6a5a, 0x4a3a5a, 0x2f4a3a, 0x8a5a3a];
    let k = 0;
    for (const p of paths) {
      for (let i = 0; i < p.n; i++, k++) {
        const g = new Graphics();
        const small = p.inside && hash01(k * 3) < 0.7; // les nains sont plus petits
        const h = small ? 9 : 12;
        const c = coats.at(Math.floor(hash01(k * 7) * coats.length)) ?? 0x6b3b2a;
        g.roundRect(-2.5, -h, 5, h - 2, 2).fill(c);
        g.circle(0, -h - 2.5, 2.6).fill(0xd9b89a);
        if (small) g.poly([-2.5, -h + 1, 2.5, -h + 1, 0, -h + 6]).fill(0x8a6a4a);
        g.rect(-2, -2, 1.6, 2).fill(0x2a2a2a).rect(0.4, -2, 1.6, 2).fill(0x2a2a2a);
        this.walkersLayer.addChild(g);
        const lantern = hash01(k * 17) < 0.35 ? this.addLight({ x: 0, y: 0, size: 60, color: 0xffc070, flicker: true }) : null;
        this.walkers.push({ g, x: lerp(p.min, p.max, hash01(k * 5)), y: p.y, min: p.min, max: p.max, speed: (8 + hash01(k) * 10) * (hash01(k * 9) < 0.5 ? -1 : 1), phase: hash01(k * 2) * 6, inside: p.inside, lantern });
      }
    }
  }

  // --- Bâtiments : on redessine seulement ce qui a changé ---
  syncCity(city: CityState): void {
    for (const [slotId, entry] of this.views) {
      const b = city.buildings[slotId];
      if (!b || entry.key !== `${b.type}:${b.seed}`) {
        this.buildingLayer.removeChild(entry.view.root);
        entry.view.root.destroy({ children: true });
        for (const spot of entry.view.lights) {
          const idx = this.lightSprites.findIndex((l) => l.spot === spot);
          if (idx >= 0) {
            this.lightSprites[idx].s.destroy();
            this.lightSprites.splice(idx, 1);
          }
        }
        this.views.delete(slotId);
      }
    }
    for (const b of Object.values(city.buildings)) {
      if (this.views.has(b.slot)) continue;
      const slot = SLOTS.find((s) => s.id === b.slot);
      if (!slot) continue;
      const view = drawBuilding(b.type, slot, b.seed, this.images.get(`batiment_${b.type}`) ?? null);
      this.buildingLayer.addChild(view.root);
      for (const spot of view.lights) this.addLight(spot);
      view.root.pivot.y = slot.y;
      view.root.y = slot.y;
      this.views.set(b.slot, { key: `${b.type}:${b.seed}`, view, born: b.builtAt < 0 ? -10 : this.time, ground: slot.y });
    }
  }

  // Repères des emplacements libres quand on construit
  showSlots(type: string | null, city: CityState, hover: string | null): void {
    const m = this.markerLayer;
    m.clear();
    if (!type) {
      if (hover) {
        const s = SLOTS.find((x) => x.id === hover);
        if (s && city.buildings[hover]) m.rect(s.x - s.width / 2, s.y - 4, s.width, 4).fill({ color: 0xe8c170, alpha: 0.8 });
      }
      return;
    }
    const def = BUILDINGS[type];
    for (const s of SLOTS) {
      if (city.buildings[s.id]) continue;
      const ok = def.zones.includes(s.zone);
      const on = s.id === hover;
      const color = ok ? 0xe8c170 : 0x8a3a3a;
      const alpha = ok ? (on ? 0.95 : 0.55) : 0.25;
      m.roundRect(s.x - s.width / 2 + 6, s.y - (on ? 70 : 46), s.width - 12, on ? 70 : 46, 4).fill({ color, alpha: alpha * 0.25 });
      m.roundRect(s.x - s.width / 2 + 6, s.y - (on ? 70 : 46), s.width - 12, on ? 70 : 46, 4).stroke({ width: on ? 2 : 1, color, alpha });
    }
  }

  slotAt(screenX: number, screenY: number): Slot | null {
    const p = this.world.toLocal({ x: screenX, y: screenY });
    let best: Slot | null = null;
    for (const s of SLOTS) {
      if (Math.abs(p.x - s.x) <= s.width / 2 && p.y <= s.y + 10 && p.y >= s.y - 110) best = s;
    }
    return best;
  }

  // --- Image par image ---
  update(v: CalendarView, dt: number): void {
    this.time += dt;
    const W = this.app.screen.width;
    const H = this.app.screen.height;
    const day = daylight(v);
    const nightK = 1 - smooth(0.0, 0.35, day);
    const snow = snowCover(v);
    const pal = seasonPalette(v);

    // Caméra
    const z = this.cam.zoom;
    this.world.scale.set(z);
    this.world.position.set(W / 2 - this.cam.x * z, H / 2 - this.cam.y * z);
    const para = (layer: Container, f: number, lift: number) => {
      layer.scale.set(z);
      layer.position.set(this.world.position.x + (this.cam.x - WORLD_W / 2) * z * (1 - f), this.world.position.y + (this.cam.y - 900) * z * (1 - f) * 0.5 - lift * z);
    };
    para(this.far, 0.3, 120);
    para(this.mid, 0.6, 30);

    // Ciel (redessiné seulement quand il change)
    const sky = skyColors(v, day);
    const skyKey = `${sky.top}-${sky.low}`;
    if (skyKey !== this.lastSkyKey) {
      paintGradient(this.skyCanvas, [[0, sky.top], [0.6, sky.mid], [1, sky.low]]);
      this.sky.texture.source.update();
      this.lastSkyKey = skyKey;
    }
    this.sky.width = W;
    this.sky.height = H;
    this.stars.alpha = nightK * (v.season.id === "hiver" ? 0.7 : 1);
    this.moon.alpha = nightK;
    this.moon.position.set(W * (0.25 + 0.5 * ((v.hour + 6) % 24) / 24), H * 0.16);

    // Teintes de saison (seulement si elles ont changé)
    const look = `${pal.grass}-${pal.foliage}-${pal.field}-${Math.round(snow * 50)}-${Math.round(nightK * 40)}`;
    if (look !== this.lastLook) {
      this.lastLook = look;
      const t = this.terrain;
      t.grass.tint = mix(pal.grass, 0xe8ecf0, snow * 0.6);
      t.fields.tint = mix(pal.field, 0xe8ecf0, snow);
      t.foliage.tint = pal.foliage;
      t.foliage.alpha = v.season.id === "hiver" ? 0.25 : 1 - smooth(0.6, 1, v.seasonIndex === 2 ? v.seasonProgress : 0) * 0.6;
      t.snow.alpha = snow;
      t.peakSnow.alpha = 0.55 + snow * 0.45;
      this.far.tint = mix(pal.far, 0x0c1020, nightK * 0.75);
      this.mid.tint = mix(shade(pal.far, -0.25), 0x080a14, nightK * 0.75);
      for (const e of this.views.values()) e.view.snow.alpha = snow;
    }

    // Bâtiments qui sortent de terre
    for (const e of this.views.values()) {
      const age = this.time - e.born;
      const k = clamp01(age / 1.2);
      const ease = 1 - Math.pow(1 - k, 3);
      e.view.root.alpha = k;
      e.view.root.scale.y = ease;
    }

    // Nuit et lumières
    this.night.alpha = nightK * 0.72;
    for (const l of this.lightSprites) {
      let a = l.spot.window ? (hash01(l.seed * 31 + Math.floor(v.hour / 3)) < 0.75 ? nightK : 0) : 0.25 + nightK * 0.75;
      if (l.spot.flicker) a *= 0.82 + Math.sin(this.time * 11 + l.seed) * 0.08 + Math.sin(this.time * 23 + l.seed * 3) * 0.06;
      if (l.spot.y > GROUND) a = Math.max(a, 0.85); // sous terre, toujours éclairé
      l.s.alpha = a;
    }

    // L'Ombre avance sur la plaine
    const reach = shadowReach(v);
    const front = lerp(-200, 650, reach);
    for (const f of this.fog) {
      const drift = Math.sin(this.time * 0.15 + f.phase) * 40;
      const x = Math.min(f.base, front - 120 + (f.base + 500) * 0.1) + drift;
      f.s.position.set(x, GROUND - 50 - f.row * 70 + Math.sin(this.time * 0.2 + f.phase) * 10);
      f.s.alpha = clamp01((front - x + 260) / 300) * (0.75 + nightK * 0.25);
    }
    for (const e of this.eyes) {
      e.x = front - 120 - (e.phase * 23) % 260;
      e.g.position.set(e.x, e.y);
      const blink = Math.sin(this.time * 0.7 + e.phase) > 0.2 ? 1 : 0;
      e.g.alpha = nightK * blink * smooth(0.4, 0.8, reach);
    }

    // Habitants : moins nombreux dehors la nuit
    for (const [i, w] of this.walkers.entries()) {
      w.x += w.speed * dt;
      if (w.x < w.min || w.x > w.max) {
        w.speed = -w.speed;
        w.x = Math.max(w.min, Math.min(w.max, w.x));
      }
      const out = w.inside || hash01(i * 13) < 0.25 || nightK < 0.6;
      w.g.visible = out;
      w.g.position.set(w.x, w.y - Math.abs(Math.sin(this.time * 7 + w.phase)) * 1.2);
      w.g.scale.x = w.speed < 0 ? -1 : 1;
      if (w.lantern) {
        w.lantern.position.set(w.x + (w.speed < 0 ? -4 : 4), w.y - 8);
        w.lantern.alpha = out ? nightK * 0.9 : 0;
      }
    }

    // Fumée des cheminées
    if (this.rng() < dt * 6) {
      const sources = [...this.views.values()].flatMap((e) => e.view.smoke);
      const src = sources.at(Math.floor(this.rng() * sources.length));
      if (src) {
        const s = new Sprite(blobTexture());
        s.anchor.set(0.5);
        s.width = s.height = 14;
        s.tint = src.y > GROUND ? 0x6a5a4a : 0xc8c8cc;
        s.position.set(src.x, src.y);
        this.smokeLayer.addChild(s);
        this.smoke.push({ s, life: 0, vx: 6 + this.rng() * 6 });
      }
    }
    for (let i = this.smoke.length - 1; i >= 0; i--) {
      const p = this.smoke[i];
      p.life += dt;
      p.s.y -= dt * 14;
      p.s.x += dt * p.vx;
      p.s.width = p.s.height = 14 + p.life * 16;
      p.s.alpha = Math.max(0, 0.5 - p.life * 0.09) * (1 - nightK * 0.5);
      if (p.life > 5.5) {
        p.s.destroy();
        this.smoke.splice(i, 1);
      }
    }

    this.updateWeather(v, dt, W, H, nightK);
  }

  // --- Neige, pluie, feuilles, pollen (à l'écran) ---
  updateWeather(v: CalendarView, dt: number, W: number, H: number, nightK: number): void {
    const dayIndex = Math.floor(v.hour / 24 + v.dayOfSeason + v.seasonIndex * 10 + v.year * 40);
    const wet = hash01(dayIndex * 7) < 0.45;
    let kind: "snow" | "rain" | "leaf" | "petal" | null = null;
    let rate = 0;
    if (v.season.id === "hiver") (kind = "snow"), (rate = 120);
    else if (v.season.id === "automne") (kind = wet ? "rain" : "leaf"), (rate = wet ? 260 : 14);
    else if (v.season.id === "printemps") (kind = wet ? "rain" : "petal"), (rate = wet ? 120 : 10);
    if (kind && this.particles.length < 900) {
      let n = rate * dt;
      while (n > 0) {
        if (this.rng() < n) {
          const s = new Sprite(Texture.WHITE);
          s.anchor.set(0.5);
          const p: Particle = { s, vx: 0, vy: 0, spin: 0 };
          if (kind === "snow") {
            const r = 1.5 + this.rng() * 2.5;
            s.texture = glowTexture();
            s.width = s.height = r * 3;
            p.vy = 30 + r * 14;
            p.vx = -10 + this.rng() * 8;
          } else if (kind === "rain") {
            s.width = 1.2;
            s.height = 14;
            s.tint = 0xa8c0d8;
            s.alpha = 0.5;
            s.rotation = 0.15;
            p.vy = 700;
            p.vx = -100;
          } else {
            s.width = 6;
            s.height = 3.5;
            s.tint = kind === "leaf" ? mix(0xc0602a, 0xe0a030, this.rng()) : 0xf4d0e0;
            p.vy = 40 + this.rng() * 20;
            p.vx = 30 + this.rng() * 30;
            p.spin = (this.rng() - 0.5) * 6;
          }
          s.position.set(this.rng() * (W + 200) - 100, -10);
          this.weatherLayer.addChild(s);
          this.particles.push(p);
        }
        n -= 1;
      }
    }
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.s.x += (p.vx + Math.sin(this.time * 2 + i) * (p.spin ? 20 : 8)) * dt;
      p.s.y += p.vy * dt;
      p.s.rotation += p.spin * dt;
      if (p.vy < 300) p.s.alpha = 0.85 - nightK * 0.35;
      if (p.s.y > H + 20 || p.s.x < -120 || p.s.x > W + 120) {
        p.s.destroy();
        this.particles.splice(i, 1);
      }
    }
  }
}
