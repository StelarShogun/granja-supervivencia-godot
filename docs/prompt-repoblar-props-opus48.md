# Prompt — Repoblación de props (Opus 4.8)

Bloque listo para pegar en Claude Code cuando se quiera repetir o continuar la repoblación del terreno.

```
ROL: Opus 4.8 — repoblación de props en Terreno_Finca.
PIPELINE: solo Blender bake → GLB → reimport Godot. MCP Blender 127.0.0.1:9876 vía tools/blender/mcp_send.py.
NO reactivar PropsSpawner en runtime. NO tocar gameplay salvo bug evidente de carga de escena.

INPUTS (assets/models/props):
- nature/trees/low_poly_forest_tree_pack.glb   (principal, atlas con texturas empaquetadas)
- nature/trees/low_poly_trees.glb              (simple; tiene 2 planos gigantes basura -> descartar)
- structure/modular_fence_system.glb           (alto poly 5k-9k verts; usar pocas variantes)
- EXCLUIR structure/wooden_bridge_..._24mb.glb  (duplica Bridge_01)
- nature/grass/low_poly_grass_pack.glb         (son tiras de 280 m, NO tufts; omitir o recortar fuerte)

SKILLS (leer antes): caveman, blender-prop-distribution, blender-lowpoly-biomes,
blender-material-audit, blender-godot-export-validator, blender-level-design-qa,
godot-3d-import-pipeline.

SCRIPTS YA CREADOS (idempotentes):
1. tools/blender/import_prop_packs.py     -> COL_PropLibrary (normaliza escala, origen en base, remapea MAT_*)
2. tools/blender/scatter_props_by_zone.py -> COL_Props por zona (raycast, Poisson, exclusiones, POIs)
3. tools/blender/replace_forest_cones.py  -> sustituye conos Tree_* por trees del pack
4. tools/blender/export_terreno_glb.py    -> export GLB excluyendo COL_PropLibrary

ORDEN: import -> scatter -> replace_forest_cones -> dedupe/limpieza -> export.

ZONA EX-LAGO: planicie seca (elipse centro (-150,145) rx62 ry48), sin agua/reeds. Quitar dock Muelle_* y WetLog enterrados.
PUENTE/RÍO: tramo corto en Bridge_01 (27.6,10,15); decoración de orilla OK, paso seco bajo tablero.
BOSQUE REAL: oeste/suroeste, X -224..-74. Allí están los árboles (no donde decía el plan viejo).

EXCLUSIONES (radio m): Sp_Player 12, Sp_An* 6, Corral_/Granero_ 8, Bridge_01 6.

GATES:
- Gate 1: 0 DefaultMaterial, 0 texturas externas (todas empaquetadas), escala coherente.
- Gate 2: cuotas por zona, 0 violación de exclusión, props pegados al suelo, sin stacks (<0.5 m).
- Gate 4: VALIDATION_OK + spawn on_floor + AUDIT_OK.

VALIDACIÓN GODOT:
  godot --headless --import
  godot --headless -s res://tools/godot/validate_game_setup.gd
  godot --headless -s res://tools/godot/check_spawn_ground.gd
  godot --headless -s res://tools/godot/audit_level_alignment.gd

RIESGO CONOCIDO: main.tscn puede referir scripts borrados del lago (underwater_effect.gd, water_visual.gd).
Si rompe la carga, quitar esos nodos/ext_resource huérfanos.

REPORTES: docs/PROP_AUDIT_BEFORE.md (fase 0) y docs/PROP_REPORT_AFTER.md (fase 4).
NO commit sin pedido del usuario. Español /caveman en chat.
```
