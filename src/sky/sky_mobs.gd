class_name SkyMobs extends RefCounted
## The bestiary.
##
## Every creature is an archetype plus a palette plus a stat line. The archetypes are
## seven animated bodies on the mobs sheet (quadruped, scurrier, insect, flyer, drifter,
## biped, serpent); the palette recolours one through the paper-doll shader. That is why
## there are forty creatures here and only seven sprites to draw: a frost wolf and a mire
## hound are the same animation in different coats, which is also true of actual wolves.
##
## Behaviours are deliberately few and legible, because a player has to be able to learn
## them and then use them:
##   grazer     flees, never attacks, drops food
##   hunter     stalks and closes
##   ambush     holds still until you are adjacent, then hits hard
##   pack       hunts, but only commits when others are near
##   territory  ignores you until you come inside its radius
##   drifter    wanders through walls, cannot be blocked, cannot be reasoned with
##   swarm      weak, numerous, and always in threes
##
## On top of the behaviour, an `ab` list of powers out of BeastPowers. The behaviour is
## how it moves; the powers are why you remember it. A thing with `drain` is a threat to
## your ship rather than to you; a thing with `steal` is a threat to your afternoon.

const A_QUAD := "quad"
const A_SMALL := "small"
const A_INSECT := "insect"
const A_FLYER := "flyer"
const A_DRIFT := "drift"
const A_BIPED := "biped"
const A_WORM := "worm"

