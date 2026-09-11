extends RefCounted

## Builds a detailed 3D mesh hierarchy for the player F-14 Tomcat from Godot primitives.
## The jet points in -Z (nose forward). Camera is at +Z (behind) looking at the rear:
## twin engine nozzles, afterburner flames, swept wings, vertical tail fins.
## Spec: UI Designer mesh spec — issue #59. 45 primitives total.


static func build_player_jet() -> Node3D:
	var root := Node3D.new()
	root.name = "JetMesh"
	root.scale = Vector3(3.0, 3.0, 3.0)

	# ============================================================
	# MATERIALS
	# ============================================================

	var mat_fuse_top  := _make_mat(Color(0.96, 0.97, 1.00), 0.15, 0.50)
	var mat_fuse_side := _make_mat(Color(0.82, 0.83, 0.90), 0.18, 0.55)
	var mat_fuse_belly := _make_mat(Color(0.70, 0.72, 0.80), 0.20, 0.60)
	var mat_wing_top  := _make_mat(Color(0.93, 0.94, 0.98), 0.12, 0.65)
	var mat_tail      := _make_mat(Color(0.90, 0.92, 0.97), 0.15, 0.55)
	var mat_intake_ramp := _make_mat(Color(0.85, 0.35, 0.10), 0.10, 0.70)
	var mat_nacelle   := _make_mat(Color(0.55, 0.54, 0.52), 0.25, 0.50)
	var mat_nozzle    := _make_mat(Color(0.12, 0.11, 0.10), 0.40, 0.25)
	var mat_nozzle_ring := _make_mat(Color(0.22, 0.20, 0.18), 0.45, 0.20)
	var mat_spine     := _make_mat(Color(0.88, 0.89, 0.94), 0.10, 0.60)
	var mat_hstab     := _make_mat(Color(0.89, 0.90, 0.95), 0.12, 0.60)

	var mat_canopy := StandardMaterial3D.new()
	mat_canopy.albedo_color = Color(0.25, 0.30, 0.75, 0.72)
	mat_canopy.metallic = 0.05
	mat_canopy.roughness = 0.05
	mat_canopy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_canopy.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Hot white/yellow core flame
	var mat_flame := StandardMaterial3D.new()
	mat_flame.albedo_color = Color(1.0, 1.0, 0.85, 1.0)
	mat_flame.emission_enabled = true
	mat_flame.emission = Color(1.0, 0.95, 0.6)
	mat_flame.emission_energy_multiplier = 8.0
	mat_flame.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_flame.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Middle orange glow layer
	var mat_flame_mid := StandardMaterial3D.new()
	mat_flame_mid.albedo_color = Color(1.0, 0.55, 0.05, 0.75)
	mat_flame_mid.emission_enabled = true
	mat_flame_mid.emission = Color(1.0, 0.45, 0.0)
	mat_flame_mid.emission_energy_multiplier = 5.0
	mat_flame_mid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_flame_mid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_flame_mid.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Outer red-orange heat shimmer layer
	var mat_flame_glow := StandardMaterial3D.new()
	mat_flame_glow.albedo_color = Color(1.0, 0.25, 0.03, 0.40)
	mat_flame_glow.emission_enabled = true
	mat_flame_glow.emission = Color(0.9, 0.15, 0.0)
	mat_flame_glow.emission_energy_multiplier = 3.0
	mat_flame_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_flame_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_flame_glow.cull_mode = BaseMaterial3D.CULL_DISABLED

	# ============================================================
	# FUSELAGE — 5 cylinder sections + 1 chine box + dorsal spine
	# ============================================================

	# Radome section 3 — rounded tip: wide bullet tip, NOT a needle
	var nose_tip := CylinderMesh.new()
	nose_tip.top_radius = 0.025
	nose_tip.bottom_radius = 0.05
	nose_tip.height = 0.70
	nose_tip.radial_segments = 12
	_add_part(root, "NoseTip", nose_tip, mat_fuse_top,
		Vector3(0, 0.02, -3.98), Vector3(90, 0, 0))

	# Radome section 2 — mid taper: gradual taper across radar housing
	var nose_mid := CylinderMesh.new()
	nose_mid.top_radius = 0.05
	nose_mid.bottom_radius = 0.08
	nose_mid.height = 0.80
	nose_mid.radial_segments = 12
	_add_part(root, "NoseMid", nose_mid, mat_fuse_top,
		Vector3(0, 0.02, -3.23), Vector3(90, 0, 0))

	# Radome section 1 — base cone: wide base connecting to fuselage
	var nose_cone := CylinderMesh.new()
	nose_cone.top_radius = 0.08
	nose_cone.bottom_radius = 0.10
	nose_cone.height = 0.75
	nose_cone.radial_segments = 12
	_add_part(root, "NoseCone", nose_cone, mat_fuse_top,
		Vector3(0, 0.02, -2.455), Vector3(90, 0, 0))

	var fuse_fwd := CylinderMesh.new()
	fuse_fwd.top_radius = 0.10
	fuse_fwd.bottom_radius = 0.22
	fuse_fwd.height = 0.90
	fuse_fwd.radial_segments = 12
	_add_part(root, "FuseForward", fuse_fwd, mat_fuse_top,
		Vector3(0, 0.02, -1.63), Vector3(90, 0, 0))

	var fuse_mid := CylinderMesh.new()
	fuse_mid.top_radius = 0.22
	fuse_mid.bottom_radius = 0.30
	fuse_mid.height = 0.85
	fuse_mid.radial_segments = 12
	_add_part(root, "FuseMid", fuse_mid, mat_fuse_top,
		Vector3(0, 0.0, -0.95), Vector3(90, 0, 0))

	var fuse_center := CylinderMesh.new()
	fuse_center.top_radius = 0.30
	fuse_center.bottom_radius = 0.28
	fuse_center.height = 0.75
	fuse_center.radial_segments = 12
	_add_part(root, "FuseCenter", fuse_center, mat_fuse_side,
		Vector3(0, -0.02, -0.18), Vector3(90, 0, 0))

	var fuse_chine := BoxMesh.new()
	fuse_chine.size = Vector3(0.52, 0.10, 0.75)
	_add_part(root, "FuseCenterChine", fuse_chine, mat_fuse_belly,
		Vector3(0, -0.12, -0.18), Vector3.ZERO)

	var fuse_rear := CylinderMesh.new()
	fuse_rear.top_radius = 0.20
	fuse_rear.bottom_radius = 0.14
	fuse_rear.height = 0.85
	fuse_rear.radial_segments = 12
	_add_part(root, "FuseRear", fuse_rear, mat_fuse_side,
		Vector3(0, -0.04, 0.68), Vector3(90, 0, 0))

	var spine := BoxMesh.new()
	spine.size = Vector3(0.07, 0.07, 2.20)
	_add_part(root, "Spine", spine, mat_spine,
		Vector3(0, 0.28, -0.40), Vector3.ZERO)

	# ============================================================
	# INTAKE RAMPS — orange-red F-14 identity markers
	# ============================================================

	var intake_ramp := BoxMesh.new()
	intake_ramp.size = Vector3(0.06, 0.22, 0.50)
	_add_part(root, "LeftIntakeRamp", intake_ramp, mat_intake_ramp,
		Vector3(-0.24, -0.04, -1.20), Vector3.ZERO)
	_add_part(root, "RightIntakeRamp", intake_ramp, mat_intake_ramp,
		Vector3(0.24, -0.04, -1.20), Vector3.ZERO)

	# ============================================================
	# CANOPY — 3-sphere elongated teardrop bubble
	# ============================================================

	var canopy_front := SphereMesh.new()
	canopy_front.radius = 0.13
	canopy_front.height = 0.22
	_add_part(root, "CanopyFront", canopy_front, mat_canopy,
		Vector3(0, 0.32, -1.25), Vector3.ZERO)

	var canopy_main := SphereMesh.new()
	canopy_main.radius = 0.16
	canopy_main.height = 0.28
	_add_part(root, "CanopyMain", canopy_main, mat_canopy,
		Vector3(0, 0.33, -0.90), Vector3.ZERO)

	var canopy_rear := SphereMesh.new()
	canopy_rear.radius = 0.12
	canopy_rear.height = 0.16
	_add_part(root, "CanopyRear", canopy_rear, mat_canopy,
		Vector3(0, 0.28, -0.60), Vector3.ZERO)

	var canopy_frame := BoxMesh.new()
	canopy_frame.size = Vector3(0.025, 0.035, 0.70)
	_add_part(root, "CanopyFrame", canopy_frame, mat_spine,
		Vector3(0, 0.40, -0.90), Vector3.ZERO)

	# ============================================================
	# WINGS — combat sweep ~38 degrees, glove + outer panel + tip
	# ============================================================

	var wing_glove := BoxMesh.new()
	wing_glove.size = Vector3(0.70, 0.07, 0.55)
	_add_part(root, "LeftWingGlove", wing_glove, mat_wing_top,
		Vector3(-0.55, -0.04, 0.05), Vector3(0, 15, -2))
	_add_part(root, "RightWingGlove", wing_glove, mat_wing_top,
		Vector3(0.55, -0.04, 0.05), Vector3(0, -15, 2))

	var wing_outer := BoxMesh.new()
	wing_outer.size = Vector3(1.10, 0.045, 0.45)
	_add_part(root, "LeftWingOuter", wing_outer, mat_wing_top,
		Vector3(-1.25, -0.06, 0.45), Vector3(0, 38, -4))
	_add_part(root, "RightWingOuter", wing_outer, mat_wing_top,
		Vector3(1.25, -0.06, 0.45), Vector3(0, -38, 4))

	var wing_tip := BoxMesh.new()
	wing_tip.size = Vector3(0.40, 0.030, 0.25)
	_add_part(root, "LeftWingTip", wing_tip, mat_wing_top,
		Vector3(-1.88, -0.07, 0.75), Vector3(0, 42, -5))
	_add_part(root, "RightWingTip", wing_tip, mat_wing_top,
		Vector3(1.88, -0.07, 0.75), Vector3(0, -42, 5))

	var wing_le := BoxMesh.new()
	wing_le.size = Vector3(1.30, 0.020, 0.055)
	_add_part(root, "LeftLeadingEdge", wing_le, mat_fuse_side,
		Vector3(-1.10, -0.04, 0.05), Vector3(0, 38, -3))
	_add_part(root, "RightLeadingEdge", wing_le, mat_fuse_side,
		Vector3(1.10, -0.04, 0.05), Vector3(0, -38, 3))

	# ============================================================
	# VERTICAL TAIL FINS — thin, canted outward, low aspect ratio
	# ============================================================

	var fin_main := BoxMesh.new()
	fin_main.size = Vector3(0.030, 0.28, 0.32)
	_add_part(root, "LeftTailFin", fin_main, mat_tail,
		Vector3(-0.28, 0.20, 1.05), Vector3(0, 8, -14))
	_add_part(root, "RightTailFin", fin_main, mat_tail,
		Vector3(0.28, 0.20, 1.05), Vector3(0, -8, 14))

	var fin_tip := BoxMesh.new()
	fin_tip.size = Vector3(0.025, 0.09, 0.20)
	_add_part(root, "LeftFinTip", fin_tip, mat_tail,
		Vector3(-0.31, 0.35, 1.02), Vector3(0, 10, -14))
	_add_part(root, "RightFinTip", fin_tip, mat_tail,
		Vector3(0.31, 0.35, 1.02), Vector3(0, -10, 14))

	var fin_root := BoxMesh.new()
	fin_root.size = Vector3(0.055, 0.09, 0.34)
	_add_part(root, "LeftFinRoot", fin_root, mat_fuse_side,
		Vector3(-0.26, 0.09, 1.05), Vector3(0, 5, -8))
	_add_part(root, "RightFinRoot", fin_root, mat_fuse_side,
		Vector3(0.26, 0.09, 1.05), Vector3(0, -5, 8))

	# ============================================================
	# ENGINE NACELLES — twin pods, tighter to centerline (±0.42)
	# ============================================================

	var intake_lip := CylinderMesh.new()
	intake_lip.top_radius = 0.195
	intake_lip.bottom_radius = 0.175
	intake_lip.height = 0.14
	intake_lip.radial_segments = 10
	_add_part(root, "LeftIntakeLip", intake_lip, mat_nacelle,
		Vector3(-0.42, -0.08, 0.22), Vector3(90, 0, 0))
	_add_part(root, "RightIntakeLip", intake_lip, mat_nacelle,
		Vector3(0.42, -0.08, 0.22), Vector3(90, 0, 0))

	var nacelle_body := CylinderMesh.new()
	nacelle_body.top_radius = 0.175
	nacelle_body.bottom_radius = 0.16
	nacelle_body.height = 0.95
	nacelle_body.radial_segments = 10
	_add_part(root, "LeftNacelle", nacelle_body, mat_nacelle,
		Vector3(-0.42, -0.08, 0.77), Vector3(90, 0, 0))
	_add_part(root, "RightNacelle", nacelle_body, mat_nacelle,
		Vector3(0.42, -0.08, 0.77), Vector3(90, 0, 0))

	var nacelle_rear := CylinderMesh.new()
	nacelle_rear.top_radius = 0.16
	nacelle_rear.bottom_radius = 0.145
	nacelle_rear.height = 0.28
	nacelle_rear.radial_segments = 10
	_add_part(root, "LeftNacelleRear", nacelle_rear, mat_nacelle,
		Vector3(-0.42, -0.08, 1.32), Vector3(90, 0, 0))
	_add_part(root, "RightNacelleRear", nacelle_rear, mat_nacelle,
		Vector3(0.42, -0.08, 1.32), Vector3(90, 0, 0))

	# ============================================================
	# ENGINE NOZZLES — dark heat-soaked metal
	# ============================================================

	var nozzle_outer := CylinderMesh.new()
	nozzle_outer.top_radius = 0.155
	nozzle_outer.bottom_radius = 0.135
	nozzle_outer.height = 0.10
	nozzle_outer.radial_segments = 10
	_add_part(root, "LeftNozzle", nozzle_outer, mat_nozzle_ring,
		Vector3(-0.42, -0.08, 1.50), Vector3(90, 0, 0))
	_add_part(root, "RightNozzle", nozzle_outer, mat_nozzle_ring,
		Vector3(0.42, -0.08, 1.50), Vector3(90, 0, 0))

	var nozzle_inner := CylinderMesh.new()
	nozzle_inner.top_radius = 0.115
	nozzle_inner.bottom_radius = 0.085
	nozzle_inner.height = 0.08
	nozzle_inner.radial_segments = 10
	_add_part(root, "LeftNozzleInner", nozzle_inner, mat_nozzle,
		Vector3(-0.42, -0.08, 1.54), Vector3(90, 0, 0))
	_add_part(root, "RightNozzleInner", nozzle_inner, mat_nozzle,
		Vector3(0.42, -0.08, 1.54), Vector3(90, 0, 0))

	# ============================================================
	# HORIZONTAL STABILIZERS — all-moving slab surfaces
	# ============================================================

	var hstab := BoxMesh.new()
	hstab.size = Vector3(0.60, 0.025, 0.28)
	_add_part(root, "LeftHStab", hstab, mat_hstab,
		Vector3(-0.58, -0.04, 1.08), Vector3(0, 12, -3))
	_add_part(root, "RightHStab", hstab, mat_hstab,
		Vector3(0.58, -0.04, 1.08), Vector3(0, -12, 3))

	var hstab_tip := BoxMesh.new()
	hstab_tip.size = Vector3(0.22, 0.018, 0.18)
	_add_part(root, "LeftHStabTip", hstab_tip, mat_hstab,
		Vector3(-0.96, -0.05, 1.12), Vector3(0, 18, -4))
	_add_part(root, "RightHStabTip", hstab_tip, mat_hstab,
		Vector3(0.96, -0.05, 1.12), Vector3(0, -18, 4))

	# ============================================================
	# AFTERBURNER FLAMES — twin nozzle plumes visible from camera
	# Camera is at world (0,5,0) looking down ~20deg at the jet.
	# Flames must extend in +Z (toward camera) but stay below
	# jet body so they're visible. X rotation of ~25deg tilts
	# the cone's axis: large base at nozzle, tip trails behind+down.
	# CylinderMesh Y-axis = cone axis. 25deg X rot: cone tilts
	# so its axis goes mostly +Z with slight downward component.
	# ============================================================

	# Individual nozzle cores — bright white hot inner jets
	var flame_core := CylinderMesh.new()
	flame_core.top_radius = 0.01
	flame_core.bottom_radius = 0.20
	flame_core.height = 1.40
	flame_core.radial_segments = 10
	_add_part(root, "LeftFlameCore", flame_core, mat_flame,
		Vector3(-0.42, -0.08, 1.90), Vector3(-25, 0, 0))
	_add_part(root, "RightFlameCore", flame_core, mat_flame,
		Vector3(0.42, -0.08, 1.90), Vector3(-25, 0, 0))

	# Central merged white/yellow inner plume — the BIG flame
	var central_core := CylinderMesh.new()
	central_core.top_radius = 0.01
	central_core.bottom_radius = 0.50
	central_core.height = 2.00
	central_core.radial_segments = 12
	_add_part(root, "CentralFlameCore", central_core, mat_flame,
		Vector3(0, -0.15, 2.00), Vector3(-25, 0, 0))

	# Central orange middle plume
	var central_mid := CylinderMesh.new()
	central_mid.top_radius = 0.01
	central_mid.bottom_radius = 0.70
	central_mid.height = 2.60
	central_mid.radial_segments = 12
	_add_part(root, "CentralFlameMid", central_mid, mat_flame_mid,
		Vector3(0, -0.20, 2.10), Vector3(-25, 0, 0))

	# Central outer heat shimmer — widest, most transparent
	var central_glow := CylinderMesh.new()
	central_glow.top_radius = 0.01
	central_glow.bottom_radius = 0.95
	central_glow.height = 3.00
	central_glow.radial_segments = 12
	_add_part(root, "CentralFlameGlow", central_glow, mat_flame_glow,
		Vector3(0, -0.28, 2.20), Vector3(-25, 0, 0))

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
