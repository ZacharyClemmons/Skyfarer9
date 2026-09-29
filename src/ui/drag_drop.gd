class_name DragDrop extends RefCounted
## What happens when the player drags an item somewhere (SS13's MouseDrop, done the way
## Burgerstation does it: a ghost of the item follows the cursor, green where it can go
## and red where it can't). Every move goes through the same inventory/storage calls
## the rest of the game uses. With dry = true nothing changes; it only answers "can it?".
##
## Destinations:
##   {"kind": "hand", "idx": 0|1}
##   {"kind": "equip", "slot": "belt"}
##   {"kind": "store", "container": Entity}          a bag's storage window
##   {"kind": "hotbar", "idx": 0..5}                   bind a carried item to a hotkey
##   {"kind": "world", "cell": Vector2i, "ents": []}  the floor, a bag on it, a person

static func apply(p: Entity, item: Entity, dst: Dictionary, dry: bool) -> bool:
	if Game.paused or not is_instance_valid(p) or not is_instance_valid(item) or item.removed:
		return false
	var inv: CInventory = p.c(&"inv")
	var h: CHealth = p.c(&"health")
	if inv == null or (h and not h.can_use_hands()) or not reachable(p, item):
		return false
	if item.has_c(&"mob"):
		return _drop_mob(p, item, dst, dry)
	if item.get_meta("nodrop", false) and item.holder == p and dst.get("kind", "") not in ["hotbar", "craft"]:
		return false
	match dst.get("kind", ""):
		"craft":
			if not reachable(p, item):
				return false
			if not dry:
				var g: Array = Game.hud.craft_grid
				for i in g.size():
					if g[i] == item:
						g[i] = null
				g[dst["idx"]] = item
				Sfx.play_ui("ui_tick", 0.5)
			return true
		"hotbar":
			if not carried(p, item):
				return false
			if not dry:
				var hb: Array = p.c(&"mob").hotbar
				for i in hb.size():
					if hb[i] == item:
						hb[i] = null
				hb[dst["idx"]] = item
				Sfx.play_ui("ui_tick", 0.5)
			return true
		"hand":
			var idx: int = dst["idx"]
			if not inv.hand_usable(idx):
				return false
			var there: Entity = inv.hands[idx]
			if there == item:
				return false
			if there == null:
				if not inv.can_hold(item) or not inv.hand_available(idx):
					return false
				return true if dry else _to_hand(p, item, idx)
			if _is_bag(there) and there.c(&"storage").can_insert(item):
				return true if dry else _insert(p, item, there)
			if item in inv.hands:
				if not inv.hand_usable(1 - idx) or there.get_meta("nodrop", false):
					return false
				if not dry:
					inv.hands[idx] = item
					inv.hands[1 - idx] = there
					inv._refresh()
				return true
			return false
		"equip":
			var slot: String = dst["slot"]
			var worn: Entity = inv.worn(slot)
			if worn == item:
				return false
			if worn == null:
				if not inv.can_equip(item, slot):
					return false
				if not dry:
					inv.equip(item, slot)
					Sfx.play("pickup", p.cell, 0.5)
				return true
			if _is_bag(worn) and worn.c(&"storage").can_insert(item):
				return true if dry else _insert(p, item, worn)
			return false
		"store":
			var cont: Entity = dst["container"]
			if cont == item or item.holder == cont or not is_instance_valid(cont) or not reachable(p, cont):
				return false
			if not cont.c(&"storage").can_insert(item):
				return false
			return true if dry else _insert(p, item, cont)
		"world":
			var cell: Vector2i = dst["cell"]
			if not Entity.cells_adjacent(p.cell, cell) or not Game.map.inb(cell) or Game.map.blocks_move_static(cell):
				return false
			var ents: Array = dst.get("ents", [])
			for e in ents:
				if e != item and e.holder == null and _is_bag(e) and e.c(&"storage").can_insert(item):
					return true if dry else _insert(p, item, e)
			for e in ents:
				if e != p and e.has_c(&"inv") and e.has_c(&"health") and e.c(&"health").can_use_hands() and e.c(&"inv").can_hold(item) and e.c(&"inv").free_hand() >= 0:
					return true if dry else _give(p, item, e)
			if item.holder == null:
				return false # already on the floor; pull it instead
			if not _surface_free(cell):
				return false
			if not dry:
				_to_floor(p, item, cell)
			return true
	return false

