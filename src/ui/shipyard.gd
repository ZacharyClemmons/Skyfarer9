class_name Shipyard extends PanelContainer
## The yard: a drawing board for hulls, with the numbers live beside it.
##
## The whole point of this screen is that a ship is a *layout*, not a stat block, and the
## interesting decisions are spatial. Where does the engine room end? Is the bunker next
## to the boiler, and how do you feel about that? Can you get from the wheel to the rail
## without going outside at altitude? None of that fits in a list of sliders, so this is a
## grid you draw on and a panel that tells you, immediately, what you just did to her.
##
## Two modes, one screen:
##   design  you are buying. Nothing is real until you press Build, and the price goes up
##           as you draw. This is where a new skyfarer spends their whole purse.
##   refit   you already own her. Every change is charged and applied to the live hull the
##           moment you commit it, and the ship out of the window changes.
##
## Controls are deliberately over-served, because a builder you have to learn is a
## builder nobody uses:
##   left drag      paint the selected brush (a stroke fills the gaps, the sound climbs)
##   right drag     erase
##   middle drag    pan            wheel   zoom (eased)      arrows  pan
##   shift + drag   rectangle fill
##   1-9, 0         pick a brush / erase       [ ]  previous / next brush     Tab  next tab
##   M              mirror across the keel (on by default: ships are symmetrical)
##   Ctrl+Z / Ctrl+Y  undo / redo
##   F              wrap the current deck in hull planking
##   L              show what is leaking
##   C              fit the hull to the board
##   Esc            close
##
## The board is *drawn* with the same sprites the flying hull uses (see shipyard_fx.gd),
## and every edit has a little consequence: the piece pops in, dust and sparkles fly, the
## numbers slide to their new values and say by how much they moved. Building should feel
## like building.

const YardArt := preload("res://src/ui/shipyard_fx.gd")
const Art := preload("res://src/ui/shipyard_art.gd")
const CELL := 32.0
const PALETTE_W := 316.0
const STATS_W := 344.0
const NONE := Vector2i(99999, 99999)
const POP_T := 0.30
const DIE_T := 0.20

## The brushes, grouped the way a person actually builds: floor first, then the walls
## round it, then the holes the machinery drops into, then the small fittings. `grp` is
## only a heading; the order within a group is the order you would reach for them.
const BRUSHES := [
	{"grp": "Decking", "g": ",", "name": "Weather deck", "col": "#8a7a5a", "hint": "Planking, open to the sky. The cheap way to make a ship bigger."},
	{"g": "=", "name": "Cabin deck", "col": "#a89878", "hint": "Sealed flooring. Enclose it and it holds air."},
	{"grp": "Structure", "g": "#", "name": "Bulwark", "col": "#6a5a44", "hint": "The ship's side. Stops you walking off; you can see over it."},
	{"g": "K", "name": "Keel timber", "col": "#4a3e30", "hint": "Heavy, strong, and it is what a hull is hung on."},
	{"g": "I", "name": "Bulkhead", "col": "#5a5a64", "hint": "Full-height interior wall. Blocks sight, and seals a cabin."},
	{"g": "W", "name": "Window", "col": "#6aa8c8", "hint": "Glass in the hull. Seals like a bulkhead and you can see out."},
	{"g": "+", "name": "Cabin door", "col": "#8a7a4a", "hint": "A way between two sealed spaces that keeps them sealed."},
	{"g": "A", "name": "Hull hatch", "col": "#c88a3a", "hint": "An airlock through the hull, for going on deck at altitude."},
	{"grp": "Mountings", "g": "E", "name": "Thruster mount", "col": "#c85a3a", "hint": "A hole for an engine. Exhausts into whatever room it is in."},
	{"g": "p", "name": "Airscrew mount", "col": "#9a6a4a", "hint": "For an airscrew: small push, real turning authority."},
	{"g": "m", "name": "Mast step", "col": "#7a8a5a", "hint": "For a mast. Free speed when the wind agrees."},
	{"g": "L", "name": "Lift cell bay", "col": "#5a8ac8", "hint": "A cell bay. This is what holds her up."},
	{"g": "B", "name": "Boiler seat", "col": "#c8783a", "hint": "For a boiler. No steam, no thrust."},
	{"g": "G", "name": "Dynamo bed", "col": "#c8a83a", "hint": "For a generator. Volts for everything that is not the engine."},
	{"g": "T", "name": "Bunker", "col": "#8a6a3a", "hint": "For fuel. Range is tankage over burn rate."},
	{"g": "O", "name": "Ballast tank", "col": "#4a6a8a", "hint": "Pumped to sink, blown to rise. Costs no fuel."},
	{"g": "S", "name": "Breaker panel", "col": "#c8c83a", "hint": "Splits the dynamo's output between lights, machines and air."},
	{"g": "h", "name": "Helm", "col": "#e8c85a", "hint": "The wheel. She needs exactly one."},
	{"g": "n", "name": "Chart table", "col": "#a8c85a", "hint": "For navigation instruments."},
	{"g": "g", "name": "Gun mount", "col": "#c84a4a", "hint": "A gun on a swivel, bearing outboard off its own beam."},
	{"g": "C", "name": "Utility mount", "col": "#5ac8a8", "hint": "Winch, bench, still, forge, sick berth, scrubber, bunk."},
	{"grp": "Fittings", "g": "v", "name": "Air vent", "col": "#7fd4ff", "hint": "Feeds the sealed spaces from the air plant."},
	{"g": "s", "name": "Scrubber", "col": "#5a9a8a", "hint": "Takes the exhaust back out of the air you breathe."},
	{"g": "*", "name": "Deck lantern", "col": "#ffd8a0", "hint": "Light. Worth far more than it costs."},
	{"g": "b", "name": "Bunk", "col": "#8a6a8a", "hint": "A berth. A crew that cannot sleep will say so."},
	{"g": "k", "name": "Cargo racking", "col": "#7a6a4a", "hint": "Hold. Hold is money."},
	{"grp": "Tools", "g": "", "name": "Erase", "col": "#3a3440", "hint": "Take a piece back off. Right-click does this too."},
]

static var _open: Shipyard = null

var user: Entity
var yard: CShipyard
var mode := "design"        # design | refit
var ship: Airship = null    # in refit mode

var cells := {}             # Vector2i(u, v) -> glyph
var fittings := {}          # Vector2i(u, v) -> module id
var lower_plan := {}        # local cell -> "=" deck or "#" bulkhead
var lower_entry_local := Vector2i(-9999, -9999)
var lower_brush := "="
var brush := 0
var module_brush := ""      # when set, painting drops a module into a matching hole
var mirror := true
var show_leaks := false
var pan := Vector2.ZERO
var zoom := 1.0
var pan_t := Vector2.ZERO   # where pan and zoom are heading (they ease there)
var zoom_t := 1.0

var _undo: Array = []
var _redo: Array = []
var _painting := 0          # 0 none, 1 paint, 2 erase
var _panning := false
var _drag_start := NONE
var _hover := NONE
var _last_paint := NONE
var _message := ""
## What the cursor is over, shown in the panel on the right. A builder where you cannot
## ask "what is this tile" is a builder you have to memorise.
var inspect := NONE
var inspect_box: RichTextLabel
var _message_t := 0.0
var _time := 0.0
var _ui_ready := false

var canvas: Control
var palette_box: VBoxContainer
var stats_box: VBoxContainer
var footer: HBoxContainer
var title_label: Label
var tab_bar: HBoxContainer
var palette_tab := "structure"
var scroll_pal: ScrollContainer
var purse_label: Label
var commit_btn: Button
var mirror_btn: Button
var leaks_btn: Button
var undo_btn: Button
var redo_btn: Button
var name_edit: LineEdit
var reason_label: Label
var issues_box: VBoxContainer
var cost_label: Label
var purse2_label: Label
var left_label: Label
var insp_icon: YardArt.Icon

var _rows := {}                       # stat id -> YardArt.StatRow
var _brush_tiles: Array = []
var _mod_tiles := {}
var _issue_sig := "\u0001"  # sentinel so an empty verdict list still builds "Nothing wrong with her."
var _last_m := {}
var _can_commit := false
var _block_msg := ""

# ---- animation state
var _pop := {}                        # cell -> seconds since placed (negative = not yet)
var _flash := {}                      # cell -> flash age
var _deny := {}                       # cell -> seconds since refused
var _dying: Array = []                # [cell, glyph, module, age]
var _parts: Array = []                # particles, in cell units
var _trail: Array = []                # [cell, age, colour]
var _stroke_n := 0
var _last_snd := 0
var _denied_stroke := false
var _bill_target := 0.0
var _bill_shown := 0.0
var _purse_shown := -1.0
var _tick_t := 0.0
var _geom_dirty := true
var _sealed := {}
var _leaks := {}
var _draught := {}
var _closing := false
var _btn_shake := 0.0
var _want_fit := false
var _last_reason := ""
var _hl_cells: Array = []

# ---- the launch
var _seq := false
var _seq_t := 0.0
var _seq_stage := 0
var _seq_price := 0
var _seq_name := ""
var _paid := false
var _stamp_layer: Control
var _shake := 0.0
var _stamp_parts: Array = []

# ---- screenshot demo (--yarddemo[=stamp]); drives the board so a still shows the effects
var _demo := ""
var _demo_t := 0.0
var _demo_n := 0

# ------------------------------------------------------------------ opening
static func open(who: Entity, y: CShipyard, refit_ship: Airship = null) -> void:
	if _open != null and is_instance_valid(_open):
		_open.queue_free()
		_open = null
		return
	var s := Shipyard.new()
	s.user = who
	s.yard = y
	if refit_ship != null:
		s.mode = "refit"
		s.ship = refit_ship
	Game.hud.root.add_child(s)
	_open = s

static func open_refit(who: Entity, sh: Airship) -> void:
	open(who, null, sh)

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 36
	offset_top = 24
	offset_right = -36
	offset_bottom = -24
	add_theme_stylebox_override("panel", UITheme.panel_style(0.985))
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	Game.paused = true
	if mode == "refit" and ship != null:
		cells = ship.cells_map.duplicate(true)
		fittings = ship.fittings.duplicate(true)
		lower_plan = ship.lower_plan.duplicate(true)
		lower_entry_local = ship.lower_entry_local
	else:
		_start_from("skiff")
	_build_ui()
	_ui_ready = true
	_refresh_palette()
	_refresh_stats()
	_update_inspector()
	# The canvas has no size until the containers have laid out, and a deferred call still
	# catches it at zero. Fit on the first frame where it is real instead.
	_want_fit = true
	for k in cells:
		_pop[k] = -0.35 - randf() * 0.2 - float(absi(k.x) + absi(k.y)) * 0.012
	# open like a drawer sliding out, not a window blinking on
	modulate.a = 0.0
	resized.connect(func(): pivot_offset = size * 0.5)
	pivot_offset = size * 0.5
	scale = Vector2(0.95, 0.95)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.28)
	tw.tween_property(self, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
	Sfx.play_ui(&"ui_open")
	var args := OS.get_cmdline_user_args()
	for a in args:
		if String(a).begins_with("--yarddemo"):
			_demo = String(a).get_slice("=", 1) if "=" in String(a) else "paint"
			if _demo == "":
				_demo = "paint"

func _exit_tree() -> void:
	Game.paused = false
	if _open == self:
		_open = null

## Close with the same little exit the open had.
func _close() -> void:
	if _closing or _seq:
		return
	_closing = true
	Sfx.play_ui(&"ui_close")
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(0.96, 0.96), 0.14)
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	tw.chain().tween_callback(queue_free)

