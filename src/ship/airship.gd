class_name Airship extends RefCounted
## One airship.
##
## A ship is real tiles on the region map, not a sprite: its hull, decks, windows, doors
## and machines are stamped into StationMap, so atmospherics, power, pipes, lighting,
## pathfinding and every interaction in the game work aboard it without knowing it is a
## vehicle. Flying is done by restamping — the ship lifts its own terrain off the map,
## puts back whatever was underneath, and lays itself down one tile over.
##
## Simulation moves in whole tiles; ShipRenderer carries the hull and everything aboard
## through the continuous position and angle between stamps.
##
## Flight model, in the order the numbers matter:
##   lift      aetherite cells hold the ship up. Lift under mass and you sink.
##   thrust    thrusters burn fuel for forward force. They also dump hot exhaust into
##             whatever tile they sit in, which is a real problem if you box one in.
##   sail      masts convert the aether wind into force, free but only where it blows.
##   rudder    sets the heading; coming about takes time and bleeds speed.
##   drag      quadratic, so every hull has a natural top speed.

const TILE_STEP_LIMIT := 3 # tiles a ship may cross in one physics step, to stop tunnelling
## An empty hull with every cell full floats at this fraction of its own weight. Cells are
## rated against the hull they are fitted to rather than being a fixed size, so a barque's
## bladders are simply bigger than a skiff's — and a hull the player has built themselves
## balances on its own without anyone tuning a table.
const DESIGN_LIFT := 1.34
const THRUST_PER_ENGINE := 46.0
const SAIL_AREA_PER_MAST := 12.0
## Quadratic drag: every hull finds its own cruise. Retuned when the region went from
## 240 tiles across to 512 — a sky you cross in a minute and a half is a corridor, and a
## sky you cannot cross at all is a wall. A stock skiff now makes about 2.7 tiles a
## second, which puts the far rim twenty minutes out and the next island over about one.
const DRAG := 0.022
## Air resistance that bites at any speed, not just at the top end. Without it a hull
## coasts for a minute after you close the throttle, which feels like ice rather than air.
const DRAG_LINEAR := 0.075
## Radians per second at rest. A ship is slow to come about and slower the faster she is
## going, which is what makes a chase a matter of planning rather than reflexes.
const TURN_RATE := 0.85
const TURN_ACCEL := 1.4 # radians/s²: the rudder takes up and releases smoothly
const TURN_DRAG := 0.3
const CRASH_SPEED := 1.2 # below this, bumping something is a nudge rather than a wreck

var id := 0
var ship_name := "Unnamed"
var hull_id := "skiff"
var hull: Dictionary = {}
var plan: Array = []   # the book plan she was launched from (kept for reference)
var keel := 0
## The live layout: Vector2i(u, v) -> plan character. This, not `plan`, is what the ship
## actually is. Building onto her adds entries; they then move, seal, weigh and fly like
## anything she was launched with.
var cells_map := {}
## What is actually bolted into each hole: Vector2i(u, v) -> ShipParts module id. The
## glyph in `cells_map` says an engine goes here; this says which engine. Splitting the
## two is what makes refitting a ship a real activity rather than a redraw.
var fittings := {}
var derelict := false

## Where the ship is. `pos` is the world-tile position of the plan's local origin (u=0,
## v=keel_row) in floats; `origin` is floor(pos), where it is stamped.
var pos := Vector2.ZERO
var origin := Vector2i.ZERO
## The bow's true direction, in radians, measured the way the screen is: 0 is east, and
## it increases clockwise (because +y is down). This is continuous — she sweeps through
## every angle between two headings rather than flipping between four of them.
var angle := 0.0
## Where the rudder is asking her to go. The gap between this and `angle` is what the
## rudder is working against.
var wanted_angle := 0.0
## The nearest quarter, which is the orientation her tiles are stamped at. Simulation —
## walking, atmospherics, collision — uses this; the hull you see uses `angle`.
var facing := 0
var heading := 0 # kept in step with `wanted_angle`, for the compass and old call sites
var turning := 0.0 # seconds left in the current turn
var angular_velocity := 0.0
var rudder_input := 0.0 # held steering, -1 port .. +1 starboard

var vel := Vector2.ZERO
var altitude := Defs.ALT_LOW
var ballast := 0.0 # -1 heavy .. +1 light, set at the trim wheel
var throttle := 0.0 # 0..1 set at the helm
var sails_set := 0.0 # 0..1

var present := false
var cells: Array = [] # every world cell the ship occupies
var deck_cells: Array = [] # walkable, open to the sky
var lower_cells: Array = [] # the instanced, physically separate deck below
var lower_stair := Vector2i(-1, -1)
var upper_stair_local := Vector2i(-9999, -9999)
var lower_parts: Array = []
var hatch_shut := false # the companionway hatch: shut, it seals the galley from the deck
var bilge := 0.0 # 0..1 how much water is standing on the lower deck
var seam := 0.0 # 0..1 how badly her seams weep; a crash or a flogging in a gale opens them
var lower_plan := {} # local hull cell -> lower floor or wall glyph
var lower_entry_local := Vector2i(-9999, -9999)
var inside_cells: Array = [] # walkable, sealed
var parts: Array = [] # Entity: everything the ship brought with it
var areas := {} # area id -> Area
var deck_area: Area = null
var inner_area: Area = null

var helm: Entity = null
var thrusters: Array = []
var lift_cells: Array = []
var masts: Array = []
var boilers: Array = []
var bunkers: Array = [] # fuel
var guns: Array = []
var screws: Array = []
var utilities: Array = [] # anything with a quirk worth asking about

var _footprint := [] # [{cell, turf, variant, structure, area}] what was under us
var _mass_cache := 0.0
var _mass_t := 0.0
## Aggregated module stats, rebuilt whenever the fit-out changes rather than every frame.
var _stats := {}
var _stats_dirty := true
var _breaches := 0
var _crash_t := 0.0
var _log: Array = []
var renderer: Node2D = null

## Pixels added on top of her true position when she is drawn: the bob, the sway, the drop
## of an arrival. Purely visual; nothing in the simulation reads it.
var fx_offset := Vector2.ZERO

# ------------------------------------------------------------------ construction
func setup(hid: String, nm := "") -> Airship:
	hull_id = hid
	hull = ShipPlan.get_hull(hid)
	plan = hull["plan"]
	keel = int(hull["keel"])
	derelict = bool(hull.get("derelict", false))
	angle = _angle_of(facing)
	wanted_angle = angle
	cells_map = ShipPlan.to_cells(plan, keel)
	fittings = default_fittings(cells_map, int(hull.get("grade", 1)))
	# a hull may carry a named fit-out in the book: a launch's winch, a frigate's long nines
	for key in hull.get("fit", {}):
		fittings[key] = hull["fit"][key]
	_stats_dirty = true
	_bounds_ok = false
	_sealed_ok = false
	ship_name = nm if nm != "" else hull["name"]
	heading = facing
	return self

## Local (u, v) to a world cell, for the ship's current facing.
##   facing E: +u is +x, +v is +y
##   facing S: +u is +y, +v is -x
##   facing W: +u is -x, +v is -y
##   facing N: +u is -y, +v is +x
func cell(u: int, v: int) -> Vector2i:
	return origin + _fwd() * u + _stbd() * v

func _fwd() -> Vector2i:
	match facing:
		Defs.DIR_E: return Vector2i(1, 0)
		Defs.DIR_S: return Vector2i(0, 1)
		Defs.DIR_W: return Vector2i(-1, 0)
		_: return Vector2i(0, -1)

func _stbd() -> Vector2i:
	var f := _fwd()
	return Vector2i(-f.y, f.x)

## Shape-derived data (bounds, sealed set, mass of the plan) only changes when the layout
## does, and every layout edit goes through mark_dirty(). Cached, because these were being
## recomputed by a walk over every cell several times a frame per ship.
var _bounds_c := Rect2i()
var _bounds_ok := false
var _sealed_c := {}
var _sealed_ok := false
var _cell_ver := -1          # cells_map.hash-free change stamp: size at cache time

func shape_bounds() -> Rect2i:
	if not _bounds_ok or _cell_ver != cells_map.size():
		_bounds_c = ShipPlan.bounds(cells_map)
		_bounds_ok = true
		_cell_ver = cells_map.size()
	return _bounds_c

func sealed_cells() -> Dictionary:
	if not _sealed_ok or _cell_ver != cells_map.size():
		_sealed_c = ShipPlan.sealed_of(cells_map)
		_sealed_ok = true
		_bounds_ok = false
		shape_bounds()
	return _sealed_c

func bow() -> Vector2i:
	return cell(shape_bounds().end.x - 1, 0)

func stern() -> Vector2i:
	return cell(shape_bounds().position.x, 0)

func center() -> Vector2i:
	var b := shape_bounds()
	return cell(b.position.x + b.size.x / 2, 0)

# ------------------------------------------------------------------ modules
## Fill every hole in a layout with the cheapest thing that fits it. This is what a hull
## out of the book is delivered with, and what a plan drawn in the yard falls back to.
static func default_fittings(cm: Dictionary, grade := 1) -> Dictionary:
	var out := {}
	for key in cm:
		var id := ShipParts.default_for(String(cm[key]), grade)
		if id != "":
			out[key] = id
	return out

