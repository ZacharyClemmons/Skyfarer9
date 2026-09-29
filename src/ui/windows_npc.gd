class_name WindowsNPC extends RefCounted
## Windows about people: talking to an NPC (quick phrases plus free text, which goes through
## the same speech understanding as typing in chat), the mind inspector (debug: everything
## an NPC is, believes and wants, live), and the favors people have asked of you.

const TRAIT_NAMES := {"bravery": "Bravery", "curiosity": "Curiosity", "diligence": "Diligence", "empathy": "Empathy", "loyalty": "Loyalty",
	"honesty": "Honesty", "aggression": "Aggression", "sociability": "Sociability", "neuroticism": "Nerves", "lawfulness": "Lawfulness", "humor": "Humour"}

static func _say_to(p: Entity, t: Entity, phrase: String) -> void:
	if p == null or t == null:
		return
	var first := t.display_name.split(" ")[0]
	p.c(&"mob").say("%s, %s" % [first, phrase] if not phrase.to_lower().contains(first.to_lower()) else phrase)

static func _section(body: Control, title: String) -> HFlowContainer:
	body.add_child(UITheme.caption(title))
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 4)
	f.add_theme_constant_override("v_separation", 4)
	body.add_child(f)
	return f

static func _phrase(box: Control, label: String, p: Entity, t: Entity, phrase: String) -> void:
	var b := Button.new()
	b.text = label
	b.tooltip_text = "Say: \"%s\"" % phrase
	b.pressed.connect(func(): WindowsNPC._say_to(p, t, phrase))
	box.add_child(b)

## Talking to an NPC.
static func talk(t: Entity, body: VBoxContainer, w: UIWindow) -> void:
	var p := Game.player
	var tb: CBrain = t.c(&"brain")
	var th: CHealth = t.c(&"health")
	if tb == null or p == null:
		return
	var r = tb.memory.rel(p.id)
	var info := "[b]%s[/b], %s\n" % [t.display_name, Jobs.title(t.c(&"mob").job)]
	info += "[color=#9ab8d8]Toward you: %s[/color]  [color=#6a7a8a](%s)[/color]\n" % [Windows._attitude(r.affinity), _familiarity(r.familiarity)]
	if r.familiarity > 15 or tb.told_bio.has(p.id):
		var words := tb.personality_words()
		if not words.is_empty():
			info += "[color=#9ab8d8]Seems %s.[/color]\n" % ", ".join(words.slice(0, 3))
	else:
		info += "[color=#6a7a8a]You don't know them well yet.[/color]\n"
	if tb.told_bio.has(p.id):
		info += "[color=#9ab8d8]From %s. Into %s.[/color]\n" % [tb.persona.hometown, tb.persona.interests_text()]
	var head: Array = tb.learned.headline(p.id)
	if not head.is_empty() and absf(head[1]) > 0.25:
		info += "[color=#c8a86a]They think you're %s.[/color]\n" % Experience.rep_word(head[0], head[1])
	var mw := tb.mood_word()
	if mw != "":
		info += "[color=#9ab8d8]They %s.[/color]\n" % mw
	info += "[color=#8a9cb0]Currently %s.[/color]" % tb.goal.get("desc", "idle")
	var fav := Favors.offered_by(t.id, p.id)
	if not fav.is_empty():
		info += "\n[color=#e8c85a]Favor%s: %s.[/color]" % [" (you agreed)" if fav["state"] == "accepted" else " they asked", fav["desc"]]
	Windows._rt(body, info)
	w.refresh_fn = Callable()
	if th.stat() != CHealth.CONSCIOUS:
		Windows._rt(body, "[color=#e8645a]They can't talk right now.[/color]")
		return
	var chat := _section(body, "Chat")
	_phrase(chat, "Hello", p, t, "hello!")
	_phrase(chat, "How are you?", p, t, "how are you?")
	_phrase(chat, "What's new?", p, t, "what's new?")
	_phrase(chat, "About you", p, t, "tell me about yourself.")
	_phrase(chat, "Hobbies?", p, t, "what do you do for fun?")
	_phrase(chat, "Goals?", p, t, "what do you want out of this voyage?")
	_phrase(chat, "Joke", p, t, "tell me a joke.")
	_phrase(chat, "What are you doing?", p, t, "what are you doing?")
	var ask := _section(body, "Ask")
	_phrase(ask, "Any tips?", p, t, "any tips for me?")
	_phrase(ask, "Need anything?", p, t, "need anything? I can help.")
	_phrase(ask, "Opinion of me", p, t, "what do you think of me?")
	var who := LineEdit.new()
	who.placeholder_text = "Where is... / What do you think of... (a name or a place)"
	who.custom_minimum_size = Vector2(380, 0)
	who.text_submitted.connect(func(txt):
		var tt: String = txt.strip_edges()
		if tt == "":
			return
		var a := SpeechIntent.area_in(SpeechIntent.norm(tt))
		var person := SpeechIntent.person_in(SpeechIntent.norm(tt), t, p)
		if person != null:
			WindowsNPC._say_to(p, t, "where is %s?" % tt if not tt.to_lower().begins_with("what") else tt)
		elif a != null:
			WindowsNPC._say_to(p, t, "how do I get to %s?" % tt)
		else:
			WindowsNPC._say_to(p, t, "where can I find a %s?" % tt)
		who.text = "")
	body.add_child(who)
	var req := _section(body, "Ask them to")
	_phrase(req, "Follow me", p, t, "follow me.")
	_phrase(req, "Stop", p, t, "stop, wait here.")
	_phrase(req, "Come here", p, t, "come here.")
	_phrase(req, "Heal me", p, t, "I'm hurt, can you help me?")
	match tb.job:
		"cook": _phrase(req, "Cook for me", p, t, "could you cook me something?")
		"bartender": _phrase(req, "A drink", p, t, "a drink, please.")
		"hop", "captain": _phrase(req, "Access...", p, t, "can I get more access on my pass?")
	if Jobs.dept(tb.job) == "engineering":
		_phrase(req, "Fix...", p, t, "there's something broken here, can you fix it?")
	_phrase(req, "Open this door", p, t, "can you open this door for me?")
	_phrase(req, "Lunch?", p, t, "want to grab lunch?")
	var soc := _section(body, "Say")
	_phrase(soc, "Thanks", p, t, "thanks!")
	_phrase(soc, "Sorry", p, t, "sorry about before.")
	_phrase(soc, "Compliment", p, t, "you're doing a great job.")
	_phrase(soc, "Yes", p, t, "yes.")
	_phrase(soc, "No", p, t, "no, sorry.")
	_phrase(soc, "Insult", p, t, "you're useless.")
	body.add_child(UITheme.caption("Or say anything"))
	var le := LineEdit.new()
	le.placeholder_text = "Type anything. They understand questions, requests, orders..."
	le.text_submitted.connect(func(txt):
		if txt.strip_edges() != "":
			WindowsNPC._say_to(p, t, txt)
		le.text = "")
	body.add_child(le)
	if Game.hud and Game.hud.debug_ai:
		Windows._btn(body, "Read their mind (debug)", func(): Game.hud.open_window("mind", t))

