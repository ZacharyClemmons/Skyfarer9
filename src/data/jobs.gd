class_name Jobs extends RefCounted
## Crew roles, adapted from tg's job datums (code/modules/jobs/job_types) for a
## sky-going ship and port. Titles are the sky names (display only; ids are the old keys). Each job: department, supervisor, access, radio, outfit, skills,
## personality leanings and where they like to work.

const ACCESS_ALL := ["all"]

const JOBS := {
	"captain": {
		"title": "Master", "dept": "command", "head": true, "supervisor": "",
		"access": ["all"], "radio": ["Command", "Security", "Engineering", "Medical", "Science", "Service", "Supply"],
		"outfit": {"uniform": ["formal", "#2a3a6a", "#d8b84a", "#1a1a20", "#d8b84a"], "head": ["captain", "#2a3a6a", "#000000", "#d8b84a"], "shoes": "#1a1a20", "gloves": "#e8e8e8", "id": "id_cap", "back": "#3a4a6a"},
		"skills": {"social": 7, "combat": 4, "engineering": 2, "medical": 2},
		"traits": {"bravery": 0.3, "lawfulness": 0.3, "diligence": 0.2},
		"work": ["Bridge", "Director's Office"], "slots": 1, "items": ["flashlight"],
	},
	"hop": {
		"title": "Purser", "dept": "command", "head": true, "supervisor": "captain",
		"access": ["command", "hop", "service", "supply", "maint", "eva", "security"], "radio": ["Command", "Service", "Supply"],
		"outfit": {"uniform": ["formal", "#3a5a8a", "#c83a3a", "#1a1a20", "#d8b84a"], "shoes": "#1a1a20", "id": "id_cmd", "back": "#4a5a7a"},
		"skills": {"social": 7, "cooking": 2}, "traits": {"sociability": 0.3, "empathy": 0.2},
		"work": ["Personnel Office", "Bridge"], "slots": 1, "items": [],
	},
	"hos": {
		"title": "Master-at-Arms", "dept": "security", "head": true, "supervisor": "captain",
		"access": ["security", "brig", "armory", "command", "maint", "eva", "engineering", "medical", "science", "supply", "service"], "radio": ["Command", "Security"],
		"outfit": {"uniform": ["jumpsuit", "#6a1a22", "#2a2e38", "#1a1a20", "#b0b8c4"], "suit": ["armor", "#3a2a2e", "#8a2a33"], "head": ["beret", "#8a1a22", "#000000", "#d8b84a"], "shoes": "#1a1a20", "gloves": "#1a1a20", "belt": "#2a2e38", "id": "id_sec", "back": "#3a3a40"},
		"skills": {"combat": 8, "social": 4, "medical": 2}, "traits": {"bravery": 0.4, "lawfulness": 0.4, "aggression": 0.2},
		"work": ["Security Office", "Brig"], "slots": 1, "items": ["baton", "handcuffs", "flashlight"],
	},
	"security": {
		"title": "Watchman", "dept": "security", "supervisor": "hos",
		"access": ["security", "brig", "maint", "eva"], "radio": ["Security"],
		"outfit": {"uniform": ["jumpsuit", "#8a2a33", "#2a2e38", "#1a1a20", "#b0b8c4"], "suit": ["armor", "#3a3f4a", "#5a6272"], "head": ["helmet", "#8a2a33", "#9fd0ec"], "shoes": "#1a1a20", "gloves": "#1a1a20", "belt": "#2a2e38", "id": "id_sec", "back": "#3a3a40"},
		"skills": {"combat": 6, "medical": 1}, "traits": {"bravery": 0.3, "lawfulness": 0.3},
		"work": ["Security Office", "Brig", "Central Hall"], "slots": 3, "items": ["baton", "handcuffs", "flashlight"],
	},
	"ce": {
		"title": "Chief Shipwright", "dept": "engineering", "head": true, "supervisor": "captain",
		"access": ["engineering", "engine", "atmos", "maint", "eva", "external", "command", "tech"], "radio": ["Command", "Engineering"],
		"outfit": {"uniform": ["jumpsuit", "#d8dee6", "#d8a53a", "#3a3a40", "#b0b8c4"], "head": ["hardhat", "#f0f0f0", "#000000", "#fff8d0"], "shoes": "#3a3530", "gloves": "#e8c83a", "belt": "toolbelt", "id": "id_eng", "back": "#8a6a3a", "suit": ["winter", "#d8dee6", "#efe8dc", "#d8a53a"]},
		"skills": {"engineering": 9, "construction": 8, "atmos": 6, "social": 4}, "traits": {"diligence": 0.3, "bravery": 0.2},
		"work": ["Engineering", "Reactor Chamber", "CE's Office"], "slots": 1, "items": ["multitool"],
	},
	"engineer": {
		"title": "Engineer", "dept": "engineering", "supervisor": "ce",
		"access": ["engineering", "engine", "maint", "eva", "external", "tech"], "radio": ["Engineering"],
		"outfit": {"uniform": ["jumpsuit", "#d88a2a", "#5f6878", "#3a3a40", "#b0b8c4"], "head": ["hardhat", "#e8c83a", "#000000", "#fff8d0"], "shoes": "#3a3530", "gloves": "#e8c83a", "belt": "toolbelt", "suit": ["hazard", "#e8702a", "#e8e8a0"], "id": "id_eng", "back": "#8a6a3a"},
		"skills": {"engineering": 7, "construction": 6, "atmos": 3}, "traits": {"diligence": 0.1},
		"work": ["Engineering", "Reactor Chamber", "Power Storage"], "slots": 3, "items": [],
	},
	"atmos": {
		"title": "Air Hand", "dept": "engineering", "supervisor": "ce",
		"access": ["engineering", "atmos", "maint", "eva", "external"], "radio": ["Engineering"],
		"outfit": {"uniform": ["jumpsuit", "#d8a53a", "#3a8ad8", "#3a3a40", "#b0b8c4"], "shoes": "#3a3530", "gloves": "#3a3530", "belt": "toolbelt", "mask": ["gasmask", "#3a3f4a", "#7ab8e0", "#000000", "#6a7486"], "id": "id_eng", "back": "#4a6a8a"},
		"skills": {"atmos": 8, "engineering": 5, "construction": 4}, "traits": {"curiosity": 0.1},
		"work": ["Atmospherics"], "slots": 2, "items": ["extinguisher", "gas_analyzer"],
	},
	"cmo": {
		"title": "Chief Surgeon", "dept": "medical", "head": true, "supervisor": "captain",
		"access": ["medical", "chemistry", "genetics", "surgery", "morgue", "command", "maint", "eva"], "radio": ["Command", "Medical"],
		"outfit": {"uniform": ["scrubs", "#3a6ad8", "#e8eef4"], "suit": ["labcoat", "#eef2f6", "#3a6ad8"], "shoes": "#e8eef4", "gloves": "#e8eef4", "id": "id_med", "back": "#e8eef4"},
		"skills": {"medical": 9, "chemistry": 6, "social": 5}, "traits": {"empathy": 0.4, "diligence": 0.2},
		"work": ["Medbay Treatment", "CMO's Office"], "slots": 1, "items": ["health_analyzer", "medkit"],
	},
	"doctor": {
		"title": "Surgeon", "dept": "medical", "supervisor": "cmo",
		"access": ["medical", "surgery", "morgue", "maint"], "radio": ["Medical"],
		"outfit": {"uniform": ["scrubs", "#4aa3b8", "#e8eef4"], "suit": ["labcoat", "#eef2f6", "#4aa3d8"], "shoes": "#e8eef4", "gloves": "#e8eef4", "id": "id_med", "back": "#e8eef4"},
		"skills": {"medical": 7, "chemistry": 3}, "traits": {"empathy": 0.35},
		"work": ["Medbay Treatment", "Medbay Lobby"], "slots": 3, "items": ["health_analyzer", "medkit"],
	},
	"chemist": {
		"title": "Distiller", "dept": "medical", "supervisor": "cmo",
		"access": ["medical", "chemistry"], "radio": ["Medical"],
		"outfit": {"uniform": ["jumpsuit", "#e8eef4", "#e8883a", "#3a3a40", "#b0b8c4"], "suit": ["labcoat", "#eef2f6", "#e8883a"], "shoes": "#e8eef4", "gloves": "#e8a83a", "id": "id_med", "back": "#e8eef4"},
		"skills": {"chemistry": 8, "medical": 4}, "traits": {"curiosity": 0.2},
		"work": ["Chemistry"], "slots": 1, "items": ["beaker"],
	},
	# tg code/modules/jobs/job_types/geneticist.dm (outfit: jumpsuit/rank/medical/geneticist,
	# labcoat/genetics, backpack/genetics, sequence scanner in the suit storage)
	"geneticist": {
		"title": "Naturalist", "dept": "medical", "supervisor": "cmo",
		"access": ["medical", "genetics", "morgue"], "radio": ["Medical"],
		"outfit": {"uniform": ["jumpsuit", "#e8eef4", "#3a7ac8", "#3a3a40", "#b0b8c4"], "suit": ["labcoat", "#eef2f6", "#3a7ac8"], "shoes": "#e8eef4", "id": "id_med", "back": "#e8eef4"},
		"skills": {"medical": 5, "science": 6, "chemistry": 3}, "traits": {"curiosity": 0.35},
		"work": ["Genetics"], "slots": 2, "items": ["sequence_scanner"],
	},
	"rd": {
		"title": "Chief Artificer", "dept": "science", "head": true, "supervisor": "captain",
		"access": ["science", "research", "rd", "command", "maint", "eva", "tech"], "radio": ["Command", "Science"],
		"outfit": {"uniform": ["jumpsuit", "#6a4a8a", "#e8eef4", "#3a3a40", "#b0b8c4"], "suit": ["labcoat", "#eef2f6", "#8a5ac8"], "shoes": "#5a4a3a", "id": "id_sci", "back": "#6a4a8a"},
		"skills": {"science": 9, "chemistry": 6, "engineering": 4}, "traits": {"curiosity": 0.4},
		"work": ["Research Lab", "RD's Office"], "slots": 1, "items": [],
	},
	"scientist": {
		"title": "Artificer", "dept": "science", "supervisor": "rd",
		"access": ["science", "research", "maint"], "radio": ["Science"],
		"outfit": {"uniform": ["jumpsuit", "#e8eef4", "#8a5ac8", "#3a3a40", "#b0b8c4"], "suit": ["labcoat", "#eef2f6", "#8a5ac8"], "shoes": "#5a4a3a", "id": "id_sci", "back": "#8a5ac8"},
		"skills": {"science": 7, "chemistry": 5}, "traits": {"curiosity": 0.35},
		"work": ["Research Lab", "Xenochemistry"], "slots": 3, "items": ["beaker"],
	},
	"qm": {
		"title": "Quartermaster", "dept": "supply", "head": true, "supervisor": "hop",
		"access": ["supply", "qm", "mining", "maint", "eva", "external"], "radio": ["Supply", "Command"],
		"outfit": {"uniform": ["jumpsuit", "#b8823a", "#5f4a2a", "#3a3a40", "#b0b8c4"], "head": ["cap", "#b8823a"], "shoes": "#3a3530", "id": "id_cargo", "back": "#8a6a3a"},
		"skills": {"social": 5, "construction": 3}, "traits": {"diligence": 0.1, "honesty": -0.1},
		"work": ["Cargo Bay", "Quartermaster's Office"], "slots": 1, "items": [],
	},
	"cargo": {
		"title": "Hold Hand", "dept": "supply", "supervisor": "qm",
		"access": ["supply", "maint", "eva"], "radio": ["Supply"],
		"outfit": {"uniform": ["jumpsuit", "#c8a06a", "#5f4a2a", "#3a3a40", "#b0b8c4"], "head": ["cap", "#c8a06a"], "shoes": "#3a3530", "gloves": "#5a4a3a", "id": "id_cargo", "back": "#8a6a3a"},
		"skills": {"construction": 3}, "traits": {},
		"work": ["Cargo Bay"], "slots": 2, "items": [],
	},
	"miner": {
		"title": "Prospector", "dept": "supply", "supervisor": "qm",
		"access": ["supply", "mining", "eva", "external", "maint"], "radio": ["Supply"],
		"outfit": {"uniform": ["jumpsuit", "#6a5a4a", "#3a3a40", "#1a1a20", "#b0b8c4"], "suit": ["winter", "#6a7a4a", "#efe8dc", "#c8ccd4"], "head": ["hood", "#6a7a4a", "#efe8dc"], "mask": ["breath", "#6a7486"], "shoes": "#3a3530", "gloves": "#3a3530", "id": "id_cargo", "back": "#5a6a3a"},
		"skills": {"mining": 8, "combat": 3, "construction": 2}, "traits": {"bravery": 0.3, "sociability": -0.2},
		"work": ["Mining Dock"], "slots": 2, "items": ["pickaxe", "tank_o2", "flashlight"],
	},
	"cook": {
		"title": "Cook", "dept": "service", "supervisor": "hop",
		"access": ["service", "kitchen"], "radio": ["Service"],
		"outfit": {"uniform": ["jumpsuit", "#eeeeee", "#c8c8c8", "#3a3a40", "#b0b8c4"], "suit": ["apron", "#e8e8e8"], "head": ["chef", "#f4f4f4", "#d8d8d8"], "shoes": "#1a1a20", "id": "id_srv", "back": "#e8e8e8"},
		"skills": {"cooking": 8, "botany": 2}, "traits": {"sociability": 0.1},
		"work": ["Kitchen"], "slots": 1, "items": [],
	},
	"bartender": {
		"title": "Publican", "dept": "service", "supervisor": "hop",
		"access": ["service", "bar"], "radio": ["Service"],
		"outfit": {"uniform": ["formal", "#2a2a30", "#e8e8e8", "#1a1a20", "#b0b8c4"], "shoes": "#1a1a20", "id": "id_srv", "back": "#2a2a30"},
		"skills": {"social": 7, "cooking": 4}, "traits": {"sociability": 0.35, "humor": 0.2},
		"work": ["Bar", "Cafeteria"], "slots": 1, "items": [],
	},
	"botanist": {
		"title": "Grower", "dept": "service", "supervisor": "hop",
		"access": ["service", "hydro"], "radio": ["Service"],
		"outfit": {"uniform": ["jumpsuit", "#4a8a4a", "#2a5a2a", "#3a3a40", "#b0b8c4"], "suit": ["apron", "#3a6a3a"], "shoes": "#3a3530", "gloves": "#4a7a3a", "id": "id_srv", "back": "#4a7a3a"},
		"skills": {"botany": 8, "cooking": 2}, "traits": {"empathy": 0.1},
		"work": ["Hydroponics"], "slots": 2, "items": [],
	},
	"janitor": {
		"title": "Sweeper", "dept": "service", "supervisor": "hop",
		"access": ["janitor", "maint", "service"], "radio": ["Service"],
		"outfit": {"uniform": ["jumpsuit", "#6a4a8a", "#3a2a4a", "#3a3a40", "#b0b8c4"], "shoes": "#1a1a20", "gloves": "#8a4ae8", "id": "id_srv", "back": "#6a4a8a"},
		"skills": {"construction": 1}, "traits": {"diligence": 0.1, "sociability": -0.1},
		"work": ["Custodial Closet"], "slots": 1, "items": ["mop"],
	},
	"clown": {
		"title": "Fool", "dept": "service", "supervisor": "hop",
		"access": ["service", "theatre"], "radio": ["Service"],
		"outfit": {"uniform": ["jumpsuit", "#e84ae8", "#ffd84a", "#4ae8e8", "#e84a4a"], "shoes": "#e84a4a", "id": "id_srv", "back": "#ffd84a"},
		"skills": {"social": 5}, "traits": {"humor": 0.8, "lawfulness": -0.3, "sociability": 0.3},
		"work": ["Cafeteria", "Central Hall"], "slots": 1, "items": ["food_banana", "food_banana"],
	},
	"assistant": {
		"title": "Deckhand", "dept": "civilian", "supervisor": "hop",
		"access": ["maint"], "radio": [],
		"outfit": {"uniform": ["jumpsuit", "#7a8292", "#5f6878", "#3a3a40", "#b0b8c4"], "shoes": "#1a1a20", "id": "id_gen", "back": "#5a6272"},
		"skills": {"construction": 1}, "traits": {"lawfulness": -0.2, "curiosity": 0.1, "diligence": -0.3},
		"work": ["Central Hall", "Cafeteria", "Dormitories"], "slots": 4, "items": [],
	},
}

