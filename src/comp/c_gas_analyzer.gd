class_name CGasAnalyzer extends Component
## tg's hand-held gas analyzer (/obj/item/analyzer): Z scans the air where you stand,
## clicking a tile scans it, and using it on a canister, tank, vent, scrubber or pipe
## port reads what's inside. Prints pressure, temperature and each gas as a share of
## the mix with its moles, like tg's atmos scan.

const GAS_NAMES := Defs.GAS_NAMES

func key() -> StringName:
	return &"gasanalyzer"

func attack_self(user: Entity) -> bool:
	scan_tile(user, user.cell)
	return true

func scan_tile(user: Entity, c: Vector2i) -> void:
	if Game.atmos == null or not Game.map.inb(c):
		return
	var i := Game.map.idx(c)
	var mix := PackedFloat32Array()
	mix.resize(Defs.GAS_COUNT)
	for g in Defs.GAS_COUNT:
		mix[g] = Game.atmos.gas[g][i]
	_report(user, "Results of analysis of %s" % Game.map.area_at(c).name, Game.atmos.pressure(i), Game.atmos.temp[i], mix)
	Sfx.play("click", user.cell, 0.5)
	Skills.add_xp(user, "atmos", 1.0)

func scan_entity(user: Entity, t: Entity) -> bool:
	if t.has_c(&"tank"):
		var tk: CTank = t.c(&"tank")
		var mix := PackedFloat32Array()
		mix.resize(Defs.GAS_COUNT)
		if tk.gas == "air":
			mix[Defs.G_O2] = tk.moles * 0.21
			mix[Defs.G_N2] = tk.moles * 0.79
		else:
			mix[CCanister.gas_index(tk.gas)] = tk.moles
		_report(user, "Results of analysis of %s" % t.the(), tk.pressure_kpa(), Defs.T20C, mix)
		return true
	if t.has_c(&"vent") and Game.pipes:
		var v: CVent = t.c(&"vent")
		var net = Game.pipes.net_at(v.layer, t.cell)
		if net == null:
			Game.tell(user, "%s isn't connected to anything." % t.the().capitalize(), "warn")
			return true
		_report(user, "Results of analysis of the pipe network behind %s" % t.the(), net.pressure(), net.temp, net.gas)
		return true
	return false

func _report(user: Entity, title: String, pressure: float, temp: float, mix: PackedFloat32Array) -> void:
	var total := 0.0
	for g in Defs.GAS_COUNT:
		total += mix[g]
	var lines := ["[b]%s[/b]" % title, "Pressure: %.2f kPa" % pressure]
	if total > 0.001:
		for g in Defs.GAS_COUNT:
			if mix[g] > 0.0005:
				lines.append("%s: %.1f %% (%.2f mol)" % [GAS_NAMES[g], mix[g] / total * 100.0, mix[g]])
		lines.append("Temperature: %.1f °C (%.1f K)" % [temp - Defs.T0C, temp])
	else:
		lines.append("[color=#8a9cb0]No gas detected.[/color]")
	Game.tell(user, "\n".join(lines), "examine")
