extends RefCounted
class_name ResultScreen

static func build(app: App) -> Control:
	var content := Shell.content_col()
	if app.last_food == null and app.last_error == "":
		content.add_child(_loading())
	elif app.last_error != "":
		content.add_child(_error(app))
	else:
		_build_food(app, content)
	return Shell.page(app, "", content, true)

static func _loading() -> Control:
	var c := UI.card(40)
	var v := UI.vbox(18)
	v.add_child(UI.label(I18n.t("loading"), UI.FS_TITLE, "text", 1))
	v.add_child(UI.label(str("…"), UI.FS_BODY, "muted"))
	c.add_child(v)
	return c

static func _error(app: App) -> Control:
	var c := UI.card(40)
	var v := UI.vbox(22)
	var msg := I18n.t("error_net")
	match app.last_error:
		"rate": msg = I18n.t("error_rate")
		"notfound": msg = I18n.t("not_found")
	v.add_child(UI.label(msg, UI.FS_TITLE, "text", 1))
	v.add_child(UI.label(I18n.t("barcode") + ": " + app.last_barcode, UI.FS_SMALL, "muted"))
	var row := UI.hbox(18)
	var retry := UI.button(I18n.t("retry"), "primary")
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(func(): app.open_barcode(app.last_barcode))
	row.add_child(retry)
	var manual := UI.button(I18n.t("unpackaged"), "ghost")
	manual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	manual.pressed.connect(func(): app.goto("generics"))
	row.add_child(manual)
	v.add_child(row)
	c.add_child(v)
	return c

static func _build_food(app: App, content: VBoxContainer) -> void:
	var f: Food = app.last_food
	var ev := Metrics.evaluate(f)

	# Kopf: Bild + Name
	var head := UI.hbox(24)
	if f.image_url != "":
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(200, 200)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(tex)
		_load_image(tex, f.image_url)
	var hv := UI.vbox(6)
	var nm := UI.label(f.display_name(I18n.lang), UI.FS_TITLE, "text", 2)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(nm)
	var sub := []
	if f.brand != "":
		sub.append(f.brand)
	if f.quantity != "":
		sub.append(f.quantity)
	if not sub.is_empty():
		hv.add_child(UI.label(" · ".join(sub), UI.FS_BODY, "muted"))
	if f.source == "generic":
		hv.add_child(UI.micro(I18n.t("unpackaged")))
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hv)
	content.add_child(head)

	content.add_child(_card_donut(ev))
	content.add_child(_card_density(ev))
	content.add_child(_card_protein(ev))
	content.add_child(_card_satiety(ev))
	var extra := _card_extra(f)
	if extra != null:
		content.add_child(extra)

	# Aktionen
	var actions := UI.hbox(18)
	var in_tray := app.tray_has(f)
	var add := UI.button(I18n.t("add_to_tray") + ("  ✓" if in_tray else ""), "primary")
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add.disabled = in_tray or app.tray.size() >= App.MAX_TRAY
	add.pressed.connect(func():
		if app.tray_add(f):
			app.goto("home")
		else:
			add.text = I18n.t("full"))
	actions.add_child(add)
	var disc := UI.button(I18n.t("discard"), "ghost")
	disc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	disc.pressed.connect(func(): app.goto("home"))
	actions.add_child(disc)
	content.add_child(actions)

# --- Karten -----------------------------------------------------------------

static func _card_title(key: String) -> Control:
	return UI.micro(I18n.t(key))

static func _card_donut(ev: Dictionary) -> Control:
	var card := UI.card(30)
	var v := UI.vbox(22)
	v.add_child(_card_title("chart_donut"))
	if not ev.split_ok:
		v.add_child(UI.label("–", UI.FS_BIG, "faint", 2))
		v.add_child(UI.label(I18n.t("product") + ": unvollständig", UI.FS_SMALL, "muted"))
		card.add_child(v)
		return card
	var row := UI.hbox(30)
	var donut := MacroDonut.new()
	donut.custom_minimum_size = Vector2(320, 320)
	donut.set_split(ev.split)
	row.add_child(donut)
	var legend := UI.vbox(16)
	legend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	legend.add_child(_legend_row("protein", ev.split))
	legend.add_child(_legend_row("carbs", ev.split))
	legend.add_child(_legend_row("fat", ev.split))
	row.add_child(legend)
	v.add_child(row)
	if ev.split.get("mismatch", false):
		v.add_child(UI.label(I18n.t("macro_estimated"), UI.FS_MICRO, "faint"))
	card.add_child(v)
	return card

static func _legend_row(key: String, split: Dictionary) -> Control:
	var row := UI.hbox(16)
	var color: String = "protein"
	match key:
		"carbs": color = "carbs"
		"fat": color = "fat"
	var sw := ColorRect.new()
	sw.color = UI.c(color)
	sw.custom_minimum_size = Vector2(24, 24)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sw)
	var name := UI.label(I18n.t(key), UI.FS_BODY, "text")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var pct := str(roundi(float(split.get(key, 0.0)) * 100.0)) + " %"
	row.add_child(UI.label(pct, UI.FS_BODY, "text", 2))
	return row

