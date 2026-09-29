class_name Goals extends RefCounted
## Universal goals every crewmember has, scored by urgency x personality.
## Rough bands: survival 800-1000, emergencies 400-800, needs 100-550,
## duties 120-600 (see JobAI), social 50-250, idle 30.

static func _g(id: String, score: float, desc: String, plan: Callable, extra := {}) -> Dictionary:
	var d := {"id": id, "score": score, "desc": desc, "plan": plan}
	d.merge(extra)
	return d

static func candidates(b: CBrain) -> Array:
	var out := []
	var e := b.e
	var h := b.health
	var n := b.needs
	var here := e.cell
	var map := Game.map
	var outdoors := map.is_outdoor(here)

	# ------------------------------------------------ survival
	if h.on_fire > 0:
		out.append(_g("stop_drop_roll", 1000.0, "putting out the flames on themselves", func(): return [Act.Do.new(func(bb, _dt): return Goals._drop_and_roll(bb))]))
	if h.breath_status in ["low_o2", "no_air", "toxic"]:
		out.append(_g("breathe", 950.0, "trying to breathe", func(): return Goals._plan_breathe(b)))
	if h.body_temp < 285.0:
		var s := 350.0 + (300.0 - h.body_temp) * 25.0
		out.append(_g("get_warm", minf(s, 940.0), "trying to get warm", func(): return Goals._plan_warm(b), {"cooldown": 20.0}))
	# fire nearby
	var fire := b.knowledge.nearest("fire", here, func(f): return Game.time - f["t"] < 20.0)
	if not fire.is_empty():
		var fc: Vector2i = fire["cell"]
		var fd := maxi(absi(fc.x - here.x), absi(fc.y - here.y))
		var can_fight := b.has_tag("extinguisher") and b.tv("bravery") > 0.35
		if fd <= 3 and not can_fight:
			out.append(_g("flee_fire", 860.0 * (1.35 - b.tv("bravery") * 0.6), "fleeing a fire", func(): return [Act.Flee.new(fc, 9)], {"cooldown": 2.0}))
		if fd <= 14:
			var s2 := 380.0 * (0.25 + b.tv("bravery")) * (0.6 + b.tv("empathy") * 0.6)
			if b.panic > 0.6:
				s2 *= 0.3
			out.append(_g("extinguish", s2, "fighting a fire", func(): return Goals._plan_extinguish(b, fc)))
	# hazardous air where we are
	var gas := b.knowledge.nearest("hazard_gas", here, func(f): return Game.time - f["t"] < 30.0)
	if not gas.is_empty():
		var gc: Vector2i = gas["cell"]
		if maxi(absi(gc.x - here.x), absi(gc.y - here.y)) <= 3:
			out.append(_g("escape_gas", 600.0 * (1.3 - b.tv("bravery") * 0.5), "escaping bad air", func(): return [Act.Flee.new(gc, 10)], {"cooldown": 3.0}))
	# being attacked
	var attackers := b.memory.recent("hurt_me", 25.0)
	if not attackers.is_empty():
		var att := Game.get_entity(attackers[-1]["actor"])
		var being_arrested: bool = att != null and Game.ai != null and Game.ai.claimed_by("arrest:%d" % att.id) not in [0, e.id]
		if att and att.dist_to(e) <= 8 and att.c(&"health") and att.c(&"health").stat() == CHealth.CONSCIOUS and not att.c(&"health").lying() and not att.c(&"health").cuffed and not being_arrested:
			var fight := b.tv("bravery") * 0.6 + b.tv("aggression") * 0.6 + b.anger * 0.5 - (1.0 - h.health() / 100.0)
			if fight > 0.7 or Jobs.dept(b.job) == "security":
				out.append(_g("fight_back", 820.0, "fighting back against %s" % att.display_name, func(): return [Act.Attack.new(att)], {"cooldown": 5.0}))
			else:
				out.append(_g("flee_attacker", 840.0, "running from %s" % att.display_name, func(): return Goals._plan_flee_attacker(b, att), {"cooldown": 3.0}))
	# wanted by security, with an officer bearing down
	if SecurityRecords.is_wanted(e.id) and not h.cuffed:
		var cop: Entity = null
		for m in Game.in_radius(here, 8, &"mob"):
			if m != e and Jobs.dept(m.c(&"mob").job) == "security" and m.c(&"health").stat() == CHealth.CONSCIOUS:
				cop = m
				break
		if cop:
			var guilty := not b.antag.is_empty() or not b.knowledge.of_type("my_crime").is_empty()
			if (guilty and b.tv("lawfulness") < 0.6) or b.tv("lawfulness") < 0.3 or b.tv("bravery") < 0.25:
				out.append(_g("evade", 780.0, "running from the Watch", func(): return [Act.Flee.new(cop.cell, 14)], {"cooldown": 2.0, "why": "They're not taking me in."}))
			else:
				out.append(_g("surrender", 770.0, "putting their hands up", func(): return [Act.Say.new(Dialogue.pick(["Okay, okay! I'll come quietly.", "Alright, I give up.", "Don't shoot! I'm not resisting."])), Act.Wait.new(8.0)],
					{"cooldown": 1.0, "why": "Don't make it worse."}))
	# panic
	if b.panic > 0.7:
		var center := here
		if not fire.is_empty():
			center = fire["cell"]
		out.append(_g("panic", 700.0 * b.panic, "panicking", func(): return [Act.Say.new(Dialogue.line("panic", b, {})), Act.Flee.new(center, 12), Act.Wait.new(3.0)], {"cooldown": 10.0}))
	# outdoors without a reason
	if outdoors and b.job != "miner" and not b.goal.get("outdoor_ok", false):
		out.append(_g("go_inside", 320.0 + (300.0 - h.body_temp) * 10.0, "heading back inside", func(): return Goals._plan_inside(b), {"cooldown": 5.0}))

	# ------------------------------------------------ evacuation (tg: everyone makes for the shuttle)
	var ev: Evac = Game.evac
	if ev and ev.mode == Evac.CALLED and ev.timer < 75.0 and Game.map.evac_lounge != null:
		out.append(_g("wait_departures", 420.0, "waiting at the departure quay", func(): return Goals._plan_lounge(b), {"cooldown": 1.0, "fail_cooldown": 15.0}))
	if ev and ev.mode == Evac.DOCKED and ev.crawler != null and SecurityRecords.escorting.has(e.id):
		out.append_array(Goals.custody_candidates(b))
	elif ev and ev.mode == Evac.DOCKED and ev.crawler != null and h.cuffed:
		pass # locked up and waiting for security
	elif ev and ev.mode == Evac.DOCKED and ev.crawler != null:
		var on := ev.vessel_at(e.cell)
		if on != null:
			var seat := Goals._vessel_seat(b, on)
			var what := "the ferry" if on.kind == "crawler" else "a lifeboat"
			if seat == e.cell:
				out.append(_g("stay_aboard", 900.0, "waiting aboard %s" % what, func(): return [Act.Wait.new(3.0)], {"cooldown": 0.1}))
			else:
				out.append(_g("find_seat", 900.0, "finding a seat on %s" % what, func(): return [Act.GoTo.new(seat, false, false)], {"cooldown": 0.5}))
		else:
			var target := Goals._pick_vessel(b)
			var seat2 := Goals._vessel_seat(b, target)
			var urgency := clampf(1.0 - ev.timer / Evac.DOCK_TIME, 0.0, 1.0)
			out.append(_g("evacuate", 650.0 + 250.0 * urgency, "heading for the relief ferry" if target.kind == "crawler" else "heading for a lifeboat",
				func(): return [Act.GoTo.new(seat2, false, true)], {"cooldown": 2.0, "fail_cooldown": 2.0, "outdoor_ok": true}))

	# ------------------------------------------------ helping others
	for f in b.knowledge.of_type("burning_person"):
		var victim := Game.get_entity(f["subject"])
		if victim and victim != e and victim.dist_to(e) <= 8 and victim.c(&"health").on_fire > 0:
			var s3 := 650.0 * (0.4 + b.tv("empathy") * 0.6) * (0.5 + b.tv("bravery")) + maxf(0.0, b.affinity(victim.id)) * 3.0
			out.append(_g("help_burning", s3, "putting out %s" % victim.display_name, func(): return Goals._plan_help_burning(b, victim)))
			break
	if Jobs.dept(b.job) != "medical":
		var down := b.knowledge.nearest("person_down", here, func(f): return Goals._is_downed(e, f))
		if not down.is_empty():
			var v2 := Game.get_entity(down["subject"])
			var dist := v2.dist_to(e)
			var fr := b.affinity(v2.id)
			var s4 := 420.0 * (0.3 + b.tv("empathy")) * clampf(1.2 - dist / 40.0, 0.4, 1.2) + maxf(0.0, fr) * 4.0 * (0.5 + b.tv("loyalty"))
			if b.cell_dangerous(v2.cell):
				s4 *= b.tv("bravery") + (b.tv("loyalty") if fr > 35 else 0.0)
			if Game.map.is_outdoor(v2.cell) and not b.outdoor_ready():
				s4 *= 0.15 + b.tv("bravery") * 0.2 # most won't run onto the glacier unprepared
			out.append(_g("rescue", s4, "helping %s" % v2.display_name, func(): return Goals._plan_rescue(b, v2), {"keep_pull": true, "fail_cooldown": 20.0, "claim": "patient:%d" % v2.id}))

	# ------------------------------------------------ reporting over the radio
	var hs := b.inv.headset()
	if hs != null and hs.enabled:
		var rep := _report_candidate(b)
		if not rep.is_empty():
			out.append(rep)

	# ------------------------------------------------ needs
	if n.nutrition < 45.0:
		var s5 := (45.0 - n.nutrition) / 45.0 * 560.0 * (0.8 + (1.0 - b.tv("empathy")) * 0.35)
		out.append(_g("eat", s5, "getting something to eat", func(): return Goals._plan_consume(b, "food"), {"fail_cooldown": 40.0}))
	if n.hydration < 45.0:
		var s6 := (45.0 - n.hydration) / 45.0 * 560.0
		out.append(_g("drink", s6, "getting a drink", func(): return Goals._plan_consume(b, "drink"), {"fail_cooldown": 40.0}))
	var nap_threshold := 25.0 + (1.0 - b.tv("diligence")) * 20.0
	if n.energy < nap_threshold:
		var s7 := (nap_threshold - n.energy) / nap_threshold * 520.0
		out.append(_g("sleep", s7, "going to bed", func(): return Goals._plan_sleep(b), {"fail_cooldown": 60.0}))
	if n.comfort < 45.0 and not outdoors and h.body_temp < 295:
		out.append(_g("cocoa", (45.0 - n.comfort) * 4.0, "getting a hot drink", func(): return Goals._plan_cocoa(b), {"cooldown": 240.0, "fail_cooldown": 120.0}))
	if n.social < 55.0 and b.talk_cd <= 0:
		var s8 := (55.0 - n.social) * 5.0 * (0.3 + b.tv("sociability"))
		out.append(_g("socialize", s8, "looking for someone to talk to", func(): return Goals._plan_socialize(b), {"cooldown": 50.0, "fail_cooldown": 40.0}))
	if n.stress > 70.0:
		out.append(_g("decompress", (n.stress - 60.0) * 6.0 * (0.4 + b.tv("neuroticism")), "trying to calm down", func(): return Goals._plan_decompress(b), {"cooldown": 90.0}))
	# snapping under stress: hot-heads may lash out at someone they dislike
	if n.stress > 85.0 and b.tv("aggression") > 0.65 and b.tv("lawfulness") < 0.6:
		var foe := b._disliked_person()
		if foe and foe.dist_to(e) <= 6 and foe.c(&"health") and foe.c(&"health").stat() == CHealth.CONSCIOUS:
			out.append(_g("snap", 500.0, "losing it at %s" % foe.display_name, func(): return [Act.Say.new(Dialogue.line("snap", b, {"name": foe.display_name.split(" ")[0]})), Act.Attack.new(foe)], {"cooldown": 300.0}))
	# grudges
	if b.anger > 0.6:
		for ep in b.memory.recent("hurt_me", 300.0):
			var who := Game.get_entity(ep["actor"])
			if who and who.dist_to(e) <= 5 and b.tv("aggression") > 0.55 and b.tv("bravery") > 0.45:
				out.append(_g("revenge", 380.0 * b.anger, "settling a score with %s" % who.display_name, func(): return [Act.Say.new(Dialogue.line("revenge", b, {"name": who.display_name.split(" ")[0]})), Act.Attack.new(who)], {"cooldown": 200.0}))
				break

	# ------------------------------------------------ player-requested
	if b.follow_target != null and Game.time < b.follow_until:
		var ft := b.follow_target
		out.append(_g("follow", 640.0, "following %s" % ft.display_name, func(): return [Act.Follow.new(ft, 20.0)], {"cooldown": 0.1}))

	# ------------------------------------------------ curiosity
	var noise_f := b.knowledge.nearest("noise", here, func(f): return Game.time - f["t"] < 40.0 and not f.get("handled", false))
	if not noise_f.is_empty():
		var nc: Vector2i = noise_f["cell"]
		var dist2 := absi(nc.x - here.x) + absi(nc.y - here.y)
		if dist2 < 30:
			var s9 := 170.0 * (0.25 + b.tv("curiosity") * 1.3) * (0.4 + b.tv("bravery")) * (1.5 if Jobs.dept(b.job) == "security" else 1.0)
			out.append(_g("investigate", s9, "checking out a noise", func(): return Goals._plan_investigate(noise_f, nc), {"cooldown": 30.0}))

	# ------------------------------------------------ idle
	out.append(_g("idle", 30.0, "hanging around", func(): return Goals._plan_idle(b), {"cooldown": 1.0}))
	return out

