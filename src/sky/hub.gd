class_name Hub extends RefCounted
## Port Meridian, and the smaller ports scattered through the rings.
##
## A port is the one place in this game where nothing is trying to kill you, and it earns
## that by being the place where every other system is explained by a person rather than a
## tooltip. The shipwright tells you what a hull costs. The quartermaster tells you what
## the port is short of. The yard master hands you a drawing board. You leave with either
## a ship or a very good reason not to have one.
##
## The layout is stamped rather than generated because a port has to be legible in three
## seconds from the deck of an arriving ship: quay along the mooring, buildings set back
## from it in a row, the yard at one end with a berth beside it, and the chart-house at
## the other. Everything else about a port — who is in it, what they carry, what they pay
## — is generated from its island's biome and ring.

## The home port's buildings, in the order they are laid out along the quay. Each is a
## room with a person in it and a reason for the player to walk in.
const MERIDIAN = [
	{"trade": "shipwright", "name": "the Meridian Yard", "w": 8, "h": 6, "yard": true,
		"sign": "MERIDIAN YARD — HULLS BUILT, BOUGHT AND MENDED"},
	{"trade": "quartermaster", "name": "the Chandlery", "w": 7, "h": 5,
		"sign": "CHANDLERY — FUEL, TOOLS, ROPE, RATIONS"},
	{"trade": "rigger", "name": "the Sail Loft", "w": 7, "h": 5,
		"sign": "SAIL LOFT — CANVAS AND CORDAGE"},
	{"trade": "artificer", "name": "the Instrument House", "w": 6, "h": 5,
		"sign": "INSTRUMENTS — COMPASSES, SOUNDERS, HELMS"},
	{"trade": "gunsmith", "name": "the Gun Shop", "w": 6, "h": 5,
		"sign": "ARMOURY — MOUNTS AND SIDEARMS"},
	{"trade": "curiosity", "name": "the Curiosity", "w": 6, "h": 5,
		"sign": "CURIOSITIES — ALL SALES FINAL"},
	{"trade": "broker", "name": "the Exchange", "w": 6, "h": 5,
		"sign": "THE EXCHANGE — WE BUY ANYTHING"},
]

## A smaller port carries two or three of these, chosen by its ring.
const OUTPORT_TRADES = [
	["quartermaster", "broker"],
	["quartermaster", "broker", "rigger"],
	["quartermaster", "broker", "shipwright"],
	["broker", "shipwright", "gunsmith"],
	["broker", "artificer", "curiosity"],
]

# ------------------------------------------------------------------ the home port
static func build(gen: SkyGen, isl: Dictionary) -> void:
	var quay := _find_quay(gen, isl, 34)
	if quay.is_empty():
		# no coast long enough: put the port in the middle and let people walk
		quay = {"cell": isl["area"].center, "dir": Vector2i.RIGHT}
	var origin: Vector2i = quay["cell"]
	var out: Vector2i = quay["dir"]              # toward open sky
	var along := Vector2i(out.y, -out.x)         # along the coast
	isl["port"] = true
	isl["port_tier"] = 4                          # Meridian carries everything
	isl["hub"] = true
	gen.hub = isl
	gen.hub_center = origin

	# the berth is decided before anything is built, because the yard desk needs to know
	# where it is laying new hulls down
	gen.ship_start = origin + along * 8
	gen.ship_start_dir = out
	# Level the town before building it. A port is not a thing that happens to fit on an
	# island — it is a thing people flattened an island to make room for, and doing it in
	# that order is what stops the generator producing a harbour boxed in by its own
	# shops on a ledge with twenty walkable tiles.
	_level(gen, isl, origin, out, along, 46, 18)
	_pave(gen, origin, out, along, 44, 3)
	# Place the shops by searching rather than by fixed offsets. A coastline is ragged and
	# an island has rock in it, so a row of buildings laid out arithmetically loses half of
	# itself off the edge — which is how Meridian ended up with four traders and no yard.
	var taken: Array = []
	var doors: Array = []
	var rooms: Array = []   # [{area, corner, out, along, w, h}] for lodgers
	var missed: Array = []
	var built := 0
	# The apron in front of the quay is public ground. Reserving it before anything is
	# placed is what keeps the harbour open rather than walled in by its own premises.
	# Built from the quay's own axes and then bounded, because `along` and `out` are
	# rotated and an axis-aligned box in world space would reserve the wrong strip.
	taken.append(_span(origin, out, along, -9, 9, -1, 4))
	for spec in MERIDIAN:
		var placed: Dictionary = spec.duplicate()
		placed["berth"] = gen.ship_start
		placed["berth_dir"] = out
		if _place_shop(gen, isl, origin, out, along, placed, taken, doors, 26, rooms):
			built += 1
		else:
			missed.append(placed)
	# Anybody who could not get their own premises takes a counter in somebody else's.
	# A port that is missing its gunsmith because the island was small is a port with a
	# hole in the game in it; a gunsmith sharing the chandlery is a small port.
	for spec in missed:
		if _lodge(gen, isl, spec, rooms) or _barrow(gen, isl, spec, origin, out, along):
			built += 1
	# the streets, cut once everything is standing, plus one inland from the quay so the
	# harbour is always joined to the rest of the island it is on
	# Dressed first and cut through afterwards: a street clears whatever stands in it, so no
	# pile of crates or lantern post can ever wall a door in, however tightly it is packed.
	for k in range(-22, 24, 6):
		var lamp: Vector2i = origin + along * k - out
		if gen.is_land(lamp) and gen.map.is_passable(lamp):
			_prop(gen, lamp, "port_lantern")
	_dress_quay(gen, origin, out, along, 22)
	_road(gen, origin, isl["area"].center, isl)
	for d in doors:
		_road(gen, origin, d, isl)
	print("Skyfarer9: %s built with %d of %d premises" % [isl["name"], built, MERIDIAN.size()])
	isl["quay"] = {"cell": origin, "dir": out, "along": along}
	isl["mooring"] = {"cell": gen.ship_start, "dir": out, "island": isl["id"]}
	_notice_board(gen, origin + along * 2 - out * 2, isl)

