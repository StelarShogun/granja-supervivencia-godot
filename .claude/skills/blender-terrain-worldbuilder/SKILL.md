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
