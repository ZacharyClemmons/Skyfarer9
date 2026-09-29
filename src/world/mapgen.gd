class_name MapGen extends RefCounted
## Builds the station from the hand-designed map (tools/mapgen/station.py writes
## assets/data/station.json): tiles, areas, doors, windows, external airlocks and every
## placed object, laid out like a /tg/station map. Infrastructure (pipes, cables, lights,
## APCs, air alarms, vents, heaters) is still routed automatically, and the reactor loop
## and its radiators are built in the reactor chamber.
## Outside: a noise-generated glacier with rock ridges, ore, ice lakes and crystals.

const W := 176
const H := 128
const SX := 24 # station origin
const SY := 18
const SW := 128
const SH := 92
const MAP_FILE := "res://assets/data/station.json"

var map: StationMap
var rng := RandomNumberGenerator.new()
var rooms: Array = [] # {name, kind, dept, rect: Rect2i, area}
var halls: Array = []
var spawns := {} # room kind -> Array[Vector2i]
var wallmount_used := {}
var exits: Array = [] # outside cells next to external airlocks
var ext_airlocks: Array = []
var noise: FastNoiseLite
var noise2: FastNoiseLite

const ROOM_INFO := {
	"security_office": {"name": "Security Office", "floor": Defs.T_RED, "access": ["security"], "door": "sec"},
	"brig": {"name": "Brig", "floor": Defs.T_DARK, "access": ["brig"], "door": "sec"},
	"armory": {"name": "Armory", "floor": Defs.T_DARK, "access": ["armory"], "door": "sec"},
	"hos_office": {"name": "Head of Security's Office", "floor": Defs.T_CARPET, "access": ["armory"], "door": "sec"},
	"bridge": {"name": "Bridge", "floor": Defs.T_BLUE, "access": ["command"], "door": "cmd"},
	"captain_office": {"name": "Director's Office", "floor": Defs.T_BLUECARPET, "access": ["captain"], "door": "cmd"},
	"hop_office": {"name": "Personnel Office", "floor": Defs.T_BLUECARPET, "access": ["hop"], "door": "cmd"},
	"server_room": {"name": "Server Room", "floor": Defs.T_DARK, "access": ["research"], "door": "sci"},
	"vault": {"name": "Vault", "floor": Defs.T_DARK, "access": ["captain"], "door": "cmd"},
	"eva_storage": {"name": "EVA Storage", "floor": Defs.T_DARK, "access": [], "door": "generic"},
	"dormitories": {"name": "Dormitories", "floor": Defs.T_WOOD, "access": [], "door": "generic"},
	"restroom": {"name": "Restrooms", "floor": Defs.T_FREEZER, "access": [], "door": "generic"},
	"lounge": {"name": "Crew Lounge", "floor": Defs.T_CARPET, "access": [], "door": "generic"},
	"research_lab": {"name": "Research Lab", "floor": Defs.T_WHITE, "access": ["science"], "door": "sci"},
	"xenochem": {"name": "Xenochemistry", "floor": Defs.T_PURPLE, "access": ["research"], "door": "sci"},
	"rd_office": {"name": "RD's Office", "floor": Defs.T_PURPLE, "access": ["rd"], "door": "sci"},
	"science_storage": {"name": "Science Storage", "floor": Defs.T_DARK, "access": ["science"], "door": "sci"},
	"cafeteria": {"name": "Cafeteria", "floor": Defs.T_CAFE, "access": [], "door": "srv"},
	"bar": {"name": "Bar", "floor": Defs.T_WOOD, "access": ["bar"], "door": "srv"},
	"kitchen": {"name": "Kitchen", "floor": Defs.T_FREEZER, "access": ["kitchen"], "door": "srv"},
	"hydroponics": {"name": "Hydroponics", "floor": Defs.T_GREEN, "access": ["hydro"], "door": "srv"},
	"treatment": {"name": "Medbay Treatment", "floor": Defs.T_TEALMED, "access": ["medical"], "door": "med"},
	"medbay_lobby": {"name": "Medbay Lobby", "floor": Defs.T_WHITE, "access": [], "door": "med"},
	"chemistry": {"name": "Chemistry", "floor": Defs.T_WHITE, "access": ["chemistry"], "door": "med"},
	"cmo_office": {"name": "CMO's Office", "floor": Defs.T_TEALMED, "access": ["medical"], "door": "med"},
	"morgue": {"name": "Morgue", "floor": Defs.T_DARK, "access": ["medical"], "door": "med"},
	"genetics": {"name": "Genetics", "floor": Defs.T_WHITE, "access": ["genetics"], "door": "med"},
	"monkey_pen": {"name": "Monkey Pen", "floor": Defs.T_GREEN, "access": ["genetics"], "door": "med"},
	"cargo_bay": {"name": "Cargo Bay", "floor": Defs.T_YELLOW, "access": ["supply"], "door": "cargo"},
	"warehouse": {"name": "Cargo Warehouse", "floor": Defs.T_DARK, "access": ["supply"], "door": "cargo"},
	"mining_dock": {"name": "Mining Dock", "floor": Defs.T_DARK, "access": ["mining"], "door": "cargo"},
	"qm_office": {"name": "Quartermaster's Office", "floor": Defs.T_YELLOW, "access": ["qm"], "door": "cargo"},
	"reactor": {"name": "Reactor Chamber", "floor": Defs.T_GRATE, "access": ["engine"], "door": "eng"},
	"engineering": {"name": "Engineering", "floor": Defs.T_YELLOW, "access": ["engineering"], "door": "eng"},
	"power_storage": {"name": "Power Storage", "floor": Defs.T_DARK, "access": ["engine"], "door": "eng"},
	"ce_office": {"name": "CE's Office", "floor": Defs.T_YELLOW, "access": ["engineering"], "door": "eng"},
	"atmospherics": {"name": "Atmospherics", "floor": Defs.T_DARK, "access": ["atmos"], "door": "eng"},
	"gas_chamber": {"name": "Gas Chamber", "floor": Defs.T_ENGINE, "access": ["atmos"], "door": "eng"},
	"tool_storage": {"name": "Tool Storage", "floor": Defs.T_STEEL, "access": [], "door": "generic"},
	"custodial": {"name": "Custodial Closet", "floor": Defs.T_PLATING, "access": ["janitor"], "door": "maint"},
	"maint_storage": {"name": "Maintenance", "floor": Defs.T_PLATING, "access": ["maint"], "door": "maint"},
	"hall": {"name": "Hallway", "floor": Defs.T_STEEL, "access": [], "door": "generic"},
	"departures": {"name": "Departure Lounge", "floor": Defs.T_BLUE, "access": [], "door": "generic"},
	"airlock": {"name": "Airlock", "floor": Defs.T_DARK, "access": [], "door": "ext"},
}

const FLOORS := {"steel": Defs.T_STEEL, "white": Defs.T_WHITE, "dark": Defs.T_DARK, "blue": Defs.T_BLUE, "red": Defs.T_RED,
	"yellow": Defs.T_YELLOW, "purple": Defs.T_PURPLE, "green": Defs.T_GREEN, "tealmed": Defs.T_TEALMED, "wood": Defs.T_WOOD,
	"freezer": Defs.T_FREEZER, "cafe": Defs.T_CAFE, "carpet": Defs.T_CARPET, "bluecarpet": Defs.T_BLUECARPET, "grate": Defs.T_GRATE,
	"plating": Defs.T_PLATING, "engine": Defs.T_ENGINE}
## tg atmos_mapping_helpers.dm ATMOS_TANK_*: moles per chamber tile, at 20°C.
## Order: O2, N2, CO2, plasma, N2O, water vapour, smoke.
const CHAMBER_GAS := {
	"n2": [0, 100000, 0, 0, 0, 0, 0],
	"o2": [100000, 0, 0, 0, 0, 0, 0],
	"co2": [0, 0, 50000, 0, 0, 0, 0],
	"plasma": [0, 0, 0, 70000, 0, 0, 0],
	"n2o": [0, 0, 0, 0, 6000, 0, 0],
	"h2o": [0, 0, 0, 0, 0, 100000, 0],
	"air": [2644, 10580, 0, 0, 0, 0, 0], # ATMOS_TANK_AIRMIX
	"": [0, 0, 0, 0, 0, 0, 0], # the mix chamber starts airless
}
const DOOR_DEPT := {"sec": "security", "cmd": "command", "sci": "science", "srv": "service", "med": "medical", "cargo": "supply", "eng": "engineering"}

func generate(seed_value: int) -> StationMap:
	rng.seed = seed_value
	map = StationMap.new(W, H)
	Game.map = map
	noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.035
	noise.fractal_octaves = 4
	noise2 = FastNoiseLite.new()
	noise2.seed = seed_value + 99
	noise2.frequency = 0.08
	_terrain()
	var data := _read_map()
	_atmos_data = data.get("atmos", {})
	_load_station(data)
	_ensure_connectivity()
	_collect_area_cells()
	_place_objects(data)
	_grime()
	_infrastructure()
	_finish_rooms()
	_departure_lounge()
	_exterior_props()
	_unblock_rooms()
	_tidy_layout()
	_tidy_walls()
	join_tables()
	_spread_on_tables()
	return map

func S(x: int, y: int) -> Vector2i:
	return Vector2i(SX + x, SY + y)

# ------------------------------------------------------------------ the station map
func _read_map() -> Dictionary:
	var f := FileAccess.open(MAP_FILE, FileAccess.READ)
	if f == null:
		push_error("MapGen: can't read %s (run: py tools/mapgen/station.py)" % MAP_FILE)
		return {}
	return JSON.parse_string(f.get_as_text())

