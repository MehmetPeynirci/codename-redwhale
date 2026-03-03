shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float gain : hint_range(0.4, 2.4) = 1.55;
uniform float overlay_alpha : hint_range(0.0, 1.0) = 0.78;
uniform float grain_strength : hint_range(0.0, 0.4) = 0.085;
uniform float scanline_strength : hint_range(0.0, 0.4) = 0.12;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;
uniform float horizontal_distortion : hint_range(0.0, 0.02) = 0.0035;
uniform float phosphor_trail : hint_range(0.0, 1.0) = 0.28;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float line_jitter = (hash12(vec2(floor(uv.y * 420.0), TIME * 16.0)) - 0.5) * horizontal_distortion;
	vec2 sample_uv = uv + vec2(line_jitter, 0.0);
	vec3 src = texture(screen_tex, sample_uv).rgb;

	float luma = dot(src, vec3(0.2126, 0.7152, 0.0722));
	float noise = hash12(vec2(uv.x * 1783.0 + TIME * 17.0, uv.y * 1337.0 - TIME * 21.0)) - 0.5;
	float scan = sin((uv.y + TIME * 0.12) * 980.0) * 0.5 + 0.5;
	float trail = texture(screen_tex, sample_uv - vec2(0.0, SCREEN_PIXEL_SIZE.y * 1.8)).g;

	float boosted = clamp(max(luma * gain, trail * phosphor_trail) + noise * grain_strength, 0.0, 1.0);
	vec3 nv_col = vec3(0.09, 1.0, 0.22) * boosted;
	nv_col *= 0.86 + scan * scanline_strength;

	float dist = distance(uv, vec2(0.5));
	float vignette = 1.0 - smoothstep(0.35, 0.76, dist);
	vignette = mix(1.0, vignette, vignette_strength);

	COLOR = vec4(nv_col * vignette, overlay_alpha);
}
