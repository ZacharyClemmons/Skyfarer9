extends RefCounted
## The drawing board's custom widgets: palette tile, inspector icon, animated stat row.

const Art := preload("res://src/ui/shipyard_art.gd")

# ============================================================== widgets
## A palette tile: a sprite, a name, a price. Toggle-like, with hover lift and a pulsing
## outline when selected.
class Tile extends Control:
	signal pressed
	var label := ""
	var sub := ""
	var accent := Color("#7fd4ff")
	var glyph := ""
	var module := ""
	var selected := false
	var dis := false
	var key_hint := ""
	var wide := false
	var erase_icon := false
	var thumb: Dictionary = {}
	var extra := ""
	var _hov := 0.0
	var _on := false
	var _down := false
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func():
			_on = true
			if not dis:
				Sfx.play_ui(&"ui_hover", 0.5)
			set_process(true))
		mouse_exited.connect(func():
			_on = false
			_down = false
			set_process(true))

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(dt: float) -> void:
		_t += dt
		var goal := 1.0 if _on else 0.0
		_hov = move_toward(_hov, goal, dt * 9.0)
		queue_redraw()
		if not selected and _hov == goal:
			set_process(false)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_down = true
			elif _down:
				_down = false
				if dis:
					Sfx.play_ui(&"ui_deny", 0.7)
				else:
					Sfx.play_ui(&"ui_click", 0.8)
					pressed.emit()
			queue_redraw()

	func set_selected(v: bool) -> void:
		selected = v
		set_process(true)
		queue_redraw()

	func _draw() -> void:
		var f := UITheme.font
		var a := 0.42 if dis else 1.0
		var lift := -2.0 * _hov if not _down else 1.0
		var r := Rect2(Vector2(0, maxf(lift, 0.0)), size)
		var bg := Color(0.09, 0.12, 0.17).lerp(Color(0.16, 0.22, 0.30), _hov)
		if selected:
			bg = bg.lerp(accent.darkened(0.55), 0.55)
		draw_rect(r, Color(bg, a))
		var edge := Color(0.28, 0.36, 0.45, a)
		var ew := 1.0
		if selected:
			var pl := 0.65 + 0.35 * sin(_t * 5.0)
			edge = Color(accent.lightened(0.25), pl)
			ew = 2.0
		elif _hov > 0.0:
			edge = Color(accent, 0.3 + 0.5 * _hov)
		draw_rect(r, edge, false, ew)
		# accent stripe
		draw_rect(Rect2(r.position, Vector2(3.0, r.size.y)), Color(accent, 0.85 * a))
		if wide:
			var ir := Rect2(r.position + Vector2(8, (r.size.y - 40.0) * 0.5 + lift * 0.5), Vector2(40, 40))
			_icon(ir, a)
			var tx := r.position.x + 54.0
			var tw := r.size.x - 60.0
			var lc := Color(0.93, 0.96, 1.0, a) if not selected else Color.WHITE
			draw_multiline_string(f, Vector2(tx, r.position.y + 18.0), label, HORIZONTAL_ALIGNMENT_LEFT, tw, 15, 2, lc)
			if sub != "":
				draw_string(f, Vector2(tx, r.end.y - 8.0), sub, HORIZONTAL_ALIGNMENT_LEFT, tw, 13, Color(accent.lightened(0.3), a))
			if extra != "":
				draw_string(f, Vector2(tx, r.end.y - 8.0), extra, HORIZONTAL_ALIGNMENT_RIGHT, tw, 13, Color(0.7, 0.8, 0.9, a))
		else:
			var isz := minf(size.x - 16.0, 44.0)
			var ir2 := Rect2(Vector2((size.x - isz) * 0.5, 6.0 + lift * 0.5), Vector2(isz, isz))
			_icon(ir2, a)
			draw_multiline_string(f, Vector2(r.position.x + 3.0, r.position.y + 6.0 + isz + 12.0), label,
				HORIZONTAL_ALIGNMENT_CENTER, size.x - 6.0, 12, 2, Color(0.9, 0.95, 1.0, a) if not selected else Color.WHITE)
			if sub != "":
				draw_string(f, Vector2(r.position.x, r.end.y - 5.0), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(accent.lightened(0.35), 0.85 * a))
			if key_hint != "":
				draw_rect(Rect2(r.position + Vector2(4, 3), Vector2(13, 14)), Color(0, 0, 0, 0.55))
				draw_string(f, r.position + Vector2(7, 14), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.75))

	func _icon(ir: Rect2, a: float) -> void:
		draw_rect(ir, Color(0.03, 0.05, 0.08, 0.75 * a))
		if erase_icon:
			var c := Color("#ff7a6a", a)
			var q := ir.grow(-8.0)
			draw_line(q.position, q.end, c, 4.0)
			draw_line(Vector2(q.end.x, q.position.y), Vector2(q.position.x, q.end.y), c, 4.0)
			return
		if not thumb.is_empty():
			var b := ShipPlan.bounds(thumb)
			var s := minf(ir.size.x / float(b.size.x), ir.size.y / float(b.size.y))
			s = floorf(s) if s > 1.0 else s
			var org := ir.position + (ir.size - Vector2(b.size) * s) * 0.5
			for k in thumb:
				var c2 := Shipyard._glyph_color(String(thumb[k]))
				draw_rect(Rect2(org + Vector2(k - b.position) * s, Vector2(s, s)), Color(c2, a))
			return
		var cells := {}
		Art.draw_cell(self, ir, Vector2i.ZERO, glyph, module, cells, false, Color(1, 1, 1, a))

