class_name HudWidgets extends RefCounted
## Small drawn widgets for the HUD: vital bars with their icon, the heart monitor, the
## cooldown shade on the evade buttons, and the station map.


## A vertical vital-sign bar (Burgerstation's health / stamina columns): an icon on top,
## a recessed well with a textured fill, a blink when it runs low.
class VitalBar extends Control:
	var icon_name: String
	var fill_name: String
	var value := 100.0
	var low := 25.0 # blinks under this (or over it, for `inverted` bars like stress)
	var inverted := false
	var tint := Color.WHITE
	var _t := 0.0

	func _init(icon: String, fill: String, tip: String) -> void:
		icon_name = icon
		fill_name = fill
		tooltip_text = tip
		custom_minimum_size = Vector2(30, 118)
		mouse_filter = Control.MOUSE_FILTER_PASS
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void:
		_t += delta
		if _alarm():
			queue_redraw()

	func _alarm() -> bool:
		return value > 100.0 - low if inverted else value < low

	func set_value(v: float) -> void:
		v = clampf(v, 0.0, 100.0)
		if absf(v - value) > 0.05:
			value = v
			queue_redraw()

	func _draw() -> void:
		var ic := UITheme.tex("icon_" + icon_name)
		var isz := Vector2(28, 28)
		var ip := Vector2((size.x - isz.x) * 0.5, 0)
		var blink := _alarm() and fmod(_t, 0.8) < 0.4
		draw_texture_rect(ic, Rect2(ip, isz), false, Color(1.6, 0.7, 0.6) if blink else Color.WHITE)
		var well := Rect2(Vector2(3, 32), Vector2(size.x - 6, size.y - 32))
		draw_style_box(UITheme.frame("well", 0, 0), well)
		var inner := well.grow(-4)
		var h := floorf(inner.size.y * value / 100.0 / 2.0) * 2.0
		if h > 0:
			var fr := Rect2(Vector2(inner.position.x, inner.end.y - h), Vector2(inner.size.x, h))
			var fs := UITheme.fill(fill_name)
			fs.modulate_color = tint
			draw_style_box(fs, fr)
			# a bright cap line
			draw_rect(Rect2(fr.position, Vector2(fr.size.x, 2)), Color(1, 1, 1, 0.35))
		# tick marks every quarter
		for i in range(1, 4):
			var y := inner.end.y - inner.size.y * i / 4.0
			draw_rect(Rect2(Vector2(inner.position.x, y), Vector2(3, 2)), Color(0, 0, 0, 0.45))


## tg's mood face (/atom/movable/screen/mood): a face that smiles or frowns with your mood
## level (1-9), tinted by sanity, over a bar of sanity (0-150). Click it for how you feel.
class MoodFace extends Control:
	var level := 5
	var sanity := 100.0
	var col := Color("#86d656")
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(30, 118)
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "Mood
Click to see how you feel."

	func set_mood(md: CMood) -> void:
		var c: Color = CMood.SANITY_COLORS[md.sanity_level]
		if md.mood_level != level or absf(md.sanity - sanity) > 0.2 or c != col:
			level = md.mood_level
			sanity = md.sanity
			col = c
			queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		if level <= 2:
			queue_redraw()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var p := Game.player
			if p and p.has_c(&"mood") and not p.c(&"health").knocked_out():
				Game.tell(p, p.c(&"mood").report())
			accept_event()

	func _draw() -> void:
		# the face
		var c := Vector2(size.x * 0.5, 14)
		var r := 12.0
		var blink := level <= 2 and fmod(_t, 0.8) < 0.4
		draw_circle(c, r + 1.5, Color(0, 0, 0, 0.6))
		draw_circle(c, r, col.lerp(Color(1.4, 0.6, 0.5), 0.5) if blink else col)
		var ink := Color(0.08, 0.1, 0.14)
		draw_rect(Rect2(c + Vector2(-5, -4), Vector2(2, 3)), ink)
		draw_rect(Rect2(c + Vector2(3, -4), Vector2(2, 3)), ink)
		# the mouth: a curve from a deep frown (1) to a wide grin (9)
		var bend := (level - 5) / 4.0 * 4.0
		var pts := PackedVector2Array()
		for i in 9:
			var x := -6.0 + i * 1.5
			pts.append(c + Vector2(x, 4.0 - bend * (1.0 - pow(x / 6.0, 2.0)) + (0.0 if bend >= 0 else bend)))
		draw_polyline(pts, ink, 2.0)
		# sanity well
		var well := Rect2(Vector2(3, 32), Vector2(size.x - 6, size.y - 32))
		draw_style_box(UITheme.frame("well", 0, 0), well)
		var inner := well.grow(-4)
		var h := floorf(inner.size.y * clampf(sanity / 150.0, 0.0, 1.0) / 2.0) * 2.0
		if h > 0:
			var fr := Rect2(Vector2(inner.position.x, inner.end.y - h), Vector2(inner.size.x, h))
			draw_rect(fr, col.darkened(0.15))
			draw_rect(Rect2(fr.position, Vector2(fr.size.x, 2)), Color(1, 1, 1, 0.35))
		# tg sanity lines: disturbed 75, neutral 100, great 125
		for s in [75.0, 100.0, 125.0]:
			var y: float = inner.end.y - inner.size.y * s / 150.0
			draw_rect(Rect2(Vector2(inner.position.x, y), Vector2(3, 2)), Color(0, 0, 0, 0.45))


