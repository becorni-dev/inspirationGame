// Sol de l'île : herbe, roche, sable et neige mélangés selon la hauteur et la pente.
// Les textures de l'atelier remplacent les couleurs procédurales quand elles existent.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/common_noise.gdshaderinc"

uniform float water_level = 0.0;
uniform float snow_level = 55.0;

uniform bool use_grass_tex = false;
uniform bool use_rock_tex = false;
uniform bool use_sand_tex = false;
uniform bool use_snow_tex = false;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_scale = 0.08;

// Grille de construction et case survolée
uniform float grid_alpha = 0.0;
uniform float cell_size = 4.0;
uniform vec4 grid_bounds = vec4(-120.0, -120.0, 120.0, 120.0);
uniform vec4 hover_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 hover_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec3 triplanar(sampler2D tex, vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 x = texture(tex, p.zy * tex_scale).rgb;
	vec3 y = texture(tex, p.xz * tex_scale).rgb;
	vec3 z = texture(tex, p.xy * tex_scale).rgb;
	return x * w.x + y * w.y + z * w.z;
}

void fragment() {
	vec3 p = world_pos;
	vec3 n = normalize(world_normal);
	float slope = 1.0 - n.y;

	float big = fbm(p.xz * 0.02);
	float mid = fbm(p.xz * 0.15);
	float fine = value_noise(p.xz * 1.7);

	// Couleurs procédurales de secours
	vec3 grass = mix(vec3(0.16, 0.26, 0.07), vec3(0.32, 0.38, 0.12), big);
	grass = mix(grass, vec3(0.22, 0.30, 0.10), mid * 0.6);
	grass *= 0.85 + fine * 0.3;
	vec3 dry = vec3(0.42, 0.38, 0.22) * (0.85 + fine * 0.3);
	grass = mix(grass, dry, smoothstep(0.55, 0.8, big) * 0.6);
	vec3 rock = mix(vec3(0.30, 0.29, 0.28), vec3(0.47, 0.44, 0.40), mid);
	rock *= 0.8 + fine * 0.35;
	vec3 sand = mix(vec3(0.70, 0.62, 0.45), vec3(0.80, 0.72, 0.55), mid) * (0.9 + fine * 0.15);
	vec3 snow = vec3(0.92, 0.94, 0.98) * (0.95 + fine * 0.05);

	if (use_grass_tex) { grass = triplanar(grass_tex, p, n) * (0.85 + big * 0.3); }
	if (use_rock_tex) { rock = triplanar(rock_tex, p, n); }
	if (use_sand_tex) { sand = triplanar(sand_tex, p, n); }
	if (use_snow_tex) { snow = triplanar(snow_tex, p, n); }

	float rock_w = smoothstep(0.28, 0.45, slope + (mid - 0.5) * 0.15);
	float sand_w = 1.0 - smoothstep(water_level + 0.6, water_level + 2.2 + mid * 1.5, p.y);
	float snow_w = smoothstep(snow_level - 6.0, snow_level + 4.0, p.y + (big - 0.5) * 14.0) * (1.0 - smoothstep(0.5, 0.75, slope));

	vec3 col = grass;
	col = mix(col, sand, sand_w);
	col = mix(col, rock, rock_w);
	col = mix(col, snow, snow_w);
	// Sable mouillé sous l'eau
	col *= mix(1.0, 0.55, 1.0 - smoothstep(water_level - 1.5, water_level + 0.2, p.y));

	float rough = mix(0.92, 0.75, rock_w);
	rough = mix(rough, 0.45, snow_w);

	// Grille de construction
	vec3 emission = vec3(0.0);
	bool in_grid = p.x > grid_bounds.x && p.z > grid_bounds.y && p.x < grid_bounds.z && p.z < grid_bounds.w;
	if (grid_alpha > 0.001 && in_grid) {
		vec2 g = (p.xz - grid_bounds.xy) / cell_size;
		vec2 f = abs(fract(g) - 0.5);
		float line = 1.0 - smoothstep(0.46, 0.49, max(f.x, f.y));
		line = 1.0 - line;
		col = mix(col, vec3(0.45, 0.75, 0.95), line * 0.35 * grid_alpha);
		emission += vec3(0.1, 0.35, 0.55) * line * 0.25 * grid_alpha;
	}
	if (hover_rect.z > hover_rect.x) {
		bool inside = p.x > hover_rect.x && p.z > hover_rect.y && p.x < hover_rect.z && p.z < hover_rect.w;
		if (inside) {
			vec2 c = (hover_rect.xy + hover_rect.zw) * 0.5;
			vec2 h = (hover_rect.zw - hover_rect.xy) * 0.5;
			vec2 d = abs(p.xz - c) / h;
			float edge = smoothstep(0.85, 0.97, max(d.x, d.y));
			col = mix(col, hover_color.rgb, 0.25 + edge * 0.5);
			emission += hover_color.rgb * (0.15 + edge * 0.8);
		}
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	EMISSION = emission;
}
