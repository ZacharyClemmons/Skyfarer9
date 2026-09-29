class_name CApc extends Component
## Area Power Controller (tg: /obj/machinery/power/apc). Draws from the powernet under
## it, buffers into its cell and feeds its area's three channels. When starved it sheds
## channels in tg's order: equipment first, then lighting, then environment.

var area_ref: Area
var charge := 1500.0 # kJ
var capacity := 1500.0
var breaker := true
var modes := {"equip": "auto", "light": "auto", "environ": "auto"} # auto / on / off
var last_load_w := 0.0
var last_input_w := 0.0
var grid_ok := false
var charging := false
var name_tag := ""

func key() -> StringName:
	return &"apc"

func on_added() -> void:
	area_ref = Game.map.area_at(e.cell)
	area_ref.apc = e
	name_tag = area_ref.name
	e.display_name = "%s APC" % area_ref.name

func machine() -> CMachine:
	return e.c(&"machine")

func operating() -> bool:
	return breaker and not machine().broken

## Decide channel states from charge (called by PowerSystem each tick).
func update_channels() -> void:
	var a := area_ref
	var old := [a.power_equip, a.power_light, a.power_environ]
	if not operating() or (charge <= 0.0 and not grid_ok):
		a.power_equip = false
		a.power_light = false
		a.power_environ = false
	else:
		var pct := charge / capacity
		a.power_equip = _mode_state("equip", pct, 0.30, a.power_equip)
		a.power_light = _mode_state("light", pct, 0.15, a.power_light)
		a.power_environ = _mode_state("environ", pct, 0.05, a.power_environ)
	if old != [a.power_equip, a.power_light, a.power_environ]:
		Bus.power_state_changed.emit(a.id)

## tg APC charging lamp: red not charging, blue charging, green fully charged; dark with the
## breaker off or the unit broken.
const LAMP := {"off": Color("#401010"), "draining": Color("#ff4a3a"), "charging": Color("#4a9aff"), "full": Color("#5aff9a")}

func lamp_state() -> String:
	if not operating():
		return "off"
	if not grid_ok:
		return "draining"
	if charging:
		return "charging"
	return "full"

func update_lamp() -> void:
	var l = e.c(&"light")
	if l:
		l.energy = 0.1 if lamp_state() == "off" else 0.35
		l.set_color(LAMP[lamp_state()])

func _mode_state(ch: String, pct: float, threshold: float, current: bool) -> bool:
	match modes[ch]:
		"on":
			return charge > 0.0 or grid_ok
		"off":
			return false
	if grid_ok:
		return true
	# hysteresis: turn off below threshold, back on 5% above it
	if current:
		return pct > threshold
	return pct > threshold + 0.05

func attack_hand(user: Entity) -> bool:
	Bus.ui_open_window.emit("apc", e)
	if user != Game.player:
		return true
	return true

func toggle_breaker(user: Entity = null) -> void:
	breaker = not breaker
	update_channels()
	if user:
		Game.visible_message(e.cell, "%s switches %s the main breaker of %s." % [user.display_name, "on" if breaker else "off", e.the()])
		if not breaker:
			Bus.stimulus.emit({"type": "apc_off", "actor": user, "target": e, "cell": e.cell, "loud": 0.0, "illegal": not user.c(&"inv").has_access("engineering")})

func examine(_user: Entity, lines: Array) -> void:
	var st: String = {"off": "[color=#ff5a4a]Its lights are out.[/color]", "draining": "[color=#ff5a4a]Its lamp is red: it's running down on its battery.[/color]",
		"charging": "[color=#7fd4ff]Its lamp is blue: charging.[/color]", "full": "[color=#6ae88a]Its lamp is green: fully charged.[/color]"}[lamp_state()]
	lines.append("Charge: %d%%. Load: %.1f kW. %s" % [int(charge / capacity * 100.0), last_load_w / 1000.0, st])
	if not breaker:
		lines.append("[color=#ffb84a]The main breaker is off.[/color]")

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Open interface", "cb": attack_hand.bind(user), "priority": 7})

func ai_tags(out: Dictionary) -> void:
	out["apc"] = true
	if charge / capacity < 0.25 and not grid_ok:
		out["apc_low"] = true
