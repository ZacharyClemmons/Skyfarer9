class_name CStockPart extends Component
const NAMES := {"micro_laser": "micro-laser", "matter_bin": "matter bin", "scanning_module": "scanning module"}
var kind := "micro_laser"
var tier := 1

func key() -> StringName:
	return &"stockpart"

func setup(p: Dictionary) -> CStockPart:
	kind = p.get("kind", kind)
	tier = clampi(int(p.get("tier", tier)), 1, 4)
	return self

func on_added() -> void:
	e.display_name = "T%d %s" % [tier, NAMES.get(kind, kind)]

func examine(_user: Entity, lines: Array) -> void:
	lines.append("A tier %d machine component. Open an empty scanner's service panel with a screwdriver to install it." % tier)

static func spawn_part(kind: String, tier: int, cell: Vector2i) -> Entity:
	return Proto.spawn("stock_part", cell, {"comps": {"stockpart": {"kind": kind, "tier": tier}}})
