import { describe, expect, it } from "vitest";
import { HOURS_PER_YEAR, daylight, shadowReach, snowCover, view } from "../src/engine/calendar";

describe("calendrier", () => {
  it("commence au printemps de l'an 1", () => {
    const v = view({ hours: 0 });
    expect(v.year).toBe(1);
    expect(v.season.id).toBe("printemps");
    expect(v.dayOfSeason).toBe(1);
  });

  it("enchaîne les quatre saisons puis change d'année", () => {
    const q = HOURS_PER_YEAR / 4;
    expect(view({ hours: q + 1 }).season.id).toBe("ete");
    expect(view({ hours: 2 * q + 1 }).season.id).toBe("automne");
    expect(view({ hours: 3 * q + 1 }).season.id).toBe("hiver");
    expect(view({ hours: HOURS_PER_YEAR + 1 }).year).toBe(2);
  });

  it("fait nuit à minuit et jour à midi", () => {
    expect(daylight(view({ hours: 0 }))).toBe(0);
    expect(daylight(view({ hours: 13 }))).toBeGreaterThan(0.9);
  });

  it("couvre de neige en fin d'hiver et la fait fondre au printemps", () => {
    const q = HOURS_PER_YEAR / 4;
    expect(snowCover(view({ hours: 4 * q - 1 }))).toBe(1);
    expect(snowCover(view({ hours: q + 10 }))).toBe(0);
    expect(snowCover(view({ hours: HOURS_PER_YEAR + q * 0.5 }))).toBe(0);
  });

  it("rapproche l'Ombre des remparts en hiver", () => {
    const q = HOURS_PER_YEAR / 4;
    expect(shadowReach(view({ hours: 3 * q + 2 }))).toBeGreaterThan(shadowReach(view({ hours: q + 2 })));
  });
});
