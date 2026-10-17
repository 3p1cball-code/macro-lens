extends SceneTree

## Tests der Allergen-/Unvertraeglichkeits-Erkennung.
## Lauf:  godot --headless --path . --script res://tests/test_allergens.gd

var passed := 0
var failed := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", msg)

func _f(name: String, ingredients: String, allergens: Array = [], traces: Array = []) -> Food:
	var f := Food.new()
	f.name = name
	f.source = "openfoodfacts"
	f.ingredients_text = ingredients
	f.allergens_tags = allergens
	f.traces_tags = traces
	f.allergen_fetched = true
	return f

func _ids(r: Dictionary, trace: bool = false) -> Array:
	var out: Array = []
	for h in r["hits"]:
		if h["trace"] == trace:
			out.append(h["id"])
	return out

func _initialize() -> void:
	_test_catalog()
	_test_real_products()
	_test_traps()
	_test_traces()
	_test_free_claims()
	_test_states()
	_test_generics()
	print("PASS: %d  FAIL: %d" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _test_catalog() -> void:
	check(Allergens.ids(Allergens.ALLERGY).size() == 14, "14 Allergien (EU-14, Nuesse + nur Erdnuesse)")
	check(Allergens.ids(Allergens.INTOL).size() == 5, "5 Unvertraeglichkeiten")
	for id in Allergens.ids():
		check(Allergens.name(id, "de") != id and Allergens.name(id, "en") != id, "Name: " + id)
		check(Allergens.examples(id, "de") != "", "Beispiele: " + id)
	check(Allergens.sanitize(["milk", "quatsch", "milk", "gluten"]) == ["gluten", "milk"], "Auswahl bereinigt + Katalogreihenfolge")

## Echte Daten aus Open Food Facts (Oktober 2026).
func _test_real_products() -> void:
	var nutella := _f("Nutella", "Zucker, Palmöl, HASELNÜSSE 13 %, MAGERMILCHPULVER 8,7 %, fettarmer Kakao, Emulgator Lecithine (Soja), Vanillin",
		["en:milk", "en:nuts", "en:soybeans"])
	var r := Allergens.analyze(nutella, ["milk", "nuts", "lactose", "gluten"])
	check(r["state"] == "red", "Nutella: rot")
	check(_ids(r).has("milk") and _ids(r).has("nuts") and _ids(r).has("lactose"), "Nutella: Milch, Nuesse, Laktose")
	check(not _ids(r).has("gluten"), "Nutella: kein Gluten")
	check(r["hits"][0]["kind"] == Allergens.ALLERGY, "Allergien zuerst")
	# Nur Unvertraeglichkeit ausgewaehlt -> orange
	check(Allergens.analyze(nutella, ["lactose"])["state"] == "orange", "nur Laktose -> orange")
	# Text allein reicht (ohne Tags)
	var no_tags := _f("Nutella", nutella.ingredients_text)
	check(_ids(Allergens.analyze(no_tags, ["milk", "nuts", "soy"])).size() == 3, "Zutatenliste ohne Tags: Milch, Nuesse, Soja")

	var alpro := _f("Geröstete Mandel Ohne Zucker", "Wasser, _Mandeln_ (2,3%), Calcium (Calciumcarbonat), Meersalz, Stabilisatoren (Guarkernmehl, Gellan), Emulgator (Lecithine), natürliches Aroma, Vitamine B12, D2, E.",
		["en:nuts"], ["de:Schalenfrüchte (keine Erdnüsse)"])
	r = Allergens.analyze(alpro, ["nuts", "peanuts", "milk", "lactose"])
	check(_ids(r) == ["nuts"], "Alpro Mandel: Nuesse enthalten")
	check(not _ids(r, true).has("peanuts"), "\"keine Erdnüsse\" in den Spuren ist keine Erdnuss-Spur")
	check(not _ids(r).has("milk") and not _ids(r).has("lactose"), "Mandeldrink ist keine Milch")

	var cola := _f("Coca-Cola Original", "Wasser, Zucker, Kohlensäure, Farbstoff E150d, Säuerungsmittel: E338, natürliche Aromen inklusive Koffein")
	r = Allergens.analyze(cola, ["caffeine", "fructose", "sulphites"])
	check(_ids(r) == ["caffeine"] and r["state"] == "orange", "Cola: Koffein (orange)")
	var zero := _f("Coca-Cola koffeinfrei", "Wasser, Kohlensäure, Farbstoff E150d, Aromen")
	check(Allergens.analyze(zero, ["caffeine"])["state"] == "none", "koffeinfrei: kein Koffein-Treffer")

	var oatly := _f("Oatmilk", "")
	oatly.allergen_fetched = true
	r = Allergens.analyze(oatly, ["milk", "gluten"])
	check(r["state"] == "unknown" or _ids(r) == ["gluten"], "Oatly ohne Zutaten: nicht geprueft (oder Hafer aus dem Namen)")
	check(not _ids(r).has("milk"), "Oatmilk ist keine Milch")

func _test_traps() -> void:
	var sel := ["milk", "lactose", "eggs", "nuts", "peanuts", "gluten", "fish", "molluscs", "soy"]
	var cases := [
		["Kokosmilch", "Kokosnussextrakt 60%, Wasser", []],
		["Schokolade", "Zucker, Kakaomasse, Kakaobutter, Emulgator: Sonnenblumenlecithin", []],
		["Proteinriegel", "Sojaeiweiß, Erbsenprotein, Glukosesirup", ["soy"]],
		["Gewürz", "Paprika, Muskatnuss, Pfeffer", []],
		["Buchweizen-Galette", "Buchweizenmehl, Wasser, Salz", []],
		["Sportgetränk", "Wasser, Maltodextrin, Natriumcitrat", []],
		["Joghurtersatz", "Hafer, Wasser, Milchsäurebakterien", ["gluten"]],
		["Calamari", "Tintenfisch 80%, Weizenmehl", ["molluscs", "gluten"]],
		["Kaffee", "Röstkaffee, ohne Milch", []],
		["Butternut-Suppe", "Butternut-Kürbis, Wasser, Zwiebel", []],
		["Kartoffelpüree", "Kartoffeln, Eisen, Vitamin C", []],
		["Peanut Butter", "Peanuts 100%", ["nuts", "peanuts"]],
		["Pesto", "Basilikum, Olivenöl, Pinienkerne, Cashewkerne, Grana Padano (MILCH, Lab, Salz, Konservierungsstoff: Lysozym aus EI)", ["milk", "lactose", "eggs", "nuts"]],
	]
	for c in cases:
		var r := Allergens.analyze(_f(c[0], c[1]), sel)
		var got := _ids(r)
		got.sort()
		var want: Array = (c[2] as Array).duplicate()
		want.sort()
		check(got == want, "%s: erwartet %s, gefunden %s" % [c[0], want, got])

func _test_traces() -> void:
	var f := _f("Müsli", "Haferflocken, Rosinen. Kann Spuren von Erdnüssen, Sesam und anderen Nüssen enthalten.")
	var r := Allergens.analyze(f, ["peanuts", "sesame", "gluten"])
	check(_ids(r) == ["gluten"], "Spuren-Satz: Hafer enthalten")
	check(_ids(r, true).has("peanuts") and _ids(r, true).has("sesame"), "Spuren: Erdnuesse, Sesam")
	check(r["state"] == "red", "Gluten enthalten -> rot")
	var only_trace := Allergens.analyze(f, ["sesame"])
	check(only_trace["state"] == "orange", "nur Spur einer Allergie -> orange")
	check(Allergens.analyze(f, ["sesame"], false)["state"] == "none", "Spuren aus -> kein Treffer")
	var tagged := _f("Riegel", "Datteln, Kakao", [], ["en:milk", "en:peanuts"])
	r = Allergens.analyze(tagged, ["milk", "lactose", "peanuts"])
	check(_ids(r, true) == ["peanuts", "milk"] or _ids(r, true) == ["milk", "peanuts"], "Spuren-Tags")
	check(not _ids(r, true).has("lactose"), "Unvertraeglichkeit: Spuren zaehlen nicht")
	check(_ids(r).is_empty() and r["state"] == "orange", "nur Spuren -> orange")
	# Spuren-Satz ohne Punkt davor
	var run_on := _f("Kekse", "Weizenmehl, Zucker, Butter kann Spuren von Ei enthalten")
	r = Allergens.analyze(run_on, ["gluten", "milk", "eggs"])
	check(_ids(r).has("gluten") and _ids(r).has("milk") and _ids(r, true) == ["eggs"], "Spur ohne Satzende: nur der Teil ab 'kann'")

func _test_free_claims() -> void:
	var lf := _f("Milch laktosefrei 1,5%", "Milch (laktosefrei), Laktase", ["en:milk"])
	var r := Allergens.analyze(lf, ["milk", "lactose"])
	check(_ids(r) == ["milk"], "laktosefrei: Milcheiweiss ja, Laktose nein")
	var gf := _f("Glutenfreies Brot", "Reismehl, Hafermehl (glutenfrei), Wasser. Glutenfrei.", ["en:gluten"])
	check(Allergens.analyze(gf, ["gluten"])["state"] == "none", "glutenfrei-Claim hebt Gluten auf")
	var gf_trace := _f("Brot", "Reismehl. Glutenfrei. Kann Spuren von Gluten enthalten.")
	check(_ids(Allergens.analyze(gf_trace, ["gluten"]), true) == ["gluten"], "glutenfrei + Spuren: Spur bleibt")

func _test_states() -> void:
	var f := _f("X", "Wasser, Salz")
	check(Allergens.analyze(f, [])["state"] == "off", "nichts ausgewaehlt -> off")
	check(Allergens.analyze(f, ["milk"])["state"] == "none", "geprueft, kein Treffer -> none")
	var empty := _f("Unbekannt", "")
	check(Allergens.analyze(empty, ["milk"])["state"] == "unknown", "keine Daten -> unknown")
	var by_name := _f("Erdnussbutter", "")
	check(Allergens.analyze(by_name, ["peanuts"])["state"] == "red", "Name allein (Erdnussbutter) -> rot")
	check(Allergens.list_names(Allergens.analyze(_f("Nutella", "Haselnüsse, Magermilchpulver"), ["milk", "nuts", "lactose"])["hits"], Allergens.ALLERGY) == "Nüsse, Milch", "Kurzliste")
	# Daten-Flags
	var stale := Food.new()
	stale.source = "openfoodfacts"
	check(stale.needs_allergen_data(), "alter Cache-Eintrag braucht Allergen-Daten")
	var rt := Food.from_dict(_f("A", "Milch", ["en:milk"], ["en:nuts"]).to_dict())
	check(rt.allergens_tags == ["en:milk"] and rt.traces_tags == ["en:nuts"] and rt.allergen_fetched and rt.ingredients_text == "Milch",
		"Allergen-Felder ueberleben den Cache")
	# OFF-Parsing
	var p := OffClient.parse_product({"code": "1", "product_name": "Test", "ingredients_text_de": "Weizenmehl, Ei",
		"ingredients_text": "Weizenmehl, Ei", "allergens_tags": ["en:gluten", "en:eggs"], "traces_tags": ["en:soybeans"], "nutriments": {}})
	check(p.ingredients_text == "Weizenmehl, Ei" and p.allergens_tags.size() == 2 and p.traces_tags == ["en:soybeans"], "OFF-Parsing der Allergen-Felder")

func _test_generics() -> void:
	var g := Generics.new()
	g.load_default()
	var by := {}
	for f in g.all():
		by[f.name] = f
	check(by["Skyr"].curated and by["Skyr"].curated_alerts.has("lactose"), "Skyr kuratiert: Laktose")
	var r := Allergens.analyze(by["Erdnüsse"], ["nuts"])
	check(r["state"] == "red", "Erdnuesse zaehlen zu 'Nuesse (alle)'")
	check(Allergens.analyze(by["Banane"], ["milk", "nuts"])["state"] == "none", "Banane: geprueft, nichts")
	check(Allergens.analyze(by["Zartbitterschokolade (70%)"], ["milk"])["state"] == "orange", "Zartbitter: Milch-Spur -> orange")
	check(Allergens.analyze(by["Gouda"], ["lactose"])["state"] == "none", "Gouda: gereift, praktisch laktosefrei")
	check(by["Obst" if false else "Apfel"].display_group("en") == "Fruit", "Gruppe EN")