static func _drop_and_roll(bb: CBrain) -> int:
	bb.health.knockdown(2.5)
	bb.mob.emote("drops and rolls on the floor!")
	return ActBase.DONE

static func _is_downed(me: Entity, f: Dictionary) -> bool:
	var v := Game.get_entity(f["subject"])
	return v != null and v != me and v.c(&"health") != null and not v.c(&"health").dead and v.c(&"health").stat() != CHealth.CONSCIOUS

static func _plan_flee_attacker(b: CBrain, att: Entity) -> Array:
	var plan: Array = [Act.Flee.new(att.cell, 12)]
	var hs := b.inv.headset()
	if hs and not b.knowledge.get_fact("crime:assault:%d" % att.id).get("reported", false):
		plan.push_front(Act.Say.new("Help! %s is attacking me in %s!" % [att.display_name, Game.map.area_at(b.e.cell).name], "Security" if "Security" in hs.channels else "Common",
			{"key": "crime:assault:%d" % att.id, "type": "crime", "subject": att.id, "cell": b.e.cell, "severity": 3, "data": {"crime": "assault", "actor": att.id, "victim": b.e.id}}))
	return plan

static func _plan_help_burning(b: CBrain, victim: Entity) -> Array:
	if b.has_tag("extinguisher"):
		return [Act.GoTo.new(victim, true), Act.Spray.new(victim.cell)]
	return [Act.GoTo.new(victim, true), Act.Hand.new(victim)]

