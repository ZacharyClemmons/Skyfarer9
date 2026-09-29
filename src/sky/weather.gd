class_name Weather extends RefCounted
## Weather that is a thing in the world rather than a filter over it.
##
## The Cloudsea's weather moves as discrete cells — a thunderhead, a fog bank, an aether
## squall — each with a position, a radius, a drift and a life. They are on the map, you
## can see them coming, you can fly round them, and if you fly into one it does something
## specific to your ship and to everything living under it:
##
##   thunderhead   charges every aether cell aboard (free ammunition, free lift-cell
##                 top-up) and periodically puts a bolt into the tallest thing present,
##                 which is your mast. A stormdrive gets faster. Canvas blows out unless
##                 it is storm canvas.
##   fog bank      sight collapses, the sounder goes deaf, and things that hunt by sound
##                 find you far more easily. Ships have hit islands in fog.
##   aether squall  lift goes up hard and unevenly. A badly trimmed hull is thrown out of
##                 its band; a well trimmed one gets a free climb.
##   downdraft     the opposite, and it is how ships are lost. Lift falls, the ship sinks,
##                 and the only answer is to blow ballast and burn fuel.
##   ashfall       heat, soot and a slow choke on anything open to the air. Blows in off
##                 cinder isles and does not care that you were not there.
##   aurora        harmless, beautiful, and it doubles what you learn while it is up,
##                 because nothing in this game should be only one of those three.
##
## A front carries its own colour into the lightmap and its own haze into the weather
## layer, so you can read it from the deck without opening anything.

enum { CLEAR, THUNDERHEAD, FOG, SQUALL, DOWNDRAFT, ASHFALL, AURORA }

const KINDS = {
	THUNDERHEAD: {"name": "a thunderhead", "col": Color(0.24, 0.26, 0.38), "haze": 0.55,
		"speak": "The cloud ahead is black and it is lit from the inside.",
		"leaving": "The thunderhead falls astern. Everything metal aboard is still humming."},
	FOG: {"name": "a fog bank", "col": Color(0.72, 0.76, 0.80), "haze": 0.85,
		"speak": "The world goes white. You cannot see the bow.",
		"leaving": "The fog thins and the sky comes back all at once."},
	SQUALL: {"name": "an aether squall", "col": Color(0.46, 0.70, 0.78), "haze": 0.40,
		"speak": "The air goes thick and the deck lifts under your feet.",
		"leaving": "The squall passes. She settles."},
	DOWNDRAFT: {"name": "a downdraft", "col": Color(0.30, 0.34, 0.42), "haze": 0.34,
		"speak": "[b]The bottom drops out of the air.[/b]",
		"leaving": "The air firms up. She stops falling."},
	ASHFALL: {"name": "an ashfall", "col": Color(0.42, 0.36, 0.32), "haze": 0.60,
		"speak": "Grit starts coming down, and it is warm.",
		"leaving": "The ash thins out. Everything aboard is grey."},
	AURORA: {"name": "an aether aurora", "col": Color(0.52, 0.84, 0.72), "haze": 0.12,
		"speak": "[color=#7ad8c8]The whole sky goes green and starts moving.[/color]",
		"leaving": "The aurora fades westward."},
}

## How many fronts a region carries at once, by altitude band. High skies are violent.
const COUNT_BY_BAND = [3, 4, 5, 6, 7]

## A front: where it is, how big, where it is going, and how long it has.
class Front:
	var kind := CLEAR
	var pos := Vector2.ZERO
	var radius := 30.0
	var drift := Vector2.ZERO
	var life := 200.0
	var strength := 1.0
	var announced := false

	func contains(c: Vector2i) -> bool:
		return Vector2(c).distance_to(pos) < radius

	## 0 at the edge, 1 at the heart. Everything scales on this, so the edge of a storm
	## is a warning rather than a wall.
	func intensity(c: Vector2i) -> float:
		var d := Vector2(c).distance_to(pos)
		if d >= radius:
			return 0.0
		return clampf(1.0 - d / radius, 0.0, 1.0) * strength

var fronts: Array = []
var band := 1
var rng := RandomNumberGenerator.new()
var _spawn_t := 0.0
var _tick_t := 0.0
var _bolt_t := 0.0
## Where the player is, cached once a tick, because half of this asks the same question.
var _here := Vector2i.ZERO
var _in := {}      # kind -> intensity at the player, this tick
var _was := {}     # kind -> was it in last tick, for arrival and departure lines

func setup(seed_value: int, band_index: int) -> void:
	rng.seed = seed_value ^ 0x5EED
	band = clampi(band_index, 0, 4)
	fronts.clear()
	for _i in COUNT_BY_BAND[band]:
		fronts.append(_new_front(true))

