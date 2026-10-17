extends RefCounted
class_name Metrics

## Reine Rechnung. Kein Netz, kein UI -> voll testbar.
## Grundlage sind Werte pro 100 g (bei Getraenken laut Open Food Facts pro 100 ml).
## Fehlt ein Eingangswert, entfaellt die betroffene Kennzahl (-1 bzw. leeres
## Dictionary). Es wird nie geraten.

const KCAL_PER_G_PROTEIN := 4.0
const KCAL_PER_G_CARB := 4.0
const KCAL_PER_G_FAT := 9.0

# --- Bezug: 100 g / Portion / Packung ---------------------------------------

const BASIS_100G := "100g"
const BASIS_PORTION := "portion"
const BASIS_PACK := "pack"

## Menge (g bzw. ml) fuer einen Bezug. -1 = unbekannt bzw. nicht erlaubt.
## ml_as_g: Fluessigkeiten 1 ml ~ 1 g umrechnen (Einstellung). Aus -> ml-Mengen
## zaehlen nicht, Portion/Packung entfaellt bei Getraenken.
static func basis_amount(f: Food, basis: String, ml_as_g: bool = true) -> float:
	if basis == BASIS_100G:
		return 100.0
	var a: Dictionary = f.portion_amount() if basis == BASIS_PORTION else f.pack_amount()
	if not a["ok"]:
		return -1.0
	if a["unit"] == "ml" and not ml_as_g:
		return -1.0
	return float(a["value"])

## Wert pro 100 g -> Wert fuer den Bezug.
static func per_basis(v100: float, f: Food, basis: String, ml_as_g: bool = true) -> float:
	if v100 < 0.0:
		return -1.0
	var amount := basis_amount(f, basis, ml_as_g)
	if amount < 0.0:
		return -1.0
	return v100 * amount / 100.0

## Anteil an der Energie (0..1) fuer g eines Naehrstoffs mit kcal/g.
static func energy_share(grams: float, kcal_per_g: float, kcal: float) -> float:
	if grams < 0.0 or kcal <= 0.0:
		return -1.0
	return clampf(grams * kcal_per_g / kcal, 0.0, 1.0)

## g pro 100 kcal (Dichte bezogen auf Energie).
static func per_100kcal(grams: float, kcal: float) -> float:
	if grams < 0.0 or kcal <= 0.0:
		return -1.0
	return grams / kcal * 100.0

# --- Makro-Donut: Energieanteile (nicht Gramm) ------------------------------

## Liefert {protein, carbs, fat} als Energieanteile 0..1, oder {} wenn ein
## Makro fehlt. sugar_separate=true teilt die Kohlenhydrate in Zucker und
## uebrige KH ("starch") - ohne Doppelzaehlung, Zucker ist Teil der KH.
static func energy_split(f: Food, sugar_separate: bool = false) -> Dictionary:
	if not f.has_macros():
		return {}
	var e_p := f.protein * KCAL_PER_G_PROTEIN
	var e_c := f.carbs * KCAL_PER_G_CARB
	var e_f := f.fat * KCAL_PER_G_FAT
	var total := e_p + e_c + e_f
	if total <= 0.0:
		return {}
	var out := {
		"protein": e_p / total,
		"carbs": e_c / total,
		"fat": e_f / total,
		"energy_from_macros": total,
		"protein_kcal": e_p, "carb_kcal": e_c, "fat_kcal": e_f,
		"mismatch": false,
		"dominant": "protein",
		"sugar_split": false,
	}
	if sugar_separate and f.sugars >= 0.0:
		var sug := minf(f.sugars, f.carbs) * KCAL_PER_G_CARB
		out["sugar"] = sug / total
		out["starch"] = (e_c - sug) / total
		out["sugar_split"] = true
	var dom: float = out["protein"]
	if float(out["carbs"]) > dom:
		dom = out["carbs"]
		out["dominant"] = "carbs"
	if float(out["fat"]) > dom:
		out["dominant"] = "fat"
	# Plausibilitaet gegen Etikettenenergie (falls vorhanden), > 25 % Abweichung
	if f.has_kcal() and f.kcal > 0.0:
		var diff: float = abs(total - f.kcal) / f.kcal
		out["mismatch"] = diff > 0.25
	return out

# --- Kaloriendichte ---------------------------------------------------------

const DENSITY_EDGES := [60.0, 150.0, 250.0, 400.0]

## Band 0..4 (sehr niedrig .. sehr hoch) oder -1 wenn kcal fehlt.
static func density_band(kcal: float) -> int:
	if kcal < 0.0:
		return -1
	var b := 0
	for e in DENSITY_EDGES:
		if kcal >= e:
			b += 1
	return b

static func energy_density(f: Food) -> float:
	return f.kcal if f.has_kcal() else -1.0

