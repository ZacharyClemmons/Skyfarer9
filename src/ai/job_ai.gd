class_name JobAI extends RefCounted
## Job duties. Each job turns the NPC's *own knowledge* into work: an engineer only fixes
## the leak they've seen, heard about on the radio, or found on a console. Diligence
## scales duty; lazy crew ignore small stuff.

static func _g(id: String, score: float, desc: String, plan: Callable, extra := {}) -> Dictionary:
	var d := {"id": id, "score": score, "desc": desc, "plan": plan}
	d.merge(extra)
	return d

static func candidates(b: CBrain) -> Array:
	var out := []
	var dept := Jobs.dept(b.job)
	var dil := 0.45 + b.tv("diligence") * 0.8
	if b.antag.size() > 0:
		out.append_array(_antag(b))
	match dept:
		"engineering":
			out.append_array(_engineering(b, dil))
		"medical":
			out.append_array(_medical(b, dil))
		"security":
			out.append_array(_security(b, dil))
		"science":
			out.append_array(_science(b, dil))
		"service":
			out.append_array(_service(b, dil))
		"supply":
			out.append_array(_supply(b, dil))
		"command":
			out.append_array(_command(b, dil))
		_:
			out.append_array(_civilian(b, dil))
	if Jobs.is_head(b.job) and dept != "command":
		out.append_array(_command(b, dil * 0.6))
	# everyone on shift drifts back to their workplace
	if not b.in_work_area() and not b.work_cells().is_empty():
		out.append(_g("go_to_work", 70.0 * dil, "heading to work", func(): return [Act.GoTo.new(b.work_cells()[randi() % b.work_cells().size()], false, false)], {"cooldown": 60.0}))
	return out

static func _console(kind: String) -> Entity:
	for c in Game.all_with(&"console"):
		if c.c(&"console").kind == kind:
			return c
	return null

static func _read_console(bb: CBrain, con: Entity) -> int:
	if con == null or not bb.e.adjacent(con):
		return ActBase.FAILED
	for line in con.c(&"console").readout():
		var f: Dictionary = line["fact"]
		if not f.is_empty():
			bb.knowledge.learn(f, Knowledge.JOB)
	bb.mob.face(Defs.dir_from_vec(con.cell - bb.e.cell) if con.cell != bb.e.cell else bb.mob.dir)
	return ActBase.DONE

static func _check_console_plan(con: Entity) -> Array:
	return [Act.GoTo.new(con, true, false), Act.Wait.new(1.5), Act.Do.new(func(bb, _dt): return JobAI._read_console(bb, con), "reading a console")]

static func _acquire_or_null(b: CBrain, tag: String, vend := ""):
	return b.plan_acquire(tag, vend)

# ============================================================================ engineering
static func _engineering(b: CBrain, dil: float) -> Array:
	var out := []
	var k := b.knowledge
	var here := b.e.cell
	# the reactor
	var rh := k.get_fact("reactor_hot")
	var cool_low := not k.of_type("coolant_low").is_empty()
	if (not rh.is_empty() and rh.get("severity", 0) >= 1) or cool_low:
		var sev: int = rh.get("severity", 1) if not rh.is_empty() else 1
		out.append(_g("reactor", (470.0 + sev * 150.0) * dil * (0.7 + b.tv("bravery") * 0.5), "getting the reactor under control", func(): return JobAI._plan_reactor(b), {"cooldown": 25.0, "claim": "reactor", "claim_ttl": 60.0}))
	# pipe leaks
	var leak := k.nearest("pipe_leak", here)
	if not leak.is_empty():
		var hot = leak.get("data", {}).get("layer", 0) == StationMap.PL_HOT
		var s := (320.0 + (200.0 if hot else 0.0)) * dil
		if b.tv("diligence") < 0.3 and not hot:
			s *= 0.4
		var lc: Vector2i = leak["cell"]
		var lkey: String = leak["key"]
		out.append(_g("fix_leak", s, "fixing a leaking pipe", func(): return JobAI._plan_fix_tile(b, "tool_welder", "welder", lc, lkey), {"fail_cooldown": 30.0, "claim": lkey}))
	# breaches
	var br := k.nearest("breach", here)
	if not br.is_empty():
		var bc: Vector2i = br["cell"]
		var bkey: String = br["key"]
		out.append(_g("fix_breach", 430.0 * dil * (0.6 + b.tv("bravery") * 0.6), "patching a breach", func(): return JobAI._plan_fix_breach(b, bc, bkey), {"fail_cooldown": 30.0, "claim": bkey}))
	# damaged wiring
	var cab := k.nearest("cable_damaged", here)
	if not cab.is_empty():
		var cc: Vector2i = cab["cell"]
		var ckey: String = cab["key"]
		out.append(_g("fix_cable", 360.0 * dil, "splicing burnt wiring", func(): return JobAI._plan_fix_tile(b, "mat_cable", "stack:cable", cc, ckey), {"fail_cooldown": 30.0, "claim": ckey}))
	# power outages
	var po := k.nearest("power_out", here)
	if not po.is_empty():
		var apc := Game.get_entity(po.get("subject", 0))
		if apc and apc.has_c(&"apc"):
			out.append(_g("power", (280.0 + po.get("severity", 1) * 50.0) * dil, "restoring power to %s" % Game.map.areas[po.get("area", 0)].name, func(): return JobAI._plan_power(b, apc, po["key"]), {"fail_cooldown": 40.0, "claim": po["key"]}))
	# broken machines
	var bm := k.nearest("broken_machine", here)
	if not bm.is_empty():
		var m := Game.get_entity(bm["subject"])
		if m and m.c(&"machine") and m.c(&"machine").broken:
			out.append(_g("fix_machine", (200.0 + bm.get("severity", 1) * 70.0) * dil, "repairing %s" % m.display_name, func(): return JobAI._plan_fix_machine(b, m), {"fail_cooldown": 40.0, "claim": "broken:%d" % m.id}))
	# cold rooms
	var cold := k.nearest("cold_area", here)
	if not cold.is_empty():
		var ca: Area = Game.map.areas[cold.get("area", 0)]
		out.append(_g("check_heating", 190.0 * dil, "checking the heating in %s" % ca.name, func(): return [Act.GoTo.new(ca.random_cell(Game.rng), false, false), Act.Wait.new(2.0)], {"cooldown": 90.0}))
	# firefighting is part of the job
	var fire := k.nearest("fire", here, func(f): return Game.time - f["t"] < 30.0)
	if not fire.is_empty():
		var fc: Vector2i = fire["cell"]
		out.append(_g("extinguish", (480.0 if b.job == "atmos" else 420.0) * (0.5 + b.tv("bravery")), "fighting a fire", func(): return Goals._plan_extinguish(b, fc)))
	# atmos specifics
	if b.job in ["atmos", "ce"]:
		# tg's first job of every shift: max the distro, so the vents have air to push
		var slack := JobAI._atmos_setup_todo()
		if not slack.is_empty():
			var urgent := JobAI._station_pressure() < 90.0
			out.append(_g("setup_atmos", (520.0 if urgent else 300.0) * dil, "setting up the air plant", func(): return JobAI._plan_atmos_setup(b, slack), {"cooldown": 20.0, "fail_cooldown": 60.0,
				"claim": "atmos_setup", "why": "The air plant's still at one atmosphere. Max it before the air thins out." if not urgent else "Pressure's dropping everywhere. The air plant!"}))
		var al := k.nearest("atmos_alarm", here)
		if not al.is_empty():
			var ac: Vector2i = al["cell"]
			out.append(_g("atmos_alarm", 360.0 * dil, "answering the air bell", func(): return [Act.GoTo.new(ac, true, true), Act.Wait.new(2.0)], {"cooldown": 60.0, "claim": al["key"]}))
		if not k.of_type("air_low").is_empty():
			out.append(_g("refill_air", 300.0 * dil, "refilling the air reserves", func(): return JobAI._plan_refill_air(b), {"cooldown": 200.0, "fail_cooldown": 120.0, "claim": "air_low"}))
		var atc := _console("atmos")
		if atc:
			out.append(_g("check_alerts", 110.0 * dil, "checking the alert console", func(): return JobAI._check_console_plan(atc), {"cooldown": 150.0}))
	# routine monitoring - job knowledge comes from consoles, not omniscience
	var rc := _console("reactor")
	if rc and b.job != "atmos":
		out.append(_g("check_reactor", 125.0 * dil, "checking the reactor", func(): return JobAI._check_console_plan(rc), {"cooldown": 200.0}))
	var pc := _console("eng")
	if pc:
		out.append(_g("check_power", 95.0 * dil, "checking power levels", func(): return JobAI._check_console_plan(pc), {"cooldown": 240.0}))
	# stock up on the basics
	if not b.has_tool("welder") or not b.has_tool("wrench"):
		var get = b.plan_acquire("tool_welder") if not b.has_tool("welder") else b.plan_acquire("tool_wrench")
		if get != null:
			out.append(_g("gear_up", 150.0 * dil, "grabbing tools", func(): return get, {"cooldown": 60.0}))
	return out

static func _plan_fix_tile(b: CBrain, need_tag: String, tool: String, cell: Vector2i, fact_key: String) -> Array:
	var plan := []
	var get = b.plan_acquire(need_tag, "tool" if need_tag.begins_with("tool") else "")
	if get == null:
		return []
	plan.append_array(get)
	plan.append(Act.GoTo.new(cell, true, true))
	plan.append(Act.UseOnTile.new(tool, cell))
	plan.append(Act.Do.new(func(bb, _dt): return JobAI._verify_fixed(bb, fact_key, cell), "checking the repair"))
	return plan

## A breach: straighten a bent grille with a rod first (tg won't take glass on a broken
## grille), then glaze it with two sheets, reinforced glass if they have it.
static func _plan_fix_breach(b: CBrain, cell: Vector2i, fact_key: String) -> Array:
	var s: int = Game.map.structure[Game.map.idx(cell)]
	if s == Defs.S_GRILLE_BROKEN:
		return _plan_fix_tile(b, "mat_rods", "stack:rods", cell, fact_key)
	if s == Defs.S_NONE:
		return _plan_fix_tile(b, "mat_rods", "stack:rods", cell, fact_key) # a new grille first
	var reinforced := _plan_fix_tile(b, "mat_rglass", "stack:rglass", cell, fact_key)
	if not reinforced.is_empty():
		return reinforced
	return _plan_fix_tile(b, "mat_glass", "stack:glass", cell, fact_key)

static var _fixed_said := {}

static func _verify_fixed(bb: CBrain, key: String, cell: Vector2i) -> int:
	var map := Game.map
	var fixed := true
	var f := bb.knowledge.get_fact(key)
	match f.get("type", ""):
		"pipe_leak":
			fixed = map.pipe_hp_at(f.get("data", {}).get("layer", 0), cell) >= 100.0
		"breach":
			fixed = Defs.is_window(map.structure[map.idx(cell)])
		"cable_damaged":
			fixed = map.cable[map.idx(cell)] != 2
	if fixed:
		bb.knowledge.forget(key)
		var ar := map.area_at(cell)
		if bb.inv.headset() and randf() < 0.6 and Game.time - JobAI._fixed_said.get(ar.id, -999.0) > 150.0:
			JobAI._fixed_said[ar.id] = Game.time
			bb.radio_say(bb.radio_channel(), Dialogue.line("fixed", bb, {"area": ar.name}), {})
		Skills.add_xp(bb.e, "engineering", 10.0)
	return ActBase.DONE

