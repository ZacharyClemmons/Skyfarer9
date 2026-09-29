class_name CSurgeryTool extends Component
## A surgical instrument (tg /obj/item/scalpel and friends). See Surgery.

var kind := "scalpel"

func key() -> StringName:
	return &"surgerytool"

func setup(p: Dictionary) -> CSurgeryTool:
	kind = p.get("kind", kind)
	return self

func examine(_user: Entity, lines: Array) -> void:
	if kind == "drapes":
		lines.append("Use them on someone lying down to start an operation on the part you're aiming at.")
