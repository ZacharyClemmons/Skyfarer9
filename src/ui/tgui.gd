class_name TGUI
## The pieces tg's tgui builds every machine screen from, in our theme: titled Sections,
## LabeledLists (dim label, bright value, lined up), ProgressBars coloured good / average /
## bad by range, a gas-mix bar, Tables with real columns, NoticeBoxes and Buttons that show
## when they're selected. One font throughout; numbers never float about in a text blob.

const GOOD := Color("#5ad87a")
const AVERAGE := Color("#e8b83a")
const BAD := Color("#e8483a")
const INFO := Color("#5ab8e8")
const LABEL := Color("#8aa0b4")

## tg-ish gas colours, indexed like Defs.GAS_NAMES.
## Gas colours for the UI, indexed like Defs.GAS_NAMES: the first eight tuned to read well
## on the dark panels, the rest tg's primary_color brightened a touch.
const GAS_COLORS := [Color("#5a9aff"), Color("#e8604a"), Color("#8a929e"), Color("#c85aff"),
	Color("#f0e0e8"), Color("#5ad8e8"), Color("#4a4a52"), Color("#5ae86a"),
	Color("#3ad8c8"), Color("#c8603a"), Color("#a98ae8"), Color("#8a7aff"),
	Color("#a8a83a"), Color("#bff4f4"), Color("#f4f4f4"), Color("#ff9a8a"),
	Color("#c8ff5a"), Color("#3aa84a"), Color("#c85ac8"), Color("#e8f4ff"), Color("#c83a4a")]
const GAS_SHORT := Defs.GAS_SHORT

# ------------------------------------------------------------------ layout
## A titled section. Returns the box to put its contents in. `right` controls sit in the
## header's right end (tg Section buttons).
static func section(parent: Control, title: String, right: Array = []) -> VBoxContainer:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	parent.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var t := UITheme.label(title, UITheme.BODY, UITheme.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	for c in right:
		head.add_child(c)
	var line := ColorRect.new()
	line.color = Color(UITheme.ACCENT, 0.25)
	line.custom_minimum_size = Vector2(0, 1)
	outer.add_child(line)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	outer.add_child(m)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	m.add_child(body)
	return body

## tg LabeledList: returns a two-column grid for item() / item_ctrl().
static func list(parent: Control) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 4)
	parent.add_child(g)
	return g

static func item(grid: GridContainer, label: String, value: String, color := UITheme.TEXT) -> Label:
	var l := UITheme.label(label, UITheme.SMALL, LABEL)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(l)
	var v := UITheme.label(value, UITheme.BODY, color)
	grid.add_child(v)
	return v

## A labelled row whose value is any control (a bar, a set of buttons).
static func item_ctrl(grid: GridContainer, label: String, ctrl: Control) -> Control:
	var l := UITheme.label(label, UITheme.SMALL, LABEL)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(ctrl)
	return ctrl

## A horizontal row; with no parent it's returned loose, to hand to item_ctrl().
static func row(parent: Control, sep := 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	if parent:
		parent.add_child(h)
	return h

## tg Table: a grid with a header row. Fill it with cell() / cell_ctrl(), row by row.
static func table(parent: Control, headers: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = headers.size()
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 3)
	parent.add_child(g)
	for h in headers:
		g.add_child(UITheme.label(str(h).to_upper(), UITheme.SMALL, LABEL))
	return g

static func cell(grid: GridContainer, text: String, color := UITheme.TEXT, size := UITheme.SMALL) -> Label:
	var l := UITheme.label(text, size, color)
	grid.add_child(l)
	return l

static func cell_ctrl(grid: GridContainer, c: Control) -> Control:
	grid.add_child(c)
	return c

## tg NoticeBox: a tinted strip with a message. level: info / good / warn / bad.
static func notice(parent: Control, text: String, level := "info") -> PanelContainer:
	var col: Color = {"info": INFO, "good": GOOD, "warn": AVERAGE, "bad": BAD}.get(level, INFO)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.16)
	sb.border_color = col
	sb.border_width_left = 3
	sb.content_margin_left = 10
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	var l := UITheme.label(text, UITheme.SMALL, col.lerp(Color.WHITE, 0.35))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	parent.add_child(p)
	return p

