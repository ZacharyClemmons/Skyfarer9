class_name SkyClasses extends RefCounted
## What you were before you had a ship.
##
## Not a job on a station — a trade you learned somewhere and the tools you still own
## because of it. A class is three things and nothing else:
##
##   skills   a head start, in the skills that trade uses. Not a lock: every skill in
##            this game is levelled by doing it, so a Gunner who spends a month mining
##            will end up a miner who used to be a gunner.
##   kit      what is in your hands on the quay. Always worth real marks, so the classes
##            are also a choice about what you do not have to buy.
##   purse    what is left in your pocket, which is the honest trade-off: the Factor
##            starts rich and useless, the Prospector starts skilled and broke.
##
## Every class can do everything. The difference is what the first two hours look like,
## and what you can already afford not to pay somebody else for.

## id -> {name, blurb, cost (what the kit is worth), skills, items, purse, jobs, note}
##   `job` is the engine role underneath, which only decides the clothes you stand up in.
const CLASSES := {
	"deckhand": {
		"name": "Deckhand", "job": "assistant", "purse": 1.00,
		"blurb": "You have crewed for other people. You know which end of a ship is which and \
nothing else in particular.",
		"note": "No head start and no gaps. The most marks in your pocket.",
		"skills": {"airmanship": 8, "rigging": 6, "athletics": 8, "survival": 6, "melee": 5, "trading": 5},
		"items": ["rations_sky", "rations_sky"],
	},
	"shipwright": {
		"name": "Shipwright", "job": "engineer", "purse": 0.80,
		"blurb": "You built hulls for a yard that took the money and kept the drawings. You \
have your own tools and your own opinions about keels.",
		"note": "Fit heavy modules from the start, and build faster than anybody.",
		"skills": {"shipwright": 26, "construction": 18, "smithing": 14, "engineering": 12, "woodcutting": 8},
		"items": ["ship_rig", "toolbox", "welder"],
	},
	"prospector": {
		"name": "Prospector", "job": "miner", "purse": 0.72,
		"blurb": "Rock, mostly. You have worked veins on four islands and you can tell aetherite \
from skyglass by the sound the pick makes.",
		"note": "Ore and timber come out faster and in greater quantity.",
		"skills": {"mining": 28, "woodcutting": 20, "survival": 12, "smithing": 8, "athletics": 8},
		"items": ["pickaxe", "axe_felling", "flashlight"],
	},
	"sailmaker": {
		"name": "Sailmaker", "job": "botanist", "purse": 0.82,
		"blurb": "Canvas and cordage. Everybody needs you and nobody thanks you, which you have \
stopped minding.",
		"note": "Better sail trim, faster cell patches, and you can make your own canvas.",
		"skills": {"rigging": 28, "foraging": 18, "airmanship": 10, "athletics": 6},
		"items": ["sail_needle", "forage_knife", "canvas_bolt"],
	},
	"gunner": {
		"name": "Gunner", "job": "security", "purse": 0.78,
		"blurb": "You served a gun on somebody's deck and you left that ship on good terms, or \
at least at speed.",
		"note": "Broadsides land. Reloads are quick. Things that bite you regret it.",
		"skills": {"gunnery": 26, "marksman": 18, "melee": 14, "armor": 10, "evasion": 8},
		"items": ["aether_pistol", "boarding_axe"],
	},
	"navigator": {
		"name": "Navigator", "job": "captain", "purse": 0.84,
		"blurb": "You can read a sky. Where the islands are, what the weather will do about it, \
and which of the two is going to kill you first.",
		"note": "See further, read the weather early, and fly tighter than anyone.",
		"skills": {"navigation": 26, "airmanship": 20, "science": 10, "trading": 8, "social": 8},
		"items": ["sky_compass", "spyglass", "chart_scrap"],
	},
	"beastlorist": {
		"name": "Beast-hunter", "job": "doctor", "purse": 0.76,
		"blurb": "You took things apart for a living and learned what was inside them. Most of \
the scars are from the learning.",
		"note": "You know what a creature does before it does it, and you get more off it after.",
		"skills": {"beastlore": 28, "melee": 16, "survival": 16, "throwing": 10, "cooking": 8},
		"items": ["skinning_knife", "harpoon", "medkit"],
	},
	"distiller": {
		"name": "Distiller", "job": "chemist", "purse": 0.80,
		"blurb": "Fuel, mostly. Tonics, when there is a demand. Other things, when there is a \
demand and nobody is looking.",
		"note": "Make your own fuel and your own tonics, and they last longer on you.",
		"skills": {"distilling": 26, "chemistry": 16, "foraging": 14, "cooking": 12, "medical": 8},
		"items": ["tonic_lift", "tonic_wind", "fuel_can", "fuel_can"],
	},
	"artificer": {
		"name": "Artificer", "job": "scientist", "purse": 0.78,
		"blurb": "Aetherite work. Half the trade is knowing what a thing does; the other half is \
knowing what it will do next.",
		"note": "Build instruments, cells and aether weapons nobody else can.",
		"skills": {"artifice": 28, "science": 16, "engineering": 12, "smithing": 8, "marksman": 6},
		"items": ["artificers_kit", "multitool", "skyglass_lens"],
	},
	"salvager": {
		"name": "Salvager", "job": "cargo", "purse": 0.74,
		"blurb": "Wrecks. You have been inside more dead ships than live ones and you have a \
rule about not looking at the crew.",
		"note": "Deeper salvage rolls, intact components, and a grapple to get at them.",
		"skills": {"salvaging": 28, "athletics": 16, "engineering": 12, "shipwright": 8, "survival": 8},
		"items": ["grapple_gun", "salvage_saw", "crowbar"],
	},
	"factor": {
		"name": "Factor", "job": "qm", "purse": 2.05,
		"blurb": "You moved other people's cargo and took a cut of it. You have contacts, a nose \
for a margin, and no practical skills whatsoever.",
		"note": "Start rich. Haggle hard. Everything else you will have to learn the slow way.",
		"skills": {"trading": 30, "social": 20, "navigation": 8},
		"items": ["ledger_of_owed"],
	},
}

