# Ciel, soleil, lune, brouillard et effets de rendu ; cycle jour et nuit.
extends Node3D

var environment: Environment
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_material: ShaderMaterial
var night := 0.0             # 0 en plein jour, 1 en pleine nuit
var quality := 0             # 0 Ultra, 1 Élevée, 2 Moyenne
const QUALITY_NAMES := ["Ultra", "Élevée", "Moyenne"]

# Couleurs du ciel par moment : [élévation du soleil, zénith, horizon, soleil]
const SKY_KEYS := [
	[-0.35, Color(0.005, 0.008, 0.02), Color(0.02, 0.03, 0.06), Color(0.5, 0.5, 0.7)],
	[-0.08, Color(0.04, 0.05, 0.12), Color(0.35, 0.18, 0.18), Color(1.0, 0.4, 0.2)],
	[0.02, Color(0.15, 0.20, 0.38), Color(0.95, 0.48, 0.25), Color(1.0, 0.55, 0.25)],
	[0.15, Color(0.20, 0.38, 0.68), Color(0.85, 0.72, 0.6), Color(1.0, 0.82, 0.6)],
	[0.5, Color(0.13, 0.34, 0.70), Color(0.62, 0.77, 0.92), Color(1.0, 0.95, 0.88)],
	[1.0, Color(0.10, 0.30, 0.68), Color(0.55, 0.72, 0.92), Color(1.0, 0.97, 0.92)],
]


func build() -> void:
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_energy = 1.0
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 6.0

	environment.ssao_enabled = true
	environment.ssao_radius = 1.6
	environment.ssao_intensity = 2.2
	environment.ssao_power = 1.6
	environment.ssil_enabled = true
	environment.ssil_radius = 4.0
	environment.ssr_enabled = true
	environment.ssr_max_steps = 64
	environment.sdfgi_enabled = true
	environment.sdfgi_use_occlusion = true
	environment.sdfgi_cascades = 4
	environment.sdfgi_min_cell_size = 0.4
	environment.sdfgi_energy = 0.9

	environment.glow_enabled = true
	environment.glow_intensity = 0.7
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.1
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	environment.fog_enabled = true
	environment.fog_density = 0.0012
	environment.fog_sky_affect = 0.25
	environment.fog_aerial_perspective = 0.6
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.006
	environment.volumetric_fog_anisotropy = 0.7
	environment.volumetric_fog_length = 180.0
	environment.volumetric_fog_detail_spread = 2.0
	environment.volumetric_fog_sky_affect = 0.0

	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.08

	world_env = WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Soleil"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 450.0
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.6
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "Lune"
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 250.0
	moon.light_angular_distance = 0.4
	add_child(moon)


# hour : heure de la journée, de 0 à 24
func set_time(hour: float) -> void:
	# Le soleil se lève à l'est (x+) à 6 h, passe au sud à midi et se couche à l'ouest à 18 h
	var a := (hour - 6.0) / 12.0 * PI
	var tilt := deg_to_rad(32.0)
	var sun_dir := Vector3(cos(a), sin(a) * cos(tilt), sin(a) * sin(tilt) + 0.12).normalized()
	var moon_dir := Vector3(-sun_dir.x, -sun_dir.y * 0.8 + 0.15, -sun_dir.z).normalized()

	sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.FORWARD)
	moon.look_at_from_position(Vector3.ZERO, -moon_dir, Vector3.UP if absf(moon_dir.y) < 0.99 else Vector3.FORWARD)

	var e := sun_dir.y
	var cols := _sky_colors(e)
	var day := smoothstep(-0.06, 0.12, e)
	night = 1.0 - smoothstep(-0.12, 0.06, e)

	sun.light_color = cols[2]
	sun.light_energy = day * 2.6
	sun.visible = e > -0.08
	moon.light_energy = night * 0.22
	moon.visible = night > 0.02 and moon_dir.y > 0.0

	sky_material.set_shader_parameter("sun_dir", sun_dir)
	sky_material.set_shader_parameter("moon_dir", moon_dir)
	sky_material.set_shader_parameter("zenith_color", cols[0])
	sky_material.set_shader_parameter("horizon_color", cols[1])
	sky_material.set_shader_parameter("sun_color", cols[2])
	sky_material.set_shader_parameter("stars", night)
	sky_material.set_shader_parameter("sky_energy", lerpf(0.6, 1.0, day))

	environment.ambient_light_energy = lerpf(0.35, 1.0, day)
	environment.tonemap_exposure = lerpf(1.6, 1.0, day)
	var fog_col: Color = cols[1]
	environment.fog_light_color = fog_col
	# Brume plus dense à l'aube et au crépuscule
	var golden := 1.0 - smoothstep(0.0, 0.3, absf(e - 0.04))
	environment.volumetric_fog_density = 0.004 + golden * 0.01 + night * 0.004
	environment.volumetric_fog_albedo = Color(0.9, 0.9, 1.0).lerp(Color(1.0, 0.75, 0.55), golden)
	environment.volumetric_fog_emission = Color(0.02, 0.025, 0.05) * night
	RenderingServer.global_shader_parameter_set("night", night)


func _sky_colors(e: float) -> Array:
	for k in range(SKY_KEYS.size() - 1):
		var a: Array = SKY_KEYS[k]
		var b: Array = SKY_KEYS[k + 1]
		var ea: float = a[0]
		var eb: float = b[0]
		if e <= eb or k == SKY_KEYS.size() - 2:
			var t := clampf((e - ea) / (eb - ea), 0.0, 1.0)
			var za: Color = a[1]
			var ha: Color = a[2]
			var sa: Color = a[3]
			return [za.lerp(b[1], t), ha.lerp(b[2], t), sa.lerp(b[3], t)]
	return [SKY_KEYS[0][1], SKY_KEYS[0][2], SKY_KEYS[0][3]]


func cycle_quality() -> String:
	quality = (quality + 1) % 3
	apply_quality()
	return QUALITY_NAMES[quality]


func apply_quality() -> void:
	var vp := get_viewport()
	environment.sdfgi_enabled = quality == 0
	environment.ssil_enabled = quality <= 1
	environment.ssr_enabled = quality <= 1
	environment.volumetric_fog_enabled = quality <= 1
	environment.ssao_enabled = true
	vp.msaa_3d = Viewport.MSAA_2X if quality == 0 else Viewport.MSAA_DISABLED
	vp.use_taa = quality <= 1
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if quality <= 1 else Viewport.SCREEN_SPACE_AA_FXAA
	if quality == 2:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		vp.scaling_3d_scale = 0.77
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
	sun.directional_shadow_max_distance = 450.0 if quality == 0 else 300.0
