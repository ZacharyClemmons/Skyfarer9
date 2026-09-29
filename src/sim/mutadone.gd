class_name Mutadone extends RefCounted
## tg /datum/reagent/medicine/mutadone (medicine_reagents.dm).

## on_mob_metabolize: the only thing that undoes monkeyism - unless they were born a
## monkey, in which case it makes them one again.
static func on_metabolize(h: CHealth) -> void:
	var e := h.e
	var d: CDna = e.c(&"dna")
	if d == null:
		return
	if Genetics.is_monkey(e):
		if not Traits.has(e, "born_monkey"):
			d.remove_mutation("race", Genetics.STANDARD_SOURCES)
	elif Traits.has(e, "born_monkey"):
		GeneFx.monkeyize(e)

## on_mob_life: no jitter; every activated and mutator mutation but the monkey gene goes;
## the DNA is no longer scrambled.
static func on_life(h: CHealth) -> void:
	h.remove_status("jitter")
	var d: CDna = h.e.c(&"dna")
	if d == null:
		return
	if not d.mutations.is_empty():
		var group := d.mutations.duplicate()
		var race := d.get_mutation("race")
		if race:
			group.erase(race)
		d.remove_mutation_group(group, Genetics.STANDARD_SOURCES)
	d.scrambled = false
