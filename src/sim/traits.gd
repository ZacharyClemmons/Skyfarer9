class_name Traits extends RefCounted
## tg traits (code/__DEFINES/traits): named flags on a mob, each held by one or more
## sources (ADD_TRAIT(mob, TRAIT_X, source) / REMOVE_TRAIT). A trait is on while any source
## holds it. Genetics adds its mutation traits under the source "genetic"; species under
## "species"; mutations that need their own source use their id.
##
## Trait names are tg's without the TRAIT_ prefix, lower case: "deaf", "mute", "blind",
## "nearsight", "shockimmune", "resistcold", "resistheat", "resistlowpressure",
## "resisthighpressure", "no_slip_ice", "clumsy", "strength", "stimmed", "nosoftcrit",
## "nohardcrit", "analgesia", "illiterate", "night_vision", "xray_vision", "thermal_vision",
## "chunkyfingers", "hulk", "pushimmune", "stunimmune", "dwarf", "giant", "too_tall",
## "unintelligible_speech", "rock_eater", "no_twohanding", "force_whisper", "mind_reader",
## "web_weaver", "advancedtooluser", "literate", "lesser_humanoid", "simian", "primitive",
## "born_monkey", "no_dna_copy", "no_underwear", "no_blood_overlay", "no_transform",
## "can_strip", "gun_natural".

static func _store(e: Entity) -> Dictionary:
	if e == null:
		return {}
	var h = e.c(&"health")
	if h != null:
		return h.traits
	if not e.has_meta("traits"):
		e.set_meta("traits", {})
	return e.get_meta("traits")

static func add(e: Entity, tname: String, source: String) -> void:
	if e == null:
		return
	var t := _store(e)
	var was: bool = t.has(tname)
	if not was:
		t[tname] = {}
	t[tname][source] = true
	if not was:
		_changed(e, tname, true)

static func add_all(e: Entity, list: Array, source: String) -> void:
	for tr in list:
		add(e, tr, source)

static func remove(e: Entity, tname: String, source: String) -> void:
	if e == null:
		return
	var t := _store(e)
	if not t.has(tname):
		return
	t[tname].erase(source)
	if t[tname].is_empty():
		t.erase(tname)
		_changed(e, tname, false)

static func remove_all(e: Entity, list: Array, source: String) -> void:
	for tr in list:
		remove(e, tr, source)

## tg REMOVE_TRAITS_IN(mob, source)
static func remove_source(e: Entity, source: String) -> void:
	var t := _store(e)
	for tr in t.keys():
		remove(e, tr, source)

static func has(e: Entity, tname: String) -> bool:
	if e == null:
		return false
	var h = e.c(&"health")
	if h != null:
		return h.traits.has(tname)
	return e.has_meta("traits") and e.get_meta("traits").has(tname)

## For code that holds the body, not the entity.
static func h_has(h, tname: String) -> bool:
	return h != null and h.traits.has(tname)

## tg HAS_TRAIT_FROM
static func has_from(e: Entity, tname: String, source: String) -> bool:
	var t := _store(e)
	return t.has(tname) and t[tname].has(source)

## tg SIGNAL_ADDTRAIT / SIGNAL_REMOVETRAIT for the traits that change the body at once.
static func _changed(e: Entity, tname: String, on: bool) -> void:
	var m = e.c(&"mob")
	match tname:
		"xray_vision", "night_vision", "thermal_vision":
			if e == Game.player and Game.lighting:
				Game.lighting.fov_dirty = true
				Game.lighting.compose_t = 0.0
		"dwarf", "giant", "too_tall":
			if m:
				m.update_size()
		"nosoftcrit", "nohardcrit":
			var h = e.c(&"health")
			if h:
				h._check_state(h.stat())
