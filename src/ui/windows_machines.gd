class_name WindowsMachines
## Machine and console screens laid out like tg's tgui ones (PowerMonitor, CrewConsole,
## StationAlertConsole, AtmosControlConsole, Canister, AtmosPump/Filter/Mixer, Apc, Smes,
## the reactor) with the TGUI kit: sections, lined-up label/value lists, coloured bars and
## tables instead of a block of text.

static func handles(kind: String, t: Entity) -> bool:
	if kind == "console":
		return t != null and t.c(&"console") and t.c(&"console").kind in ["eng", "reactor", "atmos", "med", "comms", "cmd", "desk", "pod"]
	return kind in ["air_alarm", "tank_console", "canister", "pipe_machine", "apc", "power", "reactor", "air_supply", "space_heater"]

static func width(kind: String, t: Entity) -> int:
	if kind == "air_alarm":
		return 620
	if kind == "console" and t and t.c(&"console"):
		return {"eng": 660, "med": 620, "atmos": 460, "reactor": 520, "comms": 520}.get(t.c(&"console").kind, 520)
	return {"pipe_machine": 560, "space_heater": 420, "tank_console": 500, "canister": 480, "apc": 480, "power": 460, "reactor": 480, "air_supply": 460}.get(kind, 480)

static func build(kind: String, t: Entity, body: VBoxContainer, p: Entity) -> void:
	match kind:
		"air_alarm": _air_alarm(t.c(&"air_alarm"), body, p)
		"console":
			var cc: CConsole = t.c(&"console")
			if not cc.operable():
				TGUI.notice(body, "The screen is dark.", "bad")
				return
			match cc.kind:
				"eng": _power_monitor(body)
				"reactor": _reactor_monitor(body)
				"atmos": _alert_console(body)
				"med": _crew_monitor(body)
				"comms": _comms(body, p)
				"pod": _pod(t, body, p)
				_: _ntos(body)
		"tank_console": _tank(t.c(&"console"), body, p)
		"canister": _canister(t.c(&"canister"), body, p)
		"pipe_machine": _pipe_machine(t.c(&"pipemachine"), body, p)
		"apc": _apc(t.c(&"apc"), body, p)
		"power": _power(t.c(&"powergen"), body, p)
		"reactor": _reactor(t.c(&"reactor"), body, p)
		"air_supply": _air_supply(t.c(&"air_supply"), body, p)
		"space_heater": _space_heater(t.c(&"spaceheater"), body, p)

# ============================================================================ monitoring consoles
## AirAlarm: sensor readings, modes, vents and every gas's scrubber filter.
static func _air_alarm(al: CAirAlarm, body: VBoxContainer, p: Entity) -> void:
	var machine: CMachine = al.e.c(&"machine")
	if not machine.operable():
		TGUI.notice(body, "The screen is dark.", "bad")
		return
	var ok := al.can_control(p)
	var readings: Dictionary = al.readings
	var sensor := TGUI.section(body, "Air readings")
	TGUI.notice(sensor, ["Nominal", "Caution", "DANGER"][al.danger] + (": " + al.reason if al.reason != "" else ""), ["good", "warn", "bad"][al.danger])
	var list := TGUI.list(sensor)
	TGUI.item(list, "Pressure", TGUI.kpa(readings["pressure"]))
	TGUI.item(list, "Temperature", TGUI.kelvin(readings["temp"]))
	for g in Defs.GAS_COUNT:
		var pp: float = al.gas_readings[g]
		if pp > 0.001 or g == Defs.G_O2:
			TGUI.item(list, Defs.GAS_NAMES[g], "%.3f kPa" % pp, TGUI.GAS_COLORS[g])
	var controls := TGUI.section(body, "Environmental controls")
	var lock_row := TGUI.row(controls)
	TGUI.button(lock_row, "Show pass", func(): al.toggle_lock(p))
	lock_row.add_child(UITheme.label("Locked" if al.locked else "Unlocked", UITheme.SMALL, TGUI.AVERAGE if al.locked else TGUI.GOOD))
	var modes := GridContainer.new()
	modes.columns = 4
	controls.add_child(modes)
	for mode in CAirAlarm.MODES:
		var id: String = mode
		var b := TGUI.button(modes, CAirAlarm.MODES[id]["name"], func(): al.set_mode(id, p), id == al.mode, not ok)
		b.tooltip_text = CAirAlarm.MODES[id]["desc"]
	TGUI.stepper(controls, al.area_ref.target_temp - Defs.T0C,
		[["-5", -5.0], ["-1", -1.0], ["+1", 1.0], ["+5", 5.0]], "%.0f C", func(d):
			if al.can_control(p):
				al.area_ref.target_temp = clampf(al.area_ref.target_temp + d, 278.0, 303.0), not ok)
	for kind in ["vent", "scrubber"]:
		for device in al.devices(kind):
			var vent: CVent = device.c(&"vent")
			var section := TGUI.section(body, "%s #%d%s" % [kind.capitalize(), vent.number, " (welded)" if vent.welded else ""])
			var row := TGUI.row(section)
			TGUI.button(row, "On" if vent.on else "Off", func():
				if al.can_control(p): vent.on = not vent.on, vent.on, not ok)
			TGUI.button(row, "Siphoning" if vent.siphon else ("Releasing" if kind == "vent" else "Scrubbing"), func():
				if al.can_control(p): vent.siphon = not vent.siphon, vent.siphon, not ok)
			if kind == "vent":
				TGUI.stepper(section, vent.target_pressure, [["-10", -10.0], ["+10", 10.0]], "%.0f kPa", func(d):
					if al.can_control(p): vent.target_pressure = clampf(vent.target_pressure + d, 0.0, Defs.ONE_ATMOS * 5.0), not ok)
			else:
				TGUI.button(row, "Wide net", func():
					if al.can_control(p): vent.widenet = not vent.widenet, vent.widenet, not ok)
				var filters := GridContainer.new()
				filters.columns = 4
				section.add_child(filters)
				for g in Defs.GAS_COUNT:
					var gas_id: int = g
					var b := TGUI.button(filters, Defs.GAS_SHORT[g], func():
						if al.can_control(p) and not vent.siphon:
							vent.filters[gas_id] = not vent.filters.get(gas_id, false), vent.filters.get(g, false), not ok or vent.siphon)
					b.tooltip_text = Defs.GAS_NAMES[g] + ": " + Defs.GAS_DESC[g]

