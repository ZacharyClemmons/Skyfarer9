class_name HUD extends CanvasLayer
const SettingsMenu := preload("res://src/ui/settings_menu.gd")
## The player's interface. SS13's layout (hands + equipment bar, alerts on the right,
## chat log) made friendlier: hover names, right-click verb menus, readable windows.

var root: Control
var chat_log: RichTextLabel
var chat_input: LineEdit
var chat_filter := "all"
var message_log := MessageLog.new()
var chat_lines: Array = message_log.entries
var log_search: LineEdit
var log_count: Label
var log_options: MenuButton
var slots := {}
var equip_row: Control
var equip_toggle: Button
var equip_visible := true
var name_label: RichTextLabel
var clock_time: Label
var alert_pill: PanelContainer
var evac_pill: PanelContainer
var power_pill: PanelContainer
var loc_label: Label
var purse_label: Label
const PURSE_COL := Color("#f0d060")
var _purse_target := -1
var _purse_shown := 0.0
var _purse_text := ""
var _purse_flash := 0.0   # >0 green (gained), <0 red (spent); decays toward 0
var temp_label: RichTextLabel
var alerts_box: BoxContainer
var bars := {}
var heartbeat: HudWidgets.Heartbeat
var examine_label: Label
var examine_hint: Label
var intent_buttons := {}
var move_buttons := {}
var auto_btn: Button
var aim_caption: Label
# Burgerstation's inline rows above the hands: the open bag's contents, and what's on
# the floor under you
var bag_box: VBoxContainer
var bag_caption: Label
var bag_row: GridContainer
var bag_open: Entity = null
var floor_box: VBoxContainer
var floor_row: HBoxContainer
var _rows_sig := ""
## The crafting grid's contents (Crafting), references to items you carry or can reach.
var craft_grid: Array = [null, null, null, null, null, null, null, null, null]
var hover_label: Label
var context: PopupMenu
var context_actions: Array = []
var windows: Control
var powers_bar: PowersBar # tg genetic power action buttons
var banner: PanelContainer
var banner_title: Label
var banner_text: Label
var banner_t := 0.0
var overlay: Control # draws progress bars & AI debug over the world
var fx_rect: ColorRect
var fx_mat: ShaderMaterial
var fx_full: ShaderMaterial
var fx_lite: ShaderMaterial
var death_panel: PanelContainer
var end_panel: PanelContainer
var throw_mode := false
var action_buttons := {}
var target_doll: TargetDoll
var bubbles: Array = [] # {node, ent, t}
var debug_atmos := false
var debug_ai := false
# drag and drop (see DragDrop)
var drop_slots: Array = [] # every InvSlot on screen registers itself
var mouse := Vector2.ZERO # last mouse position seen by the HUD, in canvas coordinates
var drag_item: Entity = null
var drag_from := Vector2.ZERO
var drag_click := Callable() # a press on a floor item that never becomes a drag clicks on release
var dragging := false
var drag_ghost: TextureRect
var drag_hint_slot: InvSlot
# HUD layout mode: panels can be moved (and the chat resized), then saved
var panels := {} # name -> Control
var layout_mode := false
var layout_handles: Array = []
var layout_defaults := {} # name -> anchors and offsets as built
const LAYOUT_FILE := "user://hud_layout_v3.cfg"
const CHAT_SIZE := Vector2i(470, 270)
const PANEL_KEYS := ["clock", "menu", "chat", "equipment", "hands", "examine", "alerts", "combat"]

func _ready() -> void:
	layer = 20
	root = Control.new()
	# The HUD layer is scaled (Settings > UI scale), so the root is sized by hand to the
	# viewport divided by that scale instead of anchoring to the viewport.
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.build()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)
	apply_ui_scale()
	_build_fx()
	_build_overlay()
	_build_topbar()
	_build_chat()
	_build_inventory()
	_build_misc()
	_build_drag()
	powers_bar = PowersBar.new()
	powers_bar.position = Vector2(14, 104)
	root.add_child(powers_bar)
	for k in panels:
		fit_panel(panels[k])
	for k in panels:
		var pn: Control = panels[k]
		layout_defaults[k] = [pn.anchor_left, pn.anchor_top, pn.anchor_right, pn.anchor_bottom, pn.offset_left, pn.offset_top, pn.offset_right, pn.offset_bottom]
	_load_layout()
	apply_ui_scale()
	_apply_panel_opacity()
	_set_equip_open(UITheme.equip_open, false)
	Sfx.master = UITheme.master_volume
	SettingsMenu.apply_saved()
	# test hooks: --uiscale=1.3 draws this run at that scale (not saved); --settingsshot opens
	# the settings window a moment after start
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--uiscale="):
			UITheme.ui_scale_pref = float(a.get_slice("=", 1))
			apply_ui_scale()
		elif a == "--settingsshot":
			get_tree().create_timer(2.0).timeout.connect(open_settings)
		elif a == "--hudtest":
			preload("res://src/ui/ui_selftest.gd").run(self)
		elif a == "--tipshot":
			get_tree().create_timer(1.0).timeout.connect(_demo_tips)
		elif a == "--logshot":
			get_tree().create_timer(1.0).timeout.connect(_demo_log)
	get_viewport().size_changed.connect(apply_ui_scale)
	Bus.chat.connect(_on_chat)
	Bus.speech.connect(_on_speech)
	Bus.radio.connect(_on_radio)
	Bus.announcement.connect(_on_announcement)
	Bus.ui_open_window.connect(open_window)
	Bus.mob_died.connect(_on_mob_died)
	Bus.skill_up.connect(_on_skill_up)
	Bus.xp_gained.connect(_on_xp_gained)

# ------------------------------------------------------------------ scale and preferences
var _scale := 1.0
var _window_layer: CanvasLayer
var _settings_open: UIWindow

## Draw the whole HUD (and its windows) at UITheme.ui_scale(). Everything inside `root` is
## laid out in a canvas that is 1920x1080 divided by the scale, so a bigger scale means bigger
## text and controls and less room, which is the trade the player is choosing.
func apply_ui_scale() -> void:
	_scale = UITheme.ui_scale()
	UITheme.hud_scale_now = _scale
	UITheme.apply_scaled_theme()
	var vis := get_viewport().get_visible_rect().size
	scale = Vector2(_scale, _scale)
	root.position = Vector2.ZERO
	root.size = vis / _scale
	if _window_layer != null:
		_window_layer.scale = Vector2(_scale, _scale)
		windows.position = Vector2.ZERO
		windows.size = vis / _scale
	if not panels.is_empty():
		_clamp_panels()

## Viewport (screen) coordinates to the HUD's own canvas.
func to_ui(p: Vector2) -> Vector2:
	return p / _scale

## Panel opacity from Settings: multiplies the alpha every HUD panel was built with.
func _apply_panel_opacity() -> void:
	for k in panels:
		var pn: Control = panels[k]
		if pn is PanelContainer and pn.has_theme_stylebox_override("panel"):
			var sb := pn.get_theme_stylebox("panel")
			if sb is StyleBoxTexture:
				if not pn.has_meta("base_a"):
					pn.set_meta("base_a", sb.modulate_color.a)
				sb.modulate_color.a = float(pn.get_meta("base_a")) * UITheme.panel_opacity

## --logshot: one line of every kind, to check the colours side by side.
func _demo_log() -> void:
	for pair in [["Kestrel's burner catches with a soft whump.", "good"], ["Boiler pressure is low.", "warn"],
			["A moss shrike bites you on the arm.", "combat"], ["Something is wrong with the ballast.", "bad"],
			["The quay bell rings twice: departures.", "announce"], ["Test Hand says, \"Hold her steady.\"", "say"],
			["You see a brass boiler with a round gauge.", "examine"], ["[Common] Pike: fog on the Long Sky.", "radio"]]:
		Bus.chat.emit(pair[0], pair[1])

## --tipshot: the custom tooltip drawn in its panel, since a screenshot has no mouse to hover with.
func _demo_tips() -> void:
	var y := 220.0
	for t in ["Skills (P)\nYour skills and attributes, and how close each is to the next level.",
			"Arrange the HUD (F2)\nMove the panels around; drag the chat's corner to resize it.", "Close (Esc)"]:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UITheme.frame("tooltip", 12, 8))
		pc.add_child(UITheme.make_tip(t))
		pc.position = Vector2(700, y)
		root.add_child(pc)
		y += 110.0

func set_log_text_size(px: int) -> void:
	px = clampi(px, 14, 30)
	message_log.font_size = px
	UITheme.log_px = px
	UITheme.save_pref("ui", "log_px", px)
	for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		chat_log.add_theme_font_size_override(key, px)
	if log_options != null:
		_sync_log_options()

func open_settings() -> void:
	if is_instance_valid(_settings_open) and not _settings_open.is_queued_for_deletion():
		UIFx.ease_close(_settings_open)
		return
	_settings_open = SettingsMenu.open(self)

func _build_fx() -> void:
	# full-screen post effects live on their own lower layer so UI stays crisp
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	fx_rect = ColorRect.new()
	fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_mat = ShaderMaterial.new()
	fx_full = fx_mat
	fx_mat.shader = load("res://src/render/screen_fx.gdshader")
	# The full shader reads the screen texture (blur, monochrome, psychic), which makes the
	# renderer copy the whole back buffer every frame even when it is only drawing the
	# vignette. The common case runs a copy of it with those three reads stripped out.
	var lite := Shader.new()
	var src: String = (fx_mat.shader as Shader).code
	src = src.replace("uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;", "")
	var rx := RegEx.new()
	rx.compile("textureLod\\(screen_tex,[^;]*?\\)\\.rgb")
	src = rx.sub(src, "vec3(0.0)", true)
	lite.code = src
	fx_lite = ShaderMaterial.new()
	fx_lite.shader = lite
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.width = 256
	nt.height = 256
	var fn := FastNoiseLite.new()
	fn.frequency = 0.03
	nt.noise = fn
	fx_mat.set_shader_parameter("noise_tex", nt)
	fx_lite.set_shader_parameter("noise_tex", nt)
	fx_rect.material = fx_lite
	cl.add_child(fx_rect)

func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	root.add_child(overlay)

