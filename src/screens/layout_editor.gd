extends Control
class_name LayoutEditor

## Hauptseite zusammenstellen.
##   oben:   Vorlagen (fertige + eigene), eigene speichern / loeschen
##   Mitte:  Vorschau der aktiven Bausteine (max. 5) - wie auf der Hauptseite
##   unten:  Dock mit allen 10 Bausteinen als Mini-Vorschau
## Bedienung:
##   - Karte aus dem Dock nach oben ziehen -> einrasten an der Markierung
##   - Baustein ziehen -> umsortieren; ins Dock ziehen -> entfernen
##   - Tippen auf Baustein -> Einstellungen; Tippen auf Dock-Karte -> anhaengen
## Jede Aenderung ist sofort gespeichert (sticky); Vorlagen/Entfernen mit Undo.
## Keine Scroll-Container: nichts konkurriert mit den Ziehgesten.

var app: App

var _layout: Array = []
var _foods: Array = []
var _demo := false

var _area: Control = null
var _list: VBoxContainer = null
var _info: Label = null
var _items: Array = []            # Rahmen je aktivem Baustein (Trefferflaeche)
var _handles: Array = []          # Griff je Baustein
var _presets: HFlowContainer = null
var _dock_panel: PanelContainer = null
var _dock_label: Label = null
var _dock_cards: Dictionary = {}  # id -> Karte
var _overlay: Control = null      # Einstellungen / Speichern-Dialog
var _sheet_index := -1
var _plan_sig := ""

# Ziehen
const DRAG_START := 14.0
const TAP_MAX := 24.0
var _p_src := ""                  # "" | "item" | "dock"
var _p_index := -1
var _p_id := ""
var _p_start := Vector2.ZERO
var _dragging := false
var _ghost: Control = null
var _line: ColorRect = null
var _insert := -1
var _over_dock := false
var _blocked := false

func _ready() -> void:
	if anchor_right == 0.0:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout = Layout.sanitize(app.layout)
	_pick_foods()
	add_child(Shell.root())

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	var reset := Shell.text_action(I18n.t("editor_reset"), func(): _apply(Layout.default_layout(), I18n.t("editor_applied")))
	col.add_child(Shell.pad(Shell.header(app, I18n.t("editor_title"), true, reset), Shell.PAD, 36, Shell.PAD, 0))
	col.add_child(Shell.pad(_presets_strip(), Shell.PAD, 20, Shell.PAD, 10))

	# Vorschau: feste Flaeche (Hoehe unabhaengig vom Inhalt), Inhalt mittig.
	_area = Control.new()
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_area.clip_contents = true
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 12)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info = UI.label("", UI.FS_MICRO, "faint", 1)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # sonst ist die Zeile breiter als der Schirm
	inner.add_child(Shell.pad(_info, Shell.PAD, 0, Shell.PAD, 0))
	_list = UI.vbox(12)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(Shell.pad(_list, Shell.PAD, 0, Shell.PAD, 0))
	_area.add_child(inner)
	col.add_child(_area)

	col.add_child(UI.hline())
	col.add_child(_dock())
	add_child(col)

	_line = ColorRect.new()
	_line.top_level = true
	_line.visible = false
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_line)

	_area.resized.connect(_on_area_resized)
	_rebuild()

## Android-Zurueck: erst offene Ebenen schliessen.
func handle_back() -> bool:
	if _overlay != null:
		_close_overlay()
		return true
	return false

# --- Daten fuer die Vorschau ------------------------------------------------

## Echte Produkte (Ablage/aktuell), sonst Beispiele: verpacktes Muesli
## (Portion/Packung bekannt), Skyr, Banane.
func _pick_foods() -> void:
	var real: Array = []
	for f in app.tray:
		real.append(f)
	if app.current != null and not app.tray_has(app.current) and real.size() < App.MAX_TRAY:
		real.append(app.current)
	if real.size() >= 2:
		_foods = real
		_demo = false
		return
	_demo = true
	_foods = [app.call("_demo_food")]
	for g in app.generics.all():
		if g.name in ["Skyr", "Banane"]:
			_foods.append(g)

