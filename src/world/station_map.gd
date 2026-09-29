class_name StationMap extends RefCounted
## The tile grid: turfs, tile structures (windows/grilles/girders), areas, cables and
## pipe masks, plus blocker counters maintained by dense entities (doors, machines).
## Pure data + queries; rendering and simulation live elsewhere.

var w: int
var h: int
var turf: PackedByteArray
var variant: PackedByteArray
var turf_hp: PackedFloat32Array
var structure: PackedByteArray
var struct_hp: PackedFloat32Array
var area: PackedInt32Array
var cable: PackedByteArray # 0 none, 1 intact, 2 damaged
var pipe_layers: Array = [] # Array[PackedByteArray] of NESW masks, one per PipeNet layer
var pipe_hp: Dictionary = {} # (layer * w*h + idx) -> hp; absent = 100
## tg lets several pipes share a tile on one layer as long as they use different sides
## (crossings, bridge pipes, a hidden and a visible run side by side). Such tiles keep
## each pipe's own mask here; pipe_layers holds the union for drawing and quick checks.
var pipe_groups: Array = [] # per layer: idx -> Array[int]
var pipe_color := {} # (layer * w*h + idx) -> Color: tg pipe_color; absent = the layer's own
var pipe_shown := {} # (layer * w*h + idx) -> true: a tg "visible" pipe, drawn over the floor
var pipe_links := {} # idx -> true: tg layer adaptor, joins every layer's pipe on the tile
var initial_air := {} # idx -> PackedFloat32Array of moles per gas: tiles that start with their own gas (tg ATMOS_TANK_*)
var dense_count: PackedByteArray
var floor_decals := {} # Vector2i -> "hazard" / "rug_red"... (painted floor markings, drawn by TerrainChunk)
var floor_grime := {} # Vector2i -> grime variant 0-3 (dirt on well-used floors)
var air_block_count: PackedByteArray
var opaque_count: PackedByteArray
var areas: Array = [] # Array[Area]
var evac_lounge: Area = null # Departure Lounge next to the dock
var pod_docks: Array = [] # [{cell, dir}]: escape pods docked outside airlocks
var supply_dock: Dictionary = {} # {cell, dir}: where the supply crawler parks (outside the Cargo Airlock)
var evac_dock: Dictionary = {} # {cell, dir}: where the evacuation crawler parks (outside the Departures Airlock)

const PIPE_LAYER_COUNT := 6
enum { PL_SUPPLY, PL_SCRUB, PL_HOT, PL_COLD, PL_GEN, PL_AUX }
const PIPE_LAYER_NAMES := ["supply", "scrub", "hot", "cold", "gen", "aux"]
## The tg piping layer each of ours is drawn on (tg: supply 4, scrubbers 2, general 3).
## A pipe's sprite is shifted (3 - layer) * 3 px, so different layers sit side by side.
const PIPE_TG_LAYER := [4, 2, 4, 2, 3, 5]

func _init(width: int, height: int) -> void:
	w = width
	h = height
	var n := w * h
	turf = PackedByteArray(); turf.resize(n)
	variant = PackedByteArray(); variant.resize(n)
	turf_hp = PackedFloat32Array(); turf_hp.resize(n)
	structure = PackedByteArray(); structure.resize(n)
	struct_hp = PackedFloat32Array(); struct_hp.resize(n)
	area = PackedInt32Array(); area.resize(n)
	area.fill(0)
	cable = PackedByteArray(); cable.resize(n)
	dense_count = PackedByteArray(); dense_count.resize(n)
	air_block_count = PackedByteArray(); air_block_count.resize(n)
	opaque_count = PackedByteArray(); opaque_count.resize(n)
	for i in PIPE_LAYER_COUNT:
		var p := PackedByteArray(); p.resize(n)
		pipe_layers.append(p)
		pipe_groups.append({})
	var outside := Area.new()
	outside.id = 0
	outside.name = "Glacier Surface"
	outside.outdoor = true
	areas.append(outside)

