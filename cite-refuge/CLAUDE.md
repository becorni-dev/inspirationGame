# La Cité-Refuge

Jeu de gestion 2.5D en français (TypeScript strict, Vite, PixiJS v8, Vitest). Concept : https://claude.ai/artifact/QrRC7JytoeQoRD9wjAWoH2 (ton sombre, assauts d'hiver animés, fin au Dernier Hiver vers 15 ans, technologie et magie).

Benoit débute en programmation : réponds en français, simplement, par petites étapes, et dis comment voir le résultat (`npm run dev`, quoi cliquer). Ne supprime rien sans le dire avant.

## Règles
- `src/engine/` : règles pures, sans Pixi ni DOM ; jamais `Math.random()`, utiliser `src/engine/rng.ts`.
- `src/data/*.json` : chiffres et contenu (bâtiments, emplacements, calendrier).
- `src/render/` : dessin Pixi (décor `terrain.ts`, bâtiments `buildings.ts`, scène `scene.ts`). Tout est dessiné par le code ; une image de l'atelier (`public/images/atelier/<id>.png`) pourra remplacer un dessin, qui reste le secours.
- `src/ui/` : interface HTML par-dessus le canvas.
- Chaque règle du moteur a un test dans `tests/`. Avant de pousser : `npm test` et `npm run build`.
