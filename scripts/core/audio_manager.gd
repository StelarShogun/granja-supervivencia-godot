extends Node

# ─────────────────────────────────────────────
# AudioManager — autoload singleton
#
# Responsabilidades:
#   • Música del menú (única fuente durante el menú)
#   • Capas de ambiente por peso 0-1 con fade suave
#   • Pool de SFX one-shot sin posición (portón, pasos, salto, progresión)
#   • API para que AmbientAudioController ajuste pesos cada frame
#
# Reglas de diseño:
#   • Ningún sonido se reproduce sin que exista una causa explícita.
#   • _gameplay_active actúa como interruptor global del sistema de juego.
#   • Los streams en loop nunca se reasignan si el path no cambió.
# ─────────────────────────────────────────────

const SETTINGS_PATH := "user://settings.json"

# ── archivos ──────────────────────────────────
const MUSIC_MENU  := "res://assets/audio/music/Música en general.mp3"
const AMB_BIRDS   := "res://assets/audio/music/Múscia pájaros cantando.mp3"
const AMB_CICADAS := "res://assets/audio/music/Música chicharras.mp3"
const AMB_CORRAL  := "res://assets/audio/music/Música Cerca de animales.mp3"
const AMB_STREAM  := "res://assets/audio/sfx/riachuelo.mp3"
const AMB_WIND    := "res://assets/audio/sfx/viento de fondo.mp3"

const SFX_FOOTSTEP := "res://assets/audio/sfx/pasos sobre tierra.mp3"
const SFX_GATE     := "res://assets/audio/sfx/abrir y cerrar portón.mp3"
const SFX_PROGRESS := "res://assets/audio/sfx/progresión.mp3"

# SFX dedicados (sintetizados). Reemplazan los placeholders con pitch.
const SFX_JUMP          := "res://assets/audio/sfx/salto.wav"
const SFX_MACHETE_SWING := "res://assets/audio/sfx/machete_swing.wav"
const SFX_MACHETE_HIT   := "res://assets/audio/sfx/machete_hit.wav"
const SFX_PICKUP        := "res://assets/audio/sfx/pickup.wav"
const SFX_HURT          := "res://assets/audio/sfx/dano.wav"
const SFX_VICTORY       := "res://assets/audio/sfx/victoria.wav"
const SFX_DEFEAT        := "res://assets/audio/sfx/derrota.wav"

const SFX_ANIMALS := {
	"vaca":    "res://assets/audio/sfx/vaca.mp3",
	"gallina": "res://assets/audio/sfx/gallina.mp3",
	"oveja":   "res://assets/audio/sfx/oveja.mp3",
	"cabra":   "res://assets/audio/sfx/cabra.mp3",
}

# ── capas de ambiente ─────────────────────────
const AMBIENT_LAYERS := ["birds", "cicadas", "corral", "stream", "wind"]
const AMBIENT_PATHS := {
	"birds":   AMB_BIRDS,
	"cicadas": AMB_CICADAS,
	"corral":  AMB_CORRAL,
	"stream":  AMB_STREAM,
	"wind":    AMB_WIND,
}
# Volumen máximo de cada capa cuando peso == 1.0
const AMBIENT_MAX_DB := {
	"birds":   -12.0,
	"cicadas": -11.0,
	"corral":  -10.0,
	"stream":  -11.0,
	"wind":    -9.0,
}
# Velocidad de fade (unidades de peso por segundo)
const FADE_SPEED := 2.0

# ── estado interno ────────────────────────────
var _cache: Dictionary = {}                  # path → AudioStream base (sin loop)
var _loop_cache: Dictionary = {}             # path → AudioStream duplicado con loop=true
var _menu_music: AudioStreamPlayer
var _ambient_players: Dictionary = {}        # layer → AudioStreamPlayer
var _ambient_loaded_path: Dictionary = {}    # layer → String (path actualmente cargado)
var _ambient_targets: Dictionary = {}        # layer → float  objetivo
var _ambient_current: Dictionary = {}        # layer → float  actual (interpolado)
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _gameplay_active: bool = false
var _master_linear: float = 0.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu_music = _make_player("MenuMusic")

	for layer in AMBIENT_LAYERS:
		_ambient_players[layer]     = _make_player("Amb_%s" % layer)
		_ambient_loaded_path[layer] = ""
		_ambient_targets[layer]     = 0.0
		_ambient_current[layer]     = 0.0

	# 8 slots: con 10 animales activos 4 eran insuficientes
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx_%d" % i
		p.bus  = &"Master"
		add_child(p)
		_sfx_pool.append(p)

	_apply_saved_volume()


