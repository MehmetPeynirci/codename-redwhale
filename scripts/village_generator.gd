extends Node3D

@export var grave_count: int = 150
@export var village_radius: float = 90.0
@export var tree_count: int = 78
@export var grass_count: int = 2200
@export var rock_count: int = 120

var _wall_mat: ShaderMaterial
var _roof_mat: ShaderMaterial
var _wood_mat: ShaderMaterial
var _grave_mat: ShaderMaterial
var _ground_shader_mat: ShaderMaterial
var _glass_shader_mat: ShaderMaterial
var _foliage_mat: ShaderMaterial

var _tree_trunk_mat: StandardMaterial3D
var _tree_leaf_mat: StandardMaterial3D
var _rock_mat: StandardMaterial3D

func _ready() -> void:
	randomize()
	_build_materials()
	_create_ground()
	_create_ruined_houses()
	_create_graves()
	_create_tree_clusters()
	_create_foliage()
	_create_rocks()

func _build_materials() -> void:
	var weather_shader: Shader = load("res://shaders/weathered_surface.gdshader")

	_wall_mat = _create_weathered_mat(
		weather_shader,
		Color(0.23, 0.23, 0.22),
		Color(0.13, 0.19, 0.15),
		Color(0.08, 0.09, 0.10),
		0.62,
		8.5,
		0.42,
		0.9,
		0.26
	)

	_roof_mat = _create_weathered_mat(
		weather_shader,
		Color(0.10, 0.10, 0.11),
		Color(0.09, 0.13, 0.10),
		Color(0.05, 0.06, 0.07),
		0.75,
		11.0,
		0.22,
		0.84,
		0.18
	)

	_wood_mat = _create_weathered_mat(
		weather_shader,
		Color(0.18, 0.13, 0.09),
		Color(0.14, 0.17, 0.12),
		Color(0.07, 0.07, 0.06),
		0.55,
		12.0,
		0.26,
		0.78,
		0.33
	)

	_grave_mat = _create_weathered_mat(
		weather_shader,
		Color(0.37, 0.37, 0.38),
		Color(0.19, 0.24, 0.20),
		Color(0.12, 0.12, 0.12),
		0.52,
		9.0,
		0.47,
		0.93,
		0.35
	)

	_ground_shader_mat = ShaderMaterial.new()
	_ground_shader_mat.shader = load("res://shaders/wet_ground.gdshader")

	_glass_shader_mat = ShaderMaterial.new()
	_glass_shader_mat.shader = load("res://shaders/broken_glass.gdshader")

	_foliage_mat = ShaderMaterial.new()
	_foliage_mat.shader = load("res://shaders/foliage_wind.gdshader")
	_foliage_mat.set_shader_parameter("leaf_color", Color(0.12, 0.17, 0.11))
	_foliage_mat.set_shader_parameter("tip_color", Color(0.30, 0.4, 0.20))
	_foliage_mat.set_shader_parameter("wind_strength", 0.05)
	_foliage_mat.set_shader_parameter("wind_speed", 1.45)

	_tree_trunk_mat = StandardMaterial3D.new()
	_tree_trunk_mat.albedo_color = Color(0.16, 0.12, 0.09)
	_tree_trunk_mat.roughness = 0.86

	_tree_leaf_mat = StandardMaterial3D.new()
	_tree_leaf_mat.albedo_color = Color(0.13, 0.18, 0.12)
	_tree_leaf_mat.roughness = 0.9

	_rock_mat = StandardMaterial3D.new()
	_rock_mat.albedo_color = Color(0.28, 0.29, 0.30)
	_rock_mat.roughness = 0.95

func _create_weathered_mat(
	shader: Shader,
	base_color: Color,
	moss_color: Color,
	wet_dark_color: Color,
	wetness: float,
	grunge_scale: float,
	moss_amount: float,
	rough_dry: float,
	rough_wet: float
) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("base_color", base_color)
	mat.set_shader_parameter("moss_color", moss_color)
	mat.set_shader_parameter("wet_dark_color", wet_dark_color)
	mat.set_shader_parameter("wetness", wetness)
	mat.set_shader_parameter("grunge_scale", grunge_scale)
	mat.set_shader_parameter("moss_amount", moss_amount)
	mat.set_shader_parameter("roughness_dry", rough_dry)
	mat.set_shader_parameter("roughness_wet", rough_wet)
	return mat

