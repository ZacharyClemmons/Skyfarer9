class_name CBrain extends Component
## An NPC's mind. Layers, from the bottom up:
##  - Body state: needs, health, emotions (mood, fear, anger, panic, grief).
##  - Who they are: personality traits + a Persona (backstory, interests, quirks, tastes,
##    ambitions, a typing Voice).
##  - What they believe: Knowledge (facts from their own senses, radio and gossip only),
##    Memory (episodes and relationships), Experience (what worked, dangerous and
##    favourite places, reputations of people).
##  - What they do: a utility selector over goals from survival instincts (Goals), their
##    job (JobAI), the shape of the day and their leisure (Routine), promises and errands
##    for other people, conversations and favours. Scores are bent by personality, mood,
##    learned outcomes and the time of day; jobs other people have already claimed on
##    the radio are left to them.
##  - How they come across: an inner monologue (thought), speech typed out at human
##    speed in their own voice, conversations with each other, and real answers to
##    whatever the player types (PlayerTalk).

const TRAITS := ["bravery", "curiosity", "diligence", "empathy", "loyalty", "honesty", "aggression", "sociability", "neuroticism", "lawfulness", "humor"]

var job := "assistant"
var traits := {}
var persona: Persona
var knowledge := Knowledge.new()
var memory := Memory.new()
var learned := Experience.new()
var goal: Dictionary = {}
var plan: Array = []
var action: ActBase = null
var act_t := 0.0 # seconds into the current action (for multi-tick Do steps)
var think_t := 0.0
var perceive_t := 0.0
var talk_cd := 0.0
var bark_cd := 0.0
var blocked := {} # cell -> expiry time
var mood := 0.0
var fear := 0.0
var anger := 0.0
var panic := 0.0
var grief := 0.0
var grief_for := 0
var bed_id := 0
var last_acquired: Entity = null
var goal_cooldowns := {} # goal id -> time until which it's suppressed
var antag: Dictionary = {} # traitor objective, if any
var home_area := ""
var follow_target: Entity = null
var follow_until := 0.0
var last_goal_id := ""
var order_from := 0
var debug_line := ""
## inner monologue: the latest reason behind what they're doing
var thought := ""
var thought_log: Array = [] # [[time, text]] recent thoughts, newest last
# talking
var convo: Conversation = null
var last_talked := {} # id -> time
var chat_with := 0 # who they're talking with (player conversations)
var chat_until := 0.0
var chat_last := 0.0 # when they last actually answered the player
var last_heard := {}
var pending := {} # a question we asked and are waiting on
var say_queue: Array = [] # [{t, text, to}]
var give_queue: Array = [] # [{t, item, to}]
var known_bio := {} # ids whose backstory we've heard
var told_bio := {} # ids we've told our own story to
var taught := {}
var compliments := {}
var insults := {}
var last_favor_ask := -999.0
var greeted := {} # id -> time last greeted in passing
var remarked := {} # "what:id" -> time
var avoid_until := {} # id -> time
# day
var routine_done := {}
var plan_with := {} # {what, where, who, until}
var last_smoke := 0.0
var visited := {}
var errand := {} # something someone asked of us (see PlayerTalk)
var orders: Array = [] # bartender / cook orders [{who, kind, what, t}]
var report_log := {} # fact type -> last time we reported one on the radio
var emote_t := 60.0
var scanned := {} # patient id -> when we last ran the health analyzer over them

var mob: CMob
var health: CHealth
var needs: CNeeds
var inv: CInventory

func key() -> StringName:
	return &"brain"

func on_added() -> void:
	mob = e.c(&"mob")
	health = e.c(&"health")
	needs = e.c(&"needs")
	inv = e.c(&"inv")
	think_t = Game.rng.randf() * 1.0
	perceive_t = Game.rng.randf() * 0.6
	last_smoke = -Game.rng.randf() * 300.0
	if persona == null:
		persona = Persona.generate(Game.rng, job, traits)

func setup_personality(rng: RandomNumberGenerator, bias: Dictionary) -> void:
	for t in TRAITS:
		traits[t] = clampf(rng.randfn(0.5, 0.18) + bias.get(t, 0.0), 0.0, 1.0)
	persona = Persona.generate(rng, job, traits)

func tv(t: String) -> float:
	return traits.get(t, 0.5)

func voice_formal() -> float:
	return persona.voice.get("formal", 0.5) if persona else 0.5

func personality_words() -> Array:
	var out := []
	if tv("bravery") > 0.72: out.append("brave")
	elif tv("bravery") < 0.28: out.append("cowardly")
	if tv("curiosity") > 0.72: out.append("curious")
	if tv("diligence") < 0.28: out.append("lazy")
	elif tv("diligence") > 0.75: out.append("hard-working")
	if tv("empathy") > 0.72: out.append("kind")
	elif tv("empathy") < 0.28: out.append("selfish")
	if tv("loyalty") > 0.75: out.append("loyal")
	if tv("honesty") < 0.28: out.append("dishonest")
	if tv("aggression") > 0.72: out.append("hot-headed")
	if tv("sociability") > 0.72: out.append("chatty")
	elif tv("sociability") < 0.25: out.append("reserved")
	if tv("neuroticism") > 0.72: out.append("anxious")
	if tv("humor") > 0.75: out.append("funny")
	if tv("lawfulness") < 0.25: out.append("rule-bending")
	return out

# ------------------------------------------------------------------ relationships
func rel_to(other: Entity):
	if other == null:
		return null
	return memory.rel(other.id)

func affinity(id: int) -> float:
	return memory.rel(id).affinity if memory.has_rel(id) else 0.0

func is_friend(id: int) -> bool:
	return affinity(id) > 35.0

func is_enemy(id: int) -> bool:
	return affinity(id) < -35.0

func bond(other: Entity, amount: float) -> void:
	if other == null:
		return
	var r := memory.rel(other.id)
	var before := r.affinity
	r.affinity = clampf(r.affinity + amount, -100.0, 100.0)
	if amount > 0:
		r.trust = clampf(r.trust + amount * 0.3, -100.0, 100.0)
	# milestones worth a line in the station log
	var ob: CBrain = other.c(&"brain")
	if ob != null:
		var key := "%d:%d" % [mini(e.id, other.id), maxi(e.id, other.id)]
		if before <= 60.0 and r.affinity > 60.0 and ob.affinity(e.id) > 50.0 and not CBrain._milestones.has(key + "f"):
			CBrain._milestones[key + "f"] = true
			Bus.chronicle.emit("%s and %s have become friends." % [e.display_name, other.display_name], 1)
		elif before >= -50.0 and r.affinity < -50.0 and ob.affinity(e.id) < -40.0 and not CBrain._milestones.has(key + "e"):
			CBrain._milestones[key + "e"] = true
			Bus.chronicle.emit("%s and %s can't stand each other any more." % [e.display_name, other.display_name], 1)
	# friendships feel good; the social ambition notices
	if r.affinity > 40.0 and "make_friend" in persona.ambitions and not persona.ambition_done.has("make_friend") and r.familiarity > 30.0:
		ambition_progress("make_friend")

static var _milestones := {}

func mood_word() -> String:
	if panic > 0.6: return "looks panicked"
	if health.body_temp < 285: return "is shivering"
	if grief > 0.5: return "looks like they've been crying"
	if needs.stress > 75: return "looks close to breaking down"
	if anger > 0.6: return "looks furious"
	if needs.stress > 50: return "looks stressed"
	if needs.energy < 20: return "looks exhausted"
	if needs.fun < 20: return "looks bored out of their mind"
	if mood > 0.45: return "seems in good spirits"
	if mood < -0.4: return "looks miserable"
	return ""

# ------------------------------------------------------------------ helpers used by actions
func avoid_cells() -> Array:
	var out := []
	for c in blocked.keys():
		if blocked[c] > Game.time:
			out.append(c)
		else:
			blocked.erase(c)
	for f in knowledge.of_type("fire"):
		if Game.time - f["t"] < 30.0:
			out.append(f["cell"])
	# walk around people already sitting in the evacuation crawler
	if Game.evac and Game.evac.mode == Evac.DOCKED:
		_crawler_seats_taken(out)
	return out

func _crawler_seats_taken(out: Array) -> void:
	for v in Game.evac.vessels():
		for c in v.interior:
			for x in Game.at(c):
				if x != e and x.has_c(&"mob"):
					out.append(c)
					break

func block_cell(c: Vector2i) -> void:
	blocked[c] = Game.time + 45.0

func cell_dangerous(c: Vector2i) -> bool:
	for f in knowledge.of_type("fire"):
		var fc: Vector2i = f["cell"]
		if absi(fc.x - c.x) <= 1 and absi(fc.y - c.y) <= 1:
			return true
	return false

func may_force(door) -> bool:
	## Will this person pry a door they can't open? Depends on urgency and scruples.
	if inv.find_tool("crowbar") == null:
		return false
	var urgent: float = goal.get("score", 0.0)
	if not door.powered() and not door.welded:
		return urgent > 150.0
	return urgent > 650.0 or (tv("lawfulness") < 0.3 and urgent > 250.0)

