extends RefCounted
class_name GenericsScreen

static func build(app: App) -> Control:
	var content := Shell.content_col()
	var root_c := Shell.page(app, I18n.t("unpackaged"), content, true)

	var field := UI.field(I18n.t("unpackaged_hint"))
	content.add_child(field)
	var list := UI.vbox(10)
	content.add_child(list)

	var rebuild := func(q: String):
		for c in list.get_children():
			c.queue_free()
		var items: Array = app.generics.search(q)
		if items.is_empty():
			list.add_child(UI.label(I18n.t("no_results"), UI.FS_BODY, "muted"))
			return
		var filtering: bool = q.strip_edges() != ""
		var last_group := ""
		for f in items:
			if not filtering and f.group != last_group:
				last_group = f.group
				list.add_child(UI.micro(f.group))
			var r := UI.hbox(10)
			var sub: String = f.group if filtering else ""
			r.add_child(UI.list_row(f.display_name(I18n.lang), sub, (Metrics.format_num(f.kcal, 0) + " kcal") if f.has_kcal() else "", func(): app.open_food(f), UI.FS_SMALL))
			var add := UI.button("+", "ghost", 40)
			add.custom_minimum_size = Vector2(88, 0)
			add.pressed.connect(func():
				app.tray_add(f)
				app.goto("home"))
			r.add_child(add)
			list.add_child(r)

	field.text_changed.connect(func(q): rebuild.call(q))
	rebuild.call("")
	return root_c
