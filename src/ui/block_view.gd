extends RefCounted
class_name BlockView

## Zeichnet Bausteine: eine Zeile = Titel links + eine Zelle pro Produkt.
## Live-Seite und Editor nutzen dieselben Bausteine; die Live-Seite reicht
## zusaetzlich einen Wrapper (Wischgesten) und eine Verzoegerung (Aufbau-
## Animation) durch.
##
## Groessen richten sich nach dem Platz: Die Hauptseite scrollt nicht, also
## bekommt jeder Baustein ein Hoehenbudget. Bei bis zu 4 Bausteinen reicht es
## fuer die bisherige, grosszuegige Darstellung; bei 5 rueckt "BEST" in die
## Einheitenzeile und die Zahlen werden etwas kleiner.

const GUTTER := 150
const ROW_SEP := 8          # Abstand im Matrix-VBox
const NUM_BASE := [96, 92, 78, 64]
const DONUT_BASE := [200, 142, 144, 128]
const LINE_K := 1.37        # Zeilenhoehe / Schriftgroesse (Open Sans)

## Zellgroessen fuer einen Baustein bei `budget` px Hoehe und n Spalten.
static func sizes(kind: String, n: int, budget: float, opts: Dictionary = {}) -> Dictionary:
	var ci := clampi(n - 1, 0, 3)
	var num_base: int = NUM_BASE[ci]
	match kind:
		"donut":
			return {"donut": int(clampf(budget - 16.0, 96.0, DONUT_BASE[ci])), "legend": n <= 2}
		"ampel":
			var rows := 0
			for k in Blocks.AMPEL_ROWS:
				if bool(opts.get(k, false)):
					rows += 1
			rows = maxi(rows, 1)
			var lh := clampf((budget - 8.0) / rows, 26.0, 42.0)
			# Ab 3 Spalten stehen die Zeilennamen links, in den Zellen nur Punkt + Wert.
			return {"line": int(lh), "font": UI.FS_MICRO if lh >= 32.0 else 22, "labels": n <= 2}
		_:
			var roomy := budget >= num_base * LINE_K + 128.0
			var num := num_base if roomy else int(clampf((budget - 82.0) / LINE_K, 36.0, num_base))
			return {"num": num, "compact": not roomy, "bar": 26.0 if roomy else 20.0}

## Hoehenbudget pro Baustein aus der verfuegbaren Hoehe.
static func budget(avail: float, blocks: int) -> float:
	var b := maxi(blocks, 1)
	return (avail - b * (ROW_SEP * 2 + 1)) / b

## Eine Bausteinzeile.
## wrap: func(col: int, control: Control) -> Control  (Gesten-Huelle; optional)
## delay: func(col: int) -> float  (< 0 = keine Animation; optional)
static func block_row(entry: Dictionary, foods: Array, ctx: Dictionary, sz: Dictionary,
		wrap: Callable = Callable(), delay: Callable = Callable()) -> Control:
	var id: String = entry["id"]
	var opts: Dictionary = entry.get("options", {})
	var kind := Blocks.kind(id)
	var displays: Array = []
	for f in foods:
		displays.append(Blocks.evaluate(id, f, opts, ctx))
	var best := -1
	if bool(opts.get("best", false)):
		best = Blocks.best_index(displays)
	var rmax := Blocks.row_max(displays) if kind == "bar" else 100.0
	var cells: Array = []
	for i in foods.size():
		var d: float = delay.call(i) if delay.is_valid() else -1.0
		var c := cell(kind, displays[i], sz, i == best, rmax, d)
		cells.append(wrap.call(i, c) if wrap.is_valid() else c)
	if kind == "ampel" and not bool(sz.get("labels", true)):
		return row_with_gutter(_ampel_gutter(opts, sz), cells)
	return row(Blocks.title(id), cells)

static func row_with_gutter(gutter: Control, cells: Array) -> Control:
	var r := UI.hbox(12)
	gutter.custom_minimum_size = Vector2(GUTTER, 0)
	r.add_child(gutter)
	for c in cells:
		r.add_child(c)
	return r

## Zeilennamen der Ampel links, auf gleicher Hoehe wie die Punkte.
static func _ampel_gutter(opts: Dictionary, sz: Dictionary) -> Control:
	var v := UI.vbox(0)
	var line: int = sz.get("line", 34)
	var font: int = sz.get("font", UI.FS_MICRO)
	for k in Blocks.AMPEL_ROWS:
		if not bool(opts.get(k, false)):
			continue
		var l := UI.label(I18n.t("row_" + k).to_upper(), font - 2, "muted", 1)
		l.custom_minimum_size = Vector2(0, line)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(l)
	return v

