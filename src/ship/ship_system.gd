class_name ShipSystem extends Node
## The fleet: every airship in the region, ticked once a frame.
##
## Applies orders before the visual transforms, manages camera lead and handles transit
## between altitude bands.

var ships: Array = [] # Airship
## World cell -> ship id for queries against the simulation footprint.
var ship_tiles := {}

func rebuild_tile_index() -> void:
	ship_tiles.clear()
	_claimed.clear()
	for s in ships:
		if not s.present:
			continue
		for c in s.cells + s.lower_cells:
			ship_tiles[c] = s.id
		_claimed[s.id] = s.cells + s.lower_cells

## ship id -> the cells that ship last wrote into `ship_tiles`.
var _claimed := {}

## One hull moved: drop only its old tiles and write its new ones, instead of rebuilding
## the index for every ship in the sky on every step any of them takes.
func claim_tiles(s: Airship) -> void:
	var old: Array = _claimed.get(s.id, [])
	for c in old:
		if ship_tiles.get(c, -1) == s.id:
			ship_tiles.erase(c)
	for c in s.cells + s.lower_cells:
		ship_tiles[c] = s.id
	_claimed[s.id] = s.cells + s.lower_cells

func tile_is_hull(c: Vector2i) -> bool:
	return ship_tiles.has(c)
## Whoever the player flies. Giving them a new one (bought, or drawn and launched) is a
## moment, so assignment plays the arrival: she drops into her berth, dust and steam
## roll off her, the camera comes round to look, and her name hangs in the sky.
var player_ship: Airship = null:
	set(v):
		var fresh := v != null and v != player_ship and v.present and Game.player != null
		player_ship = v
		if v != null and v.present and Game.player != null:
			Underdecks.ensure(v)
		if fresh:
			announce_arrival(v)
## ship id -> ShipAI. Only ships somebody else is flying have one; the player's does not,
## which is the only difference between their hull and yours.
var captains := {}
var traffic := SkyTraffic.new()
var _next_id := 1
var _pending_transit: Dictionary = {} # Airship -> bool (true: downward)
var _transit_t := 0.0
var transit_hook: Callable = Callable() # set by the boot sequence

func _init() -> void:
	process_priority = -10

# ------------------------------------------------------------------ fleet
func add_ship(hull_id: String, where: Vector2i, dir := Defs.DIR_E, nm := "") -> Airship:
	var sh := Airship.new().setup(hull_id, nm)
	sh.id = _next_id
	_next_id += 1
	if not sh.stamp(where, dir):
		return null
	sh.altitude = Game.sky.gen.altitude if Game.sky != null and Game.sky.gen != null else Defs.ALT_LOW
	ships.append(sh)
	var r := ShipRenderer.new()
	r.setup(sh)
	sh.renderer = r
	if Game.view != null:
		Game.view.add_child(r)
	rebuild_tile_index()
	return sh

func get_ship(id: int) -> Airship:
	for s in ships:
		if s.id == id:
			return s
	return null

# ------------------------------------------------------------------ captains
func register_ai(sh: Airship, ai: ShipAI) -> void:
	captains[sh.id] = ai

func unregister_ai(sh: Airship) -> void:
	if sh != null:
		captains.erase(sh.id)

func ai_of(sh: Airship) -> ShipAI:
	if sh == null:
		return null
	return captains.get(sh.id)

## Every hull flying under somebody else's orders, for the nav table and the chart.
func other_ships() -> Array:
	var out := []
	for s in ships:
		if s.present and s != player_ship and captains.has(s.id):
			out.append(s)
	return out

## The ship a given entity is standing on, if any.
func ship_of(e: Entity) -> Airship:
	if e == null or e.removed:
		return null
	for s in ships:
		if s.is_aboard(e):
			return s
	return null

func ship_at(c: Vector2i) -> Airship:
	var sid: int = ship_tiles.get(c, -1)
	if sid < 0:
		return null
	var s := get_ship(sid)
	return s if s != null and s.present else null

func cell_at_visual(world_position: Vector2) -> Vector2i:
	for sh in ships:
		if not sh.present:
			continue
		var c: Vector2i = sh.visual_to_cell(world_position)
		if sh.cells_map.has(sh.local_of(c)):
			return c
	return Vector2i(floori(world_position.x / Defs.TILE), floori(world_position.y / Defs.TILE))