# ------------------------------------------------------------------ layout
func _btn(text: String, cb: Callable, tip := "", size := 15) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func():
		Sfx.play_ui(&"ui_click", 0.8)
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play_ui(&"ui_hover", 0.45))
	return b

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# ---- header: title, ship name, purse, close
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	title_label = UITheme.label(_title(), UITheme.DISPLAY, UITheme.ACCENT)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	head.add_child(title_label)
	var nm_cap := UITheme.label("Ship's name", UITheme.SMALL, UITheme.DIM)
	head.add_child(nm_cap)
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(220, 34)
	name_edit.max_length = 24
	name_edit.add_theme_font_size_override("font_size", 17)
	name_edit.placeholder_text = "Name her"
	name_edit.text = ship.ship_name if (mode == "refit" and ship != null) else _pick_name()
	name_edit.tooltip_text = "What will be painted on her bow."
	name_edit.text_submitted.connect(func(_t): name_edit.release_focus())
	name_edit.text_changed.connect(func(_t): Sfx.play_ui(&"ui_tick", 0.35, randf_range(0.9, 1.2)))
	head.add_child(name_edit)
	var dice := _btn("Roll", func():
		name_edit.text = _pick_name()
		Sfx.play_ui(&"ui_tick", 0.8, 1.3), "Pick another name.", 14)
	dice.custom_minimum_size = Vector2(52, 34)
	head.add_child(dice)
	purse_label = UITheme.label("", UITheme.TITLE, Color("#e8c85a"))
	purse_label.tooltip_text = "What you have in your pocket."
	purse_label.mouse_filter = Control.MOUSE_FILTER_STOP
	head.add_child(purse_label)
	var close := UITheme.icon_button("close", "Close (Esc)", 34)
	close.pressed.connect(_close)
	head.add_child(close)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 10)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)

	# ---- palette
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(PALETTE_W, 0)
	left.add_theme_constant_override("separation", 5)
	mid.add_child(left)
	tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 3)
	left.add_child(tab_bar)
	for pair in [["structure", "Structure"], ["lower", "Lower deck"], ["modules", "Machinery"], ["book", "The book"]]:
		var b := Button.new()
		b.text = pair[1]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = pair[0]
		b.pressed.connect(func():
			Sfx.play_ui(&"ui_click", 0.8)
			_set_tab(id))
		tab_bar.add_child(b)
	scroll_pal = ScrollContainer.new()
	scroll_pal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_pal.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll_pal)
	palette_box = VBoxContainer.new()
	palette_box.add_theme_constant_override("separation", 4)
	palette_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_pal.add_child(palette_box)

	# ---- the board
	var board := PanelContainer.new()
	board.add_theme_stylebox_override("panel", UITheme.frame("well", 4, 4))
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(board)
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.clip_contents = true
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.custom_minimum_size = Vector2(360, 300)
	canvas.draw.connect(_draw_board)
	canvas.gui_input.connect(_board_input)
	canvas.mouse_exited.connect(func():
		_hover = NONE
		_update_inspector())
	board.add_child(canvas)

	# ---- numbers, with the inspector pinned under them
	var right_col := VBoxContainer.new()
	right_col.custom_minimum_size = Vector2(STATS_W, 0)
	right_col.add_theme_constant_override("separation", 6)
	mid.add_child(right_col)
	var right := ScrollContainer.new()
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(right)
	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 3)
	stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(stats_box)
	_build_stats()

	# the inspector: what the cursor is over, always visible, never scrolled away
	var insp := PanelContainer.new()
	insp.add_theme_stylebox_override("panel", UITheme.frame("well", 8, 6))
	insp.custom_minimum_size = Vector2(STATS_W, 118)
	right_col.add_child(insp)
	var ih := HBoxContainer.new()
	ih.add_theme_constant_override("separation", 8)
	insp.add_child(ih)
	insp_icon = YardArt.Icon.new()
	insp_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ih.add_child(insp_icon)
	inspect_box = RichTextLabel.new()
	inspect_box.bbcode_enabled = true
	inspect_box.fit_content = false
	inspect_box.scroll_active = false
	inspect_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspect_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspect_box.add_theme_font_size_override("normal_font_size", 15)
	inspect_box.add_theme_font_size_override("bold_font_size", 16)
	ih.add_child(inspect_box)

	# ---- the buttons that commit
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	root.add_child(footer)
	mirror_btn = _footer_btn("Mirror: on [M]", func(): _toggle_mirror(), "Ships are symmetrical. Draw one side and get the other. (M) Hold Alt while placing to put down just one.")
	mirror_btn.toggle_mode = true
	mirror_btn.button_pressed = true
	_footer_btn("Wrap hull [F]", func(): _wrap_hull(), "Put bulwark all the way round the deck you have drawn. (F)")
	leaks_btn = _footer_btn("Leaks & draughts [L]", func(): _toggle_leaks(), "Highlight every cabin tile that is open to the weather (red) and the draught the wind will carry in behind it (blue). (L)")
	leaks_btn.toggle_mode = true
	undo_btn = _footer_btn("Undo", func(): _do_undo(), "Ctrl+Z")
	redo_btn = _footer_btn("Redo", func(): _do_redo(), "Ctrl+Y")
	_footer_btn("Fit [C]", func(): _center_view(true), "Fit the whole hull on the board. (C)")
	_footer_btn("Clear", func(): _clear_all(), "Start from nothing. There is no confirmation and there is undo.")
	reason_label = UITheme.label("", UITheme.SMALL, UITheme.DIM)
	reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reason_label.clip_text = true
	reason_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(reason_label)
	commit_btn = Button.new()
	commit_btn.focus_mode = Control.FOCUS_NONE
	commit_btn.custom_minimum_size = Vector2(320, 46)
	commit_btn.add_theme_font_size_override("font_size", UITheme.TITLE)
	commit_btn.pressed.connect(func(): _commit())
	commit_btn.resized.connect(func(): commit_btn.pivot_offset = commit_btn.size * 0.5)
	footer.add_child(commit_btn)

func _footer_btn(text: String, cb: Callable, tip := "") -> Button:
	var b := _btn(text, cb, tip, 15)
	footer.add_child(b)
	return b

func _title() -> String:
	if mode == "refit" and ship != null:
		return "The yard — refitting %s" % ship.ship_name
	return "The yard — drawing board"

static var _name_rng := RandomNumberGenerator.new()

func _pick_name() -> String:
	_name_rng.randomize()
	return NAMES_A[_name_rng.randi() % NAMES_A.size()]

# ------------------------------------------------------------------ the stats panel
## [id, title, fmt, decimals, higher-is-better, bar floor, tooltip, neutral delta]
const STAT_DEFS := [
	["mass", "Displacement", "%.0f t", 0, false, 160.0, "What she weighs empty, fittings included.", true],
	["buoy", "Lift", "%.0f%% of weight", 0, true, 200.0, "Above 100 she climbs, below she sinks. Ballast trims 40% either way, so anything between about 70 and 140 is flyable.", true],
	["top", "Top speed", "%.1f kt", 1, true, 6.0, "Where thrust and drag balance.", false],
	["thrust", "Thrust", "%.0f", 0, true, 80.0, "Total engine force at full throttle.", false],
	["sail", "Canvas", "%.0f sq ft", 0, true, 80.0, "Free speed when the wind agrees.", false],
	["turn", "Rudder", "%.2f rad/s", 2, true, 2.0, "How fast she comes about. Small hulls turn; barques do not.", false],
	["range", "Range", "%.0f min", 0, true, 30.0, "Full throttle, until the bunkers are dry.", false],
	["cargo", "Hold", "%.0f t", 0, true, 30.0, "Cargo is how a trade route pays.", false],
	["crew", "Berths", "%.0f", 0, true, 8.0, "How many she is meant for.", false],
	["armor", "Plating", "%.0f", 0, true, 60.0, "Damage the hull soaks per hit.", false],
]

func _build_stats() -> void:
	_stat_head("Her numbers")
	for d in STAT_DEFS:
		var r := YardArt.StatRow.new()
		r.title = String(d[1])
		r.fmt = String(d[2])
		r.dec = int(d[3])
		r.high_good = bool(d[4])
		r.vbase = float(d[5])
		r.vmax = r.vbase
		r.tooltip_text = String(d[6])
		r.neutral_delta = bool(d[7])
		stats_box.add_child(r)
		_rows[String(d[0])] = r
	_stat_head("Will she work")
	issues_box = VBoxContainer.new()
	issues_box.add_theme_constant_override("separation", 2)
	stats_box.add_child(issues_box)
	_stat_head("The bill")
	var bill := PanelContainer.new()
	bill.add_theme_stylebox_override("panel", UITheme.frame("well", 10, 6))
	stats_box.add_child(bill)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	bill.add_child(bv)
	cost_label = _bill_row(bv, "Cost", UITheme.DISPLAY, UITheme.TEXT)
	purse2_label = _bill_row(bv, "Your purse", UITheme.BODY, UITheme.DIM)
	left_label = _bill_row(bv, "Left after", UITheme.BODY, UITheme.GOOD)

func _bill_row(parent: Control, cap: String, size: int, col: Color) -> Label:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var c := UITheme.label(cap, UITheme.SMALL, UITheme.DIM)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(c)
	var v := UITheme.label("", size, col)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	return v

func _stat_head(text: String) -> void:
	var l := UITheme.caption(text, UITheme.ACCENT)
	l.add_theme_constant_override("line_spacing", 0)
	var box := MarginContainer.new()
	box.add_theme_constant_override("margin_top", 6)
	box.add_child(l)
	stats_box.add_child(box)

func _stat_note(text: String, tone: String, hl: Array = []) -> void:
	var col := UITheme.DIM
	match tone:
		"good": col = UITheme.GOOD
		"warn": col = UITheme.WARN
		"bad": col = UITheme.BAD
		"info": col = UITheme.ACCENT
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size = Vector2(STATS_W - 40.0, 0)
	r.add_theme_font_size_override("normal_font_size", 15)
	r.add_theme_color_override("default_color", col)
	r.text = ("• " if tone != "info" else "· ") + text
	r.modulate.a = 0.0
	if not hl.is_empty():
		r.mouse_filter = Control.MOUSE_FILTER_STOP
		r.mouse_entered.connect(func(): _hl_cells = hl)
		r.mouse_exited.connect(func(): _hl_cells = [])
		r.tooltip_text = "Hover to see where on the board."
	issues_box.add_child(r)
	create_tween().tween_property(r, "modulate:a", 1.0, 0.25)

# ------------------------------------------------------------------ palette
func _set_tab(id: String) -> void:
	palette_tab = id
	_refresh_palette()

func _refresh_palette() -> void:
	for c in palette_box.get_children():
		c.queue_free()
	_brush_tiles.clear()
	_mod_tiles.clear()
	for i in tab_bar.get_child_count():
		var b: Button = tab_bar.get_child(i)
		b.button_pressed = ["structure", "lower", "modules", "book"][i] == palette_tab
	scroll_pal.scroll_vertical = 0
	match palette_tab:
		"structure": _palette_structure()
		"lower": _palette_lower()
		"modules": _palette_modules()
		"book": _palette_book()

func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_box.add_child(g)
	return g

func _palette_structure() -> void:
	palette_box.add_child(_note("Left-drag paints, right-drag erases, shift-drag fills a rectangle. Keys 1-9 pick the first nine."))
	var grid: GridContainer = null
	var grp := ""
	for i in BRUSHES.size():
		var br: Dictionary = BRUSHES[i]
		var g := String(br.get("grp", ""))
		if g != "" and g != grp:
			grp = g
			var cap := UITheme.caption(g, UITheme.ACCENT)
			var mc := MarginContainer.new()
			mc.add_theme_constant_override("margin_top", 6)
			mc.add_child(cap)
			palette_box.add_child(mc)
			grid = _grid()
		var t := YardArt.Tile.new()
		t.custom_minimum_size = Vector2(92, 104)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.label = String(br["name"])
		t.accent = Color(String(br["col"])).lightened(0.25)
		t.glyph = String(br["g"])
		t.erase_icon = t.glyph == ""
		if t.glyph != "":
			t.sub = "%d" % CShipyard.glyph_cost(t.glyph)
		if i < 9:
			t.key_hint = str(i + 1)
		elif t.erase_icon:
			t.key_hint = "0"
		t.tooltip_text = "%s\n\n%s%s" % [br["name"], br["hint"],
			("\n\n%d marks a tile." % CShipyard.glyph_cost(t.glyph)) if t.glyph != "" else ""]
		t.set_selected(brush == i and module_brush == "")
		var idx := i
		t.pressed.connect(func(): _select_brush(idx))
		grid.add_child(t)
		_brush_tiles.append(t)

func _palette_lower() -> void:
	palette_box.add_child(_note("A room directly below the weather deck. Paint within the hull outline; place one stair on a walkable tile above. Right-drag erases."))
	var make := Button.new()
	make.text = "Sketch a galley from hull"
	make.pressed.connect(_seed_lower)
	palette_box.add_child(make)
	for pair in [["=", "Cabin floor"], ["#", "Bulkhead"], ["stairs", "Stairs up"]]:
		var b := Button.new()
		b.text = String(pair[1])
		b.toggle_mode = true
		b.button_pressed = lower_brush == String(pair[0])
		var id: String = pair[0]
		b.pressed.connect(func():
			lower_brush = id
			_refresh_palette())
		palette_box.add_child(b)
	palette_box.add_child(_note("Stairs connect the two layers at the same hull coordinate. The lower deck is sealed and breathes independently."))

func _seed_lower() -> void:
	if cells.is_empty():
		return
	_push_undo()
	lower_plan.clear()
	var bounds := ShipPlan.bounds(cells)
	for y in range(bounds.position.y + 1, bounds.end.y - 1):
		for x in range(bounds.position.x + 1, bounds.end.x - 1):
			var k := Vector2i(x, y)
			if cells.has(k):
				lower_plan[k] = "="
	for k in lower_plan.keys():
		for d in Defs.DIRS4:
			if not lower_plan.has(k + d):
				lower_plan[k] = "#"
				break
	var best := 999999
	lower_entry_local = Vector2i(-9999, -9999)
	for k in lower_plan:
		if String(lower_plan[k]) == "=" and String(cells.get(k, "")) in [",", "=", "+", "A", "h", "n"]:
			var score := absi(k.x) + absi(k.y)
			if score < best:
				best = score
				lower_entry_local = k
	_say("Lower galley sketched. Place stairs where you want them.")
	_refresh_stats()

func _palette_modules() -> void:
	var tier: int = yard.port_tier if yard != null else 4
	palette_box.add_child(_note("Drop one into a matching mounting. The mounting is the hole; this is what goes in it. Colour is the grade."))
	for cat in ShipParts.CATS:
		var ids: Array = ShipParts.in_cat(String(cat))
		var shown := []
		for mid in ids:
			if ShipParts.tier_of(String(mid)) <= tier:
				shown.append(mid)
		if shown.is_empty():
			continue
		var mc := MarginContainer.new()
		mc.add_theme_constant_override("margin_top", 6)
		mc.add_child(UITheme.caption(String(ShipParts.CATS[cat]["name"]), UITheme.ACCENT))
		palette_box.add_child(mc)
		for mid in shown:
			var m: Dictionary = ShipParts.get_mod(String(mid))
			var req: Dictionary = m.get("req", {})
			var short := Skills.shortfall(user, req)
			var tip := "%s\n\n%s\n\n%s" % [String(m["name"]).capitalize(),
				String(m["desc"]), "   ".join(ShipParts.stat_lines(String(mid)))]
			var q := ShipParts.quirk_text(String(mid))
			if q != "":
				tip += "\n" + q
			if short != "":
				tip += "\nNeeds %s." % short
			var t := YardArt.Tile.new()
			t.wide = true
			t.custom_minimum_size = Vector2(0, 58)
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			t.label = String(m["name"]).capitalize()
			t.sub = Economy.money(int(m.get("cost", 0))) + " marks"
			t.accent = Color(ShipParts.tier_color(String(mid)))
			t.glyph = ShipParts.glyph_for(String(mid))
			t.module = String(mid)
			t.dis = short != ""
			if short != "":
				t.extra = "needs skill"
			t.tooltip_text = _strip(tip)
			t.set_selected(module_brush == String(mid))
			var pick: String = String(mid)
			t.pressed.connect(func(): _select_module(pick))
			palette_box.add_child(t)
			_mod_tiles[pick] = t

