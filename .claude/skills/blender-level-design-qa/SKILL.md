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
