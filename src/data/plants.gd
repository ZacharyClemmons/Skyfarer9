class_name Plants extends RefCounted
## Seeds, plant genes and species, ported from tgstation's botany
## (code/modules/hydroponics/seeds.dm, plant_genes.dm, grown/*.dm, __DEFINES/botany.dm).
##
## A seed is a plain Dictionary so it can ride along on a packet, a tray, a harvested
## fruit or a disk: {species, lifespan, endurance, maturation, production, yield,
## potency, instability, weed_rate, weed_chance, genes, grafts, name}. Every stat has
## tg's caps (adjust/set below); traits live in `genes` and are read by the tray, the
## harvest and the produce itself.

# ---------------------------------------------------------------- tg __DEFINES/botany.dm
const MAX_YIELD := 10
const MAX_LIFESPAN := 100
const MAX_ENDURANCE := 100
const MAX_PRODUCTION := 10
const MAX_POTENCY := 100
const MAX_INSTABILITY := 100
const MAX_WEEDRATE := 10
const MAX_WEEDCHANCE := 67
const MIN_ENDURANCE := 10
const MIN_LIFESPAN := 10
const WEED_HARDY_YIELD_MIN := 3
const CARNIVORY_POTENCY_MIN := 30
const FUNGAL_METAB_YIELD_MIN := 1
const PLANT_REAGENT_VOLUME := 100.0
const GENE_SHEAR_MIN_HEALTH := 15.0
const SOIL_LOVER_HYDRO_YIELD_MALUS := 0.7
const SOIL_LOVER_HYDRO_POTENCY_MAX := 0.8
const SOIL_LOVER_HYDRO_POTENCY_MIN := 0.5

## tg /obj/item/seeds defaults; any species that doesn't say otherwise uses these.
const DEFAULTS := {
	"lifespan": 25, "endurance": 15, "maturation": 6, "production": 6, "yield": 3,
	"potency": 10, "instability": 5, "weed_rate": 1, "weed_chance": 5, "growthstages": 6,
	"rarity": 0,
}

# ---------------------------------------------------------------- plant genes (plant_genes.dm)
## quality: "good" / "bad" / "neutral" (tg has no quality on plant genes; this drives the
## analyzer colouring). `graft` marks the traits a cutting can carry to another plant.
const GENES := {
	"repeated_harvest": {"name": "Perennial Growth", "desc": "The plant keeps growing after a harvest.", "quality": "good", "graft": true},
	"squash": {"name": "Liquid Contents", "desc": "Bursts when thrown or stepped on, spilling what's inside.", "quality": "neutral", "graft": true},
	"slip": {"name": "Slippery Skin", "desc": "Slippery enough to send someone flying.", "quality": "neutral", "graft": true},
	"glow": {"name": "Bioluminescence", "desc": "The fruit gives off light.", "quality": "good", "graft": true},
	"maxchem": {"name": "Densified Chemicals", "desc": "Twice the reagents in every fruit.", "quality": "good", "graft": true},
	"battery": {"name": "Capacitive Cell Production", "desc": "Wire it up and it works as a cell.", "quality": "good", "graft": true},
	"stinging": {"name": "Hypodermic Prickles", "desc": "Injects its reagents into whoever it hits.", "quality": "neutral", "graft": true},
	"fire_resistance": {"name": "Fire Resistance", "desc": "The plant does not burn.", "quality": "good", "graft": true},
	"invasive": {"name": "Invasive Spreading", "desc": "Spreads into any tray next to it.", "quality": "bad", "graft": false},
	"preserved": {"name": "Natural Insecticide", "desc": "Pests leave it alone.", "quality": "good", "graft": true},
	"tox_resistance": {"name": "Toxin Resistance", "desc": "Shrugs off a poisoned tray.", "quality": "good", "graft": true},
	"carnivory": {"name": "Obligate Carnivory", "desc": "Feeds on the pests in the tray.", "quality": "neutral", "graft": true},
	"never_mutate": {"name": "Prosophobic Inclination", "desc": "The species never mutates.", "quality": "neutral", "graft": true},
	"stable_stats": {"name": "Symbiotic Resilience", "desc": "Its stats never mutate on their own.", "quality": "good", "graft": true},
	"safe_instability": {"name": "Conserved Genetics", "desc": "Pollination can't destabilise it.", "quality": "good", "graft": true},
	"soil_lover": {"name": "Soil Lover", "desc": "Wants real soil; a water tray costs it yield.", "quality": "bad", "graft": false},
	"semiaquatic": {"name": "Semiaquatic", "desc": "Happy in water; weeds love the dry soil.", "quality": "neutral", "graft": false},
	"weed_hardy": {"name": "Weed Adaptation", "desc": "A weed: it needs nothing and chokes nothing.", "quality": "neutral", "graft": true},
	"fungal_metabolism": {"name": "Fungal Vitality", "desc": "A mushroom: it grows in the dark and drinks little.", "quality": "neutral", "graft": true},
	"toxin_adaptation": {"name": "Toxin Adaptation", "desc": "Thrives on a poisoned tray.", "quality": "good", "graft": true},
}