func _build_topbar() -> void:
	# --- the status plaque, top-left: the time and alert level, where you are, the air
	var p := PanelContainer.new()
	p.position = Vector2(12, 10)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", UITheme.frame("panel", 16, 12, 0.9))
	root.add_child(p)
	panels["clock"] = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	v.add_child(r1)
	r1.add_child(_icon("clock", 28))
	clock_time = UITheme.label("", UITheme.DISPLAY, Color.WHITE)
	r1.add_child(clock_time)
	alert_pill = _pill("ALL CLEAR", Color("#4ac86a"))
	alert_pill.tooltip_text = "Ship alert state"
	r1.add_child(alert_pill)
	evac_pill = _pill("", UITheme.WARN)
	r1.add_child(evac_pill)
	# the purse: the number a skyfarer looks at most, so it gets its own big line, and it
	# counts up or down to the new total instead of jumping
	var pr := Control.new()
	pr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(pr)
	purse_label = UITheme.label("", UITheme.TITLE, PURSE_COL)
	purse_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.0, 0.9))
	purse_label.add_theme_constant_override("outline_size", 4)
	purse_label.tooltip_text = "Your purse, in marks."
	purse_label.mouse_filter = Control.MOUSE_FILTER_PASS
	r1.add_child(purse_label)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 6)
	v.add_child(r2)
	r2.add_child(_icon("location", 22))
	loc_label = UITheme.label("", UITheme.BODY, UITheme.ACCENT)
	r2.add_child(loc_label)
	power_pill = _pill("NO POWER", UITheme.BAD)
	r2.add_child(power_pill)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(10, 0)
	r2.add_child(sp)
	r2.add_child(_icon("temp", 22))
	# rich text rather than a plain label: this line now carries the purse, the weather
	# and whatever is running on you, and each of those needs its own colour
	temp_label = RichTextLabel.new()
	temp_label.bbcode_enabled = true
	temp_label.fit_content = true
	temp_label.scroll_active = false
	temp_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	temp_label.custom_minimum_size = Vector2(180, 24)
	temp_label.add_theme_font_size_override("normal_font_size", UITheme.BODY)
	temp_label.add_theme_font_override("normal_font", UITheme.font)
	temp_label.add_theme_color_override("default_color", UITheme.DIM)
	r2.add_child(temp_label)
	# --- the menu, top-right: one icon per screen, name and key on hover
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", UITheme.frame("panel", 8, 6, 0.9))
	mp.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mp.offset_right = -12
	mp.offset_top = 10
	root.add_child(mp)
	panels["menu"] = mp
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 4)
	mp.add_child(tr)
	for it in [["skills", "skills", "Skills (P)\nYour skills and attributes, and how close each is to the next level."],
			["objectives", "objectives", "Duties (O)\nWhat your berth expects of you aboard."],
			["map", "station_map", "Chart (M)\nThe ground and decks around you."],
			["craft", "crafting", "Crafting (N)\nPut parts in the grid to make weapons, restraints and food."],
			["crew", "crew", "Crew manifest (K)\nWho's aboard and what they think of you."],
			["log", "chronicle", "Ship's log (L)\nWhat has happened this voyage."]]:
		var b := UITheme.icon_button(it[0], it[2], 44)
		var k: String = it[1]
		b.pressed.connect(func(): open_window(k, null))
		tr.add_child(b)
	var thb := UITheme.icon_button("theme", "HUD colour
Pick a colour for your HUD.", 44)
	var thm := PopupMenu.new()
	for tn in UITheme.THEMES:
		thm.add_radio_check_item(tn)
	thm.index_pressed.connect(func(i):
		UITheme.set_theme(thm.get_item_text(i))
		_apply_panel_opacity()
		for k in thm.item_count:
			thm.set_item_checked(k, k == i)
		root.queue_redraw()
		for c in root.find_children("*", "Control", true, false):
			c.queue_redraw()
	)
	thb.add_child(thm)
	thb.pressed.connect(func():
		for k in thm.item_count:
			thm.set_item_checked(k, thm.get_item_text(k) == UITheme.theme_name)
		thm.position = Vector2i(thb.get_global_transform_with_canvas().origin + Vector2(0, (thb.size.y + 4) * _scale))
		thm.reset_size()
		thm.popup()
	)
	tr.add_child(thb)
	var lb := UITheme.icon_button("layout", "Arrange the HUD (F2)\nMove the panels around; drag the chat's corner to resize it.", 44)
	lb.pressed.connect(toggle_layout_mode)
	tr.add_child(lb)
	var hb := UITheme.icon_button("help", "Help (F1)\nControls and how the ship works.", 44)
	hb.pressed.connect(func(): open_window("help", null))
	tr.add_child(hb)
	var sb := UITheme.icon_button("help", "Settings (F9)\nText and HUD size, volume, key bindings.", 44)
	sb.icon = UITheme.gear_icon()
	sb.pressed.connect(open_settings)
	tr.add_child(sb)

func _icon(name: String, sz := 24) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UITheme.tex("icon_" + name)
	t.custom_minimum_size = Vector2(sz, sz)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## A small coloured tag (alert level, NO POWER, the crawler's status).
func _pill(text: String, col: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _pill_style(col))
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var l := UITheme.label(text, UITheme.SMALL, Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	pc.add_child(l)
	return pc

func _pill_style(col: Color) -> StyleBoxFlat:
	# square-cornered with a hard 2px rim, to sit with the pixel art
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.55)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	return sb

func _set_pill(pc: PanelContainer, text: String, col: Color) -> void:
	pc.visible = text != ""
	var l := pc.get_child(0) as Label
	if l.text == text and pc.has_meta("col") and pc.get_meta("col") == col:
		return
	l.text = text
	l.add_theme_color_override("font_color", col.lightened(0.45))
	pc.set_meta("col", col)
	pc.add_theme_stylebox_override("panel", _pill_style(col))

func _build_chat() -> void:
	message_log.load_settings()
	# Burgerstation keeps the chat in a panel down the right side of the screen
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.offset_right = -12
	p.offset_top = 80
	p.add_theme_stylebox_override("panel", UITheme.frame("panel", 12, 10, 0.82))
	root.add_child(p)
	panels["chat"] = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var tabs := GridContainer.new()
	_chat_controls.append(tabs)
	tabs.columns = 4
	tabs.add_theme_constant_override("h_separation", 2)
	tabs.add_theme_constant_override("v_separation", 2)
	v.add_child(tabs)
	var group := ButtonGroup.new()
	for pair in [["All", "all"], ["Chat", "chat"], ["Combat", "combat"], ["Voice-link", "radio"],
			["Events", "events"], ["Warnings", "warnings"], ["Systems", "system"], ["Examine", "examine"]]:
		var b := Button.new()
		b.text = pair[0]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = pair[1] == "all"
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "Show %s messages. Search and options apply within this tab." % String(pair[0]).to_lower()
		b.add_theme_font_size_override("font_size", UITheme.SMALL)
		for st in ["normal", "hover", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, UITheme.frame("tab", 10, 3))
		b.add_theme_stylebox_override("pressed", UITheme.frame("tab_active", 10, 3))
		b.add_theme_stylebox_override("hover_pressed", UITheme.frame("tab_active", 10, 3))
		b.add_theme_color_override("font_color", UITheme.DIM)
		var f: String = pair[1]
		b.pressed.connect(func():
			chat_filter = f
			_rebuild_chat()
		)
		tabs.add_child(b)
	var tools := HBoxContainer.new()
	_chat_controls.append(tools)
	v.add_child(tools)
	log_search = LineEdit.new()
	log_search.placeholder_text = "Search messages…"
	log_search.clear_button_enabled = true
	log_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_search.text_changed.connect(func(text: String):
		message_log.search = text
		_rebuild_chat())
	log_search.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
			log_search.release_focus()
			log_search.accept_event())
	tools.add_child(log_search)
	log_options = MenuButton.new()
	log_options.text = "Options"
	log_options.focus_mode = Control.FOCUS_NONE
	tools.add_child(log_options)
	var menu := log_options.get_popup()
	menu.hide_on_checkable_item_selection = false
	for i in MessageLog.CATEGORIES.size():
		menu.add_check_item(MessageLog.LABELS[i], i)
	menu.add_separator()
	menu.add_check_item("Show timestamps", 20)
	menu.add_check_item("Follow new messages", 21)
	menu.add_check_item("Group consecutive repeats", 22)
	menu.add_separator("Text size")
	menu.add_radio_check_item("Compact", 30)
	menu.add_radio_check_item("Comfortable", 31)
	menu.add_radio_check_item("Large", 32)
	menu.add_separator()
	menu.add_item("Copy visible messages", 40)
	menu.add_item("Export visible messages…", 41)
	menu.id_pressed.connect(_log_option)
	menu.about_to_popup.connect(_sync_log_options)
	log_count = UITheme.label("", UITheme.SMALL, UITheme.DIM)
	_chat_controls.append(log_count)
	v.add_child(log_count)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", UITheme.frame("well", 8, 6, 0.85))
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(well)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_following = message_log.follow
	for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		chat_log.add_theme_font_size_override(key, message_log.font_size)
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.custom_minimum_size = Vector2(CHAT_SIZE)
	chat_log.selection_enabled = true
	chat_log.install_effect(LineInFx.new())
	well.add_child(chat_log)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Say something...  (;  voice-link,  :e :m :s :n :v :u :c  a section of the ship)"
	chat_input.visible = false
	chat_input.text_submitted.connect(_on_chat_submit)
	v.add_child(chat_input)

func _slot(s: String, sz: int) -> InvSlot:
	var icon: String = {"uniform": "slot_uniform", "suit": "slot_suit", "head": "slot_head", "mask": "slot_mask", "gloves": "slot_gloves", "shoes": "slot_shoes",
		"back": "slot_back", "belt": "slot_belt", "id": "slot_id", "ears": "slot_ears", "eyes": "slot_eyes", "pocket_l": "slot_pocket", "pocket_r": "slot_pocket",
		"hand_l": "hand_l", "hand_r": "hand_r"}.get(s, "")
	var sl := InvSlot.new(s, icon, sz)
	sl.clicked.connect(_on_slot_clicked)
	slots[s] = sl
	return sl

func _hud_panel(key: String, preset: int, off: Vector2, alpha := 0.86) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.frame("panel", 12, 10, alpha))
	p.set_anchors_and_offsets_preset(preset)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN if off.x < 0 else (Control.GROW_DIRECTION_BOTH if preset == Control.PRESET_CENTER_BOTTOM else Control.GROW_DIRECTION_END)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if off.x < 0:
		p.offset_right = off.x
	elif off.x > 0:
		p.offset_left = off.x
	p.offset_bottom = off.y
	root.add_child(p)
	panels[key] = p
	return p

## Burgerstation's HUD along the bottom: your worn equipment laid out like a body on the
## left; your hands in the middle with back, belt, pockets and ID either side and the hand
## actions above; on the right your vital signs, intents, movement and defence, and the
## targeting doll.
func _build_inventory() -> void:
	# --- equipment, shaped like a body
	var ep := _hud_panel("equipment", Control.PRESET_BOTTOM_LEFT, Vector2(12, -12))
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 6)
	ep.add_child(ev)
	var inv_head := HBoxContainer.new()
	inv_head.add_theme_constant_override("separation", 4)
	ev.add_child(inv_head)
	var inventory_button := Button.new()
	inventory_button.text = "Inventory  [Tab]"
	inventory_button.tooltip_text = "Inventory (Tab)\nEquipment, bags and nearby items. Drag and drop to move your gear."
	inventory_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_button.pressed.connect(toggle_inventory)
	inv_head.add_child(inventory_button)
	# the worn-gear grid takes a lot of screen for something you rarely touch mid-flight,
	# so it folds away (and remembers which way you left it)
	equip_toggle = Button.new()
	equip_toggle.text = "Worn"
	equip_toggle.toggle_mode = true
	equip_toggle.tooltip_text = "Worn gear\nShow or hide the slots for what you are wearing."
	equip_toggle.toggled.connect(func(on: bool): _set_equip_open(on))
	inv_head.add_child(equip_toggle)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	ev.add_child(grid)
	equip_row = grid
	for s in ["ears", "head", "eyes", "gloves", "mask", "", "suit", "uniform", "", "", "shoes", ""]:
		if s == "":
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(50, 50)
			sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(sp)
		else:
			grid.add_child(_slot(s, 50))
	# --- hands, with back and belt to the left and pockets and ID to the right
	var hp := _hud_panel("hands", Control.PRESET_CENTER_BOTTOM, Vector2(0, -12))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 8)
	hp.add_child(hv)
	bag_box = VBoxContainer.new()
	bag_box.add_theme_constant_override("separation", 2)
	bag_box.visible = false
	hv.add_child(bag_box)
	var bh := HBoxContainer.new()
	bag_box.add_child(bh)
	bag_caption = UITheme.caption("Backpack")
	bag_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(bag_caption)
	var bclose := UITheme.icon_button("close", "Close the bag", 22)
	bclose.pressed.connect(func():
		bag_open = null
		refresh_inventory()
	)
	bh.add_child(bclose)
	# a big bag wraps onto a second line instead of stretching across the screen
	bag_row = GridContainer.new()
	bag_row.add_theme_constant_override("h_separation", 3)
	bag_row.add_theme_constant_override("v_separation", 3)
	bag_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bag_box.add_child(bag_row)
	floor_box = VBoxContainer.new()
	floor_box.add_theme_constant_override("separation", 2)
	floor_box.visible = false
	hv.add_child(floor_box)
	floor_box.add_child(UITheme.caption("On the floor"))
	floor_row = HBoxContainer.new()
	floor_row.add_theme_constant_override("separation", 3)
	floor_row.alignment = BoxContainer.ALIGNMENT_CENTER
	floor_box.add_child(floor_row)
	var acts := HBoxContainer.new()
	acts.alignment = BoxContainer.ALIGNMENT_CENTER
	acts.add_theme_constant_override("separation", 4)
	hv.add_child(acts)
	for it in [["drop", "drop", "Drop (Q)\nDrop what's in your active hand."], ["swap", "swap", "Swap hands (X)"],
			["throw", "throw", "Throw mode (F)\nYour next click throws what you hold."], ["pull", "pull", "Stop pulling (V)\nCtrl+click something to start pulling it."],
			["resist", "resist", "Resist (B)\nBreak a grab, wriggle out of cuffs, or stop, drop and roll."],
			["internals", "internals", "Cylinder\nBreathe from your gas cylinder (needs a mask)."]]:
		acts.add_child(_action_button(it[0], it[1], it[2], 40))
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 4)
	hr.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_child(hr)
	for s in ["back", "belt"]:
		var sl := _slot(s, 54)
		sl.size_flags_vertical = Control.SIZE_SHRINK_END
		hr.add_child(sl)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	hr.add_child(gap)
	for h in ["hand_r", "hand_l"]:
		hr.add_child(_slot(h, 74))
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(8, 0)
	hr.add_child(gap2)
	for s in ["pocket_r", "pocket_l", "id"]: # mirrored like the hands
		var sl2 := _slot(s, 54)
		sl2.size_flags_vertical = Control.SIZE_SHRINK_END
		hr.add_child(sl2)
	# the hotbar (keys 5-9, 0)
	var hbr := HBoxContainer.new()
	hbr.add_theme_constant_override("separation", 4)
	hbr.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_child(hbr)
	for i in 6:
		hbr.add_child(_slot("hot_%d" % i, 44))
	# --- the examine bar and alerts sit above the hands
	var xb := PanelContainer.new()
	xb.add_theme_stylebox_override("panel", UITheme.frame("tooltip", 12, 4, 0.9))
	xb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	xb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	xb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	xb.offset_bottom = -12 - hp.get_combined_minimum_size().y - 6
	xb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(xb)
	panels["examine"] = xb
	var xh := HBoxContainer.new()
	xh.add_theme_constant_override("separation", 12)
	xh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xb.add_child(xh)
	examine_label = UITheme.label("", UITheme.BODY, Color.WHITE)
	xh.add_child(examine_label)
	examine_hint = UITheme.label("", UITheme.SMALL, UITheme.DIM)
	examine_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xh.add_child(examine_hint)
	var ab := AlertBar.new()
	ab.on_click = _action
	alerts_box = ab
	alerts_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	alerts_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	alerts_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	alerts_box.offset_bottom = xb.offset_bottom - 44
	root.add_child(alerts_box)
	panels["alerts"] = alerts_box
	# --- vital signs, intents, movement, defence and the doll, bottom-right
	var cp := _hud_panel("combat", Control.PRESET_BOTTOM_RIGHT, Vector2(-12, -12))
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 10)
	cp.add_child(ch)
	_build_vitals(ch)
	ch.add_child(VSeparator.new())
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	ch.add_child(cv)
	cv.add_child(UITheme.caption("Intent"))
	var ig := GridContainer.new()
	ig.columns = 2
	ig.add_theme_constant_override("h_separation", 4)
	ig.add_theme_constant_override("v_separation", 4)
	cv.add_child(ig)
	var igroup := ButtonGroup.new()
	for it in [["help", "Help (1)\nHug, shake awake, help up, pat out flames. Items are used gently."],
			["disarm", "Disarm (2)\nShove. Into a wall or a table knocks them down; a shove on someone staggered knocks their item away."],
			["grab", "Grab (3)\nGrab passively, again to grab aggressively, again by the neck."],
			["harm", "Harm (4)\nPunch, or attack with what you hold."]]:
		var b := UITheme.icon_button("intent_" + it[0], it[1], 46)
		b.toggle_mode = true
		b.button_group = igroup
		var iname: String = it[0]
		b.pressed.connect(func(): set_intent(iname))
		intent_buttons[iname] = b
		ig.add_child(b)
	cv.add_child(UITheme.caption("Move"))
	var mr := HBoxContainer.new()
	mr.add_theme_constant_override("separation", 4)
	cv.add_child(mr)
	var mgroup := ButtonGroup.new()
	for it in [["walk", "Walk (C cycles)\nSteady: you won't slip on wet floors."], ["run", "Run (C cycles)"],
			["sneak", "Sneak (C cycles)\nSlow and quiet: people only notice you up close, and you speak in a whisper."]]:
		var b2 := UITheme.icon_button(it[0], it[1], 38)
		b2.toggle_mode = true
		b2.button_group = mgroup
		var mname: String = it[0]
		b2.pressed.connect(func(): set_move_mode(mname))
		move_buttons[mname] = b2
		mr.add_child(b2)
	cv.add_child(UITheme.caption("Resist"))
	var dr := HBoxContainer.new()
	dr.add_theme_constant_override("separation", 4)
	cv.add_child(dr)
	auto_btn = UITheme.icon_button("auto", "Auto-resist\nStruggle against grabs on your own.", 38)
	auto_btn.toggle_mode = true
	auto_btn.toggled.connect(func(on):
		if Game.player:
			Game.player.c(&"mob").auto_resist = on
	)
	dr.add_child(auto_btn)
	ch.add_child(VSeparator.new())
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 4)
	ch.add_child(dv)
	aim_caption = UITheme.caption("Aim")
	dv.add_child(aim_caption)
	target_doll = TargetDoll.new()
	target_doll.aim_changed.connect(_on_aim_changed)
	dv.add_child(target_doll)

