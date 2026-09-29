class_name CombatTest extends Node
## --combattest: fights two test dummies in the cafeteria and checks the tg numbers and
## the Burgerstation layer. Prints COMBAT PASS/FAIL lines and quits.

var fails := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	var cell := _open_cell()
	var a := Crew.spawn_human("assistant", cell, {"name": "Attacker A"})
	var b := Crew.spawn_human("assistant", cell + Vector2i(1, 0), {"name": "Target B"})
	for e in [a, b]:
		e.remove_comp(&"brain")
		Quirks.remove_all(e) # random crew quirks would skew the checks
		for s in Skills.SKILLS:
			e.c(&"mob").xp[s] = 0.0
		for at in Skills.ATTRIBUTES:
			e.c(&"mob").attr_xp[at] = 0.0
		var inv: CInventory = e.c(&"inv")
		for h in inv.hands.duplicate():
			if h:
				inv.drop(h)
	var ha: CHealth = a.c(&"health")
	var hb: CHealth = b.c(&"health")
	var ma: CMob = a.c(&"mob")
	var mb: CMob = b.c(&"mob")
	ma.combat = true

	# punches: 5-10
	var lo := 99.0
	var hi := 0.0
	for i in 40:
		_heal(b)
		ha.stamina = 100.0
		ma.next_attack = 0.0
		var before := hb.brute
		Combat.melee(a, b, null)
		var d := hb.brute - before
		if d > 0.0:
			lo = minf(lo, d)
			hi = maxf(hi, d)
	_check("punches roll 5-10 (got %.0f-%.0f)" % [lo, hi], lo >= 5.0 and hi <= 10.0 and hi > lo)

	# attack cooldown (CLICK_CD_MELEE 0.8 s)
	_heal(b)
	ma.next_attack = 0.0
	Combat.melee(a, b, null)
	var after_one := hb.brute
	Combat.melee(a, b, null)
	_check("second swing inside 0.8 s does nothing", hb.brute == after_one)

	# toolbox: force 13 at level 1 skills, no armour on the chest
	var tb := Proto.spawn("toolbox", a.cell)
	a.c(&"inv").put_in_hands(tb, a.c(&"inv").active)
	var got := _avg_hit(a, b, tb, 30)
	_check("toolbox hits ~13 (got %.1f)" % got, got > 11.0 and got < 15.5)

	# TG's security vest has 35 melee armor on the chest.
	var vest := Crew._clothes("suit", b.cell, "armor vest", "suit_armor", [], Crew.SUIT_STATS["armor"])
	b.c(&"inv").put_in_hands(vest)
	b.c(&"inv").equip(vest, "suit")
	_check("armour vest is 35 on the chest", absf(Combat.armor(b, "chest") - 35.0) < 0.5)
	_check("armour penetration 20 vs 30 armour leaves 12.5", absf(Combat.penetrate(30.0, 20.0) - 12.5) < 0.01)

	# fire axe: 5 in one hand, 24 wielded
	a.c(&"inv").drop(tb)
	var axe := Proto.spawn("fireaxe", a.cell)
	a.c(&"inv").put_in_hands(axe, a.c(&"inv").active)
	_check("fire axe one-handed is 5", Combat.item_force(a, axe) == 5.0)
	axe.attack_self(a)
	_check("fire axe wielded is 24", Combat.item_force(a, axe) == 24.0)

	# tg check_block: a held riot shield (block 50) blocks at 50 - damage/3
	_heal(b)
	b.c(&"inv").drop(vest)
	var shield := Proto.spawn("riot_shield", b.cell)
	b.c(&"inv").put_in_hands(shield)
	var blocks := 0
	for i in 40:
		if Combat.check_block(b, "the test", 12.0, 0.0):
			blocks += 1
	_check("a riot shield blocks about 46%% of 12 damage blows (%d/40)" % blocks, blocks >= 9 and blocks <= 30)
	b.c(&"inv").drop(shield)
	shield.destroy()

	# shove into a wall: knockdown
	_heal(b)
	var wall_side := _wall_next_to(b.cell)
	if wall_side != Vector2i.ZERO:
		a.place(b.cell - wall_side)
		ma.next_attack = 0.0
		ha.stagger_t = 0.0
		Combat.shove(a, b)
		_check("shoving someone into a wall knocks them down", hb.knockdown_t > 0.0)
	# shove in the open: staggered
	_heal(b)
	hb.knockdown_t = 0.0
	b.place(cell + Vector2i(1, 0))
	a.place(cell)
	await _wait(0.3)
	ma.next_attack = 0.0
	Combat.shove(a, b)
	_check("a shove in the open staggers", hb.stagger_t > 0.0)

	# stun baton: 60 stamina and a knockdown (tg security baton)
	await _wait(0.5)
	_heal(b)
	hb.knockdown_t = 0.0
	a.c(&"inv").drop(axe)
	var baton := Proto.spawn("baton", a.cell)
	a.c(&"inv").put_in_hands(baton, a.c(&"inv").active)
	b.place(a.cell + Vector2i(1, 0))
	var st0 := hb.stamina
	Interact.use_item_on(a, baton, b)
	_check("baton drains 60 stamina (%.0f)" % (st0 - hb.stamina), st0 - hb.stamina >= 59.0)
	_check("baton knocks down", hb.knockdown_t > 0.0)

	# tg stamina: stamcrit at 100 loss, full reset 10 s after the last stamina damage
	_heal(b)
	a.c(&"inv").drop(baton)
	hb.adjust("stamina", 110.0, a)
	hb._update_stamcrit()
	_check("100 stamina loss is stamcrit", hb.stamcrit and hb.floored())
	hb.process(0.1)
	_check("no regen inside 10 s", hb.stamina < 0.0)
	hb.last_stamina_dmg = Game.time - 10.5
	hb.process(0.1)
	_check("it all comes back 10 s after the last stamina damage", hb.stamina == 100.0 and not hb.stamcrit)

	# XP from fighting
	_check("fighting earned melee XP", ma.xp.get("melee", 0.0) > 0.0 and ma.xp.get("unarmed", 0.0) > 0.0)
	_check("hits land on body zones", not hb.limb.is_empty() or hb.brute == 0.0)

	# precise aim (Burgerstation doll + tg eyes/mouth)
	_check("the doll maps points to parts", Combat.zone_at(Vector2(13, 5)) == "eyes" and Combat.zone_at(Vector2(15, 9)) == "mouth" and Combat.zone_at(Vector2(6, 27)) == "r_hand" and Combat.zone_at(Vector2(12, 44)) == "r_foot")
	ma.set_aim(Vector2(13, 5))
	_check("aiming at a point aims at that part", ma.aimed_zone() == "eyes")
	ma.set_aim_preset(1)
	ma.aim_at_zone("l_leg")
	ma.set_aim_preset(0)
	_check("aim presets remember their own aim", ma.aimed_zone() == "eyes")
	_heal(b) # standing (lying down they're 90% easy to aim at)
	var eyes_hits := 0
	var head_hits := 0
	for i in 200:
		var z := Combat.pick_zone(a, b)
		if z == "eyes":
			eyes_hits += 1
		elif z == "head":
			head_hits += 1
	_check("tg ran_zone: the aimed part 80%% of the time (%d/200)" % eyes_hits, eyes_hits > 140 and eyes_hits < 180)
	_heal(b)
	hb.eye_damage = 0.0
	b.place(a.cell + Vector2i(1, 0))
	# tg attack_effects: a blunt blow to the head has prob(damage) to knock them senseless
	var club := Proto.spawn("toolbox", a.cell) # attack_effects is the item attack chain
	for i in 40:
		_heal(b)
		Combat._apply_hit(a, b, 20.0, "brute", "head", "", 0.0, 20.0, 0.0, 0.0, club)
		if hb.has_status("confusion"):
			break
	_check("blunt blows to the head knock them senseless (confusion %.0fs, blur %.0fs)" % [hb.status.get("confusion", 0.0), hb.status.get("eye_blur", 0.0)], hb.has_status("confusion") and hb.has_status("eye_blur"))
	club.destroy()

	# intents: disarm shoves, grab grabs and tightens
	_heal(b)
	hb.knockdown_t = 0.0
	b.place(a.cell + Vector2i(1, 0))
	ma.intent = "grab"
	ma.next_attack = 0.0
	Interact.hand_on(a, b)
	_check("grab intent grabs passively", ma.pulling == b and ma.grab_state == 0)
	ma.next_attack = 0.0
	Interact.hand_on(a, b)
	_check("grabbing again is aggressive", ma.grab_state == 1)
	_check("an aggressive grab is harder to break", mb.resist_chance() < 0.3)
	ma.stop_pulling()
	ma.intent = "harm"

	# tg kicks: someone lying down gets kicked for 7-15 and never dodges it
	b.place(a.cell + Vector2i(1, 0))
	var klo := 99.0
	var khi := 0.0
	var kmiss := 0
	for i in 30:
		_heal(b)
		hb.knockdown(5.0)
		ma.next_attack = 0.0
		var kb := hb.brute
		Combat.melee(a, b, null)
		var kd := hb.brute - kb
		if kd <= 0.0:
			kmiss += 1
		else:
			klo = minf(klo, kd)
			khi = maxf(khi, kd)
	_check("kicks at the downed roll 7-15 and never miss (%.0f-%.0f, %d missed)" % [klo, khi, kmiss], kmiss == 0 and klo >= 7.0 and khi <= 15.0)

	# crafting (Burgerstation grid): a shiv from a shard and cable, a molotov that burns
	await _wait(0.6)
	_heal(a) # tg: wounded arms slow do-afters down (wound actionspeed modifier)
	var ainv: CInventory = a.c(&"inv")
	for h in ainv.hands.duplicate():
		if h:
			ainv.drop(h)
	var shard := Proto.spawn("glass_shard", a.cell)
	var coil := Proto.spawn("cable_coil", a.cell)
	var grid := [shard, coil, null, null, null, null, null, null, null]
	_check("the grid knows the shiv", Crafting.match_grid(grid) == "shiv")
	_check("gather finds parts on the floor", Crafting.gather(a, "shiv").size() == 2)
	var made := [null]
	Crafting.craft(a, grid, func(m): made[0] = m)
	await _wait(3.0)
	_check("crafting makes a shiv", made[0] != null and made[0].proto == "shiv" and made[0] in ainv.hands)
	_check("a stack only gives what the recipe needs", is_instance_valid(coil) and not coil.removed and coil.c(&"stack").amount == 28)
	for h in ainv.hands.duplicate():
		if h:
			ainv.drop(h)
	var molo := Proto.spawn("molotov", a.cell)
	var wd := Proto.spawn("welder", a.cell)
	ainv.put_in_hands(molo, 0)
	ainv.put_in_hands(wd, 1)
	wd.attack_self(a)
	ainv.active = 0
	molo.attack_self(a)
	_check("a lit welder lights the molotov", molo.c(&"molotov").lit)
	var tgt := a.cell + Vector2i(3, 0)
	for k in range(1, 4):
		if not Game.map.is_passable(a.cell + Vector2i(k, 0)):
			tgt = a.cell + Vector2i(k - 1, 0)
			break
	b.place(a.cell + Vector2i(0, 1) if Game.map.is_passable(a.cell + Vector2i(0, 1)) else a.cell)
	Interact.throw_item(a, molo, tgt)
	# the throw itself glides in real time, so give it up to a couple of seconds either way
	var burning := false
	for tries in 20:
		await _wait(0.15)
		for c in [tgt] + Defs.DIRS8.map(func(d): return tgt + d):
			if Game.atmos.hotspots.has(c):
				burning = true
		if burning and (not is_instance_valid(molo) or molo.removed):
			break
	_check("a thrown molotov starts a fire", burning and (not is_instance_valid(molo) or molo.removed))
	await _gadgets(a, b)
	print("COMBAT DONE: %d failed" % fails)
	get_tree().quit()

