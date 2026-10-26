# La ville : grille de construction, routes, bâtiments, lampadaires, et le lien avec l'économie.
extends Node3D

const BuildingFactory := preload("res://scripts/city/building_factory.gd")
const Economy := preload("res://scripts/city/economy.gd")
const Terrain := preload("res://scripts/world/terrain.gd")
const Forest := preload("res://scripts/world/forest.gd")

const CELL := 4.0
const N := 60
const ORIGIN := -120.0
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)] # nord, est, sud, ouest

signal changed

var terrain: Terrain
var forest: Forest
var defs := {}
var order: Array = []
var factory := BuildingFactory.new()
var economy := Economy.new()
var rng := RandomNumberGenerator.new()

var occupied := {}           # case -> identifiant du bâtiment
var roads := {}              # case -> { mesh, lamp, height }
var buildings := {}          # identifiant -> { type, cell, size, node, parts, rotors, smoke, active, ... }
var next_id := 1
var constructing: Array = [] # [{ parts, t, duration, road }]
var road_material: ShaderMaterial
var road_mesh := BoxMesh.new()
var night := 0.0
var wind_time := 0.0


func setup(t: Terrain, f: Forest, world_seed: int) -> void:
	terrain = t
	forest = f
	rng.seed = world_seed
	var file := FileAccess.open("res://data/buildings.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	defs = data["types"]
	order = data["order"]
	economy.setup(data["economy"])
	road_material = ShaderMaterial.new()
	road_material.shader = load("res://shaders/road.gdshader")
	road_mesh.size = Vector3(CELL, 0.6, CELL)


# --- Grille -------------------------------------------------------------

func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - ORIGIN) / CELL), floori((p.z - ORIGIN) / CELL))


func cell_center(c: Vector2i) -> Vector3:
	return Vector3(ORIGIN + (float(c.x) + 0.5) * CELL, 0.0, ORIGIN + (float(c.y) + 0.5) * CELL)


func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < N and c.y < N


func size_of(type: String) -> Vector2i:
	var s: Array = defs[type].get("size", [1, 1])
	return Vector2i(int(s[0]), int(s[1]))


