class_name CShipGun extends Component
## A ship's gun on a swivel. The "gun mounts are scenery" note in NOTES.md, answered.
##
## A mount has an arc, not a turret: it swings roughly ninety degrees either side of the
## beam it is bolted to, which is why a frigate carries them down both sides and why the
## interesting part of a gun fight is getting your broadside onto somebody who is trying
## very hard to show you his stern.
##
## Firing is a click on a target, or the gunner's order from the helm. Everything a shot
## does — damage, reach, spread, reload — comes out of the module's stat block, so
## upgrading a mount is felt immediately and the shop's numbers are the real ones.

const ARC := 1.25 # radians either side of the mount's own bearing

var ship_id := -1
var mod := "gun_swivel"
var cooldown := 0.0
var loaded := true
var bearing := 0.0 # world radians the mount is trained on
var shots := 0

func key() -> StringName:
	return &"shipgun"

func ship() -> Airship:
	return Game.fleet.get_ship(ship_id) if Game.fleet else null

func damage() -> float:
	return ShipParts.stat(mod, "gun_damage", 20.0)

func reach() -> float:
	return ShipParts.stat(mod, "gun_range", 10.0)

func reload_time() -> float:
	return ShipParts.stat(mod, "gun_reload", 3.5)

func spread() -> float:
	return ShipParts.stat(mod, "gun_spread", 0.15)

func process(delta: float) -> void:
	if cooldown > 0.0:
		cooldown = maxf(0.0, cooldown - delta)
		if cooldown <= 0.0 and not loaded:
			loaded = true
			# a lance recharges off the bus rather than being rammed, and says so
			if ShipParts.has_quirk(mod, "lance"):
				Sfx.play("shimmer", e.cell, 0.4)

## Which way the mount naturally points: outboard, off the beam it stands nearest.
func mount_bearing() -> float:
	var sh := ship()
	if sh == null:
		return 0.0
	var local := sh.local_of(e.cell)
	var b := ShipPlan.bounds(sh.cells_map)
	var mid := float(b.position.y) + float(b.size.y - 1) * 0.5
	var out := 1.0 if float(local.y) >= mid else -1.0
	# starboard is +90 degrees from the bow in screen space
	return wrapf(sh.angle + out * PI * 0.5, -PI, PI)

func in_arc(target_cell: Vector2i) -> bool:
	var to := Vector2(target_cell - e.cell)
	if to.length() < 0.01:
		return false
	return absf(wrapf(to.angle() - mount_bearing(), -PI, PI)) <= ARC

# ------------------------------------------------------------------ firing
func can_fire(user: Entity) -> String:
	if not loaded or cooldown > 0.0:
		return "still reloading"
	var m: CMachine = e.c(&"machine")
	if m != null and m.broken:
		return "wrecked"
	if ShipParts.stat(mod, "power", 0.0) < 0.0:
		var sh := ship()
		if sh != null and not sh.has_power():
			return "no power on the bus"
	if user != null and Skills.level(user, "gunnery") < 1:
		return ""
	return ""

## Fire at a world cell. Returns true if a shot went off.
func fire(user: Entity, at: Vector2i) -> bool:
	var why := can_fire(user)
	if why != "":
		if user != null:
			Game.tell(user, "The %s is %s." % [e.display_name, why], "warn")
		return false
	var d := Vector2(at - e.cell)
	if d.length() > reach() + 0.5:
		if user != null:
			Game.tell(user, "Out of reach — the %s throws about %d tiles." % [e.display_name, int(reach())], "warn")
		return false
	if not in_arc(at):
		if user != null:
			Game.tell(user, "The mount will not train that far round. Bring her beam onto it.", "warn")
		return false
	loaded = false
	var skill := Skills.frac(user, "gunnery") if user != null else 0.0
	cooldown = reload_time() * (1.0 - skill * 0.45)
	shots += 1
	bearing = d.angle()
	Sfx.play("explosion", e.cell, 0.55)
	Fx.sparks(e.cell)
	if Game.view:
		Game.view.shake(2.2)
	Game.visible_message(e.cell, "[b]%s fires.[/b]" % e.display_name.capitalize(), "combat")
	if ShipParts.has_quirk(mod, "scatter"):
		_scatter(user, at, skill)
	elif ShipParts.has_quirk(mod, "lance"):
		_lance(user, at, skill)
	elif ShipParts.has_quirk(mod, "tether"):
		_harpoon(user, at, skill)
	else:
		_ball(user, at, skill)
	if user != null:
		Skills.add_xp(user, "gunnery", 12.0)
	Bus.stimulus.emit({"type": "gunshot", "actor": user, "cell": e.cell, "loud": 22.0})
	return true

