class_name ShipPanel extends PanelContainer
## The engineer's view of your ship: every system on one screen, with the controls that
## work them.
##
## Opened with [b]G[/b]. It exists because the alternative is walking round the deck
## right-clicking things to find out whether the boiler is lit, and because a ship you
## cannot read is a ship you cannot fly.
##
## The rule this panel is built on: **a number on its own teaches nobody anything.**
## Every reading here is a bar you can see filling, a word that says what the number
## means ("climbing", "fuel starved", "no steam"), and — where it matters — the thing you
## should do about it. A player should be able to fly out of Meridian having read nothing
## but this panel and the tutorial prompts.
##
## Everything here is also doable by hand at the machine itself. This is a convenience,
## not a second system.

const W := 400.0

## A horizontal gauge: a well, a fill, a band showing where the safe range is, and a
## needle. The safe band is the part that matters — a lift reading of 112% means nothing
## until you can see that it is inside the green.
class Gauge extends Control:
	var value := 0.0          # 0..1 of the well
	var safe_lo := -1.0       # < 0 for "no safe band"
	var safe_hi := -1.0
	var warn := false
	var col := Color("#7fd4ff")
	var marker := -1.0        # a thin tick: what the machinery is actually doing vs the order
	var shown := 0.0          # what is drawn: eases toward `value` so needles have weight
	var _marker_shown := -1.0
	var _primed := false
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(120, 13)
		mouse_filter = Control.MOUSE_FILTER_PASS
		set_process(false)

	## `sweep` makes a gauge that has just appeared climb up from empty rather than snap.
	func set_gauge(v: float, w: bool, sweep := false, mk := -1.0) -> void:
		var nv := clampf(v, 0.0, 1.0)
		if not _primed:
			_primed = true
			shown = 0.0 if sweep else nv
			_marker_shown = mk
		value = nv
		warn = w
		marker = mk
		set_process(true)

	func _process(delta: float) -> void:
		_t += delta
		# fast at first, settling softly: needles have weight
		var k := 1.0 - exp(-delta * 7.0)
		shown = lerpf(shown, value, k)
		if marker >= 0.0:
			_marker_shown = lerpf(_marker_shown if _marker_shown >= 0.0 else marker, marker, 1.0 - exp(-delta * 11.0))
		queue_redraw()
		if not warn and absf(shown - value) < 0.002 and (marker < 0.0 or absf(_marker_shown - marker) < 0.002):
			shown = value
			_marker_shown = marker
			set_process(false)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.04, 0.06, 0.09, 0.9))
		# the safe band, drawn under the fill so the fill reads on top of it
		if safe_lo >= 0.0:
			var x0 := size.x * safe_lo
			var x1 := size.x * safe_hi
			draw_rect(Rect2(Vector2(x0, 1), Vector2(maxf(2.0, x1 - x0), size.y - 2)),
				Color(0.36, 0.78, 0.52, 0.22))
		var c := Color("#ff5a4a") if warn else col
		if warn:
			# a warning breathes: the fill brightens and dims so the eye finds it
			c = c.lerp(Color(1.0, 0.9, 0.75), (0.5 + 0.5 * sin(_t * 9.0)) * 0.45)
		draw_rect(Rect2(Vector2(1, 1), Vector2((size.x - 2) * shown, size.y - 2)), c)
		# a lighter cap on the fill, so it has an edge rather than just ending
		if shown > 0.01:
			draw_rect(Rect2(Vector2(maxf(1.0, (size.x - 2) * shown - 2), 1), Vector2(2, size.y - 2)),
				c.lightened(0.45))
		if marker >= 0.0:
			var mx := 1.0 + (size.x - 2) * clampf(_marker_shown, 0.0, 1.0)
			draw_rect(Rect2(Vector2(mx - 1, 0), Vector2(2, size.y)), Color(1, 1, 1, 0.85))
		draw_rect(r, Color(UITheme.BORDER, 0.55), false, 1.0)


