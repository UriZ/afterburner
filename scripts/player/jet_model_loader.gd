extends RefCounted

## Loads the real F-14 GLB model and returns it as a Node3D ready to attach.
## The model was generated procedurally from F-14 Tomcat geometry data.
## It shares the same coordinate convention as jet_mesh_builder.gd:
##   nose at -Z, camera behind at +Z, wings along X.
##
## Usage (in player_jet.gd or any Node3D):
##   var loader := preload("res://scripts/player/jet_model_loader.gd")
##   var model := loader.load_model()
##   add_child(model)

const MODEL_PATH := "res://assets/models/f14_player.glb"

## Scale that matches the primitive jet's apparent size at position (0,2.5,-8)
## with camera at (0,5,0). The GLB is in meter-scale so we scale to match.
const MODEL_SCALE := Vector3(1.0, 1.0, 1.0)

## Y rotation: GLB nose is at -Z (correct), no rotation needed.
## If the model appears backwards, set this to 180.
const MODEL_ROT_Y := 0.0


static func load_model() -> Node3D:
	var packed: PackedScene = load(MODEL_PATH)
	if packed == null:
		push_error("jet_model_loader: could not load " + MODEL_PATH)
		return Node3D.new()

	var root: Node3D = packed.instantiate()
	root.name = "JetMeshGLB"
	root.scale = MODEL_SCALE
	root.rotation_degrees.y = MODEL_ROT_Y

	# Apply unshaded emission to flame meshes so they glow regardless of lighting
	_apply_flame_materials(root)

	return root


static func _apply_flame_materials(root: Node3D) -> void:
	for child in root.get_children():
		var name_lower := child.name.to_lower()
		if "flame" in name_lower and child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.emission_enabled = true
			if "central" in name_lower:
				mat.albedo_color = Color(1.0, 0.9, 0.15, 1.0)
				mat.emission = Color(1.0, 0.85, 0.1)
				mat.emission_energy_multiplier = 6.0
			else:
				mat.albedo_color = Color(1.0, 0.55, 0.05, 1.0)
				mat.emission = Color(1.0, 0.45, 0.0)
				mat.emission_energy_multiplier = 4.0
			child.material_override = mat
