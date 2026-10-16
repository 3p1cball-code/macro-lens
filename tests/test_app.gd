extends SceneTree

## Tests des App-Zustands: Verlauf aufloesen, Pinnen, Ablage voll, Dubletten.
## Lauf:  godot --headless --path . --script res://tests/test_app.gd

var passed := 0
var failed := 0

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
	f.kcal = 100.0
	f.protein = 10.0
	f.carbs = 10.0
	f.fat = 2.0
	f.source = "openfoodfacts"
	return f

func _initialize() -> void:
	Anim.enabled = false
	var app := App.new()
	root.add_child(app)
	await process_frame
	app.tray.clear()
	app.current = null

	# Generika aus dem Verlauf aufloesbar
	var g: Food = app.generics.all()[0]
	check(app.resolve_barcode(g.barcode) != null, "Generikum per Barcode aufloesbar")
	check(app.resolve_barcode("generic:gibtsnicht") == null, "unbekanntes Generikum -> null")

	# Gewaehltes OFF-Produkt landet im Cache -> spaeter ohne Netz aufloesbar
	var a := _food("4000000000001", "Testprodukt A")
	app.store.cache.erase(a.barcode)
	app.set_current(a)
	check(app.resolve_barcode(a.barcode) != null, "OFF-Produkt nach Auswahl im Cache")
	check(str(app.store.history[0].get("barcode", "")) == a.barcode, "Auswahl steht oben im Verlauf")

	# Pinnen des aktuellen Produkts ueber die Liste: keine Doppelspalte
	app.add_pinned(a)
	check(app.tray.size() == 1, "gepinnt")
	check(app.current == null, "aktuelles Produkt geleert, wenn es gepinnt wurde")

	# Dublette -> Hinweis statt stiller Nichtreaktion
	app.add_pinned(_food("4000000000001", "Testprodukt A"))
	check(app.tray.size() == 1, "Dublette nicht erneut gepinnt")
	check(app.get_node_or_null("Toast") != null, "Hinweis bei Dublette")

	# Ablage voll -> Hinweis
	for i in range(3):
		app.add_pinned(_food("400000000001%d" % i, "P%d" % i))
	check(app.tray.size() == App.MAX_TRAY, "Ablage voll")
	app.get_node("Toast").name = "ToastSeen"
	app.add_pinned(_food("4000000000099", "zu viel"))
	check(app.tray.size() == App.MAX_TRAY, "nicht ueber MAX_TRAY")
	check(app.get_node_or_null("Toast") != null, "Hinweis bei voller Ablage")

	# Aufraeumen (keine Testdaten im Nutzerprofil hinterlassen)
	app.tray.clear()
	app._save_tray()
	for k in app.store.cache.keys():
		if str(k).begins_with("40000000000"):
			app.store.cache.erase(k)
	app.store.save_cache()
	app.store.clear_history()
	app.store.save_history()
	print("PASS: %d  FAIL: %d" % [passed, failed])
	quit(1 if failed > 0 else 0)
