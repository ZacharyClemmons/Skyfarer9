class_name BoardTest extends Node
## --boardtest: can a player actually mount and dismount every ship the game can put at a quay?
##
## For every book hull, opened the `--ship --hull=` way AND bought at each yard (Meridian and
## the outports), and for a set of awkward drawn hulls, the ship is stamped where the game
## really stamps it and then a breadth-first search is run over the game's own walking rules
## (the same tests CMob.try_step and Climb apply: passable, not dense, supported ground, and a
## chest-high rail may be climbed when there is something to stand on beyond it):
##   * BOARD: a path exists from the quay tile the player spawns on to a tile of the ship's deck
##   * DISMOUNT: a path exists back from that deck tile to the quay tile
## The search is deliberately not "is the ship adjacent"; a ship one tile off the rock with a
## two-thick wall is adjacent and still unreachable.

var checks := 0
var fails := 0
## Drawn hulls that have no way aboard from any side (every side is a two-plank wall with
## nothing to stand on beyond the first rail), which the yard must refuse rather than launch.
const REFUSED := ["custom double planked 9x7"]
## A drawn hull can exceed the clear water alongside a particular quay.
const MAY_REFUSE := ["custom huge 25x25"]
var main: Node
var gen: SkyGen

func _ready() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool, detail := "") -> void:
	checks += 1
	if not ok:
		fails += 1
	print("BOARD %s %s%s" % ["PASS" if ok else "FAIL", label, ("  [" + detail + "]") if detail != "" else ""])

# ------------------------------------------------------------------ walking rules
func _standable(c: Vector2i) -> bool:
	var map := Game.map
	if not map.inb(c):
		return false
	if not Falling.supported(c):
		return false
	if map.blocks_move_static(c) or map.dense_count[map.idx(c)] > 0:
		# a closed door is opened by bumping it; it is not a wall
		for ent in Game.at(c):
			if ent.c(&"door") != null and not map.blocks_move_static(c):
				return true
		return false
	return true

## Every cell you can go to from `a` in one move, with the rail cell (or Vector2i(-9999,-9999)).
func _moves(a: Vector2i) -> Array:
	var out := []
	var map := Game.map
	for d in Defs.DIRS4:
		var t: Vector2i = a + d
		if not map.inb(t):
			continue
		if _standable(t):
			out.append([t, Vector2i(-9999, -9999)])
		elif Climb.climbable_turf(map.get_turf(t)):
			var l: Vector2i = t + d
			if _standable(l):
				out.append([l, t])
	return out

## Shortest walk from `from` to any cell for which `goal` is true. Returns
## {"path": [...], "climbs": n} or an empty dictionary.
func _walk(from: Vector2i, goal: Callable, radius := 80) -> Dictionary:
	var prev := {from: from}
	var via := {}
	var q := [from]
	var head := 0
	while head < q.size():
		var a: Vector2i = q[head]
		head += 1
		if goal.call(a):
			var path := [a]
			var climbs := 0
			var c: Vector2i = a
			while c != from:
				if via.has(c):
					climbs += 1
				c = prev[c]
				path.append(c)
			path.reverse()
			return {"path": path, "climbs": climbs}
		for m in _moves(a):
			var n: Vector2i = m[0]
			if prev.has(n) or maxi(absi(n.x - from.x), absi(n.y - from.y)) > radius:
				continue
			prev[n] = a
			if m[1].x > -9000:
				via[n] = m[1]
			q.append(n)
	return {}

# ------------------------------------------------------------------ fixtures
func _quay_start(isl: Dictionary) -> Vector2i:
	if not isl.has("quay"):
		return Vector2i(-9999, -9999)
	var q: Dictionary = isl["quay"]
	var at: Vector2i = q["cell"]
	var along: Vector2i = q["along"]
	var out: Vector2i = q["dir"]
	for k in range(0, 12):
		for side in [1, -1]:
			var c: Vector2i = at + along * (k * side) - out
			if Game.map.is_passable(c) and Game.at(c).is_empty() and Falling.supported(c):
				return c
	return Vector2i(-9999, -9999)

func _shape(rows: Array, keel: int) -> Dictionary:
	return ShipPlan.to_cells(rows, keel)

func _rect(w: int, h: int, edge := "#", fill := ".") -> Array:
	var rows := []
	for y in h:
		var s := ""
		for x in w:
			s += edge if (x == 0 or y == 0 or x == w - 1 or y == h - 1) else fill
		rows.append(s)
	return rows

