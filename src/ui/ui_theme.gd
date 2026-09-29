class_name UITheme extends RefCounted
## The HUD's look, drawn from ui.png (tools/artgen/ui.py): gunmetal nine-slice panels
## with bevels and corner rivets, recessed slots, raised buttons with hover / pressed /
## disabled states, tabs, tooltips and bar wells. One type scale: Pixelify Sans for
## labels and buttons (14 / 16 / 20 / 26), VT323 for running text (20).

const BG := Color(0.07, 0.09, 0.13, 0.94)
const BG_LIGHT := Color(0.12, 0.16, 0.22, 0.96)
const BORDER := Color(0.37, 0.48, 0.57, 1.0)
const ACCENT := Color("#7fd4ff")
const TEXT := Color("#e6f0f8")
const DIM := Color("#9db3c6")
const WARN := Color("#ffb84a")
const BAD := Color("#ff5a4a")
const GOOD := Color("#6ae88a")

# type scale
const SMALL := 14
const BODY := 16
const TITLE := 20
const DISPLAY := 26

## Nine-slice corner size of each frame in ui.png (2x art, so twice the 1x corner).
const SLICE := {"panel": 20, "panel_title": 12, "slot_normal": 16, "slot_hot": 16, "slot_active": 16,
	"button_normal": 14, "button_hover": 14, "button_pressed": 14, "button_disabled": 14, "button_on": 14,
	"tab": 12, "tab_active": 12, "tooltip": 12, "well": 8, "line_edit": 12}

## HUD colour themes (Burgerstation lets you pick your HUD's colour): a tint on every
## panel, slot, tab and well. Changed live from the menu and remembered.
const THEMES := {"Steel": Color(1, 1, 1), "Amber": Color(1.3, 1.02, 0.66), "Crimson": Color(1.32, 0.72, 0.72),
	"Verdant": Color(0.78, 1.22, 0.86), "Violet": Color(1.05, 0.82, 1.35), "Ice": Color(0.85, 1.12, 1.3)}
const TINTED := ["panel", "panel_title", "slot_normal", "slot_hot", "slot_active", "tab", "tab_active", "well", "tooltip"]
const PREFS := "user://prefs.cfg"
static var tint := Color(1, 1, 1)
static var theme_name := "Steel"
static var _tinted: Array = [] # [WeakRef(StyleBoxTexture), alpha]

# ---- player preferences (Settings menu, F9). Saved in prefs.cfg; 0 for the scale means Auto.
static var ui_scale_pref := 0.0     ## HUD scale; 0 = pick one from the window size
static var panel_opacity := 1.0     ## 0.6 .. 1.0, multiplies every HUD panel's alpha
static var idle_fade := true        ## the message log dims and folds its controls away when quiet
static var equip_open := false      ## the worn-equipment grid is folded away until asked for
static var log_px := 20             ## message log text size in canvas pixels
static var master_volume := 0.8
static var hud_scale_now := 1.0     ## what the HUD is actually drawn at (see HUD.apply_ui_scale)
const LOG_SIZES := [17, 20, 24]

static var font: Font
static var mono: Font
static var theme: Theme