# ------------------------------------------------------------------ the outports
static func build_outport(gen: SkyGen, isl: Dictionary) -> void:
	var quay := _find_quay(gen, isl, 16)
	if quay.is_empty():
		isl.erase("port")
		return
	var origin: Vector2i = quay["cell"]
	var out: Vector2i = quay["dir"]
	var along := Vector2i(out.y, -out.x)
	var tier: int = clampi(int(isl.get("port_tier", 1)), 0, 4)
	_pave(gen, origin, out, along, 16, 2)
	var trades: Array = OUTPORT_TRADES[tier]
	var taken: Array = []
	var doors: Array = []
	var rooms: Array = []
	for t in trades:
		var spec := {"trade": String(t), "name": _shop_name(String(t), isl), "w": 6, "h": 5,
			"sign": String(t).to_upper(), "yard": String(t) == "shipwright",
			"berth": origin + along * 5, "berth_dir": out}
		if not _place_shop(gen, isl, origin, out, along, spec, taken, doors, 16, rooms):
			_lodge(gen, isl, spec, rooms)
	# dressed before the streets are cut, as at Meridian, so nothing can wall a door in
	for k in range(-10, 12, 5):
		var lamp: Vector2i = origin + along * k - out
		if gen.is_land(lamp) and gen.map.is_passable(lamp):
			_prop(gen, lamp, "port_lantern")
	_dress_quay(gen, origin, out, along, 10)
	for d in doors:
		_road(gen, origin, d, isl)
	isl["quay"] = {"cell": origin, "dir": out, "along": along}
	isl["mooring"] = {"cell": origin + along * 5, "dir": out, "island": isl["id"]}

## Find somewhere along the quay for one shop, and put it there. Works outward from the
## middle of the quay in both directions, and steps further inland if the near row is
## blocked, so a port fills the ground it has rather than the ground it wished it had.
## Places one shop and records where its door came out. The roads are cut afterwards,
## once every building is down — cutting one per shop meant a later shop could be stamped
## straight across an earlier street, which is how Meridian ended up with two premises
## nobody could walk to.
static func _place_shop(gen: SkyGen, isl: Dictionary, origin: Vector2i, out: Vector2i,
		along: Vector2i, spec: Dictionary, taken: Array, doors: Array, reach: int,
		rooms: Array = []) -> bool:
	var w: int = int(spec["w"])
	var h: int = int(spec["h"])
	# First choice: a row set back from the quay, which is what a port actually looks like.
	for back in [2, 3, 4, 5, 6, 8, 10, 12, 14, 16]:
		for k in range(0, reach):
			for side in ([1, -1] if k > 0 else [1]):
				var at: int = k * side
				var corner: Vector2i = origin + along * at - out * (h + back - 1)
				var rect := _rect_of(corner, out, along, w, h)
				if _overlaps(rect, taken):
					continue
				if _stamp_building(gen, corner, w, h, out, along, spec, isl, rooms):
					taken.append(rect)
					doors.append(_door_of(corner, out, along, w, h))
					return true
	# Second choice: anywhere on the island that will take it, nearest the quay first. A
	# coast is ragged and a tidy row will not always fit; a port that straggles inland is
	# far better than a port missing five of its seven shops.
	var cells: Array = isl["cells"]
	var near := cells.duplicate()
	near.sort_custom(func(a, b):
		return Vector2(a - origin).length_squared() < Vector2(b - origin).length_squared())
	var tried := 0
	for c in near:
		if tried > 700:
			break
		tried += 1
		var corner2: Vector2i = c
		var rect2 := _rect_of(corner2, out, along, w, h)
		if _overlaps(rect2, taken):
			continue
		if _stamp_building(gen, corner2, w, h, out, along, spec, isl, rooms):
			taken.append(rect2)
			doors.append(_door_of(corner2, out, along, w, h))
			return true
	# Last resort: a smaller premises. A cramped chandlery is far better than a port
	# missing its chandlery, and on a small or very ragged island this is what happens.
	if w > 5 or h > 4:
		var small: Dictionary = spec.duplicate()
		small["w"] = 5
		small["h"] = 4
		return _place_shop(gen, isl, origin, out, along, small, taken, doors, reach, rooms)
	return false

## Where a shop's door ends up, given its corner. Kept in one place because the road
## builder and the stamper both have to agree about it exactly.
static func _door_of(corner: Vector2i, out: Vector2i, along: Vector2i, w: int, h: int) -> Vector2i:
	return corner + along * (w / 2) + out * (h - 1)

