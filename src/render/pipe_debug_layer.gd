class_name PipeDebugLayer extends Node2D
## Debug: draws every pipe network that has gas in it, coloured by what it mostly carries,
## brighter the more is flowing; the selected network is outlined. (Debug menu, F10.)

const GAS_COLORS := TGUI.GAS_COLORS
const LAYER_OFF := [-3.0, 3.0, -3.0, 3.0, 0.0, -6.0]

static var enabled := false
static var selected = null # a PipeNet
var _t := 0.0

func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.4
		queue_redraw()

static func main_gas(net) -> int:
	var best := -1
	for g in Defs.GAS_COUNT:
		if best < 0 or net.gas[g] > net.gas[best]:
			best = g
	return best

func _draw() -> void:
	if not enabled or Game.pipes == null or Game.map == null:
		return
	var map := Game.map
	for net in Game.pipes.nets:
		var tot: float = net.total_moles()
		var sel: bool = net == selected
		if tot < 0.01 and not sel:
			continue
		var col: Color = GAS_COLORS[main_gas(net)] if tot >= 0.01 else Color(0.5, 0.5, 0.5)
		col.a = 0.35 + clampf(net.flow * 0.2, 0.0, 0.55)
		var off: float = LAYER_OFF[net.layer]
		for ci in net.cells:
			var c: Vector2i = map.cell_of(ci)
			var r := Rect2(Vector2(c) * 32.0 + Vector2(12.0 + off, 12.0 + off), Vector2(8, 8))
			draw_rect(r, col)
			if sel:
				draw_rect(Rect2(Vector2(c) * 32.0 + Vector2(1, 1), Vector2(30, 30)), Color(1, 0.9, 0.2, 0.9), false, 2.0)