## Can they go into this area without breaking the rules?
func may_enter(a: Area) -> bool:
	if a == null or a.restricted.is_empty():
		return true
	for tag in a.restricted:
		if inv.has_access(tag):
			return true
	return false

func inject_front(acts: Array) -> void:
	if action != null:
		plan.push_front(action)
	for i in range(acts.size() - 1, -1, -1):
		plan.push_front(acts[i])
	action = null

func stash_active() -> void:
	var it := inv.active_item()
	if it == null:
		return
	var bag: Entity = inv.worn("back")
	if bag and bag.has_c(&"storage") and bag.c(&"storage").insert(it):
		inv.remove_ref(it)
		return
	var belt: Entity = inv.worn("belt")
	if belt and belt.has_c(&"storage") and belt.c(&"storage").insert(it):
		inv.remove_ref(it)
		return
	for p in ["pocket_l", "pocket_r"]:
		if inv.can_equip(it, p):
			inv.remove_ref(it)
			inv.slots[p] = it
			inv._refresh()
			return
	inv.drop(it)

func stash_active_if_full() -> void:
	if inv.free_hand() < 0:
		stash_active()

## Make `item` (which we carry somewhere) the active-hand item.
func ready_item(item: Entity) -> Entity:
	if item == null or not is_instance_valid(item):
		return null
	if inv.active_item() == item:
		return item
	if inv.other_item() == item:
		inv.active = 1 - inv.active
		return item
	# in a slot or bag
	var inside := false
	for it in inv.all_items():
		if it == item:
			inside = true
	if not inside:
		return null
	if inv.active_item() != null:
		if inv.other_item() == null:
			inv.active = 1 - inv.active
		else:
			stash_active()
	Interact.detach(item)
	item.holder = e
	item.visible = false
	inv.hands[inv.active] = item
	inv._refresh()
	return item

func ready_tool(quality: String) -> Entity:
	var it := inv.find_tool(quality)
	return ready_item(it) if it else null

func ready_tag(tag: String) -> Entity:
	var it := inv.find_item(func(x): return x.ai_tags().has(tag))
	return ready_item(it) if it else null

func ready_stack(material: String) -> Entity:
	var it := inv.find_item(func(x): return x.has_c(&"stack") and x.c(&"stack").material == material)
	return ready_item(it) if it else null

func has_tag(tag: String) -> bool:
	return inv.find_item(func(x): return x.ai_tags().has(tag)) != null

func has_tool(quality: String) -> bool:
	return inv.find_tool(quality) != null

func radio_channel() -> String:
	return Jobs.radio_channel(job)

func work_areas() -> Array:
	var out := []
	for nm in Jobs.JOBS.get(job, {}).get("work", []):
		for a in Game.map.areas:
			if a.name.begins_with(nm):
				out.append(a)
	return out

func work_cells() -> Array:
	var cells := []
	for a in work_areas():
		cells.append_array(a.cells)
	return cells

func in_work_area() -> bool:
	var a := Game.map.area_at(e.cell)
	return a in work_areas()

func area_named(prefix: String) -> Area:
	for a in Game.map.areas:
		if a.name.begins_with(prefix):
			return a
	return null

## Is this item something they need to do their job (and won't hand over lightly)?
func needs_for_job(it: Entity) -> bool:
	if it == null:
		return false
	var tags := it.ai_tags()
	if it in inv.slots.values() and it.proto in ["id_card", "headset"]:
		return true
	match Jobs.dept(job):
		"engineering":
			if tags.has("tool_welder") or tags.has("tool_wrench") or tags.has("tool_multitool") or tags.has("tool_crowbar"):
				return true
		"medical":
			if tags.has("medical") or it.proto in ["defib", "health_analyzer"]:
				return true
		"security":
			if tags.has("weapon") or tags.has("restraint"):
				return true
	if job == "janitor" and tags.has("tool_mop"):
		return true
	if job == "miner" and (tags.has("tool_dig") or tags.has("air_tank")):
		return true
	return false

## Something they could spare as a thank-you.
func spare_item_for(_to: Entity) -> Entity:
	return inv.find_item(func(x): return _spare_ok(x))

func _spare_ok(x: Entity) -> bool:
	if x in inv.slots.values() or needs_for_job(x) or not x.has_c(&"item"):
		return false
	return x.proto in ["flashlight", "glowstick", "drink_water", "drink_soda", "drink_cocoa", "cig_pack", "lighter", "pen", "soap"] or x.ai_tags().has("food")

func can_first_aid(s: Entity) -> bool:
	return tv("empathy") > 0.5 and inv.find_item(func(x): return x.has_c(&"meditem") and x.c(&"meditem").uses > 0 and not x.c(&"meditem").analyzer) != null and s.dist_to(e) < 12

# ------------------------------------------------------------------ giving
## Hand `item` to `to` (adjacent). Goes through the same path as a player's drag-and-drop.
func give_item(item: Entity, to: Entity) -> bool:
	if item == null or not is_instance_valid(item) or item.removed or to == null or not is_instance_valid(to):
		return false
	if item.root() != e or e.dist_to(to) > 1.6:
		return false
	var tinv: CInventory = to.c(&"inv")
	if tinv == null:
		return false
	Interact.detach(item)
	item.holder = null
	if not tinv.put_in_hands(item):
		item.visible = true
		Game.drop_to_map(item, to.cell)
		item.place(to.cell)
	mob.face(Defs.dir_from_vec(to.cell - e.cell) if to.cell != e.cell else mob.dir)
	Game.visible_message(e.cell, "%s hands %s to %s." % [e.display_name, item.the(), to.display_name])
	Game.tell(to, "%s hands you %s." % [e.display_name, item.the()], "good")
	inv._refresh()
	if to == Game.player and Game.hud:
		Game.hud.refresh_inventory()
	Bus.stimulus.emit({"type": "gift", "actor": e, "target": to, "cell": e.cell, "loud": 0.0, "illegal": false, "text": item.display_name, "item": item})
	return true

## Give now if close enough, otherwise walk over first.
func queue_give(item: Entity, to: Entity) -> void:
	if e.dist_to(to) <= 1.6:
		give_queue.append({"t": Game.time + 1.2, "item": item, "to": to})
	else:
		errand = {"kind": "give", "item": item.id, "for": to.id, "until": Game.time + 90.0}
		think_t = 0.0

func take_order(who: Entity, kind: String, what: String) -> void:
	for o in orders:
		if o["who"] == who.id and o["kind"] == kind:
			return
	orders.append({"who": who.id, "kind": kind, "what": what, "t": Game.time})
	think_t = 0.0

func make_plan(what: String, where: String, who: Entity) -> void:
	plan_with = {"what": what, "where": where, "who": who.id, "until": Game.time + 240.0}

func start_conversation(other: Entity, topic := "") -> bool:
	if convo != null or other == null:
		return false
	var ob: CBrain = other.c(&"brain")
	if ob != null:
		if ob.convo != null or ob.goal.get("score", 0.0) > 420.0 or ob.health.stat() != CHealth.CONSCIOUS:
			return false
		if ob.avoid_until.get(e.id, 0.0) > Game.time:
			return false
	else:
		# talking at someone without a brain (the player): one friendly line
		if e.tags.get("no_smalltalk", false) or other.tags.get("no_smalltalk", false):
			return false
		say(Dialogue.greeting(self, other) if randf() < 0.5 else Dialogue.smalltalk(self, other), {"to": other})
		chat_with = other.id
		chat_until = Game.time + PlayerTalk.CHAT_WINDOW
		last_talked[other.id] = Game.time
		needs.social = minf(100.0, needs.social + 10.0)
		return true
	var c := Conversation.begin(e, other, topic)
	if c == null:
		return false
	if Game.ai:
		Game.ai.convos.append(c)
	return true

## Hot-headed moment: a shove (or a punch, if they're really angry).
func lash_out(target: Entity, how := "shove") -> void:
	if target == null or not e.adjacent(target) or health.stat() != CHealth.CONSCIOUS:
		return
	mob.face(Defs.dir_from_vec(target.cell - e.cell) if target.cell != e.cell else mob.dir)
	if how == "shove":
		Combat.shove(e, target)
	else:
		mob.combat = true
		Interact.attack(e, target, null)
		mob.combat = false
	Bus.chronicle.emit("%s lost their temper with %s." % [e.display_name, target.display_name], 1)

func ambition_progress(id: String) -> void:
	if persona == null or not id in persona.ambitions or persona.ambition_done.has(id):
		return
	persona.ambition_done[id] = true
	needs.fun = minf(100.0, needs.fun + 30.0)
	needs.stress = maxf(0.0, needs.stress - 20.0)
	mood = minf(1.0, mood + 0.3)
	remember_thought("I did it: %s." % persona.ambition_text(id))
	Bus.chronicle.emit("%s managed to %s." % [e.display_name, persona.ambition_text(id)], 1)

