class_name NpcTest extends Node
## --npctest (with --autotest, ideally --speed=4): puts the NPC minds through their paces
## in the live station and checks the results. Prints PASS/FAIL lines and a transcript of
## the interesting exchanges, so the output doubles as a read of how the crew comes across.
##   parser         what players type -> the intent NPCs understand
##   voice          typing styles stay readable
##   talk           greeting, questions, bio, directions, opinions answered in person
##   items          asking for an item and getting it (or a reasoned refusal)
##   favors         an NPC asks a favor, the player accepts and delivers
##   medical        a doctor finds a bleeding patient and treats the wound
##   security       an assault in front of an officer ends in cuffs
##   reputation     witnesses think worse of the attacker, and gossip spreads it
##   conversation   two NPCs hold a real multi-line conversation
##   routine        lunch time fills the cafeteria
##   radio          a question on the radio gets an answer
##   learning       failures lower a goal's appeal

var fails := 0
var passes := 0
var dir := "" # --npcshots=DIR: screenshots of the NPC windows (needs a window, not --headless)
var heard: Array = [] # [time, speaker Entity, text, channel]

func _ready() -> void:
	_run.call_deferred()

func _ok(cond: bool, what: String) -> void:
	print("%s %s" % ["PASS" if cond else "FAIL", what])
	if cond:
		passes += 1
	else:
		fails += 1

func _wait(sec: float) -> void:
	var until := Game.time + sec
	while Game.time < until:
		await get_tree().process_frame

func _wait_for(cond: Callable, sec: float) -> bool:
	var until := Game.time + sec
	while Game.time < until:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()

func _said_by(e: Entity, since: float) -> Array:
	return heard.filter(func(h): return h[1] == e and h[0] > since).map(func(h): return h[2])

func _free_next_to(e: Entity) -> Vector2i:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var c: Vector2i = e.cell + d
		if Game.map.is_passable(c) and not Game.at(c).any(func(x): return x.has_c(&"mob") or (x.has_c(&"blocker") and x.c(&"blocker").dense)):
			return c
	return e.cell

func _npc(job: String) -> Entity:
	for m in Game.all_with(&"brain"):
		if m.c(&"brain").job == job and not m.c(&"health").dead:
			return m
	return null

func _say(p: Entity, text: String) -> void:
	print("   > %s: %s" % [p.display_name, text])
	p.c(&"mob").say(text)
	# lines already spoken this instant belong to the last prompt
	heard = heard.map(func(h): return h if h[0] < Game.time else [h[0] - 0.001, h[1], h[2], h[3]])

func _show(e: Entity, since: float) -> void:
	for h in heard.filter(func(h): return h[1] == e and h[0] > since):
		print("   < %s: %s  (+%.1fs)" % [e.display_name, h[2], h[0] - since])

func _run() -> void:
	await get_tree().process_frame
	Conversation.debug = true
	Bus.speech.connect(_on_speech)
	Bus.radio.connect(_on_radio)
	await _wait(3.0)
	var p: Entity = Game.player
	if p == null:
		print("NPCTEST: no player")
		get_tree().quit()
		return
	Game.god_mode = false
	# checks expect able-bodied crew: no mute, blind or pacifist quirks rolled at random
	for m in Game.all_with(&"mob"):
		Quirks.remove_all(m)
	_parser()
	_voice()
	await _talk(p)
	await _items(p)
	await _favors(p)
	await _conversation()
	await _medical(p)
	await _security(p)
	_heal(p)
	await _radio(p)
	await _cargo()
	await _traitor(p)
	_learning()
	await _routine()
	if dir != "":
		await _shots(p)
	print("NPCTEST: %d passed, %d failed" % [passes, fails])
	Bus.speech.disconnect(_on_speech)
	Bus.radio.disconnect(_on_radio)
	get_tree().quit()

func _on_speech(sp, text, _c, r) -> void:
	if is_instance_valid(sp) and r > 2.0:
		heard.append([Game.time, sp, text, ""])

