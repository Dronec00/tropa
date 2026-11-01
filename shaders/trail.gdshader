shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D ground_tex : source_color, repeat_enable;
uniform sampler2D noise_tex : hint_default_white, repeat_enable;
uniform vec3 trail_color : source_color = vec3(0.22, 0.17, 0.12);

void fragment() {
	vec3 g = texture(ground_tex, UV * vec2(1.2, 7.0)).rgb;
	vec3 col = mix(g * 0.9, trail_color, 0.72);
	float u = UV.x;
	float edge = smoothstep(0.0, 0.34, u) * smoothstep(1.0, 0.66, u);
	float n = texture(noise_tex, UV * vec2(2.2, 9.0)).r;
	float n2 = texture(noise_tex, UV * vec2(5.5, 20.0)).r;
	float mask = edge * smoothstep(0.24, 0.58, n * 0.65 + n2 * 0.45 + edge * 0.30);
	ALBEDO = col * (0.85 + 0.35 * n);
	ROUGHNESS = 1.0;
	ALPHA = clamp(mask, 0.0, 1.0) * 0.9;
}
