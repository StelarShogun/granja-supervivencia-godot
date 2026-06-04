# Granja Supervivencia Godot

Proyecto 3D en **Godot 4**. El juego consiste en recorrer una finca, recolectar animales y evitar que el enemigo alcance al jugador.

## Requisitos

- Godot 4.x. El proyecto fue creado con configuración de Godot 4.6; si es posible, usen la misma versión o una 4.x compatible.
- Git.
- Git LFS para manejar modelos, texturas y audio pesados.

## Cómo descargar el proyecto

```bash
git clone https://github.com/StelarShogun/granja-supervivencia-godot.git
cd granja-supervivencia-godot
git lfs install
git lfs pull
```

## Cómo abrirlo en Godot

1. Abrir Godot.
2. Seleccionar **Import**.
3. Buscar la carpeta del repositorio.
4. Seleccionar el archivo `project.godot`.
5. Abrir la escena principal:

```text
res://scenes/levels/main.tscn
```

6. Presionar **F5** para ejecutar el proyecto completo o **F6** para ejecutar la escena actual.

## Escena principal

La escena principal configurada es:

```text
res://scenes/levels/main.tscn
```

El mapa base se encuentra en:

```text
res://assets/models/environment/Terreno_Finca.glb
```

## Estado actual de juego

El juego inicia en un menú principal con opciones de continuar, nueva partida, ajustes y salir.

Objetivo: recolectar animales dispersos por la finca y llevarlos al corral mientras se evita a El Diablo.

Controles: WASD mueve al jugador, el mouse rota la camara, Shift corre, Espacio salta, Ctrl se agacha, E interactua y Esc abre pausa/libera el mouse.

Reglas: el jugador inicia con 3 vidas visibles como corazones. Cada animal aumenta el contador del corral. La progresion sube desde 3 y 6 animales; la victoria ocurre al llegar a 10 animales. La derrota ocurre cuando las vidas llegan a 0.

El Diablo permanece oculto al inicio y aparece despues de 1 minuto en la cueva de la montana, con aviso central en pantalla.

La UI usa corazones, texto de animales y paneles simples; no muestra puntos. Animales y progresion aparecen arriba a la derecha. Hay ciclo dia/noche y ajustes basicos de volumen/controles.

Escenas principales: `scenes/ui/main_menu.tscn`, `scenes/levels/main.tscn`, `scenes/ui/hud.tscn`, `scenes/ui/settings_menu.tscn`, `scenes/ui/pause_menu.tscn`, `scenes/player/player.tscn`, `scenes/enemies/diablo.tscn`, `scenes/animals/animal.tscn` e interactivos en `scenes/interactives/`.

Como ejecutar: abrir el proyecto en Godot y presionar **F5**, o ejecutar `godot --path .` desde la carpeta del proyecto.

## Sistemas actuales

- El agua visible la genera Godot: `WaterSystem/RiverSystem` usa `Path3D` + `scripts/world/river_generator.gd` para construir una malla ribbon animada con `materials/MAT_River_Flow.tres`; `WaterSystem/LakeSystem` usa `scripts/world/lake_generator.gd` para una malla irregular de lago con `materials/MAT_Lake_Water.tres`. El GLB conserva cuenca, lecho, orillas y barro, pero ya no contiene el agua vieja confusa.
- `WaterSystem/WaterAreas` contiene solo `Area3D` + `CollisionShape3D` invisibles. `LakeWaterArea` y `RiverWaterArea` son someros; el oxigeno solo baja en `LakeDeepZone` y `RiverDeepZone`, alineados con agua profunda visible.
- Se descarto cualquier sistema de agua externo dependiente de C#/.NET. Boujie Water Shader se evaluo pero es un shader de oceano; se uso el shader propio low poly. Juice Shaders Lite no esta instalado en `addons/`, por lo que no se uso.
- El bloque gris venia de fog runtime/volumen de cielo viejo: `Sky3D` queda como unico `WorldEnvironment`, `scripts/core/sky_controller.gd` fuerza fog apagado y oculta mallas `_FogMeshI`/neblina si Sky3D las genera.
- `Terreno_Finca.blend` se rehizo en las zonas de agua: `Lake_Basin`, `Lake_Bed`, `Lake_Shore`, `Lake_WetMud`, `River_Channel`, `River_Bed`, `River_Bank_L`, `River_Bank_R`, rocas, juncos, puente y vegetacion de orilla usan materiales low poly con texturas locales de `assets/textures/environment/`.
- El jugador tiene oxigeno, reduccion de velocidad en agua, hundimiento simple y dano por ahogamiento solo en agua profunda.
- El HUD muestra una barra azul de oxigeno solo cuando el jugador esta en agua profunda o recuperando aire.
- Las trampas de barro (`MudTrap_01..03`) son visibles en el GLB con barro oscuro irregular, y cada `Area3D` esta reposicionada sobre su parche visible; el visual cuadrado de la escena de barro se mantiene oculto para no duplicar barro falso.
- El corral tiene `SafeCorralZone`: dentro del corral El Diablo deja de perseguir y no puede entrar.
- El escenario tiene colisiones para terreno, montana, limites del mapa, cercas, portones, puente, muelle, corral, granero, cueva, rocas medianas y grandes, troncos caidos (`Log_`), arboles altos y arboles del bosque (tronco). Las genera `terrain_collision_builder.gd` por nombre de malla del GLB mas colliders manuales en `ScenarioColliders`.
- La camara en tercera persona usa `SpringArm3D` con colision contra la capa World (mascara 2), de modo que no atraviesa terreno, montana, rocas, cercas ni estructuras y no deja ver bajo el suelo. El pitch esta limitado a `[-55, 35]` grados, el `near` de la camara es `0.05` y el mouse (no WASD) rota la vista.
- El Diablo usa `CharacterBody3D.move_and_slide()` con mascara World + Player, queda bloqueado por cercas y obstaculos, y se detiene fuera del corral cuando el jugador esta en `SafeCorralZone` (mensaje "Zona segura: El Diablo no puede entrar.").
- El cielo y el ciclo dia/noche los maneja **Sky3D** (nodo `Sky3D`, un `WorldEnvironment`), que aporta sol, luna, estrellas, nubes y horizonte. `scripts/core/sky_controller.gd` lo configura en tiempo de ejecucion (dia completo en 5 minutos, hora inicial 9:00, energias de sol/luna y fog en `0.0`). Es el unico `WorldEnvironment`; reemplaza al antiguo `WorldEnvironment` + `DayNightCycle`.
- El sistema de clima externo anterior fue eliminado del proyecto. No queda plugin activo, escena de clima, recurso de clima, gestor de ambiente, niebla volumetrica ni script runtime que modifique clima/nubes/fog.
- Plugins activos utiles: Godot AI/MCP para inspeccion y validacion; Sky3D para cielo y dia/noche. GDTerrainGenerator, Terrain3D y Third Person Camera permanecen instalados. No se agrego dependencia nueva para el agua.
- El jugador puede saltar (Espacio) y agacharse (Ctrl). Al agacharse baja la altura de la capsula y de la camara, reduce la velocidad y no se levanta si hay techo encima (chequeo de rayo contra la capa World). No se puede saltar dentro del agua ni agachado.
- Controles: WASD mover, mouse camara, Shift correr, Espacio saltar, Ctrl agacharse, E interactuar, Esc pausa.

