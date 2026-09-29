class_name Navigator extends RefCounted
## Shared A* over the tile grid. Doors are walkable (agents bump them open); per-agent
## blocked cells (locked doors, known fires) are applied temporarily for each query.

var astar := AStarGrid2D.new()
var map: StationMap
var _dirty := {}

func setup(m: StationMap) -> void:
	map = m
	astar.region = Rect2i(0, 0, m.w, m.h)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in m.h:
		for x in m.w:
			_refresh(Vector2i(x, y))
	Bus.tile_changed.connect(_on_tile)
	Bus.entity_moved.connect(_on_moved)
	Bus.entity_removed.connect(_on_removed)

func _on_tile(c: Vector2i) -> void:
	_dirty[c] = true

func _on_moved(e: Entity, f: Vector2i, t: Vector2i) -> void:
	if e.has_c(&"blocker"):
		_dirty[f] = true
		_dirty[t] = true

func _on_removed(e: Entity) -> void:
	if e.has_c(&"blocker"):
		_dirty[e.cell] = true

func mark(c: Vector2i) -> void:
	_dirty[c] = true

func _refresh(c: Vector2i) -> void:
	if not map.inb(c):
		return
	var i := map.idx(c)
	var solid := map.blocks_move_static(c)
	if not solid and map.dense_count[i] > 0:
		solid = true
		for e in Game.at(c):
			if e.has_c(&"door"):
				solid = false
				break
	astar.set_point_solid(c, solid)
	var w := 1.0
	var fl := map.tflags(c)
	if fl & Defs.F_SLOW:
		w = 1.8
	if fl & Defs.F_OUTDOOR:
		w *= 1.3 # people prefer staying indoors
	astar.set_point_weight_scale(c, w)

func flush() -> void:
	for c in _dirty.keys():
		_refresh(c)
		for d in Defs.DIRS4:
			if map.inb(c + d):
				_refresh(c + d)
	_dirty.clear()

## Path from a to b (b may be solid if `adjacent` - then we stop next to it).
func path(a: Vector2i, b: Vector2i, adjacent := false, avoid: Array = []) -> Array:
	flush()
	if not map.inb(a) or not map.inb(b):
		return []
	var restore := []
	for c in avoid:
		if map.inb(c) and not astar.is_point_solid(c) and c != a and c != b:
			astar.set_point_solid(c, true)
			restore.append(c)
	var result := []
	if adjacent and absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1:
		for c in restore:
			astar.set_point_solid(c, false)
		return []
	var b_solid := astar.is_point_solid(b)
	var a_solid := astar.is_point_solid(a)
	if b_solid:
		astar.set_point_solid(b, false)
	if a_solid:
		astar.set_point_solid(a, false)
	result = Array(astar.get_id_path(a, b))
	if b_solid:
		astar.set_point_solid(b, true)
	if a_solid:
		astar.set_point_solid(a, true)
	if (adjacent or b_solid) and not result.is_empty():
		result.pop_back()
	for c in restore:
		astar.set_point_solid(c, false)
	if not result.is_empty() and result[0] == a:
		result = result.slice(1)
	return result

func reachable_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return (absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1) or not path(a, b, true).is_empty()
