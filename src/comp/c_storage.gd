class_name CStorage extends Component
## Containers. Two flavours, as in SS13:
##  - "closet": lockers/crates. Closed = contents hidden inside; opening spills them onto
##    the tile, closing gathers loose items on the tile back in.
##  - "bag": backpacks/boxes/belts: an item with a browsable inventory window.

var kind := "closet"
var contents: Array = []
var capacity := 20 # object count for closets; total w_class for bags
var max_w := 3 # tg max_specific_storage (largest weight class it takes)
var max_slots := 0 # tg max_slots (0 = no limit on how many)
var holds: Array = [] # tg can_hold whitelist: item categories, tool kinds or protos (empty = anything)
var is_open := false
var req_access: Array = []
var locked := false
var secure := false
var broken_lock := false
var spr_closed := ""
var spr_open := ""
var occupants: Array = []
var mob_capacity := 3
var horizontal := false
var breakout_time := 120.0
var _message_ready := 0.0

func key() -> StringName:
	return &"storage"

func setup(p: Dictionary) -> CStorage:
	kind = p.get("kind", kind)
	capacity = p.get("capacity", capacity)
	max_w = p.get("max_w", max_w)
	max_slots = p.get("slots", max_slots)
	holds = p.get("holds", holds).duplicate()
	req_access = p.get("access", req_access).duplicate()
	locked = not req_access.is_empty()
	secure = bool(p.get("secure", locked))
	locked = bool(p.get("locked", locked))
	spr_closed = p.get("spr", "")
	spr_open = p.get("spr_open", "")
	mob_capacity = int(p.get("mob_capacity", mob_capacity))
	horizontal = bool(p.get("horizontal", horizontal))
	return self

func used() -> int:
	# drop anything destroyed without being taken out properly
	for k in range(contents.size() - 1, -1, -1):
		if not is_instance_valid(contents[k]) or contents[k].removed:
			contents.remove_at(k)
	var n := 0
	for it in contents:
		if it.has_c(&"item"):
			n += 1 if kind == "closet" else it.c(&"item").w_class
	return n

func can_insert(item: Entity) -> bool:
	if not is_instance_valid(item) or item.removed or item == e or item.holder == e or item.tags.get("abstract_hand", false):
		return false
	# Never place an ancestor inside its own contents (a holder cycle).
	var ancestor: Entity = e.holder
	while ancestor != null:
		if ancestor == item:
			return false
		ancestor = ancestor.holder
	var weight := used() # prune destroyed entries before checking the slot limit
	var it: CItem = item.c(&"item")
	if it == null:
		return false
	if kind == "closet" and (item.get_meta("nodrop", false) or item.tags.get("anchored", false) or (item.has_c(&"storage") and item.c(&"storage").kind == "closet")):
		return false
	if kind == "bag" and (it.w_class > max_w or item.has_c(&"storage")):
		return false
	if max_slots > 0 and contents.size() >= max_slots:
		return false
	if not holds.is_empty() and not (item.proto in holds or it.category in holds or (it.tool != "" and it.tool in holds)):
		return false
	return weight + (1 + occupants.size() if kind == "closet" else it.w_class) <= capacity

## Why can_insert said no, in tg's words.
func refusal(item: Entity) -> String:
	used()
	var it: CItem = item.c(&"item")
	if it == null:
		return "That doesn't fit."
	if not holds.is_empty() and not (item.proto in holds or it.category in holds or (it.tool != "" and it.tool in holds)):
		return "%s can't hold %s." % [e.display_name.capitalize(), item.the()]
	if kind == "bag" and it.w_class > max_w:
		return "%s is too big for %s." % [item.the().capitalize(), e.the()]
	if kind == "bag" and item.has_c(&"storage"):
		return "%s can't hold another container." % e.the().capitalize()
	if max_slots > 0 and contents.size() >= max_slots:
		return "%s has no room for any more items." % e.the().capitalize()
	return "%s is too full." % e.the().capitalize()

func insert(item: Entity) -> bool:
	if not can_insert(item):
		return false
	Interact.detach(item)
	item.holder = e
	item.visible = false
	contents.append(item)
	return true

func remove(item: Entity) -> void:
	contents.erase(item)
	if item in occupants:
		occupants.erase(item)
		item.remove_meta("inside")

