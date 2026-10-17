extends RefCounted
class_name Blocks

## Bausteine der Hauptseite: Katalog, Optionen und Auswertung.
## Rein fachlich - gezeichnet wird in BlockView. Jede Auswertung liefert eine
## "Anzeige" (Dictionary), die fuer alle Produkte einer Zeile vergleichbar ist.
##
## Farbprinzip: Die Farbe beschreibt immer das LEBENSMITTEL (pro 100 g bzw.
## 100 ml, Ampel-Schwellen / Dichte), die Balkenlaenge den angezeigten Wert.
## So bleibt "rot" auch bei "pro Packung" ehrlich.

const MAX_ACTIVE := 5

## kind: "donut" | "bar" | "fatq" | "ampel"
const CATALOG := {
	"macros": {"title": "lbl_macros", "name": "blk_macros", "desc": "blkd_macros", "kind": "donut",
		"options": [
			{"key": "sugar", "type": "bool", "label": "opt_sugar_split", "default": false},
			{"key": "center", "type": "choice", "label": "opt_center", "default": "auto",
				"choices": [["auto", "ch_auto"], ["protein", "ch_center_protein"], ["dominant", "ch_center_dominant"]]},
		]},
	"density": {"title": "lbl_density", "name": "blk_density", "desc": "blkd_density", "kind": "bar",
		"options": [
			{"key": "basis", "type": "choice", "label": "opt_basis", "default": "100g",
				"choices": [["100g", "ch_100g"], ["portion", "ch_portion"], ["pack", "ch_pack"]]},
			{"key": "best", "type": "bool", "label": "opt_best", "default": true},
		]},
	"protein": {"title": "lbl_protein", "name": "blk_protein", "desc": "blkd_protein", "kind": "bar",
		"options": [
			{"key": "mode", "type": "choice", "label": "opt_mode", "default": "per_kcal",
				"choices": [["per_kcal", "ch_per_kcal"], ["g", "ch_grams"]]},
			{"key": "basis", "type": "choice", "label": "opt_basis", "default": "100g", "when": ["mode", "g"],
				"choices": [["100g", "ch_100g"], ["portion", "ch_portion"], ["pack", "ch_pack"]]},
			{"key": "best", "type": "bool", "label": "opt_best", "default": true},
		]},
	"satiety": {"title": "lbl_satiety", "name": "blk_satiety", "desc": "blkd_satiety", "kind": "bar",
		"options": [
			{"key": "model", "type": "choice", "label": "opt_model", "default": "v2",
				"choices": [["v2", "ch_satiety_v2"], ["ff", "ch_satiety_ff"]]},
			{"key": "best", "type": "bool", "label": "opt_best", "default": true},
		]},
	"sugar": {"title": "lbl_sugar", "name": "blk_sugar", "desc": "blkd_sugar", "kind": "bar",
		"options": [
			{"key": "mode", "type": "choice", "label": "opt_mode", "default": "g",
				"choices": [["g", "ch_grams"], ["pct_carbs", "ch_pct_carbs"], ["per_kcal", "ch_per_kcal"], ["pct_energy", "ch_pct_energy"]]},
			{"key": "basis", "type": "choice", "label": "opt_basis", "default": "100g", "when": ["mode", "g"],
				"choices": [["100g", "ch_100g"], ["portion", "ch_portion"], ["pack", "ch_pack"]]},
			{"key": "best", "type": "bool", "label": "opt_best", "default": true},
		]},
	"fiber": {"title": "lbl_fiber", "name": "blk_fiber", "desc": "blkd_fiber", "kind": "bar",
		"options": [
			{"key": "mode", "type": "choice", "label": "opt_mode", "default": "g",
				"choices": [["g", "ch_grams"], ["per_kcal", "ch_per_kcal"]]},
			{"key": "basis", "type": "choice", "label": "opt_basis", "default": "100g", "when": ["mode", "g"],
				"choices": [["100g", "ch_100g"], ["portion", "ch_portion"], ["pack", "ch_pack"]]},
			{"key": "best", "type": "bool", "label": "opt_best", "default": true},
		]},
	"salt": {"title": "lbl_salt", "name": "blk_salt", "desc": "blkd_salt", "kind": "bar",
		"options": [
			{"key": "mode", "type": "choice", "label": "opt_mode", "default": "g",
				"choices": [["g", "ch_salt_g"], ["sodium", "ch_sodium"]]},
			{"key": "basis", "type": "choice", "label": "opt_basis", "default": "100g",
				"choices": [["100g", "ch_100g"], ["portion", "ch_portion"], ["pack", "ch_pack"]]},
			{"key": "best", "type": "bool", "label": "opt_best", "default": true},
		]},
	"satfat": {"title": "lbl_satfat", "name": "blk_satfat", "desc": "blkd_satfat", "kind": "bar",
		"options": [
			{"key": "mode", "type": "choice", "label": "opt_mode", "default": "g",
				"choices": [["g", "ch_grams"], ["pct_fat", "ch_pct_fat"], ["pct_energy", "ch_pct_energy"]]},
			{"key": "basis", "type": "choice", "label": "opt_basis", "default": "100g", "when": ["mode", "g"],
				"choices": [["100g", "ch_100g"], ["portion", "ch_portion"], ["pack", "ch_pack"]]},
			{"key": "best", "type": "bool", "label": "opt_best", "default": true},
		]},
	"fatq": {"title": "lbl_fatq", "name": "blk_fatq", "desc": "blkd_fatq", "kind": "fatq",
		"options": [
			{"key": "best", "type": "bool", "label": "opt_best", "default": true},
		]},
	"ampel": {"title": "lbl_ampel", "name": "blk_ampel", "desc": "blkd_ampel", "kind": "ampel",
		"options": [
			{"key": "fat", "type": "bool", "label": "row_fat", "default": true},
			{"key": "satfat", "type": "bool", "label": "row_satfat", "default": true},
			{"key": "sugar", "type": "bool", "label": "row_sugar", "default": true},
			{"key": "salt", "type": "bool", "label": "row_salt", "default": true},
			{"key": "fiber", "type": "bool", "label": "row_fiber", "default": false},
			{"key": "protein", "type": "bool", "label": "row_protein", "default": false},
		]},
}

