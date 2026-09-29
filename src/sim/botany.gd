class_name Botany extends RefCounted
## What happens to a plant once it leaves the tray: dressing harvested produce with its
## seed and chemicals, the traits that make a fruit slippery, luminous or full of liquid,
## and pulling seeds back out of produce.
##
## Ported from tgstation: code/modules/hydroponics/plant_genes.dm (traits on the grown
## item), grown.dm (the harvested food itself) and seed_extractor.dm (seedify).

## Which growth sprite family a species uses (the art only draws a handful of shapes).
const SPRITE_FAMILY := {
	"wheat": "wheat", "oat": "wheat", "corn": "wheat", "peppercorn": "wheat",
	"tomato": "tomato", "blood_tomato": "tomato", "chili": "chili", "ice_pepper": "chili",
	"potato": "potato", "sweet_potato": "potato", "carrot": "carrot", "onion": "carrot",
	"berry": "berry", "glow_berry": "berry", "poison_berry": "berry", "death_berry": "berry",
	"grape": "berry", "apple": "tree", "gold_apple": "tree", "banana": "tree",
	"cabbage": "leafy", "soya": "leafy", "butterbean": "leafy", "pumpkin": "vine", "blumpkin": "vine",
	"ambrosia": "ambrosia", "ambrosia_deus": "ambrosia",
	"plump": "mushroom", "chanterelle": "mushroom", "amanita": "mushroom", "angel": "mushroom",
	"reishi": "mushroom", "glowshroom": "glowshroom", "towercap": "mushroom",
	"starthistle": "thistle", "harebell": "flower", "nettle": "thistle",
}

static func sprite_family(species: String) -> String:
	return SPRITE_FAMILY.get(species, "wheat")

# ---------------------------------------------------------------- harvested produce
## tg prepare_result() plus the traits that live on the grown item: the fruit carries a
## copy of its seed, its potency-scaled chemicals and whatever its genes do.
static func dress_produce(fruit: Entity, seed: Dictionary) -> void:
	if not is_instance_valid(fruit) or seed.is_empty(): return
	fruit.set_meta("seed", seed)
	var chems := Plants.produce_reagents(seed)
	var f: CFood = fruit.c(&"food")
	if f != null:
		f.chems = chems
		# tg: potency drives how filling a fruit is (nutriment in the fruit)
		var nutri := float(chems.get("nutriment", 0.0)) + float(chems.get("vitamin", 0.0))
		if nutri > 0.0: f.nutrition = maxf(f.nutrition, nutri * 0.4)
	if Plants.has_gene(seed, "slip"):
		fruit.set_meta("slippery", true)
	if Plants.has_gene(seed, "glow"):
		fruit.set_meta("glowing", true)
		if fruit.c(&"light") == null:
			var l := CLight.new().setup({"kind": "item", "radius": 1.0 + float(seed.get("potency", 10)) / 30.0,
				"color": "#a8ffc8", "energy": 0.5, "on": true})
			fruit.add(l)
	var potency := int(seed.get("potency", 10))
	if potency >= 30 and fruit.c(&"item") != null:
		# tg: a big fruit hits harder
		var it: CItem = fruit.c(&"item")
		it.force = maxf(it.force, potency * 0.1)

## The seed a fruit grew from (its own, or its species' default).
static func seed_of(item: Entity) -> Dictionary:
	if not is_instance_valid(item): return {}
	var seed: Dictionary = item.get_meta("seed", {})
	if not seed.is_empty(): return seed
	for species in Plants.SPECIES:
		if Plants.SPECIES[species].get("produce", "") == item.proto:
			return Plants.new_seed(species)
	return {}

## tg /datum/plant_gene/trait/squash: the fruit bursts, spilling what's inside.
static func squash(fruit: Entity, cell: Vector2i, victim: Entity = null) -> bool:
	var seed := seed_of(fruit)
	if seed.is_empty() or not Plants.has_gene(seed, "squash"): return false
	var chems := Plants.produce_reagents(seed)
	Game.visible_message(cell, "%s bursts!" % fruit.the())
	if is_instance_valid(victim):
		Chem.touch_mob(chems, victim, 1.0)
	else:
		for ent in Game.at(cell):
			if ent.has_c(&"health"): Chem.touch_mob(chems, ent, 0.5)
	var puddle := Proto.spawn("decal_water", cell)
	if puddle:
		var d: CDecal = puddle.c(&"decal")
		if d: d.slippery = true
	Sfx.play("splash", cell, 0.6)
	fruit.destroy()
	return true

## Somebody trod on a slippery fruit (tg slip trait: it squashes if it can).
static func on_slipped_on(fruit: Entity, victim: Entity) -> void:
	squash(fruit, fruit.cell, victim)

## tg /datum/plant_gene/trait/stinging: the fruit injects its chemicals on a hit.
static func on_hit(fruit: Entity, target: Entity) -> void:
	var seed := seed_of(fruit)
	if seed.is_empty() or not is_instance_valid(target): return
	if Plants.has_gene(seed, "stinging") and target.has_c(&"health"):
		Chem.affect_mob(Plants.produce_reagents(seed), target, 1.0)
		Game.tell(target, "You feel a tiny prick.", "warn")
	squash(fruit, target.cell, target)

# ---------------------------------------------------------------- seeds
## Spawn a seed packet carrying `seed`.
static func make_packet(seed: Dictionary, cell: Vector2i) -> Entity:
	var packet := Proto.spawn("seed_packet", cell)
	var b: CBotany = packet.c(&"botany")
	if b: b.set_seed(seed)
	return packet

## tg seedify(): pull seeds out of produce. `multiplier` is the extractor's rating.
static func seedify(item: Entity, multiplier := 1, cell := Vector2i(-9999, -9999)) -> Array:
	var seed := seed_of(item)
	if seed.is_empty(): return []
	var where: Vector2i = cell if cell.x != -9999 else item.root_cell()
	var count := Game.rng.randi_range(1, 4) * maxi(1, multiplier)
	var out := []
	item.destroy()
	for i in count:
		out.append(make_packet(Plants.copy(seed), where))
	return out

## The plant analyzer readout (tg /obj/item/plant_analyzer).
static func analyze(seed: Dictionary, tray: CHydro = null) -> String:
	var text := ""
	if tray != null:
		text += tray.report() + "\n"
	if seed.is_empty(): return text + "No plant sample."
	return text + Plants.describe(seed)
