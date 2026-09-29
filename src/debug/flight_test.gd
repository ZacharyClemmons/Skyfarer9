class_name FlightTest extends Node
## --flighttest: exercises the actual ship, helm, renderer and terrain queries after
## voyage boot. Controlled steps use a clear sky map so wind and wildlife cannot alter
## the result. FLIGHT FAIL lines produce a nonzero process exit code.

const DT := 1.0 / 120.0
const START := Vector2i(64, 64)
var fails := 0
var checks := 0
var _saved := {}
var _ships: Array[Airship] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_isolate()
	var stock := _make_ship()
	if stock != null:
		_background(stock)
		_lighting(stock)
		_fractional_motion(stock)
		_quarter_seams(stock, "stock odd hull")
		_walking(stock)
		_blocked_turn(stock)
		_boundary_collisions(stock)
		_trim_and_thrust(stock)
		stock.remove()
	var built := _make_ship()
	if built != null:
		# Extend only the port side and the bow: an even bounding box with its centre
		# away from the plan's original centreline catches pivot rounding errors.
		built.set_piece(Vector2i(4, -4), ".")
		built.set_piece(Vector2i(11, 0), ".")
		built.set_piece(Vector2i(11, 1), ".")
		_quarter_seams(built, "asymmetric extended hull")
		built.remove()
	_incremental_lighting()
	_prop_orientation()
	_held_rudder(1.0)
	_held_rudder(-1.0)
	_frame_rate_turning()
	_restore()
	print("FLIGHT DONE: %d checks, %d failed" % [checks, fails])
	get_tree().quit(0 if fails == 0 else 1)

func _isolate() -> void:
	_saved = {"map": Game.map, "fleet": Game.fleet, "sky": Game.sky,
		"atmos": Game.atmos, "lighting": Game.lighting, "view": Game.view,
		"player": Game.player, "cell_index": Game.cell_index}
	Game.running = false
	Game.sky = null
	Game.atmos = null
	Game.lighting = null
	Game.view = null
	Game.player = null
	Game.cell_index = {}
	Game.map = StationMap.new(160, 160)
	Game.map.turf.fill(Defs.T_SKY)
	Game.fleet = ShipSystem.new()
	add_child(Game.fleet)
	Game.fleet.set_process(false)

func _restore() -> void:
	for sh in _ships:
		if sh.present:
			sh.remove()
	for key in _saved:
		Game.set(key, _saved[key])
	Game.running = false

func _make_ship(hull_id := "skiff") -> Airship:
	var sh: Airship = Game.fleet.add_ship(hull_id, START, Defs.DIR_E, "Flight fixture")
	_check("ship fits in clean sky", sh != null)
	if sh == null:
		return null
	_ships.append(sh)
	add_child(sh.renderer)
	sh.renderer.set_process(false)
	_sync(sh)
	return sh

func _sync(sh: Airship) -> void:
	sh.renderer.sync_visuals()

func _background(sh: Airship) -> void:
	var chunks := {}
	var clean_turf := true
	var clean_edges := true
	for c in sh.cells:
		var key := Vector2i(c.x / TerrainChunk.SIZE, c.y / TerrainChunk.SIZE)
		if not chunks.has(key):
			var chunk := TerrainChunk.new()
			chunk.map = Game.map
			chunk.cx = key.x
			chunk.cy = key.y
			chunk._cache_background()
			chunks[key] = chunk
		var chunk: TerrainChunk = chunks[key]
		clean_turf = clean_turf and chunk._terrain_turf(c) == Defs.T_SKY
		clean_edges = clean_edges and not chunk._landish(c) and not chunk._wallish(c)
		clean_edges = clean_edges and chunk._terrain_structure(c) == Defs.S_NONE
	_check("terrain under the drawn ship remains sky", clean_turf)
	_check("hull cannot leave coastline or wall outlines across chunk borders", clean_edges)
	for chunk in chunks.values():
		chunk.free()