# ------------------------------------------------------------------ acquisition planning
## Actions that end with an item carrying `tag` in our hands (or [] if already have it).
## Returns null when we know of no way to get one.
func plan_acquire(tag: String, vend_cat := ""):
	if has_tag(tag):
		return []
	var best := {}
	var bd := 1e9
	for f in knowledge.of_type("item_at"):
		if not tag in f.get("data", {}).get("tags", []):
			continue
		var it := Game.get_entity(f["subject"])
		if it == null or (it.root() != it and it.root().has_c(&"mob")):
			continue
		var c: Vector2i = f["cell"]
		var d := absi(c.x - e.cell.x) + absi(c.y - e.cell.y)
		# don't go back somewhere that hurt us for a spanner
		d += int(learned.danger_of(Game.map.area_at(c).id) * 60.0)
		if d < bd:
			bd = d
			best = f
	if not best.is_empty():
		var it := Game.get_entity(best["subject"])
		var goal_ent: Entity = it.holder if it.holder != null else it
		return [Act.GoTo.new(goal_ent, true), Act.PickUp.new(it)]
	if vend_cat != "":
		for f in knowledge.of_type("item_at"):
			if f.get("data", {}).get("vending", "") == vend_cat:
				var vm := Game.get_entity(f["subject"])
				if vm and vm.c(&"vending").has_stock(vend_cat):
					var proto: String = vm.c(&"vending").first_in_stock(vend_cat)
					return [Act.GoTo.new(vm, true), Act.Vend.new(vm, proto)]
	return null

## Like plan_acquire, but for a spoken item word ("welder", "cocoa", "gauze").
func plan_acquire_word(word: String):
	if inv.find_item(func(x): return SpeechIntent.item_matches(x, word)) != null:
		return []
	var spec: Array = SpeechIntent.ITEMS.get(word, ["", word])
	if spec[0] != "":
		var p = plan_acquire(spec[0], spec[0] if spec[0] in ["food", "drink", "tool"] else "")
		if p != null:
			return p
	var best := {}
	var bd := 1e9
	for f in knowledge.of_type("item_at"):
		var it := Game.get_entity(f["subject"])
		if it == null or it.root().has_c(&"mob"):
			continue
		if it.has_c(&"vending"):
			if PlayerTalk._vend_has(it, word):
				for p2 in it.c(&"vending").products:
					if p2["count"] > 0 and (p2["proto"].contains(spec[1]) or (spec[0] in ["food", "drink"] and p2["proto"].begins_with(spec[0]))):
						return [Act.GoTo.new(it, true), Act.Vend.new(it, p2["proto"])]
			continue
		if not SpeechIntent.item_matches(it, word):
			continue
		var c: Vector2i = f["cell"]
		var d := absi(c.x - e.cell.x) + absi(c.y - e.cell.y)
		if d < bd:
			bd = d
			best = f
	if best.is_empty():
		return null
	var it2 := Game.get_entity(best["subject"])
	return [Act.GoTo.new(it2.holder if it2.holder != null else it2, true), Act.PickUp.new(it2)]

# ------------------------------------------------------------------ perception
func perceive() -> void:
	var here := e.cell
	var lit := 1.0
	if Game.lighting:
		var i := Game.map.idx(here)
		lit = Game.lighting.acc_r[i] + Game.lighting.acc_g[i] + Game.lighting.amb[i] * 0.6
	var radius := 7 if lit > 0.25 or inv.find_item(func(x): return x.has_c(&"light") and x.c(&"light").lit) != null else 3
	for other in Game.in_radius(here, radius):
		if other == e or other.holder != null or other.removed:
			continue
		if not _los(here, other.cell):
			continue
		var om: CMob = other.c(&"mob")
		if om and om.sneak and maxi(absi(other.cell.x - here.x), absi(other.cell.y - here.y)) > 3:
			continue
		_observe(other)
	if Game.atmos:
		for c in Game.atmos.hotspots.keys():
			if absi(c.x - here.x) <= radius and absi(c.y - here.y) <= radius and _los(here, c):
				knowledge.learn({"key": "fire@%d,%d" % [c.x, c.y], "type": "fire", "cell": c, "severity": 3}, Knowledge.SEEN)
		# damaged infrastructure in view
		for d in Game.map.damaged_pipes():
			var pc: Vector2i = d[1]
			if absi(pc.x - here.x) <= radius and absi(pc.y - here.y) <= radius:
				var visible_leak := Game.map.pipe_leaking(d[0], pc)
				if visible_leak and (not Game.map.has_floor_tile(pc) or absi(pc.x - here.x) + absi(pc.y - here.y) <= 3):
					knowledge.learn({"key": "pipe_leak:%d:%d" % [d[0], Game.map.idx(pc)], "type": "pipe_leak", "cell": pc, "severity": 2 if d[0] == StationMap.PL_HOT else 1, "data": {"layer": d[0]}}, Knowledge.SEEN)
		var i2 := Game.map.idx(here)
		var smoke = Game.atmos.partial(i2, Defs.G_SMOKE) + Game.atmos.partial(i2, Defs.G_PLASMA)
		if smoke > 2.0:
			knowledge.learn({"key": "gas@%d" % Game.map.area[i2], "type": "hazard_gas", "cell": here, "area": Game.map.area[i2], "severity": 2}, Knowledge.SEEN)
	# what my body tells me
	var a := Game.map.area_at(here)
	if not a.outdoor and not a.power_light and a.apc != null:
		knowledge.learn({"key": "power_out:%d" % a.id, "type": "power_out", "cell": a.apc.cell, "subject": a.apc.id, "area": a.id, "severity": 2}, Knowledge.FELT)
	if health.breath_status in ["low_o2", "no_air", "toxic"] and not a.outdoor:
		knowledge.learn({"key": "gas@%d" % a.id, "type": "hazard_gas", "cell": here, "area": a.id, "severity": 3}, Knowledge.FELT)
		learned.scare(a.id, 0.06, "couldn't breathe in there")
	if not a.outdoor and Game.atmos and Game.atmos.temp_at(here) < 268.0:
		knowledge.learn({"key": "cold:%d" % a.id, "type": "cold_area", "cell": here, "area": a.id, "severity": 2}, Knowledge.FELT)
		learned.scare(a.id, 0.02, "it's freezing in there")
	# breaches: broken windows in sight
	for y in range(here.y - 5, here.y + 6):
		for x in range(here.x - 5, here.x + 6):
			var c := Vector2i(x, y)
			if Game.map.inb(c) and Defs.is_grille(Game.map.structure[Game.map.idx(c)]) and not Game.map.is_outdoor(c):
				var touches_out := false
				for d2 in Defs.DIRS4:
					if Game.map.is_outdoor(c + d2):
						touches_out = true
				if touches_out and _los(here, c):
					knowledge.learn({"key": "breach@%d,%d" % [c.x, c.y], "type": "breach", "cell": c, "severity": 3}, Knowledge.SEEN)

func _los(a: Vector2i, b: Vector2i) -> bool:
	return Game.lighting._los(a, b) if Game.lighting else true

func _observe(o: Entity) -> void:
	if o.has_c(&"mob"):
		var oh: CHealth = o.c(&"health")
		knowledge.learn({"key": "seen:%d" % o.id, "type": "person_seen", "subject": o.id, "cell": o.cell, "severity": 0}, Knowledge.SEEN)
		if oh:
			if oh.dead:
				var f := knowledge.learn({"key": "body:%d" % o.id, "type": "body", "subject": o.id, "cell": o.cell, "severity": 5}, Knowledge.SEEN)
				if f.get("new", false):
					_on_see_body(o)
			elif oh.in_crit() or (oh.stat() == CHealth.UNCONSCIOUS and not oh.sleeping):
				knowledge.learn({"key": "down:%d" % o.id, "type": "person_down", "subject": o.id, "cell": o.cell, "severity": 4}, Knowledge.SEEN)
			elif oh.health() < 70 or Body.bleed_rate(oh) > 0.3:
				knowledge.learn({"key": "injured:%d" % o.id, "type": "injured", "subject": o.id, "cell": o.cell, "severity": maxi(oh.severity(), 3 if Body.bleed_rate(oh) > 1.0 else 1)}, Knowledge.SEEN)
			else:
				knowledge.forget("injured:%d" % o.id)
				knowledge.forget("down:%d" % o.id)
			if oh.on_fire > 0:
				knowledge.learn({"key": "burning:%d" % o.id, "type": "burning_person", "subject": o.id, "cell": o.cell, "severity": 4}, Knowledge.SEEN)
			if oh.disease != null and oh.disease.stage >= 2:
				knowledge.learn({"key": "sick:%d" % o.id, "type": "sick", "subject": o.id, "cell": o.cell, "severity": 2}, Knowledge.SEEN)
			if not oh.dead and oh.stat() == CHealth.CONSCIOUS:
				_social_notice(o, oh)
		return
	var tags := o.ai_tags()
	if tags.has("broken_machine"):
		knowledge.learn({"key": "broken:%d" % o.id, "type": "broken_machine", "subject": o.id, "cell": o.cell, "severity": 2 if (tags.has("heater") or tags.has("apc") or tags.has("air_supply")) else 1}, Knowledge.SEEN)
	elif knowledge.has("broken:%d" % o.id):
		knowledge.forget("broken:%d" % o.id)
	if tags.has("mess"):
		knowledge.learn({"key": "mess:%d" % o.id, "type": "mess", "subject": o.id, "cell": o.cell, "severity": 2 if tags.has("slippery") else 1}, Knowledge.SEEN)
	if o.has_c(&"item") or tags.has("vending") or tags.has("has_extinguisher") or tags.has("bed"):
		remember_item(o, Knowledge.SEEN)

