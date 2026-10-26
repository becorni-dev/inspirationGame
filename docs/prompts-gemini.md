# Prompts Gemini (Nano Banana) pour Nouvelle Rive

Fichier généré par `python tools/generer_prompts.py` à partir de `atelier/manifest.json`.
Le plus simple : ouvrir l'Atelier d'images dans le jeu (touche I), copier le prompt, générer dans Gemini,
copier l'image et cliquer « Coller l'image ». Le jeu recadre, réduit, rend raccordable et applique.

## Textures (sol, routes, murs)

### Sol : herbe (`terrain_herbe`, 1024 × 1024 px)

Herbe du plateau et des collines (shader du terrain)

```
Lush temperate meadow grass ground seen from directly above, short mixed grass blades with small clover, a few dry yellow blades and tiny wildflowers, natural variation. Seamless tileable texture, perfectly repeating on all four edges, viewed straight from above, orthographic, flat even overcast lighting, no cast shadows, no perspective, no objects, no text, photorealistic, physically accurate colors, high detail, square format, 2K or 4K resolution.
```

### Sol : roche (`terrain_roche`, 1024 × 1024 px)

Pentes raides des montagnes

```
Grey granite mountain rock surface seen from directly above, cracks, lichen spots, weathered stone, natural variation. Seamless tileable texture, perfectly repeating on all four edges, viewed straight from above, orthographic, flat even overcast lighting, no cast shadows, no perspective, no objects, no text, photorealistic, physically accurate colors, high detail, square format, 2K or 4K resolution.
```

### Sol : sable (`terrain_sable`, 1024 × 1024 px)

Plages et bords de l'eau

```
Fine golden beach sand seen from directly above, subtle wind ripples, a few tiny shells and pebbles. Seamless tileable texture, perfectly repeating on all four edges, viewed straight from above, orthographic, flat even overcast lighting, no cast shadows, no perspective, no objects, no text, photorealistic, physically accurate colors, high detail, square format, 2K or 4K resolution.
```

### Sol : neige (`terrain_neige`, 1024 × 1024 px)

Sommets enneigés

```
Fresh compact mountain snow surface seen from directly above, soft wind-blown texture, subtle blue tint in hollows. Seamless tileable texture, perfectly repeating on all four edges, viewed straight from above, orthographic, flat even overcast lighting, no cast shadows, no perspective, no objects, no text, photorealistic, physically accurate colors, high detail, square format, 2K or 4K resolution.
```

### Route : asphalte (`route_asphalte`, 1024 × 1024 px)

Chaussée des routes (le marquage reste dessiné par le jeu)

```
Dark grey urban asphalt road surface seen from directly above, fine aggregate, small cracks and patches, no road markings. Seamless tileable texture, perfectly repeating on all four edges, viewed straight from above, orthographic, flat even overcast lighting, no cast shadows, no perspective, no objects, no text, photorealistic, physically accurate colors, high detail, square format, 2K or 4K resolution.
```

### Mur : maison (`mur_maison`, 1024 × 1024 px)

Murs des maisons (teinte ajoutée par le jeu)

```
Light cream painted lime plaster wall of a European house, subtle trowel marks, faint stains. Seamless tileable texture, perfectly repeating on all four edges, front orthographic view of a flat wall surface, flat even lighting, no windows, no doors, no perspective, no text, photorealistic, square format, 2K resolution.
```

### Mur : immeuble (`mur_immeuble`, 1024 × 1024 px)

Murs des immeubles

```
Modern light grey architectural precast concrete panel wall, thin panel joints, subtle water stains. Seamless tileable texture, perfectly repeating on all four edges, front orthographic view of a flat wall surface, flat even lighting, no windows, no doors, no perspective, no text, photorealistic, square format, 2K resolution.
```

### Mur : commerce (`mur_commerce`, 1024 × 1024 px)

Murs des commerces

```
Warm red-brown brick wall with light mortar joints, slightly weathered bricks. Seamless tileable texture, perfectly repeating on all four edges, front orthographic view of a flat wall surface, flat even lighting, no windows, no doors, no perspective, no text, photorealistic, square format, 2K resolution.
```

### Mur : usine (`mur_usine`, 1024 × 1024 px)

Murs de l'usine

