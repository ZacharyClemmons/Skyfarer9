class_name Routine extends RefCounted
## The shape of a shift and what people do with their spare time. The station clock
## runs 07:00 to 13:00; like any workplace, people drift in with a hot drink, work,
## take a break mid-morning, crowd the cafeteria at lunch, and wind down at the bar at
## the end. Early birds are sharp in the morning and fade; night owls warm up late.
## Leisure comes from the persona: the gambler plays the arcade, the music lover puts
## the jukebox on, the smoker sneaks off, the aurora-watcher stares out of the window,
## the poet pins a poem to the noticeboard. Plans made in conversation ("lunch?") are
## kept: they go and meet.

# ------------------------------------------------------------------ clock
static func aurora_now() -> bool:
	return Game.director != null and Game.director.aurora_until > Game.time

static func hour() -> float:
	return fmod(Game.station_seconds() / 3600.0, 24.0)

static func phase() -> String:
	var h := hour()
	if h < 7.42:
		return "arrival"
	if h < 9.75:
		return "morning"
	if h < 10.17:
		return "break"
	if h < 11.25:
		return "late_morning"
	if h < 11.92:
		return "lunch"
	if h < 12.58:
		return "afternoon"
	return "wind_down"

## How much their mind is on the job right now (multiplies routine duties).
static func work_mult(b: CBrain) -> float:
	var ph := phase()
	var m := 1.0
	match ph:
		"arrival": m = 0.75
		"break": m = 0.55
		"lunch": m = 0.45
		"wind_down": m = 0.7
	var ct: String = b.persona.chronotype if b.persona else "day"
	var h := hour()
	if ct == "early":
		m *= 1.2 if h < 10.0 else 0.85
	elif ct == "late":
		m *= 0.8 if h < 10.0 else 1.2
	# a bad mood or grief takes the edge off
	m *= clampf(1.0 + b.mood * 0.15 - b.grief * 0.3, 0.5, 1.2)
	return m

# ------------------------------------------------------------------ candidates
static func _g(id: String, score: float, desc: String, plan: Callable, extra := {}) -> Dictionary:
	var d := {"id": id, "score": score, "desc": desc, "plan": plan}
	d.merge(extra)
	return d

