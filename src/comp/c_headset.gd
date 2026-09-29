class_name CHeadset extends Component
## Radio headset worn on the ears. Channels follow tg's department radio setup.

var channels: Array = ["Common"]
var enabled := true

func key() -> StringName:
	return &"headset"

func setup(p: Dictionary) -> CHeadset:
	channels = p.get("channels", channels).duplicate()
	if not channels.has("Common"):
		channels.push_front("Common")
	return self

func examine(_user: Entity, lines: Array) -> void:
	var keys := []
	for ch in channels:
		for d in Defs.DEPARTMENTS.values():
			if d["radio"] == ch and d["key"] != "":
				keys.append(":%s %s" % [d["key"], ch])
	lines.append("Channels: ; Common" + (", " + ", ".join(keys) if not keys.is_empty() else ""))
