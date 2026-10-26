# Nouvelle Rive (inspirationGame)

Prototype de jeu de gestion et de construction en 3D (city builder sur une île) avec **Godot 4.7** (Forward+, GDScript). Tout le jeu est en français. Benoit débute en programmation et construit en « vibe coding » : réponds en français, simplement, par petites étapes, et dis toujours comment voir le résultat (ouvrir le projet dans Godot, F5, quoi cliquer).

## Règles

- Tout est créé par le code depuis `scripts/main.gd` (une seule scène `main.tscn`) : pas de scène éditée à la main, pour que Claude puisse tout écrire en texte.
- Scripts reliés par `preload` (pas de `class_name`). Attention à `:=` sur une valeur Variant (dictionnaire, tableau non typé) : écrire le type (`var x: float = d["k"]`).
- Les règles de l'économie (`scripts/city/economy.gd`) ne connaissent pas l'affichage.
- Chiffres de gameplay dans `data/buildings.json`.
- Toute nouvelle image passe par l'atelier : entrée dans `atelier/manifest.json` (prompt en anglais), puis `python tools/generer_prompts.py`. Le jeu doit toujours marcher sans l'image (dessin procédural de secours).
- Couleurs de l'interface dans `scripts/ui/style.gd` (thème sombre, ambre `ACCENT`, bleu plan `BLUEPRINT`).
- Paramètres globaux des shaders (`night`, `wind_strength`) déclarés dans `project.godot`, section `[shader_globals]`.

## Vérifier

Le cloud n'a ni Godot ni carte graphique. Avant de pousser : `pip install gdtoolkit` puis `gdparse` sur chaque fichier `.gd` (syntaxe). Le rendu et les erreurs d'exécution sont vus par Benoit (capture d'écran, texte rouge des panneaux Sortie et Débogueur).
