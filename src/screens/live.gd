extends Control
class_name LiveScreen

## Dauerscan: Kamera oben (native Vorschau), darunter die Bausteine (Layout,
## Standard: vier Grafiken) fuer das aktuelle Produkt und die gepinnten
## Vergleichsspalten. Kein Scrollen - die Bausteine teilen sich die Hoehe.
## Bedienung per Geste: Spalte nach UNTEN wischen = pinnen,
## nach OBEN wischen = entfernen (gepinnt oder aktuell).

var app: App
var _matrix: VBoxContainer
var _cols: Array = []             # aktuelle Spalten (siehe _columns)

# Animationszustand: welche Spalten (Schluessel -> gepinnt?) standen zuletzt da.
var _prev_cols: Dictionary = {}
var _first_build := true
var _col_nodes: Array = []        # je Spalte die Slide-Huellen ihrer Zellen
var _anim_cols: Array = []        # je Spalte: neu aufbauen?
var _busy := false                # Wegfliegen laeuft (Doppelgeste-Schutz)
var _mid: Control = null          # Mittelteil (Hoehe = Platz fuer die Bausteine)
var _banner_shown := false
var _hint_shown := false
var _plan_sig := ""               # Groessenplan des letzten Aufbaus
var _built_ms := 0

# Wischgesten (Einheiten: Basis-Viewport 1080x1920)
const SWIPE_START := 22.0         # ab hier ist es ein Wischen (nicht Tippen)
const SWIPE_COMMIT := 170.0       # so weit wischen = Aktion ausloesen
const FLICK_SPEED := 1400.0       # ... oder so schnell (px/s)
const FLICK_MIN := 70.0           # ... und mindestens so weit
var _g_col := -1
var _g_start := Vector2.ZERO
var _g_active := false
var _g_dy := 0.0
var _g_vel := 0.0
var _g_armed := false
var _g_hint: Control = null       # Hinweis waehrend des Wischens
var _drop: Dictionary = {}        # gerade gepinnt -> Einrast-Animation
var _shot_drag := Vector2.ZERO    # Screenshot-Modus: (Spalte, dy) einfrieren

func _ready() -> void:
	if anchor_right == 0.0:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Shell.root())
	_build_camera()
	_build_body()
	refresh()
	if app != null and app.debug_drag != Vector2.ZERO:
		_shot_drag = app.debug_drag
		_freeze_drag.call_deferred()

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

	# Mittelteil: feste Flaeche (Hoehe haengt NICHT vom Inhalt ab - sonst
	# Rueckkopplung mit dem Hoehenbudget der Bausteine). Inhalt mittig,
	# Ueberstand wird abgeschnitten (gewischte Spalten verschwinden an der Kante).
	var mid := Control.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.clip_contents = true
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 0)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mp := Shell.pad(_matrix_host(), Shell.PAD, 4, Shell.PAD, 4)
	inner.add_child(mp)
	mid.add_child(inner)
	body.add_child(mid)
	_mid = mid
	mid.resized.connect(_on_mid_resized)

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
	if app != null and app.show_quit():
		h.add_child(_quit_button())
	return h

## X oben rechts (nur wenn in den Einstellungen aktiviert): App sofort beenden.
func _quit_button() -> Button:
	var b := UI.button("", "ghost", UI.FS_MICRO)
	b.custom_minimum_size = Vector2(76, 76)
	b.tooltip_text = I18n.t("quit_app")
	var x := CloseGlyph.new()
	x.mouse_filter = Control.MOUSE_FILTER_IGNORE
	x.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(x)
	b.pressed.connect(func(): app.quit_app())
	return b

func _bottom_bar() -> Control:
	var h := UI.hbox(12)
	var unp := _mini("+  " + I18n.t("unpackaged"), func(): app.goto("generics"))
	unp.custom_minimum_size = Vector2(0, 108)
	unp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unp.add_theme_font_size_override("font_size", UI.FS_SMALL)
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
	if app.current != null and app.tray.size() < App.MAX_TRAY and not app.tray_has(app.current):
		cols.append({"food": app.current, "pinned": false, "index": -1})
	return cols

