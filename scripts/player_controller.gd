extends CharacterBody3D

const ACTION_UI_CANCEL: StringName = &"ui_cancel"
const ACTION_CLICK_CAPTURE: StringName = &"click_capture"
const ACTION_TOGGLE_NIGHT_VISION: StringName = &"toggle_night_vision"
const ACTION_MOVE_FORWARD: StringName = &"move_forward"
const ACTION_MOVE_BACK: StringName = &"move_back"
const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_MOVE_JUMP: StringName = &"move_jump"
const ACTION_MOVE_SPRINT: StringName = &"move_sprint"
const ACTION_MOVE_CROUCH: StringName = &"move_crouch"
const ACTION_INTERACT: StringName = &"interact"
const ACTION_TOGGLE_DOOR: StringName = &"toggle_door"
const GROUP_INTERACTABLE_DOORS: StringName = &"interactable_door"
const NIGHT_VISION_LOCKED_HINT_DURATION: float = 2.2
const NIGHT_VISION_PROMPT_TEXT: String = "Gece gorusunu acmak icin F harfine basin"

@export var mouse_sensitivity: float = 0.0018
@export var walk_speed: float = 3.7
@export var sprint_speed: float = 6.1
@export var crouch_speed: float = 2.0
@export var acceleration: float = 11.5
@export var deceleration: float = 8.8
@export var jump_velocity: float = 5.2
@export var gravity_scale: float = 1.0
@export var strafe_speed_multiplier: float = 0.86
@export var backward_speed_multiplier: float = 0.8
@export var sprint_acceleration_multiplier: float = 1.18

@export var headbob_frequency: float = 1.5
@export var headbob_amplitude: float = 0.04
@export var sprint_headbob_multiplier: float = 1.22
@export var air_control: float = 0.25

@export var stand_capsule_height: float = 1.2
@export var crouch_capsule_height: float = 0.72
@export var stand_head_height: float = 1.6
@export var crouch_head_height: float = 1.1
@export var crouch_lerp_speed: float = 10.0

@export var walk_fov: float = 88.0
@export var sprint_fov: float = 96.0
@export var crouch_fov: float = 84.0
@export var fov_lerp_speed: float = 6.0
@export var camera_tilt_strength: float = 0.02
@export var camera_sway_strength: float = 0.011
@export var landing_bump_strength: float = 0.08
@export var landing_recover_speed: float = 10.0
@export var camera_roll_sway_enabled: bool = true
@export var camera_noise_strength: float = 0.0019
@export var camera_noise_speed: float = 1.28

@export var injury_default_duration: float = 15.0
@export var injury_speed_multiplier: float = 0.72
@export var night_vision_starts_on: bool = false
@export var night_vision_ir_energy: float = 9.2
@export var night_vision_ir_range: float = 34.0
@export var night_vision_ir_angle: float = 72.0
@export var night_vision_ir_attenuation: float = 0.84
@export var night_vision_ir_color: Color = Color(0.30, 1.0, 0.36, 1.0)
@export var night_vision_ir_shadow_enabled: bool = false
@export var night_vision_unlock_prompt_duration: float = 10.0
@export var prompt_scan_interval: float = 0.09

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var night_vision_rig: Node3D = $Head/NightVisionRig
@onready var night_vision_ir_light: SpotLight3D = $Head/NightVisionRig/IRIlluminator

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _pitch: float = 0.0
var _bob_time: float = 0.0
var _base_head_pos: Vector3
var _camera_base_pos: Vector3
var _night_vision_base_pos: Vector3
var _night_vision_base_rot: Vector3
var _capsule: CapsuleShape3D
var _is_crouching: bool = false
var _landing_offset: float = 0.0
var _mouse_sway: Vector2 = Vector2.ZERO
var _camera_noise_time: float = 0.0

var _controls_locked: bool = false
var _injury_time_left: float = 0.0
var _injury_wobble_time: float = 0.0
var _has_fuel: bool = false
var _night_vision_on: bool = false
var _night_vision_unlocked: bool = false

var _night_vision_overlay_layer: CanvasLayer
var _night_vision_overlay_rect: ColorRect
var _night_vision_overlay_material: ShaderMaterial
var _night_vision_label: Label

var _prompt_layer: CanvasLayer
var _door_prompt_bg: ColorRect
var _door_prompt_label: Label
var _night_vision_prompt_bg: ColorRect
var _night_vision_prompt_label: Label
var _door_prompt_scan_left: float = 0.0
var _nearby_door: InteractableDoor
var _night_vision_prompt_time_left: float = 0.0

