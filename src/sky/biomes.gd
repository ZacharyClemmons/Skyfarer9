class_name Biomes extends RefCounted
## What an island is made of. Every floating island in the Cloudsea picks a biome, and
## the biome decides its ground, its rock, what grows on it, what hunts on it, what it
## smells like and what you can dig out of it.
##
## A biome entry:
##   name       display name ("Verdance")
##   noun       what a single island of it is called ("meadow isle")
##   ground     [[turf, weight], ...] surface turf mix, chosen per tile by a noise field
##   edge       turf ringing the island where it breaks off into sky (usually its rock)
##   rock       the stone the island's spine and cliffs are cut from
##   ores       [[turf, weight], ...] veins salted through the rock
##   under      turf of the island's underside crust (seen from below / when it shears)
##   flora      [[proto, per-100-tiles], ...] props scattered on the surface
##   fauna      [[mob id, weight], ...] the biome's native creatures
##   night      extra fauna that only come out after dusk
##   density    0..1 how crowded the surface is
##   hazard     0..1 baseline danger, drives pack sizes and the director
##   ambient    Color the biome pushes into the lightmap at ground level
##   fog        Color + strength of the haze that sits over it
##   temp       air temperature offset in K against the sky region's own
##   gas        [gas index, moles per open tile] a gas the island leaks, or []
##   water      0..1 chance of pools
##   sites      [[site id, weight], ...] structures that can be stamped on it
##   sound      ambience key
##   wind       how hard the aether wind blows across it (moves airships, staggers people)

const B_VERDANCE := "verdance"
const B_THORNWILD := "thornwild"
const B_CINDERPEAK := "cinderpeak"
const B_HOARFROST := "hoarfrost"
const B_DUNEBANK := "dunebank"
const B_BONEYARD := "boneyard"
const B_SALTMERE := "saltmere"
const B_GLASSWASTE := "glasswaste"
const B_FENMOOR := "fenmoor"
const B_CRAGSPIRE := "cragspire"
const B_BLOOMROT := "bloomrot"
const B_HEARTHMOSS := "hearthmoss"
const B_CHALKDOWNS := "chalkdowns"
const B_TANGLEREEF := "tanglereef"
const B_RUSTFALL := "rustfall"
const B_MIRRORMERE := "mirrormere"
const B_EMBERGLASS := "emberglass"
const B_STORMCROWN := "stormcrown"
const B_VERGEGLOOM := "vergegloom"
const B_ASHVEIL := "ashveil"

