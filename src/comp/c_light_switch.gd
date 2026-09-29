class_name CLightSwitch extends Component
## tg's light switch (machinery/lightswitch.dm): flicks the whole area's lights. It glows
## faintly while the area has power so you can find it in the dark.

func key() -> StringName:
	return &"lightswitch"

func area() -> Area:
	return Game.map.area_at(e.cell)

func attack_hand(user: Entity) -> bool:
	var a := area()
	var power := a.power_light
	a.lights_forced_off = not a.lights_forced_off
	Sfx.play("click", e.cell, 0.6)
	if not power:
		Game.tell(user, "You flick the switch. Nothing happens: there's no power.", "warn")
	elif user == Game.player:
		Game.tell(user, "You flick the lights %s." % ("off" if a.lights_forced_off else "on"))
	for l in Game.all_with(&"light"):
		if Game.map.area_at(l.cell) == a:
			l.c(&"light").refresh()
	update_sprite()
	return true

func update_sprite() -> void:
	e.set_sprite("objects", "light_switch_off" if area().lights_forced_off else "light_switch_on")

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Lights on" if area().lights_forced_off else "Lights off", "cb": attack_hand.bind(user), "priority": 7})

func examine(_user: Entity, lines: Array) -> void:
	var a := area()
	lines.append("It controls the lights in %s. They're %s." % [a.name, "unpowered" if not a.power_light else ("off" if a.lights_forced_off else "on")])

func ai_tags(out: Dictionary) -> void:
	out["light_switch"] = true
