extends RefCounted

## Builds 3D mesh hierarchies for enemy jets from Godot primitives.
## Types: 0=FIGHTER (red), 1=INTERCEPTOR (green), 2=BOMBER (grey).
## Nose at -Z, enemies fly toward camera (+Z direction).


static func build_enemy_mesh(type: int) -> Node3D:
	match type:
		0: return _build_fighter()
		1: return _build_interceptor()
		2: return _build_bomber()
		_: return _build_fighter()


static func _build_fighter() -> Node3D:
	var root := Node3D.new()
	root.name = "EnemyMesh"

	var mat_body := _make_mat(Color(0.85, 0.15, 0.1), 0.3, 0.4)
	var mat_canopy := _make_canopy_mat()

	var fuselage := CylinderMesh.new()
	fuselage.top_radius = 0.2
	fuselage.bottom_radius = 0.18
	fuselage.height = 1.8
	fuselage.radial_segments = 8
	_add_part(root, "Fuselage", fuselage, mat_body,
		Vector3(0, 0, 0), Vector3(90, 0, 0))

	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.2
	nose.height = 0.6
	nose.radial_segments = 8
	_add_part(root, "NoseCone", nose, mat_body,
		Vector3(0, 0, -1.2), Vector3(90, 0, 0))

	var wing := BoxMesh.new()
	wing.size = Vector3(1.4, 0.03, 0.6)
	_add_part(root, "LeftWing", wing, mat_body,
		Vector3(-0.85, -0.02, 0.1), Vector3.ZERO)
	_add_part(root, "RightWing", wing, mat_body,
		Vector3(0.85, -0.02, 0.1), Vector3.ZERO)

	var canopy := SphereMesh.new()
	canopy.radius = 0.14
	canopy.height = 0.14
	_add_part(root, "Canopy", canopy, mat_canopy,
		Vector3(0, 0.15, -0.4), Vector3.ZERO)

	return root


static func _build_interceptor() -> Node3D:
	var root := Node3D.new()
	root.name = "EnemyMesh"

	var mat_body := _make_mat(Color(0.1, 0.65, 0.2), 0.3, 0.4)
	var mat_canopy := _make_canopy_mat()

	var fuselage := CylinderMesh.new()
	fuselage.top_radius = 0.18
	fuselage.bottom_radius = 0.15
	fuselage.height = 2.2
	fuselage.radial_segments = 8
	_add_part(root, "Fuselage", fuselage, mat_body,
		Vector3(0, 0, 0), Vector3(90, 0, 0))

	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.18
	nose.height = 0.8
	nose.radial_segments = 8
	_add_part(root, "NoseCone", nose, mat_body,
		Vector3(0, 0, -1.5), Vector3(90, 0, 0))

	var wing := BoxMesh.new()
	wing.size = Vector3(1.6, 0.03, 0.5)
	_add_part(root, "LeftWing", wing, mat_body,
		Vector3(-0.95, -0.02, 0.2), Vector3.ZERO)
	_add_part(root, "RightWing", wing, mat_body,
		Vector3(0.95, -0.02, 0.2), Vector3.ZERO)

	var fin := BoxMesh.new()
	fin.size = Vector3(0.03, 0.5, 0.4)
	_add_part(root, "TailFin", fin, mat_body,
		Vector3(0, 0.35, 0.9), Vector3.ZERO)

	var canopy := SphereMesh.new()
	canopy.radius = 0.13
	canopy.height = 0.13
	_add_part(root, "Canopy", canopy, mat_canopy,
		Vector3(0, 0.13, -0.5), Vector3.ZERO)

	return root


static func _build_bomber() -> Node3D:
	var root := Node3D.new()
	root.name = "EnemyMesh"

	var mat_body := _make_mat(Color(0.55, 0.56, 0.58), 0.3, 0.5)
	var mat_engine := _make_mat(Color(0.25, 0.25, 0.27), 0.5, 0.3)
	var mat_canopy := _make_canopy_mat()

	var fuselage := CylinderMesh.new()
	fuselage.top_radius = 0.35
	fuselage.bottom_radius = 0.3
	fuselage.height = 2.8
	fuselage.radial_segments = 10
	_add_part(root, "Fuselage", fuselage, mat_body,
		Vector3(0, 0, 0), Vector3(90, 0, 0))

	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.35
	nose.height = 0.8
	nose.radial_segments = 10
	_add_part(root, "NoseCone", nose, mat_body,
		Vector3(0, 0, -1.8), Vector3(90, 0, 0))

	var wing := BoxMesh.new()
	wing.size = Vector3(2.4, 0.04, 0.9)
	_add_part(root, "LeftWing", wing, mat_body,
		Vector3(-1.5, -0.03, 0.1), Vector3.ZERO)
	_add_part(root, "RightWing", wing, mat_body,
		Vector3(1.5, -0.03, 0.1), Vector3.ZERO)

	var engine := CylinderMesh.new()
	engine.top_radius = 0.12
	engine.bottom_radius = 0.12
	engine.height = 0.8
	engine.radial_segments = 8
	_add_part(root, "LeftEngine", engine, mat_engine,
		Vector3(-1.2, -0.15, 0.0), Vector3(90, 0, 0))
	_add_part(root, "RightEngine", engine, mat_engine,
		Vector3(1.2, -0.15, 0.0), Vector3(90, 0, 0))

	var fin := BoxMesh.new()
	fin.size = Vector3(0.04, 0.6, 0.5)
	_add_part(root, "TailFin", fin, mat_body,
		Vector3(0, 0.4, 1.1), Vector3.ZERO)

	var canopy := SphereMesh.new()
	canopy.radius = 0.2
	canopy.height = 0.18
	_add_part(root, "Canopy", canopy, mat_canopy,
		Vector3(0, 0.22, -0.7), Vector3.ZERO)

	return root


static func _add_part(
	parent: Node3D, part_name: String, mesh: Mesh,
	material: StandardMaterial3D, pos: Vector3, rot_deg: Vector3
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


static func _make_mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return mat


static func _make_canopy_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.3, 0.8, 0.7)
	mat.metallic = 0.1
	mat.roughness = 0.1
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return mat