## Order in which roles get filled for an NPC crew of size n (heads and essentials first).
## Where each job starts the shift (tg: the job's start landmarks in its department).
const START_ROOM := {"captain": "bridge", "hop": "hop_office", "hos": "hos_office", "security": "security_office", "ce": "ce_office",
	"engineer": "engineering", "atmos": "atmospherics", "cmo": "cmo_office", "doctor": "treatment", "chemist": "chemistry", "geneticist": "genetics", "rd": "rd_office",
	"scientist": "research_lab", "qm": "qm_office", "cargo": "cargo_bay", "miner": "mining_dock", "cook": "kitchen", "bartender": "bar",
	"botanist": "hydroponics", "janitor": "custodial", "clown": "cafeteria", "assistant": "cafeteria"}

## Each job's own lockers in its start room, one per slot (tg: the "Station Engineer's
## locker" and friends, locked to that job's access): spare kit for the shift.
const LOCKERS := {
	"captain": {"spr": "cmd", "access": "captain", "items": ["winter_coat", "flashlight", "drink_booze", "medkit"]},
	"hop": {"spr": "cmd", "access": "hop", "items": ["winter_coat", "flashlight", "paper", "paper", "pen"]},
	"hos": {"spr": "sec", "access": "armory", "items": ["winter_coat", "egun", "baton", "handcuffs", "flashbang", "sunglasses", "gas_mask", "forensic_scanner"]},
	"security": {"spr": "sec", "access": "security", "items": ["winter_coat", "disabler", "flash", "pepperspray", "handcuffs", "sunglasses", "gauze", "forensic_scanner"]},
	"ce": {"spr": "eng", "access": "engineering", "items": ["winter_coat", "welder", "multitool", "insulated_gloves", "cable_coil", "gas_mask", "gas_analyzer", "t_scanner"]},
	"engineer": {"spr": "eng", "access": "engineering", "items": ["winter_coat", "welder", "welding_helmet", "cable_coil", "sheet_metal", "flashlight", "gas_mask", "t_scanner"]},
	"atmos": {"spr": "eng", "access": "atmos", "items": ["winter_coat", "extinguisher", "gas_mask", "tank_air", "wrench", "flashlight", "gas_analyzer", "t_scanner"]},
	"cmo": {"spr": "med", "access": "medical", "items": ["winter_coat", "defib", "medkit", "health_analyzer", "medipen", "pill_bottle"]},
	"doctor": {"spr": "med", "access": "medical", "items": ["winter_coat", "medkit", "gauze", "ointment", "medipen", "health_analyzer", "pen"]},
	"chemist": {"spr": "med", "access": "chemistry", "items": ["winter_coat", "beaker", "beaker", "gas_mask", "pill_bottle"]},
	"geneticist": {"spr": "med", "access": "genetics", "items": ["winter_coat", "pill_bottle_mutadone", "latex_gloves", "sequence_scanner", "dna_disk"]},
	"rd": {"spr": "sci", "access": "rd", "items": ["winter_coat", "beaker", "multitool", "gas_mask", "flashlight"]},
	"scientist": {"spr": "sci", "access": "science", "items": ["winter_coat", "beaker", "gas_mask", "extinguisher_mini"]},
	"qm": {"spr": "gen", "access": "qm", "items": ["winter_coat", "paper", "flashlight", "crowbar"]},
	"cargo": {"spr": "gen", "access": "supply", "items": ["winter_coat", "crowbar", "flashlight"]},
	"miner": {"spr": "winter", "access": "mining", "items": ["winter_coat", "winter_hood", "pickaxe", "tank_o2", "breath_mask", "glowstick", "glowstick", "knife_survival"]},
	"cook": {"spr": "gen", "access": "kitchen", "items": ["food_flour", "food_egg", "food_meat", "drink_water"]},
	"bartender": {"spr": "gen", "access": "bar", "items": ["drink_booze", "drink_booze", "drink_soda", "lighter", "cig_pack"]},
	"botanist": {"spr": "gen", "access": "hydro", "items": ["bucket", "food_wheat", "food_tomato", "drink_water"]},
	"janitor": {"spr": "gen", "access": "janitor", "items": ["mop", "bucket", "soap", "spray_bottle", "light_tube", "light_tube", "gas_mask", "wet_floor_sign"]},
	"clown": {"spr": "gen", "access": "", "items": ["food_banana", "food_banana", "soap"]},
	"assistant": {"spr": "gen", "access": "", "items": ["winter_coat", "flashlight", "drink_water", "cig_pack", "lighter"]},
}

