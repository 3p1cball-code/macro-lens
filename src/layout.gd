extends RefCounted
class_name Layout

## Aufbau der Hauptseite: geordnete Liste von Bausteinen mit Optionen.
##   [{"id": "macros", "options": {...}}, ...]
## Gespeichert in store.settings["home_layout"]. Funktionen geben immer eine
## NEUE, bereinigte Liste zurueck (leicht testbar, kein geteilter Zustand).
## Regeln: nur bekannte Bausteine, jeder hoechstens einmal, max. 5, mind. 1.

const KEY := "home_layout"
const PRESETS_KEY := "home_presets"
const MAX_USER_PRESETS := 12

## Vorlagen. Standard = die bisherigen vier Grafiken.
const BUILTIN := [
	{"key": "standard", "name": "preset_standard", "layout": [
		{"id": "macros"}, {"id": "density"}, {"id": "protein"}, {"id": "satiety"}]},
	{"key": "light", "name": "preset_light", "layout": [
		{"id": "density"}, {"id": "satiety"}, {"id": "fiber"}, {"id": "protein"}, {"id": "sugar"}]},
	{"key": "protein", "name": "preset_protein", "layout": [
		{"id": "protein"}, {"id": "macros"}, {"id": "density", "options": {"basis": "portion"}}, {"id": "satiety"}]},
	{"key": "sugar", "name": "preset_sugar", "layout": [
		{"id": "macros", "options": {"sugar": true}}, {"id": "sugar"}, {"id": "fiber"}, {"id": "density"}]},
	{"key": "fat", "name": "preset_fat", "layout": [
		{"id": "fatq"}, {"id": "satfat"}, {"id": "salt"}, {"id": "ampel"}]},
]

static func default_layout() -> Array:
	return sanitize(BUILTIN[0]["layout"])

static func sanitize(raw) -> Array:
	var out: Array = []
	var seen := {}
	if raw is Array:
		for e in raw:
			if out.size() >= Blocks.MAX_ACTIVE:
				break
			var id := ""
			var opts = {}
			if e is Dictionary:
				id = str(e.get("id", ""))
				opts = e.get("options", {})
			elif e is String:
				id = e
			if not Blocks.has(id) or seen.has(id):
				continue
			seen[id] = true
			out.append({"id": id, "options": Blocks.sanitize_options(id, opts)})
	if out.is_empty():
		return _hard_default()
	return out

static func _hard_default() -> Array:
	var out: Array = []
	for id in ["macros", "density", "protein", "satiety"]:
		out.append({"id": id, "options": Blocks.default_options(id)})
	return out

static func load_from(store: Store) -> Array:
	if store == null or not store.settings.has(KEY):
		return default_layout()
	return sanitize(store.settings[KEY])

static func save_to(store: Store, layout: Array) -> void:
	if store == null:
		return
	store.settings[KEY] = sanitize(layout)
	store.save_settings()

static func ids(layout: Array) -> Array:
	var out: Array = []
	for e in layout:
		out.append(e["id"])
	return out

static func contains(layout: Array, id: String) -> bool:
	return ids(layout).has(id)

static func is_full(layout: Array) -> bool:
	return layout.size() >= Blocks.MAX_ACTIVE

## Baustein an Position einfuegen. Schon vorhanden -> dorthin verschieben.
static func add(layout: Array, id: String, index: int = -1) -> Array:
	var l := sanitize(layout)
	var at := ids(l).find(id)
	if at >= 0:
		return move(l, at, index if index >= 0 else l.size() - 1)
	if not Blocks.has(id) or l.size() >= Blocks.MAX_ACTIVE:
		return l
	var entry := {"id": id, "options": Blocks.default_options(id)}
	if index < 0 or index > l.size():
		l.append(entry)
	else:
		l.insert(index, entry)
	return sanitize(l)

static func move(layout: Array, from: int, to: int) -> Array:
	var l := sanitize(layout)
	if from < 0 or from >= l.size():
		return l
	to = clampi(to, 0, l.size() - 1)
	var e = l[from]
	l.remove_at(from)
	l.insert(to, e)
	return l

## Entfernen; der letzte Baustein bleibt (leere Hauptseite waere sinnlos).
static func remove(layout: Array, index: int) -> Array:
	var l := sanitize(layout)
	if l.size() <= 1 or index < 0 or index >= l.size():
		return l
	l.remove_at(index)
	return l

static func set_option(layout: Array, index: int, key: String, value) -> Array:
	var l := sanitize(layout)
	if index < 0 or index >= l.size():
		return l
	var opts: Dictionary = (l[index]["options"] as Dictionary).duplicate()
	opts[key] = value
	l[index]["options"] = Blocks.sanitize_options(str(l[index]["id"]), opts)
	return l

static func equal(a: Array, b: Array) -> bool:
	return JSON.stringify(sanitize(a)) == JSON.stringify(sanitize(b))

# --- Vorlagen -------------------------------------------------------------------

static func builtin_presets() -> Array:
	var out: Array = []
	for p in BUILTIN:
		out.append({"key": p["key"], "name": I18n.t(p["name"]), "layout": sanitize(p["layout"]), "user": false})
	return out

static func user_presets(store: Store) -> Array:
	var out: Array = []
	if store == null:
		return out
	var raw = store.settings.get(PRESETS_KEY, [])
	if raw is Array:
		for p in raw:
			if p is Dictionary and str(p.get("name", "")).strip_edges() != "":
				out.append({"key": "user", "name": str(p["name"]).strip_edges(),
					"layout": sanitize(p.get("layout", [])), "user": true})
	return out

## Eigene Vorlage speichern. Gleicher Name ersetzt die alte. Rueckgabe: Erfolg.
static func save_user_preset(store: Store, name: String, layout: Array) -> bool:
	var n := name.strip_edges()
	if store == null or n == "":
		return false
	var list: Array = []
	for p in user_presets(store):
		if p["name"].to_lower() != n.to_lower():
			list.append({"name": p["name"], "layout": p["layout"]})
	if list.size() >= MAX_USER_PRESETS:
		return false
	list.append({"name": n.substr(0, 24), "layout": sanitize(layout)})
	store.settings[PRESETS_KEY] = list
	store.save_settings()
	return true

static func delete_user_preset(store: Store, name: String) -> void:
	if store == null:
		return
	var list: Array = []
	for p in user_presets(store):
		if p["name"] != name:
			list.append({"name": p["name"], "layout": p["layout"]})
	store.settings[PRESETS_KEY] = list
	store.save_settings()

## Name der Vorlage, die genau dem Layout entspricht ("" = eigene Zusammenstellung).
static func matching_preset(store: Store, layout: Array) -> String:
	for p in builtin_presets() + user_presets(store):
		if equal(p["layout"], layout):
			return p["name"]
	return ""
