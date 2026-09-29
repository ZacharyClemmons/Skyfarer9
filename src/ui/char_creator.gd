class_name CharCreator extends Control
## The sign-on office at Port Meridian.
##
## You stand on the quay under a hurricane lantern while a clerk's ledger fills in around
## you. Five steps, left to right along a little airship route: where you were raised
## (Origin), what you did before you had a ship (Calling), how you look (Look), your
## gifts and flaws (Habits) and your name (Papers). Your crew papers, on the left, fill in
## as you go; your character, in the middle, breathes, blinks, catches the wind and turns
## on request; and the sky behind changes to the altitude you were born at.
##
## The whole thing works with a mouse, the keyboard (Tab / arrows / Enter, Q and E for the
## previous and next step, A and D to turn, R to shuffle) and a gamepad (D-pad and A to
## choose, bumpers for steps, right stick to turn, Y to shuffle).
##
## What it changes in the game is unchanged from before: `sky_class` decides skills, kit
## and purse (SkyClasses); appearance and quirks go to the character; the three save slots
## live in user://characters.cfg. Origin, reason and the ship name you dream of are kept
## with the character and shown on the papers; they colour the story, not the numbers.

signal done(cfg: Dictionary)

const SAVE_FILE := "user://characters.cfg"
const SKIFF := 3203 # what a second-hand skiff costs at the Meridian yard (see Intro)

const BRASS := Color("#d8a848")
const BRASS_DIM := Color("#8a6a3a")
const INK := Color("#3a2a1c")
const INK_DIM := Color("#7a6448")
const PARCH := Color("#eadfbc")
const NAVY := Color(0.07, 0.10, 0.17, 0.93)

const STEPS := [
	{"id": "origin", "name": "Origin", "sub": "Where you were raised", "hint": "The altitude you grew up at is in your lungs, your accent and your papers."},
	{"id": "calling", "name": "Calling", "sub": "What you did before this", "hint": "This decides your first two hours: skills, tools and what is left in your purse."},
	{"id": "look", "name": "Look", "sub": "Face, hair and colouring", "hint": "Every style is shown on your own face. Click a swatch, or open the custom picker."},
	{"id": "habits", "name": "Habits", "sub": "Gifts and flaws", "hint": "Flaws pay for gifts. Spend no more than you have earned."},
	{"id": "papers", "name": "Papers", "sub": "Your name, and sign on", "hint": "Nearly there. The clerk needs a name, and a signature."},
]

const INTRO := [
	"PORT MERIDIAN",
	"Harbour Register  -  Sign-on Office",
	"Two thousand feet of nothing under the boards,\nand every ship in the sky ties up somewhere.",
]

const TURN_ORDER := [Defs.DIR_S, Defs.DIR_E, Defs.DIR_N, Defs.DIR_W]

var app := {}
## The trade you were in before you had a ship (SkyClasses). The engine underneath still
## wants a job id for the clothes and the paper doll, so `job` is derived from it.
var sky_class := "deckhand"
var job: String:
	get: return SkyClasses.job_of(sky_class)
var pronoun := "they"
var char_name := ""
var slot := 1
## Screenshot and regression drivers must never overwrite a player's saved characters.
var diagnostic_mode := false
var quirks: Array = []
var origin_i := 1
var home_i := 0
var reason_id := "wander"
var dream_ship := ""
var show_hat := false

var step := 0
var visited := [true, false, false, false, false]
var confirmed := false # a stamp has landed (kept for the old tests: "said I'm perfect")
var leaving := false
var intro_done := false
var intro_t := 0.0
var facing := Defs.DIR_S
var popup: Control
var _kbd := false # the last thing the player used was a key or a pad, so focus is worth showing

# scene
var stage: SkyStage
var spin_zone: Control
var rig: Node2D
var doll: PaperDoll
var content: Control
var center: Control
var fade: ColorRect
var intro_label: Label
var drone: AudioStreamPlayer
var ambient: AudioStreamPlayer
var _amb_t := 5.0

# chrome
var title_lbl: Label
var route: Route
var step_btns: Array = []
var panel_title: Label
var panel_sub: Label
var panel_hint: Label
var scroll: ScrollContainer
var body: VBoxContainer
var back_btn: Button
var next_btn: Button
var plate_name: Label
var plate_sub: Label
var card: PanelContainer
var cw := {} # papers card widgets
var stamp: Label
var _syncers: Array = []

# step widgets that need updating from outside their step
var hair_tiles: Array = []
var facial_tiles: Array = []
var swatch_rows := {}
var calling_btns := {}
var calling_detail: VBoxContainer
var calling_preview := ""
var origin_btns: Array = []
var origin_detail: Label
var reason_btns := {}
var habit_btns := {}
var habit_filter := "all"
var habit_info: Label
var habit_meter: Label
var name_edit: LineEdit
var ship_edit: LineEdit
var pron_btns := {}
var slot_btns: Array = []

# life
var _t := 0.0
var _pop := 0.0
var _blink_in := 3.0
var _blink := 0.0
var _roll := 0.0
var _roll_tick := 0.0
var _spin_drag := 0.0
var _dragging := false
var _last_purse := -1

var _sbcache := {}

# ------------------------------------------------------------------ inner widgets
## The airship route under the step buttons: dotted line, a node per step, and a little
## ship that flies to whichever one you are on.
class Route extends Control:
	var count := 5
	var pos := 0.0
	var target := 0
	var visited: Array = []
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		pos = lerpf(pos, float(target), 1.0 - exp(-delta * 6.0))
		queue_redraw()

	func _nx(i: float) -> float:
		return (i + 0.5) / float(count) * size.x

	func _draw() -> void:
		var y := size.y * 0.55
		var brass := Color("#d8a848")
		# dotted route, solid where you have already flown
		var x := _nx(0.0)
		while x < _nx(count - 1.0):
			var flown := x < _nx(pos)
			draw_rect(Rect2(x, y - 1.0, 6.0, 2.0), Color(brass, 0.95 if flown else 0.28))
			x += 12.0
		for i in count:
			var seen: bool = i < visited.size() and visited[i]
			var c := Vector2(_nx(float(i)), y)
			draw_circle(c, 6.0, Color("#101826"))
			draw_circle(c, 5.0, brass if seen else Color(brass, 0.3))
			if i == target:
				draw_arc(c, 9.0 + sin(t * 3.0), 0.0, TAU, 20, Color(brass, 0.7), 2.0)
		# the ship: a rounded envelope, a gondola and a spinning screw
		var p := Vector2(_nx(pos), y - 13.0 + sin(t * 2.2) * 1.5)
		var env := PackedVector2Array()
		for i in 17:
			var a := TAU * i / 16.0
			env.append(p + Vector2(cos(a) * 14.0, sin(a) * 6.0))
		draw_colored_polygon(env, Color("#e8dcc0"))
		draw_polyline(env, Color("#8a6a3a"), 1.5)
		draw_line(p + Vector2(-5, 5), p + Vector2(-4, 9), Color("#8a6a3a"), 1.0)
		draw_line(p + Vector2(5, 5), p + Vector2(4, 9), Color("#8a6a3a"), 1.0)
		draw_rect(Rect2(p + Vector2(-6, 9), Vector2(12, 4)), Color("#5a3d28"))
		var sp := sin(t * 30.0) * 4.0
		draw_line(p + Vector2(-16, -sp), p + Vector2(-16, sp), Color("#8a6a3a"), 1.5)