static func candidates(b: CBrain) -> Array:
	var out := []
	if b.health.cuffed or Game.map.is_outdoor(b.e.cell) and b.job != "miner":
		return out
	var ph := phase()
	var p: Persona = b.persona
	var did: Dictionary = b.routine_done
	var caf := b.area_named("Cafeteria")
	# --- arrival: a hot drink on the way in
	if ph == "arrival" and not did.has("coffee") and (p.has_quirk("coffee") or randf() < 0.5 or b.needs.comfort < 70):
		out.append(_g("morning_drink", 210.0, "grabbing a hot drink before work", func(): return Routine._plan_hot_drink(b), {"cooldown": 30.0, "fail_cooldown": 90.0, "why": "Can't start a watch without something warm.", "on_start": Routine._mark.bind(b, "coffee")}))
	# --- the Director says good morning
	if b.job == "captain" and not did.has("announce") and Game.time > 12.0 and b.inv.headset():
		out.append(_g("morning_brief", 480.0, "addressing the crew", func(): return [Act.Say.new(Dialogue.morning_announcement(b), "Common")], {"why": "The crew should hear from me.", "on_start": Routine._mark.bind(b, "announce")}))
	# --- heads of staff check in with command mid-morning
	if Jobs.is_head(b.job) and b.job != "captain" and ph == "morning" and hour() > 8.5 and not did.has("status") and b.inv.headset():
		out.append(_g("status_report", 260.0, "giving a status report", func(): return [Act.Say.new(Dialogue.dept_status(b), "Command")], {"on_start": Routine._mark.bind(b, "status")}))
	# --- break
	if ph == "break" and not did.has("break"):
		out.append(_g("take_break", 190.0 + (1.0 - b.tv("diligence")) * 120.0, "taking a break", func(): return Routine._plan_leisure(b, true), {"cooldown": 20.0, "fail_cooldown": 60.0,
			"why": "Five minutes. I've earned five minutes.", "on_start": Routine._start_break.bind(b)}))
	# --- lunch
	if ph == "lunch" and not did.has("lunch") and caf:
		var s := 300.0 + (60.0 if b.needs.nutrition < 60 else 0.0) + b.tv("sociability") * 60.0
		if b.job == "cook":
			s *= 0.3 # the cook eats after the rush
		out.append(_g("lunch", s, "having a meal in the galley", func(): return Routine._plan_lunch(b), {"cooldown": 30.0, "fail_cooldown": 60.0, "why": "Lunch. Finally.",
			"on_start": Routine._start_lunch.bind(b)}))
	# --- end of shift: the bar and the lounge fill up
	if ph == "wind_down" and not did.has("unwind"):
		out.append(_g("unwind", 180.0 + b.tv("sociability") * 100.0, "unwinding after the watch", func(): return Routine._plan_unwind(b), {"cooldown": 40.0, "fail_cooldown": 60.0,
			"why": "Shift's nearly over. Time to relax.", "on_start": Routine._mark.bind(b, "unwind")}))
	# --- plans made with someone
	if not b.plan_with.is_empty() and Game.time < b.plan_with.get("until", 0.0):
		var who := Game.get_entity(b.plan_with.get("who", 0))
		if who and not who.c(&"health").dead:
			var where: String = b.plan_with.get("where", "Cafeteria")
			out.append(_g("meet_up", 270.0, "meeting %s at the %s" % [who.display_name, where.to_lower()], func(): return Routine._plan_meet(b, who, where), {"cooldown": 15.0, "fail_cooldown": 40.0,
				"why": "I said I'd meet %s." % Dialogue.first(who)}))
	# --- leisure when bored
	var fun: float = b.needs.fun
	if fun < 58.0 and b.talk_cd <= 0.0:
		var s2 := (58.0 - fun) * 4.5 * (1.35 - b.tv("diligence") * 0.7)
		if ph in ["break", "lunch", "wind_down"]:
			s2 *= 1.6
		out.append(_g("leisure", s2, "looking for something to do", func(): return Routine._plan_leisure(b, false), {"cooldown": 45.0, "fail_cooldown": 45.0, "why": "I'm so bored."}))
	# --- quirks
	# tg nicotine withdrawal makes the craving urgent (stage 1 from a minute without)
	var nic := Addiction.stage(b.health, "nicotine") if b.health else 0
	if p.has_quirk("smoker") and (Game.time - b.last_smoke > 420.0 or nic > 0):
		var why: String = ["I need a cigarette.", "Feel like having a smoke...", "Getting antsy. Really need a smoke now.", "I can't take it! Need a smoke NOW!"][nic]
		out.append(_g("smoke_break", 150.0 + (Game.time - b.last_smoke) * 0.15 + nic * 120.0, "sneaking off for a smoke", func(): return Routine._plan_smoke(b), {"cooldown": 60.0, "fail_cooldown": 120.0, "why": why}))
	if p.has_quirk("neat_freak") and b.job != "janitor":
		var mess := b.knowledge.nearest("mess", b.e.cell, func(f): return Game.get_entity(f["subject"]) != null)
		if not mess.is_empty() and Vector2(mess["cell"] - b.e.cell).length() < 8 and b.has_tool("mop"):
			var md := Game.get_entity(mess["subject"])
			out.append(_g("tidy", 120.0, "tidying up", func(): return JobAI._plan_clean(b, md), {"fail_cooldown": 60.0, "why": "I can't stand this mess."}))
	# --- ambitions
	out.append_array(_ambitions(b))
	return out

static var _lunch_called := false

static func _mark(b: CBrain, what: String) -> void:
	b.routine_done[what] = true

static func _start_break(b: CBrain) -> void:
	b.routine_done["break"] = true
	if randf() < 0.3:
		b.bark(Dialogue.line("break_start", b, {}))

static func _start_lunch(b: CBrain) -> void:
	b.routine_done["lunch"] = true
	if randf() < 0.25 and b.inv.headset() and not Routine._lunch_called:
		Routine._lunch_called = true
		b.radio_say("Common", Dialogue.line("lunch_call", b, {}))

static func _start_party(b: CBrain) -> void:
	b.routine_done["party_call"] = true
	b.ambition_progress("party")
	Routine.party_until = Game.time + 240.0

# ------------------------------------------------------------------ plans
static func _fixtures(kind: String) -> Array:
	return Game.all_with(&"fixture").filter(func(x): return x.c(&"fixture").kind == kind and x.holder == null)

static func _nearest(b: CBrain, ents: Array) -> Entity:
	var best: Entity = null
	var bd := 1e9
	for x in ents:
		var d: float = x.dist_to(b.e)
		if d < bd and b.learned.danger_of(Game.map.area_at(x.cell).id) < 0.5:
			bd = d
			best = x
	return best

static func _plan_hot_drink(b: CBrain) -> Array:
	var have: Entity = b.inv.find_item(func(x): return x.ai_tags().has("hot_food") or x.proto in ["drink_coffee", "drink_cocoa"])
	if have:
		return [Act.Consume.new(have)]
	var cm := _nearest(b, Game.all_with(&"reagents").filter(func(x): return x.proto == "coffee_machine"))
	var plan := Goals._plan_cocoa(b)
	if not plan.is_empty():
		return plan
	if cm:
		return [Act.GoTo.new(cm, true, false), Act.Wait.new(3.0), Act.Do.new(func(bb, _dt): return Routine._sip(bb, "coffee"), "sipping coffee")]
	return []