func _on_radio(sp, ch, text, _f) -> void:
	if is_instance_valid(sp):
		heard.append([Game.time, sp, text, ch])

# ------------------------------------------------------------------ parser
func _parser() -> void:
	var cook := _npc("cook")
	var doc := _npc("doctor")
	var me: Entity = cook if cook else Game.all_with(&"brain")[0]
	var other: Entity = doc if doc else Game.all_with(&"brain")[1]
	var first := other.display_name.split(" ")[0]
	var cases := [
		["hi there", "greet"], ["hey!", "greet"], ["how are you doing?", "how_are_you"], ["whats up", "news"], ["any news?", "news"],
		["where is %s?" % first, "where_person"], ["have you seen %s" % first.to_lower(), "where_person"], ["where's the kitchen", "where_place"],
		["how do i get to medbay", "where_place"], ["can i have your flashlight?", "request_item"], ["give me a welder", "request_item"],
		["could you bring me some cocoa", "request_fetch"], ["i'm bleeding, help", "request_heal"], ["heal me please", "request_heal"],
		["follow me", "follow"], ["stop", "stop"], ["wait here", "stop"], ["teach me medicine", "teach"], ["any tips?", "teach"],
		["what do you think of %s" % first, "opinion"], ["do you like me?", "opinion_me"], ["tell me about yourself", "about_you"],
		["where are you from", "about_you"], ["what are your hobbies", "interests"], ["tell me a joke", "joke"], ["thanks!", "thanks"],
		["thank you so much", "thanks"], ["you're an idiot", "insult"], ["shut up", "insult"], ["great job today", "compliment"],
		["i'm going to kill you", "threat"], ["sorry about that", "apology"], ["%s attacked me" % first, "report_crime"],
		["can i get engineering access", "request_access"], ["need anything?", "offer_help"], ["yes", "yes"], ["nah", "no"],
		["bye", "bye"], ["i'm hungry", "request_food"], ["a beer please", "request_drink"], ["open the door", "request_open"],
		["there's a leak in the kitchen, fix it", "request_fix"], ["what are you doing?", "doing"], ["come here", "come_here"],
		["wanna grab lunch?", "invite"], ["do you like chess", "topic"], ["what scares you", "fear"], ["you stole my wallet", "accuse"],
	]
	var good := 0
	var bad := []
	for c in cases:
		var r := SpeechIntent.parse(c[0], me, Game.player)
		if r["intent"] == c[1]:
			good += 1
		else:
			bad.append("'%s' -> %s (want %s)" % [c[0], r["intent"], c[1]])
	for x in bad:
		print("   parser miss: " + x)
	_ok(good >= cases.size() - 3, "parser understands %d/%d phrases" % [good, cases.size()])
	var r2 := SpeechIntent.parse("where is %s?" % first, me, Game.player)
	_ok(r2["person"] != null and r2["person"].display_name.split(" ")[0] == first, "parser finds the person named")
	var r3 := SpeechIntent.parse("where's the kitchen", me, Game.player)
	_ok(r3["area"] != null and r3["area"].name.begins_with("Kitchen"), "parser finds the place named")
	_ok(SpeechIntent.parse("got a spare welder?", me, Game.player)["item"] == "welder", "parser finds the item named")

# ------------------------------------------------------------------ voice
func _voice() -> void:
	var outs := []
	var ok := true
	for m in Game.all_with(&"brain"):
		var b: CBrain = m.c(&"brain")
		var s := Voice.apply("Hey there, could you pass me that wrench? Thanks.", b, {"to": Game.player})
		if s.strip_edges().length() < 10:
			ok = false
		outs.append("%s [%s]: %s" % [m.display_name.split(" ")[0], Voice.describe(b.persona.voice), s])
	for o in outs.slice(0, 6):
		print("   " + o)
	_ok(ok, "every voice keeps a line readable")
	var styles := {}
	for m in Game.all_with(&"brain"):
		styles[m.c(&"brain").persona.voice.get("caps", "") + m.c(&"brain").persona.voice.get("punct", "")] = true
	_ok(styles.size() >= 3, "the crew types in at least 3 distinct styles (%d)" % styles.size())
	var interests := {}
	for m in Game.all_with(&"brain"):
		for i in m.c(&"brain").persona.interests:
			interests[i] = true
	_ok(interests.size() >= 8, "the crew has varied interests (%d kinds)" % interests.size())

