extends Node3D

## Spawns waves of enemy jets on a timer.
## Data-driven: wave definitions are arrays of dictionaries.

const SPAWN_Z := -50.0
const SPAWN_Y_MIN := 5.0  # enemies must fly above player (player MOVE_MAX.y = 4.8)
const SPAWN_Y_MAX := 7.0
const SPAWN_X_RANGE := 8.0

@export var spawn_interval: float = 2.0
@export var enabled: bool = true

var _spawn_timer: float = 0.0
var _wave_index: int = 0

var _enemy_scene: PackedScene = null

# Wave definitions: each wave is a dictionary describing what to spawn.
# formation: "v", "line", "scattered"
# type: EnemyType enum value
# count: number of enemies
var wave_definitions: Array[Dictionary] = [
	{"type": 0, "count": 2, "formation": "v"},        # 2 fighters in V
	{"type": 0, "count": 2, "formation": "line"},      # 2 fighters in line
	{"type": 1, "count": 2, "formation": "v"},         # 2 interceptors in V
	{"type": 0, "count": 3, "formation": "v"},         # 3 fighters in V
	{"type": 2, "count": 1, "formation": "line"},      # 1 bomber
	{"type": 0, "count": 3, "formation": "scattered"}, # 3 fighters scattered
	{"type": 1, "count": 3, "formation": "v"},         # 3 interceptors in V
	{"type": 2, "count": 2, "formation": "line"},      # 2 bombers in line
	{"type": 0, "count": 4, "formation": "scattered"}, # 4 fighters scattered
	{"type": 1, "count": 4, "formation": "v"},         # 4 interceptors in V
	{"type": 2, "count": 2, "formation": "scattered"}, # 2 bombers scattered
	{"type": 0, "count": 5, "formation": "scattered"}, # 5 fighters scattered
]


func _ready() -> void:
	_enemy_scene = load("res://scenes/enemies/enemy_jet.tscn")
	_spawn_timer = 5.0  # delay first wave so player has time to orient
	# Ensure the player jet is in the "player" group so enemies can find it.
	# We do this here because we can't modify the player scene (separate agent).
	_add_player_to_group.call_deferred()


func _add_player_to_group() -> void:
	var player_jet := get_parent().get_node_or_null("PlayerJet")
	if player_jet and not player_jet.is_in_group("player"):
		player_jet.add_to_group("player")


func _process(delta: float) -> void:
	if not enabled:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_spawn_wave()


func _spawn_wave() -> void:
	var wave_def := wave_definitions[_wave_index % wave_definitions.size()]
	_wave_index += 1

	var enemy_type: int = wave_def["type"]
	var count: int = wave_def["count"]
	var formation: String = wave_def["formation"]

	var positions := _calculate_formation_positions(count, formation)

	for i in range(count):
		var enemy := _enemy_scene.instantiate()
		var spawn_pos := positions[i]
		enemy.configure(enemy_type, spawn_pos)
		get_parent().add_child(enemy)


func _calculate_formation_positions(count: int, formation: String) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var center_x := randf_range(-SPAWN_X_RANGE * 0.5, SPAWN_X_RANGE * 0.5)
	var center_y := randf_range(SPAWN_Y_MIN, SPAWN_Y_MAX)

	match formation:
		"v":
			positions = _v_formation(count, center_x, center_y)
		"line":
			positions = _line_formation(count, center_x, center_y)
		"scattered":
			positions = _scattered_formation(count, center_x, center_y)
		_:
			positions = _scattered_formation(count, center_x, center_y)

	return positions


func _v_formation(count: int, cx: float, cy: float) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var spacing := 2.5
	var z_offset := 3.0  # depth offset per rank in V

	# Leader at front
	positions.append(Vector3(cx, cy, SPAWN_Z))

	for i in range(1, count):
		# Alternate left/right
		var side := 1 if i % 2 == 1 else -1
		var rank := ceili(float(i) / 2.0)
		var x := cx + side * rank * spacing
		var z := SPAWN_Z - rank * z_offset  # further back
		positions.append(Vector3(x, cy, z))

	return positions


func _line_formation(count: int, cx: float, cy: float) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var spacing := 3.0
	var total_width := (count - 1) * spacing
	var start_x := cx - total_width / 2.0

	for i in range(count):
		var x := start_x + i * spacing
		positions.append(Vector3(x, cy, SPAWN_Z))

	return positions


func _scattered_formation(count: int, cx: float, cy: float) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	for i in range(count):
		var x := cx + randf_range(-SPAWN_X_RANGE * 0.4, SPAWN_X_RANGE * 0.4)
		var y := maxf(SPAWN_Y_MIN, cy + randf_range(-0.5, 1.0))
		var z := SPAWN_Z + randf_range(-10.0, 0.0)
		positions.append(Vector3(x, y, z))

	return positions
