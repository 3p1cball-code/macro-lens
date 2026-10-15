extends RefCounted
class_name HomeScreen

static func build(app: App) -> Control:
	var content := Shell.content_col()
	content.add_child(UI.micro(I18n.t("tagline")))

	# Hauptaktion
	var scan_btn := UI.button(I18n.t("scan"), "primary", 60)
	scan_btn.custom_minimum_size = Vector2(0, 200)
	scan_btn.pressed.connect(func(): app.scan())
	content.add_child(scan_btn)

	var row := UI.hbox(20)
	var search_btn := UI.button(I18n.t("search"), "ghost")
	search_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_btn.pressed.connect(func(): app.goto("search"))
	row.add_child(search_btn)
	var gen_btn := UI.button(I18n.t("unpackaged"), "ghost")
	gen_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gen_btn.pressed.connect(func(): app.goto("generics"))
	row.add_child(gen_btn)
	content.add_child(row)

	var manual := UI.button(I18n.t("barcode") + "  …", "ghost", UI.FS_MICRO)
	manual.custom_minimum_size = Vector2(0, 74)
	manual.pressed.connect(func(): app.prompt_barcode())
	content.add_child(manual)

	content.add_child(_tray_section(app))

	# Fusszeile
	var foot := UI.hbox(0)
	var about := UI.label("ÜBER  ·  " + I18n.t("about_text"), UI.FS_SMALL, "muted")
	foot.add_child(about)
	content.add_child(foot)
	content.add_child(UI.label(I18n.t("attribution"), UI.FS_MICRO, "faint"))
	var theme_label: String = I18n.t("theme_light") if UI.dark else I18n.t("theme_dark")
	return Shell.page(app, "", content, false, Shell.text_action(theme_label, func(): app.set_dark_mode(not UI.dark)))

static func _tray_section(app: App) -> Control:
	var box := UI.vbox(18)
	var head := UI.hbox(0)
	head.add_child(UI.micro(I18n.t("tray") + "  " + str(app.tray.size()) + "/4"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	if not app.tray.is_empty():
		var cb := Button.new()
		cb.text = I18n.t("clear")
		cb.flat = true
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_override("font", UI.font(1))
		cb.add_theme_font_size_override("font_size", UI.FS_MICRO)
		cb.add_theme_color_override("font_color", UI.c("muted"))
		cb.add_theme_color_override("font_hover_color", UI.c("accent_ink"))
		cb.pressed.connect(func(): app.tray_clear(); app.goto("home"))
		head.add_child(cb)
	box.add_child(head)

	if app.tray.is_empty():
		var c := UI.card()
		c.add_child(UI.label(I18n.t("empty_tray"), UI.FS_SMALL, "muted"))
		box.add_child(c)
	else:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		for i in app.tray.size():
			grid.add_child(_mini_card(app, app.tray[i], i))
		box.add_child(grid)
		var go := UI.button(I18n.t("compare"), "primary")
		go.disabled = app.tray.size() < 2
		go.pressed.connect(func(): app.goto("compare"))
		box.add_child(go)
	return box

static func _mini_card(app: App, f: Food, index: int) -> Control:
	var card := UI.card(20)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 210)
	var v := UI.vbox(6)
	var top := UI.hbox(8)
	var nm := UI.label(f.display_name(I18n.lang), UI.FS_SMALL, "text", 1)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	var x := UI.button("×", "ghost", 32)
	x.custom_minimum_size = Vector2(52, 52)
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	x.pressed.connect(func(): app.tray_remove(index); app.goto("home"))
	top.add_child(x)
	v.add_child(top)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	var kcal_txt: String = Metrics.format_num(f.kcal, 0) if f.has_kcal() else "–"
	var h := UI.hbox(8)
	var bignum := UI.label(kcal_txt, 68, "text", 2)
	h.add_child(bignum)
	var u := UI.micro("kcal/100 g")
	u.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(u)
	v.add_child(h)
	card.add_child(v)
	return card