func _palette_book() -> void:
	palette_box.add_child(_note("A stock hull, drawn for you. Load one and change it, or buy it as it stands."))
	var purse := Economy.purse(user)
	for hid in ShipPlan.all_ids():
		var h := ShipPlan.get_hull(String(hid))
		var price := CShipyard.hull_price(String(hid), user)
		var t := YardArt.Tile.new()
		t.wide = true
		t.custom_minimum_size = Vector2(0, 64)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.label = String(h["name"])
		t.sub = "%s marks" % Economy.money(price)
		t.extra = "crew %d" % int(h["crew"])
		t.accent = UITheme.GOOD if purse >= price else Color("#e8a83a")
		t.thumb = ShipPlan.to_cells(h["plan"], int(h["keel"]))
		t.tooltip_text = "%s\n\n%s\n\nCrew %d.  %s" % [String(h["name"]), String(h["desc"]),
			int(h["crew"]), ShipPlan.summary(String(hid)).strip_edges()]
		var id: String = String(hid)
		t.pressed.connect(func():
			_push_undo()
			_start_from(id)
			_center_view(true)
			Sfx.play_ui(&"ui_whoosh", 0.7)
			_say("Loaded the %s. Change anything you like — the price follows." % String(h["name"]))
			_refresh_stats())
		palette_box.add_child(t)

func _select_brush(idx: int) -> void:
	brush = idx
	module_brush = ""
	_sync_tiles()
	_update_inspector()

func _select_module(id: String) -> void:
	module_brush = id
	_sync_tiles()
	_update_inspector()

func _sync_tiles() -> void:
	for i in _brush_tiles.size():
		var t: YardArt.Tile = _brush_tiles[i]
		if is_instance_valid(t):
			t.set_selected(brush == i and module_brush == "")
	for id in _mod_tiles:
		var t2: YardArt.Tile = _mod_tiles[id]
		if is_instance_valid(t2):
			t2.set_selected(module_brush == String(id))

func _note(text: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size = Vector2(PALETTE_W - 30, 0)
	r.add_theme_font_size_override("normal_font_size", 15)
	r.add_theme_color_override("default_color", UITheme.DIM)
	r.text = "[i]%s[/i]" % text
	return r

static func _strip(s: String) -> String:
	var out := s
	for tag in ["[color=#7fd4ff]", "[/color]", "[b]", "[/b]", "[i]", "[/i]"]:
		out = out.replace(tag, "")
	return out

# ------------------------------------------------------------------ the board
## Centre *and* scale so the whole hull fills the board. Opening onto a barque the size
## of a postage stamp in an acre of grid is the single most common complaint anybody has
## about an editor like this. `animate` glides there instead of jumping.
func _center_view(animate := false) -> void:
	var b := ShipPlan.bounds(cells)
	if b.size == Vector2i.ZERO:
		pan_t = Vector2.ZERO
		zoom_t = 1.4
	else:
		var room: Vector2 = canvas.size if canvas != null and canvas.size.x > 80.0 else Vector2(900, 700)
		# leave a comfortable margin so she is not jammed against the edges
		var fit := minf(room.x / (float(b.size.x + 4) * CELL), room.y / (float(b.size.y + 4) * CELL))
		zoom_t = clampf(fit, 0.4, 2.2)
		var mid := Vector2(b.position) + Vector2(b.size) * 0.5
		pan_t = -mid * CELL * zoom_t
	if not animate:
		zoom = zoom_t
		pan = pan_t
	if canvas != null:
		canvas.queue_redraw()

func _cell_of(p: Vector2) -> Vector2i:
	var o := canvas.size * 0.5 + pan
	var v := (p - o) / (CELL * zoom)
	return Vector2i(floori(v.x), floori(v.y))

func _pos_of(c: Vector2i) -> Vector2:
	return canvas.size * 0.5 + pan + Vector2(c) * CELL * zoom

func _pos_f(p: Vector2) -> Vector2:
	return canvas.size * 0.5 + pan + p * CELL * zoom

static func _back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var u := clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + c3 * u * u * u + c1 * u * u

func _geom() -> void:
	if not _geom_dirty:
		return
	_geom_dirty = false
	_sealed = ShipPlan.sealed_of(cells)
	_leaks.clear()
	for k in ShipPlan.leaks_of(cells):
		_leaks[k] = true
	_draught = ShipSurvey.draught_map(cells)

func _module_of(key: Vector2i, glyph: String) -> String:
	if fittings.has(key):
		return String(fittings[key])
	return ShipParts.default_for(glyph)

func _draw_board() -> void:
	var _pt := UIPerf.t0()
	_draw_board_inner()
	UIPerf.end("yard.draw_board", _pt)

func _draw_board_inner() -> void:
	var cv := canvas
	var z := CELL * zoom
	var sz := cv.size
	var f := UITheme.font
	_geom()
	# ---- the paper: a blueprint that is a little brighter in the middle
	cv.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.04, 0.06, 0.095))
	for i in 5:
		var k := float(i) / 4.0
		cv.draw_rect(Rect2(sz.x * (0.5 - 0.5 * (1.0 - k * 0.6)), sz.y * (0.5 - 0.5 * (1.0 - k * 0.6)),
			sz.x * (1.0 - k * 0.6), sz.y * (1.0 - k * 0.6)), Color(0.10, 0.16, 0.25, 0.10))
	for i in 34:
		var sx := fmod(float(i * 197 % 977) + _time * (4.0 + float(i % 5) * 2.0), sz.x + 40.0) - 20.0
		var sy := float(i * 331 % 613) / 613.0 * sz.y
		cv.draw_rect(Rect2(sx, sy, 2, 2), Color(0.6, 0.8, 1.0, 0.05 + 0.04 * float(i % 3)))
	# ---- grid: minor every tile, major every five, rulers on the edges
	var lo := _cell_of(Vector2.ZERO) - Vector2i(1, 1)
	var hi := _cell_of(sz) + Vector2i(2, 2)
	for x in range(lo.x, hi.x + 1):
		var major := x % 5 == 0
		var px := _pos_of(Vector2i(x, 0)).x
		cv.draw_line(Vector2(px, 0), Vector2(px, sz.y), Color(0.5, 0.75, 1.0, 0.10 if major else 0.04), 1.0)
		if major and z > 14.0:
			cv.draw_string(f, Vector2(px + 3, 12), str(x), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.7, 0.9, 0.35))
	for y in range(lo.y, hi.y + 1):
		var major2 := y % 5 == 0
		var py := _pos_of(Vector2i(0, y)).y
		cv.draw_line(Vector2(0, py), Vector2(sz.x, py), Color(0.5, 0.75, 1.0, 0.10 if major2 else 0.04), 1.0)
		if major2 and z > 14.0:
			cv.draw_string(f, Vector2(4, py - 3), str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.7, 0.9, 0.35))
	if palette_tab == "lower":
		_draw_lower_board(cv, z, f)
		return
	# ---- the mirror axis, down the middle of the keel row
	var ay := _pos_of(Vector2i(0, 0)).y + z * 0.5
	var acol := Color("#7fd4ff")
	var aal := 0.55 + 0.15 * sin(_time * 3.0) if mirror else 0.16
	var off := fmod(_time * 24.0, 20.0)
	var x0 := -20.0 + off
	while x0 < sz.x:
		cv.draw_line(Vector2(x0, ay), Vector2(x0 + 11.0, ay), Color(acol, aal), 2.0 if mirror else 1.0)
		x0 += 20.0
	cv.draw_string(f, Vector2(sz.x * 0.5 - 90.0, ay - 6.0), "MIRROR AXIS" if mirror else "mirror off",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(acol, aal))
	# ---- sealed spaces, shaded, so "does this cabin hold air" is answered at a glance
	var shim := 0.09 + 0.03 * sin(_time * 1.6)
	for key in _sealed:
		var sp := _pos_of(key)
		if sp.x < -z or sp.y < -z or sp.x > sz.x or sp.y > sz.y:
			continue
		cv.draw_rect(Rect2(sp, Vector2(z, z)), Color(0.35, 0.72, 0.95, shim))
	# ---- the hull itself
	for key in cells:
		_draw_cell(cv, key, String(cells[key]), z)
	# what has just been taken off, shrinking away
	for d in _dying:
		var dk: Vector2i = d[0]
		var t: float = float(d[3]) / DIE_T
		var s := 1.0 - t
		var dp := _pos_of(dk) + Vector2(z, z) * (1.0 - s) * 0.5
		Art.draw_cell(cv, Rect2(dp, Vector2(z, z) * s), dk, String(d[1]), String(d[2]), {}, false, Color(1, 1, 1, 1.0 - t))
	# ---- the leak overlay: pulsing, with air visibly escaping
	if show_leaks:
		# the draught behind each opening: how far the wind will carry into the ship
		for dk2 in _draught:
			if _leaks.has(dk2):
				continue
			var dp2 := _pos_of(dk2)
			if dp2.x < -z or dp2.y < -z or dp2.x > sz.x or dp2.y > sz.y:
				continue
			var ds: float = _draught[dk2]
			cv.draw_rect(Rect2(dp2, Vector2(z, z)), Color(0.35, 0.65, 1.0, 0.10 + 0.32 * ds))
			var sway := sin(_time * 4.0 + float(dk2.x + dk2.y) * 0.9) * z * 0.12
			for li in 2:
				var ly := dp2.y + z * (0.33 + 0.34 * float(li)) + sway
				cv.draw_line(Vector2(dp2.x + z * 0.15, ly), Vector2(dp2.x + z * 0.85, ly + sway * 0.5), Color(0.8, 0.92, 1.0, 0.25 + 0.5 * ds), 2.0)
		for key in _leaks:
			var lp := _pos_of(key)
			if lp.x < -z or lp.y < -z or lp.x > sz.x or lp.y > sz.y:
				continue
			var pl := 0.5 + 0.5 * sin(_time * 6.0 + float(key.x) * 0.7)
			cv.draw_rect(Rect2(lp, Vector2(z, z)), Color(1.0, 0.25, 0.2, 0.18 + 0.22 * pl))
			cv.draw_rect(Rect2(lp, Vector2(z, z)).grow(-1), Color(1.0, 0.4, 0.3, 0.5 + 0.5 * pl), false, 2.0)
			var dir := Vector2(0, -1.0 if key.y < 0 else 1.0)
			if key.y == 0:
				dir = Vector2(-1, 0)
			var ctr := lp + Vector2(z, z) * 0.5
			for i in 3:
				var fr := fmod(_time * 0.9 + float(i) / 3.0 + float(key.x) * 0.13, 1.0)
				var q := ctr + dir * (fr * z * 1.3)
				cv.draw_line(q - dir * z * 0.16, q + dir * z * 0.16, Color(1.0, 0.7, 0.55, (1.0 - fr) * 0.85), 2.0)
			if z > 20.0:
				cv.draw_string(f, lp + Vector2(z * 0.5 - 3.0, z * 0.5 + 5.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(z * 0.5), Color(1, 0.85, 0.8, 0.5 + 0.5 * pl))
	# cells belonging to the issue under the mouse
	if not _hl_cells.is_empty():
		var hp2 := 0.5 + 0.5 * sin(_time * 9.0)
		for hk in _hl_cells:
			var hpp := _pos_of(hk)
			cv.draw_rect(Rect2(hpp, Vector2(z, z)), Color(1.0, 0.85, 0.3, 0.15 + 0.25 * hp2))
			cv.draw_rect(Rect2(hpp, Vector2(z, z)).grow(1.0 + 2.0 * hp2), Color(1.0, 0.85, 0.3, 0.9), false, 2.0)
	# ---- the bow, bobbing
	var b := ShipPlan.bounds(cells)
	if not cells.is_empty():
		var nose := _pos_of(Vector2i(b.end.x, 0)) + Vector2(6.0 + 3.0 * sin(_time * 3.0), z * 0.5)
		cv.draw_colored_polygon(PackedVector2Array([nose + Vector2(0, -8), nose + Vector2(16, 0), nose + Vector2(0, 8)]), Color("#7fd4ff"))
		cv.draw_string(f, nose + Vector2(22, 5), "BOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#7fd4ff"))
	# ---- the cursor: guide lines, snap brackets and the ghost of what you are about to lay
	if _hover != NONE and not _panning and not _seq:
		_draw_hover(cv, z, f)
	# rectangle fill preview
	if _drag_start != NONE and _hover != NONE:
		var r := _rect_of(_drag_start, _hover)
		var rc := Color("#ff8a7a") if _painting == 2 else Color("#7fd4ff")
		var rr := Rect2(_pos_of(r.position), Vector2(r.size) * z)
		cv.draw_rect(rr, Color(rc, 0.12))
		cv.draw_rect(rr, rc, false, 2.0)
		cv.draw_string(f, rr.position + Vector2(4, -6), "%d × %d" % [r.size.x, r.size.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, rc)
	# the paint trail: rings that spread and fade
	for tr in _trail:
		var age: float = tr[1]
		var tc: Color = tr[2]
		var tp := _pos_of(tr[0]) + Vector2(z, z) * 0.5
		cv.draw_arc(tp, z * (0.4 + age * 1.6), 0.0, TAU, 20, Color(tc, (1.0 - age / 0.45) * 0.6), 2.0)
	# particles
	for p in _parts:
		var pp := _pos_f(p["p"])
		var pa := clampf(float(p["life"]) / float(p["max"]), 0.0, 1.0)
		var ps: float = float(p["sz"]) * (0.5 + 0.5 * pa)
		cv.draw_rect(Rect2(pp - Vector2(ps, ps) * 0.5, Vector2(ps, ps)), Color(p["col"], pa))
	_draw_overlays(cv, z, f, b)

func _draw_cell(cv: Control, key: Vector2i, glyph: String, z: float) -> void:
	var p := _pos_of(key)
	if p.x < -z or p.y < -z or p.x > cv.size.x or p.y > cv.size.y:
		return
	var age: float = _pop.get(key, 1.0)
	if age < 0.0:
		return
	var r := Rect2(p, Vector2(z, z))
	var fl := 0.0
	if age < POP_T:
		var t := age / POP_T
		var s := lerpf(0.35, 1.0, _back(t))
		r = Rect2(p + Vector2(z, z) * (1.0 - s) * 0.5, Vector2(z, z) * s)
		fl = 1.0 - t
	var mid := _module_of(key, glyph)
	Art.draw_cell(cv, r, key, glyph, mid, cells, _sealed.has(key))
	if mid != "" and ShipParts.cat_of(mid) != "armor" and z > 16.0:
		# the tier pip: you can see at a glance which engines are the good ones
		var tc := Color(ShipParts.tier_color(mid))
		var pc := r.end - Vector2(z * 0.16, z * 0.16)
		cv.draw_circle(pc, z * 0.11, tc)
		cv.draw_circle(pc, z * 0.11, tc.darkened(0.6), false, 1.5)
	if fl > 0.0:
		cv.draw_rect(r, Color(1, 1, 1, fl * 0.6))
	var dn: float = _deny.get(key, 9.0)
	if dn < 0.35:
		cv.draw_rect(r, Color(1, 0.2, 0.2, (1.0 - dn / 0.35) * 0.5))

## Why the cursor's cell would or would not take the current brush. "" means yes.
func _draw_lower_board(cv: Control, z: float, f: Font) -> void:
	for k in cells:
		var p := _pos_of(k)
		cv.draw_rect(Rect2(p, Vector2(z, z)).grow(-2), Color("#526777", 0.22))
	for k in lower_plan:
		var p := _pos_of(k)
		var wall := String(lower_plan[k]) == "#"
		cv.draw_rect(Rect2(p, Vector2(z, z)).grow(-1), Color("#534a40" if wall else "#a38b6b"))
		if wall:
			cv.draw_rect(Rect2(p, Vector2(z, z)).grow(-4), Color("#82745f"), false, 2.0)
		else:
			for i in 3:
				cv.draw_line(p + Vector2(2, z * float(i + 1) / 3.0), p + Vector2(z - 2, z * float(i + 1) / 3.0), Color("#d0b48b", 0.5), 1.0)
	if lower_plan.has(lower_entry_local):
		var p := _pos_of(lower_entry_local)
		cv.draw_rect(Rect2(p, Vector2(z, z)).grow(-3), Color("#d6aa61"), false, 3.0)
		cv.draw_string(f, p + Vector2(4, z - 6), "UP", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(10, int(z * 0.38)), Color("#fff0bb"))
	if _hover != NONE:
		var col := Color("#71dba5") if _place_reason(_hover, _painting == 2) == "" else Color("#e27d70")
		cv.draw_rect(Rect2(_pos_of(_hover), Vector2(z, z)).grow(-1), col, false, 2.0)
	cv.draw_string(f, Vector2(22, 34), "LOWER DECK  /  GALLEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#e8d2a8"))

