class_name CHydro extends Component
## Hydroponics trays, ported from tgstation (code/modules/hydroponics/hydroponics.dm,
## hydroponics_chemreact.dm and __DEFINES/botany.dm). Every 20 seconds the tray runs
## tg's growth cycle: it ages the plant, drinks a unit of nutrient, drinks water, takes
## light, works out toxins, pests and weeds, pollinates its neighbours, rolls mutations
## and finally decides whether there's a harvest.
##
## The seed itself (stats, traits, chemicals) is a dictionary owned by `Plants`.

const CYCLE_DELAY := 20.0 # tg HYDROTRAY_CYCLE_DELAY
const MAX_WATER := 100.0
const MAX_NUTRI := 20.0 # tg maxnutri
const NUTRIDRAIN := 1.0 # tg nutridrain, one unit a cycle
const MAX_TOXIC := 100.0
const MAX_PESTS := 10.0
const MAX_WEEDS := 10.0
const LIGHT_NEEDED := 0.4 # tg check_lumcount_below(0.4), 0.2 for mushrooms

# plant_status (tg HYDROTRAY_* defines)
const NO_PLANT := "missing"
const DEAD := "dead"
const GROWING := "growing"
const HARVESTABLE := "harvestable"

var seed: Dictionary = {} # Plants seed; empty = nothing planted
var status := NO_PLANT
var plant_health := 0.0
var water := 0.0
var toxic := 0.0
var pests := 0.0
var weeds := 0.0
var yieldmod := 1.0
var mutmod := 1.0
var age := 0
var lastproduce := 0
var self_sustaining := false
var rating := 1 # tg parts rating: better parts mean slower losses
var soil := false # tg tray_flags & SOIL
var nutrients: Dictionary = {} # the tray's own reagent holder (tg reagents, 20 u)
var preplanted := true
var cycle_t := 0.0
var overlay: Sprite2D

func key() -> StringName:
	return &"hydro"

func setup(p: Dictionary) -> CHydro:
	preplanted = p.get("preplanted", true)
	water = clampf(p.get("water", 50.0), 0.0, MAX_WATER)
	soil = p.get("soil", soil)
	rating = p.get("rating", rating)
	if p.has("nutrients"):
		add_nutrient("eznutriment", float(p["nutrients"]) * MAX_NUTRI / 100.0)
	else:
		add_nutrient("eznutriment", 10.0)
	return self

func on_added() -> void:
	overlay = Sprite2D.new()
	overlay.offset = Vector2(0, -24)
	overlay.region_enabled = true
	overlay.texture = Gfx.tex("objects")
	e.add_child(overlay)
	if preplanted:
		var pick: String = Plants.STARTER_SEEDS[Game.rng.randi() % 6] # a food crop
		plant(Plants.new_seed(pick))
	_refresh()

# ---------------------------------------------------------------- nutrient holder
func nutrient_total() -> float:
	var t := 0.0
	for k in nutrients: t += nutrients[k]
	return t

func add_nutrient(reagent: String, units: float) -> float:
	units = minf(units, maxf(0.0, MAX_NUTRI - nutrient_total()))
	if units <= 0.0: return 0.0
	nutrients[reagent] = nutrients.get(reagent, 0.0) + units
	return units

func drain_nutrients(units: float) -> void:
	var total := nutrient_total()
	if total <= 0.0: return
	var frac := minf(1.0, units / total)
	for k in nutrients.keys():
		nutrients[k] -= nutrients[k] * frac
		if nutrients[k] < 0.01: nutrients.erase(k)

# ---------------------------------------------------------------- tg setters
func set_water(v: float) -> void:
	water = clampf(v, 0.0, MAX_WATER)

func adjust_water(amount: float) -> float:
	var before := water
	set_water(water + amount)
	return water - before

func adjust_health(amount: float) -> void:
	if seed.is_empty(): return
	plant_health = clampf(plant_health + amount, 0.0, float(seed.get("endurance", 15)))

func adjust_toxic(amount: float) -> void:
	toxic = clampf(toxic + amount, 0.0, MAX_TOXIC)

func adjust_pests(amount: float) -> void:
	pests = clampf(pests + amount, 0.0, MAX_PESTS)

