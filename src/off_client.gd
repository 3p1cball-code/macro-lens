extends Node
class_name OffClient

## Open Food Facts Client: HTTP + User-Agent + Backoff + Cache.
## Lokale Quelle der Wahrheit ist der Store (offline-faehig). Es wird nie
## ohne Netz geraten; bei Fehlern faellt der Aufrufer auf den Cache zurueck.

const USER_AGENT := "MacroLens/0.1 (alexander.riedel@eyedea3d.com)"
const PRODUCT_URL := "https://world.openfoodfacts.org/api/v2/product/%s?fields=code,product_name,brands,quantity,serving_size,nutriments,image_front_url,completeness"
const SEARCH_URL := "https://world.openfoodfacts.org/cgi/search.pl?action=process&json=1&search_simple=1&page_size=20&fields=code,product_name,brands,quantity,serving_size,nutriments,image_front_url,nutriscore_grade&search_terms=%s"

var store: Store
var _last_request_ms: int = 0
var _min_gap_ms: int = 1300   # ~ vertraeglich gegenueber ~15/min Limit
var _backoff_ms: int = 0

func _ready() -> void:
	pass

# --- Produkt per Barcode ----------------------------------------------------

## Rueckgabe: {food: Food|null, cached: bool, error: ""|"net"|"rate"|"notfound"}
## force=true umgeht den Cache (z. B. wenn ein alter Eintrag keine Makros hat).
func fetch_product(barcode: String, force: bool = false) -> Dictionary:
	var cached := store.get_cached(barcode) if store else null
	if cached != null and not force:
		# Cache-first: sofort nutzbar -> schnelle, offline-feste Scans.
		return {"food": cached, "cached": true, "error": ""}

	await _throttle()
	var res := await _http_get(PRODUCT_URL % barcode)
	if res.get("code", 0) == 429 or res.get("code", 0) == 503:
		_backoff_ms = mini(_backoff_ms + 3000, 30000)
		return {"food": null, "cached": false, "error": "rate"}
	if not res.get("ok", false):
		return {"food": null, "cached": false, "error": "net"}
	_backoff_ms = 0
	var parsed = JSON.parse_string(res["body"].get_string_from_utf8())
	if parsed is Dictionary and int(parsed.get("status", 0)) == 1:
		var f := parse_product(parsed.get("product", {}))
		if f != null and store:
			store.put_cache(f)
			store.save_cache()
		return {"food": f, "cached": false, "error": ""}
	return {"food": null, "cached": false, "error": "notfound"}

# --- Suche per Name ---------------------------------------------------------

## Rueckgabe: {foods: Array[Food], error: ""|"net"|"rate"}
func search(query: String) -> Dictionary:
	var q := query.strip_edges()
	if q == "":
		return {"foods": [], "error": ""}
	await _throttle()
	var res := await _http_get(SEARCH_URL % q.uri_encode())
	if res.get("code", 0) == 429 or res.get("code", 0) == 503:
		return {"foods": [], "error": "rate"}
	if not res.get("ok", false):
		return {"foods": [], "error": "net"}
	var parsed = JSON.parse_string(res["body"].get_string_from_utf8())
	var out: Array = []
	if parsed is Dictionary:
		for p in parsed.get("products", []):
			var f := parse_product(p)
			if f != null and f.display_name() != "Unbekanntes Produkt":
				out.append(f)
	return {"foods": out, "error": ""}

# --- Parsen (defensiv) ------------------------------------------------------

static func parse_product(p: Dictionary) -> Food:
	if p.is_empty():
		return null
	var n: Dictionary = p.get("nutriments", {})
	var f := Food.new()
	f.barcode = str(p.get("code", p.get("_id", "")))
	f.name = str(p.get("product_name", "")).strip_edges()
	f.brand = _first_brand(str(p.get("brands", "")))
	f.quantity = str(p.get("quantity", ""))
	f.serving_g = _parse_grams(str(p.get("serving_size", "")))
	f.image_url = str(p.get("image_front_url", ""))
	f.source = "openfoodfacts"
	f.kcal = _nutri(n, "energy-kcal")
	if f.kcal < 0.0:
		# Fallback: Kilojoule
		var kj := _nutri(n, "energy-kj")
		if kj < 0.0:
			kj = _nutri(n, "energy")
		if kj >= 0.0:
			f.kcal = kj / 4.184
	f.protein = _nutri(n, "proteins")
	f.carbs = _nutri(n, "carbohydrates")
	f.fat = _nutri(n, "fat")
	f.saturated = _nutri(n, "saturated-fat")
	f.fiber = _nutri(n, "fiber")
	f.sugars = _nutri(n, "sugars")
	f.salt = _nutri(n, "salt")
	if f.salt < 0.0:
		var sodium := _nutri(n, "sodium")
		if sodium >= 0.0:
			f.salt = sodium * 2.5
	return f

## Naehrwert pro 100 g. Viele Produkte (z. B. tiefgekuehlte/gegarte Ware) fuehren
## ihre Werte nur als "<base>_prepared_100g" - dann darauf zurueckfallen.
static func _nutri(n: Dictionary, base: String) -> float:
	var v := _num(n, base + "_100g")
	if v >= 0.0:
		return v
	return _num(n, base + "_prepared_100g")

static func _first_brand(brands: String) -> String:
	var b := brands.strip_edges()
	if b.contains(","):
		b = b.split(",")[0].strip_edges()
	return b

static func _num(n: Dictionary, key: String) -> float:
	if not n.has(key):
		return -1.0
	var v = n[key]
	if v is float or v is int:
		return float(v)
	if v is String and v.strip_edges() != "":
		return float(v) if v.is_valid_float() else -1.0
	return -1.0

static func _parse_grams(s: String) -> float:
	var t := s.strip_edges().to_lower()
	if t == "":
		return -1.0
	var num := ""
	for ch in t:
		if (ch >= "0" and ch <= "9") or ch == "." or ch == ",":
			num += ch
		elif num != "":
			break
	num = num.replace(",", ".")
	if num == "" or not num.is_valid_float():
		return -1.0
	var v := float(num)
	if t.contains("kg"):
		v *= 1000.0
	return v

# --- HTTP -------------------------------------------------------------------

func _throttle() -> void:
	var now := Time.get_ticks_msec()
	var gap := _min_gap_ms + _backoff_ms
	var wait := gap - (now - _last_request_ms)
	if wait > 0:
		await get_tree().create_timer(float(wait) / 1000.0).timeout
	_last_request_ms = Time.get_ticks_msec()

func _http_get(url: String) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 12.0
	add_child(req)
	var headers := PackedStringArray([
		"User-Agent: " + USER_AGENT,
		"Accept: application/json",
	])
	var err := req.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "body": PackedByteArray()}
	var res: Array = await req.request_completed
	req.queue_free()
	var result_code: int = res[0]
	var http_code: int = res[1]
	var body: PackedByteArray = res[3]
	return {"ok": result_code == HTTPRequest.RESULT_SUCCESS and http_code == 200,
			"code": http_code, "body": body}
