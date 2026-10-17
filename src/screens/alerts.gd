extends RefCounted
class_name AlertsScreen

## Allergene & Unvertraeglichkeiten auswaehlen. Allergien warnen rot,
## Unvertraeglichkeiten (und Spuren einer Allergie) orange. Jede Zeile ist
## antippbar; die Auswahl wird sofort gespeichert. Zeilen reichen Zieh-Gesten
## durch, damit die lange Liste scrollt.

static func build(app: App) -> Control:
	var content := Shell.content_col()
	var clear := Shell.text_action(I18n.t("alerts_clear"), func():
		app.set_alert_ids([])
		app.goto("alerts"))
	var root_c := Shell.page(app, I18n.t("alerts_title"), content, true, clear)

	var state := {"sel": app.alert_ids()}
	var summary := UI.label("", UI.FS_BODY, "text", 1)
	var update_summary := func():
		summary.text = _summary(state["sel"])

	# Einleitung
	var intro := UI.card(30)
	var iv := UI.vbox(16)
	iv.add_child(summary)
	var how := UI.label(I18n.t("alerts_intro"), UI.FS_SMALL, "muted")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(how)
	var legend := UI.hbox(26)
	legend.add_child(_legend("bad", I18n.t("alerts_legend_red")))
	legend.add_child(_legend("intol", I18n.t("alerts_legend_orange")))
	iv.add_child(legend)
	iv.add_child(UI.hline())
	iv.add_child(UI.switch_row(I18n.t("alerts_traces"), I18n.t("alerts_traces_hint"), app.alert_traces(),
		func(on: bool): app.set_alert_traces(on)))
	intro.add_child(iv)
	content.add_child(intro)

	var toggle := func(id: String, row: AlertRow):
		var sel: Array = (state["sel"] as Array).duplicate()
		if sel.has(id):
			sel.erase(id)
		else:
			sel.append(id)
		state["sel"] = Allergens.sanitize(sel)
		app.set_alert_ids(state["sel"])
		row.set_on((state["sel"] as Array).has(id))
		Input.vibrate_handheld(10)
		update_summary.call()

	content.add_child(_section(I18n.t("alerts_allergies"), I18n.t("alerts_allergies_hint"), "bad",
		Allergens.ids(Allergens.ALLERGY), state, toggle))
	content.add_child(_section(I18n.t("alerts_intol"), I18n.t("alerts_intol_hint"), "intol",
		Allergens.ids(Allergens.INTOL), state, toggle))

	# Ehrlicher Hinweis
	var warn := UI.card(30)
	var wv := UI.vbox(12)
	wv.add_child(UI.micro(I18n.t("alerts_warn_title"), "bad"))
	var wt := UI.label(I18n.t("alerts_warn"), UI.FS_SMALL, "muted")
	wt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wv.add_child(wt)
	warn.add_child(wv)
	content.add_child(warn)

	update_summary.call()
	return root_c

static func _summary(sel: Array) -> String:
	var a := 0
	var i := 0
	for id in sel:
		if Allergens.kind_of(id) == Allergens.ALLERGY:
			a += 1
		else:
			i += 1
	if a == 0 and i == 0:
		return I18n.t("alerts_none")
	return I18n.t("alerts_count") % [a, i]

static func _legend(color_key: String, text: String) -> Control:
	var h := UI.hbox(10)
	var sw := ColorRect.new()
	sw.color = UI.c(color_key)
	sw.custom_minimum_size = Vector2(22, 22)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sw)
	h.add_child(UI.label(text, UI.FS_MICRO, "muted", 1))
	return h

static func _section(title: String, hint: String, color_key: String, ids: Array,
		state: Dictionary, toggle: Callable) -> Control:
	var card := UI.card(24)
	var v := UI.vbox(10)
	v.add_child(UI.micro(title, color_key))
	var h := UI.label(hint, UI.FS_MICRO, "faint")
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(h)
	for id in ids:
		var row := AlertRow.new()
		row.setup(id, color_key, (state["sel"] as Array).has(id))
		row.tapped.connect(func(): toggle.call(id, row))
		v.add_child(row)
	card.add_child(v)
	return card

## Eine Auswahlzeile: Farbpunkt, Name, Beispiele, Haken rechts. Tippen =
## umschalten (erst beim Loslassen ohne Bewegung - sonst scrollt die Liste).
class AlertRow extends PanelContainer:
	signal tapped
	var _color_key := "bad"
	var _check: CheckMark = null
	var _down := false
	var _pos := Vector2.ZERO

	func setup(id: String, color_key: String, on: bool) -> void:
		_color_key = color_key
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var h := UI.hbox(18)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(UI.label(Allergens.name(id, I18n.lang), UI.FS_BODY, "text", 1))
		var ex := UI.label(Allergens.examples(id, I18n.lang), UI.FS_MICRO, "muted")
		ex.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(ex)
		h.add_child(v)
		_check = CheckMark.new()
		_check.color_key = color_key
		_check.custom_minimum_size = Vector2(56, 56)
		_check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(_check)
		add_child(h)
		gui_input.connect(_on_input)
		set_on(on)

	func set_on(on: bool) -> void:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 20
		sb.content_margin_right = 14
		sb.content_margin_top = 14
		sb.content_margin_bottom = 14
		sb.set_border_width_all(1)
		if on:
			sb.bg_color = UI.c("surface").lerp(UI.c(_color_key), 0.14)
			sb.border_color = UI.c(_color_key)
			sb.border_width_left = 6
		else:
			sb.bg_color = UI.c("surface")
			sb.border_color = UI.c("line")
		add_theme_stylebox_override("panel", sb)
		_check.on = on

	func _on_input(ev: InputEvent) -> void:
		if not (ev is InputEventMouseButton) or ev.button_index != MOUSE_BUTTON_LEFT:
			return
		if ev.pressed:
			_down = true
			_pos = ev.global_position
		elif _down:
			_down = false
			if ev.global_position.distance_to(_pos) <= 24.0:
				tapped.emit()

## Runder Haken (gezeichnet; Open Sans hat kein passendes Symbol).
class CheckMark extends Control:
	var color_key := "bad"
	var on := false:
		set(v):
			on = v
			queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.4
		if on:
			draw_circle(c, r, UI.c(color_key), true, -1.0, true)
			var pts := PackedVector2Array([c + Vector2(-r * 0.45, 0.0), c + Vector2(-r * 0.1, r * 0.38),
				c + Vector2(r * 0.5, -r * 0.35)])
			draw_polyline(pts, UI.c("on_accent"), maxf(3.0, r * 0.18), true)
		else:
			draw_arc(c, r, 0.0, TAU, 48, UI.c("faint"), 2.5, true)
