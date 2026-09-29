class_name Intro extends Control
## The first thirty seconds.
##
## A game that opens by dumping nine lines into a chat log has told the player nothing,
## because nobody reads a log they have not learned to read yet. So the opening is a
## card: the port's name, where in the sky it is, what is in your pocket, and the one
## decision the game wants you to make.
##
## It is staged rather than shown. Letterbox bars slide in over a dusk sky with cloud decks
## drifting at three speeds and a ship crossing the horizon; the title's letters drop in,
## two rules are drawn outward from the middle, the lines type themselves and the purse
## counts up coin by coin. When it clears the bars retreat, the camera settles from a slow
## push-in and the quay is simply there, with the prompt about to slide in.
##
## It is deliberately short and deliberately skippable. The first press finishes the typing,
## the second dismisses it. It must never be the thing standing between a player and the
## game, only the thing that tells them which way to walk when it clears.

signal finished

## True from the moment the card exists until it has gone; the tutorial waits on this.
static var active := false

const HOLD_AFTER := 2.6   ## seconds the finished card stays up before it leaves by itself
const FADE_OUT := 1.9
const PUSH := 0.34        ## how much closer than normal the camera starts
const GOLD := Color("#e8c85a")

var _t := 0.0
var _title := ""
var _sub := ""
var _who := ""
var _entries: Array = []  ## {text, kind, start, dur, pre, post}
var _purse := 0
var _reveal_end := 0.0
var _exit_t := -1.0
var _pulse := 0.0
var _base_zoom := 2.0
var _ticks := 0
var _last_coin := -1
var _landed := false
var _clouds: Array = []
var _stars: Array = []
var _puff: GradientTexture2D

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	active = true

func setup(port_name: String, region: String, ring: String, purse: int, has_ship: bool,
		who := "", trade := "") -> Intro:
	_title = port_name.to_upper() if port_name.to_lower().begins_with("port") else ("PORT " + port_name.to_upper())
	_sub = "%s · %s · two thousand feet over nothing at all" % [ring, region]
	_purse = purse
	_who = "%s%s" % [who, ("  ·  " + trade) if trade != "" else ""]
	var lines: Array = []
	if has_ship:
		lines = [
			["Your ship is moored alongside.", "plain"],
			["She is fuelled, her cells are full, and her boiler is stone cold.", "plain"],
			["", "gap"],
			["Light it before you touch the wheel.", "accent"],
		]
	else:
		var skiff := 3203
		if Game.player != null:
			skiff = CShipyard.hull_price("skiff", Game.player)
		if purse >= skiff:
			lines = [
				["You have {n} marks and no ship.", "purse"],
				["That is, near enough, the price of a second-hand skiff.", "plain"],
				["", "gap"],
				["The yard is at the end of the quay. Buy one out of the book,", "plain"],
				["or spend the same money on one you draw yourself.", "plain"],
				["", "gap"],
				["Both are correct.", "accent"],
			]
		else:
			lines = [
				["You have {n} marks and no ship.", "purse"],
				["A second-hand skiff is %s. You are %s short." % [Economy.money(skiff), Economy.money(skiff - purse)], "plain"],
				["", "gap"],
				["The yard is at the end of the quay. Draw the leanest hull that", "plain"],
				["will fly on the yard master's board, or earn the difference first.", "plain"],
				["", "gap"],
				["Both are correct.", "accent"],
			]
	var at := 2.3
	for row in lines:
		var txt: String = row[0]
		var kind: String = row[1]
		if kind == "gap":
			at += 0.35
			continue
		var e := {"kind": kind, "start": at, "text": txt, "pre": "", "post": ""}
		if kind == "purse":
			var parts := txt.split("{n}")
			e["pre"] = parts[0]
			e["post"] = parts[1]
			e["dur"] = parts[0].length() * 0.028 + 1.15 + parts[1].length() * 0.028
		else:
			e["dur"] = maxf(0.5, txt.length() * 0.026)
		_entries.append(e)
		at += float(e["dur"]) + 0.3
	_reveal_end = at
	# a fixed seed, so every opening has the same sky and the tuning is repeatable
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for layer in 3:
		for i in 7:
			_clouds.append({"layer": layer, "x": rng.randf(), "y": rng.randf_range(0.0, 1.0),
				"w": rng.randf_range(240.0, 520.0) * (1.0 + layer * 0.35), "ph": rng.randf() * TAU})
	for i in 60:
		_stars.append(Vector3(rng.randf(), rng.randf() * 0.5, rng.randf() * TAU))
	_puff = GradientTexture2D.new()
	_puff.width = 128
	_puff.height = 128
	_puff.fill = GradientTexture2D.FILL_RADIAL
	_puff.fill_from = Vector2(0.5, 0.5)
	_puff.fill_to = Vector2(1.0, 0.5)
	var pg := Gradient.new()
	pg.set_color(0, Color(1, 1, 1, 1))
	pg.set_color(1, Color(1, 1, 1, 0))
	pg.add_point(0.5, Color(1, 1, 1, 0.55))
	_puff.gradient = pg
	if Game.view != null:
		_base_zoom = Game.view.zoom_level
	Sfx.play_ui(&"ui_stinger")
	return self

