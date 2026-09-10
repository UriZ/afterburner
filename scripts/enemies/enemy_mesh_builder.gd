extends RefCounted

## Builds detailed 3D mesh hierarchies for enemy jets from Godot primitives.
## Types: 0=FIGHTER (red, MiG-21), 1=INTERCEPTOR (green, MiG-25), 2=BOMBER (grey, Tu-22).
## Nose at -Z, enemies fly toward camera (+Z direction).
## Each type uses 15-25 primitives for convincing aircraft silhouettes.


static func build_enemy_mesh(type: int) -> Node3D:
	match type:
		0: return _build_fighter()
		1: return _build_interceptor()
		2: return _build_bomber()
		_: return _build_fighter()


# ==============================================================
# FIGHTER — MiG-21 style: delta wings, single tail, pointed nose
# ==============================================================

static func _build_fighter() -> Node3D:
	var root := Node3D.new()
	root.name = "EnemyMesh"

	# Vivid saturated red — arcade iconic
	var mat_body := _make_mat(Color(0.95, 0.08, 0.04), 0.2, 0.35, Color(0.4, 0.0, 0.0))
	var mat_body_dark := _make_mat(Color(0.70, 0.05, 0.02), 0.2, 0.4, Color(0.2, 0.0, 0.0))
	var mat_wing := _make_mat(Color(0.90, 0.06, 0.03), 0.15, 0.45, Color(0.35, 0.0, 0.0))
	var mat_nozzle := _make_mat(Color(0.15, 0.15, 0.15), 0.7, 0.2, Color(0.5, 0.25, 0.0))
	var mat_canopy := _make_canopy_mat()
	var mat_accent := _make_mat(Color(1.0, 0.85, 0.0), 0.3, 0.3, Color(0.6, 0.4, 0.0))

	# Fuselage — sharp taper toward nose
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.10
	nose.height = 0.50
	nose.radial_segments = 8
	_add_part(root, "NoseCone", nose, mat_body,
		Vector3(0, 0, -1.45), Vector3(90, 0, 0))

	var fuse_fwd := CylinderMesh.new()
	fuse_fwd.top_radius = 0.10
	fuse_fwd.bottom_radius = 0.19
	fuse_fwd.height = 0.55
	fuse_fwd.radial_segments = 8
	_add_part(root, "FuseForward", fuse_fwd, mat_body,
		Vector3(0, 0, -1.0), Vector3(90, 0, 0))

	var fuse_main := CylinderMesh.new()
	fuse_main.top_radius = 0.19
	fuse_main.bottom_radius = 0.21
	fuse_main.height = 0.85
	fuse_main.radial_segments = 8
	_add_part(root, "Fuselage", fuse_main, mat_body,
		Vector3(0, 0, -0.22), Vector3(90, 0, 0))

	var fuse_rear := CylinderMesh.new()
	fuse_rear.top_radius = 0.21
	fuse_rear.bottom_radius = 0.13
	fuse_rear.height = 0.75
	fuse_rear.radial_segments = 8
	_add_part(root, "FuseRear", fuse_rear, mat_body_dark,
		Vector3(0, 0, 0.55), Vector3(90, 0, 0))

	# Delta wings — aggressive sweep angles to read as delta from front
	# Inner wing root — close to body, angled back strongly
	var wing_root := BoxMesh.new()
	wing_root.size = Vector3(0.65, 0.035, 0.60)
	_add_part(root, "LeftWingRoot", wing_root, mat_wing,
		Vector3(-0.45, -0.02, 0.05), Vector3(0, 28, -3))
	_add_part(root, "RightWingRoot", wing_root, mat_wing,
		Vector3(0.45, -0.02, 0.05), Vector3(0, -28, 3))

	# Outer wing panel — even more swept, thinning to tip
	var wing_outer := BoxMesh.new()
	wing_outer.size = Vector3(0.55, 0.022, 0.40)
	_add_part(root, "LeftWing", wing_outer, mat_wing,
		Vector3(-1.05, -0.04, 0.22), Vector3(0, 35, -5))
	_add_part(root, "RightWing", wing_outer, mat_wing,
		Vector3(1.05, -0.04, 0.22), Vector3(0, -35, 5))

	# Wing tip accent stripe — yellow, pops visually
	var wing_tip := BoxMesh.new()
	wing_tip.size = Vector3(0.12, 0.025, 0.18)
	_add_part(root, "LeftWingTip", wing_tip, mat_accent,
		Vector3(-1.40, -0.04, 0.32), Vector3(0, 38, -5))
	_add_part(root, "RightWingTip", wing_tip, mat_accent,
		Vector3(1.40, -0.04, 0.32), Vector3(0, -38, 5))

	# Single vertical tail fin — tall, swept back
	var fin_main := BoxMesh.new()
	fin_main.size = Vector3(0.035, 0.50, 0.38)
	_add_part(root, "TailFin", fin_main, mat_body,
		Vector3(0, 0.32, 0.72), Vector3(-8, 0, 0))

	# Fin tip accent
	var fin_tip := BoxMesh.new()
	fin_tip.size = Vector3(0.028, 0.14, 0.18)
	_add_part(root, "TailFinTip", fin_tip, mat_accent,
		Vector3(0, 0.60, 0.68), Vector3(-10, 0, 0))

	# Engine nozzle — hot orange glow
	var nozzle := CylinderMesh.new()
	nozzle.top_radius = 0.14
	nozzle.bottom_radius = 0.09
	nozzle.height = 0.12
	nozzle.radial_segments = 8
	_add_part(root, "Nozzle", nozzle, mat_nozzle,
		Vector3(0, 0, 0.97), Vector3(90, 0, 0))

	# Canopy — dark tinted
	var canopy := SphereMesh.new()
	canopy.radius = 0.12
	canopy.height = 0.13
	_add_part(root, "Canopy", canopy, mat_canopy,
		Vector3(0, 0.15, -0.50), Vector3.ZERO)

	# Horizontal stabs — swept
	var hstab := BoxMesh.new()
	hstab.size = Vector3(0.38, 0.022, 0.22)
	_add_part(root, "LeftHStab", hstab, mat_wing,
		Vector3(-0.32, -0.01, 0.80), Vector3(0, 12, -3))
	_add_part(root, "RightHStab", hstab, mat_wing,
		Vector3(0.32, -0.01, 0.80), Vector3(0, -12, 3))

	# Intake scoop — darker red for contrast
	var intake := BoxMesh.new()
	intake.size = Vector3(0.14, 0.09, 0.35)
	_add_part(root, "Intake", intake, mat_body_dark,
		Vector3(0, -0.13, -0.60), Vector3.ZERO)

	# Dorsal spine — accent stripe
	var spine := BoxMesh.new()
	spine.size = Vector3(0.05, 0.05, 1.1)
	_add_part(root, "Spine", spine, mat_body_dark,
		Vector3(0, 0.17, 0.05), Vector3.ZERO)

	return root


