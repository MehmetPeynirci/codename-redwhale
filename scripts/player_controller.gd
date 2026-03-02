extends CharacterBody3D

@export var mouse_sensitivity: float = 0.0018
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.2
@export var acceleration: float = 16.0
@export var deceleration: float = 12.0
@export var jump_velocity: float = 5.2
@export var gravity_scale: float = 1.0

@export var headbob_frequency: float = 1.8
@export var headbob_amplitude: float = 0.05
@export var sprint_headbob_multiplier: float = 1.35
@export var air_control: float = 0.25

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _pitch: float = 0.0
var _bob_time: float = 0.0
var _base_head_pos: Vector3

func _ready() -> void:
	_setup_default_input_map()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_base_head_pos = head.position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-88.0), deg_to_rad(88.0))
		head.rotation.x = _pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event.is_action_pressed("click_capture"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("move_sprint") else walk_speed

	var target_velocity := wish_dir * speed
	var control := 1.0 if is_on_floor() else air_control
	var accel := acceleration if wish_dir.length() > 0.0 else deceleration

	velocity.x = move_toward(velocity.x, target_velocity.x, accel * control * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel * control * delta)

	if not is_on_floor():
		velocity.y -= _gravity * gravity_scale * delta
	elif Input.is_action_just_pressed("move_jump"):
		velocity.y = jump_velocity

	move_and_slide()
	_apply_headbob(delta, speed)

func _apply_headbob(delta: float, speed: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.1:
		var bob_mul := sprint_headbob_multiplier if Input.is_action_pressed("move_sprint") else 1.0
		_bob_time += delta * horizontal_speed * headbob_frequency * bob_mul
		var bob_x := cos(_bob_time * 0.5) * headbob_amplitude * 0.45
		var bob_y := sin(_bob_time) * headbob_amplitude
		head.position = _base_head_pos + Vector3(bob_x, bob_y, 0.0)
	else:
		_bob_time = lerp(_bob_time, 0.0, 8.0 * delta)
		head.position = head.position.lerp(_base_head_pos, min(1.0, 10.0 * delta))

func _setup_default_input_map() -> void:
	_add_action_if_missing("move_forward", KEY_W)
	_add_action_if_missing("move_back", KEY_S)
	_add_action_if_missing("move_left", KEY_A)
	_add_action_if_missing("move_right", KEY_D)
	_add_action_if_missing("move_jump", KEY_SPACE)
	_add_action_if_missing("move_sprint", KEY_SHIFT)
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
