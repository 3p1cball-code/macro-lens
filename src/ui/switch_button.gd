extends Button
class_name SwitchButton

## An/Aus-Schalter im App-Stil: flache Pille, Knopf gleitet, Akzent wenn an.
## Gezeichnet statt Theme-Grafik (Hell/Dunkel ohne Assets).

var _t := 0.0   # 0 = aus, 1 = an (animiert)

func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	flat = true
	custom_minimum_size = Vector2(124, 68)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	toggled.connect(_on_toggled)

func _ready() -> void:
	_t = 1.0 if button_pressed else 0.0

func _on_toggled(on: bool) -> void:
	Input.vibrate_handheld(10)
	if not Anim.enabled or not is_inside_tree():
		_t = 1.0 if on else 0.0
		queue_redraw()
		return
	var tw := create_tween()
	tw.tween_method(func(v: float):
		_t = v
		queue_redraw(), _t, 1.0 if on else 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var h := 44.0
	var w := 92.0
	var r := Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)
	var track := StyleBoxFlat.new()
	track.set_corner_radius_all(int(h * 0.5))
	track.bg_color = UI.c("surface2").lerp(UI.c("accent"), _t)
	track.set_border_width_all(1)
	track.border_color = UI.c("line").lerp(UI.c("accent"), _t)
	draw_style_box(track, r)
	var knob_r := h * 0.5 - 6.0
	var x := lerpf(r.position.x + h * 0.5, r.end.x - h * 0.5, _t)
	draw_circle(Vector2(x, r.position.y + h * 0.5), knob_r,
		UI.c("muted").lerp(UI.c("on_accent"), _t), true, -1.0, true)