## A horizontal bar for skills and the purse. `mark` (if >= 0) is a tick, e.g. the skiff.
class Meter extends Control:
	var value := 0.0
	var shown := 0.0
	var col := Color("#6ad88a")
	var mark := -1.0
	var mark_text := ""
	var label := ""
	var big := false

	func _process(delta: float) -> void:
		if absf(shown - value) > 0.002:
			shown = lerpf(shown, value, 1.0 - exp(-delta * 9.0))
			queue_redraw()

	func _draw() -> void:
		var h := size.y
		var bar := Rect2(0, h * 0.25 if big else 0.0, size.x, h * 0.5 if big else h)
		draw_rect(bar, Color(0, 0, 0, 0.35))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(shown, 0.0, 1.0), bar.size.y)), col)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(shown, 0.0, 1.0), bar.size.y * 0.35)), Color(1, 1, 1, 0.18))
		draw_rect(bar, Color(1, 1, 1, 0.25), false, 1.0)
		if mark >= 0.0:
			var mx := size.x * clampf(mark, 0.0, 1.0)
			draw_line(Vector2(mx, 0), Vector2(mx, h), Color("#ffe6a0"), 2.0)
			if mark_text != "":
				var f := ThemeDB.fallback_font
				draw_string(f, Vector2(mx - 4.0 - f.get_string_size(mark_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, h - 1.0), mark_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffe6a0"))

# ------------------------------------------------------------------ set-up
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_load_slot(_last_slot())
	stage = SkyStage.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.set_origin(origin_i)
	add_child(stage)
	spin_zone = Control.new()
	spin_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	spin_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	spin_zone.gui_input.connect(_spin_input)
	add_child(spin_zone)
	rig = Node2D.new()
	add_child(rig)
	doll = PaperDoll.new()
	doll.position = Vector2(0, -12)
	rig.add_child(doll)
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	_build_chrome()
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	intro_label = UITheme.label("", 30, Color(0.95, 0.9, 0.78))
	intro_label.add_theme_font_override("font", UITheme.mono)
	intro_label.add_theme_font_size_override("font_size", 34)
	intro_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	intro_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	intro_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.custom_minimum_size = Vector2(1000, 0)
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(intro_label)
	drone = AudioStreamPlayer.new()
	drone.stream = Sfx.streams.get("room_drone")
	drone.volume_db = -60.0
	add_child(drone)
	drone.play()
	ambient = AudioStreamPlayer.new()
	ambient.volume_db = -14.0
	add_child(ambient)
	resized.connect(_layout)
	content.modulate.a = 0.0
	_go_step(0, false)
	_refresh()
	_layout()

func _exit_tree() -> void:
	if drone:
		drone.stop()

# ------------------------------------------------------------------ styling helpers
func _sb(bg: Color, border: Color, bw := 2, radius := 3, mx := 10, my := 6) -> StyleBoxFlat:
	var key := "%s%s%d%d%d%d" % [bg.to_html(), border.to_html(), bw, radius, mx, my]
	if _sbcache.has(key):
		return _sbcache[key]
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	_sbcache[key] = s
	return s

func _panel(parch := false) -> PanelContainer:
	var p := PanelContainer.new()
	var s: StyleBoxFlat = (_sb(PARCH, BRASS_DIM, 3, 3, 18, 16) if parch else _sb(NAVY, BRASS_DIM, 2, 4, 20, 16)).duplicate()
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 5)
	p.add_theme_stylebox_override("panel", s)
	return p

func _style_button(b: Button, accent: Color, mx := 12, my := 7) -> void:
	b.add_theme_stylebox_override("normal", _sb(Color(0.10, 0.15, 0.23, 0.95), Color(BRASS_DIM, 0.85), 2, 3, mx, my))
	b.add_theme_stylebox_override("hover", _sb(Color(0.16, 0.23, 0.34, 0.98), BRASS, 2, 3, mx, my))
	b.add_theme_stylebox_override("pressed", _sb(accent.darkened(0.45), accent.lightened(0.15), 2, 3, mx, my))
	b.add_theme_stylebox_override("hover_pressed", _sb(accent.darkened(0.30), accent.lightened(0.3), 2, 3, mx, my))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.08, 0.10, 0.14, 0.7), Color(BRASS_DIM, 0.3), 2, 3, mx, my))
	b.add_theme_stylebox_override("focus", UITheme.focus_ring(mx, my))
	b.add_theme_color_override("font_color", UITheme.TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	b.add_theme_font_size_override("font_size", 17)

func _btn(text: String, accent := BRASS, toggle := false, min_w := 0.0, min_h := 40.0) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button(b, accent)
	b.mouse_entered.connect(func():
		if not b.disabled:
			Sfx.play_ui(&"ui_hover", 0.22, 1.15))
	b.focus_entered.connect(func():
		if _kbd:
			Sfx.play_ui(&"ui_tick", 0.3, 1.0))
	return b

func _lbl(text: String, size := 17, color := UITheme.TEXT, wrap := false) -> Label:
	var l := UITheme.label(text, size, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(10, 0)
	return l

func _ink(text: String, size := 17, color := INK, mono := false) -> Label:
	var l := _lbl(text, size, color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	if mono:
		l.add_theme_font_override("font", UITheme.mono)
		l.add_theme_font_size_override("font_size", size + 4)
	return l

func _caption(text: String, color := BRASS) -> Label:
	var l := _lbl(text.to_upper(), 15, color)
	return l

func _rule(color := Color(BRASS_DIM, 0.6)) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _gap(h := 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

# ------------------------------------------------------------------ the chrome
func _build_chrome() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# margins, done by a MarginContainer so the scaled content always has an even border
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", 28)
	mc.add_theme_constant_override("margin_right", 28)
	mc.add_theme_constant_override("margin_top", 20)
	mc.add_theme_constant_override("margin_bottom", 20)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(mc)
	mc.add_child(root)

	# ---- top bar: title, then the stepper
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 26)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.custom_minimum_size = Vector2(350, 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tv)
	title_lbl = _lbl("HARBOUR REGISTER", 30, Color("#ffe6a0"))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.1, 0.05, 0, 0.9))
	title_lbl.add_theme_constant_override("shadow_offset_x", 2)
	title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	tv.add_child(title_lbl)
	tv.add_child(_lbl("Port Meridian  ·  Sign-on Office", 16, Color("#f0d8a8")))
	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_theme_constant_override("separation", 0)
	sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(sv)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 6)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.add_child(sh)
	for i in STEPS.size():
		var b := _btn("%d  %s" % [i + 1, STEPS[i]["name"]], BRASS, true, 0.0, 42.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = String(STEPS[i]["sub"])
		var idx := i
		b.pressed.connect(func(): _go_step(idx))
		sh.add_child(b)
		step_btns.append(b)
	route = Route.new()
	route.custom_minimum_size = Vector2(0, 30)
	route.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route.visited = visited
	route.count = STEPS.size()
	sv.add_child(route)

	# ---- body: papers on the left, character in the middle, this step's choices on the right
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 24)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mid)
	_build_card(mid)
	center = Control.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size = Vector2(380, 0)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(center)
	_build_center()
	var rp := _panel()
	rp.custom_minimum_size = Vector2(640, 0)
	mid.add_child(rp)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	rp.add_child(rv)
	panel_title = _lbl("", 28, Color("#ffe6a0"))
	rv.add_child(panel_title)
	panel_sub = _lbl("", 16, UITheme.DIM, true)
	rv.add_child(panel_sub)
	rv.add_child(_rule())
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	rv.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)

	# ---- bottom bar
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 16)
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bot)
	back_btn = _btn("<  Back", BRASS, false, 150, 46)
	back_btn.pressed.connect(func(): _go_step(step - 1))
	bot.add_child(back_btn)
	panel_hint = _lbl("", 16, Color("#f0d8a8"), true)
	panel_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel_hint.size_flags_vertical = Control.SIZE_FILL
	panel_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	bot.add_child(panel_hint)
	next_btn = _btn("Next  >", BRASS, false, 230, 46)
	next_btn.pressed.connect(_next)
	bot.add_child(next_btn)

func _build_center() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	v.offset_top = -170
	v.offset_bottom = 0
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(v)
	plate_name = _lbl("", 34, Color("#fff4d0"))
	plate_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate_name.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0, 0.95))
	plate_name.add_theme_constant_override("shadow_offset_x", 2)
	plate_name.add_theme_constant_override("shadow_offset_y", 2)
	plate_name.clip_text = true
	v.add_child(plate_name)
	plate_sub = _lbl("", 17, Color("#f0d8a8"))
	plate_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate_sub.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0, 0.95))
	v.add_child(plate_sub)
	v.add_child(_gap(8))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var l := _btn("<", BRASS, false, 48, 44)
	l.tooltip_text = "Turn her left  (A, or drag on your character)"
	l.pressed.connect(func(): _turn(-1))
	h.add_child(l)
	var dice := _btn("Shuffle  (R)", BRASS, false, 190, 44)
	dice.tooltip_text = "Roll a new face and a new name. Origin, calling and habits are left alone."
	dice.pressed.connect(_shuffle)
	h.add_child(dice)
	var r := _btn(">", BRASS, false, 48, 44)
	r.tooltip_text = "Turn her right  (D)"
	r.pressed.connect(func(): _turn(1))
	h.add_child(r)

