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

	var mat_body := _make_mat(Color(0.85, 0.15, 0.1), 0.3, 0.4)
	var mat_body_dark := _make_mat(Color(0.70, 0.12, 0.08), 0.3, 0.45)
	var mat_wing := _make_mat(Color(0.78, 0.13, 0.09), 0.25, 0.5)
	var mat_nozzle := _make_mat(Color(0.12, 0.12, 0.12), 0.3, 0.3)
	var mat_canopy := _make_canopy_mat()

	# Fuselage — 4 sections for smooth taper
	# Nose cone — sharp point
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.10
	nose.height = 0.45
	nose.radial_segments = 8
	_add_part(root, "NoseCone", nose, mat_body,
		Vector3(0, 0, -1.45), Vector3(90, 0, 0))

	# Forward fuselage
	var fuse_fwd := CylinderMesh.new()
	fuse_fwd.top_radius = 0.10
	fuse_fwd.bottom_radius = 0.18
	fuse_fwd.height = 0.6
	fuse_fwd.radial_segments = 8
	_add_part(root, "FuseForward", fuse_fwd, mat_body,
		Vector3(0, 0, -1.0), Vector3(90, 0, 0))

	# Main fuselage — widest section
	var fuse_main := CylinderMesh.new()
	fuse_main.top_radius = 0.18
	fuse_main.bottom_radius = 0.20
	fuse_main.height = 0.9
	fuse_main.radial_segments = 8
	_add_part(root, "Fuselage", fuse_main, mat_body,
		Vector3(0, 0, -0.25), Vector3(90, 0, 0))

	# Rear fuselage — tapers to nozzle
	var fuse_rear := CylinderMesh.new()
	fuse_rear.top_radius = 0.20
	fuse_rear.bottom_radius = 0.14
	fuse_rear.height = 0.7
	fuse_rear.radial_segments = 8
	_add_part(root, "FuseRear", fuse_rear, mat_body_dark,
		Vector3(0, 0, 0.55), Vector3(90, 0, 0))

	# Delta wings — 2 parts each for sweep shape
	# Wing root
	var wing_root := BoxMesh.new()
	wing_root.size = Vector3(0.7, 0.03, 0.55)
	_add_part(root, "LeftWingRoot", wing_root, mat_wing,
		Vector3(-0.5, -0.02, 0.0), Vector3(0, 15, -2))
	_add_part(root, "RightWingRoot", wing_root, mat_wing,
		Vector3(0.5, -0.02, 0.0), Vector3(0, -15, 2))

	# Wing outer — thinner, more swept
	var wing_outer := BoxMesh.new()
	wing_outer.size = Vector3(0.5, 0.02, 0.35)
	_add_part(root, "LeftWing", wing_outer, mat_wing,
		Vector3(-1.0, -0.03, 0.15), Vector3(0, 20, -4))
	_add_part(root, "RightWing", wing_outer, mat_wing,
		Vector3(1.0, -0.03, 0.15), Vector3(0, -20, 4))

	# Single vertical tail fin — tall, thin
	var fin_main := BoxMesh.new()
	fin_main.size = Vector3(0.03, 0.45, 0.35)
	_add_part(root, "TailFin", fin_main, mat_body,
		Vector3(0, 0.30, 0.75), Vector3.ZERO)

	# Fin tip
	var fin_tip := BoxMesh.new()
	fin_tip.size = Vector3(0.025, 0.15, 0.2)
	_add_part(root, "TailFinTip", fin_tip, mat_body,
		Vector3(0, 0.55, 0.7), Vector3.ZERO)

	# Engine nozzle
	var nozzle := CylinderMesh.new()
	nozzle.top_radius = 0.14
	nozzle.bottom_radius = 0.10
	nozzle.height = 0.1
	nozzle.radial_segments = 8
	_add_part(root, "Nozzle", nozzle, mat_nozzle,
		Vector3(0, 0, 0.95), Vector3(90, 0, 0))

	# Canopy — flush bubble
	var canopy := SphereMesh.new()
	canopy.radius = 0.12
	canopy.height = 0.12
	_add_part(root, "Canopy", canopy, mat_canopy,
		Vector3(0, 0.14, -0.5), Vector3.ZERO)

	# Small horizontal stabs
	var hstab := BoxMesh.new()
	hstab.size = Vector3(0.35, 0.02, 0.2)
	_add_part(root, "LeftHStab", hstab, mat_wing,
		Vector3(-0.3, 0.0, 0.8), Vector3(0, 5, -3))
	_add_part(root, "RightHStab", hstab, mat_wing,
		Vector3(0.3, 0.0, 0.8), Vector3(0, -5, 3))

	# Intake — visible from front, small scoop under nose
	var intake := BoxMesh.new()
	intake.size = Vector3(0.12, 0.08, 0.3)
	_add_part(root, "Intake", intake, mat_body_dark,
		Vector3(0, -0.12, -0.6), Vector3.ZERO)

	# Dorsal spine
	var spine := BoxMesh.new()
	spine.size = Vector3(0.05, 0.04, 1.2)
	_add_part(root, "Spine", spine, mat_body_dark,
		Vector3(0, 0.16, 0.0), Vector3.ZERO)

	# Wing leading edge strips
	var wing_edge := BoxMesh.new()
	wing_edge.size = Vector3(0.9, 0.015, 0.04)
	_add_part(root, "LeftWingEdge", wing_edge, mat_body_dark,
		Vector3(-0.7, -0.02, -0.2), Vector3(0, 18, -3))
	_add_part(root, "RightWingEdge", wing_edge, mat_body_dark,
		Vector3(0.7, -0.02, -0.2), Vector3(0, -18, 3))

	return root


