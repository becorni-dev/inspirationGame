# Interface du jeu : barre du haut (chiffres de la ville), barre d'outils, fiche d'un bâtiment,
# messages, aide, écran titre et mode photo.
extends CanvasLayer

const Style := preload("res://scripts/ui/style.gd")
const Economy := preload("res://scripts/city/economy.gd")

signal tool_selected(type: String)
signal speed_selected(index: int)
signal play_pressed
signal atelier_pressed
signal demolish_selected_pressed

var root: Control
var top_bar: PanelContainer
var toolbar: PanelContainer
var stats := {}               # nom -> Label
var tool_buttons := {}        # type -> Button
var speed_buttons: Array = []
var clock_label: Label
var toast_box: VBoxContainer
var inspector: PanelContainer
var inspector_body: VBoxContainer
var help_panel: PanelContainer
var title_screen: Control
var hint_label: Label
var letterbox: Array = []
var game_ui: Array = []
var defs := {}
var order: Array = []


func build(building_defs: Dictionary, building_order: Array) -> void:
	defs = building_defs
	order = building_order
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Style.make_theme()
	add_child(root)
	_build_top_bar()
	_build_toolbar()
	_build_inspector()
	_build_toasts()
	_build_help()
	_build_letterbox()
	_build_title()
	set_game_ui_visible(false)
	_no_focus(root)


# Les boutons ne gardent pas le focus : Espace et Tab restent des commandes du jeu.
func _no_focus(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).focus_mode = Control.FOCUS_NONE
	for c in node.get_children():
		_no_focus(c)


# --- Barre du haut ------------------------------------------------------

