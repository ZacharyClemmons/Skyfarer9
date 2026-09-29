class_name PlayerTalk extends RefCounted
## An NPC answering someone who talks to them (usually the player, sometimes an NPC with
## a request). The reply depends on the intent (SpeechIntent), who's asking (friend,
## stranger, boss, the jerk who punched them earlier), the NPC's job and persona, and
## what they're in the middle of. Replies are "typed" after a short delay, like a person.
## Conversations have memory: a follow-up doesn't need their name, a "yes" answers the
## favor they just asked for, and everything said is remembered.

const CHAT_WINDOW := 35.0

## Which NPC is `speaker` talking to? The one they named, the one they were just talking
## with, or the closest one facing them. Returns null if nobody in particular.
static func addressee(speaker: Entity, text: String, cell: Vector2i, radius: float) -> Entity:
	var t := SpeechIntent.norm(text)
	var near: Array = Game.in_radius(cell, int(radius), &"brain").filter(func(x): return x != speaker and x.c(&"health").stat() == CHealth.CONSCIOUS)
	# 1. called by name up front ("Yara, ...", "hey doc, ...")
	var words := t.strip_edges().split(" ")
	var head := " " + " ".join(words.slice(0, mini(3, words.size()))) + " "
	for m in near:
		if SpeechIntent.names_me(head, m):
			return m
	# 1b. a yes or no answers whoever just asked us something
	var quick := SpeechIntent.norm(text).strip_edges().split(" ").size() <= 4 and (SpeechIntent.has_any(t, SpeechIntent.YES) or SpeechIntent.has_any(t, SpeechIntent.NO))
	if quick:
		var asker: Entity = null
		var at := -1e9
		for m in near:
			var mp: Dictionary = m.c(&"brain").pending
			# the most recent question wins, but the person right next to us counts for more
			var score: float = mp.get("t", 0.0) - m.dist_to(speaker) * 4.0
			if not mp.is_empty() and m.c(&"brain").chat_with == speaker.id and score > at and Game.time - mp.get("t", 0.0) < 45.0:
				at = score
				asker = m
		if asker:
			return asker
	# 2. whoever we're in the middle of talking with
	var best: Entity = null
	var bt := -1.0
	for m in near:
		var mb: CBrain = m.c(&"brain")
		if mb.chat_with == speaker.id and Game.time < mb.chat_until and m.dist_to(speaker) <= 6:
			var recency: float = mb.chat_last + (0.0 if mb.chat_last > 0.0 else mb.chat_until - CHAT_WINDOW - 30.0)
			if recency > bt:
				bt = recency
				best = m
	# a name anywhere else might be vocative ("thanks, Yara") or a subject ("where's Yara?")
	var named: Entity = null
	for m in near:
		if SpeechIntent.names_me(t, m):
			named = m
			break
	if named and named != best:
		var r := SpeechIntent.parse(text, named, speaker)
		if not r["intent"] in ["where_person", "opinion", "report_crime"]:
			return named
	if best:
		return best
	var bd := 99.0
	for m in near:
		var d: float = m.dist_to(speaker)
		if d <= 2.5 and d < bd:
			bd = d
			best = m
	return best

static func respond(b: CBrain, speaker: Entity, text: String) -> void:
	var r := SpeechIntent.parse(text, b.e, speaker)
	var intent: String = r["intent"]
	b.chat_with = speaker.id
	b.chat_until = Game.time + CHAT_WINDOW
	b.chat_last = Game.time
	var rel = b.memory.rel(speaker.id)
	rel.familiarity = minf(100.0, rel.familiarity + 1.5)
	b.needs.social = minf(100.0, b.needs.social + 4.0)
	b.last_heard = {"from": speaker.id, "text": text, "intent": intent, "t": Game.time}
	# they've moved on: drop anything we hadn't got round to saying to them yet
	b.say_queue = b.say_queue.filter(func(q): return q["to"] != speaker)
	Favors.note_talk(speaker, b.e)
	# busy with something that matters: short answers only
	var urgent: float = b.goal.get("score", 0.0)
	if urgent > 600.0 and not intent in ["threat", "insult", "stop", "report_crime", "request_heal", "yes", "no"]:
		if randf() < 0.6:
			b.say_later(Dialogue.pick(["Not now!", "Busy!", "Later!", "Can't talk!", "Kind of in the middle of something!"]), 0.6, speaker)
		return
	# a sworn enemy barely answers
	if b.is_enemy(speaker.id) and not intent in ["apology", "threat", "insult", "report_crime", "accuse", "stop", "go_away"] and randf() < 0.6:
		b.say_later(Dialogue.line("leave_me", b, {}), 1.0, speaker)
		return
	match intent:
		"yes", "no":
			_answer(b, speaker, intent == "yes", r)
		"greet": _greet(b, speaker, r)
		"bye": _bye(b, speaker, r)
		"how_are_you": _how_are_you(b, speaker, r)
		"doing": _doing(b, speaker, r)
		"news": _news(b, speaker, r)
		"about_you": _about_you(b, speaker, r)
		"interests": _interests(b, speaker, r)
		"opinion": _opinion(b, speaker, r)
		"opinion_me": b.say_later(Dialogue.opinion_of_you(b, speaker), -1, speaker)
		"where_person": _where_person(b, speaker, r)
		"where_place": _where_place(b, speaker, r)
		"where_item": _where_item(b, speaker, r)
		"where_unknown": b.say_later(Dialogue.pick(["Where's what?", "Where's who?", "What are you looking for?"]), -1, speaker)
		"request_item": _request_item(b, speaker, r)
		"request_fetch": _request_fetch(b, speaker, r)
		"request_heal": _request_heal(b, speaker, r)
		"request_food": _request_food(b, speaker, r)
		"request_drink": _request_drink(b, speaker, r)
		"request_access": _request_access(b, speaker, r)
		"request_open": _request_open(b, speaker, r)
		"request_fix": _request_fix(b, speaker, r)
		"follow": _follow(b, speaker, r)
		"come_here": _come_here(b, speaker, r)
		"stop": _stop(b, speaker, r)
		"go_away": _go_away(b, speaker, r)
		"go_to": _go_to(b, speaker, r)
		"teach": _teach(b, speaker, r)
		"offer_help": _offer_help(b, speaker, r)
		"report_crime": _report_crime(b, speaker, r)
		"accuse": _accused(b, speaker, r)
		"apology": _apology(b, speaker, r)
		"thanks": _thanks(b, speaker, r)
		"compliment": _compliment(b, speaker, r)
		"insult": _insult(b, speaker, r)
		"threat": _threat(b, speaker, r)
		"joke": _joke(b, speaker, r)
		"ambition": _ambition(b, speaker, r)
		"fear": b.say_later("Honestly? %s. Don't tell anyone." % Dialogue.cap(b.persona.fear) if b.memory.rel(speaker.id).trust > 10 else "Nothing. I'm fine.", -1, speaker)
		"invite": _invite(b, speaker, r)
		"help_general": b.say_later(Dialogue.pick(["With what?", "Sure, what do you need?", "What's wrong?", "Help with what?"]), -1, speaker)
		"topic": _topic(b, speaker, r)
		_: _unknown(b, speaker, r)

