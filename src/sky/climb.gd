class_name Climb extends RefCounted
## Getting over the side.
##
## A ship's bulwark stops you walking off the deck by accident, which is the point of it,
## but it is chest height and nobody would stand at a rail they could not climb. So walking
## into one, with somewhere to land on the far side, climbs over it.
##
## This is how you go ashore: bring the ship alongside an island, walk into the rail, and
## you are over. It is also how you board a derelict, and how you get back aboard.

const TIME := 0.9
const NOTE_GAP := 3.0

## Only low, see-over walls can be climbed: a bulwark or a keel timber, never a bulkhead,
## a rock face or a station wall.
static func climbable_turf(t: int) -> bool:
	var fl: int = Defs.TURFS[t]["flags"]
	return (fl & Defs.F_WALL) != 0 and (fl & Defs.F_OPAQUE) == 0

static func can_climb(e: Entity, over: Vector2i) -> bool:
	var map := Game.map
	if e == null or map == null or not map.inb(over):
		return false
	if not e.has_c(&"mob") or not climbable_turf(map.get_turf(over)):
		return false
	var h: CHealth = e.c(&"health")
	if h != null and (h.dead or h.lying() or h.incapacitated()):
		return false
	return landing_beyond(e, over) != Vector2i(-9999, -9999)

## Where you would come down: the tile directly beyond the rail, if it will hold you.
static func landing_beyond(e: Entity, over: Vector2i) -> Vector2i:
	var d: Vector2i = over - e.cell
	var to: Vector2i = over + d
	var map := Game.map
	if not map.inb(to) or map.blocks_move_static(to) or map.dense_count[map.idx(to)] > 0:
		return Vector2i(-9999, -9999)
	if not Falling.supported(to) and not Falling.airborne(e):
		return Vector2i(-9999, -9999)
	for other in Game.at(to):
		if other.has_c(&"mob") and not other.c(&"mob").is_lying():
			return Vector2i(-9999, -9999)
	return to

static func start(e: Entity, over: Vector2i) -> void:
	var to := landing_beyond(e, over)
	if to.x < -9000:
		return
	if DoAfter.busy(e):
		return
	var m: CMob = e.c(&"mob")
	if m != null:
		m.face(Defs.dir_from_vec(over - e.cell))
	Game.tell(e, "You get a leg over the rail...")
	DoAfter.start(e, null, TIME * _effort(e), func(ok: bool):
		if not ok:
			return
		var land := landing_beyond(e, over)
		if land.x < -9000:
			Game.tell(e, "The far side is blocked now.", "warn")
			return
		e.place(land)
		Skills.add_xp(e, "evasion", 8.0)
		Sfx.play("step_floor", land, 0.8)
		Game.visible_message(land, "%s climbs over the rail." % e.display_name, "emote"))

## Carrying half your own weight in salvage makes this slower, as it should.
static func _effort(e: Entity) -> float:
	var f := 1.0 - Skills.level(e, "evasion") * 0.004
	var h: CHealth = e.c(&"health")
	if h != null and h.stamina < 50.0:
		f += 0.4
	return clampf(f, 0.5, 1.8)

## Why a step was refused, for the message the player actually needs.
static func refusal(e: Entity, over: Vector2i) -> String:
	if not climbable_turf(Game.map.get_turf(over)):
		return ""
	if landing_beyond(e, over) == Vector2i(-9999, -9999):
		return "You could climb the rail here, but there is nothing on the other side to stand on."
	return ""
