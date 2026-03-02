extends Node3D

@export var grave_count: int = 120
@export var village_radius: float = 85.0

var _wall_mat: StandardMaterial3D
var _roof_mat: StandardMaterial3D
var _wood_mat: StandardMaterial3D
var _grave_mat: StandardMaterial3D
var _ground_shader_mat: ShaderMaterial
var _glass_shader_mat: ShaderMaterial

func _ready() -> void:
	randomize()
	_build_materials()
	_create_ground()
	_create_ruined_houses()
	_create_graves()

func _build_materials() -> void:
	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_color = Color(0.22, 0.22, 0.21)
	_wall_mat.roughness = 0.9

	_roof_mat = StandardMaterial3D.new()
	_roof_mat.albedo_color = Color(0.12, 0.11, 0.1)
	_roof_mat.roughness = 0.8

	_wood_mat = StandardMaterial3D.new()
	_wood_mat.albedo_color = Color(0.18, 0.14, 0.1)
	_wood_mat.roughness = 0.76

	_grave_mat = StandardMaterial3D.new()
	_grave_mat.albedo_color = Color(0.35, 0.36, 0.37)
	_grave_mat.roughness = 0.94

	_ground_shader_mat = ShaderMaterial.new()
	_ground_shader_mat.shader = load("res://shaders/wet_ground.gdshader")

	_glass_shader_mat = ShaderMaterial.new()
	_glass_shader_mat.shader = load("res://shaders/broken_glass.gdshader")

func _create_ground() -> void:
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(village_radius * 2.0, village_radius * 2.0)
	plane.subdivide_width = 10
	plane.subdivide_depth = 10
	ground_mesh.mesh = plane
	ground_mesh.material_override = _ground_shader_mat
	add_child(ground_mesh)

	var ground_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(village_radius * 2.0, 1.0, village_radius * 2.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	ground_body.add_child(shape)
	add_child(ground_body)

func _create_ruined_houses() -> void:
	var layouts := [
		{ "pos": Vector3(14.0, 0.0, -10.0), "rot": -0.3 },
		{ "pos": Vector3(-18.0, 0.0, -8.0), "rot": 0.45 },
		{ "pos": Vector3(10.0, 0.0, 20.0), "rot": 1.1 },
		{ "pos": Vector3(-12.0, 0.0, 25.0), "rot": -1.4 }
	]

	for layout in layouts:
		_create_ruined_house(layout["pos"], layout["rot"])

func _create_ruined_house(origin: Vector3, y_rot: float) -> void:
	var house := Node3D.new()
	house.position = origin
	house.rotation.y = y_rot
	add_child(house)

	_add_box_segment(house, Vector3(6.0, 0.2, 6.0), Vector3(0.0, 0.1, 0.0), Vector3.ZERO, _wall_mat, true)

	var h := 2.8
	var t := 0.22

	_add_box_segment(house, Vector3(6.0, h, t), Vector3(0.0, h * 0.5, -3.0), Vector3.ZERO, _wall_mat, true)
	_add_box_segment(house, Vector3(t, h, 6.0), Vector3(-3.0, h * 0.5, 0.0), Vector3.ZERO, _wall_mat, true)
	_add_box_segment(house, Vector3(t, h, 6.0), Vector3(3.0, h * 0.5, 0.0), Vector3.ZERO, _wall_mat, true)

	_add_box_segment(house, Vector3(2.1, h, t), Vector3(-1.95, h * 0.5, 3.0), Vector3.ZERO, _wall_mat, true)
	_add_box_segment(house, Vector3(2.1, h, t), Vector3(1.95, h * 0.5, 3.0), Vector3.ZERO, _wall_mat, true)
	_add_box_segment(house, Vector3(1.8, 0.7, t), Vector3(0.0, 0.35, 3.0), Vector3.ZERO, _wall_mat, true)
	_add_box_segment(house, Vector3(1.8, 1.0, t), Vector3(0.0, 2.3, 3.0), Vector3.ZERO, _wall_mat, true)

	_add_box_segment(house, Vector3(4.8, 0.15, 2.1), Vector3(-0.8, 2.9, -1.1), Vector3(0.16, 0.25, -0.1), _roof_mat, true)
	_add_box_segment(house, Vector3(2.5, 0.15, 1.5), Vector3(1.5, 2.5, 1.0), Vector3(-0.1, -0.2, 0.1), _roof_mat, true)

	var window_glass := MeshInstance3D.new()
	var glass := QuadMesh.new()
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
	var grave_root := Node3D.new()
	grave_root.position = Vector3(-30.0, 0.0, 10.0)
	add_child(grave_root)

	var grave_mesh := BoxMesh.new()
	grave_mesh.size = Vector3(0.42, 1.05, 0.14)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = grave_count
	mm.mesh = grave_mesh

	for i in range(grave_count):
		var local_pos := Vector3(randf_range(-12.0, 12.0), 0.52, randf_range(-18.0, 18.0))
		var basis := Basis.from_euler(Vector3(0.0, randf_range(-0.35, 0.35), randf_range(-0.05, 0.08)))
		var xform := Transform3D(basis, local_pos)
		xform = xform.scaled_local(Vector3(randf_range(0.9, 1.2), randf_range(0.75, 1.35), 1.0))
		mm.set_instance_transform(i, xform)

		if i % 12 == 0:
			var col := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.55, 1.1, 0.28)
			shape.shape = box
			shape.position = local_pos
			shape.rotation = Vector3(0.0, basis.get_euler().y, 0.0)
			col.add_child(shape)
			grave_root.add_child(col)

	var mm_instance := MultiMeshInstance3D.new()
	mm_instance.multimesh = mm
	mm_instance.material_override = _grave_mat
	grave_root.add_child(mm_instance)

func _add_box_segment(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material, add_collision: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.rotation = rot
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)

	if add_collision:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = pos
		shape.rotation = rot
		body.add_child(shape)
		parent.add_child(body)