# ------------------------------------------------------------------ small talk
static func _greet(b: CBrain, s: Entity, _r: Dictionary) -> void:
	var ep := b.memory.strongest_about(s.id)
	if not ep.is_empty() and ep["intensity"] > 0.4 and ep.get("recalled", 0) < 2:
		ep["recalled"] = ep.get("recalled", 0) + 1
		b.say_later(Dialogue.memory_line(b, ep, s), -1, s)
	else:
		b.say_later(Dialogue.greeting(b, s), -1, s)
	# friendly, chatty people keep it going; some have a favor to ask
	if b.pending.is_empty() and b.affinity(s.id) > -5 and randf() < 0.3:
		_maybe_ask_favor(b, s, 3.5)
	elif randf() < b.tv("sociability") * 0.4:
		b.say_later(Dialogue.pick(["How's your watch going?", "What brings you here?", "Staying warm?", "Busy day?"]), 2.8, s)

static func _bye(b: CBrain, s: Entity, _r: Dictionary) -> void:
	b.say_later(Dialogue.line("bye", b, {}), -1, s)
	b.chat_until = Game.time + 3.0

static func _how_are_you(b: CBrain, s: Entity, _r: Dictionary) -> void:
	b.say_later(Dialogue.status_line(b), -1, s)
	if b.tv("sociability") > 0.5 or b.tv("empathy") > 0.6:
		b.pending = {"kind": "how_are_you", "t": Game.time}

static func _doing(b: CBrain, s: Entity, _r: Dictionary) -> void:
	b.say_later(Dialogue.doing_line(b), -1, s)
	if b.thought != "" and b.tv("honesty") > 0.4 and b.antag.is_empty() and randf() < 0.5:
		b.say_later(b.thought, 2.5, s)

static func _news(b: CBrain, s: Entity, _r: Dictionary) -> void:
	var fs := b._gossip_facts(2, s)
	var delay := -1.0
	if fs.is_empty():
		# no facts: maybe an opinion about someone instead
		var subj := _someone_notable(b, s)
		if subj and b.tv("sociability") > 0.45:
			b.say_later(Dialogue.opinion(b, subj, s), delay, s)
		else:
			b.say_later(Dialogue.line("nothing_new", b, {}), delay, s)
		return
	for f in fs:
		b.say_later(Dialogue.fact_line(b, f), delay, s)
		f["shared_with_%d" % s.id] = true
		delay = 3.0 + randf()

static func _someone_notable(b: CBrain, s: Entity) -> Entity:
	for id in b.learned.rep.keys():
		if id != s.id and not b.learned.headline(id).is_empty():
			var ent := Game.get_entity(id)
			if ent:
				return ent
	return null

static func _about_you(b: CBrain, s: Entity, r: Dictionary) -> void:
	var t: String = r["t"]
	var bio: Array = b.persona.bio_lines(b)
	if t.contains("name"):
		b.say_later("%s. %s." % [b.e.display_name, SkyClasses.title_of(b.e)], -1, s)
		return
	if t.contains("old"):
		b.say_later(Dialogue.pick(["%d. Don't make it weird." % b.persona.age, "Old enough to know better. %d." % b.persona.age]), -1, s)
		return
	if b.memory.rel(s.id).familiarity < 8 and b.tv("sociability") < 0.35:
		b.say_later(Dialogue.pick(["Why do you want to know?", "Just someone doing their job.", "Not much to tell."]), -1, s)
		return
	var d := -1.0
	for i in mini(bio.size(), 3):
		b.say_later(bio[i], d, s)
		d = 3.5 + randf()
	b.told_bio[s.id] = true
	b.memory.rel(s.id).familiarity = minf(100.0, b.memory.rel(s.id).familiarity + 8.0)

static func _interests(b: CBrain, s: Entity, _r: Dictionary) -> void:
	var p: Persona = b.persona
	b.told_bio[s.id] = true
	b.say_later("I'm into %s." % p.interests_text(), -1, s)
	if not p.interests.is_empty():
		b.say_later(p.interest_line(p.interests[randi() % p.interests.size()]), 3.0, s)
	if randf() < 0.4:
		b.say_later("And I love %s. Can't get enough." % p.fav_food, 6.0, s)

static func _opinion(b: CBrain, s: Entity, r: Dictionary) -> void:
	var p: Entity = r["person"]
	if p == null:
		b.say_later(Dialogue.pick(["Who?", "About who?"]), -1, s)
		return
	var line := Dialogue.opinion(b, p, s)
	# discreet people don't badmouth colleagues to strangers
	if b.memory.rel(s.id).trust < -10 and b.tv("honesty") < 0.6:
		line = Dialogue.pick(["Why do you want to know?", "No comment.", "Ask them yourself."])
	b.say_later(line, -1, s)

