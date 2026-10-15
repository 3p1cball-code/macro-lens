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
	_matrix = UI.vbox(8)
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
	if not cols.is_empty() and app.scan_status != "" and app.scan_status != "loading":
		_matrix.add_child(_status_banner())
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

## Kompaktes Banner ueber der Matrix, wenn ein Scan keine brauchbaren Daten
## geliefert hat (die gepinnten Produkte bleiben dabei sichtbar).
func _status_banner() -> Control:
	var status: String = app.scan_status
	var text := ""
	match status:
		"nodata":
			var nm := app.last_missing.display_name(I18n.lang) if app.last_missing != null else ""
			text = I18n.t("no_data") + (" · " + nm if nm != "" else " · " + app.last_scan_code)
		"noname":
			text = I18n.t("no_name") + " · " + app.last_scan_code
		"notfound":
			text = I18n.t("not_found") + " · " + app.last_scan_code
		"rate":
			text = I18n.t("error_rate")
		"net":
			text = I18n.t("error_net")
	var card := UI.card(12)
	var h := UI.hbox(12)
	var l := UI.label(text, UI.FS_MICRO, "accent_ink", 1)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(l)
	if status == "nodata":
		var s := UI.button(I18n.t("search_online"), "ghost", UI.FS_MICRO)
		s.custom_minimum_size = Vector2(0, 62)
		s.pressed.connect(func():
			app.pending_search = app.last_missing.display_name(I18n.lang) if app.last_missing != null else ""
			app.goto("search"))
		h.add_child(s)
	var g := UI.button(I18n.t("basic_food"), "ghost", UI.FS_MICRO)
	g.custom_minimum_size = Vector2(0, 62)
	g.pressed.connect(func(): app.goto("generics"))
	h.add_child(g)
	card.add_child(h)
	return card

func _empty_state() -> Control:
	var status: String = app.scan_status
	var title := I18n.t("scan_hint")
	var body := I18n.t("attribution")
	var actions := false
	var can_search := false
	var can_retry := false
	match status:
		"loading":
			title = I18n.t("loading")
			body = ""
		"notfound":
			title = I18n.t("not_found")
			body = I18n.t("barcode") + ": " + app.last_scan_code
			actions = true
			can_retry = true
		"nodata":
			title = I18n.t("no_data")
			var nm := app.last_missing.display_name(I18n.lang) if app.last_missing != null else ""
			body = (nm + " · " if nm != "" else app.last_scan_code + " · ") + I18n.t("no_data_hint")
			actions = true
			can_search = true
		"noname":
			title = I18n.t("no_name")
			body = I18n.t("barcode") + ": " + app.last_scan_code + " · " + I18n.t("no_data_hint")
			actions = true
		"rate":
			title = I18n.t("error_rate")
			body = I18n.t("attribution")
			actions = true
			can_retry = true
		"net":
			title = I18n.t("error_net")
			body = I18n.t("attribution")
			actions = true
			can_retry = true
	var card := UI.card(38)
	var v := UI.vbox(16)
	v.add_child(UI.label(title, UI.FS_TITLE, "text" if status == "" else "accent_ink", 1))
	if body != "":
		var b := UI.label(body, UI.FS_SMALL, "muted")
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(b)
	if actions:
		var row := UI.hbox(12)
		if can_search:
			var s := UI.button(I18n.t("search_online"), "primary")
			s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s.pressed.connect(func():
				app.pending_search = app.last_missing.display_name(I18n.lang) if app.last_missing != null else ""
				app.goto("search"))
			row.add_child(s)
		var g := UI.button(I18n.t("basic_food"), "ghost" if can_search else "primary")
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.pressed.connect(func(): app.goto("generics"))
		row.add_child(g)
		if can_retry:
			var r := UI.button(I18n.t("retry"), "ghost")
			r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.pressed.connect(func(): app.retry_scan())
			row.add_child(r)
		v.add_child(row)
	card.add_child(v)
	return card

