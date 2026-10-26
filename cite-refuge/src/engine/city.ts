// La cité : emplacements par zone et bâtiments posés. Fonctions pures.
import buildingsData from "../data/buildings.json";
import sitesData from "../data/sites.json";

export type ZoneId = "cite" | "terrasses" | "galeries";

export interface BuildingType {
  name: string;
  key: string;
  zones: ZoneId[];
  desc: string;
  people?: number;
  light?: number;
}

export interface Slot {
  id: string;
  zone: ZoneId;
  x: number;
  y: number;
  width: number;
}

export interface Placed {
  slot: string;
  type: string;
  builtAt: number; // heure de jeu de la pose (pour l'animation)
  seed: number;
}

export interface CityState {
  buildings: Record<string, Placed>; // emplacement -> bâtiment
  nextSeed: number;
}

export const BUILDINGS = buildingsData.types as Record<string, BuildingType>;
export const BUILDING_ORDER = buildingsData.order as string[];
export const ZONES = sitesData.zones as Record<ZoneId, { name: string; desc: string }>;

export const SLOTS: Slot[] = (() => {
  const list: Slot[] = [];
  const counters: Record<string, number> = {};
  for (const ledge of sitesData.ledges) {
    const zone = ledge.zone as ZoneId;
    const width = (ledge.x1 - ledge.x0) / ledge.slots;
    for (let i = 0; i < ledge.slots; i++) {
      const n = counters[zone] ?? 0;
      counters[zone] = n + 1;
      list.push({ id: `${zone}-${n}`, zone, x: ledge.x0 + width * (i + 0.5), y: ledge.y, width });
    }
  }
  return list;
})();

export function slotById(id: string): Slot | undefined {
  return SLOTS.find((s) => s.id === id);
}

// Raison pour laquelle on ne peut pas bâtir ("" si c'est possible).
export function canBuild(state: CityState, slotId: string, type: string): string {
  const slot = slotById(slotId);
  const def = BUILDINGS[type];
  if (!slot) return "Emplacement inconnu";
  if (!def) return "Bâtiment inconnu";
  if (state.buildings[slotId]) return "Emplacement déjà occupé";
  if (!def.zones.includes(slot.zone)) {
    const where = def.zones.map((z) => ZONES[z].name.toLowerCase()).join(" ou ");
    return `${def.name} : seulement dans ${where}`;
  }
  return "";
}

export function build(state: CityState, slotId: string, type: string, hour: number): CityState {
  if (canBuild(state, slotId, type) !== "") return state;
  return {
    buildings: { ...state.buildings, [slotId]: { slot: slotId, type, builtAt: hour, seed: state.nextSeed } },
    nextSeed: state.nextSeed + 1,
  };
}

export function demolish(state: CityState, slotId: string): CityState {
  if (!state.buildings[slotId]) return state;
  const buildings = { ...state.buildings };
  delete buildings[slotId];
  return { ...state, buildings };
}

export function startingCity(): CityState {
  let state: CityState = { buildings: {}, nextSeed: 1 };
  for (const s of sitesData.start) state = build(state, s.slot, s.type, -100);
  return state;
}

export function population(state: CityState): number {
  return Object.values(state.buildings).reduce((n, b) => n + (BUILDINGS[b.type].people ?? 0), 0);
}
