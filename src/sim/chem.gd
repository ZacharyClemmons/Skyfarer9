class_name Chem extends RefCounted
## tg chemistry (code/modules/reagents). Reagents with their per-second effects and
## overdoses, the chemical reactions from tg's recipe files (with their minimum
## temperatures: the chem heater warms a beaker up to them), and the bloodstream: what a
## mob drinks, swallows, is injected with or has patched on goes into its blood and is
## metabolised at tg's REAGENTS_METABOLISM (0.2 u a second unless the reagent says
## otherwise).

const REAGENTS_METABOLISM := 0.2
const ROOM_TEMP := 300.0

## effects are per second while in the bloodstream (at full dose):
##   heal {brute, burn, tox, oxy}: negative is damage   od: overdose threshold
##   rate: metabolism multiplier   blood: blood regained per second   warm/cool: K per s
const REAGENTS := {
	# tg atmos_gas_reagents.dm; gas metabolites last between normal 8-second breaths.
	"freon": {"name": "Freon", "color": Color("#90560b"), "rate": 0.5},
	"halon": {"name": "Halon", "color": Color("#90560b"), "rate": 0.5},
	"healium": {"name": "Healium", "color": Color("#fa8072"), "rate": 0.5, "heal": {"brute": 4.0, "burn": 4.0, "tox": 10.0}},
	"hypernoblium": {"name": "Hyper-Noblium", "color": Color("#008080"), "rate": 0.5},
	"nitrium": {"name": "Nitrium", "color": Color("#a52a2a"), "rate": 0.5},
	"nitrosyl_plasmide": {"name": "Nitrosyl Plasmide", "color": Color("#e1a116"), "rate": 0.5, "stamina": 8.0},
	"pluoxium": {"name": "Pluoxium", "color": Color("#808080"), "rate": 0.5},
	"zauker": {"name": "Zauker", "color": Color("#006400"), "rate": 0.5, "heal": {"brute": -12.0, "oxy": -2.0, "burn": -4.0, "tox": -4.0}},
	"bz_metabolites": {"name": "BZ Metabolites", "color": Color("#9370db"), "hallu": 10.0},
	# --- the dispenser (tg /obj/machinery/chem_dispenser dispensable_reagents)
	"hydrogen": {"name": "Hydrogen", "color": Color("#808080")},
	"lithium": {"name": "Lithium", "color": Color("#808080")},
	"carbon": {"name": "Carbon", "color": Color("#1c1300")},
	"nitrogen": {"name": "Nitrogen", "color": Color("#808080")},
	"oxygen": {"name": "Oxygen", "color": Color("#808080")},
	"fluorine": {"name": "Fluorine", "color": Color("#808080"), "heal": {"tox": -0.5}},
	"sodium": {"name": "Sodium", "color": Color("#808080")},
	"aluminium": {"name": "Aluminium", "color": Color("#a8a8a8")},
	"silicon": {"name": "Silicon", "color": Color("#a8a8a8")},
	"phosphorus": {"name": "Phosphorus", "color": Color("#832828")},
	"sulfur": {"name": "Sulfur", "color": Color("#bf8c00")},
	"chlorine": {"name": "Chlorine", "color": Color("#808080"), "heal": {"tox": -0.5}},
	"potassium": {"name": "Potassium", "color": Color("#a0a0a0")},
	"iron": {"name": "Iron", "color": Color("#606060"), "blood": 0.5, "od": 30.0},
	"copper": {"name": "Copper", "color": Color("#6e3b08")},
	"mercury": {"name": "Mercury", "color": Color("#484848"), "heal": {"tox": -0.25}},
	"radium": {"name": "Radium", "color": Color("#00ff00"), "heal": {"tox": -0.5}},
	"water": {"name": "Water", "color": Color("#6aa8e8"), "rate": 5.0},
	# tg /datum/reagent/consumable/ethanol: boozepwr, metabolised at half the normal rate
	"ethanol": {"name": "Ethanol", "color": Color("#d8e8e8"), "booze": 65.0, "rate": 0.5, "flammable": true},
	"vodka": {"name": "Vodka", "color": Color("#0064c8"), "booze": 65.0, "rate": 0.5, "flammable": true},
	"beer": {"name": "Beer", "color": Color("#664300"), "booze": 25.0, "rate": 0.5},
	"sugar": {"name": "Sugar", "color": Color("#f0f0f0"), "nutri": 1.0},
	"acid": {"name": "Sulfuric Acid", "color": Color("#00ff32"), "heal": {"tox": -0.5}, "touch_burn": 0.5},
	"fuel": {"name": "Welding Fuel", "color": Color("#4a3a1a"), "heal": {"tox": -0.5}, "flammable": true},
	"silver": {"name": "Silver", "color": Color("#d0d0d0")},
	"iodine": {"name": "Iodine", "color": Color("#c8a5dc")},
	"bromine": {"name": "Bromine", "color": Color("#d35415")},
	"stable_plasma": {"name": "Stable Plasma", "color": Color("#c84ae8"), "heal": {"tox": -0.75}},
	# --- intermediates
	"ammonia": {"name": "Ammonia", "color": Color("#404030")},
	"diethylamine": {"name": "Diethylamine", "color": Color("#604030")},
	"oil": {"name": "Oil", "color": Color("#2a2a2a"), "flammable": true},
	"phenol": {"name": "Phenol", "color": Color("#e7ea91")},
	"acetone": {"name": "Acetone", "color": Color("#c4c4c4"), "heal": {"tox": -0.5}},
	"salt": {"name": "Table Salt", "color": Color("#ffffff")},
	"ash": {"name": "Ash", "color": Color("#515151")},
	"lye": {"name": "Lye", "color": Color("#fff7ea"), "heal": {"tox": -0.5}},
	"space_cleaner": {"name": "Deck Cleaner", "color": Color("#a8d8ff")},
	"lube": {"name": "Deck Slick", "color": Color("#009ca8")},
	"blood": {"name": "Blood", "color": Color("#a81e2a"), "blood": 1.0, "rate": 5.0},
	# --- tg medicine (cat2 and the classics)
	"libital": {"name": "Libital", "color": Color("#ecec8d"), "heal": {"brute": 3.0, "tox": -0.3}, "od": 30.0, "desc": "Heals brute damage; a little hard on the liver."},
	"aiuri": {"name": "Aiuri", "color": Color("#8c93ff"), "heal": {"burn": 2.0}, "od": 30.0, "desc": "Heals burns; mildly irritates the eyes."},
	"multiver": {"name": "Multiver", "color": Color("#b1e46a"), "heal": {"tox": 1.5, "oxy": -0.3}, "purge": 0.5, "desc": "Purges toxins and other chemicals; hard on the lungs."},
	"convermol": {"name": "Convermol", "color": Color("#ff6464"), "heal": {"oxy": 2.0, "tox": -0.5}, "od": 35.0, "desc": "Restores oxygen; builds up toxins."},
	"epinephrine": {"name": "Epinephrine", "color": Color("#d2ffc8"), "crit": {"brute": 0.25, "burn": 0.25, "tox": 0.25, "oxy": 0.5}, "stabilize": true, "stamina": 2.5, "od": 30.0, "desc": "Stabilises critical patients."},
	"salglu_solution": {"name": "Saline-Glucose Solution", "color": Color("#dcdcdc"), "blood": 1.0, "chance_heal": {"brute": 0.5, "burn": 0.5}, "od": 60.0, "desc": "Restores lost blood volume."},
	"salbutamol": {"name": "Salbutamol", "color": Color("#00ffff"), "heal": {"oxy": 3.0}, "clear_breath": true, "rate": 1.0, "desc": "Rapidly restores oxygen."},
	"morphine": {"name": "Morphine", "color": Color("#a9fbfb"), "painkiller": true, "sleep_after": 25.0, "od": 30.0, "rate": 2.5, "desc": "A painkiller that eventually puts you to sleep."},
	"oxandrolone": {"name": "Oxandrolone", "color": Color("#1e8bff"), "heal": {"burn": 1.0}, "heal_bad": {"burn": 2.0}, "od": 25.0, "desc": "Heals burns; more so severe ones."},
	"sal_acid": {"name": "Salicylic Acid", "color": Color("#d2d2d2"), "heal": {"brute": 1.0}, "heal_bad": {"brute": 2.0}, "od": 25.0, "desc": "Heals bruises; more so severe ones."},
	"synthflesh": {"name": "Synthflesh", "color": Color("#ffebeb"), "touch_heal": {"brute": 1.5, "burn": 1.5}, "desc": "Heals brute and burn on contact."},
	"spaceacillin": {"name": "Aethermycin", "color": Color("#e8e8a8"), "cure": true, "desc": "A broad-spectrum antiviral."},
	"cryoxadone": {"name": "Cryoxadone", "color": Color("#8ae8f8"), "cryo": true, "desc": "Heals everything in the cold, below 270 K."},
	"mannitol": {"name": "Mannitol", "color": Color("#a6fad6"), "brain": 1.0, "od": 15.0, "desc": "Efficiently restores brain damage."},
	"neurine": {"name": "Neurine", "color": Color("#c0c0c0"), "cure_trauma": 8.0, "desc": "Reacts with neural tissue, helping reform damaged connections. Can cure minor traumas."},
	"potass_iodide": {"name": "Potassium Iodide", "color": Color("#bbbbbb"), "heal": {"tox": 0.5}, "desc": "Clears radiation."},
	"atropine": {"name": "Atropine", "color": Color("#000000"), "crit": {"brute": 1.0, "burn": 1.0, "oxy": 2.0}, "od": 15.0, "desc": "An emergency stimulant for the critically injured."},
	"haloperidol": {"name": "Haloperidol", "color": Color("#27870a"), "stamina": -2.0, "hallu": -12.5, "desc": "Calms, and drains stamina. Clears hallucinations."},
	"synaptizine": {"name": "Synaptizine", "color": Color("#ff00ff"), "hallu": -10.0, "desc": "Increases resistance to stuns as well as reducing drowsiness and hallucinations."},
	"mindbreaker": {"name": "Mindbreaker Toxin", "color": Color("#b838b8"), "hallu": 5.0, "desc": "A powerful hallucinogen. Not a thing to be messed with."},
	"mutadone": {"name": "Mutadone", "color": Color("#5096c8"), "desc": "Removes jitteriness and restores genetic defects."},
	# --- genetics (tg other_reagents.dm, toxin_reagents.dm, drug_reagents.dm, peaceborg)
	"monkey_powder": {"name": "Monkey Powder", "color": Color("#9c5a19"), "desc": "Just add water!"},
	"toxin": {"name": "Toxin", "color": Color("#cf3600"), "heal": {"tox": -0.75}, "desc": "A toxic chemical."},
	"pumpup": {"name": "Pump-Up", "color": Color("#e38e44"), "stamina": 3.0, "desc": "Take on the world! A fast acting, hard hitting drug that pushes the limit on what you can handle."},
	"determination": {"name": "Determination", "color": Color("#d0d0d0"), "desc": "For when you need to push on a little more. Do NOT allow near plants."},
	"tiring_solution": {"name": "Tiring Solution", "color": Color("#a1a1a1"), "desc": "An extremely weak stamina-toxin that tires out the target. Completely harmless."},
	"dizzy_solution": {"name": "Dizzying Solution", "color": Color("#b2b2b2"), "desc": "Makes the target off balance and dizzy."},
	"aslimetoxin": {"name": "Advanced Mutation Toxin", "color": Color("#13bc5e"), "desc": "An advanced corruptive toxin produced by slimes."},
	# --- toxins and drugs
	"cyanide": {"name": "Cyanide", "color": Color("#00b4ff"), "heal": {"tox": -1.5, "oxy": -1.0}, "desc": "A deadly poison."},
	"lexorin": {"name": "Lexorin", "color": Color("#7dc3a0"), "heal": {"oxy": -3.0}, "desc": "Stops you breathing."},
	"chloralhydrate": {"name": "Chloral Hydrate", "color": Color("#000067"), "sleep_after": 5.0, "heal": {"tox": -0.5}, "desc": "A powerful sedative."},
	"mutagen": {"name": "Unstable Mutagen", "color": Color("#00ff00"), "heal": {"tox": -0.5}},
	"methamphetamine": {"name": "Methamphetamine", "color": Color("#fafafa"), "stamina": 5.0, "speed": true, "heal": {"tox": -0.25}, "od": 20.0},
	"plasma": {"name": "Plasma", "color": Color("#c84ae8"), "heal": {"tox": -1.5}, "flammable": true},
	"space_drugs": {"name": "Dreamsmoke", "color": Color("#60a584")},
	# --- pyrotechnics (react on mixing)
	"thermite": {"name": "Thermite", "color": Color("#550000")},
	"napalm": {"name": "Napalm", "color": Color("#fa00af"), "flammable": true},
	"clf3": {"name": "Chlorine Trifluoride", "color": Color("#ffc8c8"), "touch_burn": 3.0},
	"flash_powder": {"name": "Flash Powder", "color": Color("#c8c8c8")},
	"smoke_powder": {"name": "Smoke Powder", "color": Color("#c8c8c8")},
	"cryostylane": {"name": "Cryostylane", "color": Color("#8ae8f8"), "cool": 10.0},
	# --- food and drink
	"cocoa": {"name": "Hot Chocolate", "color": Color("#6a3a22"), "warm": 3.0, "nutri": 1.0},
	"coffee": {"name": "Coffee", "color": Color("#482000"), "warm": 1.0, "stamina": 1.0},
	"nutriment": {"name": "Nutriment", "color": Color("#664330"), "nutri": 3.0},
	# --- botany: what grows in the trays and what you feed them (tg other_reagents.dm,
	#     toxin_reagents.dm, food_reagents.dm; the tray effects live in CHydro.TRAY_CHEMS)
	"vitamin": {"name": "Vitamin", "color": Color("#664330"), "nutri": 4.0, "desc": "All the best vitamins, minerals and carbohydrates the body needs in pure form."},
	"capsaicin": {"name": "Capsaicin Oil", "color": Color("#b31008"), "warm": 4.0, "desc": "This is what makes chilis hot."},
	"frostoil": {"name": "Frost Oil", "color": Color("#8ba6e9"), "cool": 4.0, "desc": "A special oil that noticeably chills the body. Extracted from chilly peppers."},
	"banana": {"name": "Banana Juice", "color": Color("#fffcb9"), "nutri": 1.0, "desc": "The raw essence of a banana. HONK"},
	"milk": {"name": "Milk", "color": Color("#dfdfdf"), "nutri": 2.0, "heal": {"brute": 0.25}, "desc": "An opaque white liquid produced by the mammary glands of mammals."},
	"cream": {"name": "Cream", "color": Color("#dfd7af"), "nutri": 3.0, "desc": "The fatty, still liquid part of milk."},
	"corn_oil": {"name": "Corn Oil", "color": Color("#302000"), "nutri": 2.5, "flammable": true, "desc": "An oil derived from various types of corn."},
	"blackpepper": {"name": "Black Pepper", "color": Color("#000000"), "desc": "A powder ground from peppercorns. *AAAACHOOO*"},
	"tearjuice": {"name": "Tear Juice", "color": Color("#c0c9a0"), "blur": 2.0, "desc": "A blinding substance extracted from certain onions."},
	"honey": {"name": "Honey", "color": Color("#d3a308"), "nutri": 5.0, "heal": {"brute": 0.25, "burn": 0.25}, "desc": "Sweet sweet honey. Has antibacterial and natural healing properties."},
	"sodawater": {"name": "Soda Water", "color": Color("#619494"), "desc": "A can of club soda. Why not make a scotch and soda?"},
	"virus_food": {"name": "Virus Food", "color": Color("#899613"), "nutri": 1.0, "desc": "A mixture of water and milk. Virus cells can use this mixture to reproduce."},
	"oculine": {"name": "Oculine", "color": Color("#404040"), "eyes": 2.0, "od": 30.0, "desc": "Quickly restores eye damage and cures nearsightedness."},
	"amatoxin": {"name": "Amatoxin", "color": Color("#792300"), "heal": {"tox": -2.5}, "desc": "A powerful poison derived from certain species of mushroom."},
	"mushroom_hallucinogen": {"name": "Mushroom Hallucinogen", "color": Color("#e700e7"), "hallu": 4.0, "rate": 0.2, "od": 30.0, "desc": "A strong hallucinogenic drug derived from certain species of mushroom."},
	"staminatoxin": {"name": "Tirizene", "color": Color("#6e2828"), "stamina": -3.0, "desc": "A nonlethal poison that causes extreme fatigue and weakness in its victim."},
	"coniine": {"name": "Coniine", "color": Color("#7dc3a0"), "heal": {"tox": -1.75, "oxy": -1.0}, "rate": 0.06, "desc": "Metabolises extremely slowly, deals high toxin damage and stops breathing."},
	"uranium": {"name": "Uranium", "color": Color("#5e9964"), "heal": {"tox": -1.0}, "desc": "A jade-green metallic element in the actinide series, weakly radioactive."},
	"gold": {"name": "Gold", "color": Color("#f7c430"), "desc": "A dense, soft, shiny metal and the most malleable and ductile metal known."},
	"cellulose": {"name": "Cellulose Fibers", "color": Color("#e6e6dc"), "desc": "A polysaccharide composed of glucose monomers; plant fibre."},
	"eznutriment": {"name": "E-Z Nutrient", "color": Color("#376400"), "desc": "Contains electrolytes. It's what plants crave."},
	"left4zednutriment": {"name": "Left 4 Zed", "color": Color("#1a1e0a"), "desc": "Unstable nutrient for plants: it makes their genes drift."},
	"robustharvestnutriment": {"name": "Robust Harvest", "color": Color("#9daa33"), "desc": "Stable nutrient for plants: bigger, steadier harvests."},
	"endurogrow": {"name": "Enduro Grow", "color": Color("#7d5e4c"), "desc": "Toughens up a plant at the cost of its fruit."},
	"saltpetre": {"name": "Saltpetre", "color": Color("#60a584"), "desc": "Volatile. Controversial. Third Thing."},
	"plantbgone": {"name": "Plant-B-Gone", "color": Color("#49002e"), "heal": {"tox": -1.0}, "desc": "A harmful toxic mixture to kill plantlife. Do not ingest!"},
	"weedkiller": {"name": "Weed Killer", "color": Color("#4b004b"), "heal": {"tox": -0.5}, "desc": "A harmful toxic mixture to kill weeds. Do not ingest!"},
	"pestkiller": {"name": "Pest Killer", "color": Color("#4b004b"), "heal": {"tox": -1.0}, "desc": "A harmful toxic mixture to kill pests. Do not ingest!"},
	# --- the old station names, kept for existing kit
	"bicaridine": {"name": "Bicaridine", "color": Color("#d84a4a"), "heal": {"brute": 2.0}},
	"kelotane": {"name": "Kelotane", "color": Color("#e8a83a"), "heal": {"burn": 2.0}},
	"dylovene": {"name": "Dylovene", "color": Color("#4ad84a"), "heal": {"tox": 2.0}},
	"dexalin": {"name": "Dexalin", "color": Color("#4a8ae8"), "heal": {"oxy": 3.0}},
}

