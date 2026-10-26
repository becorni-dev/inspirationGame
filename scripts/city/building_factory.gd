# Fabrique l'apparence des bâtiments à partir de formes simples (boîtes, prismes, cylindres).
# Toutes les pièces utilisent le shader des bâtiments : fenêtres, nuit, construction.
extends RefCounted

const CELL := 4.0

var materials := {}          # type -> ShaderMaterial (texture de mur propre au type)
var glow_material: ShaderMaterial
var box := BoxMesh.new()
var prism := PrismMesh.new()
var cylinder := CylinderMesh.new()
var taper := CylinderMesh.new()
var sphere := SphereMesh.new()
var lamp_lights: Array = []

const HOUSE_COLORS := ["#e3d5b8", "#d9b99b", "#c9d3d6", "#e8e2d4", "#b8a184", "#d6c2a1", "#a9b8a0"]
const ROOF_COLORS := ["#7a3b2e", "#5b4a45", "#3f4650", "#8a5a3c", "#4b3b36"]
const TOWER_COLORS := ["#9aa8b4", "#b7b2a8", "#7d8c99", "#c4c9cc", "#6f7f8e", "#a39686"]
const SIGN_COLORS := ["#ff4d6d", "#3ee0ff", "#ffb627", "#7cff6b", "#c77dff"]


func _init() -> void:
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 1.0
	cylinder.radial_segments = 16
	taper.top_radius = 0.28
	taper.bottom_radius = 0.5
	taper.height = 1.0
	taper.radial_segments = 16
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 16
	sphere.rings = 8


func material_for(type: String) -> ShaderMaterial:
	if not materials.has(type):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/building.gdshader")
		materials[type] = m
	return materials[type]


# Construit le bâtiment. Renvoie { node, parts, height, rotors, smoke, lights }.
func make(type: String, size: Vector2i, rng: RandomNumberGenerator, base_y: float, foundation: float) -> Dictionary:
	var ctx := {
		"node": Node3D.new(), "parts": [], "height": 4.0, "rotors": [], "smoke": [], "lights": [],
		"type": type, "rng": rng, "base_y": base_y,
	}
	var w := float(size.x) * CELL
	var d := float(size.y) * CELL
	# Socle qui rattrape la pente du terrain
	_part(ctx, box, Vector3(0, -foundation * 0.5 + 0.15, 0), Vector3(w - 0.3, foundation + 0.3, d - 0.3), Color("#8d8a84"))
	match type:
		"house":
			_house(ctx)
		"tower":
			_tower(ctx)
		"shop":
			_shop(ctx)
		"factory":
			_factory(ctx)
		"wind":
			_wind(ctx)
		"solar":
			_solar(ctx)
		"park":
			_park(ctx)
	for p in ctx["parts"]:
		var mi: MeshInstance3D = p
		mi.set_instance_shader_parameter("base_y", base_y - 0.2)
		mi.set_instance_shader_parameter("height", float(ctx["height"]) + 0.6)
	return ctx