# ------------------------------------------------------------------ talking to an NPC
func _talk(p: Entity) -> void:
	var npc := _npc("assistant")
	if npc == null:
		npc = _npc("cook")
	var other := _npc("doctor")
	if npc == null or other == null:
		_ok(false, "talk: no NPCs to talk to")
		return
	var b: CBrain = npc.c(&"brain")
	b.errand = {}
	b.plan.clear()
	b.action = null
	b.goal_cooldowns["_all"] = Game.time + 60.0
	p.place(_free_next_to(npc))
	var first := npc.display_name.split(" ")[0]
	var t0 := Game.time
	_say(p, "Hi %s!" % first)
	_ok(await _wait_for(func(): return _said_by(npc, t0).size() > 0, 6.0), "talk: a greeting gets a reply")
	_show(npc, t0)
	t0 = Game.time
	_say(p, "how are you?")
	_ok(await _wait_for(func(): return _said_by(npc, t0).size() > 0, 6.0), "talk: follow-up without a name is understood")
	_show(npc, t0)
	t0 = Game.time
	_say(p, "where are you from?")
	_ok(await _wait_for(func(): return _said_by(npc, t0).size() >= 1, 8.0), "talk: asked about themselves")
	await _wait(6.0)
	_show(npc, t0)
	var said := " ".join(_said_by(npc, t0)).to_lower()
	_ok(said.contains(b.persona.hometown.to_lower().split(" ")[-1]) or said.contains("why do you want") or said.contains("not much"), "talk: the answer is their own backstory")
	t0 = Game.time
	_say(p, "where's the kitchen?")
	_ok(await _wait_for(func(): return _said_by(npc, t0).any(func(x): return x.to_lower().contains("kitchen") or x.to_lower().contains("in it")), 6.0), "talk: gives directions")
	_show(npc, t0)
	t0 = Game.time
	print("   (npc is %s; queue %s; now %.1f)" % [b.status_text(), str(b.say_queue.map(func(q): return [q["text"], snappedf(q["t"], 0.1)])), Game.time])
	_say(p, "what do you think of %s?" % other.display_name.split(" ")[0])
	_ok(await _wait_for(func(): return _said_by(npc, t0).size() > 0, 6.0), "talk: has an opinion about a colleague")
	_show(npc, t0)
	t0 = Game.time
	_say(p, "any tips for first aid?")
	_ok(await _wait_for(func(): return _said_by(npc, t0).size() > 0, 6.0), "talk: asked for advice")
	_show(npc, t0)
	t0 = Game.time
	var aff0: float = b.affinity(p.id)
	_say(p, "you're useless, shut up")
	await _wait_for(func(): return _said_by(npc, t0).size() > 0, 6.0)
	_show(npc, t0)
	_ok(b.affinity(p.id) < aff0, "talk: an insult hurts the relationship (%.0f -> %.0f)" % [aff0, b.affinity(p.id)])
	t0 = Game.time
	_say(p, "sorry, I didn't mean that")
	await _wait_for(func(): return _said_by(npc, t0).size() > 0, 6.0)
	_show(npc, t0)
	b.goal_cooldowns.erase("_all")

