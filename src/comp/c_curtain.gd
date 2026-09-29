class_name CCurtain extends Component
## tg curtain: click to draw it closed (blocks sight, not movement) or open again.

var style := "curtain" # sprite prefix: curtain, shower_curtain
var closed := false

func key() -> StringName:
	return &"curtain"

func setup(p: Dictionary) -> CCurtain:
	style = p.get("style", style)
	closed = p.get("closed", closed)
	return self

func on_added() -> void:
	_apply()

func toggle(user: Entity) -> void:
	closed = not closed
	_apply()
	Game.visible_message(e.cell, "%s %s %s." % [user.display_name, "draws" if closed else "opens", e.the()], "emote")

func _apply() -> void:
	e.set_sprite("objects", "%s_%s" % [style, "closed" if closed else "open"])
	var b: CBlocker = e.c(&"blocker")
	if b:
		b.set_state(false, false, closed)

func attack_hand(user: Entity) -> bool:
	toggle(user)
	return true

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Open curtain" if closed else "Close curtain", "cb": toggle.bind(user), "priority": 6})