static func _plan_reactor(b: CBrain) -> Array:
	var plan := []
	var con := _console("reactor")
	if con:
		plan.append(Act.GoTo.new(con, true, true))
		plan.append(Act.Do.new(func(bb, _dt): return JobAI._reactor_adjust(bb, con), "adjusting control rods"))
	# go find the leak on the hot loop if we don't know one
	var hot_leaks := b.knowledge.of_type("pipe_leak").filter(func(f): return f.get("data", {}).get("layer", 0) == StationMap.PL_HOT)
	if hot_leaks.is_empty():
		var nets = Game.pipes.nets_on_layer(StationMap.PL_HOT)
		if not nets.is_empty():
			var cells: Array = nets[0].cells
			for k in range(0, cells.size(), maxi(1, cells.size() / 4)):
				plan.append(Act.GoTo.new(Game.map.cell_of(cells[k]), true, true))
	# top up coolant from a nitrogen canister
	var net = Game.pipes.nets_on_layer(StationMap.PL_HOT)
	if not net.is_empty() and net[0].total_moles() < 650.0:
		var port: Entity = null
		for v in Game.all_with(&"vent"):
			if v.c(&"vent").mode == "port":
				port = v
		var can: Entity = null
		for t in Game.all_with(&"tank"):
			if t.proto == "canister_n2" and t.c(&"tank").moles > 100 and t.holder == null:
				if can == null or t.dist_to(b.e) < can.dist_to(b.e):
					can = t
		if port and can:
			plan.append_array([Act.GoTo.new(can, true), Act.Pull.new(can), Act.GoTo.new(port, true), Act.StopPull.new()])
			var wr = b.plan_acquire("tool_wrench", "tool")
			if wr != null:
				plan.append_array(wr)
				plan.append(Act.GoTo.new(port, true))
				plan.append(Act.UseOn.new("wrench", port))
	return plan

static func _reactor_adjust(bb: CBrain, con: Entity) -> int:
	_read_console(bb, con)
	for r in Game.all_with(&"reactor"):
		var rc: CReactor = r.c(&"reactor")
		var skill := Skills.get_skill(bb.e, "engineering")
		if rc.core_temp > CReactor.WARN_T:
			rc.rod_target = minf(1.0, rc.rod_target + 0.15 + skill * 0.02)
		elif rc.core_temp < 500.0:
			rc.rod_target = maxf(0.2, rc.rod_target - 0.1)
		if rc.core_temp > CReactor.DANGER_T and skill >= 6:
			rc.scrammed = true
			bb.radio_say("Engineering", "Scramming the reactor! Everyone find that coolant leak!", {})
		elif Game.time - JobAI._reactor_radio_t > 120.0 and rc.core_temp > CReactor.WARN_T:
			JobAI._reactor_radio_t = Game.time
			bb.radio_say("Engineering", "Inserting control rods, core at %d K." % int(rc.core_temp), {})
	return ActBase.DONE

static var _reactor_radio_t := -999.0

static func _plan_power(b: CBrain, apc: Entity, key: String) -> Array:
	return [Act.GoTo.new(apc, true, true), Act.Do.new(func(bb, _dt): return JobAI._diagnose_apc(bb, apc, key), "inspecting the power junction")]

static func _diagnose_apc(bb: CBrain, apc: Entity, key: String) -> int:
	var a: CApc = apc.c(&"apc")
	var m: CMachine = apc.c(&"machine")
	if m.broken:
		bb.inject_front([Act.UseOn.new("multitool", apc)])
		return ActBase.DONE
	if not a.breaker:
		a.toggle_breaker(bb.e)
		bb.knowledge.forget(key)
		return ActBase.DONE
	if a.grid_ok:
		bb.knowledge.forget(key)
		return ActBase.DONE
	# trace the cable: skilled engineers find the break nearby
	var skill := Skills.get_skill(bb.e, "engineering")
	var map := Game.map
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for i in map.cable.size():
		if map.cable[i] == 2:
			var c := map.cell_of(i)
			var d := Vector2(c - apc.cell).length()
			if d < 10 + skill * 3 and d < bd:
				bd = d
				best = c
	if best.x >= 0:
		bb.knowledge.learn({"key": "cable:%d" % map.idx(best), "type": "cable_damaged", "cell": best, "severity": 2}, Knowledge.JOB)
		if randf() < 0.35:
			bb.bark(Dialogue.line("found_fault", bb, {}))
	else:
		# supply side problem: check the generator room
		bb.knowledge.learn({"key": "reactor_hot", "type": "reactor_hot", "cell": apc.cell, "severity": 1}, Knowledge.JOB, 0.4)
	return ActBase.DONE

static func _plan_fix_machine(b: CBrain, m: Entity) -> Array:
	var get = b.plan_acquire("tool_multitool", "tool")
	if get == null:
		return []
	var plan: Array = get.duplicate()
	plan.append(Act.GoTo.new(m, true, true))
	plan.append(Act.UseOn.new("multitool", m))
	plan.append(Act.Do.new(func(bb, _dt): return JobAI._verify_machine(bb, m), "testing the machine"))
	return plan

static func _verify_machine(bb: CBrain, m: Entity) -> int:
	if is_instance_valid(m) and not m.removed and m.c(&"machine") and m.c(&"machine").broken:
		return ActBase.FAILED
	bb.knowledge.forget("broken:%d" % m.id)
	return ActBase.DONE

## The pumps that keep the station breathing, and the pressure each should run at (tg: the
## mix and the distro pump turned up to maximum at round start).
const ATMOS_SETUP := {"Air to Distro": 4500.0, "O2 to Airmix": 4500.0, "N2 to Airmix": 4500.0}

static func _atmos_setup_todo() -> Array:
	var out := []
	for m in Game.all_with(&"pipemachine"):
		var pm: CPipeMachine = m.c(&"pipemachine")
		if pm.kind == "pump" and ATMOS_SETUP.has(pm.display) and (pm.target_pressure < ATMOS_SETUP[pm.display] - 1.0 or not pm.on):
			var mm: CMachine = m.c(&"machine")
			if mm == null or not mm.broken:
				out.append(m)
	return out

## Mean air pressure across the station's rooms (sampled), in kPa.
static func _station_pressure() -> float:
	var total := 0.0
	var n := 0
	for a in Game.map.areas:
		if a.outdoor or a.room_kind == "gas_chamber" or a.cells.is_empty():
			continue
		total += Game.atmos.pressure_at(a.center)
		n += 1
	return total / maxf(1.0, n)

static func _plan_atmos_setup(b: CBrain, pumps: Array) -> Array:
	var plan := []
	pumps.sort_custom(func(x, y): return x.dist_to(b.e) < y.dist_to(b.e))
	for p in pumps:
		plan.append(Act.GoTo.new(p, true, true))
		plan.append(Act.Do.new(func(bb, _dt): return JobAI._max_pump(bb, p), "adjusting a pump"))
	plan.append(Act.Do.new(func(bb, _dt): return JobAI._atmos_done(bb), ""))
	return plan

static func _max_pump(bb: CBrain, p: Entity) -> int:
	if not is_instance_valid(p) or not bb.e.adjacent(p):
		return ActBase.FAILED
	var pm: CPipeMachine = p.c(&"pipemachine")
	pm.on = true
	pm.target_pressure = ATMOS_SETUP.get(pm.display, CPipeMachine.MAX_PRESSURE)
	bb.mob.face(Defs.dir_from_vec(p.cell - bb.e.cell) if p.cell != bb.e.cell else bb.mob.dir)
	Game.visible_message(p.cell, "%s turns %s up to %d kPa." % [bb.e.display_name, pm.display if pm.display != "" else p.the(), int(pm.target_pressure)])
	Sfx.play("click", p.cell, 0.5)
	Skills.add_xp(bb.e, "atmos", 8.0)
	return ActBase.DONE

static func _atmos_done(bb: CBrain) -> int:
	if bb.inv.headset():
		bb.radio_say("Engineering", Dialogue.pick(["Air plant's maxed.", "Air's set up. Air plant at max.", "Air works are running. Air plant maxed, mix is flowing."]))
	return ActBase.DONE

static func _plan_refill_air(b: CBrain) -> Array:
	var sup: Array = Game.all_with(&"air_supply")
	if sup.is_empty():
		return []
	var s: Entity = sup[0]
	var can: Entity = null
	for t in Game.all_with(&"tank"):
		if (t.proto == "canister_o2" or t.proto == "canister_air") and t.c(&"tank").moles > 100 and t.holder == null:
			can = t
			break
	if can == null:
		return []
	return [Act.GoTo.new(can, true), Act.Pull.new(can), Act.GoTo.new(s, true), Act.StopPull.new(), Act.Do.new(func(bb, _dt): return JobAI._transfer_canister(bb, can, s), "refilling reserves")]

static func _transfer_canister(bb: CBrain, can: Entity, s: Entity) -> int:
	if can.dist_to(s) > 2:
		return ActBase.FAILED
	var tk: CTank = can.c(&"tank")
	var asu: CAirSupply = s.c(&"air_supply")
	if tk.gas == "o2":
		asu.o2_reserve += tk.moles * 10.0
	else:
		asu.o2_reserve += tk.moles * 2.0
		asu.n2_reserve += tk.moles * 8.0
	tk.moles = 0.0
	bb.knowledge.forget("air_low")
	Game.visible_message(s.cell, "%s connects %s to %s." % [bb.e.display_name, can.the(), s.the()])
	return ActBase.DONE

# ============================================================================ medical
static func _medical(b: CBrain, dil: float) -> Array:
	var out := []
	var k := b.knowledge
	var here := b.e.cell
	var patients := []
	for f in k.of_type("person_down") + k.of_type("injured"):
		var p := Game.get_entity(f.get("subject", 0))
		if p == null or p == b.e or p.c(&"health") == null or p.c(&"health").dead:
			continue
		var h: CHealth = p.c(&"health")
		if h.health() > 85 and not h.in_crit() and Body.bleed_rate(h) <= 0.2 and JobAI._worst_wound(h) < 2:
			k.forget(f["key"])
			continue
		if not p in patients:
			patients.append(p)
	patients.sort_custom(func(a, c): return JobAI._triage(a.c(&"health")) > JobAI._triage(c.c(&"health")))
	if not patients.is_empty():
		var p: Entity = patients[0]
		var h2: CHealth = p.c(&"health")
		var s := (640.0 if h2.in_crit() else 330.0 + JobAI._triage(h2) * 3.0) * dil
		s += maxf(0.0, b.affinity(p.id)) * 2.0
		if Game.map.is_outdoor(p.root_cell()) and not b.outdoor_ready():
			s *= 0.6
		out.append(_g("treat", s, "treating %s" % p.display_name, func(): return JobAI._plan_treat(b, p), {"fail_cooldown": 15.0, "keep_pull": true, "claim": "patient:%d" % p.id, "outdoor_ok": true,
			"why": "%s needs help. Now." % Dialogue.first(p) if h2.in_crit() else "Let's get %s patched up." % Dialogue.first(p)}))
	# the recently dead can come back (tg: defib within five minutes)
	for f in k.of_type("body"):
		var corpse := Game.get_entity(f["subject"])
		if corpse == null or corpse.holder != null:
			continue
		var ch: CHealth = corpse.c(&"health")
		if ch == null or not ch.dead or Game.time - ch.time_of_death > 290.0 or ch.missing.has("head"):
			continue
		if b.inv.find_item(func(x): return x.proto == "defib") == null and b.plan_acquire_word("defib") == null:
			continue
		var fresh := 1.0 - (Game.time - ch.time_of_death) / 300.0
		out.append(_g("defib", (560.0 + 250.0 * fresh) * dil, "trying to revive %s" % corpse.display_name, func(): return JobAI._plan_defib(b, corpse),
			{"fail_cooldown": 20.0, "claim": "patient:%d" % corpse.id, "why": "There's still time. Paddles!"}))
		break
	var sick := k.nearest("sick", here)
	if not sick.is_empty():
		var sp := Game.get_entity(sick.get("subject", 0))
		if sp and sp.c(&"health") and sp.c(&"health").disease != null:
			out.append(_g("cure", 300.0 * dil, "curing %s" % sp.display_name, func(): return JobAI._plan_cure(b, sp), {"fail_cooldown": 30.0, "claim": "sick:%d" % sp.id}))
		else:
			k.forget(sick["key"])
	var body := k.nearest("body", here, func(f): return not Game.map.area_at(f["cell"]).name.begins_with("Morgue"))
	if not body.is_empty() and b.job != "chemist":
		var corpse2 := Game.get_entity(body["subject"])
		var morgue := b.area_named("Morgue")
		if corpse2 and morgue and corpse2.holder == null and (Game.time - corpse2.c(&"health").time_of_death > 300.0):
			out.append(_g("move_body", 110.0 * dil, "moving %s's body to the morgue" % corpse2.display_name, func(): return [Act.GoTo.new(corpse2, true), Act.Pull.new(corpse2), Act.GoTo.new(morgue.random_cell(Game.rng), false, false), Act.StopPull.new()], {"keep_pull": true, "fail_cooldown": 60.0, "claim": "body:%d" % corpse2.id}))
	var mon := _console("med")
	if mon:
		out.append(_g("check_monitor", 130.0 * dil, "checking the crew monitor", func(): return JobAI._check_console_plan(mon), {"cooldown": 150.0}))
	if b.job == "chemist":
		out.append(_g("brew", 160.0 * dil, "brewing medicine", func(): return JobAI._plan_brew(b), {"cooldown": 240.0, "fail_cooldown": 120.0}))
	if b.job == "geneticist":
		out.append(_g("sequence", 160.0 * dil, "sequencing genes", func(): return JobAI._plan_sequence(b), {"cooldown": 200.0, "fail_cooldown": 120.0}))
	# a doctor with no gauze or sutures is a doctor with nothing
	var kit_low := b.inv.find_item(func(x): return x.has_c(&"meditem") and x.c(&"meditem").kind in ["gauze", "suture"] and x.c(&"meditem").uses > 0) == null
	if kit_low or not b.has_tag("medical"):
		var get = b.plan_acquire_word("gauze") if kit_low else b.plan_acquire("medical")
		if get == null:
			get = b.plan_acquire_word("medkit")
		if get != null and not get.is_empty():
			out.append(_g("restock", 180.0 * dil, "restocking medical supplies", func(): return get, {"cooldown": 90.0}))
	return out

