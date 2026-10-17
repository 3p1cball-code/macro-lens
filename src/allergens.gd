extends RefCounted
class_name Allergens

## Allergene & Unvertraeglichkeiten: Katalog und Erkennung.
##
## Quellen je Produkt (Open Food Facts): allergens_tags, traces_tags, die
## Zutatenliste (DE/EN/Original) und der Produktname. Grundnahrungsmittel sind
## kuratiert (Food.curated_alerts).
##
## Ergebnis (analyze):
##   state  "off"     keine Warnungen ausgewaehlt
##          "red"     ausgewaehlte ALLERGIE enthalten
##          "orange"  ausgewaehlte UNVERTRAEGLICHKEIT enthalten oder Allergie als Spur
##          "none"    geprueft, keine Treffer   (NICHT "sicher" - Daten koennen fehlen)
##          "unknown" keine Zutaten-/Allergenangaben -> nicht geprueft
##   hits   [{id, kind, trace}]
##
## Bewusst vorsichtig: lieber eine Warnung zu viel als eine zu wenig. Die App
## zeigt nie "allergenfrei".

const ALLERGY := "allergy"
const INTOL := "intolerance"

## Stichwort-Regeln (gegen einzelne Woerter der Zutatenliste, kleingeschrieben):
##   "=wort"   Wort genau
##   "^wort"   Wort beginnt damit
##   "wort"    Wort enthaelt es (deutsche Komposita: "magermilchpulver")
##   "a b"     Wortfolge (letztes Wort: beginnt damit)
## excl:      Wort enthaelt das -> kein Treffer (Kokosmilch, Kakaobutter, Buchweizen)
## excl_prev: direkt davor (nur Leerzeichen/Bindestrich) -> kein Treffer ("Kokos Milch")
## free:      Claim im Text ("laktosefrei") hebt ENTHAELT auf (Spuren bleiben)
const MILK_KW := ["milch", "^milk", "molke", "whey", "butter", "sahne", "rahm", "joghurt", "jogurt",
	"yoghurt", "yogurt", "käse", "kaese", "cheese", "quark", "topfen", "kefir", "casein", "kasein",
	"caseinat", "laktose", "lactose", "ghee", "schmand", "mascarpone", "ricotta", "mozzarella",
	"parmesan", "skyr", "^cream", "crème fraîche", "creme fraiche"]
const MILK_EXCL := ["kokos", "coconut", "mandelmilch", "hafermilch", "sojamilch", "reismilch", "nussmilch",
	"cashewmilch", "dinkelmilch", "erbsenmilch", "kakaobutter", "sheabutter", "erdnussbutter", "nussbutter",
	"mandelbutter", "cashewbutter", "milchsäure", "milchsaeure", "butternut", "icecream", "ersatz"]
const MILK_PREV := ["kokos", "coconut", "mandel", "hafer", "soja", "reis", "nuss", "cashew", "dinkel",
	"erbsen", "almond", "oat", "soy", "rice", "kakao", "cocoa", "shea", "erdnuss", "peanut", "vegan",
	"pflanzlich", "plant"]