## tg PowerMonitor: the grid's supply and demand, then every area's APC.
static func _power_monitor(body: VBoxContainer) -> void:
	var supply := 0.0
	var demand := 0.0
	for net in Game.power.nets:
		supply += net.get("supply", 0.0)
		demand += net.get("demand", 0.0)
	var s := TGUI.section(body, "Power grid")
	var l := TGUI.list(s)
	var top := maxf(supply, demand) * 1.15 + 1.0
	TGUI.item_ctrl(l, "Supply", TGUI.bar(supply, top, TGUI.kw(supply), TGUI.GOOD))
	TGUI.item_ctrl(l, "Draw", TGUI.bar(demand, top, TGUI.kw(demand), TGUI.GOOD if demand <= supply else TGUI.BAD))
	if demand > supply:
		TGUI.notice(s, "Demand is higher than supply: APCs are running down their cells.", "warn")
	var a := TGUI.section(body, "Areas")
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 360)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	a.add_child(sc)
	var tb := TGUI.table(sc, ["Area", "Cell", "Load", "Eqp", "Lgt", "Env"])
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for ar in Game.map.areas:
		if ar.apc == null:
			continue
		var apc: CApc = ar.apc.c(&"apc")
		var pct := apc.charge / apc.capacity
		TGUI.cell(tb, ar.name)
		var b := TGUI.bar(pct, 1.0, "%d%%" % roundi(pct * 100.0), TGUI.ranged(pct, [0.5, 1.0], [0.15, 0.5]))
		b.custom_minimum_size = Vector2(90, 14)
		TGUI.cell_ctrl(tb, b)
		TGUI.cell(tb, TGUI.kw(apc.last_load_w), UITheme.TEXT if apc.grid_ok else TGUI.AVERAGE)
		for on in [ar.power_equip, ar.power_light, ar.power_environ]:
			TGUI.cell(tb, "On" if on else "Off", TGUI.GOOD if on else TGUI.BAD)

## tg Supermatter/reactor monitor: the core, then the loops and what the TEG makes.
static func _reactor_monitor(body: VBoxContainer) -> void:
	for r in Game.all_with(&"reactor"):
		_reactor_core(r.c(&"reactor"), body, false, null)
	var s := TGUI.section(body, "Coolant loops")
	var l := TGUI.list(s)
	for net in Game.pipes.nets_on_layer(StationMap.PL_HOT):
		TGUI.item_ctrl(l, "Hot loop", TGUI.ranged_bar(net.total_moles(), 2000.0, "%s  ·  %.0f K  ·  %.0f mol" % [TGUI.kpa(net.pressure()), net.temp, net.total_moles()], [800, 99999], [400, 800]))
		if net.total_moles() < 800:
			TGUI.notice(s, "Coolant pressure low: check the hot loop for leaks.", "bad")
	for net in Game.pipes.nets_on_layer(StationMap.PL_COLD):
		TGUI.item(l, "Cold loop", "%s  ·  %.0f K" % [TGUI.kpa(net.pressure()), net.temp])
	for g in Game.all_with(&"powergen"):
		if g.c(&"powergen").kind == "teg":
			TGUI.item(l, "Generator", TGUI.kw(g.c(&"powergen").output_w), TGUI.GOOD)

