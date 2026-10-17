extends Node
class_name OffClient

## Open Food Facts Client: HTTP + User-Agent + Drosselung + Cache.
## Lokale Quelle der Wahrheit ist der Store (offline-faehig). Es wird nie
## ohne Netz geraten; bei Fehlern faellt der Aufrufer auf den Cache zurueck.
##
## Fehlerklassen (fuer die UI):
##   ""          ok
##   "notfound"  Server erreicht, Produkt existiert dort nicht (HTTP 404 / status 0)
##   "rate"      zu viele Anfragen (HTTP 429/503) - kurz warten
##   "net"       Transportfehler (kein Netz, Timeout, DNS ...) oder Serverfehler
##
## Limits laut OFF: Produktabfragen ~100/min, Suche ~10/min. Beide Toepfe werden
## getrennt gedrosselt, damit eine ausgereizte Suche keine Scans blockiert.

const USER_AGENT := "MacroLens/0.4 (alexander.riedel@eyedea3d.com)"
# image_front_url/completeness werden nie angezeigt -> nicht mitladen (Bytes/Zeit).
const FIELDS := "code,product_name,product_name_de,product_name_en,generic_name,brands,quantity,serving_size,nutriments"
## Nur bei aktiven Allergen-Warnungen zusaetzlich geladen (spart sonst Bytes).
const ALLERGEN_FIELDS := ",ingredients_text,ingredients_text_de,ingredients_text_en,allergens_tags,traces_tags"
const PRODUCT_URL := "https://world.openfoodfacts.org/api/v2/product/%s?fields=%s"
## Suche: Search-a-licious (neu, schnell, stabil) zuerst; die alte cgi-Suche
## (laut OFF ~10/min, liefert zeitweise 503) nur noch als Rueckfall.
const SAL_URL := "https://search.openfoodfacts.org/search?page_size=20&langs=%s&fields=%s&q=%s"
const SEARCH_URL := "https://world.openfoodfacts.org/cgi/search.pl?action=process&json=1&search_simple=1&page_size=20&fields=%s&search_terms=%s"

## Nicht-Lebensmittel: gleiche Software, andere Datenbanken.
const NONFOOD_FIELDS := "code,product_name,product_name_de,product_name_en,generic_name,brands,categories,categories_tags"
const NONFOOD_SOURCES := [
	["openproductsfacts", "https://world.openproductsfacts.org/api/v2/product/%s?fields=" + NONFOOD_FIELDS],
	["openbeautyfacts", "https://world.openbeautyfacts.org/api/v2/product/%s?fields=" + NONFOOD_FIELDS],
]

const GAP_MS := {"product": 1300, "sal": 1200, "search": 6500, "nonfood": 1000}
const MAX_WAIT_MS := 4000          # laenger wird nicht still gewartet -> "rate"
const RATE_DEFAULT_MS := 8000      # ohne Retry-After
const SEARCH_TTL_MS := 10 * 60 * 1000
const SEARCH_CACHE_MAX := 100
const NONFOOD_MISS_TTL_MS := 10 * 60 * 1000
const MAX_RESULTS := 32

signal fetch_done(code: String)
signal search_done(key: String)

var store: Store
var _last_ms := {"product": -100000, "sal": -100000, "search": -100000, "nonfood": -100000}
var _rate_until := {"product": 0, "sal": 0, "search": 0, "nonfood": 0}
var lang := "de"                        # bevorzugte Sprache fuer Suchtreffer
var want_allergens := false             # Zutaten/Allergene mitladen (Warnungen aktiv)

## Allergen-Felder an/aus. Gecachte Suchtreffer ohne diese Felder verwerfen.
func set_want_allergens(v: bool) -> void:
	if v != want_allergens:
		_search_cache.clear()
	want_allergens = v

func _fields() -> String:
	return FIELDS + (ALLERGEN_FIELDS if want_allergens else "")
var _inflight: Dictionary = {}          # code -> true (eine Anfrage pro Produkt)
var _results: Dictionary = {}           # code -> letztes Ergebnis (fuer Mitwarter)
var _search_cache: Dictionary = {}      # key -> {at, res}
var _search_inflight: Dictionary = {}   # key -> true
var _nonfood_miss: Dictionary = {}      # code -> ms (in keiner Datenbank)

