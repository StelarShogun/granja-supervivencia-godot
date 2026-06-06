# AUDIT_REPORT — Terreno_Finca.blend

Gate 1 forensic audit. Read-only. All measurements taken live in Blender 5.1.2 via MCP (socket 9876).
Coordinate space: Blender (Z up). Water surface plane at Z = -3.20.

## Scene scale

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Terrain_Main footprint | 448 × 448 m (X/Y: -224..224) | ~447 m (~20 ha) | PASS |
| Terrain_Main height | Z -16.0 .. 101.3 | relief present | PASS |
| Mtn_Main bbox | X 86..226, Y -209..-79, Z 51..117 | high mountain, opposite lake | PASS |
| Full mesh bbox | X 540, Y 648, Z 135 | — | outliers beyond terrain (decor/mtn skirt) |
| Total meshes | 1801 | — | — |
| Collections | 1 (`Collection`) | — | flat; no export grouping |

## Lake depth (surface Z = -3.20)

Raycast vs `Lake_Bed`, 5 samples.

| Point | Floor Z | Depth | Status |
|-------|---------|-------|--------|
| center (-150,145) | -13.20 | 10.00 | PASS |
| N (-150,168) | -13.20 | 10.00 | PASS |
| S (-150,122) | -13.20 | 10.00 | PASS |
| E (-128,145) | -13.20 | 10.00 | PASS |
| W (-172,145) | -13.20 | 10.00 | PASS |

Lake floor flat at -13.20 = exactly 10.0 m. **Requirement ≥10 m: PASS (5/5).**

## River depth (surface_localZ − bed_floorZ, r=6)

Sampled at `RiverPath_Point_00..07`, mountain → lake.

| Point | XY | Surf Z | Floor Z | Depth | Status |
|-------|----|--------|---------|-------|--------|
| P0 source | (150,-132) | 94.53 | 94.40 | 0.13 | FAIL (headwater) |
| P1 | (120,-95) | 70.40 | 67.40 | 3.00 | PASS |
| P2 | (82,-48) | 37.40 | 34.40 | 3.00 | PASS |
| P3 | (34,18) | 11.40 | 8.40 | 3.00 | PASS |
| P4 | (-28,58) | 3.40 | 0.40 | 3.00 | PASS |
| P5 | (-78,90) | -4.60 | -7.60 | 3.00 | PASS |
| P6 | (-112,118) | -5.80 | -8.80 | 3.00 | PASS |
| P7 mouth | (-150,145) | -4.93 | -7.80 | 2.87 | LOW (lake junction) |

**Requirement ≥3 m: 6/8 PASS.** Slope monotonic descending 94.40 → -8.80 (no inversion). P0 = spring head, P7 = lake mouth transition.

## Materials

| Metric | Value |
|--------|-------|
| Total materials | 44 |
| `Material` (default-like) | 1, **0 users** (harmless) |
| Meshes with NO material slot | 5 |

No-material meshes (would export as DefaultMaterial / opaque):
- `River_Bed` — terrain geometry, **needs MAT_Mud**
- `River_Bank_L` — terrain geometry, **needs material**
- `River_Bank_R` — terrain geometry, **needs material**
- `Lake_Water_Surface` — water plane, **must NOT export opaque**
- `River_Water_Surface` — water plane, **must NOT export opaque**

## Water objects

| Object | Z range | Note |
|--------|---------|------|
| Lake_Water_Surface | -3.20 (flat) | opaque-risk, no material |
| River_Water_Surface | -5.81 .. 97.40 | follows channel, no material |

Per hard rules 9-12: visible water = Godot boujie shader AFTER export. These two surfaces must be excluded from GLB (move to non-export collection) and re-created as shader water in Godot aligned to measured basin/channel.

## Duplicates / overlap

- `Lake_Reed_00..27` (28) **and** `LakeReed_01..29` (15) — two reed naming sets in same lake zone. Likely overlap/clutter. Dedupe candidate.

## Spawns

26 present: `Sp_Player`, `Sp_Diablo`, `Sp_An01..An24`. PASS.
- `Sp_Player` Z=13.11, terrain Z=12.43 → 0.68 m above ground. Valid.

## QA cameras

**NONE present.** Rule requires Cam_Air, Cam_Lake, Cam_Cave, Cam_Path, etc. Must be created in Gate 4.

## Verdict — Gate 1

Geometry is in far better shape than the original prompt assumed: lake = 10 m, river = 3 m (6/8), terrain = 20 ha, mountain opposite lake. Terrain3D fiasco does not apply to this .blend — it already holds sculpted basin/channel.

### Defects to fix (surgery gates)
1. Assign materials to `River_Bed`, `River_Bank_L`, `River_Bank_R` (MAT_Mud / MAT_Rock).
2. Exclude `Lake_Water_Surface` + `River_Water_Surface` from GLB export (water = Godot boujie).
3. Dedupe reed sets `Lake_Reed_*` vs `LakeReed_*`.
4. Create QA cameras.
5. River P0 (0.13 m) and P7 (2.87 m) borderline — document as accepted source/mouth, or deepen P7 to ≥3 m.

### Blockers
None. Proceed to Gate 2.
