extends RefCounted
class_name GenericsScreen

static func build(app: App) -> Control:
	var content := Shell.content_col()
	var root_c := Shell.page(app, I18n.t("unpackaged"), content, true)

	var field := UI.field(I18n.t("unpackaged_hint"))
	content.add_child(field)

	var manual := UI.button(I18n.t("barcode") + "  …", "ghost", UI.FS_MICRO)
	manual.custom_minimum_size = Vector2(0, 74)
	manual.pressed.connect(func(): app.prompt_barcode())
	content.add_child(manual)

	var list := UI.vbox(10)
	list.mouse_filter = Control.MOUSE_FILTER_PASS
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
			r.mouse_filter = Control.MOUSE_FILTER_PASS
			var sub: String = f.group if filtering else ""
			var kcal: String = (Metrics.format_num(f.kcal, 0) + " kcal") if f.has_kcal() else ""
			var on_tap := func(): app.pick(f, f.barcode, true)
			r.add_child(UI.list_row(f.display_name(I18n.lang), sub, kcal, on_tap, UI.FS_SMALL))
			var add := UI.button("+", "ghost", 40)
			add.custom_minimum_size = Vector2(88, 0)
			add.pressed.connect(on_tap)
			r.add_child(add)
			list.add_child(r)

	field.text_changed.connect(func(q): rebuild.call(q))
	rebuild.call("")
	return root_c
