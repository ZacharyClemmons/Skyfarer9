class_name SkyProto extends RefCounted
## Every prototype Skyfarer adds on top of Artic9's: ship machinery, island scenery,
## ores, and the gear a skyfarer carries. `install()` merges them into Proto.P at boot,
## which keeps the engine's own 850-line prototype table untouched.
##
## Scenery is built from a compact table instead of forty near-identical dictionaries,
## because almost every island prop is the same thing — a sprite, maybe solid, maybe
## flammable, maybe it drops something when you break it.

# ------------------------------------------------------------------ scenery
## [id, name, sprite, flags, hp, desc]
## flags: s solid (blocks movement)  o opaque (blocks sight)  f flammable
##        l gives light              w harvestable with a knife/axe
const PROPS := [
	# --- Verdance
	["sky_oak", "sky oak", "sky_oak", "sof", 120, "A broad, wind-bent tree. Its roots wrap right round the island's lip, which is presumably why the island is still here."],
	["bush_berry", "berry bush", "bush_berry", "fw", 25, "Low and thorny, hung with dark fruit."],
	["wildflowers", "wildflowers", "wildflowers", "f", 8, "A drift of pale flowers that only grow where the aether is thick."],
	["tall_reed", "reeds", "tall_reed", "f", 10, "Tall dry stems that hiss in the wind."],
	["boulder", "boulder", "boulder_0", "so", 90, "A weathered lump of island stone."],
	# --- Thornwild
	["thorn_tree", "thorn tree", "thorn_tree", "sof", 110, "Black bark under a mat of finger-length thorns."],
	["vine_curtain", "hanging vines", "vine_curtain", "of", 20, "A curtain of vine thick enough to hide what is behind it."],
	["fern_giant", "giant fern", "fern_giant", "f", 18, "Fronds taller than you are."],
	["spore_pod", "spore pod", "spore_pod", "f", 12, "A taut sac the size of a head. It twitches when you get close."],
	# --- Bloomrot
	["cap_tower", "cap tower", "cap_tower", "sof", 60, "A fungal stalk grown into a crooked tower, capped in something that glows faintly."],
	["mycelium_mat", "mycelium mat", "mycelium_mat", "", 6, "A pale web of threads knitted through the soil."],
	["puffball", "puffball", "puffball", "f", 10, "Do not step on it. Everyone steps on it."],
	# --- Fenmoor
	["bog_stump", "bog stump", "bog_stump", "sf", 70, "The rotted base of something that was once enormous."],
	["reed_bed", "reed bed", "reed_bed", "f", 12, "Wet reeds standing in black water."],
	["gas_vent", "gas vent", "gas_vent", "", 40, "A crack in the peat breathing out something that catches the light wrong."],
	["fen_lantern", "fen lantern", "fen_lantern", "lf", 14, "A drooping bloom with a cold light in its throat. It is luring something, and it is not you."],
	# --- Cinderpeak / Ashveil
	["cinder_spire", "cinder spire", "cinder_spire", "so", 100, "A chimney of cooled lava, still warm to the hand."],
	["ash_pillar", "ash pillar", "ash_pillar", "so", 55, "Compacted ash, hard as chalk and about as reliable."],
	["burnt_stump", "burnt stump", "burnt_stump", "s", 45, "Charcoal in the shape of a tree."],
	["lava_crust", "lava crust", "lava_crust", "l", 30, "A skin of black rock over something still moving."],
	["obsidian_shard", "obsidian shard", "obsidian_shard", "s", 50, "Volcanic glass, sharp enough to open a boot."],
	["fumarole", "fumarole", "fumarole", "", 40, "A sulfur vent. The rock around it is stained yellow."],
	# --- Dunebank / Saltmere / Glasswaste
	["cactus_sky", "sky cactus", "cactus_sky", "s", 30, "Swollen with water it has no business having up here."],
	["dune_bone", "bleached bone", "dune_bone", "s", 40, "Something big died here a long time ago."],
	["sand_arch", "wind arch", "sand_arch", "so", 120, "Sandstone cut through by a century of wind."],
	["glass_shard", "glass shard", "glass_shard", "s", 25, "A sliver of fused sand standing on end."],
	["salt_pillar", "salt pillar", "salt_pillar", "so", 70, "A column of grey salt, faintly translucent."],
	["brine_pool", "brine pool", "brine_pool", "", 20, "Water so salt it has gone thick."],
	["crust_shelf", "salt crust", "crust_shelf", "", 15, "A crust that crunches underfoot and goes on crunching."],
	["glass_tree", "glass tree", "glass_tree", "so", 80, "Silica grown in a branching lattice. It rings when the wind moves."],
	["prism_shard", "prism shard", "prism_shard", "sl", 45, "It throws a band of colour across the ground."],
	["refraction_pool", "refraction pool", "refraction_pool", "l", 20, "Still water over crystal. The reflection is a moment behind you."],
	# --- Hoarfrost
	["frost_pine", "frost pine", "frost_pine", "sof", 90, "Black needles under a permanent rime."],
	["ice_spire", "ice spire", "ice_spire", "so", 60, "A blade of clear ice taller than a man."],
	["snow_drift", "snow drift", "snow_drift", "", 20, "Heaped and crusted over."],
	["frozen_carcass", "frozen carcass", "frozen_carcass", "s", 55, "Something died mid-stride and has been standing here ever since."],
	# --- Cragspire
	["wind_sculpt", "wind-cut stone", "wind_sculpt", "so", 100, "Scoured into a shape that looks deliberate and is not."],
	["eyrie_nest", "eyrie", "eyrie_nest", "s", 35, "A raft of sticks and salvaged rope. Occupied."],
	["cliff_moss", "cliff moss", "cliff_moss", "", 8, "It grows on the windward side, which is how you find north up here."],
	# --- Boneyard
	["rib_arch", "rib arch", "rib_arch", "so", 130, "One rib of something that used to fly. You can walk under it without stooping."],
	["skull_huge", "vast skull", "skull_huge", "so", 160, "The eye socket is a doorway. Something has made a home in it."],
	["bone_pile", "bone pile", "bone_pile", "", 30, "Picked clean and stacked by something with hands."],
	["marrow_well", "marrow well", "marrow_well", "", 45, "A bore sunk into bone. What comes up is still warm."],
	# --- Hearthmoss / Chalkdowns
	["hearth_tree", "hearth tree", "hearth_tree", "sofw", 130, "Broad and low, with bark you can peel in sheets. It runs warm — put your hand on the trunk on a cold morning and you will understand why people settled these islands first."],
	["moss_bed", "moss bed", "moss_bed", "fw", 12, "Deep enough to sleep on and somebody clearly has."],
	["chalk_figure", "chalk figure", "chalk_figure", "so", 140, "Cut into the turf down to the white, a very long time ago, by people who wanted it seen from the air. It is a person with too many arms."],
	# --- Tanglereef
	["reef_fan", "reef fan", "reef_fan", "ofw", 30, "A lattice of aether-grown coral, taller than you, and it moves when nothing is moving it."],
	["aether_polyp", "aether polyp", "aether_polyp", "flw", 18, "It pulses. Cut one open and the light goes out of it over about a minute."],
	["tide_bell", "tide bell", "tide_bell", "sl", 55, "A hollow growth that rings when the aether runs. Skyfarers use them as gauges and reef-wreckers use them as bait."],
	# --- Rustfall
	["rust_spar", "rust spar", "rust_spar", "so", 90, "A spar off something big, driven into the ground point-first. It has been here long enough to be part of the island."],
	["hull_plate_heap", "heaped plating", "hull_plate_heap", "sw", 70, "Somebody stacked it. Somebody intended to come back for it."],
	# --- Mirrormere
	["mirror_pool", "mirror pool", "mirror_pool", "l", 24, "Perfectly still and rather deeper than the island is thick. Your reflection is a half-second late and you will notice."],
	# --- Emberglass
	["ember_spire", "ember spire", "ember_spire", "sol", 95, "Glass drawn up out of a vent and left standing. It is still warm at the base and it will be for years."],
	# --- Stormcrown
	["lightning_tree", "lightning tree", "lightning_tree", "sofl", 110, "Struck so often it has grown into the shape of the strike. Fulgurite runs through the roots like veins."],
	["storm_spire", "storm spire", "storm_spire", "sol", 130, "Iron-rich rock drawn to a point by a century of weather. Stand somewhere else."],
	["fulgurite", "fulgurite", "fulgurite", "lw", 35, "A glass tube where the lightning went into the ground. Worth taking and awkward to carry."],
	# --- Vergegloom
	["gloom_stalk", "gloom stalk", "gloom_stalk", "sofw", 70, "It grows away from light, which on a lightless island means it grows in every direction at once."],
	["pale_fungus", "pale fungus", "pale_fungus", "fw", 16, "Colourless and cold. It is the only thing down here that will feed you and it is not a pleasure."],
]

