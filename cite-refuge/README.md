# La Cité-Refuge (prototype 1)

Jeu de gestion en 2.5D : Hautbourg, dernière cité libre au pied des Monts Gris, accueille les peuples qui fuient l'Ombre. Dossier de concept : https://claude.ai/artifact/QrRC7JytoeQoRD9wjAWoH2

Étape 2 : le premier hiver jouable.
- La montagne en coupe et ses quatre zones : la plaine hors des murs (fermes, bûcherons), la cité derrière les remparts, les terrasses taillées dans la falaise, les galeries naines sous terre.
- 8 bâtiments : maison, ferme, bûcheron, grenier, serre, forge naine, tour-phare, hall des peuples. Chacun coûte du bois et a un effet chiffré (fiche au clic, détail au survol).
- Deux peuples, Humains et Nains. Les Nains logent d'abord dans les galeries et sont les seuls à faire tourner les forges.
- Chaque printemps, une colonne de réfugiés arrive aux portes : tu ouvres à tous, seulement aux valides, ou tu gardes les portes fermées.
- L'été et l'automne, on produit et on stocke ; l'hiver, les fermes s'arrêtent, le chauffage brûle du bois, et ceux qui dorment dehors ou ont faim peuvent mourir. Bilan à la fin de chaque hiver.
- Partie sauvegardée automatiquement dans le navigateur (« Reprendre » sur l'écran titre).

## Lancer le jeu

```
cd cite-refuge
npm install      (une seule fois)
npm run dev
```

Ouvrir l'adresse affichée (http://localhost:5173) puis cliquer « Nouvelle partie ».

## Commandes

- Glisser avec la souris : se déplacer. Molette : zoomer. Flèches ou ZQSD aussi.
- Touches 1 à 8 (ou les boutons du bas) : choisir un bâtiment, puis cliquer un emplacement doré. Clic droit ou Échap : annuler.
- Survoler les ressources en haut : le détail de ce qui produit et consomme, par jour.
- Clic sur un bâtiment : sa fiche. Suppr : démolir le bâtiment sous la souris.
- Espace : pause. Boutons ▶ ▶▶ ▶▶▶ : vitesse. « Saison suivante » : sauter à la saison d'après.

## Pour les tests

- `npm test` : tests du moteur (calendrier, cité, vivres, bois, hiver, colonnes).
- `npm run balance` : des joueurs automatiques jouent trois ans (passif, portes fermées, bâtisseur) pour régler les chiffres de `src/data/economy.json`.
- `npm run build` : vérifie que tout compile.
- Adresse avec paramètres : `?t=470&play&speed=0` (heure de jeu 470, soit l'hiver, sans l'écran titre, en pause, en accueillant toutes les colonnes) ; `calm` cache la décision en cours, `keep` garde le bilan de l'hiver, `seed` choisit la graine ; `x`, `y`, `zoom` placent la caméra.