## id: {name, arch, pal[4], hp, dmg, speed, behaviour, size, flags, loot, desc}
##   speed   seconds per step (lower is faster; a person walks at about 0.30)
##   flags   f flying (can cross open sky)  n night only  l gives light
##           a ambusher (starts hidden)     p pack        s swarm (spawns in threes)
##           x anomalous (Foundation-flavoured: ignores ordinary rules)
static var BEASTS := {
	# ---------------------------------------------------------------- Verdance
	"skyhare": {"name": "skyhare", "arch": A_SMALL, "pal": ["#b8a078", "#8a7458", "#e8dcc0", "#5a4c3a"],
		"hp": 18, "dmg": 0, "speed": 0.20, "beh": "grazer", "size": 0.8, "flags": "", "loot": ["meat_raw"],
		"desc": "Long-eared and absurdly fast. It eats the flowers that only grow where the aether is thick, which is how you find them."},
	"aether_doe": {"name": "aether doe", "arch": A_QUAD, "pal": ["#c8b490", "#9a8468", "#e8e0d0", "#6a5c48"],
		"hp": 45, "dmg": 4, "speed": 0.30, "beh": "grazer", "size": 1.1, "flags": "", "loot": ["meat_raw", "meat_raw"],
		"desc": "It stands very still and looks at you for a long moment before it goes. Its antlers are faintly luminous."},
	"glidewing": {"name": "glidewing", "arch": A_FLYER, "pal": ["#88b8d8", "#5a8ab0", "#d8eef8", "#3a4a5a"],
		"hp": 22, "dmg": 3, "speed": 0.22, "beh": "grazer", "size": 0.9, "flags": "f", "loot": ["meat_raw"],
		"desc": "It never lands. Skyfarers say a flock of them means an island within the hour, and skyfarers are usually right."},
	"meadow_crawler": {"name": "meadow crawler", "arch": A_INSECT, "pal": ["#6a8a4a", "#4a6a34", "#a8c878", "#2a3a1a"],
		"hp": 26, "dmg": 6, "speed": 0.34, "beh": "territory", "size": 0.9, "flags": "", "loot": [],
		"ab": ["burrow"],
		"desc": "Harmless unless you stand on its burrow, which is unmarked, and everywhere."},
	"dusk_moth": {"name": "dusk moth", "arch": A_FLYER, "pal": ["#a888c8", "#7a5a9a", "#e0d0f0", "#3a2a4a"],
		"hp": 16, "dmg": 2, "speed": 0.24, "beh": "grazer", "size": 0.8, "flags": "fnl", "loot": [],
		"desc": "It carries its own light and has no idea why that is dangerous."},
	"hollow_stag": {"name": "hollow stag", "arch": A_QUAD, "pal": ["#4a4438", "#2a2620", "#c8c0a8", "#8a8068"],
		"hp": 130, "dmg": 22, "speed": 0.28, "beh": "territory", "size": 1.3, "flags": "nx", "loot": ["ore_aetherite"],
		"ab": ["gaze", "phase"],
		"desc": "Everything about it is correct except that you can see the far side of the meadow through its ribs. It will not charge while you are looking at it."},
	# ---------------------------------------------------------------- Hearthmoss
	"moss_shrike": {"name": "moss shrike", "arch": A_FLYER, "pal": ["#7a9a5a", "#546c38", "#b8d890", "#26341a"],
		"hp": 30, "dmg": 8, "speed": 0.20, "beh": "territory", "size": 0.9, "flags": "f", "loot": ["meat_raw"],
		"ab": ["leap"],
		"desc": "It keeps a larder. Everything it has caught this week is spiked on the thorns of one bush, \
in order, and it will object to your looking at it."},
	"hearth_beetle": {"name": "hearth beetle", "arch": A_INSECT, "pal": ["#8a6a4a", "#5a4630", "#c0a078", "#2a2014"],
		"hp": 24, "dmg": 4, "speed": 0.30, "beh": "grazer", "size": 0.8, "flags": "", "loot": ["chitin_plate"],
		"ab": [],
		"desc": "It eats rot and it is warm to the touch. Islanders keep them in the house in winter, \
which is where the biome gets its name."},
	"lamp_vole": {"name": "lamp vole", "arch": A_SMALL, "pal": ["#b8a878", "#8a7a54", "#e8dcae", "#4a4028"],
		"hp": 14, "dmg": 2, "speed": 0.18, "beh": "grazer", "size": 0.7, "flags": "nl", "loot": ["meat_raw"],
		"ab": ["steal"],
		"desc": "It glows faintly and it will take anything small and shiny straight out of your hand. \
Everyone finds this funny once."},
	# ---------------------------------------------------------------- Chalkdowns
	"downs_ram": {"name": "downs ram", "arch": A_QUAD, "pal": ["#d0c8b0", "#a09880", "#f0ead8", "#585040"],
		"hp": 90, "dmg": 16, "speed": 0.30, "beh": "territory", "size": 1.2, "flags": "", "loot": ["meat_raw", "beast_hide"],
		"ab": ["charge"],
		"desc": "Four hundred pounds of opinion. It will give you one warning, which is a single \
hoof scraped backward through the chalk."},
	"chalk_hopper": {"name": "chalk hopper", "arch": A_SMALL, "pal": ["#e0dcc8", "#b0aa94", "#f8f4e8", "#686250"],
		"hp": 18, "dmg": 5, "speed": 0.18, "beh": "swarm", "size": 0.7, "flags": "s", "loot": [],
		"ab": ["leap"],
		"desc": "It goes up about nine feet and it does so without warning and usually at your face."},
	"chalk_wight": {"name": "chalk wight", "arch": A_BIPED, "pal": ["#f0ece0", "#c0bcb0", "#ffffff", "#8a8678"],
		"hp": 105, "dmg": 20, "speed": 0.34, "beh": "hunter", "size": 1.1, "flags": "nx", "loot": [],
		"ab": ["phase", "gaze"],
		"desc": "The chalk figures cut into these hillsides are not decorative. One of them is \
missing from every downs isle and they have never found where it went."},
	# ---------------------------------------------------------------- Tanglereef
	"reef_drifter": {"name": "reef drifter", "arch": A_DRIFT, "pal": ["#6ac8b8", "#3a9088", "#a8f0e0", "#1a4a44"],
		"hp": 44, "dmg": 10, "speed": 0.36, "beh": "drifter", "size": 1.0, "flags": "l", "loot": [],
		"ab": ["web"],
		"desc": "A curtain of filament that drifts where the aether takes it, which is unfortunately \
also where you are."},
	"polyp_swarm": {"name": "polyp swarm", "arch": A_INSECT, "pal": ["#c86a8a", "#94405e", "#f0a8c0", "#48182c"],
		"hp": 22, "dmg": 7, "speed": 0.26, "beh": "swarm", "size": 0.7, "flags": "s", "loot": [],
		"ab": ["split"],
		"desc": "Each one is a fragment of something larger that has decided division is easier \
than agreement."},
	"tanglemaw": {"name": "tanglemaw", "arch": A_WORM, "pal": ["#4a7a6a", "#2a5248", "#88c0ac", "#142a24"],
		"hp": 88, "dmg": 20, "speed": 0.34, "beh": "ambush", "size": 1.2, "flags": "a", "loot": ["chitin_plate"],
		"ab": ["tether", "web"],
		"desc": "It does not chase. It throws a line, and then it does not need to chase."},
	"lantern_medusa": {"name": "lantern medusa", "arch": A_DRIFT, "pal": ["#a8d8f0", "#6aa0c8", "#e0f8ff", "#345468"],
		"hp": 56, "dmg": 13, "speed": 0.38, "beh": "drifter", "size": 1.1, "flags": "nlx", "loot": ["skyglass_lens"],
		"ab": ["static", "drain"],
		"desc": "Beautiful, slow, and it will empty every cell on your ship if you let it come alongside."},
	# ---------------------------------------------------------------- Rustfall
	"rust_crawler": {"name": "rust crawler", "arch": A_INSECT, "pal": ["#9a6a48", "#6a4630", "#c89870", "#3a2418"],
		"hp": 34, "dmg": 9, "speed": 0.28, "beh": "swarm", "size": 0.8, "flags": "s", "loot": ["salvage_scrap"],
		"ab": ["magnetize"],
		"desc": "It eats iron and it is not fussy about whether the iron is currently in use."},
	"scrap_hound": {"name": "scrap hound", "arch": A_QUAD, "pal": ["#7a6a5a", "#4a3e34", "#a89684", "#241c16"],
		"hp": 78, "dmg": 17, "speed": 0.24, "beh": "pack", "size": 1.1, "flags": "p", "loot": ["salvage_scrap"],
		"ab": ["steal", "summon"],
		"desc": "Half of it is plating somebody else lost. They work the edges of a group and one \
of them is always behind you."},
	"magnet_tick": {"name": "magnet tick", "arch": A_SMALL, "pal": ["#585a64", "#383a44", "#8a8c98", "#1a1c22"],
		"hp": 20, "dmg": 5, "speed": 0.24, "beh": "swarm", "size": 0.7, "flags": "s", "loot": [],
		"ab": ["magnetize"],
		"desc": "It hums. Your tools lean toward it. In numbers you will be disarmed before you \
have noticed they are there."},
	"ironjaw": {"name": "ironjaw", "arch": A_BIPED, "pal": ["#6a5a4a", "#403428", "#a08a70", "#1c1610"],
		"hp": 240, "dmg": 32, "speed": 0.46, "beh": "territory", "size": 1.4, "flags": "", "loot": ["iron_ingot", "salvage_scrap"],
		"ab": ["charge", "magnetize", "hoard"],
		"desc": "It has been taking pieces off wrecks for a very long time and it has been fitting \
them to itself."},
	"hollow_crewman": {"name": "hollow crewman", "arch": A_BIPED, "pal": ["#5a5a54", "#383832", "#908c80", "#1c1c18"],
		"hp": 110, "dmg": 21, "speed": 0.34, "beh": "hunter", "size": 1.1, "flags": "nx", "loot": ["salvage_scrap"],
		"ab": ["mimic", "summon"],
		"desc": "It is still wearing the coat, still at its station, still doing the job. It will \
ask you for a hand with something."},
	# ---------------------------------------------------------------- Mirrormere
	"mirror_walker": {"name": "mirror walker", "arch": A_BIPED, "pal": ["#d0e0ec", "#a0b0bc", "#ffffff", "#5a6a76"],
		"hp": 120, "dmg": 24, "speed": 0.32, "beh": "hunter", "size": 1.1, "flags": "x", "loot": ["skyglass_lens"],
		"ab": ["echo", "phase"],
		"desc": "It walks the way you do. It has been watching."},
	"reflection": {"name": "a reflection", "arch": A_DRIFT, "pal": ["#e8f0f8", "#b8c8d8", "#ffffff", "#6a7a8a"],
		"hp": 70, "dmg": 18, "speed": 0.30, "beh": "drifter", "size": 1.0, "flags": "nlx", "loot": [],
		"ab": ["echo", "gaze"],
		"desc": "There is nothing casting it. It is doing what you did, about a second late, and \
it is getting closer to on time."},
	# ---------------------------------------------------------------- Emberglass
	"emberling": {"name": "emberling", "arch": A_SMALL, "pal": ["#e8783a", "#a84820", "#ffc070", "#4a1c08"],
		"hp": 24, "dmg": 8, "speed": 0.22, "beh": "swarm", "size": 0.7, "flags": "sl", "loot": [],
		"ab": ["ignite", "split"],
		"desc": "Each one is a coal that decided to keep going. Do not step on them and do not \
kill them indoors."},
	"glass_salamander": {"name": "glass salamander", "arch": A_QUAD, "pal": ["#c8a878", "#8a6a48", "#f0d8a8", "#3a2c18"],
		"hp": 84, "dmg": 19, "speed": 0.28, "beh": "territory", "size": 1.1, "flags": "l", "loot": ["storm_glass"],
		"ab": ["ignite", "burrow"],
		"desc": "It runs through the melt and comes out the other side glazed. What it leaves \
behind is worth collecting once it has cooled."},
	"slagborn": {"name": "slagborn", "arch": A_BIPED, "pal": ["#8a4a2a", "#582a14", "#d08050", "#2a1208"],
		"hp": 200, "dmg": 30, "speed": 0.42, "beh": "hunter", "size": 1.3, "flags": "lx", "loot": ["iron_ingot", "storm_glass"],
		"ab": ["ignite", "charge", "regrow"],
		"desc": "Somebody's furnace was left running too long with something in it. It closes its \
own wounds by melting them shut."},
	# ---------------------------------------------------------------- Stormcrown
	"arc_mite": {"name": "arc mite", "arch": A_SMALL, "pal": ["#a8c8f0", "#6a90c0", "#e0f0ff", "#2a4460"],
		"hp": 18, "dmg": 6, "speed": 0.20, "beh": "swarm", "size": 0.7, "flags": "sl", "loot": [],
		"ab": ["static"],
		"desc": "It holds a charge it has no business holding, and it discharges it into whatever \
is nearest, which is generally the rest of the swarm and then you."},
	"charge_hound": {"name": "charge hound", "arch": A_QUAD, "pal": ["#6a7aa8", "#404a70", "#a8b8e0", "#1c2238"],
		"hp": 96, "dmg": 20, "speed": 0.22, "beh": "pack", "size": 1.1, "flags": "pl", "loot": ["storm_glass"],
		"ab": ["static", "charge"],
		"desc": "They run the storm the way a shark runs a current, and they arrive with it."},
	"stormcaller": {"name": "stormcaller", "arch": A_BIPED, "pal": ["#4a5a8a", "#2a3458", "#8a9ad0", "#121828"],
		"hp": 190, "dmg": 27, "speed": 0.38, "beh": "hunter", "size": 1.3, "flags": "lx", "loot": ["storm_glass", "aether_ingot"],
		"ab": ["static", "summon", "shriek"],
		"desc": "The weather does what it says. Nobody has established whether it is causing the \
storm or simply extremely well informed about it."},
	"thunderhead_ray": {"name": "thunderhead ray", "arch": A_FLYER, "pal": ["#8a9ac8", "#54648a", "#c8d8f8", "#242c44"],
		"hp": 130, "dmg": 24, "speed": 0.18, "beh": "hunter", "size": 1.4, "flags": "flx", "loot": ["storm_glass", "skysilk_thread"],
		"ab": ["drain", "static"],
		"desc": "Thirty feet across and it weighs nothing at all. It comes down out of the cloud \
onto your masthead and it drinks."},
	# ---------------------------------------------------------------- Vergegloom
	"gloomstalker": {"name": "gloomstalker", "arch": A_QUAD, "pal": ["#2a2a34", "#16161e", "#5a5a6a", "#0a0a0e"],
		"hp": 150, "dmg": 27, "speed": 0.22, "beh": "ambush", "size": 1.2, "flags": "ax", "loot": ["beast_hide"],
		"ab": ["echo", "charge", "feign"],
		"desc": "It hunts by where you were rather than where you are, and it is very good at \
the arithmetic."},
	"pale_swarm": {"name": "pale swarm", "arch": A_INSECT, "pal": ["#c8c0b8", "#948c84", "#f0e8e0", "#4a4440"],
		"hp": 26, "dmg": 8, "speed": 0.24, "beh": "swarm", "size": 0.7, "flags": "sx", "loot": [],
		"ab": ["split", "drain"],
		"desc": "Colourless, soundless, and it divides when you hit it. Fire is the answer and \
there is no other answer."},
	"sightless": {"name": "the sightless", "arch": A_BIPED, "pal": ["#3a3440", "#1e1a24", "#6a6478", "#0e0c12"],
		"hp": 170, "dmg": 28, "speed": 0.30, "beh": "hunter", "size": 1.2, "flags": "nx", "loot": ["aether_ingot"],
		"ab": ["shriek", "gaze", "phase"],
		"desc": "It has no eyes and it is looking directly at you. Whatever it is using instead \
is not affected by darkness, distance, or a closed hatch."},
	# ---------------------------------------------------------------- Thornwild
	"thorn_mantis": {"name": "thorn mantis", "arch": A_INSECT, "pal": ["#5a7a3a", "#3a5a24", "#98b868", "#1a2a10"],
		"hp": 48, "dmg": 16, "speed": 0.26, "beh": "ambush", "size": 1.0, "flags": "a", "loot": [],
		"ab": ["leap"],
		"desc": "It is exactly the colour of the thorns it waits in, and it waits very well."},
	"canopy_stalker": {"name": "canopy stalker", "arch": A_QUAD, "pal": ["#3a4a2a", "#243018", "#7a8a5a", "#141a0c"],
		"hp": 70, "dmg": 18, "speed": 0.24, "beh": "pack", "size": 1.1, "flags": "p", "loot": ["meat_raw"],
		"ab": ["leap", "summon"],
		"desc": "They drop one at a time so you count them wrong."},
	"spore_hopper": {"name": "spore hopper", "arch": A_SMALL, "pal": ["#8a7a9a", "#6a5478", "#c8b8d8", "#3a2a48"],
		"hp": 20, "dmg": 5, "speed": 0.22, "beh": "swarm", "size": 0.8, "flags": "s", "loot": [],
		"ab": ["split"],
		"desc": "It bursts when it dies. Everything nearby breathes what was inside it."},
	"vine_lasher": {"name": "vine lasher", "arch": A_WORM, "pal": ["#4a6a3a", "#2a4a20", "#88a868", "#182a10"],
		"hp": 60, "dmg": 14, "speed": 0.44, "beh": "ambush", "size": 1.1, "flags": "a", "loot": [],
		"ab": ["tether", "web"],
		"desc": "It is rooted, which means it cannot follow you, which means it has to be certain."},
	"night_bloom": {"name": "night bloom", "arch": A_DRIFT, "pal": ["#c878a8", "#8a4a78", "#f0c0e0", "#4a2038"],
		"hp": 34, "dmg": 9, "speed": 0.38, "beh": "drifter", "size": 1.0, "flags": "nl", "loot": [],
		"ab": ["web"],
		"desc": "A flower that opens at dusk and closes around whatever came to look at it."},
	"throat_singer": {"name": "throat singer", "arch": A_BIPED, "pal": ["#2a3a2a", "#182418", "#8a9a7a", "#0a100a"],
		"hp": 95, "dmg": 20, "speed": 0.30, "beh": "hunter", "size": 1.2, "flags": "nx", "loot": [],
		"ab": ["mimic", "shriek"],
		"desc": "It reproduces the last thing it heard, perfectly, including whose voice said it."},
	# ---------------------------------------------------------------- Fenmoor / Bloomrot
	"bog_lurker": {"name": "bog lurker", "arch": A_WORM, "pal": ["#4a4a38", "#2a2a1c", "#7a7a5a", "#141408"],
		"hp": 66, "dmg": 15, "speed": 0.36, "beh": "ambush", "size": 1.1, "flags": "a", "loot": [],
		"ab": ["tether"],
		"desc": "The water is opaque for a reason and the reason is patient."},
	"fen_leech": {"name": "fen leech", "arch": A_SMALL, "pal": ["#6a3a4a", "#48222e", "#a86878", "#240f18"],
		"hp": 14, "dmg": 4, "speed": 0.24, "beh": "swarm", "size": 0.7, "flags": "s", "loot": [],
		"ab": ["drain"],
		"desc": "Individually trivial. They are aware of this."},
	"mire_hound": {"name": "mire hound", "arch": A_QUAD, "pal": ["#4a4038", "#2a2420", "#8a7a68", "#141010"],
		"hp": 72, "dmg": 17, "speed": 0.26, "beh": "pack", "size": 1.0, "flags": "p", "loot": ["meat_raw"],
		"ab": ["summon"],
		"desc": "Bred for this, a long time ago, by somebody who then left."},
	"drowned_thing": {"name": "drowned thing", "arch": A_BIPED, "pal": ["#3a4a4a", "#1e2a2a", "#7a9090", "#101818"],
		"hp": 88, "dmg": 19, "speed": 0.36, "beh": "hunter", "size": 1.1, "flags": "nx", "loot": ["salvage_scrap"],
		"ab": ["steal", "mimic"],
		"desc": "It is wearing a skyfarer's coat and it has been wearing it for a very long time."},
	"will_o_wisp": {"name": "will-o'-wisp", "arch": A_DRIFT, "pal": ["#88e8c8", "#4aa888", "#d8fff0", "#206048"],
		"hp": 24, "dmg": 11, "speed": 0.20, "beh": "drifter", "size": 0.7, "flags": "nlx", "loot": [],
		"ab": ["echo", "phase"],
		"desc": "It goes where you were about to go, and waits there, helpfully."},
	"myconid": {"name": "myconid", "arch": A_BIPED, "pal": ["#8a6a8a", "#5a4060", "#c8a8c8", "#2a1a30"],
		"hp": 58, "dmg": 12, "speed": 0.34, "beh": "territory", "size": 1.0, "flags": "", "loot": [],
		"ab": ["spit"],
		"desc": "It walks the way something does when walking is not what it was built for."},
	"rot_crawler": {"name": "rot crawler", "arch": A_INSECT, "pal": ["#7a6a4a", "#544830", "#a89878", "#2a2418"],
		"hp": 32, "dmg": 8, "speed": 0.28, "beh": "swarm", "size": 0.8, "flags": "s", "loot": [],
		"ab": ["split"],
		"desc": "It eats what the bloom has already finished with."},
	"bloom_host": {"name": "bloom host", "arch": A_BIPED, "pal": ["#a85a7a", "#703a54", "#e8a8c0", "#3a1828"],
		"hp": 104, "dmg": 18, "speed": 0.32, "beh": "hunter", "size": 1.1, "flags": "nx", "loot": [],
		"ab": ["spit", "summon"],
		"desc": "Somebody's shape with somebody else's posture. The cap has grown through the collar of the coat."},
	"spore_cloud": {"name": "spore cloud", "arch": A_DRIFT, "pal": ["#9a8aa8", "#6a5a78", "#d0c0e0", "#3a2a48"],
		"hp": 40, "dmg": 6, "speed": 0.42, "beh": "drifter", "size": 1.2, "flags": "nx", "loot": [],
		"ab": ["split", "spit"],
		"desc": "Not one creature. Enough of them that the distinction stops mattering."},
	# ---------------------------------------------------------------- Cinderpeak / Ashveil
	"cinder_salamander": {"name": "cinder salamander", "arch": A_QUAD, "pal": ["#c85a2a", "#8a3418", "#f8a860", "#3a1408"],
		"hp": 62, "dmg": 16, "speed": 0.30, "beh": "territory", "size": 1.0, "flags": "l", "loot": [],
		"ab": ["ignite", "burrow"],
		"desc": "It runs hot enough to light what it walks past, and it knows it."},
	"ash_wraith": {"name": "ash wraith", "arch": A_DRIFT, "pal": ["#6a6058", "#443c38", "#a89888", "#201c18"],
		"hp": 46, "dmg": 13, "speed": 0.34, "beh": "drifter", "size": 1.1, "flags": "nx", "loot": [],
		"ab": ["phase", "chill"],
		"desc": "Ash in the shape of the last thing that stood here long enough to leave one."},
	"magma_tick": {"name": "magma tick", "arch": A_SMALL, "pal": ["#8a3a2a", "#5a2018", "#e87848", "#28100a"],
		"hp": 18, "dmg": 7, "speed": 0.22, "beh": "swarm", "size": 0.7, "flags": "s", "loot": [],
		"ab": ["ignite"],
		"desc": "It nests in the crust and objects to being stood on."},
	"forge_golem": {"name": "forge golem", "arch": A_BIPED, "pal": ["#6a5a4a", "#3a3028", "#c89858", "#1a1410"],
		"hp": 220, "dmg": 30, "speed": 0.46, "beh": "territory", "size": 1.4, "flags": "", "loot": ["ore_iron", "salvage_scrap"],
		"ab": ["charge", "regrow", "hoard"],
		"desc": "Still doing the job. The forge it worked in has been cold for a century and it has not been told."},
	"dust_swimmer": {"name": "dust swimmer", "arch": A_WORM, "pal": ["#8a8078", "#5a5048", "#c0b8a8", "#2a2420"],
		"hp": 54, "dmg": 14, "speed": 0.28, "beh": "ambush", "size": 1.1, "flags": "a", "loot": [],
		"ab": ["burrow", "tether"],
		"desc": "The ash here is deep enough to move through, and something does."},
	# ---------------------------------------------------------------- Dunebank / Saltmere / Glasswaste
	"sand_diver": {"name": "sand diver", "arch": A_WORM, "pal": ["#c8b088", "#9a8058", "#e8d8b0", "#4a3c28"],
		"hp": 58, "dmg": 15, "speed": 0.26, "beh": "ambush", "size": 1.1, "flags": "a", "loot": [],
		"ab": ["burrow", "charge"],
		"desc": "You will see the wake before you see the animal, and not by much."},
	"glass_beetle": {"name": "glass beetle", "arch": A_INSECT, "pal": ["#a8c8d8", "#7898a8", "#e0f0f8", "#384850"],
		"hp": 34, "dmg": 9, "speed": 0.30, "beh": "grazer", "size": 0.9, "flags": "", "loot": ["ore_skyglass"],
		"desc": "Its shell is worth taking. Getting it off is the difficult part."},
	"dune_stalker": {"name": "dune stalker", "arch": A_QUAD, "pal": ["#a89068", "#786448", "#d8c8a0", "#3a3020"],
		"hp": 76, "dmg": 18, "speed": 0.24, "beh": "pack", "size": 1.1, "flags": "np", "loot": ["meat_raw"],
		"ab": ["burrow", "summon"],
		"desc": "It hunts at night because the sand is quiet then and it can hear you walking."},
	"mirage_walker": {"name": "mirage walker", "arch": A_BIPED, "pal": ["#d8c8a8", "#a89878", "#f8f0e0", "#584838"],
		"hp": 80, "dmg": 20, "speed": 0.32, "beh": "hunter", "size": 1.1, "flags": "x", "loot": [],
		"ab": ["echo", "phase", "gaze"],
		"desc": "It is always at the distance where you cannot quite make it out. It is not actually far away."},
	"brine_walker": {"name": "brine walker", "arch": A_BIPED, "pal": ["#88a8a8", "#5a7878", "#c0e0e0", "#2a4040"],
		"hp": 70, "dmg": 15, "speed": 0.34, "beh": "territory", "size": 1.1, "flags": "", "loot": [],
		"ab": ["chill"],
		"desc": "Salt has grown through it until the salt is most of it."},
	"salt_crab": {"name": "salt crab", "arch": A_SMALL, "pal": ["#c8a898", "#987868", "#e8d0c0", "#483830"],
		"hp": 26, "dmg": 8, "speed": 0.30, "beh": "swarm", "size": 0.8, "flags": "s", "loot": ["meat_raw"],
		"ab": ["feign"],
		"desc": "Good eating, if you can catch one, which you cannot."},
	"mere_singer": {"name": "mere singer", "arch": A_DRIFT, "pal": ["#a8c8e8", "#7898b8", "#e0f0ff", "#3a5068"],
		"hp": 52, "dmg": 12, "speed": 0.36, "beh": "drifter", "size": 1.0, "flags": "nlx", "loot": [],
		"ab": ["mimic", "gaze"],
		"desc": "The note it holds is the exact note of your own ship's rigging, which is how it gets close."},
	"pale_swimmer": {"name": "pale swimmer", "arch": A_WORM, "pal": ["#d8d8d0", "#a8a8a0", "#f0f0e8", "#585850"],
		"hp": 64, "dmg": 16, "speed": 0.28, "beh": "ambush", "size": 1.0, "flags": "na", "loot": [],
		"ab": ["burrow", "tether"],
		"desc": "It lives in six inches of brine, which should not be possible, and is."},
	"prism_mite": {"name": "prism mite", "arch": A_SMALL, "pal": ["#b8d8e8", "#88a8c8", "#e8f8ff", "#405868"],
		"hp": 16, "dmg": 5, "speed": 0.20, "beh": "swarm", "size": 0.7, "flags": "sl", "loot": ["ore_skyglass"],
		"ab": ["static"],
		"desc": "It refracts. In a swarm you cannot tell how many there are, which is the point."},
	"refractor": {"name": "refractor", "arch": A_DRIFT, "pal": ["#c8e8f8", "#98c0d8", "#ffffff", "#486078"],
		"hp": 68, "dmg": 17, "speed": 0.32, "beh": "drifter", "size": 1.0, "flags": "nlx", "loot": ["ore_skyglass"],
		"ab": ["echo", "gaze", "phase"],
		"desc": "What you are looking at is where it was. It has been working on this."},
	"shatterling": {"name": "shatterling", "arch": A_INSECT, "pal": ["#a8b8c8", "#788898", "#d8e8f8", "#384450"],
		"hp": 38, "dmg": 13, "speed": 0.26, "beh": "hunter", "size": 0.9, "flags": "", "loot": ["ore_skyglass"],
		"ab": ["split"],
		"desc": "It breaks when it hits you. That is the attack."},
	# ---------------------------------------------------------------- Hoarfrost / Cragspire
	"frost_wolf": {"name": "frost wolf", "arch": A_QUAD, "pal": ["#b0c0d0", "#7a8a9a", "#e8f0f8", "#3a4450"],
		"hp": 80, "dmg": 18, "speed": 0.24, "beh": "pack", "size": 1.1, "flags": "p", "loot": ["meat_raw"],
		"ab": ["chill", "summon"],
		"desc": "They work the edges of a group and they are extremely good at it."},
	"ice_mite": {"name": "ice mite", "arch": A_SMALL, "pal": ["#a8c8e0", "#7898b8", "#e0f0ff", "#3a5068"],
		"hp": 15, "dmg": 5, "speed": 0.22, "beh": "swarm", "size": 0.7, "flags": "s", "loot": [],
		"ab": ["chill"],
		"desc": "It burrows into anything warmer than the air, which up here is everything you own."},
	"rime_stalker": {"name": "rime stalker", "arch": A_BIPED, "pal": ["#8898a8", "#586878", "#d0e0f0", "#283440"],
		"hp": 96, "dmg": 22, "speed": 0.28, "beh": "ambush", "size": 1.2, "flags": "na", "loot": [],
		"ab": ["chill", "charge"],
		"desc": "It stands in the drift exactly as long as it needs to, and the drift is patient too."},
	"snow_lurker": {"name": "snow lurker", "arch": A_WORM, "pal": ["#c0d0e0", "#90a0b0", "#f0f8ff", "#485868"],
		"hp": 50, "dmg": 13, "speed": 0.30, "beh": "ambush", "size": 1.0, "flags": "a", "loot": [],
		"ab": ["burrow", "tether"],
		"desc": "Under the crust, following the sound of boots."},
	"cold_thing": {"name": "the cold thing", "arch": A_DRIFT, "pal": ["#6a8ab0", "#405a78", "#b0d0f0", "#203040"],
		"hp": 110, "dmg": 24, "speed": 0.34, "beh": "drifter", "size": 1.1, "flags": "nx", "loot": [],
		"ab": ["chill", "phase", "gaze"],
		"desc": "Where it has been is colder, and stays colder, and that is how you track it. It is also how it tracks you."},
	"crag_gargoyle": {"name": "crag gargoyle", "arch": A_BIPED, "pal": ["#787068", "#4a4440", "#a89c90", "#242018"],
		"hp": 140, "dmg": 25, "speed": 0.38, "beh": "ambush", "size": 1.2, "flags": "a", "loot": ["ore_iron"],
		"ab": ["feign", "charge", "regrow"],
		"desc": "It is a rock until it is not. There is no intermediate stage and no warning."},
	"updraft_raptor": {"name": "updraft raptor", "arch": A_FLYER, "pal": ["#8a7058", "#5a4838", "#c8a878", "#2a2018"],
		"hp": 54, "dmg": 16, "speed": 0.18, "beh": "hunter", "size": 1.0, "flags": "f", "loot": ["meat_raw"],
		"ab": ["leap", "steal"],
		"desc": "It uses the thermals off the crag to come at you from above, which is the only direction you are not watching."},
	"stone_tick": {"name": "stone tick", "arch": A_SMALL, "pal": ["#807868", "#585044", "#b0a894", "#282420"],
		"hp": 20, "dmg": 6, "speed": 0.26, "beh": "swarm", "size": 0.7, "flags": "s", "loot": [],
		"ab": ["magnetize"],
		"desc": "It eats rock. Your ship is not rock, but it will try."},
	"quarry_hulk": {"name": "quarry hulk", "arch": A_BIPED, "pal": ["#6a6458", "#403c34", "#9a9080", "#1c1814"],
		"hp": 260, "dmg": 34, "speed": 0.52, "beh": "territory", "size": 1.5, "flags": "", "loot": ["ore_aetherite", "ore_iron"],
		"ab": ["charge", "regrow", "hoard"],
		"desc": "Slow enough to outrun and strong enough that this is the only useful fact about it."},
	# ---------------------------------------------------------------- Boneyard
	"carrion_crawler": {"name": "carrion crawler", "arch": A_WORM, "pal": ["#8a7868", "#5a4c40", "#b8a890", "#2a2218"],
		"hp": 56, "dmg": 14, "speed": 0.28, "beh": "hunter", "size": 1.0, "flags": "", "loot": [],
		"ab": ["burrow"],
		"desc": "It lives inside the big bones and comes out through the marrow channels."},
	"marrow_moth": {"name": "marrow moth", "arch": A_FLYER, "pal": ["#d8c8b0", "#a89880", "#f0e8d8", "#585044"],
		"hp": 24, "dmg": 7, "speed": 0.22, "beh": "grazer", "size": 0.8, "flags": "f", "loot": [],
		"desc": "Dust off its wings smells like a butcher's yard."},
	"bone_picker": {"name": "bone picker", "arch": A_INSECT, "pal": ["#a89880", "#786858", "#d8c8b0", "#382e24"],
		"hp": 36, "dmg": 10, "speed": 0.28, "beh": "pack", "size": 0.9, "flags": "p", "loot": [],
		"ab": ["summon", "hoard"],
		"desc": "It strips a carcass in a morning and it is not fussy about the start date."},
	"gravebound": {"name": "gravebound", "arch": A_BIPED, "pal": ["#9a8a78", "#6a5a48", "#c8b8a0", "#2a2018"],
		"hp": 120, "dmg": 23, "speed": 0.34, "beh": "hunter", "size": 1.1, "flags": "nx", "loot": ["salvage_scrap"],
		"ab": ["summon", "regrow"],
		"desc": "Assembled out of what was to hand, by something with an idea of what a person looks like and no reference."},
	"the_quiet": {"name": "the Quiet", "arch": A_DRIFT, "pal": ["#2a2a30", "#141418", "#585868", "#0a0a0c"],
		"hp": 160, "dmg": 28, "speed": 0.30, "beh": "drifter", "size": 1.3, "flags": "nx", "loot": [],
		"ab": ["gaze", "phase", "shriek", "chill"],
		"desc": "Sound stops about ten feet out from it. You will notice the silence before you notice the shape in it, and by then you have already stopped walking."},
}

