extends Container
class_name Slide

## Haelt genau ein Kind und legt es um `offset` (Pixel, vertikal) versetzt aus.
## Der Versatz ist Teil des Layouts - ein Neu-Sortieren der Eltern setzt ihn
## also nicht zurueck (anders als ein direktes Setzen von `position`).
##
## `tint` hinterlegt die Zelle farbig (Allergen-Warnung). Die Flaeche ragt
## etwas ueber die Zelle hinaus, damit die Zellen einer Spalte zu einem
## durchgehenden Band verschmelzen, und wandert beim Wischen mit.

var offset: float = 0.0:
	set(v):
		offset = v
		queue_sort()
		queue_redraw()

var tint: Color = Color(0, 0, 0, 0):
	set(v):
		tint = v
		queue_redraw()

func wrap(c: Control) -> Slide:
	size_flags_horizontal = c.size_flags_horizontal
	size_flags_vertical = c.size_flags_vertical
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(c)
	return self

func _get_minimum_size() -> Vector2:
	var m := Vector2.ZERO
	for c in get_children():
		var cc := c as Control
		if cc != null and cc.visible:
			m = m.max(cc.get_combined_minimum_size())
	return m

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for c in get_children():
			var cc := c as Control
			if cc != null:
				fit_child_in_rect(cc, Rect2(Vector2(0.0, offset), size))

func _draw() -> void:
	if tint.a <= 0.0:
		return
	draw_rect(Rect2(Vector2(-6.0, offset - 6.0), size + Vector2(12.0, 12.0)), tint)