func _exit_tree() -> void:
	active = false

func _ready() -> void:
	set_process(true)
	set_process_input(true)

# ------------------------------------------------------------------ input
func _input(ev: InputEvent) -> void:
	if _exit_t >= 0.0 or _t < 0.35:
		return
	var pressed: bool = (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventMouseButton and ev.pressed)
	if not pressed:
		return
	accept_event()
	if _t < _reveal_end:
		# first press: finish the typing at once, so a reader is never made to wait
		_t = _reveal_end
		_landed = true
		Sfx.play_ui(&"ui_click", 0.6)
	else:
		_begin_exit()

func _begin_exit() -> void:
	if _exit_t >= 0.0:
		return
	_exit_t = 0.0
	Sfx.play_ui(&"ui_whoosh", 0.8)

# ------------------------------------------------------------------ time
static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)

static func _ease_in_out(x: float) -> float:
	return smoothstep(0.0, 1.0, clampf(x, 0.0, 1.0))

static func _ease_back(x: float) -> float:
	var c := 1.70158
	var k := clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + (c + 1.0) * k * k * k + c * k * k

func _process(delta: float) -> void:
	_t += delta
	_pulse += delta
	if _exit_t < 0.0 and _t >= _reveal_end + HOLD_AFTER:
		_begin_exit()
	if _exit_t >= 0.0:
		_exit_t += delta
	_sounds()
	_camera()
	queue_redraw()
	if _exit_t >= FADE_OUT:
		if Game.view != null:
			Game.view.zoom_level = _base_zoom
		active = false
		finished.emit()
		queue_free()

## Typing ticks, coin ticks and the landing chime, driven off the same clock as the drawing.
func _sounds() -> void:
	var typed := 0
	for e in _entries:
		var k: String = e["kind"]
		var n := int(clampf((_t - float(e["start"])) / 0.026, 0.0, float(String(e["text"]).length())))
		if k == "purse":
			n = int(clampf((_t - float(e["start"])) / 0.028, 0.0, float(String(e["pre"]).length())))
		typed += n
	var want := typed / 3
	if want > _ticks:
		_ticks = want
		Sfx.play_ui(&"ui_tick", 0.16, randf_range(0.9, 1.15))
	for e in _entries:
		if e["kind"] != "purse":
			continue
		var p := _count_p(e)
		if p > 0.0 and p < 1.0:
			var step := int(p * 24.0)
			if step != _last_coin:
				_last_coin = step
				Sfx.play_ui(&"ui_coin", 0.35, 0.9 + p * 0.5)
		elif p >= 1.0 and not _landed:
			_landed = true
			Sfx.play_ui(&"ui_confirm", 0.6)

## 0..1 through the purse counter, eased so the last marks arrive slowly.
func _count_p(e: Dictionary) -> float:
	var t0 := float(e["start"]) + String(e["pre"]).length() * 0.028
	return _ease_out((_t - t0) / 1.15) if _t >= t0 else 0.0

