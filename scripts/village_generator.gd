extends Node3D

const HOUSE_DOOR_HINGE_POSITION: Vector3 = Vector3(-0.89, 0.02, 2.89)
const HOUSE_DOOR_INTERACTION_DISTANCE: float = 2.45
const HOUSE_DOOR_OPEN_ANGLE_DEG: float = 126.0
const HOUSE_DOOR_OPEN_DURATION: float = 0.62
const HOUSE_DOOR_OPEN_DIRECTION: float = -1.0
const HOUSE_DOOR_FACING_DOT_THRESHOLD: float = -0.1
const HOUSE_DOOR_MESH_SIZE: Vector3 = Vector3(1.42, 2.04, 0.075)
const HOUSE_DOOR_MESH_POSITION: Vector3 = Vector3(0.71, 1.02, 0.0)
const HOUSE_DOOR_COLLISION_SIZE: Vector3 = Vector3(1.44, 1.9, 0.09)
const HOUSE_DOOR_COLLISION_POSITION_Y: float = 1.0
const HOUSE_DOOR_HANDLE_POSITION: Vector3 = Vector3(1.20, 1.04, 0.055)
const HOUSE_DOOR_HANDLE_BASE_RADIUS: float = 0.022
const HOUSE_DOOR_HANDLE_BASE_HEIGHT: float = 0.05
const HOUSE_DOOR_HANDLE_BAR_SIZE: Vector3 = Vector3(0.22, 0.028, 0.028)
const HOUSE_DOOR_HANDLE_BAR_POSITION: Vector3 = Vector3(0.11, 0.0, 0.01)
const PBR_WALL_PREFIX: String = "res://assets/pbr/paintedplaster012/PaintedPlaster012_2K-JPG"
const PBR_ROOF_PREFIX: String = "res://assets/pbr/roofingtiles014b/RoofingTiles014B_2K-JPG"
const PBR_WOOD_PREFIX: String = "res://assets/pbr/wood039/Wood039_2K-JPG"
const PBR_CONCRETE_PREFIX: String = "res://assets/pbr/concrete012/Concrete012_2K-JPG"
const PBR_GROUND_PREFIX: String = "res://assets/pbr/ground091/Ground091_2K-JPG"
const PBR_ASPHALT_PREFIX: String = "res://assets/pbr/asphalt021/Asphalt021_2K-JPG"

@export var grave_count: int = 22
@export var village_radius: float = 90.0
@export var tree_count: int = 132
@export var grass_count: int = 4300
@export var rock_count: int = 180
@export var cemetery_center: Vector3 = Vector3(-30.0, 0.0, 10.0)
@export var cemetery_half_extents: Vector2 = Vector2(4.0, 6.5)

@export var terrain_resolution: int = 112
@export var terrain_height: float = 2.8
@export var terrain_base_frequency: float = 0.019
@export var terrain_detail_frequency: float = 0.062
@export var terrain_detail_strength: float = 0.95
@export var terrain_edge_falloff: float = 0.82

@export var road_width: float = 5.4
@export var road_shoulder_width: float = 2.6
@export var road_height_offset: float = 0.035
@export var road_samples_per_segment: int = 18
@export var road_path_points: PackedVector3Array = PackedVector3Array([
	Vector3(7.5, 0.0, 37.0),
	Vector3(4.6, 0.0, 19.0),
	Vector3(1.9, 0.0, 1.0),
	Vector3(-1.2, 0.0, -18.0),
	Vector3(-6.6, 0.0, -34.0)
])

@export var grass_road_exclusion: float = 4.2
@export var grass_asset_candidates: PackedStringArray = PackedStringArray([
	"res://assets/foliage/grass_clump.glb",
	"res://assets/foliage/grass_patch.glb",
	"res://assets/foliage/grass_01.glb"
])

var _wall_mat: Material
var _roof_mat: Material
var _wood_mat: Material
var _door_mat: Material
var _grave_mat: Material
var _ground_shader_mat: Material
var _asphalt_mat: Material
var _glass_shader_mat: Material
var _foliage_mat: ShaderMaterial
var _door_script: Script

var _tree_trunk_mat: StandardMaterial3D
var _tree_leaf_mat: StandardMaterial3D
var _rock_mat: StandardMaterial3D

var _terrain_noise_primary: FastNoiseLite
var _terrain_noise_secondary: FastNoiseLite

var _house_positions: Array[Vector3] = [
	Vector3(14.0, 0.0, -10.0),
	Vector3(-18.0, 0.0, -8.0),
	Vector3(10.0, 0.0, 20.0),
	Vector3(-12.0, 0.0, 25.0),
	Vector3(28.0, 0.0, 16.0),
	Vector3(-30.0, 0.0, 2.0)
]
var _house_rotations: Array[float] = [-0.3, 0.45, 1.1, -1.4, 0.7, -0.9]
var _house_nodes: Dictionary = {}
var _house_doors: Dictionary = {}

func _ready() -> void:
	randomize()
	_configure_terrain_noise()
	_build_materials()
	_create_ground()
	_create_ruined_houses()
	_create_graves()
	_create_tree_clusters()
	_create_foliage()
	_create_rocks()
	_create_story_landmarks()

func _configure_terrain_noise() -> void:
	_terrain_noise_primary = FastNoiseLite.new()
	_terrain_noise_primary.seed = int(randi())
	_terrain_noise_primary.frequency = terrain_base_frequency
	_terrain_noise_primary.noise_type = FastNoiseLite.TYPE_SIMPLEX

	_terrain_noise_secondary = FastNoiseLite.new()
	_terrain_noise_secondary.seed = _terrain_noise_primary.seed + 173
	_terrain_noise_secondary.frequency = terrain_detail_frequency
	_terrain_noise_secondary.noise_type = FastNoiseLite.TYPE_SIMPLEX