## tg /datum/chemical_reaction: required reagents -> results, with required_temp (K).
## "effect" reactions do something in the world instead of (or as well as) making results.
const REACTIONS := [
	# intermediates (tg others.dm)
	{"in": {"hydrogen": 3, "nitrogen": 1}, "out": {"ammonia": 3}},
	{"in": {"ammonia": 1, "ethanol": 1}, "out": {"diethylamine": 2}},
	{"in": {"fuel": 1, "carbon": 1, "hydrogen": 1}, "out": {"oil": 3}},
	{"in": {"water": 1, "chlorine": 1, "oil": 1}, "out": {"phenol": 3}},
	{"in": {"oil": 1, "fuel": 1, "oxygen": 1}, "out": {"acetone": 3}},
	{"in": {"sodium": 1, "chlorine": 1}, "out": {"salt": 2}},
	{"in": {"oil": 1}, "out": {"ash": 1}, "temp": 480},
	{"in": {"sodium": 1, "hydrogen": 1, "oxygen": 1}, "out": {"lye": 3}},
	{"in": {"ammonia": 1, "water": 1}, "out": {"space_cleaner": 2}},
	{"in": {"water": 1, "silicon": 1, "oxygen": 1}, "out": {"lube": 4}},
	# medicine (tg medicine.dm, cat2_medicines.dm)
	{"in": {"phenol": 1, "oxygen": 1, "nitrogen": 1}, "out": {"libital": 3}, "temp": 225},
	{"in": {"ammonia": 1, "acid": 1, "hydrogen": 2}, "out": {"aiuri": 4}},
	{"in": {"ash": 1, "salt": 1}, "out": {"multiver": 2}, "temp": 380},
	{"in": {"hydrogen": 1, "fluorine": 1, "oil": 1}, "out": {"convermol": 3}, "temp": 370},
	{"in": {"phenol": 1, "acetone": 1, "diethylamine": 1, "oxygen": 1, "chlorine": 1, "hydrogen": 1}, "out": {"epinephrine": 6}},
	{"in": {"salt": 2, "sugar": 1}, "out": {"salglu_solution": 3}},
	{"in": {"sodium": 1, "phenol": 1, "carbon": 1, "oxygen": 1, "acid": 1}, "out": {"sal_acid": 5}},
	{"in": {"carbon": 3, "phenol": 1, "hydrogen": 1, "oxygen": 1}, "out": {"oxandrolone": 6}},
	{"in": {"sal_acid": 1, "lithium": 1, "aluminium": 1, "bromine": 1, "ammonia": 1}, "out": {"salbutamol": 5}},
	{"in": {"carbon": 2, "hydrogen": 2, "ethanol": 1, "oxygen": 1}, "out": {"morphine": 2}, "temp": 480},
	{"in": {"blood": 1, "carbon": 1, "libital": 1}, "out": {"synthflesh": 3}, "temp": 250},
	{"in": {"potassium": 1, "iodine": 1}, "out": {"potass_iodide": 2}},
	{"in": {"sugar": 1, "hydrogen": 1, "water": 1}, "out": {"mannitol": 3}},
	{"in": {"mannitol": 1, "acetone": 1, "oxygen": 1}, "out": {"neurine": 3}, "temp": 100},
	{"in": {"ethanol": 1, "acetone": 1, "diethylamine": 1, "phenol": 1, "acid": 1}, "out": {"atropine": 5}},
	{"in": {"stable_plasma": 1, "acetone": 1, "mutagen": 1}, "out": {"cryoxadone": 3}},
	{"in": {"chlorine": 1, "fluorine": 1, "aluminium": 1, "potass_iodide": 1, "oil": 1}, "out": {"haloperidol": 5}},
	{"in": {"mutagen": 1, "acetone": 1, "bromine": 1}, "out": {"mutadone": 3}},
	# tg /datum/chemical_reaction/monkey: fifty units of monkey powder and a drop of water
	{"in": {"monkey_powder": 50, "water": 1}, "effect": "monkey"},
	{"in": {"ethanol": 1, "chlorine": 1, "silicon": 1}, "out": {"spaceacillin": 2}},
	# toxins (tg toxins.dm)
	{"in": {"oil": 1, "ammonia": 1, "oxygen": 1}, "out": {"cyanide": 3}, "temp": 380},
	{"in": {"radium": 1, "phosphorus": 1, "chlorine": 1}, "out": {"mutagen": 3}, "temp": 100},
	{"in": {"stable_plasma": 1, "hydrogen": 1, "salbutamol": 1}, "out": {"lexorin": 3}, "temp": 100},
	{"in": {"ethanol": 1, "chlorine": 3, "water": 1}, "out": {"chloralhydrate": 1}, "temp": 200},
	{"in": {"diethylamine": 1, "iodine": 1, "phosphorus": 1, "hydrogen": 1}, "out": {"methamphetamine": 4}, "temp": 372},
	{"in": {"mercury": 1, "sugar": 1, "lithium": 1}, "out": {"space_drugs": 3}},
	# botany (tg recipes/others.dm)
	{"in": {"toxin": 1, "water": 4}, "out": {"plantbgone": 5}},
	{"in": {"toxin": 1, "ammonia": 4}, "out": {"weedkiller": 5}},
	{"in": {"toxin": 1, "ethanol": 4}, "out": {"pestkiller": 5}},
	{"in": {"potassium": 1, "nitrogen": 1, "oxygen": 3}, "out": {"saltpetre": 3}},
	{"in": {"water": 5, "milk": 5}, "out": {"virus_food": 15}, "temp": 600},
	# pyrotechnics (tg pyrotechnics.dm)
	{"in": {"potassium": 1, "water": 1}, "effect": "explosion", "div": 20.0},
	{"in": {"aluminium": 1, "iron": 1, "oxygen": 1}, "out": {"thermite": 3}},
	{"in": {"oil": 1, "fuel": 1, "ethanol": 1}, "out": {"napalm": 3}},
	{"in": {"chlorine": 1, "fluorine": 3}, "effect": "clf3", "temp": 424},
	{"in": {"aluminium": 1, "potassium": 1, "sulfur": 1}, "effect": "flash"},
	{"in": {"potassium": 1, "sugar": 1, "phosphorus": 1}, "effect": "smoke"},
	{"in": {"stable_plasma": 1, "nitrogen": 1, "water": 1}, "out": {"cryostylane": 3}},
	{"in": {"plasma": 1, "fuel": 1}, "effect": "fire"},
	{"in": {"chlorine": 1, "fuel": 1}, "effect": "toxic"},
]

