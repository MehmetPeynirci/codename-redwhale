extends Node

const CANDLE_CORRECT_SET: Array[int] = [0, 2, 3]

enum StoryStage {
	WAIT_INTRO,
	CHECK_AREA,
	FIND_NOTEBOOK,
	FIND_KEY,
	GRAVE_PUZZLE,
	ENTER_STONE_HOUSE,
	CANDLE_RITUAL,
	COMPLETE
}

@export var player_path: NodePath = NodePath("../Player")
@export var car_path: NodePath = NodePath("../CrashCar")
@export var village_path: NodePath = NodePath("../Village")
@export var crash_sequence_path: NodePath = NodePath("../CrashSequence")
@export var interact_distance: float = 2.5

var _player: CharacterBody3D
var _car: Node3D
var _village: Node3D
var _crash_sequence: Node

var _stage: int = StoryStage.WAIT_INTRO

var _objective_layer: CanvasLayer
var _objective_bg: ColorRect
var _objective_label: Label
var _detail_label: Label
var _hint_bg: ColorRect
var _hint_label: Label

var _trunk_area: Area3D
var _notebook_area: Area3D
var _key_area: Area3D

var _bush_areas: Array[Area3D] = []
var _grave_areas: Array[Area3D] = []
var _candle_areas: Array[Area3D] = []
var _entry_areas: Array[Area3D] = []
var _locked_door: Node3D

var _trunk_checked: bool = false
var _bushes_examined: int = 0
var _notebook_found: bool = false
var _key_found: bool = false
var _grave_progress: int = 0

var _jumpscare_started: bool = false
var _jumpscare_completed: bool = false
var _figure_node: MeshInstance3D

func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody3D
	_car = get_node_or_null(car_path) as Node3D
	_village = get_node_or_null(village_path) as Node3D
	_crash_sequence = get_node_or_null(crash_sequence_path)

	if _player == null or _car == null or _village == null:
		push_warning("Horror director requirements missing; disabling story layer.")
		set_process(false)
		return

	_build_objective_ui()
	_build_car_story_points()
	_cache_story_nodes()
	_assign_key_bush()
	_set_area_visible(_notebook_area, false)
	_set_area_visible(_key_area, false)
	_set_objective("", "")

func _process(_delta: float) -> void:
	_update_stage_flow()
	_update_interaction_hint()

	if Input.is_action_just_pressed("interact"):
		_try_interact()

func _update_stage_flow() -> void:
	if _stage == StoryStage.WAIT_INTRO:
		if _is_player_controls_locked():
			return
		_stage = StoryStage.CHECK_AREA
		_set_objective("Aractan in ve cevreyi kontrol et.", "Bagaji incele, en az 2 caliyi arastir.")
		return

	if _stage == StoryStage.CHECK_AREA:
		if _trunk_checked and _bushes_examined >= 2:
			_stage = StoryStage.FIND_NOTEBOOK
			_set_area_visible(_notebook_area, true)
			_set_objective("Bagajdaki not defterini bul.", "E ile notu topla.")
		return

	if _stage == StoryStage.ENTER_STONE_HOUSE:
		if _is_inside_entry_area():
			_stage = StoryStage.CANDLE_RITUAL
			_set_objective("Ritueli boz.", "4 mumdan sadece 3'unu dogru kombinasyonda yak.")
		return

func _try_interact() -> void:
	if _stage == StoryStage.CHECK_AREA:
		if _is_area_near_player(_trunk_area):
			_set_car_trunk_open(true)
			if not _trunk_checked:
				_trunk_checked = true
				_set_objective("Bagaj kontrol edildi.", "Simdi cevredeki calilari arastir.")
			return
		var bush: Area3D = _nearest_area(_bush_areas)
		if bush != null:
			_interact_bush(bush)
		return

	if _stage == StoryStage.FIND_NOTEBOOK:
		if _is_area_near_player(_notebook_area):
			_notebook_found = true
			_set_area_visible(_notebook_area, false)
			_stage = StoryStage.FIND_KEY
			_set_objective("Notta yazan semboller mezarligi isaret ediyor.", "Calilarda dusmus anahtari bul.")
		return

	if _stage == StoryStage.FIND_KEY:
		if _is_area_near_player(_key_area):
			_key_found = true
			_set_area_visible(_key_area, false)
			_stage = StoryStage.GRAVE_PUZZLE
			_set_objective("Mezarlik bulmacasi", "Taslari en eski tarihten en yeniye dogru sec.")
		return

	if _stage == StoryStage.GRAVE_PUZZLE:
		var grave: Area3D = _nearest_area(_grave_areas)
		if grave != null:
			_interact_grave(grave)
		return

	if _stage == StoryStage.CANDLE_RITUAL:
		var candle: Area3D = _nearest_area(_candle_areas)
		if candle != null:
			_toggle_candle(candle)
			_validate_candle_solution()
		return

