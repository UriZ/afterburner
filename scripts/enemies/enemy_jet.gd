extends Area3D

## Base enemy jet behavior. Flies from far Z toward the camera, fires bullets
## at the player, and explodes when destroyed.

signal destroyed(score_value: int)


enum EnemyType { FIGHTER, INTERCEPTOR, BOMBER }

# Type definitions: speed, health, fire_interval, score_value, visual (int index)
# Visual values: 0=FIGHTER, 1=INTERCEPTOR, 2=BOMBER — mapped to EnemyMeshBuilder.
const TYPE_DATA := {
	EnemyType.FIGHTER: {
		"speed": 18.0,
		"health": 1,
		"fire_interval": 4.0,
		"score": 100,
		"visual": 0,
	},
	EnemyType.INTERCEPTOR: {
		"speed": 28.0,
		"health": 1,
		"fire_interval": 4.0,
		"score": 200,
		"visual": 1,
	},
	EnemyType.BOMBER: {
		"speed": 12.0,
		"health": 2,
		"fire_interval": 3.5,
		"score": 500,
		"visual": 2,
	},
}

const DESPAWN_Z := 5.0
const BULLET_SPEED := 20.0
const BULLET_LIFETIME := 3.0

var enemy_type: EnemyType = EnemyType.FIGHTER
var speed: float = 15.0
var health: int = 1
var fire_interval: float = 3.0
var score_value: int = 100

var _fire_timer: float = 0.0
var _direction := Vector3.ZERO  # normalized flight direction
var _x_drift: float = 0.0       # slight lateral movement

var _enemy_mesh: Node3D

static var _explosion_scene: PackedScene = null


func _ready() -> void:
	add_to_group("enemies")
	_apply_type_data()
	# Wire score: when destroyed, add score to GameState
	destroyed.connect(GameState.add_score)
	# Build 3D mesh for this enemy type
	var visual_id: int = TYPE_DATA[enemy_type]["visual"]
	var Builder := preload("res://scripts/enemies/enemy_mesh_builder.gd")
	_enemy_mesh = Builder.build_enemy_mesh(visual_id)
	# Rotate 180° on Y: mesh nose is at -Z, but enemies approach camera (+Z),
	# so we flip the mesh to show the nose facing the player.
	_enemy_mesh.rotation_degrees.y = 180.0
	add_child(_enemy_mesh)
	# Delay first shot so enemies don't fire immediately on spawn
	_fire_timer = randf_range(fire_interval * 0.8, fire_interval * 1.5)
	# Flight direction: mostly toward camera (+Z), with slight drift
	_direction = Vector3(_x_drift, 0.0, 1.0).normalized()


func configure(type: EnemyType, start_position: Vector3, x_drift_amount: float = 0.0) -> void:
	enemy_type = type
	position = start_position
	_x_drift = x_drift_amount


func _apply_type_data() -> void:
	var data: Dictionary = TYPE_DATA[enemy_type]
	speed = data["speed"]
	health = data["health"]
	fire_interval = data["fire_interval"]
	score_value = data["score"]


func _process(delta: float) -> void:
	# Move toward camera
	position += _direction * speed * delta

	# Despawn when past camera
	if position.z > DESPAWN_Z:
		queue_free()
		return

	# Fire at player
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		_fire_bullet()


func take_damage(amount: int = 1) -> void:
	health -= amount
	if health <= 0:
		_die()


func _die() -> void:
	destroyed.emit(score_value)
	AudioManager.play_explosion()
	_spawn_explosion()
	queue_free()


func _spawn_explosion() -> void:
	if _explosion_scene == null:
		_explosion_scene = load("res://scenes/effects/explosion.tscn")
	var explosion := _explosion_scene.instantiate()
	explosion.position = position
	# Add to parent (Main scene) so it persists after enemy is freed
	get_parent().add_child(explosion)


func _fire_bullet() -> void:
	# Find the player to aim at
	var player := _find_player()
	if player == null:
		return

	var bullet := _create_bullet()
	var aim_direction := (player.global_position - global_position).normalized()
	bullet.position = global_position
	bullet.set_meta("velocity", aim_direction * BULLET_SPEED)
	bullet.set_meta("lifetime", BULLET_LIFETIME)
	get_parent().add_child(bullet)


func _find_player() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var players := tree.get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node3D


static func _create_bullet() -> Area3D:
	## Creates a simple enemy bullet as an Area3D with a small mesh.
	var bullet := Area3D.new()
	bullet.collision_layer = 8   # layer 4: enemy bullets
	bullet.collision_mask = 1    # layer 1: player

	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	mesh_instance.mesh = sphere

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.3, 0.1)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.4, 0.1)
	material.emission_energy_multiplier = 2.0
	mesh_instance.material_override = material

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.15
	collision.shape = shape

	bullet.add_child(mesh_instance)
	bullet.add_child(collision)

	# Attach movement script
	var script := GDScript.new()
	script.source_code = """extends Area3D

func _process(delta: float) -> void:
	var vel: Vector3 = get_meta("velocity")
	position += vel * delta
	var ttl: float = get_meta("lifetime") - delta
	set_meta("lifetime", ttl)
	if ttl <= 0.0 or position.z > 10.0 or position.z < -100.0:
		queue_free()
"""
	script.reload()
	bullet.set_script(script)

	return bullet