func _place_reason(key: Vector2i, erase: bool) -> String:
	if palette_tab == "lower":
		if not cells.has(key):
			return "Outside the hull."
		if erase:
			return "" if lower_plan.has(key) else "nothing"
		if lower_brush == "stairs" and not String(cells.get(key, "")) in [",", "=", "+", "A", "h", "n"]:
			return "Stairs need a walkable tile above."
		return ""
	if erase or (module_brush == "" and brush < BRUSHES.size() and String(BRUSHES[brush]["g"]) == ""):
		return "" if cells.has(key) else "nothing"
	if module_brush != "":
		var glyph := String(cells.get(key, ""))
		if glyph == "":
			if ShipParts.glyph_for(module_brush) == "":
				return "no"
			return "" if _touches(key) else "Nothing to fix it to."
		if not ShipParts.fits_glyph(module_brush, glyph):
			return "A %s does not go in that mounting." % ShipParts.name_of(module_brush)
		return "same" if String(fittings.get(key, "")) == module_brush else ""
	if cells.has(key):
		return "same" if String(cells[key]) == String(BRUSHES[brush]["g"]) else ""
	if cells.is_empty() or _touches(key):
		return ""
	return "Build out from the hull."

func _draw_hover(cv: Control, z: float, f: Font) -> void:
	var erasing := _painting == 2 or (module_brush == "" and brush < BRUSHES.size() and String(BRUSHES[brush]["g"]) == "")
	var keys: Array = [_hover]
	if _mirroring() and _hover.y != 0:
		keys.append(Vector2i(_hover.x, -_hover.y))
	var gcol := Color("#7fd4ff")
	if module_brush != "":
		gcol = Color(ShipParts.tier_color(module_brush))
	elif brush < BRUSHES.size():
		gcol = Color(String(BRUSHES[brush]["col"])).lightened(0.3)
	# faint crosshair: row and column, so a tile is easy to line up across a long hull
	var hp := _pos_of(_hover)
	cv.draw_rect(Rect2(0, hp.y, cv.size.x, z), Color(1, 1, 1, 0.025))
	cv.draw_rect(Rect2(hp.x, 0, z, cv.size.y), Color(1, 1, 1, 0.025))
	for i in keys.size():
		var k: Vector2i = keys[i]
		var reason := _place_reason(k, _painting == 2)
		var ok := reason == ""
		var neutral := reason == "same"
		var p := _pos_of(k)
		var rc := Rect2(p, Vector2(z, z))
		var col := gcol
		if erasing:
			col = Color("#ff7a6a") if cells.has(k) else Color(0.5, 0.5, 0.55)
		elif not ok and not neutral:
			col = Color("#ff5a4a")
		elif neutral:
			col = Color(0.75, 0.8, 0.85)
		var al := 1.0 if i == 0 else 0.55
		if ok and not erasing:
			var g := ""
			var mid := ""
			if module_brush != "":
				g = String(cells.get(k, ShipParts.glyph_for(module_brush)))
				mid = module_brush
			else:
				g = String(BRUSHES[brush]["g"])
			Art.draw_cell(cv, rc, k, g, mid, cells, _sealed.has(k), Color(1, 1, 1, 0.62 * al))
		cv.draw_rect(rc, Color(col, (0.20 if ok or erasing else 0.30) * al))
		# snap brackets, breathing
		var br := z * (0.28 + 0.04 * sin(_time * 8.0))
		var pad := 1.0 + 1.5 * sin(_time * 8.0)
		var c2 := Color(col, al)
		for cx in [0.0, 1.0]:
			for cy in [0.0, 1.0]:
				var corner := p + Vector2(cx * z, cy * z) + Vector2((-pad if cx == 0.0 else pad), (-pad if cy == 0.0 else pad))
				var sx := 1.0 if cx == 0.0 else -1.0
				var sy := 1.0 if cy == 0.0 else -1.0
				cv.draw_line(corner, corner + Vector2(br * sx, 0), c2, 2.0)
				cv.draw_line(corner, corner + Vector2(0, br * sy), c2, 2.0)
		if erasing and cells.has(k):
			cv.draw_line(p + Vector2(z, z) * 0.25, p + Vector2(z, z) * 0.75, Color(col, al), 3.0)
			cv.draw_line(p + Vector2(z * 0.75, z * 0.25), p + Vector2(z * 0.25, z * 0.75), Color(col, al), 3.0)
		elif not ok and not neutral and not erasing:
			cv.draw_line(p + Vector2(z, z) * 0.3, p + Vector2(z, z) * 0.7, Color(col, al), 3.0)
			cv.draw_line(p + Vector2(z * 0.7, z * 0.3), p + Vector2(z * 0.3, z * 0.7), Color(col, al), 3.0)
	# a little label beside the cursor
	var lab := ""
	var lk: Vector2i = _hover
	if cells.has(lk):
		lab = Art.glyph_name(String(cells[lk]))
	var reason0 := _place_reason(_hover, _painting == 2)
	if reason0 != "" and reason0 != "same" and reason0 != "nothing" and reason0 != "no" and not erasing:
		lab = reason0
	if lab != "":
		var w := f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 12.0
		var bx := clampf(hp.x + z + 6.0, 4.0, cv.size.x - w - 4.0)
		var by := clampf(hp.y - 4.0, 4.0, cv.size.y - 24.0)
		cv.draw_rect(Rect2(bx, by, w, 20), Color(0.02, 0.04, 0.07, 0.85))
		cv.draw_rect(Rect2(bx, by, w, 20), Color(gcol, 0.6), false, 1.0)
		cv.draw_string(f, Vector2(bx + 6, by + 15), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.92, 0.96, 1.0))

func _draw_overlays(cv: Control, z: float, f: Font, b: Rect2i) -> void:
	var sz := cv.size
	# ---- compass, top right: which way is she pointing
	var cc := Vector2(sz.x - 54.0, 54.0)
	cv.draw_circle(cc, 36.0, Color(0.02, 0.04, 0.07, 0.6))
	cv.draw_arc(cc, 36.0, 0.0, TAU, 32, Color(0.5, 0.75, 1.0, 0.45), 1.5)
	cv.draw_colored_polygon(PackedVector2Array([cc + Vector2(30, 0), cc + Vector2(6, -8), cc + Vector2(6, 8)]), Color("#7fd4ff"))
	cv.draw_colored_polygon(PackedVector2Array([cc + Vector2(-26, 0), cc + Vector2(-6, -5), cc + Vector2(-6, 5)]), Color(0.4, 0.5, 0.6, 0.8))
	cv.draw_string(f, cc + Vector2(-8, -20), "PORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.75, 0.9, 0.7))
	cv.draw_string(f, cc + Vector2(-9, 30), "STBD", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.75, 0.9, 0.7))
	cv.draw_string(f, cc + Vector2(-46, 5), "AFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.75, 0.9, 0.7))
	cv.draw_string(f, cc + Vector2(14, 22), "BOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#7fd4ff"))
	# ---- the silhouette: the whole ship at a glance, and where the view is on it
	if not cells.is_empty():
		var mw := 132.0
		var mh := 78.0
		var mo := Vector2(sz.x - mw - 12.0, sz.y - mh - 12.0)
		cv.draw_rect(Rect2(mo, Vector2(mw, mh)), Color(0.02, 0.04, 0.07, 0.72))
		cv.draw_rect(Rect2(mo, Vector2(mw, mh)), Color(0.5, 0.75, 1.0, 0.4), false, 1.0)
		var sc := minf((mw - 12.0) / float(b.size.x), (mh - 22.0) / float(b.size.y))
		sc = floorf(sc) if sc > 1.0 else sc
		var org := mo + Vector2(6, 6) + (Vector2(mw - 12.0, mh - 22.0) - Vector2(b.size) * sc) * 0.5
		for k in cells:
			cv.draw_rect(Rect2(org + Vector2(k - b.position) * sc, Vector2(sc, sc)), Shipyard._glyph_color(String(cells[k])))
		var v0 := Vector2(_cell_of(Vector2.ZERO) - b.position) * sc + org
		var v1 := Vector2(_cell_of(sz) - b.position) * sc + org
		var vr := Rect2(v0, v1 - v0).intersection(Rect2(mo, Vector2(mw, mh)))
		if vr.size.x > 0.0:
			cv.draw_rect(vr, Color(1, 1, 1, 0.5), false, 1.0)
		var nfit := 0
		for k in cells:
			if ShipParts.default_for(String(cells[k])) != "":
				nfit += 1
		cv.draw_string(f, mo + Vector2(6, mh - 5), "%d × %d tiles · %d fittings" % [b.size.x, b.size.y, nfit],
			HORIZONTAL_ALIGNMENT_LEFT, mw - 8.0, 11, Color(0.7, 0.85, 1.0, 0.85))
	# ---- a word about what just happened, as a toast that rises and fades
	if _message != "" and _message_t > 0.0:
		var a := clampf(_message_t * 1.5, 0.0, 1.0)
		var rise := (1.0 - a) * 8.0
		var mw2 := f.get_string_size(_message, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.BODY).x + 24.0
		var tx := (sz.x - mw2) * 0.5
		var ty := sz.y - 62.0 - rise
		cv.draw_rect(Rect2(tx, ty, mw2, 28), Color(0.02, 0.04, 0.07, 0.86 * a))
		cv.draw_rect(Rect2(tx, ty, mw2, 28), Color(0.5, 0.75, 1.0, 0.6 * a), false, 1.0)
		cv.draw_string(f, Vector2(tx + 12, ty + 20), _message, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.BODY, Color(1, 1, 1, a))
	# ---- the keys
	cv.draw_string(f, Vector2(12, sz.y - 12), "LMB paint · RMB erase · Shift+drag rectangle · MMB pan · wheel zoom · M mirror (hold Alt: one side only) · F wrap · L leaks · Ctrl+Z undo · C fit",
		HORIZONTAL_ALIGNMENT_LEFT, sz.x - 170.0, 12, Color(0.6, 0.75, 0.9, 0.55))
	cv.draw_string(f, Vector2(12, 18), "ZOOM %d%%" % int(zoom * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.75, 0.9, 0.5))