## How urgently a patient needs a doctor: 0 fine .. 100+ dying.
static func _triage(h: CHealth) -> float:
	var s := (100.0 - h.health())
	s += Body.bleed_rate(h) * 12.0
	s += JobAI._worst_wound(h) * 10.0
	if h.in_crit():
		s += 60.0
	if h.blood_volume < Body.BLOOD_VOLUME_NORMAL * 0.8:
		s += 20.0
	return s

static func _worst_wound(h: CHealth) -> int:
	var w := 0
	for x in h.wounds:
		if x.get("type", "") != "fissure":
			w = maxi(w, int(x.get("sev", 0)))
	return w

## Kit to get out to someone on the glacier: coat, tank, mask. Returns [] if ready, null if we can't.
static func suit_up(b: CBrain):
	if b.outdoor_ready():
		return []
	var plan := []
	var suit: Entity = b.inv.worn("suit")
	if suit == null or suit.c(&"clothing").insulation < 0.3:
		var coat = b.plan_acquire("warm_clothing")
		if coat == null:
			return null
		plan.append_array(coat)
		plan.append(Act.Do.new(func(bb, _dt): return Goals._wear_coat(bb), "putting on a coat"))
	if not b.has_tag("air_tank"):
		var tk = b.plan_acquire("air_tank")
		if tk == null:
			return null
		plan.append_array(tk)
	if b.inv.find_item(func(x): return x.ai_tags().has("breath_mask")) == null:
		var mk = b.plan_acquire("breath_mask")
		if mk == null:
			return null
		plan.append_array(mk)
	return plan

static func _plan_treat(b: CBrain, p: Entity) -> Array:
	var plan := []
	if Game.map.is_outdoor(p.root_cell()):
		var su = JobAI.suit_up(b)
		if su == null:
			return []
		plan.append_array(su)
	var have_kit := b.inv.find_item(func(x): return x.has_c(&"meditem") and x.c(&"meditem").uses > 0 and not x.c(&"meditem").analyzer) != null
	if not have_kit:
		var get = b.plan_acquire("medical")
		if get == null:
			get = b.plan_acquire_word("gauze")
		if get == null:
			return [Act.GoTo.new(p, true, true), Act.Do.new(func(bb, _dt): return Goals._cpr(bb, p), "performing CPR"), Act.Do.new(func(bb, _dt): return Goals._wait_doafter(bb))]
		plan.append_array(get)
	plan.append(Act.GoTo.new(p, true, true))
	plan.append(Act.Do.new(func(bb, dt): return JobAI._treat_step(bb, p, dt), "treating"))
	# someone lying in a corridor goes to Medbay afterwards if they're still in a bad way
	var med := b.area_named("Medbay Treatment")
	if med and Jobs.dept(b.job) == "medical" and Game.map.area_at(p.cell) != med:
		plan.append(Act.Do.new(func(bb, _dt): return JobAI._maybe_carry_to_medbay(bb, p, med), "carrying the patient"))
	return plan

const TREAT_ORDER := ["gauze", "improvised_gauze", "suture", "bone_gel", "surgical_tape", "splint", "bonesetter", "mesh", "ointment", "bruise_pack", ""]

## The right thing from our kit for the worst problem, and where to put it: [item, part] or [].
static func _pick_treatment(bb: CBrain, h: CHealth) -> Array:
	var bleed_part := ""
	var br := 0.25
	for part in Body.PARTS:
		var r := Body.part_bleed_rate(h, part)
		if r > br and not h.gauze.has(part):
			br = r
			bleed_part = part
	var fracture_unsplinted := false
	for w in h.wounds:
		if w.get("type", "") == "bone" and int(w.get("sev", 0)) >= 2 and not h.gauze.has(w.get("part", "")):
			fracture_unsplinted = true
	var kit: Array = bb.inv.all_items().filter(func(x): return x.has_c(&"meditem") and x.c(&"meditem").uses > 0 and not x.c(&"meditem").analyzer)
	var order := Body.PARTS.keys()
	if bleed_part != "":
		order.erase(bleed_part)
		order.push_front(bleed_part)
	for kind in TREAT_ORDER:
		for it in kit:
			var m: CMedItem = it.c(&"meditem")
			if kind == "" and (m.kind != "" or m.heals.is_empty()):
				continue
			if kind != "" and m.kind != kind:
				continue
			if kind in ["gauze", "improvised_gauze"] and bleed_part == "" and not fracture_unsplinted:
				continue # don't wrap healthy limbs
			for part in order:
				if kind in ["gauze", "improvised_gauze"] and part != bleed_part and bleed_part != "":
					continue
				if m._check(h, part) == "":
					return [it, part]
	return []

static func _treat_step(bb: CBrain, p: Entity, dt := 0.0) -> int:
	if not is_instance_valid(p) or p.removed:
		return ActBase.FAILED
	bb.act_t += dt
	var h: CHealth = p.c(&"health")
	if h.dead:
		bb.knowledge.forget("down:%d" % p.id)
		bb.knowledge.forget("injured:%d" % p.id)
		bb.knowledge.learn({"key": "body:%d" % p.id, "type": "body", "subject": p.id, "cell": p.cell, "severity": 5}, Knowledge.SEEN)
		return ActBase.DONE
	if not bb.e.adjacent(p):
		bb.inject_front([Act.GoTo.new(p, true, true)])
		return ActBase.DONE
	if DoAfter.busy(bb.e):
		return ActBase.RUNNING
	if bb.act_t > 90.0:
		return ActBase.DONE
	bb.mob.face(Defs.dir_from_vec(p.cell - bb.e.cell) if p.cell != bb.e.cell else bb.mob.dir)
	# a quick scan first, like any decent doctor
	if not bb.scanned.has(p.id) or Game.time - bb.scanned[p.id] > 60.0:
		bb.scanned[p.id] = Game.time
		var an: Entity = bb.inv.find_item(func(x): return x.has_c(&"meditem") and x.c(&"meditem").analyzer)
		if an:
			bb.ready_item(an)
			Interact.use_item_on(bb.e, an, p)
			bb.say(JobAI._diagnosis(h, p), {"to": p})
			return ActBase.RUNNING
	if h.oxy > 25 and h.in_crit():
		Interact.cpr(bb.e, p)
		return ActBase.RUNNING
	# a heart that's stopped needs the paddles
	if Organs.undergoing_cardiac_arrest(h):
		var defib: Entity = bb.inv.find_item(func(x): return x.proto == "defib")
		if defib:
			bb.ready_item(defib)
			Interact.use_item_on(bb.e, defib, p)
			return ActBase.RUNNING
	var pick := _pick_treatment(bb, h)
	if pick.is_empty():
		if h.health() > 70 or bb.inv.find_item(func(x): return x.has_c(&"meditem") and x.c(&"meditem").uses > 0 and not x.c(&"meditem").analyzer) == null:
			bb.knowledge.forget("down:%d" % p.id)
			bb.knowledge.forget("injured:%d" % p.id)
			if bb.bark_cd <= 0:
				bb.bark(Dialogue.line("patched", bb, {"name": Dialogue.call_name(bb, p)}))
			if h.blood_volume < Body.BLOOD_VOLUME_NORMAL * 0.75:
				bb.say_later(Dialogue.pick(["You've lost a lot of blood. Drink something and take it easy.", "Rest, and drink plenty. Your blood needs to come back."]), 1.5, p)
			return ActBase.DONE
		return ActBase.DONE
	var it: Entity = pick[0]
	var part: String = pick[1]
	bb.mob.aim_at_zone(Body.PARTS[part]["zones"][0])
	bb.ready_item(it)
	Interact.use_item_on(bb.e, it, p)
	Skills.add_xp(bb.e, "medical", 3.0)
	return ActBase.RUNNING

static func _diagnosis(h: CHealth, p: Entity) -> String:
	var bits := []
	if Body.bleed_rate(h) > 1.0:
		bits.append("heavy bleeding")
	elif Body.bleed_rate(h) > 0.2:
		bits.append("some bleeding")
	var ww := JobAI._worst_wound(h)
	for w in h.wounds:
		if w.get("type", "") == "bone" and int(w.get("sev", 0)) >= 2:
			bits.append("a fracture in the %s" % Body.pname(w.get("part", "chest")))
			break
	if h.burn > 20:
		bits.append("burns")
	if h.tox > 15:
		bits.append("toxins in the blood")
	if h.blood_volume < Body.BLOOD_VOLUME_NORMAL * 0.8:
		bits.append("blood loss")
	if bits.is_empty():
		return Dialogue.pick(["Just bruises. You'll live.", "Nothing too serious.", "Scans look okay. Let's clean you up."])
	var s := ", ".join(bits)
	if ww >= 3 or h.in_crit():
		return Dialogue.pick(["This is bad: %s. Hold still." % s, "Okay, %s. Stay with me, %s." % [s, Dialogue.first(p)]])
	return Dialogue.pick(["Scan says %s." % s, "Looks like %s. I can fix that." % s, "Right: %s. Hold still." % s])

static func _maybe_carry_to_medbay(bb: CBrain, p: Entity, med: Area) -> int:
	var h: CHealth = p.c(&"health")
	if h.dead or h.stat() == CHealth.CONSCIOUS or not bb.e.adjacent(p):
		return ActBase.DONE
	var bed_cell := med.random_cell(Game.rng)
	for f in Game.all_with(&"furniture"):
		if f.c(&"furniture").kind in ["bed", "sleeper"] and Game.map.area_at(f.cell) == med and f.c(&"furniture").free_for(p):
			bed_cell = f.cell
			break
	bb.inject_front([Act.Pull.new(p), Act.GoTo.new(bed_cell, false, false), Act.StopPull.new(), Act.Do.new(func(b2, dt): return JobAI._treat_step(b2, p, dt), "treating")])
	return ActBase.DONE

static func _plan_defib(b: CBrain, corpse: Entity) -> Array:
	var plan := []
	if b.inv.find_item(func(x): return x.proto == "defib") == null:
		var get = b.plan_acquire_word("defib")
		if get == null:
			return []
		plan.append_array(get)
	plan.append(Act.GoTo.new(corpse, true, true))
	plan.append(Act.Do.new(func(bb, dt): return JobAI._defib_step(bb, corpse, dt), "defibrillating"))
	return plan

