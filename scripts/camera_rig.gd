# Caméra de jeu de gestion : déplacement ZQSD ou flèches, rotation A/E ou clic droit, molette pour zoomer.
# Les touches sont lues par position physique : ZQSD sur un clavier AZERTY, WASD sur un QWERTY.
extends Node3D

const Terrain := preload("res://scripts/world/terrain.gd")

var camera: Camera3D
var attributes: CameraAttributesPractical
var terrain: Terrain

var target := Vector3(0, 4, 10)
var yaw := deg_to_rad(-35.0)
var pitch := deg_to_rad(-38.0)
var distance := 110.0
var _yaw := yaw
var _pitch := pitch
var _distance := distance
var _target := target
var rotating := false
var tilt_shift := true
var auto_orbit := false      # écran titre et mode photo
var bounds := 230.0


func setup(t: Terrain) -> void:
	terrain = t
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.near = 0.3
	camera.far = 4000.0
	attributes = CameraAttributesPractical.new()
	attributes.dof_blur_amount = 0.08
	camera.attributes = attributes
	add_child(camera)
	camera.make_current()
	_apply(1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			distance = clampf(distance * 0.88, 12.0, 420.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			distance = clampf(distance * 1.13, 12.0, 420.0)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			rotating = mb.pressed
	elif event is InputEventMouseMotion and rotating:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * 0.005
		pitch = clampf(pitch - mm.relative.y * 0.004, deg_to_rad(-85.0), deg_to_rad(-8.0))


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		yaw += delta * 1.4
	if Input.is_physical_key_pressed(KEY_E):
		yaw -= delta * 1.4
	if auto_orbit:
		yaw += delta * 0.05
	if move != Vector2.ZERO:
		var speed := distance * 0.9 * (2.5 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		target += (right * move.x + fwd * move.y).normalized() * speed * delta
	target.x = clampf(target.x, -bounds, bounds)
	target.z = clampf(target.z, -bounds, bounds)
	if terrain != null:
		target.y = lerpf(target.y, maxf(terrain.height_at(target.x, target.z), 0.0), clampf(delta * 3.0, 0.0, 1.0))
	_apply(clampf(delta * 8.0, 0.0, 1.0))


func _apply(k: float) -> void:
	_yaw = lerp_angle(_yaw, yaw, k)
	_pitch = lerpf(_pitch, pitch, k)
	_distance = lerpf(_distance, distance, k)
	_target = _target.lerp(target, k)
	var b := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)
	var pos := _target + b * Vector3(0, 0, _distance)
	# On ne passe jamais sous le relief
	if terrain != null:
		var ground := maxf(terrain.height_at(pos.x, pos.z), 0.0) + 3.0
		pos.y = maxf(pos.y, ground)
	camera.global_transform = Transform3D(Basis(), pos).looking_at(_target, Vector3.UP)
	# Effet maquette (tilt-shift) : flou devant et derrière le point visé
	attributes.dof_blur_far_enabled = tilt_shift
	attributes.dof_blur_near_enabled = tilt_shift and _distance < 200.0
	attributes.dof_blur_far_distance = _distance * 1.35
	attributes.dof_blur_far_transition = _distance * 1.2
	attributes.dof_blur_near_distance = _distance * 0.55
	attributes.dof_blur_near_transition = _distance * 0.4


func ray_from_mouse(screen_pos: Vector2) -> Array:
	return [camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos)]


func focus_on(p: Vector3, dist: float) -> void:
	target = p
	distance = dist
