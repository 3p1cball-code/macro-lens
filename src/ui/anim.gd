extends RefCounted
class_name Anim

## Zentrale, einheitliche Animationen: kurz, snappy, ease-in/ease-out.
## Alles laeuft ueber Tweens am jeweiligen Node -> wird der Node verworfen
## (z. B. beim Neuaufbau), endet die Animation automatisch.

static var enabled: bool = true

const POP := 0.26        # Erscheinen (Karten, Spalten, Banner)
const BUILD := 0.50      # Aufbau der Grafiken (Donut, Balken, Zahlen)
const OUT := 0.18        # Verschwinden
const STAGGER := 0.045   # Versatz zwischen Elementen

## Fuehrt cb aus, sobald node im Baum ist (Tweens brauchen den SceneTree).
static func _in_tree(node: Node, cb: Callable) -> bool:
	if node.is_inside_tree():
		return true
	node.tree_entered.connect(cb, CONNECT_ONE_SHOT)
	return false

## Einblenden + leichtes Hochskalieren mit kleinem Ueberschwinger.
static func pop_in(node: Control, delay: float = 0.0, dur: float = POP, from_scale: float = 0.93) -> void:
	if not enabled:
		return
	node.modulate.a = 0.0
	if not _in_tree(node, func(): pop_in(node, delay, dur, from_scale)):
		return
	var tw := node.create_tween()
	tw.tween_interval(delay + 0.016)
	tw.tween_callback(func(): node.pivot_offset = node.size * 0.5)
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, dur).from(0.0) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, dur).from(Vector2.ONE * from_scale) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Nur Einblenden (fuer ganze Screens).
static func fade_in(node: CanvasItem, dur: float = 0.2) -> void:
	if not enabled:
		return
	node.modulate.a = 0.0
	if not _in_tree(node, func(): fade_in(node, dur)):
		return
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, dur).from(0.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Ausblenden + Schrumpfen, danach then.call().
static func pop_out(nodes: Array, then: Callable, dur: float = OUT) -> void:
	if not enabled or nodes.is_empty():
		then.call()
		return
	var first: Control = nodes[0]
	if not first.is_inside_tree():
		then.call()
		return
	var tw := first.create_tween()
	tw.set_parallel(true)
	for n in nodes:
		var c := n as Control
		if c == null or not is_instance_valid(c):
			continue
		c.pivot_offset = c.size * 0.5
		tw.tween_property(c, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(c, "scale", Vector2.ONE * 0.88, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(then)

## Eine Eigenschaft 0 -> 1 laufen lassen (z. B. "progress" eines Diagramms).
static func sweep(obj: Object, prop: String, delay: float = 0.0, dur: float = BUILD) -> void:
	if not enabled:
		return
	var node := obj as Node
	if node == null:
		return
	obj.set(prop, 0.0)
	if not _in_tree(node, func(): sweep(obj, prop, delay, dur)):
		return
	var tw := node.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(obj, prop, 1.0, dur).from(0.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

## Zahl hochzaehlen (0 -> target) mit fester Nachkommastelle und optionalem Suffix.
static func count_up(label: Label, target: float, decimals: int = 0, delay: float = 0.0,
		dur: float = BUILD, suffix: String = "") -> void:
	if not enabled or target < 0.0:
		return
	var fmt := func(v: float): label.text = Metrics.format_num(v, decimals) + suffix
	fmt.call(0.0)
	if not _in_tree(label, func(): count_up(label, target, decimals, delay, dur, suffix)):
		return
	var tw := label.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(fmt, 0.0, target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

## Kurzer Puls (nach PIN): kurz groesser + gruen getoent, dann zurueck.
static func pulse(nodes: Array) -> void:
	if not enabled:
		return
	for n in nodes:
		var c := n as Control
		if c == null or not is_instance_valid(c):
			continue
		if not _in_tree(c, func(): pulse([c])):
			continue
		var tw := c.create_tween()
		tw.tween_interval(0.016)
		tw.tween_callback(func(): c.pivot_offset = c.size * 0.5)
		tw.set_parallel(true)
		tw.tween_property(c, "scale", Vector2.ONE, 0.38).from(Vector2.ONE * 1.07) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "modulate", Color.WHITE, 0.45).from(Color(0.75, 1.0, 0.82)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Knopfdruck-Feedback: beim Druecken leicht einsinken, beim Loslassen zurueckfedern.
static func snappy(b: BaseButton) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func():
		if not enabled or not b.is_inside_tree():
			return
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE * 0.95, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	b.button_up.connect(func():
		if not enabled or not b.is_inside_tree():
			b.scale = Vector2.ONE
			return
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
