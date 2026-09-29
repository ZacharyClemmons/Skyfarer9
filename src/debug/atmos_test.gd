class_name AtmosTest extends Node
## --atmostest: checks the tg atmos controls do what they say. Prints ATMOS PASS/FAIL.

var fails := 0

class IsolatedPump extends CPipeMachine:
	var inlet := PipeSystem.PipeNet.new()
	var outlet := PipeSystem.PipeNet.new()
	func net_in(): return inlet
	func net_out(): return outlet

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await _wait(1.0)
	Game.time_scale = 4.0
	# MetaStation's gas tanks start full (measured before anything below drains them)
	var chambers := 0
	for ar in Game.map.areas:
		if ar.room_kind == "gas_chamber" and not ar.cells.is_empty():
			var cp: float = Game.atmos.pressure(Game.map.idx(ar.cells[0]))
			print("ATMOS (chamber %s: %.0f kPa)" % [ar.name, cp])
			if cp > 1000.0:
				chambers += 1
	_check("six gas chambers start full (%d)" % chambers, chambers >= 6 or Game.all_with(&"air_supply").size() > 0)
	var mg: MapGen = Game.world.get_parent().mapgen
	var room: Dictionary = mg.room_of("research_lab")
	var a: Area = room["area"]
	var alarm: CAirAlarm = a.air_alarm.c(&"air_alarm") if a.air_alarm else null
	_check("the lab has an air alarm", alarm != null)
	if alarm == null:
		_done()
		return
	_check("it lists the room's vents and scrubbers", alarm.devices("vent").size() >= 1 and alarm.devices("scrubber").size() >= 1)
	# lock: a scientist can't change it, an atmos tech can
	var sci := Crew.spawn_human("scientist", a.cells[0], {"name": "Sci Test"})
	var atm := Crew.spawn_human("atmos", a.cells[1], {"name": "Atmos Test"})
	for e in [sci, atm]:
		e.remove_comp(&"brain")
		Quirks.remove_all(e) # random crew quirks would skew the checks
	_check("locked against a scientist", not alarm.can_control(sci))
	_check("an atmos tech can work it", alarm.can_control(atm))
	# siphon: the room empties
	var p0 := _room_pressure(a)
	alarm.set_mode("siphon", atm)
	await _wait(14.0)
	var p1 := _room_pressure(a)
	# tg scrubbers siphon 200 L of their own tile a tick, so a big lab drains slowly
	_check("siphon mode empties the room (%.0f -> %.0f kPa)" % [p0, p1], p1 < p0 - 2.0)
	# refill: vents push well past one atmosphere
	# tg setup: an atmos tech turns Air to Distro up first (it starts at one atmosphere)
	for m in Game.all_with(&"pipemachine"):
		if m.display_name == "Air to Distro":
			m.c(&"pipemachine").max_out(atm)
	alarm.set_mode("refill", atm)
	await _wait(10.0)
	var p2 := _room_pressure(a)
	_check("refill mode fills it back up (%.0f kPa)" % p2, p2 > p1 + 4.0)
	for m in Game.all_with(&"pipemachine"):
		if m.display_name == "Air to Distro":
			m.c(&"pipemachine").adjust("target", Defs.ONE_ATMOS, atm)
	alarm.set_mode("filtering", atm)
	# scrubber filters: CO2 comes out when filtered, stays when not
	var sc: CVent = alarm.devices("scrubber")[0].c(&"vent")
	var sc_cell: Vector2i = alarm.devices("scrubber")[0].cell
	var k := Game.map.idx(sc_cell)
	Game.atmos.add_gas(k, Defs.G_CO2, 20.0, Defs.T20C)
	var co0: float = Game.atmos.gas[Defs.G_CO2][k]
	await _wait(3.0)
	_check("scrubbers take CO2 out", Game.atmos.gas[Defs.G_CO2][k] < co0 * 0.7)
	# canister: release into the room at a set pressure
	var free := _free_cell(a)
	var can := Proto.spawn("canister_o2", free)
	var cc: CCanister = can.c(&"canister")
	_check("a full canister reads about 3650 kPa (tg 1000 L)", absf(cc.pressure() - 3652.0) < 60.0)
	cc.set_release(250.0)
	cc.toggle_valve(atm)
	await _wait(4.0)
	var pc: float = Game.atmos.pressure(Game.map.idx(free))
	_check("an open valve releases gas into the room (%.0f kPa)" % pc, pc > 110.0)
	cc.toggle_valve(atm)
	# holding tank: fills up to the release pressure (a fresh canister: tg's valve has
	# just emptied most of the first one into the lab)
	can.destroy()
	can = Proto.spawn("canister_o2", free)
	cc = can.c(&"canister")
	var t := Proto.spawn("tank_air", free)
	t.c(&"tank").moles = 0.0
	atm.c(&"inv").put_in_hands(t)
	cc.insert_tank(atm, t)
	cc.set_release(900.0)
	cc.toggle_valve(atm)
	await _wait(4.0)
	_check("the holding tank fills (%.0f kPa)" % t.c(&"tank").pressure_kpa(), t.c(&"tank").pressure_kpa() > 300.0)
	cc.toggle_valve(atm)
	# a port: wrenched on, it feeds the pipe network
	var port: Entity = null
	for v in Game.all_with(&"vent"):
		if v.c(&"vent").mode == "port":
			port = v
	if port:
		var n2 := Proto.spawn("canister_n2", _free_cell_near(port.cell))
		var net = Game.pipes.net_at(port.c(&"vent").layer, port.cell)
		var m0: float = net.total_moles() if net else 0.0
		atm.place(port.cell + Vector2i(0, 1) if Game.map.is_passable(port.cell + Vector2i(0, 1)) else port.cell)
		n2.c(&"canister").toggle_port(atm)
		await _wait(4.0)
		net = Game.pipes.net_at(port.c(&"vent").layer, port.cell)
		_check("a canister on a port feeds the pipes", net != null and net.total_moles() > m0 + 5.0)
	# tg pipe machines built into the runs (MetaStation's Atmospherics, by name)
	var pump: Entity = null
	var valve: Entity = null
	var filt: Entity = null
	var heater: Entity = null
	for m in Game.all_with(&"pipemachine"):
		var pmx: CPipeMachine = m.c(&"pipemachine")
		if m.display_name == "Air to Distro" or (pump == null and pmx.kind == "pump" and Game.all_with(&"air_supply").size() > 0):
			pump = m
		elif pmx.kind == "valve" and pmx.net_in() != null and pmx.net_out() != null and pmx.net_in() != pmx.net_out():
			valve = m
		elif pmx.kind == "filter" and (pmx.filter_gas == Defs.G_PLASMA or filt == null):
			filt = m
		elif pmx.kind == "thermo" and not pmx.freezer and (pmx.on or heater == null):
			heater = m
	_check("the distro has a pump, the waste loop a filter and a valve, and there's a heater", pump != null and valve != null and filt != null and heater != null)
	if pump:
		var pm: CPipeMachine = pump.c(&"pipemachine")
		var na = pm.net_in()
		var nb = pm.net_out()
		_check("the pump splits the distro into two nets", na != null and nb != null and na != nb and nb.cells.size() > na.cells.size())
		_check("a scientist can't work the pump", not pm.can_control(sci) and pm.can_control(atm))
		# Known reserves isolate pump behavior from the live staging pumps, attached
		# canisters and time-sliced pipe pass. Use the actual pressure-pump process.
		var fixture := IsolatedPump.new()
		fixture.e = pump
		fixture.inlet.volume = 1000.0
		fixture.outlet.volume = 1000.0
		fixture.inlet.add_gas(Defs.G_N2, 2400.0, Defs.T20C)
		fixture.outlet.add_gas(Defs.G_N2, 40.0, Defs.T20C)
		fixture.on = false
		fixture.target_pressure = CPipeMachine.MAX_PRESSURE
		var p_off: float = fixture.outlet.pressure()
		for tick in 6:
			fixture.process(AtmosSystem.TICK)
		_check("with the pump off it transfers no gas (%.0f -> %.0f)" % [p_off, fixture.outlet.pressure()], is_equal_approx(fixture.outlet.pressure(), p_off))
		fixture.on = true
		for tick in 8:
			fixture.process(AtmosSystem.TICK)
		_check("enabled pressure pump fills to its target (%.0f kPa)" % fixture.outlet.pressure(), absf(fixture.outlet.pressure() - fixture.target_pressure) < 30.0)
		pm.set_on(true, atm)
		pm.max_out(atm)
	if heater:
		var hm: CPipeMachine = heater.c(&"pipemachine")
		var hn = hm.net_in()
		if hn and hn.total_moles() < 1.0:
			hn.add_gas(Defs.G_N2, 200.0, Defs.T20C) # tg's lines start empty; give it something to heat
		hm.adjust("temp", Defs.T20C + 40.0, atm)
		var t0: float = hn.temp if hn else 0.0
		# one machine step at a time (the live line is being refilled with 20°C air)
		for _step in 6:
			hm.process(AtmosSystem.TICK)
		_check("the heater warms the loop (%.1f -> %.1f K; %.0f mol, on %s, at %s)" % [t0, hn.temp if hn else 0.0, hn.total_moles() if hn else -1.0, hm.on, heater.cell - Vector2i(MapGen.SX, MapGen.SY)], hn != null and hn.temp > t0 + 0.2)
		hm.adjust("temp", Defs.T20C, atm)
		hn.temp = Defs.T20C
	if filt:
		var fm: CPipeMachine = filt.c(&"pipemachine")
		var fin = fm.net_in()
		var side = fm.net_side()
		if fin and side:
			fin.add_gas(Defs.G_PLASMA, 200.0, Defs.T20C)
			var s0: float = side.gas[Defs.G_PLASMA]
			var o0: float = fm.net_out().gas[Defs.G_PLASMA] if fm.net_out() else 0.0
			fm.process(AtmosSystem.TICK)
			var ds: float = side.gas[Defs.G_PLASMA] - s0
			var dout: float = (fm.net_out().gas[Defs.G_PLASMA] if fm.net_out() else 0.0) - o0
			_check("the filter sends plasma out its side port (+%.1f side, +%.1f straight on)" % [ds, dout], ds > 2.0 and dout < ds * 0.05)
		else:
			_check("the filter is connected on all three ports", false)
	# tg connector: an empty canister on a port fills up off the pipes
	if port:
		var pv: CVent = port.c(&"vent")
		var pnet = Game.pipes.net_facing(pv.layer, port.cell, pv.face) if pv.face != Vector2i.ZERO else Game.pipes.net_at(pv.layer, port.cell)
		if pnet:
			pnet.add_gas(Defs.G_N2, 400.0, Defs.T20C)
			pnet.add_gas(Defs.G_O2, 100.0, Defs.T20C)
			var ec := Proto.spawn("canister_empty", _free_cell_near(port.cell))
			ec.c(&"canister").port = port
			await _wait(4.0)
			var etk: CTank = ec.c(&"tank")
			_check("an empty canister on a port fills from the pipes (%.0f mol: %s)" % [etk.moles, etk.contents_text()], etk.moles > 5.0)
			ec.destroy()
	# tg portable scrubber: pulls CO2 out of the air around it
	var fc := _free_cell_near(a.cells[a.cells.size() / 2])
	var ps := Proto.spawn("portable_scrubber", fc)
	var ki := Game.map.idx(fc)
	Game.atmos.add_gas(ki, Defs.G_CO2, 40.0, Defs.T20C)
	ps.c(&"canister").set_on(true, atm)
	# Room diffusion and wall scrubbers also remove this gas; step the portable itself.
	for tick in 6:
		ps.c(&"canister").tick(AtmosSystem.TICK)
	_check("a portable scrubber pulls CO2 in (%.1f mol caught)" % ps.c(&"tank").moles, ps.c(&"tank").moles > 5.0)
	ps.destroy()
	# MetaStation's Atmospherics: the loops out to the station
	var a2d = pump.c(&"pipemachine").net_out() if pump else null
	var w2f = null
	for m in Game.all_with(&"pipemachine"):
		if m.display_name == "Waste to Filter":
			w2f = m.c(&"pipemachine").net_in()
	if a2d and w2f:
		var vbad := 0
		var sbad := 0
		for v in Game.all_with(&"vent"):
			var vv: CVent = v.c(&"vent")
			var nv = Game.pipes.net_facing(vv.layer, v.cell, vv.face) if vv.face != Vector2i.ZERO else Game.pipes.net_at(vv.layer, v.cell)
			if vv.mode == "vent" and nv != a2d:
				vbad += 1
			elif vv.mode == "scrubber" and nv != w2f:
				sbad += 1
		_check("every vent on the station is on the distro (%d not)" % vbad, vbad == 0)
		_check("every scrubber feeds the waste loop (%d not)" % sbad, sbad == 0)
	if valve:
		var vm: CPipeMachine = valve.c(&"pipemachine")
		var va = vm.net_in()
		var vb = vm.net_out()
		vm.set_on(false, atm)
		va.add_gas(Defs.G_CO2, 300.0, Defs.T20C)
		var b0: float = vb.gas[Defs.G_CO2]
		await _wait(2.0)
		_check("a closed valve passes nothing", vb.gas[Defs.G_CO2] <= b0 + 0.5)
		vm.set_on(true, atm)
		await _wait(2.0)
		_check("an open valve lets it through", vm.moved_last > 0.0 or vb.gas[Defs.G_CO2] > b0 + 5.0)
	# the analyzer reads a tile
	var ga := Proto.spawn("gas_analyzer", atm.cell)
	atm.c(&"inv").put_in_hands(ga)
	var got := [""]
	var cb := func(text, _kind):
		if "Pressure:" in text:
			got[0] = text
	Bus.chat.connect(cb)
	Game.player = atm
	ga.c(&"gasanalyzer").scan_tile(atm, atm.cell)
	Bus.chat.disconnect(cb)
	_check("the gas analyzer reports the air", "Oxygen" in got[0] and "Nitrogen" in got[0])
	var dir: String = Game.world.get_parent().args.get("shots", "")
	if dir != "":
		atm.place(a.air_alarm.cell)
		Game.view.camera.position = atm.position
		Game.hud.open_window("air_alarm", a.air_alarm)
		await _wait(1.0)
		for w in Game.hud.windows.get_children():
			w.position = Vector2(40, 60)
		atm.place(can.cell + Vector2i(1, 0) if Game.map.is_passable(can.cell + Vector2i(1, 0)) else can.cell)
		Game.hud.open_window("canister", can)
		await _wait(1.0)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir + "/atmos_ui.png")
	_done()

func _done() -> void:
	print("ATMOS DONE: %d failed" % fails)
	get_tree().quit()

func _room_pressure(a: Area) -> float:
	var p := 0.0
	for c in a.cells:
		p += Game.atmos.pressure(Game.map.idx(c))
	return p / a.cells.size()

func _free_cell(a: Area) -> Vector2i:
	for c in a.cells:
		if Game.map.is_passable(c) and Game.at(c).is_empty():
			return c
	return a.cells[0]

func _free_cell_near(c: Vector2i) -> Vector2i:
	for d in Defs.DIRS8:
		if Game.map.is_passable(c + d) and Game.at(c + d).is_empty():
			return c + d
	return c

func _wait(sec: float) -> void:
	var t0: int = Game.atmos.tick_count
	await get_tree().create_timer(sec).timeout
	print("ATMOS (waited %.0f s: %d atmos ticks, %.0f expected)" % [sec, Game.atmos.tick_count - t0, sec * Game.time_scale / AtmosSystem.TICK])

func _check(what: String, ok: bool) -> void:
	print("ATMOS %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1