## Traits a random mutation can roll in (tg add_random_traits over the mutable genes).
const RANDOM_TRAITS := ["repeated_harvest", "squash", "slip", "glow", "maxchem", "battery", "stinging",
	"fire_resistance", "invasive", "preserved", "tox_resistance", "carnivory", "never_mutate",
	"stable_stats", "safe_instability"]

## Reagents a random mutation can graft on (tg add_random_reagents).
const RANDOM_REAGENTS := ["nutriment", "sugar", "water", "toxin", "capsaicin", "frostoil", "iron",
	"potassium", "ammonia", "cyanide", "space_drugs", "libital", "aiuri"]

# ---------------------------------------------------------------- species (grown/*.dm)
## produce: the proto harvested. reagents: tg reagents_add (units = potency x rate).
## mutates: tg mutatelist, the species this one can turn into at high instability.
const SPECIES := {
	"wheat": {"name": "Wheat Stalks", "produce": "food_wheat", "production": 1, "yield": 4, "potency": 15,
		"instability": 20, "mutates": ["oat"], "reagents": {"nutriment": 0.12}},
	"oat": {"name": "Oat Stalks", "produce": "food_oat", "production": 1, "yield": 4, "potency": 15,
		"instability": 20, "reagents": {"nutriment": 0.12}},
	"tomato": {"name": "Tomato Plants", "produce": "food_tomato", "maturation": 8, "instability": 25,
		"mutates": ["blood_tomato"], "genes": ["squash", "repeated_harvest"],
		"reagents": {"nutriment": 0.1, "vitamin": 0.04}},
	"blood_tomato": {"name": "Blood-Tomato Plants", "produce": "food_tomato_blood", "maturation": 8, "rarity": 20,
		"genes": ["squash", "repeated_harvest"], "reagents": {"blood": 0.2, "nutriment": 0.1, "vitamin": 0.04}},
	"potato": {"name": "Potato Plants", "produce": "food_potato", "lifespan": 30, "maturation": 10, "production": 1,
		"yield": 4, "growthstages": 4, "mutates": ["sweet_potato"], "genes": ["soil_lover", "battery"],
		"reagents": {"nutriment": 0.1, "vitamin": 0.04}},
	"sweet_potato": {"name": "Sweet Potato Plants", "produce": "food_potato_sweet", "lifespan": 30, "maturation": 10,
		"production": 1, "yield": 4, "growthstages": 4, "genes": ["soil_lover", "battery"],
		"reagents": {"nutriment": 0.1, "vitamin": 0.1, "sugar": 0.1}},
	"berry": {"name": "Berry Bush", "produce": "food_berries", "lifespan": 20, "maturation": 5, "production": 5,
		"yield": 2, "instability": 30, "mutates": ["glow_berry", "poison_berry"], "genes": ["repeated_harvest"],
		"reagents": {"nutriment": 0.1, "vitamin": 0.04}},
	"glow_berry": {"name": "Glow-Berry Bush", "produce": "food_berries_glow", "lifespan": 30, "endurance": 25,
		"maturation": 5, "production": 5, "yield": 2, "rarity": 20, "genes": ["glow", "repeated_harvest"],
		"reagents": {"uranium": 0.25, "iodine": 0.2, "nutriment": 0.1, "vitamin": 0.04}},
	"poison_berry": {"name": "Poison-Berry Bush", "produce": "food_berries_poison", "lifespan": 20, "maturation": 5,
		"production": 5, "yield": 2, "rarity": 10, "mutates": ["death_berry"], "genes": ["repeated_harvest"],
		"reagents": {"cyanide": 0.15, "staminatoxin": 0.2, "nutriment": 0.1, "vitamin": 0.04}},
	"death_berry": {"name": "Death Berry Bush", "produce": "food_berries_death", "lifespan": 30, "maturation": 5,
		"production": 5, "yield": 2, "potency": 50, "rarity": 30, "genes": ["repeated_harvest", "tox_resistance"],
		"reagents": {"coniine": 0.08, "staminatoxin": 0.1, "nutriment": 0.1, "vitamin": 0.04}},
	"banana": {"name": "Banana Tree", "produce": "food_banana", "lifespan": 50, "endurance": 30, "instability": 10,
		"genes": ["slip", "repeated_harvest"],
		"reagents": {"banana": 0.1, "potassium": 0.1, "nutriment": 0.02, "vitamin": 0.04}},
	"corn": {"name": "Corn Stalks", "produce": "food_corn", "maturation": 8, "potency": 20, "instability": 50,
		"growthstages": 3, "mutates": ["peppercorn"], "reagents": {"corn_oil": 0.2, "nutriment": 0.1, "vitamin": 0.04}},
	"peppercorn": {"name": "Pepper-Corn Stalks", "produce": "food_peppercorn", "maturation": 8, "potency": 20,
		"growthstages": 3, "reagents": {"blackpepper": 0.2, "nutriment": 0.1, "vitamin": 0.04}},
	"carrot": {"name": "Carrots", "produce": "food_carrot", "maturation": 10, "production": 1, "yield": 5,
		"instability": 15, "growthstages": 3, "genes": ["soil_lover"],
		"reagents": {"oculine": 0.1, "nutriment": 0.05, "vitamin": 0.04}},
	"chili": {"name": "Chili Plants", "produce": "food_chili", "lifespan": 20, "maturation": 5, "production": 5,
		"yield": 4, "potency": 20, "instability": 30, "mutates": ["ice_pepper"], "genes": ["repeated_harvest"],
		"reagents": {"capsaicin": 0.25, "nutriment": 0.04, "vitamin": 0.04}},
	"ice_pepper": {"name": "Chilly Pepper Plants", "produce": "food_icepepper", "lifespan": 25, "maturation": 4,
		"production": 4, "yield": 4, "potency": 20, "rarity": 20, "genes": ["repeated_harvest"],
		"reagents": {"frostoil": 0.25, "nutriment": 0.02, "vitamin": 0.02}},
	"apple": {"name": "Apple Tree", "produce": "food_apple", "lifespan": 55, "endurance": 35, "yield": 5,
		"mutates": ["gold_apple"], "genes": ["repeated_harvest"], "reagents": {"nutriment": 0.1, "vitamin": 0.04}},
	"gold_apple": {"name": "Golden Apple Tree", "produce": "food_apple_gold", "lifespan": 55, "endurance": 35,
		"maturation": 10, "production": 10, "yield": 5, "rarity": 40, "genes": ["repeated_harvest"],
		"reagents": {"gold": 0.2, "nutriment": 0.1, "vitamin": 0.04}},
	"cabbage": {"name": "Cabbages", "produce": "food_cabbage", "lifespan": 50, "endurance": 25, "maturation": 3,
		"production": 5, "yield": 4, "instability": 10, "growthstages": 1, "genes": ["repeated_harvest"],
		"reagents": {"nutriment": 0.1, "vitamin": 0.04}},
	"soya": {"name": "Soybean Plants", "produce": "food_soybeans", "maturation": 4, "production": 4, "potency": 15,
		"growthstages": 4, "mutates": ["butterbean"], "genes": ["repeated_harvest"],
		"reagents": {"nutriment": 0.05, "vitamin": 0.04, "corn_oil": 0.03}},
	"butterbean": {"name": "Butterbean Plants", "produce": "food_butterbeans", "maturation": 4, "production": 4,
		"potency": 10, "growthstages": 4, "rarity": 20, "genes": ["repeated_harvest"],
		"reagents": {"milk": 0.05, "cream": 0.05, "vitamin": 0.04}},
	"onion": {"name": "Onion Sprouts", "produce": "food_onion", "lifespan": 20, "endurance": 25, "maturation": 3,
		"production": 4, "yield": 6, "instability": 10, "growthstages": 3, "weed_chance": 3,
		"reagents": {"nutriment": 0.1, "vitamin": 0.04, "tearjuice": 0.25}},
	"pumpkin": {"name": "Pumpkin Vines", "produce": "food_pumpkin", "lifespan": 50, "endurance": 40, "growthstages": 3,
		"mutates": ["blumpkin"], "genes": ["repeated_harvest"], "reagents": {"nutriment": 0.2, "vitamin": 0.04}},
	"blumpkin": {"name": "Blumpkin Vines", "produce": "food_blumpkin", "lifespan": 50, "endurance": 40,
		"growthstages": 3, "rarity": 20, "genes": ["repeated_harvest"],
		"reagents": {"ammonia": 0.2, "chlorine": 0.1, "nutriment": 0.2}},
	"grape": {"name": "Grape Vine", "produce": "food_grapes", "lifespan": 50, "endurance": 25, "maturation": 3,
		"production": 5, "yield": 4, "growthstages": 2, "genes": ["repeated_harvest"],
		"reagents": {"nutriment": 0.1, "vitamin": 0.04, "sugar": 0.1}},
	"ambrosia": {"name": "Ambrosia Vulgaris", "produce": "food_ambrosia", "lifespan": 60, "endurance": 25, "yield": 6,
		"potency": 5, "instability": 30, "mutates": ["ambrosia_deus"], "genes": ["repeated_harvest"],
		"reagents": {"aiuri": 0.1, "libital": 0.1, "space_drugs": 0.15, "nutriment": 0.05, "vitamin": 0.04, "toxin": 0.1}},
	"ambrosia_deus": {"name": "Ambrosia Deus", "produce": "food_ambrosia_deus", "lifespan": 60, "endurance": 25,
		"yield": 6, "potency": 5, "rarity": 40, "genes": ["repeated_harvest"],
		"reagents": {"synaptizine": 0.15, "space_drugs": 0.1, "nutriment": 0.05, "vitamin": 0.04}},
	# mushrooms: they grow in the dark and keep at least one yield
	"plump": {"name": "Plump-Helmet Mushrooms", "produce": "food_plumphelmet", "maturation": 8, "production": 1,
		"yield": 4, "potency": 15, "growthstages": 3, "genes": ["fungal_metabolism"],
		"reagents": {"nutriment": 0.1, "vitamin": 0.04}},
	"chanterelle": {"name": "Chanterelle Mushrooms", "produce": "food_chanterelle", "lifespan": 35, "endurance": 20,
		"maturation": 7, "production": 1, "yield": 5, "potency": 15, "instability": 20, "growthstages": 3,
		"genes": ["fungal_metabolism"], "reagents": {"nutriment": 0.1}},
	"amanita": {"name": "Fly Amanitas", "produce": "food_amanita", "lifespan": 50, "endurance": 35, "maturation": 10,
		"production": 5, "yield": 4, "instability": 30, "growthstages": 3, "mutates": ["angel"],
		"genes": ["fungal_metabolism"], "reagents": {"amatoxin": 0.35, "mushroom_hallucinogen": 0.04}},
	"angel": {"name": "Destroying Angels", "produce": "food_angel", "lifespan": 50, "endurance": 35, "maturation": 12,
		"production": 5, "yield": 2, "potency": 35, "rarity": 30, "growthstages": 3, "genes": ["fungal_metabolism"],
		"reagents": {"amatoxin": 0.3, "mushroom_hallucinogen": 0.04}},
	"reishi": {"name": "Reishi", "produce": "food_reishi", "lifespan": 35, "endurance": 35, "maturation": 10,
		"production": 5, "yield": 4, "potency": 15, "instability": 30, "growthstages": 4,
		"genes": ["fungal_metabolism"], "reagents": {"morphine": 0.35, "multiver": 0.35}},
	"glowshroom": {"name": "Glowshrooms", "produce": "food_glowshroom", "lifespan": 100, "endurance": 30,
		"maturation": 15, "production": 1, "yield": 3, "potency": 30, "instability": 20, "growthstages": 4,
		"rarity": 20, "genes": ["glow", "fungal_metabolism"],
		"reagents": {"radium": 0.1, "phosphorus": 0.1, "nutriment": 0.04}},
	"towercap": {"name": "Tower Caps", "produce": "sheet_wood", "lifespan": 80, "endurance": 50, "maturation": 15,
		"production": 1, "yield": 5, "potency": 50, "growthstages": 3, "genes": ["fungal_metabolism"], "reagents": {}},
	# weeds: what a neglected tray turns into
	"starthistle": {"name": "Starthistle", "produce": "food_starthistle", "lifespan": 70, "endurance": 50,
		"maturation": 5, "production": 1, "yield": 2, "instability": 35, "growthstages": 3,
		"genes": ["weed_hardy"], "reagents": {"nutriment": 0.04}},
	"harebell": {"name": "Harebells", "produce": "food_harebell", "lifespan": 100, "endurance": 20, "maturation": 7,
		"production": 1, "yield": 2, "potency": 30, "instability": 1, "growthstages": 4,
		"genes": ["weed_hardy", "preserved"], "reagents": {"nutriment": 0.04}},
	"nettle": {"name": "Nettles", "produce": "food_nettle", "lifespan": 30, "endurance": 40, "yield": 4,
		"instability": 25, "genes": ["repeated_harvest", "weed_hardy", "stinging"], "reagents": {"acid": 0.5}},
}

