import { describe, expect, it } from "vitest";
import { SLOTS, build, canBuild, demolish, startingCity } from "../src/engine/city";

describe("cité", () => {
  it("numérote les emplacements par zone", () => {
    expect(SLOTS.filter((s) => s.zone === "plaine")).toHaveLength(6);
    expect(SLOTS.filter((s) => s.zone === "cite")).toHaveLength(10);
    expect(SLOTS.filter((s) => s.zone === "terrasses")).toHaveLength(8);
    expect(SLOTS.filter((s) => s.zone === "galeries")).toHaveLength(13);
  });

  it("pose la cité de départ", () => {
    const c = startingCity();
    expect(Object.keys(c.buildings).length).toBe(15);
    expect(Object.values(c.buildings).filter((b) => b.type === "ferme")).toHaveLength(2);
  });

  it("refuse une forge hors des galeries et un emplacement occupé", () => {
    const c = startingCity();
    expect(canBuild(c, "cite-3", "forge")).toMatch(/galeries/);
    expect(canBuild(c, "cite-1", "maison")).toBe("Emplacement déjà occupé");
    expect(canBuild(c, "cite-3", "maison")).toBe("");
  });

  it("construit et démolit sans modifier l'état d'origine", () => {
    const c = startingCity();
    const c2 = build(c, "cite-3", "grenier", 5);
    expect(c2.buildings["cite-3"].type).toBe("grenier");
    expect(c.buildings["cite-3"]).toBeUndefined();
    expect(demolish(c2, "cite-3").buildings["cite-3"]).toBeUndefined();
  });
});
