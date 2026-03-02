extends Node3D

enum SequenceState {
	DRIVE,
	STALL,
	SETTLE,
	GAMEPLAY,
	RESTART
}

@export var player_path: NodePath
@export var car_path: NodePath
@export var seat_marker_path: NodePath
@export var exit_marker_path: NodePath
@export var refuel_point_path: NodePath

@export var drive_duration: float = 4.0
@export var stall_duration: float = 1.5
@export var settle_duration: float = 1.1
@export var restart_duration: float = 1.8
@export var drive_distance: float = 21.0
@export var third_person_camera_enabled: bool = true
@export var third_person_distance: float = 5.8
@export var third_person_height: float = 2.25
@export var third_person_side_offset: float = 1.15
@export var third_person_look_height: float = 1.1
@export var third_person_follow_lerp: float = 6.0
@export var third_person_fov: float = 78.0
@export var camera_shake_drive: float = 0.06
@export var camera_shake_stall: float = 0.12

var _player: CharacterBody3D
var _car: Node3D
var _seat_marker: Marker3D
var _exit_marker: Marker3D
var _refuel_point: Marker3D
var _player_camera: Camera3D
var _cinematic_camera: Camera3D
var _camera_anchor: Vector3 = Vector3.ZERO
var _camera_anchor_ready: bool = false
var _previous_car_position: Vector3 = Vector3.ZERO

var _state_time: float = 0.0
var _state: int = SequenceState.DRIVE

var _car_start: Transform3D
var _car_drive_end: Transform3D
var _car_stop_end: Transform3D

var _ui_layer: CanvasLayer
var _objective_bg: ColorRect
var _objective_label: Label
var _return_hint_shown: bool = false

func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody3D
	_car = get_node_or_null(car_path) as Node3D
	_seat_marker = get_node_or_null(seat_marker_path) as Marker3D
	_exit_marker = get_node_or_null(exit_marker_path) as Marker3D
	_refuel_point = get_node_or_null(refuel_point_path) as Marker3D

	if _player == null or _car == null or _seat_marker == null or _exit_marker == null or _refuel_point == null:
		push_warning("Breakdown sequence nodes are missing; skipping intro.")
		set_process(false)
		return

	_create_objective_ui()
	_set_objective("")

	_car_start = _car.global_transform
	_car_drive_end = _car_start.translated_local(Vector3(0.0, 0.0, -drive_distance))
	_car_stop_end = _car_drive_end.translated_local(Vector3(0.0, 0.0, -1.8))
	_player_camera = _player.get_node_or_null("Head/Camera3D") as Camera3D
	_previous_car_position = _car.global_position

	_player.call("lock_controls", true)
	_player.call("set_has_fuel", false)
	_snap_player_to_seat(deg_to_rad(-3.0), deg_to_rad(1.0), Vector3(0.01, -0.02, 0.02))
	_setup_intro_camera()

func _process(delta: float) -> void:
	_state_time += delta

	if _state == SequenceState.DRIVE:
		_update_drive(delta)
		return
	if _state == SequenceState.STALL:
		_update_stall(delta)
		return
	if _state == SequenceState.SETTLE:
		_update_settle(delta)
		return
	if _state == SequenceState.GAMEPLAY:
		_update_gameplay()
		return
	if _state == SequenceState.RESTART:
		_update_restart(delta)
		return

func _update_drive(delta: float) -> void:
	var alpha: float = clampf(_state_time / maxf(0.01, drive_duration), 0.0, 1.0)
	var eased: float = _ease_in_out(alpha)
	_car.global_transform = _car_start.interpolate_with(_car_drive_end, eased)

	var road_vibration: float = sin(_state_time * 13.0) * 0.01
	var pitch: float = deg_to_rad(-4.0 + road_vibration * 28.0)
	var roll: float = deg_to_rad(road_vibration * 15.0)
	var offset: Vector3 = Vector3(0.01, -0.02 + road_vibration, 0.02)
	_snap_player_to_seat(pitch, roll, offset)
	_update_cinematic_camera(delta, camera_shake_drive)

	if alpha >= 1.0:
		_state = SequenceState.STALL
		_state_time = 0.0

