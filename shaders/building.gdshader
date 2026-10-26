// Bâtiments : murs, fenêtres qui s'allument la nuit, animation de construction.
// Un seul shader pour toutes les pièces ; chaque pièce règle ses paramètres d'instance.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/common_noise.gdshaderinc"

global uniform float night;

instance uniform vec4 tint = vec4(0.8, 0.8, 0.8, 1.0);
instance uniform float windows = 0.0;      // 0 : pas de fenêtres, 1 : fenêtres
instance uniform float seed = 0.0;
instance uniform float base_y = 0.0;
instance uniform float height = 10.0;
instance uniform float progress = 1.0;     // 0 à 1 pendant la construction
instance uniform float glow = 0.0;         // pièce lumineuse (enseigne, feu)
instance uniform float metal = 0.0;

uniform float floor_height = 3.2;
uniform float window_width = 2.2;
uniform float lit_ratio = 0.55;
uniform vec3 window_light : source_color = vec3(1.0, 0.78, 0.48);
uniform bool use_wall_tex = false;
uniform sampler2D wall_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wall_tex_scale = 0.25;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = world_pos;
	vec3 n = normalize(world_normal);
	float cut = base_y + height * progress;
	if (progress < 0.999 && p.y > cut) { discard; }

	vec3 base = pow(tint.rgb, vec3(2.2));
	// Face verticale : coordonnée horizontale le long du mur
	float along = abs(n.x) > abs(n.z) ? p.z : p.x;
	vec2 face = vec2(along, p.y - base_y);

	vec3 wall = base;
	if (use_wall_tex && abs(n.y) < 0.5) {
		wall = texture(wall_tex, face * wall_tex_scale).rgb * mix(vec3(1.0), base * 1.6, 0.35);
	}
	float grime = fbm(face * vec2(0.3, 0.8) + seed) ;
	wall *= 0.82 + grime * 0.3;
	// Salissures en bas des murs
	wall *= mix(0.75, 1.0, smoothstep(0.0, 2.5, p.y - base_y));

	vec3 albedo = wall;
	float rough = 0.85;
	float metallic = metal;
	vec3 emission = vec3(0.0);

	if (windows > 0.5 && abs(n.y) < 0.3) {
		vec2 cell = vec2(face.x / window_width, face.y / floor_height);
		vec2 id = floor(cell);
		vec2 f = fract(cell);
		float frame_x = step(0.18, f.x) * step(f.x, 0.82);
		float frame_y = step(0.28, f.y) * step(f.y, 0.86);
		float is_window = frame_x * frame_y * step(0.8, face.y) * step(face.y, height - 0.6);
		if (is_window > 0.5) {
			float r = hash12(id + vec2(seed * 13.7, seed * 3.1 + floor(n.x * 3.0 + n.z * 7.0)));
			float lit = step(1.0 - lit_ratio, r) * night;
			vec3 glass = vec3(0.05, 0.07, 0.09);
			// Reflet du ciel sur les vitres de jour
			albedo = glass;
			rough = 0.08;
			metallic = 0.9;
			float warm = hash12(id + 7.7);
			vec3 lc = mix(window_light, vec3(0.75, 0.85, 1.0), step(0.75, warm));
			// Rideaux : intérieur pas uniforme
			float inside = 0.55 + 0.45 * value_noise(f * 3.0 + id);
			emission = lc * lit * inside * 4.0;
		}
	}

	if (glow > 0.0) {
		emission += base * glow * (0.35 + night * 0.65) * 6.0;
	}

	// Bord incandescent pendant la construction
	if (progress < 0.999) {
		float edge = 1.0 - smoothstep(0.0, 0.35, cut - p.y);
		emission += vec3(1.0, 0.55, 0.15) * edge * 6.0;
		albedo = mix(albedo, vec3(0.9, 0.6, 0.3), edge);
	}

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metallic;
	EMISSION = emission;
}