## Noticing people: saying hello in passing, remarking on the state they're in.
func _social_notice(o: Entity, oh: CHealth) -> void:
	if o.dist_to(e) > 5 or health.stat() != CHealth.CONSCIOUS or panic > 0.5:
		return
	var busy: bool = goal.get("score", 0.0) > 420.0
	var nm := Dialogue.call_name(self, o)
	# alarming things first
	var bleed := Body.bleed_rate(oh)
	if bleed > 0.8 and _remark_ok("bleed", o.id, 60.0):
		say(Dialogue.fill(Dialogue.pick(Dialogue.LINES["see_bleeding"]), {"name": nm}), {"to": o, "excited": true})
		if can_first_aid(o) and not busy and goal.get("score", 0.0) < 400.0:
			errand = {"kind": "treat", "for": o.id, "until": Game.time + 60.0}
		return
	# someone gasping for air in front of us
	if oh.breath_status in ["low_o2", "no_air", "toxic"] and not Game.map.is_outdoor(o.cell) and _remark_ok("choke", o.id, 45.0):
		say(Dialogue.fill(Dialogue.pick(Dialogue.LINES["see_choking"]), {"name": nm}), {"to": o, "excited": true})
		knowledge.learn({"key": "gas@%d" % Game.map.area_at(o.cell).id, "type": "hazard_gas", "cell": o.cell, "area": Game.map.area_at(o.cell).id, "severity": 3}, Knowledge.SEEN)
		# the brave and kind drag them out
		if tv("empathy") + tv("bravery") > 1.0 and not busy:
			knowledge.learn({"key": "down:%d" % o.id, "type": "person_down", "subject": o.id, "cell": o.cell, "severity": 4}, Knowledge.SEEN)
		return
	# badly hurt, and still walking around
	if oh.health() < 60 and _remark_ok("hurt", o.id, 180.0) and not busy:
		say(Dialogue.fill(Dialogue.pick(Dialogue.LINES["see_hurt"]), {"name": nm}), {"to": o})
		knowledge.learn({"key": "injured:%d" % o.id, "type": "injured", "subject": o.id, "cell": o.cell, "severity": 3}, Knowledge.SEEN)
		return
	if busy:
		return
	var om: CMob = o.c(&"mob")
	var oinv: CInventory = o.c(&"inv")
	# blood all over someone, with no good reason we know of
	if oinv and _bloodied(oinv) and oh.health() > 80 and not Jobs.dept(om.job) == "medical":
		if _remark_ok("bloody", o.id, 300.0):
			say(Dialogue.fill(Dialogue.pick(Dialogue.LINES["see_bloody"]), {"name": nm}), {"to": o})
			learned.note(o.id, "creepy", 0.08)
			if Jobs.dept(job) == "security" or tv("curiosity") > 0.6:
				knowledge.learn({"key": "bloody:%d" % o.id, "type": "noise", "cell": o.cell, "severity": 1, "data": {"what": "bloody"}}, Knowledge.SEEN)
			return
	# a weapon out on green alert (security cares, everybody notices)
	if om and om.combat and Game.alert_level < 2 and oinv and oinv.active_item() and oinv.active_item().ai_tags().has("weapon") and not Jobs.dept(om.job) in ["security", "command"]:
		if Jobs.dept(job) == "security" and _remark_ok("weapon", o.id, 90.0):
			say(Dialogue.fill(Dialogue.pick(Dialogue.LINES["see_weapon"]), {"name": nm}), {"to": o})
			learned.note(o.id, "violent", 0.04)
			return
	# outside without a coat
	if not e.tags.get("no_smalltalk", false) and Game.map.is_outdoor(o.cell) and oinv and (oinv.worn("suit") == null or oinv.worn("suit").c(&"clothing").insulation < 0.3) and _remark_ok("coat", o.id, 120.0):
		say(Dialogue.fill(Dialogue.pick(Dialogue.LINES["no_coat_outside"]), {"name": nm}), {"to": o})
		return
	# hello in passing: friends and colleagues, the player more than most
	if anger > 0.4 or fear > 0.4 or knowledge.has("crime:assault:%d" % o.id) or knowledge.has("crime:murder:%d" % o.id):
		return
	if convo == null and o.dist_to(e) <= 4 and Game.time - greeted.get(o.id, -999.0) > (240.0 if o == Game.player else 540.0):
		var r := memory.rel(o.id)
		var chance := 0.06 + tv("sociability") * 0.22 + r.affinity / 180.0
		if o == Game.player:
			chance += 0.2
		if r.familiarity < 5:
			chance *= 0.5
		greeted[o.id] = Game.time
		if avoid_until.get(o.id, 0.0) > Game.time or is_enemy(o.id):
			if randf() < 0.3:
				mob.emote("glares at %s." % o.display_name)
			return
		if randf() < chance:
			if randf() < 0.3:
				mob.emote(Dialogue.pick(["waves at %s." % o.display_name, "nods at %s." % o.display_name, "gives %s a little wave." % o.display_name]))
			else:
				say(Dialogue.fill(Dialogue.pick(Dialogue.LINES["passing_hi"]), {"name": nm}), {"to": o})
			if o == Game.player:
				chat_with = o.id
				chat_until = Game.time + 15.0
				# sometimes they've got something to ask
				if randf() < 0.18 + tv("sociability") * 0.1 and memory.rel(o.id).affinity > -5:
					PlayerTalk._maybe_ask_favor(self, o, 2.5)

func _bloodied(oinv: CInventory) -> bool:
	for sl in ["uniform", "suit", "gloves", "head"]:
		var it: Entity = oinv.worn(sl)
		if it and Blood.bloody(it):
			return true
	return false

func _mood_emote() -> String:
	if grief > 0.4:
		return Dialogue.pick(["wipes their eyes.", "stares at nothing for a while.", "sniffs quietly."])
	if anger > 0.5:
		return Dialogue.pick(["clenches their fists.", "mutters something under their breath.", "kicks the floor."])
	if fear > 0.5 or panic > 0.4:
		return Dialogue.pick(["glances over their shoulder.", "jumps at a noise.", "fidgets nervously."])
	if health.body_temp < 303.0:
		return Dialogue.pick(["rubs their hands together.", "shivers.", "blows into their cupped hands."])
	if needs.energy < 25:
		return Dialogue.pick(["yawns widely.", "rubs their eyes.", "nods off for a second."])
	if needs.fun < 30:
		return Dialogue.pick(["drums their fingers.", "sighs heavily.", "stares at the ceiling."])
	if mood > 0.45:
		return Dialogue.pick(["whistles a little tune.", "smiles to themselves.", "hums happily."])
	if persona.has_quirk("hums") and randf() < 0.5:
		return "hums while they work."
	if persona.has_quirk("superstitious") and randf() < 0.3:
		return "knocks on the wall for luck."
	return ""

func _remark_ok(what: String, id: int, cd: float) -> bool:
	var k := "%s:%d" % [what, id]
	if Game.time - remarked.get(k, -999.0) < cd:
		return false
	remarked[k] = Game.time
	return true

func remember_item(o: Entity, src: int) -> void:
	var tags := o.ai_tags()
	var keep := false
	for t in ["tool", "food", "drink", "medical", "extinguisher", "tank", "warm_clothing", "breath_mask", "weapon", "restraint", "material", "ingredient", "vending", "has_extinguisher", "insulated_gloves", "analyzer", "bed", "chem", "ore", "valuable"]:
		if tags.has(t):
			keep = true
			break
	for k in tags.keys():
		if k.begins_with("tool_") or k.begins_with("heals_") or k.begins_with("mat_"):
			keep = true
	if not keep:
		return
	var tlist := tags.keys()
	if tags.has("has_extinguisher"):
		tlist.append("extinguisher")
	var data := {"tags": tlist, "proto": o.proto}
	if tags.has("vending"):
		for k in tags.keys():
			if k.begins_with("sells_"):
				data["vending"] = k.substr(6)
				knowledge.learn({"key": "vend:%d:%s" % [o.id, data["vending"]], "type": "item_at", "subject": o.id, "cell": o.cell, "data": {"tags": [], "vending": data["vending"]}}, src)
		return
	var holder := o.holder
	if tags.has("has_extinguisher"):
		var ext: Entity = o.c(&"furniture").stored
		if ext:
			knowledge.learn({"key": "item:%d" % ext.id, "type": "item_at", "subject": ext.id, "cell": o.cell, "data": {"tags": ["extinguisher", "tool"], "proto": "extinguisher"}}, src)
		return
	knowledge.learn({"key": "item:%d" % o.id, "type": "item_at", "subject": o.id, "cell": o.root_cell() if holder else o.cell, "data": data}, src)

