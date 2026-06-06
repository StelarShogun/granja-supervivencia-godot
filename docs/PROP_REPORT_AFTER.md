# Prop Repopulation — Report (After)

Source: `assets/models/environment/Terreno_Finca.blend` → `Terreno_Finca.glb`.
Date: 2026-06-05. Pipeline: Blender bake → GLB → Godot reimport. No runtime PropsSpawner.

## What changed

| Step | Action |
|------|--------|
| Phase 0 | Baseline audit → `docs/PROP_AUDIT_BEFORE.md` (1649 props, forest/plain already dense, ex-lake + rural bare) |
| Phase 1 | Imported 3 packs into `COL_PropLibrary`: 23 trees, 7 shrubs, 9 rocks, 4 fences (43 variants). Normalized scale, rebased origins to base, fixed 2 sideways trees, remapped plain materials to `MAT_*`. Dropped 2 junk ground planes + 26 redundant fence variants. |
| Phase 2 | Scattered 133 instances by zone (Forest 40, Ex-lake 45, Rural 22, Mtn 20 + 6 POIs) with seeded raycast, Poisson spacing, slope + exclusion rejection. |
| Phase 2b | **Replaced all 747 cone trees** in the forest with varied pack trees at matching positions/heights (user decision). |
| Phase 3 | Removed orphan dock (`Muelle`, 11 parts), 2 buried `WetLog`, 196 stacked duplicate forest trees. Verified no lake meshes, no `Gate_Lake`, ex-lake is a shallow dry swale (~2 m), not a crater. |
| Phase 4 | Excluded `COL_PropLibrary` from export, exported GLB (Y-up, apply modifiers), reimported in Godot, ran validators. |
| Scene fix | Removed orphan `UnderwaterEffect` + `WaterVisual` nodes from `main.tscn` (referenced scripts deleted in the prior lake-removal work — broke scene load). |

## Final inventory

| Metric | Before | After |
|--------|--------|-------|
| Mesh objects (blend) | 1664 | 1584 |
| Exported visible meshes | — | 1541 (library excluded) |
| Forest trees | 747 cones (1 style) | 584 varied pack trees |
| New zone props | — | 127 (+6 POIs) |
| Library variants (not exported) | — | 43 |
| Materials in export | — | 38 (0 DefaultMaterial, 0 external textures) |
| Blend file | 33.5 MB | 28.2 MB |
| GLB | ~ | 28 MB |

## Gates

| Gate | Result |
|------|--------|
| Gate 0 (hole map) | PASS |
| Gate 1 (library: 0 DefaultMaterial, 0 external tex, coherent scale) | PASS |
| Gate 2 (quotas ±10%, 0 exclusion violations, props ground-rooted) | PASS (14 violating trees + 196 stacked dupes removed) |
| Gate 3 (no wet crater, dock/lake remnants gone) | PASS |
| Gate 4 | **VALIDATION_OK**; Player spawn `on_floor=true`; AUDIT_OK (26) |

## Godot validation

- `validate_game_setup.gd` → **VALIDATION_OK** (all InputMap, UI, scene nodes, win/lose logic OK).
- `check_spawn_ground.gd` → Player settles `on_floor=true` at terrain surface.
- `audit_level_alignment.gd` → **AUDIT_OK (26)**; 9 pre-existing issues (see risks).
- In-engine viewport screenshot confirms props render with correct materials.

## Remaining risks (NOT caused by prop work)

These are pre-existing from the terrain/lake-rebuild sessions:

1. **Spawn marker drift**: `Diablo_Spawn` (Y gap -12), `AnimalSpawn_05/06`, `Diablo_Cave_Spawn`, `CaveCollider` markers sit below the rebuilt terrain. The Godot scene markers do not match GLB positions (e.g. Godot AnimalSpawn_05 at (-128,-132) vs blend Sp_An05 at (-70,-22)). Fix via `tools/godot/sync_spawns_from_glb.gd` — gameplay scope, deferred.
2. `GLB marker missing: Sp_Diablo_Cave`, `Granero`, `Gate_Lake` — `Gate_Lake` intentionally removed; `Granero` exists as separate wall meshes (audit looks for a single named node).
3. GLB at 28 MB driven partly by the high-poly fence pack (5k–9k verts/segment). Only 4 fence variants kept; if size matters, decimate fences.

## Files created / modified

**Created:**
- `tools/blender/import_prop_packs.py`
- `tools/blender/scatter_props_by_zone.py`
- `tools/blender/replace_forest_cones.py`
- `tools/blender/export_terreno_glb.py`
- `docs/PROP_AUDIT_BEFORE.md`
- `docs/PROP_REPORT_AFTER.md`

**Modified:**
- `assets/models/environment/Terreno_Finca.blend` (props baked in)
- `assets/models/environment/Terreno_Finca.glb` (reexport)
- `scenes/levels/main.tscn` (removed 2 orphan water nodes + ext_resources)

## Commands used

```bash
# Blender (via MCP socket 127.0.0.1:9876)
python3 tools/blender/mcp_send.py < tools/blender/import_prop_packs.py
python3 tools/blender/mcp_send.py < tools/blender/scatter_props_by_zone.py
python3 tools/blender/mcp_send.py < tools/blender/replace_forest_cones.py
python3 tools/blender/mcp_send.py < tools/blender/export_terreno_glb.py

# Godot
godot --headless --import
godot --headless -s res://tools/godot/validate_game_setup.gd
godot --headless -s res://tools/godot/check_spawn_ground.gd
godot --headless -s res://tools/godot/audit_level_alignment.gd
```