## Ores dug out of the island rock.
const ORES := [
	["ore_aetherite", "aetherite ore", "ore_aetherite", "Porous blue rock that pulls upward against your hand. Lift cells run on it.", 45],
	["ore_sulfur", "sulfur ore", "ore_sulfur", "Yellow, crumbly, and it makes your eyes water. Half of what goes into distillate.", 18],
	["ore_skyglass", "skyglass", "ore_skyglass", "Clear crystal that holds a charge. Worth more than it weighs.", 70],
]

# ------------------------------------------------------------------ install
static func install() -> void:
	var P: Dictionary = Proto.P
	for row in PROPS:
		P[row[0]] = _prop(row)
	for row in ORES:
		P[row[0]] = {
			"name": row[1], "desc": row[3], "sheet": "items", "spr": row[2],
			"comps": {"item": {"w": 2, "force": 6, "throwforce": 8, "cat": "material"},
				"stack": {"amount": 1, "material": row[0]}},
			"tags": {"value": row[4]},
		}
	P.merge(SHIP, true)
	P.merge(GEAR, true)
	P.merge(PORT, true)
	P.merge(UTILITY, true)
	SkyItems.install()        # materials, tools, weapons, curios, tonics
	CSkyRod.install()         # what lives in open air and takes a hook
	ShipParts.install_items() # one crated prototype per module in the catalogue
	SkyCrafting.install()     # and one recipe for every one of them

