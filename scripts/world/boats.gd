# Quelques voiliers qui croisent au large, pour donner de la vie à la mer.
extends Node3D

const MeshBuilder := preload("res://scripts/world/mesh_builder.gd")

var boats: Array = []


func build(count: int, world_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 7
	var b := MeshBuilder.new()
	var hull := Color(0.92, 0.92, 0.9)
	b.add_box(Vector3(0, 0.35, 0), Vector3(1.6, 0.7, 5.0), hull)
	b.add_box(Vector3(0, 0.85, 0.6), Vector3(1.0, 0.4, 1.6), Color(0.55, 0.4, 0.28))
	b.add_box(Vector3(0, 4.2, 0.0), Vector3(0.1, 7.0, 0.1), Color(0.7, 0.7, 0.7))
	var sail := Color(0.97, 0.96, 0.92)
	b.add_tri(Vector3(0, 7.6, 0.05), Vector3(0, 1.1, 0.05), Vector3(0, 1.1, 2.6), sail)
	b.add_tri(Vector3(0, 7.2, -0.05), Vector3(0, 1.1, -0.05), Vector3(0, 1.1, -2.3), sail.darkened(0.05))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.6
	var mesh := b.commit(mat)
	for i in range(count):
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		add_child(mi)
		boats.append({
			"node": mi,
			"center": Vector2(rng.randf_range(-180.0, 180.0), rng.randf_range(205.0, 265.0)),
			"radius": rng.randf_range(18.0, 45.0),
			"angle": rng.randf() * TAU,
			"speed": rng.randf_range(0.02, 0.05) * (1.0 if rng.randf() < 0.5 else -1.0),
		})


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for b in boats:
		b["angle"] = float(b["angle"]) + float(b["speed"]) * delta
		var a: float = b["angle"]
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		var node: Node3D = b["node"]
		node.position = Vector3(c.x + cos(a) * r, sin(t * 0.9 + a * 5.0) * 0.12 - 0.1, c.y + sin(a) * r)
		# Cap tangent au cercle, légère gîte
		var heading := Vector3(-sin(a), 0.0, cos(a)) * signf(float(b["speed"]))
		node.rotation = Vector3(sin(t * 0.7 + a) * 0.04, atan2(-heading.x, -heading.z), 0.12 + sin(t * 0.5 + a) * 0.05)
