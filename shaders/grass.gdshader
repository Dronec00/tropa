shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled, depth_prepass_alpha;

// Карточки-пучки: три скрещённые плоскости с текстурой веера.
// Цвет задаётся градиентом от основания к кончику, крупные пятна
// сухой/сочной травы — по мировым координатам, а не по инстансу,
// чтобы поле читалось пятнами, а не шумом.

uniform sampler2D tuft : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint_a : source_color = vec3(0.42, 0.50, 0.30);
uniform vec3 tint_b : source_color = vec3(0.60, 0.56, 0.36);
global uniform vec3 player_pos;
uniform float wind_strength = 0.16;
uniform float wind_speed = 1.35;
uniform float topdown_fade = 0.30;
uniform float variant_override = -1.0;
uniform float brightness = 0.78;

varying vec3 v_world;
varying float v_patch;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world = world;
	v_patch = value_noise(world.xz * 0.032) * 0.65 + value_noise(world.xz * 0.11) * 0.35;

	float phase = world.x * 0.45 + world.z * 0.38;
	float gust = 0.70 + 0.30 * sin(TIME * 0.27 + world.x * 0.03);
	float sway = (sin(TIME * wind_speed + phase) + 0.45 * sin(TIME * wind_speed * 2.6 + phase * 1.7)) * gust;
	float h = clamp(UV.y, 0.0, 1.0);
	VERTEX.x += sway * wind_strength * h * h;
	VERTEX.z += sway * wind_strength * 0.6 * h * h;

	// примятость вокруг игрока
	vec3 to_p = world - player_pos;
	float pd = length(to_p.xz);
	float push = smoothstep(1.5, 0.15, pd);
	vec3 away = normalize(vec3(to_p.x, 0.0, to_p.z) + vec3(0.001, 0.0, 0.0));
	VERTEX.x += away.x * push * 0.30 * (1.0 - h);
	VERTEX.z += away.z * push * 0.30 * (1.0 - h);
}

void fragment() {
	float variant = variant_override >= 0.0 ? variant_override : floor(COLOR.b * 3.999);
	vec2 off = vec2(mod(variant, 2.0), floor(variant / 2.0)) * 0.5;
	vec4 c = texture(tuft, UV * 0.5 + off);
	float v = COLOR.r;
	float hue = COLOR.g;
	float h = clamp(UV.y, 0.0, 1.0);

	vec3 tint = mix(tint_a, tint_b, v);
	tint = mix(tint, tint * vec3(1.18, 1.0, 0.78), hue);

	// крупные пятна: сухая трава теплее, сочная — зеленее
	tint = mix(tint, tint * vec3(1.22, 1.02, 0.62), smoothstep(0.35, 0.85, v_patch) * 0.65);
	tint = mix(tint, tint * vec3(0.78, 1.06, 0.72), smoothstep(0.55, 0.15, v_patch) * 0.35);

	float tip = smoothstep(0.0, 0.85, h);
	float ao = mix(0.50, 1.0, smoothstep(0.0, 0.65, h));
	vec3 albedo = c.rgb * tint * ao * brightness;
	albedo = mix(albedo, albedo * vec3(1.15, 1.12, 0.92), tip * 0.45);

	ALBEDO = albedo;
	ROUGHNESS = 0.9;
	BACKLIGHT = c.rgb * 1.1;

	// мягкий свет листвы: NORMAL и VIEW — в view space
	NORMAL = normalize(mix(NORMAL, VIEW, 0.35));

	if (c.a < 0.30) {
		discard;
	}

	// взгляд сверху: часть стеблей убираем, чтобы трава не закрывала обзор
	vec3 to_cam = normalize(v_world - CAMERA_POSITION_WORLD);
	float look_down = clamp(-to_cam.y, 0.0, 1.0);
	float thin = smoothstep(0.60, 1.0, look_down) * topdown_fade;
	float dither = fract(sin(dot(floor(FRAGCOORD.xy * 0.75), vec2(12.9898, 78.233))) * 43758.5453);
	if (dither < thin) {
		discard;
	}
	ALPHA_SCISSOR_THRESHOLD = 0.35;
	ALPHA_ANTIALIASING_EDGE = 0.25;
}