func adjust_weeds(amount: float) -> void:
	# tg: semiaquatic plants in dry soil grow half again as many weeds
	var mod := 1.5 if (amount > 0.0 and not soil and Plants.has_gene(seed, "semiaquatic")) else 1.0
	weeds = clampf(weeds + amount * mod, 0.0, MAX_WEEDS)

func plant(new_seed: Dictionary) -> void:
	seed = new_seed
	status = GROWING
	plant_health = float(seed.get("endurance", 15))
	age = 0
	lastproduce = 0
	cycle_t = 0.0
	_refresh()

func clear_plant() -> void:
	seed = {}
	status = NO_PLANT
	plant_health = 0.0
	age = 0
	lastproduce = 0
	if self_sustaining: self_sustaining = false
	_refresh()

## tg plantdies(): the plant is gone, and so are its pests.
func plant_dies() -> void:
	plant_health = 0.0
	status = DEAD
	pests = 0.0
	lastproduce = 0
	_refresh()

func ready() -> bool:
	return status == HARVESTABLE

func dead() -> bool:
	return status == DEAD

func needs_care() -> bool:
	return seed.is_empty() or dead() or ready() or water < 25.0 or nutrient_total() <= 1.0 or weeds >= 5.0 or pests >= 5.0 or toxic >= 40.0

# ---------------------------------------------------------------- the growth cycle
func tick(dt: float) -> void:
	# tg self-sustaining (autogrow) runs on the machine's own tick, not the growth cycle
	if self_sustaining:
		var m: CMachine = e.c(&"machine")
		if m == null or m.operable():
			adjust_water(Game.rng.randi_range(1, 2) * dt * 0.5)
			adjust_weeds(-0.5 * dt)
			adjust_pests(-0.5 * dt)
		else:
			self_sustaining = false
			Game.visible_message(e.cell, "%s's auto-grow functionality shuts off!" % e.the())
	cycle_t += dt
	if cycle_t < CYCLE_DELAY: return
	cycle_t = 0.0
	_cycle()

