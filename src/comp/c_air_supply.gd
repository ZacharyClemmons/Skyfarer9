class_name CAirSupply extends Component
## Atmospherics distribution: mixes stored O2/N2 into the supply loop at a set pressure
## (tg's distro + mixer, collapsed into one machine). Reserves deplete over the shift;
## atmos techs top them up from canisters or by melting mined ice.

var o2_reserve := 60000.0 # moles
var n2_reserve := 200000.0
var target_kpa := 350.0
var on := true
var injected_last := 0.0

func key() -> StringName:
	return &"air_supply"

func on_added() -> void:
	if Game.pipes:
		Game.pipes.register_device(e, StationMap.PL_SUPPLY)

func on_removed() -> void:
	if Game.pipes:
		Game.pipes.unregister_device(e)

func working() -> bool:
	var m: CMachine = e.c(&"machine")
	return on and (m == null or m.operable())

func supply(net, _dt: float) -> void:
	injected_last = 0.0
	if net == null or not working():
		return
	var p: float = net.pressure()
	if p >= target_kpa:
		return
	var want: float = (target_kpa - p) * net.volume / (Defs.R_IDEAL * Defs.T20C)
	want = minf(want, 400.0)
	var o2 := minf(want * 0.21, o2_reserve)
	var n2 := minf(want * 0.79, n2_reserve)
	o2_reserve -= o2
	n2_reserve -= n2
	net.add_gas(Defs.G_O2, o2, Defs.T20C)
	net.add_gas(Defs.G_N2, n2, Defs.T20C)
	injected_last = o2 + n2

func attackby(user: Entity, item: Entity) -> bool:
	if item.proto == "ice_chunk":
		# melted and electrolysed: crude but very arctic
		o2_reserve += 900.0
		n2_reserve += 200.0
		item.destroy()
		Game.tell(user, "The machine gurgles as it melts and electrolyses the rime-ice.")
		return true
	return false

func attack_hand(_user: Entity) -> bool:
	Bus.ui_open_window.emit("air_supply", e)
	return true

func examine(_user: Entity, lines: Array) -> void:
	lines.append("O2 reserve: %.0f mol, N2 reserve: %.0f mol. Target %.0f kPa." % [o2_reserve, n2_reserve, target_kpa])
	if o2_reserve < 5000:
		lines.append("[color=#ffb84a]The oxygen reserve is running low.[/color]")

func ai_tags(out: Dictionary) -> void:
	out["air_supply"] = true
	if o2_reserve < 5000:
		out["air_low"] = true