func _build_card(parent: Control) -> void:
	card = _panel(true)
	card.custom_minimum_size = Vector2(360, 0)
	parent.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t1 := _ink("CREW PAPERS", 15, INK_DIM)
	t1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t1)
	cw["no"] = _ink("No. 0000", 15, INK_DIM)
	head.add_child(cw["no"])
	v.add_child(_rule(Color(INK, 0.5)))
	var id := HBoxContainer.new()
	id.add_theme_constant_override("separation", 12)
	v.add_child(id)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _sb(Color("#b8d4e8"), INK, 3, 2, 3, 3))
	frame.custom_minimum_size = Vector2(92, 92)
	id.add_child(frame)
	var hi := HeadIcon.new()
	hi.custom_minimum_size = Vector2(84, 84)
	frame.add_child(hi)
	cw["head"] = hi
	var nv := VBoxContainer.new()
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.add_theme_constant_override("separation", 0)
	id.add_child(nv)
	cw["name"] = _ink("", 22, INK, true)
	cw["name"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cw["name"].custom_minimum_size = Vector2(10, 0)
	cw["name"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.add_child(cw["name"])
	cw["rating"] = _ink("", 16, Color("#8a3a2a"))
	nv.add_child(cw["rating"])
	cw["pron"] = _ink("", 15, INK_DIM)
	nv.add_child(cw["pron"])
	v.add_child(_rule(Color(INK, 0.5)))
	for k in ["born", "why", "ship"]:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", -2)
		v.add_child(row)
		row.add_child(_ink({"born": "RAISED", "why": "REASON FOR SIGNING", "ship": "SHE WILL BE CALLED"}[k], 13, INK_DIM))
		var val := _ink("", 16, INK)
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		val.custom_minimum_size = Vector2(10, 0)
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(val)
		cw[k] = val
	v.add_child(_rule(Color(INK, 0.5)))
	v.add_child(_ink("KNOWS", 13, INK_DIM))
	cw["knows"] = _ink("", 16, Color("#2a5a34"))
	cw["knows"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cw["knows"].custom_minimum_size = Vector2(10, 0)
	cw["knows"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(cw["knows"])
	v.add_child(_ink("CARRIES", 13, INK_DIM))
	var kit := HBoxContainer.new()
	kit.add_theme_constant_override("separation", 4)
	v.add_child(kit)
	cw["kit"] = kit
	v.add_child(_ink("PURSE", 13, INK_DIM))
	cw["purse"] = _ink("", 20, Color("#7a4a08"), true)
	v.add_child(cw["purse"])
	cw["habits_h"] = _ink("HABITS", 13, INK_DIM)
	v.add_child(cw["habits_h"])
	cw["habits"] = _ink("", 15, INK)
	cw["habits"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cw["habits"].custom_minimum_size = Vector2(10, 0)
	cw["habits"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(cw["habits"])
	stamp = Label.new()
	stamp.text = "SIGNED ON"
	stamp.add_theme_font_size_override("font_size", 40)
	stamp.add_theme_font_override("font", UITheme.mono)
	stamp.add_theme_color_override("font_color", Color("#c0392b"))
	stamp.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.modulate.a = 0.0
	stamp.rotation = deg_to_rad(-13.0)
	stamp.add_theme_stylebox_override("normal", _sb(Color(0, 0, 0, 0), Color("#c0392b"), 4, 4, 12, 0))
	content.add_child(stamp)

## Put the doll where the middle column is, at a size that suits the screen.
func _layout() -> void:
	if content == null:
		return
	var k := clampf(minf(size.x / 1500.0, size.y / 850.0), 0.7, 1.5)
	content.scale = Vector2(k, k)
	content.size = size / k
	content.position = Vector2.ZERO
	_place_rig()

func _place_rig() -> void:
	if center == null or not is_instance_valid(center):
		return
	var r := center.get_global_rect()
	var gp := get_global_rect().position
	var cx := r.position.x + r.size.x * 0.5 - gp.x
	var s := float(maxi(4, int(round(size.y / 135.0))))
	stage.pad_x = cx
	stage.deck_top = size.y * 0.66
	var feet := stage.deck_top + (size.y - stage.deck_top) * 0.36
	stage.feet_y = feet
	stage.doll_scale = s
	rig.position = Vector2(cx, feet)

# ------------------------------------------------------------------ steps
func _go_step(i: int, animate := true) -> void:
	if i < 0 or i >= STEPS.size() or leaving:
		return
	_close_popup()
	var changed := i != step
	step = i
	visited[i] = true
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	_syncers.clear()
	hair_tiles.clear()
	facial_tiles.clear()
	swatch_rows.clear()
	calling_btns.clear()
	origin_btns.clear()
	reason_btns.clear()
	habit_btns.clear()
	pron_btns.clear()
	slot_btns.clear()
	name_edit = null
	ship_edit = null
	match STEPS[i]["id"]:
		"origin": _build_origin()
		"calling": _build_calling()
		"look": _build_look()
		"habits": _build_habits()
		"papers": _build_papers()
	panel_title.text = "%d.  %s" % [i + 1, String(STEPS[i]["sub"])]
	panel_sub.text = ""
	panel_sub.visible = false
	panel_hint.text = String(STEPS[i]["hint"])
	for j in step_btns.size():
		step_btns[j].set_pressed_no_signal(j == i)
	route.target = i
	back_btn.disabled = i == 0
	back_btn.modulate.a = 0.35 if i == 0 else 1.0
	if i == STEPS.size() - 1:
		next_btn.text = "Sign on  >"
		_style_button(next_btn, Color("#e8c85a"))
		next_btn.add_theme_color_override("font_color", Color("#ffe6a0"))
	else:
		next_btn.text = "Next: %s  >" % STEPS[i + 1]["name"]
		_style_button(next_btn, BRASS)
	scroll.scroll_vertical = 0
	if changed and animate:
		Sfx.play_ui(&"ui_whoosh", 0.35, 1.0 + 0.05 * i)
		body.modulate.a = 0.0
		body.position.x = 26.0
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(body, "modulate:a", 1.0, 0.22)
		tw.tween_property(body, "position:x", 0.0, 0.26)
	else:
		body.modulate.a = 1.0
	_refresh()
	if _kbd:
		_focus_first.call_deferred()

func _next() -> void:
	if step >= STEPS.size() - 1:
		_sign_on()
	else:
		_go_step(step + 1)

func _focus_first() -> void:
	for b in body.find_children("", "Button", true, false):
		if b.focus_mode == Control.FOCUS_ALL and b.is_visible_in_tree() and not b.disabled:
			b.grab_focus()
			return
	next_btn.grab_focus()

# ---- step 1: origin
func _build_origin() -> void:
	body.add_child(_lbl("Every skyfarer is from somewhere, and where says a lot about how you breathe. Pick the altitude you were raised at.", 16, UITheme.DIM, true))
	for i in SkyLore.ORIGINS.size():
		var o: Dictionary = SkyLore.ORIGINS[i]
		var b := _card_button(String(o["name"]), String(o["tag"]), [o["sky"][0], o["sky"][1], o["sky"][2]])
		var idx := i
		b.pressed.connect(func():
			origin_i = idx
			home_i = 0
			stage.set_origin(origin_i)
			stage.gust = maxf(stage.gust, 0.5)
			Sfx.play_ui(&"ui_confirm", 0.5, 0.9 + 0.06 * idx)
			_bump()
			_refresh())
		body.add_child(b)
		origin_btns.append(b)
	body.add_child(_gap(4))
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.32), Color(BRASS_DIM, 0.5), 1, 3, 14, 10))
	body.add_child(dp)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 5)
	dp.add_child(dv)
	origin_detail = _lbl("", 16, UITheme.TEXT, true)
	dv.add_child(origin_detail)
	var homerow := HBoxContainer.new()
	homerow.add_theme_constant_override("separation", 10)
	dv.add_child(homerow)
	var hb := _btn("", BRASS, false, 0, 36)
	hb.pressed.connect(func():
		home_i = (home_i + 1) % 4
		Sfx.play_ui(&"ui_tick", 0.5, 1.2)
		_refresh())
	homerow.add_child(hb)
	_syncers.append(func(): hb.text = "Home:  %s   (another?)" % String(SkyLore.origin(origin_i)["homes"][home_i]))
	body.add_child(_gap(4))
	body.add_child(_caption("What brought you up here?"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	body.add_child(flow)
	for r in SkyLore.REASONS:
		var rid: String = r["id"]
		var rb := _btn(String(r["name"]), BRASS, true, 0, 38)
		rb.pressed.connect(func():
			reason_id = rid
			Sfx.play_ui(&"ui_click", 0.5, 1.0 + 0.05 * randi_range(-2, 2))
			_refresh())
		flow.add_child(rb)
		reason_btns[rid] = rb
	var why := _lbl("", 16, Color("#f0d8a8"), true)
	body.add_child(why)
	_syncers.append(func():
		var o2 := SkyLore.origin(origin_i)
		for j in origin_btns.size():
			origin_btns[j].set_pressed_no_signal(j == origin_i)
		origin_detail.text = "%s\n\n%s   %s" % [String(o2["born"]).to_upper(), String(o2["blurb"]), String(o2["proverb"])]
		for rid2 in reason_btns:
			reason_btns[rid2].set_pressed_no_signal(rid2 == reason_id)
		why.text = String(SkyLore.reason(reason_id)["blurb"]))

## A wide choice with a title, a line under it and a little strip of the sky it stands for.
func _card_button(title: String, sub: String, strip: Array) -> Button:
	var b := _btn("", BRASS, true, 0, 58)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -10
	h.offset_top = 6
	h.offset_bottom = -6
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var sw := VBoxContainer.new()
	sw.add_theme_constant_override("separation", 0)
	sw.custom_minimum_size = Vector2(14, 0)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sw)
	for c in strip:
		var cr := ColorRect.new()
		cr.color = c
		cr.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sw.add_child(cr)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tv)
	tv.add_child(_lbl(title, 20, Color.WHITE))
	tv.add_child(_lbl(sub, 15, UITheme.DIM))
	return b

# ---- step 2: calling
func _build_calling() -> void:
	body.add_child(_lbl("Every calling can do everything, eventually. This decides your first two hours, and what you do not have to buy.", 16, UITheme.DIM, true))
	for g in SkyClasses.GROUPS:
		var col: Color = g[1]
		body.add_child(_caption(String(g[0]), col))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 6)
		body.add_child(grid)
		for k in g[2]:
			var id := String(k)
			var b := _btn(String(SkyClasses.info(id)["name"]), col, true, 0, 40)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_color_override("font_color", col.lightened(0.35))
			b.mouse_entered.connect(func(): _preview_calling(id))
			b.focus_entered.connect(func(): _preview_calling(id))
			b.mouse_exited.connect(func(): _preview_calling.call_deferred(sky_class))
			b.pressed.connect(func():
				sky_class = id
				Sfx.play_ui(&"ui_confirm", 0.55, 1.0 + 0.04 * randi_range(-3, 3))
				_bump()
				_refresh())
			grid.add_child(b)
			calling_btns[id] = b
	body.add_child(_gap(4))
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.32), Color(BRASS_DIM, 0.5), 1, 3, 14, 10))
	body.add_child(dp)
	calling_detail = VBoxContainer.new()
	calling_detail.add_theme_constant_override("separation", 5)
	dp.add_child(calling_detail)
	calling_preview = sky_class
	_syncers.append(func():
		for id2 in calling_btns:
			calling_btns[id2].set_pressed_no_signal(id2 == sky_class)
		_preview_calling(sky_class))