func has_access(user: Entity) -> bool:
	if req_access.is_empty():
		return true
	var inv = user.c(&"inv")
	if inv == null:
		return false
	for t in req_access:
		if inv.has_access(t):
			return true
	return false

func open(user: Entity = null, force := false) -> bool:
	if kind != "closet" or is_open:
		return false
	if locked and not force:
		if user: Game.tell(user, "It's locked.", "warn")
		return false
	if e.tags.get("welded", false) and not force:
		if user:
			Game.tell(user, "It's welded shut!", "warn")
		return false
	if not force:
		for other in Game.at(e.cell):
			if other.has_c(&"mob") and (other.tags.get("anchored", false) or (horizontal and not other.c(&"mob").is_lying())):
				if user: Game.tell(user, "Someone is blocking the lid.", "warn")
				return false
	locked = false
	e.tags["welded"] = false
	is_open = true
	for it in contents.duplicate():
		if not is_instance_valid(it) or it.removed:
			contents.erase(it)
			continue
		contents.erase(it)
		it.holder = null
		it.visible = true
		Game.drop_to_map(it, e.cell)
		it.place(e.cell)
	_release_occupants()
	_refresh()
	Sfx.play("locker", e.cell)
	return true

func close(user: Entity = null) -> bool:
	if kind != "closet" or not is_open:
		return false
	for other in Game.at(e.cell):
		if other != e and other.has_c(&"storage") and other.c(&"storage").kind == "closet":
			if user: Game.tell(user, "%s is in the way." % other.the().capitalize(), "warn")
			return false
		if other.has_c(&"mob") and (other.tags.get("anchored", false) or (horizontal and not other.c(&"mob").is_lying())):
			if user: Game.tell(user, "Someone is blocking the lid.", "warn")
			return false
	for it in Game.at(e.cell).duplicate():
		if it != e and it.has_c(&"item") and can_insert(it):
			insert(it)
		elif it.has_c(&"mob") and occupants.size() < mob_capacity and used() + occupants.size() < capacity and not it.has_meta("inside") and not Traits.has(it, "giant") and it.c(&"mob").buckled == null:
			_enclose(it)
	is_open = false
	_refresh()
	Sfx.play("locker", e.cell)
	return true

func _enclose(who: Entity) -> void:
	var mob: CMob = who.c(&"mob")
	mob.stop_pulling()
	if is_instance_valid(mob.pulled_by):
		mob.pulled_by.c(&"mob").stop_pulling()
	mob.moving = false
	Game.lift_from_map(who)
	who.holder = e
	who.set_meta("inside", e.id)
	who.visible = false
	who.place(e.cell)
	occupants.append(who)
	mob.refresh_doll()

func _release_occupants() -> void:
	for who in occupants.duplicate():
		occupants.erase(who)
		if not is_instance_valid(who) or who.removed:
			continue
		DoAfter.cancel(who)
		who.remove_meta("inside")
		who.holder = null
		who.visible = true
		Game.drop_to_map(who, e.root_cell())
		who.place(e.root_cell())
		who.c(&"mob").refresh_doll()

func relaymove(user: Entity) -> void:
	if not user in occupants or user.c(&"health").stat() != CHealth.CONSCIOUS:
		return
	if locked:
		if Game.time >= _message_ready:
			_message_ready = Game.time + 5.0
			Game.tell(user, "The locker's door won't budge! Resist (B) to break out.", "warn")
		return
	container_resist(user)

func container_resist(user: Entity) -> void:
	if is_open or not user in occupants or user.c(&"health").stat() != CHealth.CONSCIOUS or DoAfter.busy(user):
		return
	if not locked and not e.tags.get("welded", false):
		open(user)
		return
	Game.tell(user, "You start pushing the locker open. This takes two minutes.", "warn")
	DoAfter.start(user, e, breakout_time, func(ok):
		if not ok or not is_instance_valid(e) or e.removed or is_open or not is_instance_valid(user) or not user in occupants:
			return
		Game.visible_message(e.cell, "%s breaks out of %s!" % [user.display_name, e.the()], "warn")
		bust_open(), false)

func bust_open() -> void:
	broken_lock = true
	open(null, true)

