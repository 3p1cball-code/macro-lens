extends SceneTree

## Tests des OFF-Clients ohne Netz: Prefetch und In-Flight-Dedupe.
## Lauf:  godot --headless --path . --script res://tests/test_off.gd

var passed := 0
var failed := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", msg)

## Store ohne Datei-IO (keine Testdaten im Nutzerprofil).
class FakeStore extends Store:
	func queue_cache() -> void:
		pass

## Simuliert einen langsamen OFF-Abruf, zaehlt die echten Anfragen.
class FakeOff extends OffClient:
	var calls := 0

	func _http_get(url: String) -> Dictionary:
		calls += 1
		await get_tree().create_timer(0.15).timeout
		var code := url.get_file().get_slice("?", 0)
		var body := JSON.stringify({
			"status": 1,
			"product": {
				"code": code,
				"product_name": "Fake",
				"nutriments": {
					"energy-kcal_100g": 100,
					"proteins_100g": 1,
					"carbohydrates_100g": 2,
					"fat_100g": 3,
				},
			},
		})
		return {"ok": true, "code": 200, "body": body.to_utf8_buffer()}

func _initialize() -> void:
	var store := FakeStore.new()
	var off := FakeOff.new()
	off.store = store
	off._min_gap_ms = 0
	root.add_child(off)
	await process_frame

	# Zwei gleichzeitige Anfragen fuer denselben Code -> nur ein HTTP-Abruf.
	# Der erste Aufruf wird dynamisch gestartet (Coroutine ohne await im Parser),
	# der zweite wartet auf dessen Ergebnis.
	var code := "4000000000777"
	off.call("fetch_product", code)
	var rb: Dictionary = await off.fetch_product(code)
	check(off.calls == 1, "gleicher Code: nur eine HTTP-Anfrage")
	check(rb.get("food") != null, "Mitwarter erhaelt das Produkt")
	check(store.get_cached(code) != null, "Produkt liegt im Cache")

	# Prefetch (erster Sichtkontakt) + Bestaetigung -> eine gemeinsame Anfrage.
	var code2 := "4000000000778"
	off.call("prefetch", code2)
	var r2: Dictionary = await off.fetch_product(code2)
	check(off.calls == 2, "Prefetch und Bestaetigung teilen eine Anfrage")
	check(r2.get("food") != null, "Bestaetigung erhaelt das vorab geladene Produkt")
	check(store.get_cached(code2) != null, "Prefetch-Ergebnis liegt im Cache")

	# Cache-first: kein weiterer Netzaufruf.
	var r3: Dictionary = await off.fetch_product(code2)
	check(off.calls == 2, "Cache-Treffer loest keine Anfrage aus")
	check(r3.get("cached", false), "Cache-Treffer ist als solcher markiert")

	print("PASS: %d  FAIL: %d" % [passed, failed])
	quit(1 if failed > 0 else 0)
