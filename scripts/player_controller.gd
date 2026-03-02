extends CharacterBody3D

@export var mouse_sensitivity: float = 0.0018
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.2
@export var crouch_speed: float = 2.4
@export var acceleration: float = 16.0
@export var deceleration: float = 12.0
@export var jump_velocity: float = 5.2
@export var gravity_scale: float = 1.0

@export var headbob_frequency: float = 1.8
@export var headbob_amplitude: float = 0.05
@export var sprint_headbob_multiplier: float = 1.35
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
@export var camera_tilt_strength: float = 0.03
@export var camera_sway_strength: float = 0.015
@export var landing_bump_strength: float = 0.08
@export var landing_recover_speed: float = 10.0

@export var intro_duration: float = 5.6
@export var injury_duration: float = 15.0
@export var injury_speed_multiplier: float = 0.72

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _pitch: float = 0.0
var _bob_time: float = 0.0
var _base_head_pos: Vector3
var _camera_base_pos: Vector3
var _capsule: CapsuleShape3D
var _is_crouching: bool = false
var _landing_offset: float = 0.0
var _mouse_sway: Vector2 = Vector2.ZERO

var _elapsed_time: float = 0.0
var _intro_active: bool = true
var _blink_overlay: ColorRect
var _injury_elapsed: float = 0.0

func _ready() -> void:
	_setup_default_input_map()
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_base_head_pos = head.position
	_camera_base_pos = camera.position
	_capsule = collision_shape.shape as CapsuleShape3D
	if _capsule:
		stand_capsule_height = _capsule.height
	camera.fov = walk_fov
	_setup_blink_overlay()
	_apply_intro_pose(0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	if event.is_action_pressed("click_capture"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if _intro_active:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-88.0), deg_to_rad(88.0))
		head.rotation.x = _pitch
		_mouse_sway.x = clamp(_mouse_sway.x + event.relative.x * 0.00003, -camera_sway_strength, camera_sway_strength)
		_mouse_sway.y = clamp(_mouse_sway.y + event.relative.y * 0.00002, -camera_sway_strength, camera_sway_strength)