func _preview_calling(k: String) -> void:
	if calling_detail == null or not is_instance_valid(calling_detail) or STEPS[step]["id"] != "calling":
		return
	if k == calling_preview and calling_detail.get_child_count() > 0 and k == sky_class:
		return
	calling_preview = k
	for c in calling_detail.get_children():
		calling_detail.remove_child(c)
		c.queue_free()
	var cd := SkyClasses.info(k)
	var col := _class_color(k)
	var extra: Array = SkyLore.CALLINGS.get(k, ["", ""])
	var head := HBoxContainer.new()
	calling_detail.add_child(head)
	var nm := _lbl(String(cd["name"]), 26, col.lightened(0.3))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(_lbl(String(extra[0]) + ("   (yours)" if k == sky_class else "   (hover)"), 15, UITheme.DIM))
	calling_detail.add_child(_lbl(String(extra[1]), 15, Color("#f0d8a8"), true))
	calling_detail.add_child(_lbl(String(cd["blurb"]), 16, UITheme.TEXT, true))
	calling_detail.add_child(_lbl(String(cd["note"]), 16, UITheme.ACCENT, true))
	calling_detail.add_child(_gap(2))
	calling_detail.add_child(_caption("Knows", Color("#6ad88a")))
	var sk := SkyClasses.headline_skills(k).slice(0, 5)
	for row in sk:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		calling_detail.add_child(h)
		var l := _lbl(String(Skills.SKILLS.get(String(row[0]), {}).get("name", row[0])), 16, UITheme.TEXT)
		l.custom_minimum_size = Vector2(140, 0)
		h.add_child(l)
		var m := Meter.new()
		m.custom_minimum_size = Vector2(0, 14)
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		m.value = 0.0
		m.col = Color("#6ad88a")
		h.add_child(m)
		m.set_deferred("value", clampf(float(row[1]) / 30.0, 0.0, 1.0))
		var v := _lbl(str(int(row[1])), 16, Color("#6ad88a"))
		v.custom_minimum_size = Vector2(28, 0)
		h.add_child(v)
	calling_detail.add_child(_gap(2))
	calling_detail.add_child(_caption("Carries", Color("#e8a83a")))
	calling_detail.add_child(_kit_row(cd, 30, true))
	var purse := SkyClasses.purse(k)
	calling_detail.add_child(_caption("Purse", Color("#e8c85a")))
	var pm := Meter.new()
	pm.custom_minimum_size = Vector2(0, 30)
	pm.big = true
	pm.col = Color("#e8c85a") if purse >= SKIFF else Color("#e8a83a")
	var maxp := float(Economy.STARTING_PURSE) * 2.1
	pm.mark = float(SKIFF) / maxp
	pm.mark_text = "skiff"
	pm.set_deferred("value", float(purse) / maxp)
	calling_detail.add_child(pm)
	var pl := _lbl("%s marks" % Economy.money(purse), 18, Color("#e8c85a"))
	calling_detail.add_child(pl)
	if purse < SKIFF:
		calling_detail.add_child(_lbl("A skiff at the Meridian yard is about 3,200, so this calling will have to earn the difference.", 15, UITheme.DIM, true))
	else:
		calling_detail.add_child(_lbl("Near enough to buy a second-hand skiff on the spot, if that is what you want.", 15, UITheme.DIM, true))

## Small icons of what a calling starts with. `names` also writes the item names beside them.
func _kit_row(cd: Dictionary, isz: int, names: bool) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 4)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for it in cd.get("items", []):
		var p: Dictionary = Proto.P.get(String(it), {})
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(h)
		var tr := _item_icon(String(it), isz)
		h.add_child(tr)
		if names:
			h.add_child(_lbl(String(p.get("name", it)), 15, UITheme.TEXT))
	return flow

