class_name AtmosSystem extends Node
## Tile atmospherics, loosely after tg's LINDA: each open interior tile holds a gas
## mixture; active tiles share gas and heat with neighbours each tick; big pressure
## differences create wind. Outdoor tiles are an infinite frigid reservoir.
## Also: heat loss through the hull into the arctic, heaters, and fire (hotspots).

const TICK := 0.5 # tg SSair fires every 0.5 s
# tg atmos_core.dm
const MOLAR_ACCURACY := 1e-4
const MIN_TEMP_DELTA_CONSIDER := 0.5
const MIN_HEAT_CAPACITY := 0.0003
const MIN_MOLES_DELTA_TO_MOVE := Defs.MOLES_CELLSTANDARD * 0.001
const MIN_AIR_RATIO_TO_MOVE := 0.001
const MIN_AIR_TO_SUSPEND := Defs.MOLES_CELLSTANDARD * 0.1
const MIN_TEMP_TO_MOVE := Defs.T20C + 100.0
const MIN_TEMP_DELTA_SUSPEND := 4.0
const OPEN_HEAT_TRANSFER_COEFFICIENT := 0.4
const TCMB := 2.7
const BREAKDOWN_CYCLES := 5
const DISMANTLE_CYCLES := BREAKDOWN_CYCLES * 2 + 1
# tg reactions.dm
const FIRE_MIN_TEMP := 100.0 + Defs.T0C
const FIRE_MIN_TEMP_TO_SPREAD := 150.0 + Defs.T0C
const FIRE_SPREAD_RADIOSITY_SCALE := 0.85
const FIRE_GROWTH_RATE := 40000.0
const PLASMA_UPPER_TEMPERATURE := FIRE_MIN_TEMP + 1270.0
const OXYGEN_BURN_RATIO_BASE := 1.4
const PLASMA_OXYGEN_FULLBURN := 10.0
const SUPER_SATURATION_THRESHOLD := 96.0
const PLASMA_BURN_RATE_DELTA := 9.0
const FIRE_PLASMA_ENERGY_RELEASED := 3e6
const FIRE_TRITIUM_ENERGY_RELEASED := 2.8e6
const TRITIUM_OXYGEN_FULLBURN := 10.0
const FIRE_TRITIUM_BURN_RATE_DELTA := 2.0
const MINIMUM_MOLE_COUNT := 0.01
const MOLES_GAS_VISIBLE := 0.25
const WATER_VAPOR_CONDENSATION_POINT := Defs.T20C + 10.0
const WATER_VAPOR_DEPOSITION_POINT := 200.0
const N2O_DECOMP_MIN_T := 1400.0
const N2O_DECOMP_MAX_T := 100000.0
const N2O_DECOMP_ENERGY := 200000.0
# tg move_force.dm / space wind
const MOVE_FORCE_DEFAULT := 1000.0
const MOVE_RESIST_DEFAULT := 1000.0

var map: StationMap
var n := 0
var gas: Array = []
var temp: PackedFloat32Array
var active := {}
var wind_x: PackedFloat32Array
var wind_y: PackedFloat32Array
var hotspots := {} # Vector2i -> {fuel, node}
var edge_tiles := PackedInt32Array()
var edge_exposure := PackedFloat32Array()
var acc := 0.0
var heat_acc := 0.0
var tick_count := 0
var ext_temp := Defs.EXT_TEMP
## The outdoor tile the cell being processed is currently sharing with (-1: none). Open
## sky is one composition everywhere in a region but its temperature varies island by
## island, so the "outside" half of a share reads its temperature from here.
var _ext_i := -1
var _sh := PackedFloat32Array(Defs.GAS_SPECIFIC_HEAT)
var _ext := PackedFloat32Array(Defs.EXT_GASES)
var _nbr := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
var dirty_visual := {} # tiles whose gas overlay should be redrawn
# tg LINDA bookkeeping
var arc_gas: Array = [] # archived moles, per gas (tg moles_archive)
var arc_temp: PackedFloat32Array # tg temperature_archived
var arc_cycle: PackedInt32Array # the cycle each tile was archived in
var cur_cycle: PackedInt32Array # the cycle each tile was last processed in
var last_share: PackedFloat32Array
var group_of := {} # tile -> excited group id
var groups := {} # id -> {"tiles": {}, "breakdown": int, "dismantle": int}
var _next_group := 1
var pdiff := {} # tile -> [pressure difference, direction]: tg consider_pressure_difference
var _react_results := {} # tg reaction_results of the last react() call
## The gases that exist anywhere on the station. tg only stores the gases a mixture has; we
## keep every gas in its own array but only loop over the ones that have ever appeared, so
## the rare ones cost nothing until someone makes some. Starts with the eight everyday ones.
var present := PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7])

func mark_present(g: int) -> void:
	if not g in present:
		present.append(g)

