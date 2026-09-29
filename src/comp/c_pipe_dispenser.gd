class_name CPipeDispenser extends Component
## tg /obj/machinery/pipedispenser: hands out pipe fittings and takes spare ones back.

func key() -> StringName:
	return &"pipedispenser"

func dispense(user: Entity, layer: int) -> void:
	var m: CMachine = e.c(&"machine")
	if m and not m.operable():
		Game.tell(user, "%s is unpowered." % e.the().capitalize(), "warn")
		return
	if not user.adjacent(e):
		return
	var f := Proto.spawn("pipe_fitting", e.cell, {"comps": {"pipefitting": {"layer": layer}}})
	var inv: CInventory = user.c(&"inv")
	if inv == null or not inv.put_in_hands(f):
		f.place(user.cell)
	Sfx.play("vend", e.cell, 0.5)
	Game.tell(user, "%s dispenses a %s." % [e.the().capitalize(), f.display_name])

func attack_hand(user: Entity) -> bool:
	if Game.hud and user == Game.player:
		Game.hud.show_context_for([e])
	else:
		dispense(user, StationMap.PL_SUPPLY)
	return true

func attackby(user: Entity, item: Entity) -> bool:
	if item.has_c(&"pipefitting"):
		# tg: pipes dropped into the dispenser are recycled
		Game.tell(user, "You put %s back into %s." % [item.the(), e.the()])
		item.destroy()
		if user == Game.player and Game.hud:
			Game.hud.refresh_inventory()
		return true
	return false

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Take a supply pipe", "cb": dispense.bind(user, StationMap.PL_SUPPLY), "priority": 8})
	out.append({"name": "Take a scrubber pipe", "cb": dispense.bind(user, StationMap.PL_SCRUB), "priority": 7})

func examine(_user: Entity, lines: Array) -> void:
	lines.append("It makes pipe fittings. Put spare ones back in to recycle them.")
