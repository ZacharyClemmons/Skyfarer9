class_name BeastPowers extends RefCounted
## What a creature can do besides bite you.
##
## The bestiary's seven behaviours decide how a thing *moves*; this decides what makes it
## memorable. A frost wolf and a scrap hound are both pack hunters and they are not the
## same fight, because one of them circles and one of them pulls the wrench out of your
## hand and runs off with it.
##
## Every power here follows three rules, and they are the reason the fights are readable:
##   1. It is telegraphed. Something happens one turn before it lands.
##   2. It has a counter that is a decision you could have made. Stand somewhere else,
##      carry something different, put a wall between you, or kill it faster.
##   3. It does something the player can see happening to their world — an item on the
##      floor, a cell losing charge, a wall of web — rather than a number going down.

## id -> {name, cd, range, tell, desc}
##   cd     seconds between uses
##   range  tiles, 0 for self / adjacent
##   tell   what is printed the moment before it happens
const POWERS := {
	"charge": {"name": "charge", "cd": 9.0, "range": 7, "warn": true,
		"tell": "%s drops its head and digs in.",
		"desc": "Runs the line between you in one movement and knocks you flat. Break line of sight or stand behind something."},
	"leap": {"name": "leap", "cd": 7.0, "range": 6, "warn": true,
		"tell": "%s coils.",
		"desc": "Clears gaps, rails and walls. A ledge is not cover from this."},
	"spit": {"name": "spit", "cd": 5.0, "range": 6, "warn": false,
		"tell": "%s rears back.",
		"desc": "A ranged glob that burns and sticks. Move out of the line."},
	"web": {"name": "web", "cd": 12.0, "range": 5, "warn": true,
		"tell": "%s draws something back through its mouthparts.",
		"desc": "Roots you where you stand for a few seconds. Cut it, burn it, or do not be there."},
	"drain": {"name": "drain", "cd": 8.0, "range": 1, "warn": false,
		"tell": "",
		"desc": "Takes the charge out of aetherite — lift cells, weapon cells, anything holding it. \
This is how a ship is brought down."},
	"burrow": {"name": "burrow", "cd": 14.0, "range": 0, "warn": false,
		"tell": "%s goes into the ground.",
		"desc": "Gone, and then somewhere else. It comes up next to you."},
	"split": {"name": "split", "cd": 0.0, "range": 0, "warn": false,
		"tell": "",
		"desc": "Killing it makes two smaller ones. Fire stops that."},
	"summon": {"name": "call", "cd": 24.0, "range": 0, "warn": true,
		"tell": "%s throws its head back and calls.",
		"desc": "Brings more of its kind. Kill the caller first."},
	"magnetize": {"name": "pull", "cd": 10.0, "range": 5, "warn": true,
		"tell": "%s hums, and everything iron on you leans toward it.",
		"desc": "Rips metal out of your hands. Carry something that is not iron."},
	"steal": {"name": "snatch", "cd": 11.0, "range": 1, "warn": false,
		"tell": "",
		"desc": "Takes one thing and runs. Kill it and you get it back."},
	"phase": {"name": "phase", "cd": 13.0, "range": 0, "warn": false,
		"tell": "%s stops being entirely present.",
		"desc": "Cannot be hit for a few seconds. Wait it out; chasing it is how you find the others."},
	"chill": {"name": "chill", "cd": 6.0, "range": 3, "warn": false,
		"tell": "",
		"desc": "The air round it goes to nothing. You slow down and you keep slowing."},
	"ignite": {"name": "ignite", "cd": 7.0, "range": 2, "warn": false,
		"tell": "%s glows from the inside.",
		"desc": "Sets the ground, and you, alight. Do not fight it on a wooden deck."},
	"static": {"name": "arc", "cd": 6.0, "range": 4, "warn": false,
		"tell": "",
		"desc": "Arcs to everything nearby and empties aether cells. Spread out."},
	"shriek": {"name": "shriek", "cd": 30.0, "range": 0, "warn": true,
		"tell": "[b]%s opens its mouth far too wide.[/b]",
		"desc": "Calls everything on the island. Kill it quickly or leave quickly."},
	"gaze": {"name": "gaze", "cd": 10.0, "range": 8, "warn": false,
		"tell": "",
		"desc": "Looking at it costs you. Fight it with something between you, or in the dark."},
	"regrow": {"name": "knit", "cd": 4.0, "range": 0, "warn": false,
		"tell": "",
		"desc": "Closes its own wounds. Burn damage does not knit."},
	"tether": {"name": "haul", "cd": 9.0, "range": 6, "warn": true,
		"tell": "%s throws out a line.",
		"desc": "Pulls you to it. If you were standing near an edge, that is now relevant."},
	"feign": {"name": "play dead", "cd": 0.0, "range": 0, "warn": false,
		"tell": "",
		"desc": "It is not dead. It is waiting for you to walk past."},
	"lure": {"name": "lure", "cd": 0.0, "range": 0, "warn": false,
		"tell": "",
		"desc": "Looks like something worth picking up, until you pick it up."},
	"hoard": {"name": "hoard", "cd": 0.0, "range": 0, "warn": false,
		"tell": "",
		"desc": "Carries what it has taken from everyone else. Worth killing for that alone."},
	"mimic": {"name": "mimic", "cd": 16.0, "range": 9, "warn": false,
		"tell": "",
		"desc": "Says things in voices it has heard. Some of them will be yours."},
	"echo": {"name": "step", "cd": 11.0, "range": 8, "warn": true,
		"tell": "%s is not where it was.",
		"desc": "Moves to where you were a moment ago. Do not stand still and do not walk in a line."},
}