func _build_top_bar() -> void:
	top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 12
	top_bar.offset_right = -12
	top_bar.offset_top = 10
	top_bar.add_theme_stylebox_override("panel", Style.box(Style.BG, Style.LINE))
	root.add_child(top_bar)
	game_ui.append(top_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	top_bar.add_child(row)

	var logo := Style.label("NOUVELLE RIVE", 20, Style.ACCENT)
	row.add_child(logo)
	row.add_child(_sep())
	for key in [["money", "CRÉDITS"], ["pop", "HABITANTS"], ["jobs", "EMPLOIS"], ["power", "ÉLECTRICITÉ"], ["happy", "BONHEUR"]]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", -2)
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		var cap := Style.label(key[1], 11, Style.MUTED)
		var val := Style.label("—", 18)
		val.add_theme_font_override("font", Style.mono())
		box.add_child(cap)
		box.add_child(val)
		row.add_child(box)
		stats[key[0]] = val
		stats[key[0] + "_box"] = box

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	clock_label = Style.label("", 16)
	clock_label.add_theme_font_override("font", Style.mono())
	row.add_child(clock_label)
	var labels := ["II", "▶", "▶▶", "▶▶▶"]
	for i in range(4):
		var b := Button.new()
		b.text = labels[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(44, 0)
		b.tooltip_text = ["Pause (Espace)", "Vitesse normale", "Rapide", "Très rapide"][i]
		b.pressed.connect(func() -> void: speed_selected.emit(i))
		row.add_child(b)
		speed_buttons.append(b)
	row.add_child(_sep())
	var atelier := Button.new()
	atelier.text = "Atelier d'images (I)"
	atelier.pressed.connect(func() -> void: atelier_pressed.emit())
	row.add_child(atelier)
	var help := Button.new()
	help.text = "?"
	help.tooltip_text = "Aide et commandes (H)"
	help.custom_minimum_size = Vector2(36, 0)
	help.pressed.connect(func() -> void: toggle_help())
	row.add_child(help)


func _sep() -> Control:
	var s := ColorRect.new()
	s.color = Style.LINE
	s.custom_minimum_size = Vector2(1, 30)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


# --- Barre d'outils -----------------------------------------------------

func _build_toolbar() -> void:
	toolbar = PanelContainer.new()
	toolbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toolbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toolbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toolbar.offset_bottom = -14
	toolbar.add_theme_stylebox_override("panel", Style.box(Style.BG, Style.LINE))
	root.add_child(toolbar)
	game_ui.append(toolbar)
	var col := VBoxContainer.new()
	toolbar.add_child(col)
	hint_label = Style.label("Choisis un bâtiment, puis clique sur une case libre. Clic droit : tourner la vue.", 13, Style.MUTED)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	for type in order:
		var def: Dictionary = defs[type]
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(112, 64)
		b.text = "%s\n%s ¤" % [def["name"], Style.num(float(def["cost"]))]
		b.tooltip_text = _tooltip_for(type)
		b.expand_icon = false
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var t: String = type
		b.pressed.connect(func() -> void: tool_selected.emit(t))
		var key := Style.label(str(def.get("key", "")), 11, Style.ACCENT)
		key.position = Vector2(6, 3)
		b.add_child(key)
		row.add_child(b)
		tool_buttons[type] = b
	var demo := Button.new()
	demo.toggle_mode = true
	demo.custom_minimum_size = Vector2(100, 64)
	demo.text = "Démolir\nrend 50 %"
	demo.tooltip_text = "Démolir (B) : clique ou glisse sur des routes et des bâtiments.\nRend la moitié du prix."
	demo.pressed.connect(func() -> void: tool_selected.emit("demolish"))
	var dk := Style.label("B", 11, Style.BAD)
	dk.position = Vector2(6, 3)
	demo.add_child(dk)
	row.add_child(demo)
	tool_buttons["demolish"] = demo


func _tooltip_for(type: String) -> String:
	var d: Dictionary = defs[type]
	var lines: Array[String] = [str(d["name"]).to_upper(), str(d.get("desc", "")), ""]
	lines.append("Coût : %s ¤   Entretien : %s ¤/h" % [Style.num(float(d["cost"])), Style.num(float(d.get("upkeep", 0)), 1)])
	if d.has("residents"):
		lines.append("+%d habitants" % int(d["residents"]))
	if d.has("jobs"):
		lines.append("+%d emplois (%s ¤/h par employé)" % [int(d["jobs"]), Style.num(float(d.get("tax_per_worker", 0)), 1)])
	if d.has("power"):
		var p := float(d["power"])
		lines.append(("+%d MW produits" % int(p)) if p > 0 else ("%d MW consommés" % int(-p)))
	if d.has("happiness"):
		lines.append("+%d bonheur à %d cases autour" % [int(d["happiness"]), int(d["happiness_radius"])])
	if d.has("pollution"):
		lines.append("−%d bonheur des maisons à %d cases" % [int(d["pollution"]), int(d["pollution_radius"])])
	var s := Vector2i(int(d["size"][0]), int(d["size"][1]))
	lines.append("Taille : %d × %d cases" % [s.x, s.y])
	return "\n".join(PackedStringArray(lines))


func set_tool(type: String) -> void:
	for k in tool_buttons:
		var b: Button = tool_buttons[k]
		b.set_pressed_no_signal(k == type)
	if type == "":
		hint_label.text = "Choisis un bâtiment, puis clique sur une case libre. Clic droit : tourner la vue."
	elif type == "road":
		hint_label.text = "Clique et glisse pour tracer une route. Échap pour arrêter."
	elif type == "demolish":
		hint_label.text = "Clique ou glisse pour démolir. Échap pour arrêter."
	else:
		hint_label.text = "%s : clique sur une case libre. La façade se tourne vers la route." % defs[type]["name"]


func set_tool_icon(type: String, tex: Texture2D) -> void:
	if not tool_buttons.has(type):
		return
	var b: Button = tool_buttons[type]
	b.icon = tex
	b.expand_icon = tex != null
	b.add_theme_constant_override("icon_max_width", 40)


# --- Chiffres -----------------------------------------------------------

func refresh(eco: Economy, unlocked: Dictionary) -> void:
	var money: float = eco.money
	var net: float = eco.income - eco.upkeep
	stats["money"].text = "%s ¤  %s%s/h" % [Style.num(money), "+" if net >= 0 else "", Style.num(net)]
	stats["money"].add_theme_color_override("font_color", Style.FG if money >= 0 else Style.BAD)
	var bd: Dictionary = eco.breakdown
	stats["money_box"].tooltip_text = "Impôts des habitants : +%s ¤/h\nImpôts des entreprises : +%s ¤/h\nEntretien : −%s ¤/h" % [
		Style.num(float(bd.get("tax_res", 0.0)), 1), Style.num(float(bd.get("tax_work", 0.0)), 1), Style.num(float(bd.get("upkeep", 0.0)), 1)]
	stats["pop"].text = "%s / %s" % [Style.num(eco.population), Style.num(eco.capacity)]
	stats["pop_box"].tooltip_text = "Habitants / logements.\nLa ville se remplit vers %s habitants\n(selon le bonheur et l'électricité)." % Style.num(float(bd.get("target", 0.0)))
	stats["jobs"].text = "%s / %s" % [Style.num(eco.workers), Style.num(eco.jobs)]
	var unemp := float(bd.get("unemployment", 0.0))
	stats["jobs_box"].tooltip_text = "Actifs employés / emplois disponibles.\nChômage : %d %%" % int(round(unemp * 100.0))
	stats["jobs"].add_theme_color_override("font_color", Style.WARN if unemp > 0.15 else Style.FG)
	stats["power"].text = "%s / %s MW" % [Style.num(eco.power_prod), Style.num(eco.power_use)]
	stats["power"].add_theme_color_override("font_color", Style.BAD if eco.power_ratio < 0.999 else Style.GOOD)
	stats["power_box"].tooltip_text = "Production / consommation.\nÉoliennes : %s MW (vent × %s)\nSolaire : %s MW\nSi la production manque, tout tourne au ralenti." % [
		Style.num(float(bd.get("wind", 0.0)), 1), Style.num(eco.wind_factor, 2), Style.num(float(bd.get("solar", 0.0)), 1)]
	var happy: float = eco.happiness
	stats["happy"].text = "%d %%" % int(round(happy))
	stats["happy"].add_theme_color_override("font_color", Style.GOOD if happy >= 65 else (Style.WARN if happy >= 40 else Style.BAD))
	stats["happy_box"].tooltip_text = "Bonheur des quartiers (parcs, pollution) : %d %%\nChômage : −%d\nCoupures d'électricité : −%d" % [
		int(float(bd.get("base_happy", 60.0))), int(float(bd.get("unemployment_malus", 0.0))), int(float(bd.get("blackout_malus", 0.0)))]
	for type in order:
		var b: Button = tool_buttons[type]
		var locked := not bool(unlocked.get(type, true))
		b.disabled = locked
		b.modulate = Color(1, 1, 1, 0.55) if money < float(defs[type]["cost"]) else Color.WHITE


func set_clock(text: String, speed: int) -> void:
	clock_label.text = text
	for i in range(speed_buttons.size()):
		var b: Button = speed_buttons[i]
		b.set_pressed_no_signal(i == speed)


# --- Fiche d'un bâtiment ------------------------------------------------

func _build_inspector() -> void:
	inspector = PanelContainer.new()
	inspector.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	inspector.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	inspector.grow_vertical = Control.GROW_DIRECTION_BOTH
	inspector.offset_right = -14
	inspector.custom_minimum_size = Vector2(300, 0)
	inspector.visible = false
	root.add_child(inspector)
	inspector_body = VBoxContainer.new()
	inspector_body.add_theme_constant_override("separation", 6)
	inspector.add_child(inspector_body)


# lines : liste de [texte, couleur]
func show_inspector(title: String, lines: Array, can_demolish: bool) -> void:
	for c in inspector_body.get_children():
		c.queue_free()
	inspector_body.add_child(Style.label(title.to_upper(), 18, Style.ACCENT))
	var bar := ColorRect.new()
	bar.color = Style.LINE
	bar.custom_minimum_size = Vector2(0, 1)
	inspector_body.add_child(bar)
	for l in lines:
		var lab := Style.label(str(l[0]), 14, l[1])
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(280, 0)
		inspector_body.add_child(lab)
	if can_demolish:
		var b := Button.new()
		b.text = "Démolir (rend 50 %)"
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: demolish_selected_pressed.emit())
		inspector_body.add_child(b)
	inspector.visible = true


func hide_inspector() -> void:
	inspector.visible = false


# --- Messages -----------------------------------------------------------

func _build_toasts() -> void:
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.offset_top = 90
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(toast_box)


func toast(text: String, color: Color = Color(0.90, 0.93, 0.95)) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Style.box(Color(0.05, 0.07, 0.09, 0.9), color))
	var l := Style.label(text, 15, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	toast_box.add_child(p)
	while toast_box.get_child_count() > 4:
		toast_box.get_child(0).free()
	var tw := p.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


# --- Aide ---------------------------------------------------------------

func _build_help() -> void:
	help_panel = PanelContainer.new()
	help_panel.set_anchors_preset(Control.PRESET_CENTER)
	help_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	help_panel.visible = false
	root.add_child(help_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	help_panel.add_child(v)
	v.add_child(Style.label("COMMANDES", 20, Style.ACCENT))
	var lines := [
		["Z Q S D ou flèches", "déplacer la vue (Maj : plus vite)"],
		["A / E, clic droit glissé", "tourner la vue"],
		["Molette", "zoomer"],
		["R, 1 à 7", "choisir route ou bâtiment"],
		["B", "démolir"],
		["Clic gauche", "construire, ou ouvrir la fiche d'un bâtiment"],
		["Échap", "lâcher l'outil, fermer la fiche"],
		["Espace, Tab", "pause, changer de vitesse"],
		["N", "avancer de 3 heures (voir la nuit)"],
		["P", "mode photo"],
		["O", "effet maquette (flou de profondeur)"],
		["G", "qualité graphique (Ultra, Élevée, Moyenne)"],
		["I", "atelier d'images (prompts Gemini)"],
		["F11", "plein écran"],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	v.add_child(grid)
	for l in lines:
		var k := Style.label(l[0], 15, Style.BLUEPRINT)
		k.add_theme_font_override("font", Style.mono())
		grid.add_child(k)
		grid.add_child(Style.label(l[1], 15))
	v.add_child(Style.label("", 6))
	v.add_child(Style.label("Un bâtiment ne fonctionne que s'il touche une route.\nLes maisons ont besoin d'électricité, d'emplois et de parcs ; les usines polluent.", 14, Style.MUTED))


func toggle_help() -> void:
	help_panel.visible = not help_panel.visible


# --- Mode photo ---------------------------------------------------------

func _build_letterbox() -> void:
	for top in [true, false]:
		var r := ColorRect.new()
		r.color = Color.BLACK
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			r.offset_bottom = 90
		else:
			r.offset_top = -90
		r.visible = false
		root.add_child(r)
		letterbox.append(r)


func set_photo_mode(on: bool) -> void:
	for r in letterbox:
		r.visible = on
	set_game_ui_visible(not on)
	if on:
		inspector.visible = false
		help_panel.visible = false


func set_game_ui_visible(on: bool) -> void:
	for c in game_ui:
		c.visible = on
	toast_box.visible = on


# --- Écran titre --------------------------------------------------------

func _build_title() -> void:
	title_screen = Control.new()
	title_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_screen)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 620
	shade.color = Color(0.02, 0.03, 0.05, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_screen.add_child(shade)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.offset_left = 90
	v.add_theme_constant_override("separation", 10)
	title_screen.add_child(v)
	var small := Style.label("PROTOTYPE · MOTEUR GODOT 4", 14, Style.BLUEPRINT)
	small.add_theme_font_override("font", Style.mono())
	v.add_child(small)
	var t := Style.label("NOUVELLE RIVE", 72, Color.WHITE)
	t.add_theme_constant_override("outline_size", 0)
	v.add_child(t)
	v.add_child(Style.label("Bâtis une ville sur une île : routes, quartiers, énergie,\nemplois et bonheur. Le jour se lève, la nuit s'allume.", 18, Style.FG))
	v.add_child(Style.label("", 10))
	var play := Button.new()
	play.text = "    Jouer    "
	play.add_theme_font_size_override("font_size", 22)
	play.custom_minimum_size = Vector2(260, 54)
	play.add_theme_stylebox_override("normal", Style.box(Color(0.25, 0.17, 0.05, 0.95), Style.ACCENT, 2))
	play.pressed.connect(func() -> void: play_pressed.emit())
	v.add_child(play)
	var atelier := Button.new()
	atelier.text = "Atelier d'images"
	atelier.custom_minimum_size = Vector2(260, 42)
	atelier.pressed.connect(func() -> void: atelier_pressed.emit())
	v.add_child(atelier)
	var quit := Button.new()
	quit.text = "Quitter"
	quit.custom_minimum_size = Vector2(260, 42)
	quit.pressed.connect(func() -> void: get_tree().quit())
	v.add_child(quit)
	v.add_child(Style.label("", 10))
	v.add_child(Style.label("G : qualité graphique   ·   F11 : plein écran", 13, Style.MUTED))


func hide_title() -> void:
	var tw := title_screen.create_tween()
	tw.tween_property(title_screen, "modulate:a", 0.0, 0.5)
	tw.tween_callback(title_screen.hide)
	set_game_ui_visible(true)
