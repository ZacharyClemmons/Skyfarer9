extends Node
## Global constants and static data tables (turfs, gases, departments).
## Numbers follow /tg/station's atmospherics defines where there is an equivalent.

const TILE := 32

# ------------------------------------------------------------------ atmospherics (tg: __DEFINES/atmospherics)
const R_IDEAL := 8.31
const ONE_ATMOS := 101.325
const CELL_VOLUME := 2500.0
const T0C := 273.15
const T20C := 293.15
const ONE_ATMOSPHERE := 101.325 # kPa
const MOLES_CELLSTANDARD := ONE_ATMOS * CELL_VOLUME / (T20C * R_IDEAL) # ~103.98
const MIN_MOLES_DELTA := MOLES_CELLSTANDARD * 0.001
const MIN_TEMP_DELTA := 0.5
const FIRE_MIN_TEMP_TO_EXIST := 100.0 + T0C
const FIRE_MIN_TEMP_TO_SPREAD := 150.0 + T0C
const PLASMA_MIN_BURN_TEMP := 100.0 + T0C
const HAZARD_HIGH_PRESSURE := 550.0
const WARNING_HIGH_PRESSURE := 325.0
const WARNING_LOW_PRESSURE := 50.0
const HAZARD_LOW_PRESSURE := 20.0
const BODYTEMP_NORMAL := 310.15
const BODYTEMP_COLD_DAMAGE := 260.15
const BODYTEMP_HEAT_DAMAGE := 360.15
const SAFE_O2_MIN_PP := 16.0 # kPa partial pressure needed to breathe
const SAFE_CO2_MAX_PP := 10.0
const SAFE_PLASMA_MAX_PP := 0.05 # tg lungs safe_plasma_max
# tg atmos_mob_interaction.dm / mobs.dm / lungs
const BREATH_VOLUME := 1.99 # litres per breath
const BREATH_PERCENTAGE := BREATH_VOLUME / CELL_VOLUME
const BREATH_INTERVAL := 8.0 # a breath every 4th Life tick of 2 s ...
const BREATH_INTERVAL_FAILING := 2.0 # ... or every tick while the last one failed
const SUFFOCATION_OXYLOSS := 3.0
const SUFFOCATION_OXYLOSS_CRIT_MODIFIER := 0.22
const MIN_TOXIC_GAS_DAMAGE := 1.0
const MAX_TOXIC_GAS_DAMAGE := 10.0
const N2O_DETECT_MIN := 0.08
const N2O_PARA_MIN := 1.0
const N2O_SLEEP_MIN := 5.0
const COLD_LEVELS := [[120.0, 3.0], [200.0, 1.5], [260.0, 0.5]] # breath temperature below K: burn per breath
const HEAT_LEVELS := [[1000.0, 8.0], [400.0, 4.0], [360.0, 2.0]] # breath temperature above K: burn per breath
const TANK_DEFAULT_RELEASE_PRESSURE := 16.0
# tg atmos_mob_interaction.dm body temperature
const BODYTEMP_AUTORECOVERY_DIVISOR := 28.0
const BODYTEMP_STANDARD_CHANGE_RATE := 0.06
const BODYTEMP_CORE_CHANGE_RATE := BODYTEMP_STANDARD_CHANGE_RATE * 0.25
const BODYTEMP_SKIN_CORE_CHANGE_RATE := BODYTEMP_STANDARD_CHANGE_RATE * 0.65
const BODYTEMP_CORE_SKIN_CHANGE_RATE := BODYTEMP_STANDARD_CHANGE_RATE * 0.75
const BODYTEMP_AREA_SKIN_CHANGE_RATE := BODYTEMP_STANDARD_CHANGE_RATE * 0.85
const BODYTEMP_HEAT_DAMAGE_LIMIT := BODYTEMP_NORMAL + 30.0
const BODYTEMP_COLD_DAMAGE_LIMIT := BODYTEMP_NORMAL - 40.0

# Every gas in tg (code/modules/atmospherics/gasmixtures/gas_types.dm), plus smoke, which
# tg doesn't have as a gas. The first eight keep their old slots.
enum { G_O2, G_N2, G_CO2, G_PLASMA, G_N2O, G_H2O, G_SMOKE, G_TRITIUM,
	G_HYPERNOB, G_NITRIUM, G_BZ, G_PLUOXIUM, G_MIASMA, G_FREON, G_HYDROGEN, G_HEALIUM,
	G_PROTO_NITRATE, G_ZAUKER, G_HALON, G_HELIUM, G_ANTINOB }