static func info(id: String) -> Dictionary:
	return POWERS.get(id, {})

static func describe(id: String) -> String:
	var p := info(id)
	return String(p.get("desc", ""))

# ------------------------------------------------------------------ firing
## Try one power. Returns true if it went off (the AI then skips its ordinary turn).
static func use(ai: CBeastAI, id: String, target: Entity) -> bool:
	var e := ai.e
	var p := info(id)
	if p.is_empty() or target == null or not is_instance_valid(target):
		return false
	var reach := int(p.get("range", 0))
	if reach > 0 and e.dist_to(target) > reach:
		return false
	var tell := String(p.get("tell", ""))
	if tell != "" and bool(p.get("warn", false)):
		# a telegraph is one turn of warning, and it is the whole reason these are fair
		Game.visible_message(e.cell, tell % e.display_name.capitalize(), "combat_warn")
		ai.winding = id
		ai.wind_t = 0.9
		return true
	return fire(ai, id, target)

## Actually do it. Split out so a telegraphed power lands a beat after its warning.
static func fire(ai: CBeastAI, id: String, target: Entity) -> bool:
	var e := ai.e
	if target == null or not is_instance_valid(target) or target.removed:
		return false
	match id:
		"charge": return _charge(ai, e, target)
		"leap": return _leap(ai, e, target)
		"spit": return _spit(ai, e, target)
		"web": return _web(ai, e, target)
		"drain": return _drain(ai, e, target)
		"burrow": return _burrow(ai, e, target)
		"summon": return _summon(ai, e, target)
		"magnetize": return _magnetize(ai, e, target)
		"steal": return _steal(ai, e, target)
		"phase": return _phase(ai, e)
		"chill": return _chill(ai, e)
		"ignite": return _ignite(ai, e, target)
		"static": return _static(ai, e, target)
		"shriek": return _shriek(ai, e)
		"gaze": return _gaze(ai, e, target)
		"tether": return _tether(ai, e, target)
		"mimic": return _mimic(ai, e, target)
		"echo": return _echo(ai, e, target)
	return false