func _item_icon(id: String, isz: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(isz, isz)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_PASS
	var p: Dictionary = Proto.P.get(id, {})
	tr.tooltip_text = String(p.get("name", id))
	var sheet := String(p.get("sheet", "items"))
	var spr := String(p.get("spr", ""))
	if spr != "" and Gfx.has(sheet, spr):
		tr.texture = Gfx.atlas(sheet, spr)
	return tr

## Which colour a calling reads as, by what it is for.
static func _class_color(id: String) -> Color:
	for g in SkyClasses.GROUPS:
		if id in g[2]:
			return g[1]
	return UITheme.ACCENT

# ---- step 3: look
func _build_look() -> void:
	var hat := _btn("", BRASS, true, 0, 38)
	hat.tooltip_text = "Your calling's cap or mask, in the preview. In play you wear what you find."
	hat.pressed.connect(func():
		show_hat = not show_hat
		Sfx.play_ui(&"ui_click", 0.5)
		_refresh())
	body.add_child(hat)
	_syncers.append(func():
		hat.set_pressed_no_signal(show_hat)
		hat.text = "Headgear in the preview:  %s" % ("on" if show_hat else "off"))
	body.add_child(_caption("Hair"))
	var g1 := GridContainer.new()
	g1.columns = 7
	g1.add_theme_constant_override("h_separation", 6)
	g1.add_theme_constant_override("v_separation", 6)
	body.add_child(g1)
	for hs in Jobs.HAIR_STYLES:
		var t := _head_tile(String(hs), true)
		g1.add_child(t[0])
		hair_tiles.append(t)
	body.add_child(_caption("Facial hair"))
	var g2 := GridContainer.new()
	g2.columns = 7
	g2.add_theme_constant_override("h_separation", 6)
	g2.add_theme_constant_override("v_separation", 6)
	body.add_child(g2)
	for fs in Jobs.FACIAL_STYLES:
		var t2 := _head_tile(String(fs), false)
		g2.add_child(t2[0])
		facial_tiles.append(t2)
	body.add_child(_caption("Colouring"))
	_swatch_row("Skin", "skin", Jobs.SKIN_TONES)
	_swatch_row("Hair", "hair_color", Jobs.HAIR_COLORS)
	_swatch_row("Eyes", "eyes", Jobs.EYE_COLORS)
	_swatch_row("Undershirt", "underwear", ["#3a4a6a", "#2a2a30", "#e8e8e8", "#8a3a5a", "#3a6a4a", "#6a5a3a", "#c83a3a", "#3a8ad8"])

func _head_tile(style: String, is_hair: bool) -> Array:
	var b := _btn("", BRASS, true, 0, 0)
	b.custom_minimum_size = Vector2(62, 62)
	b.tooltip_text = (style.capitalize() if style != "" else "Clean shaven")
	var head := HeadIcon.new()
	head.set_anchors_preset(Control.PRESET_FULL_RECT)
	head.offset_left = 4
	head.offset_top = 4
	head.offset_right = -4
	head.offset_bottom = -4
	b.add_child(head)
	b.pressed.connect(func():
		app["hair" if is_hair else "facial"] = style
		Sfx.play_ui(&"ui_click", 0.5, 1.1)
		_bump()
		_refresh())
	return [b, head, style, is_hair]

func _sync_look() -> void:
	for t in hair_tiles:
		t[1].set_look(app, t[2], app["facial"])
		t[0].set_pressed_no_signal(app["hair"] == t[2])
	for t in facial_tiles:
		t[1].set_look(app, app["hair"], t[2])
		t[0].set_pressed_no_signal(app["facial"] == t[2])
	for key in swatch_rows:
		for sb in swatch_rows[key]:
			sb[0].set_pressed_no_signal(Color(app[key]).is_equal_approx(sb[1]))

func _swatch_row(title: String, key: String, presets: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	body.add_child(h)
	var l := _lbl(title, 16, UITheme.DIM)
	l.custom_minimum_size = Vector2(96, 0)
	h.add_child(l)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 5)
	h.add_child(flow)
	swatch_rows[key] = []
	for pc in presets:
		var col := Color(pc)
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(32, 32)
		b.tooltip_text = "%s  #%s" % [title, col.to_html(false)]
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			var sbx := StyleBoxFlat.new()
			sbx.bg_color = col
			sbx.set_corner_radius_all(3)
			sbx.border_color = Color("#101826") if st == "normal" else (BRASS if st == "hover" else Color.WHITE)
			sbx.set_border_width_all(2 if st in ["normal", "hover"] else 4)
			b.add_theme_stylebox_override(st, sbx)
		b.add_theme_stylebox_override("focus", UITheme.focus_ring(0, 0))
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func():
			app[key] = col
			Sfx.play_ui(&"ui_tick", 0.5, 1.3)
			_bump()
			_refresh())
		b.mouse_entered.connect(func(): Sfx.play_ui(&"ui_hover", 0.15, 1.3))
		flow.add_child(b)
		swatch_rows[key].append([b, col])
	var custom := _btn("...", BRASS, false, 36, 32)
	custom.tooltip_text = "Pick any %s colour" % title.to_lower()
	custom.pressed.connect(func(): _open_color(key, title, presets, custom))
	flow.add_child(custom)

func _open_color(key: String, title: String, presets: Array, at: Control) -> void:
	_close_popup()
	var cp := ColorPanel.new(title, [], Color(app[key]))
	cp.color_changed.connect(func(c):
		app[key] = c
		_refresh_look_only())
	content.add_child(cp)
	cp.reset_size()
	var gp := at.get_global_rect().position - content.get_global_rect().position
	var k := content.scale.x
	var want := gp / k + Vector2(-cp.size.x + 40.0, -cp.size.y - 10.0)
	cp.position = want.clamp(Vector2(8, 8), content.size - cp.size - Vector2(8, 8))
	popup = cp
	_pop_in(cp)

# ---- step 4: habits
func _build_habits() -> void:
	habit_meter = _lbl("", 17, UITheme.TEXT, true)
	body.add_child(habit_meter)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	body.add_child(bar)
	var fb := {}
	for f in [["all", "All"], ["gift", "Gifts"], ["odd", "Oddities"], ["flaw", "Flaws"]]:
		var b := _btn(String(f[1]), BRASS, true, 0, 36)
		var fid: String = f[0]
		b.pressed.connect(func():
			habit_filter = fid
			Sfx.play_ui(&"ui_click", 0.4)
			_rebuild_habits())
		bar.add_child(b)
		fb[fid] = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var draw := _btn("Draw a hand", BRASS, false, 0, 36)
	draw.tooltip_text = "A random, balanced set of gifts and flaws."
	draw.pressed.connect(func():
		quirks = Quirks.random_set(Game.rng)
		Sfx.play_ui(&"ui_confirm", 0.5, 1.15)
		_refresh())
	bar.add_child(draw)
	var clear := _btn("Clear", BRASS, false, 0, 36)
	clear.pressed.connect(func():
		quirks.clear()
		Sfx.play_ui(&"ui_close", 0.4)
		_refresh())
	bar.add_child(clear)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	body.add_child(list)
	list.name = "HabitList"
	habit_info = _lbl("", 16, Color("#f0d8a8"), true)
	habit_info.custom_minimum_size = Vector2(0, 62)
	var ip := PanelContainer.new()
	ip.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.32), Color(BRASS_DIM, 0.5), 1, 3, 12, 8))
	ip.add_child(habit_info)
	body.add_child(ip)
	_syncers.append(func():
		for fid2 in fb:
			fb[fid2].set_pressed_no_signal(fid2 == habit_filter)
		_sync_habits())
	_rebuild_habits()

func _rebuild_habits() -> void:
	var list := body.get_node_or_null("HabitList") as VBoxContainer
	if list == null:
		return
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	habit_btns.clear()
	for grp in [["gift", "Gifts  (cost points)", Color("#6ad88a")], ["odd", "Oddities  (free)", UITheme.ACCENT], ["flaw", "Flaws  (earn points)", Color("#ff8a6a")]]:
		if habit_filter != "all" and habit_filter != grp[0]:
			continue
		list.add_child(_caption(String(grp[1]), grp[2]))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 4)
		list.add_child(grid)
		var ids: Array = Quirks.DEFS.keys().filter(func(q):
			var v: int = Quirks.value(q)
			return (grp[0] == "gift" and v > 0) or (grp[0] == "odd" and v == 0) or (grp[0] == "flaw" and v < 0))
		ids.sort_custom(func(a, b): return String(SkyLore.habit(a)[0]) < String(SkyLore.habit(b)[0]))
		for q in ids:
			var qq: String = q
			var hb := SkyLore.habit(qq)
			var v2: int = Quirks.value(qq)
			var b := _btn("%s   %s" % [String(hb[0]), ("%+d" % v2) if v2 != 0 else ""], grp[2], true, 0, 38)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.tooltip_text = String(hb[1])
			b.mouse_entered.connect(func(): habit_info.text = "%s\n%s" % [String(hb[0]), String(hb[1])])
			b.focus_entered.connect(func(): habit_info.text = "%s\n%s" % [String(hb[0]), String(hb[1])])
			b.pressed.connect(func(): _toggle_habit(qq))
			grid.add_child(b)
			habit_btns[qq] = b
	_sync_habits()

func _toggle_habit(q: String) -> void:
	if q in quirks:
		quirks.erase(q)
		Sfx.play_ui(&"ui_close", 0.4, 1.2)
	else:
		var trial := quirks.duplicate()
		trial.append(q)
		if not q in Quirks.filter_valid(trial) or Quirks._clashes(q, quirks):
			Sfx.play_ui(&"ui_deny", 0.6)
			_habit_says("The clerk shakes her head: that one will not sit with what you already have, or you have nothing left to pay for it with.")
			_sync_habits()
			return
		quirks.append(q)
		Sfx.play_ui(&"ui_confirm", 0.45, 1.0 + 0.03 * quirks.size())
	_refresh()

