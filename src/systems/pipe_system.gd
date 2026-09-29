class_name PipeSystem extends Node
## Pipe networks (tg: datum/pipeline). Connected pipe segments on one layer share a single
## gas mixture. Devices (vents, scrubbers, reactor, TEG, radiators, air supply) attach at
## a cell. Damaged segments leak into the room - hot coolant leaks cook people.

class PipeNet:
	var layer := 0
	var cells: Array = [] # Array[int] tile indices
	var nodes: Array = [] # Array[int] idx * 4 + which pipe on the tile
	var gas := PackedFloat32Array()
	var temp := Defs.T20C
	var volume := 70.0
	var flow := 0.0 # moles that moved in or out last tick (debug readout)
	var _prev_total := 0.0

	func _init() -> void:
		gas.resize(Defs.GAS_COUNT)

	func total_moles() -> float:
		var t := 0.0
		for g in Defs.GAS_COUNT:
			t += gas[g]
		return t

	func heat_capacity() -> float:
		var c := 0.0
		for g in Defs.GAS_COUNT:
			c += gas[g] * Defs.GAS_SPECIFIC_HEAT[g]
		return c

	func pressure() -> float:
		return total_moles() * Defs.R_IDEAL * temp / volume

	func add_gas(g: int, moles: float, t: float) -> void:
		var c0 := heat_capacity()
		var e0 := c0 * temp
		gas[g] += moles
		var c1 := heat_capacity()
		if c1 > 0.001:
			temp = (e0 + moles * Defs.GAS_SPECIFIC_HEAT[g] * t) / c1

	func add_heat(j: float) -> void:
		var c := heat_capacity()
		if c > 0.1:
			temp = clampf(temp + j / c, 2.7, 8000.0)

	## Removes a fraction of the whole mix and returns the removed moles per gas.
	func take_fraction(f: float) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		out.resize(Defs.GAS_COUNT)
		f = clampf(f, 0.0, 1.0)
		for g in Defs.GAS_COUNT:
			out[g] = gas[g] * f
			gas[g] -= out[g]
		return out

var map: StationMap
var nets: Array = []
var net_of: Array = [] # per layer: Dictionary cell idx -> PipeNet (the tile's first pipe)
var node_net: Array = [] # per layer: Dictionary (idx * 4 + pipe on the tile) -> PipeNet
var devices := {} # entity id -> Array[[layer, offset]]
## tg binary / trinary devices built into a pipe run (CPipeMachine). Their cell belongs to
## no net, so the run either side of them is two nets they move gas between.
var machines: Array = []
var inline := [] # per layer: cell idx -> Entity
## Extra volume some pipe cells carry (a plant's holding tank), litres: layer -> {idx: L}
var volume_bonus := []
var dirty := true

func _init() -> void:
	for l in StationMap.PIPE_LAYER_COUNT:
		inline.append({})
		volume_bonus.append({})

func setup(m: StationMap) -> void:
	map = m
	net_of = []
	node_net = []
	for l in StationMap.PIPE_LAYER_COUNT:
		net_of.append({})
		node_net.append({})
	Bus.pipes_changed.connect(func(): dirty = true)
	rebuild()
	# initial contents
	for net in nets:
		match net.layer:
			StationMap.PL_SUPPLY:
				var mol: float = 330.0 * net.volume / (Defs.R_IDEAL * Defs.T20C)
				net.gas[Defs.G_O2] = mol * 0.21
				net.gas[Defs.G_N2] = mol * 0.79
				net.temp = Defs.T20C
			StationMap.PL_HOT:
				net.gas[Defs.G_N2] = 800.0
				net.temp = 480.0
			StationMap.PL_COLD:
				net.gas[Defs.G_N2] = 900.0
				net.temp = 260.0

func register_device(e: Entity, layer: int, offset := Vector2i.ZERO) -> void:
	var k := e.get_instance_id()
	if not devices.has(k):
		devices[k] = []
	devices[k].append([layer, offset, e])