func _interact_bush(bush: Area3D) -> void:
	var searched_variant: Variant = bush.get_meta("searched", false)
	var searched: bool = bool(searched_variant)
	if searched:
		return

	bush.set_meta("searched", true)
	_bushes_examined += 1
	_animate_bush(bush)

	var key_holder_variant: Variant = bush.get_meta("contains_key", false)
	var contains_key: bool = bool(key_holder_variant)
	if contains_key:
		_key_area.global_position = bush.global_position + Vector3(0.35, 0.25, 0.15)
		_set_area_visible(_key_area, true)

func _interact_grave(grave: Area3D) -> void:
	var order_variant: Variant = grave.get_meta("order_index", -1)
	var order_index: int = int(order_variant)
	if order_index == _grave_progress:
		_grave_progress += 1
		_highlight_grave(grave, true)
		_set_objective("Dogru sembol secimi", "Ilerleme: %d / 3" % _grave_progress)
		if _grave_progress >= 3:
			_unlock_stone_house()
	else:
		_grave_progress = 0
		_reset_grave_visuals()
		_set_objective("Yanlis siralama", "Tarihleri tekrar kontrol et: en eski -> en yeni")

func _unlock_stone_house() -> void:
	if _locked_door != null and _locked_door.has_method("set_locked"):
		_locked_door.call("set_locked", false)
	_stage = StoryStage.ENTER_STONE_HOUSE
	_set_objective("Tas evin kilidi acildi.", "Kapiyi P ile acip iceri gir.")

func _toggle_candle(candle: Area3D) -> void:
	var lit_variant: Variant = candle.get_meta("lit", false)
	var lit: bool = bool(lit_variant)
	lit = not lit
	candle.set_meta("lit", lit)

	var flame: OmniLight3D = candle.get_node_or_null("FlameLight") as OmniLight3D
	if flame != null:
		flame.visible = lit
		flame.light_energy = 1.35 if lit else 0.0

func _validate_candle_solution() -> void:
	var lit_ids: PackedInt32Array = PackedInt32Array()
	for i in range(_candle_areas.size()):
		var candle: Area3D = _candle_areas[i]
		var lit_variant: Variant = candle.get_meta("lit", false)
		if bool(lit_variant):
			var idx_variant: Variant = candle.get_meta("candle_index", i)
			lit_ids.append(int(idx_variant))

	if lit_ids.size() < 3:
		_set_objective("Rituel devam ediyor.", "Dogru 3 mumu yakman gerekiyor.")
		return
	if lit_ids.size() > 3:
		_set_objective("Fazla mum yandi.", "Sadece 3 mum yanik kalmali.")
		return

	lit_ids.sort()
	var solved: bool = true
	for i in range(CANDLE_CORRECT_SET.size()):
		if lit_ids[i] != CANDLE_CORRECT_SET[i]:
			solved = false
			break

	if solved:
		_stage = StoryStage.COMPLETE
		_set_objective("Buyu bozuldu... ama bir sey degisti.", "Sessiz kal ve arkani kontrol etme.")
		if not _jumpscare_started:
			_jumpscare_started = true
			call_deferred("_run_psychological_jumpscare")
	else:
		_set_objective("Yanlis mum kombinasyonu.", "Duvar ipuclarina gore 3 dogru mumu sec.")

func _run_psychological_jumpscare() -> void:
	if _jumpscare_completed:
		return
	if _player != null and _player.has_method("lock_controls"):
		_player.call("lock_controls", true)
	_set_objective("Arkadaki nefes sesini duydun.", "Sakin ol...")
	await get_tree().create_timer(1.35).timeout
	if _player != null and _player.has_method("lock_controls"):
		_player.call("lock_controls", false)

	_show_far_figure(true)
	await get_tree().create_timer(2.1).timeout
	_show_far_figure(false)
	_set_objective("Figur kayboldu.", "Koy daha da tehlikeli hale geldi.")
	_jumpscare_completed = true