func _create_ground() -> void:
	var ground_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(village_radius * 2.0, village_radius * 2.0)
	plane.subdivide_width = 20
	plane.subdivide_depth = 20
	ground_mesh.mesh = plane
	ground_mesh.material_override = _ground_shader_mat
	add_child(ground_mesh)

	var ground_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(village_radius * 2.0, 1.0, village_radius * 2.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	ground_body.add_child(shape)
	add_child(ground_body)

func _create_ruined_houses() -> void:
	var positions: Array[Vector3] = [
		Vector3(14.0, 0.0, -10.0),
		Vector3(-18.0, 0.0, -8.0),
		Vector3(10.0, 0.0, 20.0),
		Vector3(-12.0, 0.0, 25.0),
		Vector3(28.0, 0.0, 16.0),
		Vector3(-30.0, 0.0, 2.0)
	]
	var rotations: Array[float] = [-0.3, 0.45, 1.1, -1.4, 0.7, -0.9]

	for i in range(positions.size()):
		_create_ruined_house(positions[i], rotations[i])

func _create_ruined_house(origin: Vector3, y_rot: float) -> void:
	var house: Node3D = Node3D.new()
	house.position = origin
	house.rotation.y = y_rot
	add_child(house)

	_add_box_segment(house, Vector3(6.0, 0.2, 6.0), Vector3(0.0, 0.1, 0.0), Vector3.ZERO, _wall_mat, true)

	var h: float = 2.8
	var t: float = 0.22

	_add_box_segment(house, Vector3(6.0, h, t), Vector3(0.0, h * 0.5, -3.0), Vector3.ZERO, _wall_mat, true)
	_add_box_segment(house, Vector3(t, h, 6.0), Vector3(-3.0, h * 0.5, 0.0), Vector3.ZERO, _wall_mat, true)
	_add_box_segment(house, Vector3(t, h, 6.0), Vector3(3.0, h * 0.5, 0.0), Vector3.ZERO, _wall_mat, true)

	_add_box_segment(house, Vector3(2.1, h, t), Vector3(-1.95, h * 0.5, 3.0), Vector3.ZERO, _wall_mat, true)
	_add_box_segment(house, Vector3(2.1, h, t), Vector3(1.95, h * 0.5, 3.0), Vector3.ZERO, _wall_mat, true)
	_add_box_segment(house, Vector3(1.8, 0.7, t), Vector3(0.0, 0.35, 3.0), Vector3.ZERO, _wall_mat, true)
	_add_box_segment(house, Vector3(1.8, 1.0, t), Vector3(0.0, 2.3, 3.0), Vector3.ZERO, _wall_mat, true)

	_add_box_segment(house, Vector3(4.8, 0.15, 2.1), Vector3(-0.8, 2.9, -1.1), Vector3(0.16, 0.25, -0.1), _roof_mat, true)
	_add_box_segment(house, Vector3(2.5, 0.15, 1.5), Vector3(1.5, 2.5, 1.0), Vector3(-0.1, -0.2, 0.1), _roof_mat, true)

	var window_glass: MeshInstance3D = MeshInstance3D.new()
	var glass: QuadMesh = QuadMesh.new()
	glass.size = Vector2(1.2, 1.1)
	window_glass.mesh = glass
	window_glass.material_override = _glass_shader_mat
	window_glass.position = Vector3(0.0, 1.25, 2.88)
	window_glass.rotation = Vector3(0.0, PI, 0.0)
	house.add_child(window_glass)

	_add_box_segment(house, Vector3(1.3, 0.12, 0.12), Vector3(0.0, 1.86, 2.94), Vector3.ZERO, _wood_mat, false)
	_add_box_segment(house, Vector3(1.3, 0.12, 0.12), Vector3(0.0, 0.72, 2.94), Vector3.ZERO, _wood_mat, false)
	_add_box_segment(house, Vector3(0.12, 1.28, 0.12), Vector3(-0.64, 1.28, 2.94), Vector3.ZERO, _wood_mat, false)
	_add_box_segment(house, Vector3(0.12, 1.28, 0.12), Vector3(0.64, 1.28, 2.94), Vector3.ZERO, _wood_mat, false)

func _create_graves() -> void:
	var grave_root: Node3D = Node3D.new()
	grave_root.name = "Graves"
	grave_root.position = Vector3(-30.0, 0.0, 10.0)
	add_child(grave_root)

	var grave_mesh: BoxMesh = BoxMesh.new()
	grave_mesh.size = Vector3(0.42, 1.05, 0.14)

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = grave_count
	mm.mesh = grave_mesh

	for i in range(grave_count):
		var local_pos: Vector3 = Vector3(randf_range(-12.0, 12.0), 0.52, randf_range(-18.0, 18.0))
		var basis: Basis = Basis.from_euler(Vector3(0.0, randf_range(-0.35, 0.35), randf_range(-0.05, 0.08)))
		var xform: Transform3D = Transform3D(basis, local_pos)
		xform = xform.scaled_local(Vector3(randf_range(0.9, 1.2), randf_range(0.75, 1.35), 1.0))
		mm.set_instance_transform(i, xform)

		if i % 15 == 0:
			var col: StaticBody3D = StaticBody3D.new()
			var shape: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(0.55, 1.1, 0.28)
			shape.shape = box
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
		var trunk_h: float = randf_range(2.4, 4.2)
		var trunk_scale: float = randf_range(0.85, 1.2)

		var trunk_basis: Basis = Basis(Vector3.UP, randf_range(-PI, PI)).scaled(Vector3(trunk_scale, trunk_h, trunk_scale))
		var trunk_xf: Transform3D = Transform3D(trunk_basis, Vector3(p.x, trunk_h * 0.5, p.z))
		trunk_mm.set_instance_transform(i, trunk_xf)

		var crown_scale: float = randf_range(1.0, 1.45)
		var crown_basis: Basis = Basis(Vector3.UP, randf_range(-PI, PI)).scaled(Vector3(crown_scale * 1.4, crown_scale, crown_scale * 1.25))
		var crown_xf: Transform3D = Transform3D(crown_basis, Vector3(p.x, trunk_h + crown_scale * 0.55, p.z))
		crown_mm.set_instance_transform(i, crown_xf)

		if i % 10 == 0:
			var body: StaticBody3D = StaticBody3D.new()
			var shape: CollisionShape3D = CollisionShape3D.new()
			var trunk_shape: CylinderShape3D = CylinderShape3D.new()
			trunk_shape.radius = 0.35 * trunk_scale
			trunk_shape.height = trunk_h
			shape.shape = trunk_shape
			shape.position = Vector3(p.x, trunk_h * 0.5, p.z)
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

	var blade_mesh: QuadMesh = QuadMesh.new()
	blade_mesh.size = Vector2(0.24, 0.95)

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = grass_count
	mm.mesh = blade_mesh

	for i in range(grass_count):
		var p: Vector3 = _random_ring_position(6.0, village_radius - 5.0)
		var h: float = randf_range(0.65, 1.35)
		var yaw: float = randf_range(-PI, PI)
		var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3(randf_range(0.8, 1.15), h, 1.0))
		var xf: Transform3D = Transform3D(basis, Vector3(p.x, h * 0.5, p.z))
		mm.set_instance_transform(i, xf)

	var mm_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm_instance.multimesh = mm
	mm_instance.material_override = _foliage_mat
	grass_root.add_child(mm_instance)

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
		var s: float = randf_range(0.45, 1.2)
		var basis: Basis = Basis.from_euler(Vector3(randf_range(-0.2, 0.2), randf_range(-PI, PI), randf_range(-0.25, 0.25))).scaled(Vector3(s * 1.25, s * 0.65, s))
		var xf: Transform3D = Transform3D(basis, Vector3(p.x, s * 0.22, p.z))
		mm.set_instance_transform(i, xf)

	var mm_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm_instance.multimesh = mm
	mm_instance.material_override = _rock_mat
	rock_root.add_child(mm_instance)

func _random_ring_position(min_radius: float, max_radius: float) -> Vector3:
	var a: float = randf() * TAU
	var rr: float = sqrt(randf())
	var r: float = min_radius + rr * (max_radius - min_radius)
	return Vector3(cos(a) * r, 0.0, sin(a) * r)

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
