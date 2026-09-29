class_name LayoutHandle extends Control
## HUD layout mode: an outline over one HUD panel that drags it around. The chat's
## handle also has a corner grip that resizes the chat log.

var hud: HUD
var panel_name := ""
var target: Control
var resizable := false
var _mode := "" # "move" / "resize"
const GRIP := 18.0

func _init(h: HUD, nm: String, t: Control, can_resize: bool) -> void:
	hud = h
	panel_name = nm
	target = t
	resizable = can_resize
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	tooltip_text = "Drag to move"

func _process(_dt: float) -> void:
	# follow the panel (it can change size as its contents change)
	var r := target.get_global_rect()
	if r.size.x < 24.0 or r.size.y < 24.0:
		r = r.grow_individual(0, 0, maxf(0.0, 48.0 - r.size.x), maxf(0.0, 48.0 - r.size.y))
	global_position = r.position
	size = r.size
	queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_mode = "resize" if resizable and ev.position.x > size.x - GRIP and ev.position.y > size.y - GRIP else "move"
		else:
			if _mode != "":
				hud.reanchor(target)
			_mode = ""
		accept_event()
	elif ev is InputEventMouseMotion:
		if resizable and _mode == "":
			mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE if ev.position.x > size.x - GRIP and ev.position.y > size.y - GRIP else Control.CURSOR_MOVE
		if _mode == "move":
			var vs := hud.root.get_rect().size
			var r := target.get_global_rect()
			target.global_position = (r.position + ev.relative).clamp(Vector2.ZERO, (vs - r.size).max(Vector2.ZERO))
			accept_event()
		elif _mode == "resize":
			var log := hud.chat_log
			log.custom_minimum_size = (log.custom_minimum_size + ev.relative).clamp(Vector2(360, 120), Vector2(1400, 900))
			target.reset_size()
			accept_event()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.12))
	# dashed outline
	var col := UITheme.ACCENT
	var dash := 8.0
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(minf(x + dash * 0.6, size.x), 0), col, 2.0)
		draw_line(Vector2(x, size.y), Vector2(minf(x + dash * 0.6, size.x), size.y), col, 2.0)
		x += dash
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(0, minf(y + dash * 0.6, size.y)), col, 2.0)
		draw_line(Vector2(size.x, y), Vector2(size.x, minf(y + dash * 0.6, size.y)), col, 2.0)
		y += dash
	# name tab tucked inside the panel's top-left corner, so neighbouring panels' tabs
	# can never land on top of each other
	var tw := UITheme.font.get_string_size(panel_name.capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 12.0
	var ty := 0.0
	draw_rect(Rect2(0, ty, tw, 20), UITheme.ACCENT)
	draw_string(UITheme.font, Vector2(6, ty + 15), panel_name.capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.03, 0.05, 0.08))
	if resizable:
		for i in 3:
			var o := 4.0 + i * 5.0
			draw_line(Vector2(size.x - o, size.y - 2), Vector2(size.x - 2, size.y - o), col, 2.0)
