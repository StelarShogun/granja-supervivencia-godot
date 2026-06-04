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
