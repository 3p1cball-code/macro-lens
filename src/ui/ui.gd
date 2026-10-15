extends RefCounted
class_name UI

## Zentrales Design-System (MalochBot-Look): flach, helle/dunkle Palette,
## eine Akzentfarbe (Amber), eckige Buttons, flache Karten mit duennen Linien,
## Uppercase-Mikrolabels. Alle Fabriken liefern fertig gestylte Controls.

static var dark: bool = true

const DARK := {
	"bg": "#0F1113", "surface": "#17191C", "surface2": "#1F2227",
	"line": "#2A2E34", "text": "#ECEEF0", "muted": "#8B9199", "faint": "#5B6068",
	"accent": "#F0A020", "on_accent": "#141514", "accent_ink": "#F0A020",
	"good": "#4CC38A", "bad": "#E5484D", "warn": "#E8B931",
	"protein": "#4C8DF6", "carbs": "#F0A020", "fat": "#E5684D",
}

const LIGHT := {
	"bg": "#F3F4F5", "surface": "#FFFFFF", "surface2": "#EDEFF1",
	"line": "#E0E2E5", "text": "#16181B", "muted": "#666C74", "faint": "#9AA0A6",
	"accent": "#F0A020", "on_accent": "#141514", "accent_ink": "#9C5C00",
	"good": "#1E9E6A", "bad": "#D03A3F", "warn": "#B78400",
	"protein": "#2F6FD0", "carbs": "#C07A00", "fat": "#C24E36",
}

# Schriftgroessen (Basis-Viewport 1080 breit)
const FS_MICRO := 26
const FS_SMALL := 30
const FS_BODY := 36
const FS_TITLE := 52
const FS_BIG := 116
const FS_HUGE := 150

static var _C := {}
static var font_regular: FontFile
static var font_semibold: FontFile
static var font_bold: FontFile

static func _static_init() -> void:
	_refresh()
	_load_fonts()

static func _refresh() -> void:
	var src: Dictionary = DARK if dark else LIGHT
	_C = {}
	for k in src:
		_C[k] = Color(src[k])

static func _load_fonts() -> void:
	if font_regular != null:
		return
	font_regular = load("res://assets/fonts/OpenSans-Regular.ttf")
	font_semibold = load("res://assets/fonts/OpenSans-SemiBold.ttf")
	font_bold = load("res://assets/fonts/OpenSans-Bold.ttf")

static func set_dark(v: bool) -> void:
	dark = v
	_refresh()

static func c(key: String) -> Color:
	if _C.is_empty():
		_refresh()
	return _C.get(key, Color.MAGENTA)

static func font(weight: int = 0) -> FontFile:
	match weight:
		1: return font_semibold
		2: return font_bold
		_: return font_regular

# --- Text -------------------------------------------------------------------

static func label(text: String, size: int = FS_BODY, color_key: String = "text", weight: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c(color_key))
	return l

static func micro(text: String, color_key: String = "muted") -> Label:
	var l := label(text.to_upper(), FS_MICRO, color_key, 1)
	l.add_theme_constant_override("line_spacing", 4)
	return l

