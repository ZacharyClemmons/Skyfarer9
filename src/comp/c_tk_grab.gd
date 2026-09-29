class_name CTkGrab extends Component
var user: Entity
var focus: Entity

func key() -> StringName:
	return &"tkgrab"

func valid() -> bool:
	var d := Genetics.dna(user)
	var inv: CInventory = user.c(&"inv") if is_instance_valid(user) else null
	if d == null or not d.has_mutation("telekinesis") or inv == null or not e in inv.hands or not is_instance_valid(focus) or focus.removed or focus.holder != null or focus.dist_to(user) > GeneInteraction.TK_RANGE or focus.tags.get("anchored", not focus.has_c(&"item")):
		e.destroy()
		return false
	return true

func attack_self(_user: Entity) -> bool:
	if valid():
		if not focus.attack_self(user):
			focus.attack_hand(user)
	return true

func use_on(_user: Entity, target: Entity, cell: Vector2i, throwing: bool) -> void:
	if not valid():
		return
	if target == focus:
		attack_self(user)
		return
	if throwing:
		var direction := Vector2(cell - focus.cell).normalized()
		var count := mini(10 if focus.has_c(&"item") else 1, maxi(absi(cell.x - focus.cell.x), absi(cell.y - focus.cell.y)))
		for step in range(1, count + 1):
			var next := focus.cell + Vector2i(roundi(direction.x), roundi(direction.y))
			if not Game.map.inb(next) or Game.map.blocks_move_static(next):
				break
			focus.place(next)
			for mob in Game.at_with(next, &"health"):
				if mob != user:
					var it: CItem = focus.c(&"item")
					if it and it.throwforce > 0:
						mob.take_damage(it.throwforce, it.damtype, user)
					return
		valid()
	elif target and focus.has_c(&"item"):
		if focus.adjacent(target):
			Interact.use_item_on(user, focus, target)
		elif focus.has_c(&"gadget") and focus.c(&"gadget").ranged():
			focus.c(&"gadget").fire(user, cell)

func on_removed() -> void:
	if is_instance_valid(focus) and is_instance_valid(user):
		Traits.remove(focus, "telekinesis_controlled", str(user.id))
	var d := Genetics.dna(user)
	if d and d.tk_grab == e:
		d.tk_grab = null

func examine(_user: Entity, lines: Array) -> void:
	if is_instance_valid(focus):
		lines.append("Controls %s at range. Z activates it; throw mode throws it. Dropping releases the focus." % focus.display_name)
