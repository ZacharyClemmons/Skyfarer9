class_name SkyGen extends RefCounted
## Builds a sky region: a very wide sheet of open air with floating islands hung in it.
##
## Nothing here is hand-authored. The region is a set of concentric rings around one fixed
## point — the home port — and an island's distance from that point decides almost
## everything about it: which biomes it can be, how hard the things living on it hit, what
## its sites are worth, and whether anybody has bothered to put a trading post on it.
##
## That structure is the whole shape of the game. The first hour is spent inside the Home
## Reach, where the worst thing on an island is a territorial beetle and the ore is iron.
## Five hours later the same player is in the Outer Dark because that is the only place
## voidsteel comes from, and the difference between those two places is legible from the
## deck: the light, the weather, the silhouettes, and what comes over the rail.
##
## Each island is grown from overlapping lobes warped by noise, so the silhouettes come
## out ragged rather than round, then given its biome ground, a spine of rock with ore
## salted through it, pools, flora, fauna, sites and — if it is well enough placed — a
## port with people on it.
##
## Everything off an island is Defs.T_SKY: open air with nothing to stand on. Walking
## into it is how you die in this game (see Falling).

## Four times the old region. The Cloudsea should take real minutes to cross, because
## distance is the only currency a trade route has.
const W := 512
const H := 448
const MARGIN := 12 # tiles of clear sky kept around the region's rim

## Ring radii, in tiles from the home port. Everything outside the last one is the Rim.
## The last ring has to fit inside the short axis or it exists only in the corners, which
## would make the most dangerous sky in the game a place you reach by accident.
const RINGS = [58.0, 102.0, 146.0, 182.0]

## How many islands a region carries. A big number is the point: the sky should look
## populated from a mast-head and there should always be one more thing on the horizon.
const ISLAND_COUNT = Vector2i(38, 52)

var map: StationMap
var rng := RandomNumberGenerator.new()
var altitude := Defs.ALT_LOW
var band := 1
var region_name := "the Shelf"

var islands: Array = [] # {id, name, biome, b, tier, center, rect, cells, rim, area, ...}
var home: Dictionary = {}
## Where the home port sits, and the rings are measured from. Fixed at the middle of the
## sheet so a player's mental map of "out" and "back" never has to be relearned.
var hub_center := Vector2i(W / 2, H / 2)
var hub: Dictionary = {}
var ports: Array = [] # islands carrying a trading post
var mob_spawns: Array = [] # {cell, mob, island}
var moorings: Array = [] # {cell, dir, island} where an airship can tie up
var ship_start := Vector2i.ZERO
var ship_start_dir := Vector2i.RIGHT

var _land := {} # Vector2i -> island id, for fast overlap tests
var warp: FastNoiseLite
var detail: FastNoiseLite
var patch: FastNoiseLite

# ------------------------------------------------------------------ entry
func generate(seed_value: int, band_index := 1) -> StationMap:
	rng.seed = seed_value
	band = clampi(band_index, 0, 4)
	altitude = Defs.ALT_BANDS[band]
	region_name = Defs.ALT_NAMES[band]
	Defs.set_altitude(altitude)

	warp = _noise(seed_value, 0.055, 3)
	detail = _noise(seed_value + 7717, 0.14, 2)
	patch = _noise(seed_value + 4243, 0.032, 3)

	# The last 64 rows are an instance atlas for ship decks below the weather deck.
	# Islands remain in the original W x H region; each lower deck gets its own
	# 32 x 32 cell berth in the atlas, so stacked rooms use the real tile engine.
	map = StationMap.new(W, H + 64)
	Game.map = map # props and sites spawn during generation and need it
	map.areas[0].name = "Open Sky"
	map.areas[0].outdoor = true
	for i in W * (H + 64):
		map.turf[i] = Defs.T_SKY
		map.variant[i] = absi(hash(Vector2i(i % W, i / W))) % 8

	hub_center = Vector2i(W / 2, H / 2)
	# Stage timings, kept in the build rather than behind a flag: a region this size is a
	# few seconds of work and the only way to keep it that way is to be able to see which
	# stage grew. `report()` prints them.
	timings.clear()
	# a one-element array rather than a local, because a GDScript lambda captures by value
	# and a captured int would make every stage read as the time since generation began
	var clock := [Time.get_ticks_msec()]
	var mark := func(nm: String):
		var now := Time.get_ticks_msec()
		timings.append([nm, now - int(clock[0])])
		clock[0] = now
	_cloud_banks()
	mark.call("cloud")
	_scatter_islands()
	mark.call("scatter")
	for isl in islands:
		_paint_island(isl)
	mark.call("paint")
	for isl in islands:
		_rock_and_ore(isl)
	mark.call("rock")
	for isl in islands:
		_water(isl)
	mark.call("water")
	for isl in islands:
		_flora(isl)
		_fauna(isl)
	mark.call("life")
	_choose_home()
	for isl in islands:
		Sites.populate(self, isl)
	mark.call("sites")
	_mooring_points()
	mark.call("moorings")
	_choose_ports()
	mark.call("ports")
	if not home.is_empty():
		Hub.build(self, home)
	mark.call("hub")
	return map

