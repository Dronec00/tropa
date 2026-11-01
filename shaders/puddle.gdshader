shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform sampler2D ripple : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 water_color : source_color = vec4(0.018, 0.030, 0.034, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.075, 0.095, 0.12, 1.0);
uniform float ripple_scale = 7.0;
uniform float flow = 0.018;
uniform float edge_softness = 0.34;
uniform float opacity = 0.95;

void fragment() {
	vec2 uv = UV;
	vec3 n1 = texture(ripple, uv * ripple_scale + vec2(TIME * flow, TIME * flow * 1.3)).xyz * 2.0 - 1.0;
	vec3 n2 = texture(ripple, uv * ripple_scale * 1.9 - vec2(TIME * flow * 0.8, TIME * flow)).xyz * 2.0 - 1.0;
	NORMAL = normalize(vec3((n1.x + n2.x) * 0.35, 1.0, (n1.y + n2.y) * 0.35));

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.2);
	ALBEDO = mix(water_color.rgb, sheen_color.rgb, fres * 0.55);
	ROUGHNESS = 0.22;
	METALLIC = 0.0;
	SPECULAR = 0.18;

	float r = length(uv - vec2(0.5)) * 2.0;
	float edge = smoothstep(1.0, 1.0 - edge_softness, r);
	float breakup = smoothstep(0.35, 0.85, texture(ripple, uv * 3.5).b);
	ALPHA = opacity * edge * (0.55 + 0.45 * breakup);
}
