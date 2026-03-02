extends Node3D

@export var follow_height: float = 14.0
@export var rain_area_size: float = 36.0
@export var rain_amount: int = 4200
@export var splash_amount: int = 950
@export var target_group: StringName = &"player"

var _target: Node3D
var _particles: GPUParticles3D
var _splash_particles: GPUParticles3D

func _ready() -> void:
	_build_rain_particles()
	_build_splash_particles()
	_find_target()

func _process(_delta: float) -> void:
	if not is_instance_valid(_target):
		_find_target()
		return

	var target_pos := _target.global_position
	global_position = Vector3(target_pos.x, target_pos.y + follow_height, target_pos.z)

func _find_target() -> void:
	var candidates := get_tree().get_nodes_in_group(target_group)
	if not candidates.is_empty() and candidates[0] is Node3D:
		_target = candidates[0]

func _build_rain_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.amount = rain_amount
	_particles.lifetime = 1.2
	_particles.one_shot = false
	_particles.emitting = true
	_particles.local_coords = true
	_particles.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
	_particles.visibility_aabb = AABB(
		Vector3(-rain_area_size * 0.5, -follow_height, -rain_area_size * 0.5),
		Vector3(rain_area_size, follow_height * 2.0, rain_area_size)
	)

	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 2.5
	process.gravity = Vector3(0.0, -35.0, 0.0)
	process.initial_velocity_min = 18.0
	process.initial_velocity_max = 27.0
	process.scale_min = 0.75
	process.scale_max = 1.3
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(rain_area_size * 0.5, 0.3, rain_area_size * 0.5)
	_particles.process_material = process

	var drop_mesh := QuadMesh.new()
	drop_mesh.size = Vector2(0.015, 0.55)
	_particles.draw_pass_1 = drop_mesh

	var drop_shader := ShaderMaterial.new()
	drop_shader.shader = load("res://shaders/rain_drop.gdshader")
	_particles.material_override = drop_shader

	add_child(_particles)

func _build_splash_particles() -> void:
	_splash_particles = GPUParticles3D.new()
	_splash_particles.amount = splash_amount
	_splash_particles.lifetime = 0.45
	_splash_particles.one_shot = false
	_splash_particles.emitting = true
	_splash_particles.local_coords = true
	_splash_particles.position = Vector3(0.0, -follow_height + 0.35, 0.0)
	_splash_particles.visibility_aabb = AABB(
		Vector3(-rain_area_size * 0.5, -1.0, -rain_area_size * 0.5),
		Vector3(rain_area_size, 2.0, rain_area_size)
	)

	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 25.0
	process.gravity = Vector3(0.0, -11.0, 0.0)
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 2.5
	process.scale_min = 0.35
	process.scale_max = 0.9
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(rain_area_size * 0.5, 0.1, rain_area_size * 0.5)
	_splash_particles.process_material = process

	var splash_mesh := QuadMesh.new()
	splash_mesh.size = Vector2(0.035, 0.035)
	_splash_particles.draw_pass_1 = splash_mesh

	var splash_shader := ShaderMaterial.new()
	splash_shader.shader = load("res://shaders/rain_drop.gdshader")
	_splash_particles.material_override = splash_shader

	add_child(_splash_particles)