## tg StationAlertConsole: alarms grouped by kind, "none" when quiet.
static func _alert_console(body: VBoxContainer) -> void:
	var groups := {"Fire": [], "Atmosphere": [], "Pipes": [], "Supply": []}
	for al in StationAlerts.active.values():
		groups["Fire" if al["fact"].get("type", "") == "fire" else "Atmosphere"].append(al["text"])
	for d in Game.map.damaged_pipes():
		if Game.map.pipe_leaking(d[0], d[1]):
			groups["Pipes"].append("Pressure drop: %s loop near %s" % [StationMap.PIPE_LAYER_NAMES[d[0]], Game.map.area_at(d[1]).name])
	for sup in Game.all_with(&"air_supply"):
		var asu: CAirSupply = sup.c(&"air_supply")
		if asu.o2_reserve < 5000:
			groups["Supply"].append("Oxygen reserve low: %.0f mol" % asu.o2_reserve)
	for k in groups:
		var s := TGUI.section(body, k)
		if groups[k].is_empty():
			s.add_child(UITheme.label("No active alarms.", UITheme.SMALL, TGUI.GOOD))
		for txt in groups[k]:
			TGUI.notice(s, txt, "bad" if k in ["Fire", "Pipes"] else "warn")

## tg CrewConsole: name, job, vitals and location in lined-up columns, the worst first.
static func _crew_monitor(body: VBoxContainer) -> void:
	var rows := []
	for m in Game.all_with(&"mob"):
		var h: CHealth = m.c(&"health")
		if h == null or m.c(&"mob").job == "":
			continue
		rows.append([h.severity(), m, h])
	rows.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1].display_name < b[1].display_name)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 420)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var tb := TGUI.table(sc, ["Name", "Job", "Vitals", "Location"])
	const STATES := [["Healthy", Color("#5ad87a")], ["Scratched", Color("#b8d84a")], ["Injured", Color("#e8c83a")], ["Badly hurt", Color("#e8803a")], ["CRITICAL", Color("#ff3a3a")], ["Deceased", Color("#8a8a8a")]]
	for r in rows:
		var m: Entity = r[1]
		var st: Array = STATES[clampi(r[0], 0, 5)]
		TGUI.cell(tb, m.display_name, UITheme.TEXT)
		TGUI.cell(tb, Jobs.title(m.c(&"mob").job), TGUI.LABEL)
		TGUI.cell(tb, st[0], st[1])
		TGUI.cell(tb, Game.map.area_at(m.root_cell()).name, UITheme.TEXT)

static func _comms(body: VBoxContainer, p: Entity) -> void:
	var s := TGUI.section(body, "Ship status")
	var l := TGUI.list(s)
	TGUI.item(l, "Ship's time", Game.clock_string())
	TGUI.item(l, "Alert level", Game.ALERT_NAMES[Game.alert_level], Game.ALERT_COLORS[Game.alert_level])
	if Game.evac:
		TGUI.item(l, "Ferry", Game.evac.status_text())
		if Game.evac.reason != "" and Game.evac.mode == Evac.CALLED:
			TGUI.item(l, "Reason given", Game.evac.reason)
		if Game.evac.no_recall:
			TGUI.notice(s, "Recall signals jammed.", "bad")
	if p == null:
		return
	var a := TGUI.section(body, "Alert level")
	var names := []
	for lvl in 3:
		names.append([Game.ALERT_NAMES[lvl].capitalize(), lvl])
	TGUI.choice(a, names, Game.alert_level, func(v): Windows._set_alert(p, v))
	var e := TGUI.section(body, "Emergency ferry")
	Windows._evac_controls(e, p)

static func _pod(t: Entity, body: VBoxContainer, p: Entity) -> void:
	var s := TGUI.section(body, "Lifeboat")
	s.add_child(UITheme.label("Seats six. Launches on its own when the ferry leaves.", UITheme.SMALL, TGUI.LABEL))
	var ev = Game.evac
	var err: String = ev.can_launch_pod() if ev else "Offline."
	TGUI.notice(s, "Launch clamps released." if err == "" else err, "good" if err == "" else "warn")
	if p and ev:
		var pod: Vessel = ev.vessel_at(t.cell)
		TGUI.button(s, "LAUNCH", func(): ev.launch_pod(pod, p), false, pod == null or err != "", TGUI.BAD)

## tg NtOS home: station status and the crew manifest.
static func _ntos(body: VBoxContainer) -> void:
	var s := TGUI.section(body, "NtOS")
	var l := TGUI.list(s)
	TGUI.item(l, "Ship's time", Game.clock_string())
	TGUI.item(l, "Alert level", Game.ALERT_NAMES[Game.alert_level], Game.ALERT_COLORS[Game.alert_level])
	if Game.evac:
		TGUI.item(l, "Ferry", Game.evac.status_text())
	TGUI.item(l, "Hold budget", "%d marks" % Cargo.points)
	TGUI.item(l, "Research", "%.0f points" % Research.points)
	var m := TGUI.section(body, "Crew list")
	var tb := TGUI.table(m, ["Name", "Job"])
	for mob in Game.all_with(&"mob"):
		if mob.c(&"mob").job != "":
			TGUI.cell(tb, mob.display_name)
			TGUI.cell(tb, Jobs.title(mob.c(&"mob").job), TGUI.LABEL)

