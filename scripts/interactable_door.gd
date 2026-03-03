extends Node3D
class_name InteractableDoor

const ACTION_TOGGLE_DOOR: StringName = &"toggle_door"
const GROUP_INTERACTABLE_DOORS: StringName = &"interactable_door"
const GROUP_PLAYERS: StringName = &"player"
const DOOR_BODY_PATH: NodePath = NodePath("DoorBody")
const DOOR_COLLISION_PATH: NodePath = NodePath("DoorBody/CollisionShape3D")

@export var interaction_distance: float = 2.4
@export var open_angle_deg: float = 118.0
@export var open_duration: float = 0.62
@export var open_direction: float = -1.0
@export var auto_open_away_from_player: bool = true
@export var require_facing_door: bool = true
@export var facing_dot_threshold: float = 0.05
@export var toggle_cooldown_sec: float = 0.18
@export var starts_locked: bool = false
@export var locked_prompt: String = "Kilitli. Mezar sembollerini cozmeyi dene."
@export var open_prompt: String = "Kapiyi acmak icin P'ye basin"
@export var close_prompt: String = "Kapiyi kapatmak icin P'ye basin"
@export var handle_path: NodePath = NodePath("DoorBody/HandlePivot")
@export var handle_press_angle_deg: float = 24.0
@export var handle_press_duration: float = 0.08
@export var squeak_volume_db: float = -13.0
@export var squeak_max_distance: float = 11.0
@export var squeak_pitch_min: float = 0.93
@export var squeak_pitch_max: float = 1.08

var _is_open: bool = false
var _closed_y: float = 0.0
var _open_y: float = 0.0
var _anim_tween: Tween
var _handle_tween: Tween
var _player: Node3D
var _handle_pivot: Node3D
var _handle_rest_rotation: Vector3 = Vector3.ZERO
var _squeak_player: AudioStreamPlayer3D
var _door_collision_shape: CollisionShape3D
var _door_body: CollisionObject3D
var _door_body_layer: int = 0
var _door_body_mask: int = 0
var _door_body_layers_cached: bool = false
var _locked: bool = false
var _last_toggle_msec: int = -999999

func _ready() -> void:
	_ensure_input_action()
	add_to_group(GROUP_INTERACTABLE_DOORS)
	_closed_y = rotation.y
	_open_y = _closed_y + deg_to_rad(open_angle_deg) * open_direction
	_locked = starts_locked
	_player = _find_player()
	_cache_nodes()
	if _handle_pivot != null:
		_handle_rest_rotation = _handle_pivot.rotation
	_set_door_collision_enabled(true)
	_build_squeak_player()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.echo:
			return
	if not event.is_action_pressed(ACTION_TOGGLE_DOOR):
		return
	var now_msec: int = Time.get_ticks_msec()
	if _is_toggle_cooldown_active(now_msec):
		return
	if not _can_interact():
		return
	if not _is_nearest_door():
		return
	_last_toggle_msec = now_msec
	_toggle()

func _can_interact() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			return false
	return can_player_interact(_player)

func _is_nearest_door() -> bool:
	if _player == null:
		return false

	var player_pos: Vector3 = _player.global_position
	var nearest: InteractableDoor = null
	var nearest_dist_sq: float = INF
	var door_nodes: Array[Node] = get_tree().get_nodes_in_group(GROUP_INTERACTABLE_DOORS)

	for i in range(door_nodes.size()):
		var other: InteractableDoor = door_nodes[i] as InteractableDoor
		if other == null:
			continue
		if not other.can_player_interact(_player):
			continue
		var dist_sq: float = player_pos.distance_squared_to(other.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = other

	return nearest == self

func _is_toggle_cooldown_active(now_msec: int) -> bool:
	var min_gap_msec: int = int(toggle_cooldown_sec * 1000.0)
	return now_msec - _last_toggle_msec < min_gap_msec

func _toggle() -> void:
	if _locked:
		_play_squeak()
		return

	_cache_nodes()
	if not _is_open and auto_open_away_from_player:
		_adjust_open_direction_from_player()
	if not _is_open:
		_set_door_collision_enabled(false)

	_is_open = not _is_open
	var target_y: float = _open_y if _is_open else _closed_y
	var enable_collision_on_finish: bool = not _is_open
	_play_squeak()
	_animate_handle()
	_animate_rotation(target_y, enable_collision_on_finish)

func _adjust_open_direction_from_player() -> void:
	if _player == null:
		return
	var local_player: Vector3 = to_local(_player.global_position)
	open_direction = -1.0 if local_player.x >= 0.0 else 1.0
	_open_y = _closed_y + deg_to_rad(open_angle_deg) * open_direction

func _animate_rotation(target_y: float, enable_collision_on_finish: bool) -> void:
	if _anim_tween != null and _anim_tween.is_running():
		_anim_tween.kill()

	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_SINE)
	_anim_tween.set_ease(Tween.EASE_IN_OUT)
	_anim_tween.tween_property(self, "rotation:y", target_y, open_duration)
	if enable_collision_on_finish:
		_anim_tween.tween_callback(_set_door_collision_enabled.bind(true))

