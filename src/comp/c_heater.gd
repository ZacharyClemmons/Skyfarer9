class_name CHeater extends Component
## Room heater. The arctic is always trying to steal the station's heat through its
## walls (see AtmosSystem.heat_loss_pass); powered heaters in an area push back.
## Lose power and the cold creeps in, room by room.

var power_w := 6000.0 # heating capacity (W)
var on := true

func key() -> StringName:
	return &"heater"

func working() -> bool:
	var m: CMachine = e.c(&"machine")
	return on and (m == null or m.operable())

func tick(_dt: float) -> void:
	var m: CMachine = e.c(&"machine")
	if m:
		m.active = working()
	var want := "heater_on" if working() else "heater_off"
	if e.spr and e.spr.region_rect != Gfx.region("objects", want):
		e.set_sprite("objects", want)

func attack_hand(user: Entity) -> bool:
	on = not on
	Game.tell(user, "You switch the heater %s." % ("on" if on else "off"))
	return true

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Turn off" if on else "Turn on", "cb": attack_hand.bind(user), "priority": 5})

func ai_tags(out: Dictionary) -> void:
	out["heater"] = true
