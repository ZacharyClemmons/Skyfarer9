class_name Errands extends RefCounted
## Doing what someone asked: fetching and handing over items, treating them, opening a
## door for them, coming over, going somewhere; and filling orders (the bartender's
## drinks, the cook's meals). Scored above routine work, below emergencies, because a
## promise is a promise.

static func candidate(b: CBrain) -> Dictionary:
	var er: Dictionary = b.errand
	var who := Game.get_entity(er.get("for", 0))
	if who == null:
		b.errand = {}
		return {}
	var nm := who.display_name
	var d := {"id": "errand", "score": 520.0, "cooldown": 1.0, "fail_cooldown": 15.0, "why": "I said I'd help %s." % Dialogue.first(who)}
	match er["kind"]:
		"fetch":
			var word: String = er["word"]
			d["desc"] = "fetching %s for %s" % [word, nm]
			d["plan"] = func(): return Errands._plan_fetch(b, who, word)
		"give":
			var it := Game.get_entity(er.get("item", 0))
			if it == null or it.root() != b.e:
				b.errand = {}
				return {}
			d["desc"] = "bringing %s to %s" % [it.display_name, nm]
			d["plan"] = func(): return [Act.GoTo.new(who, true, true), Act.Do.new(func(bb, _dt): return Errands._give(bb, it, who), "handing it over")]
		"treat":
			d["desc"] = "treating %s" % nm
			d["score"] = 560.0
			if Jobs.dept(b.job) == "medical":
				d["plan"] = func(): return JobAI._plan_treat(b, who)
			else:
				d["plan"] = func(): return [Act.GoTo.new(who, true, true), Act.Do.new(func(bb, _dt): return Errands._first_aid(bb, who), "giving first aid")]
		"open":
			var door := Game.get_entity(er.get("door", 0))
			if door == null:
				b.errand = {}
				return {}
			d["desc"] = "opening a door for %s" % nm
			d["plan"] = func(): return [Act.GoTo.new(door, true, true), Act.Do.new(func(bb, _dt): return Errands._open(bb, door), "opening the door"), Act.Wait.new(4.0)]
		"come":
			d["desc"] = "going over to %s" % nm
			d["plan"] = func(): return [Act.GoTo.new(who, true, true), Act.Do.new(func(bb, _dt): return Errands._arrived(bb, who), "")]
		"go":
			var a: Area = Game.map.areas[er["area"]] if er["area"] < Game.map.areas.size() else null
			if a == null:
				b.errand = {}
				return {}
			d["desc"] = "heading to %s as asked" % a.name
			d["plan"] = func(): return [Act.GoTo.new(a.random_cell(Game.rng), false, true), Act.Do.new(func(bb, _dt): return Errands._done(bb), ""), Act.Wait.new(10.0)]
		_:
			b.errand = {}
			return {}
	return d

static func _done(bb: CBrain) -> int:
	bb.errand = {}
	return ActBase.DONE

static func _arrived(bb: CBrain, who: Entity) -> int:
	bb.errand = {}
	bb.say(Dialogue.pick(["What's up?", "Yeah?", "You called?", "Here. What do you need?"]), {"to": who})
	bb.chat_with = who.id
	bb.chat_until = Game.time + PlayerTalk.CHAT_WINDOW
	return ActBase.DONE

static func _plan_fetch(b: CBrain, who: Entity, word: String) -> Array:
	var get = b.plan_acquire_word(word)
	if get == null:
		b.errand = {}
		b.say(Dialogue.pick(["Sorry, I can't find any %s." % word, "No luck finding a %s, sorry." % word, "Couldn't find one anywhere."]), {"to": who} if who.dist_to(b.e) <= 7 else {})
		return [Act.Wait.new(0.5)]
	var plan: Array = get.duplicate()
	plan.append(Act.GoTo.new(who, true, true))
	plan.append(Act.Do.new(func(bb, _dt): return Errands._give_word(bb, word, who), "handing it over"))
	return plan

static func _give_word(bb: CBrain, word: String, who: Entity) -> int:
	var it: Entity = bb.last_acquired if bb.last_acquired and is_instance_valid(bb.last_acquired) and bb.last_acquired.root() == bb.e and SpeechIntent.item_matches(bb.last_acquired, word) else null
	if it == null:
		it = bb.inv.find_item(func(x): return SpeechIntent.item_matches(x, word))
	if it == null:
		return ActBase.FAILED
	return Errands._give(bb, it, who)

static func _give(bb: CBrain, it: Entity, who: Entity) -> int:
	if not bb.e.adjacent(who) and bb.e.dist_to(who) > 1.6:
		bb.inject_front([Act.GoTo.new(who, true, true)])
		return ActBase.DONE
	bb.errand = {}
	bb.say(Dialogue.fill(Dialogue.pick(Dialogue.LINES["give_item"]), {"name": Dialogue.call_name(bb, who)}), {"to": who})
	return ActBase.DONE if bb.give_item(it, who) else ActBase.FAILED

static func _first_aid(bb: CBrain, who: Entity) -> int:
	bb.errand = {}
	if not bb.e.adjacent(who):
		return ActBase.FAILED
	var step := JobAI._treat_step(bb, who)
	if step == ActBase.RUNNING:
		bb.inject_front([Act.Do.new(func(b2, _dt): return JobAI._treat_step(b2, who), "giving first aid")])
	return ActBase.DONE

