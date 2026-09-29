class_name CGrapple extends Component
## A barbed hook on a drum of line. Fire it at solid ground and it hauls you across the
## gap; fire it at someone who has just gone over the rail and it hauls them back.
##
## It is the answer to the game's worst moment, which is why it is expensive, slow to
## wind back in, and only holds two people if you are lucky.

const RANGE := 9
const REWIND := 3.2 # seconds to crank the line back onto the drum

var winding := 0.0

func key() -> StringName:
	return &"grapple"

func process(delta: float) -> void:
	if winding > 0.0:
		winding = maxf(0.0, winding - delta)

func ready() -> bool:
	return winding <= 0.0

## Called by the interaction layer when the player clicks a target with this in hand.
func fire_at(user: Entity, target_cell: Vector2i, target: Entity = null) -> bool:
	if not ready():
		Game.tell(user, "The line is still winding back on the drum.", "warn")
		return true
	var dist: int = maxi(absi(target_cell.x - user.cell.x), absi(target_cell.y - user.cell.y))
	if dist > RANGE:
		Game.tell(user, "Too far. The drum only holds so much line.", "warn")
		return true
	winding = REWIND
	Sfx.play("swing", user.cell, 0.9)
	# catching a falling person is what this thing is for
	if target != null and target.tags.get("falling", false):
		var to := _footing_near(user.cell)
		if to.x < -9000:
			Game.tell(user, "You have nowhere to brace. The shot goes wide.", "warn")
			return true
		Falling.rescue(target, to)
		Game.visible_message(user.cell, "[b]%s puts a grapple line into %s and hauls them back aboard.[/b]" % [
			user.display_name, target.display_name], "good")
		Skills.add_xp(user, "throwing", 30.0)
		Bus.chronicle.emit("%s pulled %s back out of the sky." % [user.display_name, target.display_name], 3)
		return true
	# otherwise it is a way across a gap
	if not Falling.supported(target_cell) or not Game.map.is_passable(target_cell):
		Game.tell(user, "Nothing there for the hook to bite on.", "warn")
		return true
	if not _clear_line(user.cell, target_cell):
		Game.tell(user, "Something is in the way of the line.", "warn")
		return true
	user.place(target_cell)
	Game.visible_message(target_cell, "%s swings across on a grapple line." % user.display_name, "emote")
	Skills.add_xp(user, "evasion", 14.0)
	Sfx.play("whoosh", target_cell, 0.8)
	return true

func _footing_near(from: Vector2i) -> Vector2i:
	if Falling.supported(from):
		return from
	for d in Defs.DIRS8:
		if Falling.supported(from + d):
			return from + d
	return Vector2i(-9999, -9999)

## The line needs a clear run — it will not bend round a hull.
func _clear_line(a: Vector2i, b: Vector2i) -> bool:
	var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	if steps <= 1:
		return true
	for k in range(1, steps):
		var t := float(k) / float(steps)
		var c := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		if Game.map.is_solid_turf(c):
			return false
	return true

func attack_self(user: Entity) -> bool:
	Game.tell(user, "You check the hook and the pawl. %s" % (
		"Ready." if ready() else "Still winding — %.0f seconds." % winding))
	return true

func examine(_user: Entity, lines: Array) -> void:
	lines.append("Range about %d tiles. %s" % [RANGE, "Wound and ready." if ready() else "[color=#e8a83a]Rewinding.[/color]"])
	lines.append("[i]Click a ledge to swing across, or a falling person to catch them.[/i]")