func unregister_device(e: Entity) -> void:
	devices.erase(e.get_instance_id())

func set_device_offset(e: Entity, layer: int, off: Vector2i) -> void:
	for entry in devices.get(e.get_instance_id(), []):
		if entry[0] == layer:
			entry[1] = off

func register_machine(e: Entity) -> void:
	if not e in machines:
		machines.append(e)
	var pm: CPipeMachine = e.c(&"pipemachine")
	if pm.inline():
		inline[pm.layer][map.idx(e.cell)] = e
		dirty = true

func unregister_machine(e: Entity) -> void:
	machines.erase(e)
	for l in inline:
		for k in l.keys():
			if l[k] == e:
				l.erase(k)
				dirty = true

## Move a fraction of `a`'s gas into `b` (only gas `only`, if given; never gas `skip`).
## Returns the moles moved.
static func transfer(a: PipeNet, b: PipeNet, f: float, only := -1, skip := -1) -> float:
	if a == null or b == null or a == b or f <= 0.0:
		return 0.0
	var moved := 0.0
	var t := a.temp
	for g in Defs.GAS_COUNT:
		if (only >= 0 and g != only) or g == skip:
			continue
		var amt := a.gas[g] * f
		if amt <= 0.0:
			continue
		a.gas[g] -= amt
		b.add_gas(g, amt, t)
		moved += amt
	return moved

func net_at(layer: int, c: Vector2i) -> PipeNet:
	if not map.inb(c):
		return null
	return net_of[layer].get(map.idx(c))

## The pipeline of whichever pipe on tile `c` opens toward `toward` (a unit offset):
## what a machine next to it actually connects to.
func net_facing(layer: int, c: Vector2i, toward: Vector2i) -> PipeNet:
	if not map.inb(c):
		return null
	var d := Defs.DIRS4.find(toward)
	if d < 0:
		return net_at(layer, c)
	var g := map.pipe_group_facing(layer, c, d)
	if g < 0:
		return null
	return node_net[layer].get(map.idx(c) * 4 + g)

func nets_on_layer(layer: int) -> Array:
	var out := []
	for net in nets:
		if net.layer == layer:
			out.append(net)
	return out

func rebuild() -> void:
	# preserve contents: each old net's gas is spread evenly over its pipes
	var per_node := []
	for l in StationMap.PIPE_LAYER_COUNT:
		per_node.append({})
	for net in nets:
		var k := float(maxi(1, net.nodes.size()))
		for nk in net.nodes:
			per_node[net.layer][nk] = [net.gas, k, net.temp]
	nets = []
	var n := map.w * map.h
	for l in StationMap.PIPE_LAYER_COUNT:
		net_of[l] = {}
		node_net[l] = {}
		var masks: PackedByteArray = map.pipe_layers[l]
		var groups: Dictionary = map.pipe_groups[l]
		var blocked: Dictionary = inline[l]
		# a machine claims only its own ports' sides of its tile: a pipe crossing under it
		# the other way (tg bridge pipes) carries on as its own line
		var claim := {}
		for bi in blocked:
			claim[bi] = _port_mask(blocked[bi])
		for i in n:
			if masks[i] == 0:
				continue
			var gcount: int = groups[i].size() if groups.has(i) else 1
			for g0 in gcount:
				var start := i * 4 + g0
				if node_net[l].has(start):
					continue
				var m0: int = groups[i][g0] if groups.has(i) else masks[i]
				if claim.has(i) and (m0 & claim[i]) != 0:
					continue
				var net := PipeNet.new()
				net.layer = l
				node_net[l][start] = net
				var stack := [start]
				var e_sum := 0.0
				var c_sum := 0.0
				while not stack.is_empty():
					var nk: int = stack.pop_back()
					var cur: int = nk >> 2
					net.nodes.append(nk)
					net.cells.append(cur)
					if not net_of[l].has(cur):
						net_of[l][cur] = net
					if per_node[l].has(nk):
						var pc: Array = per_node[l][nk]
						for gi in Defs.GAS_COUNT:
							var add: float = pc[0][gi] / pc[1]
							net.gas[gi] += add
							c_sum += add * Defs.GAS_SPECIFIC_HEAT[gi]
							e_sum += add * Defs.GAS_SPECIFIC_HEAT[gi] * pc[2]
					var c := map.cell_of(cur)
					var m: int = groups[cur][nk & 3] if groups.has(cur) else masks[cur]
					for d in 4:
						if (m & (1 << d)) == 0:
							continue
						var nc: Vector2i = c + Defs.DIRS4[d]
						if not map.inb(nc):
							continue
						var j := map.idx(nc)
						var gg := map.pipe_group_facing(l, nc, (d + 2) % 4)
						if gg < 0:
							continue
						if claim.has(j):
							var mj: int = groups[j][gg] if groups.has(j) else masks[j]
							if (mj & claim[j]) != 0:
								continue
						var jk := j * 4 + gg
						if node_net[l].has(jk):
							continue
						node_net[l][jk] = net
						stack.append(jk)
				net.volume = 70.0 * net.nodes.size()
				for ci in net.cells:
					net.volume += volume_bonus[l].get(ci, 0.0)
				if c_sum > 0.01:
					net.temp = e_sum / c_sum
				nets.append(net)
	_join_layer_links()
	dirty = false