func setup(m: StationMap) -> void:
	map = m
	n = m.w * m.h
	gas.clear()
	for g in Defs.GAS_COUNT:
		var a := PackedFloat32Array()
		a.resize(n)
		gas.append(a)
	temp = PackedFloat32Array()
	temp.resize(n)
	wind_x = PackedFloat32Array()
	wind_x.resize(n)
	wind_y = PackedFloat32Array()
	wind_y.resize(n)
	arc_gas.clear()
	for g in Defs.GAS_COUNT:
		var aa := PackedFloat32Array()
		aa.resize(n)
		arc_gas.append(aa)
	arc_temp = PackedFloat32Array()
	arc_temp.resize(n)
	arc_cycle = PackedInt32Array()
	arc_cycle.resize(n)
	arc_cycle.fill(-1)
	cur_cycle = PackedInt32Array()
	cur_cycle.resize(n)
	cur_cycle.fill(-1)
	last_share = PackedFloat32Array()
	last_share.resize(n)
	for i in n:
		var c := m.cell_of(i)
		if m.is_outdoor(c):
			for g in Defs.GAS_COUNT:
				gas[g][i] = _ext[g]
			temp[i] = Defs.EXT_TEMP
		elif m.is_solid_turf(c):
			temp[i] = Defs.EXT_TEMP
		else:
			gas[Defs.G_O2][i] = Defs.MOLES_CELLSTANDARD * 0.21
			gas[Defs.G_N2][i] = Defs.MOLES_CELLSTANDARD * 0.79
			temp[i] = Defs.T20C
	# gas chambers and the like start full of their own gas
	for i in m.initial_air:
		var mix: PackedFloat32Array = m.initial_air[i]
		var total := 0.0
		for g in Defs.GAS_COUNT:
			gas[g][i] = mix[g]
			total += mix[g]
			if mix[g] > 0.0:
				mark_present(g)
		temp[i] = Defs.T20C if total > 0.0 else 2.7
	_edges_full = true
	rebuild_edges() # full scan once, here; afterwards only changed tiles are rescanned
	Bus.tile_changed.connect(_on_tile_changed)

## Re-read one tile after its turf changed, without going through the event bus. An
## airship rewrites a hundred-odd tiles every step it flies, and one signal per tile is
## more bookkeeping than the frame can spare.
func retile(c: Vector2i) -> void:
	_on_tile_changed(c)

func _on_tile_changed(c: Vector2i) -> void:
	if not map.inb(c):
		return
	var i := map.idx(c)
	if map.is_solid_turf(c):
		for g in Defs.GAS_COUNT:
			gas[g][i] = 0.0
	elif map.is_outdoor(c):
		for g in Defs.GAS_COUNT:
			gas[g][i] = _ext[g]
		temp[i] = ext_temp
	elif total_moles(i) < 0.01 and temp[i] < 3.0:
		temp[i] = ext_temp
	wake(c)
	_edges_dirty = true
	_edge_touched[i] = true

var _edges_dirty := false

func note_air_block(i: int) -> void:
	if map == null or _edges_full:
		return
	_edge_touched[i] = true
	_edges_dirty = true
var _edge_map := {}          # tile idx -> exposure (only tiles that lose heat to the outside)
var _edge_touched := {}      # tile idx -> true: changed tiles since the last rebuild
var _edges_full := true      # no incremental baseline yet: scan the whole map

## Heat-loss exposure of one tile: how many outside-touching wall/window faces it has
## (windows count double); 0 when it isn't a simulated tile or is a gas-chamber floor.
func _edge_exposure_of(i: int) -> float:
	var c := map.cell_of(i)
	if not _is_sim(c):
		return 0.0
	if map.area_at(c).room_kind == "gas_chamber":
		return 0.0 # tg engine floors: the chambers keep their gas at room temperature
	var ex := 0.0
	for d in _nbr:
		var nc: Vector2i = c + d
		if not map.inb(nc):
			continue
		var s := map.structure[map.idx(nc)]
		var is_window := Defs.is_window(s)
		if map.is_solid_turf(nc) or is_window:
			# does this wall touch the outside?
			for d2 in _nbr:
				if map.is_outdoor(nc + d2):
					ex += 2.0 if is_window else 1.0
					break
	return ex

## An edge tile's exposure depends on tiles up to two steps away, so a changed tile
## invalidates the 5x5 block around it. An airship rewrites ~100 tiles per step; rescanning
## the whole 512x448 map each time (the old behaviour) was a ~0.6 s hitch. Same result.
func rebuild_edges() -> void:
	if _edges_full:
		_edge_map.clear()
		for i in n:
			var ex := _edge_exposure_of(i)
			if ex > 0.0:
				_edge_map[i] = ex
		_edges_full = false
	else:
		var seen := {}
		for ti in _edge_touched.keys():
			var tx: int = ti % map.w
			var ty: int = ti / map.w
			for yy in range(ty - 2, ty + 3):
				if yy < 0 or yy >= map.h:
					continue
				for xx in range(tx - 2, tx + 3):
					if xx < 0 or xx >= map.w:
						continue
					var i2: int = yy * map.w + xx
					if seen.has(i2):
						continue
					seen[i2] = true
					var ex2 := _edge_exposure_of(i2)
					if ex2 > 0.0:
						_edge_map[i2] = ex2
					else:
						_edge_map.erase(i2)
	_edge_touched.clear()
	var keys := PackedInt32Array(_edge_map.keys())
	keys.sort() # index order, as the full scan produced
	edge_tiles = keys
	edge_exposure = PackedFloat32Array()
	edge_exposure.resize(keys.size())
	for k in keys.size():
		edge_exposure[k] = _edge_map[keys[k]]
	_edges_dirty = false

# ------------------------------------------------------------------ queries
func _is_sim(c: Vector2i) -> bool:
	return map.inb(c) and not map.blocks_air(c) and not map.is_outdoor(c)

func total_moles(i: int) -> float:
	var t := 0.0
	for g in present:
		t += gas[g][i]
	return t

func heat_cap(i: int) -> float:
	var c := 0.0
	for g in present:
		c += gas[g][i] * _sh[g]
	return c

func pressure(i: int) -> float:
	return total_moles(i) * Defs.R_IDEAL * temp[i] / Defs.CELL_VOLUME