func _load_station(data: Dictionary) -> void:
	var tiles: Array = data["tiles"]
	var codes: Array = data["areas"]
	var legend: Dictionary = data["legend"]
	var area_of := {}
	var floor_of := {}
	for code in legend:
		var L: Dictionary = legend[code]
		var kind: String = L["kind"]
		var info: Dictionary = ROOM_INFO.get(kind, ROOM_INFO["hall"])
		var dept: String = DOOR_DEPT.get(info["door"], "civilian")
		if kind == "custodial":
			dept = "service"
		var a := map.new_area(L["name"], dept)
		a.restricted = info["access"].duplicate()
		a.room_kind = kind
		area_of[code] = a
		floor_of[code] = FLOORS.get(L.get("floor", ""), info["floor"])
	var cells_of := {} # code -> Array of floor cells
	var windows_at: Array = []
	for y in SH:
		var trow: String = tiles[y]
		var arow: String = codes[y]
		for x in SW:
			var ch := trow[x]
			var code := arow[x]
			var c := S(x, y)
			match ch:
				"%":
					map.set_turf(c, Defs.T_RWALL, false)
				"#":
					map.set_turf(c, Defs.T_WALL, false)
				"=":
					map.set_turf(c, Defs.T_PLATING, false)
					map.set_structure(c, Defs.S_WINDOW, false)
					windows_at.append(c)
				"W":
					map.set_turf(c, Defs.T_PLATING, false)
					map.set_structure(c, Defs.S_RWINDOW, false)
					windows_at.append(c)
				".", "+", "@":
					map.set_turf(c, floor_of[code], false)
					map.assign_area(c, area_of[code])
					if ch == "." and legend[code].has("gas"):
						var mixv: Array = CHAMBER_GAS.get(legend[code]["gas"], []).duplicate()
						mixv.resize(Defs.GAS_COUNT) # (the table lists the first gases; the rest are 0)
						for gi in Defs.GAS_COUNT:
							if mixv[gi] == null:
								mixv[gi] = 0.0
						map.initial_air[map.idx(c)] = PackedFloat32Array(mixv)
					if ch == ".":
						if not cells_of.has(code):
							cells_of[code] = []
						cells_of[code].append(c)
					else:
						_map_door(c, ch == "@", legend[code], area_of[code])
	# a window belongs to the room it looks out of (not the hall)
	for c in windows_at:
		# hull windows facing the ice are reinforced, as on tg stations; inner panes are plain
		for d in Defs.DIRS4:
			if map.is_outdoor(c + d):
				map.set_structure(c, Defs.S_RWINDOW, false)
				break
		var best: Area = null
		for d in Defs.DIRS4:
			var a := map.area_at(c + d)
			if a.id != 0 and (best == null or (best.room_kind in ["hall", "departures"] and not a.room_kind in ["hall", "departures"])):
				best = a
		if best:
			map.assign_area(c, best)
	# rooms and halls, as the rest of the game knows them
	for code in cells_of:
		var L: Dictionary = legend[code]
		var a: Area = area_of[code]
		var cs: Array = cells_of[code]
		var r := Rect2i(cs[0], Vector2i.ONE)
		for c in cs:
			r = r.expand(c)
		r.size += Vector2i.ONE
		a.center = r.get_center()
		if map.area_at(a.center) != a:
			a.center = cs[cs.size() / 2]
		match L["kind"]:
			"airlock":
				pass
			"hall", "departures":
				halls.append({"name": L["name"], "rect": r, "area": a})
				if L["kind"] == "departures":
					map.evac_lounge = a
			_:
				rooms.append({"name": L["name"], "kind": L["kind"], "dept": a.dept, "rect": r, "area": a})
	for ex in data["exits"]:
		_map_exit(ex)

func _map_door(c: Vector2i, external: bool, L: Dictionary, a: Area) -> void:
	var kind: String = L["kind"]
	if external:
		var ext_access: Array = ["external", "eva", "maint"]
		if L["name"] == "Mining Airlock":
			ext_access = ["mining", "external", "eva"]
		elif L["name"] == "Cargo Airlock":
			ext_access = ["supply", "mining", "external"]
		elif L["name"] in ["Departures Airlock", "West Airlock", "Southeast Airlock"]:
			ext_access = [] # public: the crawler / an escape pod is docked right outside
		_pending_doors.append({"cell": c, "dept": "ext", "access": ext_access, "ext": true})
		return
	var info: Dictionary = ROOM_INFO.get(kind, ROOM_INFO["hall"])
	_pending_doors.append({"cell": c, "dept": info["door"], "access": a.restricted.duplicate()})

func _map_exit(ex: Dictionary) -> void:
	var cell := S(int(ex["x"]), int(ex["y"]))
	var d := Vector2i(int(ex["dx"]), int(ex["dy"]))
	var side := Vector2i(d.y, d.x)
	var nm: String = ex["name"]
	# clear the snow in front of the airlock
	for k in 3:
		var oc := cell + d * k
		for s in [Vector2i.ZERO, side, -side]:
			if map.inb(oc + s) and (map.is_outdoor(oc + s) or map.is_rock(oc + s)):
				map.set_turf(oc + s, Defs.T_PACKED, false)
	exits.append({"cell": cell, "dir": d, "name": nm})
	if nm == "Departures Airlock":
		_evac_pad(cell, d)
	elif nm in ["West Airlock", "Southeast Airlock"]:
		_pod_pad(cell, d)
	elif nm == "Cargo Airlock":
		_supply_pad(cell, d)
	elif nm == "Mining Airlock":
		# a packed-snow trail out to the nearest rock
		var c := cell
		for k in 40:
			c += Vector2i(-1, 0) if rng.randf() < 0.75 else Defs.DIRS4[rng.randi() % 4]
			if not map.inb(c) or map.is_rock(c):
				break
			if map.is_outdoor(c):
				map.set_turf(c, Defs.T_PACKED, false)

## Map monkeys, spawned by Main once the systems are running.
var monkey_spawns: Array = []

func _place_objects(data: Dictionary) -> void:
	for o in data["objects"]:
		var c := S(int(o["x"]), int(o["y"]))
		var p: String = o["p"]
		var a := map.area_at(c)
		match p:
			"monkey":
				monkey_spawns.append(c) # tg /mob/living/carbon/human/species/monkey: spawned once the world is up
			"decal":
				var spr: String = o.get("spr", "")
				if spr == "hazard_stripe":
					map.floor_decals[c] = "hazard"
				elif spr.begins_with("rug_"):
					map.floor_decals[c] = spr
				elif spr == "puddle_oil":
					place("decal_oil", c)
				# department trim is drawn automatically along every wall
			"locker":
				var k: String = o.get("kind", "gen")
				var l := place("locker", c, {"spr": "locker_" + k, "comps": {"storage": {"spr": "locker_" + k, "spr_open": "locker_%s_open" % k, "access": a.restricted.duplicate()}}})
				_fill(l, o.get("items", []))
			"crate":
				var k2: String = o.get("kind", "gen")
				var cr := place("crate", c, {"spr": "crate_" + k2, "comps": {"storage": {"spr": "crate_" + k2, "spr_open": "crate_%s_open" % k2}}})
				_fill(cr, o.get("items", []))
			_:
				var ov := {}
				for k3 in ["spr", "name", "comps"]:
					if o.has(k3):
						ov[k3] = o[k3]
				var e := place(p, c, ov)
				if e.wall_mounted:
					wallmount_used[c] = true
				if o.has("items") and e.has_c(&"storage"):
					_fill(e, o["items"])

## Dirt: thick in maintenance, a little along hall walls and in the busy rooms.
func _grime() -> void:
	for a in map.areas:
		var p := 0.0
		match a.room_kind:
			"maint_storage": p = 0.45
			"hall", "departures": p = 0.07
			"cargo_bay", "warehouse", "mining_dock", "engineering", "reactor", "atmospherics", "custodial", "kitchen": p = 0.12
			_: p = 0.03
		for c in a.cells:
			var by_wall := false
			for d in Defs.DIRS4:
				if map.is_wall(c + d):
					by_wall = true
			if rng.randf() < (p * (1.6 if by_wall else 0.6)):
				map.floor_grime[c] = rng.randi() % 4

func _fill(container: Entity, items: Array) -> void:
	for it in items:
		container.c(&"storage").insert(Proto.spawn(it, container.cell))

## After the map's own furniture: each job's personal lockers, fire axe cabinets, and
## where the crew can start.
func _finish_rooms() -> void:
	for room in rooms:
		_job_lockers(room)
		if room["kind"] in ["bridge", "atmospherics"]:
			wall_mount(room["area"], "fireaxe_cabinet")
		spawns[room["kind"]] = spawns.get(room["kind"], [])
		for k in 6:
			var c := random_free(room)
			if c.x >= 0:
				spawns[room["kind"]].append(c)

# ------------------------------------------------------------------ exterior terrain
func _terrain() -> void:
	var cx := W / 2.0
	var cy := H / 2.0
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var n2 := noise2.get_noise_2d(x, y) * 0.5 + 0.5
			# distance from station footprint (keep a clear apron)
			var dx := maxf(0.0, maxf(SX - 8 - x, x - (SX + SW + 8)))
			var dy := maxf(0.0, maxf(SY - 8 - y, y - (SY + SH + 8)))
			var apron := sqrt(dx * dx + dy * dy)
			var edge := minf(minf(x, W - 1 - x), minf(y, H - 1 - y))
			var rockiness := n + clampf(1.0 - edge / 14.0, 0.0, 1.0) * 0.6 - 0.12
			var t := Defs.T_SNOW
			if apron > 3.0 and rockiness > 0.66:
				t = Defs.T_ROCK
			elif n2 > 0.68 and apron > 1.0:
				t = Defs.T_DEEPSNOW
			elif n < 0.3 and apron > 5.0:
				t = Defs.T_ICE
			elif rockiness > 0.6 and apron > 2.0:
				t = Defs.T_GRAVEL
			if edge < 2:
				t = Defs.T_ROCK
			map.set_turf(c, t, false)
	# ore veins inside rock
	for k in 70:
		var c := Vector2i(rng.randi_range(2, W - 3), rng.randi_range(2, H - 3))
		if map.get_turf(c) != Defs.T_ROCK:
			continue
		var ore: int = [Defs.T_ROCK_IRON, Defs.T_ROCK_IRON, Defs.T_ROCK_IRON, Defs.T_ROCK_PLASMA, Defs.T_ROCK_PLASMA, Defs.T_ROCK_CRYO, Defs.T_ROCK_GOLD][rng.randi() % 7]
		for s in rng.randi_range(3, 9):
			if map.get_turf(c) == Defs.T_ROCK:
				map.set_turf(c, ore, false)
			c += Defs.DIRS4[rng.randi() % 4]
			if not map.inb(c):
				break

# ------------------------------------------------------------------ station
func _is_hall(c: Vector2i) -> bool:
	var a := map.area_at(c)
	return a.id != 0 and a.name.contains("Hall")

var _pending_doors: Array = []
var _atmos_data := {} # station.json "atmos": the transcribed tg Atmospherics pipework
var _route_block := {} # cells utility pipe routing keeps out of (the imported machinery)
var _pipe_trunk := {} # layer -> {cell: true}: the loop a vent or scrubber may join

## Every room has to be reachable from the halls. _room_doors only looks at one spot per
## side and runs before later blocks exist, so two rooms can end up joined only to each
## other. Flood out from the halls and punch a door into each room left cut off, nearest
## a hall if possible, until nothing is.
func _ensure_connectivity() -> void:
	for pass_i in 30:
		var reached := _flood_from_halls()
		var fixed := false
		var cut_off := 0
		for room in rooms:
			if room["kind"] == "gas_chamber":
				continue # TG storage chambers are intentionally sealed, never add a door.
			if reached.has(room["rect"].get_center()) or _room_reached(room, reached):
				continue
			cut_off += 1
			var best := Vector2i(-1, -1)
			var best_score := -1.0
			var r: Rect2i = room["rect"]
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					var c := Vector2i(x, y)
					if map.area_at(c) != room["area"]:
						continue
					for d in Defs.DIRS4:
						var wc: Vector2i = c + d
						if map.get_turf(wc) != Defs.T_WALL or not reached.has(wc + d):
							continue
						# walls either side of the door, so it isn't in a corner
						var side := Vector2i(d.y, d.x)
						if not map.is_wall(wc + side) or not map.is_wall(wc - side):
							continue
						var score := 10.0 if _is_hall(wc + d) else 0.0
						score -= Vector2(c - r.get_center()).length() * 0.2
						if score > best_score:
							best_score = score
							best = wc
			if best.x < 0:
				continue
			var info: Dictionary = ROOM_INFO[room["kind"]]
			map.set_turf(best, info["floor"], false)
			map.assign_area(best, room["area"])
			_pending_doors.append({"cell": best, "dept": info["door"], "access": info["access"]})
			fixed = true
			# one door per pass: a cut-off neighbour may get reached through this one
			break
		if cut_off == 0:
			return
		if not fixed:
			push_warning("MapGen: %d rooms have no way in" % cut_off)
			return

