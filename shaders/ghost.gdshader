// Aperçu holographique du bâtiment à poser (bleu si possible, rouge sinon).
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 color : source_color = vec4(0.3, 0.8, 1.0, 1.0);

// Mêmes paramètres d'instance que le shader des bâtiments (l'aperçu réutilise leurs pièces)
instance uniform vec4 tint = vec4(1.0);
instance uniform float windows = 0.0;
instance uniform float seed = 0.0;
instance uniform float base_y = 0.0;
instance uniform float height = 10.0;
instance uniform float progress = 1.0;
instance uniform float glow = 0.0;
instance uniform float metal = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float scan = smoothstep(0.4, 0.5, fract(world_pos.y * 1.5 - TIME * 1.2)) * 0.35;
	// Les paramètres d'instance ne servent pas ici : on les garde pour qu'ils restent déclarés
	float keep = (tint.a + windows + seed + base_y + height + progress + glow + metal) * 0.0;
	ALBEDO = color.rgb * (0.15 + fresnel * 0.9 + scan + keep);
}