func partial(i: int, g: int) -> float:
	return gas[g][i] * Defs.R_IDEAL * temp[i] / Defs.CELL_VOLUME

func pressure_at(c: Vector2i) -> float:
	return pressure(map.idx(c)) if map.inb(c) else 0.0

func temp_at(c: Vector2i) -> float:
	return temp[map.idx(c)] if map.inb(c) else ext_temp

func wind_at(c: Vector2i) -> Vector2:
	if not map.inb(c):
		return Vector2.ZERO
	var i := map.idx(c)
	return Vector2(wind_x[i], wind_y[i])

func wake(c: Vector2i) -> void:
	if map == null:
		return
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var cc: Vector2i = c + d
		if _is_sim(cc):
			active[map.idx(cc)] = true

func add_gas(i: int, g: int, moles: float, t: float) -> void:
	var c := map.cell_of(i)
	if not _is_sim(c):
		return
	if moles > 0.0 and g >= 8:
		mark_present(g)
	var cap0 := heat_cap(i)
	var e0 := cap0 * temp[i]
	gas[g][i] += moles
	var cap1 := heat_cap(i)
	if cap1 > 0.001:
		temp[i] = (e0 + moles * _sh[g] * t) / cap1
	active[i] = true
	dirty_visual[i] = true

func remove_gas(i: int, g: int, moles: float) -> float:
	var take := minf(moles, gas[g][i])
	gas[g][i] -= take
	active[i] = true
	dirty_visual[i] = true
	return take

func add_heat(i: int, joules: float) -> void:
	var c := map.cell_of(i)
	if not _is_sim(c):
		return
	var cap := heat_cap(i)
	if cap < 1.0:
		cap = 1.0
	temp[i] = clampf(temp[i] + joules / cap, 2.7, 6000.0)
	active[i] = true

# ------------------------------------------------------------------ tick
## tg SSair runs under the master controller's tick budget (MC_TICK_CHECK): each part
## (pipenets, active turfs, hotspots, excited groups, high pressure) works through its list
## and, when the frame's time is used up, pauses and resumes next frame. We do the same so a
## busy atmos cycle is spread over frames instead of stalling one.
const FRAME_BUDGET_USEC := 3000
enum { PART_IDLE, PART_PIPENETS, PART_ACTIVETURFS, PART_HOTSPOTS, PART_EXCITEDGROUPS, PART_HIGHPRESSURE }
var _part := PART_IDLE
var _run: Array = []
var _run_pos := 0
var _adj_cache := {}

func _process(delta: float) -> void:
	var _pt := Perf.t0()
	_process_body(delta)
	Perf.add("atmos", _pt)

func _process_body(delta: float) -> void:
	if not Game.running or Game.paused:
		return
	acc += delta * Game.time_scale
	heat_acc += delta * Game.time_scale
	if heat_acc >= 2.0:
		heat_acc = 0.0
		var _t := Perf.t0()
		heat_loss_pass(2.0)
		Perf.add("a.heatloss", _t)
	if _part == PART_IDLE:
		if acc < TICK:
			return
		acc = minf(acc - TICK, TICK)
		_begin_cycle()
	# a cycle that's running late gets more of the frame, like the MC easing off other work
	var budget := FRAME_BUDGET_USEC if acc < TICK else FRAME_BUDGET_USEC * 3
	_run_parts(Time.get_ticks_usec() + budget)

## One whole cycle at once (tests and warm-up).
func tick() -> void:
	if _part == PART_IDLE:
		_begin_cycle()
	_run_parts(-1)

func _begin_cycle() -> void:
	tick_count += 1
	if _edges_dirty:
		var _t := Perf.t0()
		rebuild_edges()
		Perf.add("a.edges", _t)
	pdiff.clear()
	_adj_cache.clear()
	for i in active.keys():
		wind_x[i] *= 0.5
		wind_y[i] *= 0.5
	_part = PART_PIPENETS
	if Game.pipes:
		Game.pipes.tick_start(TICK)

func _out_of_time(deadline: int) -> bool:
	return deadline >= 0 and Time.get_ticks_usec() >= deadline

func _run_parts(deadline: int) -> void:
	if _part == PART_PIPENETS:
		var _t := Perf.t0()
		var _done: bool = Game.pipes == null or Game.pipes.tick_step(deadline)
		Perf.add("a.pipestep", _t)
		if not _done:
			return
		if Game.pipes:
			_t = Perf.t0()
			Game.pipes.tick_finish()
			Perf.add("a.pipefin", _t)
		_part = PART_ACTIVETURFS
		_run = active.keys()
		_run_pos = 0
	if _part == PART_ACTIVETURFS:
		# tg SSair: process every active turf once; each pair shares once per cycle
		var _t2 := Perf.t0()
		while _run_pos < _run.size():
			var i: int = _run[_run_pos]
			_run_pos += 1
			if active.has(i):
				_process_cell(i)
			if (_run_pos & 15) == 0 and _out_of_time(deadline):
				Perf.add("a.cells", _t2)
				return
		Perf.add("a.cells", _t2)
		_run = []
		_part = PART_HOTSPOTS
	if _part == PART_HOTSPOTS:
		var _t3 := Perf.t0()
		_fire_tick()
		Perf.add("a.fire", _t3)
		_part = PART_EXCITEDGROUPS
		if _out_of_time(deadline):
			return
	if _part == PART_EXCITEDGROUPS:
		var _t4 := Perf.t0()
		_process_groups()
		Perf.add("a.groups", _t4)
		_part = PART_HIGHPRESSURE
		if _out_of_time(deadline):
			return
	if _part == PART_HIGHPRESSURE:
		var _t5 := Perf.t0()
		_high_pressure_movements()
		Perf.add("a.hipress", _t5)
		_part = PART_IDLE