# ------------------------------------------------------------------ the powers
static func _charge(ai: CBeastAI, e: Entity, t: Entity) -> bool:
	var line := _line(e.cell, t.cell)
	var land := e.cell
	for c in line:
		if not Game.map.is_passable(c) or (not ai.flying and not Falling.supported(c)):
			break
		land = c
	if land == e.cell:
		return false
	e.place(land)
	Sfx.play("whoosh", land, 0.9)
	if Game.view:
		Game.view.shake(3.0)
	if e.adjacent(t):
		var h: CHealth = t.c(&"health")
		if h != null:
			h.take_damage(ai.damage * 1.6, "brute", e)
			if h.has_method("knockdown"):
				h.knockdown(30.0)
			Game.visible_message(t.cell, "[b]%s slams into %s and puts them down.[/b]" % [
				e.display_name.capitalize(), t.display_name], "combat")
			# a charge on a weather deck throws people toward the rail, which is the point
			_shove_away(t, t.cell - e.cell)
	return true

static func _leap(ai: CBeastAI, e: Entity, t: Entity) -> bool:
	# a leap ignores walls, gaps and rails, which is what makes a ledge stop being safety
	var spot := t.cell
	if not Game.map.is_passable(spot):
		for d in Defs.DIRS8:
			if Game.map.is_passable(t.cell + d):
				spot = t.cell + d
				break
	if spot == e.cell:
		return false
	e.place(spot)
	Sfx.play("whoosh", spot, 0.8)
	Fx.smoke_puff(spot)
	Game.visible_message(spot, "[b]%s lands beside %s.[/b]" % [e.display_name.capitalize(), t.display_name], "combat")
	ai.bite_now(t)
	return true

static func _spit(ai: CBeastAI, e: Entity, t: Entity) -> bool:
	var hit := _first_block(e.cell, t.cell)
	Fx.beam(e.cell, hit, Color("#a8d86a"))
	Sfx.play("spray", hit, 0.6)
	for ent in Game.at(hit):
		var h: CHealth = ent.c(&"health")
		if h != null and not h.dead:
			h.take_damage(ai.damage * 0.8, "burn", e)
			SkyBuffs.apply(ent, "sticky", 0.5, 8.0, e.display_name)
			Game.tell(ent, "[color=#a8d86a]It burns, and it clings.[/color]", "bad")
	return true

static func _web(ai: CBeastAI, e: Entity, t: Entity) -> bool:
	SkyBuffs.apply(t, "sticky", 3.0, 6.0, e.display_name)
	Fx.beam(e.cell, t.cell, Color("#d8d8c8"))
	Game.visible_message(t.cell, "[b]%s is caught fast.[/b]" % t.display_name.capitalize(), "combat")
	if Proto.has("web"):
		Proto.spawn("web", t.cell)
	return true

## The power that makes a creature a threat to a ship rather than to a person.
static func _drain(ai: CBeastAI, e: Entity, t: Entity) -> bool:
	var took := false
	var sh: Airship = Game.fleet.ship_at(e.cell) if Game.fleet != null else null
	if sh != null:
		for l in sh.lift_cells:
			if e.dist_to(l) > 2:
				continue
			var lc: CLiftCell = l.c(&"liftcell")
			if lc != null and lc.charge > 0.05:
				lc.charge = maxf(0.0, lc.charge - 0.12)
				took = true
		if took:
			Game.visible_message(e.cell, "[b][color=#ff8a5a]%s is drinking the lift cells dry.[/color][/b]" % e.display_name.capitalize(), "bad")
	var inv: CInventory = t.c(&"inv")
	if inv != null:
		for it in inv.all_items(true):
			var g: CAetherGun = it.c(&"aethergun")
			if g != null and g.cell_charge > 0:
				g.cell_charge = maxi(0, g.cell_charge - 3)
				took = true
	if took:
		Sfx.play("shimmer", e.cell, 0.7)
		var h: CHealth = e.c(&"health")
		if h != null:
			h.adjust("brute", -6.0, null)  # it feeds
	return took

