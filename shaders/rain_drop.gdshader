shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 drop_tint : source_color = vec4(0.77, 0.84, 0.95, 0.5);

void fragment() {
	float center = 1.0 - abs(UV.x - 0.5) * 2.0;
	float body = smoothstep(0.0, 0.25, UV.y) * (1.0 - smoothstep(0.65, 1.0, UV.y));
	float flicker = 0.85 + 0.15 * sin(TIME * 30.0 + UV.y * 24.0);
	ALBEDO = drop_tint.rgb;
	ALPHA = center * body * drop_tint.a * flicker;
}