static func _where_person(b: CBrain, s: Entity, r: Dictionary) -> void:
	var target: Entity = r["person"]
	if target == null:
		b.say_later("Who?", -1, s)
		return
	var nm := Dialogue.first(target)
	if target.c(&"health").dead and b.knowledge.has("body:%d" % target.id):
		b.say_later("%s's... dead. Last I knew the body was in %s." % [nm, Game.map.area_at(b.knowledge.get_fact("body:%d" % target.id)["cell"]).name], -1, s)
		return
	var c := b.knowledge.where_is(target.id)
	if c.x >= 0:
		var ago := int(Game.minutes_since(b.knowledge.get_fact("seen:%d" % target.id)["t"]))
		if target.dist_to(b.e) <= 7 and b._los(b.e.cell, target.cell):
			b.say_later("%s's right there." % nm, -1, s)
		else:
			b.say_later("Last I saw %s, they were in %s%s." % [nm, Game.map.area_at(c).name, "" if ago < 2 else ", about %d minutes ago" % ago], -1, s)
	else:
		var tm: CMob = target.c(&"mob")
		var work: Array = Jobs.JOBS.get(tm.job, {}).get("work", [])
		if not work.is_empty():
			b.say_later("Haven't seen %s. Try %s, that's where %s works." % [nm, work[0], tm.they()], -1, s)
		else:
			b.say_later("I haven't seen %s." % nm, -1, s)

static func _where_place(b: CBrain, s: Entity, r: Dictionary) -> void:
	var a: Area = r["area"]
	b.say_later(Dialogue.directions(s.cell, a), -1, s)
	if a and not a.restricted.is_empty() and not s.c(&"inv").has_access(a.restricted[0]):
		b.say_later("You'll need access to get in, mind.", 3.0, s)

static func _where_item(b: CBrain, s: Entity, r: Dictionary) -> void:
	var word: String = r["item"]
	var best := {}
	var bd := 1e9
	for f in b.knowledge.of_type("item_at"):
		var it := Game.get_entity(f["subject"])
		if it == null or not (SpeechIntent.item_matches(it, word) or (f.get("data", {}).get("vending", "") != "" and _vend_has(it, word))):
			continue
		if it.root().has_c(&"mob"):
			continue
		var c: Vector2i = f["cell"]
		var d := Vector2(c - s.cell).length()
		if d < bd:
			bd = d
			best = f
	if b.inv.find_item(func(x): return SpeechIntent.item_matches(x, word)) != null:
		b.say_later(Dialogue.pick(["I've got one, actually.", "I have one on me.", "Got one right here."]), -1, s)
		b.pending = {"kind": "offer_item", "word": word, "t": Game.time}
		b.say_later("Want it?", 2.0, s)
		return
	if best.is_empty():
		b.say_later(Dialogue.pick(["No idea, sorry.", "Haven't seen one.", "Try the purser? The purser can order anything.", "Try Tool Storage, maybe."]), -1, s)
		return
	var where := Game.map.area_at(best["cell"]).name
	var vend: String = best.get("data", {}).get("vending", "")
	if vend != "":
		b.say_later("The dispenser in %s has some." % where, -1, s)
	else:
		b.say_later(Dialogue.pick(["There's one in %s.", "I saw one in %s.", "Check %s.", "Should be one in %s."]) % where, -1, s)

static func _vend_has(vm: Entity, word: String) -> bool:
	var v = vm.c(&"vending")
	if v == null:
		return false
	for p in v.products:
		if p["count"] > 0 and (p["proto"].contains(SpeechIntent.ITEMS.get(word, ["", word])[1]) or (SpeechIntent.ITEMS.get(word, [""])[0] in ["food", "drink"] and p["proto"].begins_with(SpeechIntent.ITEMS[word][0]))):
			return true
	return false

# ------------------------------------------------------------------ requests
## How willing are they to do something for this person? 0..1+
static func willing(b: CBrain, s: Entity, cost := 0.3) -> float:
	var r = b.memory.rel(s.id)
	var w: float = 0.35 + b.tv("empathy") * 0.4 + r.affinity / 150.0 + r.trust / 250.0 + b.learned.trust_mod(s.id) * 0.3
	if b._is_superior(s):
		w += 0.35
	if b.persona.has_quirk("optimist"):
		w += 0.05
	w -= cost
	w += Skills.level(s, "social") * 0.002
	return w

static func _request_item(b: CBrain, s: Entity, r: Dictionary) -> void:
	var word: String = r["item"]
	var it: Entity = b.inv.find_item(func(x): return SpeechIntent.item_matches(x, word) and not x in b.inv.slots.values())
	if it == null:
		it = b.inv.find_item(func(x): return SpeechIntent.item_matches(x, word))
	if it == null:
		b.say_later(Dialogue.line("dont_have", b, {}), -1, s)
		_where_item(b, s, r)
		return
	var cost := 0.25
	if b.needs_for_job(it):
		cost += 0.45
	if it in b.inv.slots.values():
		cost += 0.3 # the coat off their back
	if r["polite"]:
		cost -= 0.1
	if willing(b, s, cost) > 0.35:
		b.say_later(Dialogue.fill(Dialogue.pick(Dialogue.LINES["give_item"]), {"name": Dialogue.call_name(b, s)}), -1, s)
		b.queue_give(it, s)
	else:
		var why := "I need that for work." if b.needs_for_job(it) else Dialogue.pick(Dialogue.LINES["refuse_item"])
		b.say_later(why, -1, s)

static func _request_fetch(b: CBrain, s: Entity, r: Dictionary) -> void:
	var word: String = r["item"]
	if b.inv.find_item(func(x): return SpeechIntent.item_matches(x, word)) != null:
		_request_item(b, s, r)
		return
	if willing(b, s, 0.45 if not b._is_superior(s) else 0.1) > 0.35 and b.goal.get("score", 0.0) < 300.0:
		b.say_later(Dialogue.pick(["Sure, I'll see what I can find.", "Alright, give me a minute.", "On it."]), -1, s)
		b.errand = {"kind": "fetch", "word": word, "for": s.id, "until": Game.time + 180.0}
		b.think_t = 0.0
	else:
		b.say_later(Dialogue.pick(["Get it yourself.", "I'm busy, sorry.", "Do I look like a hold hand?", "Can't right now."]), -1, s)

