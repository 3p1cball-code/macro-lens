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
var scan_status: String = ""      # "", "loading", "nodata", "notfound", "rate", "net"
var last_scan_code: String = ""   # fuer "Nochmal"
var last_missing: Food = null     # gefunden, aber ohne Naehrwerte
var pending_search: String = ""   # Vorbelegung fuer den Suche-Screen

var _current_screen: Control = null
var _current_name: String = ""
var _last_code: String = ""
var _last_code_ms: int = 0
var _shot_path: String = ""
var _shot_screen: String = "live"
var _shot_size: Vector2i = Vector2i.ZERO
var _anim_at: float = -1.0           # --anim-at=SEK: Animation mitten im Lauf fotografieren
var _demo: bool = false
var _no_demo: bool = false
var _single: bool = false
var _two: bool = false
var _nodata: bool = false

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
	Anim.enabled = _shot_path == "" or _anim_at >= 0.0
	if _demo:
		_demo_data()
	if _shot_path != "":
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
		elif a.begins_with("--shot-size="):
			var wh := a.substr(12).split("x")
			if wh.size() == 2:
				_shot_size = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--anim-at="):
			_anim_at = float(a.substr(10))
		elif a == "--demo":
			_demo = true
		elif a == "--single":
			_single = true
		elif a == "--two":
			_two = true
		elif a == "--nodata":
			_nodata = true
		elif a == "--empty":
			_demo = false
			_no_demo = true
		elif a.begins_with("--lang="):
			var l := a.substr(7)
			if l == "en" or l == "de":
				store.settings["lang"] = l
				I18n.lang = l
		elif a == "--light":
			store.settings["theme"] = "light"
			UI.set_dark(false)
	_demo = (_demo or _shot_path != "") and not _no_demo

func _capture_shot() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(_anim_at if _anim_at >= 0.0 else 0.6).timeout
	var img: Image
	if _shot_size != Vector2i.ZERO:
		# Exakte Groesse unabhaengig von der Fenstergroesse (fuer Store-Assets).
		var sv := SubViewport.new()
		sv.size = _shot_size
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sv.transparent_bg = false
		add_child(sv)
		if _current_screen != null:
			remove_child(_current_screen)
			sv.add_child(_current_screen)
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(true)
		await get_tree().process_frame
		img = sv.get_texture().get_image()
	else:
		RenderingServer.force_draw(false)
		await get_tree().process_frame
		img = get_viewport().get_texture().get_image()
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
	Anim.fade_in(node, 0.16)
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
			go_back()

## Zurueck: Unterseiten der Einstellungen fuehren dorthin, alles andere zum Scan.
func go_back() -> void:
	goto("settings" if _current_name == "about" else "live")

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
	last_scan_code = code
	var cached := store.get_cached(code)
	if cached != null and cached.has_kcal() and cached.has_macros():
		_show_current(cached)
		return
	# Unbekannt ODER unvollstaendig gespeichert (z. B. aeltere Eintraege) -> nachladen.
	scan_status = "loading"
	refresh_live()
	var res: Dictionary = await off.fetch_product(code, cached != null)
	var food: Food = res.get("food", null)
	if food == null and cached != null:
		food = cached
	if food == null:
		scan_status = str(res.get("error", "net"))
		last_missing = null
		refresh_live()
		return
	# Gefunden, aber unbrauchbar (kein Name und/oder keine Naehrwerte) ->
	# nicht als Spalte aufnehmen, sondern klar melden und Auswege anbieten.
	# (Kein Ergebnis ohne Produktnamen.)
	if food.name.strip_edges() == "":
		last_missing = food
		scan_status = "noname"
		refresh_live()
		return
	if not food.has_kcal() and not food.has_macros():
		last_missing = food
		scan_status = "nodata"
		refresh_live()
		return
	_show_current(food)

