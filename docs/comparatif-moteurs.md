# Quel moteur pour notre premier jeu de gestion en 3D ?

Contexte : Benoit décrit, Claude écrit le code (« vibe coding »). Il faut donc un moteur où **tout le jeu tient dans des fichiers texte** que Claude peut lire et modifier, qui soit **simple à installer** sur un PC Windows, gratuit, et capable d'un rendu impressionnant sur une carte graphique de 8 Go.

| Moteur | Langage | Ce qui est bien | Ce qui coince pour nous | Verdict |
| --- | --- | --- | --- | --- |
| **Godot 4.7** | GDScript (proche de Python) | Gratuit et libre, 120 Mo, rien à installer (un .exe à décompresser). Scènes, scripts et shaders en texte. Rendu Forward+ : éclairage global dynamique (SDFGI), brouillard volumétrique, ombres douces, reflets. Export Windows en un clic. | Moins de rendu « photo » qu'Unreal ; moins de boutique d'assets qu'Unity. | **Retenu** |
| Unity 6 | C# | Énorme communauté, beaucoup de tutoriels de city builder. | Installation lourde (Hub, compte, plusieurs Go), scènes difficiles à éditer en texte, licence qui a déjà changé brusquement. | Possible, plus lourd |
| Unreal Engine 5 | C++ / Blueprints | Le plus beau rendu (Lumen, Nanite). | 50 Go à installer, Blueprints visuels que Claude ne peut pas écrire, C++ long à compiler, exigeant même avec 8 Go. | Trop lourd pour débuter |
| Bevy | Rust | Tout en code, très moderne. | Pas d'éditeur, compilation lente, moteur encore jeune : beaucoup à réinventer. | Trop tôt |
| Three.js / Babylon.js | TypeScript (web) | Ce qu'on fait déjà, rien de nouveau à apprendre. | Ce n'est pas un vrai moteur de jeu : pas d'éditeur, rendu plus limité, c'est justement ce qu'on veut dépasser. | On garde pour les jeux web |

## Pourquoi Godot est le plus simple pour commencer

- On télécharge, on décompresse, on double-clique : pas de compte, pas d'installateur.
- GDScript ressemble à Python : facile à lire pour suivre ce que Claude écrit.
- Le projet entier (scènes, shaders, données JSON) est du texte : Claude peut tout créer et corriger, Benoit voit le résultat avec F5.
- Le rendu Forward+ exploite bien une carte de 8 Go : c'est ce que montre le prototype (île, mer, cycle jour et nuit, fenêtres allumées, fumée, trafic).
- Plus tard : export en `.exe` Windows, et si un jour on veut aller plus loin, Godot accepte aussi le C#.

## Limite connue

Claude travaille dans le cloud sans carte graphique : il vérifie la syntaxe du code, mais **c'est Benoit qui voit le rendu**. Le plus efficace : lancer le jeu, puis envoyer une capture d'écran ou copier le texte rouge du panneau « Sortie » / « Débogueur » de Godot si quelque chose ne va pas.
