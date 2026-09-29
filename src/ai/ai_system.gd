class_name AISystem extends Node
## Runs every NPC mind: staggered perception and thinking, per-frame acting. Routes
## stimuli, speech and radio to the brains that could actually sense them, works out who
## the player is talking to, runs NPC conversations, keeps the job board (who has
## claimed which task, so five engineers don't all run to the same leak), answers radio
## questions, and paces the background radio chatter that makes the station feel lived in.

var nav := Navigator.new()
var brains: Array = []
var debug := false
var convos: Array = [] # Conversation
var claims := {} # task key -> {id, until}
var chatter_t := 40.0
var favor_t := 2.0
var radio_queue: Array = [] # [{t, b, ch, text}] replies being "typed"
var _far_acc := {} # entity id -> dt owed to a far-away brain that acts every 4th frame
var _frame := 0
const FAR_TILES := 80

func setup(m: StationMap) -> void:
	nav.setup(m)
	Bus.stimulus.connect(_on_stimulus)
	Bus.radio.connect(_on_radio)
	Bus.speech.connect(_on_speech)
	Favors.reset()

## Break the reference cycles (conversations <-> brains, queued lines holding entities)
## before the engine tears everything down.
func _exit_tree() -> void:
	for c in convos:
		c.done = true
		c.ba = null
		c.bb = null
	convos.clear()
	radio_queue.clear()
	for e in Game.all_with(&"brain"):
		if is_instance_valid(e):
			var b: CBrain = e.c(&"brain")
			b.convo = null
			b.say_queue.clear()
			b.give_queue.clear()
			b.plan.clear()
			b.action = null
			b.goal = {}

func _process(delta: float) -> void:
	var _pt := Perf.t0()
	_process_body(delta)
	Perf.add("ai", _pt)

func _process_body(delta: float) -> void:
	if not Game.running or Game.paused:
		return
	var d := delta * Game.time_scale
	brains = Game.all_with(&"brain")
	_frame += 1
	var pc := Vector2i(-99999, -99999)
	if Game.player != null and is_instance_valid(Game.player):
		pc = Game.player.cell
	for e in brains:
		if e.removed:
			continue
		var b: CBrain = e.c(&"brain")
		if b.health.dead:
			if b.convo:
				b.convo.abort()
			continue
		b.update_emotions(d)
		b.tick_social(d)
		b.perceive_t -= d
		if b.perceive_t <= 0.0:
			b.perceive_t = 0.55 + randf() * 0.2
			if b.health.stat() == CHealth.CONSCIOUS:
				b.perceive()
		b.think_t -= d
		if b.think_t <= 0.0:
			b.think_t = 0.8 + randf() * 0.4
			b.think()
		# brains far from the player act on a quarter of the frames with the dt they were owed
		if pc.x > -99999 and absi(e.cell.x - pc.x) + absi(e.cell.y - pc.y) > FAR_TILES:
			var owed: float = _far_acc.get(e.id, 0.0) + d
			if (_frame + e.id) % 4 != 0:
				_far_acc[e.id] = owed
				continue
			_far_acc.erase(e.id)
			b.act(owed)
		else:
			b.act(d)
	for c in convos:
		c.tick(d)
	convos = convos.filter(func(c): return not c.done)
	favor_t -= d
	if favor_t <= 0.0:
		favor_t = 2.0
		Favors.tick()
	if not radio_queue.is_empty():
		_flush_radio()
	chatter_t -= d
	if chatter_t <= 0.0:
		chatter_t = randf_range(45.0, 90.0)
		_radio_chatter()

# ------------------------------------------------------------------ the job board
func claim(key: String, id: int, ttl := 90.0) -> void:
	if key == "":
		return
	var cur: Dictionary = claims.get(key, {})
	if not cur.is_empty() and cur["id"] != id and cur["until"] > Game.time:
		return
	claims[key] = {"id": id, "until": Game.time + ttl}

func claimed_by(key: String) -> int:
	var cur: Dictionary = claims.get(key, {})
	if cur.is_empty():
		return 0
	if cur["until"] < Game.time:
		claims.erase(key)
		return 0
	var who := Game.get_entity(cur["id"])
	if who == null or who.c(&"health").stat() != CHealth.CONSCIOUS:
		claims.erase(key)
		return 0
	var wb: CBrain = who.c(&"brain")
	if wb and wb.goal.get("claim", "") != key:
		return 0 # they've moved on to something else
	return cur["id"]