static func _plan_investigate(f: Dictionary, nc: Vector2i) -> Array:
	f["handled"] = true
	return [Act.GoTo.new(nc, true, false), Act.Wait.new(2.5)]

static func _set_internals(bb: CBrain) -> int:
	bb.mob.internals = true
	return ActBase.DONE

static func _wear_coat(bb: CBrain) -> int:
	var it: Entity = bb.inv.find_item(func(x): return x.ai_tags().has("warm_clothing") and not x in bb.inv.slots.values())
	if it:
		bb.inv.quick_equip(it)
	return ActBase.DONE

static func _cpr(bb: CBrain, victim: Entity) -> int:
	if bb.e.adjacent(victim):
		Interact.cpr(bb.e, victim)
	return ActBase.DONE

static func _wait_doafter(bb: CBrain) -> int:
	return ActBase.RUNNING if DoAfter.busy(bb.e) else ActBase.DONE

static func _eat_found(bb: CBrain, tag: String) -> int:
	var it: Entity = bb.inv.find_item(func(x): return x.ai_tags().has(tag))
	if it == null:
		return ActBase.FAILED
	bb.inject_front([Act.Consume.new(it)])
	return ActBase.DONE

static func _drink_tap(bb: CBrain, tap: Entity) -> int:
	if not is_instance_valid(tap) or not bb.e.adjacent(tap):
		return ActBase.FAILED
	bb.needs.hydration = minf(100.0, bb.needs.hydration + 45.0)
	bb.mob.emote("cups their hands under %s and drinks." % tap.the())
	return ActBase.DONE

