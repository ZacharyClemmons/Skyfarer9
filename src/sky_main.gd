extends Node
## Boots a voyage: generates a sky region, hangs the islands in it, starts the systems,
## and puts the player on the quay at Port Meridian with the price of a skiff in their
## purse and a decision to make about it.
##
## Nobody is given a ship. The yard at the end of the quay will sell you one out of the
## book in ninety seconds, or hand you a drawing board and let you spend exactly the same
## money on something you drew. Both are correct. That choice is the first thing the game
## asks and it is the reason the opening is on foot.
##
## Command line (after `--`):
##   --seed=N        fixed region seed
##   --band=N        altitude band 0-4 (0 the Deep .. 4 the Anvil); default 1, the Shelf
##   --hull=ID       skip the yard and start aboard this hull, for testing
##   --ship          start with the stock skiff moored, the old opening
##   --gencheck      generate, print a report, quit
##   --autotest=SEC  skip the creator, play for SEC seconds, quit
##   --flighttest    run deterministic flight and rendering regressions, quit with a result
##   --systemtest    run controls, tutorial and wildlife regressions
##   --boardtest     prove every hull can be boarded and left on foot at a quay
##   --shots=DIR     with --autotest, save periodic screenshots

var args := {}
var gen: SkyGen
var creator: CharCreator
var pause_panel: PanelContainer
var shot_dir := ""
var shot_t := 0.0
var shot_n := 0
var auto_quit := -1.0
var player_ship: Airship
var view_mode: ViewMode
var helm_panel: HelmPanel
var tutorial: Tutorial
var ship_panel: ShipPanel

