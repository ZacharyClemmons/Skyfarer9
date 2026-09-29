class_name Conversation extends RefCounted
## A real back-and-forth between two NPCs, typed out line by line at human speed so you
## can overhear it. The topic comes out of who they are and what's on their minds:
## gossip about the fire, a shared love of chess, one venting about their boss and the
## other sympathising (or not), a joke that lands or dies, consoling a friend who lost
## someone, an argument between two people who can't stand each other, what they think
## of a third person (often you), plans for lunch, a head of staff showing a junior the
## ropes. Each line can carry an effect: knowledge passed on, a reputation spread, an
## interest picked up, a friendship deepened or soured, a plan made.

var a: Entity
var b: Entity
var ba: CBrain
var bb: CBrain
var topic := ""
var lines: Array = [] # [{who 0/1, text, fx Callable}]
var i := 0
var t := 0.0
var done := false
var good := true
var started := 0.0
var end_reason := ""
static var debug := false

const TOPICS := ["gossip", "interest", "complain", "joke", "console", "grieve", "argue", "about_person", "plan", "work", "mentor", "event", "get_to_know", "smalltalk"]

static func begin(from: Entity, to: Entity, forced_topic := "") -> Conversation:
	# Port traders keep their own counsel (CVendor.idle). The crew conversation system was
	# written for a research station and has them asking each other what is under all this
	# ice, on a temperate island two thousand feet up that has never seen any.
	if from.tags.get("no_smalltalk", false) or to.tags.get("no_smalltalk", false):
		return null
	var c := Conversation.new()
	c.a = from
	c.b = to
	c.ba = from.c(&"brain")
	c.bb = to.c(&"brain")
	c.started = Game.time
	c.topic = forced_topic if forced_topic != "" else c._choose_topic()
	c._chemistry()
	c._build()
	c.t = 0.4
	c.ba.convo = c
	if c.bb:
		c.bb.convo = c
		c.bb.think_t = 0.0
	return c

func _chemistry() -> void:
	if bb == null:
		return
	var chem := 1.0 - absf(ba.tv("aggression") - bb.tv("aggression")) - absf(ba.tv("humor") - bb.tv("humor")) * 0.5
	chem += (ba.tv("sociability") + bb.tv("sociability")) * 0.3 - 0.5
	chem += ba.persona.shared_interests(bb.persona).size() * 0.25
	good = randf() < clampf(0.55 + chem * 0.4 + ba.affinity(b.id) / 200.0 + bb.affinity(a.id) / 200.0, 0.08, 0.95)

func _choose_topic() -> String:
	if bb == null:
		return "smalltalk"
	var w := {}
	var aff := ba.affinity(b.id)
	var fam: float = ba.memory.rel(b.id).familiarity
	w["smalltalk"] = 1.0
	if not ba._gossip_facts(1, b).is_empty():
		w["gossip"] = 3.0 * (0.5 + ba.tv("sociability")) * (2.0 if ba.persona.has_quirk("gossip") else 1.0)
	var shared := ba.persona.shared_interests(bb.persona)
	w["interest"] = 1.0 + shared.size() * 3.0
	if ba.needs.stress > 45 or ba.persona.has_quirk("complainer"):
		w["complain"] = 1.5 + ba.needs.stress / 50.0 + (2.0 if ba.persona.has_quirk("complainer") else 0.0)
	if ba.tv("humor") > 0.55:
		w["joke"] = ba.tv("humor") * 2.5
	if (bb.needs.stress > 60 or bb.grief > 0.3) and ba.tv("empathy") > 0.45 and aff > -10:
		w["console"] = 5.0
	if ba.grief > 0.3 and aff > 0:
		w["grieve"] = 4.0
	if aff < -25:
		w["argue"] = 2.0 + ba.tv("aggression") * 3.0 + ba.anger * 3.0
		w["smalltalk"] = 0.2
	if not _rep_subject().is_empty():
		w["about_person"] = 2.0 * (0.5 + ba.tv("sociability"))
	if aff > 5 and Routine.phase() in ["late_morning", "lunch", "afternoon", "wind_down"]:
		w["plan"] = 1.2 + (1.5 if ba.needs.fun < 40 else 0.0)
	if Jobs.dept(ba.job) == Jobs.dept(bb.job):
		w["work"] = 2.0
		if Jobs.is_head(ba.job) and not Jobs.is_head(bb.job):
			w["mentor"] = 3.0
	if not _recent_event().is_empty():
		w["event"] = 3.0
	if fam < 35:
		w["get_to_know"] = 3.0
	return Persona._weighted(Game.rng, w)