func _habit_says(t: String) -> void:
	if habit_info != null and is_instance_valid(habit_info):
		habit_info.text = t

func _sync_habits() -> void:
	if habit_meter == null or not is_instance_valid(habit_meter):
		return
	var bal := Quirks.balance(quirks)
	var pos := quirks.filter(func(q): return Quirks.value(q) > 0).size()
	var pts := -bal
	habit_meter.text = "Points to spend: %d      Gifts taken: %d of %d      Habits: %d" % [pts, pos, Quirks.MAX_POSITIVE, quirks.size()]
	habit_meter.add_theme_color_override("font_color", UITheme.BAD if bal > 0 else (Color("#6ad88a") if pts > 0 else UITheme.TEXT))
	for q in habit_btns:
		habit_btns[q].set_pressed_no_signal(q in quirks)
	if habit_info != null and habit_info.text == "":
		habit_info.text = "Hover or focus a habit to read what it means aboard ship."

# ---- step 5: papers
func _build_papers() -> void:
	body.add_child(_caption("Name"))
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 8)
	body.add_child(nr)
	name_edit = LineEdit.new()
	name_edit.text = char_name
	name_edit.max_length = 32
	name_edit.placeholder_text = "Who are you, then?"
	name_edit.custom_minimum_size = Vector2(0, 46)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", 22)
	name_edit.text_changed.connect(func(t):
		char_name = t
		_update_card())
	name_edit.text_submitted.connect(func(_t): name_edit.release_focus())
	nr.add_child(name_edit)
	var nd := _btn("Draw a name", BRASS, false, 150, 46)
	nd.tooltip_text = "A name off the harbour rolls."
	nd.pressed.connect(func():
		char_name = SkyLore.random_name(Game.rng)
		name_edit.text = char_name
		Sfx.play_ui(&"ui_confirm", 0.5, 1.2)
		_bump()
		_refresh())
	nr.add_child(nd)
	body.add_child(_caption("Pronouns"))
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	body.add_child(pr)
	for p in [["she", "she / her"], ["they", "they / them"], ["he", "he / him"]]:
		var pid: String = p[0]
		var b := _btn(String(p[1]), BRASS, true, 0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			pronoun = pid
			Sfx.play_ui(&"ui_click", 0.5)
			_refresh())
		pr.add_child(b)
		pron_btns[pid] = b
	body.add_child(_caption("The ship you mean to have, one day"))
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 8)
	body.add_child(sr)
	ship_edit = LineEdit.new()
	ship_edit.text = dream_ship
	ship_edit.max_length = 32
	ship_edit.custom_minimum_size = Vector2(0, 46)
	ship_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_edit.add_theme_font_size_override("font_size", 20)
	ship_edit.text_changed.connect(func(t):
		dream_ship = t
		_update_card())
	ship_edit.text_submitted.connect(func(_t): ship_edit.release_focus())
	sr.add_child(ship_edit)
	var sd := _btn("Christen her", BRASS, false, 150, 46)
	sd.tooltip_text = "Every skyfarer has a name picked out. You will get to use it, or you will not."
	sd.pressed.connect(func():
		dream_ship = SkyLore.random_ship(Game.rng)
		ship_edit.text = dream_ship
		Sfx.play_ui(&"ui_confirm", 0.5, 0.9)
		_refresh())
	sr.add_child(sd)
	body.add_child(_caption("Register"))
	body.add_child(_lbl("Three characters are kept. Switching saves this one first.", 15, UITheme.DIM, true))
	var sl := HBoxContainer.new()
	sl.add_theme_constant_override("separation", 8)
	body.add_child(sl)
	for n in [1, 2, 3]:
		var nn: int = n
		var b := _btn("", BRASS, true, 0, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _switch_slot(nn))
		sl.add_child(b)
		slot_btns.append(b)
	body.add_child(_gap(6))
	body.add_child(_rule())
	var oath := _lbl("", 16, Color("#f0d8a8"), true)
	body.add_child(oath)
	var go := _btn("Sign on to Port Meridian", Color("#e8c85a"), false, 0, 56)
	go.add_theme_font_size_override("font_size", 22)
	go.add_theme_color_override("font_color", Color("#ffe6a0"))
	_style_button(go, Color("#e8c85a"), 12, 10)
	go.add_theme_font_size_override("font_size", 22)
	go.add_theme_color_override("font_color", Color("#ffe6a0"))
	go.pressed.connect(_sign_on)
	body.add_child(go)
	_syncers.append(func():
		for pid2 in pron_btns:
			pron_btns[pid2].set_pressed_no_signal(pid2 == pronoun)
		for i in slot_btns.size():
			var n2 := i + 1
			slot_btns[i].set_pressed_no_signal(n2 == slot)
			slot_btns[i].text = "%d.  %s" % [n2, _slot_summary(n2)]
		oath.text = "%s, %s of %s, signing for %s. Once you step off this quay, this is the face Port Meridian knows you by." % [
			_name_or_stranger(), String(SkyClasses.info(sky_class)["name"]).to_lower(), String(SkyLore.origin(origin_i)["name"]),
			String(SkyLore.reason(reason_id)["name"]).to_lower()])

func _name_or_stranger() -> String:
	return char_name.strip_edges() if char_name.strip_edges() != "" else "A stranger"

func _slot_summary(n: int) -> String:
	if n == slot:
		return _name_or_stranger() if char_name.strip_edges() != "" else "(unnamed)"
	var cf := ConfigFile.new()
	if cf.load(SAVE_FILE) != OK or not cf.has_section("slot%d" % n):
		return "empty"
	return String(cf.get_value("slot%d" % n, "name", "?"))

func _switch_slot(n: int) -> void:
	if n == slot:
		return
	_save_slot(slot)
	_load_slot(n)
	var cf := ConfigFile.new()
	cf.load(SAVE_FILE)
	cf.set_value("meta", "slot", slot)
	cf.save(SAVE_FILE)
	stage.set_origin(origin_i)
	Sfx.play_ui(&"ui_confirm", 0.5, 1.1)
	_go_step(step, false)
	_bump()

# ------------------------------------------------------------------ updating
## Something about the character changed: redress the doll, refill the papers, and let the
## current step re-read its own buttons.
func _refresh() -> void:
	_refresh_look_only()
	for f in _syncers:
		f.call()

func _refresh_look_only() -> void:
	dress(doll, app, job, show_hat)
	doll.set_facing(facing, 0)
	_apply_blink(false)
	if not hair_tiles.is_empty() and STEPS[step]["id"] == "look":
		_sync_look()
	_update_card()

func _bump() -> void:
	_pop = 1.0

func _update_card() -> void:
	if cw.is_empty():
		return
	var o := SkyLore.origin(origin_i)
	var cd := SkyClasses.info(sky_class)
	var extra: Array = SkyLore.CALLINGS.get(sky_class, ["", ""])
	var nm := char_name.strip_edges()
	var seen := visited
	plate_name.text = nm if nm != "" else "Nameless"
	plate_sub.text = "%s  ·  %s" % [String(cd["name"]), String(o["born"])]
	cw["name"].text = nm if nm != "" else "..........."
	cw["no"].text = "No. %04d" % (absi(hash(nm + str(slot))) % 10000)
	cw["rating"].text = "%s  (%s)" % [String(extra[0]), String(cd["name"])] if seen[1] else "Rating: ........"
	cw["pron"].text = {"they": "they / them", "she": "she / her", "he": "he / him"}[pronoun] if seen[4] else "........"
	cw["born"].text = "%s, %s" % [String(o["born"]), String(o["homes"][home_i])]
	cw["why"].text = String(SkyLore.reason(reason_id)["line"]) if seen[0] else "..............................."
	cw["ship"].text = dream_ship if dream_ship.strip_edges() != "" else "(not yet named)"
	var sk := []
	for row in SkyClasses.headline_skills(sky_class).slice(0, 4):
		sk.append("%s %d" % [String(Skills.SKILLS.get(String(row[0]), {}).get("name", row[0])), int(row[1])])
	cw["knows"].text = "  ·  ".join(sk) if seen[1] else "........"
	var kit: HBoxContainer = cw["kit"]
	for c in kit.get_children():
		kit.remove_child(c)
		c.queue_free()
	if seen[1]:
		for it in cd.get("items", []):
			kit.add_child(_item_icon(String(it), 34))
	var purse := SkyClasses.purse(sky_class)
	cw["purse"].text = ("%s marks" % Economy.money(purse)) if seen[1] else "........"
	if seen[1] and _last_purse != purse:
		if _last_purse >= 0:
			Sfx.play_ui(&"ui_coin", 0.35, 1.0 if purse >= _last_purse else 0.8)
		_last_purse = purse
	var hs := []
	for q in quirks:
		hs.append(String(SkyLore.habit(String(q))[0]))
	cw["habits"].text = ", ".join(hs) if not hs.is_empty() else ("None taken." if seen[3] else "........")
	cw["head"].set_look(app, app["hair"], app["facial"])

