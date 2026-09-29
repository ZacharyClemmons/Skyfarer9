class_name SkySystem extends Node
## The region's weather and its clock.
##
## Owns four things the whole game reads from:
##   - the day/night cycle, which drives the ambient light, the sky's colour and which
##     creatures are awake;
##   - the aether wind, which pushes airships, staggers people on exposed coasts and
##     drives the cloud parallax;
##   - the weather, which is real: fronts with positions and edges that charge your gear,
##     blind your sounder, lift you out of your band or drop you out of the sky (Weather);
##   - falling: anything that has gone over the side, and its few seconds of grace;
##   - island climate, so a frost isle is genuinely cold to stand on and a cinder isle
##     genuinely cooks you.

## Real seconds in one full day. Twenty minutes is long enough that dusk feels like an
## event and short enough that you see several in a session.
const DAY_LENGTH := 1200.0
const DAWN := 0.22
const NOON := 0.5
const DUSK := 0.78

## Key colours the ambient light ramps through. Deep night in the Cloudsea is never
## pitch black — there is always some glow off the cloud deck below.
const SKY_KEYS := [
	# [time of day, ambient light, sky gradient top, sky gradient bottom]
	[0.00, Color(0.13, 0.16, 0.30), Color(0.05, 0.07, 0.16), Color(0.12, 0.13, 0.26)],
	[0.18, Color(0.24, 0.22, 0.36), Color(0.14, 0.13, 0.28), Color(0.38, 0.26, 0.34)],
	[0.25, Color(0.68, 0.52, 0.48), Color(0.36, 0.38, 0.62), Color(0.92, 0.62, 0.44)],
	[0.34, Color(0.86, 0.82, 0.74), Color(0.36, 0.55, 0.82), Color(0.78, 0.84, 0.92)],
	[0.50, Color(1.00, 0.98, 0.92), Color(0.32, 0.56, 0.88), Color(0.72, 0.86, 0.96)],
	[0.68, Color(0.94, 0.88, 0.78), Color(0.34, 0.54, 0.84), Color(0.84, 0.86, 0.90)],
	[0.76, Color(0.82, 0.58, 0.44), Color(0.30, 0.34, 0.60), Color(0.96, 0.58, 0.36)],
	[0.84, Color(0.38, 0.32, 0.44), Color(0.14, 0.14, 0.32), Color(0.44, 0.26, 0.34)],
	[1.00, Color(0.13, 0.16, 0.30), Color(0.05, 0.07, 0.16), Color(0.12, 0.13, 0.26)],
]

var gen: SkyGen
var map: StationMap
var weather := Weather.new()
## Wildlife is streamed rather than spawned: a region this size carries nine hundred
## creature records and would spend the whole frame budget on animals nobody can see.
var fauna := FaunaStream.new()

# ---- clock
var day_t := 0.34 # start mid-morning
var day_count := 1
var _last_phase := ""

# ---- wind
var wind := Vector2(1.0, 0.2)
var wind_target := Vector2(1.0, 0.2)
var gust := 0.0
var _wind_t := 0.0
var base_wind := 0.4

# ---- falling
var fallers: Array = [] # Entity

# ---- fauna
var night_pending: Array = [] # spawn records held back for dusk
var night_spawned: Array = [] # Entity, cleared at dawn

var _climate_t := 0.0
var _clim_phase := 0
var _ambient_sound := ""

func setup(g: SkyGen) -> void:
	gen = g
	map = g.map
	weather.setup(Game.seed_value, Defs.band_index(g.altitude))
	fauna.setup(g)
	base_wind = 0.35 + 0.12 * Defs.band_index(g.altitude)
	for rec in g.mob_spawns:
		if rec["night"]:
			night_pending.append(rec)
	apply_climate(true)
	_apply_light()