func _build_materials() -> void:
	_wall_mat = _create_pbr_material(PBR_WALL_PREFIX, Vector3(0.95, 0.95, 0.95), true)
	_roof_mat = _create_pbr_material(PBR_ROOF_PREFIX, Vector3(0.82, 0.82, 0.82), true)
	_wood_mat = _create_pbr_material(PBR_WOOD_PREFIX, Vector3(1.35, 1.35, 1.35), true)
	_door_mat = _create_pbr_material(PBR_WOOD_PREFIX, Vector3(1.05, 1.05, 1.05), true)
	_grave_mat = _create_pbr_material(PBR_CONCRETE_PREFIX, Vector3(1.15, 1.15, 1.15), true)
	_ground_shader_mat = _create_pbr_material(PBR_GROUND_PREFIX, Vector3(10.0, 1.0, 10.0), false)
	_asphalt_mat = _create_pbr_material(PBR_ASPHALT_PREFIX, Vector3(4.0, 1.0, 4.0), false)

	var door_standard: StandardMaterial3D = _door_mat as StandardMaterial3D
	if door_standard != null:
		door_standard.albedo_color = Color(0.78, 0.75, 0.73)
		door_standard.roughness = 0.9
	var roof_standard: StandardMaterial3D = _roof_mat as StandardMaterial3D
	if roof_standard != null:
		roof_standard.roughness = 0.95

	_glass_shader_mat = ShaderMaterial.new()
	_glass_shader_mat.shader = load("res://shaders/broken_glass.gdshader")

	_foliage_mat = ShaderMaterial.new()
	_foliage_mat.shader = load("res://shaders/foliage_wind.gdshader")
	_foliage_mat.set_shader_parameter("leaf_color", Color(0.11, 0.18, 0.10))
	_foliage_mat.set_shader_parameter("tip_color", Color(0.32, 0.44, 0.22))
	_foliage_mat.set_shader_parameter("wind_strength", 0.06)
	_foliage_mat.set_shader_parameter("wind_speed", 1.58)

	_tree_trunk_mat = StandardMaterial3D.new()
	_tree_trunk_mat.albedo_color = Color(0.16, 0.12, 0.09)
	_tree_trunk_mat.roughness = 0.86

	_tree_leaf_mat = StandardMaterial3D.new()
	_tree_leaf_mat.albedo_color = Color(0.12, 0.19, 0.11)
	_tree_leaf_mat.roughness = 0.9

	_rock_mat = StandardMaterial3D.new()
	_rock_mat.albedo_color = Color(0.27, 0.28, 0.29)
	_rock_mat.roughness = 0.95

	_door_script = load("res://scripts/interactable_door.gd") as Script

func _create_pbr_material(prefix: String, uv_scale: Vector3, use_triplanar: bool) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.uv1_scale = uv_scale
	mat.uv1_triplanar = use_triplanar
	mat.uv1_world_triplanar = use_triplanar
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.metallic = 0.0
	mat.roughness = 1.0

	var albedo_tex: Texture2D = _load_texture_if_exists("%s_Color.jpg" % prefix)
	if albedo_tex != null:
		mat.albedo_texture = albedo_tex

	var normal_tex: Texture2D = _load_texture_if_exists("%s_NormalGL.jpg" % prefix)
	if normal_tex != null:
		mat.normal_enabled = true
		mat.normal_texture = normal_tex
		mat.normal_scale = 1.0

	var roughness_tex: Texture2D = _load_texture_if_exists("%s_Roughness.jpg" % prefix)
	if roughness_tex != null:
		mat.roughness_texture = roughness_tex

	var ao_tex: Texture2D = _load_texture_if_exists("%s_AmbientOcclusion.jpg" % prefix)
	if ao_tex != null:
		mat.ao_enabled = true
		mat.ao_texture = ao_tex
		mat.ao_light_affect = 0.4

	return mat

