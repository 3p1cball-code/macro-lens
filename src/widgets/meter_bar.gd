extends Control
class_name MeterBar

## Einfacher Ein-Wert-Balken (Eiweissdichte, Saettigung). Fuellung + Rahmen,
## Wertebereich konfigurierbar.

var value: float = -1.0
var maxv: float = 100.0
var color_key: String = "accent"
var color_override: Color = Color(0, 0, 0, 0)
var bar_h: float = 46.0
var threshold: float = -1.0
var threshold_key: String = "text"
## 0..1 - Aufbau-Animation (Fuellung waechst)
var progress: float = 1.0:
	set(v):
		progress = v
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(0, bar_h)
	resized.connect(queue_redraw)

func set_value(v: float, mx: float = -1.0, ck: String = "", col: Color = Color(0, 0, 0, 0)) -> void:
	value = v
	if mx > 0.0:
		maxv = mx
	if ck != "":
		color_key = ck
	if col.a > 0.0:
		color_override = col
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var track := Rect2(0, 0, w, bar_h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UI.c("surface2")
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(1)
	sb.border_color = UI.c("line")
	draw_style_box(sb, track)
	if value < 0.0:
		return
	var frac: float = clampf(value / maxv, 0.0, 1.0) * clampf(progress, 0.0, 1.0)
	var fw: float = maxf(frac * (w - 2.0), 0.0)
	if fw > 0.5:
		var fb := StyleBoxFlat.new()
		fb.bg_color = color_override if color_override.a > 0.0 else UI.c(color_key)
		fb.set_corner_radius_all(3)
		draw_style_box(fb, Rect2(1, 1, fw, bar_h - 2.0))
	if threshold >= 0.0:
		var tx: float = clampf(threshold / maxv, 0.0, 1.0) * w
		draw_line(Vector2(tx, 0), Vector2(tx, bar_h), UI.c(threshold_key), 3.0)
