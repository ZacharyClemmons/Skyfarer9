class_name CFireAlarm extends Component
## tg fire alarm (/obj/machinery/firealarm). Click it to pull the alarm: the area's
## lights go red, the klaxon sounds and every firelock touching the area drops. Click it
## again (or swipe an ID) to reset. It also trips on its own when the room is on fire.

var area_ref: Area

func key() -> StringName:
	return &"firealarm"

func on_added() -> void:
	area_ref = Game.map.area_at(e.cell)
	e.display_name = "%s fire bell" % area_ref.name

var _shown := ""

func tick(_dt: float) -> void:
	var m: CMachine = e.c(&"machine")
	var want := "fire_alarm_on" if area_ref.fire_alarm or area_ref.fire_pulled else "fire_alarm_idle"
	if m and not m.operable():
		want = "fire_alarm"
	if want != _shown:
		_shown = want
		e.set_sprite("objects", want)

func attack_hand(user: Entity) -> bool:
	var m: CMachine = e.c(&"machine")
	if m and not m.operable():
		Game.tell(user, "%s is dark." % e.the().capitalize(), "warn")
		return true
	area_ref.fire_pulled = not area_ref.fire_pulled
	area_ref.fire_alarm = area_ref.fire_pulled or area_ref.fire_alarm
	if not area_ref.fire_pulled and area_ref.air_alarm == null:
		area_ref.fire_alarm = false
	Sfx.play("click", e.cell, 0.6)
	if area_ref.fire_pulled:
		Game.visible_message(e.cell, "%s pulls %s!" % [user.display_name, e.the()], "warn")
		Sfx.play("alarm", e.cell, 0.8)
		StationAlerts.radio_system("Fire Alarm", "Engineering", "Fire alarm pulled in %s." % area_ref.name, {"type": "fire", "key": "firealarm:%d" % area_ref.id, "cell": e.cell, "severity": 1})
	else:
		Game.visible_message(e.cell, "%s resets %s." % [user.display_name, e.the()])
	return true

func attackby(user: Entity, item: Entity) -> bool:
	if item.has_c(&"idcard") and area_ref.fire_pulled:
		return attack_hand(user)
	return false

func examine(_user: Entity, lines: Array) -> void:
	if area_ref.fire_pulled:
		lines.append("[color=#ff5a4a]It has been pulled. Click it to reset.[/color]")
	elif area_ref.fire_alarm:
		lines.append("[color=#ff5a4a]It's sounding: the sensors have picked up a fire.[/color]")
	else:
		lines.append("[color=#8a93a3]Pull in case of fire.[/color]")

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Reset alarm" if area_ref.fire_pulled else "Pull alarm", "cb": attack_hand.bind(user), "priority": 6})