func _avg_hit(a: Entity, b: Entity, item: Entity, n: int) -> float:
	var hb: CHealth = b.c(&"health")
	var total := 0.0
	var hits := 0
	for i in n:
		_heal(b)
		a.c(&"health").stamina = 100.0
		a.c(&"mob").next_attack = 0.0
		var before := hb.brute
		Combat.melee(a, b, item)
		var d := hb.brute - before
		if d > 0.0:
			total += d
			hits += 1
	return total / maxf(1.0, hits)

## Wait in game time, so the test holds at any --speed.
func _wait(sec: float) -> void:
	var until := Game.time + sec
	while Game.time < until:
		await get_tree().process_frame

func _heal(e: Entity) -> void:
	var h: CHealth = e.c(&"health")
	h.brute = 0.0
	h.burn = 0.0
	h.stamina = 100.0
	h.limb.clear()
	h.limb_burn.clear()
	h.limb_maxed.clear()
	h.wounds.clear()
	h.gauze.clear()
	h.status.clear()
	h.stamcrit = false
	h.eye_damage = 0.0
	h.bleeding = 0.0
	h.stagger_t = 0.0
	h.knockdown_t = 0.0
	h.resting = false
	h.get_up(true) # back on their feet now, not after tg's 1 s get_up
	h.stun_t = 0.0
	h.cuffed = false
	SecurityRecords.clear(e.id)
	e.c(&"mob")._update_pose()