static var ALL := {
	# ---------------------------------------------------------------- the green shelf
	B_VERDANCE: {
		"name": "Verdance", "noun": "meadow isle",
		"ground": [[Defs.T_GRASS, 62], [Defs.T_GRASS_TALL, 18], [Defs.T_DIRT, 14], [Defs.T_STONE, 6]],
		"edge": Defs.T_DIRT, "rock": Defs.T_ROCK, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_IRON, 40], [Defs.T_ROCK_AETHER, 22], [Defs.T_ROCK_GOLD, 6]],
		"flora": [["sky_oak", 5.0], ["bush_berry", 4.0], ["boulder", 1.5], ["wildflowers", 6.0], ["tall_reed", 2.0]],
		"fauna": [["skyhare", 34], ["aether_doe", 20], ["glidewing", 16], ["meadow_crawler", 10]],
		"night": [["dusk_moth", 22], ["hollow_stag", 5]],
		"density": 0.5, "hazard": 0.12,
		"ambient": Color(0.62, 0.72, 0.58), "fog": Color(0.78, 0.86, 0.92, 0.05),
		"temp": 2.0, "gas": [], "water": 0.35,
		"sites": [["shepherd_camp", 30], ["standing_stones", 18], ["wreck_small", 14], ["shrine", 10]],
		"sound": "meadow", "wind": 0.4,
	},
	B_THORNWILD: {
		"name": "Thornwild", "noun": "canopy isle",
		"ground": [[Defs.T_MOSS, 48], [Defs.T_GRASS, 22], [Defs.T_MUD, 16], [Defs.T_DIRT, 14]],
		"edge": Defs.T_MOSS, "rock": Defs.T_ROCK, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_IRON, 30], [Defs.T_ROCK_AETHER, 26], [Defs.T_ROCK_CRYSTAL, 10]],
		"flora": [["thorn_tree", 7.0], ["vine_curtain", 5.0], ["spore_pod", 3.5], ["bush_berry", 3.0], ["fern_giant", 5.0]],
		"fauna": [["thorn_mantis", 26], ["canopy_stalker", 14], ["spore_hopper", 22], ["vine_lasher", 12]],
		"night": [["night_bloom", 18], ["throat_singer", 6]],
		"density": 0.85, "hazard": 0.40,
		"ambient": Color(0.40, 0.58, 0.38), "fog": Color(0.55, 0.72, 0.52, 0.16),
		"temp": 5.0, "gas": [], "water": 0.5,
		"sites": [["overgrown_ruin", 32], ["hive_tree", 20], ["wreck_small", 12], ["poacher_camp", 12]],
		"sound": "jungle", "wind": 0.15,
	},
	B_FENMOOR: {
		"name": "Fenmoor", "noun": "bog isle",
		"ground": [[Defs.T_MUD, 44], [Defs.T_MOSS, 26], [Defs.T_WATER, 20], [Defs.T_DIRT, 10]],
		"edge": Defs.T_MUD, "rock": Defs.T_ROCK, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_SULFUR, 38], [Defs.T_ROCK_IRON, 24], [Defs.T_ROCK_AETHER, 12]],
		"flora": [["bog_stump", 5.0], ["reed_bed", 7.0], ["gas_vent", 2.5], ["fen_lantern", 2.0]],
		"fauna": [["bog_lurker", 24], ["fen_leech", 26], ["mire_hound", 12], ["drowned_thing", 8]],
		"night": [["will_o_wisp", 20], ["drowned_thing", 12]],
		"density": 0.6, "hazard": 0.45,
		"ambient": Color(0.42, 0.50, 0.46), "fog": Color(0.58, 0.66, 0.62, 0.30),
		"temp": 1.0, "gas": [Defs.G_MIASMA, 0.9], "water": 0.9,
		"sites": [["sunken_barge", 26], ["peat_cutters", 20], ["overgrown_ruin", 16], ["shrine", 10]],
		"sound": "bog", "wind": 0.1,
	},
	B_BLOOMROT: {
		"name": "Bloomrot", "noun": "fungal isle",
		"ground": [[Defs.T_MOSS, 52], [Defs.T_DIRT, 24], [Defs.T_MUD, 16], [Defs.T_BONEDUST, 8]],
		"edge": Defs.T_MOSS, "rock": Defs.T_ROCK, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_SULFUR, 30], [Defs.T_ROCK_CRYSTAL, 18], [Defs.T_ROCK_AETHER, 14]],
		"flora": [["cap_tower", 8.0], ["spore_pod", 6.0], ["mycelium_mat", 9.0], ["puffball", 4.0]],
		"fauna": [["spore_hopper", 24], ["myconid", 20], ["rot_crawler", 18], ["bloom_host", 10]],
		"night": [["bloom_host", 18], ["spore_cloud", 14]],
		"density": 0.9, "hazard": 0.5,
		"ambient": Color(0.52, 0.44, 0.58), "fog": Color(0.66, 0.56, 0.72, 0.22),
		"temp": 3.0, "gas": [Defs.G_MIASMA, 1.6], "water": 0.3,
		"sites": [["spore_heart", 30], ["overgrown_ruin", 22], ["wreck_small", 14]],
		"sound": "fungal", "wind": 0.1,
	},
	# ---------------------------------------------------------------- dry and burning
	B_CINDERPEAK: {
		"name": "Cinderpeak", "noun": "burning isle",
		"ground": [[Defs.T_ASH, 46], [Defs.T_BASALT, 34], [Defs.T_STONE, 14], [Defs.T_LAVA, 6]],
		"edge": Defs.T_BASALT, "rock": Defs.T_ROCK, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_SULFUR, 38], [Defs.T_ROCK_PLASMA, 26], [Defs.T_ROCK_IRON, 18], [Defs.T_ROCK_GOLD, 8]],
		"flora": [["cinder_spire", 4.0], ["lava_crust", 3.0], ["obsidian_shard", 3.5], ["fumarole", 2.5]],
		"fauna": [["cinder_salamander", 26], ["ash_wraith", 16], ["magma_tick", 22], ["forge_golem", 6]],
		"night": [["ash_wraith", 24]],
		"density": 0.35, "hazard": 0.65,
		"ambient": Color(0.72, 0.42, 0.30), "fog": Color(0.55, 0.34, 0.28, 0.24),
		"temp": 38.0, "gas": [Defs.G_CO2, 1.2], "water": 0.0,
		"sites": [["forge_ruin", 30], ["plasma_drill", 22], ["wreck_burnt", 18], ["shrine", 8]],
		"sound": "volcanic", "wind": 0.5,
	},
	B_ASHVEIL: {
		"name": "Ashveil", "noun": "cinder drift",
		"ground": [[Defs.T_ASH, 66], [Defs.T_BASALT, 20], [Defs.T_BONEDUST, 14]],
		"edge": Defs.T_ASH, "rock": Defs.T_ROCK, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_SULFUR, 30], [Defs.T_ROCK_PLASMA, 20], [Defs.T_ROCK_IRON, 20]],
		"flora": [["ash_pillar", 5.0], ["burnt_stump", 4.0], ["fumarole", 2.0]],
		"fauna": [["ash_wraith", 28], ["cinder_salamander", 14], ["dust_swimmer", 20]],
		"night": [["ash_wraith", 30], ["the_quiet", 4]],
		"density": 0.25, "hazard": 0.55,
		"ambient": Color(0.54, 0.46, 0.42), "fog": Color(0.50, 0.44, 0.40, 0.42),
		"temp": 14.0, "gas": [Defs.G_SMOKE, 0.35], "water": 0.0,
		"sites": [["buried_town", 28], ["wreck_burnt", 24], ["forge_ruin", 14]],
		"sound": "ashfall", "wind": 0.75,
	},
	B_DUNEBANK: {
		"name": "Dunebank", "noun": "sand isle",
		"ground": [[Defs.T_SAND, 72], [Defs.T_STONE, 16], [Defs.T_SALT, 12]],
		"edge": Defs.T_SAND, "rock": Defs.T_ROCK, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_CRYSTAL, 32], [Defs.T_ROCK_GOLD, 18], [Defs.T_ROCK_IRON, 26], [Defs.T_ROCK_AETHER, 12]],
		"flora": [["dune_bone", 3.0], ["cactus_sky", 4.0], ["sand_arch", 2.0], ["glass_shard", 3.5]],
		"fauna": [["sand_diver", 24], ["glass_beetle", 26], ["dune_stalker", 12], ["mirage_walker", 8]],
		"night": [["dune_stalker", 22], ["cold_thing", 10]],
		"density": 0.2, "hazard": 0.35,
		"ambient": Color(0.82, 0.72, 0.52), "fog": Color(0.86, 0.78, 0.60, 0.14),
		"temp": 22.0, "gas": [], "water": 0.05,
		"sites": [["buried_town", 30], ["caravan_wreck", 24], ["standing_stones", 14], ["glass_kiln", 12]],
		"sound": "desert", "wind": 0.85,
	},
	B_SALTMERE: {
		"name": "Saltmere", "noun": "brine isle",
		"ground": [[Defs.T_SALT, 50], [Defs.T_WATER, 26], [Defs.T_SAND, 16], [Defs.T_STONE, 8]],
		"edge": Defs.T_SALT, "rock": Defs.T_ROCK, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_CRYSTAL, 40], [Defs.T_ROCK_CRYO, 18], [Defs.T_ROCK_IRON, 16]],
		"flora": [["salt_pillar", 5.0], ["brine_pool", 4.0], ["crust_shelf", 3.0]],
		"fauna": [["brine_walker", 24], ["salt_crab", 26], ["mere_singer", 10], ["glass_beetle", 14]],
		"night": [["mere_singer", 20], ["pale_swimmer", 10]],
		"density": 0.3, "hazard": 0.3,
		"ambient": Color(0.78, 0.82, 0.86), "fog": Color(0.88, 0.92, 0.95, 0.18),
		"temp": 6.0, "gas": [], "water": 0.8,
		"sites": [["salt_works", 30], ["sunken_barge", 22], ["shrine", 14]],
		"sound": "brine", "wind": 0.45,
	},
	# ---------------------------------------------------------------- cold and high
	B_HOARFROST: {
		"name": "Hoarfrost", "noun": "frost isle",
		"ground": [[Defs.T_SNOW, 54], [Defs.T_DEEPSNOW, 20], [Defs.T_ICE, 16], [Defs.T_PACKED, 10]],
		"edge": Defs.T_ICE, "rock": Defs.T_ROCK, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_CRYO, 38], [Defs.T_ROCK_IRON, 26], [Defs.T_ROCK_AETHER, 16], [Defs.T_ROCK_CRYSTAL, 10]],
		"flora": [["frost_pine", 5.0], ["ice_spire", 3.5], ["snow_drift", 6.0], ["frozen_carcass", 1.2]],
		"fauna": [["frost_wolf", 22], ["ice_mite", 26], ["rime_stalker", 12], ["snow_lurker", 14]],
		"night": [["rime_stalker", 24], ["cold_thing", 12]],
		"density": 0.35, "hazard": 0.45,
		"ambient": Color(0.58, 0.68, 0.84), "fog": Color(0.80, 0.88, 0.98, 0.22),
		"temp": -42.0, "gas": [], "water": 0.1,
		"sites": [["frozen_camp", 30], ["wreck_frozen", 22], ["standing_stones", 16], ["ice_vault", 10]],
		"sound": "blizzard", "wind": 0.8,
	},
	B_CRAGSPIRE: {
		"name": "Cragspire", "noun": "crag",
		"ground": [[Defs.T_STONE, 66], [Defs.T_BASALT, 18], [Defs.T_DIRT, 10], [Defs.T_MOSS, 6]],
		"edge": Defs.T_STONE, "rock": Defs.T_ROCK, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_AETHER, 40], [Defs.T_ROCK_IRON, 28], [Defs.T_ROCK_GOLD, 14], [Defs.T_ROCK_CRYSTAL, 10]],
		"flora": [["boulder", 6.0], ["wind_sculpt", 4.0], ["eyrie_nest", 2.0], ["cliff_moss", 3.0]],
		"fauna": [["crag_gargoyle", 18], ["updraft_raptor", 24], ["stone_tick", 20], ["quarry_hulk", 8]],
		"night": [["crag_gargoyle", 26]],
		"density": 0.25, "hazard": 0.4,
		"ambient": Color(0.66, 0.66, 0.70), "fog": Color(0.82, 0.86, 0.92, 0.10),
		"temp": -8.0, "gas": [], "water": 0.1,
		"sites": [["aether_mine", 34], ["watchtower", 20], ["wreck_small", 14], ["standing_stones", 12]],
		"sound": "highwind", "wind": 1.0,
	},
	B_GLASSWASTE: {
		"name": "Glasswaste", "noun": "prism isle",
		"ground": [[Defs.T_SALT, 38], [Defs.T_STONE, 30], [Defs.T_SAND, 20], [Defs.T_BASALT, 12]],
		"edge": Defs.T_SALT, "rock": Defs.T_ROCK_CRYSTAL, "under": Defs.T_ROCK_CRYSTAL,
		"ores": [[Defs.T_ROCK_CRYSTAL, 58], [Defs.T_ROCK_AETHER, 22], [Defs.T_ROCK_GOLD, 10]],
		"flora": [["glass_tree", 6.0], ["prism_shard", 7.0], ["refraction_pool", 2.0]],
		"fauna": [["prism_mite", 28], ["glass_beetle", 20], ["refractor", 14], ["shatterling", 12]],
		"night": [["refractor", 26], ["the_quiet", 6]],
		"density": 0.45, "hazard": 0.55,
		"ambient": Color(0.74, 0.80, 0.92), "fog": Color(0.86, 0.90, 1.00, 0.16),
		"temp": -4.0, "gas": [], "water": 0.15,
		"sites": [["glass_kiln", 28], ["prism_array", 24], ["wreck_small", 14], ["shrine", 10]],
		"sound": "chimes", "wind": 0.5,
	},
	# ---------------------------------------------------------------- the near sky
	B_HEARTHMOSS: {
		"name": "Hearthmoss", "noun": "kindly isle",
		"ground": [[Defs.T_MOSS, 44], [Defs.T_GRASS, 34], [Defs.T_DIRT, 14], [Defs.T_STONE, 8]],
		"edge": Defs.T_MOSS, "rock": Defs.T_ROCK, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_IRON, 40], [Defs.T_ROCK_AETHER, 18], [Defs.T_ROCK_SULFUR, 10]],
		"flora": [["hearth_tree", 6.0], ["bush_berry", 6.0], ["wildflowers", 8.0], ["moss_bed", 5.0],
			["sky_oak", 3.0], ["tall_reed", 3.0]],
		"fauna": [["skyhare", 34], ["moss_shrike", 18], ["aether_doe", 16], ["hearth_beetle", 22]],
		"night": [["dusk_moth", 24], ["lamp_vole", 16]],
		"density": 0.55, "hazard": 0.06,
		"ambient": Color(0.66, 0.74, 0.60), "fog": Color(0.80, 0.88, 0.92, 0.04),
		"temp": 4.0, "gas": [], "water": 0.4,
		"sites": [["shepherd_camp", 32], ["wayhouse", 24], ["standing_stones", 14], ["shrine", 12], ["wreck_small", 10]],
		"sound": "meadow", "wind": 0.3,
	},
	B_CHALKDOWNS: {
		"name": "Chalkdowns", "noun": "chalk isle",
		"ground": [[Defs.T_GRASS, 40], [Defs.T_SALT, 26], [Defs.T_STONE, 22], [Defs.T_DIRT, 12]],
		"edge": Defs.T_SALT, "rock": Defs.T_ROCK, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_IRON, 34], [Defs.T_ROCK_CRYSTAL, 22], [Defs.T_ROCK_AETHER, 16]],
		"flora": [["chalk_figure", 3.0], ["wildflowers", 7.0], ["tall_reed", 4.0], ["boulder", 5.0],
			["wind_sculpt", 3.0]],
		"fauna": [["skyhare", 26], ["downs_ram", 20], ["chalk_hopper", 22], ["updraft_raptor", 10]],
		"night": [["lamp_vole", 20], ["chalk_wight", 8]],
		"density": 0.3, "hazard": 0.14,
		"ambient": Color(0.82, 0.84, 0.78), "fog": Color(0.90, 0.92, 0.94, 0.06),
		"temp": 0.0, "gas": [], "water": 0.15,
		"sites": [["chalk_figures", 30], ["wayhouse", 22], ["standing_stones", 20], ["wreck_small", 14]],
		"sound": "highwind", "wind": 0.6,
	},
	B_TANGLEREEF: {
		"name": "Tanglereef", "noun": "reef isle",
		"ground": [[Defs.T_MOSS, 36], [Defs.T_STONE, 26], [Defs.T_WATER, 20], [Defs.T_SAND, 18]],
		"edge": Defs.T_STONE, "rock": Defs.T_ROCK_CRYSTAL, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_CRYSTAL, 34], [Defs.T_ROCK_AETHER, 30], [Defs.T_ROCK_IRON, 16]],
		"flora": [["reef_fan", 8.0], ["aether_polyp", 6.0], ["tide_bell", 4.0], ["glass_tree", 3.0]],
		"fauna": [["reef_drifter", 24], ["polyp_swarm", 26], ["tanglemaw", 14], ["glass_beetle", 16]],
		"night": [["lantern_medusa", 22], ["tanglemaw", 14]],
		"density": 0.75, "hazard": 0.42,
		"ambient": Color(0.52, 0.70, 0.74), "fog": Color(0.66, 0.84, 0.88, 0.16),
		"temp": 3.0, "gas": [], "water": 0.65,
		"sites": [["reef_shrine", 28], ["sunken_barge", 24], ["overgrown_ruin", 16], ["wreck_small", 14]],
		"sound": "chimes", "wind": 0.35,
	},
	B_RUSTFALL: {
		"name": "Rustfall", "noun": "wreck field",
		"ground": [[Defs.T_GRAVEL, 34], [Defs.T_DIRT, 26], [Defs.T_ASH, 22], [Defs.T_STONE, 18]],
		"edge": Defs.T_GRAVEL, "rock": Defs.T_ROCK, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_IRON, 48], [Defs.T_ROCK_SULFUR, 22], [Defs.T_ROCK_AETHER, 18]],
		"flora": [["rust_spar", 7.0], ["hull_plate_heap", 6.0], ["burnt_stump", 4.0], ["boulder", 4.0]],
		"fauna": [["rust_crawler", 26], ["scrap_hound", 18], ["magnet_tick", 24], ["ironjaw", 10]],
		"night": [["hollow_crewman", 22], ["scrap_hound", 16]],
		"density": 0.45, "hazard": 0.52,
		"ambient": Color(0.62, 0.52, 0.44), "fog": Color(0.70, 0.60, 0.52, 0.18),
		"temp": 2.0, "gas": [Defs.G_SMOKE, 0.15], "water": 0.1,
		"sites": [["breakers_yard", 34], ["wreck_small", 26], ["wreck_burnt", 20], ["forge_ruin", 12]],
		"sound": "hollow", "wind": 0.5,
	},
	B_MIRRORMERE: {
		"name": "Mirrormere", "noun": "mirror isle",
		"ground": [[Defs.T_WATER, 36], [Defs.T_SALT, 28], [Defs.T_STONE, 22], [Defs.T_SAND, 14]],
		"edge": Defs.T_SALT, "rock": Defs.T_ROCK_CRYSTAL, "under": Defs.T_ROCK_CRYSTAL,
		"ores": [[Defs.T_ROCK_CRYSTAL, 52], [Defs.T_ROCK_AETHER, 26], [Defs.T_ROCK_GOLD, 10]],
		"flora": [["mirror_pool", 6.0], ["prism_shard", 6.0], ["glass_tree", 4.0], ["refraction_pool", 4.0]],
		"fauna": [["mirror_walker", 18], ["prism_mite", 26], ["reflection", 12], ["refractor", 16]],
		"night": [["reflection", 26], ["the_quiet", 6]],
		"density": 0.4, "hazard": 0.6,
		"ambient": Color(0.78, 0.84, 0.92), "fog": Color(0.88, 0.94, 1.00, 0.14),
		"temp": -6.0, "gas": [], "water": 0.85,
		"sites": [["prism_array", 30], ["mirror_hall", 26], ["ice_vault", 14], ["shrine", 10]],
		"sound": "chimes", "wind": 0.4,
	},
	B_EMBERGLASS: {
		"name": "Emberglass", "noun": "ember isle",
		"ground": [[Defs.T_BASALT, 38], [Defs.T_ASH, 28], [Defs.T_SALT, 18], [Defs.T_LAVA, 8], [Defs.T_STONE, 8]],
		"edge": Defs.T_BASALT, "rock": Defs.T_ROCK_CRYSTAL, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_PLASMA, 34], [Defs.T_ROCK_CRYSTAL, 28], [Defs.T_ROCK_GOLD, 20], [Defs.T_ROCK_SULFUR, 18]],
		"flora": [["ember_spire", 6.0], ["obsidian_shard", 5.0], ["glass_tree", 4.0], ["fumarole", 3.0]],
		"fauna": [["emberling", 24], ["glass_salamander", 18], ["slagborn", 12], ["cinder_salamander", 16]],
		"night": [["slagborn", 24], ["ash_wraith", 18]],
		"density": 0.35, "hazard": 0.72,
		"ambient": Color(0.78, 0.50, 0.38), "fog": Color(0.62, 0.40, 0.34, 0.20),
		"temp": 44.0, "gas": [Defs.G_CO2, 1.0], "water": 0.0,
		"sites": [["glass_kiln", 30], ["forge_ruin", 26], ["plasma_drill", 20], ["wreck_burnt", 14]],
		"sound": "volcanic", "wind": 0.55,
	},
	B_STORMCROWN: {
		"name": "Stormcrown", "noun": "storm isle",
		"ground": [[Defs.T_STONE, 40], [Defs.T_BASALT, 24], [Defs.T_GRAVEL, 20], [Defs.T_MOSS, 16]],
		"edge": Defs.T_STONE, "rock": Defs.T_ROCK_AETHER, "under": Defs.T_ROCK_AETHER,
		"ores": [[Defs.T_ROCK_AETHER, 58], [Defs.T_ROCK_CRYSTAL, 22], [Defs.T_ROCK_GOLD, 12]],
		"flora": [["lightning_tree", 5.0], ["storm_spire", 6.0], ["fulgurite", 5.0], ["wind_sculpt", 4.0]],
		"fauna": [["stormcaller", 16], ["charge_hound", 20], ["arc_mite", 26], ["thunderhead_ray", 12]],
		"night": [["stormcaller", 22], ["cold_thing", 10]],
		"density": 0.3, "hazard": 0.8,
		"ambient": Color(0.54, 0.62, 0.82), "fog": Color(0.60, 0.68, 0.86, 0.26),
		"temp": -18.0, "gas": [], "water": 0.2,
		"sites": [["lightning_farm", 32], ["aether_mine", 26], ["watchtower", 16], ["prism_array", 12]],
		"sound": "highwind", "wind": 1.3,
	},
	B_VERGEGLOOM: {
		"name": "Vergegloom", "noun": "lightless isle",
		"ground": [[Defs.T_BONEDUST, 32], [Defs.T_ASH, 28], [Defs.T_MUD, 22], [Defs.T_STONE, 18]],
		"edge": Defs.T_BONEDUST, "rock": Defs.T_ROCK, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_AETHER, 42], [Defs.T_ROCK_GOLD, 22], [Defs.T_ROCK_CRYSTAL, 18], [Defs.T_ROCK_SULFUR, 14]],
		"flora": [["gloom_stalk", 7.0], ["pale_fungus", 6.0], ["marrow_well", 3.0], ["bone_pile", 5.0]],
		"fauna": [["gloomstalker", 18], ["pale_swarm", 24], ["sightless", 14], ["the_quiet", 8]],
		"night": [["the_quiet", 20], ["sightless", 22], ["gravebound", 14]],
		"density": 0.5, "hazard": 0.95,
		"ambient": Color(0.26, 0.24, 0.32), "fog": Color(0.20, 0.20, 0.28, 0.44),
		"temp": -28.0, "gas": [Defs.G_MIASMA, 1.4], "water": 0.15,
		"sites": [["ossuary", 30], ["sunless_vault", 28], ["buried_town", 18], ["shrine", 10]],
		"sound": "hollow", "wind": 0.2,
	},
	B_BONEYARD: {
		"name": "Boneyard", "noun": "carcass isle",
		"ground": [[Defs.T_BONEDUST, 48], [Defs.T_DIRT, 22], [Defs.T_STONE, 18], [Defs.T_ASH, 12]],
		"edge": Defs.T_BONEDUST, "rock": Defs.T_ROCK, "under": Defs.T_ROCK,
		"ores": [[Defs.T_ROCK_IRON, 26], [Defs.T_ROCK_SULFUR, 22], [Defs.T_ROCK_AETHER, 30], [Defs.T_ROCK_GOLD, 12]],
		"flora": [["rib_arch", 6.0], ["skull_huge", 2.0], ["bone_pile", 7.0], ["marrow_well", 1.5]],
		"fauna": [["carrion_crawler", 24], ["marrow_moth", 22], ["bone_picker", 18], ["gravebound", 10]],
		"night": [["gravebound", 26], ["the_quiet", 8]],
		"density": 0.4, "hazard": 0.6,
		"ambient": Color(0.62, 0.58, 0.54), "fog": Color(0.72, 0.68, 0.64, 0.20),
		"temp": -2.0, "gas": [Defs.G_MIASMA, 0.7], "water": 0.05,
		"sites": [["bone_harvesters", 30], ["ossuary", 24], ["wreck_small", 16], ["shrine", 10]],
		"sound": "hollow", "wind": 0.35,
	},
}