static func _consume_last(bb: CBrain) -> int:
	if bb.last_acquired and is_instance_valid(bb.last_acquired) and not bb.last_acquired.removed:
		bb.inject_front([Act.Consume.new(bb.last_acquired)])
	return ActBase.DONE

static func _occupy(bb: CBrain, bed: Entity) -> int:
	bed.c(&"furniture").occupy(bb.e)
	return ActBase.DONE

static func _calm(bb: CBrain) -> int:
	bb.needs.stress = maxf(0.0, bb.needs.stress - 25.0)
	return ActBase.DONE

static func _idle_bark(bb: CBrain) -> int:
	bb.bark(Dialogue.idle_line(bb))
	return ActBase.DONE

# ------------------------------------------------------------------ plans
static func _plan_breathe(b: CBrain) -> Array:
	var plan := []
	var inv := b.inv
	var mask: Entity = inv.worn("mask")
	var has_tank := b.has_tag("air_tank")
	if has_tank:
		if mask == null or not mask.c(&"clothing").breath_mask:
			var m = b.plan_acquire("breath_mask")
			if m != null and m.size() <= 2 and inv.find_item(func(x): return x.ai_tags().has("breath_mask")) != null:
				var mk: Entity = inv.find_item(func(x): return x.ai_tags().has("breath_mask"))
				plan.append(Act.Equip.new(mk))
		plan.append(Act.Do.new(func(bb, _dt): return Goals._set_internals(bb), "opening the gas cylinder"))
		return plan
	# get away from the bad air: somewhere we don't know to be bad
	var safe := _safe_area(b)
	if safe:
		return [Act.GoTo.new(safe.random_cell(Game.rng), false, true)]
	return [Act.Flee.new(b.e.cell, 10)]