## Estructura de carpetas

```text
assets/
  models/
    environment/      Mapas, finca, terreno, cuevas, props grandes.
    characters/       Modelos del jugador y enemigos.
    animals/          Modelos de vacas, gallinas, ovejas y otros animales.
  textures/
    environment/      Texturas del terreno, madera, agua, rocas y vegetación.
    characters/       Texturas de personajes.
    ui/               Texturas para interfaz.
  materials/          Materiales externos si se crean como recursos .tres.
  audio/
    music/            Música de fondo.
    sfx/              Efectos de sonido.
  icons/              Íconos del proyecto.
  fonts/              Fuentes.
scenes/
  levels/             Escenas principales del mapa.
  player/             Escena y placeholders del jugador.
  enemies/            Escena de El Diablo.
  animals/            Escenas de animales recolectables.
  interactives/       Puerta, barro, plataforma y otros objetos.
  ui/                 Menús, HUD y pantallas.
scripts/
  core/               GameManager, control de partida, spawns y estados.
  player/             Movimiento, cámara y vida del jugador.
  enemies/            Persecución e IA del Diablo.
  animals/            Recolección y lógica de animales.
  interactives/       Lógica de objetos interactivos.
  ui/                 Contadores, vidas y mensajes.
  utils/              Funciones auxiliares.
shaders/              Shaders personalizados.
addons/               Plugins de Godot.
docs/                 Documentación del proyecto.
tools/blender/        Scripts de Blender para generar o mejorar mapas.
exports/              Builds generadas. No se deben subir salvo indicación del equipo.
```

## Reglas para trabajar en equipo

Antes de empezar a trabajar:

```bash
git pull
git lfs pull
```

Después de hacer cambios:

```bash
git status
git add .
git commit -m "Descripcion clara del cambio"
git push
```

No trabajen dos personas al mismo tiempo sobre la misma escena grande, por ejemplo `main.tscn`, porque pueden aparecer conflictos difíciles de resolver. Es mejor dividir tareas:

- Persona 1: mapa, terreno y props.
- Persona 2: jugador, cámara y controles.
- Persona 3: animales y sistema de recolección.
- Persona 4: enemigo, persecución y vidas.
- Persona 5: UI, sonidos y menú.

## Ramas recomendadas

Crear una rama por tarea:

```bash
git checkout -b mejora-mapa
```

Subir la rama:

```bash
git add .
git commit -m "Mejorar mapa de la finca"
git push -u origin mejora-mapa
```

Luego se une a `main` mediante Pull Request en GitHub.

## Qué no se debe subir

No subir carpetas de caché del editor ni builds temporales:

```text
.godot/
.import/
exports/
*.blend1
*.blend2
```

El archivo `.gitignore` ya está preparado para ignorar esos elementos.

## Archivos grandes

El proyecto usa Git LFS para modelos, texturas y audio. Si algún compañero ve archivos incompletos o muy pequeños, debe ejecutar:

```bash
git lfs install
git lfs pull
```

Tipos de archivo manejados por LFS:

```text
.glb, .gltf, .fbx, .blend, .png, .jpg, .jpeg, .wav, .mp3, .ogg, .webp
```

## Convenciones de nombres

Usar nombres claros y sin espacios cuando sea posible:

```text
Player.tscn
Diablo.tscn
Animal_Vaca.tscn
GameManager.gd
Terreno_Finca.glb
```

## Pendientes sugeridos

- Ajustar visualmente los spawns temporales cuando se actualice `Terreno_Finca.glb`.
- Reemplazar placeholders del jugador, animales e Diablo por modelos finales.
- Refinar colisiones del terreno y estructuras grandes del mapa final.
- Agregar sonidos simples para recoleccion, dano y victoria/derrota.
