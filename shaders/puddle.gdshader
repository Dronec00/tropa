shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform sampler2D ripple : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 water_color : source_color = vec4(0.020, 0.030, 0.038, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.16, 0.20, 0.26, 1.0);
uniform float ripple_scale = 6.0;
uniform float flow = 0.02;
uniform float edge_softness = 0.45;
uniform float opacity = 0.93;
uniform vec3 moon_dir = vec3(0.45, 0.55, -0.70);
uniform float moon_intensity = 1.0;
uniform float rain = 0.0;

void fragment() {
	vec2 uv = UV;
	vec3 n1 = texture(ripple, uv * ripple_scale + vec2(TIME * flow, TIME * flow * 1.3)).xyz * 2.0 - 1.0;
	vec3 n2 = texture(ripple, uv * ripple_scale * 1.9 - vec2(TIME * flow * 0.8, TIME * flow)).xyz * 2.0 - 1.0;
	NORMAL = normalize(vec3((n1.x + n2.x) * 0.55, 1.0, (n1.y + n2.y) * 0.55));

	// рябь от капель
	if (rain > 0.03) {
		vec2 g = uv * 16.0;
		vec2 cell = floor(g);
		float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		float t = fract(TIME * 0.8 + h);
		vec2 center = cell + vec2(h, fract(h * 7.0));
		float d = length(g - center);
		float ring = sin((d - t * 1.4) * 26.0) * exp(-d * 2.2) * (1.0 - t);
		NORMAL = normalize(NORMAL + vec3(ring * 0.10, 0.0, ring * 0.06) * rain);
	}

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.8);
	ALBEDO = mix(water_color.rgb, sheen_color.rgb, 0.25 + fres * 0.55);

	// глубина: у кромки светлее, в центре темнее
	float r = length(uv - vec2(0.5)) * 2.0;
	ALBEDO *= mix(0.55, 1.0, smoothstep(0.0, 0.8, r));

	// лунная дорожка
	vec3 R = reflect(-VIEW, NORMAL);
	float md = pow(max(dot(R, normalize(moon_dir)), 0.0), 200.0);
	ALBEDO += vec3(0.55, 0.64, 0.85) * md * moon_intensity * 1.8 * (1.0 - rain * 0.5);

	ROUGHNESS = 0.14;
	METALLIC = 0.0;
	SPECULAR = 0.35;

	float edge = smoothstep(1.0, 1.0 - edge_softness, r);
	float breakup = smoothstep(0.35, 0.85, texture(ripple, uv * 3.5).b);
	ALPHA = opacity * edge * (0.55 + 0.45 * breakup);
}
