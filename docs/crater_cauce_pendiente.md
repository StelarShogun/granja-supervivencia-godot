# Cráter / cauce profundo — trabajo pendiente en Blender

## Estado

No intervenido en esta tanda. La corrección de las paredes del cráter y del
cauce profundo exige editar la geometría del terreno en
`assets/models/environment/Terreno_Finca.blend` y reexportar
`Terreno_Finca.glb`. Es una operación de riesgo alto: la malla `Terrain_Main`
es la misma que provee colisión de navegación, spawns y el apoyo del puente.
Editarla a ciegas, sin validación visual en gameplay real, puede romper zonas
jugables protegidas. Por eso se documenta en lugar de aplicarse sin verificar.

## Problemas observados (video)

- Paredes del cráter/cauce casi verticales (aspecto de cilindro/cortina).
- Textura estirada verticalmente, se lee como patrón repetido.
- Borde superior cortado en seco, sin transición.
- Saltos duros entre pasto / tierra / roca.

## Plan recomendado (sesión Blender)

Ejecutar con `/blender-terrain-worldbuilder` + `/blender-level-design-qa`.

1. **Backup**: duplicar `Terreno_Finca.blend` antes de tocar nada.
2. **Selección acotada**: aislar solo los anillos de vértices de la pared del
   cráter y de las orillas del cauce profundo. No tocar el resto de
   `Terrain_Main`.
3. **Suavizar borde superior**: bisel/`Bevel` ligero + un par de loops de
   transición para que el labio del cráter caiga en pendiente, no en corte.
4. **Pendiente / terrazas**: reducir el ángulo de pared a ~45–60° mediante
   2–3 escalones (terrazas) en vez de una caída recta. Mantener la profundidad
   actual del fondo (cota Y inferior sin cambios).
5. **Rocas integradas**: insertar props de roca low-poly embebidos en la pared
   (no flotantes) para quebrar la silueta. Usar los packs de roca ya presentes
   en el repo; evitar nuevas dependencias.
6. **UV / material**: reproyectar UV de las paredes (box/triplanar) para
   eliminar el estirado vertical; mezclar material roca con tierra húmeda
   (`rock_face_03`, `brown_mud_02/03` ya importados) en la franja de
   transición.
7. **Transiciones**: añadir un anillo de vértices intermedio pasto→tierra→roca
   con peso de material gradual, en vez del corte actual.

## Restricciones (no romper)

- No mover ni borrar `Terrain_Main` ni `Mtn_Main`.
- No mover spawns, corral, puente, mud traps ni triggers.
- No cambiar la profundidad del fondo del cráter/cauce.
- Conservar nombres cortos y export GLB Godot-ready.

## Validación obligatoria tras editar

1. `/blender-godot-export-validator` antes de exportar el GLB.
2. Reimportar en Godot y correr `tools/godot/smoke_main.gd`
   (`godot --headless --script tools/godot/smoke_main.gd`) para confirmar que
   la escena principal sigue cargando y la vegetación se siembra.
3. Validar spawns/suelo con los QA existentes
   (`tools/godot/check_spawn_ground.gd`, `qa_animals_ground.gd`).
4. Inspección visual en gameplay real: borde, fondo y a distancia del cráter,
   y recorrido del cauce + puente.