func _show_far_figure(visible_now: bool) -> void:
	if _figure_node == null:
		_figure_node = MeshInstance3D.new()
		_figure_node.name = "FarFigure"
		var capsule: CapsuleMesh = CapsuleMesh.new()
		capsule.radius = 0.28
		capsule.mid_height = 1.4
		_figure_node.mesh = capsule
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.03, 0.03, 0.03, 0.95)
		mat.roughness = 0.98
		_figure_node.material_override = mat
		var fx: float = -27.5
		var fz: float = 5.8
		var fy: float = 0.8
		if _village != null and _village.has_method("_sample_terrain_height"):
			fy = float(_village.call("_sample_terrain_height", fx, fz)) + 0.86
		_figure_node.position = Vector3(fx, fy, fz)
		add_child(_figure_node)

	_figure_node.visible = visible_now

func _cache_story_nodes() -> void:
	_bush_areas = _collect_group_areas("story_bush")
	_grave_areas = _collect_group_areas("story_grave_symbol")
	_candle_areas = _collect_group_areas("story_candle")
	_entry_areas = _collect_group_areas("story_magic_house_entry")

	var doors: Array[Node] = get_tree().get_nodes_in_group("story_locked_door")
	if not doors.is_empty():
		_locked_door = doors[0] as Node3D

func _assign_key_bush() -> void:
	if _bush_areas.is_empty():
		return
	var idx: int = int(randi() % _bush_areas.size())
	for i in range(_bush_areas.size()):
		_bush_areas[i].set_meta("contains_key", i == idx)

func _collect_group_areas(group_name: StringName) -> Array[Area3D]:
	var out: Array[Area3D] = []
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	for i in range(nodes.size()):
		var area: Area3D = nodes[i] as Area3D
		if area != null:
			out.append(area)
	return out

func _build_car_story_points() -> void:
	_trunk_area = _create_car_interact_area("StoryTrunkArea", Vector3(0.0, 0.88, 2.05), 1.05)
	_notebook_area = _create_car_interact_area("StoryNotebookArea", Vector3(-0.42, 0.94, 2.12), 0.56)
	_key_area = _create_car_interact_area("StoryKeyArea", Vector3(0.38, 0.35, 2.22), 0.42)

	var notebook_mesh: MeshInstance3D = MeshInstance3D.new()
	var notebook_box: BoxMesh = BoxMesh.new()
	notebook_box.size = Vector3(0.24, 0.03, 0.18)
	notebook_mesh.mesh = notebook_box
	var note_mat: StandardMaterial3D = StandardMaterial3D.new()
	note_mat.albedo_color = Color(0.22, 0.18, 0.14, 1.0)
	notebook_mesh.material_override = note_mat
	notebook_mesh.position = Vector3.ZERO
	_notebook_area.add_child(notebook_mesh)

	var key_mesh: MeshInstance3D = MeshInstance3D.new()
	var key_box: BoxMesh = BoxMesh.new()
	key_box.size = Vector3(0.12, 0.02, 0.04)
	key_mesh.mesh = key_box
	var key_mat: StandardMaterial3D = StandardMaterial3D.new()
	key_mat.albedo_color = Color(0.7, 0.56, 0.2, 1.0)
	key_mat.metallic = 0.62
	key_mat.roughness = 0.35
	key_mesh.material_override = key_mat
	_key_area.add_child(key_mesh)

func _create_car_interact_area(node_name: String, local_pos: Vector3, radius: float) -> Area3D:
	var area: Area3D = Area3D.new()
	area.name = node_name
	area.position = local_pos
	_car.add_child(area)

	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	shape_node.shape = sphere
	area.add_child(shape_node)
	return area

func _animate_bush(bush: Area3D) -> void:
	var tween: Tween = create_tween()
	var initial_rot: Vector3 = bush.rotation
	var kick: Vector3 = initial_rot + Vector3(0.07, 0.0, -0.11)
	tween.tween_property(bush, "rotation", kick, 0.11)
	tween.tween_property(bush, "rotation", initial_rot, 0.22)

func _is_player_controls_locked() -> bool:
	if _player == null:
		return true
	if _player.has_method("controls_locked"):
		return bool(_player.call("controls_locked"))
	return false

func _is_inside_entry_area() -> bool:
	for i in range(_entry_areas.size()):
		if _is_area_near_player(_entry_areas[i], 1.8):
			return true
	return false

func _nearest_area(areas: Array[Area3D], max_distance: float = -1.0) -> Area3D:
	if _player == null:
		return null
	var limit: float = interact_distance if max_distance < 0.0 else max_distance
	var nearest: Area3D = null
	var nearest_sq: float = limit * limit
	for i in range(areas.size()):
		var area: Area3D = areas[i]
		if area == null or not area.visible:
			continue
		var dist_sq: float = _player.global_position.distance_squared_to(area.global_position)
		if dist_sq <= nearest_sq:
			nearest_sq = dist_sq
			nearest = area
	return nearest

