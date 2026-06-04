# AGENTS.md

## Project

Godot 4 3D farm survival game.

The player explores a rural farm, collects animals, and avoids an enemy called Diablo.

## Main goals

The project must satisfy these evaluation areas:

1. Scenario elements:
   - 3D terrain;
   - structures;
   - obstacles;
   - visual ambience;
   - lighting;
   - sky/fog;
   - interactive objects;
   - visual coherence.

2. Gameplay mechanics:
   - clear objective;
   - lives;
   - score;
   - win/lose conditions;
   - functional controls;
   - up to 3 levels of progression.

## Folder structure

Use:

- assets/models/
- assets/textures/
- assets/materials/
- assets/audio/
- scenes/levels/
- scenes/player/
- scenes/enemies/
- scenes/collectibles/
- scenes/interactives/
- scripts/core/
- scripts/player/
- scripts/enemies/
- scripts/collectibles/
- scripts/interactives/
- docs/
- tools/blender/

## Godot main scene

Main scene:

scenes/levels/main.tscn

## Rules

Do not commit .godot/.

Use Git LFS for large assets.

Do not place all scripts in one folder.

Do not modify main.tscn at the same time as another teammate unless coordinated.

## Required gameplay

- WASD movement.
- Shift run.
- E interact.
- Animal collection.
- Score.
- 3 lives.
- Diablo enemy chase.
- Level 1: rural zone.
- Level 2: lake/planicie.
- Level 3: forest/cave.
- Win after level 3.
- Lose when lives reach 0.

## Required interactives

At least:

- corral door;
- mud trap;
- cave trigger.

## Blender map quality

The farm map must not have:

- flat empty expanded zones;
- props concentrated in one area;
- unrealistic cave;
- overly advanced lake material;
- hard terrain transitions;
- DefaultMaterial on visible objects.

The map must have:

- primary forest;
- planicie;
- lake;
- rural zone;
- cave zone;
- natural paths;
- distributed props;
- coherent low poly materials.
