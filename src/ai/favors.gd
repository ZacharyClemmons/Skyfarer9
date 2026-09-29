class_name Favors extends RefCounted
## Small requests people make of each other: "could you bring me some cable?", "take this
## to the chef for me?", "check on Dmitri, he's not answering". NPCs ask the player (who
## sees accepted favors in the objectives window) and each other. Doing someone a favor
## is remembered, builds trust, spreads a "helpful" reputation, and sometimes gets you a
## reward. Letting someone down is remembered too.
##
## A favor: {id, from, to, kind, want (item word), item_id, target (entity id), desc,
##           state offered/accepted/done/failed, t, expires, reward}

static var list: Array = []
static var _next := 1

static func reset() -> void:
	list.clear()
	_next = 1

static func make(from: Entity, to: Entity, kind: String, desc: String, extra := {}) -> Dictionary:
	var f := {"id": _next, "from": from.id, "to": to.id, "kind": kind, "desc": desc, "state": "offered", "t": Game.time,
		"expires": Game.time + extra.get("ttl", 600.0), "want": "", "item_id": 0, "target": 0, "reward": ""}
	f.merge(extra, true)
	_next += 1
	list.append(f)
	return f

static func get_favor(id: int) -> Dictionary:
	for f in list:
		if f["id"] == id:
			return f
	return {}

static func open_for(to_id: int) -> Array:
	return list.filter(func(f): return f["to"] == to_id and f["state"] == "accepted")

static func offered_by(from_id: int, to_id: int) -> Dictionary:
	for f in list:
		if f["from"] == from_id and f["to"] == to_id and f["state"] in ["offered", "accepted"]:
			return f
	return {}

static func active_from(from_id: int) -> Array:
	return list.filter(func(f): return f["from"] == from_id and f["state"] in ["offered", "accepted"])

## Housekeeping: expire old favors, check the ones that complete by themselves.
static func tick() -> void:
	for f in list:
		if f["state"] != "accepted" and f["state"] != "offered":
			continue
		var giver := Game.get_entity(f["from"])
		if giver == null or giver.c(&"health").dead:
			f["state"] = "failed"
			continue
		match f["kind"]:
			"fix":
				var m := Game.get_entity(f["target"])
				if m == null or (m.c(&"machine") and not m.c(&"machine").broken):
					complete(f, Game.get_entity(f["to"]))
					continue
			"check_on":
				pass # completes when the helper talks to the target (see note_talk)
		if Game.time > f["expires"]:
			if f["state"] == "accepted":
				_fail(f)
			else:
				f["state"] = "failed"

static func _fail(f: Dictionary) -> void:
	f["state"] = "failed"
	var giver := Game.get_entity(f["from"])
	var helper := Game.get_entity(f["to"])
	if giver and helper and giver.has_c(&"brain"):
		var b: CBrain = giver.c(&"brain")
		var r = b.memory.rel(helper.id)
		r.trust = clampf(r.trust - 6.0, -100, 100)
		b.learned.note(helper.id, "helpful", -0.08)
		if helper == Game.player:
			Game.tell(helper, "[color=#9ab8d8]You didn't get round to %s's favor (%s).[/color]" % [giver.display_name, f["desc"]], "info")

## Someone gave `item` to `to`: does it settle a favor?
static func on_gift(giver: Entity, to: Entity, item: Entity) -> Dictionary:
	for f in list:
		if f["state"] != "accepted" and f["state"] != "offered":
			continue
		if f["to"] != giver.id:
			continue
		match f["kind"]:
			"fetch":
				if f["from"] == to.id and SpeechIntent.item_matches(item, f["want"]):
					complete(f, giver)
					return f
			"deliver":
				if f["target"] == to.id and item.id == f["item_id"]:
					complete(f, giver)
					return f
	return {}

## The helper spoke to someone: settles "check on X" favors.
static func note_talk(helper: Entity, listener: Entity) -> void:
	for f in list:
		if f["state"] == "accepted" and f["kind"] == "check_on" and f["to"] == helper.id and f["target"] == listener.id:
			complete(f, helper)

static func complete(f: Dictionary, helper: Entity) -> void:
	f["state"] = "done"
	var giver := Game.get_entity(f["from"])
	if giver == null or helper == null:
		return
	if giver.has_c(&"brain"):
		var b: CBrain = giver.c(&"brain")
		b.memory.remember("helped_me", helper.id, giver.id, "%s did me a favor: %s." % [helper.display_name, f["desc"]])
		b.learned.note(helper.id, "helpful", 0.25)
		b.learned.note(helper.id, "kind", 0.1)
		b.needs.stress = maxf(0.0, b.needs.stress - 8.0)
		var line := Dialogue.fill(Dialogue.pick(Dialogue.LINES["favor_thanks"]), {"name": Dialogue.call_name(b, helper)})
		if giver.dist_to(helper) <= 7:
			b.say_later(line, 0.8)
		elif b.inv.headset():
			b.radio_say(b.radio_channel() if b.radio_channel() != "" else "Common", "%s, got it. Thanks!" % Dialogue.call_name(b, helper))
		# a reward, sometimes: something spare off their belt or out of their bag
		if f.get("reward", "") == "item" and giver.dist_to(helper) <= 2:
			var spare: Entity = b.spare_item_for(helper)
			if spare:
				b.give_item(spare, helper)
	if helper.has_c(&"brain"):
		helper.c(&"brain").learned.record("favor", true)
	Skills.add_xp(helper, "social", 12.0)
	Bus.chronicle.emit("%s did %s a favor." % [helper.display_name, giver.display_name], 0)
	if helper == Game.player:
		Game.tell(helper, "[color=#6ad88a]Favor done for %s: %s.[/color]" % [giver.display_name, f["desc"]], "good")
		# word gets around
		for x in Game.all_with(&"brain"):
			if x != giver and x.dist_to(giver) <= 6:
				x.c(&"brain").learned.note(helper.id, "helpful", 0.08, false)

