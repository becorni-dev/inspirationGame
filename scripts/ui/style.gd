# Couleurs et thème de l'interface : panneaux sombres vitrés, liserés fins, accent ambre.
extends RefCounted

const BG := Color(0.04, 0.06, 0.08, 0.82)
const PANEL := Color(0.07, 0.09, 0.12, 0.92)
const LINE := Color(0.20, 0.27, 0.33, 1.0)
const FG := Color(0.90, 0.93, 0.95)
const MUTED := Color(0.55, 0.62, 0.68)
const ACCENT := Color(0.93, 0.66, 0.23)
const BLUEPRINT := Color(0.45, 0.75, 0.88)
const GOOD := Color(0.25, 0.84, 0.54)
const WARN := Color(0.95, 0.79, 0.30)
const BAD := Color(1.0, 0.37, 0.38)


static func box(bg: Color, border: Color, width := 1, radius := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Noto Sans", "DejaVu Sans"])
	t.default_font = font
	t.default_font_size = 15
	t.set_color("font_color", "Label", FG)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, LINE))
	t.set_stylebox("normal", "Button", box(Color(0.09, 0.12, 0.15, 0.95), LINE))
	t.set_stylebox("hover", "Button", box(Color(0.13, 0.17, 0.21, 0.98), BLUEPRINT))
	t.set_stylebox("pressed", "Button", box(Color(0.20, 0.15, 0.07, 1.0), ACCENT, 2))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", box(Color(0.06, 0.07, 0.09, 0.9), Color(0.14, 0.17, 0.2)))
	t.set_color("font_color", "Button", FG)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", MUTED)
	var tip := box(Color(0.05, 0.07, 0.09, 0.97), BLUEPRINT)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", FG)
	t.set_font_size("font_size", "TooltipLabel", 14)
	return t


static func mono() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "DejaVu Sans Mono", "monospace"])
	return f


# Nombre au format français : 12 345
static func num(v: float, decimals := 0) -> String:
	var neg := v < 0.0
	var a := absf(v)
	var whole := int(floor(a)) if decimals > 0 else int(round(a))
	var s := str(whole)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = " " + out
	if decimals > 0:
		var frac := int(round((a - floor(a)) * pow(10.0, decimals)))
		out += "," + str(frac).pad_zeros(decimals)
	return ("−" if neg else "") + out


static func label(text: String, size := 15, color := FG) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
