shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Земля: две фототекстуры в мировых координатах + макро-шум,
// чтобы не было видно плитки и растяжения на больших склонах.

uniform sampler2D albedo_a : source_color, repeat_enable;
uniform sampler2D albedo_b : source_color, repeat_enable;
uniform sampler2D normal_a : hint_normal, repeat_enable;
uniform sampler2D normal_b : hint_normal, repeat_enable;
uniform sampler2D rough_a : hint_roughness_gray, repeat_enable;
uniform sampler2D rough_b : hint_roughness_gray, repeat_enable;
uniform sampler2D macro : hint_default_white, repeat_enable;

uniform vec3 tint : source_color = vec3(0.62, 0.52, 0.38);
uniform float scale_a = 0.34;
uniform float scale_b = 0.11;
uniform float macro_scale = 0.006;
uniform float normal_strength = 1.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv_a = v_world.xz * scale_a;
	vec2 uv_b = v_world.xz * scale_b;
	float m = texture(macro, v_world.xz * macro_scale).r;
	float blend = smoothstep(0.30, 0.70, m);

	vec3 a = texture(albedo_a, uv_a).rgb;
	vec3 b = texture(albedo_b, uv_b).rgb;
	vec3 col = mix(a, b, blend);

	// макро-вариация яркости и цвета — ломает однородность
	float macro_var = 0.78 + 0.44 * m;
	vec3 macro_hue = mix(vec3(1.0), vec3(1.06, 0.98, 0.90), m);

	ALBEDO = col * tint * macro_var * macro_hue;
	NORMAL_MAP = mix(texture(normal_a, uv_a).rgb, texture(normal_b, uv_b).rgb, blend);
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = mix(texture(rough_a, uv_a).r, texture(rough_b, uv_b).r, blend) * 0.85 + 0.15;
}
