extends Node

# ─────────────────────────────────────────────
# AmbientAudioController
#
# Responsabilidad única: leer la posición del jugador y traducirla
# en pesos 0-1 para cada capa de ambiente del AudioManager.
#
# No produce ningún sonido directamente.
# No se ejecuta si el juego no está activo (_gameplay_active).
# ─────────────────────────────────────────────

@export var player_path: NodePath = NodePath("../Player")

# Puntos del río (XZ) coinciden con river_points del RiverSystem en main.tscn
@export var river_points: PackedVector3Array = PackedVector3Array([
	Vector3(149.653, 98.0,  132.134),
	Vector3(119.653, 71.0,   95.134),
	Vector3( 81.653, 38.0,   48.134),
	Vector3( 33.653, 12.0,  -17.866),
	Vector3(-28.347,  4.0,  -57.866),
	Vector3(-78.347, -4.0,  -89.866),
	Vector3(-112.347,-5.2, -117.866),
	Vector3(-150.347,-4.2, -144.866),
])

@export var corral_center:  Vector3 = Vector3(124.653,  7.0, -113.366)
@export var lake_center:    Vector3 = Vector3(-150.347, -3.2, -144.866)

const RIVER_HEAR_RADIUS  := 30.0
const RIVER_FADE         := 12.0
const LAKE_HEAR_RADIUS   := 45.0
const LAKE_FADE          := 16.0
const CORRAL_HEAR_RADIUS := 26.0
const CORRAL_FADE        :=  9.0

var _cached_player: Node3D = null


func _ready() -> void:
	_cached_player = get_node_or_null(player_path) as Node3D


func _process(_delta: float) -> void:
	# FIX ERROR 5: no hacer nada si el AudioManager no está en modo juego.
	if not AudioManager.is_gameplay_active():
		return

	_ensure_player()
	if _cached_player == null:
		return

	var pos := _cached_player.global_position
	var xz  := Vector2(pos.x, pos.z)

	AudioManager.set_ambient_weight("birds",   _birds_weight(xz))
	AudioManager.set_ambient_weight("cicadas", _cicadas_weight(xz))
	AudioManager.set_ambient_weight("corral",  _corral_weight(xz))
	AudioManager.set_ambient_weight("stream",  _stream_weight(xz))

	# El viento lo notifica el propio jugador a través de get_run_wind_intensity.
	# El controller solo lo pide; si el jugador no existe, queda en 0.
	if _cached_player.has_method("get_run_wind_intensity"):
		AudioManager.set_ambient_weight("wind",
			float(_cached_player.call("get_run_wind_intensity")))
	else:
		AudioManager.set_ambient_weight("wind", 0.0)


# ══════════════════════════════════════════════
# Pesos de zona
# ══════════════════════════════════════════════

func _birds_weight(xz: Vector2) -> float:
	# Zonas boscosas: montaña/bosque al NE, bosque primario SO, árboles O
	var forest_ne := _ellipse_weight(xz, Vector2( 120.0,  88.0), 78.0, 58.0)
	var forest_sw := _ellipse_weight(xz, Vector2(-118.0, -72.0), 62.0, 48.0)
	var forest_w  := _ellipse_weight(xz, Vector2( -85.0,  10.0), 45.0, 55.0)
	return clampf(maxf(forest_ne, maxf(forest_sw, forest_w)), 0.0, 1.0)


func _cicadas_weight(xz: Vector2) -> float:
	# Las chicharras suenan en zona abierta/rural.
	# Si ya hay pájaros fuertes o si estamos en el corral, no suenan.
	if _birds_weight(xz) > 0.4 or _corral_weight(xz) > 0.3:
		return 0.0
	var rural  := _ellipse_weight(xz, Vector2( 35.0, -25.0), 115.0, 95.0)
	var campo  := _ellipse_weight(xz, Vector2( 98.0, -66.0),  55.0, 45.0)
	return clampf(maxf(rural, campo), 0.0, 1.0)


func _corral_weight(xz: Vector2) -> float:
	var center := Vector2(corral_center.x, corral_center.z)
	return _smooth_falloff(xz.distance_to(center), CORRAL_HEAR_RADIUS, CORRAL_FADE)


func _stream_weight(xz: Vector2) -> float:
	var river_dist := _distance_to_polyline(xz)
	var river_w    := _smooth_falloff(river_dist, RIVER_HEAR_RADIUS, RIVER_FADE)
	var lake_dist  := xz.distance_to(Vector2(lake_center.x, lake_center.z))
	var lake_w     := _smooth_falloff(lake_dist,  LAKE_HEAR_RADIUS,  LAKE_FADE)
	return clampf(maxf(river_w, lake_w), 0.0, 1.0)


# ══════════════════════════════════════════════
# Geometría
# ══════════════════════════════════════════════

## Elipse normalizada: peso 1 dentro de la elipse, fade lineal hacia afuera.
func _ellipse_weight(point: Vector2, center: Vector2,
					 radius_x: float, radius_y: float) -> float:
	var dx := (point.x - center.x) / maxf(radius_x, 0.001)
	var dz := (point.y - center.y) / maxf(radius_y, 0.001)
	# normalized es la distancia escalada; 1.0 = borde de la elipse
	var normalized := sqrt(dx * dx + dz * dz)
	# fade sobre un 40% del radio
	return _smooth_falloff(normalized, 1.0, 0.4)


## Falloff lineal: 1.0 dentro del hear_radius, 0.0 fuera de hear_radius + fade.
func _smooth_falloff(distance: float, hear_radius: float, fade: float) -> float:
	if distance >= hear_radius + fade:
		return 0.0
	if distance <= hear_radius:
		return 1.0
	return 1.0 - clampf((distance - hear_radius) / fade, 0.0, 1.0)


## Distancia al polilínea del río proyectada en XZ.
func _distance_to_polyline(point: Vector2) -> float:
	if river_points.size() < 2:
		return INF
	var best := INF
	for i in range(river_points.size() - 1):
		var a := Vector2(river_points[i].x,     river_points[i].z)
		var b := Vector2(river_points[i + 1].x, river_points[i + 1].z)
		best = minf(best, _dist_point_segment(point, a, b))
	return best


func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _ensure_player() -> void:
	if _cached_player == null or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player") as Node3D