# ============================================================================ atmospherics
## tg AtmosControlConsole: the chamber's gas, then its injector and outlet.
static func _tank(cc: CConsole, body: VBoxContainer, p: Entity) -> void:
	var mon := "" if cc.tank == "mix" else cc.tank
	var chamber: Area = null
	var devices := []
	for d in Game.all_with(&"vent"):
		var v: CVent = d.c(&"vent")
		if v.monitored == mon and v.mode in ["injector", "siphon"]:
			devices.append(v)
			var a := Game.map.area_at(d.cell)
			if a.room_kind == "gas_chamber":
				chamber = a
	var s := TGUI.section(body, chamber.name if chamber else "Chamber reading")
	if chamber == null or chamber.cells.is_empty():
		s.add_child(UITheme.label("No sensors detected.", UITheme.SMALL, TGUI.LABEL))
	else:
		var i := Game.map.idx(chamber.cells[chamber.cells.size() / 2])
		var pr: float = Game.atmos.pressure(i)
		var l := TGUI.list(s)
		TGUI.item_ctrl(l, "Pressure", TGUI.bar(pr, maxf(pr * 1.25, 5000.0), TGUI.kpa(pr), TGUI.INFO))
		TGUI.item(l, "Temperature", TGUI.kelvin(Game.atmos.temp[i]))
		var gas := PackedFloat32Array()
		for g in Defs.GAS_COUNT:
			gas.append(Game.atmos.gas[g][i])
		TGUI.gasmix(s, gas)
	var c := TGUI.section(body, "Chamber controls")
	if devices.is_empty():
		c.add_child(UITheme.label("No devices detected.", UITheme.SMALL, TGUI.LABEL))
	var cl := TGUI.list(c)
	for v in devices:
		var vv: CVent = v
		var injector := vv.mode == "injector"
		var r := HBoxContainer.new()
		TGUI.button(r, ("Injecting" if injector else "Draining") if vv.on else "Off", func():
			vv.on = not vv.on
			if p:
				Game.tell(p, "You turn the %s %s." % ["injector" if injector else "outlet", "on" if vv.on else "off"]), vv.on)
		TGUI.item_ctrl(cl, "Input injector" if injector else "Output regulator", r)
		# tg atmos_control: the injector's rate and the outlet's pressure limit
		if injector:
			TGUI.item_ctrl(cl, "Input rate", TGUI.number(vv.volume_rate, 0.0, 200.0, 1.0, "L/s", func(v): vv.volume_rate = v))
		else:
			TGUI.item_ctrl(cl, "Output limit", TGUI.number(vv.internal_bound, 0.0, 5000.0, 10.0, "kPa", func(v): vv.internal_bound = v))

## tg Canister: the tank, the release valve, and a holding tank.
static func _canister(cc: CCanister, body: VBoxContainer, p: Entity) -> void:
	var tk := cc.tank()
	var pr := cc.pressure()
	var s := TGUI.section(body, "Canister", [_status_pill(cc.valve_open, "Valve open", "Valve closed", TGUI.AVERAGE)])
	var l := TGUI.list(s)
	TGUI.item_ctrl(l, "Pressure", TGUI.ranged_bar(pr, CCanister.MAX_RELEASE * 1.2, TGUI.kpa(pr), [1.0, 9999999.0], [0.0, 0.5]))
	TGUI.item(l, "Port", "Connected" if cc.port else "Not connected", TGUI.GOOD if cc.port else TGUI.LABEL)
	if cc.kind != "canister":
		TGUI.item_ctrl(l, "Power", TGUI.choice(null, [["On", true], ["Off", false]], cc.on, func(v): cc.set_on(v, p)))
		if cc.kind == "pump":
			TGUI.item_ctrl(l, "Direction", TGUI.choice(null, [["Out", true], ["In", false]], cc.pump_out, func(v): cc.pump_out = v))
			TGUI.item_ctrl(l, "Target", TGUI.stepper(null, cc.target, [["Min", 0.0], ["-10", cc.target - 10.0], ["+10", cc.target + 10.0], ["Max", CCanister.MAX_RELEASE]], "%.0f kPa", func(v): cc.target = clampf(v, 0.0, CCanister.MAX_RELEASE)))
	TGUI.gasmix(s, tk.composition())
	var v := TGUI.section(body, "Valve")
	var vl := TGUI.list(v)
	TGUI.item_ctrl(vl, "Release pressure", TGUI.number(cc.release_pressure, 0.0, CCanister.MAX_RELEASE, 10.0, "kPa", func(val): cc.set_release(val)))
	TGUI.item_ctrl(vl, "Release valve", TGUI.choice(null, [["Open", true], ["Closed", false]], cc.valve_open, func(_v): cc.toggle_valve(p)))
	if cc.valve_open and cc.holding == null:
		TGUI.notice(v, "Releasing into the air!", "warn")
	var h := TGUI.section(body, "Holding cylinder", [TGUI.button(TGUI.row(null), "Eject", func(): cc.eject_tank(p), false, cc.holding == null).get_parent()] if cc.holding else [])
	if cc.holding:
		var ht: CTank = cc.holding.c(&"tank")
		var hl := TGUI.list(h)
		TGUI.item(hl, "Cylinder", cc.holding.display_name.capitalize())
		TGUI.item(hl, "Pressure", TGUI.kpa(ht.pressure_kpa()))
	else:
		h.add_child(UITheme.label("No holding cylinder. Use a cylinder on the canister to insert it.", UITheme.SMALL, TGUI.LABEL))

