extends Node
## Boots a shift: generates the station, starts every system, populates the crew,
## then lets the player create their character and join.
##
## Command line (after `--`):
##   --seed=N          fixed station seed
##   --crew=N          NPC crew size (default 20)
##   --autotest=SEC    skip the creator, play as a random job, run SEC seconds, quit
##   --shots=DIR       with --autotest, save periodic screenshots into DIR
##   --evac=SEC        with --autotest, dispatch the evacuation crawler to arrive in SEC seconds

var args := {}
var pause_panel: PanelContainer
var creator: CharCreator
var shot_dir := ""
var shot_t := 0.0
var shot_n := 0
var auto_quit := -1.0
var mapgen: MapGen
var player_slot := 0 # character save slot the player's XP goes back into
var _save_t := 20.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=")
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var seed_value := int(args.get("seed", str(randi() % 1000000)))
	Game.seed_value = seed_value
	Game.rng.seed = seed_value
	seed(seed_value)
	Genetics.reset() # tg SSatoms.setupGenetics: this round's aliases and true sequences
	var t0 := Time.get_ticks_msec()
	# render world
	var view := WorldView.new()
	view.name = "WorldView"
	add_child(view)
	Game.view = view
	Game.world = view
	Game.ents_node = view.ents
	# systems (created before mapgen so devices/lights can register while spawning)
	Game.atmos = _sys(AtmosSystem.new(), "Atmos")
	Game.pipes = _sys(PipeSystem.new(), "Pipes")
	Game.power = _sys(PowerSystem.new(), "Power")
	Game.lighting = _sys(LightingSystem.new(), "Lighting")
	Game.life = _sys(LifeSystem.new(), "Life")
	Game.ai = _sys(AISystem.new(), "AI")
	Game.director = _sys(Director.new(), "Director")
	Game.chronicle = _sys(Chronicle.new(), "Chronicle")
	Game.evac = _sys(Evac.new(), "Evac")
	add_child(PlayerController.new())
	Bus.stimulus.connect(Skills.on_stimulus)
	var hud := HUD.new()
	Game.hud = hud
	add_child(hud)
	if not args.has("noenv"):
		_environment()
	# the station
	var gen := MapGen.new()
	var map := gen.generate(seed_value)
	Game.map = map
	Game.atmos.setup(map)
	Game.pipes.setup(map)
	Game.power.setup(map)
	Game.lighting.setup(map, view.lightmap)
	view.setup(map)
	Game.ai.setup(map)
	Game.evac.setup(map)
	for l in Game.all_with(&"light"):
		Game.lighting.register(l.c(&"light"))
	# the crew
	mapgen = gen
	var crew := _spawn_crew(gen, int(args.get("crew", "20")))
	Crew.assign_beds(crew)
	Crew.seed_relationships(crew)
	for c in crew:
		Crew.seed_knowledge(c)
	CVermin.infest(Game.rng.randi_range(2, 4))
	for mc in gen.monkey_spawns:
		Monkeys.spawn_monkey(mc)
	print("Artic9: station generated in %d ms (seed %d, %d entities, %d crew)" % [Time.get_ticks_msec() - t0, seed_value, Game.entities.size(), crew.size()])
	if args.has("mapcheck"):
		var bad := gen.unreachable_report()
		print("MAPCHECK seed %d: %s" % [seed_value, "OK" if bad.is_empty() else "; ".join(bad)])
		Game.power.rebuild()
		var apcs := 0
		for net in Game.power.nets:
			apcs += net["apcs"].size()
			if net["gens"].is_empty() and net["smes"].is_empty() and not net["apcs"].is_empty():
				var names := []
				for ap in net["apcs"]:
					names.append(Game.map.area_at(ap.cell).name)
				print("MAPCHECK unpowered net (%d cells): %s" % [net["cells"].size(), ", ".join(names)])
		var unwired := []
		for ap in Game.all_with(&"apc"):
			if Game.power._net_for_entity(ap) < 0:
				unwired.append(Game.map.area_at(ap.cell).name)
		print("MAPCHECK power: %d nets, %d APCs wired, not wired: %s" % [Game.power.nets.size(), apcs, ", ".join(unwired)])
		var lay := gen.layout_report()
		print("MAPCHECK doorways blocked: %d %s" % [lay["blocked"].size(), ", ".join(lay["blocked"])])
		print("MAPCHECK loose items: %d %s" % [lay["loose"].size(), ", ".join(lay["loose"].slice(0, 20))])
		print("MAPCHECK covered vents/APCs: %d %s" % [lay["covered"].size(), ", ".join(lay["covered"])])
		Game.running = true
		for i in 12:
			Game.power.tick(1.0)
		var dark := []
		for ar in Game.map.areas:
			if ar.id != 0 and not ar.outdoor and not ar.cells.is_empty() and not ar.powered("light") and ar.room_kind != "gas_chamber":
				var ap = null
				for x in Game.all_with(&"apc"):
					if Game.map.area_at(x.cell) == ar:
						ap = x
				dark.append("%s%s" % [ar.name, "" if ap else " (no APC)"])
		print("MAPCHECK dark after warm-up: %s" % ", ".join(dark))
		for net in Game.power.nets:
			print("MAPCHECK net: %d cells, %d gens, %d smes, %d apcs, supply %.0f demand %.0f" % [net["cells"].size(), net["gens"].size(), net["smes"].size(), net["apcs"].size(), net["supply"], net["demand"]])
		get_tree().quit()
		return
	# warm the simulation up a little so the station is 'running' when you arrive
	Game.running = true
	for i in 6:
		Game.power.tick(1.0)
	Game.running = false
	view.camera.position = Entity.cell_to_pos(gen.room_of("cafeteria").get("rect", Rect2i(75, 55, 1, 1)).get_center())
	if args.has("autotest"):
		var jobs := ["engineer", "doctor", "miner", "security", "scientist", "cook"]
		_join({"name": "Test Subject", "appearance": Jobs.random_appearance(Game.rng), "job": jobs[Game.rng.randi() % jobs.size()], "pronoun": "they"})
		auto_quit = float(args["autotest"])
		shot_dir = args.get("shots", "")
		if args.has("fullbright"):
			Game.lighting.full_bright = true
		if args.has("zoom"):
			view.zoom_level = float(args["zoom"])
		if args.has("at"):
			var parts: PackedStringArray = args["at"].split(",")
			var tc := Vector2i(int(parts[0]), int(parts[1]))
			Game.player.place(tc)
		if args.has("speed"):
			Game.time_scale = float(args["speed"])
		if args.has("nolight"):
			view.lightmap.visible = false
		if args.has("hidehud"):
			Game.hud.root.visible = false
		if args.has("mapshots"):
			var ms := MapShots.new()
			ms.dir = args["mapshots"]
			ms.lit = args.has("lit")
			add_child(ms)
		if args.has("atmostest"):
			add_child(AtmosTest.new())
		if args.has("combattest"):
			add_child(CombatTest.new())
		if args.has("polishtest"):
			add_child(PolishTest.new())
		if args.has("structtest"):
			add_child(StructureTest.new())
		if args.has("statustest"):
			add_child(StatusTest.new())
		if args.has("genetest"):
			var gnt := GeneTest.new()
			gnt.dir = args["genetest"] if not args["genetest"] in ["1", "true", ""] else ""
			add_child(gnt)
		if args.has("showcase"):
			var sc := ShowcaseShots.new()
			sc.dir = args["showcase"]
			add_child(sc)
		if args.has("glassshots"):
			var gs := GlassShots.new()
			gs.dir = args["glassshots"]
			add_child(gs)
		if args.has("itemtest"):
			add_child(ItemTest.new())
		if args.has("holdshots"):
			var hs := HoldShots.new()
			hs.dir = args["holdshots"]
			add_child(hs)
		if args.has("goretest"):
			var gt := GoreTest.new()
			gt.dir = args["goretest"]
			add_child(gt)
		if args.has("tgtest"):
			var tt := TgTest.new()
			tt.dir = args["tgtest"]
			add_child(tt)
		if args.has("featuretest"):
			var ft := FeatureTest.new()
			ft.dir = args["featuretest"] if not args["featuretest"] in ["1", "true", ""] else ""
			add_child(ft)
		if args.has("gastest"):
			var gt := GasTest.new()
			gt.dir = args["gastest"] if not args["gastest"] in ["1", "true", ""] else ""
			add_child(gt)
		if args.has("winshots"):
			var wsh := WinShots.new()
			wsh.dir = args["winshots"]
			add_child(wsh)
		if args.has("uitest"):
			var ut := UITest.new()
			ut.dir = args["uitest"]
			add_child(ut)
		if args.has("transcript"):
			# print everything the crew says, to read how they come across
			Bus.speech.connect(func(sp, text, _c, r): if Game.running and is_instance_valid(sp) and r > 2.0: print("[%s] %s: %s" % [Game.clock_string(), sp.display_name, text]))
			Bus.radio.connect(func(sp, ch, text, _f): if Game.running: print("[%s] [%s] %s: %s" % [Game.clock_string(), ch, sp.display_name if is_instance_valid(sp) else "Station", text]))
			Bus.chat.connect(func(text, kind): if kind == "emote": print("[%s] * %s" % [Game.clock_string(), text]))
		if args.has("airlog"):
			add_child(AirLog.new())
		if args.has("npctest") or args.has("npcshots"):
			var nt := NpcTest.new()
			nt.dir = args.get("npcshots", "")
			add_child(nt)
		if args.has("evac"):
			# testing: dispatch the crawler right away, arriving in N seconds
			Game.evac.refuel_delay = 0.0
			Game.evac.request(null, "Autotest evacuation.", float(args["evac"]) / Evac.CALL_TIME)
	else:
		open_creator()
		if args.has("chargentest"):
			var ct := ChargenTest.new()
			ct.dir = args["chargentest"]
			add_child(ct)