## The world-space bounding box of a patch measured in the quay's own axes: `k` runs
## along the quay and `d` runs inland. Used to reserve the harbour apron.
static func _span(origin: Vector2i, out: Vector2i, along: Vector2i,
		k0: int, k1: int, d0: int, d1: int) -> Rect2i:
	var lo := Vector2i(99999, 99999)
	var hi := Vector2i(-99999, -99999)
	for k in [k0, k1]:
		for d in [d0, d1]:
			var c: Vector2i = origin + along * k - out * d
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)

## The axis-aligned box a building covers, so two of them cannot be laid on each other.
static func _rect_of(corner: Vector2i, out: Vector2i, along: Vector2i, w: int, h: int) -> Rect2i:
	var a := corner
	var b := corner + along * (w - 1) + out * (h - 1)
	# grown by two, not one: a single tile of clearance lets four shops box a fifth in
	# with no way to cut a street to its door
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y)) - Vector2i.ONE
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y)) + Vector2i.ONE
	return Rect2i(lo, hi - lo + Vector2i.ONE)

static func _overlaps(r: Rect2i, taken: Array) -> bool:
	for t in taken:
		if r.intersects(t):
			return true
	return false

static func _shop_name(trade: String, isl: Dictionary) -> String:
	var place: String = String(isl["name"]).split(" ")[0]
	return {"quartermaster": "%s Chandlery", "broker": "%s Exchange", "rigger": "%s Sail Loft",
		"shipwright": "%s Yard", "gunsmith": "%s Armoury", "artificer": "%s Instruments",
		"curiosity": "%s Curiosities"}.get(trade, "%s Store") % place

# ------------------------------------------------------------------ getting about
## A port is only a port if you can walk round it.
##
## Shops are placed by searching, and a search on a ragged island will happily put the
## armoury on the far side of a rock spine with a pool in between. So every door gets a
## road back to the quay, cut through whatever is in the way: rock is quarried, water is
## filled, scenery is cleared, and the result is paved. That is also what turns a row of
## sheds into a town — the streets are the thing you actually walk down.
##
## Returns false only if the door is not on this island at all, which should not happen.
static func _road(gen: SkyGen, from: Vector2i, to: Vector2i, isl: Dictionary) -> bool:
	var path := _walk_path(gen, from, to, isl)
	if path.is_empty():
		return false
	for c in path:
		_pave_tile(gen, c)
		# a road wide enough for two people to pass, which stops it reading as a goat track
		for d in Defs.DIRS4:
			var n: Vector2i = c + d
			if gen.is_land(n) and not _is_building(gen, n):
				_pave_tile(gen, n)
	return true

## One tile of street: level it, clear it, pave it.
static func _pave_tile(gen: SkyGen, c: Vector2i) -> void:
	var map := gen.map
	if not map.inb(c) or not gen.is_land(c) or _is_building(gen, c):
		return
	var i := map.idx(c)
	map.turf[i] = Defs.T_STONE
	map.variant[i] = absi(hash(c)) % 6
	map.turf_hp[i] = 200.0
	map.structure[i] = Defs.S_NONE
	for e in Game.at(c).duplicate():
		if e.has_c(&"mob"):
			continue
		if e.has_c(&"blocker") or e.has_c(&"decal") or e.tags.get("scenery", false):
			e.destroy()

static func _is_building(gen: SkyGen, c: Vector2i) -> bool:
	var a := gen.map.area_at(c)
	return a != null and a.room_kind == "shop"

## A route between two points across this island, ignoring what is currently in the way —
## rock and water included, since the road is going to remove them. Plain breadth-first:
## the distances are tens of tiles and this runs once per shop at generation time.
static func _walk_path(gen: SkyGen, from: Vector2i, to: Vector2i, isl: Dictionary) -> Array:
	if from == to:
		return [to]
	var own := {}
	for c in isl["cells"]:
		own[c] = true
	if not own.has(to):
		return []
	var came := {from: from}
	var q := [from]
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		if cur == to:
			break
		for d in Defs.DIRS4:
			var n: Vector2i = cur + d
			if came.has(n) or not own.has(n):
				continue
			# a building is a wall to route round, not through — except the target door
			if n != to and _is_building(gen, n):
				continue
			came[n] = cur
			q.append(n)
	if not came.has(to):
		return []
	var path := []
	var at := to
	while at != from:
		path.append(at)
		at = came[at]
	path.append(from)
	path.reverse()
	return path