static func _key(f: Food) -> String:
	return f.barcode if f.barcode != "" else "n:" + f.name

func refresh() -> void:
	if _matrix == null:
		return
	for c in _matrix.get_children():
		_matrix.remove_child(c)
		c.queue_free()
	_cancel_gesture()
	var cols: Array = _columns()
	_cols = cols
	# Nur neue Spalten bauen sich auf; frisch gepinnte pulsieren kurz.
	var now_cols: Dictionary = {}
	var pulse_cols: Array = []
	_anim_cols = []
	for i in cols.size():
		var k := _key(cols[i]["food"])
		now_cols[k] = cols[i]["pinned"]
		var is_new: bool = _first_build or not _prev_cols.has(k)
		_anim_cols.append(is_new)
		if not is_new and cols[i]["pinned"] and not bool(_prev_cols[k]):
			pulse_cols.append(i)
	_prev_cols = now_cols
	_first_build = false
	_col_nodes = []
	for i in cols.size():
		_col_nodes.append([])

	_banner_shown = not cols.is_empty() and app.scan_status != "" and app.scan_status != "loading"
	if _banner_shown:
		var banner := _status_banner()
		_matrix.add_child(banner)
		Anim.pop_in(banner, 0.0, Anim.POP, 0.97)
	if cols.is_empty():
		_hint_shown = false
		var es := _empty_state()
		_matrix.add_child(es)
		Anim.pop_in(es, 0.0, Anim.POP, 0.97)
	else:
		var hint := _gesture_hint(cols)
		_hint_shown = hint != null
		_build_rows(cols)
		for i in pulse_cols:
			Anim.pulse(_col_nodes[i])
		_settle_drop(cols)
		if hint != null:
			_matrix.add_child(hint)
	_drop = {}
	_plan_sig = _plan_signature()
	_built_ms = Time.get_ticks_msec()

## Groessenplan als Text: aendert er sich (z. B. erstes Layout, Drehen,
## Einblendung der Navigationsleiste), wird neu aufgebaut.
func _plan_signature() -> String:
	if _cols.is_empty():
		return "empty"
	var per := BlockView.budget(_blocks_avail(), app.layout.size())
	var parts: PackedStringArray = []
	for e in app.layout:
		parts.append(JSON.stringify(BlockView.sizes(Blocks.kind(e["id"]), _cols.size(), per, e.get("options", {}))))
	return "|".join(parts)

func _on_mid_resized() -> void:
	if _matrix == null or _cols.is_empty() or _g_active or _busy:
		return
	if _plan_signature() == _plan_sig:
		return
	# Direkt nach dem Aufbau (erstes Layout): Aufbau-Animation nicht verschlucken.
	if Time.get_ticks_msec() - _built_ms < 400:
		_first_build = true
	refresh.call_deferred()

## Kompaktes Banner ueber der Matrix, wenn ein Scan keine brauchbaren Daten
## geliefert hat (die gepinnten Produkte bleiben dabei sichtbar).
func _status_banner() -> Control:
	var status: String = app.scan_status
	var text := ""
	if status == "nonfood":
		return _nonfood_card(true)
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
	if status == "":
		return _big_message(I18n.t("empty_live"))
	if status == "loading":
		return _big_message(I18n.t("loading"))
	if status == "nonfood":
		return _nonfood_card(false)
	var title := ""
	var body := ""
	var can_search := false
	var can_retry := false
	match status:
		"notfound":
			title = I18n.t("not_found")
			body = I18n.t("barcode") + ": " + app.last_scan_code
			can_retry = true
		"nodata":
			title = I18n.t("no_data")
			var nm := app.last_missing.display_name(I18n.lang) if app.last_missing != null else ""
			body = (nm + " · " if nm != "" else app.last_scan_code + " · ") + I18n.t("no_data_hint")
			can_search = true
		"noname":
			title = I18n.t("no_name")
			body = I18n.t("barcode") + ": " + app.last_scan_code + " · " + I18n.t("no_data_hint")
		"rate":
			title = I18n.t("error_rate")
			body = I18n.t("error_rate_hint")
			can_retry = true
		"net":
			title = I18n.t("error_net")
			body = I18n.t("error_net_hint")
			can_retry = true
	var card := UI.card(38)
	var v := UI.vbox(16)
	v.add_child(UI.label(title, UI.FS_TITLE, "accent_ink", 1))
	if body != "":
		var b := UI.label(body, UI.FS_SMALL, "muted")
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(b)
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

