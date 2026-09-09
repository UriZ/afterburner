extends SceneTree

## Tests for JetMeshBuilder and EnemyMeshBuilder.
## Run with: godot --headless --script res://tests/test_jet_mesh_builder.gd

const _JetBuilder := preload("res://scripts/player/jet_mesh_builder.gd")
const _EnemyBuilder := preload("res://scripts/enemies/enemy_mesh_builder.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== JetMeshBuilder Tests ===")

	test_player_jet_hierarchy()
	test_player_jet_materials()
	test_player_jet_flames()
	test_enemy_fighter_mesh()
	test_enemy_interceptor_mesh()
	test_enemy_bomber_mesh()
	test_enemy_invalid_type_fallback()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


func test_player_jet_hierarchy():
	print("\ntest_player_jet_hierarchy:")
	var jet := _JetBuilder.build_player_jet()
	assert_true(jet != null, "Player jet not null")
	assert_true(jet.name == "JetMesh", "Root named JetMesh")

	var expected := [
		"Fuselage", "NoseCone",
		"LeftWing", "RightWing",
		"LeftTailFin", "RightTailFin",
		"LeftNacelle", "RightNacelle",
		"LeftNozzle", "RightNozzle",
		"Canopy",
		"LeftHStab", "RightHStab",
		"LeftFlame", "RightFlame",
	]
	for part_name in expected:
		var node := jet.get_node_or_null(part_name)
		assert_true(node != null, "Has %s" % part_name)
		assert_true(node is MeshInstance3D, "%s is MeshInstance3D" % part_name)

	assert_true(jet.get_child_count() == expected.size(),
		"Child count is %d (got %d)" % [expected.size(), jet.get_child_count()])
	jet.free()


func test_player_jet_materials():
	print("\ntest_player_jet_materials:")
	var jet := _JetBuilder.build_player_jet()

	var fuselage := jet.get_node("Fuselage") as MeshInstance3D
	assert_true(fuselage.material_override != null, "Fuselage has material")
	var mat := fuselage.material_override as StandardMaterial3D
	assert_true(mat.metallic > 0.0, "Fuselage is metallic")
	assert_true(mat.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL,
		"Per-pixel shading")

	var canopy := jet.get_node("Canopy") as MeshInstance3D
	var canopy_mat := canopy.material_override as StandardMaterial3D
	assert_true(canopy_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
		"Canopy transparent")
	assert_true(canopy_mat.albedo_color.a < 1.0, "Canopy alpha < 1")

	var nozzle := jet.get_node("LeftNozzle") as MeshInstance3D
	var nozzle_mat := nozzle.material_override as StandardMaterial3D
	assert_true(nozzle_mat.albedo_color.r < 0.3, "Nozzle is dark")
	jet.free()


func test_player_jet_flames():
	print("\ntest_player_jet_flames:")
	var jet := _JetBuilder.build_player_jet()

	var left_flame := jet.get_node("LeftFlame") as MeshInstance3D
	var flame_mat := left_flame.material_override as StandardMaterial3D
	assert_true(flame_mat.emission_enabled, "Flame has emission")
	assert_true(flame_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
		"Flame is transparent")

	var nozzle := jet.get_node("LeftNozzle") as MeshInstance3D
	assert_true(left_flame.position.z > nozzle.position.z,
		"Flame Z behind nozzle Z")
	jet.free()


func test_enemy_fighter_mesh():
	print("\ntest_enemy_fighter_mesh:")
	var mesh := _EnemyBuilder.build_enemy_mesh(0)
	assert_true(mesh != null, "Fighter not null")
	assert_true(mesh.name == "EnemyMesh", "Named EnemyMesh")
	assert_true(mesh.get_node_or_null("Fuselage") != null, "Has Fuselage")
	assert_true(mesh.get_node_or_null("LeftWing") != null, "Has LeftWing")
	assert_true(mesh.get_node_or_null("RightWing") != null, "Has RightWing")
	assert_true(mesh.get_node_or_null("Canopy") != null, "Has Canopy")

	var fuselage := mesh.get_node("Fuselage") as MeshInstance3D
	var mat := fuselage.material_override as StandardMaterial3D
	assert_true(mat.albedo_color.r > 0.7, "Fighter is red (r=%.2f)" % mat.albedo_color.r)
	assert_true(mat.albedo_color.g < 0.3, "Fighter not green")
	mesh.free()


func test_enemy_interceptor_mesh():
	print("\ntest_enemy_interceptor_mesh:")
	var mesh := _EnemyBuilder.build_enemy_mesh(1)
	assert_true(mesh != null, "Interceptor not null")
	assert_true(mesh.get_node_or_null("TailFin") != null, "Has TailFin")

	var fuselage := mesh.get_node("Fuselage") as MeshInstance3D
	var mat := fuselage.material_override as StandardMaterial3D
	assert_true(mat.albedo_color.g > 0.5, "Interceptor is green")
	mesh.free()


func test_enemy_bomber_mesh():
	print("\ntest_enemy_bomber_mesh:")
	var mesh := _EnemyBuilder.build_enemy_mesh(2)
	assert_true(mesh != null, "Bomber not null")
	assert_true(mesh.get_node_or_null("LeftEngine") != null, "Has LeftEngine")
	assert_true(mesh.get_node_or_null("RightEngine") != null, "Has RightEngine")

	var fuselage := mesh.get_node("Fuselage") as MeshInstance3D
	var mat := fuselage.material_override as StandardMaterial3D
	assert_true(abs(mat.albedo_color.r - mat.albedo_color.g) < 0.1, "Bomber is grey")
	assert_true(mat.albedo_color.r > 0.4, "Bomber grey ~0.55")

	var engine := mesh.get_node("LeftEngine") as MeshInstance3D
	var engine_mat := engine.material_override as StandardMaterial3D
	assert_true(engine_mat.albedo_color.r < mat.albedo_color.r,
		"Engine darker than fuselage")
	mesh.free()


func test_enemy_invalid_type_fallback():
	print("\ntest_enemy_invalid_type_fallback:")
	var mesh := _EnemyBuilder.build_enemy_mesh(99)
	assert_true(mesh != null, "Invalid type returns fallback")
	var fuselage := mesh.get_node("Fuselage") as MeshInstance3D
	var mat := fuselage.material_override as StandardMaterial3D
	assert_true(mat.albedo_color.r > 0.7, "Fallback is fighter (red)")
	mesh.free()