# ------------------------------------------------------------------ what a shop looks like
## Each trade gets its own room rather than the same box with a different person in it.
## A player should be able to stand in a doorway and know which shop they are in from the
## floor and the clutter, before they have read the sign or spoken to anybody.
##
##   floor    the turf underfoot
##   back     props along the back wall, laid left to right
##   corner   one thing in each far corner
##   counter  what the counter itself is
##   lit      the colour of the lamp, because a forge is not lit like a chart-house
const SHOP_STYLE := {
	"shipwright": {"floor": Defs.T_PLATING, "counter": "workbench", "lit": "#ffb04a",
		"back": ["deck_forge", "crate", "sheet_stack", "crate"],
		"corner": ["rust_spar", "crate"],
		"note": "Sawdust, iron filings and the smell of hot metal. Hull plans pinned to every flat surface."},
	"rigger": {"floor": Defs.T_WOOD, "counter": "loom", "lit": "#e8d8a0",
		"back": ["loom", "crate", "canvas_roll", "crate"],
		"corner": ["canvas_roll", "crate"],
		"note": "Bolts of canvas to the ceiling and enough rope to hang the whole quay."},
	"gunsmith": {"floor": Defs.T_DARK, "counter": "table", "lit": "#e8704a",
		"back": ["gun_rack", "crate", "gun_rack", "locker"],
		"corner": ["crate", "locker"],
		"note": "Racked barrels, a smell of scorched oil, and a notice about discharging indoors."},
	"artificer": {"floor": Defs.T_WHITE, "counter": "workbench", "lit": "#9ad8ff",
		"back": ["workbench", "instrument_case", "crate", "instrument_case"],
		"corner": ["instrument_case", "crate"],
		"note": "Half of it is humming. The shopkeeper does not appear to notice."},
	"quartermaster": {"floor": Defs.T_WOOD, "counter": "table", "lit": "#ffd8a0",
		"back": ["barrel", "crate", "barrel", "crate"],
		"corner": ["barrel", "crate"],
		"note": "Stacked to the rafters with the dull things that keep people alive."},
	"curiosity": {"floor": Defs.T_CARPET, "counter": "table", "lit": "#c88ae8",
		"back": ["curio_shelf", "curio_shelf", "locker", "curio_shelf"],
		"corner": ["curio_shelf", "locker"],
		"note": "Nothing in here is labelled and everything in here is watching."},
	"broker": {"floor": Defs.T_BLUECARPET, "counter": "table", "lit": "#e8c85a",
		"back": ["ledger_desk", "crate", "crate", "locker"],
		"corner": ["crate", "crate"],
		"note": "A long counter, a set of brass scales, and a queue that is never quite empty."},
}

static func style(trade: String) -> Dictionary:
	return SHOP_STYLE.get(trade, SHOP_STYLE["quartermaster"])

# ------------------------------------------------------------------ groundworks
## Flatten a rectangle of island behind the quay into buildable ground.
##
## Rock is quarried out, pools are filled, scenery is cleared and the whole lot is left
## as bare earth ready to be built on or paved. This runs before a single shop is placed,
## so the placement search is looking at a town-sized piece of flat ground rather than
## whatever the noise happened to leave.
##
## It deliberately does not pave: the streets are paved later and the difference between
## paved street and bare ground is most of what makes the port read as a place with a
## layout rather than a grey slab.
static func _level(gen: SkyGen, isl: Dictionary, origin: Vector2i, out: Vector2i,
		along: Vector2i, width: int, depth: int) -> void:
	var map := gen.map
	var half := width / 2
	var cut := 0
	for k in range(-half, half + 1):
		for d in range(-1, depth + 1):
			var c: Vector2i = origin + along * k - out * d
			if not map.inb(c) or not gen.is_land(c):
				continue
			# a ragged edge, so the town site reads as ground somebody cleared rather
			# than as a rectangle a machine cut
			var edge_t := float(maxi(absi(k) - half + 4, d - depth + 4))
			if edge_t > 0.0 and gen.rng.randf() < edge_t * 0.3:
				continue
			var i := map.idx(c)
			var fl := map.tflags(c)
			if (fl & (Defs.F_SOLID | Defs.F_LIQUID)) != 0:
				cut += 1
			# Bare earth with patches of gravel worn through it. Patchy rather than
			# per-tile: a per-tile roll produces a checkerboard, and two earth tones in
			# broad patches produce ground somebody has been walking on for years.
			# Bare earth with worn stone through it. T_GRAVEL and T_PACKED are both
			# *frozen* in this engine's turf table and came out as snow patches in the
			# middle of a temperate port, which looked like a bug because it was one.
			var patch := (gen.patch.get_noise_2d(c.x * 2.2, c.y * 2.2) + 1.0) * 0.5
			map.turf[i] = Defs.T_DIRT if patch < 0.40 else Defs.T_STONE
			map.variant[i] = absi(hash(c)) % 4
			map.turf_hp[i] = 120.0
			map.structure[i] = Defs.S_NONE
			for e in Game.at(c).duplicate():
				if e.has_c(&"mob"):
					continue
				if e.has_c(&"blocker") or e.has_c(&"decal") or e.tags.get("scenery", false):
					e.destroy()
	# the walkable region has just changed shape, so the cached answer is wrong
	isl["ground"] = _main_ground(gen, isl)

# ------------------------------------------------------------------ construction
## A stone quay: flat, walkable, and unmistakably not a beach.
static func _pave(gen: SkyGen, origin: Vector2i, out: Vector2i, along: Vector2i, length: int, depth: int) -> void:
	var half := length / 2
	for k in range(-half, half + 1):
		for d in range(-1, depth + 1):
			var c: Vector2i = origin + along * k - out * d
			if not gen.map.inb(c) or not gen.is_land(c):
				continue
			var i := gen.map.idx(c)
			# dressed stone, not the island's own ground: a quay has to read as built
			gen.map.turf[i] = Defs.T_STONE
			gen.map.variant[i] = absi(hash(c)) % 6
			gen.map.turf_hp[i] = 200.0
			for e in Game.at(c).duplicate():
				if e.has_c(&"blocker") or e.has_c(&"decal"):
					e.destroy()