## tg weedinvasion(): which weed takes over an untended tray, by its 1..18 roll.
const WEED_INVASION := ["starthistle", "starthistle", "starthistle", "plump", "plump", "towercap", "towercap",
	"chanterelle", "chanterelle", "amanita", "amanita", "harebell", "harebell", "nettle", "nettle",
	"reishi", "reishi", "reishi"]

## The packets a botany vendor and the hydroponics lockers start with.
const STARTER_SEEDS := ["wheat", "tomato", "potato", "berry", "corn", "carrot", "chili", "apple", "cabbage",
	"soya", "onion", "pumpkin", "grape", "banana", "ambrosia", "plump", "glowshroom"]

# ---------------------------------------------------------------- seeds
static func exists(species: String) -> bool:
	return SPECIES.has(species)

static func species_name(species: String) -> String:
	return SPECIES.get(species, {}).get("name", species.capitalize())

static func stat_of(species: String, key: String) -> Variant:
	var s: Dictionary = SPECIES.get(species, {})
	if s.has(key): return s[key]
	return DEFAULTS.get(key, 0)

## A fresh seed of `species` at its species stats (tg /obj/item/seeds defaults).
static func new_seed(species: String) -> Dictionary:
	if not SPECIES.has(species): species = "wheat"
	var s: Dictionary = SPECIES[species]
	var seed := {"species": species, "name": s["name"], "grafts": 0, "genes": (s.get("genes", []) as Array).duplicate()}
	for k in DEFAULTS:
		seed[k] = s.get(k, DEFAULTS[k])
	return seed