func _sys(n: Node, nm: String) -> Node:
	n.name = nm
	add_child(n)
	return n

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.1
	env.glow_hdr_scale = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.5)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.05
	we.environment = env
	add_child(we)

func _spawn_crew(gen: MapGen, n: int) -> Array:
	var out := []
	var used := {}
	var job_room: Dictionary = Jobs.START_ROOM
	var count := {}
	for job in Jobs.FILL_ORDER:
		if out.size() >= n:
			break
		count[job] = count.get(job, 0) + 1
		if count[job] > int(Jobs.JOBS[job].get("slots", 1)):
			continue
		var room: String = job_room.get(job, "cafeteria")
		var cells: Array = gen.spawns.get(room, [])
		if cells.is_empty():
			cells = gen.spawns.get("cafeteria", [])
		var cell := Vector2i(-1, -1)
		for c in cells:
			if not used.has(c):
				cell = c
				break
		if cell.x < 0:
			continue
		used[cell] = true
		out.append(Crew.spawn_human(job, cell))
	return out

func open_creator() -> void:
	creator = CharCreator.new()
	Game.hud.root.add_child(creator)
	creator.done.connect(_join)

func _join(cfg: Dictionary) -> void:
	# like tg, you start the shift in your department (your job's start room), next to
	# your own locker
	var cells := []
	var room: Dictionary = mapgen.room_of(Jobs.START_ROOM.get(cfg["job"], "cafeteria")) if mapgen else {}
	var areas: Array = [room["area"]] if not room.is_empty() else []
	if areas.is_empty():
		for a in Game.map.areas:
			if a.name.begins_with("Dormitories"):
				areas.append(a)
	for a in areas:
		for c in a.cells:
			if Game.map.is_passable(c) and Game.at(c).is_empty():
				cells.append(c)
	if cells.is_empty():
		cells = [Vector2i(MapGen.SX + 50, MapGen.SY + 21)]
	var cell: Vector2i = cells[Game.rng.randi() % cells.size()]
	var p := Crew.spawn_human(cfg["job"], cell, {"name": cfg["name"], "appearance": cfg["appearance"], "pronoun": cfg["pronoun"], "player": true, "saved": cfg.get("saved", {}), "quirks": cfg.get("quirks", [])})
	player_slot = int(cfg.get("slot", 0))
	Game.player = p
	Bus.player_changed.emit(p)
	Game.running = true
	Game.hud.refresh_inventory()
	Game.view.camera.position = p.position
	Game.view.camera.reset_smoothing()
	var jt := Jobs.title(cfg["job"])
	Game.msg("[b][color=#7fd4ff]Welcome to Artic-9, %s.[/color][/b] You are the station's [b]%s[/b]. It is %s, and it is very, very cold outside." % [cfg["name"], jt, Game.clock_string()], "info")
	Game.msg("Press [b]F1[/b] for controls. Right-click anything to see what you can do with it. [b]F4[/b] shows what the crew are thinking.", "info")
	Bus.chronicle.emit("%s arrived for their shift as %s." % [cfg["name"], jt], 1)
	# the rest of the crew knows a new face arrived (familiarity, not friendship)
	for b in Game.all_with(&"brain"):
		var br: CBrain = b.c(&"brain")
		var r = br.memory.rel(p.id)
		r.familiarity = 25.0 if Jobs.dept(br.job) == Jobs.dept(cfg["job"]) else 5.0
		r.affinity = 8.0 if Jobs.dept(br.job) == Jobs.dept(cfg["job"]) else 0.0

