class_name Vessel extends RefCounted
## A vehicle stamped onto the glacier from a character layout: the evacuation crawler and
## the escape pods. It brings its own hull, floor, windows, air, power and fittings, and
## `remove()` takes it (and everyone aboard) away and puts the ground back.
##
## Layouts are in the dock's frame: u runs away from the station (column 0 touches the
## station hull, with the hatch 'H' at v = 0), v runs along the hull.
##   # hull    W window    H hatch    D cockpit door (command)    B brig door    M medbay door
##   . floor passengers can stand on    , other floor    > < ^ v seats facing +u / -u / -v / +v
##   N C consoles    L pod launch console    o emergency closet    b medical bed
##   l medical closet    k brig bench    E drive unit

const SOLID := ["#", "W", "E", "N", "C", "L", "o", "b", "l"]
const SEATS := [">", "<", "^", "v"]

var name := ""
var kind := "crawler" # or "pod"
var dock_cell := Vector2i.ZERO
var dir := Vector2i.RIGHT
var layout: Array = []
var v0 := 0 # layout row of the hatch
var area_key: Callable # (u, v) -> key in area_names
var area_names := {} # key -> area name; "main" is where passengers ride
var lights: Array = [] # [Vector2i(u, v)]
var treads := false

var areas := {} # area id -> Area
var main: Area = null
var cells: Array = []
var interior: Array = [] # passenger floor in the main area
var seats := {} # interior cells with a seat
var brig_cells: Array = []
var parts: Array = []
var present := false
var _footprint: Array = []

func cell(u: int, v: int) -> Vector2i:
	return dock_cell + dir * u + Vector2i(dir.y, dir.x) * v

func u_max() -> int:
	return layout[0].length() - 1

func is_on(c: Vector2i) -> bool:
	var map := Game.map
	return present and map.inb(c) and areas.has(map.area[map.idx(c)])

func occupants() -> Array:
	var out := []
	for c in cells:
		for ent in Game.at(c):
			if ent.has_c(&"mob"):
				out.append(ent)
	return out

func free_seat_count() -> int:
	var n := 0
	for c in interior:
		if not Game.at(c).any(func(x): return x.has_c(&"mob")):
			n += 1
	return n

static func vec_dir(v: Vector2i) -> String:
	if v.x > 0: return "e"
	if v.x < 0: return "w"
	return "s" if v.y > 0 else "n"

# ------------------------------------------------------------------ building
func stamp() -> void:
	var map := Game.map
	var side := Vector2i(dir.y, dir.x)
	areas.clear()
	var by_key := {}
	for k in area_names:
		var a := map.new_area(area_names[k], "civilian")
		a.restricted = []
		a.room_kind = kind
		# vehicles run off their own engines, not the station grid
		a.power_equip = true
		a.power_light = true
		a.power_environ = true
		areas[a.id] = a
		by_key[k] = a
	main = by_key["main"]
	cells.clear()
	interior.clear()
	seats.clear()
	brig_cells.clear()
	parts.clear()
	_footprint.clear()
	var fit := []
	for row in layout.size():
		var v: int = row - v0
		var line: String = layout[row]
		for u in line.length():
			var c := cell(u, v)
			if not map.inb(c):
				continue
			var ch := line[u]
			_footprint.append({"cell": c, "turf": map.get_turf(c), "structure": map.structure[map.idx(c)], "area": map.area[map.idx(c)]})
			_clear_cell(c, ch in SOLID)
			var key: String = area_key.call(u, v) if area_key.is_valid() else "main"
			var a: Area = by_key[key]
			if ch == "#":
				map.set_turf(c, Defs.T_HULL)
			else:
				map.set_turf(c, Defs.T_SHUTTLE)
				if ch == "W":
					map.set_structure(c, Defs.S_RWINDOW) # shuttle glass is reinforced
			map.assign_area(c, a)
			a.cells.append(c)
			cells.append(c)
			if a == main and (ch == "." or ch in SEATS):
				interior.append(c)
				if ch in SEATS:
					seats[c] = true
			if key == "brig" and not ch in ["#", "B", "E"]:
				brig_cells.append(c)
			fit.append([ch, c])
	for a in areas.values():
		if not a.cells.is_empty():
			a.center = a.cells[a.cells.size() / 2]
	_fill_air()
	for fc in fit:
		_fit(fc[0], fc[1], side)
	for l in lights:
		parts.append(Proto.spawn("ceiling_light", cell(l.x, l.y), {"comps": {"light": {"kind": "always", "radius": 5.0, "color": "#ffe8c8", "energy": 0.8}}}))
	if treads:
		_lay_treads(side)
	for p in parts:
		if p.has_c(&"light"):
			Game.lighting.register(p.c(&"light"))
	present = true
	Bus.lights_dirty.emit()

func _fill_air() -> void:
	var map := Game.map
	var at = Game.atmos
	for c in cells:
		var i: int = map.idx(c)
		if map.blocks_air(c):
			continue
		for g in Defs.GAS_COUNT:
			at.gas[g][i] = 0.0
		at.gas[Defs.G_O2][i] = Defs.MOLES_CELLSTANDARD * 0.21
		at.gas[Defs.G_N2][i] = Defs.MOLES_CELLSTANDARD * 0.79
		at.temp[i] = Defs.T20C
		at.wake(c)

