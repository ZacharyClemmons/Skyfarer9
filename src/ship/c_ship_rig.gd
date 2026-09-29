class_name CShipRig extends Component
## The shipwright's rig: a strap of tools and a bag of fixings that lets you change a hull
## while you are standing on it.
##
## Pick a mode with Z, then click where you want the work done. Deck goes onto open sky
## beside the ship, bulwark and bulkhead go onto deck, and the crowbar mode takes it all
## back off again. Everything you add belongs to the ship immediately: it moves with her,
## it counts toward her mass, and if you have enclosed a space it will start holding air.
##
## The rig is deliberately not a menu. The interesting decisions in a ship are where the
## engine room ends and whether the cabin is actually sealed, and you want to be looking at
## the deck while you make them.

## mode id, name, plan character, what it costs, and what it can be built on
const MODES := [
	{"id": "deck", "name": "weather deck", "ch": ",", "mat": "wood", "cost": 2,
		"desc": "Planking, open to the sky. The cheapest way to make a ship bigger."},
	{"id": "cabin", "name": "cabin deck", "ch": "=", "mat": "wood", "cost": 3,
		"desc": "Sealed flooring. Enclose it and it will hold air."},
	{"id": "bulwark", "name": "bulwark", "ch": "#", "mat": "wood", "cost": 3,
		"desc": "The ship's side. Stops you walking off; you can see over it."},
	{"id": "bulkhead", "name": "bulkhead", "ch": "I", "mat": "wood", "cost": 3,
		"desc": "Full-height interior wall. Blocks sight, and seals a cabin."},
	{"id": "window", "name": "window", "ch": "W", "mat": "glass", "cost": 2,
		"desc": "Glass in the hull. Seals like a bulkhead and you can see through it."},
	{"id": "door", "name": "cabin door", "ch": "+", "mat": "metal", "cost": 2,
		"desc": "A way between two sealed spaces that keeps them sealed."},
	{"id": "hatch", "name": "hull hatch", "ch": "A", "mat": "metal", "cost": 3,
		"desc": "An airlock through the hull, for going out on deck at altitude."},
	{"id": "remove", "name": "take apart", "ch": "", "mat": "", "cost": 0,
		"desc": "Prise a piece back off. You get most of the material back."},
]

var mode := 0

func key() -> StringName:
	return &"shiprig"

func current() -> Dictionary:
	return MODES[mode % MODES.size()]

func attack_self(user: Entity) -> bool:
	mode = (mode + 1) % MODES.size()
	var m := current()
	Game.tell(user, "[b]%s[/b] — %s%s" % [String(m["name"]).capitalize(), m["desc"],
		"" if m["cost"] == 0 else "  (%d %s)" % [m["cost"], m["mat"]]])
	Sfx.play("click", user.root_cell(), 0.5)
	return true

func examine(_user: Entity, lines: Array) -> void:
	var m := current()
	lines.append("Set to [b]%s[/b]. Z changes what it builds." % m["name"])
	lines.append("[i]Click a tile beside your ship to work on it.[/i]")

# ------------------------------------------------------------------ building
## Called by the interaction layer when the player clicks a tile with the rig in hand.
func use_on_cell(user: Entity, c: Vector2i) -> bool:
	var sh: Airship = Game.fleet.ship_of(user) if Game.fleet else null
	if sh == null:
		sh = Game.fleet.ship_at(c) if Game.fleet else null
	if sh == null:
		Game.tell(user, "You have to be working on a ship — stand aboard one.", "warn")
		return true
	if maxi(absi(c.x - user.root_cell().x), absi(c.y - user.root_cell().y)) > 1:
		Game.tell(user, "That is out of reach — stand next to where you want to work.", "warn")
		return true
	var local := sh.local_of(c)
	var m := current()
	if m["id"] == "remove":
		return _remove(user, sh, c, local)
	return _build(user, sh, c, local, m)

