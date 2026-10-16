extends SceneTree

## Wischgesten auf dem Live-Screen mit synthetischen Maus-/Touch-Events.
## Lauf:  godot --headless --path . --script res://tests/test_gesture.gd

var passed := 0
var failed := 0
var app: App

func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", msg)

func _food(code: String, nm: String) -> Food:
	var f := Food.new()
	f.barcode = code
	f.name = nm
	f.kcal = 120.0
	f.protein = 8.0
	f.carbs = 14.0
	f.fat = 3.0
	f.source = "openfoodfacts"
	return f

func _live() -> LiveScreen:
	return app._current_screen as LiveScreen

func _settle(t: float = 0.0) -> void:
	await process_frame
	await process_frame
	if t > 0.0:
		await create_timer(t).timeout
	await process_frame

## Wischen auf Spalte col um dy (in Schritten), optional als schneller Flick.
func _swipe(col: int, dy: float, steps: int = 8, dx: float = 0.0, fast: bool = false) -> void:
	var ls := _live()
	var r := ls._col_rect(col)
	var p0 := r.get_center()
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = true
	b.position = p0
	ls._input(b)
	for k in range(1, steps + 1):
		var m := InputEventMouseMotion.new()
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		m.position = p0 + Vector2(dx, dy) * (float(k) / steps)
		m.velocity = Vector2(0, dy * (20.0 if fast else 2.0))
		ls._input(m)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = p0 + Vector2(dx, dy)
	ls._input(u)

func _initialize() -> void:
	Anim.enabled = false
	app = App.new()
	root.add_child(app)
	await _settle()
	var saved_learned: Dictionary = {
		"pin": app.store.settings.get("learned_pin", null),
		"unpin": app.store.settings.get("learned_unpin", null)}
	app.tray.clear()
	app.current = _food("4000000000201", "Aktuell")
	app.tray.append(_food("4000000000202", "Gepinnt A"))
	app.refresh_live()
	await _settle()
	check(_live()._cols.size() == 2, "zwei Spalten (1 gepinnt + aktuell)")

	# Kurzes Wischen nach unten -> zurueckfedern, nichts passiert
	_swipe(1, 80.0)
	await _settle(0.4)
	check(app.tray.size() == 1 and app.current != null, "zu kurz gewischt -> keine Aktion")
	check(is_equal_approx((_live()._col_nodes[1][0] as Slide).offset, 0.0), "Spalte federt zurueck")

	# Seitlich wischen -> keine Geste
	_swipe(1, 60.0, 8, 260.0)
	await _settle(0.2)
	check(app.tray.size() == 1 and app.current != null, "seitliche Bewegung -> keine Geste")

	# Aktuelle Spalte nach unten wischen -> gepinnt
	_swipe(1, 230.0)
	await _settle()
	check(app.tray.size() == 2, "nach unten gewischt -> gepinnt")
	check(app.current == null, "aktuelles Produkt ist jetzt gepinnt")
	check(app.learned("pin"), "Pin-Geste gelernt")
	await _settle(0.6)
	check(is_equal_approx((_live()._col_nodes[1][0] as Slide).offset, 0.0), "gepinnte Spalte rastet ein")

	# Gepinnte Spalte nach unten -> nichts (nur Widerstand)
	_swipe(0, 260.0)
	await _settle(0.4)
	check(app.tray.size() == 2, "gepinnte Spalte nach unten -> keine Aktion")

	# Gepinnte Spalte nach oben -> entfernt
	var gone: Food = app.tray[0]
	_swipe(0, -230.0)
	await _settle(0.4)
	check(app.tray.size() == 1 and not app.tray.has(gone), "nach oben gewischt -> entfernt")
	check(app.learned("unpin"), "Entfernen-Geste gelernt")

	# Entfernter Barcode wird nicht sofort wieder erkannt
	app.on_scanned(gone.barcode)
	await _settle()
	check(app.current == null, "frisch entfernt -> kurz gesperrt")

	# Flick: kurz, aber schnell nach oben -> entfernt
	app.current = _food("4000000000203", "Neu")
	app.refresh_live()
	await _settle()
	_swipe(1, -90.0, 3, 0.0, true)
	await _settle(0.4)
	check(app.current == null and app.tray.size() == 1, "schneller Flick nach oben verwirft aktuelles Produkt")

	# Aufraeumen
	app.tray.clear()
	app._save_tray()
	for k in ["pin", "unpin"]:
		if saved_learned[k] == null:
			app.store.settings.erase("learned_" + k)
		else:
			app.store.settings["learned_" + k] = saved_learned[k]
	app.store.save_settings()
	for k in app.store.cache.keys():
		if str(k).begins_with("40000000002"):
			app.store.cache.erase(k)
	app.store.save_cache()
	print("PASS: %d  FAIL: %d" % [passed, failed])
	quit(1 if failed > 0 else 0)