## Grosser, ruhiger Text mittig im freien Bereich (Leerzustand, Laden).
func _big_message(text: String) -> Control:
	var l := UI.label(text, UI.FS_TITLE, "muted", 1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(0, 160)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 40)
	m.add_child(l)
	return m

## "Kein Lebensmittel": gefunden in Open Products/Beauty Facts, mit Augenzwinkern.
## compact=true -> schmales Banner ueber gepinnten Spalten.
func _nonfood_card(compact: bool) -> Control:
	var item: Dictionary = app.last_nonfood
	var kind := str(item.get("kind", "other"))
	var name := str(item.get("name", "")).strip_edges()
	var brand := str(item.get("brand", "")).strip_edges()
	var parts: PackedStringArray = []
	if name != "":
		parts.append(name)
	if brand != "" and not name.to_lower().contains(brand.to_lower()):
		parts.append(brand)
	parts.append(NonFood.label(kind, I18n.lang))
	var card := UI.card(16 if compact else 38)
	var v := UI.vbox(6 if compact else 14)
	v.add_child(UI.micro(I18n.t("nonfood_title"), "bad"))
	var msg := UI.label(NonFood.message(kind, I18n.lang), UI.FS_BODY if compact else UI.FS_TITLE, "text", 2)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	var sub := UI.label(" · ".join(parts), UI.FS_MICRO if compact else UI.FS_SMALL, "muted")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if compact:
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(sub)
	if not compact:
		var src := UI.label(I18n.t("found_in") + " " + NonFood.source_name(str(item.get("source", ""))),
			UI.FS_MICRO, "faint")
		v.add_child(src)
	card.add_child(v)
	return card

func _build_rows(cols: Array) -> void:
	var n: int = cols.size()
	var name_size: int = UI.FS_SMALL if n <= 2 else UI.FS_MICRO

	# Namen (+ PIN-Hinweis)
	var names := UI.hbox(12)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(BlockView.GUTTER, 0)
	names.add_child(pad)
	for i in range(n):
		names.add_child(_cell(i, 0, _head_cell(cols[i], name_size)))
	_matrix.add_child(names)

	# Bausteine laut Layout. Kein Scrollen: jeder bekommt ein Hoehenbudget.
	var foods: Array = []
	for c in cols:
		foods.append(c["food"])
	var layout: Array = app.layout
	var per := BlockView.budget(_blocks_avail(), layout.size())
	var ctx := app.block_ctx()
	for bi in layout.size():
		var entry: Dictionary = layout[bi]
		var row_idx := bi + 1
		var sz := BlockView.sizes(Blocks.kind(entry["id"]), n, per, entry.get("options", {}))
		var wrap := func(i: int, c: Control) -> Control: return _cell(i, row_idx, c)
		var delay := func(i: int) -> float: return _delay(i, row_idx) if _anim_cols[i] else -1.0
		_matrix.add_child(BlockView.block_row(entry, foods, ctx, sz, wrap, delay))
		if bi < layout.size() - 1:
			_matrix.add_child(UI.hline("line"))

## Verfuegbare Hoehe fuer die Bausteine (ohne Namenszeile, Banner, Hinweis).
## Gemessen am Mittelteil; vor dem ersten Layout geschaetzt.
func _blocks_avail() -> float:
	var h := 0.0
	if _mid != null and _mid.size.y > 1.0:
		h = _mid.size.y - 8.0
	else:
		var vh := get_viewport_rect().size.y
		h = vh * (1.0 - App.CAM_FRACTION) - 244.0
	h -= 100.0                          # Namenszeile
	if _banner_shown:
		h -= 96.0
	if _hint_shown:
		h -= 50.0
	return h