static func _prop(row: Array) -> Dictionary:
	var flags: String = row[3]
	var d := {
		"name": row[1], "desc": row[5], "sheet": "objects", "spr": row[2],
		"integrity": float(row[4]), "z": 0,
		"comps": {},
		"tags": {"anchored": true, "scenery": true},
	}
	if "s" in flags:
		d["comps"]["blocker"] = {"dense": true, "opaque": "o" in flags, "air": false}
	elif "o" in flags:
		d["comps"]["blocker"] = {"dense": false, "opaque": true, "air": false}
	else:
		d["z"] = -1 # flat scenery sits under anything standing on the tile
	if "f" in flags:
		d["comps"]["flammable"] = {}
	if "l" in flags:
		d["comps"]["light"] = {"kind": "always", "radius": 3.0, "color": "#7ad8c8", "energy": 0.5}
	return d

# ------------------------------------------------------------------ ship machinery
const SHIP := {
	"ship_helm": {"name": "ship's wheel", "desc": "A spoked wheel on a brass pedestal, linked to the rudder and the engine order telegraph. \
Take it and the ship is yours.", "sheet": "objects", "spr": "ship_wheel",
		"comps": {"blocker": {"dense": true}, "helm": {}, "machine": {"needs_power": false, "hp": 140}}},
	"ship_nav": {"name": "navigation table", "desc": "A chart of this sky, weighted down at the corners. Islands, moorings, and the \
places somebody crossed out.", "sheet": "objects", "spr": "nav_table",
		"comps": {"blocker": {"dense": true}, "shipnav": {}, "machine": {"needs_power": false, "hp": 100}}},
	"ship_rudder": {"name": "rudder post", "desc": "The head of the rudder, coming up through the deck.", "sheet": "objects", "spr": "rudder_post",
		"comps": {"blocker": {"dense": true}}, "integrity": 150},
	"ship_thruster": {"name": "aether thruster", "desc": "A fuel burner with a throat on it. It shoves the ship along and throws its exhaust \
into whatever room it happens to be standing in.", "sheet": "objects", "spr": "thruster_w",
		"comps": {"blocker": {"dense": true}, "thruster": {}, "machine": {"needs_power": false, "hp": 220}}},
	"ship_propeller": {"name": "propeller nacelle", "desc": "A caged airscrew for fine handling. It does very little and the crew would notice \
at once if it stopped.", "sheet": "objects", "spr": "propeller_e",
		"comps": {"blocker": {"dense": true}, "machine": {"idle": 20.0, "hp": 140}}},
	"lift_cell": {"name": "lift cell", "desc": "A braced bladder of aetherite vapour in a rope harness. This, and only this, is what \
is between the ship and the Deep.", "sheet": "objects", "spr": "lift_cell_0",
		"comps": {"blocker": {"dense": true}, "liftcell": {}}, "integrity": 90},
	"ship_boiler": {"name": "boiler", "desc": "Riveted iron with a firebox at the bottom and a gauge on the front. Read the gauge.", "sheet": "objects", "spr": "boiler",
		"comps": {"blocker": {"dense": true}, "boiler": {}, "machine": {"needs_power": false, "hp": 260}}},
	"ship_dynamo": {"name": "dynamo", "desc": "Belted off the boiler. Everything electrical aboard hangs off this one machine.", "sheet": "objects", "spr": "dynamo",
		"comps": {"blocker": {"dense": true}, "powergen": {"kind": "dynamo", "max_output": 16000.0}, "machine": {"needs_power": false, "hp": 200}}},
	"ship_apc": {"name": "ship's breaker panel", "desc": "Where the dynamo's output is split between lights, machines and the air plant.", "sheet": "objects", "spr": "apc", "wall": true,
		"comps": {"apc": {}, "machine": {"needs_power": false, "hp": 100}}},
	"fuel_bunker": {"name": "fuel bunker", "desc": "A tank of aether distillate strapped down against the frames. Flammable, in a wooden \
hull, next to a fire. Skyfarers are not a cautious profession.", "sheet": "objects", "spr": "fuel_bunker",
		"comps": {"blocker": {"dense": true}, "fuelbunker": {}}, "integrity": 120},
	"ballast_tank": {"name": "ballast tank", "desc": "Pumped full to sink, blown empty to rise. The slow way to change altitude, and the \
one that does not cost fuel.", "sheet": "objects", "spr": "ballast_tank",
		"comps": {"blocker": {"dense": true}}, "integrity": 140},
	"ship_mast": {"name": "mast", "desc": "A spar and a furled sail. Free speed, if the wind is going your way.", "sheet": "objects", "spr": "ship_mast",
		"comps": {"blocker": {"dense": true}}, "integrity": 110},
	"gun_mount": {"name": "gun mount", "desc": "A swivel gun on a pintle, with a ready rack of shot bolted beside it.", "sheet": "objects", "spr": "gun_e",
		"comps": {"blocker": {"dense": true}}, "integrity": 180},
	"cargo_winch": {"name": "cargo winch", "desc": "A drum, a boom and a hundred fathoms of line. How salvage gets aboard.", "sheet": "objects", "spr": "cargo_winch",
		"comps": {"blocker": {"dense": true}, "machine": {"idle": 30.0, "active_w": 400.0, "hp": 200}}},
	"deck_lantern": {"name": "deck lantern", "desc": "A shielded oil lamp on a hook.", "sheet": "objects", "spr": "deck_lantern",
		"comps": {"light": {"kind": "always", "radius": 5.5, "color": "#ffd8a0", "energy": 0.85}}, "z": 0},
	"ship_door": {"name": "cabin door", "desc": "A light interior door.", "sheet": "objects", "spr": "airlock_generic_0",
		"comps": {"blocker": {"dense": true, "air": true, "opaque": false},
			"door": {"dept": "generic", "access": []}, "machine": {"needs_power": false, "hp": 160}}},
	"ship_airlock": {"name": "hull hatch", "desc": "A sealing hatch through the hull. Shut it before you climb.", "sheet": "objects", "spr": "airlock_ext_0",
		"comps": {"blocker": {"dense": true, "air": true, "opaque": false},
			"door": {"dept": "ext", "access": []}, "machine": {"needs_power": false, "hp": 200}}},
	"bunk": {"name": "bunk", "desc": "A crew berth with a lee-board so you do not roll out when the ship heels.", "sheet": "objects", "spr": "bed_0",
		"comps": {"furniture": {"kind": "bed"}}},
	"workbench": {"name": "workbench", "desc": "Vices, a cluttered rack, and every tool aboard that has not been lost yet.", "sheet": "objects", "spr": "table_wood",
		"comps": {"blocker": {"dense": true}, "furniture": {"kind": "table"}}},
	"galley_stove": {"name": "galley stove", "desc": "Gimballed, so a pot stays put while the ship does not.", "sheet": "objects", "spr": "galley_stove",
		"comps": {"blocker": {"dense": true}, "cooker": {}, "machine": {"needs_power": false, "hp": 140}}},
}