static func _sip(bb: CBrain, what: String) -> int:
	bb.needs.comfort = minf(100.0, bb.needs.comfort + 20.0)
	bb.needs.hydration = minf(100.0, bb.needs.hydration + 15.0)
	bb.needs.fun = minf(100.0, bb.needs.fun + 5.0)
	bb.mob.emote("sips some %s." % what)
	return ActBase.DONE

static func _plan_lunch(b: CBrain) -> Array:
	var caf := b.area_named("Cafeteria")
	if caf == null:
		return []
	var plan := []
	var food: Entity = b.inv.find_item(func(x): return x.ai_tags().has("food"))
	if food == null:
		# the counter, then the vending machine
		var meal: Entity = null
		var bd := 1e9
		for c in caf.cells:
			for it in Game.at(c):
				if it.has_c(&"food") and not it.c(&"food").ingredient and not it.c(&"food").drink and it.holder == null:
					var d: float = it.dist_to(b.e)
					if d < bd:
						bd = d
						meal = it
		if meal:
			plan.append_array([Act.GoTo.new(meal, true, false), Act.PickUp.new(meal)])
		else:
			var get = b.plan_acquire("food", "food")
			if get != null:
				plan.append_array(get)
	plan.append(Act.GoTo.new(_seat_in(b, caf), false, false))
	plan.append(Act.Do.new(func(bb, _dt): return Routine._eat_seated(bb), "eating lunch"))
	plan.append(Act.Wait.new(randf_range(10.0, 22.0)))
	plan.append(Act.Do.new(func(bb, _dt): return Routine._lunch_chat(bb), "chatting over lunch"))
	return plan

static func _seat_in(b: CBrain, a: Area) -> Vector2i:
	var best := a.random_cell(Game.rng)
	var bd := 1e9
	for f in Game.all_with(&"furniture"):
		var fc: CFurniture = f.c(&"furniture")
		if fc.kind == "seat" and Game.map.area_at(f.cell) == a:
			if Game.at(f.cell).any(func(x): return x.has_c(&"mob") and x != b.e):
				continue
			# sit near friends, if any are here
			var d := Vector2(f.cell - b.e.cell).length() * 0.2 + randf() * 6.0
			for m in Game.in_radius(f.cell, 2, &"mob"):
				if m != b.e and b.affinity(m.id) > 20:
					d -= 6.0
				elif m != b.e and b.is_enemy(m.id):
					d += 12.0
			if d < bd:
				bd = d
				best = f.cell
	return best

static func _eat_seated(bb: CBrain) -> int:
	var food: Entity = bb.inv.find_item(func(x): return x.ai_tags().has("food"))
	if food:
		bb.inject_front([Act.Consume.new(food)])
		if bb.persona and food.display_name.to_lower().contains(bb.persona.fav_food.split(" ")[0]):
			bb.needs.fun = minf(100.0, bb.needs.fun + 15.0)
			bb.say_later(Dialogue.pick(["Mm, %s. My favourite." % food.display_name, "Oh, this is good.", "Now THAT is a %s." % food.display_name]), 2.0)
	return ActBase.DONE

static func _lunch_chat(bb: CBrain) -> int:
	# whoever's at the next seat gets talked to
	for m in Game.in_radius(bb.e.cell, 2, &"brain"):
		if m != bb.e and m.c(&"brain").convo == null and bb.convo == null and not bb.is_enemy(m.id):
			if randf() < 0.5 + bb.tv("sociability") * 0.4:
				if bb.start_conversation(m) and bb.convo != null:
					bb.inject_front([Act.Chat.new(bb.convo)])
				return ActBase.DONE
	if Game.player and Game.player.dist_to(bb.e) <= 2 and randf() < 0.4:
		bb.say(Dialogue.smalltalk(bb, Game.player), {"to": Game.player})
	return ActBase.DONE

static func _plan_unwind(b: CBrain) -> Array:
	var bar := b.area_named("Bar")
	var lounge := b.area_named("Crew Lounge")
	var a: Area = bar if bar and (b.tv("sociability") > 0.45 or randf() < 0.5) else lounge
	if a == null:
		a = b.area_named("Cafeteria")
	if a == null:
		return []
	var plan: Array = [Act.GoTo.new(_seat_in(b, a), false, false)]
	if a == bar:
		plan.append(Act.Do.new(func(bb, _dt): return Routine._order_drink(bb), "ordering a drink"))
	plan.append(Act.Wait.new(randf_range(15.0, 30.0)))
	plan.append(Act.Do.new(func(bb, _dt): return Routine._lunch_chat(bb), "chatting"))
	return plan

static func _plan_meet(b: CBrain, who: Entity, where: String) -> Array:
	var a := b.area_named(where)
	if a == null:
		b.plan_with = {}
		return []
	if Game.map.area_at(b.e.cell) == a and who.dist_to(b.e) <= 6:
		b.plan_with = {}
		var plan: Array = [Act.Talk.new(who)]
		if where == "Bar":
			plan.push_front(Act.Do.new(func(bb, _dt): return Routine._order_drink(bb), "ordering a drink"))
		if where == "Cafeteria":
			plan = _plan_lunch(b)
			plan.append(Act.Talk.new(who))
		return plan
	if Game.map.area_at(b.e.cell) == a:
		return [Act.Wait.new(5.0)]
	return [Act.GoTo.new(_seat_in(b, a), false, false)]