func _fit(ch: String, c: Vector2i, side: Vector2i) -> void:
	var noun := "crawler" if kind == "crawler" else "pod"
	match ch:
		"H":
			var hatch := Proto.spawn("airlock", c, {"name": "%s hatch" % noun, "comps": {"door": {"dept": "ext", "access": []}}})
			hatch.c(&"door").external = false
			parts.append(hatch)
		"D":
			parts.append(Proto.spawn("airlock", c, {"name": "cockpit door", "comps": {"door": {"dept": "cmd", "access": ["command"]}}}))
		"B":
			parts.append(Proto.spawn("airlock", c, {"name": "%s brig" % noun, "comps": {"door": {"dept": "sec", "access": ["brig", "security"]}}}))
		"M":
			parts.append(Proto.spawn("airlock", c, {"name": "%s medbay" % noun, "comps": {"door": {"dept": "med", "access": []}}}))
		">", "<", "^", "v":
			var fv: Vector2i = {">": dir, "<": -dir, "^": -side, "v": side}[ch]
			parts.append(Proto.spawn("chair", c, {"name": "%s seat" % noun, "spr": "chair_shuttle_" + vec_dir(fv)}))
		"k":
			parts.append(Proto.spawn("chair", c, {"name": "brig bench", "spr": "chair_steel_" + vec_dir(dir)}))
		"N":
			parts.append(Proto.spawn("console", c, {"name": "navigation console", "spr": "console_cmd", "comps": {"console": {"kind": "cmd"}, "machine": {"needs_power": false}}}))
		"C":
			parts.append(Proto.spawn("console", c, {"name": "%s comms console" % noun, "spr": "console_comms", "comps": {"console": {"kind": "comms"}, "machine": {"needs_power": false}}}))
		"L":
			parts.append(Proto.spawn("console", c, {"name": "pod launch control", "spr": "console_sec", "comps": {"console": {"kind": "pod"}, "machine": {"needs_power": false}}}))
		"o":
			# tg emergency closets: air and masks for when the hull is breached
			parts.append(_closet(c, "emergency closet", "locker_emerg", ["tank_air", "tank_air", "breath_mask", "breath_mask", "extinguisher"]))
		"b":
			parts.append(Proto.spawn("med_bed", c))
		"l":
			parts.append(_closet(c, "medical closet", "locker_med", ["medkit", "bruise_pack", "ointment", "bruise_pack"]))
		"E":
			parts.append(Proto.spawn("crawler_engine", c))

func _lay_treads(side: Vector2i) -> void:
	## Caterpillar tracks down the outer side.
	var map := Game.map
	var vmin: int = -v0 + 1
	var vmax: int = layout.size() - 1 - v0 - 1
	var first := cell(u_max() + 1, vmin)
	var last := cell(u_max() + 1, vmax)
	var top := first if (first.y < last.y or first.x < last.x) else last
	for v in range(vmin, vmax + 1):
		var c := cell(u_max() + 1, v)
		if not map.inb(c):
			continue
		_clear_cell(c, true)
		var part := "mid"
		if c == first or c == last:
			part = "a" if c == top else "b"
		parts.append(Proto.spawn("crawler_tread", c, {"spr": "tread_%s_%s" % ["v" if side.y != 0 else "h", part]}))

func _closet(c: Vector2i, nm: String, spr: String, contents: Array) -> Entity:
	var cl := Proto.spawn("locker", c, {"name": nm, "spr": spr, "comps": {"storage": {"spr": spr, "spr_open": spr + "_open"}}})
	for p in contents:
		cl.c(&"storage").insert(Proto.spawn(p, c))
	return cl

func _clear_cell(c: Vector2i, solid: bool) -> void:
	## Make room. Props are removed. Where something solid goes, loose things and people
	## are pushed inside.
	for ent in Game.at(c).duplicate():
		if ent.has_c(&"mob") or ent.has_c(&"item"):
			if solid:
				ent.place(cell(1, 0))
		else:
			ent.destroy()

# ------------------------------------------------------------------ leaving
## Drive / launch away. Everyone and everything aboard goes too. Returns the mobs that
## were aboard (already removed from the world, but their data is still readable).
func remove() -> Array:
	var map := Game.map
	var aboard := occupants()
	var leaving := []
	for c in cells:
		for ent in Game.at(c):
			leaving.append(ent)
	for ent in Game.entities.values():
		if ent.holder != null and ent.root() in leaving:
			leaving.append(ent)
	for p in parts:
		if not p in leaving:
			leaving.append(p)
	if Game.player != null and Game.player in aboard:
		Game.player = null
		Bus.player_changed.emit(null)
	for ent in leaving:
		if is_instance_valid(ent) and not ent.removed:
			ent.destroy()
	for f in _footprint:
		map.set_structure(f["cell"], f["structure"])
		map.set_turf(f["cell"], f["turf"])
		map.area[map.idx(f["cell"])] = f["area"]
	for a in areas.values():
		a.cells.clear()
	present = false
	Bus.lights_dirty.emit()
	return aboard
