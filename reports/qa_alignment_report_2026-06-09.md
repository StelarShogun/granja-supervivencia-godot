# QA Report — Alineación de props y colisión jugable (Terreno_Finca)

Fecha: 2026-06-09
Alcance: Fases 1–4 del plan de auditoría (Blender + Godot). Spawns y gameplay excluidos por mandato.

## Resumen ejecutivo

La auditoría midió 1524 meshes contra un BVH de `Terrain_Main` + `Mtn_Main` y encontró 716 objetos con |gap| > 0.15 m (340 críticos). Las causas raíz fueron tres: (1) props que quedaron al nivel del terreno antiguo tras excavar el cráter del lago (fondo intencional a −103.2 m) y la garganta del río; (2) las estructuras Granero/Corral ya no existen en el GLB — son construcciones runtime de Godot cuyas posiciones de editor quedaron 5 m por debajo del terreno actual; y (3) un grupo de colliders fantasma (`ScenarioColliders`) desalineados decenas de metros respecto de los visuales actuales. Se eliminaron 163 props de vegetación suspendidos en el aire, se reposicionaron 333 props sobre el terreno, se corrigieron las alturas de Barn/Shed en `main.tscn`, se eliminaron los colliders fantasma y se añadieron 782 proxies de colisión primitiva (troncos, rocas grandes, cercas sueltas) sin trimesh masivo. Validación final en Godot 4.6.3 headless: la escena carga, la colisión bloquea en todas las categorías de prueba y quedan 0 props con |gap| > 0.15 m en las zonas A–E.

## Tabla de problemas

| objeto/grupo | zona | gap_m | tipo | fix aplicado | estado |
|---|---|---|---|---|---|
| 163 vegetación (Lib_Tree 33, Bush_Old 21, Ribera 20, Lib_Shrub 13, Log_Old 12, otros) | A cráter + B garganta | +2 a +101 | flotando en aire sobre terreno excavado | eliminados en Blender | PASS |
| 31 rocas (Lib_Rock, Rock_Old) | A + B | +2 a +101 | flotando | snap al lecho del cráter/garganta | PASS |
| 119 props varios | global | +0.15 a +2 | flotando leve | snap_bottom (+0.04 m) | PASS |
| 214 props varios | global | −0.15 a −10 | enterrados | snap_bottom, árboles enderezados Z-up | PASS |
| Barn (granero) | C rural | −5.27 | editor y=4.8, terreno y=10.07 | y=10.02 en main.tscn (snap runtime queda como respaldo) | PASS |
| Shed | C rural | −5.0 | editor y=3.4, terreno y=8.4 | y=8.35 en main.tscn | PASS |
| BarnCollider fantasma | — | desalineado 76 m del visual | muro invisible | nodo eliminado | PASS |
| ShedCollider fantasma | — | desalineado 59 m | muro invisible | nodo eliminado | PASS |
| CaveCollider fantasma | — | flotando ~28 m sobre boca de cueva | muro invisible | nodo eliminado | PASS |
| FenceCollider_01..05 + BridgeCollider fantasma | — | y=23 (flotando) / posición vieja | muros invisibles | nodos eliminados | PASS |
| Cave_Rock_00..06, Cave_Lip_* (10 objetos) | montaña/cueva | −16 a +6 | falso positivo: raycast pega la superficie exterior de la montaña, objetos son interior de cueva | sin cambio (por diseño) | SKIP |

## Colisión

| categoría | count OK | count GAP previo | fix |
|---|---|---|---|
| Terreno (Terrain_Main, Mtn_Main) | 2 trimesh | 0 | sin cambio |
| Estructuras GLB (Bridge_Part_01, Cave_Lip_×3) | 4 trimesh | 0 | sin cambio |
| Estructuras runtime (Barn, Shed, Fence corral 30 tiles) | colisión propia | 0 (pero duplicadas por fantasmas) | fantasmas eliminados |
| Troncos de árbol (Lib_Tree) | 584 cilindros proxy | eran 584 sin colisión | proxy CylinderShape3D r=0.4·escala, h=2.5 |
| Rocas ≥1 m (Rock_*, Lib_Rock, River_Bank_Rock) | ~190 boxes proxy | eran sin colisión | proxy BoxShape3D desde AABB |
| Cercas sueltas (Lib_Fence, POI_BrokenFence) | boxes proxy | eran sin colisión | proxy BoxShape3D |
| Decoración pequeña (bushes, flores, pasto, logs) | sin colisión | — | por diseño (atravesable) |
| Total proxies generados | 782 | — | límite MAX_PROXY_SHAPES=1500 |