# ------------------------------------------------------------------ a skyfarer's gear
const GEAR := {
	"fuel_can": {"name": "fuel can", "desc": "Forty units of aether distillate. Keep it away from the boiler, which is difficult, \
because the boiler is what needs it.", "sheet": "items", "spr": "fuel_can",
		"comps": {"item": {"w": 3, "force": 8, "cat": "material"}, "flammable": {}},
		"tags": {"fuel": 40.0}},
	"glider_pack": {"name": "glider harness", "desc": "Folded silk and cane in a back harness. Pull the ring while falling and you get to \
choose where you land — roughly.", "sheet": "items", "spr": "glider_pack",
		"comps": {"item": {"w": 4, "cat": "clothing", "slots": ["back"]},
			"clothing": {"slot": "back", "sprite": "back_glider", "colors": ["#c8b088", "#6a5a48"]},
			"glider": {}}},
	"grapple_gun": {"name": "grapple launcher", "desc": "A barbed hook on a drum of line. Fires at a ledge, a rail, or a person who is \
about to stop being on the ship.", "sheet": "items", "spr": "grapple_gun",
		"comps": {"item": {"w": 3, "force": 8, "cat": "tool", "slots": ["belt", "back"]}, "grapple": {}}},
	"sky_compass": {"name": "aether compass", "desc": "The needle does not point north. It points at the nearest island, which is far \
more useful.", "sheet": "items", "spr": "sky_compass",
		"comps": {"item": {"w": 1, "cat": "tool", "slots": ["belt", "pocket_l", "pocket_r"]}, "skycompass": {}}},
	"spyglass": {"name": "spyglass", "desc": "Brass, scratched, and worth more than the coat you are wearing.", "sheet": "items", "spr": "spyglass",
		"comps": {"item": {"w": 2, "cat": "tool", "slots": ["belt", "pocket_l", "pocket_r"]}, "spyglass": {}}},
	"breathing_rig": {"name": "altitude rig", "desc": "A mask and a small bottle. Above the Reaches the air is not a courtesy any more.", "sheet": "items", "spr": "breathing_rig",
		"comps": {"item": {"w": 3, "cat": "clothing", "slots": ["mask"]},
			"clothing": {"slot": "mask", "sprite": "mask_breath", "pressure": true, "colors": ["#4a5262", "#b0b8c4"]}}},
	"ship_rig": {"name": "shipwright's rig", "desc": "A strap of saws, braces and fixings. Z picks what it builds; click a tile beside your ship to work on it. Everything you fit becomes part of her — it moves with her, it weighs something, and if you close a space it starts holding air.", "sheet": "items", "spr": "ship_rig",
		"comps": {"item": {"w": 3, "force": 8, "cat": "tool", "slots": ["belt", "back"]}, "shiprig": {}}},
	"salvage_scrap": {"name": "salvaged scrap", "desc": "Bent plate, cut cable and a bearing that still turns. Worth something to the right \
yard.", "sheet": "items", "spr": "salvage_scrap",
		"comps": {"item": {"w": 3, "cat": "material"}, "stack": {"amount": 1, "material": "scrap"}},
		"tags": {"value": 30}},
	"chart_scrap": {"name": "torn chart", "desc": "A corner of somebody's chart. There is an island marked on it that is not on yours.", "sheet": "items", "spr": "paper",
		"comps": {"item": {"w": 1, "cat": "misc"}}, "tags": {"value": 60}},
}