# ------------------------------------------------------------------ senses
func _on_stimulus(info: Dictionary) -> void:
	var cell: Vector2i = info.get("cell", Vector2i.ZERO)
	var r := int(maxf(info.get("loud", 0.0), 8.0)) + 1
	for e in Game.all_with(&"brain"):
		if absi(e.cell.x - cell.x) <= r and absi(e.cell.y - cell.y) <= r:
			e.c(&"brain").on_stimulus(info)
		elif info.get("type", "") == "gift" and info.get("target") == e:
			e.c(&"brain").on_stimulus(info)

func _on_radio(speaker: Entity, channel: String, text: String, fact: Dictionary) -> void:
	for e in Game.all_with(&"brain"):
		e.c(&"brain").on_radio(speaker, channel, text, fact)
	if speaker != null and is_instance_valid(speaker) and speaker.has_c(&"mob") and not speaker.has_c(&"brain") and fact.is_empty():
		radio_question(speaker, channel, text)

func _on_speech(speaker: Entity, text: String, cell: Vector2i, radius: float) -> void:
	if speaker == null or not is_instance_valid(speaker) or speaker.has_c(&"brain"):
		return
	var to := PlayerTalk.addressee(speaker, text, cell, radius)
	for e in Game.all_with(&"brain"):
		if absi(e.cell.x - cell.x) <= radius and absi(e.cell.y - cell.y) <= radius:
			e.c(&"brain").on_speech(speaker, text, cell, radius, e == to)

## The player asked something over the radio: whoever knows answers, like a person would.
func radio_question(speaker: Entity, channel: String, text: String) -> void:
	var t := SpeechIntent.norm(text)
	var listeners: Array = Game.all_with(&"brain").filter(func(x): return x.c(&"health").stat() == CHealth.CONSCIOUS and x.c(&"inv").headset() != null and channel in x.c(&"inv").headset().channels)
	if listeners.is_empty():
		return
	# addressed by name on the radio?
	var named: Entity = null
	for m in listeners:
		if SpeechIntent.names_me(t, m):
			named = m
			break
	var who := SpeechIntent.person_in(t, named, speaker)
	var asks_where := SpeechIntent.has_frag(t, ["where", "seen", "anyone seen", "location"])
	if named != null:
		var nb: CBrain = named.c(&"brain")
		var r := SpeechIntent.parse(text, named, speaker)
		var line := ""
		match r["intent"]:
			"where_unknown", "where_person":
				if r["person"] == null:
					line = "In %s." % Game.map.area_at(named.cell).name
			"doing":
				line = Dialogue.doing_line(nb)
			"how_are_you":
				line = Dialogue.status_line(nb)
			"greet":
				line = Dialogue.greeting(nb, speaker)
			"thanks":
				line = Dialogue.line("welcome", nb, {})
			"come_here", "follow":
				PlayerTalk._come_here(nb, speaker, r)
				line = Dialogue.pick(["On my way.", "Coming.", "Where are you?"])
		if SpeechIntent.has_frag(t, ["where are you", "where r u", "your location"]):
			line = "%s. Why?" % Game.map.area_at(named.cell).name
		if line != "":
			_radio_reply(nb, channel, line)
			return
	if who != null and asks_where:
		# the freshest sighting wins
		var best: Entity = null
		var bt := -1.0
		for m in listeners:
			var f: Dictionary = m.c(&"brain").knowledge.get_fact("seen:%d" % who.id)
			if not f.is_empty() and f["t"] > bt and m != who:
				bt = f["t"]
				best = m
		if best:
			var c: Vector2i = best.c(&"brain").knowledge.where_is(who.id)
			var ago := int(Game.minutes_since(bt))
			_radio_reply(best.c(&"brain"), channel, "Saw %s in %s%s." % [Dialogue.first(who), Game.map.area_at(c).name, " just now" if ago < 2 else ", %d minutes ago" % ago])
		elif who.has_c(&"brain") and who in listeners and randf() < 0.8:
			_radio_reply(who.c(&"brain"), channel, "I'm in %s." % Game.map.area_at(who.cell).name)
		return
	# "anyone got a welder?", "is there food?"
	var word := SpeechIntent.item_in(t)
	if word != "" and SpeechIntent.has_frag(t, ["anyone", "anybody", "any1", "who has", "who's got", "got a", "have a", "spare", "where can i", "is there"]):
		for m in listeners:
			var mb: CBrain = m.c(&"brain")
			if mb.inv.find_item(func(x): return SpeechIntent.item_matches(x, word)) != null and PlayerTalk.willing(mb, speaker, 0.3) > 0.4:
				_radio_reply(mb, channel, Dialogue.pick(["I've got one. Where are you?", "I have a spare %s, come find me in %s." % [word, Game.map.area_at(m.cell).name], "Got one here, %s." % Game.map.area_at(m.cell).name]))
				return
		for m in listeners:
			var mb2: CBrain = m.c(&"brain")
			for f in mb2.knowledge.of_type("item_at"):
				var it := Game.get_entity(f["subject"])
				if it and SpeechIntent.item_matches(it, word) and not it.root().has_c(&"mob"):
					_radio_reply(mb2, channel, "There's one in %s." % Game.map.area_at(f["cell"]).name)
					return
	# a general "hello?" or "anyone there?" gets somebody saying hi
	if SpeechIntent.has_any(t, SpeechIntent.GREET) or SpeechIntent.has_frag(t, ["anyone there", "anybody there", "hello?", "radio check"]):
		var m2: Entity = listeners[randi() % listeners.size()]
		if randf() < 0.4 + m2.c(&"brain").tv("sociability") * 0.4:
			_radio_reply(m2.c(&"brain"), channel, Dialogue.pick(["Hey.", "Loud and clear.", "Here.", "Morning!", "What's up?"]))