# ------------------------------------------------------------------ items
func _items(p: Entity) -> void:
	var npc := _npc("assistant")
	if npc == null:
		npc = _npc("botanist")
	if npc == null:
		return
	var b: CBrain = npc.c(&"brain")
	b.memory.rel(p.id).affinity = 45.0
	b.memory.rel(p.id).trust = 30.0
	var fl := Proto.spawn("flashlight", npc.cell)
	b.inv.put_in_hands(fl)
	b.plan.clear()
	b.action = null
	p.place(_free_next_to(npc))
	var t0 := Game.time
	_say(p, "%s, can I have your flashlight please?" % npc.display_name.split(" ")[0])
	var got := await _wait_for(func(): return fl.root() == p, 8.0)
	_show(npc, t0)
	if not got:
		print("   flashlight is with %s; npc %s; errand %s; gives queued %d" % [fl.root().display_name, b.status_text(), b.errand, b.give_queue.size()])
	_ok(got, "items: a friendly NPC hands over a spare flashlight")
	b.goal_cooldowns.erase("_all")

# ------------------------------------------------------------------ favors
func _favors(p: Entity) -> void:
	var npc := _npc("engineer")
	if npc == null:
		return
	var b: CBrain = npc.c(&"brain")
	# take their cable so they want some
	for it in b.inv.all_items():
		if it.ai_tags().has("mat_cable"):
			Interact.detach(it)
			it.destroy()
	b.memory.rel(p.id).affinity = 20.0
	p.place(_free_next_to(npc))
	b.goal_cooldowns["_all"] = Game.time + 40.0
	b.plan.clear()
	b.action = null
	b.goal = {}
	b.last_favor_ask = -999.0
	# nobody else has a question hanging for the player right now
	for m in Game.all_with(&"brain"):
		if m != npc:
			m.c(&"brain").pending = {}
	var t0 := Game.time
	var asked := PlayerTalk._maybe_ask_favor(b, p, 0.5, true)
	await _wait(3.0)
	_show(npc, t0)
	_ok(asked and b.pending.get("kind", "") == "favor", "favors: an NPC asks the player for something")
	if not asked:
		return
	var f := Favors.get_favor(b.pending["id"])
	print("   favor: %s (%s)" % [f["desc"], f["kind"]])
	t0 = Game.time
	var to := PlayerTalk.addressee(p, "sure", p.cell, 7.0)
	print("   (before 'sure': addressee %s; pending %s; chat_with player %s)" % [to.display_name if to else "nobody", b.pending, b.chat_with == p.id])
	_say(p, "sure")
	await _wait(3.0)
	_show(npc, t0)
	_ok(f["state"] == "accepted", "favors: saying yes accepts it")
	# deliver what they wanted
	var proto := ""
	match f.get("want", ""):
		"cable": proto = "cable_coil"
		"glass": proto = "sheet_glass"
		"metal": proto = "sheet_metal"
		"food": proto = "food_sandwich"
		"drink": proto = "drink_water"
		"coat": proto = "winter_coat"
		"cocoa": proto = "drink_cocoa"
		"cigarette": proto = "cig_pack"
		"ore": proto = "ore_iron"
		"gauze": proto = "gauze"
		"suture": proto = "suture"
		"cuffs": proto = "handcuffs"
		"tomato": proto = "food_tomato"
		"meat": proto = "food_meat"
		"mop": proto = "mop"
	if f["kind"] == "fetch" and proto != "":
		var it := Proto.spawn(proto, p.cell)
		p.c(&"inv").put_in_hands(it)
		t0 = Game.time
		DragDrop._give(p, it, npc)
		await _wait(3.0)
		_show(npc, t0)
		_ok(f["state"] == "done", "favors: handing it over completes the favor")
		_ok(not b.memory.recent("helped_me", 30.0).is_empty(), "favors: the NPC remembers the help")
		_ok(b.learned.rep_of(p.id, "helpful") > 0.1, "favors: the player now has a helpful reputation with them")
	elif f["kind"] == "check_on":
		var target := Game.get_entity(f["target"])
		if target:
			p.place(_free_next_to(target))
			_say(p, "Hey %s, how are you?" % target.display_name.split(" ")[0])
			await _wait(2.0)
			_ok(f["state"] == "done", "favors: checking on their friend completes the favor")
	b.goal_cooldowns.erase("_all")