# ==============================================================
# INTERCEPTOR — MiG-25 style: twin tails, large intakes, long fuselage
# ==============================================================

static func _build_interceptor() -> Node3D:
	var root := Node3D.new()
	root.name = "EnemyMesh"

	var mat_body := _make_mat(Color(0.1, 0.65, 0.2), 0.3, 0.4)
	var mat_body_dark := _make_mat(Color(0.08, 0.52, 0.16), 0.3, 0.45)
	var mat_wing := _make_mat(Color(0.09, 0.58, 0.18), 0.25, 0.5)
	var mat_nacelle := _make_mat(Color(0.07, 0.42, 0.14), 0.35, 0.4)
	var mat_nozzle := _make_mat(Color(0.10, 0.10, 0.10), 0.3, 0.3)
	var mat_canopy := _make_canopy_mat()

	# Fuselage — long and slim, 4 sections
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.10
	nose.height = 0.5
	nose.radial_segments = 8
	_add_part(root, "NoseCone", nose, mat_body,
		Vector3(0, 0, -1.75), Vector3(90, 0, 0))

	var fuse_fwd := CylinderMesh.new()
	fuse_fwd.top_radius = 0.10
	fuse_fwd.bottom_radius = 0.16
	fuse_fwd.height = 0.7
	fuse_fwd.radial_segments = 8
	_add_part(root, "FuseForward", fuse_fwd, mat_body,
		Vector3(0, 0, -1.15), Vector3(90, 0, 0))

	var fuse_main := CylinderMesh.new()
	fuse_main.top_radius = 0.16
	fuse_main.bottom_radius = 0.18
	fuse_main.height = 1.2
	fuse_main.radial_segments = 8
	_add_part(root, "Fuselage", fuse_main, mat_body,
		Vector3(0, 0, -0.2), Vector3(90, 0, 0))

	var fuse_rear := CylinderMesh.new()
	fuse_rear.top_radius = 0.18
	fuse_rear.bottom_radius = 0.12
	fuse_rear.height = 0.8
	fuse_rear.radial_segments = 8
	_add_part(root, "FuseRear", fuse_rear, mat_body_dark,
		Vector3(0, 0, 0.8), Vector3(90, 0, 0))

	# Large intake ramps — boxy, flanking forward fuselage
	var intake := BoxMesh.new()
	intake.size = Vector3(0.16, 0.14, 0.5)
	_add_part(root, "LeftIntake", intake, mat_nacelle,
		Vector3(-0.22, -0.04, -0.5), Vector3.ZERO)
	_add_part(root, "RightIntake", intake, mat_nacelle,
		Vector3(0.22, -0.04, -0.5), Vector3.ZERO)

	# Wings — moderately swept
	var wing_inner := BoxMesh.new()
	wing_inner.size = Vector3(0.8, 0.03, 0.45)
	_add_part(root, "LeftWingInner", wing_inner, mat_wing,
		Vector3(-0.6, -0.02, 0.1), Vector3(0, 12, -2))
	_add_part(root, "RightWingInner", wing_inner, mat_wing,
		Vector3(0.6, -0.02, 0.1), Vector3(0, -12, 2))

	var wing_outer := BoxMesh.new()
	wing_outer.size = Vector3(0.5, 0.02, 0.3)
	_add_part(root, "LeftWing", wing_outer, mat_wing,
		Vector3(-1.15, -0.03, 0.2), Vector3(0, 15, -4))
	_add_part(root, "RightWing", wing_outer, mat_wing,
		Vector3(1.15, -0.03, 0.2), Vector3(0, -15, 4))

	# Twin vertical tail fins — canted outward
	var fin := BoxMesh.new()
	fin.size = Vector3(0.03, 0.42, 0.35)
	_add_part(root, "TailFin", fin, mat_body,
		Vector3(-0.25, 0.28, 1.0), Vector3(0, 0, -12))
	# Second fin (unique name)
	_add_part(root, "TailFinR", fin, mat_body,
		Vector3(0.25, 0.28, 1.0), Vector3(0, 0, 12))

	# Fin tips
	var fin_tip := BoxMesh.new()
	fin_tip.size = Vector3(0.025, 0.14, 0.22)
	_add_part(root, "TailFinTipL", fin_tip, mat_body,
		Vector3(-0.28, 0.52, 0.95), Vector3(0, 0, -12))
	_add_part(root, "TailFinTipR", fin_tip, mat_body,
		Vector3(0.28, 0.52, 0.95), Vector3(0, 0, 12))

	# Engine nozzles — twin
	var nozzle := CylinderMesh.new()
	nozzle.top_radius = 0.12
	nozzle.bottom_radius = 0.09
	nozzle.height = 0.1
	nozzle.radial_segments = 8
	_add_part(root, "LeftNozzle", nozzle, mat_nozzle,
		Vector3(-0.22, -0.04, 1.25), Vector3(90, 0, 0))
	_add_part(root, "RightNozzle", nozzle, mat_nozzle,
		Vector3(0.22, -0.04, 1.25), Vector3(90, 0, 0))

	# Canopy
	var canopy := SphereMesh.new()
	canopy.radius = 0.11
	canopy.height = 0.10
	_add_part(root, "Canopy", canopy, mat_canopy,
		Vector3(0, 0.12, -0.7), Vector3.ZERO)

	# Horizontal stabilizers
	var hstab := BoxMesh.new()
	hstab.size = Vector3(0.4, 0.02, 0.22)
	_add_part(root, "LeftHStab", hstab, mat_wing,
		Vector3(-0.4, 0.0, 1.05), Vector3(0, 8, -3))
	_add_part(root, "RightHStab", hstab, mat_wing,
		Vector3(0.4, 0.0, 1.05), Vector3(0, -8, 3))

	return root