const ORDER := ["macros", "density", "protein", "satiety", "sugar", "fiber", "salt", "satfat", "fatq", "ampel"]
const AMPEL_ROWS := ["fat", "satfat", "sugar", "salt", "fiber", "protein"]

# --- Katalog ----------------------------------------------------------------

static func ids() -> Array:
	return ORDER.duplicate()

static func has(id: String) -> bool:
	return CATALOG.has(id)

static func spec(id: String) -> Dictionary:
	return CATALOG.get(id, {})

static func kind(id: String) -> String:
	return str(spec(id).get("kind", "bar"))

static func title(id: String) -> String:
	return I18n.t(str(spec(id).get("title", id)))

static func block_name(id: String) -> String:
	return I18n.t(str(spec(id).get("name", id)))

static func desc(id: String) -> String:
	return I18n.t(str(spec(id).get("desc", "")))

static func option_specs(id: String) -> Array:
	return spec(id).get("options", [])

static func default_options(id: String) -> Dictionary:
	var out := {}
	for o in option_specs(id):
		out[o["key"]] = o["default"]
	return out

## Optionen auf gueltige Werte bringen; Unbekanntes faellt weg, Fehlendes
## bekommt den Standard (migrationssicher fuer kuenftige Versionen).
static func sanitize_options(id: String, raw) -> Dictionary:
	var src: Dictionary = raw if raw is Dictionary else {}
	var out := {}
	for o in option_specs(id):
		var k: String = o["key"]
		var v = src.get(k, o["default"])
		if o["type"] == "bool":
			out[k] = bool(v) if (v is bool or v is int or v is float) else o["default"]
		else:
			var ok := false
			for c in o["choices"]:
				if str(c[0]) == str(v):
					ok = true
			out[k] = str(v) if ok else o["default"]
	return out

