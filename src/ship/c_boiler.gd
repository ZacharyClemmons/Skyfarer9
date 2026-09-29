class_name CBoiler extends Component
## A fuel-fired boiler. It burns distillate to raise steam; the steam drives the dynamo,
## which is what keeps the lights, the thrusters' ignition and the scrubbers alive.
##
## It is also the most dangerous object on the ship. Pressure builds with the fire and
## bleeds off through the safety valve. Shut the valve to hold more pressure — the dynamo
## runs harder — and keep shutting it and you will find out why the valve is there.

## A lit boiler burns whether or not the throttle is open, which is why you shut it down
## when you moor. Small against the thrusters, and it adds up over an afternoon.
const FUEL_PER_SECOND := 0.06
const MAX_PRESSURE := 100.0
const SAFE_PRESSURE := 74.0
## Where the safety valve starts to lift. Under this she just makes steam.
const LIFT_PRESSURE := 58.0
const BURST_PRESSURE := 118.0
const VALVE_RELIEF := 9.0 # pressure vented per second with the valve open

## Which boiler is bolted in (ShipParts): output, thirst and how hard it cooks the room.
var mod := "boiler_std"
var lit := false
var damper := 0.75 # 0..1 how hard it is being fired
var valve_open := true
var pressure := 0.0
var _creak_t := 0.0
var _warned := false
var _cue := 0 # how many pressure milestones she has passed on the way up
const ShipFxScript := preload("res://src/ship/ship_fx.gd")
## Pressure milestones and what each one means to the man at the gauge.
const CUES := [
	[8.0, "Steam is up. The injectors have something to bite on.", "good"],
	[36.0, "The gauge is climbing. She is coming on the boil.", "info"],
	[58.0, "The safety valve starts to feather. Working pressure.", "info"],
]

func key() -> StringName:
	return &"boiler"

func on_added() -> void:
	_refresh()

## 0..1 of rated output, which the dynamo multiplies into watts. A better boiler makes
## more steam out of the same pressure, so it drives more machinery off the same fire.
func output() -> float:
	if not lit:
		return 0.0
	return clampf(pressure / SAFE_PRESSURE, 0.0, 1.35) * ShipParts.stat(mod, "steam", 1.0)

func ship() -> Airship:
	return Game.fleet.get_ship(int(e.tags.get("ship", -1))) if Game.fleet else null

func process(delta: float) -> void:
	var sh := ship()
	if lit:
		var need := FUEL_PER_SECOND * damper * delta * ShipParts.stat(mod, "fuel_mul", 1.0)
		var got: float = sh.draw_fuel(need) if sh != null else 0.0
		if got < need * 0.8:
			extinguish("the fuel ran out")
		else:
			# a water-tube boiler comes up in a minute and a half; a pot boiler takes ten
			pressure = minf(MAX_PRESSURE * 1.4, pressure + damper * 11.0 * delta * ShipParts.stat(mod, "steam", 1.0))
			# a fired boiler heats the room it stands in, which is welcome up high and
			# miserable over a cinder isle
			var at = Game.atmos
			if at != null and not Game.map.is_outdoor(e.cell):
				at.add_heat(Game.map.idx(e.cell), 14000.0 * damper * delta * ShipParts.stat(mod, "heat_mul", 1.0))
	else:
		pressure = maxf(0.0, pressure - delta * 5.0)
	# A safety valve lifts at its set pressure and not before — it is there to stop her
	# bursting, not to stop her working. Below the line it does nothing at all.
	if valve_open and pressure > LIFT_PRESSURE:
		var over: float = (pressure - LIFT_PRESSURE) / maxf(1.0, SAFE_PRESSURE - LIFT_PRESSURE)
		pressure = maxf(LIFT_PRESSURE, pressure - VALVE_RELIEF * (0.35 + over) * delta)
		if Game.atmos != null and not Game.map.is_outdoor(e.cell):
			# venting steam into a cabin is how you fog your own windows and scald a cook
			Game.atmos.add_gas(Game.map.idx(e.cell), Defs.G_H2O, 0.7 * delta, Defs.T0C + 130.0)
	_strain(delta)
	_cues(sh)
	_refresh()

## Tell the player, once each, how the pressure is coming on, so waiting for steam has
## milestones instead of a silent ten seconds.
func _cues(sh: Airship) -> void:
	if not lit or pressure < CUES[0][0] * 0.5:
		_cue = 0
		return
	if _cue < CUES.size() and pressure >= float(CUES[_cue][0]):
		var cue: Array = CUES[_cue]
		_cue += 1
		if sh != null and sh == Game.fleet.player_ship:
			Game.visible_message(e.cell, "[color=#9ad8ff]%s[/color]" % cue[1], cue[2])
			Sfx.play("ratchet", e.cell, 0.5, 0.8 + 0.15 * _cue)
			ShipFxScript.steam(e.position + Vector2(0, -14), 2)
	elif _cue > 0 and pressure < float(CUES[_cue - 1][0]) - 6.0:
		_cue -= 1

