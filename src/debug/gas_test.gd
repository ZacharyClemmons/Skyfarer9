class_name GasTest extends Node
## --gastest: every tg gas reaction, fed a mixture tg's requirements say should react,
## checked for the right products and the right direction of heat. Plus the whole-map
## plumbing for rare gases: a new gas on a tile spreads to its neighbours, and a pipe
## network full of fuel and oxygen burns. Prints "GAS PASS/FAIL ..." and quits.

var fails := 0
var dir := ""

func _ready() -> void:
	_run.call_deferred()

func _check(what: String, ok: bool) -> void:
	print("GAS %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1

## Run one reaction step on a mix of {gas: moles} at `t` kelvin in `v` litres.
func _react(gases: Dictionary, t: float, v := 2500.0) -> Dictionary:
	var m := []
	m.resize(Defs.GAS_COUNT)
	m.fill(0.0)
	for g in gases:
		m[g] = gases[g]
	var ctx := {"m": m, "t": t, "v": v, "cell": Vector2i(-1, -1), "net": null}
	var res := GasReactions.react(ctx)
	return {"m": m, "t": ctx["t"], "res": res}

func _run() -> void:
	await get_tree().process_frame
	var r: Dictionary
	# --- fires
	r = _react({Defs.G_PLASMA: 10.0, Defs.G_O2: 150.0}, 600.0)
	_check("plasma burns in oxygen to CO2 and steam, hotter (%.0f K)" % r["t"], r["m"][Defs.G_PLASMA] < 10.0 and r["m"][Defs.G_CO2] > 0.0 and r["m"][Defs.G_H2O] > 0.0 and r["t"] > 600.0)
	r = _react({Defs.G_PLASMA: 1.0, Defs.G_O2: 200.0}, 600.0)
	_check("oxygen-rich plasma fire (O2:plasma >= 96) makes tritium", r["m"][Defs.G_TRITIUM] > 0.0)
	r = _react({Defs.G_HYDROGEN: 10.0, Defs.G_O2: 100.0}, 500.0)
	_check("hydrogen burns to water vapour, hotter", r["m"][Defs.G_HYDROGEN] < 10.0 and r["m"][Defs.G_H2O] > 0.0 and r["t"] > 500.0)
	r = _react({Defs.G_TRITIUM: 10.0, Defs.G_O2: 100.0}, 500.0)
	_check("tritium burns to water vapour, hotter", r["m"][Defs.G_TRITIUM] < 10.0 and r["m"][Defs.G_H2O] > 0.0 and r["t"] > 500.0)
	r = _react({Defs.G_FREON: 10.0, Defs.G_O2: 100.0}, 200.0)
	_check("freon + oxygen soaks up heat (200 -> %.0f K) and makes CO2" % r["t"], r["m"][Defs.G_CO2] > 0.0 and r["t"] < 200.0)
	r = _react({Defs.G_FREON: 10.0, Defs.G_O2: 100.0}, 300.0)
	_check("freon doesn't react above 283 K", r["res"].is_empty())
	# --- formations
	r = _react({Defs.G_O2: 20.0, Defs.G_N2: 40.0, Defs.G_BZ: 10.0}, 220.0)
	_check("N2O forms from O2 and N2 with BZ as the catalyst (200-250 K)", r["m"][Defs.G_N2O] > 0.0 and is_equal_approx(r["m"][Defs.G_BZ], 10.0))
	r = _react({Defs.G_N2O: 20.0}, 1500.0)
	_check("N2O breaks down into N2 and O2 above 1400 K", r["m"][Defs.G_N2O] < 20.0 and r["m"][Defs.G_N2] > 0.0 and r["m"][Defs.G_O2] > 0.0)
	r = _react({Defs.G_N2O: 20.0, Defs.G_PLASMA: 20.0}, 300.0)
	_check("BZ forms from N2O and plasma", r["m"][Defs.G_BZ] > 0.0)
	r = _react({Defs.G_N2O: 20.0, Defs.G_PLASMA: 20.0}, 400.0)
	_check("... but not above 313 K", r["m"][Defs.G_BZ] == 0.0)
	r = _react({Defs.G_CO2: 10.0, Defs.G_O2: 10.0, Defs.G_TRITIUM: 1.0}, 250.0)
	_check("pluoxium forms from CO2, O2 and a trace of tritium (50-273 K)", r["m"][Defs.G_PLUOXIUM] > 0.0 and r["m"][Defs.G_HYDROGEN] > 0.0)
	r = _react({Defs.G_TRITIUM: 30.0, Defs.G_N2: 30.0, Defs.G_BZ: 10.0}, 1600.0)
	_check("nitrium forms from tritium, N2 and BZ above 1500 K, cooling it", r["m"][Defs.G_NITRIUM] > 0.0 and r["t"] < 1600.0)
	r = _react({Defs.G_O2: 1.0, Defs.G_NITRIUM: 10.0}, 300.0)
	_check("nitrium decays to hydrogen and N2 with oxygen about (<343 K)", r["m"][Defs.G_NITRIUM] < 10.0 and r["m"][Defs.G_HYDROGEN] > 0.0)
	r = _react({Defs.G_PLASMA: 60.0, Defs.G_CO2: 30.0, Defs.G_BZ: 10.0}, 700.0)
	_check("freon forms from plasma, CO2 and BZ over 473 K", r["m"][Defs.G_FREON] > 0.0)
	r = _react({Defs.G_N2: 100.0, Defs.G_TRITIUM: 50.0}, 10.0)
	_check("hyper-noblium forms from N2 and tritium below 15 K", r["m"][Defs.G_HYPERNOB] > 0.0)
	r = _react({Defs.G_BZ: 5.0, Defs.G_FREON: 30.0}, 100.0)
	_check("healium forms from BZ and freon (25-300 K)", r["m"][Defs.G_HEALIUM] > 0.0)
	r = _react({Defs.G_HYPERNOB: 1.0, Defs.G_NITRIUM: 10.0}, 60000.0)
	_check("zauker forms from hyper-noblium and nitrium at 50,000-75,000 K", r["m"][Defs.G_ZAUKER] > 0.0)
	r = _react({Defs.G_N2: 10.0, Defs.G_ZAUKER: 10.0}, 300.0)
	_check("zauker breaks down with nitrogen into O2 and N2", r["m"][Defs.G_ZAUKER] < 10.0 and r["m"][Defs.G_O2] > 0.0)
	r = _react({Defs.G_PLUOXIUM: 10.0, Defs.G_HYDROGEN: 20.0}, 6000.0)
	_check("proto-nitrate forms from pluoxium and hydrogen (5,000-10,000 K)", r["m"][Defs.G_PROTO_NITRATE] > 0.0)
	r = _react({Defs.G_PROTO_NITRATE: 1.0, Defs.G_HYDROGEN: 200.0}, 300.0)
	_check("proto-nitrate turns lots of hydrogen into more of itself", r["m"][Defs.G_PROTO_NITRATE] > 1.0 and r["m"][Defs.G_HYDROGEN] < 200.0)
	r = _react({Defs.G_PROTO_NITRATE: 10.0, Defs.G_TRITIUM: 10.0}, 200.0)
	_check("proto-nitrate turns tritium into hydrogen (150-340 K)", r["m"][Defs.G_TRITIUM] < 10.0 and r["m"][Defs.G_HYDROGEN] > 0.0)
	r = _react({Defs.G_PROTO_NITRATE: 10.0, Defs.G_BZ: 10.0}, 270.0)
	_check("proto-nitrate breaks BZ into helium, N2 and plasma (260-280 K)", r["m"][Defs.G_HELIUM] > 0.0 and r["m"][Defs.G_BZ] < 10.0)
	r = _react({Defs.G_HALON: 5.0, Defs.G_O2: 200.0}, 500.0)
	# (tg's maths: it takes energy out, but losing 20 mol of O2 per 2.5 of pluoxium drops the
	# heat capacity more, so this mix ends up a little warmer - as it does in tg)
	_check("halon strips oxygen from hot air, leaving pluoxium", r["m"][Defs.G_O2] < 200.0 and r["m"][Defs.G_PLUOXIUM] > 0.0 and r["m"][Defs.G_HALON] < 5.0)
	r = _react({Defs.G_MIASMA: 10.0}, 500.0)
	_check("dry heat sterilises miasma into oxygen (over 443 K)", r["m"][Defs.G_MIASMA] < 10.0 and r["m"][Defs.G_O2] > 0.0)
	r = _react({Defs.G_MIASMA: 10.0, Defs.G_H2O: 10.0}, 500.0)
	_check("... not in humid air", r["m"][Defs.G_MIASMA] == 10.0)
	r = _react({Defs.G_ANTINOB: 10.0, Defs.G_N2: 100.0}, 300.0)
	_check("anti-noblium turns the rest of the mix into itself", r["m"][Defs.G_ANTINOB] > 10.0 and r["m"][Defs.G_N2] < 100.0)
	# --- hyper-noblium stops everything
	r = _react({Defs.G_HYPERNOB: 10.0, Defs.G_PLASMA: 10.0, Defs.G_O2: 150.0}, 600.0)
	_check("5+ mol of hyper-noblium above 20 K stops reactions (a plasma fire here)", r["res"].is_empty())
	# --- conservation: fires don't create matter
	r = _react({Defs.G_PLASMA: 10.0, Defs.G_O2: 150.0}, 600.0)
	var tot := 0.0
	for g in Defs.GAS_COUNT:
		tot += r["m"][g]
	_check("a plasma fire never goes negative (%.2f mol left)" % tot, tot > 0.0 and r["m"][Defs.G_O2] >= 0.0 and r["m"][Defs.G_PLASMA] >= 0.0)
	# --- on the map: a rare gas spreads, and a pipe fire burns
	var at: AtmosSystem = Game.atmos
	var c: Vector2i = Vector2i(-1, -1)
	for ar in Game.map.areas:
		if ar.name == "Research Lab":
			c = ar.cells[ar.cells.size() / 2]
	if c.x >= 0:
		var i := Game.map.idx(c)
		at.add_gas(i, Defs.G_BZ, 50.0, Defs.T20C)
		_check("adding BZ marks it present on the station", Defs.G_BZ in at.present)
		for k in 6:
			at.tick()
		var nb := -1
		for d in Defs.DIRS4:
			if nb < 0 and Game.map.is_passable(c + d) and not Game.map.blocks_air(c + d):
				nb = Game.map.idx(c + d)
		_check("BZ spreads to the next tile (%.2f mol there)" % at.gas[Defs.G_BZ][nb], at.gas[Defs.G_BZ][nb] > 0.1)
	var burnt := false
	for net in Game.pipes.nets:
		if net.cells.size() > 5 and net.total_moles() < 50.0:
			net.add_gas(Defs.G_PLASMA, 20.0, 700.0)
			net.add_gas(Defs.G_O2, 200.0, 700.0)
			var p0: float = net.gas[Defs.G_PLASMA]
			Game.pipes._react_net(net)
			burnt = net.gas[Defs.G_PLASMA] < p0
			break
	_check("a pipe full of hot plasma and oxygen burns inside the pipe", burnt)
	if c.x >= 0:
		_visible_gases(c)
		_breathing(c)
		_canisters(c)
	_air_alarm()
	if dir != "" and DisplayServer.get_name() != "headless":
		await _screenshots()
	print("GAS DONE: %d failed" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _visible_gases(c: Vector2i) -> void:
	var i := Game.map.idx(c)
	var layer: GasLayer = Game.view.gas_layer
	for g in Defs.GAS_COUNT:
		Game.atmos.gas[g][i] = 0.0
	for g in Defs.GAS_COUNT:
		Game.atmos.gas[g][i] = Defs.GAS_VISIBLE_AT[g]
		layer._write(i)
		_check("%s invisible at threshold" % Defs.GAS_SHORT[g], layer.visible_amount(c, g) == 0.0)
		Game.atmos.gas[g][i] += 20.0
		layer._write(i)
		_check("%s visibility follows gas metadata" % Defs.GAS_SHORT[g], (layer.visible_amount(c, g) > 0.0) == Defs.GAS_VISIBLE[g])
		if Defs.GAS_VISIBLE[g] and not GasLayer.CHANNEL.has(g):
			var tint := layer.tint_img.get_pixel(c.x, c.y)
			_check("%s has the correct shader tint" % Defs.GAS_SHORT[g], tint.a > 0.9 and absf(tint.r - Defs.GAS_COLOR[g].r) < 0.01)
		Game.atmos.gas[g][i] = 0.0
	layer._write(i)
	_check("rare gas overlay clears", layer.tint_img.get_pixel(c.x, c.y).a == 0.0)

func _breath_at(d: Entity, gases: Dictionary) -> void:
	var i := Game.map.idx(d.cell)
	for g in Defs.GAS_COUNT:
		Game.atmos.gas[g][i] = float(gases.get(g, 0.0)) * Defs.CELL_VOLUME / (Defs.R_IDEAL * Defs.T20C)
	Game.atmos.temp[i] = Defs.T20C
	var h: CHealth = d.c(&"health")
	h.breath_t = 0.0
	h.losebreath = 0.0
	Game.life._breathe(d, h, d.c(&"mob"), d.c(&"inv"), i, 0.0)

func _breathing(c: Vector2i) -> void:
	var d := Crew.spawn_human("assistant", c, {"name": "Gas test patient"})
	d.remove_comp(&"brain")
	Quirks.remove_all(d) # random crew quirks would skew the checks
	var h: CHealth = d.c(&"health")
	h.oxy = 20.0
	_breath_at(d, {Defs.G_PLUOXIUM: 3.0, Defs.G_N2: 80.0})
	_check("pluoxium alone supplies oxygen at x8 efficiency", not h.failed_last_breath and h.oxy < 20.0 and h.chems.has("pluoxium"))
	_breath_at(d, {Defs.G_PLUOXIUM: 1.0})
	_check("insufficient pluoxium still causes suffocation", h.failed_last_breath)
	_breath_at(d, {Defs.G_O2: 21.0, Defs.G_BZ: 5.0})
	Chem.metabolize(h, 1.0)
	_check("BZ metabolizes into hallucinations", h.has_status("hallucination"))
	var burn0 := h.burn
	_breath_at(d, {Defs.G_O2: 21.0, Defs.G_FREON: 8.0})
	_check("freon burns and slows", h.burn > burn0 and h.move_add() >= 0.16)
	h.oxy = 0.0
	_breath_at(d, {Defs.G_O2: 21.0, Defs.G_HALON: 1.0})
	_check("halon causes oxygen loss even in breathable air", h.oxy >= 5.0 and h.chems.has("halon"))
	h.chems.clear()
	h.adjust("brute", 10.0)
	var brute0 := h.brute
	_breath_at(d, {Defs.G_O2: 21.0, Defs.G_HEALIUM: 7.0})
	Chem.metabolize(h, 1.0)
	_check("healium induces sleep and heals", h.has_status("sleeping") and h.brute < brute0)
	for k in 11:
		Chem.metabolize(h, 1.0)
	_check("healium sleep releases after metabolism", not h.chems.has("healium") and h.status_left("sleeping") <= 1.0)
	h.remove_status("sleeping")
	h.get_up(true) # on their feet now, not after tg's 1 s get_up (crawling would mask nitrium)
	_breath_at(d, {Defs.G_O2: 21.0, Defs.G_HELIUM: 6.0})
	_check("helium changes the voice", h.helium_voice)
	_breath_at(d, {Defs.G_O2: 21.0})
	_check("fresh air restores the voice", not h.helium_voice)
	h.chems.clear()
	_breath_at(d, {Defs.G_O2: 21.0, Defs.G_NITRIUM: 12.0})
	h.sleep_for(10.0)
	_check("nitrium speeds movement and prevents sleep", h.move_add() < 0.0 and not h.has_status("sleeping"))
	h.chems.clear()
	var tox0 := h.tox
	_breath_at(d, {Defs.G_O2: 21.0, Defs.G_TRITIUM: 2.0})
	_check("tritium inhalation is toxic", h.tox > tox0)
	_breath_at(d, {Defs.G_O2: 21.0, Defs.G_MIASMA: 40.0})
	_check("miasma causes disgust", h.disgust > 0.0)
	brute0 = h.brute
	_breath_at(d, {Defs.G_O2: 21.0, Defs.G_ZAUKER: 1.0})
	Chem.metabolize(h, 1.0)
	_check("zauker damages its host after inhalation", h.brute > brute0 and h.chems.has("zauker"))
	var inv: CInventory = d.c(&"inv")
	var mask := Proto.spawn("gas_mask", c)
	inv.equip(mask, "mask")
	h.chems.clear()
	_breath_at(d, {Defs.G_O2: 21.0, Defs.G_BZ: 2.0})
	_check("gas mask reduces BZ below the hallucination threshold", not h.chems.has("bz_metabolites"))
	_breath_at(d, {Defs.G_BZ: 2.0})
	_check("a gas mask does not create oxygen", h.failed_last_breath)
	var tank := Proto.spawn("tank_o2", c)
	inv.put_in_hands(tank)
	d.c(&"mob").internals = true
	h.chems.clear()
	_breath_at(d, {Defs.G_ZAUKER: 20.0, Defs.G_BZ: 20.0})
	_check("internals isolate the lungs from contaminated room air", not h.failed_last_breath and not h.chems.has("zauker") and not h.chems.has("bz_metabolites"))
	d.destroy()

func _canisters(c: Vector2i) -> void:
	for id in CTank.GAS_ID:
		var e := Proto.spawn("canister_" + id, c)
		var tank: CTank = e.c(&"tank")
		_check("%s canister has gas and a sprite" % id, tank.composition()[CTank.GAS_ID[id]] > 0.0 and Gfx.has("objects", e.spr_name))
		e.destroy()

func _air_alarm() -> void:
	var alarms := Game.all_with(&"air_alarm")
	_check("station has air alarms", not alarms.is_empty())
	if alarms.is_empty():
		return
	var al: CAirAlarm = alarms[0].c(&"air_alarm")
	al.tick(1.0)
	var body := VBoxContainer.new()
	WindowsMachines.build("air_alarm", al.e, body, Game.player)
	_check("air alarm builds with the TGUI kit", body.get_child_count() > 1 and WindowsMachines.handles("air_alarm", al.e))
	var filters := {}
	var bz_button: Button
	for b in body.find_children("*", "Button", true, false):
		if b.tooltip_text.begins_with("BZ:"):
			bz_button = b
		if b.tooltip_text.begins_with("Zauker:") or b.tooltip_text.begins_with("Pluoxium:"):
			filters[b.text] = true
	_check("air alarm exposes rare-gas scrubber filters", filters.size() == 2)
	var scrub: CVent = al.devices("scrubber")[0].c(&"vent")
	var locked := al.locked
	al.locked = false
	var before: bool = scrub.filters.get(Defs.G_BZ, false)
	bz_button.pressed.emit()
	_check("BZ filter button changes the actual scrubber", scrub.filters.get(Defs.G_BZ, false) != before)
	scrub.siphon = true
	bz_button.pressed.emit()
	_check("filter callbacks cannot alter a siphoning scrubber", scrub.filters.get(Defs.G_BZ, false) != before)
	scrub.siphon = false
	scrub.filters[Defs.G_BZ] = before
	al.locked = locked
	body.free()

func _screenshots() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Game.paused = true
	Game.lighting.full_bright = true
	var al: Entity = Game.all_with(&"air_alarm")[0]
	Game.player.place(al.cell + Vector2i.DOWN)
	Game.hud.open_window("air_alarm", al)
	for k in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("air_alarm.png"))
	Game.hud.root.visible = false
	var origin := Vector2i(75, 55)
	# Screenshot-only display tiles, kept out of the saved station map.
	var n := 0
	for id in CTank.GAS_ID:
		var c := origin + Vector2i((n % 5) * 4, (n / 5) * 4)
		for y in range(-1, 2):
			for x in range(-1, 2):
				var cell := c + Vector2i(x, y)
				Game.map.set_turf(cell, Defs.T_STEEL)
				var i := Game.map.idx(cell)
				for g in Defs.GAS_COUNT:
					Game.atmos.gas[g][i] = 0.0
				Game.atmos.gas[CTank.GAS_ID[id]][i] = 20.0
		Proto.spawn("canister_" + id, c)
		var label := Label.new()
		label.text = Defs.GAS_SHORT[CTank.GAS_ID[id]]
		label.position = Entity.cell_to_pos(c) + Vector2(-25, 24)
		label.add_theme_font_size_override("font_size", 12)
		label.z_index = 100
		Game.view.add_child(label)
		n += 1
	Game.player.place(origin + Vector2i(8, 6))
	Game.view.zoom_level = 1.5
	Game.view.camera.position = Entity.cell_to_pos(Game.player.cell)
	Game.view.camera.reset_smoothing()
	Game.view.gas_layer.refresh_all()
	for k in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("gas_canisters.png"))
