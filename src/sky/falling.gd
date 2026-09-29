class_name Falling extends RefCounted
## The Cloudsea's one universal rule: there is no floor.
##
## Open sky is a turf like any other, so the tile grid, pathfinding and atmospherics all
## work unchanged — but anything standing on it that cannot fly falls out of the region.
##
## Falling off is meant to be a mistake you can see coming, not a twitch death. You never
## walk off a ledge at a walk: a deliberate step into open air is refused with a warning,
## and only a run, a shove, a throw, an explosion or a blackout will actually put you over
## the side. Once you are over, you have FREEFALL seconds to be saved — by a glider, by a
## grapple line, or by someone grabbing your arm — before the Deep takes you.

const FREEFALL := 2.6 # seconds of grace before you are gone
const LEDGE_CHANCE := 0.55 # base chance of catching the edge when you go over by accident

# ------------------------------------------------------------------ support
## Is there anything holding this cell up? Either the turf itself, or something built
## across the gap (a gangplank, a rope bridge, a ship's deck is its own turf).
static func supported(c: Vector2i) -> bool:
	var map := Game.map
	if map == null or not map.inb(c):
		return false
	if not Defs.is_void_turf(map.get_turf(c)):
		return true
	for e in Game.at(c):
		if e.tags.get("platform", false) and not e.removed:
			return true
	return false

## Can this mob be over open air without falling? Winged things, anything held up by a
## gene power, and anyone under a deployed glider.
static func airborne(e: Entity) -> bool:
	if e == null or e.removed:
		return false
	if e.tags.get("flying", false):
		return true
	var m: CMob = e.c(&"mob")
	if m != null and e.has_c(&"health"):
		var h: CHealth = e.c(&"health")
		if h.has_status("levitate"):
			return true
	var inv: CInventory = e.c(&"inv")
	if inv != null:
		var back := inv.worn("back")
		if back != null and back.tags.get("glider_open", false):
			return true
	return false

## Would stepping here be a fall? Used by the player controller (to refuse the step) and
## by mob AI (to never path into the sky in the first place).
static func would_fall(e: Entity, c: Vector2i) -> bool:
	return not supported(c) and not airborne(e)

# ------------------------------------------------------------------ going over
## Something is over open air. Returns true if it is now falling.
## `willing` is a deliberate jump: no ledge-grab, no panic.
static func check(e: Entity, willing := false) -> bool:
	if e == null or e.removed or e.holder != null:
		return false
	# A ship being restamped has its tiles off the map for one call. Anything it is
	# carrying is not over open sky, however it looks from here.
	if Game.fleet != null and Game.fleet.restamping_any():
		return false
	if e.tags.get("falling", false):
		return true
	if supported(e.cell) or airborne(e):
		return false
	if e.tags.get("anchored", true) == false and not e.has_c(&"mob") and not e.has_c(&"item"):
		pass # unanchored furniture falls like anything else
	# a thing that is not a mob and not loose (a wall fixture, a stamped ship part) stays
	if not e.has_c(&"mob") and not e.has_c(&"item") and not e.has_c(&"health") and e.tags.get("anchored", false):
		return false
	if e.has_c(&"mob") and not willing and _grab_ledge(e):
		return false
	begin(e)
	return true

## Last chance: grab the lip of the island you just walked off. Being knocked out, tied
## up, or carrying too much makes it much less likely.
static func _grab_ledge(e: Entity) -> bool:
	var h: CHealth = e.c(&"health")
	if h == null or h.dead:
		return false
	var m: CMob = e.c(&"mob")
	if m != null and m.is_lying():
		return false
	if h.has_status("unconscious") or h.has_status("paralysis"):
		return false
	# there has to be a lip within reach
	var lip := Vector2i(-9999, -9999)
	for d in Defs.DIRS8:
		if supported(e.cell + d):
			lip = e.cell + d
			break
	if lip.x < -9000:
		return false
	# quick hands and quick feet save you; being worn out does not
	var chance := LEDGE_CHANCE + Skills.level(e, "evasion") * 0.004 + Skills.attr_level(e, "agility") * 0.003
	if h.stamcrit:
		chance *= 0.35
	if h.stamina < 40.0:
		chance *= 0.7
	if Game.rng.randf() > chance:
		return false
	# caught it: you are on the ledge, winded and prone
	e.place(lip)
	h.knockdown(20.0)
	h.adjust("stamina", 25.0, null)
	Game.tell(e, "[b]You go over the edge[/b] — and catch the lip with both hands. You haul yourself back up, shaking.", "warn")
	Game.visible_message(e.cell, "%s goes over the edge and catches it!" % e.display_name, "warn")
	Sfx.play("hit", e.cell, 0.9)
	return true

## Commit: this thing is leaving the region.
static func begin(e: Entity) -> void:
	if e.tags.get("falling", false):
		return
	e.tags["falling"] = true
	e.tags["fall_t"] = FREEFALL
	var m: CMob = e.c(&"mob")
	if m != null:
		m.stop_pulling()
		if m.pulled_by != null and m.pulled_by.c(&"mob") != null:
			m.pulled_by.c(&"mob").stop_pulling()
		var h: CHealth = e.c(&"health")
		if h != null and not h.dead:
			Game.tell(e, "[b][color=#ff6a6a]You are falling.[/color][/b] The island shrinks above you. The air roars.", "bad")
			Game.visible_message(e.cell, "[b]%s falls into the open sky![/b]" % e.display_name, "bad")
			Bus.chronicle.emit("%s went over the side." % e.display_name, 3)
			Sfx.play("whoosh", e.cell, 1.0)
	elif e.has_c(&"item"):
		Game.visible_message(e.cell, "%s tumbles away into the sky." % e.the(), "emote")
	Game.sky.add_faller(e)

## A rescue: something caught them (a grapple, a glider opening, a hand).
static func rescue(e: Entity, to: Vector2i) -> void:
	if not e.tags.get("falling", false):
		return
	e.tags.erase("falling")
	e.tags.erase("fall_t")
	Game.sky.remove_faller(e)
	e.scale = Vector2.ONE
	e.modulate = Color.WHITE
	e.place(to)
	var h: CHealth = e.c(&"health")
	if h != null:
		h.knockdown(14.0)
	Game.tell(e, "[b]Caught.[/b] You are hauled back onto solid ground.", "good")

## Nobody caught them. Gone.
static func consume(e: Entity) -> void:
	if e == null or e.removed:
		return
	var h: CHealth = e.c(&"health")
	if h != null and not h.dead:
		if e == Game.player:
			Game.msg("[b][color=#ff4a4a]You fall out of the sky.[/color][/b]", "bad")
		Bus.chronicle.emit("%s was lost to the Deep." % e.display_name, 4)
		h.adjust("brute", 500.0, null) # the ground, eventually
		h.die()
	var st: CStorage = e.c(&"storage")
	if st != null:
		st.contents.clear() # everything inside goes with it
	e.destroy()