## The module in a hole, falling back to the glyph's stock fitting so an old save or a
## hand-edited plan still flies.
func module_at(local: Vector2i) -> String:
	if fittings.has(local):
		return String(fittings[local])
	return ShipParts.default_for(String(cells_map.get(local, "")), int(hull.get("grade", 1)))

## Swap one module for another, in place. The hole does not change, so nothing has to be
## rebuilt except the one fitting standing in it.
func set_module(local: Vector2i, mod_id: String) -> bool:
	if not cells_map.has(local):
		return false
	if mod_id != "" and not ShipParts.fits_glyph(mod_id, String(cells_map[local])):
		return false
	if mod_id == "":
		fittings.erase(local)
	else:
		fittings[local] = mod_id
	var world := cell(local.x, local.y)
	for pt in parts.duplicate():
		if is_instance_valid(pt) and not pt.removed and pt.cell == world:
			_forget_part(pt)
			pt.destroy()
	_fit_missing()
	mark_dirty()
	return true

## Swap several modules at once: one sweep over the fittings and one refit, instead of a
## full pass per module (a ring-scaled crew re-fit twenty holes at spawn, ~15 ms).
func set_modules(changes: Array) -> int:
	var at_cells := {}
	for pair in changes:
		var local: Vector2i = pair[0]
		var mod_id := String(pair[1])
		if not cells_map.has(local):
			continue
		if mod_id != "" and not ShipParts.fits_glyph(mod_id, String(cells_map[local])):
			continue
		if mod_id == "":
			fittings.erase(local)
		else:
			fittings[local] = mod_id
		at_cells[cell(local.x, local.y)] = true
	if at_cells.is_empty():
		return 0
	for pt in parts.duplicate():
		if is_instance_valid(pt) and not pt.removed and at_cells.has(pt.cell):
			_forget_part(pt)
			pt.destroy()
	_fit_missing()
	mark_dirty()
	return at_cells.size()

## The module in every hole, stock fittings included: what diagnose() and the refit
## quote (CShipyard.refit_quote) should be given as "what she is now".
func effective_fittings() -> Dictionary:
	var out := {}
	for key in cells_map:
		var id := module_at(key)
		if id != "":
			out[key] = id
	return out

## Every module aboard, as [local, id] pairs.
func module_list() -> Array:
	var out := []
	for key in cells_map:
		var id := module_at(key)
		if id != "":
			out.append([key, id])
	return out

func mark_dirty() -> void:
	_bounds_ok = false
	_sealed_ok = false
	_stats_dirty = true
	_mass_cache = 0.0
	_mass_t = 0.0

## Everything the fit-out adds up to, in one pass. Multipliers combine multiplicatively
## per module, so two efficient engines are genuinely better than one and the numbers
## never go negative on you.
func stats() -> Dictionary:
	if not _stats_dirty and not _stats.is_empty():
		return _stats
	_stats_dirty = false
	var st := {"thrust": 0.0, "sail": 0.0, "turn": 0.0, "power": 0.0, "steam": 0.0,
		"fuel_cap": 0.0, "cargo": 0.0, "armor": 0.0, "crew": 0.0, "sight": 0.0,
		"drag_mul": 1.0, "fuel_mul": 1.0, "heat_mul": 1.0, "lift_units": 0.0,
		"quirks": {}, "guns": [], "mass": 0.0}
	for pair in module_list():
		var id: String = pair[1]
		var m: Dictionary = ShipParts.get_mod(id)
		if m.is_empty():
			continue
		for k in ["thrust", "sail", "turn", "power", "steam", "fuel_cap", "cargo", "armor", "crew", "sight"]:
			st[k] += float(m.get(k, 0.0))
		st["lift_units"] += float(m.get("lift", 0.0))
		st["mass"] += float(m.get("mass", 0.0))
		for k in ["drag_mul", "fuel_mul", "heat_mul"]:
			if m.has(k):
				st[k] *= float(m[k])
		var q := String(m.get("quirk", ""))
		if q != "":
			st["quirks"][q] = int(st["quirks"].get(q, 0)) + 1
		if m.has("gun_damage"):
			st["guns"].append(id)
	_stats = st
	return st

func has_quirk(q: String) -> bool:
	return stats()["quirks"].has(q)

## Is there a live bus? A lance, a sounder and a gyro all want volts, and a ship whose
## dynamo is cold is a ship with half its fittings asleep.
## A dynamo needs a lit boiler behind it, and an aetheric tap needs neither. That is the
## whole test, and it is the reason "light the boiler first" is the sequence the game
## teaches on the first screen.
func has_power() -> bool:
	var dynamo := false
	for p in parts:
		if not is_instance_valid(p) or p.removed or not p.has_c(&"powergen"):
			continue
		if ShipParts.stat(String(p.tags.get("mod", "")), "steam", 0.0) >= 0.0:
			return true  # an aetheric tap draws off the ambient field and asks for nothing
		dynamo = true
	return dynamo and steam_up()

func quirk_count(q: String) -> int:
	return int(stats()["quirks"].get(q, 0))

## Skill of whoever has the wheel. An empty helm flies like a novice has it.
func pilot() -> Entity:
	if helm == null or not is_instance_valid(helm) or helm.removed:
		return null
	var hc: CHelm = helm.c(&"helm")
	return hc.pilot if hc != null else null

func pilot_skill(skill: String) -> float:
	var p := pilot()
	return Skills.frac(p, skill) if p != null else 0.0

# ------------------------------------------------------------------ stamping
## Lay the ship onto the map at `where` (world cell of local origin) facing `dir`.
func stamp(where: Vector2i, dir := Defs.DIR_E) -> bool:
	if present:
		return false
	origin = where
	pos = Vector2(where)
	facing = dir
	heading = dir
	angle = _angle_of(dir)
	wanted_angle = angle
	# a hull may only be laid down over open sky; anything else would pave over the world
	if not derelict and not _fits(where, dir):
		return false
	var map := Game.map
	deck_area = map.new_area("%s — deck" % ship_name, "civilian")
	deck_area.outdoor = true
	deck_area.room_kind = "ship_deck"
	inner_area = map.new_area("%s — below" % ship_name, "civilian")
	inner_area.room_kind = "ship"
	# a ship runs off its own dynamo, not any station grid
	inner_area.power_equip = true
	inner_area.power_light = true
	inner_area.power_environ = true
	areas = {deck_area.id: deck_area, inner_area.id: inner_area}
	var t_st := SPerf.t0()
	_lay_terrain(true, true)
	SPerf.end("stamp.lay", t_st)
	t_st = SPerf.t0()
	_fit_out()
	SPerf.end("stamp.fitout", t_st)
	present = true
	Bus.lights_dirty.emit()
	return true

## Write the plan's turfs, structures and areas, remembering what we covered up.
func _lay_terrain(save_footprint: bool, fill_air := false) -> void:
	var map := Game.map
	cells.clear()
	deck_cells.clear()
	inside_cells.clear()
	deck_area.cells.clear()
	inner_area.cells.clear()
	if save_footprint:
		_footprint.clear()
	var touched := []
	var t := SPerf.t0()
	var sealed_map := sealed_cells()
	SPerf.end("lay.sealed", t)
	for key in cells_map:
		var u: int = key.x
		var v: int = key.y
		var ch: String = cells_map[key]
		var c := cell(u, v)
		if not map.inb(c):
			continue
		var i := map.idx(c)
		if save_footprint:
			_footprint.append({"cell": c, "turf": map.turf[i], "variant": map.variant[i],
				"structure": map.structure[i], "area": map.area[i]})
		_clear_cell(c, ShipPlan.is_dense(ch))
		var sealed: bool = sealed_map.has(Vector2i(u, v))
		var a: Area = inner_area if sealed else deck_area
		if ShipPlan.is_wall(ch):
			map.turf[i] = Defs.T_KEEL if ch == "K" else Defs.T_HULLWOOD
			map.structure[i] = Defs.S_NONE
			a = deck_area
		elif ShipPlan.is_window(ch):
			map.turf[i] = Defs.T_DECK
			map.structure[i] = Defs.S_RWINDOW if ch == "w" else Defs.S_WINDOW
			map.struct_hp[i] = Defs.STRUCTS[map.structure[i]]["hp"]
			a = inner_area
		elif ch == "I":
			map.turf[i] = Defs.T_BULKHEAD
			map.structure[i] = Defs.S_NONE
			a = inner_area
		elif ch == ",":
			map.turf[i] = Defs.T_DECK_OPEN
			map.structure[i] = Defs.S_NONE
		elif sealed:
			map.turf[i] = Defs.T_DECK
			map.structure[i] = Defs.S_NONE
		else:
			map.turf[i] = Defs.T_DECK_OPEN
			map.structure[i] = Defs.S_NONE
		map.turf_hp[i] = float(Defs.TURFS[map.turf[i]].get("hp", 100))
		map.variant[i] = absi(hash(Vector2i(u, v))) % 4
		map.area[i] = a.id
		a.cells.append(c)
		cells.append(c)
		if not map.is_solid_turf(c):
			if sealed or ShipPlan.is_window(ch):
				inside_cells.append(c)
			else:
				deck_cells.append(c)
		touched.append(c)
	SPerf.end("lay.loop", t)
	t = SPerf.t0()
	deck_area.center = deck_cells[deck_cells.size() / 2] if not deck_cells.is_empty() else origin
	inner_area.center = inside_cells[inside_cells.size() / 2] if not inside_cells.is_empty() else deck_area.center
	_retile(touched)
	SPerf.end("lay.retile", t)
	t = SPerf.t0()
	if Game.fleet != null:
		Game.fleet.claim_tiles(self)
	SPerf.end("lay.index", t)
	# Fresh air only when the hull is first laid (or re-drawn in the yard). A hull that is
	# merely sliding or swinging carries the air it already has (see _restamp_inner), so a
	# breach, a fire or a cooked engine room stays what it is from one tile to the next.
	if fill_air and save_footprint and not derelict:
		_fill_air()