# ------------------------------------------------------------------ clock
func _process(delta: float) -> void:
	if not Game.running or Game.paused:
		return
	var adv := delta * Game.time_scale / DAY_LENGTH
	day_t += adv
	while day_t >= 1.0:
		day_t -= 1.0
		day_count += 1
		Bus.chronicle.emit("Day %d over %s." % [day_count, gen.region_name if gen else "the sky"], 1)
	var t := SPerf.t0()
	_apply_light()
	_wind(delta)
	SPerf.end("sky.light+wind", t)
	t = SPerf.t0()
	weather.process(delta * Game.time_scale)
	SPerf.end("weather", t)
	t = SPerf.t0()
	fauna.process(delta)
	SPerf.end("fauna", t)
	SkyBuffs.tick()
	_fall(delta)
	_climate_t -= delta
	if _climate_t <= 0.0 and _clim_i < 0:
		_climate_t = 8.0
		_clim_i = 0   # begin a pass; islands are done a few per frame, not all in one
		_clim_phase += 1
	if _clim_i >= 0:
		t = SPerf.t0()
		_climate_step()
		SPerf.end("climate", t)
	t = SPerf.t0()
	_sweep(delta)
	SPerf.end("sweep", t)
	_phase_watch()

## 0 = midnight, 0.5 = noon.
func time_of_day() -> float:
	return day_t

func is_night() -> bool:
	return day_t < DAWN or day_t > DUSK + 0.06

func is_day() -> bool:
	return day_t > DAWN + 0.08 and day_t < DUSK

## How high the sun sits, -1 (deep night) to 1 (noon). Drives shadow length in 3D and
## how much the lightmap opens up outdoors.
func sun_elevation() -> float:
	return -cos(day_t * TAU)

func phase_name() -> String:
	if day_t < 0.18: return "night"
	if day_t < 0.30: return "dawn"
	if day_t < 0.44: return "morning"
	if day_t < 0.58: return "noon"
	if day_t < 0.72: return "afternoon"
	if day_t < 0.84: return "dusk"
	return "night"

func clock_string() -> String:
	var mins := int(day_t * 1440.0)
	return "%02d:%02d" % [mins / 60, mins % 60]

func _ramp(idx: int) -> Array:
	var keys := SKY_KEYS
	for k in range(keys.size() - 1):
		var a: Array = keys[k]
		var b: Array = keys[k + 1]
		if day_t >= a[0] and day_t <= b[0]:
			var span: float = maxf(0.0001, b[0] - a[0])
			var f: float = (day_t - a[0]) / span
			return [Color(a[idx]).lerp(Color(b[idx]), f)]
	return [Color(keys[0][idx])]

func ambient_color() -> Color:
	return _ramp(1)[0]

func sky_top() -> Color:
	return _ramp(2)[0]

func sky_bottom() -> Color:
	return _ramp(3)[0]

func _apply_light() -> void:
	if Game.lighting == null:
		return
	var amb := ambient_color()
	# the Deep never sees the sun properly; the Anvil is washed out and glaring
	var b := Defs.band_index(gen.altitude if gen else Defs.ALT_LOW)
	if b == 0:
		amb = amb.darkened(0.45).lerp(Color(0.32, 0.22, 0.20), 0.35)
	elif b >= 3:
		amb = amb.lightened(0.10)
	# the weather sits on top of the time of day: inside a thunderhead it is dusk at noon,
	# and under an aurora everything is faintly green
	if Game.player != null:
		var wt := weather.tint_at(Underdecks.world_cell(Game.player))
		if wt.a > 0.01:
			amb = amb.lerp(Color(wt.r, wt.g, wt.b), wt.a)
	Game.lighting.ambient = amb

func _phase_watch() -> void:
	var ph := phase_name()
	if ph == _last_phase:
		return
	var was := _last_phase
	_last_phase = ph
	if was == "":
		return
	match ph:
		"dawn":
			Game.msg("[color=#e8b87a]The cloud deck below turns gold. Dawn.[/color]", "info")
			fauna.on_night(false)
		"dusk":
			Game.msg("[color=#c87a5a]The light goes long and red. Dusk — something will be moving soon.[/color]", "warn")
			fauna.on_night(true)
		"night":
			if was == "dusk":
				Game.msg("[color=#7a8ad8]Night. The islands are dark shapes now.[/color]", "info")

