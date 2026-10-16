extends RefCounted
class_name AboutScreen

static func build(app: App) -> Control:
	var content := Shell.content_col()
	var root_c := Shell.page(app, I18n.t("about"), content, true)

	var card := UI.card(34)
	var v := UI.vbox(20)
	var title := UI.label(I18n.t("about_text"), UI.FS_TITLE, "text", 2)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var body := UI.label(I18n.t("about_body"), UI.FS_BODY, "muted")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	v.add_child(UI.hline())
	# Die vier Grafiken erklaeren
	v.add_child(_explain("chart_donut", "split"))
	v.add_child(_explain("chart_density", "density"))
	v.add_child(_explain("chart_protein", "protein"))
	v.add_child(_explain("chart_satiety", "satiety"))
	v.add_child(UI.hline())
	v.add_child(UI.label(I18n.t("attribution"), UI.FS_MICRO, "faint"))
	v.add_child(UI.label("Macro Lens · v" + str(ProjectSettings.get_setting("application/config/version", "0.1.0")), UI.FS_MICRO, "faint"))
	v.add_child(UI.label(I18n.t("contact") + " · macro-lens@eyedea3d.com", UI.FS_MICRO, "faint"))
	card.add_child(v)
	content.add_child(card)

	var scanner_hint := UI.label(I18n.t("scan_unavailable") if not Engine.has_singleton("MacroLens") else I18n.t("scan_hint"), UI.FS_SMALL, "muted")
	content.add_child(scanner_hint)
	return root_c

static func _explain(title_key: String, body_key: String) -> Control:
	var row := UI.hbox(16)
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.micro(I18n.t(title_key)))
	var b := UI.label(_body(body_key), UI.FS_SMALL, "muted")
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)
	row.add_child(v)
	return row

static func _body(key: String) -> String:
	var de := {
		"split": "Energieanteile Eiweiß / Kohlenhydrate / Fett.",
		"density": "Wie viel Energie pro 100 g.",
		"protein": "Wie viel Eiweiß pro 100 kcal.",
		"satiety": "Wie füllend pro Kalorie (Schätzung).",
	}
	var en := {
		"split": "Energy shares of protein / carbs / fat.",
		"density": "How much energy per 100 g.",
		"protein": "How much protein per 100 kcal.",
		"satiety": "How filling per calorie (estimate).",
	}
	return (en if I18n.lang == "en" else de).get(key, "")