func _room_reached(room: Dictionary, reached: Dictionary) -> bool:
	var r: Rect2i = room["rect"]
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if reached.has(Vector2i(x, y)):
				return true
	return false

func _flood_from_halls() -> Dictionary:
	var seen := {}
	var q: Array[Vector2i] = []
	for h in halls:
		var r: Rect2i = h["rect"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if not map.is_solid_turf(c) and not seen.has(c):
					seen[c] = true
					q.append(c)
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in Defs.DIRS4:
			var n: Vector2i = c + d
			if seen.has(n) or not map.inb(n) or map.is_solid_turf(n) or map.is_outdoor(n):
				continue
			if map.structure[map.idx(n)] != Defs.S_NONE:
				continue
			seen[n] = true
			q.append(n)
	return seen

## Debug (--mapcheck): rooms whose floor can't be walked to from the halls once furniture
## and machines are in, counting doors as open.
## Tiles someone can walk to from the halls once furniture and machines are in (doors count as open).
func _walk_flood() -> Dictionary:
	var start: Vector2i = halls[0]["rect"].get_center()
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in Defs.DIRS4:
			var n: Vector2i = c + d
			if seen.has(n) or not map.inb(n) or map.is_outdoor(n) or map.blocks_move_static(n):
				continue
			if map.dense_count[map.idx(n)] > 0 and not _has_door(n):
				continue
			seen[n] = true
			q.append(n)
	return seen

func _has_door(c: Vector2i) -> bool:
	for e in Game.at(c):
		if e.has_c(&"door"):
			return true
	return false

## Furniture can seal off part of a room: a sink across the only strip that leads to a
## door, or crates boxing in a corner. Find each sealed pocket and move one of the things
## walling it in to the far end of the pocket, which opens it up.
func _unblock_rooms() -> void:
	var given_up := {}
	for guard in 80:
		var seen := _walk_flood()
		var pocket_cell := Vector2i(-1, -1)
		for room in rooms:
			if room["kind"] == "gas_chamber":
				continue # Do not relocate equipment to open sealed gas tanks.
			for c in room["area"].cells:
				if map.dense_count[map.idx(c)] == 0 and not map.blocks_move_static(c) and not seen.has(c) and not given_up.has(c):
					pocket_cell = c
					break
			if pocket_cell.x >= 0:
				break
		if pocket_cell.x < 0:
			return
		# the pocket, and the movable blockers between it and the reachable part of the station
		var pocket := {pocket_cell: 0}
		var q: Array[Vector2i] = [pocket_cell]
		var walls_in: Array = []
		while not q.is_empty():
			var c: Vector2i = q.pop_front()
			for d in Defs.DIRS4:
				var n: Vector2i = c + d
				if pocket.has(n) or not map.inb(n) or map.is_outdoor(n) or map.blocks_move_static(n):
					continue
				if map.dense_count[map.idx(n)] > 0 and not _has_door(n):
					if not n in walls_in:
						walls_in.append(n)
					continue
				pocket[n] = pocket[c] + 1
				q.append(n)
		var moved := false
		for bc in walls_in:
			var opens := false
			for d in Defs.DIRS4:
				if seen.has(bc + d):
					opens = true
			if not opens:
				continue
			var mover: Entity = null
			for e in Game.at(bc):
				if e.has_c(&"blocker") and e.c(&"blocker").dense and e.c(&"blocker").footprint.size() == 1 and not e.has_c(&"door") and not e.wall_mounted:
					mover = e
			if mover == null:
				continue
			# the pocket cell farthest from the gap, and not in front of a door
			var target := Vector2i(-1, -1)
			var far := -1
			for pc in pocket:
				var dist := absi(pc.x - bc.x) + absi(pc.y - bc.y)
				if dist > far and not _door_adjacent(pc) and Game.at(pc).is_empty():
					far = dist
					target = pc
			if target.x < 0:
				mover.destroy()
			else:
				mover.place(target)
			moved = true
			break
		if not moved:
			moved = _clear_path(pocket, seen)
		if not moved:
			var what := []
			for bc in walls_in:
				for e in Game.at(bc):
					what.append("%s%s" % [e.proto, " (wall)" if e.wall_mounted else ""])
			push_warning("MapGen: can't open up a sealed pocket at %s (walled in by %s)" % [pocket_cell, what])
			for pc in pocket:
				given_up[pc] = true

## When a pocket is sealed behind more than one blocker (two crates stacked in a strip),
## find the shortest way out through movable furniture and clear everything on it into
## the far end of the pocket.
func _movable_blocker(c: Vector2i) -> Entity:
	for e in Game.at(c):
		if e.has_c(&"blocker") and e.c(&"blocker").dense and e.c(&"blocker").footprint.size() == 1 and not e.has_c(&"door") and not e.wall_mounted:
			return e
	return null

func _clear_path(pocket: Dictionary, seen: Dictionary) -> bool:
	var prev := {}
	var q: Array[Vector2i] = []
	for pc in pocket:
		prev[pc] = pc
		q.append(pc)
	var goal := Vector2i(-1, -1)
	while not q.is_empty() and goal.x < 0:
		var c: Vector2i = q.pop_front()
		for d in Defs.DIRS4:
			var n: Vector2i = c + d
			if prev.has(n) or not map.inb(n) or map.is_outdoor(n) or map.blocks_move_static(n):
				continue
			if seen.has(n):
				prev[n] = c
				goal = n
				break
			if map.dense_count[map.idx(n)] > 0 and not _has_door(n) and _movable_blocker(n) == null:
				continue
			prev[n] = c
			q.append(n)
	if goal.x < 0:
		return false
	var spots := pocket.keys().filter(func(pc): return not _door_adjacent(pc) and _movable_blocker(pc) == null)
	spots.sort_custom(func(a2, b2): return pocket[a2] > pocket[b2])
	var c2: Vector2i = prev[goal]
	var cleared := false
	while not pocket.has(c2):
		var e := _movable_blocker(c2)
		while e != null:
			if spots.is_empty():
				e.destroy()
			else:
				e.place(spots.pop_front())
			cleared = true
			e = _movable_blocker(c2)
		c2 = prev[c2]
	return cleared

## The colour a gas chamber's lamp is tinted, from the gas it holds (tg's canister colours).
static func chamber_tint(nm: String) -> Color:
	for k in CHAMBER_TINTS:
		if nm.begins_with(k):
			return CHAMBER_TINTS[k]
	return Color("#ffe0a8")

const CHAMBER_TINTS := {
	"Nitrogen": Color("#ff9a8a"), "Oxygen": Color("#8ac0ff"), "Carbon Dioxide": Color("#c8ccd8"),
	"Plasma": Color("#d88aff"), "Nitrous Oxide": Color("#fff0f4"), "Air Mix": Color("#d8ecff"),
	"Water Vapour": Color("#9ae0f0"), "Gas Mix": Color("#ffd89a"),
}

func unreachable_report() -> Array:
	var seen := _walk_flood()
	var out := []
	for room in rooms:
		if room["kind"] == "gas_chamber":
			continue # sealed on purpose (tg's tanks are only reached by breaking in)
		var total := 0
		var ok := 0
		for c in room["area"].cells:
			if map.dense_count[map.idx(c)] > 0:
				continue
			total += 1
			if seen.has(c):
				ok += 1
		if total > 0 and ok < total:
			out.append("%s: %d/%d floor tiles reachable" % [room["name"], ok, total])
			if OS.get_cmdline_user_args().has("--mapdump"):
				var r: Rect2i = room["rect"].grow(1)
				for y in range(r.position.y, r.end.y):
					var row := ""
					for x in range(r.position.x, r.end.x):
						var c := Vector2i(x, y)
						var ch := "#" if map.blocks_move_static(c) else ("." if seen.has(c) else "x")
						for e in Game.at(c):
							if e.has_c(&"door"):
								ch = "D"
						if ch != "#" and ch != "D" and map.dense_count[map.idx(c)] > 0:
							ch = "o"
						row += ch
					print(row)
				var names := {}
				for c in room["area"].cells:
					for e in Game.at(c):
						if map.dense_count[map.idx(c)] > 0 and not e.has_c(&"door"):
							names[e.proto_id if "proto_id" in e else e.display_name] = true
				print("dense: ", names.keys())
				var lost := []
				for c in room["area"].cells:
					if map.dense_count[map.idx(c)] == 0 and not seen.has(c):
						lost.append(c)
				print("rect ", room["rect"], " lost ", lost.slice(0, 20))
	return out

func _collect_area_cells() -> void:
	for a in map.areas:
		a.cells = []
	for i in map.w * map.h:
		var c := map.cell_of(i)
		if map.is_solid_turf(c) or map.structure[i] != Defs.S_NONE:
			continue
		var aid := map.area[i]
		if aid == 0 and not map.is_outdoor(c):
			continue
		if aid != 0:
			map.areas[aid].cells.append(c)

# ------------------------------------------------------------------ helpers for placement
func free_floor(c: Vector2i) -> bool:
	if not map.inb(c) or map.is_solid_turf(c) or map.structure[map.idx(c)] != Defs.S_NONE:
		return false
	if map.dense_count[map.idx(c)] > 0:
		return false
	for e in Game.at(c):
		if e.has_c(&"door") or e.has_c(&"blocker") or e.z_index >= 0 and e.has_c(&"furniture"):
			return false
	return true

func _door_adjacent(c: Vector2i) -> bool:
	for d in Defs.DIRS4:
		for e in Game.at(c + d):
			if e.has_c(&"door"):
				return true
	return false

## Floor cells along the inside of a room's walls. side: "n", "s", "e", "w", "any"
func wall_cells(room: Dictionary, side := "any") -> Array:
	var r: Rect2i = room["rect"]
	var out := []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if map.area_at(c) != room["area"]:
				continue
			var ok := false
			if (side == "n" or side == "any") and map.is_wall(c + Vector2i(0, -1)): ok = true
			if (side == "s" or side == "any") and map.is_wall(c + Vector2i(0, 1)): ok = true
			if (side == "w" or side == "any") and map.is_wall(c + Vector2i(-1, 0)): ok = true
			if (side == "e" or side == "any") and map.is_wall(c + Vector2i(1, 0)): ok = true
			if ok:
				out.append(c)
	return out

func place(proto: String, c: Vector2i, ov := {}) -> Entity:
	return Proto.spawn(proto, c, ov)

func place_along(room: Dictionary, proto: String, count: int, side := "n", ov := {}) -> Array:
	var cells := wall_cells(room, side)
	cells.shuffle()
	var out := []
	for c in cells:
		if out.size() >= count:
			break
		if free_floor(c) and not _door_adjacent(c):
			out.append(place(proto, c, ov))
	return out

func wall_mount(room_area: Area, proto: String, pref_cells: Array = []) -> Entity:
	var cells := pref_cells
	if cells.is_empty():
		for c in room_area.cells:
			if map.is_wall(c + Vector2i(0, -1)):
				cells.append(c)
	cells = cells.duplicate()
	cells.shuffle()
	for c in cells:
		if wallmount_used.has(c) or _door_adjacent(c):
			continue
		if not map.is_wall(c + Vector2i(0, -1)):
			continue
		wallmount_used[c] = true
		return place(proto, c)
	return null

func random_free(room: Dictionary, avoid_walls := false) -> Vector2i:
	var r: Rect2i = room["rect"]
	for k in 60:
		var c := Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))
		if map.area_at(c) != room["area"]:
			continue
		if avoid_walls and not wall_cells(room).is_empty() and c in wall_cells(room):
			continue
		if free_floor(c) and not _door_adjacent(c):
			return c
	return Vector2i(-1, -1)