## Which biomes can appear in a given altitude band (0..4, see Defs.ALT_BANDS). Altitude
## decides the flavour of a sky: the Deep is wet and rotten, the Anvil is glass and stone.
static var BY_BAND := {
	0: [B_FENMOOR, B_BLOOMROT, B_BONEYARD, B_THORNWILD, B_VERGEGLOOM, B_RUSTFALL],
	# The outer rings of a low sky still carry the strange biomes: tier gates them out of
	# the near rings, so a storm isle in the Shelf is something you only meet after an
	# hour of flying, which is exactly when it should happen.
	1: [B_HEARTHMOSS, B_VERDANCE, B_CHALKDOWNS, B_THORNWILD, B_FENMOOR, B_CINDERPEAK,
		B_SALTMERE, B_BLOOMROT, B_DUNEBANK, B_TANGLEREEF, B_RUSTFALL, B_BONEYARD,
		B_MIRRORMERE, B_EMBERGLASS, B_STORMCROWN, B_VERGEGLOOM],
	2: [B_VERDANCE, B_CHALKDOWNS, B_CRAGSPIRE, B_DUNEBANK, B_HOARFROST, B_CINDERPEAK,
		B_GLASSWASTE, B_BONEYARD, B_ASHVEIL, B_TANGLEREEF, B_MIRRORMERE, B_RUSTFALL,
		B_EMBERGLASS, B_STORMCROWN, B_VERGEGLOOM],
	3: [B_CRAGSPIRE, B_HOARFROST, B_GLASSWASTE, B_ASHVEIL, B_BONEYARD, B_MIRRORMERE,
		B_EMBERGLASS, B_STORMCROWN],
	4: [B_GLASSWASTE, B_CRAGSPIRE, B_HOARFROST, B_STORMCROWN, B_VERGEGLOOM, B_EMBERGLASS, B_MIRRORMERE],
}