## tg AtmosPump / AtmosFilter / AtmosMixer / valves / ThermoMachine, plus a schematic of
## the machine's ports so you can see what it takes from where and where it puts it.
const MACHINE_NAMES := {"pump": "Pressure pump", "vpump": "Volumetric pump", "valve": "Manual valve", "filter": "Gas filter",
	"mixer": "Gas mixer", "gate": "Passive gate", "pvalve": "Pressure valve"}
const MACHINE_HELP := {
	"pump": "Pushes gas from its input into its output until the output reaches the set pressure.",
	"vpump": "Moves a fixed volume of the input's gas into the output every second, whatever the pressures.",
	"valve": "Open, the two sides share their gas freely. Closed, nothing passes.",
	"filter": "Sends the ticked gases out the side port; everything else carries on through.",
	"mixer": "Blends the main and side inputs in the set proportion into the output, up to the set pressure.",
	"gate": "Lets gas through one way only, and only while the output is below the set pressure.",
	"pvalve": "Opens once the input is above the set pressure and lets it bleed into the output.",
}

static func _pipe_machine(pm: CPipeMachine, body: VBoxContainer, p: Entity) -> void:
	var ok := pm.can_control(p)
	if pm.kind == "thermo":
		_thermo(pm, body, p, ok)
		return
	var title: String = pm.display if pm.display != "" else "Controls"
	var power := TGUI.row(null, 3)
	if pm.kind == "valve":
		TGUI.choice(power, [["Open", true], ["Closed", false]], pm.on, func(v): pm.set_on(v, p), not ok)
	else:
		TGUI.choice(power, [["On", true], ["Off", false]], pm.on, func(v): pm.set_on(v, p), not ok)
	var s := TGUI.section(body, title, [power])
	if pm.display != "":
		s.add_child(UITheme.label(MACHINE_NAMES.get(pm.kind, ""), UITheme.SMALL, TGUI.LABEL))
	if not ok:
		TGUI.notice(s, "Locked: show an Air Works or Engine Room pass to change it.", "warn")
	var l := TGUI.list(s)
	match pm.kind:
		"pump", "gate", "pvalve":
			TGUI.item_ctrl(l, "Opens above" if pm.kind == "pvalve" else "Output pressure",
				TGUI.number(pm.target_pressure, 0.0, CPipeMachine.MAX_PRESSURE, 10.0, "kPa", func(v): pm.adjust("target", v, p), true, not ok))
		"vpump":
			TGUI.item_ctrl(l, "Transfer rate", TGUI.number(pm.rate, 0.0, CPipeMachine.MAX_RATE, 1.0, "L/s", func(v): pm.adjust("rate", v, p), true, not ok))
		"filter":
			TGUI.item_ctrl(l, "Transfer rate", TGUI.number(pm.rate, 0.0, CPipeMachine.MAX_RATE, 1.0, "L/s", func(v): pm.adjust("rate", v, p), true, not ok))
			var fl := HFlowContainer.new()
			fl.add_theme_constant_override("h_separation", 4)
			fl.add_theme_constant_override("v_separation", 4)
			for g in [Defs.G_O2, Defs.G_N2, Defs.G_CO2, Defs.G_PLASMA, Defs.G_N2O, Defs.G_H2O, Defs.G_SMOKE]:
				var gg: int = g
				var on_g: bool = g in pm.filters
				var b := TGUI.button(fl, ("[x] " if on_g else "[ ] ") + TGUI.GAS_SHORT[g], func(): pm.adjust("gas_toggle", gg, p), on_g, not ok)
				b.add_theme_color_override("font_color", TGUI.GAS_COLORS[g].lerp(Color.WHITE, 0.35) if on_g else TGUI.LABEL)
			TGUI.item_ctrl(l, "Filter out", fl)
		"mixer":
			TGUI.item_ctrl(l, "Output pressure", TGUI.number(pm.target_pressure, 0.0, CPipeMachine.MAX_PRESSURE, 10.0, "kPa", func(v): pm.adjust("target", v, p), true, not ok))
			var main_l := TGUI.number(pm.node1_conc * 100.0, 0.0, 100.0, 1.0, "%", func(v): pm.adjust("node1", v / 100.0, p), false, not ok)
			TGUI.item_ctrl(l, "Main input", main_l)
			var side_l := TGUI.number((1.0 - pm.node1_conc) * 100.0, 0.0, 100.0, 1.0, "%", func(v): pm.adjust("node1", 1.0 - v / 100.0, p), false, not ok)
			TGUI.item_ctrl(l, "Side input", side_l)
			var pres := TGUI.row(null, 3)
			for pr in [["79 / 21", 0.79], ["21 / 79", 0.21], ["50 / 50", 0.5], ["All main", 1.0], ["All side", 0.0]]:
				var val: float = pr[1]
				TGUI.button(pres, pr[0], func(): pm.adjust("node1", val, p), is_equal_approx(pm.node1_conc, val), not ok)
			TGUI.item_ctrl(l, "Presets", pres)
	s.add_child(UITheme.label(MACHINE_HELP.get(pm.kind, ""), UITheme.SMALL, TGUI.LABEL))
	# where the gas comes from and goes
	var d := TGUI.section(body, "Connections")
	var ports := [{"name": "Input" if pm.kind != "mixer" else "Main input", "net": pm.net_in(), "role": "in"},
		{"name": "Output", "net": pm.net_out(), "role": "out"}]
	if pm.dir_side != Vector2i.ZERO:
		ports.append({"name": "Filtered out" if pm.kind == "filter" else "Side input", "net": pm.net_side(), "role": "side_out" if pm.kind == "filter" else "side_in"})
	var short: String = {"pump": "Pump", "vpump": "Vol. pump", "valve": "Valve", "filter": "Filter", "mixer": "Mixer", "gate": "Gate", "pvalve": "P. valve"}.get(pm.kind, "")
	d.add_child(TGUI.PortDiagram.new(short, ports, pm.moved_last, pm.working()))
	var tip := "Ctrl-click the valve to %s it." % ("close" if pm.on else "open") if pm.kind == "valve" else "Ctrl-click the machine to switch it %s; Alt-click to max it out." % ("off" if pm.on else "on")
	d.add_child(UITheme.label(tip, UITheme.SMALL, TGUI.LABEL))

