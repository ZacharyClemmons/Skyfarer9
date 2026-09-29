class_name Species extends RefCounted
## tg /datum/species (code/modules/mob/living/carbon/human/_species.dm, species_types/).
## Only what genetics needs so far: humans, monkeys (species_types/monkeys.dm) and the
## skeleton a DNA meltdown leaves. The rest of tg's species are the next port.
##
## A species brings inherent traits, the slots it can't wear anything in, the language it
## speaks, and (monkeys) the mutation that marks it. The brain is separate: a human brain
## (tg /obj/item/organ/brain) lets you use tools and read; a primate brain doesn't, and
## born monkeys keep theirs when they're humanized.

const DEFS := {
	"human": {"name": "Human", "traits": []},
	"corgi": {"name": "Corgi", "traits": ["animal_body", "geneless", "no_dna_copy"]},
	"crab": {"name": "Crab", "traits": ["animal_body", "geneless", "no_dna_copy", "nodrown"]},
	"gorilla": {"name": "Gorilla", "traits": ["animal_body", "geneless", "no_dna_copy"]},
	# tg /datum/species/monkey
	"monkey": {"name": "Monkey", "traits": ["no_blood_overlay", "no_dna_copy", "no_underwear", "lesser_humanoid", "simian"],
		"no_equip": ["suit", "gloves", "shoes", "suit_store"], "language": "monkey"},
	# tg /datum/species/skeleton (what's left after a meltdown melts the skin off)
	"skeleton": {"name": "Skeleton", "traits": ["resistcold", "resistheat", "resistlowpressure", "resisthighpressure", "nohunger", "nobreath", "geneless"]},
}

## tg brain organ_traits
const BRAIN_TRAITS := {
	"human": ["advancedtooluser", "literate", "can_strip"],
	"primate": ["can_strip", "primitive", "gun_natural"],
}

static func name_of(id: String) -> String:
	return DEFS.get(id, {}).get("name", id.capitalize())

static func of(e: Entity) -> String:
	var d: CDna = e.c(&"dna") if e else null
	return d.species if d else "human"

## tg carbon/set_species: the old species is lost, the new one gained.
static func set_species(e: Entity, id: String) -> void:
	var d: CDna = e.c(&"dna")
	if d == null or not DEFS.has(id):
		return
	var old := d.species
	d.species = id
	on_species_loss(e, old, id)
	on_species_gain(e, id, old)
	# TG COMSIG_SPECIES_GAIN: restricted mutations lose all their sources when
	# the new species (or their can_acquire override) no longer permits them.
	for mutation in d.mutations.duplicate():
		var allowed: Array = mutation.def().get("species", [])
		if not allowed.is_empty() and (not id in allowed or not GeneFx.can_acquire(e, mutation)):
			d.remove_mutation(mutation, mutation.sources.duplicate())
	var m: CMob = e.c(&"mob")
	if m:
		m.species_name = id
		m.refresh_doll()
		m.update_size()

static func on_species_loss(e: Entity, id: String, _new_id: String) -> void:
	Traits.remove_source(e, "species")
	var d: CDna = e.c(&"dna")
	if id == "monkey" and d:
		d.remove_mutation("race", Genetics.SRC_ACTIVATED)

static func on_species_gain(e: Entity, id: String, _old: String) -> void:
	var def: Dictionary = DEFS[id]
	Traits.add_all(e, def.get("traits", []), "species")
	# tg no_equip_flags: whatever's in a slot it can't use falls off
	var inv: CInventory = e.c(&"inv")
	if inv:
		for s in def.get("no_equip", []):
			var it: Entity = inv.worn(s)
			if it:
				inv.drop(it)
	var d: CDna = e.c(&"dna")
	if id == "monkey" and d:
		d.add_mutation("race", Genetics.SRC_ACTIVATED)
	apply_brain(e)

## The brain's traits (tg organ_traits of the brain in the head).
static func apply_brain(e: Entity) -> void:
	var d: CDna = e.c(&"dna")
	Traits.remove_source(e, "brain")
	if d == null:
		return
	Traits.add_all(e, BRAIN_TRAITS.get(d.brain_kind, []), "brain")