func _build(user: Entity, sh: Airship, c: Vector2i, local: Vector2i, m: Dictionary) -> bool:
	var existing: String = sh.cells_map.get(local, "")
	var ch: String = m["ch"]
	if existing == ch:
		Game.tell(user, "There is already %s there." % m["name"])
		return true
	# a new tile has to touch the ship somewhere, or you would be building in mid-air
	if existing == "" and not sh.touches(local):
		Game.tell(user, "Nothing to fix it to. Build out from the hull.", "warn")
		return true
	# building over open sky is fine; building over an island is not
	if existing == "" and not Defs.is_void_turf(Game.map.get_turf(c)):
		Game.tell(user, "The ground is in the way. You can only build out over open sky.", "warn")
		return true
	# walls need a clear tile: nothing standing where the timber goes
	if ShipPlan.is_dense(ch):
		for e in Game.at(c):
			if e.has_c(&"mob") or e.has_c(&"blocker"):
				Game.tell(user, "%s is in the way." % e.the().capitalize(), "warn")
				return true
	var cost := int(m["cost"])
	if not _take(user, String(m["mat"]), cost):
		Game.tell(user, "You need %d %s for that." % [cost, m["mat"]], "warn")
		return true
	var skill := Skills.level(user, "construction")
	DoAfter.start(user, null, maxf(0.6, 2.2 - skill * 0.012), func(ok: bool):
		if not ok:
			return
		sh.set_piece(local, ch)
		Skills.add_xp(user, "construction", 14.0)
		Sfx.play("ratchet", c, 0.7)
		Game.tell(user, "You fit %s." % m["name"])
		_report_seal(user, sh))
	return true

func _remove(user: Entity, sh: Airship, c: Vector2i, local: Vector2i) -> bool:
	var existing: String = sh.cells_map.get(local, "")
	if existing == "":
		Game.tell(user, "There is nothing of the ship there.", "warn")
		return true
	if sh.cells_map.size() <= 4:
		Game.tell(user, "Take any more off and there will be no ship left.", "warn")
		return true
	# do not strand a piece of deck by cutting the tile that joins it on
	if sh.would_sever(local):
		Game.tell(user, "Cut that and you would leave part of her hanging in the air.", "warn")
		return true
	DoAfter.start(user, null, 1.6, func(ok: bool):
		if not ok:
			return
		var mat := _material_of(existing)
		sh.set_piece(local, "")
		if mat != "":
			_give(user, mat, 1)
		Skills.add_xp(user, "construction", 8.0)
		Sfx.play("ratchet", c, 0.6)
		Game.tell(user, "You prise it off.")
		_report_seal(user, sh))
	return true

func _material_of(ch: String) -> String:
	if ch in ShipPlan.WINDOWS:
		return "glass"
	if ch in ["+", "A"]:
		return "metal"
	if ch in [",", ".", "=", "#", "K", "I"]:
		return "wood"
	return ""

## After every change, say whether her sealed spaces actually hold. This is the feedback
## that makes enclosing a cabin a solvable puzzle rather than a guess.
func _report_seal(user: Entity, sh: Airship) -> void:
	var leaks := ShipPlan.leaks_of(sh.cells_map)
	if leaks.is_empty():
		return
	Game.tell(user, "[color=#e8a83a]%d cabin tile%s still open to the weather.[/color]" % [
		leaks.size(), "" if leaks.size() == 1 else "s"], "warn")

# ------------------------------------------------------------------ materials
func _take(user: Entity, material: String, amount: int) -> bool:
	if amount <= 0:
		return true
	var found := _stacks(user, material)
	var total := 0
	for st in found:
		total += st.amount
	if total < amount:
		return false
	var left := amount
	for st in found:
		var n: int = mini(left, st.amount)
		st.amount -= n
		left -= n
		if st.amount <= 0:
			st.e.destroy()
		if left <= 0:
			break
	return true

func _give(user: Entity, material: String, amount: int) -> void:
	for st in _stacks(user, material):
		st.amount += amount
		return
	var proto := {"wood": "sheet_wood", "glass": "sheet_glass", "metal": "sheet_metal"}.get(material, "")
	if proto == "" or not Proto.has(proto):
		return
	var it := Proto.spawn(proto, user.root_cell())
	var stc: CStack = it.c(&"stack")
	if stc != null:
		stc.amount = amount

func _stacks(user: Entity, material: String) -> Array:
	var out := []
	var inv: CInventory = user.c(&"inv")
	if inv == null:
		return out
	for it in inv.all_items(true):
		var st: CStack = it.c(&"stack")
		if st != null and st.material == material:
			out.append(st)
	# also anything loose on the tile you are standing on, so a pile of planks on deck works
	for e in Game.at(user.root_cell()):
		var st2: CStack = e.c(&"stack")
		if st2 != null and st2.material == material and not st2 in out:
			out.append(st2)
	return out
