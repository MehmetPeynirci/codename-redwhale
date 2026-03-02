shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx;

uniform vec3 leaf_color : source_color = vec3(0.15, 0.20, 0.12);
uniform vec3 tip_color : source_color = vec3(0.31, 0.42, 0.18);
uniform float wind_strength = 0.06;
uniform float wind_speed = 1.7;
uniform float alpha_cut = 0.4;

void vertex() {
	float bend_mask = clamp(UV.y, 0.0, 1.0);
	float wave = sin(TIME * wind_speed + UV.x * 5.5 + VERTEX.y * 2.3);
	VERTEX.x += wave * wind_strength * bend_mask;
}

void fragment() {
	float blade = smoothstep(0.04, 0.2, UV.x) * (1.0 - smoothstep(0.8, 0.96, UV.x));
	float tip = smoothstep(0.45, 1.0, UV.y);
	float alpha = blade * (1.0 - smoothstep(0.96, 1.0, UV.y));

	ALBEDO = mix(leaf_color, tip_color, tip);
	ROUGHNESS = 0.85;
	SPECULAR = 0.12;
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
}
