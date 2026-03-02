extends Node3D

@export var model_root_path: NodePath = NodePath("ModelPivot")
@export var collision_shape_path: NodePath = NodePath("CarBody/CollisionShape3D")
@export var target_length: float = 4.6
@export var target_width: float = 1.95
@export var y_rotation_offset_deg: float = 0.0

var _model_root: Node3D
var _collision_shape: CollisionShape3D

func _ready() -> void:
	_model_root = get_node_or_null(model_root_path) as Node3D
	_collision_shape = get_node_or_null(collision_shape_path) as CollisionShape3D
	if _model_root == null:
		return

	_model_root.rotation_degrees.y = y_rotation_offset_deg
	_fit_model_to_target()
	_update_collision_shape()
	_apply_texture_materials()

func _fit_model_to_target() -> void:
	var meshes: Array[MeshInstance3D] = _collect_meshes(_model_root)
	var bounds: AABB = _compute_bounds(meshes)
	if bounds.size.length() <= 0.0001:
		return

	var horizontal_span: float = maxf(bounds.size.x, bounds.size.z)
	if horizontal_span <= 0.001:
		return

	var uniform_scale: float = target_length / horizontal_span
	_model_root.scale = Vector3.ONE * uniform_scale

	var scaled_bounds: AABB = _compute_bounds(meshes)
	var center_x: float = scaled_bounds.position.x + scaled_bounds.size.x * 0.5
	var center_z: float = scaled_bounds.position.z + scaled_bounds.size.z * 0.5
	var bottom_y: float = scaled_bounds.position.y
	_model_root.position -= Vector3(center_x, bottom_y, center_z)

func _update_collision_shape() -> void:
	if _collision_shape == null:
		return
	if not (_collision_shape.shape is BoxShape3D):
		return

	var box: BoxShape3D = _collision_shape.shape as BoxShape3D
	box.size = Vector3(target_width, 1.15, target_length)
	_collision_shape.position = Vector3(0.0, box.size.y * 0.5, 0.0)

func _apply_texture_materials() -> void:
	var mats: Dictionary = _build_material_map()
	var default_mat: Material = mats.get("defaultmaterial", null)
	if default_mat == null:
		return

	var meshes: Array[MeshInstance3D] = _collect_meshes(_model_root)
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
	var path: String = "res://small-price-car/textures/" + file_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

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
	var has_point: bool = false
	var min_v: Vector3 = Vector3.ZERO
	var max_v: Vector3 = Vector3.ZERO
	var inv: Transform3D = _model_root.global_transform.affine_inverse()

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