## tg ThermoMachine: the pipe's temperature and the target, with Min / Max / Reset.
static func _thermo(pm: CPipeMachine, body: VBoxContainer, p: Entity, ok: bool) -> void:
	var power := TGUI.row(null, 3)
	TGUI.choice(power, [["On", true], ["Off", false]], pm.on, func(v): pm.set_on(v, p), not ok)
	var s := TGUI.section(body, "Freezer" if pm.freezer else "Heater", [power])
	if not ok:
		TGUI.notice(s, "Locked: show an Air Works or Engine Room pass to change it.", "warn")
	var n = Game.pipes.net_at(pm.layer, pm.e.cell + pm.dir_in)
	var l := TGUI.list(s)
	if n:
		TGUI.item(l, "Pipe temperature", TGUI.kelvin(n.temp), TGUI.INFO if pm.freezer else TGUI.AVERAGE)
		TGUI.item(l, "Pipe pressure", TGUI.kpa(n.pressure()))
	else:
		TGUI.item(l, "Pipe", "not connected", TGUI.LABEL)
	var t := TGUI.row(null, 4)
	t.add_child(TGUI.NumberInput.new(pm.target_temp, CPipeMachine.TEMP_RANGE[0], CPipeMachine.TEMP_RANGE[1], 1.0, "K", func(v): pm.adjust("temp", v, p)))
	TGUI.button(t, "Min", func(): pm.adjust("temp", CPipeMachine.TEMP_RANGE[0], p), false, not ok)
	TGUI.button(t, "Max", func(): pm.adjust("temp", CPipeMachine.TEMP_RANGE[1], p), false, not ok)
	TGUI.button(t, "Reset", func(): pm.adjust("temp", Defs.T20C, p), false, not ok)
	TGUI.item_ctrl(l, "Target", t)
	TGUI.item(l, "", "%.0f°C" % (pm.target_temp - Defs.T0C), TGUI.LABEL)
	if n:
		_net_block(TGUI.section(body, "Pipe contents"), n)

static func _net_block(parent: Control, n) -> void:
	var l := TGUI.list(parent)
	TGUI.item(l, "Pressure", TGUI.kpa(n.pressure()), UITheme.ACCENT)
	TGUI.item(l, "Temperature", TGUI.kelvin(n.temp))
	TGUI.gasmix(parent, n.gas)