# ------------------------------------------------------------------ spawning
## Spawn one creature. `power` is the ring multiplier: everything on the Rim is the same
## animal as the one in the Home Reach, grown into the place it lives.
static func spawn(id: String, cell: Vector2i, power := 1.0) -> Entity:
	var d: Dictionary = BEASTS.get(id, {})
	if d.is_empty():
		return null
	var e := Entity.new()
	e.proto = "beast_" + id
	e.display_name = d["name"]
	e.desc = d["desc"]
	e.cell = cell
	e.position = Entity.cell_to_pos(cell)
	e.z_index = 1
	e.tags = {"beast": id, "arch": d["arch"], "pal": d["pal"], "size": d["size"]}
	var flags: String = d["flags"]
	if "f" in flags:
		e.tags["flying"] = true
	Game.ents_node.add_child(e)

	var health := CHealth.new()
	var mob := CMob.new()
	mob.real_name = d["name"]
	mob.job = ""
	mob.pronoun = "they"
	mob.species_name = id
	e.add(CInventory.new())
	e.add(health)
	e.add(mob)
	Game.register(e)
	health.max_health = float(d["hp"]) * power
	if health.has_method("set_health"):
		health.set_health(health.max_health)
	var ai := CBeastAI.new()
	ai.setup(id, d)
	ai.power = power
	ai.damage = float(d["dmg"]) * (0.6 + power * 0.4)
	e.add(ai)
	e.tags["power"] = power
	if power > 1.6:
		# out here the same animal is simply bigger, and you can see that it is
		e.scale = Vector2.ONE * minf(1.45, 1.0 + (power - 1.0) * 0.16)
		e.display_name = "%s %s" % [_epithet(power), d["name"]]
	mob.move_dur = maxf(0.14, float(d["speed"]) * (1.0 - (power - 1.0) * 0.05))
	mob.refresh_doll()
	if "a" in flags:
		ai.hidden = true
	if "l" in flags:
		var lit := CLight.new().setup({"kind": "always", "radius": 3.2,
			"color": String(d["pal"][2]), "energy": 0.55})
		e.add(lit)
		if Game.lighting:
			Game.lighting.register(lit)
	return e

