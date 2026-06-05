# Plan completo: Rebuild del mapa — Granja Supervivencia

**Proyecto:** Godot 4 — `granja-supervivencia-godot`  
**Fecha:** 2026-06-05  
**Objetivo:** Borrar el mapa actual (GLB + capas de agua rotas) y reconstruir desde cero con **Terrain3D**, **Asset Placer**, **GoBuild** y **boujie_water_shader** (Claude Code), manteniendo la idea del terreno y eliminando errores visuales/físicos del agua.

---

## 1. Contexto y diagnóstico

### 1.1 Problemas del mapa actual

| Síntoma | Causa raíz |
|---------|------------|
| Río/lago no se sienten parte del mapa | Láminas planas (`river_generator`, `lake_generator`) sobre terreno GLB independiente |
| Física de agua rara, múltiples capas | 7+ `CollisionShape3D` en `RiverWaterArea` + zonas profundas duplicadas |
| Huecos negros bajo puente | Desalineación visual/colisión/agua |
| Hierba/props flotando | `grass_spawner` + `water_deco_reproject` parchean un GLB mal alineado |
| Barra negra en horizonte | Planos lejanos, farplane océano, o meshes horizontales huérfanos |
| Doble suelo | `Terrain_BasicCollision` (caja Y=-20) + trimesh del GLB |

### 1.2 Arquitectura actual a eliminar

- `Level/Terreno_Finca` (GLB)
- `Level/Terrain_BasicCollision`
- `WaterSystem` completo (generadores + `WaterAreas` actuales)
- `TerrainOverride`, `WaterDecoReproject`, `GrassSpawner`, `GoBuildCube`
- Materiales: `MAT_River_Flow.tres`, `MAT_Lake_Water.tres` (tras boujie)
- Scripts atados al GLB:
  - `scripts/core/terrain_collision_builder.gd`
  - `scripts/world/terrain_material_override.gd`
  - `scripts/world/water_deco_reproject.gd`

### 1.3 Qué se conserva (gameplay)

- `SpawnPoints/*` (reubicar al final)
- `Player`, `Diablo`, `GameManager`, `Animals`
- `InteractiveObjects` (corral, barro, puente)
- `UI`, `PauseMenu`, `VictoryScreen`
- `MapBounds` (muros del borde)
- `Sky3D` / iluminación
- `scripts/interactives/water_area.gd` (simplificado)
- `scripts/player/player.gd` (mecánica oxígeno/agua)

---

## 2. División de trabajo

### 2.1 Claude Code — Agua visual (boujie_water_shader)

**Addon:** `res://addons/boujie_water_shader/`  
**Referencia:** `example/boujie_water_shader/water_shader_examples.tscn`

| Tarea | Detalle |
|-------|---------|
| Lago | `Ocean` o prefab acotado; sin océano infinito |
| Río | Mesh custom con material boujie siguiendo cauce |
| Materiales | `WaterMaterialDesigner`, `deep_ocean_material.tres` |
| Shore foam | Contra colisión Terrain3D (layer 2) |
| LOD | Mínimo necesario; evitar farplane al horizonte en mapa finito |
| Sin colisión | Meshes boujie solo visuales |

**No toca:** Terrain3D, props, spawns, `Area3D` de gameplay.

### 2.2 Terreno y mundo

| Tarea | Herramienta |
|-------|-------------|
| Terreno único + colisión | Terrain3D |
| Árboles, rocas, juncos | Asset Placer |
| Corral, granero, puente, cueva | GoBuild |
| Física agua jugador | `water_area.gd` (simplificado) |
| Reposicionar spawns | Editor |
| Limpieza scripts viejos | Repo |

---

## 3. Contrato de integración (Terrain ↔ Boujie)

### 3.1 Constantes acordadas

```gdscript
# Valores iniciales — ajustar tras esculpir Terrain3D
const LAKE_CENTER     := Vector3(-150.347, -3.2, -144.866)
const LAKE_RADIUS_X   := 60.0
const LAKE_RADIUS_Z   := 44.0
const WATER_SURFACE_Y := -3.2
const RIVER_DEPTH     := 3.0   # profundidad cauce respecto a orilla
const LAKE_DEPTH      := 10.0  # profundidad cuenca respecto a superficie
```

### 3.2 Reglas

1. **Una sola cota** `WATER_SURFACE_Y` para lago y desembocadura del río.
2. Boujie = solo visual; gameplay = `Area3D` separados.
3. Bajo el **puente**: sin volumen de agua (ni visual atravesando collider).
4. Terrain3D esculpido **antes** de posicionar meshes boujie finales.
5. `river_path`: `Curve3D` o `PackedVector3Array` exportada desde Terrain3D/cauce.

### 3.3 Entregables Claude Code → Terreno