func _load_texture_if_exists(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _create_ground() -> void:
	var ground_mesh: MeshInstance3D = MeshInstance3D.new()
	ground_mesh.name = "GroundTerrain"
	var terrain_mesh: ArrayMesh = _build_terrain_mesh()
	ground_mesh.mesh = terrain_mesh
	ground_mesh.material_override = _ground_shader_mat
	add_child(ground_mesh)

	var ground_body: StaticBody3D = StaticBody3D.new()
	ground_body.name = "GroundCollision"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	concave.data = terrain_mesh.get_faces()
	shape.shape = concave
	ground_body.add_child(shape)
	add_child(ground_body)

	_create_asphalt_road()

func _build_terrain_mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var resolution: int = clampi(terrain_resolution, 48, 120)
	var grid_size: int = resolution + 1
	var span: float = village_radius * 2.0
	var step: float = span / float(resolution)
	var half: float = village_radius
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(grid_size * grid_size)

	for z in range(grid_size):
		for x in range(grid_size):
			var px: float = -half + float(x) * step
			var pz: float = -half + float(z) * step
			heights[_height_index(x, z, grid_size)] = _sample_terrain_height(px, pz)

	for z in range(resolution):
		for x in range(resolution):
			var x0: float = -half + float(x) * step
			var x1: float = x0 + step
			var z0: float = -half + float(z) * step
			var z1: float = z0 + step

			var h00: float = heights[_height_index(x, z, grid_size)]
			var h10: float = heights[_height_index(x + 1, z, grid_size)]
			var h11: float = heights[_height_index(x + 1, z + 1, grid_size)]
			var h01: float = heights[_height_index(x, z + 1, grid_size)]

			var p00: Vector3 = Vector3(x0, h00, z0)
			var p10: Vector3 = Vector3(x1, h10, z0)
			var p11: Vector3 = Vector3(x1, h11, z1)
			var p01: Vector3 = Vector3(x0, h01, z1)

			var uv00: Vector2 = Vector2((x0 + half) / span, (z0 + half) / span)
			var uv10: Vector2 = Vector2((x1 + half) / span, (z0 + half) / span)
			var uv11: Vector2 = Vector2((x1 + half) / span, (z1 + half) / span)
			var uv01: Vector2 = Vector2((x0 + half) / span, (z1 + half) / span)

			_add_terrain_triangle(surface, p00, p10, p11, uv00, uv10, uv11)
			_add_terrain_triangle(surface, p00, p11, p01, uv00, uv11, uv01)

	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()

func _height_index(x: int, z: int, row_size: int) -> int:
	return (z * row_size) + x

func _add_terrain_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	surface.set_uv(uv_a)
	surface.add_vertex(a)
	surface.set_uv(uv_b)
	surface.add_vertex(b)
	surface.set_uv(uv_c)
	surface.add_vertex(c)

func _create_asphalt_road() -> void:
	var road_points: Array[Vector3] = _build_road_polyline()
	if road_points.size() < 2:
		return

	var road_surface: SurfaceTool = SurfaceTool.new()
	road_surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_width: float = road_width * 0.5
	var traveled: float = 0.0

	for i in range(road_points.size() - 1):
		var p0: Vector3 = road_points[i]
		var p1: Vector3 = road_points[i + 1]
		var segment_2d: Vector2 = Vector2(p1.x - p0.x, p1.z - p0.z)
		var seg_len: float = segment_2d.length()
		if seg_len < 0.05:
			continue

		var dir_2d: Vector2 = segment_2d / seg_len
		var right_2d: Vector2 = Vector2(-dir_2d.y, dir_2d.x)

		var l0: Vector3 = Vector3(
			p0.x - right_2d.x * half_width,
			_sample_terrain_height(p0.x - right_2d.x * half_width, p0.z - right_2d.y * half_width) + road_height_offset,
			p0.z - right_2d.y * half_width
		)
		var r0: Vector3 = Vector3(
			p0.x + right_2d.x * half_width,
			_sample_terrain_height(p0.x + right_2d.x * half_width, p0.z + right_2d.y * half_width) + road_height_offset,
			p0.z + right_2d.y * half_width
		)
		var l1: Vector3 = Vector3(
			p1.x - right_2d.x * half_width,
			_sample_terrain_height(p1.x - right_2d.x * half_width, p1.z - right_2d.y * half_width) + road_height_offset,
			p1.z - right_2d.y * half_width
		)
		var r1: Vector3 = Vector3(
			p1.x + right_2d.x * half_width,
			_sample_terrain_height(p1.x + right_2d.x * half_width, p1.z + right_2d.y * half_width) + road_height_offset,
			p1.z + right_2d.y * half_width
		)

		var v0: float = traveled * 0.12
		var v1: float = (traveled + seg_len) * 0.12

		_add_terrain_triangle(road_surface, l0, r0, r1, Vector2(0.0, v0), Vector2(1.0, v0), Vector2(1.0, v1))
		_add_terrain_triangle(road_surface, l0, r1, l1, Vector2(0.0, v0), Vector2(1.0, v1), Vector2(0.0, v1))
		traveled += seg_len

	road_surface.generate_normals()
	road_surface.generate_tangents()
	var road_mesh: ArrayMesh = road_surface.commit()

	var road_instance: MeshInstance3D = MeshInstance3D.new()
	road_instance.name = "AsphaltRoad"
	road_instance.mesh = road_mesh
	road_instance.material_override = _asphalt_mat
	add_child(road_instance)

func _build_road_polyline() -> Array[Vector3]:
	var dense_points: Array[Vector3] = []
	if road_path_points.size() < 2:
		return dense_points

	var samples_per_segment: int = maxi(road_samples_per_segment, 4)
	for i in range(road_path_points.size() - 1):
		var a: Vector3 = road_path_points[i]
		var b: Vector3 = road_path_points[i + 1]
		for s in range(samples_per_segment):
			var t: float = float(s) / float(samples_per_segment)
			var p: Vector3 = a.lerp(b, t)
			p.y = _sample_terrain_height(p.x, p.z) + road_height_offset
			dense_points.append(p)

	var last: Vector3 = road_path_points[road_path_points.size() - 1]
	last.y = _sample_terrain_height(last.x, last.z) + road_height_offset
	dense_points.append(last)
	return dense_points

func _create_ruined_houses() -> void:
	for i in range(_house_positions.size()):
		var house_pos: Vector3 = _house_positions[i]
		house_pos.y = _sample_terrain_height(house_pos.x, house_pos.z)
		var house: Node3D = _create_ruined_house(i, house_pos, _house_rotations[i])
		_house_nodes[i] = house

func _create_ruined_house(index: int, origin: Vector3, y_rot: float) -> Node3D:
	var house: Node3D = Node3D.new()
	house.position = origin
	house.rotation.y = y_rot
	house.name = "House_%d" % index
	house.add_to_group("story_house")
	add_child(house)

	var wall_material: Material = _wall_mat
	if index == 1:
		wall_material = _grave_mat

	_add_box_segment(house, Vector3(6.0, 0.04, 6.0), Vector3(0.0, 0.02, 0.0), Vector3.ZERO, wall_material, false)

	var h: float = 2.8
	var t: float = 0.22

	_add_box_segment(house, Vector3(6.0, h, t), Vector3(0.0, h * 0.5, -3.0), Vector3.ZERO, wall_material, true)
	_add_box_segment(house, Vector3(t, h, 6.0), Vector3(-3.0, h * 0.5, 0.0), Vector3.ZERO, wall_material, true)
	_add_box_segment(house, Vector3(t, h, 6.0), Vector3(3.0, h * 0.5, 0.0), Vector3.ZERO, wall_material, true)

	_add_box_segment(house, Vector3(2.1, h, t), Vector3(-1.95, h * 0.5, 3.0), Vector3.ZERO, wall_material, true)
	_add_box_segment(house, Vector3(2.1, h, t), Vector3(1.95, h * 0.5, 3.0), Vector3.ZERO, wall_material, true)
	_add_box_segment(house, Vector3(1.8, 0.4, t), Vector3(0.0, 2.6, 3.0), Vector3.ZERO, wall_material, true)

	_add_box_segment(house, Vector3(4.8, 0.15, 2.1), Vector3(-0.8, 2.9, -1.1), Vector3(0.16, 0.25, -0.1), _roof_mat, true)
	_add_box_segment(house, Vector3(2.5, 0.15, 1.5), Vector3(1.5, 2.5, 1.0), Vector3(-0.1, -0.2, 0.1), _roof_mat, true)

	_add_box_segment(house, Vector3(1.56, 0.12, 0.12), Vector3(0.0, 2.36, 2.94), Vector3.ZERO, _wood_mat, false)
	_add_box_segment(house, Vector3(1.56, 0.02, 0.12), Vector3(0.0, 0.01, 2.94), Vector3.ZERO, _wood_mat, false)
	_add_box_segment(house, Vector3(0.12, 2.2, 0.12), Vector3(-0.84, 1.3, 2.94), Vector3.ZERO, _wood_mat, false)
	_add_box_segment(house, Vector3(0.12, 2.2, 0.12), Vector3(0.84, 1.3, 2.94), Vector3.ZERO, _wood_mat, false)

	var door_hinge: Node3D = _add_house_door(house)
	_house_doors[index] = door_hinge
	if index == 1 and door_hinge != null:
		door_hinge.add_to_group("story_locked_door")
		if door_hinge.has_method("set_locked"):
			door_hinge.call("set_locked", true)
	if index == 2:
		_add_box_segment(house, Vector3(1.8, 0.12, 1.4), Vector3(1.15, 1.96, -0.85), Vector3(0.55, -0.12, 0.18), _roof_mat, false)

	return house

func _add_house_door(house: Node3D) -> Node3D:
	var hinge: Node3D = Node3D.new()
	hinge.name = "DoorHinge"
	hinge.position = HOUSE_DOOR_HINGE_POSITION
	_configure_house_door_interaction(hinge)

	var door_body: AnimatableBody3D = AnimatableBody3D.new()
	door_body.name = "DoorBody"
	hinge.add_child(door_body)

	var door_mesh: MeshInstance3D = _create_house_door_mesh()
	door_body.add_child(door_mesh)
	door_body.add_child(_create_house_door_collision())
	door_body.add_child(_create_house_door_handle())

	house.add_child(hinge)
	return hinge

func _configure_house_door_interaction(hinge: Node3D) -> void:
	if _door_script == null:
		return
	hinge.set_script(_door_script)
	hinge.set("interaction_distance", HOUSE_DOOR_INTERACTION_DISTANCE)
	hinge.set("open_angle_deg", HOUSE_DOOR_OPEN_ANGLE_DEG)
	hinge.set("open_duration", HOUSE_DOOR_OPEN_DURATION)
	hinge.set("open_direction", HOUSE_DOOR_OPEN_DIRECTION)
	hinge.set("auto_open_away_from_player", true)
	hinge.set("require_facing_door", true)
	hinge.set("facing_dot_threshold", HOUSE_DOOR_FACING_DOT_THRESHOLD)

func _create_house_door_mesh() -> MeshInstance3D:
	var door_mesh: MeshInstance3D = MeshInstance3D.new()
	var door_shape: BoxMesh = BoxMesh.new()
	door_shape.size = HOUSE_DOOR_MESH_SIZE
	door_mesh.mesh = door_shape
	door_mesh.material_override = _door_mat
	door_mesh.position = HOUSE_DOOR_MESH_POSITION
	return door_mesh

func _create_house_door_collision() -> CollisionShape3D:
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = HOUSE_DOOR_COLLISION_SIZE
	collision.shape = box
	collision.position = Vector3(HOUSE_DOOR_MESH_POSITION.x, HOUSE_DOOR_COLLISION_POSITION_Y, HOUSE_DOOR_MESH_POSITION.z)
	return collision

func _create_house_door_handle() -> Node3D:
	var handle_pivot: Node3D = Node3D.new()
	handle_pivot.name = "HandlePivot"
	handle_pivot.position = HOUSE_DOOR_HANDLE_POSITION

	var handle_base: MeshInstance3D = MeshInstance3D.new()
	var base_mesh: CylinderMesh = CylinderMesh.new()
	base_mesh.top_radius = HOUSE_DOOR_HANDLE_BASE_RADIUS
	base_mesh.bottom_radius = HOUSE_DOOR_HANDLE_BASE_RADIUS
	base_mesh.height = HOUSE_DOOR_HANDLE_BASE_HEIGHT
	handle_base.mesh = base_mesh
	handle_base.material_override = _wood_mat
	handle_base.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	handle_pivot.add_child(handle_base)

	var handle_bar: MeshInstance3D = MeshInstance3D.new()
	var bar_mesh: BoxMesh = BoxMesh.new()
	bar_mesh.size = HOUSE_DOOR_HANDLE_BAR_SIZE
	handle_bar.mesh = bar_mesh
	handle_bar.material_override = _wood_mat
	handle_bar.position = HOUSE_DOOR_HANDLE_BAR_POSITION
	handle_pivot.add_child(handle_bar)
	return handle_pivot

func _create_graves() -> void:
	var grave_root: Node3D = Node3D.new()
	grave_root.name = "Graves"
	grave_root.position = Vector3(cemetery_center.x, _sample_terrain_height(cemetery_center.x, cemetery_center.z), cemetery_center.z)
	add_child(grave_root)

	var grave_mesh: BoxMesh = BoxMesh.new()
	grave_mesh.size = Vector3(0.42, 1.05, 0.14)

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = grave_count
	mm.mesh = grave_mesh

	for i in range(grave_count):
		var lx: float = randf_range(-cemetery_half_extents.x, cemetery_half_extents.x)
		var lz: float = randf_range(-cemetery_half_extents.y, cemetery_half_extents.y)
		var world_x: float = grave_root.position.x + lx
		var world_z: float = grave_root.position.z + lz
		var local_ground_y: float = _sample_terrain_height(world_x, world_z) - grave_root.position.y

		var local_pos: Vector3 = Vector3(lx, local_ground_y + 0.52, lz)
		var basis: Basis = Basis.from_euler(Vector3(0.0, randf_range(-0.35, 0.35), randf_range(-0.05, 0.08)))
		var xform: Transform3D = Transform3D(basis, local_pos)
		xform = xform.scaled_local(Vector3(randf_range(0.9, 1.2), randf_range(0.75, 1.35), 1.0))
		mm.set_instance_transform(i, xform)

		if i % 15 == 0:
			var col: StaticBody3D = StaticBody3D.new()
			var shape: CollisionShape3D = CollisionShape3D.new()
			var grave_box: BoxShape3D = BoxShape3D.new()
			grave_box.size = Vector3(0.55, 1.1, 0.28)
			shape.shape = grave_box
			shape.position = local_pos
			shape.rotation = Vector3(0.0, basis.get_euler().y, 0.0)
			col.add_child(shape)
			grave_root.add_child(col)

	var mm_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm_instance.multimesh = mm
	mm_instance.material_override = _grave_mat
	grave_root.add_child(mm_instance)

func _create_tree_clusters() -> void:
	var tree_root: Node3D = Node3D.new()
	tree_root.name = "Trees"
	add_child(tree_root)

	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.12
	trunk_mesh.bottom_radius = 0.18
	trunk_mesh.height = 1.0

	var crown_mesh: SphereMesh = SphereMesh.new()
	crown_mesh.radius = 0.65
	crown_mesh.height = 1.15

	var trunk_mm: MultiMesh = MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	trunk_mm.instance_count = tree_count
	trunk_mm.mesh = trunk_mesh

	var crown_mm: MultiMesh = MultiMesh.new()
	crown_mm.transform_format = MultiMesh.TRANSFORM_3D
	crown_mm.instance_count = tree_count
	crown_mm.mesh = crown_mesh

	for i in range(tree_count):
		var p: Vector3 = _random_ring_position(24.0, village_radius - 7.0)
		if _distance_to_road(Vector2(p.x, p.z)) < road_width + 0.8:
			p = _random_ring_position(30.0, village_radius - 7.0)

		var ground_y: float = _sample_terrain_height(p.x, p.z)
		var trunk_h: float = randf_range(2.4, 4.2)
		var trunk_scale: float = randf_range(0.85, 1.2)

		var trunk_basis: Basis = Basis(Vector3.UP, randf_range(-PI, PI)).scaled(Vector3(trunk_scale, trunk_h, trunk_scale))
		var trunk_xf: Transform3D = Transform3D(trunk_basis, Vector3(p.x, ground_y + trunk_h * 0.5, p.z))
		trunk_mm.set_instance_transform(i, trunk_xf)

		var crown_scale: float = randf_range(1.0, 1.45)
		var crown_basis: Basis = Basis(Vector3.UP, randf_range(-PI, PI)).scaled(Vector3(crown_scale * 1.4, crown_scale, crown_scale * 1.25))
		var crown_xf: Transform3D = Transform3D(crown_basis, Vector3(p.x, ground_y + trunk_h + crown_scale * 0.55, p.z))
		crown_mm.set_instance_transform(i, crown_xf)

		if i % 10 == 0:
			var body: StaticBody3D = StaticBody3D.new()
			var shape: CollisionShape3D = CollisionShape3D.new()
			var trunk_shape: CylinderShape3D = CylinderShape3D.new()
			trunk_shape.radius = 0.35 * trunk_scale
			trunk_shape.height = trunk_h
			shape.shape = trunk_shape
			shape.position = Vector3(p.x, ground_y + trunk_h * 0.5, p.z)
			body.add_child(shape)
			tree_root.add_child(body)

	var trunk_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	trunk_instance.multimesh = trunk_mm
	trunk_instance.material_override = _tree_trunk_mat
	tree_root.add_child(trunk_instance)

	var crown_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	crown_instance.multimesh = crown_mm
	crown_instance.material_override = _tree_leaf_mat
	tree_root.add_child(crown_instance)

func _create_foliage() -> void:
	var grass_root: Node3D = Node3D.new()
	grass_root.name = "Grass"
	add_child(grass_root)

	var blade_mesh: Mesh = _load_grass_mesh_asset()
	if blade_mesh == null:
		blade_mesh = _build_procedural_grass_mesh()

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = grass_count
	mm.mesh = blade_mesh

	var placed: int = 0
	var attempts: int = 0
	var max_attempts: int = grass_count * 4
	while placed < grass_count and attempts < max_attempts:
		attempts += 1
		var p: Vector3 = _random_ring_position(6.0, village_radius - 5.0)
		if _distance_to_road(Vector2(p.x, p.z)) < grass_road_exclusion:
			continue
		if _is_near_house(Vector2(p.x, p.z), 4.1):
			continue
		var density_mask: float = _terrain_noise_secondary.get_noise_2d(p.x * 0.9, p.z * 0.9)
		if density_mask < -0.18:
			continue

		var h: float = randf_range(0.65, 1.35)
		var yaw: float = randf_range(-PI, PI)
		var tilt_x: float = randf_range(-0.1, 0.1)
		var tilt_z: float = randf_range(-0.1, 0.1)
		var basis: Basis = Basis.from_euler(Vector3(tilt_x, yaw, tilt_z)).scaled(Vector3(randf_range(0.75, 1.2), h, randf_range(0.85, 1.15)))
		var base_y: float = _sample_terrain_height(p.x, p.z)
		var xf: Transform3D = Transform3D(basis, Vector3(p.x, base_y + h * 0.5, p.z))
		mm.set_instance_transform(placed, xf)
		placed += 1

	if placed < grass_count:
		mm.instance_count = placed

	var mm_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm_instance.multimesh = mm
	mm_instance.material_override = _foliage_mat
	grass_root.add_child(mm_instance)

func _build_procedural_grass_mesh() -> Mesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var width: float = 0.2
	var height: float = 1.0
	var planes: int = 3
	for i in range(planes):
		var yaw: float = float(i) * PI / float(planes)
		var right: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw)) * width * 0.5
		var bottom_l: Vector3 = -right
		var bottom_r: Vector3 = right
		var top_l: Vector3 = Vector3(-right.x * 0.18, height, -right.z * 0.18)
		var top_r: Vector3 = Vector3(right.x * 0.18, height, right.z * 0.18)
		var normal: Vector3 = Vector3(-sin(yaw), 0.0, cos(yaw))

		st.set_normal(normal)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(bottom_l)
		st.set_normal(normal)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(bottom_r)
		st.set_normal(normal)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(top_l)

		st.set_normal(normal)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(top_l)
		st.set_normal(normal)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(bottom_r)
		st.set_normal(normal)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(top_r)

		st.set_normal(-normal)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(bottom_r)
		st.set_normal(-normal)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(bottom_l)
		st.set_normal(-normal)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(top_r)

		st.set_normal(-normal)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(top_r)
		st.set_normal(-normal)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(bottom_l)
		st.set_normal(-normal)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(top_l)

	st.generate_normals()
	st.generate_tangents()
	st.commit(mesh)
	return mesh