# ------------------------------------------------------------------ tg LINDA
func _archive(i: int) -> void:
	if arc_cycle[i] >= tick_count:
		return
	arc_cycle[i] = tick_count
	for g in present:
		arc_gas[g][i] = gas[g][i]
	arc_temp[i] = temp[i]

## Open neighbours of a tile: other tiles (>= 0) and the outside (-1 - direction).
func _adjacent(i: int) -> Array:
	var cached = _adj_cache.get(i)
	if cached != null:
		return cached
	var c := map.cell_of(i)
	var out := []
	for k in 4:
		var nc: Vector2i = c + _nbr[k]
		if not map.inb(nc) or map.blocks_air(nc):
			continue
		if map.is_outdoor(nc):
			out.append(-1 - k)
		else:
			out.append(map.idx(nc))
	_adj_cache[i] = out
	return out

## tg turf/open/process_cell.
func _process_cell(i: int) -> void:
	var c := map.cell_of(i)
	if not _is_sim(c):
		active.erase(i)
		return
	_archive(i)
	cur_cycle[i] = tick_count
	var adj := _adjacent(i)
	var coeff := 1.0 / float(adj.size() + 1)
	var gid: int = group_of.get(i, 0)
	for nb in adj:
		if nb < 0:
			# The open sky, which never runs out (tg planetary / immutable mix). Its
			# composition is the region's altitude air, but its temperature is read off
			# that particular tile, so an island's own climate — a cinder isle's heat, a
			# frost isle's bite — conducts through a hull the way it should.
			_ext_i = map.idx(c + _nbr[-1 - nb])
			if _compare_ext(i):
				if gid == 0:
					gid = _new_group()
					_group_add(gid, i)
				var diff := _share(i, -1, coeff, 0.2)
				_last_share_check(i, gid)
				if diff > 0.0:
					_consider(i, c + _nbr[-1 - nb], diff)
			continue
		var j: int = nb
		if cur_cycle[j] >= tick_count:
			continue # it shared with us already this cycle
		_archive(j)
		var should := false
		var gj: int = group_of.get(j, 0)
		if gid != 0 and gj != 0 and gid != gj:
			gid = _merge_groups(gid, gj)
			gj = gid
		if gid != 0 and gj != 0 and active.has(j):
			should = true
		elif _compare(i, j):
			active[j] = true
			var g2: int = gid if gid != 0 else (gj if gj != 0 else _new_group())
			if gid == 0:
				_group_add(g2, i)
			if gj == 0:
				_group_add(g2, j)
			gid = g2
			should = true
		if should:
			var diff2 := _share(i, j, coeff, 1.0 / float(_adjacent(j).size() + 1))
			_last_share_check(i, gid)
			if diff2 > 0.0:
				_consider(i, map.cell_of(j), diff2)
			elif diff2 < 0.0:
				_consider(j, c, -diff2)
			dirty_visual[j] = true
	var reacting := react(i)
	dirty_visual[i] = true
	if gid == 0 and not reacting and not hotspots.has(c):
		active.erase(i)

func _last_share_check(i: int, gid: int) -> void:
	if gid == 0 or not groups.has(gid):
		return
	if last_share[i] > MIN_AIR_TO_SUSPEND:
		groups[gid]["breakdown"] = 0
		groups[gid]["dismantle"] = 0
	elif last_share[i] > MIN_MOLES_DELTA_TO_MOVE:
		groups[gid]["dismantle"] = 0

## tg gas_mixture/compare(sample, cmp_archive = TRUE): true when there's something to share.
func _compare(i: int, j: int) -> bool:
	var ti := 0.0
	var tj := 0.0
	for g in present:
		ti += gas[g][i]
		tj += gas[g][j]
	if absf(ti - tj) > MIN_MOLES_DELTA_TO_MOVE:
		return true
	for g in present:
		var a: float = arc_gas[g][i]
		var d := absf(a - arc_gas[g][j])
		if d > MIN_MOLES_DELTA_TO_MOVE and d > a * MIN_AIR_RATIO_TO_MOVE:
			return true
	if ti > MIN_MOLES_DELTA_TO_MOVE and absf(arc_temp[i] - arc_temp[j]) > MIN_TEMP_DELTA_SUSPEND:
		return true
	return false

## The temperature of the open-sky tile currently being shared with.
func _ext_t() -> float:
	return temp[_ext_i] if _ext_i >= 0 else ext_temp

## Re-read the sky reservoir after the region's altitude changed (Defs.set_altitude).
func refresh_external() -> void:
	_ext = PackedFloat32Array(Defs.EXT_GASES)
	ext_temp = Defs.EXT_TEMP
	for g in Defs.GAS_COUNT:
		if _ext[g] > 0.0:
			mark_present(g)

func _compare_ext(i: int) -> bool:
	var ti := 0.0
	var te := 0.0
	for g in present:
		ti += gas[g][i]
		te += _ext[g]
	if absf(ti - te) > MIN_MOLES_DELTA_TO_MOVE:
		return true
	for g in present:
		var a: float = arc_gas[g][i]
		var d := absf(a - _ext[g])
		if d > MIN_MOLES_DELTA_TO_MOVE and d > a * MIN_AIR_RATIO_TO_MOVE:
			return true
	return ti > MIN_MOLES_DELTA_TO_MOVE and absf(arc_temp[i] - _ext_t()) > MIN_TEMP_DELTA_SUSPEND

