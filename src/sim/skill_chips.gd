class_name SkillChips extends RefCounted
## TG brain limits: five physical slots, three active complexity, +1 from Biotech.
static func list_of(user: Entity) -> Array:
	if not user.has_meta("skillchips"): user.set_meta("skillchips", [])
	return user.get_meta("skillchips")
static func capacity(user: Entity) -> int:
	var d := Genetics.dna(user)
	return 3 + (1 if d and d.has_mutation("biotechcompat") else 0)
static func used_slots(user: Entity) -> int:
	var total := 0
	for chip in list_of(user):
		if is_instance_valid(chip) and not chip.removed: total += chip.c(&"skillchip").slot_use
	return total
static func used_complexity(user: Entity) -> int:
	var total := 0
	for chip in list_of(user):
		if is_instance_valid(chip) and not chip.removed and chip.c(&"skillchip").active: total += chip.c(&"skillchip").complexity
	return total
static func implant_error(user: Entity, item: Entity) -> String:
	if not user.has_c(&"health") or not Organs.has(user.c(&"health"), "brain"): return "No brain detected."
	var ch: CSkillChip = item.c(&"skillchip")
	if ch == null or ch.owner != null: return "Chip is already implanted or invalid."
	if not CSkillChip.DEFS.has(ch.kind): return "Unrecognized skillchip."
	if used_slots(user) + ch.slot_use > 5: return "Not enough free brain slots."
	for existing in list_of(user):
		if existing.c(&"skillchip").kind == ch.kind and not CSkillChip.DEFS.get(ch.kind, {}).get("multiple", false): return "Duplicate chip detected."
		if CSkillChip.DEFS[ch.kind].get("category", "general") == "job" and CSkillChip.DEFS[existing.c(&"skillchip").kind].get("category", "general") == "job": return "Incompatible job category chip."
	return ""

static func taunt(user: Entity, intentional: bool) -> bool:
	if not Traits.has(user, "matrix_taunt"): return true
	var h: CHealth = user.c(&"health")
	if intentional and h.stamina - 19.0 <= h.crit_threshold():
		Game.tell(user, "You are too tired to dodge.", "warn")
		return false
	for item in list_of(user):
		var chip: CSkillChip = item.c(&"skillchip")
		if chip.kind != "matrix_taunt" or not chip.active: continue
		var source := "skillchip:%d" % item.id
		if Traits.has_from(user, "unhittable_projectiles", source): return true
		Traits.add(user, "unhittable_projectiles", source)
		h.adjust("stamina", 19.0)
		Genetics.after(1.4, func():
			if is_instance_valid(user) and not user.removed: Traits.remove(user, "unhittable_projectiles", source))
	return true
static func implant(user: Entity, item: Entity) -> String:
	var error := implant_error(user, item)
	if error != "": return error
	Interact.detach(item)
	item.holder = user
	item.visible = false
	item.c(&"skillchip").owner = user
	list_of(user).append(item)
	return ""
static func remove(user: Entity, item: Entity) -> String:
	if not item in list_of(user): return "Chip is not implanted here."
	var chip: CSkillChip = item.c(&"skillchip")
	if Game.time < chip.ready: return "Chip is still recharging."
	if chip.active: chip.toggle(true)
	list_of(user).erase(item)
	chip.owner = null
	chip.ready = Game.time + 300.0
	item.holder = null
	item.visible = true
	Game.drop_to_map(item, user.cell)
	item.place(user.cell)
	if not chip.removable: item.destroy()
	return ""
static func update(user: Entity) -> void:
	var chips := list_of(user)
	for chip in chips.duplicate():
		if not is_instance_valid(chip) or chip.removed: chips.erase(chip)
	var brain_ok := user.has_c(&"health") and Organs.has(user.c(&"health"), "brain")
	for item in chips:
		if used_complexity(user) <= capacity(user) and brain_ok: break
		if item.c(&"skillchip").active:
			item.c(&"skillchip").toggle(true)
			Game.tell(user, "Skillchip failsafe: %s was deactivated." % item.display_name, "warn")
static func detach_brain(user: Entity, brain: Entity) -> void:
	var chips := list_of(user).duplicate()
	for item in chips:
		var ch: CSkillChip = item.c(&"skillchip")
		if ch.active: ch.toggle(true)
		Traits.remove_source(user, "skillchip:%d" % item.id)
		ch.active = false
		ch.owner = null
		item.holder = brain
	list_of(user).clear()
	brain.set_meta("skillchips", chips)
	brain.add(CSkillBrain.new())
static func restore_brain(user: Entity, brain: Entity) -> void:
	if not brain.has_meta("skillchips"): return
	for item in brain.get_meta("skillchips"):
		item.c(&"skillchip").owner = user
		item.holder = user
		list_of(user).append(item)
	brain.get_meta("skillchips").clear()
	update(user)

static func sing(text: String) -> String:
	var words := text.split(" ")
	if words.size() > 1:
		var last: String = words[-1]
		var vowel := ""
		for letter in last:
			if letter in "aeiouAEIOU": vowel = letter
		var final_word := ""
		var ellipsis := last.ends_with("...")
		for i in last.length():
			var letter := last[i]
			if letter == "." and i == last.length() - 1 and not ellipsis:
				final_word += "!"
			elif vowel != "" and letter == vowel:
				final_word += letter.repeat(4)
				if i == last.length() - 1: final_word += "."
			else: final_word += letter
		if not ellipsis and not final_word.ends_with("."): final_word += "!"
		words[-1] = final_word
	return "♪ " + " ".join(words) + " ♪"