## The sides of its tile an inline machine's ports use (all four if it hasn't set them).
func _port_mask(e: Entity) -> int:
	if e == null or not is_instance_valid(e) or not e.has_c(&"pipemachine"):
		return 15
	var pm: CPipeMachine = e.c(&"pipemachine")
	var m := 0
	for v in [pm.dir_in, pm.dir_out, pm.dir_side]:
		var d := Defs.DIRS4.find(v)
		if d >= 0:
			m |= 1 << d
	return m if m != 0 else 15

## tg layer adaptors: on every layer, the pipe along the adaptor's axis is one pipeline
## (a pipe crossing the tile the other way stays its own line). Our own joints (an Array of
## layers) join those layers' pipes on the tile.
func _join_layer_links() -> void:
	for i in map.pipe_links.keys():
		var first: PipeNet = null
		var which = map.pipe_links[i]
		var c := map.cell_of(i)
		var layers: Array = which if which is Array else range(StationMap.PIPE_LAYER_COUNT)
		var axis: int = which.get("axis", 15) if which is Dictionary else 15
		for l in layers:
			var other: PipeNet = null
			if axis == 15:
				other = net_of[l].get(i)
			else:
				for d in 4:
					if axis & (1 << d):
						var g := map.pipe_group_facing(l, c, d)
						if g >= 0:
							other = node_net[l].get(i * 4 + g)
							break
			if other == null or other == first:
				continue
			if first == null:
				first = other
				continue
			_merge(first, other)

func _merge(a: PipeNet, b: PipeNet) -> void:
	var c0 := a.heat_capacity()
	var c1 := b.heat_capacity()
	for g in Defs.GAS_COUNT:
		a.gas[g] += b.gas[g]
	if c0 + c1 > 0.01:
		a.temp = (a.temp * c0 + b.temp * c1) / (c0 + c1)
	a.volume += b.volume
	a.cells.append_array(b.cells)
	for l in StationMap.PIPE_LAYER_COUNT:
		for k in node_net[l].keys():
			if node_net[l][k] == b:
				node_net[l][k] = a
				if not a.nodes.has(k):
					a.nodes.append(k)
		for k in net_of[l].keys():
			if net_of[l][k] == b:
				net_of[l][k] = a
	nets.erase(b)

# ------------------------------------------------------------------ tick (driven by AtmosSystem)
## One whole tick (tests). In play the air subsystem drives tick_start / tick_step /
## tick_finish so the work is spread over frames (tg SSair pipenets + atmos machinery).
func tick(dt: float) -> void:
	tick_start(dt)
	tick_step(-1)
	tick_finish()

var _dt := 0.5
var _dev_run: Array = []
var _mach_run: Array = []
var _pos := 0

