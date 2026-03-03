extends Node

const INTRO_CARDS: Array[String] = [
	"CINNET 2",
	"Audio\nResit Gozdamla",
	"Developers & Redwhale Owners",
	"Ali Yabuz\n(Project Management)",
	"Mehmet Peynirci\n(Game Development Team)"
]

@export var fade_in_duration: float = 0.42
@export var hold_duration: float = 0.85
@export var fade_out_duration: float = 0.38
@export var card_gap_duration: float = 0.06
@export var intro_speed_multiplier: float = 1.3
@export var overlay_color: Color = Color(0.0, 0.0, 0.0, 0.95)
@export var music_volume_db: float = -15.0
@export var allow_skip: bool = true

var _layer: CanvasLayer
var _background: ColorRect
var _label: Label
var _hint: Label
var _music_player: AudioStreamPlayer
var _intro_tween: Tween
var _is_finishing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	process_priority = 100
	_build_ui()
	_build_music()
	_pause_world()
	_play_sequence()

func _unhandled_input(event: InputEvent) -> void:
	if not allow_skip or _is_finishing:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_finish_intro()

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 95
	_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(_layer)

	_background = ColorRect.new()
	_background.anchor_left = 0.0
	_background.anchor_top = 0.0
	_background.anchor_right = 1.0
	_background.anchor_bottom = 1.0
	_background.offset_left = 0.0
	_background.offset_top = 0.0
	_background.offset_right = 0.0
	_background.offset_bottom = 0.0
	_background.color = overlay_color
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_background)

	_label = Label.new()
	_label.anchor_left = 0.5
	_label.anchor_top = 0.5
	_label.anchor_right = 0.5
	_label.anchor_bottom = 0.5
	_label.offset_left = -520.0
	_label.offset_top = -92.0
	_label.offset_right = 520.0
	_label.offset_bottom = 92.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 44)
	_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.89, 1.0))
	_label.modulate.a = 0.0
	_background.add_child(_label)

	_hint = Label.new()
	_hint.anchor_left = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_right = 0.5
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -220.0
	_hint.offset_top = -48.0
	_hint.offset_right = 220.0
	_hint.offset_bottom = -20.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.text = "Enter / ESC to skip"
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.75, 0.72, 0.68, 0.92))
	_background.add_child(_hint)

func _build_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "IntroMusicPlayer"
	_music_player.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_music_player.volume_db = music_volume_db
	_music_player.stream = _build_intro_music_stream()
	add_child(_music_player)
	_music_player.play()

func _pause_world() -> void:
	get_tree().paused = true

func _play_sequence() -> void:
	var speed_scale: float = maxf(0.35, intro_speed_multiplier)
	var fade_in: float = fade_in_duration / speed_scale
	var hold: float = hold_duration / speed_scale
	var fade_out: float = fade_out_duration / speed_scale
	var gap: float = card_gap_duration / speed_scale

	_intro_tween = create_tween()
	for card in INTRO_CARDS:
		_intro_tween.tween_callback(_set_card_text.bind(card))
		_intro_tween.tween_property(_label, "modulate:a", 1.0, fade_in)
		_intro_tween.tween_interval(hold)
		_intro_tween.tween_property(_label, "modulate:a", 0.0, fade_out)
		_intro_tween.tween_interval(gap)
	_intro_tween.tween_callback(_finish_intro)

func _set_card_text(text: String) -> void:
	if _label != null:
		_label.text = text

func _finish_intro() -> void:
	if _is_finishing:
		return
	_is_finishing = true

	if _intro_tween != null and _intro_tween.is_running():
		_intro_tween.kill()

	var outro_tween: Tween = create_tween()
	outro_tween.tween_property(_label, "modulate:a", 0.0, 0.25)
	outro_tween.parallel().tween_property(_hint, "modulate:a", 0.0, 0.25)
	outro_tween.parallel().tween_property(_background, "color:a", 0.0, 0.55)
	if _music_player != null:
		outro_tween.parallel().tween_property(_music_player, "volume_db", -55.0, 0.65)
	outro_tween.tween_callback(_complete_intro)

func _complete_intro() -> void:
	get_tree().paused = false
	if _music_player != null:
		_music_player.stop()
	if _layer != null:
		_layer.queue_free()
	queue_free()

func _build_intro_music_stream() -> AudioStreamWAV:
	var sample_rate: int = 16000
	var duration: float = 10.0
	var sample_count: int = int(duration * float(sample_rate))
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(sample_count * 2)

	var roots: PackedFloat32Array = PackedFloat32Array([98.0, 110.0, 82.41, 92.5])
	var chord_seconds: float = 2.5

	for i in range(sample_count):
		var t: float = float(i) / float(sample_rate)
		var chord_idx: int = int(floor(t / chord_seconds)) % roots.size()
		var root: float = roots[chord_idx]
		var pad_a: float = sin(TAU * root * t)
		var pad_b: float = sin(TAU * root * 1.5 * t + 0.6)
		var pad_c: float = sin(TAU * root * 2.0 * t + 1.2)
		var pulse: float = 0.58 + 0.42 * sin(TAU * 0.125 * t)
		var shimmer: float = sin(TAU * (36.0 + sin(t * 0.5) * 4.0) * t) * 0.07
		var edge_fade: float = 1.0
		if t < 0.7:
			edge_fade = t / 0.7
		elif t > duration - 0.7:
			edge_fade = maxf(0.0, (duration - t) / 0.7)
		var sample: float = ((pad_a * 0.42) + (pad_b * 0.3) + (pad_c * 0.17)) * pulse
		sample = (sample + shimmer) * 0.23 * edge_fade

		var q: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		if q < 0:
			q += 65536
		var idx: int = i * 2
		pcm[idx] = q & 0xFF
		pcm[idx + 1] = (q >> 8) & 0xFF

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = int(0.6 * sample_rate)
	wav.loop_end = sample_count - 1
	wav.data = pcm
	return wav