# --- Vorlagen -----------------------------------------------------------------

func _presets_strip() -> Control:
	var v := UI.vbox(12)
	v.add_child(UI.micro(I18n.t("editor_presets")))
	_presets = HFlowContainer.new()
	_presets.add_theme_constant_override("h_separation", 12)
	_presets.add_theme_constant_override("v_separation", 12)
	v.add_child(_presets)
	_fill_presets()
	return v

func _fill_presets() -> void:
	for c in _presets.get_children():
		c.queue_free()
	var active := Layout.matching_preset(app.store, _layout)
	for p in Layout.builtin_presets() + Layout.user_presets(app.store):
		var on: bool = p["name"] == active
		var b := UI.button(p["name"], "primary" if on else "ghost", UI.FS_MICRO)
		b.custom_minimum_size = Vector2(0, 72)
		var lay: Array = p["layout"]
		b.pressed.connect(func(): _apply(lay, I18n.t("editor_applied")))
		if p["user"]:
			var h := UI.hbox(0)
			h.add_child(b)
			var x := UI.button("×", "ghost", UI.FS_SMALL)
			x.custom_minimum_size = Vector2(64, 72)
			var nm: String = p["name"]
			x.pressed.connect(func(): _delete_preset(nm, lay))
			h.add_child(x)
			_presets.add_child(h)
		else:
			_presets.add_child(b)
	var save := UI.button("+  " + I18n.t("editor_save"), "accent", UI.FS_MICRO)
	save.custom_minimum_size = Vector2(0, 72)
	save.pressed.connect(_open_save_dialog)
	_presets.add_child(save)

func _apply(l: Array, msg: String) -> void:
	var prev := _layout.duplicate(true)
	if Layout.equal(prev, l):
		return
	_commit(l)
	app.toast(msg, I18n.t("undo"), func(): _commit(prev))

func _delete_preset(name: String, lay: Array) -> void:
	Layout.delete_user_preset(app.store, name)
	_fill_presets()
	app.toast(I18n.t("editor_preset_deleted"), I18n.t("undo"), func():
		Layout.save_user_preset(app.store, name, lay)
		_fill_presets())

# --- Dock -----------------------------------------------------------------------

func _dock() -> Control:
	_dock_panel = PanelContainer.new()
	_dock_panel.add_theme_stylebox_override("panel", _dock_style(false))
	var v := UI.vbox(14)
	_dock_label = UI.micro(I18n.t("editor_blocks") + "  ·  " + I18n.t("editor_dock_hint"))
	v.add_child(_dock_label)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for id in Blocks.ids():
		var card := _dock_card(id)
		_dock_cards[id] = card
		grid.add_child(card)
	v.add_child(grid)
	_dock_panel.add_child(v)
	_update_dock()
	return _dock_panel

func _dock_style(drop: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UI.c("bad").lerp(UI.c("bg"), 0.82) if drop else UI.c("bg")
	sb.content_margin_left = Shell.PAD
	sb.content_margin_right = Shell.PAD
	sb.content_margin_top = 18
	sb.content_margin_bottom = 30
	return sb

func _dock_card(id: String) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UI.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pv := BlockPreview.new()
	pv.block_id = id
	pv.custom_minimum_size = Vector2(0, 74)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pv)
	var nm := UI.label(Blocks.block_name(id), 22, "text", 1)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	v.add_child(nm)
	p.add_child(v)
	return p

