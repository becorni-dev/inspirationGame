// Une partie : vivres, bois, peuples, logement, travail, hiver et colonnes de réfugiés.
// Fonctions pures : elles prennent un état et en renvoient un nouveau. Le hasard vient de la graine.
import economy from "../data/economy.json";
import refugees from "../data/refugees.json";
import { DAYS_PER_SEASON, SEASONS, type Season } from "./calendar";
import { BUILDINGS, type CityState, type PeopleId, build, canBuild, demolish, startingCity } from "./city";
import { mulberry32 } from "./rng";

export const PEOPLES: PeopleId[] = ["humain", "nain"];
export const PEOPLE_NAMES = refugees.peoples as Record<PeopleId, { name: string; one: string; share: number }>;
const DAYS_PER_YEAR = DAYS_PER_SEASON * SEASONS.length;
const WINTER = 3;

export interface Group {
  able: number; // valides, qui travaillent
  wounded: number; // blessés : mangent, ne travaillent pas, guérissent ou meurent au changement de saison
}

export interface Column {
  year: number;
  people: PeopleId;
  origin: string;
  story: string;
  able: number;
  wounded: number;
}

export type ColumnChoice = "tous" | "valides" | "personne";

export interface Entry {
  day: number;
  text: string;
  tone: "good" | "bad" | "neutral";
}

export interface Losses {
  cold: number;
  hunger: number;
  wounds: number;
}

export interface WinterReport extends Losses {
  year: number;
  survivors: number;
  food: number;
  wood: number;
}

export interface GameState {
  seed: number;
  day: number; // jours entièrement passés depuis le début
  city: CityState;
  food: number;
  wood: number;
  pop: Record<PeopleId, Group>;
  column: Column | null; // colonne aux portes, en attente de ta décision
  report: WinterReport | null; // bilan de l'hiver à montrer au joueur
  winter: Losses; // morts de l'hiver en cours
  deaths: Losses; // morts depuis le début
  welcomed: number;
  refused: number;
  chronicle: Entry[];
  fallen: boolean;
}

// --- Calendrier en jours ---

export interface DayInfo {
  year: number;
  seasonIndex: number;
  season: Season;
  dayOfSeason: number;
}

export function dayInfo(day: number): DayInfo {
  const inYear = ((day % DAYS_PER_YEAR) + DAYS_PER_YEAR) % DAYS_PER_YEAR;
  const seasonIndex = Math.floor(inYear / DAYS_PER_SEASON);
  return {
    year: Math.floor(day / DAYS_PER_YEAR) + 1,
    seasonIndex,
    season: SEASONS[seasonIndex],
    dayOfSeason: (inYear % DAYS_PER_SEASON) + 1,
  };
}

export function dayLabel(day: number): string {
  const d = dayInfo(day);
  return `An ${d.year}, ${d.season.name.toLowerCase()}`;
}

// --- Population ---

export function total(g: Group): number {
  return g.able + g.wounded;
}

export function population(state: GameState): number {
  return PEOPLES.reduce((n, p) => n + total(state.pop[p]), 0);
}

function placed(state: GameState, type: string) {
  return Object.values(state.city.buildings).filter((b) => b.type === type);
}

// --- Logement : les Nains vont d'abord dans les galeries, les Humains en surface ---

export interface Housing {
  galleryBeds: number;
  surfaceBeds: number;
  gallery: Record<PeopleId, number>;
  surface: Record<PeopleId, number>;
  homeless: Record<PeopleId, number>;
  galleryHouses: number; // maisons habitées (à chauffer)
  surfaceHouses: number;
}

export function housing(state: GameState): Housing {
  let galleryBeds = 0;
  let surfaceBeds = 0;
  for (const b of Object.values(state.city.buildings)) {
    const beds = BUILDINGS[b.type].beds ?? 0;
    if (b.slot.startsWith("galeries")) galleryBeds += beds;
    else surfaceBeds += beds;
  }
  const n = { humain: total(state.pop.humain), nain: total(state.pop.nain) };
  const gallery = { humain: 0, nain: Math.min(n.nain, galleryBeds) };
  const surface = { humain: Math.min(n.humain, surfaceBeds), nain: 0 };
  surface.nain = Math.min(n.nain - gallery.nain, surfaceBeds - surface.humain);
  gallery.humain = Math.min(n.humain - surface.humain, galleryBeds - gallery.nain);
  const homeless = { humain: n.humain - surface.humain - gallery.humain, nain: n.nain - surface.nain - gallery.nain };
  const beds = 5;
  return {
    galleryBeds,
    surfaceBeds,
    gallery,
    surface,
    homeless,
    galleryHouses: Math.ceil((gallery.humain + gallery.nain) / beds),
    surfaceHouses: Math.ceil((surface.humain + surface.nain) / beds),
  };
}

