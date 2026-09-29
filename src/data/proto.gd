class_name Proto extends RefCounted
## Entity prototypes (like tg's typepaths). `spawn(id, cell, overrides)` builds an Entity
## from data: sprite + a dictionary of components with their parameters.

const TOOL_SLOTS := ["belt", "pocket_l", "pocket_r"]

static var P := {
	# ------------------------------------------------------------- tools
	"wrench": {"name": "wrench", "desc": "A wrench with common uses. Can be found in your hand.", "sheet": "items", "spr": "wrench",
		"comps": {"item": {"icon": "wrench", "w": 2, "force": 5, "throwforce": 7, "demo": 1.25, "tool": "wrench", "cat": "tool", "verb": "bashes", "slots": TOOL_SLOTS}}},
	"crowbar": {"name": "crowbar", "desc": "A small crowbar. Opens unpowered doors; also persuades people.", "sheet": "items", "spr": "crowbar",
		"comps": {"item": {"w": 2, "force": 5, "throwforce": 7, "demo": 1.25, "tool": "crowbar", "cat": "tool", "verb": "smacks", "slots": TOOL_SLOTS}}},
	"screwdriver": {"name": "screwdriver", "desc": "You can be totally screwy with this.", "sheet": "items", "spr": "screwdriver",
		"comps": {"item": {"w": 1, "force": 5, "throwforce": 5, "sharp": "pointy", "demo": 0.5, "tool": "screwdriver", "cat": "tool", "verb": "stabs", "slots": TOOL_SLOTS}}},
	"wirecutters": {"name": "wirecutters", "desc": "This cuts wires.", "sheet": "items", "spr": "wirecutters",
		"comps": {"item": {"w": 2, "force": 6, "tool": "wirecutters", "cat": "tool", "verb": "pinches", "slots": TOOL_SLOTS}}},
	"welder": {"name": "blowtorch", "desc": "A brass blowtorch on a hose of fuel. Z to light it.", "sheet": "items", "spr": "welder",
		"comps": {"item": {"w": 2, "force": 3, "throwforce": 5, "wound": 10, "exposed": 15, "tool": "welder", "cat": "tool", "verb": "burns", "slots": TOOL_SLOTS}, "welder": {},
			"light": {"kind": "item", "radius": 2.5, "color": "#9ad8ff", "energy": 0.8, "on": false}}},
	"multitool": {"name": "multitool", "desc": "Used for pulsing wires and tuning aether fittings.", "sheet": "items", "spr": "multitool",
		"comps": {"item": {"w": 2, "force": 5, "tool": "multitool", "cat": "tool", "slots": TOOL_SLOTS}}},
	"cable_coil": {"name": "cable coil", "desc": "A coil of insulated power cable.", "sheet": "items", "spr": "cable_coil",
		"comps": {"item": {"w": 2, "cat": "material", "slots": TOOL_SLOTS}, "stack": {"amount": 30, "material": "cable"}}},
	"sheet_metal": {"name": "metal sheets", "desc": "Sheets of metal. Build walls and floors.", "sheet": "items", "spr": "sheet_metal",
		"comps": {"item": {"conducts": true, "w": 3, "force": 5, "throwforce": 10, "cat": "material"}, "stack": {"amount": 20, "material": "metal"}}},
	"sheet_glass": {"name": "glass sheets", "desc": "Sheets of glass. Two on a grille make a window; add rods to reinforce them.", "sheet": "items", "spr": "sheet_glass",
		"comps": {"item": {"w": 3, "cat": "material"}, "stack": {"amount": 10, "material": "glass"}}},
	"sheet_rglass": {"name": "reinforced glass", "desc": "Glass which seems to have rods or something stuck in them. Two on a grille make a reinforced window.", "sheet": "items", "spr": "sheet_rglass",
		"comps": {"item": {"w": 3, "cat": "material"}, "stack": {"amount": 1, "material": "rglass"}}},
	"pipe_fitting": {"name": "pipe fitting", "desc": "A length of smart pipe. It joins whatever pipes are next to it.", "sheet": "items", "spr": "pipe_item_supply",
		"comps": {"item": {"w": 3, "force": 8, "cat": "material"}, "pipefitting": {}}},
	"rcd": {"name": "shipwright's press", "desc": "A brass-and-aether press that raises and strikes bulkheads, decking and hatches at a squeeze. Z to pick what it builds; feed it plate or packed-aether cartridges.", "sheet": "items", "spr": "rcd",
		"comps": {"item": {"w": 3, "force": 10, "throwforce": 10, "conducts": true, "cat": "tool", "slots": ["belt"]}, "rcd": {}}},
	"spacecash": {"name": "bundle of marks", "desc": "It's worth 1000 marks. Probably.", "sheet": "items", "spr": "paper", "tint": "#8ae88a",
		"comps": {"item": {"w": 1, "cat": "valuable", "slots": TOOL_SLOTS}}},
	"rcd_ammo": {"name": "packed-aether cartridge", "desc": "Aether packed hard into a brass case for the shipwright's press. 160 units.", "sheet": "items", "spr": "rcd_ammo",
		"comps": {"item": {"w": 2, "cat": "material", "slots": TOOL_SLOTS}}},
	"rpd": {"name": "pipefitter's press", "desc": "A device used to lay pipe at a squeeze. Z to pick what it lays.", "sheet": "items", "spr": "rpd",
		"comps": {"item": {"w": 3, "force": 10, "throwforce": 10, "conducts": true, "cat": "tool", "slots": ["belt"]}, "rpd": {}}},
	# ------------------------------------------------------------- tg armour, EVA and ballistics
	"armor_vest": {"name": "plated vest", "desc": "A layered leather-and-plate vest that gives decent protection against most kinds of damage.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 3, "cat": "clothing", "slots": ["suit"]}, "clothing": {"wound": 10.0, "slot": "suit", "sprite": "suit_armor", "armor": 0.35, "bullet": 30.0, "laser": 30.0, "energy": 40.0, "covers": ["chest"], "insulation": 0.1, "colors": ["#3a3f4a", "#5a6272"]}}},
	"bulletproof_vest": {"name": "shot-proof vest", "desc": "A heavy, quilted vest with steel inserts that excels at stopping shot and, to a lesser degree, blast.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 3, "cat": "clothing", "slots": ["suit"]}, "clothing": {"wound": 20.0, "slot": "suit", "sprite": "suit_armor", "armor": 0.15, "bullet": 60.0, "laser": 10.0, "energy": 10.0, "covers": ["chest"], "insulation": 0.1, "slow": 0.05, "colors": ["#4a4a3a", "#6a6a52"]}}},
	"reflector_vest": {"name": "mirrored vest", "desc": "A vest of polished plate that excels at turning aside lance-fire.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 3, "cat": "clothing", "slots": ["suit"]}, "clothing": {"slot": "suit", "sprite": "suit_armor", "armor": 0.1, "bullet": 10.0, "laser": 60.0, "energy": 60.0, "covers": ["chest"], "insulation": 0.1, "colors": ["#c8ccd4", "#9fd0ec"]}}},
	"riot_armor": {"name": "boarding harness", "desc": "A suit of lacquered, quilted armour with heavy padding, made to take a beating in a boarding melee.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 4, "cat": "clothing", "slots": ["suit"]}, "clothing": {"wound": 20.0, "slot": "suit", "sprite": "suit_armor", "armor": 0.5, "bullet": 10.0, "laser": 10.0, "energy": 10.0, "covers": ["chest", "l_arm", "r_arm", "l_leg", "r_leg", "l_hand", "r_hand", "l_foot", "r_foot"], "insulation": 0.2, "slow": 0.1, "colors": ["#2a2e3a", "#4a5262"]}}},
	"helmet_sec": {"name": "helmet", "desc": "Standard Watch issue. Protects the head from impacts.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 2, "cat": "clothing", "slots": ["head"]}, "clothing": {"wound": 10.0, "slot": "head", "sprite": "head_helmet", "armor": 0.35, "bullet": 30.0, "laser": 30.0, "insulation": 0.1, "colors": ["#8a2a33", "#9fd0ec"]}}},
	"helmet_riot": {"name": "boarding helm", "desc": "A helm designed to take close-range blows.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 2, "cat": "clothing", "slots": ["head"]}, "clothing": {"wound": 10.0, "slot": "head", "sprite": "head_helmet", "armor": 0.5, "bullet": 10.0, "laser": 10.0, "insulation": 0.1, "hides_hair": true, "colors": ["#2a2e3a", "#9fd0ec"]}}},
	"hardhat": {"name": "hard hat", "desc": "A piece of headgear used in dangerous working conditions to protect the head.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 2, "cat": "clothing", "slots": ["head"]}, "clothing": {"wound": 10.0, "slot": "head", "sprite": "head_hardhat", "armor": 0.15, "insulation": 0.05, "colors": ["#e8c83a", "#fff4d8"]}}},
	"eva_suit": {"name": "high-altitude suit", "desc": "A sealed, brass-ringed suit that protects the wearer from thin air and the killing cold of the upper sky. Warm, too.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 4, "cat": "clothing", "slots": ["suit"]}, "clothing": {"slot": "suit", "sprite": "suit_hazard", "insulation": 0.9, "heat": 0.2, "pressure": true, "slow": 0.35, "colors": ["#e8eef4", "#d84a4a", "#c8ccd4"]}}},
	"eva_helmet": {"name": "high-altitude helm", "desc": "A sealed brass helm with a glass port. It protects the wearer from thin air and the killing cold of the upper sky.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 3, "cat": "clothing", "slots": ["head"]}, "clothing": {"slot": "head", "sprite": "head_helmet", "insulation": 0.3, "pressure": true, "hides_hair": true, "colors": ["#e8eef4", "#9fd0ec"]}}},
	"revolver": {"name": "six-shot revolver", "desc": "A classic, if not outdated, Watch sidearm. Load it with a box of rounds; Z unloads it.", "sheet": "items", "spr": "revolver",
		"comps": {"item": {"w": 2, "force": 10, "conducts": true, "cat": "weapon", "slots": ["belt", "pocket_l", "pocket_r"]}, "gadget": {"kind": "ballistic", "sub": "revolver", "charges": 6}}},
	"shotgun": {"name": "scattergun", "desc": "A sturdy scattergun with a long tube and a fixed stock, meant for clearing a deck without killing what is on it. Load shells into it; Z racks it.", "sheet": "items", "spr": "shotgun",
		"comps": {"item": {"w": 4, "force": 10, "conducts": true, "cat": "weapon", "slots": ["back"]}, "gadget": {"kind": "ballistic", "sub": "shotgun", "charges": 6}}},
	"ammo_38": {"name": "revolver rounds", "desc": "A box of lethal revolver rounds.", "sheet": "items", "spr": "ammo_38",
		"comps": {"item": {"w": 1, "cat": "weapon", "slots": TOOL_SLOTS}, "stack": {"amount": 6, "material": "ammo"}}},
	"ammo_38_rubber": {"name": "rubber revolver rounds", "desc": "A box of rubber revolver rounds: they hurt and wind, rarely wound.", "sheet": "items", "spr": "ammo_38_rubber",
		"comps": {"item": {"w": 1, "cat": "weapon", "slots": TOOL_SLOTS}, "stack": {"amount": 6, "material": "ammo"}}},
	"shell_beanbag": {"name": "padded slugs", "desc": "Low-velocity padded shells: a lot of stamina damage.", "sheet": "items", "spr": "shell_beanbag",
		"comps": {"item": {"w": 1, "cat": "weapon", "slots": TOOL_SLOTS}, "stack": {"amount": 6, "material": "ammo"}}},
	"shell_buckshot": {"name": "buckshot shells", "desc": "A heavy buckshot shell: six pellets.", "sheet": "items", "spr": "shell_buckshot",
		"comps": {"item": {"w": 1, "cat": "weapon", "slots": TOOL_SLOTS}, "stack": {"amount": 6, "material": "ammo"}}},
	"shell_slug": {"name": "shotgun slugs", "desc": "A heavy lead slug.", "sheet": "items", "spr": "shell_slug",
		"comps": {"item": {"w": 1, "cat": "weapon", "slots": TOOL_SLOTS}, "stack": {"amount": 6, "material": "ammo"}}},
	"spent_shell": {"name": "spent scattergun shell", "desc": "An empty casing ejected from a scattergun.", "sheet": "items", "spr": "shell_beanbag",
		"comps": {"item": {"w": 1, "cat": "misc"}}},
	"shell_rubbershot": {"name": "rubber shot shells", "desc": "Six rubber pellets per shell, for breaking up a crowd.", "sheet": "items", "spr": "shell_beanbag",
		"comps": {"item": {"w": 1, "cat": "weapon", "slots": TOOL_SLOTS}, "stack": {"amount": 6, "material": "ammo"}}},
	"he_pipe": {"name": "heat exchanger fins", "desc": "Heat-exchanging pipe: fins on the pipe trade heat with what is around them. Out in the open sky, they cool whatever runs through.", "sheet": "objects", "spr": "he_fins", "z": -1,
		"comps": {"hepipe": {}}},
	"igniter": {"name": "igniter", "desc": "It's useful for igniting gas. Click it to switch it on and off.", "sheet": "objects", "spr": "igniter", "z": -1,
		"comps": {"machine": {"idle": 2.0, "active_w": 50.0, "hp": 80}, "fixture": {"kind": "igniter"}}},
	"sheet_wood": {"name": "wooden planks", "desc": "One can only guess that this is a bunch of wood.", "sheet": "items", "spr": "sheet_wood",
		"comps": {"item": {"w": 3, "force": 5, "cat": "material"}, "stack": {"amount": 10, "material": "wood"}}},
	"floor_tile": {"name": "deck tile", "desc": "A tile of decking. Use it on plating to lay a deck.", "sheet": "items", "spr": "floor_tile",
		"comps": {"item": {"w": 2, "force": 6, "throwforce": 10, "cat": "material"}, "stack": {"amount": 4, "material": "tile"}}},
	"wallframe": {"name": "wall frame", "desc": "A fixture taken off a wall. Stand under a wall and use it on the floor there to hang it back up.", "sheet": "items", "spr": "wallframe",
		"comps": {"item": {"w": 2, "cat": "material"}}},
	"circuit_board": {"name": "circuit board", "desc": "A brass circuit board for a machine. Slot it into a wired frame.", "sheet": "items", "spr": "circuit_board",
		"comps": {"item": {"w": 1, "cat": "material", "slots": TOOL_SLOTS}}},
	"machine_frame": {"name": "machine frame", "desc": "The frame of a machine.", "sheet": "objects", "spr": "machine_frame_0",
		"comps": {"blocker": {"dense": true}, "frame": {"kind": "machine"}}, "tags": {"anchored": false}},
	"computer_frame": {"name": "computer frame", "desc": "The frame of a computer.", "sheet": "objects", "spr": "computer_frame_0",
		"comps": {"blocker": {"dense": true}, "frame": {"kind": "computer"}}, "tags": {"anchored": false}},
	"rods": {"name": "metal rods", "desc": "Some rods. Can be used for building, or something.", "sheet": "items", "spr": "rods",
		"comps": {"item": {"conducts": true, "w": 3, "force": 9, "throwforce": 10, "demo": 1.25, "cat": "material"}, "stack": {"amount": 10, "material": "rods"}}},
	"sheet_plasma": {"name": "plasma sheets", "desc": "Solid plasma. Generator fuel. Highly flammable.", "sheet": "items", "spr": "sheet_plasma",
		"comps": {"item": {"w": 2, "cat": "material"}, "stack": {"amount": 5, "material": "plasma"}}},
	"extinguisher": {"name": "fire extinguisher", "desc": "A traditional red fire extinguisher. Click toward a fire to spray.", "sheet": "items", "spr": "extinguisher",
		"comps": {"item": {"w": 4, "force": 13, "throwforce": 13, "demo": 1.25, "cat": "extinguisher", "verb": "slams"}, "extinguisher": {}}},
	"toolbox": {"name": "rigger's tool chest", "desc": "A rigger's chest of hand tools. Heavy enough to double as a weapon.", "sheet": "items", "spr": "toolbox_blue",
		"comps": {"item": {"conducts": true, "w": 4, "force": 13, "throwforce": 13, "wound": 5, "demo": 1.25, "cat": "tool", "verb": "robusts"}, "storage": {"kind": "bag", "capacity": 14, "max_w": 3}}, "fill": ["wrench", "crowbar", "screwdriver", "wirecutters", "welder"]},
	"toolbox_elec": {"name": "wiring tool chest", "desc": "A chest of wiring tools. Heavy enough to double as a weapon.", "sheet": "items", "spr": "toolbox_yellow",
		"comps": {"item": {"conducts": true, "w": 4, "force": 13, "throwforce": 13, "wound": 5, "demo": 1.25, "cat": "tool", "verb": "robusts"}, "storage": {"kind": "bag", "capacity": 14, "max_w": 3}}, "fill": ["screwdriver", "wirecutters", "multitool", "cable_coil"]},
	"toolbox_emerg": {"name": "emergency tool chest", "desc": "A chest of patch-up tools for when things go wrong at altitude. Heavy enough to double as a weapon.", "sheet": "items", "spr": "toolbox_red",
		"comps": {"item": {"conducts": true, "w": 4, "force": 13, "throwforce": 13, "wound": 5, "demo": 1.25, "cat": "tool", "verb": "robusts"}, "storage": {"kind": "bag", "capacity": 14, "max_w": 3}}, "fill": ["crowbar", "extinguisher_mini", "flashlight"]},
	"extinguisher_mini": {"name": "pocket fire extinguisher", "desc": "A light and compact extinguisher.", "sheet": "items", "spr": "extinguisher",
		"comps": {"item": {"w": 2, "force": 3, "throwforce": 2, "cat": "extinguisher", "slots": TOOL_SLOTS}, "extinguisher": {}}},
	"flashlight": {"name": "hand lantern", "desc": "A hooded hand lantern. Z to toggle.", "sheet": "items", "spr": "flashlight",
		"comps": {"item": {"w": 2, "cat": "tool", "slots": TOOL_SLOTS}, "togglelight": {"on": "flashlight_on", "off": "flashlight"},
			"light": {"kind": "item", "radius": 5.5, "color": "#fff4d8", "energy": 0.9, "on": false}}},
	"t_scanner": {"name": "sounding scope", "desc": "An aether-sounding scope used to find cables and pipes hidden under the decking. Z to switch it on.", "sheet": "items", "spr": "t_scanner",
		"comps": {"item": {"w": 2, "cat": "tool", "slots": TOOL_SLOTS}, "tray": {}}},
	"glowstick": {"name": "glow vial", "desc": "A sealed vial of glowing lichen-jelly.", "sheet": "items", "spr": "glowstick",
		"comps": {"item": {"w": 1, "cat": "tool", "slots": TOOL_SLOTS}, "light": {"kind": "item", "radius": 3.5, "color": "#5aff9a", "energy": 0.7, "on": false}, "gadget": {"kind": "glowstick", "burn": 600.0}}},
	"pickaxe": {"name": "pickaxe", "desc": "Breaks stone and ore. Click on rock to mine.", "sheet": "items", "spr": "pickaxe",
		"comps": {"item": {"w": 4, "force": 15, "throwforce": 10, "demo": 1.15, "tool": "dig", "cat": "tool", "verb": "picks", "slots": ["back", "belt"]}}},
	# ------------------------------------------------------------- tg melee weapons
	"fireaxe": {"name": "fire axe", "desc": "For cutting fouled rigging and hewing through a burning bulkhead. Z to wield it with both hands.", "sheet": "items", "spr": "fireaxe",
		"comps": {"item": {"conducts": true, "w": 4, "force": 5, "wield": 24, "throwforce": 15, "sharp": "edged", "wound": -15, "exposed": 20, "demo": 1.25, "cat": "weapon", "verb": "chops", "slots": ["back"]}}},
	"knife_kitchen": {"name": "galley knife", "desc": "A general purpose cook's knife, forged by a Meridian cutler. Guaranteed to stay sharp for years to come.", "sheet": "items", "spr": "knife_kitchen",
		"comps": {"item": {"conducts": true, "w": 2, "force": 10, "throwforce": 10, "sharp": "edged", "wound": 5, "exposed": 15, "demo": 0.75, "tool": "knife", "cat": "weapon", "verb": "slashes", "slots": TOOL_SLOTS}}},
	"knife_cleaver": {"name": "butcher's cleaver", "desc": "A huge thing used for chopping and chopping up meat.", "sheet": "items", "spr": "knife_cleaver",
		"comps": {"item": {"conducts": true, "w": 3, "force": 15, "throwforce": 10, "sharp": "edged", "wound": 15, "exposed": 15, "demo": 0.75, "tool": "knife", "cat": "weapon", "verb": "chops"}}},
	"knife_survival": {"name": "survival knife", "desc": "A hunting grade survival knife.", "sheet": "items", "spr": "knife_survival",
		"comps": {"item": {"conducts": true, "w": 2, "force": 15, "throwforce": 15, "sharp": "edged", "wound": 5, "exposed": 15, "demo": 0.75, "tool": "knife", "cat": "weapon", "verb": "slashes", "slots": TOOL_SLOTS}}},
	"riot_shield": {"name": "boarding shield", "desc": "A heavy shield, good at blocking blunt objects from connecting with the torso of the bearer.", "sheet": "items", "spr": "riot_shield",
		"comps": {"item": {"w": 4, "force": 10, "throwforce": 5, "block": 50, "cat": "weapon", "verb": "bashes", "slots": ["back"]}}, "tags": {"shield_transparent": true}},
	"baseball_bat": {"name": "belaying pin", "desc": "Solid hardwood, made for rigging and, when it comes to it, for skulls.", "sheet": "items", "spr": "baseball_bat",
		"comps": {"item": {"w": 5, "force": 13, "throwforce": 13, "wound": -10, "demo": 1.25, "cat": "weapon", "verb": "beats", "slots": ["back"]}, "flammable": {"ignite": 500.0, "fuel": 10.0}}},
	"mop": {"name": "deck mop", "desc": "The deckhand's oldest weapon against grime.", "sheet": "items", "spr": "mop",
		"comps": {"item": {"w": 3, "force": 8, "throwforce": 10, "tool": "mop", "cat": "tool"}}},
	"bucket": {"name": "bucket", "desc": "It's a bucket. Fill it at a sink and dip a mop in it.", "sheet": "items", "spr": "bucket",
		"comps": {"item": {"w": 3, "force": 5, "throwforce": 5, "cat": "misc"}, "reagents": {"kind": "bucket", "volume": 70.0, "contents": {"water": 70.0}}}},
	"wet_floor_sign": {"name": "wet deck sign", "desc": "Mind the deck, it is wet!", "sheet": "items", "spr": "wet_floor_sign",
		"comps": {"item": {"w": 3, "force": 1, "throwforce": 3, "cat": "misc"}}},
	"light_tube": {"name": "light tube", "desc": "A replacement lamp tube.", "sheet": "items", "spr": "light_tube",
		"comps": {"item": {"w": 1, "cat": "material"}}},
	"soap": {"name": "soap", "desc": "A cheap bar of soap. Smells of pine. Slippery underfoot; use it on the floor to scrub a mess away.", "sheet": "items", "spr": "soap",
		"comps": {"item": {"w": 1, "cat": "misc"}, "decal": {"kind": "soap", "slippery": true, "cleanable": false}}},
	"paper": {"name": "paper", "desc": "A sheet of paper.", "sheet": "items", "spr": "paper",
		"comps": {"item": {"w": 1, "cat": "misc"}, "flammable": {"ignite": 450.0, "fuel": 6.0}}},
	"ore_iron": {"name": "iron ore", "desc": "Raw iron ore.", "sheet": "items", "spr": "ore_iron", "comps": {"item": {"w": 2, "cat": "ore"}}},
	"ore_plasma": {"name": "plasma ore", "desc": "Raw plasma crystals. Handle with care.", "sheet": "items", "spr": "ore_plasma", "comps": {"item": {"w": 2, "cat": "ore"}}},
	"ore_cryo": {"name": "frostglass", "desc": "A faintly glowing blue mineral found only in the frozen heights.", "sheet": "items", "spr": "ore_cryo", "comps": {"item": {"w": 2, "cat": "ore"}}},
	"ore_gold": {"name": "gold ore", "desc": "Shiny.", "sheet": "items", "spr": "ore_gold", "comps": {"item": {"w": 2, "cat": "ore"}}},
	"ice_chunk": {"name": "rime-ice chunk", "desc": "Ice from the high sky. The air plant can melt this into breathable air. It drips if you leave it somewhere warm.", "sheet": "items", "spr": "ice_chunk", "comps": {"item": {"w": 2, "cat": "ore"}, "melt": {"into": "water", "volume": 25.0, "time": 90.0}}},
	# ------------------------------------------------------------- gas
	"tank_o2": {"name": "breathing cylinder", "desc": "A cylinder of oxygen for a breathing mask.", "sheet": "items", "spr": "tank_o2",
		"comps": {"item": {"w": 3, "force": 10, "throwforce": 10, "demo": 1.25, "cat": "tank", "slots": ["back", "belt", "suit_storage"]}, "tank": {"gas": "o2", "moles": 17.47, "volume": 70.0}}},
	"tank_air": {"name": "emergency air cylinder", "desc": "A small cylinder of breathable air.", "sheet": "items", "spr": "tank_air",
		"comps": {"item": {"w": 2, "force": 4, "throwforce": 10, "demo": 1.25, "cat": "tank", "slots": ["belt", "pocket_l", "pocket_r"]}, "tank": {"gas": "air", "moles": 8.0}}},
	# ------------------------------------------------------------- medical
	# ------------------------------------------------------------- tg medical stacks, chems and gore
	"suture": {"name": "suture", "desc": "Basic sterile sutures used to seal up cuts and lacerations and stop bleeding.", "sheet": "items", "spr": "suture",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "meditem": {"kind": "suture"}}},
	"mesh": {"name": "regenerative mesh", "desc": "A bacteriostatic mesh used to dress burns.", "sheet": "items", "spr": "mesh",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "meditem": {"kind": "mesh"}}},
	"bone_gel": {"name": "bone gel", "desc": "A potent medical gel that, when applied to a damaged bone in a proper surgical setting, triggers an intense melding reaction to repair the wound. Follow with surgical tape.", "sheet": "items", "spr": "bone_gel",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "meditem": {"kind": "bone_gel"}, "surgerytool": {"kind": "bone_gel"}}},
	"surgical_tape": {"name": "surgical tape", "desc": "Has extreme adhesive qualities. Seals gelled fractures so they can knit.", "sheet": "items", "spr": "surgical_tape",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "meditem": {"kind": "surgical_tape"}}},
	"splint": {"name": "splint", "desc": "Used to keep a broken limb still: halves the limp and lets a shattered arm work.", "sheet": "items", "spr": "splint",
		"comps": {"item": {"w": 2, "cat": "medical", "slots": TOOL_SLOTS}, "meditem": {"kind": "splint"}}},
	"bonesetter": {"name": "bonesetter", "desc": "For setting things right.", "sheet": "items", "spr": "bonesetter",
		"comps": {"item": {"w": 2, "force": 8, "cat": "medical", "slots": TOOL_SLOTS}, "meditem": {"kind": "bonesetter"}, "surgerytool": {"kind": "bonesetter"}}},
	"blood_pack": {"name": "blood pack", "desc": "Contains blood used for transfusion. Hang it on an IV drip.", "sheet": "items", "spr": "blood_pack_full",
		"comps": {"item": {"w": 1, "cat": "chem", "slots": TOOL_SLOTS}, "reagents": {"kind": "blood_pack", "volume": 200.0, "contents": {"blood": 200.0}}}},
	"blood_pack_empty": {"name": "blood pack", "desc": "An empty blood pack. Hang it on an IV drip set to draw.", "sheet": "items", "spr": "blood_pack",
		"comps": {"item": {"w": 1, "cat": "chem", "slots": TOOL_SLOTS}, "reagents": {"kind": "blood_pack", "volume": 200.0}}},
	"saline_bag": {"name": "saline-glucose bag", "desc": "Restores blood volume. Hang it on an IV drip.", "sheet": "items", "spr": "blood_pack", "tint": "#d8e8f0",
		"comps": {"item": {"w": 1, "cat": "chem", "slots": TOOL_SLOTS}, "reagents": {"kind": "blood_pack", "volume": 200.0, "contents": {"salglu_solution": 100.0}}}},
	"syringe": {"name": "syringe", "desc": "A syringe that can hold up to 15 units. Z switches between drawing and injecting.", "sheet": "items", "spr": "syringe",
		"comps": {"item": {"w": 1, "force": 1, "cat": "chem", "slots": TOOL_SLOTS, "sharp": "pointy"}, "reagents": {"kind": "syringe", "volume": 15.0}}},
	"syringe_multiver": {"name": "syringe (multiver)", "desc": "Contains multiver: purges toxins.", "sheet": "items", "spr": "syringe",
		"comps": {"item": {"w": 1, "force": 1, "cat": "chem", "slots": TOOL_SLOTS}, "reagents": {"kind": "syringe", "volume": 15.0, "contents": {"multiver": 15.0}}}},
	"dropper": {"name": "dropper", "desc": "A dropper. Holds up to 5 units.", "sheet": "items", "spr": "dropper",
		"comps": {"item": {"w": 1, "cat": "chem", "slots": TOOL_SLOTS}, "reagents": {"kind": "dropper", "volume": 5.0}}},
	"bottle": {"name": "bottle", "desc": "A small bottle. Holds up to 30 units.", "sheet": "items", "spr": "bottle",
		"comps": {"item": {"w": 1, "cat": "chem", "slots": TOOL_SLOTS}, "reagents": {"kind": "bottle", "volume": 30.0}}},
	"bottle_epinephrine": {"name": "epinephrine bottle", "desc": "A small bottle containing epinephrine.", "sheet": "items", "spr": "bottle_filled",
		"comps": {"item": {"w": 1, "cat": "chem", "slots": TOOL_SLOTS}, "reagents": {"kind": "bottle", "volume": 30.0, "contents": {"epinephrine": 30.0}}}},
	"bottle_multiver": {"name": "multiver bottle", "desc": "A small bottle of multiver.", "sheet": "items", "spr": "bottle_filled",
		"comps": {"item": {"w": 1, "cat": "chem", "slots": TOOL_SLOTS}, "reagents": {"kind": "bottle", "volume": 30.0, "contents": {"multiver": 30.0}}}},
	"bottle_morphine": {"name": "morphine bottle", "desc": "A small bottle of morphine.", "sheet": "items", "spr": "bottle_filled",
		"comps": {"item": {"w": 1, "cat": "chem", "slots": TOOL_SLOTS}, "reagents": {"kind": "bottle", "volume": 30.0, "contents": {"morphine": 30.0}}}},
	"bottle_chloral": {"name": "chloral hydrate bottle", "desc": "A small bottle of chloral hydrate. Mickey's Favorite!", "sheet": "items", "spr": "bottle_filled",
		"comps": {"item": {"w": 1, "cat": "chem", "slots": TOOL_SLOTS}, "reagents": {"kind": "bottle", "volume": 30.0, "contents": {"chloralhydrate": 15.0}}}},
	"pill": {"name": "pill", "desc": "A tablet or capsule.", "sheet": "items", "spr": "pill",
		"comps": {"item": {"w": 1, "cat": "chem", "slots": TOOL_SLOTS}, "reagents": {"kind": "pill", "volume": 50.0}}},
	"patch": {"name": "patch", "desc": "A chemical patch for touch-based applications.", "sheet": "items", "spr": "patch",
		"comps": {"item": {"w": 1, "cat": "chem", "slots": TOOL_SLOTS}, "reagents": {"kind": "patch", "volume": 40.0}}},
	"patch_libital": {"name": "libital patch (brute)", "desc": "A pain reliever. Does minor liver damage. Diluted with granibitaluri.", "sheet": "items", "spr": "patch", "tint": "#ecec8d",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "reagents": {"kind": "patch", "volume": 40.0, "contents": {"libital": 5.0}}}},
	"patch_aiuri": {"name": "aiuri patch (burn)", "desc": "Helps with burn injuries. Does minor eye damage. Diluted with granibitaluri.", "sheet": "items", "spr": "patch", "tint": "#8c93ff",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "reagents": {"kind": "patch", "volume": 40.0, "contents": {"aiuri": 5.0}}}},
	"pill_multiver": {"name": "multiver pill", "desc": "Neutralizes many common toxins.", "sheet": "items", "spr": "pill", "tint": "#b1e46a",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "reagents": {"kind": "pill", "volume": 50.0, "contents": {"multiver": 5.0}}}},
	"pill_salbutamol": {"name": "salbutamol pill", "desc": "Used to treat oxygen deprivation.", "sheet": "items", "spr": "pill", "tint": "#00ffff",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "reagents": {"kind": "pill", "volume": 50.0, "contents": {"salbutamol": 5.0}}}},
	"pill_convermol": {"name": "convermol pill", "desc": "Restores oxygen deprivation while producing a lesser amount of toxic byproducts.", "sheet": "items", "spr": "pill", "tint": "#ff6464",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "reagents": {"kind": "pill", "volume": 50.0, "contents": {"convermol": 10.0}}}},
	"pill_iron": {"name": "iron pill", "desc": "Used to reduce bloodloss slowly.", "sheet": "items", "spr": "pill", "tint": "#909090",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "reagents": {"kind": "pill", "volume": 50.0, "contents": {"iron": 30.0}}}},
	"severed_limb": {"name": "severed limb", "desc": "Well, that's not supposed to come off.", "sheet": "items", "spr": "limb_arm",
		"comps": {"item": {"w": 3, "force": 5, "throwforce": 5, "cat": "body"}, "surgerytool": {"kind": "limb"}}},
	"organ_heart": {"name": "heart", "desc": "I feel bad for the heartless bastard who lost this.", "sheet": "items", "spr": "organ_heart", "comps": {"item": {"w": 1, "cat": "body"}, "surgerytool": {"kind": "organ"}, "food": {"nutrition": 10}}},
	"organ_brain": {"name": "brain", "desc": "A piece of juicy meat found in a person's head.", "sheet": "items", "spr": "organ_brain", "comps": {"item": {"w": 1, "cat": "body"}, "surgerytool": {"kind": "organ"}}},
	"organ_lungs": {"name": "lungs", "desc": "Breathe in, breathe out.", "sheet": "items", "spr": "organ_lungs", "comps": {"item": {"w": 1, "cat": "body"}, "surgerytool": {"kind": "organ"}}},
	"organ_liver": {"name": "liver", "desc": "Pairing suggestion: chianti and fava beans.", "sheet": "items", "spr": "organ_liver", "comps": {"item": {"w": 1, "cat": "body"}, "surgerytool": {"kind": "organ"}, "food": {"nutrition": 10}}},
	"self_grasp": {"name": "self-grasp", "desc": "Sometimes all you can do is slow the bleeding.", "sheet": "items", "spr": "gauze",
		"comps": {"item": {"w": 5, "cat": "body"}}},
	"organ_eyes": {"name": "eyes", "desc": "I see you!", "sheet": "items", "spr": "organ_eyes", "comps": {"item": {"w": 1, "cat": "body"}, "surgerytool": {"kind": "organ"}}},
	"organ_stomach": {"name": "stomach", "desc": "Onaka ga suite imasu.", "sheet": "items", "spr": "organ_stomach", "comps": {"item": {"w": 1, "cat": "body"}, "surgerytool": {"kind": "organ"}, "food": {"nutrition": 10}}},
	"organ_appendix": {"name": "appendix", "desc": "", "sheet": "items", "spr": "organ_appendix", "comps": {"item": {"w": 1, "cat": "body"}, "surgerytool": {"kind": "organ"}, "food": {"nutrition": 5}}},
	# tg /obj/effect/decal/cleanable/blood and its subtypes
	"blood": {"name": "pool of blood", "desc": "It's slippery and gooey. Perhaps it's the chef's cooking?", "sheet": "objects", "spr": "blood_floor_0", "z": -2, "comps": {"decal": {"kind": "blood", "blood": "pool"}}},
	"blood_splatter": {"name": "pool of blood", "desc": "It's slippery and gooey. Perhaps it's the chef's cooking?", "sheet": "objects", "spr": "blood_splatter_0", "z": -2, "comps": {"decal": {"kind": "blood", "blood": "splatter"}}},
	"blood_drip": {"name": "drop of blood", "desc": "It's slippery and gooey. Perhaps it's the chef's cooking?", "sheet": "objects", "spr": "blood_drop_0", "z": -2, "comps": {"decal": {"kind": "blood", "blood": "drip"}}},
	"blood_trail": {"name": "trail of blood", "desc": "Your instincts say you shouldn't be following these.", "sheet": "objects", "spr": "blood_trails_0_v", "z": -2, "comps": {"decal": {"kind": "blood", "blood": "trail"}}},
	"gibs": {"name": "gibs", "desc": "They look bloody and gruesome.", "sheet": "objects", "spr": "gore_gib_0", "z": -2, "comps": {"decal": {"kind": "blood", "blood": "gibs"}}},
	"chem_master": {"name": "ChemMaster 3000", "desc": "Used to separate chemicals and distribute them in a variety of forms.", "sheet": "objects", "spr": "chem_master",
		"comps": {"blocker": {"dense": true}, "machine": {"idle": 20.0, "hp": 100}, "chemmachine": {"kind": "master"}, "light": {"kind": "machine", "radius": 1.5, "color": "#6ae8a8", "energy": 0.3}}},
	"chem_heater": {"name": "chemical heater", "desc": "A small machine that heats or cools a beaker to a set temperature.", "sheet": "objects", "spr": "chem_heater",
		"comps": {"blocker": {"dense": true}, "machine": {"idle": 20.0, "active_w": 1000.0, "hp": 100}, "chemmachine": {"kind": "heater"}}},
	"medkit": {"name": "first-aid kit", "desc": "It's an emergency medical kit for those serious boo-boos.", "sheet": "items", "spr": "medkit",
		"comps": {"item": {"w": 3, "cat": "medical"}, "storage": {"kind": "bag", "capacity": 12, "max_w": 2, "slots": 7}}, "fill": ["gauze", "suture", "suture", "mesh", "mesh", "medipen", "health_analyzer"]},
	"medkit_burn": {"name": "burn treatment kit", "desc": "A specialised kit for when the boiler room -spontaneously- burns down.", "sheet": "items", "spr": "medkit_burn",
		"comps": {"item": {"w": 3, "cat": "medical"}, "storage": {"kind": "bag", "capacity": 12, "max_w": 2, "slots": 7}}, "fill": ["patch_aiuri", "patch_aiuri", "patch_aiuri", "patch_aiuri", "mesh", "ointment"]},
	"medkit_o2": {"name": "thin-air treatment kit", "desc": "A box full of remedies for the lightheaded and breathless.", "sheet": "items", "spr": "medkit_o2",
		"comps": {"item": {"w": 3, "cat": "medical"}, "storage": {"kind": "bag", "capacity": 12, "max_w": 2, "slots": 7}}, "fill": ["pill_salbutamol", "pill_salbutamol", "pill_salbutamol", "pill_convermol", "pill_convermol", "medipen"]},
	"medkit_toxin": {"name": "toxin treatment kit", "desc": "Used to treat toxic blood content and radiation poisoning.", "sheet": "items", "spr": "medkit_toxin",
		"comps": {"item": {"w": 3, "cat": "medical"}, "storage": {"kind": "bag", "capacity": 12, "max_w": 2, "slots": 7}}, "fill": ["pill_multiver", "pill_multiver", "pill_multiver", "pill_multiver", "syringe_multiver", "pill_bottle"]},
	"bruise_pack": {"name": "bruise pack", "desc": "A therapeutic gel pack and bandages designed to treat blunt-force trauma.", "sheet": "items", "spr": "bruise_pack",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "meditem": {"kind": "bruise_pack"}}},
	"ointment": {"name": "ointment", "desc": "Basic burn ointment, rated effective for second degree burns with proper bandaging. Also frostbite.", "sheet": "items", "spr": "ointment",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "meditem": {"kind": "ointment"}}},
	# tg /obj/item/detective_scanner
	"forensic_scanner": {"name": "forensic scanner", "desc": "Used to remotely scan objects and biomass for DNA and fingerprints. Can print a report of the findings.", "sheet": "items", "spr": "forensic_scanner",
		"comps": {"item": {"w": 2, "cat": "tool", "slots": TOOL_SLOTS}, "gadget": {"kind": "forensic"}}},
	"health_analyzer": {"name": "health analyzer", "desc": "A hand-held body scanner.", "sheet": "items", "spr": "health_analyzer",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "meditem": {"analyzer": true}}},
	"gas_analyzer": {"name": "gas analyzer", "desc": "A hand-held environmental scanner which reports current gas levels. Z scans where you stand; use it on a tile, tank or vent.", "sheet": "items", "spr": "gas_analyzer",
		"comps": {"item": {"w": 2, "force": 0, "throwforce": 0, "cat": "tool", "slots": TOOL_SLOTS}, "gasanalyzer": {}}},
	# tg pill_bottle/mannitol/braintumor: four diluted 5u mannitol pills (the brain tumor quirk)
	"pill_mannitol": {"name": "mannitol pill", "desc": "Used to treat symptoms for brain tumors.", "sheet": "items", "spr": "pill", "tint": "#a6fad6",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "reagents": {"kind": "pill", "volume": 50.0, "contents": {"mannitol": 5.0}}}},
	"pill_bottle_mannitol": {"name": "bottle of mannitol pills", "desc": "Contains diluted pills used to treat brain tumor symptoms. Take one when feeling lightheaded.", "sheet": "items", "spr": "pill_bottle",
		"comps": {"item": {"w": 2, "cat": "medical", "slots": TOOL_SLOTS}, "storage": {"kind": "bag", "capacity": 7, "max_w": 1, "slots": 7}}, "fill": ["pill_mannitol", "pill_mannitol", "pill_mannitol", "pill_mannitol"]},
	"pill_bottle": {"name": "fever pills", "desc": "A broad spectrum antiviral, from a Meridian apothecary.", "sheet": "items", "spr": "pill_bottle",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "meditem": {"heals": {"tox": 5}, "uses": 5, "delay": 1.0, "cures": true}}},
	"beaker_large": {"name": "large beaker", "desc": "A large beaker. Can hold up to 100 units.", "sheet": "items", "spr": "beaker",
		"comps": {"item": {"w": 2, "cat": "chem", "slots": TOOL_SLOTS}, "reagents": {"kind": "beaker", "volume": 100.0}}},
	"beaker": {"name": "beaker", "desc": "A beaker. It can hold up to 50 units.", "sheet": "items", "spr": "beaker",
		"comps": {"item": {"w": 1, "cat": "chem", "slots": TOOL_SLOTS}, "reagents": {"kind": "beaker", "volume": 50.0}}},
	# ------------------------------------------------------------- security
	"baton": {"name": "stun baton", "desc": "A stun baton for incapacitating people with.", "sheet": "items", "spr": "baton",
		"comps": {"item": {"conducts": true, "w": 3, "force": 10, "throwforce": 7, "cat": "weapon", "verb": "beats", "slots": ["belt"]}, "secgear": {"kind": "baton"}}},
	"handcuffs": {"name": "handcuffs", "desc": "Use this to keep prisoners in line.", "sheet": "items", "spr": "handcuffs",
		"comps": {"item": {"w": 1, "cat": "restraint", "slots": TOOL_SLOTS}, "secgear": {"kind": "cuffs"}}},
	# ------------------------------------------------------------- id / comms
	"id_card": {"name": "passcard", "desc": "A brass-stamped pass. Shows who you are and which hatches open for you.", "sheet": "items", "spr": "id_gen",
		"comps": {"item": {"w": 1, "cat": "id", "slots": ["id"]}, "idcard": {}}},
	"headset": {"name": "voice-link earpiece", "desc": "A modular aether-link that fits over the ear.", "sheet": "items", "spr": "headset",
		"comps": {"item": {"w": 1, "cat": "clothing", "slots": ["ears"]}, "headset": {}}},
	# ------------------------------------------------------------- clothing (generic, recoloured by overrides)
	"uniform": {"name": "deckhand's coveralls", "desc": "Standard-issue hard-wearing coveralls.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 3, "cat": "clothing", "slots": ["uniform"]}, "clothing": {"wound": 5.0, "slot": "uniform", "sprite": "uniform_jumpsuit", "insulation": 0.1}}},
	"winter_coat": {"name": "winter coat", "desc": "A heavy, fur-lined parka. Essential outside.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 4, "cat": "clothing", "slots": ["suit"]}, "clothing": {"slot": "suit", "sprite": "suit_winter", "insulation": 0.55, "colors": ["#3a8a9a", "#efe8dc", "#c8ccd4"], "slow": 0.05}}},
	"winter_hood": {"name": "winter hood", "desc": "A fur-lined hood.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 2, "cat": "clothing", "slots": ["head"]}, "clothing": {"slot": "head", "sprite": "head_hood", "insulation": 0.2, "hides_hair": true, "colors": ["#3a8a9a", "#efe8dc"]}}},
	"beanie": {"name": "beanie", "desc": "A warm knitted hat.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 1, "cat": "clothing", "slots": ["head"]}, "clothing": {"slot": "head", "sprite": "head_beanie", "insulation": 0.1, "hides_hair": false, "colors": ["#d84a4a", "#f0e0e0", "#ffffff"]}}},
	"scarf": {"name": "scarf", "desc": "A long knitted scarf.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 1, "cat": "clothing", "slots": ["mask"]}, "clothing": {"slot": "mask", "sprite": "mask_scarf", "insulation": 0.08, "colors": ["#c83a3a", "#f0e0c0"]}}},
	"suit": {"name": "coat", "desc": "Outerwear.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 3, "cat": "clothing", "slots": ["suit"]}, "clothing": {"slot": "suit", "sprite": "suit_labcoat", "insulation": 0.15}}},
	"hat": {"name": "hat", "desc": "Headwear.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 2, "cat": "clothing", "slots": ["head"]}, "clothing": {"slot": "head", "sprite": "head_cap", "insulation": 0.05}}},
	"shoes": {"name": "shoes", "desc": "Sturdy shoes.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 2, "cat": "clothing", "slots": ["shoes"]}, "clothing": {"slot": "shoes", "sprite": "shoes", "insulation": 0.05}}},
	"gloves": {"name": "gloves", "desc": "Gloves.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 1, "cat": "clothing", "slots": ["gloves"]}, "clothing": {"slot": "gloves", "sprite": "gloves", "insulation": 0.04}}},
	"mask": {"name": "mask", "desc": "A mask.", "sheet": "items", "spr": "gas_mask",
		"comps": {"item": {"w": 2, "cat": "clothing", "slots": ["mask"]}, "clothing": {"slot": "mask", "sprite": "mask_breath", "breath": true}}},
	"gas_mask": {"name": "gas mask", "desc": "Connects to an air supply. Filters smoke and reduces harmful gases by 80%; does not supply oxygen.", "sheet": "items", "spr": "gas_mask",
		"comps": {"item": {"w": 2, "cat": "clothing", "slots": ["mask"]}, "clothing": {"slot": "mask", "sprite": "mask_gasmask", "breath": true, "filter": true, "hides_face": true, "insulation": 0.05, "colors": ["#3a3f4a", "#7ab8e0", "#000000", "#6a7486"]}}},
	"breath_mask": {"name": "breath mask", "desc": "A close-fitting mask that can be connected to an air supply.", "sheet": "items", "spr": "gas_mask",
		"comps": {"item": {"w": 1, "cat": "clothing", "slots": ["mask"]}, "clothing": {"slot": "mask", "sprite": "mask_breath", "breath": true, "colors": ["#6a7486"]}}},
	"backpack": {"name": "backpack", "desc": "You wear this on your back and put items into it.", "sheet": "items", "spr": "toolbox_blue",
		"comps": {"item": {"w": 4, "cat": "container", "slots": ["back"]}, "storage": {"kind": "bag", "capacity": 21, "max_w": 3, "slots": 21},
			"clothing": {"slot": "back", "sprite": "backpack", "colors": ["#5a6272", "#3a3f4a"]}}},
	"toolbelt": {"name": "tool belt", "desc": "Can hold various tools.", "sheet": "items", "spr": "toolbox_yellow",
		"comps": {"item": {"w": 3, "cat": "container", "slots": ["belt"]}, "storage": {"kind": "bag", "capacity": 21, "max_w": 3, "slots": 7, "holds": ["tool", "wrench", "screwdriver", "crowbar", "wirecutters", "welder", "multitool", "cable_coil", "gas_analyzer", "extinguisher_mini", "flashlight", "gloves", "insulated_gloves", "headset", "drink_soda"]},
			"clothing": {"slot": "belt", "sprite": "toolbelt", "colors": ["#7a5a3a", "#000000", "#000000", "#b0b8c4"]}}},
	"insulated_gloves": {"name": "insulated gloves", "desc": "These gloves will protect the wearer from electric shock.", "sheet": "items", "spr": "coat_eng",
		"comps": {"item": {"w": 1, "cat": "clothing", "slots": ["gloves"]}, "clothing": {"slot": "gloves", "sprite": "gloves", "insulated": true, "insulation": 0.05, "colors": ["#e8c83a"]}}},
	# ------------------------------------------------------------- food & drink
	"food_sandwich": {"name": "sandwich", "desc": "A grand creation of meat, cheese, bread, and several leaves of lettuce.", "sheet": "items", "spr": "food_sandwich", "comps": {"item": {"w": 2, "cat": "food"}, "food": {"nutrition": 35, "bites": 3, "mood": 4}}},
	"food_soup": {"name": "potato soup", "desc": "Hot and hearty.", "sheet": "items", "spr": "food_soup", "comps": {"item": {"w": 2, "cat": "food"}, "food": {"nutrition": 30, "hydration": 15, "bites": 3, "warmth": 3.0, "mood": 6}}},
	"food_burger": {"name": "burger", "desc": "The cornerstone of every nutritious breakfast.", "sheet": "items", "spr": "food_burger", "comps": {"item": {"w": 2, "cat": "food"}, "food": {"nutrition": 45, "bites": 3, "mood": 6}}},
	"food_donut": {"name": "sugar knot", "desc": "Goes great with strong coffee.", "sheet": "items", "spr": "food_donut", "comps": {"item": {"w": 1, "cat": "food"}, "food": {"nutrition": 15, "bites": 2, "mood": 8}}},
	"food_pizza": {"name": "flatbread slice", "desc": "A delicious slice of flatbread.", "sheet": "items", "spr": "food_pizza", "comps": {"item": {"w": 1, "cat": "food"}, "food": {"nutrition": 30, "bites": 2, "mood": 8}}},
	"food_ration": {"name": "ration pack", "desc": "Nutritionally complete. Tastes like cardboard.", "sheet": "items", "spr": "food_ration", "comps": {"item": {"w": 1, "cat": "food"}, "food": {"nutrition": 40, "bites": 2, "mood": -2}}},
	"food_meat": {"name": "slab of meat", "desc": "Cut from something that had it coming.", "sheet": "items", "spr": "food_meat", "comps": {"item": {"w": 2, "cat": "ingredient"}, "food": {"nutrition": 8, "bites": 2, "ingredient": true, "mood": -3}}},
	"food_flour": {"name": "flour sack", "desc": "A big bag of flour.", "sheet": "items", "spr": "food_flour", "comps": {"item": {"w": 2, "cat": "ingredient"}, "food": {"nutrition": 0, "bites": 1, "ingredient": true}}},
	"food_egg": {"name": "egg", "desc": "An egg.", "sheet": "items", "spr": "food_egg", "comps": {"item": {"w": 1, "cat": "ingredient"}, "food": {"nutrition": 5, "bites": 1, "ingredient": true}}},
	"food_tomato": {"name": "tomato", "desc": "Grown under glass in a port garden.", "sheet": "items", "spr": "food_tomato", "comps": {"item": {"w": 1, "cat": "ingredient"}, "food": {"nutrition": 8, "hydration": 4, "bites": 1, "ingredient": true}}},
	"food_potato": {"name": "potato", "desc": "Starchy.", "sheet": "items", "spr": "food_potato", "comps": {"item": {"w": 1, "cat": "ingredient"}, "food": {"nutrition": 6, "bites": 1, "ingredient": true}}},
	"food_berries": {"name": "snowberries", "desc": "Tart blue berries that grow on the frosted islands.", "sheet": "items", "spr": "food_berries", "comps": {"item": {"w": 1, "cat": "ingredient"}, "food": {"nutrition": 8, "hydration": 5, "bites": 1, "ingredient": true, "mood": 3}}},
	"food_wheat": {"name": "wheat", "desc": "Grind it into flour.", "sheet": "items", "spr": "food_wheat", "comps": {"item": {"w": 1, "cat": "ingredient"}, "food": {"nutrition": 0, "bites": 1, "ingredient": true}}},
	"food_banana": {"name": "banana", "desc": "Shipped up from the warm reaches. Watch the peel.", "sheet": "items", "spr": "food_banana", "comps": {"item": {"w": 1, "cat": "food", "slots": TOOL_SLOTS}, "food": {"nutrition": 12, "bites": 1, "mood": 3}}},
	"banana_peel": {"name": "banana peel", "desc": "A peel from a banana. Watch your step.", "sheet": "items", "spr": "food_banana_peel", "z": -1,
		"comps": {"item": {"w": 1, "cat": "trash"}, "decal": {"kind": "peel", "slippery": true}}},
	"drink_cocoa": {"name": "hot cocoa", "desc": "Steaming hot cocoa. The best thing about the high sky.", "sheet": "items", "spr": "drink_cocoa", "comps": {"item": {"w": 1, "cat": "drink"}, "food": {"nutrition": 5, "hydration": 25, "bites": 3, "warmth": 4.0, "drink": true, "mood": 8}}},
	"drink_water": {"name": "water bottle", "desc": "Rainwater from a ship cistern.", "sheet": "items", "spr": "drink_water", "comps": {"item": {"w": 1, "cat": "drink", "slots": TOOL_SLOTS}, "food": {"hydration": 40, "bites": 3, "drink": true, "mood": 1, "nutrition": 0}}},
	"drink_soda": {"name": "Skyfizz", "desc": "Refreshing, if you can stand the cold.", "sheet": "items", "spr": "drink_soda", "comps": {"item": {"w": 1, "cat": "drink", "slots": TOOL_SLOTS}, "food": {"hydration": 30, "nutrition": 5, "bites": 2, "drink": true, "mood": 4}}},
	"drink_coffee": {"name": "coffee", "desc": "Robust.", "sheet": "items", "spr": "drink_coffee", "comps": {"item": {"w": 1, "cat": "drink"}, "food": {"hydration": 20, "bites": 2, "drink": true, "warmth": 2.5, "mood": 5, "nutrition": 0}}},
	"drink_booze": {"name": "bottle of rum", "desc": "For warming the soul, not the body.", "sheet": "items", "spr": "drink_booze", "comps": {"item": {"w": 2, "cat": "drink", "force": 15, "throwforce": 15, "demo": 0.25, "verb": "smashes"}, "food": {"hydration": 10, "bites": 5, "drink": true, "mood": 10, "nutrition": 0, "chems": {"vodka": 100.0}}}},
	# ------------------------------------------------------------- doors & walls fixtures
	"airlock": {"name": "bulkhead hatch", "desc": "It opens and closes.", "sheet": "objects", "spr": "airlock_generic_0",
		"comps": {"blocker": {"dense": true, "air": true, "opaque": false}, "door": {}}},
	"apc": {"name": "power junction", "desc": "A control panel for a compartment's electrical systems.", "sheet": "objects", "spr": "apc", "wall": true,
		"comps": {"machine": {"needs_power": false, "hp": 80}, "apc": {}, "light": {"kind": "machine", "radius": 1.5, "color": "#5aff9a", "energy": 0.35}}},
	"air_alarm": {"name": "air warning bell", "desc": "A bell-and-gauge that monitors the air and sounds when it turns bad.", "sheet": "objects", "spr": "air_alarm", "wall": true,
		"comps": {"machine": {"channel": "environ", "idle": 10.0, "hp": 50}, "air_alarm": {}, "light": {"kind": "machine", "radius": 1.5, "color": "#5ad0ff", "energy": 0.3}}},
	"light_fixture": {"name": "light fixture", "desc": "A lighting fixture.", "sheet": "objects", "spr": "light_on", "wall": true,
		"comps": {"light": {"kind": "fixture", "radius": 6.0, "color": "#ffeed6", "energy": 0.75, "origin": [0, 0]}}},
	"light_fixture_cold": {"name": "light fixture", "desc": "A lighting fixture.", "sheet": "objects", "spr": "light_on", "wall": true,
		"comps": {"light": {"kind": "fixture", "radius": 6.0, "color": "#e4efff", "energy": 0.75}}},
	"ceiling_light": {"name": "ceiling light", "desc": "A recessed ceiling panel.", "sheet": "objects", "spr": "", "z": -3,
		"comps": {"light": {"kind": "ceiling", "radius": 5.5, "color": "#fff3e0", "energy": 0.7}}},
	"emergency_light": {"name": "emergency light", "desc": "Battery backed. Turns on when the power fails.", "sheet": "objects", "spr": "emergency_light", "wall": true,
		"comps": {"light": {"kind": "emergency", "radius": 4.5, "color": "#ff3a2a", "energy": 0.8}}},
	"ext_cabinet": {"name": "extinguisher cabinet", "desc": "A small wall mounted cabinet designed to hold a fire extinguisher.", "sheet": "objects", "spr": "extinguisher_cabinet", "wall": true,
		"comps": {"furniture": {"kind": "cabinet", "item": "extinguisher"}}},
	"sign_med": {"name": "sickbay sign", "desc": "A sign marking the Sickbay.", "sheet": "objects", "spr": "sign_med", "wall": true},
	"sign_sec": {"name": "watch sign", "desc": "A sign marking the Watch.", "sheet": "objects", "spr": "sign_sec", "wall": true},
	"sign_eng": {"name": "engine room sign", "desc": "A sign marking the Engine Room.", "sheet": "objects", "spr": "sign_eng", "wall": true},
	"sign_sci": {"name": "aetherworks sign", "desc": "A sign marking the Aetherworks.", "sheet": "objects", "spr": "sign_sci", "wall": true},
	"sign_cmd": {"name": "bridge sign", "desc": "A sign marking the Bridge.", "sheet": "objects", "spr": "sign_cmd", "wall": true},
	"sign_srv": {"name": "service sign", "desc": "A sign marking Service.", "sheet": "objects", "spr": "sign_srv", "wall": true},
	"sign_cargo": {"name": "hold sign", "desc": "A sign marking the Cargo Hold.", "sheet": "objects", "spr": "sign_cargo", "wall": true},
	"sign_bar": {"name": "taproom sign", "desc": "A sign marking the Taproom.", "sheet": "objects", "spr": "sign_bar", "wall": true},
	"sign_danger": {"name": "danger sign", "desc": "A warning sign.", "sheet": "objects", "spr": "sign_danger", "wall": true},
	"sign_atmos": {"name": "air works sign", "desc": "A sign marking the Air Works.", "sheet": "objects", "spr": "sign_atmos", "wall": true},
	"poster_0": {"name": "poster", "desc": "A poster. Someone has doodled on the corner.", "sheet": "objects", "spr": "poster_0", "wall": true},
	"poster_1": {"name": "poster", "desc": "A poster. Someone has doodled on the corner.", "sheet": "objects", "spr": "poster_1", "wall": true},
	"poster_2": {"name": "poster", "desc": "A poster. Someone has doodled on the corner.", "sheet": "objects", "spr": "poster_2", "wall": true},
	"poster_3": {"name": "poster", "desc": "A poster. Someone has doodled on the corner.", "sheet": "objects", "spr": "poster_3", "wall": true},
	"poster_4": {"name": "poster", "desc": "A poster. Someone has doodled on the corner.", "sheet": "objects", "spr": "poster_4", "wall": true},
	"poster_5": {"name": "poster", "desc": "A poster. Someone has doodled on the corner.", "sheet": "objects", "spr": "poster_5", "wall": true},
	"filing_cabinet": {"name": "filing cabinet", "desc": "A large cabinet with drawers.", "sheet": "objects", "spr": "filing_cabinet", "comps": {"blocker": {"dense": true}, "storage": {"kind": "closet", "capacity": 12, "mob_capacity": 0}}},
	"water_cooler": {"name": "water cooler", "desc": "A machine that dispenses cold water. It's always cold up here anyway.", "sheet": "objects", "spr": "water_cooler", "comps": {"blocker": {"dense": true}, "vending": {"products": [["drink_water", 20]]}}},
	"desk_computer": {"name": "desk engine", "desc": "A clockwork ledger-engine. The screensaver is a spinning Guild seal.", "sheet": "objects", "spr": "desk_computer", "z": 1, "comps": {"fixture": {"kind": "computer"}, "console": {"kind": "desk"}}},
	"desk_lamp": {"name": "desk lamp", "desc": "A green banker's lamp.", "sheet": "objects", "spr": "desk_lamp", "z": 1, "comps": {"light": {"kind": "item", "radius": 2.5, "color": "#ffe8b0", "energy": 0.6, "on": true}}},
	"coffee_machine": {"name": "coffee machine", "desc": "Hot coffee, in the highest place you've ever worked.", "sheet": "objects", "spr": "coffee_machine", "comps": {"blocker": {"dense": true}, "vending": {"products": [["drink_coffee", 15], ["drink_cocoa", 10]]}}},
	"fireaxe_cabinet": {"name": "fire axe cabinet", "desc": "There is a small label that reads \"For Emergency use only\" along with details for safe use of the axe.", "sheet": "objects", "spr": "extinguisher_cabinet", "wall": true,
		"comps": {"furniture": {"kind": "cabinet", "item": "fireaxe"}}},
	"status_display": {"name": "status display", "desc": "Shows the ship's clock and the watch bell.", "sheet": "objects", "spr": "status_display", "wall": true,
		"comps": {"statusdisplay": {}, "light": {"kind": "machine", "radius": 1.6, "color": "#5ad0ff", "energy": 0.35}}},
	"fire_alarm": {"name": "fire bell", "desc": "Pull this in case of emergency. Thus, keep pulling it forever.", "sheet": "objects", "spr": "fire_alarm_idle", "wall": true,
		"comps": {"machine": {"channel": "environ", "idle": 5.0, "hp": 50}, "firealarm": {}, "light": {"kind": "machine", "radius": 1.2, "color": "#ff6a4a", "energy": 0.25}}},
	"firelock": {"name": "fire shutter", "desc": "Apply crowbar.", "sheet": "objects", "spr": "firelock_0",
		"comps": {"blocker": {"dense": false}, "firelock": {}}},
	"holofan_barrier": {"name": "shimmer shutter", "desc": "A shimmering barrier resembling a fire shutter. Though it does not stop solid objects from passing through, gas is kept out.", "sheet": "objects", "spr": "holofan_barrier", "z": 1,
		"comps": {"blocker": {"dense": false, "air": true}, "holosign": {}}},
	"autolathe": {"name": "clockwork lathe", "desc": "It produces items using iron, glass, cord and maybe some more.", "sheet": "objects", "spr": "autolathe",
		"comps": {"blocker": {"dense": true}, "machine": {"idle": 10.0, "active_w": 1000.0, "hp": 150}, "lathe": {"kind": "autolathe"}}},
	"intercom": {"name": "speaking tube", "desc": "Talk through this.", "sheet": "objects", "spr": "intercom", "wall": true, "comps": {"fixture": {"kind": "intercom", "on": false}}},
	# ------------------------------------------------------------- atmos devices
	"vent": {"name": "air vent", "desc": "Has a valve and pump attached to it.", "sheet": "objects", "spr": "vent", "z": -1,
		"comps": {"machine": {"channel": "environ", "idle": 30.0, "hp": 60}, "vent": {"mode": "vent"}}},
	"scrubber": {"name": "air scrubber", "desc": "Has a valve and pump attached to it.", "sheet": "objects", "spr": "scrubber", "z": -1,
		"comps": {"machine": {"channel": "environ", "idle": 30.0, "hp": 60}, "vent": {"mode": "scrubber"}}},
	# tg atmos pipe machines (CPipeMachine); mapgen builds them into the runs
	"pump": {"name": "pressure pump", "desc": "A pump that pushes gas out until the output pipe reaches its target pressure.", "sheet": "objects", "spr": "pump_supply_on", "z": -1,
		"comps": {"machine": {"channel": "environ", "idle": 20.0, "hp": 80}, "pipemachine": {"kind": "pump"}}},
	"pipe_dispenser": {"name": "pipe dispenser", "desc": "Makes pipe fittings for the pipefitter on the go.", "sheet": "objects", "spr": "pipe_dispenser",
		"comps": {"blocker": {"dense": true}, "machine": {"channel": "equip", "idle": 20.0, "hp": 100}, "pipedispenser": {}}},
	"volume_pump": {"name": "volumetric pump", "desc": "A pump that moves a set volume of gas every second, whatever the pressure.", "sheet": "objects", "spr": "vpump_supply_on", "z": -1,
		"comps": {"machine": {"channel": "environ", "idle": 20.0, "hp": 80}, "pipemachine": {"kind": "vpump"}}},
	"manual_valve": {"name": "manual valve", "desc": "A pipe valve. Open, gas flows through; closed, it doesn't.", "sheet": "objects", "spr": "valve_supply_on", "z": -1,
		"comps": {"pipemachine": {"kind": "valve"}}},
	"gas_filter": {"name": "gas filter", "desc": "Sends one gas out of its side port and lets the rest carry on.", "sheet": "objects", "spr": "filter_scrub_on", "z": -1,
		"comps": {"machine": {"channel": "environ", "idle": 20.0, "hp": 80}, "pipemachine": {"kind": "filter"}}},
	"thermo_heater": {"name": "heater", "desc": "A thermomachine. Heats the gas in the pipe it's connected to.", "sheet": "objects", "spr": "thermo_heater_on",
		"comps": {"blocker": {"dense": true}, "machine": {"channel": "environ", "idle": 50.0, "active_w": 2000.0, "hp": 120}, "pipemachine": {"kind": "thermo"}}},
	"thermo_freezer": {"name": "freezer", "desc": "A thermomachine. Cools the gas in the pipe it's connected to.", "sheet": "objects", "spr": "thermo_freezer_off",
		"comps": {"blocker": {"dense": true}, "machine": {"channel": "environ", "idle": 50.0, "active_w": 2000.0, "hp": 120}, "pipemachine": {"kind": "thermo", "freezer": true, "on": false}}},
	"outlet": {"name": "exhaust stack", "desc": "Ship exhaust. Vents waste gas into the open sky.", "sheet": "objects", "spr": "scrubber", "z": -1,
		"comps": {"vent": {"mode": "outlet"}}},
	"light_switch": {"name": "light switch", "desc": "Make dark.", "sheet": "objects", "spr": "light_switch_on", "wall": true,
		"comps": {"lightswitch": {}, "light": {"kind": "fixture", "radius": 1.0, "color": "#8affb0", "energy": 0.25}}},
	"space_heater": {"name": "cabin heater", "desc": "Made by Meridian tinkers using traditional methods, this heater/cooler is guaranteed not to set the ship on fire. Warranty void if used in engines.", "sheet": "objects", "spr": "space_heater",
		"comps": {"blocker": {"dense": true}, "spaceheater": {}, "light": {"kind": "always", "radius": 2.0, "color": "#ff8a3a", "energy": 0.4, "on": false}}, "tags": {"anchored": false}},
	"heater": {"name": "wall heater", "desc": "Keeps the high-sky chill out.", "sheet": "objects", "spr": "heater_on", "wall": true,
		"comps": {"machine": {"channel": "environ", "idle": 50.0, "active_w": 1500.0, "hp": 80}, "heater": {},
			"light": {"kind": "machine", "radius": 1.8, "color": "#ff8a3a", "energy": 0.45}}},
	"air_supply": {"name": "air plant", "desc": "Mixes stored oxygen and nitrogen into the ship's air supply.", "sheet": "objects", "spr": "console_atmos",
		"comps": {"machine": {"channel": "environ", "idle": 200.0, "hp": 120}, "air_supply": {}, "blocker": {"dense": true}, "light": {"kind": "machine", "radius": 2.0, "color": "#5ad0ff", "energy": 0.5}}},
	"canister_o2": {"name": "oxygen canister", "desc": "Contains oxygen.", "sheet": "objects", "spr": "canister_o2",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "o2", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_n2": {"name": "nitrogen canister", "desc": "Contains nitrogen. Doubles as reactor coolant.", "sheet": "objects", "spr": "canister_n2",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "n2", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_plasma": {"name": "plasma canister", "desc": "Contains plasma. Extremely flammable.", "sheet": "objects", "spr": "canister_plasma",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "plasma", "moles": 800.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_air": {"name": "air canister", "desc": "Contains breathable air.", "sheet": "objects", "spr": "canister_air",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "air", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_co2": {"name": "carbon dioxide canister", "desc": "Contains carbon dioxide.", "sheet": "objects", "spr": "canister_co2",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "co2", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_n2o": {"name": "nitrous oxide canister", "desc": "Contains nitrous oxide. Sleeping gas.", "sheet": "objects", "spr": "canister_n2o",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "n2o", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_h2o": {"name": "water vapor canister", "desc": "Contains water vapor.", "sheet": "objects", "spr": "canister_h2o",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "h2o", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_tritium": {"name": "Tritium canister", "desc": "Highly flammable and radioactive.", "sheet": "objects", "spr": "canister_tritium",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "tritium", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_nob": {"name": "Hyper-Noblium canister", "desc": "Suppresses gas reactions in sufficient quantities.", "sheet": "objects", "spr": "canister_nob",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "nob", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_nitrium": {"name": "Nitrium canister", "desc": "An experimental stimulant that can damage lungs.", "sheet": "objects", "spr": "canister_nitrium",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "nitrium", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_bz": {"name": "BZ canister", "desc": "A hallucinogenic nerve agent.", "sheet": "objects", "spr": "canister_bz",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "bz", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_pluox": {"name": "Pluoxium canister", "desc": "Eight times as effective as oxygen for breathing.", "sheet": "objects", "spr": "canister_pluox",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "pluox", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_miasma": {"name": "Miasma canister", "desc": "Rotting biological pollutants. Disease hazard.", "sheet": "objects", "spr": "canister_miasma",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "miasma", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_freon": {"name": "Freon canister", "desc": "Coolant gas. Caustic if inhaled.", "sheet": "objects", "spr": "canister_freon",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "freon", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_h2": {"name": "Hydrogen canister", "desc": "Highly flammable gas.", "sheet": "objects", "spr": "canister_h2",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "h2", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_healium": {"name": "Healium canister", "desc": "An anesthetic gas with healing properties.", "sheet": "objects", "spr": "canister_healium",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "healium", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_proto_nitrate": {"name": "Proto-Nitrate canister", "desc": "Volatile gas with many atmospheric reactions.", "sheet": "objects", "spr": "canister_proto_nitrate",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "proto_nitrate", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_zauker": {"name": "Zauker canister", "desc": "Extremely toxic gas.", "sheet": "objects", "spr": "canister_zauker",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "zauker", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_halon": {"name": "Halon canister", "desc": "Fire suppressant. Harmful if inhaled.", "sheet": "objects", "spr": "canister_halon",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "halon", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_he": {"name": "Helium canister", "desc": "An inert noble gas. Makes your voice squeaky.", "sheet": "objects", "spr": "canister_he",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "he", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_antinob": {"name": "Anti-Noblium canister", "desc": "Highly reactive gas that consumes other gases.", "sheet": "objects", "spr": "canister_antinob",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "antinob", "moles": 1500.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"canister_empty": {"name": "canister", "desc": "An empty gas canister.", "sheet": "objects", "spr": "canister_empty",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "", "moles": 0.0, "volume": 1000.0}, "canister": {}}, "tags": {"anchored": false}},
	"portable_pump": {"name": "portable air pump", "desc": "Pumps gas between its tank and the room around it.", "sheet": "objects", "spr": "portable_pump",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "", "moles": 0.0, "volume": 1000.0}, "canister": {"kind": "pump"}}, "tags": {"anchored": false}},
	"portable_scrubber": {"name": "portable air scrubber", "desc": "Pulls carbon dioxide, plasma and the like out of the air around it.", "sheet": "objects", "spr": "portable_scrubber",
		"comps": {"blocker": {"dense": true}, "tank": {"gas": "", "moles": 0.0, "volume": 1000.0}, "canister": {"kind": "scrubber"}}, "tags": {"anchored": false}},
	# tg atmos devices the Atmospherics import places (MetaStation)
	"gas_mixer": {"name": "gas mixer", "desc": "Mixes two gases at the ratio it's set to.", "sheet": "objects", "spr": "mixer_gen_on", "z": -1,
		"comps": {"machine": {"channel": "environ", "idle": 20.0, "hp": 80}, "pipemachine": {"kind": "mixer"}}},
	"passive_gate": {"name": "passive gate", "desc": "Lets gas through one way, up to its set pressure.", "sheet": "objects", "spr": "gate_gen_on", "z": -1,
		"comps": {"pipemachine": {"kind": "gate"}}},
	"pressure_valve": {"name": "pressure valve", "desc": "Opens when the pressure on its input goes over the setting.", "sheet": "objects", "spr": "gate_gen_on", "z": -1,
		"comps": {"machine": {"channel": "environ", "idle": 10.0, "hp": 80}, "pipemachine": {"kind": "pvalve"}}},
	"gas_injector": {"name": "air injector", "desc": "Pumps the gas in its pipe onto its tile.", "sheet": "objects", "spr": "injector", "z": -1,
		"comps": {"machine": {"channel": "environ", "idle": 30.0, "hp": 60}, "vent": {"mode": "injector"}}},
	"gas_siphon": {"name": "tank output inlet", "desc": "Draws gas from the room into its pipe.", "sheet": "objects", "spr": "vent_siphon", "z": -1,
		"comps": {"machine": {"channel": "environ", "idle": 30.0, "hp": 60}, "vent": {"mode": "siphon"}}},
	"passive_vent": {"name": "passive vent", "desc": "An open pipe end. Gas moves freely between the pipe and the air.", "sheet": "objects", "spr": "passive_vent", "z": -1,
		"comps": {"vent": {"mode": "passive"}}},
	"connector_port": {"name": "connector port", "desc": "Wrench a canister onto it to connect it to the pipes.", "sheet": "objects", "spr": "connector", "z": -1,
		"comps": {"vent": {"mode": "port"}}},
	"pipe_tank": {"name": "pressure tank", "desc": "A large stationary tank on the pipes (2500 L).", "sheet": "objects", "spr": "pipe_tank",
		"comps": {"blocker": {"dense": true}}},
	"meter": {"name": "gas flow meter", "desc": "It measures the gas in the pipe it's clamped to.", "sheet": "objects", "spr": "meter_0", "z": 1,
		"comps": {"meter": {}}},
	# ------------------------------------------------------------- power
	"reactor": {"name": "aether reactor", "desc": "The ship's heart. Keep it cool.", "sheet": "objects", "spr": "reactor",
		"comps": {"machine": {"needs_power": false, "hp": 400}, "reactor": {}, "blocker": {"dense": true, "footprint": [[0, 0], [1, 0], [0, -1], [1, -1]]},
			"light": {"kind": "always", "radius": 4.5, "color": "#2ad8a8", "energy": 0.9}}},
	"teg": {"name": "thermoelectric generator", "desc": "Turns a difference in temperature into electricity.", "sheet": "objects", "spr": "teg",
		"comps": {"machine": {"needs_power": false, "hp": 250}, "powergen": {"kind": "teg"}, "blocker": {"dense": true, "footprint": [[0, 0], [1, 0]]},
			"light": {"kind": "always", "radius": 2.0, "color": "#ffcc4a", "energy": 0.4}}},
	"smes": {"name": "power storage unit", "desc": "A high-capacity superconducting magnetic energy storage (SMES) unit.", "sheet": "objects", "spr": "smes",
		"comps": {"machine": {"needs_power": false, "hp": 200}, "powergen": {"kind": "smes"}, "blocker": {"dense": true}, "light": {"kind": "always", "radius": 1.8, "color": "#5aff7a", "energy": 0.4}}},
	"generator": {"name": "portable generator", "desc": "A portable generator for emergency backup power. Fuel with plasma sheets.", "sheet": "objects", "spr": "generator",
		"comps": {"machine": {"needs_power": false, "hp": 120}, "powergen": {"kind": "generator", "fuel": 0.5}, "blocker": {"dense": true}}, "tags": {"anchored": false}},
	"radiator": {"name": "heat exchanger", "desc": "Dumps the reactor's waste heat into the open sky.", "sheet": "objects", "spr": "radiator",
		"comps": {"machine": {"needs_power": false, "hp": 150}, "powergen": {"kind": "radiator"}, "blocker": {"dense": true}}},
	# ------------------------------------------------------------- consoles & machines
	"console": {"name": "computer", "desc": "A console.", "sheet": "objects", "spr": "console_eng",
		"comps": {"machine": {"idle": 300.0, "hp": 100}, "console": {}, "blocker": {"dense": true}, "light": {"kind": "machine", "radius": 2.2, "color": "#6ab8ff", "energy": 0.5}}},
	"vending": {"name": "vending machine", "desc": "Free rations, courtesy of the Meridian Guild.", "sheet": "objects", "spr": "vending_snack",
		"comps": {"machine": {"idle": 150.0, "hp": 120}, "vending": {}, "blocker": {"dense": true}, "light": {"kind": "machine", "radius": 2.2, "color": "#ffe8a8", "energy": 0.5}}},
	"microwave": {"name": "microwave", "desc": "Cooks and boils stuff.", "sheet": "objects", "spr": "microwave",
		"comps": {"machine": {"idle": 20.0, "active_w": 1000.0, "hp": 60}, "cooker": {}}},
	"oven": {"name": "galley range", "desc": "A heavy cooking range.", "sheet": "objects", "spr": "oven",
		"comps": {"machine": {"idle": 30.0, "active_w": 2000.0, "hp": 100}, "cooker": {}, "blocker": {"dense": true}}},
	"hydro_tray": {"name": "hydroponics tray", "desc": "An interstitial growing tray with grow lights.", "sheet": "objects", "spr": "hydro_tray",
		"comps": {"machine": {"idle": 150.0, "hp": 80}, "hydro": {}, "blocker": {"dense": true}}},
	"chem_dispenser": {"name": "chem dispenser", "desc": "Creates and dispenses chemicals.", "sheet": "objects", "spr": "chem_dispenser",
		"comps": {"machine": {"idle": 200.0, "hp": 100}, "reagents": {"kind": "dispenser"}, "blocker": {"dense": true}, "light": {"kind": "machine", "radius": 1.8, "color": "#5ad0ff", "energy": 0.4}}},
	"sleeper": {"name": "sleeper", "desc": "A pod that slowly stabilises whoever lies inside.", "sheet": "objects", "spr": "sleeper",
		"comps": {"machine": {"idle": 400.0, "hp": 120}, "blocker": {"dense": false, "footprint": [[0, 0], [1, 0]]}, "furniture": {"kind": "sleeper"}, "light": {"kind": "machine", "radius": 2.0, "color": "#4ab8d8", "energy": 0.4}}},
	# ------------------------------------------------------------- furniture & storage
	"table": {"name": "table", "desc": "A square piece of metal standing on four metal legs.", "sheet": "objects", "spr": "table_steel",
		"comps": {"blocker": {"dense": true}, "furniture": {"kind": "table"}}},
	"counter": {"name": "counter", "desc": "A kitchen counter.", "sheet": "objects", "spr": "table_counter",
		"comps": {"blocker": {"dense": true}, "furniture": {"kind": "table"}}},
	"chair": {"name": "chair", "desc": "You sit in this. Either by will or force.", "sheet": "objects", "spr": "chair_steel_s", "comps": {"furniture": {"kind": "seat"}}},
	"bed": {"name": "bed", "desc": "This is used to lie in, sleep in or strap on.", "sheet": "objects", "spr": "bed_0", "z": -1,
		"comps": {"furniture": {"kind": "bed"}, "flammable": {"fuel": 20.0}}},
	"op_table": {"name": "operating table", "desc": "Used for advanced medical procedures.", "sheet": "objects", "spr": "op_table", "z": -1, "comps": {"furniture": {"kind": "bed"}}},
	"med_bed": {"name": "sickbay cot", "desc": "A clean cot for the sick and wounded.", "sheet": "objects", "spr": "med_bed", "z": -1, "comps": {"furniture": {"kind": "bed"}}},
	"locker": {"name": "locker", "desc": "It's a basic storage unit.", "sheet": "objects", "spr": "locker_gen",
		"comps": {"blocker": {"dense": true}, "storage": {"kind": "closet", "capacity": 30, "spr": "locker_gen", "spr_open": "locker_gen_open"}}},
	"crate": {"name": "crate", "desc": "A rectangular timber-and-iron crate.", "sheet": "objects", "spr": "crate_gen",
		"comps": {"blocker": {"dense": true}, "storage": {"kind": "closet", "capacity": 30, "horizontal": true, "spr": "crate_gen", "spr_open": "crate_gen_open"}}, "tags": {"anchored": false}},
	"fridge": {"name": "icebox", "desc": "Keeps food cold. Not hard, this high up.", "sheet": "objects", "spr": "fridge",
		"comps": {"blocker": {"dense": true}, "storage": {"kind": "closet", "capacity": 40, "spr": "fridge", "spr_open": "fridge"}}},
	# tg dressing (tools/artgen/decor2.py)
	"iv_drip": {"name": "IV drip", "desc": "An IV drip with an advanced infusion pump.", "sheet": "objects", "spr": "iv_drip", "comps": {"fixture": {"kind": "iv_drip"}, "storage": {"kind": "bag", "capacity": 4, "max_w": 3, "slots": 1, "holds": ["chem"]}, "blocker": {"dense": false}}},
	"bar_stool": {"name": "bar stool", "desc": "It has some unsavory stains on it...", "sheet": "objects", "spr": "bar_stool", "comps": {"furniture": {"kind": "seat"}}},
	"jukebox": {"name": "jukebox", "desc": "A classic music player.", "sheet": "objects", "spr": "jukebox", "comps": {"fixture": {"kind": "jukebox"}, "machine": {"idle": 20.0, "hp": 100}, "blocker": {"dense": true}}},
	"arcade": {"name": "penny arcade", "desc": "A brass gaming machine. Does not support Pinball.", "sheet": "objects", "spr": "arcade", "comps": {"fixture": {"kind": "arcade"}, "machine": {"idle": 20.0, "hp": 100}, "blocker": {"dense": true}}},
	"noticeboard": {"name": "notice board", "desc": "A board for pinning important notices upon.", "sheet": "objects", "spr": "noticeboard", "wall": true, "comps": {"fixture": {"kind": "noticeboard"}, "storage": {"kind": "bag", "capacity": 5, "max_w": 1, "slots": 5, "holds": ["paper"]}}},
	"med_cabinet": {"name": "apothecary cabinet", "desc": "A wall-mounted cabinet of medical supplies.", "sheet": "objects", "spr": "med_cabinet", "wall": true,
		"comps": {"vending": {"products": [["gauze", 4], ["bruise_pack", 3], ["ointment", 3], ["medipen", 2]]}}},
	"curtain": {"name": "curtain", "desc": "A privacy curtain on a ceiling rail.", "sheet": "objects", "spr": "curtain_open",
		"comps": {"blocker": {"dense": false, "opaque": false}, "curtain": {}}},
	"shower": {"name": "shower", "desc": "A ship shower: a cistern, a pull-chain and a very brief supply of warm water.", "sheet": "objects", "spr": "shower", "z": -1, "comps": {"fixture": {"kind": "shower"}}},
	"toilet": {"name": "ship head", "desc": "A brass-and-copper waste-disposal unit that drops it all overboard. Do not think about where it lands.", "sheet": "objects", "spr": "toilet", "comps": {"furniture": {"kind": "seat"}}},
	"mirror": {"name": "mirror", "desc": "Mirror mirror on the wall, who's the fairest of the fleet?", "sheet": "objects", "spr": "mirror", "wall": true, "comps": {"fixture": {"kind": "mirror"}}},
	"bench": {"name": "bench", "desc": "Perfect for sitting on.", "sheet": "objects", "spr": "bench", "comps": {"furniture": {"kind": "seat"}}},
	"protolathe": {"name": "artificer's lathe", "desc": "Converts raw materials into useful objects.", "sheet": "objects", "spr": "rnd_protolathe", "comps": {"blocker": {"dense": true}, "machine": {"idle": 40.0, "active_w": 1500.0, "hp": 120}, "lathe": {"kind": "protolathe"}}},
	"destructive_analyzer": {"name": "breaking bench", "desc": "Learn by taking things apart!", "sheet": "objects", "spr": "rnd_analyzer", "comps": {"blocker": {"dense": true}, "machine": {"idle": 40.0, "hp": 120}, "danalyzer": {}}},
	"server_rack": {"name": "ledger engine", "desc": "A clockwork engine that processes arbitrary information.", "sheet": "objects", "spr": "rnd_server", "comps": {"blocker": {"dense": true}, "machine": {"idle": 60.0, "hp": 120}}},
	"wardrobe": {"name": "wardrobe", "desc": "It's a storage unit for standard-issue attire.", "sheet": "objects", "spr": "wardrobe", "comps": {"blocker": {"dense": true}, "storage": {"kind": "closet", "capacity": 14}}},
	"display_case": {"name": "display case", "desc": "A display case for prized possessions.", "sheet": "objects", "spr": "display_case", "comps": {"fixture": {"kind": "display"}, "storage": {"kind": "bag", "capacity": 4, "max_w": 4, "slots": 1}, "blocker": {"dense": true}}},
	"wall_clock": {"name": "clock", "desc": "Ship's time, for all the good it does.", "sheet": "objects", "spr": "wall_clock", "wall": true, "comps": {"fixture": {"kind": "clock"}}},
	"pegboard": {"name": "tool pegboard", "desc": "Every tool in its place.", "sheet": "objects", "spr": "pegboard", "wall": true},
	"sink": {"name": "sink", "desc": "A sink used for washing one's hands and face.", "sheet": "objects", "spr": "sink", "comps": {"fixture": {"kind": "sink"}, "blocker": {"dense": true}}},
	"trash_bin": {"name": "trash bin", "desc": "For trash.", "sheet": "objects", "spr": "trash_bin", "comps": {"fixture": {"kind": "trash_bin"}, "storage": {"kind": "bag", "capacity": 24, "max_w": 3}, "blocker": {"dense": true}}},
	"disposal": {"name": "disposal unit", "desc": "A pneumatic waste disposal unit.", "sheet": "objects", "spr": "disposal", "comps": {"fixture": {"kind": "disposal"}, "storage": {"kind": "bag", "capacity": 60, "max_w": 4}, "machine": {"idle": 20.0, "hp": 100}, "blocker": {"dense": true}}},
	"potted_plant": {"name": "potted plant", "desc": "A little bit of nature contained in a pot.", "sheet": "objects", "spr": "potted_plant_0",
		"comps": {"blocker": {"dense": true}, "flammable": {"fuel": 15.0}}},
	"bookshelf": {"name": "bookshelf", "desc": "A great place for storing knowledge.", "sheet": "objects", "spr": "bookshelf",
		"comps": {"blocker": {"dense": true, "opaque": false}, "flammable": {"fuel": 40.0}}},
	# ------------------------------------------------------------- exterior
	"floodlight": {"name": "floodlight", "desc": "Lights up the ground around the port.", "sheet": "objects", "spr": "floodlight",
		"comps": {"blocker": {"dense": true}, "light": {"kind": "always", "radius": 9.0, "color": "#fff1d8", "energy": 1.05}}},
	"antenna": {"name": "signal mast", "desc": "The port's link to the wider sky.", "sheet": "objects", "spr": "antenna",
		"comps": {"blocker": {"dense": true}, "machine": {"needs_power": false, "hp": 150}, "light": {"kind": "always", "radius": 1.5, "color": "#ff3a2a", "energy": 0.5}}},
	"drift": {"name": "snowdrift", "desc": "Wind-packed snow.", "sheet": "objects", "spr": "drift_0", "z": -1, "comps": {}},
	"ice_crystal": {"name": "ice crystal", "desc": "A cluster of glowing frostglass crystals.", "sheet": "objects", "spr": "ice_crystal_0",
		"comps": {"blocker": {"dense": true}, "light": {"kind": "always", "radius": 3.0, "color": "#5ae0ff", "energy": 0.6}}},
	"boulder": {"name": "boulder", "desc": "A frozen boulder.", "sheet": "objects", "spr": "boulder_0", "comps": {"blocker": {"dense": true}}},
	"lichen": {"name": "frost lichen", "desc": "Bioluminescent lichen. It glows faintly in the dark.", "sheet": "objects", "spr": "lichen_0", "z": -1,
		"comps": {"light": {"kind": "always", "radius": 1.8, "color": "#2ad8c8", "energy": 0.35}}},
	"fuel_tank": {"name": "fuel tank", "desc": "A tank full of torch fuel. Refill blowtorches by using them on it. Do not use a lit one.", "sheet": "objects", "spr": "fuel_tank",
		"comps": {"fueltank": {}, "blocker": {"dense": true}}, "tags": {"anchored": false}},
	"crawler_engine": {"name": "drive unit", "desc": "One of the crawler's diesel-electric drive units. It's warm to the touch.", "sheet": "objects", "spr": "crawler_engine",
		"comps": {"blocker": {"dense": true}, "light": {"kind": "always", "radius": 1.6, "color": "#ff7a2a", "energy": 0.45}}},
	"crawler_tread": {"name": "crawler track", "desc": "A caterpillar track as tall as you are, packed with ice.", "sheet": "objects", "spr": "tread_v_mid",
		"comps": {"blocker": {"dense": true}}},
	"supply_pod": {"name": "supply drop", "desc": "A Guild supply drop.", "sheet": "objects", "spr": "supply_pod",
		"comps": {"blocker": {"dense": true}, "storage": {"kind": "closet", "capacity": 40}, "light": {"kind": "always", "radius": 2.5, "color": "#ff5a3a", "energy": 0.6}}},
	# ------------------------------------------------------------- decals
	"decal_blood": {"name": "blood", "desc": "It's red.", "sheet": "objects", "spr": "blood_0", "z": -2, "comps": {"decal": {"kind": "blood"}}},
	"decal_vomit": {"name": "vomit", "desc": "Gross.", "sheet": "objects", "spr": "puddle_vomit", "z": -2, "comps": {"decal": {"kind": "vomit", "slippery": true}}},
	"decal_water": {"name": "puddle", "desc": "A puddle of water. Slippery!", "sheet": "objects", "spr": "puddle_water", "z": -2, "comps": {"decal": {"kind": "water", "slippery": true, "dry": 120.0}}},
	"decal_oil": {"name": "oil", "desc": "Engine oil.", "sheet": "objects", "spr": "puddle_oil", "z": -2, "comps": {"decal": {"kind": "oil", "slippery": true}}},
	"decal_glass": {"name": "tiny shards", "desc": "Back to sand.", "sheet": "objects", "spr": "glass_debris_0", "z": -2, "comps": {"decal": {"kind": "glass"}}},
	"decal_scorch": {"name": "scorch marks", "desc": "Something burned here.", "sheet": "objects", "spr": "scorch_0", "z": -2, "comps": {"decal": {"kind": "scorch"}}},
	"liquid_water": {"name": "puddle of water", "sheet": "objects", "spr": "liquid_water_1", "z": -2, "comps": {"decal": {"kind": "water", "slippery": true, "liquid": true}}},
	"liquid_ice": {"name": "ice sheet", "sheet": "objects", "spr": "liquid_ice_1", "z": -2, "comps": {"decal": {"kind": "ice", "slippery": true, "liquid": true}}},
	"liquid_fuel": {"name": "welding fuel", "sheet": "objects", "spr": "liquid_fuel_1", "z": -2, "comps": {"decal": {"kind": "fuel", "slippery": true, "liquid": true}}},
	"liquid_oil": {"name": "oil slick", "sheet": "objects", "spr": "liquid_oil_1", "z": -2, "comps": {"decal": {"kind": "oil", "slippery": true, "liquid": true}}},
	"liquid_coolant": {"name": "coolant", "sheet": "objects", "spr": "liquid_coolant_1", "z": -2, "comps": {"decal": {"kind": "coolant", "slippery": true, "liquid": true}}},
	"liquid_vomit": {"name": "vomit", "sheet": "objects", "spr": "liquid_vomit_1", "z": -2, "comps": {"decal": {"kind": "vomit", "slippery": true, "liquid": true}}},
	"liquid_blood": {"name": "pool of blood", "sheet": "objects", "spr": "liquid_blood_1", "z": -2, "comps": {"decal": {"kind": "blood", "liquid": true}}},
	# ------------------------------------------------------------- critters
	"mouse": {"name": "mouse", "desc": "It's a small, disease-ridden rodent.", "sheet": "objects", "spr": "mouse_e", "z": 1,
		"comps": {"vermin": {}}},
	"mouse_dead": {"name": "dead mouse", "desc": "It's not squeaking any more.", "sheet": "objects", "spr": "mouse_dead",
		"comps": {"item": {"w": 1, "cat": "trash"}}},
	"decal_coolant": {"name": "coolant", "desc": "Reactor coolant residue.", "sheet": "objects", "spr": "puddle_coolant", "z": -2, "comps": {"decal": {"kind": "coolant", "slippery": true, "dry": 200.0}}},
	"debris": {"name": "metal debris", "desc": "Twisted metal.", "sheet": "items", "spr": "debris", "comps": {"item": {"w": 3, "cat": "material"}, "stack": {"amount": 2, "material": "metal"}}},
	# ------------------------------------------------------------- tg gadgets (CGadget)
	"flash": {"name": "flash", "desc": "A powerful and versatile flashbulb device. Blinds and knocks down whoever it's used on; Z flashes everyone around you. Overuse burns it out.", "sheet": "items", "spr": "flash",
		"comps": {"item": {"w": 1, "cat": "weapon", "slots": TOOL_SLOTS}, "gadget": {"kind": "flash", "charges": 0}}},
	"pepperspray": {"name": "pepper spray", "desc": "Brewed by a Meridian apothecary, used to blind and down an opponent quickly.", "sheet": "items", "spr": "pepperspray",
		"comps": {"item": {"w": 1, "cat": "weapon", "slots": TOOL_SLOTS}, "gadget": {"kind": "pepperspray", "charges": 10}}},
	"spray_bottle": {"name": "deck cleaner", "desc": "BLAM!-brand non-foaming deck cleaner! Sprays clean the floor in front of you.", "sheet": "items", "spr": "spray_bottle",
		"comps": {"item": {"w": 2, "cat": "tool", "slots": TOOL_SLOTS}, "gadget": {"kind": "spray", "charges": 25}}},
	"lighter": {"name": "cheap lighter", "desc": "A cheap-as-free lighter. Z to flick it.", "sheet": "items", "spr": "lighter",
		"comps": {"item": {"w": 1, "cat": "tool", "slots": TOOL_SLOTS}, "gadget": {"kind": "lighter"},
			"light": {"kind": "item", "radius": 1.8, "color": "#ffb05a", "energy": 0.6, "on": false}}},
	"cigarette": {"name": "cigarette", "desc": "A roll of tobacco and nicotine. Wear it, then light it.", "sheet": "items", "spr": "cigarette",
		"comps": {"item": {"w": 1, "cat": "misc", "slots": ["mask"]}, "clothing": {"slot": "mask", "sprite": "mask_cigarette", "colors": ["#f4f0e8", "#ff6a2a"]}, "gadget": {"kind": "cigarette", "burn": 180.0}}},
	"cig_pack": {"name": "pack of cigarettes", "desc": "Skyleaf cigarettes. Smoking is bad for you.", "sheet": "items", "spr": "cig_pack",
		"comps": {"item": {"w": 1, "cat": "misc", "slots": TOOL_SLOTS}, "storage": {"kind": "bag", "capacity": 6, "max_w": 1}}, "fill": ["cigarette", "cigarette", "cigarette", "cigarette", "cigarette", "cigarette"]},
	"holofan": {"name": "shimmer projector", "desc": "A projector that raises shimmering barriers that keep the air conditions from changing.", "sheet": "items", "spr": "holofan",
		"comps": {"item": {"w": 2, "cat": "tool", "slots": TOOL_SLOTS}, "gadget": {"kind": "holofan", "charges": 6}}},
	"pen": {"name": "pen", "desc": "It's a normal black ink pen. Use it on paper to write.", "sheet": "items", "spr": "pen",
		"comps": {"item": {"w": 1, "force": 0, "sharp": "pointy", "cat": "tool", "slots": TOOL_SLOTS}, "gadget": {"kind": "pen"}}},
	# ------------------------------------------------------------- surgery (tg)
	"scalpel": {"name": "scalpel", "desc": "Cut, cut, and once more cut.", "sheet": "items", "spr": "scalpel",
		"comps": {"item": {"w": 1, "force": 10, "throwforce": 5, "wound": 10, "exposed": 15, "demo": 0.25, "cat": "medical", "verb": "slashes", "sharp": "edged"}, "surgerytool": {"kind": "scalpel"}}},
	"hemostat": {"name": "hemostat", "desc": "You think you have seen this before.", "sheet": "items", "spr": "hemostat",
		"comps": {"item": {"w": 1, "force": 0, "cat": "medical"}, "surgerytool": {"kind": "hemostat"}}},
	"retractor": {"name": "retractor", "desc": "Retracts stuff.", "sheet": "items", "spr": "retractor",
		"comps": {"item": {"w": 1, "force": 0, "cat": "medical"}, "surgerytool": {"kind": "retractor"}}},
	"cautery": {"name": "cautery", "desc": "This stops bleeding.", "sheet": "items", "spr": "cautery",
		"comps": {"item": {"w": 1, "force": 0, "cat": "medical"}, "surgerytool": {"kind": "cautery"}}},
	"circular_saw": {"name": "circular saw", "desc": "For heavy duty cutting.", "sheet": "items", "spr": "circular_saw",
		"comps": {"item": {"w": 3, "force": 15, "throwforce": 9, "wound": 15, "exposed": 10, "cat": "medical", "verb": "saws", "sharp": "edged"}, "surgerytool": {"kind": "saw"}}},
	"surgical_drapes": {"name": "surgical drapes", "desc": "Guild-approved surgical drapes provide optimal safety and infection control.", "sheet": "items", "spr": "surgical_drapes",
		"comps": {"item": {"w": 2, "cat": "medical"}, "surgerytool": {"kind": "drapes"}}},
	"gauze": {"name": "medical gauze", "desc": "A roll of elastic cloth, perfect for stabilizing all kinds of wounds, from cuts and burns, to broken bones.", "sheet": "items", "spr": "gauze",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "meditem": {"kind": "gauze"}}},
	"medipen": {"name": "epinephrine autoinjector", "desc": "A rapid and safe way to stabilize patients in critical condition for crew without advanced medical knowledge.", "sheet": "items", "spr": "medipen",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "reagents": {"kind": "medipen", "volume": 15.0, "contents": {"epinephrine": 10.0, "atropine": 3.0}}}},
	"defib": {"name": "defibrillator", "desc": "A device that delivers powerful shocks to restart a heart. Works on the recently dead (about five minutes).", "sheet": "items", "spr": "defib",
		"comps": {"item": {"w": 4, "cat": "medical", "slots": ["back", "belt"]}, "gadget": {"kind": "defib", "charges": 8}}},
	"disabler": {"name": "aether stunner", "desc": "A self-defence weapon that exhausts organic targets, weakening them until they collapse.", "sheet": "items", "spr": "disabler",
		"comps": {"item": {"w": 2, "force": 5, "throwforce": 5, "cat": "weapon", "slots": ["belt", "suit_store"]}, "gadget": {"kind": "gun", "sub": "disabler", "charges": 20}}},
	"laser_gun": {"name": "aether pistol", "desc": "A basic aether-lance pistol that fires concentrated beams of light which pass through glass.", "sheet": "items", "spr": "laser_gun",
		"comps": {"item": {"w": 3, "force": 5, "throwforce": 5, "cat": "weapon", "slots": ["belt", "back"]}, "gadget": {"kind": "gun", "sub": "laser", "charges": 16}}},
	"egun": {"name": "aether carbine", "desc": "A basic hybrid aether carbine with two settings: disable and kill. Z switches.", "sheet": "items", "spr": "egun_stun",
		"comps": {"item": {"w": 3, "force": 5, "throwforce": 5, "cat": "weapon", "slots": ["belt", "back"]}, "gadget": {"kind": "gun", "sub": "egun", "charges": 16}}},
	"flashbang": {"name": "flash bomb", "desc": "A flash bomb. Z pulls the pin; five seconds later, everyone nearby gets blinded and knocked down.", "sheet": "items", "spr": "flashbang",
		"comps": {"item": {"w": 1, "throwforce": 5, "cat": "weapon", "slots": TOOL_SLOTS}, "gadget": {"kind": "grenade", "sub": "flash"}}},
	"smoke_grenade": {"name": "smoke grenade", "desc": "Z pulls the pin; five seconds later it fills the area with smoke.", "sheet": "items", "spr": "smoke_grenade",
		"comps": {"item": {"w": 1, "throwforce": 5, "cat": "weapon", "slots": TOOL_SLOTS}, "gadget": {"kind": "grenade", "sub": "smoke"}}},
	"welding_helmet": {"name": "blowtorch mask", "desc": "A head-mounted face cover designed to protect the wearer completely from torch-glare. Also stops flashes.", "sheet": "items", "spr": "welding_helmet",
		"comps": {"item": {"w": 3, "force": 8, "cat": "clothing", "slots": ["head"]}, "clothing": {"slot": "head", "sprite": "head_welding", "colors": ["#4a5262", "#1d2230", "#e8c83a"], "hides_hair": true}}},
	# tg /obj/item/clothing/glasses/regular: the nearsighted quirk's prescription pair
	"prescription_glasses": {"name": "prescription glasses", "desc": "Ground by a Meridian optician.", "sheet": "items", "spr": "glasses",
		"comps": {"item": {"w": 1, "cat": "clothing", "slots": ["eyes"]}, "clothing": {"slot": "eyes", "sprite": "mask_sunglasses", "colors": ["#a8c8e0"], "vision_correction": true}}},
	"sunglasses": {"name": "tinted goggles", "desc": "Smoked lenses in a brass frame. Protects against flashes.", "sheet": "items", "spr": "sunglasses",
		"comps": {"item": {"w": 1, "cat": "clothing", "slots": ["eyes"]}, "clothing": {"slot": "eyes", "sprite": "mask_sunglasses", "colors": ["#1d1b22"]}}},
	"recharger": {"name": "recharger", "desc": "A charging dock for aether weaponry. Use a gun or defibrillator on it.", "sheet": "objects", "spr": "recharger",
		"comps": {"machine": {"idle": 20.0, "active_w": 1500.0, "hp": 80}, "recharger": {}}},
	# ------------------------------------------------------------- improvised (see Crafting)
	"shiv": {"name": "glass shiv", "desc": "A glass shard with a cable-wrapped grip. Made for one thing.", "sheet": "items", "spr": "shiv",
		"comps": {"item": {"w": 1, "force": 8, "throwforce": 12, "sharp": "edged", "wound": 5, "exposed": 15, "demo": 0.75, "cat": "weapon", "verb": "stabs", "slots": TOOL_SLOTS}}},
	"spear": {"name": "spear", "desc": "A glass point lashed to a metal rod. Z to wield it with both hands.", "sheet": "items", "spr": "spear",
		"comps": {"item": {"conducts": true, "w": 4, "force": 10, "wield": 18, "throwforce": 20, "sharp": "pointy", "wound": -15, "exposed": 15, "ap": 5, "demo": 0.75, "cat": "weapon", "verb": "stabs", "slots": ["back"]}}},
	"molotov": {"name": "molotov cocktail", "desc": "A bottle of spirits with a rag in the neck. Light it with a blowtorch, then throw it.", "sheet": "items", "spr": "molotov",
		"comps": {"item": {"w": 2, "force": 15, "throwforce": 15, "demo": 0.25, "cat": "weapon", "verb": "smashes"}, "molotov": {}}},
	"cable_cuffs": {"name": "cable restraints", "desc": "Cable coil twisted into cuffs.", "sheet": "items", "spr": "cable_cuffs",
		"comps": {"item": {"w": 1, "cat": "restraint", "slots": TOOL_SLOTS}, "secgear": {"kind": "cuffs"}}},
	# ------------------------------------------------------------- tg genetics (dna_scanner.dm, dna_console.dm, dna_injector.dm...)
	"dna_scanner": {"name": "DNA scanner", "desc": "It scans DNA structures.", "sheet": "objects", "spr": "dna_scanner_open",
		"comps": {"machine": {"idle": 50.0, "active_w": 300.0, "hp": 150}, "blocker": {"dense": false}, "dnascanner": {}}},
	"dna_console": {"name": "DNA Console", "desc": "From here you can research mysteries of the DNA!", "sheet": "objects", "spr": "console_dna",
		"comps": {"machine": {"idle": 300.0, "hp": 100}, "blocker": {"dense": true}, "dnaconsole": {}, "light": {"kind": "machine", "radius": 2.2, "color": "#6a9aff", "energy": 0.5}}},
	"dna_injector": {"name": "DNA injector", "desc": "A cheap single use autoinjector that injects the user with DNA.", "sheet": "items", "spr": "dnainjector",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "dnainjector": {"kind": "injector"}}},
	"dna_activator": {"name": "DNA activator", "desc": "Activates the current mutation on injection, if the subject has it.", "sheet": "items", "spr": "dnainjector",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "dnainjector": {"kind": "activator"}}},
	"dna_injector_timed": {"name": "DNA injector", "desc": "A cheap single use autoinjector that injects the user with DNA.", "sheet": "items", "spr": "dnainjector",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "dnainjector": {"kind": "timed", "duration": 60.0}}},
	"dna_injector_hulk": {"name": "DNA injector (Hulk)", "desc": "This will make you big and strong, but give you a bad skin condition.", "sheet": "items", "spr": "dnainjector",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "dnainjector": {"kind": "timed", "duration": 60.0, "add": ["hulk"]}}},
	"dna_injector_h2m": {"name": "DNA injector (Human > Monkey)", "desc": "Will make you a flea bag.", "sheet": "items", "spr": "dnainjector",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "dnainjector": {"kind": "timed", "duration": 60.0, "add": ["race"]}}},
	"chromosome_stabilizer": {"name": "stabilizer chromosome", "desc": "A chromosome that reduces mutation instability by 20%.", "sheet": "items", "spr": "chromosome_stabilizer",
		"comps": {"item": {"w": 2, "cat": "medical"}, "chromosome": {"kind": "stabilizer"}}},
	"chromosome_synchronizer": {"name": "synchronizer chromosome", "desc": "A chromosome that reduces mutation knockback and downsides by 50%.", "sheet": "items", "spr": "chromosome_synchronizer",
		"comps": {"item": {"w": 2, "cat": "medical"}, "chromosome": {"kind": "synchronizer"}}},
	"chromosome_power": {"name": "power chromosome", "desc": "A chromosome that increases mutation power by 50%.", "sheet": "items", "spr": "chromosome_power",
		"comps": {"item": {"w": 2, "cat": "medical"}, "chromosome": {"kind": "power"}}},
	"chromosome_energy": {"name": "energetic chromosome", "desc": "A chromosome that reduces action based mutation cooldowns by 50%.", "sheet": "items", "spr": "chromosome_energy",
		"comps": {"item": {"w": 2, "cat": "medical"}, "chromosome": {"kind": "energy"}}},
	"dna_disk": {"name": "DNA data disk", "desc": "A floppy disk for carrying mutations and genetic makeups between DNA consoles. Z flips the write-protect tab.", "sheet": "items", "spr": "datadisk0",
		"comps": {"item": {"w": 1, "cat": "misc", "slots": TOOL_SLOTS}, "dnadisk": {}}},
	"disk_box": {"name": "floppy disk box", "desc": "A set of 8 Guild-approved floppy disks in individual packaging.", "sheet": "items", "spr": "box_disks",
		"comps": {"item": {"w": 2, "cat": "container"}, "storage": {"kind": "bag", "capacity": 8, "max_w": 1, "slots": 8}}, "fill": ["dna_disk", "dna_disk", "dna_disk", "dna_disk", "dna_disk", "dna_disk", "dna_disk", "dna_disk"]},
	"sequence_scanner": {"name": "genetic sequence scanner", "desc": "A hand-held scanner for analyzing someones gene sequence on the fly. Use on a DNA console to update the internal database.", "sheet": "items", "spr": "gene_scanner",
		"comps": {"item": {"w": 1, "throwforce": 3, "cat": "medical", "slots": ["belt", "pocket_l", "pocket_r"], "conducts": true}, "seqscanner": {}}},
	"tk_grab": {"name": "Telekinetic Grab", "desc": "A focused object controlled by thought.", "sheet": "items", "spr": "gene_scanner", "tags": {"telekinetic_grab": true, "abstract_hand": true}, "comps": {"item": {"w": 1}, "tkgrab": {}}},
	"stock_part": {"name": "stock part", "desc": "An upgradeable machine component.", "sheet": "items", "spr": "multitool", "comps": {"item": {"w": 2, "cat": "tool", "slots": TOOL_SLOTS}, "stockpart": {}}},
	"skillchip": {"name": "lesson card", "sheet": "items", "spr": "circuit_board", "comps": {"item": {"w": 2, "cat": "medical"}, "skillchip": {}}},
	"skill_station": {"name": "lesson lectern", "desc": "Insert a lesson card, then enter to learn, activate or remove it.", "sheet": "objects", "spr": "dna_scanner_open", "comps": {"machine": {"idle": 100.0, "hp": 100}, "blocker": {"dense": false}, "skillstation": {}}},
	"mineral_hand": {"name": "mineral hand", "sheet": "items", "spr": "ore_gold", "tags": {"abstract_hand": true}, "comps": {"item": {"w": 4}, "mineralhand": {}}},
	"rock_glow": {"name": "mineral glow", "comps": {"light": {"kind": "always", "radius": 3.0, "energy": 1.0}}},
	"petrified_statue": {"name": "petrified statue", "desc": "A lifelike marble statue. Breaking it destroys the body inside; intact statues release their occupant after eight minutes.", "tags": {"anchored": true}, "comps": {"blocker": {"dense": true}, "statue": {}}},
	"psychic_wall": {"name": "psychic wall", "tags": {"anchored": true}, "comps": {"blocker": {"dense": true}, "psychicwall": {}}},
	"sheet_plasteel": {"name": "plasteel sheets", "sheet": "items", "spr": "sheet_metal", "comps": {"item": {"w": 2, "cat": "material"}, "stack": {"amount": 5, "material": "plasteel"}}},
	"sheet_gold": {"name": "gold sheets", "sheet": "items", "spr": "ore_gold", "comps": {"item": {"w": 2, "cat": "material"}, "stack": {"amount": 5, "material": "gold"}}},
	"sheet_silver": {"name": "silver sheets", "sheet": "items", "spr": "sheet_metal", "comps": {"item": {"w": 2, "cat": "material"}, "stack": {"amount": 5, "material": "silver"}}},
	"sheet_uranium": {"name": "uranium sheets", "sheet": "items", "spr": "ore_plasma", "comps": {"item": {"w": 2, "cat": "material"}, "stack": {"amount": 5, "material": "uranium"}}},
	"sheet_titanium": {"name": "titanium sheets", "sheet": "items", "spr": "sheet_metal", "comps": {"item": {"w": 2, "cat": "material"}, "stack": {"amount": 5, "material": "titanium"}}},
	"sheet_diamond": {"name": "diamond sheets", "sheet": "items", "spr": "sheet_glass", "comps": {"item": {"w": 2, "cat": "material"}, "stack": {"amount": 5, "material": "diamond"}}},
	"sheet_bananium": {"name": "brightmetal sheets", "sheet": "items", "spr": "ore_gold", "comps": {"item": {"w": 2, "cat": "material"}, "stack": {"amount": 5, "material": "bananium"}}},
	"sheet_bluespace": {"name": "aether crystals", "sheet": "items", "spr": "ore_gold", "comps": {"item": {"w": 2, "cat": "material"}, "stack": {"amount": 5, "material": "bluespace"}}},
	"ore_gibtonite": {"name": "gibtonite ore", "sheet": "items", "spr": "ore_plasma", "comps": {"item": {"w": 4, "cat": "material"}}},
	"monkey_cube": {"name": "monkey cube", "desc": "Just add water!", "sheet": "items", "spr": "monkeycube", "tags": {"monkeycube": true, "spawns": "monkey"},
		"comps": {"item": {"w": 1, "cat": "food", "slots": TOOL_SLOTS}, "food": {"nutrition": 6, "bites": 3, "mood": 0, "chems": {"monkey_powder": 30.0}}}},
	"monkey_cube_box": {"name": "monkey cube box", "desc": "Apothecary-brand monkey cubes. Just add water!", "sheet": "items", "spr": "box_monkeycubes",
		"comps": {"item": {"w": 2, "cat": "container"}, "storage": {"kind": "bag", "capacity": 7, "max_w": 1, "slots": 7}}, "fill": ["monkey_cube", "monkey_cube", "monkey_cube", "monkey_cube", "monkey_cube"]},
	"pill_mutadone": {"name": "mutadone pill", "desc": "Used to treat genetic damage.", "sheet": "items", "spr": "pill", "tint": "#5096c8",
		"comps": {"item": {"w": 1, "cat": "medical", "slots": TOOL_SLOTS}, "reagents": {"kind": "pill", "volume": 50.0, "contents": {"mutadone": 5.0}}}},
	"pill_bottle_mutadone": {"name": "bottle of mutadone pills", "desc": "Contains pills used to treat genetic abnormalities.", "sheet": "items", "spr": "pill_bottle",
		"comps": {"item": {"w": 2, "cat": "medical", "slots": TOOL_SLOTS}, "storage": {"kind": "bag", "capacity": 7, "max_w": 1, "slots": 7}}, "fill": ["pill_mutadone", "pill_mutadone", "pill_mutadone", "pill_mutadone", "pill_mutadone", "pill_mutadone", "pill_mutadone"]},
	"latex_gloves": {"name": "latex gloves", "desc": "Cheap sterile gloves made from latex. Provides quicker carrying from a good grip.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 1, "cat": "clothing", "slots": ["gloves"]}, "clothing": {"slot": "gloves", "sprite": "gloves", "insulation": 0.02, "colors": ["#e8eef4"]}}},
	"labcoat_genetics": {"name": "naturalist's smock", "desc": "A smock that protects against minor chemical spills. Has a blue stripe on the shoulder.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 3, "cat": "clothing", "slots": ["suit"]}, "clothing": {"slot": "suit", "sprite": "suit_labcoat", "insulation": 0.15, "colors": ["#eef2f6", "#3a7ac8"]}}},
	"uniform_genetics": {"name": "naturalist's coveralls", "desc": "It's made of a special fibre that gives special protection against biohazards. It has a naturalist's stripe on it.", "sheet": "items", "spr": "coat_gen",
		"comps": {"item": {"w": 3, "cat": "clothing", "slots": ["uniform"]}, "clothing": {"wound": 5.0, "slot": "uniform", "sprite": "uniform_jumpsuit", "insulation": 0.1, "colors": ["#e8eef4", "#3a7ac8", "#3a3a40", "#b0b8c4"]}}},
	"backpack_genetics": {"name": "naturalist's pack", "desc": "A bag designed to be super tough, just in case someone hulks out on you.", "sheet": "items", "spr": "toolbox_blue",
		"comps": {"item": {"w": 4, "cat": "container", "slots": ["back"]}, "storage": {"kind": "bag", "capacity": 21, "max_w": 3, "slots": 21},
			"clothing": {"slot": "back", "sprite": "backpack", "colors": ["#e8eef4", "#3a7ac8"]}}},
	# what the genetic powers leave behind
	"sheet_snow": {"name": "snow", "desc": "Some snow, packed into a block.", "sheet": "items", "spr": "sheet_snow",
		"comps": {"item": {"w": 3, "force": 1, "throwforce": 2, "cat": "material"}, "stack": {"amount": 1, "material": "snow"}}},
	"ash": {"name": "ashes", "desc": "Ashes to ashes, dust to dust, and into the wind.", "sheet": "objects", "spr": "ash", "z": -2, "comps": {"decal": {"kind": "ash", "cleanable": true}}},
	"web_genetic": {"name": "web", "desc": "It's stringy, sticky, and came out of your shipmate.", "sheet": "objects", "spr": "stickyweb", "z": -1, "integrity": 15, "comps": {"web": {}}},
	"void_hole": {"name": "hole in reality", "desc": "It's shaped an awful lot like a person.", "sheet": "objects", "spr": "void_hole", "z": -1, "comps": {}},
	"tongue_spike": {"name": "biomass spike", "desc": "Hardened biomass, shaped into a spike. Very pointy!", "sheet": "items", "spr": "tonguespike",
		"comps": {"item": {"w": 2, "force": 2, "throwforce": 25, "sharp": "pointy", "cat": "weapon"}}},
	"chem_spike": {"name": "chem spike", "desc": "Hardened biomass, shaped into... something.", "sheet": "items", "spr": "tonguespikechem",
		"comps": {"item": {"w": 2, "force": 2, "throwforce": 2, "sharp": "pointy", "cat": "weapon"}}},
	"glass_shard": {"name": "glass shard", "desc": "A nasty looking shard of glass.", "sheet": "items", "spr": "glass_shard", "spr_pick": ["glass_shard", "glass_shard_medium", "glass_shard_small"],
		"comps": {"item": {"w": 1, "force": 5, "throwforce": 10, "sharp": "edged", "verb": "slashes", "caltrop": 5, "cat": "trash"}}},
}

static func has(id: String) -> bool:
	return P.has(id)

static func category(id: String) -> String:
	var d: Dictionary = P.get(id, {})
	return d.get("comps", {}).get("item", {}).get("cat", "misc")

static func spawn(id: String, cell: Vector2i, ov: Dictionary = {}) -> Entity:
	var d: Dictionary = P.get(id, {})
	if d.is_empty():
		push_error("unknown proto " + id)
		d = P["paper"]
	var e := Entity.new()
	e.proto = id
	e.display_name = ov.get("name", d.get("name", id))
	e.desc = ov.get("desc", d.get("desc", ""))
	e.wall_mounted = d.get("wall", false)
	e.tags = d.get("tags", {}).duplicate()
	e.cell = cell
	e.position = Entity.cell_to_pos(cell)
	e.z_index = d.get("z", 1 if d.get("comps", {}).has("mob") else 0) # tg: mobs sit above objects
	Game.ents_node.add_child(e)
	var spr_name: String = ov.get("spr", d.get("spr", ""))
	if not ov.has("spr") and d.has("spr_pick"):
		spr_name = d["spr_pick"][randi() % d["spr_pick"].size()] # tg: pick("large", "medium", "small")
	e.set_sprite(d.get("sheet", "items"), spr_name)
	var comps: Dictionary = d.get("comps", {})
	var cov: Dictionary = ov.get("comps", {})
	for cname in comps:
		var params: Dictionary = comps[cname].duplicate()
		if cov.has(cname):
			params.merge(cov[cname], true)
		var comp := make_comp(cname, params)
		if comp:
			e.add(comp)
	for cname in cov:
		if not comps.has(cname):
			var comp2 := make_comp(cname, cov[cname])
			if comp2:
				e.add(comp2)
	# tg: lockers and crates aren't bolted down; you can drag them around
	if e.has_c(&"storage") and e.c(&"storage").kind == "closet" and not e.tags.has("anchored"):
		e.tags["anchored"] = false
	# tg: solid structures can be smashed (machines and bodies keep their own damage)
	if not e.has_c(&"integrity") and not e.has_c(&"machine") and not e.has_c(&"health") and not e.has_c(&"item") \
			and (d.has("integrity") or (e.has_c(&"blocker") and e.c(&"blocker").dense) or e.has_c(&"furniture")):
		var over := {}
		if d.has("integrity"):
			over["hp"] = float(d["integrity"])
		e.add(CIntegrity.for_entity(e, over))
	Game.register(e)
	if ov.has("tint") or d.has("tint"):
		e.spr.modulate = Color(ov.get("tint", d.get("tint", "#ffffff")))
	for f in ([] if ov.get("nofill", false) else d.get("fill", [])):
		var it := spawn(f, cell)
		e.c(&"storage").insert(it)
	return e

static func make_comp(cname: String, p: Dictionary) -> Component:
	match cname:
		"item": return CItem.new().setup(p)
		"clothing": return CClothing.new().setup(p)
		"idcard": return CIdCard.new().setup(p)
		"headset": return CHeadset.new().setup(p)
		"blocker": return CBlocker.new().setup(p)
		"door": return CDoor.new().setup(p)
		"storage": return CStorage.new().setup(p)
		"machine": return CMachine.new().setup(p)
		"light": return CLight.new().setup(p)
		"apc": return CApc.new()
		"air_alarm": return CAirAlarm.new()
		"vent": return CVent.new().setup(p)
		"heater": return CHeater.new()
		"reactor": return CReactor.new()
		"powergen": return CPowerGen.new().setup(p)
		"air_supply": return CAirSupply.new()
		"console": return CConsole.new().setup(p)
		"vending": return CVending.new().setup(p)
		"furniture": return CFurniture.new().setup(p)
		"cooker": return CCooker.new()
		"hydro": return CHydro.new().setup(p)
		"botany": return CBotany.new().setup(p)
		"reagents": return CReagents.new().setup(p)
		"welder": return CWelder.new()
		"molotov": return CMolotov.new()
		"gadget": return CGadget.new().setup(p)
		"recharger": return CRecharger.new()
		"pipemachine": return CPipeMachine.new().setup(p)
		"togglelight": return CToggleLight.new().setup(p)
		"tray": return CTray.new()
		"lightswitch": return CLightSwitch.new()
		"spaceheater": return CSpaceHeater.new()
		"extinguisher": return CExtinguisher.new()
		"stack": return CStack.new().setup(p)
		"meditem": return CMedItem.new().setup(p)
		"secgear": return CSecurityGear.new().setup(p)
		"tank": return CTank.new().setup(p)
		"canister": return CCanister.new().setup(p)
		"meter": return CMeter.new().setup(p)
		"pipefitting": return CPipeFitting.new().setup(p)
		"pipedispenser": return CPipeDispenser.new()
		"gasanalyzer": return CGasAnalyzer.new()
		"food": return CFood.new().setup(p)
		"decal": return CDecal.new().setup(p)
		"flammable": return CFlammable.new().setup(p)
		"melt": return CMelt.new().setup(p)
		"fueltank": return CFuelTank.new()
		"vermin": return CVermin.new()
		"statusdisplay": return CStatusDisplay.new()
		"curtain": return CCurtain.new().setup(p)
		"surgerytool": return CSurgeryTool.new().setup(p)
		"firelock": return CFirelock.new()
		"firealarm": return CFireAlarm.new()
		"holosign": return CHolosign.new()
		"lathe": return CLathe.new().setup(p)
		"danalyzer": return CDAnalyzer.new()
		"fixture": return CFixture.new().setup(p)
		"chemmachine": return CChemMachine.new().setup(p)
		"frame": return CFrame.new().setup(p)
		"rcd": return CRCD.new().setup(p)
		"rpd": return CRPD.new()
		"hepipe": return CHEPipe.new().setup(p)
		"dnascanner": return CDnaScanner.new().setup(p)
		"dnaconsole": return CDnaConsole.new().setup(p)
		"dnainjector": return CDnaInjector.new().setup(p)
		"chromosome": return CChromosome.new().setup(p)
		"dnadisk": return CDnaDisk.new().setup(p)
		"seqscanner": return CSeqScanner.new()
		"tkgrab": return CTkGrab.new()
		"stockpart": return CStockPart.new().setup(p)
		"skillchip": return CSkillChip.new().setup(p)
		"skillstation": return CSkillStation.new().setup(p)
		"mineralhand": return MineralHand.new()
		"statue": return CStatue.new()
		"psychicwall": return CPsychicWall.new()
		"web": return CWeb.new()
		# ---- Skyfarer: ships and sky gear
		"helm": return CHelm.new()
		"thruster": return CThruster.new()
		"liftcell": return CLiftCell.new()
		"boiler": return CBoiler.new()
		"fuelbunker": return CFuelBunker.new().setup(p)
		"shipnav": return CShipNav.new()
		"shiprig": return CShipRig.new()
		"glider": return CGlider.new()
		"grapple": return CGrapple.new()
		"skycompass": return CSkyCompass.new().setup(p)
		"spyglass": return CSpyglass.new()
		"shipgun": return CShipGun.new()
		"shipmodule": return CShipModule.new().setup(p)
		"curio": return CCurio.new().setup(p)
		"tonic": return CTonic.new().setup(p)
		"quirkweapon": return CQuirkWeapon.new().setup(p)
		"aethergun": return CAetherGun.new().setup(p)
		"skyrod": return CSkyRod.new()
		"vendor": return CVendor.new().setup(p)
		"shipyard": return CShipyard.new()
		"noticeboard": return CNoticeBoard.new()
	push_error("unknown component " + cname)
	return null