static func _defib_step(bb: CBrain, corpse: Entity, dt: float) -> int:
	if not is_instance_valid(corpse) or corpse.removed:
		return ActBase.FAILED
	var h: CHealth = corpse.c(&"health")
	bb.act_t += dt
	if not h.dead:
		bb.say(Dialogue.pick(["We've got a pulse!", "They're back! Stay with me!", "Heartbeat! Oh thank god."]), {"excited": true})
		bb.learned.note(corpse.id, "brave", 0.0)
		bb.ambition_progress("save_life")
		Bus.chronicle.emit("%s brought %s back from the dead." % [bb.e.display_name, corpse.display_name], 3)
		Bus.stimulus.emit({"type": "rescue", "actor": bb.e, "target": corpse, "cell": corpse.cell, "loud": 3.0})
		bb.knowledge.forget("body:%d" % corpse.id)
		bb.knowledge.learn({"key": "down:%d" % corpse.id, "type": "person_down", "subject": corpse.id, "cell": corpse.cell, "severity": 4}, Knowledge.SEEN)
		return ActBase.DONE
	if Game.time - h.time_of_death > 300.0 or bb.act_t > 40.0:
		bb.say(Dialogue.pick(["...it's no use. They're gone.", "Time of death, %s." % Game.clock_string(), "I'm sorry. I couldn't bring them back."]))
		return ActBase.DONE
	if DoAfter.busy(bb.e):
		return ActBase.RUNNING
	if not bb.e.adjacent(corpse):
		bb.inject_front([Act.GoTo.new(corpse, true, true)])
		return ActBase.RUNNING
	var d: Entity = bb.inv.find_item(func(x): return x.proto == "defib")
	if d == null or d.c(&"gadget").charges <= 0:
		return ActBase.FAILED
	bb.ready_item(d)
	bb.mob.intent = "help"
	if randf() < 0.4:
		bb.say(Dialogue.pick(["Clear!", "Charging... clear!", "Come on, come on..."]), {"excited": true})
	Interact.use_item_on(bb.e, d, corpse)
	return ActBase.RUNNING

static func _plan_cure(b: CBrain, p: Entity) -> Array:
	var plan := []
	if b.inv.find_item(func(x): return x.has_c(&"meditem") and x.c(&"meditem").cures) == null:
		var get = b.plan_acquire("heals_tox")
		if get == null:
			return []
		plan.append_array(get)
	plan.append(Act.GoTo.new(p, true, true))
	plan.append(Act.Do.new(func(bb, _dt): return JobAI._cure_step(bb, p), "administering medicine"))
	return plan

static func _cure_step(bb: CBrain, p: Entity) -> int:
	var pill: Entity = bb.inv.find_item(func(x): return x.has_c(&"meditem") and x.c(&"meditem").cures)
	if pill == null or not bb.e.adjacent(p):
		return ActBase.FAILED
	bb.ready_item(pill)
	Interact.use_item_on(bb.e, pill, p)
	bb.knowledge.forget("sick:%d" % p.id)
	return ActBase.DONE

static func _plan_brew(b: CBrain) -> Array:
	var disp: Entity = null
	for d in Game.all_with(&"reagents"):
		if d.c(&"reagents").kind == "dispenser" and Game.map.area_at(d.cell).name.begins_with("Chemistry"):
			disp = d
	if disp == null:
		return []
	return [Act.GoTo.new(disp, true, false), Act.Wait.new(8.0), Act.Do.new(func(bb, _dt): return JobAI._brew(bb, disp), "bottling medicine")]

## A geneticist's shift at a DNA console (a free one: nobody standing at it).
static func _plan_sequence(b: CBrain) -> Array:
	var best: Entity = null
	var best_d := INF
	for c in Game.all_with(&"dnaconsole"):
		var taken := Game.in_radius(c.cell, 1, &"mob").any(func(x): return x != b.e)
		var d := float((c.cell - b.e.cell).length_squared())
		if not taken and d < best_d:
			best = c
			best_d = d
	if best == null:
		return []
	return [Act.GoTo.new(best, true, false), Act.Wait.new(20.0)]

static func _brew(bb: CBrain, disp: Entity) -> int:
	var skill := Skills.get_skill(bb.e, "chemistry")
	if randf() < 0.08 - skill * 0.007:
		var fx := [{"effect": ["smoke", "toxic", "fire"][randi() % 3], "amount": 10.0}]
		Chem.apply_effects(fx, disp.cell, bb.e)
		Bus.chronicle.emit("A chemistry mishap in %s." % Game.map.area_at(disp.cell).name, 2)
		return ActBase.DONE
	for k in 2:
		Proto.spawn(["bruise_pack", "ointment", "pill_bottle"][randi() % 3], bb.e.cell)
	return ActBase.DONE

# ============================================================================ security
static func _security(b: CBrain, dil: float) -> Array:
	var out := []
	var k := b.knowledge
	# warrants from crimes we believe
	for f in k.of_type("crime"):
		var actor: int = f.get("data", {}).get("actor", 0)
		if actor == 0 or actor == b.e.id or SecurityRecords.is_wanted(actor):
			continue
		if f.get("conf", 1.0) < 0.55 or f.get("severity", 1) < 2:
			continue
		var suspect := Game.get_entity(actor)
		if suspect == null:
			continue
		# a fellow officer only gets a warrant on what we saw ourselves
		if Jobs.dept(suspect.c(&"mob").job) == "security" and f.get("src", 0) != Knowledge.SEEN:
			continue
		var crime: String = f.get("data", {}).get("crime", "crimes")
		out.append(_g("warrant", 360.0 * dil * (0.6 + b.tv("lawfulness") * 0.6), "issuing a warrant for %s" % suspect.display_name, func(): return [Act.Do.new(func(bb, _dt): return JobAI._set_warrant(bb, suspect, crime), "filing a warrant")], {"cooldown": 5.0}))
		break
	# arrests
	for f in k.of_type("wanted"):
		var sid: int = f.get("subject", 0)
		var s2 := Game.get_entity(sid)
		if s2 == null or not SecurityRecords.is_wanted(sid):
			continue
		var sh: CHealth = s2.c(&"health")
		if sh == null or sh.dead or sh.cuffed:
			continue
		var loc := k.where_is(sid)
		if loc.x < 0:
			continue
		var score := (520.0 + (60.0 if s2.dist_to(b.e) < 10 else 0.0)) * dil * (0.5 + b.tv("bravery") * 0.7)
		out.append(_g("arrest", score, "arresting %s" % s2.display_name, func(): return JobAI._plan_arrest(b, s2), {"fail_cooldown": 25.0, "keep_pull": true, "claim": "arrest:%d" % s2.id}))
		break
	# tg: prisoners ride out in the shuttle brig. An officer collects each one; the
	# prisoner then goes to the crawler brig themselves (see Goals, custody).
	var ev: Evac = Game.evac
	if ev and ev.mode == Evac.DOCKED and ev.timer > 45.0 and ev.crawler != null and not ev.crawler.brig_cells.is_empty():
		for pr in JobAI._prisoners():
			out.append(_g("escort", 880.0, "collecting %s for the ferry" % pr.display_name, func(): return JobAI._plan_escort(b, pr), {"fail_cooldown": 20.0, "claim": "escort:%d" % pr.id}))
			break
	# releases
	for id in SecurityRecords.brig_until.keys():
		if Game.time > SecurityRecords.brig_until[id]:
			var pr := Game.get_entity(id)
			if pr:
				out.append(_g("release", 240.0 * dil, "releasing %s" % pr.display_name, func(): return [Act.GoTo.new(pr, true), Act.Do.new(func(bb, _dt): return JobAI._release(bb, pr), "releasing a prisoner")], {"cooldown": 20.0}))
			else:
				SecurityRecords.brig_until.erase(id)
			break
	var rec := _console("sec")
	if rec:
		out.append(_g("check_records", 90.0 * dil, "checking records", func(): return JobAI._check_console_plan(rec), {"cooldown": 200.0}))
	# patrols
	var halls := []
	for a in Game.map.areas:
		if a.name.contains("Hall"):
			halls.append_array(a.cells)
	if not halls.is_empty():
		out.append(_g("patrol", 95.0 * dil, "patrolling", func(): return [Act.Wander.new(halls), Act.Wait.new(4.0)], {"cooldown": 20.0}))
	if not b.has_tag("weapon"):
		var get = b.plan_acquire("weapon")
		if get != null:
			out.append(_g("gear_up", 200.0, "grabbing a baton", func(): return get, {"cooldown": 60.0}))
	elif b.inv.find_item(func(x): return x.has_c(&"gadget") and x.c(&"gadget").kind == "gun") == null:
		var gun = b.plan_acquire_word("disabler")
		if gun != null and not gun.is_empty():
			out.append(_g("gear_up_gun", 150.0 * dil, "grabbing a disabler", func(): return gun, {"cooldown": 120.0, "why": "Better have something with range."}))
	if not b.has_tag("restraint"):
		var cf = b.plan_acquire("restraint")
		if cf != null and not cf.is_empty():
			out.append(_g("gear_up_cuffs", 170.0 * dil, "grabbing cuffs", func(): return cf, {"cooldown": 120.0}))
	# fights in front of an officer get broken up: whoever started it first
	var brawls: Array = k.of_type("crime").filter(func(f): return Game.time - f["t"] <= 20.0 and f.get("data", {}).get("crime", "") == "assault" and f.get("src", 0) == Knowledge.SEEN)
	brawls.sort_custom(func(x, y): return x.get("t0", x["t"]) < y.get("t0", y["t"]))
	for f in brawls:
		var brawler := Game.get_entity(f.get("data", {}).get("actor", 0))
		if brawler and brawler != b.e and brawler.dist_to(b.e) < 9 and brawler.c(&"health").stat() == CHealth.CONSCIOUS and not brawler.c(&"health").cuffed:
			out.append(_g("stop_fight", 720.0 * (0.5 + b.tv("bravery") * 0.6), "breaking up a fight", func(): return [Act.Say.new(Dialogue.line("stop_fight", b, {})), Act.Subdue.new(brawler), Act.Do.new(func(bb, _dt): return JobAI._cuff_step(bb, brawler), "cuffing")],
				{"claim": "arrest:%d" % brawler.id, "fail_cooldown": 15.0, "why": "Not on my watch."}))
			break
	return out

static func _set_warrant(bb: CBrain, suspect: Entity, crime: String) -> int:
	SecurityRecords.set_wanted(suspect, crime, bb.e)
	bb.knowledge.learn({"key": "wanted:%d" % suspect.id, "type": "wanted", "subject": suspect.id, "cell": suspect.cell, "severity": 2}, Knowledge.JOB)
	return ActBase.DONE

static func _plan_arrest(b: CBrain, s: Entity) -> Array:
	var plan: Array = []
	if not b.has_tag("restraint"):
		var cuffs = b.plan_acquire("restraint")
		if cuffs != null:
			plan.append_array(cuffs)
	plan.append_array([Act.Subdue.new(s), Act.Do.new(func(bb, _dt): return JobAI._cuff_step(bb, s), "cuffing"),
		Act.Do.new(func(bb, _dt): return JobAI._search(bb, s), "searching")])
	var brig := b.area_named("Brig")
	if brig:
		var cell := brig.random_cell(Game.rng)
		for f in Game.all_with(&"furniture"):
			if f.c(&"furniture").kind == "bed" and Game.map.area_at(f.cell) == brig:
				cell = f.cell
				break
		plan.append_array([Act.Pull.new(s), Act.GoTo.new(cell, false, false), Act.StopPull.new(), Act.Do.new(func(bb, _dt): return JobAI._jail(bb, s), "booking a prisoner")])
	return plan