## Tiles around the player's mooring kept clear of wildlife at the start of a voyage.
const SAFE_RADIUS := 16

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=")
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	SPerf.on = args.has("sperf")
	SPerf.install(self)
	var seed_value := int(args.get("seed", str(randi() % 1000000)))
	Game.seed_value = seed_value
	Game.rng.seed = seed_value
	seed(seed_value)
	Genetics.reset()
	SkyProto.install() # everything the generators are about to spawn
	var t0 := Time.get_ticks_msec()

	# renderer
	var view := WorldView.new()
	view.name = "WorldView"
	add_child(view)
	Game.view = view
	Game.world = view
	Game.ents_node = view.ents

	# systems, before generation so lights and machines can register as they spawn
	Game.atmos = _sys(AtmosSystem.new(), "Atmos")
	Game.pipes = _sys(PipeSystem.new(), "Pipes")
	Game.power = _sys(PowerSystem.new(), "Power")
	Game.lighting = _sys(LightingSystem.new(), "Lighting")
	Game.life = _sys(LifeSystem.new(), "Life")
	Game.ai = _sys(AISystem.new(), "AI")
	Game.director = _sys(Director.new(), "Director")
	Game.chronicle = _sys(Chronicle.new(), "Chronicle")
	Game.evac = _sys(Evac.new(), "Evac")
	Game.sky = _sys(SkySystem.new(), "Sky")
	Game.fleet = _sys(ShipSystem.new(), "Fleet")
	add_child(PlayerController.new())
	# the first-person view: same world, second camera (F5 toggles)
	view_mode = ViewMode.new()
	view_mode.name = "ViewMode"
	add_child(view_mode)
	Bus.stimulus.connect(Skills.on_stimulus)
	var hud := HUD.new()
	Game.hud = hud
	add_child(hud)
	if not args.has("noenv"):
		_environment()

	# the region
	Underdecks.reset()
	gen = SkyGen.new()
	var band := int(args.get("band", "1"))
	var map := gen.generate(seed_value, band)
	Game.map = map
	Game.atmos.setup(map)
	Game.atmos.refresh_external() # the sky's air is the band's air
	Game.pipes.setup(map)
	Game.power.setup(map)
	Game.lighting.setup(map, view.lightmap)
	view.setup(map)
	Game.ai.setup(map)
	Game.evac.setup(map)
	view_mode.setup(map)
	Game.sky.setup(gen)
	# the sky itself, behind everything: gradient, parallax cloud decks, sun and weather
	if not args.has("flatsky"):
		var backdrop := SkyBackdrop.new()
		backdrop.name = "SkyBackdrop"
		add_child(backdrop)
	else:
		TerrainChunk.SKY_BACKDROP = false
	# Artic9's blizzard becomes wind-borne haze: enough to show the wind, not enough to
	# fight the sky for attention.
	view.snow.intensity = 0.09
	view.snow.modulate = Color(0.86, 0.93, 1.0, 0.40)
	Game.fleet.transit_hook = _transit
	for l in Game.all_with(&"light"):
		Game.lighting.register(l.c(&"light"))
	Bus.mob_died.connect(_on_died)
	Reputation.reset()

	SkyBuffs.reset()
	# Wildlife is not spawned here any more. SkySystem's FaunaStream brings an island's
	# population in when the player is within sight of it and puts it back when they
	# leave, which is what makes a region this size affordable at all.
	print("Skyfarer9: %d creature records across %d islands, streamed" % [
		gen.mob_spawns.size(), gen.islands.size()])
	# A ship is something you buy in the yard, not something you wake up owning. The old
	# opening is kept behind a flag because every flight test in the project assumes it.
	if args.has("hull") or args.has("ship") or args.has("flighttest") or args.has("flytest") \
			or args.has("buildtest") or args.has("uishot") or args.has("turnshot") \
			or args.has("looptest") or args.has("systemtest") or args.has("decktest"):
		_launch_player_ship()

	print("Skyfarer9: region generated in %d ms (seed %d, %d entities)" % [
		Time.get_ticks_msec() - t0, seed_value, Game.entities.size()])
	print(gen.report())

	if args.has("gencheck"):
		_gencheck()
		get_tree().quit()
		return

	Game.running = true
	for i in 6:
		Game.power.tick(1.0)
	Game.running = false
	view.camera.position = Entity.cell_to_pos(gen.ship_start)

	if args.has("autotest") or args.has("flighttest") or args.has("systemtest") or args.has("boardtest") or args.has("hudtest") or args.has("decktest") or args.has("hazardtest"):
		_join({"name": "Test Hand", "appearance": Jobs.random_appearance(Game.rng), "job": "engineer", "pronoun": "they"})
		auto_quit = float(args.get("autotest", "-1"))
		shot_dir = args.get("shots", "")
		if args.has("fullbright"):
			Game.lighting.full_bright = true
		if args.has("zoom"):
			view.zoom_level = float(args["zoom"])
		if args.has("speed"):
			Game.time_scale = float(args["speed"])
		if args.has("nolight"):
			view.lightmap.visible = false
		if args.has("bare"):
			# diagnostics: strip every overlay layer so only terrain and entities remain
			view.snow.visible = false
			view.gas_root.visible = false
			for ch in view.get_children():
				if ch.get_class() == "Node2D" and ch.name in ["AtmosOverlay", "TRayLayer", "PipeDebugLayer", "PipeHover"]:
					ch.visible = false
			for ch in view.get_children():
				var s2 := str(ch.get_script().resource_path) if ch.get_script() else ""
				if "atmos_overlay" in s2 or "tray_layer" in s2 or "pipe_debug" in s2 or "pipe_hover" in s2 or "thermal" in s2 or "echo" in s2:
					ch.visible = false
		if args.has("hidehud"):
			Game.hud.root.visible = false
		if args.has("day"):
			Game.sky.day_t = float(args["day"])
		if args.has("at"):
			var parts: PackedStringArray = args["at"].split(",")
			Game.player.place(Vector2i(int(parts[0]), int(parts[1])))
		if args.has("rich"):
			Economy.infinite = true
		if args.has("onisland"):
			# stand in the middle of the home island, for looking at the place
			if not gen.home.is_empty():
				var surf: Array = gen.home["surface"]
				if not surf.is_empty():
					Game.player.place(surf[surf.size() / 2])
		if args.has("turnshot"):
			# hold her mid-sweep so the hull can be seen at a real angle
			var sh2 := player_ship
			if sh2 != null:
				for b2 in sh2.boilers:
					var bc2: CBoiler = b2.c(&"boiler")
					if bc2 != null:
						bc2.lit = true
						bc2.pressure = 62.0
				sh2.wanted_angle = wrapf(sh2.angle + float(args.get("turnshot", "0.9")), -PI, PI)
		if args.has("uishot"):
			# open the ship panel and put the player at the wheel, for a look at the UI
			ship_panel.toggle()
			var sh := player_ship
			if sh != null and sh.helm != null:
				for b in sh.boilers:
					var bc: CBoiler = b.c(&"boiler")
					if bc != null:
						bc.lit = true
						bc.pressure = 62.0
				Game.player.place(sh.helm.cell + Vector2i(0, 1) if Game.map.is_passable(sh.helm.cell + Vector2i(0, 1)) else Game.player.cell)
				sh.helm.c(&"helm").take(Game.player)
				sh.throttle = 0.7
				sh.sails_set = 0.0
				sh.ballast = -0.4
				sh.heading = (sh.facing + 1) % 4
		if args.has("arrivalshot") and player_ship != null:
			# replay the moment a ship becomes yours, for a look at the drop and the banner
			Game.fleet.announce_arrival(player_ship)
			shot_t = 0.5
		if args.has("refitdemo") and player_ship != null:
			# QA: open a refit on the player's ship with one extra deck tile and press Build
			Economy.set_purse(Game.player, int(args.get("purse", "9000")))
			Shipyard.open_refit(Game.player, player_ship)
			var ry: Shipyard = Shipyard._open
			if ry != null:
				for rk in ry.cells.keys():
					if not ry.cells.has(rk + Vector2i(0, -1)):
						ry.cells[rk + Vector2i(0, -1)] = "="
						break
				ry._refresh_stats()
				if String(args.get("refitdemo", "")) != "hold":  # =hold leaves the board open for a screenshot
					ry._demo = "launch"
		if args.has("yardshot"):
			# open the drawing board at a yard desk, for a look at the builder
			for de in Game.all_with(&"shipyard"):
				var beside: Vector2i = de.cell + Vector2i(0, 1)
				Game.player.place(beside if Game.map.is_passable(beside) else Game.player.cell)
				Economy.set_purse(Game.player, int(args.get("purse", "2600")))
				Shipyard.open(Game.player, de.c(&"shipyard"))
				var sy: Shipyard = Shipyard._open
				if sy != null and args.has("hullpick"):
					sy._start_from(args["hullpick"])
					sy._center_view()
					sy._refresh_stats()
				break
		if args.has("shopshot"):
			var keeper: Entity = null
			var want: String = args.get("shopshot", "1")
			for ke in Game.all_with(&"vendor"):
				var v: CVendor = ke.c(&"vendor")
				if keeper == null or (want != "1" and v.trade == want):
					keeper = ke
			print("SHOPSHOT: keeper=%s" % (keeper.display_name if keeper != null else "NONE"))
			if keeper != null:
				var beside2: Vector2i = keeper.cell + Vector2i(0, 1)
				Game.player.place(beside2 if Game.map.is_passable(beside2) else keeper.cell + Vector2i(0, -1))
				Economy.set_purse(Game.player, 40000)
				Game.hud.open_window("shop", keeper)
				for wnd in Game.hud.windows.get_children():
					print("SHOPSHOT: window %s pos=%s size=%s vis=%s children=%d" % [
						wnd.get("kind"), wnd.position, wnd.size, wnd.visible, wnd.get_child_count()])
		if args.has("craftshot"):
			for id in ["iron_ingot", "ore_iron", "sky_timber", "fibre_bundle", "ore_aetherite", "sheet_metal", "cable_coil"]:
				for _i in 8:
					if Proto.has(id):
						Economy.deliver(Game.player, Proto.spawn(id, Game.player.root_cell()))
			Game.hud.open_window("skycraft", null)
		if args.has("noticeshot"):
			for be in Game.all_with(&"noticeboard"):
				Game.hud.open_window("notices", be)
				break
		if args.has("skillshot"):
			for sk in Skills.SKILLS:
				Skills.set_level(Game.player, sk, Game.rng.randi_range(1, 60))
			Game.hud.open_window("skills", null)
		if args.has("airtest"):
			_air_test()
		if args.has("buildtest"):
			_build_test()
		if args.has("flytest"):
			_fly_test()
		if args.has("fps"):
			view_mode.set_active(true)
			if args.has("look"):
				view_mode.view3d.yaw = deg_to_rad(float(args["look"]))
		if args.has("flighttest"):
			auto_quit = -1.0
			Game.running = false
			add_child(FlightTest.new())
		elif args.has("inventorytest"):
			auto_quit = -1.0
			var test := InventoryTest.new()
			test.dir = args["inventorytest"]
			add_child(test)
		elif args.has("systemtest"):
			auto_quit = -1.0
			add_child(SkyPolishTest.new())
		elif args.has("boardtest"):
			auto_quit = -1.0
			add_child(BoardTest.new())
		elif args.has("hazardtest"):
			auto_quit = -1.0
			add_child(HazardTest.new())
		elif args.has("decktest"):
			auto_quit = -1.0
			var test := DeckTest.new()
			test.shot_dir = String(args.get("deckshot", ""))
			add_child(test)
		print("LIGHT ambient=%s day_t=%.2f phase=%s fullbright=%s" % [
			Game.lighting.ambient, Game.sky.day_t, Game.sky.phase_name(), Game.lighting.full_bright])
	else:
		open_creator()

