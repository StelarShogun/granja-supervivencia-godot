# Estructura del proyecto

Este proyecto está ordenado para trabajar en Godot 4 y GitHub.

```text
assets/                 Recursos fuente del juego.
  models/               Modelos 3D GLB/FBX.
  textures/             Texturas de modelos, entorno y UI.
  materials/            Materiales externos si se crean como .tres.
  audio/                Música y efectos de sonido.
  icons/                Íconos del proyecto.
  fonts/                Fuentes tipográficas.
scenes/                 Escenas .tscn de Godot.
  levels/               Escenas principales de mapa o nivel.
  characters/           Escenas de jugador y enemigos.
  animals/              Escenas de animales recolectables.
  ui/                   Interfaz, menús y HUD.
scripts/                Scripts GDScript.
  managers/             GameManager, control de partida, spawns.
  player/               Movimiento y lógica del jugador.
  enemies/              IA básica del Diablo u otros enemigos.
  animals/              Recolección y comportamiento de animales.
  ui/                   HUD, menús, mensajes.
  utils/                Funciones auxiliares.
shaders/                Shaders propios.
addons/                 Plugins de Godot.
docs/                   Documentación del equipo.
tools/                  Scripts externos, por ejemplo Blender Python.
exports/                Builds generadas. Normalmente no se versionan.
```