## A button; `selected` shows it lit (tg Button selected), `tone` colours its text.
static func button(parent: Control, text: String, cb: Callable, selected := false, disabled := false, tone := Color(0, 0, 0, 0)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	b.disabled = disabled
	b.set_meta("ui_selected", selected)
	if selected:
		b.toggle_mode = true
		b.set_pressed_no_signal(true)
		b.add_theme_color_override("font_color", UITheme.ACCENT)
		b.add_theme_color_override("font_pressed_color", UITheme.ACCENT)
		b.add_theme_color_override("font_hover_pressed_color", UITheme.ACCENT)
		# a locked control still shows which setting it's on
		b.add_theme_color_override("font_disabled_color", Color(UITheme.ACCENT, 0.75))
		# lit like tg's selected buttons: a tinted face and a bright edge
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(UITheme.ACCENT, 0.24 if st != "disabled" else 0.14)
			sb.border_color = Color(UITheme.ACCENT, 0.9 if st != "disabled" else 0.5)
			sb.set_border_width_all(1)
			sb.content_margin_left = 10
			sb.content_margin_right = 10
			sb.content_margin_top = 4
			sb.content_margin_bottom = 4
			b.add_theme_stylebox_override(st, sb)
	if tone.a > 0:
		b.add_theme_color_override("font_color", tone)
		b.add_theme_color_override("font_pressed_color", tone)
	parent.add_child(b)
	return b

## A set of mutually exclusive buttons (Auto / On / Off...); the current one is lit.
static func choice(parent: Control, options: Array, current, cb: Callable, disabled := false) -> HBoxContainer:
	var r := row(parent, 3)
	for o in options:
		var val = o[1] if o is Array else o
		var txt: String = o[0] if o is Array else str(o)
		button(r, txt, func(): cb.call(val), val == current, disabled)
	return r

## "- value +" with coarse and fine steps; `fmt` formats the value.
static func stepper(parent: Control, value: float, steps: Array, fmt: String, cb: Callable, disabled := false) -> HBoxContainer:
	var r := row(parent, 3)
	var half := steps.size() / 2
	for i in steps.size():
		if i == half:
			var v := UITheme.label(fmt % value, UITheme.BODY, UITheme.ACCENT)
			v.custom_minimum_size = Vector2(92, 0)
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			r.add_child(v)
		var s = steps[i]
		button(r, s[0], func(): cb.call(s[1]), false, disabled)
	return r

# ------------------------------------------------------------------ status text
static func onoff(on: bool, on_txt := "On", off_txt := "Off") -> Array:
	return [on_txt, GOOD] if on else [off_txt, BAD]

## good / average / bad by where `v` sits: `good` and `average` are [lo, hi] ranges.
static func ranged(v: float, good: Array, average: Array) -> Color:
	if v >= good[0] and v <= good[1]:
		return GOOD
	if v >= average[0] and v <= average[1]:
		return AVERAGE
	return BAD

static func kpa(p: float) -> String:
	return ("%.1f kPa" % p) if p < 1000.0 else ("%s kPa" % _thousands(roundi(p)))

static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

static func kelvin(t: float) -> String:
	return "%.0f K (%.0f°C)" % [t, t - Defs.T0C]

static func kw(w: float) -> String:
	return ("%.0f W" % w) if absf(w) < 1000.0 else ("%.1f kW" % (w / 1000.0))

# ------------------------------------------------------------------ bars
## tg ProgressBar: fills to value/max, coloured, with its reading written on it.
class Bar extends Control:
	var frac := 0.0
	var col := GOOD
	var text := "" # (also what the window's change-detection reads)

	func _init(f: float, c: Color, t: String) -> void:
		frac = clampf(f, 0.0, 1.0)
		col = c
		text = t
		custom_minimum_size = Vector2(120, 18)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.02, 0.03, 0.05, 0.9))
		draw_rect(r, Color(col, 0.55), false, 1.0)
		if frac > 0.0:
			var fr := Rect2(Vector2(1, 1), Vector2((size.x - 2) * frac, size.y - 2))
			draw_rect(fr, Color(col, 0.55))
			draw_rect(Rect2(fr.position, Vector2(fr.size.x, 2)), Color(col.lerp(Color.WHITE, 0.4), 0.7))
		if text != "":
			var f := UITheme.font
			var fs := UITheme.SMALL
			var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := Vector2((size.x - tw) * 0.5, size.y * 0.5 + fs * 0.36)
			draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
			draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