func _new_front(anywhere: bool) -> Front:
	var f := Front.new()
	f.kind = _roll_kind()
	if anywhere:
		f.pos = Vector2(rng.randf_range(0, SkyGen.W), rng.randf_range(0, SkyGen.H))
	else:
		# new weather comes in over the rim, so it can be seen arriving
		var edge := rng.randi() % 4
		match edge:
			0: f.pos = Vector2(rng.randf_range(0, SkyGen.W), -20.0)
			1: f.pos = Vector2(SkyGen.W + 20.0, rng.randf_range(0, SkyGen.H))
			2: f.pos = Vector2(rng.randf_range(0, SkyGen.W), SkyGen.H + 20.0)
			_: f.pos = Vector2(-20.0, rng.randf_range(0, SkyGen.H))
	f.radius = rng.randf_range(26.0, 72.0)
	if f.kind == AURORA:
		f.radius = rng.randf_range(70.0, 140.0)
	var ang := rng.randf() * TAU
	f.drift = Vector2(cos(ang), sin(ang)) * rng.randf_range(0.25, 0.9)
	f.life = rng.randf_range(180.0, 520.0)
	f.strength = rng.randf_range(0.55, 1.0)
	return f

## Which weather a band gets. The Deep is fog and ash; the Anvil is lightning and aurora.
func _roll_kind() -> int:
	var table := []
	match band:
		0: table = [[FOG, 30], [ASHFALL, 22], [DOWNDRAFT, 24], [THUNDERHEAD, 10], [SQUALL, 14]]
		1: table = [[FOG, 26], [SQUALL, 24], [THUNDERHEAD, 18], [DOWNDRAFT, 16], [ASHFALL, 10], [AURORA, 6]]
		2: table = [[SQUALL, 24], [THUNDERHEAD, 24], [FOG, 18], [DOWNDRAFT, 16], [AURORA, 10], [ASHFALL, 8]]
		3: table = [[THUNDERHEAD, 30], [SQUALL, 22], [DOWNDRAFT, 18], [AURORA, 16], [FOG, 14]]
		_: table = [[THUNDERHEAD, 34], [AURORA, 22], [SQUALL, 20], [DOWNDRAFT, 18], [FOG, 6]]
	var total := 0
	for row in table:
		total += int(row[1])
	var r := rng.randi() % maxi(1, total)
	for row in table:
		r -= int(row[1])
		if r < 0:
			return int(row[0])
	return FOG

# ------------------------------------------------------------------ tick
func process(delta: float) -> void:
	for f in fronts.duplicate():
		var ff: Front = f
		ff.pos += ff.drift * delta
		ff.life -= delta
		# fronts fade rather than vanish, so nothing pops out of existence in front of you
		if ff.life < 20.0:
			ff.strength = maxf(0.0, ff.strength - delta * 0.05)
		if ff.life <= 0.0 or ff.pos.x < -90 or ff.pos.y < -90 or ff.pos.x > SkyGen.W + 90 or ff.pos.y > SkyGen.H + 90:
			fronts.erase(ff)
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = rng.randf_range(35.0, 90.0)
		if fronts.size() < COUNT_BY_BAND[band] + 2:
			fronts.append(_new_front(false))
	_tick_t -= delta
	if _tick_t > 0.0:
		return
	_tick_t = 1.0
	_apply(1.0)

# ------------------------------------------------------------------ queries
## Total intensity of one kind of weather at a cell.
func at(c: Vector2i, kind: int) -> float:
	var v := 0.0
	for f in fronts:
		var ff: Front = f
		if ff.kind == kind:
			v = maxf(v, ff.intensity(c))
	return v

## The worst weather over a cell, as [kind, intensity].
func worst_at(c: Vector2i) -> Array:
	var best := CLEAR
	var bi := 0.0
	for f in fronts:
		var ff: Front = f
		var i := ff.intensity(c)
		if i > bi:
			bi = i
			best = ff.kind
	return [best, bi]

## Storm charge in the air: what a stormdrive drinks and an aether cell recharges from.
func storm_charge(c: Vector2i) -> float:
	return at(c, THUNDERHEAD) + at(c, AURORA) * 0.4

## How thick the aether runs here: fishing, condensers and lift all read it.
func aether_density(c: Vector2i) -> float:
	return 1.0 + at(c, SQUALL) * 0.9 + at(c, AURORA) * 0.5 - at(c, DOWNDRAFT) * 0.5

## How far you can see. Fog is the only thing in this game that takes sight away.
func visibility(c: Vector2i) -> float:
	return clampf(1.0 - at(c, FOG) * 0.85 - at(c, ASHFALL) * 0.35, 0.12, 1.0)

## What lift is multiplied by here. A squall is free altitude; a downdraft is the reason
## ships are lost.
func lift_factor(c: Vector2i) -> float:
	return 1.0 + at(c, SQUALL) * 0.45 - at(c, DOWNDRAFT) * 0.5

