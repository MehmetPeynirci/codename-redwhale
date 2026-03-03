shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform bool use_pbr_textures = false;
uniform bool use_ao_texture = false;
uniform sampler2D albedo_tex : source_color;
uniform sampler2D normal_tex : hint_normal;
uniform sampler2D roughness_tex : hint_roughness_r;
uniform sampler2D ao_tex : hint_default_white;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec3 base_color : source_color = vec3(0.26, 0.25, 0.24);
uniform vec3 moss_color : source_color = vec3(0.14, 0.20, 0.15);
uniform vec3 wet_dark_color : source_color = vec3(0.08, 0.09, 0.10);
uniform float grunge_scale = 8.0;
uniform float wetness = 0.55;
uniform float moss_amount = 0.35;
uniform float roughness_dry = 0.88;
uniform float roughness_wet = 0.28;
uniform float specular_wet = 0.75;
uniform float normal_strength = 1.0;
uniform float edge_wear = 0.2;
uniform float edge_wear_power = 1.7;
uniform float detail_noise_scale = 14.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 tex_albedo = base_color;
	float tex_roughness = roughness_dry;
	float tex_ao = 1.0;

	if (use_pbr_textures) {
		tex_albedo = texture(albedo_tex, uv).rgb;
		tex_roughness = texture(roughness_tex, uv).r;
		NORMAL_MAP = texture(normal_tex, uv).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	if (use_ao_texture) {
		tex_ao = texture(ao_tex, uv).r;
	}

	float macro_grime = hash12(floor(uv * grunge_scale));
	float micro_grime = hash12(floor(uv * detail_noise_scale + vec2(19.0, 53.0)));
	float grime = mix(macro_grime, micro_grime, 0.36);
	float moss_mask = smoothstep(0.58, 0.96, grime) * moss_amount;
	float rain_streak = sin(UV.y * 40.0 + TIME * 0.55 + UV.x * 5.0) * 0.5 + 0.5;
	float wet_mask = clamp(wetness * (0.65 + rain_streak * 0.35), 0.0, 1.0);
	float side_edge = pow(1.0 - abs(NORMAL.y), edge_wear_power);
	float wear_mask = clamp(side_edge * edge_wear, 0.0, 1.0);

	vec3 albedo = tex_albedo * base_color;
	albedo = mix(albedo, albedo * vec3(0.76, 0.78, 0.8), 0.18);
	albedo = mix(albedo, albedo + vec3(0.04, 0.035, 0.03), wear_mask);
	albedo = mix(albedo, moss_color, moss_mask);
	albedo = mix(albedo, wet_dark_color, wet_mask * 0.45);

	ALBEDO = albedo;
	ROUGHNESS = clamp(mix(max(tex_roughness, roughness_dry), roughness_wet, wet_mask), 0.04, 1.0);
	SPECULAR = mix(0.2, specular_wet, wet_mask);
	AO = clamp(tex_ao * mix(1.0, 0.9, moss_mask), 0.0, 1.0);
}