func _sys(n: Node, nm: String) -> Node:
	n.name = nm
	add_child(n)
	return n

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.5
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
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.08
	we.environment = env
	add_child(we)

# ------------------------------------------------------------------ population
## Daytime wildlife. Night creatures are held back by SkySystem until dusk.
func _spawn_fauna() -> void:
	var n := 0
	# Nothing hunts within sight of the mooring. The first thing a new player should do is
	# look around their ship, not be eaten beside it.
	var safe: Vector2i = gen.hub_center
	for rec in gen.mob_spawns:
		if rec["night"]:
			continue
		var c: Vector2i = rec["cell"]
		if not Game.map.is_passable(c):
			continue
		if maxi(absi(c.x - safe.x), absi(c.y - safe.y)) < SAFE_RADIUS:
			continue
		var made := SkyMobs.spawn_group(rec["mob"], c, float(rec.get("power", 1.0)))
		n += made.size()
	print("Skyfarer9: %d creatures abroad by day, %d waiting for dusk" % [n, Game.sky.night_pending.size()])

## The player's ship, moored off the home island with the gangway out.
func _launch_player_ship() -> void:
	var hull: String = args.get("hull", "skiff")
	# Only launch from a berth with a proven walk from the quay onto her deck.
	var out: Vector2i = gen.ship_start_dir          # from the coast toward open sky
	var berth := Mooring.plan(ShipPlan.to_cells(ShipPlan.get_hull(hull)["plan"], ShipPlan.get_hull(hull)["keel"]),
		gen.ship_start, out)
	if not berth.is_empty():
		player_ship = Game.fleet.add_ship(hull, berth["origin"], berth["dir"], "Kestrel")
	if player_ship == null:
		push_error("could not place the player's ship at a walkable berth")
		return
	Game.fleet.player_ship = player_ship
	# she starts fuelled, charged and cold: light the boiler yourself
	for b in player_ship.bunkers:
		var fb: CFuelBunker = b.c(&"fuelbunker")
		if fb != null:
			fb.amount = fb.capacity
	for l in player_ship.lift_cells:
		var lc: CLiftCell = l.c(&"liftcell")
		if lc != null:
			lc.charge = 1.0
	# a starting kit in the emergency locker
	for p in player_ship.parts:
		if p.proto == "locker" and p.display_name.begins_with("emergency"):
			var st: CStorage = p.c(&"storage")
			if st != null:
				for item in ["glider_pack", "sky_compass", "grapple_gun", "toolbox", "flashlight",
						"fuel_can", "ship_rig", "sheet_wood", "sheet_wood", "sheet_glass"]:
					if Proto.has(item):
						st.insert(Proto.spawn(item, p.cell))
			break

# ------------------------------------------------------------------ joining
func open_creator() -> void:
	creator = CharCreator.new()
	creator.diagnostic_mode = args.has("introshot") or args.has("chargentest")
	Game.hud.root.add_child(creator)
	creator.done.connect(_join)
	if args.has("introshot"):
		var sh := Intro.Shots.new()
		sh.dir = String(args["introshot"])
		sh.main = self
		add_child(sh)
	elif args.has("chargentest"):
		var test := ChargenTest.new()
		test.dir = String(args["chargentest"])
		add_child(test)