static func _request_heal(b: CBrain, s: Entity, _r: Dictionary) -> void:
	var sh: CHealth = s.c(&"health")
	var hurt := sh.health() < 95 or Body.bleed_rate(sh) > 0 or not sh.wounds.is_empty()
	if not hurt:
		b.say_later(Dialogue.pick(["You look fine to me.", "Where does it hurt? You seem alright.", "Hypochondriac, huh? I know the type."]), -1, s)
		return
	if Jobs.dept(b.job) == "medical" or b.can_first_aid(s):
		b.knowledge.learn({"key": "injured:%d" % s.id, "type": "injured", "subject": s.id, "cell": s.cell, "severity": maxi(3, sh.severity())}, Knowledge.HEARD, 1.0, s.id)
		b.errand = {"kind": "treat", "for": s.id, "until": Game.time + 120.0}
		b.say_later(Dialogue.line("coming", b, {}), -1, s)
		b.think_t = 0.0
	else:
		b.say_later(Dialogue.pick(["Get to sickbay, I'll call it in.", "I'm no surgeon. Sickbay, go!", "Hang on, I'll fetch the surgeon."]), -1, s)
		if b.inv.headset():
			b.radio_say("Medical", "%s needs help in %s." % [s.display_name, Game.map.area_at(s.cell).name],
				{"key": "injured:%d" % s.id, "type": "injured", "subject": s.id, "cell": s.cell, "severity": 3})

static func _request_food(b: CBrain, s: Entity, _r: Dictionary) -> void:
	if b.job == "cook":
		b.say_later(Dialogue.pick(["Coming right up.", "One meal, on its way.", "Give me a minute, I'll cook something.", "Sit tight."]), -1, s)
		b.take_order(s, "food", "")
		return
	var food: Entity = b.inv.find_item(func(x): return x.ai_tags().has("food"))
	if food and willing(b, s, 0.3) > 0.3:
		b.say_later(Dialogue.pick(["Here, have this.", "I've got something. Here.", "Take it, I'm not that hungry."]), -1, s)
		b.queue_give(food, s)
		return
	b.say_later(Dialogue.pick(["The galley should have something.", "Ask the cook. Or try the dispensers.", "I'm hungry too. Galley?"]), -1, s)

static func _request_drink(b: CBrain, s: Entity, r: Dictionary) -> void:
	if b.job == "bartender":
		var what: String = r["item"] if r["item"] != "" else "house special"
		b.say_later(Dialogue.pick(["Coming up.", "One %s." % what, "Sure thing.", "Pull up a stool."]), -1, s)
		b.take_order(s, "drink", what)
		return
	var dr: Entity = b.inv.find_item(func(x): return x.ai_tags().has("drink"))
	if dr and willing(b, s, 0.2) > 0.3:
		b.say_later("Here.", -1, s)
		b.queue_give(dr, s)
		return
	b.say_later(Dialogue.pick(["Taproom's that way.", "Ask the publican.", "There's a dispenser around somewhere."]), -1, s)

static func _request_access(b: CBrain, s: Entity, r: Dictionary) -> void:
	if not b.job in ["hop", "captain"]:
		b.say_later(Dialogue.pick(["That's the purser's job.", "Talk to the purser.", "Ask the purser, not me."]), -1, s)
		return
	var sid: Entity = s.c(&"inv").worn("id")
	if sid == null or sid.c(&"idcard") == null:
		b.say_later("You need a passcard first. Where's yours?", -1, s)
		return
	# which department?
	var t: String = r["t"]
	var dept := ""
	for d in Defs.DEPARTMENTS:
		if t.contains(d) or t.contains(Defs.DEPARTMENTS[d]["name"].to_lower()):
			dept = d
	if dept == "" and r["area"] != null:
		dept = (r["area"] as Area).dept
	var aliases := {"engi": "engineering", "med": "medical", "sci": "science", "cargo": "supply", "kitchen": "service", "bar": "service", "hydro": "service", "maint": "civilian", "sec": "security"}
	for k in aliases:
		if dept == "" and SpeechIntent.has_word(t, k):
			dept = aliases[k]
	if dept == "":
		b.say_later("Access to what, exactly?", -1, s)
		b.pending = {"kind": "access_what", "t": Game.time}
		return
	var w := willing(b, s, 0.3 if dept in ["service", "supply", "civilian", "science"] else (0.55 if dept in ["engineering", "medical"] else 0.95))
	if b.learned.rep_of(s.id, "thief") > 0.2 or b.learned.rep_of(s.id, "violent") > 0.2 or SecurityRecords.is_wanted(s.id):
		w -= 0.5
	if dept in ["command"] and b.job != "captain":
		w = 0.0
	if w < 0.35:
		b.say_later(Dialogue.pick(["No. Not with your record.", "Denied. Give me a reason and maybe.", "I can't just hand out access like candy.", "Put in a request. In writing. Denied for now."]), -1, s)
		return
	if s.dist_to(b.e) > 2:
		b.say_later("Come to my desk and I'll sort it out.", -1, s)
		b.pending = {"kind": "access_grant", "dept": dept, "t": Game.time}
		return
	_grant_access(b, s, dept)