const ITEMS := [
	# --- Allergien (EU-14) ---------------------------------------------------
	{"id": "gluten", "kind": ALLERGY,
		"tags": ["en:gluten", "en:wheat", "en:barley", "en:rye", "en:oats", "en:spelt", "en:kamut"],
		"kw": ["gluten", "weizen", "roggen", "gerste", "hafer", "dinkel", "emmer", "einkorn", "kamut",
			"khorasan", "triticale", "grünkern", "gruenkern", "malz", "grieß", "griess", "couscous", "bulgur",
			"seitan", "paniermehl", "wheat", "=rye", "barley", "^oat", "spelt", "^malt", "semolina", "durum"],
		"excl": ["buchweizen", "buckwheat", "maltodextrin", "maltit", "maltose", "glutenfrei"],
		"free": ["glutenfrei", "gluten free", "ohne gluten", "sans gluten"]},
	{"id": "crustaceans", "kind": ALLERGY, "tags": ["en:crustaceans"],
		"kw": ["garnele", "shrimp", "krabbe", "krebs", "hummer", "languste", "scampi", "prawn", "^crab",
			"lobster", "crayfish", "krustentier", "crustace"]},
	{"id": "eggs", "kind": ALLERGY, "tags": ["en:eggs"],
		"kw": ["=ei", "^eier", "eigelb", "eiklar", "eidotter", "vollei", "hühnerei", "huehnerei", "eipulver",
			"=egg", "=eggs"]},
	{"id": "fish", "kind": ALLERGY, "tags": ["en:fish"],
		"kw": ["fisch", "^fish", "lachs", "salmon", "=tuna", "hering", "sardine", "sardelle", "anchovi",
			"anchovy", "kabeljau", "dorsch", "forelle", "makrele", "scholle", "pangasius", "zander",
			"matjes", "surimi", "=cod", "haddock", "seehecht"],
		"excl": ["tintenfisch"]},
	{"id": "peanuts", "kind": ALLERGY, "tags": ["en:peanuts"],
		"kw": ["erdnu", "erdnü", "peanut", "arachis"]},
	{"id": "nuts", "kind": ALLERGY,
		# "Nuesse" = alle Nuesse inkl. Erdnuesse (botanisch Huelsenfrucht).
		"tags": ["en:nuts", "en:almonds", "en:hazelnuts", "en:walnuts", "en:cashew-nuts", "en:pecan-nuts",
			"en:brazil-nuts", "en:pistachio-nuts", "en:pistachios", "en:macadamia-nuts", "en:queensland-nuts",
			"en:peanuts"],
		"kw": ["nuss", "nüsse", "nuesse", "=nut", "=nuts", "mandel", "almond", "hazelnut", "walnut", "cashew",
			"kaschu", "pekan", "pecan", "pistazie", "pistachio", "macadamia", "brazil", "schalenfrucht",
			"schalenfrücht", "nougat", "marzipan", "krokant", "erdnu", "erdnü", "peanut", "arachis"],
		"excl": ["kokos", "coconut", "muskat", "nutmeg", "butternut"]},
	{"id": "soy", "kind": ALLERGY, "tags": ["en:soybeans"],
		"kw": ["soja", "^soy", "tofu", "tempeh", "=miso", "edamame", "shoyu"]},
	{"id": "milk", "kind": ALLERGY, "tags": ["en:milk"],
		"kw": MILK_KW, "excl": MILK_EXCL, "excl_prev": MILK_PREV},
	{"id": "celery", "kind": ALLERGY, "tags": ["en:celery"],
		"kw": ["sellerie", "celery", "celeriac"]},
	{"id": "mustard", "kind": ALLERGY, "tags": ["en:mustard"],
		"kw": ["senf", "mustard"]},
	{"id": "sesame", "kind": ALLERGY, "tags": ["en:sesame-seeds", "en:sesame"],
		"kw": ["sesam", "sesame", "tahin", "gomasio"]},
	{"id": "sulphites", "kind": ALLERGY, "tags": ["en:sulphur-dioxide-and-sulphites"],
		"kw": ["sulfit", "sulphit", "schwefeldioxid", "schweflige", "=e220", "=e221", "=e222", "=e223",
			"=e224", "=e225", "=e226", "=e227", "=e228", "sulfur dioxide", "sulphur dioxide"]},
	{"id": "lupin", "kind": ALLERGY, "tags": ["en:lupin"],
		"kw": ["lupin"]},
	{"id": "molluscs", "kind": ALLERGY, "tags": ["en:molluscs"],
		"kw": ["muschel", "auster", "oyster", "tintenfisch", "kalmar", "calamar", "oktopus", "octopus",
			"krake", "schnecke", "squid", "mussel", "=clam", "scallop", "weichtier", "mollus"]},
	# --- Unvertraeglichkeiten --------------------------------------------------
	{"id": "lactose", "kind": INTOL, "tags": ["en:milk"],
		"kw": ["milch", "^milk", "molke", "whey", "sahne", "rahm", "joghurt", "jogurt", "yoghurt", "yogurt",
			"quark", "topfen", "kefir", "laktose", "lactose", "schmand", "mascarpone", "ricotta", "mozzarella",
			"skyr", "frischkäse", "frischkaese", "^cream"],
		"excl": MILK_EXCL, "excl_prev": MILK_PREV,
		"free": ["laktosefrei", "lactose free", "ohne laktose", "laktose frei"]},
	{"id": "fructose", "kind": INTOL, "tags": [],
		"kw": ["fruktose", "fructose", "fruchtzucker", "invertzucker", "invert sugar", "isoglukose",
			"honig", "honey", "agave", "dicksaft", "saftkonzentrat", "fruchtkonzentrat", "sorbit", "=e420"]},
	{"id": "sorbitol", "kind": INTOL, "tags": [],
		"kw": ["sorbit", "=e420"]},
	{"id": "caffeine", "kind": INTOL, "tags": [],
		"kw": ["koffein", "coffein", "caffein", "kaffee", "coffee", "espresso", "guarana", "=mate", "matcha",
			"grüntee", "gruentee", "schwarztee", "teeextrakt", "=tee", "=cola", "^colagetränk"],
		"free": ["koffeinfrei", "coffeinfrei", "entkoffeiniert", "decaf", "caffeine free", "ohne koffein"]},
	{"id": "histamine", "kind": INTOL, "tags": [],
		"kw": ["histamin"]},
]