func _fractional_motion(sh: Airship) -> void:
	sh.angle = 0.37
	_sync(sh)
	var pivot := sh.visual_pivot()
	var origin := sh.origin
	var before := _visuals(sh)
	var shift := Vector2(0.25, 0.375)
	sh.vel = shift / 0.5
	sh._advance(0.5)
	sh.vel = Vector2.ZERO
	_sync(sh)
	_near_vec("fractional flight moves the hull every frame", sh.renderer.position - pivot, shift * Defs.TILE)
	_check("fractional flight keeps the current stamped cells", sh.origin == origin)
	var carried := true
	for p in sh.parts:
		carried = carried and (p.position - before[p.id]).distance_to(shift * Defs.TILE) < 0.01
	_check("all fittings share the hull's fractional motion", carried)
	var picks := true
	for c in sh.cells:
		var home := Entity.cell_to_pos(c)
		var centre := sh.visual_position(home) - Vector2(0, Defs.TILE * 0.5)
		picks = picks and sh.visual_to_cell(centre) == c
	_check("clicking the rotated visible deck finds its simulation cell", picks)
	pivot = sh.visual_pivot()
	before = _visuals(sh)
	shift = Vector2(1.4, 0.0)
	sh.vel = shift / 0.5
	sh._advance(0.5)
	sh.vel = Vector2.ZERO
	_sync(sh)
	_near_vec("crossing a stamped tile advances the hull exactly once", sh.visual_pivot() - pivot, shift * Defs.TILE)
	carried = true
	for p in sh.parts:
		carried = carried and (p.position - before[p.id]).distance_to(shift * Defs.TILE) < 0.01
	_check("fittings remain smooth when flight crosses a stamped tile", carried)

func _lighting(sh: Airship) -> void:
	var light := LightingSystem.new()
	add_child(light)
	light.set_process(false)
	var sprite := Sprite2D.new()
	add_child(sprite)
	Game.lighting = light
	light.setup(Game.map, sprite)
	light.ambient = Color(0.6, 0.5, 0.4)
	light.visible.fill(1)
	var local := Vector2i(4, 0)
	var c := sh.cell(local.x, local.y)
	# A dark cabin tile should darken its continuously drawn deck, while the sky
	# exposed alongside that deck keeps its original ambient light.
	light.amb[Game.map.idx(c)] = 0.0
	light.compose()
	var pixel := c - light.region_origin
	var background := light.image.get_pixelv(pixel)
	var deck := light._ship_source_image.get_pixelv(pixel)
	_check("a dark stamped cabin cannot leave a dark rectangle in the sky",
		absf(background.r - 0.6) < 0.002 and absf(background.g - 0.5) < 0.002)
	_check("the separate deck lightmap retains the cabin's darkness", deck.r < 0.1 and deck.g < 0.1)
	_check("ship lighting mask includes the source deck tile",
		roundi(light._ship_mask_image.get_pixelv(pixel).r * 255.0) == 1)
	var clear_pixel := Vector2i(2, 2)
	var clear_background := light.image.get_pixelv(clear_pixel)
	var clear_deck := light._ship_source_image.get_pixelv(clear_pixel)
	_check("lighting outside a ship retains its ordinary world map",
		absf(clear_background.r - clear_deck.r) < 0.001 and absf(clear_background.b - clear_deck.b) < 0.001)
	var source_pivot: Vector2 = light._ship_source_pivots[0]
	var source_angle: float = light._ship_source_angles[0]
	sh.angle = wrapf(Airship._angle_of(sh.facing) + PI * 0.25 + 0.01, -PI, PI)
	light._sync_ship_transforms()
	_check("lighting follows the continuously rotated deck before a quarter seam", _mask_follows(light, sh, local))
	var turned := sh._rotate_to((sh.facing + 1) % 4)
	sh.pos += Vector2(0.13, 0.21)
	light._sync_ship_transforms()
	_check("lighting source frame remains fixed through a quarter seam",
		turned and light._ship_source_pivots[0].distance_to(source_pivot) < 0.00001
		and absf(light._ship_source_angles[0] - source_angle) < 0.00001)
	var pivot: Vector4 = light._ship_pivots[0]
	_near_vec("lighting's destination pivot tracks fractional ship movement",
		Vector2(pivot.z, pivot.w), sh.visual_pivot() / Defs.TILE)
	_near_vec("lighting carries the captured source rotation into the new pose",
		light._ship_rotations[0], Vector2(cos(sh.angle - source_angle), sin(sh.angle - source_angle)), 0.00001)
	_check("lighting stays on the same visible deck tile after restamping", _mask_follows(light, sh, local))
	light.full_bright = true
	light.compose()
	c = sh.cell(local.x, local.y)
	pixel = c - light.region_origin
	background = light.image.get_pixelv(pixel)
	deck = light._ship_source_image.get_pixelv(pixel)
	_check("full bright reaches both sky and continuously drawn decks",
		background.r > 0.999 and background.g > 0.999 and deck.r > 0.999 and deck.b > 0.999)
	Game.lighting = null
	light.queue_free()
	sprite.queue_free()