# ------------------------------------------------------------------ NPC-NPC conversation
func _conversation() -> void:
	var a := _npc("scientist")
	var c := _npc("botanist")
	if a == null or c == null:
		a = Game.all_with(&"brain")[2]
		c = Game.all_with(&"brain")[3]
	var ba: CBrain = a.c(&"brain")
	var bc: CBrain = c.c(&"brain")
	c.place(_free_next_to(a))
	for bb in [ba, bc]:
		bb.goal_cooldowns["_all"] = Game.time + 40.0
		bb.plan.clear()
		bb.action = null
	var fam0: float = ba.memory.rel(c.id).familiarity
	var t0 := Game.time
	ba.goal = {"id": "socialize", "score": 200.0, "desc": "chatting"}
	ba.plan = [Act.Talk.new(c)]
	var started := await _wait_for(func(): return ba.convo != null, 5.0)
	_ok(started, "conversation: two NPCs start talking")
	if started:
		print("   topic: %s" % ba.convo.topic)
	await _wait_for(func(): return ba.convo == null, 45.0)
	var lines := heard.filter(func(h): return (h[1] == a or h[1] == c) and h[0] >= t0 and h[3] == "")
	for h in lines:
		print("   %s: %s" % [h[1].display_name, h[2]])
	_ok(lines.size() >= 3, "conversation: a real exchange (%d lines)" % lines.size())
	_ok(lines.any(func(h): return h[1] == a) and lines.any(func(h): return h[1] == c), "conversation: both of them speak")
	_ok(ba.memory.rel(c.id).familiarity > fam0, "conversation: they know each other a bit better")
	for bb in [ba, bc]:
		bb.goal_cooldowns.erase("_all")

# ------------------------------------------------------------------ medical
func _medical(p: Entity) -> void:
	var doc := _npc("doctor")
	if doc == null:
		doc = _npc("cmo")
	if doc == null:
		_ok(false, "medical: no doctor")
		return
	var h: CHealth = p.c(&"health")
	var b: CBrain = doc.c(&"brain")
	b.orders.clear()
	b.errand = {}
	p.place(_free_next_to(doc))
	# a nasty cut on the arm
	Body.apply_wound(h, "l_arm", "laceration")
	h.adjust("brute", 25.0, null)
	var bleed0 := Body.bleed_rate(h)
	var t0 := Game.time
	_say(p, "%s, I'm bleeding, help!" % doc.display_name.split(" ")[0])
	var treated := await _wait_for(func(): return Body.bleed_rate(h) < bleed0 * 0.5 or h.gauze.has("l_arm"), 70.0)
	_show(doc, t0)
	print("   doctor is %s; bleeding %.2f -> %.2f; gauze on arm: %s" % [b.status_text(), bleed0, Body.bleed_rate(h), h.gauze.has("l_arm")])
	_ok(treated, "medical: the doctor treats the bleeding arm")
	# heal the player back up for what follows
	for w in h.wounds.duplicate():
		Body.remove_wound(h, w, false)
	h.brute = 0.0
	h.limb.clear()
	h.blood_volume = Body.BLOOD_VOLUME_NORMAL

