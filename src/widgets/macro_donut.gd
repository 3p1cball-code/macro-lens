extends Control
class_name MacroDonut

## Makro-Donut: Energieanteile von Protein/Kohlenhydraten/Fett als Ring.
## Rein zeichnend, keine Kinder. Setzt `split` (aus Metrics.energy_split).

var split: Dictionary = {}
var ring_width: float = 40.0
var gap_rad: float = 0.10
## "none" (Prozente stehen daneben) | "dominant" | "protein"
var center_mode: String = "dominant"
## 0..1 - Aufbau-Animation (Segmente wachsen im Uhrzeigersinn)
var progress: float = 1.0:
	set(v):
		progress = v
		queue_redraw()

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(260, 260)
	resized.connect(queue_redraw)

func set_split(s: Dictionary) -> void:
	split = s
	queue_redraw()

func _draw() -> void:
	var sz := size
	var center := sz * 0.5
	var radius: float = minf(sz.x, sz.y) * 0.5 - ring_width * 0.5 - 4.0
	if radius <= 0.0:
		return
	# Grundring
	draw_arc(center, radius, 0.0, TAU, 96, UI.c("surface2"), ring_width, true)
	if split.is_empty():
		return
	var segs := [[float(split.get("protein", 0.0)), UI.c("protein")]]
	if bool(split.get("sugar_split", false)):
		# Zucker ist Teil der KH: als eigener Bogen, Rest-KH daneben.
		segs.append([float(split.get("sugar", 0.0)), UI.c("sugar")])
		segs.append([float(split.get("starch", 0.0)), UI.c("carbs")])
	else:
		segs.append([float(split.get("carbs", 0.0)), UI.c("carbs")])
	segs.append([float(split.get("fat", 0.0)), UI.c("fat")])
	var angle := -PI * 0.5
	var p := clampf(progress, 0.0, 1.0)
	for s in segs:
		var frac: float = s[0]
		if frac <= 0.001:
			continue
		var span: float = frac * TAU * p
		var a0: float = angle + gap_rad * 0.5
		var a1: float = angle + span - gap_rad * 0.5
		if a1 > a0:
			draw_arc(center, radius, a0, a1, 96, s[1], ring_width, true)
		angle += span
	if center_mode == "none":
		return
	# Zentrum: dominanter Anteil (oder Eiweissanteil in der kompakten Ansicht)
	var dom := str(split.get("dominant", "protein"))
	if center_mode == "protein":
		dom = "protein"
	var frac_dom: float = float(split.get(dom, 0.0))
	var f := UI.font(2)
	var m: float = minf(sz.x, sz.y)
	var fs_big := int(m * 0.27)
	var txt := str(roundi(frac_dom * 100.0)) + "%"
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_big).x
	var tcol := UI.c("text")
	tcol.a = p
	draw_string(f, center + Vector2(-tw * 0.5, fs_big * 0.30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_big, tcol)
	var fs_sm := int(m * 0.13)
	var name_key: String = {"protein": "protein_short", "carbs": "carbs_short", "fat": "fat_short"}.get(dom, "protein_short")
	var nm := I18n.t(name_key).to_upper()
	var fsm := UI.font(1)
	var nw := fsm.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_sm).x
	var mcol := UI.c("muted")
	mcol.a = p
	draw_string(fsm, center + Vector2(-nw * 0.5, fs_big * 0.30 + fs_sm * 1.35), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_sm, mcol)