func _mask_follows(light: LightingSystem, sh: Airship, local: Vector2i) -> bool:
	var c := sh.cell(local.x, local.y)
	var world := (sh.visual_position(Entity.cell_to_pos(c)) - Vector2(0, Defs.TILE * 0.5)) / Defs.TILE
	var pivots: Vector4 = light._ship_pivots[0]
	var rotation: Vector2 = light._ship_rotations[0]
	var relative := world - Vector2(pivots.z, pivots.w)
	var source := Vector2(pivots.x, pivots.y) + Vector2(
		rotation.x * relative.x + rotation.y * relative.y,
		-rotation.y * relative.x + rotation.x * relative.y)
	var pixel := Vector2i(floori(source.x), floori(source.y)) - light.region_origin
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= LightingSystem.REGION_W or pixel.y >= LightingSystem.REGION_H:
		return false
	return roundi(light._ship_mask_image.get_pixelv(pixel).r * 255.0) == 1

func _incremental_lighting() -> void:
	var sh := _make_ship("cutter")
	if sh == null:
		return
	# Fit real glass into a cabin bulkhead so window spill, occlusion and both
	# stamped cabin footprints participate in the incremental exposure update.
	var window := Vector2i(5, -1)
	sh.set_piece(window, "W")
	_check("incremental lighting fixture has an actual cabin window",
		Defs.is_window(Game.map.structure[Game.map.idx(sh.cell(window.x, window.y))]))
	var light := LightingSystem.new()
	add_child(light)
	light.set_process(false)
	var sprite := Sprite2D.new()
	add_child(sprite)
	Game.lighting = light
	light.setup(Game.map, sprite)
	var step := Vector2i(1, 0)
	var moved := sh._restamp(sh.origin + step, sh.facing)
	sh.pos += Vector2(step)
	_check("windowed cabin can move for incremental lighting test", moved)
	_ambient_matches(light, "windowed cabin translation")
	var turned := sh._rotate_to((sh.facing + 1) % 4)
	_check("windowed cabin can turn for incremental lighting test", turned)
	_ambient_matches(light, "windowed cabin quarter turn")
	var blocker := Entity.new()
	add_child(blocker)
	blocker.place(sh.cell(6, -1))
	Game.register(blocker)
	blocker.add(CBlocker.new().setup({"dense": false, "air": false, "opaque": true}))
	_ambient_matches(light, "adding an opaque blocker beside a window")
	blocker.place(sh.cell(6, 0))
	_ambient_matches(light, "moving an opaque blocker past a window")
	blocker.destroy()
	_ambient_matches(light, "removing a window's opaque blocker")
	Game.lighting = null
	light.queue_free()
	sprite.queue_free()
	sh.remove()

func _ambient_matches(light: LightingSystem, label: String) -> void:
	_check("%s requests a local lighting refresh" % label, light._amb_dirty and not light._amb_full_dirty)
	if light._amb_dirty:
		light._refresh_ambient()
	var incremental := light.amb.duplicate()
	light.rebuild_ambient()
	var error := 0.0
	for i in incremental.size():
		error = maxf(error, absf(incremental[i] - light.amb[i]))
	_check("%s: incremental exposure matches a full rebuild (error %.7f)" % [label, error], error < 0.000001)