## tg chem dispenser (tier 1)
const DISPENSABLE := ["hydrogen", "lithium", "carbon", "nitrogen", "oxygen", "fluorine", "sodium", "aluminium", "silicon", "phosphorus", "sulfur", "chlorine", "potassium", "iron", "copper", "mercury", "radium", "water", "ethanol", "sugar", "acid", "fuel", "silver", "iodine", "bromine", "stable_plasma"]

## tg /datum/reagent/medicine and /datum/reagent/drug subtypes (the chemical allergy
## mutation reacts to them)
const MEDICINE_OR_DRUG := ["libital", "aiuri", "multiver", "convermol", "epinephrine", "salglu_solution", "salbutamol", "morphine",
	"oxandrolone", "sal_acid", "synthflesh", "spaceacillin", "cryoxadone", "mannitol", "neurine", "potass_iodide", "atropine",
	"haloperidol", "synaptizine", "mutadone", "bicaridine", "kelotane", "dylovene", "dexalin", "space_drugs", "methamphetamine", "pumpup"]

static func is_medicine_or_drug(k: String) -> bool:
	return k in MEDICINE_OR_DRUG

static func rname(k: String) -> String:
	return REAGENTS.get(k, {}).get("name", k.capitalize())

## Mixes `contents` (name -> units) in place at `temp` K; returns the world effects.
static func react(contents: Dictionary, temp := ROOM_TEMP) -> Array:
	var effects := []
	var changed := true
	var guard := 0
	while changed and guard < 12:
		changed = false
		guard += 1
		for r in REACTIONS:
			if temp < float(r.get("temp", 0)):
				continue
			var amount := 1e9
			var ok := true
			for k in r["in"]:
				if contents.get(k, 0.0) < 0.1:
					ok = false
					break
				amount = minf(amount, contents[k] / float(r["in"][k]))
			if not ok or amount <= 0.0:
				continue
			for k in r["in"]:
				contents[k] -= amount * float(r["in"][k])
				if contents[k] < 0.01:
					contents.erase(k)
			for o in r.get("out", {}):
				contents[o] = contents.get(o, 0.0) + amount * float(r["out"][o])
			if r.has("effect"):
				var total_in := 0.0
				for k in r["in"]:
					total_in += amount * float(r["in"][k])
				effects.append({"effect": r["effect"], "amount": total_in, "div": r.get("div", 10.0)})
			changed = true
	return effects