## Pick something fun to do, from who they are.
static func _plan_leisure(b: CBrain, on_break: bool) -> Array:
	var p: Persona = b.persona
	var w := {}
	var arcades := _fixtures("arcade")
	var jukes := _fixtures("jukebox")
	var boards := _fixtures("noticeboard")
	if not arcades.is_empty():
		w["arcade"] = 1.0 + (3.0 if p.has_interest("gambling") else 0.0) + (2.0 if "win_arcade" in p.ambitions else 0.0)
	if not jukes.is_empty():
		w["jukebox"] = 0.5 + (3.0 if p.has_interest("music") else 0.0)
	if b.area_named("Bar"):
		w["bar"] = 1.0 + b.tv("sociability") + (1.5 if Routine.phase() == "wind_down" else 0.0)
		# tg alcoholics: the bar calls, louder in withdrawal
		if Quirks.has(b.e, "alcoholic"):
			w["bar"] += 2.0 + 2.0 * (Addiction.stage(b.health, "alcohol") if b.health else 0)
	if not boards.is_empty():
		w["noticeboard"] = 0.6 + (2.5 if p.has_interest("poetry") else 0.0) + (1.0 if p.has_quirk("gossip") or p.has_quirk("nosy") else 0.0)
	if p.has_interest("aurora") or p.has_interest("stars") or p.has_interest("birds") or Routine.aurora_now():
		w["window"] = 2.5
	w["hobby"] = 2.0
	w["friend"] = 0.5 + b.tv("sociability") * 2.0
	w["wander"] = 0.5 + b.tv("curiosity") * 1.5
	if p.has_quirk("smoker"):
		w["smoke"] = 2.5
	if b.needs.energy < 45:
		w["nap"] = 2.0
	if on_break and p.has_quirk("coffee"):
		w["drink"] = 3.0
	var fav := b.learned.favourite_area()
	if fav > 0:
		w["favourite"] = 2.0
	var pick := Persona._weighted(Game.rng, w)
	match pick:
		"arcade":
			var ar := _nearest(b, arcades)
			if ar:
				return [Act.GoTo.new(ar, true, false), Act.Do.new(func(bb, dt): return Routine._play_arcade(bb, ar, dt), "playing the arcade")]
		"jukebox":
			var jb := _nearest(b, jukes)
			if jb:
				return [Act.GoTo.new(jb, true, false), Act.Do.new(func(bb, _dt): return Routine._jukebox(bb, jb), "picking a song"), Act.Wait.new(randf_range(8.0, 15.0))]
		"bar":
			var bar := b.area_named("Bar")
			return [Act.GoTo.new(_seat_in(b, bar), false, false), Act.Do.new(func(bb, _dt): return Routine._order_drink(bb), "ordering a drink"), Act.Wait.new(randf_range(12.0, 25.0)),
				Act.Do.new(func(bb, _dt): return Routine._lunch_chat(bb), "chatting at the bar")]
		"noticeboard":
			var nb := _nearest(b, boards)
			if nb:
				return [Act.GoTo.new(nb, true, false), Act.Wait.new(3.0), Act.Do.new(func(bb, _dt): return Routine._noticeboard(bb, nb), "reading the noticeboard")]
		"window":
			var wc := _window_spot(b)
			if wc.x >= 0:
				return [Act.GoTo.new(wc, false, false), Act.Do.new(func(bb, _dt): return Routine._gaze(bb), "looking out of the window"), Act.Wait.new(randf_range(10.0, 20.0))]
		"smoke":
			return _plan_smoke(b)
		"nap":
			var lounge := b.area_named("Crew Lounge")
			if lounge:
				return [Act.GoTo.new(_seat_in(b, lounge), false, false), Act.Do.new(func(bb, _dt): return Routine._doze(bb), "dozing off"), Act.Wait.new(25.0),
					Act.Do.new(func(bb, _dt): return Routine._wake(bb), "waking up")]
		"drink":
			return _plan_hot_drink(b)
		"friend":
			var fr := _friend_to_visit(b)
			if fr:
				return [Act.Talk.new(fr)]
		"favourite":
			var fa: Area = Game.map.areas[fav] if fav >= 0 and fav < Game.map.areas.size() else null
			if fa:
				return [Act.GoTo.new(fa.random_cell(Game.rng), false, false), Act.Do.new(func(bb, _dt): return Routine._hobby(bb), "relaxing"), Act.Wait.new(randf_range(10.0, 18.0))]
		"wander":
			var areas: Array = Game.map.areas.filter(func(a): return not a.outdoor and a.cells.size() > 8 and a.room_kind != "maint" and b.learned.danger_of(a.id) < 0.3 and b.may_enter(a))
			if not areas.is_empty():
				var a: Area = areas[randi() % areas.size()]
				return [Act.GoTo.new(a.random_cell(Game.rng), false, false), Act.Do.new(func(bb, _dt): return Routine._look_around(bb), "looking around")]
	# the default: their hobby, wherever they are
	var spot := b.area_named("Crew Lounge")
	var plan: Array = []
	if spot and Game.map.area_at(b.e.cell) != spot:
		plan.append(Act.GoTo.new(_seat_in(b, spot), false, false))
	plan.append(Act.Do.new(func(bb, _dt): return Routine._hobby(bb), "passing the time"))
	plan.append(Act.Wait.new(randf_range(12.0, 22.0)))
	return plan

