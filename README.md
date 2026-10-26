# Nouvelle Rive

Prototype de jeu de gestion et de construction en 3D, fait avec le moteur **Godot 4.7**.
On bâtit une ville sur une île : routes, maisons, immeubles, commerces, usines, éoliennes, panneaux solaires et parcs.
Chaque bâtiment a un effet chiffré (habitants, emplois, électricité, bonheur, argent), le jour se lève et la nuit s'allume.

Pourquoi Godot : voir [docs/comparatif-moteurs.md](docs/comparatif-moteurs.md).

## Installer (une seule fois)

1. Télécharger **Godot 4.7** version **standard** (pas « .NET ») pour Windows : https://godotengine.org/download/windows/
2. Décompresser le fichier zip où tu veux (par exemple `C:\Godot\`). Il n'y a rien d'autre à installer.
3. Récupérer ce dépôt sur ton PC (GitHub Desktop : *Clone* `becorni-dev/inspirationGame`, puis la branche indiquée par Claude).

## Lancer le jeu

1. Ouvrir `Godot_v4.7-stable_win64.exe`.
2. Dans le gestionnaire de projets : **Importer**, choisir le fichier `project.godot` de ce dossier, puis **Importer et modifier**.
3. La première ouverture prend une minute (Godot prépare les shaders).
4. Appuyer sur **F5** (ou le bouton ▶ en haut à droite). Le jeu s'ouvre sur l'écran titre, cliquer **Jouer**.

Si quelque chose ne marche pas : en bas de l'éditeur, onglets **Sortie** et **Débogueur** ; copier le texte rouge et l'envoyer à Claude.

## Commandes

| Touche | Action |
| --- | --- |
| Z Q S D ou flèches | déplacer la vue (Maj : plus vite) |
| A / E, clic droit glissé | tourner la vue |
| Molette | zoomer |
| R, 1 à 7 | route, maison, immeuble, commerce, usine, éolienne, centrale solaire, parc |
| B | démolir (rend la moitié du prix) |
| Clic gauche | construire ; sans outil, ouvrir la fiche d'un bâtiment |
| Échap | lâcher l'outil |
| Espace, Tab | pause, vitesse |
| N | avancer de 3 heures (pour voir la nuit) |
| P | mode photo (caméra qui tourne, bandes noires) |
| O | effet maquette (flou de profondeur) |
| G | qualité graphique : Ultra, Élevée, Moyenne |
| I | atelier d'images |
| H | aide |

## Les règles du prototype

- Un bâtiment ne fonctionne que s'il **touche une route**.
- Les habitants arrivent si la ville est attirante : **bonheur** (parcs proches, pas de pollution), **emplois** et **électricité** suffisante.
- Les éoliennes produisent selon le vent, le solaire seulement le jour.
- L'immeuble se débloque à 60 habitants.
- Tous les chiffres sont dans [`data/buildings.json`](data/buildings.json), modifiables sans toucher au code.
- Survoler les chiffres en haut de l'écran donne le détail des calculs.

## Atelier d'images (Gemini)

Le jeu tourne sans aucune image : sol, eau, ciel, arbres, bâtiments et voitures sont dessinés par le code.
Chaque image qui peut l'améliorer est listée dans [`atelier/manifest.json`](atelier/manifest.json) avec son prompt (liste lisible : [docs/prompts-gemini.md](docs/prompts-gemini.md)).

1. Dans le jeu, touche **I** (ou bouton « Atelier d'images »).
2. **Copier le prompt**, le coller dans Gemini (Nano Banana), générer.
3. Dans Gemini, clic droit sur l'image, **Copier l'image**.
4. Dans l'atelier, **Coller l'image** (ou « Choisir un fichier… »).
5. L'image est recadrée, réduite, rendue raccordable (textures) et rangée dans `atelier/images/`. Elle apparaît tout de suite dans le jeu. Il reste à faire un commit de `atelier/images/` pour la garder.

## Organisation

```
project.godot          réglages du projet (rendu Forward+, anticrénelage, paramètres globaux des shaders)
main.tscn              la seule scène : tout le reste est créé par scripts/main.gd
scripts/main.gd        chef d'orchestre : monde, ville, caméra, interface, commandes
scripts/world/         relief, ciel et cycle jour/nuit, forêts, voiliers, outil de maillage
scripts/city/          grille et bâtiments, économie (règles pures), apparence des bâtiments, circulation
scripts/ui/            interface (barre du haut, outils, fiche, aide, écran titre) et thème
scripts/atelier/       atelier d'images
shaders/               sol, eau, ciel, bâtiments, routes, feuillage, aperçu holographique
data/buildings.json    les bâtiments et l'économie
atelier/               manifeste des images et images déposées
docs/                  comparatif des moteurs, prompts Gemini
```
