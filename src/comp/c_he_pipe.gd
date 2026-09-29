class_name CHEPipe extends Component
## tg heat-exchange pipe (/obj/machinery/atmospherics/pipe/heat_exchanging): fitted onto a
## pipe, it trades heat between the gas inside and whatever it's lying in. Out on the
## glacier (tg: in space) it dumps heat into the endless cold, which is how the station
## cools a hot loop; inside it warms or chills the room.

var layer := StationMap.PL_SUPPLY
const CONDUCTIVITY := 0.4 # tg HE pipe thermal_conductivity
const TILE_CAP := 60000.0 # J/K standing in for a tile of air or a patch of glacier

func key() -> StringName:
	return &"hepipe"

func setup(p: Dictionary) -> CHEPipe:
	layer = p.get("layer", layer)
	return self

func on_added() -> void:
	if Game.pipes:
		Game.pipes.register_device(e, layer)

func on_removed() -> void:
	if Game.pipes:
		Game.pipes.unregister_device(e)

func exchange(net, dt: float) -> void:
	if net == null or Game.atmos == null:
		return
	var map := Game.map
	var outdoor := map.is_outdoor(e.cell)
	var env_t: float
	if outdoor:
		env_t = Defs.EXT_TEMP + (Game.director.ext_temp_offset if Game.director else 0.0)
	else:
		env_t = Game.atmos.temp[map.idx(e.cell)]
	var dT: float = env_t - net.temp
	if absf(dT) < 0.05:
		return
	var env_cap := 1e9 if outdoor else maxf(1.0, Game.atmos.total_moles(map.idx(e.cell)) * 20.8)
	var cap := minf(minf(net.heat_capacity(), env_cap), TILE_CAP)
	var q := dT * cap * CONDUCTIVITY * 0.1 * dt
	net.add_heat(q)
	if not outdoor:
		Game.atmos.add_heat(map.idx(e.cell), -q)

func examine(_user: Entity, lines: Array) -> void:
	lines.append("Fins along a %s pipe trade its heat with the surroundings." % StationMap.PIPE_LAYER_NAMES[layer])
