class_name ShipParts extends RefCounted
## Everything you can bolt to a hull, and what it does to her numbers.
##
## A stamped ship keeps two parallel maps. `cells_map` says what shape she is — planking,
## bulwark, bulkhead, a hole for an engine — and that is what seals, weighs and flies.
## `fittings` says *which* engine is in the hole: a brass burner off a scrapyard or a
## triple-expansion aether turbine somebody in Meridian took four months over.
##
## Splitting the two is what makes upgrading a ship a real activity. The deck plan you
## drew at the shipyard never changes when you buy a better thruster; the hole stays the
## same size and something better goes in it. Everything downstream reads the numbers
## rather than the glyph, so a skiff with a Vashti turbine genuinely outruns a cutter with
## a brass burner, and the reason is legible in the panel.
##
## A module's stat block, all optional, all additive unless the name says otherwise:
##   thrust      pounds of shove at full throttle
##   lift        share of the hull's designed lift this cell carries (1.0 = a stock cell)
##   sail        square feet of canvas, worth wind-force
##   turn        rudder authority, added to the hull's own
##   drag_mul    multiplies the hull's drag coefficient (a fairing is < 1)
##   fuel_mul    multiplies the fuel this module burns (efficiency is < 1)
##   power       watts produced (+) or drawn (-)
##   steam       boiler output; a thruster needs steam to inject
##   heat_mul    how hard it cooks the compartment it stands in
##   cargo       extra tonnes of hold
##   armor       damage soaked per hull hit on this tile
##   crew        berths added
##   mass        tonnes, overriding the glyph's default
##   quirk       a named behaviour hook (see QUIRKS at the bottom)

# ------------------------------------------------------------------ categories
const CATS := {
	"thruster": {"name": "Thrusters", "glyph": "E", "desc": "Forward shove. Burns distillate and dumps its exhaust into the compartment it stands in."},
	"propeller": {"name": "Airscrews", "glyph": "p", "desc": "Fine handling. Small thrust, real turning authority."},
	"mast": {"name": "Rigs", "glyph": "m", "desc": "Canvas. Free speed when the aether wind is going your way."},
	"lift": {"name": "Lift cells", "glyph": "L", "desc": "What is between you and the Deep."},
	"boiler": {"name": "Boilers", "glyph": "B", "desc": "Pressure for the injectors. No steam, no thrust."},
	"dynamo": {"name": "Generators", "glyph": "G", "desc": "Volts for everything that is not the engine."},
	"bunker": {"name": "Bunkers", "glyph": "T", "desc": "Distillate. Range is bunker capacity divided by burn rate."},
	"gun": {"name": "Gun mounts", "glyph": "g", "desc": "Ship weapons on a swivel or a slide."},
	"helm": {"name": "Helms", "glyph": "h", "desc": "The wheel. Better ones read more and fight you less."},
	"nav": {"name": "Navigation", "glyph": "n", "desc": "Charts, sounders and the things that find islands for you."},
	"utility": {"name": "Utility", "glyph": "C", "desc": "Winches, benches, stills, everything that is not flying her."},
	"armor": {"name": "Plating", "glyph": "#", "desc": "Hull skin. Heavy, and worth it the first time something shoots at you."},
}

## tier -> what a shipyard calls it, and roughly where it belongs in the game
const TIER_NAMES = ["salvage", "standard", "fine", "master", "legend"]
const TIER_COLORS = ["#8aa0b4", "#dbe8f4", "#6ad88a", "#7fd4ff", "#e8a83a"]