const NEG := ["ohne", "keine", "kein", "keinen", "keiner", "frei", "free", "without", "=no", "sans", "nicht"]

const NAMES := {
	"gluten": ["Gluten / Getreide", "Gluten / cereals"],
	"crustaceans": ["Krebstiere", "Crustaceans"],
	"eggs": ["Eier", "Eggs"],
	"fish": ["Fisch", "Fish"],
	"peanuts": ["Nur Erdnüsse", "Peanuts only"],
	"nuts": ["Nüsse (alle)", "Nuts (all)"],
	"soy": ["Soja", "Soy"],
	"milk": ["Milch (Milcheiweiß)", "Milk (milk protein)"],
	"celery": ["Sellerie", "Celery"],
	"mustard": ["Senf", "Mustard"],
	"sesame": ["Sesam", "Sesame"],
	"sulphites": ["Sulfite", "Sulphites"],
	"lupin": ["Lupinen", "Lupin"],
	"molluscs": ["Weichtiere", "Molluscs"],
	"lactose": ["Laktose", "Lactose"],
	"fructose": ["Fruktose", "Fructose"],
	"sorbitol": ["Sorbit", "Sorbitol"],
	"caffeine": ["Koffein", "Caffeine"],
	"histamine": ["Histamin", "Histamine"],
}

## Kurzformen fuer Banner/Badge.
const SHORT := {
	"gluten": ["Gluten", "Gluten"], "nuts": ["Nüsse", "Nuts"], "peanuts": ["Erdnüsse", "Peanuts"],
	"milk": ["Milch", "Milk"],
}