func tick_start(dt: float) -> void:
	if dirty:
		rebuild()
	_dt = dt
	_dev_run = devices.keys()
	_mach_run = machines.duplicate()
	_pos = 0
	for net in nets:
		net._prev_total = net.total_moles()
		net.flow = 0.0

## Works through the vents and machines; false if the frame's time ran out first.
func tick_step(deadline: int) -> bool:
	var at: AtmosSystem = Game.atmos
	var dt := _dt
	var total := _dev_run.size() + _mach_run.size()
	while _pos < total:
		var k := _pos
		_pos += 1
		if k < _dev_run.size():
			_device(_dev_run[k], at, dt)
		else:
			_machine(_mach_run[k - _dev_run.size()], dt)
		if (_pos & 7) == 0 and deadline >= 0 and Time.get_ticks_usec() >= deadline:
			return _pos >= total
	return true

func _device(key, at: AtmosSystem, dt: float) -> void:
	if not devices.has(key):
		return
	var list: Array = devices[key]
	for entry in list:
		var e: Entity = entry[2]
		if not is_instance_valid(e) or e.removed:
			devices.erase(key)
			break
		var layer: int = entry[0]
		var c: Vector2i = e.cell + entry[1]
		var net := net_at(layer, c)
		if e.has_c(&"vent") and e.c(&"vent").face != Vector2i.ZERO:
			net = net_facing(layer, c, e.c(&"vent").face)
		if e.has_c(&"vent"):
			_vent(e.c(&"vent"), net, c, at)
		elif e.has_c(&"reactor"):
			e.c(&"reactor").process_heat(net, dt)
		elif e.has_c(&"air_supply"):
			e.c(&"air_supply").supply(net, dt)
		elif e.has_c(&"hepipe"):
			e.c(&"hepipe").exchange(net, dt)
		elif e.has_c(&"powergen"):
			var pg: CPowerGen = e.c(&"powergen")
			if pg.kind == "radiator":
				pg.radiate(net, dt)
			elif pg.kind == "teg" and layer == StationMap.PL_HOT:
				pg.teg_exchange(net, net_at(StationMap.PL_COLD, e.cell + Vector2i(1, 0)), dt)

func _machine(m, dt: float) -> void:
	if not is_instance_valid(m) or m.removed:
		machines.erase(m)
		return
	var pmc: CPipeMachine = m.c(&"pipemachine")
	pmc.process(dt)
	if pmc.moved_last > 0.0:
		for nn in [pmc.net_in(), pmc.net_out(), pmc.net_side()]:
			if nn:
				nn.flow += pmc.moved_last

func tick_finish() -> void:
	var at: AtmosSystem = Game.atmos
	_leaks(at)
	# tg pipelines react like any other mixture (a fuel line can burn inside the pipe,
	# freon chills its line...)
	for net in nets:
		_react_net(net)
	for net in nets:
		net.flow = maxf(net.flow, absf(net.total_moles() - net._prev_total))
	for net in nets:
		if net.pressure() > 7000.0 and Game.rng.randf() < 0.05:
			var i: int = net.cells[Game.rng.randi() % net.cells.size()]
			map.damage_pipe(net.layer, map.cell_of(i), 70.0)
			Game.visible_message(map.cell_of(i), "A pipe bursts with a deafening bang!", "bad")
			Bus.stimulus.emit({"type": "pipe_burst", "cell": map.cell_of(i), "loud": 14.0})

func _react_net(net: PipeNet) -> void:
	var tot := net.total_moles()
	if tot < 0.01:
		return
	var m := []
	m.resize(Defs.GAS_COUNT)
	for g in Defs.GAS_COUNT:
		m[g] = net.gas[g]
	var ctx := {"m": m, "t": net.temp, "v": net.volume, "cell": Vector2i(-1, -1), "net": net}
	if GasReactions.react(ctx).is_empty():
		return
	for g in Defs.GAS_COUNT:
		net.gas[g] = maxf(0.0, m[g])
		if m[g] > 0.0 and g >= 8 and Game.atmos:
			Game.atmos.mark_present(g)
	net.temp = clampf(ctx["t"], 2.7, 1e6)