## How far out a biome belongs. This is the *other* axis, and it is the one the player
## actually feels: the region is a set of rings round the home port, and the further out
## you fly the worse the neighbourhood and the better the loot. A biome's tier is the
## earliest ring it is allowed to appear in.
##
## Keeping tier separate from altitude band is what stops the world being one straight
## line. A Hoarfrost isle in the near Reaches is a cold, manageable place; the same biome
## four rings out is a cold place with something in it.
const TIER_OF := {
	B_HEARTHMOSS: 0, B_VERDANCE: 0, B_CHALKDOWNS: 0,
	B_SALTMERE: 1, B_DUNEBANK: 1, B_THORNWILD: 1, B_FENMOOR: 1, B_RUSTFALL: 1,
	B_BLOOMROT: 2, B_CRAGSPIRE: 2, B_HOARFROST: 2, B_TANGLEREEF: 2, B_GLASSWASTE: 2,
	B_CINDERPEAK: 2, B_BONEYARD: 3, B_ASHVEIL: 3, B_MIRRORMERE: 3, B_EMBERGLASS: 3,
	B_STORMCROWN: 4, B_VERGEGLOOM: 4,
}

## What each ring is called, and what it means. Names go on the chart and in the log, so
## "I am going out to the Long Sky" is a sentence a player can say and mean.
const RING_NAMES = ["the Home Reach", "the Nearing", "the Long Sky", "the Outer Dark", "the Rim"]
const RING_BLURB = [
	"Charted, patrolled, and everything on it has been eaten by something that has since been eaten.",
	"Far enough out that the charts get vague. Good ore, worse company.",
	"Where a working skyfarer makes their living, and where most of them stop.",
	"Nobody flies here for a cargo. They fly here for one specific thing and they leave.",
	"The edge of the chart. What is out here is worth what it costs, which is a great deal.",
]
## Everything on a ring is scaled by this: creature health and damage, loot quality, what
## a port will stock, and what a site is worth breaking into.
const RING_POWER = [1.0, 1.35, 1.9, 2.7, 3.8]
const RING_LOOT = [0.0, 0.15, 0.35, 0.6, 0.9]