func _join(cfg: Dictionary) -> void:
	var cell := _boarding_cell()
	var p := Crew.spawn_human(cfg["job"], cell, {"name": cfg["name"], "appearance": cfg["appearance"],
		"pronoun": cfg["pronoun"], "player": true, "saved": cfg.get("saved", {}), "quirks": cfg.get("quirks", [])})
	Game.player = p
	Bus.player_changed.emit(p)
	if player_ship != null:
		Underdecks.ensure(player_ship)
	Game.running = true
	Game.hud.refresh_inventory()
	helm_panel = HelmPanel.new()
	Game.hud.root.add_child(helm_panel)
	tutorial = Tutorial.new()
	Game.hud.root.add_child(tutorial)
	ship_panel = ShipPanel.new()
	Game.hud.root.add_child(ship_panel)
	Game.view.camera.position = p.position
	Game.view.camera.reset_smoothing()
	# The trade they came from decides their skills, their kit and what is in their purse,
	# so it has to be applied before a single line of the opening reads any of those.
	p.tags["sky_class"] = String(cfg.get("sky_class", "deckhand"))
	SkyClasses.apply(p, String(cfg.get("sky_class", "deckhand")))
	_starting_kit(p)
	var isl_name: String = gen.home["name"] if not gen.home.is_empty() else "somewhere"
	Game.msg("[b][color=#9ad8ff]Port %s, in %s — two thousand feet over nothing at all.[/color][/b]" % [
		isl_name, gen.region_name], "info")
	if player_ship != null:
		Game.msg("Your ship [b]%s[/b] is moored alongside. She is fuelled and her cells are full, but her boiler is cold." % player_ship.ship_name, "info")
	else:
		Game.msg("You have [b][color=#e8c85a]%s marks[/color][/b]. A second-hand skiff at the yard is about %s." % [
			Economy.money(Economy.purse(p)), Economy.money(3200)], "good" if Economy.purse(p) >= 3203 else "info")
		Game.msg("[color=#e8d8a0]The yard is at the end of the quay. Buy a hull out of the book, or spend the same money on one you draw yourself.[/color]", "info")
		Game.msg("[i]Read the notice board by the gangway if you have never been up here before.[/i]", "info")
	Game.msg("[b]F1[/b] controls · [b]G[/b] ship · [b]J[/b] bench · [b]I[/b] drawing board · [b]P[/b] skills · [b]F7[/b] hide prompts.", "info")
	# the cold open: the port's name, where it is, and the one decision it wants from you
	if not (args.has("autotest") or args.has("flighttest") or args.has("systemtest") or args.has("boardtest") or args.has("decktest")):
		var card := Intro.new().setup(isl_name, gen.region_name,
			_home_ring(), Economy.purse(p), player_ship != null, String(cfg["name"]),
			String(SkyClasses.info(String(cfg.get("sky_class", "deckhand")))["name"]))
		Game.hud.root.add_child(card)
	Bus.chronicle.emit("%s came ashore at %s with %s marks and no ship." % [
		cfg["name"], isl_name, Economy.money(Economy.purse(p))] if player_ship == null
		else "%s signed aboard the %s." % [cfg["name"], player_ship.ship_name], 1)

## Which ring the home port is in, for the intro card. Always the innermost one.
func _home_ring() -> String:
	return Biomes.ring_name(0)

## What a skyfarer arrives with: the clothes they stand up in and the tools that make the
## first hour possible. Deliberately meagre — every one of these is also the cheapest
## thing in the chandlery, so a player who loses one knows exactly where to get another.
func _starting_kit(p: Entity) -> void:
	var inv: CInventory = p.c(&"inv")
	if inv == null:
		return
	# Deliberately thin: the class gave them their trade's tools, and everything here is
	# also the cheapest thing in the chandlery, so a player who loses one knows where to
	# get another. Anything already carried is skipped.
	var have := {}
	for it in inv.all_items(true):
		have[it.proto] = true
	for id in ["rations_sky", "flashlight"]:
		if have.has(id):
			continue
		if not Proto.has(id):
			continue
		var it := Proto.spawn(id, p.root_cell())
		if it != null:
			Economy.deliver(p, it)

## Somewhere sensible to appear: on the quay at Meridian if there is one, on the deck of
## the ship if the old opening was asked for, anywhere solid if neither worked.
func _boarding_cell() -> Vector2i:
	if player_ship == null and not gen.home.is_empty() and gen.home.has("quay"):
		var q: Dictionary = gen.home["quay"]
		var at: Vector2i = q["cell"]
		var along: Vector2i = q["along"]
		var out: Vector2i = q["dir"]
		for k in range(0, 12):
			for side in [1, -1]:
				var c: Vector2i = at + along * (k * side) - out
				if Game.map.is_passable(c) and Game.at(c).is_empty() and Falling.supported(c):
					return c
	if player_ship != null and player_ship.present:
		for c in player_ship.deck_cells:
			if Game.map.is_passable(c) and Game.at(c).is_empty():
				return c
	var way: Array = Game.fleet.gangway(player_ship) if player_ship != null else []
	if way.size() == 2:
		return way[1]
	if not gen.home.is_empty():
		var surf: Array = gen.home["surface"]
		for c in surf:
			if Game.map.is_passable(c) and Game.at(c).is_empty():
				return c
	return gen.ship_start

# ------------------------------------------------------------------ events
func _on_died(e: Entity) -> void:
	if e.tags.has("beast"):
		SkyMobs.drop_loot(e, _last_killer(e))
		_kill_xp(e)

## Whoever landed the killing blow, for skinning yields and combat experience.
func _last_killer(e: Entity) -> Entity:
	var ai: CBeastAI = e.c(&"beastai")
	if ai != null and ai.last_hit_by != null and is_instance_valid(ai.last_hit_by) and not ai.last_hit_by.removed:
		return ai.last_hit_by
	# fall back to the player if they are close enough to plausibly have done it
	if Game.player != null and Game.player.dist_to(e) <= 3:
		return Game.player
	return null

## Killing things is how a skyfarer learns to fight, and what it teaches depends on what
## you killed it with and how hard it was.
func _kill_xp(e: Entity) -> void:
	var who := _last_killer(e)
	if who == null or who != Game.player:
		return
	var d: Dictionary = SkyMobs.get_beast(String(e.tags.get("beast", "")))
	if d.is_empty():
		return
	var power := float(e.tags.get("power", 1.0))
	var worth := (float(d["hp"]) * 0.22 + float(d["dmg"]) * 1.1) * power
	var inv: CInventory = who.c(&"inv")
	var held: Entity = inv.hands[inv.active] if inv != null else null
	var skill := "unarmed"
	if held != null and is_instance_valid(held):
		if held.has_c(&"aethergun"):
			skill = "marksman"
		elif held.has_c(&"item") and held.c(&"item").force > 6:
			skill = "melee"
	Skills.add_xp(who, skill, worth)