static func _safe_area(b: CBrain) -> Area:
	var best: Area = null
	var bd := 1e9
	for a in Game.map.areas:
		if a.outdoor or a.cells.size() < 6 or a.atmos_alarm or a.fire_alarm:
			continue
		if b.knowledge.has("gas@%d" % a.id):
			continue
		var d := Vector2(a.center - b.e.cell).length()
		if d < 4:
			continue
		if d < bd:
			bd = d
			best = a
	return best

static func _plan_warm(b: CBrain) -> Array:
	var here := b.e.cell
	if Game.map.is_outdoor(here):
		return _plan_inside(b)
	var plan := []
	var inv := b.inv
	if inv.worn("suit") == null or inv.worn("suit").c(&"clothing").insulation < 0.3:
		var coat = b.plan_acquire("warm_clothing")
		if coat != null:
			plan.append_array(coat)
			plan.append(Act.Do.new(func(bb, _dt): return Goals._wear_coat(bb), "putting on a coat"))
			return plan
	# go somewhere heated
	var warm: Area = null
	var bd := 1e9
	for a in Game.map.areas:
		if a.outdoor or a.cells.is_empty() or not a.power_environ:
			continue
		var t = Game.atmos.temp_at(a.center)
		if t < 285:
			continue
		var d := Vector2(a.center - here).length()
		if d < bd:
			bd = d
			warm = a
	if warm:
		plan.append(Act.GoTo.new(warm.random_cell(Game.rng), false, true))
		plan.append(Act.Wait.new(8.0))
		return plan
	return _plan_cocoa(b)

static func _plan_lounge(b: CBrain) -> Array:
	## Take a lounge seat if one is free, else find some floor that isn't the doorway.
	var lounge: Area = Game.map.evac_lounge
	var here := b.e.cell
	for x in Game.at(here):
		if x.has_c(&"furniture") and Game.map.area_at(here) == lounge:
			return [Act.Wait.new(6.0)]
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for c in lounge.cells:
		var seat := false
		var taken := false
		for x in Game.at(c):
			if x.has_c(&"furniture"):
				seat = true
			if x.has_c(&"mob") and x != b.e:
				taken = true
		if seat and not taken:
			var d: int = (c - here).length_squared()
			if d < bd:
				bd = d
				best = c
	if best.x < 0:
		if Game.map.area_at(here) == lounge and Game.rng.randf() < 0.8:
			return [Act.Wait.new(5.0)]
		best = lounge.random_cell(Game.rng)
	return [Act.GoTo.new(best, false, false), Act.Wait.new(6.0)]

