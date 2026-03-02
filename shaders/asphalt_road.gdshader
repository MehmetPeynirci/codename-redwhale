shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 asphalt_dark : source_color = vec3(0.07, 0.075, 0.08);
uniform vec3 asphalt_mid : source_color = vec3(0.14, 0.145, 0.15);
uniform vec3 wet_tint : source_color = vec3(0.09, 0.1, 0.11);
uniform float grain_scale = 28.0;
uniform float crack_scale = 6.0;
uniform float wetness = 0.34;
uniform float rough_dry = 0.86;
uniform float rough_wet = 0.2;
uniform float stripe_strength = 0.09;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec2 uv = UV * grain_scale;
	float base_noise = noise2(uv);
	float detail_noise = noise2(uv * 2.3 + vec2(13.1, 7.6));
	float crack_mask = smoothstep(0.63, 0.82, noise2(UV * crack_scale + vec2(19.0, 9.0)));

	float tonal = clamp(base_noise * 0.65 + detail_noise * 0.35, 0.0, 1.0);
	vec3 asphalt = mix(asphalt_dark, asphalt_mid, tonal);
	asphalt = mix(asphalt, wet_tint, wetness * (0.5 + tonal * 0.5));
	asphalt -= crack_mask * 0.08;

	float lane_hint = exp(-pow((UV.x - 0.5) * 4.5, 2.0));
	asphalt += vec3(stripe_strength * lane_hint * (0.4 + 0.6 * sin(UV.y * 42.0)));

	ALBEDO = asphalt;
	ROUGHNESS = mix(rough_dry, rough_wet, wetness * (0.55 + crack_mask * 0.3));
	SPECULAR = mix(0.28, 0.72, wetness);
	METALLIC = 0.0;
}