static func _burrow(ai: CBeastAI, e: Entity, t: Entity) -> bool:
	Fx.smoke_puff(e.cell)
	Sfx.play("dig", e.cell, 0.7)
	for d in Defs.DIRS8:
		var c: Vector2i = t.cell + d
		if Game.map.is_passable(c) and Falling.supported(c) and Game.at(c).is_empty():
			e.place(c)
			Game.visible_message(c, "[b]%s comes up out of the ground.[/b]" % e.display_name.capitalize(), "combat")
			Fx.smoke_puff(c)
			return true
	return false

static func _summon(ai: CBeastAI, e: Entity, t: Entity) -> bool:
	Sfx.play("alarm", e.cell, 0.7)
	var made := 0
	for _i in Game.rng.randi_range(2, 3):
		for _try in 12:
			var c: Vector2i = e.cell + Vector2i(Game.rng.randi_range(-4, 4), Game.rng.randi_range(-4, 4))
			if not Game.map.is_passable(c) or not Falling.supported(c) or not Game.at(c).is_empty():
				continue
			var m := SkyMobs.spawn(ai.beast, c, ai.power * 0.8)
			if m != null:
				var mai: CBeastAI = m.c(&"beastai")
				if mai != null:
					mai.target = t
					mai.last_seen = Game.time
				made += 1
			break
	if made > 0:
		Game.visible_message(e.cell, "[b][color=#ff8a5a]%d more come out of the dark.[/color][/b]" % made, "bad")
	return made > 0

## Iron out of your hands. Carry chitin and it does nothing.
static func _magnetize(ai: CBeastAI, e: Entity, t: Entity) -> bool:
	var inv: CInventory = t.c(&"inv")
	if inv == null:
		return false
	var pulled := 0
	for i in 2:
		var held: Entity = inv.hands[i]
		if held == null or not is_instance_valid(held):
			continue
		if not _is_iron(held):
			continue
		inv.drop(held, e.cell)
		Fx.beam(t.cell, e.cell, Color("#8aa0b4"))
		pulled += 1
	if pulled > 0:
		Sfx.play("ratchet", e.cell, 0.8)
		Game.tell(t, "[b][color=#ff8a5a]It tears the iron out of your hands.[/color][/b]", "bad")
	return pulled > 0

static func _is_iron(it: Entity) -> bool:
	if it.proto in ["iron_ingot", "sheet_metal", "rods", "salvage_scrap"]:
		return true
	var ci: CItem = it.c(&"item")
	if ci == null:
		return false
	return ci.cat in ["tool", "weapon"] and not it.proto.begins_with("chitin")

## Takes one thing and leaves. Kill it and you get it back, which is the point.
static func _steal(ai: CBeastAI, e: Entity, t: Entity) -> bool:
	var inv: CInventory = t.c(&"inv")
	if inv == null:
		return false
	var loot: Entity = null
	for i in 2:
		if inv.hands[i] != null and is_instance_valid(inv.hands[i]):
			loot = inv.hands[i]
			break
	if loot == null:
		return false
	inv.drop(loot, e.cell)
	var mine: CInventory = e.c(&"inv")
	if mine != null:
		mine.put_in_hands(loot)
	e.tags["stolen"] = true
	ai.fleeing = 14.0
	Game.tell(t, "[b][color=#ff8a5a]%s snatches %s and bolts.[/color][/b]" % [
		e.display_name.capitalize(), loot.display_name], "bad")
	Sfx.play("pickup", e.cell, 0.8)
	return true

static func _phase(ai: CBeastAI, e: Entity) -> bool:
	ai.phased = 4.0
	e.modulate = Color(1, 1, 1, 0.3)
	Fx.smoke_puff(e.cell)
	Game.visible_message(e.cell, "[i]%s thins out until it is barely there.[/i]" % e.display_name.capitalize(), "warn")
	return true