const GAS_COUNT := 21
const GAS_NAMES := ["Oxygen", "Nitrogen", "Carbon Dioxide", "Plasma", "Nitrous Oxide", "Water Vapor", "Smoke", "Tritium",
	"Hyper-Noblium", "Nitrium", "BZ", "Pluoxium", "Miasma", "Freon", "Hydrogen", "Healium",
	"Proto-Nitrate", "Zauker", "Halon", "Helium", "Anti-Noblium"]
const GAS_SHORT := ["O2", "N2", "CO2", "Plasma", "N2O", "H2O", "Smoke", "Tritium",
	"Hyper-Nob", "Nitrium", "BZ", "Pluox", "Miasma", "Freon", "H2", "Healium",
	"Proto-Nit", "Zauker", "Halon", "He", "Anti-Nob"]
# tg specific_heat (J/K per mole)
const GAS_SPECIFIC_HEAT := [20.0, 20.0, 30.0, 200.0, 40.0, 40.0, 20.0, 10.0,
	2000.0, 10.0, 20.0, 80.0, 20.0, 600.0, 15.0, 10.0,
	30.0, 350.0, 175.0, 15.0, 1.0]
# tg moles_visible: over this many moles a gas shows as an overlay (0: never visible).
# MOLES_GAS_VISIBLE is 0.25; N2O shows from x2, freon x30, miasma x60.
const GAS_VISIBLE_AT := [0.0, 0.0, 0.0, 0.25, 0.5, 0.25, 0.25, 0.25,
	0.25, 0.25, 0.0, 0.0, 15.0, 7.5, 0.0, 0.25,
	0.25, 0.25, 0.25, 0.0, 0.25]
const GAS_VISIBLE := [false, false, false, true, true, true, true, true,
	true, true, false, false, true, true, false, true,
	true, true, true, false, true]
# tg primary_color, used where each gas needs a colour of its own (filters, analyzers, tanks)
const GAS_PRIMARY := [Color("#0000ff"), Color("#ffff00"), Color("#808080"), Color("#ffc0cb"), Color("#ffe4c4"), Color("#b0c4de"), Color("#2e2e33"), Color("#32cd32"),
	Color("#008080"), Color("#a52a2a"), Color("#9370db"), Color("#7b68ee"), Color("#808000"), Color("#afeeee"), Color("#ffffff"), Color("#fa8072"),
	Color("#adff2f"), Color("#006400"), Color("#800080"), Color("#f0f8ff"), Color("#800000")]
# overlay tint for the gases drawn as a coloured haze (tg's overlay sprites' main colour)
const GAS_COLOR := [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.85, 0.35, 1.0), Color(1, 1, 1), Color(0.9, 0.95, 1.0), Color(0.18, 0.18, 0.2), Color(0.35, 0.95, 0.35),
	Color(0.3, 0.85, 0.85), Color(0.75, 0.35, 0.2), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.55, 0.55, 0.2), Color(0.7, 0.95, 0.98), Color(0, 0, 0, 0), Color(0.98, 0.55, 0.5),
	Color(0.7, 1.0, 0.25), Color(0.1, 0.45, 0.15), Color(0.6, 0.2, 0.65), Color(0, 0, 0, 0), Color(0.55, 0.05, 0.1)]
# tg gas descriptions (desc)
const GAS_DESC := ["The gas most life forms need to be able to survive. Also an oxidizer.",
	"A very common gas that pads the air out to a pressure lungs can use.",
	"The gas you breathe out. Harmless in small doses, deadly in a shut hold.",
	"A flammable gas with many curious properties. Artificers prize it above almost anything else in the sky.",
	"A gas known to cause drowsiness, euphoria, and eventually unconsciousness.",
	"Water, in gas form. Makes floors slippery and washes items on them.",
	"Soot and fumes from a fire.",
	"A highly flammable and radioactive gas.",
	"The most noble gas of them all. High quantities actively prevent reactions from occurring.",
	"An experimental (and slightly toxic) performance enhancing gas that increases speed and alertness when inhaled.",
	"A powerful hallucinogenic nerve agent able to induce cognitive damage.",
	"An alternative to oxygen that is eight times more efficient at lung diffusion.",
	"Miasma is not necessarily a gas, but more broadly refers to biological pollutants.",
	"A coolant gas. Primarily used for its endothermic reaction with oxygen.",
	"A highly flammable gas.",
	"An experimental alternative to anesthetic that induces a state of unconsciousness while healing.",
	"A volatile gas that has wildly different reactions with other gases.",
	"A highly toxic and difficult to produce gas.",
	"A potent fire suppressant. It removes oxygen from high temperature fires and cools down the area.",
	"An inert noble gas produced by the fusion of hydrogen and its derivatives.",
	"A mysterious and highly reactive gas known to replicate itself."]

