class_name FaunaStream extends RefCounted
## Wildlife, streamed.
##
## The region carries something like nine hundred creature records across fifty islands.
## Spawning all of them at boot costs five seconds and then costs a slice of every frame
## afterwards, for animals on islands the player will not reach for an hour.
##
## So they are not spawned. A record sits inert until the player comes within sight of an
## island, at which point that island's population arrives; when the player leaves, it is
## put back into records. Two rules keep this honest:
##
##   1. Nothing is spawned or despawned inside the player's view. An island wakes up while
##      it is still a smudge on the horizon and goes quiet only once it is well astern.
##   2. A creature that has been *changed* — hurt, angered, robbed you, or is carrying
##      something it took — is remembered rather than recycled. Come back to an island you
##      fought on and the survivors are the survivors, still hurt, and they remember.
##
## The effect is that the sky is full and the frame budget is not.

## Tiles from the player at which an island's wildlife arrives, and at which it leaves.
## The gap between the two is hysteresis: without it, sitting at the boundary would spawn
## and despawn the same wolf forever.
const WAKE := 52.0
const SLEEP := 92.0
## Never spawn anything this close to the player. They should not see it happen.
const NO_SPAWN := 26

var gen: SkyGen
## island id -> {records: Array, live: Array[Entity], awake: bool, centre: Vector2i}
var islands := {}
var _t := 0.0
var _woke := 0
var _slept := 0

func setup(g: SkyGen) -> void:
	gen = g
	islands.clear()
	for isl in g.islands:
		islands[isl["id"]] = {"records": [], "live": [], "awake": false,
			"centre": isl["area"].center if isl["area"] != null else isl["center"],
			"name": isl["name"], "tier": int(isl.get("tier", 0))}
	for rec in g.mob_spawns:
		var id: int = int(rec["island"])
		if islands.has(id):
			islands[id]["records"].append(rec)
	if SPerf.on:
		for id in islands:
			var ir: Dictionary = islands[id]
			print("SPERF island %d %s centre=%d,%d records=%d" % [id, ir["name"], ir["centre"].x, ir["centre"].y, ir["records"].size()])

## Which islands have people on them and should never go quiet: a port with shopkeepers
## in it is not wildlife and is not streamed.
func is_port(id: int) -> bool:
	for isl in gen.islands:
		if isl["id"] == id:
			return isl.get("port", false)
	return false

# ------------------------------------------------------------------ tick
## Spawn jobs waiting their turn: [island rec, creature record, is_night_wave]. Waking an
## island used to instance its whole population inside one frame; now the scan only
## queues and each frame spends at most SPAWN_BUDGET_USEC bringing records in, so an
## island arriving over the horizon costs a few slices instead of one hitch.
var _queue: Array = []
const SPAWN_BUDGET_USEC := 1500

func _drain() -> void:
	if _queue.is_empty():
		return
	var deadline := Time.get_ticks_usec() + SPAWN_BUDGET_USEC
	var here: Vector2i = Underdecks.world_cell(Game.player) if Game.player != null and is_instance_valid(Game.player) else Vector2i.ZERO
	while not _queue.is_empty():
		var job: Array = _queue.pop_front()
		var rec: Dictionary = job[0]
		var r: Dictionary = job[1]
		if not rec["awake"] or bool(r.get("taken", false)):
			continue
		var c: Vector2i = r["cell"]
		if bool(job[2]):
			if not Game.map.is_passable(c) or maxi(absi(c.x - here.x), absi(c.y - here.y)) < 14:
				continue
		else:
			if not Game.map.is_passable(c) or not Falling.supported(c):
				continue
			if maxi(absi(c.x - here.x), absi(c.y - here.y)) < NO_SPAWN:
				continue
		var made := SkyMobs.spawn_group(String(r["mob"]), c, float(r.get("power", 1.0)))
		for m in made:
			if not bool(job[2]):
				m.tags["stream_island"] = rec.get("id", -1)
			rec["live"].append(m)
		if not made.is_empty():
			r["taken"] = true
			r["live"] = made
		if Time.get_ticks_usec() >= deadline:
			break