static func build() -> Theme:
	if theme:
		return theme
	load_prefs()
	font = load("res://assets/fonts/PixelifySans.ttf")
	mono = load("res://assets/fonts/VT323.ttf")
	UIFx.install()
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = BODY
	var panel := frame("panel", 16, 12)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	for st in ["normal", "hover", "pressed", "disabled"]:
		theme.set_stylebox(st, "Button", frame("button_" + st, 12, 6))
	theme.set_stylebox("focus", "Button", focus_ring())
	theme.set_stylebox("hover_pressed", "Button", frame("button_on", 12, 6))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_hover_pressed_color", "Button", ACCENT)
	theme.set_color("font_disabled_color", "Button", Color(DIM, 0.6))
	theme.set_color("icon_normal_color", "Button", Color(1, 1, 1, 0.92))
	theme.set_color("icon_hover_color", "Button", Color.WHITE)
	theme.set_color("icon_disabled_color", "Button", Color(1, 1, 1, 0.35))
	theme.set_font_size("font_size", "Button", BODY)
	theme.set_constant("h_separation", "Button", 6)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_font_size("font_size", "Label", BODY)
	# a soft drop shadow on every label lifts small text off the busy world behind the panels
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	var le := frame("line_edit", 10, 6)
	theme.set_stylebox("normal", "LineEdit", le)
	theme.set_stylebox("focus", "LineEdit", focus_ring(10, 6))
	theme.set_stylebox("read_only", "LineEdit", le)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_color("font_placeholder_color", "LineEdit", Color(DIM, 0.7))
	theme.set_font("normal_font", "RichTextLabel", mono)
	theme.set_font_size("normal_font_size", "RichTextLabel", 20)
	theme.set_font("bold_font", "RichTextLabel", mono)
	theme.set_font_size("bold_font_size", "RichTextLabel", 20)
	theme.set_font("italics_font", "RichTextLabel", mono)
	theme.set_font_size("italics_font_size", "RichTextLabel", 20)
	theme.set_font("mono_font", "RichTextLabel", mono)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_color("font_shadow_color", "RichTextLabel", Color(0, 0, 0, 0.55))
	theme.set_constant("shadow_offset_x", "RichTextLabel", 1)
	theme.set_constant("shadow_offset_y", "RichTextLabel", 1)
	theme.set_stylebox("panel", "PopupMenu", frame("panel", 12, 10))
	theme.set_stylebox("hover", "PopupMenu", frame("button_hover", 8, 2))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_color("font_separator_color", "PopupMenu", ACCENT)
	theme.set_font_size("font_size", "PopupMenu", BODY)
	theme.set_font_size("font_separator_size", "PopupMenu", SMALL)
	theme.set_constant("v_separation", "PopupMenu", 6)
	theme.set_stylebox("panel", "TooltipPanel", frame("tooltip", 12, 8))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", 15)
	theme.set_font("font", "TooltipLabel", font)
	theme.set_stylebox("background", "ProgressBar", frame("well", 2, 2))
	theme.set_stylebox("fill", "ProgressBar", fill("xp"))
	# thin, dark scrollbars
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.08, 0.6)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	theme.set_stylebox("scroll", "VScrollBar", sb)
	var grab := frame("button_normal", 0, 0)
	theme.set_stylebox("grabber", "VScrollBar", grab)
	theme.set_stylebox("grabber_highlight", "VScrollBar", frame("button_hover", 0, 0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", frame("button_pressed", 0, 0))
	var sep := StyleBoxLine.new()
	sep.color = Color(BORDER, 0.5)
	sep.thickness = 2
	theme.set_stylebox("separator", "HSeparator", sep)
	_extend_theme(theme)
	return theme

static func load_prefs() -> void:
	var cf := ConfigFile.new()
	if cf.load(PREFS) != OK:
		return
	theme_name = cf.get_value("hud", "theme", "Steel")
	tint = THEMES.get(theme_name, Color(1, 1, 1))
	ui_scale_pref = clampf(float(cf.get_value("ui", "scale", 0.0)), 0.0, 1.6)
	panel_opacity = clampf(float(cf.get_value("ui", "opacity", 1.0)), 0.6, 1.0)
	idle_fade = bool(cf.get_value("ui", "idle_fade", true))
	equip_open = bool(cf.get_value("ui", "equip_open", false))
	log_px = clampi(int(cf.get_value("ui", "log_px", 20)), 14, 30)
	master_volume = clampf(float(cf.get_value("audio", "master", 0.8)), 0.0, 1.0)

static func save_pref(section: String, key: String, value) -> void:
	var cf := ConfigFile.new()
	cf.load(PREFS)
	cf.set_value(section, key, value)
	cf.save(PREFS)

## The HUD scale to draw at. Auto aims for text that is no smaller on screen than it is at
## 1920x1080: a smaller window stretches the 1080p canvas down, so the HUD is scaled back up
## by the same amount (capped at 1.25: the bottom row of panels needs about 1300 canvas pixels).
static func ui_scale() -> float:
	if ui_scale_pref > 0.0:
		return ui_scale_pref
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return 1.0
	var w := Vector2(loop.root.size)
	var st := minf(w.x / 1920.0, w.y / 1080.0)
	return clampf(1.0 / maxf(st, 0.1), 1.0, 1.25)

## Text that lives outside the HUD canvas layer (tooltips, popup menus, toasts) is not
## scaled by it, so its sizes are multiplied by hand.
static func px(size: int) -> int:
	return int(roundf(size * hud_scale_now))

static func apply_scaled_theme() -> void:
	if theme == null:
		return
	theme.set_font_size("font_size", "TooltipLabel", px(15))
	theme.set_font_size("font_size", "PopupMenu", px(BODY))
	theme.set_font_size("font_separator_size", "PopupMenu", px(SMALL))
	theme.set_constant("v_separation", "PopupMenu", px(6))

## A visible keyboard-focus outline: a hollow accent box drawn over whatever the control
## already looks like.
static func focus_ring(px_x := 12, px_y := 6) -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.draw_center = false
	f.border_color = ACCENT
	f.set_border_width_all(2)
	f.content_margin_left = px_x
	f.content_margin_right = px_x
	f.content_margin_top = px_y
	f.content_margin_bottom = px_y
	return f

## Sliders in the same steel and cyan as everything else.
static func _extend_theme(t: Theme) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.03, 0.05, 0.09, 0.95)
	track.border_color = Color(BORDER, 0.7)
	track.set_border_width_all(2)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill_a := StyleBoxFlat.new()
	fill_a.bg_color = Color(ACCENT, 0.55)
	fill_a.border_color = Color(ACCENT, 0.9)
	fill_a.set_border_width_all(2)
	fill_a.content_margin_top = 4
	fill_a.content_margin_bottom = 4
	var fill_b: StyleBoxFlat = fill_a.duplicate()
	fill_b.bg_color = Color(ACCENT, 0.75)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill_a)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_b)
	t.set_icon("grabber", "HSlider", _grabber(Color(0.86, 0.94, 1.0)))
	t.set_icon("grabber_highlight", "HSlider", _grabber(ACCENT))
	t.set_icon("grabber_disabled", "HSlider", _grabber(Color(DIM, 0.5)))
	t.set_stylebox("focus", "HSlider", focus_ring(2, 2))