# ==============================================================
# BOMBER — Tu-22 style: wide fuselage, swept wings, underwing engines
# ==============================================================

static func _build_bomber() -> Node3D:
	var root := Node3D.new()
	root.name = "EnemyMesh"

	var mat_body := _make_mat(Color(0.55, 0.56, 0.58), 0.3, 0.5)
	var mat_body_dark := _make_mat(Color(0.45, 0.46, 0.48), 0.3, 0.55)
	var mat_wing := _make_mat(Color(0.50, 0.51, 0.53), 0.25, 0.55)
	var mat_engine := _make_mat(Color(0.25, 0.25, 0.27), 0.5, 0.3)
	var mat_engine_lip := _make_mat(Color(0.32, 0.32, 0.34), 0.45, 0.35)
	var mat_nozzle := _make_mat(Color(0.10, 0.10, 0.10), 0.3, 0.3)
	var mat_canopy := _make_canopy_mat()

	# Fuselage — wide, 4 sections
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.22
	nose.height = 0.7
	nose.radial_segments = 10
	_add_part(root, "NoseCone", nose, mat_body,
		Vector3(0, 0, -2.05), Vector3(90, 0, 0))

	var fuse_fwd := CylinderMesh.new()
	fuse_fwd.top_radius = 0.22
	fuse_fwd.bottom_radius = 0.32
	fuse_fwd.height = 0.8
	fuse_fwd.radial_segments = 10
	_add_part(root, "FuseForward", fuse_fwd, mat_body,
		Vector3(0, 0, -1.3), Vector3(90, 0, 0))

	var fuse_main := CylinderMesh.new()
	fuse_main.top_radius = 0.32
	fuse_main.bottom_radius = 0.34
	fuse_main.height = 1.4
	fuse_main.radial_segments = 10
	_add_part(root, "Fuselage", fuse_main, mat_body,
		Vector3(0, 0, -0.2), Vector3(90, 0, 0))

	var fuse_rear := CylinderMesh.new()
	fuse_rear.top_radius = 0.34
	fuse_rear.bottom_radius = 0.20
	fuse_rear.height = 1.0
	fuse_rear.radial_segments = 10
	_add_part(root, "FuseRear", fuse_rear, mat_body_dark,
		Vector3(0, 0, 0.7), Vector3(90, 0, 0))

	# Swept wings — 2 parts each
	var wing_inner := BoxMesh.new()
	wing_inner.size = Vector3(1.2, 0.04, 0.75)
	_add_part(root, "LeftWingInner", wing_inner, mat_wing,
		Vector3(-0.9, -0.03, 0.0), Vector3(0, 10, -2))
	_add_part(root, "RightWingInner", wing_inner, mat_wing,
		Vector3(0.9, -0.03, 0.0), Vector3(0, -10, 2))

	var wing_outer := BoxMesh.new()
	wing_outer.size = Vector3(0.7, 0.03, 0.5)
	_add_part(root, "LeftWing", wing_outer, mat_wing,
		Vector3(-1.8, -0.04, 0.15), Vector3(0, 14, -4))
	_add_part(root, "RightWing", wing_outer, mat_wing,
		Vector3(1.8, -0.04, 0.15), Vector3(0, -14, 4))

	# Underwing engine pods — intake + body + nozzle
	# Left engine intake lip
	var eng_lip := CylinderMesh.new()
	eng_lip.top_radius = 0.14
	eng_lip.bottom_radius = 0.13
	eng_lip.height = 0.1
	eng_lip.radial_segments = 8
	_add_part(root, "LeftEngIntake", eng_lip, mat_engine_lip,
		Vector3(-1.1, -0.16, -0.25), Vector3(90, 0, 0))
	_add_part(root, "RightEngIntake", eng_lip, mat_engine_lip,
		Vector3(1.1, -0.16, -0.25), Vector3(90, 0, 0))

	# Engine body
	var eng_body := CylinderMesh.new()
	eng_body.top_radius = 0.13
	eng_body.bottom_radius = 0.12
	eng_body.height = 0.7
	eng_body.radial_segments = 8
	_add_part(root, "LeftEngine", eng_body, mat_engine,
		Vector3(-1.1, -0.16, 0.1), Vector3(90, 0, 0))
	_add_part(root, "RightEngine", eng_body, mat_engine,
		Vector3(1.1, -0.16, 0.1), Vector3(90, 0, 0))

	# Engine nozzles
	var eng_nozzle := CylinderMesh.new()
	eng_nozzle.top_radius = 0.12
	eng_nozzle.bottom_radius = 0.08
	eng_nozzle.height = 0.08
	eng_nozzle.radial_segments = 8
	_add_part(root, "LeftEngNozzle", eng_nozzle, mat_nozzle,
		Vector3(-1.1, -0.16, 0.5), Vector3(90, 0, 0))
	_add_part(root, "RightEngNozzle", eng_nozzle, mat_nozzle,
		Vector3(1.1, -0.16, 0.5), Vector3(90, 0, 0))

	# Twin vertical tail fins
	var fin := BoxMesh.new()
	fin.size = Vector3(0.04, 0.5, 0.4)
	_add_part(root, "TailFin", fin, mat_body,
		Vector3(-0.2, 0.35, 1.0), Vector3(0, 0, -10))
	_add_part(root, "TailFinR", fin, mat_body,
		Vector3(0.2, 0.35, 1.0), Vector3(0, 0, 10))

	# Fin tips
	var fin_tip := BoxMesh.new()
	fin_tip.size = Vector3(0.03, 0.16, 0.25)
	_add_part(root, "TailFinTipL", fin_tip, mat_body,
		Vector3(-0.23, 0.62, 0.95), Vector3(0, 0, -10))
	_add_part(root, "TailFinTipR", fin_tip, mat_body,
		Vector3(0.23, 0.62, 0.95), Vector3(0, 0, 10))

	# Canopy — wider for bomber crew
	var canopy := SphereMesh.new()
	canopy.radius = 0.18
	canopy.height = 0.16
	_add_part(root, "Canopy", canopy, mat_canopy,
		Vector3(0, 0.22, -1.0), Vector3.ZERO)

	# Horizontal stabilizers
	var hstab := BoxMesh.new()
	hstab.size = Vector3(0.55, 0.03, 0.3)
	_add_part(root, "LeftHStab", hstab, mat_wing,
		Vector3(-0.5, 0.0, 1.05), Vector3(0, 8, -3))
	_add_part(root, "RightHStab", hstab, mat_wing,
		Vector3(0.5, 0.0, 1.05), Vector3(0, -8, 3))

	# Dorsal spine
	var spine := BoxMesh.new()
	spine.size = Vector3(0.06, 0.05, 1.5)
	_add_part(root, "Spine", spine, mat_body_dark,
		Vector3(0, 0.28, -0.2), Vector3.ZERO)

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