func _build_rows(cols: Array) -> void:
	var n: int = cols.size()
	var num_size: int = [96, 92, 78, 64][clampi(n - 1, 0, 3)]
	var donut_h: int = [200, 142, 144, 128][clampi(n - 1, 0, 3)]
	var name_size: int = UI.FS_SMALL if n <= 2 else UI.FS_MICRO
	var show_legend: bool = n <= 2
	var show_best: bool = n >= 2

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

	# Makro-Donut (Prozente daneben; kompakt: Eiweiss-Prozent im Kreis)
	var drows: Array = []
	for i in range(n):
		drows.append(_donut_cell(evals[i], donut_h, show_legend))
	_matrix.add_child(_row("lbl_macros", drows))
	_matrix.add_child(UI.hline("line"))

	# Kaloriendichte (gruen -> rot, auf einer Skala 0..500)
	var krows: Array = []
	for i in range(n):
		var ev = evals[i]
		var col: Color = UI.c("faint") if not ev.density_ok else UI.scale_color(Metrics.density_t(ev.density))
		krows.append(_bar_cell(Metrics.format_num(ev.density, 0) if ev.density_ok else "–", "kcal/100 g", ev.density if ev.density_ok else -1.0, 500.0, col, num_size, show_best and i == best_kcal))
	_matrix.add_child(_row("lbl_density", krows))
	_matrix.add_child(UI.hline("line"))

	# Eiweissdichte (viel = gruen)
	var prows: Array = []
	for i in range(n):
		var ev = evals[i]
		var col: Color = UI.c("faint") if not ev.protein_density_ok else UI.scale_color(Metrics.protein_t(ev.protein_density))
		prows.append(_bar_cell(Metrics.format_num(ev.protein_density, 1) if ev.protein_density_ok else "–", "g/100 kcal", ev.protein_density if ev.protein_density_ok else -1.0, 25.0, col, num_size, show_best and i == best_pd))
	_matrix.add_child(_row("lbl_protein", prows))
	_matrix.add_child(UI.hline("line"))

	# Saettigung (hoch = gruen)
	var srows: Array = []
	for i in range(n):
		var ev = evals[i]
		var sc: float = float(ev.fullness.get("score", -1)) if ev.fullness_ok else -1.0
		var col: Color = UI.c("faint") if sc < 0.0 else UI.scale_color(Metrics.satiety_t(sc))
		srows.append(_bar_cell(str(int(sc)) if sc >= 0.0 else "–", "von 100", sc, 100.0, col, num_size, show_best and i == best_sat))
	_matrix.add_child(_row("lbl_satiety", srows))

func _donut_cell(ev: Dictionary, h: int, show_legend: bool) -> Control:
	var cell := UI.hbox(18 if show_legend else 0)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if show_legend:
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
	var d := MacroDonut.new()
	d.custom_minimum_size = Vector2(h, h)
	d.ring_width = h * 0.16
	d.center_mode = "none" if show_legend else "protein"
	if ev.split_ok:
		d.set_split(ev.split)
	cell.add_child(d)
	if show_legend and ev.split_ok:
		var legend := UI.vbox(12)
		legend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(_legend_row("protein", ev.split))
		legend.add_child(_legend_row("carbs", ev.split))
		legend.add_child(_legend_row("fat", ev.split))
		cell.add_child(legend)
	return cell

func _legend_row(key: String, split: Dictionary) -> Control:
	var row := UI.hbox(10)
	var ck: String = "protein"
	if key == "carbs":
		ck = "carbs"
	elif key == "fat":
		ck = "fat"
	var sw := ColorRect.new()
	sw.color = UI.c(ck)
	sw.custom_minimum_size = Vector2(20, 20)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sw)
	var nm := UI.label(I18n.t(key + "_short"), UI.FS_MICRO, "muted", 1)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size = Vector2(92, 0)
	row.add_child(nm)
	row.add_child(UI.label(str(roundi(float(split.get(key, 0.0)) * 100.0)) + " %", UI.FS_BODY, "text", 2))
	return row

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

func _bar_cell(value: String, unit: String, raw: float, maxv: float, col: Color, num_size: int, best: bool) -> Control:
	var cell := UI.vbox(6)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(UI.big_number_colored(value, col, num_size))
	cell.add_child(UI.micro(unit))
	var bar := MeterBar.new()
	bar.bar_h = 26.0
	bar.set_value(raw, maxv, "", col)
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
