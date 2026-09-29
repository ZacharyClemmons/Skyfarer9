class_name UIFx extends RefCounted
## Global UI "juice": every Button in the game gets hover / press sounds and a small
## hover-grow + press-squash automatically (hooked once, as it enters the tree, from
## UITheme.build). Also toasts and a few tween helpers other code can call:
##
##   UIFx.toast("Hull repaired", "good")     # tones: info good warn bad gold
##   UIFx.pop(control, 1.2)                  # quick scale pop
##   UIFx.shake(control)                     # deny wobble
##   UIFx.appear(control, Vector2(0, 8))     # fade + slide in (message lines etc.)
##   UIFx.ease_open(window) / ease_close(window)
##
## Opt a button out with button.set_meta("no_fx", true); pick its click voice with
## button.set_meta("fx_sound", "ui_confirm"). Hover/press only ever react to real input.

const TONES := {
	"info": [Color("#7fd4ff"), "ui_toast"], "good": [Color("#6ae88a"), "ui_confirm"],
	"warn": [Color("#ffb84a"), "ui_tick"], "bad": [Color("#ff5a4a"), "ui_deny"],
	"gold": [Color("#ffd970"), "ui_coin"]}
const MAX_TOASTS := 4

static var _installed := false
static var _host: CanvasLayer
static var _stack: VBoxContainer

static func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

## Hook every Button that ever enters the tree. Safe to call repeatedly.
static func install() -> void:
	if _installed:
		return
	var t := tree()
	if t == null:
		return
	_installed = true
	t.node_added.connect(_on_node_added)

static func _on_node_added(n: Node) -> void:
	if n is Button and not n.has_meta("_fx"):
		n.set_meta("_fx", true)
		n.mouse_entered.connect(_enter.bind(n))
		n.mouse_exited.connect(_exit.bind(n))
		n.button_down.connect(_down.bind(n))
		n.button_up.connect(_up.bind(n))
		n.gui_input.connect(_input.bind(n))
		n.tree_exiting.connect(_reset.bind(n))

static func _skip(b: Button) -> bool:
	return b.has_meta("no_fx") or not is_instance_valid(b) or not b.is_inside_tree()

static func _hover_scale(b: Button) -> float:
	return 1.0 + clampf(3.0 / maxf(minf(b.size.x, b.size.y), 1.0), 0.008, 0.07)

static func _tw(b: Node) -> Tween:
	if b.has_meta("_fx_tw"):
		var old = b.get_meta("_fx_tw")
		if old is Tween and old.is_valid():
			old.kill()
	var tw := b.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	b.set_meta("_fx_tw", tw)
	return tw

static func _enter(b: Button) -> void:
	if _skip(b) or b.disabled:
		return
	b.pivot_offset = b.size * 0.5
	if not b.has_meta("_fx_mod"):
		b.set_meta("_fx_mod", b.self_modulate)
	Sfx.play_ui("ui_hover", 0.6, randf_range(0.96, 1.06))
	var tw := _tw(b)
	tw.tween_property(b, "scale", Vector2.ONE * _hover_scale(b), 0.09)
	tw.tween_property(b, "self_modulate", (b.get_meta("_fx_mod") as Color) * Color(1.14, 1.14, 1.14, 1.0), 0.09)

static func _exit(b: Button) -> void:
	if not is_instance_valid(b) or not b.has_meta("_fx_mod"):
		return
	var tw := _tw(b)
	tw.tween_property(b, "scale", Vector2.ONE, 0.12)
	tw.tween_property(b, "self_modulate", b.get_meta("_fx_mod"), 0.12)

static func _down(b: Button) -> void:
	if _skip(b) or b.disabled:
		return
	b.pivot_offset = b.size * 0.5
	Sfx.play_ui(str(b.get_meta("fx_sound", "ui_click")), 0.9, randf_range(0.95, 1.05))
	var tw := _tw(b)
	tw.tween_property(b, "scale", Vector2(0.94, 0.9), 0.05)

static func _up(b: Button) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	var hovering := b.get_global_rect().has_point(b.get_global_mouse_position())
	var tw := _tw(b)
	tw.tween_property(b, "scale", Vector2.ONE * (_hover_scale(b) if hovering else 1.0), 0.16).set_trans(Tween.TRANS_BACK)

