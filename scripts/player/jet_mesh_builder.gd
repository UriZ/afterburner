extends RefCounted

## Builds a 3D mesh hierarchy for the player F-14 Tomcat from Godot primitives.
## The jet points in -Z (nose forward). Camera behind at +Z sees the rear:
## twin engine nozzles, afterburner flames, swept wings, vertical tail fins.


static func build_player_jet() -> Node3D:
	var root := Node3D.new()
	root.name = "JetMesh"
	# Scale up ~20% overall
	root.scale = Vector3(1.2, 1.2, 1.2)

	# Materials (created once, shared across parts)
	var mat_fuselage := _make_mat(Color(0.92, 0.91, 0.88), 0.0, 0.8)
	var mat_wing := _make_mat(Color(0.82, 0.81, 0.78), 0.0, 0.85)
	var mat_tail_fin := _make_mat(Color(0.85, 0.84, 0.82), 0.0, 0.7)
	var mat_nacelle := _make_mat(Color(0.55, 0.54, 0.52), 0.0, 0.6)
	var mat_nozzle := _make_mat(Color(0.12, 0.12, 0.12), 0.1, 0.35)
	var mat_canopy := _make_mat(Color(0.08, 0.35, 0.85, 0.75), 0.0, 0.25)
	mat_canopy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_canopy.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_flame := StandardMaterial3D.new()
	mat_flame.albedo_color = Color(1.0, 0.6, 0.1, 0.85)
	mat_flame.emission_enabled = true
	mat_flame.emission = Color(1.0, 0.5, 0.0)
	mat_flame.emission_energy_multiplier = 3.0
	mat_flame.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Fuselage -- cylinder laid along Z
	var fuselage_mesh := CylinderMesh.new()
	fuselage_mesh.top_radius = 0.35
	fuselage_mesh.bottom_radius = 0.3
	fuselage_mesh.height = 3.0
	fuselage_mesh.radial_segments = 12
	_add_part(root, "Fuselage", fuselage_mesh, mat_fuselage,
		Vector3(0, 0, 0), Vector3(90, 0, 0))

	# Rear fuselage taper between nacelles
	var rear_taper_mesh := CylinderMesh.new()
	rear_taper_mesh.top_radius = 0.3
	rear_taper_mesh.bottom_radius = 0.18
	rear_taper_mesh.height = 0.8
	rear_taper_mesh.radial_segments = 12
	_add_part(root, "RearTaper", rear_taper_mesh, mat_fuselage,
		Vector3(0, -0.05, 1.4), Vector3(90, 0, 0))

	# Nose cone
	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.0
	nose_mesh.bottom_radius = 0.3
	nose_mesh.height = 1.0
	nose_mesh.radial_segments = 12
	_add_part(root, "NoseCone", nose_mesh, mat_fuselage,
		Vector3(0, 0, -2.0), Vector3(90, 0, 0))

	# Wings -- wider at root, narrower at tip, more sweep via rotation
	var wing_mesh := BoxMesh.new()
	wing_mesh.size = Vector3(2.5, 0.04, 0.9)
	# Sweep wings back with Y rotation; anhedral with Z
	_add_part(root, "LeftWing", wing_mesh, mat_wing,
		Vector3(-1.5, -0.05, 0.1), Vector3(0, 12, -8))
	_add_part(root, "RightWing", wing_mesh, mat_wing,
		Vector3(1.5, -0.05, 0.1), Vector3(0, -12, 8))

	# Tail fins -- canted outward by ~12 degrees
	var fin_mesh := BoxMesh.new()
	fin_mesh.size = Vector3(0.04, 0.7, 0.5)
	_add_part(root, "LeftTailFin", fin_mesh, mat_tail_fin,
		Vector3(-0.5, 0.45, 1.2), Vector3(0, 0, -12))
	_add_part(root, "RightTailFin", fin_mesh, mat_tail_fin,
		Vector3(0.5, 0.45, 1.2), Vector3(0, 0, 12))

	# Engine nacelles -- wider separation (X=0.5)
	var nacelle_mesh := CylinderMesh.new()
	nacelle_mesh.top_radius = 0.15
	nacelle_mesh.bottom_radius = 0.18
	nacelle_mesh.height = 1.4
	nacelle_mesh.radial_segments = 8
	_add_part(root, "LeftNacelle", nacelle_mesh, mat_nacelle,
		Vector3(-0.5, -0.1, 0.8), Vector3(90, 0, 0))
	_add_part(root, "RightNacelle", nacelle_mesh, mat_nacelle,
		Vector3(0.5, -0.1, 0.8), Vector3(90, 0, 0))

	# Engine nozzles
	var nozzle_mesh := CylinderMesh.new()
	nozzle_mesh.top_radius = 0.18
	nozzle_mesh.bottom_radius = 0.12
	nozzle_mesh.height = 0.15
	nozzle_mesh.radial_segments = 8
	_add_part(root, "LeftNozzle", nozzle_mesh, mat_nozzle,
		Vector3(-0.5, -0.1, 1.55), Vector3(90, 0, 0))
	_add_part(root, "RightNozzle", nozzle_mesh, mat_nozzle,
		Vector3(0.5, -0.1, 1.55), Vector3(90, 0, 0))

	# Canopy — low-profile bubble
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 0.18
	canopy_mesh.height = 0.14
	_add_part(root, "Canopy", canopy_mesh, mat_canopy,
		Vector3(0, 0.2, -0.6), Vector3.ZERO)

	# Horizontal stabilizers
	var hstab_mesh := BoxMesh.new()
	hstab_mesh.size = Vector3(0.7, 0.03, 0.35)
	_add_part(root, "LeftHStab", hstab_mesh, mat_wing,
		Vector3(-0.7, 0.0, 1.1), Vector3(0, 0, -5))
	_add_part(root, "RightHStab", hstab_mesh, mat_wing,
		Vector3(0.7, 0.0, 1.1), Vector3(0, 0, 5))

	# Afterburner flame cones
	var flame_mesh := CylinderMesh.new()
	flame_mesh.top_radius = 0.12
	flame_mesh.bottom_radius = 0.02
	flame_mesh.height = 0.5
	flame_mesh.radial_segments = 6
	_add_part(root, "LeftFlame", flame_mesh, mat_flame,
		Vector3(-0.5, -0.1, 1.8), Vector3(90, 0, 0))
	_add_part(root, "RightFlame", flame_mesh, mat_flame,
		Vector3(0.5, -0.1, 1.8), Vector3(90, 0, 0))

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
