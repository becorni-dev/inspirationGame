// Point d'entrée : relie le moteur (temps, partie), la scène PixiJS et l'interface.
import { Application } from "pixi.js";
import { type Clock, HOURS_PER_YEAR, SECONDS_PER_HOUR, advance, view } from "./engine/calendar";
import { type GameState, answerColumn, buildError, construct, dayLabel, fastForward, newGame, nextDay, staffing, tearDown } from "./engine/game";
import { Scene } from "./render/scene";
import { Hud } from "./ui/hud";
import "./ui/style.css";

const params = new URLSearchParams(location.search);
const SPEEDS = [0, 1, 3, 8];
const SAVE_KEY = "cite-refuge-partie-1";
const START_HOUR = 7; // la partie commence au printemps de l'an 1, à 7 h

// Sauvegarde automatique : l'état complet en JSON (le navigateur peut la refuser, on s'en passe alors)
function save(state: GameState, clock: Clock): void {
  try {
    localStorage.setItem(SAVE_KEY, JSON.stringify({ state, hours: clock.hours }));
  } catch {
    /* sauvegarde impossible */
  }
}
function load(): { state: GameState; hours: number } | null {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

async function start(): Promise<void> {
  const app = new Application();
  await app.init({ resizeTo: window, background: 0x0b0d12, antialias: true, autoDensity: true, resolution: Math.min(window.devicePixelRatio, 2) });
  document.getElementById("stage")!.appendChild(app.canvas);

  // Écran titre : fin d'automne au crépuscule (ou ?t=heures pour les captures)
  let clock: Clock = { hours: params.has("t") ? Number(params.get("t")) : HOURS_PER_YEAR * 0.5 + 17.5 };
  let state: GameState = newGame(Number(params.get("seed") ?? 1));
  let speed = params.has("speed") ? Number(params.get("speed")) : 1;
  let tool: string | null = null;
  let hover: string | null = null;
  let playing = false;

  const scene = new Scene(app);
  if (params.has("zoom")) scene.cam.zoom = Number(params.get("zoom"));
  if (params.has("x")) scene.cam.x = Number(params.get("x"));
  if (params.has("y")) scene.cam.y = Number(params.get("y"));

  const frozen = () => !!(state.column || state.report || state.fallen);
  const refresh = () => {
    scene.syncCity(state.city);
    scene.syncPeople(state, staffing(state));
  };
  const begin = (s: GameState, hours: number) => {
    state = s;
    clock = { hours };
    playing = true;
    refresh();
    hud.showGame();
  };

  const hud = new Hud(document.getElementById("hud")!, {
    onPlay: (resume) => {
      const saved = resume ? load() : null;
      if (saved) begin(saved.state, saved.hours);
      else begin(newGame(Number(params.get("seed") ?? Date.now() % 100000)), START_HOUR);
    },
    onSpeed: (i) => (speed = i),
    onTool: (t) => {
      tool = tool === t ? null : t;
      hud.setTool(tool);
    },
    onSkipSeason: () => {
      if (frozen()) return;
      clock = advance(clock, (HOURS_PER_YEAR / 4) * (1 - view(clock).seasonProgress) + 0.01);
    },
    onColumn: (choice) => {
      const c = state.column;
      state = answerColumn(state, choice);
      if (c) scene.releaseColumn(choice);
      refresh();
      save(state, clock);
    },
    onReportDone: () => {
      state = { ...state, report: null };
      save(state, clock);
    },
    onRestart: () => {
      try {
        localStorage.removeItem(SAVE_KEY);
      } catch {
        /* rien */
      }
      location.reload();
    },
  });
  const saved = load();
  hud.offerResume(saved && !saved.state.fallen ? dayLabel(saved.state.day) : null);

  // Captures : ?play lance directement une partie (?t avance jusqu'à cette heure en accueillant tout le monde)
  if (params.has("play")) {
    const t = params.has("t") ? Number(params.get("t")) : START_HOUR;
    const d = Math.floor(t / 24);
    let s = fastForward(newGame(Number(params.get("seed") ?? 1)), params.has("keep") ? d - 1 : d);
    if (params.has("keep")) s = nextDay(s.column ? answerColumn(s, "tous") : s); // garde le bilan de l'hiver à l'écran
    if (params.has("calm")) s = { ...s, column: null, report: null };
    begin(s, t);
  } else refresh();

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
      hud.showInfo(null, state);
      return;
    }
    if (tool && !state.city.buildings[slot.id]) {
      const why = frozen() ? "Décide d'abord de ce qui se passe aux portes." : buildError(state, slot.id, tool);
      if (why) hud.toast(why, true);
      else {
        state = construct(state, slot.id, tool, clock.hours);
        refresh();
        save(state, clock);
      }
    } else hud.showInfo(slot, state);
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
      hud.showInfo(null, state);
    }
    if (e.code === "Delete" && hover && state.city.buildings[hover] && !frozen()) {
      state = tearDown(state, hover);
      refresh();
      hud.showInfo(null, state);
      save(state, clock);
    }
    const digit = /^(?:Digit|Numpad)([1-8])$/.exec(e.code);
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
    if (!playing) clock = advance(clock, (dt * 0.6) / SECONDS_PER_HOUR);
    else if (!frozen()) {
      clock = advance(clock, (dt * (SPEEDS[speed] ?? 1)) / SECONDS_PER_HOUR);
      // Chaque jour écoulé fait tourner le moteur ; une décision arrête le temps
      let changed = false;
      while (Math.floor(clock.hours / 24) > state.day && !frozen()) {
        state = nextDay(state);
        changed = true;
      }
      if (frozen()) clock = { hours: state.day * 24 + 0.01 };
      if (changed) {
        refresh();
        save(state, clock);
      }
    }
    if (playing && state.column && !state.report) scene.showColumn(state.column);
    const pan = (700 * dt) / scene.cam.zoom;
    if (keys.has("KeyW") || keys.has("ArrowUp")) scene.cam.y -= pan;
    if (keys.has("KeyS") || keys.has("ArrowDown")) scene.cam.y += pan;
    if (keys.has("KeyA") || keys.has("ArrowLeft")) scene.cam.x -= pan;
    if (keys.has("KeyD") || keys.has("ArrowRight")) scene.cam.x += pan;
    scene.cam.x = Math.max(0, Math.min(3200, scene.cam.x));
    scene.cam.y = Math.max(200, Math.min(1500, scene.cam.y));
    const v = view(clock);
    scene.showSlots(playing ? tool : null, state, hover);
    scene.update(v, dt);
    if (playing) hud.update(v, state, speed, frozen());
  });
}

start();
