# Petit outil pour fabriquer des maillages par le code (arbres, voitures, terrain).
extends RefCounted

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()


func add_tri(a: Vector3, b: Vector3, c: Vector3, col: Color, smooth_normals: Array = []) -> void:
	verts.append(a)
	verts.append(b)
	verts.append(c)
	if smooth_normals.size() == 3:
		normals.append(smooth_normals[0])
		normals.append(smooth_normals[1])
		normals.append(smooth_normals[2])
	else:
		var n := (b - a).cross(c - a).normalized()
		normals.append(n)
		normals.append(n)
		normals.append(n)
	colors.append(col)
	colors.append(col)
	colors.append(col)


# Face orientée vers l'extérieur : on vérifie que la normale pointe dans le sens voulu.
func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, outward: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot(outward) < 0.0:
		n = -n
	for v in [a, b, c, a, c, d]:
		verts.append(v)
		normals.append(n)
		colors.append(col)


func add_box(center: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var c := center
	var p := [
		c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z),
		c + Vector3(h.x, -h.y, h.z), c + Vector3(-h.x, -h.y, h.z),
		c + Vector3(-h.x, h.y, -h.z), c + Vector3(h.x, h.y, -h.z),
		c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z),
	]
	add_quad(p[4], p[5], p[6], p[7], col, Vector3.UP)
	add_quad(p[0], p[1], p[2], p[3], col, Vector3.DOWN)
	add_quad(p[3], p[2], p[6], p[7], col, Vector3.BACK)
	add_quad(p[0], p[1], p[5], p[4], col, Vector3.FORWARD)
	add_quad(p[1], p[2], p[6], p[5], col, Vector3.RIGHT)
	add_quad(p[0], p[3], p[7], p[4], col, Vector3.LEFT)


# Cône ou cylindre (rayon du bas, rayon du haut), normales lissées.
func add_cone(base: Vector3, r_bottom: float, r_top: float, h: float, segments: int, col: Color, col_top: Color) -> void:
	var slope := (r_bottom - r_top) / maxf(h, 0.001)
	for i in range(segments):
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var n0 := (d0 + Vector3.UP * slope).normalized()
		var n1 := (d1 + Vector3.UP * slope).normalized()
		var b0 := base + d0 * r_bottom
		var b1 := base + d1 * r_bottom
		var t0 := base + Vector3.UP * h + d0 * r_top
		var t1 := base + Vector3.UP * h + d1 * r_top
		_add_colored_tri(b0, b1, t1, [n0, n1, n1], [col, col, col_top])
		if r_top > 0.001:
			_add_colored_tri(b0, t1, t0, [n0, n1, n0], [col, col_top, col_top])
			_add_colored_tri(base + Vector3.UP * h, t0, t1, [Vector3.UP, Vector3.UP, Vector3.UP], [col_top, col_top, col_top])
		_add_colored_tri(base, b1, b0, [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN], [col, col, col])


# Sphère bosselée (feuillage) : rayon perturbé par une graine.
func add_blob(center: Vector3, radius: Vector3, rings: int, segments: int, col: Color, col_dark: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bumps: Array[float] = []
	for i in range((rings + 1) * (segments + 1)):
		bumps.append(rng.randf_range(0.82, 1.12))
	var pts: Array[Vector3] = []
	var nrm: Array[Vector3] = []
	for r in range(rings + 1):
		var phi := PI * float(r) / float(rings)
		for s in range(segments + 1):
			var theta := TAU * float(s % segments) / float(segments)
			var d := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var k := bumps[r * (segments + 1) + (s % segments)]
			if r == 0 or r == rings:
				k = 1.0
			pts.append(center + d * radius * k)
			nrm.append(d)
	for r in range(rings):
		for s in range(segments):
			var i0 := r * (segments + 1) + s
			var i1 := i0 + 1
			var i2 := i0 + segments + 1
			var i3 := i2 + 1
			var c_top := col.lerp(col_dark, float(r) / float(rings))
			var c_bot := col.lerp(col_dark, float(r + 1) / float(rings))
			_add_colored_tri(pts[i0], pts[i2], pts[i3], [nrm[i0], nrm[i2], nrm[i3]], [c_top, c_bot, c_bot])
			_add_colored_tri(pts[i0], pts[i3], pts[i1], [nrm[i0], nrm[i3], nrm[i1]], [c_top, c_bot, c_top])


func _add_colored_tri(a: Vector3, b: Vector3, c: Vector3, n: Array, cols: Array) -> void:
	verts.append(a)
	verts.append(b)
	verts.append(c)
	normals.append(n[0])
	normals.append(n[1])
	normals.append(n[2])
	colors.append(cols[0])
	colors.append(cols[1])
	colors.append(cols[2])


func commit(material: Material = null) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material != null:
		mesh.surface_set_material(0, material)
	return mesh