static func _friend_to_visit(b: CBrain) -> Entity:
	var best: Entity = null
	var bv := 25.0
	for id in b.memory.rels:
		var a: float = b.memory.rels[id].affinity
		if a > bv:
			var fr := Game.get_entity(id)
			if fr and fr.has_c(&"mob") and fr.c(&"health").stat() == CHealth.CONSCIOUS and fr.dist_to(b.e) < 45:
				var fb: CBrain = fr.c(&"brain")
				if fb and fb.goal.get("score", 0.0) > 350.0:
					continue
				bv = a
				best = fr
	return best

static func _window_spot(b: CBrain) -> Vector2i:
	## A floor tile beside a window that looks out on the glacier, not too far away.
	var best := Vector2i(-1, -1)
	var bd := 1e9
	var map := Game.map
	for k in 400:
		var c := Vector2i(b.e.cell.x + randi_range(-30, 30), b.e.cell.y + randi_range(-30, 30))
		if not map.inb(c) or not Defs.is_window(map.structure[map.idx(c)]):
			continue
		var outside := false
		var inside := Vector2i(-1, -1)
		for d in Defs.DIRS4:
			if map.is_outdoor(c + d):
				outside = true
			elif map.is_passable(c + d) and not map.is_outdoor(c + d):
				inside = c + d
		if outside and inside.x >= 0:
			var dd := Vector2(inside - b.e.cell).length()
			if dd < bd and b.may_enter(map.area_at(inside)):
				bd = dd
				best = inside
	return best

# ------------------------------------------------------------------ leisure steps
static func _play_arcade(bb: CBrain, ar: Entity, dt: float) -> int:
	if not is_instance_valid(ar) or not bb.e.adjacent(ar):
		return ActBase.FAILED
	bb.act_t += dt
	if bb.act_t < 0.1:
		bb.mob.face(Defs.dir_from_vec(ar.cell - bb.e.cell) if ar.cell != bb.e.cell else bb.mob.dir)
		bb.mob.emote("starts playing %s." % ar.the())
		Sfx.play("beep", ar.cell, 0.4)
	if bb.act_t < 9.0:
		return ActBase.RUNNING
	bb.act_t = 0.0
	var skill := randf() * 60.0 + bb.learned.arcade_plays * 3.0 + bb.tv("curiosity") * 10.0
	var score := int(skill * 137.0) + randi() % 500
	bb.learned.arcade_plays += 1
	var best := Routine.arcade_record
	if score > best:
		Routine.arcade_record = score
		Routine.arcade_holder = bb.e.id
		bb.learned.arcade_best = score
		bb.say(Dialogue.line("arcade_win", bb, {}))
		bb.needs.fun = minf(100.0, bb.needs.fun + 40.0)
		bb.ambition_progress("win_arcade")
		if randf() < 0.5 and bb.inv.headset():
			bb.radio_say("Common", "New arcade high score: %d. Come at me, ship." % score)
		Bus.chronicle.emit("%s set a new arcade high score (%d)." % [bb.e.display_name, score], 0)
	else:
		bb.learned.arcade_best = maxi(bb.learned.arcade_best, score)
		if randf() < 0.6:
			bb.say(Dialogue.line("arcade_lose", bb, {}))
		bb.needs.fun = minf(100.0, bb.needs.fun + 22.0)
	return ActBase.DONE

static var arcade_record := 4000
static var arcade_holder := 0

static func _jukebox(bb: CBrain, jb: Entity) -> int:
	if not is_instance_valid(jb) or not bb.e.adjacent(jb):
		return ActBase.FAILED
	var fx: CFixture = jb.c(&"fixture")
	if not fx.on:
		Interact.hand_on(bb.e, jb)
		if randf() < 0.5:
			bb.say(Dialogue.line("music_on", bb, {}))
	else:
		bb.mob.emote(Dialogue.pick(["bobs their head to the music.", "dances a little.", "taps a foot along to the music.", "sways to the beat."]))
	bb.needs.fun = minf(100.0, bb.needs.fun + 18.0)
	bb.learned.soothe(Game.map.area_at(bb.e.cell).id, 0.1)
	return ActBase.DONE