static func _glyph_color(g: String) -> Color:
	for br in BRUSHES:
		if String(br["g"]) == g:
			return Color(String(br["col"]))
	return Color("#6a6a74")

static func _rect_of(a: Vector2i, b: Vector2i) -> Rect2i:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)

# ------------------------------------------------------------------ input
func _board_input(ev: InputEvent) -> void:
	if _seq:
		return
	if ev is InputEventMouseMotion:
		var was := _hover
		_hover = _cell_of(ev.position)
		if _hover != was:
			_update_inspector()
		if _panning:
			pan += ev.relative
			pan_t += ev.relative
			return
		if _painting != 0 and _drag_start == NONE and _hover != was and _last_paint != NONE:
			for c in _line_cells(_last_paint, _hover):
				_apply_brush(c, _painting == 2)
			_last_paint = _hover
		return
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if mb.pressed:
				_zoom_by(1.15, mb.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_zoom_by(1.0 / 1.15, mb.position)
		MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
			var erase := mb.button_index == MOUSE_BUTTON_RIGHT
			if mb.pressed:
				canvas.grab_focus()
				if name_edit != null:
					name_edit.release_focus()
				_push_undo()
				_stroke_n = 0
				_denied_stroke = false
				if Input.is_key_pressed(KEY_SHIFT):
					_drag_start = _cell_of(mb.position)
					_painting = 2 if erase else 1
					Sfx.play_ui(&"ui_tick", 0.5)
					return
				_painting = 2 if erase else 1
				_last_paint = _cell_of(mb.position)
				_apply_brush(_last_paint, erase)
			else:
				if _drag_start != NONE:
					_fill_rect(_rect_of(_drag_start, _cell_of(mb.position)), _painting == 2)
					_drag_start = NONE
				_painting = 0
				_last_paint = NONE
				_refresh_stats()

## Every cell on the straight line from a to b, excluding a. A fast stroke skips tiles
## between mouse events; painting them all is what makes a stroke feel like a stroke.
static func _line_cells(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []
	var dx := absi(b.x - a.x)
	var dy := absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx - dy
	var c := a
	var guard := 0
	while c != b and guard < 400:
		guard += 1
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			c.x += sx
		if e2 < dx:
			err += dx
			c.y += sy
		out.append(c)
	return out

func _zoom_by(f: float, at: Vector2) -> void:
	var o := canvas.size * 0.5
	var wp := (at - o - pan_t) / (CELL * zoom_t)
	zoom_t = clampf(zoom_t * f, 0.35, 3.2)
	pan_t = at - o - wp * CELL * zoom_t
	Sfx.play_ui(&"ui_tick", 0.25, 0.9 + zoom_t * 0.15)

func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed:
		return
	var k := ev as InputEventKey
	if _seq:
		get_viewport().set_input_as_handled()
		return
	var typing := name_edit != null and name_edit.has_focus()
	if typing:
		if k.physical_keycode == KEY_ESCAPE:
			name_edit.release_focus()
			get_viewport().set_input_as_handled()
		return
	var ctrl := k.ctrl_pressed
	# arrow keys pan, and repeat while held
	var pv := Vector2.ZERO
	match k.physical_keycode:
		KEY_LEFT: pv = Vector2(1, 0)
		KEY_RIGHT: pv = Vector2(-1, 0)
		KEY_UP: pv = Vector2(0, 1)
		KEY_DOWN: pv = Vector2(0, -1)
	if pv != Vector2.ZERO:
		pan_t += pv * 90.0
		get_viewport().set_input_as_handled()
		return
	if k.echo:
		return
	match k.physical_keycode:
		KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
		KEY_M:
			_toggle_mirror()
			get_viewport().set_input_as_handled()
		KEY_F:
			_wrap_hull()
			get_viewport().set_input_as_handled()
		KEY_L:
			_toggle_leaks()
			get_viewport().set_input_as_handled()
		KEY_C, KEY_HOME:
			_center_view(true)
			get_viewport().set_input_as_handled()
		KEY_MINUS:
			_zoom_by(1.0 / 1.25, canvas.size * 0.5)
		KEY_EQUAL:
			_zoom_by(1.25, canvas.size * 0.5)
		KEY_TAB:
			var order := ["structure", "lower", "modules", "book"]
			_set_tab(order[(order.find(palette_tab) + 1) % order.size()])
			Sfx.play_ui(&"ui_tick", 0.6)
			get_viewport().set_input_as_handled()
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			var step := -1 if k.physical_keycode == KEY_BRACKETLEFT else 1
			_select_brush(posmod(brush + step, BRUSHES.size()))
			Sfx.play_ui(&"ui_tick", 0.6, 1.0 + 0.05 * step)
			get_viewport().set_input_as_handled()
		KEY_Z:
			if ctrl:
				_do_undo()
				get_viewport().set_input_as_handled()
		KEY_Y:
			if ctrl:
				_do_redo()
				get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if ctrl:
				_commit()
				get_viewport().set_input_as_handled()
		_:
			var n := -1
			if k.physical_keycode >= KEY_1 and k.physical_keycode <= KEY_9:
				n = k.physical_keycode - KEY_1
			elif k.physical_keycode == KEY_0:
				n = BRUSHES.size() - 1
			if n >= 0 and n < BRUSHES.size() and not ctrl:
				if palette_tab != "structure":
					_set_tab("structure")
				_select_brush(n)
				Sfx.play_ui(&"ui_tick", 0.6)
				get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var _pt := UIPerf.t0()
	_process_inner(delta)
	UIPerf.end("yard.process", _pt)
	UIPerf.tick(delta)

func _process_inner(delta: float) -> void:
	_time += delta
	if _want_fit and canvas != null and canvas.size.x > 80.0:
		_want_fit = false
		_center_view()
		canvas.queue_redraw()
	# eased zoom and pan: glide, never jump
	var k := 1.0 - exp(-14.0 * delta)
	zoom = lerpf(zoom, zoom_t, k)
	if absf(zoom - zoom_t) < 0.0004:
		zoom = zoom_t
	pan = pan.lerp(pan_t, k)
	if pan.distance_to(pan_t) < 0.05:
		pan = pan_t
	if _message_t > 0.0:
		_message_t -= delta * 0.45
	_tick_fx(delta)
	_tick_numbers(delta)
	_tick_demo(delta)
	if _seq:
		_tick_seq(delta)
	if commit_btn != null:
		_tick_button(delta)
	if canvas != null:
		# Full rate only while something is actually moving or being dragged; the idle
		# ambience (drifting motes, axis dashes, bobbing bow) is fine at 30 Hz.
		_idle_t += delta
		var busy := zoom != zoom_t or pan != pan_t or _painting != 0 or _panning or _drag_start != NONE 			or _seq or not _pop.is_empty() or not _deny.is_empty() or not _dying.is_empty() 			or not _trail.is_empty() or not _parts.is_empty() or _message_t > 0.0 or _hover != _drawn_hover
		if busy or _idle_t >= 0.033:
			_idle_t = 0.0
			_drawn_hover = _hover
			canvas.queue_redraw()

var _idle_t := 0.0
var _drawn_hover := Vector2i(-99999, -99999)

func _tick_fx(dt: float) -> void:
	for key in _pop.keys():
		_pop[key] = float(_pop[key]) + dt
		if float(_pop[key]) > POP_T:
			_pop.erase(key)
	for key in _deny.keys():
		_deny[key] = float(_deny[key]) + dt
		if float(_deny[key]) > 0.4:
			_deny.erase(key)
	for d in _dying:
		d[3] = float(d[3]) + dt
	_dying = _dying.filter(func(d): return float(d[3]) < DIE_T)
	for tr in _trail:
		tr[1] = float(tr[1]) + dt
	_trail = _trail.filter(func(tr): return float(tr[1]) < 0.45)
	for p in _parts:
		p["life"] = float(p["life"]) - dt
		p["v"] = Vector2(p["v"]) + Vector2(0, float(p["g"])) * dt
		p["p"] = Vector2(p["p"]) + Vector2(p["v"]) * dt
	_parts = _parts.filter(func(p): return float(p["life"]) > 0.0)

func _burst(key: Vector2i, col: Color, n: int, erase: bool) -> void:
	if _parts.size() > 320:
		return
	var c := Vector2(key) + Vector2(0.5, 0.5)
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(0.6, 2.6)
		var life := randf_range(0.25, 0.6)
		var sparkle := not erase and i % 3 == 0
		_parts.append({
			"p": c + Vector2(cos(a), sin(a)) * 0.25, "v": Vector2(cos(a), sin(a)) * sp - (Vector2.ZERO if erase else Vector2(0, 0.6)),
			"life": life, "max": life, "g": 5.5 if erase else 1.2,
			"col": Color(1.0, 0.97, 0.8) if sparkle else col.lightened(randf_range(0.0, 0.4)),
			"sz": randf_range(3.0, 6.0) if not sparkle else 3.0})

# ------------------------------------------------------------------ editing
func _apply_brush(key: Vector2i, erase: bool) -> void:
	var changed := _set_one(key, erase)
	if _mirroring() and key.y != 0 and not (palette_tab == "lower" and lower_brush == "stairs" and not erase):
		changed = _set_one(Vector2i(key.x, -key.y), erase) or changed
	if changed:
		_stroke_n += 1
		_trail.append([key, 0.0, _fx_col(erase)])
		_paint_sound(erase)
		_refresh_stats()
	elif _fail != "" and not _denied_stroke:
		_denied_stroke = true
		_deny[key] = 0.0
		Sfx.play_ui(&"ui_deny", 0.6)
		_say(_fail)
	_fail = ""

var _fail := ""

func _fx_col(erase: bool) -> Color:
	if palette_tab == "lower":
		return Color("#ff8a7a" if erase else "#c99b63")
	if erase:
		return Color("#ff8a7a")
	if module_brush != "":
		return Color(ShipParts.tier_color(module_brush))
	return Color(String(BRUSHES[brush]["col"])).lightened(0.3)

## Placement and erase sounds, rate limited, and the pitch climbs along the stroke so a
## long drag sounds like it is going somewhere.
func _paint_sound(erase: bool) -> void:
	var now := Time.get_ticks_msec()
	if _stroke_n > 1 and now - _last_snd < 55:
		return
	_last_snd = now
	var pitch := 0.92 + 0.05 * float(mini(_stroke_n, 18))
	Sfx.play_ui(&"ui_erase" if erase else &"ui_place", 0.85, pitch)

func _fx_placed(key: Vector2i, glyph: String, mid: String) -> void:
	_pop[key] = 0.0
	var col := Color(String(BRUSHES[brush]["col"])) if module_brush == "" else Color(ShipParts.tier_color(module_brush))
	_burst(key, col.lightened(0.15), 7, false)

func _fx_erased(key: Vector2i, glyph: String, mid: String) -> void:
	_dying.append([key, glyph, mid, 0.0])
	_pop.erase(key)
	_burst(key, _dust_col(glyph), 8, true)

static func _dust_col(glyph: String) -> Color:
	return _glyph_color(glyph).lightened(0.2)

## Returns true if the board changed.
func _set_one(key: Vector2i, erase: bool) -> bool:
	if palette_tab == "lower":
		if not cells.has(key):
			_fail = "Lower deck must stay within the hull."
			return false
		if erase:
			if not lower_plan.has(key):
				return false
			lower_plan.erase(key)
			if key == lower_entry_local:
				lower_entry_local = Vector2i(-9999, -9999)
			return true
		if lower_brush == "stairs":
			if _place_reason(key, false) != "":
				_fail = _place_reason(key, false)
				return false
			if lower_entry_local == key and String(lower_plan.get(key, "")) == "=":
				return false
			lower_entry_local = key
			lower_plan[key] = "="
			return true
		if String(lower_plan.get(key, "")) == lower_brush:
			return false
		lower_plan[key] = lower_brush
		if key == lower_entry_local and lower_brush == "#":
			lower_entry_local = Vector2i(-9999, -9999)
		return true
	if erase:
		if not cells.has(key):
			return false
		var og := String(cells[key])
		_fx_erased(key, og, _module_of(key, og))
		cells.erase(key)
		fittings.erase(key)
		return true
	if module_brush != "":
		var glyph := String(cells.get(key, ""))
		var made := false
		if glyph == "":
			# dropping a module on empty space cuts the hole for it first, which is what
			# the player meant and saves a step they would only ever resent
			glyph = ShipParts.glyph_for(module_brush)
			if glyph == "" or not _touches(key):
				_fail = "Nothing to fix it to. Build out from the hull."
				return false
			cells[key] = glyph
			made = true
		if not ShipParts.fits_glyph(module_brush, glyph):
			_fail = "A %s does not go in that mounting." % ShipParts.name_of(module_brush)
			return false
		if not made and String(fittings.get(key, "")) == module_brush:
			return false
		fittings[key] = module_brush
		_fx_placed(key, glyph, module_brush)
		return true
	var br: Dictionary = BRUSHES[brush]
	var g := String(br["g"])
	if g == "":
		if not cells.has(key):
			return false
		var og2 := String(cells[key])
		_fx_erased(key, og2, _module_of(key, og2))
		cells.erase(key)
		fittings.erase(key)
		return true
	if not cells.has(key) and not cells.is_empty() and not _touches(key):
		_fail = "Build out from the hull: a hull has to be one connected thing."
		return false  # no building in mid-air
	if String(cells.get(key, "")) == g:
		return false
	cells[key] = g
	# a new hole gets the cheapest thing that fits, so a drawing is always flyable
	var dflt := ShipParts.default_for(g)
	if dflt == "":
		fittings.erase(key)
	elif not fittings.has(key) or not ShipParts.fits_glyph(String(fittings[key]), g):
		fittings[key] = dflt
	_fx_placed(key, g, dflt)
	return true

func _touches(key: Vector2i) -> bool:
	for d in Defs.DIRS4:
		if cells.has(key + d):
			return true
	return false

func _fill_rect(r: Rect2i, erase: bool) -> void:
	var n := 0
	var wave := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var a := _set_one(Vector2i(x, y), erase)
			if _mirroring() and y != 0 and not (palette_tab == "lower" and lower_brush == "stairs" and not erase):
				a = _set_one(Vector2i(x, -y), erase) or a
			if a:
				n += 1
				if not erase and _pop.has(Vector2i(x, y)):
					_pop[Vector2i(x, y)] = -0.02 * float(wave)
				wave += 1
	_fail = ""
	if n > 0:
		_stroke_n = 1
		Sfx.play_ui(&"ui_erase" if erase else &"ui_place", 1.0, 0.85)
		Sfx.play_ui(&"ui_tick", 0.6, 1.4)
		_say("%s %d tile%s." % ["Cleared" if erase else "Filled", n, "" if n == 1 else "s"])
	_refresh_stats()

## Mirror is on for the board, but holding Alt places (or erases) just the one tile under
## the cursor: the odd lantern, the single gun on one beam, the off-centre hatch.
func _mirroring() -> bool:
	return mirror and not Input.is_key_pressed(KEY_ALT)

func _toggle_mirror() -> void:
	mirror = not mirror
	if mirror_btn != null:
		mirror_btn.text = "Mirror: %s [M]" % ("on" if mirror else "off")
		mirror_btn.set_pressed_no_signal(mirror)
	Sfx.play_ui(&"ui_tick", 0.8, 1.2 if mirror else 0.8)
	_say("Mirror %s." % ("on — draw one side, get the other" if mirror else "off"))

func _toggle_leaks() -> void:
	show_leaks = not show_leaks
	_geom_dirty = true
	_geom()
	var n := _leaks.size()
	if leaks_btn != null:
		leaks_btn.set_pressed_no_signal(show_leaks)
	Sfx.play_ui(&"ui_tick", 0.8, 1.2 if show_leaks else 0.8)
	if show_leaks:
		_say("%d cabin tile%s open to the weather; wind will reach %d more." % [n, "" if n == 1 else "s", maxi(0, _draught.size() - n)] if n > 0 else "Not a leak on her. She is tight.")
	else:
		_say("")

## Put bulwark all the way round whatever deck has been drawn. This is the single most
## useful button on the screen: drawing the outline by hand is forty clicks of tedium and
## no decisions at all.
func _wrap_hull() -> void:
	_push_undo()
	var add := {}
	for key in cells:
		var g := String(cells[key])
		if g in ShipPlan.WALLS or g == "I":
			continue
		for d in Defs.DIRS8:
			var n: Vector2i = key + d
			if not cells.has(n):
				add[n] = true
	var i := 0
	for key in add:
		cells[key] = "#"
		_pop[key] = -0.012 * float(i)
		_burst(key, Color("#a08a64"), 3, false)
		i += 1
	if add.is_empty():
		_say("Nothing to wrap: she is already closed in.")
		Sfx.play_ui(&"ui_deny", 0.6)
	else:
		Sfx.play_ui(&"ui_place", 1.0, 0.8)
		Sfx.play_ui(&"ui_confirm", 0.5)
		_say("Wrapped %d tiles of bulwark round her." % add.size())
	_refresh_stats()

func _clear_all() -> void:
	_push_undo()
	if palette_tab == "lower":
		lower_plan.clear()
		lower_entry_local = Vector2i(-9999, -9999)
		_say("Lower deck cleared. Ctrl+Z puts it back.")
		_refresh_stats()
		return
	var i := 0
	for k in cells:
		if i < 60:
			_dying.append([k, String(cells[k]), _module_of(k, String(cells[k])), 0.0])
		_burst(k, _dust_col(String(cells[k])), 1, true)
		i += 1
	cells.clear()
	fittings.clear()
	lower_plan.clear()
	lower_entry_local = Vector2i(-9999, -9999)
	Sfx.play_ui(&"ui_erase", 1.0, 0.7)
	_say("Cleared. Ctrl+Z puts it back.")
	_refresh_stats()

func _start_from(hull_id: String) -> void:
	var h := ShipPlan.get_hull(hull_id)
	cells = ShipPlan.to_cells(h["plan"], int(h["keel"]))
	fittings = Airship.default_fittings(cells, int(h.get("grade", 1)))
	lower_plan.clear()
	lower_entry_local = Vector2i(-9999, -9999)
	_dying.clear()
	# she builds herself in from the keel outwards
	_pop.clear()
	for k in cells:
		_pop[k] = -absf(float(k.x)) * 0.02 - absf(float(k.y)) * 0.03
	_geom_dirty = true

func _push_undo() -> void:
	_undo.append([cells.duplicate(true), fittings.duplicate(true), lower_plan.duplicate(true), lower_entry_local])
	if _undo.size() > 60:
		_undo.pop_front()
	_redo.clear()

func _do_undo() -> void:
	if _undo.is_empty():
		_say("Nothing to undo.")
		Sfx.play_ui(&"ui_deny", 0.5)
		return
	_redo.append([cells.duplicate(true), fittings.duplicate(true), lower_plan.duplicate(true), lower_entry_local])
	var st: Array = _undo.pop_back()
	cells = st[0]
	fittings = st[1]
	lower_plan = st[2]
	lower_entry_local = st[3]
	Sfx.play_ui(&"ui_tick", 0.9, 0.8)
	_refresh_stats()

func _do_redo() -> void:
	if _redo.is_empty():
		_say("Nothing to redo.")
		Sfx.play_ui(&"ui_deny", 0.5)
		return
	_undo.append([cells.duplicate(true), fittings.duplicate(true), lower_plan.duplicate(true), lower_entry_local])
	var st: Array = _redo.pop_back()
	cells = st[0]
	fittings = st[1]
	lower_plan = st[2]
	lower_entry_local = st[3]
	Sfx.play_ui(&"ui_tick", 0.9, 1.2)
	_refresh_stats()

func _say(text: String) -> void:
	_message = text
	_message_t = 2.0

## What is under the cursor, in plain words. This is the panel that makes the board
## readable without a key: hover anything and it tells you what it is, what is bolted in
## it, and what that does. Off the hull it shows what your brush is and what it costs.
func _update_inspector() -> void:
	if inspect_box == null:
		return
	var key := _hover
	if palette_tab == "lower":
		var desc := "Move over the drawing."
		if key != NONE:
			desc = "Outside the hull." if not cells.has(key) else ("Bulkhead" if String(lower_plan.get(key, "")) == "#" else "Cabin floor" if lower_plan.has(key) else "Empty lower deck")
			if key == lower_entry_local:
				desc = "Stairs up to weather deck"
		inspect_box.text = "[b]Lower deck[/b]\n%s\n[color=#8aa0b4]Paint floor and bulkheads; stairs must meet a walkable tile above.[/color]" % desc
		return
	if key == NONE or not cells.has(key):
		var word := "empty sky"
		if key != NONE:
			word = "Empty. Build here." if _touches(key) else "Empty sky."
		var g := ""
		var mid := ""
		var col := Color("#7fd4ff")
		var out := ""
		if module_brush != "":
			mid = module_brush
			g = ShipParts.glyph_for(module_brush)
			col = Color(ShipParts.tier_color(module_brush))
			var m := ShipParts.get_mod(module_brush)
			out = "[color=#8aa0b4]%s[/color]\n[b]%s[/b]  [color=#e8c85a]%s marks[/color]\n%s\n[color=#6a7a8a]Click a matching mounting to fit it.[/color]" % [
				word if key != NONE else "Brush", String(m.get("name", mid)).capitalize(),
				Economy.money(int(m.get("cost", 0))), "  ".join(ShipParts.stat_lines(module_brush))]
		elif brush < BRUSHES.size():
			var br: Dictionary = BRUSHES[brush]
			g = String(br["g"])
			col = Color(String(br["col"])).lightened(0.3)
			out = "[color=#8aa0b4]%s[/color]\n[b][color=%s]%s[/color][/b]  [color=#e8c85a]%s[/color]\n[color=#b8c8d8]%s[/color]" % [
				word if key != NONE else "Brush", col.to_html(false), String(br["name"]),
				("%d marks" % CShipyard.glyph_cost(g)) if g != "" else "free", String(br["hint"])]
		insp_icon.glyph = g
		insp_icon.module = mid
		insp_icon.accent = col
		insp_icon.queue_redraw()
		inspect_box.text = out
		return
	var glyph := String(cells[key])
	var bname := Art.glyph_name(glyph)
	var bcol := "#dbe8f4"
	for br in BRUSHES:
		if String(br["g"]) == glyph:
			bcol = Color(String(br["col"])).lightened(0.3).to_html(false)
	var out2 := "[b][color=%s]%s[/color][/b]   [color=#6a7a8a](%d, %d)[/color]\n" % [bcol, bname, key.x, key.y]
	var mid2 := _module_of(key, glyph)
	if mid2 != "":
		var m2 := ShipParts.get_mod(mid2)
		out2 += "[color=%s]%s[/color]\n[color=#a8c0d4]%s[/color]\n" % [ShipParts.tier_color(mid2),
			String(m2.get("name", mid2)).capitalize(), "  ".join(ShipParts.stat_lines(mid2))]
		var q := ShipParts.quirk_text(mid2)
		if q != "":
			out2 += "[color=#e8a83a]%s[/color]\n" % q
	else:
		var hint := ""
		for br in BRUSHES:
			if String(br["g"]) == glyph:
				hint = String(br["hint"])
		out2 += "[color=#8aa0b4]%s[/color]\n" % hint
	if _sealed.has(key):
		out2 += "[color=#7fd4ff]Sealed: holds air.[/color] "
	if _leaks.has(key):
		out2 += "[color=#ff6a5a]Leaking![/color]"
	insp_icon.glyph = glyph
	insp_icon.module = mid2
	insp_icon.accent = Color(bcol)
	insp_icon.queue_redraw()
	inspect_box.text = out2

func _brush_word() -> String:
	if module_brush != "":
		return "%s (click a matching mounting)" % ShipParts.name_of(module_brush)
	if brush < BRUSHES.size():
		return String(BRUSHES[brush]["name"])
	return "nothing"

# ------------------------------------------------------------------ the numbers
## Everything the panel on the right shows is computed from the drawing by the same code
## that flies a real hull, so what it promises is what you get. The rows are built once
## and told their new targets, which is what lets them slide and show the change.
func _refresh_stats() -> void:
	_geom_dirty = true
	if not _ui_ready:
		return
	var m := _measure()
	_last_m = m
	_rows["mass"].set_value(m["mass"])
	_rows["buoy"].set_value(m["buoy"] * 100.0, _band(m["buoy"], 0.95, 1.45))
	_rows["top"].set_value(m["top"])
	_rows["thrust"].set_value(m["thrust"])
	_rows["sail"].set_value(m["sail"])
	_rows["turn"].set_value(m["turn"])
	_rows["range"].set_value(float(m["range_min"]), "", "—" if String(m["range"]) == "—" else "")
	_rows["cargo"].set_value(m["cargo"])
	_rows["crew"].set_value(float(m["crew"]))
	_rows["armor"].set_value(m["armor"])
	# the verdicts only rebuild when they change, so they do not flicker while you paint
	var diag: Array = m["diag"]
	var ok := ShipPlan.can_build(diag)
	var sig := ""
	for issue in diag:
		sig += String(issue["code"]) + String(issue["text"]) + str(issue["cells"].size())
	if sig != _issue_sig:
		_issue_sig = sig
		_hl_cells = []
		for c in issues_box.get_children():
			c.queue_free()
		for issue in diag:
			var tone: String = {"error": "bad", "warn": "warn", "info": "info"}.get(String(issue["severity"]), "info")
			_stat_note(String(issue["text"]), tone, issue["cells"])
		if diag.is_empty():
			_stat_note("Nothing wrong with her.", "good")
		for q in m["quirks"]:
			_stat_note(String(ShipParts.QUIRKS.get(String(q), q)), "info")
	var price: int = m["price"]
	_bill_target = float(price)
	var purse := Economy.purse(user)
	_block_msg = ""
	if cells.is_empty():
		_block_msg = "Nothing drawn yet."
	elif not ok:
		for issue in diag:
			if String(issue["severity"]) == "error":
				_block_msg = String(issue["text"])
				break
	elif purse < price:
		_block_msg = "You are %s marks short." % Economy.money(price - purse)
	_can_commit = _block_msg == ""
	if commit_btn != null:
		commit_btn.text = ("Commit the refit — %s marks" if mode == "refit" else "Build her — %s marks") % Economy.money(price)
		commit_btn.tooltip_text = _block_msg if not _can_commit else "Hand over the marks and take her out. (Ctrl+Enter)"
	if reason_label != null:
		if _can_commit:
			reason_label.text = "Ready. She will fly."
			reason_label.add_theme_color_override("font_color", UITheme.GOOD)
		else:
			reason_label.text = _block_msg
			reason_label.add_theme_color_override("font_color", UITheme.BAD)
		if _block_msg != _last_reason:
			_last_reason = _block_msg
	if undo_btn != null:
		undo_btn.text = "Undo (%d)" % _undo.size() if not _undo.is_empty() else "Undo"
		redo_btn.text = "Redo (%d)" % _redo.size() if not _redo.is_empty() else "Redo"
	_update_inspector()

## Bill and purse count to their new values, ticking as they go, and go red when they
## cannot cover it.
func _tick_numbers(dt: float) -> void:
	if cost_label == null:
		return
	var purse := float(Economy.purse(user))
	if _purse_shown < 0.0:
		_purse_shown = purse
		_bill_shown = _bill_target
	var before := _bill_shown
	_bill_shown = lerpf(_bill_shown, _bill_target, 1.0 - exp(-10.0 * dt))
	if absf(_bill_shown - _bill_target) < 0.6:
		_bill_shown = _bill_target
	_purse_shown = lerpf(_purse_shown, purse, 1.0 - exp(-8.0 * dt))
	if absf(_purse_shown - purse) < 0.6:
		_purse_shown = purse
	_tick_t -= dt
	if absf(_bill_shown - before) > 4.0 and _tick_t <= 0.0:
		_tick_t = 0.06
		Sfx.play_ui(&"ui_tick", 0.3, 1.0 + clampf((_bill_shown - before) / 400.0, -0.3, 0.5))
	var shown_i := int(round(_bill_shown))
	var affordable := _paid or purse >= _bill_target
	var left := int(round(_purse_shown - (0.0 if _paid else _bill_shown)))
	var pshown := int(round(_purse_shown))
	# text and colour overrides only when the numbers actually moved (an override forces a
	# theme refresh and a relayout of the whole stats column)
	var key := Vector3i(shown_i, pshown, left)
	if key != _num_key or affordable != _num_aff:
		_num_key = key
		var flip := affordable != _num_aff
		_num_aff = affordable
		cost_label.text = "%s marks" % Economy.money(shown_i)
		purse2_label.text = "%s marks" % Economy.money(pshown)
		left_label.text = ("%s marks" % Economy.money(left)) if left >= 0 else ("short %s" % Economy.money(-left))
		purse_label.text = "%s marks" % Economy.money(pshown)
		if flip or not _num_colored:
			_num_colored = true
			cost_label.add_theme_color_override("font_color", UITheme.TEXT if affordable else Color("#ffb0a0"))
			purse2_label.add_theme_color_override("font_color", UITheme.GOOD if affordable else UITheme.BAD)
			purse_label.add_theme_color_override("font_color", Color("#e8c85a") if affordable else Color("#ff7a6a"))
		left_label.add_theme_color_override("font_color", UITheme.GOOD if left >= 0 else UITheme.BAD)
	# the pulse when you cannot afford it is a modulate, which is free
	if not affordable:
		var pl := 1.0 + 0.3 * (0.5 + 0.5 * sin(_time * 6.0))
		purse_label.self_modulate = Color(pl, pl, pl)
	elif purse_label.self_modulate != Color.WHITE:
		purse_label.self_modulate = Color.WHITE

var _num_key := Vector3i(-1, -1, -1)
var _num_aff := false
var _num_colored := false

## The build button breathes when you can afford her, and sulks when you cannot.
func _tick_button(dt: float) -> void:
	_btn_shake = maxf(0.0, _btn_shake - dt * 3.0)
	if _can_commit and not _seq:
		var p := 0.5 + 0.5 * sin(_time * 3.4)
		commit_btn.self_modulate = Color(1.0 + 0.22 * p, 1.0 + 0.14 * p, 1.0 - 0.15 * p)
		commit_btn.scale = Vector2.ONE * (1.0 + 0.025 * p)
		commit_btn.rotation = 0.0
	else:
		commit_btn.self_modulate = Color(0.62, 0.62, 0.68)
		commit_btn.scale = Vector2.ONE
		commit_btn.rotation = sin(_time * 60.0) * 0.03 * _btn_shake

func _band(v: float, lo: float, hi: float) -> String:
	if v < lo * 0.75 or v > hi * 1.2:
		return "bad"
	if v < lo or v > hi:
		return "warn"
	return "good"

## Run the drawing through the real flight model.
func _measure() -> Dictionary:
	var out := {"issues": [], "quirks": []}
	var mass := ShipPlan.mass_of(cells)
	var st := {"thrust": 0.0, "sail": 0.0, "turn": 0.0, "lift_units": 0.0, "fuel_cap": 0.0,
		"cargo": 0.0, "armor": 0.0, "crew": 0.0, "power": 0.0, "steam": 0.0,
		"drag_mul": 1.0, "fuel_mul": 1.0, "mass": 0.0}
	var quirks := {}
	var burn := 0.0
	for key in cells:
		var mid := String(fittings.get(key, ShipParts.default_for(String(cells[key]))))
		if mid == "":
			continue
		var mm := ShipParts.get_mod(mid)
		if mm.is_empty():
			continue
		for k in ["thrust", "sail", "turn", "fuel_cap", "cargo", "armor", "crew", "power", "steam"]:
			st[k] += float(mm.get(k, 0.0))
		st["lift_units"] += float(mm.get("lift", 0.0))
		st["mass"] += float(mm.get("mass", 0.0))
		for k in ["drag_mul", "fuel_mul"]:
			if mm.has(k):
				st[k] *= float(mm[k])
		if mm.has("quirk"):
			quirks[String(mm["quirk"])] = true
		if String(mm.get("cat", "")) == "thruster":
			burn += CThruster.FUEL_PER_SECOND * float(mm.get("fuel_mul", 1.0))
	mass += st["mass"] * 0.5
	out["mass"] = mass
	out["thrust"] = st["thrust"]
	out["sail"] = st["sail"]
	out["cargo"] = st["cargo"] + float(ShipPlan.sealed_of(cells).size()) * 0.35
	out["armor"] = st["armor"]
	out["crew"] = int(st["crew"]) + 2
	out["quirks"] = quirks.keys()
	# lift: cells are rated against the hull, exactly as Airship does it
	var lift := 0.0
	if st["lift_units"] > 0.0:
		lift = mass * Airship.DESIGN_LIFT
	out["buoy"] = lift / maxf(1.0, mass)
	# top speed from the same quadratic the flight model solves
	var t: float = st["thrust"]
	if t > 0.0:
		var a: float = Airship.DRAG * mass * st["drag_mul"]
		var bq: float = Airship.DRAG_LINEAR * mass * st["drag_mul"]
		out["top"] = (-bq + sqrt(bq * bq + 4.0 * a * t)) / (2.0 * a)
	else:
		out["top"] = 0.0
	# turn rate, same formula
	var turn: float = Airship.TURN_RATE * (110.0 / maxf(1.0, mass)) + st["turn"]
	if t > 0.0:
		turn *= 1.25
	out["turn"] = clampf(turn, 0.16, 2.6)
	# range
	if burn <= 0.001 or st["fuel_cap"] <= 0.0:
		out["range"] = "—"
		out["range_min"] = 0
	else:
		var secs: float = st["fuel_cap"] / burn
		out["range"] = "%d min at full" % maxi(1, int(secs / 60.0))
		out["range_min"] = maxi(1, int(secs / 60.0))
	out["diag"] = ShipPlan.diagnose(cells, fittings, {"who": user})
	if not lower_plan.is_empty():
		var lb := ShipPlan.bounds(lower_plan)
		var problem := ""
		if lb.size.x > 30 or lb.size.y > 30:
			problem = "Lower deck must fit in a 30 by 30 tile berth."
		elif not lower_plan.has(lower_entry_local) or String(lower_plan.get(lower_entry_local, "")) != "=":
			problem = "Place stairs on the lower deck."
		elif not String(cells.get(lower_entry_local, "")) in [",", "=", "+", "A", "h", "n"]:
			problem = "Stairs must meet a walkable tile above."
		else:
			for k in lower_plan:
				if not cells.has(k):
					problem = "Lower deck extends beyond the hull."
					break
		if problem != "":
			out["diag"].append({"severity": "error", "code": "lower_deck", "text": problem, "cells": []})
	out["diag"].append_array(ShipSurvey.diagnose(cells, lower_plan, lower_entry_local))
	out["price"] = _price(st)
	_check(out, st, quirks)
	return out

func _price(st: Dictionary) -> int:
	var markup: float = 1.0
	if mode == "refit":
		markup = CShipyard.YARD_DISCOUNT
	if mode == "refit" and ship != null:
		var grade := int(ship.hull.get("grade", 1)) if ship.hull is Dictionary else 1
		var q := CShipyard.refit_quote(ship.cells_map, ship.effective_fittings(), cells, fittings, user, markup, grade)
		return int(q["price"]) + maxi(0, lower_plan.size() - ship.lower_plan.size()) * 6
	return CShipyard.plan_price(cells, fittings, user, markup) + lower_plan.size() * 6

## Everything that would stop her flying, or stop her being pleasant to fly, said plainly.
func _check(out: Dictionary, st: Dictionary, quirks: Dictionary) -> void:
	var issues: Array = out["issues"]
	var glyphs := {}
	for key in cells:
		var g := String(cells[key])
		glyphs[g] = int(glyphs.get(g, 0)) + 1
	if cells.is_empty():
		issues.append(["Nothing drawn yet.", "bad"])
		return
	if not _connected():
		issues.append(["She is in two pieces. Every tile has to join the rest.", "bad"])
	if int(glyphs.get("h", 0)) == 0:
		issues.append(["No helm. Nobody can steer her.", "bad"])
	elif int(glyphs.get("h", 0)) > 1:
		issues.append(["More than one wheel. Only the first will answer.", "warn"])
	if st["lift_units"] <= 0.0:
		issues.append(["No lift cells. She is a shed.", "bad"])
	if st["thrust"] <= 0.0 and st["sail"] <= 0.0:
		issues.append(["Nothing to move her. Fit a thruster or a mast.", "bad"])
	if int(glyphs.get("B", 0)) == 0 and st["thrust"] > 0.0:
		issues.append(["Thrusters and no boiler. The injectors need steam.", "bad"])
	if int(glyphs.get("T", 0)) == 0 and st["thrust"] > 0.0:
		issues.append(["No bunker. Nowhere to keep the fuel.", "bad"])
	var walkable := 0
	for key in cells:
		if not ShipPlan.is_dense(String(cells[key])):
			walkable += 1
	if walkable < 3:
		issues.append(["Almost nowhere to stand. A crew needs deck.", "warn"])
	var leaks := ShipPlan.leaks_of(cells)
	if not leaks.is_empty():
		issues.append(["%d cabin tile%s still open to the weather — press L to see them." % [
			leaks.size(), "" if leaks.size() == 1 else "s"], "warn"])
	if out["buoy"] < 0.7:
		issues.append(["Far too heavy for her cells. She will not leave the ground.", "bad"])
	elif out["buoy"] > 1.9:
		issues.append(["Wildly over-lifted. Ballast will not hold her down.", "warn"])
	# the things that are merely unwise
	if _engine_indoors() and int(glyphs.get("s", 0)) == 0 and int(glyphs.get("v", 0)) == 0:
		issues.append(["An engine in a sealed space with no scrubber. It will cook the crew.", "warn"])
	if _bunker_by_boiler():
		issues.append(["A bunker up against the boiler. This has been done before. It went badly.", "warn"])
	if st["power"] < 0.0:
		issues.append(["More draw than the dynamo makes. Something will not run.", "warn"])
	if int(glyphs.get("*", 0)) == 0:
		issues.append(["No lantern. Night at altitude is very dark.", "warn"])

func _connected() -> bool:
	if cells.is_empty():
		return true
	var start: Vector2i = cells.keys()[0]
	var seen := {start: true}
	var q := [start]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in Defs.DIRS4:
			var n: Vector2i = c + d
			if cells.has(n) and not seen.has(n):
				seen[n] = true
				q.append(n)
	return seen.size() == cells.size()

func _engine_indoors() -> bool:
	var sealed := ShipPlan.sealed_of(cells)
	for key in cells:
		if String(cells[key]) in ["E", "B"] and sealed.has(key):
			return true
	return false

func _bunker_by_boiler() -> bool:
	for key in cells:
		if String(cells[key]) != "T":
			continue
		for d in Defs.DIRS8:
			if String(cells.get(key + d, "")) == "B":
				return true
	return false

# ------------------------------------------------------------------ committing
## Press the button. If she cannot be built, say why and shake; if she can, the shipwright
## sets out the papers, and only when they are stamped does anything become real.
func _commit(instant := false) -> void:
	if _seq or _closing:
		return
	var m := _measure()
	var price: int = m["price"]
	_refresh_stats()
	if not _can_commit:
		_btn_shake = 1.0
		Sfx.play_ui(&"ui_deny")
		_say(_block_msg)
		if not _leaks.is_empty() and _block_msg == "":
			show_leaks = true
		return
	if mode != "refit" and yard != null and Mooring.plan(cells, yard.berth, Defs.DIRS4[yard.berth_dir]).is_empty():
		# no berth where a person could walk aboard her: say so before any money moves
		_btn_shake = 1.0
		Sfx.play_ui(&"ui_deny")
		_say("No berth here can take her: there is no way to walk aboard. Leave open deck or a single plank of bulwark on her side, or make her smaller.")
		return
	if instant:
		_commit_now(price)
		return
	_begin_stamp(price)

func _chosen_name() -> String:
	var nm := name_edit.text.strip_edges() if name_edit != null else ""
	if nm == "":
		nm = _pick_name()
	return nm

func _begin_stamp(price: int) -> void:
	_seq = true
	_seq_t = 0.0
	_seq_stage = 0
	_seq_price = price
	_seq_name = _chosen_name()
	_paid = false
	_stamp_parts.clear()
	if name_edit != null:
		name_edit.release_focus()
	_stamp_layer = Control.new()
	_stamp_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_stamp_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stamp_layer.draw.connect(_draw_stamp)
	add_child(_stamp_layer)
	Sfx.play_ui(&"ui_whoosh")

func _abort_seq() -> void:
	_seq = false
	if _stamp_layer != null:
		_stamp_layer.queue_free()
		_stamp_layer = null

func _tick_seq(dt: float) -> void:
	var spd := 1.0 if mode != "refit" else 1.35
	if _demo == "hold" and _seq_t > 1.2:
		spd = 0.0
	_seq_t += dt * spd
	_shake = maxf(0.0, _shake - dt * 4.0)
	for p in _stamp_parts:
		p["life"] = float(p["life"]) - dt
		p["v"] = Vector2(p["v"]) + Vector2(0, 900.0) * dt
		p["p"] = Vector2(p["p"]) + Vector2(p["v"]) * dt
	_stamp_parts = _stamp_parts.filter(func(p): return float(p["life"]) > 0.0)
	if _seq_stage == 0 and _seq_t >= 0.62:
		# the stamp lands: money changes hands here, so it is the moment it hurts
		_seq_stage = 1
		if not Economy.take(user, _seq_price):
			Game.tell(user, "[color=#ff6a6a]You cannot pay for that.[/color]", "warn")
			Sfx.play_ui(&"ui_deny")
			_abort_seq()
			return
		_paid = true
		_shake = 1.0
		Sfx.play_ui(&"ui_confirm")
		Sfx.play_ui(&"ui_coin", 0.9)
		var c := _stamp_layer.size * 0.5 + Vector2(90, 70)
		for i in 26:
			var a := randf() * TAU
			var sp := randf_range(120.0, 460.0)
			var life := randf_range(0.4, 0.9)
			_stamp_parts.append({"p": c, "v": Vector2(cos(a), sin(a) - 0.6) * sp, "life": life, "max": life,
				"col": Color("#e8dcc0") if i % 3 != 0 else Color("#c0392b"), "sz": randf_range(3.0, 7.0)})
	elif _seq_stage == 1 and _seq_t >= 1.5:
		_seq_stage = 2
		Sfx.play_ui(&"ui_launch" if mode != "refit" else &"ui_purchase")
		_screen_flash()
	elif _seq_stage == 2 and _seq_t >= 1.78:
		_seq_stage = 3
		_commit_now(_seq_price)
		return
	if _stamp_layer != null:
		_stamp_layer.queue_redraw()

func _screen_flash() -> void:
	if Game.hud == null or Game.hud.root == null:
		return
	var fl := ColorRect.new()
	fl.color = Color(1.0, 0.96, 0.85, 0.95)
	fl.set_anchors_preset(Control.PRESET_FULL_RECT)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.hud.root.add_child(fl)
	var tw := fl.create_tween()
	tw.tween_property(fl, "color:a", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(fl.queue_free)

## The shipwright's order of work, laid on the desk, and the stamp that makes it so.
func _draw_stamp() -> void:
	var L := _stamp_layer
	if L == null:
		return
	var f := UITheme.font
	var sz := L.size
	var t := _seq_t
	L.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, clampf(t / 0.3, 0.0, 1.0) * 0.68))
	var e := 1.0 - pow(1.0 - clampf(t / 0.45, 0.0, 1.0), 3.0)
	var cw := 500.0
	var ch := 330.0
	var sh := Vector2(sin(_time * 90.0), cos(_time * 77.0)) * 7.0 * _shake
	var ctr := sz * 0.5 + Vector2(0, (1.0 - e) * 260.0) + sh
	var card := Rect2(ctr - Vector2(cw, ch) * 0.5, Vector2(cw, ch))
	L.draw_rect(Rect2(card.position + Vector2(6, 8), card.size), Color(0, 0, 0, 0.45 * e))
	L.draw_rect(card, Color("#e8dcc0"))
	L.draw_rect(card, Color("#8a6a3a"), false, 4.0)
	var ink := Color("#3a2a18")
	var head := "SHIPWRIGHT'S ORDER OF WORK" if mode != "refit" else "ORDER OF REFIT"
	L.draw_string(f, card.position + Vector2(0, 46), head, HORIZONTAL_ALIGNMENT_CENTER, cw, 26, ink)
	L.draw_line(card.position + Vector2(30, 60), card.position + Vector2(cw - 30, 60), ink, 2.0)
	var y := 100.0
	var rows := [["Vessel", _seq_name], ["Pieces", "%d tiles, %d fittings" % [cells.size(), fittings.size()]],
		["Crew", "%d berths" % int(_last_m.get("crew", 2))], ["Price", "%s marks" % Economy.money(_seq_price)]]
	for r in rows:
		L.draw_string(f, card.position + Vector2(34, y), String(r[0]) + ":", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink.lightened(0.3))
		L.draw_string(f, card.position + Vector2(150, y), String(r[1]), HORIZONTAL_ALIGNMENT_LEFT, cw - 180.0, 21, ink)
		L.draw_line(card.position + Vector2(148, y + 6), card.position + Vector2(cw - 34, y + 6), ink.lightened(0.55), 1.0)
		y += 38.0
	# the signature, scribbled in with a pen
	var sp := clampf((t - 0.3) / 0.28, 0.0, 1.0)
	var pts := PackedVector2Array()
	var n := int(40.0 * sp)
	for i in n:
		var u := float(i) / 40.0
		pts.append(card.position + Vector2(40.0 + u * 190.0, ch - 58.0 + sin(u * 22.0) * 9.0 * (1.0 - u * 0.5) - u * 6.0))
	if pts.size() > 1:
		L.draw_polyline(pts, Color("#1a2a5a"), 2.0)
	L.draw_string(f, card.position + Vector2(34, ch - 22), "Master shipwright", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink.lightened(0.4))
	# the stamp
	if t >= 0.62:
		var st := t - 0.62
		var s := lerpf(3.2, 1.0, 1.0 - pow(1.0 - clampf(st / 0.11, 0.0, 1.0), 3.0))
		var al := clampf(st / 0.05, 0.0, 1.0)
		var word := "APPROVED" if mode != "refit" else "PAID"
		var c := card.position + Vector2(cw - 150.0, ch - 90.0)
		L.draw_set_transform(c, -0.21, Vector2(s, s))
		var wd := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
		var red := Color("#c0392b", al * 0.92)
		L.draw_rect(Rect2(Vector2(-wd * 0.5 - 14, -34), Vector2(wd + 28, 56)), red, false, 5.0)
		L.draw_rect(Rect2(Vector2(-wd * 0.5 - 8, -28), Vector2(wd + 16, 44)), red, false, 2.0)
		L.draw_string(f, Vector2(-wd * 0.5, 6), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, red)
		L.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for p in _stamp_parts:
		var pa := clampf(float(p["life"]) / float(p["max"]), 0.0, 1.0)
		var ps: float = float(p["sz"])
		L.draw_rect(Rect2(Vector2(p["p"]) - Vector2(ps, ps) * 0.5, Vector2(ps, ps)), Color(p["col"], pa))
	if t > 1.5:
		var fa := clampf((t - 1.5) / 0.2, 0.0, 1.0) * 0.0
		L.draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 0.97, 0.88, fa))

