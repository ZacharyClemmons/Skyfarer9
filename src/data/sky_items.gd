class_name SkyItems extends RefCounted
## The second half of a skyfarer's kit: materials with a production chain behind them,
## tools that gate a skill, weapons that do something specific and unpleasant, and the
## small number of objects whose entire purpose is to be funny the first time and a
## genuine tactic the second.
##
## The rule every entry here follows: if it has an effect, the effect is mechanical and
## the description tells you what it is. Nothing in this file is flavour text over a
## +2 damage bonus. A shrieking bell really does bring every creature on the island; a
## gravity sink really does stop you falling and really does stop you moving.

# ------------------------------------------------------------------ materials
## [id, name, sprite, value, weight, desc]
## The chain: ore -> ingot -> part. Fibre -> thread -> canvas. Hide -> leather -> harness.
const MATERIALS := [
	["sky_timber", "sky timber", "sky_timber", 12, 3, "wood",
		"A length of island-grown hardwood. It is under tension along the grain — cut it wrong and it kicks."],
	["ironwood_beam", "ironwood beam", "ironwood_beam", 44, 5, "ironwood",
		"Thornwild heartwood, grown so slowly it rings when you tap it. Keels are made of this and nothing else."],
	["fibre_bundle", "fibre bundle", "fibre_bundle", 6, 2, "fibre",
		"Stripped reed and vine, retted and combed. The start of every rope and every sail in this sky."],
	["skysilk_thread", "skysilk thread", "skysilk_thread", 64, 1, "skysilk",
		"Marrow-moth thread wound onto a card. Stronger than the wire it replaced and a quarter the weight."],
	["canvas_bolt", "bolt of canvas", "canvas_bolt", 38, 3, "canvas",
		"Woven, tarred and rolled. A mast takes four of these and the sailmaker will tell you it takes six."],
	["beast_hide", "beast hide", "beast_hide", 22, 3, "hide",
		"Scraped and salted. What it came off decides what it is good for, and it is always good for something."],
	["chitin_plate", "chitin plate", "chitin_plate", 34, 2, "chitin",
		"A section of insect shell, lacquered. Lighter than iron, and it does not conduct."],
	["iron_ingot", "iron ingot", "iron_ingot", 26, 4, "iron",
		"Smelted and cast into a bar somebody can actually carry. The universal currency of every forge."],
	["aether_ingot", "aetherite ingot", "aether_ingot", 110, 3, "aetherite",
		"Refined aetherite, cast in a mould that has to be held down. It weighs less than nothing, which \
is not a figure of speech and is the entire point."],
	["skyglass_lens", "skyglass lens", "skyglass_lens", 88, 1, "skyglass",
		"Ground and polished from a single crystal. It holds a charge and it will not let go of it politely."],
	["bone_meal", "bone meal", "bone_meal", 9, 2, "bonemeal",
		"Ground fine. Fertiliser, flux, and one ingredient in something you should not make."],
	["marrow_oil", "marrow oil", "marrow_oil", 38, 2, "marrowoil",
		"Rendered out of the big bones. It burns at twice the heat of distillate and smells like regret."],
	["sporecap", "sporecap", "sporecap", 11, 1, "sporecap",
		"Dried fungal cap. Half the tonics in this sky start here and about a third of the hallucinations."],
	["storm_glass", "storm glass", "storm_glass", 150, 1, "stormglass",
		"Sand fused by a lightning strike, still faintly charged. It hums when the weather is about to turn."],
	["voidsteel_ingot", "voidsteel ingot", "voidsteel_ingot", 420, 4, "voidsteel",
		"Iron quenched in the Anvil's air. It is cold to the touch, always, and it does not dull."],
]