## The air in every sealed cell, keyed by local coordinate, so it can be set down again
## wherever the hull lands. LINDA keeps running on the real tiles the whole time; this only
## stops a slide or a turn from silently swapping the cabin's air for the sky's.
func _air_snapshot() -> Dictionary:
	var out := {}
	var at = Game.atmos
	if at == null or derelict:
		return out
	for c in inside_cells:
		if not Game.map.inb(c) or Game.map.blocks_air(c):
			continue
		var i := Game.map.idx(c)
		var rec := PackedFloat32Array()
		rec.resize(Defs.GAS_COUNT + 1)
		for g in Defs.GAS_COUNT:
			rec[g] = at.gas[g][i]
		rec[Defs.GAS_COUNT] = at.temp[i]
		out[local_of(c)] = rec
	return out

func _air_restore(snap: Dictionary) -> void:
	var at = Game.atmos
	if at == null or snap.is_empty():
		return
	for c in inside_cells:
		if not Game.map.inb(c) or Game.map.blocks_air(c):
			continue
		var rec = snap.get(local_of(c))
		if rec == null:
			continue
		var i := Game.map.idx(c)
		for g in Defs.GAS_COUNT:
			at.gas[g][i] = rec[g]
		at.temp[i] = rec[Defs.GAS_COUNT]
		at.wake(c)

## Sealed spaces start with good air at a comfortable temperature.
func _fill_air() -> void:
	var at = Game.atmos
	if at == null:
		return
	for c in inside_cells:
		var i := Game.map.idx(c)
		if Game.map.blocks_air(c):
			continue
		for g in Defs.GAS_COUNT:
			at.gas[g][i] = 0.0
		at.gas[Defs.G_O2][i] = Defs.MOLES_CELLSTANDARD * 0.21
		at.gas[Defs.G_N2][i] = Defs.MOLES_CELLSTANDARD * 0.79
		at.temp[i] = Defs.T20C
		at.wake(c)

## Make room. Loose things and people standing where solid hull is about to appear get
## shoved inboard rather than deleted; island scenery is simply shouldered aside.
func _clear_cell(c: Vector2i, solid: bool) -> void:
	for ent in Game.at(c).duplicate():
		if ent in parts or _carry_ids.has(ent.get_instance_id()):
			continue
		if ent.has_c(&"mob") or ent.has_c(&"item"):
			if solid:
				var to := _open_cell()
				if to.x > -9000:
					ent.place(to)
		elif ent.has_c(&"blocker") or ent.has_c(&"furniture") or ent.has_c(&"decal"):
			if solid:
				ent.destroy()

func _open_cell() -> Vector2i:
	for c in deck_cells:
		if Game.map.is_passable(c):
			return c
	for c in inside_cells:
		if Game.map.is_passable(c):
			return c
	return Vector2i(-9999, -9999)

## Push the changed tiles through the systems that care, without spamming the event bus
## once per tile (a moving sloop rewrites ~150 tiles a step).
func _retile(touched: Array) -> void:
	if _rt_defer:
		_rt_acc.append_array(touched)
		return
	_retile_now(touched)

var _rt_defer := false
var _rt_acc: Array = []

## One int per cell describing what the map holds there for the hull's purposes.
func _sig(c: Vector2i) -> int:
	var m := Game.map
	var i := m.idx(c)
	return int(m.turf[i]) | (int(m.structure[i]) << 8) | (int(m.variant[i]) << 16) | (int(m.area[i]) << 20)

## Restamp sends only the tiles that actually differ to the systems downstream. A hull
## that slides one tile leaves ~90% of its cells holding exactly what they held, and
## waking atmos, the chunk renderer and the ambient-light pass for those was most of
## the cost of flying.
func _flush_retile(pre: Dictionary) -> void:
	_rt_defer = false
	var out := []
	var seen := {}
	for c in _rt_acc:
		if seen.has(c):
			continue
		seen[c] = true
		if pre.has(c) and Game.map.inb(c) and _sig(c) == pre[c]:
			continue
		out.append(c)
	_rt_acc = []
	if not out.is_empty():
		_retile_now(out)

func _retile_now(touched: Array) -> void:
	# The drawn hull lives in the ship's own frame, so sliding or swinging it does not
	# change a single tile of the picture; only a real edit (relay, breach) needs a redraw.
	if is_instance_valid(renderer) and not restamping:
		renderer.queue_redraw()
	if Game.atmos != null and Game.atmos.map != null:
		for c in touched:
			Game.atmos.retile(c)
	if Game.view:
		Game.view.mark_cells_dirty(touched)
	if Game.lighting:
		Game.lighting.mark_ambient_dirty(touched)

# ------------------------------------------------------------------ fitting out
func _fit_out() -> void:
	thrusters.clear()
	lift_cells.clear()
	masts.clear()
	boilers.clear()
	bunkers.clear()
	guns.clear()
	screws.clear()
	utilities.clear()
	helm = null
	for key in cells_map:
		var c := cell(key.x, key.y)
		if not Game.map.inb(c):
			continue
		var e := _fit(cells_map[key], c, key)
		if e != null:
			parts.append(e)
			e.tags["ship"] = id
	for p in parts:
		if p.has_c(&"light") and Game.lighting != null and Game.lighting.map != null:
			Game.lighting.register(p.c(&"light"))

## Which object a utility module actually puts on the deck. A utility mounting is one
## hole that takes any of these, which is why a small hull can be a salvage boat on
## Monday and a still on Tuesday without being redrawn.
const UTIL_PROTO := {
	"util_winch": "cargo_winch", "util_bench": "workbench", "util_still": "ship_still",
	"util_forge": "deck_forge", "util_galley": "galley_stove", "util_medbay": "med_bed",
	"util_hold": "crate", "util_scrubber": "air_scrubber", "util_bunk": "bunk",
	"util_lantern": "deck_lantern", "util_beacon": "aether_beacon",
}