## A ship has climbed or sunk out of this band. Rebuild the region at the new altitude
## and put the ship back into it — the Cloudsea is one region deep at a time.
func _transit(sh: Airship, downward: bool) -> void:
	if sh != player_ship:
		# somebody else's ship simply leaves this sky
		sh.remove()
		return
	var new_band := clampi(Defs.band_index(gen.altitude) + (-1 if downward else 1), 0, 4)
	Game.msg("[b][color=#9ad8ff]You cross into %s.[/color][/b]" % Defs.ALT_NAMES[new_band], "info")
	Bus.chronicle.emit("The %s crossed into %s." % [sh.ship_name, Defs.ALT_NAMES[new_band]], 2)
	# Not yet: rebuilding the region under a flying ship needs the crew, the hull and the
	# cargo carried across intact. Hold at the boundary and say so plainly.
	sh.altitude = Defs.ALT_BANDS[Defs.band_index(gen.altitude)] + (0.25 if downward else -0.25)
	sh.ballast = 0.0
	Game.msg("[i]The cloud closes over. There is nowhere to go from here yet — trim level and stay in this sky.[/i]", "warn")

## Is the port actually habitable? Every shop is a sealed room built at generation time,
## and a sealed room with no air in it is a vacuum that freezes and suffocates whoever
## walks into it. This walks the port and prints what the air is doing in each of them.
func _air_test() -> void:
	var at = Game.atmos
	if at == null or gen.home.is_empty():
		print("AIRTEST: no atmosphere or no port")
		return
	var quay: Vector2i = gen.home.get("quay", {}).get("cell", gen.hub_center)
	print("AIRTEST quay %s: %s" % [quay, _air_line(quay)])
	var seen := {}
	for e in Game.all_with(&"vendor"):
		var a := Game.map.area_at(e.cell)
		if a == null or seen.has(a.id):
			continue
		seen[a.id] = true
		var lamps := 0
		var lit := 0.0
		for c in a.cells:
			for x in Game.at(c):
				if x.proto == "shop_lamp":
					lamps += 1
			if Game.lighting != null:
				lit = maxf(lit, Game.lighting.light_at(c) if Game.lighting.has_method("light_at") else 0.0)
		print("AIRTEST %-26s %s  cells=%d  lamps=%d  brightest=%.2f" % [
			a.name, _air_line(e.cell), a.cells.size(), lamps, lit])
	for e in Game.all_with(&"shipyard"):
		print("AIRTEST yard desk at %s: %s" % [e.cell, _air_line(e.cell)])
	# and the walk: can you actually get from the quay to every door?
	_reach_test(quay)

## A tile you can get through by opening something.
func _is_door(c: Vector2i) -> bool:
	for e in Game.at(c):
		if e.has_c(&"door"):
			return true
	return false

func _air_line(c: Vector2i) -> String:
	var at = Game.atmos
	var i := Game.map.idx(c)
	var total := 0.0
	for g in Defs.GAS_COUNT:
		total += float(at.gas[g][i])
	var kpa: float = total * Defs.R_IDEAL * at.temp[i] / Defs.CELL_VOLUME
	var o2: float = at.gas[Defs.G_O2][i]
	return "%6.1f kPa  %6.1f C  O2 %5.1f mol%s" % [kpa, at.temp[i] - Defs.T0C, o2,
		"   *** UNBREATHABLE ***" if (kpa < 16.0 or o2 < 1.0) else ""]

## Flood-fill from the quay and check every door and counter is on the walkable side of
## it. A port you cannot walk round is not a port.
func _reach_test(from: Vector2i) -> void:
	var seen := {from: true}
	var q := [from]
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		for d in Defs.DIRS4:
			var nc: Vector2i = cur + d
			if seen.has(nc) or not Game.map.inb(nc):
				continue
			if not Falling.supported(nc):
				continue
			# a shut door is a door, not a wall: a person opens it and walks through
			if not Game.map.is_passable(nc) and not _is_door(nc):
				continue
			seen[nc] = true
			q.append(nc)
	var bad := 0
	var total := 0
	# only this island: a shopkeeper three rings away is not meant to be walkable to
	var own := {}
	for c in (gen.home["cells"] as Array):
		own[c] = true
	for e in Game.all_with(&"vendor"):
		if not own.has(e.cell):
			continue
		total += 1
		var ok := false
		for d in Defs.DIRS8:
			if seen.has(e.cell + d):
				ok = true
		if not ok:
			bad += 1
			print("AIRTEST *** %s at %s cannot be reached from the quay ***" % [e.display_name, e.cell])
	for e in Game.all_with(&"shipyard"):
		if not own.has(e.cell):
			continue
		total += 1
		var ok2 := false
		for d in Defs.DIRS8:
			if seen.has(e.cell + d):
				ok2 = true
		if not ok2:
			bad += 1
			print("AIRTEST *** the yard desk at %s cannot be reached from the quay ***" % e.cell)
	print("AIRTEST reach: %d of %d counters on the home island reachable on foot (%d tiles walkable)" % [
		total - bad, total, seen.size()])
	# and the doors themselves, which is where a blockage actually shows
	for a in Game.map.areas:
		if a.room_kind != "shop" or a.cells.is_empty() or not own.has(a.cells[0]):
			continue
		var door := Vector2i(-9999, -9999)
		for c in a.cells:
			for e in Game.at(c):
				if e.has_c(&"door"):
					door = c
		print("AIRTEST   %-24s door %s  %s" % [a.name, door,
			"reachable" if seen.has(door) else "*** WALLED IN ***"])