static func ring_name(tier: int) -> String:
	return RING_NAMES[clampi(tier, 0, 4)]

static func ring_power(tier: int) -> float:
	return RING_POWER[clampi(tier, 0, 4)]

static func ring_loot(tier: int) -> float:
	return RING_LOOT[clampi(tier, 0, 4)]

static func tier_of(id: String) -> int:
	return int(TIER_OF.get(id, 2))

## Pick a biome that suits both the altitude band and the ring. A ring will happily take
## anything at or below its own tier, weighted toward the nastiest thing it is allowed,
## so the Outer Dark is mostly outer-dark biomes with the occasional quiet meadow in it —
## which is far more unsettling than making every island out there hostile.
static func pick_for(band: int, tier: int, rng: RandomNumberGenerator) -> String:
	var pool: Array = BY_BAND.get(clampi(band, 0, 4), BY_BAND[1])
	var ok := []
	var total := 0.0
	for id in pool:
		var t: int = tier_of(String(id))
		if t > tier:
			continue
		# weight toward the ring's own tier: 1 for far below, 4 for bang on
		var w := 1.0 + 3.0 / (1.0 + float(tier - t))
		ok.append([id, w])
		total += w
	if ok.is_empty():
		return B_VERDANCE
	var r := rng.randf() * total
	for row in ok:
		r -= float(row[1])
		if r <= 0.0:
			return String(row[0])
	return String(ok[ok.size() - 1][0])

