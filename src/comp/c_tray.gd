class_name CTray extends Component
## tg's T-ray scanner (items/devices/scanners/t_scanner.dm): switched on, it shows the
## pipes and cables hidden under the floor within 3 tiles of whoever carries it, flickering
## back up every 0.8 s. TRayLayer draws what it reveals.

const RANGE := 3

var on := false

static var active: Array = [] # scanners switched on

func key() -> StringName:
	return &"tray"

func attack_self(user: Entity) -> bool:
	on = not on
	if on:
		if not e in active:
			active.append(e)
	else:
		active.erase(e)
	e.set_sprite("items", "t_scanner_on" if on else "t_scanner")
	Sfx.play("click", user.cell, 0.5)
	Game.tell(user, "You switch %s %s." % [e.the(), "on" if on else "off"])
	return true

func on_removed() -> void:
	active.erase(e)

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Turn off" if on else "Turn on", "cb": attack_self.bind(user), "priority": 6})

func examine(_user: Entity, lines: Array) -> void:
	lines.append("It is %s." % ("on, humming faintly" if on else "off"))

## The tile a switched-on scanner is scanning from, for the viewer: the player's own
## scanner, carried anywhere on them.
static func player_scan_origin() -> Vector2i:
	for s in active:
		if not is_instance_valid(s) or s.removed:
			continue
		var holder: Entity = s.root()
		if holder == Game.player:
			return holder.cell
	return Vector2i(-9999, -9999)