static func _order_drink(bb: CBrain) -> int:
	var drink: String = bb.persona.fav_drink if bb.persona else "vodka"
	if drink.begins_with("water"):
		drink = "water"
	if drink.begins_with("anything"):
		drink = "cocoa"
	# the bartender takes the order if they're behind the bar
	for m in Game.in_radius(bb.e.cell, 7, &"brain"):
		var mb: CBrain = m.c(&"brain")
		if mb.job == "bartender" and mb.health.stat() == CHealth.CONSCIOUS and Game.map.area_at(m.cell) == Game.map.area_at(bb.e.cell):
			bb.say(Dialogue.line("drink_order", bb, {"drink": drink}), {"to": m})
			mb.take_order(bb.e, "drink", drink)
			return ActBase.DONE
	var get = bb.plan_acquire("drink", "drink")
	if get != null and get.size() <= 2:
		get = get.duplicate()
		get.append(Act.Do.new(func(b2, _dt): return Goals._eat_found(b2, "drink"), "drinking"))
		bb.inject_front(get)
	return ActBase.DONE

static func _noticeboard(bb: CBrain, nb: Entity) -> int:
	if not is_instance_valid(nb):
		return ActBase.FAILED
	var st: CStorage = nb.c(&"storage")
	bb.mob.emote("reads the notices on %s." % nb.the())
	bb.needs.fun = minf(100.0, bb.needs.fun + 8.0)
	# react to what's pinned there
	if st and not st.contents.is_empty():
		var paper: Entity = st.contents[randi() % st.contents.size()]
		var text: String = paper.tags.get("text", "")
		if text != "" and randf() < 0.5:
			bb.say_later(Dialogue.pick(["Ha, look at this one.", "Who wrote this?", "Hm. Interesting.", "\"%s\"... okay then." % text.split("\n")[0].substr(0, 40)]), 1.0)
	# and sometimes pin something of their own
	if st and st.contents.size() < 8 and randf() < 0.35 + (0.3 if bb.persona.has_interest("poetry") else 0.0):
		var note := Routine.write_note(bb)
		if note != "":
			var paper2 := Proto.spawn("paper", bb.e.cell)
			paper2.tags["text"] = note
			paper2.display_name = "paper - '%s'" % note.split("\n")[0].substr(0, 24)
			if st.insert(paper2):
				bb.mob.emote("pins a note to %s." % nb.the())
			else:
				paper2.destroy()
	return ActBase.DONE

## Something they'd pin on a noticeboard.
static func write_note(bb: CBrain) -> String:
	var p: Persona = bb.persona
	var sig: String = bb.e.display_name.split(" ")[0]
	var opts := []
	if p.has_interest("poetry"):
		opts.append(Dialogue.pick(["The wind has no home\nit sleeps against the ship\nI know how it feels\n- %s" % sig,
			"Rime on the rigging\nthe stove clicks off again\nI am so cold now\n- %s" % sig,
			"Ode to the Cocoa Kettle\nYou are brown and warm\nand you are out of order\nlike my heart\n- %s" % sig]))
	if p.has_interest("chess"):
		opts.append("CHESS CLUB\nTaproom, after supper. Bring a board if you have one.\nAll levels welcome. - %s" % sig)
	if p.has_interest("gambling"):
		opts.append("CARD NIGHT\nTaproom, end of watch. Buy-in: whatever you've got.\n- %s" % sig)
	if p.has_interest("cryptids"):
		opts.append("HAS ANYONE ELSE HEARD THE KNOCKING?\nThree knocks under the bilge boards. Every night.\nTalk to %s. I'm not crazy." % sig)
	if p.has_interest("conspiracy"):
		opts.append("ASK YOURSELF: why does the ferry never arrive when the ledgers say it does?\nWake up, sailors.")
	if p.has_interest("knitting"):
		opts.append("Free scarves! Tell %s your favourite colour. Wool is limited." % sig)
	if p.has_interest("films"):
		opts.append("PLAY NIGHT\nTaproom, end of watch. Something with a happy ending, I promise. - %s" % sig)
	if p.has_interest("aurora"):
		opts.append("AURORA LOG\nSeen from the rail: %d so far this season.\nAdd yours below. - %s" % [randi_range(12, 60), sig])
	if p.has_quirk("complainer"):
		opts.append("To whoever keeps leaving the %s: STOP. - %s" % [Dialogue.pick(["hatch open", "galley range dirty", "lamps on in the bunkroom", "cocoa kettle empty"]), sig])
	if p.has_quirk("collector"):
		opts.append("WANTED: interesting rocks, odd crystals, anything weird. Will trade. - %s" % sig)
	opts.append("LOST: %s. If found, return to %s (%s). Reward: my eternal gratitude." % [Dialogue.pick(["one glove", "my good pen", "a lucky coin", "my sanity", "a flask"]), sig, Jobs.title(bb.job)])
	if "party" in p.ambitions:
		opts.append("GET-TOGETHER at the taproom, end of watch! Everyone welcome. - %s" % sig)
	if "write_home" in p.ambitions:
		bb.ambition_progress("write_home")
		return ""
	return Dialogue.pick(opts)

