---
name: godot-gameplay-spawn-system
description: Implement farm survival gameplay in Godot: player movement, animal collection, Diablo enemy, UI, lives, score, 3 levels, and interactives.
---

# Godot Gameplay Spawn System

Required gameplay:
- WASD move;
- Shift run;
- E interact;
- collect animals;
- score +100;
- 3 lives;
- Diablo chases player;
- lose at 0 lives;
- win after level 3.

Levels:
- Level 1: rural, 5 animals, slow Diablo.
- Level 2: plain/lake, 8 animals, medium Diablo.
- Level 3: forest/cave, 10 animals, faster Diablo.

Required scripts:
- scripts/player/player.gd
- scripts/enemies/diablo.gd
- scripts/animals/animal.gd
- scripts/managers/game_manager.gd
- scripts/interactives/puerta_corral.gd
- scripts/interactives/trampa_barro.gd
- scripts/interactives/entrada_cueva.gd

Required UI:
- lives;
- score;
- collected/goal;
- level;
- message.

Do not overbuild. Make playable first.
