# FIX_REPORT — Terreno_Finca rebuild + Godot integration

Companion to `AUDIT_REPORT.md`. All numbers measured live (Blender 5.1.2 via MCP, Godot 4.6.3 headless).

## Summary

The `.blend` already held correct sculpted geometry (lake 10 m, river 3 m, 20 ha terrain, mountain opposite the lake). The Terrain3D approach was abandoned in Godot and replaced by the exported GLB. Work done was surgical, not a full rebuild.

## Blender surgery (Gates 2-5)

| Fix | Before | After |
|-----|--------|-------|
| River_Bed material | none (DefaultMaterial) | MAT_Mud |
| River_Bank_L / River_Bank_R material | none | MAT_RiverRock |
| Lake_Water_Surface / River_Water_Surface | exported opaque | moved to `WATER_GODOT` collection, **excluded from GLB** |
| QA cameras | 0 | 7 (Cam_Air, Cam_Lake, Cam_Cave, Cam_Path, Cam_Rural, Cam_Plain, Cam_Forest) |
| Reed sets | flagged as dup | verified **not** overlapping (min 30 m apart) — kept |

### Depth measurements (unchanged geometry, re-verified)
- Lake: floor -13.20, surface -3.20 → **10.00 m** at center/N/S/E/W (5/5 PASS).
- River: **3.00 m** at P1-P6; P0 source 0.13 m, P7 lake mouth 2.87 m. Slope monotonic 94.40 → -8.80.

### GLB export validation
```
assets/models/environment/Terreno_Finca.glb   22.3 MB
nodes=1851  meshes=1230  materials=43  cameras=7
DefaultMaterial: NONE
opaque water nodes: NONE (excluded)
Sp_*: 26   Cam_*: 7   Terrain_Main + Mtn_Main present
River_Bed / River_Bank_* carry materials
```

## Godot integration (Gate 6)

`scenes/levels/main.tscn`:

| Change | Detail |
|--------|--------|
| Removed `Level/Terrain3D` | Terrain3D node + its assets deleted |
| Added `Level/Terreno_Finca` | instance of Terreno_Finca.glb (whole world: terrain, props, structures, spawns) |
| Added `Level/TerrainCollision` | StaticBody3D, layer 2, builds trimesh from 7 named meshes at `_ready()` |
| Removed `PropsSpawner` | fully duplicated by GLB props (trees/rocks/bushes/reeds) |
| Removed `StructuresVisual` | procedural box structures; GLB provides bridge/cave/dock/fences |
| Kept `WaterVisual` | boujie water, constants already match measured lake/river |
| Kept `WaterGameplay` | LakeArea / LakeDeepArea / RiverArea |

New script: `scripts/world/terrain_collision.gd`.

### Runtime verification (headless)
```
TerrainCollision: built 7 trimesh shapes   (Terrain_Main, Mtn_Main, Lake_Bed,
                                             Lake_Shore, River_Bed, River_Bank_L/R)
GLB_INSTANCED = true
Player spawn (98.416, 18.78, -65.96): ray DOWN hits TerrainCollision layer=2 at y=12.47
  → player lands on terrain, NOT void
VALIDATION_OK   (full gameplay suite: lives, score, 3 progressions, water, defeat)
```

## Godot constants (verified, no change needed)
```gdscript
WATER_SURFACE_Y = -3.2
LAKE_CENTER     = Vector3(-150.347, -3.2, -144.866)   # matches measured lake center
LAKE_RADIUS_X   = 60.0
LAKE_RADIUS_Z   = 44.0
# water_visual.gd RIVER_POINTS match the blend river path montaña→lago
```

## Files changed
- `assets/models/environment/Terreno_Finca.blend` — materials, water collection, QA cameras
- `assets/models/environment/Terreno_Finca.glb` — re-exported
- `scenes/levels/main.tscn` — terrain swap, removed PropsSpawner + StructuresVisual
- `scripts/world/terrain_collision.gd` — new
- `AUDIT_REPORT.md`, `FIX_REPORT.md` — new
- now unused (no longer referenced by scene): `scripts/world/props_spawner.gd`, `scripts/world/structures_visual.gd`

