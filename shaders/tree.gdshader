shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D bark_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D bark_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float use_normal = 0.0;
uniform sampler2D moss_tex : source_color, repeat_enable;
uniform float trunk_moss = 0.0;
uniform float wind = 0.22;

global uniform vec3 player_pos;

varying float v_height;
varying float v_leaf;
varying vec3 v_world;

void vertex() {
	v_height = UV2.x;
	v_leaf = UV2.y;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world = world;

	float phase = world.x * 0.22 + world.z * 0.19;
	float gust = 0.62 + 0.38 * sin(TIME * 0.33 + world.x * 0.02);
	float sway = (sin(TIME * 0.9 + phase) + 0.4 * sin(TIME * 2.3 + phase * 1.7)) * gust;
	float amount = v_height * v_height;
	VERTEX.x += sway * wind * amount;
	VERTEX.z += sway * wind * 0.55 * amount;

	vec3 to_player = world - player_pos;
	float d = length(to_player.xz);
	float push = smoothstep(2.8, 0.6, d);
	vec2 dir = normalize(to_player.xz + vec2(0.001));
	VERTEX.x += dir.x * push * 0.2 * v_height;
	VERTEX.z += dir.y * push * 0.2 * v_height;
}

void fragment() {
	vec3 albedo;
	if (v_leaf > 0.5) {
		vec4 c = texture(leaf_tex, UV);
		albedo = COLOR.rgb * c.rgb * 2.2;
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = 0.22;
		ALPHA_ANTIALIASING_EDGE = 0.18;
	} else {
		ALPHA = 1.0;
		albedo = COLOR.rgb * texture(bark_tex, UV * vec2(1.0, 3.0)).rgb * 1.1;
		if (trunk_moss > 0.0) {
			float mh = 1.0 - smoothstep(0.0, 0.22, v_height);
			float mn = texture(moss_tex, UV * vec2(2.0, 2.0) + vec2(v_world.x * 0.05, 0.0)).g;
			float mask = mh * smoothstep(0.35, 0.75, mn + mh * 0.45) * trunk_moss;
			albedo = mix(albedo, texture(moss_tex, UV * 2.4).rgb * vec3(0.55, 0.75, 0.42) * 1.6, mask);
		}
		if (use_normal > 0.5) {
			NORMAL_MAP = texture(bark_normal, UV * vec2(1.0, 3.0)).rgb;
			NORMAL_MAP_DEPTH = 1.0;
		}
	}
	float variation = 0.88 + 0.12 * sin(v_world.x * 0.7 + v_world.z * 0.6);
	ALBEDO = albedo * variation;
	ROUGHNESS = 1.0;
	BACKLIGHT = COLOR.rgb * (v_leaf > 0.5 ? 0.35 : 0.0);
}
