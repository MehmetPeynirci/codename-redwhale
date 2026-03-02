shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 can_color : source_color = vec3(0.78, 0.11, 0.09);
uniform vec3 rust_color : source_color = vec3(0.20, 0.12, 0.07);
uniform float rust_amount = 0.35;
uniform float roughness_val = 0.36;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float rust = smoothstep(0.62, 1.0, hash12(floor(UV * 22.0))) * rust_amount;
	ALBEDO = mix(can_color, rust_color, rust);
	METALLIC = 0.72;
	ROUGHNESS = roughness_val + rust * 0.28;
	SPECULAR = 0.72;
}