static func copy(seed: Dictionary) -> Dictionary:
	var out := seed.duplicate(true)
	out["grafts"] = 0
	return out

static func has_gene(seed: Dictionary, gene: String) -> bool:
	return gene in (seed.get("genes", []) as Array)

static func add_gene(seed: Dictionary, gene: String) -> bool:
	if not GENES.has(gene) or has_gene(seed, gene): return false
	# tg can_add: plant types are exclusive, and so are the glow colours
	if gene in ["weed_hardy", "fungal_metabolism", "toxin_adaptation"]:
		for g in ["weed_hardy", "fungal_metabolism", "toxin_adaptation"]:
			if has_gene(seed, g): return false
	seed["genes"] = (seed.get("genes", []) as Array) + [gene]
	return true

static func remove_gene(seed: Dictionary, gene: String) -> bool:
	var genes: Array = seed.get("genes", [])
	if not gene in genes: return false
	genes = genes.duplicate()
	genes.erase(gene)
	seed["genes"] = genes
	return true

## tg reagents_add plus any reagent genes grafted on by a mutation.
static func reagents_of(seed: Dictionary) -> Dictionary:
	var base: Dictionary = (SPECIES.get(seed.get("species", ""), {}).get("reagents", {}) as Dictionary).duplicate()
	for r in seed.get("extra_reagents", {}):
		base[r] = maxf(base.get(r, 0.0), seed["extra_reagents"][r])
	return base

