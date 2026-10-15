extends Control
class_name DensityScale

## Kaloriendichte: 5-Farb-Band (sehr niedrig .. sehr hoch) mit Marker.
## Skala 0..CAP kcal/100 g, Bandbreiten proportional.

const CAP := 500.0
const EDGES: Array[float] = [0.0, 60.0, 150.0, 250.0, 400.0, 500.0]
const BAND_COLORS: Array[String] = ["#4CC38A", "#8FC24A", "#E8B931", "#E8863C", "#E5484D"]
const BAR_H := 40.0
const KNOB := 14.0

var kcal: float = -1.0

func _ready() -> void:
	custom_minimum_size = Vector2(0, 86)
	resized.connect(queue_redraw)

func set_kcal(v: float) -> void:
	kcal = v
	queue_redraw()

func _draw() -> void:
	if kcal < 0.0:
		return
	var w := size.x
	var top := KNOB + 12.0
	var track := Rect2(0, top, w, BAR_H)
	# Baender
	for i in range(5):
		var x0 := EDGES[i] / CAP * w
		var x1 := EDGES[i + 1] / CAP * w
		draw_rect(Rect2(x0, top, x1 - x0, BAR_H), Color(BAND_COLORS[i]), true)
	# Rahmen
	draw_rect(track, UI.c("line"), false, 1.0)
	# Marker
	var mx: float = clampf(kcal / CAP, 0.0, 1.0) * w
	mx = clampf(mx, 2.0, w - 2.0)
	var line_col := UI.c("text")
	draw_line(Vector2(mx, top - KNOB), Vector2(mx, top + BAR_H + 12.0), line_col, 3.0)
	var tri := PackedVector2Array([
		Vector2(mx - 10, top - KNOB - 12.0),
		Vector2(mx + 10, top - KNOB - 12.0),
		Vector2(mx, top - KNOB),
	])
	draw_colored_polygon(tri, line_col)