## Aufbau-Verzoegerung: Zeile fuer Zeile, Spalten leicht versetzt.
func _delay(col: int, row: int) -> float:
	var rank := 0
	for j in range(col):
		if _anim_cols[j]:
			rank += 1
	return row * Anim.STAGGER + rank * Anim.STAGGER * 0.6

## Zelle der Spalte zuordnen und (bei neuer Spalte) einblenden.
func _cell(col: int, row: int, c: Control) -> Control:
	var w := Slide.new().wrap(c)
	_col_nodes[col].append(w)
	if _anim_cols[col]:
		Anim.pop_in(c, _delay(col, row))
	return w

func _head_cell(col: Dictionary, name_size: int) -> Control:
	var food: Food = col["food"]
	var cell := UI.vbox(4)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Gepinnt: kurze Akzentlinie oben ("Nadel"); aktuell: Platzhalter gleicher Hoehe.
	var line := PinLine.new()
	line.custom_minimum_size = Vector2(0, 5)
	line.visible_line = col["pinned"]
	cell.add_child(line)
	var nm := UI.label(UI.short(food.display_name(I18n.lang), 20), name_size, "text", 2)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size = Vector2(0, 44)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(nm)
	var sub: String = food.brand if food.brand != "" else food.display_group(I18n.lang)
	var subrow := UI.hbox(8)
	if sub != "":
		var sl := UI.micro(sub)
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		subrow.add_child(sl)
	if not col["pinned"]:
		subrow.add_child(_swipe_chip())
	cell.add_child(subrow)
	return cell

## "v PIN" - zeigt an, dass diese Spalte noch nicht gepinnt ist (nach unten wischen).
func _swipe_chip() -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(2)
	sb.border_color = UI.c("accent")
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var h := UI.hbox(6)
	var ch := Chevron.new()
	ch.down = true
	ch.color_key = "accent_ink"
	ch.custom_minimum_size = Vector2(22, 22)
	ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ch)
	h.add_child(UI.label("PIN", UI.FS_MICRO, "accent_ink", 2))
	p.add_child(h)
	return p

# --- Wischgesten -------------------------------------------------------------

## Spalte unter dem Punkt (Huellrechteck aller Zellen der Spalte), sonst -1.
func _col_at(pos: Vector2) -> int:
	for i in _col_nodes.size():
		var r := _col_rect(i)
		if r.size.x > 0.0 and r.grow_individual(6, 10, 6, 10).has_point(pos):
			return i
	return -1

func _col_rect(i: int) -> Rect2:
	var r := Rect2()
	var first := true
	for w in _col_nodes[i]:
		var c := w as Control
		if c == null or not is_instance_valid(c) or not c.is_inside_tree():
			continue
		var g := c.get_global_rect()   # Huelle bewegt sich nicht, nur ihr Inhalt
		r = g if first else r.merge(g)
		first = false
	return r

func _input(event: InputEvent) -> void:
	if _busy or _cols.is_empty() or _shot_drag != Vector2.ZERO:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_g_col = _col_at(event.position)
			_g_start = event.position
			_g_active = false
			_g_armed = false
			_g_dy = 0.0
			_g_vel = 0.0
		elif _g_col >= 0:
			if _g_active:
				get_viewport().set_input_as_handled()
				_release()
			_g_col = -1
	elif event is InputEventMouseMotion and _g_col >= 0 \
			and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var d: Vector2 = event.position - _g_start
		if not _g_active:
			if absf(d.x) > SWIPE_START * 2.0 and absf(d.x) > absf(d.y):
				_g_col = -1          # eher seitlich -> keine Geste
				return
			if absf(d.y) < SWIPE_START or absf(d.y) < absf(d.x) * 1.3:
				return
			_g_active = true
		_g_dy = d.y
		_g_vel = event.velocity.y
		_drag_visual()
		get_viewport().set_input_as_handled()

## Was die aktuelle Geste bewirken wuerde: "pin", "out" oder "" (nur Widerstand).
func _g_mode() -> String:
	if _g_col < 0 or _g_col >= _cols.size():
		return ""
	if _g_dy < 0.0:
		return "out"
	return "" if _cols[_g_col]["pinned"] else "pin"