static func _quantize(v: float) -> float:
	return snappedf(v, MOLAR_ACCURACY)

func _heat_cap_arc(i: int) -> float:
	var hc := 0.0
	for g in present:
		hc += arc_gas[g][i] * _sh[g]
	return hc

## tg gas_mixture/share(sharer, our_coeff, sharer_coeff). j = -1 shares with the outside
## air, which doesn't change. Returns the pressure difference, for space wind.
func _share(i: int, j: int, our_coeff: float, their_coeff: float) -> float:
	var ext := j < 0
	var t_arc_j: float = _ext_t() if ext else arc_temp[j]
	var temperature_delta: float = arc_temp[i] - t_arc_j
	var thr := absf(temperature_delta) > MIN_TEMP_DELTA_CONSIDER
	var old_hc_i := 0.0
	var old_hc_j := 0.0
	if thr:
		old_hc_i = heat_cap(i)
		if ext:
			for g in present:
				old_hc_j += _ext[g] * _sh[g]
		else:
			old_hc_j = heat_cap(j)
	var hc_i_to_j := 0.0
	var hc_j_to_i := 0.0
	var moved := 0.0
	var abs_moved := 0.0
	for g in present:
		var their: float = _ext[g] if ext else arc_gas[g][j]
		var delta := _quantize(arc_gas[g][i] - their)
		if delta == 0.0:
			continue
		delta *= our_coeff if delta > 0.0 else their_coeff
		if thr:
			var ghc := delta * _sh[g]
			if delta > 0.0:
				hc_i_to_j += ghc
			else:
				hc_j_to_i -= ghc
		gas[g][i] = maxf(0.0, gas[g][i] - delta)
		if not ext:
			gas[g][j] = maxf(0.0, gas[g][j] + delta)
		moved += delta
		abs_moved += absf(delta)
	last_share[i] = abs_moved
	if thr:
		var new_hc_i := old_hc_i + hc_j_to_i - hc_i_to_j
		var new_hc_j := old_hc_j + hc_i_to_j - hc_j_to_i
		if new_hc_i > MIN_HEAT_CAPACITY:
			temp[i] = (old_hc_i * temp[i] - hc_i_to_j * arc_temp[i] + hc_j_to_i * t_arc_j) / new_hc_i
		if not ext and new_hc_j > MIN_HEAT_CAPACITY:
			temp[j] = (old_hc_j * temp[j] - hc_j_to_i * t_arc_j + hc_i_to_j * arc_temp[i]) / new_hc_j
			if absf(old_hc_j) > MIN_HEAT_CAPACITY and absf(new_hc_j / old_hc_j - 1.0) < 0.1:
				_temperature_share(i, j, OPEN_HEAT_TRANSFER_COEFFICIENT)
		elif ext:
			_temperature_share(i, -1, OPEN_HEAT_TRANSFER_COEFFICIENT)
	temp[i] = clampf(temp[i], TCMB, 1e6)
	if not ext:
		temp[j] = clampf(temp[j], TCMB, 1e6)
	if temperature_delta > MIN_TEMP_TO_MOVE or absf(moved) > MIN_MOLES_DELTA_TO_MOVE:
		var our_moles := 0.0
		var their_moles := 0.0
		for g in present:
			our_moles += gas[g][i]
			their_moles += _ext[g] if ext else gas[g][j]
		return (arc_temp[i] * (our_moles + moved) - t_arc_j * (their_moles - moved)) * Defs.R_IDEAL / Defs.CELL_VOLUME
	return 0.0

## tg gas_mixture/temperature_share: conduction between two mixtures.
func _temperature_share(i: int, j: int, coeff: float) -> void:
	var ext := j < 0
	var tj: float = _ext_t() if ext else arc_temp[j]
	var dT: float = arc_temp[i] - tj
	if absf(dT) <= MIN_TEMP_DELTA_CONSIDER:
		return
	var hci := _heat_cap_arc(i)
	var hcj := 0.0
	if ext:
		for g in present:
			hcj += _ext[g] * _sh[g]
		hcj *= 5.0 # tg planetary: heat_capacity() * 5
	else:
		hcj = _heat_cap_arc(j)
	if hcj > MIN_HEAT_CAPACITY and hci > MIN_HEAT_CAPACITY:
		var heat := coeff * dT * (hcj * hci / (hcj + hci))
		temp[i] = maxf(temp[i] - heat / hci, TCMB)
		if not ext:
			temp[j] = maxf(temp[j] + heat / hcj, TCMB)

# ---------------- excited groups (tg /datum/excited_group)
func _new_group() -> int:
	var id := _next_group
	_next_group += 1
	groups[id] = {"tiles": {}, "breakdown": 0, "dismantle": 0}
	return id

func _group_add(gid: int, i: int) -> void:
	groups[gid]["tiles"][i] = true
	group_of[i] = gid

func _merge_groups(a: int, b: int) -> int:
	var big := a if groups[a]["tiles"].size() >= groups[b]["tiles"].size() else b
	var small := b if big == a else a
	for t in groups[small]["tiles"]:
		groups[big]["tiles"][t] = true
		group_of[t] = big
	groups[big]["breakdown"] = 0
	groups[big]["dismantle"] = 0
	groups.erase(small)
	return big