func room_of(kind: String) -> Dictionary:
	for r in rooms:
		if r["kind"] == kind:
			return r
	return {}

# ------------------------------------------------------------------ infrastructure
func _infrastructure() -> void:
	# doors
	for d in _pending_doors:
		var e := Proto.spawn("airlock", d["cell"], {"comps": {"door": {"dept": d["dept"], "access": d["access"]}}})
		e.display_name = "%s airlock" % map.area_at(d["cell"]).name if d["dept"] != "ext" else "external airlock"
		if d.get("ext", false):
			ext_airlocks.append(e)
		elif not map.area_at(d["cell"]).room_kind in ["airlock"]:
			# tg: a firelock sits under every interior airlock
			place("firelock", d["cell"])
	_hall_firelocks()
	var all_areas: Array = []
	for room in rooms:
		all_areas.append(room["area"])
	for h in halls:
		all_areas.append(h["area"])
	for a in map.areas:
		if a.name == "Central Hall" or a.name.ends_with("Airlock"):
			all_areas.append(a)
	# APCs, air alarms, lights, heaters, vents & scrubbers
	var apcs := []
	var vents := []
	var scrubbers := []
	for a in all_areas:
		if a.room_kind == "gas_chamber":
			# tg's chambers are bare (no APC, alarm or vents), but a ceiling lamp tinted to
			# the gas lights each one evenly so you can see in through the gallery glass
			# and tell the tanks apart at a glance
			var lamp := place("ceiling_light", a.center)
			if lamp and lamp.c(&"light"):
				lamp.c(&"light").color = chamber_tint(a.name)
				lamp.c(&"light").energy = 1.25
				lamp.c(&"light").radius = 4.5
			continue
		var apc := wall_mount(a, "apc")
		if apc:
			apcs.append(apc)
		if a.cells.size() > 6:
			wall_mount(a, "air_alarm")
		if a.cells.size() > 6 and not a.outdoor:
			wall_mount(a, "fire_alarm")
		var nlights := maxi(1, a.cells.size() / 22)
		for k in nlights:
			wall_mount(a, "light_fixture" if a.dept != "medical" else "light_fixture_cold")
		wall_mount(a, "emergency_light")
		_ceiling_lights(a)
		# tg: every room has a light switch; halls and airlocks don't
		if a.cells.size() > 6 and not a.outdoor and not a.name.ends_with("Hall") and not a.name.ends_with("Airlock"):
			wall_mount(a, "light_switch")
		# space heaters wait in engineering and atmospherics for the next cold snap
		if a.name in ["Engineering", "Atmospherics", "Atmospherics Gas Storage"]:
			var hc := _free_cell_in(a)
			if hc.x >= 0:
				place("space_heater", hc)
		if a.cells.size() > 12:
			wall_mount(a, "ext_cabinet")
		# floor devices (Atmospherics brings its own from the tg map)
		var nv := maxi(1, a.cells.size() / 60)
		if not _atmos_data.is_empty() and a.room_kind == "atmospherics":
			nv = 0
		for k in nv:
			var vc := _free_cell_in(a)
			if vc.x >= 0:
				vents.append(place("vent", vc))
			var sc := _free_cell_in(a)
			if sc.x >= 0:
				scrubbers.append(place("scrubber", sc))
		var nh := maxi(1, a.cells.size() / 70)
		for k in nh:
			wall_mount(a, "heater")
	# tg's gas chambers are part of the Atmospherics area: their injectors and inlets run
	# off Atmospherics' APC
	var atmos_main: Area = null
	for a in all_areas:
		if a.name == "Atmospherics":
			atmos_main = a
	for a in all_areas:
		if a.room_kind == "gas_chamber" and atmos_main:
			a.power_parent = atmos_main
	# anything left without an APC (airlock chambers, corridors with no wall to hang
	# one on) runs off a neighbouring area's
	for a in all_areas:
		if a.apc != null or a.power_parent != null:
			continue
		for c in a.cells:
			for d in Defs.DIRS4:
				var nb := map.area_at(c + d * 2)
				if nb.id != 0 and nb != a and nb.apc != null:
					a.power_parent = nb
					break
			if a.power_parent:
				break
	# engineering core
	_engine_room()
	if _atmos_data.is_empty():
		_atmos_room()
	_tg_gear()
	# cables: SMES net to every APC
	# the grid grows out from the TEG: the SMES banks join it, then every APC.
	# (Portable generators in maintenance stay off the grid, as in tg, until someone
	# drags one onto a cable.)
	var roots := []
	for e in Game.all_with(&"powergen"):
		var pg: CPowerGen = e.c(&"powergen")
		if pg.kind == "teg":
			roots.push_front(e.cell)
		elif pg.kind == "smes":
			roots.append(e.cell)
	if not roots.is_empty():
		map.cable[map.idx(roots[0])] = 1
		for i in range(1, roots.size()):
			_route_cable(roots[i])
		for apc in apcs:
			_route_cable(apc.cell)
	# pipes: supply to vents, scrub from scrubbers
	var supply := Game.all_with(&"air_supply")
	if not _atmos_data.is_empty():
		_import_pipework()
		for v in vents:
			_route_pipe(StationMap.PL_SUPPLY, v.cell)
		for s2 in scrubbers:
			_route_pipe(StationMap.PL_SCRUB, s2.cell)
	elif not supply.is_empty():
		var root: Vector2i = supply[0].cell
		map.set_pipe_mask(StationMap.PL_SUPPLY, root, 0)
		_pipe_seed[StationMap.PL_SUPPLY] = [root]
		for v in vents:
			_route_pipe(StationMap.PL_SUPPLY, v.cell)
		var outl := Game.all_with(&"vent").filter(func(e): return e.c(&"vent").mode == "outlet")
		if not outl.is_empty():
			_pipe_seed[StationMap.PL_SCRUB] = [outl[0].cell]
			for s in scrubbers:
				_route_pipe(StationMap.PL_SCRUB, s.cell)
		_pipe_machines(root)

var _pipe_seed := {}

## tg table smoothing: each table picks the sprite that joins it to its neighbours of the
## same style, so rows and L-shapes read as one surface (a real bar top, a lab bench).
static func join_tables() -> void:
	var by_cell := {}
	for e in Game.all_with(&"furniture"):
		if e.c(&"furniture").kind == "table" and e.spr_name.begins_with("table_"):
			var style: String = e.spr_name.substr(6).split("_")[0]
			e.set_meta("table_style", style)
			by_cell[e.cell] = e
	for c in by_cell:
		var e: Entity = by_cell[c]
		var st: String = e.get_meta("table_style")
		var m := 0
		for i in 4:
			var n: Entity = by_cell.get(c + [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][i])
			if n and n.get_meta("table_style") == st:
				m |= 1 << i
		e.set_sprite("objects", "table_%s_%d" % [st, m])

## Several things on one table sit side by side, not stacked on one spot (tg maps nudge
## them with pixel_x/pixel_y).
const TABLE_SPOTS := [Vector2(-6, -4), Vector2(6, -2), Vector2(0, 2), Vector2(-7, 2), Vector2(7, -7)]

func _spread_on_tables() -> void:
	for t in Game.all_with(&"furniture"):
		if t.holder != null or not t.c(&"furniture").kind in ["table", "counter"]:
			continue
		var on: Array = Game.at(t.cell).filter(func(x): return x.has_c(&"item") and x.holder == null)
		if on.size() < 2:
			continue
		for i in on.size():
			on[i].set_pixel_offset(TABLE_SPOTS[i % TABLE_SPOTS.size()])

# ------------------------------------------------------------------ layout sanity
## Items that belong on the floor (or are floor clutter by design).
const FLOOR_ITEMS := ["bucket", "mop", "extinguisher", "debris", "glass_shard", "mouse_dead", "banana_peel",
	"ore_iron", "ore_plasma", "ore_cryo", "ore_gold", "ice_chunk", "riot_shield", "baseball_bat",
	"sheet_metal", "sheet_glass", "sheet_plasma", "sheet_plasteel", "sheet_wood"]

## Cells you walk through to use a door (either side of it, along its passage).
func _door_lanes() -> Dictionary:
	var out := {}
	for d in Game.all_with(&"door"):
		for ax in [Vector2i(1, 0), Vector2i(0, 1)]:
			var a: Vector2i = d.cell + ax
			var b: Vector2i = d.cell - ax
			if map.inb(a) and map.inb(b) and not map.is_solid_turf(a) and not map.is_solid_turf(b):
				out[a] = d
				out[b] = d
	return out

static func _is_obstacle(e: Entity) -> bool:
	return e.has_c(&"blocker") and e.c(&"blocker").dense and not e.has_c(&"door") and not e.has_c(&"mob") and not e.wall_mounted

func _is_loose(e: Entity) -> bool:
	if not e.has_c(&"item") or e.holder != null or e.proto in FLOOR_ITEMS:
		return false
	var a := map.area_at(e.cell)
	if a.outdoor or a.room_kind in ["maint_storage", "hall", "departures", "airlock", ""]:
		return false
	for o in Game.at(e.cell):
		if o.has_c(&"storage") or (o.has_c(&"furniture") and o.c(&"furniture").kind in ["table", "counter", "bed", "cabinet"]) or o.has_c(&"vending"):
			return false
	return true