- Nodos en `main.tscn`: `WaterVisual/Lake`, `WaterVisual/River`
- Material `.tres` usados
- `water_surface_y` confirmado
- Lista de meshes sin colisión

### 3.4 Entregables Terreno → Claude Code

- Terreno esculpido con cuenca y cauce
- `river_path` final
- `lake_center` y radios medidos
- Puente GoBuild con posición final

---

## 4. Fases de implementación

### Fase 0 — Backup y preparación

- [ ] Commit o branch: `feature/terrain3d-rebuild`
- [ ] Exportar posiciones actuales de `SpawnPoints` (referencia)
- [ ] Archivar `Terreno_Finca.glb` como referencia de layout (no activo)
- [ ] Documentar cotas actuales del río (8 puntos en `river_generator.gd`)

**Criterio de salida:** branch limpio, referencias guardadas.

---

### Fase 1 — Limpieza de `main.tscn`

**Eliminar nodos:**

```
Level/Terreno_Finca
Level/Terrain_BasicCollision
WaterSystem (completo)
TerrainOverride
WaterDecoReproject
GrassSpawner
GoBuildCube
```

**Mantener sin cambios de script:**

```
SpawnPoints, Player, Diablo, GameManager, Animals
InteractiveObjects, UI, PauseMenu, VictoryScreen
MapBounds, Sky3D
```

**Criterio de salida:** escena carga sin errores; jugador cae al vacío (esperado hasta Fase 2).

---

### Fase 2 — Terrain3D (terreno base)

**Setup:**

- [ ] Añadir nodo `Terrain3D` bajo `Level/`
- [ ] Región ~512×512 m (≈20 ha)
- [ ] Physics layer **2 (World)**
- [ ] Texturas: hierba, tierra, roca, barro (mínimo 4)

**Esculpir biomas:**

| Zona | Ubicación aprox. | Notas |
|------|------------------|-------|
| Rural | Este, media altura | Spawn jugador, corral |
| Planicie | Centro-oeste | Animales progresión 2 |
| Bosque | Norte/oeste | Irregular, pendientes suaves |
| Montaña | Noreste | Alta, opuesta al lago |
| Cuenca lago | `LAKE_CENTER` | Depresión ~10 m bajo superficie |
| Cauce río | Montaña → lago | Canal ~3 m, curva natural |
| Cueva | En montaña | Entrada visible, interior oscuro |

**Validación Fase 2:**

- [ ] Caminar todo el mapa sin caer al vacío
- [ ] Profundidad lago ≥ 10 m (medir con raycast/debug)
- [ ] Profundidad río ≥ 3 m en tramos centrales
- [ ] Sin planos planos gigantes (>100 m sin relieve)
- [ ] Colisión = visual (un solo suelo)

---

### Fase 3 — Agua visual boujie (Claude Code)

**Brief:**

> Integrar `boujie_water_shader` en `scenes/levels/main.tscn`.
> Reemplazar sistema viejo de agua visual.
> Lago: `Ocean` acotado en `LAKE_CENTER`, radio ~60×44, Y=`WATER_SURFACE_Y`.
> Río: mesh siguiendo `river_path`, material boujie, olas suaves.
> Sin océano infinito ni farplane que corte horizonte.
> Shore foam contra Terrain3D layer 2.
> Sin colisión en meshes de agua.
> Referencia: `example/boujie_water_shader/water_shader_examples.tscn`.

**Checklist:**

- [ ] `WaterVisual/Lake` montado y alineado a cuenca
- [ ] `WaterVisual/River` sigue cauce esculpido
- [ ] Sin z-fighting con orillas Terrain3D
- [ ] Sin barra negra en horizonte
- [ ] Materiales guardados en `materials/`
- [ ] `MAT_River_Flow` y `MAT_Lake_Water` deprecados

**Criterio de salida:** agua se ve integrada; jugador aún no interactúa (Fase 4).

---

### Fase 4 — Agua gameplay (física simplificada)

**Reemplazar** las 7+ cajas del río por estructura mínima:

```
WaterGameplay/
  LakeArea          → water_area.gd, deep_water=false (orilla)
  LakeDeepArea      → water_area.gd, deep_water=true (centro)
  RiverArea         → water_area.gd, 1-3 CollisionShape3D siguiendo cauce
  RiverDeepArea     → opcional, tramos embovedados
```

**Configuración `water_area.gd`:**

- `collision_layer = 16` (Water)
- `collision_mask = 1` (Player)
- `water_surface_y = WATER_SURFACE_Y`

**Puente:**

- [ ] Recortar `RiverArea` bajo collider del puente
- [ ] O excluir tramo con shape hueco

**Integración jugador:**