## A prisoner security has collected walks (cuffed) to the crawler brig and stays there.
## The only thing a cuffed NPC does (see CBrain.think).
static func custody_candidates(b: CBrain) -> Array:
	var ev: Evac = Game.evac
	if ev == null or ev.mode != Evac.DOCKED or ev.crawler == null or not SecurityRecords.escorting.has(b.e.id):
		return []
	var bc := Goals._brig_spot(b, ev.crawler)
	if bc == b.e.cell:
		return [_g("custody", 960.0, "sitting in the ferry brig", func(): return [Act.Wait.new(4.0)], {"cooldown": 0.1})]
	return [_g("custody", 960.0, "being taken to the ferry brig", func(): return [Act.GoTo.new(bc, false, false)], {"cooldown": 1.0, "outdoor_ok": true})]

static func _brig_spot(b: CBrain, v: Vessel) -> Vector2i:
	if b.e.cell in v.brig_cells:
		return b.e.cell
	for c in v.brig_cells:
		if not Game.at(c).any(func(x): return x.has_c(&"mob") or (x.has_c(&"blocker") and x.c(&"blocker").dense)):
			return c
	return v.brig_cells[0]

## Which way out: the crawler, unless an escape pod with a free seat is a lot closer.
static func _pick_vessel(b: CBrain) -> Vessel:
	var ev: Evac = Game.evac
	var best: Vessel = ev.crawler
	var here := b.e.cell
	var bd: int = absi(best.dock_cell.x - here.x) + absi(best.dock_cell.y - here.y) - 15
	for p in ev.pods:
		if not p.present or p.free_seat_count() == 0:
			continue
		var d: int = absi(p.dock_cell.x - here.x) + absi(p.dock_cell.y - here.y)
		if d < bd:
			bd = d
			best = p
	return best

## The best free spot reachable from the hatch without squeezing past anyone: seats first
## (along the walls, they never block the aisle), then the deepest floor, so the vessel
## fills from the ends. Someone already in the best reachable spot keeps it.
static func _vessel_seat(b: CBrain, v: Vessel) -> Vector2i:
	var hatch: Vector2i = v.dock_cell
	var free := {}
	for c in v.interior:
		free[c] = true
		for x in Game.at(c):
			if x != b.e and x.has_c(&"mob"):
				free.erase(c)
				break
	var score := {hatch: 0}
	var depth := {hatch: 0}
	var queue: Array = [hatch]
	var best := hatch
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in Defs.DIRS4:
			var nc: Vector2i = c + d
			if free.has(nc) and not depth.has(nc):
				depth[nc] = depth[c] + 1
				score[nc] = depth[nc] + (30 if v.seats.has(nc) else 0)
				queue.append(nc)
				if score[nc] > score[best]:
					best = nc
	if score.has(b.e.cell) and score[b.e.cell] == score[best]:
		return b.e.cell
	return best

static func _plan_inside(b: CBrain) -> Array:
	# nearest external airlock we know of, then a step inside
	var best: Entity = null
	var bd := 1e9
	for d in Game.all_with(&"door"):
		if d.c(&"door").external:
			var dd := Vector2(d.cell - b.e.cell).length()
			if dd < bd:
				bd = dd
				best = d
	if best == null:
		return []
	var inside := best.cell
	for dir in Defs.DIRS4:
		var c: Vector2i = best.cell + dir
		if not Game.map.is_outdoor(c) and Game.map.is_passable(c):
			inside = c + dir
			break
	return [Act.GoTo.new(inside, false, true)]

static func _plan_extinguish(b: CBrain, fc: Vector2i) -> Array:
	var plan := []
	var get = b.plan_acquire("extinguisher")
	if get == null:
		return []
	plan.append_array(get)
	plan.append(Act.GoTo.new(fc, true, true))
	plan.append(Act.Spray.new(fc))
	return plan

static func _plan_rescue(b: CBrain, victim: Entity) -> Array:
	var plan: Array = [Act.GoTo.new(victim, true, true)]
	var vh: CHealth = victim.c(&"health")
	if vh.oxy > 15:
		plan.append(Act.Do.new(func(bb, _dt): return Goals._cpr(bb, victim), "performing CPR"))
		plan.append(Act.Do.new(func(bb, _dt): return Goals._wait_doafter(bb), "performing CPR"))
	# brave / caring people drag the patient to Medbay
	if b.tv("empathy") + b.tv("bravery") > 0.9:
		var med := b.area_named("Medbay Treatment")
		if med:
			var bed_cell := med.random_cell(Game.rng)
			for f in Game.all_with(&"furniture"):
				if f.c(&"furniture").kind in ["bed", "sleeper"] and Game.map.area_at(f.cell) == med and f.c(&"furniture").free_for(victim):
					bed_cell = f.cell
					break
			plan.append(Act.Pull.new(victim))
			plan.append(Act.GoTo.new(bed_cell, false, false))
			plan.append(Act.StopPull.new())
			plan.append(Act.Say.new(Dialogue.line("dropped_patient", b, {"name": victim.display_name.split(" ")[0]})))
	return plan