## Applies reaction side effects in the world at `cell`.
static func apply_effects(effects: Array, cell: Vector2i, cause: Entity) -> void:
	for ef in effects:
		var amt: float = ef["amount"]
		match ef["effect"]:
			"explosion":
				# tg reagent_explosion: strength = volume / strengthdiv
				var power: float = amt / float(ef.get("div", 10.0))
				if power >= 1.0:
					var p := clampi(int(power), 0, 6)
					Explosion.explode(cell, int(p / 4.0), int(p / 2.0), p, cause)
				else:
					Fx.sparks(cell)
					Game.visible_message(cell, "The solution fizzes violently!", "warn")
			"smoke":
				Fx.smoke_puff(cell)
				if Game.atmos:
					Game.atmos.add_gas(Game.map.idx(cell), Defs.G_SMOKE, amt * 3.0, 300.0)
			"flash":
				# tg flash_powder: flashes everyone in range
				Fx.sparks(cell)
				Game.visible_message(cell, "A blinding flash erupts from the mixture!", "bad")
				# tg flash_powder: range = volume / 3; paralysed 6 s close by, else stunned 10 s
				for m in Game.in_radius(cell, maxi(1, int(amt / 3.0)), &"health"):
					var fh: CHealth = m.c(&"health")
					if StatusFx.flash_act(fh, 1, false):
						if maxi(absi(m.cell.x - cell.x), absi(m.cell.y - cell.y)) < 4:
							fh.paralyze(6.0)
						else:
							fh.stun(10.0)
			"monkey":
				# tg /datum/chemical_reaction/monkey: a monkey per reaction, up to the cap
				for i in maxi(1, int(amt / 51.0)):
					if Monkeys.cube_count() < Monkeys.MONKEY_CAP:
						Monkeys.spawn_monkey(cell, true)
				Game.visible_message(cell, "[b]The mixture expands into a brown mass before shaping itself into a monkey![/b]", "bad")
			"fire", "clf3":
				if Game.atmos:
					Game.atmos.add_gas(Game.map.idx(cell), Defs.G_PLASMA, amt * 0.6, 600.0)
					Game.atmos.ignite(cell, cause)
				if ef["effect"] == "clf3":
					for d in Defs.DIRS8:
						if Game.atmos and Game.rng.randf() < 0.6:
							Game.atmos.ignite(cell + d, cause)
			"toxic":
				if Game.atmos:
					Game.atmos.add_gas(Game.map.idx(cell), Defs.G_SMOKE, amt * 2.0, 300.0)
				for m in Game.in_radius(cell, 1, &"health"):
					m.c(&"health").adjust("tox", amt * 0.6, cause)
	if not effects.is_empty():
		Bus.stimulus.emit({"type": "chem_reaction", "actor": cause, "cell": cell, "loud": 8.0, "effects": effects})