# ------------------------------------------------------------------ security
func _security(p: Entity) -> void:
	var off := _npc("security")
	if off == null:
		off = _npc("hos")
	var victim := _npc("janitor")
	if victim == null:
		victim = _npc("cook")
	if off == null or victim == null:
		_ok(false, "security: no officer / victim")
		return
	var ob: CBrain = off.c(&"brain")
	if not ob.has_tag("restraint"):
		ob.inv.put_in_hands(Proto.spawn("handcuffs", off.cell))
		ob.stash_active()
	victim.place(_free_next_to(off))
	await _wait(0.5)
	p.place(_free_next_to(victim))
	ob.goal_cooldowns.clear()
	var witnesses: Array = Game.in_radius(p.cell, 6, &"brain").filter(func(x): return x != victim)
	var t0 := Game.time
	var log_fn := func(info):
		if info.get("type", "") in ["assault", "cuffed"] and info.get("actor") and info.get("target"):
			var ab = info["actor"].c(&"brain")
			print("   ! %s: %s -> %s%s  [%s]" % [info["type"], info["actor"].display_name, info["target"].display_name, " (illegal)" if info.get("illegal", false) else "",
				("%s / %s" % [ab.goal.get("id", ""), ab.goal.get("claim", "")]) if ab else "player"])
	Bus.stimulus.connect(log_fn)
	# punch them a few times, in full view
	p.c(&"mob").intent = "harm"
	for i in 3:
		p.c(&"mob").next_attack = 0.0
		Interact.attack(p, victim, null)
		await _wait(1.0)
	p.c(&"mob").intent = "help"
	var cuffed := await _wait_for(func(): return p.c(&"health").cuffed, 70.0)
	Bus.stimulus.disconnect(log_fn)
	_show(off, t0)
	for w in witnesses.slice(0, 3):
		_show(w, t0)
	print("   officer: %s" % ob.status_text())
	_ok(ob.knowledge.of_type("crime").any(func(f): return f.get("data", {}).get("actor", 0) == p.id), "security: the officer knows who did it")
	_ok(cuffed, "security: the attacker ends up in cuffs")
	var vb: CBrain = victim.c(&"brain")
	_ok(vb.affinity(p.id) < -10.0, "reputation: the victim dislikes the attacker (%.0f)" % vb.affinity(p.id))
	var rep_seen := witnesses.filter(func(w): return w.c(&"brain").learned.rep_of(p.id, "violent") > 0.1).size()
	_ok(rep_seen >= 1, "reputation: witnesses now think the player is violent (%d of %d)" % [rep_seen, witnesses.size()])
	# let them go for the rest of the test
	p.c(&"health").cuffed = false
	SecurityRecords.clear(p.id)
	SecurityRecords.brig_until.erase(p.id)
	for m in Game.all_with(&"brain"):
		for k in m.c(&"brain").knowledge.facts.keys():
			if k.begins_with("wanted:%d" % p.id) or k.ends_with(":%d" % p.id) and k.begins_with("crime:"):
				m.c(&"brain").knowledge.forget(k)
		m.c(&"brain").goal = {}
		m.c(&"brain").plan.clear()
		m.c(&"brain").action = null
	await _wait(2.0)

# ------------------------------------------------------------------ radio
func _radio(p: Entity) -> void:
	var target := _npc("cook")
	if target == null:
		return
	var hs: CHeadset = p.c(&"inv").headset()
	if hs == null:
		_ok(false, "radio: player has no headset")
		return
	if not "Common" in hs.channels:
		hs.channels.append("Common")
	var ph: CHealth = p.c(&"health")
	for st in ["stutter", "slurring", "confusion", "jitter"]:
		ph.remove_status(st)
	var t0 := Game.time
	_say(p, ";anyone seen %s?" % target.display_name.split(" ")[0])
	var answered := await _wait_for(func(): return heard.any(func(h): return h[0] >= t0 and h[3] == "Common" and h[1] != p), 12.0)
	for h in heard.filter(func(h): return h[0] >= t0 and h[3] != ""):
		print("   [%s] %s: %s" % [h[3], h[1].display_name, h[2]])
	_ok(answered, "radio: somebody answers a question on the radio")

# ------------------------------------------------------------------ learning
func _learning() -> void:
	var b: CBrain = Game.all_with(&"brain")[0].c(&"brain")
	var before := b.learned.goal_bias("fix_leak")
	for i in 4:
		b.learned.record("fix_leak", false)
	_ok(b.learned.goal_bias("fix_leak") < before, "learning: repeated failure makes a goal less appealing (%.2f -> %.2f)" % [before, b.learned.goal_bias("fix_leak")])
	b.learned.scare(5, 0.5, "test")
	_ok(b.learned.danger_of(5) > 0.4, "learning: a bad experience makes a place feel dangerous")
	b.learned.hear_rep(9999, "thief", 0.8, 1.0)
	_ok(b.learned.rep_of(9999, "thief") > 0.1, "learning: gossip about someone sticks")