func _rep_subject() -> Dictionary:
	# someone notable the speaker has an opinion about (the player first)
	var best := {}
	var bv := 0.2
	for id in ba.learned.rep.keys():
		if id == b.id or id == a.id:
			continue
		var h: Array = ba.learned.headline(id)
		if h.is_empty():
			continue
		var v: float = absf(h[1]) + (0.2 if Game.player and id == Game.player.id else 0.0)
		if v > bv:
			var ent := Game.get_entity(id)
			if ent:
				bv = v
				best = {"id": id, "key": h[0], "v": h[1], "ent": ent}
	return best

func _recent_event() -> Dictionary:
	var best := {}
	var bv := 0.45
	for ep in ba.memory.episodes:
		if Game.time - ep["t"] > 900.0:
			continue
		if ep["type"] in ["good_chat", "bad_chat", "ordered_me", "joked"]:
			continue
		if ep["intensity"] > bv:
			bv = ep["intensity"]
			best = ep
	return best

func L(who: int, text: String, fx := Callable()) -> void:
	lines.append({"who": who, "text": text, "fx": fx})

# ------------------------------------------------------------------ scripts
func _build() -> void:
	var recently: bool = ba.last_talked.get(b.id, -999.0) > Game.time - 150.0
	if not recently and topic != "argue":
		L(0, Dialogue.greeting(ba, b))
		if bb:
			L(1, Dialogue.greeting(bb, a) if randf() < 0.6 else Dialogue.pick(["Hey.", "Oh, hi.", "Hi!", "Hey, what's up?", "Mm?"]))
	if bb == null:
		L(0, Dialogue.smalltalk(ba, b))
		return
	match topic:
		"gossip": _gossip()
		"interest": _interest()
		"complain": _complain()
		"joke": _joke()
		"console": _console()
		"grieve": _grieve()
		"argue": _argue()
		"about_person": _about_person()
		"plan": _plan()
		"work": _work()
		"mentor": _mentor()
		"event": _event()
		"get_to_know": _get_to_know()
		_: _smalltalk()
	if topic != "argue" and randf() < 0.55:
		L(0, Dialogue.line("bye", ba, {}))
		if randf() < 0.5:
			L(1, Dialogue.line("bye", bb, {}))

func _smalltalk() -> void:
	L(0, Dialogue.smalltalk(ba, b))
	L(1, Dialogue.reply(bb, a, good))
	if good and randf() < 0.5:
		L(1, Dialogue.smalltalk(bb, a))
		L(0, Dialogue.reply(ba, b, true))

func _gossip() -> void:
	var facts := ba._gossip_facts(2, b)
	for f in facts:
		var ff: Dictionary = f
		var sent: Dictionary = f.duplicate()
		f["shared_with_%d" % b.id] = true
		var conf: float = ba.knowledge.get_fact(f["key"]).get("conf", 1.0) * 0.85
		L(0, Dialogue.fact_line(ba, ff), func(): bb.hear_gossip(a, sent, conf))
		L(1, Dialogue.fact_reaction(bb, ff))
	# guilty consciences: liars deflect onto someone they dislike
	for my in ba.knowledge.of_type("my_crime"):
		if ba.tv("honesty") < 0.3 and randf() < 0.3:
			var scapegoat := ba._disliked_person()
			if scapegoat and scapegoat != b:
				var lie := {"key": "crime:%s:%d" % [my["data"]["crime"], scapegoat.id], "type": "crime", "subject": scapegoat.id, "cell": my["cell"], "severity": 2,
					"data": {"crime": my["data"]["crime"], "actor": scapegoat.id, "victim": my["data"].get("victim", 0), "lie_by": a.id}}
				L(0, Dialogue.fact_line(ba, lie), func(): bb.hear_gossip(a, lie, 0.6))
				L(1, Dialogue.fact_reaction(bb, lie))
				break
	if lines.size() < 3:
		_smalltalk()