func _quarter_seams(sh: Airship, label: String) -> void:
	var local_cells := _local_cells(sh)
	var intact := true
	var continuous := true
	var centred := true
	var counts := true
	var dense := _dense_count()
	for k in 8:
		# Keep the visible angle fixed while its simulation changes quarter. Every
		# fitting must remain on the very same visible plank through that seam.
		sh.angle = wrapf(Airship._angle_of(sh.facing) + PI * 0.25 + 0.01, -PI, PI)
		_sync(sh)
		var before := _visuals(sh)
		var pivot := sh.visual_pivot()
		var next := (sh.facing + 1) % 4
		var turned := sh._rotate_to(next)
		intact = intact and turned
		_sync(sh)
		centred = centred and sh.visual_pivot().distance_to(pivot) < 0.01
		for p in sh.parts:
			intact = intact and is_instance_valid(p) and not p.removed
			intact = intact and sh.local_of(p.cell) == local_cells[p.id]
			intact = intact and p.cell in sh.cells and Game.at(p.cell).has(p)
			continuous = continuous and p.position.distance_to(before[p.id]) < 0.01
		counts = counts and _dense_count() == dense
	_check("%s: repeated quarter turns preserve the visual pivot" % label, centred)
	_check("%s: fittings stay in their original local cells" % label, intact)
	_check("%s: fittings have no visible jump at quarter seams" % label, continuous)
	_check("%s: turns preserve blocker counts" % label, counts)

func _walking(sh: Airship) -> void:
	var from_local := Vector2i(4, -1)
	var to_local := Vector2i(5, -1)
	var e := Entity.new()
	e.display_name = "Walking fixture"
	add_child(e)
	e.place(sh.cell(from_local.x, from_local.y))
	Game.register(e)
	var mob: CMob = e.add(CMob.new())
	mob._begin_move(sh.cell(to_local.x, to_local.y), false)
	mob.process(mob.move_dur * 0.5)
	sh.angle = wrapf(Airship._angle_of(sh.facing) + 0.4, -PI, PI)
	_sync(sh)
	var progress := mob.move_t
	var expected := sh.visual_position(mob.from_pos.lerp(mob.to_pos, progress))
	_near_vec("a walking passenger stays halfway between visible deck cells", e.position, expected)
	var before := e.position
	for k in 4:
		_sync(sh)
	_near_vec("renderer refreshes cannot restart or finish a passenger's step", e.position, before)
	_near("renderer preserves walk progress", mob.move_t, progress)
	var pivot := sh.visual_pivot()
	var turned := sh._rotate_to((sh.facing + 1) % 4)
	_sync(sh)
	_check("ship can turn with a passenger halfway through a step", turned and mob.moving)
	_near_vec("a turn preserves the halfway passenger's visible position", e.position, before)
	_near_vec("a passenger does not move the ship's pivot during a turn", sh.visual_pivot(), pivot)
	_near_vec("walk start rotates into the new simulation frame", mob.from_pos,
		Entity.cell_to_pos(sh.cell(from_local.x, from_local.y)))
	_near_vec("walk end rotates into the new simulation frame", mob.to_pos,
		Entity.cell_to_pos(sh.cell(to_local.x, to_local.y)))
	_near("restamping preserves walk progress", mob.move_t, progress)
	# Carry the same ongoing step one tile forward too; rendering must never leak
	# its rotated coordinates into the simulation endpoints.
	var old_from := mob.from_pos
	var old_to := mob.to_pos
	var step := Vector2i(1, 0)
	var moved := sh._restamp(sh.origin + step, sh.facing)
	sh.pos += Vector2(step)
	_sync(sh)
	_check("ship translation carries the ongoing walk", moved and mob.moving)
	_near_vec("translation carries the walk start exactly once", mob.from_pos - old_from, Vector2(step) * Defs.TILE)
	_near_vec("translation carries the walk end exactly once", mob.to_pos - old_to, Vector2(step) * Defs.TILE)
	mob.process(mob.move_dur)
	_sync(sh)
	_check("passenger finishes the carried step on deck", not mob.moving and sh.is_aboard(e))
	_near_vec("finished passenger rests on the correct visible tile", e.position,
		sh.visual_position(Entity.cell_to_pos(e.cell)))
	e.destroy()