## ROADMAP layout sanity: doorways stay clear, and items sit on tables rather than loose
## in the middle of a room.
func _tidy_layout() -> void:
	var lanes := _door_lanes()
	for c in lanes:
		for e in Game.at(c).duplicate():
			if _is_obstacle(e):
				var to := _nearest_clear(c, map.area_at(c), lanes)
				if to.x >= 0:
					e.place(to)
	var tables := {} # area id -> [cells]
	for e in Game.all_with(&"furniture"):
		if e.holder == null and e.c(&"furniture").kind in ["table", "counter"]:
			var aid: int = map.area[map.idx(e.cell)]
			if not tables.has(aid):
				tables[aid] = []
			tables[aid].append(e.cell)
	for e in Game.all_with(&"item").duplicate():
		if not _is_loose(e):
			continue
		var cand: Array = tables.get(map.area[map.idx(e.cell)], [])
		var best := Vector2i(-1, -1)
		var bd := 1 << 30
		for tc in cand:
			var n := Game.at(tc).filter(func(x): return x.has_c(&"item")).size()
			var d: int = (tc - e.cell).length_squared()
			if n < 3 and d < bd:
				bd = d
				best = tc
		if best.x >= 0:
			e.place(best)
			continue
		# no table with room: put it away in a locker or crate in the same room
		for st in Game.all_with(&"storage"):
			if st.holder == null and st.c(&"storage").kind == "closet" and map.area_at(st.cell) == map.area_at(e.cell) and st.c(&"storage").insert(e):
				break

func _move_safely(o: Entity, a: Area, lanes: Dictionary) -> void:
	var home := o.cell
	var tried := {}
	for attempt in 12:
		var to := _nearest_clear(home, a, lanes, tried)
		if to.x < 0:
			break
		tried[to] = true
		o.place(to)
		if _room_connected(a):
			return
	o.place(home)

## Every walkable tile in the room can be reached from its doors.
func _room_connected(a: Area) -> bool:
	var start := Vector2i(-1, -1)
	var total := 0
	for c in a.cells:
		if map.is_passable(c):
			total += 1
			if start.x < 0 and _door_adjacent(c):
				start = c
	if start.x < 0:
		return true
	var seen := {start: true}
	var q: Array = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in Defs.DIRS4:
			var n: Vector2i = c + d
			if not seen.has(n) and map.inb(n) and map.area_at(n) == a and map.is_passable(n):
				seen[n] = true
				q.append(n)
	return seen.size() >= total

func _nearest_clear(from: Vector2i, a: Area, lanes: Dictionary, skip := {}) -> Vector2i:
	var seen := {from: true}
	var q: Array = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in Defs.DIRS4:
			var n: Vector2i = c + d
			if seen.has(n) or not map.inb(n) or map.area_at(n) != a or map.is_solid_turf(n):
				continue
			seen[n] = true
			q.append(n)
			if not lanes.has(n) and not skip.has(n) and free_floor(n) and not _door_adjacent(n) and Game.at(n).is_empty():
				return n
		if seen.size() > 200:
			break
	return Vector2i(-1, -1)

## For --mapcheck: what's still wrong after tidying.
func layout_report() -> Dictionary:
	var lanes := _door_lanes()
	var blocked := []
	for c in lanes:
		for e in Game.at(c):
			if _is_obstacle(e):
				blocked.append("%s at %s (%s)" % [e.proto, c, map.area_at(c).name])
	var loose := []
	for e in Game.all_with(&"item"):
		if _is_loose(e):
			loose.append("%s (%s)" % [e.proto, map.area_at(e.cell).name])
	var covered := []
	for v in Game.all_with(&"vent"):
		for e in Game.at(v.cell):
			# tg maps canisters onto their ports, and Atmospherics' own scrubbers under its tables
			if v.c(&"vent").mode == "port" and e.has_c(&"canister"):
				continue
			if not _atmos_data.is_empty() and map.area_at(v.cell).room_kind == "atmospherics":
				continue
			if e != v and _is_obstacle(e):
				covered.append("%s under %s (%s)" % [v.proto, e.proto, map.area_at(v.cell).name])
	for a in Game.all_with(&"apc"):
		for e in Game.at(a.cell):
			if e != a and e.spr and e.spr.region_rect.size.y > 34.0:
				covered.append("APC behind %s (%s)" % [e.proto, map.area_at(a.cell).name])
	return {"blocked": blocked, "loose": loose, "covered": covered}

## Wall fixtures (APCs, alarms, buttons, intercoms, signs) sit on the wall above their
## floor tile; anything tall on that tile (a locker, a vending machine) hides them, and two
## fixtures on one tile overlap. Slide the fixture along the wall to a clear spot.
func _tidy_walls() -> void:
	var important := []
	var decor := []
	for e in Game.entities.values():
		if e.wall_mounted and e.holder == null:
			(important if e.proto in WALL_PRIORITY else decor).append(e)
	var taken := {}
	# working fixtures first; decoration (signs, posters, clocks, boards) makes way for them
	for f in important:
		_seat_fixture(f, taken, true)
	for f in decor:
		if not _seat_fixture(f, taken, false):
			f.destroy() # no clear wall left for a poster: leave it off

## Slide a fixture along its wall (up to 6 tiles either way) to a clear spot.
func _seat_fixture(f: Entity, taken: Dictionary, over_decor: bool) -> bool:
	if _wall_spot_ok(f.cell, f, taken, over_decor):
		taken[f.cell] = true
		return true
	for k in range(1, 7):
		for sgn in [1, -1]:
			var c: Vector2i = f.cell + Vector2i(k * sgn, 0)
			if map.area_at(c) == map.area_at(f.cell) and map.is_wall(c + Vector2i(0, -1)) and not map.is_wall(c) and _wall_spot_ok(c, f, taken, over_decor):
				f.place(c)
				taken[c] = true
				return true
	if over_decor:
		# nowhere along the wall: the furniture in front of it moves instead, somewhere
		# that doesn't wall off part of the room
		var lanes := _door_lanes()
		var a := map.area_at(f.cell)
		for o in Game.at(f.cell).duplicate():
			if o != f and not o.wall_mounted and not o.has_c(&"item") and not o.has_c(&"mob") and not o.has_c(&"decal"):
				_move_safely(o, a, lanes)
	taken[f.cell] = true
	return false

const WALL_PRIORITY := ["apc", "air_alarm", "fire_alarm", "ext_cabinet", "light_fixture", "light_fixture_cold",
	"emergency_light", "heater", "intercom", "recharger", "med_cabinet", "status_display"]

func _wall_spot_ok(c: Vector2i, f: Entity, taken: Dictionary, over_decor := false) -> bool:
	if taken.has(c):
		return false
	for o in Game.at(c):
		if o == f or o.has_c(&"item") or o.has_c(&"mob") or o.has_c(&"decal"):
			continue
		if o.wall_mounted:
			if over_decor and not o.proto in WALL_PRIORITY:
				continue # decor gets moved afterwards
			return false
		# tall things (lockers, vendors, fridges, bookshelves) cover the wall face
		if o.spr and o.spr.region_rect.size.y > 34.0:
			return false
		if o.has_c(&"storage") and o.c(&"storage").kind == "closet":
			return false
		if o.has_c(&"vending"):
			return false
	return true

## tg kit around the station: rechargers in security and the armory's guns, the defib in
## treatment, a lighter and smokes at the bar, space cleaner in custodial, pens for the HoP.
func _tg_gear() -> void:
	var sets := {
		"security_office": [["recharger", "wall"], ["flash", "table"], ["pepperspray", "table"]],
		"armory": [["recharger", "wall"], ["laser_gun", "table"], ["laser_gun", "table"], ["egun", "table"], ["flashbang", "table"], ["flashbang", "table"], ["smoke_grenade", "table"], ["sunglasses", "table"]],
		"treatment": [["defib", "table"], ["recharger", "wall"], ["gauze", "table"], ["medipen", "table"]],
		"bar": [["lighter", "table"], ["cig_pack", "table"]],
		"custodial": [["spray_bottle", "table"]],
		"hop_office": [["pen", "table"], ["paper", "table"]],
		"lounge": [["cig_pack", "table"]],
	}
	for kind in sets:
		for r in rooms:
			if r["kind"] != kind:
				continue
			for pair in sets[kind]:
				if pair[1] == "wall":
					place_along(r, pair[0], 1, "n")
				else:
					var c := _table_cell(r)
					if c.x >= 0:
						place(pair[0], c)
			break

## A table in the room with nothing on it yet (else a free floor tile).
func _table_cell(room: Dictionary) -> Vector2i:
	var a: Area = room["area"]
	var cells := a.cells.duplicate()
	cells.shuffle()
	for c in cells:
		var table := false
		var busy := false
		for e in Game.at(c):
			if e.has_c(&"furniture") and e.c(&"furniture").kind in ["table", "counter"]:
				table = true
			elif e.has_c(&"item"):
				busy = true
		if table and not busy:
			return c
	var f := _free_cell_in(a)
	return f

## tg atmospherics: the air plant feeds the distro loop through a pressure pump, with a
## heater on the loop; the waste loop runs through a gas filter (plasma to a side port)
## and a manual valve before the exhaust.
func _pipe_machines(supply_root: Vector2i) -> void:
	var blocked := []
	for l in StationMap.PIPE_LAYER_COUNT:
		blocked.append({})
	var pump := _plant_pump(supply_root, blocked)
	if pump:
		# the heater sits beside the loop, just downstream of the pump
		var pm: CPipeMachine = pump.c(&"pipemachine")
		var start: Vector2i = pump.cell + pm.dir_out
		# then a freezer (off) further along, as tg's atmos has both thermomachines on distro
		var todo := ["thermo_heater", "thermo_freezer"]
		var used := []
		for c in _pipe_walk(StationMap.PL_SUPPLY, start, blocked, 24):
			if todo.is_empty():
				break
			if used.any(func(u): return absi(u.x - c.x) + absi(u.y - c.y) <= 1):
				continue
			for d in Defs.DIRS4:
				var hc: Vector2i = c + d
				if free_floor(hc) and Game.at(hc).is_empty() and not _door_adjacent(hc) and map.pipe_mask(StationMap.PL_SUPPLY, hc) == 0 and not used.any(func(u): return absi(u.x - hc.x) + absi(u.y - hc.y) <= 1):
					var th := place(todo.pop_front(), hc, {"comps": {"pipemachine": {"layer": StationMap.PL_SUPPLY}}})
					th.c(&"pipemachine").dir_in = c - hc
					map.connect_pipe(StationMap.PL_SUPPLY, hc, c) # tg: the thermomachine sits on a stub off the loop
					used.append(c)
					used.append(hc)
					break
	var outl := Game.all_with(&"vent").filter(func(e): return e.c(&"vent").mode == "outlet")
	if outl.is_empty():
		return
	var oc: Vector2i = outl[0].cell
	# the outlet is where the waste loop ends, so "in" is the side away from it
	var flt := _inline_machine(StationMap.PL_SCRUB, oc, "gas_filter", blocked, {"layer": StationMap.PL_SCRUB, "gas": Defs.G_PLASMA}, true, true)
	# the exhaust valve goes between the filter and the outlet (any cut there splits them)
	for c in _pipe_walk(StationMap.PL_SCRUB, oc, blocked, 60):
		if c == oc or not _straight(StationMap.PL_SCRUB, c) or not free_floor(c) or not Game.at_with(c, &"vent").is_empty() or _next_to_machine(StationMap.PL_SCRUB, c, blocked):
			continue
		blocked[StationMap.PL_SCRUB][c] = true
		var reach := {}
		for x in _pipe_walk(StationMap.PL_SCRUB, oc, blocked):
			reach[x] = true
		var m := map.pipe_mask(StationMap.PL_SCRUB, c)
		var d_sink := Vector2i.ZERO
		for d in 4:
			if m & (1 << d) and reach.has(c + Defs.DIRS4[d]):
				d_sink = Defs.DIRS4[d]
		var vv := place("manual_valve", c, {"comps": {"pipemachine": {"layer": StationMap.PL_SCRUB}}})
		vv.c(&"pipemachine").dir_in = -d_sink
		vv.c(&"pipemachine").dir_out = d_sink
		return
	# no room between them: just upstream of the filter instead (the loop is a tree, so
	# any cut splits it)
	if flt == null:
		return
	var fpm: CPipeMachine = flt.c(&"pipemachine")
	var up0: Vector2i = flt.cell + fpm.dir_in
	var prev := flt.cell
	for c in _pipe_walk(StationMap.PL_SCRUB, up0, blocked, 12):
		if _straight(StationMap.PL_SCRUB, c) and free_floor(c) and Game.at_with(c, &"vent").is_empty() and Game.at_with(c, &"pipemachine").is_empty() and not _next_to_machine(StationMap.PL_SCRUB, c, blocked):
			# downstream is the neighbour nearer the filter
			var best := Vector2i.ZERO
			var bd := 1 << 30
			var m := map.pipe_mask(StationMap.PL_SCRUB, c)
			for d in 4:
				if m & (1 << d):
					var n: Vector2i = c + Defs.DIRS4[d]
					var dist := absi(n.x - flt.cell.x) + absi(n.y - flt.cell.y)
					if dist < bd:
						bd = dist
						best = Defs.DIRS4[d]
			blocked[StationMap.PL_SCRUB][c] = true
			var v2 := place("manual_valve", c, {"comps": {"pipemachine": {"layer": StationMap.PL_SCRUB}}})
			v2.c(&"pipemachine").dir_in = -best
			v2.c(&"pipemachine").dir_out = best
			return
	if flt:
		var fm: CPipeMachine = flt.c(&"pipemachine")
		var sc: Vector2i = flt.cell + fm.dir_side
		var port := place("vent", sc, {"name": "filter port", "comps": {"vent": {"mode": "port", "layer": StationMap.PL_SCRUB}}})
		port.set_sprite("objects", "connector")
		port.remove_comp(&"machine")

