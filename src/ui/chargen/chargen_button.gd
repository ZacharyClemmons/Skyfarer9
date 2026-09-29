class_name ChargenButton extends Control
## One of the buttons floating around your character in the setup room (Burgerstation's
## chargen HUD buttons). Styles:
##   "main"   big rounded square (the current hair / facial hair)
##   "trim"   smaller, dimmer square (the neighbouring choices in a carousel)
##   "arrow_l" / "arrow_r"
##   "swatch" round colour button (skin, hair, eyes, underwear)
##   "plate"  wide name plate
##   "square" plain button with a short caption

signal activated
signal activated_alt # right click

var style := "square"
var caption := "" # small text under the button
var side_caption := "" # text to the left of the button (carousel row names)
var text := "" # text drawn on the button
var color := Color.WHITE # swatch colour / accent
var hot := false
var _press_t := 0.0
var _hov := 0.0 # eased hover, 0..1
var _t := 0.0

func _init(st: String, sz: Vector2, cap := "") -> void:
	style = st
	caption = cap
	custom_minimum_size = sz
	size = sz
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			_press_t = 0.14
			Sfx.play_ui(&"ui_click", 0.7, 1.0 if style != "arrow_l" else 0.9)
			activated.emit()
			accept_event()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			activated_alt.emit()
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hot = true
		Sfx.play_ui(&"ui_hover", 0.35, randf_range(0.95, 1.08))
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		hot = false
		queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	var want := 1.0 if hot else 0.0
	if not is_equal_approx(_hov, want):
		_hov = move_toward(_hov, want, delta * 9.0)
		queue_redraw()
	if _press_t > 0.0:
		_press_t -= delta
		queue_redraw()
	if style == "begin":
		queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	# hover swells the button a little; a press squeezes it in, then it springs back
	r = r.grow(_hov * 2.0)
	if _press_t > 0.0:
		r = r.grow(-3.0 * (_press_t / 0.14))
	var edge := Color(0.42, 0.62, 0.78, 0.7)
	if hot:
		edge = UITheme.ACCENT
	match style:
		"arrow_l", "arrow_r":
			var c := size * 0.5
			var s := minf(size.x, size.y) * 0.32
			var dir := -1.0 if style == "arrow_l" else 1.0
			var pts := PackedVector2Array([c + Vector2(dir * s, 0), c + Vector2(-dir * s * 0.6, -s), c + Vector2(-dir * s * 0.6, s)])
			draw_colored_polygon(pts, Color(0.08, 0.12, 0.18, 0.9))
			pts.append(pts[0])
			draw_polyline(pts, edge, 2.0)
		"swatch":
			var c2 := size * 0.5
			var rad := minf(size.x, size.y) * 0.5 - 3.0
			draw_circle(c2, rad + 2.0, Color(0.02, 0.03, 0.05, 0.9))
			draw_circle(c2, rad - 2.0, color)
			draw_arc(c2, rad, 0, TAU, 40, edge, 2.0)
			# glassy highlight
			draw_arc(c2 + Vector2(-rad * 0.2, -rad * 0.2), rad * 0.55, PI * 1.05, PI * 1.45, 12, Color(1, 1, 1, 0.35), 2.0)
		"plate":
			_panel(r, edge, 6)
			draw_line(r.position + Vector2(8, r.size.y - 4), r.end - Vector2(8, 4), Color(edge.r, edge.g, edge.b, 0.35), 1.0)
		"trim":
			_panel(r, Color(edge.r, edge.g, edge.b, edge.a * 0.6), 4, 0.6)
		"begin":
			var pulse := 0.5 + 0.5 * sin(_t * 3.0)
			var gold := Color("#e8c85a")
			for g in 3:
				draw_rect(r.grow(3.0 + g * 3.0 + pulse * 3.0), Color(gold, (0.12 - g * 0.035) * (0.6 + 0.4 * pulse + _hov)), false, 2.0)
			_panel(r, gold if hot else Color(gold, 0.85), 8)
			draw_rect(Rect2(r.position + Vector2(5, 5), r.size - Vector2(10, 10)), Color(gold, 0.10 + 0.14 * _hov))
		"main":
			_panel(r, edge, 10)
			draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.08))
		_:
			_panel(r, edge if color == Color.WHITE else Color(color, 0.9), 6)
	if text != "":
		var font := UITheme.font
		var fs := 15 if style != "plate" else 18
		var tcol := Color.WHITE if hot else UITheme.TEXT
		if style == "begin":
			tcol = Color("#ffe9a0") if hot else Color("#e8c85a")
			fs = 20
		draw_string(font, Vector2(4, size.y * 0.5 + fs * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, fs, tcol)
	if side_caption != "":
		var lines := side_caption.split("
")
		for i in lines.size():
			draw_string(UITheme.mono, Vector2(-190, size.y * 0.5 - 4 + i * 18), lines[i], HORIZONTAL_ALIGNMENT_RIGHT, 180, 18,
				Color(UITheme.DIM, 0.75) if i == 0 else UITheme.TEXT)
	if caption != "":
		var f2 := UITheme.mono
		draw_string(f2, Vector2(-20, size.y + 16), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x + 40, 17, Color(UITheme.DIM, 0.9 if hot else 0.7))

func _panel(r: Rect2, edge: Color, radius: int, fill_a := 0.88) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.1, fill_a)
	sb.border_color = edge
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 4
	draw_style_box(sb, r)
