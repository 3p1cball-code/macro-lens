extends SceneTree

## Tests der reinen Rechenlogik (Metrics, Food, OFF-Parsing).
## Lauf:  godot --headless --path . --script res://tests/test_metrics.gd

var _pass := 0
var _fail := 0

func _initialize() -> void:
	_test_energy_split()
	_test_density()
	_test_protein_density()
	_test_fullness()
	_test_scale_format()
	_test_off_parsing()
	_test_generics()
	print("---")
	print("PASS: ", _pass, "  FAIL: ", _fail)
	quit(0 if _fail == 0 else 1)

func _ok(name: String, cond: bool) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: ", name)

func _near(name: String, a: float, b: float, eps: float = 0.01) -> void:
	if absf(a - b) <= eps:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: ", name, "  got=", a, " want=", b)

func _food(kcal: float, p: float, c: float, f: float, fib: float = -1.0) -> Food:
	var x := Food.new()
	x.kcal = kcal
	x.protein = p
	x.carbs = c
	x.fat = f
	x.fiber = fib
	return x

func _test_energy_split() -> void:
	var s := Metrics.energy_split(_food(63, 11, 4, 0.2))
	_ok("split present", not s.is_empty())
	# e_p=44, e_c=16, e_f=1.8 -> total 61.8
	_near("protein share", s["protein"], 44.0 / 61.8, 0.005)
	_near("carbs share", s["carbs"], 16.0 / 61.8, 0.005)
	_ok("dominant protein", s["dominant"] == "protein")
	# fehlendes Makro -> keine Auswertung
	_ok("missing macro -> empty", Metrics.energy_split(_food(100, -1, 10, 2)).is_empty())
	# Plausibilitaet: Makros 400 kcal vs Etikett 800 -> mismatch
	var m := Metrics.energy_split(_food(800, 25, 25, 25))
	_ok("mismatch flagged", m.get("mismatch", false))

func _test_density() -> void:
	_ok("band 18 -> 0", Metrics.density_band(18) == 0)
	_ok("band 63 -> 1", Metrics.density_band(63) == 1)
	_ok("band 150 -> 2", Metrics.density_band(150) == 2)
	_ok("band 250 -> 3", Metrics.density_band(250) == 3)
	_ok("band 402 -> 4", Metrics.density_band(402) == 4)
	_ok("band -1 -> -1", Metrics.density_band(-1) == -1)

func _test_protein_density() -> void:
	# 11 g Protein bei 63 kcal -> 17.46 g/100 kcal
	_near("skyr protein density", Metrics.protein_density(_food(63, 11, 4, 0.2)), 17.46, 0.02)
	_ok("no kcal -> -1", Metrics.protein_density(_food(-1, 11, 4, 0.2)) < 0.0)

func _test_fullness() -> void:
	var ff := Metrics.fullness_factor(_food(63, 11, 4, 0.2, 0.0))
	_ok("fullness present", not ff.is_empty())
	_ok("fullness in 0..100", int(ff["score"]) >= 0 and int(ff["score"]) <= 100)
	# ohne Ballaststoffe markiert
	_ok("no-fiber flagged", Metrics.fullness_factor(_food(63, 11, 4, 0.2, -1.0))["no_fiber"])
	# kalorienarmes, proteinreiches Produkt fuellt mehr als kalorienreiches fettes
	var low := int(Metrics.fullness_factor(_food(60, 11, 4, 0.2, 0.0))["score"])
	var high := int(Metrics.fullness_factor(_food(600, 5, 30, 50, 0.0))["score"])
	_ok("low-cal fuller than high-cal", low > high)

func _test_scale_format() -> void:
	_near("scale to portion", Metrics.scale_value(63.0, 150.0), 94.5, 0.01)
	_ok("format_dash", Metrics.format_num(-1.0) == "–")
	_ok("format_int", Metrics.format_num(402.0, 0) == "402")
	_ok("format_1dec", Metrics.format_num(2.34, 1) == "2.3")

func _test_off_parsing() -> void:
	var p := {
		"code": "4001234567890",
		"product_name": "Test-Joghurt",
		"brands": "Müller, Andere",
		"quantity": "500 g",
		"serving_size": "150 g",
		"nutriments": {
			"energy-kcal_100g": 61.0,
			"proteins_100g": 3.5,
			"carbohydrates_100g": 4.7,
			"fat_100g": 3.3,
		},
	}
	var f := OffClient.parse_product(p)
	_ok("parse name", f.name == "Test-Joghurt")
	_ok("parse first brand", f.brand == "Müller")
	_near("parse serving g", f.serving_g, 150.0, 0.01)
	_near("parse kcal", f.kcal, 61.0, 0.01)
	_ok("missing fiber stays -1", f.fiber == -1.0)
	# kJ-Fallback
	var p2 := {"code": "1", "product_name": "X", "nutriments": {"energy-kj_100g": 418.4, "proteins_100g": 1.0, "carbohydrates_100g": 1.0, "fat_100g": 1.0}}
	var f2 := OffClient.parse_product(p2)
	_near("kj fallback", f2.kcal, 100.0, 0.5)
	# "prepared"-Variante (z. B. Iglo Fischstaebchen: Werte nur als *_prepared_100g)
	var p3 := {
		"code": "4250241203524",
		"product_name": "Fischstäbchen",
		"brands": "IGLO",
		"nutriments": {
			"energy-kcal_prepared_100g": 204.666666666667,
			"proteins_prepared_100g": 12.0,
			"carbohydrates_prepared_100g": 18.0,
			"fat_prepared_100g": 8.0,
			"fiber_prepared_100g": 1.0,
		},
	}
	var f3 := OffClient.parse_product(p3)
	_near("prepared kcal", f3.kcal, 204.67, 0.1)
	_ok("prepared has macros", f3.has_macros())
	_near("prepared protein", f3.protein, 12.0, 0.01)
	_near("prepared fiber", f3.fiber, 1.0, 0.01)
	# Name nur im lokalisierten Feld bzw. generic_name
	var p4 := {
		"code": "1", "product_name_de": "Gratinkäse", "generic_name": "Käse",
		"nutriments": {"energy-kcal_100g": 300.0, "proteins_100g": 20.0, "carbohydrates_100g": 2.0, "fat_100g": 24.0},
	}
	_ok("localized name fallback", OffClient.parse_product(p4).name == "Gratinkäse")
	var p5 := {"code": "2", "generic_name": "Gratinkäse", "nutriments": {"energy-kcal_100g": 300.0}}
	_ok("generic_name fallback", OffClient.parse_product(p5).name == "Gratinkäse")
	# Eintrag ohne Namen -> leerer Name (wird als unbrauchbar behandelt)
	_ok("nameless stays empty", OffClient.parse_product({"code": "3", "nutriments": {}}).name == "")
	# leeres Produkt -> null
	_ok("empty product -> null", OffClient.parse_product({}) == null)

func _test_generics() -> void:
	var g := Generics.new()
	g.load_default()
	_ok("generics loaded > 40", g.all().size() > 40)
	_ok("search skyr", g.search("skyr").size() >= 1)
	_ok("search english name", g.search("banana").size() >= 1)
	_ok("generic freeze-dried", g.search("gefriergetrocknet").size() >= 1)
	var skyr: Food = g.search("skyr")[0]
	_ok("generic has macros", skyr.has_macros())
	_ok("generic protein density ok", Metrics.protein_density(skyr) > 0.0)