static func _grant_access(b: CBrain, s: Entity, dept: String) -> void:
	var sid: Entity = s.c(&"inv").worn("id")
	if sid == null:
		return
	var card = sid.c(&"idcard")
	var add := []
	for job in Jobs.JOBS:
		if Jobs.JOBS[job]["dept"] == dept and not Jobs.JOBS[job].get("head", false):
			for tag in Jobs.JOBS[job]["access"]:
				if not tag in card.access and not tag in ["armory", "command", "captain", "vault"] and not tag in add:
					add.append(tag)
			break
	if add.is_empty():
		b.say_later("You already have everything I can give you there.", -1, s)
		return
	card.access.append_array(add)
	Game.visible_message(b.e.cell, "%s shows %s to the pass console." % [b.e.display_name, sid.the()])
	b.say_later(Dialogue.pick(["Done. Don't make me regret it.", "There you go. Access granted.", "All set. Use it wisely.", "Sorted."]), 1.5, s)
	Bus.chronicle.emit("%s gave %s %s access." % [b.e.display_name, s.display_name, Defs.DEPARTMENTS.get(dept, {}).get("name", dept)], 1)

static func _request_open(b: CBrain, s: Entity, _r: Dictionary) -> void:
	var door: Entity = null
	var bd := 99.0
	for d in Game.in_radius(s.cell, 3, &"door"):
		var dc: CDoor = d.c(&"door")
		if dc.is_open() or dc.external:
			continue
		var dd: float = d.dist_to(s)
		if dd < bd and dc.has_access(b.e):
			bd = dd
			door = d
	if door == null:
		b.say_later(Dialogue.pick(["Which door?", "I can't open that either.", "I don't have access there."]), -1, s)
		return
	var sensitive: bool = Game.map.area_at(door.cell + Vector2i(0, 0)).dept in ["security", "command"]
	var cost := 0.35 + (0.4 if sensitive else 0.0) + (0.3 if b.tv("lawfulness") > 0.65 else 0.0)
	if Jobs.dept(b.job) == "security" and not b._is_superior(s):
		cost += 0.4
	if willing(b, s, cost) > 0.35:
		b.say_later(Dialogue.pick(["Fine, just this once.", "Alright, come on.", "Okay. Don't tell anyone.", "Sure."]), -1, s)
		b.errand = {"kind": "open", "door": door.id, "for": s.id, "until": Game.time + 60.0}
		b.think_t = 0.0
	else:
		b.say_later(Dialogue.pick(["No access, no entry. Sorry.", "I can't do that.", "Nice try.", "Ask your section head."]), -1, s)

static func _request_fix(b: CBrain, s: Entity, r: Dictionary) -> void:
	var t: String = r["t"]
	var a: Area = r["area"] if r["area"] != null else Game.map.area_at(s.cell)
	var fact := {}
	if t.contains("leak"):
		fact = {"key": "told_leak:%d" % a.id, "type": "pipe_leak", "cell": a.center, "severity": 1, "data": {"layer": 0}}
	elif t.contains("breach") or t.contains("window"):
		fact = {"key": "breach@told%d" % a.id, "type": "breach", "cell": a.center, "severity": 3}
	elif t.contains("power") or t.contains("light") or t.contains("dark"):
		if a.apc:
			fact = {"key": "power_out:%d" % a.id, "type": "power_out", "cell": a.apc.cell, "subject": a.apc.id, "area": a.id, "severity": 2}
	elif t.contains("cold") or t.contains("freezing") or t.contains("heat"):
		fact = {"key": "cold:%d" % a.id, "type": "cold_area", "cell": a.center, "area": a.id, "severity": 2}
	else:
		for f in b.knowledge.of_type("broken_machine"):
			if Game.map.area_at(f["cell"]) == a:
				fact = f
	var conf := clampf(0.6 + b.memory.rel(s.id).trust / 200.0 + b.learned.trust_mod(s.id) * 0.3, 0.2, 1.0)
	if Jobs.dept(b.job) == "engineering":
		if fact.is_empty():
			b.say_later("Fix what, where?", -1, s)
			return
		b.knowledge.learn(fact, Knowledge.TOLD, conf, s.id)
		b.say_later(Dialogue.pick(["I'll take a look.", "On it.", "Alright, heading there.", "The engine room's on it."]), -1, s)
		b.think_t = 0.0
	else:
		b.say_later(Dialogue.pick(["I'll let the engine room know.", "Not my crew. I'll call it in.", "Engine room, not me. Hang on."]), -1, s)
		if not fact.is_empty() and b.inv.headset():
			b.radio_say("Engineering" if "Engineering" in b.inv.headset().channels else "Common", "Report of %s." % b.knowledge.describe(fact), fact)

# ------------------------------------------------------------------ orders
static func _follow(b: CBrain, s: Entity, _r: Dictionary) -> void:
	var rel = b.memory.rel(s.id)
	if b._is_superior(s) or rel.affinity > 15 or rel.trust > 20 or b.tv("empathy") > 0.7 or willing(b, s, 0.3) > 0.45:
		b.follow_target = s
		b.follow_until = Game.time + 120.0
		b.think_t = 0.0
		b.say_later(Dialogue.fill(Dialogue.pick(Dialogue.LINES["follow_ok"]), {"name": Dialogue.call_name(b, s)}), -1, s)
	else:
		b.say_later(Dialogue.line("refuse", b, {}), -1, s)

static func _come_here(b: CBrain, s: Entity, _r: Dictionary) -> void:
	if willing(b, s, 0.2) > 0.3 or b._is_superior(s):
		b.errand = {"kind": "come", "for": s.id, "until": Game.time + 40.0}
		b.think_t = 0.0
		b.say_later(Dialogue.pick(["Coming.", "What is it?", "On my way.", "Yeah?"]), -1, s)
	else:
		b.say_later(Dialogue.pick(["You come here.", "Why?", "I'm busy."]), -1, s)

static func _stop(b: CBrain, s: Entity, _r: Dictionary) -> void:
	b.follow_target = null
	b.errand = {}
	if b.goal.get("score", 0.0) > 700.0 and not b._is_superior(s):
		b.say_later("Can't, this is urgent!", -1, s)
		return
	b.plan.clear()
	b.action = null
	b.goal_cooldowns["_all"] = Game.time + 10.0
	b.say_later(Dialogue.line("ok", b, {}), -1, s)