## tg's distro: the air plant (mixer) fills a short stub of pipe at high pressure and a
## pressure pump feeds the distribution loop from it. The stub is laid out beside the
## plant: plant stub -> pump -> the loop at the plant's own cell.
func _plant_pump(root: Vector2i, blocked: Array) -> Entity:
	var sup: Array = Game.all_with(&"air_supply")
	if sup.is_empty():
		return null
	for d in Defs.DIRS4:
		var pc: Vector2i = root + d
		var sc: Vector2i = root + d * 2
		var ok := true
		for c in [pc, sc]:
			if not free_floor(c) or map.pipe_mask(StationMap.PL_SUPPLY, c) != 0 or not Game.at(c).filter(func(e): return e.has_c(&"blocker") and e.c(&"blocker").dense).is_empty():
				ok = false
		if not ok:
			continue
		map.connect_pipe(StationMap.PL_SUPPLY, root, pc)
		map.connect_pipe(StationMap.PL_SUPPLY, pc, sc)
		blocked[StationMap.PL_SUPPLY][pc] = true
		var e := place("pump", pc, {"comps": {"pipemachine": {"layer": StationMap.PL_SUPPLY, "target": 350.0}}})
		var pm: CPipeMachine = e.c(&"pipemachine")
		pm.dir_in = d
		pm.dir_out = -d
		var asup: CAirSupply = sup[0].c(&"air_supply")
		asup.target_kpa = 4500.0
		Game.pipes.set_device_offset(sup[0], StationMap.PL_SUPPLY, d * 2)
		# the mixer's holding tank
		Game.pipes.volume_bonus[StationMap.PL_SUPPLY][map.idx(sc)] = 2000.0
		Game.pipes.dirty = true
		return e
	return null

## A machine's ports need a plain pipe cell each, so two machines can't touch.
func _next_to_machine(layer: int, c: Vector2i, blocked: Array) -> bool:
	for d in Defs.DIRS4:
		if blocked[layer].has(c + d):
			return true
	return false

func _straight(layer: int, c: Vector2i) -> bool:
	var m := map.pipe_mask(layer, c)
	return m == 5 or m == 10 # N+S or E+W

## Pipe cells reachable from `start` along `layer`, nearest first, not crossing machines.
func _pipe_walk(layer: int, start: Vector2i, blocked: Array, limit := 9999) -> Array:
	var out := []
	var seen := {start: true}
	var q := [start]
	while not q.is_empty() and out.size() < limit:
		var c: Vector2i = q.pop_front()
		out.append(c)
		var m := map.pipe_mask(layer, c)
		for d in 4:
			if m & (1 << d) == 0:
				continue
			var n: Vector2i = c + Defs.DIRS4[d]
			if seen.has(n) or blocked[layer].has(n) or map.pipe_mask(layer, n) & (1 << ((d + 2) % 4)) == 0:
				continue
			seen[n] = true
			q.append(n)
	return out

## Build a machine into a straight stretch of pipe near `root` such that cutting the pipe
## there leaves the root side small (just the plant) and everything else downstream. With
## `side`, it also needs a free floor tile beside it for a side port.
func _inline_machine(layer: int, root: Vector2i, proto: String, blocked: Array, cfg := {}, side := false, root_is_sink := false) -> Entity:
	var total := _pipe_walk(layer, root, blocked).size()
	for c in _pipe_walk(layer, root, blocked, 60):
		if c == root:
			continue
		var m := map.pipe_mask(layer, c)
		var dirs := []
		for d in 4:
			if m & (1 << d):
				dirs.append(d)
		if dirs.size() != 2 or (dirs[0] + 2) % 4 != dirs[1]:
			continue
		if not free_floor(c) or not Game.at(c).filter(func(e): return e.has_c(&"blocker") and e.c(&"blocker").dense).is_empty():
			continue
		if not Game.at_with(c, &"pipemachine").is_empty() or not Game.at_with(c, &"vent").is_empty() or _next_to_machine(layer, c, blocked):
			continue
		blocked[layer][c] = true
		var up := _pipe_walk(layer, root, blocked).size()
		if up > (40 if side else 14) or total - up < 10:
			blocked[layer].erase(c)
			continue
		var side_c := Vector2i(-99, -99)
		if side:
			for d in [(dirs[0] + 1) % 4, (dirs[0] + 3) % 4]:
				var sc: Vector2i = c + Defs.DIRS4[d]
				if free_floor(sc) and Game.at(sc).filter(func(e): return e.has_c(&"blocker") and e.c(&"blocker").dense).is_empty() and map.pipe_mask(layer, sc) == 0:
					side_c = sc
					break
			if side_c.x == -99:
				blocked[layer].erase(c)
				continue
		# which way is upstream: the neighbour still connected to the root
		var reach := {}
		for x in _pipe_walk(layer, root, blocked):
			reach[x] = true
		var d_in: Vector2i = Defs.DIRS4[dirs[0]] if reach.has(c + Defs.DIRS4[dirs[0]]) else Defs.DIRS4[dirs[1]]
		var mc := cfg.duplicate()
		mc["layer"] = layer
		var e := place(proto, c, {"comps": {"pipemachine": mc}})
		var pm: CPipeMachine = e.c(&"pipemachine")
		if root_is_sink:
			d_in = -d_in
		pm.dir_in = d_in
		pm.dir_out = -d_in
		if side:
			map.connect_pipe(layer, c, side_c)
			pm.dir_side = side_c - c
		return e
	return null

func _ceiling_lights(a: Area) -> void:
	## Recessed ceiling panels on a regular grid (every 4 tiles across, 4 down, offset
	## from the room's corner) so rooms are evenly lit, the way tg maps space their lights.
	if a.cells.size() < 6:
		return
	var r := Rect2i(a.cells[0], Vector2i.ONE)
	for c in a.cells:
		r = r.expand(c)
	var cellset := {}
	for c in a.cells:
		cellset[c] = true
	var ox := r.position.x + 1 + (r.size.x % 4) / 2
	var oy := r.position.y + 1 + (r.size.y % 4) / 2
	var placed := 0
	for y in range(oy, r.end.y + 1, 4):
		for x in range(ox, r.end.x + 1, 4):
			var c := Vector2i(x, y)
			if cellset.has(c):
				place("ceiling_light", c)
				placed += 1
	if placed == 0:
		place("ceiling_light", a.cells[a.cells.size() / 2])

func _free_cell_in(a: Area) -> Vector2i:
	var cells := a.cells.duplicate()
	cells.shuffle()
	for c in cells:
		if free_floor(c) and not _door_adjacent(c) and Game.at(c).is_empty():
			return c
	return Vector2i(-1, -1)

func _heater_cell(a: Area) -> Vector2i:
	var cells := a.cells.duplicate()
	cells.shuffle()
	for c in cells:
		if not free_floor(c) or _door_adjacent(c) or not Game.at(c).is_empty():
			continue
		var walls := 0
		for d in Defs.DIRS4:
			if map.is_wall(c + d):
				walls += 1
		if walls >= 1 and not map.is_wall(c + Vector2i(0, -1)) or walls >= 2:
			return c
	return Vector2i(-1, -1)

func _route_cable(target: Vector2i) -> void:
	## Power runs down the middle of hallways and maintenance, onto the nearest cable.
	_route(target, "cable", func(c): return map.cable[map.idx(c)] == 1, func(a, _b): map.cable[map.idx(a)] = 1)
	map.cable[map.idx(target)] = 1

func _cable_connected_hint(c: Vector2i) -> bool:
	for d in Defs.DIRS4:
		if map.cable[map.idx(c + d)] == 1:
			return true
	return false

func _route_pipe(layer: int, target: Vector2i) -> void:
	## Distribution pipes run along the hallways in their own lane (supply by one wall,
	## scrubbers by the other), onto the nearest pipe of the same layer.
	var seeds: Array = _pipe_seed.get(layer, [])
	if seeds.is_empty():
		return
	if map.pipe_mask(layer, target) != 0:
		return # already on the run: routing again would close a loop
	if _pipe_trunk.has(layer):
		# joining tg's loops: only onto the distro / waste line itself, never onto some
		# other pipe that happens to share the layer
		var trunk: Dictionary = _pipe_trunk[layer]
		_route(target, "supply" if layer == StationMap.PL_SUPPLY else "scrub",
			func(c): return trunk.has(c),
			func(a, b):
				map.connect_pipe(layer, a, b)
				trunk[a] = true
				trunk[b] = true)
		return
	var seedset := {}
	for sd in seeds:
		seedset[sd] = true
	_route(target, "supply" if layer == StationMap.PL_SUPPLY else "scrub",
		func(c): return map.pipe_mask(layer, c) != 0 or seedset.has(c),
		func(a, b): map.connect_pipe(layer, a, b))

