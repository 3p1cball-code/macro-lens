extends RefCounted
class_name Generics

## Mitgelieferte, lokale Unverpackt-/Generika-Liste. Keine Live-Abhaengigkeit.
## Zweisprachig: name = deutsch, name_en = englisch.

const PATH := "res://data/generics.json"

var items: Array = []        # Array[Food]

func load_default() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_warning("generics.json nicht gefunden")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return
	for raw in parsed.get("items", []):
		items.append(_to_food(raw))

func _to_food(raw: Dictionary) -> Food:
	var f := Food.new()
	f.name = str(raw.get("de", ""))
	f.name_en = str(raw.get("en", ""))
	f.group = str(raw.get("g", ""))
	f.source = "generic"
	f.barcode = "generic:" + f.name_en.to_lower().replace(" ", "_")
	f.kcal = float(raw.get("kcal", -1))
	f.protein = float(raw.get("p", -1))
	f.carbs = float(raw.get("c", -1))
	f.fat = float(raw.get("f", -1))
	f.fiber = float(raw.get("fib", -1))
	f.sugars = float(raw.get("sug", -1))
	f.saturated = float(raw.get("sat", -1))
	f.salt = float(raw.get("salt", -1))
	return f

func search(query: String) -> Array:
	var q := query.strip_edges().to_lower()
	var out: Array = []
	for f in items:
		if q == "" or f.name.to_lower().contains(q) or f.name_en.to_lower().contains(q) or f.group.to_lower().contains(q):
			out.append(f)
	return out

func all() -> Array:
	return items