func _create_rocks() -> void:
	var rock_root: Node3D = Node3D.new()
	rock_root.name = "Rocks"
	add_child(rock_root)

	var rock_mesh: SphereMesh = SphereMesh.new()
	rock_mesh.radius = 0.45
	rock_mesh.height = 0.7

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = rock_count
	mm.mesh = rock_mesh

	for i in range(rock_count):
		var p: Vector3 = _random_ring_position(10.0, village_radius - 6.0)
		if _distance_to_road(Vector2(p.x, p.z)) < road_width + 0.7:
			p = _random_ring_position(14.0, village_radius - 6.0)

		var s: float = randf_range(0.45, 1.2)
		var basis: Basis = Basis.from_euler(Vector3(randf_range(-0.2, 0.2), randf_range(-PI, PI), randf_range(-0.25, 0.25))).scaled(Vector3(s * 1.25, s * 0.65, s))
		var base_y: float = _sample_terrain_height(p.x, p.z)
		var xf: Transform3D = Transform3D(basis, Vector3(p.x, base_y + s * 0.22, p.z))
		mm.set_instance_transform(i, xf)

	var mm_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm_instance.multimesh = mm
	mm_instance.material_override = _rock_mat
	rock_root.add_child(mm_instance)

func _create_story_landmarks() -> void:
	_create_road_signpost()
	_create_broken_pole()
	_create_story_bushes()
	_create_symbolic_graves()
	_create_magic_house_story()
	_create_ruined_house_story()

