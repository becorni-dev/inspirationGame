// Équilibrage : joue plusieurs premières années avec des joueurs automatiques simples.
// npm run balance
import { SLOTS } from "../src/engine/city";
import { type ColumnChoice, type GameState, answerColumn, buildError, construct, dayInfo, housing, newGame, nextDay, population, winterNeeds } from "../src/engine/game";

type Policy = { name: string; choice: ColumnChoice; builder: boolean };
const policies: Policy[] = [
  { name: "passif, accueille tout", choice: "tous", builder: false },
  { name: "passif, portes fermées", choice: "personne", builder: false },
  { name: "bâtisseur, accueille tout", choice: "tous", builder: true },
  { name: "bâtisseur, valides seulement", choice: "valides", builder: true },
];

function tryBuild(s: GameState, type: string): GameState {
  for (const slot of SLOTS) if (!buildError(s, slot.id, type)) return construct(s, slot.id, type, 0);
  return s;
}

// Un joueur simple : des maisons pour les sans-abri, des fermes et du bois tant qu'il en manque pour l'hiver
function play(s: GameState): GameState {
  const si = dayInfo(s.day).seasonIndex;
  if (si === 3) return s;
  const need = winterNeeds(s);
  const h = housing(s);
  const homeless = h.homeless.humain + h.homeless.nain;
  if (si < 2 && s.food + 40 < need.food * 1.3) s = tryBuild(s, "ferme");
  if (s.wood > need.wood + 25 && homeless > 0) s = tryBuild(s, "maison");
  if (si === 0 && s.wood < 40) s = tryBuild(s, "bucheron");
  return s;
}

for (const p of policies) {
  const rows: string[] = [];
  for (let seed = 1; seed <= 6; seed++) {
    let s = newGame(seed);
    for (let d = 0; d < 24 * 3; d++) {
      if (s.column) s = answerColumn(s, p.choice);
      if (p.builder) s = play(s);
      s = nextDay(s);
      if (s.report) {
        rows.push(`  graine ${seed}, hiver ${s.report.year} : froid ${s.report.cold}, faim ${s.report.hunger}, blessures ${s.report.wounds}, ${s.report.survivors} survivants, reste ${s.report.food} vivres et ${s.report.wood} bois`);
        s = { ...s, report: null };
      }
    }
    rows.push(`  graine ${seed}, fin an 3 : ${population(s)} habitants, ${Object.keys(s.city.buildings).length} bâtiments`);
  }
  console.log(`\n${p.name}\n${rows.join("\n")}`);
}
