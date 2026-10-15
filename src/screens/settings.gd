extends RefCounted
class_name SettingsScreen

static func build(app: App) -> Control:
	var content := Shell.content_col()
	var root_c := Shell.page(app, I18n.t("settings_title"), content, true)

	content.add_child(_section(I18n.t("theme"), [
		[I18n.t("theme_dark"), func(): app.set_dark_mode(true), UI.dark],
		[I18n.t("theme_light"), func(): app.set_dark_mode(false), not UI.dark],
	]))
	content.add_child(_section(I18n.t("language"), [
		["Deutsch", func(): app.set_lang("de"), I18n.lang == "de"],
		["English", func(): app.set_lang("en"), I18n.lang == "en"],
	]))
	content.add_child(UI.label(I18n.t("attribution"), UI.FS_MICRO, "faint"))
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