## A framed sprite for the inspector.
class Icon extends Control:
	var glyph := ""
	var module := ""
	var accent := Color("#7fd4ff")

	func _init() -> void:
		custom_minimum_size = Vector2(56, 56)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.08))
		if glyph != "":
			Art.draw_cell(self, Rect2(Vector2(4, 4), size - Vector2(8, 8)), Vector2i.ZERO, glyph, module, {}, false)
		draw_rect(Rect2(Vector2.ZERO, size), Color(accent, 0.7), false, 2.0)

## A number with a bar behind it, that slides to new values and shows what just changed.
class StatRow extends Control:
	var title := ""
	var fmt := "%.0f"
	var dec := 0
	var value := 0.0
	var shown := 0.0
	var vmax := 1.0
	var vbase := 1.0
	var high_good := true
	var neutral_delta := false
	var tone := ""
	var text_override := ""
	var delta := 0.0
	var delta_t := 0.0
	var pulse := 0.0
	var _first := true

	func _init() -> void:
		custom_minimum_size = Vector2(0, 38)
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_process(false)

	func set_value(v: float, new_tone := "", txt := "") -> void:
		tone = new_tone
		text_override = txt
		vmax = maxf(vbase, v * 1.15)
		if _first:
			_first = false
			value = v
			shown = 0.0
			set_process(true)
			return
		if absf(v - value) > 0.0005:
			var d := v - value
			delta = (delta if delta_t > 0.0 and signf(d) == signf(delta) else 0.0) + d
			delta_t = 2.6
			pulse = 1.0
			value = v
			set_process(true)

	func _process(dt: float) -> void:
		var moving := absf(shown - value) > 0.001
		if moving:
			shown = lerpf(shown, value, 1.0 - exp(-9.0 * dt))
			if absf(shown - value) < 0.002 * maxf(1.0, absf(value)):
				shown = value
		if delta_t > 0.0:
			delta_t -= dt
		if pulse > 0.0:
			pulse = maxf(0.0, pulse - dt * 3.0)
		if moving or delta_t > 0.0 or pulse > 0.0:
			queue_redraw()
		else:
			set_process(false)

	func _tone_col() -> Color:
		match tone:
			"good": return UITheme.GOOD
			"warn": return UITheme.WARN
			"bad": return UITheme.BAD
		return Color("#5fb4e8")

	func _draw() -> void:
		var f := UITheme.font
		var w := size.x
		var vc := UITheme.TEXT
		if tone != "":
			vc = _tone_col()
		vc = vc.lerp(Color.WHITE, pulse * 0.6)
		draw_string(f, Vector2(2, 15), title, HORIZONTAL_ALIGNMENT_LEFT, w * 0.5, 14, UITheme.DIM)
		var txt := text_override if text_override != "" else fmt % shown
		draw_string(f, Vector2(0, 16), txt, HORIZONTAL_ALIGNMENT_RIGHT, w - 2.0, 17, vc)
		if delta_t > 0.0 and absf(delta) > 0.0005:
			var up := delta > 0.0
			var dc := Color("#9ab4c8")
			if not neutral_delta:
				dc = UITheme.GOOD if up == high_good else UITheme.BAD
			var al := clampf(delta_t / 0.8, 0.0, 1.0)
			var s := ("%+." + str(dec) + "f") % delta
			if text_override != "":
				s = ("+" if up else "-")
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			draw_string(f, Vector2(w - tw - 66.0, 16.0), s, HORIZONTAL_ALIGNMENT_RIGHT, 56.0, 14, Color(dc, al))
		# bar
		var by := 24.0
		draw_rect(Rect2(0, by, w, 7), Color(0.03, 0.05, 0.08))
		var frac := clampf(shown / maxf(0.0001, vmax), 0.0, 1.0)
		var c := _tone_col()
		draw_rect(Rect2(1, by + 1, (w - 2.0) * frac, 5), c.darkened(0.15))
		draw_rect(Rect2(1, by + 1, (w - 2.0) * frac, 2), c.lightened(0.35))
		if pulse > 0.0:
			draw_rect(Rect2(1, by + 1, (w - 2.0) * frac, 5), Color(1, 1, 1, pulse * 0.5))
		draw_rect(Rect2(0, by, w, 7), Color(0.3, 0.4, 0.5, 0.6), false, 1.0)