# ------------------------------------------------------------------ effects
## Everything the weather does, once a second, to the ship and the person the player is.
func _apply(dt: float) -> void:
	var p := Game.player
	if p == null or not is_instance_valid(p):
		return
	_here = p.root_cell()
	var sh: Airship = Game.fleet.ship_of(p) if Game.fleet != null else null
	var now := {}
	for kind in KINDS:
		var i := at(_here, int(kind))
		if i > 0.05:
			now[kind] = i
	# arrivals and departures, said once
	for kind in now:
		if not _was.has(kind):
			Game.msg("[b][color=#9ad8ff]%s[/color][/b]  %s" % [
				String(KINDS[kind]["name"]).capitalize(), String(KINDS[kind]["speak"])], "warn")
	for kind in _was:
		if not now.has(kind):
			Game.msg("[i]%s[/i]" % String(KINDS[kind]["leaving"]), "info")
	_was = now
	if now.is_empty():
		return
	var outdoors := Game.map.is_outdoor(_here)
	for kind in now:
		var i: float = now[kind]
		match kind:
			THUNDERHEAD: _thunder(p, sh, i, dt, outdoors)
			FOG: _fog(p, sh, i, dt)
			SQUALL: _squall(p, sh, i, dt, outdoors)
			DOWNDRAFT: _downdraft(p, sh, i, dt)
			ASHFALL: _ash(p, sh, i, dt, outdoors)
			AURORA: _aurora(p, sh, i, dt)

## A storm charges everything and eventually hits the tallest thing present.
func _thunder(p: Entity, sh: Airship, i: float, dt: float, outdoors: bool) -> void:
	SkyBuffs.apply(p, "static", i, 3.0, "storm")
	# free charge for every aether weapon carried, which makes flying into a storm a
	# genuine resupply run rather than only a hazard
	var inv: CInventory = p.c(&"inv")
	if inv != null and rng.randf() < dt * i * 0.25:
		for it in inv.all_items(true):
			var g: CAetherGun = it.c(&"aethergun")
			if g != null:
				g.storm_charge(1)
	if sh != null:
		# and for the lift cells, which is the reason old hands go looking for weather
		if rng.randf() < dt * i * 0.2:
			for l in sh.lift_cells:
				var lc: CLiftCell = l.c(&"liftcell")
				if lc != null:
					lc.charge = minf(1.0, lc.charge + 0.02 * i)
		# canvas blows out unless it is built for this
		if sh.sails_set > 0.3 and rng.randf() < dt * i * 0.05 and sh.quirk_count("storm_proof") == 0:
			sh.sails_set = maxf(0.0, sh.sails_set - 0.4)
			Game.msg("[b][color=#ff8a5a]The canvas blows out with a crack. What is left is reefed.[/color][/b]", "bad")
	_bolt_t -= dt
	if _bolt_t <= 0.0 and outdoors and rng.randf() < i * 0.18:
		_bolt_t = 6.0
		_strike(p, sh, i)

## A bolt goes into the tallest thing aboard, which is your mast, and from there into
## whatever was touching it.
func _strike(p: Entity, sh: Airship, i: float) -> void:
	var target: Vector2i = _here
	if sh != null and not sh.masts.is_empty():
		var m: Entity = sh.masts[rng.randi() % sh.masts.size()]
		if is_instance_valid(m):
			target = m.cell
	Game.msg("[b][color=#9ad8ff]A bolt comes down.[/color][/b]", "bad")
	Sfx.play("explosion", target, 0.8)
	Fx.sparks(target)
	if Game.view:
		Game.view.shake(6.0)
	if Game.atmos != null and Game.map.inb(target):
		Game.atmos.add_heat(Game.map.idx(target), 120000.0 * i)
	for ent in Game.in_radius(target, 2, &"health"):
		var h: CHealth = ent.c(&"health")
		if h == null or h.dead:
			continue
		# a hull with skyglass lamination sheds it, which is the whole sales pitch
		var soak := 0.0
		if sh != null:
			soak = sh.armor_at(ent.cell) * 0.5
		var dealt := maxf(0.0, (16.0 + 22.0 * i) - soak)
		if dealt > 0.0:
			h.take_damage(dealt, "burn", null)
			Game.tell(ent, "[b][color=#9ad8ff]The bolt goes through you.[/color][/b]", "bad")
			SkyBuffs.apply(ent, "static", 1.0, 20.0, "lightning")

## Sight collapses. The one weather that changes how you fly rather than how fast.
func _fog(p: Entity, sh: Airship, i: float, dt: float) -> void:
	SkyBuffs.apply(p, "blind", i, 3.0, "fog")
	# hunting things find you: a fogged sky is quiet and sound carries
	if rng.randf() < dt * i * 0.08:
		for other in Game.in_radius(_here, 22, &"beastai"):
			var ai: CBeastAI = other.c(&"beastai")
			if ai != null and ai.target == null and ai.damage > 0.0 and rng.randf() < 0.3:
				ai.target = p
				ai.last_seen = Game.time

