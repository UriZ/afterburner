extends Node

## 2D enemy jet. Pure data/logic node — no visual transform.
## GameWorld reads its state and draws it via EnemySpriteRenderer.

const _DepthUtil := preload("res://scripts/game/depth_util.gd")

signal destroyed(score_value: int)

enum EnemyType { FIGHTER, INTERCEPTOR, BOMBER }

const TYPE_DATA: Dictionary = {
	0: {  # FIGHTER
		"speed": 0.35,
		"health": 1,
		"fire_interval": 1.5,
		"score": 100,
		"visual": 0,
	},
	1: {  # INTERCEPTOR
		"speed": 0.55,
		"health": 1,
		"fire_interval": 1.5,
		"score": 200,
		"visual": 1,
	},
	2: {  # BOMBER
		"speed": 0.25,
		"health": 2,
		"fire_interval": 2.0,
		"score": 500,
		"visual": 2,
	},
}

const DESPAWN_DEPTH: float = 0.92
# Asymptote for the saturating scale curve (see get_screen_scale()). A hard
# minf() clamp here would create a plateau — the curve below approaches this
# value but never reaches it, so size keeps growing (just decelerating) all
# the way to despawn instead of freezing at a fixed size (#105), while still
# staying well under the raw quadratic's ~2.57 at DESPAWN_DEPTH (#95).
const SCALE_SATURATION: float = 3.0
const BULLET_SPEED: float = 0.6
# Enemy must be visibly close before it's allowed to open fire — gives the
# player an approach window instead of getting shot at while still a distant dot.
const MIN_FIRE_DEPTH: float = 0.3

var enemy_type: int = 0  # EnemyType.FIGHTER
var logical_x: float = 0.0
var logical_depth: float = 0.0
var speed: float = 0.35
var health: int = 1
var fire_interval: float = 4.0
var score_value: int = 100
var _x_drift: float = 0.0
var _fire_timer: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	_apply_type_data()
	_fire_timer = randf_range(1.2, 2.0)
	# Connect score signal in deferred call so autoloads are guaranteed available
	call_deferred("_connect_score_signal")


func _connect_score_signal() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		destroyed.connect(gs.add_score)


func configure(type: int, start_logical_x: float, start_logical_depth: float, x_drift_amount: float = 0.0) -> void:
	enemy_type = type
	logical_x = start_logical_x
	logical_depth = start_logical_depth
	_x_drift = x_drift_amount
	_apply_type_data()


func _apply_type_data() -> void:
	var data: Dictionary = TYPE_DATA[enemy_type]
	speed = data["speed"]
	health = data["health"]
	fire_interval = data["fire_interval"]
	score_value = data["score"]


func _process(delta: float) -> void:
	logical_depth += speed * delta
	logical_x += _x_drift * delta

	if logical_depth > DESPAWN_DEPTH:
		queue_free()
		return

	_fire_timer -= delta
	if _fire_timer <= 0.0 and logical_depth >= MIN_FIRE_DEPTH:
		_fire_timer = fire_interval
		_fire_bullet()


func get_screen_position() -> Vector2:
	return _DepthUtil.to_screen(logical_x, logical_depth)


func get_screen_scale() -> float:
	# Saturating curve: raw*K/(K+raw) is strictly increasing in raw (and thus
	# in depth, since depth_to_scale() is strictly increasing) for all
	# raw >= 0, and approaches K asymptotically without ever reaching it. For
	# raw << K it's close to raw unchanged (distant enemies look the same as
	# before); as raw grows, growth decelerates smoothly instead of hitting a
	# hard wall.
	var raw: float = _DepthUtil.depth_to_scale(logical_depth)
	return raw * SCALE_SATURATION / (SCALE_SATURATION + raw)


func get_collision_radius() -> float:
	return _DepthUtil.scale_pixels(logical_depth, 20.0)


func get_visual_type() -> int:
	return TYPE_DATA[enemy_type]["visual"]


func take_damage(amount: int = 1) -> void:
	health -= amount
	if health <= 0:
		_die()


func _die() -> void:
	destroyed.emit(score_value)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_explosion()
	_spawn_explosion()
	queue_free()


func _spawn_explosion() -> void:
	var explosion_script: GDScript = preload("res://scripts/effects/explosion_2d.gd")
	var explosion := Node2D.new()
	explosion.set_script(explosion_script)
	explosion.position = get_screen_position()
	explosion.z_index = 999
	var scale_val: float = _DepthUtil.depth_to_scale(logical_depth)
	explosion.set("base_radius", maxf(scale_val * 240.0, 90.0))
	if get_parent():
		get_parent().add_child(explosion)


func _fire_bullet() -> void:
	var player: Node = _find_player()
	if player == null:
		return
	var bullet := Node.new()
	bullet.set_script(preload("res://scripts/enemies/enemy_bullet_2d.gd"))
	bullet.set("logical_x", logical_x)
	bullet.set("logical_depth", logical_depth)
	bullet.set("speed", BULLET_SPEED)
	bullet.set("target_screen_pos", player.get_screen_position())
	get_parent().add_child(bullet)


func _find_player() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var players: Array = tree.get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