func _interest() -> void:
	var shared := ba.persona.shared_interests(bb.persona)
	var id: String = shared[randi() % shared.size()] if not shared.is_empty() else ba.persona.interests[randi() % ba.persona.interests.size()]
	var is_shared := id in bb.persona.interests
	var curious := bb.tv("curiosity") > 0.55 and good
	L(0, Dialogue.interest_chat(ba, id, is_shared))
	L(1, Dialogue.interest_response(bb, id, is_shared, curious), func():
		if is_shared:
			ba.bond(b, 4.0)
			bb.bond(a, 4.0)
		elif curious and randf() < 0.35 and bb.persona.interests.size() < 5:
			# picked up a new interest from a friend
			bb.persona.interests.append(id)
			bb.learned.picked_up.append(id)
			bb.memory.remember("good_chat", a.id, a.id, "%s got me into %s." % [a.display_name, bb.persona.interest_label(id)], 0.8))
	if is_shared:
		L(1, bb.persona.interest_line(id))
		L(0, Dialogue.pick(["Exactly!", "Ha! Yes.", "We should do that together sometime.", "You get it."]))
	elif good and randf() < 0.5:
		L(0, ba.persona.interest_line(id))

func _complain() -> void:
	L(0, Dialogue.complaint(ba))
	var sym := good or bb.tv("empathy") > 0.6
	L(1, Dialogue.sympathy(bb, sym), func():
		if sym:
			ba.needs.stress = maxf(0.0, ba.needs.stress - 6.0)
			ba.bond(b, 2.0)
		else:
			ba.bond(b, -3.0))
	if sym and randf() < 0.5:
		L(1, Dialogue.complaint(bb))
		L(0, Dialogue.sympathy(ba, true))

func _joke() -> void:
	L(0, Dialogue.pick(Dialogue.LINES["joke"]))
	var laughs := good and bb.tv("humor") > 0.35
	L(1, Dialogue.pick(Dialogue.LINES["joke_laugh" if laughs else "joke_groan"]), func():
		ba.learned.note(a.id, "funny", 0.0)
		bb.learned.note(a.id, "funny", 0.12 if laughs else -0.05)
		if laughs:
			bb.needs.fun = minf(100.0, bb.needs.fun + 10.0)
			ba.needs.fun = minf(100.0, ba.needs.fun + 6.0)
			bb.bond(a, 3.0)
		# bystanders with a sense of humour chime in
		for m in Game.in_radius(a.cell, 3, &"brain"):
			if m != a and m != b and randf() < m.c(&"brain").tv("humor") * 0.5:
				m.c(&"brain").say_later(Dialogue.pick(Dialogue.LINES["joke_laugh"] if laughs else Dialogue.LINES["joke_groan"]), 1.4)
				break)
	if laughs and randf() < 0.4:
		L(1, Dialogue.pick(Dialogue.LINES["joke"]))
		L(0, Dialogue.pick(Dialogue.LINES["joke_laugh"]))

func _console() -> void:
	var nm := Dialogue.call_name(ba, b)
	if bb.grief > 0.3:
		var dead := Game.get_entity(bb.grief_for)
		L(0, "I heard about %s. I'm so sorry, %s." % [Dialogue.first(dead) if dead else "your friend", nm])
		L(1, Dialogue.fill(Dialogue.pick(Dialogue.LINES["grieving"]), {"name": Dialogue.first(dead) if dead else "them"}))
	else:
		L(0, Dialogue.pick(["You okay, %s? You look awful." % nm, "Hey, %s. Rough day?" % nm, "You seem stressed. Talk to me."]))
		L(1, Dialogue.complaint(bb))
	L(0, Dialogue.fill(Dialogue.pick(Dialogue.LINES["console"]), {"name": nm}), func():
		bb.needs.stress = maxf(0.0, bb.needs.stress - 15.0 * (0.5 + ba.tv("empathy")))
		bb.grief = maxf(0.0, bb.grief - 0.2)
		bb.bond(a, 8.0)
		ba.bond(b, 3.0)
		bb.learned.note(a.id, "kind", 0.2)
		bb.memory.remember("helped_me", a.id, b.id, "%s comforted me when I needed it." % a.display_name, 0.7))
	L(1, Dialogue.fill(Dialogue.pick(Dialogue.LINES["console_reply"]), {"name": Dialogue.call_name(bb, a)}))