func _cycle() -> void:
	var rng := Game.rng
	if not seed.is_empty() and status != DEAD:
		var fungal := Plants.has_gene(seed, "fungal_metabolism")
		age += 1
		if age < int(seed.get("maturation", 6)): lastproduce = age
		# --- nutrients
		_apply_chemicals()
		drain_nutrients(minf(0.5, NUTRIDRAIN) if self_sustaining else NUTRIDRAIN)
		if nutrient_total() <= 0.0 and not Plants.has_gene(seed, "weed_hardy"):
			adjust_health(-rng.randi_range(1, 3))
		# --- light
		var lum: float = Game.lighting.light_at(e.cell) if Game.lighting else 1.0
		if lum < (0.2 if fungal else LIGHT_NEEDED):
			adjust_health((-1.0 if fungal else -2.0) / rating)
		# --- water
		adjust_water(-rng.randi_range(1, 6) / float(rating))
		if water <= 10.0 and not fungal:
			adjust_health(-rng.randi_range(0, 1) / float(rating))
			if water <= 0.0:
				adjust_health(-rng.randi_range(0, 2) / float(rating))
		elif water > 10.0 and nutrient_total() > 0.0:
			adjust_health(rng.randi_range(1, 2) / float(rating))
			if rng.randi_range(1, 100) <= int(seed.get("weed_chance", 5)):
				adjust_weeds(float(seed.get("weed_rate", 1)))
			elif rng.randf() < 0.05:
				adjust_weeds(1.0 / rating)
		# --- toxins
		if toxic >= 10.0:
			if Plants.has_gene(seed, "toxin_adaptation"):
				adjust_health(round(toxic / rng.randi_range(10, 16)))
				Plants.adjust(seed, "potency", round(toxic / rng.randi_range(20, 30)))
			elif toxic >= 40.0 and not Plants.has_gene(seed, "tox_resistance"):
				if toxic < 80.0:
					adjust_health(-1.0 / rating)
					adjust_toxic(-rating * 2.0)
				else:
					adjust_health(-3.0)
					adjust_toxic(-rating * 3.0)
		# --- pests
		var carnivore := Plants.has_gene(seed, "carnivory")
		if pests >= 8.0:
			if not carnivore:
				if int(seed.get("potency", 0)) >= 30:
					Plants.set_stat(seed, "potency", maxf(Plants.CARNIVORY_POTENCY_MIN, float(seed["potency"]) - rng.randi_range(2, 6)))
			else:
				adjust_health(2.0 / rating)
				adjust_pests(-1.0 / rating)
		elif pests >= 4.0:
			if not carnivore:
				if int(seed.get("potency", 0)) >= 30:
					Plants.set_stat(seed, "potency", maxf(Plants.CARNIVORY_POTENCY_MIN, float(seed["potency"]) - rng.randi_range(1, 4)))
			else:
				adjust_health(1.0 / rating)
				if rng.randf() < 0.5: adjust_pests(-1.0 / rating)
		elif carnivore and rng.randf() < 0.05:
			adjust_pests(-1.0 / rating)
		# --- weeds choke the fruit
		if weeds >= 5.0 and not Plants.has_gene(seed, "weed_hardy"):
			if int(seed.get("yield", 0)) >= 3:
				Plants.adjust(seed, "yield", -rng.randi_range(1, 2))
				Plants.set_stat(seed, "yield", maxf(Plants.WEED_HARDY_YIELD_MIN, float(seed["yield"])))
		pollinate()
		_mutation_rolls()
		# --- health and age
		if plant_health <= 0.0:
			plant_dies()
			adjust_weeds(1.0 / rating)
		if age > int(seed.get("lifespan", 25)):
			adjust_health(-rng.randi_range(1, 5) / float(rating))
		# --- harvest
		var production := int(seed.get("production", 6))
		if age > production and (age - lastproduce) > production and status == GROWING:
			if int(seed.get("yield", 0)) != -1:
				status = HARVESTABLE
			else:
				lastproduce = age
		if rng.randf() < 0.05:
			adjust_pests(1.0 / rating)
	else:
		if water > 10.0 and nutrient_total() > 0.0 and Game.rng.randf() < 0.1:
			adjust_weeds(1.0 / rating)
	# --- the weeds take over
	if weeds >= MAX_WEEDS and Game.rng.randf() < 0.5 and not self_sustaining:
		if not seed.is_empty() and int(seed.get("yield", 0)) >= 3:
			Plants.adjust(seed, "yield", -Game.rng.randi_range(1, 2))
			Plants.set_stat(seed, "yield", maxf(Plants.WEED_HARDY_YIELD_MIN, float(seed["yield"])))
		if seed.is_empty():
			weed_invasion()
	if Plants.has_gene(seed, "invasive"):
		_spread()
	_refresh()

## tg's instability rolls: traits first, then the species, then the stats.
func _mutation_rolls() -> void:
	var rng := Game.rng
	var instability := float(seed.get("instability", 5))
	if instability >= 80.0:
		Plants.mutate(seed, 0, 0, 0, 0, 0, 0, 0, int(instability - 75.0), 0)
	if instability >= 60.0:
		if rng.randi_range(1, 100) <= int(instability / 2.0) and not self_sustaining \
				and not Plants.mutations_of(seed).is_empty() and not Plants.has_gene(seed, "never_mutate"):
			mutate_species()
			Plants.set_stat(seed, "instability", instability / 2.0)
			return
	if instability >= 20.0 and rng.randi_range(1, 100) <= int(instability) and not Plants.has_gene(seed, "stable_stats"):
		if instability >= 40.0:
			hard_mutate(5 if instability >= 80.0 else 0)
		else:
			Plants.mutate(seed, 2, 5, 1, 2, 25, 2, 5, 0, 0)

## tg mutate()/hardmutate() with the tray's mutation modifier.
func mutate_stats() -> void:
	Plants.mutate(seed)

func hard_mutate(stabmut := 4) -> void:
	Plants.mutate(seed, 4, 10, 2, 4, 50, 4, 10, 0, stabmut)

