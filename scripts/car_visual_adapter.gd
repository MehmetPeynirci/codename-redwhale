extends Node3D

@export var model_root_path: NodePath = NodePath("ModelPivot")
@export var fallback_visual_path: NodePath = NodePath("FallbackVisual")
@export var collision_shape_path: NodePath = NodePath("CarBody/CollisionShape3D")
@export var model_scene_candidates: PackedStringArray = PackedStringArray([
	"res://small-price-car/source/NEXIA DONE.fbx",
	"res://small-price-car/source/NEXIA DONE.glb",
	"res://small-price-car/source/NEXIA DONE.gltf"
])
@export var target_length: float = 4.6
@export var target_width: float = 1.95
@export var y_rotation_offset_deg: float = 0.0
@export var model_ground_offset: float = -0.06
@export var trunk_hinge_path: NodePath = NodePath("StoryTrunkHinge")
@export var trunk_open_angle_deg: float = 56.0
@export var trunk_open_duration: float = 0.52
@export var driver_door_hinge_path: NodePath = NodePath("FallbackVisual/DriverDoorHinge")
@export var driver_door_open_angle_deg: float = 62.0
@export var driver_door_open_duration: float = 0.4

var _model_root: Node3D
var _fallback_visual: Node3D
var _collision_shape: CollisionShape3D
var _active_model: Node3D
var _trunk_hinge: Node3D
var _trunk_tween: Tween
var _trunk_closed_rotation_x: float = 0.0
var _trunk_open: bool = false
var _driver_door_hinge: Node3D
var _driver_door_tween: Tween
var _driver_door_closed_rotation_y: float = 0.0
var _driver_door_open: bool = false
var _texture_cache: Dictionary = {}
var _missing_texture_files: Dictionary = {}
var _imported_texture_path_cache: Dictionary = {}

func _ready() -> void:
	_model_root = get_node_or_null(model_root_path) as Node3D
	_fallback_visual = get_node_or_null(fallback_visual_path) as Node3D
	_collision_shape = get_node_or_null(collision_shape_path) as CollisionShape3D
	_cache_trunk_hinge()
	_cache_driver_door_hinge()
	if _model_root == null:
		return

	_model_root.rotation_degrees.y = y_rotation_offset_deg
	_active_model = _try_spawn_external_model()

	if _active_model != null:
		if _fallback_visual != null:
			_fallback_visual.visible = false
		_fit_model_to_target()
		_update_collision_shape()
		_apply_texture_materials()
	else:
		if _fallback_visual != null:
			_fallback_visual.visible = true
		_update_collision_shape()

func set_trunk_open(opened: bool) -> void:
	_cache_trunk_hinge()
	if _trunk_hinge == null:
		return

	if _trunk_open == opened and (_trunk_tween == null or not _trunk_tween.is_running()):
		return
	_trunk_open = opened

	if _trunk_tween != null and _trunk_tween.is_running():
		_trunk_tween.kill()

	var target_x: float = _trunk_closed_rotation_x
	if opened:
		target_x += deg_to_rad(-absf(trunk_open_angle_deg))

	_trunk_tween = create_tween()
	_trunk_tween.set_trans(Tween.TRANS_SINE)
	_trunk_tween.set_ease(Tween.EASE_IN_OUT)
	_trunk_tween.tween_property(_trunk_hinge, "rotation:x", target_x, trunk_open_duration)

func toggle_trunk() -> void:
	set_trunk_open(not _trunk_open)

func is_trunk_open() -> bool:
	return _trunk_open

func set_driver_door_open(opened: bool) -> void:
	_cache_driver_door_hinge()
	if _driver_door_hinge == null:
		return

	if _driver_door_open == opened and (_driver_door_tween == null or not _driver_door_tween.is_running()):
		return
	_driver_door_open = opened

	if _driver_door_tween != null and _driver_door_tween.is_running():
		_driver_door_tween.kill()

	var target_y: float = _driver_door_closed_rotation_y
	if opened:
		target_y += deg_to_rad(absf(driver_door_open_angle_deg))

	_driver_door_tween = create_tween()
	_driver_door_tween.set_trans(Tween.TRANS_SINE)
	_driver_door_tween.set_ease(Tween.EASE_IN_OUT)
	_driver_door_tween.tween_property(_driver_door_hinge, "rotation:y", target_y, maxf(0.01, driver_door_open_duration))

func toggle_driver_door() -> void:
	set_driver_door_open(not _driver_door_open)

