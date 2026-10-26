# Forêts : des milliers d'arbres dessinés en une fois (MultiMesh), sapins en altitude, feuillus en bas.
extends Node3D

const MeshBuilder := preload("res://scripts/world/mesh_builder.gd")
const Terrain := preload("res://scripts/world/terrain.gd")

var pines: MultiMeshInstance3D
var leafy: MultiMeshInstance3D
var material: ShaderMaterial
# Pour chaque case de la grille : liste de [type, index] des arbres qui s'y trouvent
var by_cell := {}
var _saved := {}


func build(terrain: Terrain, grid, world_seed: int, count: int) -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/foliage.gdshader")
	var pine_mesh := _pine_mesh()
	var leafy_mesh := _leafy_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 99
	var density := FastNoiseLite.new()
	density.seed = world_seed + 5
	density.frequency = 0.012

	var pine_list: Array[Transform3D] = []
	var pine_cols: Array[Color] = []
	var leafy_list: Array[Transform3D] = []
	var leafy_cols: Array[Color] = []
	var half: float = Terrain.SIZE * 0.5 - 10.0
	var tries := 0
	while pine_list.size() + leafy_list.size() < count and tries < count * 6:
		tries += 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		var h: float = terrain.height_at(x, z)
		if h < 1.5 or h > 78.0:
			continue
		var n: Vector3 = terrain.normal_at(x, z)
		if n.y < 0.78:
			continue
		var dens := density.get_noise_2d(x, z) * 0.5 + 0.5
		# Clairières sur le plateau pour laisser de la place à la ville
		var on_plateau := absf(h - Terrain.PLATEAU_HEIGHT) < 2.5 and Vector2(x, z).length() < 110.0
		var threshold := 0.62 if on_plateau else 0.38
		if dens < threshold + rng.randf() * 0.2:
			continue
		var s := rng.randf_range(0.7, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
		var tr := Transform3D(basis, Vector3(x, h - 0.2, z))
		var tint := Color.from_hsv(rng.randf_range(0.2, 0.32), rng.randf_range(0.5, 0.8), rng.randf_range(0.75, 1.1))
		var kind := 0 if (h > 14.0 or rng.randf() < 0.3) else 1
		var cell: Vector2i = grid.cell_of(Vector3(x, 0.0, z))
		var index := 0
		if kind == 0:
			index = pine_list.size()
			pine_list.append(tr)
			pine_cols.append(tint)
		else:
			index = leafy_list.size()
			leafy_list.append(tr)
			leafy_cols.append(tint)
		if not by_cell.has(cell):
			by_cell[cell] = []
		by_cell[cell].append([kind, index])

	pines = _make_instance(pine_mesh, pine_list, pine_cols)
	pines.name = "Sapins"
	leafy = _make_instance(leafy_mesh, leafy_list, leafy_cols)
	leafy.name = "Feuillus"
	add_child(pines)
	add_child(leafy)


func _make_instance(mesh: Mesh, list: Array[Transform3D], cols: Array[Color]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in range(list.size()):
		mm.set_instance_transform(i, list[i])
		mm.set_instance_color(i, cols[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = material
	return inst


# Retire (ou remet) les arbres d'une case quand on y construit.
func clear_cell(cell: Vector2i) -> void:
	if not by_cell.has(cell):
		return
	for entry in by_cell[cell]:
		var mm: MultiMesh = pines.multimesh if entry[0] == 0 else leafy.multimesh
		var key := "%d_%d" % [entry[0], entry[1]]
		if not _saved.has(key):
			_saved[key] = mm.get_instance_transform(entry[1])
		var t: Transform3D = _saved[key]
		mm.set_instance_transform(entry[1], Transform3D(Basis().scaled(Vector3.ONE * 0.0001), t.origin - Vector3(0, 50, 0)))


func _pine_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	var bark := Color(0.28, 0.18, 0.11)
	b.add_cone(Vector3.ZERO, 0.28, 0.18, 2.2, 7, bark, bark)
	var dark := Color(0.10, 0.22, 0.12)
	var light := Color(0.22, 0.40, 0.20)
	b.add_cone(Vector3(0, 1.6, 0), 2.4, 0.0, 3.4, 9, dark, light)
	b.add_cone(Vector3(0, 3.4, 0), 1.9, 0.0, 3.0, 9, dark, light)
	b.add_cone(Vector3(0, 5.0, 0), 1.35, 0.0, 2.6, 8, dark, light)
	b.add_cone(Vector3(0, 6.5, 0), 0.8, 0.0, 2.0, 7, dark, light)
	return b.commit()


func _leafy_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	var bark := Color(0.30, 0.22, 0.14)
	b.add_cone(Vector3.ZERO, 0.32, 0.2, 3.2, 7, bark, bark)
	var top := Color(0.36, 0.50, 0.18)
	var low := Color(0.13, 0.26, 0.08)
	b.add_blob(Vector3(0, 4.6, 0), Vector3(2.6, 2.2, 2.6), 6, 10, top, low, 1)
	b.add_blob(Vector3(1.3, 4.0, 0.6), Vector3(1.6, 1.4, 1.6), 5, 8, top, low, 2)
	b.add_blob(Vector3(-1.1, 4.2, -0.9), Vector3(1.7, 1.5, 1.7), 5, 8, top, low, 3)
	b.add_blob(Vector3(-0.2, 6.0, 0.3), Vector3(1.5, 1.3, 1.5), 5, 8, top, low, 4)
	return b.commit()