## tg ISADVANCEDTOOLUSER
static func advanced_tool_user(e: Entity) -> bool:
	return e != null and (not e.has_c(&"dna") or Traits.has(e, "advancedtooluser"))

## tg species_language_holder: the language this body can speak ("" = common)
static func language(e: Entity) -> String:
	if Genetics.is_monkey(e):
		return "monkey"
	return ""

## tg scramble_paragraph / scramble_sentence / scramble_word
const LANGS := {
	"monkey": {"syllables": ["oop", "aak", "chee", "eek"], "space": 0.0, "sentence": 0.0, "bw_sentence": 10.0, "bw_space": 75.0, "lo": 0, "hi": 0},
	"beachbum": {"syllables": ["cowabunga", "rad", "radical", "dudes", "bogus", "weeed", "every", "dee", "dah", "woah", "surf", "blazed", "high", "heinous", "day",
		"brah", "bro", "blown", "catch", "body", "beach", "oooo", "twenty", "shiz", "phiz", "wizz", "pop", "chill", "awesome", "dude", "it",
		"wax", "stoked", "yes", "ding", "way", "no", "wicked", "aaaa", "cool", "hoo", "wah", "wee", "man", "maaaaaan", "mate", "wick",
		"oh", "ocean", "up", "out", "rip", "slide", "big", "stomp", "weed", "pot", "smoke", "four-twenty", "shove", "wacky", "hah",
		"sick", "slash", "spit", "stoked", "shallow", "gun", "party", "heavy", "stellar", "excellent", "triumphant", "babe", "four",
		"tail", "trim", "tube", "wobble", "roll", "gnarly", "epic"], "space": 80.0, "sentence": 5.0, "bw_sentence": 0.0, "bw_space": 100.0, "lo": -2, "hi": -1,
		"mutual": 50.0}, # tg mutual_understanding: common speakers catch about half of it
}

static func scramble(lang: String, input: String) -> String:
	var L: Dictionary = LANGS[lang]
	var out := []
	var re := RegEx.create_from_string("(.+?(?:[\\.!\\?]|$))")
	for m in re.search_all(input):
		var s := m.get_string(1).strip_edges()
		if s != "":
			out.append(_scramble_sentence(L, s))
	return " ".join(out)

static func _scramble_sentence(L: Dictionary, input: String) -> String:
	var words := []
	var translated := []
	for w in input.split(" "):
		var base := w.strip_edges().lstrip(".,!?;:'\"").rstrip(".,!?;:'\"")
		if L.get("mutual", 0.0) > 0.0 and Genetics.prob(L["mutual"]):
			words.append(w)
			translated.append(false)
			continue
		var sw := _scramble_word(L, base)
		words.append(sw)
		translated.append(sw != base)
	if words.is_empty():
		return ""
	var sentence: String = str(words[0]).capitalize().substr(0, 1) + str(words[0]).substr(1)
	for i in range(1, words.size()):
		var word: String = words[i]
		if not translated[i]:
			sentence += " " + word
			continue
		if translated[i - 1] or Genetics.prob(L["bw_space"]):
			sentence += " "
		elif Genetics.prob(L["bw_sentence"]):
			sentence += ". "
			word = word.substr(0, 1).to_upper() + word.substr(1)
		sentence += word
	if translated[words.size() - 1]:
		var last := input.substr(input.length() - 1)
		if last in [".", "!", "?"]:
			sentence += last
	return sentence

static func _scramble_word(L: Dictionary, input: String) -> String:
	var size := maxi(input.length() + Game.rng.randi_range(L["lo"], L["hi"]), 1)
	var word := ""
	var add_period := false
	var add_space := false
	while word.length() < size:
		if add_period:
			word += ". "
		elif add_space:
			word += " "
		var nxt: String = Genetics.rand_pick(L["syllables"])
		word += (nxt.substr(0, 1).to_upper() + nxt.substr(1)) if add_period else nxt
		add_period = Genetics.prob(L["sentence"])
		add_space = Genetics.prob(L["space"])
	if input.length() >= 2 and input == input.to_upper() and input != input.to_lower():
		return word.to_upper()
	return word

## the stoner mutation's Beachtongue
static func beachbum(text: String) -> String:
	return scramble("beachbum", text)