static func _gaze(bb: CBrain) -> int:
	var aurora: bool = Routine.aurora_now()
	if aurora:
		bb.say(Dialogue.line("aurora", bb, {}))
		bb.learned.seen_aurora = true
		bb.ambition_progress("see_aurora")
		bb.needs.fun = minf(100.0, bb.needs.fun + 35.0)
		bb.needs.stress = maxf(0.0, bb.needs.stress - 15.0)
	else:
		bb.mob.emote(Dialogue.pick(["stares out at the clouds.", "watches the cloud-wisps blow past the porthole.", "presses a hand to the cold glass.", "gazes out at the horizon."]))
		bb.needs.fun = minf(100.0, bb.needs.fun + 14.0)
		bb.needs.stress = maxf(0.0, bb.needs.stress - 6.0)
	bb.learned.soothe(Game.map.area_at(bb.e.cell).id, 0.12)
	return ActBase.DONE

static func _hobby(bb: CBrain) -> int:
	var p: Persona = bb.persona
	var lines := {"chess": "studies a pocket chess set.", "cooking": "flips through a battered recipe book.", "music": "hums and taps out a rhythm.",
		"aurora": "scribbles in a little logbook.", "geology": "turns a pebble over in their fingers.", "conspiracy": "reads something called 'THE TRUTH ABOUT THE DEEP'.",
		"history": "reads a dog-eared history book.", "fitness": "drops and does a set of pull-ups.", "gambling": "shuffles a deck of cards.",
		"gardening": "checks a tiny potted seedling.", "poetry": "writes something in a notebook, then crosses it out.", "engines": "tinkers with a little spring.",
		"birds": "sketches a bird from memory.", "films": "quotes an old film under their breath.", "knitting": "knits a few rows of a scarf.",
		"religion": "bows their head for a quiet moment.", "cryptids": "listens intently to the floor.", "tea": "sniffs a tin of tea leaves.",
		"sports": "bounces a ball against the wall.", "stars": "traces constellations on a scrap of paper."}
	var opts := []
	for i in p.interests:
		if lines.has(i):
			opts.append(lines[i])
	if opts.is_empty():
		opts = ["stretches.", "leans back and closes their eyes.", "people-watches."]
	bb.mob.emote(Dialogue.pick(opts))
	bb.needs.fun = minf(100.0, bb.needs.fun + 20.0)
	bb.needs.stress = maxf(0.0, bb.needs.stress - 5.0)
	bb.learned.soothe(Game.map.area_at(bb.e.cell).id, 0.08)
	return ActBase.DONE

static func _look_around(bb: CBrain) -> int:
	bb.needs.fun = minf(100.0, bb.needs.fun + 10.0)
	var a := Game.map.area_at(bb.e.cell)
	if not bb.visited.has(a.id):
		bb.visited[a.id] = true
		if randf() < 0.3:
			bb.say_later(Dialogue.pick(["Huh, never been in here before.", "So this is %s." % a.name, "Didn't know this place existed."]), 0.5)
	return ActBase.DONE

static func _doze(bb: CBrain) -> int:
	bb.health.fall_asleep()
	return ActBase.DONE

static func _wake(bb: CBrain) -> int:
	if bb.health.sleeping:
		bb.health.wake()
	bb.needs.energy = minf(100.0, bb.needs.energy + 10.0)
	return ActBase.DONE

static func _plan_smoke(b: CBrain) -> Array:
	# a quiet corner: maintenance, or a spot by a window
	var spot := _window_spot(b)
	var plan := []
	if spot.x >= 0:
		plan.append(Act.GoTo.new(spot, false, false))
	plan.append(Act.Do.new(func(bb, _dt): return Routine._smoke(bb), "smoking"))
	plan.append(Act.Wait.new(12.0))
	return plan

static func _smoke(bb: CBrain) -> int:
	bb.last_smoke = Game.time
	var cig: Entity = bb.inv.find_item(func(x): return x.proto.contains("cig") and x.has_c(&"gadget"))
	if cig and cig.c(&"gadget").kind == "cigarette" and not cig.c(&"gadget").lit:
		var lighter: Entity = bb.inv.find_item(func(x): return x.proto == "lighter")
		if lighter:
			bb.ready_item(cig)
			cig.c(&"gadget").light(bb.e)
	bb.mob.emote(Dialogue.pick(["lights a cigarette.", "takes a long drag.", "blows smoke at the ceiling.", "flicks ash on the floor."]))
	if randf() < 0.3:
		bb.say(Dialogue.line("smoke", bb, {}))
	bb.needs.stress = maxf(0.0, bb.needs.stress - 18.0)
	bb.needs.fun = minf(100.0, bb.needs.fun + 12.0)
	return ActBase.DONE