## Spawn the fitting that belongs in one hole, configured from its module. `local` is the
## hole's key, so the specific module can be looked up; passing Vector2i.MAX means "work
## it out from the glyph", which is what a wreck's loot caches want.
func _fit(ch: String, c: Vector2i, local := Vector2i(99999, 99999)) -> Entity:
	var facing_name := Vessel.vec_dir(_fwd())
	var aft_name := Vessel.vec_dir(-_fwd())
	var mod_id := ""
	if local.x < 99999:
		mod_id = module_at(local)
	var mod: Dictionary = ShipParts.get_mod(mod_id)
	var nice: String = String(mod.get("name", ""))
	match ch:
		"+": return Proto.spawn("ship_door", c, {"name": "%s hatch" % ship_name})
		"A": return Proto.spawn("ship_airlock", c, {"name": "%s hull hatch" % ship_name})
		"h":
			helm = Proto.spawn("ship_helm", c, {"name": "%s's wheel" % ship_name})
			helm.c(&"helm").ship_id = id
			return helm
		"n": return Proto.spawn("ship_nav", c)
		"r": return Proto.spawn("ship_rudder", c)
		"E":
			var t := Proto.spawn("ship_thruster", c, {"spr": "thruster_" + aft_name})
			var tc: CThruster = t.c(&"thruster")
			tc.ship_id = id
			tc.mod = mod_id
			if nice != "":
				t.display_name = nice
				t.desc = String(mod.get("desc", t.desc))
			thrusters.append(t)
			return t
		"L":
			var l := Proto.spawn("lift_cell", c)
			var lc: CLiftCell = l.c(&"liftcell")
			lc.ship_id = id
			lc.mod = mod_id
			if nice != "":
				l.display_name = nice
				l.desc = String(mod.get("desc", l.desc))
			lift_cells.append(l)
			return l
		"m":
			var m := Proto.spawn("ship_mast", c)
			if nice != "":
				m.display_name = nice
				m.desc = String(mod.get("desc", m.desc))
			m.tags["mod"] = mod_id
			masts.append(m)
			return m
		"p":
			var sc := Proto.spawn("ship_propeller", c, {"spr": "propeller_" + facing_name})
			if nice != "":
				sc.display_name = nice
				sc.desc = String(mod.get("desc", sc.desc))
			sc.tags["mod"] = mod_id
			screws.append(sc)
			return sc
		"B":
			var b := Proto.spawn("ship_boiler", c)
			var bc: CBoiler = b.c(&"boiler")
			if bc != null:
				bc.mod = mod_id
			if nice != "":
				b.display_name = nice
				b.desc = String(mod.get("desc", b.desc))
			boilers.append(b)
			return b
		"G":
			var g := Proto.spawn("ship_dynamo", c)
			if nice != "":
				g.display_name = nice
				g.desc = String(mod.get("desc", g.desc))
			var pg = g.c(&"powergen")
			if pg != null and mod.has("power"):
				pg.max_output = maxf(1000.0, float(mod["power"]))
			g.tags["mod"] = mod_id
			return g
		"S": return Proto.spawn("ship_apc", c)
		"T":
			var t2 := Proto.spawn("fuel_bunker", c)
			var fb: CFuelBunker = t2.c(&"fuelbunker")
			if fb != null and mod.has("fuel_cap"):
				fb.capacity = float(mod["fuel_cap"])
				fb.amount = minf(fb.amount, fb.capacity)
			if fb != null:
				fb.mod = mod_id
			if nice != "":
				t2.display_name = nice
				t2.desc = String(mod.get("desc", t2.desc))
			bunkers.append(t2)
			return t2
		"O": return Proto.spawn("ballast_tank", c)
		"g":
			var gm := Proto.spawn("gun_mount", c, {"spr": "gun_" + facing_name})
			var gc: CShipGun = CShipGun.new()
			gc.ship_id = id
			gc.mod = mod_id if mod_id != "" else "gun_swivel"
			gm.add(gc)
			if nice != "":
				gm.display_name = nice
				gm.desc = String(mod.get("desc", gm.desc))
			guns.append(gm)
			return gm
		"C":
			# a utility mounting is a hole that takes any of half a dozen fittings, so
			# what actually gets spawned is whichever one the owner bolted in
			var util_proto := UTIL_PROTO.get(mod_id, "cargo_winch")
			if not Proto.has(String(util_proto)):
				util_proto = "cargo_winch"
			var w := Proto.spawn(String(util_proto), c)
			if w == null:
				return null
			w.tags["mod"] = mod_id
			if nice != "":
				w.display_name = nice
				w.desc = String(mod.get("desc", w.desc))
			utilities.append(w)
			return w
		"v": return Proto.spawn("air_vent", c) if Proto.has("air_vent") else null
		"s": return Proto.spawn("air_scrubber", c) if Proto.has("air_scrubber") else null
		"*": return Proto.spawn("deck_lantern", c)
		"c": return Proto.spawn("chair", c, {"name": "deck chair", "spr": "chair_shuttle_" + facing_name})
		"b": return Proto.spawn("bunk", c) if Proto.has("bunk") else Proto.spawn("bed", c)
		"t": return Proto.spawn("table", c)
		"d": return Proto.spawn("workbench", c) if Proto.has("workbench") else Proto.spawn("table", c)
		"f": return Proto.spawn("galley_stove", c) if Proto.has("galley_stove") else null
		"M": return Proto.spawn("med_bed", c)
		"k": return Proto.spawn("crate", c) if Proto.has("crate") else null
		"l": return Proto.spawn("locker", c)
		"o": return Proto.spawn("locker", c, {"name": "emergency locker", "spr": "locker_emerg"})
		"?": return _loot_cache(c)
	return null

func _loot_cache(c: Vector2i) -> Entity:
	var box := Proto.spawn("crate", c, {"name": "salvage crate"}) if Proto.has("crate") else Proto.spawn("locker", c)
	var st: CStorage = box.c(&"storage")
	if st != null:
		for _i in Game.rng.randi_range(1, 4):
			var pick: String = Salvage.roll(Game.rng)
			if Proto.has(pick):
				st.insert(Proto.spawn(pick, c))
	return box

# ------------------------------------------------------------------ building
## World cell to local (u, v). The inverse of cell().
func local_of(c: Vector2i) -> Vector2i:
	var rel := c - origin
	var f := _fwd()
	var st := _stbd()
	return Vector2i(rel.x * f.x + rel.y * f.y, rel.x * st.x + rel.y * st.y)

## Centre of the tile indices in the ship's own frame. Every visual uses this pivot.
func local_pivot() -> Vector2:
	var b := shape_bounds()
	return Vector2(b.position) + Vector2(b.size - Vector2i.ONE) * 0.5

func pivot_offset(dir: int) -> Vector2:
	var f := Vector2(Defs.DIRS4[dir])
	var mid := local_pivot()
	return f * mid.x + Vector2(-f.y, f.x) * mid.y + Vector2(0.5, 0.5)

func visual_pivot() -> Vector2:
	return (pos + pivot_offset(facing)) * float(Defs.TILE)

## Walking endpoints stay in the simulation frame, independently of rendering.
func simulation_position(e: Entity) -> Vector2:
	var m: CMob = e.c(&"mob")
	if m != null and m.moving:
		return m.from_pos.lerp(m.to_pos, m.move_t)
	return Entity.cell_to_pos(e.cell)

func visual_position(home: Vector2) -> Vector2:
	var feet := Vector2(0, Defs.TILE * 0.5)
	var local := ((home - feet) / float(Defs.TILE) - Vector2(origin) - Vector2(0.5, 0.5)).rotated(-_angle_of(facing))
	var centre := visual_pivot() + ((local - local_pivot()) * float(Defs.TILE)).rotated(angle)
	return centre + feet

## Pick the simulated tile corresponding to a point on the visible, rotated deck.
func visual_to_cell(world_position: Vector2) -> Vector2i:
	var local := (world_position - visual_pivot()).rotated(-angle) / float(Defs.TILE) + local_pivot()
	return cell(floori(local.x + 0.5), floori(local.y + 0.5))

## Does a local cell touch the ship, so something could be fixed to it?
func touches(local: Vector2i) -> bool:
	for d in Defs.DIRS4:
		if cells_map.has(local + d):
			return true
	return false

## Would removing this piece leave part of the ship floating on its own? A hull has to stay
## one connected thing, or moving her would tear her in half.
func would_sever(local: Vector2i) -> bool:
	if not cells_map.has(local):
		return false
	var rest := {}
	for k in cells_map:
		if k != local:
			rest[k] = true
	if rest.is_empty():
		return false
	var start: Vector2i = rest.keys()[0]
	var seen := {start: true}
	var q := [start]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in Defs.DIRS4:
			var n: Vector2i = c + d
			if rest.has(n) and not seen.has(n):
				seen[n] = true
				q.append(n)
	return seen.size() < rest.size()

## Add, change or remove one piece of the ship, and put the world right afterwards.
## `ch` of "" removes. Everything downstream — mass, lift, sealing, what moves with her —
## reads the live layout, so this is the only call building needs to make.
func set_piece(local: Vector2i, ch: String) -> void:
	var map := Game.map
	var world := cell(local.x, local.y)
	if not map.inb(world):
		return
	# take the old fitting away, if this tile had one
	for p in parts.duplicate():
		if is_instance_valid(p) and not p.removed and p.cell == world:
			_forget_part(p)
			p.destroy()
	var was: String = String(cells_map.get(local, ""))
	if ch != was:
		fittings.erase(local)
	if ch != "":
		var dflt := ShipParts.default_for(ch)
		if dflt != "" and not fittings.has(local):
			fittings[local] = dflt
	if ch == "":
		cells_map.erase(local)
		# hand the tile back to whatever was under it
		for f in _footprint:
			if f["cell"] == world:
				var i := map.idx(world)
				map.turf[i] = f["turf"]
				map.variant[i] = f["variant"]
				map.structure[i] = f["structure"]
				map.struct_hp[i] = Defs.STRUCTS[f["structure"]]["hp"]
				map.area[i] = f["area"]
				_footprint.erase(f)
				break
		_retile([world])
	else:
		cells_map[local] = ch
	_relay()
	mark_dirty()

## Drop a fitting out of every index it is in. One place, so a new index cannot be
## forgotten the next time one is added.
func _forget_part(p: Entity) -> void:
	parts.erase(p)
	thrusters.erase(p)
	lift_cells.erase(p)
	masts.erase(p)
	boilers.erase(p)
	bunkers.erase(p)
	guns.erase(p)
	screws.erase(p)
	utilities.erase(p)
	if helm == p:
		helm = null

## Re-lay the whole hull in place. Cheaper than it sounds (a few hundred tiles) and it is
## the one call that guarantees turfs, areas, sealing and fittings all agree.
func _relay() -> void:
	var carried := _carried()
	_carry_ids.clear()
	for rec in carried:
		_carry_ids[rec["e"].get_instance_id()] = true
	restamping = true
	_restore()
	_lay_terrain(true, true)
	_put_back(carried, false)
	restamping = false
	_carry_ids.clear()
	if is_instance_valid(renderer):
		renderer.queue_redraw()
	_fit_missing()
	Bus.lights_dirty.emit()