func footprint(c: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for dx in range(size.x):
		for dz in range(size.y):
			list.append(c + Vector2i(dx, dz))
	return list


# Rectangle couvert au sol (min x, min z, max x, max z) pour la surbrillance.
func rect_of(c: Vector2i, size: Vector2i) -> Vector4:
	var x0 := ORIGIN + float(c.x) * CELL
	var z0 := ORIGIN + float(c.y) * CELL
	return Vector4(x0, z0, x0 + float(size.x) * CELL, z0 + float(size.y) * CELL)


func _heights(c: Vector2i, size: Vector2i) -> Vector2:
	var r := rect_of(c, size)
	var lo := INF
	var hi := -INF
	for k in range(5):
		for m in range(5):
			var x := lerpf(r.x, r.z, float(k) / 4.0)
			var z := lerpf(r.y, r.w, float(m) / 4.0)
			var h := terrain.height_at(x, z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return Vector2(lo, hi)


func footprint_center(c: Vector2i, size: Vector2i) -> Vector3:
	var r := rect_of(c, size)
	return Vector3((r.x + r.z) * 0.5, 0.0, (r.y + r.w) * 0.5)


# Raison pour laquelle on ne peut pas construire ici ("" si c'est possible).
func check(type: String, c: Vector2i) -> String:
	var def: Dictionary = defs[type]
	var size := size_of(type)
	for cell in footprint(c, size):
		if not in_grid(cell):
			return "Hors de la zone constructible"
		if occupied.has(cell) or roads.has(cell):
			return "Case déjà occupée"
	var hl := _heights(c, size)
	if hl.x < 0.8:
		return "Trop près de l'eau"
	if hl.y - hl.x > 2.2 * float(maxi(size.x, size.y)):
		return "Terrain trop en pente"
	var unlock := float(def.get("unlock_population", 0))
	if economy.population < unlock:
		return "Se débloque à %d habitants" % int(unlock)
	if economy.money < float(def.get("cost", 0)):
		return "Pas assez d'argent"
	return ""


# --- Construction -------------------------------------------------------

func build(type: String, c: Vector2i, instant := false) -> int:
	if type == "road":
		return 1 if build_road(c, instant) else 0
	if check(type, c) != "":
		return 0
	var def: Dictionary = defs[type]
	economy.money -= float(def.get("cost", 0))
	var size := size_of(type)
	var hl := _heights(c, size)
	var base_y := hl.y + 0.05
	var b_rng := RandomNumberGenerator.new()
	b_rng.seed = rng.randi()
	var made := factory.make(type, size, b_rng, base_y, hl.y - hl.x + 1.2)
	var node: Node3D = made["node"]
	var center := footprint_center(c, size)
	node.position = Vector3(center.x, base_y, center.z)
	node.rotation.y = _facing(c, size)
	add_child(node)
	var id := next_id
	next_id += 1
	for cell in footprint(c, size):
		occupied[cell] = id
		if forest != null:
			forest.clear_cell(cell)
	buildings[id] = {
		"id": id, "type": type, "cell": c, "size": size, "node": node,
		"parts": made["parts"], "rotors": made["rotors"], "smoke": made["smoke"],
		"height": made["height"], "active": false, "happy_bonus": 0.0, "pollution": 0.0,
		"built": instant,
	}
	if instant:
		_set_progress(made["parts"], 1.0)
	else:
		_set_progress(made["parts"], 0.0)
		for s in made["smoke"]:
			s.emitting = false
		constructing.append({"id": id, "parts": made["parts"], "t": 0.0, "duration": float(def.get("build_time", 2.0)), "road": false})
	refresh_status()
	changed.emit()
	return id


# Orientation : la façade (+z) regarde la première route voisine.
func _facing(c: Vector2i, size: Vector2i) -> float:
	var angles := {Vector2i(0, 1): 0.0, Vector2i(1, 0): PI * 0.5, Vector2i(-1, 0): -PI * 0.5, Vector2i(0, -1): PI}
	for dir in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		for cell in footprint(c, size):
			if roads.has(cell + dir):
				return angles[dir]
	return 0.0


func can_build_road(c: Vector2i) -> String:
	if not in_grid(c):
		return "Hors de la zone constructible"
	if occupied.has(c):
		return "Case déjà occupée"
	if roads.has(c):
		return "Déjà une route"
	var hl := _heights(c, Vector2i.ONE)
	if hl.x < 0.6:
		return "Trop près de l'eau"
	if hl.y - hl.x > 2.5:
		return "Terrain trop en pente"
	if economy.money < float(defs["road"]["cost"]):
		return "Pas assez d'argent"
	return ""


func build_road(c: Vector2i, instant := false) -> bool:
	if can_build_road(c) != "":
		return false
	economy.money -= float(defs["road"]["cost"])
	var hl := _heights(c, Vector2i.ONE)
	var h := (hl.x + hl.y) * 0.5 + 0.08
	var mi := MeshInstance3D.new()
	mi.mesh = road_mesh
	mi.material_override = road_material
	var center := cell_center(c)
	mi.position = Vector3(center.x, h - 0.3, center.z)
	add_child(mi)
	var lamp: Node3D = null
	if (c.x + c.y) % 3 == 0:
		lamp = factory.make_street_lamp(self, Vector3(center.x + 1.75, h, center.z + 1.75), rng)
	roads[c] = {"mesh": mi, "lamp": lamp, "height": h}
	if forest != null:
		forest.clear_cell(c)
	_update_links(c)
	for d in DIRS:
		_update_links(c + d)
	if not instant:
		mi.set_instance_shader_parameter("progress", 0.0)
		constructing.append({"id": -1, "parts": [mi], "t": 0.0, "duration": 0.5, "road": true})
	refresh_status()
	changed.emit()
	return true


func _update_links(c: Vector2i) -> void:
	if not roads.has(c):
		return
	var l := Vector4(
		1.0 if roads.has(c + DIRS[0]) else 0.0,
		1.0 if roads.has(c + DIRS[1]) else 0.0,
		1.0 if roads.has(c + DIRS[2]) else 0.0,
		1.0 if roads.has(c + DIRS[3]) else 0.0)
	var mi: MeshInstance3D = roads[c]["mesh"]
	mi.set_instance_shader_parameter("links", l)


func road_height(c: Vector2i) -> float:
	if roads.has(c):
		return float(roads[c]["height"])
	return terrain.height_at(cell_center(c).x, cell_center(c).z)


# Démolit ce qui se trouve sur la case et rend la moitié du prix.
func demolish(c: Vector2i) -> float:
	if roads.has(c):
		var r: Dictionary = roads[c]
		r["mesh"].queue_free()
		if r["lamp"] != null:
			r["lamp"].queue_free()
		roads.erase(c)
		for d in DIRS:
			_update_links(c + d)
		var refund := float(defs["road"]["cost"]) * 0.5
		economy.money += refund
		refresh_status()
		changed.emit()
		return refund
	if occupied.has(c):
		var id: int = occupied[c]
		var b: Dictionary = buildings[id]
		for cell in footprint(b["cell"], b["size"]):
			occupied.erase(cell)
		b["node"].queue_free()
		buildings.erase(id)
		var refund2 := float(defs[b["type"]].get("cost", 0)) * 0.5
		economy.money += refund2
		refresh_status()
		changed.emit()
		return refund2
	return 0.0


func has_road_access(b: Dictionary) -> bool:
	for cell in footprint(b["cell"], b["size"]):
		for d in DIRS:
			if roads.has(cell + d):
				return true
	return false


# Calcule pour chaque bâtiment : actif (route et construit), bonus des parcs, pollution.
func refresh_status() -> void:
	var parks: Array = []
	var factories: Array = []
	for id in buildings:
		var b: Dictionary = buildings[id]
		b["active"] = bool(b["built"]) and has_road_access(b)
		if b["type"] == "park" and b["active"]:
			parks.append(b)
		if b["type"] == "factory" and b["active"]:
			factories.append(b)
	for id in buildings:
		var b: Dictionary = buildings[id]
		if float(defs[b["type"]].get("residents", 0)) <= 0.0:
			continue
		var pos: Vector2i = b["cell"]
		var bonus := 0.0
		for p in parks:
			var pdef: Dictionary = defs["park"]
			var pc: Vector2i = p["cell"]
			if (pc - pos).length() <= float(pdef["happiness_radius"]):
				bonus += float(pdef["happiness"])
		var pol := 0.0
		for f in factories:
			var fdef: Dictionary = defs["factory"]
			var fc: Vector2i = f["cell"] + Vector2i.ONE
			var dist := Vector2(fc - pos).length()
			var radius := float(fdef["pollution_radius"])
			if dist <= radius:
				pol += float(fdef["pollution"]) * (1.0 - dist / (radius + 1.0))
		b["happy_bonus"] = minf(bonus, 30.0)
		b["pollution"] = pol


func building_at(c: Vector2i) -> Dictionary:
	if occupied.has(c):
		return buildings[occupied[c]]
	return {}


func count(type: String) -> int:
	var n := 0
	for id in buildings:
		if buildings[id]["type"] == type:
			n += 1
	return n


# --- Temps --------------------------------------------------------------

func tick_hour(daylight: float) -> void:
	var list: Array = []
	for id in buildings:
		var b: Dictionary = buildings[id]
		list.append({"type": b["type"], "def": defs[b["type"]], "active": b["active"], "happy_bonus": b["happy_bonus"], "pollution": b["pollution"]})
	for c in roads:
		list.append({"type": "road", "def": defs["road"], "active": true, "happy_bonus": 0.0, "pollution": 0.0})
	economy.tick_hour(list, daylight)


func _process(delta: float) -> void:
	# Animations de chantier
	for k in range(constructing.size() - 1, -1, -1):
		var job: Dictionary = constructing[k]
		job["t"] = float(job["t"]) + delta
		var p := clampf(float(job["t"]) / float(job["duration"]), 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - p, 2.0)
		var alive := true
		for part in job["parts"]:
			if not is_instance_valid(part):
				alive = false
				break
		if not alive:
			constructing.remove_at(k)
			continue
		_set_progress(job["parts"], eased)
		if p >= 1.0:
			constructing.remove_at(k)
			var id: int = job["id"]
			if id > 0 and buildings.has(id):
				buildings[id]["built"] = true
				for s in buildings[id]["smoke"]:
					s.emitting = true
				refresh_status()
				changed.emit()

	# Éoliennes : vitesse selon le vent
	wind_time += delta
	economy.wind_factor = 0.75 + 0.35 * sin(wind_time * 0.05) + 0.15 * sin(wind_time * 0.23)
	for id in buildings:
		var b: Dictionary = buildings[id]
		if not b["built"]:
			continue
		for r in b["rotors"]:
			var rotor: Node3D = r
			rotor.rotation.z += delta * 1.6 * economy.wind_factor

	# Lampadaires la nuit
	var on := night > 0.2
	var i := factory.lamp_lights.size() - 1
	while i >= 0:
		if not is_instance_valid(factory.lamp_lights[i]):
			factory.lamp_lights.remove_at(i)
		else:
			var l: OmniLight3D = factory.lamp_lights[i]
			l.visible = on
			l.light_energy = night * 1.8
		i -= 1


func _set_progress(parts: Array, p: float) -> void:
	for part in parts:
		var mi: MeshInstance3D = part
		mi.set_instance_shader_parameter("progress", p)
