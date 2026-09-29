class_name CBeastAI extends Component
## Sky creature behaviour.
##
## Seven behaviours, each one legible enough that a player can learn it in one encounter
## and then plan around it. That is the whole design goal: a hunter you can outrun, an
## ambusher you can spot if you look, a pack that breaks if you thin it, a drifter you
## cannot fight and have to leave.
##
## On top of the behaviour sits a short list of *powers* (BeastPowers): the thing this
## particular creature does that nothing else does. A behaviour decides how it moves; a
## power is why you remember it. Powers telegraph before they land and every one of them
## has a counter that was a decision you could have made a minute earlier.
##
## Everything here refuses to walk into open sky unless it can fly, which is what makes
## a ledge a tactic.

const SIGHT := 9
const LOSE_INTEREST := 12.0

var beast := ""
var behaviour := "grazer"
var damage := 0.0
var sight := SIGHT
var flying := false
var nocturnal := false
var anomalous := false
var packish := false

var target: Entity = null
var last_seen := 0.0
var hidden := false # ambushers, until they strike
var alert := 0.0 # 0 calm .. 1 committed
var _step_t := 0.0
var _home := Vector2i.ZERO
var _wander := Vector2i.ZERO
var _attack_t := 0.0

## ---- powers
## What this creature can do besides bite. Ids into BeastPowers.POWERS.
var powers: Array = []
var cooldowns := {}
## A telegraphed power that is winding up: it lands when `wind_t` runs out, and until it
## does the creature is standing still doing something visible.
var winding := ""
var wind_t := 0.0
## Deliberately untargetable, for a few seconds.
var phased := 0.0
## Running away with something, for a few seconds.
var fleeing := 0.0
## How hard this one is, from the ring it was spawned in. 1.0 in the Home Reach, near 4
## out on the Rim, and it multiplies health, damage and what it drops.
var power := 1.0
## Ambushers that look like scenery, and lures that look like loot.
var disguised := false
## Who hit it last. Skinning yields and combat experience both need an owner, and the
## health component does not track one.
var last_hit_by: Entity = null

func key() -> StringName:
	return &"beastai"

func setup(id: String, d: Dictionary) -> CBeastAI:
	beast = id
	behaviour = d["beh"]
	damage = float(d["dmg"])
	var flags: String = d["flags"]
	flying = "f" in flags
	nocturnal = "n" in flags
	anomalous = "x" in flags
	packish = "p" in flags
	powers = (d.get("ab", []) as Array).duplicate()
	disguised = powers.has("lure") or powers.has("feign")
	sight = SIGHT + (3 if behaviour == "hunter" else 0)
	if powers.has("gaze") or powers.has("echo"):
		sight += 3
	return self

func on_added() -> void:
	_home = e.cell
	if disguised:
		hidden = true
		e.modulate = Color(1, 1, 1, 0.55)

# ------------------------------------------------------------------ tick
## How far away a creature stops being worth thinking about every frame. A region this
## size carries seven hundred of them; simulating all of them at full rate would spend
## the whole frame budget on animals nobody can see. Far ones still move and still hunt —
## they simply think in slower steps, and they wake fully the moment you are near.
const NEAR := 34
const FAR_SKIP := 1.6

var _far_t := 0.0

