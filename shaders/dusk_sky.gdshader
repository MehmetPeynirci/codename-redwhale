shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.22, 0.34, 0.56);
uniform vec3 horizon_color : source_color = vec3(0.98, 0.56, 0.36);
uniform vec3 ground_haze_color : source_color = vec3(0.96, 0.67, 0.47);
uniform vec3 sun_color : source_color = vec3(1.0, 0.83, 0.62);
uniform vec3 sun_direction = vec3(-0.36, 0.22, -0.90);
uniform float sun_size : hint_range(0.004, 0.08) = 0.022;
uniform float sun_glow : hint_range(0.0, 4.0) = 1.7;
uniform float haze_strength : hint_range(0.0, 1.0) = 0.62;
uniform float cloud_strength : hint_range(0.0, 1.0) = 0.24;
uniform float sky_exposure : hint_range(0.2, 2.4) = 1.05;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));

	float ab = mix(a, b, f.x);
	float cd = mix(c, d, f.x);
	return mix(ab, cd, f.y);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);

	vec3 base = mix(horizon_color, zenith_color, pow(up, 1.2));
	float haze_mask = smoothstep(-0.15, 0.35, dir.y);
	base = mix(ground_haze_color, base, haze_mask);

	vec3 sun_dir = normalize(sun_direction);
	float sun_dot = dot(dir, sun_dir);
	float sun_disk = smoothstep(cos(sun_size), cos(sun_size * 0.6), sun_dot);
	float sun_halo = smoothstep(cos(sun_size * 9.0), cos(sun_size * 1.2), sun_dot) - sun_disk;
	base += sun_color * sun_disk * 1.4;
	base += sun_color * sun_halo * sun_glow * 0.42;

	vec2 uv = vec2(atan(dir.x, dir.z) / (PI * 2.0) + 0.5, acos(clamp(dir.y, -1.0, 1.0)) / PI);
	float c0 = value_noise(uv * 6.0 + vec2(TIME * 0.004, 0.0));
	float c1 = value_noise(uv * 12.0 + vec2(TIME * 0.006, 0.0));
	float clouds = smoothstep(0.62, 0.85, c0 * 0.68 + c1 * 0.32);
	float cloud_fade = smoothstep(-0.05, 0.45, dir.y);
	base = mix(base, base + vec3(0.12, 0.09, 0.08), clouds * cloud_strength * cloud_fade);

	base = mix(base, base * vec3(1.0, 0.95, 0.9), haze_strength * (1.0 - haze_mask));
	COLOR = base * sky_exposure;
}