func _commit_now(price: int) -> void:
	var took_here := false
	if not _paid:
		if not Economy.take(user, price):
			Game.tell(user, "[color=#ff6a6a]You cannot pay for that.[/color]", "warn")
			_abort_seq()
			return
		took_here = true
	if mode == "refit" and ship != null:
		_apply_refit()
		var nm := name_edit.text.strip_edges() if name_edit != null else ""
		if nm != "" and nm != ship.ship_name:
			ship.ship_name = nm
		Game.tell(user, "[color=#6ad88a]The yard works through the night. %s is refitted.[/color]" % ship.ship_name, "good")
		Bus.chronicle.emit("%s was refitted at a cost of %s marks." % [ship.ship_name, Economy.money(price)], 2)
		Skills.add_xp(user, "shipwright", 60.0)
		queue_free()
		return
	if not _launch_new():
		# the berth was full: give her the money back and let her try again
		if _paid or took_here:
			Economy.give(user, price)
			_paid = false
		_abort_seq()
		return

func _apply_refit() -> void:
	# remove what has gone, then lay in what is new, then swap the modules
	if not ship.lower_cells.is_empty():
		if Game.player != null and ship.lower_cells.has(Game.player.cell):
			Game.player.place(ship.cell(ship.upper_stair_local.x, ship.upper_stair_local.y))
		Underdecks.clear(ship)
	for key in ship.cells_map.keys():
		if not cells.has(key):
			ship.set_piece(key, "")
	for key in cells:
		if String(ship.cells_map.get(key, "")) != String(cells[key]):
			ship.set_piece(key, String(cells[key]))
	for key in fittings:
		if ship.cells_map.has(key):
			ship.set_module(key, String(fittings[key]))
	ship.mark_dirty()
	ship.lower_plan = lower_plan.duplicate(true)
	ship.lower_entry_local = lower_entry_local
	Underdecks.ensure(ship)


