class_name CExtinguisher extends Component
## Fire extinguisher: sprays foam in a 3-wide cone toward the target tile, putting out
## hotspots, burning people and cooling the air.

var charges := 20

func key() -> StringName:
	return &"extinguisher"

func spray(user: Entity, target: Vector2i) -> bool:
	if charges <= 0:
		Game.tell(user, "The extinguisher is empty.", "warn")
		return false
	charges -= 1
	var origin := user.cell
	var d := target - origin
	var dir := Vector2i(signi(d.x), signi(d.y))
	if dir == Vector2i.ZERO:
		dir = Defs.DIRS4[user.c(&"mob").dir] if user.c(&"mob") else Vector2i(0, 1)
	var side := Vector2i(-dir.y, dir.x)
	var cells := []
	for dist in range(1, 4):
		var c := origin + dir * dist
		if Game.map.blocks_air(c):
			break
		cells.append(c)
		if dist >= 2:
			cells.append(c + side)
			cells.append(c - side)
	for c in cells:
		Fx.foam(c)
		if Game.atmos:
			Game.atmos.extinguish(c)
		for m in Game.at_with(c, &"health"):
			m.c(&"health").on_fire = 0.0
		for f in Game.at_with(c, &"flammable"):
			f.c(&"flammable").burning = 0.0
	Sfx.play("spray", origin)
	# recoil on ice / in low gravity, as in SS13
	return true

func examine(_user: Entity, lines: Array) -> void:
	lines.append("Charges left: %d." % charges)

func ai_tags(out: Dictionary) -> void:
	if charges > 0:
		out["extinguisher"] = true