# ------------------------------------------------------------------ the character
func _turn(by: int) -> void:
	var i: int = TURN_ORDER.find(facing)
	facing = TURN_ORDER[(i + by + 4) % 4]
	doll.set_facing(facing, 0)
	Sfx.play_ui(&"ui_tick", 0.35, 1.0 + 0.1 * by)
	_bump()

func _spin_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			_dragging = ev.pressed
			_spin_drag = 0.0
			if ev.pressed:
				if not intro_done:
					_skip_intro()
				_close_popup()
	elif ev is InputEventMouseMotion and _dragging:
		_spin_drag += ev.relative.x
		if absf(_spin_drag) > 46.0:
			_turn(1 if _spin_drag > 0.0 else -1)
			_spin_drag = 0.0

func _shuffle() -> void:
	if _roll > 0.0 or leaving:
		return
	_roll = 0.9
	_roll_tick = 0.0
	stage.gust = 1.0
	Sfx.play_ui(&"ui_whoosh", 0.5, 1.1)

func _finish_roll() -> void:
	app = Jobs.random_appearance(Game.rng)
	char_name = SkyLore.random_name(Game.rng)
	if name_edit != null:
		name_edit.text = char_name
	facing = Defs.DIR_S
	Sfx.play_ui(&"ui_confirm", 0.7, 1.25)
	Sfx.play_ui(&"ui_coin", 0.3, 1.4)
	_bump()
	_refresh()

func _apply_blink(closed: bool) -> void:
	var s: Sprite2D = doll.layers.get("eyes")
	if s != null and doll.layer_src.get("eyes", "") != "":
		s.visible = not closed

func _process(delta: float) -> void:
	_t += delta
	_intro(delta)
	if _roll > 0.0:
		_roll -= delta
		_roll_tick -= delta
		if _roll_tick <= 0.0:
			_roll_tick = 0.075
			# flicker through faces, and spin her, while the dice are in the air
			var keep := app
			app = Jobs.random_appearance(Game.rng)
			facing = TURN_ORDER[(int(_t * 13.0)) % 4]
			var nm := SkyLore.random_name(Game.rng)
			plate_name.text = nm
			dress(doll, app, job, show_hat)
			doll.set_facing(facing, 0)
			cw["head"].set_look(app, app["hair"], app["facial"])
			Sfx.play_ui(&"ui_tick", 0.35, 0.9 + (0.9 - _roll) * 0.9)
			if _roll <= 0.0:
				app = keep
		if _roll <= 0.0:
			_finish_roll()
	# a little life while you stand there choosing
	_pop = move_toward(_pop, 0.0, delta * 4.5)
	var bob := roundf(0.5 + 0.5 * sin(_t * 2.1) - 0.15)
	doll.position = Vector2(0.0, -12.0 - _pop * 1.6 - bob * 0.0)
	rig.skew = sin(_t * 1.6) * 0.012 + sin(_t * 4.7) * 0.006 * (1.0 + stage.gust * 6.0)
	rig.scale = Vector2(stage.doll_scale * (1.0 - 0.07 * _pop), stage.doll_scale * (1.0 + 0.10 * _pop))
	# blink
	_blink_in -= delta
	if _blink_in <= 0.0 and _blink <= 0.0:
		_blink = 0.12
		_blink_in = randf_range(2.4, 5.5)
		_apply_blink(true)
	elif _blink > 0.0:
		_blink -= delta
		if _blink <= 0.0:
			_apply_blink(false)
	# hair and facial hair lift in a gust
	var lift := 1.0 if sin(_t * 2.3 + sin(_t * 0.7) * 2.0) > 0.86 - stage.gust * 1.2 else 0.0
	doll.set_layer_offset("hair", Vector2(lift, 0.0))
	_place_rig()
	# gamepad: right stick turns her
	var ax := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(ax) > 0.7 and not _dragging:
		_stick_hold += delta
		if _stick_hold > 0.28:
			_stick_hold = 0.0
			_turn(1 if ax > 0.0 else -1)
	else:
		_stick_hold = 0.28
	# now and then a gull or a creak
	_amb_t -= delta
	if _amb_t <= 0.0 and intro_done and not leaving:
		_amb_t = randf_range(6.0, 13.0)
		var nm2: String = ["amb_gull", "amb_creak", "amb_rope"][randi() % 3]
		var st: AudioStream = Sfx.streams.get(nm2)
		if st != null:
			ambient.stream = st
			ambient.pitch_scale = randf_range(0.85, 1.15)
			ambient.play()

var _stick_hold := 0.28

# ------------------------------------------------------------------ input
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed:
		if not intro_done:
			_skip_intro()
			get_viewport().set_input_as_handled()
			return
		_kbd = true
		match ev.physical_keycode:
			KEY_ESCAPE:
				if popup != null:
					_close_popup()
				elif step > 0:
					_go_step(step - 1)
				get_viewport().set_input_as_handled()
			KEY_Q, KEY_PAGEUP:
				_go_step(step - 1)
			KEY_E, KEY_PAGEDOWN:
				if step < STEPS.size() - 1:
					_go_step(step + 1)
			KEY_A:
				_turn(-1)
			KEY_D:
				_turn(1)
			KEY_R:
				_shuffle()
			KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_TAB:
				if get_viewport().gui_get_focus_owner() == null:
					_focus_first()
					get_viewport().set_input_as_handled()
	elif ev is InputEventJoypadButton and ev.pressed:
		if not intro_done:
			_skip_intro()
			return
		_kbd = true
		match ev.button_index:
			JOY_BUTTON_LEFT_SHOULDER: _go_step(step - 1)
			JOY_BUTTON_RIGHT_SHOULDER: _go_step(step + 1)
			JOY_BUTTON_Y: _shuffle()
			JOY_BUTTON_B:
				if popup != null:
					_close_popup()
				else:
					_go_step(step - 1)
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A:
				if get_viewport().gui_get_focus_owner() == null:
					_focus_first()
	elif ev is InputEventMouseMotion:
		_kbd = false

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if not intro_done:
			_skip_intro()
		_close_popup()

func _close_popup() -> void:
	if popup and is_instance_valid(popup):
		var p := popup
		popup = null
		p.queue_free()

## Panels drop in with a fade instead of appearing, and say so.
func _pop_in(c: Control) -> void:
	var dest := c.position
	c.modulate.a = 0.0
	c.position = dest + Vector2(0, 14)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.16)
	tw.tween_property(c, "position", dest, 0.22)
	Sfx.play_ui(&"ui_open", 0.4)

# ------------------------------------------------------------------ signing on
func _sign_on() -> void:
	if leaving:
		return
	if char_name.strip_edges() == "":
		char_name = SkyLore.random_name(Game.rng)
		if name_edit != null:
			name_edit.text = char_name
		_refresh()
	confirmed = true
	leaving = true
	_close_popup()
	_save_slot(slot)
	# the stamp comes down on the papers with a thump and the whole desk shakes
	stamp.reset_size()
	var cr := card.get_global_rect()
	var k := content.scale.x
	stamp.position = (cr.position + Vector2(cr.size.x * 0.5, cr.size.y * 0.78)) / k - stamp.size * 0.5
	stamp.pivot_offset = stamp.size * 0.5
	stamp.modulate.a = 1.0
	stamp.scale = Vector2(3.2, 3.2)
	Sfx.play_ui(&"ui_stinger", 0.6)
	var tw := create_tween()
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Sfx.play_ui(&"ui_place", 1.0, 0.7)
		stage.gust = 1.0
		_shake())
	tw.tween_interval(0.9)
	tw.tween_callback(_leave)

func _shake() -> void:
	var tw := create_tween()
	for i in 6:
		tw.tween_property(content, "position", Vector2(randf_range(-7, 7), randf_range(-5, 5)) * (1.0 - i / 6.0), 0.03)
	tw.tween_property(content, "position", Vector2.ZERO, 0.03)

