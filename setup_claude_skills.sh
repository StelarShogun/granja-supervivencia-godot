#!/usr/bin/env bash
set -euo pipefail

mkdir -p .claude/skills/{caveman,blender-level-design-qa,blender-lowpoly-biomes,blender-terrain-worldbuilder,blender-prop-distribution,blender-cave-designer,blender-material-audit,blender-godot-export-validator,godot-3d-import-pipeline,godot-gameplay-spawn-system,git-godot-team-workflow}

cat > .claude/skills/caveman/SKILL.md <<'EOF'
---
name: caveman
description: Ultra-concise technical mode. Always use when user asks for efficiency, verification, Blender/Godot work, repo cleanup, or long agentic tasks.
---

# Caveman Mode

Speak short. No filler. No motivational text.

Rules:
- Tool first.
- Verify before claim.
- Say facts only.
- Use checklists.
- Use paths.
- Use commands.
- No essays.
- No "should probably".
- If unsure, inspect.
- If task modifies files, report files changed.
- Code, file contents, commit messages, and user-facing docs must remain normal professional language.
- Do not degrade technical accuracy.
- Do not omit required steps.
- For long tasks: Plan → Execute → Verify → Report.
EOF

cat > .claude/skills/blender-level-design-qa/SKILL.md <<'EOF'
---
name: blender-level-design-qa
description: Strict QA for Blender game levels. Use before and after editing terrain, props, biomes, caves, lakes, rivers, spawns, and exported GLB files.
---

# Blender Level Design QA

Use this before claiming any Blender map is finished.

Workflow:
1. Open/inspect scene.
2. Measure bounding box.
3. List collections.
4. Count objects/materials.
5. Identify flat empty zones.
6. Identify hard rectangular biome cuts.
7. Identify prop clusters.
8. Inspect cave from player height.
9. Inspect lake/river from aerial and player height.
10. Inspect structures for scale/location.
11. Inspect spawns.
12. Inspect materials/shading.
13. Create/update review cameras.
14. Export only after visual and technical checks pass.

Reject if:
- terrain is mostly flat patches;
- river looks painted, floating, or broken;
- lake is not integrated;
- cave looks like black block;
- structures look random or oversized;
- props are clustered in one zone;
- spawns are inside water/rocks/trees/fences;
- visible DefaultMaterial exists;
- GLB depends on external textures;
- no validation report.

Required cameras:
- Cam_Air
- Cam_Rural
- Cam_Plain
- Cam_Forest
- Cam_Lake
- Cam_Cave
- Cam_Path

Final report:
- file used;
- scale;
- problems found;
- fixes;
- remaining risks;
- exported paths.
EOF

cat > .claude/skills/blender-lowpoly-biomes/SKILL.md <<'EOF'
---
name: blender-lowpoly-biomes
description: Build coherent low poly biomes for the farm map: mountain, cave, lake, river, forest, plain, rural zone, paths, and transitions.
---

# Low Poly Biomes

Required biomes:
- Main mountain
- Cave zone
- Lake zone
- River corridor
- Primary forest
- Open plain
- Rural/productive farm
- Transition paths

Rules:
- No square biome patches.
- Use gradual transitions.
- Vary scale/rotation of repeated assets.
- Keep low poly.
- Use simple materials.
- Leave walkable paths.

Mountain:
- dominant high landmark;
- broad base;
- cave embedded in slope;
- river/source connection;
- rocks and sparse vegetation.

Forest:
- tall/medium/small trees;
- bushes;
- undergrowth;
- logs;
- rocks;
- dark humid ground;
- narrow paths.

Plain:
- open visibility;
- subtle low hills;
- short grass;
- small props only;
- good chase space.

Lake:
- 10 m geometric depth;
- simple water material;
- muddy shore;
- rocks/reeds/logs;
- connected to river.

River:
- 3 m geometric depth along full course;
- continuous channel;
- natural curves;
- simple water;
- wet banks.

Rural:
- barn/shed/coop/corral/fences;
- hay, barrels, crates, tools;
- logical subzones;
- paths between structures.
EOF

cat > .claude/skills/blender-terrain-worldbuilder/SKILL.md <<'EOF'
---
name: blender-terrain-worldbuilder
description: Rebuild and validate terrain relief for the 20ha farm map, including mountain, lake basin, river channel, paths, slopes, and transitions.
---

# Terrain Worldbuilder

Scale:
- Target: 20 hectares.
- Approx: 447 m x 447 m.
- Do not rescale blindly. Measure bounding box first.

