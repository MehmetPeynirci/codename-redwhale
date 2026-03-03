shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.13, 0.13, 0.14);
uniform vec3 flake_tint : source_color = vec3(0.34, 0.36, 0.40);
uniform float flake_density = 150.0;
uniform float flake_intensity = 0.24;
uniform float clearcoat_strength = 0.92;
uniform float wetness = 0.28;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV * flake_density;
	float flakes = hash12(floor(uv));
	float flake_mask = smoothstep(0.81, 1.0, flakes);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.2);

	vec3 paint = base_color;
	paint += flake_tint * flake_mask * flake_intensity;
	paint = mix(paint, paint * 0.82, wetness * 0.24);

	ALBEDO = paint;
	METALLIC = 0.93;
	ROUGHNESS = clamp(0.23 - flake_mask * 0.05 - fresnel * 0.08 - wetness * 0.09, 0.045, 0.32);
	SPECULAR = clamp(clearcoat_strength + fresnel * 0.14, 0.0, 1.0);
	RIM = fresnel * (0.05 + wetness * 0.08);
	RIM_TINT = 0.34;
}
