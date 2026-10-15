extends Control
class_name App

## Wurzel: Zustand, Navigation, Ablage, Netz-Flows. Screens werden als
## Controls gebaut und ausgetauscht (code-getriebene UI, volle Kontrolle).

const MAX_TRAY := 4

var store: Store
var off: OffClient
var generics: Generics

var tray: Array = []              # Array[Food]
var last_food: Food = null
var last_error: String = ""       # ""|"net"|"rate"|"notfound"
var last_barcode: String = ""

var _current: Control = null
var _current_name: String = ""
var _shot_path: String = ""
var _shot_screen: String = "home"
var _demo: bool = false

func _ready() -> void:
	for c in get_children():
		c.queue_free()
	store = Store.new()
	store.load_all()
	I18n.lang = str(store.settings.get("lang", "de"))
	UI.set_dark(str(store.settings.get("theme", "dark")) == "dark")
	generics = Generics.new()
	generics.load_default()
	off = OffClient.new()
	off.store = store
	add_child(off)
	_load_tray()
	_parse_args()
	if _demo:
		_demo_tray()
	if _shot_path != "":
		DisplayServer.window_set_size(Vector2i(480, 854))
		goto(_shot_screen)
		await _capture_shot()
	else:
		goto("home")

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--screen="):
			_shot_screen = a.substr(9)
		elif a == "--demo":
			_demo = true
	_demo = _demo or _shot_path != ""

## Screenshot-Harness fuer die Entwicklung (--shot=<pfad> --screen=<name> --demo).
func _capture_shot() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_path)
	get_tree().quit()

# --- Navigation -------------------------------------------------------------

func goto(name: String) -> void:
	if _current != null:
		remove_child(_current)
		_current.queue_free()
		_current = null
	_current_name = name
	var node: Control = null
	match name:
		"home": node = HomeScreen.build(self)
		"result": node = ResultScreen.build(self)
		"compare": node = CompareScreen.build(self)
		"history": node = HistoryScreen.build(self)
		"search": node = SearchScreen.build(self)
		"generics": node = GenericsScreen.build(self)
		"about": node = AboutScreen.build(self)
		"settings": node = SettingsScreen.build(self)
		_: node = HomeScreen.build(self)
	_current = node
	add_child(node)

func is_home() -> bool:
	return _current_name == "home"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not is_home():
			goto("home")

# --- Ablage -----------------------------------------------------------------

func tray_add(food: Food) -> bool:
	if food == null:
		return false
	if tray_has(food):
		return true
	if tray.size() >= MAX_TRAY:
		return false
	tray.append(food)
	_save_tray()
	return true

func tray_remove(index: int) -> void:
	if index >= 0 and index < tray.size():
		tray.remove_at(index)
		_save_tray()

func tray_clear() -> void:
	tray.clear()
	_save_tray()

func tray_has(food: Food) -> bool:
	if food == null:
		return false
	for f in tray:
		if f.barcode != "" and f.barcode == food.barcode:
			return true
		if f.barcode == "" and f.name == food.name:
			return true
	return false

func _save_tray() -> void:
	var arr: Array = []
	for f in tray:
		arr.append(f.to_dict())
	store.settings["tray"] = arr
	store.save_settings()

func _load_tray() -> void:
	var arr = store.settings.get("tray", [])
	if arr is Array:
		for d in arr:
			if d is Dictionary:
				tray.append(Food.from_dict(d))

# --- Flows ------------------------------------------------------------------

func open_barcode(barcode: String) -> void:
	last_barcode = barcode
	last_food = null
	last_error = ""
	goto("result")  # zeigt Ladezustand (last_food == null, kein Fehler)
	var res: Dictionary = await off.fetch_product(barcode)
	if res.get("food", null) != null:
		var f: Food = res.food
		last_food = f
		last_error = ""
		store.add_history(f)
		store.save_history()
	else:
		last_error = str(res.get("error", "net"))
	goto("result")

## Loest eine gespeicherte Kennung (Verlauf) wieder zu einem Food auf.
func resolve_barcode(bc: String) -> Food:
	if bc == "":
		return null
	if bc.begins_with("generic:"):
		for g in generics.all():
			if g.barcode == bc:
				return g
		return null
	return store.get_cached(bc)

func open_food(food: Food) -> void:
	last_food = food
	last_error = ""
	last_barcode = food.barcode
	store.add_history(food)
	store.save_history()
	goto("result")

## Manuelle Barcode-Eingabe (Fallback ohne Scanner/Play Services).
func prompt_barcode() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := UI.card(36)
	card.custom_minimum_size = Vector2(840, 0)
	var v := UI.vbox(20)
	v.add_child(UI.micro(I18n.t("barcode")))
	var field := UI.field("z. B. 4001234567890")
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	v.add_child(field)
	var row := UI.hbox(14)
	var ok := UI.button(I18n.t("search"), "primary")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func():
		var bc := field.text.strip_edges()
		overlay.queue_free()
		if bc != "":
			open_barcode(bc))
	row.add_child(ok)
	var cancel := UI.button(I18n.t("close"), "ghost")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func(): overlay.queue_free())
	row.add_child(cancel)
	v.add_child(row)
	card.add_child(v)
	center.add_child(card)
	add_child(overlay)
	field.grab_focus()

func scan() -> void:
	if not Engine.has_singleton("MacroLens"):
		prompt_barcode()
		return
	var ml: Object = Engine.get_singleton("MacroLens")
	if not ml.has_signal("barcode_scanned"):
		return
	if not ml.is_connected("barcode_scanned", _on_barcode_scanned):
		ml.connect("barcode_scanned", _on_barcode_scanned)
	if ml.has_signal("scan_cancelled") and not ml.is_connected("scan_cancelled", _on_scan_cancelled):
		ml.connect("scan_cancelled", _on_scan_cancelled)
	ml.call("scanBarcode")

func _on_barcode_scanned(code: String) -> void:
	open_barcode(code)

func _on_scan_cancelled() -> void:
	pass

## Teilt Text: auf Android via Share-Sheet, am Desktop in die Zwischenablage.
func share_text(text: String) -> void:
	if Engine.has_singleton("MacroLens"):
		Engine.get_singleton("MacroLens").call("shareText", text)
	else:
		DisplayServer.clipboard_set(text)

# --- Theme / Sprache --------------------------------------------------------

func set_dark_mode(dark_mode: bool) -> void:
	store.settings["theme"] = "dark" if dark_mode else "light"
	store.save_settings()
	UI.set_dark(dark_mode)
	goto(_current_name)

func set_lang(l: String) -> void:
	store.settings["lang"] = l
	store.save_settings()
	I18n.lang = l
	goto(_current_name)

# --- Demo (Screenshots) -----------------------------------------------------

func _demo_tray() -> void:
	var by_name := ["Skyr", "Erdnüsse", "Banane", "Haferflocken"]
	for g in generics.all():
		if by_name.has(g.name):
			tray_add(g)
	for f in tray:
		store.add_history(f)
	if _shot_screen == "result" and last_food == null:
		last_food = _demo_food()

func _demo_food() -> Food:
	var f := Food.new()
	f.barcode = "demo"
	f.name = "Knusper-Müsli Nuss"
	f.brand = "Demo-Marke"
	f.quantity = "500 g"
	f.serving_g = 45.0
	f.source = "openfoodfacts"
	f.kcal = 402.0
	f.protein = 9.4
	f.carbs = 61.0
	f.fat = 11.8
	f.fiber = 7.2
	f.sugars = 19.5
	f.saturated = 2.1
	f.salt = 0.28
	return f