## Spawn a creature, and its company if it travels in one.
static func _epithet(power: float) -> String:
	if power >= 3.2:
		return ["rimeworn", "old", "sky-scarred", "vast"][Game.rng.randi() % 4]
	if power >= 2.4:
		return ["far-sky", "grown", "hardened"][Game.rng.randi() % 3]
	return ["lean", "wary", "long-ranged"][Game.rng.randi() % 3]

static func spawn_group(id: String, cell: Vector2i, power := 1.0) -> Array:
	var d: Dictionary = BEASTS.get(id, {})
	if d.is_empty():
		return []
	var out := []
	var first := spawn(id, cell, power)
	if first != null:
		out.append(first)
	var flags: String = d["flags"]
	var extra := 0
	if "s" in flags:
		extra = Game.rng.randi_range(2, 4)
	elif "p" in flags:
		extra = Game.rng.randi_range(1, 3)
	for _i in extra:
		var c := _near(cell, 3)
		if c.x < 0:
			continue
		var m := spawn(id, c, power)
		if m != null:
			out.append(m)
	return out

static func _near(c: Vector2i, r: int) -> Vector2i:
	for _try in 20:
		var p: Vector2i = c + Vector2i(Game.rng.randi_range(-r, r), Game.rng.randi_range(-r, r))
		if Game.map.is_passable(p) and Falling.supported(p) and Game.at(p).is_empty():
			return p
	return Vector2i(-1, -1)

