extends Control
class_name BlockPreview

## Kleines Sinnbild eines Bausteins fuer das Dock im Editor. Gezeichnet (keine
## Assets), damit es in Hell/Dunkel und jeder Groesse scharf bleibt.

var block_id := "macros"

## Beispielzahl + Farbe + Fuellstand je Balken-Baustein.
const SAMPLE := {
	"density": ["402", "bad", 0.8],
	"protein": ["17.5", "good", 0.7],
	"satiety": ["74", "good", 0.74],
	"sugar": ["12", "warn", 0.45],
	"fiber": ["6.2", "good", 0.5],
	"salt": ["0.3", "good", 0.15],
	"satfat": ["2.1", "warn", 0.35],
}

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	match Blocks.kind(block_id):
		"donut": _draw_donut()
		"fatq": _draw_split()
		"ampel": _draw_ampel()
		_: _draw_bar()

func _draw_donut() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.36
	var w := r * 0.42
	var segs := [[0.28, "protein"], [0.20, "sugar"], [0.27, "carbs"], [0.25, "fat"]]
	var a := -PI * 0.5
	for s in segs:
		var span: float = float(s[0]) * TAU
		draw_arc(c, r, a + 0.06, a + span - 0.06, 32, UI.c(s[1]), w, true)
		a += span

func _draw_bar() -> void:
	var smp: Array = SAMPLE.get(block_id, ["42", "accent", 0.5])
	var col := UI.c(smp[1])
	var f := UI.font(2)
	var fs := int(size.y * 0.42)
	var x0 := size.x * 0.12
	draw_string(f, Vector2(x0, size.y * 0.52), str(smp[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	var bw := size.x * 0.76
	var by := size.y * 0.68
	var bh := maxf(6.0, size.y * 0.12)
	_rrect(Rect2(x0, by, bw, bh), UI.c("surface2"))
	_rrect(Rect2(x0, by, bw * float(smp[2]), bh), col)

func _draw_split() -> void:
	var f := UI.font(2)
	var x0 := size.x * 0.12
	var fs := int(size.y * 0.36)
	draw_string(f, Vector2(x0, size.y * 0.48), "18 %", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.c("good"))
	var bw := size.x * 0.76
	var by := size.y * 0.66
	var bh := maxf(6.0, size.y * 0.12)
	_rrect(Rect2(x0, by, bw, bh), UI.c("good").lerp(UI.c("surface2"), 0.55))
	_rrect(Rect2(x0, by, bw * 0.18, bh), UI.c("good"))

func _draw_ampel() -> void:
	var cols := ["good", "warn", "bad", "good"]
	var n := cols.size()
	var r := minf(size.y * 0.16, size.x / (n * 3.2))
	var gap := (size.x * 0.76) / n
	var x0 := size.x * 0.12 + gap * 0.5
	for i in n:
		var x := x0 + gap * i
		draw_circle(Vector2(x, size.y * 0.38), r, UI.c(cols[i]), true, -1.0, true)
		_rrect(Rect2(x - r, size.y * 0.66, r * 2.0, maxf(5.0, size.y * 0.08)), UI.c("surface2"))

func _rrect(r: Rect2, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(minf(r.size.y * 0.5, 6.0)))
	draw_style_box(sb, r)