func _leave() -> void:
	leaving = true
	_save_slot(slot)
	Sfx.play_ui(&"ui_launch", 0.9)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fade, "color:a", 1.0, 1.1)
	tw.tween_property(drone, "volume_db", -60.0, 1.1)
	tw.set_parallel(false)
	tw.tween_callback(_finish)

func _finish() -> void:
	var nm := char_name.strip_edges()
	if nm == "":
		nm = SkyLore.random_name(Game.rng)
	# a positive balance isn't allowed; drop positives until it fits
	quirks = Quirks.filter_valid(quirks)
	done.emit({"name": nm, "appearance": app, "job": job, "sky_class": sky_class,
		"pronoun": pronoun, "slot": 0 if diagnostic_mode else slot,
		"saved": {} if diagnostic_mode else saved_progress(slot), "quirks": quirks,
		"origin": String(SkyLore.origin(origin_i)["id"]), "home": String(SkyLore.origin(origin_i)["homes"][home_i]),
		"reason": reason_id, "dream_ship": dream_ship})
	queue_free()

# ------------------------------------------------------------------ intro
func _intro(delta: float) -> void:
	if intro_done:
		return
	intro_t += delta
	var total := 0.0
	var shown := ""
	for line in INTRO:
		var dur: float = String(line).length() * 0.03 + 0.9
		if intro_t < total + dur:
			var n := int((intro_t - total) / 0.03)
			shown += String(line).substr(0, n)
			intro_label.text = shown
			if n < String(line).length() and n > 0 and int((intro_t - total - delta) / 0.03) != n and n % 2 == 0:
				Sfx.play_ui(&"ui_tick", 0.12, 0.7)
			return
		total += dur
		shown += String(line) + "\n\n"
	_skip_intro()

func _skip_intro() -> void:
	if intro_done:
		return
	intro_done = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(intro_label, "modulate:a", 0.0, 0.5)
	tw.tween_property(fade, "color:a", 0.0, 1.2)
	tw.tween_property(content, "modulate:a", 1.0, 1.0).set_delay(0.3)
	tw.tween_property(drone, "volume_db", -13.0, 2.5)
	Sfx.play_ui(&"ui_confirm", 0.5, 1.1)
	Sfx.play_ui(&"ui_whoosh", 0.4, 0.8)

# ------------------------------------------------------------------ save slots
func _last_slot() -> int:
	var cf := ConfigFile.new()
	if cf.load(SAVE_FILE) != OK:
		return 1
	return int(cf.get_value("meta", "slot", 1))

func _load_slot(n: int) -> void:
	slot = n
	quirks = []
	var cf := ConfigFile.new()
	var sec := "slot%d" % n
	origin_i = 1
	home_i = 0
	reason_id = "wander"
	dream_ship = ""
	pronoun = "they"
	sky_class = "deckhand"
	if cf.load(SAVE_FILE) != OK or not cf.has_section(sec):
		app = Jobs.random_appearance(Game.rng)
		char_name = SkyLore.random_name(Game.rng)
		dream_ship = SkyLore.random_ship(Game.rng)
		origin_i = 1
		return
	char_name = cf.get_value(sec, "name", SkyLore.random_name(Game.rng))
	pronoun = cf.get_value(sec, "pronoun", "they")
	sky_class = cf.get_value(sec, "class", "deckhand")
	if not SkyClasses.CLASSES.has(sky_class):
		sky_class = "deckhand"
	app = Jobs.random_appearance(Game.rng)
	for k in ["skin", "hair_color", "eyes", "underwear"]:
		app[k] = Color(cf.get_value(sec, k, app[k].to_html()))
	var hs: String = cf.get_value(sec, "hair", app["hair"])
	app["hair"] = hs if hs in Jobs.HAIR_STYLES else app["hair"]
	var fs: String = cf.get_value(sec, "facial", "")
	app["facial"] = fs if fs in Jobs.FACIAL_STYLES else ""
	quirks = Quirks.filter_valid(Array(cf.get_value(sec, "quirks", PackedStringArray())))
	var oid: String = cf.get_value(sec, "origin", "shelf")
	for i in SkyLore.ORIGINS.size():
		if SkyLore.ORIGINS[i]["id"] == oid:
			origin_i = i
	home_i = clampi(int(cf.get_value(sec, "home_i", 0)), 0, 3)
	reason_id = String(cf.get_value(sec, "reason", "wander"))
	if SkyLore.reason(reason_id)["id"] != reason_id:
		reason_id = "wander"
	dream_ship = String(cf.get_value(sec, "dream_ship", ""))

func _save_slot(n: int) -> void:
	if diagnostic_mode:
		return
	var cf := ConfigFile.new()
	cf.load(SAVE_FILE)
	var sec := "slot%d" % n
	cf.set_value(sec, "name", char_name)
	cf.set_value(sec, "pronoun", pronoun)
	cf.set_value(sec, "class", sky_class)
	for k in ["skin", "hair_color", "eyes", "underwear"]:
		cf.set_value(sec, k, Color(app[k]).to_html())
	cf.set_value(sec, "hair", app["hair"])
	cf.set_value(sec, "facial", app["facial"])
	cf.set_value(sec, "quirks", PackedStringArray(quirks))
	cf.set_value(sec, "origin", String(SkyLore.origin(origin_i)["id"]))
	cf.set_value(sec, "home_i", home_i)
	cf.set_value(sec, "reason", reason_id)
	cf.set_value(sec, "dream_ship", dream_ship)
	cf.set_value("meta", "slot", n)
	cf.save(SAVE_FILE)

## The skill and attribute XP kept in a slot (written by save_progress during the shift).
static func saved_progress(n: int) -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(SAVE_FILE) != OK:
		return {}
	var sec := "slot%d" % n
	return {"skills": cf.get_value(sec, "skills", {}), "attrs": cf.get_value(sec, "attrs", {})}

static func save_progress(n: int, m: CMob) -> void:
	if n <= 0 or m == null:
		return
	var cf := ConfigFile.new()
	cf.load(SAVE_FILE)
	var sec := "slot%d" % n
	cf.set_value(sec, "skills", m.xp.duplicate())
	cf.set_value(sec, "attrs", m.attr_xp.duplicate())
	cf.save(SAVE_FILE)

# ------------------------------------------------------------------ dressing the doll
## Puts appearance `a` and job `jb`'s outfit on a paper doll. In the sign-on office hats and
## masks are left off by default so you can see your face and hair.
static func dress(d: PaperDoll, a: Dictionary, jb: String, head_gear := true) -> void:
	var o: Dictionary = Jobs.JOBS[jb]["outfit"]
	d.set_layer("body", "body", [a["skin"], a["underwear"]])
	d.set_layer("eyes", "eyes", [a["eyes"], null, null, Color(a["hair_color"]).darkened(0.3)])
	d.set_layer("facial", ("facial_" + a["facial"]) if a["facial"] != "" else "", [a["hair_color"]])
	var hide_hair := false
	var cols := func(arr: Array) -> Array:
		var out := []
		for c in arr:
			out.append(Color(c))
		return out
	d.set_layer("uniform", "uniform_" + o["uniform"][0] if o.has("uniform") else "", cols.call(o.get("uniform", [""]).slice(1)))
	d.set_layer("shoes", "shoes" if o.has("shoes") else "", [Color(o.get("shoes", "#000000"))])
	d.set_layer("gloves", "gloves" if o.has("gloves") else "", [Color(o.get("gloves", "#000000"))])
	d.set_layer("suit", "suit_" + o["suit"][0] if o.has("suit") else "", cols.call(o.get("suit", [""]).slice(1)))
	d.set_layer("belt", "toolbelt" if o.has("belt") else "", [Color("#7a5a3a"), null, null, Color("#b0b8c4")])
	d.set_layer("back", "backpack" if o.has("back") else "", [Color(o.get("back", "#000000")), Color(o.get("back", "#000000")).darkened(0.35)])
	d.set_layer("mask", "mask_" + o["mask"][0] if o.has("mask") and head_gear else "", cols.call(o.get("mask", [""]).slice(1)))
	if o.has("head") and head_gear:
		d.set_layer("head", "head_" + o["head"][0], cols.call(o["head"].slice(1)))
		hide_hair = o["head"][0] in ["hood", "helmet"]
	else:
		d.set_layer("head", "", [])
	d.set_layer("hair", ("hair_" + a["hair"]) if a["hair"] != "bald" and not hide_hair else "", [a["hair_color"]])
