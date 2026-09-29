class_name CMeter extends Component
## tg /obj/machinery/meter: clamped onto a pipe, it reads out the pipe's pressure and
## temperature. The dial shows the pressure at a glance (tg: the bar grows with pressure
## and its colour follows the temperature).

var layer := StationMap.PL_GEN
var _shown := -1

func key() -> StringName:
	return &"meter"

func setup(p: Dictionary) -> CMeter:
	layer = p.get("layer", layer)
	return self

func on_added() -> void:
	_refresh.call_deferred()

func net():
	if Game.pipes == null:
		return null
	return Game.pipes.net_at(layer, e.cell)

## tg meter icon: 0 empty, then pressure bands.
func level() -> int:
	var n = net()
	if n == null:
		return 0
	var p: float = n.pressure()
	if p <= 0.15:
		return 0
	if p < 101.0:
		return 1
	if p < 500.0:
		return 2
	if p < 2000.0:
		return 3
	return 4

func _refresh() -> void:
	if e == null or e.removed:
		return
	var l := level()
	if l != _shown:
		_shown = l
		e.set_sprite("objects", "meter_%d" % l)

func tick(_dt: float) -> void:
	_refresh()

func examine(_user: Entity, lines: Array) -> void:
	var n = net()
	if n == null:
		lines.append("It isn't attached to anything.")
		return
	lines.append("The pressure gauge reads %.1f kPa; %.1f K (%.1f°C)." % [n.pressure(), n.temp, n.temp - Defs.T0C])