# ------------------------------------------------------------------ the Cloudsea
## Skyfarer's open air. Unlike Artic9's asteroid this is breathable down low and lethal
## up high, so the "outdoor reservoir" the atmos system mixes with is a function of the
## sky region's altitude rather than a constant. SkyGen sets ALT at world generation and
## the numbers below are recomputed from it.

## Altitude bands, in kilometres above the Deep. Each band is a different sky region.
const ALT_DEEP := 0.4    # below the cloud floor: hot, thick, dark, and something lives there
const ALT_LOW := 2.0     # the green shelf, where most inhabited islands drift
const ALT_MID := 5.5     # thin and cold; you feel it on a long climb
const ALT_HIGH := 9.0    # need a mask
const ALT_VOID := 14.0   # the Anvil. Sealed hull or you die.
const ALT_NAMES := ["the Deep", "the Shelf", "the Reaches", "the Heights", "the Anvil"]
const ALT_BANDS := [ALT_DEEP, ALT_LOW, ALT_MID, ALT_HIGH, ALT_VOID]

## Sea-level-ish reference: 101 kPa of 21/79 air at 20 C, per 2500 L cell.
const SKY_MOLES_BASE := MOLES_CELLSTANDARD
const SKY_SCALE_HEIGHT := 7.4 # km; pressure falls off as exp(-alt / this)

## Total moles per outdoor cell at a given altitude.
static func sky_moles(alt_km: float) -> float:
	return SKY_MOLES_BASE * exp(-maxf(0.0, alt_km) / SKY_SCALE_HEIGHT)

## Air temperature at altitude: warm in the Deep, ~-6.5 K per km on the way up, and the
## Anvil bottoms out near the stratosphere's own floor.
static func sky_temp(alt_km: float) -> float:
	return maxf(205.0, 318.0 - alt_km * 6.5)

## The outdoor gas reservoir for a sky region: ordinary air, thinned by altitude. The
## Deep carries a haze of miasma off whatever is rotting down there.
static func sky_gases(alt_km: float) -> Array:
	var out := []
	out.resize(GAS_COUNT)
	out.fill(0.0)
	var n := sky_moles(alt_km)
	out[G_O2] = n * 0.21
	out[G_N2] = n * 0.78
	out[G_CO2] = n * 0.005
	if alt_km <= ALT_DEEP + 0.01:
		out[G_MIASMA] = n * 0.02
		out[G_H2O] = n * 0.03
	return out

## Runtime values, set by SkyGen. Default: the Shelf.
static var ALT := ALT_LOW
static var EXT_TEMP := sky_temp(ALT_LOW)
static var EXT_GASES := sky_gases(ALT_LOW)

static func set_altitude(alt_km: float) -> void:
	ALT = alt_km
	EXT_TEMP = sky_temp(alt_km)
	EXT_GASES = sky_gases(alt_km)

static func band_index(alt_km: float) -> int:
	var best := 0
	for i in ALT_BANDS.size():
		if alt_km >= ALT_BANDS[i] - 0.01:
			best = i
	return best

static func band_name(alt_km: float) -> String:
	return ALT_NAMES[band_index(alt_km)]

## Is this turf open sky? Stepping onto it without something to hold you means falling.
static func is_void_turf(t: int) -> bool:
	return t == T_SKY or t == T_CLOUD

# ------------------------------------------------------------------ turfs
enum {
	T_SNOW, T_DEEPSNOW, T_ICE, T_GRAVEL, T_PACKED,
	T_ROCK, T_ROCK_IRON, T_ROCK_PLASMA, T_ROCK_CRYO, T_ROCK_GOLD,
	T_PLATING, T_STEEL, T_WHITE, T_DARK, T_BLUE, T_RED, T_YELLOW, T_PURPLE, T_GREEN, T_TEALMED,
	T_WOOD, T_FREEZER, T_CAFE, T_CARPET, T_BLUECARPET, T_GRATE,
	T_WALL, T_RWALL,
	T_HULL, T_SHUTTLE, T_ENGINE,
	# ---- Skyfarer: the Cloudsea and its islands
	T_SKY, T_CLOUD,
	T_GRASS, T_GRASS_TALL, T_DIRT, T_MOSS, T_SAND, T_ASH, T_MUD, T_SALT, T_BONEDUST,
	T_STONE, T_BASALT, T_WATER, T_LAVA,
	T_ROCK_AETHER, T_ROCK_SULFUR, T_ROCK_CRYSTAL, T_THICKET,
	T_DECK, T_DECK_PLATE, T_DECK_OPEN, T_HULLWOOD, T_KEEL, T_BULKHEAD,
	T_COUNT
}

