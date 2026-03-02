shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.26, 0.25, 0.24);
uniform vec3 moss_color : source_color = vec3(0.14, 0.20, 0.15);
uniform vec3 wet_dark_color : source_color = vec3(0.08, 0.09, 0.10);
uniform float grunge_scale = 8.0;
uniform float wetness = 0.55;
uniform float moss_amount = 0.35;
uniform float roughness_dry = 0.88;
uniform float roughness_wet = 0.28;
uniform float specular_wet = 0.75;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV * grunge_scale;
	float grime = hash12(floor(uv));
	float moss_mask = smoothstep(0.58, 0.96, grime) * moss_amount;
	float rain_streak = sin(UV.y * 40.0 + TIME * 5.0 + UV.x * 5.0) * 0.5 + 0.5;
	float wet_mask = clamp(wetness * (0.65 + rain_streak * 0.35), 0.0, 1.0);

	vec3 albedo = mix(base_color, moss_color, moss_mask);
	albedo = mix(albedo, wet_dark_color, wet_mask * 0.45);

	ALBEDO = albedo;
	ROUGHNESS = mix(roughness_dry, roughness_wet, wet_mask);
	SPECULAR = mix(0.2, specular_wet, wet_mask);
}