# ------------------------------------------------------------------ tick
func _process(delta: float) -> void:
	if not Game.running or Game.paused:
		return
	var d: float = minf(delta * Game.time_scale, 0.1) # never let a hitch teleport a ship
	var t_all := SPerf.t0()
	var pcell := Underdecks.world_cell(Game.player) if Game.player != null and is_instance_valid(Game.player) else Vector2i(-99999, -99999)
	var t := SPerf.t0()
	_tick_parts(d)
	SPerf.end("parts", t)
	_hazard_t += d
	if _hazard_t >= ShipHazards.TICK:
		var hs := ship_of(Game.player) if Game.player != null and is_instance_valid(Game.player) else null
		if hs == null:
			hs = player_ship
		ShipHazards.tick(hs, _hazard_t)
		_hazard_t = 0.0
	t = SPerf.t0()
	traffic.process(delta)
	SPerf.end("traffic", t)
	for s in ships.duplicate():
		if not s.present:
			ships.erase(s)
			captains.erase(s.id)
			continue
		var cap: ShipAI = captains.get(s.id)
		if cap != null:
			t = SPerf.t0()
			cap.process(d)
			SPerf.end("ai", t)
		t = SPerf.t0()
		var fly_dt := d
		if far_from_player(s, pcell):
			# nobody can see or touch a hull this far off: same flight model, ticked in
			# 0.1 s steps instead of every frame
			var acc: float = float(_far_acc.get(s.id, 0.0)) + d
			if acc < FAR_STEP:
				_far_acc[s.id] = acc
				fly_dt = 0.0
			else:
				_far_acc[s.id] = 0.0
				fly_dt = acc
		if fly_dt > 0.0:
			s.fly(fly_dt)
		SPerf.end("fly", t)
	t = SPerf.t0()
	_camera(delta)
	_transit(delta)
	SPerf.end("cam", t)
	SPerf.end("FLEET", t_all)

const FAR_TILES := 110.0
const FAR_STEP := 0.1
var _far_acc := {}
var _hazard_t := 0.0

func far_from_player(s: Airship, pcell: Vector2i) -> bool:
	if s == player_ship or pcell.x < -90000:
		return false
	return Vector2(s.origin - pcell).length_squared() > FAR_TILES * FAR_TILES

## Ship machinery runs off the frame rather than a subsystem tick, because there are only
## ever a handful of each and they all want smooth, continuous behaviour.
func _tick_parts(d: float) -> void:
	for comp_key in [&"boiler", &"liftcell", &"thruster"]:
		for ent in Game.all_with(comp_key):
			var c = ent.c(comp_key)
			if c != null and c.has_method("process"):
				c.process(d)
	for ent in Game.all_with(&"helm"):
		var hc: CHelm = ent.c(&"helm")
		if hc != null:
			hc.process(d)

# ------------------------------------------------------------------ camera
## What speed feels like from the deck.
##
## The hull is steady on screen by design, so without this you are moving fast and nothing
## tells you. The air does: haze streams past you at your own speed and in your own
## direction, and the camera leans a little into the run so the bow has more sky in front
## of it than behind.
var _lead := Vector2.ZERO
var _focus_ship: Airship = null
var _focus_age := 0.0
const FOCUS_LEN := 4.2

## The moment a ship becomes yours. Safe to call for any present hull.
func announce_arrival(sh: Airship, headline := "LAUNCHED") -> void:
	if sh == null or not sh.present:
		return
	sh.begin_arrival()
	_focus_ship = sh
	_focus_age = 0.0
	Game.msg("[i]The last line is cast off and %s takes the air.[/i]" % sh.ship_name, "info")
	Sfx.play_ui("ui_launch", 0.9)
	var tip := "Walk to the boiler and light her." if sh.steam_up() == false else ""
	preload("res://src/ui/ship_banner.gd").show_for(sh, headline, tip)

func _motion_feel(delta: float) -> void:
	var sh := ship_of(Game.player)
	if Game.view == null:
		return
	var want_lead := Vector2.ZERO
	# after a launch the camera comes round to look at her, then hands back
	if _focus_ship != null and is_instance_valid(Game.player):
		_focus_age += delta
		if not _focus_ship.present or _focus_age > FOCUS_LEN:
			_focus_ship = null
		else:
			var env := smoothstep(0.0, 0.6, _focus_age) * (1.0 - smoothstep(FOCUS_LEN - 1.4, FOCUS_LEN, _focus_age))
			var off: Vector2 = _focus_ship.visual_pivot() - Game.player.position
			want_lead += off.limit_length(240.0) * env * 0.85
	if sh != null and sh.present:
		var v := sh.vel
		if Game.view.snow != null:
			# particles stream past the deck: opposite the way she is going, faster the
			# faster she goes, plus whatever the wind is doing on its own
			var wind := Vector2.ZERO
			if Game.sky != null:
				wind = Game.sky.wind_vector() * 40.0
			Game.view.snow.wind = wind - v * 46.0
			Game.view.snow.intensity = clampf(0.09 + v.length() * 0.10, 0.09, 0.42)
		want_lead = v.limit_length(4.0) * 13.0
	elif Game.view.snow != null and Game.sky != null:
		Game.view.snow.wind = Game.sky.wind_vector() * 40.0
		Game.view.snow.intensity = 0.09
	_lead = _lead.lerp(want_lead, 1.0 - exp(-delta * 2.2))
	Game.view.motion_lead = _lead