static func _cuff_step(bb: CBrain, s: Entity) -> int:
	var h: CHealth = s.c(&"health")
	if h.cuffed:
		bb.mob.combat = false
		return ActBase.DONE
	if not bb.e.adjacent(s):
		# still down (a shove sends them a tile away): walk over; up and running: subdue again
		var down := h.lying() or h.stamcrit or h.incapacitated() or h.stat() != CHealth.CONSCIOUS
		var first: ActBase = Act.GoTo.new(s, true, true) if down else Act.Subdue.new(s)
		bb.inject_front([first, Act.Do.new(func(b2, _dt): return JobAI._cuff_step(b2, s), "cuffing")])
		return ActBase.DONE
	if DoAfter.busy(bb.e):
		return ActBase.RUNNING
	var cuffs: Entity = bb.inv.find_item(func(x): return x.has_c(&"secgear") and x.c(&"secgear").kind == "cuffs")
	if cuffs == null:
		return ActBase.DONE
	bb.ready_item(cuffs)
	cuffs.c(&"secgear").cuff(bb.e, s)
	return ActBase.RUNNING

## Confiscate weapons (and anything they're known to have stolen) off a cuffed suspect.
static func _search(bb: CBrain, s: Entity) -> int:
	if not bb.e.adjacent(s):
		return ActBase.DONE
	var sinv: CInventory = s.c(&"inv")
	if sinv == null:
		return ActBase.DONE
	var took := []
	for it in sinv.all_items():
		if it.ai_tags().has("weapon") and not it.proto in ["flashlight"]:
			Interact.detach(it)
			it.holder = null
			var bag: Entity = bb.inv.worn("back")
			if not (bag and bag.c(&"storage") and bag.c(&"storage").insert(it)):
				it.visible = true
				Game.drop_to_map(it, bb.e.cell)
				it.place(bb.e.cell)
			took.append(it.display_name)
	sinv._refresh()
	if not took.is_empty():
		bb.say("Confiscating %s." % Persona._and_list(took))
		Game.visible_message(s.cell, "%s searches %s and takes %s." % [bb.e.display_name, s.display_name, Persona._and_list(took)], "warn")
	elif randf() < 0.5:
		bb.say(Dialogue.pick(["Clean. Alright.", "Nothing on them.", "Pockets are clear."]))
	return ActBase.DONE

static func _jail(bb: CBrain, s: Entity) -> int:
	SecurityRecords.brig_until[s.id] = Game.time + 150.0
	SecurityRecords.clear(s.id)
	bb.knowledge.forget("wanted:%d" % s.id)
	bb.radio_say("Security", "%s is in the brig. Sentence: a couple of minutes." % s.display_name, {})
	Bus.chronicle.emit("%s was arrested by %s." % [s.display_name, bb.e.display_name], 2)
	return ActBase.DONE

## People security should take to the crawler: serving brig time or cuffed on a warrant,
## alive, and not already on their way.
static func _prisoners() -> Array:
	var out := []
	for m in Game.all_with(&"mob"):
		var h: CHealth = m.c(&"health")
		if h == null or h.dead or m.holder != null or SecurityRecords.escorting.has(m.id):
			continue
		if SecurityRecords.brig_until.has(m.id) or (h.cuffed and SecurityRecords.is_wanted(m.id)):
			out.append(m)
	return out

static func _plan_escort(b: CBrain, pr: Entity) -> Array:
	return [Act.GoTo.new(pr, true, true), Act.Do.new(func(bb, _dt): return JobAI._take_custody(bb, pr), "taking a prisoner")]

static func _take_custody(bb: CBrain, pr: Entity) -> int:
	if not bb.e.adjacent(pr) or pr.c(&"health").dead:
		return ActBase.FAILED
	SecurityRecords.escorting[pr.id] = bb.e.id
	SecurityRecords.brig_until.erase(pr.id)
	bb.say("%s, you're coming with us. Ferry brig, now." % pr.display_name.split(" ")[0])
	Bus.chronicle.emit("%s marched %s to the ferry's brig." % [bb.e.display_name, pr.display_name], 2)
	return ActBase.DONE

static func _release(bb: CBrain, pr: Entity) -> int:
	var h: CHealth = pr.c(&"health")
	if h:
		if h.cuffed:
			# the cuffs come back off and go back on the officer's belt
			var cuffs := Proto.spawn("handcuffs", bb.e.cell)
			if not bb.inv.put_in_hands(cuffs):
				bb.inv.drop(cuffs)
			else:
				bb.stash_active()
		h.cuffed = false
	SecurityRecords.brig_until.erase(pr.id)
	bb.say("Alright %s, you're free to go. Behave." % pr.display_name.split(" ")[0])
	return ActBase.DONE

# ============================================================================ science
static func _science(b: CBrain, dil: float) -> Array:
	var out := []
	var sci := _console("sci")
	if sci and (b.job == "rd" or randf() < 0.5):
		var node := JobAI._next_research()
		if node != "":
			out.append(_g("research", (260.0 if b.job == "rd" else 180.0) * dil, "researching %s" % Research.NODES[node]["name"], func(): return [Act.GoTo.new(sci, true, false), Act.Wait.new(3.0),
				Act.Do.new(func(bb, _dt): return JobAI._do_research(bb, node), "at the ledger engine")], {"cooldown": 60.0, "fail_cooldown": 60.0, "claim": "research", "why": "We've got the points. Let's use them."}))
	out.append(_g("experiment", (170.0 + b.tv("curiosity") * 120.0) * dil, "running an experiment", func(): return JobAI._plan_experiment(b), {"cooldown": 160.0, "fail_cooldown": 90.0}))
	if b.tv("curiosity") > 0.55 and b.tv("bravery") > 0.4:
		var crystal: Entity = null
		for c in Game.all_with(&"light"):
			if c.proto == "ice_crystal" and c.dist_to(b.e) < 60:
				crystal = c
				break
		if crystal:
			out.append(_g("field_study", 110.0 * b.tv("curiosity"), "studying the frostglass crystals outside", func(): return JobAI._plan_field(b, crystal), {"cooldown": 600.0, "fail_cooldown": 300.0, "outdoor_ok": true}))
	return out

static func _next_research() -> String:
	var best := ""
	var bc := 1e9
	for id in Research.NODES:
		if Research.available(id) and Research.cost(id) <= Research.points and Research.cost(id) < bc:
			bc = Research.cost(id)
			best = id
	return best

static func _do_research(bb: CBrain, node: String) -> int:
	if Research.research(node, bb.e):
		Skills.add_xp(bb.e, "science", 30.0)
		if randf() < 0.6:
			bb.say(Dialogue.pick(["Yes! %s is done." % Research.NODES[node]["name"], "Another node down.", "Science marches on."]))
		return ActBase.DONE
	return ActBase.FAILED

static func _plan_experiment(b: CBrain) -> Array:
	var disp: Entity = null
	for d in Game.all_with(&"reagents"):
		if d.c(&"reagents").kind == "dispenser" and Game.map.area_at(d.cell) in b.work_areas():
			disp = d
			break
	if disp == null:
		return []
	return [Act.GoTo.new(disp, true, false), Act.Wait.new(6.0), Act.Do.new(func(bb, _dt): return JobAI._experiment(bb, disp), "mixing chemicals")]

static func _experiment(bb: CBrain, disp: Entity) -> int:
	## Careful, skilled scientists mix known recipes; curious or sloppy ones improvise.
	var skill := Skills.get_skill(bb.e, "chemistry") + Skills.get_skill(bb.e, "science") * 0.5
	var reckless := bb.tv("curiosity") * 0.6 + (1.0 - bb.tv("diligence")) * 0.4
	var mix := {}
	if randf() < reckless * 0.45 - skill * 0.03:
		var pool := Chem.DISPENSABLE.duplicate()
		pool.shuffle()
		for k in randi_range(2, 3):
			mix[pool[k]] = randf_range(5.0, 15.0)
	else:
		var safe := [{"carbon": 10, "iron": 10, "sugar": 10}, {"silicon": 10, "carbon": 10}, {"water": 10, "silicon": 10, "plasma": 5}]
		mix = safe[randi() % safe.size()].duplicate()
	var fx := Chem.react(mix)
	Research.experiments_run += 1
	Research.points += 10.0 + skill * 2.0 + fx.size() * 15.0
	if not fx.is_empty():
		var dangerous := fx.any(func(x): return x["effect"] in ["explosion", "fire", "toxic", "smoke", "freeze"])
		if dangerous:
			Research.accidents += 1
			Bus.chronicle.emit("%s's experiment went wrong in %s." % [bb.e.display_name, Game.map.area_at(disp.cell).name], 3)
			bb.say(Dialogue.line("oops", bb, {}))
		Chem.apply_effects(fx, disp.cell, bb.e)
	return ActBase.DONE

static func _plan_field(b: CBrain, crystal: Entity) -> Array:
	var plan := []
	var inv := b.inv
	if inv.worn("suit") == null or inv.worn("suit").c(&"clothing").insulation < 0.3:
		var coat = b.plan_acquire("warm_clothing")
		if coat == null:
			return []
		plan.append_array(coat)
		plan.append(Act.Do.new(func(bb, _dt): return Goals._wear_coat(bb), "putting on a coat"))
	plan.append(Act.GoTo.new(crystal, true, false))
	plan.append(Act.Wait.new(6.0))
	plan.append(Act.Do.new(func(bb, _dt): return JobAI._sample(bb), "taking samples"))
	plan.append_array(Goals._plan_inside(b))
	return plan

static func _sample(_bb: CBrain) -> int:
	Research.points += 40.0
	return ActBase.DONE

# ============================================================================ service
static func _service(b: CBrain, dil: float) -> Array:
	var out := []
	match b.job:
		"cook":
			var caf := b.area_named("Cafeteria")
			var stock := 0
			if caf:
				for c in caf.cells:
					for it in Game.at(c):
						if it.has_c(&"food") and not it.c(&"food").ingredient and not it.c(&"food").drink:
							stock += 1
			if stock < 4:
				out.append(_g("cook", (300.0 - stock * 50.0) * dil, "cooking a meal", func(): return JobAI._plan_cook(b), {"cooldown": 20.0, "fail_cooldown": 60.0}))
		"botanist":
			var tray := _nearest_with(b, "hydro", func(t): return t.c(&"hydro").needs_care())
			if tray:
				out.append(_g("garden", 240.0 * dil, "tending the plants", func(): return JobAI._plan_garden(b, tray), {"fail_cooldown": 30.0}))
			var produce := _nearest_with(b, "food", func(t): return t.c(&"food").ingredient and t.holder == null and Game.map.area_at(t.cell).name.begins_with("Hydroponics"))
			if produce:
				out.append(_g("deliver_produce", 170.0 * dil, "bringing produce to the kitchen", func(): return JobAI._plan_deliver_produce(b, produce), {"fail_cooldown": 60.0}))
		"janitor":
			var mess := b.knowledge.nearest("mess", b.e.cell)
			if not mess.is_empty():
				var md := Game.get_entity(mess["subject"])
				if md:
					out.append(_g("clean", (200.0 + mess.get("severity", 1) * 60.0) * dil, "mopping up %s" % md.display_name, func(): return JobAI._plan_clean(b, md), {"fail_cooldown": 30.0, "claim": "mess:%d" % md.id}))
				else:
					b.knowledge.forget(mess["key"])
			var halls := []
			for a in Game.map.areas:
				if a.name.contains("Hall"):
					halls.append_array(a.cells)
			out.append(_g("rounds", 80.0 * dil, "doing the rounds", func(): return [Act.Wander.new(halls)], {"cooldown": 15.0}))
		"bartender":
			var bar := b.area_named("Bar")
			if bar == null:
				bar = b.area_named("Cafeteria")
			if bar:
				out.append(_g("tend_bar", 110.0 * dil, "tending the bar", func(): return [Act.Wander.new(bar.cells), Act.Wait.new(6.0), Act.Do.new(func(bb, _dt): return JobAI._bar_talk(bb), "polishing a glass")], {"cooldown": 10.0}))
		"clown":
			if b.has_tag("food") and b.inv.find_item(func(x): return x.proto == "food_banana") != null:
				out.append(_g("prank", 150.0 * b.tv("humor"), "planning a prank", func(): return JobAI._plan_prank(b), {"cooldown": 400.0}))
	return out