func _create_road_signpost() -> void:
	var sign_root: Node3D = Node3D.new()
	sign_root.name = "RoadSign"
	var sx: float = 7.8
	var sz: float = 34.8
	sign_root.position = Vector3(sx, _sample_terrain_height(sx, sz), sz)
	add_child(sign_root)

	_add_box_segment(sign_root, Vector3(0.18, 2.45, 0.18), Vector3(-0.9, 1.22, 0.0), Vector3(0.0, 0.0, 0.04), _wood_mat, false)
	_add_box_segment(sign_root, Vector3(0.18, 2.35, 0.18), Vector3(0.9, 1.17, 0.0), Vector3(0.0, 0.0, -0.03), _wood_mat, false)
	_add_box_segment(sign_root, Vector3(2.6, 0.86, 0.16), Vector3(0.0, 1.88, -0.02), Vector3(0.03, 0.0, 0.0), _wood_mat, false)

	var sign_text: Label3D = Label3D.new()
	sign_text.text = "Mezit - Uc Catalli - Golge Koyu"
	sign_text.font_size = 62
	sign_text.modulate = Color(0.87, 0.83, 0.74, 0.95)
	sign_text.outline_modulate = Color(0.02, 0.02, 0.02, 0.8)
	sign_text.outline_size = 3
	sign_text.position = Vector3(-1.16, 2.01, 0.09)
	sign_text.rotation = Vector3(0.0, PI * 0.5, 0.0)
	sign_root.add_child(sign_text)

