class_name GeneInteraction extends RefCounted
## TG ranged mutation hooks and telekinetic hand item, reimplemented through
## the same machinery/item interactions used by ordinary hands.
const TK_RANGE := 15

static func reflect_projectile(origin: Entity, firer: Entity, damage: float, kind: String) -> void:
	for cell in GenePowers._line(origin.cell, firer.cell, 12):
		if not Game.map.inb(cell) or Game.map.blocks_move_static(cell): return
		for mob in Game.at_with(cell, &"health"):
			if mob == origin or mob.c(&"health").dead: continue
			Fx.beam(origin.cell, cell, Color("#bda8ff"))
			mob.c(&"health").hurt_zone("chest", damage * 0.7, kind, firer)
			return

static func can_open(user: Entity, target: Entity) -> bool:
	if Genetics.can_reach(user, target):
		return true
	var d := Genetics.dna(user)
	return d != null and d.has_mutation("telekinesis") and target.dist_to(user) <= TK_RANGE and not target.has_c(&"mob")

static func click(user: Entity, target: Entity, cell: Vector2i, mods: Dictionary) -> bool:
	var d := Genetics.dna(user)
	var inv: CInventory = user.c(&"inv")
	if d == null or inv == null:
		return false
	var item := inv.active_item()
	if item and item.has_c(&"mineralhand"):
		item.c(&"mineralhand").use_on(user, cell)
		return true
	if item and item.has_c(&"tkgrab"):
		item.c(&"tkgrab").use_on(user, target, cell, mods.get("throw", false))
		return true
	if target and Genetics.can_reach(user, target):
		return false
	if d.has_mutation("laser_eyes") and user.c(&"mob").combat:
		if Game.time >= d.laser_ready:
			d.laser_ready = Game.time + 0.4
			var beam := CGadget.new()
			beam.e = user
			beam.kind = "gun"
			beam.sub = "laser"
			beam.charges = 1
			beam._shoot(user, cell)
		return true
	if not d.has_mutation("telekinesis") or item != null or target == null or target.has_c(&"mob") or target.holder != null or target.dist_to(user) > TK_RANGE:
		return false
	if target.has_c(&"item") or not target.tags.get("anchored", true):
		var grab := Proto.spawn("tk_grab", user.cell)
		var tk: CTkGrab = grab.c(&"tkgrab")
		tk.user = user
		tk.focus = target
		grab.display_name = "Telekinetic Grab: " + target.display_name
		grab.set_sprite(target.spr_sheet, target.spr_name)
		if not inv.put_in_hands(grab, inv.active):
			grab.destroy()
			return true
		d.tk_grab = grab
		Traits.add(target, "telekinesis_controlled", str(user.id))
		Fx.smoke_puff(target.cell)
	else:
		target.attack_hand(user)
	return true

static func validate(user: Entity) -> void:
	var d := Genetics.dna(user)
	if d and is_instance_valid(d.tk_grab) and not d.tk_grab.removed:
		d.tk_grab.c(&"tkgrab").valid()
