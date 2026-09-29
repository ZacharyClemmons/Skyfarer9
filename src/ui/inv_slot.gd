class_name InvSlot extends Control
## One HUD inventory slot (hand, equipment, or a cell of a bag's storage grid), SS13
## style: a faint slot icon when empty and the item sprite when filled.
## Left click = interact (on release, so a press can turn into a drag), right click = verbs.
## Drag an item out of a slot to move it (see DragDrop).

signal clicked(slot: String, button: int)

var slot := ""
var icon_name := ""
var item: Entity = null
var container: Entity = null # set for storage-grid cells
var drop_destination: Dictionary = {}
var active := false
var hot := false
var drop_hint := 0 # 1 = the dragged item can go here, -1 = it can't
var _pressed := false
var _seen_set := false
var _icon_tw: Tween
var item_icon: TextureRect # the item, as a child so it can carry the item's recolouring material
var count_label: Label

func _init(s: String, icon: String, sz := 56) -> void:
	slot = s
	icon_name = icon
	custom_minimum_size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = s.capitalize().replace("_", " ")
	item_icon = TextureRect.new()
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	item_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_icon.offset_left = 3
	item_icon.offset_top = 3
	item_icon.offset_right = -3
	item_icon.offset_bottom = -3
	add_child(item_icon)
	count_label = UITheme.label("", 14, Color.WHITE)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	count_label.offset_right = -5
	count_label.offset_bottom = -3
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	count_label.add_theme_constant_override("outline_size", 4)
	add_child(count_label)

func _enter_tree() -> void:
	if Game.hud:
		Game.hud.drop_slots.append(self)

func _exit_tree() -> void:
	if Game.hud:
		Game.hud.drop_slots.erase(self)

## Where an item dropped on this slot goes (DragDrop destination).
func destination() -> Dictionary:
	if not drop_destination.is_empty():
		return drop_destination
	if container != null:
		return {"kind": "store", "container": container}
	if slot.begins_with("hot_"):
		return {"kind": "hotbar", "idx": int(slot.substr(4))}
	if slot.begins_with("craft_"):
		return {"kind": "craft", "idx": int(slot.substr(6))}
	if slot == "hand_l":
		return {"kind": "hand", "idx": 0}
	if slot == "hand_r":
		return {"kind": "hand", "idx": 1}
	return {"kind": "equip", "slot": slot}

func contains_drop(pos: Vector2) -> bool:
	if not is_visible_in_tree() or not get_global_rect().has_point(pos):
		return false
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().has_point(pos):
			return false
		ancestor = ancestor.get_parent()
	return true

func set_item(it: Entity) -> void:
	if not is_instance_valid(it) or it.removed:
		it = null
	var arrived := it != null and it != item and _seen_set and is_inside_tree()
	_seen_set = true
	item = it
	var label := slot.capitalize().replace("_", " ") if container == null else ""
	if slot.begins_with("hot_"):
		label = "Hotbar %s\nDrag an item you carry here; press %s to draw or use it." % [HOT_KEYS[int(slot.substr(4))], HOT_KEYS[int(slot.substr(4))]]
	count_label.text = str(it.c(&"stack").amount) if it and it.has_c(&"stack") else ""
	tooltip_text = it.display_name.capitalize() if it else label
	if it and it.has_c(&"stack"):
		tooltip_text += " (%d)" % it.c(&"stack").amount
	if it and slot.begins_with("hot_"):
		tooltip_text += "\n" + label
	if slot in ["hand_l", "hand_r"]:
		var hand_name := "Left hand" if slot == "hand_l" else "Right hand"
		tooltip_text = (tooltip_text + "\n" if it else "") + hand_name
		tooltip_text += "\nClick to use the held item" if active and it else "\nClick to select this hand"
		tooltip_text += "\nDrag to move; right-click for actions" if it else "\nDrag an item here to hold it"
		if Game.player and not Game.player.c(&"inv").hand_usable(0 if slot == "hand_l" else 1):
			tooltip_text += "\nThis hand cannot hold items right now"
	if it and it.spr and it.spr.texture:
		item_icon.texture = icon_of(it)
		item_icon.material = it.spr.material
		item_icon.modulate = it.spr.modulate
		item_icon.visible = true
	else:
		item_icon.visible = false
	if arrived and item_icon.visible:
		_pop_icon()
	queue_redraw()

## An item landing in the slot: a quick squash-and-settle plus a soft thunk.
func _pop_icon() -> void:
	item_icon.pivot_offset = item_icon.size * 0.5
	item_icon.scale = Vector2(0.6, 0.6)
	if _icon_tw and _icon_tw.is_valid():
		_icon_tw.kill()
	_icon_tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_icon_tw.tween_property(item_icon, "scale", Vector2.ONE, 0.2)
	Sfx.play_ui("ui_pop", 0.45, randf_range(0.95, 1.1))

func _process(_delta: float) -> void:
	if item == null:
		return
	if not is_instance_valid(item) or item.removed:
		set_item(null)
	elif item.has_c(&"stack") and count_label.text != str(item.c(&"stack").amount):
		set_item(item)

static func icon_of(it: Entity) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = it.spr.texture
	at.region = it.spr.region_rect
	return at

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_pressed = true
				if item and Game.hud:
					Game.hud.drag_press(item, Game.hud.mouse, Callable())
			elif _pressed:
				# a drag that started here swallows the release before it gets this far
				_pressed = false
				if Rect2(Vector2.ZERO, size).has_point(ev.position):
					clicked.emit(slot, MOUSE_BUTTON_LEFT)
			accept_event()
		elif ev.pressed:
			clicked.emit(slot, ev.button_index)
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hot = true
		if item != null:
			Sfx.play_ui("ui_hover", 0.45, 1.15)
			item_icon.pivot_offset = item_icon.size * 0.5
			if _icon_tw and _icon_tw.is_valid():
				_icon_tw.kill()
			_icon_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_icon_tw.tween_property(item_icon, "scale", Vector2.ONE * 1.1, 0.08)
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		hot = false
		if _icon_tw and _icon_tw.is_valid():
			_icon_tw.kill()
		_icon_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_icon_tw.tween_property(item_icon, "scale", Vector2.ONE, 0.1)
		queue_redraw()

func set_drop_hint(v: int) -> void:
	if v != drop_hint:
		if v > 0:
			Sfx.play_ui("ui_tick", 0.35, 1.3)
		drop_hint = v
		queue_redraw()

const HOT_KEYS := ["5", "6", "7", "8", "9", "0"]
static var _styles := {}

static func _style(state: String) -> StyleBoxTexture:
	if not _styles.has(state):
		_styles[state] = UITheme.frame("slot_" + state, 0, 0)
	return _styles[state]

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(_style("active" if active else ("hot" if hot else "normal")), r)
	if drop_hint != 0:
		var col := UITheme.GOOD if drop_hint > 0 else UITheme.BAD
		draw_rect(r.grow(-4), Color(col, 0.18))
		draw_rect(r.grow(-2), col, false, 2.0)
	if item == null and icon_name != "" and Gfx.has("fx", "ui_" + icon_name):
		var reg := Gfx.region("fx", "ui_" + icon_name)
		var s := size.x * 0.62
		draw_texture_rect_region(Gfx.tex("fx"), Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s)), reg, Color(1, 1, 1, 0.28))
	if slot.begins_with("hot_"):
		var k: String = HOT_KEYS[int(slot.substr(4))]
		draw_string_outline(UITheme.font, Vector2(5, 15), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.9))
		draw_string(UITheme.font, Vector2(5, 15), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.ACCENT if item else UITheme.DIM)