// --- Travail : chaque bâtiment reçoit un travailleur à tour de rôle, dans l'ordre des priorités ---

export interface Staff {
  slots: Record<string, Record<PeopleId, number>>;
  workers: number;
  idle: number;
  tools: number; // bonus de production des forges (0,1 = +10 %)
}

export function staffing(state: GameState): Staff {
  const free = { humain: state.pop.humain.able, nain: state.pop.nain.able };
  const order = Object.values(state.city.buildings)
    .filter((b) => (BUILDINGS[b.type].jobs ?? 0) > 0)
    .sort((a, b) => economy.jobPriority.indexOf(a.type) - economy.jobPriority.indexOf(b.type) || a.slot.localeCompare(b.slot));
  const slots: Record<string, Record<PeopleId, number>> = {};
  for (const b of order) slots[b.slot] = { humain: 0, nain: 0 };
  let changed = true;
  while (changed) {
    changed = false;
    for (const b of order) {
      const def = BUILDINGS[b.type];
      const s = slots[b.slot];
      if (s.humain + s.nain >= (def.jobs ?? 0)) continue;
      const who: PeopleId | null = def.onlyPeople ? (free[def.onlyPeople] > 0 ? def.onlyPeople : null) : free.humain > 0 ? "humain" : free.nain > 0 ? "nain" : null;
      if (!who) continue;
      s[who]++;
      free[who]--;
      changed = true;
    }
  }
  let tools = 0;
  for (const b of order) {
    const def = BUILDINGS[b.type];
    if (def.tools) tools += (def.tools * (slots[b.slot].humain + slots[b.slot].nain)) / (def.jobs ?? 1);
  }
  const workers = Object.values(slots).reduce((n, s) => n + s.humain + s.nain, 0);
  return { slots, workers, idle: free.humain + free.nain, tools };
}

// --- Production et consommation d'une journée ---

export interface Line {
  label: string;
  value: number;
}

export interface Forecast {
  foodIn: Line[];
  foodOut: Line[];
  woodIn: Line[];
  woodOut: Line[];
  food: number; // solde par jour
  wood: number;
  storage: number;
  shield: number; // part des morts d'hiver évitée par les phares
}

const sum = (lines: Line[]) => lines.reduce((n, l) => n + l.value, 0);

export function storage(state: GameState): number {
  return economy.baseStorage + placed(state, "grenier").length * (BUILDINGS.grenier.storage ?? 0);
}

export function forecast(state: GameState, seasonIndex = dayInfo(state.day).seasonIndex): Forecast {
  const staff = staffing(state);
  const boost = 1 + staff.tools;
  const foodIn: Line[] = [];
  const woodIn: Line[] = [];
  const add = (lines: Line[], label: string, value: number) => {
    if (value <= 0) return;
    const l = lines.find((x) => x.label === label);
    if (l) l.value += value;
    else lines.push({ label, value });
  };
  for (const b of Object.values(state.city.buildings)) {
    const def = BUILDINGS[b.type];
    const s = staff.slots[b.slot];
    if (!s) continue;
    const n = s.humain + s.nain;
    if (def.food) add(foodIn, `${def.name}s`, n * def.food[seasonIndex] * boost);
    if (def.wood) add(woodIn, `${def.name}s`, n * def.wood[seasonIndex] * boost);
  }
  if (staff.idle && economy.glean[seasonIndex]) add(foodIn, "Glaneurs (sans poste)", staff.idle * economy.glean[seasonIndex]);
  const h = housing(state);
  const heat = economy.heatPerHouse[seasonIndex];
  const woodOut: Line[] = [];
  if (heat > 0) {
    woodOut.push({ label: "Chauffage des maisons", value: heat * h.surfaceHouses });
    if (h.galleryHouses) woodOut.push({ label: "Chauffage des galeries", value: heat * economy.galleryHeatFactor * h.galleryHouses });
  }
  const phares = placed(state, "phare").length;
  if (seasonIndex === WINTER && phares) woodOut.push({ label: "Flamme des phares", value: phares * (BUILDINGS.phare.winterWood ?? 0) });
  const foodOut: Line[] = [{ label: `${population(state)} bouches à nourrir`, value: population(state) * economy.foodPerPerson }];
  return {
    foodIn,
    foodOut,
    woodIn,
    woodOut: woodOut.filter((l) => l.value > 0),
    food: sum(foodIn) - sum(foodOut),
    wood: sum(woodIn) - sum(woodOut),
    storage: storage(state),
    shield: Math.min(economy.winterShieldMax, phares * (BUILDINGS.phare.winterShield ?? 0)),
  };
}

// Ce qu'il faut avoir en réserve pour passer tout l'hiver avec la cité d'aujourd'hui
export function winterNeeds(state: GameState): { food: number; wood: number } {
  const f = forecast(state, WINTER);
  return { food: Math.max(0, -f.food * DAYS_PER_SEASON), wood: Math.max(0, -f.wood * DAYS_PER_SEASON) };
}

