shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

// Ближняя трава: каждая травинка — узкая полоска из сегментов.
// Без текстуры и без альфы, поэтому силуэт чистый на любом расстоянии.
// Ветер и примятость считаются в мировых координатах и переводятся
// обратно в модельные, чтобы все травинки гнулись в одну сторону.

uniform float wind_strength = 1.0;
uniform float wind_speed = 1.0;
uniform float brightness = 1.0;

global uniform vec3 player_pos;

varying vec3 v_world;

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

	float h = clamp(UV.y, 0.0, 1.0);
	float phase = world.x * 0.55 + world.z * 0.47;
	float gust = 0.70 + 0.30 * sin(TIME * 0.25 + world.x * 0.03);
	float sway = (
		sin(TIME * 1.5 * wind_speed + phase)
		+ 0.35 * sin(TIME * 3.4 * wind_speed + phase * 1.8)
	) * gust;

	vec3 off = vec3(sway, 0.0, sway * 0.65) * (wind_strength * 0.11 * h * h);

	// примятость вокруг игрока
	vec3 to_p = world - player_pos;
	float pd = length(to_p.xz);
	float push = smoothstep(1.4, 0.20, pd);
	vec3 away = normalize(vec3(to_p.x, 0.0, to_p.z) + vec3(0.001, 0.0, 0.0));
	off += away * push * 0.20 * (1.0 - h);
	off.y -= push * 0.10 * (1.0 - h);

	VERTEX += mat3(inverse(MODEL_MATRIX)) * off;
}

void fragment() {
	float h = clamp(UV.y, 0.0, 1.0);
	float patch = value_noise(v_world.xz * 0.05) * 0.65 + value_noise(v_world.xz * 0.15) * 0.35;

	vec3 base = vec3(0.028, 0.055, 0.016);
	vec3 tip = mix(vec3(0.12, 0.27, 0.06), vec3(0.26, 0.34, 0.11), smoothstep(0.25, 0.85, patch));
	vec3 c = mix(base, tip, smoothstep(0.02, 0.92, h));
	c *= mix(0.75, 1.10, COLOR.r);
	c *= brightness;

	ALBEDO = c;
	ROUGHNESS = 0.9;
	BACKLIGHT = c * 0.6;
	NORMAL = normalize(mix(NORMAL, VIEW, 0.20));
}
