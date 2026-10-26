// Mer et lac : vagues, réfraction, couleur selon la profondeur, écume sur les rivages.
shader_type spatial;
render_mode cull_disabled, depth_draw_always, specular_schlick_ggx;

#include "res://shaders/common_noise.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap, repeat_disable;

uniform vec3 shallow_color : source_color = vec3(0.10, 0.55, 0.55);
uniform vec3 deep_color : source_color = vec3(0.01, 0.07, 0.13);
uniform float depth_fade = 7.0;
uniform float wave_height = 0.18;
uniform float foam_depth = 0.9;
uniform float refraction = 0.035;

varying vec3 world_pos;

vec3 wave(vec2 p, float t) {
	// Trois vagues superposées : hauteur et dérivées en x et z
	vec3 r = vec3(0.0);
	vec2 d1 = normalize(vec2(1.0, 0.35));
	vec2 d2 = normalize(vec2(-0.4, 1.0));
	vec2 d3 = normalize(vec2(0.7, -0.8));
	float k1 = 0.22; float k2 = 0.37; float k3 = 0.61;
	float a1 = dot(p, d1) * k1 + t * 1.1;
	float a2 = dot(p, d2) * k2 + t * 1.5;
	float a3 = dot(p, d3) * k3 + t * 2.1;
	r.x = sin(a1) + 0.6 * sin(a2) + 0.3 * sin(a3);
	r.y = cos(a1) * k1 * d1.x + 0.6 * cos(a2) * k2 * d2.x + 0.3 * cos(a3) * k3 * d3.x;
	r.z = cos(a1) * k1 * d1.y + 0.6 * cos(a2) * k2 * d2.y + 0.3 * cos(a3) * k3 * d3.y;
	return r;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 w = wave(world_pos.xz, TIME);
	VERTEX.y += w.x * wave_height;
	world_pos.y += w.x * wave_height;
	NORMAL = normalize(vec3(-w.y * wave_height, 1.0, -w.z * wave_height));
}

void fragment() {
	// Petites rides procédurales
	vec2 uv1 = world_pos.xz * 0.35 + vec2(TIME * 0.05, TIME * 0.03);
	vec2 uv2 = world_pos.xz * 0.9 - vec2(TIME * 0.07, -TIME * 0.04);
	float e = 0.05;
	float n0 = fbm(uv1) + fbm(uv2) * 0.5;
	float nx = fbm(uv1 + vec2(e, 0.0)) + fbm(uv2 + vec2(e, 0.0)) * 0.5;
	float nz = fbm(uv1 + vec2(0.0, e)) + fbm(uv2 + vec2(0.0, e)) * 0.5;
	vec3 ripple = normalize(vec3((n0 - nx) * 3.0, 1.0, (n0 - nz) * 3.0));
	vec3 n_world = normalize(vec3(0.0, 1.0, 0.0) + vec3(ripple.x, 0.0, ripple.z));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(n_world, 0.0)).xyz, 0.6));

	// Profondeur de l'eau sous ce pixel
	float depth_raw = texture(depth_tex, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vec3 behind = upos.xyz / upos.w;
	float water_depth = max(VERTEX.z - behind.z, 0.0);

	// Réfraction : on décale la lecture de l'écran, sauf si cela lit un objet au-dessus de l'eau
	vec2 offset = ripple.xz * refraction * clamp(water_depth / 2.0, 0.0, 1.0);
	vec2 ruv = SCREEN_UV + offset;
	float d2 = texture(depth_tex, ruv).r;
	vec4 up2 = INV_PROJECTION_MATRIX * vec4(ruv * 2.0 - 1.0, d2, 1.0);
	if (up2.z / up2.w > VERTEX.z) { ruv = SCREEN_UV; }
	vec3 refr = textureLod(screen_tex, ruv, 0.0).rgb;

	float t = clamp(water_depth / depth_fade, 0.0, 1.0);
	vec3 water = mix(shallow_color, deep_color, sqrt(t));
	vec3 under = mix(refr * shallow_color * 1.6, water, smoothstep(0.0, 1.0, t));

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	fresnel = mix(0.04, 1.0, fresnel);

	// Écume du rivage
	float foam_noise = fbm(world_pos.xz * 1.3 + TIME * 0.2);
	float foam = 1.0 - smoothstep(0.0, foam_depth, water_depth - foam_noise * 0.5);
	foam *= step(0.02, water_depth);
	float crest = smoothstep(0.75, 1.0, n0) * 0.25;

	ALBEDO = mix(vec3(0.0), vec3(0.9), clamp(foam + crest, 0.0, 1.0));
	EMISSION = under * (1.0 - fresnel) * (1.0 - foam);
	ROUGHNESS = mix(0.03, 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