## A little ECG trace: rate follows your heart (stress, exhaustion, blood loss), the
## trace goes ragged when you're badly hurt and flat when you're dead.
class Heartbeat extends Control:
	var bpm := 72.0
	var severity := 0 # CHealth.severity(): 0 fine .. 4 critical, 5 dead
	const WINDOW := 3.0 # seconds of trace shown
	const N := 220
	var _time := 0.0
	var _beats: Array = [] # start time of each beat in the window

	func _init() -> void:
		custom_minimum_size = Vector2(150, 34)
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = "Heart rate"

	func _process(delta: float) -> void:
		_time += delta
		var beat := 60.0 / maxf(bpm, 1.0)
		if severity < 5 and (_beats.is_empty() or _time - _beats[-1] >= beat):
			_beats.append(_time)
		while not _beats.is_empty() and _beats[0] < _time - WINDOW - 1.0:
			_beats.pop_front()
		var tip := "Heart rate: %d bpm" % int(bpm) if severity < 5 else "No pulse."
		if tip != tooltip_text:
			tooltip_text = tip
		queue_redraw()

	## The trace height at time t: P wave, QRS spike and T wave after each beat.
	func _wave(t: float) -> float:
		var y := 0.0
		for b in _beats:
			var s: float = t - b
			if s < 0.0 or s > 0.6:
				continue
			y += 0.12 * exp(-pow((s - 0.06) / 0.025, 2.0))
			y += -0.16 * exp(-pow((s - 0.15) / 0.009, 2.0))
			y += 1.0 * exp(-pow((s - 0.175) / 0.011, 2.0))
			y += -0.28 * exp(-pow((s - 0.2) / 0.01, 2.0))
			y += 0.22 * exp(-pow((s - 0.38) / 0.045, 2.0))
		if severity >= 4 and severity < 5:
			y += sin(t * 37.0) * 0.05 + sin(t * 91.0) * 0.04
		return y

	func _draw() -> void:
		draw_style_box(UITheme.frame("well", 0, 0), Rect2(Vector2.ZERO, size))
		var r := Rect2(Vector2(5, 4), size - Vector2(10, 8))
		# grid
		for x in range(int(r.position.x) + 6, int(r.end.x), 12):
			draw_rect(Rect2(Vector2(x, r.position.y), Vector2(1, r.size.y)), Color(0.2, 0.5, 0.35, 0.18))
		var col: Color = [Color("#6ae88a"), Color("#a8e86a"), Color("#e8d84a"), Color("#ff9a4a"), Color("#ff5a4a"), Color("#8a8a8a")][clampi(severity, 0, 5)]
		var pts := PackedVector2Array()
		for i in N:
			var v := _wave(_time - WINDOW * (1.0 - i / float(N - 1)))
			pts.append(Vector2(r.position.x + r.size.x * i / float(N - 1), r.position.y + r.size.y * (0.7 - v * 0.62)))
		draw_polyline(pts, Color(col, 0.22), 4.0)
		draw_polyline(pts, col, 2.0)
		draw_circle(pts[N - 1], 2.5, Color.WHITE)
		var txt := "%d" % int(bpm) if severity < 5 else "--"
		draw_string(UITheme.font, Vector2(r.end.x - 26, r.position.y + 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col, 0.9))


## Darkens a button from the top while its ability recharges.
class Cooldown extends Control:
	var fn: Callable # -> float 0..1 (1 = just used)

	func _init(f: Callable) -> void:
		fn = f
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	var _was := 0.0

	func _process(_d: float) -> void:
		var v: float = fn.call() if fn.is_valid() else 0.0
		if v > 0.0 or _was > 0.0:
			queue_redraw()
		_was = v

	func _draw() -> void:
		var v: float = clampf(fn.call(), 0.0, 1.0) if fn.is_valid() else 0.0
		if v <= 0.0:
			return
		var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * v)), Color(0.0, 0.02, 0.05, 0.62))


