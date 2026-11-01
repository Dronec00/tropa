shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled, depth_prepass_alpha;

uniform sampler2D tuft : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(0.85, 0.95, 0.75);
uniform float wind_strength = 0.18;
uniform float wind_speed = 1.4;

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
	if (c.a < 0.45) {
		discard;
	}
	ALBEDO = c.rgb * tint;
	ROUGHNESS = 0.95;
	BACKLIGHT = c.rgb * 0.6;
}
