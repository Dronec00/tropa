shader_type canvas_item;
render_mode unshaded;

// Постобработка: лёгкая хроматика, зерно, виньетка и цветокоррекция теней/светов.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float grain_amount = 0.040;
uniform float chroma_amount = 0.0016;
uniform float vignette_amount = 0.42;
uniform float contrast = 1.05;
uniform vec3 shadow_tint : source_color = vec3(0.90, 0.96, 1.10);
uniform vec3 highlight_tint : source_color = vec3(1.06, 1.01, 0.93);

void fragment() {
	vec2 uv = SCREEN_UV;
	float ca = chroma_amount * length(uv - vec2(0.5));

	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ca, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ca, 0.0)).b;

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col *= mix(shadow_tint, highlight_tint, smoothstep(0.04, 0.55, lum));
	col = (col - 0.5) * contrast + 0.5;

	float d = distance(uv, vec2(0.5));
	float vig = smoothstep(0.88, 0.18, d);
	col *= mix(1.0, vig, vignette_amount);

	float n = fract(sin(dot(uv * (TIME * 60.0), vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain_amount;

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
