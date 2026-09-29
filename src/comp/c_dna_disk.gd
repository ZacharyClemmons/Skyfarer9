class_name CDnaDisk extends Component
## tg /obj/item/disk/data: carries up to ten mutations and one genetic makeup between DNA
## consoles.

var mutations: Array = [] # Mutation
var genetic_makeup_buffer := {}
var max_mutations := 10
var read_only := false

func key() -> StringName:
	return &"dnadisk"

func setup(p: Dictionary) -> CDnaDisk:
	read_only = p.get("read_only", read_only)
	return self

func on_added() -> void:
	# tg: icon_state = "datadisk[rand(0,7)]"
	e.set_sprite("items", "datadisk%d" % (Game.rng.randi() % 8))

func attack_self(user: Entity) -> bool:
	read_only = not read_only
	Game.tell(user, "You flip the write-protect tab to %s." % ("protected" if read_only else "unprotected"))
	return true

func examine(_user: Entity, lines: Array) -> void:
	lines.append("The write-protect tab is set to %s." % ("protected" if read_only else "unprotected"))
	if not mutations.is_empty():
		lines.append("It holds %d mutation%s." % [mutations.size(), "" if mutations.size() == 1 else "s"])
	if not genetic_makeup_buffer.is_empty():
		lines.append("It holds the genetic makeup of \"%s\"." % genetic_makeup_buffer.get("name", "?"))
