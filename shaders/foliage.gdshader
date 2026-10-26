// Arbres : couleur par sommet et par instance, balancement au vent.
shader_type spatial;
render_mode cull_disabled;

global uniform float wind_strength;

uniform bool use_leaf_tex = false;
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_enable;

varying float sway_mask;
varying vec3 world_pos;

void vertex() {
	// La hauteur du sommet dans l'arbre décide de son balancement
	sway_mask = clamp(VERTEX.y / 8.0, 0.0, 1.0);
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = origin.x * 0.13 + origin.z * 0.11;
	float s = sin(TIME * 1.3 + phase) * 0.6 + sin(TIME * 2.7 + phase * 2.0) * 0.25;
	VERTEX.x += s * sway_mask * sway_mask * 0.25 * wind_strength;
	VERTEX.z += cos(TIME * 1.1 + phase) * sway_mask * sway_mask * 0.15 * wind_strength;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (use_leaf_tex && sway_mask > 0.2) {
		c *= texture(leaf_tex, world_pos.xy * 0.5 + world_pos.zx * 0.3).rgb * 1.8;
	}
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	// Lumière qui traverse les feuilles
	BACKLIGHT = c * 0.6 * sway_mask;
}