func _on_see_body(o: Entity) -> void:
	var fr := is_friend(o.id)
	memory.remember("friend_died" if fr else "saw_death", 0, o.id, "I found %s's body in %s." % [o.display_name, Game.map.area_at(o.cell).name], 1.0 if fr else 0.6)
	needs.add_stress(40.0 if fr else 20.0 * (0.5 + tv("neuroticism")))
	fear = minf(1.0, fear + 0.4)
	learned.scare(Game.map.area_at(o.cell).id, 0.35 if fr else 0.2, "that's where %s died" % o.display_name.split(" ")[0])
	if fr or affinity(o.id) > 15:
		var g := clampf(affinity(o.id) / 70.0, 0.3, 1.0)
		if g > grief:
			grief = g
			grief_for = o.id
		remember_thought("%s is dead. I can't believe it." % o.display_name.split(" ")[0])
	if fr:
		bark(Dialogue.line("friend_dead", self, {"name": o.display_name}))
	else:
		bark(Dialogue.line("see_body", self, {"name": o.display_name}))

# ------------------------------------------------------------------ stimuli
func on_stimulus(info: Dictionary) -> void:
	var cell: Vector2i = info.get("cell", e.cell)
	var dist: int = maxi(absi(cell.x - e.cell.x), absi(cell.y - e.cell.y))
	var loud: float = info.get("loud", 0.0)
	var seen: bool = dist <= 7 and _los(e.cell, cell)
	var heard: bool = dist <= loud
	var type: String = info.get("type", "")
	var actor: Entity = info.get("actor")
	var target: Entity = info.get("target")
	# a gift lands in our hands even if we didn't see it coming
	if type == "gift" and target == e and health.stat() == CHealth.CONSCIOUS:
		_on_gift(actor, info)
		return
	if not seen and not heard:
		return
	if health.stat() != CHealth.CONSCIOUS:
		return
	var actor_id := actor.id if actor != null and is_instance_valid(actor) else 0
	var target_id := target.id if target != null and is_instance_valid(target) and target.has_c(&"mob") else 0
	var area_id: int = Game.map.area_at(cell).id
	if actor == e:
		if info.get("illegal", false):
			knowledge.learn({"key": "mycrime:%s:%d" % [type, int(Game.time)], "type": "my_crime", "cell": cell, "data": {"crime": type, "victim": target_id}}, Knowledge.FELT)
		return
	match type:
		"assault", "theft", "break_in", "vandalism", "sabotage", "trespass":
			if not info.get("illegal", false):
				return
			if not seen or actor_id == 0:
				if heard and type in ["assault", "vandalism", "break_in"]:
					knowledge.learn({"key": "noise@%d,%d" % [cell.x, cell.y], "type": "noise", "cell": cell, "severity": 1}, Knowledge.HEARD)
				return
			_witness_crime(type, actor, target, cell, info)
		"death":
			if seen and target:
				knowledge.learn({"key": "body:%d" % target.id, "type": "body", "subject": target.id, "cell": target.cell, "severity": 5}, Knowledge.SEEN)
				if actor_id > 0 and actor.has_c(&"mob") and actor != target:
					_witness_crime("murder", actor, target, cell, info)
				if target.id != e.id:
					_on_see_body(target)
		"collapse":
			if seen and target:
				knowledge.learn({"key": "down:%d" % target.id, "type": "person_down", "subject": target.id, "cell": target.cell, "severity": 4}, Knowledge.SEEN)
				if is_friend(target.id):
					needs.add_stress(10)
		"fire", "on_fire", "explosion", "pipe_burst", "chem_reaction", "window_broken":
			fear = minf(1.0, fear + (0.5 if type == "explosion" else 0.2) * (1.2 - tv("bravery")))
			needs.add_stress(6.0 * (0.5 + tv("neuroticism")))
			learned.scare(area_id, 0.3 if type == "explosion" else 0.15, {"fire": "there was a fire", "explosion": "something blew up", "window_broken": "the window blew out"}.get(type, "something went wrong there"))
			if type == "fire" or type == "on_fire":
				knowledge.learn({"key": "fire@%d,%d" % [cell.x, cell.y], "type": "fire", "cell": cell, "severity": 3}, Knowledge.SEEN if seen else Knowledge.HEARD)
			elif type == "window_broken":
				knowledge.learn({"key": "breach@%d,%d" % [cell.x, cell.y], "type": "breach", "cell": cell, "severity": 3}, Knowledge.SEEN if seen else Knowledge.HEARD)
			else:
				knowledge.learn({"key": "noise@%d,%d" % [cell.x, cell.y], "type": "noise", "cell": cell, "severity": 3, "data": {"what": type}}, Knowledge.SEEN if seen else Knowledge.HEARD)
			if seen and info.get("illegal", false) and actor_id > 0 and actor.has_c(&"mob"):
				_witness_crime("fire" if type == "fire" else "explosion", actor, null, cell, info)
			if seen and dist <= 4 and bark_cd <= 0:
				bark(Dialogue.line("alarm_" + type, self, {"area": Game.map.area_at(cell).name}))
		"pipe_leak":
			knowledge.learn({"key": "pipe_leak:%d:%d" % [info.get("layer", 0), Game.map.idx(cell)], "type": "pipe_leak", "cell": cell, "severity": 2 if info.get("layer", 0) == StationMap.PL_HOT else 1, "data": {"layer": info.get("layer", 0)}}, Knowledge.HEARD)
		"treated", "rescue":
			if actor_id > 0:
				learned.note(actor_id, "helpful", 0.3 if target_id == e.id else 0.12, seen)
				if type == "rescue":
					learned.note(actor_id, "brave", 0.15, seen)
			if target_id == e.id:
				memory.remember("saved_me" if type == "rescue" else "treated_me", actor_id, e.id, "%s %s me in %s." % [actor.display_name, "saved" if type == "rescue" else "patched", Game.map.area_at(cell).name])
				learned.note(actor_id, "kind", 0.15)
				if bark_cd <= 0:
					bark(Dialogue.line("thanks", self, {"name": Dialogue.call_name(self, actor)}))
			elif seen and actor_id > 0:
				memory.remember("saw_rescue", actor_id, target_id, "I saw %s help %s." % [actor.display_name, target.display_name if target else "someone"], 0.5)
		"hug":
			if target_id == e.id:
				memory.remember("hugged_me", actor_id, e.id, "%s hugged me." % actor.display_name)
				learned.note(actor_id, "kind", 0.08)
				needs.stress = maxf(0.0, needs.stress - 5.0)
		"cuffed":
			if target_id == e.id:
				memory.remember("arrested_me", actor_id, e.id, "%s arrested me." % actor.display_name)
		"repaired":
			if seen and actor_id > 0:
				learned.note(actor_id, "competent", 0.1)
				if Game.map.area_at(cell) in work_areas():
					memory.remember("fixed_my_workplace", actor_id, 0, "%s fixed things in my workplace." % actor.display_name, 0.5)
		"slip":
			if actor_id == e.id:
				learned.scare(area_id, 0.03, "I slipped there")
			elif seen and tv("humor") > 0.6 and bark_cd <= 0:
				bark(Dialogue.line("laugh", self, {}))
		"vomit":
			if seen:
				knowledge.learn({"key": "sick:%d" % actor_id, "type": "sick", "subject": actor_id, "cell": cell, "severity": 2}, Knowledge.SEEN)

func _on_gift(from: Entity, info: Dictionary) -> void:
	if from == null or not is_instance_valid(from):
		return
	var item: Entity = info.get("item")
	if item == null:
		for it in inv.hands:
			if it and it.display_name == info.get("text", ""):
				item = it
	memory.remember("gave_me", from.id, e.id, "%s gave me %s." % [from.display_name, info.get("text", "something")])
	learned.note(from.id, "kind", 0.06)
	if item == null:
		return
	var f := Favors.on_gift(from, e, item)
	if not f.is_empty():
		return # the favor thanks them
	# unasked-for presents
	if item.has_c(&"food") and not item.c(&"food").ingredient and (needs.nutrition < 70 or (item.c(&"food").drink and needs.hydration < 70)):
		say_later(Dialogue.line("food_thanks", self, {}), -1, from)
		bond(from, 5.0)
		memory.remember("fed_me", from.id, e.id, "%s gave me food when I was hungry." % from.display_name, 0.8)
		inject_front([Act.Consume.new(item)])
	elif needs_for_job(item) or item.ai_tags().has("tool") or item.ai_tags().has("medical"):
		say_later(Dialogue.pick(["Oh, thanks! I can use this.", "Perfect, just what I needed.", "Nice, thanks."]), -1, from)
		bond(from, 4.0)
		stash_active_if_full()
	elif item.ai_tags().has("weapon") and Jobs.dept(job) != "security":
		say_later(Dialogue.pick(["Why are you giving me a weapon?", "I don't want this.", "Uh. What am I supposed to do with this?"]), -1, from)
		learned.note(from.id, "creepy", 0.05)
	elif item.ai_tags().has("ore") and persona.has_quirk("collector"):
		say_later("Ooh, for my collection? Thank you!", -1, from)
		bond(from, 6.0)
		ambition_progress("collect")
	else:
		say_later(Dialogue.line("not_wanted", self, {}) if randf() < 0.5 else Dialogue.pick(["Thanks, I guess.", "Oh. Thanks!", "Huh, thanks."]), -1, from)
		bond(from, 1.5)