# ------------------------------------------------------------------ ambitions
static func _ambitions(b: CBrain) -> Array:
	var out := []
	var p: Persona = b.persona
	for a in p.ambitions:
		if p.ambition_done.has(a):
			continue
		match a:
			"see_aurora":
				if Routine.aurora_now() and not b.learned.seen_aurora:
					var wc := _window_spot(b)
					if wc.x >= 0:
						out.append(_g("aurora", 340.0, "running to see the aurora", func(): return [Act.GoTo.new(wc, false, true), Act.Do.new(func(bb, _dt): return Routine._gaze(bb), "watching the aurora"), Act.Wait.new(15.0)],
							{"cooldown": 60.0, "why": "The aurora! Finally!"}))
			"make_friend":
				if b.needs.social < 70:
					var stranger := _stranger(b)
					if stranger:
						out.append(_g("befriend", 140.0, "getting to know %s" % stranger.display_name, func(): return [Act.Talk.new(stranger, "get_to_know")], {"cooldown": 200.0, "why": "I should actually talk to %s." % Dialogue.first(stranger)}))
			"learn_skill":
				var mentor := _mentor_for(b)
				if mentor and b.needs.fun < 70:
					out.append(_g("learn", 110.0, "picking %s's brain" % mentor.display_name, func(): return [Act.GoTo.new(mentor, true, false), Act.Do.new(func(bb, _dt): return Routine._ask_lesson(bb, mentor), "asking for tips")], {"cooldown": 300.0, "why": "%s knows things I don't." % Dialogue.first(mentor)}))
			"collect":
				pass # handled by the collector habit of picking things up (see CBrain.perceive)
			"party":
				if Routine.phase() == "wind_down" and b.inv.headset() and not b.routine_done.has("party_call"):
					out.append(_g("party", 260.0, "rounding people up for a get-together", func(): return [Act.Say.new(Dialogue.pick(["Get-together in the taproom, everyone! Come on!", "Party in the taproom! You've all earned it.", "Taproom. Now. Everyone. It's a party."]), "Common"), Act.GoTo.new(Routine._seat_in(b, b.area_named("Bar")) if b.area_named("Bar") else b.e.cell, false, false)],
						{"on_start": Routine._start_party.bind(b)}))
	# everyone drifts to a party they heard about
	if Routine.party_until > Game.time and b.area_named("Bar") and Game.map.area_at(b.e.cell) != b.area_named("Bar"):
		out.append(_g("join_party", 160.0 * (0.4 + b.tv("sociability")), "heading to the party in the taproom", func(): return [Act.GoTo.new(Routine._seat_in(b, b.area_named("Bar")), false, false), Act.Wait.new(20.0)], {"cooldown": 120.0}))
	return out

static var party_until := 0.0

static func _stranger(b: CBrain) -> Entity:
	for m in Game.in_radius(b.e.cell, 10, &"mob"):
		if m == b.e or m.c(&"health").stat() != CHealth.CONSCIOUS:
			continue
		if b.memory.rel(m.id).familiarity < 25 and not b.is_enemy(m.id):
			if m.has_c(&"brain") and m.c(&"brain").goal.get("score", 0.0) > 300.0:
				continue
			return m
	return null

static func _mentor_for(b: CBrain) -> Entity:
	for m in Game.in_radius(b.e.cell, 12, &"brain"):
		if m == b.e:
			continue
		var skill := Conversation._dept_skill(m.c(&"brain").job)
		if Skills.level(m, skill) > Skills.level(b.e, skill) + 30 and b.affinity(m.id) > -10:
			return m
	return null

static func _ask_lesson(bb: CBrain, mentor: Entity) -> int:
	if not is_instance_valid(mentor) or mentor.dist_to(bb.e) > 2:
		return ActBase.FAILED
	var mb: CBrain = mentor.c(&"brain")
	if mb == null or mb.convo != null:
		return ActBase.FAILED
	bb.say(Dialogue.pick(["Hey, could you show me how you do what you do?", "Got any tips for a beginner?", "Teach me something?"]), {"to": mentor})
	if mb.tv("empathy") + mb.affinity(bb.e.id) / 100.0 > 0.35:
		var skill := Conversation._dept_skill(mb.job)
		mb.say_later(Dialogue.fill(Dialogue.pick(Dialogue.LINES["taught"]), {"tip": Dialogue.tip(skill)}), 2.0)
		Skills.add_xp(bb.e, skill, 40.0)
		bb.learned.mentors[mentor.id] = bb.learned.mentors.get(mentor.id, 0) + 1
		var lessons := 0
		for k in bb.learned.mentors:
			lessons += bb.learned.mentors[k]
		if lessons >= 3:
			bb.ambition_progress("learn_skill")
		bb.bond(mentor, 5.0)
	else:
		mb.say_later(Dialogue.line("busy", mb, {}), 1.5)
	return ActBase.DONE
