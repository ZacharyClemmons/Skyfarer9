class_name PipeHover extends Node2D
## Hover an exposed pipe and its whole network lights up: a glow traced along every pipe
## in the network (so you can follow where it goes through the tangle), the devices on it
## ringed, and the examine bar says what it carries. tg makes you trace pipes by eye or
## with a t-ray; this is the readable version of the same information, so it only works
## while you hold a gas analyzer.

## Pixel offset of each of our pipe layers inside its tile (tg's layer offsets; matches
## the pipe sprites in objects.png).
const LAYER_PX := [-3.0, 3.0, -3.0, 3.0, 0.0, -6.0]

static var hovered = null # the PipeNet under the mouse, or null
static var hovered_layer := -1
var _pulse := 0.0

## "3,050 kPa · 20°C · N2 78%  O2 21%": a network's contents, short enough for the examine bar.
static func readout(net) -> String:
	var tot: float = net.total_moles()
	if tot < 0.01:
		return "empty"
	return "%s kPa  ·  %d°C  ·  %s" % [_kpa(net.pressure()), int(round(net.temp - Defs.T0C)), _mix(net.gas, tot)]

## The same for the open air on a tile (gas chambers).
static func air_readout(c: Vector2i) -> String:
	if Game.atmos == null or not Game.map.inb(c):
		return ""
	var i := Game.map.idx(c)
	var gas := PackedFloat32Array()
	var tot := 0.0
	for g in Defs.GAS_COUNT:
		gas.append(Game.atmos.gas[g][i])
		tot += gas[g]
	if tot < 0.01:
		return "vacuum"
	return "%s kPa  ·  %d°C  ·  %s" % [_kpa(Game.atmos.pressure(i)), int(round(Game.atmos.temp[i] - Defs.T0C)), _mix(gas, tot)]

## What to call a network: by the job of its layer, else by what's in it.
static func net_name(net) -> String:
	# the station's own air lines are the plain (uncoloured) supply and scrubber pipes; tg's
	# coloured Atmospherics lines reuse those layers, so they're named by what they carry
	var plain := true
	var map := Game.map
	for ci in net.cells.slice(0, 8):
		if map.pipe_color.has(map.pipe_key(net.layer, map.cell_of(ci))):
			plain = false
			break
	if plain and net.layer == 0:
		return "Air supply pipe"
	if plain and net.layer == 1:
		return "Scrubber waste pipe"
	var tot: float = net.total_moles()
	if tot < 0.01:
		return "Empty pipe"
	var main := PipeDebugLayer.main_gas(net)
	var f: float = net.gas[main] / tot
	var o2 := Defs.GAS_NAMES.find("Oxygen")
	var n2 := Defs.GAS_NAMES.find("Nitrogen")
	if o2 >= 0 and n2 >= 0 and absf(net.gas[n2] / tot - 0.79) < 0.08 and absf(net.gas[o2] / tot - 0.21) < 0.08:
		return "Air pipe"
	if f < 0.7:
		return "Mixed gas pipe"
	return "%s pipe" % Defs.GAS_NAMES[main]

static func _kpa(p: float) -> String:
	return ("%.0f" % p) if p < 10000.0 else ("%.1fk" % (p / 1000.0))



static func _mix(gas, tot: float) -> String:
	var parts := []
	var order := range(Defs.GAS_COUNT)
	order.sort_custom(func(a, b): return gas[a] > gas[b])
	for g in order:
		var f: float = gas[g] / tot
		if f >= 0.01 and parts.size() < 3:
			parts.append("%s %d%%" % [Defs.GAS_SHORT[g], int(round(f * 100.0))])
	return "  ".join(parts)

func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 3.0, TAU)
	var net = _pick()
	if net != hovered or hovered != null:
		hovered = net
		queue_redraw()