const VENT_NODE_VOLUME := 200.0 # tg unary devices' own air (airs[1].volume)
const SCRUBBER_VOLUME_RATE := 200.0 # tg vent_scrubber volume_rate, L per tick

## Moves `moles` of a tile's air (all gases in proportion) into a pipe.
func _room_to_pipe(i: int, net: PipeNet, moles: float, at: AtmosSystem) -> void:
	var have := at.total_moles(i)
	if have < 0.0001 or moles <= 0.0:
		return
	var f := minf(moles / have, 1.0)
	for g in at.present:
		var amt: float = at.gas[g][i] * f
		if amt > 0.0:
			at.remove_gas(i, g, amt)
			net.add_gas(g, amt, at.temp[i])

## One vent-type device's tick; records how much gas it moved (positive: pipe to room,
## negative: room to pipe) for the atmos overlay's arrows.
func _vent(v: CVent, net: PipeNet, c: Vector2i, at: AtmosSystem) -> void:
	if net == null or not v.working():
		v.moved_last = 0.0
		return
	var m0 := net.total_moles()
	_vent_step(v, net, c, at)
	v.moved_last = m0 - net.total_moles()

func _vent_step(v: CVent, net: PipeNet, c: Vector2i, at: AtmosSystem) -> void:
	var i := map.idx(c)
	match v.mode:
		"vent":
			if v.clogged > 0:
				v.clogged -= 0.5
				at.add_gas(i, Defs.G_SMOKE, 1.5, 320.0)
				return
			if v.siphon:
				# tg vent_pump siphoning (no bounds): a node's worth of room air into the pipe
				var env_p := at.pressure(i)
				var ttv := maxf(at.temp[i], 2.7)
				var want_s := minf(10000.0, env_p) * VENT_NODE_VOLUME / (ttv * Defs.R_IDEAL)
				_room_to_pipe(i, net, want_s, at)
				return
			# tg vent_pump releasing with an external bound: push what the pressure
			# difference asks for, as much as the vent's own section of pipe holds
			var p := at.pressure(i)
			var delta := minf(10000.0, v.target_pressure - p)
			var total := net.total_moles()
			if delta <= 0.0 or total < 0.001 or net.temp <= 0.0:
				return
			var mv := delta * Defs.CELL_VOLUME / (net.temp * Defs.R_IDEAL)
			mv = minf(mv, total * minf(1.0, VENT_NODE_VOLUME / maxf(net.volume, 1.0)))
			var out := net.take_fraction(mv / total)
			for g in Defs.GAS_COUNT:
				if out[g] > 0:
					at.add_gas(i, g, out[g], net.temp)
		"scrubber":
			# tg vent_scrubber: each tick it works volume_rate litres of the tile's air - the
			# filtered gases when scrubbing, everything when siphoning - and on a wide net the
			# tiles around it too
			var cells := [i]
			if v.widenet:
				for d in Defs.DIRS4:
					var nc: Vector2i = c + d
					if map.inb(nc) and not map.blocks_air(nc):
						cells.append(map.idx(nc))
			var f := SCRUBBER_VOLUME_RATE / Defs.CELL_VOLUME
			if net.pressure() >= 10000.0:
				return # tg: the scrubber stops when its pipe is full
			for k in cells:
				for g in (at.present if v.siphon else v.filters.keys()):
					if not v.siphon and not v.filters[g]:
						continue
					var amt: float = at.gas[g][k] * f
					if amt > 0.0001:
						at.remove_gas(k, g, amt)
						net.add_gas(g, amt, at.temp[k])
		"outlet":
			var total2 := net.total_moles()
			if net.pressure() > 50.0 and total2 > 0:
				net.take_fraction(0.25)
		"injector":
			# tg outlet_injector: volume_rate litres of the pipe's gas onto the tile each second
			var tot := net.total_moles()
			if tot < 0.001 or net.temp <= 0.0:
				return
			var mol: float = net.pressure() * v.volume_rate * AtmosSystem.TICK / (net.temp * Defs.R_IDEAL)
			var out := net.take_fraction(minf(mol / tot, 1.0))
			for g in Defs.GAS_COUNT:
				if out[g] > 0:
					at.add_gas(i, g, out[g], net.temp)
			at.wake(c)
		"siphon":
			# tg vent_pump siphoning with an internal bound: pull the room's gas into the pipe
			# until the pipe reaches internal_bound (chamber outputs: 4000 kPa)
			var env_p := at.pressure(i)
			var delta := minf(10000.0, env_p)
			delta = minf(delta, v.internal_bound - net.pressure())
			if delta <= 0.0:
				return
			var tt := maxf(at.temp[i], 2.7)
			var want: float = delta * v.volume_l / (tt * Defs.R_IDEAL)
			var have := 0.0
			for g in Defs.GAS_COUNT:
				have += at.gas[g][i]
			if have < 0.001:
				return
			var f := minf(want / have, 1.0)
			for g in Defs.GAS_COUNT:
				var amt: float = at.gas[g][i] * f
				if amt > 0.0:
					at.remove_gas(i, g, amt)
					net.add_gas(g, amt, at.temp[i])
			at.wake(c)
		"passive":
			# tg passive_vent: an open pipe end; the pipe and the tile share toward equal pressure
			var pn := net.pressure()
			var pt := at.pressure(i)
			if absf(pn - pt) < 0.5:
				return
			if pn > pt:
				var tot2 := net.total_moles()
				var f2 := clampf((pn - pt) / (2.0 * maxf(pn, 0.01)), 0.0, 0.5)
				var out2 := net.take_fraction(f2)
				for g in Defs.GAS_COUNT:
					if out2[g] > 0:
						at.add_gas(i, g, out2[g], net.temp)
			else:
				var have2 := 0.0
				for g in Defs.GAS_COUNT:
					have2 += at.gas[g][i]
				var f3 := clampf((pt - pn) / (2.0 * maxf(pt, 0.01)), 0.0, 0.5)
				for g in Defs.GAS_COUNT:
					var amt2: float = at.gas[g][i] * f3
					if amt2 > 0.0:
						at.remove_gas(i, g, amt2)
						net.add_gas(g, amt2, at.temp[i])
			at.wake(c)