func _blocked_turn(sh: Airship) -> void:
	var next := (sh.facing + 1) % 4
	var new_pos := sh.pos + sh.pivot_offset(sh.facing) - sh.pivot_offset(next)
	var new_origin := Vector2i(floori(new_pos.x), floori(new_pos.y))
	var obstacle := Vector2i(-1, -1)
	for local in sh.cells_map:
		var rotated := Vector2(local).rotated(Airship._angle_of(next))
		var c := new_origin + Vector2i(roundi(rotated.x), roundi(rotated.y))
		if c not in sh.cells:
			obstacle = c
			break
	_check("blocked-turn fixture has a newly swept tile", obstacle.x >= 0)
	if obstacle.x < 0:
		return
	Game.map.turf[Game.map.idx(obstacle)] = Defs.T_ROCK
	var furniture := Proto.spawn("table", obstacle)
	var before := _local_cells(sh)
	var pivot := sh.visual_pivot()
	var origin := sh.origin
	var facing := sh.facing
	var dense := _dense_count()
	var moved := sh._rotate_to(next)
	_sync(sh)
	_check("rotation refuses solid terrain in its new footprint", not moved)
	_check("blocked rotation leaves ship cells and facing intact", sh.origin == origin and sh.facing == facing)
	_near_vec("blocked rotation cannot change the visual pivot", sh.visual_pivot(), pivot)
	var intact := sh.parts.size() == before.size()
	for p in sh.parts:
		intact = intact and not p.removed and sh.local_of(p.cell) == before[p.id]
	_check("blocked rotation keeps all fittings aboard", intact)
	_check("blocked rotation cannot delete scenery or tunnel into terrain",
		not furniture.removed and Game.map.get_turf(obstacle) == Defs.T_ROCK and obstacle not in sh.cells)
	_check("blocked rotation leaves blocker counts intact", _dense_count() == dense)
	furniture.destroy()
	Game.map.turf[Game.map.idx(obstacle)] = Defs.T_SKY

func _held_rudder(direction: float) -> void:
	var sh := _make_ship()
	if sh == null:
		return
	var helm: CHelm = sh.helm.c(&"helm")
	for b in sh.boilers:
		var boiler: CBoiler = b.c(&"boiler")
		boiler.lit = true
		boiler.pressure = 62.0
	sh.throttle = 0.3
	var total := 0.0
	var forward := true
	var bounded := true
	var pivot := sh.visual_pivot()
	for k in 12000:
		helm.steer(direction)
		var previous := sh.angle
		sh._turn(DT)
		var turned := wrapf(sh.angle - previous, -PI, PI)
		total += turned * direction
		forward = forward and turned * direction >= -0.00001
		bounded = bounded and absf(turned) <= 1.9 * DT + 0.001
	_check("held %s rudder completes several full rotations" % _side(direction), total > TAU * 2.0)
	_check("held %s rudder never reverses across the angle wrap" % _side(direction), forward)
	_check("held %s rudder turns smoothly each frame" % _side(direction), bounded)
	_near_vec("repeated held turns do not move the hull's pivot", sh.visual_pivot(), pivot)
	var speed := absf(sh.angular_velocity)
	helm.steer(0.0)
	var previous := sh.angle
	sh._turn(DT)
	_check("releasing %s rudder keeps the turn continuous" % _side(direction),
		absf(sh.angular_velocity) > 0.0 and absf(sh.angular_velocity) <= speed + 0.00001)
	forward = wrapf(sh.angle - previous, -PI, PI) * direction >= -0.00001
	for k in 1200:
		helm.steer(0.0)
		previous = sh.angle
		sh._turn(DT)
		forward = forward and wrapf(sh.angle - previous, -PI, PI) * direction >= -0.00001
		if k == 11:
			_check("released %s rudder smoothly slows within a tenth of a second" % _side(direction),
				absf(sh.angular_velocity) > 0.0 and absf(sh.angular_velocity) < speed)
	_check("released %s rudder settles without reversing" % _side(direction), forward and absf(sh.angular_velocity) < 0.002)
	sh.remove()

