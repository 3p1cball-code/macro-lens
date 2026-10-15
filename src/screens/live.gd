extends Control
class_name LiveScreen

## Dauerscan: Kamera oben (native Vorschau), darunter die vier Grafiken des
## aktuellen Produkts und der gepinnten Vergleichsspalten. Kein Scrollen.

var app: App
var _matrix: VBoxContainer
var _pin_btn: Button

func _ready() -> void:
	if anchor_right == 0.0:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Shell.root())
	_build_camera()
	_build_body()
	refresh()

# --- Kameraflaeche (native Vorschau liegt darueber) -------------------------

func _build_camera() -> void:
	var cam := Control.new()
	cam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cam.anchor_left = 0.0
	cam.anchor_top = 0.0
	cam.anchor_right = 1.0
	cam.anchor_bottom = App.CAM_FRACTION
	add_child(cam)

	var ph := ColorRect.new()
	ph.color = UI.c("surface2")
	ph.set_anchors_preset(Control.PRESET_FULL_RECT)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cam.add_child(ph)

	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 60)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(3)
	sb.border_color = UI.c("accent")
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := CenterContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint := UI.micro(I18n.t("scan_hint"), "text")
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(hint)
	panel.add_child(inner)
	m.add_child(panel)
	cam.add_child(m)

# --- Koerper ----------------------------------------------------------------

func _build_body() -> void:
	var body := VBoxContainer.new()
	body.anchor_left = 0.0
	body.anchor_top = App.CAM_FRACTION
	body.anchor_right = 1.0
	body.anchor_bottom = 1.0
	body.add_theme_constant_override("separation", 0)
	add_child(body)
	body.add_child(UI.hline("accent", 3))
	body.add_child(Shell.pad(_top_bar(), Shell.PAD, 8, Shell.PAD, 6))

	var mid := VBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	mid.add_child(_vspacer())
	var mp := Shell.pad(_matrix_host(), Shell.PAD, 4, Shell.PAD, 4)
	mp.size_flags_vertical = Control.SIZE_FILL
	mid.add_child(mp)
	mid.add_child(_vspacer())
	body.add_child(mid)

	body.add_child(UI.hline("line", 1))
	body.add_child(Shell.pad(_bottom_bar(), Shell.PAD, 12, Shell.PAD, 22))

func _matrix_host() -> Control:
	_matrix = UI.vbox(12)
	return _matrix

func _vspacer() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _top_bar() -> Control:
	var h := UI.hbox(10)
	var logo := UI.hbox(0)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.add_child(UI.label("MACRO", 32, "text", 2))
	logo.add_child(UI.label(" LENS", 32, "accent_ink", 2))
	h.add_child(logo)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(_mini(I18n.t("search"), func(): app.goto("search")))
	h.add_child(_mini(I18n.t("history"), func(): app.goto("history")))
	h.add_child(_mini(I18n.t("settings"), func(): app.goto("settings")))
	return h

func _bottom_bar() -> Control:
	var h := UI.hbox(12)
	_pin_btn = UI.button("PIN", "primary", UI.FS_BODY)
	_pin_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pin_btn.custom_minimum_size = Vector2(0, 108)
	_pin_btn.pressed.connect(func(): app.pin_current())
	h.add_child(_pin_btn)

	var share := _mini(I18n.t("share"), func(): app.share_comparison())
	share.custom_minimum_size = Vector2(0, 108)
	h.add_child(share)

	var unp := _mini(I18n.t("unpackaged") + "  +", func(): app.goto("generics"))
	unp.custom_minimum_size = Vector2(0, 108)
	h.add_child(unp)
	return h

func _mini(text: String, cb: Callable) -> Button:
	var b := UI.button(text.to_upper(), "ghost", UI.FS_MICRO)
	b.custom_minimum_size = Vector2(0, 76)
	b.pressed.connect(cb)
	return b

# --- Inhalt ----------------------------------------------------------------

func _columns() -> Array:
	var cols: Array = []
	for i in range(app.tray.size()):
		cols.append({"food": app.tray[i], "pinned": true, "index": i})
	if app.current != null and app.tray.size() < App.MAX_TRAY:
		cols.append({"food": app.current, "pinned": false, "index": -1})
	return cols

func refresh() -> void:
	if _matrix == null:
		return
	for c in _matrix.get_children():
		c.queue_free()
	var cols: Array = _columns()
	if cols.is_empty():
		_matrix.add_child(_empty_state())
	else:
		_build_rows(cols)

	if _pin_btn == null:
		return
	var can_pin: bool = app.current != null and app.tray.size() < App.MAX_TRAY
	_pin_btn.disabled = not can_pin
	if app.current != null:
		_pin_btn.text = "PIN  ·  " + UI.short(app.current.display_name(I18n.lang), 18)
	elif app.tray.size() >= App.MAX_TRAY:
		_pin_btn.text = I18n.t("full")
	else:
		_pin_btn.text = "PIN"

func _empty_state() -> Control:
	var msg := I18n.t("scan_hint")
	match app.scan_status:
		"loading": msg = I18n.t("loading")
		"notfound": msg = I18n.t("not_found")
		"rate": msg = I18n.t("error_rate")
		"net": msg = I18n.t("error_net")
	var card := UI.card(40)
	var v := UI.vbox(14)
	v.add_child(UI.label(msg, UI.FS_TITLE, "text" if app.scan_status == "" else "accent_ink", 1))
	v.add_child(UI.label(I18n.t("attribution"), UI.FS_MICRO, "faint"))
	card.add_child(v)
	return card