## Spawn fittings for layout cells that do not have one yet (a newly built helm, a lift
## cell dropped into a new bay). Existing fittings are left where they are.
func _fit_missing() -> void:
	var have := {}
	for p in parts:
		if is_instance_valid(p) and not p.removed:
			have[p.cell] = true
	for key in cells_map:
		var c := cell(key.x, key.y)
		if have.has(c) or not Game.map.inb(c):
			continue
		var e := _fit(cells_map[key], c, key)
		if e != null:
			parts.append(e)
			e.tags["ship"] = id
			if e.has_c(&"light") and Game.lighting != null and Game.lighting.map != null:
				Game.lighting.register(e.c(&"light"))

# ------------------------------------------------------------------ mass, lift, thrust
func mass() -> float:
	if Game.time - _mass_t < 2.0 and _mass_cache > 0.0:
		return _mass_cache * (1.0 - ballast * 0.40)
	_mass_t = Game.time
	var m := hull_mass()
	for c in cells:
		for e in Game.at(c):
			if e in parts:
				continue
			if e.has_c(&"mob"):
				m += 7.0
			elif e.has_c(&"item"):
				var it: CItem = e.c(&"item")
				m += 0.15 * float(it.w_class if it != null else 2)
			elif e.has_c(&"storage"):
				m += 2.0
	m += bilge * hull_mass() * 0.10 # standing water is weight
	# Ballast is the pilot's main trim control: a hull floats high with full cells, and you
	# pump water in to hold it level. Holding a steady altitude is a thing you actively do.
	_mass_cache = m
	return m * (1.0 - ballast * 0.40)

## What a *stock* cell is worth on this hull. Cells are rated against the hull they are
## fitted to rather than being a fixed size, so every ship — including one the player drew
## themselves — floats at the same designed ratio with no table to tune. Better cells then
## carry more than their share of it.
func lift_rating() -> float:
	var units: float = stats()["lift_units"]
	if units <= 0.0:
		return 0.0
	return hull_mass() * DESIGN_LIFT / units

## Empty displacement: the structure plus what is bolted into it, with nothing aboard.
## Both the lift rating and the shipyard's readout are measured against this, so a hull
## floats at its designed ratio whatever you fit to it.
func hull_mass() -> float:
	return ShipPlan.mass_of(cells_map) + float(stats()["mass"]) * 0.5

## Lift from every cell that is charged and intact, each scaled by what kind of cell it is.
func lift() -> float:
	var rating := lift_rating()
	var total := 0.0
	var cold := 1.0
	if quirk_count("cold_lift") > 0 and Game.sky != null:
		# a sunken cell lifts harder the colder the air: best at altitude and after dark
		cold = 1.0 + clampf((Defs.T20C - Defs.sky_temp(altitude)) / 90.0, -0.1, 0.55)
	for l in lift_cells:
		if not is_instance_valid(l) or l.removed:
			continue
		var lc = l.c(&"liftcell")
		if lc == null:
			continue
		var share := ShipParts.stat(String(lc.mod), "lift", 1.0)
		var k := cold if ShipParts.has_quirk(String(lc.mod), "cold_lift") else 1.0
		total += lc.output() * rating * share * k
	# the air she is actually in: a squall is free altitude, a downdraft is how ships
	# are lost, and neither is something you can only read about in a panel
	if Game.sky != null and Game.sky.has_method("lift_factor_at"):
		total *= Game.sky.lift_factor_at(center())
	return total

## Positive: climbing. Negative: sinking. Expressed as a fraction of the ship's mass, so
## a reading of 1.0 means "you are holding exactly your own weight".
func buoyancy() -> float:
	var m := maxf(1.0, mass())
	return lift() / m

## Forward force. Each engine contributes its own rating rather than a flat constant, so
## an upgraded thruster is felt immediately and the shop's numbers are the real ones.
func thrust() -> float:
	var total := 0.0
	var storm := _storm_charge()
	for t in thrusters:
		if not is_instance_valid(t) or t.removed:
			continue
		var tc = t.c(&"thruster")
		if tc == null:
			continue
		var rated := ShipParts.stat(String(tc.mod), "thrust", THRUST_PER_ENGINE)
		if ShipParts.has_quirk(String(tc.mod), "storm_feed"):
			rated *= 1.0 + storm * 0.9
		total += tc.output() * rated
	# airscrews contribute a little push of their own, and they do it on volts
	for sc in screws:
		if is_instance_valid(sc) and not sc.removed:
			total += ShipParts.stat(String(sc.tags.get("mod", "")), "thrust", 0.0) * throttle
	# a hand on the wheel who knows what they are doing gets more out of the same engines
	total *= 1.0 + pilot_skill("airmanship") * 0.18
	# Thruster spool already follows the throttle. Multiplying it again squares the input.
	return total

## How much charge is in the air right here: a stormdrive drinks it and a lance recharges
## faster in it. 0 in clear air, 1 in the heart of a thunderhead.
func _storm_charge() -> float:
	if Game.sky == null or not Game.sky.has_method("storm_charge_at"):
		return 0.0
	return Game.sky.storm_charge_at(center())

func sail_force() -> Vector2:
	var area := 0.0
	var close := false
	for m in masts:
		if not is_instance_valid(m) or m.removed:
			continue
		var mid := String(m.tags.get("mod", ""))
		area += ShipParts.stat(mid, "sail", SAIL_AREA_PER_MAST)
		if ShipParts.has_quirk(mid, "close_hauled"):
			close = true
	if area <= 0.0 or sails_set <= 0.0 or Game.sky == null:
		return Vector2.ZERO
	var w: Vector2 = Game.sky.wind_vector()
	# sails only pull usefully on the beam or behind; close to the wind they do nothing.
	# A lateen rig cheats that rule, which is the entire reason anyone buys one.
	var f := Vector2(cos(angle), sin(angle))
	var dot: float = w.normalized().dot(f) if w.length() > 0.01 else 0.0
	var align := clampf(dot, -0.55 if close else -0.2, 1.0)
	if close and dot < 0.0:
		align = absf(dot) * 0.55
	# trim is a skill: a good hand gets more out of the same canvas
	var trim := 1.0 + pilot_skill("rigging") * 0.3
	return w * area * sails_set * maxf(0.0, align) * 0.08 * trim

## Where thrust and drag balance: m(k1 v + k2 v^2) = T.
func top_speed() -> float:
	var t := thrust() + sail_force().length()
	if t <= 0.0:
		return 0.0
	var m := maxf(1.0, mass())
	var dm: float = stats()["drag_mul"]
	var a := DRAG * m * dm
	var b := DRAG_LINEAR * m * dm
	return (-b + sqrt(b * b + 4.0 * a * t)) / (2.0 * a)

func speed() -> float:
	return vel.length()

# ------------------------------------------------------------------ visual life
const ShipFxScript := preload("res://src/ship/ship_fx.gd")
const ARRIVE_DROP := 0.9
const ARRIVE_LEN := 2.6
var arrive_age := 99.0
var thrum := 0.0            # 0..1 how hard her engines are working, for the panels
var _fx_t := 0.0
var _bob := 0.0
var _bob_v := 0.0
var _sway := 0.0
var _sway_v := 0.0
var _last_throttle := 0.0
var _landed := true
var _alpha_done := true
var _smoke_t := 0.0
var _exhaust_t := 0.0

## Start the arrival: she falls into her berth out of the air, fading in, and lands.
func begin_arrival() -> void:
	arrive_age = 0.0
	_landed = false
	_alpha_done = false
	_bob = 0.0
	_bob_v = 0.0
	_set_alpha(0.0)
	fx_offset = Vector2(0, -96.0)

func arriving() -> bool:
	return arrive_age < ARRIVE_LEN

func _set_alpha(a: float) -> void:
	if renderer != null and is_instance_valid(renderer):
		renderer.modulate.a = a
	for p in parts:
		if is_instance_valid(p) and not p.removed:
			p.modulate.a = a

## She hits her berth: the hull squats and rebounds on the spring, vapour rolls off the
## edge of the deck, the camera thumps.
func _touch_down() -> void:
	_bob_v += 70.0
	if Game.view != null:
		Game.view.shake(2.5)
	var rim := []
	for key in cells_map:
		for d in Defs.DIRS4:
			if not cells_map.has(key + d):
				rim.append(cell(key.x, key.y))
				break
	var step := maxi(1, rim.size() / 10)
	var pick := []
	for i in range(0, rim.size(), step):
		pick.append(rim[i])
	for c in pick:
		ShipFxScript.puff(Entity.cell_to_pos(c) + Vector2(0, 10), 2, 10.0, 12.0, 1.3,
			Color(0.9, 0.95, 1.0, 0.7), 2.1, 0.5, Vector2((c.x - center().x) * 4.0, 0))
	Sfx.play("door", center(), 0.9)

