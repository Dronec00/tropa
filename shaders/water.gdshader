shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.14, 0.22, 0.23, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.05, 0.06, 1.0);
uniform vec4 sky_color : source_color = vec4(0.16, 0.21, 0.28, 1.0);
uniform sampler2D ripple : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float flow = 0.035;
uniform float edge_fade = 0.14;

void fragment() {
	vec2 uv_a = UV * vec2(5.0, 1.6) + vec2(TIME * flow, TIME * flow * 2.0);
	vec2 uv_b = UV * vec2(2.4, 0.9) - vec2(TIME * flow * 0.7, TIME * flow * 1.3);
	vec3 n_a = texture(ripple, uv_a).xyz * 2.0 - 1.0;
	vec3 n_b = texture(ripple, uv_b).xyz * 2.0 - 1.0;
	NORMAL = normalize(vec3((n_a.x + n_b.x) * 0.75, 1.0, (n_a.y + n_b.y) * 0.75));

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	vec3 base = mix(deep_color.rgb, shallow_color.rgb, fres * 0.8 + 0.15);
	ALBEDO = mix(base, sky_color.rgb, fres * 0.55);
	// мягкая кромка: вода растворяется в берегу, без линии
	float edge_u = smoothstep(0.0, edge_fade, UV.x) * smoothstep(1.0, 1.0 - edge_fade, UV.x);
	float edge_noise = texture(ripple, UV * vec2(2.0, 6.0)).g;
	edge_u *= mix(0.45, 1.0, smoothstep(0.25, 0.75, edge_noise));
	ALPHA = 0.94 * edge_u;
	ROUGHNESS = 0.04;
	METALLIC = 0.15;
	SPECULAR = 0.9;
	EMISSION = shallow_color.rgb * fres * 0.22;
}