# name, sprite prefix, variants, flags
const F_SOLID := 1
const F_OPAQUE := 2
const F_OUTDOOR := 4
const F_FLOOR := 8 # station floor tile (has tile covering; hides pipes)
const F_SLIPPERY := 16
const F_SLOW := 32
const F_ROCK := 64
const F_WALL := 128
const F_VOID := 256    # open sky: nothing to stand on, you fall
const F_LIQUID := 512  # water / lava: wades, splashes, may burn
const F_SOFT := 1024   # grass, moss, sand: muffles footsteps, takes tracks

var TURFS := [
	{"name": "snow", "spr": "snow", "var": 8, "flags": F_OUTDOOR},
	{"name": "deep snow", "spr": "deepsnow", "var": 4, "flags": F_OUTDOOR | F_SLOW},
	{"name": "ice", "spr": "ice", "var": 4, "flags": F_OUTDOOR | F_SLIPPERY},
	{"name": "frozen gravel", "spr": "gravel", "var": 4, "flags": F_OUTDOOR},
	{"name": "packed snow", "spr": "packed", "var": 4, "flags": F_OUTDOOR},
	{"name": "rock", "spr": "rock", "var": 3, "flags": F_SOLID | F_OPAQUE | F_ROCK, "hp": 60},
	{"name": "iron-veined rock", "spr": "rock_iron", "var": 1, "flags": F_SOLID | F_OPAQUE | F_ROCK, "hp": 70, "ore": "ore_iron"},
	{"name": "aetherglass-veined rock", "spr": "rock_plasma", "var": 1, "flags": F_SOLID | F_OPAQUE | F_ROCK, "hp": 80, "ore": "ore_plasma"},
	{"name": "frostglass-veined rock", "spr": "rock_cryo", "var": 1, "flags": F_SOLID | F_OPAQUE | F_ROCK, "hp": 80, "ore": "ore_cryo"},
	{"name": "gold-veined rock", "spr": "rock_gold", "var": 1, "flags": F_SOLID | F_OPAQUE | F_ROCK, "hp": 90, "ore": "ore_gold"},
	{"name": "plating", "spr": "plating", "var": 4, "flags": 0},
	{"name": "steel floor", "spr": "floor_steel", "var": 4, "flags": F_FLOOR},
	{"name": "white floor", "spr": "floor_white", "var": 4, "flags": F_FLOOR},
	{"name": "dark floor", "spr": "floor_dark", "var": 4, "flags": F_FLOOR},
	{"name": "blue floor", "spr": "floor_blue", "var": 4, "flags": F_FLOOR},
	{"name": "red floor", "spr": "floor_red", "var": 4, "flags": F_FLOOR},
	{"name": "yellow floor", "spr": "floor_yellow", "var": 4, "flags": F_FLOOR},
	{"name": "purple floor", "spr": "floor_purple", "var": 4, "flags": F_FLOOR},
	{"name": "green floor", "spr": "floor_green", "var": 4, "flags": F_FLOOR},
	{"name": "sterile floor", "spr": "floor_tealmed", "var": 4, "flags": F_FLOOR},
	{"name": "wooden floor", "spr": "floor_wood", "var": 4, "flags": F_FLOOR},
	{"name": "freezer floor", "spr": "floor_freezer", "var": 4, "flags": F_FLOOR},
	{"name": "checkered floor", "spr": "floor_cafe", "var": 4, "flags": F_FLOOR},
	{"name": "carpet", "spr": "floor_carpet", "var": 4, "flags": F_FLOOR},
	{"name": "blue carpet", "spr": "floor_bluecarpet", "var": 4, "flags": F_FLOOR},
	{"name": "catwalk grate", "spr": "grate", "var": 4, "flags": 0},
	{"name": "wall", "spr": "wall", "var": 1, "flags": F_SOLID | F_OPAQUE | F_WALL, "hp": 200},
	{"name": "reinforced wall", "spr": "rwall", "var": 1, "flags": F_SOLID | F_OPAQUE | F_WALL, "hp": 600},
	{"name": "armoured hull", "spr": "hull", "var": 1, "flags": F_SOLID | F_OPAQUE | F_WALL, "hp": 800},
	{"name": "ferry deck", "spr": "floor_shuttle", "var": 4, "flags": F_FLOOR},
	# tg turf/open/floor/engine: bolted plates, no tile to pry up; the gas chambers' floor
	{"name": "reinforced floor", "spr": "floor_engine", "var": 1, "flags": 0},
	# ------------------------------------------------------------ Skyfarer
	# Open sky. Nothing holds you up; step off an island and you fall into the Deep.
	{"name": "open sky", "spr": "sky", "var": 8, "flags": F_OUTDOOR | F_VOID},
	{"name": "cloud bank", "spr": "cloud", "var": 4, "flags": F_OUTDOOR | F_VOID},
	{"name": "grass", "spr": "grass", "var": 8, "flags": F_OUTDOOR | F_SOFT},
	{"name": "tall grass", "spr": "grasstall", "var": 4, "flags": F_OUTDOOR | F_SOFT | F_SLOW},
	{"name": "bare earth", "spr": "dirt", "var": 4, "flags": F_OUTDOOR},
	{"name": "moss", "spr": "moss", "var": 4, "flags": F_OUTDOOR | F_SOFT},
	{"name": "sand", "spr": "sand", "var": 6, "flags": F_OUTDOOR | F_SOFT | F_SLOW},
	{"name": "ashfall", "spr": "ash", "var": 4, "flags": F_OUTDOOR | F_SOFT},
	{"name": "mud", "spr": "mud", "var": 4, "flags": F_OUTDOOR | F_SLOW},
	{"name": "salt flat", "spr": "salt", "var": 4, "flags": F_OUTDOOR},
	{"name": "bone dust", "spr": "bonedust", "var": 4, "flags": F_OUTDOOR | F_SOFT},
	{"name": "stone", "spr": "stone", "var": 6, "flags": F_OUTDOOR},
	{"name": "basalt", "spr": "basalt", "var": 4, "flags": F_OUTDOOR},
	{"name": "shallow water", "spr": "water", "var": 4, "flags": F_OUTDOOR | F_LIQUID | F_SLOW},
	{"name": "molten rock", "spr": "lava", "var": 4, "flags": F_OUTDOOR | F_LIQUID},
	{"name": "aetherite-veined rock", "spr": "rock_aether", "var": 1, "flags": F_SOLID | F_OPAQUE | F_ROCK, "hp": 90, "ore": "ore_aetherite"},
	{"name": "sulfur-veined rock", "spr": "rock_sulfur", "var": 1, "flags": F_SOLID | F_OPAQUE | F_ROCK, "hp": 70, "ore": "ore_sulfur"},
	{"name": "crystal-veined rock", "spr": "rock_crystal", "var": 1, "flags": F_SOLID | F_OPAQUE | F_ROCK, "hp": 85, "ore": "ore_skyglass"},
	# Jungle thicket: dense enough to stop you and block sight, but hacked apart in seconds.
	{"name": "thicket", "spr": "thicket", "var": 1, "flags": F_SOLID | F_OPAQUE | F_ROCK, "hp": 25},
	# Sealed decks: indoor, so the atmos system simulates the air in them. A cabin with a
	# hole in it decompresses, and at altitude that matters.
	{"name": "deck planking", "spr": "deck", "var": 4, "flags": F_FLOOR},
	{"name": "deck plating", "spr": "deckplate", "var": 4, "flags": F_FLOOR},
	# The weather deck: you can walk on it, but it is open to the sky, so it holds
	# whatever the region's air is and never needs sealing.
	{"name": "weather deck", "spr": "deckopen", "var": 4, "flags": F_OUTDOOR},
	# The outer hull is a bulwark you can see over — standing at the rail of your own ship
	# should not feel like standing in a crate — so it stops movement without stopping sight.
	{"name": "ship hull", "spr": "hullwood", "var": 1, "flags": F_SOLID | F_WALL, "hp": 400},
	{"name": "keel timber", "spr": "keel", "var": 1, "flags": F_SOLID | F_WALL, "hp": 900},
	# Interior bulkheads are full height, and do block sight: a cabin is private.
	{"name": "bulkhead", "spr": "bulkhead", "var": 1, "flags": F_SOLID | F_OPAQUE | F_WALL, "hp": 300},
]

