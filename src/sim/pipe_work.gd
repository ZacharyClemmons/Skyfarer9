class_name PipeWork extends RefCounted
## Laying and removing pipes by hand, after tg's /obj/machinery/atmospherics wrench_act and
## /obj/item/pipe (smart pipes). Pipes are exposed only where the floor tile is pried up.
##
## Unfastening: 2 seconds with a wrench (instant if the pipe is empty). If the pipe is more
## than 2 atmospheres over the room, you're warned by a gush of air, and when it comes free
## you're thrown pressure/250 tiles. The removed segment's share of the gas escapes into
## the room and you get the fitting back.
##
## Fastening: put a fitting on plating and wrench it. It joins every neighbouring pipe on its
## layer (tg smart pipe), so runs are laid outward one tile at a time from existing pipe.

const LAYER_NAMES := ["supply", "scrubber", "hot loop", "cold loop"]
const SEGMENT_VOLUME := 70.0 # litres per pipe tile, matches PipeSystem.rebuild

## The pipe layer drawn nearest the click: supply/hot sit 3 px up-left of the tile centre,
## scrub/cold 3 px down-right (see tools/artgen/objects.py pipe()).
static func layer_at(cell: Vector2i, wpos) -> int:
	var map := Game.map
	var best := -1
	var best_d := 1e9
	for l in StationMap.PIPE_LAYER_COUNT:
		var m := map.pipe_mask(l, cell)
		if m == 0 or not _free_segment(l, cell):
			continue
		var d := 0.0
		if wpos is Vector2:
			var off := -3.0 if l in [StationMap.PL_SUPPLY, StationMap.PL_HOT] else 3.0
			var centre := Vector2(cell) * 32.0 + Vector2(16.0 + off, 16.0 + off)
			var local: Vector2 = wpos - centre
			# distance to the nearest arm of the pipe (it runs through the centre)
			d = local.length()
			for k in 4:
				if m & (1 << k):
					var dir := Vector2(Defs.DIRS4[k])
					var along := clampf(local.dot(dir), 0.0, 16.0)
					d = minf(d, (local - dir * along).length())
		if d < best_d:
			best_d = d
			best = l
	return best

## A plain pipe tile on this layer, nothing built into it.
static func _free_segment(layer: int, cell: Vector2i) -> bool:
	var i := Game.map.idx(cell)
	if Game.pipes and Game.pipes.inline[layer].has(i):
		return false
	for v in Game.at_with(cell, &"vent"):
		if v.c(&"vent").layer == layer:
			return false
	return true

## tg wrench_act on a pipe. Returns true if there was a pipe to work on.
static func try_unwrench(user: Entity, item: Entity, cell: Vector2i) -> bool:
	var map := Game.map
	if map.has_floor_tile(cell) or map.is_solid_turf(cell):
		return false
	var layer := layer_at(cell, Interact.click_pos)
	if layer < 0:
		for l in StationMap.PIPE_LAYER_COUNT:
			if map.pipe_mask(l, cell) != 0:
				Game.tell(user, "Something is built into that pipe. Deal with it first.", "warn")
				return true
		return false
	var net = Game.pipes.net_at(layer, cell) if Game.pipes else null
	var inside: float = net.pressure() if net else 0.0
	var delta: float = inside - (Game.atmos.pressure_at(cell) if Game.atmos else 0.0)
	var empty: bool = net == null or net.total_moles() < 0.01
	var nm: String = "%s pipe" % LAYER_NAMES[layer]
	if not empty:
		Game.tell(user, "You begin to unfasten the %s..." % nm)
	var unsafe := delta > 2.0 * Defs.ONE_ATMOSPHERE
	if unsafe:
		Game.tell(user, "As you begin unwrenching the %s a gush of air blows in your face... maybe you should reconsider?" % nm, "bad")
	Sfx.play("ratchet", cell, 0.6)
	var dur: float = 0.0 if empty else 2.0 * item.c(&"item").tool_speed
	DoAfter.start(user, null, dur, func(ok):
		if not ok or map.pipe_mask(layer, cell) == 0 or map.has_floor_tile(cell):
			return
		_remove(layer, cell)
		Sfx.play("ratchet", cell, 0.8)
		Game.visible_message(cell, "%s unfastens the %s." % [user.display_name, nm])
		Bus.stimulus.emit({"type": "deconstruct", "actor": user, "cell": cell, "loud": 2.0, "illegal": not user.c(&"inv").has_access("atmos")})
		if unsafe:
			pressure_throw(user, cell, delta)
	)
	return true