static func row(label_text: String, cells: Array) -> Control:
	var r := UI.hbox(12)
	var lbl := UI.label(label_text, UI.FS_MICRO, "muted", 1)
	lbl.custom_minimum_size = Vector2(GUTTER, 0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r.add_child(lbl)
	for c in cells:
		r.add_child(c)
	return r

static func cell(kind: String, d: Dictionary, sz: Dictionary, best: bool, rmax: float, delay: float) -> Control:
	match kind:
		"donut": return donut_cell(d, sz, delay)
		"fatq": return fatq_cell(d, sz, best, delay)
		"ampel": return ampel_cell(d, sz, delay)
	return bar_cell(d, sz, best, rmax, delay)

# --- Zellen -------------------------------------------------------------------

static func donut_cell(d: Dictionary, sz: Dictionary, delay: float) -> Control:
	var h: int = sz.get("donut", 140)
	var show_legend: bool = sz.get("legend", false)
	var cell := UI.hbox(18 if show_legend else 0)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if show_legend:
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
	var donut := MacroDonut.new()
	donut.custom_minimum_size = Vector2(h, h)
	donut.ring_width = h * 0.16
	var center: String = str(d.get("center", "auto"))
	if center == "auto":
		donut.center_mode = "none" if show_legend else "protein"
	else:
		donut.center_mode = center
	if d.get("ok", false):
		donut.set_split(d["split"])
	cell.add_child(donut)
	if delay >= 0.0:
		Anim.sweep(donut, "progress", delay + 0.05)
	if show_legend and d.get("ok", false):
		var split: Dictionary = d["split"]
		var legend := UI.vbox(10 if bool(split.get("sugar_split", false)) else 12)
		legend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(_legend_row("protein_short", "protein", float(split.get("protein", 0.0))))
		if bool(split.get("sugar_split", false)):
			legend.add_child(_legend_row("sugar_short", "sugar", float(split.get("sugar", 0.0))))
			legend.add_child(_legend_row("starch_short", "carbs", float(split.get("starch", 0.0))))
		else:
			legend.add_child(_legend_row("carbs_short", "carbs", float(split.get("carbs", 0.0))))
		legend.add_child(_legend_row("fat_short", "fat", float(split.get("fat", 0.0))))
		cell.add_child(legend)
	return cell

static func _legend_row(name_key: String, color_key: String, share: float) -> Control:
	var r := UI.hbox(10)
	var sw := ColorRect.new()
	sw.color = UI.c(color_key)
	sw.custom_minimum_size = Vector2(20, 20)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(sw)
	var nm := UI.label(I18n.t(name_key), UI.FS_MICRO, "muted", 1)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size = Vector2(92, 0)
	r.add_child(nm)
	r.add_child(UI.label(str(roundi(share * 100.0)) + " %", UI.FS_BODY, "text", 2))
	return r

static func bar_cell(d: Dictionary, sz: Dictionary, best: bool, rmax: float, delay: float) -> Control:
	var ok: bool = d.get("ok", false)
	var compact: bool = sz.get("compact", false)
	var num_size: int = sz.get("num", 64)
	var col: Color = d.get("color", UI.c("faint")) if ok else UI.c("faint")
	var raw: float = d.get("value", -1.0) if ok else -1.0
	var dec: int = d.get("decimals", 0)
	var c := UI.vbox(4 if compact else 6)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var num := UI.big_number_colored(Metrics.format_num(raw, dec) if raw >= 0.0 else "–", col, num_size)
	num.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	num.clip_text = true
	c.add_child(num)
	var unit_row := UI.hbox(6)
	var unit := UI.micro(str(d.get("note", "")) if not ok and str(d.get("note", "")) != "" else str(d.get("unit", "")))
	unit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	unit_row.add_child(unit)
	var chip: Control = null
	if best and compact:
		chip = UI.chip(I18n.t("best"), "good")
		unit_row.add_child(chip)
	c.add_child(unit_row)
	var bar := MeterBar.new()
	bar.bar_h = float(sz.get("bar", 26.0))
	bar.set_value(raw, maxf(rmax, 0.0001), "", col)
	c.add_child(bar)
	if best and not compact:
		var h := UI.hbox(0)
		chip = UI.chip(I18n.t("best"), "good")
		h.add_child(chip)
		c.add_child(h)
	if delay >= 0.0 and raw >= 0.0:
		var dd := delay + 0.05
		Anim.count_up(num, raw, dec, dd)
		Anim.sweep(bar, "progress", dd)
		if chip != null:
			Anim.pop_in(chip, dd + Anim.BUILD * 0.8, Anim.POP, 0.6)
	return c

## Fettqualitaet: Anteil gesaettigt (Zahl) + zweifarbiger Balken gesaettigt/ungesaettigt.
static func fatq_cell(d: Dictionary, sz: Dictionary, best: bool, delay: float) -> Control:
	var ok: bool = d.get("ok", false)
	var compact: bool = sz.get("compact", false)
	var c := UI.vbox(4 if compact else 6)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var raw: float = d.get("value", -1.0) if ok else -1.0
	var col: Color = d.get("color", UI.c("faint")) if ok else UI.c("faint")
	var num := UI.big_number_colored(Metrics.format_num(raw, 0) + (" %" if raw >= 0.0 else "") if raw >= 0.0 else "–",
		col, sz.get("num", 64))
	num.clip_text = true
	c.add_child(num)
	var unit_row := UI.hbox(6)
	var note := str(d.get("note", ""))
	var unit := UI.micro(note if not ok and note != "" else I18n.t("u_pct_sat"))
	unit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	unit_row.add_child(unit)
	if best and compact:
		unit_row.add_child(UI.chip(I18n.t("best"), "good"))
	c.add_child(unit_row)
	var bar := SplitBar.new()
	bar.bar_h = float(sz.get("bar", 26.0))
	bar.share = float(d.get("share", -1.0)) if ok else -1.0
	bar.left_color = col
	c.add_child(bar)
	if best and not compact:
		var h := UI.hbox(0)
		h.add_child(UI.chip(I18n.t("best"), "good"))
		c.add_child(h)
	if delay >= 0.0 and ok:
		Anim.sweep(bar, "progress", delay + 0.05)
	return c

## Ampel: eine Zeile je Naehrstoff - Punkt in Ampelfarbe, Kurzname, Wert.
static func ampel_cell(d: Dictionary, sz: Dictionary, delay: float) -> Control:
	var v := UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line: int = sz.get("line", 34)
	var font: int = sz.get("font", UI.FS_MICRO)
	var labels: bool = sz.get("labels", true)
	for r in d.get("rows", []):
		var h := UI.hbox(8)
		h.custom_minimum_size = Vector2(0, line)
		var dot := Dot.new()
		dot.color = r["color"]
		dot.custom_minimum_size = Vector2(font * 0.7, font * 0.7)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(dot)
		if labels:
			var nm := UI.label(str(r["label"]), font, "muted", 1)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			h.add_child(nm)
		var val := UI.label(str(r["text"]), font, "text", 2)
		val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if not labels:
			val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(val)
		v.add_child(h)
		if delay >= 0.0:
			Anim.pop_in(dot, delay + 0.05, Anim.POP, 0.3)
	return v

# --- kleine Zeichen-Bausteine -----------------------------------------------

## Farbiger Kreis (Ampelpunkt).
class Dot extends Control:
	var color := Color.WHITE
	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, color, true, -1.0, true)