func is_driver_door_open() -> bool:
	return _driver_door_open

func _cache_trunk_hinge() -> void:
	if _trunk_hinge != null:
		return
	_trunk_hinge = get_node_or_null(trunk_hinge_path) as Node3D
	if _trunk_hinge != null:
		_trunk_closed_rotation_x = _trunk_hinge.rotation.x

func _cache_driver_door_hinge() -> void:
	if _driver_door_hinge != null:
		return
	_driver_door_hinge = get_node_or_null(driver_door_hinge_path) as Node3D
	if _driver_door_hinge != null:
		_driver_door_closed_rotation_y = _driver_door_hinge.rotation.y

func _try_spawn_external_model() -> Node3D:
	var candidate_paths: PackedStringArray = _build_candidate_paths()
	for path_variant in candidate_paths:
		var path: String = str(path_variant)
		if path.strip_edges() == "":
			continue
		if not ResourceLoader.exists(path):
			continue
		var res: Resource = load(path)
		if res == null:
			continue
		var spawned: Node3D = _spawn_from_resource(res)
		if spawned != null:
			_model_root.add_child(spawned)
			return spawned
	return null

func _build_candidate_paths() -> PackedStringArray:
	var ordered: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for raw_path in model_scene_candidates:
		var path: String = str(raw_path)
		if path.strip_edges() == "":
			continue
		if seen.has(path):
			continue
		seen[path] = true
		ordered.append(path)
	return ordered

func _spawn_from_resource(res: Resource) -> Node3D:
	if res is PackedScene:
		var packed: PackedScene = res as PackedScene
		var inst: Node = packed.instantiate()
		var inst3d: Node3D = inst as Node3D
		if inst3d == null:
			inst.queue_free()
			return null
		return inst3d

	if res is Mesh:
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		mesh_instance.mesh = res as Mesh
		return mesh_instance
	return null

func _fit_model_to_target() -> void:
	if _active_model == null:
		return

	var meshes: Array[MeshInstance3D] = _collect_meshes(_active_model)
	var bounds: AABB = _compute_bounds(meshes)
	if bounds.size.length() <= 0.0001:
		return

	var horizontal_span: float = maxf(bounds.size.x, bounds.size.z)
	if horizontal_span <= 0.001:
		return

	var uniform_scale: float = target_length / horizontal_span
	_active_model.scale = Vector3.ONE * uniform_scale

	var scaled_meshes: Array[MeshInstance3D] = _collect_meshes(_active_model)
	var scaled_bounds: AABB = _compute_bounds(scaled_meshes)
	var center_x: float = scaled_bounds.position.x + scaled_bounds.size.x * 0.5
	var center_z: float = scaled_bounds.position.z + scaled_bounds.size.z * 0.5
	var contact_bottom_y: float = _compute_contact_bottom_y(scaled_meshes)
	_active_model.position -= Vector3(center_x, contact_bottom_y, center_z)
	_active_model.position.y += model_ground_offset

func _update_collision_shape() -> void:
	if _collision_shape == null:
		return
	if not (_collision_shape.shape is BoxShape3D):
		return

	var box: BoxShape3D = _collision_shape.shape as BoxShape3D
	box.size = Vector3(target_width, 1.15, target_length)
	_collision_shape.position = Vector3(0.0, box.size.y * 0.5, 0.0)

func _apply_texture_materials() -> void:
	if _active_model == null:
		return

	var mats: Dictionary = _build_material_map()
	var default_mat: Material = mats.get("defaultmaterial", null)
	if default_mat == null:
		return

	var meshes: Array[MeshInstance3D] = _collect_meshes(_active_model)
	for mesh_instance in meshes:
		var key: String = _choose_material_key(mesh_instance.name.to_lower())
		var chosen: Material = mats.get(key, default_mat)
		if chosen != null:
			mesh_instance.material_override = chosen

func _build_material_map() -> Dictionary:
	var map: Dictionary = {}
	map["defaultmaterial"] = _create_mat("DefaultMaterial", true)
	map["wheel"] = _create_mat("wheel", false)
	map["wheel_panel"] = _create_mat("wheel_panel", false)
	map["disk"] = _create_mat("disk", false)
	map["brake"] = _create_mat("brake", false)
	map["interior"] = _create_mat("interior", false)
	map["handle"] = _create_mat("handle", false)
	map["lamp"] = _create_mat("lamp", false)
	map["lamp2"] = _create_mat("lamp2", false)
	map["steering_wheel"] = _create_mat("steering_wheel", false)
	map["steering_wheel_1"] = _create_mat("steering_wheel_1", false)
	map["chair1"] = _create_mat("chair1", false)
	map["chair2"] = _create_mat("chair2", false)
	map["chair3"] = _create_mat("chair3", false)
	map["chair_back1"] = _create_mat("chair_back1", false)
	map["chair_back2"] = _create_mat("chair_back2", false)
	map["chair_back3"] = _create_mat("chair_back3", false)
	return map