func _create_broken_pole() -> void:
	var pole_root: Node3D = Node3D.new()
	pole_root.name = "BrokenPole"
	var px: float = -8.0
	var pz: float = 11.5
	pole_root.position = Vector3(px, _sample_terrain_height(px, pz), pz)
	add_child(pole_root)

	var pole_mesh: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.11
	cylinder.bottom_radius = 0.14
	cylinder.height = 5.8
	pole_mesh.mesh = cylinder
	pole_mesh.material_override = _wood_mat
	pole_mesh.position = Vector3(0.0, 2.9, 0.0)
	pole_mesh.rotation = Vector3(0.1, 0.0, 0.13)
	pole_root.add_child(pole_mesh)

	var flicker_light: OmniLight3D = OmniLight3D.new()
	flicker_light.name = "PoleLamp"
	flicker_light.position = Vector3(0.25, 4.85, 0.11)
	flicker_light.light_color = Color(1.0, 0.94, 0.82, 1.0)
	flicker_light.light_energy = 0.95
	flicker_light.omni_range = 12.0
	flicker_light.omni_attenuation = 1.35
	var flicker_script: Script = load("res://scripts/flicker_light.gd") as Script
	if flicker_script != null:
		flicker_light.set_script(flicker_script)
	pole_root.add_child(flicker_light)