## Manuelles Wiederholen eines fehlgeschlagenen Scans (umgeht den Debounce).
func retry_scan() -> void:
	if last_scan_code == "":
		return
	_last_code = ""
	on_scanned(last_scan_code)

func _show_current(food: Food) -> void:
	current = food
	scan_status = ""
	_remember(food)
	refresh_live()

## Food im Verlauf vermerken und (falls OFF) im Cache halten, damit der
## Verlauf es spaeter ohne Netz wieder aufloesen kann.
func _remember(food: Food) -> void:
	if food == null:
		return
	if food.barcode != "" and not food.barcode.begins_with("generic:") \
			and food.source != "user" and store.get_cached(food.barcode) == null:
		store.put_cache(food)
		store.save_cache()
	store.add_history(food)
	store.save_history()

## Food zu einem Verlaufs-Barcode: Generika, Cache, eigene Eintraege.
func resolve_barcode(code: String) -> Food:
	if code == "":
		return null
	if code.begins_with("generic:"):
		for f in generics.all():
			if f.barcode == code:
				return f
		return null
	var c := store.get_cached(code)
	if c != null:
		return c
	if store.user_foods.has(code):
		return Food.from_dict(store.user_foods[code])
	return null

## Aus einer Liste gewaehlt (Verlauf/Suche/Generika): anzeigen oder pinnen.
## Ist das Food nicht aufloesbar, wird der Barcode wie ein Scan nachgeladen.
func pick(food: Food, code: String, pin: bool) -> void:
	goto("live")
	if food == null:
		if code == "" or code.begins_with("generic:"):
			toast(I18n.t("not_found"))
			return
		if pin and tray.size() >= MAX_TRAY:
			toast(I18n.t("full"))
			return
		_last_code = ""
		await on_scanned(code)
		if pin and current != null and current.barcode == code:
			pin_current()
		return
	if pin:
		add_pinned(food)
	else:
		set_current(food)

func set_current(food: Food) -> void:
	if food == null:
		return
	current = food
	scan_status = ""
	_remember(food)
	refresh_live()

func pin_current() -> void:
	if current == null:
		return
	if tray.size() >= MAX_TRAY:
		toast(I18n.t("full"))
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
	if food == null:
		return
	if tray_has(food):
		toast(I18n.t("already_pinned"))
		return
	if tray.size() >= MAX_TRAY:
		toast(I18n.t("full"))
		return
	tray.append(food)
	_save_tray()
	# Dasselbe Produkt nicht zusaetzlich als "neue" Spalte zeigen.
	if current != null and _same(current, food):
		current = null
	scan_status = ""
	_remember(food)
	refresh_live()

static func _same(a: Food, b: Food) -> bool:
	if a.barcode != "" or b.barcode != "":
		return a.barcode == b.barcode
	return a.name == b.name

## Kurze Meldung unten im Bild, blendet sich selbst aus.
func toast(text: String) -> void:
	var old := get_node_or_null("Toast")
	if old != null:
		old.name = "ToastOld"
		old.queue_free()
	var panel := PanelContainer.new()
	panel.name = "Toast"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = UI.c("text")
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	var l := UI.label(text.to_upper(), UI.FS_MICRO, "bg", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(l)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.80
	panel.anchor_bottom = 0.80
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	Anim.pop_in(panel, 0.0, 0.22)
	var tw := panel.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(panel, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(panel.queue_free)

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
	var field := UI.field("4001234567890")
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
	if _nodata:
		var f := _demo_food()
		f.kcal = -1.0
		f.protein = -1.0
		f.carbs = -1.0
		f.fat = -1.0
		f.fiber = -1.0
		last_missing = f
		scan_status = "nodata"
	elif _shot_screen == "live":
		current = _demo_food()
		scan_status = ""

func _demo_food() -> Food:
	var f := Food.new()
	f.barcode = "demo"
	f.name = "Knusper-Müsli Nuss"
	f.brand = "Demo"
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