func _drag_visual() -> void:
	if _g_col < 0 or _g_col >= _col_nodes.size():
		return
	var mode := _g_mode()
	var dy := _g_dy
	var off := 0.0
	var prog := 0.0
	match mode:
		"pin":
			prog = clampf(dy / SWIPE_COMMIT, 0.0, 1.0)
			off = dy if dy < SWIPE_COMMIT else SWIPE_COMMIT + (dy - SWIPE_COMMIT) * 0.25
		"out":
			prog = clampf(-dy / SWIPE_COMMIT, 0.0, 1.0)
			off = dy
		_:
			off = 40.0 * (1.0 - exp(-dy / 140.0))   # schon gepinnt: nur leichter Widerstand
	var armed := prog >= 1.0
	var tint := Color.WHITE
	if mode == "pin":
		tint = Color.WHITE.lerp(Color(0.80, 1.0, 0.86), prog)
	elif mode == "out":
		tint = Color(1, 1, 1, 1.0 - 0.6 * prog)
	for w in _col_nodes[_g_col]:
		(w as Slide).offset = off
		(w as Control).modulate = tint
	_show_hint(mode, prog, armed)
	if armed and not _g_armed:
		_g_armed = true
		if _g_hint != null:
			Anim.pulse([_g_hint])
		Input.vibrate_handheld(12)
	elif not armed:
		_g_armed = false

## Schriftzug in der Luecke, die die Spalte beim Wischen freigibt.
func _show_hint(mode: String, prog: float, armed: bool) -> void:
	if mode == "":
		_hide_hint()
		return
	if _g_hint == null or not is_instance_valid(_g_hint):
		_g_hint = UI.hbox(8)
		_g_hint.top_level = true
		_g_hint.alignment = BoxContainer.ALIGNMENT_CENTER
		_g_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ch := Chevron.new()
		ch.custom_minimum_size = Vector2(28, 28)
		ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_g_hint.add_child(ch)
		_g_hint.add_child(UI.label("", UI.FS_SMALL, "text", 2))
		add_child(_g_hint)
	var ch: Chevron = _g_hint.get_child(0)
	var lbl: Label = _g_hint.get_child(1)
	ch.down = mode == "pin"
	var key := "muted"
	if armed:
		key = "good" if mode == "pin" else "bad"
	ch.color_key = key
	ch.queue_redraw()
	lbl.text = I18n.t("swipe_pin" if mode == "pin" else "swipe_out")
	lbl.add_theme_color_override("font_color", UI.c(key))
	var r := _col_rect(_g_col)
	var hh := 48.0
	_g_hint.size = Vector2(r.size.x, hh)
	var y := r.position.y + 8.0 if mode == "pin" else r.end.y - hh - 8.0
	_g_hint.position = Vector2(r.position.x, y)
	_g_hint.modulate.a = clampf(prog * 1.6, 0.0, 1.0)

func _hide_hint() -> void:
	if _g_hint != null and is_instance_valid(_g_hint):
		_g_hint.queue_free()
	_g_hint = null

