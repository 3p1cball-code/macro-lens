extends RefCounted
class_name AboutScreen

## Ueber Macro Lens: Foto, worum es geht, Bedienung, alle Bausteine (dient
## zugleich als Hilfe), Hinweise zu Schaetzungen/Umrechnungen, Privatsphaere,
## Kontakt (Mail antippbar), Version und Datenquellen.

const PORTRAIT := "res://assets/about/portrait.jpg"
const MAIL := "macro-lens@eyedea3d.com"
const REPO := "https://github.com/3p1cball-code/macro-lens"

static func build(app: App) -> Control:
	var content := Shell.content_col(30)
	var root_c := Shell.page(app, I18n.t("about"), content, true)

	content.add_child(_portrait())

	# Einstieg
	var intro := UI.vbox(18)
	var title := UI.label(I18n.t("about_text"), UI.FS_TITLE, "text", 2)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_child(title)
	intro.add_child(_para(I18n.t("about_intro"), UI.FS_BODY, "text"))
	intro.add_child(_para(I18n.t("about_me"), UI.FS_BODY, "muted"))
	content.add_child(intro)

	# So funktioniert's
	var how := _section(I18n.t("sec_how"))
	for i in [1, 2, 3]:
		how.add_child(_step(i, I18n.t("how_%d_t" % i), I18n.t("how_%d_b" % i)))
	content.add_child(_card(how))

	# Bausteine = Hilfe
	var blocks := _section(I18n.t("sec_blocks"))
	var first := true
	for id in Blocks.ids():
		if not first:
			blocks.add_child(UI.hline())
		first = false
		var v := UI.vbox(4)
		v.add_child(UI.label(Blocks.block_name(id), UI.FS_BODY, "text", 1))
		v.add_child(_para(Blocks.desc(id), UI.FS_SMALL, "muted"))
		blocks.add_child(v)
	content.add_child(_card(blocks))

	# Gut zu wissen
	var good := _section(I18n.t("sec_good"))
	for key in ["good_satiety", "good_ml", "good_fsa", "good_nonfood"]:
		good.add_child(_bullet(I18n.t(key)))
	content.add_child(_card(good))

	# Privatsphaere
	var priv := _section(I18n.t("sec_privacy"))
	priv.add_child(_para(I18n.t("privacy_body"), UI.FS_SMALL, "muted"))
	content.add_child(_card(priv))

	# Kontakt
	var contact := _section(I18n.t("sec_contact"))
	contact.add_child(_para(I18n.t("contact_body"), UI.FS_BODY, "text"))
	var mail := UI.button(MAIL, "accent")
	mail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mail.pressed.connect(func(): app.open_url("mailto:" + MAIL + "?subject=Macro%20Lens"))
	contact.add_child(mail)
	var gh := UI.button("GitHub  ›", "ghost", UI.FS_SMALL)
	gh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gh.pressed.connect(func(): app.open_url(REPO))
	contact.add_child(gh)
	content.add_child(_card(contact))

	# Fusszeile
	var foot := UI.vbox(8)
	var ver := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	foot.add_child(UI.label("Macro Lens · v" + ver + " · " + I18n.t("about_license"), UI.FS_MICRO, "faint", 1))
	foot.add_child(_para(I18n.t("attribution_full"), UI.FS_MICRO, "faint"))
	content.add_child(foot)
	return root_c

# --- Bausteine der Seite ----------------------------------------------------

## Foto (schwarzweiss, 4:3) mit duenner Linie und Bildunterschrift.
static func _portrait() -> Control:
	var v := UI.vbox(10)
	if ResourceLoader.exists(PORTRAIT):
		var frame := PanelContainer.new()
		frame.mouse_filter = Control.MOUSE_FILTER_PASS
		var sb := StyleBoxFlat.new()
		sb.bg_color = UI.c("surface2")
		sb.set_border_width_all(1)
		sb.border_color = UI.c("line")
		sb.set_corner_radius_all(4)
		frame.add_theme_stylebox_override("panel", sb)
		var tex := TextureRect.new()
		tex.texture = load(PORTRAIT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tex.custom_minimum_size = Vector2(0, 700)
		tex.clip_contents = true
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tex)
		v.add_child(frame)
	v.add_child(UI.micro(I18n.t("about_caption"), "faint"))
	return v

static func _card(inner: Control) -> Control:
	var c := UI.card(34)
	c.add_child(inner)
	return c

static func _section(title: String) -> VBoxContainer:
	var v := UI.vbox(20)
	v.add_child(UI.micro(title, "accent_ink"))
	return v

static func _para(text: String, size: int, color_key: String) -> Label:
	var l := UI.label(text, size, color_key)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_constant_override("line_spacing", 6)
	return l

static func _step(n: int, title: String, body: String) -> Control:
	var h := UI.hbox(22)
	var num := UI.label(str(n), UI.FS_TITLE, "accent_ink", 2)
	num.custom_minimum_size = Vector2(52, 0)
	num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(num)
	var v := UI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(title, UI.FS_BODY, "text", 2))
	v.add_child(_para(body, UI.FS_SMALL, "muted"))
	h.add_child(v)
	return h

static func _bullet(text: String) -> Control:
	var h := UI.hbox(18)
	var dot := UI.label("—", UI.FS_SMALL, "accent_ink", 2)
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(dot)
	var p := _para(text, UI.FS_SMALL, "muted")
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(p)
	return h
