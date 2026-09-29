class_name CIdCard extends Component
## Identification and access (tg: /obj/item/card/id).

var owner_name := ""
var assignment := ""
var access: Array = []

func key() -> StringName:
	return &"idcard"

func setup(p: Dictionary) -> CIdCard:
	owner_name = p.get("owner", owner_name)
	assignment = p.get("job", assignment)
	access = p.get("access", access).duplicate()
	return self

func examine(_user: Entity, lines: Array) -> void:
	if owner_name != "":
		lines.append("It reads: [b]%s[/b], %s." % [owner_name, assignment])

func ai_tags(out: Dictionary) -> void:
	out["id"] = true