# ------------------------------------------------------------------ the catalogue
## id -> {cat, name, tier, cost, desc, ...stats, req: {skill: level}}
static var MODULES := {
	# ================================================================ thrusters
	"thruster_brass": {"cat": "thruster", "name": "brass burner", "tier": 0, "cost": 380, "mass": 4.0,
		"thrust": 38.0, "fuel_mul": 1.25, "heat_mul": 1.2, "steam": 0.0,
		"desc": "A fuel burner with a throat on it, third-hand, and it was third-hand when the last owner bought it. \
It will get you off an island."},
	"thruster_std": {"cat": "thruster", "name": "aether thruster", "tier": 1, "cost": 820, "mass": 5.0,
		"thrust": 52.0, "fuel_mul": 1.0, "heat_mul": 1.0,
		"desc": "The standard yard-fitted engine of the Shelf. Nothing about it is clever and everything about it works."},
	"thruster_twin": {"cat": "thruster", "name": "twinned burner", "tier": 2, "cost": 1750, "mass": 7.5,
		"thrust": 86.0, "fuel_mul": 1.35, "heat_mul": 1.7, "req": {"shipwright": 20},
		"desc": "Two throats off one injector. Twice the shove and rather more than twice the heat, so put it somewhere \
you do not mind losing."},
	"thruster_vashti": {"cat": "thruster", "name": "Vashti turbine", "tier": 3, "cost": 4200, "mass": 6.5,
		"thrust": 104.0, "fuel_mul": 0.72, "heat_mul": 0.85, "turn": 0.04, "req": {"shipwright": 40, "artifice": 25},
		"desc": "Aether expands through three stages instead of one. Vashti died owing money to four ports and \
this is why everyone forgave her."},
	"thruster_stormdrive": {"cat": "thruster", "name": "stormdrive", "tier": 4, "cost": 11000, "mass": 9.0,
		"thrust": 132.0, "fuel_mul": 0.55, "heat_mul": 1.1, "quirk": "storm_feed", "req": {"shipwright": 60, "artifice": 55},
		"desc": "It drinks the charge out of a thunderhead. In clear air it is merely very good; inside a storm cell it \
is the fastest thing in this sky and the gauges stop being reassuring.", "glow": "#7fd4ff"},
	"thruster_whisper": {"cat": "thruster", "name": "whisper drive", "tier": 3, "cost": 5400, "mass": 5.0,
		"thrust": 68.0, "fuel_mul": 0.8, "heat_mul": 0.4, "quirk": "quiet", "req": {"artifice": 45},
		"desc": "The exhaust is routed through a baffle stack the size of the engine. Half the noise reaches the outside \
world, which matters more than you would think to the things that hunt by sound."},

	# ================================================================ airscrews
	"screw_caged": {"cat": "propeller", "name": "caged airscrew", "tier": 1, "cost": 340, "mass": 3.0,
		"thrust": 9.0, "turn": 0.10, "power": -900.0,
		"desc": "It does very little and the crew would notice at once if it stopped."},
	"screw_vector": {"cat": "propeller", "name": "vectoring screw", "tier": 2, "cost": 1100, "mass": 3.5,
		"thrust": 12.0, "turn": 0.22, "power": -1600.0, "req": {"shipwright": 25},
		"desc": "The whole nacelle swings. She will come about inside her own length, which is a thing you only \
appreciate in a canyon."},
	"screw_gyro": {"cat": "propeller", "name": "gyro stabiliser", "tier": 3, "cost": 2600, "mass": 5.0,
		"turn": 0.30, "power": -2600.0, "quirk": "steady", "req": {"artifice": 35},
		"desc": "A flywheel the size of a table, spun up and gimballed. She holds a heading through a gale and \
a gust no longer throws the cook across the galley."},

	# ================================================================ rigs
	"mast_gaff": {"cat": "mast", "name": "gaff mast", "tier": 0, "cost": 190, "mass": 2.0,
		"sail": 12.0, "desc": "A spar, a boom and a lot of hand-stitching. Free speed if the wind agrees with you."},
	"mast_square": {"cat": "mast", "name": "square rig", "tier": 1, "cost": 520, "mass": 3.2,
		"sail": 22.0, "drag_mul": 1.06, "desc": "More canvas than a gaff and worse to windward. Trade winds only."},
	"mast_lateen": {"cat": "mast", "name": "lateen rig", "tier": 2, "cost": 980, "mass": 2.6,
		"sail": 19.0, "turn": 0.06, "quirk": "close_hauled", "req": {"rigging": 25},
		"desc": "She will sail far closer to the wind than she has any right to. Every other rig needs the wind \
behind it; this one needs the wind to exist."},
	"mast_skysilk": {"cat": "mast", "name": "skysilk rig", "tier": 3, "cost": 3100, "mass": 1.8,
		"sail": 34.0, "drag_mul": 0.96, "req": {"rigging": 45},
		"desc": "Spun from the thread a marrow moth leaves on the rock. Lighter than the rope holding it up, and it \
does not tear — it unravels, slowly, and you notice."},
	"mast_stormcanvas": {"cat": "mast", "name": "storm canvas", "tier": 3, "cost": 2400, "mass": 4.4,
		"sail": 26.0, "quirk": "storm_proof", "req": {"rigging": 35},
		"desc": "Heavy, tarred, and it will not blow out in a gale. Everyone else has to reef; you do not."},

	# ================================================================ lift cells
	"lift_patched": {"cat": "lift", "name": "patched bladder", "tier": 0, "cost": 210, "mass": 1.6,
		"lift": 0.82, "desc": "More patch than bladder. It leaks a little, always, and you learn to live with it."},
	"lift_std": {"cat": "lift", "name": "lift cell", "tier": 1, "cost": 560, "mass": 2.0,
		"lift": 1.0, "desc": "A braced bladder of aetherite vapour in a rope harness. Standard, everywhere, \
for the excellent reason that it works."},
	"lift_ribbed": {"cat": "lift", "name": "ribbed cell", "tier": 2, "cost": 1300, "mass": 2.8,
		"lift": 1.24, "armor": 4.0, "req": {"rigging": 20},
		"desc": "Cane ribs inside the envelope. It holds its shape under fire, which is the whole point of it."},
	"lift_skyglass": {"cat": "lift", "name": "skyglass cell", "tier": 3, "cost": 3400, "mass": 1.9,
		"lift": 1.55, "req": {"artifice": 40},
		"desc": "Vapour held in a lattice of grown crystal rather than cloth. It does not leak. It does shatter, \
once, spectacularly, and then you are a glider."},
	"lift_sunken": {"cat": "lift", "name": "sunken cell", "tier": 4, "cost": 9000, "mass": 2.2,
		"lift": 1.9, "quirk": "cold_lift", "req": {"artifice": 60, "salvaging": 40},
		"desc": "Pulled out of something in the Deep that had been floating for longer than the ports have existed. \
It lifts harder the colder it gets, which is backwards, and nobody has explained it."},

	# ================================================================ boilers
	"boiler_pot": {"cat": "boiler", "name": "pot boiler", "tier": 0, "cost": 260, "mass": 4.0,
		"steam": 0.7, "fuel_mul": 1.3, "heat_mul": 1.3,
		"desc": "Riveted iron, a firebox, and a gauge whose needle has been bent back into place at least once."},
	"boiler_std": {"cat": "boiler", "name": "boiler", "tier": 1, "cost": 640, "mass": 5.0,
		"steam": 1.0, "fuel_mul": 1.0, "heat_mul": 1.0,
		"desc": "Read the gauge. That is the entire manual and it is sufficient."},
	"boiler_water_tube": {"cat": "boiler", "name": "water-tube boiler", "tier": 2, "cost": 1600, "mass": 5.5,
		"steam": 1.45, "fuel_mul": 0.88, "heat_mul": 0.9, "req": {"engineering": 25},
		"desc": "Pressure up in ninety seconds instead of ten minutes, and it does not go off like a shell when \
it fails. It merely goes off."},
	"boiler_aether": {"cat": "boiler", "name": "aether core", "tier": 3, "cost": 4800, "mass": 4.5,
		"steam": 1.9, "fuel_mul": 0.6, "power": 6000.0, "heat_mul": 0.7, "req": {"artifice": 45},
		"desc": "It is not a boiler. It is a cell of aetherite held just below the point where it decides to \
stop being aetherite, and the port authority would like a word about it.", "glow": "#7ad8c8"},

	# ================================================================ generators
	"dynamo_belt": {"cat": "dynamo", "name": "belt dynamo", "tier": 1, "cost": 480, "mass": 4.0,
		"power": 16000.0, "steam": -0.15, "desc": "Belted off the boiler. Everything electrical aboard hangs \
off this one machine and the belt is the part that fails."},
	"dynamo_turbo": {"cat": "dynamo", "name": "turbo-alternator", "tier": 2, "cost": 1450, "mass": 4.5,
		"power": 38000.0, "steam": -0.25, "req": {"engineering": 30},
		"desc": "Steam straight onto the blades. Quieter, twice the output, and it eats your boiler margin."},
	"dynamo_aether": {"cat": "dynamo", "name": "aetheric tap", "tier": 3, "cost": 3900, "mass": 3.0,
		"power": 64000.0, "req": {"artifice": 50},
		"desc": "No moving parts, no fuel, and a faint smell of a storm about to happen. Draws straight off \
the ambient field, which is free until the day it is not.", "glow": "#9ad8ff"},

	# ================================================================ bunkers
	"bunker_small": {"cat": "bunker", "name": "fuel bunker", "tier": 1, "cost": 220, "mass": 2.0,
		"fuel_cap": 110.0, "desc": "A tank of distillate strapped down against the frames. Flammable, in a wooden \
hull, next to a fire. Skyfarers are not a cautious profession."},
	"bunker_long": {"cat": "bunker", "name": "long-range bunker", "tier": 2, "cost": 620, "mass": 3.4,
		"fuel_cap": 240.0, "desc": "Double the tankage and a baffle inside so it does not slosh you off a heading."},
	"bunker_armored": {"cat": "bunker", "name": "armoured bunker", "tier": 3, "cost": 1500, "mass": 5.0,
		"fuel_cap": 200.0, "armor": 10.0, "quirk": "no_cookoff", "req": {"smithing": 35},
		"desc": "Plated, baffled and self-sealing. It will not go up when something puts a hole in it, which \
distinguishes it from every other bunker ever fitted."},
	"bunker_condenser": {"cat": "bunker", "name": "aether condenser", "tier": 4, "cost": 5200, "mass": 4.0,
		"fuel_cap": 170.0, "quirk": "condense", "req": {"artifice": 55, "distilling": 40},
		"desc": "It makes distillate out of the air, slowly, and faster where the aether runs thick. You will \
never be stranded again. You will also never again be in a hurry."},

	# ================================================================ guns
	"gun_swivel": {"cat": "gun", "name": "swivel gun", "tier": 1, "cost": 700, "mass": 4.0,
		"gun_damage": 22.0, "gun_range": 11.0, "gun_reload": 3.2, "gun_spread": 0.14,
		"desc": "A pintle, a short barrel and a ready rack of shot. Point it and pull. It is not accurate and \
it does not need to be."},
	"gun_harpoon": {"cat": "gun", "name": "harpoon gun", "tier": 1, "cost": 850, "mass": 4.5,
		"gun_damage": 30.0, "gun_range": 9.0, "gun_reload": 4.5, "gun_spread": 0.05, "quirk": "tether",
		"desc": "Built for salvage and repurposed the way everything up here is. The line stays attached, which \
means whatever you hit is now attached to you. Consider this."},
	"gun_carronade": {"cat": "gun", "name": "carronade", "tier": 2, "cost": 1900, "mass": 7.0,
		"gun_damage": 52.0, "gun_range": 8.0, "gun_reload": 5.0, "gun_spread": 0.22, "req": {"gunnery": 25},
		"desc": "A short fat barrel that throws a heavy ball a short distance very hard. Smashers, the yards \
call them, and they mean the ball and the recoil equally."},
	"gun_long": {"cat": "gun", "name": "long nine", "tier": 2, "cost": 2300, "mass": 6.5,
		"gun_damage": 34.0, "gun_range": 20.0, "gun_reload": 4.2, "gun_spread": 0.04, "req": {"gunnery": 30},
		"desc": "Reach. You will hit things that have not noticed you and would prefer to keep it that way."},
	"gun_aether_lance": {"cat": "gun", "name": "aether lance", "tier": 3, "cost": 6400, "mass": 5.5,
		"gun_damage": 46.0, "gun_range": 16.0, "gun_reload": 2.4, "gun_spread": 0.02, "power": -14000.0,
		"quirk": "lance", "req": {"gunnery": 45, "artifice": 40},
		"desc": "A charged bolt rather than a ball. It goes through the first thing it hits and keeps going, so \
line your shot up on two of them.", "glow": "#9ad8ff"},
	"gun_scatter": {"cat": "gun", "name": "scatter rack", "tier": 2, "cost": 1700, "mass": 5.0,
		"gun_damage": 12.0, "gun_range": 6.0, "gun_reload": 2.0, "gun_spread": 0.5, "quirk": "scatter",
		"req": {"gunnery": 20},
		"desc": "Nine small barrels on a frame, fired together. Useless against a hull and devastating against \
anything with wings, which in this sky is most of what attacks you."},

	# ================================================================ helms
	"helm_wheel": {"cat": "helm", "name": "ship's wheel", "tier": 1, "cost": 300, "mass": 1.4,
		"turn": 0.0, "desc": "A spoked wheel on a brass pedestal, linked to the rudder and the engine telegraph. \
Take it and the ship is yours."},
	"helm_binnacle": {"cat": "helm", "name": "binnacle helm", "tier": 2, "cost": 1100, "mass": 2.0,
		"turn": 0.08, "quirk": "readout", "req": {"airmanship": 20},
		"desc": "Wheel, compass, inclinometer and a pressure repeater in one pedestal, so you can fly her without \
looking away from where you are going."},
	"helm_aether": {"cat": "helm", "name": "aether helm", "tier": 3, "cost": 3600, "mass": 2.2,
		"turn": 0.16, "power": -3000.0, "quirk": "autotrim", "req": {"airmanship": 45, "artifice": 30},
		"desc": "It trims the ballast for you, continuously, and it is better at it than you are. Pilots hate it \
for about a week."},

	# ================================================================ navigation
	"nav_table": {"cat": "nav", "name": "navigation table", "tier": 1, "cost": 240, "mass": 1.2,
		"sight": 0.0, "desc": "A chart of this sky, weighted down at the corners. Islands, moorings, and the \
places somebody crossed out."},
	"nav_sounder": {"cat": "nav", "name": "aether sounder", "tier": 2, "cost": 900, "mass": 1.8,
		"sight": 6.0, "power": -1200.0, "quirk": "sound", "req": {"navigation": 20},
		"desc": "It pings the field and listens. Islands, wrecks and large creatures come back as different \
notes, and you learn the difference the hard way once."},
	"nav_oracle": {"cat": "nav", "name": "storm oracle", "tier": 3, "cost": 2800, "mass": 2.0,
		"sight": 10.0, "power": -2400.0, "quirk": "forecast", "req": {"navigation": 45},
		"desc": "A ring of aetherite needles that lean toward pressure. It knows what the weather is going to do \
about twenty minutes before the weather does."},

	# ================================================================ utility
	"util_winch": {"cat": "utility", "name": "cargo winch", "tier": 1, "cost": 520, "mass": 5.0,
		"cargo": 12.0, "power": -400.0, "quirk": "winch",
		"desc": "A drum, a boom and a hundred fathoms of line. This is how salvage gets aboard, and how \
salvage gets aboard is the whole business."},
	"util_bench": {"cat": "utility", "name": "shipwright's bench", "tier": 1, "cost": 380, "mass": 3.0,
		"quirk": "bench", "desc": "Vices, a rack and every tool aboard that has not been lost yet. \
You can work a hull here that you could not work standing on a deck."},
	"util_still": {"cat": "utility", "name": "ship's still", "tier": 2, "cost": 1200, "mass": 4.0,
		"quirk": "still", "power": -800.0, "req": {"distilling": 20},
		"desc": "Copper, coiled, and technically for fuel. What it is actually for depends on the crew."},
	"util_forge": {"cat": "utility", "name": "deck forge", "tier": 2, "cost": 1400, "mass": 6.0,
		"quirk": "forge", "heat_mul": 1.4, "req": {"smithing": 25},
		"desc": "A hearth, a bellows and an anvil bolted to the frames. Do not site it next to the bunker. \
People do."},
	"util_galley": {"cat": "utility", "name": "galley stove", "tier": 1, "cost": 300, "mass": 3.0,
		"quirk": "galley", "desc": "Gimballed, so a pot stays put while the ship does not."},
	"util_medbay": {"cat": "utility", "name": "sick berth", "tier": 2, "cost": 1000, "mass": 3.5,
		"crew": 1, "quirk": "medbay", "desc": "One bunk, a locker of bandages and a strap across the middle. \
It has saved more skyfarers than every gun in this list."},
	"util_hold": {"cat": "utility", "name": "cargo hold frame", "tier": 1, "cost": 160, "mass": 1.0,
		"cargo": 8.0, "desc": "Racking, lashing points and a deck strong enough to stack on. Hold is money."},
	"util_scrubber": {"cat": "utility", "name": "air scrubber", "tier": 1, "cost": 420, "mass": 2.0,
		"power": -1800.0, "quirk": "scrub", "desc": "It takes the exhaust back out of the air you are breathing. \
Above the Reaches this stops being optional."},
	"util_bunk": {"cat": "utility", "name": "crew bunk", "tier": 1, "cost": 120, "mass": 1.2,
		"crew": 1, "desc": "A berth with a lee-board so you do not roll out when she heels."},
	"util_lantern": {"cat": "utility", "name": "deck lantern", "tier": 0, "cost": 45, "mass": 0.4,
		"quirk": "light", "desc": "A shielded oil lamp on a hook. It is worth more than it costs."},
	"util_beacon": {"cat": "utility", "name": "aether beacon", "tier": 3, "cost": 2200, "mass": 2.0,
		"power": -2000.0, "quirk": "beacon", "req": {"artifice": 35},
		"desc": "It marks where you are on every chart in the sky. Useful when you want to be found. \
Consider carefully whether you want to be found.", "glow": "#ffd8a0"},

	# ================================================================ plating
	"armor_planking": {"cat": "armor", "name": "oak planking", "tier": 0, "cost": 0, "mass": 1.4,
		"armor": 0.0, "desc": "The hull she was built with. It keeps the weather out and stops you walking off."},
	"armor_sheathed": {"cat": "armor", "name": "copper sheathing", "tier": 1, "cost": 40, "mass": 1.9,
		"armor": 6.0, "drag_mul": 0.985, "req": {"smithing": 15},
		"desc": "Nailed over the planking. It turns a glancing hit and it stops things growing on the hull, \
which up here is a genuine problem."},
	"armor_plate": {"cat": "armor", "name": "iron plate", "tier": 2, "cost": 95, "mass": 3.2,
		"armor": 16.0, "req": {"smithing": 30},
		"desc": "Bolted strakes of iron. Heavy enough that you will feel it in the climb rate and glad of it \
the first time something shoots at you."},
	"armor_skyglass": {"cat": "armor", "name": "skyglass lamination", "tier": 3, "cost": 260, "mass": 2.1,
		"armor": 22.0, "quirk": "shed", "req": {"smithing": 45, "artifice": 35},
		"desc": "Crystal laminated between two thin plates. It sheds an aether lance instead of absorbing it, \
and the flash is visible from the next island."},
}

