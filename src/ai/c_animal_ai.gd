class_name CAnimalAI extends Component
## A transformed NPC retains a living, mobile body; player bodies use player controls.
var next_step := 0.0
func key() -> StringName: return &"animalai"
func process(_dt: float) -> void:
	if Game.time < next_step or e.c(&"health").dead: return
	next_step = Game.time + 2.0
	var offset: Vector2i = Defs.DIRS4[Game.rng.randi_range(0, 3)]
	e.c(&"mob").try_step(offset)
