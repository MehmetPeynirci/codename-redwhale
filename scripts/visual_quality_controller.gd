extends Node3D

@export var world_environment_path: NodePath = NodePath("WorldEnvironment")
@export var directional_light_path: NodePath = NodePath("DirectionalLight3D")

func _ready() -> void:
	var world_env: WorldEnvironment = get_node_or_null(world_environment_path) as WorldEnvironment
	if world_env != null and world_env.environment != null:
		_apply_environment_quality(world_env.environment)

	var sun: DirectionalLight3D = get_node_or_null(directional_light_path) as DirectionalLight3D
	if sun != null:
		_apply_sun_quality(sun)

func _apply_environment_quality(env: Environment) -> void:
	_safe_set(env, &"tonemap_mode", Environment.TONE_MAPPER_ACES)
	_safe_set(env, &"tonemap_exposure", 1.08)
	_safe_set(env, &"tonemap_white", 6.2)

	_safe_set(env, &"adjustment_enabled", true)
	_safe_set(env, &"adjustment_brightness", 0.95)
	_safe_set(env, &"adjustment_contrast", 1.14)
	_safe_set(env, &"adjustment_saturation", 0.93)

	_safe_set(env, &"fog_enabled", true)
	_safe_set(env, &"fog_density", 0.02)
	_safe_set(env, &"fog_height", -0.35)
	_safe_set(env, &"fog_height_density", 0.18)

	_safe_set(env, &"volumetric_fog_enabled", true)
	_safe_set(env, &"volumetric_fog_density", 0.05)
	_safe_set(env, &"volumetric_fog_detail_spread", 8.0)
	_safe_set(env, &"volumetric_fog_anisotropy", 0.35)

	_safe_set(env, &"ssao_enabled", true)
	_safe_set(env, &"ssao_radius", 2.1)
	_safe_set(env, &"ssao_intensity", 2.0)
	_safe_set(env, &"ssao_power", 1.9)
	_safe_set(env, &"ssao_detail", 0.65)

	_safe_set(env, &"ssil_enabled", true)
	_safe_set(env, &"ssil_radius", 5.2)
	_safe_set(env, &"ssil_intensity", 1.35)
	_safe_set(env, &"ssil_sharpness", 0.92)

	_safe_set(env, &"sdfgi_enabled", true)
	_safe_set(env, &"sdfgi_use_occlusion", true)
	_safe_set(env, &"sdfgi_use_multibounce", true)
	_safe_set(env, &"sdfgi_read_sky_light", true)

	_safe_set(env, &"ssr_enabled", true)
	_safe_set(env, &"ssr_max_steps", 96)
	_safe_set(env, &"ssr_depth_tolerance", 0.22)

	_safe_set(env, &"glow_enabled", true)
	_safe_set(env, &"glow_intensity", 0.78)
	_safe_set(env, &"glow_strength", 0.72)
	_safe_set(env, &"glow_bloom", 0.16)

func _apply_sun_quality(sun: DirectionalLight3D) -> void:
	_safe_set(sun, &"light_energy", 0.9)
	_safe_set(sun, &"light_indirect_energy", 1.05)
	_safe_set(sun, &"light_color", Color(0.74, 0.76, 0.79, 1.0))
	_safe_set(sun, &"shadow_enabled", true)
	_safe_set(sun, &"shadow_blur", 1.9)
	_safe_set(sun, &"shadow_bias", 0.03)
	_safe_set(sun, &"shadow_normal_bias", 1.05)
	_safe_set(sun, &"directional_shadow_mode", DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	_safe_set(sun, &"directional_shadow_max_distance", 160.0)
	_safe_set(sun, &"directional_shadow_blend_splits", true)

func _safe_set(target: Object, property_name: StringName, value: Variant) -> void:
	if _has_property(target, property_name):
		target.set(property_name, value)

func _has_property(target: Object, property_name: StringName) -> bool:
	var property_list: Array[Dictionary] = target.get_property_list()
	for entry in property_list:
		var prop_name_value: Variant = entry.get("name", "")
		if StringName(str(prop_name_value)) == property_name:
			return true
	return false