func process(delta: float) -> void:
	var h: CHealth = e.c(&"health")
	if h == null or h.dead:
		return
	# Distance culling. Anything in a fight, or with a target, keeps full attention.
	if target == null and winding == "" and Game.player != null:
		var d: int = maxi(absi(e.cell.x - Game.player.cell.x), absi(e.cell.y - Game.player.cell.y))
		if d > NEAR:
			_far_t -= delta
			if _far_t > 0.0:
				return
			_far_t = FAR_SKIP
			delta *= FAR_SKIP
	_attack_t = maxf(0.0, _attack_t - delta)
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - delta)
	if phased > 0.0:
		phased = maxf(0.0, phased - delta)
		if phased <= 0.0:
			e.modulate = Color.WHITE
	if fleeing > 0.0:
		fleeing = maxf(0.0, fleeing - delta)
	# a telegraphed power: the wind-up is a real pause, and it is where you get out of
	# the way or put something between you
	if winding != "":
		wind_t -= delta
		if wind_t <= 0.0:
			var w := winding
			winding = ""
			BeastPowers.fire(self, w, target)
		return
	if powers.has("regrow") and h.health() < h.max_health:
		# knits itself shut, unless the wound was a burn
		h.adjust("brute", -1.2 * delta * power, null)
	_step_t -= delta
	if _step_t > 0.0:
		return
	var m: CMob = e.c(&"mob")
	if m == null or m.moving or not m.can_move():
		_step_t = 0.2
		return
	_step_t = m.move_dur * (1.6 if target == null else 1.0)
	_look()
	# something that has just robbed you is not interested in fighting you
	if fleeing > 0.0:
		_flee()
		return
	if target != null and _try_power():
		return
	match behaviour:
		"grazer": _grazer()
		"hunter": _hunter()
		"ambush": _ambush()
		"pack": _pack()
		"territory": _territory()
		"drifter": _drifter()
		"swarm": _swarm()

## Pick a power and use it. The order in the list is the order it prefers, so a creature
## designed round one trick will reach for that trick first.
func _try_power() -> bool:
	if powers.is_empty() or target == null:
		return false
	var d := e.dist_to(target)
	for id in powers:
		var pid := String(id)
		if pid in ["split", "feign", "lure", "hoard", "regrow"]:
			continue  # passive; handled elsewhere
		if float(cooldowns.get(pid, 0.0)) > 0.0:
			continue
		var spec := BeastPowers.info(pid)
		if spec.is_empty():
			continue
		var reach := int(spec.get("range", 0))
		# the interesting ones are used at a distance; the close ones wait until adjacent
		if reach > 0 and d > reach:
			continue
		if reach == 0 and d > 6:
			continue
		if pid == "charge" and d < 3:
			continue  # a charge needs room to be a charge
		if Game.rng.randf() > 0.55:
			continue  # not every opening is taken, so fights are not scripted
		cooldowns[pid] = float(spec.get("cd", 8.0))
		if BeastPowers.use(self, pid, target):
			return true
	return false

## What can it see? Beasts notice mobs that are not their own kind.
func _look() -> void:
	if target != null and (not is_instance_valid(target) or target.removed):
		target = null
	if target != null:
		var th: CHealth = target.c(&"health")
		if th != null and th.dead:
			target = null
		elif e.dist_to(target) > sight + 4 or Game.time - last_seen > LOSE_INTEREST:
			target = null
			alert = maxf(0.0, alert - 0.4)
	if target != null:
		if anomalous or _can_see(target.cell):
			last_seen = Game.time
		return
	var best: Entity = null
	var bd := 9999
	for other in Game.in_radius(e.cell, sight, &"mob"):
		if other == e or other.removed:
			continue
		# Wildlife hunts people, not each other. Two hundred creatures on an island that
		# all consider each other prey is not an ecosystem, it is a mass extinction that
		# happens in the first ten seconds and leaves the island empty. Being attacked
		# still makes anything fight back, whatever attacked it (see on_attacked).
		if other.tags.has("beast"):
			continue
		var oh: CHealth = other.c(&"health")
		if oh == null or oh.dead:
			continue
		# a drifter does not need line of sight; everything else does
		if not anomalous and not _can_see(other.cell):
			continue
		var d := e.dist_to(other)
		if d < bd:
			bd = d
			best = other
	if best != null:
		target = best
		last_seen = Game.time

func _can_see(c: Vector2i) -> bool:
	# cheap line check against opaque turfs
	var a := e.cell
	var steps: int = maxi(absi(c.x - a.x), absi(c.y - a.y))
	for k in range(1, steps):
		var t := float(k) / float(steps)
		var p := Vector2i(roundi(lerpf(a.x, c.x, t)), roundi(lerpf(a.y, c.y, t)))
		if Game.map.is_opaque(p):
			return false
	return true

# ------------------------------------------------------------------ behaviours
func _grazer() -> void:
	if target != null and e.dist_to(target) <= 5:
		_flee()
		return
	_amble()

func _hunter() -> void:
	if target == null:
		_amble()
		return
	alert = minf(1.0, alert + 0.2)
	if e.adjacent(target):
		_bite()
	else:
		_toward(target.cell)

