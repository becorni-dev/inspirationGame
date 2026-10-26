# La Cité-Refuge (prototype 1)

Jeu de gestion en 2.5D : Hautbourg, dernière cité libre au pied des Monts Gris, accueille les peuples qui fuient l'Ombre. Dossier de concept : https://claude.ai/artifact/QrRC7JytoeQoRD9wjAWoH2

Ce premier prototype montre le décor et le temps qui passe, sans vraie gestion encore :
- la montagne en coupe, avec trois zones : la cité au pied des remparts, les terrasses taillées dans la paroi, les galeries naines sous terre ;
- 6 bâtiments (maison, grenier, tour-phare, hall des peuples, serre elfe, forge naine) ;
- les quatre saisons, le jour et la nuit, la neige, la pluie, les fenêtres qui s'allument, la brume de l'Ombre qui avance en hiver.

## Lancer le jeu

```
cd cite-refuge
npm install      (une seule fois)
npm run dev
```

Ouvrir l'adresse affichée (http://localhost:5173) puis cliquer « Entrer dans Hautbourg ».

## Commandes

- Glisser avec la souris : se déplacer. Molette : zoomer. Flèches ou ZQSD aussi.
- Touches 1 à 6 (ou les boutons du bas) : choisir un bâtiment, puis cliquer un emplacement doré. Clic droit ou Échap : annuler.
- Clic sur un bâtiment : sa fiche. Suppr : démolir le bâtiment sous la souris.
- Espace : pause. Boutons ▶ ▶▶ ▶▶▶ : vitesse. « Saison suivante » : sauter à la saison d'après.

## Pour les tests

- `npm test` : tests du moteur (calendrier, cité).
- `npm run build` : vérifie que tout compile.
- Adresse avec paramètres : `?t=470&play&speed=0` (heure de jeu 470, soit l'hiver, sans l'écran titre, en pause) ; `x`, `y`, `zoom` placent la caméra.
