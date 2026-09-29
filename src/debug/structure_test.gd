class_name StructureTest extends Node
## --structtest: breaks windows and grilles the tg way and checks the numbers against
## window.dm / grille.dm / atom_defense.dm, plus the tg item stats hitting them.
## Prints STRUCT PASS/FAIL lines and quits.

var fails := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	_armor_math()
	_crack_stages()
	_item_stats()
	_mapgen()
	var spot := _window_spot()
	if spot.is_empty():
		_check("found a window with floor beside it", false)
	else:
		var a := Crew.spawn_human("assistant", spot["stand"], {"name": "Vandal"})
		a.remove_comp(&"brain")
		a.remove_comp(&"mood")
		Quirks.remove_all(a)
		for s in Skills.SKILLS:
			a.c(&"mob").xp[s] = 0.0
		var inv: CInventory = a.c(&"inv")
		for h in inv.hands.duplicate():
			if h:
				inv.drop(h)
		a.c(&"mob").combat = true
		await _break_window(a, spot["cell"])
		await _reinforced(a, spot["cell"])
		await _grille(a, spot["cell"])
		_heal(a) # A live grille can paralyze the fixture; rebuilding is a separate check.
		await _rebuild(a, spot["cell"])
		await _throw(a, spot["cell"])
		_explosion(spot["cell"])
		_heal(a)
		await _objects(a)
		await _shards(a)
	print("STRUCT DONE: %d failed" % fails)
	get_tree().quit()

# ------------------------------------------------------------------ pure numbers
func _armor_math() -> void:
	# window melee 50: a toolbox is 13 x 1.25 demolition = 16.25 -> 8.1
	_near("toolbox on a window: 16.25 through melee 50", Structures.run_armor(Defs.S_WINDOW, 16.25, "brute", "melee"), 8.1)
	# reinforced: melee 80 -> 3.25 (rounds to 3.2/3.3)
	_near("toolbox on a reinforced window: melee 80", Structures.run_armor(Defs.S_RWINDOW, 16.25, "brute", "melee"), 3.25, 0.06)
	# damage_deflection 11: a 10-force hit does nothing to reinforced glass
	_check("reinforced window deflects a 10 melee hit", Structures.run_armor(Defs.S_RWINDOW, 10.0, "brute", "melee") == 0.0)
	_check("plain window has no deflection", Structures.run_armor(Defs.S_WINDOW, 10.0, "brute", "melee") == 5.0)
	# a lit welder (15 burn) is a melee hit: melee armour only, not fire as well
	_near("lit welder on a window is 15 burn through melee 50", Structures.run_armor(Defs.S_WINDOW, 15.0, "burn", "melee"), 7.5)
	_near("fire (atmos) armour 80 on a window", Structures.run_armor(Defs.S_WINDOW, 25.0, "burn", "fire"), 5.0)
	_check("unarmoured damage goes straight through", Structures.run_armor(Defs.S_RWINDOW, 25.0, "burn", "") == 25.0)
	_check("toxin-type damage doesn't hurt structures", Structures.run_armor(Defs.S_WINDOW, 25.0, "tox", "melee") == 0.0)
	_near("armour penetration 20 vs grille melee 50", Structures.run_armor(Defs.S_GRILLE, 10.0, "brute", "melee", 20.0), 6.3, 0.06)
	_check("grille is 50 hp, window 100, reinforced 150", Structures.max_hp(Defs.S_GRILLE) == 50.0 and Structures.max_hp(Defs.S_WINDOW) == 100.0 and Structures.max_hp(Defs.S_RWINDOW) == 150.0)

func _crack_stages() -> void:
	var ok := Structures.crack_stage(100, 100) == 0 and Structures.crack_stage(76, 100) == 0 \
		and Structures.crack_stage(75, 100) == 75 and Structures.crack_stage(51, 100) == 75 \
		and Structures.crack_stage(50, 100) == 50 and Structures.crack_stage(26, 100) == 50 \
		and Structures.crack_stage(25, 100) == 25 and Structures.crack_stage(1, 100) == 25
	_check("crack overlays at 75/50/25% like tg update_overlays", ok)

