# Atelier d'images : chaque image du jeu a un prompt Gemini.
# Copier le prompt, générer l'image dans Gemini, la copier, puis « Coller l'image » ici :
# elle est recadrée, réduite, rendue raccordable si c'est une texture, enregistrée et appliquée tout de suite.
extends CanvasLayer

const Style := preload("res://scripts/ui/style.gd")

signal asset_changed(id: String)

var entries: Array = []
var textures := {}            # id -> Texture2D
var panel: PanelContainer
var list_box: VBoxContainer
var status_label: Label
var file_dialog: FileDialog
var _file_target := ""


func setup() -> void:
	layer = 20
	var file := FileAccess.open("res://atelier/manifest.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	entries = data["entries"]
	for e in entries:
		_load_entry(str(e["id"]))
	_build_ui()
	panel.visible = false


func texture(id: String) -> Texture2D:
	return textures.get(id, null)


# Les images enregistrées par l'atelier : d'abord dans le dossier du projet, sinon dans le dossier utilisateur.
func _paths(id: String) -> Array[String]:
	return [ProjectSettings.globalize_path("res://atelier/images/%s.png" % id), ProjectSettings.globalize_path("user://atelier/%s.png" % id)]


func _save_path(id: String) -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://atelier/images/%s.png" % id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://atelier"))
	return ProjectSettings.globalize_path("user://atelier/%s.png" % id)


func _load_entry(id: String) -> void:
	textures.erase(id)
	for path in _paths(id):
		if FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img != null and not img.is_empty():
				img.generate_mipmaps()
				textures[id] = ImageTexture.create_from_image(img)
				return


func is_open() -> bool:
	return panel.visible


func toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		_refresh_list()


# --- Traitement de l'image ----------------------------------------------

func _process_image(e: Dictionary, img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var target := int(e["size"])
	# Recadrage carré au centre
	var side := mini(img.get_width(), img.get_height())
	var ox := (img.get_width() - side) / 2
	var oy := (img.get_height() - side) / 2
	var sq := img.get_region(Rect2i(ox, oy, side, side))
	sq.resize(target, target, Image.INTERPOLATE_LANCZOS)
	if bool(e.get("tileable", false)):
		sq = _make_seamless(sq)
	return sq


# Fondu avec une copie décalée d'une demi-image : les bords se raccordent.
func _make_seamless(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var band := 0.22
	for y in range(h):
		var fy := float(y) / float(h - 1)
		var ey := minf(fy, 1.0 - fy)
		for x in range(w):
			var fx := float(x) / float(w - 1)
			var ex := minf(fx, 1.0 - fx)
			var edge := minf(ex, ey)
			var k := 1.0 - smoothstep(0.0, band, edge)
			var a := img.get_pixel(x, y)
			var b := img.get_pixel((x + w / 2) % w, (y + h / 2) % h)
			out.set_pixel(x, y, a.lerp(b, k))
	return out


func import_image(id: String, img: Image) -> void:
	var e := _entry(id)
	if e.is_empty() or img == null or img.is_empty():
		_status("Pas d'image à importer.", Style.BAD)
		return
	var processed := _process_image(e, img)
	var path := _save_path(id)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := processed.save_png(path)
	if err != OK:
		_status("Impossible d'enregistrer %s (erreur %d)." % [path, err], Style.BAD)
		return
	_load_entry(id)
	_status("« %s » enregistrée et appliquée (%s)." % [e["name"], path.get_file()], Style.GOOD)
	asset_changed.emit(id)
	_refresh_list()


func remove_image(id: String) -> void:
	for path in _paths(id):
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	textures.erase(id)
	_status("Image retirée : le dessin procédural revient.", Style.WARN)
	asset_changed.emit(id)
	_refresh_list()


func paste_from_clipboard(id: String) -> void:
	if not DisplayServer.has_method("clipboard_get_image"):
		_status("Cette version de Godot ne sait pas lire une image dans le presse-papiers : utilise « Choisir un fichier ».", Style.WARN)
		return
	var img: Image = DisplayServer.call("clipboard_get_image")
	if img == null or img.is_empty():
		_status("Le presse-papiers ne contient pas d'image. Dans Gemini : clic droit sur l'image, « Copier l'image ».", Style.WARN)
		return
	_status("Traitement de l'image…", Style.BLUEPRINT)
	import_image(id, img)


func _entry(id: String) -> Dictionary:
	for e in entries:
		if e["id"] == id:
			return e
	return {}


# --- Interface ----------------------------------------------------------

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Style.make_theme()
	add_child(root)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 120
	panel.offset_right = -120
	panel.offset_top = 70
	panel.offset_bottom = -70
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(Style.label("ATELIER D'IMAGES", 22, Style.ACCENT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var close := Button.new()
	close.text = "Fermer (I)"
	close.pressed.connect(toggle)
	head.add_child(close)
	v.add_child(Style.label("1. Copier le prompt   2. Le coller dans Gemini (Nano Banana) et générer   3. Copier l'image dans Gemini   4. « Coller l'image » ici.\nLes textures sont recadrées, réduites et rendues raccordables. Elles sont rangées dans atelier/images/ et apparaissent aussitôt dans le jeu.", 14, Style.MUTED))
	status_label = Style.label("", 14, Style.BLUEPRINT)
	v.add_child(status_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 10)
	scroll.add_child(list_box)

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	file_dialog.use_native_dialog = true
	file_dialog.title = "Choisir une image"
	file_dialog.file_selected.connect(_on_file_selected)
	root.add_child(file_dialog)


func _on_file_selected(path: String) -> void:
	var img := Image.load_from_file(path)
	import_image(_file_target, img)


func _status(text: String, color: Color) -> void:
	if status_label != null:
		status_label.text = text
		status_label.add_theme_color_override("font_color", color)


func _refresh_list() -> void:
	for c in list_box.get_children():
		c.queue_free()
	var done := 0
	for e in entries:
		if textures.has(str(e["id"])):
			done += 1
	list_box.add_child(Style.label("%d image(s) sur %d" % [done, entries.size()], 14, Style.FG))
	for e in entries:
		list_box.add_child(_row(e))


func _row(e: Dictionary) -> Control:
	var id := str(e["id"])
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.box(Color(0.06, 0.08, 0.1, 0.95), Style.LINE))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	card.add_child(h)
	var tex := texture(id)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(110, 110)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(tr)
	else:
		var ph := PanelContainer.new()
		ph.custom_minimum_size = Vector2(110, 110)
		ph.add_theme_stylebox_override("panel", Style.box(Color(0.03, 0.04, 0.05), Style.BLUEPRINT.darkened(0.4)))
		var l := Style.label("à créer", 13, Style.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ph.add_child(l)
		h.add_child(ph)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var title := HBoxContainer.new()
	v.add_child(title)
	title.add_child(Style.label(str(e["name"]), 17, Color.WHITE))
	var state := "✔ en place" if tex != null else "dessin procédural"
	title.add_child(Style.label("   %s · %d × %d px · %s" % [id, int(e["size"]), int(e["size"]), state], 13, Style.GOOD if tex != null else Style.MUTED))
	v.add_child(Style.label(str(e["usage"]), 13, Style.MUTED))
	var prompt := TextEdit.new()
	prompt.text = str(e["prompt"])
	prompt.editable = false
	prompt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	prompt.custom_minimum_size = Vector2(0, 66)
	prompt.add_theme_font_size_override("font_size", 13)
	v.add_child(prompt)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	v.add_child(buttons)
	var copy := Button.new()
	copy.text = "Copier le prompt"
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(str(e["prompt"]))
		_status("Prompt copié : colle-le dans Gemini.", Style.GOOD))
	buttons.add_child(copy)
	var paste := Button.new()
	paste.text = "Coller l'image"
	paste.pressed.connect(func() -> void: paste_from_clipboard(id))
	buttons.add_child(paste)
	var pick := Button.new()
	pick.text = "Choisir un fichier…"
	pick.pressed.connect(func() -> void:
		_file_target = id
		file_dialog.popup_centered_ratio(0.6))
	buttons.add_child(pick)
	if tex != null:
		var rm := Button.new()
		rm.text = "Retirer"
		rm.pressed.connect(func() -> void: remove_image(id))
		buttons.add_child(rm)
	return card