# ------------------------------------------------------------------ tools that gate a skill
const TOOLS := {
	"axe_felling": {"name": "felling axe", "desc": "A long haft and a heavy head. For sky-timber, which fights back.",
		"sheet": "items", "spr": "axe_felling", "value": 90,
		"comps": {"item": {"w": 5, "force": 18, "throwforce": 12, "cat": "tool", "tool": "chop", "slots": ["back"]}},
		"tags": {"tool_tier": 1, "skill": "woodcutting"}},
	"axe_ironwood": {"name": "ironwood axe", "desc": "Skyglass edge in an ironwood haft. It takes hardwood the \
felling axe merely argues with.", "sheet": "items", "spr": "axe_ironwood", "value": 420,
		"comps": {"item": {"w": 5, "force": 26, "throwforce": 14, "cat": "tool", "tool": "chop", "slots": ["back"]}},
		"tags": {"tool_tier": 3, "skill": "woodcutting", "req": {"woodcutting": 35}}},
	"pick_aether": {"name": "aetherite pick", "desc": "The head is cast round an aetherite core, so it swings \
lighter than it lands. Rock comes apart in sheets.", "sheet": "items", "spr": "pick_aether", "value": 480,
		"comps": {"item": {"w": 4, "force": 22, "cat": "tool", "tool": "dig", "slots": ["back"]}},
		"tags": {"tool_tier": 3, "skill": "mining", "req": {"mining": 35}}},
	"forage_knife": {"name": "forager's knife", "desc": "A curved blade for cutting stems without bruising them. \
What you take with this is worth more than what you take with your hands.",
		"sheet": "items", "spr": "forage_knife", "value": 70,
		"comps": {"item": {"w": 1, "force": 10, "cat": "tool", "tool": "cut", "slots": ["belt", "pocket_l", "pocket_r"]}},
		"tags": {"tool_tier": 2, "skill": "foraging"}},
	"skinning_knife": {"name": "skinning knife", "desc": "Short, fat-bellied and appallingly sharp. \
It takes a hide off in one piece if you know where to start.", "sheet": "items", "spr": "skinning_knife", "value": 85,
		"comps": {"item": {"w": 1, "force": 12, "cat": "tool", "tool": "cut", "slots": ["belt"]}},
		"tags": {"tool_tier": 2, "skill": "beastlore"}},
	"sky_rod": {"name": "skyfisher's rod", "desc": "Twelve feet of springy cane, a drum reel and two hundred \
fathoms of skysilk. You trail it off the rail and wait. Things bite.",
		"sheet": "items", "spr": "sky_rod", "value": 160,
		"comps": {"item": {"w": 3, "cat": "tool", "slots": ["back"]}, "skyrod": {}},
		"tags": {"skill": "skyfishing"}},
	"salvage_saw": {"name": "salvage saw", "desc": "A toothed disc on a spring arbor. It opens a wreck's plating \
without opening whatever the wreck was carrying.", "sheet": "items", "spr": "salvage_saw", "value": 260,
		"comps": {"item": {"w": 4, "force": 14, "cat": "tool", "tool": "cut", "slots": ["back"]}},
		"tags": {"tool_tier": 2, "skill": "salvaging"}},
	"artificers_kit": {"name": "artificer's kit", "desc": "Loupes, needle files, a static comb and six things \
that have no name outside the trade. Aetherite work needs all of them.",
		"sheet": "items", "spr": "artificers_kit", "value": 340,
		"comps": {"item": {"w": 4, "cat": "tool", "tool": "multitool", "slots": ["belt", "back"]}},
		"tags": {"tool_tier": 2, "skill": "artifice"}},
	"sail_needle": {"name": "sailmaker's palm", "desc": "A leather palm with an iron boss and a needle the size \
of your little finger. Canvas does not sew itself and it certainly does not sew easily.",
		"sheet": "items", "spr": "sail_needle", "value": 55,
		"comps": {"item": {"w": 1, "cat": "tool", "slots": ["pocket_l", "pocket_r", "belt"]}},
		"tags": {"tool_tier": 1, "skill": "rigging"}},
}