func _item_stats() -> void:
	# tg values (force, throwforce, demolition_mod)
	var want := {
		"wrench": [5, 7, 1.25], "crowbar": [5, 7, 1.25], "screwdriver": [5, 5, 0.5],
		"extinguisher": [13, 13, 1.25], "toolbox": [13, 13, 1.25], "fireaxe": [5, 15, 1.25],
		"knife_kitchen": [10, 10, 0.75], "baseball_bat": [13, 13, 1.25], "rods": [9, 10, 1.25],
		"laser_gun": [5, 5, 1.0], "drink_booze": [15, 15, 0.25], "glass_shard": [5, 10, 1.0],
		"spear": [10, 20, 0.75], "scalpel": [10, 5, 0.25], "tank_o2": [10, 10, 1.25],
	}
	var bad := []
	for p in want:
		var e := Proto.spawn(p, Vector2i(1, 1))
		var it: CItem = e.c(&"item")
		if it.force != want[p][0] or it.throwforce != want[p][1] or not is_equal_approx(it.demolition, want[p][2]):
			bad.append("%s %s/%s/%s" % [p, it.force, it.throwforce, it.demolition])
		e.destroy()
	_check("item force/throwforce/demolition match tg %s" % (str(bad) if bad else ""), bad.is_empty())
	var sh := Proto.spawn("glass_shard", Vector2i(1, 1))
	_check("glass shards are edged", sh.c(&"item").sharpness == "edged")
	sh.destroy()

func _mapgen() -> void:
	var map := Game.map
	var rw := 0
	var wrong := 0
	for i in map.structure.size():
		var s: int = map.structure[i]
		if not Defs.is_window(s):
			continue
		var c := map.cell_of(i)
		var outside := false
		for d in Defs.DIRS4:
			if map.is_outdoor(c + d):
				outside = true
		if s == Defs.S_RWINDOW:
			rw += 1
		if outside and s != Defs.S_RWINDOW:
			wrong += 1
	_check("hull windows are reinforced (%d reinforced, %d plain on the hull)" % [rw, wrong], rw > 0 and wrong == 0)

# ------------------------------------------------------------------ in the world
func _break_window(a: Entity, cell: Vector2i) -> void:
	var map := Game.map
	map.set_structure(cell, Defs.S_WINDOW)
	var tb := Proto.spawn("toolbox", a.cell)
	a.c(&"inv").put_in_hands(tb, a.c(&"inv").active)
	var hits := 0
	var saw := {}
	while Defs.is_window(map.structure[map.idx(cell)]) and hits < 40:
		a.c(&"mob").next_attack = 0.0
		Interact.hit_tile(a, tb, cell)
		hits += 1
		if Defs.is_window(map.structure[map.idx(cell)]):
			saw[Structures.crack_at(cell)] = true
	# 100 / 8.125 -> 13 hits
	_check("a toolbox breaks a window in 13 hits (took %d)" % hits, hits == 13)
	_check("the pane cracked through 75, 50 and 25 on the way", saw.has(75) and saw.has(50) and saw.has(25))
	_check("the grille stays when the pane breaks", map.structure[map.idx(cell)] == Defs.S_GRILLE)
	var shards := Game.at(cell).filter(func(e): return e.proto == "glass_shard").size()
	_check("a fulltile pane leaves 2 shards (got %d)" % shards, shards == 2)
	_check("glass debris on the floor", Game.at(cell).any(func(e): return e.proto == "decal_glass"))
	_clear_items(cell)
	# one-handed fire axe is 5 x 0.8 -> 2 per hit, wielded 24 x 1.25 -> 15
	map.set_structure(cell, Defs.S_WINDOW)
	a.c(&"inv").drop(tb)
	var axe := Proto.spawn("fireaxe", a.cell)
	a.c(&"inv").put_in_hands(axe, a.c(&"inv").active)
	a.c(&"mob").next_attack = 0.0
	Interact.hit_tile(a, axe, cell)
	_near("one-handed fire axe does 2 to a window", 100.0 - map.struct_hp[map.idx(cell)], 2.0)
	axe.attack_self(a)
	a.c(&"mob").next_attack = 0.0
	Interact.hit_tile(a, axe, cell)
	_near("wielded fire axe does 15 to a window", 98.0 - map.struct_hp[map.idx(cell)], 15.0)
	axe.attack_self(a)
	a.c(&"inv").drop(axe)
	axe.destroy()
	tb.destroy()
	# welder repair: 4 s with a lit welder brings it back to full
	var wd := Proto.spawn("welder", a.cell)
	a.c(&"inv").put_in_hands(wd, a.c(&"inv").active)
	wd.c(&"welder").attack_self(a)
	a.c(&"mob").combat = false
	Interact.use_on_tile(a, wd, cell)
	await _idle(a)
	_check("a welder repairs the window to full", map.struct_hp[map.idx(cell)] == 100.0)
	a.c(&"mob").combat = true
	if wd.c(&"welder").lit:
		wd.c(&"welder").attack_self(a)
	a.c(&"inv").drop(wd)
	wd.destroy()