## The station map (M): every wall and floor, rooms tinted by department, doors, you.
class StationMapView extends Control:
	const DEPT := {"command": Color("#3a5a9a"), "security": Color("#9a3a3a"), "engineering": Color("#b8862a"), "medical": Color("#4aa8c8"),
		"science": Color("#8a5ab8"), "service": Color("#5a9a4a"), "supply": Color("#9a7a4a"), "civilian": Color("#5a6a7a"), "maint": Color("#3a3f46")}
	var img_tex: ImageTexture
	var bounds := Rect2i()
	var hot_area: Area
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(760, 560)
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_render()

	func _render() -> void:
		var m := Game.map
		if m == null:
			return
		var lo := Vector2i(m.w, m.h)
		var hi := Vector2i.ZERO
		for y in m.h:
			for x in m.w:
				var c := Vector2i(x, y)
				if _indoor(c):
					lo = lo.min(c)
					hi = hi.max(c)
		bounds = Rect2i(lo - Vector2i(2, 2), hi - lo + Vector2i(5, 5))
		var img := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.03, 0.05, 0.08, 1.0))
		for y in bounds.size.y:
			for x in bounds.size.x:
				var c := bounds.position + Vector2i(x, y)
				if not m.inb(c):
					continue
				if m.is_wall(c):
					# station walls bright; bare asteroid rock barely there
					var hull := false
					for d in Defs.DIRS8:
						if _indoor(c + d):
							hull = true
					img.set_pixel(x, y, Color("#8fa4b8") if hull else Color(0.09, 0.11, 0.14))
				elif _indoor(c):
					var a := m.area_at(c)
					var col: Color = DEPT.get(a.dept if a else "civilian", DEPT["civilian"])
					if a and ("maint" in a.name.to_lower() or a.room_kind == "maint"):
						col = DEPT["maint"]
					img.set_pixel(x, y, col.darkened(0.35) if (x + y) % 2 else col.darkened(0.28))
				else:
					img.set_pixel(x, y, Color(0.07, 0.1, 0.14) if (x * 7 + y * 3) % 11 else Color(0.1, 0.13, 0.18))
		for d in Game.all_with(&"door"):
			var p: Vector2i = d.cell - bounds.position
			if p.x >= 0 and p.y >= 0 and p.x < bounds.size.x and p.y < bounds.size.y:
				img.set_pixel(p.x, p.y, Color("#e8d86a"))
		img_tex = ImageTexture.create_from_image(img)

	func _indoor(c: Vector2i) -> bool:
		var m := Game.map
		if not m.inb(c) or m.is_wall(c) or m.is_outdoor(c):
			return false
		var a := m.area_at(c)
		return a != null and not a.outdoor

	const LEGEND_W := 130.0

	func _scale() -> float:
		return floorf(minf((size.x - LEGEND_W) / bounds.size.x, size.y / bounds.size.y) * 2.0) / 2.0

	func _origin() -> Vector2:
		return Vector2(LEGEND_W, 0) + (size - Vector2(LEGEND_W, 0) - Vector2(bounds.size) * _scale()) * 0.5

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion and Game.map:
			var c := bounds.position + Vector2i(((ev.position - _origin()) / _scale()).floor())
			var a: Area = Game.map.area_at(c) if Game.map.inb(c) else null
			if a and a.outdoor:
				a = null
			if a != hot_area:
				hot_area = a
				tooltip_text = a.name if a else ""

	func _draw() -> void:
		if img_tex == null:
			return
		var s := _scale()
		var o := _origin()
		draw_texture_rect(img_tex, Rect2(o, Vector2(bounds.size) * s), false)
		if hot_area:
			for c in hot_area.cells:
				var p: Vector2 = o + Vector2(c - bounds.position) * s
				draw_rect(Rect2(p, Vector2(s, s)), Color(1, 1, 1, 0.16))
			var lp: Vector2 = o + Vector2(hot_area.center - bounds.position) * s
			var tw := UITheme.font.get_string_size(hot_area.name, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.SMALL).x
			draw_string_outline(UITheme.font, lp - Vector2(tw * 0.5, 0), hot_area.name, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.SMALL, 6, Color(0, 0, 0, 0.9))
			draw_string(UITheme.font, lp - Vector2(tw * 0.5, 0), hot_area.name, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.SMALL, Color.WHITE)
		if Game.player:
			var pp: Vector2 = o + (Vector2(Game.player.cell - bounds.position) + Vector2(0.5, 0.5)) * s
			var pr := 3.0 + 2.0 * (0.5 + 0.5 * sin(_t * 5.0))
			draw_circle(pp, pr + 2.0, Color(0, 0, 0, 0.6))
			draw_circle(pp, pr, UITheme.ACCENT)
		# legend
		var y := 8.0
		for k in ["command", "security", "engineering", "medical", "science", "service", "supply", "civilian", "maint"]:
			draw_rect(Rect2(Vector2(8, y), Vector2(12, 12)), DEPT[k])
			draw_rect(Rect2(Vector2(8, y), Vector2(12, 12)), Color(0, 0, 0, 0.6), false, 1.0)
			draw_string(UITheme.font, Vector2(26, y + 11), "crawlspace" if k == "maint" else (Defs.DEPARTMENTS[k]["name"].to_lower() if Defs.DEPARTMENTS.has(k) else k), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.SMALL, UITheme.DIM)
			y += 18.0