## What would this NPC ask for right now? Returns a favor spec or {}.
static func want_of(b: CBrain, helper: Entity) -> Dictionary:
	var e := b.e
	# something they actually lack for their job or needs
	var wants := []
	if b.needs.nutrition < 45 and not b.has_tag("food"):
		wants.append(["fetch", "food", "bring me something to eat", 2.0])
	if b.needs.hydration < 45 and not b.has_tag("drink"):
		wants.append(["fetch", "drink", "bring me something to drink", 1.5])
	if b.health.body_temp < 300 and b.inv.worn("suit") == null:
		wants.append(["fetch", "coat", "find me a warm coat", 1.5])
	match Jobs.dept(b.job):
		"engineering":
			if not b.has_tag("mat_cable"):
				wants.append(["fetch", "cable", "bring me a cable coil", 1.2])
			if not b.has_tag("mat_glass"):
				wants.append(["fetch", "glass", "get me some glass sheets", 0.8])
			if not b.has_tag("mat_metal"):
				wants.append(["fetch", "metal", "bring me some metal sheets", 0.8])
		"medical":
			if b.inv.find_item(func(x): return x.proto == "gauze") == null:
				wants.append(["fetch", "gauze", "grab me some gauze", 1.5])
			if b.inv.find_item(func(x): return x.proto == "suture") == null:
				wants.append(["fetch", "suture", "find me some sutures", 0.8])
		"security":
			if not b.has_tag("restraint"):
				wants.append(["fetch", "cuffs", "find me a pair of cuffs", 1.0])
		"service":
			if b.job == "cook":
				wants.append(["fetch", "tomato", "bring me a tomato from the garden", 1.0])
				wants.append(["fetch", "meat", "find me some meat for the kitchen", 0.7])
			if b.job == "janitor" and not b.has_tool("mop"):
				wants.append(["fetch", "mop", "find my mop", 2.0])
		"science":
			wants.append(["fetch", "ore", "bring me some ore to study", 0.8])
	if b.persona:
		if b.persona.has_quirk("smoker") and b.inv.find_item(func(x): return x.proto.contains("cig")) == null:
			wants.append(["fetch", "cigarette", "get me a smoke", 1.0])
		if b.persona.has_quirk("coffee"):
			wants.append(["fetch", "cocoa", "grab me a hot cocoa", 1.2])
		if b.persona.has_quirk("collector"):
			wants.append(["fetch", "ore", "find me something interesting. Ore, maybe", 0.6])
	# check on a friend they haven't seen in a while
	for id in b.memory.rels.keys():
		var r = b.memory.rels[id]
		if r.affinity > 40:
			var fr := Game.get_entity(id)
			if fr and fr != helper and fr.has_c(&"mob") and not fr.c(&"health").dead:
				var seen: Dictionary = b.knowledge.get_fact("seen:%d" % id)
				if seen.is_empty() or Game.time - seen["t"] > 300.0:
					wants.append(["check_on", "", "check on %s for me, I haven't seen %s in ages" % [fr.display_name.split(" ")[0], fr.c(&"mob").them()], 1.2, id])
	# a delivery: something from their hands to a friend or a colleague
	var gift := b.inv.find_item(func(x): return x.has_c(&"food") and not x.c(&"food").ingredient)
	if gift:
		for id in b.memory.rels.keys():
			var fr2 := Game.get_entity(id)
			if fr2 and fr2 != helper and fr2 != e and fr2.has_c(&"mob") and b.memory.rels[id].affinity > 30 and fr2.dist_to(e) > 12 and not fr2.c(&"health").dead:
				wants.append(["deliver", "", "take this %s to %s" % [gift.display_name, fr2.display_name.split(" ")[0]], 0.8, id, gift.id])
				break
	# a broken machine at their workplace
	for f in b.knowledge.of_type("broken_machine"):
		var m := Game.get_entity(f["subject"])
		if m and Game.map.area_at(m.cell) in b.work_areas():
			wants.append(["fix", "", "fix %s in %s" % [m.display_name, Game.map.area_at(m.cell).name], 1.0, m.id])
			break
	if wants.is_empty():
		return {}
	var total := 0.0
	for w in wants:
		total += w[3]
	var roll := randf() * total
	for w in wants:
		roll -= w[3]
		if roll <= 0:
			var spec := {"kind": w[0], "want": w[1], "desc": w[2]}
			if w.size() > 4:
				spec["target"] = w[4]
			if w.size() > 5:
				spec["item_id"] = w[5]
			return spec
	return {}

static func ask_line(b: CBrain, spec: Dictionary, helper: Entity) -> String:
	var nm := Dialogue.call_name(b, helper)
	var d: String = spec["desc"]
	var opts := ["Hey %s, could you %s?" % [nm, d], "%s! Any chance you could %s?" % [nm, d], "Do me a favor, %s? %s." % [nm, Dialogue.cap(d)],
		"I hate to ask, but could you %s?" % d, "You look like you've got a minute. Could you %s?" % d]
	if b.tv("aggression") > 0.65:
		opts.append("%s. %s. Would you." % [nm, Dialogue.cap(d)])
	if b.voice_formal() > 0.65:
		opts.append("%s, if it's not too much trouble, would you %s?" % [nm, d])
	return Dialogue.pick(opts)
