shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled, depth_prepass_alpha;

uniform sampler2D tuft : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint_a : source_color = vec3(0.62, 0.80, 0.44);
uniform vec3 tint_b : source_color = vec3(0.95, 0.88, 0.52);
uniform float wind_strength = 0.16;
uniform float wind_speed = 1.35;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 0.45 + world.z * 0.38;
	float gust = 0.70 + 0.30 * sin(TIME * 0.27 + world.x * 0.03);
	float sway = (sin(TIME * wind_speed + phase) + 0.45 * sin(TIME * wind_speed * 2.6 + phase * 1.7)) * gust;
	float h = clamp(UV.y, 0.0, 1.0);
	VERTEX.x += sway * wind_strength * h * h;
	VERTEX.z += sway * wind_strength * 0.6 * h * h;
}

void fragment() {
	vec4 c = texture(tuft, UV);
	float v = COLOR.r;
	float hue = COLOR.g;
	vec3 tint = mix(tint_a, tint_b, v);
	tint = mix(tint, tint * vec3(1.12, 1.0, 0.82), hue);
	float ao = mix(0.45, 1.0, smoothstep(0.0, 0.62, UV.y));
	ALBEDO = c.rgb * tint * ao * 1.35;
	ROUGHNESS = 0.9;
	BACKLIGHT = c.rgb * 0.8;
	ALPHA = smoothstep(0.30, 0.46, c.a);
	ALPHA_SCISSOR_THRESHOLD = 0.35;
	ALPHA_ANTIALIASING_EDGE = 0.25;
}