const EXAMPLES := {
	"gluten": ["Weizen, Roggen, Gerste, Hafer, Dinkel, Malz … – auch bei Zöliakie", "Wheat, rye, barley, oats, spelt, malt … – also for coeliac disease"],
	"crustaceans": ["Garnelen, Krabben, Hummer, Krebse …", "Shrimp, crab, lobster, crayfish …"],
	"eggs": ["Ei, Eigelb, Eiklar, Vollei …", "Egg, yolk, egg white …"],
	"fish": ["Lachs, Thunfisch, Hering, Sardellen …", "Salmon, tuna, herring, anchovies …"],
	"peanuts": ["Nur Erdnüsse und Erdnussöl/-mus", "Only peanuts and peanut oil/butter"],
	"nuts": ["Mandel, Haselnuss, Walnuss, Cashew, Pistazie … inkl. Erdnüsse", "Almond, hazelnut, walnut, cashew, pistachio … incl. peanuts"],
	"soy": ["Soja, Tofu, Tempeh, Edamame, Sojalecithin …", "Soy, tofu, tempeh, edamame, soy lecithin …"],
	"milk": ["Milch, Molke, Butter, Käse, Sahne, Joghurt …", "Milk, whey, butter, cheese, cream, yogurt …"],
	"celery": ["Sellerie, Selleriesalz …", "Celery, celery salt …"],
	"mustard": ["Senf, Senfsaat …", "Mustard, mustard seed …"],
	"sesame": ["Sesam, Tahin …", "Sesame, tahini …"],
	"sulphites": ["Sulfite, Schwefeldioxid, E220–E228 (Wein, Trockenobst …)", "Sulphites, sulphur dioxide, E220–E228 (wine, dried fruit …)"],
	"lupin": ["Lupinen, Lupinenmehl …", "Lupin, lupin flour …"],
	"molluscs": ["Muscheln, Tintenfisch, Oktopus, Schnecken …", "Mussels, squid, octopus, snails …"],
	"lactose": ["Milchzucker – Milch, Sahne, Joghurt, Quark … („laktosefrei“ wird beachtet)", "Milk sugar – milk, cream, yogurt, quark … (“lactose-free” is respected)"],
	"fructose": ["Fruchtzucker, Invertzucker, Honig, Agavendicksaft, Saftkonzentrat, Sorbit …", "Fructose, invert sugar, honey, agave, juice concentrate, sorbitol …"],
	"sorbitol": ["Sorbit / Sorbitol, E420 (z. B. in zuckerfreien Süßwaren)", "Sorbitol, E420 (e.g. in sugar-free sweets)"],
	"caffeine": ["Kaffee, Tee, Mate, Guarana, Cola, Energydrinks …", "Coffee, tea, mate, guarana, cola, energy drinks …"],
	"histamine": ["Nur wenn ausdrücklich angegeben – gereifte/fermentierte Lebensmittel erkennt die Zutatenliste nicht", "Only when explicitly declared – ingredient lists don't reveal matured/fermented foods"],
}

# --- Katalog -------------------------------------------------------------------

static func ids(kind: String = "") -> Array:
	var out: Array = []
	for it in ITEMS:
		if kind == "" or it["kind"] == kind:
			out.append(it["id"])
	return out

static func item(id: String) -> Dictionary:
	for it in ITEMS:
		if it["id"] == id:
			return it
	return {}

static func kind_of(id: String) -> String:
	return str(item(id).get("kind", ""))

static func name(id: String, lang: String = "de") -> String:
	var pair: Array = NAMES.get(id, [id, id])
	return pair[1] if lang == "en" else pair[0]

static func short_name(id: String, lang: String = "de") -> String:
	var pair: Array = SHORT.get(id, NAMES.get(id, [id, id]))
	return pair[1] if lang == "en" else pair[0]

static func examples(id: String, lang: String = "de") -> String:
	var pair: Array = EXAMPLES.get(id, ["", ""])
	return pair[1] if lang == "en" else pair[0]

## Auswahl bereinigen: nur bekannte, keine Doppelten, Katalog-Reihenfolge.
static func sanitize(raw) -> Array:
	var want := {}
	if raw is Array or raw is PackedStringArray:
		for x in raw:
			want[str(x)] = true
	var out: Array = []
	for it in ITEMS:
		if want.has(it["id"]):
			out.append(it["id"])
	return out

# --- Analyse ---------------------------------------------------------------------