## Aktive Bausteine im Dock markieren (Akzentrahmen + Haken).
func _update_dock() -> void:
	for id in _dock_cards:
		var card: PanelContainer = _dock_cards[id]
		var on := Layout.contains(_layout, id)
		var sb := UI.card_style(8, 4, "surface")
		if on:
			sb.border_color = UI.c("accent")
			sb.set_border_width_all(2)
		card.add_theme_stylebox_override("panel", sb)
		card.modulate.a = 1.0 if on or not Layout.is_full(_layout) else 0.45
		var nm: Label = card.get_child(0).get_child(1)
		nm.text = ("✓ " if on else "") + Blocks.block_name(id)
		nm.add_theme_color_override("font_color", UI.c("accent_ink") if on else UI.c("text"))

# --- Vorschau ---------------------------------------------------------------------

func _avail() -> float:
	var h := _area.size.y if _area != null and _area.size.y > 1.0 else get_viewport_rect().size.y * 0.45
	return h - 60.0                     # Infozeile + Abstaende

func _per_block() -> float:
	var n := maxi(_layout.size(), 1)
	return (_avail() - (n - 1) * 12.0) / n - 26.0   # Rahmen + Innenabstand

func _plan_signature() -> String:
	var per := _per_block()
	var parts: PackedStringArray = []
	for e in _layout:
		parts.append(JSON.stringify(BlockView.sizes(Blocks.kind(e["id"]), _foods.size(), per, e.get("options", {}))))
	return "|".join(parts)

func _on_area_resized() -> void:
	if _dragging:
		return
	if _plan_signature() != _plan_sig:
		_rebuild.call_deferred()

func _rebuild(focus_id: String = "") -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_items = []
	_handles = []
	var per := _per_block()
	var ctx := app.block_ctx()
	for i in _layout.size():
		var e: Dictionary = _layout[i]
		var sz := BlockView.sizes(Blocks.kind(e["id"]), _foods.size(), per, e.get("options", {}))
		var item := PanelContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := UI.card_style(10, 4, "surface")
		sb.content_margin_left = 4
		item.add_theme_stylebox_override("panel", sb)
		var h := UI.hbox(6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var grip := Grip.new()
		grip.custom_minimum_size = Vector2(44, 0)
		grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(grip)
		var row := BlockView.block_row(e, _foods, ctx, sz)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ignore_mouse(row)
		h.add_child(row)
		item.add_child(h)
		_list.add_child(item)
		_items.append(item)
		_handles.append(grip)
		if e["id"] == focus_id:
			Anim.pulse([item])
	var info := str(_layout.size()) + " / " + str(Blocks.MAX_ACTIVE) + "  ·  " + I18n.t("editor_preview_hint")
	if _demo:
		info += "  ·  " + I18n.t("editor_demo")
	_info.text = info.to_upper()
	_plan_sig = _plan_signature()

## Vorschau ist nur Anzeige: Eingaben laufen ueber _input (Ziehen/Tippen).
func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)

func _commit(l: Array, focus_id: String = "") -> void:
	_layout = Layout.sanitize(l)
	app.set_layout(_layout)
	_rebuild(focus_id)
	_fill_presets()
	_update_dock()

func _remove_at(index: int) -> void:
	if _layout.size() <= 1:
		app.toast(I18n.t("editor_last"))
		return
	var prev := _layout.duplicate(true)
	_commit(Layout.remove(_layout, index))
	app.toast(I18n.t("editor_removed"), I18n.t("undo"), func(): _commit(prev))

# --- Eingaben: Tippen + Ziehen ------------------------------------------------------

func _hit_item(pos: Vector2) -> int:
	for i in _items.size():
		var c: Control = _items[i]
		if is_instance_valid(c) and c.get_global_rect().has_point(pos):
			return i
	return -1

func _hit_dock(pos: Vector2) -> String:
	for id in _dock_cards:
		var c: Control = _dock_cards[id]
		if c.get_global_rect().has_point(pos):
			return id
	return ""

