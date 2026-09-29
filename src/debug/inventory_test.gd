class_name InventoryTest extends UITest
## --autotest --inventorytest=build/polish: actual mouse-driven inventory transfers.

func _run() -> void:
	if dir != "":
		dir = ProjectSettings.globalize_path("res://" + dir) if not dir.is_absolute_path() else dir
		DirAccess.make_dir_recursive_absolute(dir)
	await _frames(20)
	var hud: HUD = Game.hud
	var p := Game.player
	var inv: CInventory = p.c(&"inv")
	for it in inv.hands.duplicate():
		if it: inv.drop(it)
	if inv.worn("back") == null:
		inv.equip(Proto.spawn("backpack", p.cell), "back")
	var bag := inv.worn("back")
	var wrench := Proto.spawn("wrench", p.cell)
	inv.put_in_hands(wrench, 1)
	inv.active = 1
	_key(KEY_TAB)
	await _frames(15)
	var panel := _window("inventory") as InventoryPanel
	_check("Tab opens actual inventory", panel != null)
	if panel == null:
		get_tree().quit(1)
		return
	_check("all equipment and hands are shown", panel.equipment.size() == 15)
	_check("inventory fits horizontally", panel.size.x <= get_viewport().get_visible_rect().size.x)
	var bag_slot: InvSlot = panel.bags.back.slots[0]
	await _drag(_center(panel.equipment.hand_r), _center(bag_slot), true)
	_check("hand to backpack by dragging", wrench.holder == bag and not wrench in inv.hands)
	await _frames(10)
	var stored: InvSlot
	for sl in panel.bags.back.slots:
		if sl.item == wrench: stored = sl
	_check("container grid updates after transfer", stored != null)
	if stored:
		await _drag(_center(stored), _center(panel.equipment.hand_l))
	_check("backpack to left hand by dragging", inv.hands[0] == wrench)
	await _frames(10)
	await _drag(_center(panel.equipment.hand_l), _center(panel.equipment.head))
	_check("invalid equipment drop preserves the item", inv.hands[0] == wrench)
	Game.paused = true
	_check("paused transfers are rejected", not DragDrop.apply(p, wrench, {"kind": "store", "container": bag}, false) and inv.hands[0] == wrench)
	Game.paused = false
	panel.scroll.scroll_vertical = 0
	await _frames(4)
	_mouse(_center(panel.equipment.hand_l))
	_mouse(_center(panel.equipment.hand_l), MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	_mouse(_center(panel.equipment.hand_l) + Vector2(20, 0), 0, true)
	panel.scroll.scroll_vertical = 9999
	await _frames(5)
	var floor_slot: InvSlot = panel.ground_slots[-1]
	_mouse(_center(floor_slot), 0, true)
	await _frames(2)
	_mouse(_center(floor_slot), MOUSE_BUTTON_LEFT, false)
	await _frames(10)
	_check("ground drop lands on the player's tile", wrench.holder == null and wrench.cell == p.cell)
	var pickup: InvSlot
	for sl in panel.ground_slots:
		if sl.item == wrench: pickup = sl
	if pickup: await _click(_center(pickup))
	_check("ground item can be picked up", wrench in inv.hands)
	panel.scroll.scroll_vertical = 0
	await _frames(10)
	if inv.worn("head"):
		inv.worn("head").destroy()
		inv.slots.erase("head")
	var hat := Proto.spawn("beanie", p.cell)
	var free := inv.free_hand()
	inv.put_in_hands(hat, free)
	hud.refresh_inventory()
	await _frames(3)
	await _drag(_center(panel.equipment.hand_l if free == 0 else panel.equipment.hand_r), _center(panel.equipment.head))
	_check("drag equips compatible headwear", inv.worn("head") == hat)
	_mouse(_center(panel.equipment.head))
	_mouse(_center(panel.equipment.head), MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	_mouse(_center(panel.equipment.head) + Vector2(25, 0), 0, true)
	await _frames(2)
	_key(KEY_ESCAPE)
	_mouse(_center(panel.equipment.head), MOUSE_BUTTON_LEFT, false)
	await _frames(3)
	_check("Escape cancels dragging without unequipping", inv.worn("head") == hat and hud.drag_item == null and _window("inventory") == panel)
	await get_tree().create_timer(2.0).timeout
	await _frames(10)
	await _shot("inventory_panel")
	_mouse(_center(panel.equipment.head), MOUSE_BUTTON_RIGHT, true)
	await _frames(3)
	_check("right-click opens item actions", hud.context.visible and not hud.context_actions.is_empty())
	_mouse(_center(panel.equipment.head), MOUSE_BUTTON_RIGHT, false)
	hud.context.hide()
	_key(KEY_TAB)
	await _frames(3)
	_check("Tab closes inventory", _window("inventory") == null)
	print("INVENTORY DONE: %d failed" % fails)
	get_tree().quit(0 if fails == 0 else 1)
