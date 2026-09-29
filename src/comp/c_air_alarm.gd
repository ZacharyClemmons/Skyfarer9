class_name CAirAlarm extends Component
## Air alarm (tg: /obj/machinery/airalarm). Monitors its area's air; raises area alarms
## that get relayed to Engineering over the radio by the station alert system, just
## like tg's station alert console. Also acts as the area thermostat.

var area_ref: Area
var readings := {"pressure": 101.3, "o2": 21.0, "co2": 0.0, "plasma": 0.0, "temp": 293.0, "smoke": 0.0}
var gas_readings := PackedFloat32Array()
var danger := 0 # 0 ok, 1 warning, 2 danger
var reason := ""
var fire := false
var mode := "filtering" # tg air alarm modes, see MODES
var locked := true # tg: swipe an ID with atmospherics/engineering access to unlock the controls
var _cycle_phase := "" # "cycle" mode: siphon until empty, then refill

## tg /obj/machinery/airalarm modes: what the room's vents and scrubbers do.
const MODES := {
	"filtering": {"name": "Filtering", "desc": "Scrubs out contaminants (carbon dioxide). Vents keep the room at 1 atm."},
	"contaminated": {"name": "Contaminated", "desc": "Scrubs out ALL contaminants quickly: every gas but oxygen, nitrogen and pluoxium, on a wide net."},
	"draught": {"name": "Draught", "desc": "Siphons air out while replacing it: vents push to 2 atm."},
	"refill": {"name": "Refill", "desc": "Vents pump at three times normal pressure to refill the room fast."},
	"cycle": {"name": "Cycle", "desc": "Siphons the room empty, then refills it with fresh air."},
	"siphon": {"name": "Siphon", "desc": "Vents off, scrubbers siphon everything out."},
	"panic": {"name": "Emergency Siphon", "desc": "Vents off, scrubbers siphon everything out on a wide net, fast."},
	"off": {"name": "Off", "desc": "Every vent and scrubber in the room is shut off."},
}
const UNLOCK_ACCESS := ["atmos", "engineering"]
var _prev_danger := 0
var _prev_fire := false
var _report_cd := 0.0

func key() -> StringName:
	return &"air_alarm"

func on_added() -> void:
	gas_readings.resize(Defs.GAS_COUNT)
	area_ref = Game.map.area_at(e.cell)
	area_ref.air_alarm = e
	e.display_name = "%s air bell" % area_ref.name

func tick(dt: float) -> void:
	_report_cd = maxf(0.0, _report_cd - dt)
	var m: CMachine = e.c(&"machine")
	if not m.operable() or Game.atmos == null:
		return
	var at = Game.atmos
	var cells := area_ref.cells
	if cells.is_empty():
		return
	# sample a handful of cells (cheap and 'sensor like')
	var n := 0
	var p := 0.0
	var t := 0.0
	var o2 := 0.0
	var co2 := 0.0
	var pl := 0.0
	var sm := 0.0
	var step := maxi(1, cells.size() / 12)
	var fires := 0
	gas_readings.fill(0.0)
	for i in range(0, cells.size(), step):
		var c: Vector2i = cells[i]
		var k: int = Game.map.idx(c)
		p += at.pressure(k)
		for g in Defs.GAS_COUNT:
			gas_readings[g] += at.partial(k, g)
		t += at.temp[k]
		o2 += at.partial(k, Defs.G_O2)
		co2 += at.partial(k, Defs.G_CO2)
		pl += at.partial(k, Defs.G_PLASMA)
		sm += at.partial(k, Defs.G_SMOKE)
		n += 1
	for c in at.hotspots.keys():
		if Game.map.area[Game.map.idx(c)] == area_ref.id:
			fires += 1
	if n == 0:
		return
	for g in Defs.GAS_COUNT:
		gas_readings[g] /= n
	readings = {"pressure": p / n, "temp": t / n, "o2": o2 / n, "co2": co2 / n, "plasma": pl / n, "smoke": sm / n}
	danger = 0
	reason = ""
	var r := readings
	if r["pressure"] < Defs.HAZARD_LOW_PRESSURE or r["pressure"] > Defs.HAZARD_HIGH_PRESSURE:
		danger = 2
		reason = "pressure %.0f kPa" % r["pressure"]
	elif r["pressure"] < Defs.WARNING_LOW_PRESSURE or r["pressure"] > Defs.WARNING_HIGH_PRESSURE:
		danger = 1
		reason = "pressure %.0f kPa" % r["pressure"]
	if r["o2"] < 16.0:
		danger = maxi(danger, 2 if r["o2"] < 10 else 1)
		reason = "low oxygen"
	if r["plasma"] > 0.5 or r["co2"] > 8.0:
		danger = maxi(danger, 2)
		reason = "toxic gas"
	if r["temp"] < 263.0 or r["temp"] > 330.0:
		danger = maxi(danger, 2 if (r["temp"] < 243.0 or r["temp"] > 370.0) else 1)
		reason = "temperature %.0f C" % (r["temp"] - Defs.T0C)
	fire = fires > 0
	area_ref.atmos_alarm = danger >= 2
	area_ref.fire_alarm = fire or area_ref.fire_pulled
	if (danger >= 2 and _prev_danger < 2) or (fire and not _prev_fire):
		_raise()
	if danger == 0 and _prev_danger >= 2 and not fire:
		StationAlerts.clear(area_ref)
	_prev_danger = danger
	_prev_fire = fire
	# cycle: once the room is (nearly) empty, switch from siphoning to refilling
	if mode == "cycle" and _cycle_phase == "siphon" and r["pressure"] < 5.0:
		_cycle_phase = "refill"
		_apply_mode()
	elif mode == "cycle" and _cycle_phase == "refill" and r["pressure"] >= Defs.ONE_ATMOS * 0.98:
		mode = "filtering"
		_cycle_phase = ""
		_apply_mode()