static func _bar_talk(bb: CBrain) -> int:
	bb.mob.emote(Dialogue.pick(["polishes a glass.", "wipes down the bar.", "lines up the bottles.", "checks the taps."]))
	for m in Game.in_radius(bb.e.cell, 3, &"mob"):
		if m != bb.e and m.c(&"health").stat() == CHealth.CONSCIOUS and randf() < 0.35:
			if m.has_c(&"brain"):
				if bb.convo == null and bb.start_conversation(m) and bb.convo != null:
					bb.inject_front([Act.Chat.new(bb.convo)])
			else:
				bb.say(Dialogue.pick(["What'll it be?", "Rough watch? First one's on me.", "You look like you need a drink.", "Anything to drink?"]), {"to": m})
			break
	return ActBase.DONE

static func _nearest_with(b: CBrain, comp: String, pred: Callable) -> Entity:
	var best: Entity = null
	var bd := 1e9
	for t in Game.all_with(StringName(comp)):
		if t.holder != null or not pred.call(t):
			continue
		var d = t.dist_to(b.e)
		if d < bd:
			bd = d
			best = t
	return best

static func _plan_cook(b: CBrain) -> Array:
	var fridge: Entity = null
	var mw: Entity = null
	for s in Game.all_with(&"storage"):
		if s.proto == "fridge":
			fridge = s
	for c in Game.all_with(&"cooker"):
		if c.proto == "microwave":
			mw = c
	if fridge == null or mw == null:
		return []
	var st: CStorage = fridge.c(&"storage")
	var ing := []
	for it in st.contents:
		if it.has_c(&"food") and it.c(&"food").ingredient and ing.size() < 2:
			ing.append(it)
	if ing.is_empty() and st.is_open:
		for it in Game.at(fridge.cell):
			if it.has_c(&"food") and it.c(&"food").ingredient and ing.size() < 2:
				ing.append(it)
	if ing.is_empty():
		if not b.knowledge.has("req:ingredients"):
			b.knowledge.learn({"key": "req:ingredients", "type": "supply_request", "cell": fridge.cell, "severity": 1}, Knowledge.FELT)
			return [Act.Say.new("We're out of ingredients in the galley. Growers, hold, anything?", "Service", {}), Act.Do.new(func(_bb, _dt): return JobAI._request_food(_bb), "")]
		return []
	var plan: Array = [Act.GoTo.new(fridge, true, false), Act.Do.new(func(bb, _dt): return JobAI._open(bb, fridge), "opening the fridge")]
	for it in ing:
		plan.append(Act.PickUp.new(it))
	plan.append(Act.Do.new(func(bb, _dt): return JobAI._close(bb, fridge), "closing the fridge"))
	plan.append(Act.GoTo.new(mw, true, false))
	for it in ing:
		plan.append(Act.UseOn.new(it, mw))
	plan.append(Act.Hand.new(mw))
	plan.append(Act.Wait.new(9.0))
	plan.append(Act.Do.new(func(bb, _dt): return JobAI._collect_meal(bb, mw), "plating the meal"))
	var caf := b.area_named("Cafeteria")
	if caf:
		var counter_cell := caf.center
		for t in Game.all_with(&"furniture"):
			if t.proto == "counter" and Game.map.area_at(t.cell) == caf:
				counter_cell = t.cell
				break
		plan.append(Act.GoTo.new(counter_cell, true, false))
		plan.append(Act.Do.new(func(bb, _dt): return JobAI._serve(bb, counter_cell), "serving"))
	return plan

static func _request_food(bb: CBrain) -> int:
	Cargo.request("kitchen ingredients", "service", bb.e)
	return ActBase.DONE

static func _open(bb: CBrain, box: Entity) -> int:
	var st: CStorage = box.c(&"storage")
	if not st.is_open:
		if st.locked and not st.toggle_lock(bb.e): return ActBase.FAILED
		if not st.open(bb.e): return ActBase.FAILED
	return ActBase.DONE

static func _close(bb: CBrain, box: Entity) -> int:
	var st: CStorage = box.c(&"storage")
	if st.is_open:
		st.close(bb.e)
	return ActBase.DONE

static func _collect_meal(bb: CBrain, mw: Entity) -> int:
	if mw.c(&"cooker").cooking > 0:
		return ActBase.RUNNING
	for it in Game.at(mw.cell):
		if it.has_c(&"food") and not it.c(&"food").ingredient:
			if bb.inv.free_hand() < 0:
				bb.stash_active()
			Interact.pickup(bb.e, it)
			return ActBase.DONE
	return ActBase.DONE

static func _serve(bb: CBrain, cell: Vector2i) -> int:
	var meal: Entity = bb.inv.find_item(func(x): return x.has_c(&"food") and not x.c(&"food").ingredient)
	if meal:
		bb.inv.drop(meal, cell)
		if randf() < 0.4:
			bb.say(Dialogue.line("order_up", bb, {"food": meal.display_name}))
	return ActBase.DONE

static func _plan_garden(b: CBrain, tray: Entity) -> Array:
	return [Act.GoTo.new(tray, true, false), Act.Hand.new(tray)]

static func _plan_deliver_produce(b: CBrain, produce: Entity) -> Array:
	var fridge: Entity = null
	for s in Game.all_with(&"storage"):
		if s.proto == "fridge":
			fridge = s
	if fridge == null:
		return []
	return [Act.GoTo.new(produce, true), Act.PickUp.new(produce), Act.GoTo.new(fridge, true), Act.Do.new(func(bb, _dt): return JobAI._stock_fridge(bb, fridge), "stocking the fridge")]

static func _stock_fridge(bb: CBrain, fridge: Entity) -> int:
	var st: CStorage = fridge.c(&"storage")
	for it in bb.inv.all_items(false):
		if it.has_c(&"food") and it.c(&"food").ingredient:
			bb.inv.remove_ref(it)
			it.holder = null
			if not st.insert(it):
				bb.inv.drop(it)
	return ActBase.DONE

static func _plan_clean(b: CBrain, mess: Entity) -> Array:
	var plan := []
	if not b.has_tool("mop"):
		var get = b.plan_acquire("tool_mop")
		if get == null:
			return []
		plan.append_array(get)
	plan.append(Act.GoTo.new(mess, true, false))
	plan.append(Act.UseOn.new("mop", mess))
	plan.append(Act.Do.new(func(bb, _dt): return JobAI._forget_mess(bb, mess), ""))
	return plan

static func _forget_mess(bb: CBrain, mess: Entity) -> int:
	bb.knowledge.forget("mess:%d" % (mess.id if is_instance_valid(mess) else 0))
	return ActBase.DONE

static func _plan_prank(b: CBrain) -> Array:
	var banana: Entity = b.inv.find_item(func(x): return x.proto == "food_banana")
	var halls := []
	for a in Game.map.areas:
		if a.name.contains("Hall"):
			halls.append_array(a.cells)
	if banana == null or halls.is_empty():
		return []
	return [Act.Consume.new(banana), Act.Wander.new(halls), Act.Do.new(func(bb, _dt): return JobAI._drop_peel(bb), "leaving a surprise")]

static func _drop_peel(bb: CBrain) -> int:
	var peel: Entity = bb.inv.find_item(func(x): return x.proto == "banana_peel")
	if peel:
		bb.inv.drop(peel)
		bb.say(Dialogue.line("honk", bb, {}))
	return ActBase.DONE

# ============================================================================ supply
static func _supply(b: CBrain, dil: float) -> Array:
	var out := []
	if b.job == "miner":
		var storm = Game.director != null and Game.director.storm > 0.5
		var outside := Game.map.is_outdoor(b.e.cell)
		if storm and outside and b.tv("bravery") < 0.85:
			out.append(_g("storm_retreat", 620.0, "getting out of the storm", func(): return Goals._plan_inside(b)))
		elif not storm and b.needs.energy > 25:
			out.append(_g("mine", 230.0 * dil, "digging out on the island", func(): return JobAI._plan_mine(b), {"cooldown": 60.0, "fail_cooldown": 120.0, "outdoor_ok": true}))
		# bring ore home
		var ore_count := b.inv.all_items().filter(func(x): return x.ai_tags().has("ore")).size()
		if ore_count >= 3:
			var dock := b.area_named("Mining Dock")
			if dock:
				out.append(_g("haul_ore", 300.0 * dil, "hauling ore back", func(): return [Act.GoTo.new(dock.random_cell(Game.rng), false, false), Act.Do.new(func(bb, _dt): return JobAI._drop_ore(bb), "unloading ore")], {"outdoor_ok": true}))
	else:
		var ore := _nearest_with(b, "item", func(t): return t.ai_tags().has("ore") and Game.map.area_at(t.cell).name.begins_with("Mining Dock"))
		var con := _nearest_with(b, "console", func(t): return t.c(&"console").kind == "cargo" and b.may_enter(Game.map.area_at(t.cell)))
		if ore and con:
			out.append(_g("sell_ore", 170.0 * dil, "processing ore", func(): return [Act.GoTo.new(ore, true), Act.PickUp.new(ore), Act.GoTo.new(con, true), Act.Do.new(func(bb, _dt): return JobAI._sell(bb), "processing ore")], {"fail_cooldown": 30.0}))
		# order what the station is short of, and bring the crawler in
		var want := JobAI._supply_needs()
		var hauling := JobAI._stray_crate(b) != null or (Cargo.state == Cargo.DOCKED and JobAI._crate_aboard() != null)
		if con and not want.is_empty() and Cargo.orders.is_empty() and Cargo.state == Cargo.AWAY and not hauling:
			out.append(_g("order_supplies", (340.0 + want.size() * 40.0) * dil, "ordering supplies", func(): return [Act.GoTo.new(con, true, false), Act.Wait.new(2.0),
				Act.Do.new(func(bb, _dt): return JobAI._place_orders(bb, want), "at the hold ledger")], {"cooldown": 60.0, "fail_cooldown": 60.0, "claim": "cargo_order",
				"why": "People are going hungry. Get a crate in."}))
		# a delivery left half-way (someone got called away) still needs finishing
		var stray := JobAI._stray_crate(b)
		if stray:
			out.append(_g("unload", 350.0 * dil, "finishing a delivery", func(): return JobAI._plan_unload(b, stray), {"cooldown": 5.0, "fail_cooldown": 30.0, "keep_pull": true, "claim": "crate:%d" % stray.id,
				"why": "That crate's not going to deliver itself."}))
		# the crawler's in: unload it
		if Cargo.state == Cargo.DOCKED:
			var crate := JobAI._crate_aboard()
			if crate:
				out.append(_g("unload", 360.0 * dil, "unloading the supply ferry", func(): return JobAI._plan_unload(b, crate), {"cooldown": 5.0, "fail_cooldown": 30.0, "keep_pull": true, "claim": "crate:%d" % crate.id,
					"outdoor_ok": true, "why": "Crates don't carry themselves."}))
			elif con and Cargo.orders.is_empty():
				out.append(_g("send_crawler", 200.0 * dil, "sending the ferry back", func(): return [Act.GoTo.new(con, true, false), Act.Do.new(func(bb, _dt): return JobAI._send_crawler(bb), "at the hold ledger")],
					{"cooldown": 60.0, "claim": "cargo_send"}))
		# requests the ordering above doesn't cover (food is ordered, not scrounged)
		var others: Array = Cargo.requests.filter(func(r): return not (r["what"].contains("ingredient") or r["what"].contains("food")))
		if not others.is_empty():
			var r: Dictionary = others[0]
			out.append(_g("fulfil", 230.0 * dil, "fulfilling a supply request", func(): return JobAI._plan_fulfil(b, r), {"cooldown": 30.0, "fail_cooldown": 90.0}))
	return out

## What the station is running short of, as cargo pack ids.
static func _supply_needs() -> Array:
	var out := []
	var hungry := 0
	var thirsty := 0
	for m in Game.all_with(&"brain"):
		var n: CNeeds = m.c(&"needs")
		if n.nutrition < 35.0:
			hungry += 1
		if n.hydration < 30.0:
			thirsty += 1
	var kitchen_empty := false
	for r in Cargo.requests:
		if r["what"].contains("ingredient") or r["what"].contains("food"):
			kitchen_empty = true
	if kitchen_empty or hungry >= 4:
		out.append("food")
	if hungry >= 3:
		out.append("rations")
	if thirsty >= 4:
		out.append("coffee")
	return out.filter(func(id): return Cargo.PACKS.has(id))

