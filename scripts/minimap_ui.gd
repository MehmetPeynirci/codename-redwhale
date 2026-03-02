extends Node

@export var player_path: NodePath = NodePath("../Player")
@export var village_path: NodePath = NodePath("../Village")
@export var map_size_px: int = 214
@export var map_margin_px: int = 18
@export var map_height: float = 132.0
@export var map_world_size: float = 180.0
@export var map_center: Vector3 = Vector3.ZERO
@export var follow_player: bool = false
@export var marker_color: Color = Color(0.9, 0.16, 0.18, 1.0)
@export var frame_color: Color = Color(0.05, 0.06, 0.08, 0.92)
@export var frame_border_color: Color = Color(0.38, 0.11, 0.13, 0.95)
@export var map_texture_tint: Color = Color(0.6, 0.72, 0.66, 1.0)

var _player: CharacterBody3D
var _village: Node3D

var _ui_layer: CanvasLayer
var _panel: Panel
var _map_texture_rect: TextureRect
var _viewport: SubViewport
var _map_camera: Camera3D
var _marker_root: Node2D
var _marker_shape: Polygon2D
var _north_label: Label
var _dynamic_center: Vector3 = Vector3.ZERO

func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody3D
	_village = get_node_or_null(village_path) as Node3D

	_derive_map_parameters()
	_build_ui()
	_build_map_viewport()
	_update_runtime_state()

func _process(_delta: float) -> void:
	_update_runtime_state()

func _derive_map_parameters() -> void:
	if _village == null:
		return

	map_center = _village.global_position
	var radius_variant: Variant = _village.get("village_radius")
	var radius_type: int = typeof(radius_variant)
	if radius_type == TYPE_FLOAT or radius_type == TYPE_INT:
		var radius: float = float(radius_variant)
		if radius > 2.0:
			map_world_size = maxf(40.0, radius * 2.0)

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 45
	add_child(_ui_layer)

	_panel = Panel.new()
	_panel.anchor_left = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = float(-map_size_px - map_margin_px)
	_panel.offset_top = float(map_margin_px)
	_panel.offset_right = float(-map_margin_px)
	_panel.offset_bottom = float(map_size_px + map_margin_px)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = frame_color
	panel_style.border_color = frame_border_color
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	_panel.add_theme_stylebox_override("panel", panel_style)

	_map_texture_rect = TextureRect.new()
	_map_texture_rect.position = Vector2(8.0, 8.0)
	_map_texture_rect.size = Vector2(float(map_size_px - 16), float(map_size_px - 16))
	_map_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_map_texture_rect.modulate = map_texture_tint
	_map_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_map_texture_rect)

	_marker_root = Node2D.new()
	_map_texture_rect.add_child(_marker_root)

	_marker_shape = Polygon2D.new()
	_marker_shape.color = marker_color
	_marker_shape.polygon = PackedVector2Array([
		Vector2(0.0, -7.0),
		Vector2(5.5, 6.0),
		Vector2(0.0, 2.2),
		Vector2(-5.5, 6.0)
	])
	_marker_root.add_child(_marker_shape)

	_north_label = Label.new()
	_north_label.text = "N"
	_north_label.position = Vector2((_map_texture_rect.size.x * 0.5) - 6.0, -1.0)
	_north_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.22, 1.0))
	_north_label.add_theme_font_size_override("font_size", 14)
	_map_texture_rect.add_child(_north_label)

func _build_map_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.disable_3d = false
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.size = Vector2i(maxi(96, map_size_px - 16), maxi(96, map_size_px - 16))
	_viewport.world_3d = get_viewport().world_3d
	add_child(_viewport)

	_map_texture_rect.texture = _viewport.get_texture()

	_map_camera = Camera3D.new()
	_map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_map_camera.size = map_world_size
	_map_camera.near = 0.05
	_map_camera.far = map_height + 220.0
	_map_camera.current = true
	_viewport.add_child(_map_camera)

func _update_runtime_state() -> void:
	if _map_camera == null:
		return

	_dynamic_center = map_center
	if follow_player and _player != null:
		_dynamic_center.x = _player.global_position.x
		_dynamic_center.z = _player.global_position.z

	var center_target: Vector3 = Vector3(_dynamic_center.x, _dynamic_center.y, _dynamic_center.z)
	_map_camera.global_position = center_target + Vector3(0.0, map_height, 0.0)
	_map_camera.look_at(center_target, Vector3(0.0, 0.0, -1.0))

	_update_player_marker()

func _update_player_marker() -> void:
	if _player == null or _marker_root == null or _map_texture_rect == null:
		return

	var local_x: float = _player.global_position.x - _dynamic_center.x
	var local_z: float = _player.global_position.z - _dynamic_center.z
	var u: float = clampf(local_x / map_world_size + 0.5, 0.03, 0.97)
	var v: float = clampf(local_z / map_world_size + 0.5, 0.03, 0.97)

	var map_size: Vector2 = _map_texture_rect.size
	_marker_root.position = Vector2(map_size.x * u, map_size.y * v)
	_marker_root.rotation = -_player.global_rotation.y
