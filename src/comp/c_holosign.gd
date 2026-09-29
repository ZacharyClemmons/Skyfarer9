class_name CHolosign extends Component
## tg /obj/structure/holosign/barrier/atmos: a hologram that keeps gas in but lets people
## and things through. One integrity point: any hand or hit pops it. Clicking it with the
## projector that made it takes it down.

var projector: Entity = null

func key() -> StringName:
	return &"holosign"

func on_removed() -> void:
	if projector and is_instance_valid(projector) and projector.has_c(&"gadget"):
		projector.c(&"gadget").signs.erase(e)

func pop(user: Entity) -> void:
	if user:
		Game.visible_message(e.cell, "%s waves a hand through %s and it fizzles out." % [user.display_name, e.the()])
	Sfx.play("shimmer", e.cell, 0.6)
	e.destroy()

func attack_hand(user: Entity) -> bool:
	pop(user)
	return true

func attackby(user: Entity, item: Entity) -> bool:
	var gd: CGadget = item.c(&"gadget")
	if gd and gd.kind == "holofan":
		Game.tell(user, "You clear the hologram.")
		pop(null)
		return true
	pop(user)
	return true

func examine(_user: Entity, lines: Array) -> void:
	lines.append("[color=#8a93a3]Gas can't get through it, but you can walk right through.[/color]")