## The whole player-facing loop, driven the way a player drives it: stand at the boiler and
## light it, click the wheel, hold W, then stop alongside land and climb over the rail.
var _loop_stage := 0
var _loop_t := 0.0
var _before_turn := 0
var _parts_before := 0

func _loop_test(delta: float) -> void:
	if not args.has("looptest") or Game.player == null or player_ship == null:
		return
	_loop_t -= delta
	if _loop_t > 0.0:
		return
	_loop_t = 1.0
	var p := Game.player
	var sh := player_ship
	match _loop_stage:
		0:
			# first: can you get off the ship where she is moored?
			var got := false
			for c in sh.deck_cells:
				for d in Defs.DIRS4:
					var rail: Vector2i = c + d
					if not Climb.climbable_turf(Game.map.get_turf(rail)):
						continue
					p.place(c)
					if Climb.can_climb(p, rail):
						print("LOOP A: climbing the rail at %s from deck %s" % [rail, c])
						Climb.start(p, rail)
						got = true
						break
				if got:
					break
			if not got:
				print("LOOP A: *** no way ashore from the mooring ***")
			_loop_stage = 10
			_loop_t = 2.0
		10:
			print("LOOP B: ashore = %s (at %s)" % [not sh.is_aboard(p), p.cell])
			_loop_stage = 11
			_loop_t = 0.5
		11:
			# and back aboard again over the same rail
			for d in Defs.DIRS4:
				var rail2: Vector2i = p.cell + d
				if Climb.climbable_turf(Game.map.get_turf(rail2)) and Climb.can_climb(p, rail2):
					Climb.start(p, rail2)
					break
			_loop_stage = 12
			_loop_t = 2.0
		12:
			print("LOOP C: back aboard = %s" % sh.is_aboard(p))
			_loop_stage = 1
		1:
			# walk to the boiler the way a player would: find it, stand beside it
			var b = sh.boilers[0] if not sh.boilers.is_empty() else null
			if b == null:
				print("LOOP: no boiler"); _loop_stage = 99; return
			p.place(b.cell + Vector2i(0, 1) if Game.map.is_passable(b.cell + Vector2i(0, 1)) else sh.deck_cells[0])
			print("LOOP: standing by the boiler at %s" % p.cell)
			_loop_stage = 2
		2:
			var b = sh.boilers[0]
			Interact.click(p, b, b.cell)
			var fired := false
			for v in b.get_verbs(p):
				if String(v["name"]).begins_with("Light"):
					v["cb"].call()   # exactly how HUD.context_actions invokes a verb
					fired = true
			print("LOOP: 'Light the burner' verb fired = %s, boiler lit = %s" % [
				fired, b.c(&"boiler").lit])
			print("LOOP D: boiler lit, pressure building")
			_loop_stage = 3
		3:
			if not sh.steam_up():
				return # wait for pressure
			var hlm = sh.helm
			p.place(hlm.cell + Vector2i(0, 1) if Game.map.is_passable(hlm.cell + Vector2i(0, 1)) else p.cell)
			Interact.click(p, hlm, hlm.cell)
			print("LOOP E: took the wheel = %s" % (Helm.of(p) != null))
			_loop_stage = 4
		4:
			# this is what holding W does
			var h := Helm.of(p)
			if h == null:
				print("LOOP 3: FAILED - not at the wheel"); _loop_stage = 99; return
			sh.throttle = 1.0
			sh.ballast = -0.85
			print("LOOP F: throttle open, trim %.2f" % sh.ballast)
			_loop_stage = 5
		5:
			if sh.speed() > 0.5:
				print("LOOP G: under way at %.1f kt, %.2f km" % [sh.speed(), sh.altitude])
				# and come about, to prove nothing is thrown off the deck
				_before_turn = sh.occupants().size()
				_parts_before = sh.parts.size()
				sh.heading = (sh.facing + 1) % 4
				_loop_stage = 6
				_loop_t = 6.0
		6:
			print("LOOP H: came about to %s — %d aboard (was %d), %d fittings (was %d)" % [
				["N","E","S","W"][sh.facing], sh.occupants().size(), _before_turn,
				sh.parts.size(), _parts_before])
			var stray := 0
			for prt in sh.parts:
				if is_instance_valid(prt) and not prt.removed and not prt.cell in sh.cells:
					stray += 1
			print("LOOP I: fittings outside the hull after turning: %d%s" % [
				stray, "  *** SCATTERED ***" if stray > 0 else "  (none)"])
			print("LOOP J: player still aboard = %s" % sh.is_aboard(p))
			_loop_stage = 99
		20:
			# look for land beside the hull
			for c in sh.cells:
				for d in Defs.DIRS4:
					var n: Vector2i = c + d
					if n in sh.cells:
						continue
					if Game.map.inb(n) and not Defs.is_void_turf(Game.map.get_turf(n)):
						sh.throttle = 0.0
						sh.vel = Vector2.ZERO
						print("LOOP 5: alongside land at %s" % n)
						_loop_stage = 6
						return
		6:
			# find a rail with land beyond it and climb it
			for c in sh.deck_cells:
				for d in Defs.DIRS4:
					var rail: Vector2i = c + d
					if not Climb.climbable_turf(Game.map.get_turf(rail)):
						continue
					p.place(c)
					if Climb.can_climb(p, rail):
						print("LOOP 6: climbing the rail at %s from deck %s" % [rail, c])
						Climb.start(p, rail)
						_loop_stage = 7
						_loop_t = 2.5
						return
			print("LOOP 6: no climbable rail with footing beyond it")
			_loop_stage = 99
		7:
			print("LOOP 7: ashore = %s (player at %s, aboard = %s)" % [
				not sh.is_aboard(p), p.cell, sh.is_aboard(p)])
			_loop_stage = 99