# ------------------------------------------------------------------ routine
func _routine() -> void:
	# jump the clock to lunch and watch the cafeteria fill up
	var lunch_t := (11.4 - Defs.SHIFT_START_HOUR) * 3600.0 / Defs.SIM_TIME_SCALE
	if Game.time < lunch_t:
		Game.time = lunch_t
	_ok(Routine.phase() == "lunch", "routine: the clock reads lunch (%s)" % Game.clock_string())
	for m in Game.all_with(&"brain"):
		m.c(&"brain").think_t = 0.0
	await _wait(40.0)
	var eating := 0
	var in_caf := 0
	var caf := Game.map.areas.filter(func(a): return a.name.begins_with("Cafeteria"))
	for m in Game.all_with(&"brain"):
		var b: CBrain = m.c(&"brain")
		if b.routine_done.has("lunch"):
			eating += 1
		if not caf.is_empty() and Game.map.area_at(m.cell) == caf[0]:
			in_caf += 1
	print("   %d crew went for lunch, %d in the cafeteria now" % [eating, in_caf])
	_ok(eating >= 5, "routine: lunch time sends people to eat (%d)" % eating)

# ------------------------------------------------------------------ screenshots
func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [dir, name])
		print("   saved %s/%s.png" % [dir, name])

func _shots(p: Entity) -> void:
	var npc := _npc("bartender")
	if npc == null:
		npc = Game.all_with(&"brain")[0]
	p.place(_free_next_to(npc))
	Game.view.camera.position = p.position
	Game.view.camera.reset_smoothing()
	Game.hud.debug_ai = true
	await _wait(2.0)
	await _shot("npc_overlay")
	Game.hud.open_window("talk", npc)
	await _wait(1.0)
	await _shot("npc_talk")
	for w in Game.hud.windows.get_children():
		w.queue_free()
	await get_tree().process_frame
	Game.hud.open_window("mind", npc)
	await _wait(2.0)
	await _shot("npc_mind")
	# and the text, for the log
	var vb := VBoxContainer.new()
	WindowsNPC.mind(npc, vb, null)
	for c in vb.get_children():
		if c is RichTextLabel:
			print(c.get_parsed_text())
	vb.free()
	for w in Game.hud.windows.get_children():
		w.queue_free()
	await get_tree().process_frame
	Game.hud.open_window("objectives", null)
	await _wait(1.0)
	await _shot("npc_objectives")

# ------------------------------------------------------------------ traitor
func _traitor(p: Entity) -> void:
	var killer := _npc("cargo")
	if killer == null:
		killer = _npc("miner")
	var mark := _npc("botanist")
	if mark == null:
		mark = _npc("janitor")
	if killer == null or mark == null or killer == mark:
		_ok(false, "traitor: no suitable pair")
		return
	var kb: CBrain = killer.c(&"brain")
	kb.traits["aggression"] = 0.9
	kb.antag = {"kind": "kill", "target": mark.id, "name": mark.display_name, "escape": true}
	# a knife in their pocket, and the two of them alone in a maintenance tunnel
	var knife := Proto.spawn("knife_kitchen", killer.cell)
	kb.inv.put_in_hands(knife)
	var maint: Area = null
	for a in Game.map.areas:
		if (a.room_kind == "maint" or a.name.contains("Maint")) and a.cells.size() > 20:
			var crowd := 0
			for c in a.cells:
				for x in Game.at(c):
					if x.has_c(&"mob"):
						crowd += 1
			if crowd == 0:
				maint = a
				break
	if maint == null:
		_ok(false, "traitor: no quiet spot")
		return
	var spot := maint.random_cell(Game.rng)
	for c in maint.cells:
		if Game.map.is_passable(c):
			spot = c
			break
	mark.place(spot)
	var mb: CBrain = mark.c(&"brain")
	mb.goal_cooldowns["_all"] = Game.time + 60.0
	mb.plan.clear()
	mb.action = null
	killer.place(_free_next_to(mark))
	p.place(Vector2i(p.cell.x, p.cell.y)) # the player stays wherever they are, well away
	kb.think_t = 0.0
	var mh: CHealth = mark.c(&"health")
	var hp0 := mh.health()
	var hit := await _wait_for(func(): return mh.health() < hp0 - 15.0 or mh.dead, 40.0)
	print("   traitor %s: %s; thinking \"%s\"; mark at %d hp" % [killer.display_name, kb.status_text(), kb.thought, int(mh.health())])
	_ok(hit, "traitor: strikes when the mark is alone")
	mb.goal_cooldowns.erase("_all")
	kb.antag = {}
	if mh.dead:
		mh.revive()

