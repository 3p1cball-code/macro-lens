extends RefCounted
class_name HistoryScreen

static func build(app: App) -> Control:
	var content := Shell.content_col()
	var right := Shell.text_action(I18n.t("clear"), func():
		app.store.clear_history()
		app.store.save_history()
		app.goto("history"))
	var root_c := Shell.page(app, I18n.t("history_title"), content, true, right)

	var filter := UI.field(I18n.t("search_hint"))
	content.add_child(filter)

	var list := UI.vbox(14)
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(list)

	var entries: Array = app.store.history
	if entries.is_empty():
		list.add_child(UI.label(I18n.t("history_empty"), UI.FS_BODY, "muted"))
		return root_c

	var rebuild := func(q: String):
		for c in list.get_children():
			c.queue_free()
		var shown := 0
		for e in entries:
			var name := str(e.get("name", ""))
			if q != "" and not name.to_lower().contains(q.to_lower()):
				continue
			var bc := str(e.get("barcode", ""))
			var food: Food = app.resolve_barcode(bc)
			if food == null and str(e.get("source", "")) == "generic":
				continue
			var row := UI.hbox(12)
			row.mouse_filter = Control.MOUSE_FILTER_PASS
			var kcal := ""
			if food != null and food.has_kcal():
				kcal = Metrics.format_num(food.kcal, 0) + " kcal"
			var on_show := func(): app.pick(food, bc, false)
			row.add_child(UI.list_row(name, _subtitle(e, food), kcal, on_show))
			var add := UI.button("+", "ghost", 40)
			add.custom_minimum_size = Vector2(96, 0)
			add.pressed.connect(func(): app.pick(food, bc, true))
			row.add_child(add)
			list.add_child(row)
			shown += 1
		if shown == 0:
			list.add_child(UI.label(I18n.t("no_results"), UI.FS_BODY, "muted"))

	filter.text_changed.connect(func(q): rebuild.call(q))
	rebuild.call("")
	return root_c

static func _subtitle(e: Dictionary, f: Food) -> String:
	var parts := []
	if f != null and f.brand != "":
		parts.append(f.brand)
	if e.get("source", "") == "generic":
		parts.append(I18n.t("unpackaged"))
	var t := int(e.get("ts", 0))
	if t > 0:
		parts.append(Time.get_datetime_string_from_unix_time(t).substr(0, 10))
	return " · ".join(parts)