func _ready() -> void:
	_setup_default_input_map()
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_base_head_pos = head.position
	_camera_base_pos = camera.position
	_night_vision_base_pos = night_vision_rig.position
	_night_vision_base_rot = night_vision_rig.rotation
	_capsule = collision_shape.shape as CapsuleShape3D
	if _capsule:
		stand_capsule_height = _capsule.height

	camera.fov = walk_fov
	head.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.position = _camera_base_pos
	_build_night_vision_overlay()
	_build_prompt_overlay()
	_apply_night_vision_settings()
	_night_vision_on = false
	_night_vision_unlocked = false
	if night_vision_starts_on:
		_night_vision_unlocked = true
		_night_vision_on = true
	_set_night_vision_enabled(_night_vision_on)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_UI_CANCEL):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	if event.is_action_pressed(ACTION_CLICK_CAPTURE):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return
	if event.is_action_pressed(ACTION_TOGGLE_NIGHT_VISION):
		if not _night_vision_unlocked:
			_show_night_vision_prompt(NIGHT_VISION_LOCKED_HINT_DURATION)
			return
		_set_night_vision_enabled(not _night_vision_on)
		_night_vision_prompt_time_left = 0.0
		return

	if _controls_locked:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-88.0), deg_to_rad(88.0))
		head.rotation.x = _pitch
		if camera_roll_sway_enabled:
			_mouse_sway.x = clampf(_mouse_sway.x + event.relative.x * 0.00003, -camera_sway_strength, camera_sway_strength)
			_mouse_sway.y = clampf(_mouse_sway.y + event.relative.y * 0.00002, -camera_sway_strength, camera_sway_strength)