## The room's vents and scrubbers, numbered like tg's air alarm list.
func devices(kind: String) -> Array:
	var out := []
	for v in Game.all_with(&"vent"):
		var cv: CVent = v.c(&"vent")
		if cv.mode == kind and Game.map.area_at(v.cell) == area_ref:
			out.append(v)
	out.sort_custom(func(a, b): return a.id < b.id)
	for k in out.size():
		out[k].c(&"vent").number = k + 1
	return out

func set_mode(m: String, user: Entity = null) -> void:
	if not MODES.has(m) or not can_control(user):
		return
	mode = m
	_cycle_phase = "siphon" if m == "cycle" else ""
	_apply_mode()
	if user:
		Game.visible_message(e.cell, "%s sets %s to %s." % [user.display_name, e.the(), MODES[m]["name"]])
		Bus.stimulus.emit({"type": "tamper" if m in ["siphon", "panic", "off"] and area_ref.id != 0 else "repaired", "actor": user, "target": e, "cell": e.cell, "loud": 1.0})

## tg air_alarm_modes.dm, mode by mode. Scrubbers filter CO2 by default (and smoke, which
## tg doesn't have as a gas); "contaminated" takes every gas but oxygen, nitrogen and
## pluoxium on a wide net.
func _apply_mode() -> void:
	var m := mode
	if m == "cycle":
		m = "siphon_wide" if _cycle_phase == "siphon" else "filtering"
	var vent_on := not m in ["siphon", "panic", "off", "siphon_wide"]
	var vent_bound: float = {"draught": 2.0, "refill": 3.0}.get(m, 1.0) * Defs.ONE_ATMOS
	for v in devices("vent"):
		var cv: CVent = v.c(&"vent")
		cv.on = vent_on
		cv.siphon = false
		cv.target_pressure = vent_bound
	for s in devices("scrubber"):
		var cs: CVent = s.c(&"vent")
		cs.on = m != "off"
		cs.siphon = m in ["siphon", "panic", "draught", "siphon_wide"]
		cs.widenet = m in ["contaminated", "panic", "siphon_wide"]
		if m == "contaminated":
			cs.filters = {}
			for g in Defs.GAS_COUNT:
				if not g in [Defs.G_O2, Defs.G_N2, Defs.G_PLUOXIUM]:
					cs.filters[g] = true
		elif m in ["filtering", "refill"]:
			cs.filters = {Defs.G_CO2: true, Defs.G_SMOKE: true}

func can_control(user: Entity) -> bool:
	if not locked or user == null:
		return true
	var inv = user.c(&"inv")
	if inv:
		for t in UNLOCK_ACCESS:
			if inv.has_access(t):
				return true
	return false

func toggle_lock(user: Entity) -> void:
	var inv = user.c(&"inv")
	var ok := false
	if inv:
		for t in UNLOCK_ACCESS:
			if inv.has_access(t):
				ok = true
	if ok:
		locked = not locked
		Game.tell(user, "You %s the air alarm's controls." % ("lock" if locked else "unlock"))
	else:
		Game.tell(user, "Access denied.", "bad")
		Sfx.play("deny", e.cell)

func attackby(user: Entity, item: Entity) -> bool:
	if item.has_c(&"idcard"):
		toggle_lock(user)
		return true
	return false

func _raise() -> void:
	if fire:
		StationAlerts.raise(area_ref, "fire", "Fire alarm in %s." % area_ref.name)
	else:
		StationAlerts.raise(area_ref, "atmos", "Air alarm in %s: %s." % [area_ref.name, reason])

func attack_hand(_user: Entity) -> bool:
	Bus.ui_open_window.emit("air_alarm", e)
	return true

func examine(_user: Entity, lines: Array) -> void:
	var r := readings
	lines.append("Pressure %.1f kPa, %.1f C, O2 %.1f kPa, CO2 %.1f kPa%s" % [r["pressure"], r["temp"] - Defs.T0C, r["o2"], r["co2"], (", plasma %.1f kPa" % r["plasma"]) if r["plasma"] > 0.05 else ""])
	if danger >= 2:
		lines.append("[color=#ff5a4a]The display flashes red: %s![/color]" % reason)
	elif danger == 1:
		lines.append("[color=#ffb84a]The display is amber: %s.[/color]" % reason)

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Open interface", "cb": attack_hand.bind(user), "priority": 7})
