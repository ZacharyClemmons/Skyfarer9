class_name SkyTraffic extends RefCounted
## Everybody else's ships.
##
## A sky with one hull in it is a diorama. This keeps a handful of other ships flying at
## any time, weighted by ring: traders and revenue cutters work the Home Reach and the
## Nearing, pirates thicken as you go out, and the Rim carries things that were somebody's
## ship a long time ago and are now something else.
##
## Streamed like the wildlife, for the same reason: a hull is two hundred tiles of
## terrain and a fit-out of machinery, and forty of them would cost the frame. Ships are
## spawned just outside the player's sight, live while they are near, and are quietly
## retired once they are a long way astern — unless they are *interesting*, meaning they
## have shot at you, you have shot at them, or they are a named ship somebody is paying
## for. Those are kept.

## How many hulls are airborne near the player at once, by ring.
const TRAFFIC_BY_RING = [3, 4, 4, 3, 2]
## Spawned this far out — beyond the horizon, so nothing is seen appearing.
const SPAWN_MIN := 62.0
const SPAWN_MAX := 96.0
## Retired past this, if nothing interesting has happened.
const RETIRE := 165.0
const CHECK_EVERY := 3.0

## kind -> [weight by ring 0..4], which hulls they fly, and how good their crews are.
const KINDS := {
	"trader":  {"w": [60, 46, 32, 18, 8],  "hulls": ["cutter", "launch", "barque", "sloop"], "skill": [0.2, 0.5]},
	"patrol":  {"w": [30, 24, 16, 8, 3],   "hulls": ["cutter", "sloop", "frigate"],          "skill": [0.5, 0.85]},
	"pirate":  {"w": [4, 18, 34, 46, 44],  "hulls": ["skiff", "cutter", "launch", "sloop", "frigate"], "skill": [0.25, 0.9]},
	"hermit":  {"w": [6, 12, 18, 28, 45],  "hulls": ["skiff", "launch"],                     "skill": [0.1, 0.4]},
}

## Ship names, by trade. A revenue cutter is not called the Long Answer.
const NAMES := {
	"trader": ["Marigold", "Fair Warning", "Recompense", "Wager", "Orison", "Bellwether",
		"Second Thought", "Late Again", "Salt and Duty", "Thin Excuse", "Patient Anna",
		"Ledger", "Long Haul", "Consignment", "Good Faith"],
	"patrol": ["Vigilance", "Assize", "Writ", "Meridian Watch", "Warrant", "Precedent",
		"Due Process", "Custody", "Summons"],
	"pirate": ["Black Kite", "Nine Teeth", "Gull's Mercy", "Reckoning", "Cut Line",
		"Widow's Portion", "Red Answer", "Knife Weather", "No Quarter", "Old Debt",
		"Last Argument", "Bad Lot"],
	"hermit": ["Alone", "Far Enough", "The Quiet Life", "Nobody's", "Out Of It", "Hermitage"],
}

var live: Array = []        # [{ship, ai}]
var _t := 0.0
var spawned := 0
var retired := 0

func process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = CHECK_EVERY
	if Game.player == null or Game.fleet == null or Game.sky == null or Game.sky.gen == null:
		return
	var t_r := SPerf.t0()
	_retire()
	SPerf.end("traffic.retire", t_r)
	var here := Underdecks.world_cell(Game.player)
	var tier: int = Game.sky.gen.tier_at(here)
	var want: int = TRAFFIC_BY_RING[clampi(tier, 0, 4)]
	if Reputation.hunted():
		want += 1  # the watch is looking for you, and it sends someone
	if live.size() < want and Game.rng.randf() < 0.55:
		var t := SPerf.t0()
		_spawn_near(here, tier)
		SPerf.end("traffic.spawn", t)
	# and a word on the common channel now and then, so the sky sounds occupied
	if not live.is_empty() and Game.rng.randf() < 0.07:
		var rec: Dictionary = live[Game.rng.randi() % live.size()]
		var ai: ShipAI = rec["ai"]
		if ai.order in [ShipAI.HAUL, ShipAI.PATROL, ShipAI.MOOR]:
			ai.idle_hail()

# ------------------------------------------------------------------ spawning
func _spawn_near(here: Vector2i, tier: int) -> void:
	var kind := _roll_kind(tier)
	if kind == "":
		return
	var spec: Dictionary = KINDS[kind]
	# the warrant brings cutters whatever the ring says
	if Reputation.hunted() and Game.rng.randf() < 0.4:
		kind = "patrol"
		spec = KINDS["patrol"]
	var hulls: Array = spec["hulls"]
	# further out, the bigger hulls in a kind's list become likelier
	var pick: int = mini(hulls.size() - 1, int(Game.rng.randf_range(0.0, float(hulls.size())) * (0.5 + float(tier) * 0.22)))
	var hull_id := String(hulls[pick])
	var t_s := SPerf.t0()
	var at := _clear_spot(here)
	SPerf.end("spawn.spot", t_s)
	if at.x < -9000:
		return
	var nm := _name_for(kind)
	t_s = SPerf.t0()
	var sh: Airship = Game.fleet.add_ship(hull_id, at, Game.rng.randi() % 4, nm)
	SPerf.end("spawn.add_ship", t_s)
	if sh == null:
		return
	var sk: Array = spec["skill"]
	var skill: float = lerpf(float(sk[0]), float(sk[1]), clampf(float(tier) / 4.0 + Game.rng.randf() * 0.35, 0.0, 1.0))
	var ai := ShipAI.new().setup(sh, kind, skill)
	ai.captain = Hub._person_name(Game.rng)
	# fuel, cells and a fit-out appropriate to how far out they are working
	t_s = SPerf.t0()
	_provision(sh, tier, kind)
	SPerf.end("spawn.provision", t_s)
	if kind == "trader":
		ai.cargo_value = Game.rng.randi_range(300, 900) * (1 + tier)
		ai.waypoints = _trade_route(at)
		ai.order = ShipAI.HAUL
	elif kind == "pirate":
		ai.bounty = Game.rng.randi_range(200, 700) * (1 + tier)
		ai.order = ShipAI.PATROL
	elif kind == "patrol":
		ai.order = ShipAI.PATROL
		if Reputation.hunted():
			ai.target = Game.fleet.player_ship
			ai.order = ShipAI.HUNT
	else:
		ai.order = ShipAI.MOOR
	Game.fleet.register_ai(sh, ai)
	live.append({"ship": sh, "ai": ai})
	spawned += 1

