extends RefCounted
class_name Metrics

## Reine Rechnung. Kein Netz, kein UI -> voll testbar.
## Alles auf 100-g-Basis. Fehlt ein Eingangswert, entfaellt die betroffene
## Kennzahl (Rueckgabe null bzw. valid=false). Es wird nie geraten.

# --- Makro-Donut: Energieanteile (nicht Gramm) ------------------------------

const KCAL_PER_G_PROTEIN := 4.0
const KCAL_PER_G_CARB := 4.0
const KCAL_PER_G_FAT := 9.0

## Liefert {protein, carbs, fat} als Energieanteile 0..1, oder null wenn ein
## Makro fehlt. Zusaetzlich energy_from_macros und ein Plausibilitaetsflag.
static func energy_split(f: Food) -> Dictionary:
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
	}
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

# --- Saettigung (Fullness Factor) -------------------------------------------

## FF = 41.7 / cal^0.7 + 0.05*protein + 6.17e-4*fiber^3 - 7.25e-6*fat^3 + 0.617
## Rohbereich ~0..5. Ohne Ballaststoffe entfaellt der fiber-Term (geschaetzt).
static func fullness_factor(f: Food) -> Dictionary:
	if not f.has_kcal() or f.kcal <= 0.0:
		return {}
	if not f.has_protein() or not f.has_fat():
		return {}
	var ff := 41.7 / pow(f.kcal, 0.7)
	ff += 0.05 * f.protein
	if f.has_fiber():
		ff += 6.17e-4 * pow(f.fiber, 3.0)
	ff -= 7.25e-6 * pow(f.fat, 3.0)
	ff += 0.617
	var raw := clampf(ff, 0.0, 5.0)
	return {
		"raw": raw,
		"score": roundi(raw / 5.0 * 100.0),
		"no_fiber": not f.has_fiber(),
	}

# --- Gesamtauswertung -------------------------------------------------------

## Bündelt alle vier Grafiken inkl. Verfuegbarkeit fuer die UI.
static func evaluate(f: Food) -> Dictionary:
	var split := energy_split(f)
	var ff := fullness_factor(f)
	var pd := protein_density(f)
	return {
		"split": split,
		"split_ok": not split.is_empty(),
		"density": energy_density(f),
		"density_band": density_band(f.kcal),
		"density_ok": f.has_kcal(),
		"protein_density": pd,
		"protein_density_ok": pd >= 0.0,
		"fullness": ff,
		"fullness_ok": not ff.is_empty(),
		"serving_g": f.serving_g,
	}

# --- Skalierung auf eine Menge ----------------------------------------------

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

static func density_label(band: int, lang: String = "de") -> String:
	if lang == "en":
		return ["Very low", "Low", "Medium", "High", "Very high"][clampi(band, 0, 4)]
	return ["Sehr niedrig", "Niedrig", "Mittel", "Hoch", "Sehr hoch"][clampi(band, 0, 4)]