func toggle_lock(user: Entity) -> bool:
	if kind != "closet" or not secure or broken_lock or is_open or user in occupants or not user.adjacent(e) or not user.c(&"health").can_use_hands():
		return false
	if locked and not has_access(user):
		Game.tell(user, "Access denied.", "bad")
		return false
	locked = not locked
	Forensics.touch(e, user)
	Sfx.play("click", e.cell)
	Game.tell(user, "You %s %s." % ["lock" if locked else "unlock", e.the()])
	_refresh()
	return true

func wrench_secondary(user: Entity, item: Entity) -> bool:
	if kind != "closet" or not item.has_c(&"item") or item.c(&"item").tool != "wrench" or not user.adjacent(e) or user in occupants or not user.c(&"health").can_use_hands():
		return false
	e.tags["anchored"] = not e.tags.get("anchored", false)
	Forensics.touch(e, user)
	Sfx.play("ratchet", e.cell)
	Game.tell(user, "You %s %s." % ["bolt down" if e.tags["anchored"] else "unbolt", e.the()])
	return true

func on_moved(_old: Vector2i, cell: Vector2i) -> void:
	for item in contents:
		if is_instance_valid(item) and not item.removed:
			item.place(cell)
	for who in occupants:
		if is_instance_valid(who) and not who.removed:
			who.place(cell)

func on_removed() -> void:
	_release_occupants()

func can_put_in(user: Entity, target: Entity) -> bool:
	return kind == "closet" and is_open and mob_capacity > 0 and is_instance_valid(target) and not target.removed and target != user and target.has_c(&"mob") and not target.has_meta("inside") and target.holder == null and not target.tags.get("anchored", false) and not Traits.has(target, "giant") and target.c(&"mob").buckled == null and user.adjacent(e) and user.adjacent(target) and user.c(&"health").can_use_hands() and not DoAfter.busy(user)

func put_in(user: Entity, target: Entity) -> bool:
	if not can_put_in(user, target):
		return false
	Game.tell(user, "You start stuffing %s into %s." % [target.the(), e.the()])
	DoAfter.start(user, target, 4.0, func(ok):
		if not ok or not is_instance_valid(e) or e.removed or not can_put_in(user, target):
			return
		target.c(&"health").paralyze(4.0)
		target.place(e.cell)
		close(user))
	return true

func _refresh() -> void:
	if spr_closed != "":
		e.set_sprite("objects", spr_open if is_open else spr_closed)
	var b = e.c(&"blocker")
	if b and kind == "closet":
		b.set_state(not is_open, false, false)

func attack_hand(user: Entity) -> bool:
	if kind == "closet":
		if is_open:
			close(user)
		else:
			if not open(user) and locked and secure:
				toggle_lock(user)
		return true
	return false

func attackby(user: Entity, item: Entity) -> bool:
	if item.has_c(&"idcard") and kind == "closet" and secure and not is_open:
		toggle_lock(user)
		return true
	if kind == "bag" and item != e:
		var inv = user.c(&"inv")
		if insert(item):
			if inv:
				inv._refresh()
			Game.tell(user, "You put %s into %s." % [item.the(), e.the()])
			return true
		if item.has_c(&"item"):
			# tg: a bag says why it won't take something (and you don't hit it)
			Game.tell(user, refusal(item), "warn")
			return true
	return false

func verbs(user: Entity, out: Array) -> void:
	if kind == "closet" and user.adjacent(e):
		out.append({"name": "Close" if is_open else "Open", "cb": attack_hand.bind(user), "priority": 6})
		if secure and not broken_lock and not is_open:
			out.append({"name": "Unlock" if locked else "Lock", "cb": toggle_lock.bind(user), "priority": 5})
	if kind == "bag":
		out.append({"name": "Look inside", "cb": func(): Bus.ui_open_window.emit("storage", e), "priority": 6})

func examine(_user: Entity, lines: Array) -> void:
	if kind == "closet":
		lines.append("It is %s%s." % ["open" if is_open else "closed", " and locked" if locked and not is_open else ""])
		if e.tags.get("welded", false): lines.append("It is welded shut.")
		if secure and broken_lock: lines.append("Its lock is broken; it cannot be locked again.")
		lines.append("It is %s to the floor." % ("bolted" if e.tags.get("anchored", false) else "not bolted"))
	else:
		lines.append("It holds %d item(s)." % contents.size())

func ai_tags(out: Dictionary) -> void:
	out["container"] = true
