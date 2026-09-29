class_name CInventory extends Component
## Hands + equipment slots of a humanoid (tg: /mob/living/carbon/human inventory).

const SLOTS := ["uniform", "suit", "head", "mask", "gloves", "shoes", "back", "belt", "id", "ears", "eyes", "pocket_l", "pocket_r"]
const DOLL_SLOT := {"uniform": "uniform", "suit": "suit", "head": "head", "mask": "mask", "gloves": "gloves", "shoes": "shoes", "back": "back", "belt": "belt"}

var hands: Array = [null, null]
var active := 1 # 0 left, 1 right
var slots := {}

func key() -> StringName:
	return &"inv"

func active_item() -> Entity:
	return hands[active]

func other_item() -> Entity:
	return hands[1 - active]

func free_hand() -> int:
	for hand in [active, 1 - active]:
		if hand_available(hand):
			return hand
	return -1

func hand_usable(hand: int) -> bool:
	if hand < 0 or hand >= hands.size(): return false
	var health: CHealth = e.c(&"health")
	return health == null or not Body.limb_disabled(health, "l_arm" if hand == 0 else "r_arm")

func hand_available(hand: int) -> bool:
	if not hand_usable(hand) or hands[hand] != null:
		return false
	var other: Entity = hands[1 - hand]
	return other == null or not other.has_c(&"item") or not other.c(&"item").is_wielded

func can_hold(item: Entity) -> bool:
	if not is_instance_valid(item) or item.removed or Traits.has(e, "animal_body"):
		return false
	var d: CDna = e.c(&"dna")
	return not (d and d.has_mutation("elastic_arms") and item.has_c(&"item") and item.c(&"item").w_class > 4 and not item.tags.get("abstract_hand", false))

func worn(slot: String) -> Entity:
	return slots.get(slot)

func _attach(item: Entity) -> void:
	Interact.detach(item, item.holder != e)
	item.holder = e
	item.visible = false
	var b = item.c(&"blocker")
	if b:
		b.on_removed()

func put_in_hands(item: Entity, prefer := -1) -> bool:
	if not is_instance_valid(item) or item.removed: return false
	if Traits.has(e, "animal_body"):
		return false
	var d: CDna = e.c(&"dna")
	if d and d.has_mutation("elastic_arms") and item.has_c(&"item") and item.c(&"item").w_class > 4 and not item.tags.get("abstract_hand", false):
		Game.tell(e, "Your arms are too floppy to hold that!", "warn")
		return false
	var h := prefer if hand_available(prefer) else free_hand()
	if h < 0:
		return false
	_attach(item)
	hands[h] = item
	_refresh()
	return true

func drop(item: Entity, where = null) -> void:
	if item == null:
		return
	if item.has_c(&"mineralhand"):
		item.destroy()
		return
	if item.tags.get("telekinetic_grab", false):
		item.destroy()
		return
	if item.tags.has("self_grasp"):
		# tg DROPDEL hand item: letting go of your own wound
		Interact.release_grasp(e)
		return
	if item.has_c(&"item"):
		item.c(&"item").is_wielded = false
	var c: Vector2i = where if where != null else e.cell
	remove_ref(item, false)
	item.holder = null
	item.visible = true
	item.cell = c
	Game.drop_to_map(item, c)
	item.place(c)
	# tg: things dropped on the floor land a little scattered, not dead centre
	if not Game.at(c).any(func(x): return x.has_c(&"furniture") and x.c(&"furniture").kind in ["table", "counter"]):
		item.set_pixel_offset(Vector2(Game.rng.randi_range(-5, 5), Game.rng.randi_range(-4, 3)))
	_refresh()

func remove_ref(item: Entity, refresh := true) -> void:
	for i in 2:
		if hands[i] == item:
			hands[i] = null
	for s in slots.keys():
		if slots[s] == item:
			slots.erase(s)
	if refresh:
		_refresh()

func can_equip(item: Entity, slot: String) -> bool:
	if Traits.has(e, "animal_body"): return false
	if item.tags.get("abstract_hand", false):
		return false
	if slot == "gloves" and Traits.has(e, "chunkyfingers"):
		return false
	if slots.has(slot):
		return false
	var it: CItem = item.c(&"item")
	if it == null:
		return false
	if slot in ["pocket_l", "pocket_r"]:
		return it.w_class <= 2 and slots.has("uniform")
	if slot in ["id", "belt"] and not slots.has("uniform"):
		return false
	return slot in it.slots

