// Couleurs par saison et par moment de la journée.
import type { CalendarView } from "../engine/calendar";
import { mix } from "./util";

interface SeasonPalette {
  grass: number;
  foliage: number;
  field: number;
  skyTop: number;
  skyLow: number;
  far: number;
}

const PALETTES: Record<string, SeasonPalette> = {
  printemps: { grass: 0x6f9a4a, foliage: 0x7fae52, field: 0x8fb15a, skyTop: 0x5f8fc4, skyLow: 0xc9d8e0, far: 0x8ea3b8 },
  ete: { grass: 0x88a046, foliage: 0x557f32, field: 0xd2b04a, skyTop: 0x4d86c6, skyLow: 0xe2dcc4, far: 0x9aaabb },
  automne: { grass: 0x8a7d42, foliage: 0xb8662a, field: 0x7a5a36, skyTop: 0x6a7f98, skyLow: 0xd8b892, far: 0x8c8f9a },
  hiver: { grass: 0x7d8277, foliage: 0x4a4038, field: 0x8a8478, skyTop: 0x56677c, skyLow: 0xb8c0c8, far: 0x8e98a6 },
};

const ORDER = ["printemps", "ete", "automne", "hiver"];

// Couleurs de la saison, fondues vers la suivante en fin de saison
export function seasonPalette(v: CalendarView): SeasonPalette {
  const a = PALETTES[ORDER[v.seasonIndex]];
  const b = PALETTES[ORDER[(v.seasonIndex + 1) % 4]];
  const t = Math.max(0, (v.seasonProgress - 0.75) / 0.25);
  const out = {} as SeasonPalette;
  for (const k of Object.keys(a) as (keyof SeasonPalette)[]) out[k] = mix(a[k], b[k], t);
  return out;
}

// Ciel : jour, aube ou crépuscule, nuit
export function skyColors(v: CalendarView, day: number): { top: number; mid: number; low: number } {
  const p = seasonPalette(v);
  const nightTop = 0x070912;
  const nightLow = 0x161a2c;
  const duskTop = 0x2b2f5a;
  const duskLow = 0xd9784a;
  const dusk = Math.max(0, 1 - Math.abs(day - 0.18) / 0.18) * (day < 0.45 ? 1 : 0);
  let top = mix(nightTop, p.skyTop, Math.min(1, day * 1.6));
  let low = mix(nightLow, p.skyLow, Math.min(1, day * 1.6));
  top = mix(top, duskTop, dusk * 0.5);
  low = mix(low, duskLow, dusk * 0.75);
  return { top, mid: mix(top, low, 0.55), low };
}