# ------------------------------------------------------------------ lookups
static func get_mod(id: String) -> Dictionary:
	return MODULES.get(id, {})

static func exists(id: String) -> bool:
	return MODULES.has(id)

static func stat(id: String, key: String, dflt := 0.0) -> float:
	return float(MODULES.get(id, {}).get(key, dflt))

static func cat_of(id: String) -> String:
	return String(MODULES.get(id, {}).get("cat", ""))

static func name_of(id: String) -> String:
	return String(MODULES.get(id, {}).get("name", id))

static func tier_of(id: String) -> int:
	return int(MODULES.get(id, {}).get("tier", 1))

static func tier_color(id: String) -> String:
	return TIER_COLORS[clampi(tier_of(id), 0, TIER_COLORS.size() - 1)]

static func quirk_of(id: String) -> String:
	return String(MODULES.get(id, {}).get("quirk", ""))

static func has_quirk(id: String, q: String) -> bool:
	return quirk_of(id) == q

## Every module of one category, cheapest first.
static func in_cat(cat: String) -> Array:
	var out := []
	for id in MODULES:
		if MODULES[id]["cat"] == cat:
			out.append(id)
	out.sort_custom(func(a, b): return float(MODULES[a].get("cost", 0)) < float(MODULES[b].get("cost", 0)))
	return out