func _witness_crime(crime: String, actor: Entity, victim: Entity, cell: Vector2i, info: Dictionary) -> void:
	var actor_id := actor.id
	var victim_id := victim.id if victim != null and victim.has_c(&"mob") else 0
	# lawful violence: security arresting a wanted person isn't a crime to most
	var am: CMob = actor.c(&"mob")
	if am and Jobs.dept(am.job) == "security" and victim_id > 0:
		if SecurityRecords.is_wanted(victim_id):
			return
		var ab: CBrain = actor.c(&"brain")
		if ab and ab.goal.get("id", "") in ["arrest", "stop_fight", "escort"]:
			return # an officer making an arrest (and whoever gets bumped along the way)
		if ab == null and not knowledge.of_type("crime").filter(func(f): return f.get("data", {}).get("actor", 0) == victim_id and Game.time - f["t"] < 60.0).is_empty():
			return # the player-officer taking down someone we saw attack people
	# hitting back at someone who's hitting you is self-defense; an officer taking down a
	# brawler is doing their job
	if crime == "assault" and victim_id > 0:
		var their := knowledge.get_fact("crime:assault:%d" % victim_id)
		if not their.is_empty() and Game.time - their["t"] < 30.0 and (their.get("data", {}).get("victim", 0) == actor_id or (am and Jobs.dept(am.job) == "security")):
			return
	# an engineer prying their way into a dark room to get the power back isn't a burglar
	if crime == "break_in" and am and Jobs.dept(am.job) == "engineering" and not Game.map.area_at(cell).powered("light"):
		return
	if crime == "trespass":
		# only security and the area's own staff care much about trespassing, and they
		# deal with it in person: a word, not a radio call
		if Jobs.dept(job) != "security" and not Game.map.area_at(cell) in work_areas():
			return
		if bark_cd <= 0 and actor.dist_to(e) <= 6 and _remark_ok("trespass", actor_id, 240.0):
			bark(Dialogue.pick(["You're not supposed to be in here, %s.", "%s, this area's restricted. Out.", "Hey, %s. Staff only."]) % Dialogue.call_name(self, actor))
		learned.note(actor_id, "creepy", 0.03)
		return
	var sev := {"assault": 3, "murder": 5, "theft": 2, "break_in": 2, "vandalism": 2, "sabotage": 3, "trespass": 1, "fire": 3, "explosion": 4}.get(crime, 2)
	var data := {"crime": crime, "actor": actor_id, "victim": victim_id, "what": info.get("text", "")}
	var f := knowledge.learn({"key": "crime:%s:%d" % [crime, actor_id], "type": "crime", "subject": actor_id, "cell": cell, "severity": sev, "data": data}, Knowledge.SEEN)
	# reputation: this is how word about people starts
	match crime:
		"assault", "murder": learned.note(actor_id, "violent", 0.25 if crime == "assault" else 0.7)
		"theft", "break_in": learned.note(actor_id, "thief", 0.3)
		"sabotage", "vandalism", "fire", "explosion":
			learned.note(actor_id, "violent", 0.15)
			learned.note(actor_id, "creepy", 0.15)
	var steady := 0.35 if Jobs.dept(job) == "security" else 1.0
	if victim_id == e.id:
		memory.remember("hurt_me" if crime == "assault" else "stole_from_me", actor_id, e.id, "%s %s me." % [actor.display_name, "attacked" if crime == "assault" else "robbed"])
		anger = minf(1.0, anger + 0.5 * (0.5 + tv("aggression")))
		fear = minf(1.0, fear + 0.4 * (1.2 - tv("bravery")) * steady)
		learned.scare(Game.map.area_at(cell).id, 0.3, "%s attacked me there" % actor.display_name.split(" ")[0])
		remember_thought("%s attacked me!" % actor.display_name.split(" ")[0])
	elif victim_id > 0 and is_friend(victim_id):
		memory.remember("friend_hurt_by", actor_id, victim_id, "%s hurt my friend %s." % [actor.display_name, victim.display_name])
		anger = minf(1.0, anger + 0.4)
	else:
		memory.remember("saw_assault" if crime in ["assault", "murder"] else "saw_crime", actor_id, victim_id, "I saw %s %s." % [actor.display_name, knowledge._crime_text(f).split(" in ")[0]], 0.7 if sev >= 3 else 0.4)
	needs.add_stress(sev * 3.0 * (0.5 + tv("neuroticism")) * steady)
	if bark_cd <= 0 and sev >= 2:
		var friend_of_actor := is_friend(actor_id)
		if friend_of_actor and tv("loyalty") > 0.6:
			pass # looks the other way
		elif tv("aggression") > 0.65 and tv("bravery") > 0.5:
			bark(Dialogue.line("confront", self, {"name": Dialogue.call_name(self, actor)}))
		else:
			bark(Dialogue.line("witness", self, {"name": Dialogue.call_name(self, actor)}))

func on_radio(speaker: Entity, channel: String, text: String, fact: Dictionary) -> void:
	var hs := inv.headset()
	if hs == null or not hs.enabled or not channel in hs.channels:
		return
	if health.stat() != CHealth.CONSCIOUS:
		return
	if speaker == e:
		return
	if not fact.is_empty() and fact.has("key"):
		var trust := 0.95
		if speaker != null:
			trust = clampf(0.75 + affinity(speaker.id) / 400.0 + memory.rel(speaker.id).trust / 300.0 + learned.trust_mod(speaker.id) * 0.2, 0.2, 1.0)
		var f := fact.duplicate()
		if f["type"] == "alarm_clear":
			for k in knowledge.facts.keys():
				var old: Dictionary = knowledge.facts[k]
				if old["type"] in ["atmos_alarm", "fire"] and old.get("area", -1) == f.get("area", -2):
					knowledge.forget(k)
			return
		if f["type"] == "reactor_ok":
			knowledge.forget("reactor_hot")
			return
		var got := knowledge.learn(f, Knowledge.RADIO, trust, speaker.id if speaker else 0)
		got["reported"] = true
		got["via_radio"] = channel
		if f["type"] == "order" and f.get("data", {}).get("to", "") in [job, Jobs.dept(job), "all"]:
			order_from = speaker.id if speaker else 0
	elif speaker != null and speaker.has_c(&"mob") and not speaker.has_c(&"brain"):
		# the player talking on the radio
		_parse_player_radio(speaker, channel, text)

func _parse_player_radio(speaker: Entity, _channel: String, text: String) -> void:
	var t := text.to_lower()
	var area := _area_in_text(t)
	if area == null:
		area = Game.map.area_at(speaker.cell)
	var trust := clampf(0.7 + learned.trust_mod(speaker.id) * 0.3, 0.2, 1.0)
	if t.contains("fire"):
		knowledge.learn({"key": "fire@radio%d" % area.id, "type": "fire", "cell": area.center, "severity": 3}, Knowledge.RADIO, trust, speaker.id)
	if t.contains("medic") or t.contains("help") or t.contains("hurt") or t.contains("injured") or t.contains("bleeding"):
		knowledge.learn({"key": "down:%d" % speaker.id, "type": "person_down" if t.contains("dying") or t.contains("crit") else "injured", "subject": speaker.id, "cell": speaker.cell, "severity": 3}, Knowledge.RADIO, trust, speaker.id)
	if t.contains("breach"):
		knowledge.learn({"key": "breach@radio%d" % area.id, "type": "breach", "cell": area.center, "severity": 3}, Knowledge.RADIO, trust, speaker.id)
	if t.contains("power"):
		if area.apc:
			knowledge.learn({"key": "power_out:%d" % area.id, "type": "power_out", "cell": area.apc.cell, "subject": area.apc.id, "area": area.id, "severity": 2}, Knowledge.RADIO, trust, speaker.id)
	if t.contains("leak"):
		knowledge.learn({"key": "told_leak:%d" % area.id, "type": "pipe_leak", "cell": area.center, "severity": 1, "data": {"layer": 0}}, Knowledge.RADIO, trust * 0.8, speaker.id)
	if t.contains("security") or t.contains("attacked") or t.contains("thief") or t.contains("traitor"):
		knowledge.learn({"key": "noise@radio%d" % area.id, "type": "noise", "cell": speaker.cell, "severity": 2}, Knowledge.RADIO, trust, speaker.id)
		var culprit := SpeechIntent.person_in(SpeechIntent.norm(text), e, speaker)
		if culprit and (t.contains("attack") or t.contains("stole") or t.contains("traitor") or t.contains("killed")):
			var crime := "theft" if t.contains("stole") else ("murder" if t.contains("killed") else "assault")
			knowledge.learn({"key": "crime:%s:%d" % [crime, culprit.id], "type": "crime", "subject": culprit.id, "cell": speaker.cell, "severity": 3,
				"data": {"crime": crime, "actor": culprit.id, "victim": speaker.id if t.contains(" me") else 0}}, Knowledge.RADIO, trust * 0.8, speaker.id)