Required terrain:
- high mountain opposite lake side;
- cave embedded in mountain;
- lake basin 10 m deep;
- river channel 3 m deep entire route;
- open plain;
- rural mid/low area;
- forested area;
- natural transitions.

Terrain rules:
- No giant flat squares.
- No hard rectangular patches.
- No painted-only river.
- No floating water.
- No cliff unless intentional.
- Keep player-walkable routes.
- Low poly, not high subdivision.

Use:
- broad slopes;
- soft ridges;
- shallow depressions;
- irregular paths;
- microrelief;
- rocks/grass/soil patches for transitions.

Validation:
- measure depth lake;
- measure depth river;
- inspect from aerial;
- inspect from player height.
EOF

cat > .claude/skills/blender-prop-distribution/SKILL.md <<'EOF'
---
name: blender-prop-distribution
description: Redistribute farm, forest, lake, river, mountain, cave, and rural props logically across a Blender game map.
---

# Prop Distribution

Goal: no single prop pile.

Required points of interest:
- rural tool area;
- hay/storage near barn;
- corral animal area;
- bebedero in plain;
- broken fence on path;
- wood pile near forest;
- logs/rocks near cave;
- shore props near lake;
- small rest/fishing area;
- forest clearing.

Zone logic:
- Rural: hay, crates, barrels, tools, fences, coop, barn, shed, troughs.
- Forest: trees, logs, stumps, rocks, bushes, tall grass.
- Plain: low props, small rocks, sparse bushes, partial fences.
- Lake/River: rocks, mud, reeds, logs, wet grass.
- Cave/Mountain: large rocks, dark soil, sparse wild vegetation.

Validation:
- top view density;
- player-height view;
- no floating/buried props;
- no blocked main paths.
EOF

cat > .claude/skills/blender-cave-designer/SKILL.md <<'EOF'
---
name: blender-cave-designer
description: Create or repair a believable low poly cave integrated into a mountain or slope, not a black block.
---

# Cave Designer

Required:
- name main cave object/collection: Mini_Cueva or Cave_Main;
- marker: Zn_Cave or Zona_Cueva;
- embedded in mountain slope;
- irregular entrance;
- rock frame;
- side rocks;
- roof rock;
- dark readable interior;
- entrance floor;
- access path;
- wild vegetation;
- player can approach.

Reject:
- black block;
- rectangular hole;
- isolated object;
- cave floating;
- no terrain integration;
- no access path.

Material:
- MAT_Cave or MAT_20HA_Cueva_Interior;
- dark grey, not pure black.
EOF

cat > .claude/skills/blender-material-audit/SKILL.md <<'EOF'
---
name: blender-material-audit
description: Audit Blender materials, shading nodes, external texture dependencies, DefaultMaterial, and GLB/Godot compatibility.
---

# Blender Material Audit

Goal: simple beautiful low poly materials, no fragile external dependencies.

Inspect:
- all visible materials;
- shader nodes;
- Image Texture nodes;
- bpy.data.images filepaths;
- normal/roughness/metallic/displacement maps;
- node groups;
- transparent/advanced water shaders;
- DefaultMaterial;
- objects with no material.

Replace complex materials with simple Principled BSDF:
- color base;
- roughness simple;
- metallic 0 unless needed;
- alpha only if needed;
- no external textures;
- no Blender-only effects.

Use material names:
- MAT_Grass
- MAT_Forest
- MAT_Dirt
- MAT_Wet
- MAT_Mud
- MAT_Path
- MAT_Water
- MAT_Rock
- MAT_RockDark
- MAT_Wood
- MAT_LeafA
- MAT_LeafB
- MAT_Hay
- MAT_Cave
- MAT_Rural
- MAT_Metal

Reject if:
- visible materials use external images;
- DefaultMaterial visible;
- water uses complex shader;
- cave is pure black;
- GLB depends on external image files.

Report:
- materials scanned;
- complex materials found;
- external textures found;
- materials replaced;
- final palette.
EOF

cat > .claude/skills/blender-godot-export-validator/SKILL.md <<'EOF'
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
EOF

cat > .claude/skills/godot-3d-import-pipeline/SKILL.md <<'EOF'
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
EOF

cat > .claude/skills/godot-gameplay-spawn-system/SKILL.md <<'EOF'
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
EOF

cat > .claude/skills/git-godot-team-workflow/SKILL.md <<'EOF'
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
EOF

echo "Claude skills created."
find .claude/skills -maxdepth 2 -name SKILL.md | sort