## Free altitude, unevenly given.
func _squall(p: Entity, sh: Airship, i: float, dt: float, outdoors: bool) -> void:
	if sh == null:
		if outdoors and rng.randf() < dt * i * 0.06 and not SkyBuffs.has(p, "wind_immune"):
			Game.tell(p, "[color=#e8a83a]The gust nearly takes you off your feet.[/color]", "warn")
			var h: CHealth = p.c(&"health")
			if h != null and h.has_method("knockdown"):
				h.knockdown(8.0)
		return
	sh.altitude += 0.035 * i * dt
	if rng.randf() < dt * 0.1:
		Game.msg("[color=#7ad8c8]She is lifting on the squall. Trim heavy or ride it.[/color]", "info")

## The one that kills people.
func _downdraft(p: Entity, sh: Airship, i: float, dt: float) -> void:
	if sh == null:
		return
	sh.altitude = maxf(0.05, sh.altitude - 0.045 * i * dt)
	if rng.randf() < dt * 0.12:
		Game.msg("[color=#ff8a5a]She is going down. Blow ballast.[/color]", "bad")

## Heat, grit and a slow choke.
func _ash(p: Entity, sh: Airship, i: float, dt: float, outdoors: bool) -> void:
	if not outdoors:
		return
	SkyBuffs.apply(p, "slow", i * 0.25, 3.0, "ash")
	if Game.atmos != null:
		var idx := Game.map.idx(_here)
		Game.atmos.add_gas(idx, Defs.G_SMOKE, 0.12 * i * dt, Defs.T0C + 90.0)
		Game.atmos.mark_present(Defs.G_SMOKE)
		Game.atmos.add_heat(idx, 1800.0 * i * dt)
	if sh != null and rng.randf() < dt * i * 0.04:
		# soot in the burners: an engine in an ashfall loses a little ground
		for t in sh.thrusters:
			var tc: CThruster = t.c(&"thruster")
			if tc != null:
				tc.heat = minf(1.0, tc.heat + 0.04)

## The kind one.
func _aurora(p: Entity, sh: Airship, i: float, dt: float) -> void:
	SkyBuffs.apply(p, "xp", 1.0 + i * 0.6, 3.0, "aurora")
	if sh != null and rng.randf() < dt * i * 0.15:
		for l in sh.lift_cells:
			var lc: CLiftCell = l.c(&"liftcell")
			if lc != null:
				lc.charge = minf(1.0, lc.charge + 0.015 * i)

# ------------------------------------------------------------------ presentation
## The colour the weather pushes into the lightmap where the player is.
func tint_at(c: Vector2i) -> Color:
	var col := Color(1, 1, 1, 0.0)
	for f in fronts:
		var ff: Front = f
		var i := ff.intensity(c)
		if i <= 0.01:
			continue
		var k: Color = KINDS[ff.kind]["col"]
		col = col.lerp(Color(k.r, k.g, k.b, i * 0.55), i)
	return col

## How much haze the weather layer should draw.
func haze_at(c: Vector2i) -> float:
	var h := 0.0
	for f in fronts:
		var ff: Front = f
		h = maxf(h, ff.intensity(c) * float(KINDS[ff.kind]["haze"]))
	return h

## What the glass says. A storm oracle reads it earlier and from further away.
func forecast(from: Vector2i, sight: float) -> String:
	var soon := []
	for f in fronts:
		var ff: Front = f
		if ff.strength < 0.2:
			continue
		var d := Vector2(from).distance_to(ff.pos) - ff.radius
		if d > sight:
			continue
		var word := "over you" if d <= 0.0 else "%d tiles off" % int(d)
		var going := ""
		if ff.drift.length() > 0.05:
			var to: Vector2 = ff.pos + ff.drift * 60.0
			going = " and closing" if Vector2(from).distance_to(to) < Vector2(from).distance_to(ff.pos) else " and drawing away"
		soon.append("%s, %s%s" % [String(KINDS[ff.kind]["name"]), word, going])
	if soon.is_empty():
		return "Nothing on the glass. Clear sky as far as the instrument reaches."
	return "; ".join(soon).capitalize() + "."

func text_at(c: Vector2i) -> String:
	var w := worst_at(c)
	if int(w[0]) == CLEAR or float(w[1]) < 0.08:
		return ""
	var strength := "the edge of"
	if float(w[1]) > 0.66:
		strength = "the heart of"
	elif float(w[1]) > 0.33:
		strength = "well inside"
	return "You are in %s %s." % [strength, String(KINDS[int(w[0])]["name"])]
