class_name CConsole extends Component
## Computer consoles. Using one gives the user job knowledge (tg: crew monitor,
## station alert console, power monitor, reactor monitor...). The same data drives the
## player's UI window and NPC knowledge, so NPCs only know what their console shows.

var kind := "eng"
var tank := "" # "tank" consoles: the gas chamber they run (tg atmos_control/*_tank)

func key() -> StringName:
	return &"console"

func setup(p: Dictionary) -> CConsole:
	kind = p.get("kind", kind)
	tank = p.get("tank", tank)
	return self

func operable() -> bool:
	var m: CMachine = e.c(&"machine")
	return m == null or m.operable()

const TANK_NAMES := {"n2": "Nitrogen", "o2": "Oxygen", "co2": "Carbon Dioxide", "plasma": "Plasma", "n2o": "Nitrous Oxide", "air": "Mixed Air", "mix": "Gas Mix", "h2o": "Water Vapour"}

func title() -> String:
	if kind == "tank":
		return "%s Supply Control" % TANK_NAMES.get(tank, "Tank")
	return {"reactor": "Reactor Monitoring", "eng": "Power Monitoring", "atmos": "Ship Alert Console", "med": "Crew Monitoring",
		"sec": "Watch Records", "cargo": "Hold Ledger", "cmd": "Bridge Console", "comms": "Signal Console", "sci": "Artificer's Console", "pod": "Lifeboat Launch Control", "desk": "Desk Engine"}.get(kind, "Console")

