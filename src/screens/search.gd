extends RefCounted
class_name SearchScreen

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

	var status := UI.label("", UI.FS_SMALL, "muted")
	content.add_child(status)
	var list := UI.vbox(14)
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(list)

	var do_search := func():
		var q := field.text.strip_edges()
		if q == "":
			return
		for c in list.get_children():
			c.queue_free()
		status.text = I18n.t("searching")
		var res: Dictionary = await app.off.search(q)
		status.text = ""
		var foods: Array = res.get("foods", [])
		if foods.is_empty():
			list.add_child(UI.label(I18n.t("no_results") if res.get("error", "") == "" else I18n.t("error_net"), UI.FS_BODY, "muted"))
			return
		for f in foods:
			var r := UI.hbox(12)
			r.mouse_filter = Control.MOUSE_FILTER_PASS
			var kcal: String = Metrics.format_num(f.kcal, 0) + " kcal" if f.has_kcal() else ""
			var sub: String = f.brand if f.brand != "" else ""
			var on_show := func(): app.set_current(f); app.goto("live")
			r.add_child(UI.list_row(f.display_name(I18n.lang), sub, kcal, on_show))
			var add := UI.button("+", "ghost", 40)
			add.custom_minimum_size = Vector2(96, 0)
			add.pressed.connect(func(): app.add_pinned(f); app.goto("live"))
			r.add_child(add)
			list.add_child(r)

	btn.pressed.connect(do_search)
	field.text_submitted.connect(func(_t): do_search.call())
	return root_c