static func _air_supply(asu: CAirSupply, body: VBoxContainer, p: Entity) -> void:
	var nets = Game.pipes.nets_on_layer(StationMap.PL_SUPPLY)
	var np: float = nets[0].pressure() if not nets.is_empty() else 0.0
	var s := TGUI.section(body, "Distribution", [_status_pill(asu.working(), "Running", "Stopped", TGUI.GOOD)])
	var l := TGUI.list(s)
	TGUI.item_ctrl(l, "Loop pressure", TGUI.ranged_bar(np, asu.target_kpa * 1.5, "%s  (target %.0f)" % [TGUI.kpa(np), asu.target_kpa], [asu.target_kpa * 0.8, asu.target_kpa * 1.3], [asu.target_kpa * 0.4, asu.target_kpa * 1.6]))
	TGUI.item_ctrl(l, "Oxygen reserve", TGUI.ranged_bar(asu.o2_reserve, 40000.0, "%.0f mol" % asu.o2_reserve, [10000, 1e9], [5000, 10000]))
	TGUI.item_ctrl(l, "Nitrogen reserve", TGUI.ranged_bar(asu.n2_reserve, 150000.0, "%.0f mol" % asu.n2_reserve, [20000, 1e9], [8000, 20000]))
	TGUI.item_ctrl(l, "Power", TGUI.choice(null, [["On", true], ["Off", false]], asu.on, func(v): asu.on = v))
	TGUI.item_ctrl(l, "Target", TGUI.stepper(null, asu.target_kpa, [["-25", asu.target_kpa - 25.0], ["+25", asu.target_kpa + 25.0]], "%.0f kPa", func(v): asu.target_kpa = clampf(v, 100.0, 600.0)))
	TGUI.notice(body, "Feed it rime-ice chunks cut from the high sky to replenish oxygen.", "info")

## tg SpaceHeater: power, the cell, the room's temperature, the target and the mode.
static func _space_heater(sh: CSpaceHeater, body: VBoxContainer, p: Entity) -> void:
	var s := TGUI.section(body, "Power", [UITheme.label({"heat": "Heating", "cool": "Cooling"}.get(sh.mode, "Standby"), UITheme.SMALL, {"heat": Color("#ff8a3a"), "cool": Color("#5ac8ff")}.get(sh.mode, TGUI.LABEL))])
	var l := TGUI.list(s)
	TGUI.item_ctrl(l, "Power", TGUI.choice(null, [["On", true], ["Off", false]], sh.on, func(v): sh.set_on(v, p)))
	var pct := sh.charge / CSpaceHeater.CAPACITY
	TGUI.item_ctrl(l, "Cell", TGUI.ranged_bar(pct, 1.0, "%d%%" % roundi(pct * 100.0), [0.5, 1.0], [0.15, 0.5]))
	var t := TGUI.section(body, "Temperature")
	var tl := TGUI.list(t)
	var here: float = Game.atmos.temp_at(sh.e.cell) if Game.atmos else Defs.T20C
	TGUI.item(tl, "Current", "%.1f°C" % (here - Defs.T0C), TGUI.ranged(here - Defs.T0C, [15, 30], [5, 40]))
	var lo := CSpaceHeater.T_MEDIAN - CSpaceHeater.T_RANGE
	var hi := CSpaceHeater.T_MEDIAN + CSpaceHeater.T_RANGE
	TGUI.item_ctrl(tl, "Target", TGUI.stepper(null, sh.target - Defs.T0C, [["-5", sh.target - 5.0], ["-1", sh.target - 1.0], ["+1", sh.target + 1.0], ["+5", sh.target + 5.0]], "%.0f°C", func(v): sh.target = clampf(v, lo, hi)))
	TGUI.item_ctrl(tl, "Mode", TGUI.choice(null, [["Auto", "auto"], ["Heat", "heat"], ["Cool", "cool"]], sh.set_mode, func(v): sh.set_mode = v))

# ============================================================================ power
## tg Apc: main breaker and cell, then each channel with Auto / On / Off.
static func _apc(apc: CApc, body: VBoxContainer, p: Entity) -> void:
	var a := apc.area_ref
	var s := TGUI.section(body, "Power status", [_status_pill(apc.grid_ok, "External: good", "External: none", TGUI.AVERAGE)])
	var l := TGUI.list(s)
	TGUI.item_ctrl(l, "Main breaker", TGUI.choice(null, [["On", true], ["Off", false]], apc.breaker, func(v): if v != apc.breaker: apc.toggle_breaker(p)))
	var pct := apc.charge / apc.capacity
	TGUI.item_ctrl(l, "Power cell", TGUI.ranged_bar(pct, 1.0, "%d%%  ·  %s" % [roundi(pct * 100.0), "charging" if apc.charging else ("full" if pct > 0.99 else ("draining" if not apc.grid_ok else "idle"))], [0.5, 1.0], [0.15, 0.5]))
	TGUI.item(l, "Load", TGUI.kw(apc.last_load_w))
	var c := TGUI.section(body, "Power channels")
	var cl := TGUI.list(c)
	for ch in [["equip", "Equipment", a.power_equip], ["light", "Lighting", a.power_light], ["environ", "Environment", a.power_environ]]:
		var chn: String = ch[0]
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		var st := UITheme.label("On " if ch[2] else "Off", UITheme.SMALL, TGUI.GOOD if ch[2] else TGUI.BAD)
		st.custom_minimum_size = Vector2(34, 0)
		r.add_child(st)
		TGUI.choice(r, [["Auto", "auto"], ["On", "on"], ["Off", "off"]], apc.modes[chn], func(v):
			apc.modes[chn] = v
			apc.update_channels())
		TGUI.item_ctrl(cl, ch[1], r)