## Who you are, your heart, and a column per vital sign.
func _build_vitals(parent: Control) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	parent.add_child(v)
	name_label = RichTextLabel.new()
	name_label.bbcode_enabled = true
	name_label.fit_content = true
	name_label.scroll_active = false
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.custom_minimum_size = Vector2(230, 0)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_override("normal_font", UITheme.font)
	name_label.add_theme_font_override("bold_font", UITheme.font)
	name_label.add_theme_font_size_override("normal_font_size", UITheme.SMALL)
	name_label.add_theme_font_size_override("bold_font_size", UITheme.BODY)
	v.add_child(name_label)
	heartbeat = HudWidgets.Heartbeat.new()
	heartbeat.custom_minimum_size = Vector2(230, 34)
	v.add_child(heartbeat)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	v.add_child(row)
	for it in [["health", "heart", "health", "Health"], ["stamina", "stamina", "stamina", "Stamina\nSpent by fighting, dodging and running."],
			["temp", "temp", "temp", "Body temperature"], ["food", "food", "food", "Nutrition"], ["water", "water", "water", "Hydration"],
			["energy", "energy", "energy", "Energy\nSleep to recover it."]]:
		var b := HudWidgets.VitalBar.new(it[1], it[2], it[3])
		row.add_child(b)
		bars[it[0]] = b
	# tg mood face and sanity
	var mf := HudWidgets.MoodFace.new()
	row.add_child(mf)
	bars["mood"] = mf

## Size a panel to its contents, keeping it pinned the way it grows (a centred panel
## stays centred, a right-hand one keeps its right edge).
func fit_panel(pn: Control) -> void:
	var ms := pn.get_combined_minimum_size()
	match pn.grow_horizontal:
		Control.GROW_DIRECTION_BEGIN:
			pn.offset_left = pn.offset_right - ms.x
		Control.GROW_DIRECTION_BOTH:
			var cx := (pn.offset_left + pn.offset_right) * 0.5
			pn.offset_left = roundf(cx - ms.x * 0.5)
			pn.offset_right = pn.offset_left + ms.x
		_:
			pn.offset_right = pn.offset_left + ms.x
	match pn.grow_vertical:
		Control.GROW_DIRECTION_BEGIN:
			pn.offset_top = pn.offset_bottom - ms.y
		Control.GROW_DIRECTION_BOTH:
			var cy := (pn.offset_top + pn.offset_bottom) * 0.5
			pn.offset_top = roundf(cy - ms.y * 0.5)
			pn.offset_bottom = pn.offset_top + ms.y
		_:
			pn.offset_bottom = pn.offset_top + ms.y

func set_zone(z: String) -> void:
	if Game.player == null:
		return
	Game.player.c(&"mob").aim_at_zone(z)
	_on_aim_changed()

func set_aim_preset(i: int) -> void:
	if Game.player == null:
		return
	Game.player.c(&"mob").set_aim_preset(i)
	_on_aim_changed()

func _on_aim_changed() -> void:
	var m: CMob = Game.player.c(&"mob") if Game.player else null
	if m:
		aim_caption.text = "AIM  %s" % Combat.ZONE_NAMES[m.aimed_zone()].to_upper()

func set_intent(i: String) -> void:
	var p := Game.player
	if p == null:
		return
	var m: CMob = p.c(&"mob")
	if m.intent != i:
		m.intent = i
		Sfx.play_ui("ui_tick", 0.5)
	_refresh_action_icons()

## Burgerstation's three paces: walk, run, sneak.
func set_move_mode(mode: String) -> void:
	var p := Game.player
	if p == null:
		return
	var m: CMob = p.c(&"mob")
	m.run = mode == "run"
	m.sneak = mode == "sneak"
	Game.tell(p, {"walk": "You will now walk.", "run": "You will now run.", "sneak": "You start sneaking."}[mode])
	_refresh_action_icons()

func _action_button(icon: String, id: String, tip: String, sz := 44) -> Button:
	var b := UITheme.icon_button(icon, tip, sz)
	b.pressed.connect(func(): _action(id))
	action_buttons[id] = b
	return b

func _build_misc() -> void:
	hover_label = UITheme.label("", 17, Color.WHITE)
	hover_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hover_label.add_theme_constant_override("outline_size", 5)
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hover_label)
	context = PopupMenu.new()
	context.id_pressed.connect(_on_context)
	root.add_child(context)
	var window_layer := CanvasLayer.new()
	window_layer.layer = 21
	root.add_child(window_layer)
	_window_layer = window_layer
	windows = Control.new()
	windows.theme = root.theme
	windows.set_anchors_preset(Control.PRESET_TOP_LEFT)
	windows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_layer.add_child(windows)
	apply_ui_scale()
	banner = PanelContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(-380, 70)
	banner.custom_minimum_size = Vector2(760, 0)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	var bv := VBoxContainer.new()
	banner.add_child(bv)
	banner_title = UITheme.label("", 22, UITheme.WARN)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(banner_title)
	banner_text = UITheme.label("", 16)
	banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(banner_text)
	root.add_child(banner)

# ------------------------------------------------------------------ chat
const LOG_COLORS := {"info": "#d2dde8", "warn": "#ffc45a", "bad": "#ff8272", "combat": "#ff8272", "combat_warn": "#ffc45a",
	"good": "#86f0ac", "examine": "#a8d8ff", "emote": "#c4b8e8", "announce": "#ffe98a", "say": "#f4f8fc", "radio": "#8ae88a"}

func _on_chat(text: String, kind: String) -> void:
	var col: String = LOG_COLORS.get(kind, "#d2dde8")
	var line := "[color=%s]%s[/color]" % [col, text]
	# the lines that want action get a tinted band behind them so they stand out in a scroll
	# of ordinary chatter, and announcements are bold
	match kind:
		"bad", "combat": line = "[bgcolor=#3c1616]%s[/bgcolor]" % line
		"warn", "combat_warn": line = "[bgcolor=#3a2a0c]%s[/bgcolor]" % line
		"announce": line = "[b]%s[/b]" % line
	add_line(line, kind)