Capas verificadas: TerrainCollision layer 2 / mask 0; Player CharacterBody3D mask 2. Pruebas de raycast horizontal a altura de pecho: Barn BLOCK, Shed BLOCK, cerca corral BLOCK, roca BLOCK, tronco BLOCK, deck puente BLOCK (trimesh, hit y=1.69 en centro de AABB).

## Comandos ejecutados

- Blender 5.1.2 headless (vía MCP `execute_blender_code_for_cli`) sobre `assets/models/environment/Terreno_Finca.blend`:
  - `tools/blender/audit_terrain_alignment.py` (pre y post; CSV en `reports/`)
  - `tools/blender/fix_terrain_alignment.py` (fix + save + export GLB)
  - `python -m ensurepip && pip install numpy` en el Python del venv Blender-MCP (el exporter glTF lo requiere y faltaba)
- `godot --headless --path . --import`
- `godot --headless --path . --script tools/godot/audit_level_alignment.gd`
- `godot --headless --path . --script tools/godot/qa_probe_collision.gd`

## Archivos tocados

- `assets/models/environment/Terreno_Finca.blend` — 163 props eliminados, 333 snapeados, árboles enderezados
- `assets/models/environment/Terreno_Finca.glb` — re-exportado (export_apply, Y-up)
- `scenes/levels/main.tscn` — eliminado `ScenarioColliders` (24 nodos) y 9 sub_resources huérfanos; Barn y=10.02, Shed y=8.35
- `scripts/world/terrain_collision.gd` — proxies primitivos para troncos/rocas/cercas
- `tools/godot/audit_level_alignment.gd` — expectativas actualizadas (estructuras runtime, Bridge_Part_01)
- Nuevos: `tools/blender/audit_terrain_alignment.py`, `tools/blender/fix_terrain_alignment.py`, `tools/godot/qa_probe_collision.gd`, `reports/audit_terrain_alignment.csv`, `reports/audit_terrain_alignment_post.csv`, este reporte

## Apéndice — Pasada de spawns (mismo día)

Ejecutado `sync_spawns_from_glb.gd` y aplicadas las coordenadas GLB (con offset −37.47/+2.03/+22.39 resuelto) a `main.tscn`: `Player_Spawn`, `Diablo_Spawn`, `Diablo_Cave_Spawn`, `AnimalSpawn_01..10`, `CaveTrigger` y los nodos `Player` y `Diablo`. El empty `Sp_Diablo_Cave` flotaba 3.25 m en el .blend; se bajó a suelo+0.5 (z 95.445 → 92.194) y se re-exportó el GLB. Resultado final de `audit_level_alignment.gd`: 31 OK, 0 ISSUE.

Nota de diseño: `AnimalSpawn_05/06` (Sp_An12/13 del GLB, zona ex-lago) quedan en el fondo del cráter a y≈−100.8, sobre suelo válido. Coherente con el GLB como fuente de verdad, pero revisar si esos animales deben ser alcanzables sin bajar al cráter.

## Riesgos restantes

- `glb_cleanup.gd` lanza 2 errores en harness headless (`current_scene` null al crear interactivos de la garganta); en juego real `current_scene` existe — verificar una vez in-game.
- Validación hecha por raycast headless; falta caminata manual in-game por cráter, garganta y rural.
- 782 proxies son shapes primitivos estáticos (coste bajo); si hay impacto de rendimiento, reducir `TRUNK_RADIUS`/categorías.
- numpy quedó instalado en el venv de Blender-MCP (requerido por el exporter glTF de Blender 5.1).

## Criterio de salida

- [x] 0 props con |gap| > 0.15 m en zonas A–E (post-audit: 10 restantes, todos interior de cueva, falsos positivos por diseño, fuera de zonas A–E)
- [x] 0 estructuras con >30 % enterradas (Barn/Shed corregidos; corral snap por tile)
- [x] Colisión jugable: terreno + estructuras + props bloqueantes (782 proxies + 6 trimesh)
- [x] GLB exportado y main.tscn carga sin errores de parseo en Godot 4.6.3
- [x] audit_level_alignment.gd sin ISSUE críticos de nivel (los 11 restantes son spawns/triggers, fuera de alcance)