func _create_mat(prefix: String, include_metallic: bool) -> Material:
	var base: Texture2D = _load_tex(prefix + "_Base_color.png")
	if base == null:
		return null

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = base
	mat.roughness = 0.7
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

	var rough: Texture2D = _load_tex(prefix + "_Roughness.png")
	if rough != null:
		mat.roughness_texture = rough

	var normal: Texture2D = _load_tex(prefix + "_Normal_OpenGL.png")
	if normal != null:
		mat.normal_enabled = true
		mat.normal_texture = normal
		mat.normal_scale = 1.0

	var ao: Texture2D = _load_tex(prefix + "_Mixed_AO.png")
	if ao != null:
		mat.ao_enabled = true
		mat.ao_texture = ao
		mat.ao_light_affect = 0.7

	if include_metallic:
		var metallic: Texture2D = _load_tex(prefix + "_Metallic.png")
		if metallic != null:
			mat.metallic = 1.0
			mat.metallic_texture = metallic
		else:
			mat.metallic = 0.55

	var opacity: Texture2D = _load_tex(prefix + "_Opacity.png")
	if opacity != null:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.albedo_texture_force_srgb = true
		mat.albedo_color = Color(1, 1, 1, 0.82)
		mat.alpha_scissor_threshold = 0.4

	return mat

func _load_tex(file_name: String) -> Texture2D:
	var clean_name: String = file_name.strip_edges()
	if clean_name == "":
		return null
	if _missing_texture_files.has(clean_name):
		return null
	if _texture_cache.has(clean_name):
		return _texture_cache.get(clean_name) as Texture2D

	var path: String = "res://small-price-car/textures/" + clean_name
	if not FileAccess.file_exists(path):
		_missing_texture_files[clean_name] = true
		return null

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if not bytes.is_empty():
		var image: Image = Image.new()
		var image_err: int = _load_image_from_buffer(image, bytes, path.get_extension().to_lower())
		if image_err == OK:
			var tex_from_image: ImageTexture = ImageTexture.create_from_image(image)
			_texture_cache[clean_name] = tex_from_image
			return tex_from_image

	# Fallback to imported texture only if direct decoding fails.
	var imported_path: String = _resolve_imported_texture_path(path)
	if imported_path != "" and ResourceLoader.exists(imported_path):
		var imported_tex: Texture2D = ResourceLoader.load(imported_path) as Texture2D
		if imported_tex != null:
			_texture_cache[clean_name] = imported_tex
			return imported_tex

	_missing_texture_files[clean_name] = true
	return null

func _resolve_imported_texture_path(source_path: String) -> String:
	if _imported_texture_path_cache.has(source_path):
		return str(_imported_texture_path_cache.get(source_path))

	var import_cfg_path: String = source_path + ".import"
	if not FileAccess.file_exists(import_cfg_path):
		_imported_texture_path_cache[source_path] = ""
		return ""

	var file: FileAccess = FileAccess.open(import_cfg_path, FileAccess.READ)
	if file == null:
		_imported_texture_path_cache[source_path] = ""
		return ""

	var remap_path: String = ""
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.begins_with("path=\""):
			remap_path = line.trim_prefix("path=\"").trim_suffix("\"")
			break
	file.close()

	_imported_texture_path_cache[source_path] = remap_path
	return remap_path

func _load_image_from_buffer(image: Image, bytes: PackedByteArray, ext_hint: String) -> int:
	var format: String = _detect_image_format(bytes)
	if format == "":
		format = ext_hint
	if format == "png":
		return image.load_png_from_buffer(bytes)
	if format == "jpg" or format == "jpeg":
		return image.load_jpg_from_buffer(bytes)
	if format == "webp":
		return image.load_webp_from_buffer(bytes)
	return ERR_UNAVAILABLE

