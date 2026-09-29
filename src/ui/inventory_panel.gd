class_name InventoryPanel extends UIWindow
## Persistent slots keep drag targets stable while the inventory changes.

var equipment := {}
var bags := {}
var ground_slots: Array = []
var ground_grid: GridContainer
var ground_note: Label
var details: Label
var purse: Label
var preview: PaperDoll
var _tick := 0.0

func _init() -> void:
	super("Inventory  /  Tab", 800)
	kind = "inventory"
	body.add_theme_constant_override("separation", 12)
	var header := HBoxContainer.new()
	body.add_child(header)
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(100, 136)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(portrait)
	preview = PaperDoll.new()
	preview.position = Vector2(50, 132)
	preview.scale = Vector2(4, 4)
	portrait.add_child(preview)
	var intro := VBoxContainer.new()
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(intro)
	intro.add_child(UITheme.label("YOUR GEAR", UITheme.DISPLAY, UITheme.ACCENT))
	purse = UITheme.label("", UITheme.BODY, UITheme.WARN)
	intro.add_child(purse)
	var help := UITheme.label("Drag items between hands, equipment and bags.\nDrag onto the ground to drop. Right-click for actions.\nGreen slots accept the item; red slots cannot.", UITheme.BODY, UITheme.DIM)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_child(help)
	body.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	body.add_child(columns)
	var gear := VBoxContainer.new()
	gear.custom_minimum_size.x = 340
	columns.add_child(gear)
	gear.add_child(UITheme.caption("Hands & equipment", UITheme.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	gear.add_child(grid)
	for slot in ["hand_l", "hand_r", "back", "belt", "head", "eyes", "ears", "mask", "suit", "uniform", "gloves", "shoes", "pocket_l", "pocket_r", "id"]:
		var cell := VBoxContainer.new()
		grid.add_child(cell)
		var sl := InvSlot.new(slot, slot, 72)
		sl.clicked.connect(func(s, b): Game.hud._on_slot_clicked(s, b))
		equipment[slot] = sl
		cell.add_child(sl)
		var caption := UITheme.label(_slot_name(slot), 13, UITheme.DIM)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(caption)
	var cargo := VBoxContainer.new()
	cargo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cargo.add_theme_constant_override("separation", 12)
	columns.add_child(cargo)
	for slot in ["back", "belt"]:
		var section := VBoxContainer.new()
		cargo.add_child(section)
		var title := UITheme.caption("", UITheme.ACCENT)
		section.add_child(title)
		var meter := ProgressBar.new()
		meter.custom_minimum_size.y = 8
		meter.show_percentage = false
		section.add_child(meter)
		var bag_grid := GridContainer.new()
		bag_grid.columns = 5
		bag_grid.add_theme_constant_override("h_separation", 4)
		bag_grid.add_theme_constant_override("v_separation", 4)
		section.add_child(bag_grid)
		var note := UITheme.label("", UITheme.SMALL, UITheme.DIM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section.add_child(note)
		bags[slot] = {"title": title, "meter": meter, "grid": bag_grid, "note": note, "slots": []}
	body.add_child(HSeparator.new())
	body.add_child(UITheme.caption("At your feet  /  drop items here", UITheme.ACCENT))
	ground_grid = GridContainer.new()
	ground_grid.columns = 10
	ground_grid.add_theme_constant_override("h_separation", 4)
	ground_grid.add_theme_constant_override("v_separation", 4)
	body.add_child(ground_grid)
	ground_note = UITheme.label("", UITheme.SMALL, UITheme.DIM)
	body.add_child(ground_note)
	details = UITheme.label("Hover over an item to inspect it.", UITheme.BODY, UITheme.TEXT)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.y = 48
	body.add_child(details)

static func _slot_name(slot: String) -> String:
	return {"hand_l": "Left hand", "hand_r": "Right hand", "back": "Backpack", "pocket_l": "L pocket", "pocket_r": "R pocket", "id": "Pass"}.get(slot, slot.capitalize())

func _ready() -> void:
	_sync()
	_fit_height.call_deferred()
	_center_initial.call_deferred()

func _center_initial() -> void:
	await get_tree().process_frame
	_fit_height()
	reset_size()
	_want = (get_parent_area_size() - size) * 0.5
	_clamp()

func _process(delta: float) -> void:
	super(delta)
	if Game.player == null:
		queue_free()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.1
		_sync()
	var hovered: Entity = null
	for sl in Game.hud.drop_slots:
		if is_ancestor_of(sl) and sl.is_visible_in_tree() and sl.hot and is_instance_valid(sl.item):
			hovered = sl.item
			break
	if hovered:
		var item: CItem = hovered.c(&"item")
		var desc := hovered.desc.replace("[b]", "").replace("[/b]", "").replace("[i]", "").replace("[/i]", "")
		details.text = "%s%s\n%s" % [hovered.display_name.capitalize(), "  /  size %d" % item.w_class if item else "", desc]
	else:
		details.text = "Hover to inspect. Click a bag item to take it into a free hand.\nEsc or right-click cancels a drag. Tab closes your inventory."

func _sync() -> void:
	var p := Game.player
	if p == null:
		return
	var inv: CInventory = p.c(&"inv")
	purse.text = "%s  /  %s marks" % [p.display_name, Economy.money(Economy.purse(p))]
	for slot in equipment:
		var sl: InvSlot = equipment[slot]
		var hand := ["hand_l", "hand_r"].find(slot)
		sl.active = hand == inv.active
		sl.set_item(inv.hands[hand] if hand >= 0 else inv.worn(slot))
	var mob: CMob = p.c(&"mob")
	if mob and mob.doll:
		for layer in PaperDoll.ORDER:
			preview.set_layer(layer, mob.doll.layer_src[layer])
			var source: Sprite2D = mob.doll.layers[layer]
			(preview.layers[layer].material as ShaderMaterial).set_shader_parameter("pal", (source.material as ShaderMaterial).get_shader_parameter("pal"))
	for slot in bags:
		var section: Dictionary = bags[slot]
		var bag := inv.worn(slot)
		var storage: CStorage = bag.c(&"storage") if bag else null
		if storage == null or storage.kind != "bag":
			section.title.text = _slot_name(slot).to_upper()
			section.note.text = "Equip a container here to use its storage."
			section.meter.visible = false
			section.grid.visible = false
			continue
		var used := storage.used()
		section.title.text = "%s  /  %d of %d" % [bag.display_name.to_upper(), used, storage.capacity]
		section.meter.visible = true
		section.meter.max_value = storage.capacity
		section.meter.value = used
		section.grid.visible = true
		section.note.text = "Capacity is based on item size. Drag onto any cell to store."
		var count := maxi(10, storage.contents.size() + 1)
		if storage.max_slots > 0:
			count = mini(count, storage.max_slots)
		_grow_slots(section.slots, section.grid, count, 60)
		for i in section.slots.size():
			var sl: InvSlot = section.slots[i]
			sl.visible = i < count
			sl.container = bag
			sl.set_item(storage.contents[i] if i < storage.contents.size() else null)
	var floor_items: Array = Game.at(p.cell).filter(func(e): return e.has_c(&"item") and e.holder == null and not e.removed and e.visible)
	_grow_slots(ground_slots, ground_grid, maxi(10, floor_items.size() + 1), 60)
	for i in ground_slots.size():
		var sl: InvSlot = ground_slots[i]
		sl.visible = i < maxi(10, floor_items.size() + 1)
		sl.drop_destination = {"kind": "world", "cell": p.cell, "ents": []}
		sl.set_item(floor_items[i] if i < floor_items.size() else null)
	ground_note.text = "%d nearby items. Empty cells drop items onto your current tile." % floor_items.size()
	_fit_height.call_deferred()

func _grow_slots(list: Array, grid: GridContainer, count: int, slot_size: int) -> void:
	while list.size() < count:
		var sl := InvSlot.new("contents", "", slot_size)
		sl.clicked.connect(func(_s, button):
			var p := Game.player
			if p == null or Game.paused:
				return
			if button == MOUSE_BUTTON_RIGHT and sl.item:
				Game.hud.show_context_for([sl.item], true)
			elif button == MOUSE_BUTTON_LEFT:
				var inv: CInventory = p.c(&"inv")
				if sl.item:
					var hand := inv.free_hand()
					if hand >= 0 and DragDrop.apply(p, sl.item, {"kind": "hand", "idx": hand}, false):
						inv.active = hand
					elif hand < 0:
						Game.tell(p, "Your hands are full. Drag the item into another bag or onto the ground.", "warn")
				elif inv.active_item():
					DragDrop.apply(p, inv.active_item(), sl.destination(), false)
				Game.hud.refresh_inventory())
		grid.add_child(sl)
		list.append(sl)
