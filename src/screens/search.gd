extends RefCounted
class_name SearchScreen

## Namenssuche ueber Open Food Facts. Die Suche ist dort stark limitiert
## (~10/min): der OffClient drosselt, cached und teilt laufende Anfragen.
## Hier: bei Fehlern bleiben die letzten Treffer stehen, es gibt eine klare
## Meldung (Limit vs. Netz) und "Nochmal". Aeltere Antworten werden verworfen,
## wenn inzwischen neu gesucht wurde.

static func build(app: App) -> Control:
	var content := Shell.content_col()
	var root_c := Shell.page(app, I18n.t("search"), content, true)

	var row := UI.hbox(14)
	var field := UI.field(I18n.t("search_hint"))
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	var btn := UI.button(I18n.t("search"), "primary")
	btn.custom_minimum_size = Vector2(220, 92)
	row.add_child(btn)
	content.add_child(row)

	var status_row := UI.hbox(12)
	var status := UI.label("", UI.FS_SMALL, "muted")
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_row.add_child(status)
	var retry := UI.button(I18n.t("retry"), "ghost", UI.FS_MICRO)
	retry.custom_minimum_size = Vector2(0, 66)
	retry.visible = false
	status_row.add_child(retry)
	content.add_child(status_row)

	var list := UI.vbox(14)
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(list)

	var state := {"seq": 0, "last": ""}

	var fill := func(foods: Array):
		for c in list.get_children():
			c.queue_free()
		if foods.is_empty():
			list.add_child(UI.label(I18n.t("no_results"), UI.FS_BODY, "muted"))
			return
		for f in foods:
			var r := UI.hbox(12)
			r.mouse_filter = Control.MOUSE_FILTER_PASS
			var kcal: String = Metrics.format_num(f.kcal, 0) + " kcal" if f.has_kcal() else ""
			var sub: String = f.brand if f.brand != "" else ""
			var on_show := func(): app.pick(f, f.barcode, false)
			r.add_child(UI.list_row(f.display_name(I18n.lang), sub, kcal, on_show))
			var add := UI.button("+", "ghost", 40)
			add.custom_minimum_size = Vector2(96, 0)
			add.pressed.connect(func(): app.pick(f, f.barcode, true))
			r.add_child(add)
			list.add_child(r)

	var do_search := func(q: String):
		q = q.strip_edges()
		if q == "":
			return
		state["seq"] = int(state["seq"]) + 1
		var my_seq: int = state["seq"]
		state["last"] = q
		status.text = I18n.t("searching")
		retry.visible = false
		var res: Dictionary = await app.off.search(q)
		if my_seq != int(state["seq"]) or not is_instance_valid(status):
			return   # inzwischen neu gesucht oder Screen verlassen
		var err := str(res.get("error", ""))
		if err != "":
			# Letzte Treffer stehen lassen; klar sagen, was los ist.
			status.text = I18n.t("error_rate_hint") if err == "rate" else I18n.t("error_net")
			retry.visible = true
			return
		status.text = ""
		fill.call(res.get("foods", []))

	btn.pressed.connect(func(): do_search.call(field.text))
	field.text_submitted.connect(func(t): do_search.call(t))
	retry.pressed.connect(func(): do_search.call(str(state["last"])))

	# Vorbelegung aus dem Live-Screen ("Keine Naehrwerte -> im Netz suchen").
	var pre: String = app.pending_search
	app.pending_search = ""
	if pre != "":
		field.text = pre
		do_search.call(pre)
	return root_c