static func color_of(contents: Dictionary) -> Color:
	var c := Color(0, 0, 0, 0)
	var tot := 0.0
	for k in contents:
		var rc: Color = REAGENTS.get(k, {}).get("color", Color.WHITE)
		c += rc * contents[k]
		tot += contents[k]
	return c / tot if tot > 0 else Color(1, 1, 1, 0)

static func describe(contents: Dictionary) -> String:
	var parts := []
	for k in contents:
		parts.append("%.1fu %s" % [contents[k], rname(k)])
	return ", ".join(parts) if not parts.is_empty() else "nothing"

## Swallowed / injected / dripped: `frac` of `contents` goes into the mob's bloodstream.
## Blood itself goes straight into the blood volume. The caller removes it from the source.
static func affect_mob(contents: Dictionary, mob: Entity, frac: float, btype := "") -> void:
	var h: CHealth = mob.c(&"health")
	if h == null:
		return
	for k in contents.keys():
		var u: float = contents[k] * frac
		if u <= 0.0:
			continue
		if k == "blood":
			Body.transfuse(h, u, btype)
			continue
		if k == "determination":
			h.determination += u # tg /datum/reagent/determination: the wound adrenaline
			continue
		var info: Dictionary = REAGENTS.get(k, {})
		if info.has("warm"):
			h.body_temp = minf(Defs.BODYTEMP_NORMAL + 1.0, h.body_temp + info["warm"] * u * 0.2)
		h.chems[k] = h.chems.get(k, 0.0) + u