# ------------------------------------------------------------------ utility fittings
## The other things a utility mounting can hold. A winch, a bench and a galley stove
## already existed; these are the ones the module catalogue added.
const UTILITY := {
	"deck_forge": {"name": "deck forge", "desc": "A hearth, a bellows and an anvil bolted to the frames. \
Do not site it next to the bunker. People do.", "sheet": "objects", "spr": "galley_stove",
		"comps": {"blocker": {"dense": true}, "cooker": {}, "machine": {"needs_power": false, "hp": 220},
			"light": {"kind": "always", "radius": 4.0, "color": "#ff9a4a", "energy": 0.8}},
		"tags": {"anchored": true, "station": "forge"}},
	"ship_still": {"name": "ship's still", "desc": "Copper, coiled, and technically for fuel. What it is \
actually for depends on the crew.", "sheet": "objects", "spr": "fuel_bunker",
		"comps": {"blocker": {"dense": true}, "machine": {"idle": 400.0, "hp": 160}},
		"tags": {"anchored": true, "station": "still"}},
	"aether_beacon": {"name": "aether beacon", "desc": "It marks where you are on every chart in the sky. \
Useful when you want to be found. Consider carefully whether you want to be found.",
		"sheet": "objects", "spr": "lift_cell_0",
		"comps": {"blocker": {"dense": true}, "machine": {"idle": 2000.0, "hp": 120},
			"light": {"kind": "always", "radius": 9.0, "color": "#ffd8a0", "energy": 1.2}},
		"tags": {"anchored": true}},
	"loom": {"name": "sail loft frame", "desc": "A standing frame with a bolt half woven on it and a great \
deal of somebody's patience.", "sheet": "objects", "spr": "table_wood",
		"comps": {"blocker": {"dense": true}, "furniture": {"kind": "table"}},
		"tags": {"anchored": true, "station": "loom"}},
}