# ------------------------------------------------------------------ wind
## The aether wind wanders rather than gusting randomly, so a pilot can read it and plan
## a course. Gusts ride on top of the base direction.
func _wind(delta: float) -> void:
	_wind_t -= delta
	if _wind_t <= 0.0:
		_wind_t = randf_range(18.0, 46.0)
		var ang := randf() * TAU
		var mag := base_wind * randf_range(0.6, 1.6)
		wind_target = Vector2(cos(ang), sin(ang)) * mag
	wind = wind.lerp(wind_target, minf(1.0, delta * 0.15))
	gust = maxf(0.0, gust - delta * 0.6)
	if randf() < delta * 0.04:
		gust = randf_range(0.5, 1.8) * base_wind
	# ShipSystem drives the weather layer while the player is aboard a hull, so that haze
	# can stream past the deck at the ship's own speed; it falls back to this otherwise.
	if Game.view and Game.view.snow and (Game.fleet == null or Game.fleet.ship_of(Game.player) == null):
		Game.view.snow.wind = wind_vector() * 40.0
	if Game.view and Game.view.snow and Game.player != null:
		# haze thickens inside a front, so weather is visible from the deck without
		# anybody having to open a panel about it
		var h := weather.haze_at(Underdecks.world_cell(Game.player))
		Game.view.snow.intensity = maxf(Game.view.snow.intensity, 0.09 + h * 0.75)

func wind_vector() -> Vector2:
	return wind * (1.0 + gust)

func wind_strength() -> float:
	return wind_vector().length()

func wind_name() -> String:
	var s := wind_strength()
	if s < 0.25: return "calm"
	if s < 0.6: return "a steady breeze"
	if s < 1.1: return "a stiff wind"
	if s < 1.8: return "a hard blow"
	return "a gale"

## Compass word for the direction the wind is going.
func wind_dir_name() -> String:
	var v := wind_vector()
	if v.length() < 0.05:
		return "nowhere"
	var a := rad_to_deg(v.angle())
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return names[int(round(fposmod(a, 360.0) / 45.0)) % 8]

# ------------------------------------------------------------------ weather queries
## Charge in the air at a cell: a stormdrive drinks it, an aether cell tops up off it,
## and a lance reloads faster in it.
func storm_charge_at(c: Vector2i) -> float:
	return weather.storm_charge(c)

## How thick the aether runs. Fishing, fuel condensers and lift all read this.
func aether_density_at(c: Vector2i) -> float:
	return weather.aether_density(c)

## 0..1 of normal sight. Fog is the only thing that takes it away.
func visibility_at(c: Vector2i) -> float:
	return weather.visibility(c)

## What lift is multiplied by here. Above 1 in a squall, below 1 in a downdraft.
func lift_factor_at(c: Vector2i) -> float:
	return weather.lift_factor(c)

func weather_tint(c: Vector2i) -> Color:
	return weather.tint_at(c)

func weather_haze(c: Vector2i) -> float:
	return weather.haze_at(c)

func weather_text() -> String:
	var c: Vector2i = Underdecks.world_cell(Game.player) if Game.player != null else Vector2i.ZERO
	return weather.text_at(c)

## What the glass says, out to `sight` tiles. A storm oracle passes a much larger number.
func forecast(from: Vector2i, sight := 30.0) -> String:
	return weather.forecast(from, sight)

# ------------------------------------------------------------------ falling
func add_faller(e: Entity) -> void:
	if not e in fallers:
		fallers.append(e)

func remove_faller(e: Entity) -> void:
	fallers.erase(e)

func _fall(delta: float) -> void:
	for e in fallers.duplicate():
		if not is_instance_valid(e) or e.removed:
			fallers.erase(e)
			continue
		var t: float = e.tags.get("fall_t", 0.0) - delta
		e.tags["fall_t"] = t
		# the drop away: shrink, fade and slide down-screen, so you can see them go
		var f: float = clampf(1.0 - t / Falling.FREEFALL, 0.0, 1.0)
		e.scale = Vector2.ONE * (1.0 - f * 0.72)
		e.modulate = Color(1, 1, 1, 1.0 - f * 0.85)
		e.position += Vector2(0, 46.0 * delta) + Vector2(wind_vector() * 6.0 * delta)
		if e == Game.player and Game.view:
			Game.view.shake(1.4)
		# a glider popped open mid-fall saves you, if there is anywhere to land
		if Falling.airborne(e):
			var to := _nearest_ground(e.cell)
			if to.x > -9000:
				Falling.rescue(e, to)
				continue
		if t <= 0.0:
			fallers.erase(e)
			Falling.consume(e)

func _nearest_ground(from: Vector2i) -> Vector2i:
	for r in range(1, 9):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var c: Vector2i = from + Vector2i(x, y)
				if Falling.supported(c) and map.is_passable(c):
					return c
	return Vector2i(-9999, -9999)

## Anything standing over open sky that should not be. This catches the cases no single
## movement hook can: a ship flying out from under a boarding party, a hull tile blown
## away, an island edge mined through.
var _sweep_t := 0.0