## Does building work, and does what you built stay built when she moves? Extends the
## hull off the stern, encloses a cabin, then hands over to the flight test.
func _build_test() -> void:
	var sh := player_ship
	if sh == null:
		print("BUILDTEST: no ship")
		return
	var before: int = sh.cells_map.size()
	var mass0 := sh.mass()
	var b := ShipPlan.bounds(sh.cells_map)
	# a three-by-three bay hung off the port beam, walled and roofed as a cabin
	var u0: int = b.position.x + 2
	var v0: int = b.end.y # just outside the current beam
	var added := 0
	for v in range(v0, v0 + 3):
		for u in range(u0, u0 + 3):
			var ch := "=" if (u > u0 and u < u0 + 2 and v > v0 and v < v0 + 2) else "I"
			if v == v0 and u == u0 + 1:
				ch = "+" # a door back into the ship
			sh.set_piece(Vector2i(u, v), ch)
			added += 1
	var leaks := ShipPlan.leaks_of(sh.cells_map)
	print("BUILDTEST: %d pieces -> %d (added %d), mass %.0f -> %.0f, leaks %d" % [
		before, sh.cells_map.size(), added, mass0, sh.mass(), leaks.size()])
	print("BUILDTEST: deck %d, inside %d" % [sh.deck_cells.size(), sh.inside_cells.size()])
	_built_check = Vector2i(u0 + 1, v0 + 1)

var _built_check := Vector2i(-9999, -9999)

func _verify_built(_delta: float) -> void:
	if _built_check.x < -9000 or player_ship == null:
		return
	var world := player_ship.cell(_built_check.x, _built_check.y)
	var t: int = Game.map.turf[Game.map.idx(world)] if Game.map.inb(world) else -1
	print("BUILDTEST: the new cabin tile is now at %s, turf %s (%s)" % [
		world, t, "moved with her" if t == Defs.T_DECK else "LOST"])
	_built_check = Vector2i(-9999, -9999)

## Does the ship actually fly? Lights the boiler, takes the wheel, opens the throttle and
## reports what happens, so the core loop is verified rather than assumed.
var _fly_t := 0.0
var _flying := false

func _fly_test() -> void:
	if player_ship == null:
		print("FLYTEST: no ship")
		return
	for b in player_ship.boilers:
		var bc: CBoiler = b.c(&"boiler")
		if bc != null:
			bc.lit = true
			bc.damper = 1.0
			bc.valve_open = true
	var helm := player_ship.helm
	if helm == null:
		print("FLYTEST: no helm")
		return
	helm.c(&"helm").take(Game.player)
	player_ship.throttle = 1.0
	player_ship.ballast = -0.26 # trim down to hold level
	if args.has("freeturn"):
		# lift her clear of the island first, so the sweep is not fighting the rock
		var away: Vector2i = player_ship._fwd() * 14
		player_ship._restamp(player_ship.origin + away, player_ship.facing)
		player_ship.pos += Vector2(away)
	# put the rudder hard over and leave it there, to watch her come right round
	player_ship.wanted_angle = wrapf(player_ship.angle + PI * 0.95, -PI, PI)
	_flying = true
	print("FLYTEST: boiler lit, wheel taken, throttle full. start=%s alt=%.2f" % [
		player_ship.origin, player_ship.altitude])

func _fly_report(delta: float) -> void:
	if not _flying or player_ship == null:
		return
	_fly_t -= delta
	if _fly_t > 0.0:
		return
	_fly_t = 0.7
	if Game.time > 16.0 and _flying:
		player_ship.throttle = 0.0   # all stop, and watch her square up
	if Game.time > 14.0:
		_verify_built(0.0)
	print("FLYTEST t=%5.1f  bow %6.1f deg (stamped %s)  want %6.1f  %.2f kt  vel %s" % [
		Game.time, rad_to_deg(player_ship.angle), ["N","E","S","W"][player_ship.facing],
		rad_to_deg(player_ship.wanted_angle), player_ship.speed(), player_ship.vel])

