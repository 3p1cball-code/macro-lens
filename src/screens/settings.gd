extends RefCounted
class_name SettingsScreen

static func build(app: App) -> Control:
	var content := Shell.content_col()
	var root_c := Shell.page(app, I18n.t("settings_title"), content, true)

	# Hauptseite zusammenstellen
	var home := UI.card(30)
	var hv := UI.vbox(16)
	hv.add_child(UI.micro(I18n.t("set_home")))
	var preset := Layout.matching_preset(app.store, app.layout)
	var summary := (preset if preset != "" else I18n.t("editor_custom")) \
		+ "  ·  " + str(app.layout.size()) + " / " + str(Blocks.MAX_ACTIVE)
	hv.add_child(UI.label(summary, UI.FS_BODY, "text", 1))
	var names: PackedStringArray = []
	for e in app.layout:
		names.append(Blocks.block_name(e["id"]))
	var nl := UI.label(" · ".join(names), UI.FS_SMALL, "muted")
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(nl)
	var eb := UI.button(I18n.t("set_home_btn") + "  ›", "primary")
	eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eb.pressed.connect(func(): app.goto("layout"))
	hv.add_child(eb)
	var hh := UI.label(I18n.t("set_home_hint"), UI.FS_MICRO, "faint")
	hh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(hh)
	home.add_child(hv)
	content.add_child(home)

	# Allergene & Unvertraeglichkeiten
	var al := UI.card(30)
	var av := UI.vbox(16)
	av.add_child(UI.micro(I18n.t("alerts_title")))
	var sel := app.alert_ids()
	var a_names: PackedStringArray = []
	var i_names: PackedStringArray = []
	for id in sel:
		if Allergens.kind_of(id) == Allergens.ALLERGY:
			a_names.append(Allergens.short_name(id, I18n.lang))
		else:
			i_names.append(Allergens.short_name(id, I18n.lang))
	if sel.is_empty():
		av.add_child(UI.label(I18n.t("alerts_none"), UI.FS_BODY, "text", 1))
		var hint := UI.label(I18n.t("alerts_settings_hint"), UI.FS_SMALL, "muted")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		av.add_child(hint)
	else:
		if not a_names.is_empty():
			var l := UI.label(I18n.t("alerts_allergies") + ": " + ", ".join(a_names), UI.FS_SMALL, "bad", 1)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			av.add_child(l)
		if not i_names.is_empty():
			var l2 := UI.label(I18n.t("alerts_intol") + ": " + ", ".join(i_names), UI.FS_SMALL, "intol", 1)
			l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			av.add_child(l2)
	var ab2 := UI.button(I18n.t("alerts_btn") + "  ›", "ghost")
	ab2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ab2.pressed.connect(func(): app.goto("alerts"))
	av.add_child(ab2)
	al.add_child(av)
	content.add_child(al)

	# Optionen (Schalter)
	var opts := UI.card(30)
	var ov := UI.vbox(22)
	ov.add_child(UI.micro(I18n.t("set_options")))
	ov.add_child(UI.switch_row(I18n.t("set_quit"), I18n.t("set_quit_hint"), app.show_quit(),
		func(on: bool): app.set_show_quit(on)))
	ov.add_child(UI.hline())
	ov.add_child(UI.switch_row(I18n.t("set_ml"), I18n.t("set_ml_hint"), app.ml_as_g(),
		func(on: bool): app.set_ml_as_g(on)))
	opts.add_child(ov)
	content.add_child(opts)

	content.add_child(_section(I18n.t("theme"), [
		[I18n.t("theme_dark"), func(): app.set_dark_mode(true), UI.dark],
		[I18n.t("theme_light"), func(): app.set_dark_mode(false), not UI.dark],
	]))
	content.add_child(_section(I18n.t("language"), [
		["Deutsch", func(): app.set_lang("de"), I18n.lang == "de"],
		["English", func(): app.set_lang("en"), I18n.lang == "en"],
	]))

	var about := UI.card(30)
	var ab := UI.button(I18n.t("about_btn") + "  ›", "ghost")
	ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ab.pressed.connect(func(): app.goto("about"))
	about.add_child(ab)
	content.add_child(about)
	return root_c

static func _section(title: String, options: Array) -> Control:
	var card := UI.card(30)
	var v := UI.vbox(16)
	v.add_child(UI.micro(title))
	for o in options:
		var active: bool = o[2]
		var row := UI.hbox(14)
		var b := UI.button(o[0] + ("  ✓" if active else ""), "primary" if active else "ghost")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(o[1])
		row.add_child(b)
		v.add_child(row)
	card.add_child(v)
	return card