# ------------------------------------------------------------------ cargo
func _heal(p: Entity) -> void:
	var h: CHealth = p.c(&"health")
	if h.dead:
		h.revive()
	for w in h.wounds.duplicate():
		Body.remove_wound(h, w, false)
	h.brute = 0.0
	h.burn = 0.0
	h.tox = 0.0
	h.oxy = 0.0
	h.limb.clear()
	h.cuffed = false
	h.blood_volume = Body.BLOOD_VOLUME_NORMAL
	for st in h.status.keys():
		h.remove_status(st)
	h.stamina = 100.0
	h.stamcrit = false
	h.last_stamina_dmg = -100.0
	if h.sleeping:
		h.wake()
	h.resting = false
	h.get_up(true) # tests: on their feet at once
	for m in Game.all_with(&"brain"):
		var k: Knowledge = m.c(&"brain").knowledge
		k.forget("down:%d" % p.id)
		k.forget("injured:%d" % p.id)

func _cargo() -> void:
	_heal(Game.player)
	var tech := _npc("cargo")
	if tech == null:
		tech = _npc("qm")
	if tech == null:
		_ok(false, "cargo: no cargo tech")
		return
	var tb: CBrain = tech.c(&"brain")
	Cargo.requests.clear()
	Cargo.request("kitchen ingredients", "service", _npc("cook"))
	var fridge: Entity = null
	for s2 in Game.all_with(&"storage"):
		if s2.proto == "fridge":
			fridge = s2
	var before: int = fridge.c(&"storage").contents.size() if fridge else 0
	var ordered := await _wait_for(func(): return Cargo.state != Cargo.AWAY or (fridge != null and fridge.c(&"storage").contents.size() > before), 150.0)
	print("   cargo: %s; tech %s" % [Cargo.status_text(), tb.status_text()])
	_ok(ordered, "cargo: a kitchen request gets food moving (ordered, or a waiting crate delivered)")
	await _wait_for(func(): return Cargo.state == Cargo.DOCKED, 120.0)
	var t_unload := Game.time
	for i in 50:
		await _wait(3.0)
		if heard.any(func(h): return h[0] > t_unload and String(h[2]).to_lower().contains("unpacked")):
			break
		var pl: Entity = tech.c(&"mob").pulling
		print("   t+%d: tech %s at %s, pulling %s, plan %s" % [i * 3, tb.status_text(), Game.map.area_at(tech.cell).name, pl.display_name if pl else "-", tb.plan.map(func(a): return a.label)])
		if fridge and fridge.c(&"storage").contents.size() > before:
			break
	var unpacked := heard.any(func(h): return h[0] > t_unload and String(h[2]).to_lower().contains("unpacked"))
	_ok(unpacked or (fridge != null and fridge.c(&"storage").contents.size() > before), "cargo: the delivery is hauled in and unpacked (kitchen fridge or cafeteria)")