## One shop: four walls, a door onto the quay, a floor, a counter, a sign and a person.
static func _stamp_building(gen: SkyGen, corner: Vector2i, w: int, h: int,
		out: Vector2i, along: Vector2i, spec: Dictionary, isl: Dictionary,
		rooms: Array = []) -> bool:
	var map := gen.map
	# The footprint has to be on this island — a shop cannot hang over open sky — but rock
	# and water are allowed, because a port levels the ground it is built on and that is
	# what people do. Refusing rock is what left Meridian half built.
	for y in range(-1, h + 1):
		for x in range(-1, w + 1):
			var c: Vector2i = corner + along * x + out * y
			if not map.inb(c) or not gen.is_land(c):
				return false
			# and on the part of the island people can walk on, which is the whole reason
			# the port was sited where it was
			var ground: Dictionary = isl.get("ground", {})
			if not ground.is_empty() and not ground.has(c):
				return false
			# do not build on top of another building; a site's scenery is fair game
			var a := map.area_at(c)
			if a != null and a.room_kind == "shop":
				return false
	var st := style(String(spec["trade"]))
	var area := map.new_area(String(spec["name"]), "civilian")
	area.room_kind = "shop"
	area.power_equip = true
	area.power_light = true
	area.power_environ = true
	area.outdoor = false
	for y in h:
		for x in w:
			var c: Vector2i = corner + along * x + out * y
			var i := map.idx(c)
			for e in Game.at(c).duplicate():
				if e.has_c(&"blocker") or e.has_c(&"decal") or e.has_c(&"furniture"):
					e.destroy()
			var edge: bool = x == 0 or y == 0 or x == w - 1 or y == h - 1
			map.turf[i] = Defs.T_WALL if edge else int(st["floor"])
			map.structure[i] = Defs.S_NONE
			map.turf_hp[i] = float(Defs.TURFS[map.turf[i]].get("hp", 200))
			map.variant[i] = absi(hash(c)) % 4
			map.area[i] = area.id
			area.cells.append(c)
	# the door: middle of the quay-facing wall, which is the far edge in +out
	var door_x := w / 2
	var door: Vector2i = corner + along * door_x + out * (h - 1)
	map.turf[map.idx(door)] = Defs.T_WOOD
	Proto.spawn("ship_door", door, {"name": "%s door" % String(spec["name"])})
	# two windows, so a shop reads as a shop from the quay
	var win_cells: Array = []
	for dx in [door_x - 2, door_x + 2]:
		if dx <= 0 or dx >= w - 1:
			continue
		var win: Vector2i = corner + along * dx + out * (h - 1)
		map.turf[map.idx(win)] = Defs.T_WOOD
		map.set_structure(win, Defs.S_WINDOW, false)
		win_cells.append(win)
	# what PortLife needs to bring the front to life: where the doors, windows and
	# chimneys are, and which way is out
	if not isl.has("shops"):
		isl["shops"] = []
	(isl["shops"] as Array).append({"door": door, "trade": String(spec["trade"]),
		"col": String(st["lit"]), "out": out, "along": along, "corner": corner,
		"w": w, "h": h, "windows": win_cells, "yard": bool(spec.get("yard", false)),
		"name": String(spec["name"])})
	# a lantern either side of the step, so a door is findable from the far end of the quay
	for sx in [-3, 3]:
		var lc: Vector2i = corner + along * (door_x + sx) + out * h
		if _open_ground(gen, lc) and Game.at(lc).is_empty():
			_prop(gen, lc, "port_lantern")
	area.center = corner + along * (w / 2) + out * (h / 2)

	# ---- Light it first, on tiles reserved before any furniture can take them. A lamp
	# that failed to spawn because a crate got there first left the whole room pitch
	# black, and an unlit interior reads as "you cannot go in there".
	var lamp_cells := [corner + along * (w / 2) + out * 2,
		corner + along * (w / 2) + out * (h - 2)]
	for at in lamp_cells:
		if not map.inb(at):
			continue
		for old in Game.at(at).duplicate():
			if not old.has_c(&"mob"):
				old.destroy()
		var lamp := Proto.spawn("shop_lamp", at)
		if lamp == null:
			continue
		var li: CLight = lamp.c(&"light")
		if li != null:
			li.color = Color(String(st["lit"]))
			li.radius = 8.0
			li.energy = 1.1
			if Game.lighting != null:
				Game.lighting.register(li)

	# ---- the counter, across the shop two tiles in from the door, with a gap to get
	# behind it. A counter you can walk round is a shop; one you cannot is a wall.
	var counter_row := h - 3
	for x in range(1, w - 1):
		if x == door_x + 1:
			continue  # the gap the shopkeeper steps through
		var at3: Vector2i = corner + along * x + out * counter_row
		if at3 in lamp_cells or not Game.at(at3).is_empty():
			continue
		_prop(gen, at3, String(st["counter"]))

	# ---- the back wall, laid out left to right
	var back: Array = st["back"]
	for x in range(1, w - 1):
		var at2: Vector2i = corner + along * x + out * 1
		if at2 in lamp_cells or not Game.at(at2).is_empty():
			continue
		_prop(gen, at2, String(back[(x - 1) % back.size()]))
	# ---- and one thing in each far corner, for the silhouette
	var corners: Array = st["corner"]
	_prop(gen, corner + along * 1 + out * 2, String(corners[0]))
	_prop(gen, corner + along * (w - 2) + out * 2, String(corners[1 % corners.size()]))

	# ---- the sign over the door, and a painted mat outside it, so the row of shops is
	# legible from the far end of the quay without reading anything
	_sign(gen, corner + along * door_x + out * h, String(spec["sign"]), String(spec["name"]))
	_doormat(gen, corner + along * door_x + out * (h + 1), String(st["lit"]), String(spec["name"]))

	# ---- the person behind it
	var stand: Vector2i = corner + along * door_x + out * (h - 4)
	if not map.is_passable(stand):
		stand = area.center
	var keeper := _keeper(gen, stand, String(spec["trade"]), isl)
	if keeper != null:
		keeper.desc = String(st["note"])
		keeper.c(&"mob").face(Defs.dir_from_vec(out))
	rooms.append({"area": area, "corner": corner, "out": out, "along": along,
		"w": w, "h": h, "name": String(spec["name"]), "lodgers": 0})
	# a port's premises are always lit. See LightingSystem.lit_rooms for why this is not
	# left to the lamps: one lamp that failed to place left a shop pitch black, and a
	# black rectangle with a door in it reads as somewhere you are not allowed to go.
	if Game.lighting != null:
		for c in area.cells:
			if map.inb(c) and not map.is_solid_turf(c):
				Game.lighting.lit_rooms[map.idx(c)] = true
		Game.lighting.mark_ambient_dirty()
	if bool(spec.get("yard", false)):
		# the drawing board goes where a customer can reach it without going behind the
		# counter, because it is the one thing in this port a new player has to find
		var desk_at: Vector2i = corner + along * 1 + out * counter_row
		_yard_desk(gen, desk_at, isl,
			spec.get("berth", gen.ship_start), spec.get("berth_dir", gen.ship_start_dir))
	return true