func _is_area_near_player(area: Area3D, distance: float = -1.0) -> bool:
	if area == null or _player == null or not area.visible:
		return false
	var limit: float = interact_distance if distance < 0.0 else distance
	return _player.global_position.distance_to(area.global_position) <= limit

func _reset_grave_visuals() -> void:
	for i in range(_grave_areas.size()):
		_highlight_grave(_grave_areas[i], false)

func _highlight_grave(grave: Area3D, highlighted: bool) -> void:
	if grave == null:
		return
	var label: Label3D = grave.get_node_or_null("Label3D") as Label3D
	if label != null:
		label.modulate = Color(0.42, 0.94, 0.58, 0.95) if highlighted else Color(0.88, 0.9, 0.86, 0.96)

func _set_area_visible(area: Area3D, value: bool) -> void:
	if area == null:
		return
	area.visible = value
	area.monitoring = value
	area.monitorable = value

func _build_objective_ui() -> void:
	_objective_layer = CanvasLayer.new()
	_objective_layer.layer = 46
	add_child(_objective_layer)

	_objective_bg = ColorRect.new()
	_objective_bg.position = Vector2(24.0, 96.0)
	_objective_bg.size = Vector2(650.0, 92.0)
	_objective_bg.color = Color(0.02, 0.03, 0.04, 0.72)
	_objective_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_layer.add_child(_objective_bg)

	_objective_label = Label.new()
	_objective_label.position = Vector2(14.0, 12.0)
	_objective_label.size = Vector2(620.0, 30.0)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.95, 1.0))
	_objective_label.add_theme_font_size_override("font_size", 20)
	_objective_bg.add_child(_objective_label)

	_detail_label = Label.new()
	_detail_label.position = Vector2(14.0, 46.0)
	_detail_label.size = Vector2(620.0, 36.0)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.86, 0.92))
	_detail_label.add_theme_font_size_override("font_size", 16)
	_objective_bg.add_child(_detail_label)

	_hint_bg = ColorRect.new()
	_hint_bg.anchor_left = 0.5
	_hint_bg.anchor_top = 1.0
	_hint_bg.anchor_right = 0.5
	_hint_bg.anchor_bottom = 1.0
	_hint_bg.offset_left = -220.0
	_hint_bg.offset_top = -134.0
	_hint_bg.offset_right = 220.0
	_hint_bg.offset_bottom = -98.0
	_hint_bg.color = Color(0.02, 0.03, 0.04, 0.68)
	_hint_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_bg.visible = false
	_objective_layer.add_child(_hint_bg)

	_hint_label = Label.new()
	_hint_label.anchor_left = 0.0
	_hint_label.anchor_top = 0.0
	_hint_label.anchor_right = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color(0.91, 0.93, 0.95, 1.0))
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_bg.add_child(_hint_label)

func _set_objective(main_text: String, detail_text: String) -> void:
	if _objective_label != null:
		_objective_label.text = main_text
	if _detail_label != null:
		_detail_label.text = detail_text
	if _objective_bg != null:
		_objective_bg.visible = main_text != "" or detail_text != ""

func _set_car_trunk_open(opened: bool) -> void:
	if _car == null:
		return
	if _car.has_method("set_trunk_open"):
		_car.call("set_trunk_open", opened)

func _update_interaction_hint() -> void:
	if _hint_bg == null or _hint_label == null:
		return
	var hint: String = ""

	if _stage == StoryStage.CHECK_AREA:
		if _is_area_near_player(_trunk_area):
			hint = "Bagaji ac ve kontrol et (E)"
		elif _nearest_area(_bush_areas) != null:
			hint = "Caliyi incele (E)"
	elif _stage == StoryStage.FIND_NOTEBOOK and _is_area_near_player(_notebook_area):
		hint = "Not defterini al (E)"
	elif _stage == StoryStage.FIND_KEY and _is_area_near_player(_key_area):
		hint = "Anahtari al (E)"
	elif _stage == StoryStage.GRAVE_PUZZLE and _nearest_area(_grave_areas) != null:
		hint = "Mezar tasini incele (E)"
	elif _stage == StoryStage.CANDLE_RITUAL and _nearest_area(_candle_areas) != null:
		hint = "Mumu ac/kapat (E)"

	_hint_label.text = hint
	_hint_bg.visible = hint != ""