func _open_cell() -> Vector2i:
	var a: Area = Game.world.get_parent().mapgen.room_of("cafeteria")["area"]
	for c in a.cells:
		var ok := true
		for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0), Vector2i(-1, 0)]:
			if not Game.map.is_passable(c + d) or not Game.at(c + d).is_empty():
				ok = false
		if ok:
			return c
	return a.cells[0]

func _wall_next_to(c: Vector2i) -> Vector2i:
	var a: Area = Game.map.area_at(c)
	for cc in a.cells:
		for d in Defs.DIRS4:
			if Game.map.is_wall(cc + d) and Game.map.is_passable(cc - d) and Game.at(cc).is_empty() and Game.at(cc - d).is_empty():
				return _move_pair(cc, d)
	return Vector2i.ZERO

func _move_pair(cc: Vector2i, d: Vector2i) -> Vector2i:
	for e in Game.all_with(&"mob"):
		if e.display_name == "Target B":
			e.place(cc)
	return d

func _check(what: String, ok: bool) -> void:
	print("COMBAT %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1

## tg gadgets: flash, pepper spray, energy guns, recharger, defib, grenades, smokes, cleaner.
func _gadgets(a: Entity, b: Entity) -> void:
	var ainv: CInventory = a.c(&"inv")
	var ma: CMob = a.c(&"mob")
	var hb: CHealth = b.c(&"health")
	var _clear := func():
		for h in ainv.hands.duplicate():
			if h:
				ainv.drop(h)
	_clear.call()
	await _wait(0.3)
	# flash
	_heal(b)
	hb.eye_damage = 0.0
	b.place(a.cell + Vector2i(1, 0))
	var fl := Proto.spawn("flash", a.cell)
	ainv.put_in_hands(fl, ainv.active)
	ma.intent = "harm"
	b.c(&"mob").dir = Defs.DIR_W # facing the flasher (tg deviation none)
	Interact.use_item_on(a, fl, b)
	_check("a flash floors them, confuses and drains stamina (tg flash_mob)", hb.has_status("knockdown") and hb.has_status("confusion") and hb.stamina <= 20.0)
	_heal(b)
	hb.eye_damage = 0.0
	var sg := Proto.spawn("sunglasses", b.cell)
	var binv: CInventory = b.c(&"inv")
	if binv.worn("eyes"): binv.drop(binv.worn("eyes"))
	_check("sunglasses equip over an empty eye slot", binv.equip(sg, "eyes") and StatusFx.eye_protection(hb) >= 1)
	fl.c(&"gadget").cooldown = 0.0
	Interact.use_item_on(a, fl, b)
	_check("sunglasses protect against the flash", not hb.has_status("knockdown") and not hb.has_status("confusion"))
	b.c(&"inv").unequip("eyes")
	_clear.call()
	# pepper spray at range
	_heal(b)
	hb.eye_damage = 0.0
	var ps := Proto.spawn("pepperspray", a.cell)
	ainv.put_in_hands(ps, ainv.active)
	b.place(a.cell + Vector2i(2, 0))
	Interact.click(a, b, b.cell, {})
	_check("pepper spray reaches two tiles and blinds", StatusFx.blind(hb) and hb.has_status("knockdown") and ps.c(&"gadget").charges == 9)
	_clear.call()
	# disabler: stamina; laser: burn
	_heal(b)
	var dis := Proto.spawn("disabler", a.cell)
	ainv.put_in_hands(dis, ainv.active)
	b.place(a.cell + Vector2i(3, 0))
	for i in 4:
		dis.c(&"gadget").cooldown = 0.0
		Interact.click(a, b, b.cell, {})
	_check("disabler bolts wear someone down (%.0f stamina)" % hb.stamina, hb.stamina <= 0.0 and hb.brute + hb.burn < 1.0 and dis.c(&"gadget").charges == 16)
	_clear.call()
	_heal(b)
	var las := Proto.spawn("laser_gun", a.cell)
	ainv.put_in_hands(las, ainv.active)
	las.c(&"gadget").cooldown = 0.0
	Interact.click(a, b, b.cell, {})
	_check("a laser burns (%.0f)" % hb.burn, hb.burn >= 10.0)
	las.c(&"gadget").charges = 0
	las.c(&"gadget").cooldown = 0.0
	var burn0 := hb.burn
	Interact.click(a, b, b.cell, {})
	_check("an empty gun just clicks", hb.burn == burn0)
	# recharger
	var rc := Proto.spawn("recharger", a.cell + Vector2i(0, 1))
	rc.attackby(a, las)
	_check("the gun sits in the recharger", rc.c(&"recharger").held == las and las not in ainv.hands)
	await _wait(4.5) # machines tick once a second, one charge per 1.5 s
	rc.attack_hand(a)
	_check("the recharger charged it (%d)" % las.c(&"gadget").charges, las.c(&"gadget").charges >= 2 and las in ainv.hands)
	_clear.call()
	rc.destroy()
	# defibrillator: the recently dead come back
	_heal(b)
	hb.brute = 110.0
	hb.adjust("oxy", 100.0, null)
	_check("the target is dead", hb.dead)
	b.place(a.cell + Vector2i(1, 0))
	var df := Proto.spawn("defib", a.cell)
	ainv.put_in_hands(df, ainv.active)
	ma.intent = "help"
	Interact.use_item_on(a, df, b)
	await _wait(7.0)
	_check("the defib restarts a heart", not hb.dead)
	_clear.call()
	_heal(b)
	# flashbang
	var fb := Proto.spawn("flashbang", a.cell)
	ainv.put_in_hands(fb, ainv.active)
	fb.attack_self(a)
	_check("pulling the pin primes it", fb.c(&"gadget").fuse > 0.0)
	Interact.throw_item(a, fb, b.cell)
	b.place(a.cell + Vector2i(2, 0))
	hb.stamina = 100.0
	await _wait(5.6)
	_check("the flashbang goes off and floors people nearby (removed %s, knockdown %.0f)" % [not is_instance_valid(fb) or fb.removed, hb.knockdown_t], (not is_instance_valid(fb) or fb.removed) and hb.has_status("knockdown"))
	# smoke grenade
	var sm := Proto.spawn("smoke_grenade", a.cell + Vector2i(1, 0))
	sm.c(&"gadget").fuse = 0.05
	var k := Game.map.idx(sm.cell)
	# fuses burn down on the once-a-second item tick
	for tries in 12:
		await _wait(0.15)
		if Game.atmos.gas[Defs.G_SMOKE][k] > 5.0:
			break
	_check("the smoke grenade fills the air with smoke", Game.atmos.gas[Defs.G_SMOKE][k] > 5.0)
	# station security answers the "assaults" in here and may have cuffed the attacker by
	# now (it depends on how fast they got to the cafeteria): reset both before going on
	_heal(a)
	_heal(b)
	# lighter and cigarette
	_clear.call()
	var lt := Proto.spawn("lighter", a.cell)
	var cig := Proto.spawn("cigarette", a.cell)
	ainv.put_in_hands(cig, 0)
	ainv.equip(cig, "mask")
	ainv.hands[0] = null if ainv.hands[0] == cig else ainv.hands[0]
	ainv.put_in_hands(lt, ainv.active)
	lt.attack_self(a)
	Interact.use_item_on(a, lt, a)
	_check("a lit lighter lights the cigarette you're wearing", lt.c(&"gadget").lit and cig.c(&"gadget").lit)
	# space cleaner
	_clear.call()
	var mess := Proto.spawn("decal_blood", a.cell + Vector2i(1, 0))
	var sp := Proto.spawn("spray_bottle", a.cell)
	ainv.put_in_hands(sp, ainv.active)
	Interact.click(a, null, a.cell + Vector2i(1, 0), {})
	_check("space cleaner cleans blood off the floor", not is_instance_valid(mess) or mess.removed)
	# riot shield blocks shots
	_clear.call()
	_heal(b)
	var shield := Proto.spawn("riot_shield", b.cell)
	b.c(&"inv").put_in_hands(shield, 0)
	b.place(a.cell + Vector2i(3, 0))
	var gun := Proto.spawn("laser_gun", a.cell)
	ainv.put_in_hands(gun, ainv.active)
	gun.c(&"gadget").fire(a, b.cell)
	_check("transparent riot shields let laser beams through", hb.burn > 0.0)
	shield.tags["shield_transparent"] = false # opaque shield fixture for check_block
	var blocked := 0
	for i in 20:
		gun.c(&"gadget").cooldown = 0.0
		gun.c(&"gadget").charges = 10
		var bb := hb.burn
		Interact.click(a, b, b.cell, {})
		if hb.burn == bb:
			blocked += 1
	_check("an opaque shield blocks some laser shots (%d/20)" % blocked, blocked >= 4 and blocked <= 18)
	b.c(&"inv").drop(shield)
	_clear.call()
	# welding without a helmet hurts your eyes
	var ha: CHealth = a.c(&"health")
	ha.eye_damage = 0.0
	Interact.weld_flash(a)
	var bare := ha.eye_damage
	var helm := Proto.spawn("welding_helmet", a.cell)
	if ainv.worn("head"):
		ainv.unequip("head")
	ainv.equip(helm, "head")
	ha.eye_damage = 0.0
	Interact.weld_flash(a)
	_check("welding stings bare eyes, a welding helmet protects", bare > 0.0 and ha.eye_damage == 0.0)
	# tg airlock hacking
	var door: Entity = null
	for dd in Game.all_with(&"door"):
		var dc: CDoor = dd.c(&"door")
		if dc.state == CDoor.CLOSED and dc.powered() and not dc.external:
			door = dd
			break
	if door:
		var dc2: CDoor = door.c(&"door")
		var sd := Proto.spawn("screwdriver", a.cell)
		var wc := Proto.spawn("wirecutters", a.cell)
		var mt := Proto.spawn("multitool", a.cell)
		ainv.put_in_hands(sd, ainv.active)
		door.attackby(a, sd)
		_check("a screwdriver opens the airlock's panel", dc2.panel_open)
		ainv.drop(sd)
		var bolt_c := ""
		var power_c := ""
		for c in dc2.wires:
			if dc2.wires[c] == "bolts": bolt_c = c
			if dc2.wires[c] == "power": power_c = c
		ainv.put_in_hands(mt, ainv.active)
		dc2.wire_action(a, bolt_c, "pulse")
		_check("pulsing the bolt wire drops the bolts", dc2.bolted)
		_check("a bolted door won't open", not dc2.bump(Game.player if Game.player else a) or dc2.state == CDoor.CLOSED)
		dc2.wire_action(a, bolt_c, "pulse")
		ainv.drop(mt)
		ainv.put_in_hands(wc, ainv.active)
		dc2.wire_action(a, power_c, "cut")
		_check("cutting the power wire kills the door's power", not dc2.powered())
		dc2.wire_action(a, power_c, "mend")
		_check("mending it restores power", dc2.powered())
	# a baseball bat can knock people back
	_clear.call()
	_heal(b)
	b.place(a.cell + Vector2i(1, 0))
	var bat := Proto.spawn("baseball_bat", a.cell)
	ainv.put_in_hands(bat, ainv.active)
	var knocked := false
	for i in 12:
		_heal(b)
		b.place(a.cell + Vector2i(1, 0))
		a.c(&"health").stamina = 100.0
		ma.next_attack = 0.0
		Combat.melee(a, b, bat)
		await _wait(0.3)
		if b.cell.x - a.cell.x >= 2:
			knocked = true
			break
	_check("a baseball bat knocks people back", knocked)