## tg mutatespecie(): the plant turns into one of the species on its mutate list.
func mutate_species() -> void:
	if seed.is_empty() or status == DEAD: return
	var options := Plants.mutations_of(seed)
	if options.is_empty(): return
	var old_name: String = seed.get("name", "plant")
	var next: String = options[Game.rng.randi() % options.size()]
	var carried: Array = (seed.get("genes", []) as Array).duplicate()
	seed = Plants.new_seed(next)
	for g in carried:
		if Plants.GENES.get(g, {}).get("graft", false): Plants.add_gene(seed, g)
	hard_mutate()
	plant_health = float(seed.get("endurance", 15))
	weeds = 0.0
	status = GROWING
	age = 0
	lastproduce = 0
	Game.visible_message(e.cell, "%s suddenly mutates into %s!" % [old_name, seed.get("name", "something")])
	_refresh()

## tg weedinvasion(): an untended tray is taken over by whatever weed blows in.
func weed_invasion() -> void:
	var old_name: String = seed.get("name", "empty tray") if not seed.is_empty() else "empty tray"
	var species: String = Plants.WEED_INVASION[Game.rng.randi() % Plants.WEED_INVASION.size()]
	seed = Plants.new_seed(species)
	status = GROWING
	age = 0
	lastproduce = 0
	plant_health = float(seed.get("endurance", 15))
	weeds = 0.0
	pests = 0.0
	Game.visible_message(e.cell, "The %s is overtaken by some %s!" % [old_name, seed.get("name", "weeds")])
	_refresh()

## tg pollinate(): neighbouring trays trade potency, instability and yield.
func pollinate(range_tiles := 1) -> void:
	if seed.is_empty(): return
	for other in Game.all_with(&"hydro"):
		if other == e or not is_instance_valid(other): continue
		var c: Vector2i = other.cell - e.cell
		if absi(c.x) > range_tiles or absi(c.y) > range_tiles: continue
		var t: CHydro = other.c(&"hydro")
		if t == null or t.seed.is_empty() or t.status == DEAD: continue
		Plants.set_stat(t.seed, "potency", round(float(t.seed["potency"]) + 0.1 * (float(seed["potency"]) - float(t.seed["potency"]))))
		if not Plants.has_gene(t.seed, "safe_instability"):
			Plants.set_stat(t.seed, "instability", round(float(t.seed["instability"]) + 0.1 * (float(seed["instability"]) - float(t.seed["instability"]))))
		Plants.set_stat(t.seed, "yield", round(float(t.seed["yield"]) + 0.5 * (float(seed["yield"]) - float(t.seed["yield"]))))
		# tg: an unstable plant donates one of its reagents to the neighbour
		if float(seed.get("instability", 0)) >= 20.0 and Game.rng.randf() < 0.7:
			var mine := Plants.reagents_of(seed)
			if not mine.is_empty():
				var pick: String = mine.keys()[Game.rng.randi() % mine.size()]
				var extra: Dictionary = (t.seed.get("extra_reagents", {}) as Dictionary).duplicate()
				extra[pick] = maxf(extra.get(pick, 0.0), float(mine[pick]) * 0.5)
				t.seed["extra_reagents"] = extra

## tg invasive spreading: the plant jumps into any empty tray next to it.
func _spread() -> void:
	for other in Game.all_with(&"hydro"):
		if other == e or not is_instance_valid(other): continue
		var d: Vector2i = other.cell - e.cell
		if absi(d.x) > 1 or absi(d.y) > 1: continue
		var t: CHydro = other.c(&"hydro")
		if t == null: continue
		if t.seed.is_empty():
			t.plant(Plants.copy(seed))
			Game.visible_message(other.cell, "%s spreads into %s!" % [seed.get("name", "The plant"), other.the()])
			return
		elif t.status != DEAD and Game.rng.randf() < 0.1:
			t.adjust_health(-10.0)
			return