func _reinforced(a: Entity, cell: Vector2i) -> void:
	var map := Game.map
	map.set_structure(cell, Defs.S_RWINDOW)
	var cr := Proto.spawn("screwdriver", a.cell)
	a.c(&"inv").put_in_hands(cr, a.c(&"inv").active)
	a.c(&"mob").next_attack = 0.0
	Interact.hit_tile(a, cr, cell)
	_check("a screwdriver (5 x 0.5) can't mark reinforced glass", map.struct_hp[map.idx(cell)] == 150.0)
	a.c(&"inv").drop(cr)
	cr.destroy()
	Structures.take_damage(cell, 999.0, "brute", "", null)
	var rods := Game.at(cell).filter(func(e): return e.proto == "rods")
	_check("a reinforced pane drops its 2 rods", rods.size() == 1 and rods[0].c(&"stack").amount == 2)
	_clear_items(cell)

func _grille(a: Entity, cell: Vector2i) -> void:
	var map := Game.map
	map.set_structure(cell, Defs.S_GRILLE)
	# kicks: rand(5,10) melee -> 2.5-5
	var lo := 99.0
	var hi := 0.0
	for k in 20:
		map.struct_hp[map.idx(cell)] = 50.0
		a.c(&"mob").next_attack = 0.0
		Interact.hand_on_tile(a, cell)
		var d: float = 50.0 - map.struct_hp[map.idx(cell)]
		lo = minf(lo, d)
		hi = maxf(hi, d)
	_check("kicking a grille does 2.5-5 (got %.1f-%.1f)" % [lo, hi], lo >= 2.5 and hi <= 5.0 and hi > lo)
	map.struct_hp[map.idx(cell)] = 21.0
	Structures.take_damage(cell, 2.0, "brute", "", null)
	_check("a grille at 40% bends: broken, passable", map.structure[map.idx(cell)] == Defs.S_GRILLE_BROKEN and map.is_passable(cell))
	_check("bent grille holds 20", map.struct_hp[map.idx(cell)] == 20.0)
	_check("bending drops one rod", Game.at(cell).filter(func(e): return e.proto == "rods").size() == 1)
	_clear_items(cell)
	Structures.take_damage(cell, 99.0, "brute", "", null)
	_check("a broken grille falls apart into its last rod", map.structure[map.idx(cell)] == Defs.S_NONE and Game.at(cell).filter(func(e): return e.proto == "rods" and e.c(&"stack").amount == 1).size() == 1)
	_clear_items(cell)

func _rebuild(a: Entity, cell: Vector2i) -> void:
	var map := Game.map
	map.set_structure(cell, Defs.S_GRILLE_BROKEN)
	a.c(&"mob").combat = false
	var rods := Proto.spawn("rods", a.cell, {"comps": {"stack": {"amount": 5}}})
	a.c(&"inv").put_in_hands(rods, a.c(&"inv").active)
	var glass := Proto.spawn("sheet_glass", a.cell, {"comps": {"stack": {"amount": 1}}})
	Interact.use_on_tile(a, glass, cell)
	await _idle(a)
	_check("glass won't go on a broken grille", map.structure[map.idx(cell)] == Defs.S_GRILLE_BROKEN)
	Interact.use_on_tile(a, rods, cell)
	await _idle(a)
	_check("a rod straightens the broken grille", map.structure[map.idx(cell)] == Defs.S_GRILLE and rods.c(&"stack").amount == 4)
	Interact.use_on_tile(a, glass, cell)
	await _idle(a)
	_check("one sheet isn't enough for a fulltile window", map.structure[map.idx(cell)] == Defs.S_GRILLE)
	# rods on glass make reinforced glass
	glass.c(&"stack").amount = 3
	a.c(&"inv").drop(rods)
	a.c(&"inv").put_in_hands(glass, a.c(&"inv").active)
	rods.c(&"stack").attackby(a, glass) # glass used on rods
	var rg: Entity = null
	for h in a.c(&"inv").hands:
		if h and h.proto == "sheet_rglass":
			rg = h
	_check("rods and glass make reinforced glass", rg != null and glass.c(&"stack").amount == 2 and rods.c(&"stack").amount == 3)
	glass.c(&"stack").attackby(a, rods)
	_check("more rods add to the reinforced glass in hand", rg != null and rg.c(&"stack").amount == 2)
	Interact.use_on_tile(a, rg, cell)
	await _idle(a)
	_check("two sheets of reinforced glass make a reinforced window", map.structure[map.idx(cell)] == Defs.S_RWINDOW and map.struct_hp[map.idx(cell)] == 150.0)
	for e in [rods, glass]:
		if is_instance_valid(e) and not e.removed:
			e.destroy()
	a.c(&"mob").combat = true