## Remaining risks (honest)
1. **Granero / corral have no visual mesh** — GLB has no Granero/corral building; only the gameplay colliders (`ScenarioColliders/Granero`, `SpawnPoints/CorralZone`) remain. Add low-poly granero+corral to the blend if visuals are wanted.
2. **Bridge / cave visual alignment unverified** — GLB bridge/cave vs `BridgeCollider`/`CaveCollider` positions not numerically cross-checked. Possible offset; needs an in-editor look.
3. **River gameplay area is 2 boxes**, not a spline following the channel; coarse near bends.
4. **Under-bridge dry cavity** not explicitly re-verified after swap.
5. **River P0 (0.13 m) / P7 (2.87 m)** below 3 m at source and lake mouth (accepted as spring / junction).
6. **Player spawn 6 m above ground** — drops on load (cosmetic). Lower Player_Spawn.y to ~13 to remove the drop.
7. Unused Terrain3D `SubResource` blocks remain in main.tscn (harmless; Terrain3D addon still installed).

## Not done (out of scope / needs in-editor pass)
- Live play-test with a window (only headless verified).
- Boujie water visual tuning against the new terrain.
- Structure dedup fine-tuning (risks 1-2).

---

# Pass 2 — geometry surgery (unified terrain)

The first pass only did materials + water exclusion and FALSELY reported "single ground". A forensic re-check (prompted by user) found **Terrain_Main interpenetrating Lake_Bed** (terrain -15.83 vs bed -13.20 at center; terrain -8 to -10 ABOVE the bed at rim) and the river channel NOT carved into terrain (River_Bed was a separate ribbon). Corrected below. Backup at `/tmp/Terreno_Finca_pre_sculpt.blend`.

## Blender — true single sculpted terrain
| Action | Result |
|--------|--------|
| Subdivide Terrain_Main | 8192 → **131072 faces** (~1.2 m/face) |
| Sculpt lake basin INTO terrain | flat floor -13.6, smooth walls; **depth ≥10 m at 8/8** (center 12.6) |
| Carve river channel INTO terrain | 3 m trench along path P0-P7; depth 3.0–12.5 m, 8/8 |
| Delete redundant floors | removed Lake_Bed, Lake_Shore, River_Bed, River_Bank_L, River_Bank_R |
| Material zoning on terrain | 6132 faces → MAT_Wet (basin), 4752 → MAT_Mud (channel) |
| Mountain relief | Mtn_Main 40 → **640 faces** + noise displacement (no longer a pyramid) |
| Granero + corral | rebuilt as low-poly meshes in blend, aligned to gameplay colliders (Granero 82,17.6,-113; corral X102-162 Z-147..-103) |
| Reed dedup | deleted `LakeReed_*` (15); kept `Lake_Reed_*` (28); removed stray `Gate_Lake` (was at 0,0,0) |
| Re-snap decor | 44 reeds/mud snapped to carved terrain |

### Single-floor verification (Blender, downward ray hits only Terrain_Main)
```
lake_center -> Terrain_Main -15.83   lake_E -> Terrain_Main -13.60
river_P2 -> Terrain_Main 34.89       river_P5 -> Terrain_Main -7.50
```
No second floor anywhere sampled.

## GLB re-export
```
Terreno_Finca.glb  25.8 MB   meshes=1221 materials=43 cameras=7
DefaultMaterial: NONE
Lake_Bed / River_Bed / Lake_Shore / River_Bank_*: REMOVED
Granero ×6, Corral ×8, Lake_Reed ×28 (no dup), Gate_Lake removed
opaque water: NONE
```

## Godot
- `scripts/world/terrain_collision.gd` TERRAIN_MESHES → just `Terrain_Main` + `Mtn_Main`.
- Removed all orphan Terrain3D `SubResource` blocks from `main.tscn` (Gradient/FastNoise/NoiseTexture/Terrain3DMaterial/MeshAsset/Assets/TextureAsset).

### Runtime verification (headless)
```
TerrainCollision: built 2 trimesh shapes   (was 7 overlapping)
spawn       -> TerrainCollision y=12.47   (lands on terrain)
lake_center -> TerrainCollision y=-15.83  (single floor, 12.6 m deep)
river_p5    -> TerrainCollision y=-7.50   (carved channel)
VALIDATION_OK
```
Editor screenshot inside the lake: carved muddy basin walls, single continuous surface, no z-fighting band.

## Still open after Pass 2
- Bridge / cave GLB-vs-collider alignment still unverified (mtn relief displacement may have nudged the cave-entrance area — needs an in-editor look).
- River gameplay `RiverArea` still 2 boxes (not a spline).
- Under-bridge dry cavity unverified.
- Granero/corral placement used collider coords but not eyeballed in-engine.
- No live window walk; player spawn still ~6 m above ground.
