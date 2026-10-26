// Petits outils de dessin : couleurs, textures fabriquées par le navigateur.
import { Texture } from "pixi.js";

export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

export function clamp01(t: number): number {
  return Math.max(0, Math.min(1, t));
}

export function smooth(a: number, b: number, x: number): number {
  const t = clamp01((x - a) / (b - a));
  return t * t * (3 - 2 * t);
}

export function mix(c1: number, c2: number, t: number): number {
  const k = clamp01(t);
  const r = Math.round(lerp((c1 >> 16) & 255, (c2 >> 16) & 255, k));
  const g = Math.round(lerp((c1 >> 8) & 255, (c2 >> 8) & 255, k));
  const b = Math.round(lerp(c1 & 255, c2 & 255, k));
  return (r << 16) | (g << 8) | b;
}

export function shade(c: number, f: number): number {
  return f >= 0 ? mix(c, 0xffffff, f) : mix(c, 0x000000, -f);
}

export function css(c: number): string {
  return `#${c.toString(16).padStart(6, "0")}`;
}

function canvasTexture(w: number, h: number, paint: (ctx: CanvasRenderingContext2D) => void): Texture {
  const c = document.createElement("canvas");
  c.width = w;
  c.height = h;
  paint(c.getContext("2d")!);
  return Texture.from(c);
}

// Halo lumineux doux (fenêtres, braseros, phares)
export const glowTexture = (() => {
  let tex: Texture | null = null;
  return () =>
    (tex ??= canvasTexture(128, 128, (ctx) => {
      const g = ctx.createRadialGradient(64, 64, 0, 64, 64, 64);
      g.addColorStop(0, "rgba(255,255,255,1)");
      g.addColorStop(0.25, "rgba(255,255,255,0.55)");
      g.addColorStop(0.6, "rgba(255,255,255,0.12)");
      g.addColorStop(1, "rgba(255,255,255,0)");
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, 128, 128);
    }));
})();

// Nappe de brume irrégulière (Ombre, nuages)
export const blobTexture = (() => {
  let tex: Texture | null = null;
  return () =>
    (tex ??= canvasTexture(256, 256, (ctx) => {
      for (let i = 0; i < 14; i++) {
        const x = 128 + Math.cos(i * 2.4) * 50 * ((i % 3) / 2 + 0.3);
        const y = 128 + Math.sin(i * 1.7) * 40 * ((i % 4) / 3 + 0.3);
        const r = 50 + ((i * 37) % 40);
        const g = ctx.createRadialGradient(x, y, 0, x, y, r);
        g.addColorStop(0, "rgba(255,255,255,0.35)");
        g.addColorStop(1, "rgba(255,255,255,0)");
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, 256, 256);
      }
    }));
})();

// Dégradé vertical du ciel, redessiné quand l'heure change
export function paintGradient(canvas: HTMLCanvasElement, stops: [number, number][]): void {
  const ctx = canvas.getContext("2d")!;
  const g = ctx.createLinearGradient(0, 0, 0, canvas.height);
  for (const [at, color] of stops) g.addColorStop(at, css(color));
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
}