# ------------------------------------------------------------------ weapons
## Every one of these does a specific thing. If two of them did the same thing one of
## them would not be here.
const WEAPONS := {
	"harpoon": {"name": "hand harpoon", "desc": "Barbed, weighted and meant to be thrown. It stays in, which \
means the thing it is in slows down, which is usually what you wanted.",
		"sheet": "items", "spr": "harpoon", "value": 110,
		"comps": {"item": {"w": 4, "force": 20, "throwforce": 34, "cat": "weapon", "slots": ["back"], "sharp": "pointy"},
			"embeds": {"chance": 75, "pain": 2.0}},
		"tags": {"skill": "throwing"}},
	"boarding_axe": {"name": "boarding axe", "desc": "Half axe, half grapnel. You can open a hull with it, \
or a person, or hook a rail when the gap turns out to be wider than it looked.",
		"sheet": "items", "spr": "boarding_axe", "value": 190,
		"comps": {"item": {"w": 4, "force": 24, "throwforce": 16, "cat": "weapon", "tool": "pry", "slots": ["belt", "back"], "sharp": "edged"}},
		"tags": {"skill": "melee"}},
	"cutlass_brine": {"name": "brinesteel cutlass", "desc": "Salt-quenched in a Saltmere forge. It keeps an \
edge in weather that eats ordinary steel, and it leaves wounds that do not want to close.",
		"sheet": "items", "spr": "cutlass_brine", "value": 460,
		"comps": {"item": {"w": 3, "force": 27, "cat": "weapon", "slots": ["belt"], "sharp": "edged"},
			"quirkweapon": {"effect": "salt"}},
		"tags": {"skill": "melee", "req": {"melee": 25}}},
	"stormblade": {"name": "stormblade", "desc": "A skyglass core in a steel spine, kept charged off the air. \
Every third blow arcs to whatever else is touching your target, which in a boarding action \
is a great many people.", "sheet": "items", "spr": "stormblade", "value": 1450,
		"comps": {"item": {"w": 3, "force": 30, "cat": "weapon", "slots": ["belt"], "sharp": "edged"},
			"quirkweapon": {"effect": "arc"}, "light": {"kind": "always", "radius": 2.4, "color": "#9ad8ff", "energy": 0.5}},
		"tags": {"skill": "melee", "req": {"melee": 45, "artifice": 25}}},
	"cinder_maul": {"name": "cinder maul", "desc": "A basalt head that holds the heat of the forge it was made \
in for about a week. It sets what it hits on fire and it is extremely tiring to use.",
		"sheet": "items", "spr": "cinder_maul", "value": 620,
		"comps": {"item": {"w": 7, "force": 34, "cat": "weapon", "slots": ["back"]},
			"quirkweapon": {"effect": "ignite"}},
		"tags": {"skill": "melee", "req": {"melee": 35}}},
	"quiet_knife": {"name": "the quiet knife", "desc": "Taken off something in a Boneyard ossuary. Sound stops \
about a foot from the blade. You do not hear it draw and neither does anyone else.",
		"sheet": "items", "spr": "quiet_knife", "value": 1100,
		"comps": {"item": {"w": 1, "force": 19, "cat": "weapon", "slots": ["pocket_l", "pocket_r", "belt"], "sharp": "edged"},
			"quirkweapon": {"effect": "silent"}},
		"tags": {"skill": "melee"}},
	"aether_pistol": {"name": "aether pistol", "desc": "A skyglass lens, a coil and a grip. It throws a bolt \
that does not care about armour and it needs about four seconds between bolts to stop caring \
about your hand.", "sheet": "items", "spr": "aether_pistol", "value": 780,
		"comps": {"item": {"w": 3, "force": 8, "cat": "weapon", "slots": ["belt", "pocket_l"]},
			"aethergun": {"damage": 26.0, "reach": 7, "reload": 3.4, "cost": 1}},
		"tags": {"skill": "marksman"}},
	"lance_carbine": {"name": "lance carbine", "desc": "The aether lance, shrunk until one person can hold it \
and no person can hold it steady. It goes through the first thing it hits.",
		"sheet": "items", "spr": "lance_carbine", "value": 2100,
		"comps": {"item": {"w": 6, "force": 12, "cat": "weapon", "slots": ["back"]},
			"aethergun": {"damage": 38.0, "reach": 12, "reload": 4.6, "cost": 2, "pierce": 2}},
		"tags": {"skill": "marksman", "req": {"marksman": 35}}},
	"scattergun": {"name": "deck scattergun", "desc": "A short barrel and a handful of whatever was on the bench. \
At arm's length it is decisive. At ten feet it is a loud apology.",
		"sheet": "items", "spr": "scattergun", "value": 540,
		"comps": {"item": {"w": 5, "force": 14, "cat": "weapon", "slots": ["back"]},
			"aethergun": {"damage": 11.0, "reach": 4, "reload": 3.0, "cost": 1, "pellets": 6}},
		"tags": {"skill": "marksman"}},
}

