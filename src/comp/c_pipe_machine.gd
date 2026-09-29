class_name CPipeMachine extends Component
## tg's atmos pipe machines, built into a pipe run (binary / trinary devices) or sitting on
## one (the thermomachine). An inline machine splits the run into an input net and an
## output net and moves gas between them:
##   "pump"    pressure pump: pushes gas out until the output reaches its target (0-4500 kPa)
##   "vpump"   volume pump: moves a set volume of the input's gas each second (0-200 L/s)
##   "valve"   manual valve: open, the two sides share their gas; closed, nothing passes
##   "filter"  gas filter: the chosen gas goes out the side port, everything else on through
##   "thermo"  heater / freezer: heats or cools the pipe's gas toward its target temperature
## Click to open its controls; atmos access is needed to change them.

var kind := "pump"
var layer := StationMap.PL_SUPPLY
var on := true
var target_pressure := Defs.ONE_ATMOS # pump
var rate := 200.0 # vpump, L/s (also the filter's throughput)
var filter_gas := -1 # filter: the first gas it filters, -1 = none (kept for old callers)
var filters: Array = [] # filter: every gas it sends out the side (tg filters take several)
var target_temp := Defs.T20C # thermo
var freezer := false
var heat_power := 80000.0 # thermo, W
var node1_conc := 0.5 # mixer: share taken from the in-line input (node 1); node 2 gives the rest
var display := "" # tg's name for it, "Air to Distro"...
# the ports, as offsets from the machine's cell
var dir_in := Vector2i.ZERO
var dir_out := Vector2i.ZERO
var dir_side := Vector2i.ZERO
var moved_last := 0.0 # moles last tick, for the readout

const MAX_PRESSURE := 4500.0
const MAX_RATE := 200.0
const TEMP_RANGE := [73.15, 593.15] # tg thermomachine limits

func key() -> StringName:
	return &"pipemachine"

func setup(p: Dictionary) -> CPipeMachine:
	kind = p.get("kind", kind)
	layer = p.get("layer", layer)
	on = p.get("on", on)
	target_pressure = p.get("target", target_pressure)
	freezer = p.get("freezer", freezer)
	if freezer:
		target_temp = TEMP_RANGE[0]
	filter_gas = p.get("gas", filter_gas)
	filters = [filter_gas] if filter_gas >= 0 else []
	node1_conc = p.get("node1", node1_conc)
	rate = p.get("rate", rate)
	display = p.get("display", display)
	return self

func on_added() -> void:
	# after spawning has put us on the map (and mapgen has set our ports)
	_register.call_deferred()

func _register() -> void:
	if e == null or e.removed:
		return
	if Game.pipes:
		Game.pipes.register_machine(e)
	_refresh_sprite()

func on_removed() -> void:
	if Game.pipes:
		Game.pipes.unregister_machine(e)

func inline() -> bool:
	return kind != "thermo"

func working() -> bool:
	if not on:
		return false
	if kind == "valve":
		return true
	var m: CMachine = e.c(&"machine")
	return m == null or m.operable()

func layer_name() -> String:
	match layer:
		StationMap.PL_SUPPLY, StationMap.PL_HOT: return "supply"
		StationMap.PL_SCRUB, StationMap.PL_COLD: return "scrub"
		StationMap.PL_AUX: return "aux"
	return "gen"

func _refresh_sprite() -> void:
	if e == null or e.removed:
		return
	if kind == "thermo":
		e.set_sprite("objects", "thermo_%s_%s" % ["freezer" if freezer else "heater", "on" if on else "off"])
	else:
		var art: String = {"pvalve": "gate"}.get(kind, kind)
		e.set_sprite("objects", "%s_%s_%s" % [art, layer_name(), "on" if on else "off"])

func net_in():
	return Game.pipes.net_facing(layer, e.cell + dir_in, -dir_in) if Game.pipes else null

func net_out():
	return Game.pipes.net_facing(layer, e.cell + dir_out, -dir_out) if Game.pipes else null

func net_side():
	return Game.pipes.net_facing(layer, e.cell + dir_side, -dir_side) if Game.pipes and dir_side != Vector2i.ZERO else null

