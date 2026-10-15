extends RefCounted
class_name Shell

## Gemeinsame Screen-Bausteine: Hintergrund, Rand, Kopfzeile, Scrollbereich.

const PAD := 44
const GAP := 26

static func root(color_key: String = "bg") -> ColorRect:
	var r := ColorRect.new()
	r.color = UI.c(color_key)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func pad(child: Control, l: int = PAD, t: int = 0, r: int = PAD, b: int = 0) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(child)
	return m

static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	s.scroll_deadzone = 30
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s

## Kopfzeile. with_back=false zeigt die Wortmarke (Startseite).
static func header(app: App, title: String, with_back: bool = true, right: Control = null) -> Control:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 120)
	row.add_theme_constant_override("separation", 24)
	if with_back:
		var b := UI.button("‹", "ghost", 60)
		b.custom_minimum_size = Vector2(100, 92)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): app.goto("live"))
		row.add_child(b)
		var t := UI.label(title.to_upper(), 38, "text", 1)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(t)
	else:
		var logo := HBoxContainer.new()
		logo.add_theme_constant_override("separation", 0)
		logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		logo.add_child(UI.label("MACRO", 46, "text", 2))
		logo.add_child(UI.label(" LENS", 46, "accent_ink", 2))
		row.add_child(logo)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
	if right != null:
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(right)
	outer.add_child(row)
	outer.add_child(UI.hline())
	return outer

## Vollstaendiger Screen: Hintergrund + Kopfzeile + scrollbarer Inhalt.
static func page(app: App, title: String, content: Control, with_back: bool = true, right: Control = null) -> Control:
	var root_c := Control.new()
	root_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_c.add_child(root())
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	col.add_child(pad(header(app, title, with_back, right), PAD, 36, PAD, 0))
	var inner := pad(content, PAD, GAP, PAD, 60)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	var sc := scroll()
	sc.add_child(inner)
	col.add_child(sc)
	root_c.add_child(col)
	root_c.set_meta("scroll", sc)
	root_c.set_meta("content", content)
	return root_c

static func content_col(sep: int = GAP) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	# Events durchreichen, damit der ScrollContainer Zieh-Gesten bekommt.
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	return v

## Kompakter Text-Button in der Kopfzeile (statt Emoji-Glyphen -> sicher auf Android).
static func text_action(text: String, on_press: Callable) -> Button:
	var b := UI.button(text.to_upper(), "ghost", UI.FS_MICRO)
	b.custom_minimum_size = Vector2(0, 72)
	b.pressed.connect(on_press)
	return b