// --- Le passage d'un jour ---

function deathsAmong(rng: () => number, n: number, p: number): number {
  let d = 0;
  for (let i = 0; i < n; i++) if (rng() < p) d++;
  return d;
}

function kill(group: Group, n: number): Group {
  const fromWounded = Math.min(group.wounded, n);
  return { wounded: group.wounded - fromWounded, able: Math.max(0, group.able - (n - fromWounded)) };
}

function log(state: GameState, text: string, tone: Entry["tone"] = "neutral"): Entry[] {
  return [...state.chronicle, { day: state.day, text, tone }].slice(-60);
}

export function nextDay(state: GameState): GameState {
  if (state.fallen) return state;
  const info = dayInfo(state.day);
  const si = info.seasonIndex;
  const rng = mulberry32(state.seed * 7919 + state.day * 104729 + 13);
  const f = forecast(state, si);
  const h = housing(state);
  const pop = { humain: { ...state.pop.humain }, nain: { ...state.pop.nain } };
  const losses = { cold: 0, hunger: 0, wounds: 0 };
  let s: GameState = { ...state, pop };

  // Vivres : si on manque, une part de la cité a faim
  const foodHave = state.food + sum(f.foodIn);
  const foodNeed = sum(f.foodOut);
  let hungry = 0;
  if (foodHave >= foodNeed) s.food = Math.min(f.storage, foodHave - foodNeed);
  else {
    hungry = 1 - foodHave / foodNeed;
    s.food = 0;
  }

  // Bois : si on manque, les maisons ont froid et les phares s'éteignent
  const woodHave = state.wood + sum(f.woodIn);
  const woodNeed = sum(f.woodOut);
  let shortage = 0;
  if (woodHave >= woodNeed) s.wood = woodHave - woodNeed;
  else {
    shortage = 1 - woodHave / woodNeed;
    s.wood = 0;
  }

  const shield = si === WINTER ? f.shield * (1 - shortage) : 0;
  const r = economy.risk;
  for (const p of PEOPLES) {
    let cold = 0;
    if (si === WINTER) {
      cold += deathsAmong(rng, h.homeless[p], r.homelessWinter * (1 - shield));
      if (shortage > 0) {
        cold += deathsAmong(rng, h.surface[p], r.coldNoWood * shortage * (1 - shield));
        cold += deathsAmong(rng, h.gallery[p], r.coldNoWood * r.galleryColdFactor * shortage * (1 - shield));
      }
    }
    const hunger = hungry > 0 ? deathsAmong(rng, Math.round(total(pop[p]) * hungry), r.hunger * (1 - shield)) : 0;
    pop[p] = kill(pop[p], cold + hunger);
    losses.cold += cold;
    losses.hunger += hunger;
  }
  if (losses.cold) s.chronicle = log(s, `${dayLabel(state.day)} : ${losses.cold} ${losses.cold > 1 ? "morts" : "mort"} de froid.`, "bad");
  if (losses.hunger) s.chronicle = log(s, `${dayLabel(state.day)} : ${losses.hunger} ${losses.hunger > 1 ? "morts" : "mort"} de faim.`, "bad");

  s.day = state.day + 1;

  // Changement de saison : les blessés guérissent ou meurent
  const next = dayInfo(s.day);
  if (next.seasonIndex !== si) {
    for (const p of PEOPLES) {
      const died = deathsAmong(rng, pop[p].wounded, 1 - economy.wounds.healChance);
      losses.wounds += died;
      pop[p] = { able: pop[p].able + pop[p].wounded - died, wounded: 0 };
    }
    if (losses.wounds) s.chronicle = log(s, `${dayLabel(s.day)} : ${losses.wounds} ${losses.wounds > 1 ? "blessés n'ont pas survécu" : "blessé n'a pas survécu"}.`, "bad");
  }
  s.winter = si === WINTER ? add(state.winter, losses) : state.winter;
  s.deaths = add(state.deaths, losses);

  if (next.seasonIndex !== si) {
    if (next.seasonIndex === WINTER) s.chronicle = log(s, `${dayLabel(s.day)} : l'hiver tombe sur Hautbourg.`);
    if (next.seasonIndex === 0) {
      s.report = { year: info.year, ...s.winter, survivors: population(s), food: Math.floor(s.food), wood: Math.floor(s.wood) };
      const lost = s.winter.cold + s.winter.hunger + s.winter.wounds;
      s.chronicle = log(s, `Fin de l'hiver de l'an ${info.year} : ${lost ? `${lost} ${lost > 1 ? "morts" : "mort"}` : "personne n'est mort"}, ${population(s)} survivants.`, lost ? "bad" : "good");
      s.winter = { cold: 0, hunger: 0, wounds: 0 };
      s.column = makeColumn(s, next.year);
    }
  }
  if (population(s) === 0) {
    s.fallen = true;
    s.chronicle = log(s, `${dayLabel(s.day)} : Hautbourg est tombée.`, "bad");
  }
  return s;
}

