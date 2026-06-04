# CLAUDE.md

## Project

Godot 4 3D farm survival game.

The player explores a rural farm, collects animals, and avoids Diablo.

## Communication

Always use `/caveman` style for normal conversation:
- short;
- direct;
- technical;
- no filler;
- verify before claiming.

Do not use caveman style inside:
- code;
- README;
- commit messages;
- user-facing documents;
- reports that must be professional.

## Required skills

For Blender map work, use:
- /caveman
- /blender-level-design-qa
- /blender-lowpoly-biomes
- /blender-terrain-worldbuilder
- /blender-prop-distribution
- /blender-cave-designer
- /blender-material-audit
- /blender-godot-export-validator

For Godot work, use:
- /caveman
- /godot-3d-import-pipeline
- /godot-gameplay-spawn-system

For repository work, use:
- /caveman
- /git-godot-team-workflow

## Rules

Do not claim success without verification.

Before changing files:
1. run `pwd`;
2. run `git status`;
3. inspect files;
4. make a plan;
5. ask only if blocked.

After changing files:
1. run validation;
2. report changed files;
3. report commands used;
4. report remaining risks.

## Do not commit

- .godot/
- .import/
- exports/*
- builds/*
- local AI/MCP addons
- Blender temp files

## Main map goals

The farm map must have:
- 20ha approximate scale;
- high mountain;
- cave inside mountain;
- lake with 10m geometric depth;
- river with 3m geometric depth along the course;
- natural river flow from mountain to lake;
- rural zone;
- primary forest;
- open plain;
- coherent low poly materials;
- no complex external texture dependencies;
- short clean object names;
- Godot-ready GLB export.

## Main gameplay goals

The Godot project must have:
- main.tscn;
- Player;
- Diablo;
- GameManager;
- UI;
- SpawnPoints;
- animals;
- interactives;
- WASD movement;
- Shift run;
- E interact;
- 3 lives;
- score;
- 3 levels;
- win/lose conditions.