static func _go_away(b: CBrain, s: Entity, _r: Dictionary) -> void:
	b.follow_target = null
	b.chat_until = 0.0
	b.bond(s, -2.0)
	b.say_later(Dialogue.pick(["Fine.", "Rude.", "Okay, okay.", "Whatever."]), -1, s)
	b.avoid_until[s.id] = Game.time + 90.0

static func _go_to(b: CBrain, s: Entity, r: Dictionary) -> void:
	var a: Area = r["area"]
	if a == null:
		b.say_later("Go where?", -1, s)
		return
	if b._is_superior(s) or willing(b, s, 0.5) > 0.4:
		b.errand = {"kind": "go", "area": a.id, "for": s.id, "until": Game.time + 90.0}
		b.think_t = 0.0
		b.say_later(Dialogue.pick(["Heading to %s." % a.name, "On my way.", "Alright, going."]), -1, s)
	else:
		b.say_later(Dialogue.pick(["You're not my boss.", "Why?", "I'll pass."]), -1, s)

# ------------------------------------------------------------------ teaching, help
static func _teach(b: CBrain, s: Entity, r: Dictionary) -> void:
	var skill: String = r["skill"]
	if skill == "":
		skill = Conversation._dept_skill(b.job)
	var lvl := Skills.level(b.e, skill if Skills.SKILLS.has(skill) else "melee" if skill == "security" else skill)
	if skill == "security":
		lvl = Skills.level(b.e, "melee")
	var tip := Dialogue.tip(skill)
	if tip == "" or (lvl < 25 and Conversation._dept_skill(b.job) != skill):
		b.say_later(Dialogue.line("cant_teach", b, {}), -1, s)
		return
	if willing(b, s, 0.15) < 0.25:
		b.say_later(Dialogue.pick(["Figure it out yourself.", "I'm not your teacher.", "Read a manual."]), -1, s)
		return
	b.say_later(Dialogue.fill(Dialogue.pick(Dialogue.LINES["taught"]), {"tip": tip}), -1, s)
	var xs := skill if Skills.SKILLS.has(skill) else "melee"
	var taught: int = b.taught.get(s.id, 0)
	b.taught[s.id] = taught + 1
	if taught < 4:
		Skills.add_xp(s, xs, 30.0 + lvl * 0.4)
	if s == Game.player and taught == 0:
		Game.tell(s, "[color=#9ab8d8]%s shows you a thing or two about %s.[/color]" % [b.e.display_name, Skills.SKILLS.get(xs, {"name": xs})["name"].to_lower()], "info")

static func _offer_help(b: CBrain, s: Entity, _r: Dictionary) -> void:
	if not _maybe_ask_favor(b, s, -1.0, true):
		b.say_later(Dialogue.pick(["I'm good, thanks.", "Nah, all good. Thanks though.", "Not right now. Appreciate it.", "Actually, no. Everything's fine for once."]), -1, s)

## Ask `s` for a favor if there's something we want. Returns true if asked.
static func _maybe_ask_favor(b: CBrain, s: Entity, delay := -1.0, forced := false) -> bool:
	if not Favors.offered_by(b.e.id, s.id).is_empty():
		var f := Favors.offered_by(b.e.id, s.id)
		if forced:
			b.say_later("Still need you to %s, if you can." % f["desc"], delay, s)
			if f["state"] == "offered":
				b.pending = {"kind": "favor", "id": f["id"], "t": Game.time}
			return true
		return false
	if not forced and Game.time - b.last_favor_ask < 300.0:
		return false
	var spec := Favors.want_of(b, s)
	if spec.is_empty():
		return false
	b.last_favor_ask = Game.time
	var extra := {"want": spec.get("want", ""), "target": spec.get("target", 0), "item_id": spec.get("item_id", 0), "reward": "item" if randf() < 0.35 else ""}
	var f2 := Favors.make(b.e, s, spec["kind"], spec["desc"], extra)
	b.pending = {"kind": "favor", "id": f2["id"], "t": Game.time}
	b.say_later(Favors.ask_line(b, spec, s), delay, s)
	b.chat_last = Game.time
	return true

static func _answer(b: CBrain, s: Entity, yes: bool, _r: Dictionary) -> void:
	var p: Dictionary = b.pending
	if p.is_empty() or Game.time - p.get("t", 0.0) > 45.0:
		b.say_later(Dialogue.pick(["Okay?", "...alright.", "Cool.", "Mm-hm."]) if yes else Dialogue.pick(["No what?", "Okay.", "...fine."]), -1, s)
		return
	b.pending = {}
	match p["kind"]:
		"favor":
			var f := Favors.get_favor(p["id"])
			if f.is_empty():
				return
			if yes:
				f["state"] = "accepted"
				f["expires"] = Game.time + 600.0
				b.say_later(Dialogue.pick(["Thanks! You're a lifesaver.", "Brilliant, thank you.", "Great, I owe you one.", "Appreciate it."]), -1, s)
				if f["kind"] == "deliver":
					var it := Game.get_entity(f["item_id"])
					if it and it.root() == b.e:
						b.queue_give(it, s)
				if s == Game.player:
					Game.tell(s, "[color=#9ab8d8]Favor for %s: %s. (Objectives, O)[/color]" % [b.e.display_name, f["desc"]], "info")
			else:
				f["state"] = "failed"
				b.say_later(Dialogue.line("favor_decline_ok", b, {}) if b.tv("empathy") > 0.35 else Dialogue.pick(["Figures.", "Right. Thanks for nothing."]), -1, s)
				if b.tv("empathy") < 0.35:
					b.bond(s, -2.0)
		"offer_item":
			if yes:
				var it2: Entity = b.inv.find_item(func(x): return SpeechIntent.item_matches(x, p["word"]))
				if it2 and willing(b, s, 0.2 + (0.4 if b.needs_for_job(it2) else 0.0)) > 0.3:
					b.say_later(Dialogue.pick(["Here.", "Take it.", "All yours."]), -1, s)
					b.queue_give(it2, s)
				else:
					b.say_later("Actually, I need it. Sorry.", -1, s)
			else:
				b.say_later("Suit yourself.", -1, s)
		"how_are_you":
			b.say_later(Dialogue.pick(["Good to hear.", "Glad someone's doing well.", "Ha, same."]) if yes else Dialogue.pick(["Hang in there.", "Yeah, it's that kind of watch."]), -1, s)
		"access_grant":
			if yes and s.dist_to(b.e) <= 2:
				_grant_access(b, s, p["dept"])
		"invite":
			if yes:
				b.make_plan(p["what"], p["where"], s)
				b.say_later("Great, see you there.", -1, s)
			else:
				b.say_later("Another time then.", -1, s)
		_:
			b.say_later(Dialogue.line("ok", b, {}), -1, s)