## A little pixel-art cog for the settings button (there is no gear in ui.png).
static func gear_icon() -> ImageTexture:
	var n := 22
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n - 1, n - 1) * 0.5
	for x in n:
		for y in n:
			var d := Vector2(x, y).distance_to(c)
			var ang := atan2(y - c.y, x - c.x)
			var tooth := int(floor((ang + PI) / TAU * 16.0)) % 2 == 0
			var outer := 9.6 if tooth else 7.6
			if d <= outer and d >= 3.4:
				img.set_pixel(x, y, Color("#c4d6e6") if d > 5.2 else Color("#8fb4d0"))
	return ImageTexture.create_from_image(img)

static func _grabber(col: Color) -> ImageTexture:
	var img := Image.create(12, 22, false, Image.FORMAT_RGBA8)
	for x in 12:
		for y in 22:
			if x >= 2 and x < 10 and y >= 2 and y < 20:
				img.set_pixel(x, y, col)
			elif x == 1 or x == 10 or y == 1 or y == 20:
				img.set_pixel(x, y, Color(0.02, 0.03, 0.06, 1.0))
	return ImageTexture.create_from_image(img)

## An icon button that draws a proper tooltip: the first line is its name (with the key in
## gold when it ends in "(K)"), the rest is what it does, wrapped.
class TipButton extends Button:
	func _make_custom_tooltip(for_text: String) -> Object:
		return UITheme.make_tip(for_text)