## Take a share of everything in a tile's air into a pipe (tg: siphoning).
func _siphon(i: int, net: PipeNet, rate: float, at: AtmosSystem) -> void:
	var total := 0.0
	for g in Defs.GAS_COUNT:
		total += at.gas[g][i]
	if total < 0.05:
		return
	var f := minf(0.25, rate * 2.0 / total)
	for g in Defs.GAS_COUNT:
		var amt: float = at.gas[g][i] * f
		if amt > 0.0:
			at.remove_gas(i, g, amt)
			net.add_gas(g, amt, at.temp[i])

func _leaks(at: AtmosSystem) -> void:
	for d in map.damaged_pipes():
		var layer: int = d[0]
		var c: Vector2i = d[1]
		var hp := map.pipe_hp_at(layer, c)
		if hp >= 60.0:
			continue
		var net := net_at(layer, c)
		if net == null:
			continue
		var total := net.total_moles()
		if total < 0.05:
			continue
		var frac := 0.03 * (1.0 - hp / 60.0) + 0.01
		var out := net.take_fraction(frac)
		if map.is_outdoor(c) or map.is_solid_turf(c):
			continue
		var i := map.idx(c)
		for g in Defs.GAS_COUNT:
			if out[g] > 0:
				at.add_gas(i, g, out[g], net.temp)
		if Game.rng.randf() < 0.08:
			Bus.stimulus.emit({"type": "pipe_leak", "cell": c, "loud": 5.0, "layer": layer})
			if layer == StationMap.PL_HOT and Game.rng.randf() < 0.3:
				Liquids.spill(c, "coolant", 6.0)