# ------------------------------------------------------------------ the interesting drawer
## The things a player tells someone else about.
const CURIOS := {
	"shrieking_bell": {"name": "shrieking bell", "desc": "Cast from a mere singer's throat-bone. Ring it and \
every creature within two hundred feet comes to look at what happened, all at once, from every \
direction. There is a use for this. Work out what it is before you ring it.",
		"sheet": "items", "spr": "shrieking_bell", "value": 380,
		"comps": {"item": {"w": 2, "cat": "misc", "slots": ["belt"]}, "curio": {"effect": "shriek"}}},
	"gravity_sink": {"name": "gravity sink", "desc": "A sealed jar of something the Deep made. While you hold \
it you cannot fall. You also cannot move faster than a walk, and it is extremely heavy, and it \
is not obvious which of those facts will kill you.",
		"sheet": "items", "spr": "gravity_sink", "value": 1400,
		"comps": {"item": {"w": 9, "cat": "misc", "slots": ["back"]}, "curio": {"effect": "sink"}}},
	"liars_compass": {"name": "liar's compass", "desc": "It points at the nearest island, confidently, and it \
is wrong about one time in five. Skyfarers keep them because the wrong answer is usually \
somewhere nobody has been.", "sheet": "items", "spr": "liars_compass", "value": 220,
		"comps": {"item": {"w": 1, "cat": "tool", "slots": ["belt", "pocket_l"]}, "skycompass": {"liar": true}}},
	"boiling_flask": {"name": "self-boiling flask", "desc": "Whatever goes in comes out hot. It has never been \
explained and every galley in the Shelf has one. Cooks a raw thing in about ten seconds and \
takes the skin off your palm if you hold the wrong end.",
		"sheet": "items", "spr": "boiling_flask", "value": 260,
		"comps": {"item": {"w": 2, "cat": "tool", "slots": ["belt"]}, "curio": {"effect": "boil"}}},
	"pocket_updraft": {"name": "pocket updraft", "desc": "A pressure flask with a release ring. Pull it and the \
air under you goes solid for a second and a half. You will go up about forty feet. You will then \
come down about forty feet, so have a plan.",
		"sheet": "items", "spr": "pocket_updraft", "value": 340,
		"comps": {"item": {"w": 2, "cat": "tool", "slots": ["belt", "pocket_l"]}, "curio": {"effect": "updraft", "uses": 3}}},
	"echo_shell": {"name": "echo shell", "desc": "Hold it to your ear and you hear this place forty seconds \
from now. Mostly it is wind. Occasionally it is something arriving.",
		"sheet": "items", "spr": "echo_shell", "value": 700,
		"comps": {"item": {"w": 1, "cat": "misc", "slots": ["pocket_l", "pocket_r"]}, "curio": {"effect": "echo"}}},
	"anchor_charm": {"name": "anchor charm", "desc": "A knot of skysilk somebody tied wrong on purpose. The \
wind will not touch you while you wear it. Neither will a gale you actually needed.",
		"sheet": "items", "spr": "anchor_charm", "value": 480,
		"comps": {"item": {"w": 1, "cat": "clothing", "slots": ["neck"]},
			"clothing": {"slot": "neck", "sprite": "neck_charm", "colors": ["#c8b088", "#7a6a58"]},
			"curio": {"effect": "anchor"}}},
	"ledger_of_owed": {"name": "ledger of what is owed", "desc": "Somebody's accounts, in a hand that gets \
worse toward the end. Every port in this sky is in it, and about half the entries have not \
been settled. Shows you what each port wants before you get there.",
		"sheet": "items", "spr": "ledger", "value": 560,
		"comps": {"item": {"w": 2, "cat": "misc", "slots": ["belt"]}, "curio": {"effect": "ledger"}}},
	"tin_of_stars": {"name": "tin of stars", "desc": "Forty-odd flakes of something that will not stop glowing. \
Throw a pinch and the tile lights for a minute. Throw the tin and you will regret it, briefly, \
in excellent light.", "sheet": "items", "spr": "tin_of_stars", "value": 190,
		"comps": {"item": {"w": 1, "cat": "tool", "slots": ["pocket_l", "pocket_r"]},
			"curio": {"effect": "stars", "uses": 12}}},
	"thinking_cap": {"name": "the thinking cap", "desc": "A knitted cap with a skyglass bead sewn into the band. \
You learn faster wearing it. You also say what you are thinking, out loud, which has ended more \
partnerships than piracy.", "sheet": "items", "spr": "thinking_cap", "value": 900,
		"comps": {"item": {"w": 1, "cat": "clothing", "slots": ["head"]},
			"clothing": {"slot": "head", "sprite": "head_thinking", "colors": ["#7a6a9a", "#9ad8ff"]},
			"curio": {"effect": "thinking"}}},
	"drowned_mans_lung": {"name": "drowned man's lung", "desc": "A bladder organ taken off something in the \
Fenmoor, still working. Breathe through it and you can go anywhere the air is bad. It has to \
be kept wet and it dislikes being forgotten about.",
		"sheet": "items", "spr": "drowned_lung", "value": 820,
		"comps": {"item": {"w": 3, "cat": "clothing", "slots": ["mask"]},
			"clothing": {"slot": "mask", "sprite": "mask_lung", "pressure": true, "colors": ["#5a7878", "#a8c0c0"]},
			"curio": {"effect": "lung"}}},
	"cartographers_eye": {"name": "cartographer's eye", "desc": "A brass monocle with a skyglass lens. Islands \
you look at get written onto your chart, permanently, including the ones you were only \
looking at by accident.", "sheet": "items", "spr": "cart_eye", "value": 1200,
		"comps": {"item": {"w": 1, "cat": "clothing", "slots": ["eyes"]},
			"clothing": {"slot": "eyes", "sprite": "eyes_monocle", "colors": ["#c8a85a", "#9ad8ff"]},
			"curio": {"effect": "chart"}}},
}