## tg MouseDrop of a person: onto a chair / bed / operating table buckles them (yourself
## or whoever you're pulling), onto a table lays them on it.
static func _drop_mob(p: Entity, m: Entity, dst: Dictionary, dry: bool) -> bool:
	if m.has_meta("inside"):
		return false
	if dst.get("kind", "") != "world":
		return false
	if m != p and p.c(&"mob").pulling != m:
		return false
	var ents: Array = dst.get("ents", [])
	for e in ents:
		if e.has_c(&"storage") and e.c(&"storage").can_put_in(p, m):
			return true if dry else e.c(&"storage").put_in(p, m)
		if e.has_c(&"dnascanner") and e.c(&"dnascanner").can_put_in(p, m):
			return true if dry else e.c(&"dnascanner").put_in(p, m)
		if e.has_c(&"skillstation") and e.c(&"skillstation").can_put_in(p, m):
			return true if dry else e.c(&"skillstation").put_in(p, m)
		if Buckle.can_buckle(p, m, e):
			return true if dry else Buckle.buckle(p, m, e)
	if m != p:
		for e in ents:
			if e.has_c(&"furniture") and e.c(&"furniture").kind in ["table", "counter"] and p.adjacent(e):
				return true if dry else Buckle.onto_table(p, m, e)
	return false

## Held, worn, or inside something that is (any depth).
static func carried(p: Entity, e: Entity) -> bool:
	var h: Entity = e.holder
	var guard := 0
	while h != null and guard < 8:
		if h == p:
			return true
		h = h.holder
		guard += 1
	return false

## Worn, held, in something the player carries, or within arm's reach.
static func reachable(p: Entity, e: Entity) -> bool:
	if not is_instance_valid(e) or e.removed or e.has_meta("inside"):
		return false
	if e.root() == p:
		return true
	return Entity.cells_adjacent(p.cell, e.root_cell())

static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

static func _is_bag(e: Entity) -> bool:
	return e.has_c(&"storage") and e.c(&"storage").kind == "bag"

## Open floor, or a table (anything dense there has to be a table).
static func _surface_free(cell: Vector2i) -> bool:
	if Game.map.dense_count[Game.map.idx(cell)] == 0:
		return true
	for e in Game.at(cell):
		if e.has_c(&"blocker") and e.c(&"blocker").dense and e.c(&"blocker").active:
			if not (e.has_c(&"furniture") and e.c(&"furniture").kind == "table"):
				return false
	return true

static func _to_hand(p: Entity, item: Entity, idx: int) -> bool:
	var inv: CInventory = p.c(&"inv")
	var from_floor := item.holder == null
	var area := Game.map.area_at(item.cell)
	if not inv.put_in_hands(item, idx):
		return false
	Sfx.play("pickup", p.cell)
	if from_floor:
		Interact._theft_check(p, item, area)
	return true

static func _insert(p: Entity, item: Entity, cont: Entity) -> bool:
	var from_floor := item.holder == null
	var area := Game.map.area_at(item.cell)
	if not cont.c(&"storage").insert(item):
		return false
	Sfx.play("pickup", p.cell, 0.4)
	if from_floor:
		Interact._theft_check(p, item, area)
	p.c(&"inv")._refresh()
	return true

static func _to_floor(p: Entity, item: Entity, cell: Vector2i) -> void:
	Interact.detach(item)
	item.holder = null
	item.visible = true
	Game.drop_to_map(item, cell)
	item.place(cell)
	p.c(&"inv")._refresh()
	Sfx.play("drop", cell)

static func _give(p: Entity, item: Entity, to: Entity) -> bool:
	if not to.c(&"health").can_use_hands() or not to.c(&"inv").can_hold(item):
		return false
	if not to.c(&"inv").put_in_hands(item):
		return false
	p.c(&"inv")._refresh()
	Game.tell(p, "You hand %s to %s." % [item.the(), to.display_name])
	Bus.stimulus.emit({"type": "gift", "actor": p, "target": to, "cell": p.cell, "loud": 0.0, "illegal": false, "text": item.display_name})
	return true