func _area_in_text(t: String) -> Area:
	return SpeechIntent.area_in(SpeechIntent.norm(t))

## Local speech heard (players and NPCs).
func on_speech(speaker: Entity, text: String, cell: Vector2i, radius: float, addressed: bool) -> void:
	if speaker == e or health.stat() != CHealth.CONSCIOUS:
		return
	if maxi(absi(cell.x - e.cell.x), absi(cell.y - e.cell.y)) > radius:
		return
	if speaker.has_c(&"brain"):
		return # NPC speech between NPCs is handled by their Conversation
	if addressed:
		PlayerTalk.respond(self, speaker, text)
	else:
		PlayerTalk.overhear(self, speaker, text)

func _is_superior(other: Entity) -> bool:
	var om: CMob = other.c(&"mob")
	if om == null:
		return false
	if om.job == "captain":
		return true
	if om.job == "hop" and Jobs.JOBS.get(job, {}).get("supervisor", "") == "hop":
		return true
	return Jobs.is_head(om.job) and Jobs.dept(om.job) == Jobs.dept(job) and not Jobs.is_head(job)

func _person_in_text(t: String) -> Entity:
	return SpeechIntent.person_in(SpeechIntent.norm(t), e, null)

# ------------------------------------------------------------------ speaking
## Say something out loud, typed in their own voice. ctx: {to, excited, raw}
func say(text: String, ctx := {}) -> void:
	if text == "":
		return
	if not ctx.get("raw", false):
		text = Voice.apply(text, self, ctx)
	mob.say(text)

## Say it after the time it takes to type (delay < 0: work it out from the length).
## Queued lines come out in order.
func say_later(text: String, delay := -1.0, to: Entity = null) -> void:
	if text == "":
		return
	# Port traders speak for themselves (CVendor.idle) in their own register. Left to the
	# crew brain they ask each other what is under all this ice, on an island that has
	# never seen any, which is funny exactly once.
	if e.tags.get("no_smalltalk", false):
		return
	var d := delay
	if d < 0:
		d = 0.5 + text.length() * 0.035 * (1.3 - voice_formal() * 0.4) + randf() * 0.6
	var start := Game.time
	if not say_queue.is_empty():
		start = maxf(start, say_queue[-1]["t"])
	say_queue.append({"t": start + d, "text": text, "to": to})
	if to != null and not to.has_c(&"brain"):
		chat_with = to.id
		chat_until = maxf(chat_until, start + d + PlayerTalk.CHAT_WINDOW)

func bark(text: String) -> void:
	if bark_cd > 0 or text == "":
		return
	bark_cd = 8.0 + Game.rng.randf() * 8.0
	say(text, {"excited": text.ends_with("!")})

func radio_say(channel: String, text: String, fact := {}) -> void:
	text = Voice.apply(text, self, {"radio": true, "excited": text.ends_with("!")})
	if not mob.radio(channel, text, fact):
		return
	if fact.has("key"):
		var own := knowledge.get_fact(fact["key"])
		if not own.is_empty():
			own["reported"] = true

func remember_thought(t: String) -> void:
	thought = t
	thought_log.append([Game.clock_string(), t])
	if thought_log.size() > 14:
		thought_log.pop_front()

# ------------------------------------------------------------------ conversation & gossip
func _gossip_facts(n: int, listener: Entity) -> Array:
	var cands := []
	for f in knowledge.facts.values():
		if f.get("shared_with_%d" % listener.id, false):
			continue
		var v := knowledge.gossip_value(f)
		if v <= 0:
			continue
		# honesty filter: don't incriminate yourself or close friends
		if f["type"] == "crime":
			var actor: int = f.get("data", {}).get("actor", 0)
			if actor == listener.id:
				continue
			if is_friend(actor) and tv("loyalty") > 0.55 and tv("honesty") < 0.7:
				continue
		cands.append([v * randf_range(0.7, 1.3) * (1.4 if persona.has_quirk("gossip") else 1.0), f])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var out := []
	for k in mini(n, cands.size()):
		out.append(cands[k][1])
	return out

## Kept for callers that just want a chat to happen now.
func converse(other: Entity) -> void:
	start_conversation(other)

func hear_gossip(from: Entity, f: Dictionary, conf: float) -> void:
	var trust := clampf(0.6 + memory.rel(from.id).trust / 200.0 + affinity(from.id) / 400.0 + learned.trust_mod(from.id) * 0.2, 0.1, 1.0)
	knowledge.learn(f, Knowledge.TOLD, conf * trust, from.id)
	if f["type"] == "crime":
		var actor: int = f.get("data", {}).get("actor", 0)
		if actor > 0 and actor != e.id:
			var r := memory.rel(actor)
			r.affinity = clampf(r.affinity - 5.0 * trust, -100.0, 100.0)
			r.trust = clampf(r.trust - 8.0 * trust, -100.0, 100.0)
			var crime: String = f.get("data", {}).get("crime", "")
			learned.hear_rep(actor, "violent" if crime in ["assault", "murder"] else "thief", 0.6, trust)

func _disliked_person() -> Entity:
	var worst: Entity = null
	var wv := -15.0
	for id in memory.rels.keys():
		var a: float = memory.rels[id].affinity
		if a < wv:
			var ent := Game.get_entity(id)
			if ent and ent.has_c(&"mob"):
				wv = a
				worst = ent
	return worst

func learn_health(target: Entity) -> void:
	var h: CHealth = target.c(&"health")
	if h and h.health() < 90:
		knowledge.learn({"key": "injured:%d" % target.id, "type": "injured", "subject": target.id, "cell": target.cell, "severity": h.severity()}, Knowledge.SEEN)

# ------------------------------------------------------------------ emotions & per-frame
func update_emotions(dt: float) -> void:
	fear = maxf(0.0, fear - dt * 0.02 * (0.5 + tv("bravery")))
	anger = maxf(0.0, anger - dt * 0.015)
	grief = maxf(0.0, grief - dt * 0.0006)
	var target_mood := needs.mood() + memory.emotional_load() * 0.3 - fear * 0.3 - grief * 0.4
	# tg mood: the moodlets they're living with, and how their sanity is holding up
	var md: CMood = e.c(&"mood")
	if md:
		target_mood += clampf(md.mood / 15.0, -0.6, 0.6) + clampf((md.sanity - CMood.SANITY_NEUTRAL) / 250.0, -0.4, 0.2)
	if persona and persona.has_quirk("optimist"):
		target_mood += 0.15
	if persona and persona.has_quirk("complainer"):
		target_mood -= 0.08
	mood = move_toward(mood, clampf(target_mood, -1.0, 1.0), dt * 0.05)
	var stress_n := needs.stress / 100.0
	var p := clampf(fear * 0.7 + stress_n * 0.5 - tv("bravery") * 0.4 + tv("neuroticism") * 0.25 - 0.15, 0.0, 1.0)
	# people trained for emergencies keep their heads
	if Jobs.dept(job) in ["security", "command"]:
		p *= 0.4
	elif Jobs.dept(job) in ["medical", "engineering"]:
		p *= 0.75
	panic = move_toward(panic, p, dt * 0.2)
	memory.decay(dt)
	learned.decay(dt)
	bark_cd = maxf(0.0, bark_cd - dt)
	talk_cd = maxf(0.0, talk_cd - dt)

## Typed-out speech and hand-overs that were waiting their turn; and the little things
## people do without thinking.
func tick_social(dt: float) -> void:
	emote_t -= dt
	if emote_t <= 0.0:
		emote_t = randf_range(50.0, 110.0)
		if convo == null and goal.get("score", 0.0) < 250.0 and health.stat() == CHealth.CONSCIOUS:
			var em := _mood_emote()
			if em != "":
				mob.emote(em)
	while not say_queue.is_empty() and say_queue[0]["t"] <= Game.time:
		var s: Dictionary = say_queue.pop_front()
		if health.stat() == CHealth.CONSCIOUS:
			var to: Entity = s["to"]
			if to != null and is_instance_valid(to) and to.cell != e.cell and to.dist_to(e) <= 7:
				mob.face(Defs.dir_from_vec(to.cell - e.cell))
			say(s["text"], {"to": to})
	while not give_queue.is_empty() and give_queue[0]["t"] <= Game.time:
		var g: Dictionary = give_queue.pop_front()
		if not give_item(g["item"], g["to"]) and is_instance_valid(g["to"]) and is_instance_valid(g["item"]):
			errand = {"kind": "give", "item": g["item"].id, "for": g["to"].id, "until": Game.time + 60.0}