## Which category each plan glyph cuts a hole for. Several glyphs share the utility
## category, and which utility goes in one is a decision the owner makes.
const GLYPH_CAT := {
	"E": "thruster", "p": "propeller", "m": "mast", "L": "lift", "B": "boiler",
	"G": "dynamo", "T": "bunker", "g": "gun", "h": "helm", "n": "nav",
	"#": "armor", "K": "armor",
}
## The glyphs that are a specific utility rather than a free choice of one.
const GLYPH_UTIL := {
	"C": "util_winch", "d": "util_bench", "f": "util_galley", "M": "util_medbay",
	"s": "util_scrubber", "b": "util_bunk", "*": "util_lantern", "k": "util_hold",
}

## What goes in a hole by default, at a given grade.
##
## Grade is the difference between a hull out of a breaker's yard and one out of a naval
## dock, and it is why a second-hand skiff is affordable and worth upgrading. A grade-0
## skiff is delivered with a brass burner and patched bladders; the same deck plan at
## grade 3 is a very different ship for four times the money.
##
## Picked rather than tabulated, so adding a module to the catalogue automatically makes
## it the thing a high-grade hull is delivered with, and nothing has to be kept in step.
static func default_for(glyph: String, grade := 1) -> String:
	if GLYPH_UTIL.has(glyph):
		return String(GLYPH_UTIL[glyph])
	var cat := String(GLYPH_CAT.get(glyph, ""))
	if cat == "":
		return ""
	var best := ""
	var best_tier := -1
	for id in MODULES:
		var m: Dictionary = MODULES[id]
		if String(m["cat"]) != cat:
			continue
		var t := int(m.get("tier", 1))
		if t > grade:
			continue
		# A hull off the shelf is never delivered with a module that takes a skill to
		# fit. Those are the player's own work, and a frigate that arrived with four
		# stormdrives in it would cost a hundred thousand marks and end the game.
		if not (m.get("req", {}) as Dictionary).is_empty():
			continue
		if t > best_tier:
			best_tier = t
			best = id
	if best == "":
		# nothing at this grade: take the cheapest in the category rather than nothing
		var cheap := in_cat(cat)
		return String(cheap[0]) if not cheap.is_empty() else ""
	return best