static func _report_candidate(b: CBrain) -> Dictionary:
	var hs := b.inv.headset()
	var best := {}
	var bs := 0.0
	for f in b.knowledge.facts.values():
		if f.get("reported", false) or f["src"] == Knowledge.RADIO:
			continue
		if not f["type"] in ["fire", "breach", "person_down", "body", "crime", "power_out", "hazard_gas", "pipe_leak", "injured", "burning_person", "sick", "cold_area"]:
			continue
		var sev: int = f.get("severity", 1)
		if f["type"] == "injured" and sev < 3:
			continue
		if f["type"] == "pipe_leak" and sev < 2 and Jobs.dept(b.job) != "engineering":
			continue
		# don't flood the radio: one report of a kind at a time, unless it's dire
		if sev < 4 and Game.time - b.report_log.get(f["type"], -999.0) < 75.0:
			continue
		var s := 330.0 + sev * 45.0
		if f["type"] == "crime":
			var actor: int = f.get("data", {}).get("actor", 0)
			if actor == b.e.id:
				continue
			# wandering into the wrong room is security's business, not a radio call
			if f.get("data", {}).get("crime", "") == "trespass":
				var ta := Game.map.area_at(f.get("cell", Vector2i.ZERO))
				if Jobs.dept(b.job) != "security" and not (ta.room_kind in ["armory", "vault"] or ta.name.begins_with("Armory") or ta.name.begins_with("Vault")):
					continue
			if b.is_friend(actor) and b.tv("loyalty") > 0.55:
				continue
			s *= 0.4 + b.tv("honesty") * 0.4 + b.tv("lawfulness") * 0.4
		if b.tv("diligence") < 0.25 and sev < 3:
			s *= 0.5
		if Game.time - f["t"] > 120.0:
			continue
		if s > bs:
			bs = s
			best = f
	if best.is_empty():
		return {}
	var f2 := best
	var chan := "Common"
	match f2["type"]:
		"fire", "breach", "power_out", "hazard_gas", "pipe_leak", "cold_area":
			chan = "Engineering" if "Engineering" in hs.channels else "Common"
		"person_down", "body", "injured", "sick", "burning_person":
			chan = "Medical" if "Medical" in hs.channels else "Common"
		"crime":
			chan = "Security" if "Security" in hs.channels else "Common"
	var text := Dialogue.report_line(b, f2)
	var sent := f2.duplicate()
	for k in sent.keys():
		if k.begins_with("shared_with_"):
			sent.erase(k)
	return _g("report", bs, "calling it in on the voice-link", func(): return Goals._plan_report(b, f2, text, chan, sent), {"cooldown": 3.0})

static func _plan_report(b: CBrain, f: Dictionary, text: String, chan: String, sent: Dictionary) -> Array:
	f["reported"] = true
	b.report_log[f["type"]] = Game.time
	return [Act.Say.new(text, chan, sent)]

static func _plan_consume(b: CBrain, tag: String) -> Array:
	var have: Entity = b.inv.find_item(func(x): return x.ai_tags().has(tag))
	if have:
		return [Act.Consume.new(have)]
	var get = b.plan_acquire(tag, tag)
	if tag == "drink":
		# the tap always works: use it when the machines are dry, far away, or keep failing us
		var tap: Entity = null
		for f in Game.all_with(&"fixture"):
			if f.c(&"fixture").kind == "sink" and (tap == null or f.dist_to(b.e) < tap.dist_to(b.e)) and b.may_enter(Game.map.area_at(f.cell)):
				tap = f
		var far: bool = get != null and not get.is_empty() and get[0] is Act.GoTo and b.e.dist_to(get[0].ent if get[0].ent else b.e) > 25.0
		if tap and (get == null or b.learned.failures("drink") >= 2 or (far and tap.dist_to(b.e) < 15.0)):
			return [Act.GoTo.new(tap, true, false), Act.Do.new(func(bb, _dt): return Goals._drink_tap(bb, tap), "drinking from the tap")]
	if get == null:
		# go look where food usually is
		var caf := b.area_named("Cafeteria")
		if caf and Game.map.area_at(b.e.cell) != caf:
			return [Act.GoTo.new(caf.random_cell(Game.rng), false, false), Act.Wait.new(1.0)]
		return []
	var plan: Array = get.duplicate()
	plan.append(Act.Do.new(func(bb, _dt): return Goals._eat_found(bb, tag), "eating"))
	return plan

