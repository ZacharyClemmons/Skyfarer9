class_name CSpaceHeater extends Component
## tg's space heater (machinery/spaceheater.dm): a wheeled heater / cooler that runs off its
## own cell. Auto mode heats or cools the air on its tile and the tiles around it toward the
## target temperature; heat or cool mode only does the one. 40 kJ a tick at most, and every
## 20 J of heat costs 1 J of charge.

const HEAT_PER_S := 80000.0 # W (tg: 40 kJ per SSair tick)
const EFFICIENCY := 20.0 # joules of heat per joule of charge
const CAPACITY := 10000.0 # kJ (tg: a high-capacity cell)
const T_MEDIAN := 30.0 + Defs.T0C # tg settable_temperature_median
const T_RANGE := 30.0

var on := false
var set_mode := "auto" # auto / heat / cool
var mode := "standby" # what it's doing right now
var target := Defs.T20C
var charge := CAPACITY

func key() -> StringName:
	return &"spaceheater"

func tick(dt: float) -> void:
	var was := mode
	mode = "standby"
	if on and charge > 0.5 and Game.atmos and e.holder == null:
		var cells := [e.cell]
		for d in Defs.DIRS4:
			if Game.map.is_passable(e.cell + d):
				cells.append(e.cell + d)
		var here: float = Game.atmos.temp_at(e.cell)
		if set_mode != "cool" and here < target - 1.0:
			mode = "heat"
		elif set_mode != "heat" and here > target + 1.0:
			mode = "cool"
		if mode != "standby":
			var budget := minf(HEAT_PER_S * dt, charge * 1000.0 * EFFICIENCY)
			var used := 0.0
			for c in cells:
				var i: int = Game.map.idx(c)
				var need: float = absf(Game.atmos.temp[i] - target) * Game.atmos.heat_cap(i)
				var j := minf(need, budget / cells.size())
				Game.atmos.add_heat(i, j if mode == "heat" else -j)
				used += j
			charge = maxf(0.0, charge - used / EFFICIENCY / 1000.0)
	if mode != was:
		update_sprite()

func update_sprite() -> void:
	e.set_sprite("objects", {"heat": "space_heater_heat", "cool": "space_heater_cool"}.get(mode, "space_heater"))
	var l: CLight = e.c(&"light")
	if l:
		l.on = mode != "standby"
		l.set_color(Color("#ff8a3a") if mode == "heat" else Color("#5ac8ff"))
		l.refresh()

func attack_hand(user: Entity) -> bool:
	Bus.ui_open_window.emit("space_heater", e)
	return true

func set_on(v: bool, user: Entity) -> void:
	if v and charge <= 0.5:
		Game.tell(user, "The charge meter reads empty.", "warn")
		return
	on = v
	Sfx.play("click", e.cell, 0.5)
	update_sprite()

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Turn off" if on else "Turn on", "cb": func(): set_on(not on, user), "priority": 7})
	out.append({"name": "Settings", "cb": attack_hand.bind(user), "priority": 6})

func examine(_user: Entity, lines: Array) -> void:
	lines.append("The charge meter reads %d%%. It is set to %s, %.0f°C." % [roundi(charge / CAPACITY * 100.0), set_mode, target - Defs.T0C])

func ai_tags(out: Dictionary) -> void:
	out["space_heater"] = true