static func _remove(layer: int, cell: Vector2i) -> void:
	var map := Game.map
	var pipes = Game.pipes
	if pipes and pipes.dirty:
		pipes.rebuild()
	var net = pipes.net_at(layer, cell) if pipes else null
	# the segment's share of the pipeline's gas escapes into the room
	if net and net.volume > 0.0 and Game.atmos and not map.is_outdoor(cell):
		var out: PackedFloat32Array = net.take_fraction(SEGMENT_VOLUME / net.volume)
		var i := map.idx(cell)
		for g in Defs.GAS_COUNT:
			if out[g] > 0.0:
				Game.atmos.add_gas(i, g, out[g], net.temp)
		Game.atmos.wake(cell)
	var m := map.pipe_mask(layer, cell)
	for k in 4:
		if m & (1 << k):
			var n: Vector2i = cell + Defs.DIRS4[k]
			map.set_pipe_mask(layer, n, map.pipe_mask(layer, n) & ~(1 << ((k + 2) % 4)))
			Bus.tile_changed.emit(n)
	map.set_pipe_mask(layer, cell, 0)
	map.repair_pipe(layer, cell)
	Proto.spawn("pipe_fitting", cell, {"comps": {"pipefitting": {"layer": layer}}})
	Bus.pipes_changed.emit()
	Bus.tile_changed.emit(cell)

## tg unsafe_pressure_release: the pipe throws you away from it.
static func pressure_throw(user: Entity, from: Vector2i, pressure: float) -> void:
	var map := Game.map
	var d := user.cell - from
	var dir := Vector2i(signi(d.x), signi(d.y))
	if dir == Vector2i.ZERO:
		dir = Defs.DIRS4[Game.rng.randi() % 4]
	var dist := clampi(int(pressure / 250.0), 1, 10)
	Game.visible_message(user.cell, "[b]%s is sent flying by pressure![/b]" % user.display_name, "bad")
	var to := user.cell
	var slammed := false
	for k in dist:
		var n := to + dir
		if map.blocks_move_static(n) or Game.at(n).any(func(x): return x != user and x.has_c(&"blocker") and x.c(&"blocker").dense):
			slammed = true
			break
		to = n
	if to != user.cell:
		Interact.glide(user, to, 0.06 * user.cell.distance_to(to))
	var h: CHealth = user.c(&"health")
	if h:
		if slammed:
			h.hurt_zone("chest", 8.0, "brute", null)
			Sfx.play("punch", to, 0.8)
		h.knockdown(2.0 if slammed else 1.0)

## tg pipe item wrench_act: fasten a fitting where it lies.
static func install(user: Entity, fitting: Entity) -> void:
	var map := Game.map
	var cell := fitting.cell
	var pf: CPipeFitting = fitting.c(&"pipefitting")
	var layer := pf.layer
	if fitting.holder != null:
		Game.tell(user, "Put the pipe down where you want it first.", "warn")
		return
	if map.has_floor_tile(cell):
		Game.tell(user, "You need to pry up the floor tile first.", "warn")
		return
	if map.is_solid_turf(cell) or map.is_outdoor(cell):
		Game.tell(user, "You can't fasten a pipe there.", "warn")
		return
	if map.pipe_mask(layer, cell) != 0:
		Game.tell(user, "There is already a %s pipe here." % LAYER_NAMES[layer], "warn")
		return
	var links := []
	for k in 4:
		var n: Vector2i = cell + Defs.DIRS4[k]
		if map.inb(n) and map.pipe_mask(layer, n) != 0 and not Game.pipes.inline[layer].has(map.idx(n)):
			links.append(n)
	if links.is_empty():
		Game.tell(user, "There's no %s pipe next to it to connect to." % LAYER_NAMES[layer], "warn")
		return
	for n in links:
		map.connect_pipe(layer, cell, n)
		Bus.tile_changed.emit(n)
	Sfx.play("ratchet", cell, 0.8)
	Game.visible_message(cell, "%s fastens the %s pipe." % [user.display_name, LAYER_NAMES[layer]])
	fitting.destroy()
	Bus.pipes_changed.emit()
	Bus.tile_changed.emit(cell)
	Skills.add_xp(user, "engineering", 3.0)
