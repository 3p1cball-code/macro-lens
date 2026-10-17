extends SceneTree

## Tests des OFF-Clients ohne Netz: Fehlerklassen, Prefetch/Dedupe, Such-Cache,
## Rate-Sperre und Nicht-Lebensmittel (Open Products/Beauty Facts).
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
	func queue_nonfood() -> void:
		pass

## Antworten nach URL-Teilstueck; zaehlt echte Anfragen.
class FakeOff extends OffClient:
	var calls := 0
	var urls: Array = []
	var routes: Dictionary = {}   # substring -> {transport_ok, code, body(String), retry_after_ms}

	func _http_get(url: String) -> Dictionary:
		calls += 1
		urls.append(url)
		await get_tree().create_timer(0.05).timeout
		for k in routes:
			if url.contains(k):
				var r: Dictionary = routes[k]
				return {"transport_ok": r.get("transport_ok", true), "code": r.get("code", 200),
					"retry_after_ms": r.get("retry_after_ms", -1),
					"body": str(r.get("body", "")).to_utf8_buffer()}
		return {"transport_ok": true, "code": 404, "retry_after_ms": -1,
			"body": JSON.stringify({"status": 0}).to_utf8_buffer()}

static func food_body(code: String) -> String:
	return JSON.stringify({"status": 1, "product": {"code": code, "product_name": "Fake",
		"nutriments": {"energy-kcal_100g": 100, "proteins_100g": 1, "carbohydrates_100g": 2, "fat_100g": 3}}})

func _new_off(store: Store) -> FakeOff:
	var off := FakeOff.new()
	off.store = store
	off.throttle_enabled = false
	root.add_child(off)
	return off

