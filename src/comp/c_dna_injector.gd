class_name CDnaInjector extends Component
## tg /obj/item/dnainjector (code/game/objects/items/dna_injector.dm): a single use
## autoinjector. Instant on yourself; three seconds to stick someone else.
##
##   dna_injector        adds and removes set mutations (the premade ones)
##   dna_activator       the console's prints: activates a mutation already in their
##                       genes (a research activator used that way fills with data the
##                       console can turn into a chromosome); a mutator forces it in anyway
##   dna_injector_timed  lasts 60 seconds: a makeup injector (name, blood, looks) or the
##                       premade hulk / monkey ones

var add_mutations: Array = [] # Mutation (or ids for the premade injectors)
var remove_mutations: Array = [] # ids
var used := false
var duration := INF
var stored_dna := {} # makeup: UI / UE / UF / name / blood_type
var damage_coeff := 1.0
var force_mutate := false
var research := false
var filled := false
var crispr_charge := false
var kind := "injector" # injector, activator, timed

func key() -> StringName:
	return &"dnainjector"

func setup(p: Dictionary) -> CDnaInjector:
	kind = p.get("kind", kind)
	for mid in p.get("add", []):
		add_mutations.append(Mutation.make(mid))
	remove_mutations = p.get("remove", []).duplicate()
	if kind == "timed":
		duration = p.get("duration", 60.0)
	return self

func _update_icon() -> void:
	e.set_sprite("items", "dnainjector0" if used else "dnainjector")
	if used and not e.desc.ends_with("This one is used up."):
		e.desc += " This one is used up."

## tg dnainjector/inject (and the activator's override)
func inject(target: Entity, user: Entity) -> bool:
	if not Genetics.can_mutate(target):
		return false
	var th: CHealth = target.c(&"health")
	var d: CDna = target.c(&"dna")
	if kind == "activator":
		for m in add_mutations:
			if not d.activate_mutation(m):
				if force_mutate:
					d.add_mutation(m, Genetics.SRC_MUTATOR)
			elif research and (target == Game.player or target.has_c(&"brain")):
				filled = true # tg target.client: a mind that can be learned from
			if th.disease != null and th.disease.has_method("is_genetic") and th.disease.is_genetic():
				crispr_charge = true
		return true
	if th.dead:
		var they: String = target.c(&"mob").they() if target.has_c(&"mob") else "they"
		Game.tell(user, "You can't modify %s's DNA while %s %s dead." % [target.display_name, they, "are" if they == "they" else "is"])
		return false
	for mid in remove_mutations:
		d.remove_mutation(mid, Genetics.STANDARD_SOURCES)
	for m in add_mutations:
		var mid: String = m.id
		if d.mutation_in_sequence(mid):
			d.activate_mutation(m)
			if duration != INF:
				Genetics.after(duration, func(): if is_instance_valid(target) and target.has_c(&"dna"): target.c(&"dna").remove_mutation(mid, Genetics.SRC_ACTIVATED))
		else:
			d.add_mutation(m, Genetics.SRC_MUTATOR)
			if duration != INF:
				Genetics.after(duration, func(): if is_instance_valid(target) and target.has_c(&"dna"): target.c(&"dna").remove_mutation(mid, Genetics.SRC_MUTATOR))
	if not stored_dna.is_empty():
		d.start_temp_transform(stored_dna, 1e12 if duration == INF else duration)
	return true

## tg dnainjector/attack
func attack(user: Entity, target: Entity) -> void:
	if not Species.advanced_tool_user(user):
		Game.tell(user, "You don't have the dexterity to do this!", "warn")
		return
	if used:
		Game.tell(user, "This injector is used up!", "warn")
		return
	if target.has_c(&"monkeyai"):
		target.c(&"monkeyai").on_try_syringe(user)
	if target != user:
		Game.visible_message(target.cell, "[b]%s is trying to inject %s with %s![/b]" % [user.display_name, target.display_name, e.the()], "bad")
		DoAfter.start(user, target, 3.0, func(ok):
			if not ok or used or not is_instance_valid(e) or e.removed:
				return
			Game.visible_message(target.cell, "[b]%s injects %s with the syringe with %s![/b]" % [user.display_name, target.display_name, e.the()], "bad")
			_finish(user, target))
		return
	Game.tell(user, "You inject yourself with %s." % e.the())
	_finish(user, target)

func _finish(user: Entity, target: Entity) -> void:
	Sfx.play("syringe", target.cell, 0.5)
	if not inject(target, user):
		Game.tell(user, "It appears that %s does not have compatible DNA." % target.display_name)
		return
	used = true
	_update_icon()
	if user != target and not Genetics.is_monkey(target):
		Interact._crime_check(user, target, "assault")

func examine(_user: Entity, lines: Array) -> void:
	if used:
		lines.append("This one is used up.")
