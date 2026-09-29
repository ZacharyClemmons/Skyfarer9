class_name Research extends RefCounted
## Station research output and tg's techweb (code/modules/research/techweb). Points come
## from the R&D servers (tg TECHWEB_SINGLE_SERVER_INCOME per second each), from
## scientists' experiments, and from feeding new things to the destructive analyzer.
## Researching a node unlocks its designs on the protolathe.

static var points := 0.0
static var experiments_run := 0
static var accidents := 0
static var researched := {} # node id -> true
static var analyzed := {} # proto -> true (the destructive analyzer only pays once per kind)

## tg TECHWEB_TIER_*_POINTS
const TIER := [0, 40, 80, 120, 160, 200]

## A slice of tg's techweb: the nodes whose designs exist here. Tier-0 nodes start researched.
const NODES := {
	"fundamental_sci": {"name": "Natural Philosophy", "tier": 0, "pre": [], "desc": "Establish the basics of research: ledger engines, consoles and the breaking bench."},
	"construction": {"name": "Construction", "tier": 0, "pre": [], "desc": "Tools and electronics for building and repairing the ship."},
	"atmos": {"name": "Air Works", "tier": 0, "pre": [], "desc": "Gas handling equipment: analyzers, cylinders and extinguishers."},
	"medbay_equip": {"name": "Sickbay Equipment", "tier": 0, "pre": [], "desc": "Essential medical tools to patch you up while sickbay is still intact."},
	"basic_arms": {"name": "Basic Arms", "tier": 0, "pre": [], "desc": "Ballistics can be unpredictable in a high wind."},
	"office_equip": {"name": "Office Equipment", "tier": 0, "pre": [], "desc": "Stationery, voice-links and cleaning supplies."},
	"cafeteria_equip": {"name": "Galley Equipment", "tier": 0, "pre": [], "desc": "Kitchen utensils."},
	"material_processing": {"name": "Material Processing", "tier": 0, "pre": [], "desc": "Refinement and alloying of raw materials."},
	"energy_manipulation": {"name": "Energy Manipulation", "tier": 1, "pre": ["construction"], "desc": "Harnessing the raw power of lightning arcs through sophisticated energy control methods."},
	"holographics": {"name": "Holographics", "tier": 2, "pre": ["energy_manipulation"], "desc": "Use of holographic technology for signage and barriers."},
	"gas_compression": {"name": "Gas Compression", "tier": 1, "pre": ["atmos"], "desc": "Highly pressurized gases hold potential for unlocking immense energy capabilities."},
	"plasma_control": {"name": "Controlled Plasma", "tier": 2, "pre": ["gas_compression", "energy_manipulation"], "desc": "Experiments with high-pressure gases and electricity resulting in crystallization and controlled plasma reactions."},
	"chem_synthesis": {"name": "Chemical Synthesis", "tier": 1, "pre": ["medbay_equip"], "desc": "Synthesizing complex chemicals from electricity and thin air... Don't ask how."},
	"sec_equip": {"name": "Watch Equipment", "tier": 1, "pre": ["basic_arms"], "desc": "Standard equipment used by the Watch."},
	"riot_supression": {"name": "Boarding Defence", "tier": 2, "pre": ["sec_equip"], "desc": "When the boarders are coming over the rail."},
	"explosives": {"name": "Explosives", "tier": 3, "pre": ["riot_supression"], "desc": "For once, intentional explosions."},
	"electric_weapons": {"name": "Electric Weaponry", "tier": 3, "pre": ["riot_supression"], "desc": "Energy-based weaponry."},
	"beam_weapons": {"name": "Advanced Beam Weaponry", "tier": 4, "pre": ["electric_weapons"], "desc": "So advanced, even engineers are baffled by its operational principles."},
	"sanitation": {"name": "Advanced Deck Care", "tier": 2, "pre": ["office_equip"], "desc": "Cleaning the ship with cutting-edge technology."},
	"genetics_tools": {"name": "Genetics Equipment", "tier": 1, "pre": ["medbay_equip"], "desc": "Sequence analyzers, DNA disks and upgraded scanner components."},
	"advanced_genetics": {"name": "Advanced Genetics Equipment", "tier": 3, "pre": ["genetics_tools", "chem_synthesis"], "desc": "High precision parts for low damage genetic sequencing."},
}