## The order they are offered in: the plain one first, then by what they are for.
const ORDER = ["deckhand", "shipwright", "prospector", "sailmaker", "navigator",
	"salvager", "beastlorist", "distiller", "artificer", "gunner", "factor"]

## Which group a class belongs to on the picker, purely for reading order.
const GROUPS = [
	["Aboard ship", Color("#7fd4ff"), ["deckhand", "shipwright", "navigator", "sailmaker"]],
	["On the islands", Color("#6ad88a"), ["prospector", "salvager", "beastlorist"]],
	["At the bench", Color("#e8a83a"), ["distiller", "artificer"]],
	["For hire", Color("#e8645a"), ["gunner", "factor"]],
]

## Godot reserves get_class() on Object, so this is `info`.
static func info(id: String) -> Dictionary:
	return CLASSES.get(id, CLASSES["deckhand"])

## What this person is, for the HUD, the radio and anything else that used to print a
## station job title. Reads the class off the entity first, then a vendor's trade, and
## only falls back to the engine's job table for crew the old code spawned.
static func title_of(who: Entity) -> String:
	if who == null or not is_instance_valid(who):
		return ""
	var cid := String(who.tags.get("sky_class", ""))
	if cid != "" and CLASSES.has(cid):
		return String(CLASSES[cid]["name"])
	var v: CVendor = who.c(&"vendor")
	if v != null:
		return String(v.info()["name"])
	if who.tags.has("beast"):
		return ""
	var m: CMob = who.c(&"mob")
	return CREW_TITLES.get(m.job, "skyfarer") if m != null else "skyfarer"

## What the engine's old station roles are called up here. Nobody in this game works for
## a research station, so the few NPCs spawned through the crew system get sky names.
const CREW_TITLES := {
	"captain": "master", "hop": "purser", "hos": "master-at-arms", "security": "watchman",
	"ce": "chief shipwright", "engineer": "engineer", "atmos": "air hand",
	"cmo": "surgeon", "doctor": "surgeon", "chemist": "distiller", "geneticist": "artificer",
	"rd": "chief artificer", "scientist": "artificer", "qm": "purser", "cargo": "hand",
	"miner": "prospector", "cook": "cook", "bartender": "publican", "botanist": "grower",
	"janitor": "sweeper", "clown": "fool", "assistant": "deckhand",
}

static func job_of(id: String) -> String:
	return String(info(id).get("job", "assistant"))

static func title(id: String) -> String:
	return String(info(id).get("name", id.capitalize()))

## What this class's kit is worth, so the purse trade-off can be shown honestly.
static func kit_value(id: String) -> int:
	var v := 0
	for it in info(id).get("items", []):
		v += Economy.base_value(String(it))
	return v

static func purse(id: String) -> int:
	return int(Economy.STARTING_PURSE * float(info(id).get("purse", 1.0)))

## The three or four skills worth naming on the picker, best first.
static func headline_skills(id: String) -> Array:
	var sk: Dictionary = info(id).get("skills", {})
	var rows := []
	for k in sk:
		rows.append([k, int(sk[k])])
	rows.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	return rows

## Apply the class to a freshly made character: skills, kit and purse.
static func apply(who: Entity, id: String) -> void:
	var cd := info(id)
	for skill in cd.get("skills", {}):
		Skills.set_level(who, String(skill), int(cd["skills"][skill]))
	Economy.set_purse(who, purse(id))
	for it in cd.get("items", []):
		if not Proto.has(String(it)):
			continue
		var made := Proto.spawn(String(it), who.root_cell())
		if made != null:
			Economy.deliver(who, made)
