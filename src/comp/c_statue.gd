class_name CStatue extends Component
## TG petrification encloses the original body for eight minutes.
var occupant: Entity
var remaining := 480.0
var integrity := 200.0
var initial_integrity := 200.0

func key() -> StringName:
	return &"statue"

func enclose(body: Entity) -> void:
	occupant = body
	var h: CHealth = body.c(&"health")
	integrity = maxf(1.0, h.health() + 100.0)
	initial_integrity = integrity
	e.display_name = "statue of %s" % body.display_name
	body.set_meta("inside", e.id)
	body.set_meta("petrified", true)
	Traits.add_all(body, ["godmode", "mute", "noblood", "immobilized"], "petrification")
	var m: CMob = body.c(&"mob")
	if m and m.doll:
		var image: Node2D = m.doll.duplicate()
		e.add_child(image)
		image.visible = true
		image.modulate = Color(0.55, 0.55, 0.58)
		m.doll.visible = false

func process(dt: float) -> void:
	remaining -= dt
	if remaining <= 0.0:
		e.destroy()

func take_damage(amount: float, _kind: String, _source: Entity) -> float:
	integrity -= amount
	if integrity <= 0.0:
		var body := occupant
		occupant = null
		if is_instance_valid(body) and not body.removed:
			Traits.remove_source(body, "petrification")
			body.remove_meta("inside")
			body.remove_meta("petrified")
			Organs.remove(body.c(&"health"), "brain", e.cell)
			GeneFx.dust(body)
		e.destroy()
	return 0.0

func on_removed() -> void:
	if not is_instance_valid(occupant) or occupant.removed:
		return
	var body := occupant
	occupant = null
	Traits.remove_source(body, "petrification")
	body.remove_meta("inside")
	body.remove_meta("petrified")
	body.place(e.cell)
	var m: CMob = body.c(&"mob")
	if m and m.doll:
		m.doll.visible = true
	var h: CHealth = body.c(&"health")
	h.adjust("brute", maxf(0.0, initial_integrity - integrity))
	h.set_status_if_lower("paralyzed", 10.0)

func examine(_user: Entity, lines: Array) -> void:
	lines.append("The stone will crumble in %d seconds. Integrity: %d." % [ceili(remaining), ceili(integrity)])