func _create_story_bushes() -> void:
	var bush_root: Node3D = Node3D.new()
	bush_root.name = "StoryBushes"
	add_child(bush_root)

	var center: Vector2 = Vector2(2.2, 18.8)
	for i in range(8):
		var angle: float = float(i) * TAU / 8.0 + randf_range(-0.3, 0.3)
		var dist: float = randf_range(2.8, 7.2)
		var bx: float = center.x + cos(angle) * dist
		var bz: float = center.y + sin(angle) * dist
		var by: float = _sample_terrain_height(bx, bz)

		var bush: Area3D = Area3D.new()
		bush.name = "Bush_%d" % i
		bush.position = Vector3(bx, by + 0.45, bz)
		bush.set_meta("searched", false)
		bush.set_meta("contains_key", false)
		bush.add_to_group("story_bush")
		bush_root.add_child(bush)

		var shape_node: CollisionShape3D = CollisionShape3D.new()
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = 0.9
		shape_node.shape = shape
		shape_node.position = Vector3(0.0, 0.2, 0.0)
		bush.add_child(shape_node)

		var bush_mesh: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.9
		sphere.height = 1.1
		bush_mesh.mesh = sphere
		bush_mesh.material_override = _foliage_mat
		bush_mesh.scale = Vector3(1.0, 0.7, 1.0)
		bush.add_child(bush_mesh)

func _create_symbolic_graves() -> void:
	var puzzle_root: Node3D = Node3D.new()
	puzzle_root.name = "PuzzleGraves"
	var base: Vector3 = Vector3(cemetery_center.x, _sample_terrain_height(cemetery_center.x, cemetery_center.z), cemetery_center.z)
	puzzle_root.position = base + Vector3(0.0, 0.0, -3.0)
	add_child(puzzle_root)

	var data: Array[Dictionary] = [
		{"symbol": "MZ", "year": 1891, "order": 0, "x": -1.5},
		{"symbol": "UC", "year": 1938, "order": 1, "x": 0.0},
		{"symbol": "GK", "year": 1972, "order": 2, "x": 1.5}
	]

	for i in range(data.size()):
		var entry: Dictionary = data[i]
		var area: Area3D = Area3D.new()
		area.name = "SymbolGrave_%d" % i
		area.position = Vector3(float(entry["x"]), 0.0, 0.0)
		area.add_to_group("story_grave_symbol")
		area.set_meta("symbol", String(entry["symbol"]))
		area.set_meta("year", int(entry["year"]))
		area.set_meta("order_index", int(entry["order"]))
		puzzle_root.add_child(area)

		var shape_node: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(0.65, 1.35, 0.35)
		shape_node.shape = box
		shape_node.position = Vector3(0.0, 0.68, 0.0)
		area.add_child(shape_node)

		var mesh: MeshInstance3D = MeshInstance3D.new()
		var grave_box: BoxMesh = BoxMesh.new()
		grave_box.size = Vector3(0.58, 1.28, 0.28)
		mesh.mesh = grave_box
		mesh.material_override = _grave_mat
		mesh.position = Vector3(0.0, 0.64, 0.0)
		area.add_child(mesh)

		var label: Label3D = Label3D.new()
		label.text = "%s\\n%d" % [String(entry["symbol"]), int(entry["year"])]
		label.font_size = 48
		label.position = Vector3(-0.31, 1.18, 0.16)
		label.rotation = Vector3(0.0, PI * 0.5, 0.0)
		label.modulate = Color(0.88, 0.9, 0.86, 0.96)
		area.add_child(label)

func _create_magic_house_story() -> void:
	if not _house_nodes.has(1):
		return
	var house: Node3D = _house_nodes[1] as Node3D
	if house == null:
		return

	var symbol_label: Label3D = Label3D.new()
	symbol_label.text = "MZ - UC - GK"
	symbol_label.font_size = 52
	symbol_label.position = Vector3(-1.15, 1.84, 2.93)
	symbol_label.rotation = Vector3(0.0, PI, 0.0)
	symbol_label.modulate = Color(0.79, 0.17, 0.14, 0.92)
	house.add_child(symbol_label)

	_add_box_segment(house, Vector3(1.15, 0.2, 0.85), Vector3(0.0, 0.48, -0.32), Vector3.ZERO, _wood_mat, false)

	var ritual_ring: MeshInstance3D = MeshInstance3D.new()
	var ring_mesh: CylinderMesh = CylinderMesh.new()
	ring_mesh.top_radius = 1.06
	ring_mesh.bottom_radius = 1.06
	ring_mesh.height = 0.04
	ritual_ring.mesh = ring_mesh
	ritual_ring.material_override = _grave_mat
	ritual_ring.position = Vector3(0.0, 0.03, -0.4)
	house.add_child(ritual_ring)

	var entry_area: Area3D = Area3D.new()
	entry_area.name = "MagicHouseEntry"
	entry_area.position = Vector3(0.0, 0.9, 1.1)
	entry_area.add_to_group("story_magic_house_entry")
	var entry_shape: CollisionShape3D = CollisionShape3D.new()
	var entry_box: BoxShape3D = BoxShape3D.new()
	entry_box.size = Vector3(1.5, 1.8, 1.5)
	entry_shape.shape = entry_box
	entry_area.add_child(entry_shape)
	house.add_child(entry_area)

	var candle_positions: Array[Vector3] = [
		Vector3(-0.65, 0.42, -0.95),
		Vector3(0.63, 0.42, -0.9),
		Vector3(-0.74, 0.42, 0.1),
		Vector3(0.76, 0.42, 0.05)
	]
	for i in range(candle_positions.size()):
		var candle: Area3D = Area3D.new()
		candle.name = "RitualCandle_%d" % i
		candle.position = candle_positions[i]
		candle.add_to_group("story_candle")
		candle.set_meta("candle_index", i)
		candle.set_meta("lit", false)
		house.add_child(candle)

		var candle_shape_node: CollisionShape3D = CollisionShape3D.new()
		var candle_shape: SphereShape3D = SphereShape3D.new()
		candle_shape.radius = 0.28
		candle_shape_node.shape = candle_shape
		candle_shape_node.position = Vector3(0.0, 0.26, 0.0)
		candle.add_child(candle_shape_node)

		var candle_mesh: MeshInstance3D = MeshInstance3D.new()
		var candle_body: CylinderMesh = CylinderMesh.new()
		candle_body.top_radius = 0.06
		candle_body.bottom_radius = 0.065
		candle_body.height = 0.36
		candle_mesh.mesh = candle_body
		candle_mesh.position = Vector3(0.0, 0.18, 0.0)
		candle_mesh.material_override = _wood_mat
		candle.add_child(candle_mesh)

		var flame: OmniLight3D = OmniLight3D.new()
		flame.name = "FlameLight"
		flame.position = Vector3(0.0, 0.38, 0.0)
		flame.light_color = Color(1.0, 0.69, 0.34, 1.0)
		flame.light_energy = 0.0
		flame.omni_range = 3.2
		flame.visible = false
		candle.add_child(flame)