func _camera() -> void:
	if Game.view == null:
		return
	var total := _reveal_end + HOLD_AFTER + FADE_OUT
	var p := _ease_in_out(_t / total)
	Game.view.zoom_level = _base_zoom * (1.0 + PUSH * (1.0 - p))

## 1 while the card is up, easing to 0 as it leaves.
func _leave_p() -> float:
	return _ease_in_out(_exit_t / FADE_OUT) if _exit_t >= 0.0 else 0.0

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	var vs := size
	var f := UITheme.font
	var leave := _leave_p()
	var a := 1.0 - leave
	var enter := _ease_out(_t / 0.9)
	# ---- the sky: it is the card's own backdrop, and it dissolves to show the quay
	var back := 0.97 * (1.0 - _ease_in_out((leave - 0.05) / 0.95))
	var top_c := Color(0.015, 0.025, 0.06, back)
	var mid_c := Color(0.07, 0.11, 0.2, back)
	var hor_c := Color(0.34, 0.26, 0.27, back)
	var hy := vs.y * 0.74
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, hy * 0.6), Vector2(0, hy * 0.6)]),
		PackedColorArray([top_c, top_c, mid_c, mid_c]))
	draw_polygon(PackedVector2Array([Vector2(0, hy * 0.6), Vector2(vs.x, hy * 0.6), Vector2(vs.x, hy), Vector2(0, hy)]),
		PackedColorArray([mid_c, mid_c, hor_c, hor_c]))
	draw_rect(Rect2(0, hy, vs.x, vs.y - hy), Color(0.05, 0.07, 0.12, back))
	for s in _stars:
		var tw := 0.4 + 0.6 * (0.5 + 0.5 * sin(_t * 1.3 + s.z))
		draw_rect(Rect2(s.x * vs.x, s.y * hy, 2, 2), Color(0.85, 0.92, 1.0, back * 0.5 * tw))
	_draw_clouds(vs, hy, back)
	_draw_ship(vs, hy, back)
	# ---- letterbox: slides in, and out again as the card clears
	var bar := vs.y * 0.085 * enter * (1.0 - _ease_in_out(leave * 1.25))
	if bar > 0.5:
		draw_rect(Rect2(0, 0, vs.x, bar), Color(0.0, 0.0, 0.0, 1.0))
		draw_rect(Rect2(0, vs.y - bar, vs.x, bar), Color(0.0, 0.0, 0.0, 1.0))
		draw_rect(Rect2(0, bar - 1.0, vs.x, 1.0), Color(UITheme.ACCENT, 0.35 * a))
		draw_rect(Rect2(0, vs.y - bar, vs.x, 1.0), Color(UITheme.ACCENT, 0.35 * a))
	# the creator fades to black; the card comes up out of that black rather than cutting in
	var veil := 1.0 - _ease_out(_t / 0.8)
	if veil > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, veil))
	if a <= 0.001:
		return

	var cx := vs.x * 0.5
	var top := vs.y * 0.27 - leave * 26.0
	var rule := minf(760.0, vs.x - 64.0)
	var accent := Color(UITheme.ACCENT, a)

	# ---- top rule, drawn outward from the middle
	var rp := _ease_out((_t - 0.25) / 0.9)
	var half := rule * 0.5 * rp
	draw_line(Vector2(cx - half, top - 30), Vector2(cx + half, top - 30), accent, 2.0)
	# ---- the title: letters drop in one after another, with a flash as each lands
	var fs := 46 if vs.x >= 900.0 else 32
	var track := 8.0
	var total_w := 0.0
	for ch in _title:
		total_w += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + track
	total_w -= track
	var x := cx - total_w * 0.5
	for i in _title.length():
		var ch := _title.substr(i, 1)
		var lp := (_t - 0.5 - i * 0.055) / 0.5
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if lp > 0.0:
			var yo := (1.0 - _ease_back(lp)) * -26.0
			var al := clampf(lp * 2.5, 0.0, 1.0) * a
			var flash := clampf(1.0 - lp, 0.0, 1.0)
			var col := Color(1, 1, 1, al).lerp(Color(UITheme.ACCENT, al), flash * 0.9)
			draw_string(f, Vector2(x + 2, top + 18 + yo + 2), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, al * 0.5))
			draw_string(f, Vector2(x, top + 18 + yo), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += w + track
	# ---- the sub-title fades up under it
	var sp := _ease_out((_t - 1.35) / 0.8)
	if sp > 0.0:
		draw_string(f, Vector2(cx - rule * 0.5, top + 50 + (1.0 - sp) * 8.0), _sub, HORIZONTAL_ALIGNMENT_CENTER,
			rule, 16, Color(UITheme.DIM, sp * a))
	# ---- bottom rule, with a diamond that pops at the end
	var bp := _ease_out((_t - 1.0) / 0.9)
	var bh := rule * 0.5 * bp
	draw_line(Vector2(cx - bh, top + 68), Vector2(cx + bh, top + 68), Color(accent, a * 0.45), 1.0)
	var dp := _ease_back((_t - 1.8) / 0.4)
	if dp > 0.0:
		var d := 5.0 * dp
		draw_colored_polygon(PackedVector2Array([Vector2(cx, top + 68 - d), Vector2(cx + d, top + 68),
			Vector2(cx, top + 68 + d), Vector2(cx - d, top + 68)]), Color(GOLD, a))
	# ---- who you are
	if _who != "":
		var wp := _ease_out((_t - 1.75) / 0.7)
		if wp > 0.0:
			draw_string(f, Vector2(cx - rule * 0.5, top + 96), _who, HORIZONTAL_ALIGNMENT_CENTER, rule, 15,
				Color(UITheme.ACCENT, wp * a * 0.85))

	# ---- the lines, typed
	var lfs := 20
	for e in _entries:
		var w0 := 0.0
		w0 = maxf(w0, f.get_string_size(String(e["text"]).replace("{n}", Economy.money(_purse)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x)
		if w0 > rule:
			lfs = maxi(14, int(lfs * rule / w0))
	var y := top + 138.0
	for e in _entries:
		# every entry keeps its slot whether or not it has started, so nothing shifts
		var kind: String = e["kind"]
		var col2 := Color(UITheme.TEXT, a)
		if kind == "accent":
			col2 = Color(UITheme.ACCENT, a)
		var age: float = _t - float(e["start"])
		if age >= 0.0:
			if kind == "purse":
				_draw_purse(f, e, cx, y, lfs, a, age)
			else:
				var text: String = e["text"]
				var n := int(clampf(age / 0.026, 0.0, float(text.length())))
				var full_w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
				var shown := text.substr(0, n)
				draw_string(f, Vector2(cx - full_w * 0.5, y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, col2)
				if n < text.length():
					var cw := f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
					draw_rect(Rect2(cx - full_w * 0.5 + cw + 2, y - lfs + 3, 8, lfs - 2),
						Color(UITheme.ACCENT, a * (0.5 + 0.5 * sin(_pulse * 20.0))))
		y += 30.0 if kind != "gap" else 12.0
		# gaps are not entries, so blank space is added between groups by their start times
		var idx := _entries.find(e)
		if idx + 1 < _entries.size() and float(_entries[idx + 1]["start"]) - float(e["start"]) - float(e["dur"]) > 0.5:
			y += 16.0

	# ---- the prompt, breathing, once there is nothing left to read
	if _t >= _reveal_end and _exit_t < 0.0:
		var pa := _ease_out((_t - _reveal_end) / 0.6)
		var blink := 0.5 + 0.5 * sin(_pulse * 2.6)
		draw_string(f, Vector2(cx - rule * 0.5, vs.y - bar - 34.0), "press any key",
			HORIZONTAL_ALIGNMENT_CENTER, rule, 15, Color(UITheme.DIM, pa * (0.35 + 0.65 * blink)))

func _draw_purse(f: Font, e: Dictionary, cx: float, y: float, lfs: int, a: float, age: float) -> void:
	var pre: String = e["pre"]
	var post: String = e["post"]
	var final_num := Economy.money(_purse)
	var wpre := f.get_string_size(pre, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	var wnum := f.get_string_size(final_num, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	var wpost := f.get_string_size(post, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	var x0 := cx - (wpre + wnum + wpost) * 0.5
	var npre := int(clampf(age / 0.028, 0.0, float(pre.length())))
	draw_string(f, Vector2(x0, y), pre.substr(0, npre), HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(GOLD, a))
	var p := _count_p(e)
	if npre >= pre.length():
		var v := int(round(_purse * p))
		var pop := 1.0
		if p >= 1.0:
			pop = 1.0 + 0.25 * maxf(0.0, 1.0 - (_t - (float(e["start"]) + pre.length() * 0.028 + 1.15)) * 5.0)
		var col := Color(GOLD, a).lerp(Color(1, 1, 1, a), 0.6 * (pop - 1.0) * 4.0)
		draw_string(f, Vector2(x0 + wpre, y), Economy.money(v), HORIZONTAL_ALIGNMENT_LEFT, -1, int(lfs * pop), col)
	if p >= 1.0:
		var t_end := float(e["start"]) + pre.length() * 0.028 + 1.15
		var m := int(clampf((_t - t_end) / 0.028, 0.0, float(post.length())))
		draw_string(f, Vector2(x0 + wpre + wnum, y), post.substr(0, m), HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(GOLD, a))

## Three cloud decks drifting at different speeds: the far one pale and slow, the near one
## dark and quick, so the card has depth without a single texture.
func _draw_clouds(vs: Vector2, hy: float, back: float) -> void:
	if back <= 0.01:
		return
	for c in _clouds:
		var layer: int = c["layer"]
		var w: float = c["w"]
		var speed := 5.0 + layer * 9.0
		var span := vs.x + w * 2.0
		var px := fposmod(float(c["x"]) * span + _t * speed, span) - w
		var py := hy - 40.0 + (float(c["y"]) - 0.5) * (150.0 + layer * 130.0) + layer * 40.0
		py += sin(_t * 0.3 + float(c["ph"])) * 3.0
		var col: Color
		match layer:
			0: col = Color(0.42, 0.36, 0.4, 0.10 * back)
			1: col = Color(0.22, 0.24, 0.34, 0.20 * back)
			_: col = Color(0.06, 0.08, 0.13, 0.40 * back)
		var h := w * 0.22
		# five soft puffs make one lumpy cloud with no hard edge anywhere on it
		for k in 5:
			var fx := (k - 2) * 0.22
			var fw := w * (0.62 - absf(k - 2) * 0.1)
			var fh := h * (1.0 - absf(k - 2) * 0.12)
			draw_texture_rect(_puff, Rect2(px + w * fx - fw * 0.5, py - fh * 0.5 + (k % 2) * 3.0, fw, fh), false, col)

## A small ship crossing the horizon, as dark as the sky lets her be, with one lit window.
func _draw_ship(vs: Vector2, hy: float, back: float) -> void:
	if back <= 0.01:
		return
	var k := clampf(vs.x / 1920.0, 0.6, 1.4)
	var span := vs.x + 700.0
	var x := fposmod(vs.x * 0.12 + _t * 22.0, span) - 200.0
	var pos := Vector2(x, hy - 96.0 * k + sin(_t * 0.7) * 6.0)
	var dark := Color(0.012, 0.018, 0.04, back)
	var env := PackedVector2Array()
	for i in 24:
		var an := TAU * i / 24.0
		env.append(pos + Vector2(cos(an) * 110.0 * k, -34.0 * k + sin(an) * 32.0 * k))
	draw_colored_polygon(env, dark)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-100, -36) * k, pos + Vector2(-146, -66) * k,
		pos + Vector2(-128, -30) * k]), dark)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-100, -30) * k, pos + Vector2(-146, 0) * k,
		pos + Vector2(-120, -30) * k]), dark)
	draw_rect(Rect2(pos + Vector2(-46, 2) * k, Vector2(90, 20) * k), dark)
	draw_line(pos + Vector2(-34, -6) * k, pos + Vector2(-34, 2) * k, dark, 2.0)
	draw_line(pos + Vector2(34, -6) * k, pos + Vector2(34, 2) * k, dark, 2.0)
	# lantern light on the gondola, and a warm rim along the top of the envelope
	var warm := Color(1.0, 0.72, 0.4, back)
	draw_circle(pos + Vector2(6, 12) * k, 9.0 * k, Color(warm, 0.14 * back))
	draw_rect(Rect2(pos + Vector2(2, 9) * k, Vector2(8, 6) * k), Color(warm, 0.9 * back))
	var rim := PackedVector2Array()
	for i in 13:
		var an2 := PI + PI * i / 12.0 * 0.78 + PI * 0.12
		rim.append(pos + Vector2(cos(an2) * 108.0 * k, -34.0 * k + sin(an2) * 30.0 * k))
	draw_polyline(rim, Color(warm, 0.3 * back), 2.0)