func _input(event: InputEvent) -> void:
	if _overlay != null or not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_p_src = ""
			_p_start = event.position
			var i := _hit_item(event.position)
			if i >= 0:
				_p_src = "item"
				_p_index = i
				_p_id = _layout[i]["id"]
			else:
				var id := _hit_dock(event.position)
				if id != "":
					_p_src = "dock"
					_p_id = id
		else:
			if _dragging:
				get_viewport().set_input_as_handled()
				_drop(event.position)
			elif _p_src != "" and event.position.distance_to(_p_start) <= TAP_MAX:
				get_viewport().set_input_as_handled()
				if _p_src == "item":
					_open_sheet(_p_index)
				else:
					_tap_dock(_p_id)
			_p_src = ""
	elif event is InputEventMouseMotion and _p_src != "" \
			and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if not _dragging:
			if event.position.distance_to(_p_start) < DRAG_START:
				return
			_begin_drag()
		_move_drag(event.position)
		get_viewport().set_input_as_handled()

func _tap_dock(id: String) -> void:
	var at := Layout.ids(_layout).find(id)
	if at >= 0:
		_open_sheet(at)
		return
	if Layout.is_full(_layout):
		app.toast(I18n.t("editor_full"))
		return
	Input.vibrate_handheld(12)
	_commit(Layout.add(_layout, id), id)

