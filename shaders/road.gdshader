// Route : asphalte, trottoirs et marquage selon les routes voisines.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/common_noise.gdshaderinc"

global uniform float night;

instance uniform vec4 links = vec4(0.0); // nord, est, sud, ouest (1 = route voisine)
instance uniform float progress = 1.0;

uniform float cell_size = 4.0;
uniform bool use_asphalt_tex = false;
uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 node_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	node_pos = NODE_POSITION_WORLD;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec2 uv = (world_pos.xz - node_pos.xz) / cell_size; // -0.5 .. 0.5
	vec3 col;
	float rough = 0.9;
	vec3 emission = vec3(0.0);
	if (n.y < 0.5) {
		// Bord de la chaussée : béton
		col = vec3(0.42, 0.41, 0.39) * (0.85 + value_noise(world_pos.xy * 3.0) * 0.2);
	} else {
		float grain = value_noise(world_pos.xz * 6.0) * 0.5 + value_noise(world_pos.xz * 23.0) * 0.5;
		col = vec3(0.07, 0.075, 0.08) * (0.8 + grain * 0.4);
		if (use_asphalt_tex) { col = texture(asphalt_tex, world_pos.xz * 0.2).rgb; }
		float wear = fbm(world_pos.xz * 0.4);
		col = mix(col, col * 1.6, smoothstep(0.6, 0.8, wear) * 0.5);
		rough = 0.75;
		// Trottoirs sur les bords sans voisin
		float side = 0.0;
		if (links.x < 0.5 && uv.y < -0.36) side = 1.0;
		if (links.z < 0.5 && uv.y > 0.36) side = 1.0;
		if (links.y < 0.5 && uv.x > 0.36) side = 1.0;
		if (links.w < 0.5 && uv.x < -0.36) side = 1.0;
		// Coins toujours en trottoir
		if (abs(uv.x) > 0.36 && abs(uv.y) > 0.36) side = 1.0;
		vec3 walk = vec3(0.50, 0.49, 0.46) * (0.9 + grain * 0.2);
		float tiles = step(0.94, fract(world_pos.x * 1.2)) + step(0.94, fract(world_pos.z * 1.2));
		walk *= 1.0 - clamp(tiles, 0.0, 1.0) * 0.15;
		// Marquage au centre vers chaque voisin
		float mark = 0.0;
		float dash_z = step(0.5, fract(world_pos.z * 0.5));
		float dash_x = step(0.5, fract(world_pos.x * 0.5));
		float cnt = links.x + links.y + links.z + links.w;
		bool straight_ns = links.x > 0.5 && links.z > 0.5 && links.y < 0.5 && links.w < 0.5;
		bool straight_ew = links.y > 0.5 && links.w > 0.5 && links.x < 0.5 && links.z < 0.5;
		if (abs(uv.x) < 0.012 && ((links.x > 0.5 && uv.y < 0.0) || (links.z > 0.5 && uv.y > 0.0))) mark = dash_z;
		if (abs(uv.y) < 0.012 && ((links.y > 0.5 && uv.x > 0.0) || (links.w > 0.5 && uv.x < 0.0))) mark = dash_x;
		if (cnt > 2.5 || (!straight_ns && !straight_ew && cnt > 1.5)) {
			// Carrefour : passages piétons au lieu des tirets
			mark = 0.0;
			float zebra_x = step(0.5, fract(uv.x * 10.0));
			float zebra_y = step(0.5, fract(uv.y * 10.0));
			if (abs(uv.y) > 0.28 && abs(uv.y) < 0.34 && abs(uv.x) < 0.3) mark = zebra_x;
			if (abs(uv.x) > 0.28 && abs(uv.x) < 0.34 && abs(uv.y) < 0.3) mark = zebra_y;
		}
		col = mix(col, vec3(0.85, 0.82, 0.7), mark * 0.9);
		col = mix(col, walk, side);
		// Reflets humides la nuit sous les lampadaires
		rough = mix(rough, 0.35, night * 0.4 * (1.0 - side));
	}
	if (progress < 0.999) {
		emission = vec3(0.2, 0.6, 1.0) * (1.0 - progress) * 3.0;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	EMISSION = emission;
}