## The glyph a module needs in the deck plan. Plating is special: it modifies the hull
## tile it is nailed to rather than occupying a hole of its own.
static func glyph_for(id: String) -> String:
	var c := cat_of(id)
	if c == "armor":
		return "#"
	return String(CATS.get(c, {}).get("glyph", ""))

## Can this module go in a hole cut for that glyph? Utility and armour are flexible;
## everything else wants its own kind of hole.
static func fits_glyph(id: String, glyph: String) -> bool:
	var c := cat_of(id)
	if c == "armor":
		return glyph in ["#", "K"]
	if c == "utility":
		return glyph in ["C", "d", "f", "M", "s", "b", "*", "k", "="]
	return glyph == String(CATS.get(c, {}).get("glyph", ""))

# ------------------------------------------------------------------ descriptions
## The stat line a shop, a panel or a tooltip shows. Only the numbers that are actually
## non-zero, because a wall of zeroes teaches nobody anything.
static func stat_lines(id: String) -> Array:
	var m := get_mod(id)
	if m.is_empty():
		return []
	var out := []
	var add := func(key: String, label: String, suffix := "", scale := 1.0, sign := false):
		if not m.has(key):
			return
		var v := float(m[key]) * scale
		if absf(v) < 0.001:
			return
		out.append("%s %s%s%s" % [label, "+" if sign and v > 0.0 else "", _num(v), suffix])
	add.call("thrust", "thrust", "", 1.0, true)
	add.call("sail", "canvas", " sq ft", 1.0, true)
	add.call("lift", "lift", "% of a stock cell", 100.0)
	add.call("turn", "rudder", "", 1.0, true)
	add.call("steam", "steam", "x", 1.0, true)
	add.call("power", "power", " W", 1.0, true)
	add.call("fuel_cap", "tankage", " units", 1.0, true)
	add.call("cargo", "hold", " t", 1.0, true)
	add.call("armor", "armour", "", 1.0, true)
	add.call("crew", "berths", "", 1.0, true)
	add.call("gun_damage", "shot", " damage")
	add.call("gun_range", "reach", " tiles")
	add.call("gun_reload", "reload", " s")
	add.call("sight", "sight", " tiles", 1.0, true)
	if m.has("drag_mul") and absf(float(m["drag_mul"]) - 1.0) > 0.001:
		var d := (float(m["drag_mul"]) - 1.0) * 100.0
		out.append("drag %s%s%%" % ["+" if d > 0.0 else "", _num(d)])
	if m.has("fuel_mul") and absf(float(m["fuel_mul"]) - 1.0) > 0.001:
		var f := (float(m["fuel_mul"]) - 1.0) * 100.0
		out.append("burn %s%s%%" % ["+" if f > 0.0 else "", _num(f)])
	if m.has("heat_mul") and absf(float(m["heat_mul"]) - 1.0) > 0.001:
		var h := (float(m["heat_mul"]) - 1.0) * 100.0
		out.append("heat %s%s%%" % ["+" if h > 0.0 else "", _num(h)])
	out.append("%s t" % _num(float(m.get("mass", 2.0))))
	return out

