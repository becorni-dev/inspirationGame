# Circulation : des voitures roulent à droite sur les routes, phares allumés la nuit.
extends Node3D

const MeshBuilder := preload("res://scripts/world/mesh_builder.gd")
const City := preload("res://scripts/city/city.gd")

const PAINTS := ["#c0392b", "#ecf0f1", "#2c3e50", "#7f8c8d", "#2980b9", "#f1c40f", "#16a085", "#1b1b1b", "#8e44ad", "#d35400"]

var city: City
var cars: Array = []
var rng := RandomNumberGenerator.new()
var body_mesh: ArrayMesh
var glass_mesh: ArrayMesh
var head_mesh: ArrayMesh
var tail_mesh: ArrayMesh
var head_mat := StandardMaterial3D.new()
var tail_mat := StandardMaterial3D.new()
var glass_mat := StandardMaterial3D.new()
var paint_mats: Array = []
var speed_scale := 1.0


func setup(c: City) -> void:
	city = c
	rng.seed = 4242
	var b := MeshBuilder.new()
	b.add_box(Vector3(0, 0.45, 0), Vector3(1.7, 0.6, 4.0), Color.WHITE)
	b.add_box(Vector3(0, 0.95, -0.25), Vector3(1.5, 0.5, 2.0), Color.WHITE)
	body_mesh = b.commit()
	var g := MeshBuilder.new()
	g.add_box(Vector3(0, 0.97, -0.25), Vector3(1.53, 0.42, 2.03), Color.WHITE)
	glass_mesh = g.commit()
	var h := MeshBuilder.new()
	h.add_box(Vector3(0.55, 0.5, -2.01), Vector3(0.35, 0.16, 0.04), Color.WHITE)
	h.add_box(Vector3(-0.55, 0.5, -2.01), Vector3(0.35, 0.16, 0.04), Color.WHITE)
	head_mesh = h.commit()
	var t := MeshBuilder.new()
	t.add_box(Vector3(0.6, 0.55, 2.01), Vector3(0.3, 0.12, 0.04), Color.WHITE)
	t.add_box(Vector3(-0.6, 0.55, 2.01), Vector3(0.3, 0.12, 0.04), Color.WHITE)
	tail_mesh = t.commit()

	glass_mat.albedo_color = Color(0.03, 0.04, 0.05)
	glass_mat.metallic = 0.9
	glass_mat.roughness = 0.05
	head_mat.albedo_color = Color(1.0, 0.95, 0.8)
	head_mat.emission_enabled = true
	head_mat.emission = Color(1.0, 0.92, 0.75)
	tail_mat.albedo_color = Color(0.5, 0.02, 0.02)
	tail_mat.emission_enabled = true
	tail_mat.emission = Color(1.0, 0.05, 0.03)
	for p in PAINTS:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(p)
		m.metallic = 0.6
		m.roughness = 0.3
		m.clearcoat_enabled = true
		m.clearcoat = 1.0
		m.clearcoat_roughness = 0.1
		paint_mats.append(m)


func _spawn() -> void:
	var keys := city.roads.keys()
	if keys.is_empty():
		return
	var start: Vector2i = keys[rng.randi() % keys.size()]
	var car := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.material_override = paint_mats[rng.randi() % paint_mats.size()]
	car.add_child(body)
	var glass := MeshInstance3D.new()
	glass.mesh = glass_mesh
	glass.material_override = glass_mat
	car.add_child(glass)
	var head := MeshInstance3D.new()
	head.mesh = head_mesh
	head.material_override = head_mat
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	car.add_child(head)
	var tail := MeshInstance3D.new()
	tail.mesh = tail_mesh
	tail.material_override = tail_mat
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	car.add_child(tail)
	car.scale = Vector3.ONE * 0.62
	add_child(car)
	var dir: Vector2i = City.DIRS[rng.randi() % 4]
	var info := {"node": car, "from": start, "to": start, "dir": dir, "t": 1.0, "speed": rng.randf_range(5.0, 8.0), "life": rng.randf_range(60.0, 160.0)}
	car.position = _lane_point(start, dir)
	cars.append(info)


func _lane_point(c: Vector2i, dir: Vector2i) -> Vector3:
	var p := city.cell_center(c)
	var right := Vector3(-float(dir.y), 0.0, float(dir.x))
	p += right * 0.85
	p.y = city.road_height(c) + 0.05
	return p


func _next_dir(c: Vector2i, came: Vector2i) -> Vector2i:
	var options: Array[Vector2i] = []
	for d in City.DIRS:
		var dd: Vector2i = d
		if city.roads.has(c + dd) and dd != -came:
			options.append(dd)
	if options.is_empty():
		return -came if city.roads.has(c - came) else Vector2i.ZERO
	# Préférence pour aller tout droit
	if options.has(came) and rng.randf() < 0.55:
		return came
	return options[rng.randi() % options.size()]


func update_cars(delta: float, target: int, night: float) -> void:
	head_mat.emission_energy_multiplier = 0.2 + night * 6.0
	tail_mat.emission_energy_multiplier = 0.6 + night * 3.0
	if cars.size() < target and rng.randf() < 0.3:
		_spawn()
	for k in range(cars.size() - 1, -1, -1):
		var car: Dictionary = cars[k]
		var node: Node3D = car["node"]
		car["life"] = float(car["life"]) - delta
		var from: Vector2i = car["from"]
		var to: Vector2i = car["to"]
		var gone := not city.roads.has(to) or not city.roads.has(from)
		if gone or (float(car["life"]) < 0.0 and cars.size() > target) or cars.size() > target + 10:
			node.queue_free()
			cars.remove_at(k)
			continue
		car["t"] = float(car["t"]) + delta * float(car["speed"]) * speed_scale / City.CELL
		if float(car["t"]) >= 1.0:
			var dir: Vector2i = car["dir"]
			var nd := _next_dir(to, dir)
			if nd == Vector2i.ZERO:
				node.queue_free()
				cars.remove_at(k)
				continue
			car["from"] = to
			car["to"] = to + nd
			car["prev_dir"] = dir
			car["dir"] = nd
			car["t"] = 0.0
			from = to
			to = to + nd
		var d: Vector2i = car["dir"]
		var a := _lane_point(from, d)
		var b := _lane_point(to, d)
		var target_pos := a.lerp(b, float(car["t"]))
		node.position = node.position.lerp(target_pos, clampf(delta * 10.0, 0.0, 1.0))
		var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
		if flat.length() > 0.01:
			var yaw := atan2(-flat.x, -flat.z)
			node.rotation.y = lerp_angle(node.rotation.y, yaw, clampf(delta * 8.0, 0.0, 1.0))
		var slope := (b.y - a.y) / City.CELL
		node.rotation.x = lerpf(node.rotation.x, atan(slope), clampf(delta * 6.0, 0.0, 1.0))
