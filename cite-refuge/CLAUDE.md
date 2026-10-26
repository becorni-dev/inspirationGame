# La Cité-Refuge

Jeu de gestion 2.5D en français (TypeScript strict, Vite, PixiJS v8, Vitest). Concept : https://claude.ai/artifact/QrRC7JytoeQoRD9wjAWoH2 (ton sombre, assauts d'hiver animés, fin au Dernier Hiver vers 15 ans, technologie et magie).

Benoit débute en programmation : réponds en français, simplement, par petites étapes, et dis comment voir le résultat (`npm run dev`, quoi cliquer). Ne supprime rien sans le dire avant.

## Règles
- `src/engine/` : règles pures, sans Pixi ni DOM ; jamais `Math.random()`, utiliser `src/engine/rng.ts`.
- `src/engine/game.ts` : la partie (vivres, bois, peuples, logement, travail, hiver, colonnes de réfugiés). `nextDay` fait passer un jour ; l'interface et `npm run balance` utilisent les mêmes fonctions.
- `src/data/*.json` : chiffres et contenu (bâtiments, emplacements, calendrier, `economy.json` pour les règles, `refugees.json` pour les colonnes).
- `src/render/` : dessin Pixi (décor `terrain.ts`, bâtiments `buildings.ts`, scène `scene.ts`). Tout est dessiné par le code ; une image de l'atelier (`public/images/atelier/<id>.png`) pourra remplacer un dessin, qui reste le secours.
- `src/ui/` : interface HTML par-dessus le canvas.
- Chaque règle du moteur a un test dans `tests/`. Avant de pousser : `npm test` et `npm run build` ; après un changement de chiffres, `npm run balance`.
- Plan du jeu (étapes 1 à 6) : dans le dossier de concept. Étapes 1 et 2 faites.
