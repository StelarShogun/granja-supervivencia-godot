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
   - health (100 HP bar);
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
- Animal collection via corral delivery (both modes).
- 100 HP health bar; Cacique collectible heals.
- Diablo enemy chase.
- Level 1: rural zone.
- Level 2: open plain (former lake basin; now dry plain with river crossing).
- Level 3: forest/cave.
- Win after 10 animals in corral.
- Lose when HP reaches 0.

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
- overly advanced water material;
- hard terrain transitions;
- DefaultMaterial on visible objects.

The map must have:

- primary forest;
- open plain (former lake basin, now dry);
- river crossing with bridge (no lake);
- rural zone;
- cave zone;
- natural paths;
- distributed props;
- coherent low poly materials.

## Learned User Preferences

- Responder siempre en español.
- Usar estilo /caveman (corto, directo, técnico) en conversación según CLAUDE.md.
- Integración visual del agua (boujie_water_shader) la gestiona Claude Code; no duplicar ese trabajo aquí.
- Verificar con Godot AI MCP (editor conectado) cuando esté disponible; no usar headless por defecto.
- Terreno Blender roto: restaurar desde UNA `liderazgo 2/Terreno_Finca.blend` (= LFS); no boolean/sculpt con props sobre `Terrain_Main`.

## Learned Workspace Facts

- Jugador usa barra de 100 HP (no 3 vidas); Cacique cura; derrota a 0 HP.
- Sin puntuación en HUD, guardado ni pantalla de victoria.
- Animales solo cuentan al entregarlos en el corral (Normal y modo difícil); progresión 3/6/10; modo difícil = `game_mode` 1.
- Terreno activo: `Terreno_Finca.glb`/`.blend`; Terrain3D abandonado; agua opaca no en GLB; restore UNA = git LFS HEAD.
- Profundidad geométrica solo cauce río (~30 m) + lago (~100 m); `tools/blender/carve_river_lake_gorge.py`; puente `wooden_bridge_roofed_bridge_cap_-24mb.glb`.
- Machete fondo lago (`Sp_Machete`); única arma vs Diablo (F); Cacique ≠ machete; cuerda `Sp_Rope_Top/Bottom` (E); `glb_cleanup.gd` spawnea interactives.
- Prohibido boolean `Machete` en `Terrain_Main`; no usar `remove_lake_keep_bridge_river.py` para reparar geometría rota.
- `vendor/archives/` guarda repos de terceros con `.gdignore`; plugins activos permanecen en `addons/`.
- `main.tscn`: Terreno_Finca, TerrainCollision (`terrain_collision.gd`), WaterGameplay, WaterVisual; sin Terrain3D/PropsSpawner/StructuresVisual.
- Spawn/alineación: `Terreno_Finca` identidad; Player_Spawn=`Sp_Player` GLB; tools/godot/check_spawn_ground.gd, audit_level_alignment.gd, sync_spawns_from_glb.gd.
- GLB pendiente: `Corral_01`, `Barn_01` en origen; `Granero` ausente (sí Granero_Floor/Roof); cráter bosque fuera del cauce no debe existir.
- Nadar/bucear implementados; cave trigger con aviso si Diablo no salió y flag `player_entered_cave` en guardado.