func _process_groups() -> void:
	for gid in groups.keys():
		if not groups.has(gid):
			continue
		var g: Dictionary = groups[gid]
		g["breakdown"] += 1
		g["dismantle"] += 1
		var volatile := false
		for t in g["tiles"]:
			if hotspots.has(map.cell_of(t)):
				volatile = true
				break
		if g["breakdown"] >= BREAKDOWN_CYCLES and not volatile:
			_self_breakdown(g)
		elif g["dismantle"] >= DISMANTLE_CYCLES and not volatile:
			for t in g["tiles"]:
				group_of.erase(t)
				active.erase(t)
			groups.erase(gid)

## tg self_breakdown: the whole settled group evens out to its average.
func _self_breakdown(g: Dictionary) -> void:
	var tiles: Dictionary = g["tiles"]
	var cnt := tiles.size()
	if cnt == 0:
		return
	var sums := PackedFloat32Array()
	sums.resize(Defs.GAS_COUNT)
	var energy := 0.0
	var hcap := 0.0
	var outside := false
	for t in tiles:
		if not _is_sim(map.cell_of(t)):
			continue
		var hc := heat_cap(t)
		energy += temp[t] * hc
		hcap += hc
		for gg in Defs.GAS_COUNT:
			sums[gg] += gas[gg][t]
		for nb in _adjacent(t):
			if nb < 0:
				outside = true
	var t_avg := energy / hcap if hcap > MIN_HEAT_CAPACITY else ext_temp
	for t in tiles:
		if not _is_sim(map.cell_of(t)):
			continue
		for gg in Defs.GAS_COUNT:
			gas[gg][t] = sums[gg] / cnt
		temp[t] = t_avg
		dirty_visual[t] = true
	g["breakdown"] = 0
	if outside:
		g["dismantle"] = 0 # an open breach never settles

# ---------------- space wind (tg consider_pressure_difference / high_pressure_movements)
func _consider(i: int, toward: Vector2i, diff: float) -> void:
	var c := map.cell_of(i)
	var d := toward - c
	if not pdiff.has(i) or diff > pdiff[i][0]:
		pdiff[i] = [diff, d]
	wind_x[i] += d.x * diff * 0.02
	wind_y[i] += d.y * diff * 0.02

func _high_pressure_movements() -> void:
	var moved := {}
	for i in pdiff:
		var diff: float = pdiff[i][0]
		var dir: Vector2i = pdiff[i][1]
		var c := map.cell_of(i)
		for e in Game.at(c).duplicate():
			if moved.has(e) or e.holder != null or e.removed:
				continue
			if e.tags.get("anchored", not e.has_c(&"item") and not e.has_c(&"mob")):
				continue
			var m: CMob = e.c(&"mob")
			if m and (m.buckled != null or m.pulled_by != null):
				continue
			# tg experience_pressure_difference
			var resistance := 25.0 if m else (4.0 if e.has_c(&"item") else 10.0)
			var move_prob := diff / resistance * 75.0 - 25.0
			var max_force := sqrt(diff) * (MOVE_FORCE_DEFAULT / 5.0)
			if move_prob > 25.0 and Game.rng.randf() * 100.0 < move_prob and max_force >= MOVE_RESIST_DEFAULT:
				var to := c + dir
				if map.blocks_move_static(to) or Game.at(to).any(func(x): return x != e and x.has_c(&"blocker") and x.c(&"blocker").dense):
					continue
				moved[e] = true
				Interact.glide(e, to, 0.15)

# ------------------------------------------------------------------ tg reactions
## tg gas_mixture/react on a tile. Returns true if anything reacted.
func react(i: int) -> bool:
	var m := []
	m.resize(Defs.GAS_COUNT)
	m.fill(0.0)
	for g in present:
		m[g] = gas[g][i]
	var ctx := {"m": m, "t": temp[i], "v": Defs.CELL_VOLUME, "cell": map.cell_of(i), "net": null}
	var res := GasReactions.react(ctx)
	if res.is_empty():
		return false
	_react_results = res
	for g in Defs.GAS_COUNT:
		if m[g] > 0.0 or g in present:
			if m[g] > 0.0 and not g in present:
				mark_present(g)
			gas[g][i] = maxf(0.0, m[g])
	temp[i] = clampf(ctx["t"], TCMB, 1e6)
	return true

func _mix_hc(mix: PackedFloat32Array) -> float:
	var hc := 0.0
	for g in Defs.GAS_COUNT:
		hc += mix[g] * _sh[g]
	return hc

## tg's reactions on any mixture (a pocket of burning air, a tank...). Returns {mix, temp,
## results}. See GasReactions.
func react_mix(mix: PackedFloat32Array, t: float, cell := Vector2i(-1, -1), volume := Defs.CELL_VOLUME) -> Dictionary:
	var m := []
	m.resize(Defs.GAS_COUNT)
	for g in Defs.GAS_COUNT:
		m[g] = mix[g] if g < mix.size() else 0.0
	var ctx := {"m": m, "t": t, "v": volume, "cell": cell, "net": null}
	var res := GasReactions.react(ctx)
	var out := PackedFloat32Array()
	out.resize(Defs.GAS_COUNT)
	for g in Defs.GAS_COUNT:
		out[g] = m[g]
		if m[g] > 0.0 and g >= 8:
			mark_present(g)
	return {"mix": out, "temp": clampf(ctx["t"], TCMB, 1e6), "results": res}

