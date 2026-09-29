class_name CBlocker extends Component
## Makes an entity occupy its tile(s): blocks movement, air and/or sight.
## Keeps the StationMap blocker counters in sync as it moves or toggles.
## `footprint` lists extra cell offsets for multi-tile machines (reactor, TEG, sleeper).

var dense := true
var air := false
var opaque := false
var active := true
var footprint: Array = [Vector2i.ZERO]

func key() -> StringName:
	return &"blocker"

func setup(p: Dictionary) -> CBlocker:
	dense = p.get("dense", dense)
	air = p.get("air", air)
	opaque = p.get("opaque", opaque)
	if p.has("footprint"):
		footprint = []
		for o in p["footprint"]:
			footprint.append(Vector2i(o[0], o[1]))
	return self

func _apply(at: Vector2i, sign: int) -> void:
	for o in footprint:
		Game.map.add_blocker(at + o, dense, air, opaque, sign)

func cells() -> Array:
	var out := []
	for o in footprint:
		out.append(e.cell + o)
	return out

func on_added() -> void:
	if e.holder == null and active:
		_apply(e.cell, 1)

func on_removed() -> void:
	if e.holder == null and active:
		_apply(e.cell, -1)
		active = false

func on_moved(from: Vector2i, to: Vector2i) -> void:
	if active and from != to and e.holder == null:
		_apply(from, -1)
		_apply(to, 1)

func set_state(d: bool, a: bool, o: bool) -> void:
	if active:
		_apply(e.cell, -1)
	dense = d
	air = a
	opaque = o
	active = true
	_apply(e.cell, 1)
	if Game.atmos:
		for c in cells():
			Game.atmos.wake(c)
