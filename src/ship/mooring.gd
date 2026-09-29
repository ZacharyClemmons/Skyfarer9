class_name Mooring extends RefCounted
## Where a hull is laid down beside a quay so that a person can actually walk aboard.
##
## The old rule ("lie her alongside the berth cell, one tile off, and if she does not fit walk
## her out to sea") ignored that a coast is ragged: the hull ended up two, four, twenty tiles
## from the rock, or nose-in to it, with nothing to walk across. This searches for a berth
## instead. Every candidate is scored with the rules the player is actually moved by
## (CMob.try_step and Climb): open ground you can stand on, and a chest-high rail you can climb
## when there is somewhere to land beyond it. A hull is only ever offered a berth from which
## a walk exists from the quay onto her deck, and the closest such berth wins.
##
## `plan()` touches nothing; it only reads the map. It returns {} when there is no berth,
## and the caller must then refuse (and refund) rather than strand her in the sky.

const MAX_WALK := 40        ## a berth further than this many steps from the quay is no berth
const MAX_OUT := 19         ## how far off the coast we will go looking
const ALONG_SPAN := 14      ## how far along the coast we will slide her
const NONE := Vector2i(-9999, -9999)

## Could a person stand on this cell (the same tests CMob.try_step applies)?
static func standable(c: Vector2i) -> bool:
	var map := Game.map
	if map == null or not map.inb(c):
		return false
	if map.blocks_move_static(c) or map.dense_count[map.idx(c)] > 0:
		return false
	return Falling.supported(c)

## Glyphs whose tile a person can walk over once stamped: plating, deck, cabin floor, a door, a
## hatch, a medical bunk. Deliberately a short list. Anything else is treated as solid, so a
## berth is never chosen on the strength of a fitting that turns out to be in the way.
## `--boardtest` checks this list against the real stamped tiles.
const WALKABLE_GLYPHS := [".", ",", "=", "+", "A", "M"]

static func is_blocked_glyph(ch: String) -> bool:
	return not (ch in WALKABLE_GLYPHS)

## `berth` is the coast cell the yard lays hulls down at, `out` points from it into open sky.
## Returns {"origin": Vector2i, "dir": int, "walk": steps from the quay to the deck, "off": tiles
## between the nearest rock and the hull} or {}.
static func plan(cells_map: Dictionary, berth: Vector2i, out: Vector2i) -> Dictionary:
	var map := Game.map
	if map == null or cells_map.is_empty():
		return {}
	var along := Vector2i(out.y, -out.x)
	var stand := _stand_near(berth, out)
	if stand == NONE:
		return {}
	var flood := _flood(stand)

	# what each local cell is, as a walker meets it: 1 you can stand there, 2 a rail you can
	# climb, anything else a solid thing. Mirrors Airship._lay_terrain and ShipPlan.DENSE.
	var kind := {}
	for k in cells_map:
		var ch: String = cells_map[k]
		if ShipPlan.is_wall(ch):
			kind[k] = 2
		elif is_blocked_glyph(ch):
			kind[k] = 3
		else:
			kind[k] = 1
	# she is boarded onto her main deck, not a cubby that happens to touch the rock
	var goal := _largest_standable(kind)
	if goal.is_empty():
		return {}

	var facings: Array = []
	for v in [along, -along, out, -out]:
		facings.append(Defs.dir_from_vec(v))
	for g in range(0, MAX_OUT + 1):
		var best := {}
		var best_cost := 1 << 30
		for f in facings:
			var fwd: Vector2i = Defs.DIRS4[f]
			var stbd := Vector2i(-fwd.y, fwd.x)
			# where the hull lies with her origin at (0, 0): used to centre her on the berth
			var lo_out := 1 << 30
			var lo_a := 1 << 30
			var hi_a := -(1 << 30)
			for k in cells_map:
				var w: Vector2i = fwd * k.x + stbd * k.y
				lo_out = mini(lo_out, w.x * out.x + w.y * out.y)
				var a := w.x * along.x + w.y * along.y
				lo_a = mini(lo_a, a)
				hi_a = maxi(hi_a, a)
			var mid_a := (lo_a + hi_a) / 2
			var base_out := berth.x * out.x + berth.y * out.y
			var base_a := berth.x * along.x + berth.y * along.y
			for slide in _slides():
				var origin: Vector2i = out * (base_out + 1 + g - lo_out) + along * (base_a + slide - mid_a)
				var cost := _score(cells_map, kind, goal, origin, f, flood)
				if cost < 0:
					continue
				cost = cost * 64 + absi(slide)
				if cost < best_cost:
					best_cost = cost
					best = {"origin": origin, "dir": f, "walk": cost / 64, "off": g}
		if not best.is_empty():
			return best
	return {}

