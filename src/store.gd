extends RefCounted
class_name Store

## Lokale Persistenz: Cache (OFF-Produkte offline), Verlauf, Einstellungen.
## Nichts verlaesst das Geraet. JSON unter user://.

const CACHE_PATH := "user://cache.json"
const HISTORY_PATH := "user://history.json"
const SETTINGS_PATH := "user://settings.json"
const USER_FOODS_PATH := "user://my_foods.json"
const MAX_HISTORY := 500

var cache: Dictionary = {}          # barcode -> Food.to_dict()
var history: Array = []             # [{barcode, ts}, ...] neueste zuerst
var settings: Dictionary = {}       # theme/lang/unit
var user_foods: Dictionary = {}     # selbst angelegte Generika

func load_all() -> void:
	cache = _read_dict(CACHE_PATH)
	history = _read_array(HISTORY_PATH)
	settings = _read_dict(SETTINGS_PATH)
	user_foods = _read_dict(USER_FOODS_PATH)
	_apply_defaults()

func _apply_defaults() -> void:
	if not settings.has("theme"):
		settings["theme"] = "dark"
	if not settings.has("lang"):
		settings["lang"] = "de"
	if not settings.has("unit"):
		settings["unit"] = "100g"

func save_settings() -> void: _write(SETTINGS_PATH, settings)
func save_cache() -> void: _write(CACHE_PATH, cache)
func save_history() -> void: _write(HISTORY_PATH, history)
func save_user_foods() -> void: _write(USER_FOODS_PATH, user_foods)

# --- Sparsames Schreiben ----------------------------------------------------

## Scan-Daten aendern sich oft; statt bei jedem Scan die komplette JSON neu zu
## schreiben, sammeln wir ~1,5 s und schreiben dann einmal. Flush passiert
## zusaetzlich bei App-Pause/Exit (App._notification/_exit_tree).
const WRITE_DELAY := 1.5

var _pending: Dictionary = {}
var _flush_scheduled := false

func queue_cache() -> void: _schedule("cache")
func queue_history() -> void: _schedule("history")

func _schedule(what: String) -> void:
	_pending[what] = true
	if _flush_scheduled:
		return
	_flush_scheduled = true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		flush_pending()
		return
	await tree.create_timer(WRITE_DELAY).timeout
	_flush_scheduled = false
	flush_pending()

func flush_pending() -> void:
	if _pending.has("cache"):
		_write(CACHE_PATH, cache)
	if _pending.has("history"):
		_write(HISTORY_PATH, history)
	_pending.clear()

# --- Cache ------------------------------------------------------------------

func get_cached(barcode: String) -> Food:
	if barcode == "" or not cache.has(barcode):
		return null
	return Food.from_dict(cache[barcode])

func put_cache(f: Food) -> void:
	if f == null or f.barcode == "":
		return
	f.updated_ms = Time.get_unix_time_from_system() * 1000
	cache[f.barcode] = f.to_dict()

# --- Verlauf ----------------------------------------------------------------

func add_history(f: Food) -> void:
	if f == null:
		return
	var stamp := int(Time.get_unix_time_from_system())
	# Duplikat entfernen, dann vorne einfuegen
	var filtered: Array = []
	for e in history:
		if str(e.get("barcode", "")) != f.barcode or f.barcode == "":
			filtered.append(e)
	filtered.push_front({"barcode": f.barcode, "ts": stamp, "name": f.display_name(), "source": f.source})
	while filtered.size() > MAX_HISTORY:
		filtered.pop_back()
	history = filtered

func clear_history() -> void:
	history = []

# --- Selbst angelegte Generika ---------------------------------------------

func put_user_food(f: Food) -> void:
	if f == null:
		return
	f.source = "user"
	var key := f.barcode if f.barcode != "" else "user:" + f.name.to_lower()
	user_foods[key] = f.to_dict()
	save_user_foods()

# --- IO ---------------------------------------------------------------------

func _read_dict(path: String) -> Dictionary:
	var d = _read_json(path)
	return d if d is Dictionary else {}

func _read_array(path: String) -> Array:
	var d = _read_json(path)
	return d if d is Array else []

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	if txt.strip_edges() == "":
		return null
	return JSON.parse_string(txt)

func _write(path: String, value) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(value))
	f.close()
