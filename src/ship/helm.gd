class_name Helm extends RefCounted
## Finding the wheel a given person has hold of.
##
## Small enough to be a free function, but it is asked for from the player controller, the
## HUD and the tutorial, so it lives in one place rather than three.

static func of(e: Entity) -> CHelm:
	if e == null or e.removed:
		return null
	for ent in Game.all_with(&"helm"):
		var h: CHelm = ent.c(&"helm")
		if h != null and h.pilot == e:
			return h
	return null

## The ship that person is currently flying, if any.
static func ship_of(e: Entity) -> Airship:
	var h := of(e)
	return h.ship() if h != null else null
