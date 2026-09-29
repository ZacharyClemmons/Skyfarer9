class_name Crafting extends RefCounted
## Burgerstation's crafting grid: put the parts in the 3x3 grid (drag them in from your
## hands, bags or the floor next to you) and, when they make something, press Craft.
## Recipes are shapeless: only what's in the grid counts, not where. Stacks (cable,
## metal) give up just what the recipe needs. Your skill in the recipe's field makes it
## faster and earns XP.

## id -> {name, desc, needs: {proto: count}, out, skill, time}
const RECIPES := {
	"shiv": {"name": "Glass shiv", "desc": "A shard of glass with a cable grip. Sharp, quick, nasty.",
		"needs": {"glass_shard": 1, "cable_coil": 2}, "out": "shiv", "skill": "melee", "time": 2.0},
	"spear": {"name": "Spear", "desc": "A glass point lashed to a metal rod. Hits hard with both hands.",
		"needs": {"glass_shard": 1, "cable_coil": 4, "sheet_metal": 2}, "out": "spear", "skill": "construction", "time": 4.0},
	"molotov": {"name": "Molotov cocktail", "desc": "Spirits and a paper rag. Light it with a blowtorch and throw.",
		"needs": {"drink_booze": 1, "paper": 1}, "out": "molotov", "skill": "throwing", "time": 2.0},
	"cable_cuffs": {"name": "Cable restraints", "desc": "Cable coil twisted into cuffs. Easier to slip than the real thing.",
		"needs": {"cable_coil": 15}, "out": "cable_cuffs", "skill": "construction", "time": 3.0},
	"burger": {"name": "Burger", "desc": "Meat in a bun.", "needs": {"food_meat": 1, "food_flour": 1}, "out": "food_burger", "skill": "cooking", "time": 3.0},
	"sandwich": {"name": "Sandwich", "desc": "Bread and whatever's to hand.", "needs": {"food_flour": 1, "food_tomato": 1}, "out": "food_sandwich", "skill": "cooking", "time": 2.0},
	"pizza": {"name": "Flatbread", "desc": "Dough, tomato, meat. The crew's favourite.",
		"needs": {"food_flour": 1, "food_tomato": 2, "food_meat": 1}, "out": "food_pizza", "skill": "cooking", "time": 5.0},
	# tg metal sheet recipes (GLOB.metal_recipes)
	"floor_tiles": {"name": "Deck tiles (x4)", "desc": "One metal sheet makes four deck tiles.", "needs": {"sheet_metal": 1}, "out": "floor_tile", "amount": 4, "skill": "construction", "time": 1.0},
	"rods": {"name": "Metal rods (x2)", "desc": "One metal sheet makes two rods.", "needs": {"sheet_metal": 1}, "out": "rods", "amount": 2, "skill": "construction", "time": 1.0},
	"machine_frame": {"name": "Machine frame", "desc": "Build a machine on it: wrench, 5 cable, a circuit board, screwdriver.", "needs": {"sheet_metal": 5}, "out": "machine_frame", "skill": "construction", "time": 3.0},
	"computer_frame": {"name": "Computer frame", "desc": "Build a computer on it: wrench, 5 cable, a circuit board, screwdriver.", "needs": {"sheet_metal": 5, "sheet_glass": 1}, "out": "computer_frame", "skill": "construction", "time": 3.0},
	"chair": {"name": "Chair", "desc": "A metal chair.", "needs": {"sheet_metal": 1, "rods": 1}, "out": "chair", "skill": "construction", "time": 2.0},
	"stool": {"name": "Bar stool", "desc": "A stool.", "needs": {"sheet_metal": 1, "cable_coil": 1}, "out": "bar_stool", "skill": "construction", "time": 2.0},
	"bed": {"name": "Bed", "desc": "A metal bed.", "needs": {"sheet_metal": 2, "rods": 1}, "out": "bed", "skill": "construction", "time": 3.0},
	"table": {"name": "Table", "desc": "A metal table.", "needs": {"sheet_metal": 1, "rods": 2}, "out": "table", "skill": "construction", "time": 3.0},
	"locker": {"name": "Closet", "desc": "A metal closet.", "needs": {"sheet_metal": 2, "rods": 2}, "out": "locker", "skill": "construction", "time": 4.0},
	"crate": {"name": "Crate", "desc": "A sturdy crate.", "needs": {"sheet_metal": 3}, "out": "crate", "skill": "construction", "time": 3.0},
	"wood_table": {"name": "Wooden table", "desc": "A wooden table.", "needs": {"sheet_wood": 2}, "out": "table", "skill": "construction", "time": 3.0, "ov": {"spr": "table_wood"}},
}