# ------------------------------------------------------- stat caps (tg adjust_*/set_*)
static func _max_yield(seed: Dictionary) -> int:
	return MAX_YIELD

static func _min_yield(seed: Dictionary) -> int:
	return FUNGAL_METAB_YIELD_MIN if has_gene(seed, "fungal_metabolism") else 0

static func set_stat(seed: Dictionary, stat: String, value: float) -> void:
	match stat:
		"yield": seed["yield"] = clampi(int(round(value)), _min_yield(seed), _max_yield(seed))
		"lifespan": seed["lifespan"] = clampi(int(round(value)), MIN_LIFESPAN, MAX_LIFESPAN)
		"endurance": seed["endurance"] = clampi(int(round(value)), MIN_ENDURANCE, MAX_ENDURANCE)
		"production": seed["production"] = clampi(int(round(value)), 1, MAX_PRODUCTION)
		"potency": seed["potency"] = clampi(int(round(value)), 0, MAX_POTENCY)
		"instability": seed["instability"] = clampi(int(round(value)), 0, MAX_INSTABILITY)
		"weed_rate": seed["weed_rate"] = clampi(int(round(value)), 0, MAX_WEEDRATE)
		"weed_chance": seed["weed_chance"] = clampi(int(round(value)), 0, MAX_WEEDCHANCE)
		_: seed[stat] = value

