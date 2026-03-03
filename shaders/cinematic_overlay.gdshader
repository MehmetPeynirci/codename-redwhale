shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float grain_strength : hint_range(0.0, 0.15) = 0.028;
uniform float grain_speed : hint_range(0.0, 4.0) = 1.2;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.32;
uniform float chromatic_aberration : hint_range(0.0, 0.004) = 0.0011;
uniform float contrast : hint_range(0.8, 1.4) = 1.06;
uniform float saturation : hint_range(0.7, 1.4) = 1.03;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = uv - vec2(0.5);
	float dist = length(center);
	vec2 dir = center / max(dist, 0.0001);
	vec2 shift = dir * chromatic_aberration * dist;

	float r = texture(screen_tex, uv + shift).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - shift).b;
	vec3 col = vec3(r, g, b);

	vec2 viewport_size = vec2(1.0) / SCREEN_PIXEL_SIZE;
	vec2 grain_uv = uv * viewport_size * 0.5 + vec2(TIME * grain_speed, TIME * grain_speed * 0.63);
	float grain = hash12(grain_uv) * 2.0 - 1.0;
	col += grain * grain_strength;

	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(lum), col, saturation);
	col = (col - 0.5) * contrast + 0.5;

	float vignette = smoothstep(0.28, 0.92, dist);
	col *= 1.0 - vignette * vignette_strength;

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