func _process(delta: float) -> void:
	if not _gameplay_active:
		return
	for layer in AMBIENT_LAYERS:
		var target  := float(_ambient_targets.get(layer, 0.0))
		var current := float(_ambient_current.get(layer, 0.0))
		current = move_toward(current, target, delta * FADE_SPEED)
		_ambient_current[layer] = current
		_apply_ambient_layer(layer, current)


# ═══════════════════════════════════════════
# API pública
# ═══════════════════════════════════════════

## Inicia la música del menú. Detiene todo lo demás.
func play_menu_music() -> void:
	_gameplay_active = false
	_stop_all_ambients()
	_start_loop(_menu_music, MUSIC_MENU, -8.0)


## El jugador entró al mundo. La música del menú se corta.
func enter_gameplay() -> void:
	_menu_music.stop()
	_gameplay_active = true
	# Los ambients arrancan en 0; AmbientAudioController los subirá según posición.
	for layer in AMBIENT_LAYERS:
		_ambient_targets[layer] = 0.0
		_ambient_current[layer] = 0.0
		_ambient_players[layer].stop()
		_ambient_loaded_path[layer] = ""


## Llamado por AmbientAudioController cada frame con un valor 0-1.
func set_ambient_weight(layer: String, weight: float) -> void:
	if not _ambient_targets.has(layer):
		return
	_ambient_targets[layer] = clampf(weight, 0.0, 1.0)


## Pasos sobre tierra: se llama solo cuando el jugador se mueve sobre el suelo.
func play_footstep() -> void:
	_play_one_shot(SFX_FOOTSTEP, -12.0, randf_range(0.9, 1.1))


## Salto: se llama una sola vez al despegar del suelo.
func play_jump() -> void:
	_play_one_shot(SFX_JUMP, -9.0, randf_range(0.97, 1.03))


## Machete: swing al atacar (volumen medio).
func play_machete_swing() -> void:
	_play_one_shot(SFX_MACHETE_SWING, -7.0, randf_range(0.95, 1.06))


## Machete: impacto al golpear al Diablo (claro y presente).
func play_machete_hit() -> void:
	_play_one_shot(SFX_MACHETE_HIT, -3.5, randf_range(0.97, 1.04))


## Pickup de machete o Cacique.
func play_pickup() -> void:
	_play_one_shot(SFX_PICKUP, -5.0)


## Daño recibido por el jugador.
func play_player_hurt() -> void:
	_play_one_shot(SFX_HURT, -4.0)


## Jingle de victoria.
func play_victory() -> void:
	_play_one_shot(SFX_VICTORY, -3.0)


## Jingle de derrota.
func play_defeat() -> void:
	_play_one_shot(SFX_DEFEAT, -3.0)


## Portón del corral.
func play_gate() -> void:
	_play_one_shot(SFX_GATE, -2.0)


## SFX de subida de nivel.
func play_progression() -> void:
	_play_one_shot(SFX_PROGRESS, -1.0)


## Devuelve el AudioStream base (sin loop) para que animal.gd lo use en su voz 3D.
func get_animal_stream(kind: String) -> AudioStream:
	var path: String = SFX_ANIMALS.get(kind, SFX_ANIMALS["vaca"])
	return _load_stream(path)


## Detiene todo el audio de juego (victoria / derrota).
func stop_gameplay() -> void:
	_gameplay_active = false
	_stop_all_ambients()


func is_gameplay_active() -> bool:
	return _gameplay_active