func _roll_kind(tier: int) -> String:
	var total := 0
	for k in KINDS:
		total += int(KINDS[k]["w"][clampi(tier, 0, 4)])
	if total <= 0:
		return ""
	var r := Game.rng.randi() % total
	for k in KINDS:
		r -= int(KINDS[k]["w"][clampi(tier, 0, 4)])
		if r < 0:
			return k
	return "trader"

func _name_for(kind: String) -> String:
	var pool: Array = NAMES.get(kind, NAMES["trader"])
	var nm := String(pool[Game.rng.randi() % pool.size()])
	# never two of the same name in the air at once
	for rec in live:
		if rec["ship"].ship_name == nm:
			return nm + " of " + Biomes.NAME_FIRST[Game.rng.randi() % Biomes.NAME_FIRST.size()]
	return nm

## Somewhere over the horizon with room to lay a hull down.
func _clear_spot(here: Vector2i) -> Vector2i:
	for _try in 40:
		var a := Game.rng.randf() * TAU
		var d := Game.rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		var c := here + Vector2i(Vector2(cos(a), sin(a)) * d)
		if not Game.map.inb(c) or c.x < 20 or c.y < 20 or c.x > SkyGen.W - 20 or c.y > SkyGen.H - 20:
			continue
		# needs clear sky around it, or the hull will not stamp
		var ok := true
		for y in range(-9, 10):
			for x in range(-13, 14):
				var p := c + Vector2i(x, y)
				if not Game.map.inb(p) or not Defs.is_void_turf(Game.map.get_turf(p)):
					ok = false
					break
			if not ok:
				break
		if ok:
			return c
	return Vector2i(-9999, -9999)

## Fuel, charge and a fit-out. Deep-sky ships carry better parts, which is both a reason
## to fight one and a reason not to.
func _provision(sh: Airship, tier: int, kind: String) -> void:
	for b in sh.bunkers:
		var fb: CFuelBunker = b.c(&"fuelbunker")
		if fb != null:
			fb.amount = fb.capacity * Game.rng.randf_range(0.5, 1.0)
	for l in sh.lift_cells:
		var lc: CLiftCell = l.c(&"liftcell")
		if lc != null:
			lc.charge = Game.rng.randf_range(0.85, 1.0)
	# upgrade a few fittings, by ring
	var grade := clampi(tier - 1 + (1 if kind == "patrol" else 0), 0, 3)
	if grade <= 0:
		return
	var swaps := []
	for pair in sh.module_list():
		var local: Vector2i = pair[0]
		var cat := ShipParts.cat_of(String(pair[1]))
		if not cat in ["thruster", "lift", "gun", "boiler", "armor"]:
			continue
		if Game.rng.randf() > 0.35 + float(tier) * 0.12:
			continue
		var better := ShipParts.default_for(String(sh.cells_map[local]), grade)
		if better != "":
			swaps.append([local, better])
	sh.set_modules(swaps)
	sh.mark_dirty()

## A route between two ports, so a trader is going somewhere rather than wandering.
func _trade_route(from: Vector2i) -> Array:
	var out := []
	var gen: SkyGen = Game.sky.gen
	var ports: Array = gen.ports.duplicate()
	if not gen.home.is_empty():
		ports.append(gen.home)
	ports = ports.filter(func(i): return i.get("area") != null)
	ports.sort_custom(func(a, b):
		return Vector2(a["area"].center - from).length() < Vector2(b["area"].center - from).length())
	for isl in ports.slice(0, 3):
		var m = isl.get("mooring")
		out.append(m["cell"] if m != null else isl["area"].center)
	return out

# ------------------------------------------------------------------ retiring
func _retire() -> void:
	var here: Vector2i = Underdecks.world_cell(Game.player)
	for rec in live.duplicate():
		var sh: Airship = rec["ship"]
		var ai: ShipAI = rec["ai"]
		if not is_instance_valid(sh) or not sh.present:
			live.erase(rec)
			Game.fleet.unregister_ai(sh)
			continue
		var d := Vector2(sh.center() - here).length()
		if d < RETIRE:
			continue
		# anything that has been in a fight with you is kept: a pirate you drove off and
		# then met again two rings later is a far better story than a fresh one
		if ai.hostile_to_player or ai.nerve < 0.9 or ai.bounty > 0 and ai.order == ShipAI.FLEE:
			if d < RETIRE * 2.2:
				continue
		live.erase(rec)
		Game.fleet.unregister_ai(sh)
		sh.remove()
		retired += 1

func status_text() -> String:
	var by := {}
	for rec in live:
		var k: String = rec["ai"].kind
		by[k] = int(by.get(k, 0)) + 1
	var parts := []
	for k in by:
		parts.append("%d %s" % [by[k], k])
	return "traffic: %d aloft (%s), %d spawned, %d retired" % [
		live.size(), ", ".join(parts) if not parts.is_empty() else "none", spawned, retired]