# ------------------------------------------------------------------ social
static func _report_crime(b: CBrain, s: Entity, r: Dictionary) -> void:
	var culprit: Entity = r["person"]
	if culprit == null:
		return
	var t: String = r["t"]
	var crime := "assault"
	if t.contains("stole") or t.contains("robbed") or t.contains("took"):
		crime = "theft"
	elif t.contains("killed") or t.contains("murder"):
		crime = "murder"
	elif t.contains("broke into"):
		crime = "break_in"
	elif t.contains("traitor"):
		crime = "sabotage"
	var trust := clampf(0.55 + b.memory.rel(s.id).trust / 200.0 + b.learned.trust_mod(s.id) * 0.4 - b.affinity(culprit.id) / 250.0, 0.1, 1.0)
	var victim := s.id if t.contains(" me ") or t.ends_with(" me ") else 0
	var f := {"key": "crime:%s:%d" % [crime, culprit.id], "type": "crime", "subject": culprit.id, "cell": s.cell, "severity": 5 if crime == "murder" else 3,
		"data": {"crime": crime, "actor": culprit.id, "victim": victim, "told_by": s.id}}
	var nm := Dialogue.first(culprit)
	if b.is_friend(culprit.id) and b.tv("loyalty") > 0.6:
		b.say_later(Dialogue.pick(["%s? No way. I don't believe you." % nm, "That doesn't sound like %s." % nm, "You must be mistaken."]), -1, s)
		b.knowledge.learn(f, Knowledge.TOLD, trust * 0.4, s.id)
		return
	b.knowledge.learn(f, Knowledge.TOLD, trust, s.id)
	b.learned.hear_rep(culprit.id, "violent" if crime in ["assault", "murder"] else "thief", 0.6, trust)
	if Jobs.dept(b.job) == "security":
		b.say_later(Dialogue.pick(["I'll look into it.", "Noted. We'll deal with %s." % nm, "Right. Where did this happen?", "Leave it with security."]), -1, s)
		b.think_t = 0.0
	elif trust > 0.5 and b.inv.headset() and "Security" in b.inv.headset().channels:
		b.say_later("I'll pass it on.", -1, s)
	else:
		b.say_later(Dialogue.pick(["You should tell security.", "Report it to security. Seriously.", "%s? Yikes. Go to security." % nm]), -1, s)

static func _accused(b: CBrain, s: Entity, _r: Dictionary) -> void:
	var guilty := not b.knowledge.of_type("my_crime").is_empty() or not b.antag.is_empty()
	if guilty and b.tv("honesty") > 0.7:
		b.say_later(Dialogue.line("accused_guilty", b, {}), -1, s)
	elif guilty:
		b.say_later(Dialogue.line("accused_deny", b, {}), -1, s)
		if b.tv("honesty") < 0.3 and randf() < 0.5:
			var sc := b._disliked_person()
			if sc and sc != s:
				b.say_later("If you want a suspect, look at %s." % Dialogue.first(sc), 2.5, s)
	else:
		b.say_later(Dialogue.pick(["What?! I didn't do anything!", "Are you insane?", "That's ridiculous.", "Who told you that?"]), -1, s)
		b.bond(s, -6.0)
		b.anger = minf(1.0, b.anger + 0.15)

static func _apology(b: CBrain, s: Entity, _r: Dictionary) -> void:
	var grievance := false
	for ep in b.memory.episodes:
		if ep["actor"] == s.id and ep["valence"] < -0.2 and Game.time - ep["t"] < 1200.0:
			grievance = true
	if not grievance:
		b.say_later(Dialogue.pick(["For what?", "It's fine. What for, though?", "No harm done."]), -1, s)
		return
	if b.tv("empathy") + b.affinity(s.id) / 100.0 + randf() * 0.3 > 0.5:
		b.say_later(Dialogue.line("apology_accept", b, {}), -1, s)
		b.bond(s, 8.0)
		b.memory.rel(s.id).trust = clampf(b.memory.rel(s.id).trust + 5.0, -100, 100)
		b.anger = maxf(0.0, b.anger - 0.3)
	else:
		b.say_later(Dialogue.line("apology_reject", b, {}), -1, s)

static func _thanks(b: CBrain, s: Entity, _r: Dictionary) -> void:
	b.bond(s, 2.0)
	b.say_later(Dialogue.line("welcome", b, {}), -1, s)

static func _compliment(b: CBrain, s: Entity, _r: Dictionary) -> void:
	var r = b.memory.rel(s.id)
	var n: int = b.compliments.get(s.id, 0)
	b.compliments[s.id] = n + 1
	if r.affinity < -20 or (n > 3 and b.tv("honesty") > 0.5):
		b.say_later(Dialogue.line("complimented_cold", b, {}), -1, s)
		return
	b.bond(s, maxf(0.5, 5.0 - n * 1.5))
	b.needs.fun = minf(100.0, b.needs.fun + 4.0)
	b.say_later(Dialogue.line("complimented", b, {}), -1, s)