static func _card_density(ev: Dictionary) -> Control:
	var card := UI.card(30)
	var v := UI.vbox(20)
	v.add_child(_card_title("chart_density"))
	if not ev.density_ok:
		v.add_child(UI.label("–", UI.FS_BIG, "faint", 2))
		card.add_child(v)
		return card
	var row := UI.hbox(24)
	var n := UI.big_number(Metrics.format_num(ev.density, 0), "text")
	row.add_child(n)
	var u := UI.vbox(0)
	u.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	u.add_child(UI.label("kcal/100 g", UI.FS_SMALL, "muted"))
	u.add_child(UI.label(Metrics.density_label(ev.density_band, I18n.lang), UI.FS_BODY, "accent_ink", 1))
	row.add_child(u)
	v.add_child(row)
	var scale := DensityScale.new()
	scale.set_kcal(ev.density)
	v.add_child(scale)
	card.add_child(v)
	return card

static func _card_protein(ev: Dictionary) -> Control:
	var card := UI.card(30)
	var v := UI.vbox(20)
	v.add_child(_card_title("chart_protein"))
	if not ev.protein_density_ok:
		v.add_child(UI.label("–", UI.FS_BIG, "faint", 2))
		card.add_child(v)
		return card
	var row := UI.hbox(20)
	row.add_child(UI.big_number(Metrics.format_num(ev.protein_density, 1), "text"))
	var u := UI.vbox(0)
	u.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	u.add_child(UI.label("g Eiweiß", UI.FS_SMALL, "muted"))
	u.add_child(UI.label("pro 100 kcal", UI.FS_SMALL, "muted"))
	row.add_child(u)
	v.add_child(row)
	var bar := MeterBar.new()
	bar.set_value(ev.protein_density, 25.0, "protein")
	v.add_child(bar)
	card.add_child(v)
	return card

static func _card_satiety(ev: Dictionary) -> Control:
	var card := UI.card(30)
	var v := UI.vbox(20)
	v.add_child(_card_title("chart_satiety"))
	if not ev.fullness_ok:
		v.add_child(UI.label("–", UI.FS_BIG, "faint", 2))
		card.add_child(v)
		return card
	var score: int = ev.fullness.get("score", 0)
	var row := UI.hbox(20)
	row.add_child(UI.big_number(str(score), "text"))
	var u := UI.vbox(0)
	u.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	u.add_child(UI.label("von 100", UI.FS_SMALL, "muted"))
	u.add_child(UI.label(I18n.t("estimate"), UI.FS_SMALL, "accent_ink", 1))
	row.add_child(u)
	v.add_child(row)
	var bar := MeterBar.new()
	var ck := "good" if score >= 60 else ("warn" if score >= 35 else "bad")
	bar.set_value(float(score), 100.0, ck)
	v.add_child(bar)
	if ev.fullness.get("no_fiber", false):
		v.add_child(UI.label(I18n.t("estimate_nofiber"), UI.FS_MICRO, "faint"))
	card.add_child(v)
	return card

static func _card_extra(f: Food) -> Control:
	var rows := []
	if f.has(f.fiber): rows.append(["fiber", f.fiber, "g"])
	if f.has(f.sugars): rows.append(["sugar", f.sugars, "g"])
	if f.has(f.saturated): rows.append(["sat_fat", f.saturated, "g"])
	if f.has(f.salt): rows.append(["salt", f.salt, "g"])
	if rows.is_empty():
		return null
	var card := UI.card(30)
	var v := UI.vbox(16)
	v.add_child(_card_title("more_numbers"))
	for r in rows:
		var row := UI.hbox(0)
		row.add_child(UI.label(I18n.t(r[0]), UI.FS_BODY, "muted"))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
		row.add_child(UI.label(Metrics.format_num(r[1]) + " " + r[2], UI.FS_BODY, "text", 1))
		v.add_child(row)
	card.add_child(v)
	return card

# --- Bild laden -------------------------------------------------------------

static func _load_image(tr: TextureRect, url: String) -> void:
	var req := HTTPRequest.new()
	tr.add_child(req)
	req.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var img := Image.new()
			var ok := false
			if url.get_extension().to_lower() in ["jpg", "jpeg"]:
				ok = img.load_jpg_from_buffer(body) == OK
			else:
				ok = img.load_png_from_buffer(body) == OK
				if not ok:
					ok = img.load_jpg_from_buffer(body) == OK
			if ok:
				tr.texture = ImageTexture.create_from_image(img)
		req.queue_free())
	req.request(url, PackedStringArray(["User-Agent: MacroLens/0.1 (alexander.riedel@eyedea3d.com)"]))