## Testhilfe: Drosselung abschalten (Fake-HTTP braucht keine Pausen).
var throttle_enabled := true

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

	# Laeuft fuer diesen Code schon eine Anfrage (Prefetch)? Mitbenutzen statt
	# doppelt laden - spart eine TLS-Verbindung und Wartezeit.
	if _inflight.has(barcode):
		while _inflight.has(barcode):
			await fetch_done
		return _results.get(barcode, {"food": null, "cached": false, "error": "net"})

	_inflight[barcode] = true
	var out: Dictionary = await _fetch_remote(barcode)
	_inflight.erase(barcode)
	_results[barcode] = out
	while _results.size() > MAX_RESULTS:
		_results.erase(_results.keys()[0])
	fetch_done.emit(barcode)
	return out

## Vorab-Abruf beim ersten Sichtkontakt (vor der Bestaetigung). Das Ergebnis
## landet im Cache; die spaetere Bestaetigung findet es dort sofort.
func prefetch(barcode: String) -> void:
	if barcode == "" or store == null:
		return
	if store.get_cached(barcode) != null:
		return
	await fetch_product(barcode, false)

func _fetch_remote(barcode: String) -> Dictionary:
	if not await _throttle("product"):
		return {"food": null, "cached": false, "error": "rate"}
	var with_allergens := want_allergens
	var res := await _http_get(PRODUCT_URL % [barcode, _fields()])
	var err := _classify(res, "product")
	if err != "" and err != "notfound":
		return {"food": null, "cached": false, "error": err}
	var parsed = _json(res)
	if err == "" and parsed is Dictionary and int(parsed.get("status", 0)) == 1:
		var f := parse_product(parsed.get("product", {}))
		if f != null:
			f.allergen_fetched = with_allergens
		if f != null and store:
			store.put_cache(f)
			store.queue_cache()
		return {"food": f, "cached": false, "error": ""}
	return {"food": null, "cached": false, "error": "notfound"}

# --- Nicht-Lebensmittel -----------------------------------------------------

## Fragt Open Products Facts und Open Beauty Facts. Nur aufrufen, wenn OFF den
## Barcode nicht kennt. Rueckgabe: {item: Dictionary|null, error: ""|"notfound"|"net"|"rate"}
func lookup_nonfood(barcode: String) -> Dictionary:
	if barcode == "":
		return {"item": null, "error": "notfound"}
	if store != null and store.nonfood.has(barcode):
		return {"item": store.nonfood[barcode], "error": ""}
	var miss_at := int(_nonfood_miss.get(barcode, -1))
	if miss_at >= 0 and Time.get_ticks_msec() - miss_at < NONFOOD_MISS_TTL_MS:
		return {"item": null, "error": "notfound"}
	var worst := "notfound"
	for src in NONFOOD_SOURCES:
		if not await _throttle("nonfood"):
			worst = "rate"
			continue
		var res := await _http_get(String(src[1]) % barcode)
		var err := _classify(res, "nonfood")
		if err == "":
			var parsed = _json(res)
			if parsed is Dictionary and int(parsed.get("status", 0)) == 1:
				var item := NonFood.from_product(parsed.get("product", {}), String(src[0]), barcode)
				if store != null:
					store.nonfood[barcode] = item
					store.queue_nonfood()
				return {"item": item, "error": ""}
		elif err != "notfound":
			worst = err
	if worst == "notfound":
		_nonfood_miss[barcode] = Time.get_ticks_msec()
	return {"item": null, "error": worst}

# --- Suche per Name ---------------------------------------------------------

