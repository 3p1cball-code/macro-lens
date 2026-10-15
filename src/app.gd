extends Control
class_name App

## Wurzel: Zustand, Navigation, Ablage (gepinnte Produkte), Scan-Flow.
## Standard-Screen ist der Dauerscan ("live"). Kein Hauptmenue.

const MAX_TRAY := 4
const CAM_FRACTION := 0.30
const SCAN_DEBOUNCE_MS := 2500

var store: Store
var off: OffClient
var generics: Generics

var tray: Array = []              # gepinnte Vergleichsprodukte (max 4)
var current: Food = null          # zuletzt gescannt/gewaehlt (noch nicht gepinnt)
var scan_status: String = ""      # Meldung im Live-Screen ("", "notfound", "rate", "net")

var _current_screen: Control = null
var _current_name: String = ""
var _last_code: String = ""
var _last_code_ms: int = 0
var _shot_path: String = ""
var _shot_screen: String = "live"
var _demo: bool = false
var _no_demo: bool = false
var _single: bool = false
var _two: bool = false

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
	_connect_plugin()
	_parse_args()
	if _demo:
		_demo_data()
	if _shot_path != "":
		DisplayServer.window_set_size(Vector2i(480, 854))
		goto(_shot_screen)
		await _capture_shot()
	else:
		goto("live")

# --- Plugin ----------------------------------------------------------------

func _connect_plugin() -> void:
	if not Engine.has_singleton("MacroLens"):
		return
	var ml: Object = Engine.get_singleton("MacroLens")
	if ml.has_signal("barcode_scanned") and not ml.is_connected("barcode_scanned", on_scanned):
		ml.connect("barcode_scanned", on_scanned)
	if ml.has_signal("scan_failed") and not ml.is_connected("scan_failed", _on_scan_failed):
		ml.connect("scan_failed", _on_scan_failed)

func has_scanner() -> bool:
	return Engine.has_singleton("MacroLens")

func start_preview() -> void:
	if has_scanner():
		Engine.get_singleton("MacroLens").call("startPreview", CAM_FRACTION)

func stop_preview() -> void:
	if has_scanner():
		Engine.get_singleton("MacroLens").call("stopPreview")

func _on_scan_failed(_msg: String) -> void:
	pass

# --- Navigation ------------------------------------------------------------

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--screen="):
			_shot_screen = a.substr(9)
		elif a == "--demo":
			_demo = true
		elif a == "--single":
			_single = true
		elif a == "--two":
			_two = true
		elif a == "--empty":
			_demo = false
			_no_demo = true
	_demo = (_demo or _shot_path != "") and not _no_demo

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

func goto(name: String) -> void:
	if name == "home":
		name = "live"
	if _current_screen != null:
		remove_child(_current_screen)
		_current_screen.queue_free()
		_current_screen = null
	_current_name = name
	var node: Control = null
	match name:
		"live":
			var ls := LiveScreen.new()
			ls.app = self
			ls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			node = ls
		"generics": node = GenericsScreen.build(self)
		"search": node = SearchScreen.build(self)
		"history": node = HistoryScreen.build(self)
		"about": node = AboutScreen.build(self)
		"settings": node = SettingsScreen.build(self)
		_:
			var fallback := LiveScreen.new()
			fallback.app = self
			node = fallback
	_current_screen = node
	add_child(node)
	if name == "live":
		start_preview()
	else:
		stop_preview()

func is_live() -> bool:
	return _current_name == "live"

func refresh_live() -> void:
	if _current_screen != null and _current_screen.has_method("refresh"):
		_current_screen.call("refresh")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not is_live():
			goto("live")

# --- Scan-Flow -------------------------------------------------------------

func on_scanned(code: String) -> void:
	if code.strip_edges() == "":
		return
	var now := Time.get_ticks_msec()
	if code == _last_code and now - _last_code_ms < SCAN_DEBOUNCE_MS:
		return
	_last_code = code
	_last_code_ms = now
	# Bereits gepinnt oder aktuell -> ignorieren
	if current != null and current.barcode == code:
		return
	for f in tray:
		if f.barcode == code:
			return
	var cached := store.get_cached(code)
	if cached != null:
		_show_current(cached)
		return
	scan_status = "loading"
	refresh_live()
	var res: Dictionary = await off.fetch_product(code)
	if res.get("food", null) != null:
		_show_current(res.food)
	else:
		scan_status = str(res.get("error", "net"))
		refresh_live()

func _show_current(food: Food) -> void:
	current = food
	scan_status = ""
	store.add_history(food)
	store.save_history()
	refresh_live()

func set_current(food: Food) -> void:
	if food == null:
		return
	current = food
	scan_status = ""
	refresh_live()

func pin_current() -> void:
	if current == null or tray.size() >= MAX_TRAY:
		return
	if not tray_has(current):
		tray.append(current)
		_save_tray()
	current = null
	scan_status = ""
	refresh_live()

func unpin(index: int) -> void:
	if index >= 0 and index < tray.size():
		tray.remove_at(index)
		_save_tray()
		refresh_live()

func add_pinned(food: Food) -> void:
	if food == null or tray.size() >= MAX_TRAY or tray_has(food):
		return
	tray.append(food)
	_save_tray()
	store.add_history(food)
	store.save_history()
	refresh_live()

func tray_has(food: Food) -> bool:
	if food == null:
		return false
	for f in tray:
		if f.barcode != "" and f.barcode == food.barcode:
			return true
		if f.barcode == "" and f.name == food.name:
			return true
	return false

func clear_tray() -> void:
	tray.clear()
	_save_tray()
	refresh_live()

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

# --- Teilen ----------------------------------------------------------------

func share_text(text: String) -> void:
	if has_scanner():
		Engine.get_singleton("MacroLens").call("shareText", text)
	else:
		DisplayServer.clipboard_set(text)

func share_comparison() -> void:
	var cols: Array = []
	for f in tray:
		cols.append(f)
	var lines: Array = ["Macro Lens"]
	for f in cols:
		var ev := Metrics.evaluate(f)
		var parts: Array = [f.display_name(I18n.lang)]
		if ev.density_ok:
			parts.append(Metrics.format_num(ev.density, 0) + " kcal/100 g")
		if ev.protein_density_ok:
			parts.append(Metrics.format_num(ev.protein_density, 1) + " g " + I18n.t("protein"))
		if ev.fullness_ok:
			parts.append(I18n.t("chart_satiety") + " " + str(ev.fullness.get("score", 0)) + "/100")
		lines.append("• " + " · ".join(parts))
	lines.append(I18n.t("attribution"))
	share_text("\n".join(lines))

# --- Manuelle Eingabe ------------------------------------------------------

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
		goto("live")
		if bc != "":
			on_scanned(bc))
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

func _demo_data() -> void:
	tray.clear()
	var by_name := ["Skyr", "Erdnüsse", "Banane"]
	for g in generics.all():
		if by_name.has(g.name):
			tray.append(g)
	if _single:
		tray.clear()
	if _two:
		while tray.size() > 1:
			tray.pop_back()
	if _shot_screen == "live":
		current = _demo_food()
		scan_status = ""

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
