class_name UITest extends Node
## --uitest=DIR: drives the HUD with synthetic mouse events (the same path real input
## takes), checks that drag and drop moved things where it should, and saves screenshots
## into DIR. Prints "UITEST PASS/FAIL ..." lines and quits.

var dir := ""
var fails := 0
var _last := Vector2.ZERO

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if dir != "":
		dir = dir if dir.is_absolute_path() else ProjectSettings.globalize_path("res://" + dir)
		var directory_error := DirAccess.make_dir_recursive_absolute(dir)
		_check("screenshot directory is available", directory_error == OK)
	await _frames(20)
	var hud: HUD = Game.hud
	var p := Game.player
	var inv: CInventory = p.c(&"inv")
	# a known setup: a backpack on, a wrench in the right hand, left hand empty
	for i in 2:
		if inv.hands[i]:
			inv.hands[i].destroy()
			inv.hands[i] = null
	if inv.worn("back") == null:
		inv.equip(Proto.spawn("backpack", p.cell), "back")
	var bag: Entity = inv.worn("back")
	var wrench := Proto.spawn("wrench", p.cell)
	inv.put_in_hands(wrench, 1)
	inv.active = 1
	hud.refresh_inventory()
	await _frames(5)

	# 1. hand -> backpack window
	hud.open_window("storage", bag)
	await _frames(5)
	var win := _window("storage")
	_check("storage window opens", win != null)
	var cells := _storage_cells(win)
	_check("storage grid has cells", cells.size() >= 14)
	var empty_cell: InvSlot = null
	for c in cells:
		if c.item == null:
			empty_cell = c
			break
	await _click(_center(empty_cell))
	_check("empty storage cell accepts the held item", wrench.holder == bag and inv.hands[1] == null)
	Windows._take(p, bag.c(&"storage"), wrench)
	_check("storage click draws the item back into a hand", wrench in inv.hands)
	await _frames(3)
	for c in _storage_cells(_window("storage")):
		if c.item == null:
			empty_cell = c
			break
	await _drag(_center(hud.slots["hand_r"]), _center(empty_cell), true)
	_check("hand -> bag", wrench.holder == bag and inv.hands[1] == null)
	_check("completed hand drag clears its pressed state", not hud.slots["hand_r"]._pressed)

	# 2. bag -> left hand
	await _frames(3)
	var src: InvSlot = null
	for c in _storage_cells(_window("storage")):
		if c.item == wrench:
			src = c
	_check("wrench shows in the bag grid", src != null)
	if src:
		await _drag(_center(src), _center(hud.slots["hand_l"]))
	_check("bag -> left hand", inv.hands[0] == wrench)

	# 3. hand -> the floor next to the player (with the bag window out of the way)
	_window("storage").queue_free()
	await _frames(2)
	var floor_cell := _free_adjacent(p.cell)
	await _drag(_center(hud.slots["hand_l"]), _world_screen(floor_cell))
	_check("hand -> floor", wrench.holder == null and wrench.cell == floor_cell)

	# 4. floor -> right hand (starts on the world, not a slot)
	await _drag(_world_screen(floor_cell), _center(hud.slots["hand_r"]))
	_check("floor -> right hand", inv.hands[1] == wrench)
	# Secondary tool clicks must reach the world after an inventory drag.
	var tool_locker := Proto.spawn("locker", floor_cell)
	var previous_hand := inv.active
	inv.active = 1
	_mouse(_world_screen(floor_cell), MOUSE_BUTTON_RIGHT, true)
	_mouse(_world_screen(floor_cell), MOUSE_BUTTON_RIGHT, false)
	await _frames(2)
	_check("right-click wrench anchors a locker after pickup", tool_locker.tags.get("anchored", false))
	_mouse(_world_screen(floor_cell), MOUSE_BUTTON_RIGHT, true)
	_mouse(_world_screen(floor_cell), MOUSE_BUTTON_RIGHT, false)
	await _frames(2)
	_check("second right-click wrench unanchors the locker", not tool_locker.tags.get("anchored", false))
	tool_locker.destroy()
	inv.active = previous_hand

	# 5. an invalid drop (a wrench onto the head slot) changes nothing
	await _drag(_center(hud.slots["hand_r"]), _center(hud.slots["head"]))
	_check("invalid drop leaves the item alone", inv.hands[1] == wrench and inv.worn("head") != wrench)
	var health: CHealth = p.c(&"health")
	health.missing["l_arm"] = true
	_check("disabled hand rejects the drop preview", not DragDrop.apply(p, wrench, {"kind": "hand", "idx": 0}, true))
	_check("disabled hand rejects the drop without moving the item", not DragDrop.apply(p, wrench, {"kind": "hand", "idx": 0}, false) and inv.hands[1] == wrench)
	health.missing.erase("l_arm")
	health.cuffed = true
	hud._action("drop")
	_check("cuffed drop shortcut preserves the held item", inv.hands[1] == wrench)
	health.cuffed = false
	wrench.set_meta("nodrop", true)
	_check("dragging cannot bypass a held item's drop restriction", not DragDrop.apply(p, wrench, {"kind": "store", "container": bag}, false) and inv.hands[1] == wrench)
	wrench.remove_meta("nodrop")
	var lamp := Proto.spawn("flashlight", p.cell)
	inv.put_in_hands(lamp, 0)
	inv.active = 0
	var was_on: bool = lamp.c(&"light").on
	health.cuffed = true
	_key(KEY_Z)
	_key(KEY_E)
	_check("cuffed use and equip shortcuts preserve the held item", lamp.c(&"light").on == was_on and inv.hands[0] == lamp)
	health.cuffed = false
	_key(KEY_Z)
	_check("use shortcut still toggles a usable held flashlight", lamp.c(&"light").on != was_on)
	var before_cancel: bool = lamp.c(&"light").on
	hud.slots["hand_l"]._pressed = true
	hud.drag_press(lamp, _center(hud.slots["hand_l"]), Callable())
	_key(KEY_ESCAPE)
	_mouse(_center(hud.slots["hand_l"]), MOUSE_BUTTON_LEFT, false)
	await _frames(2)
	_check("release after cancelled hand drag cannot activate the item", lamp.c(&"light").on == before_cancel)
	lamp.destroy()
	inv.active = 1
	hud.refresh_inventory()
	_check("active hand tooltip describes using its held item", "Click to use" in hud.slots["hand_r"].tooltip_text)

	# A front window blocks drops into inventory slots behind it.
	hud.open_window("help", null)
	await _frames(3)
	var cover := _window("help")
	cover._want = _center(hud.slots["hand_r"]) - Vector2(30, 50)
	cover._clamp()
	await _frames(2)
	_check("front window obscures the hand", cover.get_global_rect().has_point(_center(hud.slots["hand_r"])))
	_check("front window blocks dropping into the hand behind it", hud._drop_target(_center(hud.slots["hand_r"])).is_empty())
	cover.queue_free()
	await _frames(2)
	hud.open_window("help", null)
	hud.open_window("skills", null)
	await _frames(2)
	_key(KEY_ESCAPE)
	await _frames(2)
	_check("Escape closes only the front window", _window("skills") == null and _window("help") != null)
	_key(KEY_ESCAPE)
	await _frames(2)
	_check("second Escape closes the remaining window", _window("help") == null)
	hud.open_chat("unfinished message")
	_key(KEY_ESCAPE)
	await _frames(2)
	_check("Escape cancels chat and releases typing focus", not hud.chat_input.visible and not hud.chat_active())
	hud.drag_press(wrench, _center(hud.slots["hand_r"]), Callable())
	hud.slots["hand_r"]._pressed = true
	_key(KEY_ESCAPE)
	_check("Escape cancels a pending drag", hud.drag_item == null and not hud.dragging)
	_check("cancelling a drag clears its slot's pressed state", not hud.slots["hand_r"]._pressed)
	var temporary := Proto.spawn("flashlight", p.cell)
	hud.drag_press(temporary, _world_screen(p.cell), Callable())
	temporary.destroy()
	await _frames(1)
	_mouse(_center(hud.slots["hand_l"]), MOUSE_BUTTON_LEFT, false)
	await _frames(1)
	_check("releasing a destroyed pickup cancels safely", hud.drag_item == null and not hud.dragging)

	# 6. a plain click on the left hand still selects it
	await _click(_center(hud.slots["hand_l"]))
	_check("click selects hand", inv.active == 0)
	# ...and clicking the other hand switches to it even when it holds something
	await _click(_center(hud.slots["hand_r"]))
	_check("click switches to a full hand", inv.active == 1 and inv.hands[1] == wrench)
	await _click(_center(hud.slots["hand_l"]))

	# 7. equip by dragging: a beanie onto the head slot (take whatever's there off first)
	if inv.worn("head"):
		inv.worn("head").destroy()
		inv.slots.erase("head")
	var hat := Proto.spawn("beanie", p.cell)
	inv.put_in_hands(hat, 0)
	hud.refresh_inventory()
	await _frames(2)
	await _drag(_center(hud.slots["hand_l"]), _center(hud.slots["head"]))
	_check("hand -> head slot", inv.worn("head") == hat)
	await _frames(10)
	await _shot("inventory")
	# the examine bar names what's under the mouse and what a click would do
	var npc := Proto.spawn("toolbox", _free_adjacent(p.cell))
	_mouse(_world_screen(npc.cell))
	await _frames(3)
	_check("examine bar names what's under the mouse (%s)" % hud.examine_label.text, hud.examine_label.text == npc.display_name.capitalize() and hud.panels["examine"].visible)
	await _shot("examine")
	npc.destroy()

	# 8. skills: the screen opens, and earning XP levels you up with a toast
	hud.open_window("skills", null)
	await _frames(5)
	var sw := _window("skills")
	_check("skills window opens", sw != null and sw.find_children("*", "SkillsPanel", true, false).size() == 1)
	var lvl0 := Skills.level(p, "engineering")
	Skills.add_xp(p, "engineering", Skills.level_to_xp(lvl0 + 3) - p.c(&"mob").xp.get("engineering", 0.0))
	await get_tree().create_timer(0.6).timeout
	_check("XP levels a skill up", Skills.level(p, "engineering") >= lvl0 + 3)
	_check("level-up toast shows", hud._toasts.size() >= 1)
	await _shot("skills")
	for w in hud.windows.get_children():
		w.queue_free()
	hud.open_window("objectives", null)
	await _frames(4)
	await _shot("objectives")
	for w in hud.windows.get_children():
		w.queue_free()
	Proto.spawn("glass_shard", p.cell)
	Proto.spawn("cable_coil", p.cell)
	hud.open_window("crafting", null)
	await _frames(3)
	var got := Crafting.gather(p, "shiv")
	for k in got.size():
		hud.craft_grid[k] = got[k]
	_window("crafting").refresh_t = 0.0
	await _frames(4)
	_check("crafting window shows a match", Crafting.match_grid(hud.craft_grid) == "shiv")
	await _shot("crafting")
	for w in hud.windows.get_children():
		w.queue_free()
	hud.open_window("station_map", null)
	await _frames(4)
	await _shot("station_map")
	for w in hud.windows.get_children():
		w.queue_free()
	await _frames(2)

	# 8b. hotbar: drag a carried item onto a hotkey slot; the key draws it from the bag
	var tool := Proto.spawn("wrench", p.cell)
	inv.put_in_hands(tool, inv.active)
	await _frames(2)
	hud.refresh_inventory()
	var hand_slot: InvSlot = hud.slots["hand_l" if inv.active == 0 else "hand_r"]
	await _drag(_center(hand_slot), _center(hud.slots["hot_0"]))
	_check("hotbar: drag binds the item", p.c(&"mob").hotbar[0] == tool and tool in inv.hands)
	DragDrop.apply(p, tool, {"kind": "store", "container": bag}, false)
	for hh in inv.hands.size():
		if inv.hands[hh] and inv.hands[hh] != tool:
			inv.drop(inv.hands[hh])
	hud.use_hotbar(0)
	_check("hotbar: the key draws it from the bag", tool in inv.hands and inv.active_item() == tool)
	await _frames(2)

	# inline rows: click the backpack to open it above the hands; items underfoot show too
	Proto.spawn("flashlight", p.cell)
	Proto.spawn("glass_shard", p.cell)
	for hh in inv.hands.size():
		if inv.hands[hh]:
			inv.drop(inv.hands[hh], _free_adjacent(p.cell))
	await get_tree().create_timer(0.4).timeout
	await _frames(2)
	await _click(_center(hud.slots["back"]))
	await _frames(4)
	_check("clicking the backpack opens its row", hud.bag_open == bag and hud.bag_box.visible and hud.bag_row.get_child_count() >= bag.c(&"storage").contents.size())
	_check("items underfoot show in the floor row", hud.floor_box.visible and hud.floor_row.get_child_count() >= 2)
	var stable_bag_slot := hud.bag_row.get_child(0)
	var stable_floor_slot := hud.floor_row.get_child(0)
	hud.refresh_inventory()
	_check("hand refresh preserves unchanged bag and floor controls", hud.bag_row.get_child(0) == stable_bag_slot and hud.floor_row.get_child(0) == stable_floor_slot)
	var fl: InvSlot = hud.floor_row.get_child(0)
	var fl_item := fl.item
	await _click(_center(fl))
	await _frames(3)
	_check("clicking a floor item picks it up", fl_item in inv.hands)
	var sgl := Proto.spawn("sunglasses", p.cell)
	var cg := Proto.spawn("cigarette", p.cell)
	if inv.worn("eyes"):
		inv.unequip("eyes")
	if inv.worn("mask"):
		inv.unequip("mask")
	inv.equip(sgl, "eyes")
	inv.equip(cg, "mask")
	p.c(&"mob").refresh_doll()
	for hh in inv.hands.size():
		if inv.hands[hh]:
			inv.drop(inv.hands[hh], _free_adjacent(p.cell))
	p.c(&"mob").refresh_doll()
	p.c(&"mob").face(2)
	Game.view.zoom_level = 4.0
	await _frames(3)
	await _shot("rows")
	Game.view.zoom_level = 2.0
	hud.bag_open = null
	hud.refresh_inventory()

	# HUD colour themes: switch live, then back
	UITheme.set_theme("Amber")
	await _frames(3)
	_check("theme tints the panels", (hud.panels["hands"].get_theme_stylebox("panel") as StyleBoxTexture).modulate_color.r > 1.1)
	await _shot("theme_amber")
	UITheme.set_theme("Steel")
	await _frames(2)

	# 9. HUD layout mode: move the status panel
	var st: Control = hud.panels["combat"]
	var before := st.global_position
	hud.toggle_layout_mode()
	await _frames(3)
	await _shot("layout")
	await _drag(st.get_global_rect().get_center(), st.get_global_rect().get_center() + Vector2(-300, -200))
	_check("layout: vitals panel moved", st.global_position.distance_to(before + Vector2(-300, -200)) < 8.0)
	hud.toggle_layout_mode()
	_check("layout saved", FileAccess.file_exists(HUD.LAYOUT_FILE))
	hud.reset_layout()
	await _frames(3)
	_check("layout reset", st.global_position.distance_to(before) < 24.0)

	print("UITEST DONE: %d failed" % fails)
	get_tree().quit()

