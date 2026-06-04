---
name: blender-godot-export-validator
description: Validate Blender scene before GLB export for Godot 4: naming, scale, materials, spawns, geometry, and compatibility.
---

# Blender Godot Export Validator

Before export:
- check scale;
- check collection organization;
- check object names;
- check visible materials;
- check no external material dependencies;
- check no unnecessary hidden junk;
- check transforms reasonable;
- check terrain/lake/river/cave exist;
- check spawns exist;
- check review cameras exist.

Required main names:
- Mtn_Main
- Lake_Main
- River_Main
- Mini_Cueva or Cave_Main
- Sp_Player
- Sp_Diablo
- Sp_An01..Sp_An24

Export:
- save .blend;
- export .glb;
- report paths;
- reopen/check exported file if possible.

Reject:
- no GLB;
- missing spawns;
- shader complexity;
- broken scale;
- bad naming.