## Returns false if there was no room in the berth. Otherwise she is laid down, fuelled
## and floated, and the yard closes.
func _launch_new() -> bool:
	var name_in := _chosen_name()
	var sh := _stamp_custom(name_in)
	if sh == null:
		Game.tell(user, "[color=#ff6a6a]There is no room in the berth. Clear the moorings and try again.[/color]", "warn")
		return false
	Game.fleet.player_ship = sh
	for b in sh.bunkers:
		var fb: CFuelBunker = b.c(&"fuelbunker")
		if fb != null:
			fb.amount = fb.capacity
	for l in sh.lift_cells:
		var lc: CLiftCell = l.c(&"liftcell")
		if lc != null:
			lc.charge = 1.0
	Game.msg("[b][color=#6ad88a]%s is yours. She is fuelled, her cells are full and her boiler is cold.[/color][/b]" % sh.ship_name, "good")
	Game.msg("[i]Walk to the boiler, light it, take the wheel, and open the throttle.[/i]", "info")
	Bus.chronicle.emit("%s was launched out of the Meridian yard." % sh.ship_name, 1)
	Skills.add_xp(user, "shipwright", 140.0)
	queue_free()
	return true

## Screenshot driver: `--yarddemo` paints and erases a stroke on a loop, `--yarddemo=stamp`
## presses Build after a few seconds. It exists so a still image can show the effects.
func _tick_demo(dt: float) -> void:
	if _demo == "" or _seq or _closing or canvas == null:
		return
	_demo_t += dt
	if _demo in ["modules", "book"] and palette_tab != _demo:
		_set_tab(_demo)
	if _demo == "stamp" or _demo == "launch":
		if _demo_t > 1.0:
			_commit()
			_demo = "hold" if _demo == "stamp" else ""
		return
	if _demo_t < 1.0:
		return
	var step := int((_demo_t - 1.0) / 0.16)
	if step == _demo_n:
		return
	_demo_n = step
	var cyc := step % 26
	var x := cyc - 6 if cyc < 13 else cyc - 19
	brush = 1 if cyc < 13 else 2
	module_brush = ""
	var erase := cyc >= 13 and step % 52 >= 26
	if step == 10:
		show_leaks = true
		_geom_dirty = true
	_hover = Vector2i(x, 4)
	if cyc == 0:
		_push_undo()
		_stroke_n = 0
	_painting = 2 if erase else 1
	_apply_brush(_hover, erase)
	_painting = 0
	_sync_tiles()
	_update_inspector()