## SFX de animal one-shot (colecta, eventos sin nodo 3D).
func play_animal_sfx(kind: String, volume_db: float = -3.0) -> void:
	var path: String = SFX_ANIMALS.get(kind, SFX_ANIMALS["vaca"])
	_play_one_shot(path, volume_db, randf_range(0.95, 1.05))


func apply_master_volume(linear: float) -> void:
	_master_linear = clampf(linear, 0.0, 1.0)
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(_master_linear, 0.001)))
		AudioServer.set_bus_mute(bus, _master_linear <= 0.001)


# ═══════════════════════════════════════════
# Implementación interna
# ═══════════════════════════════════════════

func _apply_ambient_layer(layer: String, weight: float) -> void:
	var player: AudioStreamPlayer = _ambient_players.get(layer)
	if player == null:
		return

	if weight <= 0.001:
		if player.playing:
			player.stop()
		return

	var path: String = AMBIENT_PATHS[layer]

	# FIX ERROR 1: Solo reasignamos el stream si el path cambió.
	# Antes se hacía duplicate() cada frame y la comparación de objetos
	# siempre resultaba TRUE, reiniciando el audio 60 veces por segundo.
	if _ambient_loaded_path.get(layer, "") != path:
		var stream := _looping_stream(path)
		if stream == null:
			return
		player.stream = stream
		_ambient_loaded_path[layer] = path

	var max_db: float = float(AMBIENT_MAX_DB.get(layer, -12.0))
	player.volume_db = lerpf(-60.0, max_db, weight)
	if not player.playing:
		player.play()


func _stop_all_ambients() -> void:
	for layer in AMBIENT_LAYERS:
		_ambient_targets[layer] = 0.0
		_ambient_current[layer] = 0.0
		var player: AudioStreamPlayer = _ambient_players.get(layer)
		if player != null and player.playing:
			player.stop()
		_ambient_loaded_path[layer] = ""


func _make_player(node_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.bus  = &"Master"
	add_child(p)
	return p


func _start_loop(player: AudioStreamPlayer, path: String, volume_db: float) -> void:
	var stream := _looping_stream(path)
	if stream == null:
		return
	player.stream    = stream
	player.volume_db = volume_db
	player.play()


func _play_one_shot(path: String, volume_db: float, pitch_scale: float = 1.0) -> void:
	var stream := _load_stream(path)
	if stream == null:
		return
	# Si el slot actual está reproduciendo el mismo archivo, buscar uno libre
	var start_index := _sfx_index
	for i in _sfx_pool.size():
		var idx := (start_index + i) % _sfx_pool.size()
		var p   := _sfx_pool[idx]
		if not p.playing:
			_sfx_index = (idx + 1) % _sfx_pool.size()
			p.stream      = stream
			p.volume_db   = volume_db
			p.pitch_scale = pitch_scale
			p.play()
			return
	# Todos ocupados: sobreescribir el actual (comportamiento anterior)
	var p := _sfx_pool[_sfx_index]
	_sfx_index    = (_sfx_index + 1) % _sfx_pool.size()
	p.stream      = stream
	p.volume_db   = volume_db
	p.pitch_scale = pitch_scale
	p.play()


## Devuelve un stream con loop=true cacheado. Se duplica una sola vez por path.
func _looping_stream(path: String) -> AudioStream:
	if _loop_cache.has(path):
		return _loop_cache[path]
	var base := _load_stream(path)
	if base == null:
		return null
	var looped: AudioStream = base.duplicate()
	if looped is AudioStreamMP3:
		(looped as AudioStreamMP3).loop = true
	_loop_cache[path] = looped
	return looped


func _load_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		push_warning("[AudioManager] Archivo no encontrado: %s" % path)
		return null
	var res := load(path)
	if res is AudioStream:
		_cache[path] = res
		return res
	return null


func _apply_saved_volume() -> void:
	var linear := 0.8
	if FileAccess.file_exists(SETTINGS_PATH):
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				linear = float(parsed.get("volume", 0.8))
	apply_master_volume(linear)