## The awkward drawn hulls. cells are local (u, v) exactly as the drawing board keeps them.
func _custom_shapes() -> Dictionary:
	var out := {}
	var skiff := ShipPlan.get_hull("skiff")
	var base := ShipPlan.to_cells(skiff["plan"], int(skiff["keel"]))
	out["tiny 5x3"] = _shape(_rect(5, 3), 1)
	out["one cell"] = {Vector2i(0, 0): "."}
	var lp := _rect(41, 3)
	out["very long 41x3"] = _shape(lp, 1)
	out["very wide 9x25"] = _shape(_rect(9, 25), 12)
	out["huge 25x25"] = _shape(_rect(25, 25), 12)
	out["bare platform 9x5"] = _shape(_rect(9, 5, ".", "."), 2)
	var spur_p: Dictionary = base.duplicate()
	for i in range(1, 9):
		spur_p[Vector2i(0, -3 - i)] = "="
	out["skiff + 8 spur to port"] = spur_p
	var spur_s: Dictionary = base.duplicate()
	for i in range(1, 9):
		spur_s[Vector2i(0, 3 + i)] = "="
	out["skiff + 8 spur to starboard"] = spur_s
	var bowsprit: Dictionary = base.duplicate()
	for i in range(1, 12):
		bowsprit[Vector2i(6 + i, 0)] = "#"
	out["skiff + 11 bowsprit"] = bowsprit
	var far: Dictionary = {}
	for k in base:
		far[k + Vector2i(14, 9)] = base[k]
	out["skiff drawn far off-centre (+14,+9)"] = far
	var far2: Dictionary = {}
	for k in base:
		far2[k + Vector2i(-20, -8)] = base[k]
	out["skiff drawn far off-centre (-20,-8)"] = far2
	var two: Dictionary = {}
	for k in base:
		two[k] = base[k]
		two[k + Vector2i(0, 12)] = base[k]
	out["two skiffs abreast"] = two
	out["double planked 9x7"] = _shape(["#########", "#########", "##.....##", "##.h...##", "##.....##", "#########", "#########"], 3)
	return out

# ------------------------------------------------------------------ one ship
## Board and dismount `sh` from `start`. Returns true when both work.
func _board(label: String, sh: Airship, start: Vector2i) -> bool:
	var stand_ok := _standable(start)
	var ship_cells := {}
	for c in sh.cells:
		ship_cells[c] = true
	var goal_deck := func(c: Vector2i) -> bool:
		return ship_cells.has(c) and _standable(c) and not Game.map.is_solid_turf(c)
	var res := _walk(start, goal_deck)
	if not stand_ok:
		_check("%s: player start is on walkable quay" % label, false, "start %s" % start)
		return false
	if res.is_empty():
		_dump(start, sh)
		_mismatch(sh)
		_check("%s: BOARD walk quay->deck" % label, false,
			"ship origin %s facing %d, %d cells, deck %d, no walkable path from %s" % [
				sh.origin, sh.facing, sh.cells.size(), sh.deck_cells.size(), start])
		return false
	var path: Array = res["path"]
	# the real rule for the first rail on the way, checked with the real player
	var real_ok := true
	if Game.player != null and res["climbs"] > 0:
		var keep: Vector2i = Game.player.cell
		for i in range(path.size() - 1):
			var a: Vector2i = path[i]
			var b: Vector2i = path[i + 1]
			if maxi(absi(a.x - b.x), absi(a.y - b.y)) == 2:
				Game.player.place(a)
				var rail: Vector2i = (a + b) / 2
				real_ok = Climb.can_climb(Game.player, rail)
				break
		Game.player.place(keep)
	var reach_len := path.size() - 1
	var deck: Vector2i = path[path.size() - 1]
	var back := _walk(deck, func(c: Vector2i) -> bool: return c == start)
	var gap := 999
	for c in sh.cells:
		gap = mini(gap, absi(c.x - start.x) + absi(c.y - start.y))
	var ok := real_ok and not back.is_empty()
	_check("%s: BOARD+DISMOUNT" % label, ok,
		"origin %s, %d steps on, %d rail climbs, %d steps back, nearest hull %d tiles from you%s" % [
			sh.origin, reach_len, res["climbs"], back["path"].size() - 1 if not back.is_empty() else -1, gap,
			"" if real_ok else ", Climb.can_climb REFUSED" ])
	if reach_len > 40:
		_check("%s: spawns close enough (<=40 steps)" % label, false, "%d steps" % reach_len)
		ok = false
	return ok

## ASCII map of the quay and the hull for a failing case: P you, . ground, ~ sky, # wall/rail,
## d deck, h hull rail.
func _dump(start: Vector2i, sh: Airship) -> void:
	var lo := start
	var hi := start
	for c in sh.cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	lo -= Vector2i(2, 2)
	hi += Vector2i(2, 2)
	if hi.x - lo.x > 70 or hi.y - lo.y > 50:
		return
	var own := {}
	for c in sh.cells:
		own[c] = true
	for y in range(lo.y, hi.y + 1):
		var row := ""
		for x in range(lo.x, hi.x + 1):
			var c := Vector2i(x, y)
			var ch := "?"
			if c == start:
				ch = "P"
			elif not Game.map.inb(c):
				ch = " "
			elif own.has(c):
				ch = "h" if Game.map.is_solid_turf(c) else "d"
			elif Defs.is_void_turf(Game.map.get_turf(c)):
				ch = "~"
			elif _standable(c):
				ch = "."
			else:
				ch = "#"
			row += ch
		print("BOARD MAP %s" % row)

