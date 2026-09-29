class_name ShipAI extends RefCounted
## Somebody else at somebody else's wheel.
##
## An AI captain flies through exactly the same controls a player does — throttle,
## rudder, ballast, sails, guns — and nothing else. There is no shortcut that moves an
## NPC hull directly, because the moment one exists the AI stops being beatable by
## understanding the flight model, which is the only interesting thing about fighting a
## ship. A pirate that cannot outturn you in a canyon is a pirate you can escape in a
## canyon, and you can work that out from the deck.
##
## The consequence worth knowing: an NPC barque is slow to come about for the same reason
## yours is, a pirate with a cold boiler cannot chase you, and shooting a ship's lift
## cells brings it down rather than reducing a hit-point pool.
##
## Orders, in the order they override each other:
##   flee      lift is failing, or the captain has lost their nerve. Run, and trim up.
##   fight     a target inside reach. Close to the beam and give them the broadside.
##   hunt      a target seen but far off. Close on it.
##   patrol    a loop between waypoints, looking.
##   haul      a course between two ports, avoiding everything.
##   moor      station-keeping at a port.

enum { MOOR, HAUL, PATROL, HUNT, FIGHT, FLEE }

const ORDER_NAMES = ["moored", "hauling", "on patrol", "hunting", "fighting", "running"]

## How far a lookout sees. Weather cuts it; a sounder extends it.
const LOOKOUT := 44.0
## Inside this, a gunnery crew will open fire.
const ENGAGE := 17.0
## The beam is where the guns are, so a fighting captain tries to sit here.
const BEAM_ANGLE := PI * 0.5

var ship: Airship
var kind := "trader"      # trader | pirate | patrol | hermit
var order := PATROL
var target: Airship = null
var waypoints: Array = []
var wp := 0
var nerve := 1.0          # 0 broken, 1 resolute. Damage and losing a fight wear it down.
var skill := 0.4          # 0..1: gunnery, airmanship and how well they trim
var home := Vector2i.ZERO
var cargo_value := 0
var bounty := 0
var captain := ""
var hostile_to_player := false

var _t := 0.0
var _talk_t := 0.0
var _stuck := 0.0
var _last_pos := Vector2.ZERO

func setup(sh: Airship, k: String, sk: float) -> ShipAI:
	ship = sh
	kind = k
	skill = clampf(sk, 0.05, 1.0)
	home = sh.origin
	hostile_to_player = k == "pirate"
	return self

# ------------------------------------------------------------------ the tick
func process(delta: float) -> void:
	if ship == null or not ship.present:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.4
	_engineering()
	_decide()
	match order:
		MOOR: _moor()
		HAUL: _haul()
		PATROL: _patrol()
		HUNT: _hunt()
		FIGHT: _fight()
		FLEE: _flee()
	_gunnery()
	_unstick(delta)

## The things a crew does below decks without being told: keep the boiler lit, keep the
## trim level, and stop feeding a fire when the bunkers are nearly dry.
func _engineering() -> void:
	var want_steam := order != MOOR
	for b in ship.boilers:
		var bc: CBoiler = b.c(&"boiler")
		if bc == null:
			continue
		if want_steam and not bc.lit and ship.fuel() > 4.0:
			bc.lit = true
			bc.damper = 0.55 + skill * 0.4
			bc.valve_open = true
		elif not want_steam and bc.lit:
			bc.lit = false
	# ballast: hold level, and a better crew holds it tighter
	var buoy := ship.buoyancy()
	var slack := 0.10 - skill * 0.06
	if buoy > 1.0 + slack:
		ship.ballast = clampf(ship.ballast - 0.08, -1.0, 1.0)
	elif buoy < 1.0 - slack:
		ship.ballast = clampf(ship.ballast + 0.08, -1.0, 1.0)
	# canvas, when it is worth setting
	if not ship.masts.is_empty() and Game.sky != null:
		var w: Vector2 = Game.sky.wind_vector()
		var f := Vector2(cos(ship.angle), sin(ship.angle))
		var helping: bool = w.length() > 0.3 and w.normalized().dot(f) > 0.15
		var storm: bool = Game.sky.weather.at(ship.center(), Weather.THUNDERHEAD) > 0.3
		var want_sail: float = 0.0
		if helping and order != FIGHT and not (storm and ship.quirk_count("storm_proof") == 0):
			want_sail = 0.6 + skill * 0.4
		ship.sails_set = move_toward(ship.sails_set, want_sail, 0.15)