func add_line(bb: String, kind: String) -> void:
	_chat_idle = 0.0
	message_log.preset = chat_filter
	match kind:
		"announce": Sfx.play_ui("ui_toast", 0.5)
		"good": Sfx.play_ui("ui_tick", 0.4, 1.3)
		"warn", "bad": Sfx.play_ui("ui_tick", 0.45, 0.75)
	_settle_line()
	message_log.add(bb, kind, Game.time)
	match message_log.result:
		"collapse":
			# only the last line changed (its x-count): patch that paragraph, not all 2000
			var entry: Dictionary = chat_lines[-1]
			if _last_para >= 0 and message_log.matches(entry):
				_drop_paragraphs_from(_last_para)
				_append_entry(entry, false)
		"popped":
			var gone := message_log.popped
			if not gone.is_empty() and message_log.matches(gone):
				var n: int = message_log.format_entry(gone).count("
") + 1
				for _i in n:
					if chat_log.get_paragraph_count() > 1:
						chat_log.remove_paragraph(0)
				if _last_para >= 0:
					_last_para = maxi(0, _last_para - n)
			var entry2: Dictionary = chat_lines[-1]
			if message_log.matches(entry2):
				_append_entry(entry2, true)
		_:
			var entry3: Dictionary = chat_lines[-1]
			if message_log.matches(entry3):
				_append_entry(entry3, true)
	_update_log_count()

# --- newest line slides in (LineInFx), then is swapped for plain text
var _last_para := -1       # first paragraph of the newest displayed entry
var _anim_id := 0
var _anim_from := -1       # paragraph where the animating line starts, or -1
var _anim_entry: Dictionary = {}

func _append_entry(entry: Dictionary, animate: bool) -> void:
	_last_para = maxi(0, chat_log.get_paragraph_count() - 1)
	if not animate or not is_inside_tree() or Engine.is_editor_hint():
		chat_log.append_text(message_log.format_entry(entry) + "
")
		return
	_anim_from = _last_para
	_anim_entry = entry
	chat_log.append_text("[linein t0=%d]%s[/linein]
" % [Time.get_ticks_msec(), message_log.format_entry(entry)])
	_anim_id += 1
	get_tree().create_timer(0.55).timeout.connect(_settle_if.bind(_anim_id))

func _settle_if(id: int) -> void:
	if id == _anim_id:
		_settle_line()

## Swap the animating line back to plain text (one paragraph, so O(1)).
func _settle_line() -> void:
	if _anim_from < 0:
		return
	var from := _anim_from
	var entry := _anim_entry
	_anim_from = -1
	_anim_entry = {}
	_anim_id += 1
	if from >= chat_log.get_paragraph_count():
		return
	_drop_paragraphs_from(from)
	chat_log.append_text(message_log.format_entry(entry) + "
")

func _drop_paragraphs_from(first: int) -> void:
	# the last paragraph is the empty one after the final newline: leave it
	var n := chat_log.get_paragraph_count() - 1 - first
	for _i in maxi(n, 0):
		chat_log.remove_paragraph(first)

func _rebuild_chat(preserve_scroll := false) -> void:
	message_log.preset = chat_filter
	_anim_from = -1
	_anim_id += 1
	_last_para = -1
	var bar := chat_log.get_v_scroll_bar()
	var scroll := bar.value
	var reading_history := preserve_scroll and scroll + bar.page < bar.max_value - 1.0
	chat_log.clear()
	for l in chat_lines:
		if message_log.matches(l):
			_last_para = maxi(0, chat_log.get_paragraph_count() - 1)
			chat_log.append_text(message_log.format_entry(l) + "
")
	if not message_log.follow or reading_history:
		chat_log.get_v_scroll_bar().set_deferred("value", scroll)
	_update_log_count()

func _update_log_count() -> void:
	var shown := 0
	for entry in chat_lines:
		if message_log.matches(entry): shown += 1
	log_count.text = "%d / %d messages · %s" % [shown, chat_lines.size(), "Live" if message_log.follow else "Reading history"]

func _sync_log_options() -> void:
	var menu := log_options.get_popup()
	for i in MessageLog.CATEGORIES.size():
		menu.set_item_checked(menu.get_item_index(i), message_log.enabled[MessageLog.CATEGORIES[i]])
	for pair in [[20, message_log.timestamps], [21, message_log.follow], [22, message_log.collapse]]:
		menu.set_item_checked(menu.get_item_index(pair[0]), pair[1])
	for i in 3:
		menu.set_item_checked(menu.get_item_index(30 + i), message_log.font_size == UITheme.LOG_SIZES[i])

func _log_option(id: int) -> void:
	if id < MessageLog.CATEGORIES.size():
		var cat: String = MessageLog.CATEGORIES[id]
		message_log.enabled[cat] = not message_log.enabled[cat]
	elif id == 20: message_log.timestamps = not message_log.timestamps
	elif id == 21: message_log.follow = not message_log.follow
	elif id == 22: message_log.collapse = not message_log.collapse
	elif id in [30, 31, 32]: set_log_text_size(UITheme.LOG_SIZES[id - 30])
	elif id == 40:
		DisplayServer.clipboard_set(message_log.plain_text())
		return
	elif id == 41:
		var dialog := FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.filters = PackedStringArray(["*.txt ; Text log"])
		dialog.current_file = "skyfarer-log.txt"
		dialog.file_selected.connect(func(path: String):
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_string(message_log.plain_text() + "\n")
			else:
				Game.msg("Could not save the message log.", "warn")
			dialog.queue_free())
		dialog.canceled.connect(dialog.queue_free)
		root.add_child(dialog)
		dialog.popup_centered(Vector2i(700, 480))
		return
	chat_log.scroll_following = message_log.follow
	for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		chat_log.add_theme_font_size_override(key, message_log.font_size)
	message_log.save_settings()
	_sync_log_options()
	_rebuild_chat()

func _on_speech(speaker: Entity, text: String, cell: Vector2i, radius: float) -> void:
	var p := Game.player
	if p == null:
		return
	var d := maxi(absi(cell.x - p.cell.x), absi(cell.y - p.cell.y))
	if d > radius:
		return
	var ph: CHealth = p.c(&"health")
	if ph and speaker != p and (StatusFx.deaf(ph) or ph.knocked_out()):
		return # tg: deaf or out cold, you don't hear it
	var verb := "says"
	if text.ends_with("?"):
		verb = "asks"
	elif text.ends_with("!"):
		verb = "exclaims"
	if radius <= 2.0:
		verb = "mutters"
	var nm := speaker.display_name
	var spoken := text
	var sh: CHealth = speaker.c(&"health")
	if sh and sh.helium_voice:
		verb = "squeaks"
		text = "[font_size=12]%s[/font_size]" % text
	add_line("[color=#e8eef4][b]%s[/b] %s, \"%s\"[/color]" % [nm, verb, text], "say")
	if radius > 2.0 and (Game.lighting == null or Game.lighting.player_can_see(cell)):
		bubble(speaker, spoken)

func _on_radio(speaker: Entity, channel: String, text: String, fact: Dictionary) -> void:
	var p := Game.player
	if p == null:
		return
	var inv: CInventory = p.c(&"inv")
	var hs := inv.headset() if inv else null
	if hs == null or not channel in hs.channels:
		# tg intercoms: their speaker plays Common to anyone standing nearby; an antenna
		# mutation hears Common too
		var pm: CMob = p.c(&"mob")
		if channel != "Common" or not (Game.in_radius(p.cell, 2, &"fixture").any(func(x): return x.c(&"fixture").kind == "intercom") or (pm and pm.has_antenna())):
			return
	var col: Color = Defs.RADIO_COLORS.get(channel, Color("#7ad87a"))
	var who := speaker.display_name if speaker else fact.get("speaker_name", "Ship")
	var job := ""
	if speaker and speaker.has_c(&"mob"):
		job = " (%s)" % Jobs.title(speaker.c(&"mob").job)
	if speaker and speaker.has_c(&"health") and speaker.c(&"health").helium_voice:
		text = "[font_size=12]%s[/font_size]" % text
	add_line("[color=#%s][%s] [b]%s[/b]%s: %s[/color]" % [col.to_html(false), Defs.radio_label(channel), who, job, text], "radio")
	if speaker != p:
		Sfx.play("radio", p.cell, 0.25)

func _on_chat_submit(text: String) -> void:
	chat_input.visible = false
	chat_input.release_focus()
	chat_input.text = ""
	if text.strip_edges() == "" or Game.player == null:
		return
	if text.begins_with("*"):
		# tg: say "*scream", "*nod Bob", "*me waves" (Emotes)
		Emotes.emote(Game.player, text.substr(1), true)
		return
	Game.player.c(&"mob").say(text)

func open_chat(prefix := "") -> void:
	chat_input.visible = true
	chat_input.text = prefix
	chat_input.grab_focus()
	chat_input.caret_column = prefix.length()

func chat_active() -> bool:
	# any text field (chat, a console's reason box...) swallows movement keys
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit

## tg runechat for emotes: the action in italics above them.
func bubble_emote(ent: Entity, text: String) -> void:
	bubble(ent, "*%s*" % text.rstrip("."))
	var b: Dictionary = bubbles[-1] if not bubbles.is_empty() else {}
	if b.get("ent") == ent:
		b["node"].add_theme_color_override("font_color", Color(0.85, 0.87, 0.95))

func bubble(ent: Entity, text: String) -> void:
	if Game.view == null:
		return
	var l := Label.new()
	l.text = text if text.length() < 60 else text.substr(0, 57) + "..."
	l.add_theme_font_override("font", UITheme.mono)
	l.add_theme_font_size_override("font_size", 26)
	if ent.has_c(&"health") and ent.c(&"health").helium_voice:
		l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 1))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.scale = Vector2(0.5, 0.5)
	l.z_index = 20
	Game.view.fx_layer.add_child(l)
	# stack above previous bubbles of the same speaker
	var stack := 0
	for b in bubbles:
		if b["ent"] == ent:
			stack += 1
	bubbles.append({"node": l, "ent": ent, "t": 4.5 + text.length() * 0.04, "stack": stack})

func _update_bubbles(delta: float) -> void:
	for b in bubbles.duplicate():
		b["t"] -= delta
		var n: Label = b["node"]
		var e: Entity = b["ent"]
		if b["t"] <= 0 or not is_instance_valid(e) or e.removed:
			n.queue_free()
			bubbles.erase(b)
			continue
		var w := n.size.x * n.scale.x
		n.position = e.position + Vector2(-w * 0.5, -46 - b["stack"] * 9)
		n.modulate.a = clampf(b["t"], 0.0, 1.0)
		if Game.lighting and not Game.lighting.player_can_see(e.cell):
			n.modulate.a = 0.0
	# re-stack when older ones expire
	var seen := {}
	for i in range(bubbles.size() - 1, -1, -1):
		var b2: Dictionary = bubbles[i]
		var k: Entity = b2["ent"]
		b2["stack"] = seen.get(k, 0)
		seen[k] = b2["stack"] + 1

func _on_announcement(title: String, text: String, severity: int) -> void:
	banner.visible = true
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", [UITheme.ACCENT, UITheme.WARN, UITheme.BAD][clampi(severity, 0, 2)])
	banner_text.text = text
	banner_t = 9.0
	banner.modulate.a = 1.0
	add_line("[color=#ffe07a][b]%s[/b]: %s[/color]" % [title, text], "announce")
	if Game.player:
		Sfx.play("ding" if severity == 0 else "alarm", Game.player.cell, 0.4)

# ------------------------------------------------------------------ inventory
func refresh_inventory() -> void:
	var p := Game.player
	if p == null:
		return
	var inv: CInventory = p.c(&"inv")
	for s in slots.keys():
		var sl: InvSlot = slots[s]
		if s.begins_with("hot_"):
			var hb: Array = p.c(&"mob").hotbar
			var hi := int(s.substr(4))
			if hb[hi] != null and (not is_instance_valid(hb[hi]) or hb[hi].removed or not DragDrop.carried(p, hb[hi])):
				hb[hi] = null
			sl.set_item(hb[hi])
			sl.active = hb[hi] != null and hb[hi] == inv.active_item()
		elif s == "hand_l":
			sl.active = inv.active == 0
			sl.set_item(inv.hands[0])
		elif s == "hand_r":
			sl.active = inv.active == 1
			sl.set_item(inv.hands[1])
		else:
			sl.set_item(inv.worn(s))
			if s in ["back", "belt"]:
				sl.active = bag_open != null and bag_open == inv.worn(s)
		sl.queue_redraw()
	_refresh_rows(true)
	if windows != null:
		for w in windows.get_children():
			if w is UIWindow and w.kind == "inventory" and not w.is_queued_for_deletion():
				w._sync()

func _on_slot_clicked(slot: String, button: int) -> void:
	var p := Game.player
	if p == null or Game.paused:
		return
	var inv: CInventory = p.c(&"inv")
	var h: CHealth = p.c(&"health")
	if not h.can_use_hands():
		return
	if slot.begins_with("craft_"):
		# clicking a grid cell takes the part back out
		craft_grid[int(slot.substr(6))] = null
		for w in windows.get_children():
			if w is UIWindow and w.kind == "crafting":
				w.refresh_t = 0.0
		return
	if slot.begins_with("hot_"):
		var hi := int(slot.substr(4))
		if button == MOUSE_BUTTON_RIGHT:
			p.c(&"mob").hotbar[hi] = null
			refresh_inventory()
		else:
			use_hotbar(hi)
		return
	if button == MOUSE_BUTTON_RIGHT:
		var it: Entity = inv.hands[0] if slot == "hand_l" else (inv.hands[1] if slot == "hand_r" else inv.worn(slot))
		if it:
			show_context_for([it], true)
		return
	if slot == "hand_l" or slot == "hand_r":
		var idx := 0 if slot == "hand_l" else 1
		var there: Entity = inv.hands[idx]
		var held: Entity = inv.active_item()
		if inv.active == idx:
			if there != null:
				there.attack_self(p) # tg: clicking what's in your active hand uses it
		else:
			# clicking the other hand always switches to it; to move or combine items between
			# hands, drag one onto the other
			inv.active = idx
			if held != null or there != null:
				Sfx.play_ui("click")
		refresh_inventory()
		return
	var held := inv.active_item()
	var worn := inv.worn(slot)
	if held and worn == null:
		if not inv.equip(held, slot):
			Game.tell(p, "You can't put %s there." % held.the(), "warn")
		else:
			inv.hands[inv.active] = null if inv.hands[inv.active] == held else inv.hands[inv.active]
			inv._refresh()
	elif held and worn and worn.has_c(&"storage") and worn.c(&"storage").kind == "bag":
		worn.attackby(p, held)
	elif worn and held == null:
		if worn.has_c(&"storage") and worn.c(&"storage").kind == "bag" and Input.is_key_pressed(KEY_SHIFT) and slot in ["back", "belt"]:
			open_window("storage", worn)
		elif worn.has_c(&"storage") and worn.c(&"storage").kind == "bag" and slot in ["back", "belt"]:
			# Burgerstation: the bag opens as a row of slots above your hands (Shift+click
			# for the full window)
			bag_open = null if bag_open == worn else worn
		else:
			inv.unequip(slot)
	refresh_inventory()

## A hotbar key: draw the item into a free hand (or switch to the hand holding it); if
## it's already in your active hand, use it.
func use_hotbar(i: int) -> void:
	var p := Game.player
	if p == null or not p.c(&"health").can_use_hands():
		return
	var inv: CInventory = p.c(&"inv")
	var it: Entity = p.c(&"mob").hotbar[i]
	if it == null or not is_instance_valid(it) or not DragDrop.carried(p, it):
		refresh_inventory()
		return
	var hand := inv.hands.find(it)
	if hand >= 0:
		if inv.active == hand:
			it.attack_self(p)
		else:
			inv.active = hand
	else:
		var free := inv.active if inv.hands[inv.active] == null else inv.free_hand()
		if free < 0:
			Game.tell(p, "Your hands are full.", "warn")
		elif DragDrop.apply(p, it, {"kind": "hand", "idx": free}, false):
			inv.active = free
	refresh_inventory()

## Rebuild the bag and floor rows when what they show changes.
func _refresh_rows(force := false) -> void:
	var p := Game.player
	if p == null or bag_row == null:
		return
	var inv: CInventory = p.c(&"inv")
	if bag_open and (not is_instance_valid(bag_open) or bag_open.removed or not DragDrop.carried(p, bag_open)):
		bag_open = null
	if bag_open:
		var st: CStorage = bag_open.c(&"storage")
		bag_caption.text = "%s   %d / %d" % [bag_open.display_name.to_upper(), st.used(), st.capacity]
	var bag_items: Array = bag_open.c(&"storage").contents if bag_open else []
	var floor_items := []
	for e in Game.at(p.cell):
		if e.has_c(&"item") and e.holder == null and e.visible and not e.removed:
			floor_items.append(e)
	var sig := "%s|%s|%s" % [bag_open.id if bag_open else 0, bag_items.map(func(x): return x.id), floor_items.map(func(x): return x.id)]
	# A hand update must not replace unchanged bag/floor controls under the cursor.
	if sig == _rows_sig:
		return
	_rows_sig = sig
	# detach the old slots now: queued-for-deletion children still count towards the
	# panel's minimum size, and the hands panel would be fitted twice as wide as it is
	for row in [bag_row, floor_row]:
		for c in row.get_children():
			row.remove_child(c)
			c.queue_free()
	bag_box.visible = bag_open != null
	if bag_open:
		var n := maxi(bag_items.size() + 1, mini(8, bag_items.size() + 3))
		bag_row.columns = mini(n, 10)
		for i in n:
			var sl := InvSlot.new("bagcell_%d" % i, "", 44)
			sl.container = bag_open
			sl.set_item(bag_items[i] if i < bag_items.size() else null)
			sl.clicked.connect(_on_row_clicked.bind(sl))
			bag_row.add_child(sl)
	floor_box.visible = not floor_items.is_empty()
	for it in floor_items.slice(0, 8):
		var fs := InvSlot.new("floor", "", 44)
		fs.set_item(it)
		fs.tooltip_text = it.display_name.capitalize() + "\nClick to pick up, or drag it somewhere."
		fs.clicked.connect(_on_row_clicked.bind(fs))
		floor_row.add_child(fs)
	_restack_bottom.call_deferred()

## Keep the examine bar and alerts sitting just above the hands panel as it grows.
func _restack_bottom() -> void:
	var hp: Control = panels["hands"]
	if layout_mode:
		return
	fit_panel(hp)
	var xb: Control = panels["examine"]
	xb.offset_bottom = hp.offset_top - 6
	fit_panel(xb)
	alerts_box.offset_bottom = xb.offset_bottom - 44
	fit_panel(alerts_box)

func _on_row_clicked(_slot: String, button: int, sl: InvSlot) -> void:
	var p := Game.player
	if p == null or Game.paused or not p.c(&"health").can_use_hands():
		return
	var inv: CInventory = p.c(&"inv")
	if button == MOUSE_BUTTON_RIGHT:
		if sl.item:
			show_context_for([sl.item], true)
		return
	var held := inv.active_item()
	if sl.item == null:
		# an empty bag cell: put what you hold in the bag
		if held and sl.container:
			DragDrop.apply(p, held, {"kind": "store", "container": sl.container}, false)
	elif held and sl.item.has_c(&"storage") and sl.item.c(&"storage").kind == "bag":
		sl.item.attackby(p, held)
	elif held == null:
		DragDrop.apply(p, sl.item, {"kind": "hand", "idx": inv.active}, false)
	else:
		Interact.use_item_on(p, held, sl.item)
	refresh_inventory()

func _action(id: String) -> void:
	var p := Game.player
	if p == null or Game.paused:
		return
	var m: CMob = p.c(&"mob")
	var inv: CInventory = p.c(&"inv")
	if id in ["drop", "use", "equip", "throw", "internals"] and not p.c(&"health").can_use_hands():
		Game.tell(p, "You can't do that right now.", "warn")
		return
	match id:
		"use":
			var item := inv.active_item()
			if item:
				item.attack_self(p)
		"equip":
			var item := inv.active_item()
			if item and not inv.quick_equip(item):
				Game.tell(p, "You can't equip that.", "warn")
		"drop":
			Interact.drop_active(p)
		"swap":
			inv.active = 1 - inv.active
		"throw":
			throw_mode = not throw_mode
			Game.tell(p, "Throw mode %s." % ("on" if throw_mode else "off"))
		"pull":
			m.stop_pulling()
		"resist":
			_resist(p)
		"internals":
			var mask: Entity = inv.worn("mask")
			if mask == null or not mask.c(&"clothing").breath_mask:
				Game.tell(p, "You need a breath mask on to use your gas cylinder.", "warn")
			elif not m.internals and Game.life._internals_tank(p) == null:
				Game.tell(p, "You have no gas cylinder.", "warn")
			else:
				m.internals = not m.internals
				Game.tell(p, "You %s your gas cylinder." % ("open" if m.internals else "close"))
		"combat":
			# R flips between help and harm, like tg's old combat mode
			set_intent("help" if m.combat else "harm")
		"run":
			# C cycles walk -> run -> sneak
			set_move_mode("sneak" if m.run else ("walk" if m.sneak else "run"))
	refresh_inventory()
	_refresh_action_icons()

func _refresh_action_icons() -> void:
	var p := Game.player
	if p == null:
		return
	var m: CMob = p.c(&"mob")
	for k in intent_buttons:
		var b: Button = intent_buttons[k]
		if b.button_pressed != (m.intent == k):
			b.set_pressed_no_signal(m.intent == k)
	var mode := "sneak" if m.sneak else ("run" if m.run else "walk")
	for k in move_buttons:
		var b2: Button = move_buttons[k]
		if b2.button_pressed != (mode == k):
			b2.set_pressed_no_signal(mode == k)
	action_buttons["throw"].set_pressed_no_signal(throw_mode)
	action_buttons["throw"].toggle_mode = true
	action_buttons["internals"].toggle_mode = true
	action_buttons["internals"].set_pressed_no_signal(m.internals)
	action_buttons["pull"].disabled = m.pulling == null
	if auto_btn.button_pressed != m.auto_resist:
		auto_btn.set_pressed_no_signal(m.auto_resist)
	target_doll.mob = m
	target_doll.health = p.c(&"health")
	target_doll.inv = p.c(&"inv")
	_on_aim_changed()

func _resist(p: Entity) -> void:
	var h: CHealth = p.c(&"health")
	var m: CMob = p.c(&"mob")
	# tg container_resist_act: inside a DNA scanner
	if p.has_meta("inside"):
		var box: Entity = Game.get_entity(p.get_meta("inside"))
		if box and box.has_c(&"dnascanner"):
			box.c(&"dnascanner").container_resist(p)
			return
		if box and box.has_c(&"skillstation"):
			box.c(&"skillstation").container_resist(p)
			return
		if box and box.has_c(&"storage"):
			box.c(&"storage").container_resist(p)
			return
	if h.on_fire > 0:
		h.knockdown(2.5)
		h.on_fire = maxf(0.0, h.on_fire - 5.0)
		m.emote("stops, drops and rolls!")
	elif m.buckled != null and not h.cuffed:
		Buckle.unbuckle(p, p)
	elif m.pulled_by:
		if randf() < m.resist_chance():
			m.pulled_by.c(&"mob").stop_pulling()
			Game.tell(p, "You break free!")
		else:
			Game.tell(p, "You struggle against the grip.")
	elif h.cuffed and m.buckled != null:
		# tg: cuffed and strapped down, working the buckle loose takes a minute
		Game.tell(p, "You start working at the buckle with your cuffed hands...")
		DoAfter.start(p, null, 60.0, func(ok):
			if ok:
				Buckle.unbuckle(p, p)
		)
	elif h.cuffed:
		Game.tell(p, "You start wriggling out of the cuffs (this will take a while)...")
		DoAfter.start(p, null, 40.0, func(ok):
			if ok:
				h.cuffed = false
				Game.tell(p, "You slip out of the handcuffs!", "good")
				Proto.spawn("handcuffs", p.cell)
		)

# ------------------------------------------------------------------ context menu
func show_context_for(ents: Array, for_inventory := false, tile := Vector2i(-1, -1)) -> void:
	var p := Game.player
	context.clear()
	context_actions.clear()
	var id := 0
	for e in ents:
		if not is_instance_valid(e):
			continue
		context.add_separator(e.display_name.capitalize())
		context.add_item("  Examine", id)
		context_actions.append(func(): Interact.examine(p, e, e.root_cell()))
		id += 1
		for v in e.get_verbs(p):
			context.add_item("  " + v["name"], id)
			context_actions.append(v["cb"])
			id += 1
		if for_inventory and e.holder == p:
			context.add_item("  Use in hand", id)
			context_actions.append(func():
				if p.c(&"health").can_use_hands() and e in p.c(&"inv").hands:
					e.attack_self(p)
			)
			id += 1
			context.add_item("  Drop", id)
			context_actions.append(func():
				if p.c(&"health").can_use_hands() and e.holder == p:
					var inv: CInventory = p.c(&"inv")
					if e in inv.hands:
						var previous := inv.active
						inv.active = inv.hands.find(e)
						Interact.drop_active(p)
						inv.active = previous
					elif not e.get_meta("nodrop", false):
						inv.drop(e)
			)
			id += 1
	# the tile itself (walls, windows, floors aren't entities), like tg's turf entry
	if tile.x >= 0 and Game.map.inb(tile):
		var sname: String = ["", "window", "grille", "girder", "cracked window"][Game.map.structure[Game.map.idx(tile)]]
		var tname: String = sname if sname != "" else Defs.TURFS[Game.map.get_turf(tile)]["name"]
		context.add_separator(tname.capitalize())
		context.add_item("  Examine", id)
		context_actions.append(func(): Interact.examine(p, null, tile))
		id += 1
	if id == 0:
		return
	context.position = Vector2i(get_viewport().get_mouse_position())
	context.reset_size()
	context.popup()

func _on_context(id: int) -> void:
	if id >= 0 and id < context_actions.size():
		context_actions[id].call()
		refresh_inventory()

# ------------------------------------------------------------------ windows
func toggle_inventory() -> void:
	if Game.player == null:
		return
	for w in windows.get_children():
		if w is UIWindow and w.kind == "inventory" and not w.is_queued_for_deletion():
			_end_drag()
			w.queue_free()
			return
	var panel := InventoryPanel.new()
	windows.add_child(panel)
	panel.place_initial(0)
	panel._want = (root.size - panel.size) * 0.5
	panel._clamp.call_deferred()

func close_front_window() -> bool:
	for i in range(windows.get_child_count() - 1, -1, -1):
		var w := windows.get_child(i)
		if w is UIWindow and w.visible and not w.is_queued_for_deletion():
			w.queue_free()
			return true
	return false

func open_window(kind: String, target: Entity) -> void:
	if Game.player == null and not kind in ["help", "chronicle"]:
		return
	for w in windows.get_children():
		if w is UIWindow and not w.is_queued_for_deletion() and w.kind == kind and w.target == target:
			w.queue_free()
			return
	if target and Game.player and target != Game.player and Game.player.adjacent(target):
		Forensics.touch(target, Game.player) # tg atom/interact: add_fingerprint
	var w := UIWindow.new(Windows.title(kind, target), Windows.width(kind, target))
	w.kind = kind
	w.target = target
	w.refresh_fn = func(body): Windows.build(kind, target, body, w)
	w.interval = Windows.interval(kind)
	w.mouse_filter = Control.MOUSE_FILTER_STOP
	windows.add_child(w)
	w.place_initial(windows.get_child_count())

# ------------------------------------------------------------------ per-frame
func _process(delta: float) -> void:
	var p := Game.player
	_update_bubbles(delta)
	_update_xp_pops(delta)
	if banner_t > 0:
		banner_t -= delta
		if banner_t < 1.0:
			banner.modulate.a = banner_t
		if banner_t <= 0:
			banner.visible = false
	# the overlay only draws do-after bars and the AI debug text: skip the redraw (and the
	# canvas item rebuild) on the frames where there is nothing to show
	var want_overlay: bool = debug_ai or not DoAfter.active.is_empty()
	if want_overlay or _overlay_dirty:
		overlay.queue_redraw()
	_overlay_dirty = want_overlay
	if p == null or not is_instance_valid(p):
		return
	var _t := UIPerf.t0()
	_update_status(p)
	_tick_purse(delta)
	_update_chat_fade(delta)
	UIPerf.end("hud.status", _t)
	_t = UIPerf.t0()
	_update_hover()
	UIPerf.end("hud.hover", _t)
	_t = UIPerf.t0()
	_update_screen_fx(p, delta)
	UIPerf.end("hud.screenfx", _t)
	if UIPerf.on:
		UIPerf.tick(delta)
		_perf_count += 1
		if _perf_count % 300 == 0:
			var np := 0
			var nv := 0
			var stack: Array = [self]
			while not stack.is_empty():
				var nd: Node = stack.pop_back()
				if nd.is_processing():
					np += 1
					if nd is CanvasItem and not nd.is_visible_in_tree():
						nv += 1
				stack.append_array(nd.get_children())
			print("UIPERF processing nodes under HUD: %d (hidden: %d)" % [np, nv])

var _slow_t := 0.0
var _overlay_dirty := false
var _fx_cache := {}
var _perf_count := 0

## The purse counts up (or down) to a new total, flashing green when you are paid and red
## when you spend, so a sale is something you see rather than notice afterwards.
func _tick_purse(delta: float) -> void:
	if _purse_target < 0:
		return
	if _purse_text == "":
		_purse_shown = float(_purse_target)
	var diff := float(_purse_target) - _purse_shown
	if absf(diff) > 0.01:
		if _purse_flash * diff <= 0.0:
			_purse_flash = 1.0 if diff > 0.0 else -1.0
		# close most of the gap in about 0.6 s whatever its size, at least one mark a frame
		var step := maxf(absf(diff) * minf(1.0, delta * 5.0), 1.0)
		_purse_shown = _purse_shown + signf(diff) * minf(step, absf(diff))
		_purse_flash = signf(_purse_flash) * 1.0
	else:
		_purse_flash = move_toward(_purse_flash, 0.0, delta * 1.6)
	var txt := "%s marks" % Economy.money(int(roundf(_purse_shown)))
	if txt != _purse_text:
		_purse_text = txt
		purse_label.text = txt
		_fit_clock.call_deferred()
	var col := PURSE_COL
	if _purse_flash > 0.0:
		col = PURSE_COL.lerp(UITheme.GOOD.lightened(0.3), absf(_purse_flash))
	elif _purse_flash < 0.0:
		col = PURSE_COL.lerp(UITheme.BAD.lightened(0.25), absf(_purse_flash))
	purse_label.add_theme_color_override("font_color", col)

# --- the message log folds its controls away and dims when nothing has happened for a while
var _chat_idle := 0.0
var _chat_controls: Array = []
var _chat_folded := false

## A panel whose contents grew (a longer purse, a wider label) is refitted; containers only
## ever report the new minimum, they do not move the anchored edges for us.
func _refit_cramped() -> void:
	if layout_mode:
		return
	for k in ["clock", "chat"]:
		var pn: Control = panels[k]
		var ms := pn.get_combined_minimum_size()
		if pn.size.x + 0.5 < ms.x or pn.size.y + 0.5 < ms.y:
			pn.reset_size()
			fit_panel(pn)

var _hands_dx := 0.0

## On a narrow canvas the centred hands panel runs into the vitals panel on its right (or
## the worn-gear grid on its left). Slide it sideways just far enough, and back again when
## there is room.
func _dodge_hands() -> void:
	if layout_mode:
		return
	var hp: Control = panels["hands"]
	var cp: Control = panels["combat"]
	var ep: Control = panels["equipment"]
	var hr := hp.get_global_rect()
	var left_limit := ep.get_global_rect().end.x + 8.0
	var right_limit := cp.get_global_rect().position.x - 8.0
	var natural := hr.position.x - _hands_dx           # where it would sit, centred
	var want := 0.0
	if natural + hr.size.x > right_limit:
		want = right_limit - (natural + hr.size.x)
		if natural + want < left_limit:
			want = maxf(want, left_limit - natural)
	if absf(want - _hands_dx) > 0.5:
		var d := want - _hands_dx
		hp.offset_left += d
		hp.offset_right += d
		_hands_dx = want

func _update_chat_fade(delta: float) -> void:
	var pn: Control = panels["chat"]
	var busy := layout_mode or chat_input.visible or log_search.has_focus() or log_search.text != "" \
		or pn.get_global_rect().has_point(root.get_local_mouse_position())
	_chat_idle = 0.0 if busy else _chat_idle + delta
	var fold: bool = UITheme.idle_fade and _chat_idle > 6.0
	if fold != _chat_folded:
		_chat_folded = fold
		for c in _chat_controls:
			c.visible = not fold
		pn.reset_size()
		fit_panel(pn)
	var want_a := 0.55 if (UITheme.idle_fade and _chat_idle > 12.0) else 1.0
	pn.modulate.a = move_toward(pn.modulate.a, want_a, delta * (2.0 if want_a > pn.modulate.a else 0.5))

func _set_equip_open(on: bool, save := true) -> void:
	if equip_row == null:
		return
	equip_visible = on
	equip_row.visible = on
	if equip_toggle != null:
		equip_toggle.set_pressed_no_signal(on)
	if save:
		UITheme.equip_open = on
		UITheme.save_pref("ui", "equip_open", on)
	var pn: Control = panels.get("equipment")
	if pn != null:
		pn.reset_size()
		fit_panel(pn)

func _fit_clock() -> void:
	if not layout_mode:
		fit_panel(panels["clock"])

func _update_status(p: Entity) -> void:
	_slow_t -= get_process_delta_time()
	if _slow_t > 0:
		return
	_slow_t = 0.25
	_refit_cramped()
	_dodge_hands()
	var h: CHealth = p.c(&"health")
	var n: CNeeds = p.c(&"needs")
	var m: CMob = p.c(&"mob")
	var area := Game.map.area_at(p.cell)
	var ext_c = (Game.atmos.ext_temp if Game.atmos else Defs.EXT_TEMP) - Defs.T0C
	var here_t = (Game.atmos.temp_at(p.cell) if Game.atmos else 293.0) - Defs.T0C
	var alert_col: Color = Game.ALERT_COLORS[Game.alert_level]
	clock_time.text = Game.clock_string()
	_set_pill(alert_pill, Game.ALERT_NAMES[Game.alert_level], alert_col.darkened(0.15))
	var evac_txt := ""
	if Game.evac and Game.evac.mode in [Evac.CALLED, Evac.DOCKED, Evac.ESCAPE]:
		evac_txt = Game.evac.status_text().to_upper()
	_set_pill(evac_pill, evac_txt, UITheme.BAD if Game.evac and Game.evac.mode == Evac.DOCKED else UITheme.WARN.darkened(0.2))
	# Skyfarer: the place line says where you are in the sky, not just which room, because
	# "the Long Sky" is a fact the player needs far more often than "Open Sky".
	var place := area.name
	if Underdecks.stair_at(p.cell):
		place += "  [E: stairs]"
	if Game.sky != null and Game.sky.gen != null:
		var ring: String = Game.sky.gen.ring_name_at(Underdecks.world_cell(p))
		if not place.contains(ring):
			place += "  [%s]" % ring
	loc_label.text = place
	power_pill.visible = not (area.outdoor or area.powered("light"))
	# marks, the weather and whatever is currently running on you all live on one line,
	# because they are the three things a skyfarer checks without stopping walking
	_purse_target = Economy.purse(p)
	var extra := ""
	var wx: String = Game.sky.weather_text() if Game.sky != null else ""
	if wx != "":
		extra += "   [color=#9ad8ff]%s[/color]" % wx
	for b in SkyBuffs.active(p).slice(0, 4):
		extra += "   [color=%s]%s %ds[/color]" % [b["color"], b["name"], int(b["left"])]
	var temp_txt := "%.0f°C here   %.0f°C outside%s" % [here_t, ext_c, extra]
	if temp_label.text != temp_txt:
		temp_label.text = temp_txt
		# the plaque is exactly as wide as its text (it used to be pinned at 820 px, which
		# ran it under the tutorial card)
		_fit_clock.call_deferred()
	var sev := h.severity()
	# tg screwy_hud (hallucinations, anosognosia): the HUD lies about your health
	var screwy := Hallucinations.screwy(h)
	if screwy != "" and not h.dead:
		sev = {"healthy": 0, "hurt": maxi(sev, 3), "crit": 4, "dead": 5}.get(screwy, sev)
	var st = ["[color=#6ae88a]Healthy[/color]", "[color=#b8d84a]Scratched[/color]", "[color=#e8c83a]Hurt[/color]", "[color=#ff9a4a]Badly hurt[/color]", "[color=#ff4a3a]CRITICAL[/color]", "[color=#8a8a8a]DEAD[/color]"][sev]
	var tags := ""
	if m.internals:
		tags += "  [color=#6a9aff]on cylinder[/color]"
	if m.pulled_by:
		tags += "  [color=#ff9a5a]grabbed[/color]"
	name_label.text = "[b]%s[/b]  [color=#8aa0b4]%s[/color]\n%s%s" % [p.display_name, SkyClasses.title_of(p), st, tags]
	heartbeat.severity = sev
	heartbeat.bpm = 0.0 if h.dead else clampf(64.0 + n.stress * 0.35 + (100.0 - h.stamina) * 0.45 + h.pain * 0.3 + h.oxy * 0.4, 40.0, 190.0)
	bars["health"].set_value(h.health() if screwy == "" or h.dead else {"healthy": 100.0, "hurt": minf(h.health(), 35.0), "crit": -10.0, "dead": -100.0}.get(screwy, h.health()))
	bars["stamina"].set_value(h.stamina)
	bars["temp"].set_value((h.body_temp - 250.0) / 70.0 * 100.0)
	bars["temp"].tint = Color(1, 1, 1) if h.body_temp > 300 else (Color(0.6, 0.75, 1.3) if h.body_temp > 280 else Color(1.4, 0.6, 0.6))
	bars["temp"].low = 71.0
	bars["food"].set_value(n.nutrition)
	bars["water"].set_value(n.hydration)
	bars["energy"].set_value(n.energy)
	if p.has_c(&"mood"):
		bars["mood"].set_mood(p.c(&"mood"))
	_update_alerts(p)
	_refresh_action_icons()
	_refresh_rows()
	var hpn: Control = panels["hands"]
	if absf(hpn.size.x - hpn.get_combined_minimum_size().x) > 1.0 or absf(hpn.size.y - hpn.get_combined_minimum_size().y) > 1.0:
		_restack_bottom()
	# ambience
	var outdoors := 1.0 if Game.map.is_outdoor(p.cell) else 0.0
	var storm: float = Game.director.storm if Game.director else 0.0
	Sfx.update_ambience(outdoors, storm, area.fire_alarm, area.powered("equip") or area.outdoor)

## What's wrong with you, worst first (see AlertBar for the names and advice).
func _update_alerts(p: Entity) -> void:
	var h: CHealth = p.c(&"health")
	var n: CNeeds = p.c(&"needs")
	var m: CMob = p.c(&"mob")
	var list := []
	var add := func(id: String, sev: int, label := "", extra := ""):
		list.append({"id": id, "sev": sev, "label": label, "extra": extra})
	var W := AlertBar.WARN
	var B := AlertBar.BAD
	# breathing (tg lung alerts)
	if h.breath_status in ["low_o2", "no_air"]:
		add.call("oxy", B, "NO AIR" if h.breath_status == "no_air" else "THIN AIR")
	if h.breath_alerts.has("co2"):
		add.call("co2", B if h.breath_alerts["co2"] else W, "CO2")
	if h.breath_alerts.has("plasma"):
		add.call("plasma", B, "PLASMA")
	if h.breath_alerts.has("n2o"):
		add.call("n2o", B, "N2O")
	if h.breath_alerts.has("smoke"):
		add.call("smoke", W, "SMOKE")
	if h.on_fire > 0: add.call("fire", B, "ON FIRE")
	# knocked about
	if h.unconscious_t > 0.0: add.call("unconscious", B, "OUT %ds" % ceili(h.unconscious_t))
	elif h.has_status("sleeping") or h.sleeping: add.call("asleep", W, "ASLEEP")
	if h.stun_t > 0.0: add.call("stunned", B, "STUN %ds" % ceili(h.stun_t))
	if h.has_status("paralyzed"): add.call("paralyzed", B, "PARALYZED %ds" % ceili(h.status_left("paralyzed")))
	if h.knockdown_t > 0.0: add.call("floored", W, "DOWN %ds" % ceili(h.knockdown_t))
	if h.has_status("immobilized"): add.call("immobilized", W, "STUCK %ds" % ceili(h.status_left("immobilized")))
	if h.stamcrit: add.call("stamcrit", B, "EXHAUSTED", "You're too exhausted to keep going...")
	if h.stat() == CHealth.SOFT_CRIT: add.call("softcrit", B, "CRITICAL", "You're in critical condition: you can only crawl and whisper.")
	if StatusFx.blind(h) and not h.knocked_out(): add.call("blind", B, "BLIND", "You can't see! This may be caused by a genetic defect, eye trauma, being unconscious, or something covering your eyes.")
	if h.has_status("druggy"): add.call("high", W, "HIGH", "Whoa man, you're tripping balls! Careful you don't get addicted... if you aren't already.")
	# tg /atom/movable/screen/alert/embeddedobject
	if h.embedded.any(func(em): return not em["data"]["stealthy"]):
		add.call("embedded", B, "EMBEDDED ITEM", "Something got lodged into your flesh and is causing major bleeding. It might fall out with time, but surgery is the safest way. If you're feeling frisky, examine yourself and click the underlined item to pull the object out.")
	# tg fake_alert hallucination
	if h.has_meta("fake_alert"):
		var fa: Array = h.get_meta("fake_alert")
		add.call(fa[0], B, fa[1], "")
	# tg /atom/movable/screen/alert/status_effect/drunk, alert/gross|verygross|disgusted, trance
	if h.drunk >= StatusFx.TIPSY_THRESHOLD: add.call("drunk", W, "DRUNK", "All that alcohol you've been drinking is impairing your speech, motor skills, and mental cognition. Make sure to act like it.")
	if h.disgust >= Organs.DISGUST_LEVEL_DISGUSTED: add.call("disgust", B, "DISGUSTED", "ABSOLUTELY DISGUSTIN'. You feel like you're going to throw up.")
	elif h.disgust >= Organs.DISGUST_LEVEL_VERYGROSS: add.call("disgust", W, "VERY GROSS", "Hoo boy, that was disgusting. You might be sick.")
	elif h.disgust >= Organs.DISGUST_LEVEL_GROSS: add.call("disgust", W, "GROSS", "That was kind of gross...")
	if h.has_status("trance"): add.call("trance", W, "TRANCE", "Everything feels so distant, and you can feel your thoughts forming loops inside your head...")
	# temperature: tg species/handle_environment alerts (BODYTEMP_*_WARNING_1..3 on skin)
	var bt := h.body_temp
	var temp_txt := "Body temperature %.0f C." % (bt - Defs.T0C)
	var cold1 := Defs.BODYTEMP_COLD_DAMAGE_LIMIT
	var hot1 := Defs.BODYTEMP_HEAT_DAMAGE_LIMIT
	if bt < cold1 - 150.0: add.call("cold", B, "FREEZING", temp_txt)
	elif bt < cold1 - 70.0: add.call("cold", B, "COLD", temp_txt)
	elif bt < cold1: add.call("cold", W, "CHILLY", temp_txt)
	if bt > hot1 + 360.0: add.call("hot", B, "SCORCHING", temp_txt)
	elif bt > hot1 + 120.0: add.call("hot", B, "HOT", temp_txt)
	elif bt > hot1: add.call("hot", W, "WARM", temp_txt)
	# pressure: tg warning and hazard levels
	if Game.atmos:
		var kpa: float = Game.atmos.pressure_at(p.cell)
		var ptxt := "%.0f kPa here." % kpa
		if kpa < Defs.HAZARD_LOW_PRESSURE: add.call("lowpressure", B, "NO AIR", ptxt + " The air is far too thin to breathe.")
		elif kpa < Defs.WARNING_LOW_PRESSURE: add.call("lowpressure", W, "THIN AIR", ptxt)
		elif kpa > Defs.HAZARD_HIGH_PRESSURE: add.call("highpressure", B, "CRUSHING", ptxt)
		elif kpa > Defs.WARNING_HIGH_PRESSURE: add.call("highpressure", W, "HIGH PRES", ptxt)
	# body
	var br := Body.bleed_rate(h)
	if br >= Body.BLEED_OVERLAY_MED: add.call("bleeding", B, "BLEEDING", "Losing %.1f u of blood a second." % br)
	elif br > 0.0: add.call("bleeding", W, "BLEEDING", "Losing %.1f u of blood a second." % br)
	if h.determined: add.call("determined", W, "DETERMINED", "The serious wounds you've sustained have put your body into fight-or-flight mode! Now's the time to look for an exit!")
	var limping := false
	for lp in ["l_leg", "r_leg"]:
		for lw in Body.wounds_on(h, lp):
			if Body.wound_def(lw).get("limp", 0.0) > 0.0:
				limping = true
	if limping: add.call("limp", W, "LIMPING", "One or more of your legs has been wounded, slowing down steps with that leg! Get it fixed, or at least in a sling of gauze!")
	if h.pain > 60: add.call("pain", B, "AGONY")
	elif h.pain > 30: add.call("pain", W, "PAIN")
	if h.disease != null: add.call("sick", W, "SICK")
	if StatusFx.nearsight(h) > 0 or h.has_status("eye_blur"): add.call("blurry", W, "BLURRY")
	if StatusFx.deaf(h) and not h.knocked_out(): add.call("deaf", W, "DEAF", "You can't hear anything.")
	if h.stamina < 30.0 and h.stat() == CHealth.CONSCIOUS: add.call("winded", W, "WINDED", "Stamina %d%%." % int(h.stamina))
	# held
	if h.cuffed: add.call("cuffed", W, "CUFFED")
	if m and m.pulled_by != null: add.call("pulled", W, "GRABBED", "%s has hold of you." % m.pulled_by.display_name)
	if m and m.buckled != null: add.call("buckled", AlertBar.INFO, "BUCKLED", "Buckled to %s." % m.buckled.the())
	# needs
	for a in n.alerts():
		match a:
			"starving": add.call("starving", B, "STARVING")
			"hungry": add.call("hungry", W, "HUNGRY")
			"thirsty": add.call("thirsty", W, "THIRSTY")
			"tired": add.call("tired", W, "EXHAUSTED")
	# internals, with how much is left in the tank
	if h.breath_status == "internals" and Game.life:
		var tank: CTank = Game.life._internals_tank(p)
		if tank:
			var pct := int(round(tank.moles / maxf(0.01, tank.max_moles) * 100.0))
			add.call("internals", W if pct < 20 else AlertBar.INFO, "AIR %d%%" % pct, "%s: %d%% left." % [tank.e.display_name.capitalize(), pct])
	(alerts_box as AlertBar).set_alerts(list)

func _update_hover() -> void:
	if Game.view == null:
		return
	var mp := mouse
	var c: Vector2i = Game.view.cell_at_screen(mouse)
	Game.view.set_hover(c)
	var names := []
	if Game.lighting and Game.lighting.player_can_see(c):
		for e in PlayerController.entities_under_mouse():
			names.append(e.display_name)
		if names.is_empty() and Game.map.inb(c):
			names.append(Defs.TURFS[Game.map.get_turf(c)]["name"])
	var txt := ", ".join(names.slice(0, 3))
	_update_examine(c)
	if debug_atmos and Game.atmos and Game.map.inb(c):
		var i := Game.map.idx(c)
		txt += "\n%.1f kPa  %.1f K  O2 %.1f  CO2 %.1f  PL %.1f  smoke %.1f%s" % [Game.atmos.pressure(i), Game.atmos.temp[i], Game.atmos.partial(i, 0), Game.atmos.partial(i, 2), Game.atmos.partial(i, 3), Game.atmos.partial(i, 6), "  active" if Game.atmos.active.has(i) else ""]
	if PipeDebugLayer.enabled and Game.pipes and Game.map.inb(c):
		for l in StationMap.PIPE_LAYER_COUNT:
			var gs := Game.map.pipe_groups_at(l, c)
			for gi in gs.size():
				var net = Game.pipes.node_net[l].get(Game.map.idx(c) * 4 + gi)
				txt += "\n%s pipe: %s" % [StationMap.PIPE_LAYER_NAMES[l], Windows.net_summary(net) if net else "(no network)"]
	if hover_label.text != txt:
		hover_label.text = txt
	hover_label.position = to_ui(mp) + Vector2(18, 14)
	var hv := not over_hud(mouse)
	if hover_label.visible != hv:
		hover_label.visible = hv

## The examine bar above the hands: what's under the mouse and what a click would do.
func _update_examine(c: Vector2i) -> void:
	var p := Game.player
	var nm := ""
	var hint := ""
	if p and not over_hud(mouse) and Game.map.inb(c) and Game.lighting and Game.lighting.player_can_see(c):
		var ents := PlayerController.entities_under_mouse()
		var top: Entity = null
		for e in ents:
			if e != p:
				top = e
				break
		var m: CMob = p.c(&"mob")
		var held: Entity = p.c(&"inv").active_item()
		if top:
			var near := p.adjacent(top) or top.cell == p.cell
			if top.has_c(&"mob"):
				hint = {"help": "hug / help up", "disarm": "shove", "grab": "grab", "harm": "attack"}[m.intent]
				if held:
					hint = ("hit with " if m.intent != "help" else "use ") + held.display_name
				if top.c(&"health") and top.c(&"health").dead:
					hint = "dead  ·  " + hint
			elif top.has_c(&"item"):
				hint = "pick up  ·  drag to a slot" if held == null else "use %s on it" % held.display_name
			elif held:
				hint = "use %s on it" % held.display_name
			else:
				hint = "use"
			nm = (Quirks.seen_name(p, top) if top.has_c(&"mob") else top.display_name).capitalize() # tg prosopagnosia
			hint = ("too far  ·  " if not near else "") + hint + "  ·  right click for more"
			# atmos devices: its tg name and what it's doing right now
			# (only with a gas analyzer in hand)
			if (top.has_c(&"pipemachine") or top.has_c(&"vent") or top.has_c(&"meter")) and AtmosOverlay.analyzer_view():
				nm = AtmosOverlay.label_for(top)
				var d := AtmosOverlay.describe(top)
				hint = "  ·  ".join(PackedStringArray(["too far"] if not near else []) + PackedStringArray([d] if d != "" else []))
		elif PipeHover.hovered != null:
			# pointing at an exposed pipe: what the whole network is carrying
			var net = PipeHover.hovered
			nm = PipeHover.net_name(net)
			hint = PipeHover.readout(net)
			if Game.map.pipe_links.has(Game.map.idx(c)):
				# tg layer manifold: the square box where pipes on different layers join
				nm = "Layer adaptor  (%s)" % nm
				hint = "joins the pipe layers on this tile into one line  ·  " + hint
		else:
			nm = Defs.TURFS[Game.map.get_turf(c)]["name"].capitalize()
			var ar := Game.map.area_at(c)
			if ar.room_kind == "gas_chamber":
				nm = ar.name
				if AtmosOverlay.analyzer_view():
					hint = PipeHover.air_readout(c)
	if examine_label.text != nm or examine_hint.text != hint:
		examine_label.text = nm
		examine_label.add_theme_color_override("font_color", Color.WHITE if hint != "" else UITheme.DIM)
		examine_hint.text = hint
		examine_hint.visible = hint != ""
		panels["examine"].visible = nm != ""
		if not layout_mode:
			fit_panel(panels["examine"])

## Shader uniforms only cross to the renderer when they change.
func _fx(k: String, v) -> void:
	if _fx_cache.get(k) != v:
		_fx_cache[k] = v
		fx_full.set_shader_parameter(k, v)
		fx_lite.set_shader_parameter(k, v)

func _update_screen_fx(p: Entity, _delta: float) -> void:
	var h: CHealth = p.c(&"health")
	# frost creeps in only once you're below tg's first cold warning
	var frost := clampf((Defs.BODYTEMP_COLD_DAMAGE_LIMIT - h.body_temp) / 70.0, 0.0, 1.0)
	_fx("frost", frost)
	var outdoors := Game.map.is_outdoor(p.cell)
	var storm: float = Game.director.storm if Game.director else 0.0
	_fx("blizzard", storm * (0.85 if outdoors else 0.0))
	# tg update_damage_hud: stepped brute, oxygen and crit overlays
	var dh := h.damage_hud()
	_fx("brute_sev", float(dh["brute"]))
	_fx("oxy_sev", float(dh["oxy"]))
	_fx("crit_sev", float(dh["crit"]))
	_fx("critvision", float(dh["critvision"]))
	_fx("aurora", Game.lighting.aurora if Game.lighting and outdoors else 0.0)
	_fx("blur", clampf(maxf(StatusFx.nearsight(h) * 0.15, StatusFx.blur_amount(h)), 0.0, 1.0))
	_fx("flash", clampf(h.status_left("flash_overlay") / 2.5, 0.0, 1.0))
	_fx("blind", 0.0 if h.dead or Psyker.can_echo(Game.player) else (1.0 if h.knocked_out() else (0.985 if StatusFx.blind(h) else 0.0)))
	_fx("high", 1.0 if h.has_status("druggy") else 0.0)
	_fx("psychic", 1.0 if h.has_status("psychic_projection") else 0.0)
	_fx("mono", 1.0 if Traumas.colorblind(h) else 0.0)
	var need_full: bool = float(_fx_cache.get("mono", 0.0)) > 0.0 or float(_fx_cache.get("blur", 0.0)) > 0.0 or float(_fx_cache.get("psychic", 0.0)) > 0.0
	var want: ShaderMaterial = fx_full if need_full else fx_lite
	if fx_rect.material != want:
		fx_rect.material = want
	var m: CMob = p.c(&"mob")
	m.doll.set_frost(frost * 0.7)

func _draw_overlay() -> void:
	# world -> screen (the camera), then screen -> the HUD's own scaled canvas
	var xf := Transform2D().scaled(Vector2.ONE / _scale) * get_viewport().get_canvas_transform()
	for a in DoAfter.active:
		var u: Entity = a["user"]
		if not is_instance_valid(u):
			continue
		if Game.lighting and not Game.lighting.player_can_see(u.cell):
			continue
		var pos: Vector2 = xf * (u.position + Vector2(-14, 4))
		var w := 28.0 * xf.get_scale().x
		overlay.draw_rect(Rect2(pos, Vector2(w, 5)), Color(0, 0, 0, 0.7))
		overlay.draw_rect(Rect2(pos + Vector2(1, 1), Vector2((w - 2) * a["t"] / a["dur"], 3)), UITheme.GOOD)
	if debug_ai:
		for e in Game.all_with(&"brain"):
			if Game.lighting and not Game.lighting.player_can_see(e.cell):
				continue
			var b: CBrain = e.c(&"brain")
			var pos2: Vector2 = xf * (e.position + Vector2(-20, -44))
			overlay.draw_string(UITheme.mono, pos2, "%s: %s" % [e.display_name.split(" ")[0], b.status_text()], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 0.6))
			if b.thought != "":
				overlay.draw_string(UITheme.mono, pos2 + Vector2(0, 16), "\"%s\"" % b.thought.substr(0, 60), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.85, 1.0, 0.85))

func _on_mob_died(e: Entity) -> void:
	if e != Game.player:
		return
	await get_tree().create_timer(2.5).timeout
	show_death()

func show_death() -> void:
	if death_panel:
		death_panel.queue_free()
	death_panel = PanelContainer.new()
	death_panel.set_anchors_preset(Control.PRESET_CENTER)
	death_panel.position = Vector2(-340, -260)
	death_panel.custom_minimum_size = Vector2(680, 520)
	root.add_child(death_panel)
	var v := VBoxContainer.new()
	death_panel.add_child(v)
	v.add_child(UITheme.label("You have died.", 30, UITheme.BAD))
	v.add_child(UITheme.label("The ship sails on without you. Here's how your voyage went:", 15, UITheme.DIM))
	var lg := RichTextLabel.new()
	lg.bbcode_enabled = true
	lg.custom_minimum_size = Vector2(640, 360)
	lg.text = Game.chronicle.as_bbcode(true)
	v.add_child(lg)
	var h := HBoxContainer.new()
	v.add_child(h)
	var obs := Button.new()
	obs.text = "Keep watching"
	obs.pressed.connect(func(): death_panel.queue_free())
	h.add_child(obs)
	var again := Button.new()
	again.text = "Sign on as a new hand"
	again.pressed.connect(func():
		death_panel.queue_free()
		Game.world.get_parent().open_creator()
	)
	h.add_child(again)

## The round-end screen (tg: the roundend report). `departing` = the player just left on
## the crawler and it's still on its way. Otherwise the crawler has reached the base.
func show_round_end(departing: bool) -> void:
	if end_panel:
		end_panel.queue_free()
	if death_panel:
		death_panel.queue_free()
		death_panel = null
	var mine := {}
	for r in Game.evac.roster:
		if r["player"]:
			mine = r
	var head := "The voyage is over."
	var col := UITheme.ACCENT
	match mine.get("status", ""):
		"escaped":
			head = "You got clear of the ship."
			col = UITheme.GOOD
		"custody":
			head = "You were led off the ship in irons."
			col = UITheme.WARN
		"stranded":
			head = "The ferry left without you."
			col = UITheme.WARN
		"dead", "body_recovered":
			head = "You didn't survive the voyage."
			col = UITheme.BAD
	var sub := "The ferry runs for the home port..." if departing else "The ferry reached the home port. The voyage is over."
	end_panel = PanelContainer.new()
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.position = Vector2(-360, -290)
	end_panel.custom_minimum_size = Vector2(720, 580)
	root.add_child(end_panel)
	var v := VBoxContainer.new()
	end_panel.add_child(v)
	v.add_child(UITheme.label(head, 30, col))
	v.add_child(UITheme.label(sub, 15, UITheme.DIM))
	var lg := RichTextLabel.new()
	lg.bbcode_enabled = true
	lg.custom_minimum_size = Vector2(680, 420)
	lg.text = Game.evac.report_bbcode() + "\n\n[b]Ship's log[/b]\n" + Game.chronicle.as_bbcode(true)
	v.add_child(lg)
	var h := HBoxContainer.new()
	v.add_child(h)
	var obs := Button.new()
	obs.text = "Keep watching"
	obs.pressed.connect(func():
		end_panel.queue_free()
		end_panel = null
	)
	h.add_child(obs)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	h.add_child(quit)

# ------------------------------------------------------------------ drag and drop
func _build_drag() -> void:
	var drag_layer := CanvasLayer.new()
	drag_layer.layer = 30
	root.add_child(drag_layer)
	drag_ghost = TextureRect.new()
	drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	drag_ghost.size = Vector2(52, 52)
	drag_ghost.visible = false
	drag_ghost.z_index = 100
	drag_layer.add_child(drag_ghost)

## Called on a left press on something draggable. It becomes a drag once the mouse moves.
func drag_press(item: Entity, pos: Vector2, on_click: Callable) -> void:
	drag_item = item
	drag_from = pos
	drag_click = on_click
	dragging = false

func _input(ev: InputEvent) -> void:
	if ev is InputEventMouse:
		mouse = ev.position
	if ev is InputEventKey and ev.pressed and not ev.echo and not SettingsMenu.capturing:
		if ev.physical_keycode == KEY_F9 and not chat_active():
			open_settings()
			get_viewport().set_input_as_handled()
			return
	elif ev is InputEventMouseButton:
		if ev.pressed:
			# clicking away from a text box gives the keyboard back to the game (otherwise
			# the search field keeps eating WASD until you press Esc)
			var f := get_viewport().gui_get_focus_owner()
			if (f is LineEdit or f is TextEdit) and root.is_ancestor_of(f) and not f.get_global_rect().has_point(to_ui(ev.position)):
				if f == chat_input:
					chat_input.visible = false
				f.release_focus()
		else:
			_release_click_focus.call_deferred()
	if Game.paused and drag_item != null:
		_end_drag()
	if ev is InputEventKey and ev.pressed and ev.physical_keycode == KEY_ESCAPE:
		if drag_item != null:
			_end_drag()
			get_viewport().set_input_as_handled()
			return
		if chat_active():
			var focus := get_viewport().gui_get_focus_owner()
			if focus == chat_input:
				chat_input.visible = false
			focus.release_focus()
			get_viewport().set_input_as_handled()
			return
	if drag_item == null:
		return
	if not is_instance_valid(drag_item) or drag_item.removed:
		_end_drag()
		return
	if ev is InputEventMouseMotion:
		var pos := mouse
		if not dragging and pos.distance_to(drag_from) > 10.0:
			if not is_instance_valid(drag_item) or drag_item.removed or (drag_item.spr == null and not drag_item.has_c(&"mob")):
				_end_drag()
				return
			dragging = true
			if drag_item.has_c(&"mob"):
				drag_ghost.texture = null # dragging a person: the target highlight is the feedback
			else:
				drag_ghost.texture = InvSlot.icon_of(drag_item)
				drag_ghost.material = drag_item.spr.material
			drag_ghost.visible = true
		if dragging:
			_update_drag(pos)
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		if dragging:
			_finish_drag(mouse)
			get_viewport().set_input_as_handled()
		else:
			var cb := drag_click
			_end_drag(false)
			if cb.is_valid():
				cb.call()
				get_viewport().set_input_as_handled()
	elif dragging and (ev is InputEventMouseButton and ev.pressed or ev is InputEventKey and ev.pressed and ev.physical_keycode == KEY_ESCAPE):
		# right click or Esc cancels
		_end_drag()
		get_viewport().set_input_as_handled()

## A click on a button or slider must not leave it holding the keyboard: Space and Enter
## would press it again and the arrow keys would nudge it while you are trying to fly.
func _release_click_focus() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f is BaseButton or f is Range:
		f.release_focus()

func _drop_target(pos: Vector2) -> Dictionary:
	# `pos` is a screen position; the HUD's own rectangles live in its scaled canvas.
	var q := to_ui(pos)
	# Resolve the front window first; slots behind it cannot receive a drop.
	for i in range(windows.get_child_count() - 1, -1, -1):
		var w = windows.get_child(i)
		if w is UIWindow and w.is_visible_in_tree() and not w.is_queued_for_deletion() and w.get_global_rect().has_point(q):
			for sl in drop_slots:
				if w.is_ancestor_of(sl) and sl.contains_drop(q):
					return {"slot": sl, "dst": sl.destination()}
			if w.kind == "storage" and w.target:
				return {"dst": {"kind": "store", "container": w.target}}
			return {}
	for sl in drop_slots:
		if sl.contains_drop(q):
			return {"slot": sl, "dst": sl.destination()}
	if over_hud(pos):
		return {}
	var cell: Vector2i = Game.view.cell_at_screen(pos)
	return {"dst": {"kind": "world", "cell": cell, "ents": PlayerController.entities_at(cell)}}

## Is the mouse over a HUD panel or window (rather than the world)? `pos` is a screen position.
func over_hud(pos: Vector2) -> bool:
	var q := to_ui(pos)
	for w in windows.get_children():
		if w is Control and w.visible and w.get_global_rect().has_point(q):
			return true
	for k in ["chat", "clock", "menu", "equipment", "hands", "combat"]:
		var pn: Control = panels[k]
		if pn.visible and pn.get_global_rect().has_point(q):
			return true
	return false

func _update_drag(pos: Vector2) -> void:
	drag_ghost.position = pos - drag_ghost.size * 0.5
	var t := _drop_target(pos)
	var ok := not t.is_empty() and DragDrop.apply(Game.player, drag_item, t["dst"], true)
	var over_slot: InvSlot = t.get("slot")
	for sl in drop_slots:
		if sl.is_visible_in_tree():
			sl.set_drop_hint(1 if DragDrop.apply(Game.player, drag_item, sl.destination(), true) else (-1 if sl == over_slot else 0))
	drag_ghost.modulate = Color(0.55, 1.0, 0.6, 0.72) if ok else Color(1.0, 0.45, 0.4, 0.6)
	drag_hint_slot = over_slot
	if over_slot:
		over_slot.set_drop_hint(1 if ok else -1)

func _finish_drag(pos: Vector2) -> void:
	if Game.paused:
		_end_drag()
		return
	var t := _drop_target(pos)
	var p := Game.player
	# a sloppy click that wobbled into a drag and landed back on its own slot is a click
	if t.get("slot") is InvSlot and t["slot"].item == drag_item:
		var sl: InvSlot = t["slot"]
		_end_drag()
		sl.clicked.emit(sl.slot, MOUSE_BUTTON_LEFT)
		return
	if not t.is_empty() and p and DragDrop.apply(p, drag_item, t["dst"], true):
		DragDrop.apply(p, drag_item, t["dst"], false)
	_end_drag()
	refresh_inventory()
	for w in windows.get_children():
		if w is UIWindow and w.kind in ["storage", "crafting"]:
			w.refresh_t = 0.0

func _end_drag(cancel_press := true) -> void:
	for sl in drop_slots:
		sl.set_drop_hint(0)
	if cancel_press:
		for sl in drop_slots:
			sl._pressed = false
	drag_item = null
	drag_click = Callable()
	dragging = false
	drag_ghost.visible = false
	if drag_hint_slot and is_instance_valid(drag_hint_slot):
		drag_hint_slot.set_drop_hint(0)
	drag_hint_slot = null

# ------------------------------------------------------------------ HUD layout
func toggle_layout_mode() -> void:
	layout_mode = not layout_mode
	for hd in layout_handles:
		hd.queue_free()
	layout_handles.clear()
	if not layout_mode:
		_save_layout()
		return
	for k in ["clock", "menu", "chat", "equipment", "hands", "combat", "examine", "alerts"]:
		var h := LayoutHandle.new(self, k, panels[k], k == "chat")
		root.add_child(h)
		layout_handles.append(h)
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.offset_top = 60
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	bar.add_child(hb)
	hb.add_child(UITheme.label("Drag panels to move them. Drag the chat's corner to resize it.", 15, UITheme.ACCENT))
	var rb := Button.new()
	rb.text = "Reset"
	rb.pressed.connect(func():
		reset_layout()
		toggle_layout_mode()
		toggle_layout_mode()
	)
	hb.add_child(rb)
	var db := Button.new()
	db.text = "Done"
	db.pressed.connect(toggle_layout_mode)
	hb.add_child(db)
	root.add_child(bar)
	layout_handles.append(bar)

## After a panel is moved, anchor it to whichever part of the screen it's in, so it keeps
## its place when the window is resized.
func reanchor(pn: Control) -> void:
	var vs := root.get_rect().size
	var r := pn.get_global_rect()
	var c := r.get_center()
	var ax := 0.0 if c.x < vs.x / 3.0 else (1.0 if c.x > vs.x * 2.0 / 3.0 else 0.5)
	var ay := 0.0 if c.y < vs.y / 3.0 else (1.0 if c.y > vs.y * 2.0 / 3.0 else 0.5)
	pn.anchor_left = ax
	pn.anchor_right = ax
	pn.anchor_top = ay
	pn.anchor_bottom = ay
	pn.offset_left = r.position.x - ax * vs.x
	pn.offset_top = r.position.y - ay * vs.y
	pn.offset_right = pn.offset_left + r.size.x
	pn.offset_bottom = pn.offset_top + r.size.y

func _clamp_panels() -> void:
	var vs := root.get_rect().size
	for k in panels:
		var pn: Control = panels[k]
		var r := pn.get_global_rect()
		var np := Vector2(clampf(r.position.x, 0.0, maxf(0.0, vs.x - r.size.x)), clampf(r.position.y, 0.0, maxf(0.0, vs.y - r.size.y)))
		if np != r.position:
			pn.global_position = np

func _save_layout() -> void:
	var cf := ConfigFile.new()
	for k in panels:
		var pn: Control = panels[k]
		cf.set_value(k, "anchor", Vector2(pn.anchor_left, pn.anchor_top))
		cf.set_value(k, "offset", Vector2(pn.offset_left, pn.offset_top))
	cf.set_value("chat", "log_size", chat_log.custom_minimum_size)
	cf.save(LAYOUT_FILE)

func _load_layout() -> void:
	var cf := ConfigFile.new()
	if cf.load(LAYOUT_FILE) != OK:
		return
	chat_log.custom_minimum_size = cf.get_value("chat", "log_size", chat_log.custom_minimum_size)
	panels["chat"].reset_size()
	for k in panels:
		if not cf.has_section_key(k, "anchor"):
			continue
		var pn: Control = panels[k]
		var a: Vector2 = cf.get_value(k, "anchor")
		var o: Vector2 = cf.get_value(k, "offset")
		var sz := pn.get_combined_minimum_size().max(pn.size)
		pn.anchor_left = a.x
		pn.anchor_right = a.x
		pn.anchor_top = a.y
		pn.anchor_bottom = a.y
		pn.offset_left = o.x
		pn.offset_top = o.y
		pn.offset_right = o.x + sz.x
		pn.offset_bottom = o.y + sz.y
	_clamp_panels.call_deferred()

func reset_layout() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LAYOUT_FILE))
	_hands_dx = 0.0
	chat_log.custom_minimum_size = Vector2(CHAT_SIZE)
	panels["chat"].reset_size()
	for k in layout_defaults:
		var pn: Control = panels[k]
		var d: Array = layout_defaults[k]
		pn.anchor_left = d[0]
		pn.anchor_top = d[1]
		pn.anchor_right = d[2]
		pn.anchor_bottom = d[3]
		pn.offset_left = d[4]
		pn.offset_top = d[5]
		pn.offset_right = d[6]
		pn.offset_bottom = d[7]

