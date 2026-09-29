class_name PowerSystem extends Node
## Powernets (tg: datum/powernet). Connected intact cables form a net; generators and
## SMES units feed it; APCs draw their area's load from it and buffer in their cells.
## Damaged cables split nets, so a fire in maintenance can black out Medbay.

const TICK := 1.0
const LIGHT_W := 60.0
const APC_CHARGE_W := 4000.0
const PRIORITY := ["Bridge", "Medbay", "Engineering", "Reactor", "Atmospherics", "Security"]

var map: StationMap
var net_id := PackedInt32Array()
var nets: Array = [] # Array[Dictionary] {cells, gens, smes, apcs, supply, demand}
var dirty := true
var acc := 0.0
var blackout_t := 0.0 # comms blackout event
var total_gen := 0.0
var total_load := 0.0
var grid_check_t := 0.0

func setup(m: StationMap) -> void:
	map = m
	net_id.resize(m.w * m.h)
	Bus.cables_changed.connect(func(): dirty = true)
	rebuild()

func rebuild() -> void:
	net_id.fill(-1)
	nets = []
	for i in net_id.size():
		if map.cable[i] != 1 or net_id[i] >= 0:
			continue
		var id := nets.size()
		var net := {"cells": [], "gens": [], "smes": [], "apcs": [], "supply": 0.0, "demand": 0.0}
		var stack := [i]
		net_id[i] = id
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			net["cells"].append(cur)
			var c := map.cell_of(cur)
			for d in Defs.DIRS4:
				var nc: Vector2i = c + d
				if not map.inb(nc):
					continue
				var j := map.idx(nc)
				if map.cable[j] == 1 and net_id[j] < 0:
					net_id[j] = id
					stack.append(j)
		nets.append(net)
	for e in Game.all_with(&"powergen"):
		var pg: CPowerGen = e.c(&"powergen")
		if pg.kind == "radiator":
			continue
		var nid := _net_for_entity(e)
		if nid >= 0:
			if pg.kind == "smes":
				nets[nid]["smes"].append(e)
			else:
				nets[nid]["gens"].append(e)
	for e in Game.all_with(&"apc"):
		var nid := _net_for_entity(e)
		if nid >= 0:
			nets[nid]["apcs"].append(e)
	dirty = false

func _net_for_entity(e: Entity) -> int:
	var cells := [e.cell]
	var b = e.c(&"blocker")
	if b:
		cells = b.cells()
	for c in cells:
		if map.inb(c) and net_id[map.idx(c)] >= 0:
			return net_id[map.idx(c)]
	return -1

func cell_powered(c: Vector2i) -> bool:
	if not map.inb(c):
		return false
	var nid := net_id[map.idx(c)]
	return nid >= 0 and nid < nets.size() and nets[nid]["supply"] > 0.0

## tg cable multitool reading: total power, load and excess on this cable's network.
func cable_report(c: Vector2i) -> String:
	if dirty:
		rebuild()
	var i := map.idx(c)
	if map.cable[i] == 2:
		return "[color=#ffb84a]This cable is damaged: it isn't carrying anything.[/color]"
	var nid := net_id[i] if i < net_id.size() else -1
	if nid < 0 or nid >= nets.size():
		return "The cable isn't connected to anything."
	var net: Dictionary = nets[nid]
	var supply: float = net.get("supply", 0.0)
	var demand: float = net.get("demand", 0.0)
	var stored := 0.0
	for smes in net.get("smes", []):
		if is_instance_valid(smes) and not smes.removed:
			stored += smes.c(&"powergen").charge
	var lines := ["[b]Power network[/b] (%d cables, %d APCs)" % [net.get("cells", []).size(), net.get("apcs", []).size()],
		"Total power: %s" % _fmt_w(supply), "Load: %s" % _fmt_w(demand),
		"Excess power: %s" % _fmt_w(supply - demand)]
	if not net.get("smes", []).is_empty():
		lines.append("Stored in SMES: %.0f kJ" % stored)
	return "
".join(lines)

static func _fmt_w(w: float) -> String:
	if absf(w) >= 1000000.0:
		return "%.2f MW" % (w / 1000000.0)
	if absf(w) >= 1000.0:
		return "%.1f kW" % (w / 1000.0)
	return "%d W" % int(w)

func telecomms_ok() -> bool:
	if blackout_t > 0:
		return false
	for a in Game.all_with(&"machine"):
		if a.proto == "antenna":
			return not a.c(&"machine").broken
	return true

func summary() -> String:
	return "Generation %.1f kW | Load %.1f kW | Nets %d" % [total_gen / 1000.0, total_load / 1000.0, nets.size()]

func _process(delta: float) -> void:
	var _pt := Perf.t0()
	_process_body(delta)
	Perf.add("power", _pt)