static func analyze(f: Food, selected: Array, traces_on: bool = true) -> Dictionary:
	if f == null or selected.is_empty():
		return {"state": "off", "hits": [], "checked": false}
	var found := {}   # id -> "contains" | "trace"
	var checked := false
	if f.curated:
		checked = true
		for spec in f.curated_alerts:
			var s := str(spec)
			var tr := s.begins_with("~")
			_add(found, s.trim_prefix("~"), tr)
	else:
		checked = f.ingredients_text.strip_edges() != "" or not f.allergens_tags.is_empty() \
			or not f.traces_tags.is_empty()
		var full := " . ".join(PackedStringArray([f.ingredients_text, f.name]))
		var norm := normalize(full)
		var toks := tokenize(norm)
		var spaced := " " + " ".join(PackedStringArray(toks.map(func(t): return t["t"]))) + " "
		for it in ITEMS:
			var id: String = it["id"]
			if not selected.has(id):
				continue
			var freed := _claims_free(it, spaced)
			# Allergen-Tags
			for tag in f.allergens_tags:
				var r := _tag_match(it, str(tag))
				if r != "" and not (r == "contains" and freed):
					_add(found, id, false)
			# Spuren-Tags
			for tag in f.traces_tags:
				if _tag_match(it, str(tag)) != "":
					_add(found, id, true)
			# Zutatenliste + Name
			var m := _text_match(it, toks)
			if m["contains"] and not freed:
				_add(found, id, false)
			if m["trace"]:
				_add(found, id, true)
	# Bewerten (nur ausgewaehlte)
	var hits: Array = []
	var red := false
	var orange := false
	for it in ITEMS:
		var id: String = it["id"]
		if not selected.has(id) or not found.has(id):
			continue
		var k := kind_of(id)
		var tr: bool = found[id] == "trace"
		if tr and (k == INTOL or not traces_on):
			continue
		hits.append({"id": id, "kind": k, "trace": tr})
		if k == ALLERGY and not tr:
			red = true
		else:
			orange = true
	hits.sort_custom(func(a, b): return _rank(a) < _rank(b))
	var state := "red" if red else ("orange" if orange else ("none" if checked else "unknown"))
	return {"state": state, "hits": hits, "checked": checked}

static func _rank(h: Dictionary) -> int:
	if h["trace"]:
		return 2
	return 0 if h["kind"] == ALLERGY else 1

static func _add(found: Dictionary, id: String, trace: bool) -> void:
	if trace:
		if not found.has(id):
			found[id] = "trace"
	else:
		found[id] = "contains"

# --- Text ------------------------------------------------------------------------

static func normalize(text: String) -> String:
	var t := text.to_lower()
	for ch in ["_", "*", "•", "\t"]:
		t = t.replace(ch, " ")
	var re := RegEx.new()
	re.compile("\\be\\s*-?\\s*(\\d{3})")
	t = re.sub(t, "e$1", true)
	return t