## Hold absolutely still until something is within reach, then commit. Being seen first
## costs it the ambush, which is why looking around is worth doing.
func _ambush() -> void:
	if hidden:
		e.modulate = Color(1, 1, 1, 0.35)
		if target != null and e.dist_to(target) <= 1:
			_spring()
		return
	if target == null:
		if Game.time - last_seen > 8.0:
			hidden = true
			e.modulate = Color(1, 1, 1, 0.35)
		return
	if e.adjacent(target):
		_bite()
	else:
		_toward(target.cell)

func _spring() -> void:
	hidden = false
	e.modulate = Color.WHITE
	alert = 1.0
	Game.visible_message(e.cell, "[b]%s bursts out of cover![/b]" % e.display_name.capitalize(), "bad")
	Sfx.play("swing", e.cell, 0.9)
	if Game.view:
		Game.view.shake(1.6)
	_bite()

## A pack animal will not press an attack on its own. Kill two of a pack of four and the
## rest lose their nerve.
func _pack() -> void:
	if target == null:
		_amble()
		return
	var friends := 0
	for other in Game.in_radius(e.cell, 7, &"beastai"):
		if other != e and str(other.tags.get("beast", "")) == beast:
			var oh: CHealth = other.c(&"health")
			if oh != null and not oh.dead:
				friends += 1
	if friends < 1:
		# alone: circle at a distance rather than commit
		alert = maxf(0.0, alert - 0.1)
		if e.dist_to(target) < 4:
			_flee()
		return
	alert = minf(1.0, alert + 0.15)
	if e.adjacent(target):
		_bite()
	else:
		_toward(target.cell)

## Ignores you entirely until you come inside its patch, then drives you out of it and
## goes home.
func _territory() -> void:
	var from_home := maxi(absi(e.cell.x - _home.x), absi(e.cell.y - _home.y))
	if target != null and maxi(absi(target.cell.x - _home.x), absi(target.cell.y - _home.y)) <= 6:
		if e.adjacent(target):
			_bite()
		else:
			_toward(target.cell)
		return
	if from_home > 7:
		_toward(_home)
		return
	_amble()

## Walks through walls, cannot be blocked, and does not care what you do about it.
func _drifter() -> void:
	if target == null:
		_amble()
		return
	if e.adjacent(target):
		_bite()
		return
	var d := _step_toward(target.cell)
	var to: Vector2i = e.cell + d
	if Game.map.inb(to) and (flying or Falling.supported(to)):
		e.place(to)
		e.c(&"mob").face(Defs.dir_from_vec(d))

func _swarm() -> void:
	if target == null:
		_amble()
		return
	if e.adjacent(target):
		_bite()
	else:
		_toward(target.cell)

# ------------------------------------------------------------------ movement
func _amble() -> void:
	if Game.rng.randf() < 0.45:
		return
	if _wander == Vector2i.ZERO or Game.rng.randf() < 0.3:
		_wander = Defs.DIRS4[Game.rng.randi() % 4]
	_try(_wander)

func _flee() -> void:
	if target == null:
		return
	var away := e.cell - target.cell
	_try(Vector2i(signi(away.x), signi(away.y)))

func _toward(c: Vector2i) -> void:
	_try(_step_toward(c))

func _step_toward(c: Vector2i) -> Vector2i:
	var d := c - e.cell
	return Vector2i(signi(d.x), signi(d.y))

## Never step into open sky unless you have wings. This is the rule that makes ledges
## useful and keeps the island's wildlife on the island.
func _try(d: Vector2i) -> bool:
	if d == Vector2i.ZERO:
		return false
	var m: CMob = e.c(&"mob")
	if m == null:
		return false
	var to: Vector2i = e.cell + d
	if not flying and not Falling.supported(to):
		# try to slide round the gap rather than stop dead at it
		for alt in [Vector2i(d.x, 0), Vector2i(0, d.y), Vector2i(-d.y, d.x), Vector2i(d.y, -d.x)]:
			if alt != Vector2i.ZERO and Falling.supported(e.cell + alt):
				return m.try_step(alt)
		return false
	if m.try_step(d):
		return true
	if d.x != 0 and d.y != 0:
		return m.try_step(Vector2i(d.x, 0)) or m.try_step(Vector2i(0, d.y))
	return false