static func bar(value: float, maxv: float, text: String, color := GOOD) -> Bar:
	return Bar.new(value / maxv if maxv > 0.0 else 0.0, color, text)

## A bar coloured by where value sits in tg-style good / average ranges.
static func ranged_bar(value: float, maxv: float, text: String, good: Array, average: Array) -> Bar:
	return bar(value, maxv, text, ranged(value, good, average))

## The gas mix as one stacked bar (each gas its colour, width by share), and a legend.
class GasBar extends Control:
	var parts: Array = [] # [fraction, colour]
	var text := ""

	func _init(p: Array, t: String) -> void:
		parts = p
		text = t
		custom_minimum_size = Vector2(160, 14)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.02, 0.03, 0.05, 0.9))
		var x := 1.0
		for p in parts:
			var w: float = (size.x - 2) * p[0]
			draw_rect(Rect2(Vector2(x, 1), Vector2(w, size.y - 2)), Color(p[1], 0.85))
			draw_rect(Rect2(Vector2(x, 1), Vector2(w, 2)), Color(p[1].lerp(Color.WHITE, 0.45), 0.85))
			x += w
		draw_rect(r, Color(1, 1, 1, 0.15), false, 1.0)

## Gas breakdown in the tg GasmixParser's spirit: a stacked bar, then each gas with its
## share and moles. `gas` is moles per gas (Defs order).
static func gasmix(parent: Control, gas, min_share := 0.001) -> void:
	var tot := 0.0
	for g in Defs.GAS_COUNT:
		tot += gas[g]
	if tot < 0.001:
		parent.add_child(UITheme.label("No gas detected.", UITheme.SMALL, LABEL))
		return
	var parts := []
	var names := []
	var order := range(Defs.GAS_COUNT)
	order.sort_custom(func(a, b): return gas[a] > gas[b])
	for g in order:
		var f: float = gas[g] / tot
		if f >= min_share:
			parts.append([f, GAS_COLORS[g]])
			names.append(g)
	var sig := ""
	for g in names:
		sig += "%s%d " % [GAS_SHORT[g], roundi(gas[g] / tot * 100.0)]
	parent.add_child(GasBar.new(parts, sig))
	var t := GridContainer.new()
	t.columns = 3
	t.add_theme_constant_override("h_separation", 14)
	t.add_theme_constant_override("v_separation", 2)
	parent.add_child(t)
	for g in names:
		var sw := ColorRect.new()
		sw.color = GAS_COLORS[g]
		sw.custom_minimum_size = Vector2(10, 10)
		var nm := HBoxContainer.new()
		nm.add_theme_constant_override("separation", 6)
		var cc := CenterContainer.new()
		cc.add_child(sw)
		nm.add_child(cc)
		nm.add_child(UITheme.label(Defs.GAS_NAMES[g], UITheme.SMALL))
		t.add_child(nm)
		var pct := UITheme.label("%.1f%%" % (gas[g] / tot * 100.0), UITheme.SMALL, UITheme.TEXT)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		t.add_child(pct)
		t.add_child(UITheme.label("%.1f mol" % gas[g], UITheme.SMALL, LABEL))

