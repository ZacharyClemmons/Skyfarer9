class_name CBreachPatch extends Component
## A hole in the hull, and the way to close it: nail a plank across it. The tile goes back
## to being whatever it was before it was stove in.

func key() -> StringName:
	return &"breach_patch"

func examine(_user: Entity, lines: Array) -> void:
	lines.append("Planks would patch it.")

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Patch the hole (uses a plank)", "priority": 27, "cb": func(): patch(user)})

func attackby(user: Entity, item: Entity) -> bool:
	if item != null and item.proto == "sheet_wood":
		patch(user, item)
		return true
	return false

func attack_hand(user: Entity) -> bool:
	patch(user)
	return true

func patch(user: Entity, plank: Entity = null) -> void:
	if plank == null:
		var inv: CInventory = user.c(&"inv") if user != null else null
		if inv != null:
			plank = inv.find_item(func(it): return it.proto == "sheet_wood")
	if plank == null:
		Game.tell(user, "You need wooden planks to patch this.", "warn")
		return
	plank.destroy()
	var map := Game.map
	var c: Vector2i = e.cell
	map.set_turf(c, int(e.tags.get("was_turf", Defs.T_HULLWOOD)))
	map.set_structure(c, int(e.tags.get("was_struct", Defs.S_NONE)))
	map.turf_hp[map.idx(c)] = float(Defs.TURFS[map.turf[map.idx(c)]].get("hp", 100))
	var sh: Airship = Game.fleet.ship_at(c) if Game.fleet != null else null
	if sh != null:
		sh.seam = maxf(0.0, sh.seam - 0.05)
	Sfx.play("wall_hit", c, 0.5)
	Game.tell(user, "You nail a plank across the hole. The wind stops whistling through.", "good")
	e.destroy()
