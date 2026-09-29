class_name CPipeFitting extends Component
## tg /obj/item/pipe (smart pipe): a loose fitting. Use it in hand to switch layer; put it
## on plating and wrench it to join the pipes next to it (PipeWork.install).

var layer := StationMap.PL_SUPPLY

func key() -> StringName:
	return &"pipefitting"

func setup(p: Dictionary) -> CPipeFitting:
	layer = p.get("layer", layer)
	return self

func on_added() -> void:
	_apply()

func _apply() -> void:
	e.display_name = "%s pipe fitting" % PipeWork.LAYER_NAMES[layer]
	e.set_sprite("items", "pipe_item_%s" % StationMap.PIPE_LAYER_NAMES[layer])
	var holder: Entity = e.holder
	if holder and holder.has_c(&"mob"):
		holder.c(&"mob").refresh_doll()

## Supply and scrubber are the layers crew lay; the reactor loops are engineering's.
func cycle(user: Entity) -> void:
	layer = StationMap.PL_SCRUB if layer == StationMap.PL_SUPPLY else StationMap.PL_SUPPLY
	_apply()
	Game.tell(user, "You set the fitting for the %s layer." % PipeWork.LAYER_NAMES[layer])
	Sfx.play("click", e.root_cell(), 0.5)

func attack_self(user: Entity) -> bool:
	cycle(user)
	return true

func attackby(user: Entity, item: Entity) -> bool:
	var it: CItem = item.c(&"item")
	if it and it.tool == "wrench":
		PipeWork.install(user, e)
		return true
	return false

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Switch layer", "cb": cycle.bind(user), "priority": 5})

func examine(_user: Entity, lines: Array) -> void:
	lines.append("It's set for the %s layer. Put it on bare plating next to a pipe and wrench it down." % PipeWork.LAYER_NAMES[layer])