## The living part of a hull: a damped bob and sway that never quite stops, kicked by the
## throttle and by the rudder, a hum in the frame when the engines are working, smoke from
## the funnel and a wisp behind each burner. All of it is the drawn hull's offset only.
func _visual_fx(delta: float) -> void:
	var d := minf(delta, 0.05)
	_fx_t += d
	var sp := clampf(speed() / 3.0, 0.0, 1.0)
	# opening the throttle kicks the hull; the spring gives it weight
	_bob_v += (throttle - _last_throttle) * 26.0
	_last_throttle = throttle
	var amp := lerpf(1.8, 1.1, sp)
	var target := sin(_fx_t * 2.3 + id) * amp + sin(_fx_t * 1.31 + 1.0) * amp * 0.5 - ballast * 1.5
	_bob_v += (-40.0 * (_bob - target) - 7.5 * _bob_v) * d
	_bob += _bob_v * d
	# leaning out of a turn
	var lean := -clampf(angular_velocity, -1.2, 1.2) * 3.0
	var tsway := sin(_fx_t * 1.7 + 2.0 + id) * 0.9 + lean
	_sway_v += (-24.0 * (_sway - tsway) - 6.0 * _sway_v) * d
	_sway += _sway_v * d
	var run := 0.0
	for t in thrusters:
		if is_instance_valid(t) and not t.removed and t.has_c(&"thruster"):
			run = maxf(run, t.c(&"thruster").spool)
	thrum = move_toward(thrum, run, d * 3.0)
	# (the old 58 Hz engine-hum jitter beat against the frame rate into a visible sub-pixel
	# shimmer of the whole world, since the camera rides the deck; the hum is now carried by
	# the thrum-scaled sway spring alone)
	var jit := 0.0
	var drop := 0.0
	if arrive_age < ARRIVE_LEN:
		arrive_age += d
		if arrive_age < ARRIVE_DROP:
			var k := 1.0 - arrive_age / ARRIVE_DROP
			drop = -96.0 * k * k
		elif not _landed:
			_landed = true
			_touch_down()
		if arrive_age < 0.6:
			_set_alpha(clampf(arrive_age / 0.45, 0.0, 1.0))
		elif not _alpha_done:
			_alpha_done = true
			_set_alpha(1.0)
	# whole texels only: a fractional offset on a pixel-art hull shimmers as it changes
	fx_offset = Vector2(roundf(_sway + jit * 0.5), roundf(_bob + jit + drop))
	_funnel_and_exhaust(d, thrum)

func _funnel_and_exhaust(d: float, run: float) -> void:
	if Game.player == null or Game.view == null:
		return
	if Game.player.position.distance_to(visual_pivot()) > 900.0:
		return
	_smoke_t -= d
	if _smoke_t <= 0.0:
		var fire := 0.0
		var stack: Entity = null
		for b in boilers:
			if is_instance_valid(b) and not b.removed and b.has_c(&"boiler"):
				var bc: CBoiler = b.c(&"boiler")
				if bc.lit and bc.pressure / CBoiler.SAFE_PRESSURE > fire:
					fire = clampf(bc.pressure / CBoiler.SAFE_PRESSURE, 0.0, 1.0)
					stack = b
		_smoke_t = lerpf(1.0, 0.35, maxf(fire, run))
		if stack != null and fire > 0.02:
			ShipFxScript.funnel(stack.position + Vector2(0, -16), maxf(fire * 0.5, run))
	_exhaust_t -= d
	if _exhaust_t <= 0.0 and run > 0.25:
		_exhaust_t = 0.28
		var back := -Vector2(cos(angle), sin(angle))
		for t in thrusters:
			if is_instance_valid(t) and not t.removed and t.has_c(&"thruster") and t.c(&"thruster").spool > 0.25:
				ShipFxScript.puff(t.position + back * 16.0 + Vector2(0, -8), 1, 3.0, 6.0, 0.7,
					Color(1.0, 0.92, 0.78, 0.5 * run), 1.1, 0.35, back * 34.0)

# ------------------------------------------------------------------ flight
func fly(delta: float) -> void:
	if not present:
		return
	_visual_fx(delta)
	_crash_t = maxf(0.0, _crash_t - delta)
	_turn(delta)
	var m := maxf(1.0, mass())
	var force := Vector2(cos(angle), sin(angle)) * thrust() + sail_force()
	if Game.sky != null:
		# even with no sail set, a hull this size gets pushed around — unless a gyro is
		# spinning, in which case she simply refuses to be
		var buffet := 0.012
		if quirk_count("steady") > 0:
			buffet *= 0.25
		force += Game.sky.wind_vector() * m * buffet
	vel += force / m * delta
	# quadratic drag: every hull finds its own cruise
	var sp := vel.length()
	if sp > 0.0001:
		var dm: float = stats()["drag_mul"]
		vel *= exp(-DRAG_LINEAR * dm * delta) / (1.0 + DRAG * dm * sp * delta)
		# The keel resists sideways skidding while preserving forward momentum.
		var lateral := Vector2(-sin(angle), cos(angle))
		vel -= lateral * vel.dot(lateral) * (1.0 - exp(-0.65 * delta))
		if vel.length() < 0.03 and throttle <= 0.0:
			vel = Vector2.ZERO
	_altitude(delta, m)
	_advance(delta)

## Vertical trim. Lift against mass decides whether you rise, and crossing out of the
## band's range hands the ship to ShipSystem for a region change.
func _altitude(delta: float, m: float) -> void:
	var net := (lift() - m) / m
	if absf(net) < 0.02:
		net = 0.0
	altitude = maxf(0.05, altitude + net * 0.09 * delta)
	if Game.sky != null:
		var band: int = Defs.band_index(Game.sky.gen.altitude)
		var lo: float = Defs.ALT_BANDS[maxi(0, band - 1)]
		var hi: float = Defs.ALT_BANDS[mini(4, band + 1)]
		if band == 0:
			lo = 0.05
		if altitude <= lo + 0.02 or altitude >= hi - 0.02:
			altitude = clampf(altitude, lo + 0.03, hi - 0.03)
			Game.fleet.request_transit(self, altitude <= lo + 0.05)

## The rudder accelerates the bow into a turn and brakes toward an ordered heading.
## Simulation tiles are restamped when the sweep crosses into a new quarter.
##
## If she cannot be restamped — moored tight against a cliff, say — the bow is held at the
## stops rather than allowed to swing on. The picture and the deck you can walk on must
## never disagree by more than the quarter they share.
func _turn(delta: float) -> void:
	_settle(delta)
	var diff := wrapf(wanted_angle - angle, -PI, PI)
	if rudder_input == 0.0 and absf(diff) < 0.0001 and absf(angular_velocity) < 0.001:
		angle = wanted_angle
		angular_velocity = 0.0
		turning = 0.0
		return
	var rate := _turn_rate()
	var desired := rudder_input * rate
	if rudder_input == 0.0:
		# Brake early enough to arrive at an ordered heading without an abrupt stop.
		desired = signf(diff) * minf(rate, sqrt(2.0 * TURN_ACCEL * absf(diff)))
	var previous := angular_velocity
	angular_velocity = move_toward(angular_velocity, desired, TURN_ACCEL * delta)
	var step := (previous + angular_velocity) * 0.5 * delta
	if rudder_input == 0.0 and signf(step) == signf(diff) and absf(step) >= absf(diff):
		step = diff
		angular_velocity = 0.0
	var target := wrapf(angle + step, -PI, PI)
	var q := _quarter_of(target)
	if q != facing and not _rotate_to(q):
		angular_velocity = 0.0
		_hold_at_stops()
		return
	angle = target
	if rudder_input != 0.0:
		wanted_angle = angle # held steering cannot lap the bow and reverse the turn
		heading = _quarter_of(angle)
	turning = maxf(absf(angular_velocity) / TURN_ACCEL,
		absf(wrapf(wanted_angle - angle, -PI, PI)) / maxf(0.05, rate))
	# a hull dragged round loses way, which is what makes a turn cost you something
	vel *= exp(-absf(step) * TURN_DRAG)

## A ship lying still squares herself up.
##
## Once the helm is idle and the ship has lost way, gently align the visible deck with
## its simulation quarter for boarding and building. An active turn keeps its order.
func _settle(delta: float) -> void:
	if rudder_input != 0.0 or throttle > 0.01 or speed() > 0.22 or absf(angular_velocity) > 0.01 or absf(wrapf(wanted_angle - angle, -PI, PI)) > 0.01:
		return
	var square := _angle_of(facing)
	var off := wrapf(wanted_angle - square, -PI, PI)
	if absf(off) < 0.004:
		return
	wanted_angle = square

## Swing is limited to the quarter she is stamped on, so the drawn hull can never get more
## than 45 degrees away from the tiles it stands for.
func _hold_at_stops() -> void:
	# the order stands: as soon as there is room she carries on round
	turning = 0.0
	if Game.fleet != null and Game.fleet.ship_of(Game.player) == self and Game.time > _stops_note:
		_stops_note = Game.time + 6.0
		Game.msg("[i]%s will not come round — there is no room to swing her.[/i]" % ship_name, "warn")

var _stops_note := 0.0

## How fast she answers her helm. Heavier is slower, faster is slower still, and a hull
## with more thrust behind it comes round quicker.
func _turn_rate() -> float:
	var m := maxf(1.0, mass())
	var base := TURN_RATE * (110.0 / m)
	base *= 1.0 / (1.0 + speed() * 0.22)
	if thrust() > 0.0:
		base *= 1.25 # engines help her round
	# rudder authority bought and bolted on: vectoring screws, a gyro, a better helm
	base += float(stats()["turn"])
	base *= 1.0 + pilot_skill("airmanship") * 0.25
	return clampf(base, 0.16, 2.6)