static func get_beast(id: String) -> Dictionary:
	return BEASTS.get(id, {})

## What a beast leaves behind. Anomalous things leave nothing, which is part of why
## nobody has worked out what they are.
## What a beast leaves behind, and what a skinner gets out of it.
##
## Beastlore is the skill that turns a carcass into materials: an unskilled kill drops the
## bestiary's listed loot and nothing else, and a skilled one takes the hide, the chitin
## and the parts a distiller wants. A creature from a far ring drops more of everything,
## which is most of why anybody goes out there.
static func drop_loot(e: Entity, killer: Entity = null) -> void:
	var id: String = str(e.tags.get("beast", ""))
	var d: Dictionary = BEASTS.get(id, {})
	if d.is_empty():
		return
	var power := float(e.tags.get("power", 1.0))
	var skill := Skills.frac(killer, "beastlore") if killer != null else 0.0
	for item in d.get("loot", []):
		if not Proto.has(str(item)):
			continue
		var n := 1 + int(floor((power - 1.0) * 0.7 + skill * 2.0))
		for _i in maxi(1, n):
			Proto.spawn(str(item), e.cell)
	# the skinner's bonus: parts the listed loot does not include
	if killer != null and skill > 0.02:
		var extra := _harvest_table(String(d["arch"]))
		for row in extra:
			var chance := float(row[1]) * (0.3 + skill) * (0.7 + power * 0.3)
			if Game.rng.randf() < chance and Proto.has(String(row[0])):
				Proto.spawn(String(row[0]), e.cell)
		Skills.add_xp(killer, "beastlore", 12.0 + float(d["hp"]) * 0.12 * power)
	# anything it had taken off somebody else
	var ai: CBeastAI = e.c(&"beastai")
	if ai != null:
		BeastPowers.on_death(ai, bool(e.tags.get("burned", false)))

## What each body plan is worth to somebody with a knife. Kept as one table rather than
## forty entries because the archetype decides this far more than the species does.
static func _harvest_table(arch: String) -> Array:
	match arch:
		A_QUAD: return [["beast_hide", 0.9], ["meat_raw", 0.7], ["marrow_oil", 0.2]]
		A_SMALL: return [["beast_hide", 0.4], ["meat_raw", 0.6]]
		A_INSECT: return [["chitin_plate", 0.9], ["marrow_oil", 0.15]]
		A_FLYER: return [["skysilk_thread", 0.35], ["meat_raw", 0.5], ["chitin_plate", 0.3]]
		A_DRIFT: return [["skyglass_lens", 0.12], ["sporecap", 0.5]]
		A_BIPED: return [["beast_hide", 0.7], ["bone_meal", 0.6], ["salvage_scrap", 0.2]]
		A_WORM: return [["chitin_plate", 0.6], ["marrow_oil", 0.45], ["meat_raw", 0.4]]
	return []
