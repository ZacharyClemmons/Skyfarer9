class_name Blood extends RefCounted
## tg forensics blood (code/modules/forensics/forensics_helpers.dm): blood gets onto worn
## clothes, gloves or bare hands, and the weapon that drew it. A bloodied item is
## "blood-stained" on examine and wears a stain on the paper doll; water washes it off.

## tg ITEM_SLOT_* -> this game's inventory slots
const SLOT := {"iclothing": "uniform", "oclothing": "suit", "gloves": "gloves", "feet": "shoes", "mask": "mask", "head": "head", "eyes": "eyes"}

static func can_bleed(h: CHealth) -> bool:
	return h != null and h.blood_volume > 0.0

static func stain_item(it: Entity, from: CHealth = null) -> void:
	if it == null or it.removed:
		return
	if from:
		Forensics.add_blood(it, from)
	if not it.get_meta("bloody", false):
		it.set_meta("bloody", true)
		if it.spr:
			it.spr.self_modulate = Color(1.0, 0.82, 0.82)

static func clean_item(it: Entity) -> bool:
	if it and it.has_meta("forensics"):
		Forensics.wash(it) # tg CLEAN_WASH: blood, prints and fibres
	if it and it.get_meta("bloody", false):
		it.remove_meta("bloody")
		if it.spr:
			it.spr.self_modulate = Color.WHITE
		return true
	return false

static func bloody(it: Entity) -> bool:
	return it != null and it.get_meta("bloody", false)

## tg human/add_blood_DNA_to_items: `slots` are tg slot names (iclothing, oclothing,
## gloves, feet, mask, head, eyes, hands).
static func add_to_items(mob: Entity, slots: Array, from: CHealth = null) -> void:
	var inv: CInventory = mob.c(&"inv")
	if inv == null:
		return
	var s := slots.duplicate()
	# don't messy up the jumpsuit under a coat
	if "oclothing" in s and inv.worn("suit") != null:
		s.erase("iclothing")
	var dirty_hands: bool = "gloves" in s or "hands" in s
	var dirty_feet: bool = "feet" in s
	for k in s:
		if not SLOT.has(k):
			continue
		var it: Entity = inv.worn(SLOT[k])
		if it:
			stain_item(it, from)
	if inv.worn("gloves") != null:
		dirty_hands = false
	if inv.worn("shoes") != null:
		dirty_feet = false
	if "hands" in s:
		for it in inv.hands:
			if it:
				stain_item(it, from)
	if dirty_hands:
		mob.tags["bloody_hands"] = Game.rng.randi_range(2, 4)
		if from:
			mob.set_meta("hand_blood", {Forensics.dna(from.e): from.blood_type}) # tg: blood_in_hands carries DNA
	if dirty_feet:
		mob.tags["bloody_feet"] = maxf(mob.tags.get("bloody_feet", 0.0), 50.0)
	var m: CMob = mob.c(&"mob")
	if m:
		m.refresh_doll()

## tg wash (sinks wash hands and what's held; showers and space cleaner everything worn)
static func wash(mob: Entity, everything: bool) -> void:
	mob.tags.erase("bloody_hands")
	mob.remove_meta("hand_blood")
	var inv: CInventory = mob.c(&"inv")
	if inv == null:
		return
	var changed := false
	for it in inv.hands:
		changed = clean_item(it) or changed
	if everything:
		mob.tags.erase("bloody_feet")
		for sl in ["uniform", "suit", "head", "mask", "gloves", "shoes", "eyes", "back", "belt"]:
			changed = clean_item(inv.worn(sl)) or changed
	else:
		changed = clean_item(inv.worn("gloves")) or changed
	var m: CMob = mob.c(&"mob")
	if m and changed:
		m.refresh_doll()

## tg get_examine_name: "a blood-stained <thing>"
static func title(it: Entity) -> String:
	if bloody(it):
		return "a blood-stained %s" % it.display_name
	return it.display_name
