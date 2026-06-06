# PROMPT OPUS 4.8 — Rebuild Terreno_Finca.blend (MCP Blender)

> **Copiar todo el bloque `PROMPT` a Claude Opus 4.8.**  
> Modo: agresivo, cero tolerancia, verificación obligatoria en cada gate.

---

## PROMPT

```
# ROL
Eres Opus 4.8 en modo ingeniero senior de nivel AAA low-poly.
Misión única: DESTRUIR el enfoque Terrain3D fallido y RECONSTRUIR el mapa
desde Terreno_Finca.blend con geometría correcta — especialmente LAGO y RÍO.
Sin excusas. Sin "parece bien". Sin éxito sin mediciones.

Proyecto: /home/dilan/Documentos/GitHub/granja-supervivencia-godot
Estilo conversación: /caveman (corto, técnico). Idioma: español.

---

# VEREDICTO PREVIO (NO DISCUTIR)

Terrain3D = FIASCO. Prohibido usarlo como terreno final.
- heightmap 512×512 desalineado con spawns/estructuras del layout original
- editor/juego: suelo plano o cuadros
- props/estructuras Godot con Y inventado
- agua boujie = ribbons planos que NO siguen geometría real

Fuente de verdad ÚNICA:
  assets/models/environment/Terreno_Finca.blend
Export obligatorio:
  assets/models/environment/Terreno_Finca.glb

---

# HARD RULES (VIOLACIÓN = RECHAZO AUTOMÁTICO)

## Geometría
1. UN solo suelo caminable por zona — cero meshes de terreno apilados.
2. Lago: profundidad GEOMÉTRICA ≥ 10.0 m (medida en Blender, no estimada).
3. Río: profundidad GEOMÉTRICA ≥ 3.0 m en TODO el recorrido montaña→lago.
4. Cauce y cuenca = depresiones ESCULPIDAS en terreno, NO planos encima.
5. Cero z-fighting entre Basin/Bed/Shore/Terrain_Main.
6. Cero meshes ocultos/degenerate que exporten al GLB.
7. Cero planos horizontales gigantes bajo el mapa (Y << -20 sin razón).
8. Vértices de orilla: transición continua (no cliff 90° salvo roca intencional).

## Agua
9. PROHIBIDO exportar agua opaca en GLB (MAT_Water, meshes líquidos sólidos).
10. Agua visible = boujie en Godot DESPUÉS — solo rellena huecos ya esculpidos.
11. Bajo puente: CERO volumen de agua (visual y gameplay) — hueco obligatorio.
12. Una sola cota de superficie: WATER_SURFACE_Y = -3.2 m.

## Materiales
13. Cero DefaultMaterial visible.
14. Cero dependencias de textura externa al repo.
15. Principled BSDF simple; paleta MAT_* canónica.
16. Cero shaders Blender-only que no exporten a glTF.

## Pipeline
17. NO tocar GameManager, Player, Diablo, HUD, guardado, menús.
18. NO reintroducir scripts muertos (river_generator, lake_generator, terrain_collision_builder legacy sin revisar).
19. NO declarar "terminado" sin GLB + reporte QA + mediciones numéricas.
20. NO commit sin pedido explícito del usuario.

---

# SKILLS OBLIGATORIAS (LEER ANTES DE EDITAR)

Ejecutar en orden:
1. /blender-level-design-qa
2. /blender-terrain-worldbuilder
3. /blender-material-audit
4. /blender-godot-export-validator
5. /blender-lowpoly-biomes
6. /blender-prop-distribution
7. /blender-cave-designer
8. /godot-3d-import-pipeline (solo post-export Godot)

---

# HERRAMIENTAS

## MCP Blender
- Socket: 127.0.0.1:9876
- Cliente: tools/blender/mcp_send.py
  echo '<bpy code>' | python3 tools/blender/mcp_send.py
- Blender Toolkit WebSocket (si disponible): puerto 9400

## Scripts repo
- tools/blender/fix_terrain_farm.py      (fase materiales/rename)
- tools/blender/build_phase3.py … 5     (estructuras/rutas)
- tools/blender/render_qa.py            (screenshots QA)
- tools/blender/render_check.py

## Godot validación final
godot --headless --path . -s res://tools/godot/validate_game_setup.gd
→ debe imprimir VALIDATION_OK

---

# INVENTARIO DE ERRORES ACTUALES (CORREGIR TODOS)

## A) Arquitectura rota original
| ID | Fallo | Evidencia |
|----|-------|-----------|
| A1 | Río/lago como láminas sobre GLB | river_generator, lake_generator |
| A2 | Capas superpuestas | terreno + bed + basin + agua Godot + MAT_Water blend |
| A3 | Doble suelo | Terrain_BasicCollision Y=-20 + trimesh GLB |
| A4 | 7+ cajas agua río | RiverWaterArea múltiples CollisionShape3D |
| A5 | Hueco negro bajo puente | desalineación visual/colisión/agua |
| A6 | Props flotando | grass_spawner, water_deco_reproject |
| A7 | Barra negra horizonte | planos lejanos / océano boujie mal acotado |

## B) Fiasco Terrain3D (estado actual)
| ID | Fallo | Evidencia |
|----|-------|-----------|
| B1 | Terreno plano en juego | Terrain3D sin relieve útil en main.tscn |
| B2 | GLB ausente en escena | Level/Terreno_Finca no instanciado |
| B3 | Agua ribbon inventada | water_visual.gd RIVER_POINTS hardcodeados |
| B4 | Estructuras fake | structures_visual.gd cajas Godot |
| B5 | Props Y fake | props_spawner.gd alturas estimadas |
| B6 | Spawns desincronizados | layout blend ≠ heightmap 512² |

## C) Lago — fallos geométricos
| ID | Fallo | Fix exigido |
|----|-------|-------------|
| C1 | Cuenca separada de Terrain_Main | Boolean/join/s sculpt — UN volumen coherente |
| C2 | Profundidad no medida | Raycast centro: piso ≤ -13.2 m (10 m bajo -3.2) |
| C3 | Shore abrupto | Pendiente orilla ≥ suave, material MAT_Wet/MAT_Mud |
| C4 | Bed overlap basin | Un lecho, no dos meshes en mismo volumen |
| C5 | WaterArea cajas Godot | Reemplazar tras medir forma real exportada |

## D) Río — fallos geométricos
| ID | Fallo | Fix exigido |
|----|-------|-------------|
| D1 | Ribbon plano Godot | Cauce esculpido 3 m bajo orillas locales |
| D2 | Solo 2 cajas gameplay | Area3D siguiendo spline real del cauce |
| D3 | Agua bajo puente | Recorte obligatorio tramo BridgeCollider |
| D4 | Banks flotantes | River_Bank_L/R soldados al terreno |
| D5 | Pendiente rota | Montaña (Y~98) → lago (Y~-3.2) monótona descendente |

---

# OBJETOS CANÓNICOS EN .blend (DEBEN EXISTIR O CREARSE)

Terreno:
  Terrain_Main, Mtn_Main

Agua SECA (geometría, no líquido):
  Lake_Basin, Lake_Bed, Lake_Shore, Lake_WetMud
  River_Channel, River_Bed, River_Bank_L, River_Bank_R

Gameplay markers:
  Sp_Player, Sp_Diablo, Sp_An01 … Sp_An24
  Mini_Cueva o Cave_Main

Cámaras QA (obligatorias):
  Cam_Air, Cam_Rural, Cam_Plain, Cam_Forest, Cam_Lake, Cam_Cave, Cam_Path

---

# CONSTANTES DE INTEGRACIÓN (MEDIR Y ACTUALIZAR — NO ASUMIR)

```gdscript
WATER_SURFACE_Y  = -3.2
LAKE_DEPTH       = 10.0    # geométrica mínima
RIVER_DEPTH      = 3.0     # geométrica mínima en todo el cauce
LAKE_CENTER      = Vector3(-150.347, -3.2, -144.866)  # verificar post-export
LAKE_RADIUS_X    = 60.0    # verificar
LAKE_RADIUS_Z    = 44.0    # verificar
```

Puente referencia Godot:
  BRIDGE_DECK ≈ (24.153, 17.724, -9.866)

Player spawn referencia:
  (98.416, 18.78, -65.96)

---

# PLAN DE EJECUCIÓN — 6 GATES (NO SALTAR)

## GATE 0 — Pre-flight
- [ ] pwd + git status
- [ ] Terreno_Finca.blend existe y abre sin error
- [ ] MCP Blender responde (ping socket 9876)
- [ ] Skills leídas
- [ ] Crear rama mental: NO Terrain3D

**STOP si:** blend corrupto o MCP muerto.

---

## GATE 1 — Auditoría forense (SOLO LECTURA)
Ejecutar y documentar:

- [ ] Bbox escena completa (ancho × largo × alto)
- [ ] ¿Escala ~447 m × 447 m (~20 ha)? Si no → reportar desviación %
- [ ] Listar TODAS las colecciones
- [ ] Listar meshes en radio lago: centro (-150, -145), radio 80 m
- [ ] Listar meshes a lo largo del río (montaña → lago)
- [ ] Contar objetos con MAT_Water o nombre *Water*
- [ ] Contar DefaultMaterial
- [ ] Detectar duplicados/overlaps (bbox intersectan en lago/río)
- [ ] Medir profundidad lago: 5 raycasts (centro, N, S, E, O)
- [ ] Medir profundidad río: mínimo 8 puntos equidistantes
- [ ] Screenshot Cam_Lake, Cam_Air, vista puente
- [ ] Tabla: objeto | tipo | bbox | material | problema

**STOP si:** no puedes medir profundidades numéricamente.

**Entregable Gate 1:** `AUDIT_REPORT.md` con tabla y mediciones.

---

## GATE 2 — Cirugía geometría lago
- [ ] Integrar Lake_Basin en terreno (método documentado: boolean/sculpt/join)
- [ ] Piso cuenca ≤ -13.2 m en centro (tolerancia +0.5 m)
- [ ] Eliminar mesh bed/basin duplicado en mismo volumen
- [ ] Lake_Shore + Lake_WetMud: transición sin cliff duro
- [ ] Eliminar/ocultar agua opaca blend en zona lago
- [ ] Re-medir 5 raycasts — pegar resultados

**STOP si:** profundidad centro < 9.5 m o overlap no resuelto.

---

## GATE 3 — Cirugía geometría río
- [ ] Cauce continuo montaña → lago (sin gaps)
- [ ] Profundidad ≥ 3.0 m en 8 puntos de muestreo
- [ ] River_Bank_L/R integradas (no flotantes)
- [ ] Lecho material MAT_Mud o grava — un mesh lecho, no apilado
- [ ] Tramo bajo puente: cavidad seca (sin mesh agua, sin bed overlap)
- [ ] Pendiente monótona descendente (documentar ΔY por tramo)
- [ ] Re-medir 8 puntos — pegar resultados

**STOP si:** cualquier punto < 2.7 m profundidad o gap en cauce.

---

## GATE 4 — Limpieza global
- [ ] Eliminar meshes bajo terreno (internal faces, duplicates)
- [ ] Props hundidos/flotantes: raycast snap a terreno
- [ ] Cueva: no bloque negro (MAT_Cave, entrada integrada en montaña)
- [ ] Materiales: audit completo — 0 external, 0 DefaultMaterial
- [ ] Spawns: Sp_Player fuera de agua/roca/árbol
- [ ] Cámaras QA posicionadas y funcionales
- [ ] Montaña opuesta al lago (layout 20 ha)

**STOP si:** DefaultMaterial visible o spawn inválido.

---

## GATE 5 — Export GLB
- [ ] Guardar Terreno_Finca.blend
- [ ] Export Terreno_Finca.glb (Y-up, scale 1.0, materiales embebidos)
- [ ] Ejecutar /blender-godot-export-validator
- [ ] Render QA: Cam_Lake, Cam_Air, Cam_Cave, Cam_Path
- [ ] Reporte export: tamaño, nº meshes, nº materiales, spawns presentes

**STOP si:** validator rechaza o falta spawn obligatorio.

---

## GATE 6 — Integración Godot (solo tras Gate 5 OK)

### Eliminar
- [ ] Level/Terrain3D
- [ ] assets/terrain/data/* (opcional archivar)
- [ ] water_visual.gd ribbons si no alinean a cauce medido
- [ ] structures_visual.gd / props_spawner.gd si GLB ya contiene assets

### Restaurar
- [ ] Level/Terreno_Finca ← instancia Terreno_Finca.glb
- [ ] Colisión terreno (trimesh o builder simplificado por nombre mesh)
- [ ] WaterVisual boujie alineado a cuenca/cauce MEDIDOS
- [ ] WaterGameplay: LakeArea + LakeDeep + RiverArea siguiendo forma real
- [ ] Recorte agua bajo puente
- [ ] SpawnPoints reubicados desde Sp_* del GLB si cambiaron

### Validar
- [ ] godot --headless -s res://tools/godot/validate_game_setup.gd → VALIDATION_OK
- [ ] Play: jugador en terreno spawn, no vacío
- [ ] Caminar mapa sin caer
- [ ] Nado coherente en lago/río
- [ ] Sin hueco negro bajo puente
- [ ] Screenshot MCP Godot editor + in-game

**STOP si:** VALIDATION_OK falla o jugador cae al vacío.

---

# CHECKLIST MAESTRA (100% O FRACASO)

## Blender — Geometría
- [ ] B1 Terreno único sin suelo apilado
- [ ] B2 Lago profundidad ≥ 10 m medida (centro)
- [ ] B3 Río profundidad ≥ 3 m en 8/8 puntos
- [ ] B4 Cero z-fighting lago
- [ ] B5 Cero z-fighting río
- [ ] B6 Cero mesh bajo mesh en cuenca
- [ ] B7 Cero mesh bajo mesh en cauce
- [ ] B8 Orillas suaves (no rectángulos duros)
- [ ] B9 Puente: cavidad seca debajo
- [ ] B10 Montaña + cueva integradas

## Blender — Export
- [ ] B11 Sin MAT_Water opaco en GLB
- [ ] B12 Sin DefaultMaterial
- [ ] B13 Texturas empaquetadas/locales
- [ ] B14 Spawns Sp_Player, Sp_Diablo, Sp_An01+ presentes
- [ ] B15 Cámaras QA presentes
- [ ] B16 GLB validator PASS
- [ ] B17 blend + glb guardados en paths correctos

## Godot — Integración
- [ ] G1 Terrain3D eliminado de main.tscn
- [ ] G2 Terreno_Finca.glb instanciado
- [ ] G3 Colisión terreno funciona (layer 2)
- [ ] G4 Agua visual en cuenca/cauce (no flotando)
- [ ] G5 WaterGameplay alineado
- [ ] G6 Sin doble suelo
- [ ] G7 Spawns válidos
- [ ] G8 VALIDATION_OK
- [ ] G9 Play test sin vacío bajo pies
- [ ] G10 Puente sin agua atravesando

## Documentación
- [ ] D1 AUDIT_REPORT con mediciones antes
- [ ] D2 FIX_REPORT con mediciones después
- [ ] D3 Screenshots Cam_Lake + Cam_Air + puente + in-game
- [ ] D4 Constantes Godot actualizadas (lista)
- [ ] D5 Riesgos pendientes honestos

---

# FORMATO DE RESPUESTA OBLIGATORIO

Cada gate termina con:

```
## GATE N — [NOMBRE]
Estado: PASS | FAIL
Mediciones:
  - lago_centro_profundidad: X.X m
  - rio_punto_1..8: [lista]
  - bbox_escena: X × Y × Z