static func _chill(ai: CBeastAI, e: Entity) -> bool:
	if Game.atmos != null and Game.map.inb(e.cell):
		Game.atmos.add_heat(Game.map.idx(e.cell), -42000.0)
	var got := false
	for ent in Game.in_radius(e.cell, 3, &"health"):
		if ent == e:
			continue
		SkyBuffs.apply(ent, "chill", 1.0, 10.0, e.display_name)
		SkyBuffs.apply(ent, "slow", 0.45, 10.0, e.display_name)
		var h: CHealth = ent.c(&"health")
		if h != null:
			h.take_damage(3.0, "burn", e)
		got = true
	if got:
		Fx.frost_burst(e.cell)
	return got

static func _ignite(ai: CBeastAI, e: Entity, t: Entity) -> bool:
	if Game.atmos != null and Game.map.inb(t.cell):
		Game.atmos.add_heat(Game.map.idx(t.cell), 140000.0)
	Fx.flame_on(t)
	var h: CHealth = t.c(&"health")
	if h != null:
		h.take_damage(ai.damage * 0.7, "burn", e)
	SkyBuffs.apply(t, "scorch", 1.0, 14.0, e.display_name)
	Game.visible_message(t.cell, "[b][color=#ff8a5a]The air round %s catches.[/color][/b]" % t.display_name, "bad")
	return true

static func _static(ai: CBeastAI, e: Entity, t: Entity) -> bool:
	var hit := 0
	for ent in Game.in_radius(e.cell, 4, &"health"):
		if ent == e:
			continue
		var h: CHealth = ent.c(&"health")
		if h == null or h.dead:
			continue
		h.take_damage(ai.damage * 0.55, "burn", e)
		Fx.beam(e.cell, ent.cell, Color("#9ad8ff"))
		SkyBuffs.apply(ent, "static", 1.0, 8.0, e.display_name)
		var inv: CInventory = ent.c(&"inv")
		if inv != null:
			for it in inv.all_items(true):
				var g: CAetherGun = it.c(&"aethergun")
				if g != null:
					g.cell_charge = maxi(0, g.cell_charge - 2)
		hit += 1
	if hit > 0:
		Sfx.play("spark", e.cell, 0.8)
	return hit > 0

static func _shriek(ai: CBeastAI, e: Entity) -> bool:
	Sfx.play("alarm", e.cell, 1.0)
	if Game.view:
		Game.view.shake(3.0)
	var n := 0
	for other in Game.in_radius(e.cell, 26, &"beastai"):
		if other == e:
			continue
		var oai: CBeastAI = other.c(&"beastai")
		if oai == null or oai.target != null:
			continue
		oai.target = ai.target
		oai.last_seen = Game.time
		oai.hidden = false
		other.modulate = Color.WHITE
		n += 1
	Game.visible_message(e.cell, "[b][color=#ff6a6a]The island answers it.[/color][/b]" if n > 3
		else "[color=#e8a83a]Something answers, a long way off.[/color]", "bad")
	return true

## It costs you to look at it. In the dark, or behind a wall, it does nothing.
static func _gaze(ai: CBeastAI, e: Entity, t: Entity) -> bool:
	if not ai._can_see(t.cell):
		return false
	if Game.lighting != null and Game.lighting.has_method("player_can_see") and t == Game.player:
		if not Game.lighting.player_can_see(e.cell):
			return false
	var h: CHealth = t.c(&"health")
	if h == null:
		return false
	h.take_damage(ai.damage * 0.5, "brute", e)
	SkyBuffs.apply(t, "blind", 1.0, 6.0, e.display_name)
	SkyBuffs.apply(t, "slow", 0.5, 6.0, e.display_name)
	Game.tell(t, "[b][color=#c88ae8]You look at it and something goes wrong behind your eyes.[/color][/b]", "bad")
	return true

