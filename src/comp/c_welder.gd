class_name CWelder extends Component
## Welding tool: Z toggles the flame. Lit welders burn fuel, light up, and can ignite gas.

var lit := false
var fuel := 40.0
var max_fuel := 40.0

func key() -> StringName:
	return &"welder"

func attack_self(user: Entity) -> bool:
	if not lit and fuel <= 0:
		Game.tell(user, "It's out of fuel.", "warn")
		return true
	lit = not lit
	e.set_sprite("items", "welder_on" if lit else "welder")
	var l = e.c(&"light")
	if l:
		l.on = lit
		l.refresh()
	Game.tell(user, "You %s the blowtorch." % ("light" if lit else "shut off"))
	var m = user.c(&"mob")
	if m:
		m.refresh_doll()
	return true

func use_fuel(amt: float) -> bool:
	if fuel < amt:
		lit = false
		e.set_sprite("items", "welder")
		return false
	fuel -= amt
	return true

func tick(dt: float) -> void:
	if lit:
		if not use_fuel(dt * 0.05):
			return
		if Game.atmos:
			Game.atmos.spark(e.root_cell(), 0.2)

func examine(_user: Entity, lines: Array) -> void:
	lines.append("Fuel: %d/%d. It is %s." % [int(fuel), int(max_fuel), "lit" if lit else "off"])

func ai_tags(out: Dictionary) -> void:
	if lit:
		out["lit_welder"] = true