func _animate_handle() -> void:
	if _handle_pivot == null:
		return
	if _handle_tween != null and _handle_tween.is_running():
		_handle_tween.kill()

	var pressed_rotation: Vector3 = _handle_rest_rotation + Vector3(0.0, 0.0, deg_to_rad(-handle_press_angle_deg))
	_handle_tween = create_tween()
	_handle_tween.set_trans(Tween.TRANS_SINE)
	_handle_tween.set_ease(Tween.EASE_OUT)
	_handle_tween.tween_property(_handle_pivot, "rotation", pressed_rotation, handle_press_duration)
	_handle_tween.set_ease(Tween.EASE_IN)
	_handle_tween.tween_property(_handle_pivot, "rotation", _handle_rest_rotation, handle_press_duration * 1.2)

func _find_player() -> Node3D:
	var players: Array[Node] = get_tree().get_nodes_in_group(GROUP_PLAYERS)
	if players.is_empty():
		return null
	return players[0] as Node3D

func _ensure_input_action() -> void:
	if not InputMap.has_action(ACTION_TOGGLE_DOOR):
		InputMap.add_action(ACTION_TOGGLE_DOOR)
	if InputMap.action_get_events(ACTION_TOGGLE_DOOR).is_empty():
		var key_event: InputEventKey = InputEventKey.new()
		key_event.physical_keycode = KEY_P
		InputMap.action_add_event(ACTION_TOGGLE_DOOR, key_event)

func _build_squeak_player() -> void:
	if _squeak_player != null and is_instance_valid(_squeak_player):
		return
	_squeak_player = AudioStreamPlayer3D.new()
	_squeak_player.name = "DoorSqueakPlayer"
	_squeak_player.stream = _build_squeak_stream()
	_squeak_player.volume_db = squeak_volume_db
	_squeak_player.max_distance = squeak_max_distance
	_squeak_player.unit_size = 1.0
	_squeak_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_squeak_player)

func _build_squeak_stream() -> AudioStreamWAV:
	var sample_rate: int = 24000
	var duration: float = 0.34
	var sample_count: int = int(duration * float(sample_rate))
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(sample_count * 2)

	for i in range(sample_count):
		var t: float = float(i) / float(sample_rate)
		var n: float = t / duration
		var freq: float = lerpf(980.0, 330.0, n) + sin(t * 31.0) * 42.0
		var carrier: float = sin((TAU * freq * t) + sin(t * 17.0) * 0.75)
		var rasp: float = sin(TAU * (freq * 2.7) * t) * 0.23
		var envelope: float = pow(maxf(0.0, sin(n * PI)), 1.2)
		var sample: float = (carrier + rasp) * envelope * 0.33

		var q: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		if q < 0:
			q += 65536
		var index: int = i * 2
		pcm[index] = q & 0xFF
		pcm[index + 1] = (q >> 8) & 0xFF

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	wav.data = pcm
	return wav

func _play_squeak() -> void:
	if _squeak_player == null:
		return
	_squeak_player.pitch_scale = randf_range(squeak_pitch_min, squeak_pitch_max)
	_squeak_player.play()

func _set_door_collision_enabled(enabled: bool) -> void:
	_cache_nodes()
	if _door_collision_shape != null:
		_door_collision_shape.set_deferred("disabled", not enabled)
	if _door_body != null:
		if not enabled:
			_door_body.collision_layer = 0
			_door_body.collision_mask = 0
		elif _door_body_layers_cached:
			_door_body.collision_layer = _door_body_layer
			_door_body.collision_mask = _door_body_mask

func is_open() -> bool:
	return _is_open

func is_locked() -> bool:
	return _locked

func set_locked(value: bool) -> void:
	_locked = value

func get_prompt_text() -> String:
	if _locked:
		return locked_prompt
	if _is_open:
		return close_prompt
	return open_prompt

func can_player_interact(player_node: Node3D) -> bool:
	if player_node == null:
		return false
	var player_pos: Vector3 = player_node.global_position
	if player_pos.distance_to(global_position) > interaction_distance:
		return false

	if not require_facing_door:
		return true
	var to_door: Vector3 = (global_position - player_pos).normalized()
	var player_forward: Vector3 = -player_node.global_transform.basis.z.normalized()
	return player_forward.dot(to_door) >= facing_dot_threshold

func _cache_nodes() -> void:
	if _handle_pivot == null:
		_handle_pivot = get_node_or_null(handle_path) as Node3D
	if _door_collision_shape == null:
		_door_collision_shape = get_node_or_null(DOOR_COLLISION_PATH) as CollisionShape3D
	if _door_body == null:
		_door_body = get_node_or_null(DOOR_BODY_PATH) as CollisionObject3D
	if _door_body != null and not _door_body_layers_cached:
		_door_body_layer = _door_body.collision_layer
		_door_body_mask = _door_body.collision_mask
		_door_body_layers_cached = true
