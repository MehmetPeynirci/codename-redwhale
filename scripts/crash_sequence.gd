extends Node3D

@export var player_path: NodePath
@export var car_path: NodePath
@export var seat_marker_path: NodePath
@export var exit_marker_path: NodePath

@export var drive_duration: float = 2.6
@export var impact_duration: float = 0.45
@export var recover_duration: float = 1.4
@export var crash_distance: float = 18.0
@export var injury_duration: float = 15.0

var _player: CharacterBody3D
var _car: Node3D
var _seat_marker: Marker3D
var _exit_marker: Marker3D
var _state_time: float = 0.0
var _state: int = 0

var _car_start: Transform3D
var _car_target: Transform3D

func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody3D
	_car = get_node_or_null(car_path) as Node3D
	_seat_marker = get_node_or_null(seat_marker_path) as Marker3D
	_exit_marker = get_node_or_null(exit_marker_path) as Marker3D

	if _player == null or _car == null or _seat_marker == null or _exit_marker == null:
		push_warning("Crash sequence nodes are missing; skipping crash intro.")
		set_process(false)
		return

	_car_start = _car.global_transform
	_car_target = _car_start.translated_local(Vector3(0.0, 0.0, -crash_distance))

	_player.call("lock_controls", true)
	_snap_player_to_seat(deg_to_rad(-4.0), deg_to_rad(1.0), Vector3(0.01, -0.02, 0.02))

func _process(delta: float) -> void:
	_state_time += delta

	if _state == 0:
		_update_drive()
		return
	if _state == 1:
		_update_impact()
		return
	if _state == 2:
		_update_recover()
		return

func _update_drive() -> void:
	var alpha: float = clampf(_state_time / maxf(0.01, drive_duration), 0.0, 1.0)
	var eased: float = _ease_in_out(alpha)
	_car.global_transform = _car_start.interpolate_with(_car_target, eased)

	var road_vibration: float = sin(_state_time * 14.0) * 0.01
	var pitch: float = deg_to_rad(-4.0 + road_vibration * 35.0)
	var roll: float = deg_to_rad(road_vibration * 20.0)
	var offset: Vector3 = Vector3(0.01, -0.02 + road_vibration, 0.02)
	_snap_player_to_seat(pitch, roll, offset)

	if alpha >= 1.0:
		_state = 1
		_state_time = 0.0

func _update_impact() -> void:
	_car.global_transform = _car_target

	var t: float = clampf(_state_time / maxf(0.01, impact_duration), 0.0, 1.0)
	var shock: float = 1.0 - t
	var jitter_x: float = sin(_state_time * 95.0) * 0.02 * shock
	var jitter_y: float = absf(sin(_state_time * 73.0)) * 0.02 * shock

	var pitch: float = deg_to_rad(-16.0 + sin(_state_time * 48.0) * 2.3)
	var roll: float = deg_to_rad(sin(_state_time * 62.0) * 3.0)
	var offset: Vector3 = Vector3(jitter_x, -0.05 + jitter_y, 0.04)
	_snap_player_to_seat(pitch, roll, offset)

	if t >= 1.0:
		_state = 2
		_state_time = 0.0

func _update_recover() -> void:
	_car.global_transform = _car_target

	var alpha: float = clampf(_state_time / maxf(0.01, recover_duration), 0.0, 1.0)
	var eased: float = _ease_in_out(alpha)

	var pitch: float = lerpf(deg_to_rad(-12.0), deg_to_rad(-2.0), eased)
	var roll: float = lerpf(deg_to_rad(2.5), 0.0, eased)
	var offset: Vector3 = Vector3(0.0, lerpf(-0.03, 0.0, eased), lerpf(0.03, 0.0, eased))
	_snap_player_to_seat(pitch, roll, offset)

	if alpha >= 1.0:
		_finish_sequence()

func _finish_sequence() -> void:
	_car.global_transform = _car_target
	_player.call("place_player", _exit_marker.global_transform)
	_player.call("reset_head_camera_pose")
	_player.call("lock_controls", false)
	_player.call("start_injury", injury_duration)

	_state = 3
	set_process(false)

func _snap_player_to_seat(pitch: float, roll: float, camera_offset: Vector3) -> void:
	_player.call("place_player", _seat_marker.global_transform)
	_player.call("set_head_camera_pose", pitch, roll, camera_offset)

func _ease_in_out(x: float) -> float:
	var t: float = clampf(x, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
