class_name CHelm extends Component
## The ship's wheel. Take it and you are flying; let go and the ship holds its last order.
##
## Piloting is direct rather than menu-driven: once you have the wheel, the movement keys
## become ship controls (W/S throttle, A/D put the rudder over, Q/E trim the ballast) and
## the HUD shows a helm readout. Everything is also available as a verb, so an NPC pilot
## or a player who prefers the mouse can fly perfectly well.

var ship_id := -1
var pilot: Entity = null

func key() -> StringName:
	return &"helm"

func ship() -> Airship:
	return Game.fleet.get_ship(ship_id) if Game.fleet else null

func flying() -> bool:
	return pilot != null and is_instance_valid(pilot) and not pilot.removed and pilot.adjacent(e)

func process(_delta: float) -> void:
	if pilot != null and not flying():
		release(pilot, true)

# ------------------------------------------------------------------ taking the wheel
func attack_hand(user: Entity) -> bool:
	if pilot == user:
		release(user, false)
		return true
	if pilot != null and is_instance_valid(pilot):
		Game.tell(user, "%s has the wheel." % pilot.display_name)
		return true
	take(user)
	return true

func take(user: Entity) -> void:
	var sh := ship()
	if sh == null:
		Game.tell(user, "The wheel turns freely. It is not connected to anything.")
		return
	pilot = user
	Game.tell(user, "[b]You take the wheel of %s.[/b]  [color=#9ad8ff]W/S throttle · A/D hold the rudder over · X steady · Q/E ballast · R sails · Space all stop · click the wheel to let go.[/color]" % sh.ship_name, "good")
	Game.visible_message(e.cell, "%s takes the wheel." % user.display_name)
	Sfx.play("ratchet", e.cell, 0.6)
	if user == Game.player:
		Bus.helm_changed.emit(sh)

func release(user: Entity, silent: bool) -> void:
	var sh := ship()
	steer(0.0)
	if not silent:
		Game.tell(user, "You let go of the wheel.")
	pilot = null
	if user == Game.player:
		Bus.helm_changed.emit(null)
	if sh != null and not silent:
		Game.visible_message(e.cell, "%s steps away from the wheel." % user.display_name)

# ------------------------------------------------------------------ orders
func throttle(d: float) -> void:
	var sh := ship()
	if sh == null:
		return
	sh.throttle = clampf(sh.throttle + d, 0.0, 1.0)
	_say("Throttle %d%%." % int(sh.throttle * 100.0))

func all_stop() -> void:
	var sh := ship()
	if sh == null:
		return
	sh.throttle = 0.0
	sh.sails_set = 0.0
	_say("[b]All stop.[/b]")

## Hold the rudder over. `amount` is in radians and is applied every frame the key is
## held, so the bow sweeps round rather than snapping between four headings.
func rudder(amount: float) -> void:
	var sh := ship()
	if sh == null:
		return
	sh.rudder_input = 0.0
	var lead := wrapf(sh.wanted_angle - sh.angle, -PI, PI)
	sh.wanted_angle = wrapf(sh.angle + clampf(lead + amount, -PI * 0.5, PI * 0.5), -PI, PI)
	sh.heading = Airship._quarter_of(sh.wanted_angle)

## Held keys ask for a turn rate. Releasing the key allows a short, smooth braking arc.
func steer(direction: float) -> void:
	var sh := ship()
	if sh == null:
		return
	if direction == 0.0 and sh.rudder_input != 0.0:
		var coast := signf(sh.angular_velocity) * sh.angular_velocity * sh.angular_velocity / (2.0 * Airship.TURN_ACCEL)
		sh.wanted_angle = wrapf(sh.angle + coast, -PI, PI)
		sh.heading = Airship._quarter_of(sh.wanted_angle)
	sh.rudder_input = clampf(direction, -1.0, 1.0)

