import { describe, expect, it } from "vitest";
import {
  type GameState,
  answerColumn,
  buildError,
  construct,
  dayInfo,
  fastForward,
  forecast,
  housing,
  newGame,
  nextDay,
  population,
  staffing,
  storage,
  winterNeeds,
} from "../src/engine/game";

const WINTER_START = 18;
const days = (s: GameState, n: number) => fastForward(s, n);

describe("une partie", () => {
  it("commence au printemps avec une colonne aux portes", () => {
    const g = newGame(1);
    expect(dayInfo(g.day).season.id).toBe("printemps");
    expect(g.column).not.toBeNull();
    expect(population(g)).toBe(40);
  });

  it("la décision sur la colonne change la population", () => {
    const g = newGame(1);
    const c = g.column!;
    expect(population(answerColumn(g, "tous"))).toBe(40 + c.able + c.wounded);
    expect(population(answerColumn(g, "valides"))).toBe(40 + c.able);
    const shut = answerColumn(g, "personne");
    expect(population(shut)).toBe(40);
    expect(shut.refused).toBe(c.able + c.wounded);
  });

  it("le Hall des peuples attire des colonnes plus grandes", () => {
    const g = newGame(3);
    const noHall = { ...g, city: { ...g.city, buildings: Object.fromEntries(Object.entries(g.city.buildings).filter(([, b]) => b.type !== "hall")) } };
    const size = (s: GameState) => {
      const n = nextDayUntilSpring(s).column!;
      return n.able + n.wounded;
    };
    expect(size(g)).toBeGreaterThan(size(noHall));
  });

  it("même graine, mêmes choix : même histoire", () => {
    expect(days(newGame(7), 30)).toEqual(days(newGame(7), 30));
  });
});

function nextDayUntilSpring(s: GameState): GameState {
  let g = answerColumn(s, "personne");
  while (!g.column) g = nextDay(g);
  return g;
}

describe("production", () => {
  it("les fermes donnent plus en été et à l'automne, rien l'hiver", () => {
    const g = answerColumn(newGame(1), "personne");
    const farms = (si: number) => forecast(g, si).foodIn.find((l) => l.label === "Fermes")?.value ?? 0;
    expect(farms(1)).toBeGreaterThan(farms(0));
    expect(farms(2)).toBeGreaterThan(farms(1));
    expect(farms(3)).toBe(0);
  });

  it("la serre nourrit même l'hiver", () => {
    const g = answerColumn(newGame(1), "personne");
    expect(forecast(g, 3).foodIn.find((l) => l.label === "Serres")!.value).toBeGreaterThan(0);
  });

  it("seuls les Nains travaillent à la forge, qui donne +10 % de production", () => {
    let g = answerColumn(newGame(1), "personne");
    const forge = Object.values(g.city.buildings).find((b) => b.type === "forge")!;
    expect(staffing(g).slots[forge.slot]).toEqual({ humain: 0, nain: 3 });
    expect(staffing(g).tools).toBeCloseTo(0.1);
    g = { ...g, pop: { ...g.pop, nain: { able: 0, wounded: 0 } } };
    expect(staffing(g).slots[forge.slot]).toEqual({ humain: 0, nain: 0 });
    expect(staffing(g).tools).toBe(0);
  });

  it("les vivres au-delà des greniers pourrissent", () => {
    const g = { ...answerColumn(newGame(1), "personne"), food: 10000 };
    expect(nextDay(g).food).toBe(storage(g));
    const more = construct({ ...g, wood: 100 }, "cite-3", "grenier", 0);
    expect(storage(more)).toBe(storage(g) + 150);
  });
});

describe("logement", () => {
  it("les Nains s'installent d'abord dans les galeries", () => {
    const g = answerColumn(newGame(1), "personne");
    const h = housing(g);
    expect(h.gallery.nain).toBe(Math.min(10, h.galleryBeds));
    expect(h.surface.humain).toBe(Math.min(30, h.surfaceBeds));
  });

  it("une maison coûte du bois et donne 5 lits", () => {
    const g = { ...answerColumn(newGame(1), "personne"), wood: 100 };
    const g2 = construct(g, "cite-3", "maison", 0);
    expect(g2.wood).toBe(80);
    expect(housing(g2).surfaceBeds).toBe(housing(g).surfaceBeds + 5);
  });

  it("on ne bâtit pas l'hiver ni sans bois", () => {
    const g = answerColumn(newGame(1), "personne");
    expect(buildError({ ...g, wood: 0 }, "cite-3", "maison")).toMatch(/bois/);
    expect(buildError({ ...g, day: WINTER_START, wood: 100 }, "cite-3", "maison")).toMatch(/hiver/);
  });
});

describe("hiver", () => {
  const winter = (wood: number, extra = 0) => {
    const g = answerColumn(newGame(5), "personne");
    let s: GameState = { ...g, day: WINTER_START, wood, food: 500, pop: { ...g.pop, humain: { able: 30 + extra, wounded: 0 } } };
    for (let i = 0; i < 6; i++) s = nextDay(s);
    return s;
  };

  it("le chauffage brûle du bois l'hiver", () => {
    const g = { ...answerColumn(newGame(1), "personne"), day: WINTER_START };
    expect(forecast(g).wood).toBeLessThan(0);
    expect(winterNeeds(g).wood).toBeGreaterThan(0);
  });

  it("sans bois, la cité meurt de froid", () => {
    const warm = winter(1000);
    const cold = winter(0);
    expect(cold.report!.cold).toBeGreaterThan(warm.report!.cold);
  });

  it("dormir dehors l'hiver tue", () => {
    expect(winter(1000, 40).report!.cold).toBeGreaterThan(winter(1000, 0).report!.cold);
  });

  it("la faim tue quand les réserves sont vides", () => {
    const g = answerColumn(newGame(2), "personne");
    let s: GameState = { ...g, day: WINTER_START, food: 0, wood: 1000 };
    for (let i = 0; i < 6; i++) s = nextDay(s);
    expect(s.report!.hunger).toBeGreaterThan(0);
  });

  it("au printemps : bilan de l'hiver et nouvelle colonne", () => {
    const g = answerColumn(newGame(1), "personne");
    let s: GameState = { ...g, day: WINTER_START, wood: 1000, food: 500 };
    for (let i = 0; i < 6; i++) s = nextDay(s);
    expect(dayInfo(s.day).year).toBe(2);
    expect(s.report?.year).toBe(1);
    expect(s.column?.year).toBe(2);
  });
});