func _radio_reply(b: CBrain, channel: String, line: String) -> void:
	# typed reply: arrives after a human delay (sim time)
	radio_queue.append({"t": Game.time + 1.2 + line.length() * 0.04 + randf() * 1.5, "b": b.e, "ch": channel, "text": line})

func _flush_radio() -> void:
	var keep := []
	for r in radio_queue:
		if r["t"] > Game.time:
			keep.append(r)
			continue
		var who: Entity = r["b"]
		if is_instance_valid(who) and not who.removed and who.has_c(&"brain") and who.c(&"health").stat() == CHealth.CONSCIOUS:
			who.c(&"brain").radio_say(r["ch"], r["text"])
	radio_queue = keep

## Background radio: the station talking to itself. Rate-limited so it never spams.
func _radio_chatter() -> void:
	var cands: Array = Game.all_with(&"brain").filter(func(x):
		var b: CBrain = x.c(&"brain")
		return b.health.stat() == CHealth.CONSCIOUS and b.inv.headset() != null and b.goal.get("score", 0.0) < 350.0 and b.panic < 0.3)
	if cands.is_empty():
		return
	var w := {}
	for x in cands:
		var b: CBrain = x.c(&"brain")
		w[str(x.id)] = 0.2 + b.tv("sociability") + (0.6 if b.persona.has_quirk("gossip") else 0.0) + (0.4 if b.needs.fun < 40 else 0.0)
	var pick_id := Persona._weighted(Game.rng, w)
	var who := Game.get_entity(int(pick_id)) if pick_id != "" else null
	if who == null:
		return
	var b2: CBrain = who.c(&"brain")
	var hs := b2.inv.headset()
	var dept_ch := b2.radio_channel()
	if randf() < 0.45 and dept_ch in hs.channels and dept_ch != "Common":
		b2.radio_say(dept_ch, Dialogue.dept_status(b2))
	elif "Common" in hs.channels:
		b2.radio_say("Common", Dialogue.banter(b2))
		# somebody answers, sometimes
		if randf() < 0.45:
			var rep: Array = cands.filter(func(x): return x != who and "Common" in x.c(&"inv").headset().channels)
			if not rep.is_empty():
				var rb: CBrain = rep[randi() % rep.size()].c(&"brain")
				_radio_reply(rb, "Common", Dialogue.reply(rb, who, rb.affinity(who.id) > -10))
