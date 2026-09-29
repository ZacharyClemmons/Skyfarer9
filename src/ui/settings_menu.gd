extends RefCounted
## The Settings window (F9, the cog in the top bar, or Settings on the pause menu).
##
## UI scale, panel opacity, message-log text size, the idle-fade and worn-gear toggles,
## window mode / vsync / frame cap, master volume and key rebinding. Everything is saved to
## prefs.cfg through UITheme.save_pref and re-applied by apply_saved() at start-up.
##
## Deliberately not a class_name: it is loaded with preload from hud.gd, so adding it needs
## no `--import`.

## True while a key-binding button is waiting for a key; HUD ignores F9 meanwhile.
static var capturing := false
## Used by the HUD regression driver so simulated rebinds never change prefs.cfg.
static var persist_changes := true
static var _defaults := {}
static var _key_buttons := {}

const KEYS := [
	["Move up", "move_up"], ["Move down", "move_down"], ["Move left", "move_left"], ["Move right", "move_right"],
	["Walk / run / sneak", "walk_toggle"], ["Combat stance", "combat"], ["Rest / stand", "rest"], ["Resist", "resist"],
	["Swap hands", "swap_hands"], ["Use held item", "use_self"], ["Drop", "drop"], ["Equip", "equip"], ["Throw mode", "throw"],
	["Inventory", "inventory"], ["Skills", "skills"], ["Duties", "objectives"], ["Chart", "station_map"],
	["Crafting", "crafting"], ["Log", "chronicle"], ["Help", "help"], ["Say something", "talk"], ["Voice-link", "radio_talk"],
	["Zoom in", "zoom_in"], ["Zoom out", "zoom_out"], ["Arrange the HUD", "hud_layout"],
	["Hotbar 1", "hotbar_0"], ["Hotbar 2", "hotbar_1"], ["Hotbar 3", "hotbar_2"], ["Hotbar 4", "hotbar_3"],
	["Hotbar 5", "hotbar_4"], ["Hotbar 6", "hotbar_5"],
]

# ------------------------------------------------------------------ start-up
## Called once by HUD._ready: remember the stock key map, then lay the player's choices over it.
static func apply_saved() -> void:
	if _defaults.is_empty():
		for k in KEYS:
			_defaults[k[1]] = _codes(k[1])
	var cf := ConfigFile.new()
	if cf.load(UITheme.PREFS) != OK:
		return
	if cf.has_section("keys"):
		for a in cf.get_section_keys("keys"):
			if InputMap.has_action(a):
				_set_primary(a, int(cf.get_value("keys", a)))
	if cf.has_section_key("graphics", "quality"):
		LightingSystem.quality = clampi(int(cf.get_value("graphics", "quality")), 0, 2)
	if cf.has_section_key("display", "fullscreen"):
		_set_fullscreen(bool(cf.get_value("display", "fullscreen")))
	if cf.has_section_key("display", "vsync"):
		_set_vsync(bool(cf.get_value("display", "vsync")))
	if cf.has_section_key("display", "max_fps"):
		Engine.max_fps = int(cf.get_value("display", "max_fps"))

static func _set_fullscreen(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)

static func _set_vsync(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)

# ------------------------------------------------------------------ key map helpers
static func _codes(action: String) -> Array:
	var out := []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			out.append(int(ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode))
	return out