## Ist die Option bei den aktuellen Werten sichtbar ("when": [key, value])?
static func option_visible(o: Dictionary, opts: Dictionary) -> bool:
	if not o.has("when"):
		return true
	var w: Array = o["when"]
	return str(opts.get(w[0], "")) == str(w[1])

# --- Auswertung ---------------------------------------------------------------

## ctx: {"ml_as_g": bool}
static func evaluate(id: String, f: Food, opts: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	var o := sanitize_options(id, opts)
	var ml_as_g := bool(ctx.get("ml_as_g", true))
	match id:
		"macros": return _eval_macros(f, o)
		"density": return _eval_density(f, o, ml_as_g)
		"protein": return _eval_protein(f, o, ml_as_g)
		"satiety": return _eval_satiety(f, o)
		"sugar": return _eval_sugar(f, o, ml_as_g)
		"fiber": return _eval_fiber(f, o, ml_as_g)
		"salt": return _eval_salt(f, o, ml_as_g)
		"satfat": return _eval_satfat(f, o, ml_as_g)
		"fatq": return _eval_fatq(f, o)
		"ampel": return _eval_ampel(f, o)
	return {"ok": false}

## Index des besten Produkts einer Zeile (-1 = keins / ausgeschaltet).
## Bei weniger als 2 gueltigen Werten gibt es kein "BEST".
static func best_index(displays: Array) -> int:
	var idx := -1
	var ref := 0.0
	var valid := 0
	for i in displays.size():
		var d: Dictionary = displays[i]
		if not d.get("ok", false) or not d.has("rank"):
			continue
		valid += 1
		var v: float = d["rank"]
		var high: bool = d.get("good_high", false)
		if idx < 0 or (high and v > ref) or (not high and v < ref):
			idx = i
			ref = v
	return idx if valid >= 2 else -1

## Gemeinsame Balken-Obergrenze einer Zeile: feste Skala oder (Portion/Packung)
## eine runde Grenze ueber dem groessten Wert.
static func row_max(displays: Array) -> float:
	var fixed := 0.0
	var biggest := 0.0
	for d in displays:
		if not d.get("ok", false):
			continue
		fixed = maxf(fixed, float(d.get("bar_max", 0.0)))
		biggest = maxf(biggest, float(d.get("value", 0.0)))
	if fixed > 0.0:
		return fixed
	return Metrics.nice_max(biggest * 1.1)

# --- einzelne Bausteine -------------------------------------------------------

static func _basis_unit(f: Food, basis: String) -> String:
	match basis:
		"portion": return I18n.t("u_portion")
		"pack": return I18n.t("u_pack")
	return "100 ml" if f.is_drink() else "100 g"

static func _bar(value: float, decimals: int, unit: String, color: Color, bar_max: float, good_high: bool) -> Dictionary:
	if value < 0.0:
		return {"ok": false, "unit": unit}
	return {"ok": true, "value": value, "decimals": decimals, "unit": unit, "color": color,
		"bar_max": bar_max, "good_high": good_high, "rank": value}

static func _level_color(level: int) -> Color:
	match level:
		0: return UI.c("good")
		1: return UI.c("warn")
		2: return UI.c("bad")
	return UI.c("faint")

static func _positive_color(level: int) -> Color:
	match level:
		2: return UI.c("good")
		1: return UI.c("good").lerp(UI.c("faint"), 0.45)
	return UI.c("faint")

static func _eval_macros(f: Food, o: Dictionary) -> Dictionary:
	var split := Metrics.energy_split(f, bool(o["sugar"]))
	if split.is_empty():
		return {"ok": false}
	return {"ok": true, "split": split, "center": o["center"]}

static func _eval_density(f: Food, o: Dictionary, ml_as_g: bool) -> Dictionary:
	if not f.has_kcal():
		return {"ok": false, "unit": "kcal"}
	var basis: String = o["basis"]
	var v := Metrics.per_basis(f.kcal, f, basis, ml_as_g)
	var col := UI.scale_color(Metrics.density_t(f.kcal))
	var d := _bar(v, 0, "kcal/" + _basis_unit(f, basis), col, 500.0 if basis == "100g" else 0.0, false)
	d["best_on"] = o["best"]
	return d

static func _eval_protein(f: Food, o: Dictionary, ml_as_g: bool) -> Dictionary:
	var pd := Metrics.protein_density(f)
	var col := UI.c("faint") if pd < 0.0 else UI.scale_color(Metrics.protein_t(pd))
	var d: Dictionary
	if o["mode"] == "per_kcal":
		d = _bar(pd, 1, I18n.t("unit_g_100kcal"), col, 25.0, true)
	else:
		var basis: String = o["basis"]
		var v := Metrics.per_basis(f.protein, f, basis, ml_as_g) if f.has_protein() else -1.0
		if pd < 0.0 and f.has_protein():
			col = UI.c("accent")
		d = _bar(v, Metrics.auto_decimals(v), "g/" + _basis_unit(f, basis), col, 30.0 if basis == "100g" else 0.0, true)
	d["best_on"] = o["best"]
	return d

static func _eval_satiety(f: Food, o: Dictionary) -> Dictionary:
	var r := Metrics.satiety(f) if o["model"] == "v2" else Metrics.fullness_factor(f)
	if r.is_empty():
		return {"ok": false, "unit": I18n.t("of_100")}
	var sc := float(r["score"])
	var d := _bar(sc, 0, I18n.t("of_100"), UI.scale_color(Metrics.satiety_t(sc)), 100.0, true)
	d["detail"] = r
	d["best_on"] = o["best"]
	return d

## Werte eines Naehrstoffs je nach Modus. kcal_per_g fuer "% Energie".
static func _nutrient_bar(f: Food, grams100: float, o: Dictionary, ml_as_g: bool, color: Color,
		max_100g: float, kcal_per_g: float, good_high: bool) -> Dictionary:
	var mode: String = o.get("mode", "g")
	var d: Dictionary
	match mode:
		"per_kcal":
			d = _bar(Metrics.per_100kcal(grams100, f.kcal), 1, I18n.t("unit_g_100kcal"), color, max_100g / 2.0, good_high)
		"pct_energy":
			var s := Metrics.energy_share(grams100, kcal_per_g, f.kcal)
			d = _bar(s * 100.0 if s >= 0.0 else -1.0, 0, I18n.t("u_pct_energy"), color, 100.0, good_high)
		"pct_carbs":
			var v := -1.0
			if grams100 >= 0.0 and f.has_carbs() and f.carbs > 0.0:
				v = clampf(grams100 / f.carbs, 0.0, 1.0) * 100.0
			d = _bar(v, 0, I18n.t("u_pct_carbs"), color, 100.0, good_high)
		"pct_fat":
			var v2 := -1.0
			if grams100 >= 0.0 and f.has_fat() and f.fat > 0.0:
				v2 = clampf(grams100 / f.fat, 0.0, 1.0) * 100.0
			d = _bar(v2, 0, I18n.t("u_pct_fat"), color, 100.0, good_high)
		_:
			var basis: String = o.get("basis", "100g")
			var v3 := Metrics.per_basis(grams100, f, basis, ml_as_g)
			d = _bar(v3, Metrics.auto_decimals(v3), "g/" + _basis_unit(f, basis), color,
				max_100g if basis == "100g" else 0.0, good_high)
	d["best_on"] = o.get("best", true)
	return d

static func _eval_sugar(f: Food, o: Dictionary, ml_as_g: bool) -> Dictionary:
	var col := _level_color(Metrics.fsa_level("sugar", f.sugars, f.is_drink()))
	return _nutrient_bar(f, f.sugars, o, ml_as_g, col, 50.0, Metrics.KCAL_PER_G_CARB, false)

static func _eval_fiber(f: Food, o: Dictionary, ml_as_g: bool) -> Dictionary:
	var col := _positive_color(Metrics.fiber_level(f))
	return _nutrient_bar(f, f.fiber, o, ml_as_g, col, 15.0, 2.0, true)

static func _eval_satfat(f: Food, o: Dictionary, ml_as_g: bool) -> Dictionary:
	var col := _level_color(Metrics.fsa_level("satfat", f.saturated, f.is_drink()))
	var d := _nutrient_bar(f, f.saturated, o, ml_as_g, col, 10.0, Metrics.KCAL_PER_G_FAT, false)
	if o.get("mode", "g") == "pct_energy" and d.get("ok", false):
		d["bar_max"] = 50.0
	return d

static func _eval_salt(f: Food, o: Dictionary, ml_as_g: bool) -> Dictionary:
	var col := _level_color(Metrics.fsa_level("salt", f.salt, f.is_drink()))
	var basis: String = o["basis"]
	var d: Dictionary
	if o["mode"] == "sodium":
		var mg := Metrics.per_basis(f.salt / 2.5 * 1000.0 if f.salt >= 0.0 else -1.0, f, basis, ml_as_g)
		d = _bar(mg, 0, "mg Na/" + _basis_unit(f, basis), col, 1200.0 if basis == "100g" else 0.0, false)
	else:
		var v := Metrics.per_basis(f.salt, f, basis, ml_as_g)
		d = _bar(v, 2 if v >= 0.0 and v < 1.0 else 1, "g/" + _basis_unit(f, basis), col,
			3.0 if basis == "100g" else 0.0, false)
	d["best_on"] = o["best"]
	return d

static func _eval_fatq(f: Food, o: Dictionary) -> Dictionary:
	var s := Metrics.sat_share(f)
	if s < 0.0:
		var little := f.has_fat() and f.fat < 0.5
		return {"ok": false, "note": I18n.t("fatq_little") if little else "", "unit": I18n.t("u_pct_sat")}
	var level := 0 if s <= 0.34 else (1 if s <= 0.5 else 2)
	var d := _bar(s * 100.0, 0, I18n.t("u_pct_sat"), _level_color(level), 100.0, false)
	d["share"] = s
	d["best_on"] = o["best"]
	return d

static func _eval_ampel(f: Food, o: Dictionary) -> Dictionary:
	var drink := f.is_drink()
	var rows: Array = []
	for key in AMPEL_ROWS:
		if not bool(o.get(key, false)):
			continue
		var level := -1
		var v := -1.0
		var positive := false
		match key:
			"fat":
				v = f.fat
				level = Metrics.fsa_level("fat", v, drink)
			"satfat":
				v = f.saturated
				level = Metrics.fsa_level("satfat", v, drink)
			"sugar":
				v = f.sugars
				level = Metrics.fsa_level("sugar", v, drink)
			"salt":
				v = f.salt
				level = Metrics.fsa_level("salt", v, drink)
			"fiber":
				v = f.fiber
				level = Metrics.fiber_level(f)
				positive = true
			"protein":
				v = f.protein
				level = Metrics.protein_level(f)
				positive = true
		var col := _positive_color(level) if positive else _level_color(level)
		var dec := 2 if key == "salt" and v >= 0.0 and v < 1.0 else 1
		rows.append({"key": key, "label": I18n.t("row_" + key + "_short"), "level": level,
			"color": col, "text": Metrics.format_num(v, dec) if v >= 0.0 else "–"})
	return {"ok": not rows.is_empty(), "rows": rows}
