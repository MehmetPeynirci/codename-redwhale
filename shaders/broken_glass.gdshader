shader_type spatial;
render_mode cull_disabled, blend_mix, depth_prepass_alpha;

uniform vec4 tint : source_color = vec4(0.72, 0.8, 0.85, 0.28);
uniform float crack_density = 22.0;

void fragment() {
	vec2 uv = UV;
	float crack = abs(sin(uv.x * crack_density) * cos(uv.y * (crack_density * 0.7)));
	float shards = step(0.45, crack);
	float edge_fade = smoothstep(0.0, 0.06, uv.x) * smoothstep(0.0, 0.06, 1.0 - uv.x);
	edge_fade *= smoothstep(0.0, 0.06, uv.y) * smoothstep(0.0, 0.06, 1.0 - uv.y);

	ALBEDO = tint.rgb;
	ROUGHNESS = 0.03;
	METALLIC = 0.0;
	SPECULAR = 0.95;
	ALPHA = shards * tint.a * edge_fade;
}
