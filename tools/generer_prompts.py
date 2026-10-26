"""Régénère docs/prompts-gemini.md à partir de atelier/manifest.json.

Lancer depuis le dossier du projet :  python tools/generer_prompts.py
"""
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
manifest = json.loads((root / "atelier" / "manifest.json").read_text(encoding="utf-8"))
lines = [
    "# Prompts Gemini (Nano Banana) pour Nouvelle Rive",
    "",
    "Fichier généré par `python tools/generer_prompts.py` à partir de `atelier/manifest.json`.",
    "Le plus simple : ouvrir l'Atelier d'images dans le jeu (touche I), copier le prompt, générer dans Gemini,",
    "copier l'image et cliquer « Coller l'image ». Le jeu recadre, réduit, rend raccordable et applique.",
    "",
]
for kind, title in (("texture", "Textures (sol, routes, murs)"), ("icon", "Icônes de la barre d'outils")):
    lines += [f"## {title}", ""]
    for e in manifest["entries"]:
        if e["kind"] != kind:
            continue
        lines += [
            f"### {e['name']} (`{e['id']}`, {e['size']} × {e['size']} px)",
            "",
            e["usage"],
            "",
            "```",
            e["prompt"],
            "```",
            "",
        ]
(root / "docs" / "prompts-gemini.md").write_text("\n".join(lines), encoding="utf-8")
print("docs/prompts-gemini.md écrit :", len(manifest["entries"]), "images")