# ------------------------------------------------------------------ ports
## The furniture of a trading post. Small list, because what makes a port feel like a
## place is the people in it and the shape of the buildings, not the props.
const PORT := {
	"port_lantern": {"name": "quay lantern", "desc": "A tall iron post with a shuttered lamp on top. They are lit from dusk by somebody whose whole job it is.", "sheet": "objects", "spr": "port_lantern",
		"comps": {"blocker": {"dense": true}, "light": {"kind": "always", "radius": 7.0, "color": "#ffd8a0", "energy": 1.0}},
		"integrity": 120, "tags": {"anchored": true}},
	"port_sign": {"name": "shop sign", "desc": "Painted board on an iron bracket.", "sheet": "objects",
		"spr": "port_sign", "wall": true, "z": 0, "tags": {"anchored": true}},
	"yard_desk": {"name": "yard master's desk", "desc": "A drawing board, a rack of hull plans and a ledger of everything the yard has ever put in the air. The yard master will let you draw on it if you can pay for what you draw.", "sheet": "objects", "spr": "yard_desk",
		"comps": {"blocker": {"dense": true}, "shipyard": {}}, "integrity": 180,
		"tags": {"anchored": true}},
	"notice_board": {"name": "notice board", "desc": "Charts, warnings, prices and three notices about a missing ship. The whole sky is written on this board if you read it properly.",
		"sheet": "objects", "spr": "notice_board", "wall": true,
		"comps": {"noticeboard": {}}, "integrity": 90, "tags": {"anchored": true}},
	# ---- shop fittings. Each trade's room is dressed out of this list, which is what
	# makes a doorway legible before you have read the sign.
	"shop_lamp": {"name": "hanging lamp", "desc": "A shaded lamp on a chain, trimmed low.",
		"sheet": "objects", "spr": "deck_lantern", "z": 0,
		"comps": {"light": {"kind": "always", "radius": 6.5, "color": "#ffd8a0", "energy": 0.9}},
		"tags": {"anchored": true}},
	"shop_mat": {"name": "painted step", "desc": "A square of colour painted onto the quay outside a door. Every shop on the front has one and no two are the same, which is the entire point of them.",
		"sheet": "objects", "spr": "shop_mat", "z": -1, "tags": {"anchored": true, "scenery": true}},
	"sheet_stack": {"name": "stacked plate", "desc": "Iron sheet, cut to size and stacked by thickness.",
		"sheet": "objects", "spr": "hull_plate_heap",
		"comps": {"blocker": {"dense": true}}, "integrity": 90, "tags": {"anchored": true}},
	"canvas_roll": {"name": "rolled canvas", "desc": "Bolts of tarred canvas standing on end, each one a mast's worth and each one heavier than it looks.", "sheet": "objects", "spr": "canvas_roll",
		"comps": {"blocker": {"dense": true}}, "integrity": 60, "tags": {"anchored": true}},
	"gun_rack": {"name": "gun rack", "desc": "Barrels stood in a rack, muzzles up, with a chain through the trigger guards and a notice about who has the key.", "sheet": "objects", "spr": "gun_rack",
		"comps": {"blocker": {"dense": true}}, "integrity": 120, "tags": {"anchored": true}},
	"instrument_case": {"name": "instrument case", "desc": "Glass over green baize, and a row of things that are all pointing very slightly differently.", "sheet": "objects", "spr": "instrument_case",
		"comps": {"blocker": {"dense": true},
			"light": {"kind": "always", "radius": 2.2, "color": "#9ad8ff", "energy": 0.4}},
		"integrity": 70, "tags": {"anchored": true}},
	"curio_shelf": {"name": "curiosity shelf", "desc": "Objects of uncertain provenance, arranged by somebody with a system they have not explained.", "sheet": "objects", "spr": "curio_shelf",
		"comps": {"blocker": {"dense": true},
			"light": {"kind": "always", "radius": 2.0, "color": "#c88ae8", "energy": 0.35}},
		"integrity": 70, "tags": {"anchored": true}},
	"ledger_desk": {"name": "broker's desk", "desc": "Brass scales, a stack of contracts, and a ledger open at a page with a great many names crossed out.", "sheet": "objects", "spr": "yard_desk",
		"comps": {"blocker": {"dense": true}}, "integrity": 120, "tags": {"anchored": true}},
	"barrel": {"name": "barrel", "desc": "Water, salt pork, or distillate. The chalk mark says which and the chalk mark is frequently wrong.", "sheet": "objects", "spr": "barrel",
		"comps": {"blocker": {"dense": true}}, "integrity": 80, "tags": {"anchored": false}},
	"bollard": {"name": "bollard", "desc": "Cast iron, sunk into the quay, with a century of rope-burn worn into the neck of it.", "sheet": "objects", "spr": "bollard",
		"comps": {"blocker": {"dense": true}}, "integrity": 220, "tags": {"anchored": true}},
	"rope_coil": {"name": "coil of rope", "desc": "Flaked down properly, which means somebody here knows their trade.", "sheet": "objects", "spr": "rope_coil", "z": -1, "tags": {"anchored": false}},
	"quay_crate": {"name": "cargo crate", "desc": "Stencilled for somewhere else. It has been waiting a while.", "sheet": "objects", "spr": "quay_crate",
		"comps": {"blocker": {"dense": true}}, "integrity": 60, "tags": {"anchored": false}},
	"star_dust": {"name": "scattered starlight", "desc": "Cold light on the ground, burning quietly through.", "sheet": "objects", "spr": "star_dust", "z": -1,
		"comps": {"light": {"kind": "always", "radius": 5.5, "color": "#d8e8ff", "energy": 0.95}},
		"tags": {"anchored": true}},
}