## Put a trader behind a spare stretch of somebody else's counter. The room keeps its own
## name; the sign outside gains a second line; and the trade is open for business.
static func _lodge(gen: SkyGen, isl: Dictionary, spec: Dictionary, rooms: Array) -> bool:
	var trade := String(spec["trade"])
	for room in rooms:
		if int(room.get("lodgers", 0)) >= 3:
			continue
		var corner: Vector2i = room["corner"]
		var out: Vector2i = room["out"]
		var along: Vector2i = room["along"]
		var w: int = room["w"]
		var h: int = room["h"]
		# behind the counter, working outward from the far end
		for x in range(w - 2, 0, -1):
			var stand: Vector2i = corner + along * x + out * (h - 4)
			if not gen.map.inb(stand) or not gen.map.is_passable(stand):
				continue
			if not Game.at(stand).is_empty():
				continue
			var keeper := _keeper(gen, stand, trade, isl)
			if keeper == null:
				continue
			room["lodgers"] = int(room.get("lodgers", 0)) + 1
			var area: Area = room["area"]
			area.name = "%s (and %s)" % [area.name, String(CVendor.TRADES[trade]["name"]).to_lower()]
			keeper.desc = "Renting a yard of counter in %s, and making the most of it." % String(room["name"])
			if bool(spec.get("yard", false)):
				var desk_at: Vector2i = corner + along * maxi(1, x - 1) + out * (h - 3)
				_yard_desk(gen, desk_at, isl,
					spec.get("berth", gen.ship_start), spec.get("berth_dir", gen.ship_start_dir))
			return true
	return false

## The last resort, and the nicest one: a trader working off a handcart on the quay.
##
## A port that is short of buildings is not a port that is short of trades. Somebody will
## always set up on the front with a barrow and a tarpaulin, and a player who finds the
## gunsmith standing in the open air between the chandlery and the harbour master has
## learned something true about the place.
static func _barrow(gen: SkyGen, isl: Dictionary, spec: Dictionary,
		origin: Vector2i, out: Vector2i, along: Vector2i) -> bool:
	var trade := String(spec["trade"])
	for k in range(1, 22):
		for side in [1, -1]:
			for d in [1, 2, 3]:
				var c: Vector2i = origin + along * (k * side) - out * d
				if not gen.map.inb(c) or not gen.map.is_passable(c):
					continue
				if not Game.at(c).is_empty() or not Falling.supported(c):
					continue
				var a := gen.map.area_at(c)
				if a != null and a.room_kind == "shop":
					continue
				var keeper := _keeper(gen, c, trade, isl)
				if keeper == null:
					continue
				keeper.desc = "Working off a barrow on the front, under a tarpaulin and a hand-painted board."
				# the cart itself, so it reads as a pitch rather than somebody loitering
				var behind: Vector2i = c - out
				if gen.map.inb(behind) and gen.map.is_passable(behind) and Game.at(behind).is_empty():
					_prop(gen, behind, "quay_crate")
				_doormat(gen, c + out, String(style(trade)["lit"]), String(spec["name"]))
				if bool(spec.get("yard", false)):
					var desk: Vector2i = c + along * side
					if gen.map.inb(desk) and gen.map.is_passable(desk) and Game.at(desk).is_empty():
						_yard_desk(gen, desk, isl,
							spec.get("berth", gen.ship_start), spec.get("berth_dir", gen.ship_start_dir))
				return true
	return false

