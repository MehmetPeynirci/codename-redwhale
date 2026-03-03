shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.01, 0.015, 0.037);
uniform vec3 horizon_color : source_color = vec3(0.024, 0.036, 0.069);
uniform vec3 moon_color : source_color = vec3(0.82, 0.88, 0.98);
uniform vec3 moon_direction = vec3(-0.56, 0.23, -0.8);
uniform float moon_size : hint_range(0.01, 0.12) = 0.045;
uniform float moon_glow : hint_range(0.0, 2.0) = 0.58;
uniform float star_density : hint_range(200.0, 2400.0) = 1450.0;
uniform float star_intensity : hint_range(0.0, 2.0) = 1.02;
uniform float twinkle_speed : hint_range(0.0, 8.0) = 1.8;
uniform float sky_exposure : hint_range(0.2, 2.0) = 1.03;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);

	vec3 col = mix(horizon_color, zenith_color, pow(up, 1.55));
	float sky_mask = smoothstep(-0.08, 0.18, dir.y);

	float tau = PI * 2.0;
	vec2 uv = vec2(atan(dir.x, dir.z) / tau + 0.5, acos(clamp(dir.y, -1.0, 1.0)) / PI);
	vec2 grid = uv * star_density;
	vec2 cell = floor(grid);
	vec2 f = fract(grid);

	float rnd = hash12(cell);
	float sparkle = smoothstep(0.9981, 1.0, rnd);
	float star_shape = smoothstep(0.34, 0.0, length(f - vec2(0.5)));
	float twinkle = 0.6 + 0.4 * sin(TIME * twinkle_speed + rnd * 90.0);
	float star = sparkle * star_shape * twinkle * sky_mask;

	vec3 star_color = mix(vec3(0.72, 0.8, 1.0), vec3(1.0), hash12(cell + 13.0));
	col += star_color * star * star_intensity;

	vec3 moon_dir = normalize(moon_direction);
	float mdot = dot(dir, moon_dir);
	float moon_disk = smoothstep(cos(moon_size), cos(moon_size * 0.35), mdot);
	float moon_halo = smoothstep(cos(moon_size * 3.5), cos(moon_size * 0.55), mdot) - moon_disk;
	col += moon_color * moon_disk;
	col += moon_color * moon_halo * moon_glow * 0.5;

	col += vec3(0.02, 0.028, 0.05) * pow(sky_mask, 2.0) * 0.25;
	COLOR = col * sky_exposure;
}