# --- Eiweissdichte (g Protein pro 100 kcal) ---------------------------------

static func protein_density(f: Food) -> float:
	if not f.has_protein() or not f.has_kcal() or f.kcal <= 0.0:
		return -1.0
	return f.protein / (f.kcal / 100.0)

# --- Ampel-Schwellen ---------------------------------------------------------

## UK Food Standards Agency, Front-of-Pack-Kennzeichnung (pro 100 g bzw. 100 ml).
## [niedrig bis einschliesslich, hoch ab mehr als]. Getraenke haben eigene,
## strengere Grenzen.
const FSA_FOOD := {
	"fat": [3.0, 17.5], "satfat": [1.5, 5.0], "sugar": [5.0, 22.5], "salt": [0.3, 1.5],
}
const FSA_DRINK := {
	"fat": [1.5, 8.75], "satfat": [0.75, 2.5], "sugar": [2.5, 11.25], "salt": [0.3, 0.75],
}

## 0 = niedrig (gruen), 1 = mittel (amber), 2 = hoch (rot), -1 = unbekannt.
static func fsa_level(nutrient: String, v100: float, drink: bool = false) -> int:
	if v100 < 0.0:
		return -1
	var t: Array = (FSA_DRINK if drink else FSA_FOOD).get(nutrient, [])
	if t.is_empty():
		return -1
	if v100 <= float(t[0]):
		return 0
	if v100 > float(t[1]):
		return 2
	return 1

## Ballaststoffe nach EU-Health-Claims (VO 1924/2006): "Ballaststoffquelle"
## ab 3 g/100 g oder 1,5 g/100 kcal, "hoher Gehalt" ab 6 g/100 g oder 3 g/100 kcal.
## 2 = hoch, 1 = Quelle, 0 = wenig, -1 = unbekannt.
static func fiber_level(f: Food) -> int:
	if not f.has_fiber():
		return -1
	var pk := per_100kcal(f.fiber, f.kcal)
	if f.fiber >= 6.0 or pk >= 3.0:
		return 2
	if f.fiber >= 3.0 or pk >= 1.5:
		return 1
	return 0

## Eiweiss nach EU-Health-Claims: "Proteinquelle" ab 12 % der Energie,
## "hoher Proteingehalt" ab 20 %. 2/1/0, -1 = unbekannt.
static func protein_level(f: Food) -> int:
	if not f.has_protein() or not f.has_kcal() or f.kcal <= 0.0:
		return -1
	var share := energy_share(f.protein, KCAL_PER_G_PROTEIN, f.kcal)
	if share >= 0.20:
		return 2
	if share >= 0.12:
		return 1
	return 0

# --- Fettqualitaet ------------------------------------------------------------

## Anteil gesaettigter Fettsaeuren am Gesamtfett (0..1). -1 wenn unbekannt
## oder kaum Fett (< 0,5 g/100 g, dann ist die Aufteilung bedeutungslos).
static func sat_share(f: Food) -> float:
	if not f.has_fat() or f.saturated < 0.0 or f.fat < 0.5:
		return -1.0
	return clampf(f.saturated / f.fat, 0.0, 1.0)

# --- Saettigung ---------------------------------------------------------------

## Klassischer Fullness Factor (NutritionData, Regression auf die Satiety-Index-
## Daten von Holt et al. 1995), inkl. der veroeffentlichten Grenzen:
## kcal mind. 30, Protein max. 30 g, Ballaststoffe max. 12 g, Fett max. 50 g,
## Ergebnis 0,5..5.
static func fullness_factor(f: Food) -> Dictionary:
	if not f.has_kcal() or f.kcal <= 0.0:
		return {}
	if not f.has_protein() or not f.has_fat():
		return {}
	var cal := maxf(f.kcal, 30.0)
	var pr := minf(f.protein, 30.0)
	var tf := minf(f.fat, 50.0)
	var ff := 41.7 / pow(cal, 0.7) + 0.05 * pr - 7.25e-6 * pow(tf, 3.0) + 0.617
	if f.has_fiber():
		ff += 6.17e-4 * pow(minf(f.fiber, 12.0), 3.0)
	var raw := clampf(ff, 0.5, 5.0)
	return {
		"raw": raw,
		"score": roundi(raw / 5.0 * 100.0),
		"no_fiber": not f.has_fiber(),
	}

