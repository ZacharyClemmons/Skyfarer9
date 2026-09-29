class_name CRamp extends Component
## The boarding-ramp hull piece. Shut, it is a sealed plate in the ship's side. Use it and
## it swings open and a ramp runs out to the quay; use it again to haul the ramp in.

var open := false

func key() -> StringName:
	return &"ramp"

func on_added() -> void:
	_show()

func _ship() -> Airship:
	return Game.fleet.ship_at(e.cell) if Game.fleet != null else null

func examine(_user: Entity, lines: Array) -> void:
	lines.append("A boarding ramp. Use it beside a quay or a shore to run a ramp out." if not open else "The ramp is out. Use it again to haul it in.")

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Haul the ramp in" if open else "Run the ramp out", "priority": 30, "cb": func(): toggle(user)})

func attack_hand(user: Entity) -> bool:
	toggle(user)
	return true

func toggle(user: Entity) -> void:
	var sh := _ship()
	if sh == null:
		return
	if open:
		var why := Gangway.retract(sh)
		if why != "":
			Game.tell(user, why, "warn")
			return
		open = false
		(e.c(&"blocker") as CBlocker).set_state(true, true, true)
		Game.tell(user, "You haul the ramp in and dog the plate shut.", "info")
	else:
		var why2 := Gangway.deploy(e, sh)
		if why2 != "":
			Game.tell(user, why2, "warn")
			return
		open = true
		(e.c(&"blocker") as CBlocker).set_state(false, false, false)
		Game.tell(user, "The plate swings down into a ramp. Walk across — and haul it in before you cast off.", "good")
	_show()

func _show() -> void:
	e.set_sprite("objects", "airlock_cargo_%d" % (3 if open else 0))