# ---------------------------------------------------------------- tray chemistry
## tg apply_chemicals(): each reagent in the tray's holder does its own thing to the
## tray and the seed (on_hydroponics_apply in the reagent files).
func _apply_chemicals() -> void:
	var rng := Game.rng
	for r in nutrients.keys():
		var v: float = nutrients[r]
		match r:
			"water":
				adjust_water(round(v))
			"eznutriment":
				if not seed.is_empty():
					Plants.adjust(seed, "instability", 0.2)
					Plants.adjust(seed, "potency", round(v * 0.3))
					Plants.adjust(seed, "yield", round(v * 0.1))
			"left4zednutriment":
				adjust_health(round(v * 0.1))
				Plants.adjust(seed, "instability", round(v * 0.2))
			"robustharvestnutriment":
				if not seed.is_empty():
					Plants.adjust(seed, "instability", -0.25)
					Plants.adjust(seed, "potency", round(v * 0.1))
					Plants.adjust(seed, "yield", round(v * 0.2))
			"endurogrow":
				if not seed.is_empty():
					Plants.adjust(seed, "potency", -round(v * 0.1))
					Plants.adjust(seed, "yield", -round(v * 0.075))
					Plants.adjust(seed, "endurance", round(v * 0.35))
			"saltpetre":
				adjust_health(round(v * 0.18))
				if not seed.is_empty():
					Plants.adjust(seed, "production", -round(v / 10.0))
					Plants.adjust(seed, "potency", round(v))
			"ammonia":
				adjust_health(round(v * 0.12))
				if not seed.is_empty() and v >= 5.0: Plants.adjust(seed, "instability", 1)
			"diethylamine":
				adjust_health(round(v))
				adjust_pests(-rng.randi_range(1, 2))
				if not seed.is_empty():
					Plants.adjust(seed, "yield", round(v))
					Plants.adjust(seed, "instability", -round(v))
			"nutriment", "vitamin":
				adjust_health(round(v * 0.2))
			"sugar":
				adjust_weeds(rng.randi_range(1, 2))
				adjust_pests(rng.randi_range(1, 2))
			"virus_food":
				adjust_health(-round(v * 0.5))
			"honey":
				if not seed.is_empty() and rng.randf() < 0.2: pollinate()
			"milk":
				adjust_water(round(v * 0.3))
				if not seed.is_empty() and not Plants.has_gene(seed, "fungal_metabolism"):
					Plants.adjust(seed, "potency", -round(v * 0.5))
			"sodawater":
				adjust_water(round(v))
				adjust_health(round(v * 0.1))
			"blood":
				adjust_pests(rng.randi_range(2, 3))
			"ash":
				adjust_health(round(v))
				adjust_weeds(-1.0)
			"mutagen":
				radioactive_exposure(v * 0.1)
				Plants.adjust(seed, "instability", round(v * 0.2))
			"uranium", "radium":
				radioactive_exposure(v * 0.1)
				Plants.adjust(seed, "instability", round(v * 0.1))
				adjust_toxic(round(0.5 * v))
			"plantbgone":
				adjust_health(-round(v * 10.0))
				adjust_toxic(round(v * 6.0))
				adjust_weeds(-rng.randi_range(4, 8))
			"weedkiller":
				adjust_toxic(round(v * 0.5))
				adjust_weeds(-rng.randi_range(1, 2))
			"pestkiller":
				adjust_toxic(round(v))
				adjust_pests(-rng.randi_range(1, 2))
			"chlorine":
				adjust_health(-round(v))
				adjust_toxic(round(v * 1.5))
				adjust_water(-round(v * 0.5))
				adjust_weeds(-rng.randi_range(1, 3))
			"fluorine":
				adjust_health(-round(v * 2.0))
				adjust_toxic(round(v * 2.5))
				adjust_water(-round(v * 0.5))
				adjust_weeds(-rng.randi_range(1, 4))
			"phosphorus":
				adjust_health(-round(v * 0.75))
				adjust_water(-round(v * 0.5))
				adjust_weeds(-rng.randi_range(1, 2))
			"acid":
				adjust_health(-round(v))
				adjust_toxic(round(v * 1.5))
				adjust_weeds(-rng.randi_range(1, 2))
			"cryoxadone":
				adjust_health(round(v * 3.0))
			_:
				# tg /datum/reagent/toxin: anything else poisonous just poisons the tray
				if Chem.REAGENTS.get(r, {}).get("heal", {}).get("tox", 0.0) < 0.0:
					adjust_toxic(round(v * 2.0))
	if nutrients.has("water"):
		nutrients.erase("water") # water goes to the tray's water level, not its nutrients