func _update_stall(delta: float) -> void:
	var t: float = clampf(_state_time / maxf(0.01, stall_duration), 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	_car.global_transform = _car_drive_end.interpolate_with(_car_stop_end, eased)

	var sputter: float = sin(_state_time * 22.0) * (1.0 - t)
	var pitch: float = deg_to_rad(-8.0 + sputter * 2.4)
	var roll: float = deg_to_rad(sputter * 1.8)
	var offset: Vector3 = Vector3(sputter * 0.004, -0.04 + absf(sputter) * 0.004, 0.035)
	_snap_player_to_seat(pitch, roll, offset)
	_update_cinematic_camera(delta, lerpf(camera_shake_stall, camera_shake_stall * 0.45, t))

	if t >= 1.0:
		_state = SequenceState.SETTLE
		_state_time = 0.0

func _update_settle(delta: float) -> void:
	_car.global_transform = _car_stop_end
	var alpha: float = clampf(_state_time / maxf(0.01, settle_duration), 0.0, 1.0)
	var eased: float = _ease_in_out(alpha)

	var pitch: float = lerpf(deg_to_rad(-8.0), deg_to_rad(-2.0), eased)
	var roll: float = lerpf(deg_to_rad(1.4), 0.0, eased)
	var offset: Vector3 = Vector3(0.0, lerpf(-0.03, 0.0, eased), lerpf(0.03, 0.0, eased))
	_snap_player_to_seat(pitch, roll, offset)
	_update_cinematic_camera(delta, lerpf(camera_shake_stall * 0.35, 0.0, eased))

	if alpha >= 1.0:
		_finish_cinematic()

func _finish_cinematic() -> void:
	_car.global_transform = _car_stop_end
	_disable_intro_camera()
	_player.call("place_player", _exit_marker.global_transform)
	_player.call("reset_head_camera_pose")
	_set_first_person_camera_active(true)
	_player.call("lock_controls", false)
	if _player.has_method("unlock_night_vision_controls"):
		_player.call("unlock_night_vision_controls", true)

	_set_objective("Motor bozuldu. Koyde bir yerden yakit bidonu bul.")
	_state = SequenceState.GAMEPLAY
	_state_time = 0.0

func _update_gameplay() -> void:
	var has_fuel: bool = bool(_player.call("has_fuel"))
	if has_fuel and not _return_hint_shown:
		_return_hint_shown = true
		_set_objective("Yakiti buldun. Arabaya don, motorun yanina gel ve E bas.")

	if not has_fuel:
		return

	var distance_to_refuel: float = _player.global_position.distance_to(_refuel_point.global_position)
	if distance_to_refuel <= 2.6 and Input.is_action_just_pressed("interact"):
		_player.call("consume_fuel")
		_player.call("lock_controls", true)
		_set_objective("Motor yeniden calistiriliyor...")
		_state = SequenceState.RESTART
		_state_time = 0.0

func _update_restart(delta: float) -> void:
	var alpha: float = clampf(_state_time / maxf(0.01, restart_duration), 0.0, 1.0)
	var eased: float = _ease_in_out(alpha)
	var target_restart: Transform3D = _car_stop_end.translated_local(Vector3(0.0, 0.0, -1.4))
	_car.global_transform = _car_stop_end.interpolate_with(target_restart, eased)

	var crank: float = sin(_state_time * 18.0) * (1.0 - alpha)
	var pitch: float = deg_to_rad(-3.0 + crank * 1.6)
	var roll: float = deg_to_rad(crank * 0.9)
	var offset: Vector3 = Vector3(crank * 0.002, -0.015 + absf(crank) * 0.002, 0.01)
	_snap_player_to_seat(pitch, roll, offset)
	_update_cinematic_camera(delta, 0.0)

	if alpha >= 1.0:
		_player.call("place_player", _exit_marker.global_transform)
		_player.call("reset_head_camera_pose")
		_set_first_person_camera_active(true)
		_player.call("lock_controls", false)
		if _player.has_method("unlock_night_vision_controls"):
			_player.call("unlock_night_vision_controls", true)
		_set_objective("Motor calisti. Hazirsan yola devam et.")
		_state = SequenceState.GAMEPLAY
		_state_time = 0.0

func _snap_player_to_seat(pitch: float, roll: float, camera_offset: Vector3) -> void:
	_player.call("place_player", _seat_marker.global_transform)
	_player.call("set_head_camera_pose", pitch, roll, camera_offset)

func _setup_intro_camera() -> void:
	if not third_person_camera_enabled:
		_set_first_person_camera_active(true)
		return

	_cinematic_camera = Camera3D.new()
	_cinematic_camera.name = "CinematicCamera"
	_cinematic_camera.fov = third_person_fov
	_cinematic_camera.near = 0.03
	_cinematic_camera.current = true
	add_child(_cinematic_camera)

	_set_first_person_camera_active(false)
	_camera_anchor_ready = false
	_update_cinematic_camera(0.0, 0.0)

func _disable_intro_camera() -> void:
	if is_instance_valid(_cinematic_camera):
		_cinematic_camera.current = false
		_cinematic_camera.queue_free()
	_cinematic_camera = null
	_camera_anchor_ready = false

func _set_first_person_camera_active(active: bool) -> void:
	if _player != null and _player.has_method("set_first_person_active"):
		_player.call("set_first_person_active", active)
	elif _player_camera != null:
		_player_camera.current = active

func _update_cinematic_camera(delta: float, shake_amount: float) -> void:
	if _cinematic_camera == null or _car == null:
		return

	var car_xf: Transform3D = _car.global_transform
	var desired_position: Vector3 = car_xf.origin
	desired_position += car_xf.basis.z * third_person_distance
	desired_position += car_xf.basis.x * third_person_side_offset
	desired_position += Vector3.UP * third_person_height

	if not _camera_anchor_ready:
		_camera_anchor = desired_position
		_camera_anchor_ready = true
	else:
		var follow_alpha: float = minf(1.0, delta * third_person_follow_lerp)
		_camera_anchor = _camera_anchor.lerp(desired_position, follow_alpha)

	var speed_mps: float = 0.0
	if delta > 0.0001:
		speed_mps = _car.global_position.distance_to(_previous_car_position) / delta
	_previous_car_position = _car.global_position

	var shake_scale: float = clampf(speed_mps / 8.0, 0.25, 1.0)
	var shake: Vector3 = Vector3(
		sin(_state_time * 15.0) * shake_amount * 0.35 * shake_scale,
		sin(_state_time * 28.0) * shake_amount * 0.2 * shake_scale,
		cos(_state_time * 19.0) * shake_amount * 0.35 * shake_scale
	)
	_cinematic_camera.global_position = _camera_anchor + shake

	var look_target: Vector3 = car_xf.origin + Vector3.UP * third_person_look_height - car_xf.basis.z * 1.2
	_cinematic_camera.look_at(look_target, Vector3.UP)

	var target_fov: float = third_person_fov + clampf(speed_mps * 0.45, 0.0, 4.0)
	_cinematic_camera.fov = lerpf(_cinematic_camera.fov, target_fov, minf(1.0, delta * 4.0))

func _create_objective_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 40
	add_child(_ui_layer)

	_objective_bg = ColorRect.new()
	_objective_bg.position = Vector2(24.0, 24.0)
	_objective_bg.size = Vector2(620.0, 64.0)
	_objective_bg.color = Color(0.02, 0.03, 0.04, 0.72)
	_objective_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_objective_bg)

	_objective_label = Label.new()
	_objective_label.position = Vector2(16.0, 16.0)
	_objective_label.size = Vector2(586.0, 38.0)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.95, 1.0))
	_objective_label.add_theme_font_size_override("font_size", 18)
	_objective_bg.add_child(_objective_label)

func _set_objective(text: String) -> void:
	if is_instance_valid(_objective_label):
		_objective_label.text = text
		_objective_bg.visible = text != ""

func _ease_in_out(x: float) -> float:
	var t: float = clampf(x, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
