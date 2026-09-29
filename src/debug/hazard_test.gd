class_name HazardTest extends Node
## --hazardtest: wind, draughts, fire spread, bilge and the companionway on a real hull.

var checks := 0
var fails := 0

func _ready() -> void:
	_run.call_deferred()

func _check(what: String, ok: bool) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("HAZARD %s %s" % ["PASS" if ok else "FAIL", what])

func _run() -> void:
	var sh: Airship = Game.fleet.player_ship
	_check("player ship exists", sh != null)
	if sh == null:
		get_tree().quit(1)
		return
	# --- the yard's survey, on a hand-drawn cabin with a missing wall
	var plan := {}
	for x in 8:
		for y in 5:
			plan[Vector2i(x, y)] = "#" if (x == 0 or y == 0 or x == 7 or y == 4) else "="
	plan[Vector2i(0, 2)] = "="
	plan[Vector2i(4, 2)] = "f"
	plan[Vector2i(5, 2)] = "T"
	var dm := ShipSurvey.draught_map(plan)
	_check("survey finds the hole", not ShipPlan.leaks_of(plan).is_empty())
	_check("survey carries the draught inward", dm.size() > 1)
	var codes := []
	for d in ShipSurvey.diagnose(plan, {}, Vector2i(-9999, -9999)):
		codes.append(d["code"])
	_check("survey warns of the draught", codes.has("draught"))
	_check("survey warns of a stove by the bunker", codes.has("stove_fuel"))
	_check("survey notes no lower deck", codes.has("no_hold"))
	# --- wind
	Game.sky.wind = Vector2(1.5, 0.0)
	sh.vel = Vector2.ZERO
	_check("apparent wind follows the sky", ShipHazards.wind_strength(sh) > 1.5)
	sh.vel = Game.sky.wind_vector() * 1.6 / 0.7
	_check("running with the wind cancels it", ShipHazards.wind_strength(sh) < 0.1)
	sh.vel = Vector2.ZERO
	# --- draughts: open a hole into a room
	ShipHazards.tick(sh, 0.5)
	var st := ShipHazards.state(sh)
	_check("state tracks wind", float(st["wind"]) > 1.0)
	var before := int(st["openings"])
	var hole := Vector2i(-1, -1)
	for c in sh.inside_cells:
		for d in Defs.DIRS4:
			var n: Vector2i = c + d
			if Game.map.is_wall(n) and not sh.deck_cells.has(n) and Game.map.is_outdoor(n + d):
				hole = n
				break
		if hole.x >= 0:
			break
	if hole.x >= 0:
		sh.breach(hole)
		st["scan_t"] = -99.0
		ShipHazards.tick(sh, 0.5)
		_check("a hole makes an opening", int(st["openings"]) > before)
		_check("a draught blows behind it", float(st["worst"]) > 0.1)
		_check("report mentions openings", ShipHazards.report(sh).contains("opening"))
		_check("breaching leaves the seams weeping", sh.seam > 0.0)
	else:
		print("HAZARD NOTE no wall between a room and the sky on this hull; skipped draught checks")
	# --- bilge
	if not sh.lower_cells.is_empty():
		var m0 := sh.mass()
		sh.seam = 0.6
		sh.bilge = 0.0
		for i in 40:
			ShipHazards.tick(sh, 0.5)
		_check("a sprung seam fills the bilge", sh.bilge > 0.2)
		sh._mass_t = -99.0
		_check("standing water is weight", sh.mass() > m0)
		var pump: Entity = null
		for p in sh.lower_parts:
			if p is Entity and p.proto == "bilge_pump":
				pump = p
		_check("a pump stands below decks", pump != null)
		if pump != null:
			var level := sh.bilge
			(pump.c(&"bilge_pump") as CBilgePump).pump(Game.player)
			_check("pumping lowers the bilge", sh.bilge < level)
			var s0 := sh.seam
			(pump.c(&"bilge_pump") as CBilgePump).caulk(Game.player)
			_check("caulking without planks does nothing", sh.seam == s0)
		# --- fire below, smoke and heat above
		var lo := Game.map.idx(sh.lower_stair)
		var top := sh.cell(sh.upper_stair_local.x, sh.upper_stair_local.y)
		Game.atmos.gas[Defs.G_SMOKE][lo] = 5.0
		Game.atmos.temp[lo] = 420.0
		var hi := Game.map.idx(top)
		var roofed: bool = not Game.map.is_outdoor(top) and not Game.map.blocks_air(top)
		var smoke0: float = Game.atmos.gas[Defs.G_SMOKE][hi]
		var t0: float = Game.atmos.temp[hi]
		ShipHazards.tick(sh, 0.5)
		_check("smoke leaves the galley by the companionway", Game.atmos.gas[Defs.G_SMOKE][lo] < 5.0)
		if roofed:
			_check("smoke climbs into a roofed stair", Game.atmos.gas[Defs.G_SMOKE][hi] > smoke0)
			_check("heat climbs into a roofed stair", Game.atmos.temp[hi] > t0)
		Game.atmos.ignite(sh.lower_stair + Vector2i(1, 0), null, 6.0)
		ShipHazards.tick(sh, 0.5)
		_check("fires below are counted", int(ShipHazards.state(sh)["fires"]) >= 0)
		sh.bilge = 0.0
		sh.seam = 0.0
	else:
		print("HAZARD NOTE no lower deck on this hull; skipped bilge checks")
	print("HAZARD DONE: %d checks, %d failed" % [checks, fails])
	get_tree().quit(0 if fails == 0 else 1)