func _strain(delta: float) -> void:
	if pressure < SAFE_PRESSURE:
		_warned = false
		return
	_creak_t -= delta
	if _creak_t <= 0.0:
		_creak_t = 1.4
		Sfx.play("wall_tap", e.cell, 0.5)
	if pressure > SAFE_PRESSURE and not _warned:
		_warned = true
		Game.visible_message(e.cell, "[color=#e8a83a]The boiler's rivets start to tick. The gauge is in the red.[/color]", "warn")
	if pressure > BURST_PRESSURE:
		burst()

func burst() -> void:
	Game.visible_message(e.cell, "[b][color=#ff4a4a]THE BOILER LETS GO.[/color][/b]", "bad")
	Bus.chronicle.emit("A boiler burst aboard %s." % _ship_name(), 4)
	var at = Game.atmos
	if at != null:
		var i := Game.map.idx(e.cell)
		at.add_heat(i, 1.4e6)
		at.add_gas(i, Defs.G_H2O, 90.0, Defs.T0C + 260.0)
	Explosion.explode(e.cell, 1, 2, 4, null)
	e.destroy()

func _ship_name() -> String:
	var sh := ship()
	return sh.ship_name if sh != null else "a ship"

func light(user: Entity) -> void:
	if lit:
		return
	var sh := ship()
	if sh != null and sh.fuel() <= 0.5:
		Game.tell(user, "The bunkers are empty. Nothing to burn.")
		return
	lit = true
	Game.tell(user, "You open the damper and put a light to the burner. It catches with a [b]whump[/b] and the firebox roars.")
	Sfx.play("welder", e.cell, 0.9)
	Sfx.play("whoosh", e.cell, 0.7, 0.7)
	# the flare: a bloom of orange light, a gout of steam, a small shove of the camera
	if Game.lighting != null:
		Game.lighting.flash(e.cell, Color(1.0, 0.62, 0.25), 4.5, 0.8)
	ShipFxScript.steam(e.position + Vector2(0, -10), 3)
	if Game.view != null and user == Game.player:
		Game.view.shake(1.2)
	Skills.add_xp(user, "engineering", 8.0)
	_refresh()

func extinguish(why := "") -> void:
	if not lit:
		return
	lit = false
	_cue = 0
	ShipFxScript.steam(e.position + Vector2(0, -10), 2)
	Game.visible_message(e.cell, "The boiler goes out%s." % ("" if why == "" else " — " + why), "warn")
	_refresh()

func _refresh() -> void:
	var nm := "boiler_lit" if lit else "boiler"
	if e.spr_name != nm and Gfx.has("objects", nm):
		e.set_sprite("objects", nm)
	e.set_glow_visible(lit)

func examine(_user: Entity, lines: Array) -> void:
	lines.append("Fire: [b]%s[/b], damper %d%%. Pressure: [b]%.0f[/b] of %.0f%s" % [
		"lit" if lit else "cold", int(damper * 100.0), pressure, SAFE_PRESSURE,
		"  [color=#ff6a6a](OVER)[/color]" if pressure > SAFE_PRESSURE else ""])
	lines.append("Safety valve: [b]%s[/b]." % ("open" if valve_open else "[color=#e8a83a]shut[/color]"))

func verbs(user: Entity, out: Array) -> void:
	if lit:
		out.append({"name": "Shut the damper", "priority": 22, "cb": func(): extinguish("shut down")})
	else:
		out.append({"name": "Light the burner", "priority": 25, "cb": func(): light(user)})
	out.append({"name": "Shut the safety valve" if valve_open else "Open the safety valve", "priority": 20,
		"cb": func(): _toggle_valve(user)})
	out.append({"name": "Damper: more air", "priority": 15, "cb": func(): _damper(user, 0.2)})
	out.append({"name": "Damper: less air", "priority": 14, "cb": func(): _damper(user, -0.2)})

func _toggle_valve(u: Entity) -> void:
	valve_open = not valve_open
	Sfx.play("ratchet", e.cell, 0.7)
	if valve_open:
		Game.tell(u, "You crack the safety valve. Steam screams out and the needle drops.")
	else:
		Game.tell(u, "[color=#e8a83a]You screw the safety valve shut. The needle starts to climb.[/color]", "warn")

func _damper(u: Entity, d: float) -> void:
	damper = clampf(damper + d, 0.0, 1.0)
	Game.tell(u, "Damper at %d%%." % int(damper * 100.0))
	Sfx.play("click", e.cell, 0.5)

func take_damage(amount: float, _kind: String, _source: Entity) -> float:
	if lit and amount > 12.0 and Game.rng.randf() < 0.3:
		Game.visible_message(e.cell, "[b]The boiler is holed — scalding steam everywhere![/b]", "bad")
		if Game.atmos:
			Game.atmos.add_gas(Game.map.idx(e.cell), Defs.G_H2O, 24.0, Defs.T0C + 180.0)
		pressure = maxf(0.0, pressure - 40.0)
	return amount

func ai_tags(out: Dictionary) -> void:
	out["boiler"] = true
	if pressure > SAFE_PRESSURE:
		out["overpressure"] = true
