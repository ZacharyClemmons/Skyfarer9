class_name PolishTest extends Node
## --polishtest with --autotest: inventory and timed-action regressions.

var fails := 0

func _ready() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool) -> void:
	print("POLISH %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		fails += 1

func _run() -> void:
	await get_tree().process_frame
	Game.running = false
	DoAfter.active.clear()
	var p := Crew.spawn_human("assistant", Game.player.cell, {"name": "Polish tester"})
	p.remove_comp(&"brain")
	Quirks.remove_all(p)
	var inv: CInventory = p.c(&"inv")
	for it in inv.hands.duplicate():
		if it:
			inv.drop(it)
	inv.active = 1
	var bag := Proto.spawn("backpack", p.cell)
	var storage: CStorage = bag.c(&"storage")
	var tool := Proto.spawn("wrench", p.cell)
	inv.put_in_hands(tool, inv.active)
	var result := []
	var cb := func(ok: bool): result.append(ok)
	DoAfter.start(p, p, 1.0, cb)
	DoAfter.process(1.0)
	_check("unchanged action completes once", result == [true] and not DoAfter.busy(p))
	result.clear()
	DoAfter.start(p, p, 1.0, cb)
	storage.insert(tool)
	DoAfter.process(1.0)
	_check("storing the tool interrupts action", result == [false])
	inv.put_in_hands(tool, inv.active)
	result.clear()
	DoAfter.start(p, p, 1.0, cb)
	inv.active = 0
	DoAfter.process(1.0)
	_check("changing hands interrupts action", result == [false])
	result.clear()
	DoAfter.start(p, p, 1.0, cb)
	var second := Proto.spawn("screwdriver", p.cell)
	inv.put_in_hands(second, inv.active)
	DoAfter.process(1.0)
	_check("filling an initially empty active hand interrupts action", result == [false])
	inv.drop(second)
	var hat := Proto.spawn("beanie", p.cell)
	if inv.worn("head"):
		inv.worn("head").destroy()
	inv.put_in_hands(hat, 0)
	result.clear()
	DoAfter.start(p, p, 1.0, cb)
	inv.equip(hat, "head")
	DoAfter.process(1.0)
	_check("equipping a held item interrupts action", result == [false])
	var patient := Crew.spawn_human("assistant", p.cell, {"name": "Moving patient"})
	patient.remove_comp(&"brain")
	result.clear()
	DoAfter.start(p, patient, 1.0, cb)
	patient.place(p.cell + Vector2i(1, 0))
	DoAfter.process(1.0)
	_check("patient movement interrupts action even within reach", result == [false])
	patient.place(p.cell)
	var calls := []
	DoAfter.start(p, p, 1.0, func(ok):
		calls.append(["first", ok])
		DoAfter.cancel(patient))
	DoAfter.start(patient, patient, 1.0, func(ok): calls.append(["second", ok]))
	DoAfter.process(1.0)
	_check("callback cancellation cannot complete another action twice", calls == [["first", true], ["second", false]])
	storage.max_slots = 1
	_check("bag accepts its first item", storage.insert(second))
	_check("already stored item is rejected without duplication", not storage.insert(second) and storage.contents.size() == 1)
	# Simulate a removed entry left by an external component.
	second.removed = true
	_check("destroyed entries do not consume bag slots", storage.can_insert(tool) and storage.contents.is_empty())
	second.removed = false
	second.destroy()
	var box := Proto.spawn("backpack", p.cell, {"comps": {"storage": {"kind": "closet", "capacity": 100}}})
	var inner := Proto.spawn("backpack", p.cell, {"comps": {"storage": {"kind": "bag", "capacity": 100}}})
	_check("container cannot contain itself", not box.c(&"storage").insert(box))
	_check("outer container accepts inner container", box.c(&"storage").insert(inner))
	_check("container cannot contain an ancestor", not inner.c(&"storage").insert(box))
	var axe := Proto.spawn("fireaxe", p.cell)
	inv.drop(tool)
	inv.put_in_hands(axe, 0)
	axe.c(&"item").attack_self(p)
	_check("axe can be wielded", axe.c(&"item").is_wielded)
	var spare := Proto.spawn("wrench", p.cell)
	_check("wielding reserves the other hand", inv.free_hand() == -1 and not inv.put_in_hands(spare, 1))
	_check("wielded offhand rejects drag previews", not DragDrop.apply(p, spare, {"kind": "hand", "idx": 1}, true))
	spare.spr_sheet = ""
	spare.spr_name = "custom-held-icon"
	var doll: PaperDoll = p.c(&"mob").doll
	doll.set_held(0, spare)
	var fallback_ok := true
	for facing in [Defs.DIR_S, Defs.DIR_E, Defs.DIR_N, Defs.DIR_W]:
		doll.set_facing(facing, 0)
		fallback_ok = fallback_ok and doll.held_l.region_rect == spare.spr.region_rect
	_check("held sprite fallback keeps the new item's region in every direction", fallback_ok)
	inv._refresh()
	spare.destroy()
	inv.drop(axe)
	_check("dropping an axe clears its wielded state", not axe.c(&"item").is_wielded)
	inv.put_in_hands(axe, 0)
	axe.c(&"item").attack_self(p)
	box.c(&"storage").insert(axe)
	_check("storing an axe clears its wielded state", not axe.c(&"item").is_wielded)
	inv.put_in_hands(axe, 0)
	p.c(&"health").missing["r_arm"] = true
	axe.c(&"item").attack_self(p)
	_check("a missing other arm cannot wield a two-handed item", not axe.c(&"item").is_wielded)
	p.c(&"health").missing.erase("r_arm")
	box.c(&"storage").insert(axe)
	storage.insert(tool)
	inv.put_in_hands(bag, 0)
	var destination := p.cell + Vector2i(3, 0)
	p.place(destination)
	bag.destroy()
	_check("destroyed carried bag spills at carrier location", tool.holder == null and tool.cell == destination and tool in Game.at(destination))
	var sheets := Proto.spawn("sheet_metal", p.cell, {"comps": {"stack": {"amount": 12}}})
	var slot := InvSlot.new("hot_0", "")
	add_child(slot)
	slot.set_item(sheets)
	_check("stack count and hotkey instructions are visible", slot.count_label.text == "12" and "(12)" in slot.tooltip_text and "press 5" in slot.tooltip_text)
	sheets.c(&"stack").use(2)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("stack badge updates after consuming materials", slot.count_label.text == "10" and "(10)" in slot.tooltip_text)
	sheets.destroy()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("destroyed stack clears its inventory icon", slot.item == null and slot.count_label.text == "")
	_vital_mechanics()
	_container_mechanics()
	_locker_parity()
	print("POLISHTEST DONE: %d failed" % fails)
	get_tree().quit(1 if fails else 0)

func _container_mechanics() -> void:
	var cell := Vector2i(6, 6)
	var user := Crew.spawn_human("assistant", cell + Vector2i.LEFT, {"name": "Container operator"})
	user.remove_comp(&"brain")
	Quirks.remove_all(user)
	var patient := Crew.spawn_human("assistant", cell, {"name": "Locker patient"})
	patient.remove_comp(&"brain")
	Quirks.remove_all(patient)
	patient.remove_comp(&"mood")
	var locker := Proto.spawn("locker", cell)
	var st: CStorage = locker.c(&"storage")
	st.open(user)
	user.c(&"mob").start_pulling(patient)
	_check("closing a locker encloses people on its tile", st.close(user) and patient in st.occupants and patient.holder == locker and patient.has_meta("inside") and not patient.visible)
	_check("locker closure clears incoming pulls and world selection", user.c(&"mob").pulling == null and patient not in PlayerController.entities_at(cell) and patient not in Game.at(cell))
	user.c(&"mob").start_pulling(patient)
	_check("enclosed people cannot be pulled", user.c(&"mob").pulling == null)
	patient.c(&"mob").try_step(Vector2i.RIGHT)
	_check("walking exits an unlocked locker", st.is_open and patient.holder == null and not patient.has_meta("inside") and patient.visible and patient in Game.at(cell))
	st.close(user)
	st.locked = true
	patient.c(&"mob").try_step(Vector2i.RIGHT)
	_check("walking cannot exit a locked locker", not st.is_open and patient.has_meta("inside"))
	st.container_resist(patient)
	DoAfter.process(119.0)
	_check("locked locker breakout takes the full two minutes", DoAfter.busy(patient) and not st.is_open)
	DoAfter.process(1.01)
	_check("resisting breaks the lock and releases the occupant", st.is_open and not st.locked and not patient.has_meta("inside"))
	st.close(user)
	locker.tags["welded"] = true
	st.container_resist(patient)
	DoAfter.process(120.01)
	_check("resisting can also break out of a welded locker", st.is_open and not locker.tags.get("welded", false) and patient.holder == null)
	st.close(user)
	st.locked = true
	patient.c(&"health").cuffed = true
	st.container_resist(patient)
	DoAfter.process(120.01)
	_check("cuffed occupants can resist a locked locker", st.is_open and patient.holder == null)
	patient.c(&"health").cuffed = false
	st.close(user)
	locker.place(cell + Vector2i.RIGHT)
	_check("carried occupants follow a moving locker", patient.cell == locker.cell and patient.root_cell() == locker.cell)
	locker.destroy()
	_check("destroying a locker releases occupants at its current location", patient.holder == null and not patient.has_meta("inside") and patient.visible and patient in Game.at(cell + Vector2i.RIGHT))
	patient.place(cell)
	var crate := Proto.spawn("crate", cell)
	var cs: CStorage = crate.c(&"storage")
	_check("standing on a closed crate blocks opening its lid", not cs.open(user))
	patient.place(cell + Vector2i.UP)
	cs.open(user)
	patient.place(cell)
	_check("a standing person blocks a crate lid", not cs.close(user) and cs.is_open)
	patient.c(&"health").set_resting(true, false)
	_check("a lying person fits inside a crate", cs.close(user) and patient in cs.occupants)
	cs.open(user)
	patient.c(&"health").set_resting(false, false)
	crate.destroy()
	var dragged_locker := Proto.spawn("locker", cell + Vector2i.RIGHT)
	var dragged_storage: CStorage = dragged_locker.c(&"storage")
	dragged_storage.open(user)
	user.place(cell)
	user.remove_comp(&"mood")
	user.c(&"mob").start_pulling(patient)
	var drop := {"kind": "world", "cell": dragged_locker.cell, "ents": [dragged_locker]}
	_check("dragging a patient into an open locker starts a timed action", DragDrop.apply(user, patient, drop, false) and DoAfter.busy(user) and dragged_storage.is_open)
	DoAfter.process(3.0)
	_check("locker stuffing cannot complete before four seconds", DoAfter.busy(user) and dragged_storage.is_open)
	DoAfter.process(1.01)
	_check("locker stuffing encloses and briefly paralyzes the patient", patient in dragged_storage.occupants and patient.c(&"health").has_status("paralyzed") and user.c(&"mob").pulling == null)
	dragged_locker.destroy()
	patient.c(&"health").status.clear()
	var tool := Proto.spawn("wrench", user.cell)
	user.c(&"inv").put_in_hands(tool)
	patient.c(&"health").cuffed = true
	_check("failed handoff preserves the giver's held item", not DragDrop._give(user, tool, patient) and tool.holder == user)
	patient.c(&"health").cuffed = false
	tool.destroy()
	patient.destroy()
	user.destroy()

func _locker_parity() -> void:
	var cell := Vector2i(10, 6)
	var user := Crew.spawn_human("assistant", cell + Vector2i.LEFT, {"name": "Locker operator"})
	user.remove_comp(&"brain")
	user.remove_comp(&"mood")
	Quirks.remove_all(user)
	var inv: CInventory = user.c(&"inv")
	for item in inv.hands.duplicate():
		if item: item.destroy()
	var card: CIdCard = inv.worn("id").c(&"idcard")
	card.access = []
	var locker := Proto.spawn("locker", cell, {"comps": {"storage": {"access": ["security"]}}})
	var st: CStorage = locker.c(&"storage")
	_check("secure lockers start locked and deny unauthorized unlocks", st.secure and st.locked and not st.toggle_lock(user))
	var integrity: CIntegrity = locker.c(&"integrity")
	_check("secure locker has TG durability, armor and deflection", integrity.max_hp == 250.0 and integrity.deflect == 20.0 and integrity.armor.get("melee") == 30 and integrity.armor.get("bullet") == 50 and integrity.armor.get("energy") == 100)
	_check("secure locker deflects weak tools and halves bullets", integrity.reduce(19.0, "brute", "melee", 0.0) == 0.0 and integrity.reduce(40.0, "brute", "bullet", 0.0) == 20.0)
	card.access = ["security"]
	_check("access does not bypass a closed lock", not st.open(user) and st.locked)
	st.attack_hand(user)
	_check("first authorized click unlocks without opening", not st.locked and not st.is_open)
	st.attack_hand(user)
	_check("second click opens the unlocked locker", st.is_open)
	_check("an open locker cannot be locked", not st.toggle_lock(user))
	st.close(user)
	card.access = []
	_check("anyone can lock an unlocked secure locker", st.toggle_lock(user) and st.locked)
	_check("a locked locker cannot be opened without a user", not st.open())
	var verbs := []
	st.verbs(user, verbs)
	_check("secure locker exposes an explicit unlock action", verbs.any(func(v): return v["name"] == "Unlock"))
	var supply := Proto.spawn("wrench", cell)
	st.insert(supply)
	var retrieval := Act.PickUp.new(supply)
	var operator := {"e": user, "inv": inv}
	_check("NPC retrieval fails promptly without locker access", retrieval.tick(operator, 0.0) == Act.FAILED and st.locked and not st.is_open)
	card.access = ["security"]
	_check("authorized NPC retrieval unlocks and opens", retrieval.tick(operator, 0.0) == Act.RUNNING and st.is_open and not st.locked)
	_check("NPC retrieves the released locker item", retrieval.tick(operator, 0.0) == Act.DONE and supply.holder == user)
	supply.destroy()
	st.close(user)
	st.toggle_lock(user)
	locker.tags["welded"] = true
	locker.c(&"integrity").hp = 70.0
	locker.c(&"integrity").take_damage(11.0, "brute", user)
	_check("damage bursts a welded locked locker open", st.is_open and not st.locked and not locker.tags.get("welded", false))
	_check("a broken secure lock cannot be reused", st.broken_lock and not st.toggle_lock(user))
	locker.destroy()
	var limited := Proto.spawn("locker", cell, {"comps": {"storage": {"capacity": 2}}})
	var ls: CStorage = limited.c(&"storage")
	ls.open(user)
	var items := []
	for i in 3: items.append(Proto.spawn("toolbox", cell))
	var stuck := Proto.spawn("wrench", cell)
	stuck.set_meta("nodrop", true)
	ls.close(user)
	_check("locker capacity counts objects rather than item weight", ls.contents.size() == 2 and ls.used() == 2)
	_check("overflow and no-drop items remain on the floor", items.filter(func(x): return x.holder == null).size() == 1 and stuck.holder == null)
	limited.place(cell + Vector2i.RIGHT)
	_check("moving lockers update contained item locations", ls.contents.all(func(x): return x.cell == limited.cell and x not in Game.at(limited.cell)))
	limited.destroy()
	for item in items + [stuck]: item.destroy()
	var wrench := Proto.spawn("wrench", user.cell)
	inv.put_in_hands(wrench)
	var tools_locker := Proto.spawn("locker", cell)
	var ts: CStorage = tools_locker.c(&"storage")
	_check("secondary wrench action bolts down a locker", ts.wrench_secondary(user, wrench) and tools_locker.tags["anchored"])
	_check("secondary wrench action unbolts a locker", ts.wrench_secondary(user, wrench) and not tools_locker.tags["anchored"])
	wrench.destroy()
	if inv.worn("head"): inv.worn("head").destroy()
	inv.equip(Proto.spawn("welding_helmet", user.cell), "head")
	var welder := Proto.spawn("welder", user.cell)
	inv.put_in_hands(welder, inv.active)
	welder.c(&"welder").lit = true
	Construction.tool_act(user, welder, tools_locker)
	DoAfter.process(3.0)
	_check("locker welding waits the full four seconds", DoAfter.busy(user) and not tools_locker.tags.get("welded", false))
	DoAfter.process(1.01)
	_check("completed welding consumes one fuel and seals the door", tools_locker.tags.get("welded", false) and is_equal_approx(welder.c(&"welder").fuel, 39.0))
	Construction.tool_act(user, welder, tools_locker)
	DoAfter.process(4.01)
	_check("unwelding restores a usable door", not tools_locker.tags.get("welded", false) and ts.open(user))
	ts.close(user)
	var fuel: float = welder.c(&"welder").fuel
	Construction.tool_act(user, welder, tools_locker)
	ts.open(user)
	DoAfter.process(4.01)
	_check("opening mid-weld prevents sealing and preserves fuel", ts.is_open and not tools_locker.tags.get("welded", false) and is_equal_approx(welder.c(&"welder").fuel, fuel))
	Construction.tool_act(user, welder, tools_locker)
	ts.close(user)
	DoAfter.process(4.01)
	_check("closing mid-cut prevents locker deconstruction", not tools_locker.removed and is_equal_approx(welder.c(&"welder").fuel, fuel))
	welder.c(&"welder").fuel = 0.0
	Construction.tool_act(user, welder, tools_locker)
	_check("an empty welder cannot start a locker action", not DoAfter.busy(user))
	tools_locker.destroy()
	welder.destroy()
	user.destroy()

func _vital_mechanics() -> void:
	# Isolate projectile paths from generated station layout and restore the terrain.
	var terrain := []
	for x in range(2, 22):
		for y in range(2, 14):
			var cell := Vector2i(x, y)
			var index := Game.map.idx(cell)
			terrain.append([cell, Game.map.turf[index], Game.map.structure[index]])
			Game.map.set_turf(cell, Defs.T_PLATING)
			Game.map.set_structure(cell, Defs.S_NONE)
	var user := Crew.spawn_human("assistant", Vector2i(4, 8), {"name": "Vital systems tester"})
	user.remove_comp(&"brain")
	Quirks.remove_all(user)
	var inv: CInventory = user.c(&"inv")
	var health: CHealth = user.c(&"health")
	for item in inv.hands.duplicate():
		if item: inv.drop(item)
	inv.active = 0
	health.missing["l_arm"] = true
	var wrench := Proto.spawn("wrench", user.cell)
	_check("pickup uses the remaining arm when the active arm is missing", Interact.pickup(user, wrench) and inv.hands[1] == wrench and inv.hands[0] == null)
	inv.drop(wrench)
	health.missing["r_arm"] = true
	_check("two missing arms leave no hand and cannot receive an item", inv.free_hand() == -1 and not inv.put_in_hands(wrench) and wrench.holder == null)
	health.missing.clear()
	health.wounds.append({"part": "l_arm", "disabling": true})
	_check("a disabled active arm does not receive inventory items", inv.put_in_hands(wrench, 0) and inv.hands[1] == wrench)
	inv.drop(wrench)
	health.wounds.clear()
	var result := []
	var neighbor := Proto.spawn("wrench", user.cell + Vector2i(1, 1))
	DoAfter.start(user, neighbor, 1.0, func(ok): result.append(ok))
	Game.map.set_turf(user.cell + Vector2i(1, 0), Defs.T_WALL)
	Game.map.set_turf(user.cell + Vector2i(0, 1), Defs.T_WALL)
	DoAfter.process(1.0)
	_check("a timed action cannot complete through two closed wall corners", result == [false])
	Game.map.set_turf(user.cell + Vector2i(1, 0), Defs.T_PLATING)
	Game.map.set_turf(user.cell + Vector2i(0, 1), Defs.T_PLATING)
	var victims := []
	for y in [7, 8, 9]:
		var victim := Crew.spawn_human("assistant", Vector2i(12, y), {"name": "Projectile tester"})
		victim.remove_comp(&"brain")
		Quirks.remove_all(victim)
		victims.append(victim)
	var target: Entity = victims[1]
	var target_health: CHealth = target.c(&"health")
	var crate := Proto.spawn("crate", target.cell)
	var revolver := Proto.spawn("revolver", user.cell)
	var ballistic: CGadget = revolver.c(&"gadget")
	ballistic.chamber = ["ammo_38"]
	ballistic.fire(user, target.cell)
	_check("solid cover stops a bullet before a person sharing its tile", is_zero_approx(target_health.brute))
	var laser := Proto.spawn("laser_gun", user.cell)
	laser.c(&"gadget").fire(user, target.cell)
	_check("solid cover stops a laser before a person sharing its tile", is_zero_approx(target_health.burn))
	target_health.set_resting(true, false)
	crate.c(&"storage").open(user)
	target_health.set_resting(false, false)
	ballistic.cooldown = 0.0
	ballistic.chamber = ["ammo_38"]
	ballistic.fire(user, target.cell)
	_check("opening the cover allows the bullet to reach the person", target_health.brute > 0.0)
	Traumas.gain(health, "pacifism")
	ballistic.cooldown = 0.0
	ballistic.chamber = ["ammo_38"]
	var damage_before := target_health.brute
	ballistic.fire(user, target.cell)
	_check("traumatic pacifism prevents firing a lethal ballistic round", ballistic.chamber == ["ammo_38"] and is_equal_approx(target_health.brute, damage_before))
	var energy_gun := Proto.spawn("egun", user.cell)
	var energy: CGadget = energy_gun.c(&"gadget")
	energy.mode = "disable"
	var before_charge := energy.charges
	energy.fire(user, target.cell)
	_check("pacifism permits an energy gun in disabler mode", energy.charges == before_charge - 1 and target_health.stamina < 100.0)
	energy.cooldown = 0.0
	energy.mode = "kill"
	before_charge = energy.charges
	energy.fire(user, target.cell)
	_check("switching that energy gun to lethal mode prevents firing", energy.charges == before_charge)
	Traumas.cure_all(health, Traumas.RES_ABSOLUTE)
	crate.destroy()
	var shotgun := Proto.spawn("shotgun", user.cell)
	var gun: CGadget = shotgun.c(&"gadget")
	var off_center_damage := 0.0
	for shot in 12:
		for victim in victims:
			var h: CHealth = victim.c(&"health")
			h.brute = 0.0
			h.limb.clear()
			h.wounds.clear()
			h.status.clear()
			h.knockdown_t = 0.0
			h.resting = false
			h.get_up(true)
		gun.cooldown = 0.0
		gun.chamber = ["shell_buckshot"]
		gun.pump_needed = false
		gun.fire(user, target.cell)
		off_center_damage += victims[0].c(&"health").brute + victims[2].c(&"health").brute
	_check("buckshot spreads onto neighboring targets rather than one identical ray", off_center_damage > 0.0)
	_source_mechanics(user, target)
	for entity in victims + [user, wrench, neighbor, revolver, laser, shotgun, energy_gun]: entity.destroy()
	for tile in terrain:
		Game.map.set_turf(tile[0], tile[1])
		Game.map.set_structure(tile[0], tile[2])

func _source_mechanics(user: Entity, target: Entity) -> void:
	var inv: CInventory = user.c(&"inv")
	var health: CHealth = target.c(&"health")
	var target_inv: CInventory = target.c(&"inv")
	for item in inv.hands.duplicate():
		if item: inv.drop(item)
	for item in target_inv.hands.duplicate():
		if item: target_inv.drop(item)
	var shotgun := Proto.spawn("shotgun", user.cell)
	var gun: CGadget = shotgun.c(&"gadget")
	inv.put_in_hands(shotgun)
	_check("TG riot shotgun starts with six rubber-shot shells", gun.chamber.size() == 6 and gun.chamber[0] == "shell_rubbershot" and gun.chamber_ready())
	var top_up := Proto.spawn("shell_slug", user.cell, {"comps": {"stack": {"amount": 2}}})
	gun.load_ammo(user, top_up)
	_check("shotgun tube can top up to six plus one chambered shell", gun.chamber.size() == 7 and top_up.c(&"stack").amount == 1)
	gun.fire(user, user.cell + Vector2i(10, 4))
	_check("firing leaves a spent shell and requires pumping", gun.pump_needed and gun.spent_shell == "shell_rubbershot" and gun.chamber.size() == 6 and is_equal_approx(gun.cooldown, 0.8))
	gun.cooldown = 0.0
	gun.fire(user, user.cell + Vector2i(10, 4))
	_check("pulling the trigger before pumping cannot consume a second shell", gun.chamber.size() == 6)
	gun.pump(user)
	_check("pumping ejects the spent casing and feeds the next shell", gun.chamber_ready() and gun.spent_shell == "" and Game.at(user.cell).any(func(item): return item.proto == "spent_shell"))
	var shells_before := gun.chamber.size()
	gun.pump(user)
	_check("pumping a live shell ejects recoverable ammunition", gun.chamber.size() == shells_before - 1 and Game.at(user.cell).any(func(item): return item.proto == "shell_rubbershot" and item.c(&"stack").amount == 1))
	gun.unload(user)
	var single := Proto.spawn("shell_beanbag", user.cell, {"comps": {"stack": {"amount": 1}}})
	gun.load_ammo(user, single)
	_check("loading an empty shotgun fills the tube without silently chambering", gun.pump_needed and not gun.chamber_ready())
	gun.pump(user)
	_check("pumping an empty chamber readies the loaded tube", gun.chamber_ready())
	# Direct projectile paths remove spread and hit-zone randomness from numeric checks.
	user.c(&"mob").aim_at_zone("chest")
	var victim_health := func():
		health.brute = 0.0
		health.burn = 0.0
		health.stamina = 100.0
		health.limb.clear()
		health.limb_burn.clear()
		health.wounds.clear()
		health.status.clear()
		health.knockdown_t = 0.0
		health.resting = false
		health.get_up(true)
	for slot in target_inv.slots.keys(): target_inv.drop(target_inv.worn(slot))
	var armor := Proto.spawn("armor_vest", target.cell)
	target_inv.equip(armor, "suit")
	_check("armor vest protects chest with separate energy and laser ratings", is_equal_approx(Combat.armor_vs(target, "chest", "energy"), 40.0) and is_equal_approx(Combat.armor_vs(target, "chest", "laser"), 30.0))
	_check("a chest vest does not supply arm armor or wound protection", is_zero_approx(Combat.armor(target, "l_arm")) and is_zero_approx(Body.wound_armor(health, "l_arm")))
	victim_health.call()
	var slug := CGadget.ROUNDS["shell_slug"].duplicate()
	var direction := Vector2(target.cell - user.cell).normalized()
	for part in Body.PARTS:
		if part != "chest": health.missing[part] = true
	gun._bullet(user, target.cell, direction, slug)
	_check("slug armor penetration defeats a thirty-point vest", is_equal_approx(health.brute, 25.0))
	victim_health.call()
	var disabler := Proto.spawn("disabler", user.cell)
	disabler.c(&"gadget").fire(user, target.cell)
	_check("disabler stamina damage uses energy armor rather than laser armor", is_equal_approx(health.stamina, 82.0))
	health.missing.clear()
	target_inv.drop(armor)
	var riot := Proto.spawn("riot_armor", target.cell)
	target_inv.equip(riot, "suit")
	_check("riot armor protects legs and feet with the source ratings", is_equal_approx(Combat.armor(target, "l_leg"), 50.0) and is_equal_approx(Combat.armor(target, "r_foot"), 50.0) and is_equal_approx(Body.wound_armor(health, "l_leg"), 20.0))
	target_inv.drop(riot)
	var shield := Proto.spawn("riot_shield", target.cell, {"comps": {"item": {"block": 150}}})
	target_inv.put_in_hands(shield)
	victim_health.call()
	gun._bullet(user, target.cell, direction, CGadget.ROUNDS["ammo_38"])
	_check("ballistic projectile checks held shield blocking", is_zero_approx(health.brute))
	var laser := Proto.spawn("laser_gun", user.cell)
	laser.c(&"gadget").fire(user, target.cell)
	_check("laser ignores a transparent shield even at guaranteed block chance", health.burn > 0.0)
	target_inv.drop(shield)
	victim_health.call()
	var distance := user.dist_to(target)
	gun._bullet(user, target.cell, direction, CGadget.ROUNDS["shell_buckshot"])
	_check("buckshot damage loses a quarter point per traveled tile", is_equal_approx(health.brute, 5.0 - 0.25 * distance))
	victim_health.call()
	gun._bullet(user, target.cell, direction, CGadget.ROUNDS["shell_rubbershot"])
	_check("rubber shot applies damage and stamina falloff separately", is_equal_approx(health.brute, maxf(0.0, 3.0 - 0.25 * distance)) and is_equal_approx(health.stamina, 100.0 - (10.0 - 0.25 * distance)))
	# A repaired corpse must revive in crit, and severely injured corpses retain ratios.
	health.dead = true
	health.brute = 0.0
	health.burn = 0.0
	health.tox = 0.0
	health.oxy = 0.0
	health.revive(true)
	_check("defibrillation of a repaired corpse restores minus fifty health via oxygen loss", not health.dead and is_equal_approx(health.health(), -50.0) and is_equal_approx(health.oxy, 150.0))
	health.dead = true
	health.brute = 100.0
	health.burn = 50.0
	health.tox = 50.0
	health.oxy = 100.0
	health.revive(true)
	_check("defibrillation scales every damage type proportionally", not health.dead and is_equal_approx(health.brute, 50.0) and is_equal_approx(health.burn, 25.0) and is_equal_approx(health.tox, 25.0) and is_equal_approx(health.oxy, 50.0))
	for item in inv.hands.duplicate():
		if item: inv.drop(item)
	user.place(target.cell + Vector2i(-1, 0))
	user.c(&"mob").intent = "help"
	var defib := Proto.spawn("defib", user.cell)
	inv.put_in_hands(defib)
	health.dead = true
	health.brute = 0.0
	health.burn = 0.0
	health.tox = 0.0
	health.oxy = 0.0
	var medical_speed := Skills.speed(user, "medical")
	defib.c(&"gadget")._defib(user, target)
	DoAfter.process(3.0 * medical_speed)
	_check("defibrillator has not fired at the old three-second cutoff", health.dead and defib.c(&"gadget").charges == 8 and DoAfter.busy(user))
	DoAfter.process(2.0 * medical_speed + 0.01)
	_check("five-second defibrillator workflow consumes charge and revives into crit", not health.dead and defib.c(&"gadget").charges == 7 and is_equal_approx(health.health(), -50.0) and health.has_status("jitter"))
	var charger := Proto.spawn("recharger", user.cell, {"comps": {"machine": {"needs_power": false}}})
	var recharge: CRecharger = charger.c(&"recharger")
	var battery: CGadget = laser.c(&"gadget")
	battery.charges = 0
	recharge.attackby(user, laser)
	recharge.tick(4.5)
	_check("recharger accounts for elapsed time rather than one charge per tick", battery.charges == 3)
	recharge.tick(0.75)
	charger.c(&"machine").broken = true
	recharge.tick(4.5)
	_check("broken rechargers stop charging and active power draw", battery.charges == 3 and not charger.c(&"machine").active)
	charger.c(&"machine").broken = false
	recharge.attack_hand(user)
	recharge.attackby(user, laser)
	recharge.tick(0.75)
	_check("replacing a device starts a fresh charge interval", battery.charges == 3)
	charger.destroy()
	_check("destroying a recharger releases its device to the floor", laser.holder == null and laser in Game.at(user.cell))
	for item in [shotgun, top_up, armor, shield, laser, disabler, riot, defib]: item.destroy()