func _part(ctx: Dictionary, mesh: Mesh, pos: Vector3, scale: Vector3, color: Color, windows := false, glow := 0.0, metal := 0.0, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale
	mi.material_override = material_for(ctx["type"])
	mi.set_instance_shader_parameter("tint", color)
	mi.set_instance_shader_parameter("windows", 1.0 if windows else 0.0)
	mi.set_instance_shader_parameter("seed", ctx["rng"].randf() * 100.0)
	mi.set_instance_shader_parameter("glow", glow)
	mi.set_instance_shader_parameter("metal", metal)
	if glow > 0.0:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder: Node3D = parent if parent != null else ctx["node"]
	holder.add_child(mi)
	ctx["parts"].append(mi)
	return mi


func _pick(rng: RandomNumberGenerator, list: Array) -> Color:
	return Color(list[rng.randi() % list.size()])


func _house(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var floors := 1 if rng.randf() < 0.55 else 2
	var h := 3.0 * float(floors)
	var wall := _pick(rng, HOUSE_COLORS)
	var roof := _pick(rng, ROOF_COLORS)
	var bw := rng.randf_range(2.6, 3.1)
	var bd := rng.randf_range(2.3, 2.8)
	_part(ctx, box, Vector3(0, h * 0.5, -0.2), Vector3(bw, h, bd), wall, true)
	var roof_h := rng.randf_range(1.3, 1.9)
	var r := _part(ctx, prism, Vector3(0, h + roof_h * 0.5, -0.2), Vector3(bw + 0.4, roof_h, bd + 0.4), roof)
	if rng.randf() < 0.5:
		r.rotation.y = PI * 0.5
		r.scale = Vector3(bd + 0.4, roof_h, bw + 0.4)
	_part(ctx, box, Vector3(bw * 0.25, h + roof_h * 0.7, -0.6), Vector3(0.45, 1.4, 0.45), Color("#6b5e57"))
	# Porte et petit perron côté rue (+z)
	_part(ctx, box, Vector3(-bw * 0.2, 1.05, -0.2 + bd * 0.5 + 0.02), Vector3(0.9, 2.1, 0.08), Color("#3b2a22"))
	_part(ctx, box, Vector3(-bw * 0.2, 0.12, -0.2 + bd * 0.5 + 0.5), Vector3(1.4, 0.24, 0.9), Color("#9b968e"))
	# Haie du jardin
	if rng.randf() < 0.6:
		_part(ctx, box, Vector3(0, 0.45, -1.75), Vector3(3.5, 0.9, 0.4), Color("#3d5c2a"))
	ctx["height"] = h + roof_h + 0.8


func _tower(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var h := snappedf(rng.randf_range(16.0, 42.0), 3.2)
	var glass := rng.randf() < 0.35
	var color := Color("#5d7a95") if glass else _pick(rng, TOWER_COLORS)
	var bw := rng.randf_range(3.0, 3.5)
	_part(ctx, box, Vector3(0, h * 0.5, 0), Vector3(bw, h, bw), color, true, 0.0, 0.5 if glass else 0.0)
	# Corniche et retrait au sommet
	_part(ctx, box, Vector3(0, h + 0.2, 0), Vector3(bw + 0.25, 0.4, bw + 0.25), color.darkened(0.25))
	var top := h + 0.4
	if h > 28.0:
		var th := rng.randf_range(3.0, 6.5)
		_part(ctx, box, Vector3(0, top + th * 0.5, 0), Vector3(bw * 0.7, th, bw * 0.7), color.darkened(0.1), true)
		top += th
	# Climatiseurs et antenne avec feu rouge
	for k in range(rng.randi_range(1, 3)):
		_part(ctx, box, Vector3(rng.randf_range(-0.8, 0.8), top + 0.35, rng.randf_range(-0.8, 0.8)), Vector3(0.7, 0.7, 0.9), Color("#a7adb2"))
	var ah := rng.randf_range(2.5, 5.0)
	_part(ctx, cylinder, Vector3(0.6, top + ah * 0.5, 0.6), Vector3(0.12, ah, 0.12), Color("#c8c8c8"), false, 0.0, 0.8)
	_part(ctx, sphere, Vector3(0.6, top + ah, 0.6), Vector3(0.3, 0.3, 0.3), Color("#ff2020"), false, 2.0)
	# Hall vitré au rez-de-chaussée
	_part(ctx, box, Vector3(0, 1.6, bw * 0.5 + 0.05), Vector3(bw * 0.6, 3.0, 0.1), Color("#e6d2a0"), false, 0.5)
	ctx["height"] = top + ah


func _shop(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var h := rng.randf_range(3.8, 5.0)
	var wall := _pick(rng, HOUSE_COLORS).darkened(0.1)
	var sign_col := _pick(rng, SIGN_COLORS)
	_part(ctx, box, Vector3(0, h * 0.5, -0.3), Vector3(3.6, h, 2.8), wall, true)
	# Vitrine éclairée
	_part(ctx, box, Vector3(0, 1.3, 1.12), Vector3(3.0, 2.2, 0.06), Color("#ffe7b3"), false, 0.45)
	# Auvent
	_part(ctx, box, Vector3(0, 2.75, 1.45), Vector3(3.5, 0.15, 0.9), sign_col.darkened(0.35))
	# Enseigne lumineuse
	_part(ctx, box, Vector3(0, h - 0.6, 1.12), Vector3(2.6, 0.7, 0.12), sign_col, false, 1.6)
	if rng.randf() < 0.5:
		_part(ctx, box, Vector3(0, h + 0.9, -0.3), Vector3(2.0, 1.4, 0.15), sign_col, false, 1.8)
		ctx["height"] = h + 1.6
	else:
		ctx["height"] = h + 0.2


func _factory(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var wall := Color("#9a8f84")
	_part(ctx, box, Vector3(0.6, 3.2, -0.4), Vector3(6.2, 6.4, 6.0), wall, false, 0.0, 0.1)
	# Toit en dents de scie
	for k in range(3):
		var r := _part(ctx, prism, Vector3(0.6 - 2.07 + float(k) * 2.07, 7.1, -0.4), Vector3(2.07, 1.4, 6.0), Color("#6d737a"), false, 0.0, 0.4)
		r.rotation.z = 0.0
	# Bureaux vitrés
	_part(ctx, box, Vector3(-3.0, 2.4, 2.4), Vector3(1.6, 4.8, 2.6), Color("#c7c2b8"), true)
	# Cuves
	for k in range(2):
		_part(ctx, cylinder, Vector3(-3.0 + float(k) * 1.5, 1.6, -2.6), Vector3(1.3, 3.2, 1.3), Color("#cfd4d8"), false, 0.0, 0.7)
	# Cheminées avec fumée
	for k in range(2):
		var cx := 2.6 + float(k) * 0.0
		var cz := -2.6 + float(k) * 2.2
		var ch := 15.0 - float(k) * 3.0
		_part(ctx, taper, Vector3(cx, ch * 0.5, cz), Vector3(1.1, ch, 1.1), Color("#8b6f5f"))
		_part(ctx, cylinder, Vector3(cx, ch - 1.2, cz), Vector3(0.7, 0.5, 0.7), Color("#e8e8e8"))
		_part(ctx, sphere, Vector3(cx, ch + 0.15, cz), Vector3(0.25, 0.25, 0.25), Color("#ff3030"), false, 1.5)
		ctx["smoke"].append(_smoke(ctx["node"], Vector3(cx, ch + 0.3, cz)))
	# Quai de chargement
	_part(ctx, box, Vector3(1.5, 0.5, 3.0), Vector3(3.5, 1.0, 1.4), Color("#7f7a72"))
	_part(ctx, box, Vector3(1.5, 1.9, 2.62), Vector3(2.4, 1.8, 0.1), Color("#ffcf8a"), false, 0.35)
	ctx["height"] = 16.0


func _wind(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var h := rng.randf_range(24.0, 30.0)
	var white := Color("#e9eef2")
	_part(ctx, taper, Vector3(0, h * 0.5, 0), Vector3(1.0, h, 1.0), white, false, 0.0, 0.2)
	_part(ctx, box, Vector3(0, h + 0.4, -0.3), Vector3(1.0, 1.0, 2.4), white, false, 0.0, 0.2)
	_part(ctx, sphere, Vector3(0, h + 1.0, -0.3), Vector3(0.25, 0.25, 0.25), Color("#ff2020"), false, 2.0)
	var rotor := Node3D.new()
	rotor.position = Vector3(0, h + 0.4, 1.0)
	ctx["node"].add_child(rotor)
	_part(ctx, sphere, Vector3.ZERO, Vector3(0.8, 0.8, 1.1), white, false, 0.0, 0.2, rotor)
	for k in range(3):
		var arm := Node3D.new()
		arm.rotation.z = TAU * float(k) / 3.0
		rotor.add_child(arm)
		_part(ctx, box, Vector3(0, 5.5, 0), Vector3(0.55, 11.0, 0.12), white, false, 0.0, 0.2, arm)
	rotor.rotation.z = rng.randf() * TAU
	ctx["rotors"].append(rotor)
	ctx["height"] = h + 12.0


func _solar(ctx: Dictionary) -> void:
	var panel := Color("#1b2c4f")
	for row in range(4):
		for col in range(2):
			var p := _part(ctx, box, Vector3(-1.9 + float(col) * 3.8, 1.0, -2.9 + float(row) * 1.9), Vector3(3.4, 0.08, 1.5), panel, false, 0.0, 0.9)
			p.rotation.x = deg_to_rad(-28.0)
			_part(ctx, box, Vector3(-1.9 + float(col) * 3.8, 0.45, -2.9 + float(row) * 1.9), Vector3(0.12, 0.9, 0.12), Color("#9aa0a6"), false, 0.0, 0.8)
	_part(ctx, box, Vector3(3.2, 0.9, 3.3), Vector3(1.0, 1.8, 0.8), Color("#d0d4d8"))
	_part(ctx, sphere, Vector3(3.2, 1.95, 3.6), Vector3(0.15, 0.15, 0.15), Color("#40ff80"), false, 1.5)
	ctx["height"] = 2.2


func _park(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	_part(ctx, box, Vector3(0, 0.1, 0), Vector3(3.8, 0.2, 3.8), Color("#4f7f32"))
	_part(ctx, box, Vector3(0, 0.22, 0), Vector3(0.8, 0.06, 3.8), Color("#c2b28f"))
	_part(ctx, box, Vector3(0, 0.22, 0), Vector3(3.8, 0.06, 0.8), Color("#c2b28f"))
	# Fontaine
	_part(ctx, cylinder, Vector3(0, 0.35, 0), Vector3(1.4, 0.3, 1.4), Color("#bdb8ae"))
	_part(ctx, cylinder, Vector3(0, 0.48, 0), Vector3(1.15, 0.05, 1.15), Color("#3fb6d8"), false, 0.3, 0.6)
	_part(ctx, cylinder, Vector3(0, 0.9, 0), Vector3(0.2, 1.0, 0.2), Color("#bdb8ae"))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var c: Vector2 = corner
		var s := rng.randf_range(0.8, 1.2)
		var pos := Vector3(c.x * 1.25, 0, c.y * 1.25)
		_part(ctx, cylinder, pos + Vector3(0, 0.8, 0), Vector3(0.18, 1.6, 0.18), Color("#5a4030"))
		_part(ctx, sphere, pos + Vector3(0, 2.2 * s, 0), Vector3(1.4, 1.3, 1.4) * s, Color("#4c7a2c").lerp(Color("#7a9a30"), rng.randf()))
	# Lampadaire du parc
	_part(ctx, cylinder, Vector3(1.7, 1.4, 0.6), Vector3(0.08, 2.8, 0.08), Color("#2d3136"), false, 0.0, 0.8)
	_part(ctx, sphere, Vector3(1.7, 2.85, 0.6), Vector3(0.28, 0.28, 0.28), Color("#ffd9a0"), false, 1.2)
	ctx["lights"].append(_lamp_light(ctx["node"], Vector3(1.7, 2.7, 0.6)))
	ctx["height"] = 3.6


func _smoke(parent: Node3D, pos: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = pos
	p.amount = 40
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 40, 40))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0.6, 0.15, 0.25)
	pm.damping_min = 0.2
	pm.damping_max = 0.4
	pm.scale_min = 1.2
	pm.scale_max = 2.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 3.5))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.85, 0.85, 0.0))
	grad.set_color(1, Color(0.6, 0.6, 0.62, 0.0))
	grad.add_point(0.12, Color(0.8, 0.8, 0.8, 0.55))
	grad.add_point(0.6, Color(0.7, 0.7, 0.72, 0.3))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_texture = _soft_dot()
	mat.roughness = 1.0
	quad.material = mat
	p.draw_pass_1 = quad
	parent.add_child(p)
	return p


var _dot_tex: GradientTexture2D = null


func _soft_dot() -> GradientTexture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot_tex = GradientTexture2D.new()
		_dot_tex.gradient = g
		_dot_tex.fill = GradientTexture2D.FILL_RADIAL
		_dot_tex.fill_from = Vector2(0.5, 0.5)
		_dot_tex.fill_to = Vector2(1.0, 0.5)
		_dot_tex.width = 64
		_dot_tex.height = 64
	return _dot_tex


func _lamp_light(parent: Node3D, pos: Vector3) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Color(1.0, 0.78, 0.5)
	l.omni_range = 9.0
	l.omni_attenuation = 1.4
	l.light_energy = 0.0
	l.shadow_enabled = false
	l.visible = false
	parent.add_child(l)
	lamp_lights.append(l)
	return l


# Lampadaire de rue (pas un bâtiment : posé au coin d'une route).
func make_street_lamp(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var ctx := {"node": Node3D.new(), "parts": [], "height": 5.0, "rotors": [], "smoke": [], "lights": [], "type": "lamp", "rng": rng}
	var root: Node3D = ctx["node"]
	root.position = pos
	parent.add_child(root)
	_part(ctx, cylinder, Vector3(0, 2.3, 0), Vector3(0.1, 4.6, 0.1), Color("#33383d"), false, 0.0, 0.8)
	_part(ctx, box, Vector3(0, 4.55, 0.35), Vector3(0.12, 0.08, 0.8), Color("#33383d"), false, 0.0, 0.8)
	_part(ctx, box, Vector3(0, 4.45, 0.7), Vector3(0.35, 0.1, 0.5), Color("#ffd9a0"), false, 1.4)
	_lamp_light(root, Vector3(0, 4.2, 0.7))
	return root