# ------------------------------------------------------------------ helpers
func _check(what: String, ok: bool) -> void:
	print("UITEST %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _window(kind: String) -> UIWindow:
	for w in Game.hud.windows.get_children():
		if w is UIWindow and w.kind == kind and not w.is_queued_for_deletion():
			return w
	return null

func _storage_cells(w: UIWindow) -> Array:
	var out := []
	if w == null:
		return out
	for n in w.find_children("*", "InvSlot", true, false):
		out.append(n)
	return out

func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

func _world_screen(cell: Vector2i) -> Vector2:
	var pos := Entity.cell_to_pos(cell) - Vector2(0, 12)
	return get_viewport().get_canvas_transform() * pos

func _free_adjacent(c: Vector2i) -> Vector2i:
	for d in Defs.DIRS8:
		var n: Vector2i = c + d
		if Game.map.is_passable(n) and Game.at(n).is_empty():
			return n
	return c

func _to_window(pos: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * pos

func _mouse(pos: Vector2, button := 0, pressed := false) -> void:
	# never warp the real cursor; the HUD tracks the mouse from these events
	var wp := _to_window(pos)
	var ev: InputEvent
	if button == 0:
		var mm := InputEventMouseMotion.new()
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		mm.relative = wp - _last
		ev = mm
	else:
		var mb := InputEventMouseButton.new()
		mb.button_index = button
		mb.pressed = pressed
		ev = mb
	ev.position = wp
	ev.global_position = wp
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	_last = wp

func _drag(a: Vector2, b: Vector2, shot_midway := false) -> void:
	_mouse(a)
	await _frames(2)
	_mouse(a, MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	for i in range(1, 11):
		_mouse(a.lerp(b, i / 10.0), 0, true)
		await _frames(1)
	if shot_midway:
		await _frames(2)
		await _shot("dragging")
	_mouse(b, MOUSE_BUTTON_LEFT, false)
	await _frames(3)

func _click(a: Vector2) -> void:
	_mouse(a)
	await _frames(2)
	_mouse(a, MOUSE_BUTTON_LEFT, true)
	await _frames(1)
	_mouse(a, MOUSE_BUTTON_LEFT, false)
	await _frames(2)

func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	ev = InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _shot(nm: String) -> void:
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		_check("screenshot saved: " + nm, img.save_png("%s/ui_%s.png" % [dir, nm]) == OK)
