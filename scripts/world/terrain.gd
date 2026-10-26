# Le relief de l'île : montagnes au nord, plateau constructible au centre, plage et mer au sud.
extends Node3D

const SIZE := 640.0          # côté du terrain en mètres
const STEP := 2.0            # distance entre deux sommets
const WATER_LEVEL := 0.0
const PLATEAU_HEIGHT := 3.5

var resolution := 0          # sommets par côté
var heights := PackedFloat32Array()
var material: ShaderMaterial
var mesh_instance: MeshInstance3D

var _base := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _detail := FastNoiseLite.new()


func build(world_seed: int) -> void:
	_base.seed = world_seed
	_base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_base.frequency = 0.0035
	_base.fractal_octaves = 5
	_ridge.seed = world_seed + 11
	_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge.frequency = 0.006
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge.fractal_octaves = 5
	_detail.seed = world_seed + 23
	_detail.frequency = 0.05
	_detail.fractal_octaves = 3

	resolution = int(SIZE / STEP) + 1
	heights.resize(resolution * resolution)
	var half := SIZE * 0.5
	for j in range(resolution):
		for i in range(resolution):
			var x := -half + float(i) * STEP
			var z := -half + float(j) * STEP
			heights[j * resolution + i] = _shape(x, z)
	_build_mesh()


# Forme générale de l'île, en mètres au-dessus de la mer.
func _shape(x: float, z: float) -> float:
	var half := SIZE * 0.5
	var u := x / half
	var v := z / half
	var d := sqrt(u * u + v * v)
	var n := _base.get_noise_2d(x, z)
	var h := 5.0 + n * 9.0

	# Chaîne de montagnes au nord et sur les côtés
	var north := clampf((-v + 0.15) * 1.6, 0.0, 1.0)
	var ring := smoothstep(0.32, 0.85, d)
	var ridge := _ridge.get_noise_2d(x, z) * 0.5 + 0.5
	var mountain := maxf(north * smoothstep(0.2, 0.6, -v + 0.25), ring * 0.55)
	h += pow(ridge, 1.6) * 95.0 * mountain

	# Mer au sud et tout autour au loin
	var south := smoothstep(0.18, 0.55, v + n * 0.08)
	h = lerpf(h, -14.0 + n * 4.0, south)
	h = lerpf(h, -22.0, smoothstep(0.85, 1.05, d))

	# Plateau constructible au centre
	var pd := Vector2(u * 1.05, (v + 0.02) * 1.25).length()
	var plateau := 1.0 - smoothstep(0.26, 0.46, pd + n * 0.05)
	var gentle := PLATEAU_HEIGHT + _detail.get_noise_2d(x, z) * 0.35 + n * 0.8
	h = lerpf(h, gentle, plateau)
	return h


func _build_mesh() -> void:
	var half := SIZE * 0.5
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.resize(resolution * resolution)
	normals.resize(resolution * resolution)
	for j in range(resolution):
		for i in range(resolution):
			var idx := j * resolution + i
			verts[idx] = Vector3(-half + float(i) * STEP, heights[idx], -half + float(j) * STEP)
			var hl := _h(i - 1, j)
			var hr := _h(i + 1, j)
			var hd := _h(i, j - 1)
			var hu := _h(i, j + 1)
			normals[idx] = Vector3(hl - hr, 2.0 * STEP, hd - hu).normalized()
	for j in range(resolution - 1):
		for i in range(resolution - 1):
			var a := j * resolution + i
			var b := a + 1
			var c := a + resolution
			var d := c + 1
			for k in [a, b, d, a, d, c]:
				indices.append(k)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/terrain.gdshader")
	mesh.surface_set_material(0, material)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.name = "Sol"
	add_child(mesh_instance)


func _h(i: int, j: int) -> float:
	i = clampi(i, 0, resolution - 1)
	j = clampi(j, 0, resolution - 1)
	return heights[j * resolution + i]


# Hauteur du sol en un point (interpolation entre les sommets).
func height_at(x: float, z: float) -> float:
	var half := SIZE * 0.5
	var fx := (x + half) / STEP
	var fz := (z + half) / STEP
	var i := int(floor(fx))
	var j := int(floor(fz))
	var tx := fx - float(i)
	var tz := fz - float(j)
	var h00 := _h(i, j)
	var h10 := _h(i + 1, j)
	var h01 := _h(i, j + 1)
	var h11 := _h(i + 1, j + 1)
	# Même découpe en triangles que le maillage (diagonale a-d)
	if tx > tz:
		return h00 + (h10 - h00) * tx + (h11 - h10) * tz
	return h00 + (h11 - h01) * tx + (h01 - h00) * tz


func normal_at(x: float, z: float) -> Vector3:
	var e := 1.0
	var hl := height_at(x - e, z)
	var hr := height_at(x + e, z)
	var hd := height_at(x, z - e)
	var hu := height_at(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()


# Point où un rayon de la caméra touche le sol (null s'il le rate).
func raycast(origin: Vector3, dir: Vector3) -> Variant:
	var t := 0.0
	var step := 2.0
	var prev := origin
	for k in range(900):
		t += step
		var p := origin + dir * t
		if p.y < height_at(p.x, p.z):
			# Affinage par dichotomie
			var lo := prev
			var hi := p
			for r in range(12):
				var m := (lo + hi) * 0.5
				if m.y < height_at(m.x, m.z):
					hi = m
				else:
					lo = m
			return (lo + hi) * 0.5
		prev = p
		if p.y < -60.0:
			break
	return null