## A single ball along a line, stopping at the first thing it meets.
func _ball(user: Entity, at: Vector2i, skill: float) -> void:
	var aim := _scatter_cell(at, spread() * (1.0 - skill * 0.6))
	var hit := _trace(aim)
	_impact(user, hit, damage())

## Punches through: keeps going after the first target, for as far as it has left.
func _lance(user: Entity, at: Vector2i, skill: float) -> void:
	var aim := _scatter_cell(at, spread() * (1.0 - skill * 0.6))
	var line := _line(e.cell, aim)
	var pierced := 0
	for c in line:
		if _impact(user, c, damage() * (1.0 - pierced * 0.18)):
			pierced += 1
			if pierced >= 3:
				return
	Fx.beam(e.cell, aim, Color("#9ad8ff"))

## A cone of small shot. Murderous on anything with wings, useless against planking.
func _scatter(user: Entity, at: Vector2i, skill: float) -> void:
	var base := Vector2(at - e.cell).angle()
	var n := 5 + int(skill * 4.0)
	var dist: float = minf(reach(), Vector2(at - e.cell).length())
	for i in n:
		var a := base + Game.rng.randf_range(-spread(), spread())
		var c := e.cell + Vector2i(Vector2(cos(a), sin(a)) * dist)
		var hit := _trace(c)
		_impact(user, hit, damage(), true)

## A barbed hook on a drum of line. Whatever it hits is now attached to your ship, which
## is either a salvage technique or a serious mistake.
func _harpoon(user: Entity, at: Vector2i, skill: float) -> void:
	var aim := _scatter_cell(at, spread() * (1.0 - skill * 0.6))
	var hit := _trace(aim)
	var struck := false
	for ent in Game.at(hit):
		if ent.has_c(&"health") or ent.has_c(&"item"):
			struck = true
			_impact(user, hit, damage())
			ent.tags["tethered_to"] = e.get_instance_id()
			Game.visible_message(hit, "[b]The harpoon line goes taut.[/b]", "warn")
			break
	if not struck:
		_impact(user, hit, damage())

func _scatter_cell(at: Vector2i, sp: float) -> Vector2i:
	if sp <= 0.001:
		return at
	var d := Vector2(at - e.cell)
	var a := d.angle() + Game.rng.randf_range(-sp, sp)
	return e.cell + Vector2i(Vector2(cos(a), sin(a)) * d.length())

## First thing on the line that stops a shot.
func _trace(to: Vector2i) -> Vector2i:
	var last := e.cell
	for c in _line(e.cell, to):
		last = c
		if not Game.map.inb(c):
			return last
		if Game.map.is_solid_turf(c) or Game.map.structure[Game.map.idx(c)] != Defs.S_NONE:
			return c
		for ent in Game.at(c):
			if ent.has_c(&"health"):
				return c
	return last

static func _line(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	for k in range(1, steps + 1):
		var t := float(k) / float(maxi(1, steps))
		out.append(Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))))
	return out