func _physics_process(delta: float) -> void:
	_elapsed_time += delta
	if _intro_active:
		_update_intro(delta)
		return

	_injury_elapsed += delta

	var was_on_floor := is_on_floor()
	var previous_vertical_velocity := velocity.y

	_update_crouch_state(delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed := walk_speed
	if _is_crouching:
		speed = crouch_speed
	elif Input.is_action_pressed("move_sprint"):
		speed = sprint_speed

	if _is_injured_phase():
		var limp_pulse := max(0.0, sin(_injury_elapsed * 8.5))
		var limp_factor := injury_speed_multiplier * (0.9 - limp_pulse * 0.22)
		speed *= limp_factor
		if Input.is_action_pressed("move_sprint"):
			speed = max(speed * 0.95, walk_speed * 0.95)

	var target_velocity := wish_dir * speed
	var control := 1.0 if is_on_floor() else air_control
	var accel := acceleration if wish_dir.length() > 0.0 else deceleration

	velocity.x = move_toward(velocity.x, target_velocity.x, accel * control * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel * control * delta)

	if not is_on_floor():
		velocity.y -= _gravity * gravity_scale * delta
	elif Input.is_action_just_pressed("move_jump") and not _is_crouching and not _is_injured_phase():
		velocity.y = jump_velocity

	move_and_slide()

	if not was_on_floor and is_on_floor() and previous_vertical_velocity < -2.0:
		_landing_offset = min(abs(previous_vertical_velocity) * 0.015, landing_bump_strength)

	_apply_headbob(delta)
	_update_camera_effects(delta, input_dir)

func _update_intro(delta: float) -> void:
	velocity = Vector3.ZERO
	_apply_intro_pose(_elapsed_time)
	_update_blink_overlay(_elapsed_time)

	if _elapsed_time >= intro_duration:
		_intro_active = false
		_injury_elapsed = 0.0
		if is_instance_valid(_blink_overlay):
			_blink_overlay.visible = false
		head.position = _base_head_pos
		head.rotation.z = 0.0
		camera.position = _camera_base_pos

func _apply_intro_pose(t: float) -> void:
	var prone_end: float = 1.8
	var stand_start: float = 2.7
	var stand_end: float = intro_duration

	if t <= prone_end:
		_base_head_pos.y = 0.55
		head.position = Vector3(_base_head_pos.x, _base_head_pos.y, _base_head_pos.z)
		head.rotation.x = deg_to_rad(-84.0)
		head.rotation.z = deg_to_rad(8.0)
		camera.position = _camera_base_pos + Vector3(0.04, -0.02, 0.0)
		return

	if t < stand_start:
		_base_head_pos.y = lerp(0.55, 0.68, (t - prone_end) / (stand_start - prone_end))
		head.position = Vector3(_base_head_pos.x, _base_head_pos.y, _base_head_pos.z)
		head.rotation.x = deg_to_rad(-84.0)
		head.rotation.z = deg_to_rad(6.0)
		camera.position = _camera_base_pos + Vector3(0.03, -0.01, 0.0)
		return

	var stand_t: float = clampf((t - stand_start) / maxf(0.01, stand_end - stand_start), 0.0, 1.0)
	_base_head_pos.y = lerp(0.68, stand_head_height, stand_t)
	head.position = Vector3(_base_head_pos.x, _base_head_pos.y, _base_head_pos.z)
	_pitch = lerp(deg_to_rad(-84.0), 0.0, stand_t)
	head.rotation.x = _pitch
	head.rotation.z = lerp(deg_to_rad(6.0), 0.0, stand_t)
	var intro_cam_offset := Vector3(0.03, -0.01, 0.0)
	camera.position = (_camera_base_pos + intro_cam_offset).lerp(_camera_base_pos, stand_t)

func _update_blink_overlay(t: float) -> void:
	if not is_instance_valid(_blink_overlay):
		return
	_blink_overlay.visible = true
	var alpha: float = 0.0
	alpha = maxf(alpha, _blink_curve(t, 1.95, 0.22))
	alpha = maxf(alpha, _blink_curve(t, 2.35, 0.22))
	_blink_overlay.color = Color(0.0, 0.0, 0.0, alpha)

func _blink_curve(t: float, center: float, duration: float) -> float:
	var half: float = duration * 0.5
	var d: float = absf(t - center)
	if d >= half:
		return 0.0
	return 1.0 - (d / half)

func _setup_blink_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_blink_overlay = ColorRect.new()
	_blink_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blink_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blink_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	layer.add_child(_blink_overlay)

func _is_injured_phase() -> bool:
	return _injury_elapsed < injury_duration

func _update_crouch_state(delta: float) -> void:
	var wants_crouch := Input.is_action_pressed("move_crouch")
	if not wants_crouch and _would_hit_ceiling():
		_is_crouching = true
	else:
		_is_crouching = wants_crouch

	if _capsule:
		var target_capsule_height := crouch_capsule_height if _is_crouching else stand_capsule_height
		_capsule.height = lerp(_capsule.height, target_capsule_height, min(1.0, crouch_lerp_speed * delta))
		var target_center_y := _capsule.radius + (_capsule.height * 0.5)
		collision_shape.position.y = lerp(collision_shape.position.y, target_center_y, min(1.0, crouch_lerp_speed * delta))

	var target_head_height := crouch_head_height if _is_crouching else stand_head_height
	_base_head_pos.y = lerp(_base_head_pos.y, target_head_height, min(1.0, crouch_lerp_speed * delta))

func _would_hit_ceiling() -> bool:
	if not _capsule:
		return false
	var diff := stand_capsule_height - _capsule.height
	if diff <= 0.02:
		return false
	return test_move(global_transform, Vector3.UP * diff)

func _apply_headbob(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.1:
		var bob_mul := sprint_headbob_multiplier if Input.is_action_pressed("move_sprint") and not _is_crouching else 1.0
		var limp_mul := 1.2 if _is_injured_phase() else 1.0
		_bob_time += delta * horizontal_speed * headbob_frequency * bob_mul * limp_mul
			var crouch_mul := 0.55 if _is_crouching else 1.0
			var limp_side := sin(_injury_elapsed * 7.0) * (0.03 if _is_injured_phase() else 0.0)
			var bob_x := cos(_bob_time * 0.5) * headbob_amplitude * 0.45 * crouch_mul + limp_side
			var bob_y := sin(_bob_time) * headbob_amplitude * crouch_mul
			if _is_injured_phase():
				bob_y = max(0.0, bob_y) * 1.3 - headbob_amplitude * 0.24
		head.position = _base_head_pos + Vector3(bob_x, bob_y - _landing_offset, 0.0)
	else:
		_bob_time = lerp(_bob_time, 0.0, 8.0 * delta)
		head.position = head.position.lerp(_base_head_pos - Vector3(0.0, _landing_offset, 0.0), min(1.0, 10.0 * delta))

func _update_camera_effects(delta: float, input_dir: Vector2) -> void:
	_landing_offset = lerp(_landing_offset, 0.0, min(1.0, landing_recover_speed * delta))
	_mouse_sway = _mouse_sway.lerp(Vector2.ZERO, min(1.0, 8.0 * delta))

	var target_fov := walk_fov
	if _is_crouching:
		target_fov = crouch_fov
	elif Input.is_action_pressed("move_sprint") and is_on_floor() and input_dir.y < -0.1 and not _is_injured_phase():
		target_fov = sprint_fov
	camera.fov = lerp(camera.fov, target_fov, min(1.0, fov_lerp_speed * delta))

	var limp_roll := sin(_injury_elapsed * 7.0) * 0.035 if _is_injured_phase() else 0.0
	var target_roll := -input_dir.x * camera_tilt_strength + _mouse_sway.x + limp_roll
	camera.rotation.z = lerp(camera.rotation.z, target_roll, min(1.0, 10.0 * delta))
	camera.position = camera.position.lerp(_camera_base_pos + Vector3(_mouse_sway.x * 0.35, -_mouse_sway.y * 0.35, 0.0), min(1.0, 10.0 * delta))

func _setup_default_input_map() -> void:
	_add_action_if_missing("move_forward", KEY_W)
	_add_action_if_missing("move_back", KEY_S)
	_add_action_if_missing("move_left", KEY_A)
	_add_action_if_missing("move_right", KEY_D)
	_add_action_if_missing("move_jump", KEY_SPACE)
	_add_action_if_missing("move_sprint", KEY_SHIFT)
	_add_action_if_missing("move_crouch", KEY_CTRL)
	_add_action_if_missing("click_capture", MOUSE_BUTTON_LEFT, true)

func _add_action_if_missing(action: StringName, keycode: int, is_mouse := false) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var ev: InputEvent
		if is_mouse:
			var m := InputEventMouseButton.new()
			m.button_index = keycode
			ev = m
		else:
			var k := InputEventKey.new()
			k.physical_keycode = keycode
			ev = k
		InputMap.action_add_event(action, ev)