static func make_tip(text: String) -> Control:
	var lines := text.split("\n", false, 1)
	var head := lines[0] if lines.size() > 0 else ""
	var rest := lines[1] if lines.size() > 1 else ""
	var key := ""
	var open := head.rfind("(")
	if open > 0 and head.ends_with(")"):
		key = head.substr(open)
		head = head.substr(0, open).strip_edges()
	var w := 0.0
	for ln in text.split("\n"):
		w = maxf(w, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, px(15)).x)
	w = clampf(w + 8.0, px(120), px(340))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 10)
	box.add_child(hb)
	var hl := label(head, 17, ACCENT)
	hl.add_theme_font_size_override("font_size", px(17))
	hb.add_child(hl)
	if key != "":
		var kl := label(key, 15, Color("#e8c85a"))
		kl.add_theme_font_size_override("font_size", px(15))
		hb.add_child(kl)
	if rest != "":
		var bl := label(rest, 15, Color("#c4d4e2"))
		bl.add_theme_font_size_override("font_size", px(15))
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size.x = w
		box.add_child(bl)
	return box

static func tex(name: String) -> AtlasTexture:
	return Gfx.atlas("ui", name)

## A nine-slice frame from ui.png as a stylebox.
static func frame(name: String, pad_x := 12, pad_y := 8, alpha := 1.0) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex(name)
	var m: int = SLICE.get(name, 12)
	s.texture_margin_left = m
	s.texture_margin_right = m
	s.texture_margin_top = m
	s.texture_margin_bottom = m
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	s.modulate_color = Color(1, 1, 1, alpha)
	if name in TINTED:
		s.modulate_color = Color(tint, alpha)
		_tinted.append([weakref(s), alpha])
	return s

## Switch the HUD colour theme everywhere, now, and remember it.
static func set_theme(nm: String) -> void:
	theme_name = nm
	tint = THEMES.get(nm, Color(1, 1, 1))
	var keep := []
	for t in _tinted:
		var sb: StyleBoxTexture = t[0].get_ref()
		if sb:
			sb.modulate_color = Color(tint, t[1])
			keep.append(t)
	_tinted = keep
	var cf := ConfigFile.new()
	cf.load(PREFS)
	cf.set_value("hud", "theme", nm)
	cf.save(PREFS)

## A bar fill (health, stamina...) as a stylebox.
static func fill(name: String) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex("fill_" + name)
	s.texture_margin_top = 2
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return s

## The standard panel. `alpha` < 1 for HUD panels that sit over the world.
static func panel_style(alpha := 0.94) -> StyleBoxTexture:
	return frame("panel", 16, 12, clampf(alpha / 0.94, 0.0, 1.0))

static func label(text: String, size := BODY, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	# nothing in the interface is set smaller than SMALL: 11-13 px pixel text is what made
	# the old panels hard to read at 1600x900
	l.add_theme_font_size_override("font_size", maxi(size, SMALL))
	l.add_theme_color_override("font_color", color)
	return l

## A small caption in capitals, for section headings on panels.
static func caption(text: String, color := DIM) -> Label:
	var l := label(text.to_upper(), SMALL, color)
	return l

## An icon button with a tooltip (Burgerstation's HUD buttons: a picture, a name and a
## description on hover).
static func icon_button(icon_name: String, tip: String, sz := 44) -> Button:
	var b := TipButton.new()
	b.icon = tex("icon_" + icon_name)
	b.expand_icon = false
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(sz, sz)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	for st in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var base: StyleBoxTexture = theme.get_stylebox(st, "Button").duplicate()
		base.content_margin_left = 4
		base.content_margin_right = 4
		base.content_margin_top = 4
		base.content_margin_bottom = 4
		b.add_theme_stylebox_override(st, base)
	return b
