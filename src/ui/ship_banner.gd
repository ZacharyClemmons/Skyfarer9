extends Control
## The card that hangs in the sky for a few seconds when a ship is yours: her name, what she
## is, and one line about what to do next. Fades in from a slight drop, holds, and lifts
## away. It never takes input and it never blocks the view for long.

var _t := 0.0
var _hold := 3.4
var _name: Label
var _kind: Label
var _tip: Label
var _box: VBoxContainer

## Show the banner for `sh` on the HUD. `headline` sits above the name ("LAUNCHED").
static func show_for(sh: Airship, headline := "LAUNCHED", tip := "") -> void:
	if Game.hud == null or Game.hud.root == null or sh == null:
		return
	for old in Game.hud.root.get_children():
		if old.name == "ShipBanner":
			old.queue_free()
	var b: Control = new()
	b.name = "ShipBanner"
	Game.hud.root.add_child(b)
	b._setup(sh, headline, tip)

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0

func _setup(sh: Airship, headline: String, tip: String) -> void:
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 2)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_box)
	var head := _line(headline, UITheme.SMALL, UITheme.DIM)
	_name = _line(sh.ship_name, 40, UITheme.ACCENT)
	var kind := String(sh.hull.get("name", "hull"))
	var grade := int(sh.hull.get("grade", 1))
	_kind = _line("%s  -  %d berths  -  %s fit-out" % [kind, sh.berths(),
		ShipParts.TIER_NAMES[clampi(grade, 0, ShipParts.TIER_NAMES.size() - 1)]], UITheme.BODY, UITheme.TEXT)
	if tip != "":
		_tip = _line(tip, UITheme.SMALL, UITheme.DIM)
		_hold += 1.0
	_box.custom_minimum_size = Vector2(560, 0)
	_box.size = Vector2(560, 0)

func _line(text: String, size: int, col: Color) -> Label:
	var l := UITheme.label(text, size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_box.add_child(l)
	return l

func _process(delta: float) -> void:
	_t += delta
	var fade_in := 0.6
	var fade_out := 1.2
	var a := clampf(_t / fade_in, 0.0, 1.0)
	if _t > _hold:
		a = clampf(1.0 - (_t - _hold) / fade_out, 0.0, 1.0)
	modulate.a = a * a * (3.0 - 2.0 * a)
	if _box != null:
		# a slow drift down as it appears, and up as it leaves
		var e := 1.0 - pow(1.0 - clampf(_t / fade_in, 0.0, 1.0), 3.0)
		var lift := 0.0 if _t <= _hold else (_t - _hold) * 10.0
		_box.position = Vector2((size.x - _box.custom_minimum_size.x) * 0.5, 196.0 + e * 14.0 - lift)
		var s := 1.0 + (1.0 - e) * 0.06
		_box.pivot_offset = Vector2(_box.custom_minimum_size.x * 0.5, 0)
		_box.scale = Vector2(s, s)
	if _t > _hold + fade_out:
		queue_free()