Fixes aplicados: [lista]
Archivos tocados: [lista]
Screenshots: [paths]
Bloqueadores: [si FAIL]
```

Al final:

```
## VEREDICTO FINAL
Estado: APROBADO | RECHAZADO
Checklist: XX/32 PASS
GLB: path + tamaño
VALIDATION_OK: sí/no
Riesgos restantes: [lista o "ninguno"]
```

---

# ANTI-PATTERNS (INSTANT FAIL)

- "Parece correcto" sin número
- Exportar sin medir profundidad
- Dejar Terrain3D en main.tscn
- Dejar ribbons water_visual sin alinear
- Apilar Bed + Basin + Terrain en mismo XY
- Agua opaca en GLB
- Saltarse un gate
- Modificar gameplay scripts sin permiso
- Commit automático

---

# ORDEN DE ARRANQUE

1. Lee skills.
2. Gate 0 pre-flight.
3. Gate 1 auditoría — NO edites hasta tener AUDIT_REPORT.
4. Gates 2-4 cirugía Blender.
5. Gate 5 export.
6. Gate 6 Godot.
7. Checklist maestra 32/32.
8. Veredicto final.

EMPIEZA AHORA. Gate 0. Sin prosa. Solo hechos y números.
```

---

## Uso

1. Copiar bloque `PROMPT` completo a Claude Opus 4.8.
2. Blender abierto con `Terreno_Finca.blend` + MCP activo (9876).
3. Godot opcional en Gate 6.
4. Exigir checklist 32/32 antes de aceptar entrega.