## MetaStation's Atmospherics pipework as tg_atmos_import.py wrote it: every pipe with its
## real connections, colour and visibility, the layer adaptors, and the devices on them.
## The station's supply and waste loops then grow out from where tg's distro and waste
## lines leave the block.
func _import_pipework() -> void:
	var at := _atmos_data
	for p in at["pipes"]:
		var c := S(int(p["x"]), int(p["y"]))
		var layer := int(p["layer"])
		var gs: Array = []
		for g in p["groups"]:
			gs.append(int(g))
		map.set_pipe_groups(layer, c, gs)
		var key := map.pipe_key(layer, c)
		if p["color"] != null:
			map.pipe_color[key] = Color(p["color"])
		if p["shown"]:
			map.pipe_shown[key] = true
		_route_block[c] = true
	for l in at["links"]:
		map.pipe_links[map.idx(S(int(l[0]), int(l[1])))] = {"axis": int(l[2]) if l.size() > 2 else 15}
	for d in at["devices"]:
		_import_device(d)
	_pipe_trunk = {StationMap.PL_SUPPLY: {}, StationMap.PL_SCRUB: {}}
	var joints := [] # [general-layer cell outside the block, the loop layer it joins]
	for ex in at["exits"]:
		var layer := int(ex["layer"])
		# tg_atmos_import traced each line through the rest of MetaStation: only the real
		# distro and waste loops join ours (not, say, the external air ports' feed)
		var tag: String = ex.get("loop", "")
		var loop := StationMap.PL_SUPPLY if tag == "distro" else (StationMap.PL_SCRUB if tag == "waste" else -1)
		if loop < 0:
			continue
		var c := S(int(ex["x"]), int(ex["y"]))
		var dv := _bit_vec(int(ex["dir"]))
		# out through the wall (tg runs pipes inside walls) to the first open floor
		var path := [c]
		var o: Vector2i = c + dv
		while map.inb(o) and map.is_solid_turf(o) and path.size() < 3:
			path.append(o)
			o += dv
		if not map.inb(o) or map.is_solid_turf(o) or map.is_outdoor(o) or _route_block.has(o) or map.area_at(o).id == 0:
			continue
		path.append(o)
		for k in range(1, path.size()):
			map.connect_pipe(layer, path[k - 1], path[k])
		if layer == loop:
			# tg's distro / waste line itself: the station's loop grows from here
			_pipe_trunk[loop][o] = true
			if not _pipe_seed.has(loop):
				_pipe_seed[loop] = []
			_pipe_seed[loop].append(o)
		else:
			# a supply- or waste-coloured line on another layer ("Air to Distro" feeds the
			# distro on tg's layer 3): in tg it meets a layer adaptor just past the block, so
			# one joins it to the loop here
			map.pipe_color[map.pipe_key(layer, o)] = Color("#3a7ad8" if loop == StationMap.PL_SUPPLY else "#d84a3a")
			map.pipe_links[map.idx(o)] = [layer, loop]
			joints.append([o, loop])
	# In tg every place the distro (or waste loop) leaves Atmospherics is one pipeline,
	# joined up out in the station. Join ours the same way before any vent routes in.
	for j in joints:
		if not _pipe_seed.has(j[1]):
			_pipe_seed[j[1]] = []
		_pipe_seed[j[1]].append(j[0])
	for loop in [StationMap.PL_SUPPLY, StationMap.PL_SCRUB]:
		var seeds: Array = _pipe_seed.get(loop, [])
		if seeds.is_empty():
			continue
		var trunk: Dictionary = _pipe_trunk[loop]
		trunk.clear()
		trunk[seeds[0]] = true
		for k in range(1, seeds.size()):
			var sd: Vector2i = seeds[k]
			if trunk.has(sd):
				continue
			_route(sd, "supply" if loop == StationMap.PL_SUPPLY else "scrub",
				func(c): return trunk.has(c),
				func(a, b):
					map.connect_pipe(loop, a, b)
					trunk[a] = true
					trunk[b] = true)
			trunk[sd] = true
	Game.pipes.dirty = true

static func _bit_vec(bit: int) -> Vector2i:
	for d in 4:
		if bit == 1 << d:
			return Defs.DIRS4[d]
	return Vector2i.ZERO

const _GAS_ID := {"o2": Defs.G_O2, "n2": Defs.G_N2, "co2": Defs.G_CO2, "plasma": Defs.G_PLASMA, "n2o": Defs.G_N2O, "h2o": Defs.G_H2O}

func _import_device(d: Dictionary) -> void:
	var c := S(int(d["x"]), int(d["y"]))
	var layer := int(d["layer"])
	var proto: String = d["proto"]
	var face := _bit_vec(int(d.get("dir", 4)))
	var e: Entity = null
	match proto:
		"pump", "volume_pump", "manual_valve", "gas_filter", "gas_mixer", "passive_gate", "pressure_valve":
			var cfg := {"layer": layer, "on": bool(d.get("on", false)), "display": d.get("name", "")}
			if d.has("target"):
				cfg["target"] = float(d["target"])
			if d.has("rate"):
				cfg["rate"] = float(d["rate"])
			if d.has("node1"):
				cfg["node1"] = float(d["node1"])
			if d.get("gas", "") != "":
				cfg["gas"] = _GAS_ID.get(d["gas"], -1)
			e = place(proto, c, {"comps": {"pipemachine": cfg}})
			if e == null:
				return
			var pm: CPipeMachine = e.c(&"pipemachine")
			pm.dir_in = _bit_vec(int(d.get("in", 0)))
			pm.dir_out = _bit_vec(int(d.get("out", 0)))
			pm.dir_side = _bit_vec(int(d.get("side", 0)))
			if d.get("name", "") != "":
				e.display_name = d["name"]
		"thermo_heater", "thermo_freezer":
			e = place(proto, c, {"comps": {"pipemachine": {"layer": layer, "on": bool(d.get("on", false))}}})
			if e:
				e.c(&"pipemachine").dir_in = face
		"vent", "scrubber":
			e = place(proto, c, {"comps": {"vent": {"layer": layer}}})
			if e:
				e.c(&"vent").face = face
		"gas_injector", "gas_siphon", "passive_vent", "connector_port":
			var vc := {"layer": layer, "on": bool(d.get("on", true)), "monitored": d.get("monitored", "")}
			if d.has("volume_rate"):
				vc["volume_rate"] = float(d["volume_rate"])
			if d.has("volume_l"):
				vc["volume_l"] = float(d["volume_l"])
			e = place(proto, c, {"comps": {"vent": vc}})
			if e:
				e.c(&"vent").face = face
			if e and proto == "connector_port":
				# tg: a canister mapped onto a port starts connected to it
				for can in Game.at(c):
					if can.has_c(&"canister"):
						can.c(&"canister").port = e
		"pipe_tank":
			e = place(proto, c)
			Game.pipes.volume_bonus[layer][map.idx(c)] = 2500.0 # tg: a 2500 L stationary tank
		"meter":
			e = place("meter", c, {"comps": {"meter": {"layer": layer}}})

## tg-style utility runs: a cheapest-path search from `target` to anything `reached`
## accepts, where hallways and maintenance are cheap, room floors are dear, each
## utility has a preferred lane in the hall, and joining an existing run is cheapest of
## all, so lines gather into neat parallel trunks. `lay(a, b)` joins each step.
func _route(target: Vector2i, lane: String, reached: Callable, lay: Callable) -> void:
	var dist := {target: 0}
	var prev := {}
	var buckets := {0: [target]}
	var d := 0
	var found := Vector2i(-1, -1)
	var guard := 0
	while found.x < 0 and guard < 200000:
		guard += 1
		if not buckets.has(d) or buckets[d].is_empty():
			buckets.erase(d)
			if buckets.is_empty():
				break
			d = buckets.keys().min()
			continue
		var c: Vector2i = buckets[d].pop_back()
		if dist.get(c, 1 << 30) < d:
			continue
		if c != target and reached.call(c):
			found = c
			break
		for dd in Defs.DIRS4:
			var n: Vector2i = c + dd
			if not map.inb(n) or map.is_solid_turf(n) or map.is_outdoor(n) or map.is_rock(n):
				continue
			if lane != "cable" and map.structure[map.idx(n)] != Defs.S_NONE:
				continue
			if lane != "cable" and _route_block.has(n) and not reached.call(n):
				continue
			var nd := d + _route_cost(n, lane, reached)
			# straight runs with right-angle turns, not staircases
			if prev.has(c) and n - c != c - prev[c]:
				nd += 5
			if nd < dist.get(n, 1 << 30):
				dist[n] = nd
				prev[n] = c
				if not buckets.has(nd):
					buckets[nd] = []
				buckets[nd].append(n)
	if found.x < 0:
		return
	var c2 := found
	while c2 != target:
		var p: Vector2i = prev[c2]
		lay.call(c2, p)
		c2 = p

func _route_cost(c: Vector2i, lane: String, reached: Callable) -> int:
	if reached.call(c):
		return 1
	var a := map.area_at(c)
	var open_space := a.id == 0 or a.room_kind in ["hall", "departures", "maint_storage", "airlock"] or not map.has_floor_tile(c)
	var cost := 3 if open_space else 14
	if not open_space:
		# inside rooms, keep to the walls
		for dd in Defs.DIRS4:
			if map.is_wall(c + dd):
				cost = 8
				break
	if open_space and a.room_kind != "maint_storage":
		# which lane of the hall this is
		var by_nw := map.is_wall(c + Vector2i(0, -1)) or map.is_wall(c + Vector2i(-1, 0))
		var by_se := map.is_wall(c + Vector2i(0, 1)) or map.is_wall(c + Vector2i(1, 0))
		var want := (lane == "supply" and by_nw and not by_se) or (lane == "scrub" and by_se and not by_nw) or (lane == "cable" and not by_nw and not by_se)
		cost += 0 if want else 3
	return cost

func _connect_path(layer: int, a: Vector2i, b: Vector2i, allow_walls := false) -> void:
	var prev := {a: a}
	var q := [a]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		if c == b:
			break
		for d in Defs.DIRS4:
			var nc: Vector2i = c + d
			if prev.has(nc) or not map.inb(nc):
				continue
			if not allow_walls and (map.is_solid_turf(nc) or map.structure[map.idx(nc)] != Defs.S_NONE) and nc != b:
				continue
			if map.is_rock(nc):
				continue
			prev[nc] = c
			q.append(nc)
	if not prev.has(b):
		return
	var c2 := b
	while c2 != a:
		var p: Vector2i = prev[c2]
		map.connect_pipe(layer, c2, p)
		c2 = p