## tg radioactive_exposure(): mutagen and radioactives destabilise and mutate.
func radioactive_exposure(modifier := 1.0) -> void:
	if seed.is_empty():
		if Game.rng.randf() < 0.5 * modifier: adjust_weeds(maxf(1.0, round(modifier)))
		return
	Plants.adjust(seed, "instability", round(2.0 * modifier))
	adjust_toxic(round(1.5 * modifier))
	if Game.rng.randf() < 0.1 * modifier:
		adjust_health(round(-5.0 * modifier))
	if Game.rng.randf() < 0.15 * modifier:
		mutate_species()
	elif Game.rng.randf() < 0.1 * modifier:
		hard_mutate()

# ---------------------------------------------------------------- harvest
## tg /obj/item/seeds/harvest(): yield fruits, each carrying a copy of the seed.
func harvest(user: Entity) -> int:
	if not ready() or seed.is_empty(): return 0
	var count := Plants.yield_of(seed, yieldmod, soil)
	var produce_id: String = Plants.SPECIES.get(seed["species"], {}).get("produce", "")
	var made := 0
	var wild_mutation := ""
	for i in count:
		var fruit_seed := Plants.copy(seed)
		var id := produce_id
		# tg early wild mutation: an unstable plant sometimes fruits as its mutation
		var instability := float(seed.get("instability", 0))
		if instability >= 30.0 and not Plants.mutations_of(seed).is_empty() and Game.rng.randi_range(1, 100) <= int(instability / 3.0):
			var options := Plants.mutations_of(seed)
			var next: String = options[Game.rng.randi() % options.size()]
			fruit_seed = Plants.new_seed(next)
			Plants.set_stat(fruit_seed, "instability", round(instability * 0.5))
			id = Plants.SPECIES.get(next, {}).get("produce", produce_id)
			wild_mutation = fruit_seed.get("name", "")
		elif not soil and Plants.has_gene(seed, "soil_lover"):
			Plants.set_stat(fruit_seed, "potency", round(float(seed["potency"]) * Game.rng.randf_range(
				Plants.SOIL_LOVER_HYDRO_POTENCY_MIN, Plants.SOIL_LOVER_HYDRO_POTENCY_MAX)))
		if id == "" or not Proto.P.has(id): continue
		var fruit := Proto.spawn(id, e.cell)
		Botany.dress_produce(fruit, fruit_seed)
		made += 1
	if is_instance_valid(user):
		if made <= 0:
			Game.tell(user, "You fail to harvest anything useful!", "warn")
		else:
			Game.tell(user, "You harvest %d items from the %s." % [made, seed.get("name", "plant")])
			if wild_mutation != "":
				Game.tell(user, "Some of the fruit came out as %s!" % wild_mutation)
		Skills.add_xp(user, "botany", 6.0 * maxi(1, made))
	# tg update_tray()
	lastproduce = age
	if Plants.has_gene(seed, "repeated_harvest"):
		status = GROWING
	else:
		clear_plant()
	_refresh()
	return made

# ---------------------------------------------------------------- interaction
func _can_work(user: Entity) -> bool:
	return is_instance_valid(user) and user.adjacent(e) and user.c(&"health") != null and user.c(&"health").can_use_hands()

func attack_hand(user: Entity) -> bool:
	if not _can_work(user): return true
	if ready():
		harvest(user)
	elif dead():
		Game.tell(user, "You remove the dead plant from %s." % e.the())
		clear_plant()
	else:
		Game.tell(user, report())
	return true

func attackby(user: Entity, item: Entity) -> bool:
	if not _can_work(user): return true
	var bot: CBotany = item.c(&"botany")
	if bot != null:
		return bot.use_on_tray(user, self)
	# tg: anything that holds reagents waters and feeds the tray
	var r: CReagents = item.c(&"reagents")
	if r != null and r.is_open():
		return pour(user, item)
	# composting food (tg IS_EDIBLE: it goes into the tray's nutrients)
	var f: CFood = item.c(&"food")
	if f != null:
		var units := maxf(1.0, f.nutrition * 0.5)
		add_nutrient("nutriment", units)
		for k in f.chems: add_nutrient(k, f.chems[k])
		Game.visible_message(e.cell, "%s composts %s, spreading it through %s." % [user.display_name, item.the(), e.the()])
		item.destroy()
		_refresh()
		return true
	return false