# ------------------------------------------------------------------ skills feedback
var _xp_pops := {} # skill -> {node, amount, t}
var _toasts: Array = []

## "+12 Engineering" rising over your head; gains in the same skill close together add up.
func _on_xp_gained(ent: Entity, what: String, amount: float) -> void:
	if ent != Game.player or Game.view == null:
		return
	var nm: String = Skills.SKILLS[what]["name"] if Skills.SKILLS.has(what) else what.capitalize()
	var col := Color.WHITE
	for g in Skills.GROUPS:
		if what in g[2]:
			col = g[1]
	var pop: Dictionary = _xp_pops.get(what, {})
	if pop.is_empty() or not is_instance_valid(pop.get("node")):
		var l := Label.new()
		l.add_theme_font_override("font", UITheme.mono)
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06))
		l.add_theme_constant_override("outline_size", 5)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.scale = Vector2(0.5, 0.5)
		l.z_index = 25
		Game.view.fx_layer.add_child(l)
		pop = {"node": l, "amount": 0.0, "t": 0.0, "rise": 0.0, "stack": _xp_pops.size()}
		_xp_pops[what] = pop
	pop["amount"] += amount
	pop["t"] = 1.8
	var lab: Label = pop["node"]
	lab.text = "+%d %s" % [int(ceil(pop["amount"])), nm]
	lab.add_theme_color_override("font_color", col.lightened(0.3))