func _throw(a: Entity, cell: Vector2i) -> void:
	var map := Game.map
	map.set_structure(cell, Defs.S_WINDOW)
	var back := a.cell - (cell - a.cell)
	if map.is_passable(back) and Game.at(back).is_empty():
		a.place(back)
	var tb := Proto.spawn("toolbox", a.cell)
	a.c(&"inv").put_in_hands(tb, a.c(&"inv").active)
	Interact.throw_item(a, tb, cell)
	# tg obj/hitby: throwforce 13 x demolition 1.25 = 16.25 through melee 50 -> 8.1
	_near("a thrown toolbox does 8.1 to a window", 100.0 - map.struct_hp[map.idx(cell)], 8.1, 0.06)
	await _wait(0.5)
	if is_instance_valid(tb) and not tb.removed:
		tb.destroy()

func _explosion(cell: Vector2i) -> void:
	var map := Game.map
	map.set_structure(cell, Defs.S_RWINDOW)
	Structures.ex_act(cell, 1, null)
	var lost: float = 150.0 - map.struct_hp[map.idx(cell)]
	# light: 10-90 bomb through bomb 25 -> 7.5-67.5
	_check("a light blast on reinforced glass does 7.5-67.5 (%.1f)" % lost, lost >= 7.4 and lost <= 67.6)
	Structures.ex_act(cell, 3, null)
	_check("devastation takes the pane and the grille", map.structure[map.idx(cell)] == Defs.S_NONE)
	_clear_items(cell)

# ------------------------------------------------------------------ doors, lockers, tables
func _objects(a: Entity) -> void:
	var open := _free_floor_near(a.cell)
	var inv: CInventory = a.c(&"inv")
	for item in inv.hands.duplicate():
		if item: inv.drop(item)
	a.c(&"mob").combat = true
	# airlock: 300 hp, melee 30, deflection 21 (tg AIRLOCK_DAMAGE_DEFLECTION_N)
	var door := Proto.spawn("airlock", open)
	var ig: CIntegrity = door.c(&"integrity")
	_check("an airlock is 300 hp with 21 deflection", ig != null and ig.max_hp == 300.0 and ig.deflect == 21.0)
	var tb := Proto.spawn("toolbox", a.cell)
	inv.put_in_hands(tb, inv.active)
	a.c(&"mob").next_attack = 0.0
	_check("a toolbox (16.25) can't dent an airlock", Combat.strike_object(a, door, tb) == 0.0 and ig.hp == 300.0)
	inv.drop(tb)
	var axe := Proto.spawn("fireaxe", a.cell)
	inv.put_in_hands(axe, inv.active)
	axe.attack_self(a)
	# wielded: 24 x 1.25 = 30 through melee 30 -> 21
	_near("a wielded fire axe does 21 to an airlock", Combat.strike_object(a, door, axe), 21.0)
	ig.hp = 80.0
	Combat.strike_object(a, door, axe)
	_check("an airlock under 25% breaks: dead lights, unpowered", ig.broken and door.c(&"door").broken and not door.c(&"door").powered())
	door.destroy()
	# locker: 200 hp, melee 20, bursts open at 25%
	var lk := Proto.spawn("locker", open)
	var st: CStorage = lk.c(&"storage")
	st.locked = true
	var li: CIntegrity = lk.c(&"integrity")
	_near("a fire axe does 24 to a locker (30 through melee 20)", Combat.strike_object(a, lk, axe), 24.0)
	li.hp = 60.0
	Combat.strike_object(a, lk, axe)
	_check("a locker under 25% bursts open and unlocks", st.is_open and not st.locked and lk.c(&"integrity").broken)
	lk.destroy()
	# table: collapses at 33%
	var tbl := Proto.spawn("table", open)
	tbl.c(&"integrity").hp = 40.0
	Combat.strike_object(a, tbl, axe)
	_check("a table under 33% collapses", tbl.removed and Game.at(open).any(func(x): return x.proto == "sheet_metal"))
	_clear_items(open)
	axe.attack_self(a)
	inv.drop(axe)
	axe.destroy()
	tb.destroy()
	# explosions: heavy is 100-250 bomb, not an instant delete
	var d2 := Proto.spawn("airlock", open)
	for e in Game.at(open):
		if e != d2 and not e.has_c(&"mob"):
			e.destroy()
	d2.take_damage(120.0, "brute", null, "bomb")
	_near("a 120 bomb hit on an airlock is 108 through bomb 10", 300.0 - d2.c(&"integrity").hp, 108.0)
	d2.destroy()