static func _place_orders(bb: CBrain, want: Array) -> int:
	var got := []
	for id in want:
		if Cargo.order(id, bb.e):
			got.append(Cargo.PACKS[id]["name"])
	if got.is_empty():
		return ActBase.FAILED
	Cargo.call_shuttle(bb.e)
	for r in Cargo.requests.duplicate():
		if r["what"].contains("ingredient") or r["what"].contains("food"):
			Cargo.requests.erase(r)
	bb.radio_say("Supply", "Ordered %s. Ferry's on its way." % Persona._and_list(got))
	if bb.inv.headset() and "Service" in bb.inv.headset().channels:
		bb.radio_say("Service", "Food's coming, kitchen. Hang in there.")
	return ActBase.DONE

## A delivered crate with food still in it, sitting somewhere it doesn't belong.
static func _stray_crate(b: CBrain) -> Entity:
	for x in Game.all_with(&"storage"):
		if x.holder != null or not x.proto.contains("crate") or x.c(&"storage").contents.is_empty():
			continue
		if not x.c(&"storage").contents.any(func(it): return it.has_c(&"food")):
			continue
		var a := Game.map.area_at(x.cell)
		if x.cell in Cargo.pad_cells() or a.outdoor:
			continue
		# only crates the supply crawler brought (a pack's name), not whatever else is lying around
		if not Cargo.PACKS.values().any(func(pk): return pk["name"] == x.display_name):
			continue
		if x.dist_to(b.e) < 60:
			return x
	return null

static func _crate_aboard() -> Entity:
	for c in Cargo.pad_cells():
		for x in Game.at(c):
			if x.has_c(&"storage") and x.proto.contains("crate") and x.holder == null and not x.c(&"storage").contents.is_empty():
				return x
	return null

## Where a crate's contents belong: ingredients to the kitchen fridge, ready food to the
## cafeteria, anything else to the cargo bay.
static func _crate_home(crate: Entity) -> Area:
	var st: CStorage = crate.c(&"storage")
	var ingredients := 0
	var meals := 0
	for it in st.contents:
		if it.has_c(&"food"):
			if it.c(&"food").ingredient:
				ingredients += 1
			else:
				meals += 1
	var kitchen: Area = null
	var caf: Area = null
	var bay: Area = null
	for a in Game.map.areas:
		if a.name.begins_with("Kitchen") and kitchen == null:
			kitchen = a
		elif a.name.begins_with("Cafeteria") and caf == null:
			caf = a
		elif a.name.begins_with("Cargo Bay") and bay == null:
			bay = a
	if ingredients > 0 and ingredients >= meals:
		return kitchen if kitchen else caf
	if meals > 0:
		return caf if caf else kitchen
	return bay

static func _plan_unload(b: CBrain, crate: Entity) -> Array:
	var home := JobAI._crate_home(crate)
	if home == null:
		return []
	# already where it belongs: just unpack it
	if Game.map.area_at(crate.cell) == home:
		return [Act.GoTo.new(crate, true, false), Act.Do.new(func(bb, _dt): return JobAI._unpack(bb, crate, home), "unpacking")]
	var cell := home.random_cell(Game.rng)
	for k in 10:
		if Game.map.is_passable(cell) and not Game.at(cell).any(func(x): return x.has_c(&"blocker") and x.c(&"blocker").dense):
			break
		cell = home.random_cell(Game.rng)
	return [Act.GoTo.new(crate, true, true), Act.Pull.new(crate), Act.GoTo.new(cell, false, true), Act.StopPull.new(),
		Act.Do.new(func(bb, _dt): return JobAI._unpack(bb, crate, home), "unpacking")]

static func _unpack(bb: CBrain, crate: Entity, home: Area) -> int:
	if not is_instance_valid(crate) or crate.removed:
		return ActBase.FAILED
	var st: CStorage = crate.c(&"storage")
	var fridge: Entity = null
	for s in Game.all_with(&"storage"):
		if s.proto == "fridge" and Game.map.area_at(s.cell) == home:
			fridge = s
	var n := 0
	for it in st.contents.duplicate():
		st.remove(it)
		it.holder = null
		if fridge and it.has_c(&"food") and it.c(&"food").ingredient and fridge.c(&"storage").insert(it):
			n += 1
			continue
		it.visible = true
		Game.drop_to_map(it, crate.cell)
		it.place(crate.cell)
		n += 1
	Game.visible_message(crate.cell, "%s unpacks %s." % [bb.e.display_name, crate.the()])
	var what := "Kitchen" if home.name.begins_with("Kitchen") else home.name
	bb.radio_say("Service" if bb.inv.headset() and "Service" in bb.inv.headset().channels else "Supply", "Delivery for %s: %d things unpacked." % [what, n])
	# everyone who wanders past knows there's food now
	for m in Game.in_radius(crate.cell, 10, &"brain"):
		for it2 in Game.at(crate.cell):
			if it2.has_c(&"item"):
				m.c(&"brain").remember_item(it2, Knowledge.SEEN)
	return ActBase.DONE

static func _send_crawler(bb: CBrain) -> int:
	if Cargo.state != Cargo.DOCKED:
		return ActBase.DONE
	Cargo.send_shuttle(bb.e)
	return ActBase.DONE

static func _plan_mine(b: CBrain) -> Array:
	var plan := []
	var inv := b.inv
	if inv.worn("suit") == null or inv.worn("suit").c(&"clothing").insulation < 0.3:
		var coat = b.plan_acquire("warm_clothing")
		if coat != null:
			plan.append_array(coat)
			plan.append(Act.Do.new(func(bb, _dt): return Goals._wear_coat(bb), "suiting up"))
	if not b.has_tag("air_tank"):
		var tk = b.plan_acquire("air_tank")
		if tk == null:
			return []
		plan.append_array(tk)
	if not b.has_tool("dig"):
		var pick = b.plan_acquire("tool_dig")
		if pick == null:
			return []
		plan.append_array(pick)
	# nearest ore-bearing rock (miners know the survey maps)
	var map := Game.map
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for k in 600:
		var c := Vector2i(randi_range(0, map.w - 1), randi_range(0, map.h - 1))
		var t := map.get_turf(c)
		if t in [Defs.T_ROCK_IRON, Defs.T_ROCK_PLASMA, Defs.T_ROCK_CRYO, Defs.T_ROCK_GOLD]:
			var open := false
			for d in Defs.DIRS4:
				if map.is_outdoor(c + d):
					open = true
			if open:
				var dd := Vector2(c - b.e.cell).length()
				if dd < bd:
					bd = dd
					best = c
	if best.x < 0:
		return []
	plan.append(Act.GoTo.new(best, true, true))
	plan.append(Act.UseOnTile.new("dig", best))
	plan.append(Act.Do.new(func(bb, _dt): return JobAI._collect_ore(bb, best), "collecting ore"))
	return plan

static func _collect_ore(bb: CBrain, c: Vector2i) -> int:
	for it in Game.at(c).duplicate():
		if it.ai_tags().has("ore"):
			if bb.inv.free_hand() < 0:
				bb.stash_active()
			if not Interact.pickup(bb.e, it):
				break
			bb.stash_active()
	return ActBase.DONE

static func _drop_ore(bb: CBrain) -> int:
	for it in bb.inv.all_items():
		if it.ai_tags().has("ore"):
			Interact.detach(it)
			it.holder = bb.e
			bb.inv.drop(it)
	return ActBase.DONE

static func _sell(bb: CBrain) -> int:
	for it in bb.inv.all_items(false):
		if it.ai_tags().has("ore"):
			var v := Cargo.sell(it)
			bb.inv.remove_ref(it)
			it.destroy()
			if v > 0 and randf() < 0.3:
				bb.say("That's another %d points for the Guild." % v)
	return ActBase.DONE

static func _plan_fulfil(b: CBrain, r: Dictionary) -> Array:
	var dept_area: Area = null
	for a in Game.map.areas:
		if a.dept == r["dept"] and a.cells.size() > 8:
			dept_area = a
			break
	var bay := b.area_named("Cargo Bay")
	if dept_area == null or bay == null:
		Cargo.requests.erase(r)
		return []
	var crate: Entity = null
	for s in Game.all_with(&"storage"):
		if s.proto == "crate" and Game.map.area_at(s.cell) == bay and s.holder == null:
			crate = s
			break
	if crate == null:
		Cargo.requests.erase(r)
		return []
	return [Act.GoTo.new(crate, true), Act.Pull.new(crate), Act.GoTo.new(dept_area.random_cell(Game.rng), false, false), Act.StopPull.new(),
		Act.Do.new(func(bb, _dt): return JobAI._delivered(bb, r), "delivering")]

static func _delivered(bb: CBrain, r: Dictionary) -> int:
	Cargo.requests.erase(r)
	bb.radio_say("Supply", "Delivered %s to %s." % [r["what"], Defs.DEPARTMENTS.get(r["dept"], {}).get("name", r["dept"])], {})
	return ActBase.DONE

# ============================================================================ command
static func _command(b: CBrain, dil: float) -> Array:
	var out := []
	var k := b.knowledge
	# direct departments during emergencies
	for f in k.facts.values():
		if f.get("ordered", false) or f.get("severity", 0) < 3:
			continue
		if not f["type"] in ["reactor_hot", "fire", "breach", "person_down", "body", "crime", "power_out"]:
			continue
		if Game.time - f["t"] > 90.0:
			continue
		var target_dept = {"reactor_hot": "engineering", "fire": "engineering", "breach": "engineering", "power_out": "engineering",
			"person_down": "medical", "body": "medical", "crime": "security"}[f["type"]]
		if Jobs.dept(b.job) != "command" and Jobs.dept(b.job) != target_dept:
			continue
		var ff: Dictionary = f
		out.append(_g("give_order", 330.0 * dil * (0.6 + b.tv("diligence") * 0.5), "coordinating the response", func(): return JobAI._plan_order(b, ff, target_dept), {"cooldown": 20.0}))
		break
	if b.job == "captain":
		var deaths := k.of_type("body").size()
		var bad = deaths > 0 or not k.of_type("crime").filter(func(f): return f.get("severity", 0) >= 3).is_empty() or k.get_fact("reactor_hot").get("severity", 0) >= 2
		if bad and Game.alert_level < 2:
			out.append(_g("red_alert", 300.0, "raising the alert state", func(): return JobAI._plan_alert(b, 2), {"cooldown": 600.0}))
		elif not bad and Game.alert_level >= 2 and k.of_type("fire").is_empty():
			out.append(_g("stand_down", 120.0, "lowering the alert state", func(): return JobAI._plan_alert(b, 0), {"cooldown": 600.0}))
		var mon := _console("med")
		if mon:
			out.append(_g("check_crew", 90.0 * dil, "checking on the crew", func(): return JobAI._check_console_plan(mon), {"cooldown": 240.0}))
		# abandon ship: enough bodies, or a reactor on the edge of meltdown
		var rh := k.get_fact("reactor_hot")
		var meltdown = rh.get("severity", 0) >= 2 and rh.get("data", {}).get("integrity", 100.0) < 40.0
		if (deaths >= 4 or meltdown) and Game.evac and Game.evac.can_call() == "":
			var why := "Reactor meltdown imminent." if meltdown else "Multiple crew fatalities. Ship unsafe."
			out.append(_g("call_evac", 460.0, "calling the relief ferry", func(): return JobAI._plan_call_evac(b, why), {"cooldown": 300.0}))
	return out

static func _plan_call_evac(b: CBrain, why: String) -> Array:
	var comms := _console("comms")
	if comms == null:
		return []
	return [Act.GoTo.new(comms, true, true), Act.Do.new(func(bb, _dt): return ActBase.DONE if Game.evac.request_by(bb.e, why) else ActBase.FAILED, "using the comms console"),
		Act.Say.new("I've called the ferry. Everyone get to the departure quay when it arrives.", "Common")]