func _release() -> void:
	var i := _g_col
	var mode := _g_mode()
	var flick := absf(_g_dy) >= FLICK_MIN and absf(_g_vel) >= FLICK_SPEED \
		and signf(_g_vel) == signf(_g_dy)
	var commit := absf(_g_dy) >= SWIPE_COMMIT or flick
	_hide_hint()
	_g_active = false
	if i < 0 or i >= _cols.size():
		return
	var col: Dictionary = _cols[i]
	var ws: Array = _col_nodes[i]
	if mode == "pin" and commit:
		# Neu aufbauen; die Spalte rastet von hier aus nach oben ein (_settle_drop).
		_drop = {"key": _key(col["food"]), "from": (ws[0] as Slide).offset}
		app.mark_learned("pin")
		app.pin_current()
		return
	if mode == "out" and commit:
		_busy = true
		var food: Food = col["food"]
		var pinned: bool = col["pinned"]
		var from: float = (ws[0] as Slide).offset
		var tw := create_tween().set_parallel(true)
		for w in ws:
			tw.tween_property(w, "offset", from - 260.0, 0.17) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tw.tween_property(w, "modulate:a", 0.0, 0.15)
		tw.chain().tween_callback(func():
			_busy = false
			if pinned:
				app.mark_learned("unpin")
				app.unpin_food(food)
			else:
				app.mark_learned("unpin")
				app.dismiss_current())
		return
	# Nicht weit genug: zurueckfedern.
	var tw2 := create_tween().set_parallel(true)
	for w in ws:
		tw2.tween_property(w, "offset", 0.0, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(w, "modulate", Color.WHITE, 0.22)

func _cancel_gesture() -> void:
	_g_col = -1
	_g_active = false
	_g_armed = false
	_hide_hint()

## Gerade gepinnte Spalte: aus der Wischposition nach oben einrasten,
## Nadel-Linie zieht sich auf.
func _settle_drop(cols: Array) -> void:
	if _drop.is_empty():
		return
	for i in cols.size():
		if _key(cols[i]["food"]) != _drop["key"]:
			continue
		var from: float = _drop["from"]
		for w in _col_nodes[i]:
			var sl := w as Slide
			sl.offset = from
			var tw := sl.create_tween()
			tw.tween_property(sl, "offset", 0.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var head := (_col_nodes[i][0] as Slide).get_child(0)
		var line := head.get_child(0) as PinLine
		if line != null:
			line.progress = 0.0
			var tl := line.create_tween()
			tl.tween_interval(0.12)
			tl.tween_property(line, "progress", 1.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		return

## Dezente Erklaerzeile, bis die Gesten einmal benutzt wurden.
func _gesture_hint(cols: Array) -> Control:
	var parts: Array = []
	var has_new := false
	for c in cols:
		if not c["pinned"]:
			has_new = true
	if has_new and not app.learned("pin"):
		parts.append([true, I18n.t("hint_pin")])
	if not app.learned("unpin") and (app.learned("pin") or not has_new):
		parts.append([false, I18n.t("hint_out")])
	if parts.is_empty():
		return null
	var h := UI.hbox(26)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p in parts:
		var g := UI.hbox(8)
		var ch := Chevron.new()
		ch.down = p[0]
		ch.color_key = "faint"
		ch.custom_minimum_size = Vector2(20, 20)
		ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		g.add_child(ch)
		g.add_child(UI.label(p[1], UI.FS_MICRO, "faint", 1))
		h.add_child(g)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 14)
	m.add_child(h)
	return m

## Screenshot-Modus: Geste mitten im Wischen einfrieren (--drag=SPALTE,DY).
func _freeze_drag() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_g_col = int(_shot_drag.x)
	_g_dy = _shot_drag.y
	_g_active = true
	_drag_visual()

# --- kleine Zeichen-Bausteine -------------------------------------------------

## Pfeilspitze (Open Sans hat keine Pfeil-Glyphen).
class Chevron extends Control:
	var down := true
	var color_key := "muted"
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var y0 := h * 0.30
		var y1 := h * 0.72
		var pts := PackedVector2Array([Vector2(w * 0.15, y0), Vector2(w * 0.5, y1), Vector2(w * 0.85, y0)]) if down \
			else PackedVector2Array([Vector2(w * 0.15, y1), Vector2(w * 0.5, y0), Vector2(w * 0.85, y1)])
		draw_polyline(pts, UI.c(color_key), maxf(2.0, w * 0.13), true)

## Akzentlinie ueber gepinnten Spalten.
class PinLine extends Control:
	var visible_line := true
	var progress := 1.0:
		set(v):
			progress = v
			queue_redraw()
	func _draw() -> void:
		if not visible_line:
			return
		var w := size.x * 0.42 * clampf(progress, 0.0, 1.0)
		draw_rect(Rect2(0, 0, w, size.y), UI.c("accent"))

## "X" fuer den Schliessen-Knopf (Open Sans hat kein passendes Zeichen).
class CloseGlyph extends Control:
	func _draw() -> void:
		var m := minf(size.x, size.y)
		var r := m * 0.20
		var c := size * 0.5
		var w := maxf(2.0, m * 0.05)
		var col := UI.c("text")
		draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, w, true)
		draw_line(c + Vector2(-r, r), c + Vector2(r, -r), col, w, true)