static func _tether(ai: CBeastAI, e: Entity, t: Entity) -> bool:
	var line := _line(t.cell, e.cell)
	var land := t.cell
	for c in line:
		if not Game.map.is_passable(c):
			break
		land = c
	if land == t.cell:
		return false
	Fx.beam(e.cell, t.cell, Color("#8a7a5a"))
	t.place(land)
	Game.tell(t, "[b][color=#ff8a5a]Something takes hold and hauls.[/color][/b]", "bad")
	Sfx.play("whoosh", land, 0.7)
	return true

## It repeats what it heard, in the voice it heard it in.
static func _mimic(ai: CBeastAI, e: Entity, t: Entity) -> bool:
	var line: String = String(e.tags.get("heard", ""))
	if line == "":
		line = ["...", "hello?", "is anyone there", "do not go down there"][Game.rng.randi() % 4]
	Bus.speech.emit(e, line, e.cell, 9.0)
	Game.msg("[i]%s, in a voice you have heard before: \"%s\"[/i]" % [e.display_name.capitalize(), line], "warn")
	return true

## It goes to where you were, which teaches you not to walk in straight lines.
static func _echo(ai: CBeastAI, e: Entity, t: Entity) -> bool:
	var back: Vector2i = t.tags.get("last_cell", t.cell)
	if not Game.map.is_passable(back):
		return false
	Fx.smoke_puff(e.cell)
	e.place(back)
	Fx.smoke_puff(back)
	Sfx.play("shimmer", back, 0.6)
	return true

# ------------------------------------------------------------------ death powers
## Called when something with `split` dies. Fire stops it, which is the counter.
static func on_death(ai: CBeastAI, by_fire: bool) -> void:
	var e := ai.e
	if ai.powers.has("split") and not by_fire:
		var n := 0
		for d in Defs.DIRS4:
			var c: Vector2i = e.cell + d
			if not Game.map.is_passable(c) or not Falling.supported(c):
				continue
			var m := SkyMobs.spawn(ai.beast, c, ai.power * 0.5)
			if m != null:
				var mai: CBeastAI = m.c(&"beastai")
				if mai != null:
					mai.powers = ai.powers.filter(func(p): return p != "split")
					mai.target = ai.target
				n += 1
			if n >= 2:
				break
		if n > 0:
			Game.visible_message(e.cell, "[b][color=#ff8a5a]It comes apart into %d smaller ones.[/color][/b]" % n, "bad")
	if ai.powers.has("hoard"):
		# it has been robbing this island for years
		var box := e.cell
		for _i in Game.rng.randi_range(2, 5):
			var pick := Salvage.roll(Game.rng, 0.35 + ai.power * 0.1)
			if Proto.has(pick):
				Proto.spawn(pick, box)
		Game.visible_message(box, "[color=#e8c85a]Everything it had taken spills out.[/color]", "good")

# ------------------------------------------------------------------ helpers
static func _line(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	for k in range(1, steps + 1):
		var t := float(k) / float(maxi(1, steps))
		out.append(Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))))
	return out

static func _first_block(a: Vector2i, b: Vector2i) -> Vector2i:
	var last := a
	for c in _line(a, b):
		if not Game.map.inb(c) or Game.map.is_solid_turf(c):
			return last
		last = c
	return last

static func _shove_away(t: Entity, dir: Vector2i) -> void:
	var step := Vector2i(signi(dir.x), signi(dir.y))
	if step == Vector2i.ZERO:
		return
	for k in 2:
		var c: Vector2i = t.cell + step
		if not Game.map.inb(c) or Game.map.blocks_move_static(c):
			return
		# being shoved over the side is a real outcome, and it is why you do not fight
		# a charging animal with your back to the rail
		t.place(c)
		if not Falling.supported(c):
			Falling.begin(t)
			return