```
Industrial corrugated steel cladding wall, vertical ribs, light grey paint with rust streaks. Seamless tileable texture, perfectly repeating on all four edges, front orthographic view of a flat wall surface, flat even lighting, no windows, no doors, no perspective, no text, photorealistic, square format, 2K resolution.
```

### Feuillage (`feuillage`, 512 × 512 px)

Feuilles des arbres (mélangée à leur couleur)

```
Dense green tree foliage canopy seen from directly above, overlapping leaves, natural light and dark green variation. Seamless tileable texture, perfectly repeating on all four edges, viewed straight from above, orthographic, flat even overcast lighting, no cast shadows, no perspective, no objects, no text, photorealistic, physically accurate colors, high detail, square format, 2K or 4K resolution.
```

## Icônes de la barre d'outils

### Icône : route (`icone_road`, 512 × 512 px)

Bouton de la barre d'outils

```
Game interface icon: a miniature 3D model of a short asphalt road crossing with white markings and a tiny street lamp, three-quarter isometric view from above, centered, occupying 70 percent of the frame, on a plain very dark blue-black background (#0c1014) with a subtle soft amber rim light, photorealistic miniature, tilt-shift look, crisp details, no text, no border, square format, 1K resolution.
```

### Icône : maison (`icone_house`, 512 × 512 px)

Bouton de la barre d'outils

```
Game interface icon: a miniature 3D model of a small cozy European suburban house with a pitched terracotta roof and a tiny garden hedge, three-quarter isometric view from above, centered, occupying 70 percent of the frame, on a plain very dark blue-black background (#0c1014) with a subtle soft amber rim light, photorealistic miniature, tilt-shift look, crisp details, no text, no border, square format, 1K resolution.
```

### Icône : immeuble (`icone_tower`, 512 × 512 px)

Bouton de la barre d'outils

```
Game interface icon: a miniature 3D model of a modern residential apartment tower with many lit windows, three-quarter isometric view from above, centered, occupying 70 percent of the frame, on a plain very dark blue-black background (#0c1014) with a subtle soft amber rim light, photorealistic miniature, tilt-shift look, crisp details, no text, no border, square format, 1K resolution.
```

### Icône : commerce (`icone_shop`, 512 × 512 px)

Bouton de la barre d'outils

```
Game interface icon: a miniature 3D model of a small corner shop with a glowing neon sign and a striped awning, three-quarter isometric view from above, centered, occupying 70 percent of the frame, on a plain very dark blue-black background (#0c1014) with a subtle soft amber rim light, photorealistic miniature, tilt-shift look, crisp details, no text, no border, square format, 1K resolution.
```

### Icône : usine (`icone_factory`, 512 × 512 px)

Bouton de la barre d'outils

```
Game interface icon: a miniature 3D model of a compact factory with a sawtooth roof and two smoking chimneys, three-quarter isometric view from above, centered, occupying 70 percent of the frame, on a plain very dark blue-black background (#0c1014) with a subtle soft amber rim light, photorealistic miniature, tilt-shift look, crisp details, no text, no border, square format, 1K resolution.
```

### Icône : éolienne (`icone_wind`, 512 × 512 px)

Bouton de la barre d'outils

```
Game interface icon: a miniature 3D model of a modern white wind turbine on a small grassy hill, three-quarter isometric view from above, centered, occupying 70 percent of the frame, on a plain very dark blue-black background (#0c1014) with a subtle soft amber rim light, photorealistic miniature, tilt-shift look, crisp details, no text, no border, square format, 1K resolution.
```

### Icône : centrale solaire (`icone_solar`, 512 × 512 px)

Bouton de la barre d'outils

```
Game interface icon: a miniature 3D model of a small solar farm with rows of tilted photovoltaic panels, three-quarter isometric view from above, centered, occupying 70 percent of the frame, on a plain very dark blue-black background (#0c1014) with a subtle soft amber rim light, photorealistic miniature, tilt-shift look, crisp details, no text, no border, square format, 1K resolution.
```

### Icône : parc (`icone_park`, 512 × 512 px)

Bouton de la barre d'outils

```
Game interface icon: a miniature 3D model of a small city park with a round fountain, trees and paths, three-quarter isometric view from above, centered, occupying 70 percent of the frame, on a plain very dark blue-black background (#0c1014) with a subtle soft amber rim light, photorealistic miniature, tilt-shift look, crisp details, no text, no border, square format, 1K resolution.
```
