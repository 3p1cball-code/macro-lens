extends RefCounted
class_name Food

## Datenmodell eines Produkts. Alle Naehrwerte pro 100 g.
## Fehlende Werte bleiben bei -1 (nicht 0!), damit "fehlt" von "ist null"
## unterschieden werden kann. Kein Raten.

const NO_VALUE := -1.0

var barcode: String = ""
var name: String = ""
var name_en: String = ""           # englischer Name (Generika), sonst leer
var group: String = ""             # Kategorie (Generika), deutsch
var group_en: String = ""          # Kategorie englisch
var brand: String = ""
var quantity: String = ""          # z. B. "500 g" (Freitext vom Etikett)
var serving_g: float = NO_VALUE     # Portionsgroesse in g (bzw. ml), falls bekannt
var serving_text: String = ""       # Portion als Freitext, z. B. "1 Portion (30 g)"

var kcal: float = NO_VALUE          # energy-kcal_100g
var protein: float = NO_VALUE       # proteins_100g
var carbs: float = NO_VALUE         # carbohydrates_100g
var fat: float = NO_VALUE           # fat_100g
var saturated: float = NO_VALUE     # saturated-fat_100g
var fiber: float = NO_VALUE         # fiber_100g
var sugars: float = NO_VALUE        # sugars_100g
var salt: float = NO_VALUE          # salt_100g

var source: String = ""             # "openfoodfacts" | "generic" | "user"
var image_url: String = ""
var updated_ms: int = 0

func has(v: float) -> bool:
	return v != null and v >= 0.0

# --- bequeme Abfragen -------------------------------------------------------

func has_kcal() -> bool: return kcal >= 0.0
func has_protein() -> bool: return protein >= 0.0
func has_carbs() -> bool: return carbs >= 0.0
func has_fat() -> bool: return fat >= 0.0
func has_fiber() -> bool: return fiber >= 0.0

func has_macros() -> bool:
	return has_protein() and has_carbs() and has_fat()

# --- Mengen (Portion / Packung) ---------------------------------------------

## Liest die erste Mengenangabe mit Einheit aus einem Etikett-Text.
## "500 g" -> 500 g, "2 x 125 g" -> 250 g, "0,5 l" -> 500 ml, "6 x 0,33 l" -> 1980 ml,
## "1 Portion (30 g)" -> 30 g. Rueckgabe {ok, value, unit("g"|"ml")}.
static func parse_amount(text: String) -> Dictionary:
	var t := text.strip_edges().to_lower().replace(",", ".")
	if t == "":
		return {"ok": false, "value": -1.0, "unit": ""}
	var re := RegEx.new()
	re.compile("(?:(\\d+)\\s*[x×*]\\s*)?(\\d+(?:\\.\\d+)?)\\s*(kg|mg|g|ml|cl|dl|l)(?![a-z])")
	var m := re.search(t)
	if m == null:
		return {"ok": false, "value": -1.0, "unit": ""}
	var count := 1.0
	if m.get_string(1) != "":
		count = float(m.get_string(1))
	var v := float(m.get_string(2)) * count
	var unit := "g"
	var u := m.get_string(3)
	if u == "kg":
		v *= 1000.0
	elif u == "mg":
		v /= 1000.0
	elif u == "l":
		v *= 1000.0
	elif u == "dl":
		v *= 100.0
	elif u == "cl":
		v *= 10.0
	if u in ["l", "dl", "cl", "ml"]:
		unit = "ml"
	if v <= 0.0:
		return {"ok": false, "value": -1.0, "unit": ""}
	return {"ok": true, "value": v, "unit": unit}

## Portionsgroesse: bevorzugt der Freitext (mit Einheit), sonst serving_g als Gramm.
func portion_amount() -> Dictionary:
	var a := parse_amount(serving_text)
	if a["ok"]:
		return a
	if serving_g > 0.0:
		return {"ok": true, "value": serving_g, "unit": "g"}
	return {"ok": false, "value": -1.0, "unit": ""}

## Packungsinhalt aus dem Etikett ("500 g", "1,5 l", "4 x 125 g").
func pack_amount() -> Dictionary:
	return parse_amount(quantity)

## Getraenk = Inhalt in ml/l (dann gelten Getraenke-Schwellen, und Naehrwerte
## von Open Food Facts beziehen sich auf 100 ml).
func is_drink() -> bool:
	if pack_amount()["unit"] == "ml":
		return true
	return portion_amount()["unit"] == "ml"

func display_group(lang: String = "de") -> String:
	if lang == "en" and group_en.strip_edges() != "":
		return group_en
	return group

func display_name(lang: String = "de") -> String:
	if lang == "en" and name_en.strip_edges() != "":
		return name_en.strip_edges()
	if name.strip_edges() == "":
		return "Unknown product" if lang == "en" else "Unbekanntes Produkt"
	return name.strip_edges()

# --- Serialisierung ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"barcode": barcode, "name": name, "name_en": name_en, "group": group, "group_en": group_en,
		"brand": brand, "quantity": quantity,
		"serving_g": serving_g, "serving_text": serving_text, "kcal": kcal, "protein": protein, "carbs": carbs,
		"fat": fat, "saturated": saturated, "fiber": fiber, "sugars": sugars,
		"salt": salt, "source": source, "image_url": image_url,
		"updated_ms": updated_ms,
	}

static func from_dict(d: Dictionary) -> Food:
	var f := Food.new()
	f.barcode = str(d.get("barcode", ""))
	f.name = str(d.get("name", ""))
	f.name_en = str(d.get("name_en", ""))
	f.group = str(d.get("group", ""))
	f.group_en = str(d.get("group_en", ""))
	f.brand = str(d.get("brand", ""))
	f.quantity = str(d.get("quantity", ""))
	f.serving_g = float(d.get("serving_g", NO_VALUE))
	f.serving_text = str(d.get("serving_text", ""))
	f.kcal = float(d.get("kcal", NO_VALUE))
	f.protein = float(d.get("protein", NO_VALUE))
	f.carbs = float(d.get("carbs", NO_VALUE))
	f.fat = float(d.get("fat", NO_VALUE))
	f.saturated = float(d.get("saturated", NO_VALUE))
	f.fiber = float(d.get("fiber", NO_VALUE))
	f.sugars = float(d.get("sugars", NO_VALUE))
	f.salt = float(d.get("salt", NO_VALUE))
	f.source = str(d.get("source", ""))
	f.image_url = str(d.get("image_url", ""))
	f.updated_ms = int(d.get("updated_ms", 0))
	return f

func clone() -> Food:
	return Food.from_dict(to_dict())