func turf_flags(t: int) -> int:
	return TURFS[t]["flags"]

# ------------------------------------------------------------------ structures on tiles (windows etc.)
## Windows sit on a grille: breaking the pane leaves the grille behind (tg fulltile windows
## are mapped over grilles). Window damage shows as crack overlays from its integrity.
enum { S_NONE, S_WINDOW, S_GRILLE, S_GIRDER, S_RWINDOW, S_GRILLE_BROKEN }
## tg structure stats (code/game/objects/structures/window.dm, grille.dm):
##   hp: max_integrity; deflect: damage_deflection (melee hits under it do nothing);
##   armor: damage-flag armour, 0-100; name: examine name.
const STRUCTS := [
	{"name": "", "hp": 0.0, "deflect": 0.0, "armor": {}},
	{"name": "window", "hp": 100.0, "deflect": 0.0, "armor": {"melee": 50, "fire": 80}}, # /window/fulltile
	{"name": "grille", "hp": 50.0, "deflect": 0.0, "armor": {"melee": 50, "bullet": 70, "laser": 70, "energy": 100, "bomb": 10}},
	{"name": "girder", "hp": 200.0, "deflect": 0.0, "armor": {}}, # /structure/girder: no armour
	{"name": "reinforced window", "hp": 150.0, "deflect": 11.0, "armor": {"melee": 80, "bomb": 25, "fire": 80}}, # /window/reinforced/fulltile
	{"name": "broken grille", "hp": 20.0, "deflect": 0.0, "armor": {"melee": 50, "bullet": 70, "laser": 70, "energy": 100, "bomb": 10}},
]
const GRILLE_FAILURE := 0.4 # tg grille integrity_failure: at 40% it breaks, leaving 20 hp