# ------------------------------------------------------------------ attacking
func bite_now(t: Entity) -> void:
	var save := target
	target = t
	_attack_t = 0.0
	_bite()
	target = save

func _bite() -> void:
	if target == null or _attack_t > 0.0 or damage <= 0.0:
		return
	_attack_t = 1.1
	var m: CMob = e.c(&"mob")
	if m != null:
		m.face(Defs.dir_from_vec(target.cell - e.cell))
	var th: CHealth = target.c(&"health")
	if th == null:
		return
	# a glancing blow if they are quick on their feet
	var dodge: float = clampf(Skills.level(target, "evasion") * 0.004, 0.0, 0.35)
	if Game.rng.randf() < dodge:
		Game.visible_message(e.cell, "%s lunges at %s and misses." % [e.display_name.capitalize(), target.display_name], "combat_warn")
		Skills.add_xp(target, "evasion", 6.0)
		return
	var dealt: float = damage * Game.rng.randf_range(0.8, 1.2)
	# armour worn is worth something, and so is knowing what this thing does
	th.take_damage(dealt, "brute", e)
	Game.visible_message(e.cell, "[b]%s tears into %s![/b]" % [e.display_name.capitalize(), target.display_name], "combat")
	Fx.attack_effect(target.position, "smash")
	Sfx.play("hit", target.cell, 0.8)
	Bus.stimulus.emit({"type": "attack", "actor": e, "target": target, "cell": target.cell, "loud": 4.0})

## Being hit makes anything defend itself, and makes a pack commit.
func on_attacked(by: Entity) -> void:
	if by == null or by == e:
		return
	if disguised:
		disguised = false
		Game.visible_message(e.cell, "[b]It was not what it looked like.[/b]", "bad")
	# a creature that plays dead gets one free ambush out of it
	if powers.has("feign") and not e.tags.get("feigned", false):
		e.tags["feigned"] = true
	last_hit_by = by
	target = by
	last_seen = Game.time
	hidden = false
	e.modulate = Color.WHITE
	alert = 1.0
	if behaviour == "grazer":
		return
	for other in Game.in_radius(e.cell, 8, &"beastai"):
		if other != e and str(other.tags.get("beast", "")) == beast:
			var oai: CBeastAI = other.c(&"beastai")
			if oai != null and oai.target == null:
				oai.target = by
				oai.last_seen = Game.time
				oai.hidden = false
				other.modulate = Color.WHITE

func examine(_user: Entity, lines: Array) -> void:
	if hidden:
		return
	var h: CHealth = e.c(&"health")
	if h != null and not h.dead:
		var frac := h.health() / maxf(1.0, h.max_health)
		var word := "unhurt"
		if frac < 0.25: word = "[color=#ff6a6a]barely standing[/color]"
		elif frac < 0.55: word = "[color=#e8a83a]badly hurt[/color]"
		elif frac < 0.9: word = "hurt"
		lines.append("It looks %s." % word)
	if alert > 0.6:
		lines.append("[color=#ff8a5a]It has seen you.[/color]")
	if anomalous:
		lines.append("[i]Something about it does not resolve properly.[/i]")
	if power > 1.5:
		lines.append("[color=#e8a83a]It is bigger than the ones nearer home.[/color]")
	# Beastlore is the skill that turns "something killed me" into "I know what that does".
	# Every level of it reveals one more of a creature's tricks.
	var known := 0
	if _user != null:
		known = 1 + int(Skills.frac(_user, "beastlore") * 4.0)
	var shown := 0
	for id in powers:
		if shown >= known:
			lines.append("[color=#8aa0b4]It does something else you have not worked out yet.[/color]")
			break
		var desc := BeastPowers.describe(String(id))
		if desc == "":
			continue
		lines.append("[color=#c88ae8]%s[/color]" % desc)
		shown += 1
	if _user != null and shown > 0:
		Skills.add_xp(_user, "beastlore", 3.0)

func ai_tags(out: Dictionary) -> void:
	out["beast"] = true
	out["hostile"] = damage > 0.0
