extends SceneTree

## Tests: Layout-Modell, Bausteine, Mengen, Saettigung 2.0, Editor (Drag & Drop).
## Lauf:  godot --headless --path . --script res://tests/test_layout.gd

var passed := 0
var failed := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", msg)

func near(a: float, b: float, eps: float, msg: String) -> void:
	check(absf(a - b) <= eps, msg + "  (ist %s, soll %s)" % [a, b])

class MemStore extends Store:
	func save_settings() -> void:
		pass

func _food(kcal: float, p: float, c: float, f: float, fib: float = -1.0, sug: float = -1.0) -> Food:
	var x := Food.new()
	x.kcal = kcal
	x.protein = p
	x.carbs = c
	x.fat = f
	x.fiber = fib
	x.sugars = sug
	return x

func _initialize() -> void:
	Anim.enabled = false
	_test_amounts()
	_test_layout_model()
	_test_presets()
	_test_blocks()
	_test_satiety()
	await _test_editor()
	print("PASS: %d  FAIL: %d" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _test_amounts() -> void:
	var a := Food.parse_amount("500 g")
	check(a["ok"] and a["unit"] == "g" and is_equal_approx(a["value"], 500.0), "500 g")
	check(is_equal_approx(Food.parse_amount("2 x 125 g")["value"], 250.0), "2 x 125 g -> 250 g")
	var l := Food.parse_amount("0,5 l")
	check(l["unit"] == "ml" and is_equal_approx(l["value"], 500.0), "0,5 l -> 500 ml")
	check(is_equal_approx(Food.parse_amount("6 x 0,33 L")["value"], 1980.0), "6 x 0,33 L -> 1980 ml")
	check(is_equal_approx(Food.parse_amount("1 Portion (30 g)")["value"], 30.0), "1 Portion (30 g) -> 30 g (nicht 1)")
	check(is_equal_approx(Food.parse_amount("1kg")["value"], 1000.0), "1kg")
	check(is_equal_approx(Food.parse_amount("33 cl")["value"], 330.0), "33 cl -> 330 ml")
	check(not Food.parse_amount("eine Packung")["ok"], "ohne Einheit -> nicht ok")
	check(not Food.parse_amount("")["ok"], "leer -> nicht ok")
	var d := _food(42, 0, 10.6, 0, -1, 10.6)
	d.quantity = "1,5 l"
	check(d.is_drink(), "Getraenk erkannt (ml)")

func _test_layout_model() -> void:
	var def := Layout.default_layout()
	check(Layout.ids(def) == ["macros", "density", "protein", "satiety"], "Standard = bisherige vier Grafiken")
	var s := Layout.sanitize([{"id": "macros"}, {"id": "nope"}, {"id": "macros"}, "sugar",
		{"id": "fiber"}, {"id": "salt"}, {"id": "satfat"}, {"id": "fatq"}])
	check(Layout.ids(s) == ["macros", "sugar", "fiber", "salt", "satfat"], "unbekannt/doppelt raus, max 5")
	check(Layout.ids(Layout.sanitize([])) == Layout.ids(def), "leer -> Standard")
	check(Layout.ids(Layout.sanitize("kaputt")) == Layout.ids(def), "Unsinn -> Standard")
	var opt := Layout.sanitize([{"id": "density", "options": {"basis": "galaxie", "x": 1}}])
	check(opt[0]["options"]["basis"] == "100g" and not opt[0]["options"].has("x"), "Optionen bereinigt")
	var a := Layout.add(def, "sugar", 1)
	check(Layout.ids(a) == ["macros", "sugar", "density", "protein", "satiety"], "einfuegen an Position")
	check(Layout.ids(Layout.add(a, "fiber")) == Layout.ids(a), "voll -> nichts angefuegt")
	check(Layout.ids(Layout.add(def, "satiety", 0))[0] == "satiety", "vorhandenes -> verschieben")
	check(Layout.ids(Layout.move(def, 0, 3)) == ["density", "protein", "satiety", "macros"], "verschieben")
	check(Layout.ids(Layout.remove(def, 1)) == ["macros", "protein", "satiety"], "entfernen")
	check(Layout.remove([{"id": "macros"}], 0).size() == 1, "letzter Baustein bleibt")
	var o := Layout.set_option(def, 1, "basis", "pack")
	check(o[1]["options"]["basis"] == "pack", "Option setzen")
	check(Layout.set_option(def, 1, "basis", "quatsch")[1]["options"]["basis"] == "100g", "ungueltige Option -> Standard")

func _test_presets() -> void:
	var st := MemStore.new()
	check(Layout.builtin_presets().size() == 5, "5 fertige Vorlagen")
	for p in Layout.builtin_presets():
		check(p["layout"].size() >= 1 and p["layout"].size() <= Blocks.MAX_ACTIVE, "Vorlage gueltig: " + p["key"])
	check(Layout.matching_preset(st, Layout.default_layout()) == I18n.t("preset_standard"), "Standard erkannt")
	var mine := Layout.add(Layout.default_layout(), "fiber")
	check(Layout.matching_preset(st, mine) == "", "eigene Zusammenstellung")
	check(Layout.save_user_preset(st, "Wocheneinkauf", mine), "eigene Vorlage speichern")
	check(Layout.matching_preset(st, mine) == "Wocheneinkauf", "eigene Vorlage erkannt")
	check(Layout.save_user_preset(st, "wocheneinkauf", Layout.default_layout()), "gleicher Name ersetzt")
	check(Layout.user_presets(st).size() == 1, "kein Duplikat")
	check(not Layout.save_user_preset(st, "   ", mine), "leerer Name abgelehnt")
	Layout.delete_user_preset(st, "wocheneinkauf")
	check(Layout.user_presets(st).is_empty(), "loeschen")

func _test_blocks() -> void:
	check(Blocks.ids().size() == 10, "10 Bausteine")
	for id in Blocks.ids():
		check(Blocks.block_name(id) != "" and not Blocks.desc(id).begins_with("blkd_"), "Texte vorhanden: " + id)
	var m := _food(389, 13.5, 66, 6.9, 10.6, 1.0)
	m.quantity = "500 g"
	m.serving_text = "1 Portion (45 g)"
	var ctx := {"ml_as_g": true}
	near(Blocks.evaluate("density", m, {"basis": "pack"}, ctx)["value"], 1945.0, 0.1, "kcal pro Packung")
	near(Blocks.evaluate("density", m, {"basis": "portion"}, ctx)["value"], 175.05, 0.1, "kcal pro Portion")
	check(Blocks.evaluate("density", m, {"basis": "pack"}, ctx)["unit"].contains(I18n.t("u_pack")), "Einheit Packung")
	var g := _food(89, 1.1, 22.8, 0.3, 2.6, 12.2)   # Generikum: keine Portion/Packung
	check(not Blocks.evaluate("density", g, {"basis": "pack"}, ctx)["ok"], "ohne Packungsangabe -> keine Zahl")
	# Getraenk: ml -> g nur mit Einstellung
	var cola := _food(42, 0, 10.6, 0, -1, 10.6)
	cola.quantity = "1,5 l"
	near(Blocks.evaluate("sugar", cola, {"mode": "g", "basis": "pack"}, ctx)["value"], 159.0, 0.1, "Zucker pro 1,5-l-Flasche")
	check(not Blocks.evaluate("sugar", cola, {"mode": "g", "basis": "pack"}, {"ml_as_g": false})["ok"], "ml-Umrechnung aus -> keine Zahl")
	check(Blocks.evaluate("density", cola, {}, ctx)["unit"].contains("100 ml"), "Getraenk: pro 100 ml")
	# Prozent-Modi
	near(Blocks.evaluate("sugar", g, {"mode": "pct_carbs"}, ctx)["value"], 12.2 / 22.8 * 100.0, 0.05, "Zucker % der KH")
	near(Blocks.evaluate("sugar", g, {"mode": "pct_energy"}, ctx)["value"], 12.2 * 4.0 / 89.0 * 100.0, 0.05, "Zucker % Energie")
	# Ampel-Schwellen (FSA)
	check(Metrics.fsa_level("sugar", 4.0) == 0 and Metrics.fsa_level("sugar", 10.0) == 1 and Metrics.fsa_level("sugar", 30.0) == 2, "FSA Zucker")
	check(Metrics.fsa_level("sugar", 10.6, true) == 1 and Metrics.fsa_level("sugar", 12.0, true) == 2, "FSA Getraenke strenger")
	check(Metrics.fsa_level("salt", -1.0) == -1, "unbekannt -> -1")
	# BEST und Skala
	var ds := [{"ok": true, "value": 3.0, "rank": 3.0, "good_high": false},
		{"ok": true, "value": 1.0, "rank": 1.0, "good_high": false}, {"ok": false}]
	check(Blocks.best_index(ds) == 1, "BEST = niedrigster Wert")
	check(Blocks.best_index([ds[0], ds[2]]) == -1, "nur ein gueltiger Wert -> kein BEST")
	near(Blocks.row_max([{"ok": true, "value": 1945.0, "bar_max": 0.0}]), 2500.0, 0.1, "variable Skala: runde Grenze")
	# Makro-Donut mit Zucker
	var split: Dictionary = Blocks.evaluate("macros", g, {"sugar": true}, ctx)["split"]
	near(float(split["sugar"]) + float(split["starch"]), float(split["carbs"]), 0.0001, "Zucker + Rest = KH (keine Doppelzaehlung)")
	# Fettqualitaet
	var oil := _food(884, 0, 0, 100)
	oil.saturated = 14.0
	near(Blocks.evaluate("fatq", oil, {}, ctx)["value"], 14.0, 0.01, "Rapsoel 14 % gesaettigt")
	check(not Blocks.evaluate("fatq", g, {}, ctx)["ok"], "kaum Fett -> keine Aufteilung")
	# Ampel-Zeilen nach Optionen
	var amp := Blocks.evaluate("ampel", m, {"fiber": true, "protein": true}, ctx)
	check(amp["rows"].size() == 6, "Ampel mit Ballaststoffen und Eiweiss = 6 Zeilen")
	check(Blocks.evaluate("ampel", m, {}, ctx)["rows"].size() == 4, "Ampel Standard = 4 Zeilen")

func _test_satiety() -> void:
	var skyr := _food(63, 11, 4, 0.2, 0, 4)
	var chicken := _food(165, 31, 0, 3.6, 0, 0)
	var potato := _food(87, 1.9, 20, 0.1, 1.8, 0.9)
	var apple := _food(52, 0.3, 13.8, 0.2, 2.4, 10.4)
	var oats := _food(389, 13.5, 66, 6.9, 10.6, 1.0)
	var croissant := _food(406, 8, 46, 21, 2.6, 11)
	var choc := _food(546, 4.9, 61, 31, 3.4, 48)
	var cola := _food(42, 0, 10.6, 0, 0, 10.6)
	cola.quantity = "1 l"
	var milk := _food(64, 3.4, 4.8, 3.6, 0, 4.8)
	milk.quantity = "1 l"
	var s := func(f: Food) -> int: return int(Metrics.satiety(f)["score"])
	check(s.call(skyr) > s.call(oats), "Skyr > Haferflocken (Energiedichte)")
	check(s.call(apple) > s.call(croissant), "Apfel > Croissant (Holt)")
	check(s.call(potato) > s.call(croissant), "Kartoffel > Croissant (Holt)")
	check(s.call(chicken) > s.call(choc), "Haehnchen > Schokolade")
	check(s.call(milk) > s.call(cola) + 10, "Milch deutlich > Cola (fluessiger Zucker)")
	check(s.call(cola) < s.call(apple), "Cola < Apfel")
	check(s.call(choc) < 35, "Schokolade niedrig")
	# Ballaststoffe zaehlen: gleiches Produkt mit mehr Ballaststoffen ist saettigender
	check(s.call(_food(250, 8, 40, 5, 8, 2)) > s.call(_food(250, 8, 40, 5, 1, 2)), "mehr Ballaststoffe -> satter")
	# FF-Grenzen: kcal mind. 30
	var water := _food(10, 0, 2, 0, 0, 2)
	near(float(Metrics.fullness_factor(water)["raw"]), clampf(41.7 / pow(30.0, 0.7) + 0.617, 0.5, 5.0), 0.001, "FF: kcal mind. 30")
	check(Metrics.satiety(_food(-1, 1, 1, 1)).is_empty(), "ohne kcal -> keine Schaetzung")

func _test_editor() -> void:
	var app := App.new()
	root.add_child(app)
	app.position = Vector2.ZERO
	app.size = Vector2(1080, 1920)   # headless: echte Basisgroesse, sonst kollabiert das Layout
	await process_frame
	var saved_layout = app.store.settings.get(Layout.KEY, null)
	app.tray.clear()
	app.current = null
	app.set_layout(Layout.default_layout())
	app.goto("layout")
	for i in 4:
		await process_frame
	var ed: LayoutEditor = null
	for c in app.get_children():
		if c is LayoutEditor:
			ed = c
	check(ed != null, "Editor geoeffnet")
	if ed == null:
		return
	check(ed._items.size() == 4, "4 Bausteine in der Vorschau")

	# Karte "Zucker" aus dem Dock auf den ersten Baustein ziehen -> Position 0
	var from: Vector2 = (ed._dock_cards["sugar"] as Control).get_global_rect().get_center()
	var to: Vector2 = (ed._items[0] as Control).get_global_rect().get_center() + Vector2(0, -10)
	_drag(ed, from, to)
	check(app.layout.size() == 5 and app.layout[0]["id"] == "sugar", "Dock -> Position 0 eingerastet")
	check(app.store.settings[Layout.KEY][0]["id"] == "sugar", "sofort gespeichert")
	for i in 2:
		await process_frame

	# Voll: weitere Karte wird abgelehnt
	from = (ed._dock_cards["salt"] as Control).get_global_rect().get_center()
	to = (ed._items[2] as Control).get_global_rect().get_center()
	_drag(ed, from, to)
	check(app.layout.size() == 5 and not Layout.contains(app.layout, "salt"), "bei 5 Bausteinen kein sechster")
	for i in 2:
		await process_frame

	# Baustein 0 (Zucker) ans Ende verschieben
	from = (ed._items[0] as Control).get_global_rect().get_center()
	to = (ed._items[4] as Control).get_global_rect().end + Vector2(-20, -4)
	_drag(ed, from, to)
	check(app.layout[4]["id"] == "sugar", "umsortiert ans Ende")
	for i in 2:
		await process_frame

	# Baustein ins Dock ziehen = entfernen
	from = (ed._items[4] as Control).get_global_rect().get_center()
	to = ed._dock_panel.get_global_rect().get_center()
	_drag(ed, from, to)
	check(app.layout.size() == 4 and not Layout.contains(app.layout, "sugar"), "ins Dock gezogen = entfernt")
	for i in 2:
		await process_frame

	# Tippen auf Baustein -> Einstellungen; Option setzen; Zurueck schliesst die Ebene
	var tap: Vector2 = (ed._items[1] as Control).get_global_rect().get_center()
	_press(ed, tap, true)
	_press(ed, tap, false)
	check(ed._overlay != null and ed._sheet_index == 1, "Tippen oeffnet Einstellungen")
	ed._set_option("basis", "pack")
	check(app.layout[1]["options"]["basis"] == "pack", "Option im Sheet gesetzt + gespeichert")
	check(ed.handle_back() and ed._overlay == null, "Zurueck schliesst zuerst das Sheet")

	# Tippen auf Dock-Karte = anhaengen
	tap = (ed._dock_cards["fiber"] as Control).get_global_rect().get_center()
	_press(ed, tap, true)
	_press(ed, tap, false)
	check(Layout.ids(app.layout).back() == "fiber", "Tippen im Dock haengt an")

	# Aufraeumen (Nutzerprofil wie vorher)
	if saved_layout == null:
		app.store.settings.erase(Layout.KEY)
	else:
		app.store.settings[Layout.KEY] = saved_layout
	app.store.save_settings()

func _press(ed: LayoutEditor, pos: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = pos
	e.global_position = pos
	ed._input(e)

func _drag(ed: LayoutEditor, from: Vector2, to: Vector2) -> void:
	_press(ed, from, true)
	for i in range(1, 9):
		var m := InputEventMouseMotion.new()
		m.position = from.lerp(to, i / 8.0)
		m.global_position = m.position
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		ed._input(m)
	_press(ed, to, false)