# ------------------------------------------------------------------ decision making
func think() -> void:
	knowledge.expire()
	if health.stat() != CHealth.CONSCIOUS:
		plan.clear()
		action = null
		goal = {}
		if convo:
			convo.abort()
		return
	var cands: Array
	if health.cuffed:
		cands = Goals.custody_candidates(self)
		if cands.is_empty():
			plan.clear()
			action = null
			goal = {"id": "cuffed", "score": 0, "desc": "restrained"}
			return
	else:
		cands = Goals.candidates(self)
		var wm := Routine.work_mult(self)
		for c in JobAI.candidates(self):
			if c["score"] < 420.0:
				c["score"] *= wm
			cands.append(c)
		cands.append_array(Routine.candidates(self))
		cands.append_array(_personal_candidates())
	if cands.is_empty():
		return
	var noise := 0.12 * (0.5 + tv("neuroticism")) + panic * 0.25
	var best := {}
	var bs := -1.0
	var talking := convo != null and not convo.done
	for c in cands:
		var s: float = c["score"]
		if goal_cooldowns.get(c["id"], 0.0) > Game.time:
			continue
		# mid-conversation, only something that matters pulls them away
		if talking and s < 420.0 and c["id"] != "chat" and c["id"] != goal.get("id", ""):
			continue
		if goal_cooldowns.get("_all", 0.0) > Game.time and s < 700.0:
			continue
		s *= learned.goal_bias(c["id"])
		# someone else already took this job on the radio
		if c.has("claim") and Game.ai and s < 750.0:
			var who: int = Game.ai.claimed_by(c["claim"])
			if who != 0 and who != e.id:
				s *= 0.3
		s *= 1.0 + randf_range(-noise, noise)
		if not goal.is_empty() and c["id"] == goal.get("id", "") and (action != null or not plan.is_empty()):
			s *= 1.3 # commitment
		c["eff"] = s
		if s > bs:
			bs = s
			best = c
	if best.is_empty():
		return
	if not goal.is_empty() and best["id"] == goal.get("id", "") and (action != null or not plan.is_empty()):
		return
	# switch goal
	var built = best["plan"].call()
	if built == null or (built is Array and built.is_empty()):
		goal_cooldowns[best["id"]] = Game.time + 6.0
		return
	if DoAfter.busy(e) and best["score"] < 700:
		return
	if DoAfter.busy(e):
		DoAfter.cancel(e)
	if not best.get("keep_pull", false) and mob.pulling != null:
		mob.stop_pulling()
	# walking away from a conversation for something more pressing
	if convo != null and best["id"] != "chat" and best["id"] != "socialize" and not best["id"].begins_with("meet"):
		convo.abort()
	goal = best
	plan = built
	action = null
	act_t = 0.0
	last_goal_id = best["id"]
	var why: String = best.get("why", "")
	if why == "":
		why = Thoughts.of(self, best)
	if why != "" and why != thought:
		remember_thought(why)
	if best.has("claim") and Game.ai:
		Game.ai.claim(best["claim"], e.id, best.get("claim_ttl", 90.0))
		_ack_radio(best)
	if best.has("on_start"):
		best["on_start"].call()

## Tell the team we've got it, if the job came in over the radio.
func _ack_radio(g: Dictionary) -> void:
	var key: String = g.get("claim", "")
	var f := knowledge.get_fact(key)
	if f.is_empty() or not f.has("via_radio") or f.get("acked", false):
		return
	f["acked"] = true
	if inv.headset() == null or randf() > 0.55 + tv("diligence") * 0.3:
		return
	var ch: String = f["via_radio"]
	var line := Dialogue.line("ack_head" if Jobs.is_head(job) else "ack", self, {})
	if randf() < 0.4:
		line += " " + Dialogue.pick(["Heading to %s.", "Be there soon.", "Coming from %s."]).replace("%s", Game.map.area_at(f.get("cell", e.cell)).name if randf() < 0.5 else Game.map.area_at(e.cell).name)
	radio_say(ch, line)

## Goals that come from people: errands asked of us, orders to fill, plans, conversations.
func _personal_candidates() -> Array:
	var out := []
	# in a conversation someone else started
	if convo != null and not convo.done and convo.a != e:
		var c := convo
		out.append({"id": "chat", "score": 290.0, "desc": "chatting with %s" % c.a.display_name, "plan": func(): return [Act.Chat.new(c)], "cooldown": 0.5, "why": ""})
	# errands the player (or someone) asked for
	if not errand.is_empty():
		if Game.time > errand.get("until", 0.0):
			errand = {}
		else:
			var eg := Errands.candidate(self)
			if not eg.is_empty():
				out.append(eg)
	# people waiting for us to serve them
	if not orders.is_empty():
		var og := Errands.order_candidate(self)
		if not og.is_empty():
			out.append(og)
	# the collector's habit
	if persona.has_quirk("collector") or "collect" in persona.ambitions:
		var nice := knowledge.nearest("item_at", e.cell, func(f): return ("ore" in f.get("data", {}).get("tags", []) or "valuable" in f.get("data", {}).get("tags", [])) and Game.get_entity(f["subject"]) != null and Game.get_entity(f["subject"]).holder == null)
		if not nice.is_empty() and Vector2(nice["cell"] - e.cell).length() < 14:
			var it := Game.get_entity(nice["subject"])
			out.append({"id": "collect", "score": 90.0 + tv("curiosity") * 60.0, "desc": "picking up %s" % it.display_name, "plan": func(): return [Act.GoTo.new(it, true, false), Act.PickUp.new(it), Act.Do.new(CBrain._pocket, "pocketing it")],
				"cooldown": 120.0, "fail_cooldown": 120.0, "why": "Ooh, that looks interesting."})
	return out

static func _pocket(bb: CBrain, _dt: float) -> int:
	bb.ambition_progress("collect")
	bb.stash_active()
	return ActBase.DONE

## Survival instinct: mask up and open the air tank when the air goes bad or we step outside.
func _internals_instinct() -> void:
	var outdoors := Game.map.is_outdoor(e.cell)
	var bad_air := health.breath_status in ["low_o2", "no_air", "toxic"]
	if mob.internals:
		if not outdoors and not bad_air and Game.atmos.partial(Game.map.idx(e.cell), Defs.G_O2) > 18.0:
			mob.internals = false
		return
	if not (outdoors or bad_air):
		return
	if Game.life._internals_tank(e) == null:
		var tank: Entity = inv.find_item(func(x): return x.ai_tags().has("air_tank"))
		if tank == null:
			return
		# move the tank somewhere it can feed the mask (belt/pocket/hand)
		ready_item(tank)
	var mask: Entity = inv.worn("mask")
	if mask == null or not mask.c(&"clothing").breath_mask:
		var bm: Entity = inv.find_item(func(x): return x.ai_tags().has("breath_mask") and not x in inv.slots.values())
		if bm == null:
			return
		inject_front([Act.Equip.new(bm)])
		return
	mob.internals = true

## Ready to go out on the glacier? (warm clothes and an air supply)
func outdoor_ready() -> bool:
	var suit: Entity = inv.worn("suit")
	var warm = suit != null and suit.c(&"clothing").insulation >= 0.3
	var air := inv.find_item(func(x): return x.ai_tags().has("air_tank")) != null
	var mask := inv.find_item(func(x): return x.ai_tags().has("breath_mask")) != null
	return warm and air and mask

func act(dt: float) -> void:
	if health.stat() != CHealth.CONSCIOUS or (health.cuffed and goal.get("id", "") != "custody"):
		return
	_internals_instinct()
	if action == null:
		if plan.is_empty():
			if not goal.is_empty():
				learned.record(goal["id"], true)
				goal_cooldowns[goal["id"]] = Game.time + goal.get("cooldown", 4.0)
				goal = {}
				think_t = minf(think_t, 0.2)
			return
		action = plan.pop_front()
		act_t = 0.0
		action.start(self)
	var st := action.tick(self, dt)
	if st == ActBase.DONE:
		action = null
	elif st == ActBase.FAILED:
		action = null
		plan.clear()
		if not goal.is_empty():
			learned.record(goal["id"], false)
			goal_cooldowns[goal["id"]] = Game.time + goal.get("fail_cooldown", 12.0) * (1.0 + learned.failures(goal["id"]) * 0.25)
			goal = {}
		think_t = minf(think_t, 0.3)
		mob.combat = false

func status_text() -> String:
	var g: String = goal.get("desc", "idle")
	var a: String = action.label if action else ""
	return "%s%s" % [g, (" (" + a + ")") if a != "" and a != g else ""]