## What the captain has decided to do about the world.
func _decide() -> void:
	# nerve first: a ship that is losing goes home, whatever it was doing
	var hurt := _damage_fraction()
	if hurt > 0.55 or ship.buoyancy() < 0.72 or ship.fuel() < 3.0:
		nerve = minf(nerve, 0.25)
	if nerve < 0.3:
		if order != FLEE:
			_say(_line("flee"))
			order = FLEE
		return
	if target != null and (not is_instance_valid(target) or not target.present):
		target = null
	if target == null:
		target = _look()
	if target != null:
		var d := _dist_to(target)
		if d <= ENGAGE + 6.0:
			if order != FIGHT:
				_say(_line("engage"))
			order = FIGHT
		else:
			order = HUNT
		return
	order = HAUL if kind == "trader" and not waypoints.is_empty() else PATROL
	if kind == "hermit":
		order = MOOR

## Who is worth attacking, and who is worth avoiding. A trader looks for nothing and a
## patrol looks for pirates, which means the sky occasionally sorts itself out without
## the player being present — and a player who watches that happen has learned the rules.
func _look() -> Airship:
	if kind == "trader" or kind == "hermit":
		return null
	if Game.fleet == null:
		return null
	var sight := LOOKOUT * _visibility() * (0.75 + skill * 0.5)
	var best: Airship = null
	var bd := 1e9
	for other in Game.fleet.ships:
		if other == ship or not other.present:
			continue
		if not _is_prey(other):
			continue
		var d := _dist_to(other)
		if d < sight and d < bd:
			bd = d
			best = other
	return best

func _is_prey(other: Airship) -> bool:
	var oai: ShipAI = Game.fleet.ai_of(other)
	if other == Game.fleet.player_ship:
		# a pirate wants your cargo; a patrol wants you only if you have earned it
		if kind == "pirate":
			return true
		return kind == "patrol" and Reputation.wanted() > 0
	if oai == null:
		return false
	match kind:
		"pirate": return oai.kind in ["trader", "hermit"]
		"patrol": return oai.kind == "pirate"
	return false

func _visibility() -> float:
	if Game.sky == null:
		return 1.0
	var v: float = Game.sky.visibility_at(ship.center())
	if ship.has_quirk("sound"):
		v = maxf(v, 0.85)  # a sounder pings through fog
	return v

# ------------------------------------------------------------------ orders
func _moor() -> void:
	ship.throttle = 0.0
	ship.rudder_input = 0.0

func _haul() -> void:
	if waypoints.is_empty():
		order = PATROL
		return
	var to: Vector2i = waypoints[wp % waypoints.size()]
	if _dist_to_cell(to) < 14.0:
		wp += 1
		if wp >= waypoints.size() * 4:
			# a trader that has run its route long enough leaves this sky
			ship.remove()
			return
	_steer_for(to, 0.85)

func _patrol() -> void:
	if waypoints.is_empty():
		_make_patrol()
	if waypoints.is_empty():
		_moor()
		return
	var to: Vector2i = waypoints[wp % waypoints.size()]
	if _dist_to_cell(to) < 12.0:
		wp += 1
	_steer_for(to, 0.6)

func _hunt() -> void:
	if target == null:
		order = PATROL
		return
	_steer_for(target.center(), 1.0)

## Fighting is a manoeuvre, not a damage race. The guns bear on the beam, so a captain
## who knows their trade puts the target abeam and holds it there — and a player who
## works that out can sit on their stern and be shot at by nothing.
func _fight() -> void:
	if target == null:
		order = PATROL
		return
	var d := _dist_to(target)
	if d > ENGAGE + 10.0:
		order = HUNT
		return
	var to_target := Vector2(target.center() - ship.center())
	var want := to_target.angle()
	# turn so the target sits off the beam rather than off the bow
	var side: float = 1.0 if wrapf(want - ship.angle, -PI, PI) > 0.0 else -1.0
	ship.wanted_angle = wrapf(want - side * BEAM_ANGLE, -PI, PI)
	ship.heading = Airship._quarter_of(ship.wanted_angle)
	# hold the range: close if far, open if they are inside your own turning circle
	var want_speed: float = 0.5
	if d > ENGAGE * 0.8:
		want_speed = 0.9
	elif d < 5.0:
		want_speed = 0.85  # too close to shoot: get some air
	ship.throttle = want_speed

