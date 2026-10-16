extends RefCounted
class_name I18n

## Sehr schlankes Woerterbuch DE -> EN. Sprache kommt aus Store.settings["lang"].

static var lang: String = "de"

const STRINGS := {
	"app_name": ["MACRO LENS", "MACRO LENS"],
	"tagline": ["Vier Grafiken statt Nährwerttabelle", "Four charts instead of a nutrition table"],

	"scan": ["SCANNEN", "SCAN"],
	"search": ["SUCHEN", "SEARCH"],
	"unpackaged": ["UNVERPACKT", "UNPACKAGED"],
	"compare": ["VERGLEICH", "COMPARE"],
	"history": ["VERLAUF", "HISTORY"],
	"back": ["ZURÜCK", "BACK"],
	"close": ["SCHLIESSEN", "CLOSE"],
	"about": ["ÜBER", "ABOUT"],
	"about_link": ["Zweck, Grafiken & Kontakt", "Purpose, charts & contact"],
	"settings": ["EINSTELLUNGEN", "SETTINGS"],
	"empty_tray": ["Nichts in der Ablage. Scanne oder suche ein Produkt.", "Nothing in the tray. Scan or search a product."],
	"tray": ["ABLAGE", "TRAY"],
	"full": ["Ablage voll (max. 4)", "Tray full (max. 4)"],
	"already_pinned": ["Schon gepinnt", "Already pinned"],
	"add_to_tray": ["IN ABLAGE", "TO TRAY"],
	"discard": ["VERWERFEN", "DISCARD"],
	"remove": ["ENTFERNEN", "REMOVE"],
	"clear": ["LEEREN", "CLEAR"],
	"search_hint": ["Produktname eingeben …", "Enter product name …"],
	"unpackaged_hint": ["Grundnahrungsmittel durchsuchen …", "Search basic foods …"],
	"no_results": ["Nichts gefunden.", "Nothing found."],
	"searching": ["Suche läuft …", "Searching …"],
	"loading": ["Lade Produkt …", "Loading product …"],
	"not_found": ["Nicht in der Datenbank gefunden.", "Not found in the database."],
	"no_data": ["Keine Nährwerte hinterlegt", "No nutrition data available"],
	"no_name": ["Eintrag ohne Produktnamen", "Entry without a product name"],
	"no_data_hint": ["Open Food Facts hat für dieses Produkt keine Nährwerte. Suche im Netz oder nimm ein Grundnahrungsmittel.", "Open Food Facts has no nutrition data for this product. Search online or pick a basic food."],
	"search_online": ["IM NETZ SUCHEN", "SEARCH ONLINE"],
	"basic_food": ["GRUNDNAHRUNG", "BASIC FOOD"],
	"offline_used": ["Offline aus Speicher", "Offline from cache"],
	"offline_scan": ["Kein Netz — gespeicherte Produkte verfügbar", "No network — cached products available"],
	"error_net": ["Netzwerkfehler. Nochmal versuchen.", "Network error. Try again."],
	"error_rate": ["Zu viele Anfragen. Kurz warten.", "Too many requests. Wait a moment."],
	"retry": ["NOCHMAL", "RETRY"],
	"add_manual": ["SELBST ANLEGEN", "CREATE MANUALLY"],
	"barcode": ["Barcode", "Barcode"],
	"brand": ["Marke", "Brand"],
	"product": ["Produkt", "Product"],

	# Grafiken
	"lbl_macros": ["MAKROS", "MACROS"],
	"lbl_density": ["DICHTE", "DENSITY"],
	"lbl_protein": ["EIWEISS", "PROTEIN"],
	"lbl_satiety": ["SÄTTIGUNG", "SATIETY"],
	"chart_donut": ["WORAUS KOMMEN DIE KALORIEN", "WHERE THE CALORIES COME FROM"],
	"chart_density": ["KALORIENDICHTE", "CALORIE DENSITY"],
	"chart_protein": ["EIWEISSDICHTE", "PROTEIN DENSITY"],
	"chart_satiety": ["SÄTTIGUNG", "SATIETY"],
	"protein": ["Eiweiß", "Protein"],
	"carbs": ["Kohlenhydrate", "Carbs"],
	"fat": ["Fett", "Fat"],
	"protein_short": ["Eiweiß", "Protein"],
	"carbs_short": ["KH", "Carbs"],
	"fat_short": ["Fett", "Fat"],
	"per_100g": ["pro 100 g", "per 100 g"],
	"per_100kcal": ["pro 100 kcal", "per 100 kcal"],
	"kcal_100g": ["kcal/100 g", "kcal/100 g"],
	"of_100": ["von 100", "of 100"],
	"unit_g_100kcal": ["g/100 kcal", "g/100 kcal"],
	"estimate": ["Schätzung", "Estimate"],
	"estimate_nofiber": ["Schätzung (ohne Ballaststoffe)", "Estimate (without fiber)"],
	"fiber": ["Ballaststoffe", "Fiber"],
	"sugar": ["Zucker", "Sugar"],
	"sat_fat": ["davon gesättigt", "of which saturates"],
	"salt": ["Salz", "Salt"],
	"serving": ["Portion", "Serving"],
	"unit_100g": ["100 g", "100 g"],
	"portion": ["Portion", "Serving"],
	"package": ["Packung", "Package"],
	"more_numbers": ["WEITERE ZAHLEN", "MORE NUMBERS"],
	"macro_estimated": ["Donut aus Makros berechnet", "Donut computed from macros"],
	"best": ["BEST", "BEST"],
	"worst": ["SCHLECHT", "WORST"],
	"new": ["NEU", "NEW"],

	"compare_title": ["VERGLEICH", "COMPARE"],
	"compare_need": ["Mindestens 2 Produkte für den Vergleich.", "At least 2 products to compare."],

	"history_title": ["VERLAUF", "HISTORY"],
	"history_empty": ["Noch nichts gescannt.", "Nothing scanned yet."],
	"clear_history": ["VERLAUF LEEREN", "CLEAR HISTORY"],
	"confirm_clear": ["Verlauf wirklich leeren?", "Really clear history?"],

	"settings_title": ["EINSTELLUNGEN", "SETTINGS"],
	"theme": ["Darstellung", "Appearance"],
	"theme_dark": ["Dunkel", "Dark"],
	"theme_light": ["Hell", "Light"],
	"language": ["Sprache", "Language"],

	"about_text": ["Schneller die bessere Wahl im Supermarkt.", "Faster, better choices in the supermarket."],
	"contact": ["Kontakt", "Contact"],
	"about_body": [
		"Für alle, die bewusst einkaufen: Das Angebot im Supermarkt ist riesig, die Zeit am Regal kurz. Macro Lens filtert schnell – Barcode scannen, vier Grafiken sehen, bis zu vier Produkte vergleichen.\nBewusst ohne Mengen und ohne Tracking: ein Messgerät, kein Tagebuch.\nKeine Konten, keine Cloud, keine Werbung, keine Telemetrie. Sättigung ist eine Schätzung.",
		"For health-conscious shoppers: supermarket shelves are crowded, time in the aisle is short. Macro Lens filters fast – scan a barcode, see four charts, compare up to four products.\nDeliberately no quantities and no tracking: a measuring device, not a diary.\nNo accounts, no cloud, no ads, no telemetry. Satiety is an estimate."],
	"attribution": ["Daten: Open Food Facts (ODbL) · Generika: USDA FoodData Central", "Data: Open Food Facts (ODbL) · Basics: USDA FoodData Central"],

	"scan_hint": ["Barcode scannen", "Scan barcode"],
	"scan_unavailable": ["Scanner nur auf Android verfügbar.", "Scanner only available on Android."],
}

static func t(key: String) -> String:
	if not STRINGS.has(key):
		return key
	var pair: Array = STRINGS[key]
	return pair[1] if lang == "en" else pair[0]