## Heat escaping through the hull, and room heaters fighting back.
func heat_loss_pass(dt: float) -> void:
	var k := 0.0009 * dt
	for idx in edge_tiles.size():
		var i := edge_tiles[idx]
		var t := temp[i]
		if t <= ext_temp:
			continue
		var before := t
		t -= (t - ext_temp) * k * edge_exposure[idx]
		temp[i] = t
		if absf(before - t) > 0.25:
			active[i] = true
	# heating per area
	var budgets := {}
	for h in Game.all_with(&"heater"):
		if h.c(&"heater").working():
			var aid := map.area[map.idx(h.cell)]
			budgets[aid] = budgets.get(aid, 0.0) + h.c(&"heater").power_w * dt
	for aid in budgets.keys():
		var a: Area = map.areas[aid]
		var budget: float = budgets[aid]
		var cells := a.cells
		if cells.is_empty():
			continue
		for c in cells:
			var i := map.idx(c)
			if not _is_sim(c):
				continue
			var want := a.target_temp - temp[i]
			if want <= 0.05:
				continue
			var cap := heat_cap(i)
			var e: float = minf(want * cap * 0.5, budget / float(cells.size()) * 2.5)
			if e <= 0:
				continue
			temp[i] += e / maxf(cap, 1.0)
			if e / maxf(cap, 1.0) > 0.3:
				active[i] = true

# ------------------------------------------------------------------ fire
func can_burn(i: int) -> bool:
	return gas[Defs.G_O2][i] >= 0.5

## tg turf/open/hotspot_expose: heat on a tile with fuel (plasma or tritium) and oxygen in
## it starts a hotspot of volume * 25 at that temperature.
func hotspot_expose(c: Vector2i, exposed_temp: float, exposed_volume: float, soh := false) -> void:
	if not _is_sim(c):
		return
	var i := map.idx(c)
	if gas[Defs.G_O2][i] < 0.5:
		return
	var fuel: bool = gas[Defs.G_PLASMA][i] > 0.5 or gas[Defs.G_TRITIUM][i] > 0.5
	if hotspots.has(c):
		var hs: Dictionary = hotspots[c]
		if soh and fuel:
			hs["temp"] = maxf(hs.get("temp", 0.0), exposed_temp)
			hs["vol"] = maxf(hs.get("vol", 0.0), exposed_volume)
		return
	if exposed_temp > FIRE_MIN_TEMP and fuel:
		_new_hotspot(c, exposed_volume * 25.0, exposed_temp, 0.0, null)

## Set something alight on a tile: a lighter, a welder, a burning object (tg: they call
## hotspot_expose(700, 5)). With fuel gas in the air that starts a real fire; our burnable
## objects and spilled fuel keep a fire of their own going for `fuel` seconds.
func ignite(c: Vector2i, cause: Entity = null, fuel := 6.0) -> void:
	if not _is_sim(c):
		return
	var i := map.idx(c)
	if not can_burn(i):
		return
	hotspot_expose(c, 700.0, 5.0)
	if hotspots.has(c):
		hotspots[c]["fuel"] = maxf(hotspots[c]["fuel"], fuel)
		return
	_new_hotspot(c, 5.0 * 25.0, 700.0, fuel, cause)

func _new_hotspot(c: Vector2i, vol: float, t: float, fuel: float, cause: Entity) -> void:
	var i := map.idx(c)
	var flame := AnimatedFlame.new()
	flame.position = Entity.cell_to_pos(c)
	Game.ents_node.add_child(flame)
	hotspots[c] = {"fuel": fuel, "node": flame, "age": 0.0, "vol": vol, "temp": t, "just": true}
	active[i] = true
	Bus.stimulus.emit({"type": "fire", "actor": cause, "cell": c, "loud": 5.0, "illegal": cause != null and cause.has_c(&"mob")})
	if Game.lighting:
		Game.lighting.fire_changed()

func spark(c: Vector2i, chance := 1.0) -> void:
	if not map.inb(c) or Game.rng.randf() > chance:
		return
	var i := map.idx(c)
	if gas[Defs.G_PLASMA][i] > 0.3 and can_burn(i):
		ignite(c, null, 2.0)
		return
	for e in Game.at(c):
		var f = e.c(&"flammable")
		if f and Game.rng.randf() < 0.1:
			f.ignite()
			ignite(c, null, 4.0)
			return

func extinguish(c: Vector2i) -> void:
	if hotspots.has(c):
		_kill_hotspot(c)
	if map.inb(c):
		var i := map.idx(c)
		temp[i] = maxf(Defs.T20C - 10.0, temp[i] * 0.6)
		gas[Defs.G_H2O][i] += 0.3
		active[i] = true
		dirty_visual[i] = true

func _kill_hotspot(c: Vector2i) -> void:
	var hs: Dictionary = hotspots[c]
	if is_instance_valid(hs["node"]):
		hs["node"].queue_free()
	hotspots.erase(c)
	if Game.lighting:
		Game.lighting.fire_changed()