## The pipe network under the mouse: of the visible pipes on the hovered tile, the one
## whose line runs closest to the pointer.
func _pick():
	if Game.pipes == null or Game.map == null or Game.hud == null or Game.view == null:
		return null
	if Game.hud.over_hud(Game.hud.mouse) or not AtmosOverlay.analyzer_view():
		return null
	var map := Game.map
	var wp: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * Game.hud.mouse
	var c := Vector2i(floori(wp.x / Defs.TILE), floori(wp.y / Defs.TILE))
	if not map.inb(c) or (Game.lighting and not Game.lighting.player_can_see(c)):
		return null
	var local: Vector2 = wp - Vector2(c) * Defs.TILE
	var best = null
	var best_d := 7.0 # pixels: how close the pointer must be to a pipe's line
	var i := map.idx(c)
	for layer in StationMap.PIPE_LAYER_COUNT:
		if map.pipe_mask(layer, c) == 0 or not _visible(layer, c):
			continue
		var gs := map.pipe_groups_at(layer, c)
		for g in gs.size():
			var d := _dist_to_pipe(local, gs[g], LAYER_PX[layer])
			if d < best_d:
				var net = Game.pipes.node_net[layer].get(i * 4 + g)
				if net:
					best_d = d
					best = net
					hovered_layer = layer
	return best

func _visible(layer: int, c: Vector2i) -> bool:
	var map := Game.map
	var fl: int = Defs.TURFS[map.turf[map.idx(c)]]["flags"]
	var covered := (fl & Defs.F_FLOOR) != 0 or (fl & Defs.F_WALL) != 0
	return not covered or map.pipe_shown.has(map.pipe_key(layer, c)) or TerrainChunk.xray

static func _dist_to_pipe(p: Vector2, mask: int, off: float) -> float:
	var ctr := Vector2(16.0 + off, 16.0 + off)
	var best := p.distance_to(ctr)
	for d in 4:
		if mask & (1 << d):
			var dir := Vector2(Defs.DIRS4[d])
			var end := ctr + dir * 32.0
			end = end.clamp(Vector2.ZERO, Vector2(32, 32))
			best = minf(best, Geometry2D.get_closest_point_to_segment(p, ctr, end).distance_to(p))
	return best

func _draw() -> void:
	var net = hovered
	if net == null:
		return
	var map := Game.map
	var col: Color = PipeDebugLayer.GAS_COLORS[PipeDebugLayer.main_gas(net)] if net.total_moles() > 0.01 else Color(0.75, 0.8, 0.9)
	var a := 0.7 + 0.3 * sin(_pulse)
	var off: float = LAYER_PX[net.layer]
	var glow := Color(col.lerp(Color.WHITE, 0.2), 0.32 * a)
	var core := Color(col.lerp(Color.WHITE, 0.7), a)
	for ni in net.nodes:
		var ci: int = ni / 4
		var g: int = ni % 4
		var c := map.cell_of(ci)
		var gs := map.pipe_groups_at(net.layer, c)
		if g >= gs.size():
			continue
		var mask: int = gs[g]
		var ctr := Vector2(c) * Defs.TILE + Vector2(16.0 + off, 16.0 + off)
		for d in 4:
			if mask & (1 << d):
				var end := ctr + Vector2(Defs.DIRS4[d]) * 16.5
				draw_line(ctr, end, glow, 12.0)
				draw_line(ctr, end, core, 2.0)
		draw_circle(ctr, 2.0, core)
	# ring the machines hooked onto this network
	for id in Game.pipes.devices:
		for entry in Game.pipes.devices[id]:
			var ent: Entity = entry[2]
			if entry[0] != net.layer or not is_instance_valid(ent) or ent.removed:
				continue
			if Game.pipes.net_at(entry[0], ent.cell + entry[1]) == net:
				draw_rect(Rect2(Vector2(ent.cell) * Defs.TILE + Vector2(2, 2), Vector2(28, 28)), Color(col, a), false, 2.0)