## Where Mooring's picture of the hull (by glyph) disagrees with the stamped tiles.
func _mismatch(sh: Airship) -> void:
	var seen := {}
	for k in sh.cells_map:
		var ch: String = sh.cells_map[k]
		var c := sh.cell(k.x, k.y)
		var real := _standable(c)
		var model := not (ShipPlan.is_wall(ch) or Mooring.is_blocked_glyph(ch))
		if model and not real and not seen.has(ch):
			seen[ch] = true
			print("BOARD MISMATCH glyph '%s': model standable=%s, real standable=%s" % [ch, model, real])

## Count glyph disagreements between Mooring's model and the stamped tiles of `sh`.
func _model_errors(sh: Airship) -> Array:
	var bad := {}
	for k in sh.cells_map:
		var ch: String = sh.cells_map[k]
		if ShipPlan.is_wall(ch):
			continue
		var c := sh.cell(k.x, k.y)
		# only the unsafe direction matters: Mooring thinks she can be walked on and she cannot
		if not Mooring.is_blocked_glyph(ch) and not _standable(c):
			bad[ch] = true
	return bad.keys()

func _clear(sh: Airship) -> void:
	if sh == null:
		return
	if Game.fleet.player_ship == sh:
		Game.fleet.player_ship = null
	sh.remove()
	Game.fleet.ships.erase(sh)
	if sh.renderer != null and is_instance_valid(sh.renderer):
		sh.renderer.queue_free()
	Game.fleet.rebuild_tile_index()

# ------------------------------------------------------------------ run
func _run() -> void:
	Game.running = false
	main = get_tree().current_scene
	gen = Game.sky.gen
	var p := Game.player
	var start: Vector2i = p.cell
	_check("player spawns on the Meridian quay (walkable, supported)", _standable(start), "cell %s" % start)
	var hulls := ["skiff", "cutter", "launch", "sloop", "barque", "frigate"]

	# 1. the --ship --hull=ID opening: sky_main's own placement, and player_ship assignment
	for h in hulls:
		main.args["hull"] = h
		main.player_ship = null
		main._launch_player_ship()
		var sh: Airship = main.player_ship
		if sh == null:
			_check("--ship --hull=%s: ship placed" % h, false)
			continue
		var origin_before := sh.origin
		_check("--ship --hull=%s: assigned as player ship, arrival sequence running" % h,
			Game.fleet.player_ship == sh and sh.present and sh.arriving())
		_board("--ship --hull=%s @ Meridian" % h, sh, start)
		_check("--ship --hull=%s: arrival animation does not move the hull" % h, sh.origin == origin_before)
		_clear(sh)
	main.player_ship = null

	# 2. the yards: every book hull and every awkward drawn hull, at Meridian and the outports
	var yards := []
	for de in Game.all_with(&"shipyard"):
		yards.append(de.c(&"shipyard"))
	_check("at least one shipyard exists", yards.size() >= 1, "%d yards" % yards.size())
	var shapes: Dictionary = {}
	for h in hulls:
		var hd := ShipPlan.get_hull(h)
		shapes["book " + h] = ShipPlan.to_cells(hd["plan"], int(hd["keel"]))
	var custom := _custom_shapes()
	for k in custom:
		shapes["custom " + k] = custom[k]
	for y in yards:
		var isl: Dictionary = gen.island_at(y.berth)
		if isl.is_empty():
			isl = gen.island_at(y.e.cell)
		var st: Vector2i = start if (isl.get("hub", false)) else _quay_start(isl)
		var where := "Meridian" if isl.get("hub", false) else String(isl.get("name", "outport"))
		if st.x < -9000:
			_check("%s: has a quay tile to stand on" % where, false)
			continue
		if not isl.get("hub", false):
			# the player is not there: what matters is the quay tile, standing is checked above
			_check("%s: quay tile is standable" % where, _standable(st), "cell %s" % st)
		for label in shapes:
			var yd := Shipyard.new()
			yd.yard = y
			yd.cells = shapes[label].duplicate(true)
			yd.fittings = Airship.default_fittings(yd.cells, 1)
			var sh := yd._stamp_custom("Test")
			yd.free()
			var tag := "%s @ %s" % [label, where]
			if sh == null:
				# refusing cleanly is acceptable only for a ship that genuinely cannot lie there;
				# it must be reported, and the buyer refunded (see Shipyard._commit_now)
				if label in REFUSED or label in MAY_REFUSE:
					_check("%s: refused cleanly (no walkable way aboard; nothing is stamped)" % tag, true)
				else:
					_check("%s: placed" % tag, false, "no berth (buyer would be refunded)")
				continue
			if label in REFUSED:
				_check("%s: was expected to be refused" % tag, false)
			var wrong := _model_errors(sh)
			_check("%s: Mooring model matches the stamped tiles" % tag, wrong.is_empty(), "glyphs %s" % [wrong])
			_board(tag, sh, st)
			_clear(sh)

	print("BOARD DONE: %d checks, %d failed" % [checks, fails])
	get_tree().quit(0 if fails == 0 else 1)
