class_name Monkeys extends RefCounted
## tg monkeys: /mob/living/carbon/human/species/monkey (monkey.dm) and monkey cubes
## (food/monkeycube.dm). A monkey is a person with the monkey species, a primate brain,
## the monkey gene switched on, and tg's monkey AI.

const MONKEY_CAP := 64 # tg config MONKEYCAP
static var cube_monkeys: Array = [] # tg SSmobs.cubemonkeys

static func cube_count() -> int:
	cube_monkeys = cube_monkeys.filter(func(m): return is_instance_valid(m) and not m.removed)
	return cube_monkeys.size()

## tg /mob/living/carbon/human/species/monkey/Initialize (born a monkey)
static func spawn_monkey(cell: Vector2i, cubespawned := false, angry := false) -> Entity:
	var rng := Game.rng
	var e := Entity.new()
	e.proto = "monkey"
	var nm := "monkey (%d)" % rng.randi_range(1, 999) # tg /datum/language/monkey get_random_name
	e.display_name = nm
	e.cell = cell
	e.position = Entity.cell_to_pos(cell)
	e.z_index = 1
	Game.ents_node.add_child(e)
	var inv := CInventory.new()
	var health := CHealth.new()
	var needs := CNeeds.new()
	var mob := CMob.new()
	mob.real_name = nm
	mob.job = ""
	mob.appearance = Jobs.random_appearance(rng)
	mob.pronoun = ["they", "she", "he"][rng.randi() % 3]
	e.add(inv)
	e.add(health)
	e.add(needs)
	e.add(mob)
	e.add(CMood.new())
	var dna := CDna.new()
	dna.brain_kind = "primate" # tg /obj/item/organ/brain/primate
	e.add(dna)
	needs.nutrition = rng.randf_range(45, 80)
	needs.hydration = rng.randf_range(55, 90)
	needs.energy = rng.randf_range(60, 100)
	Game.register(e)
	Traits.add(e, "born_monkey", "innate")
	dna.initialize_dna()
	Species.set_species(e, "monkey")
	var ai := CMonkeyAI.new()
	ai.aggressive = angry
	e.add(ai)
	if cubespawned:
		cube_monkeys.append(e)
	mob.refresh_doll()
	return e

## tg monkeycube/Expand: water makes it a monkey (while under the cap)
static func expand_cube(cube: Entity) -> void:
	if cube.removed or cube.get_meta("expanding", false):
		return
	cube.set_meta("expanding", true)
	var c := cube.root_cell()
	if cube.holder != null:
		var h := cube.holder
		var inv: CInventory = h.c(&"inv")
		if inv and cube in inv.hands:
			inv.drop(cube, h.root_cell())
		else:
			Interact.detach(cube)
			Game.drop_to_map(cube, c)
			cube.place(c)
	var kind: String = cube.tags.get("spawns", "monkey")
	var spammer: Entity = Game.get_entity(cube.get_meta("last_toucher", 0))
	var made: Entity = null
	if kind == "monkey":
		if cube_count() < MONKEY_CAP:
			made = spawn_monkey(c, true)
		elif spammer:
			Game.tell(spammer, "Aether harmonics prevent the creation of more than %d monkeys on the ship at one time!" % MONKEY_CAP, "warn")
	elif Proto.has(kind):
		made = Proto.spawn(kind, c)
	if made:
		Game.visible_message(c, "%s expands!" % cube.the().capitalize())
		var m: CMob = made.c(&"mob")
		if m and m.doll:
			# tg: alpha 0 -> 255 and scale 0.1 -> 1 over 0.5 s
			m.doll.modulate.a = 0.0
			m.doll.scale = Vector2(0.1, 0.1)
			var tw := m.doll.create_tween().set_parallel(true)
			tw.tween_property(m.doll, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(m.doll, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif spammer == null:
		Game.visible_message(c, "%s fails to expand!" % cube.the().capitalize())
		cube.remove_meta("expanding")
		return
	cube.destroy()

## tg water/expose_obj: water on a monkey cube
static func expose_water(item: Entity) -> bool:
	if item and item.tags.has("monkeycube"):
		expand_cube(item)
		return true
	return false