static func adjust(seed: Dictionary, stat: String, amount: float) -> void:
	if seed.is_empty(): return
	set_stat(seed, stat, float(seed.get(stat, 0)) + amount)

## tg /obj/item/seeds/mutate(): the stat drift a mutagen pulse or an unstable plant rolls.
static func mutate(seed: Dictionary, lifemut := 2, endmut := 5, productmut := 1, yieldmut := 2,
		potmut := 25, wrmut := 2, wcmut := 5, traitmut := 0, stabmut := 3) -> void:
	if seed.is_empty(): return
	var rng := Game.rng
	adjust(seed, "lifespan", rng.randi_range(-lifemut, lifemut))
	adjust(seed, "endurance", rng.randi_range(-endmut, endmut))
	adjust(seed, "production", rng.randi_range(-productmut, productmut))
	adjust(seed, "yield", rng.randi_range(-yieldmut, yieldmut))
	adjust(seed, "potency", rng.randi_range(-potmut, potmut))
	adjust(seed, "instability", rng.randi_range(-stabmut, stabmut))
	adjust(seed, "weed_rate", rng.randi_range(-wrmut, wrmut))
	adjust(seed, "weed_chance", rng.randi_range(-wcmut, wcmut))
	if traitmut > 0 and rng.randi_range(1, 100) <= traitmut:
		if rng.randf() < 0.5: add_random_trait(seed)
		else: add_random_reagent(seed)