func pour(user: Entity, item: Entity) -> bool:
	var r: CReagents = item.c(&"reagents")
	if r == null or not r.is_open(): return false
	if r.total() <= 0.0:
		Game.tell(user, "%s is empty!" % item.the(), "warn")
		return true
	if nutrient_total() >= MAX_NUTRI and not r.contents.has("water"):
		Game.tell(user, "%s is full." % e.the())
		return true
	var mix := r.take(r.transfer)
	var watered := 0.0
	for k in mix:
		if k == "water":
			watered = adjust_water(round(mix[k]))
		else:
			add_nutrient(k, mix[k])
	Sfx.play("pour", e.cell, 0.5)
	Game.tell(user, "You water %s. Water: %d/%d, nutrients: %.1f/%d." % [e.the(), int(water), int(MAX_WATER), nutrient_total(), int(MAX_NUTRI)])
	Skills.add_xp(user, "botany", 2.0)
	_refresh()
	return true

func toggle_autogrow(user: Entity) -> void:
	var m: CMachine = e.c(&"machine")
	if m and not m.operable():
		Game.tell(user, "%s has no power." % e.the(), "warn")
		return
	self_sustaining = not self_sustaining
	Game.tell(user, "You %s %s's autogrow function." % ["activate" if self_sustaining else "deactivate", e.the()])

func report() -> String:
	var text := "Water: %d/%d. Nutrients: %.1f/%d. Weeds: %.1f/10. Pests: %.1f/10. Toxins: %d/100." % [
		int(water), int(MAX_WATER), nutrient_total(), int(MAX_NUTRI), weeds, pests, int(toxic)]
	if seed.is_empty(): return "Empty tray. " + text
	var state := "dead" if dead() else ("ready to harvest" if ready() else "growing")
	return "%s (%s). Health %.0f/%d, age %d/%d. %s" % [seed.get("name", "?"), state, plant_health,
		int(seed.get("endurance", 15)), age, int(seed.get("lifespan", 25)), text]

func examine(_user: Entity, lines: Array) -> void:
	lines.append(report())
	if weeds >= 5.0: lines.append("[color=#e8a83a]It's filled with weeds![/color]")
	if pests >= 5.0: lines.append("[color=#e8a83a]It's filled with tiny worms![/color]")
	if self_sustaining: lines.append("Its autogrow is on.")

func verbs(user: Entity, out: Array) -> void:
	if ready(): out.append({"name": "Harvest", "cb": attack_hand.bind(user), "priority": 6})
	elif dead(): out.append({"name": "Remove dead plant", "cb": attack_hand.bind(user), "priority": 6})
	out.append({"name": "Autogrow: %s" % ("on" if self_sustaining else "off"), "cb": toggle_autogrow.bind(user), "priority": 3})
	if nutrient_total() > 0.0:
		out.append({"name": "Empty nutrient tank", "cb": func():
			nutrients.clear()
			Game.tell(user, "You empty %s's nutrient tank." % e.the()), "priority": 2})

func ai_tags(out: Dictionary) -> void:
	out["hydro"] = true
	if needs_care(): out["hydro_needs_care"] = true
	if ready(): out["hydro_harvest"] = true

# ---------------------------------------------------------------- sprite
func _refresh() -> void:
	if overlay == null: return
	overlay.visible = not seed.is_empty()
	if seed.is_empty(): return
	var family: String = Botany.sprite_family(seed.get("species", ""))
	var stage := 0
	if ready():
		stage = 4
	else:
		var maturation := maxf(1.0, float(seed.get("maturation", 6)))
		stage = clampi(int(float(age) / maturation * 4.0), 0, 3)
	overlay.region_rect = Gfx.region("objects", "plant_%s_%d" % [family, stage])
	if dead():
		overlay.modulate = Color(0.45, 0.35, 0.25)
	elif plant_health > float(seed.get("endurance", 15)) / 2.0:
		overlay.modulate = Color.WHITE
	else:
		overlay.modulate = Color(0.8, 0.7, 0.5)
