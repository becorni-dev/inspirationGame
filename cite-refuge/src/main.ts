// Point d'entrée : relie le moteur (temps, cité), la scène PixiJS et l'interface.
import { Application } from "pixi.js";
import { type Clock, HOURS_PER_YEAR, SECONDS_PER_HOUR, advance, view } from "./engine/calendar";
import { build, canBuild, demolish, startingCity, type CityState } from "./engine/city";
import { Scene } from "./render/scene";
import { Hud } from "./ui/hud";
import "./ui/style.css";

const params = new URLSearchParams(location.search);
const SPEEDS = [0, 1, 3, 8];

async function start(): Promise<void> {
  const app = new Application();
  await app.init({ resizeTo: window, background: 0x0b0d12, antialias: true, autoDensity: true, resolution: Math.min(window.devicePixelRatio, 2) });
  document.getElementById("stage")!.appendChild(app.canvas);

  // Saison de départ : fin d'automne au crépuscule pour l'écran titre (modifiable par ?t=heures)
  let clock: Clock = { hours: params.has("t") ? Number(params.get("t")) : HOURS_PER_YEAR * 0.5 + 17.5 };
  let city: CityState = startingCity();
  let speed = params.has("speed") ? Number(params.get("speed")) : 1;
  let tool: string | null = null;
  let hover: string | null = null;
  let playing = params.has("play");

  const scene = new Scene(app);
  if (params.has("zoom")) scene.cam.zoom = Number(params.get("zoom"));
  if (params.has("x")) scene.cam.x = Number(params.get("x"));
  if (params.has("y")) scene.cam.y = Number(params.get("y"));
  scene.syncCity(city);

  const hud = new Hud(document.getElementById("hud")!, {
    onPlay: () => {
      playing = true;
      hud.showGame();
    },
    onSpeed: (i) => (speed = i),
    onTool: (t) => {
      tool = tool === t ? null : t;
      hud.setTool(tool);
    },
    onSkipSeason: () => {
      clock = advance(clock, (HOURS_PER_YEAR / 4) * (1 - view(clock).seasonProgress) + 0.01);
      hud.toast(`Voici ${view(clock).season.name.toLowerCase()}.`);
    },
  });
  if (playing) hud.showGame();

  // --- Souris : construire, inspecter, déplacer la vue ---
  let drag: { x: number; y: number; cx: number; cy: number; moved: boolean } | null = null;
  const canvas = app.canvas;
  canvas.addEventListener("contextmenu", (e) => e.preventDefault());
  canvas.addEventListener("pointerdown", (e) => {
    drag = { x: e.clientX, y: e.clientY, cx: scene.cam.x, cy: scene.cam.y, moved: false };
  });
  window.addEventListener("pointerup", (e) => {
    const wasDrag = drag?.moved;
    drag = null;
    if (wasDrag || !playing || e.target !== canvas) return;
    const slot = scene.slotAt(e.clientX, e.clientY);
    if (e.button === 2) {
      tool = null;
      hud.setTool(null);
      return;
    }
    if (!slot) {
      hud.showInfo(null, city);
      return;
    }
    if (tool) {
      const why = canBuild(city, slot.id, tool);
      if (why) hud.toast(why, true);
      else {
        city = build(city, slot.id, tool, clock.hours);
        scene.syncCity(city);
      }
    } else hud.showInfo(slot, city);
  });
  window.addEventListener("pointermove", (e) => {
    if (drag) {
      const dx = e.clientX - drag.x;
      const dy = e.clientY - drag.y;
      if (Math.abs(dx) + Math.abs(dy) > 5) drag.moved = true;
      if (drag.moved) {
        scene.cam.x = drag.cx - dx / scene.cam.zoom;
        scene.cam.y = drag.cy - dy / scene.cam.zoom;
      }
    }
    hover = scene.slotAt(e.clientX, e.clientY)?.id ?? null;
  });
  canvas.addEventListener("wheel", (e) => {
    e.preventDefault();
    const before = scene.world.toLocal({ x: e.clientX, y: e.clientY });
    scene.cam.zoom = Math.max(0.35, Math.min(2.4, scene.cam.zoom * (e.deltaY < 0 ? 1.12 : 1 / 1.12)));
    scene.update(view(clock), 0);
    const after = scene.world.toLocal({ x: e.clientX, y: e.clientY });
    scene.cam.x += before.x - after.x;
    scene.cam.y += before.y - after.y;
  }, { passive: false });

  // --- Clavier ---
  const keys = new Set<string>();
  window.addEventListener("keydown", (e) => {
    keys.add(e.code);
    if (!playing) return;
    if (e.code === "Space") {
      speed = speed === 0 ? 1 : 0;
      e.preventDefault();
    }
    if (e.code === "Escape") {
      tool = null;
      hud.setTool(null);
      hud.showInfo(null, city);
    }
    if (e.code === "Delete" && hover && city.buildings[hover]) {
      city = demolish(city, hover);
      scene.syncCity(city);
      hud.showInfo(null, city);
    }
    const digit = /^Digit([1-6])$/.exec(e.code);
    if (digit) {
      const t = hud.toolByKey(digit[1]);
      if (t) {
        tool = tool === t ? null : t;
        hud.setTool(tool);
      }
    }
  });
  window.addEventListener("keyup", (e) => keys.delete(e.code));

  app.ticker.add((ticker) => {
    const dt = Math.min(0.1, ticker.deltaMS / 1000);
    const rate = playing ? SPEEDS[speed] ?? 1 : 0.6;
    clock = advance(clock, (dt * rate) / SECONDS_PER_HOUR);
    const pan = 700 * dt / scene.cam.zoom;
    if (keys.has("KeyW") || keys.has("ArrowUp")) scene.cam.y -= pan;
    if (keys.has("KeyS") || keys.has("ArrowDown")) scene.cam.y += pan;
    if (keys.has("KeyA") || keys.has("ArrowLeft")) scene.cam.x -= pan;
    if (keys.has("KeyD") || keys.has("ArrowRight")) scene.cam.x += pan;
    scene.cam.x = Math.max(0, Math.min(3200, scene.cam.x));
    scene.cam.y = Math.max(200, Math.min(1500, scene.cam.y));
    const v = view(clock);
    scene.showSlots(playing ? tool : null, city, hover);
    scene.update(v, dt);
    hud.update(v, city, speed);
  });
}

start();