# ------------------------------------------------------------------ number input
## tg NumberInput: shows "101 kPa"; drag left / right across it to change the value (one
## step every few pixels), scroll the wheel over it, or click and type a number and press
## Enter. `on_set` gets the new value, already clamped.
class NumberInput extends LineEdit:
	var value := 0.0
	var minv := 0.0
	var maxv := 100.0
	var step := 1.0
	var unit := ""
	var decimals := 0
	var on_set: Callable
	var _press_x := 0.0
	var _press_v := 0.0
	var _dragging := false
	var _down := false

	func _init(v: float, lo: float, hi: float, st: float, u: String, cb: Callable, dec := 0) -> void:
		value = v
		minv = lo
		maxv = hi
		step = st
		unit = u
		on_set = cb
		decimals = dec
		custom_minimum_size = Vector2(96, 0)
		alignment = HORIZONTAL_ALIGNMENT_CENTER
		mouse_default_cursor_shape = Control.CURSOR_HSIZE
		tooltip_text = "Drag left or right, scroll, or click and type a value."
		add_theme_color_override("font_color", UITheme.ACCENT)
		_show()
		text_submitted.connect(func(t):
			_commit_text(t)
			release_focus())
		focus_exited.connect(func(): _commit_text(text))
		focus_entered.connect(func():
			text = _fmt(value)
			select_all())

	func _fmt(v: float) -> String:
		return ("%." + str(decimals) + "f") % v

	func _show() -> void:
		text = "%s %s" % [_fmt(value), unit] if unit != "" else _fmt(value)

	func _commit_text(t: String) -> void:
		var num := t.strip_edges().split(" ")[0]
		if num.is_valid_float():
			_apply(num.to_float())
		_show()

	func _apply(v: float) -> void:
		v = clampf(snappedf(v, step) if step > 0 else v, minv, maxv)
		if not is_equal_approx(v, value):
			value = v
			if on_set.is_valid():
				on_set.call(v)
		_show()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
				_apply(value + step)
				accept_event()
			elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
				_apply(value - step)
				accept_event()
			elif ev.button_index == MOUSE_BUTTON_LEFT:
				if ev.pressed:
					_down = true
					_dragging = false
					_press_x = ev.position.x
					_press_v = value
				else:
					_down = false
					if _dragging:
						_dragging = false
						release_focus()
						accept_event()
		elif ev is InputEventMouseMotion and _down:
			var dx: float = ev.position.x - _press_x
			if absf(dx) > 4.0:
				_dragging = true
			if _dragging:
				var steps := roundi(dx / 4.0)
				var v := clampf(_press_v + steps * step, minv, maxv)
				value = v
				_show()
				if on_set.is_valid():
					on_set.call(v)
				accept_event()

## A NumberInput with a Max button beside it (tg's layout for pressures and rates).
static func number(value: float, lo: float, hi: float, step: float, unit: String, cb: Callable, with_max := true, disabled := false, dec := 0) -> HBoxContainer:
	var r := row(null, 6)
	var n := NumberInput.new(value, lo, hi, step, unit, cb, dec)
	n.editable = not disabled
	r.add_child(n)
	if with_max:
		button(r, "Max", func(): cb.call(hi), false, disabled or is_equal_approx(value, hi))
	return r

