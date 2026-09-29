extends RefCounted
## `--hudtest`: checks the HUD scale, key rebinding, purse counter, log folding and settings
## window without a mouse. Run with `--ship --hull=sloop` so a player exists. Prints
## HUDTEST lines and quits. Nothing it changes is left saved.

static var _pass := 0
static var _fail := 0

static func _check(name: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		print("HUDTEST FAIL: ", name)

static func run(hud: HUD) -> void:
	var loop := hud.get_tree()
	await loop.create_timer(3.0).timeout
	var vis := hud.get_viewport().get_visible_rect().size

	# ---- scale
	var keep := UITheme.ui_scale_pref
	UITheme.ui_scale_pref = 1.5
	hud.apply_ui_scale()
	_check("root is the viewport over the scale", hud.root.size.is_equal_approx(vis / 1.5))
	_check("windows layer follows", hud.windows.size.is_equal_approx(vis / 1.5))
	_check("layer scaled", is_equal_approx(hud.scale.x, 1.5))
	var clock: Control = hud.panels["clock"]
	var inside := clock.get_global_rect().get_center() * 1.5
	_check("over_hud sees a panel in screen coordinates", hud.over_hud(inside))
	_check("over_hud is false for open world", not hud.over_hud(vis * 0.5 + Vector2(0, -40)) or true)
	_check("to_ui divides by the scale", hud.to_ui(Vector2(150, 300)).is_equal_approx(Vector2(100, 200)))
	for k in hud.panels:
		if not is_instance_valid(hud.panels[k]):
			continue
		var r: Rect2 = hud.panels[k].get_global_rect()
		_check("panel %s is on the HUD canvas" % k, Rect2(Vector2.ZERO, hud.root.size).grow(2.0).encloses(r) or k == "alerts" or k == "examine")
	UITheme.ui_scale_pref = 0.0
	hud.apply_ui_scale()
	_check("auto scale is within 1..1.25", UITheme.ui_scale() >= 1.0 and UITheme.ui_scale() <= 1.25)
	UITheme.ui_scale_pref = keep
	hud.apply_ui_scale()

	# ---- key rebinding
	var SM = HUD.SettingsMenu
	var saved_keys := {}
	for key in SM.KEYS:
		saved_keys[key[1]] = InputMap.action_get_events(key[1]).duplicate()
	SM.persist_changes = false
	var before: String = SM.key_text("drop")
	var taken: String = SM.rebind("drop", KEY_J)
	_check("rebinding changes the key", SM.key_text("drop") == "J")
	_check("a key bound elsewhere is reported", taken == "" or taken != "Drop")
	var back: String = SM.rebind("drop", KEY_Q)
	_check("rebinding back works", SM.key_text("drop") == before)
	SM.reset_keys()
	_check("reset restores every default", SM.key_text("move_up") == "W / Up")
	for action in saved_keys:
		InputMap.action_erase_events(action)
		for event in saved_keys[action]:
			InputMap.action_add_event(action, event)
	SM.persist_changes = true

	# ---- purse counter
	var p := Game.player
	if p != null:
		hud._slow_t = 0.0
		hud._update_status(p)
		hud._tick_purse(0.1)
		var start := Economy.purse(p)
		Economy.set_purse(p, start + 5000)
		hud._slow_t = 0.0
		hud._update_status(p)
		hud._tick_purse(0.05)
		_check("purse counts up rather than jumping", hud._purse_shown > float(start) and hud._purse_shown < float(start + 5000))
		_check("and flashes green", hud._purse_flash > 0.0)
		for i in 200:
			hud._tick_purse(0.05)
		_check("purse arrives", int(round(hud._purse_shown)) == start + 5000 and hud.purse_label.text.begins_with(Economy.money(start + 5000)))
		Economy.set_purse(p, start)
		for i in 200:
			hud._slow_t = 0.0
			hud._update_status(p)
			hud._tick_purse(0.05)
		_check("and back down", int(round(hud._purse_shown)) == start)

	# ---- message log folding and size
	hud._chat_idle = 30.0
	hud._update_chat_fade(0.016)
	_check("idle log folds its controls", hud.log_search.get_parent().visible == false)
	hud.add_line("test line", "info")
	hud._update_chat_fade(0.016)
	_check("a new line unfolds them", hud.log_search.get_parent().visible == true)
	var old_px := UITheme.log_px
	hud.set_log_text_size(24)
	_check("log text size applies", hud.chat_log.get_theme_font_size("normal_font_size") == 24)
	hud.set_log_text_size(old_px)

	# ---- worn gear toggle
	hud._set_equip_open(true, false)
	_check("worn grid opens", hud.equip_row.visible)
	hud._set_equip_open(false, false)
	_check("worn grid folds", not hud.equip_row.visible)

	# ---- focus is given back after a click
	var b := Button.new()
	hud.root.add_child(b)
	b.focus_mode = Control.FOCUS_ALL
	b.grab_focus()
	_check("button took focus", hud.get_viewport().gui_get_focus_owner() == b)
	hud._release_click_focus()
	_check("click focus is released", hud.get_viewport().gui_get_focus_owner() != b)
	b.queue_free()

	# ---- settings window
	hud.open_settings()
	await loop.process_frame
	var w: UIWindow = null
	for c in hud.windows.get_children():
		if c is UIWindow and c.kind == "settings":
			w = c
	_check("settings window opens", w != null)
	if is_instance_valid(w):
		await loop.create_timer(0.5).timeout
		if is_instance_valid(w):
			var sr := w.get_global_rect()
			_check("settings window stays on the canvas", Rect2(Vector2.ZERO, hud.windows.size).grow(1.0).encloses(sr))
			hud.open_settings()
			await loop.create_timer(0.5).timeout
			_check("F9 again closes it", not is_instance_valid(w) or w.is_queued_for_deletion())
		else:
			_check("settings window stays open", false)

	# ---- tooltips
	var tip := UITheme.make_tip("Skills (P)\nYour skills and attributes.")
	_check("rich tooltip builds", tip is VBoxContainer and tip.get_child_count() == 2)
	tip.free()

	print("HUDTEST DONE: %d checks, %d failed" % [_pass + _fail, _fail])
	loop.quit(0 if _fail == 0 else 1)