static func _familiarity(f: float) -> String:
	if f < 8:
		return "stranger"
	if f < 25:
		return "seen around"
	if f < 50:
		return "acquaintance"
	if f < 80:
		return "knows you well"
	return "close"

## Everything about an NPC's mind (debug).
static func mind(t: Entity, body: VBoxContainer, _w: UIWindow) -> void:
	var b: CBrain = t.c(&"brain") if t else null
	if b == null:
		Windows._rt(body, "No mind to read.")
		return
	var p: Persona = b.persona
	var s := "[b]%s[/b], %s, age %d. %s\n" % [t.display_name, Jobs.title(b.job), p.age, "Early bird." if p.chronotype == "early" else ("Night owl." if p.chronotype == "late" else "")]
	s += "[color=#9ab8d8]From %s. %s[/color]\n" % [p.hometown, p.reason]
	s += "Into %s. Loves %s and %s. Can't stand %s. Afraid of %s.\n" % [p.interests_text(), p.fav_food, p.fav_drink, p.peeve, p.fear]
	s += "Habits: %s.\n" % ", ".join(p.quirks_text())
	var amb := []
	for a in p.ambitions:
		amb.append("%s%s" % [p.ambition_text(a), " [color=#6ad88a](done)[/color]" if p.ambition_done.has(a) else ""])
	s += "Wants to: %s.\n" % ", ".join(amb)
	s += "Types: %s. Catchphrase: \"%s\"\n" % [Voice.describe(p.voice), p.catchphrase]
	Windows._rt(body, s)
	# traits and state
	var tr := "[color=#8a9cb0]Personality[/color]  "
	for k in CBrain.TRAITS:
		tr += "%s %d  " % [TRAIT_NAMES[k], int(b.tv(k) * 100)]
	var n: CNeeds = b.needs
	tr += "\n[color=#8a9cb0]Feelings[/color]  mood %+.2f  fear %.2f  anger %.2f  panic %.2f  grief %.2f\n" % [b.mood, b.fear, b.anger, b.panic, b.grief]
	tr += "[color=#8a9cb0]Needs[/color]  food %d  water %d  energy %d  social %d  fun %d  comfort %d  stress %d" % [n.nutrition, n.hydration, n.energy, n.social, n.fun, n.comfort, n.stress]
	# tg mood, sanity, moodlets and quirks
	var md: CMood = t.c(&"mood")
	if md:
		tr += "\n[color=#8a9cb0]Mood (tg)[/color]  %+d  level %d  sanity %d" % [int(md.mood), md.mood_level, int(md.sanity)]
		for c in md.events:
			var ev: Dictionary = md.events[c]
			tr += "\n   %+d  %s" % [int(ev["change"]), ev["desc"]]
	var qn := Quirks.names(t)
	if not qn.is_empty():
		tr += "\n[color=#8a9cb0]Quirks[/color]  %s" % ", ".join(qn)
	Windows._rt(body, tr)
	# what they're doing and why
	var g := "[color=#8a9cb0]Doing[/color]  [b]%s[/b]\n[color=#e8c85a]\"%s\"[/color]\n" % [b.status_text(), b.thought]
	for tl in b.thought_log.slice(maxi(0, b.thought_log.size() - 6)):
		g += "[color=#6a7a8a]%s  %s[/color]\n" % [tl[0], tl[1]]
	Windows._rt(body, g)
	# the choices in front of them right now
	var cands: Array = Goals.candidates(b) + JobAI.candidates(b) + Routine.candidates(b) + b._personal_candidates()
	for c in cands:
		c["eff"] = c["score"] * b.learned.goal_bias(c["id"])
	cands.sort_custom(func(x, y): return x["eff"] > y["eff"])
	var cl := "[color=#8a9cb0]Options (score)[/color]\n"
	for c in cands.slice(0, 8):
		var cd: float = b.goal_cooldowns.get(c["id"], 0.0) - Game.time
		cl += "%5d  %s%s\n" % [int(c["eff"]), c["desc"], " [color=#6a7a8a](resting %ds)[/color]" % int(cd) if cd > 0 else ""]
	Windows._rt(body, cl)
	# people
	var people := []
	for id in b.memory.rels.keys():
		var ent := Game.get_entity(id)
		if ent and ent.has_c(&"mob"):
			people.append([id, b.memory.rels[id]])
	people.sort_custom(func(x, y): return absf(x[1].affinity) > absf(y[1].affinity))
	var pl := "[color=#8a9cb0]People (affinity / trust / familiarity), and what they think of them[/color]\n"
	for pr in people.slice(0, 8):
		var ent2 := Game.get_entity(pr[0])
		var rp := []
		for nt in b.learned.notable(pr[0]).slice(0, 2):
			rp.append(Experience.rep_word(nt[0], nt[1]))
		pl += "%-20s %+4d %+4d %3d  %s\n" % [ent2.display_name, int(pr[1].affinity), int(pr[1].trust), int(pr[1].familiarity), ", ".join(rp)]
	Windows._rt(body, pl)
	# places, memories, knowledge
	var ex := "[color=#8a9cb0]Learned[/color]  "
	var sa := b.learned.scariest_area()
	if sa > 0:
		ex += "avoids %s (%s). " % [Game.map.areas[sa].name, b.learned.danger_why.get(sa, "")]
	var fa := b.learned.favourite_area()
	if fa > 0:
		ex += "Likes %s. " % Game.map.areas[fa].name
	if not b.learned.picked_up.is_empty():
		ex += "Picked up: %s. " % ", ".join(b.learned.picked_up)
	var fails := []
	for k in b.learned.outcomes:
		if b.learned.outcomes[k]["fail"] >= 2:
			fails.append("%s x%d" % [k, b.learned.outcomes[k]["fail"]])
	if not fails.is_empty():
		ex += "Keeps failing at: %s." % ", ".join(fails.slice(0, 4))
	var mem := "\n[color=#8a9cb0]Memories[/color]\n"
	var eps: Array = b.memory.episodes.duplicate()
	eps.sort_custom(func(x, y): return x["t"] > y["t"])
	for ep in eps.slice(0, 6):
		mem += "[color=%s]%s[/color]\n" % ["#6ad88a" if ep["valence"] > 0 else "#e8a08a", ep["text"]]
	var kc := {}
	for f in b.knowledge.facts.values():
		kc[f["type"]] = kc.get(f["type"], 0) + 1
	var kl := []
	for k in kc:
		if k != "item_at" and k != "person_seen":
			kl.append("%s %d" % [k, kc[k]])
	mem += "[color=#8a9cb0]Knows about[/color]  %s (and %d items, %d people seen)" % [", ".join(kl), kc.get("item_at", 0), kc.get("person_seen", 0)]
	Windows._rt(body, ex + mem)

## Favors people have asked of the player (in the objectives window).
static func favors(body: VBoxContainer, p: Entity) -> void:
	var open := Favors.list.filter(func(f): return f["to"] == p.id and f["state"] in ["accepted", "offered"])
	var done := Favors.list.filter(func(f): return f["to"] == p.id and f["state"] == "done")
	if open.is_empty() and done.is_empty():
		return
	body.add_child(UITheme.caption("Favors"))
	for f in open:
		var giver := Game.get_entity(f["from"])
		var left := int(maxf(0.0, f["expires"] - Game.time) * Defs.SIM_TIME_SCALE / 60.0)
		var txt := "[b]%s[/b]: %s  [color=#6a7a8a](%s%s)[/color]" % [giver.display_name if giver else "someone", f["desc"], "you agreed" if f["state"] == "accepted" else "they asked",
			", about %d min left" % left if f["state"] == "accepted" else ""]
		Windows._rt(body, txt)
	if not done.is_empty():
		Windows._rt(body, "[color=#6ad88a]Done: %s[/color]" % ", ".join(done.map(func(f): return f["desc"])))