# ==============================================================
# INTERCEPTOR — MiG-25 style: twin tails, large intakes, long fuselage
# ==============================================================

static func _build_interceptor() -> Node3D:
	var root := Node3D.new()
	root.name = "EnemyMesh"

	# Vivid saturated green
	var mat_body := _make_mat(Color(0.05, 0.85, 0.12), 0.2, 0.35, Color(0.0, 0.35, 0.0))
	var mat_body_dark := _make_mat(Color(0.03, 0.60, 0.08), 0.2, 0.4, Color(0.0, 0.2, 0.0))
	var mat_wing := _make_mat(Color(0.04, 0.78, 0.10), 0.15, 0.45, Color(0.0, 0.28, 0.0))
	var mat_nacelle := _make_mat(Color(0.03, 0.55, 0.07), 0.3, 0.4, Color(0.0, 0.15, 0.0))
	var mat_nozzle := _make_mat(Color(0.15, 0.15, 0.15), 0.7, 0.2, Color(0.5, 0.25, 0.0))
	var mat_canopy := _make_canopy_mat()
	var mat_accent := _make_mat(Color(0.9, 1.0, 0.1), 0.3, 0.3, Color(0.5, 0.5, 0.0))

	# Fuselage — long and slim
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.10
	nose.height = 0.55
	nose.radial_segments = 8
	_add_part(root, "NoseCone", nose, mat_body,
		Vector3(0, 0, -1.78), Vector3(90, 0, 0))

	var fuse_fwd := CylinderMesh.new()
	fuse_fwd.top_radius = 0.10
	fuse_fwd.bottom_radius = 0.17
	fuse_fwd.height = 0.65
	fuse_fwd.radial_segments = 8
	_add_part(root, "FuseForward", fuse_fwd, mat_body,
		Vector3(0, 0, -1.15), Vector3(90, 0, 0))

	var fuse_main := CylinderMesh.new()
	fuse_main.top_radius = 0.17
	fuse_main.bottom_radius = 0.19
	fuse_main.height = 1.15
	fuse_main.radial_segments = 8
	_add_part(root, "Fuselage", fuse_main, mat_body,
		Vector3(0, 0, -0.2), Vector3(90, 0, 0))

	var fuse_rear := CylinderMesh.new()
	fuse_rear.top_radius = 0.19
	fuse_rear.bottom_radius = 0.12
	fuse_rear.height = 0.85
	fuse_rear.radial_segments = 8
	_add_part(root, "FuseRear", fuse_rear, mat_body_dark,
		Vector3(0, 0, 0.82), Vector3(90, 0, 0))

	# Large intake ramps — distinctive MiG-25 feature, big rectangular scoops
	var intake := BoxMesh.new()
	intake.size = Vector3(0.18, 0.16, 0.55)
	_add_part(root, "LeftIntake", intake, mat_nacelle,
		Vector3(-0.25, -0.04, -0.48), Vector3.ZERO)
	_add_part(root, "RightIntake", intake, mat_nacelle,
		Vector3(0.25, -0.04, -0.48), Vector3.ZERO)

	# Intake accent lips — bright green strip
	var intake_lip := BoxMesh.new()
	intake_lip.size = Vector3(0.18, 0.025, 0.04)
	_add_part(root, "LeftIntakeLip", intake_lip, mat_accent,
		Vector3(-0.25, -0.04, -0.76), Vector3.ZERO)
	_add_part(root, "RightIntakeLip", intake_lip, mat_accent,
		Vector3(0.25, -0.04, -0.76), Vector3.ZERO)

	# Wings — moderately swept, wider span than fighter
	var wing_inner := BoxMesh.new()
	wing_inner.size = Vector3(0.85, 0.032, 0.48)
	_add_part(root, "LeftWingInner", wing_inner, mat_wing,
		Vector3(-0.62, -0.02, 0.12), Vector3(0, 18, -2))
	_add_part(root, "RightWingInner", wing_inner, mat_wing,
		Vector3(0.62, -0.02, 0.12), Vector3(0, -18, 2))

	var wing_outer := BoxMesh.new()
	wing_outer.size = Vector3(0.55, 0.022, 0.32)
	_add_part(root, "LeftWing", wing_outer, mat_wing,
		Vector3(-1.22, -0.04, 0.24), Vector3(0, 25, -4))
	_add_part(root, "RightWing", wing_outer, mat_wing,
		Vector3(1.22, -0.04, 0.24), Vector3(0, -25, 4))

	# Wing tip accents
	var wing_tip := BoxMesh.new()
	wing_tip.size = Vector3(0.10, 0.025, 0.14)
	_add_part(root, "LeftWingTip", wing_tip, mat_accent,
		Vector3(-1.58, -0.04, 0.32), Vector3(0, 28, -4))
	_add_part(root, "RightWingTip", wing_tip, mat_accent,
		Vector3(1.58, -0.04, 0.32), Vector3(0, -28, 4))

	# Twin vertical tail fins — canted outward
	var fin := BoxMesh.new()
	fin.size = Vector3(0.035, 0.46, 0.38)
	_add_part(root, "TailFinL", fin, mat_body,
		Vector3(-0.28, 0.30, 1.02), Vector3(-6, 0, -14))
	_add_part(root, "TailFinR", fin, mat_body,
		Vector3(0.28, 0.30, 1.02), Vector3(-6, 0, 14))

	# Fin tips — accent yellow
	var fin_tip := BoxMesh.new()
	fin_tip.size = Vector3(0.028, 0.12, 0.20)
	_add_part(root, "TailFinTipL", fin_tip, mat_accent,
		Vector3(-0.33, 0.56, 0.97), Vector3(-6, 0, -14))
	_add_part(root, "TailFinTipR", fin_tip, mat_accent,
		Vector3(0.33, 0.56, 0.97), Vector3(-6, 0, 14))

	# Twin engine nozzles
	var nozzle := CylinderMesh.new()
	nozzle.top_radius = 0.12
	nozzle.bottom_radius = 0.08
	nozzle.height = 0.12
	nozzle.radial_segments = 8
	_add_part(root, "LeftNozzle", nozzle, mat_nozzle,
		Vector3(-0.24, -0.04, 1.28), Vector3(90, 0, 0))
	_add_part(root, "RightNozzle", nozzle, mat_nozzle,
		Vector3(0.24, -0.04, 1.28), Vector3(90, 0, 0))

	# Canopy
	var canopy := SphereMesh.new()
	canopy.radius = 0.11
	canopy.height = 0.11
	_add_part(root, "Canopy", canopy, mat_canopy,
		Vector3(0, 0.13, -0.72), Vector3.ZERO)

	# Horizontal stabilizers
	var hstab := BoxMesh.new()
	hstab.size = Vector3(0.42, 0.022, 0.24)
	_add_part(root, "LeftHStab", hstab, mat_wing,
		Vector3(-0.42, -0.01, 1.08), Vector3(0, 10, -3))
	_add_part(root, "RightHStab", hstab, mat_wing,
		Vector3(0.42, -0.01, 1.08), Vector3(0, -10, 3))

	return root


