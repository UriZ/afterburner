extends RefCounted

## Builds a detailed 3D mesh hierarchy for the player F-14 Tomcat from Godot primitives.
## The jet points in -Z (nose forward). Camera behind at +Z sees the rear:
## twin engine nozzles, afterburner flames, swept wings, vertical tail fins.
## Uses 35+ primitives to create a convincing aircraft silhouette.


static func build_player_jet() -> Node3D:
	var root := Node3D.new()
	root.name = "JetMesh"
	root.scale = Vector3(2.0, 2.0, 2.0)

	# -- Materials --
	var mat_fuse := _make_mat(Color(0.88, 0.90, 0.96), 0.2, 0.6)
	var mat_fuse_dark := _make_mat(Color(0.76, 0.79, 0.87), 0.2, 0.65)
	var mat_wing := _make_mat(Color(0.82, 0.85, 0.93), 0.15, 0.75)
	var mat_wing_edge := _make_mat(Color(0.72, 0.76, 0.86), 0.15, 0.8)
	var mat_tail := _make_mat(Color(0.84, 0.87, 0.94), 0.18, 0.6)
	var mat_nacelle := _make_mat(Color(0.52, 0.51, 0.50), 0.2, 0.5)
	var mat_nacelle_lip := _make_mat(Color(0.60, 0.59, 0.57), 0.25, 0.45)
	var mat_nozzle := _make_mat(Color(0.10, 0.10, 0.10), 0.3, 0.3)
	var mat_nozzle_ring := _make_mat(Color(0.18, 0.16, 0.14), 0.35, 0.25)
	var mat_spine := _make_mat(Color(0.80, 0.79, 0.76), 0.12, 0.7)
	var mat_canopy := _make_mat(Color(0.08, 0.35, 0.85, 0.75), 0.05, 0.15)
	mat_canopy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_canopy.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_hstab := _make_mat(Color(0.83, 0.82, 0.79), 0.1, 0.8)

	# Hot white/yellow core flame
	var mat_flame := StandardMaterial3D.new()
	mat_flame.albedo_color = Color(1.0, 0.95, 0.6, 0.95)
	mat_flame.emission_enabled = true
	mat_flame.emission = Color(1.0, 0.9, 0.4)
	mat_flame.emission_energy_multiplier = 4.0
	mat_flame.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Outer orange/red glow layer — larger, translucent
	var mat_flame_glow := StandardMaterial3D.new()
	mat_flame_glow.albedo_color = Color(1.0, 0.35, 0.05, 0.45)
	mat_flame_glow.emission_enabled = true
	mat_flame_glow.emission = Color(1.0, 0.25, 0.0)
	mat_flame_glow.emission_energy_multiplier = 2.5
	mat_flame_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_flame_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_flame_glow.cull_mode = BaseMaterial3D.CULL_DISABLED

	# ============================================================
	# FUSELAGE — 6 cylinder sections tapering nose to tail
	# ============================================================

	# Section 1: Nose tip — sharp cone
	var nose_tip := CylinderMesh.new()
	nose_tip.top_radius = 0.0
	nose_tip.bottom_radius = 0.12
	nose_tip.height = 0.5
	nose_tip.radial_segments = 12
	_add_part(root, "NoseCone", nose_tip, mat_fuse,
		Vector3(0, 0, -2.35), Vector3(90, 0, 0))

	# Section 2: Forward fuselage — slim taper
	var fuse_fwd := CylinderMesh.new()
	fuse_fwd.top_radius = 0.12
	fuse_fwd.bottom_radius = 0.24
	fuse_fwd.height = 0.8
	fuse_fwd.radial_segments = 12
	_add_part(root, "FuseForward", fuse_fwd, mat_fuse,
		Vector3(0, 0, -1.7), Vector3(90, 0, 0))

	# Section 3: Mid fuselage — canopy area, widest
	var fuse_mid := CylinderMesh.new()
	fuse_mid.top_radius = 0.24
	fuse_mid.bottom_radius = 0.34
	fuse_mid.height = 1.0
	fuse_mid.radial_segments = 12
	_add_part(root, "Fuselage", fuse_mid, mat_fuse,
		Vector3(0, 0, -0.8), Vector3(90, 0, 0))

	# Section 4: Center fuselage — wing root area
	var fuse_center := CylinderMesh.new()
	fuse_center.top_radius = 0.34
	fuse_center.bottom_radius = 0.32
	fuse_center.height = 0.8
	fuse_center.radial_segments = 12
	_add_part(root, "FuseCenter", fuse_center, mat_fuse,
		Vector3(0, -0.02, -0.0), Vector3(90, 0, 0))

	# Section 5: Rear fuselage — narrows between engines
	var fuse_rear := CylinderMesh.new()
	fuse_rear.top_radius = 0.32
	fuse_rear.bottom_radius = 0.22
	fuse_rear.height = 0.9
	fuse_rear.radial_segments = 12
	_add_part(root, "FuseRear", fuse_rear, mat_fuse_dark,
		Vector3(0, -0.04, 0.65), Vector3(90, 0, 0))

	# Section 6: Tail boom — thin connection to tail
	var fuse_tail := CylinderMesh.new()
	fuse_tail.top_radius = 0.22
	fuse_tail.bottom_radius = 0.16
	fuse_tail.height = 0.5
	fuse_tail.radial_segments = 12
	_add_part(root, "FuseTail", fuse_tail, mat_fuse_dark,
		Vector3(0, -0.04, 1.2), Vector3(90, 0, 0))

	# Dorsal spine ridge — raised strip along fuselage top
	var spine := BoxMesh.new()
	spine.size = Vector3(0.08, 0.06, 2.0)
	_add_part(root, "Spine", spine, mat_spine,
		Vector3(0, 0.28, -0.3), Vector3.ZERO)

	# ============================================================
	# CANOPY — elongated bubble flush with fuselage
	# ============================================================

	# Main canopy bubble
	var canopy_main := SphereMesh.new()
	canopy_main.radius = 0.15
	canopy_main.height = 0.16
	_add_part(root, "Canopy", canopy_main, mat_canopy,
		Vector3(0, 0.26, -1.0), Vector3.ZERO)

	# Canopy rear extension
	var canopy_rear := SphereMesh.new()
	canopy_rear.radius = 0.13
	canopy_rear.height = 0.12
	_add_part(root, "CanopyRear", canopy_rear, mat_canopy,
		Vector3(0, 0.25, -0.7), Vector3.ZERO)

	# Canopy frame — thin ridge
	var canopy_frame := BoxMesh.new()
	canopy_frame.size = Vector3(0.02, 0.04, 0.5)
	_add_part(root, "CanopyFrame", canopy_frame, mat_fuse,
		Vector3(0, 0.29, -0.85), Vector3.ZERO)

	# ============================================================
	# WINGS — swept back at ~55 degrees (variable sweep, combat position)
	# Each wing: 3 overlapping parts for planform shape
	# ============================================================

	# Wing root — thick section joining fuselage
	var wing_root := BoxMesh.new()
	wing_root.size = Vector3(0.9, 0.06, 0.7)
	_add_part(root, "LeftWingRoot", wing_root, mat_wing,
		Vector3(-0.7, -0.06, 0.0), Vector3(0, 20, -3))
	_add_part(root, "RightWingRoot", wing_root, mat_wing,
		Vector3(0.7, -0.06, 0.0), Vector3(0, -20, 3))

	# Wing mid — main visible surface
	var wing_mid := BoxMesh.new()
	wing_mid.size = Vector3(1.2, 0.04, 0.55)
	_add_part(root, "LeftWing", wing_mid, mat_wing,
		Vector3(-1.4, -0.07, 0.2), Vector3(0, 18, -5))
	_add_part(root, "RightWing", wing_mid, mat_wing,
		Vector3(1.4, -0.07, 0.2), Vector3(0, -18, 5))

	# Wing tip — tapered thin section
	var wing_tip := BoxMesh.new()
	wing_tip.size = Vector3(0.5, 0.03, 0.35)
	_add_part(root, "LeftWingTip", wing_tip, mat_wing_edge,
		Vector3(-2.1, -0.08, 0.4), Vector3(0, 22, -6))
	_add_part(root, "RightWingTip", wing_tip, mat_wing_edge,
		Vector3(2.1, -0.08, 0.4), Vector3(0, -22, 6))

	# Wing leading edge strips — thin swept lines
	var wing_edge := BoxMesh.new()
	wing_edge.size = Vector3(1.8, 0.02, 0.06)
	_add_part(root, "LeftWingEdge", wing_edge, mat_wing_edge,
		Vector3(-1.3, -0.05, -0.15), Vector3(0, 25, -4))
	_add_part(root, "RightWingEdge", wing_edge, mat_wing_edge,
		Vector3(1.3, -0.05, -0.15), Vector3(0, -25, 4))

	# ============================================================
	# VERTICAL STABILIZERS — twin, canted outward ~15 degrees
	# Each: 2 parts for tapered shape
	# ============================================================

	# Main fin body
	var fin_main := BoxMesh.new()
	fin_main.size = Vector3(0.04, 0.55, 0.45)
	_add_part(root, "LeftTailFin", fin_main, mat_tail,
		Vector3(-0.42, 0.38, 1.15), Vector3(0, 5, -15))
	_add_part(root, "RightTailFin", fin_main, mat_tail,
		Vector3(0.42, 0.38, 1.15), Vector3(0, -5, 15))

	# Fin tip — tapered top
	var fin_tip := BoxMesh.new()
	fin_tip.size = Vector3(0.03, 0.2, 0.3)
	_add_part(root, "LeftFinTip", fin_tip, mat_tail,
		Vector3(-0.48, 0.7, 1.1), Vector3(0, 8, -15))
	_add_part(root, "RightFinTip", fin_tip, mat_tail,
		Vector3(0.48, 0.7, 1.1), Vector3(0, -8, 15))

	# Fin root fairing — blended base
	var fin_root := BoxMesh.new()
	fin_root.size = Vector3(0.06, 0.15, 0.5)
	_add_part(root, "LeftFinRoot", fin_root, mat_fuse_dark,
		Vector3(-0.38, 0.12, 1.15), Vector3(0, 3, -10))
	_add_part(root, "RightFinRoot", fin_root, mat_fuse_dark,
		Vector3(0.38, 0.12, 1.15), Vector3(0, -3, 10))

	# ============================================================
	# ENGINE NACELLES — twin pods flanking rear fuselage
	# Each: intake lip + main body + narrowing nozzle section
	# ============================================================

	# Intake lip — wider front ring
	var intake_lip := CylinderMesh.new()
	intake_lip.top_radius = 0.22
	intake_lip.bottom_radius = 0.20
	intake_lip.height = 0.15
	intake_lip.radial_segments = 10
	_add_part(root, "LeftIntakeLip", intake_lip, mat_nacelle_lip,
		Vector3(-0.48, -0.10, 0.25), Vector3(90, 0, 0))
	_add_part(root, "RightIntakeLip", intake_lip, mat_nacelle_lip,
		Vector3(0.48, -0.10, 0.25), Vector3(90, 0, 0))

	# Main nacelle body
	var nacelle_body := CylinderMesh.new()
	nacelle_body.top_radius = 0.20
	nacelle_body.bottom_radius = 0.18
	nacelle_body.height = 1.0
	nacelle_body.radial_segments = 10
	_add_part(root, "LeftNacelle", nacelle_body, mat_nacelle,
		Vector3(-0.48, -0.10, 0.8), Vector3(90, 0, 0))
	_add_part(root, "RightNacelle", nacelle_body, mat_nacelle,
		Vector3(0.48, -0.10, 0.8), Vector3(90, 0, 0))

	# Nacelle rear taper
	var nacelle_rear := CylinderMesh.new()
	nacelle_rear.top_radius = 0.18
	nacelle_rear.bottom_radius = 0.16
	nacelle_rear.height = 0.3
	nacelle_rear.radial_segments = 10
	_add_part(root, "LeftNacelleRear", nacelle_rear, mat_nacelle,
		Vector3(-0.48, -0.10, 1.35), Vector3(90, 0, 0))
	_add_part(root, "RightNacelleRear", nacelle_rear, mat_nacelle,
		Vector3(0.48, -0.10, 1.35), Vector3(90, 0, 0))

	# ============================================================
	# ENGINE NOZZLES — dark circular openings at rear
	# Each: outer ring + inner dark circle
	# ============================================================

	# Nozzle outer ring
	var nozzle_outer := CylinderMesh.new()
	nozzle_outer.top_radius = 0.17
	nozzle_outer.bottom_radius = 0.15
	nozzle_outer.height = 0.1
	nozzle_outer.radial_segments = 10
	_add_part(root, "LeftNozzle", nozzle_outer, mat_nozzle_ring,
		Vector3(-0.48, -0.10, 1.53), Vector3(90, 0, 0))
	_add_part(root, "RightNozzle", nozzle_outer, mat_nozzle_ring,
		Vector3(0.48, -0.10, 1.53), Vector3(90, 0, 0))

	# Nozzle inner dark
	var nozzle_inner := CylinderMesh.new()
	nozzle_inner.top_radius = 0.13
	nozzle_inner.bottom_radius = 0.10
	nozzle_inner.height = 0.08
	nozzle_inner.radial_segments = 10
	_add_part(root, "LeftNozzleInner", nozzle_inner, mat_nozzle,
		Vector3(-0.48, -0.10, 1.57), Vector3(90, 0, 0))
	_add_part(root, "RightNozzleInner", nozzle_inner, mat_nozzle,
		Vector3(0.48, -0.10, 1.57), Vector3(90, 0, 0))

	# ============================================================
	# HORIZONTAL STABILIZERS — small swept surfaces near tail
	# ============================================================

	var hstab := BoxMesh.new()
	hstab.size = Vector3(0.65, 0.03, 0.3)
	_add_part(root, "LeftHStab", hstab, mat_hstab,
		Vector3(-0.65, -0.02, 1.1), Vector3(0, 10, -4))
	_add_part(root, "RightHStab", hstab, mat_hstab,
		Vector3(0.65, -0.02, 1.1), Vector3(0, -10, 4))

	# HStab tips
	var hstab_tip := BoxMesh.new()
	hstab_tip.size = Vector3(0.25, 0.02, 0.2)
	_add_part(root, "LeftHStabTip", hstab_tip, mat_hstab,
		Vector3(-1.05, -0.03, 1.15), Vector3(0, 15, -5))
	_add_part(root, "RightHStabTip", hstab_tip, mat_hstab,
		Vector3(1.05, -0.03, 1.15), Vector3(0, -15, 5))

	# ============================================================
	# AFTERBURNER FLAMES — kept at same position convention
	# ============================================================

	# Core flame — bright white/yellow, 2.5x original size
	var flame_mesh := CylinderMesh.new()
	flame_mesh.top_radius = 0.14
	flame_mesh.bottom_radius = 0.02
	flame_mesh.height = 1.25
	flame_mesh.radial_segments = 8
	_add_part(root, "LeftFlame", flame_mesh, mat_flame,
		Vector3(-0.48, -0.10, 2.2), Vector3(90, 0, 0))
	_add_part(root, "RightFlame", flame_mesh, mat_flame,
		Vector3(0.48, -0.10, 2.2), Vector3(90, 0, 0))

	# Glow layer — wider, longer, orange/red, translucent
	var flame_glow_mesh := CylinderMesh.new()
	flame_glow_mesh.top_radius = 0.24
	flame_glow_mesh.bottom_radius = 0.03
	flame_glow_mesh.height = 1.7
	flame_glow_mesh.radial_segments = 8
	_add_part(root, "LeftFlameGlow", flame_glow_mesh, mat_flame_glow,
		Vector3(-0.48, -0.10, 2.35), Vector3(90, 0, 0))
	_add_part(root, "RightFlameGlow", flame_glow_mesh, mat_flame_glow,
		Vector3(0.48, -0.10, 2.35), Vector3(90, 0, 0))

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
