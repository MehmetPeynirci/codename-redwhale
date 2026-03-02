shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.13, 0.13, 0.14);
uniform vec3 flake_tint : source_color = vec3(0.34, 0.36, 0.40);
uniform float flake_density = 180.0;
uniform float clearcoat_strength = 0.92;
uniform float rain_streak_strength = 0.16;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV * flake_density;
	float flakes = hash12(floor(uv));
	float rain = sin((UV.y * 50.0) + TIME * 8.0 + UV.x * 7.0) * 0.5 + 0.5;
	float streak = smoothstep(0.68, 1.0, rain) * rain_streak_strength;

	vec3 paint = mix(base_color, flake_tint, smoothstep(0.82, 1.0, flakes) * 0.22);
	paint = mix(paint, paint * 0.75, streak);

	ALBEDO = paint;
	METALLIC = 0.88;
	ROUGHNESS = clamp(0.25 - streak * 0.16, 0.06, 0.32);
	SPECULAR = clearcoat_strength;
}