static func _quarter_of(a: float) -> int:
	# 0 east, then clockwise (screen +y is down): south, west, north
	var k := int(round(wrapf(a, 0.0, TAU) / (PI * 0.5))) % 4
	return [Defs.DIR_E, Defs.DIR_S, Defs.DIR_W, Defs.DIR_N][k]

static func _angle_of(dir: int) -> float:
	return [-PI * 0.5, 0.0, PI * 0.5, PI][dir]

func _rotate_to(dir: int) -> bool:
	if Game.map == null:
		return false
	var step: int = ((dir - facing) + 4) % 4
	# Changing the simulation basis must preserve the hull's world-space centre.
	var next_pos := pos + pivot_offset(facing) - pivot_offset(dir)
	var next_origin := Vector2i(floori(next_pos.x), floori(next_pos.y))
	if not _restamp(next_origin, dir):
		return false
	pos = next_pos
	_reface_parts()
	if Game.fleet != null:
		Game.fleet.on_turned(self, 1 if step == 1 else -1)
	Sfx.play("ratchet", center(), 0.5)
	return true

func _dir_word(d: int) -> String:
	return ["bow north", "bow east", "bow south", "bow west"][d]

## Fittings whose sprite depends on which way the ship points (thrusters, guns, props).
func _reface_parts() -> void:
	var aft := Vessel.vec_dir(-_fwd())
	var fore := Vessel.vec_dir(_fwd())
	for p in parts:
		if not is_instance_valid(p) or p.removed:
			continue
		match p.proto:
			"ship_thruster": p.set_sprite("objects", "thruster_" + aft)
			"ship_propeller": p.set_sprite("objects", "propeller_" + fore)
			"gun_mount": p.set_sprite("objects", "gun_" + fore)
			"chair": p.set_sprite("objects", "chair_shuttle_" + fore)

# ------------------------------------------------------------------ moving
func _advance(delta: float) -> void:
	if vel.length() < 0.0001:
		return
	pos += vel * delta
	var want := Vector2i(floori(pos.x), floori(pos.y))
	var d := want - origin
	if d == Vector2i.ZERO:
		return
	d.x = clampi(d.x, -TILE_STEP_LIMIT, TILE_STEP_LIMIT)
	d.y = clampi(d.y, -TILE_STEP_LIMIT, TILE_STEP_LIMIT)
	# one axis at a time, so a diagonal cannot slip through a corner
	if d.x != 0:
		_try_shift(Vector2i(signi(d.x) * mini(absi(d.x), TILE_STEP_LIMIT), 0))
	# A collision or region stop may have clamped pos while resolving the first axis.
	d.y = clampi(floori(pos.y) - origin.y, -TILE_STEP_LIMIT, TILE_STEP_LIMIT)
	if d.y != 0:
		_try_shift(Vector2i(0, signi(d.y) * mini(absi(d.y), TILE_STEP_LIMIT)))

func _try_shift(d: Vector2i) -> void:
	var step := Vector2i(signi(d.x), signi(d.y))
	var n := maxi(absi(d.x), absi(d.y))
	for _k in n:
		if not _shift(step):
			return

## Move exactly one tile. Returns false if we hit something.
func _shift(d: Vector2i) -> bool:
	var to := origin + d
	if not _fits(to, facing):
		if _at_region_edge(to):
			_edge_stop()
		else:
			_collide(d)
		return false
	return _restamp(to, facing)

# ------------------------------------------------------------------ restamping
## Everything the ship carries: her crew, whatever is lying on her decks, and her own
## fittings, each recorded in her frame. One list, because a turn has to move the boiler
## exactly as surely as it moves the cook.
func _carried() -> Array:
	var out := []
	var seen := {}
	var f := _fwd()
	var st := _stbd()
	var record := func(e: Entity, at: Vector2i):
		if e == null or e.removed or seen.has(e.get_instance_id()):
			return
		seen[e.get_instance_id()] = true
		var rel: Vector2i = at - origin
		var m: CMob = e.c(&"mob")
		out.append({"e": e, "u": rel.x * f.x + rel.y * f.y, "v": rel.x * st.x + rel.y * st.y,
			"old_origin": origin, "old_facing": facing,
			"walk_from": m.from_pos if m != null else Vector2.ZERO,
			"walk_to": m.to_pos if m != null else Vector2.ZERO})
	for c in cells:
		for e in Game.at(c):
			if e.holder == null:
				record.call(e, c)
	for p in parts:
		if is_instance_valid(p) and not p.removed:
			record.call(p, p.cell)
	return out

## True while the hull is being lifted and set back down. Nothing the ship carries may be
## shoved aside or dropped into the sky during that window: for one call, the ship's own
## tiles do not exist, and anything standing on them would otherwise be treated as standing
## over nothing.
var restamping := false
var _carry_ids := {}

## Lift the hull, put it down somewhere else (or facing another way), and bring everything
## aboard with it. This is the single path for moving and turning, so the two can never
## drift apart.
func _restamp(new_origin: Vector2i, new_facing: int) -> bool:
	var t_rs := SPerf.t0()
	var ok := _restamp_inner(new_origin, new_facing)
	SPerf.end("restamp", t_rs)
	return ok

func _restamp_inner(new_origin: Vector2i, new_facing: int) -> bool:
	var t := SPerf.t0()
	var carried := _carried()
	SPerf.end("rs.carried", t)
	_carry_ids.clear()
	for rec in carried:
		_carry_ids[rec["e"].get_instance_id()] = true
	var old_origin := origin
	var old_facing := facing
	restamping = true
	t = SPerf.t0()
	var pre := {}
	for c in cells:
		pre[c] = _sig(c)
	var air := _air_snapshot()
	_rt_defer = true
	_rt_acc = []
	_restore()
	SPerf.end("rs.restore", t)
	origin = new_origin
	facing = new_facing
	t = SPerf.t0()
	var fit_ok := _fits(new_origin, new_facing)
	SPerf.end("rs.fits", t)
	if not fit_ok:
		origin = old_origin
		facing = old_facing
		_lay_terrain(true)
		_flush_retile(pre)
		_air_restore(air)
		_put_back(carried, false)
		restamping = false
		_carry_ids.clear()
		return false
	t = SPerf.t0()
	_lay_terrain(true)
	SPerf.end("rs.lay", t)
	t = SPerf.t0()
	_flush_retile(pre)
	_air_restore(air)
	SPerf.end("rs.flush", t)
	t = SPerf.t0()
	_put_back(carried, true)
	SPerf.end("rs.putback", t)
	restamping = false
	_carry_ids.clear()
	# `pos` is the authoritative float position and `origin` only ever tracks floor(pos);
	# nudging pos here as well would advance her twice for every tile of velocity, which is
	# most of what made her judder.
	return true

## Set everything down in the same place aboard it was before. A mob part-way through a
## step has its walk carried along too, so it glides on from where it now is instead of
## snapping back toward a tile that has moved out from under it.
func _put_back(carried: Array, moved: bool) -> void:
	var map := Game.map
	for rec in carried:
		var e: Entity = rec["e"]
		if not is_instance_valid(e) or e.removed:
			continue
		var to := cell(rec["u"], rec["v"])
		if not map.inb(to):
			continue
		e.place(to)
		if moved:
			var m: CMob = e.c(&"mob")
			if m != null and m.moving:
				var old_base := (Vector2(rec["old_origin"]) + Vector2(0.5, 1.0)) * float(Defs.TILE)
				var new_base := (Vector2(origin) + Vector2(0.5, 1.0)) * float(Defs.TILE)
				var turn := _angle_of(facing) - _angle_of(rec["old_facing"])
				m.from_pos = new_base + (Vector2(rec["walk_from"]) - old_base).rotated(turn)
				m.to_pos = new_base + (Vector2(rec["walk_to"]) - old_base).rotated(turn)
				e.position = m.from_pos.lerp(m.to_pos, m.move_t)
				if rec["old_facing"] != facing:
					m.face((m.dir + facing - int(rec["old_facing"]) + 4) % 4)

## Would the hull fit here? Anything solid that is not our own terrain blocks us.
func _fits(at: Vector2i, dir: int) -> bool:
	var map := Game.map
	var tiles: Dictionary = Game.fleet.ship_tiles if Game.fleet != null else {}
	var my_id := id
	var save_o := origin
	var save_f := facing
	origin = at
	facing = dir
	var ok := true
	for key in cells_map:
		var c := cell(key.x, key.y)
		if not map.inb(c) or c.x < 1 or c.y < 1 or c.x >= map.w - 1 or c.y >= map.h - 1:
			ok = false
			break
		if tiles.get(c, -1) == my_id:
			continue
		# open sky and cloud is what we fly through; anything else is an obstruction
		if not Defs.is_void_turf(map.get_turf(c)):
			ok = false
			break
		if map.structure[map.idx(c)] != Defs.S_NONE:
			ok = false
			break
	origin = save_o
	facing = save_f
	return ok