func _sweep(delta: float) -> void:
	_sweep_t -= delta
	if _sweep_t > 0.0:
		return
	_sweep_t = 0.5
	for e in Game.all_with(&"mob"):
		if e.holder == null and not e.tags.get("falling", false):
			Falling.check(e)
	for e in Game.all_with(&"item"):
		if e.holder == null and not e.tags.get("falling", false) and not Falling.supported(e.cell):
			Falling.begin(e)

# ------------------------------------------------------------------ island climate
## Islands carry their own weather. This writes the biome's temperature (and any gas it
## leaks) straight into its outdoor tiles; the atmos system leaves outdoor tiles alone,
## so the values stick, and interiors conduct against them properly.
func apply_climate(full: bool) -> void:
	if gen == null or Game.atmos == null:
		return
	_clim_phase += 1
	var sun := sun_elevation()
	for isl in gen.islands:
		_climate_island(isl, full, sun)

var _clim_i := -1
const CLIMATE_ISLANDS_PER_FRAME := 3

## The 8-second climate sweep, sliced: the same cells get the same writes, a few islands
## per frame, so the whole pass no longer lands as one 13 ms hitch.
func _climate_step() -> void:
	if gen == null or Game.atmos == null:
		_clim_i = -1
		return
	var sun := sun_elevation()
	var n := gen.islands.size()
	var stop := mini(n, _clim_i + CLIMATE_ISLANDS_PER_FRAME)
	while _clim_i < stop:
		_climate_island(gen.islands[_clim_i], false, sun)
		_clim_i += 1
	if _clim_i >= n:
		_clim_i = -1

func _climate_island(isl: Dictionary, full: bool, sun: float) -> void:
	var at = Game.atmos
	var b: Dictionary = isl["b"]
	var off := float(b["temp"])
	# day swing: bare rock and sand bake by day and give it all back at night
	var exposure := 1.0 - float(b["density"]) * 0.6
	off += sun * 9.0 * exposure
	var target := Defs.sky_temp(gen.altitude) + off
	var leak: Array = b["gas"]
	var cells: Array = isl["cells"]
	var step := 1 if full else 3
	var start := 0 if full else (_clim_phase % 3)
	for k in range(start, cells.size(), step):
		var c: Vector2i = cells[k]
		var i := map.idx(c)
		# An island's climate is the weather, and weather does not come indoors. A
		# building stamped on the island is still in the island's cell list, so
		# without this a shop on a frost isle froze its own shopkeeper and a shop on
		# a bog isle filled with miasma, which is exactly what was happening.
		if not map.is_outdoor(c):
			continue
		if map.is_solid_turf(c):
			at.temp[i] = target
			continue
		at.temp[i] = lerpf(at.temp[i], target, 1.0 if full else 0.5)
		if not leak.is_empty():
			at.gas[int(leak[0])][i] = float(leak[1])
			at.mark_present(int(leak[0]))

# ------------------------------------------------------------------ night fauna
func _spawn_night() -> void:
	for rec in night_pending:
		var c: Vector2i = rec["cell"]
		if not map.is_passable(c):
			continue
		if Game.player != null and Underdecks.world_cell(Game.player).distance_to(c) < 14:
			continue # dusk should be a warning, not an ambush at the rail
		var e = SkyMobs.spawn(rec["mob"], c)
		if e != null:
			night_spawned.append(e)

func _clear_night() -> void:
	for e in night_spawned:
		if is_instance_valid(e) and not e.removed:
			var h: CHealth = e.c(&"health")
			if h != null and h.dead:
				continue
			# they slip away rather than popping out of existence, if nobody is watching
			if Game.player != null and Game.lighting != null and Game.lighting.player_can_see(e.cell):
				continue
			e.destroy()
	night_spawned.clear()

# ------------------------------------------------------------------ status text
func status_text() -> String:
	var line := "%s, %s  %s from the %s  (day %d)" % [
		clock_string(), phase_name(), wind_name(), _from(wind_dir_name()), day_count]
	var w := weather_text()
	if w != "":
		line += "  —  " + w
	return line

func _from(going: String) -> String:
	const OPP := {"east": "west", "west": "east", "north": "south", "south": "north",
		"south-east": "north-west", "north-west": "south-east",
		"south-west": "north-east", "north-east": "south-west", "nowhere": "nowhere"}
	return OPP.get(going, going)
