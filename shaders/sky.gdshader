shader_type sky;

uniform vec3 top_color : source_color = vec3(0.006, 0.010, 0.022);
uniform vec3 horizon_color : source_color = vec3(0.020, 0.028, 0.045);
uniform float star_scale = 420.0;
uniform float star_brightness = 6.5;

float hash13(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void sky() {
	vec3 dir = EYEDIR;
	float h = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.55));

	// млечная полоса
	float band = exp(-pow((dir.y - 0.35 + dir.x * 0.25) * 3.2, 2.0));
	col += vec3(0.05, 0.06, 0.08) * band * 0.35;

	// звёзды
	vec3 cell = floor(dir * star_scale);
	float n = hash13(cell);
	vec3 offset = vec3(hash13(cell + 1.7), hash13(cell + 3.1), hash13(cell + 5.3)) - 0.5;
	vec3 local = fract(dir * star_scale) - 0.5 - offset * 0.35;
	float d = length(local);
	float star = smoothstep(0.32, 0.0, d) * step(0.9935, n);
	float twinkle = 0.7 + 0.3 * sin(TIME * 1.7 + n * 60.0);
	col += vec3(0.85, 0.9, 1.0) * star * star_brightness * twinkle * smoothstep(0.0, 0.18, dir.y);

	COLOR = col;
}