## What a working quay has on it.
##
## Bollards on the edge, because a ship ties to something. Crates stencilled for
## somewhere else, because cargo waits. Coils of rope, barrels, and a lantern every six
## tiles. None of it does anything; all of it is the difference between a stone rectangle
## and a place where people load ships for a living.
static func _dress_quay(gen: SkyGen, origin: Vector2i, out: Vector2i, along: Vector2i, reach: int) -> void:
	var rng := gen.rng
	for k in range(-reach, reach + 1):
		if absi(k) <= 3:
			continue # Leave the arrival apron and notice board clear.
		var edge: Vector2i = origin + along * k
		# bollards along the lip, spaced, never blocking the gangway
		if absi(k) % 4 == 2 and _open_ground(gen, edge):
			_prop(gen, edge, "bollard")
			continue
		# and clutter set back from it, where it will not be walked through
		if rng.randf() > 0.5:
			continue
		for d in [1, 2]:
			var c: Vector2i = origin + along * k - out * d
			if not _open_ground(gen, c):
				continue
			var a2 := gen.map.area_at(c)
			if a2 != null and a2.room_kind == "shop":
				continue
			var pick: String = ["quay_crate", "barrel", "rope_coil", "quay_crate", "rope_coil", "barrel"][rng.randi() % 6]
			_prop(gen, c, pick)
			# cargo waits in piles, not in ones: a second crate beside the first, and
			# sometimes a third row behind it, leaving the walkway inland clear
			if pick != "rope_coil" and rng.randf() < 0.55:
				var nb: Vector2i = c + along
				if _open_ground(gen, nb) and absi(k + 1) > 3:
					_prop(gen, nb, "barrel" if pick == "quay_crate" else "quay_crate")
			break

## A painted square of colour on the quay outside a door. It costs one tile and it is the
## difference between "a row of identical sheds" and "the one with the orange step is the
## yard".
static func _doormat(gen: SkyGen, c: Vector2i, col: String, nm: String) -> void:
	if not gen.map.inb(c) or not gen.is_land(c):
		return
	if not Proto.has("shop_mat"):
		return
	var m := Proto.spawn("shop_mat", c, {"name": "%s — the step" % nm})
	if m != null and m.spr != null:
		m.spr.modulate = Color(col)

## Land you can stand on, with nothing on it. `is_passable` is true for open sky, which
## is exactly how a row of bollards ended up hanging in the air off the end of the quay.
static func _open_ground(gen: SkyGen, c: Vector2i) -> bool:
	if not gen.map.inb(c) or not gen.is_land(c):
		return false
	if gen.map.is_solid_turf(c) or not gen.map.is_passable(c):
		return false
	if (gen.map.tflags(c) & Defs.F_LIQUID) != 0:
		return false
	return Game.at(c).is_empty()

static func _prop(gen: SkyGen, c: Vector2i, proto_id: String) -> Entity:
	if not gen.map.inb(c) or not Proto.has(proto_id):
		return null
	return Proto.spawn(proto_id, c)

static func _sign(gen: SkyGen, c: Vector2i, text: String, nm: String) -> void:
	if not gen.map.inb(c) or not Proto.has("port_sign"):
		return
	var e := Proto.spawn("port_sign", c, {"name": nm})
	if e != null:
		e.desc = "[b]%s[/b]" % text

## A trader, behind a counter, with stock generated from what this port is and where.
static func _keeper(gen: SkyGen, c: Vector2i, trade: String, isl: Dictionary) -> Entity:
	if not gen.map.inb(c):
		return null
	var cfg := {"name": _person_name(gen.rng), "appearance": Jobs.random_appearance(gen.rng),
		"pronoun": ["they", "she", "he"][gen.rng.randi() % 3]}
	var who := Crew.spawn_human("assistant", c, cfg)
	if who == null:
		return null
	var v := CVendor.new().setup({"trade": trade, "tier": int(isl.get("port_tier", 1)),
		"biome": String(isl["biome"])})
	who.add(v)
	who.tags["vendor"] = true
	who.tags["anchored_role"] = true
	# nobody swings at the people who run a port; see Combat.melee
	who.tags["protected"] = true
	# they speak for themselves (CVendor.idle). The generic crew brain would otherwise
	# have them broadcasting station gossip about moss shrikes over the common channel.
	who.tags["no_smalltalk"] = true
	who.tags["sky_class"] = ""
	var m: CMob = who.c(&"mob")
	if m != null:
		m.job = "assistant"
		_dress_keeper(who, trade)
	who.display_name = "%s, %s" % [String(cfg["name"]), String(CVendor.TRADES[trade]["name"]).to_lower()]
	# a shopkeeper who wanders off is a shopkeeper nobody can find
	var brain: CBrain = who.c(&"brain")
	if brain != null:
		who.tags["home_cell"] = c
	# they know their trade, which is why their prices are what they are
	Skills.set_level(who, "trading", 25 + int(isl.get("port_tier", 1)) * 12)
	match trade:
		"shipwright": Skills.set_level(who, "shipwright", 55)
		"rigger": Skills.set_level(who, "rigging", 55)
		"gunsmith": Skills.set_level(who, "gunnery", 55)
		"artificer": Skills.set_level(who, "artifice", 55)
	return who