# ------------------------------------------------------------------ glass shards
func _shards(a: Entity) -> void:
	var inv: CInventory = a.c(&"inv")
	var h: CHealth = a.c(&"health")
	var step := _free_floor_near(a.cell)
	_heal(a)
	var sh := Proto.spawn("glass_shard", step)
	_check("shards come in tg's three sizes", sh.spr_name in ["glass_shard", "glass_shard_medium", "glass_shard_small"])
	# shoes on: just a crunch
	var shoes: Entity = inv.worn("shoes")
	a.c(&"mob")._step_on(step)
	_check("with shoes on, stepping on glass doesn't hurt", shoes == null or (h.brute == 0.0 and h.stun_t <= 0.0))
	if shoes:
		inv.unequip("shoes")
		inv.drop(shoes)
	a.c(&"mob")._step_on(step)
	_check("barefoot on glass: 5 to a leg and paralysed (brute %.0f)" % h.brute, h.brute == 5.0 and h.status_left("paralyzed") > 1.5 and (h.limb.get("l_leg", 0.0) + h.limb.get("r_leg", 0.0)) == 5.0)
	_heal(a)
	if shoes and not shoes.removed:
		inv.equip(shoes, "shoes")
	# bare hands: the shard cuts your palm when you use it (force 5 x 0.5)
	sh.destroy()
	var sh2 := Proto.spawn("glass_shard", a.cell)
	inv.put_in_hands(sh2, inv.active)
	var gl: Entity = inv.worn("gloves")
	if gl:
		inv.unequip("gloves")
		inv.drop(gl)
	Combat.after_attack(a, sh2)
	_check("a bare-handed shard cuts your hand for 2.5", absf(h.brute - 2.5) < 0.01)
	_heal(a)
	# a lit welder melts it back into glass
	var wd := Proto.spawn("welder", a.cell)
	inv.put_in_hands(wd, 1 - inv.active)
	wd.c(&"welder").attack_self(a)
	sh2.attackby(a, wd)
	_check("a welder melts a shard into a glass sheet", sh2.removed and inv.hands.any(func(x): return x != null and x.proto == "sheet_glass"))
	if wd.c(&"welder").lit:
		wd.c(&"welder").attack_self(a)

func _free_floor_near(c: Vector2i) -> Vector2i:
	for r in range(1, 6):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var q := c + Vector2i(x, y)
				if Game.map.is_passable(q) and not Game.map.is_outdoor(q) and Game.at(q).is_empty() and Game.map.structure[Game.map.idx(q)] == Defs.S_NONE:
					return q
	return c

func _heal(e: Entity) -> void:
	var h: CHealth = e.c(&"health")
	h.brute = 0.0
	h.burn = 0.0
	h.limb.clear()
	h.stun_t = 0.0
	h.status.erase("paralyzed")
	h.knockdown_t = 0.0
	h.bleeding = 0.0
	e.c(&"mob")._update_pose()

# ------------------------------------------------------------------ helpers
## A window with open floor on the inside to stand on (the station has plenty).
func _window_spot() -> Dictionary:
	var map := Game.map
	for i in map.structure.size():
		if not Defs.is_window(map.structure[i]):
			continue
		var c := map.cell_of(i)
		for d in Defs.DIRS4:
			var st: Vector2i = c + d
			var back: Vector2i = st + d
			if map.is_passable(st) and not map.is_outdoor(st) and Game.at(st).is_empty() and map.is_passable(back) and Game.at(back).is_empty():
				return {"cell": c, "stand": st}
	return {}

func _clear_items(cell: Vector2i) -> void:
	for e in Game.at(cell).duplicate():
		if e.has_c(&"item") or e.has_c(&"decal"):
			e.destroy()

## Wait (in game time) for the user's do_after to finish.
func _idle(user: Entity) -> void:
	var until := Game.time + 20.0
	await get_tree().process_frame
	while DoAfter.busy(user) and Game.time < until:
		await get_tree().process_frame

func _wait(sec: float) -> void:
	var until := Game.time + sec
	while Game.time < until:
		await get_tree().process_frame

func _near(what: String, got: float, want: float, tol := 0.01) -> void:
	_check("%s (got %.2f)" % [what, got], absf(got - want) <= tol)

func _check(what: String, ok: bool) -> void:
	print("STRUCT %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1