## Debug: `--introshot=DIR` walks the whole opening on a script and saves a screenshot at each
## beat, because none of it can be judged from a still. Owned by the intro; not used in play.
class Shots extends Node:
	var dir := ""
	var t := 0.0
	var beat := 0
	var script_times := [1.2, 2.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0, 25.1, 28.1, 31.1, 34.1, 35.9, 36.7, 38.6, 40.6, 41.6]
	var main: Node

	func _process(delta: float) -> void:
		t += delta
		while beat < script_times.size() and t >= script_times[beat]:
			_beat(beat)
			beat += 1
		if beat >= script_times.size() and t > script_times[-1] + 1.0:
			get_tree().quit()

	func _shot(nm: String) -> void:
		if DisplayServer.get_name() == "headless":
			return
		var img := get_viewport().get_texture().get_image()
		if img:
			img.save_png("%s/%s.png" % [dir, nm])

	func _beat(i: int) -> void:
		var cr = main.get("creator")
		var live: bool = cr != null and is_instance_valid(cr)
		match i:
			0: _shot("a_creator_typing")
			1:
				if live:
					cr._skip_intro()
			2: _shot("b1_origin")
			3:
				if live:
					cr.origin_btns[3].pressed.emit()
					cr.reason_btns["debt"].pressed.emit()
			4: _shot("b2_origin_heights")
			5:
				if live:
					cr._go_step(1)
			6: _shot("c1_calling")
			7:
				if live:
					cr.calling_btns["gunner"].pressed.emit()
					cr.calling_btns["navigator"].mouse_entered.emit()
			8: _shot("c2_calling_gunner_preview_navigator")
			9:
				if live:
					cr._go_step(2)
			10: _shot("d1_look")
			11:
				if live:
					cr.app["hair"] = "braids"
					cr.app["facial"] = "handlebar"
					cr._refresh()
					cr._turn(1)
					cr.scroll.scroll_vertical = 600
			12: _shot("d2_look_scrolled_turned")
			13:
				if live:
					cr.quirks = ["alcohol_tolerance", "freerunning", "jolly", "family_heirloom", "light_drinker"]
					cr._go_step(3)
			14: _shot("e1_habits")
			15:
				if live:
					cr._go_step(4)
			16: _shot("f1_papers")
			17:
				if live:
					cr._shuffle()
			18: _shot("f2_shuffle_midroll")
			19:
				if live:
					cr._sign_on()
			20: _shot("g1_stamp")
			21: _shot("g2_stamp_late")
			22: _shot("g3_leaving")
			23: _shot("h_card_a")
			24: _shot("h_card_b")
			25: _shot("i_card_c")
			26: _shot("i_card_d")
			27: _shot("j_card_e")
			28: _shot("j_card_fade")
			29: _shot("k_world")
			30: _shot("l_tutorial")
			31: _shot("m_end")