# ------------------------------------------------------------------ port diagram
## A little schematic of an inline atmos machine: its input, itself, its output (and a
## side port for filters and mixers), each port with its pressure and what's in it, and
## arrows showing which way gas goes and whether it's moving right now.
class PortDiagram extends Control:
	var ports := [] # [{name, net, role: "in" / "out" / "side_in" / "side_out"}]
	var device := ""
	var moving := 0.0
	var on := true
	var text := "" # change detection

	func _init(dev: String, p: Array, mv: float, is_on: bool) -> void:
		device = dev
		ports = p
		moving = mv
		on = is_on
		custom_minimum_size = Vector2(0, 150 if _has_side() else 96)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for q in ports:
			text += "%s%s " % [q["name"], TGUI.kpa(q["net"].pressure()) if q["net"] else "-"]
		text += "%.2f%s" % [mv, is_on]

	func _has_side() -> bool:
		for q in ports:
			if q["role"].begins_with("side"):
				return true
		return false

	func _box(r: Rect2, q: Dictionary) -> void:
		var n = q["net"]
		var col: Color = UITheme.DIM
		if n and n.total_moles() > 0.01:
			col = AtmosOverlay._net_color(n)
		draw_rect(r, Color(0.03, 0.05, 0.08, 0.9))
		draw_rect(r, Color(col, 0.8), false, 1.5)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(col, 0.8))
		var f := UITheme.font
		draw_string(f, r.position + Vector2(8, 18), q["name"].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 12, TGUI.LABEL)
		if n == null:
			draw_string(f, r.position + Vector2(8, 38), "not connected", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 13, TGUI.LABEL)
			return
		draw_string(f, r.position + Vector2(8, 38), TGUI.kpa(n.pressure()), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 15, UITheme.ACCENT)
		var tot: float = n.total_moles()
		var mix := PipeHover._mix(n.gas, tot) if tot > 0.01 else "empty"
		draw_string(f, r.position + Vector2(8, 56), "%.0f°C  ·  %s" % [n.temp - Defs.T0C, mix], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 12, UITheme.TEXT)

	func _arrow(a: Vector2, b: Vector2, col: Color) -> void:
		draw_line(a, b, Color(0, 0, 0, 0.6), 5.0)
		draw_line(a, b, col, 2.5)
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		draw_line(b, b - d * 8 + n * 6, col, 2.5)
		draw_line(b, b - d * 8 - n * 6, col, 2.5)

	func _draw() -> void:
		var w := size.x
		var bw := (w - 90.0) * 0.5
		var bh := 66.0
		var y0 := 10.0
		var in_r := Rect2(Vector2(0, y0), Vector2(bw, bh))
		var out_r := Rect2(Vector2(w - bw, y0), Vector2(bw, bh))
		var dev := Rect2(Vector2(bw + 12, y0 + 12), Vector2(66, 42))
		var col := Color("#6aff9a") if moving > 0.0001 else (Color(0.85, 0.9, 0.95, 0.8) if on else Color(1, 0.4, 0.35))
		for q in ports:
			match q["role"]:
				"in": _box(in_r, q)
				"out": _box(out_r, q)
				_:
					var sr := Rect2(Vector2((w - bw) * 0.5, y0 + bh + 14), Vector2(bw, bh - 6))
					_box(sr, q)
					if q["role"] == "side_out":
						_arrow(Vector2(dev.get_center().x, dev.end.y), Vector2(dev.get_center().x, sr.position.y - 2), col)
					else:
						_arrow(Vector2(dev.get_center().x, sr.position.y - 2), Vector2(dev.get_center().x, dev.end.y), col)
		# the device in the middle
		draw_rect(dev, Color(0.1, 0.13, 0.18))
		draw_rect(dev, Color(col, 0.9), false, 1.5)
		var f := UITheme.font
		var tw := f.get_string_size(device, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(f, Vector2(dev.get_center().x - tw * 0.5, dev.position.y + 18), device, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.TEXT)
		var st := ("%.1f mol/s" % moving) if moving > 0.0001 else ("idle" if on else "off")
		var sw := f.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(f, Vector2(dev.get_center().x - sw * 0.5, dev.position.y + 34), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		_arrow(Vector2(in_r.end.x + 2, in_r.get_center().y), Vector2(dev.position.x - 2, in_r.get_center().y), col)
		_arrow(Vector2(dev.end.x + 2, out_r.get_center().y), Vector2(out_r.position.x - 2, out_r.get_center().y), col)
