class_name Tutorial extends Control
## Teaching someone to fly a ship they have never seen.
##
## Watches completed milestones in order, so starting alongside land cannot skip flying.
## Lighting the boiler early also completes the prompt to find it.
##
## Press F7 to turn it off. It retires itself once you have been ashore and back.

const W := 500.0
const PAD := 12.0

## id, the line shown, and the test for "you have done this"
var steps: Array = []
var step := 0
var done := false
var muted := false
var _t := 0.0
var _flash := 0.0
var _last := -1
var _shown := 0          ## the step on screen; lags `step` while a completed one plays its tick
var _check_t := 0.0      ## time left on the completion flourish
var _finish_pending := false
var _slide := 0.0        ## 0..1 entrance of the current prompt
var _reveal := 0.0       ## characters of the body typed so far
var _prog := 0.0         ## the progress bar, eased toward the real thing
var _appeared := false
var _anim := 0.0

func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	custom_minimum_size = Vector2(W, 64)
	position = Vector2(-W * 0.5, 62.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	steps = [
		# ---- the port. Three steps, and the third one is the whole opening decision.
		{"id": "board",
			"text": "Read the NOTICE BOARD on the quay. It is the one object in this game worth reading.",
			"hint": "WASD to walk. Click the board to read. Tab opens your inventory; drag items to move them.",
			"test": func(): return _read_board() or _has_ship()},
		{"id": "look",
			"text": "Walk the quay. Every door is a trader, and each of them sells something you will \
eventually need.",
			"hint": "Click a shopkeeper to open their counter.  J opens your own bench at any time.",
			"test": func(): return _visited_shop() or _has_ship()},
		{"id": "yard",
			"text": "Find the YARD at the end of the quay and open the yard master's desk. Weigh your purse \
against the price of a skiff.",
			"hint": "Buy one out of the book, or draw your own. Both are correct.",
			"test": func(): return _yard_open() or _has_ship()},
		{"id": "buy",
			"text": "Choose a hull. 'The book' has ready-made ones; 'Structure' and 'Modules' let you draw \
your own. The panel on the right tells you whether she will fly.",
			"hint": "Mirror is on, so you draw one side and get the other. F wraps the deck in hull. L shows leaks.",
			"test": func(): return _has_ship()},
		# ---- and then the ship, which is the old tutorial, still correct
		{"id": "find_boiler",
			"text": "She is yours and her boiler is cold. Walk to the BOILER — the riveted iron box with \
the round gauge.",
			"hint": "WASD to walk.  Press G any time to see every system aboard.",
			"test": func(): return _near("ship_boiler", 1) or _lit()},
		{"id": "light",
			"text": "RIGHT-CLICK the boiler, then click 'Light the burner'. She cannot move without steam.",
			"hint": "Or press G and click the Light button there.",
			"test": func(): return _lit()},
		{"id": "pressure",
			"text": "Wait for pressure. Watch the boiler gauge climb on the G panel.",
			"hint": "It takes about ten seconds to raise steam from cold.",
			"test": func(): return _steam()},
		{"id": "wheel",
			"text": "Steam is up. LEFT-CLICK the ship's wheel to take it.",
			"hint": "The wheel is the spoked one on the brass pedestal.",
			"test": func(): return Helm.of(Game.player) != null},
		{"id": "throttle",
			"text": "You have the wheel. HOLD W to open the throttle. The readout at the bottom shows THR rising.",
			"hint": "S closes the throttle.  SPACE is all stop.",
			"test": func(): return _throttle() > 0.25},
		{"id": "moving",
			"text": "She is making way. Press A or D to put the rudder over — she takes a few seconds to come about.",
			"hint": "The compass on the readout shows the bow. North is up, the same as the screen.",
			"test": func(): return _turned()},
		{"id": "trim",
			"text": "HOLD E to trim heavier and stop her climbing. Get the TRIM bar to the middle.",
			"hint": "Q trims lighter and she rises.  Full cells float high, so you will be trimming down.",
			"test": func(): return _trimmed()},
		{"id": "island",
			"text": "Steer for an island. When you are alongside it, press SPACE to stop.",
			"hint": "The aether compass in your locker points at the nearest land.",
			"test": func(): return _alongside()},
		{"id": "ashore",
			"text": "Alongside. Let go of the wheel (click it), then WALK INTO THE RAIL to climb over and go ashore.",
			"hint": "A bulwark is chest height. You climb it — you do not walk through it.",
			"test": func(): return _ashore()},
		{"id": "back",
			"text": "That is the whole loop: raise steam, fly, moor, climb ashore. Climb back over the rail to get aboard.",
			"hint": "SHIFT + a direction steps off a ledge on purpose. Nothing else will.",
			"test": func(): return _aboard_again()},
		{"id": "gather",
			"text": "Now make something. Cut a tree with an axe, break rock with a pick, cut fibre with a knife \
— then press J and turn it into a part for her.",
			"hint": "Everything you gather feeds something you can fit. The bench list shows what is missing.",
			"test": func(): return _crafted()},
		{"id": "outward",
			"text": "Last thing: the sky is in rings. The Home Reach will not kill you and has nothing worth \
having. Everything good is further out. Go and see.",
			"hint": "The ring you are in shows next to your location, top left. Ports get scarcer as you go.",
			"test": func(): return _left_home()},
	]

func _ready() -> void:
	set_process(true)
	Bus.stimulus.connect(_on_stimulus)

var _left_layout := false

## Centred at the top when there is room between the status plaque and the message log,
## otherwise tucked under the plaque at the left so it never covers either.
func _layout() -> void:
	var vw := get_parent_area_size().x
	var left := vw < 1700.0
	if left == _left_layout and _appeared:
		return
	_left_layout = left
	if left:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		position = Vector2(12.0, 104.0)
	else:
		# offsets, not `position`: with a centre anchor the offsets are relative to the centre
		set_anchors_preset(Control.PRESET_CENTER_TOP)
		offset_left = -W * 0.5
		offset_right = W * 0.5
		offset_top = 62.0
		offset_bottom = 62.0 + maxf(custom_minimum_size.y, 64.0)

func _process(delta: float) -> void:
	if done or muted:
		visible = false
		_dirty = true
		return
	# nothing slides in over the cold-open card; it arrives just as the card clears
	if Game.player == null or not Game.running or Intro.active:
		visible = false
		return
	visible = true
	_layout()
	if not _appeared:
		_appeared = true
		_slide = 0.0
		Sfx.play_ui(&"ui_open", 0.5)
	if Game.paused:
		return
	_anim += delta
	_slide = minf(1.0, _slide + delta / 0.55)
	_reveal += delta * 130.0
	_prog = lerpf(_prog, float(step) / steps.size(), minf(1.0, delta * 5.0))
	_t -= delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	if _check_t > 0.0:
		_check_t -= delta
		if _check_t <= 0.0:
			if _finish_pending:
				done = true
				return
			_shown = mini(step, steps.size() - 1)
			_slide = 0.0
			_reveal = 0.0
			Sfx.play_ui(&"ui_whoosh", 0.22, 1.5)
	# redraw only while something on the card is moving; a settled card costs nothing
	if _slide < 1.0 or _flash > 0.0 or _check_t > 0.0 or _reveal < _reveal_end 			or absf(_prog - float(step) / steps.size()) > 0.0008 or _dirty:
		_dirty = false
		queue_redraw()
	if _t > 0.0:
		return
	_t = 0.25
	var previous := step
	while step < steps.size() and bool(steps[step]["test"].call()):
		step += 1
	if step > previous:
		_flash = 1.0
		# hold the step just finished on screen, ticked off, before the next slides in
		_shown = previous if _check_t <= 0.0 else _shown
		_check_t = 1.0
		_reveal = 9999.0
		Sfx.play_ui(&"ui_confirm", 0.55)
		if step >= steps.size():
			_finish_pending = true
			Game.msg("[b][color=#8ad8a0]That is the loop. The sky is yours — F7 brings these prompts back if you want them.[/color][/b]", "good")

func toggle() -> void:
	muted = not muted
	if not muted:
		done = false
		step = 0
		_was_ashore = false
		_start_facing = -1
		_last = -1
		_t = 0.0
		_shown = 0
		_check_t = 0.0
		_finish_pending = false
		_slide = 0.0
		_reveal = 0.0
		_prog = 0.0
	Game.msg("Tutorial prompts %s." % ("hidden" if muted else "shown"), "info")

# ------------------------------------------------------------------ tests
func _ship() -> Airship:
	if Game.fleet == null:
		return null
	var sh: Airship = Game.fleet.ship_of(Game.player)
	return sh if sh != null else Game.fleet.player_ship

## ---- the port steps. These watch for things the player has actually opened, because a
## prompt that clears itself on a timer teaches nobody anything.
func _has_ship() -> bool:
	return Game.fleet != null and Game.fleet.player_ship != null and Game.fleet.player_ship.present

func _window_open(kind: String) -> bool:
	if Game.hud == null:
		return false
	for w in Game.hud.windows.get_children():
		if w is UIWindow and w.kind == kind and not w.is_queued_for_deletion():
			return true
	return false

var _saw_board := false
var _saw_shop := false

func _read_board() -> bool:
	if _window_open("notices"):
		_saw_board = true
	return _saw_board

func _visited_shop() -> bool:
	if _window_open("shop"):
		_saw_shop = true
	return _saw_shop

func _yard_open() -> bool:
	return Shipyard._open != null and is_instance_valid(Shipyard._open)

var _made := 0

func _crafted() -> bool:
	# any recipe finished, tracked off the stimulus the crafting code already emits
	return _made > 0

func _on_stimulus(info: Dictionary) -> void:
	if String(info.get("type", "")) in ["crafted", "harvested"] and info.get("actor") == Game.player:
		_made += 1

func _left_home() -> bool:
	if Game.player == null or Game.sky == null or Game.sky.gen == null:
		return false
	return Game.sky.gen.tier_at(Game.player.root_cell()) >= 1

func _near(proto: String, r: int) -> bool:
	var p := Game.player
	if p == null:
		return false
	for e in Game.in_radius(p.root_cell(), r):
		if e.proto == proto:
			return true
	return false

func _lit() -> bool:
	var sh := _ship()
	if sh == null:
		return false
	for b in sh.boilers:
		if is_instance_valid(b) and b.has_c(&"boiler") and b.c(&"boiler").lit:
			return true
	return false

var _start_facing := -1
var _cached_step := -1
var _body := ""
var _lines: Array = []
var _hints: Array = []
var _h := 0.0
var _reveal_end := 0.0
var _dirty := true

## Did they actually put the rudder over and come about, rather than just read about it?
func _turned() -> bool:
	var sh := _ship()
	if sh == null:
		return false
	if _start_facing < 0:
		_start_facing = sh.facing
	return sh.facing != _start_facing or sh.heading != sh.facing

func _steam() -> bool:
	var sh := _ship()
	return sh != null and sh.steam_up()

func _throttle() -> float:
	var sh := _ship()
	return sh.throttle if sh != null else 0.0

func _speed() -> float:
	var sh := _ship()
	return sh.speed() if sh != null else 0.0

func _trimmed() -> bool:
	var sh := _ship()
	if sh == null:
		return false
	return absf(sh.buoyancy() - 1.0) < 0.05 and sh.ballast != 0.0

## Stopped, with land within reach of the hull.
func _alongside() -> bool:
	var sh := _ship()
	if sh == null or sh.speed() > 0.35:
		return false
	for c in sh.cells:
		for d in Defs.DIRS4:
			var n: Vector2i = c + d
			if n in sh.cells:
				continue
			if Game.map.inb(n) and not Defs.is_void_turf(Game.map.get_turf(n)):
				return true
	return false

var _was_ashore := false

func _ashore() -> bool:
	var p := Game.player
	var sh := _ship()
	if p == null or sh == null:
		return false
	if not sh.is_aboard(p) and Falling.supported(p.cell):
		_was_ashore = true
	return _was_ashore

func _aboard_again() -> bool:
	var p := Game.player
	var sh := _ship()
	return _was_ashore and p != null and sh != null and sh.is_aboard(p)

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	if _shown >= steps.size():
		return
	var checking := _check_t > 0.0
	var s: Dictionary = steps[_shown]
	var f := UITheme.font
	if _cached_step != _shown:
		# wrapping measures every word; do it once per step, not once per frame
		_cached_step = _shown
		_body = _plain(String(s["text"]))
		_lines = _wrap(f, _body, 19, W - PAD * 2 - 8)
		_hints = _wrap(f, String(s["hint"]), 15, W - PAD * 2)
		_h = PAD * 2 + _lines.size() * 24 + _hints.size() * 20 + 30
		_reveal_end = float(_body.length()) + 40.0
	var body: String = _body
	var lines := _lines
	var hints := _hints
	var h: float = _h
	if custom_minimum_size.y != h:
		custom_minimum_size = Vector2(W, h)
	# slide down and in with an overshoot; on a completed step the panel does a small hop
	var e := 1.0 - pow(1.0 - _slide, 3.0)
	var off := Vector2(0.0, -(1.0 - e) * 34.0)
	if checking:
		off.y += -3.0 * sin(clampf((1.0 - _check_t) / 0.25, 0.0, 1.0) * PI)
	modulate.a = clampf(_slide * 2.2, 0.0, 1.0)
	draw_set_transform(off)
	var box := Rect2(Vector2.ZERO, Vector2(W, h))
	draw_style_box(UITheme.panel_style(0.92), box)
	# a soft flash when a step is completed, so progress is felt as well as read
	if _flash > 0.0:
		draw_rect(box, Color(0.55, 0.85, 0.65, _flash * 0.25))
		draw_rect(box.grow(2.0 * _flash), Color(0.5, 1.0, 0.7, _flash * 0.6), false, 2.0)
	var accent := UITheme.GOOD if checking else UITheme.ACCENT
	draw_string(f, Vector2(PAD, PAD + 15), ("STEP %d OF %d  ·  DONE" if checking else "STEP %d OF %d") % [_shown + 1, steps.size()],
		HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2, 15, accent)
	var y := PAD + 40
	var chars := int(_reveal)
	for ln in lines:
		var shown_ln: String = ln.substr(0, maxi(0, chars))
		draw_string(f, Vector2(PAD + 1, y + 1), shown_ln, HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2, 19, Color(0, 0, 0, 0.5))
		draw_string(f, Vector2(PAD, y), shown_ln, HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2, 19,
			Color(UITheme.GOOD, 0.95) if checking else Color("#f4f9fd"))
		chars -= ln.length()
		y += 24
	var hint_a := 1.0 if checking else clampf((float(_reveal) - body.length()) / 40.0, 0.0, 1.0)
	for ln in hints:
		draw_string(f, Vector2(PAD, y + 4), ln, HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2, 15, Color(UITheme.DIM, hint_a))
		y += 20
	# the progress bar fills smoothly rather than snapping, with a bright leading edge
	var bw := (W - PAD * 2) * _prog
	draw_rect(Rect2(PAD, h - 8, W - PAD * 2, 3), Color(UITheme.BORDER, 0.35))
	draw_rect(Rect2(PAD, h - 8, bw, 3), UITheme.ACCENT)
	if _flash > 0.0:
		draw_rect(Rect2(PAD + bw - 10.0, h - 9, 10, 5), Color(1, 1, 1, _flash * 0.9))
	draw_string(f, Vector2(W - 112, PAD + 15), "F7 to hide", HORIZONTAL_ALIGNMENT_RIGHT, 104, 14, UITheme.DIM)
	if checking:
		_draw_check(Vector2(W - 34.0, h * 0.5 - 4.0), clampf((1.0 - _check_t) / 0.35, 0.0, 1.0))
	draw_set_transform(Vector2.ZERO)

## A ring that closes and a tick that draws itself, popping slightly past full size.
func _draw_check(c: Vector2, p: float) -> void:
	var pop := 1.0 + 0.25 * sin(clampf(p, 0.0, 1.0) * PI)
	var r := 14.0 * pop
	draw_circle(c, r, Color(0.1, 0.25, 0.16, 0.9 * p))
	draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * minf(1.0, p * 1.6), 32, UITheme.GOOD, 2.5)
	var tp := clampf((p - 0.35) / 0.65, 0.0, 1.0)
	if tp > 0.0:
		var a := c + Vector2(-6, 0) * pop
		var m := c + Vector2(-2, 5) * pop
		var b := c + Vector2(7, -5) * pop
		var pts := PackedVector2Array([a])
		if tp < 0.4:
			pts.append(a.lerp(m, tp / 0.4))
		else:
			pts.append(m)
			pts.append(m.lerp(b, (tp - 0.4) / 0.6))
		draw_polyline(pts, Color.WHITE, 2.5)

## The prompts are written with the same bbcode as the chat log, but this panel draws raw
## strings, so the tags come back out here rather than being duplicated in two forms.
func _plain(t: String) -> String:
	for tag in ["[b]", "[/b]", "[i]", "[/i]"]:
		t = t.replace(tag, "")
	return t

func _wrap(f: Font, text: String, size: int, width: float) -> Array:
	var out := []
	var line := ""
	for word in text.split(" "):
		var test := word if line == "" else line + " " + word
		if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out
