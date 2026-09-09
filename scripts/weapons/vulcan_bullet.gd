extends Area3D

## A single vulcan cannon bullet that flies toward the aim direction,
## scaling down to simulate depth, and auto-frees after max range.
## Creates a bright tracer line behind the bullet for visual feedback.

const SPEED := 80.0
const MAX_DISTANCE := 200.0
const SCALE_RATE := 3.0  # how fast it shrinks as it flies away
const TRACER_LENGTH := 0.5
const HIT_FLASH_DURATION := 0.08  # seconds

var aim_direction := Vector3(0, 0, -1)  # set by WeaponManager before adding to tree
var _distance_traveled := 0.0
var _initial_scale := Vector3.ONE
var _tracer: MeshInstance3D = null


func _ready() -> void:
	_initial_scale = scale
	area_entered.connect(_on_area_entered)
	_create_tracer()


func _create_tracer() -> void:
	_tracer = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = TRACER_LENGTH
	_tracer.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.95, 0.3)
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer.material_override = mat

	# Align cylinder along the Z axis (bullet flight direction)
	_tracer.rotation.x = PI / 2.0
	_tracer.position.z = TRACER_LENGTH * 0.5  # trail behind bullet
	add_child(_tracer)


func _process(delta: float) -> void:
	var move_amount := SPEED * delta
	position += aim_direction * move_amount
	_distance_traveled += move_amount

	# Scale down to simulate flying into the distance
	var t := _distance_traveled / MAX_DISTANCE
	var s := maxf(1.0 - t * SCALE_RATE, 0.05)
	scale = _initial_scale * s

	if _distance_traveled >= MAX_DISTANCE:
		queue_free()


func _on_area_entered(area: Area3D) -> void:
	# Hit an enemy (layer 3 = bit 4)
	if area.collision_layer & 4:
		if area.has_method("take_damage"):
			area.take_damage(1)
		_flash_enemy(area)
	queue_free()


func _flash_enemy(enemy: Node3D) -> void:
	## Brief white flash on hit: set all mesh materials to white, then restore.
	var meshes: Array[MeshInstance3D] = []
	var original_materials: Array[Material] = []
	_collect_meshes(enemy, meshes)
	if meshes.is_empty():
		return

	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color.WHITE
	flash_mat.emission_enabled = true
	flash_mat.emission = Color.WHITE
	flash_mat.emission_energy_multiplier = 3.0
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for mesh in meshes:
		original_materials.append(mesh.material_override)
		mesh.material_override = flash_mat

	# Use a tween on the enemy node (not this bullet, which is about to be freed)
	var tween := enemy.create_tween()
	tween.tween_interval(HIT_FLASH_DURATION)
	tween.tween_callback(func():
		for i in meshes.size():
			if is_instance_valid(meshes[i]):
				meshes[i].material_override = original_materials[i]
	)


static func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)
