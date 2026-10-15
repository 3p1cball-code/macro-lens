extends RefCounted
class_name CompareScreen

## 4er-Vergleich: je Kennzahl eine Zeile mit den Produktspalten,
## Bestwerte je Zeile markiert. Groesse passt sich der Produktanzahl an.

static func build(app: App) -> Control:
	var content := Shell.content_col()
	var share := Shell.text_action(I18n.t("share"), func(): _share(app))
	var root_c := Shell.page(app, I18n.t("compare_title"), content, true, share)
	if app.tray.size() < 2:
		content.add_child(UI.label(I18n.t("compare_need"), UI.FS_BODY, "muted"))
		return root_c
	_build_matrix(app, content)
	return root_c

static func _build_matrix(app: App, content: VBoxContainer) -> void:
	var foods: Array = app.tray
	var n: int = foods.size()
	var num_size: int = [120, 92, 72][clampi(n - 2, 0, 2)]
	var donut_h: int = [230, 200, 172][clampi(n - 2, 0, 2)]

	var evals: Array = []
	var kcals: Array = []
	var pds: Array = []
	var sats: Array = []
	for f in foods:
		var ev := Metrics.evaluate(f)
		evals.append(ev)
		kcals.append(ev.density if ev.density_ok else -1.0)
		pds.append(ev.protein_density if ev.protein_density_ok else -1.0)
		sats.append(float(ev.fullness.get("score", -1)) if ev.fullness_ok else -1.0)
	var best_kcal := _best(kcals, true)
	var best_pd := _best(pds, false)
	var best_sat := _best(sats, false)

	# Produktnamen
	var names := UI.hbox(14)
	for f in foods:
		var cell := UI.vbox(4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := UI.label(f.display_name(I18n.lang), UI.FS_SMALL, "text", 2)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(nm)
		if f.brand != "":
			var b := UI.label(f.brand, UI.FS_MICRO, "muted")
			b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(b)
		names.add_child(cell)
	content.add_child(names)

	# Donut
	var dcells: Array = []
	for ev in evals:
		var cell := UI.vbox(0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var d := MacroDonut.new()
		d.custom_minimum_size = Vector2(0, donut_h)
		d.ring_width = donut_h * 0.15
		if ev.split_ok:
			d.set_split(ev.split)
		cell.add_child(d)
		dcells.append(cell)
	content.add_child(_metric_row("chart_donut", dcells))

	var kc: Array = []
	for i in range(n):
		var ev = evals[i]
		kc.append(_num_cell(Metrics.format_num(ev.density, 0) if ev.density_ok else "–", "kcal/100 g", num_size, i == best_kcal))
	content.add_child(_metric_row("chart_density", kc))

	var pc: Array = []
	for i in range(n):
		var ev = evals[i]
		pc.append(_bar_cell(Metrics.format_num(ev.protein_density, 1) if ev.protein_density_ok else "–", "g/100 kcal", ev.protein_density if ev.protein_density_ok else -1.0, 25.0, "protein", num_size, i == best_pd))
	content.add_child(_metric_row("chart_protein", pc))

	var sc2: Array = []
	for i in range(n):
		var ev = evals[i]
		var sc: float = float(ev.fullness.get("score", -1)) if ev.fullness_ok else -1.0
		var ck := "good" if sc >= 60 else ("warn" if sc >= 35 else "bad")
		sc2.append(_bar_cell(str(int(sc)) if sc >= 0.0 else "–", "von 100", sc, 100.0, ck, num_size, i == best_sat))
	content.add_child(_metric_row("chart_satiety", sc2))

	var foot := UI.label(I18n.t("estimate") + " · " + I18n.t("attribution"), UI.FS_MICRO, "faint")
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(foot)

static func _metric_row(label_key: String, cells: Array) -> Control:
	var v := UI.vbox(14)
	v.add_child(UI.micro(I18n.t(label_key)))
	var row := UI.hbox(14)
	for c in cells:
		row.add_child(c)
	v.add_child(row)
	return v

static func _num_cell(value: String, unit: String, num_size: int, best: bool) -> Control:
	var cell := UI.vbox(4)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := "good" if best else "text"
	cell.add_child(UI.big_number(value, col, num_size))
	cell.add_child(UI.micro(unit))
	if best:
		var h := UI.hbox(0)
		h.add_child(UI.chip(I18n.t("best"), "good"))
		cell.add_child(h)
	return cell

static func _bar_cell(value: String, unit: String, raw: float, maxv: float, color_key: String, num_size: int, best: bool) -> Control:
	var cell := UI.vbox(8)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := "good" if best else "text"
	cell.add_child(UI.big_number(value, col, num_size))
	cell.add_child(UI.micro(unit))
	var bar := MeterBar.new()
	bar.bar_h = 30.0
	bar.set_value(raw, maxv, color_key)
	cell.add_child(bar)
	if best:
		var h := UI.hbox(0)
		h.add_child(UI.chip(I18n.t("best"), "good"))
		cell.add_child(h)
	return cell

static func _best(values: Array, lower: bool) -> int:
	var idx := -1
	var ref := INF if lower else -INF
	for i in values.size():
		var v: float = values[i]
		if v < 0.0:
			continue
		if lower and v < ref:
			ref = v
			idx = i
		elif not lower and v > ref:
			ref = v
			idx = i
	return idx

static func _share(app: App) -> void:
	var lines: Array = ["Macro Lens — " + I18n.t("compare_title")]
	for f in app.tray:
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
	app.share_text("\n".join(lines))
