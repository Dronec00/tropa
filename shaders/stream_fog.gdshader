shader_type fog;

// Туман-слой над водой: плотнее у земли, редеет с высотой, медленно дрейфует.

uniform float density : hint_range(0.0, 1.0) = 0.30;
uniform vec3 albedo_color : source_color = vec3(0.55, 0.62, 0.74);
uniform float height_falloff = 1.1;
uniform float base_height = 0.0;
uniform float noise_scale = 0.22;
uniform float drift = 0.25;

void fog() {
	float h = max(WORLD_POSITION.y - base_height, 0.0);
	float height_mask = exp(-h * height_falloff);

	float n1 = sin((WORLD_POSITION.x + TIME * drift) * noise_scale);
	float n2 = sin((WORLD_POSITION.z - TIME * drift * 0.7) * noise_scale * 1.3);
	float n = 0.72 + 0.28 * n1 * n2;

	DENSITY = density * height_mask * n;
	ALBEDO = albedo_color;
}