func _grieve() -> void:
	var dead := Game.get_entity(ba.grief_for)
	var dn := Dialogue.first(dead) if dead else "them"
	L(0, Dialogue.fill(Dialogue.pick(Dialogue.LINES["grieving"]), {"name": dn}))
	if bb.tv("empathy") > 0.4 or good:
		L(1, Dialogue.pick(["I know. I'm sorry.", "%s was one of the good ones." % dn, "Come here. It's going to be okay.", "I miss %s too." % dn]), func():
			ba.grief = maxf(0.0, ba.grief - 0.15)
			ba.needs.stress = maxf(0.0, ba.needs.stress - 10.0)
			ba.bond(b, 6.0))
	else:
		L(1, Dialogue.pick(["People die out here. It happens.", "...yeah.", "Try not to think about it."]), func(): ba.bond(b, -4.0))

func _argue() -> void:
	L(0, Dialogue.argument_open(ba, b))
	var hot := bb.tv("aggression") > 0.55 or bb.anger > 0.4
	L(1, Dialogue.argument_back(bb, a, hot), func():
		ba.bond(b, -5.0)
		bb.bond(a, -5.0)
		ba.anger = minf(1.0, ba.anger + 0.15)
		bb.anger = minf(1.0, bb.anger + (0.2 if hot else 0.05))
		ba.needs.stress = minf(100.0, ba.needs.stress + 5.0)
		bb.needs.stress = minf(100.0, bb.needs.stress + 6.0))
	if hot:
		L(0, Dialogue.argument_back(ba, b, ba.tv("aggression") > 0.6))
		L(1, Dialogue.argument_back(bb, a, true), func():
			# it boils over: a shove from the angrier one, if they're that sort
			if ba.tv("aggression") > 0.75 and ba.tv("lawfulness") < 0.45 and ba.anger > 0.5 and a.adjacent(b):
				ba.lash_out(b, "shove")
			elif bb.tv("aggression") > 0.75 and bb.tv("lawfulness") < 0.45 and bb.anger > 0.5 and a.adjacent(b):
				bb.lash_out(a, "shove"))
	else:
		L(0, Dialogue.pick(["That's what I thought.", "Whatever.", "Hmph."]))

func _about_person() -> void:
	var s := _rep_subject()
	if s.is_empty():
		_smalltalk()
		return
	var ent: Entity = s["ent"]
	var nm := Dialogue.first(ent)
	L(0, Dialogue.pick(["Have you met %s?" % nm, "What do you make of %s?" % nm, "Can I tell you something about %s?" % nm, "So, %s..." % nm]))
	var key: String = s["key"]
	var v: float = s["v"]
	var trust := clampf(0.5 + bb.memory.rel(a.id).trust / 200.0 + bb.affinity(a.id) / 300.0, 0.1, 1.0)
	L(0, Dialogue.opinion(ba, ent, b), func(): bb.learned.hear_rep(ent.id, key, v, trust))
	# the listener's own view
	var own: Array = bb.learned.headline(ent.id)
	if not own.is_empty() and own[0] == key and signf(own[1]) == signf(v):
		L(1, Dialogue.pick(["Yeah, I've noticed that too.", "I know, right?", "Tell me about it."]))
	elif bb.affinity(ent.id) > 35 and v < 0:
		L(1, Dialogue.pick(["Hey, %s is my friend." % nm, "That's not fair, %s's alright." % nm, "I don't believe that."]), func(): bb.bond(a, -3.0))
	else:
		L(1, Dialogue.pick(["Huh. Good to know.", "Really?", "I'll keep that in mind.", "Hm. Noted."]))

func _plan() -> void:
	var what := "lunch" if Routine.phase() in ["late_morning", "lunch"] else ("bar" if Routine.phase() in ["wind_down", "afternoon"] else "break")
	L(0, Dialogue.plan_invite(ba, what, b))
	var yes := good and bb.affinity(a.id) > -5 and bb.needs.stress < 80
	L(1, Dialogue.pick(Dialogue.LINES["yes"] if yes else ["Maybe later.", "Can't, too much to do.", "Rain check?", "Nah, I'm good."]), func():
		if yes:
			var where := "Cafeteria" if what == "lunch" else ("Bar" if what == "bar" else "Crew Lounge")
			ba.make_plan(what, where, b)
			bb.make_plan(what, where, a))