func _initialize() -> void:
	await process_frame
	_test_classify()
	await _test_food()
	await _test_errors()
	await _test_search()
	await _test_nonfood()
	print("PASS: %d  FAIL: %d" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _test_food() -> void:
	var store := FakeStore.new()
	var off := _new_off(store)
	off.routes["openfoodfacts.org/api/v2/product/4000000000777"] = {"body": food_body("4000000000777")}
	off.routes["openfoodfacts.org/api/v2/product/4000000000778"] = {"body": food_body("4000000000778")}

	# Zwei gleichzeitige Anfragen fuer denselben Code -> nur ein HTTP-Abruf.
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

	# Cache-first: kein weiterer Netzaufruf.
	var r3: Dictionary = await off.fetch_product(code2)
	check(off.calls == 2, "Cache-Treffer loest keine Anfrage aus")
	check(r3.get("cached", false), "Cache-Treffer ist als solcher markiert")
	off.queue_free()

func _test_errors() -> void:
	var store := FakeStore.new()
	var off := _new_off(store)
	# 404 ist "nicht gefunden", NICHT "Netzwerkfehler" (alter Bug).
	var r: Dictionary = await off.fetch_product("4000000000001")
	check(str(r.get("error")) == "notfound", "HTTP 404 -> notfound (war: net)")

	# Transportfehler -> net
	off.routes["product/4000000000002"] = {"transport_ok": false, "code": 0}
	r = await off.fetch_product("4000000000002")
	check(str(r.get("error")) == "net", "Transportfehler -> net")

	# 5xx -> net
	off.routes["product/4000000000005"] = {"code": 500}
	r = await off.fetch_product("4000000000005")
	check(str(r.get("error")) == "net", "HTTP 500 -> net")

	# 429 mit Retry-After -> rate; danach sperrt der Topf ohne HTTP
	off.routes["product/4000000000003"] = {"code": 429, "retry_after_ms": 30000}
	r = await off.fetch_product("4000000000003")
	check(str(r.get("error")) == "rate", "HTTP 429 -> rate")
	check(off.rate_wait_ms("product") > 20000, "Retry-After setzt die Sperre")
	var before := off.calls
	r = await off.fetch_product("4000000000004")
	check(str(r.get("error")) == "rate" and off.calls == before, "gesperrter Topf: sofort rate, kein HTTP")
	check(off.rate_wait_ms("search") == 0, "Suche-Topf bleibt von Produkt-Sperre unberuehrt")

	check(OffClient.parse_retry_after(PackedStringArray(["Content-Type: x", "Retry-After: 12"])) == 12000,
		"Retry-After-Header wird gelesen")
	check(OffClient.parse_retry_after(PackedStringArray(["Content-Type: x"])) == -1, "ohne Header -> -1")
	off.queue_free()

func _test_search() -> void:
	var store := FakeStore.new()
	var off := _new_off(store)
	# Search-a-licious: "hits", Marken als Liste
	off.routes["&q=Skyr"] = {"body": JSON.stringify({"hits": [
		{"code": "1", "product_name": "Skyr Natur", "brands": ["Milram", "X"], "nutriments": {"energy-kcal_100g": 63}},
		{"code": "2", "product_name": "", "nutriments": {}},
	]})}
	var a: Dictionary = await off.search("Skyr")
	check(off.calls == 1 and (a["foods"] as Array).size() == 1, "Suche liefert Treffer (namenlose raus)")
	check((a["foods"] as Array).size() == 1 and a["foods"][0].brand == "Milram", "Marke aus Liste")
	check(str(off.urls[0]).begins_with("https://search.openfoodfacts.org/"), "zuerst Search-a-licious")
	var b: Dictionary = await off.search("  skyr ")
	check(off.calls == 1 and b.get("cached", false), "gleiche Suche kommt aus dem Cache")

	# Gleichzeitige identische Suche -> eine Anfrage
	off.routes["&q=Quark"] = {"body": JSON.stringify({"hits": [
		{"code": "3", "product_name": "Quark", "nutriments": {}}]})}
	off.call("search", "Quark")
	var c: Dictionary = await off.search("quark")
	check(off.calls == 2 and (c["foods"] as Array).size() == 1, "laufende Suche wird mitbenutzt")

	# Search-a-licious gestoert (503) -> Rueckfall auf alte Suche
	off.routes["&q=Hafer"] = {"code": 503}
	off.routes["search_terms=Hafer"] = {"body": JSON.stringify({"products": [
		{"code": "4", "product_name": "Haferflocken", "nutriments": {}}]})}
	var d: Dictionary = await off.search("Hafer")
	check(str(d["error"]) == "" and (d["foods"] as Array).size() == 1, "Rueckfall auf cgi-Suche")

	# Beide weg -> Fehler, nicht gecacht
	off.routes["&q=fehler"] = {"transport_ok": false, "code": 0}
	off.routes["search_terms=fehler"] = {"transport_ok": false, "code": 0}
	var e: Dictionary = await off.search("fehler")
	check(str(e["error"]) == "net", "Suche: beide Transportfehler -> net")
	var before := off.calls
	await off.search("fehler")
	check(off.calls > before, "fehlgeschlagene Suche wird beim naechsten Mal neu gesendet")
	off.queue_free()

func _test_nonfood() -> void:
	var store := FakeStore.new()
	var off := _new_off(store)
	# OFF kennt es nicht, Open Products Facts auch nicht, Open Beauty Facts schon.
	off.routes["openbeautyfacts.org/api/v2/product/8001090662231"] = {"body": JSON.stringify({
		"status": 1, "product": {"code": "8001090662231", "product_name": "Coconut Milk",
			"brands": "Pantene, P&G", "categories_tags": ["en:hair", "en:shampoos"]}})}
	var r: Dictionary = await off.lookup_nonfood("8001090662231")
	var item = r.get("item", null)
	check(item != null and str(item["kind"]) == "hair", "Shampoo aus Open Beauty Facts -> hair")
	check(item != null and str(item["brand"]) == "Pantene", "erste Marke")
	check(store.nonfood.has("8001090662231"), "Nicht-Lebensmittel wird gemerkt")
	var calls := off.calls
	await off.lookup_nonfood("8001090662231")
	check(off.calls == calls, "zweiter Lookup ohne Netz")

	# Nirgends gefunden -> notfound, und kurzzeitig gemerkt
	r = await off.lookup_nonfood("4000000009999")
	check(r.get("item", null) == null and str(r["error"]) == "notfound", "nirgends -> notfound")
	calls = off.calls
	await off.lookup_nonfood("4000000009999")
	check(off.calls == calls, "Fehltreffer wird kurz gemerkt (kein Dauerfragen)")

	# Netzfehler -> net (und NICHT als Fehltreffer gemerkt)
	off.routes["openproductsfacts.org/api/v2/product/4000000008888"] = {"transport_ok": false}
	r = await off.lookup_nonfood("4000000008888")
	check(str(r["error"]) == "net", "Netzfehler beim Nicht-Lebensmittel -> net")
	off.queue_free()

func _test_classify() -> void:
	check(NonFood.classify(["en:household-chemicals", "en:laundry-detergents"], "", "Persil", "openproductsfacts") == "cleaning",
		"Waschmittel -> cleaning")
	check(NonFood.classify([], "", "Spülmittel", "openproductsfacts") == "cleaning",
		"ohne Kategorie, Name Spuelmittel -> cleaning")
	check(NonFood.classify(["en:baby-foods", "en:non-food-products"], "", "Nivea crème", "openbeautyfacts") == "cosmetic",
		"verrauschte Kategorie, Creme -> cosmetic")
	check(NonFood.classify(["en:furniture"], "", "Office chair", "openproductsfacts") == "other",
		"'chair' ist kein 'hair'")
	check(NonFood.classify(["en:pet-foods", "en:cat-food"], "", "Whiskas", "openproductsfacts") == "pet",
		"Katzenfutter -> pet")
	check(NonFood.classify([], "", "", "openbeautyfacts") == "cosmetic", "OBF ohne Infos -> cosmetic")
	check(NonFood.classify([], "", "", "openproductsfacts") == "other", "OPF ohne Infos -> other")
	check(NonFood.classify([], "", "Zahnpasta sensitiv", "openbeautyfacts") == "oral", "Zahnpasta -> oral")
	check(NonFood.message("cleaning", "de").contains("Frühstück"), "Text DE")
	check(NonFood.message("unbekannt", "en") == NonFood.message("other", "en"), "unbekannte Art -> other")