static func is_window(s: int) -> bool:
	return s == S_WINDOW or s == S_RWINDOW

static func is_grille(s: int) -> bool:
	return s == S_GRILLE or s == S_GRILLE_BROKEN

## Does this structure stop movement? A broken grille is bent out of the way (tg set_density(FALSE)).
static func struct_dense(s: int) -> bool:
	return s != S_NONE and s != S_GRILLE_BROKEN

# ------------------------------------------------------------------ departments & radio (tg: radio channels)
const DEPARTMENTS := {
	"command": {"name": "Bridge", "color": Color("#4a8ad8"), "radio": "Command", "key": "c"},
	"security": {"name": "Watch", "color": Color("#d84a4a"), "radio": "Security", "key": "s"},
	"engineering": {"name": "Engine Room", "color": Color("#e8a83a"), "radio": "Engineering", "key": "e"},
	"medical": {"name": "Sickbay", "color": Color("#4ab8d8"), "radio": "Medical", "key": "m"},
	"science": {"name": "Aetherworks", "color": Color("#b87ae8"), "radio": "Science", "key": "n"},
	"service": {"name": "Galley", "color": Color("#5ac87a"), "radio": "Service", "key": "v"},
	"supply": {"name": "Hold", "color": Color("#c8883a"), "radio": "Supply", "key": "u"},
	"civilian": {"name": "Passengers", "color": Color("#9aa3b3"), "radio": "Common", "key": ""},
}
const RADIO_COLORS := {
	"Common": Color("#7ad87a"), "Command": Color("#6a9aff"), "Security": Color("#ff5a5a"),
	"Engineering": Color("#ffb84a"), "Medical": Color("#5ad0e8"), "Science": Color("#c88aff"),
	"Service": Color("#8ae88a"), "Supply": Color("#d8a86a"), "Station": Color("#ffe07a"),
}
## What each channel is called on screen. The keys stay the old ids (code compares them).
const RADIO_LABELS := {"Command": "Bridge", "Security": "Watch", "Engineering": "Engine Room", "Medical": "Sickbay",
	"Science": "Aetherworks", "Service": "Galley", "Supply": "Hold", "Station": "Ship"}
static func radio_label(ch: String) -> String:
	return RADIO_LABELS.get(ch, ch)

# ------------------------------------------------------------------ time
## One real second is SIM_TIME_SCALE station seconds. Shift starts 07:00.
const SIM_TIME_SCALE := 6.0
const SHIFT_START_HOUR := 7.0

const DIRS4 := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const DIRS8 := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]
enum { DIR_N, DIR_E, DIR_S, DIR_W }

func dir_from_vec(v: Vector2i) -> int:
	if abs(v.x) > abs(v.y):
		return DIR_E if v.x > 0 else DIR_W
	return DIR_S if v.y > 0 else DIR_N