func _create_ruined_house_story() -> void:
	if not _house_nodes.has(2):
		return
	var house: Node3D = _house_nodes[2] as Node3D
	if house == null:
		return

	var warning_label: Label3D = Label3D.new()
	warning_label.text = "Bodrumdan ses geliyor..."
	warning_label.font_size = 42
	warning_label.position = Vector3(-1.3, 0.4, -1.75)
	warning_label.rotation = Vector3(0.0, 0.26, 0.0)
	warning_label.modulate = Color(0.84, 0.82, 0.78, 0.8)
	house.add_child(warning_label)

func _random_ring_position(min_radius: float, max_radius: float) -> Vector3:
	var a: float = randf() * TAU
	var rr: float = sqrt(randf())
	var r: float = min_radius + rr * (max_radius - min_radius)
	return Vector3(cos(a) * r, 0.0, sin(a) * r)

func _raw_terrain_height(x: float, z: float) -> float:
	var base_noise: float = _terrain_noise_primary.get_noise_2d(x, z) * terrain_height
	var detail_noise: float = _terrain_noise_secondary.get_noise_2d(x, z) * terrain_detail_strength
	var radial: float = Vector2(x, z).length() / maxf(1.0, village_radius)
	var edge: float = _smoothstep(terrain_edge_falloff, 1.0, radial)
	return base_noise + detail_noise - edge * terrain_height * 0.7

func _sample_terrain_height(x: float, z: float) -> float:
	var height: float = _raw_terrain_height(x, z)
	var point: Vector2 = Vector2(x, z)

	for i in range(_house_positions.size()):
		var center: Vector2 = Vector2(_house_positions[i].x, _house_positions[i].z)
		var d: float = point.distance_to(center)
		if d < 5.0:
			var blend: float = 1.0 - _smoothstep(2.4, 5.0, d)
			var center_h: float = _raw_terrain_height(center.x, center.y)
			height = lerpf(height, center_h, blend * 0.9)

	var road_distance: float = _distance_to_road(point)
	if road_distance < road_width + road_shoulder_width:
		var road_blend: float = 1.0 - _smoothstep(road_width * 0.5, road_width + road_shoulder_width, road_distance)
		height = lerpf(height, 0.02, road_blend * 0.96)

	return height

func _distance_to_road(point: Vector2) -> float:
	if road_path_points.size() < 2:
		return INF

	var nearest: float = INF
	for i in range(road_path_points.size() - 1):
		var a3: Vector3 = road_path_points[i]
		var b3: Vector3 = road_path_points[i + 1]
		var a: Vector2 = Vector2(a3.x, a3.z)
		var b: Vector2 = Vector2(b3.x, b3.z)
		var d: float = _distance_to_segment_2d(point, a, b)
		if d < nearest:
			nearest = d
	return nearest

func _distance_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq <= 0.0001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var projection: Vector2 = a + ab * t
	return p.distance_to(projection)

func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	if edge1 <= edge0:
		return 0.0
	var t: float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _is_near_house(point: Vector2, radius: float) -> bool:
	for i in range(_house_positions.size()):
		var center: Vector2 = Vector2(_house_positions[i].x, _house_positions[i].z)
		if point.distance_to(center) < radius:
			return true
	return false

func _load_grass_mesh_asset() -> Mesh:
	for candidate_variant in grass_asset_candidates:
		var path: String = str(candidate_variant)
		if path == "" or not ResourceLoader.exists(path):
			continue

		var res: Resource = load(path)
		if res == null:
			continue
		if res is Mesh:
			return res as Mesh
		if res is PackedScene:
			var packed: PackedScene = res as PackedScene
			var inst: Node = packed.instantiate()
			var extracted: Mesh = _extract_mesh_from_scene(inst)
			inst.queue_free()
			if extracted != null:
				return extracted

	return null

func _extract_mesh_from_scene(node: Node) -> Mesh:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node.mesh != null:
			return mesh_node.mesh

	for child_variant in node.get_children():
		var child: Node = child_variant as Node
		if child == null:
			continue
		var found: Mesh = _extract_mesh_from_scene(child)
		if found != null:
			return found

	return null

func _add_box_segment(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material, add_collision: bool) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.rotation = rot
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)

	if add_collision:
		var body: StaticBody3D = StaticBody3D.new()
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = pos
		shape.rotation = rot
		body.add_child(shape)
		parent.add_child(body)