const FILL_ORDER := ["captain", "engineer", "doctor", "security", "cook", "ce", "scientist", "atmos", "botanist", "janitor",
	"hos", "cmo", "miner", "cargo", "engineer", "doctor", "security", "rd", "bartender", "chemist", "geneticist", "assistant", "clown",
	"qm", "hop", "scientist", "engineer", "assistant", "security", "doctor", "miner", "assistant", "cargo", "botanist", "assistant"]

static func title(job: String) -> String:
	return JOBS.get(job, {}).get("title", job.capitalize())

static func dept(job: String) -> String:
	return JOBS.get(job, {}).get("dept", "civilian")

static func is_head(job: String) -> bool:
	return JOBS.get(job, {}).get("head", false)

static func radio_channel(job: String) -> String:
	var d: String = dept(job)
	return Defs.DEPARTMENTS[d]["radio"]

static func head_of(dept_id: String) -> String:
	for k in JOBS:
		if JOBS[k]["dept"] == dept_id and JOBS[k].get("head", false):
			return k
	return "captain"

# ------------------------------------------------------------------ names (diverse; no real people)
const FIRST := ["Aldous", "Brynn", "Corvin", "Delphine", "Edric", "Fenna", "Gareth", "Halia", "Ivor", "Jessa", "Kestrel", "Lorin", "Maren", "Nolan", "Odessa",
	"Pell", "Quill", "Rhosyn", "Soren", "Tamsin", "Ulric", "Vesper", "Wren", "Xanthe", "Yorick", "Zephyr", "Alba", "Bram", "Cosima", "Dovan",
	"Elowen", "Finch", "Galen", "Hettie", "Isolde", "Jory", "Kit", "Lyra", "Mabon", "Nessa", "Orrin", "Perrin", "Rook", "Sabine", "Tarn",
	"Una", "Vane", "Willa", "Ysolde", "Zed", "Amara", "Bartholomew", "Cass", "Ines", "Hollis", "Ro", "Sasha", "Tove", "Marisol"]