## Rueckgabe: {foods: Array[Food], error: ""|"net"|"rate", cached: bool}
## Gleiche Suchbegriffe innerhalb von 10 min kommen aus dem Speicher; eine
## laufende identische Suche wird mitbenutzt statt erneut gesendet.
func search(query: String) -> Dictionary:
	var q := query.strip_edges()
	if q == "":
		return {"foods": [], "error": "", "cached": false}
	var key := q.to_lower()
	var hit = _search_cache.get(key, null)
	if hit != null and Time.get_ticks_msec() - int(hit["at"]) < SEARCH_TTL_MS:
		var r: Dictionary = (hit["res"] as Dictionary).duplicate()
		r["cached"] = true
		return r
	if _search_inflight.has(key):
		while _search_inflight.has(key):
			await search_done
		var done = _search_cache.get(key, null)
		if done != null:
			return done["res"]
		return {"foods": [], "error": "net", "cached": false}

	_search_inflight[key] = true
	var out := await _search_remote(q)
	_search_inflight.erase(key)
	# Erfolg wird 10 min gecacht. Fehler nur als "abgelaufen" abgelegt: Mitwarter
	# bekommen das Ergebnis, die naechste Suche fragt aber wieder an.
	var at := Time.get_ticks_msec() if out["error"] == "" else -SEARCH_TTL_MS
	_search_cache.erase(key)
	_search_cache[key] = {"at": at, "res": out}
	while _search_cache.size() > SEARCH_CACHE_MAX:
		_search_cache.erase(_search_cache.keys()[0])
	search_done.emit(key)
	return out

func _search_remote(q: String) -> Dictionary:
	var a := await _search_sal(q)
	if a["error"] == "":
		return a
	var b := await _search_legacy(q)
	if b["error"] == "":
		return b
	# Beide gescheitert: Transportfehler ist die ehrlichere Meldung als "Limit".
	return a if a["error"] == "net" else b

func _search_sal(q: String) -> Dictionary:
	if not await _throttle("sal"):
		return {"foods": [], "error": "rate", "cached": false}
	var langs := "de,en" if lang == "de" else "en,de"
	var with_allergens := want_allergens
	var res := await _http_get(SAL_URL % [langs, _fields(), q.uri_encode()])
	var err := _classify(res, "sal")
	if err != "":
		return {"foods": [], "error": "net" if err == "notfound" else err, "cached": false}
	var parsed = _json(res)
	if not (parsed is Dictionary) or not (parsed.get("hits", null) is Array):
		return {"foods": [], "error": "net", "cached": false}
	return {"foods": _foods_from(parsed["hits"], with_allergens), "error": "", "cached": false}

func _search_legacy(q: String) -> Dictionary:
	if not await _throttle("search"):
		return {"foods": [], "error": "rate", "cached": false}
	var with_allergens := want_allergens
	var res := await _http_get(SEARCH_URL % [_fields(), q.uri_encode()])
	var err := _classify(res, "search")
	if err == "notfound":
		return {"foods": [], "error": "", "cached": false}
	if err != "":
		return {"foods": [], "error": err, "cached": false}
	var parsed = _json(res)
	if not (parsed is Dictionary):
		return {"foods": [], "error": "net", "cached": false}
	return {"foods": _foods_from(parsed.get("products", []), with_allergens), "error": "", "cached": false}

static func _foods_from(list, with_allergens: bool = false) -> Array:
	var out: Array = []
	if not (list is Array):
		return out
	for p in list:
		if not (p is Dictionary):
			continue
		var f := parse_product(p)
		if f != null and f.name.strip_edges() != "":
			f.allergen_fetched = with_allergens
			out.append(f)
	return out

## Wie lange (ms) ein Topf noch gesperrt ist; 0 = frei.
func rate_wait_ms(kind: String) -> int:
	return maxi(0, int(_rate_until.get(kind, 0)) - Time.get_ticks_msec())

# --- Parsen (defensiv) ------------------------------------------------------

static func parse_product(p: Dictionary) -> Food:
	if p.is_empty():
		return null
	var n: Dictionary = p.get("nutriments", {}) if p.get("nutriments", {}) is Dictionary else {}
	var f := Food.new()
	f.barcode = str(p.get("code", p.get("_id", "")))
	# Name defensiv: viele Eintraege haben nur den lokalisierten Namen oder generic_name.
	f.name = _first_text([
		p.get("product_name", ""),
		p.get("product_name_de", ""),
		p.get("product_name_en", ""),
		p.get("generic_name", ""),
	])
	var brands = p.get("brands", "")
	if brands is Array:
		brands = ", ".join(PackedStringArray(brands.map(func(x): return str(x))))
	f.brand = _first_brand(str(brands))
	f.quantity = str(p.get("quantity", ""))
	f.serving_text = str(p.get("serving_size", "")).strip_edges()
	if f.serving_text.to_lower() == "null":
		f.serving_text = ""
	var portion := Food.parse_amount(f.serving_text)
	f.serving_g = float(portion["value"]) if portion["ok"] else _parse_grams(f.serving_text)
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
	# Allergene (nur vorhanden, wenn angefragt)
	var texts: PackedStringArray = []
	for k in ["ingredients_text_de", "ingredients_text", "ingredients_text_en"]:
		var t := str(p.get(k, "")).strip_edges()
		if t != "" and t.to_lower() != "null" and not texts.has(t):
			texts.append(t)
	f.ingredients_text = " . ".join(texts)
	f.allergens_tags = Food._str_array(p.get("allergens_tags", []))
	f.traces_tags = Food._str_array(p.get("traces_tags", []))
	return f

