shader_type sky;

uniform vec3 top_color : source_color = vec3(0.006, 0.010, 0.022);
uniform vec3 horizon_color : source_color = vec3(0.020, 0.028, 0.045);
uniform float star_scale = 420.0;
uniform float star_brightness = 6.5;

uniform vec3 moon_dir = vec3(0.35, 0.45, -0.55);
uniform float moon_size = 0.00006;
uniform float moon_glow = 0.9;

uniform float cloud_cover = 0.35;
uniform float cloud_scale = 1.7;
uniform vec3 cloud_color : source_color = vec3(0.06, 0.07, 0.10);
uniform vec3 cloud_lit : source_color = vec3(0.34, 0.38, 0.46);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.55));

	// облака: шум на плоскости, снесённый по высоте
	vec2 cuv = dir.xz / max(dir.y, 0.10) * cloud_scale + vec2(TIME * 0.004, TIME * 0.0015);
	float n = fbm(cuv);
	float cover = smoothstep(0.42, 0.78, n) * smoothstep(0.02, 0.22, dir.y);

	// луна
	vec3 mdir = normalize(moon_dir);
	float md = dot(normalize(dir), mdir);
	float disc = smoothstep(1.0 - moon_size, 1.0 - moon_size * 0.45, md);
	float halo = pow(max(md, 0.0), 1500.0);

	// облака подсвечены луной
	float moon_light = clamp(md * 0.5 + 0.5, 0.0, 1.0);
	vec3 ccol = mix(cloud_color, cloud_lit, moon_light * moon_glow);
	col = mix(col, ccol, cover * cloud_cover);

	// звёзды (гаснут в облаках)
	vec3 cell = floor(dir * star_scale);
	float sn = hash21(cell.xy + cell.z * 17.0);
	vec3 offset = vec3(hash21(cell.xy + 1.7), hash21(cell.xy + 3.1), hash21(cell.xy + 5.3)) - 0.5;
	vec3 local = fract(dir * star_scale) - 0.5 - offset * 0.35;
	float sd = length(local);
	float star = smoothstep(0.32, 0.0, sd) * step(0.9955, sn);
	float twinkle = 0.7 + 0.3 * sin(TIME * 1.7 + sn * 60.0);
	col += vec3(0.85, 0.9, 1.0) * star * star_brightness * twinkle * smoothstep(0.0, 0.18, dir.y) * (1.0 - cover);

	// диск луны и её ореол
	col += vec3(0.95, 0.97, 1.0) * disc * 2.6 * moon_glow * (1.0 - cover * 0.85);
	col += vec3(0.35, 0.42, 0.58) * halo * 0.30 * moon_glow * (1.0 - cover * 0.7);

	COLOR = col;
}