static func get_b(id: String) -> Dictionary:
	return ALL.get(id, ALL[B_VERDANCE])

static func pick_for_band(band: int, rng: RandomNumberGenerator) -> String:
	var pool: Array = BY_BAND.get(clampi(band, 0, 4), BY_BAND[1])
	return pool[rng.randi() % pool.size()]

## Weighted pick out of a [[value, weight], ...] table.
static func weighted(table: Array, rng: RandomNumberGenerator):
	var total := 0.0
	for row in table:
		total += float(row[1])
	if total <= 0.0:
		return null
	var r := rng.randf() * total
	for row in table:
		r -= float(row[1])
		if r <= 0.0:
			return row[0]
	return table[table.size() - 1][0]

## The surface turf for a tile, given two 0..1 noise fields. The first picks broadly
## between the biome's ground types (so the mix comes out in patches rather than static),
## the second breaks up the boundaries.
static func ground_turf(b: Dictionary, n1: float, n2: float) -> int:
	var table: Array = b["ground"]
	var total := 0.0
	for row in table:
		total += float(row[1])
	var t := clampf(n1 * 0.82 + n2 * 0.18, 0.0, 0.9999) * total
	for row in table:
		t -= float(row[1])
		if t <= 0.0:
			return int(row[0])
	return int(table[0][0])

## Islands are named for their biome and a scrap of the old world's language.
const NAME_FIRST := ["Kal", "Ves", "Dorn", "Ith", "Mar", "Sol", "Bran", "Ael", "Tor", "Hesp",
	"Cair", "Orl", "Vand", "Sera", "Mor", "Quill", "Ash", "Bryn", "Cove", "Duns",
	"Fell", "Gale", "Harrow", "Isk", "Jorn", "Kess", "Lum", "Nyr", "Perch", "Roke"]
const NAME_LAST := ["holm", "reach", "fell", "mere", "crag", "wold", "spire", "gard", "ness", "hollow",
	"barrow", "strand", "keep", "march", "rest", "shear", "drift", "perch", "fold", "watch"]

static func island_name(rng: RandomNumberGenerator, b: Dictionary) -> String:
	var n: String = str(NAME_FIRST[rng.randi() % NAME_FIRST.size()]) + str(NAME_LAST[rng.randi() % NAME_LAST.size()])
	if rng.randf() < 0.18:
		return "%s %s" % [["Old", "Little", "Upper", "Lower", "Far", "Broken"][rng.randi() % 6], n]
	return n
