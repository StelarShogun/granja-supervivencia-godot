# Prop Audit — Baseline (Before Repopulation)

Source: `assets/models/environment/Terreno_Finca.blend` (live, via Blender MCP `127.0.0.1:9876`).
Date: 2026-06-05.

## Scene totals

| Metric | Value |
|--------|-------|
| Objects | 1704 |
| Mesh objects | 1664 |
| Prop meshes (excl. terrain/mtn/cave) | 1649 |
| World bbox (m) | X 450.4 · Y 448.0 · Z 129.2 |
| Collections | `Collection` (1686 objs, flat — no zone subcollections), `WATER_GODOT` (0) |

## Prop count by name prefix (top)

| Prefix | Count |
|--------|-------|
| Tree | 745 |
| Bush | 226 |
| Ribera | 222 |
| Rock | 192 |
| Log | 59 |
| Pasto | 25 |
| Flor | 20 |
| Monticulo | 20 |
| Tallo | 20 |
| Planicie | 19 |
| Tocon | 14 |
| Cave | 12 |
| Muelle | 11 |
| RiverReed | 8 |
| Corral | 6 |
| Granero | 6 |
| WetLog | 5 |

Existing trees are simple low-poly cones (single style). Imported packs add variety.

## Density by zone (Blender X/Y plane)

| Zone | Rect / Ellipse | Count | Area m² | Props/100 m² | Verdict |
|------|----------------|-------|---------|--------------|---------|
| Rural | X 100–160, Y 100–140 | 18 | 2400 | 0.75 | **Sparse** — structures present, ground bare |
| Forest | X -90–40, Y 20–90 | 123 | 9100 | 1.35 | **Already dense** — reduce add target |
| Ex-lake (ellipse) | c(-150,145) rx62 ry48 | 14 | ~9350 | 0.15 | **Bare crater** — top priority |
| Open plain | X -50–80, Y -80–40 | 258 | 15600 | 1.65 | **Busiest** — minimal/no add |
| River-bridge | X 0–55, Y -25–15 | 45 | 2200 | 2.05 | OK |
| Mtn/cave | X 86–226, Y -209–-79 | 63 | 18200 | 0.35 | Sparse but large; light add |

## Empty-cell grid (40 m cells, 144 total)

- 39 empty cells, but **most are map-edge cells** (|x|≥236 or |y|≥204, outside ~450 m playable).
- Meaningful interior empties: ex-lake band (X -164, Y 116–156), mountain approach (X 116, Y -84 to -44).
- 17 sparse cells (<3 props).

## Visual QA (WORKBENCH renders, `/tmp/before_*.png`)

| View | Observation |
|------|-------------|
| Top-down | Trees clustered bottom-left; large bare grey areas center/top/right |
| Cam_Plain | Near-empty void, a few small rocks + one tuft |
| Cam_Rural | Bare ground around granero/corral; needs farm detail |
| Cam_Forest | Sparse single-style cone trees on grey ground |
| Cam_Cave | Rocky interior OK |

## Revised targets (baseline denser than original plan assumed)

Original plan budgeted +200–280. Baseline already has 1649 props. Revise down to avoid over-packing and keep GLB < 28 MB.

| Zone | Original target | **Revised add** | Rationale |
|------|-----------------|-----------------|-----------|
| Rural | 25–35 | **20–30** (POIs: hay, barrels, crates, fences near barn) | Detail, not volume |
| Forest | 80–120 trees | **30–45** varied pack trees + replace/augment cones | Already 123; add variety not count |
| Ex-lake plain | 40–60 | **35–50** (rocks, bushes, sparse grass, simple trees) | Fill the crater |
| Open plain | 30–40 | **0–10** | Already busiest |
| River-bridge | 15–25 | **0–10** | Already 2.05/100 m² |
| Mtn/cave | 20–30 | **15–25** (large rocks, few inclined trees, logs at entrance) | Light |

**Revised total: +100–170 instances** (down from 200–280). Max ceiling ~250.
Target post-repopulation: < 2000 mesh objects, GLB < 28 MB.

## Gate 0 — PASS

Hole map identified. No edits made. Ready for Phase 1 (import packs).
