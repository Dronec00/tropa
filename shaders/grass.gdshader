shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform vec3 grass_base : source_color = vec3(0.12, 0.16, 0.07);
uniform vec3 grass_tip : source_color = vec3(0.42, 0.50, 0.22);
uniform float wind_strength = 0.16;
uniform float wind_speed = 1.35;

varying float v_height;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 0.42 + world.z * 0.35;
	float sway = sin(TIME * wind_speed + phase) * 0.65
		+ sin(TIME * wind_speed * 2.6 + phase * 1.7) * 0.25;
	float h = clamp(VERTEX.y, 0.0, 1.0);
	VERTEX.x += sway * wind_strength * h * h;
	VERTEX.z += sway * wind_strength * 0.55 * h * h;
	v_height = h;
}

void fragment() {
	ALBEDO = mix(grass_base, grass_tip, v_height * v_height);
	ROUGHNESS = 0.95;
	BACKLIGHT = vec3(0.10, 0.13, 0.05);
}
