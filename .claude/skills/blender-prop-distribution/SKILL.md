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