## Farbskala 0..1: gruen (0) -> amber (0.5) -> rot (1).
static func scale_color(t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	var green := Color("#4CC38A")
	var amber := Color("#E8B931")
	var red := Color("#E5484D")
	if t < 0.5:
		return green.lerp(amber, t / 0.5)
	return amber.lerp(red, (t - 0.5) / 0.5)

## Kuerzt Text auf maxlen Zeichen (mit Ellipse) - verhindert Buchstabenumbrueche.
static func short(text: String, maxlen: int) -> String:
	var t := text.strip_edges()
	if t.length() <= maxlen:
		return t
	return t.substr(0, maxi(1, maxlen - 1)).strip_edges() + "…"

## Grosse Zahl in freier Farbe (fuer die Farbskalen).
static func big_number_colored(text: String, color: Color, size: int = FS_BIG) -> Label:
	var l := label(text, size, "text", 2)
	l.add_theme_color_override("font_color", color)
	return l

static func big_number(text: String, color_key: String = "text", size: int = FS_BIG) -> Label:
	var l := label(text, size, color_key, 2)
	return l

# --- Container --------------------------------------------------------------

static func vbox(sep: int = 0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func spacer(min_size: float = 0.0) -> Control:
	var ctl := Control.new()
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ctl.custom_minimum_size = Vector2(min_size, min_size)
	return ctl

static func hline(color_key: String = "line", thickness: int = 1) -> ColorRect:
	var r := ColorRect.new()
	r.color = c(color_key)
	r.custom_minimum_size = Vector2(0, thickness)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r

static func vline(color_key: String = "line", thickness: int = 1) -> ColorRect:
	var r := ColorRect.new()
	r.color = c(color_key)
	r.custom_minimum_size = Vector2(thickness, 0)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return r

# --- Styleboxen -------------------------------------------------------------

static func card_style(pad: int = 26, radius: int = 4, color_key: String = "surface") -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c(color_key)
	sb.set_border_width_all(1)
	sb.border_color = c("line")
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb

static func flat_style(color_key: String, radius: int = 4, pad: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c(color_key)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb

static func card(pad: int = 26) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_style(pad))
	return p

# --- Buttons ----------------------------------------------------------------

static func button(text: String, kind: String = "primary", font_size: int = FS_BODY) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font(1))
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(0, 92)
	if kind == "primary":
		b.add_theme_color_override("font_color", c("on_accent"))
		b.add_theme_color_override("font_hover_color", c("on_accent"))
		b.add_theme_color_override("font_pressed_color", c("on_accent"))
		b.add_theme_stylebox_override("normal", _btn(c("accent"), 4))
		b.add_theme_stylebox_override("hover", _btn(c("accent").lightened(0.10), 4))
		b.add_theme_stylebox_override("pressed", _btn(c("accent").darkened(0.12), 4))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	elif kind == "ghost":
		b.add_theme_color_override("font_color", c("text"))
		b.add_theme_color_override("font_hover_color", c("text"))
		b.add_theme_color_override("font_pressed_color", c("muted"))
		b.add_theme_stylebox_override("normal", _btn_outline())
		b.add_theme_stylebox_override("hover", _btn(c("surface2"), 4, true))
		b.add_theme_stylebox_override("pressed", _btn(c("surface2").darkened(0.05), 4, true))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	else: # accent-ghost / quiet
		b.add_theme_color_override("font_color", c("accent_ink"))
		b.add_theme_color_override("font_hover_color", c("accent_ink"))
		b.add_theme_stylebox_override("normal", _btn_outline("accent"))
		b.add_theme_stylebox_override("hover", _btn(c("surface2"), 4, true))
		b.add_theme_stylebox_override("pressed", _btn(c("surface2"), 4, true))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

static func _btn(bg: Color, radius: int, bordered: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if bordered:
		sb.set_border_width_all(1)
		sb.border_color = c("line")
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func _btn_outline(border_key: String = "line") -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(1)
	sb.border_color = c(border_key)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func field(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.add_theme_font_override("font", font(0))
	e.add_theme_font_size_override("font_size", FS_BODY)
	e.add_theme_color_override("font_color", c("text"))
	e.add_theme_color_override("font_placeholder_color", c("faint"))
	e.add_theme_color_override("caret_color", c("accent"))
	e.custom_minimum_size = Vector2(0, 92)
	var sb := StyleBoxFlat.new()
	sb.bg_color = c("surface")
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = c("line")
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	e.add_theme_stylebox_override("normal", sb)
	e.add_theme_stylebox_override("focus", sb)
	return e

## Zeile in einer Liste: Name (expand), optional Unterzeile, optional Wert.
## Der gesamte Zeilenbereich reagiert auf Tippen (sofern on_press gesetzt).
static func list_row(title: String, subtitle: String, right_text: String = "", on_press: Callable = Callable(), title_size: int = FS_BODY) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = c("surface")
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = c("line")
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := label(title, title_size, "text", 1)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	if subtitle != "":
		var st := label(subtitle, FS_MICRO, "muted")
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(st)
	row.add_child(v)
	if right_text != "":
		var r := label(right_text, FS_BODY, "text", 0)
		r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(r)
	p.add_child(row)
	# PASS, damit ein Zieh-Gesten-Event den ScrollContainer erreicht; getippt wird
	# erst beim Loslassen ohne nennenswerte Bewegung (sonst loest Scrollen aus).
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	if on_press.is_valid():
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var tap := {"pos": Vector2.ZERO, "down": false}
		p.gui_input.connect(func(ev: InputEvent):
			if not (ev is InputEventMouseButton) or ev.button_index != MOUSE_BUTTON_LEFT:
				return
			if ev.pressed:
				tap["pos"] = ev.global_position
				tap["down"] = true
			elif tap["down"]:
				tap["down"] = false
				if ev.global_position.distance_to(tap["pos"]) <= 24.0:
					on_press.call())
	return p

# --- Kleine Bausteine -------------------------------------------------------

## Kleines farbiges Etikett (z. B. "BEST").
static func chip(text: String, color_key: String, filled: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if filled:
		sb.bg_color = c(color_key)
		p.add_theme_stylebox_override("panel", sb)
		p.add_child(label(text.to_upper(), FS_MICRO, "on_accent", 2))
	else:
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(1)
		sb.border_color = c(color_key)
		p.add_theme_stylebox_override("panel", sb)
		p.add_child(label(text.to_upper(), FS_MICRO, color_key, 2))
	return p