# ------------------------------------------------------------------ consumables
const CONSUMABLES := {
	"tonic_lift": {"name": "lifter's tonic", "desc": "Sporecap and marrow oil. You will carry twice what you \
should for four minutes and you will feel it tomorrow.", "sheet": "items", "spr": "tonic_lift", "value": 85,
		"comps": {"item": {"w": 1, "cat": "food", "slots": ["pocket_l", "pocket_r"]},
			"tonic": {"effect": "strength", "dur": 240.0}}},
	"tonic_wind": {"name": "windwalker's tonic", "desc": "You move quicker and the ground feels further away. \
Do not drink it near an edge.", "sheet": "items", "spr": "tonic_wind", "value": 95,
		"comps": {"item": {"w": 1, "cat": "food", "slots": ["pocket_l", "pocket_r"]},
			"tonic": {"effect": "speed", "dur": 180.0}}},
	"tonic_clarity": {"name": "clarity draught", "desc": "Everything gets a little louder and a lot clearer. \
You learn faster for a while and you will have a headache about it.",
		"sheet": "items", "spr": "tonic_clarity", "value": 140,
		"comps": {"item": {"w": 1, "cat": "food", "slots": ["pocket_l", "pocket_r"]},
			"tonic": {"effect": "learning", "dur": 600.0}}},
	"tonic_ironhide": {"name": "ironhide draught", "desc": "Your skin goes grey and stops caring. It also stops \
feeling, which matters when you are on fire and have not noticed.",
		"sheet": "items", "spr": "tonic_ironhide", "value": 160,
		"comps": {"item": {"w": 1, "cat": "food", "slots": ["pocket_l", "pocket_r"]},
			"tonic": {"effect": "armor", "dur": 200.0}}},
	"tonic_breath": {"name": "thin-air draught", "desc": "Your blood carries more than it should. Four minutes \
of the Heights without a mask, and then four minutes of wishing you had one.",
		"sheet": "items", "spr": "tonic_breath", "value": 180,
		"comps": {"item": {"w": 1, "cat": "food", "slots": ["pocket_l", "pocket_r"]},
			"tonic": {"effect": "altitude", "dur": 240.0}}},
	"rations_sky": {"name": "skyfarer's rations", "desc": "Hard bread, salt meat and a square of pressed fruit. \
Nobody has ever enjoyed one and nobody has ever sailed without them.",
		"sheet": "items", "spr": "rations_sky", "value": 22,
		"comps": {"item": {"w": 2, "cat": "food"}, "food": {"nutrition": 340, "taste": "salt and duty"}}},
}

# ------------------------------------------------------------------ install
static func install() -> void:
	var P: Dictionary = Proto.P
	for row in MATERIALS:
		# [id, name, sprite, value, weight, stack material, description]
		P[row[0]] = {
			"name": row[1], "desc": String(row[6]), "sheet": "items", "spr": row[2],
			"comps": {"item": {"w": int(row[4]), "force": 5, "throwforce": 6, "cat": "material"},
				"stack": {"amount": 1, "material": String(row[5])}},
			"tags": {"value": int(row[3])},
		}
	for src in [TOOLS, WEAPONS, CURIOS, CONSUMABLES]:
		for id in src:
			var d: Dictionary = (src[id] as Dictionary).duplicate(true)
			if d.has("value"):
				var tags: Dictionary = d.get("tags", {})
				tags["value"] = d["value"]
				d["tags"] = tags
				d.erase("value")
			P[id] = d
