class_name CPowerGen extends Component
## Powernet producers and storage:
##   "teg"        thermoelectric generator between the HOT and COLD loops
##   "generator"  portable fuel generator (P.A.C.M.A.N. style)
##   "smes"       big battery (tg: SMES) - charges on surplus, discharges on deficit
##   "radiator"   not a generator: dumps COLD loop heat into the arctic air

var kind := "teg"
var output_w := 0.0 # produced this tick
# teg
var efficiency := 0.42
# generator
var on := false
var fuel := 0.0
var max_output := 25000.0
# smes
var charge := 40000.0 # kJ
var capacity := 60000.0
var input_limit := 40000.0 # W
var output_limit := 60000.0 # W
var charge_on := true
var output_on := true
var last_in := 0.0
var last_out := 0.0

func key() -> StringName:
	return &"powergen"

func setup(p: Dictionary) -> CPowerGen:
	kind = p.get("kind", kind)
	fuel = p.get("fuel", fuel)
	return self

func on_added() -> void:
	if kind == "teg" and Game.pipes:
		Game.pipes.register_device(e, StationMap.PL_HOT)
		Game.pipes.register_device(e, StationMap.PL_COLD, Vector2i(1, 0))
	if kind == "radiator" and Game.pipes:
		Game.pipes.register_device(e, StationMap.PL_COLD)

func on_removed() -> void:
	if Game.pipes:
		Game.pipes.unregister_device(e)

## TEG heat exchange (called from PipeSystem each atmos tick).
func teg_exchange(hot, cold, dt: float) -> void:
	output_w = 0.0
	if hot == null or cold == null:
		return
	var m: CMachine = e.c(&"machine")
	if m and m.broken:
		return
	var dT: float = hot.temp - cold.temp
	if dT <= 0:
		return
	var cap := minf(hot.heat_capacity(), cold.heat_capacity())
	var q := dT * cap * 0.12 # J this tick moved from hot to cold side
	var produced := q * efficiency
	hot.add_heat(-q)
	cold.add_heat(q - produced)
	output_w = produced / dt

func radiate(net, dt: float) -> void:
	if net == null:
		return
	var ext = Defs.EXT_TEMP + (Game.director.ext_temp_offset if Game.director else 0.0)
	var dT: float = net.temp - ext
	if dT <= 0:
		return
	var q: float = dT * minf(net.heat_capacity(), 60000.0) * 0.035
	net.add_heat(-q * dt * 2.0)

func generator_tick(dt: float) -> void:
	output_w = 0.0
	if not on:
		return
	if fuel <= 0:
		on = false
		e.set_sprite("objects", "generator")
		Game.visible_message(e.cell, "%s sputters and stops." % e.the().capitalize())
		return
	fuel = maxf(0.0, fuel - dt * 0.004)
	output_w = max_output

func attack_hand(user: Entity) -> bool:
	match kind:
		"generator":
			if fuel <= 0:
				Game.tell(user, "It has no fuel. Insert plasma sheets.", "warn")
				return true
			on = not on
			e.set_sprite("objects", "generator_on" if on else "generator")
			Game.visible_message(e.cell, "%s turns %s %s." % [user.display_name, "on" if on else "off", e.the()])
			return true
		"smes", "teg":
			Bus.ui_open_window.emit("power", e)
			return true
	return false

func attackby(user: Entity, item: Entity) -> bool:
	if kind == "generator" and item.proto == "sheet_plasma":
		fuel = minf(1.0, fuel + 0.25)
		var st = item.c(&"stack")
		if st:
			st.use(1)
		Game.tell(user, "You feed a plasma sheet into %s." % e.the())
		return true
	return false

func examine(_user: Entity, lines: Array) -> void:
	match kind:
		"teg":
			lines.append("Output: %.1f kW." % (output_w / 1000.0))
		"generator":
			lines.append("It is %s. Fuel: %d%%." % ["running" if on else "off", int(fuel * 100)])
		"smes":
			lines.append("Charge: %d%% (%.0f MJ). In %.1f kW, out %.1f kW." % [int(charge / capacity * 100), charge / 1000.0, last_in / 1000.0, last_out / 1000.0])

func ai_tags(out: Dictionary) -> void:
	out[kind] = true
