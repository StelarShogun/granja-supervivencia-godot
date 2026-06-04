---
name: godot-3d-import-pipeline
description: Import GLB map into Godot 4 and create a playable 3D scene with lighting, collision, player, UI, spawns, and environment.
---

# Godot 3D Import Pipeline

Project structure:
- assets/models/environment/
- scenes/levels/
- scenes/player/
- scenes/enemies/
- scenes/animals/
- scenes/interactives/
- scripts/

Main scene must contain:
- WorldEnvironment
- SunLight
- Level
- SpawnPoints
- Player
- Diablo
- GameManager
- InteractiveObjects
- UI

Import rules:
- put GLB in assets/models/environment/;
- instance in scenes/levels/main.tscn;
- create collision for terrain/large objects first;
- avoid collision on every tiny prop initially;
- add camera and light;
- verify project.godot main_scene.

Do not modify Blender asset unless asked.