func _boundary_collisions(sh: Airship) -> void:
	for d: Vector2i in Defs.DIRS4:
		var obstacle := Vector2i(-1, -1)
		for c: Vector2i in sh.cells:
			if c + d not in sh.cells:
				obstacle = c + d
				break
		if obstacle.x < 0:
			_check("collision fixture has an exposed hull edge", false)
			continue
		Game.map.turf[Game.map.idx(obstacle)] = Defs.T_ROCK
		sh.pos = Vector2(sh.origin) + Vector2(0.5, 0.5)
		if d.x != 0:
			sh.pos.x = sh.origin.x + (0.999 if d.x > 0 else 0.001)
		else:
			sh.pos.y = sh.origin.y + (0.999 if d.y > 0 else 0.001)
		var tangent := Vector2(-d.y, d.x)
		sh.vel = Vector2(d) * 0.2 + tangent * 0.1
		_sync(sh)
		var before := sh.visual_pivot()
		var origin := sh.origin
		var fittings := _visuals(sh)
		sh._advance(0.01)
		_sync(sh)
		var small := sh.visual_pivot().distance_to(before) < 0.1
		for p in sh.parts:
			small = small and p.position.distance_to(fittings[p.id]) < 0.1
		var side := Vessel.vec_dir(d)
		_check("a gentle %s collision stops without a visible snap" % side, small)
		_check("a %s collision stops at the boundary without tunnelling" % side,
			sh.origin == origin and absf(sh.vel.dot(Vector2(d))) < 0.00001
			and Game.map.get_turf(obstacle) == Defs.T_ROCK and obstacle not in sh.cells)
		_near("a %s collision preserves velocity along the coast" % side, sh.vel.dot(tangent), 0.1)
		Game.map.turf[Game.map.idx(obstacle)] = Defs.T_SKY
	sh.vel = Vector2.ZERO

func _trim_and_thrust(sh: Airship) -> void:
	sh.ballast = 0.0
	sh._mass_cache = 0.0
	var dry := sh.mass()
	var cached_at := sh._mass_t
	sh.ballast = 0.5
	_near("ballast responds immediately while dry hull mass is cached", sh.mass(), dry * 0.8, 0.0001)
	sh.ballast = -0.5
	_near("heavier trim responds in the same simulation frame", sh.mass(), dry * 1.2, 0.0001)
	_check("trim changes retain the existing dry hull cache", sh._mass_t == cached_at and sh._mass_cache == dry)
	sh.ballast = 0.0
	for b in sh.boilers:
		var boiler: CBoiler = b.c(&"boiler")
		boiler.lit = true
		boiler.pressure = 62.0
	for b in sh.bunkers:
		var bunker: CFuelBunker = b.c(&"fuelbunker")
		bunker.amount = bunker.capacity
	sh.throttle = 1.0
	for t in sh.thrusters:
		var thruster: CThruster = t.c(&"thruster")
		thruster.heat = 0.0
		thruster.process(CThruster.SPOOL_UP + 0.1)
	var full := sh.thrust()
	_check("fuelled engines reach full thrust", full > 0.0)
	sh.throttle = 0.5
	for t in sh.thrusters:
		t.c(&"thruster").process(CThruster.SPOOL_UP + 0.1)
	_near("half throttle produces half thrust after engines spool down", sh.thrust(), full * 0.5, 0.0001)
	sh.throttle = 0.0

func _frame_rate_turning() -> void:
	var angles: Array[float] = []
	var rates: Array[float] = []
	for fps in [30, 60, 120]:
		var sh := _make_ship()
		if sh == null:
			return
		var helm: CHelm = sh.helm.c(&"helm")
		sh.throttle = 0.3
		for k in fps * 5:
			helm.steer(1.0)
			sh._turn(1.0 / fps)
		angles.append(sh.angle)
		rates.append(sh.angular_velocity)
		sh.remove()
	_near("five seconds of turning agrees at 30 and 120 frames per second",
		wrapf(angles[0] - angles[2], -PI, PI), 0.0, 0.002)
	_near("five seconds of turning agrees at 60 and 120 frames per second",
		wrapf(angles[1] - angles[2], -PI, PI), 0.0, 0.002)
	_near("final turning speed agrees at 30 and 120 frames per second", rates[0], rates[2])
	_near("final turning speed agrees at 60 and 120 frames per second", rates[1], rates[2])