func _flee() -> void:
	var from: Vector2 = Vector2(target.center()) if target != null else Vector2(home)
	var away := (Vector2(ship.center()) - from).normalized()
	if away.length() < 0.01:
		away = Vector2.RIGHT
	ship.wanted_angle = away.angle()
	ship.heading = Airship._quarter_of(ship.wanted_angle)
	ship.throttle = 1.0
	ship.sails_set = 1.0
	# climbing is the oldest escape in this sky: trim up and let them lose you in cloud
	ship.ballast = clampf(ship.ballast + 0.05, -1.0, 1.0)
	if _damage_fraction() < 0.3 and nerve < 1.0:
		nerve = minf(1.0, nerve + 0.02)
		if nerve > 0.45:
			target = null
			order = PATROL

# ------------------------------------------------------------------ flying
func _steer_for(c: Vector2i, throttle: float) -> void:
	var to := Vector2(c - ship.center())
	if to.length() < 0.5:
		return
	ship.wanted_angle = to.angle()
	ship.heading = Airship._quarter_of(ship.wanted_angle)
	# do not drive full-tilt into a turn you cannot make
	var off := absf(wrapf(ship.wanted_angle - ship.angle, -PI, PI))
	ship.throttle = throttle * clampf(1.0 - off / PI * 0.7, 0.25, 1.0)
	ship.rudder_input = 0.0

func _make_patrol() -> void:
	waypoints.clear()
	if Game.sky == null or Game.sky.gen == null:
		return
	var gen: SkyGen = Game.sky.gen
	var here := ship.center()
	var near := []
	for isl in gen.islands:
		# an island whose noise pass left it too small to keep has no area at all
		if isl.get("area") == null:
			continue
		var d := Vector2(isl["area"].center - here).length()
		if d < 150.0:
			near.append(isl)
	near.shuffle()
	for isl in near.slice(0, 4):
		var m = isl.get("mooring")
		waypoints.append(m["cell"] if m != null else isl["area"].center)
	if waypoints.is_empty():
		waypoints.append(home)

## A ship that has wedged itself against a rock gives up on the waypoint rather than
## grinding there for the rest of the session.
func _unstick(delta: float) -> void:
	var moved := ship.pos.distance_to(_last_pos)
	_last_pos = ship.pos
	if ship.throttle > 0.2 and moved < 0.3:
		_stuck += delta
		if _stuck > 6.0:
			_stuck = 0.0
			wp += 1
			ship.wanted_angle = wrapf(ship.angle + PI * 0.6, -PI, PI)
			ship.heading = Airship._quarter_of(ship.wanted_angle)
	else:
		_stuck = maxf(0.0, _stuck - delta)

# ------------------------------------------------------------------ gunnery
func _gunnery() -> void:
	if order != FIGHT or target == null:
		return
	var aim := _aim_point(target)
	for g in ship.guns:
		if not is_instance_valid(g) or g.removed:
			continue
		var gc: CShipGun = g.c(&"shipgun")
		if gc == null or gc.can_fire(null) != "":
			continue
		if not gc.in_arc(aim):
			continue
		if Vector2(aim - g.cell).length() > gc.reach():
			continue
		# a poor crew shoots early and wide; a good one waits
		if Game.rng.randf() > 0.25 + skill * 0.6:
			continue
		gc.fire(_gunner(), aim)

## Where to put the shot. A good crew goes for the lift cells, because a ship with no
## lift is a ship on the ground, and that is the whole doctrine of sky fighting.
func _aim_point(t: Airship) -> Vector2i:
	if skill > 0.45 and not t.lift_cells.is_empty():
		for l in t.lift_cells:
			if is_instance_valid(l) and not l.removed:
				var lc: CLiftCell = l.c(&"liftcell")
				if lc != null and lc.charge > 0.3:
					return l.cell
	return t.center()

## Guns want a shooter for the experience and the message. NPC crews are not entities, so
## they fire as nobody — the gun still works, it simply teaches no one anything.
func _gunner() -> Entity:
	return null

# ------------------------------------------------------------------ damage and death
func _damage_fraction() -> float:
	var breaches := float(ship.breaches())
	var cells := float(maxi(1, ship.cells_map.size()))
	var lift := 0.0
	var n := 0
	for l in ship.lift_cells:
		if is_instance_valid(l) and not l.removed:
			var lc: CLiftCell = l.c(&"liftcell")
			if lc != null:
				lift += lc.charge * lc.integrity
				n += 1
	var lift_frac: float = (lift / float(n)) if n > 0 else 0.0
	return clampf(breaches / cells * 3.0 + (1.0 - lift_frac) * 0.6, 0.0, 1.0)

