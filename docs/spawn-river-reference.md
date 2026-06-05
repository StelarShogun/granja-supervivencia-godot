# Referencia SpawnPoints y River Path — pre-rebuild

Capturado de `scenes/levels/main.tscn` en commit d3cbae0 (checkpoint 0.4).
Usar para reubicar markers en Fase 7 tras Terrain3D.

## SpawnPoints (coordenadas Godot X,Y,Z)

| Marker | X | Y | Z | Notas |
|--------|---|---|---|-------|
| Player_Spawn | 98.416 | 13.35 | -65.96 | Zona rural finca |
| Diablo_Spawn | 145.653 | 99.3 | 132.134 | Cueva montaña |
| Diablo_Cave_Spawn | 145.653 | 99.3 | 132.134 | Idem |
| AnimalSpawn_01 | -45.347 | 2.95 | 35.134 | Planicie SW |
| AnimalSpawn_02 | -18.347 | 5.9 | 20.134 | Planicie centro |
| AnimalSpawn_03 | -58.347 | 2.5 | -2.866 | Planicie W |
| AnimalSpawn_04 | -34.347 | 4.15 | -11.866 | Planicie W |
| AnimalSpawn_05 | -70.347 | 1.45 | 22.134 | Planicie SW |
| AnimalSpawn_06 | -8.347 | 12.6 | 58.134 | Camino norte |
| AnimalSpawn_07 | 53.653 | 17.2 | -45.866 | Rural/bosque |
| AnimalSpawn_08 | 81.653 | 16.4 | -53.866 | Rural E |
| AnimalSpawn_09 | 111.653 | 10.5 | -77.866 | Rural E |
| AnimalSpawn_10 | 27.653 | 7.15 | -95.866 | Rural S |
| CorralZone | 124.653 | 6.8 | -113.366 | Corral zona rural |
| SafeCorralZone | 124.653 | 7.0 | -113.366 | Idem |
| MudTrap_01 | 29.653 | 17.86 | -30.549 | Camino finca |
| MudTrap_02 | 14.0 | 40.0 | -6.0 | Pendiente media |
| MudTrap_03 | -22.0 | 40.0 | 28.0 | Pendiente norte |
| BridgeTrigger | 24.153 | 16.2 | -9.866 | Puente |

## River Path — 8 puntos Curve3D (Godot X,Y,Z)

```
pt0: (149.653, 98.0,   132.134)   # boca cueva / nacimiento
pt1: (119.653, 71.0,    95.134)   # pendiente alta montaña
pt2: ( 81.653, 38.0,    48.134)   # bajada media
pt3: ( 33.653, 12.0,   -17.866)   # planicie alta
pt4: (-28.347,  4.0,   -57.866)   # planicie baja
pt5: (-78.347, -4.0,   -89.866)   # aproximación lago
pt6: (-112.347, -5.2,  -117.866)  # orilla lago
pt7: (-150.347, -4.2,  -144.866)  # desembocadura lago
```

`water_surface_y` en desembocadura = **-4.2**  
`LAKE_CENTER` = Vector3(-150.347, -3.2, -144.866)

## Notas de biomas observados (GLB de referencia)

- **Rural / finca**: zona E, spawn en (98, 13, -66), corral en (124, 7, -113)
- **Planicie**: centro-SW, animales 01-05, cotas bajas Y=1-6
- **Montaña**: NE, Y=38-98, cueva alrededor de (145, 99, 132)
- **Lago**: zona W, center (-150, -3.2, -145), radio ~60×44 m
- **Río**: de (149, 98, 132) a (-150, -4.2, -145), ~8 puntos

## Colliders de InteractiveObjects a conservar

```
Barn_01           → (144.653, 7.935, -134.866)  # granero finca
BridgeTrigger     → (24.153, 16.2, -9.866)
MudTrap_01-03     → ver tabla arriba
CorralZone/Safe   → (124.653, 6.8-7.0, -113.366)
```