func toggle_pause() -> void:
	if pause_panel:
		pause_panel.queue_free()
		pause_panel = null
		Game.paused = false
		return
	Game.paused = true
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-160, -120)
	pause_panel.custom_minimum_size = Vector2(320, 240)
	Game.hud.root.add_child(pause_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pause_panel.add_child(v)
	v.add_child(UITheme.label("Paused", 28, UITheme.ACCENT))
	for pair in [["Resume", "resume"], ["Controls", "help"], ["Station log", "log"], ["Quit", "quit"]]:
		var b := Button.new()
		b.text = pair[0]
		var id: String = pair[1]
		b.pressed.connect(func(): _pause_action(id))
		v.add_child(b)

func _pause_action(id: String) -> void:
	match id:
		"resume":
			toggle_pause()
		"help":
			Game.hud.open_window("help", null)
		"log":
			Game.hud.open_window("chronicle", null)
		"quit":
			_save_progress()
			get_tree().quit()

func _save_progress() -> void:
	if player_slot > 0 and Game.player and is_instance_valid(Game.player):
		CharCreator.save_progress(player_slot, Game.player.c(&"mob"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress()

func _process(delta: float) -> void:
	_save_t -= delta
	if _save_t <= 0.0:
		_save_t = 20.0
		_save_progress()
	if auto_quit > 0:
		auto_quit -= delta
		if shot_dir != "":
			shot_t -= delta
			if shot_t <= 0:
				shot_t = 6.0
				_shot()
		if auto_quit <= 0:
			Game.running = false
			_report()
			get_tree().quit()

func _shot() -> void:
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/shot_%02d.png" % [shot_dir, shot_n])
		shot_n += 1

func _report() -> void:
	print("=== autotest report t=%.1f ===" % Game.time)
	print("entities %d, hotspots %d, active atmos %d" % [Game.entities.size(), Game.atmos.hotspots.size(), Game.atmos.active.size()])
	print(Game.power.summary())
	for e in Game.all_with(&"brain"):
		var b: CBrain = e.c(&"brain")
		var nd: CNeeds = e.c(&"needs")
		print("  %-22s %-24s %s  hp=%d temp=%.0f food=%d water=%d tox=%d" % [e.display_name, Jobs.title(b.job), b.status_text(), int(e.c(&"health").health()), e.c(&"health").body_temp, int(nd.nutrition), int(nd.hydration), int(e.c(&"health").tox)])
	for en in Game.chronicle.entries:
		print("  [%s] %s%s" % [en["clock"], en["text"], " (secret)" if en["secret"] else ""])
	print("events: ", Game.director.events_log)
	print("tension %.2f target %.2f" % [Game.director.tension, Game.director.target])
	var o2_ch := 0.0
	var o2_in := 0.0
	var kpa := 0.0
	var nin := 0
	for ar in Game.map.areas:
		if ar.outdoor:
			continue
		for c in ar.cells:
			var i := Game.map.idx(c)
			if ar.room_kind == "gas_chamber":
				o2_ch += Game.atmos.gas[Defs.G_O2][i]
			else:
				o2_in += Game.atmos.gas[Defs.G_O2][i]
				kpa += Game.atmos.pressure_at(c) if Game.atmos.has_method("pressure_at") else 0.0
				nin += 1
	var open_ext := []
	for d in Game.all_with(&"door"):
		var dc: CDoor = d.c(&"door")
		if dc.external and dc.is_open():
			open_ext.append("%s%s" % [Game.map.area_at(d.cell).name, " (welded)" if dc.welded else ""])
	var breaches := 0
	for i in Game.map.structure.size():
		if Defs.is_grille(Game.map.structure[i]) or Game.map.structure[i] == Defs.S_GRILLE_BROKEN:
			var c := Game.map.cell_of(i)
			if not Game.map.is_outdoor(c) and Defs.DIRS4.any(func(dd): return Game.map.is_outdoor(c + dd)):
				breaches += 1
	var lows := []
	for ar in Game.map.areas:
		if not ar.outdoor and not ar.cells.is_empty() and ar.room_kind != "gas_chamber" and Game.atmos.pressure_at(ar.center) < 30.0:
			lows.append(ar.name)
	var tot := []
	for g in Game.atmos.gas.size():
		var sm := 0.0
		for ar in Game.map.areas:
			if ar.outdoor or ar.room_kind == "gas_chamber":
				continue
			for c in ar.cells:
				sm += Game.atmos.gas[g][Game.map.idx(c)]
		tot.append(int(sm))
	print("room gases by index: %s; hotspots %d" % [tot, Game.atmos.hotspots.size()])
	print("leaks: external doors open %s; breached windows %d; rooms under 30 kPa: %d %s" % [open_ext, breaches, lows.size(), lows.slice(0, 12)])
	print("air: O2 in chambers %.0f mol, in the crew's air %.0f mol, mean %.0f kPa over %d tiles" % [o2_ch, o2_in, kpa / maxf(1, nin), nin])
	for asu in Game.all_with(&"air_supply"):
		print("air supply: O2 %.0f mol, N2 %.0f mol" % [asu.c(&"air_supply").o2_reserve, asu.c(&"air_supply").n2_reserve])
	for r in Game.all_with(&"reactor"):
		print(r.c(&"reactor").status_text())
	print(Game.evac.status_text(), " calls=", Game.evac.call_count)
	if not Game.evac.roster.is_empty():
		print("evac roster: ", Game.evac.summary())
		for r in Game.evac.roster:
			print("  %-14s %s, %s" % [r["status"], r["name"], r["job"]])
		var rep: String = Game.evac.report_bbcode()
		if "[b]Traitors[/b]" in rep:
			print(rep.substr(rep.find("[b]Traitors[/b]")))