## 0, +1, -1, +2, -2 ... so the tidiest berth wins a tie.
static func _slides() -> Array:
	var out := [0]
	for i in range(1, ALONG_SPAN + 1):
		out.append(i)
		out.append(-i)
	return out

## Steps from the quay to her deck for one candidate berth, or -1 if she does not fit or there
## is no walk.
static func _score(cells_map: Dictionary, kind: Dictionary, goal: Dictionary, origin: Vector2i,
		dir: int, flood: Dictionary) -> int:
	var map := Game.map
	var fwd: Vector2i = Defs.DIRS4[dir]
	var stbd := Vector2i(-fwd.y, fwd.x)
	var world := {}
	for k in cells_map:
		var c: Vector2i = origin + fwd * k.x + stbd * k.y
		if not map.inb(c) or c.x < 1 or c.y < 1 or c.x >= map.w - 1 or c.y >= map.h - 1:
			return -1
		if not Defs.is_void_turf(map.get_turf(c)) or map.structure[map.idx(c)] != Defs.S_NONE:
			return -1
		world[c] = k
	var best := -1
	for c in world:
		var k: Vector2i = world[c]
		if not goal.has(k):
			continue
		for d in Defs.DIRS4:
			var n: Vector2i = c + d
			var cost := -1
			if world.has(n):
				if kind[world[n]] == 2:
					var n2: Vector2i = n + d
					if not world.has(n2) and flood.has(n2):
						cost = int(flood[n2]) + 2
			elif flood.has(n):
				cost = int(flood[n]) + 1
			elif map.inb(n) and Climb.climbable_turf(map.get_turf(n)):
				var n3: Vector2i = n + d
				if flood.has(n3) and not world.has(n3):
					cost = int(flood[n3]) + 2
			if cost >= 0 and (best < 0 or cost < best):
				best = cost
	return best

## The biggest 4-connected patch of floor a person could stand on, in local coordinates.
static func _largest_standable(kind: Dictionary) -> Dictionary:
	var seen := {}
	var best := {}
	for k in kind:
		if kind[k] != 1 or seen.has(k):
			continue
		var comp := {k: true}
		seen[k] = true
		var q := [k]
		var head := 0
		while head < q.size():
			var a: Vector2i = q[head]
			head += 1
			for d in Defs.DIRS4:
				var n: Vector2i = a + d
				if kind.get(n, 0) == 1 and not seen.has(n):
					seen[n] = true
					comp[n] = true
					q.append(n)
		if comp.size() > best.size():
			best = comp
	return best

## A cell to walk from: the berth itself or the nearest ground behind it.
static func _stand_near(berth: Vector2i, out: Vector2i) -> Vector2i:
	for r in range(0, 8):
		for k in range(0, r + 1):
			for s in [0, 1, -1]:
				var c: Vector2i = berth - out * (r - k) + Vector2i(out.y, -out.x) * (k * s)
				if standable(c):
					return c
	return NONE

## Distance in steps from `from` to every cell reachable on foot (rails climbed as CMob does).
static func _flood(from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var q := [from]
	var head := 0
	var map := Game.map
	while head < q.size():
		var a: Vector2i = q[head]
		head += 1
		var da: int = dist[a]
		if da >= MAX_WALK:
			continue
		for d in Defs.DIRS4:
			var t: Vector2i = a + d
			if not map.inb(t):
				continue
			if standable(t):
				if not dist.has(t):
					dist[t] = da + 1
					q.append(t)
			elif Climb.climbable_turf(map.get_turf(t)):
				var l: Vector2i = t + d
				if standable(l) and not dist.has(l):
					dist[l] = da + 2
					q.append(l)
	return dist