# ------------------------------------------------------------------ indexing
func idx(c: Vector2i) -> int:
	return c.y * w + c.x

func cell_of(i: int) -> Vector2i:
	return Vector2i(i % w, i / w)

func inb(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h

# ------------------------------------------------------------------ turf queries
func get_turf(c: Vector2i) -> int:
	return turf[idx(c)] if inb(c) else Defs.T_ROCK

func tflags(c: Vector2i) -> int:
	return Defs.TURFS[get_turf(c)]["flags"]

func is_solid_turf(c: Vector2i) -> bool:
	return (tflags(c) & Defs.F_SOLID) != 0

func is_wall(c: Vector2i) -> bool:
	return (tflags(c) & Defs.F_WALL) != 0

func is_rock(c: Vector2i) -> bool:
	return (tflags(c) & Defs.F_ROCK) != 0

func is_outdoor(c: Vector2i) -> bool:
	## Outdoor tiles are open to the asteroid's atmosphere (an infinite reservoir).
	return inb(c) and (tflags(c) & Defs.F_OUTDOOR) != 0

func has_floor_tile(c: Vector2i) -> bool:
	return (tflags(c) & Defs.F_FLOOR) != 0

func blocks_air(c: Vector2i) -> bool:
	if not inb(c):
		return true
	var i := idx(c)
	if (Defs.TURFS[turf[i]]["flags"] & Defs.F_SOLID) != 0:
		return true
	if Defs.is_window(structure[i]):
		return true
	return air_block_count[i] > 0

func is_opaque(c: Vector2i) -> bool:
	if not inb(c):
		return true
	var i := idx(c)
	if (Defs.TURFS[turf[i]]["flags"] & Defs.F_OPAQUE) != 0:
		return true
	return opaque_count[i] > 0

func is_passable(c: Vector2i) -> bool:
	## Static passability (ignores doors, which the mover handles by bumping).
	if not inb(c):
		return false
	var i := idx(c)
	if (Defs.TURFS[turf[i]]["flags"] & Defs.F_SOLID) != 0:
		return false
	if Defs.struct_dense(structure[i]):
		return false
	return dense_count[i] == 0

func blocks_move_static(c: Vector2i) -> bool:
	if not inb(c):
		return true
	var i := idx(c)
	return (Defs.TURFS[turf[i]]["flags"] & Defs.F_SOLID) != 0 or Defs.struct_dense(structure[i])

# ------------------------------------------------------------------ mutation
func set_turf(c: Vector2i, t: int, notify := true) -> void:
	if not inb(c):
		return
	var i := idx(c)
	var was_opaque := is_opaque(c)
	turf[i] = t
	var tv: int = Defs.TURFS[t]["var"]
	variant[i] = (absi(hash(c)) % tv) if tv > 1 else 0
	turf_hp[i] = float(Defs.TURFS[t].get("hp", 100))
	if notify:
		Bus.tile_changed.emit(c)
		if was_opaque != is_opaque(c):
			Bus.opacity_changed.emit(c)

func set_structure(c: Vector2i, s: int, notify := true) -> void:
	if not inb(c):
		return
	var i := idx(c)
	structure[i] = s
	struct_hp[i] = Defs.STRUCTS[s]["hp"]
	if notify:
		Bus.tile_changed.emit(c)

func add_blocker(c: Vector2i, dense: bool, air: bool, opaque: bool, sign: int) -> void:
	if not inb(c):
		return
	var i := idx(c)
	if dense:
		dense_count[i] = clampi(dense_count[i] + sign, 0, 255)
	if air:
		air_block_count[i] = clampi(air_block_count[i] + sign, 0, 255)
		if Game.atmos != null:
			Game.atmos.note_air_block(i) # heat-loss edge cache depends on what blocks air
	if opaque:
		opaque_count[i] = clampi(opaque_count[i] + sign, 0, 255)
		Bus.opacity_changed.emit(c)

# ------------------------------------------------------------------ areas
func area_at(c: Vector2i) -> Area:
	if not inb(c):
		return areas[0]
	return areas[area[idx(c)]]

func new_area(name: String, dept: String) -> Area:
	var a := Area.new()
	a.id = areas.size()
	a.name = name
	a.dept = dept
	areas.append(a)
	return a

func assign_area(c: Vector2i, a: Area) -> void:
	area[idx(c)] = a.id

# ------------------------------------------------------------------ pipes
func pipe_mask(layer: int, c: Vector2i) -> int:
	return pipe_layers[layer][idx(c)] if inb(c) else 0

func set_pipe_mask(layer: int, c: Vector2i, m: int) -> void:
	var i := idx(c)
	if pipe_groups[layer].has(i):
		# keep the other pipes; this changes whichever one the new mask overlaps
		var gs: Array = pipe_groups[layer][i]
		var old: int = pipe_layers[layer][i]
		var removed: int = old & ~m
		var out := []
		for g in gs:
			var ng: int = g & ~removed
			if ng != 0:
				out.append(ng)
		var added: int = m & ~old
		if added != 0:
			if out.is_empty():
				out.append(added)
			else:
				out[0] |= added
		set_pipe_groups(layer, c, out)
		return
	pipe_layers[layer][i] = m

func connect_pipe(layer: int, a: Vector2i, b: Vector2i) -> void:
	## Adds a pipe joint between neighbouring cells a and b.
	var d := b - a
	var da := Defs.DIRS4.find(d)
	var db := Defs.DIRS4.find(-d)
	if da < 0:
		return
	set_pipe_mask(layer, a, pipe_layers[layer][idx(a)] | (1 << da))
	set_pipe_mask(layer, b, pipe_layers[layer][idx(b)] | (1 << db))

## The separate pipes on a tile (each a NESW mask). Usually just the one.
func pipe_groups_at(layer: int, c: Vector2i) -> Array:
	if not inb(c):
		return []
	var i := idx(c)
	if pipe_groups[layer].has(i):
		return pipe_groups[layer][i]
	var m: int = pipe_layers[layer][i]
	return [m] if m != 0 else []

## Which of the tile's pipes uses side `d` (0-3), or -1.
func pipe_group_facing(layer: int, c: Vector2i, d: int) -> int:
	var gs := pipe_groups_at(layer, c)
	for g in gs.size():
		if gs[g] & (1 << d):
			return g
	return -1

func set_pipe_groups(layer: int, c: Vector2i, groups: Array) -> void:
	var i := idx(c)
	var m := 0
	for g in groups:
		m |= g
	pipe_layers[layer][i] = m
	if groups.size() > 1:
		pipe_groups[layer][i] = groups.duplicate()
	else:
		pipe_groups[layer].erase(i)

func pipe_key(layer: int, c: Vector2i) -> int:
	return layer * w * h + idx(c)

func pipe_hp_at(layer: int, c: Vector2i) -> float:
	return pipe_hp.get(layer * w * h + idx(c), 100.0)

func damage_pipe(layer: int, c: Vector2i, amount: float) -> void:
	var k := layer * w * h + idx(c)
	var hp: float = pipe_hp.get(k, 100.0)
	hp = maxf(0.0, hp - amount)
	pipe_hp[k] = hp
	Bus.tile_changed.emit(c)

func repair_pipe(layer: int, c: Vector2i) -> void:
	pipe_hp.erase(layer * w * h + idx(c))
	Bus.tile_changed.emit(c)

func pipe_leaking(layer: int, c: Vector2i) -> bool:
	return pipe_hp.get(layer * w * h + idx(c), 100.0) < 60.0

func damaged_pipes() -> Array:
	## [[layer, cell], ...] for pipes below full health
	var out := []
	var n := w * h
	for k in pipe_hp.keys():
		out.append([int(k) / n, cell_of(int(k) % n)])
	return out