func _process_body(delta: float) -> void:
	if not Game.running or Game.paused:
		return
	acc += delta * Game.time_scale
	if acc >= TICK:
		acc -= TICK
		tick(TICK)

func tick(dt: float) -> void:
	if dirty:
		rebuild()
	blackout_t = maxf(0.0, blackout_t - dt)
	grid_check_t = maxf(0.0, grid_check_t - dt)
	# area loads
	var loads := {}
	for e in Game.all_with(&"machine"):
		var m: CMachine = e.c(&"machine")
		if not m.needs_power or e.holder != null:
			continue
		var aid := map.area[map.idx(e.cell)]
		if map.areas[aid].powered(m.channel):
			loads[aid] = loads.get(aid, 0.0) + m.load_w()
	for e in Game.all_with(&"light"):
		var l: CLight = e.c(&"light")
		if (l.kind == "fixture" or l.kind == "ceiling") and l.lit:
			var aid2 := map.area[map.idx(e.cell)]
			loads[aid2] = loads.get(aid2, 0.0) + LIGHT_W
	# generators
	total_gen = 0.0
	total_load = 0.0
	for e in Game.all_with(&"powergen"):
		var pg: CPowerGen = e.c(&"powergen")
		if pg.kind == "generator":
			pg.generator_tick(dt)
	for net in nets:
		var gen := 0.0
		for g in net["gens"]:
			if is_instance_valid(g) and not g.removed:
				gen += g.c(&"powergen").output_w
		var apcs: Array = net["apcs"].filter(func(a): return is_instance_valid(a) and not a.removed)
		apcs.sort_custom(func(a, b): return _prio(a) < _prio(b))
		var supply := gen
		var smes_avail := 0.0
		for s in net["smes"]:
			if is_instance_valid(s) and not s.removed:
				var sp: CPowerGen = s.c(&"powergen")
				if sp.output_on:
					smes_avail += minf(sp.output_limit, sp.charge * 1000.0 / dt)
		var budget := supply + smes_avail
		var used := 0.0
		if grid_check_t > 0:
			budget = 0.0
		for a in apcs:
			var apc: CApc = a.c(&"apc")
			var load: float = loads.get(apc.area_ref.id, 0.0) if apc.operating() else 0.0
			apc.last_load_w = load
			var want_charge := minf(APC_CHARGE_W, (apc.capacity - apc.charge) * 1000.0 / dt)
			if budget >= load and apc.operating():
				apc.grid_ok = true
				budget -= load
				used += load
				var ch := minf(want_charge, budget)
				budget -= ch
				used += ch
				apc.charge = minf(apc.capacity, apc.charge + ch * dt / 1000.0)
				apc.last_input_w = load + ch
				apc.charging = ch > 1.0
			else:
				apc.grid_ok = false
				apc.charging = false
				apc.last_input_w = 0.0
				apc.charge = maxf(0.0, apc.charge - load * dt / 1000.0)
			apc.update_channels()
			apc.update_lamp()
		# settle SMES: discharge what we drew beyond generation, charge with the surplus
		var from_smes := maxf(0.0, used - supply)
		var surplus := maxf(0.0, supply - used)
		for s in net["smes"]:
			if not is_instance_valid(s) or s.removed:
				continue
			var sp: CPowerGen = s.c(&"powergen")
			sp.last_in = 0.0
			sp.last_out = 0.0
			if from_smes > 0 and sp.output_on:
				var take := minf(from_smes, sp.charge * 1000.0 / dt)
				sp.charge -= take * dt / 1000.0
				sp.last_out = take
				from_smes -= take
			elif surplus > 0 and sp.charge_on:
				var put := minf(surplus, sp.input_limit)
				sp.charge = minf(sp.capacity, sp.charge + put * dt / 1000.0)
				sp.last_in = put
				surplus -= put
		net["supply"] = gen
		net["demand"] = used
		total_gen += gen
		total_load += used
	# APCs not connected to any cable run on their cells
	for e in Game.all_with(&"apc"):
		var apc2: CApc = e.c(&"apc")
		var nid := _net_for_entity(e)
		if nid < 0:
			var load2: float = loads.get(apc2.area_ref.id, 0.0) if apc2.operating() else 0.0
			apc2.grid_ok = false
			apc2.last_load_w = load2
			apc2.charging = false
			apc2.charge = maxf(0.0, apc2.charge - load2 * dt / 1000.0)
			apc2.update_channels()
			apc2.update_lamp()
	# lights react to power
	for e in Game.all_with(&"light"):
		e.c(&"light").refresh()

func _prio(a: Entity) -> int:
	var nm: String = a.c(&"apc").area_ref.name
	for k in PRIORITY.size():
		if nm.contains(PRIORITY[k]):
			return k
	return 99