static func _plan_cocoa(b: CBrain) -> Array:
	var have: Entity = b.inv.find_item(func(x): return x.ai_tags().has("hot_food"))
	if have:
		return [Act.Consume.new(have)]
	for f in b.knowledge.of_type("item_at"):
		if f.get("data", {}).get("vending", "") == "drink":
			var vm := Game.get_entity(f["subject"])
			if vm and vm.c(&"vending").products.any(func(p): return p["proto"] == "drink_cocoa" and p["count"] > 0):
				return [Act.GoTo.new(vm, true, false), Act.Vend.new(vm, "drink_cocoa"), Act.Do.new(func(bb, _dt): return Goals._consume_last(bb), "sipping cocoa")]
	return []

static func _plan_sleep(b: CBrain) -> Array:
	var bed := Game.get_entity(b.bed_id)
	if bed == null or not bed.c(&"furniture").free_for(b.e):
		bed = null
		for f in b.knowledge.of_type("item_at"):
			if "bed" in f.get("data", {}).get("tags", []):
				var cand := Game.get_entity(f["subject"])
				if cand and cand.c(&"furniture") and cand.c(&"furniture").free_for(b.e) and not Game.map.area_at(cand.cell).name.begins_with("Medbay") and not Game.map.area_at(cand.cell).name.begins_with("Brig") and not Game.map.area_at(cand.cell).name.begins_with("Morgue"):
					bed = cand
					break
	if bed == null:
		return [Act.Sleep.new()]
	return [Act.GoTo.new(bed.cell, false, false), Act.Do.new(func(bb, _dt): return Goals._occupy(bb, bed), "getting into bed"), Act.Sleep.new()]

static func _plan_socialize(b: CBrain) -> Array:
	var best: Entity = null
	var bs := -1e9
	for m in Game.in_radius(b.e.cell, 14, &"mob"):
		if m == b.e:
			continue
		var mh: CHealth = m.c(&"health")
		if mh == null or mh.stat() != CHealth.CONSCIOUS:
			continue
		var ob: CBrain = m.c(&"brain")
		if ob and (ob.goal.get("score", 0.0) > 300.0):
			continue
		var s = b.affinity(m.id) + randf_range(-10, 10) - m.dist_to(b.e) * 2.0
		if m == Game.player:
			s += 5.0 * b.tv("sociability")
		if b.is_enemy(m.id):
			continue
		if s > bs:
			bs = s
			best = m
	if best == null:
		var caf := b.area_named("Cafeteria")
		if caf and Game.map.area_at(b.e.cell) != caf:
			return [Act.GoTo.new(caf.random_cell(Game.rng), false, false)]
		return []
	b.talk_cd = 45.0
	var ob2: CBrain = best.c(&"brain")
	if ob2:
		ob2.talk_cd = 30.0
	return [Act.Talk.new(best)]

static func _plan_decompress(b: CBrain) -> Array:
	for nm in ["Crew Lounge", "Dormitories", "Cafeteria"]:
		var a := b.area_named(nm)
		if a:
			return [Act.GoTo.new(a.random_cell(Game.rng), false, false), Act.Wait.new(20.0), Act.Do.new(func(bb, _dt): return Goals._calm(bb), "calming down")]
	return []

static func _plan_idle(b: CBrain) -> Array:
	var cells := b.work_cells()
	if cells.is_empty() or randf() < 0.25:
		var a := b.area_named(["Cafeteria", "Crew Lounge", "Central Hall", "North Hall"][randi() % 4])
		if a:
			cells = a.cells
	if cells.is_empty():
		return [Act.Wait.new(3.0)]
	var plan: Array = [Act.Wander.new(cells), Act.Wait.new(randf_range(3.0, 9.0))]
	if randf() < 0.1 and b.bark_cd <= 0:
		plan.append(Act.Do.new(func(bb, _dt): return Goals._idle_bark(bb)))
	return plan