static func _dress_keeper(who: Entity, trade: String) -> void:
	var inv: CInventory = who.c(&"inv")
	var accent := Color(String(style(trade)["lit"]))
	var uniform := inv.worn("uniform")
	if uniform:
		var clothing: CClothing = uniform.c(&"clothing")
		clothing.sprite = "uniform_formal" if trade in ["broker", "curiosity"] else "uniform_jumpsuit"
		clothing.colors = [accent.darkened(0.35), accent.lightened(0.25), Color("#322d2a"), Color("#d6b66b")]
		clothing.refresh_icon()
	if trade in ["shipwright", "rigger", "gunsmith"] and inv.worn("suit") == null:
		var apron := Crew._clothes("suit", who.cell, "%s's work apron" % CVendor.TRADES[trade]["name"], "suit_apron", [accent.darkened(0.25)], Crew.SUIT_STATS.apron)
		inv.equip(apron, "suit")
	var hat: String = {"shipwright": "hardhat", "quartermaster": "cap", "gunsmith": "beret", "artificer": "cap"}.get(trade, "")
	if hat != "" and inv.worn("head") == null:
		var head := Crew._clothes("hat", who.cell, "%s's %s" % [CVendor.TRADES[trade]["name"], hat], "head_" + hat, [accent, Color("#322d2a"), Color("#d6b66b")], Crew.HEAD_STATS.get(hat, {}))
		inv.equip(head, "head")
	who.c(&"mob").refresh_doll()

static func _yard_desk(gen: SkyGen, c: Vector2i, isl: Dictionary, berth, berth_dir) -> void:
	if not gen.map.inb(c) or not Proto.has("yard_desk"):
		return
	var e := Proto.spawn("yard_desk", c)
	if e == null:
		return
	var y := CShipyard.new()
	y.berth = berth as Vector2i
	y.berth_dir = Defs.dir_from_vec(berth_dir as Vector2i)
	y.port_tier = int(isl.get("port_tier", 1))
	y.biome = String(isl["biome"])
	e.add(y)

## The board by the gangway: where the region's rings, its ports and its rumours are
## written down, so a player who reads one thing in this game reads the right thing.
static func _notice_board(gen: SkyGen, c: Vector2i, isl: Dictionary) -> void:
	if not gen.map.inb(c) or not Proto.has("notice_board"):
		return
	var e := Proto.spawn("notice_board", c)
	if e != null:
		e.tags["hub"] = true

# ------------------------------------------------------------------ quay finding
## Where the port goes.
##
## Every previous version of this scored coastline by "how much land is behind it", and
## every version put Meridian on a ledge with a cliff at its back at least one seed in
## ten — seven shops, a harbour and twenty tiles you could stand on.
##
## So it does not guess. It floods the island for walkable ground, takes the largest
## connected piece of it, and only then looks for a coast on the edge of *that*. A port
## sited this way is on the part of the island a person could live on, by construction.
static func _find_quay(gen: SkyGen, isl: Dictionary, span: int) -> Dictionary:
	var ground := _main_ground(gen, isl)
	if ground.size() < 40:
		return {}
	isl["ground"] = ground
	# coast tiles of the walkable region: walkable, with open sky beyond
	var shore := []
	for c in ground:
		for d in Defs.DIRS4:
			if not gen.is_land(c + d):
				shore.append([c, d])
				break
	if shore.is_empty():
		return {}
	shore.shuffle()
	var best := {}
	var best_score := -1.0
	var tried := 0
	for pair in shore:
		if tried > 140:
			break
		tried += 1
		var p: Vector2i = pair[0]
		var d: Vector2i = pair[1]
		if not gen._clear_run(p, d, 10) or not gen._clear_flank(p, d, mini(span, 13), 8):
			continue
		# how much of the walkable region is within easy reach of this spot: the port
		# wants elbow room, and this is the number that actually measures it
		var room := 0
		for y in range(-7, 8):
			for x in range(-7, 8):
				if ground.has(p + Vector2i(x, y)):
					room += 1
		var score := float(room)
		if score > best_score:
			best_score = score
			best = {"cell": p, "dir": d}
		if best_score > 150.0:
			break
	return best

## The largest connected patch of ground on an island you could actually walk across.
## Rock, water and the far side of a chasm are all excluded, which is the point.
static func _main_ground(gen: SkyGen, isl: Dictionary) -> Dictionary:
	var walkable := {}
	for c in isl["cells"]:
		if gen.map.is_solid_turf(c):
			continue
		if (gen.map.tflags(c) & Defs.F_LIQUID) != 0:
			continue
		walkable[c] = true
	var best := {}
	var seen := {}
	for start in walkable:
		if seen.has(start):
			continue
		var comp := {}
		var q := [start]
		seen[start] = true
		var head := 0
		while head < q.size():
			var cur: Vector2i = q[head]
			head += 1
			comp[cur] = true
			for d in Defs.DIRS4:
				var n: Vector2i = cur + d
				if walkable.has(n) and not seen.has(n):
					seen[n] = true
					q.append(n)
		if comp.size() > best.size():
			best = comp
	return best

const FIRST = ["Wren", "Cass", "Orlo", "Teodo", "Bell", "Maro", "Sable", "Idris", "Nell", "Corvo",
	"Piet", "Hale", "Ysolde", "Bram", "Quill", "Ferro", "Lys", "Rook", "Tamsin", "Odo",
	"Vasska", "Emeret", "Harl", "Juno", "Kestrel", "Marlo", "Perrin", "Sy", "Truda", "Wick"]
const LAST = ["Ashdown", "Vane", "Cutter", "Halloway", "Marrow", "Pike", "Fennel", "Straked",
	"Underhill", "Braid", "Crowther", "Sallow", "Tarn", "Weft", "Gilder", "Lockyer",
	"Standfast", "Reave", "Bellwether", "Ossick"]

static func _person_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [FIRST[rng.randi() % FIRST.size()], LAST[rng.randi() % LAST.size()]]
