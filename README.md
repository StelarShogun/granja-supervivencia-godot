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
  characters/         Escenas del jugador y enemigos.
  animals/            Escenas de animales recolectables.
  ui/                 Menús, HUD y pantallas.
scripts/
  managers/           GameManager, control de partida, spawns y estados.
  player/             Movimiento, cámara y vida del jugador.
  enemies/            Persecución e IA del Diablo.
  animals/            Recolección y lógica de animales.
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

- Crear escena del jugador en `scenes/characters/player/`.
- Crear escena del enemigo en `scenes/characters/enemies/`.
- Crear animales recolectables en `scenes/animals/`.
- Crear `GameManager.gd` en `scripts/managers/`.
- Crear HUD en `scenes/ui/`.
- Configurar colisiones del terreno y props.
- Crear spawns en el mapa usando los marcadores del modelo 3D.