func _begin_drag() -> void:
	_dragging = true
	_insert = -1
	_ghost = PanelContainer.new()
	var sb := UI.card_style(10, 6, "surface")
	sb.border_color = UI.c("accent")
	sb.set_border_width_all(2)
	_ghost.add_theme_stylebox_override("panel", sb)
	var v := UI.vbox(4)
	var pv := BlockPreview.new()
	pv.block_id = _p_id
	pv.custom_minimum_size = Vector2(190, 80)
	v.add_child(pv)
	var nm := UI.label(Blocks.block_name(_p_id), UI.FS_MICRO, "text", 2)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	_ghost.add_child(v)
	_ghost.top_level = true
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ignore_mouse(_ghost)
	add_child(_ghost)
	_ghost.pivot_offset = Vector2(110, 70)
	_ghost.scale = Vector2.ONE * 0.9
	var tw := _ghost.create_tween()
	tw.tween_property(_ghost, "scale", Vector2.ONE * 1.04, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _p_src == "item" and _p_index < _items.size():
		(_items[_p_index] as Control).modulate.a = 0.3
	Input.vibrate_handheld(12)

func _move_drag(pos: Vector2) -> void:
	if _ghost != null:
		_ghost.position = pos - _ghost.size * 0.5
	var dock_rect := _dock_panel.get_global_rect()
	var over := dock_rect.has_point(pos) and _p_src == "item"
	if over != _over_dock:
		_over_dock = over
		_dock_panel.add_theme_stylebox_override("panel", _dock_style(over))
		_dock_label.text = I18n.t("editor_drop_remove") if over \
			else I18n.t("editor_blocks") + "  ·  " + I18n.t("editor_dock_hint")
		_dock_label.add_theme_color_override("font_color", UI.c("bad") if over else UI.c("muted"))
		if over:
			Input.vibrate_handheld(10)
	if over or (_p_src == "dock" and dock_rect.has_point(pos)):
		_line.visible = false
		_insert = -1
		return
	# Einfuegeposition = Anzahl sichtbarer Bausteine oberhalb des Fingers.
	var visible_items: Array = []
	for i in _items.size():
		if _p_src == "item" and i == _p_index:
			continue
		visible_items.append(_items[i])
	var idx := 0
	for c in visible_items:
		if pos.y > (c as Control).get_global_rect().get_center().y:
			idx += 1
	_blocked = _p_src == "dock" and not Layout.contains(_layout, _p_id) and Layout.is_full(_layout)
	var y := 0.0
	if visible_items.is_empty():
		y = _list.get_global_rect().get_center().y
	elif idx == 0:
		y = (visible_items[0] as Control).get_global_rect().position.y - 7.0
	else:
		y = (visible_items[idx - 1] as Control).get_global_rect().end.y + 5.0
	var lr := _list.get_global_rect()
	_line.position = Vector2(lr.position.x, y - 2.0)
	_line.size = Vector2(lr.size.x, 4.0)
	_line.color = UI.c("bad") if _blocked else UI.c("accent")
	_line.visible = true
	if idx != _insert:
		_insert = idx
		Input.vibrate_handheld(8)

func _drop(pos: Vector2) -> void:
	var src := _p_src
	var from := _p_index
	var id := _p_id
	var target := _insert
	var over := _over_dock
	_end_drag()
	if src == "item":
		if over:
			_remove_at(from)
		elif target >= 0 and target != from:
			Input.vibrate_handheld(14)
			_commit(Layout.move(_layout, from, target), id)
	elif src == "dock" and target >= 0:
		if Layout.contains(_layout, id):
			_commit(Layout.move(_layout, Layout.ids(_layout).find(id), target), id)
		elif Layout.is_full(_layout):
			app.toast(I18n.t("editor_full"))
		else:
			Input.vibrate_handheld(14)
			_commit(Layout.add(_layout, id, target), id)

func _end_drag() -> void:
	_dragging = false
	_line.visible = false
	if _ghost != null:
		var g := _ghost
		_ghost = null
		var tw := g.create_tween().set_parallel(true)
		tw.tween_property(g, "modulate:a", 0.0, 0.12)
		tw.tween_property(g, "scale", Vector2.ONE * 0.8, 0.12)
		tw.chain().tween_callback(g.queue_free)
	for c in _items:
		if is_instance_valid(c):
			(c as Control).modulate.a = 1.0
	if _over_dock:
		_over_dock = false
		_dock_panel.add_theme_stylebox_override("panel", _dock_style(false))
		_dock_label.text = I18n.t("editor_blocks") + "  ·  " + I18n.t("editor_dock_hint")
		_dock_label.add_theme_color_override("font_color", UI.c("muted"))
	_p_src = ""

# --- Ebenen: Baustein-Einstellungen, Vorlage speichern ---------------------------

func _overlay_base(top_anchor: float) -> VBoxContainer:
	_close_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_overlay())
	_overlay.add_child(dim)
	var card := PanelContainer.new()
	var sb := UI.card_style(40, 6, "surface")
	card.add_theme_stylebox_override("panel", sb)
	card.anchor_left = 0.0
	card.anchor_right = 1.0
	card.anchor_top = top_anchor
	card.anchor_bottom = 1.0
	card.offset_left = 18
	card.offset_right = -18
	card.offset_bottom = -18
	var sc := Shell.scroll()
	var v := UI.vbox(26)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(v)
	card.add_child(sc)
	_overlay.add_child(card)
	add_child(_overlay)
	Anim.pop_in(card, 0.0, 0.22, 0.97)
	return v

func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
	_overlay = null
	_sheet_index = -1

func _open_sheet(index: int) -> void:
	if index < 0 or index >= _layout.size():
		return
	var v := _overlay_base(0.12)   # setzt _sheet_index zurueck -> danach setzen
	_sheet_index = index
	_fill_sheet(v)