func _work() -> void:
	var dept := Jobs.dept(ba.job)
	L(0, Dialogue.dept_status(ba) if randf() < 0.5 else Dialogue.pick(["How's work going?", "Busy day?", "Anything I should know about?", "Did you see the state of %s?" % Game.map.area_at(a.cell).name]))
	# share job knowledge (the useful stuff)
	var shared_any := false
	for f in ba.knowledge.facts.values():
		if f["type"] in ["pipe_leak", "breach", "broken_machine", "power_out", "injured", "person_down", "mess", "wanted", "reactor_hot", "sick", "cable_damaged"] and not f.get("shared_with_%d" % b.id, false):
			var sent: Dictionary = f.duplicate()
			f["shared_with_%d" % b.id] = true
			L(0, "Heads up: %s." % ba.knowledge.describe(f), func(): bb.hear_gossip(a, sent, 0.95))
			L(1, Dialogue.pick(["On it.", "I'll take a look.", "Thanks, noted.", "Ugh. Okay."]))
			shared_any = true
			break
	if not shared_any:
		L(1, Dialogue.dept_status(bb) if dept == Jobs.dept(bb.job) else Dialogue.reply(bb, a, good))

func _mentor() -> void:
	var skill := _dept_skill(ba.job)
	var tip := Dialogue.tip(skill)
	if tip == "":
		_work()
		return
	L(0, Dialogue.pick(["Let me show you something, %s." % Dialogue.call_name(ba, b), "Quick lesson.", "Here's something I wish someone told me on my first voyage."]))
	L(0, Dialogue.fill(Dialogue.pick(Dialogue.LINES["taught"]), {"tip": tip}), func():
		Skills.add_xp(b, skill, 25.0 + Skills.level(a, skill) * 0.3)
		bb.learned.mentors[a.id] = bb.learned.mentors.get(a.id, 0) + 1
		bb.memory.rel(a.id).respect = minf(100.0, bb.memory.rel(a.id).respect + 4.0))
	L(1, Dialogue.pick(["Got it, thanks.", "Oh, that's useful.", "Huh, I didn't know that.", "Thanks, boss."] if good else ["Yeah, I know.", "...right.", "I've been doing this for years, but okay."]))

static func _dept_skill(job: String) -> String:
	match Jobs.dept(job):
		"engineering": return "atmos" if job == "atmos" else "engineering"
		"medical": return "chemistry" if job == "chemist" else "medical"
		"security": return "security"
		"science": return "science"
		"service":
			return {"cook": "cooking", "botanist": "botany", "bartender": "social"}.get(job, "survival")
		"supply": return "mining" if job == "miner" else "construction"
		"command": return "social"
	return "survival"

func _event() -> void:
	var ep := _recent_event()
	if ep.is_empty():
		_smalltalk()
		return
	L(0, Dialogue.pick(["Can you believe what happened earlier?", "I still can't stop thinking about earlier.", "Did you hear what happened?"]))
	L(0, ep["text"])
	var reaction := "That's awful." if ep["valence"] < 0 else "That's great!"
	if ep["type"] in ["saved_me", "treated_me", "helped_me"]:
		var who := Game.get_entity(ep["actor"])
		reaction = "%s did that? Good for them." % Dialogue.first(who) if who else reaction
		if who:
			var trust := clampf(0.5 + bb.memory.rel(a.id).trust / 200.0, 0.1, 1.0)
			L(1, reaction, func(): bb.learned.hear_rep(who.id, "helpful", 0.5, trust))
			return
	L(1, reaction if randf() < 0.5 else Dialogue.fact_reaction(bb, {"type": "body" if ep["valence"] < -0.5 else "noise", "severity": 3 if ep["valence"] < -0.5 else 1}))

func _get_to_know() -> void:
	L(0, Dialogue.bio_ask(ba, b))
	var bio: Array = bb.persona.bio_lines(bb)
	L(1, bio[0], func():
		ba.memory.rel(b.id).familiarity = minf(100.0, ba.memory.rel(b.id).familiarity + 12.0)
		bb.memory.rel(a.id).familiarity = minf(100.0, bb.memory.rel(a.id).familiarity + 12.0)
		ba.known_bio[b.id] = true)
	if good:
		L(0, Dialogue.pick(["No way. I'm from %s myself." % ba.persona.hometown, "Huh. I came for %s, honestly." % ba.persona.reason_id.replace("_", " "), "That's a good reason.", "Wow."]))
		if bio.size() > 2:
			L(1, bio[2], func():
				var shared := ba.persona.shared_interests(bb.persona)
				if not shared.is_empty():
					ba.bond(b, 6.0)
					bb.bond(a, 6.0))
			var shared2 := ba.persona.shared_interests(bb.persona)
			if not shared2.is_empty():
				L(0, "Wait, you like %s too?" % ba.persona.interest_label(shared2[0]))
				L(1, Dialogue.pick(["Yes! Finally!", "Ha, small ship.", "We have to talk about that."]))

