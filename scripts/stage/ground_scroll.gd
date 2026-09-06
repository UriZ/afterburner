extends MeshInstance3D

@export var scroll_speed: float = 18.0

var _offset: float = 0.0


func _process(delta: float) -> void:
	_offset += scroll_speed * delta
	if _offset > 1000.0:
		_offset -= 1000.0
	(material_override as ShaderMaterial).set_shader_parameter("scroll_offset", _offset)