func _prop_orientation() -> void:
	var sh := _make_ship()
	if sh == null:
		return
	sh.set_piece(Vector2i(4, -1), "t")
	sh.set_piece(Vector2i(6, -1), "k")
	sh.set_piece(Vector2i(7, -1), "+")
	sh.set_piece(Vector2i(6, 1), "p")
	sh.set_piece(Vector2i(7, 1), "g")
	var directional := {"ship_thruster": "thruster_w", "ship_propeller": "propeller_e", "gun_mount": "gun_e"}
	var originals := {}
	for p in sh.parts:
		if not directional.has(p.proto) and p.proto != "chair":
			originals[p.id] = p.spr_name
	_check("prop orientation fixture includes furniture, consoles, containers and machinery", originals.size() >= 9)
	for facing in [Defs.DIR_E, Defs.DIR_S, Defs.DIR_W, Defs.DIR_N]:
		if sh.facing != facing:
			_check("prop fixture turns to the next cardinal heading", sh._rotate_to(facing))
		for offset in [0.0, 0.4]:
			sh.angle = wrapf(Airship._angle_of(facing) + offset, -PI, PI)
			_sync(sh)
			var upright := true
			var artwork := true
			var placed := true
			var flat := true
			for p in sh.parts:
				var rotates: bool = directional.has(p.proto)
				var local := sh.local_of(p.cell)
				var feet := Vector2(0, Defs.TILE * 0.5)
				var centre := sh.visual_pivot() + ((Vector2(local) - sh.local_pivot()) * Defs.TILE).rotated(sh.angle)
				var expected := centre + feet
				placed = placed and p.position.distance_to(expected) < 0.01
				if rotates:
					flat = flat and absf(p.rotation) < 0.00001
					var direction := Vessel.vec_dir(-sh._fwd() if p.proto == "ship_thruster" else sh._fwd())
					var prefix: String = {"ship_thruster": "thruster_", "ship_propeller": "propeller_", "gun_mount": "gun_"}[p.proto]
					flat = flat and p.spr_name == prefix + direction
				else:
					upright = upright and absf(p.rotation) < 0.00001
					if p.spr != null:
						upright = upright and absf(p.spr.global_rotation) < 0.00001
					if p.glow_spr != null:
						upright = upright and absf(p.glow_spr.global_rotation) < 0.00001
					if p.proto == "chair":
						artwork = artwork and p.spr_name == "chair_shuttle_" + Vessel.vec_dir(sh._fwd())
					else:
						artwork = artwork and p.spr_name == originals[p.id]
			var pose := "%s %s" % [Vessel.vec_dir(sh._fwd()), "cardinal" if offset == 0.0 else "mid-turn"]
			_check("%s: furniture and machinery artwork remains upright" % pose, upright)
			_check("%s: props retain original art and chairs use directional variants" % pose, artwork)
			_check("%s: every prop rests at its transformed deck position" % pose, placed)
			_check("%s: thrusters, propellers and guns use upright native directional art" % pose, flat)
	_quarter_seams(sh, "upright-prop fixture")
	sh.remove()

func _side(direction: float) -> String:
	return "starboard" if direction > 0.0 else "port"

func _visuals(sh: Airship) -> Dictionary:
	var out := {}
	for p in sh.parts:
		out[p.id] = p.position
	return out

func _local_cells(sh: Airship) -> Dictionary:
	var out := {}
	for p in sh.parts:
		out[p.id] = sh.local_of(p.cell)
	return out

func _dense_count() -> int:
	var total := 0
	for n in Game.map.dense_count:
		total += n
	return total

func _near_vec(what: String, got: Vector2, expected: Vector2, tolerance := 0.01) -> void:
	_check("%s (error %.5f px)" % [what, got.distance_to(expected)], got.distance_to(expected) <= tolerance)

func _near(what: String, got: float, expected: float, tolerance := 0.00001) -> void:
	_check(what, absf(got - expected) <= tolerance)

func _check(what: String, ok: bool) -> void:
	checks += 1
	print("FLIGHT %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1