## One pipe tick (from PipeSystem).
func process(dt: float) -> void:
	moved_last = 0.0
	if not working():
		return
	var a = net_in()
	var b = net_out()
	match kind:
		"pump":
			if a == null or b == null:
				return
			var pb: float = b.pressure()
			if pb >= target_pressure:
				return
			var t := maxf(a.temp, 2.7)
			var want: float = (target_pressure - pb) * b.volume / (Defs.R_IDEAL * t)
			var total: float = a.total_moles()
			if total <= 0.001:
				return
			moved_last = PipeSystem.transfer(a, b, minf(want, total * 0.5) / total)
		"vpump":
			if a == null or b == null or b.pressure() > 9000.0:
				return
			moved_last = PipeSystem.transfer(a, b, clampf(rate * dt / a.volume, 0.0, 0.5))
		"valve":
			if a == null or b == null or a == b:
				return
			# share toward equal pressure
			var pa: float = a.pressure()
			var pbv: float = b.pressure()
			var hi = a if pa > pbv else b
			var lo = b if pa > pbv else a
			var ph: float = hi.pressure()
			if ph <= 0.01:
				return
			var dp: float = absf(pa - pbv)
			var f: float = clampf(dp * lo.volume / (ph * (hi.volume + lo.volume)), 0.0, 0.5)
			moved_last = PipeSystem.transfer(hi, lo, f)
		"filter":
			var s = net_side()
			if a == null or b == null:
				return
			var f2: float = clampf(rate * dt / a.volume, 0.0, 0.5)
			if s != null and s.pressure() < MAX_PRESSURE:
				for g in filters:
					moved_last += PipeSystem.transfer(a, s, f2, g)
			if b.pressure() < MAX_PRESSURE:
				for g in Defs.GAS_COUNT:
					if s == null or not g in filters:
						moved_last += PipeSystem.transfer(a, b, f2, g)
		"mixer":
			# tg trinary/mixer: fill the output toward target, node1:node2 by moles
			var a2 = net_side()
			if a == null or a2 == null or b == null:
				return
			var pout: float = b.pressure()
			if pout >= target_pressure:
				return
			var general: float = (target_pressure - pout) * b.volume / Defs.R_IDEAL
			var c1: float = a.heat_capacity()
			var c2: float = a2.heat_capacity()
			if c1 + c2 <= 0.0:
				return
			var t_eq: float = (a.temp * c1 + a2.temp * c2) / (c1 + c2)
			if t_eq <= 0.0:
				return
			var m1: float = node1_conc * general / t_eq
			var m2: float = (1.0 - node1_conc) * general / t_eq
			var have1: float = a.total_moles()
			var have2: float = a2.total_moles()
			if node1_conc <= 0.0:
				m2 = minf(m2, have2)
			elif node1_conc >= 1.0:
				m1 = minf(m1, have1)
			else:
				if m1 <= 0.0 or m2 <= 0.0 or have1 < 0.001 or have2 < 0.001:
					return
				var ratio := minf(have1 / m1, have2 / m2)
				if ratio < 1.0:
					m1 *= ratio
					m2 *= ratio
			if m1 > 0.0 and have1 > 0.0:
				moved_last += PipeSystem.transfer(a, b, minf(m1 / have1, 1.0))
			if m2 > 0.0 and have2 > 0.0:
				moved_last += PipeSystem.transfer(a2, b, minf(m2 / have2, 1.0))
		"gate":
			# tg passive_gate: lets gas through one way, never more than equalising, up to target
			if a == null or b == null:
				return
			var pa: float = a.pressure()
			var pb2: float = b.pressure()
			if pa <= pb2 or pb2 >= target_pressure:
				return
			var dp: float = minf((pa - pb2) * 0.5, target_pressure - pb2)
			var tot: float = a.total_moles()
			if tot <= 0.001:
				return
			var want2: float = dp * b.volume / (Defs.R_IDEAL * maxf(a.temp, 2.7))
			moved_last = PipeSystem.transfer(a, b, minf(want2 / tot, 0.5))
		"pvalve":
			# tg pressure_valve: open while the input is over the set pressure
			if a == null or b == null or a.pressure() <= target_pressure:
				return
			var pa3: float = a.pressure()
			var pb3: float = b.pressure()
			if pa3 <= pb3:
				return
			var f3: float = clampf((pa3 - pb3) * b.volume / (pa3 * (a.volume + b.volume)), 0.0, 0.5)
			moved_last = PipeSystem.transfer(a, b, f3)
		"thermo":
			var n = net_in()
			if n == null:
				return
			var cap: float = n.heat_capacity()
			if cap < 0.5:
				return
			var dT: float = target_temp - n.temp
			if (freezer and dT >= 0.0) or (not freezer and dT <= 0.0):
				return
			var j: float = clampf(dT * cap, -heat_power * dt, heat_power * dt)
			n.add_heat(j)
			var m: CMachine = e.c(&"machine")
			if m:
				m.active = absf(j) > 1.0

