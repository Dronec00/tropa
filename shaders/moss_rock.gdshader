shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform sampler2D stone_albedo : source_color, repeat_enable;
uniform sampler2D stone_normal : hint_normal, repeat_enable;
uniform sampler2D moss_albedo : source_color, repeat_enable;
uniform sampler2D moss_normal : hint_normal, repeat_enable;
uniform vec3 stone_tint : source_color = vec3(0.42, 0.43, 0.40);
uniform vec3 moss_tint : source_color = vec3(0.30, 0.42, 0.20);
uniform float moss_amount = 0.95;
uniform float moss_bias = 0.35;

varying vec3 v_world_normal;
varying vec3 v_world;

void vertex() {
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV * 2.2;
	float up = clamp(v_world_normal.y, 0.0, 1.0);
	float n = texture(moss_albedo, uv * 1.6 + v_world.xz * 0.06).g;
	float mask = smoothstep(0.32, 0.78, up * (0.55 + n * 0.9) * moss_amount + moss_bias * up);
	mask *= moss_amount;

	vec3 stone = texture(stone_albedo, uv).rgb * stone_tint * 1.4;
	vec3 moss = texture(moss_albedo, uv * 1.3).rgb * moss_tint * 1.9;
	ALBEDO = mix(stone, moss, mask);
	NORMAL_MAP = normalize(mix(
		texture(stone_normal, uv).rgb,
		texture(moss_normal, uv * 1.3).rgb,
		mask
	));
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(0.92, 1.0, mask);
}