## tg design datums: materials in tg units (SHEET_MATERIAL_AMOUNT = 100 per sheet).
## "lathe": which lathes print it; protolathe designs need their "node" researched.
const DESIGNS := {
	"skill_station": {"proto": "skill_station", "mats": {"iron": 300, "glass": 100}, "lathe": ["protolathe"], "node": "advanced_genetics", "cat": "Genetics"},
	"chip_entrails": {"name": "Entrails Reader lesson card", "proto": "skillchip", "comps": {"skillchip": {"kind": "entrails_reader"}}, "mats": {"iron": 20, "glass": 20}, "lathe": ["protolathe"], "node": "genetics_tools", "cat": "Genetics"},
	"chip_musical": {"name": "Musical lesson card", "proto": "skillchip", "comps": {"skillchip": {"kind": "musical"}}, "mats": {"iron": 20, "glass": 20}, "lathe": ["protolathe"], "node": "genetics_tools", "cat": "Genetics"},
	"chip_adapter": {"name": "Useless Adapter lesson card", "proto": "skillchip", "comps": {"skillchip": {"kind": "useless_adapter"}}, "mats": {"iron": 20, "glass": 20}, "lathe": ["protolathe"], "node": "genetics_tools", "cat": "Genetics"},
	"chip_engineer": {"name": "Engineering Circuitry lesson card", "proto": "skillchip", "comps": {"skillchip": {"kind": "engineer"}}, "mats": {"iron": 20, "glass": 20}, "lathe": ["protolathe"], "node": "genetics_tools", "cat": "Genetics"},
	"chip_strength": {"name": "True Strength lesson card", "proto": "skillchip", "comps": {"skillchip": {"kind": "research_director"}}, "mats": {"iron": 20, "glass": 20}, "lathe": ["protolathe"], "node": "advanced_genetics", "cat": "Genetics"},
	"chip_matrix": {"name": "Taunt 2 Dodge lesson card", "proto": "skillchip", "comps": {"skillchip": {"kind": "matrix_taunt"}}, "mats": {"iron": 20, "glass": 20}, "lathe": ["protolathe"], "node": "advanced_genetics", "cat": "Genetics"},
	"sequence_scanner": {"proto": "sequence_scanner", "mats": {"iron": 50, "glass": 30}, "lathe": ["protolathe"], "node": "genetics_tools", "cat": "Genetics"},
	"dna_disk": {"proto": "dna_disk", "mats": {"iron": 10, "glass": 5}, "lathe": ["protolathe"], "node": "genetics_tools", "cat": "Genetics"},
	"scanner_laser_t2": {"name": "T2 micro-laser", "proto": "stock_part", "comps": {"stockpart": {"kind": "micro_laser", "tier": 2}}, "mats": {"iron": 50, "glass": 20}, "lathe": ["protolathe"], "node": "genetics_tools", "cat": "Genetics"},
	"scanner_bin_t2": {"name": "T2 matter bin", "proto": "stock_part", "comps": {"stockpart": {"kind": "matter_bin", "tier": 2}}, "mats": {"iron": 80, "glass": 20}, "lathe": ["protolathe"], "node": "genetics_tools", "cat": "Genetics"},
	"scanner_module_t2": {"name": "T2 scanning module", "proto": "stock_part", "comps": {"stockpart": {"kind": "scanning_module", "tier": 2}}, "mats": {"iron": 40, "glass": 40}, "lathe": ["protolathe"], "node": "genetics_tools", "cat": "Genetics"},
	"scanner_laser_t3": {"name": "T3 micro-laser", "proto": "stock_part", "comps": {"stockpart": {"kind": "micro_laser", "tier": 3}}, "mats": {"iron": 80, "glass": 40, "gold": 20}, "lathe": ["protolathe"], "node": "advanced_genetics", "cat": "Genetics"},
	"scanner_bin_t3": {"name": "T3 matter bin", "proto": "stock_part", "comps": {"stockpart": {"kind": "matter_bin", "tier": 3}}, "mats": {"iron": 120, "glass": 40, "gold": 20}, "lathe": ["protolathe"], "node": "advanced_genetics", "cat": "Genetics"},
	"scanner_module_t3": {"name": "T3 scanning module", "proto": "stock_part", "comps": {"stockpart": {"kind": "scanning_module", "tier": 3}}, "mats": {"iron": 60, "glass": 60, "gold": 20}, "lathe": ["protolathe"], "node": "advanced_genetics", "cat": "Genetics"},
	"scanner_laser_t4": {"name": "T4 micro-laser", "proto": "stock_part", "comps": {"stockpart": {"kind": "micro_laser", "tier": 4}}, "mats": {"iron": 100, "glass": 50, "gold": 40}, "lathe": ["protolathe"], "node": "advanced_genetics", "cat": "Genetics"},
	"scanner_bin_t4": {"name": "T4 matter bin", "proto": "stock_part", "comps": {"stockpart": {"kind": "matter_bin", "tier": 4}}, "mats": {"iron": 160, "glass": 50, "gold": 40}, "lathe": ["protolathe"], "node": "advanced_genetics", "cat": "Genetics"},
	"scanner_module_t4": {"name": "T4 scanning module", "proto": "stock_part", "comps": {"stockpart": {"kind": "scanning_module", "tier": 4}}, "mats": {"iron": 80, "glass": 80, "gold": 40}, "lathe": ["protolathe"], "node": "advanced_genetics", "cat": "Genetics"},
	# autolathe (tg autolathe/*.dm), always available there
	"wrench": {"proto": "wrench", "mats": {"iron": 15}, "lathe": ["autolathe", "protolathe"], "node": "construction", "cat": "Tools"},
	"crowbar": {"proto": "crowbar", "mats": {"iron": 5}, "lathe": ["autolathe", "protolathe"], "node": "construction", "cat": "Tools"},
	"screwdriver": {"proto": "screwdriver", "mats": {"iron": 8}, "lathe": ["autolathe", "protolathe"], "node": "construction", "cat": "Tools"},
	"wirecutters": {"proto": "wirecutters", "mats": {"iron": 8}, "lathe": ["autolathe", "protolathe"], "node": "construction", "cat": "Tools"},
	"welder": {"proto": "welder", "mats": {"iron": 7, "glass": 2}, "lathe": ["autolathe", "protolathe"], "node": "construction", "cat": "Tools"},
	"multitool": {"proto": "multitool", "mats": {"iron": 5, "glass": 2}, "lathe": ["autolathe", "protolathe"], "node": "construction", "cat": "Tools"},
	"cable_coil": {"proto": "cable_coil", "mats": {"iron": 5, "glass": 5}, "lathe": ["autolathe", "protolathe"], "node": "construction", "cat": "Tools", "amount": 5},
	"toolbox": {"proto": "toolbox", "mats": {"iron": 50}, "lathe": ["autolathe"], "cat": "Tools", "empty": true},
	"flashlight": {"proto": "flashlight", "mats": {"iron": 5, "glass": 2}, "lathe": ["autolathe", "protolathe"], "node": "construction", "cat": "Tools"},
	"t_scanner": {"proto": "t_scanner", "mats": {"iron": 3, "glass": 2}, "lathe": ["autolathe", "protolathe"], "node": "construction", "cat": "Tools"},
	"welding_helmet": {"proto": "welding_helmet", "mats": {"iron": 88, "glass": 40}, "lathe": ["autolathe", "protolathe"], "node": "energy_manipulation", "cat": "Tools"},
	"extinguisher": {"proto": "extinguisher", "mats": {"iron": 50}, "lathe": ["autolathe", "protolathe"], "node": "atmos", "cat": "Atmospherics"},
	"extinguisher_mini": {"proto": "extinguisher_mini", "mats": {"iron": 50, "glass": 40}, "lathe": ["protolathe"], "node": "atmos", "cat": "Atmospherics"},
	"gas_analyzer": {"proto": "gas_analyzer", "mats": {"iron": 3, "glass": 2}, "lathe": ["autolathe", "protolathe"], "node": "atmos", "cat": "Atmospherics"},
	"tank_o2": {"proto": "tank_o2", "mats": {"iron": 200}, "lathe": ["protolathe"], "node": "atmos", "cat": "Atmospherics", "empty": true},
	"tank_air": {"proto": "tank_air", "mats": {"iron": 50}, "lathe": ["autolathe", "protolathe"], "node": "gas_compression", "cat": "Atmospherics", "empty": true},
	"rpd": {"proto": "rpd", "mats": {"iron": 3750, "glass": 1875}, "lathe": ["protolathe"], "node": "plasma_control", "cat": "Atmospherics"},
	"rcd": {"proto": "rcd", "mats": {"iron": 3000, "glass": 1500}, "lathe": ["protolathe"], "node": "plasma_control", "cat": "Construction"},
	"rcd_ammo": {"proto": "rcd_ammo", "mats": {"iron": 600, "glass": 300}, "lathe": ["protolathe"], "node": "construction", "cat": "Construction"},
	"holofan": {"proto": "holofan", "mats": {"iron": 100, "glass": 50}, "lathe": ["protolathe"], "node": "holographics", "cat": "Atmospherics"},
	"generator": {"proto": "generator", "mats": {"iron": 500, "glass": 200, "plasma": 100}, "lathe": ["protolathe"], "node": "plasma_control", "cat": "Power"},
	"light_tube": {"proto": "light_tube", "mats": {"glass": 10}, "lathe": ["autolathe", "protolathe"], "node": "construction", "cat": "Construction"},
	"sheet_metal": {"proto": "sheet_metal", "mats": {"iron": 100}, "lathe": ["autolathe"], "cat": "Construction"},
	"sheet_glass": {"proto": "sheet_glass", "mats": {"glass": 100}, "lathe": ["autolathe"], "cat": "Construction"},
	"sheet_rglass": {"proto": "sheet_rglass", "mats": {"iron": 50, "glass": 100}, "lathe": ["autolathe", "protolathe"], "node": "material_processing", "cat": "Construction"},
	"rods": {"proto": "rods", "mats": {"iron": 50}, "lathe": ["autolathe"], "cat": "Construction", "amount": 2},
	"pickaxe": {"proto": "pickaxe", "mats": {"iron": 200}, "lathe": ["autolathe", "protolathe"], "node": "material_processing", "cat": "Mining"},
	"beaker": {"proto": "beaker", "mats": {"glass": 50}, "lathe": ["autolathe", "protolathe"], "node": "medbay_equip", "cat": "Medical"},
	"scalpel": {"proto": "scalpel", "mats": {"iron": 200, "glass": 50}, "lathe": ["autolathe", "protolathe"], "node": "medbay_equip", "cat": "Medical"},
	"hemostat": {"proto": "hemostat", "mats": {"iron": 250, "glass": 125}, "lathe": ["autolathe", "protolathe"], "node": "medbay_equip", "cat": "Medical"},
	"retractor": {"proto": "retractor", "mats": {"iron": 300, "glass": 150}, "lathe": ["autolathe", "protolathe"], "node": "medbay_equip", "cat": "Medical"},
	"cautery": {"proto": "cautery", "mats": {"iron": 125, "glass": 75}, "lathe": ["autolathe", "protolathe"], "node": "medbay_equip", "cat": "Medical"},
	"circular_saw": {"proto": "circular_saw", "mats": {"iron": 500, "glass": 300}, "lathe": ["autolathe", "protolathe"], "node": "medbay_equip", "cat": "Medical"},
	"health_analyzer": {"proto": "health_analyzer", "mats": {"iron": 50, "glass": 5}, "lathe": ["protolathe"], "node": "medbay_equip", "cat": "Medical"},
	"defib": {"proto": "defib", "mats": {"iron": 400, "glass": 200, "gold": 200}, "lathe": ["protolathe"], "node": "medbay_equip", "cat": "Medical"},
	"medipen": {"proto": "medipen", "mats": {"iron": 50, "glass": 20}, "lathe": ["protolathe"], "node": "chem_synthesis", "cat": "Medical"},
	"surgical_drapes": {"proto": "surgical_drapes", "mats": {"iron": 20}, "lathe": ["protolathe"], "node": "medbay_equip", "cat": "Medical"},
	"shell_beanbag": {"proto": "shell_beanbag", "mats": {"iron": 250}, "lathe": ["autolathe", "protolathe"], "node": "basic_arms", "cat": "Security", "amount": 6},
	"shell_rubbershot": {"proto": "shell_rubbershot", "mats": {"iron": 250}, "lathe": ["autolathe", "protolathe"], "node": "basic_arms", "cat": "Security", "amount": 6},
	"ammo_38_rubber": {"proto": "ammo_38_rubber", "mats": {"iron": 200}, "lathe": ["protolathe"], "node": "basic_arms", "cat": "Security", "amount": 6},
	"shell_buckshot": {"proto": "shell_buckshot", "mats": {"iron": 400}, "lathe": ["protolathe"], "node": "riot_supression", "cat": "Security", "amount": 6},
	"helmet_sec": {"proto": "helmet_sec", "mats": {"iron": 400, "glass": 100}, "lathe": ["protolathe"], "node": "sec_equip", "cat": "Security"},
	"armor_vest": {"proto": "armor_vest", "mats": {"iron": 800}, "lathe": ["protolathe"], "node": "sec_equip", "cat": "Security"},
	"hardhat": {"proto": "hardhat", "mats": {"iron": 200}, "lathe": ["autolathe", "protolathe"], "node": "construction", "cat": "Tools"},
	"handcuffs": {"proto": "handcuffs", "mats": {"iron": 50}, "lathe": ["autolathe", "protolathe"], "node": "riot_supression", "cat": "Security"},
	"pepperspray": {"proto": "pepperspray", "mats": {"iron": 100, "glass": 50}, "lathe": ["protolathe"], "node": "sec_equip", "cat": "Security"},
	"seclite": {"proto": "flashlight", "mats": {"iron": 25}, "lathe": ["protolathe"], "node": "sec_equip", "cat": "Security"},
	"flash": {"proto": "flash", "mats": {"iron": 30, "glass": 30}, "lathe": ["protolathe"], "node": "sec_equip", "cat": "Security"},
	"riot_shield": {"proto": "riot_shield", "mats": {"iron": 1000, "glass": 500}, "lathe": ["protolathe"], "node": "riot_supression", "cat": "Security"},
	"flashbang": {"proto": "flashbang", "mats": {"iron": 300, "glass": 100}, "lathe": ["protolathe"], "node": "explosives", "cat": "Security"},
	"smoke_grenade": {"proto": "smoke_grenade", "mats": {"iron": 300, "glass": 100}, "lathe": ["protolathe"], "node": "explosives", "cat": "Security"},
	"disabler": {"proto": "disabler", "mats": {"iron": 500, "glass": 300}, "lathe": ["protolathe"], "node": "electric_weapons", "cat": "Security"},
	"laser_gun": {"proto": "laser_gun", "mats": {"iron": 1000, "glass": 500, "gold": 250}, "lathe": ["protolathe"], "node": "beam_weapons", "cat": "Security"},
	"egun": {"proto": "egun", "mats": {"iron": 1000, "glass": 500, "gold": 300, "plasma": 200}, "lathe": ["protolathe"], "node": "beam_weapons", "cat": "Security"},
	"headset": {"proto": "headset", "mats": {"iron": 8}, "lathe": ["autolathe", "protolathe"], "node": "office_equip", "cat": "Service"},
	"bucket": {"proto": "bucket", "mats": {"iron": 20}, "lathe": ["autolathe", "protolathe"], "node": "office_equip", "cat": "Service"},
	"mop": {"proto": "mop", "mats": {"iron": 50}, "lathe": ["autolathe", "protolathe"], "node": "office_equip", "cat": "Service"},
	"pen": {"proto": "pen", "mats": {"iron": 10}, "lathe": ["autolathe", "protolathe"], "node": "office_equip", "cat": "Service"},
	"spray_bottle": {"proto": "spray_bottle", "mats": {"iron": 30, "glass": 20}, "lathe": ["protolathe"], "node": "sanitation", "cat": "Service"},
	"knife_kitchen": {"proto": "knife_kitchen", "mats": {"iron": 600}, "lathe": ["autolathe", "protolathe"], "node": "cafeteria_equip", "cat": "Service"},
}