func attack_hand(user: Entity) -> bool:
	Bus.ui_open_window.emit("pipe_machine", e)
	return true

func can_control(user: Entity) -> bool:
	if user == null:
		return true
	var inv = user.c(&"inv")
	return inv != null and (inv.has_access("atmos") or inv.has_access("engineering"))

func set_on(v: bool, user: Entity) -> void:
	if user and not can_control(user):
		Game.tell(user, "Access denied.", "warn")
		Sfx.play("deny", e.cell, 0.5)
		return
	on = v
	_refresh_sprite()
	Sfx.play("click", e.cell, 0.5)
	if user:
		Game.visible_message(e.cell, "%s turns %s %s." % [user.display_name, e.the(), "on" if on else "off"] if kind != "valve" else "%s %s %s." % [user.display_name, "opens" if on else "closes", e.the()])

func adjust(field: String, v: float, user: Entity) -> void:
	if user and not can_control(user):
		Game.tell(user, "Access denied.", "warn")
		return
	match field:
		"target":
			target_pressure = clampf(v, 0.0, MAX_PRESSURE)
		"rate":
			rate = clampf(v, 0.0, MAX_RATE)
		"temp":
			target_temp = clampf(v, TEMP_RANGE[0], TEMP_RANGE[1])
		"gas":
			# a single gas, or -1 for none
			filters = [int(v)] if int(v) >= 0 else []
			filter_gas = int(v)
		"gas_toggle":
			var g := int(v)
			if g in filters:
				filters.erase(g)
			else:
				filters.append(g)
			filter_gas = filters[0] if not filters.is_empty() else -1
		"node1":
			node1_conc = clampf(v, 0.0, 1.0)
	Sfx.play("click", e.cell, 0.3)

## tg ALT-click: max it out (pressure 4500 kPa / rate 200 L/s).
func max_out(user: Entity) -> void:
	if user and not can_control(user):
		Game.tell(user, "Access denied.", "warn")
		return
	match kind:
		"pump", "mixer", "gate", "pvalve":
			target_pressure = MAX_PRESSURE
			Game.tell(user, "You set %s's output to %.0f kPa." % [e.the(), target_pressure])
		"vpump", "filter":
			rate = MAX_RATE
			Game.tell(user, "You set %s to %.0f L/s." % [e.the(), rate])
		"thermo":
			target_temp = TEMP_RANGE[0] if freezer else TEMP_RANGE[1]
			Game.tell(user, "You set %s to %.0f K." % [e.the(), target_temp])
	Sfx.play("click", e.cell, 0.3)

func examine(_user: Entity, lines: Array) -> void:
	var a = net_in()
	var b = net_out()
	match kind:
		"pump":
			lines.append("Pressure pump, %s. Target %.0f kPa." % ["on" if on else "off", target_pressure])
		"vpump":
			lines.append("Volume pump, %s. %.0f L/s." % ["on" if on else "off", rate])
		"valve":
			lines.append("The valve is %s." % ("OPEN" if on else "closed"))
		"filter":
			lines.append("Gas filter, %s, filtering %s." % ["on" if on else "off", Defs.GAS_NAMES[filter_gas] if filter_gas >= 0 else "nothing"])
		"mixer":
			lines.append("Gas mixer, %s. Output %.0f kPa; node 1 %d%%, node 2 %d%%." % ["on" if on else "off", target_pressure, roundi(node1_conc * 100.0), roundi((1.0 - node1_conc) * 100.0)])
		"gate":
			lines.append("Passive gate, %s. Lets gas through one way up to %.0f kPa." % ["on" if on else "off", target_pressure])
		"pvalve":
			lines.append("Pressure valve, %s. Opens above %.0f kPa on its input." % ["on" if on else "off", target_pressure])
		"thermo":
			var n = net_in()
			lines.append("%s, %s. Target %.0f K (%.0f°C); the pipe is at %.0f K." % ["Freezer" if freezer else "Heater", "on" if on else "off", target_temp, target_temp - Defs.T0C, n.temp if n else 0.0])
	if display != "":
		lines.insert(0, "It's labelled \"%s\"." % display)
	if inline() and a and b:
		lines.append("In: %.0f kPa   Out: %.0f kPa" % [a.pressure(), b.pressure()])