const LAST := ["Windham", "Thorne", "Ashdown", "Cloudesley", "Fairweather", "Gale", "Highcastle", "Ironwood", "Kestrel", "Lanyard", "Merrow",
	"Northcott", "Oakhurst", "Pennyfeather", "Quillon", "Ravenscar", "Skye", "Tidewell", "Underhill", "Vanterpool", "Wexcombe", "Yardley", "Brackenridge",
	"Cobbold", "Dunmore", "Eastlake", "Foxglove", "Greystoke", "Hawthorne", "Inglenook", "Jessamy", "Keelson", "Lockwood", "Marlowe", "Nightingale",
	"Overton", "Pryce", "Rigby", "Stormont", "Tallow", "Upwood", "Varley", "Whitlock", "Frost", "Winter", "Halvorsen", "Aalto", "Birch"]

const SKIN_TONES := ["#f6d7bf", "#f0c8a8", "#e0ac8a", "#d49a74", "#c8906a", "#a8704a", "#8a5a3e", "#6a4430", "#5a3a2a", "#4a2e20"]
const HAIR_COLORS := ["#1a1418", "#2e1e16", "#4a2e1e", "#6a3a22", "#8a5a3a", "#b8864a", "#e8c85a", "#f0e0b0", "#c86a2a", "#a83a2a", "#8a8a8a", "#e8e8e8", "#3a4a8a", "#d84a8a"]
const EYE_COLORS := ["#3a2a1a", "#5a3a22", "#3a6ad8", "#4a9a4a", "#6a8a9a", "#8a6a3a", "#2a2a2a", "#7a4ae8"]
const HAIR_STYLES := ["short", "crew", "buzz", "sidepart", "spiky", "long", "bob", "ponytail", "bun", "braids", "afro", "mohawk",
	"undercut", "topknot", "curly", "messy", "pigtails", "slicked", "shoulder", "dreads", "bald"]
const FACIAL_STYLES := ["", "stubble", "mustache", "handlebar", "goatee", "beard", "fullbeard", "sideburns"]
const FACIAL := ["", "", "", "", "", "beard", "mustache", "goatee", "stubble", "fullbeard", "sideburns", "handlebar"]

static func random_appearance(rng: RandomNumberGenerator) -> Dictionary:
	var hair_c := Color(HAIR_COLORS[rng.randi() % 12])
	return {
		"skin": Color(SKIN_TONES[rng.randi() % SKIN_TONES.size()]),
		"hair": HAIR_STYLES[rng.randi() % HAIR_STYLES.size()],
		"hair_color": hair_c,
		"eyes": Color(EYE_COLORS[rng.randi() % EYE_COLORS.size()]),
		"facial": FACIAL[rng.randi() % FACIAL.size()],
		"underwear": Color.from_hsv(rng.randf(), 0.3, 0.4),
	}

static func random_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [FIRST[rng.randi() % FIRST.size()], LAST[rng.randi() % LAST.size()]]