func equip(item: Entity, slot: String) -> bool:
	if not can_equip(item, slot):
		return false
	_attach(item)
	slots[slot] = item
	_refresh()
	return true

## Equip into the first fitting slot (used by the E key and by NPC dressing).
func quick_equip(item: Entity) -> bool:
	var it: CItem = item.c(&"item")
	if it == null:
		return false
	for s in it.slots:
		if can_equip(item, s):
			return equip(item, s)
	return false

func unequip(slot: String) -> Entity:
	var item: Entity = slots.get(slot)
	if item == null:
		return null
	if free_hand() < 0:
		return null
	slots.erase(slot)
	hands[free_hand()] = item
	_refresh()
	return item

## Into the first worn bag (back, then belt) with room, like tg's give_item_to_holder
## LOCATION_BACKPACK. False if nothing has room.
func store(item: Entity) -> bool:
	for slot in ["back", "belt"]:
		var bag: Entity = worn(slot)
		if bag and bag.has_c(&"storage") and bag.c(&"storage").insert(item):
			return true
	return false

func all_items(deep := true) -> Array:
	for i in 2:
		if hands[i] != null and (not is_instance_valid(hands[i]) or hands[i].removed):
			hands[i] = null
	for s in slots.keys():
		if not is_instance_valid(slots[s]) or slots[s].removed:
			slots.erase(s)
	var out := []
	for h in hands:
		if h != null:
			out.append(h)
	for s in slots.values():
		out.append(s)
	if deep:
		for s in ["back", "belt"]:
			var cont: Entity = slots.get(s)
			if cont and cont.has_c(&"storage"):
				for it in cont.c(&"storage").contents:
					if is_instance_valid(it) and not it.removed:
						out.append(it)
	return out

func find_item(pred: Callable) -> Entity:
	for it in all_items():
		if pred.call(it):
			return it
	return null

func find_tool(quality: String) -> Entity:
	return find_item(func(it): return it.has_c(&"item") and it.c(&"item").tool == quality)

func id_card() -> CIdCard:
	for cand in [slots.get("id"), hands[active], hands[1 - active]]:
		if cand != null and cand.has_c(&"idcard"):
			return cand.c(&"idcard")
	return null

func has_access(tag: String) -> bool:
	var id := id_card()
	return id != null and (tag in id.access or "all" in id.access)

func insulation() -> float:
	var ins := 0.0
	for s in ["uniform", "suit", "head", "mask", "gloves", "shoes"]:
		var it: Entity = slots.get(s)
		if it and it.has_c(&"clothing"):
			ins += it.c(&"clothing").insulation
	return clampf(ins, 0.0, 0.95)

func heat_protection() -> float:
	var hp := 0.0
	for s in slots.values():
		if s.has_c(&"clothing"):
			hp += s.c(&"clothing").heat_protection
	return clampf(hp, 0.0, 0.95)

func armor() -> float:
	var a := 0.0
	for s in slots.values():
		if s.has_c(&"clothing"):
			a += s.c(&"clothing").armor
	return clampf(a, 0.0, 0.8)

func slowdown() -> float:
	var sd := 0.0
	for s in slots.values():
		if s.has_c(&"clothing"):
			sd += s.c(&"clothing").slowdown
	return sd

func headset() -> CHeadset:
	var hs: Entity = slots.get("ears")
	return hs.c(&"headset") if hs and hs.has_c(&"headset") else null

func _refresh() -> void:
	var mob = e.c(&"mob")
	if mob:
		mob.refresh_doll()
	if e == Game.player and Game.hud:
		Game.hud.refresh_inventory()

func examine(_user: Entity, lines: Array) -> void:
	for s in ["uniform", "suit", "head", "mask", "gloves", "shoes"]:
		var it: Entity = slots.get(s)
		if it:
			lines.append(("[color=#ff8a7a]They are wearing %s![/color]" if Blood.bloody(it) else "They are wearing %s.") % Blood.title(it))
	# tg carbon examine: bare hands with blood on them
	if slots.get("gloves") == null and e.tags.get("bloody_hands", 0) > 0:
		lines.append("[color=#ff8a7a]They have blood-stained hands![/color]")
	for s in ["back", "belt"]:
		var it: Entity = slots.get(s)
		if it:
			lines.append("They have %s on their %s." % [it.display_name, s])
	for i in 2:
		if hands[i]:
			lines.append("They are holding %s in their %s hand." % [Blood.title(hands[i]), "left" if i == 0 else "right"])