## Balken mit zwei Anteilen (links Farbe = gesaettigt, rechts ungesaettigt).
class SplitBar extends Control:
	var bar_h := 26.0
	var share := -1.0
	var left_color := Color.WHITE
	var progress := 1.0:
		set(v):
			progress = v
			queue_redraw()
	func _ready() -> void:
		custom_minimum_size = Vector2(0, bar_h)
		resized.connect(queue_redraw)
	func _draw() -> void:
		var w := size.x
		var sb := StyleBoxFlat.new()
		sb.bg_color = UI.c("surface2")
		sb.set_corner_radius_all(3)
		sb.set_border_width_all(1)
		sb.border_color = UI.c("line")
		draw_style_box(sb, Rect2(0, 0, w, bar_h))
		if share < 0.0:
			return
		var p := clampf(progress, 0.0, 1.0)
		var inner := (w - 2.0) * p
		var lw := inner * share
		if inner - lw > 0.5:
			var rb := StyleBoxFlat.new()
			rb.bg_color = UI.c("good").lerp(UI.c("surface2"), 0.55)
			rb.set_corner_radius_all(3)
			draw_style_box(rb, Rect2(1, 1, inner, bar_h - 2.0))
		if lw > 0.5:
			var lb := StyleBoxFlat.new()
			lb.bg_color = left_color
			lb.set_corner_radius_all(3)
			draw_style_box(lb, Rect2(1, 1, lw, bar_h - 2.0))