function add(a: Losses, b: Losses): Losses {
  return { cold: a.cold + b.cold, hunger: a.hunger + b.hunger, wounds: a.wounds + b.wounds };
}

// --- Les colonnes de réfugiés ---

export function makeColumn(state: GameState, year: number): Column {
  const rng = mulberry32(state.seed * 31337 + year * 977);
  const people: PeopleId = rng() < PEOPLE_NAMES.humain.share ? "humain" : "nain";
  const list = refugees.origins[people];
  const origin = list[Math.floor(rng() * list.length)];
  const bonus = placed(state, "hall").reduce((n, b) => n + (BUILDINGS[b.type].columnBonus ?? 0), 0);
  const [min, max] = refugees.size;
  const size = Math.round((min + rng() * (max - min)) * (1 + bonus));
  const [wmin, wmax] = refugees.wounded;
  const wounded = Math.round(size * (wmin + rng() * (wmax - wmin)));
  return { year, people, origin: origin.name, story: origin.story, able: size - wounded, wounded };
}

export function answerColumn(state: GameState, choice: ColumnChoice): GameState {
  const c = state.column;
  if (!c) return state;
  const able = choice === "personne" ? 0 : c.able;
  const wounded = choice === "tous" ? c.wounded : 0;
  const size = c.able + c.wounded;
  const g = state.pop[c.people];
  const pop = { ...state.pop, [c.people]: { able: g.able + able, wounded: g.wounded + wounded } };
  const shut = size - able - wounded;
  const who = PEOPLE_NAMES[c.people].name.toLowerCase();
  const text =
    choice === "tous"
      ? `${dayLabel(state.day)} : les portes s'ouvrent pour ${c.origin}, ${size} ${who} dont ${c.wounded} blessés.`
      : choice === "valides"
        ? `${dayLabel(state.day)} : ${able} ${who} de ${c.origin} entrent. ${c.wounded} blessés restent dehors.`
        : `${dayLabel(state.day)} : les portes restent fermées. ${c.origin} repartent dans la brume, ${size} ${who}.`;
  return {
    ...state,
    pop,
    column: null,
    welcomed: state.welcomed + able + wounded,
    refused: state.refused + shut,
    chronicle: log(state, text, choice === "tous" ? "good" : "bad"),
  };
}

// --- Bâtir et démolir ---

export function buildError(state: GameState, slotId: string, type: string): string {
  const why = canBuild(state.city, slotId, type);
  if (why) return why;
  if (dayInfo(state.day).seasonIndex === WINTER) return "L'hiver, on ne bâtit pas : la terre est gelée.";
  const cost = BUILDINGS[type].cost;
  if (state.wood < cost) return `Pas assez de bois : il en faut ${cost}.`;
  return "";
}

export function construct(state: GameState, slotId: string, type: string, hour: number): GameState {
  if (buildError(state, slotId, type)) return state;
  return { ...state, wood: state.wood - BUILDINGS[type].cost, city: build(state.city, slotId, type, hour) };
}

export function tearDown(state: GameState, slotId: string): GameState {
  const b = state.city.buildings[slotId];
  if (!b) return state;
  return { ...state, wood: state.wood + Math.floor(BUILDINGS[b.type].cost * economy.demolishRefund), city: demolish(state.city, slotId) };
}

// --- Nouvelle partie ---

export function newGame(seed = 1): GameState {
  const st = economy.start;
  const s: GameState = {
    seed,
    day: 0,
    city: startingCity(),
    food: st.food,
    wood: st.wood,
    pop: { humain: { able: st.people.humain, wounded: 0 }, nain: { able: st.people.nain, wounded: 0 } },
    column: null,
    report: null,
    winter: { cold: 0, hunger: 0, wounds: 0 },
    deaths: { cold: 0, hunger: 0, wounds: 0 },
    welcomed: 0,
    refused: 0,
    chronicle: [{ day: 0, text: "An 1, printemps : la route du sud se remplit. L'Ombre a avalé les vallées, et Hautbourg est la dernière cité libre.", tone: "neutral" }],
    fallen: false,
  };
  return { ...s, column: makeColumn(s, 1) };
}

// Avance de plusieurs jours en accueillant toutes les colonnes (captures et tests)
export function fastForward(state: GameState, days: number): GameState {
  let s = state;
  for (let i = 0; i < days; i++) {
    if (s.column) s = answerColumn(s, "tous");
    s = { ...nextDay(s), report: null };
  }
  return s;
}