## Godot's own camera smoothing lags behind a correction that has to land on the exact
## frame it is issued, so it is turned off while the player is riding a hull and restored
## when they step off.
var _smoothing_off := false

func _tune_smoothing() -> void:
	if Game.view == null:
		return
	var aboard := ship_of(Game.player) != null
	if aboard == _smoothing_off:
		return
	_smoothing_off = aboard
	Game.view.camera.position_smoothing_enabled = not aboard

## The first-person tile renderer compensates its yaw when its simulation quarter changes.
## Overhead visuals use the continuous hull transform directly.
const TURN_EASE := 0.62
var turn_roll := 0.0

func restamping_any() -> bool:
	for s in ships:
		if s.restamping:
			return true
	return false

## Called the moment a hull comes about. `step` is +1 to starboard, -1 to port.
func on_turned(sh: Airship, step: int) -> void:
	if ship_of(Game.player) != sh:
		return
	turn_roll = -step * PI * 0.5
	var vm = Game.view.get_parent().get_node_or_null("ViewMode") if Game.view != null else null
	if vm != null and vm.view3d != null:
		vm.view3d.carry_turn(step)

func _camera(delta: float) -> void:
	_tune_smoothing()
	_motion_feel(delta)
	if absf(turn_roll) > 0.0005:
		turn_roll = move_toward(turn_roll, 0.0, delta * (PI * 0.5) / TURN_EASE)
	else:
		turn_roll = 0.0
	if Game.view != null:
		Game.view.camera.rotation = 0.0

# ------------------------------------------------------------------ transit between bands
## A ship that climbs or sinks past the edge of its band leaves the region. The boot
## sequence installs `transit_hook` to actually rebuild the world; without one we just
## hold the ship at the boundary and tell the pilot why.
func request_transit(sh: Airship, downward: bool) -> void:
	if _pending_transit.has(sh):
		return
	_pending_transit[sh] = downward
	_transit_t = 4.0
	if sh == player_ship or ship_of(Game.player) == sh:
		var to: String = Defs.ALT_NAMES[clampi(Defs.band_index(Game.sky.gen.altitude) + (-1 if downward else 1), 0, 4)]
		Game.msg("[b][color=#9ad8ff]%s is %s out of this sky. %s ahead.[/color][/b]" % [
			sh.ship_name, "sinking" if downward else "climbing", to.capitalize()], "info")
		Game.msg("[i]Level off within a few seconds to stay, or hold your trim to cross over.[/i]", "info")

func _transit(delta: float) -> void:
	if _pending_transit.is_empty():
		return
	_transit_t -= delta
	# levelling off cancels the crossing
	for sh in _pending_transit.keys():
		if not is_instance_valid(sh) or not sh.present:
			_pending_transit.erase(sh)
			continue
		var b: float = sh.buoyancy()
		if absf(b - 1.0) < 0.03:
			_pending_transit.erase(sh)
			if ship_of(Game.player) == sh:
				Game.msg("You level off. The horizon settles.", "info")
	if _transit_t > 0.0 or _pending_transit.is_empty():
		return
	for sh in _pending_transit.keys():
		var down: bool = _pending_transit[sh]
		if transit_hook.is_valid():
			transit_hook.call(sh, down)
		else:
			Game.msg("[i]%s holds at the edge of the band.[/i]" % sh.ship_name, "info")
	_pending_transit.clear()

# ------------------------------------------------------------------ mooring
## Is this ship close enough to an island for the crew to step across? Returns the pair of
## cells (ship side, land side) that form the gangway, or an empty array.
func gangway(sh: Airship) -> Array:
	for c in sh.deck_cells:
		for d in Defs.DIRS4:
			var land: Vector2i = c + d
			if sh.present and land in sh.cells:
				continue
			if Falling.supported(land) and Game.map.is_passable(land):
				return [c, land]
	return []

func moored(sh: Airship) -> bool:
	return sh.speed() < 0.2 and not gangway(sh).is_empty()

func status_text() -> String:
	if ships.is_empty():
		return "no ships in this sky"
	var out := [traffic.status_text()]
	for s in ships:
		var cap: ShipAI = captains.get(s.id)
		out.append(cap.status_text() if cap != null else s.status_text())
	return "\n".join(out)