static func _input(ev: InputEvent, b: Button) -> void:
	# a disabled button says "no" when you try it
	if b.disabled and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not b.has_meta("no_fx"):
		Sfx.play_ui("ui_deny", 0.5)
		shake(b, 3.0)

static func _reset(b: Button) -> void:
	if not is_instance_valid(b):
		return
	b.scale = Vector2.ONE
	if b.has_meta("_fx_mod"):
		b.self_modulate = b.get_meta("_fx_mod")

# ------------------------------------------------------------------ helpers
static func pop(c: Control, amount := 1.15, dur := 0.22) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * amount
	var tw := c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, dur)

static func shake(c: Control, px := 4.0) -> void:
	if c == null or not c.is_inside_tree():
		return
	var tw := c.create_tween()
	var base := c.position
	# containers own position, so wobble the pivot-scale as well as the offset
	for k in 4:
		tw.tween_property(c, "rotation", deg_to_rad(px * (1.0 if k % 2 == 0 else -1.0) * (1.0 - k * 0.22)), 0.03)
	tw.tween_property(c, "rotation", 0.0, 0.04)
	c.pivot_offset = c.size * 0.5

## Fade + slide a freshly added node in (message lines, list rows).
static func appear(c: CanvasItem, from := Vector2(0, 6), dur := 0.25) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, dur)
	if c is Control and not c.get_parent() is Container:
		var end: Vector2 = c.position
		c.position = end + from
		tw.tween_property(c, "position", end, dur)

static func _set_scale(v: float, w: Control) -> void:
	if is_instance_valid(w):
		w.pivot_offset = w.size * 0.5
		w.scale = Vector2.ONE * v

## Window open: quick eased scale + fade pop.
static func ease_open(w: Control, quiet := false) -> void:
	if not quiet:
		Sfx.play_ui("ui_open", 0.7)
	w.modulate.a = 0.0
	var tw := w.create_tween().set_parallel(true)
	tw.tween_property(w, "modulate:a", 1.0, 0.14)
	tw.tween_method(_set_scale.bind(w), 0.94, 1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Window close: fade and shrink a touch, then free.
static func ease_close(w: Control) -> void:
	if w.has_meta("_closing"):
		return
	w.set_meta("_closing", true)
	Sfx.play_ui("ui_close", 0.6)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := w.create_tween().set_parallel(true)
	tw.tween_property(w, "modulate:a", 0.0, 0.11)
	tw.tween_method(_set_scale.bind(w), 1.0, 0.95, 0.11)
	tw.chain().tween_callback(w.queue_free)

# ------------------------------------------------------------------ toasts
static func _ensure_host() -> bool:
	if is_instance_valid(_host):
		return true
	var t := tree()
	if t == null or t.root == null:
		return false
	_host = CanvasLayer.new()
	_host.layer = 95
	_host.name = "UIFxToasts"
	_stack = VBoxContainer.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_theme_constant_override("separation", 6)
	_stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_stack.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_stack.offset_top = 96
	_stack.offset_right = -18
	_stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	_host.add_child(_stack)
	t.root.add_child.call_deferred(_host)
	return true

## A small self-dismissing notification at the top right.
static func toast(text: String, tone := "info", seconds := 2.8) -> void:
	if not _ensure_host():
		return
	var spec: Array = TONES.get(tone, TONES["info"])
	var col: Color = spec[0]
	while _stack.get_child_count() >= MAX_TOASTS:
		var old := _stack.get_child(0)
		_stack.remove_child(old)
		old.queue_free()
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.93)
	sb.border_color = Color(col, 0.9)
	sb.border_width_left = 4
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UITheme.px(19))
	l.add_theme_color_override("font_color", Color(1, 1, 1).lerp(col, 0.25))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	p.modulate.a = 0.0
	_stack.add_child(p)
	Sfx.play_ui(str(spec[1]), 0.55)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.16)
	tw.tween_interval(seconds)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
	# a little overshoot pop as it arrives
	p.resized.connect(func() -> void: p.pivot_offset = Vector2(p.size.x, p.size.y * 0.5), CONNECT_ONE_SHOT)
	var pt := p.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	p.scale = Vector2(0.88, 0.88)
	pt.tween_property(p, "scale", Vector2.ONE, 0.24)