## Land a shot on a cell. Returns true if it hit something living.
func _impact(user: Entity, c: Vector2i, dmg: float, small := false) -> bool:
	if not Game.map.inb(c):
		return false
	Fx.sparks(c)
	var hit := false
	for ent in Game.at(c).duplicate():
		var h: CHealth = ent.c(&"health")
		if h != null and not h.dead:
			h.take_damage(dmg * Game.rng.randf_range(0.85, 1.15), "brute", user)
			Game.visible_message(c, "[b]%s is struck![/b]" % ent.display_name.capitalize(), "combat")
			hit = true
			continue
		if ent.has_c(&"blocker") and not small:
			ent.take_damage(dmg, "brute", user)
	if not hit and not small:
		# a ball that finds a hull rather than a person still does its job
		var sh: Airship = Game.fleet.ship_at(c) if Game.fleet else null
		if sh != null and sh != ship():
			var soak: float = sh.armor_at(c)
			if dmg > soak:
				sh.breach(c)
			_tell_target(sh)
		elif Game.map.is_rock(c) and dmg > 30.0:
			# heavy shot shears rock off an island lip, which is a demolition technique
			Interact.mine(c, user)
	# a lift cell is the thing worth shooting, and hitting one is what brings a ship down
	for ent in Game.at(c):
		var lc: CLiftCell = ent.c(&"liftcell")
		if lc != null:
			lc.take_damage(dmg, "brute", user)
			var owner: Airship = Game.fleet.ship_at(c) if Game.fleet else null
			if owner != null and owner != ship():
				_tell_target(owner)
	Sfx.play("wall_hit", c, 0.5)
	return hit

## Whoever we just hit should know who hit them, and decide what to do about it.
func _tell_target(sh: Airship) -> void:
	if Game.fleet == null:
		return
	var cap: ShipAI = Game.fleet.ai_of(sh)
	if cap == null:
		return
	cap.on_hit(ship())
	# a hull that cannot hold itself up any more has lost
	if sh.buoyancy() < 0.45 and not sh.derelict:
		cap.on_wrecked(ship())
		sh.derelict = true
		Game.fleet.unregister_ai(sh)

# ------------------------------------------------------------------ player interface
func examine(user: Entity, lines: Array) -> void:
	var spec := ShipParts.get_mod(mod)
	if not spec.is_empty():
		lines.append("[color=%s]%s[/color] — %s" % [ShipParts.tier_color(mod),
			String(spec["name"]).capitalize(), "   ".join(ShipParts.stat_lines(mod))])
		var q := ShipParts.quirk_text(mod)
		if q != "":
			lines.append("[color=#e8a83a]%s[/color]" % q)
	lines.append("Bears [b]%s[/b], %d tiles, %s." % [_bearing_word(), int(reach()),
		"[color=#6ad88a]loaded[/color]" if loaded and cooldown <= 0.0 else "[color=#e8a83a]reloading (%.1fs)[/color]" % cooldown])
	if shots > 0:
		lines.append("[i]%d round%s fired from this mount.[/i]" % [shots, "" if shots == 1 else "s"])
	if user != null:
		lines.append("[i]Click a target inside the arc to fire.[/i]")

func _bearing_word() -> String:
	var a := rad_to_deg(mount_bearing())
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return names[int(round(fposmod(a, 360.0) / 45.0)) % 8]

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Sight along the mount", "priority": 20, "cb": func(): _sight(user)})

func _sight(user: Entity) -> void:
	var targets := []
	for ent in Game.in_radius(e.cell, int(reach()), &"health"):
		if ent == user or ent.removed:
			continue
		var h: CHealth = ent.c(&"health")
		if h == null or h.dead:
			continue
		if in_arc(ent.cell):
			targets.append(ent)
	if targets.is_empty():
		Game.tell(user, "Nothing in the arc. Bring her beam round.")
		return
	targets.sort_custom(func(a, b): return e.cell.distance_squared_to(a.cell) < e.cell.distance_squared_to(b.cell))
	Game.tell(user, "In the arc: %s." % ", ".join(targets.slice(0, 4).map(func(t): return t.display_name)))

## The click-to-fire path: the interaction layer routes a click on a distant cell to the
## nearest gun that can actually bear on it.
static func fire_from_ship(user: Entity, at: Vector2i) -> bool:
	if Game.fleet == null:
		return false
	var sh: Airship = Game.fleet.ship_of(user)
	if sh == null:
		return false
	var best: CShipGun = null
	var best_d := 1e9
	for g in sh.guns:
		if not is_instance_valid(g) or g.removed:
			continue
		var gc: CShipGun = g.c(&"shipgun")
		if gc == null or not gc.in_arc(at) or gc.can_fire(user) != "":
			continue
		var d := Vector2(at - g.cell).length()
		if d <= gc.reach() and d < best_d:
			best_d = d
			best = gc
	if best == null:
		return false
	return best.fire(user, at)

func ai_tags(out: Dictionary) -> void:
	out["gun"] = true