## Lay a drawn hull into the yard's berth. It goes through the same Airship.stamp() as a
## hull out of the book, because there is no reason for it to be a different ship.
func _stamp_custom(nm: String) -> Airship:
	if yard != null:
		# a berth from which a person can walk from the quay onto her deck (see Mooring)
		var out_v: Vector2i = Defs.DIRS4[yard.berth_dir]
		var spot := Mooring.plan(cells, yard.berth, out_v)
		if spot.is_empty():
			return null
		return _make(nm, spot["origin"], int(spot["dir"]))
	var berth := Vector2i(SkyGen.W / 2, SkyGen.H / 2)
	var dir: int = Defs.DIR_E
	var b := ShipPlan.bounds(cells)
	var fwd: Vector2i = Defs.DIRS4[dir]
	var out := Vector2i(-fwd.y, fwd.x)
	var base := berth - fwd * (b.position.x + b.size.x / 2)
	for back in range(1, 20):
		var sh := _make(nm, base + out * back, dir)
		if sh != null:
			return sh
	return null

func _make(nm: String, where: Vector2i, dir: int) -> Airship:
	var sh := Airship.new()
	sh.hull_id = "custom"
	sh.hull = {"kind": "custom", "name": "custom hull", "tier": 1, "crew": 2,
		"desc": "Drawn on a board in Meridian and built to the drawing.", "plan": [], "keel": 0}
	sh.plan = []
	sh.keel = 0
	sh.cells_map = cells.duplicate(true)
	sh.fittings = fittings.duplicate(true)
	sh.lower_plan = lower_plan.duplicate(true)
	sh.lower_entry_local = lower_entry_local
	sh.ship_name = nm
	sh.mark_dirty()
	sh.id = Game.fleet._next_id
	Game.fleet._next_id += 1
	if not sh.stamp(where, dir):
		return null
	sh.altitude = Game.sky.gen.altitude if Game.sky != null and Game.sky.gen != null else Defs.ALT_LOW
	Game.fleet.ships.append(sh)
	var r := ShipRenderer.new()
	r.setup(sh)
	sh.renderer = r
	if Game.view != null:
		Game.view.add_child(r)
	Game.fleet.rebuild_tile_index()
	return sh

const NAMES_A = ["Kestrel", "Marigold", "Long Answer", "Perseverance", "Quiet Word", "Saltbird",
	"Thin Excuse", "Gannet", "Fair Warning", "Corvid", "Late Again", "Wager", "Orison",
	"Pale Horse", "Second Thought", "Bellwether", "Tern", "Unlikely", "Recompense", "Sparrowhawk"]

static func _random_name() -> String:
	return NAMES_A[Game.rng.randi() % NAMES_A.size()]