func _build_rows(cols: Array) -> void:
	var n: int = cols.size()
	var num_size: int = [120, 92, 78, 64][clampi(n - 1, 0, 3)]
	var donut_h: int = [230, 190, 158, 140][clampi(n - 1, 0, 3)]
	var name_size: int = UI.FS_SMALL if n <= 2 else UI.FS_MICRO

	var evals: Array = []
	var kcals: Array = []
	var pds: Array = []
	var sats: Array = []
	for c in cols:
		var ev := Metrics.evaluate(c["food"])
		evals.append(ev)
		kcals.append(ev.density if ev.density_ok else -1.0)
		pds.append(ev.protein_density if ev.protein_density_ok else -1.0)
		sats.append(float(ev.fullness.get("score", -1)) if ev.fullness_ok else -1.0)
	var best_kcal := _best(kcals, true)
	var best_pd := _best(pds, false)
	var best_sat := _best(sats, false)

	# Namen (+ Papierkorb / NEU)
	var names := UI.hbox(12)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(150, 0)
	names.add_child(pad)
	for i in range(n):
		names.add_child(_head_cell(cols[i], name_size))
	_matrix.add_child(names)

	# Makro-Donut
	var drows: Array = []
	for i in range(n):
		var cell := UI.vbox(0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var d := MacroDonut.new()
		d.custom_minimum_size = Vector2(0, donut_h)
		d.ring_width = donut_h * 0.16
		if evals[i].split_ok:
			d.set_split(evals[i].split)
		cell.add_child(d)
		drows.append(cell)
	_matrix.add_child(_row("lbl_macros", drows))
	_matrix.add_child(UI.hline("line"))

	# Kaloriendichte
	var krows: Array = []
	for i in range(n):
		krows.append(_num_cell(Metrics.format_num(evals[i].density, 0) if evals[i].density_ok else "–", "kcal/100 g", num_size, i == best_kcal))
	_matrix.add_child(_row("lbl_density", krows))
	_matrix.add_child(UI.hline("line"))

	# Eiweissdichte
	var prows: Array = []
	for i in range(n):
		prows.append(_bar_cell(Metrics.format_num(evals[i].protein_density, 1) if evals[i].protein_density_ok else "–", "g/100 kcal", evals[i].protein_density if evals[i].protein_density_ok else -1.0, 25.0, "protein", num_size, i == best_pd))
	_matrix.add_child(_row("lbl_protein", prows))
	_matrix.add_child(UI.hline("line"))

	# Saettigung
	var srows: Array = []
	for i in range(n):
		var sc: float = float(evals[i].fullness.get("score", -1)) if evals[i].fullness_ok else -1.0
		var ck := "good" if sc >= 60 else ("warn" if sc >= 35 else "bad")
		srows.append(_bar_cell(str(int(sc)) if sc >= 0.0 else "–", "von 100", sc, 100.0, ck, num_size, i == best_sat))
	_matrix.add_child(_row("lbl_satiety", srows))

func _row(label_key: String, cells: Array) -> Control:
	var row := UI.hbox(12)
	var lbl := UI.label(I18n.t(label_key), UI.FS_MICRO, "muted", 1)
	lbl.custom_minimum_size = Vector2(150, 0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	for c in cells:
		row.add_child(c)
	return row

func _head_cell(col: Dictionary, name_size: int) -> Control:
	var food: Food = col["food"]
	var cell := UI.vbox(4)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UI.hbox(6)
	var nm := UI.label(UI.short(food.display_name(I18n.lang), 20), name_size, "text", 2)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size = Vector2(0, 44)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	if col["pinned"]:
		var idx: int = col["index"]
		var x := UI.button("×", "ghost", 34)
		x.custom_minimum_size = Vector2(56, 56)
		x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		x.pressed.connect(func(): app.unpin(idx))
		top.add_child(x)
	cell.add_child(top)
	var sub: String = food.brand if food.brand != "" else food.group
	var subrow := UI.hbox(8)
	if sub != "":
		var sl := UI.micro(sub)
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		subrow.add_child(sl)
	if not col["pinned"]:
		subrow.add_child(UI.chip(I18n.t("new"), "accent"))
	cell.add_child(subrow)
	return cell

func _num_cell(value: String, unit: String, num_size: int, best: bool) -> Control:
	var cell := UI.vbox(2)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(UI.big_number(value, "good" if best else "text", num_size))
	cell.add_child(UI.micro(unit))
	if best:
		var h := UI.hbox(0)
		h.add_child(UI.chip(I18n.t("best"), "good"))
		cell.add_child(h)
	return cell

func _bar_cell(value: String, unit: String, raw: float, maxv: float, color_key: String, num_size: int, best: bool) -> Control:
	var cell := UI.vbox(6)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(UI.big_number(value, "good" if best else "text", num_size))
	cell.add_child(UI.micro(unit))
	var bar := MeterBar.new()
	bar.bar_h = 26.0
	bar.set_value(raw, maxv, color_key)
	cell.add_child(bar)
	if best:
		var h := UI.hbox(0)
		h.add_child(UI.chip(I18n.t("best"), "good"))
		cell.add_child(h)
	return cell

static func _best(values: Array, lower: bool) -> int:
	var idx := -1
	var ref := INF if lower else -INF
	for i in values.size():
		var v: float = values[i]
		if v < 0.0:
			continue
		if lower and v < ref:
			ref = v
			idx = i
		elif not lower and v > ref:
			ref = v
			idx = i
	return idx