func _fire_tick() -> void:
	if hotspots.is_empty():
		return
	for c in hotspots.keys():
		if not hotspots.has(c):
			continue
		var hs: Dictionary = hotspots[c]
		var i := map.idx(c)
		hs["age"] += TICK
		if hs["just"]:
			hs["just"] = false # tg: a new hotspot waits a cycle
			continue
		if not _is_sim(c) or not can_burn(i):
			_kill_hotspot(c)
			continue
		var gas_fire: bool = (gas[Defs.G_PLASMA][i] >= 0.5 or gas[Defs.G_TRITIUM][i] >= 0.5) and hs["temp"] >= FIRE_MIN_TEMP and hs["vol"] > 1.0
		var bypassing := false
		if gas_fire:
			# tg hotspot/perform_exposure: a small pocket of the tile's air (the hotspot's
			# volume) is heated to the hotspot's temperature and reacts; once the fire fills
			# the tile, the whole tile's air burns at its own temperature
			bypassing = hs["vol"] > Defs.CELL_VOLUME * 0.95
			var results := {}
			if bypassing:
				var mixb := PackedFloat32Array()
				mixb.resize(Defs.GAS_COUNT)
				for g in Defs.GAS_COUNT:
					mixb[g] = gas[g][i]
				var rb := react_mix(mixb, temp[i], c)
				for g in Defs.GAS_COUNT:
					gas[g][i] = maxf(0.0, rb["mix"][g])
				temp[i] = rb["temp"]
				results = rb["results"]
				hs["temp"] = temp[i]
			else:
				var ratio := minf(hs["vol"] / Defs.CELL_VOLUME, 1.0)
				var pocket := PackedFloat32Array()
				pocket.resize(Defs.GAS_COUNT)
				var rest_hc := 0.0
				for g in Defs.GAS_COUNT:
					pocket[g] = gas[g][i] * ratio
					gas[g][i] -= pocket[g]
					rest_hc += gas[g][i] * _sh[g]
				var rp := react_mix(pocket, hs["temp"], Vector2i(-1, -1))
				results = rp["results"]
				hs["temp"] = rp["temp"]
				# tg assume_air: the pocket mixes back into the tile
				var p_hc := _mix_hc(rp["mix"])
				var tot_hc := rest_hc + p_hc
				if tot_hc > MIN_HEAT_CAPACITY:
					temp[i] = (temp[i] * rest_hc + rp["temp"] * p_hc) / tot_hc
				for g in Defs.GAS_COUNT:
					gas[g][i] += rp["mix"][g]
			hs["vol"] = (results.get("plasmafire", 0.0) + results.get("tritfire", 0.0)) * FIRE_GROWTH_RATE
			if hs["vol"] <= 1.0 and hs["fuel"] <= 0.0:
				_kill_hotspot(c)
				continue
			# tg: a tile-filling fire radiates into its neighbours
			if bypassing and temp[i] > FIRE_MIN_TEMP_TO_SPREAD:
				for d in _nbr:
					var nc: Vector2i = c + d
					if not hotspots.has(nc) and _is_sim(nc):
						hotspot_expose(nc, temp[i] * FIRE_SPREAD_RADIOSITY_SCALE, Defs.CELL_VOLUME / 4.0)
		# our burnable objects and spilled fuel (tg's burning objects and fuel pools)
		var energy := 0.0
		for e in Game.at(c):
			var f = e.c(&"flammable")
			if f:
				if f.burning <= 0 and temp[i] > f.ignite_temp:
					f.ignite()
				energy += f.burn_tick(TICK)
		if hs["fuel"] > 0:
			hs["fuel"] -= TICK
			energy += 25000.0
		if energy > 0.0:
			var o2_use := minf(gas[Defs.G_O2][i], energy / 250000.0 + 0.05)
			gas[Defs.G_O2][i] -= o2_use
			gas[Defs.G_CO2][i] += o2_use * 0.7
			gas[Defs.G_SMOKE][i] += 0.35
			add_heat(i, energy)
			hs["temp"] = maxf(hs["temp"], temp[i])
		if not gas_fire and energy <= 0.0:
			_kill_hotspot(c)
			continue
		active[i] = true
		dirty_visual[i] = true
		var t: float = maxf(temp[i], hs["temp"]) if gas_fire else temp[i]
		var flame: AnimatedFlame = hs["node"]
		if is_instance_valid(flame):
			flame.intensity = 0 if t < 600 else (1 if t < 1200 else 2)
		# harm what's here
		for e in Game.at(c).duplicate():
			if e.removed:
				continue
			var h = e.c(&"health")
			if h and not h.dead:
				e.take_damage(clampf((t - 350.0) / 120.0, 1.0, 8.0), "burn", null)
				if Game.rng.randf() < 0.35:
					h.ignite(8.0)
			elif e.has_c(&"machine") and Game.rng.randf() < 0.1:
				e.take_damage(4.0, "burn", null, "fire")
			elif e.has_c(&"light") and e.c(&"light").kind == "fixture" and t > 700 and Game.rng.randf() < 0.1:
				e.c(&"light").break_light()
		if map.cable[i] == 1 and Game.rng.randf() < 0.025:
			map.cable[i] = 2
			Bus.cables_changed.emit()
			Bus.stimulus.emit({"type": "cable_burnt", "cell": c, "loud": 0.0})
		if t > 800.0 and Game.rng.randf() < 0.05:
			# tg window atmos_expose: panes past their heat_resistance (800 K, reinforced 1600 K)
			# take unarmoured burn damage
			for d in _nbr:
				var s := map.structure[map.idx(c + d)]
				if Defs.is_window(s) and t > (1600.0 if s == Defs.S_RWINDOW else 800.0):
					Structures.take_damage(c + d, 25.0, "burn", "", null)
		if hs["age"] > 20.0 and Game.rng.randf() < 0.02:
			Proto.spawn("decal_scorch", c, {"spr": "scorch_%d" % (Game.rng.randi() % 3)})
		# our object fires creep to burnable things next door (tg: fire_act on neighbours)
		if not gas_fire and t > FIRE_MIN_TEMP_TO_SPREAD and Game.rng.randf() < 0.05:
			for d in _nbr:
				var nc2: Vector2i = c + d
				if not hotspots.has(nc2) and _is_sim(nc2):
					for e2 in Game.at(nc2):
						if e2.has_c(&"flammable"):
							ignite(nc2, null, 3.0)
							break