## Structured readout. Each entry: {"text": String, "fact": Dictionary or {}}
func readout() -> Array:
	var out := []
	if not operable():
		return out
	match kind:
		"reactor":
			for r in Game.all_with(&"reactor"):
				var rc: CReactor = r.c(&"reactor")
				var sev := 0
				if rc.core_temp > CReactor.WARN_T: sev = 1
				if rc.core_temp > CReactor.DANGER_T: sev = 2
				out.append({"text": rc.status_text(), "fact": {"type": "reactor_hot" if sev > 0 else "reactor_ok", "key": "reactor_hot", "subject": r.id, "cell": r.cell, "severity": sev, "data": {"temp": rc.core_temp, "integrity": rc.integrity}}})
			for net in Game.pipes.nets_on_layer(StationMap.PL_HOT):
				out.append({"text": "Hot loop: %.0f kPa, %.0f K, %.0f mol" % [net.pressure(), net.temp, net.total_moles()], "fact": {}})
				if net.total_moles() < 800:
					out.append({"text": "[color=#ff5a4a]Coolant pressure low: check the hot loop for leaks.[/color]", "fact": {"type": "coolant_low", "key": "coolant_low", "cell": e.cell, "severity": 2}})
			for net in Game.pipes.nets_on_layer(StationMap.PL_COLD):
				out.append({"text": "Cold loop: %.0f kPa, %.0f K" % [net.pressure(), net.temp], "fact": {}})
			for g in Game.all_with(&"powergen"):
				if g.c(&"powergen").kind == "teg":
					out.append({"text": "Thermoelectric output: %.1f kW" % (g.c(&"powergen").output_w / 1000.0), "fact": {}})
		"eng":
			out.append({"text": Game.power.summary(), "fact": {}})
			for a in Game.map.areas:
				if a.apc == null:
					continue
				var apc: CApc = a.apc.c(&"apc")
				var dead = not (a.power_equip or a.power_light or a.power_environ)
				var line := "%-22s %3d%%  %5.1f kW %s" % [a.name, int(apc.charge / apc.capacity * 100), apc.last_load_w / 1000.0, "[color=#ff5a4a]OFFLINE[/color]" if dead else ("" if apc.grid_ok else "[color=#ffb84a]battery[/color]")]
				var f := {}
				if dead or not apc.grid_ok:
					f = {"type": "power_out", "key": "power_out:%d" % a.id, "subject": a.apc.id, "cell": a.apc.cell, "area": a.id, "severity": 2 if dead else 1}
				out.append({"text": line, "fact": f})
		"tank":
			# tg atmos_control: the chamber's air, and its input injector / output siphon
			var mon := "" if tank == "mix" else tank
			var chamber: Area = null
			for d in Game.all_with(&"vent"):
				var v: CVent = d.c(&"vent")
				if v.monitored == mon and v.mode in ["injector", "siphon"]:
					var a := Game.map.area_at(d.cell)
					if a.room_kind == "gas_chamber":
						chamber = a
					out.append({"text": "%s: %s" % ["Input injector" if v.mode == "injector" else "Output inlet", "[color=#5ad87a]ON[/color]" if v.on else "[color=#888]off[/color]"], "fact": {}})
			if chamber and not chamber.cells.is_empty():
				var i := Game.map.idx(chamber.cells[chamber.cells.size() / 2])
				out.push_front({"text": "Chamber: %.0f kPa, %.0f K" % [Game.atmos.pressure(i), Game.atmos.temp[i]], "fact": {}})
				var tot: float = Game.atmos.total_moles(i)
				if tot > 0.01:
					for g in Defs.GAS_COUNT:
						var mol: float = Game.atmos.gas[g][i]
						if mol / tot > 0.005:
							out.insert(1, {"text": "  %s %.0f%%" % [Defs.GAS_NAMES[g], mol / tot * 100.0], "fact": {}})
		"atmos":
			for al in StationAlerts.active.values():
				out.append({"text": "[color=#ffb84a]%s[/color]" % al["text"], "fact": al["fact"]})
			for d in Game.map.damaged_pipes():
				if Game.map.pipe_leaking(d[0], d[1]):
					out.append({"text": "Pressure drop detected: %s loop near %s" % [StationMap.PIPE_LAYER_NAMES[d[0]], Game.map.area_at(d[1]).name],
						"fact": {"type": "pipe_leak", "key": "pipe_leak:%d:%d" % [d[0], Game.map.idx(d[1])], "cell": d[1], "data": {"layer": d[0]}, "severity": 2 if d[0] == StationMap.PL_HOT else 1}})
			for s in Game.all_with(&"air_supply"):
				var asu: CAirSupply = s.c(&"air_supply")
				out.append({"text": "Air reserves: O2 %.0f mol, N2 %.0f mol" % [asu.o2_reserve, asu.n2_reserve], "fact": {"type": "air_low", "key": "air_low", "subject": s.id, "cell": s.cell, "severity": 1} if asu.o2_reserve < 5000 else {}})
			if out.is_empty():
				out.append({"text": "No active alerts.", "fact": {}})
		"med":
			for m in Game.all_with(&"mob"):
				var h: CHealth = m.c(&"health")
				if h == null or m.c(&"mob").job == "":
					continue
				var sev := h.severity()
				var loc := Game.map.area_at(m.root_cell()).name
				var st = ["[color=#5ad87a]healthy[/color]", "[color=#b8d84a]scratched[/color]", "[color=#e8c83a]injured[/color]", "[color=#e8803a]badly hurt[/color]", "[color=#ff3a3a]CRITICAL[/color]", "[color=#888]DECEASED[/color]"][sev]
				var f := {}
				if sev >= 2:
					f = {"type": "injured" if sev < 5 else "body", "key": ("injured:%d" if sev < 5 else "body:%d") % m.id, "subject": m.id, "cell": m.root_cell(), "severity": sev}
				out.append({"text": "%-24s %-14s %s" % [m.display_name, loc, st], "fact": f})
		"sec":
			for rec in SecurityRecords.wanted.values():
				out.append({"text": "[color=#ff5a4a]WANTED[/color] %s - %s" % [rec["name"], rec["crime"]], "fact": {"type": "wanted", "key": "wanted:%d" % rec["id"], "subject": rec["id"], "cell": Vector2i.ZERO, "severity": 2}})
			if SecurityRecords.wanted.is_empty():
				out.append({"text": "No outstanding warrants.", "fact": {}})
		"cargo":
			for r in Cargo.requests:
				out.append({"text": "Request: %s for %s" % [r["what"], r["dept"]], "fact": {}})
			out.append({"text": "Hold budget: %d marks. %s" % [Cargo.points, Cargo.status_text()], "fact": {}})
		"sci":
			out.append({"text": "Research progress: %.0f points" % Research.points, "fact": {}})
		"pod":
			var ev = Game.evac
			var err: String = ev.can_launch_pod() if ev else "Offline."
			out.append({"text": "Lifeboat. Seats six. Launches on its own when the ferry leaves.", "fact": {}})
			out.append({"text": "[color=#6ae88a]Launch clamps released.[/color]" if err == "" else "[color=#ffb84a]%s[/color]" % err, "fact": {}})
		"desk":
			# tg modular computer: the NtOS home screen's crew manifest and station status
			out.append({"text": "[b]Ship's ledger[/b]  Ship's time %s. Alert state %s." % [Game.clock_string(), Game.ALERT_NAMES[Game.alert_level]], "fact": {}})
			if Game.evac:
				out.append({"text": Game.evac.status_text(), "fact": {}})
			out.append({"text": "Hold budget: %d marks. Research: %.0f points." % [Cargo.points, Research.points], "fact": {}})
			out.append({"text": "[b]Crew manifest[/b]", "fact": {}})
			for m in Game.all_with(&"mob"):
				if m.c(&"mob").job != "":
					out.append({"text": "  %-24s %s" % [m.display_name, Jobs.title(m.c(&"mob").job)], "fact": {}})
		"comms":
			out.append({"text": "Ship's time %s. Alert state %s." % [Game.clock_string(), Game.ALERT_NAMES[Game.alert_level]], "fact": {}})
			if Game.evac:
				out.append({"text": "[b]%s[/b]" % Game.evac.status_text(), "fact": {}})
				if Game.evac.reason != "" and Game.evac.mode == Evac.CALLED:
					out.append({"text": "Reason given: %s" % Game.evac.reason, "fact": {}})
				if Game.evac.no_recall:
					out.append({"text": "[color=#ff5a4a]Recall signals jammed.[/color]", "fact": {}})
		_:
			out.append({"text": "Ship's time %s. Alert state %s." % [Game.clock_string(), Game.ALERT_NAMES[Game.alert_level]], "fact": {}})
	return out

func attack_hand(user: Entity) -> bool:
	if not operable():
		Game.tell(user, "The screen is dark.", "warn")
		return true
	# tg consoles with real controls get their own window
	match kind:
		"sci": Bus.ui_open_window.emit("rnd", e)
		"cargo": Bus.ui_open_window.emit("cargo", e)
		"sec": Bus.ui_open_window.emit("secrecords", e)
		"tank": Bus.ui_open_window.emit("tank_console", e)
		_: Bus.ui_open_window.emit("console", e)
	return true

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Use", "cb": attack_hand.bind(user), "priority": 7})

func ai_tags(out: Dictionary) -> void:
	out["console_" + kind] = true