static func add_random_trait(seed: Dictionary) -> String:
	var pool := RANDOM_TRAITS.filter(func(g): return not has_gene(seed, g))
	if pool.is_empty(): return ""
	var gene: String = pool[Game.rng.randi() % pool.size()]
	return gene if add_gene(seed, gene) else ""

static func add_random_reagent(seed: Dictionary) -> String:
	var r: String = RANDOM_REAGENTS[Game.rng.randi() % RANDOM_REAGENTS.size()]
	var extra: Dictionary = (seed.get("extra_reagents", {}) as Dictionary).duplicate()
	extra[r] = maxf(extra.get(r, 0.0), 0.04)
	seed["extra_reagents"] = extra
	return r

## Which species this one can turn into (tg mutatelist).
static func mutations_of(seed: Dictionary) -> Array:
	return SPECIES.get(seed.get("species", ""), {}).get("mutates", [])

## tg prepare_result(): potency-scaled reagents for one harvested fruit.
static func produce_reagents(seed: Dictionary) -> Dictionary:
	var rates := reagents_of(seed)
	var out := {}
	if rates.is_empty(): return out
	var total := 0.0
	for r in rates: total += float(rates[r])
	var volume := PLANT_REAGENT_VOLUME * (2.0 if has_gene(seed, "maxchem") else 1.0)
	var potency := float(seed.get("potency", 10))
	for r in rates:
		var amount: float = volume * (potency / 100.0) * float(rates[r]) * minf(1.0, 1.0 / maxf(0.001, total))
		out[r] = maxf(1.0, round(amount))
	return out

## tg getYield(): the tray's yield modifier and the soil-lover malus.
static func yield_of(seed: Dictionary, yieldmod := 1.0, soil := false) -> int:
	var y := float(seed.get("yield", 0))
	if y < 0: return 0
	if not soil and has_gene(seed, "soil_lover"): y *= SOIL_LOVER_HYDRO_YIELD_MALUS
	if yieldmod == 0.0: return int(minf(y, 1.0))
	return int(round(y * yieldmod))

static func describe(seed: Dictionary) -> String:
	if seed.is_empty(): return "nothing"
	var lines := "%s - lifespan %d, endurance %d, maturation %d, production %d, yield %d, potency %d, instability %d, weed rate %d, weed chance %d%%" % [
		seed.get("name", "?"), seed.get("lifespan", 0), seed.get("endurance", 0), seed.get("maturation", 0),
		seed.get("production", 0), seed.get("yield", 0), seed.get("potency", 0), seed.get("instability", 0),
		seed.get("weed_rate", 0), seed.get("weed_chance", 0)]
	var genes: Array = seed.get("genes", [])
	if not genes.is_empty():
		var names := []
		for g in genes: names.append(GENES.get(g, {}).get("name", g))
		lines += "\nTraits: " + ", ".join(names)
	var rea := reagents_of(seed)
	if not rea.is_empty():
		var names := []
		for r in rea: names.append("%s %d%%" % [Chem.rname(r), int(float(rea[r]) * 100.0)])
		lines += "\nChemicals: " + ", ".join(names)
	return lines