func _fill_sheet(v: VBoxContainer) -> void:
	for c in v.get_children():
		c.queue_free()
	var e: Dictionary = _layout[_sheet_index]
	var id: String = e["id"]
	var opts: Dictionary = e["options"]

	var head := UI.vbox(8)
	head.add_child(UI.micro(I18n.t("editor_blocks"), "accent_ink"))
	head.add_child(UI.label(Blocks.block_name(id), UI.FS_TITLE, "text", 2))
	var d := UI.label(Blocks.desc(id), UI.FS_SMALL, "muted")
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(d)
	v.add_child(head)

	# Live-Vorschau mit den aktuellen Optionen
	var pv := UI.card(16)
	var sz := BlockView.sizes(Blocks.kind(id), _foods.size(), 250.0, opts)
	var row := BlockView.block_row(e, _foods, app.block_ctx(), sz)
	_ignore_mouse(row)
	pv.add_child(row)
	v.add_child(pv)

	for o in Blocks.option_specs(id):
		if not Blocks.option_visible(o, opts):
			continue
		var key: String = o["key"]
		if o["type"] == "bool":
			v.add_child(UI.switch_row(I18n.t(o["label"]), "", bool(opts.get(key, false)),
				func(on: bool): _set_option(key, on)))
		else:
			var box := UI.vbox(12)
			box.add_child(UI.micro(I18n.t(o["label"])))
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 12)
			flow.add_theme_constant_override("v_separation", 12)
			for ch in o["choices"]:
				var val: String = ch[0]
				var on: bool = str(opts.get(key, "")) == val
				var b := UI.button(I18n.t(ch[1]), "primary" if on else "ghost", UI.FS_SMALL)
				b.custom_minimum_size = Vector2(0, 76)
				b.pressed.connect(func(): _set_option(key, val))
				flow.add_child(b)
			box.add_child(flow)
			v.add_child(box)

	var btns := UI.hbox(14)
	var rm := UI.button(I18n.t("editor_remove"), "ghost")
	rm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rm.disabled = _layout.size() <= 1
	var idx := _sheet_index
	rm.pressed.connect(func():
		_close_overlay()
		_remove_at(idx))
	btns.add_child(rm)
	var done := UI.button(I18n.t("editor_done"), "primary")
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(_close_overlay)
	btns.add_child(done)
	v.add_child(btns)

func _set_option(key: String, value) -> void:
	if _sheet_index < 0:
		return
	var keep := _sheet_index
	_layout = Layout.set_option(_layout, keep, key, value)
	app.set_layout(_layout)
	_rebuild()
	_fill_presets()
	# Sheet neu fuellen (sichtbare Optionen koennen sich aendern, z. B. "Bezug").
	if _overlay != null:
		var sc: ScrollContainer = _overlay.get_child(1).get_child(0)
		var scroll := sc.scroll_vertical
		_sheet_index = keep
		_fill_sheet(sc.get_child(0))
		sc.set_deferred("scroll_vertical", scroll)

func _open_save_dialog() -> void:
	var v := _overlay_base(0.42)
	v.add_child(UI.micro(I18n.t("editor_save_title"), "accent_ink"))
	var field := UI.field(I18n.t("editor_name_hint"))
	var n := Layout.user_presets(app.store).size() + 1
	field.text = ("Meine Seite %d" if I18n.lang == "de" else "My layout %d") % n
	field.select_all_on_focus = true
	v.add_child(field)
	var names: PackedStringArray = []
	for e in _layout:
		names.append(Blocks.block_name(e["id"]))
	var l := UI.label(" · ".join(names), UI.FS_SMALL, "muted")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var row := UI.hbox(14)
	var cancel := UI.button(I18n.t("close"), "ghost")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_close_overlay)
	row.add_child(cancel)
	var ok := UI.button(I18n.t("editor_save"), "primary")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var do_save := func():
		if Layout.save_user_preset(app.store, field.text, _layout):
			_close_overlay()
			_fill_presets()
			app.toast(I18n.t("editor_saved"))
		else:
			app.toast(I18n.t("editor_save_fail"))
	ok.pressed.connect(do_save)
	field.text_submitted.connect(func(_t): do_save.call())
	row.add_child(ok)
	v.add_child(row)
	field.grab_focus.call_deferred()

# --- Griff ------------------------------------------------------------------------

## Sechs Punkte als Zieh-Griff.
class Grip extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var col := UI.c("faint")
		for dx in [-7.0, 7.0]:
			for dy in [-14.0, 0.0, 14.0]:
				draw_circle(c + Vector2(dx, dy), 3.5, col, true, -1.0, true)
