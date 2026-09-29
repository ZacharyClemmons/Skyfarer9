class_name Janitor extends RefCounted
## tg janitorial bits: a wet mop leaves the floor wet (slippery) for a little while, and a
## wet floor sign nearby warns people (walking past it in walk mode never slips anyway).

const WET_TIME := 20.0 # tg: TURF_WET_WATER lasts ~20 s after mopping

static func wet_floor(c: Vector2i) -> void:
	if not Game.map.inb(c) or Game.map.is_solid_turf(c) or Game.map.is_outdoor(c):
		return
	for d in Game.at(c):
		if d.proto == "decal_water":
			d.c(&"decal").dry_t = WET_TIME
			d.c(&"decal").slippery = true
			return
	var w := Proto.spawn("decal_water", c)
	w.c(&"decal").dry_t = WET_TIME
	w.spr.modulate = Color(1, 1, 1, 0.45)

## Mopping a bare tile with a wet mop (tg mop/afterattack): cleans it and wets it.
static func mop_tile(user: Entity, mop: Entity, c: Vector2i) -> bool:
	if not user.has_c(&"brain") and int(mop.tags.get("wet", 0)) <= 0:
		Game.tell(user, "Your mop is dry!", "warn")
		return true
	DoAfter.start(user, null, 1.2, func(ok):
		if not ok:
			return
		for d in Game.at_with(c, &"decal"):
			if d.c(&"decal").cleanable and not d.c(&"decal").liquid:
				d.destroy()
		mop.tags["wet"] = maxi(0, int(mop.tags.get("wet", 0)) - 1)
		wet_floor(c)
		Game.visible_message(c, "%s mops the floor." % user.display_name))
	return true