var ship: Airship = null
var body: VBoxContainer
var _t := 0.0
var _rows := {}          # key -> Control, rebuilt only when the fit-out changes
var _signature := ""
var _collapsed := {}     # section -> bool
var _sweep_next := false # gauges fill up from empty the first time the panel opens
var _slide: Tween
var _scroll: ScrollContainer
var _fit_t := 0.0

func _init() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(18, 92)
	custom_minimum_size = Vector2(W, 0)
	visible = false
	add_theme_stylebox_override("panel", UITheme.panel_style(0.96))
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# the panel is taller than a small screen; it scrolls instead of running off the bottom
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(body)
	add_child(_scroll)

func toggle() -> void:
	visible = not visible
	if _slide != null:
		_slide.kill()
	if visible:
		_signature = ""
		_sweep_next = true
		_rebuild()
		# slide in from the left edge and fade up
		modulate.a = 0.0
		position.x = -18.0
		_slide = create_tween().set_parallel(true)
		_slide.tween_property(self, "modulate:a", 1.0, 0.18)
		_slide.tween_property(self, "position:x", 18.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		modulate.a = 1.0
		position.x = 18.0
	Sfx.play_ui("ui_open" if visible else "ui_close", 0.5)

func _fit_scroll(delta: float) -> void:
	_fit_t -= delta
	if _fit_t > 0.0:
		return
	_fit_t = 0.2
	var avail := maxf(200.0, get_parent_area_size().y - 92.0 - 110.0)
	var want := body.get_combined_minimum_size().y
	var h := minf(want, avail)
	if absf(_scroll.custom_minimum_size.y - h) > 0.5:
		_scroll.custom_minimum_size.y = h
		reset_size()

func _process(delta: float) -> void:
	if not visible:
		return
	_fit_scroll(delta)
	ship = _find_ship()
	if ship == null:
		if _signature != "none":
			_clear()
			_title_bar()
			var msg := UITheme.label("You are not aboard a ship.", 15, UITheme.DIM)
			body.add_child(msg)
			var hint := RichTextLabel.new()
			hint.bbcode_enabled = true
			hint.fit_content = true
			hint.scroll_active = false
			hint.custom_minimum_size = Vector2(W - 24, 0)
			hint.add_theme_font_size_override("normal_font_size", 15)
			hint.text = "[color=#8aa0b4]Buy or draw one at the yard, then stand on her deck.[/color]"
			body.add_child(hint)
			_signature = "none"
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.15
	var sig := _sig()
	if sig != _signature:
		_signature = sig
		_rebuild()
	else:
		_refresh()

func _find_ship() -> Airship:
	if Game.fleet == null or Game.player == null:
		return null
	var sh: Airship = Game.fleet.ship_of(Game.player)
	if sh != null:
		return sh
	var h := Helm.of(Game.player)
	return h.ship() if h != null else null

## What the panel's layout depends on. Only a change here forces the rows to be rebuilt.
func _sig() -> String:
	if ship == null:
		return "none"
	return "%s|%d|%d|%d|%d|%d|%d|%d" % [ship.ship_name, ship.boilers.size(), ship.thrusters.size(),
		ship.lift_cells.size(), ship.bunkers.size(), ship.guns.size(), ship.masts.size(),
		_collapsed.size()]

func _clear() -> void:
	for c in body.get_children():
		c.queue_free()
	_rows.clear()

# ------------------------------------------------------------------ layout
func _title_bar() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	body.add_child(bar)
	var t := UITheme.label("SHIP SYSTEMS", 13, UITheme.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(t)
	bar.add_child(UITheme.label("G to close", 12, UITheme.DIM))

func _rebuild() -> void:
	_clear()
	if ship == null:
		return
	_title_bar()
	_head("%s — %s" % [ship.ship_name, String(ship.hull.get("name", "hull")).to_lower()], "")

	# ---- flight. The four numbers a pilot actually watches, as bars.
	_gauge("thr", "Throttle")
	_gauge("speed", "Speed")
	_gauge("lift", "Lift")
	_gauge("fuel", "Fuel")
	_gauge("power", "Steam")
	_stat("flight", "")
	_stat("advice", "")

	# ---- the controls that matter most, right at the top, because a player in trouble
	# should not have to scroll to find "all stop"
	var quick := _row()
	_btn(quick, "All stop", func(): _all_stop(), "Close the throttle and take the way off her.")
	_btn(quick, "Level off", func(): _level(), "Trim the ballast until she holds her altitude.")
	_btn(quick, "Light all", func(): _all_boilers(true), "Light every boiler aboard.")
	_btn(quick, "Bank fires", func(): _all_boilers(false), "Shut them down. Saves fuel in port.")

	if not ship.boilers.is_empty() and _open("Boilers"):
		for i in ship.boilers.size():
			var b: Entity = ship.boilers[i]
			_stat("boiler%d" % i, "")
			var row := _row()
			_btn(row, "Light", func(): _boiler(b, "light"), "Set the fire going. Nothing moves without it.")
			_btn(row, "Shut", func(): _boiler(b, "out"))
			_btn(row, "Valve", func(): _boiler(b, "valve"), "Shut the safety valve to hold more pressure. This is how boilers burst.")
			_btn(row, "−", func(): _boiler(b, "down"), "Damper down: less fire, less pressure, less fuel.")
			_btn(row, "+", func(): _boiler(b, "up"), "Damper up.")

	if not ship.thrusters.is_empty() and _open("Thrusters"):
		for i in ship.thrusters.size():
			_stat("thruster%d" % i, "")

	if not ship.lift_cells.is_empty() and _open("Lift cells"):
		for i in ship.lift_cells.size():
			var l: Entity = ship.lift_cells[i]
			_stat("lift%d" % i, "")
			var row2 := _row()
			_btn(row2, "Vent", func(): _vent(l), "Dump this cell's charge to lose height fast. You will want it back.")

	if _open("Bunkers"):
		_stat("fuelrow", "")
		_stat("range", "")

	if not ship.masts.is_empty() and _open("Sails"):
		_stat("sails", "")
		var row3 := _row()
		_btn(row3, "Set sail", func(): _sails(0.34), "Free speed, if the wind agrees with you.")
		_btn(row3, "Take in", func(): _sails(-0.34))
		_btn(row3, "Full", func(): _sails(1.0))
		_btn(row3, "Furl", func(): _sails(-1.0))

	if not ship.guns.is_empty() and _open("Guns"):
		for i in ship.guns.size():
			_stat("gun%d" % i, "")

	if _open("Her fit-out"):
		_stat("mods", "")
		var row4 := _row()
		_btn(row4, "Open the drawing board (I)", func():
			if Game.player != null:
				Shipyard.open_refit(Game.player, ship),
			"Redraw her, or swap a module for a better one.")
	_refresh()
	_sweep_next = false

## A collapsible section heading. Ships get large; a panel that cannot be folded up is a
## panel that ends up taller than the screen.
func _open(title: String) -> bool:
	var shut: bool = _collapsed.get(title, false)
	var b := Button.new()
	b.text = "%s  %s" % ["▸" if shut else "▾", title]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", UITheme.ACCENT)
	b.pressed.connect(func():
		_collapsed[title] = not shut
		_signature = ""      # force a rebuild
		_rebuild())
	body.add_child(b)
	return not shut

func _head(text: String, _sub: String) -> void:
	body.add_child(UITheme.label(text, 15, UITheme.TEXT))

func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 3)
	body.add_child(r)
	return r

## A labelled bar. Bars are the whole point of this panel: "fuel 41" means nothing at a
## glance and a bar two fifths full means everything.
func _gauge(key: String, label: String) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	body.add_child(r)
	var l := UITheme.label(label, 13, UITheme.DIM)
	l.custom_minimum_size = Vector2(54, 0)
	r.add_child(l)
	var bar := Gauge.new()
	bar.custom_minimum_size = Vector2(W - 200, 13)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# lift is the only reading with a right answer, so it is the only one with a band
	if key == "lift":
		bar.safe_lo = 0.96 / 1.6
		bar.safe_hi = 1.14 / 1.6
	elif key == "power":
		# working pressure: the valve feathers at 58 and the red line is 74
		bar.safe_lo = CBoiler.LIFT_PRESSURE / CBoiler.SAFE_PRESSURE
		bar.safe_hi = 1.0
	r.add_child(bar)
	var v := UITheme.label("", 13, UITheme.TEXT)
	v.custom_minimum_size = Vector2(112, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(v)
	_rows[key] = bar
	_rows[key + "_v"] = v

func _stat(key: String, text: String) -> void:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.custom_minimum_size = Vector2(W - 24, 17)
	l.add_theme_font_size_override("normal_font_size", 14)
	l.add_theme_color_override("default_color", UITheme.TEXT)
	l.text = text
	body.add_child(l)
	_rows[key] = l

func _btn(row: HBoxContainer, text: String, cb: Callable, tip := "") -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	row.add_child(b)

# ------------------------------------------------------------------ live values
func _refresh() -> void:
	if ship == null:
		return
	var top := maxf(0.1, ship.top_speed())
	var thrum := 0.0
	for t in ship.thrusters:
		if is_instance_valid(t) and not t.removed and t.has_c(&"thruster"):
			thrum = maxf(thrum, t.c(&"thruster").output())
	_put_gauge("thr", ship.throttle, "%d%% ordered, %d%% engine" % [int(ship.throttle * 100.0), int(thrum * 100.0)],
		false, thrum)
	_put_gauge("speed", ship.speed() / top, "%.1f / %.1f kt" % [ship.speed(), top], false)
	var b := ship.buoyancy()
	_put_gauge("lift", b / 1.6, "%d%% of weight" % int(b * 100.0), b < 0.9 or b > 1.3)
	var cap := maxf(1.0, ship.fuel_capacity())
	_put_gauge("fuel", ship.fuel() / cap, "%.0f / %.0f" % [ship.fuel(), cap], ship.fuel() < cap * 0.2)
	var steam := 0.0
	for bo in ship.boilers:
		var bc: CBoiler = bo.c(&"boiler")
		if bc != null:
			steam = maxf(steam, bc.pressure / CBoiler.SAFE_PRESSURE)
	_put_gauge("power", steam, "%d%%" % int(steam * 100.0) if not ship.boilers.is_empty() else "no boiler",
		steam > 1.0)

	var trim := "level"
	if b > 1.04: trim = "[color=#7ad8c8]climbing[/color]"
	elif b < 0.96: trim = "[color=#e8a83a]sinking[/color]"
	var br := ship.breaches()
	_put("flight", "Heading [b]%s[/b]   %.2f km   %s   throttle %d%%   %s" % [
		["north", "east", "south", "west"][ship.facing], ship.altitude, trim,
		int(ship.throttle * 100.0),
		"[color=#8ad8a0]hull sound[/color]" if br == 0 else "[color=#ff6a6a]%d breach%s[/color]" % [br, "" if br == 1 else "es"]])
	_put("advice", _advice())

	for i in ship.boilers.size():
		var e: Entity = ship.boilers[i]
		if not is_instance_valid(e) or e.removed:
			continue
		var bc2: CBoiler = e.c(&"boiler")
		if bc2 == null:
			continue
		var over := bc2.pressure > CBoiler.SAFE_PRESSURE
		_put("boiler%d" % i, "%s  %s  %.0f/%.0f kPa   damper %d%%   valve %s" % [
			"[color=#e8a83a]LIT[/color]" if bc2.lit else "[color=#8aa0b4]cold[/color]",
			_bar(bc2.pressure / CBoiler.MAX_PRESSURE, over),
			bc2.pressure, CBoiler.SAFE_PRESSURE, int(bc2.damper * 100.0),
			"open" if bc2.valve_open else "[color=#e8a83a]SHUT[/color]"])

	for i in ship.thrusters.size():
		var e2: Entity = ship.thrusters[i]
		if not is_instance_valid(e2) or e2.removed:
			continue
		var tc: CThruster = e2.c(&"thruster")
		if tc == null:
			continue
		var note := ""
		if tc.starved:
			note = "   [color=#ff8a5a]fuel starved[/color]"
		elif not ship.steam_up():
			note = "   [color=#e8a83a]no steam — light the boiler[/color]"
		elif tc.heat > 0.7:
			note = "   [color=#ff8a5a]overheating[/color]"
		_put("thruster%d" % i, "%s %s  %d%%   heat %d%%%s" % [
			_name_of(e2), _bar(tc.output(), false), int(tc.output() * 100.0), int(tc.heat * 100.0), note])

	for i in ship.lift_cells.size():
		var e3: Entity = ship.lift_cells[i]
		if not is_instance_valid(e3) or e3.removed:
			continue
		var lc: CLiftCell = e3.c(&"liftcell")
		if lc == null:
			continue
		_put("lift%d" % i, "%s %s  %d%%   envelope %d%%%s" % [
			_name_of(e3), _bar(lc.charge, lc.charge < 0.25), int(lc.charge * 100.0), int(lc.integrity * 100.0),
			"   [color=#ff8a5a]VENTING[/color]" if lc.venting else
			("   [color=#e8a83a]torn — weld it[/color]" if lc.integrity < 0.98 else "")])

	_put("fuelrow", "%s  %.0f / %.0f units of distillate" % [
		_bar(ship.fuel() / cap, ship.fuel() < cap * 0.2), ship.fuel(), cap])
	var secs := ship.endurance()
	_put("range", "[color=#8aa0b4]About %s at full throttle, or %s at cruise.[/color]" % [
		_dur(secs), _dur(secs * 2.4)])

	if not ship.masts.is_empty():
		var wind := ""
		if Game.sky != null:
			wind = "   wind %s from the %s" % [Game.sky.wind_name(), Game.sky._from(Game.sky.wind_dir_name())]
		_put("sails", "%s  %d%% set   (%d mast%s)%s" % [_bar(ship.sails_set, false),
			int(ship.sails_set * 100.0), ship.masts.size(), "" if ship.masts.size() == 1 else "s", wind])

	for i in ship.guns.size():
		var g: Entity = ship.guns[i]
		if not is_instance_valid(g) or g.removed:
			continue
		var gc: CShipGun = g.c(&"shipgun")
		if gc == null:
			continue
		_put("gun%d" % i, "%s   bears [b]%s[/b]   %s" % [_name_of(g), gc._bearing_word(),
			"[color=#6ad88a]loaded[/color]" if gc.loaded and gc.cooldown <= 0.0
			else "[color=#e8a83a]reloading %.1fs[/color]" % gc.cooldown])

	var st := ship.stats()
	_put("mods", "[color=#8aa0b4]%d fittings · %.0f t · hold %.0f t · %d berths · plating %.0f[/color]" % [
		ship.module_list().size(), ship.mass(), ship.cargo_capacity(), ship.berths(), st["armor"]])

## The one line that says what to do next. This is the single most useful thing on the
## panel for somebody who has not flown before.
func _advice() -> String:
	if ship.fuel() < 2.0:
		return "[color=#ff6a6a]Dry. She will not move until you put distillate in a bunker.[/color]"
	if not ship.steam_up():
		return "[color=#e8a83a]No steam. Light a boiler and give it about ten seconds.[/color]"
	if ship.buoyancy() > 1.35:
		return "[color=#e8a83a]She is light and climbing. Trim heavier (E at the wheel).[/color]"
	if ship.buoyancy() < 0.8:
		return "[color=#ff6a6a]She is heavy and sinking. Trim lighter (Q), or vent ballast.[/color]"
	if ship.breaches() > 0:
		return "[color=#ff6a6a]Holed. Patch the hull before you go up.[/color]"
	if Helm.of(Game.player) == null:
		return "[color=#8aa0b4]Steam up. Take the wheel and open the throttle.[/color]"
	if ship.throttle < 0.05:
		return "[color=#8aa0b4]At the wheel. Hold W to open the throttle.[/color]"
	return "[color=#6ad88a]All well.[/color]"

func _name_of(e: Entity) -> String:
	var short := e.display_name.capitalize()
	if short.length() > 18:
		short = short.substr(0, 17) + "."
	return "[color=#8aa0b4]%-18s[/color]" % short

static func _dur(secs: float) -> String:
	if secs > 3600.0:
		return "hours"
	if secs < 90.0:
		return "%d seconds" % int(secs)
	return "%d minutes" % int(secs / 60.0)

func _put(key: String, text: String) -> void:
	var l = _rows.get(key)
	if l != null and is_instance_valid(l):
		l.text = text

func _put_gauge(key: String, frac: float, text: String, warn: bool, marker := -1.0) -> void:
	var bar = _rows.get(key)
	if bar != null and is_instance_valid(bar):
		bar.set_gauge(frac, warn, _sweep_next, marker)
	var v = _rows.get(key + "_v")
	if v != null and is_instance_valid(v):
		v.text = text
		v.add_theme_color_override("font_color", UITheme.BAD if warn else UITheme.TEXT)

## A gauge made of text, for the rows that sit inside a sentence.
func _bar(v: float, warn: bool) -> String:
	var n := 10
	var filled := int(round(clampf(v, 0.0, 1.0) * n))
	var col := "#ff6a6a" if warn else "#7fd4ff"
	return "[color=%s]%s[/color][color=#3a4450]%s[/color]" % [
		col, "|".repeat(filled), "|".repeat(n - filled)]

# ------------------------------------------------------------------ controls
func _all_stop() -> void:
	var h := Helm.of(Game.player)
	if h != null:
		h.all_stop()
	elif ship != null:
		ship.throttle = 0.0
		ship.vel = Vector2.ZERO
	_refresh()

## Trim until she holds. Doing this by hand is a skill; having a button for it is the
## difference between an interesting system and a chore.
func _level() -> void:
	if ship == null:
		return
	var b := ship.buoyancy()
	if absf(b - 1.0) < 0.02:
		Game.tell(Game.player, "She is already level.")
		return
	ship.ballast = clampf(ship.ballast + (0.25 if b < 1.0 else -0.25), -1.0, 1.0)
	Game.tell(Game.player, "You work the ballast pump. Trim %+.0f%%." % (ship.ballast * 100.0))
	Sfx.play("ratchet", ship.center(), 0.5)
	_refresh()

func _all_boilers(on: bool) -> void:
	if ship == null:
		return
	var n := 0
	for b in ship.boilers:
		var bc: CBoiler = b.c(&"boiler")
		if bc == null:
			continue
		if on and not bc.lit:
			bc.light(Game.player)
			n += 1
		elif not on and bc.lit:
			bc.extinguish("shut down")
			n += 1
	if n > 0:
		Game.tell(Game.player, "%s %d boiler%s." % ["Lit" if on else "Banked", n, "" if n == 1 else "s"])
	_refresh()

func _boiler(e: Entity, what: String) -> void:
	if not is_instance_valid(e) or e.removed:
		return
	var bc: CBoiler = e.c(&"boiler")
	var p := Game.player
	if bc == null or p == null:
		return
	match what:
		"light": bc.light(p)
		"out": bc.extinguish("shut down")
		"valve": bc._toggle_valve(p)
		"up": bc._damper(p, 0.2)
		"down": bc._damper(p, -0.2)
	_refresh()

func _vent(e: Entity) -> void:
	if not is_instance_valid(e) or e.removed:
		return
	var lc: CLiftCell = e.c(&"liftcell")
	if lc != null and Game.player != null:
		lc._toggle_vent(Game.player)
	_refresh()

func _sails(d: float) -> void:
	var h := Helm.of(Game.player)
	if h != null:
		h.sails(d)
	elif ship != null:
		ship.sails_set = clampf(ship.sails_set + d, 0.0, 1.0)
	_refresh()