static func _num(v: float) -> String:
	if absf(v - roundf(v)) < 0.05:
		return "%d" % int(roundf(v))
	return "%.1f" % v

## What a quirk actually does, in one line, for the shop and the fitting panel.
const QUIRKS := {
	"storm_feed": "Feeds on storm charge: thrust rises sharply inside a thunderhead.",
	"quiet": "Runs quiet. Creatures that hunt by sound lose you far sooner.",
	"steady": "Holds a heading. The wind cannot throw the ship or her crew about.",
	"close_hauled": "Draws usefully from wind on the bow, not just abeam or astern.",
	"storm_proof": "Will not blow out. Full canvas is safe in any weather.",
	"cold_lift": "Lifts harder the colder the air. Best at altitude, best at night.",
	"no_cookoff": "Self-sealing: a hit will not touch off the fuel.",
	"condense": "Slowly distils fuel out of the air. Faster where the aether runs thick.",
	"tether": "The line stays attached. What you hit is dragged along behind you.",
	"lance": "The bolt punches through and keeps going.",
	"scatter": "A cone of shot. Murderous on flyers, useless on a hull.",
	"readout": "Instruments at the wheel: you fly her without looking away.",
	"autotrim": "Trims ballast for you, holding altitude without a hand on it.",
	"sound": "Pings the field: islands, wrecks and large creatures show on the nav.",
	"forecast": "Warns of the weather about twenty minutes before it arrives.",
	"winch": "Lifts heavy salvage aboard from the deck.",
	"bench": "Ship fitting and repair can be done here, faster and cheaper.",
	"still": "Distils fuel and tonics under way.",
	"forge": "Smithing aboard, under way.",
	"galley": "Cooking aboard.",
	"medbay": "Treat wounds properly instead of bleeding on the deck.",
	"scrub": "Pulls exhaust and miasma back out of the ship's air.",
	"light": "Lights the deck.",
	"beacon": "Marks your position on every chart in the sky.",
	"shed": "Sheds energy weapons instead of absorbing them.",
}