## [stage, milliseconds] for the last generate(), printed by report().
var timings: Array = []

## How far out a world cell is, as a ring index 0..4.
func tier_at(c: Vector2i) -> int:
	var d := Vector2(c - hub_center).length()
	for i in RINGS.size():
		if d < RINGS[i]:
			return i
	return 4

func ring_name_at(c: Vector2i) -> String:
	return Biomes.ring_name(tier_at(c))

func _noise(sd: int, freq: float, oct: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = sd
	n.frequency = freq
	n.fractal_octaves = oct
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return n

# ------------------------------------------------------------------ sky dressing
## Drifting banks of cloud. Purely atmosphere: they read as sky and you still fall
## through them, but they break up the emptiness and hide what is on the far side.
func _cloud_banks() -> void:
	var n := rng.randi_range(70, 120)
	for _i in n:
		var c := Vector2i(rng.randi_range(2, W - 3), rng.randi_range(2, H - 3))
		var rx := rng.randi_range(5, 18)
		var ry := rng.randi_range(3, 8)
		for y in range(c.y - ry, c.y + ry + 1):
			for x in range(c.x - rx, c.x + rx + 1):
				var p := Vector2i(x, y)
				if not map.inb(p):
					continue
				var dx := float(x - c.x) / float(rx)
				var dy := float(y - c.y) / float(ry)
				var d := dx * dx + dy * dy
				if d > 1.0:
					continue
				if (1.0 - d) + detail.get_noise_2d(x * 2.0, y * 2.0) * 0.5 > 0.45:
					map.turf[map.idx(p)] = Defs.T_CLOUD

# ------------------------------------------------------------------ island layout
## Scatter island seeds so that no two land masses touch. Big islands go down first and
## claim their space; the rest fill the gaps.
## Lay the region out ring by ring rather than scattering at random, so the shape of the
## world is a thing the player can learn instead of a thing they have to survey.
##
## The home island goes down first, at the centre, and it is always large and always
## gentle. Every other island is then placed into a ring, and an island's ring decides
## which biomes it may be and how hard it hits. Islands further out are also allowed to
## be bigger, because a landmark worth a two-minute flight has to be worth looking at.
func _scatter_islands() -> void:
	var placed := []
	# ---- the home island: big, kindly, and exactly in the middle
	var home_r := rng.randi_range(30, 38)
	placed.append({"c": hub_center, "r": home_r})
	islands.append(_isl(hub_center, home_r, 0, true))

	var wanted := rng.randi_range(ISLAND_COUNT.x, ISLAND_COUNT.y)
	# a quota per ring, so no ring is ever empty and the outer sky is not crowded
	var quota := [maxi(4, wanted / 7), maxi(5, wanted / 5), maxi(6, wanted / 4),
		maxi(5, wanted / 5), maxi(4, wanted / 7)]
	for tier in 5:
		for _i in quota[tier]:
			var r := rng.randi_range(7 + tier * 3, 16 + tier * 6)
			var spot := _find_spot_in_ring(r, tier, placed)
			if spot.x < 0:
				continue
			placed.append({"c": spot, "r": r})
			islands.append(_isl(spot, r, tier, false))
	# a scatter of very small rocks everywhere: waypoints, ambushes, and somewhere to
	# put down when a cell tears
	for _i in rng.randi_range(14, 24):
		var r2 := rng.randi_range(4, 7)
		var spot2 := _find_spot_in_ring(r2, rng.randi_range(0, 4), placed)
		if spot2.x < 0:
			continue
		placed.append({"c": spot2, "r": r2})
		islands.append(_isl(spot2, r2, tier_at(spot2), false))

func _isl(spot: Vector2i, r: int, tier: int, is_home: bool) -> Dictionary:
	var bid: String = Biomes.B_HEARTHMOSS if is_home else Biomes.pick_for(band, tier, rng)
	var b := Biomes.get_b(bid)
	return {
		"id": islands.size(),
		"biome": bid, "b": b, "tier": tier,
		"name": Biomes.island_name(rng, b),
		"center": spot, "radius": r,
		"cells": [], "rim": [], "surface": [],
		"area": null, "sites": [], "charted": tier == 0,
	}

## Somewhere inside a given ring that is far enough from everything already down.
func _find_spot_in_ring(r: int, tier: int, placed: Array) -> Vector2i:
	var lo: float = 0.0 if tier == 0 else RINGS[tier - 1]
	var hi: float = RINGS[tier] if tier < RINGS.size() else float(mini(W, H)) * 0.5 - MARGIN - float(r)
	lo = maxf(lo, 44.0) # never inside the home island's own approaches
	if hi <= lo + 6.0:
		hi = lo + 26.0
	for _try in 400:
		var ang := rng.randf() * TAU
		var dist := lerpf(lo, hi, sqrt(rng.randf())) # even area coverage, not even radius
		var c := hub_center + Vector2i(Vector2(cos(ang), sin(ang)) * dist)
		if c.x < MARGIN + r or c.y < MARGIN + r or c.x >= W - MARGIN - r or c.y >= H - MARGIN - r:
			continue
		var ok := true
		for pl in placed:
			# keep a channel of open sky between islands: wide enough to fly a ship through
			var need: float = float(r) + float(pl["r"]) + 13.0
			if Vector2(c - pl["c"]).length() < need:
				ok = false
				break
		if ok:
			return c
	return Vector2i(-1, -1)

## Grow one island: several overlapping lobes, their combined field warped by noise and
## thresholded. Then keep only the biggest connected piece so we never ship an island
## with a detached crumb floating beside it.
func _paint_island(isl: Dictionary) -> void:
	var c: Vector2i = isl["center"]
	var r: int = isl["radius"]
	var lobes := []
	lobes.append({"c": Vector2(c), "r": float(r) * rng.randf_range(0.62, 0.8)})
	for _i in rng.randi_range(2, 5):
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(0.2, 0.62) * r
		lobes.append({"c": Vector2(c) + Vector2(cos(ang), sin(ang)) * dist,
			"r": float(r) * rng.randf_range(0.34, 0.66)})
	var got := []
	var pad := r + 3
	for y in range(c.y - pad, c.y + pad + 1):
		for x in range(c.x - pad, c.x + pad + 1):
			var p := Vector2i(x, y)
			if not map.inb(p) or p.x < 3 or p.y < 3 or p.x >= W - 3 or p.y >= H - 3:
				continue
			if _land.has(p):
				continue
			var f := 0.0
			for L in lobes:
				var d: float = Vector2(p).distance_to(L["c"]) / maxf(1.0, L["r"])
				f = maxf(f, 1.0 - d)
			if f <= 0.0:
				continue
			# ragged coast: low-frequency warp for the big bays, detail for the fringe
			f += warp.get_noise_2d(x, y) * 0.34 + detail.get_noise_2d(x, y) * 0.10
			if f > 0.34:
				got.append(p)
	got = _largest_component(got)
	if got.size() < 14:
		islands.erase(isl)
		return
	var b: Dictionary = isl["b"]
	var area := map.new_area("%s (%s)" % [isl["name"], b["name"]], "civilian")
	area.outdoor = true
	area.room_kind = "island"
	isl["area"] = area
	var minp: Vector2i = got[0]
	var maxp: Vector2i = got[0]
	for p in got:
		var i := map.idx(p)
		var n1 := (patch.get_noise_2d(p.x * 1.0, p.y * 1.0) + 1.0) * 0.5
		var n2 := (detail.get_noise_2d(p.x * 1.6, p.y * 1.6) + 1.0) * 0.5
		map.turf[i] = Biomes.ground_turf(b, n1, n2)
		map.variant[i] = absi(hash(p)) % 8
		map.turf_hp[i] = 100.0
		map.area[i] = area.id
		area.cells.append(p)
		_land[p] = isl["id"]
		minp = Vector2i(mini(minp.x, p.x), mini(minp.y, p.y))
		maxp = Vector2i(maxi(maxp.x, p.x), maxi(maxp.y, p.y))
	isl["cells"] = got
	isl["rect"] = Rect2i(minp, maxp - minp + Vector2i.ONE)
	area.center = _pick_interior(isl)
	# the coast: land that looks out over open sky
	var rim := []
	for p in got:
		for d in Defs.DIRS4:
			if not _land.has(p + d):
				rim.append(p)
				break
	isl["rim"] = rim
	# a lip of the biome's edge turf all the way round, so coasts read as coasts
	var edge_t: int = b["edge"]
	for p in rim:
		if (map.tflags(p) & Defs.F_LIQUID) == 0:
			map.turf[map.idx(p)] = edge_t

func _largest_component(cells: Array) -> Array:
	var set := {}
	for p in cells:
		set[p] = true
	var best := []
	var seen := {}
	for p in cells:
		if seen.has(p):
			continue
		var comp := []
		var q := [p]
		seen[p] = true
		while not q.is_empty():
			var cur: Vector2i = q.pop_back()
			comp.append(cur)
			for d in Defs.DIRS4:
				var nc: Vector2i = cur + d
				if set.has(nc) and not seen.has(nc):
					seen[nc] = true
					q.append(nc)
		if comp.size() > best.size():
			best = comp
	return best

# ------------------------------------------------------------------ rock and ore
## An island's spine. High ground becomes solid rock you have to mine or walk around,
## and the rock carries the biome's ore veins. Rock is kept off the coast so there is
## always a walkable shelf round the outside.
func _rock_and_ore(isl: Dictionary) -> void:
	var b: Dictionary = isl["b"]
	var rim := {}
	for p in isl["rim"]:
		rim[p] = true
	# distance from the coast, so we can hold rock back from the edge
	var dist := _coast_distance(isl, rim)
	var rock: int = b["rock"]
	var ores: Array = b["ores"]
	var spine := _noise(rng.randi(), 0.075, 3)
	var rocks := []
	for p in isl["cells"]:
		var d: int = dist.get(p, 0)
		if d < 2:
			continue
		var v := spine.get_noise_2d(p.x, p.y)
		# bias toward the middle so the spine runs through the island's mass
		v += clampf(float(d) / 9.0, 0.0, 0.5) * 0.45
		if v > 0.52:
			rocks.append(p)
	# no single-tile pillars: rock needs a neighbour to look like an outcrop
	var rset := {}
	for p in rocks:
		rset[p] = true
	for p in rocks:
		var n := 0
		for d in Defs.DIRS4:
			if rset.has(p + d):
				n += 1
		if n == 0:
			continue
		var i := map.idx(p)
		map.turf[i] = rock
		map.turf_hp[i] = float(Defs.TURFS[rock].get("hp", 60))
		isl["surface"].append(null) # placeholder, recomputed below
	isl["surface"].clear()
	# ore veins: short worms through the rock
	var rock_cells := []
	for p in isl["cells"]:
		if map.is_rock(p):
			rock_cells.append(p)
	var veins := int(maxf(1.0, rock_cells.size() / 26.0))
	for _v in veins:
		if rock_cells.is_empty():
			break
		var ore = Biomes.weighted(ores, rng)
		if ore == null:
			break
		var at: Vector2i = rock_cells[rng.randi() % rock_cells.size()]
		var len_v := rng.randi_range(3, 9)
		var dir: Vector2i = Defs.DIRS8[rng.randi() % 8]
		for _s in len_v:
			if map.inb(at) and map.is_rock(at):
				var i := map.idx(at)
				map.turf[i] = int(ore)
				map.turf_hp[i] = float(Defs.TURFS[int(ore)].get("hp", 70))
			if rng.randf() < 0.3:
				dir = Defs.DIRS8[rng.randi() % 8]
			at += dir
	# walkable surface list, for placing things later
	for p in isl["cells"]:
		if not map.is_solid_turf(p) and (map.tflags(p) & Defs.F_LIQUID) == 0:
			isl["surface"].append(p)

## BFS outward from the coast: how many tiles inland is each cell?
func _coast_distance(isl: Dictionary, rim: Dictionary) -> Dictionary:
	var dist := {}
	var q := []
	for p in rim.keys():
		dist[p] = 0
		q.append(p)
	var head := 0
	var own := {}
	for p in isl["cells"]:
		own[p] = true
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		var nd: int = dist[cur] + 1
		for d in Defs.DIRS4:
			var nc: Vector2i = cur + d
			if own.has(nc) and not dist.has(nc):
				dist[nc] = nd
				q.append(nc)
	return dist

# ------------------------------------------------------------------ water
## Pools collect in hollows. On a floating island they are perched, which is unsettling
## if you think about it, so the game does not invite you to.
func _water(isl: Dictionary) -> void:
	var b: Dictionary = isl["b"]
	var chance := float(b["water"])
	if chance <= 0.01:
		return
	var hollow := _noise(rng.randi(), 0.09, 2)
	var rim := {}
	for p in isl["rim"]:
		rim[p] = true
	var dist := _coast_distance(isl, rim)
	for p in isl["cells"]:
		if map.is_solid_turf(p) or dist.get(p, 0) < 2:
			continue
		var v := (hollow.get_noise_2d(p.x, p.y) + 1.0) * 0.5
		if v < chance * 0.34:
			map.turf[map.idx(p)] = Defs.T_WATER
	# recompute the dry surface list
	var surf := []
	for p in isl["cells"]:
		if not map.is_solid_turf(p) and (map.tflags(p) & Defs.F_LIQUID) == 0:
			surf.append(p)
	isl["surface"] = surf

# ------------------------------------------------------------------ life
func _flora(isl: Dictionary) -> void:
	var b: Dictionary = isl["b"]
	var surf: Array = isl["surface"]
	if surf.is_empty():
		return
	var scale := float(surf.size()) / 100.0 * float(b["density"])
	for row in b["flora"]:
		var proto: String = row[0]
		if not Proto.has(proto):
			continue
		var n := int(round(float(row[1]) * scale))
		for _i in n:
			var p: Vector2i = surf[rng.randi() % surf.size()]
			if not _clear_for_prop(p):
				continue
			Proto.spawn(proto, p)

func _clear_for_prop(p: Vector2i) -> bool:
	if not map.inb(p) or map.is_solid_turf(p):
		return false
	if (map.tflags(p) & Defs.F_LIQUID) != 0:
		return false
	for e in Game.at(p):
		if e.has_c(&"blocker") or e.has_c(&"furniture"):
			return false
	return true

## Fauna are recorded rather than spawned, so the boot sequence can decide how much of
## the region is awake at once (and so night-only creatures can arrive at dusk).
func _fauna(isl: Dictionary) -> void:
	var b: Dictionary = isl["b"]
	var surf: Array = isl["surface"]
	if surf.is_empty():
		return
	var tier: int = int(isl.get("tier", 1))
	# the home island is deliberately almost empty of anything that bites: the first thing
	# a new player should do is look around, not be eaten on a beach
	var crowd := 0.5 + float(b["hazard"])
	if isl.get("home", false) or tier == 0:
		crowd *= 0.55
	var n := int(round(float(surf.size()) / 30.0 * crowd))
	n = clampi(n, 1, 26)
	var power := Biomes.ring_power(tier)
	for _i in n:
		var mob = Biomes.weighted(b["fauna"], rng)
		if mob == null:
			continue
		mob_spawns.append({"cell": surf[rng.randi() % surf.size()], "mob": mob,
			"island": isl["id"], "night": false, "tier": tier, "power": power})
	for _i in int(n * 0.5):
		var mob2 = Biomes.weighted(b["night"], rng)
		if mob2 == null:
			continue
		mob_spawns.append({"cell": surf[rng.randi() % surf.size()], "mob": mob2,
			"island": isl["id"], "night": true, "tier": tier, "power": power})

# ------------------------------------------------------------------ home
## The player's island: the biggest gentle one we can find, so the first ten minutes are
## not a fight for your life.
func _choose_home() -> void:
	# the middle island, which was placed for the purpose. If the noise ate it — a real
	# possibility, since every island is thresholded — fall back to the kindest big one.
	var best: Dictionary = {}
	var best_score := -1e9
	for isl in islands:
		if isl["surface"].is_empty():
			continue
		var b: Dictionary = isl["b"]
		var near := Vector2(isl["center"] - hub_center).length()
		var score := float(isl["surface"].size()) * (1.2 - float(b["hazard"])) - near * 9.0
		if score > best_score:
			best_score = score
			best = isl
	if best.is_empty():
		return
	home = best
	best["home"] = true
	best["tier"] = 0
	best["charted"] = true
	# Whatever the noise did to the island we meant to be home, the one that ends up
	# carrying Port Meridian is a kindly one. A capital built on a Vergegloom isle would
	# be lightless, airless and -28 C, and the first thing a new player would do is die
	# of it on the quay.
	if float(best["b"]["hazard"]) > 0.2 or float(best["b"]["temp"]) < -6.0 or not (best["b"]["gas"] as Array).is_empty():
		best["biome"] = Biomes.B_HEARTHMOSS
		best["b"] = Biomes.get_b(Biomes.B_HEARTHMOSS)
	best["name"] = "Meridian"
	best["area"].name = "Port Meridian"
	hub_center = best["area"].center
	# every island's ring is measured from wherever the port actually ended up
	for isl in islands:
		if isl.get("home", false):
			continue
		isl["tier"] = tier_at(isl["center"])

func _pick_interior(isl: Dictionary) -> Vector2i:
	var cells: Array = isl["cells"]
	if cells.is_empty():
		return isl["center"]
	var sum := Vector2.ZERO
	for p in cells:
		sum += Vector2(p)
	var avg := sum / float(cells.size())
	var best: Vector2i = cells[0]
	var bd := 1e9
	for p in cells:
		var d := Vector2(p).distance_squared_to(avg)
		if d < bd:
			bd = d
			best = p
	return best

# ------------------------------------------------------------------ moorings
## Somewhere to tie up: a stretch of coast with clear sky in front of it, long enough to
## lay an airship alongside. Every island gets at least one if its shape allows.
func _mooring_points() -> void:
	for isl in islands:
		var found := _find_mooring(isl)
		if not found.is_empty():
			found["island"] = isl["id"]
			moorings.append(found)
			isl["mooring"] = found
	var berth: Dictionary = home.get("mooring", {}) if not home.is_empty() else {}
	if berth.is_empty() and not moorings.is_empty():
		berth = moorings[0]
	if berth.is_empty():
		ship_start = Vector2i(W / 2, H / 2)
		ship_start_dir = Vector2i.RIGHT
		return
	ship_start = berth["cell"]
	ship_start_dir = berth["dir"]

## Look along the coast for a run of `span` rim tiles that all face the same way, with
## `depth` tiles of nothing but sky beyond them.
func _find_mooring(isl: Dictionary, span := 15, depth := 11) -> Dictionary:
	var rim: Array = isl["rim"]
	if rim.is_empty():
		return {}
	# Testing every rim tile against a 15-wide flank is about a hundred thousand map
	# lookups per island, and there are fifty islands. Sample the coast instead and stop
	# once a handful of berths have been found: a ship needs one, not all of them.
	var pool := rim.duplicate()
	pool.shuffle()
	if pool.size() > 120:
		pool.resize(120)
	var candidates := []
	for p in pool:
		if map.is_solid_turf(p):
			continue
		for d in Defs.DIRS4:
			if _clear_run(p, d, depth) and _clear_flank(p, d, span, depth):
				candidates.append({"cell": p, "dir": d})
				break
		if candidates.size() >= 6:
			break
	if candidates.is_empty():
		# relax, in stages, rather than giving up: a cramped berth still beats none
		for relax in [[11, 9], [9, 8], [7, 7], [5, 6]]:
			for p in pool:
				if map.is_solid_turf(p):
					continue
				for d in Defs.DIRS4:
					if _clear_run(p, d, relax[1]) and _clear_flank(p, d, relax[0], relax[1]):
						return {"cell": p, "dir": d}
		return {}
	return candidates[rng.randi() % candidates.size()]

func _clear_run(p: Vector2i, d: Vector2i, depth: int) -> bool:
	for k in range(1, depth + 1):
		var c: Vector2i = p + d * k
		if not map.inb(c) or not Defs.is_void_turf(map.get_turf(c)):
			return false
	return true

func _clear_flank(p: Vector2i, d: Vector2i, span: int, depth: int) -> bool:
	var side := Vector2i(d.y, d.x)
	var half := span / 2
	for s in range(-half, half + 1):
		if not _clear_run(p + side * s, d, depth):
			return false
	return true

# ------------------------------------------------------------------ ports
## Which islands carry somebody selling something. A port needs a mooring, a bit of flat
## ground and a reason to exist, and there are fewer of them the further out you go —
## which is what makes a far port worth knowing about and worth flying back to.
func _choose_ports() -> void:
	ports.clear()
	var per_ring := [1, 3, 3, 2, 1]
	var by_ring := {}
	for isl in islands:
		if isl.get("home", false) or not isl.has("mooring"):
			continue
		if isl["surface"].size() < 70:
			continue
		var t: int = int(isl.get("tier", 1))
		if not by_ring.has(t):
			by_ring[t] = []
		by_ring[t].append(isl)
	for tier in 5:
		var pool: Array = by_ring.get(tier, [])
		pool.shuffle()
		for i in mini(per_ring[tier], pool.size()):
			var isl: Dictionary = pool[i]
			isl["port"] = true
			isl["port_tier"] = clampi(tier, 0, 4)
			isl["charted"] = true
			isl["name"] = "%s %s" % [isl["name"], ["Landing", "Anchorage", "Quay", "Stand", "Perch"][rng.randi() % 5]]
			isl["area"].name = isl["name"]
			ports.append(isl)
			Hub.build_outport(self, isl)

# ------------------------------------------------------------------ helpers used by Sites
func island_at(c: Vector2i) -> Dictionary:
	var id = _land.get(c)
	if id == null:
		return {}
	for isl in islands:
		if isl["id"] == id:
			return isl
	return {}

func is_land(c: Vector2i) -> bool:
	return _land.has(c)

func free_surface(isl: Dictionary, avoid_rim := 2) -> Vector2i:
	var surf: Array = isl["surface"]
	if surf.is_empty():
		return Vector2i(-1, -1)
	var rim := {}
	for p in isl["rim"]:
		rim[p] = true
	for _try in 120:
		var p: Vector2i = surf[rng.randi() % surf.size()]
		if avoid_rim > 0 and _near_rim(p, rim, avoid_rim):
			continue
		if _clear_for_prop(p):
			return p
	return Vector2i(-1, -1)

func _near_rim(p: Vector2i, rim: Dictionary, r: int) -> bool:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if rim.has(p + Vector2i(x, y)):
				return true
	return false

## A flat, land-locked rectangle inside an island, for stamping a structure into.
func find_flat(isl: Dictionary, w: int, h: int, tries := 260) -> Vector2i:
	var surf: Array = isl["surface"]
	if surf.is_empty():
		return Vector2i(-1, -1)
	for _try in tries:
		var o: Vector2i = surf[rng.randi() % surf.size()]
		if _rect_ok(o, w, h):
			return o
	return Vector2i(-1, -1)

func _rect_ok(o: Vector2i, w: int, h: int) -> bool:
	for y in range(o.y - 1, o.y + h + 1):
		for x in range(o.x - 1, o.x + w + 1):
			var c := Vector2i(x, y)
			if not map.inb(c) or not _land.has(c):
				return false
			if map.is_solid_turf(c):
				return false
			if (map.tflags(c) & Defs.F_LIQUID) != 0:
				return false
	for y in range(o.y, o.y + h):
		for x in range(o.x, o.x + w):
			for e in Game.at(Vector2i(x, y)):
				if e.has_c(&"blocker"):
					return false
	return true

func report() -> String:
	var lines := ["Sky region: %s (altitude %.1f km, %.0f kPa outside, %.0f C)  %dx%d" % [
		region_name, altitude,
		Defs.sky_moles(altitude) * Defs.R_IDEAL * Defs.sky_temp(altitude) / Defs.CELL_VOLUME,
		Defs.sky_temp(altitude) - Defs.T0C, W, H]]
	var by_ring := [0, 0, 0, 0, 0]
	for isl in islands:
		by_ring[clampi(int(isl.get("tier", 0)), 0, 4)] += 1
	for t in 5:
		lines.append("  %-16s %2d islands" % [Biomes.ring_name(t), by_ring[t]])
	var stage := []
	for row in timings:
		stage.append("%s %dms" % [row[0], row[1]])
	lines.append("  generation: " + "  ".join(stage))
	var shown := islands.duplicate()
	shown.sort_custom(func(a, b): return int(a.get("tier", 0)) < int(b.get("tier", 0)))
	for isl in shown:
		lines.append("  %-24s %-12s ring %d  %4d tiles%s%s%s" % [isl["name"], isl["b"]["name"],
			int(isl.get("tier", 0)), isl["cells"].size(),
			"  HOME" if isl.get("home", false) else "",
			"  PORT" if isl.get("port", false) else "",
			("  sites: " + ", ".join(isl["sites"])) if not isl["sites"].is_empty() else ""])
	return "\n".join(lines)