## Woerter mit Kontext: t (Text), sent (Satz), chunk (Komma-Abschnitt),
## joined (direkt nach dem vorigen Wort, nur Leerzeichen/Bindestrich dazwischen).
static func tokenize(text: String) -> Array:
	var out: Array = []
	var cur := ""
	var sent := 0
	var chunk := 0
	var joined := false
	var pending_joined := true
	for ch in text + " ":
		var c := ch.unicode_at(0)
		var word := (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c > 127
		if word:
			cur += ch
			continue
		if cur != "":
			out.append({"t": cur, "sent": sent, "chunk": chunk, "joined": joined and pending_joined})
			cur = ""
			joined = true
			pending_joined = true
		if ch == " " or ch == "-":
			continue
		pending_joined = false
		if ch in [",", ";", ":", "(", ")", "[", "]", "/", "\n"]:
			chunk += 1
		if ch in [".", ";", "\n", "!", "?"]:
			sent += 1
			chunk += 1
	return out

static func _kw_hit(kw: String, tok: String) -> bool:
	if kw.begins_with("="):
		return tok == kw.substr(1)
	if kw.begins_with("^"):
		return tok.begins_with(kw.substr(1))
	return tok.contains(kw)

## Liefert {contains, trace}.
static func _text_match(it: Dictionary, toks: Array) -> Dictionary:
	var res := {"contains": false, "trace": false}
	if toks.is_empty():
		return res
	var trace_from := _trace_starts(toks)
	var excl: Array = it.get("excl", [])
	var excl_prev: Array = it.get("excl_prev", [])
	for kw in it["kw"]:
		var parts: PackedStringArray = String(kw).split(" ")
		for i in toks.size():
			var ok := true
			for j in parts.size():
				if i + j >= toks.size():
					ok = false
					break
				var p := parts[j]
				var tk: String = toks[i + j]["t"]
				if parts.size() == 1:
					ok = _kw_hit(p, tk)
				elif j < parts.size() - 1:
					ok = tk == p.trim_prefix("=").trim_prefix("^")
				else:
					ok = tk.begins_with(p.trim_prefix("=").trim_prefix("^"))
				if not ok:
					break
			if not ok:
				continue
			var last: String = toks[i + parts.size() - 1]["t"]
			if last.ends_with("frei") or last.ends_with("free") or last.ends_with("freie"):
				continue
			var skip := false
			for e in excl:
				if String(toks[i]["t"]).contains(e):
					skip = true
			if not skip and toks[i]["joined"] and i > 0:
				var prev: String = toks[i - 1]["t"]
				for e in excl_prev:
					if prev.begins_with(e):
						skip = true
			if skip or _negated(toks, i):
				continue
			var t0: int = trace_from.get(toks[i]["sent"], -1)
			if t0 >= 0 and i >= t0:
				res["trace"] = true
			else:
				res["contains"] = true
	return res

## Pro Satz: ab welchem Wort beginnt "kann Spuren … enthalten" / "may contain traces".
static func _trace_starts(toks: Array) -> Dictionary:
	var out := {}
	for i in toks.size():
		var t: String = toks[i]["t"]
		var s: int = toks[i]["sent"]
		if out.has(s):
			continue
		var start := -1
		if t.begins_with("spur") or t.begins_with("trace"):
			start = i
			# "kann (auch) Spuren" -> ab "kann"
			for k in range(maxi(0, i - 3), i):
				if toks[k]["sent"] == s and String(toks[k]["t"]) in ["kann", "können", "koennen", "may", "can"]:
					start = k
					break
		elif t == "may" and i + 1 < toks.size() and String(toks[i + 1]["t"]).begins_with("contain"):
			start = i
		elif t == "enthält" or t == "enthaelt":
			pass
		if start >= 0:
			out[s] = start
	return out

static func _negated(toks: Array, i: int) -> bool:
	var chunk: int = toks[i]["chunk"]
	for k in range(maxi(0, i - 3), i):
		if toks[k]["chunk"] != chunk:
			continue
		var t: String = toks[k]["t"]
		for n in NEG:
			if (n.begins_with("=") and t == n.substr(1)) or (not n.begins_with("=") and t == n):
				return true
	return false

static func _claims_free(it: Dictionary, spaced: String) -> bool:
	for fr in it.get("free", []):
		var phrase := " " + String(fr).replace("-", " ") + " "
		if spaced.contains(phrase):
			return true
		# zusammengeschrieben ("laktosefrei") kommt als ein Wort vor
		if not String(fr).contains(" ") and spaced.contains(" " + String(fr)):
			return true
	return false

## Tag -> "contains" bei Treffer (kanonisch oder per Stichwort im Tag-Text), sonst "".
static func _tag_match(it: Dictionary, tag: String) -> String:
	var t := tag.to_lower().strip_edges()
	if t == "":
		return ""
	if (it.get("tags", []) as Array).has(t):
		return "contains"
	var body := t.substr(t.find(":") + 1) if t.contains(":") else t
	var m := _text_match(it, tokenize(normalize(body.replace("-", " "))))
	return "contains" if m["contains"] or m["trace"] else ""

# --- Texte fuer die Oberflaeche ---------------------------------------------------

## "Milch, Nüsse" fuer eine Trefferliste (Filter: "allergy"/"intolerance"/"trace").
static func list_names(hits: Array, which: String, lang: String = "de") -> String:
	var names: PackedStringArray = []
	for h in hits:
		var tr: bool = h["trace"]
		var match_: bool = (which == "trace" and tr) or (not tr and h["kind"] == which)
		if match_:
			names.append(short_name(h["id"], lang))
	return ", ".join(names)