func _physics_process(delta: float) -> void:
	if _injury_time_left > 0.0:
		_injury_time_left = maxf(0.0, _injury_time_left - delta)
		_injury_wobble_time += delta
	else:
		_injury_wobble_time = lerpf(_injury_wobble_time, 0.0, minf(1.0, delta * 2.0))

	if _controls_locked:
		velocity = Vector3.ZERO
		_bob_time = lerpf(_bob_time, 0.0, minf(1.0, delta * 8.0))
		_landing_offset = lerpf(_landing_offset, 0.0, minf(1.0, delta * landing_recover_speed))
		camera.fov = lerpf(camera.fov, walk_fov, minf(1.0, delta * fov_lerp_speed))
		_update_night_vision_motion(delta)
		_update_prompt_state(delta)
		return

	var was_on_floor: bool = is_on_floor()
	var previous_vertical_velocity: float = velocity.y

	_update_crouch_state(delta)

	var input_dir: Vector2 = Input.get_vector(ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT, ACTION_MOVE_FORWARD, ACTION_MOVE_BACK)
	var yaw_basis: Basis = Basis(Vector3.UP, rotation.y)
	var wish_dir: Vector3 = (yaw_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed: float = walk_speed
	if _is_crouching:
		speed = crouch_speed
	elif Input.is_action_pressed(ACTION_MOVE_SPRINT):
		speed = sprint_speed

	var locomotion_scale: float = 1.0
	if input_dir.y > 0.08:
		locomotion_scale *= backward_speed_multiplier
	if absf(input_dir.x) > 0.08 and input_dir.y > -0.2:
		locomotion_scale *= strafe_speed_multiplier
	speed *= locomotion_scale

	if _is_injured_phase():
		var limp_pulse: float = maxf(0.0, sin(_injury_wobble_time * 8.0))
		var limp_factor: float = injury_speed_multiplier * (0.92 - limp_pulse * 0.22)
		speed *= limp_factor
		if Input.is_action_pressed(ACTION_MOVE_SPRINT):
			speed = maxf(speed, walk_speed * 0.95)

	var target_velocity: Vector3 = wish_dir * speed
	var control: float = 1.0 if is_on_floor() else air_control
	var accel: float = acceleration if wish_dir.length() > 0.0 else deceleration
	if Input.is_action_pressed(ACTION_MOVE_SPRINT) and input_dir.y < -0.08 and wish_dir.length() > 0.0:
		accel *= sprint_acceleration_multiplier

	velocity.x = move_toward(velocity.x, target_velocity.x, accel * control * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel * control * delta)

	if not is_on_floor():
		velocity.y -= _gravity * gravity_scale * delta
	elif Input.is_action_just_pressed(ACTION_MOVE_JUMP) and not _is_crouching and not _is_injured_phase():
		velocity.y = jump_velocity

	move_and_slide()

	if not was_on_floor and is_on_floor() and previous_vertical_velocity < -2.0:
		_landing_offset = minf(absf(previous_vertical_velocity) * 0.015, landing_bump_strength)

	_apply_headbob(delta)
	_update_camera_effects(delta, input_dir)
	_update_night_vision_motion(delta)
	_update_prompt_state(delta)

func lock_controls(locked: bool) -> void:
	_controls_locked = locked
	if locked:
		velocity = Vector3.ZERO
		_mouse_sway = Vector2.ZERO
		_bob_time = 0.0

func controls_locked() -> bool:
	return _controls_locked

func start_injury(duration_seconds: float = -1.0) -> void:
	var duration: float = injury_default_duration if duration_seconds <= 0.0 else duration_seconds
	_injury_time_left = maxf(0.0, duration)
	_injury_wobble_time = 0.0

func set_has_fuel(value: bool) -> void:
	_has_fuel = value

func has_fuel() -> bool:
	return _has_fuel

func consume_fuel() -> void:
	_has_fuel = false

func place_player(world_transform: Transform3D) -> void:
	global_transform = world_transform
	velocity = Vector3.ZERO
	_landing_offset = 0.0

func set_head_camera_pose(pitch_rad: float, roll_rad: float, camera_offset: Vector3) -> void:
	_pitch = pitch_rad
	head.rotation.x = pitch_rad
	head.rotation.z = roll_rad
	camera.position = _camera_base_pos + camera_offset
	camera.rotation = Vector3.ZERO

func reset_head_camera_pose() -> void:
	_pitch = 0.0
	head.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.position = _camera_base_pos

func set_first_person_active(active: bool) -> void:
	camera.current = active

func unlock_night_vision_controls(show_hint: bool = true) -> void:
	_night_vision_unlocked = true
	if show_hint:
		_show_night_vision_prompt(night_vision_unlock_prompt_duration)

func _set_night_vision_enabled(enabled: bool) -> void:
	if enabled and not _night_vision_unlocked:
		enabled = false
	_night_vision_on = enabled
	if night_vision_ir_light != null:
		night_vision_ir_light.visible = enabled
		night_vision_ir_light.light_energy = night_vision_ir_energy if enabled else 0.0

	if is_instance_valid(_night_vision_overlay_rect):
		_night_vision_overlay_rect.visible = enabled
	if is_instance_valid(_night_vision_label):
		_night_vision_label.visible = enabled
	if _night_vision_overlay_material != null:
		_night_vision_overlay_material.set_shader_parameter("overlay_alpha", 0.9 if enabled else 0.0)

func _apply_night_vision_settings() -> void:
	if night_vision_ir_light == null:
		return
	night_vision_ir_light.light_color = night_vision_ir_color
	night_vision_ir_light.spot_range = night_vision_ir_range
	night_vision_ir_light.spot_angle = night_vision_ir_angle
	night_vision_ir_light.spot_attenuation = night_vision_ir_attenuation
	night_vision_ir_light.shadow_enabled = night_vision_ir_shadow_enabled
	night_vision_ir_light.shadow_bias = 0.05
	night_vision_ir_light.shadow_normal_bias = 1.0

func _update_night_vision_motion(delta: float) -> void:
	if night_vision_rig == null:
		return

	var injury_shake: float = sin(_injury_wobble_time * 6.3) * (0.016 if _is_injured_phase() else 0.0)
	var bob_x: float = cos(_bob_time * 0.55) * 0.008
	var bob_y: float = sin(_bob_time * 1.05) * 0.012
	var sway_x: float = _mouse_sway.x * 2.2
	var sway_y: float = -_mouse_sway.y * 2.2

	var target_pos: Vector3 = _night_vision_base_pos + Vector3(bob_x + injury_shake, bob_y - absf(injury_shake) * 0.25, 0.0)
	var target_rot: Vector3 = _night_vision_base_rot + Vector3(sway_y * 2.1, -sway_x * 1.35, -sway_x * 0.65)

	night_vision_rig.position = night_vision_rig.position.lerp(target_pos, minf(1.0, delta * 10.0))
	night_vision_rig.rotation = night_vision_rig.rotation.lerp(target_rot, minf(1.0, delta * 8.0))

func _build_night_vision_overlay() -> void:
	var overlay_shader: Shader = load("res://shaders/night_vision_overlay.gdshader") as Shader
	if overlay_shader == null:
		return

	_night_vision_overlay_layer = CanvasLayer.new()
	_night_vision_overlay_layer.layer = 60
	add_child(_night_vision_overlay_layer)

	_night_vision_overlay_rect = ColorRect.new()
	_night_vision_overlay_rect.anchor_left = 0.0
	_night_vision_overlay_rect.anchor_top = 0.0
	_night_vision_overlay_rect.anchor_right = 1.0
	_night_vision_overlay_rect.anchor_bottom = 1.0
	_night_vision_overlay_rect.offset_left = 0.0
	_night_vision_overlay_rect.offset_top = 0.0
	_night_vision_overlay_rect.offset_right = 0.0
	_night_vision_overlay_rect.offset_bottom = 0.0
	_night_vision_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night_vision_overlay_rect.color = Color(1.0, 1.0, 1.0, 1.0)
	_night_vision_overlay_layer.add_child(_night_vision_overlay_rect)

	_night_vision_overlay_material = ShaderMaterial.new()
	_night_vision_overlay_material.shader = overlay_shader
	_night_vision_overlay_material.set_shader_parameter("overlay_alpha", 0.9)
	_night_vision_overlay_material.set_shader_parameter("gain", 2.25)
	_night_vision_overlay_material.set_shader_parameter("grain_strength", 0.07)
	_night_vision_overlay_material.set_shader_parameter("scanline_strength", 0.09)
	_night_vision_overlay_material.set_shader_parameter("vignette_strength", 0.36)
	_night_vision_overlay_rect.material = _night_vision_overlay_material

	_night_vision_label = Label.new()
	_night_vision_label.text = "NV CAM"
	_night_vision_label.position = Vector2(18.0, 14.0)
	_night_vision_label.add_theme_color_override("font_color", Color(0.56, 1.0, 0.62, 0.95))
	_night_vision_label.add_theme_font_size_override("font_size", 15)
	_night_vision_overlay_layer.add_child(_night_vision_label)

func _build_prompt_overlay() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.layer = 61
	add_child(_prompt_layer)

	_door_prompt_bg = ColorRect.new()
	_door_prompt_bg.anchor_left = 0.5
	_door_prompt_bg.anchor_top = 1.0
	_door_prompt_bg.anchor_right = 0.5
	_door_prompt_bg.anchor_bottom = 1.0
	_door_prompt_bg.offset_left = -200.0
	_door_prompt_bg.offset_top = -88.0
	_door_prompt_bg.offset_right = 200.0
	_door_prompt_bg.offset_bottom = -46.0
	_door_prompt_bg.color = Color(0.02, 0.03, 0.04, 0.74)
	_door_prompt_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door_prompt_bg.visible = false
	_prompt_layer.add_child(_door_prompt_bg)

	_door_prompt_label = Label.new()
	_door_prompt_label.anchor_left = 0.0
	_door_prompt_label.anchor_top = 0.0
	_door_prompt_label.anchor_right = 1.0
	_door_prompt_label.anchor_bottom = 1.0
	_door_prompt_label.offset_left = 14.0
	_door_prompt_label.offset_top = 8.0
	_door_prompt_label.offset_right = -14.0
	_door_prompt_label.offset_bottom = -8.0
	_door_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_door_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_door_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_door_prompt_label.add_theme_font_size_override("font_size", 18)
	_door_prompt_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.97, 1.0))
	_door_prompt_bg.add_child(_door_prompt_label)

	_night_vision_prompt_bg = ColorRect.new()
	_night_vision_prompt_bg.anchor_left = 0.5
	_night_vision_prompt_bg.anchor_top = 1.0
	_night_vision_prompt_bg.anchor_right = 0.5
	_night_vision_prompt_bg.anchor_bottom = 1.0
	_night_vision_prompt_bg.offset_left = -250.0
	_night_vision_prompt_bg.offset_top = -136.0
	_night_vision_prompt_bg.offset_right = 250.0
	_night_vision_prompt_bg.offset_bottom = -96.0
	_night_vision_prompt_bg.color = Color(0.02, 0.03, 0.04, 0.74)
	_night_vision_prompt_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night_vision_prompt_bg.visible = false
	_prompt_layer.add_child(_night_vision_prompt_bg)

	_night_vision_prompt_label = Label.new()
	_night_vision_prompt_label.anchor_left = 0.0
	_night_vision_prompt_label.anchor_top = 0.0
	_night_vision_prompt_label.anchor_right = 1.0
	_night_vision_prompt_label.anchor_bottom = 1.0
	_night_vision_prompt_label.offset_left = 12.0
	_night_vision_prompt_label.offset_top = 7.0
	_night_vision_prompt_label.offset_right = -12.0
	_night_vision_prompt_label.offset_bottom = -7.0
	_night_vision_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_night_vision_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_night_vision_prompt_label.add_theme_font_size_override("font_size", 16)
	_night_vision_prompt_label.add_theme_color_override("font_color", Color(0.82, 0.97, 0.86, 0.96))
	_night_vision_prompt_bg.add_child(_night_vision_prompt_label)