func _detect_image_format(bytes: PackedByteArray) -> String:
	if bytes.size() >= 8:
		if bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47 and bytes[4] == 0x0D and bytes[5] == 0x0A and bytes[6] == 0x1A and bytes[7] == 0x0A:
			return "png"
	if bytes.size() >= 3:
		if bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF:
			return "jpg"
	if bytes.size() >= 12:
		if bytes[0] == 0x52 and bytes[1] == 0x49 and bytes[2] == 0x46 and bytes[3] == 0x46 and bytes[8] == 0x57 and bytes[9] == 0x45 and bytes[10] == 0x42 and bytes[11] == 0x50:
			return "webp"
	return ""

func _choose_material_key(node_name: String) -> String:
	if node_name.contains("wheel_panel"):
		return "wheel_panel"
	if node_name.contains("steering_wheel_1"):
		return "steering_wheel_1"
	if node_name.contains("steering_wheel"):
		return "steering_wheel"
	if node_name.contains("chair_back1"):
		return "chair_back1"
	if node_name.contains("chair_back2"):
		return "chair_back2"
	if node_name.contains("chair_back3"):
		return "chair_back3"
	if node_name.contains("chair1"):
		return "chair1"
	if node_name.contains("chair2"):
		return "chair2"
	if node_name.contains("chair3"):
		return "chair3"
	if node_name.contains("interior"):
		return "interior"
	if node_name.contains("handle"):
		return "handle"
	if node_name.contains("lamp2"):
		return "lamp2"
	if node_name.contains("lamp"):
		return "lamp"
	if node_name.contains("disk"):
		return "disk"
	if node_name.contains("brake"):
		return "brake"
	if node_name.contains("wheel"):
		return "wheel"
	return "defaultmaterial"

func _collect_meshes(root_node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	_collect_meshes_rec(root_node, result)
	return result

func _collect_meshes_rec(node: Node, bucket: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		bucket.append(node as MeshInstance3D)
	for child_variant in node.get_children():
		var child: Node = child_variant as Node
		if child != null:
			_collect_meshes_rec(child, bucket)

func _compute_bounds(meshes: Array[MeshInstance3D]) -> AABB:
	if _active_model == null:
		return AABB(Vector3.ZERO, Vector3.ZERO)

	var has_point: bool = false
	var min_v: Vector3 = Vector3.ZERO
	var max_v: Vector3 = Vector3.ZERO
	var inv: Transform3D = _active_model.global_transform.affine_inverse()

	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue
		var mesh_xf: Transform3D = inv * mesh_instance.global_transform
		var mesh_aabb: AABB = mesh_instance.mesh.get_aabb()
		for corner in _aabb_corners(mesh_aabb):
			var p: Vector3 = mesh_xf * corner
			if not has_point:
				has_point = true
				min_v = p
				max_v = p
			else:
				min_v = min_v.min(p)
				max_v = max_v.max(p)

	if not has_point:
		return AABB(Vector3.ZERO, Vector3.ZERO)
	return AABB(min_v, max_v - min_v)

func _compute_contact_bottom_y(meshes: Array[MeshInstance3D]) -> float:
	if _active_model == null:
		return 0.0

	var inv: Transform3D = _active_model.global_transform.affine_inverse()
	var min_any: float = INF
	var min_wheel: float = INF

	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue

		var mesh_xf: Transform3D = inv * mesh_instance.global_transform
		var mesh_aabb: AABB = mesh_instance.mesh.get_aabb()
		var local_min_y: float = INF

		for corner in _aabb_corners(mesh_aabb):
			var p: Vector3 = mesh_xf * corner
			min_any = minf(min_any, p.y)
			local_min_y = minf(local_min_y, p.y)

		if _is_wheel_mesh(mesh_instance.name):
			min_wheel = minf(min_wheel, local_min_y)

	if min_wheel < INF:
		return min_wheel
	if min_any < INF:
		return min_any
	return 0.0

func _is_wheel_mesh(mesh_name: String) -> bool:
	var lowered: String = mesh_name.to_lower()
	return lowered.contains("wheel") or lowered.contains("tire") or lowered.contains("tyre") or lowered.contains("lastik")

func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var p: Vector3 = aabb.position
	var s: Vector3 = aabb.size
	return [
		p,
		p + Vector3(s.x, 0.0, 0.0),
		p + Vector3(0.0, s.y, 0.0),
		p + Vector3(0.0, 0.0, s.z),
		p + Vector3(s.x, s.y, 0.0),
		p + Vector3(s.x, 0.0, s.z),
		p + Vector3(0.0, s.y, s.z),
		p + s
	]