# ------------------------------------------------------------------ running
func tick(dt: float) -> void:
	if done:
		return
	if not _ok():
		abort()
		return
	t -= dt
	if t > 0:
		return
	if i >= lines.size():
		_finish()
		return
	var ln: Dictionary = lines[i]
	i += 1
	var sb: CBrain = ba if ln["who"] == 0 else bb
	var other: Entity = b if ln["who"] == 0 else a
	var sp: Entity = a if ln["who"] == 0 else b
	if sb != null:
		sb.mob.face(Defs.dir_from_vec(other.cell - sp.cell) if other.cell != sp.cell else sb.mob.dir)
		sb.say(ln["text"], {"to": other})
	if ln["fx"].is_valid():
		ln["fx"].call()
	# the next line comes after the time it takes to read this one and type the reply
	var nxt: Dictionary = lines[i] if i < lines.size() else {}
	var typing: float = 0.0 if nxt.is_empty() else clampf(0.7 + String(nxt["text"]).length() * 0.045, 1.2, 4.8)
	t = typing + randf_range(0.2, 0.9)

func _ok() -> bool:
	for pair in [[a, ba], [b, bb]]:
		var ent: Entity = pair[0]
		if not is_instance_valid(ent) or ent.removed:
			end_reason = "gone"
			return false
		var h: CHealth = ent.c(&"health")
		if h == null or h.stat() != CHealth.CONSCIOUS:
			end_reason = "%s not conscious" % ent.display_name
			return false
		if pair[1] != null and pair[1].convo != self:
			end_reason = "%s left the conversation (%s)" % [ent.display_name, pair[1].status_text()]
			return false
	if a.dist_to(b) > 3:
		end_reason = "too far apart (%.1f)" % a.dist_to(b)
		return false
	return true

func abort() -> void:
	if done:
		return
	done = true
	if debug:
		print("   (conversation %s/%s ended early: %s)" % [a.display_name, b.display_name, end_reason if end_reason != "" else "abort() called"])
	for pair in [[a, ba], [b, bb]]:
		var br: CBrain = pair[1]
		if br != null and is_instance_valid(pair[0]) and br.convo == self:
			br.convo = null
	# whoever walked off says so, if they're still up
	if i > 0 and i < lines.size():
		for br in [ba, bb]:
			if br != null and br.health.stat() == CHealth.CONSCIOUS and randf() < 0.5:
				br.say(Dialogue.line("break_off", br, {}))
				break

func _finish() -> void:
	done = true
	for pair in [[ba, b], [bb, a]]:
		var br: CBrain = pair[0]
		var other: Entity = pair[1]
		if br == null:
			continue
		if br.convo == self:
			br.convo = null
		br.needs.social = minf(100.0, br.needs.social + 22.0)
		br.needs.stress = maxf(0.0, br.needs.stress - 3.0 * br.tv("sociability"))
		br.needs.fun = minf(100.0, br.needs.fun + 5.0)
		br.last_talked[other.id] = Game.time
		var r = br.memory.rel(other.id)
		r.familiarity = minf(100.0, r.familiarity + 5.0)
		if topic != "argue":
			br.memory.remember("good_chat" if good else "bad_chat", other.id, other.id, "Chatted with %s about %s." % [other.display_name, _topic_text()], 1.0)
		if other.has_c(&"brain"):
			Favors.note_talk(br.e, other)
	if Game.player and a.dist_to(Game.player) <= 7:
		pass # overheard: the lines went out as ordinary speech

func _topic_text() -> String:
	return {"gossip": "the latest news", "interest": "hobbies", "complain": "work", "joke": "jokes", "console": "how they're holding up", "grieve": "a friend we lost",
		"about_person": "people", "plan": "plans", "work": "work", "mentor": "the job", "event": "what happened", "get_to_know": "ourselves", "smalltalk": "nothing much"}.get(topic, "things")
