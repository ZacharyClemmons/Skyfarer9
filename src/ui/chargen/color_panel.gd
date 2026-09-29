class_name ColorPanel extends PanelContainer
## Colour picker for the setup room: a row of preset swatches plus hue / saturation /
## brightness strips you can click or drag along. Changes apply live.

signal color_changed(c: Color)

var current := Color.WHITE
var strips := {} # "h"/"s"/"v" -> Control

func _init(title: String, presets: Array, start: Color) -> void:
	current = start
	add_theme_stylebox_override("panel", UITheme.panel_style(0.96))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	v.add_child(UITheme.label(title, 16, UITheme.ACCENT))
	if not presets.is_empty():
		var g := GridContainer.new()
		g.columns = 10
		g.add_theme_constant_override("h_separation", 4)
		g.add_theme_constant_override("v_separation", 4)
		v.add_child(g)
		for pc in presets:
			var col := Color(pc)
			var b := ChargenButton.new("swatch", Vector2(28, 28))
			b.color = col
			b.activated.connect(func(): _pick(col))
			g.add_child(b)
	for k in ["h", "s", "v"]:
		var row := HBoxContainer.new()
		v.add_child(row)
		var l := UITheme.label({"h": "Hue", "s": "Tint", "v": "Shade"}[k], 13, UITheme.DIM)
		l.custom_minimum_size = Vector2(46, 0)
		row.add_child(l)
		var st := Control.new()
		st.custom_minimum_size = Vector2(260, 18)
		st.mouse_filter = Control.MOUSE_FILTER_STOP
		st.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var key: String = k
		st.draw.connect(func(): _draw_strip(st, key))
		st.gui_input.connect(func(ev): _strip_input(st, key, ev))
		row.add_child(st)
		strips[k] = st

func _pick(c: Color) -> void:
	current = c
	for st in strips.values():
		st.queue_redraw()
	color_changed.emit(c)

func _strip_input(st: Control, key: String, ev: InputEvent) -> void:
	var drag: bool = ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	var click: bool = ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT
	if not (drag or click):
		return
	var f := clampf(ev.position.x / st.size.x, 0.0, 0.999)
	var h := current.h
	var s := current.s
	var v := current.v
	match key:
		"h": h = f
		"s": s = f
		"v": v = f
	_pick(Color.from_hsv(h, s, v))
	st.accept_event()

func _draw_strip(st: Control, key: String) -> void:
	var n := 48
	var w := st.size.x / n
	for i in n:
		var f := (i + 0.5) / n
		var c: Color
		match key:
			"h": c = Color.from_hsv(f, maxf(current.s, 0.5), maxf(current.v, 0.6))
			"s": c = Color.from_hsv(current.h, f, maxf(current.v, 0.3))
			_: c = Color.from_hsv(current.h, current.s, f)
		st.draw_rect(Rect2(i * w, 0, w + 1, st.size.y), c)
	st.draw_rect(Rect2(Vector2.ZERO, st.size), UITheme.BORDER, false, 1.0)
	var val: float = {"h": current.h, "s": current.s, "v": current.v}[key]
	var x := val * st.size.x
	st.draw_rect(Rect2(x - 2, -2, 4, st.size.y + 4), Color.WHITE)
	st.draw_rect(Rect2(x - 3, -3, 6, st.size.y + 6), Color.BLACK, false, 1.0)