func _update_xp_pops(delta: float) -> void:
	for k in _xp_pops.keys():
		var pop: Dictionary = _xp_pops[k]
		var l: Label = pop["node"]
		pop["t"] -= delta
		pop["rise"] += delta * 10.0
		if pop["t"] <= 0.0 or not is_instance_valid(l) or Game.player == null:
			if is_instance_valid(l):
				l.queue_free()
			_xp_pops.erase(k)
			continue
		var w := l.size.x * l.scale.x
		l.position = Game.player.position + Vector2(-w * 0.5, -52 - pop["rise"] - pop["stack"] * 9)
		l.modulate.a = clampf(pop["t"] / 0.6, 0.0, 1.0)

## A card that slides down from the top on a level-up, with the new level and a filling ring.
func _on_skill_up(ent: Entity, what: String, lvl: int) -> void:
	if ent != Game.player:
		return
	var is_attr := Skills.ATTRIBUTES.has(what)
	var nm: String = Skills.ATTRIBUTES[what]["name"] if is_attr else Skills.SKILLS[what]["name"]
	var col: Color = Skills.ATTR_COLORS.get(what, UITheme.ACCENT)
	if not is_attr:
		for g in Skills.GROUPS:
			if what in g[2]:
				col = g[1]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.frame("panel", 14, 10))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	var stripe := ColorRect.new()
	stripe.color = col
	stripe.custom_minimum_size = Vector2(4, 0)
	h.add_child(stripe)
	var badge := SkillsPanel.Badge.new(52, col)
	badge.value = lvl
	h.add_child(badge)
	var v := VBoxContainer.new()
	h.add_child(v)
	v.add_child(UITheme.label("ATTRIBUTE UP" if is_attr else "SKILL UP", 13, col))
	v.add_child(UITheme.label("%s  %d" % [nm, lvl], 22, Color.WHITE))
	root.add_child(card)
	card.reset_size()
	var x := root.get_rect().size.x * 0.5 - card.size.x * 0.5
	var y0 := -card.size.y - 10.0
	var y1 := 70.0 + _toasts.size() * (card.size.y + 8.0)
	card.position = Vector2(x, y0)
	_toasts.append(card)
	var tw := create_tween()
	tw.tween_property(card, "position:y", y1, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.8)
	tw.tween_property(card, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		_toasts.erase(card)
		card.queue_free()
	)