static func _open(bb: CBrain, door: Entity) -> int:
	bb.errand = {}
	if not is_instance_valid(door) or not bb.e.adjacent(door):
		return ActBase.FAILED
	var dc: CDoor = door.c(&"door")
	if not dc.is_open():
		Interact.hand_on(bb.e, door)
	return ActBase.DONE

# ------------------------------------------------------------------ orders
static func order_candidate(b: CBrain) -> Dictionary:
	# oldest order first; drop ones whose customer left
	while not b.orders.is_empty():
		var o: Dictionary = b.orders[0]
		var who := Game.get_entity(o["who"])
		if who == null or Game.time - o["t"] > 240.0 or who.c(&"health").dead:
			b.orders.pop_front()
			continue
		break
	if b.orders.is_empty():
		return {}
	var o2: Dictionary = b.orders[0]
	var cust := Game.get_entity(o2["who"])
	if o2["kind"] == "drink":
		return {"id": "serve", "score": 460.0, "desc": "pouring a drink for %s" % cust.display_name, "plan": func(): return Errands._plan_drink(b, o2, cust), "cooldown": 1.0, "fail_cooldown": 20.0}
	return {"id": "serve", "score": 450.0, "desc": "cooking for %s" % cust.display_name, "plan": func(): return Errands._plan_meal(b, o2, cust), "cooldown": 1.0, "fail_cooldown": 30.0}

static func _plan_drink(b: CBrain, o: Dictionary, cust: Entity) -> Array:
	var word: String = o.get("what", "")
	if not SpeechIntent.ITEMS.has(word):
		word = "booze" if b.inv.find_item(func(x): return x.proto == "drink_booze") != null else "drink"
	var get = b.plan_acquire_word(word)
	if get == null:
		get = b.plan_acquire("drink", "drink")
	if get == null:
		b.orders.erase(o)
		b.say("Sorry, we're out.", {"to": cust} if cust.dist_to(b.e) <= 7 else {})
		return [Act.Wait.new(0.5)]
	var plan: Array = get.duplicate()
	plan.append(Act.GoTo.new(cust, true, false))
	plan.append(Act.Do.new(func(bb, _dt): return Errands._serve(bb, o, cust, "drink"), "serving"))
	return plan

static func _plan_meal(b: CBrain, o: Dictionary, cust: Entity) -> Array:
	var meal: Entity = b.inv.find_item(func(x): return x.has_c(&"food") and not x.c(&"food").ingredient and not x.c(&"food").drink)
	if meal == null:
		# something already on the cafeteria counter?
		var caf := b.area_named("Cafeteria")
		if caf:
			for c in caf.cells:
				for it in Game.at(c):
					if meal == null and it.has_c(&"food") and not it.c(&"food").ingredient and not it.c(&"food").drink and it.holder == null:
						meal = it
		if meal:
			return [Act.GoTo.new(meal, true, false), Act.PickUp.new(meal), Act.GoTo.new(cust, true, false), Act.Do.new(func(bb, _dt): return Errands._serve(bb, o, cust, "food"), "serving")]
		var cook := JobAI._plan_cook(b)
		if cook.is_empty():
			b.orders.erase(o)
			b.say("Sorry, the kitchen's empty. Nothing to cook with.", {"to": cust} if cust.dist_to(b.e) <= 7 else {})
			return [Act.Wait.new(0.5)]
		# cook, then bring the meal over instead of leaving it on the counter
		while not cook.is_empty() and not (cook[-1] is Act.Do and cook[-1].label == "plating the meal"):
			cook.pop_back()
		cook.append(Act.GoTo.new(cust, true, false))
		cook.append(Act.Do.new(func(bb, _dt): return Errands._serve(bb, o, cust, "food"), "serving"))
		return cook
	return [Act.GoTo.new(cust, true, false), Act.Do.new(func(bb, _dt): return Errands._serve(bb, o, cust, "food"), "serving")]

static func _serve(bb: CBrain, o: Dictionary, cust: Entity, kind: String) -> int:
	bb.orders.erase(o)
	var it: Entity = bb.inv.find_item(func(x): return x.has_c(&"food") and (x.c(&"food").drink if kind == "drink" else (not x.c(&"food").drink and not x.c(&"food").ingredient)))
	if it == null:
		return ActBase.FAILED
	if bb.e.dist_to(cust) > 1.6:
		bb.orders.push_front(o)
		bb.inject_front([Act.GoTo.new(cust, true, false)])
		return ActBase.DONE
	var cat := "drink_serve" if kind == "drink" else "food_serve"
	bb.say(Dialogue.fill(Dialogue.pick(Dialogue.LINES[cat]), {"drink": it.display_name, "food": it.display_name, "name": Dialogue.call_name(bb, cust)}), {"to": cust})
	if bb.give_item(it, cust):
		Skills.add_xp(bb.e, "cooking" if kind == "food" else "social", 8.0)
		if kind == "food" and randf() < 0.2:
			bb.ambition_progress("feed_everyone")
		return ActBase.DONE
	return ActBase.FAILED
