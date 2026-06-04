---
name: git-godot-team-workflow
description: Keep Godot repo clean for team work: Git LFS, .gitignore, branches, commits, and conflict prevention.
---

# Git Godot Team Workflow

Do not commit:
- .godot/
- .import/
- exports/*
- builds/*
- Blender temp files
- local AI/MCP addons unless required

Use Git LFS for:
- .glb
- .gltf
- .fbx
- .blend
- .png
- .jpg
- .jpeg
- .webp
- .wav
- .mp3
- .ogg

Workflow:
- git status before edits;
- branch per task;
- small commits;
- pull before work;
- avoid multiple people editing main.tscn together.

Branches:
- mapa-blender
- base-jugable-godot
- mecanicas-juego
- escenario-ambientacion
- interactivos
- bugfix