static func _insult(b: CBrain, s: Entity, _r: Dictionary) -> void:
	var n: int = b.insults.get(s.id, 0)
	b.insults[s.id] = n + 1
	b.memory.remember("insulted_me", s.id, b.e.id, "%s insulted me." % s.display_name, 0.6 + n * 0.2)
	b.bond(s, -6.0 - n * 3.0)
	b.anger = minf(1.0, b.anger + 0.12 * (0.5 + b.tv("aggression")))
	b.learned.note(s.id, "kind", -0.1)
	var cat := "insulted"
	if b.tv("aggression") > 0.6:
		cat = "insulted_mad"
	elif b.tv("neuroticism") > 0.6 or b.tv("bravery") < 0.35:
		cat = "insulted_hurt"
	b.say_later(Dialogue.line(cat, b, {}), -1, s)
	# the hot-headed only take so much
	if n >= 2 and b.tv("aggression") > 0.7 and b.tv("lawfulness") < 0.5 and s.dist_to(b.e) <= 1.5:
		b.lash_out(s, "shove")

static func _threat(b: CBrain, s: Entity, _r: Dictionary) -> void:
	b.memory.remember("insulted_me", s.id, b.e.id, "%s threatened me." % s.display_name, 1.0)
	b.bond(s, -15.0)
	b.learned.note(s.id, "violent", 0.2)
	b.learned.note(s.id, "creepy", 0.2)
	var scared := b.tv("bravery") < 0.5
	b.fear = minf(1.0, b.fear + (0.4 if scared else 0.1))
	b.say_later(Dialogue.line("threatened_scared" if scared else "threatened", b, {}), -1, s)
	if b.inv.headset() and (b.tv("lawfulness") > 0.4 or scared):
		b.radio_say("Security" if "Security" in b.inv.headset().channels else "Common", "%s just threatened to kill me in %s!" % [s.display_name, Game.map.area_at(b.e.cell).name],
			{"key": "crime:threat:%d" % s.id, "type": "crime", "subject": s.id, "cell": s.cell, "severity": 2, "data": {"crime": "assault", "actor": s.id, "victim": b.e.id, "what": "threats"}})
	# everyone nearby heard it
	for m in Game.in_radius(s.cell, 6, &"brain"):
		if m != b.e:
			m.c(&"brain").learned.note(s.id, "creepy", 0.1)

static func _joke(b: CBrain, s: Entity, _r: Dictionary) -> void:
	if b.tv("humor") < 0.3:
		b.say_later(Dialogue.pick(["I don't really do jokes.", "Life in the sky. That's the joke.", "No."]), -1, s)
		return
	b.say_later(Dialogue.pick(Dialogue.LINES["joke"]), -1, s)

static func _ambition(b: CBrain, s: Entity, _r: Dictionary) -> void:
	var p: Persona = b.persona
	if p.ambitions.is_empty():
		b.say_later("Just get through the watch, honestly.", -1, s)
		return
	var a: String = p.ambitions[0]
	if p.ambition_done.has(a):
		b.say_later("I already did what I set out to do this voyage: %s. Feels good." % p.ambition_text(a), -1, s)
	else:
		b.say_later(p.ambition_line(a), -1, s)

static func _invite(b: CBrain, s: Entity, r: Dictionary) -> void:
	var t: String = r["t"]
	var what := "bar" if t.contains("drink") or t.contains("bar") else ("lunch" if t.contains("lunch") or t.contains("eat") or t.contains("food") or t.contains("bite") else "break")
	var where: String = {"bar": "Bar", "lunch": "Cafeteria", "break": "Crew Lounge"}[what]
	if willing(b, s, 0.2) > 0.35 and b.goal.get("score", 0.0) < 400.0:
		b.say_later(Dialogue.pick(["Sure, I'd like that.", "Why not. Lead the way.", "Yeah! Meet you there.", "Go on then."]), -1, s)
		b.make_plan(what, where, s)
	else:
		b.say_later(Dialogue.pick(["Maybe later.", "Can't, too busy.", "I'll pass.", "Another time."]), -1, s)

static func _topic(b: CBrain, s: Entity, r: Dictionary) -> void:
	var k: String = r.get("topic", "")
	if b.persona.has_interest(k):
		b.say_later(Dialogue.pick(["Oh, you're into %s? Me too!", "%s! Finally, someone who gets it.", "Did someone say %s?"]) % b.persona.interest_label(k), -1, s)
		b.say_later(b.persona.interest_line(k), 3.0, s)
		b.bond(s, 4.0)
	else:
		b.say_later(Dialogue.pick(["Not really my thing.", "Huh. Okay.", "Can't say I know much about %s." % b.persona.interest_label(k)]), -1, s)

static func _unknown(b: CBrain, s: Entity, r: Dictionary) -> void:
	if r["question"]:
		b.say_later(Dialogue.pick(["I don't know.", "No idea.", "Couldn't tell you.", "Good question.", "Hm. Not sure.", "Beats me."]), -1, s)
	elif b.tv("sociability") > 0.5 and randf() < 0.5:
		b.say_later(Dialogue.pick(["Ha, yeah.", "Right?", "Mm-hm.", "True.", "Heh."]), -1, s)
	else:
		b.say_later(Dialogue.line("confused", b, {}), -1, s)

## Something said nearby that wasn't meant for us, but we heard it.
static func overhear(b: CBrain, speaker: Entity, text: String) -> void:
	var t := SpeechIntent.norm(text)
	if SpeechIntent.has_any(t, SpeechIntent.INSULTS) or SpeechIntent.has_frag(t, SpeechIntent.THREATS):
		b.learned.note(speaker.id, "kind", -0.04)
		if SpeechIntent.has_frag(t, SpeechIntent.THREATS):
			b.learned.note(speaker.id, "creepy", 0.08)
	if t.contains(" help ") or t.contains(" fire ") or t.contains(" medic ") or t.contains(" security "):
		b._parse_player_radio(speaker, "", text)
	# someone mentioned our interest in passing
	for k in b.persona.interests:
		if SpeechIntent.has_word(t, k) and b.tv("sociability") > 0.55 and randf() < 0.35 and b.goal.get("score", 0.0) < 250.0:
			b.say_later("Did someone say %s?" % b.persona.interest_label(k), 1.5, speaker)
			b.chat_with = speaker.id
			b.chat_until = Game.time + CHAT_WINDOW
			return