## Called by CShipGun when a shot lands on this hull.
func on_hit(by: Airship) -> void:
	nerve = maxf(0.0, nerve - 0.06 * (1.0 - skill * 0.5))
	if by != null and target == null and kind != "trader":
		target = by
	if by == Game.fleet.player_ship:
		hostile_to_player = true
		if kind != "pirate":
			# shooting a trader or a patrol is a thing the sky remembers
			Reputation.on_attacked_innocent(kind)
	if nerve < 0.3 and order != FLEE:
		_say(_line("flee"))

## She has come apart. What is left is a derelict worth stripping.
func on_wrecked(by: Airship) -> void:
	Game.msg("[b][color=#ff8a5a]%s goes down.[/color][/b]" % ship.ship_name, "bad")
	Bus.chronicle.emit("%s was brought down over %s." % [
		ship.ship_name, Game.sky.gen.ring_name_at(ship.center()) if Game.sky != null else "the sky"], 3)
	if by == Game.fleet.player_ship:
		if kind == "pirate" and bounty > 0:
			Economy.give(Game.player, bounty)
			Game.msg("[color=#e8c85a]%s was wanted. That is %s marks.[/color]" % [
				ship.ship_name, Economy.money(bounty)], "good")
			Reputation.on_pirate_killed()
		else:
			Reputation.on_innocent_killed(kind)
		if Game.player != null:
			Skills.add_xp(Game.player, "gunnery", 120.0 + float(bounty) * 0.05)
	# spill her cargo into the wreck rather than deleting it
	_scatter_cargo()

func _scatter_cargo() -> void:
	var drops: int = 2 + cargo_value / 220
	for _i in mini(12, drops):
		var c: Vector2i = ship.cells[Game.rng.randi() % ship.cells.size()] if not ship.cells.is_empty() else ship.origin
		var pick := Salvage.roll(Game.rng, 0.3 + float(bounty) * 0.0002)
		if Proto.has(pick):
			Proto.spawn(pick, c)

# ------------------------------------------------------------------ voice
## Ships talk on the common channel. It is the cheapest way to make a sky feel inhabited
## and the only warning you get before a pirate commits.
const LINES := {
	"pirate": {
		"engage": ["Heave to and we will only take the cargo.", "Bring her about, friend. This will be quick.",
			"You are a long way from anywhere.", "Cut your engines."],
		"flee": ["Break off! Break off!", "She is not worth it — go!", "We are holed, we are holed."],
		"hail": ["Nice hull. Shame about the escort.", "Keep flying, and keep flying past us."],
	},
	"patrol": {
		"engage": ["Revenue cutter. Cut your engines and stand by.", "You are under the guns of the Meridian watch.",
			"Do not make this a chase."],
		"flee": ["Falling back — call it in!", "We are hit. Disengaging."],
		"hail": ["Steady as you go.", "Keep to the charted lanes and you will keep your cargo."],
	},
	"trader": {
		"engage": [], "flee": ["Sheer off! Sheer off!", "All we have is salt and rope!", "Do not shoot, do not shoot."],
		"hail": ["Fair winds.", "Anything worth knowing out that way?", "Mind the weather to the east."],
	},
	"hermit": {
		"engage": [], "flee": ["Leave me be."], "hail": ["Go around.", "I have nothing you want."],
	},
}

func _line(what: String) -> String:
	var t: Dictionary = LINES.get(kind, LINES["trader"])
	var pool: Array = t.get(what, [])
	if pool.is_empty():
		return ""
	return String(pool[Game.rng.randi() % pool.size()])

func _say(text: String) -> void:
	if text == "" or Game.time < _talk_t:
		return
	# only worth hearing if it is happening near you
	if Game.player == null or _dist_to_cell(Game.player.root_cell()) > 60.0:
		return
	_talk_t = Game.time + 8.0
	Game.msg("[color=#8ad8a0][b]%s[/b] — \"%s\"[/color]" % [ship.ship_name, text], "radio")

## A passing hail, when nothing is happening. Ships that never speak are scenery.
func idle_hail() -> void:
	_say(_line("hail"))

# ------------------------------------------------------------------ helpers
func _dist_to(other: Airship) -> float:
	return Vector2(other.center() - ship.center()).length()

func _dist_to_cell(c: Vector2i) -> float:
	return Vector2(c - ship.center()).length()

func status_text() -> String:
	return "%s (%s, %s) — %s, nerve %d%%" % [ship.ship_name, kind,
		ORDER_NAMES[order], ship.status_text(), int(nerve * 100.0)]