- [ ] Oxígeno drena en `deep_water`
- [ ] `underwater_effect.gd` visible al sumergirse
- [ ] Velocidad reducida en agua somera

**Criterio de salida:** entrar/salir agua coherente; sin flotar; sin daño en orilla seca.

---

### Fase 5 — Estructuras GoBuild

| Estructura | Ubicación | Colisión |
|------------|-----------|----------|
| Corral | Zona rural, cerca spawn | StaticBody3D layer 2 |
| Granero | Rural | StaticBody3D |
| Puente | Cruce río | Ramp + deck; sin agua debajo |
| Boca cueva | Montaña | Rocks/labios GoBuild |
| Cerca tramos | Rural/planicie | Opcional |

**Criterio de salida:** puente caminable; corral coincide con `CorralZone` y `SafeCorralZone`.

---

### Fase 6 — Props Asset Placer

| Bioma | Props |
|-------|-------|
| Bosque | Árboles conos, troncos |
| Planicie | Rocas pequeñas, arbustos |
| Orillas agua | Juncos, rocas |
| Rural | Heno, cercas, detalle finca |

**Criterio de salida:** sin props flotando; distribución por bioma coherente.

---

### Fase 7 — Gameplay markers y spawns

| Marker | Zona objetivo |
|--------|---------------|
| `Player_Spawn` | Rural, cerca corral |
| `AnimalSpawn_01-03` | Rural |
| `AnimalSpawn_04-06` | Planicie / lago |
| `AnimalSpawn_07-10` | Bosque / montaña |
| `Diablo_Cave_Spawn` | Interior/entrada cueva |
| `CorralZone` | Dentro corral GoBuild |
| `SafeCorralZone` | Misma zona corral |
| `MudTrap_01-03` | Caminos barro |
| `BridgeTrigger` | Sobre puente |

**Criterio de salida:** partida completa jugable de spawn a victoria.

---

### Fase 8 — Limpieza código y validación

**Scripts a eliminar:**

```
scripts/core/terrain_collision_builder.gd
scripts/world/terrain_material_override.gd
scripts/world/water_deco_reproject.gd
scripts/world/river_generator.gd
scripts/world/lake_generator.gd
```

**Actualizar:**

- [ ] `tools/godot/validate_game_setup.gd` — rutas nuevas
- [ ] `.gdignore` / `.gitignore` — excluir Terrain3D cache
- [ ] `AGENTS.md` — pipeline Terrain3D en lugar de GLB

**Tests manuales:**

- [ ] WASD + cámara en todo el mapa
- [ ] Recolectar 10 animales → victoria
- [ ] Diablo persigue; zona segura corral funciona
- [ ] Ahogamiento en lago profundo
- [ ] Barro ralentiza
- [ ] Pausa / guardar / continuar
- [ ] Sin barra negra, sin agua flotante, sin física rara

---

## 5. Criterios de aceptación finales (QA)

### Visual

- [ ] Un solo terreno visible (Terrain3D)
- [ ] Agua boujie alineada a cuenca y cauce
- [ ] Orillas con transición creíble (foam + textura barro)
- [ ] Sin meshes del GLB viejo visibles
- [ ] Cielo/niebla coherente (sin barra negra)

### Física

- [ ] Un solo suelo caminable
- [ ] Agua: entrar/salir sin bugs
- [ ] Puente: sin volumen agua invisible debajo
- [ ] Colisión Terrain3D layer 2 en todo el mapa

### Gameplay (requisitos CLAUDE.md)

- [ ] 3 progresiones por animales (3/6/10)
- [ ] Corral, barro, puente interactivos
- [ ] Cueva con spawn Diablo
- [ ] 20 ha aproximados explorables
- [ ] Zonas: rural, planicie, bosque, lago, montaña/cueva

---

## 6. Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Boujie océano infinito corta horizonte | `Ocean` local sin farplane |
| Desfase Terrain3D / boujie | Congelar `WATER_SURFACE_Y` en Fase 2 |
| Spawns en el vacío | Reubicar solo en Fase 7 |
| Dos flujos pisan `main.tscn` | Fases separadas; boujie solo en `WaterVisual/` |
| Rendimiento hierba | Asset Placer con LOD; grass spawner off |

---

## 7. Archivos clave

| Ruta | Rol |
|------|-----|
| `scenes/levels/main.tscn` | Escena principal |
| `addons/terrain_3d/` | Terreno editable |
| `addons/asset_placer/` | Colocación props |
| `addons/go_build/` | Estructuras |
| `addons/boujie_water_shader/` | Agua visual |
| `scripts/interactives/water_area.gd` | Gameplay agua |
| `scripts/player/player.gd` | Oxígeno, movimiento agua |
| `tools/godot/validate_game_setup.gd` | CI local |
| `docs/plan-rebuild-mapa.md` | Este documento |