# ------------------------------------------------------------------ checks
func _gencheck() -> void:
	var land := 0
	var void_tiles := 0
	for i in Game.map.w * Game.map.h:
		if Defs.is_void_turf(Game.map.turf[i]):
			void_tiles += 1
		else:
			land += 1
	print("GENCHECK tiles: %d land, %d sky (%.1f%% land)" % [land, void_tiles, 100.0 * land / float(land + void_tiles)])
	print("GENCHECK islands: %d, moorings: %d, fauna records: %d" % [
		gen.islands.size(), gen.moorings.size(), gen.mob_spawns.size()])
	var no_moor := []
	for isl in gen.islands:
		if not isl.has("mooring"):
			no_moor.append(isl["name"])
	print("GENCHECK islands with no mooring: %d %s" % [no_moor.size(), no_moor])
	# the port, which is now where the game starts and therefore the thing worth checking
	if gen.home.is_empty():
		print("GENCHECK hub: *** NO HOME ISLAND ***")
	else:
		var shops := 0
		var yards := 0
		for e in Game.all_with(&"vendor"):
			shops += 1
		for e in Game.all_with(&"shipyard"):
			yards += 1
		print("GENCHECK hub: %s, quay %s, berth %s, %d traders, %d yard desks%s" % [
			gen.home["name"], gen.home.get("quay", {}).get("cell", Vector2i.ZERO),
			gen.ship_start, shops, yards,
			"" if yards > 0 and shops >= 5 else "  *** PORT INCOMPLETE ***"])
		print("GENCHECK ports: %d in the region (%s)" % [gen.ports.size(),
			", ".join(gen.ports.map(func(i): return "%s r%d" % [i["name"], int(i.get("tier", 0))]))])
		var start := _boarding_cell()
		print("GENCHECK spawn: %s (%s)" % [start,
			"walkable" if Game.map.is_passable(start) and Falling.supported(start) else "*** NOT WALKABLE ***"])
	for hid in ShipPlan.all_ids():
		var hh := ShipPlan.get_hull(hid)
		var hc := ShipPlan.to_cells(hh["plan"], int(hh["keel"]))
		var dg := ShipPlan.diagnose(hc, Airship.default_fittings(hc, int(hh.get("grade", 1))))
		print("GENCHECK diagnose %s: %s" % [hid, "clean" if dg.is_empty() else str(dg.map(func(d): return "%s:%s" % [d["severity"], d["code"]]))])
	print("GENCHECK modules: %d in the catalogue, %d recipes, %d prototypes" % [
		ShipParts.MODULES.size(), SkyCrafting.RECIPES.size(), Proto.P.size()])
	# what a hull off the shelf actually costs, against the purse a new skyfarer is given.
	# The starting purse is meant to be "near enough the price of a skiff", and the only
	# way to keep that true as the module catalogue changes is to print it.
	for hid in ShipPlan.all_ids():
		var hh := ShipPlan.get_hull(String(hid))
		var hc := ShipPlan.to_cells(hh["plan"], int(hh["keel"]))
		var hf := Airship.default_fittings(hc, int(hh.get("grade", 1)))
		var gcost := 0
		for k in hc:
			gcost += CShipyard.glyph_cost(String(hc[k]))
		var mcost := 0
		for k in hf:
			mcost += int(ShipParts.stat(String(hf[k]), "cost", 0.0))
		print("GENCHECK hull %-9s grade %d  %3d cells  hull %5d + fit %5d = %6d marks%s" % [
			hid, int(hh.get("grade", 1)), hc.size(), gcost, mcost, int((gcost + mcost) * 1.18),
			"   <- the purse buys this" if int((gcost + mcost) * 1.18) <= Economy.STARTING_PURSE else ""])
	if player_ship != null:
		print("GENCHECK ship: %s at %s, %d cells, %d deck, %d inside, mass %.0f, lift %.0f, fuel %.0f" % [
			player_ship.ship_name, player_ship.origin, player_ship.cells.size(),
			player_ship.deck_cells.size(), player_ship.inside_cells.size(),
			player_ship.mass(), player_ship.lift(), player_ship.fuel()])
		print("GENCHECK ship buoyancy %.2f, thrusters %d, lift cells %d, breaches %d" % [
			player_ship.buoyancy(), player_ship.thrusters.size(), player_ship.lift_cells.size(),
			player_ship.breaches()])
	else:
		print("GENCHECK ship: none — the player buys one in the yard (pass --ship for the old opening)")
	if player_ship != null:
		# The question the player actually asks: can I get off this thing?
		var spots := []
		for c in player_ship.deck_cells:
			for d in Defs.DIRS4:
				var rail: Vector2i = c + d
				if not Climb.climbable_turf(Game.map.get_turf(rail)):
					continue
				var beyond: Vector2i = rail + d
				if Game.map.inb(beyond) and not Defs.is_void_turf(Game.map.get_turf(beyond)) 						and not Game.map.blocks_move_static(beyond):
					spots.append(beyond)
		print("GENCHECK gangway: %d places you can climb ashore from the deck%s" % [
			spots.size(), ("  e.g. " + str(spots[0])) if not spots.is_empty() else "  *** NO WAY OFF ***"])
	if player_ship != null:
		var r: Rect2i = Rect2i(player_ship.origin - Vector2i(3, 6), Vector2i(20, 14))
		print("GENCHECK ship turfs (origin %s):" % player_ship.origin)
		for y in range(r.position.y, r.end.y):
			var line := ""
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if not Game.map.inb(c):
					line += "?"
					continue
				var t: int = Game.map.turf[Game.map.idx(c)]
				line += {Defs.T_SKY: ".", Defs.T_CLOUD: "~", Defs.T_DECK_OPEN: "d",
					Defs.T_DECK: "=", Defs.T_DECK_PLATE: "p", Defs.T_HULLWOOD: "#",
					Defs.T_KEEL: "K"}.get(t, String.chr(97 + t % 26))
			print("   |%s|" % line)
	var missing := {}
	for isl in gen.islands:
		for row in isl["b"]["flora"]:
			if not Proto.has(str(row[0])):
				missing[str(row[0])] = true
		for row in isl["b"]["fauna"] + isl["b"]["night"]:
			if not SkyMobs.BEASTS.has(str(row[0])):
				missing["mob:" + str(row[0])] = true
	print("GENCHECK missing prototypes: %d %s" % [missing.size(), missing.keys()])

# ------------------------------------------------------------------ pause / loop
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
	for pair in [["Resume", "resume"], ["Settings", "settings"], ["Controls", "help"], ["Log", "log"], ["Quit", "quit"]]:
		var b := Button.new()
		b.text = pair[0]
		var id: String = pair[1]
		b.pressed.connect(func(): _pause_action(id))
		v.add_child(b)

func _pause_action(id: String) -> void:
	match id:
		"resume": toggle_pause()
		"settings": Game.hud.open_settings()
		"help": Game.hud.open_window("help", null)
		"log": Game.hud.open_window("chronicle", null)
		"quit": get_tree().quit()

func _process(delta: float) -> void:
	SPerf.frame(delta)
	_loop_test(delta)
	_fly_report(delta)
	if auto_quit > 0:
		auto_quit -= delta
		if shot_dir != "":
			shot_t -= delta
			if shot_t <= 0:
				shot_t = 1.2 if args.has("arrivalshot") else 6.0
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
	print("entities %d, active atmos %d" % [Game.entities.size(), Game.atmos.active.size()])
	print(Game.sky.status_text())
	print(Game.fleet.status_text())
	var alive := 0
	for e in Game.all_with(&"beastai"):
		var h: CHealth = e.c(&"health")
		if h != null and not h.dead:
			alive += 1
	print("creatures alive: %d" % alive)
	for en in Game.chronicle.entries:
		print("  [%s] %s" % [en["clock"], en["text"]])
