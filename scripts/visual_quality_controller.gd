extends Node3D

@export var world_environment_path: NodePath = NodePath("WorldEnvironment")
@export var directional_light_path: NodePath = NodePath("DirectionalLight3D")
@export var fast_start_quality: bool = false

func _ready() -> void:
	var world_env: WorldEnvironment = get_node_or_null(world_environment_path) as WorldEnvironment
	if world_env != null and world_env.environment != null:
		_apply_environment_quality(world_env.environment)

	var sun: DirectionalLight3D = get_node_or_null(directional_light_path) as DirectionalLight3D
	if sun != null:
		_apply_sun_quality(sun)

func _apply_environment_quality(env: Environment) -> void:
	_safe_set(env, &"tonemap_mode", Environment.TONE_MAPPER_ACES)
	_safe_set(env, &"tonemap_exposure", 0.64)
	_safe_set(env, &"tonemap_white", 4.9)

	_safe_set(env, &"adjustment_enabled", true)
	_safe_set(env, &"adjustment_brightness", 0.72)
	_safe_set(env, &"adjustment_contrast", 1.11)
	_safe_set(env, &"adjustment_saturation", 0.87)

	_safe_set(env, &"fog_enabled", true)
	_safe_set(env, &"fog_density", 0.011)
	_safe_set(env, &"fog_height", -0.1)
	_safe_set(env, &"fog_height_density", 0.2)
	_safe_set(env, &"fog_light_energy", 0.22)
	_safe_set(env, &"fog_light_color", Color(0.17, 0.22, 0.31, 1.0))

	if fast_start_quality:
		_safe_set(env, &"volumetric_fog_enabled", true)
		_safe_set(env, &"volumetric_fog_density", 0.013)
		_safe_set(env, &"volumetric_fog_detail_spread", 10.0)
		_safe_set(env, &"volumetric_fog_anisotropy", 0.4)
		_safe_set(env, &"ssao_enabled", true)
		_safe_set(env, &"ssao_radius", 1.8)
		_safe_set(env, &"ssao_intensity", 1.95)
		_safe_set(env, &"ssao_power", 1.75)
		_safe_set(env, &"ssao_detail", 0.62)
		_safe_set(env, &"ssil_enabled", true)
		_safe_set(env, &"ssil_radius", 4.2)
		_safe_set(env, &"ssil_intensity", 1.15)
		_safe_set(env, &"ssil_sharpness", 0.86)
		_safe_set(env, &"sdfgi_enabled", false)
		_safe_set(env, &"ssr_enabled", true)
		_safe_set(env, &"ssr_max_steps", 64)
		_safe_set(env, &"ssr_depth_tolerance", 0.22)
	else:
		_safe_set(env, &"volumetric_fog_enabled", true)
		_safe_set(env, &"volumetric_fog_density", 0.015)
		_safe_set(env, &"volumetric_fog_detail_spread", 10.0)
		_safe_set(env, &"volumetric_fog_anisotropy", 0.45)

		_safe_set(env, &"ssao_enabled", true)
		_safe_set(env, &"ssao_radius", 2.5)
		_safe_set(env, &"ssao_intensity", 2.6)
		_safe_set(env, &"ssao_power", 2.05)
		_safe_set(env, &"ssao_detail", 0.76)

		_safe_set(env, &"ssil_enabled", true)
		_safe_set(env, &"ssil_radius", 6.0)
		_safe_set(env, &"ssil_intensity", 1.55)
		_safe_set(env, &"ssil_sharpness", 0.95)

		_safe_set(env, &"sdfgi_enabled", true)
		_safe_set(env, &"sdfgi_use_occlusion", true)
		_safe_set(env, &"sdfgi_use_multibounce", true)
		_safe_set(env, &"sdfgi_read_sky_light", true)

		_safe_set(env, &"ssr_enabled", true)
		_safe_set(env, &"ssr_max_steps", 128)
		_safe_set(env, &"ssr_depth_tolerance", 0.18)

	_safe_set(env, &"glow_enabled", true)
	_safe_set(env, &"glow_intensity", 0.28)
	_safe_set(env, &"glow_strength", 0.35)
	_safe_set(env, &"glow_bloom", 0.04)

func _apply_sun_quality(sun: DirectionalLight3D) -> void:
	_safe_set(sun, &"light_energy", 0.16)
	_safe_set(sun, &"light_indirect_energy", 0.2)
	_safe_set(sun, &"light_color", Color(0.48, 0.56, 0.74, 1.0))
	_safe_set(sun, &"shadow_enabled", true)
	_safe_set(sun, &"shadow_blur", 2.0)
	_safe_set(sun, &"shadow_bias", 0.025)
	_safe_set(sun, &"shadow_normal_bias", 1.0)
	_safe_set(sun, &"directional_shadow_mode", DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	_safe_set(sun, &"directional_shadow_max_distance", 190.0)
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
