class_name DoAfter extends RefCounted
## Timed actions (tg: do_after). Cancelled if the user moves, is incapacitated, the
## target moves, or the active hand changes (including picking up or equipping an item).
## Reference: tgstation code/datums/timed_actions.dm, default held-item/location checks.
## The callback receives true on success, false on interruption.

static var active: Array = []

static func start(user: Entity, target: Entity, duration: float, cb: Callable, require_hands := true) -> void:
	for a in active:
		if a["user"] == user:
			Game.tell(user, "You are already busy.", "warn")
			return
	var inv = user.c(&"inv")
	var held: Entity = inv.active_item() if inv else null
	# tg wound actionspeed modifier: a hurt arm on the active hand slows everything down
	duration *= Body.action_mult(user)
	active.append({"user": user, "target": target, "t": 0.0, "dur": maxf(0.1, duration), "cb": cb,
		"ucell": user.cell, "tcell": target.root_cell() if target else Vector2i.ZERO, "held": held,
		"hand": inv.active if inv else -1, "require_hands": require_hands})

static func busy(user: Entity) -> bool:
	for a in active:
		if a["user"] == user:
			return true
	return false

static func progress(user: Entity) -> float:
	for a in active:
		if a["user"] == user:
			return a["t"] / a["dur"]
	return -1.0

static func cancel(user: Entity) -> void:
	for a in active.duplicate():
		if a["user"] == user:
			active.erase(a)
			a["cb"].call(false)

static func process(delta: float) -> void:
	for a in active.duplicate():
		# An earlier callback may cancel another action in this snapshot.
		if not a in active:
			continue
		var u: Entity = a["user"]
		var t: Entity = a["target"]
		var ok = is_instance_valid(u) and not u.removed and u.cell == a["ucell"]
		if ok:
			var h = u.c(&"health")
			if h and (not h.can_use_hands() if a.get("require_hands", true) else h.incapacitated()):
				ok = false
		var held = a.get("held")
		if ok:
			var inv: CInventory = u.c(&"inv")
			if inv and (inv.active != a["hand"] or inv.active_item() != held):
				ok = false
		if ok and held != null and (not is_instance_valid(held) or held.removed or held.holder != u):
			ok = false
		if ok and t != null:
			if not is_instance_valid(t) or t.removed:
				ok = false
			elif t.root_cell() != a["tcell"]:
				ok = false
			elif not u.adjacent(t):
				ok = false
		if not ok:
			active.erase(a)
			a["cb"].call(false)
			continue
		a["t"] += delta
		if a["t"] >= a["dur"]:
			active.erase(a)
			a["cb"].call(true)