func _update_prompt_state(delta: float) -> void:
	if _night_vision_prompt_time_left > 0.0:
		_night_vision_prompt_time_left = maxf(0.0, _night_vision_prompt_time_left - delta)

	_door_prompt_scan_left -= delta
	if _door_prompt_scan_left <= 0.0:
		_door_prompt_scan_left = prompt_scan_interval
		_nearby_door = _find_nearby_door()

	_update_door_prompt()
	_update_night_vision_prompt()

func _show_night_vision_prompt(duration_seconds: float) -> void:
	_night_vision_prompt_time_left = maxf(_night_vision_prompt_time_left, duration_seconds)

func _update_door_prompt() -> void:
	if _door_prompt_bg == null or _door_prompt_label == null:
		return
	if _nearby_door == null:
		_door_prompt_bg.visible = false
		return
	_door_prompt_label.text = _nearby_door.get_prompt_text()
	_door_prompt_bg.visible = true

func _update_night_vision_prompt() -> void:
	if _night_vision_prompt_bg == null or _night_vision_prompt_label == null:
		return
	var should_show: bool = _night_vision_unlocked and not _night_vision_on and _night_vision_prompt_time_left > 0.0
	_night_vision_prompt_bg.visible = should_show
	if should_show:
		_night_vision_prompt_label.text = NIGHT_VISION_PROMPT_TEXT