## How many of `proto` an item counts as (a stack counts its amount).
static func count_of(e: Entity) -> int:
	var st = e.c(&"stack")
	return st.amount if st else 1

## What's in the grid, as {proto: count}.
static func tally(grid: Array) -> Dictionary:
	var t := {}
	for e in grid:
		if e != null and is_instance_valid(e) and not e.removed:
			t[e.proto] = t.get(e.proto, 0) + count_of(e)
	return t

## The recipe the grid makes, or "". Everything in the grid must be used by it.
## The recipe last picked from the list: several recipes can share parts (a metal sheet
## makes tiles, rods, frames...), so the one you asked for wins.
static var picked := ""

static func _fits(id: String, t: Dictionary) -> bool:
	var needs: Dictionary = RECIPES[id]["needs"]
	for k in t:
		if not needs.has(k):
			return false
	for k in needs:
		if t.get(k, 0) < needs[k]:
			return false
	return true

static func match_grid(grid: Array) -> String:
	var t := tally(grid)
	if t.is_empty():
		return ""
	if picked != "" and RECIPES.has(picked) and _fits(picked, t):
		return picked
	for id in RECIPES:
		var needs: Dictionary = RECIPES[id]["needs"]
		var ok := true
		for k in t:
			if not needs.has(k):
				ok = false
		for k in needs:
			if t.get(k, 0) < needs[k]:
				ok = false
		if ok:
			return id
	return ""

## Can `p` make recipe `id` from what they carry or what's within reach? Returns the
## items to use, or [] if something's missing.
static func gather(p: Entity, id: String) -> Array:
	var needs: Dictionary = RECIPES[id]["needs"].duplicate()
	var pool := []
	var inv: CInventory = p.c(&"inv")
	for h in inv.hands:
		if h:
			pool.append(h)
	for it in inv.all_items():
		if not it in pool:
			pool.append(it)
	for c in [p.cell] + _around(p.cell):
		for e in Game.at(c):
			if e.holder == null and e.has_c(&"item") and not e in pool:
				pool.append(e)
	var out := []
	for e in pool:
		if needs.get(e.proto, 0) > 0:
			out.append(e)
			needs[e.proto] -= count_of(e)
	for k in needs:
		if needs[k] > 0:
			return []
	return out

static func _around(c: Vector2i) -> Array:
	var out := []
	for d in Defs.DIRS8:
		out.append(c + d)
	return out

## Make it: after a do-after, use up the parts and put the result in a free hand (or at
## your feet).
static func craft(p: Entity, grid: Array, done: Callable = Callable()) -> void:
	var id := match_grid(grid)
	if id == "":
		Game.tell(p, "That doesn't make anything.", "warn")
		return
	var r: Dictionary = RECIPES[id]
	var t: float = r["time"] / (1.0 + Skills.level(p, r["skill"]) * 0.02)
	Game.visible_message(p.cell, "%s starts making %s." % [p.display_name, r["name"].to_lower()])
	DoAfter.start(p, null, t, func(ok):
		if not ok:
			return
		if match_grid(grid) != id:
			Game.tell(p, "Something's missing.", "warn")
			return
		var needs: Dictionary = r["needs"].duplicate()
		for e in grid:
			if e == null or not is_instance_valid(e) or e.removed or needs.get(e.proto, 0) <= 0:
				continue
			var st = e.c(&"stack")
			if st:
				var n := mini(st.amount, needs[e.proto])
				needs[e.proto] -= n
				st.use(n)
			else:
				needs[e.proto] -= 1
				e.destroy()
		var ov: Dictionary = r.get("ov", {}).duplicate(true)
		if r.has("amount"):
			ov["comps"] = {"stack": {"amount": r["amount"]}}
		var made := Proto.spawn(r["out"], p.cell, ov)
		var inv: CInventory = p.c(&"inv")
		if inv.free_hand() >= 0:
			inv.put_in_hands(made, inv.free_hand())
		Skills.add_xp(p, r["skill"], 10.0 + r["time"] * 4.0)
		Sfx.play("ratchet", p.cell, 0.5)
		Game.tell(p, "You make %s." % made.the(), "good")
		if done.is_valid():
			done.call(made)
	)