## A quarter turn in one go, for the verb menu and for anyone flying with the mouse.
func put_rudder_over(step: int) -> void:
	var sh := ship()
	if sh == null:
		return
	sh.rudder_input = 0.0
	sh.wanted_angle = wrapf(sh.wanted_angle + step * PI * 0.5, -PI, PI)
	sh.heading = Airship._quarter_of(sh.wanted_angle)
	_say("Rudder over — steering %s." % ["north", "east", "south", "west"][sh.heading])
	Sfx.play("ratchet", e.cell, 0.5)

## Centre the rudder: stop turning and hold whatever heading she is on now.
func steady() -> void:
	var sh := ship()
	if sh == null:
		return
	sh.rudder_input = 0.0
	var coast := signf(sh.angular_velocity) * sh.angular_velocity * sh.angular_velocity / (2.0 * Airship.TURN_ACCEL)
	sh.wanted_angle = wrapf(sh.angle + coast, -PI, PI)
	sh.heading = Airship._quarter_of(sh.wanted_angle)
	_say("Steady as she goes.")

func trim(d: float) -> void:
	var sh := ship()
	if sh == null:
		return
	sh.ballast = clampf(sh.ballast + d, -1.0, 1.0)
	var word := "level"
	if sh.ballast > 0.1: word = "light (climbing)"
	elif sh.ballast < -0.1: word = "heavy (sinking)"
	_say("Ballast trimmed %s." % word)

func sails(d: float) -> void:
	var sh := ship()
	if sh == null:
		return
	if sh.masts.is_empty():
		_say("This hull carries no masts.")
		return
	sh.sails_set = clampf(sh.sails_set + d, 0.0, 1.0)
	_say("Sails %s." % ("furled" if sh.sails_set <= 0.0 else "set %d%%" % int(sh.sails_set * 100.0)))
	Sfx.play("whoosh", e.cell, 0.5)

func _say(msg: String) -> void:
	if pilot != null and is_instance_valid(pilot):
		Game.tell(pilot, msg)

# ------------------------------------------------------------------ description
func examine(_user: Entity, lines: Array) -> void:
	var sh := ship()
	if sh == null:
		lines.append("It is not linked to a hull.")
		return
	lines.append(sh.status_text())
	lines.append("Throttle [b]%d%%[/b], sails [b]%d%%[/b], steering [b]%s[/b]." % [
		int(sh.throttle * 100.0), int(sh.sails_set * 100.0), ["north", "east", "south", "west"][sh.heading]])
	if Game.sky != null:
		lines.append("Outside: %s from the %s." % [Game.sky.wind_name(), Game.sky._from(Game.sky.wind_dir_name())])
	if pilot != null and is_instance_valid(pilot):
		lines.append("[i]%s has the wheel.[/i]" % pilot.display_name)

func verbs(user: Entity, out: Array) -> void:
	if pilot == user:
		out.append({"name": "Let go of the wheel", "priority": 30, "cb": func(): release(user, false)})
		out.append({"name": "Ahead more", "priority": 25, "cb": func(): throttle(0.25)})
		out.append({"name": "Ahead less", "priority": 24, "cb": func(): throttle(-0.25)})
		out.append({"name": "All stop", "priority": 23, "cb": func(): all_stop()})
		out.append({"name": "Port the rudder", "priority": 22, "cb": func(): put_rudder_over(-1)})
		out.append({"name": "Starboard the rudder", "priority": 21, "cb": func(): put_rudder_over(1)})
		out.append({"name": "Trim lighter (climb)", "priority": 20, "cb": func(): trim(0.25)})
		out.append({"name": "Trim heavier (sink)", "priority": 19, "cb": func(): trim(-0.25)})
		var sh := ship()
		if sh != null and not sh.masts.is_empty():
			out.append({"name": "Set more sail", "priority": 18, "cb": func(): sails(0.34)})
			out.append({"name": "Take in sail", "priority": 17, "cb": func(): sails(-0.34)})
	else:
		out.append({"name": "Take the wheel", "priority": 30, "cb": func(): take(user)})

func ai_tags(out: Dictionary) -> void:
	out["helm"] = true