# ==============================================================
# BOMBER — Tu-22 style: wide fuselage, swept wings, underwing engines
# ==============================================================

static func _build_bomber() -> Node3D:
	var root := Node3D.new()
	root.name = "EnemyMesh"

	# Lighter grey with contrast — light top, dark belly
	var mat_body := _make_mat(Color(0.78, 0.80, 0.84), 0.25, 0.45, Color(0.08, 0.08, 0.10))
	var mat_body_dark := _make_mat(Color(0.30, 0.30, 0.34), 0.25, 0.5, Color(0.02, 0.02, 0.04))
	var mat_wing := _make_mat(Color(0.72, 0.74, 0.78), 0.2, 0.5, Color(0.06, 0.06, 0.08))
	var mat_engine := _make_mat(Color(0.20, 0.20, 0.24), 0.6, 0.3, Color(0.02, 0.02, 0.04))
	var mat_engine_lip := _make_mat(Color(0.55, 0.56, 0.60), 0.5, 0.3, Color(0.08, 0.08, 0.10))
	var mat_nozzle := _make_mat(Color(0.12, 0.12, 0.12), 0.7, 0.2, Color(0.6, 0.28, 0.0))
	var mat_canopy := _make_canopy_mat()
	var mat_accent := _make_mat(Color(0.9, 0.1, 0.05), 0.2, 0.3, Color(0.5, 0.0, 0.0))

	# Fuselage — wide, 4 sections
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.23
	nose.height = 0.75
	nose.radial_segments = 10
	_add_part(root, "NoseCone", nose, mat_body,
		Vector3(0, 0, -2.05), Vector3(90, 0, 0))

	var fuse_fwd := CylinderMesh.new()
	fuse_fwd.top_radius = 0.23
	fuse_fwd.bottom_radius = 0.34
	fuse_fwd.height = 0.80
	fuse_fwd.radial_segments = 10
	_add_part(root, "FuseForward", fuse_fwd, mat_body,
		Vector3(0, 0, -1.32), Vector3(90, 0, 0))

	var fuse_main := CylinderMesh.new()
	fuse_main.top_radius = 0.34
	fuse_main.bottom_radius = 0.36
	fuse_main.height = 1.35
	fuse_main.radial_segments = 10
	_add_part(root, "Fuselage", fuse_main, mat_body,
		Vector3(0, 0, -0.22), Vector3(90, 0, 0))

	var fuse_rear := CylinderMesh.new()
	fuse_rear.top_radius = 0.36
	fuse_rear.bottom_radius = 0.18
	fuse_rear.height = 1.05
	fuse_rear.radial_segments = 10
	_add_part(root, "FuseRear", fuse_rear, mat_body_dark,
		Vector3(0, 0, 0.72), Vector3(90, 0, 0))

	# Swept wings — aggressive taper for bomber silhouette
	var wing_inner := BoxMesh.new()
	wing_inner.size = Vector3(1.25, 0.045, 0.80)
	_add_part(root, "LeftWingInner", wing_inner, mat_wing,
		Vector3(-0.95, -0.04, 0.05), Vector3(0, 16, -2))
	_add_part(root, "RightWingInner", wing_inner, mat_wing,
		Vector3(0.95, -0.04, 0.05), Vector3(0, -16, 2))

	var wing_outer := BoxMesh.new()
	wing_outer.size = Vector3(0.75, 0.032, 0.52)
	_add_part(root, "LeftWing", wing_outer, mat_wing,
		Vector3(-1.88, -0.05, 0.20), Vector3(0, 22, -4))
	_add_part(root, "RightWing", wing_outer, mat_wing,
		Vector3(1.88, -0.05, 0.20), Vector3(0, -22, 4))

	# Wing tip accent — red stripe for visibility
	var wing_tip := BoxMesh.new()
	wing_tip.size = Vector3(0.15, 0.038, 0.20)
	_add_part(root, "LeftWingTip", wing_tip, mat_accent,
		Vector3(-2.40, -0.05, 0.28), Vector3(0, 24, -4))
	_add_part(root, "RightWingTip", wing_tip, mat_accent,
		Vector3(2.40, -0.05, 0.28), Vector3(0, -24, 4))

	# Underwing engine pods — prominent, dark cylinders
	var eng_lip := CylinderMesh.new()
	eng_lip.top_radius = 0.15
	eng_lip.bottom_radius = 0.14
	eng_lip.height = 0.10
	eng_lip.radial_segments = 8
	_add_part(root, "LeftEngIntake", eng_lip, mat_engine_lip,
		Vector3(-1.15, -0.18, -0.28), Vector3(90, 0, 0))
	_add_part(root, "RightEngIntake", eng_lip, mat_engine_lip,
		Vector3(1.15, -0.18, -0.28), Vector3(90, 0, 0))

	var eng_body := CylinderMesh.new()
	eng_body.top_radius = 0.14
	eng_body.bottom_radius = 0.12
	eng_body.height = 0.75
	eng_body.radial_segments = 8
	_add_part(root, "LeftEngine", eng_body, mat_engine,
		Vector3(-1.15, -0.18, 0.10), Vector3(90, 0, 0))
	_add_part(root, "RightEngine", eng_body, mat_engine,
		Vector3(1.15, -0.18, 0.10), Vector3(90, 0, 0))

	var eng_nozzle := CylinderMesh.new()
	eng_nozzle.top_radius = 0.12
	eng_nozzle.bottom_radius = 0.08
	eng_nozzle.height = 0.10
	eng_nozzle.radial_segments = 8
	_add_part(root, "LeftEngNozzle", eng_nozzle, mat_nozzle,
		Vector3(-1.15, -0.18, 0.52), Vector3(90, 0, 0))
	_add_part(root, "RightEngNozzle", eng_nozzle, mat_nozzle,
		Vector3(1.15, -0.18, 0.52), Vector3(90, 0, 0))

	# Twin vertical tail fins — swept back, taller for bomber scale
	var fin := BoxMesh.new()
	fin.size = Vector3(0.045, 0.55, 0.44)
	_add_part(root, "TailFinL", fin, mat_body,
		Vector3(-0.22, 0.38, 1.05), Vector3(-8, 0, -10))
	_add_part(root, "TailFinR", fin, mat_body,
		Vector3(0.22, 0.38, 1.05), Vector3(-8, 0, 10))

	# Fin tips — red accent
	var fin_tip := BoxMesh.new()
	fin_tip.size = Vector3(0.04, 0.16, 0.26)
	_add_part(root, "TailFinTipL", fin_tip, mat_accent,
		Vector3(-0.25, 0.68, 1.00), Vector3(-8, 0, -10))
	_add_part(root, "TailFinTipR", fin_tip, mat_accent,
		Vector3(0.25, 0.68, 1.00), Vector3(-8, 0, 10))

	# Canopy — wider for bomber
	var canopy := SphereMesh.new()
	canopy.radius = 0.18
	canopy.height = 0.17
	_add_part(root, "Canopy", canopy, mat_canopy,
		Vector3(0, 0.24, -1.02), Vector3.ZERO)

	# Horizontal stabilizers
	var hstab := BoxMesh.new()
	hstab.size = Vector3(0.58, 0.032, 0.32)
	_add_part(root, "LeftHStab", hstab, mat_wing,
		Vector3(-0.52, -0.01, 1.08), Vector3(0, 10, -3))
	_add_part(root, "RightHStab", hstab, mat_wing,
		Vector3(0.52, -0.01, 1.08), Vector3(0, -10, 3))

	# Dorsal spine — dark stripe for contrast
	var spine := BoxMesh.new()
	spine.size = Vector3(0.07, 0.055, 1.55)
	_add_part(root, "Spine", spine, mat_body_dark,
		Vector3(0, 0.30, -0.18), Vector3.ZERO)

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


static func _make_mat(color: Color, metallic: float, roughness: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.2
	return mat


static func _make_canopy_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.15, 0.6, 0.75)
	mat.metallic = 0.2
	mat.roughness = 0.05
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.05, 0.3)
	mat.emission_energy_multiplier = 0.8
	return mat