func _engine_room() -> void:
	var room := room_of("reactor")
	if room.is_empty():
		return
	var r: Rect2i = room["rect"]
	var rc := Vector2i(r.position.x + r.size.x / 2 - 2, r.position.y + r.size.y / 2)
	var reactor := place("reactor", rc)
	var teg_c := rc + Vector2i(4, 0)
	var teg := place("teg", teg_c)
	# hot loop: reactor <-> TEG hot port, as a ring
	_connect_path(StationMap.PL_HOT, rc, teg_c)
	_connect_path(StationMap.PL_HOT, rc + Vector2i(0, 2), teg_c + Vector2i(0, 2))
	_connect_path(StationMap.PL_HOT, rc, rc + Vector2i(0, 2))
	_connect_path(StationMap.PL_HOT, teg_c, teg_c + Vector2i(0, 2))
	var port := place("vent", rc + Vector2i(-2, 2), {"name": "coolant port", "comps": {"vent": {"mode": "port"}}})
	port.set_sprite("objects", "connector")
	port.remove_comp(&"machine")
	_connect_path(StationMap.PL_HOT, rc + Vector2i(-2, 2), rc + Vector2i(0, 2))
	place("canister_n2", rc + Vector2i(-3, 2))
	place("canister_n2", rc + Vector2i(-3, 3))
	place("console", rc + Vector2i(0, 3), {"spr": "console_reactor", "comps": {"console": {"kind": "reactor"}}})
	# cold loop out through the hull to radiators in the snow
	var cold_start := teg_c + Vector2i(1, 0)
	var south_wall := Vector2i(cold_start.x, SY + SH - 1)
	# find the hull tile below
	var yy := cold_start.y
	while yy < H - 1 and not (map.get_turf(Vector2i(cold_start.x, yy)) == Defs.T_RWALL and map.is_outdoor(Vector2i(cold_start.x, yy + 1))):
		yy += 1
	south_wall = Vector2i(cold_start.x, yy)
	_connect_path(StationMap.PL_COLD, cold_start, south_wall, true)
	var rad_row := south_wall.y + 3
	var prev_c := south_wall
	for k in 8:
		var rcell := Vector2i(south_wall.x - 6 + k * 2, rad_row + (k % 2))
		if not map.inb(rcell):
			continue
		for yy2 in range(south_wall.y + 1, rad_row + 3):
			for xx in range(rcell.x - 1, rcell.x + 2):
				var cc := Vector2i(xx, yy2)
				if map.is_rock(cc) or map.get_turf(cc) == Defs.T_ICE or map.get_turf(cc) == Defs.T_DEEPSNOW:
					map.set_turf(cc, Defs.T_PACKED, false)
		place("radiator", rcell)
		_connect_path(StationMap.PL_COLD, prev_c, rcell, true)
		prev_c = rcell
	place("floodlight", Vector2i(south_wall.x - 8, rad_row + 1))
	place("floodlight", Vector2i(south_wall.x + 11, rad_row + 1))
	# power storage
	var ps := room_of("power_storage")
	if not ps.is_empty():
		var cells := place_along(ps, "smes", 2, "n")
		place_along(ps, "generator", 1, "s")
		var sc := random_free(ps)
		if sc.x >= 0:
			place("sheet_plasma", sc)
		# tie TEG to SMES
		for s in cells:
			map.cable[map.idx(s.cell)] = 1
		map.cable[map.idx(teg_c)] = 1
		if not cells.is_empty():
			_route_cable_between(teg_c, cells[0].cell)
			for s in cells:
				_route_cable_between(s.cell, cells[0].cell)
	else:
		map.cable[map.idx(teg_c)] = 1
		place("smes", rc + Vector2i(-3, -2))

func _route_cable_between(a: Vector2i, b: Vector2i) -> void:
	var prev := {a: a}
	var q := [a]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		if c == b:
			break
		for d in Defs.DIRS4:
			var nc: Vector2i = c + d
			if prev.has(nc) or not map.inb(nc) or map.is_solid_turf(nc) and nc != b or map.is_outdoor(nc):
				continue
			prev[nc] = c
			q.append(nc)
	if not prev.has(b):
		return
	var c2 := b
	while true:
		map.cable[map.idx(c2)] = 1
		if c2 == a:
			break
		c2 = prev[c2]

func _atmos_room() -> void:
	var room := room_of("atmospherics")
	if room.is_empty() or not Game.all_with(&"air_supply").is_empty():
		return # the map already has its air plant
	var c := random_free(room)
	if c.x < 0:
		return
	place("air_supply", c)
	var oc := random_free(room)
	if oc.x >= 0:
		place("outlet", oc)
	place_along(room, "canister_o2", 2, "e")
	place_along(room, "canister_air", 2, "e")
	place_along(room, "canister_n2", 1, "w")
	place_along(room, "canister_plasma", 1, "w")
	place_along(room, "console", 1, "n", {"spr": "console_atmos", "comps": {"console": {"kind": "atmos"}}})

# ------------------------------------------------------------------ furnishing
## The personal lockers of every job that starts in this room, one per job slot, named
## for the job and locked to its access (tg: "Station Engineer's locker").
func _job_lockers(room: Dictionary) -> void:
	for job in Jobs.START_ROOM:
		if Jobs.START_ROOM[job] != room["kind"] or not Jobs.LOCKERS.has(job):
			continue
		# only the first room of a kind gets them (there are two EVA storages, etc.)
		if room_of(room["kind"]) != room:
			continue
		var lk: Dictionary = Jobs.LOCKERS[job]
		var n := mini(int(Jobs.JOBS[job].get("slots", 1)), 3)
		var acc: Array = [lk["access"]] if lk["access"] != "" else []
		for side in ["n", "e", "w", "s"]:
			if n <= 0:
				break
			var ls := place_along(room, "locker", n, side, {"name": "%s's locker" % Jobs.title(job), "spr": "locker_" + lk["spr"],
				"comps": {"storage": {"spr": "locker_" + lk["spr"], "spr_open": "locker_%s_open" % lk["spr"], "access": acc}}})
			for l in ls:
				l.set_meta("job_locker", job)
				for it in lk["items"]:
					l.c(&"storage").insert(Proto.spawn(it, l.cell))
			n -= ls.size()

## Packed-snow pad outside the Departures Airlock where the evacuation crawler parks.
var _pad := {}

func _evac_pad(cell: Vector2i, d: Vector2i) -> void:
	map.evac_dock = {"cell": cell, "dir": d}
	var side := Vector2i(d.y, d.x)
	for u in range(0, Evac.U_MAX + 3):
		for v in range(Evac.V_MIN - 1, Evac.V_MAX + 2):
			var c := cell + d * u + side * v
			if not map.inb(c):
				continue
			_pad[c] = true
			if map.is_outdoor(c) or map.is_rock(c):
				map.set_turf(c, Defs.T_PACKED, false)

func _departure_lounge() -> void:
	var lounge: Area = map.evac_lounge
	if lounge == null:
		return
	# status displays where people look: the lounge, the bridge, the cafeteria, the crossroads
	wall_mount(lounge, "status_display")
	for a in map.areas:
		if a.name in ["Bridge", "Cafeteria", "Central Hall"]:
			wall_mount(a, "status_display")

## tg maps put firelocks across corridors wherever one hallway area meets another, so a
## breach or fire only takes out one stretch of hall.
func _hall_firelocks() -> void:
	var done := {}
	for h in halls:
		var a: Area = h["area"]
		for c in a.cells:
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var n: Vector2i = c + d
				if not map.inb(n) or map.is_solid_turf(n) or map.is_solid_turf(c):
					continue
				var b: Area = map.area_at(n)
				if b == a or b == null or b.id == 0 or not b.room_kind in ["hall", "departures"]:
					continue
				if done.has(n) or not Game.at(n).is_empty() or not Game.at(c).filter(func(x): return x.has_c(&"door")).is_empty():
					continue
				if Game.at(n).any(func(x): return x.has_c(&"door")):
					continue
				done[n] = true
				place("firelock", n)

## Packed snow where the supply crawler parks (tg's cargo shuttle dock).
func _supply_pad(cell: Vector2i, d: Vector2i) -> void:
	map.supply_dock = {"cell": cell, "dir": d}
	var side := Vector2i(d.y, d.x)
	for u in range(0, Cargo.LAYOUT[0].length() + 2):
		for v in range(-Cargo.V0 - 1, Cargo.LAYOUT.size() - Cargo.V0 + 1):
			var c := cell + d * u + side * v
			if map.inb(c):
				_pad[c] = true
				if map.is_outdoor(c) or map.is_rock(c):
					map.set_turf(c, Defs.T_PACKED, false)

func _pod_pad(cell: Vector2i, d: Vector2i) -> void:
	map.pod_docks.append({"cell": cell, "dir": d})
	var side := Vector2i(d.y, d.x)
	for u in range(0, Evac.POD[0].length() + 1):
		for v in range(-Evac.POD_V0 - 1, Evac.POD.size() - Evac.POD_V0 + 1):
			var c := cell + d * u + side * v
			if map.inb(c):
				_pad[c] = true
				if map.is_outdoor(c) or map.is_rock(c):
					map.set_turf(c, Defs.T_PACKED, false)

# ------------------------------------------------------------------ outside
func _exterior_props() -> void:
	for ex in exits:
		var c: Vector2i = ex["cell"]
		var d: Vector2i = ex["dir"]
		var side := Vector2i(d.y, d.x)
		var reach := 2
		if ex["name"] == "Departures Airlock":
			reach = Evac.V_MAX + 3
		elif ex["name"] in ["West Airlock", "Southeast Airlock"]:
			reach = Evac.POD_V0 + 2
		elif ex["name"] == "Cargo Airlock":
			reach = Cargo.V0 + 2
		for s in [side * reach, -side * reach]:
			var fc: Vector2i = c + d + s
			if map.inb(fc) and map.is_outdoor(fc) and Game.at(fc).is_empty():
				place("floodlight", fc)
				break
	# comms mast near the north airlock
	for ex in exits:
		if ex["name"] == "North Airlock":
			var ac: Vector2i = ex["cell"] + Vector2i(4, -3)
			if map.inb(ac) and map.is_outdoor(ac):
				place("antenna", ac)
	# scatter
	for k in 900:
		var c := Vector2i(rng.randi_range(2, W - 3), rng.randi_range(2, H - 3))
		if not map.is_outdoor(c) or not Game.at(c).is_empty() or _pad.has(c):
			continue
		var near_rock := false
		for d in Defs.DIRS8:
			if map.is_rock(c + d):
				near_rock = true
				break
		var near_station := c.x > SX - 3 and c.x < SX + SW + 3 and c.y > SY - 3 and c.y < SY + SH + 3
		if near_station:
			continue
		var roll := rng.randf()
		if near_rock and roll < 0.1:
			place("ice_crystal", c, {"spr": "ice_crystal_%d" % rng.randi_range(0, 2)})
		elif near_rock and roll < 0.25:
			place("boulder", c, {"spr": "boulder_%d" % rng.randi_range(0, 2)})
		elif roll < 0.035:
			place("lichen", c, {"spr": "lichen_%d" % rng.randi_range(0, 2)})
		elif roll < 0.052 and map.get_turf(c) in [Defs.T_SNOW, Defs.T_DEEPSNOW]:
			var dr := place("drift", c, {"spr": "drift_%d" % rng.randi_range(0, 3)})
			dr.modulate.a = 0.95
		elif roll < 0.087:
			place("boulder", c, {"spr": "boulder_%d" % rng.randi_range(0, 2)})