## tg touch application (patches, sprays): touch reagents act on the skin right away.
static func touch_mob(contents: Dictionary, mob: Entity, frac: float) -> void:
	var h: CHealth = mob.c(&"health")
	if h == null:
		return
	for k in contents.keys():
		var u: float = contents[k] * frac
		var info: Dictionary = REAGENTS.get(k, {})
		for dmg in info.get("touch_heal", {}):
			h.adjust(dmg, -info["touch_heal"][dmg] * u)
		if info.has("touch_burn"):
			h.adjust("burn", info["touch_burn"] * u)
		if k == "space_cleaner":
			Blood.wash(mob, true)
	# the rest soaks in (tg patches: absorbed through the skin)
	affect_mob(contents, mob, frac)

## tg reagents/metabolize, once a second.
static func metabolize(h: CHealth, dt: float) -> void:
	if h.chems.is_empty() or h.dead:
		return
	# tg liver: toxins under its tolerance are filtered harmlessly, the rest hurt it; a
	# failing or missing liver metabolises nothing (liverless metabolize)
	if not Organs.liver_works(h):
		return
	var filtered := Organs.liver_filter(h, dt)
	var purge := 0.0
	for k in h.chems.keys():
		purge += REAGENTS.get(k, {}).get("purge", 0.0) * minf(1.0, h.chems[k])
	for k in h.chems.keys():
		if filtered.has(k) or not h.chems.has(k):
			continue
		var info: Dictionary = REAGENTS.get(k, {})
		var amount: float = h.chems[k]
		var use := minf(amount, REAGENTS_METABOLISM * info.get("rate", 1.0) * dt)
		var f := use / (REAGENTS_METABOLISM * dt) if use > 0.0 else 0.0 # 0..1 of a full dose
		if use > 0.0 and Addiction.REAGENTS.has(k):
			Addiction.expose(h, k, use)
		# tg on_mob_metabolize: the first tick a reagent works in the body
		if not h.has_meta("met_" + k):
			h.set_meta("met_" + k, true)
			if k == "mutadone":
				Mutadone.on_metabolize(h)
		match k:
			"mutadone":
				Mutadone.on_life(h)
			"tiring_solution":
				# tg peaceborg/tire: tires you out, never past 45 less your injuries
				if h.stamina_loss() < 45.0 - (100.0 - h.health()):
					h.adjust("stamina", 10.0 * 0.5 * dt)
				if Game.rng.randf() < 0.3 * dt:
					Game.tell(h.e, "You should sit down and take a rest...", "warn")
			"dizzy_solution":
				# tg peaceborg/confuse
				h.set_status("confusion", minf(h.status_left("confusion") + 3.0 * 0.5 * dt, maxf(5.0, h.status_left("confusion"))))
				if Game.rng.randf() < 0.2 * dt:
					Game.tell(h.e, "You feel confused and disoriented.", "warn")
		if k == "healium":
			h.sleep_for(30.0)
		if k == "nitrosyl_plasmide":
			h.remove_status("sleeping")
			var elapsed: float = h.get_meta("dose_" + k, 0.0)
			h.adjust("tox", 0.05 * elapsed * dt)
			h.set_meta("dose_" + k, elapsed + dt)
		if k == "pluoxium" and h.stat() == CHealth.UNCONSCIOUS:
			for organ in h.organs:
				Organs.apply_damage(h, organ, -0.5 * dt)
		if info.has("brain"):
			Organs.apply_damage(h, "brain", -info["brain"] * f * dt)
		if info.has("eyes"): # tg oculine: restores the eyes
			h.eye_damage = maxf(0.0, h.eye_damage - info["eyes"] * f * dt)
			h.set_status("eye_blur", maxf(0.0, h.status_left("eye_blur") - 4.0 * f * dt))
		if info.has("blur"): # tg tearjuice: onions in the eyes
			h.set_status_if_lower("eye_blur", info["blur"] * f * 6.0)
		if info.has("cure_trauma") and Body.spt_prob(info["cure_trauma"], dt):
			Traumas.cure_type(h, "", Traumas.RES_BASIC)
		for dmg in info.get("heal", {}):
			h.adjust(dmg, -info["heal"][dmg] * f * dt)
		for dmg in info.get("heal_bad", {}):
			var cur: float = h.burn if dmg == "burn" else h.brute
			if cur >= 25.0:
				h.adjust(dmg, -(info["heal_bad"][dmg] - info.get("heal", {}).get(dmg, 0.0)) * f * dt)
		for dmg in info.get("chance_heal", {}):
			if Game.rng.randf() < 0.33:
				h.adjust(dmg, -info["chance_heal"][dmg] * f * dt)
		if info.has("crit") and h.health() <= 0.0:
			for dmg in info["crit"]:
				h.adjust(dmg, -info["crit"][dmg] * f * dt)
		if info.get("stabilize", false) and h.health() <= 0.0:
			h.losebreath = 0.0
		if info.get("clear_breath", false):
			h.losebreath = maxf(0.0, h.losebreath - 1.0 * dt)
		if info.has("stamina"):
			h.adjust("stamina", -info["stamina"] * f * dt)
		if info.has("blood") and h.blood_volume < Body.BLOOD_VOLUME_NORMAL:
			h.blood_volume = minf(Body.BLOOD_VOLUME_NORMAL, h.blood_volume + info["blood"] * f * dt)
		if info.get("painkiller", false):
			h.pain = maxf(0.0, h.pain - 10.0 * dt)
		if info.get("cryo", false) and h.body_temp < 270.0:
			for dmg in ["brute", "burn", "tox", "oxy"]:
				h.adjust(dmg, -1.0 * f * dt)
		if info.has("cool"):
			h.body_temp -= info["cool"] * f * dt
		if info.has("warm"):
			h.body_temp = minf(Defs.BODYTEMP_NORMAL + 1.0, h.body_temp + info["warm"] * f * dt)
		if info.get("cure", false) and h.disease != null:
			h.disease.cure_progress += use * 0.1
		if info.has("booze"):
			_booze(h, k, info["booze"], amount, f, dt)
		if info.has("hallu"):
			# tg mindbreaker: anchors those plagued with hallucinations instead
			if k == "mindbreaker" and Traumas.has(h, "hallucinations"):
				h.remove_status("hallucination")
			else:
				Hallucinations.adjust(h, info["hallu"] * f * dt)
		if info.has("nutri"):
			var n: CNeeds = h.e.c(&"needs")
			if n:
				n.nutrition = minf(100.0, n.nutrition + info["nutri"] * f * dt * 0.5)
		if info.has("sleep_after"):
			h.set_meta("dose_" + k, h.get_meta("dose_" + k, 0.0) + use)
			if h.get_meta("dose_" + k, 0.0) >= info["sleep_after"]:
				h.knock_out(4.0)
		if info.has("od") and amount > info["od"]:
			# tg overdose: toxins, and the reagent's own nastiness
			h.adjust("tox", 1.0 * dt)
			if h.e == Game.player and Game.rng.randf() < 0.1:
				Game.tell(h.e, "You feel sick... too much %s." % rname(k), "bad")
		var left := amount - use
		if k != "multiver" and purge > 0.0:
			left = maxf(0.0, left - purge * dt)
		if left <= 0.01:
			h.chems.erase(k)
			if k == "healium" and h.has_status("sleeping"):
				h.set_status("sleeping", 1.0)
			if h.has_meta("dose_" + k):
				h.remove_meta("dose_" + k)
			if h.has_meta("met_" + k):
				h.remove_meta("met_" + k)
		else:
			h.chems[k] = left