static func _key_event(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code as Key
	return ev

## Replace the action's first key with `code` (0 removes it); any other keys it has stay.
static func _set_primary(action: String, code: int) -> void:
	var codes := _codes(action)
	var rest: Array = codes.slice(1)
	rest.erase(code)
	InputMap.action_erase_events(action)
	if code != 0:
		InputMap.action_add_event(action, _key_event(code))
	for c in rest:
		InputMap.action_add_event(action, _key_event(c))

static func _remove_code(action: String, code: int) -> void:
	var codes := _codes(action)
	if not codes.has(code):
		return
	codes.erase(code)
	InputMap.action_erase_events(action)
	for c in codes:
		InputMap.action_add_event(action, _key_event(c))

static func key_text(action: String) -> String:
	var parts := PackedStringArray()
	for c in _codes(action):
		var code: Key = c as Key
		parts.append(OS.get_keycode_string(code if DisplayServer.get_name() == "headless"
			else DisplayServer.keyboard_get_keycode_from_physical(code)))
	return " / ".join(parts) if not parts.is_empty() else "unbound"

## Bind `code` as the action's main key. Whoever else had that key loses it, and the change
## is saved for every action it touched.
static func rebind(action: String, code: int) -> String:
	var taken := ""
	for k in KEYS:
		var other: String = k[1]
		if other != action and _codes(other).has(code):
			_remove_code(other, code)
			_save_key(other)
			taken = k[0]
	_set_primary(action, code)
	_save_key(action)
	return taken

static func _save_key(action: String) -> void:
	if not persist_changes:
		return
	var codes := _codes(action)
	UITheme.save_pref("keys", action, int(codes[0]) if not codes.is_empty() else 0)

static func reset_keys() -> void:
	for a in _defaults:
		InputMap.action_erase_events(a)
		for c in _defaults[a]:
			InputMap.action_add_event(a, _key_event(c))
	if persist_changes:
		var cf := ConfigFile.new()
		cf.load(UITheme.PREFS)
		if cf.has_section("keys"):
			cf.erase_section("keys")
			cf.save(UITheme.PREFS)

## Waits for one key press for a binding button, then hands it back.
class Capture extends Node:
	var done: Callable

	func _input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_finish(-1)
			return
		if ev is InputEventKey and ev.pressed and not ev.echo:
			get_viewport().set_input_as_handled()
			var code := int(ev.physical_keycode)
			_finish(-1 if code == KEY_ESCAPE else code)

	func _finish(code: int) -> void:
		set_process_input(false)
		queue_free()
		done.call(code)

# ------------------------------------------------------------------ the window
static func open(hud: HUD) -> UIWindow:
	var w := UIWindow.new("Settings", 640)
	w.kind = "settings"
	w.refresh_fn = Callable()
	hud.windows.add_child(w)
	_fill(w, hud)
	w.place_initial(0)
	return w

static func _fill(w: UIWindow, hud: HUD) -> void:
	var body := w.body
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	_key_buttons.clear()

	_head(body, "Display")
	# --- UI scale: applied when the handle is let go, because the window itself resizes
	var scale_val := UITheme.ui_scale_pref if UITheme.ui_scale_pref > 0.0 else UITheme.ui_scale()
	var auto_btn := _toggle("Auto", UITheme.ui_scale_pref <= 0.0)
	var sc_lbl := UITheme.label(_scale_text(scale_val), UITheme.BODY, UITheme.ACCENT)
	sc_lbl.custom_minimum_size.x = 56
	var sc := _slider(0.75, 1.4, 0.05, scale_val)
	sc.editable = UITheme.ui_scale_pref > 0.0
	sc.value_changed.connect(func(v: float) -> void: sc_lbl.text = _scale_text(v))
	sc.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			_apply_scale(hud, sc.value))
	auto_btn.toggled.connect(func(on: bool) -> void:
		sc.editable = not on
		if on:
			_apply_scale(hud, 0.0)
			sc.set_value_no_signal(UITheme.ui_scale())
			sc_lbl.text = _scale_text(UITheme.ui_scale())
		else:
			_apply_scale(hud, sc.value))
	_row(body, "HUD scale", [auto_btn, sc, sc_lbl], "Scales every panel and window. Auto keeps text the same size on screen whatever your window is.")

	var op_lbl := UITheme.label("%d%%" % int(UITheme.panel_opacity * 100.0), UITheme.BODY, UITheme.ACCENT)
	op_lbl.custom_minimum_size.x = 56
	var op := _slider(0.6, 1.0, 0.05, UITheme.panel_opacity)
	op.value_changed.connect(func(v: float) -> void:
		UITheme.panel_opacity = v
		op_lbl.text = "%d%%" % int(v * 100.0)
		hud._apply_panel_opacity())
	op.drag_ended.connect(func(_c: bool) -> void: UITheme.save_pref("ui", "opacity", UITheme.panel_opacity))
	_row(body, "Panel opacity", [op, op_lbl], "Raise it if text is hard to read over a busy background.")

	var fs := _toggle("Fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	fs.toggled.connect(func(on: bool) -> void:
		_set_fullscreen(on)
		UITheme.save_pref("display", "fullscreen", on))
	var vs := _toggle("VSync", DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
	vs.toggled.connect(func(on: bool) -> void:
		_set_vsync(on)
		UITheme.save_pref("display", "vsync", on))
	_row(body, "Window", [fs, vs])
	var fps_group := ButtonGroup.new()
	var fps_row: Array = []
	for pair in [["Unlimited", 0], ["60", 60], ["120", 120]]:
		var fb := _toggle(pair[0], Engine.max_fps == pair[1])
		fb.button_group = fps_group
		var val: int = pair[1]
		fb.pressed.connect(func() -> void:
			Engine.max_fps = val
			UITheme.save_pref("display", "max_fps", val))
		fps_row.append(fb)
	_row(body, "Frame cap", fps_row, "Lower it to make a laptop quieter.")

	var q_group := ButtonGroup.new()
	var q_row: Array = []
	for qi in 3:
		var qb := _toggle(["Low", "Medium", "High"][qi], LightingSystem.quality == qi)
		qb.button_group = q_group
		qb.pressed.connect(func() -> void:
			LightingSystem.quality = qi
			UITheme.save_pref("graphics", "quality", qi))
		q_row.append(qb)
	_row(body, "Graphics quality", q_row, "Low turns off the optional lighting effects, Medium adds ambient occlusion and dims unseen space, High adds lamp bloom. Bloom (High) starts up at the next launch; the other two switch at once.")

	_head(body, "Text and HUD")
	var size_group := ButtonGroup.new()
	var size_row: Array = []
	for i in 3:
		var sb := _toggle(["Compact", "Comfortable", "Large"][i], hud.message_log.font_size == UITheme.LOG_SIZES[i])
		sb.button_group = size_group
		var px: int = UITheme.LOG_SIZES[i]
		sb.pressed.connect(func() -> void: hud.set_log_text_size(px))
		size_row.append(sb)
	_row(body, "Message log text", size_row)
	var fade := _toggle("On", UITheme.idle_fade)
	fade.toggled.connect(func(on: bool) -> void:
		UITheme.idle_fade = on
		UITheme.save_pref("ui", "idle_fade", on))
	_row(body, "Fade log when quiet", [fade], "The log dims and tucks its tabs and search away until something happens or you hover it.")
	var worn := _toggle("Shown", UITheme.equip_open)
	worn.toggled.connect(func(on: bool) -> void: hud._set_equip_open(on))
	_row(body, "Worn gear slots", [worn], "The grid of slots for what you are wearing. Tab always opens the full inventory.")

	_head(body, "Audio")
	var mv_lbl := UITheme.label("%d%%" % int(UITheme.master_volume * 100.0), UITheme.BODY, UITheme.ACCENT)
	mv_lbl.custom_minimum_size.x = 56
	var mv := _slider(0.0, 1.0, 0.05, UITheme.master_volume)
	mv.value_changed.connect(func(v: float) -> void:
		UITheme.master_volume = v
		Sfx.master = v
		mv_lbl.text = "%d%%" % int(v * 100.0))
	mv.drag_ended.connect(func(_c: bool) -> void:
		UITheme.save_pref("audio", "master", UITheme.master_volume)
		Sfx.play_ui("ui_confirm", 0.8))
	_row(body, "Master volume", [mv, mv_lbl])

	_head(body, "Keys")
	body.add_child(_note("Click a key, then press the new one (Esc cancels). Another action using it loses it. "
		+ "Ship controls (Q / E ballast, Space all stop, G panel, mouse) are fixed."))
	for k in KEYS:
		if not InputMap.has_action(k[1]):
			continue
		var kb := Button.new()
		kb.text = key_text(k[1])
		kb.custom_minimum_size = Vector2(150, 0)
		kb.focus_mode = Control.FOCUS_NONE
		_key_buttons[k[1]] = kb
		var action: String = k[1]
		var label: String = k[0]
		kb.pressed.connect(func() -> void: _begin_capture(hud, kb, action, label))
		_row(body, k[0], [kb])

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	body.add_child(foot)
	var rk := Button.new()
	rk.text = "Reset keys"
	rk.pressed.connect(func() -> void:
		reset_keys()
		_refresh_keys())
	foot.add_child(rk)
	var rd := Button.new()
	rd.text = "Reset display and text"
	rd.pressed.connect(func() -> void:
		UITheme.ui_scale_pref = 0.0
		UITheme.panel_opacity = 1.0
		UITheme.idle_fade = true
		for pair in [["ui", "scale", 0.0], ["ui", "opacity", 1.0], ["ui", "idle_fade", true]]:
			UITheme.save_pref(pair[0], pair[1], pair[2])
		hud.set_log_text_size(20)
		hud._set_equip_open(false)
		hud.apply_ui_scale()
		hud._apply_panel_opacity()
		_fill(w, hud))
	foot.add_child(rd)
	var done := Button.new()
	done.text = "Done"
	done.pressed.connect(func() -> void: UIFx.ease_close(w))
	foot.add_child(done)

static func _apply_scale(hud: HUD, v: float) -> void:
	UITheme.ui_scale_pref = v
	UITheme.save_pref("ui", "scale", v)
	hud.apply_ui_scale()

static func _scale_text(v: float) -> String:
	return "%.2fx" % v

static func _refresh_keys() -> void:
	for a in _key_buttons:
		var b: Button = _key_buttons[a]
		if is_instance_valid(b):
			b.text = key_text(a)

static func _begin_capture(hud: HUD, btn: Button, action: String, label: String) -> void:
	if capturing:
		return
	capturing = true
	btn.text = "Press a key..."
	var cap := Capture.new()
	cap.done = func(code: int) -> void:
		# stay in "capturing" a moment longer so the very key press that was just bound
		# cannot also close the window or open another one
		hud.get_tree().create_timer(0.15).timeout.connect(func() -> void: capturing = false)
		if code > 0:
			var taken := rebind(action, code)
			if taken != "":
				UIFx.toast("%s now uses that key; %s lost it." % [label, taken], "warn")
		_refresh_keys()
	hud.root.add_child(cap)

# ------------------------------------------------------------------ small builders
static func _head(body: Control, text: String) -> void:
	var l := UITheme.label(text.to_upper(), UITheme.BODY, UITheme.ACCENT)
	l.add_theme_constant_override("outline_size", 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	box.add_child(sp)
	box.add_child(l)
	box.add_child(HSeparator.new())
	body.add_child(box)

static func _note(text: String) -> Label:
	var l := UITheme.label(text, UITheme.SMALL, UITheme.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 540
	return l

static func _row(body: Control, label: String, controls: Array, tip := "") -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UITheme.label(label, UITheme.BODY)
	l.custom_minimum_size.x = 210
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	if tip != "":
		l.tooltip_text = tip
	h.add_child(l)
	for c in controls:
		h.add_child(c)
	body.add_child(h)

static func _toggle(text: String, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	return b

static func _slider(lo: float, hi: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(230, 26)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	return s
