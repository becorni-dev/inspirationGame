// Ciel procédural : dégradé selon l'heure, soleil, lune, étoiles et nuages qui défilent.
shader_type sky;

#include "res://shaders/common_noise.gdshaderinc"

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 zenith_color : source_color = vec3(0.12, 0.32, 0.65);
uniform vec3 horizon_color : source_color = vec3(0.6, 0.75, 0.9);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.75);
uniform float stars = 0.0;
uniform float cloud_cover = 0.45;
uniform float sky_energy = 1.0;

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 col = mix(horizon_color, zenith_color, pow(clamp(h, 0.0, 1.0), 0.55));
	// Sous l'horizon : on assombrit doucement (reflet sur la mer)
	col = mix(col, horizon_color * 0.45, smoothstep(0.0, -0.25, h));

	float sd = dot(dir, normalize(sun_dir));
	float sun_up = clamp(sun_dir.y * 4.0 + 0.4, 0.0, 1.0);
	// Halo et couronne du soleil
	col += sun_color * pow(max(sd, 0.0), 8.0) * 0.35 * sun_up;
	col += sun_color * pow(max(sd, 0.0), 64.0) * 0.6 * sun_up;
	// Lumière rasante orangée près de l'horizon au coucher
	float low = 1.0 - smoothstep(0.0, 0.35, abs(sun_dir.y));
	col += vec3(1.0, 0.45, 0.15) * pow(max(sd, 0.0), 3.0) * low * (1.0 - smoothstep(0.0, 0.5, h)) * 0.8;

	// Disque solaire
	if (!AT_CUBEMAP_PASS) {
		float disk = smoothstep(0.9994, 0.9997, sd);
		col += sun_color * disk * 30.0 * sun_up;
		float md = dot(dir, normalize(moon_dir));
		float moon = smoothstep(0.9990, 0.9993, md);
		float craters = fbm(dir.xz * 400.0);
		col += vec3(0.75, 0.8, 0.9) * moon * (0.7 + craters * 0.5) * 2.0 * stars;
	}

	// Étoiles
	if (stars > 0.01 && h > 0.0) {
		vec3 sp = dir * 260.0;
		vec3 cell = floor(sp);
		float rnd = hash13(cell);
		float star = step(0.9975, rnd);
		vec3 f = fract(sp) - 0.5;
		float point = smoothstep(0.35, 0.0, length(f));
		float twinkle = 0.6 + 0.4 * sin(TIME * (2.0 + rnd * 6.0) + rnd * 50.0);
		col += vec3(0.85, 0.9, 1.0) * star * point * twinkle * stars * smoothstep(0.0, 0.2, h) * 3.0;
		// Voie lactée
		float band = exp(-pow(dot(dir, normalize(vec3(0.3, 0.6, 0.74))) * 4.0, 2.0));
		col += vec3(0.25, 0.25, 0.35) * band * fbm(dir.xy * 9.0 + dir.z * 4.0) * stars * 0.35;
	}

	// Nuages projetés sur un plafond
	if (h > 0.01) {
		vec2 cp = dir.xz / (h + 0.08) * 1.6 + vec2(TIME * 0.004, TIME * 0.002);
		float c = fbm(cp * 1.4) * 0.7 + fbm(cp * 4.0) * 0.3;
		float cov = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.35, c);
		float lit = clamp(sun_dir.y * 2.0 + 0.3, 0.05, 1.0);
		vec3 cloud_col = mix(vec3(0.08, 0.09, 0.13), vec3(1.0) , lit);
		cloud_col = mix(cloud_col, vec3(1.0, 0.55, 0.3), low * 0.7 * clamp(sun_dir.y * 3.0 + 1.0, 0.0, 1.0));
		cloud_col += sun_color * pow(max(sd, 0.0), 6.0) * 0.6 * sun_up;
		col = mix(col, cloud_col, cov * smoothstep(0.01, 0.15, h) * 0.9);
	}

	COLOR = col * sky_energy;
}