const ALCOHOL_RATE := 0.005
const ALCOHOL_EXPONENT := 1.6
const ALCOHOL_THRESHOLD_MODIFIER := 1.0

## tg /datum/reagent/consumable/ethanol/on_mob_life: drunkenness from the volume and the
## boozepwr (diluted by any water in you), and liver damage that grows with strength.
static func _booze(h: CHealth, _k: String, boozepwr: float, volume: float, ratio: float, dt: float) -> void:
	if h.drunk >= volume * boozepwr * ALCOHOL_THRESHOLD_MODIFIER and boozepwr >= 0.0:
		return
	var power := boozepwr * Quirks.booze_mult(h.e) # tg TRAIT_ALCOHOL_TOLERANCE / TRAIT_LIGHT_DRINKER
	var alcohol := 0.0
	for c in h.chems:
		if REAGENTS.get(c, {}).has("booze"):
			alcohol += h.chems[c]
	var water: float = h.chems.get("water", 0.0)
	if alcohol + water > 0.0:
		power *= alcohol / (alcohol + water)
	StatusFx.adjust_drunk(h, sqrt(volume) * power * ALCOHOL_RATE * ratio * dt)
	if boozepwr > 0.0:
		Organs.apply_damage(h, "liver", maxf(sqrt(volume) * pow(boozepwr, ALCOHOL_EXPONENT) * ALCOHOL_RATE * dt, 0.0) / 150.0)
