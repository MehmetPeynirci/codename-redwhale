extends Node

@export var canvas_layer: int = 80
@export var grain_strength: float = 0.028
@export var vignette_strength: float = 0.32
@export var chromatic_aberration: float = 0.0011
@export var contrast: float = 1.06
@export var saturation: float = 1.03
@export var blue_tint_strength: float = 0.08
@export var shadow_crush: float = 0.06

var _overlay_material: ShaderMaterial

func _ready() -> void:
	var shader: Shader = load("res://shaders/cinematic_overlay.gdshader") as Shader
	if shader == null:
		return

	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = canvas_layer
	add_child(layer)

	var rect: ColorRect = ColorRect.new()
	rect.anchor_left = 0.0
	rect.anchor_top = 0.0
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.offset_left = 0.0
	rect.offset_top = 0.0
	rect.offset_right = 0.0
	rect.offset_bottom = 0.0
	rect.color = Color(1.0, 1.0, 1.0, 1.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)

	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = shader
	_overlay_material.set_shader_parameter("grain_strength", grain_strength)
	_overlay_material.set_shader_parameter("vignette_strength", vignette_strength)
	_overlay_material.set_shader_parameter("chromatic_aberration", chromatic_aberration)
	_overlay_material.set_shader_parameter("contrast", contrast)
	_overlay_material.set_shader_parameter("saturation", saturation)
	_overlay_material.set_shader_parameter("blue_tint_strength", blue_tint_strength)
	_overlay_material.set_shader_parameter("shadow_crush", shadow_crush)
	rect.material = _overlay_material