func process(delta: float) -> void:
	if not _queue.is_empty():
		var t_d := SPerf.t0()
		_drain()
		SPerf.end("fauna.drain", t_d)
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.5
	if Game.player == null or not is_instance_valid(Game.player):
		return
	var here := Underdecks.world_cell(Game.player)
	var night: bool = Game.sky != null and Game.sky.is_night()
	for id in islands:
		var rec: Dictionary = islands[id]
		var d := Vector2(rec["centre"] - here).length()
		if not rec["awake"] and d < WAKE:
			var t := SPerf.t0()
			_wake(rec, night)
			SPerf.end("fauna.wake", t)
		elif rec["awake"] and d > SLEEP:
			var t2 := SPerf.t0()
			_sleep(rec)
			SPerf.end("fauna.sleep", t2)

## An island comes to life. Night records are held back until dusk, exactly as before.
func _wake(rec: Dictionary, night: bool) -> void:
	rec["awake"] = true
	_woke += 1
	for r in rec["records"]:
		if bool(r.get("night", false)) != night:
			continue
		if bool(r.get("taken", false)):
			continue
		_queue.append([rec, r, false])

## The island goes astern. Anything that was hurt, angry or carrying your wrench is kept;
## everything else is put back into a record and forgotten.
func _sleep(rec: Dictionary) -> void:
	rec["awake"] = false
	if not _queue.is_empty():
		_queue = _queue.filter(func(j): return j[0] != rec)
	_slept += 1
	var kept := []
	for m in rec["live"]:
		if not is_instance_valid(m) or m.removed:
			continue
		var h: CHealth = m.c(&"health")
		var ai: CBeastAI = m.c(&"beastai")
		var interesting := false
		if h != null and (h.dead or h.health() < h.max_health * 0.98):
			interesting = true
		if ai != null and (ai.target != null or ai.last_hit_by != null):
			interesting = true
		if m.tags.get("stolen", false):
			interesting = true
		if interesting:
			# a creature you have met stays met. It keeps its wounds and its grudge.
			kept.append(m)
			continue
		m.destroy()
	rec["live"] = kept
	# everything that was despawned can be re-rolled next time
	for r in rec["records"]:
		var live: Array = r.get("live", [])
		var any := false
		for m in live:
			if is_instance_valid(m) and not m.removed:
				any = true
				break
		if not any:
			r["taken"] = false
			r["live"] = []

## Dusk and dawn: the night population of every awake island arrives or slips away.
func on_night(night: bool) -> void:
	# anything still queued for the wrong half of the day is simply not going to happen
	if not _queue.is_empty():
		_queue = _queue.filter(func(j): return bool(j[1].get("night", false)) == night)
	for id in islands:
		var rec: Dictionary = islands[id]
		if not rec["awake"]:
			continue
		if night:
			_wake_night(rec)
		else:
			_clear_night(rec)

func _wake_night(rec: Dictionary) -> void:
	for r in rec["records"]:
		if not bool(r.get("night", false)) or bool(r.get("taken", false)):
			continue
		_queue.append([rec, r, true])

func _clear_night(rec: Dictionary) -> void:
	for m in rec["live"].duplicate():
		if not is_instance_valid(m) or m.removed:
			rec["live"].erase(m)
			continue
		var d: Dictionary = SkyMobs.get_beast(String(m.tags.get("beast", "")))
		if d.is_empty() or not "n" in String(d.get("flags", "")):
			continue
		var h: CHealth = m.c(&"health")
		if h != null and h.dead:
			continue
		# they slip away rather than popping, if nobody is watching
		if Game.player != null and Game.lighting != null and Game.lighting.player_can_see(m.cell):
			continue
		rec["live"].erase(m)
		m.destroy()
	for r in rec["records"]:
		if bool(r.get("night", false)):
			var live: Array = r.get("live", [])
			var any := false
			for m in live:
				if is_instance_valid(m) and not m.removed:
					any = true
			if not any:
				r["taken"] = false

func live_count() -> int:
	var n := 0
	for id in islands:
		for m in islands[id]["live"]:
			if is_instance_valid(m) and not m.removed:
				n += 1
	return n

func status_text() -> String:
	var awake := 0
	var total := 0
	for id in islands:
		if islands[id]["awake"]:
			awake += 1
		total += (islands[id]["records"] as Array).size()
	return "fauna: %d records over %d islands, %d islands awake, %d creatures live" % [
		total, islands.size(), awake, live_count()]
