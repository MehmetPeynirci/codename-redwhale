shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 mud_color : source_color = vec3(0.19, 0.18, 0.17);
uniform vec3 wet_color : source_color = vec3(0.11, 0.12, 0.13);
uniform float puddle_scale = 0.18;
uniform float puddle_threshold = 0.66;
uniform float puddle_softness = 0.12;
uniform float uv_tiling = 34.0;
uniform float ripple_speed = 4.0;
uniform float ripple_strength = 0.08;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV * uv_tiling;
	float n = hash12(floor(uv * puddle_scale));
	float puddle = smoothstep(puddle_threshold - puddle_softness, puddle_threshold + puddle_softness, n);
	float ripple = sin((uv.x * 2.2 + uv.y * 1.8) + TIME * ripple_speed) * 0.5 + 0.5;
	float wet_mix = clamp(puddle * (0.8 + ripple * 0.2), 0.0, 1.0);

	ALBEDO = mix(mud_color, wet_color, wet_mix);
	ROUGHNESS = mix(0.86, 0.08, wet_mix);
	SPECULAR = mix(0.2, 0.8, wet_mix);
	vec3 ripple_normal = normalize(vec3(cos(uv.x + TIME) * ripple_strength, 1.0, sin(uv.y + TIME * 1.2) * ripple_strength));
	NORMAL = normalize(mix(NORMAL, ripple_normal, wet_mix));
}