## Saettigung 2.0 - Schaetzung pro Kalorie (0..100).
##
## Kern ist der Fullness Factor (Energiedichte, Protein, Ballaststoffe, Fett;
## an Holt 1995 gefittet). Er bewertet aber nur pro 100 g und uebersieht drei
## gut belegte Effekte. Holt hat isokalorische Portionen verglichen; dort
## korrelieren Ballaststoffe (r = 0,46) und Protein (r = 0,37) mit der
## Saettigung - also zaehlt ihre Dichte pro Kalorie:
##   + bis 8 Punkte  Ballaststoffe pro 100 kcal (voll ab 5 g/100 kcal)
##   + bis 6 Punkte  Eiweiss pro 100 kcal (voll ab 20 g/100 kcal)
##   - bis 15 Punkte Zuckeranteil an der Energie ueber 25 % (Suesses ist
##                   schmackhaft und wenig saettigend; Holt: Palatability r = -0,64)
##   - bis 30 Punkte bei Getraenken proportional zum Zuckeranteil: fluessige
##                   Zuckerkalorien werden kaum kompensiert (DiMeglio & Mattes
##                   2000); Milch/Proteingetraenke bleiben davon fast unberuehrt.
## Fehlen Ballaststoffe oder Zucker, entfaellt nur der jeweilige Term.
static func satiety(f: Food) -> Dictionary:
	var ff := fullness_factor(f)
	if ff.is_empty():
		return {}
	var base := float(ff["raw"]) / 5.0 * 100.0
	var fiber_bonus := 0.0
	if f.has_fiber():
		fiber_bonus = 8.0 * clampf(per_100kcal(f.fiber, f.kcal) / 5.0, 0.0, 1.0)
	var protein_bonus := 6.0 * clampf(per_100kcal(f.protein, f.kcal) / 20.0, 0.0, 1.0)
	var sugar_pen := 0.0
	var drink_pen := 0.0
	var sugar_share := -1.0
	if f.sugars >= 0.0:
		sugar_share = energy_share(f.sugars, KCAL_PER_G_CARB, f.kcal)
		sugar_pen = 15.0 * maxf(0.0, sugar_share - 0.25) / 0.75
		if f.is_drink():
			drink_pen = 30.0 * sugar_share
	var score := clampf(base + fiber_bonus + protein_bonus - sugar_pen - drink_pen, 0.0, 100.0)
	return {
		"score": roundi(score),
		"base": base,
		"fiber": fiber_bonus,
		"protein": protein_bonus,
		"sugar": -sugar_pen,
		"drink": -drink_pen,
		"no_fiber": not f.has_fiber(),
		"no_sugar": f.sugars < 0.0,
	}

# --- Gesamtauswertung (Standardansicht) ---------------------------------------

## Bündelt die vier Standardgrafiken inkl. Verfuegbarkeit fuer die UI.
static func evaluate(f: Food) -> Dictionary:
	var split := energy_split(f)
	var sat := satiety(f)
	var pd := protein_density(f)
	return {
		"split": split,
		"split_ok": not split.is_empty(),
		"density": energy_density(f),
		"density_band": density_band(f.kcal),
		"density_ok": f.has_kcal(),
		"protein_density": pd,
		"protein_density_ok": pd >= 0.0,
		"fullness": sat,
		"fullness_ok": not sat.is_empty(),
		"serving_g": f.serving_g,
	}

# --- Skalierung / Format ------------------------------------------------------

static func scale_value(v: float, grams: float) -> float:
	if v < 0.0:
		return -1.0
	return v * grams / 100.0

static func format_num(v: float, decimals: int = 1) -> String:
	if v < 0.0:
		return "–"
	var s: String
	match decimals:
		0: s = str(roundi(v))
		1: s = String.num(v, 1)
		_: s = String.num(v, decimals)
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s

## Sinnvolle Nachkommastellen fuer eine Zahl je nach Groesse.
static func auto_decimals(v: float) -> int:
	if v < 0.0 or v >= 100.0:
		return 0
	if v >= 10.0:
		return 0 if absf(v - roundf(v)) < 0.05 else 1
	return 1

## Runde Obergrenze fuer Balken mit variabler Skala (Portion/Packung).
static func nice_max(v: float) -> float:
	if v <= 0.0:
		return 1.0
	var exp10 := pow(10.0, floorf(log(v) / log(10.0)))
	for m in [1.0, 2.0, 2.5, 5.0, 10.0]:
		if v <= m * exp10:
			return m * exp10
	return 10.0 * exp10

## Position auf einer Grün->Rot-Skala (0 = "gut", 1 = "schlecht").
static func density_t(kcal: float) -> float:
	return clampf(kcal / 500.0, 0.0, 1.0)

static func protein_t(pd: float) -> float:
	return 1.0 - clampf(pd / 20.0, 0.0, 1.0)

static func satiety_t(score: float) -> float:
	return 1.0 - clampf(score / 100.0, 0.0, 1.0)

static func density_label(band: int, lang: String = "de") -> String:
	if lang == "en":
		return ["Very low", "Low", "Medium", "High", "Very high"][clampi(band, 0, 4)]
	return ["Sehr niedrig", "Niedrig", "Mittel", "Hoch", "Sehr hoch"][clampi(band, 0, 4)]
