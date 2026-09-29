class_name CrewStories extends RefCounted
## The human side of the round-end report: who became friends, who fell out, who did
## favours, who got what they came for, the arcade champion, and what the crew ended up
## thinking of you.

static func lines() -> Array:
	var out := []
	var brains: Array = Game.all_with(&"brain")
	var seen_pairs := {}
	var friends := []
	var feuds := []
	for m in brains:
		var b: CBrain = m.c(&"brain")
		for id in b.memory.rels.keys():
			var other := Game.entities.get(id)
			if other == null or not is_instance_valid(other) or other == Game.player or not other.has_c(&"brain"):
				continue
			var key := "%d:%d" % [mini(m.id, id), maxi(m.id, id)]
			if seen_pairs.has(key):
				continue
			var a: float = b.memory.rels[id].affinity
			var back: float = other.c(&"brain").affinity(m.id)
			if a > 55.0 and back > 55.0:
				seen_pairs[key] = true
				friends.append([m.display_name.split(" ")[0], other.display_name.split(" ")[0], (a + back) * 0.5])
			elif a < -45.0 and back < -45.0:
				seen_pairs[key] = true
				feuds.append([m.display_name.split(" ")[0], other.display_name.split(" ")[0], (a + back) * 0.5])
	friends.sort_custom(func(x, y): return x[2] > y[2])
	feuds.sort_custom(func(x, y): return x[2] < y[2])
	if not friends.is_empty():
		out.append("[color=#6ae88a]Friends:[/color] %s" % ", ".join(friends.slice(0, 5).map(func(f): return "%s & %s" % [f[0], f[1]])))
	if not feuds.is_empty():
		out.append("[color=#ff8a6a]Couldn't stand each other:[/color] %s" % ", ".join(feuds.slice(0, 4).map(func(f): return "%s & %s" % [f[0], f[1]])))
	# ambitions
	var got := []
	for m in brains:
		var p: Persona = m.c(&"brain").persona
		for a in p.ambition_done:
			got.append("%s got to %s" % [m.display_name.split(" ")[0], p.ambition_text(a)])
	if not got.is_empty():
		out.append("[color=#e8c85a]Wishes granted:[/color] %s." % "; ".join(got.slice(0, 6)))
	# favours
	var done := Favors.list.filter(func(f): return f["state"] == "done")
	if not done.is_empty():
		var by := {}
		for f in done:
			var h = Game.entities.get(f["to"])
			if h and is_instance_valid(h):
				by[h.display_name] = by.get(h.display_name, 0) + 1
		var names := by.keys()
		names.sort_custom(func(x, y): return by[x] > by[y])
		out.append("[color=#9ab8d8]Favours done:[/color] %d (most by %s)." % [done.size(), names[0] if not names.is_empty() else "nobody"])
	if Routine.arcade_holder != 0:
		var ch = Game.entities.get(Routine.arcade_holder)
		if ch and is_instance_valid(ch):
			out.append("[color=#c88ae8]Arcade champion:[/color] %s, with %d." % [ch.display_name, Routine.arcade_record])
	# what they thought of the player
	var p := Game.player
	if p and is_instance_valid(p):
		var fans := []
		var foes := []
		var reps := {}
		for m in brains:
			var b2: CBrain = m.c(&"brain")
			if not b2.memory.has_rel(p.id):
				continue
			var a2: float = b2.affinity(p.id)
			if a2 > 35.0:
				fans.append(m.display_name.split(" ")[0])
			elif a2 < -30.0:
				foes.append(m.display_name.split(" ")[0])
			for nt in b2.learned.notable(p.id):
				if nt[1] > 0.2:
					reps[nt[0]] = reps.get(nt[0], 0) + 1
		var rk := reps.keys()
		rk.sort_custom(func(x, y): return reps[x] > reps[y])
		var words := rk.slice(0, 3).map(func(k): return Experience.rep_word(k, 1.0))
		var line := "[b]You:[/b] "
		if fans.is_empty() and foes.is_empty() and words.is_empty():
			line += "most of the crew barely noticed you."
		else:
			if not words.is_empty():
				line += "people thought you were %s. " % Persona._and_list(words)
			if not fans.is_empty():
				line += "Liked by %s. " % Persona._and_list(fans.slice(0, 5))
			if not foes.is_empty():
				line += "%s won't miss you." % Persona._and_list(foes.slice(0, 4))
		out.append(line.strip_edges())
	return out
