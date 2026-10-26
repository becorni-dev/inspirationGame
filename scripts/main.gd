# Chef d'orchestre du prototype : crée le monde, la ville, l'interface et relie les commandes du joueur.
extends Node3D

const SkyRig := preload("res://scripts/world/sky_rig.gd")
const Terrain := preload("res://scripts/world/terrain.gd")
const Forest := preload("res://scripts/world/forest.gd")
const Boats := preload("res://scripts/world/boats.gd")
const City := preload("res://scripts/city/city.gd")
const Traffic := preload("res://scripts/city/traffic.gd")
const BuildingFactory := preload("res://scripts/city/building_factory.gd")
const CameraRig := preload("res://scripts/camera_rig.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const Style := preload("res://scripts/ui/style.gd")
const Atelier := preload("res://scripts/atelier/atelier.gd")

const WORLD_SEED := 2027
const SECONDS_PER_HOUR := 6.0          # à vitesse normale : une journée dure 2 min 24 s
const SPEEDS := [0.0, 1.0, 3.0, 8.0]
const MONTHS := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
const MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

var sky: SkyRig
var terrain: Terrain
var forest: Forest
var city: City
var traffic: Traffic
var cam: CameraRig
var hud: Hud
var atelier: Atelier
var water: MeshInstance3D
var ghost_factory := BuildingFactory.new()
var ghost_material: ShaderMaterial
var ghost: Node3D = null
var ghost_type := ""
var road_ghosts: Array = []

var playing := false
var photo_mode := false
var tool := ""
var speed := 1
var hour := 17.1                     # heure de la journée
var day := 0
var hour_accum := 0.0
var hover_cell := Vector2i(-1, -1)
var hover_valid := false
var drag_start := Vector2i(-1, -1)
var dragging := false
var selected := -1


func _ready() -> void:
	_declare_globals()
	sky = SkyRig.new()
	add_child(sky)
	sky.build()

	terrain = Terrain.new()
	add_child(terrain)
	terrain.build(WORLD_SEED)
	terrain.material.set_shader_parameter("grid_bounds", Vector4(City.ORIGIN, City.ORIGIN, City.ORIGIN + City.CELL * City.N, City.ORIGIN + City.CELL * City.N))
	terrain.material.set_shader_parameter("cell_size", City.CELL)
	_build_water()

	city = City.new()
	city.name = "Ville"
	add_child(city)
	forest = Forest.new()
	forest.name = "Forêts"
	add_child(forest)
	forest.build(terrain, city, WORLD_SEED, 14000)
	city.setup(terrain, forest, WORLD_SEED)

	var boats := Boats.new()
	add_child(boats)
	boats.build(6, WORLD_SEED)

	traffic = Traffic.new()
	add_child(traffic)
	traffic.setup(city)

	cam = CameraRig.new()
	add_child(cam)
	cam.setup(terrain)
	cam.focus_on(Vector3(10, 4, 20), 150.0)
	cam.pitch = deg_to_rad(-22.0)
	cam.yaw = deg_to_rad(-25.0)
	cam.auto_orbit = true

	ghost_material = ShaderMaterial.new()
	ghost_material.shader = load("res://shaders/ghost.gdshader")

	hud = Hud.new()
	add_child(hud)
	hud.build(city.defs, city.order)
	hud.tool_selected.connect(_on_tool_selected)
	hud.speed_selected.connect(func(i: int) -> void: speed = i)
	hud.play_pressed.connect(_start_game)
	hud.atelier_pressed.connect(func() -> void: atelier.toggle())
	hud.demolish_selected_pressed.connect(_demolish_selected)

	atelier = Atelier.new()
	add_child(atelier)
	atelier.setup()
	atelier.asset_changed.connect(func(_id: String) -> void: _apply_assets())
	_apply_assets()

	_build_starter_town()
	sky.apply_quality()
	sky.set_time(hour)
	city.changed.connect(_on_city_changed)
	_refresh_hud()


func _declare_globals() -> void:
	# Sécurité : si project.godot n'a pas déclaré les paramètres globaux des shaders
	var names := RenderingServer.global_shader_parameter_get_list()
	if not names.has(&"night"):
		RenderingServer.global_shader_parameter_add("night", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	if not names.has(&"wind_strength"):
		RenderingServer.global_shader_parameter_add("wind_strength", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0)


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1600, 1600)
	plane.subdivide_width = 260
	plane.subdivide_depth = 260
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	plane.material = mat
	water = MeshInstance3D.new()
	water.name = "Eau"
	water.mesh = plane
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(0, Terrain.WATER_LEVEL, 0)
	add_child(water)


# --- Images de l'atelier --------------------------------------------------

func _apply_assets() -> void:
	var pairs := [["terrain_herbe", "grass"], ["terrain_roche", "rock"], ["terrain_sable", "sand"], ["terrain_neige", "snow"]]
	for p in pairs:
		var tex := atelier.texture(p[0])
		terrain.material.set_shader_parameter("use_%s_tex" % p[1], tex != null)
		terrain.material.set_shader_parameter("%s_tex" % p[1], tex)
	var asphalt := atelier.texture("route_asphalte")
	city.road_material.set_shader_parameter("use_asphalt_tex", asphalt != null)
	city.road_material.set_shader_parameter("asphalt_tex", asphalt)
	var walls := {"house": "mur_maison", "tower": "mur_immeuble", "shop": "mur_commerce", "factory": "mur_usine"}
	for type in walls:
		var tex := atelier.texture(walls[type])
		var m := city.factory.material_for(type)
		m.set_shader_parameter("use_wall_tex", tex != null)
		m.set_shader_parameter("wall_tex", tex)
	var leaf := atelier.texture("feuillage")
	forest.material.set_shader_parameter("use_leaf_tex", leaf != null)
	forest.material.set_shader_parameter("leaf_tex", leaf)
	for type in city.order:
		hud.set_tool_icon(type, atelier.texture("icone_" + str(type)))


# --- Ville de départ ------------------------------------------------------

func _build_starter_town() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	# Le temps de poser la ville de départ, l'argent et les déblocages ne comptent pas
	city.economy.money = 1.0e9
	city.economy.population = 1.0e5
	var road_cells: Array[Vector2i] = []
	for i in range(14, 47):
		road_cells.append(Vector2i(i, 29))
	for i in [20, 28, 36]:
		for j in range(19, 41):
			road_cells.append(Vector2i(i, j))
	for i in range(20, 37):
		road_cells.append(Vector2i(i, 37))
		road_cells.append(Vector2i(i, 22))
	for c in road_cells:
		city.build_road(c, true)

	# Centre : immeubles et commerces autour du carrefour principal
	var downtown := [Vector2i(27, 28), Vector2i(29, 28), Vector2i(27, 30), Vector2i(29, 30), Vector2i(27, 27), Vector2i(29, 27), Vector2i(29, 31), Vector2i(27, 31), Vector2i(29, 26), Vector2i(27, 32)]
	for c in downtown:
		city.build("tower", c, true)
	for c in [Vector2i(35, 28), Vector2i(37, 28), Vector2i(21, 30), Vector2i(19, 30), Vector2i(35, 30), Vector2i(21, 28), Vector2i(31, 30), Vector2i(25, 28)]:
		city.build("shop", c, true)
	# Industrie à l'est, énergie à l'ouest
	city.build("factory", Vector2i(40, 30), true)
	city.build("factory", Vector2i(43, 30), true)
	city.build("solar", Vector2i(40, 27), true)
	for c in [Vector2i(15, 28), Vector2i(17, 28), Vector2i(15, 30), Vector2i(17, 30), Vector2i(14, 26), Vector2i(16, 32)]:
		city.build("wind", c, true)
	for c in [Vector2i(24, 34), Vector2i(32, 25), Vector2i(24, 25), Vector2i(32, 34)]:
		city.build("park", c, true)
	# Quartiers de maisons le long des rues
	for c in road_cells:
		for d in City.DIRS:
			var n: Vector2i = c + d
			if rng.randf() < 0.72 and city.check("house", n) == "":
				city.build("house", n, true)
	city.refresh_status()
	city.economy.money = float(city.economy.rules.get("start_money", 60000))
	city.economy.population = city.economy.capacity * 0.0
	for k in range(30):
		city.tick_hour(1.0)
	city.economy.money = float(city.economy.rules.get("start_money", 60000))


func _start_game() -> void:
	playing = true
	cam.auto_orbit = false
	cam.focus_on(Vector3(8, 4, 10), 110.0)
	cam.pitch = deg_to_rad(-42.0)
	hud.hide_title()
	hud.toast("Bienvenue à Nouvelle Rive ! Choisis un bâtiment en bas de l'écran.", Style.ACCENT)


# --- Boucle ---------------------------------------------------------------

func _process(delta: float) -> void:
	var rate: float = SPEEDS[speed] if playing else 0.15
	if photo_mode:
		rate = maxf(rate, 0.3)
	var hours := delta * rate / SECONDS_PER_HOUR
	hour += hours
	hour_accum += hours
	while hour >= 24.0:
		hour -= 24.0
		day += 1
	while hour_accum >= 1.0:
		hour_accum -= 1.0
		if playing:
			city.tick_hour(sky_daylight())
			_refresh_hud()
	sky.set_time(hour)
	city.night = sky.night
	traffic.speed_scale = 1.0 if speed == 0 else clampf(SPEEDS[speed], 1.0, 2.0)
	var roads := city.roads.size()
	var target := 0
	if roads > 3:
		target = mini(int(roads * 0.6), mini(int(city.economy.population / 6.0) + 8, 160))
	traffic.update_cars(delta if speed > 0 or not playing else 0.0, target, sky.night)
	if playing:
		hud.set_clock(_clock_text(), speed)


func sky_daylight() -> float:
	return clampf(1.0 - sky.night * 1.3, 0.0, 1.0) * clampf(sin((hour - 6.0) / 12.0 * PI) * 1.4, 0.0, 1.0)


func _clock_text() -> String:
	var d := day
	var m := 2                       # la partie commence le 1er mars 2027
	var year := 2027
	while d >= MONTH_DAYS[m]:
		d -= MONTH_DAYS[m]
		m += 1
		if m >= 12:
			m = 0
			year += 1
	var h := int(floor(hour))
	var mi := int(floor((hour - float(h)) * 60.0))
	return "%d %s %d  %02d:%02d" % [d + 1, MONTHS[m], year, h, mi]


func _refresh_hud() -> void:
	var unlocked := {}
	for type in city.order:
		var def: Dictionary = city.defs[type]
		unlocked[type] = city.economy.population >= float(def.get("unlock_population", 0))
	hud.refresh(city.economy, unlocked)
	if selected > 0:
		_show_selected()


func _on_city_changed() -> void:
	_refresh_hud()


# --- Commandes ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		_on_key(event as InputEventKey)
		return
	if not playing or photo_mode or atelier.is_open():
		return
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
		if dragging and tool == "demolish":
			_demolish_at(hover_cell)
		elif dragging and tool != "road" and tool != "" and city.size_of(tool) == Vector2i.ONE:
			_try_build(tool, hover_cell, false)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_update_hover(mb.position)
		if mb.pressed:
			dragging = true
			drag_start = hover_cell
			if tool == "demolish":
				_demolish_at(hover_cell)
			elif tool == "":
				_select_at(hover_cell)
			elif tool != "road":
				_try_build(tool, hover_cell, true)
		else:
			if dragging and tool == "road":
				_build_road_path(drag_start, hover_cell)
			dragging = false
			_clear_road_ghosts()


func _on_key(k: InputEventKey) -> void:
	var code := k.physical_keycode
	if code == KEY_F11:
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if code == KEY_G:
		hud.toast("Qualité graphique : %s" % sky.cycle_quality(), Style.BLUEPRINT)
		return
	if code == KEY_I:
		atelier.toggle()
		return
	if atelier.is_open():
		if code == KEY_ESCAPE:
			atelier.toggle()
		return
	if not playing:
		return
	if code == KEY_P:
		photo_mode = not photo_mode
		cam.auto_orbit = photo_mode
		cam.tilt_shift = true
		hud.set_photo_mode(photo_mode)
		_set_tool("")
		return
	if photo_mode:
		if code == KEY_ESCAPE:
			photo_mode = false
			cam.auto_orbit = false
			hud.set_photo_mode(false)
		return
	match code:
		KEY_ESCAPE:
			if tool != "":
				_set_tool("")
			else:
				selected = -1
				hud.hide_inspector()
				hud.help_panel.visible = false
		KEY_R:
			_on_tool_selected("road")
		KEY_B, KEY_DELETE:
			_on_tool_selected("demolish")
		KEY_SPACE:
			speed = 1 if speed == 0 else 0
		KEY_TAB:
			speed = 1 + (speed % 3)
		KEY_N:
			hour += 3.0
			hud.toast("+3 heures", Style.BLUEPRINT)
		KEY_O:
			cam.tilt_shift = not cam.tilt_shift
			hud.toast("Effet maquette : %s" % ("oui" if cam.tilt_shift else "non"), Style.BLUEPRINT)
		KEY_H:
			hud.toggle_help()
		_:
			if code >= KEY_1 and code <= KEY_9:
				var idx := int(code - KEY_1) + 1
				if idx < city.order.size():
					_on_tool_selected(str(city.order[idx]))


func _on_tool_selected(type: String) -> void:
	_set_tool("" if tool == type else type)


func _set_tool(type: String) -> void:
	tool = type
	hud.set_tool(type)
	selected = -1
	hud.hide_inspector()
	terrain.material.set_shader_parameter("grid_alpha", 1.0 if type != "" else 0.0)
	_rebuild_ghost()
	_update_ghost()


func _rebuild_ghost() -> void:
	if ghost != null:
		ghost.queue_free()
		ghost = null
	ghost_type = ""
	if tool == "" or tool == "road" or tool == "demolish":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var made := ghost_factory.make(tool, city.size_of(tool), rng, 0.0, 1.0)
	ghost = made["node"]
	for p in made["parts"]:
		var mi: MeshInstance3D = p
		mi.material_override = ghost_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for s in made["smoke"]:
		s.queue_free()
	for l in ghost_factory.lamp_lights:
		if is_instance_valid(l):
			l.queue_free()
	ghost_factory.lamp_lights.clear()
	ghost_type = tool
	add_child(ghost)


func _update_hover(screen: Vector2) -> void:
	var ray := cam.ray_from_mouse(screen)
	var hit: Variant = terrain.raycast(ray[0], ray[1])
	if hit == null:
		hover_cell = Vector2i(-1, -1)
	else:
		hover_cell = city.cell_of(hit)
	if dragging and tool == "road":
		_preview_road_path(drag_start, hover_cell)
	_update_ghost()


func _update_ghost() -> void:
	var size := Vector2i.ONE
	if tool != "" and tool != "road" and tool != "demolish":
		size = city.size_of(tool)
	if hover_cell.x < 0 or not playing:
		terrain.material.set_shader_parameter("hover_rect", Vector4.ZERO)
		if ghost != null:
			ghost.visible = false
		return
	var reason := ""
	if tool == "road":
		reason = city.can_build_road(hover_cell)
	elif tool == "demolish":
		reason = "" if (city.roads.has(hover_cell) or city.occupied.has(hover_cell)) else "Rien à démolir"
	elif tool != "":
		reason = city.check(tool, hover_cell)
	hover_valid = reason == ""
	var col := Style.BLUEPRINT if hover_valid else Style.BAD
	if tool == "demolish" and hover_valid:
		col = Style.WARN
	if tool == "" and city.occupied.has(hover_cell):
		var b := city.building_at(hover_cell)
		terrain.material.set_shader_parameter("hover_rect", city.rect_of(b["cell"], b["size"]))
	else:
		terrain.material.set_shader_parameter("hover_rect", city.rect_of(hover_cell, size) if tool != "" else Vector4.ZERO)
	terrain.material.set_shader_parameter("hover_color", col)
	ghost_material.set_shader_parameter("color", col)
	if ghost != null:
		var center := city.footprint_center(hover_cell, size)
		var y := terrain.height_at(center.x, center.z)
		ghost.position = Vector3(center.x, y + 0.05, center.z)
		ghost.rotation.y = city._facing(hover_cell, size)
		ghost.visible = true
	if not hover_valid and tool != "" and tool != "demolish":
		hud.hint_label.text = reason
	elif tool != "":
		hud.set_tool(tool)


# --- Routes ---------------------------------------------------------------

func _road_path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if a.x < 0 or b.x < 0:
		return path
	# D'abord dans la direction la plus longue, puis l'autre (tracé en L)
	var horizontal_first := absi(b.x - a.x) >= absi(b.y - a.y)
	var c := a
	path.append(c)
	if horizontal_first:
		while c.x != b.x:
			c.x += signi(b.x - a.x)
			path.append(c)
		while c.y != b.y:
			c.y += signi(b.y - a.y)
			path.append(c)
	else:
		while c.y != b.y:
			c.y += signi(b.y - a.y)
			path.append(c)
		while c.x != b.x:
			c.x += signi(b.x - a.x)
			path.append(c)
	return path


func _preview_road_path(a: Vector2i, b: Vector2i) -> void:
	var path := _road_path(a, b)
	while road_ghosts.size() < path.size():
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(City.CELL * 0.96, 0.5, City.CELL * 0.96)
		mi.mesh = bm
		mi.material_override = ghost_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		road_ghosts.append(mi)
	var cost := 0.0
	for i in range(road_ghosts.size()):
		var g: MeshInstance3D = road_ghosts[i]
		if i < path.size():
			var c := city.cell_center(path[i])
			g.position = Vector3(c.x, terrain.height_at(c.x, c.z) + 0.1, c.z)
			g.visible = not city.roads.has(path[i])
			if g.visible:
				cost += float(city.defs["road"]["cost"])
		else:
			g.visible = false
	hud.hint_label.text = "Route : %d cases · %s ¤" % [path.size(), Style.num(cost)]


func _clear_road_ghosts() -> void:
	for g in road_ghosts:
		g.visible = false


func _build_road_path(a: Vector2i, b: Vector2i) -> void:
	var built := 0
	var failed := ""
	for c in _road_path(a, b):
		if city.roads.has(c):
			continue
		var reason := city.can_build_road(c)
		if reason == "":
			city.build_road(c)
			built += 1
		elif failed == "":
			failed = reason
	if built > 0:
		hud.toast("%d case(s) de route construites" % built, Style.GOOD)
	if failed != "":
		hud.toast("Certaines cases n'ont pas pu être construites : %s" % failed, Style.WARN)


# --- Construction, démolition, fiche ---------------------------------------

func _try_build(type: String, c: Vector2i, report: bool) -> void:
	if c.x < 0:
		return
	var reason := city.check(type, c)
	if reason != "":
		if report:
			hud.toast(reason, Style.BAD)
		return
	var id := city.build(type, c)
	if id > 0:
		var b: Dictionary = city.buildings[id]
		if not city.has_road_access(b):
			hud.toast("%s posé(e), mais sans route il ne fonctionnera pas." % city.defs[type]["name"], Style.WARN)
	_update_ghost()


func _demolish_at(c: Vector2i) -> void:
	if c.x < 0:
		return
	var refund := city.demolish(c)
	if refund > 0.0:
		hud.toast("Démoli : +%s ¤" % Style.num(refund), Style.WARN)


func _select_at(c: Vector2i) -> void:
	if c.x < 0 or not city.occupied.has(c):
		selected = -1
		hud.hide_inspector()
		return
	selected = city.occupied[c]
	_show_selected()


func _show_selected() -> void:
	if not city.buildings.has(selected):
		selected = -1
		hud.hide_inspector()
		return
	var b: Dictionary = city.buildings[selected]
	var def: Dictionary = city.defs[b["type"]]
	var eco := city.economy
	var lines: Array = []
	if not b["built"]:
		lines.append(["En construction…", Style.BLUEPRINT])
	elif not b["active"]:
		lines.append(["Ne fonctionne pas : aucune route ne touche ce bâtiment.", Style.BAD])
	else:
		lines.append(["En service", Style.GOOD])
	if def.has("residents"):
		lines.append(["Logements : %d habitants" % int(def["residents"]), Style.FG])
		var local := 60.0 + float(b["happy_bonus"]) - float(b["pollution"])
		lines.append(["Bonheur du quartier : %d %%" % int(local), Style.GOOD if local >= 65 else Style.WARN])
		lines.append(["   Parcs proches : +%d" % int(b["happy_bonus"]), Style.MUTED])
		lines.append(["   Pollution des usines : −%d" % int(b["pollution"]), Style.BAD if float(b["pollution"]) > 0 else Style.MUTED])
	if def.has("jobs"):
		var filled := 0.0 if eco.jobs <= 0.0 else eco.workers / eco.jobs
		lines.append(["Emplois : %d (occupés à %d %%)" % [int(def["jobs"]), int(filled * 100.0)], Style.FG])
		lines.append(["Rapporte environ %s ¤/h" % Style.num(float(def["jobs"]) * filled * float(def.get("tax_per_worker", 0)) * eco.power_ratio, 1), Style.GOOD])
	if def.has("power"):
		var p := float(def["power"])
		if p > 0:
			var now := p * (sky_daylight() if b["type"] == "solar" else eco.wind_factor)
			lines.append(["Produit %s MW maintenant (%d MW au mieux)" % [Style.num(now, 1), int(p)], Style.GOOD])
		else:
			lines.append(["Consomme %d MW" % int(-p), Style.WARN])
	if def.has("happiness"):
		lines.append(["+%d bonheur pour les logements à %d cases" % [int(def["happiness"]), int(def["happiness_radius"])], Style.GOOD])
	if def.has("pollution"):
		lines.append(["Pollue les logements à %d cases (jusqu'à −%d)" % [int(def["pollution_radius"]), int(def["pollution"])], Style.BAD])
	lines.append(["Entretien : %s ¤/h" % Style.num(float(def.get("upkeep", 0)), 1), Style.MUTED])
	hud.show_inspector(str(def["name"]), lines, true)


func _demolish_selected() -> void:
	if selected > 0 and city.buildings.has(selected):
		var b: Dictionary = city.buildings[selected]
		_demolish_at(b["cell"])
	selected = -1
	hud.hide_inspector()