## What the destructive analyzer pays out the first time it takes something apart.
const ANALYZE_POINTS := {"tool": 8.0, "medical": 12.0, "weapon": 20.0, "tank": 10.0, "material": 5.0, "chem": 10.0, "food": 2.0, "clothing": 4.0, "container": 4.0}
const ANALYZE_SPECIAL := {"ore_plasma": 25.0, "ore_cryo": 40.0, "ore_gold": 20.0, "sheet_plasma": 25.0, "defib": 40.0, "egun": 60.0, "laser_gun": 50.0, "disabler": 35.0, "flash": 15.0, "health_analyzer": 20.0, "gas_analyzer": 15.0, "multitool": 15.0, "glowstick": 10.0, "medipen": 15.0}

static func _ensure_base() -> void:
	if researched.is_empty():
		for id in NODES:
			if NODES[id]["tier"] == 0:
				researched[id] = true

static func is_researched(node: String) -> bool:
	_ensure_base()
	return researched.has(node)

static func cost(node: String) -> float:
	return float(TIER[NODES[node]["tier"]])

static func available(node: String) -> bool:
	_ensure_base()
	if researched.has(node):
		return false
	for p in NODES[node]["pre"]:
		if not researched.has(p):
			return false
	return true

static func research(node: String, by: Entity) -> bool:
	if not available(node) or points < cost(node):
		return false
	points -= cost(node)
	researched[node] = true
	var n := designs_of(node).size()
	StationAlerts.radio_system("R&D Console", "Science", "Researched %s. %d new design%s available on the protolathe." % [NODES[node]["name"], n, "" if n == 1 else "s"], {"type": "research", "key": "research:" + node, "cell": by.cell if by else Vector2i.ZERO, "severity": 0})
	return true

static func designs_of(node: String) -> Array:
	var out := []
	for id in DESIGNS:
		if DESIGNS[id].get("node", "") == node and "protolathe" in DESIGNS[id]["lathe"]:
			out.append(id)
	return out

## Designs a lathe of this kind can print right now.
static func designs_for(lathe: String) -> Array:
	_ensure_base()
	var out := []
	for id in DESIGNS:
		var d: Dictionary = DESIGNS[id]
		if not lathe in d["lathe"]:
			continue
		if lathe == "protolathe" and not researched.has(d.get("node", "")):
			continue
		out.append(id)
	return out

static func analyze_value(item: Entity) -> float:
	if analyzed.has(item.proto):
		return 0.0
	if ANALYZE_SPECIAL.has(item.proto):
		return ANALYZE_SPECIAL[item.proto]
	var it: CItem = item.c(&"item")
	return ANALYZE_POINTS.get(it.category if it else "", 3.0)

## tg SSresearch: each powered R&D server adds TECHWEB_SINGLE_SERVER_INCOME a second.
static func tick_servers(dt: float) -> void:
	for s in Game.all_with(&"machine"):
		if s.proto == "server_rack" and s.c(&"machine").operable():
			points += 1.0 * dt