static func quirk_text(id: String) -> String:
	var q := quirk_of(id)
	return String(QUIRKS.get(q, ""))

# ------------------------------------------------------------------ as an item
## Modules are bought as crated items and installed from the hold. This is the prototype
## for one, generated rather than hand-written because there are sixty of them and they
## differ only in which module is inside.
static func item_proto(id: String) -> Dictionary:
	var m := get_mod(id)
	var lines: Array = stat_lines(id)
	var q := quirk_text(id)
	var d := String(m.get("desc", ""))
	if not lines.is_empty():
		d += "\n\n[color=#7fd4ff]%s[/color]" % "   ".join(lines)
	if q != "":
		d += "\n[color=#e8a83a]%s[/color]" % q
	d += "\n[i]Carry it to your ship and fit it from the shipwright's rig or the yard panel.[/i]"
	return {
		"name": "%s (crated)" % String(m.get("name", id)),
		"desc": d, "sheet": "items", "spr": _item_sprite(id),
		"comps": {"item": {"w": int(clampf(float(m.get("mass", 2.0)) * 1.6, 3.0, 12.0)), "cat": "material"},
			"shipmodule": {"mod": id}},
		"tags": {"value": int(float(m.get("cost", 100)) * 0.55), "module": id},
	}

static func _item_sprite(id: String) -> String:
	return "mod_" + cat_of(id)

## Install every module prototype into Proto.P. Called once from SkyProto.install().
static func install_items() -> void:
	for id in MODULES:
		Proto.P["mod_" + id] = item_proto(id)