## Is the obstruction simply the end of the sky region rather than something solid?
func _at_region_edge(at: Vector2i) -> bool:
	var map := Game.map
	var save_o := origin
	origin = at
	var edge := false
	for key in cells_map:
		var c := cell(key.x, key.y)
		if not map.inb(c) or c.x < 2 or c.y < 2 or c.x >= map.w - 2 or c.y >= map.h - 2:
			edge = true
			break
	origin = save_o
	return edge

var _edge_t := 0.0

## The rim of the region. Nothing to hit out here, so the ship simply will not go further:
## she loses way and lies to, and the pilot is told why.
func _edge_stop() -> void:
	vel = Vector2.ZERO
	pos = pos.clamp(Vector2(origin), Vector2(origin) + Vector2(0.9999, 0.9999))
	throttle = minf(throttle, 0.2)
	if Game.time < _edge_t:
		return
	_edge_t = Game.time + 12.0
	if Game.fleet != null and Game.fleet.ship_of(Game.player) == self:
		Game.msg("[color=#9ad8ff]The cloud ahead goes on forever and the compass will not settle. This is as far as %s goes in this sky.[/color]" % ship_name, "warn")
		Game.msg("[i]Come about, or change your trim to cross into another band.[/i]", "info")

## Put the ground back the way we found it.
func _restore() -> void:
	var map := Game.map
	var touched := []
	for f in _footprint:
		var c: Vector2i = f["cell"]
		if not map.inb(c):
			continue
		var i := map.idx(c)
		map.turf[i] = f["turf"]
		map.variant[i] = f["variant"]
		map.structure[i] = f["structure"]
		map.struct_hp[i] = Defs.STRUCTS[f["structure"]]["hp"]
		map.turf_hp[i] = float(Defs.TURFS[f["turf"]].get("hp", 100))
		map.area[i] = f["area"]
		touched.append(c)
	_footprint.clear()
	_retile(touched)

# ------------------------------------------------------------------ collisions
func _collide(d: Vector2i) -> void:
	var sp := speed()
	# Stop only the component that is driving into the obstruction, and keep the rest. A
	# hull that bounces off every tile it touches feels broken; one that slides along a
	# coast until it finds a way past feels like a ship.
	if d.x != 0:
		vel.x = 0.0
		pos.x = float(origin.x) + (0.9999 if d.x > 0 else 0.0)
	if d.y != 0:
		vel.y = 0.0
		pos.y = float(origin.y) + (0.9999 if d.y > 0 else 0.0)
	if _crash_t > 0.0:
		return
	_crash_t = 1.0
	if sp < CRASH_SPEED:
		# a touch, not a crash: no damage, and only a note if the pilot is aboard
		if Game.fleet != null and Game.fleet.ship_of(Game.player) == self:
			Game.msg("[i]%s scrapes alongside.[/i]" % ship_name, "warn")
		Sfx.play("wall_hit", center(), 0.5)
		return
	# a real crash: damage scales with how fast you were going
	var force: float = sp * 22.0
	Game.msg("[b][color=#ff6a6a]%s strikes something — hard.[/color][/b]" % ship_name, "bad")
	Bus.chronicle.emit("%s crashed at %.1f tiles/s." % [ship_name, sp], 3)
	Sfx.play("explosion", center(), 0.7)
	if Game.view:
		Game.view.shake(6.0)
	seam = minf(1.0, seam + force * 0.006)
	# stove in the hull on the side that hit
	var hits := 0
	for c in cells:
		var rel: Vector2i = c - origin
		if (d.x != 0 and signi(rel.x) != signi(d.x)) or (d.y != 0 and signi(rel.y) != signi(d.y)):
			continue
		if not Game.map.is_wall(c) or hits >= 8:
			continue
		# plating turns a share of the impacts outright, which is what you paid for
		var odds := 0.22 / (1.0 + armor_at(c) * 0.06)
		if Game.rng.randf() < odds:
			hits += 1
			breach(c)
	for c in cells:
		for e in Game.at(c):
			var h: CHealth = e.c(&"health")
			if h != null and not h.dead:
				h.adjust("brute", force * 0.12, null)
				h.knockdown(20.0)
				Game.tell(e, "You are thrown off your feet!", "bad")

## Hole in the hull. At altitude this is how a crew dies.
func breach(c: Vector2i) -> void:
	var map := Game.map
	if not map.inb(c):
		return
	map.set_turf(c, Defs.T_DECK_OPEN)
	map.set_structure(c, Defs.S_NONE)
	_breaches += 1
	seam = minf(1.0, seam + 0.04)
	if Game.rng.randf() < 0.35 and Game.atmos != null:
		Game.atmos.ignite(c, null, 3.0) # splinters, sparks, a lamp let go
	for f in _footprint:
		if f["cell"] == c:
			f["turf"] = f["turf"] # footprint keeps the original ground; the hull is what changed
	Fx.sparks(c)
	Game.visible_message(c, "[b]The hull gives way![/b]", "bad")

func breaches() -> int:
	var n := 0
	for c in inside_cells:
		if Game.map.is_outdoor(c):
			n += 1
		for d in Defs.DIRS4:
			if Game.map.inb(c + d) and Defs.is_void_turf(Game.map.get_turf(c + d)):
				n += 1
				break
	return n

# ------------------------------------------------------------------ queries
func is_aboard(e: Entity) -> bool:
	if e == null or e.removed:
		return false
	var c := e.root_cell()
	return present and Game.map.inb(c) and areas.has(Game.map.area[Game.map.idx(c)])

func occupants() -> Array:
	var out := []
	for c in cells + lower_cells:
		for e in Game.at(c):
			if e.has_c(&"mob"):
				out.append(e)
	return out

## Is there a lit boiler with enough pressure to work the thrusters' injectors?
func steam_up() -> bool:
	for b in boilers:
		if not is_instance_valid(b) or b.removed:
			continue
		var bc: CBoiler = b.c(&"boiler")
		if bc != null and bc.lit and bc.pressure > 8.0:
			return true
	return false

func fuel() -> float:
	var f := 0.0
	for b in bunkers:
		if is_instance_valid(b) and not b.removed and b.has_c(&"fuelbunker"):
			f += b.c(&"fuelbunker").amount
	return f

## Total bunker capacity, for the range readout.
func fuel_capacity() -> float:
	var c := 0.0
	for b in bunkers:
		if is_instance_valid(b) and not b.removed and b.has_c(&"fuelbunker"):
			c += b.c(&"fuelbunker").capacity
	return c

## Tonnes of hold. Racking, winches and a big enough deck.
func cargo_capacity() -> float:
	return float(stats()["cargo"]) + float(inside_cells.size()) * 0.35

## Berths: how many people she is meant for.
func berths() -> int:
	return int(stats()["crew"]) + int(hull.get("crew", 2))

## Damage soaked by the plating on a given hull tile.
func armor_at(c: Vector2i) -> float:
	var local := local_of(c)
	return ShipParts.stat(module_at(local), "armor", 0.0)

## How many seconds of full throttle are left in the bunkers.
func endurance() -> float:
	var burn := 0.0
	for t in thrusters:
		if is_instance_valid(t) and not t.removed and t.has_c(&"thruster"):
			burn += CThruster.FUEL_PER_SECOND * ShipParts.stat(String(t.c(&"thruster").mod), "fuel_mul", 1.0)
	if burn <= 0.001:
		return 9999.0
	return fuel() / burn

func draw_fuel(want: float) -> float:
	var got := 0.0
	for b in bunkers:
		if got >= want:
			break
		if is_instance_valid(b) and not b.removed and b.has_c(&"fuelbunker"):
			got += b.c(&"fuelbunker").draw(want - got)
	return got

## The line the helm and the nav console read out.
func status_text() -> String:
	var b := buoyancy()
	var trim := "level"
	if b > 1.04: trim = "climbing"
	elif b < 0.96: trim = "sinking"
	if not steam_up():
		trim += ", no steam"
	return "%s — %s, %.1f/%.1f kt, %.2f km (%s), lift %.0f%%, fuel %.0f/%.0f, %d breach%s" % [
		ship_name, _dir_word(facing), speed(), top_speed(), altitude, trim, b * 100.0,
		fuel(), fuel_capacity(), breaches(), "" if breaches() == 1 else "es"]

# ------------------------------------------------------------------ leaving
## Take the ship (and everyone on it) out of the region.
func remove() -> Array:
	var aboard := occupants()
	var leaving := []
	for c in cells + lower_cells:
		for e in Game.at(c):
			leaving.append(e)
	for e in Game.entities.values():
		if e.holder != null and e.root() in leaving:
			leaving.append(e)
	for p in parts:
		if not p in leaving:
			leaving.append(p)
	for e in leaving:
		if is_instance_valid(e) and not e.removed:
			e.destroy()
	parts.clear()
	Underdecks.clear(self)
	_restore()
	for a in areas.values():
		a.cells.clear()
	present = false
	if Game.fleet != null:
		Game.fleet.rebuild_tile_index()
	Bus.lights_dirty.emit()
	return aboard