static var _orders_given := {} # fact key -> time: one head gives each order

static func _plan_order(b: CBrain, f: Dictionary, dept: String) -> Array:
	f["ordered"] = true
	if Game.time - _orders_given.get(f["key"], -999.0) < 240.0:
		return []
	_orders_given[f["key"]] = Game.time
	var text := Dialogue.order_line(b, f, dept)
	var order := {"key": "order:%s:%d" % [f["key"], int(Game.time)], "type": "order", "cell": f.get("cell", Vector2i.ZERO), "severity": f.get("severity", 2), "data": {"to": dept, "about": f["key"]}}
	return [Act.Say.new(text, Defs.DEPARTMENTS[dept]["radio"], order)]

static func _plan_alert(b: CBrain, level: int) -> Array:
	var comms := _console("comms")
	if comms == null:
		return []
	return [Act.GoTo.new(comms, true, true), Act.Do.new(func(bb, _dt): return JobAI._set_alert(bb, level), "using the comms console")]

static func _set_alert(bb: CBrain, level: int) -> int:
	Game.set_alert(level, "By order of %s." % bb.e.display_name)
	return ActBase.DONE

# ============================================================================ civilians
static func _civilian(b: CBrain, dil: float) -> Array:
	var out := []
	if b.job == "assistant":
		# greytide: the bored and rule-bending help themselves to tools
		if b.tv("lawfulness") < 0.35 and not b.has_tag("tool"):
			var get = b.plan_acquire("tool")
			if get != null:
				out.append(_g("borrow_tools", 70.0 * (1.0 - b.tv("lawfulness")), "borrowing some tools", func(): return get, {"cooldown": 600.0}))
		if b.tv("curiosity") > 0.7 and b.tv("bravery") > 0.55 and not (Game.director and Game.director.storm > 0.3):
			out.append(_g("sightsee", 60.0 * b.tv("curiosity"), "going out to see the sky", func(): return JobAI._plan_sightsee(b), {"cooldown": 900.0, "outdoor_ok": true}))
	return out

static func _plan_sightsee(b: CBrain) -> Array:
	var ex: Array = Game.all_with(&"door").filter(func(d): return d.c(&"door").external)
	if ex.is_empty():
		return []
	var d: Entity = ex[randi() % ex.size()]
	var out_cell := d.cell
	for dir in Defs.DIRS4:
		if Game.map.is_outdoor(d.cell + dir):
			out_cell = d.cell + dir * 4
	return [Act.GoTo.new(out_cell, false, false), Act.Wait.new(12.0)]

# ============================================================================ traitors
static func _witnesses(b: CBrain) -> int:
	var n := 0
	for m in Game.in_radius(b.e.cell, 7, &"mob"):
		if m == b.e:
			continue
		var h: CHealth = m.c(&"health")
		if h and h.stat() == CHealth.CONSCIOUS and b._los(b.e.cell, m.cell):
			n += 1
	return n

static func _antag(b: CBrain) -> Array:
	var out := []
	var obj: Dictionary = b.antag
	if obj.get("done", false):
		return out
	match obj.get("kind", ""):
		"sabotage":
			var c: Vector2i = obj["cell"]
			out.append(_g("antag", 280.0 + b.tv("diligence") * 60.0, "doing some 'maintenance'", func(): return JobAI._plan_sabotage(b, c), {"cooldown": 90.0, "fail_cooldown": 120.0}))
		"steal":
			var target := Game.get_entity(obj.get("target", 0))
			if target == null or target.removed:
				obj["done"] = true
			elif target.root() == b.e:
				obj["done"] = true
				Bus.chronicle.emit("%s quietly completed a secret objective." % b.e.display_name, 1)
			else:
				out.append(_g("antag", 260.0, "looking for something", func(): return JobAI._plan_steal(b, target), {"cooldown": 90.0, "fail_cooldown": 150.0}))
		"kill":
			var mark := Game.get_entity(obj.get("target", 0))
			if mark == null or mark.c(&"health").dead:
				obj["done"] = true
				if mark:
					b.remember_thought("It's done. Stay calm. Act normal.")
					Bus.chronicle.emit("%s quietly completed a secret objective." % b.e.display_name, 1)
			else:
				var armed := b.inv.find_item(func(x): return x.ai_tags().has("weapon") or x.ai_tags().has("tool_crowbar") or x.proto.contains("toolbox") or x.proto.contains("knife")) != null
				if not armed:
					var get = b.plan_acquire("weapon")
					if get == null:
						get = b.plan_acquire("tool_crowbar")
					if get != null and not get.is_empty():
						out.append(_g("antag", 240.0, "picking something up", func(): return get, {"cooldown": 30.0, "why": "I'll need something heavy."}))
				else:
					var alone := JobAI._witnesses_near(b, mark) == 0
					var close: bool = mark.dist_to(b.e) < 12
					var s := 230.0 + b.tv("aggression") * 80.0 + (260.0 if alone and close else 0.0)
					out.append(_g("antag", s, "looking for someone", func(): return JobAI._plan_hunt(b, mark), {"cooldown": 20.0, "fail_cooldown": 40.0, "keep_pull": true,
						"why": "%s is alone. Now." % Dialogue.first(mark) if alone and close else "Patience. Wait until %s is alone." % Dialogue.first(mark)}))
	# after the deed: blood on the hands has to go
	if obj.get("kind", "") == "kill" and b._bloodied(b.inv):
		var sink: Entity = null
		for f in Game.all_with(&"fixture"):
			if f.c(&"fixture").kind == "sink" and (sink == null or f.dist_to(b.e) < sink.dist_to(b.e)):
				sink = f
		if sink:
			out.append(_g("antag_clean", 420.0, "washing up", func(): return [Act.GoTo.new(sink, true, false), Act.Hand.new(sink)], {"cooldown": 30.0, "why": "Wash it off. All of it."}))
	return out

## People who'd see what happens to `mark` (other than us and them).
static func _witnesses_near(b: CBrain, mark: Entity) -> int:
	var n := 0
	for m in Game.in_radius(mark.cell, 7, &"mob"):
		if m == b.e or m == mark:
			continue
		var h: CHealth = m.c(&"health")
		if h and h.stat() == CHealth.CONSCIOUS and b._los(mark.cell, m.cell):
			n += 1
	return n

## Shadow the mark; strike when nobody's looking; then drag them somewhere quiet.
static func _plan_hunt(b: CBrain, mark: Entity) -> Array:
	return [Act.Do.new(func(bb, dt): return JobAI._stalk(bb, mark, dt), "wandering about")]

static func _stalk(bb: CBrain, mark: Entity, dt: float) -> int:
	if not is_instance_valid(mark) or mark.removed:
		return ActBase.DONE
	var mh: CHealth = mark.c(&"health")
	bb.act_t += dt
	if mh.dead:
		bb.mob.combat = false
		bb.inject_front([Act.Do.new(func(b2, _dt): return JobAI._hide_body(b2, mark), "tidying up")])
		return ActBase.DONE
	if bb.act_t > 120.0:
		return ActBase.DONE # give it a rest and come back later
	var seen := JobAI._witnesses_near(bb, mark)
	var d: float = mark.dist_to(bb.e)
	if seen == 0 and not Game.map.is_outdoor(mark.cell):
		# strike
		if not bb.e.adjacent(mark):
			bb.inject_front([Act.GoTo.new(mark, true, true), Act.Do.new(func(b2, dt2): return JobAI._stalk(b2, mark, dt2), "wandering about")])
			return ActBase.DONE
		var w: Entity = bb.inv.find_item(func(x): return x.ai_tags().has("weapon") or x.ai_tags().has("tool_crowbar") or x.proto.contains("toolbox") or x.proto.contains("knife"))
		if w:
			bb.ready_item(w)
		bb.mob.combat = true
		bb.mob.face(Defs.dir_from_vec(mark.cell - bb.e.cell) if mark.cell != bb.e.cell else bb.mob.dir)
		if Combat.ready_to_attack(bb.e):
			if w:
				Interact.use_item_on(bb.e, w, mark)
			else:
				Interact.attack(bb.e, mark, null)
		return ActBase.RUNNING
	bb.mob.combat = false
	# keep a casual distance
	if d > 6:
		bb.inject_front([Act.GoTo.new(mark, true, false), Act.Do.new(func(b2, dt2): return JobAI._stalk(b2, mark, dt2), "wandering about")])
		return ActBase.DONE
	return ActBase.RUNNING

static func _hide_body(bb: CBrain, body: Entity) -> int:
	if not is_instance_valid(body) or body.removed:
		return ActBase.DONE
	# somewhere quiet: the nearest maintenance tunnel
	var best: Area = null
	var bd := 1e9
	for a in Game.map.areas:
		if a.room_kind == "maint" or a.name.contains("Maint"):
			var dd := Vector2(a.center - bb.e.cell).length()
			if dd < bd:
				bd = dd
				best = a
	if best == null or bd > 40 or JobAI._witnesses_near(bb, body) > 0:
		bb.remember_thought("Leave it. Walk away. Don't run.")
		return ActBase.DONE
	bb.remember_thought("Get it out of sight.")
	bb.inject_front([Act.GoTo.new(body, true, true), Act.Pull.new(body), Act.GoTo.new(best.random_cell(Game.rng), false, false), Act.StopPull.new()])
	return ActBase.DONE

static func _plan_sabotage(b: CBrain, c: Vector2i) -> Array:
	var get = b.plan_acquire("tool_wrench", "tool")
	if get == null:
		return []
	var plan: Array = get.duplicate()
	plan.append(Act.GoTo.new(c, true, false))
	plan.append(Act.Do.new(func(bb, _dt): return JobAI._sabotage_step(bb, c), "tinkering with a pipe"))
	return plan

static func _sabotage_step(bb: CBrain, c: Vector2i) -> int:
	if _witnesses(bb) > 0:
		bb.antag["waited"] = bb.antag.get("waited", 0.0) + 0.2
		if bb.antag["waited"] > 40.0:
			bb.antag["waited"] = 0.0
			return ActBase.FAILED
		return ActBase.RUNNING
	var map := Game.map
	for layer in [StationMap.PL_HOT, StationMap.PL_SUPPLY, StationMap.PL_COLD]:
		if map.pipe_mask(layer, c) != 0:
			map.damage_pipe(layer, c, 75.0)
			break
	if map.cable[map.idx(c)] == 1:
		map.cable[map.idx(c)] = 2
		Bus.cables_changed.emit()
	Bus.stimulus.emit({"type": "sabotage", "actor": bb.e, "cell": c, "loud": 0.0, "illegal": true})
	bb.antag["done"] = true
	Bus.chronicle.emit("Someone sabotaged the pipes in %s." % map.area_at(c).name, 3)
	return ActBase.DONE

static func _plan_steal(b: CBrain, target: Entity) -> Array:
	var where := target.root()
	var plan: Array = [Act.GoTo.new(where, true, false), Act.Do.new(func(bb, _dt): return JobAI._steal_step(bb, target), "rummaging")]
	return plan

static func _steal_step(bb: CBrain, target: Entity) -> int:
	if _witnesses(bb) > 0:
		bb.antag["waited"] = bb.antag.get("waited", 0.0) + 0.2
		if bb.antag["waited"] > 40.0:
			bb.antag["waited"] = 0.0
			return ActBase.FAILED
		return ActBase.RUNNING
	var h := target.holder
	if h and h.has_c(&"storage") and h.c(&"storage").kind == "closet" and not h.c(&"storage").is_open:
		var storage: CStorage = h.c(&"storage")
		if storage.locked and not storage.toggle_lock(bb.e): return ActBase.FAILED
		if not storage.open(bb.e): return ActBase.FAILED
	bb.inject_front([Act.PickUp.new(target), Act.Do.new(func(b2, _dt): return JobAI._hide(b2), "")])
	return ActBase.DONE

static func _hide(bb: CBrain) -> int:
	bb.stash_active()
	return ActBase.DONE