## tg Smes, and the portable generator.
static func _power(pg: CPowerGen, body: VBoxContainer, p: Entity) -> void:
	if pg.kind == "smes":
		var pct := pg.charge / pg.capacity
		var s := TGUI.section(body, "Stored energy")
		s.add_child(TGUI.ranged_bar(pct, 1.0, "%d%%  ·  %.1f MJ" % [roundi(pct * 100.0), pg.charge / 1000.0], [0.5, 1.0], [0.15, 0.5]))
		var i := TGUI.section(body, "Input")
		var il := TGUI.list(i)
		TGUI.item_ctrl(il, "Charge mode", TGUI.choice(null, [["Auto", true], ["Off", false]], pg.charge_on, func(v): pg.charge_on = v))
		TGUI.item(il, "Charging at", TGUI.kw(pg.last_in), TGUI.GOOD if pg.last_in > 0 else TGUI.LABEL)
		var o := TGUI.section(body, "Output")
		var ol := TGUI.list(o)
		TGUI.item_ctrl(ol, "Output", TGUI.choice(null, [["On", true], ["Off", false]], pg.output_on, func(v): pg.output_on = v))
		TGUI.item(ol, "Supplying", TGUI.kw(pg.last_out), TGUI.GOOD if pg.last_out > 0 else TGUI.LABEL)
	else:
		var s2 := TGUI.section(body, "Generator")
		var l2 := TGUI.list(s2)
		TGUI.item(l2, "Output", TGUI.kw(pg.output_w), TGUI.GOOD if pg.output_w > 0 else TGUI.LABEL)
	var g := TGUI.section(body, "Grid")
	g.add_child(UITheme.label(Game.power.summary(), UITheme.SMALL, TGUI.LABEL))

static func _reactor(rc: CReactor, body: VBoxContainer, p: Entity) -> void:
	_reactor_core(rc, body, true, p)

static func _reactor_core(rc: CReactor, body: VBoxContainer, controls: bool, p: Entity) -> void:
	var s := TGUI.section(body, "Reactor core", [_status_pill(not rc.scrammed, "Running", "SCRAMMED", TGUI.BAD)])
	var l := TGUI.list(s)
	TGUI.item_ctrl(l, "Core temperature", TGUI.ranged_bar(rc.core_temp, CReactor.MELT_T, "%.0f K" % rc.core_temp, [0, CReactor.WARN_T], [CReactor.WARN_T, CReactor.DANGER_T]))
	TGUI.item_ctrl(l, "Integrity", TGUI.ranged_bar(rc.integrity, 100.0, "%.0f%%" % rc.integrity, [80, 100], [40, 80]))
	TGUI.item_ctrl(l, "Fuel", TGUI.ranged_bar(rc.fuel, 1.0, "%d%%" % roundi(rc.fuel * 100.0), [0.3, 1.0], [0.1, 0.3]))
	TGUI.item_ctrl(l, "Control rods", TGUI.bar(rc.rods, 1.0, "%d%% in  (target %d%%)" % [roundi(rc.rods * 100.0), roundi(rc.rod_target * 100.0)], TGUI.INFO))
	TGUI.item(l, "Heat", "%.0f kW made  ·  %.0f kW to coolant" % [rc.heat_out_kw, rc.transfer_kw])
	if rc.core_temp > CReactor.DANGER_T:
		TGUI.notice(s, "Core temperature critical. Insert the rods or SCRAM.", "bad")
	elif rc.core_temp > CReactor.WARN_T:
		TGUI.notice(s, "Core running hot.", "warn")
	if controls:
		var r := TGUI.row(s)
		TGUI.button(r, "Rods in +10%", func(): rc.rod_target = minf(1.0, rc.rod_target + 0.1))
		TGUI.button(r, "Rods out -10%", func(): rc.rod_target = maxf(0.0, rc.rod_target - 0.1))
		TGUI.button(r, "Reset SCRAM" if rc.scrammed else "SCRAM", func(): rc.scrammed = not rc.scrammed, false, false, TGUI.BAD if not rc.scrammed else TGUI.GOOD)

# ============================================================================ bits
static func _status_pill(on: bool, on_txt: String, off_txt: String, off_col: Color) -> Label:
	var l := UITheme.label(on_txt if on else off_txt, UITheme.SMALL, TGUI.GOOD if on else off_col)
	return l