## Naehrwert pro 100 g. Viele Produkte (z. B. tiefgekuehlte/gegarte Ware) fuehren
## ihre Werte nur als "<base>_prepared_100g" - dann darauf zurueckfallen.
static func _nutri(n: Dictionary, base: String) -> float:
	var v := _num(n, base + "_100g")
	if v >= 0.0:
		return v
	return _num(n, base + "_prepared_100g")

static func _first_text(values: Array) -> String:
	for v in values:
		var s := str(v).strip_edges()
		if s != "" and s.to_lower() != "null":
			return s
	return ""

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

## Ordnet eine HTTP-Antwort einer Fehlerklasse zu und setzt bei Bedarf die Sperre.
func _classify(res: Dictionary, kind: String) -> String:
	if not res.get("transport_ok", false):
		return "net"
	var code := int(res.get("code", 0))
	if code == 200:
		return ""
	if code == 404:
		return "notfound"
	if code == 429 or code == 503:
		var wait := int(res.get("retry_after_ms", -1))
		if wait <= 0:
			wait = RATE_DEFAULT_MS
		_rate_until[kind] = Time.get_ticks_msec() + clampi(wait, 1000, 120000)
		return "rate"
	return "net"

static func _json(res: Dictionary):
	var body: PackedByteArray = res.get("body", PackedByteArray())
	if body.is_empty():
		return null
	return JSON.parse_string(body.get_string_from_utf8())

## Wartet, bis der Topf `kind` wieder senden darf. false = laenger gesperrt
## als MAX_WAIT_MS (dann lieber sofort "rate" melden als still zu haengen).
func _throttle(kind: String) -> bool:
	if not throttle_enabled:
		# Test: keine Pausen, aber eine aktive Rate-Sperre gilt trotzdem.
		if int(_rate_until.get(kind, 0)) - Time.get_ticks_msec() > MAX_WAIT_MS:
			return false
		_last_ms[kind] = Time.get_ticks_msec()
		return true
	var now := Time.get_ticks_msec()
	var gap: int = GAP_MS.get(kind, 1300)
	var wait := maxi(gap - (now - int(_last_ms.get(kind, 0))), int(_rate_until.get(kind, 0)) - now)
	if wait > MAX_WAIT_MS:
		return false
	# Platz sofort reservieren, damit parallele Aufrufer sich hinten anstellen.
	_last_ms[kind] = now + maxi(wait, 0)
	if wait > 0:
		await get_tree().create_timer(float(wait) / 1000.0).timeout
	return true

static func parse_retry_after(headers: PackedStringArray) -> int:
	for h in headers:
		var s := String(h)
		if s.to_lower().begins_with("retry-after:"):
			var v := s.substr(12).strip_edges()
			if v.is_valid_int():
				return int(v) * 1000
	return -1

func _http_get(url: String) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 12.0
	req.accept_gzip = true
	add_child(req)
	var headers := PackedStringArray([
		"User-Agent: " + USER_AGENT,
		"Accept: application/json",
	])
	var err := req.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		req.queue_free()
		return {"transport_ok": false, "code": 0, "body": PackedByteArray()}
	var res: Array = await req.request_completed
	req.queue_free()
	var result_code: int = res[0]
	return {
		"transport_ok": result_code == HTTPRequest.RESULT_SUCCESS,
		"code": int(res[1]),
		"retry_after_ms": parse_retry_after(res[2]),
		"body": res[3],
	}
