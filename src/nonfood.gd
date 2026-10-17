extends RefCounted
class_name NonFood

## Produkte, die Open Food Facts nicht kennt, aber Open Products Facts bzw.
## Open Beauty Facts. Kein Food-Objekt: kommt nie in Verlauf, Ablage oder
## Naehrwert-Cache. Ergebnis ist ein schlichtes Dictionary (JSON-tauglich):
##   {barcode, name, brand, kind, source}
##
## Kategorien in den Datenbanken sind oft leer oder verrauscht (z. B. Creme mit
## "en:baby-foods"). Deshalb werden Kategorien UND Produktname nach Stichworten
## durchsucht; die Quelle ist der Rueckfall (Open Beauty Facts -> Kosmetik).

## Reihenfolge = Prioritaet. Stichworte < 6 Zeichen muessen am Wortanfang
## stehen ("hair" trifft "haircare", aber nicht "chair"), laengere duerfen
## irgendwo vorkommen (deutsche Komposita: "fluessigwaschmittel").
const RULES := [
	["cleaning", ["detergent", "lessive", "waschmittel", "spülmittel", "spuelmittel", "cleaning", "cleaner",
		"reiniger", "laundry", "dishwash", "household-chemical", "disinfect", "desinfekt", "weichspül",
		"softener", "entkalk", "bleach", "javel", "putzmittel"]],
	["pet", ["pet-food", "petfood", "dog-food", "cat-food", "hundefutter", "katzenfutter", "tierfutter",
		"animal-food", "dog", "cat", "hund", "katze"]],
	["tobacco", ["tobacco", "tabak", "cigarette", "zigarette", "e-liquid"]],
	["battery", ["batter", "akku"]],
	["oral", ["toothpaste", "zahnpasta", "zahncreme", "mouthwash", "mundspül", "dentifrice"]],
	["hair", ["shampoo", "conditioner", "hair", "haar"]],
	["cosmetic", ["cosmetic", "kosmetik", "cosmétique", "cream", "creme", "crème", "lotion", "soap",
		"seife", "deodor", "dusch", "shower", "skin", "make-up", "makeup", "parfum", "perfume", "beauty",
		"sonnenschutz", "sunscreen"]],
]

const KINDS := ["cleaning", "pet", "tobacco", "battery", "oral", "hair", "cosmetic", "other"]

const MESSAGES := {
	"cleaning": ["Putzmittel ist kein Frühstück. Bitte nicht essen.",
		"Cleaning products are not breakfast. Please don't eat them."],
	"pet": ["Für Hund und Katze gedacht – nicht für dich.",
		"Made for cats and dogs – not for you."],
	"tobacco": ["Rauch ist keine Mahlzeit. Hier gibt's keine Makros.",
		"Smoke is not a meal. No macros here."],
	"battery": ["Batterien sind kein Snack – auch nicht die kleinen.",
		"Batteries are not a snack – not even the small ones."],
	"oral": ["Zahnpasta wird ausgespuckt, nicht gegessen.",
		"Toothpaste gets spat out, not eaten."],
	"hair": ["Shampoo ist kein Smoothie. Bitte nicht trinken.",
		"Shampoo is not a smoothie. Please don't drink it."],
	"cosmetic": ["Gehört auf die Haut, nicht auf den Teller.",
		"Goes on your skin, not on your plate."],
	"other": ["Kein Lebensmittel – auch nicht mit viel Ketchup.",
		"Not food – not even with plenty of ketchup."],
}

const LABELS := {
	"cleaning": ["Putzmittel", "Cleaning product"],
	"pet": ["Tierfutter", "Pet food"],
	"tobacco": ["Tabak", "Tobacco"],
	"battery": ["Batterie", "Battery"],
	"oral": ["Zahnpflege", "Oral care"],
	"hair": ["Haarpflege", "Hair care"],
	"cosmetic": ["Kosmetik", "Cosmetics"],
	"other": ["Haushaltsprodukt", "Household product"],
}

const SOURCE_NAMES := {
	"openproductsfacts": "Open Products Facts",
	"openbeautyfacts": "Open Beauty Facts",
}

static func from_product(p: Dictionary, source: String, barcode: String) -> Dictionary:
	var name := _first_text([p.get("product_name", ""), p.get("product_name_de", ""),
		p.get("product_name_en", ""), p.get("generic_name", "")])
	var brand := str(p.get("brands", "")).strip_edges()
	if brand.contains(","):
		brand = brand.split(",")[0].strip_edges()
	var tags: Array = p.get("categories_tags", []) if p.get("categories_tags", []) is Array else []
	var cats := str(p.get("categories", ""))
	return {
		"barcode": str(p.get("code", barcode)) if str(p.get("code", "")) != "" else barcode,
		"name": name,
		"brand": brand,
		"kind": classify(tags, cats, name, source),
		"source": source,
	}

static func classify(tags: Array, categories: String, name: String, source: String) -> String:
	var parts: PackedStringArray = []
	for t in tags:
		parts.append(str(t))
	parts.append(categories)
	parts.append(name)
	var text := " ".join(parts).to_lower()
	var words := _words(text)
	for rule in RULES:
		for kw in rule[1]:
			if _matches(text, words, String(kw)):
				return rule[0]
	return "cosmetic" if source == "openbeautyfacts" else "other"

static func _matches(text: String, words: PackedStringArray, kw: String) -> bool:
	if kw.length() >= 6:
		return text.contains(kw)
	for w in words:
		if w.begins_with(kw):
			return true
	return false

static func _words(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var cur := ""
	for ch in text:
		var c := ch.unicode_at(0)
		var is_word := (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c > 127
		if is_word:
			cur += ch
		elif cur != "":
			out.append(cur)
			cur = ""
	if cur != "":
		out.append(cur)
	return out

static func _first_text(values: Array) -> String:
	for v in values:
		var s := str(v).strip_edges()
		if s != "" and s.to_lower() != "null":
			return s
	return ""

static func message(kind: String, lang: String = "de") -> String:
	var pair: Array = MESSAGES.get(kind, MESSAGES["other"])
	return pair[1] if lang == "en" else pair[0]

static func label(kind: String, lang: String = "de") -> String:
	var pair: Array = LABELS.get(kind, LABELS["other"])
	return pair[1] if lang == "en" else pair[0]

static func source_name(source: String) -> String:
	return SOURCE_NAMES.get(source, source)
