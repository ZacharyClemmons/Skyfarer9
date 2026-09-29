class_name FeatureTest extends Node
## --featuretest[=DIR]: checks the tg features added in the tg-parity passes (T-ray scanner,
## light switches, space heaters...) and, with a DIR, screenshots each. Prints
## "FEATURE PASS/FAIL ..." lines and quits.

var dir := ""
var fails := 0

func _ready() -> void:
	_run.call_deferred()

func _check(what: String, ok: bool) -> void:
	print("FEATURE %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1

func _shot(name: String) -> void:
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/feature_%s.png" % [dir, name])

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _look(c: Vector2i, zoom := 2.0) -> void:
	Game.view.zoom_level = zoom
	Game.view.camera.position = Entity.cell_to_pos(c)
	Game.view.camera.reset_smoothing()

func _run() -> void:
	await _frames(20)
	var p := Game.player
	var inv: CInventory = p.c(&"inv")
	for i in 2:
		if inv.hands[i]:
			inv.hands[i].destroy()
			inv.hands[i] = null

	# --- T-ray scanner: reveals the pipes under the floor near its carrier
	var spot := Vector2i(-1, -1)
	for i in Game.map.w * Game.map.h:
		var c := Game.map.cell_of(i)
		var fl: int = Defs.TURFS[Game.map.turf[i]]["flags"]
		if (fl & Defs.F_FLOOR) != 0 and Game.map.is_passable(c) and Game.map.pipe_mask(0, c) != 0 and not Game.map.pipe_shown.has(Game.map.pipe_key(0, c)):
			spot = c
			break
	_check("found a hidden pipe to scan", spot.x >= 0)
	p.place(spot)
	var tr := Proto.spawn("t_scanner", p.cell)
	inv.put_in_hands(tr, inv.active)
	tr.c(&"tray").attack_self(p)
	_check("T-ray switched on scans from its carrier", CTray.player_scan_origin() == p.cell)
	Game.hud.refresh_inventory()
	_look(p.cell, 2.5)
	await _frames(12)
	await _shot("tray")
	tr.c(&"tray").attack_self(p)
	_check("T-ray switched off stops scanning", CTray.player_scan_origin().x < -9000)
	tr.destroy()

	# --- light switch: turns the whole room's lights off and back on
	var sw: Entity = null
	for e in Game.all_with(&"lightswitch"):
		var ar := Game.map.area_at(e.cell)
		if ar.power_light and Game.all_with(&"light").any(func(l): return Game.map.area_at(l.cell) == ar and l.c(&"light").kind == "fixture"):
			sw = e
			break
	_check("rooms have light switches", sw != null)
	if sw:
		var ar2 := Game.map.area_at(sw.cell)
		var room_lights := Game.all_with(&"light").filter(func(l): return Game.map.area_at(l.cell) == ar2 and l.c(&"light").kind in ["fixture", "ceiling"])
		p.place(sw.cell)
		_look(sw.cell, 2.0)
		Game.lighting.full_bright = false
		await _frames(10)
		await _shot("switch_on")
		sw.c(&"lightswitch").attack_hand(p)
		await _frames(10)
		_check("flicking it turns the room's lights off", room_lights.all(func(l): return not l.c(&"light").lit))
		await _shot("switch_off")
		sw.c(&"lightswitch").attack_hand(p)
		await _frames(3)
		_check("flicking it again turns them back on", room_lights.all(func(l): return l.c(&"light").lit))

	# --- space heater: warms the air around it toward its target
	var sh: Entity = null
	for e in Game.all_with(&"spaceheater"):
		sh = e
		break
	_check("a space heater is on the station", sh != null)
	if sh:
		var hc: CSpaceHeater = sh.c(&"spaceheater")
		var i := Game.map.idx(sh.cell)
		var t0: float = Game.atmos.temp[i]
		hc.target = t0 + 15.0
		hc.set_mode = "heat"
		hc.set_on(true, p)
		Game.life.machines_tick(1.0)
		var first_mode := hc.mode
		for k in 19:
			Game.life.machines_tick(1.0)
		_check("heating warms the room (%.1f -> %.1f K)" % [t0, Game.atmos.temp[i]], Game.atmos.temp[i] > t0 + 2.0)
		_check("heating uses the cell", hc.charge < CSpaceHeater.CAPACITY)
		_check("it runs in heat mode until the target is reached (%s, then %s)" % [first_mode, hc.mode], first_mode == "heat" and hc.mode == "standby")
		p.place(sh.cell + Vector2i(0, 1) if Game.map.is_passable(sh.cell + Vector2i(0, 1)) else sh.cell)
		_look(sh.cell, 2.0)
		Game.hud.open_window("space_heater", sh)
		await _frames(15)
		await _shot("heater")
		hc.set_on(false, p)
	# --- where the station's air comes from: everything feeding the vents' network
	var distro = null
	for v in Game.all_with(&"vent"):
		var cv: CVent = v.c(&"vent")
		if cv.mode == "vent" and Game.map.area_at(v.cell).room_kind != "atmospherics":
			distro = Game.pipes.net_at(cv.layer, v.cell + cv.face)
			if distro:
				break
	if distro:
		print("DISTRO net layer %d, %d tiles, %.0f kPa, %s" % [distro.layer, distro.cells.size(), distro.pressure(), PipeHover.readout(distro)])
		for m in Game.pipes.machines:
			var pm: CPipeMachine = m.c(&"pipemachine")
			if pm.inline() and pm.net_out() == distro:
				var src = pm.net_in()
				print("DISTRO fed by %s '%s' on=%s moved=%.2f from a net of %d tiles (%s)" % [pm.kind, pm.display, pm.on, pm.moved_last, src.cells.size() if src else 0, PipeHover.readout(src) if src else "-"])
				if src:
					for m2 in Game.pipes.machines:
						var pm2: CPipeMachine = m2.c(&"pipemachine")
						if pm2.inline() and pm2.net_out() == src:
							print("DISTRO   <- %s '%s' on=%s from %s" % [pm2.kind, pm2.display, pm2.on, PipeHover.readout(pm2.net_in()) if pm2.net_in() else "-"])
					for id in Game.pipes.devices:
						for entry in Game.pipes.devices[id]:
							if Game.pipes.net_at(entry[0], entry[2].cell + entry[1]) == src:
								print("DISTRO   <- device %s (%s)" % [entry[2].proto, entry[2].display_name])
					var ov: AtmosOverlay = Game.view.find_children("*", "AtmosOverlay", true, false)[0]
					ov._compute_flow()
					print("DISTRO   air line in design: %s (%d dists)  in flow: %s" % [ov._design.has(src), ov._design.get(src, {}).size(), ov._flow.has(src)])
		for id in Game.pipes.devices:
			for entry in Game.pipes.devices[id]:
				if Game.pipes.net_at(entry[0], entry[2].cell + entry[1]) == distro and not entry[2].has_c(&"vent"):
					print("DISTRO device on it: %s" % entry[2].proto)
	print("FEATURE DONE: %d failed" % fails)
	get_tree().quit()