func _find_nearby_door() -> InteractableDoor:
	var nearest: InteractableDoor = null
	var nearest_dist_sq: float = INF
	var door_nodes: Array[Node] = get_tree().get_nodes_in_group(GROUP_INTERACTABLE_DOORS)

	for i in range(door_nodes.size()):
		var door: InteractableDoor = door_nodes[i] as InteractableDoor
		if door == null:
			continue
		if not door.can_player_interact(self):
			continue

		var dist_sq: float = global_position.distance_squared_to(door.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = door

	return nearest

func _is_injured_phase() -> bool:
	return _injury_time_left > 0.0

func _update_crouch_state(delta: float) -> void:
	var wants_crouch: bool = Input.is_action_pressed(ACTION_MOVE_CROUCH)
	if not wants_crouch and _would_hit_ceiling():
		_is_crouching = true
	else:
		_is_crouching = wants_crouch

	if _capsule:
		var target_capsule_height: float = crouch_capsule_height if _is_crouching else stand_capsule_height
		_capsule.height = lerpf(_capsule.height, target_capsule_height, minf(1.0, crouch_lerp_speed * delta))
		var target_center_y: float = _capsule.radius + (_capsule.height * 0.5)
		collision_shape.position.y = lerpf(collision_shape.position.y, target_center_y, minf(1.0, crouch_lerp_speed * delta))

	var target_head_height: float = crouch_head_height if _is_crouching else stand_head_height
	_base_head_pos.y = lerpf(_base_head_pos.y, target_head_height, minf(1.0, crouch_lerp_speed * delta))

func _would_hit_ceiling() -> bool:
	if not _capsule:
		return false
	var diff: float = stand_capsule_height - _capsule.height
	if diff <= 0.02:
		return false
	return test_move(global_transform, Vector3.UP * diff)

func _apply_headbob(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.1:
		var bob_mul: float = sprint_headbob_multiplier if Input.is_action_pressed(ACTION_MOVE_SPRINT) and not _is_crouching else 1.0
		var limp_mul: float = 1.2 if _is_injured_phase() else 1.0
		_bob_time += delta * horizontal_speed * headbob_frequency * bob_mul * limp_mul

		var crouch_mul: float = 0.55 if _is_crouching else 1.0
		var limp_side: float = sin(_injury_wobble_time * 7.0) * (0.03 if _is_injured_phase() else 0.0)
		var bob_x: float = cos(_bob_time * 0.5) * headbob_amplitude * 0.45 * crouch_mul + limp_side
		var bob_y: float = sin(_bob_time) * headbob_amplitude * crouch_mul
		if _is_injured_phase():
			bob_y = maxf(0.0, bob_y) * 1.3 - headbob_amplitude * 0.24

		head.position = _base_head_pos + Vector3(bob_x, bob_y - _landing_offset, 0.0)
	else:
		_bob_time = lerpf(_bob_time, 0.0, 8.0 * delta)
		head.position = head.position.lerp(_base_head_pos - Vector3(0.0, _landing_offset, 0.0), minf(1.0, 10.0 * delta))

func _update_camera_effects(delta: float, input_dir: Vector2) -> void:
	_landing_offset = lerpf(_landing_offset, 0.0, minf(1.0, landing_recover_speed * delta))
	_mouse_sway = _mouse_sway.lerp(Vector2.ZERO, minf(1.0, 8.0 * delta))
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var movement_noise_scale: float = 0.7 + clampf(horizontal_speed / maxf(walk_speed, 0.01), 0.0, 1.0) * 0.55
	_camera_noise_time += delta * camera_noise_speed * movement_noise_scale

	var target_fov: float = walk_fov
	if _is_crouching:
		target_fov = crouch_fov
	elif Input.is_action_pressed(ACTION_MOVE_SPRINT) and is_on_floor() and input_dir.y < -0.1 and not _is_injured_phase():
		target_fov = sprint_fov
	camera.fov = lerpf(camera.fov, target_fov, minf(1.0, fov_lerp_speed * delta))

	var noise_x: float = sin(_camera_noise_time * 1.3) * camera_noise_strength
	noise_x += sin(_camera_noise_time * 2.75 + 0.65) * camera_noise_strength * 0.42
	var noise_y: float = cos(_camera_noise_time * 1.65) * camera_noise_strength * 1.1
	noise_y += sin(_camera_noise_time * 3.4 + 1.2) * camera_noise_strength * 0.32
	var camera_noise: Vector3 = Vector3(noise_x, noise_y, 0.0)

	if not camera_roll_sway_enabled:
		camera.rotation = Vector3.ZERO
		camera.position = _camera_base_pos + camera_noise
		return

	var limp_roll: float = sin(_injury_wobble_time * 7.0) * 0.035 if _is_injured_phase() else 0.0
	var breathing_roll: float = sin(_camera_noise_time * 0.82) * camera_noise_strength * 5.5
	var target_roll: float = -input_dir.x * camera_tilt_strength + _mouse_sway.x + limp_roll + breathing_roll
	camera.rotation.z = lerpf(camera.rotation.z, target_roll, minf(1.0, 10.0 * delta))

	var sway_offset: Vector3 = Vector3(_mouse_sway.x * 0.35, -_mouse_sway.y * 0.35, 0.0)
	camera.position = camera.position.lerp(_camera_base_pos + sway_offset + camera_noise, minf(1.0, 10.0 * delta))

func _setup_default_input_map() -> void:
	_add_action_if_missing(ACTION_MOVE_FORWARD, KEY_W)
	_add_action_if_missing(ACTION_MOVE_BACK, KEY_S)
	_add_action_if_missing(ACTION_MOVE_LEFT, KEY_A)
	_add_action_if_missing(ACTION_MOVE_RIGHT, KEY_D)
	_add_action_if_missing(ACTION_MOVE_JUMP, KEY_SPACE)
	_add_action_if_missing(ACTION_MOVE_SPRINT, KEY_SHIFT)
	_add_action_if_missing(ACTION_MOVE_CROUCH, KEY_CTRL)
	_add_action_if_missing(ACTION_INTERACT, KEY_E)
	_add_action_if_missing(ACTION_TOGGLE_DOOR, KEY_P)
	_add_action_if_missing(ACTION_TOGGLE_NIGHT_VISION, KEY_F)
	_add_action_if_missing(ACTION_CLICK_CAPTURE, MOUSE_BUTTON_LEFT, true)

func _add_action_if_missing(action: StringName, keycode: int, is_mouse: bool = false) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var ev: InputEvent
		if is_mouse:
			var m: InputEventMouseButton = InputEventMouseButton.new()
			m.button_index = keycode
			ev = m
		else:
			var k: InputEventKey = InputEventKey.new()
			k.physical_keycode = keycode
			ev = k
		InputMap.action_add_event(action, ev)
