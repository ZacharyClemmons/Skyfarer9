class_name SkyCrafting extends RefCounted
## What a skyfarer makes, and what they have to know to make it.
##
## This is the layer that ties the gathering skills to the ship. Every module in
## ShipParts can be bought with marks, and almost every one of them can instead be built
## out of things you dug, felled, skinned or fished for — at a level that takes real
## work. That is the whole argument for a skill system in a game about flying: the
## Vashti turbine you cannot afford at hour three is a thing you can *make* at hour
## twenty, and the route to it goes through mining, smithing and artifice in that order.
##
## A recipe needs three things and states all of them:
##   station   where it can be done. "" is anywhere; "forge", "bench", "still", "loom"
##             are real objects you either carry a ship fitting for or find in a port.
##   reqs      {skill: level}. Hard gates. You are told the shortfall, not refused silently.
##   needs     {proto: count}. Consumed. Stacks give up exactly what is asked for.
##
## and gives back one thing, plus experience in the skill that did the work.

## station id -> what counts as one, and what a port calls it
const STATIONS := {
	"": {"name": "anywhere", "protos": []},
	"bench": {"name": "a workbench", "protos": ["workbench", "table"]},
	"forge": {"name": "a forge", "protos": ["deck_forge", "galley_stove"]},
	"still": {"name": "a still", "protos": ["ship_still", "chem_dispenser"]},
	"loom": {"name": "a sail loft or a palm and needle", "protos": ["loom", "workbench"]},
}

## id -> {name, out, amount, station, reqs, needs, skill, xp, time, desc}
static var RECIPES := {
	# ================================================================ smelting
	"iron_ingot": {"name": "Iron ingot", "out": "iron_ingot", "station": "forge",
		"skill": "smithing", "reqs": {"smithing": 1}, "needs": {"ore_iron": 2}, "xp": 14.0, "time": 3.0,
		"desc": "Two lumps of ore, one bar. Everything metal in this sky starts here."},
	"aether_ingot": {"name": "Aetherite ingot", "out": "aether_ingot", "station": "forge",
		"skill": "smithing", "reqs": {"smithing": 25, "artifice": 15}, "needs": {"ore_aetherite": 3, "iron_ingot": 1},
		"xp": 40.0, "time": 5.0,
		"desc": "Aetherite will not hold a shape on its own. It has to be cast around an iron core, \
and it has to be held down while it cools."},
	"skyglass_lens": {"name": "Skyglass lens", "out": "skyglass_lens", "station": "bench",
		"skill": "artifice", "reqs": {"artifice": 20}, "needs": {"ore_skyglass": 2}, "xp": 34.0, "time": 5.0,
		"desc": "Ground, polished and then left alone for an hour before you touch it again."},
	"voidsteel_ingot": {"name": "Voidsteel ingot", "out": "voidsteel_ingot", "station": "forge",
		"skill": "smithing", "reqs": {"smithing": 60, "artifice": 40},
		"needs": {"iron_ingot": 3, "storm_glass": 1, "ore_cryo": 2}, "xp": 130.0, "time": 9.0,
		"desc": "Quenched in air off the Anvil. You need the air, which means you need to have \
been there, which is most of the difficulty."},
	"sheet_metal_x": {"name": "Metal sheets (x4)", "out": "sheet_metal", "amount": 4, "station": "forge",
		"skill": "smithing", "reqs": {"smithing": 5}, "needs": {"iron_ingot": 1}, "xp": 10.0, "time": 2.0,
		"desc": "Beaten flat. Dull, necessary, and the thing you will make most of."},
	"sheet_glass_x": {"name": "Glass sheets (x3)", "out": "sheet_glass", "amount": 3, "station": "forge",
		"skill": "smithing", "reqs": {"smithing": 12}, "needs": {"ore_skyglass": 1}, "xp": 12.0, "time": 2.5,
		"desc": "Skyglass will make ordinary glass if you are prepared to waste it, and everyone is."},

	# ================================================================ timber
	"sky_timber_plank": {"name": "Planks (x3)", "out": "sheet_wood", "amount": 3, "station": "bench",
		"skill": "woodcutting", "reqs": {"woodcutting": 1}, "needs": {"sky_timber": 1}, "xp": 8.0, "time": 2.0,
		"desc": "Cut along the grain, because cut across it a sky timber will spring and take a finger."},
	"ironwood_beam": {"name": "Ironwood beam", "out": "ironwood_beam", "station": "bench",
		"skill": "woodcutting", "reqs": {"woodcutting": 35, "shipwright": 20},
		"needs": {"sky_timber": 4, "iron_ingot": 1}, "xp": 55.0, "time": 6.0,
		"desc": "Laminated and banded. This is what a keel is, and nothing cheaper will do."},

	# ================================================================ fibre and canvas
	"fibre_rope": {"name": "Cable coil (x3)", "out": "cable_coil", "amount": 3, "station": "",
		"skill": "rigging", "reqs": {"rigging": 1}, "needs": {"fibre_bundle": 2}, "xp": 9.0, "time": 2.0,
		"desc": "Laid up by hand. Every line on a ship starts as this and most of them end as this."},
	"canvas_bolt": {"name": "Bolt of canvas", "out": "canvas_bolt", "station": "loom",
		"skill": "rigging", "reqs": {"rigging": 15}, "needs": {"fibre_bundle": 5}, "xp": 26.0, "time": 4.0,
		"desc": "Woven, then tarred, then rolled while it is still tacky. Do this on deck."},
	"skysilk_thread": {"name": "Skysilk thread", "out": "skysilk_thread", "station": "loom",
		"skill": "rigging", "reqs": {"rigging": 40, "beastlore": 25},
		"needs": {"skysilk_thread": 0, "beast_hide": 1, "fibre_bundle": 3}, "xp": 60.0, "time": 6.0,
		"desc": "Combed out of moth dust and spun onto a card. It takes four hours and it is worth it."},
	"leather_harness": {"name": "Leather harness", "out": "glider_pack", "station": "loom",
		"skill": "rigging", "reqs": {"rigging": 25}, "needs": {"beast_hide": 3, "canvas_bolt": 2, "cable_coil": 4},
		"xp": 70.0, "time": 8.0,
		"desc": "Silk and cane in a back harness. The first one you make, test somewhere low."},

	# ================================================================ distilling
	"distillate": {"name": "Fuel can", "out": "fuel_can", "station": "still",
		"skill": "distilling", "reqs": {"distilling": 1}, "needs": {"ore_sulfur": 2, "sporecap": 1}, "xp": 12.0, "time": 3.0,
		"desc": "Forty units of aether distillate. It is mostly sulfur and regret."},
	"marrow_oil": {"name": "Marrow oil", "out": "marrow_oil", "station": "still",
		"skill": "distilling", "reqs": {"distilling": 25, "beastlore": 20}, "needs": {"bone_meal": 3}, "xp": 34.0, "time": 4.0,
		"desc": "Rendered slowly out of the big bones. Burns at twice the heat of distillate."},
	"tonic_lift": {"name": "Lifter's tonic", "out": "tonic_lift", "station": "still",
		"skill": "distilling", "reqs": {"distilling": 15}, "needs": {"sporecap": 2, "marrow_oil": 1}, "xp": 28.0, "time": 3.0,
		"desc": "You will carry twice what you should for four minutes and ache for a day."},
	"tonic_wind": {"name": "Windwalker's tonic", "out": "tonic_wind", "station": "still",
		"skill": "distilling", "reqs": {"distilling": 20}, "needs": {"sporecap": 2, "fibre_bundle": 2}, "xp": 30.0, "time": 3.0,
		"desc": "Quicker on your feet and worse at judging edges."},
	"tonic_clarity": {"name": "Clarity draught", "out": "tonic_clarity", "station": "still",
		"skill": "distilling", "reqs": {"distilling": 35, "artifice": 20}, "needs": {"ore_skyglass": 1, "sporecap": 3},
		"xp": 55.0, "time": 5.0,
		"desc": "Everything gets louder and a great deal clearer. You learn faster and then you stop."},
	"tonic_breath": {"name": "Thin-air draught", "out": "tonic_breath", "station": "still",
		"skill": "distilling", "reqs": {"distilling": 45}, "needs": {"marrow_oil": 2, "sporecap": 2, "ore_cryo": 1},
		"xp": 70.0, "time": 6.0,
		"desc": "Your blood carries more than it should. The Heights without a mask, briefly."},
	"tonic_ironhide": {"name": "Ironhide draught", "out": "tonic_ironhide", "station": "still",
		"skill": "distilling", "reqs": {"distilling": 40, "beastlore": 30}, "needs": {"chitin_plate": 2, "marrow_oil": 1},
		"xp": 66.0, "time": 5.0,
		"desc": "Your skin goes grey and stops caring. It also stops feeling."},

	# ================================================================ tools and gear
	"forage_knife": {"name": "Forager's knife", "out": "forage_knife", "station": "forge",
		"skill": "smithing", "reqs": {"smithing": 10}, "needs": {"iron_ingot": 1, "sky_timber": 1}, "xp": 22.0, "time": 3.0,
		"desc": "A curved blade for cutting stems without bruising them."},
	"skinning_knife": {"name": "Skinning knife", "out": "skinning_knife", "station": "forge",
		"skill": "smithing", "reqs": {"smithing": 12}, "needs": {"iron_ingot": 1, "beast_hide": 1}, "xp": 24.0, "time": 3.0,
		"desc": "Short, fat-bellied and appallingly sharp."},
	"axe_felling": {"name": "Felling axe", "out": "axe_felling", "station": "forge",
		"skill": "smithing", "reqs": {"smithing": 15}, "needs": {"iron_ingot": 2, "sky_timber": 1}, "xp": 30.0, "time": 4.0,
		"desc": "A long haft and a heavy head."},
	"axe_ironwood": {"name": "Ironwood axe", "out": "axe_ironwood", "station": "forge",
		"skill": "smithing", "reqs": {"smithing": 45, "woodcutting": 35},
		"needs": {"iron_ingot": 3, "ironwood_beam": 1, "skyglass_lens": 1}, "xp": 110.0, "time": 8.0,
		"desc": "Skyglass edge in an ironwood haft. It takes hardwood the felling axe argues with."},
	"pick_aether": {"name": "Aetherite pick", "out": "pick_aether", "station": "forge",
		"skill": "smithing", "reqs": {"smithing": 40, "artifice": 25},
		"needs": {"aether_ingot": 1, "iron_ingot": 2, "sky_timber": 1}, "xp": 105.0, "time": 8.0,
		"desc": "The head is cast round an aetherite core, so it swings lighter than it lands."},
	"sky_rod": {"name": "Skyfisher's rod", "out": "sky_rod", "station": "bench",
		"skill": "rigging", "reqs": {"rigging": 12, "skyfishing": 8}, "needs": {"sky_timber": 2, "skysilk_thread": 1, "cable_coil": 2},
		"xp": 40.0, "time": 5.0,
		"desc": "Twelve feet of springy cane, a drum reel and two hundred fathoms of silk."},
	"artificers_kit": {"name": "Artificer's kit", "out": "artificers_kit", "station": "bench",
		"skill": "artifice", "reqs": {"artifice": 25}, "needs": {"iron_ingot": 2, "skyglass_lens": 1, "beast_hide": 1},
		"xp": 66.0, "time": 6.0,
		"desc": "Loupes, needle files and six things with no name outside the trade."},
	"sky_compass": {"name": "Aether compass", "out": "sky_compass", "station": "bench",
		"skill": "artifice", "reqs": {"artifice": 18, "navigation": 10}, "needs": {"ore_aetherite": 2, "iron_ingot": 1, "sheet_glass": 1},
		"xp": 48.0, "time": 5.0,
		"desc": "The needle ignores north and points at the nearest land."},
	"breathing_rig": {"name": "Altitude rig", "out": "breathing_rig", "station": "bench",
		"skill": "artifice", "reqs": {"artifice": 22, "survival": 20}, "needs": {"beast_hide": 2, "iron_ingot": 1, "cable_coil": 3},
		"xp": 52.0, "time": 5.0,
		"desc": "A mask and a small bottle. Above the Reaches the air stops being a courtesy."},
	"grapple_gun": {"name": "Grapple launcher", "out": "grapple_gun", "station": "bench",
		"skill": "artifice", "reqs": {"artifice": 28, "smithing": 20}, "needs": {"iron_ingot": 2, "cable_coil": 6, "skysilk_thread": 1},
		"xp": 74.0, "time": 6.0,
		"desc": "A barbed hook on a drum of line."},

	# ================================================================ weapons
	"harpoon": {"name": "Hand harpoon", "out": "harpoon", "station": "forge",
		"skill": "smithing", "reqs": {"smithing": 14}, "needs": {"iron_ingot": 1, "sky_timber": 1}, "xp": 26.0, "time": 3.0,
		"desc": "Barbed, weighted and meant to be thrown."},
	"boarding_axe": {"name": "Boarding axe", "out": "boarding_axe", "station": "forge",
		"skill": "smithing", "reqs": {"smithing": 22}, "needs": {"iron_ingot": 2, "ironwood_beam": 0, "sky_timber": 1},
		"xp": 40.0, "time": 4.0,
		"desc": "Half axe, half grapnel."},
	"cutlass_brine": {"name": "Brinesteel cutlass", "out": "cutlass_brine", "station": "forge",
		"skill": "smithing", "reqs": {"smithing": 38, "melee": 25}, "needs": {"iron_ingot": 3, "ore_skyglass": 1},
		"xp": 96.0, "time": 7.0,
		"desc": "Salt-quenched. It leaves wounds that do not want to close."},
	"cinder_maul": {"name": "Cinder maul", "out": "cinder_maul", "station": "forge",
		"skill": "smithing", "reqs": {"smithing": 42}, "needs": {"iron_ingot": 2, "ore_plasma": 2, "ironwood_beam": 1},
		"xp": 108.0, "time": 8.0,
		"desc": "A basalt head that holds the forge's heat for about a week."},
	"aether_pistol": {"name": "Aether pistol", "out": "aether_pistol", "station": "bench",
		"skill": "artifice", "reqs": {"artifice": 32, "marksman": 15}, "needs": {"skyglass_lens": 1, "iron_ingot": 2, "cable_coil": 4},
		"xp": 90.0, "time": 7.0,
		"desc": "A lens, a coil and a grip."},
	"lance_carbine": {"name": "Lance carbine", "out": "lance_carbine", "station": "bench",
		"skill": "artifice", "reqs": {"artifice": 55, "marksman": 35}, "needs": {"skyglass_lens": 2, "aether_ingot": 1, "voidsteel_ingot": 1},
		"xp": 220.0, "time": 12.0,
		"desc": "The aether lance shrunk until one person can hold it."},
	"stormblade": {"name": "Stormblade", "out": "stormblade", "station": "forge",
		"skill": "smithing", "reqs": {"smithing": 60, "artifice": 50, "melee": 45},
		"needs": {"voidsteel_ingot": 1, "skyglass_lens": 2, "storm_glass": 2}, "xp": 280.0, "time": 14.0,
		"desc": "A skyglass core in a steel spine, kept charged off the air."},
}

# ------------------------------------------------------------------ modules from parts
## Every ship module can also be built rather than bought. The bill of materials is
## derived from what the module *is* — its category and tier — rather than written out
## sixty times, so adding a module to the catalogue automatically makes it craftable and
## the recipe is always in proportion to the thing.
const CAT_MATERIALS := {
	"thruster": [["iron_ingot", 3], ["sheet_metal", 4], ["cable_coil", 3]],
	"propeller": [["iron_ingot", 2], ["sky_timber", 2], ["cable_coil", 2]],
	"mast": [["sky_timber", 3], ["canvas_bolt", 3], ["cable_coil", 4]],
	"lift": [["ore_aetherite", 4], ["canvas_bolt", 2], ["cable_coil", 3]],
	"boiler": [["iron_ingot", 4], ["sheet_metal", 3], ["cable_coil", 2]],
	"dynamo": [["iron_ingot", 3], ["cable_coil", 6], ["ore_aetherite", 1]],
	"bunker": [["sheet_metal", 5], ["iron_ingot", 1]],
	"gun": [["iron_ingot", 4], ["sky_timber", 1], ["cable_coil", 2]],
	"helm": [["sky_timber", 2], ["iron_ingot", 1], ["cable_coil", 2]],
	"nav": [["sheet_glass", 2], ["iron_ingot", 1], ["ore_aetherite", 1]],
	"utility": [["sheet_metal", 3], ["sky_timber", 2]],
	"armor": [["iron_ingot", 2], ["sheet_metal", 2]],
}
## What each tier adds on top, and which skill does the work.
const TIER_EXTRA := [
	[],
	[],
	[["iron_ingot", 2]],
	[["aether_ingot", 1], ["skyglass_lens", 1]],
	[["voidsteel_ingot", 1], ["storm_glass", 2], ["aether_ingot", 2]],
]
const CAT_SKILL := {
	"thruster": "smithing", "propeller": "smithing", "mast": "rigging", "lift": "rigging",
	"boiler": "smithing", "dynamo": "artifice", "bunker": "smithing", "gun": "smithing",
	"helm": "artifice", "nav": "artifice", "utility": "shipwright", "armor": "smithing",
}
const CAT_STATION := {
	"mast": "loom", "lift": "loom", "nav": "bench", "helm": "bench", "dynamo": "bench",
	"utility": "bench",
}

## Build the module recipes once, at boot, from the catalogue.
static func install() -> void:
	for mid in ShipParts.MODULES:
		var m: Dictionary = ShipParts.MODULES[mid]
		var cat := String(m["cat"])
		var tier := int(m.get("tier", 1))
		if cat == "armor" and tier == 0:
			continue  # plain planking is not a thing you make, it is a thing a hull has
		var needs := {}
		for row in CAT_MATERIALS.get(cat, [["iron_ingot", 2]]):
			needs[String(row[0])] = int(row[1]) + tier
		for row in TIER_EXTRA[clampi(tier, 0, 4)]:
			needs[String(row[0])] = int(needs.get(String(row[0]), 0)) + int(row[1])
		var skill := String(CAT_SKILL.get(cat, "shipwright"))
		var reqs: Dictionary = (m.get("req", {}) as Dictionary).duplicate()
		# building it yourself is always harder than being allowed to fit one
		reqs[skill] = maxi(int(reqs.get(skill, 1)), 6 + tier * 16)
		reqs["shipwright"] = maxi(int(reqs.get("shipwright", 1)), 1 + tier * 12)
		RECIPES["mod_" + mid] = {
			"name": "%s (crated)" % String(m["name"]).capitalize(),
			"out": "mod_" + mid, "station": String(CAT_STATION.get(cat, "forge")),
			"skill": skill, "reqs": reqs, "needs": needs,
			"xp": 40.0 + float(tier) * 70.0, "time": 5.0 + float(tier) * 3.0,
			"desc": String(m.get("desc", "")), "module": true,
		}

# ------------------------------------------------------------------ making things
## Which station a person is standing at, if any.
static func station_at(user: Entity) -> String:
	if user == null:
		return ""
	var have := {"": true}
	for d in Defs.DIRS8 + [Vector2i.ZERO]:
		for e in Game.at(user.root_cell() + d):
			for sid in STATIONS:
				if sid == "":
					continue
				if e.proto in STATIONS[sid]["protos"]:
					have[sid] = true
	# a ship fitting counts: a deck forge is a forge, a ship's still is a still
	var sh: Airship = Game.fleet.ship_of(user) if Game.fleet != null else null
	if sh != null:
		for q in [["forge", "forge"], ["still", "still"], ["bench", "bench"], ["loom", "bench"]]:
			if sh.has_quirk(String(q[1])):
				have[String(q[0])] = true
	var out := []
	for k in have:
		out.append(k)
	return ",".join(out)

static func at_station(user: Entity, want: String) -> bool:
	if want == "":
		return true
	return want in station_at(user).split(",")

## Everything this person could see on a crafting list, with why they can or cannot.
static func available(user: Entity) -> Array:
	var out := []
	var here := station_at(user).split(",")
	for id in RECIPES:
		var r: Dictionary = RECIPES[id]
		var st := String(r.get("station", ""))
		var short := Skills.shortfall(user, r.get("reqs", {}))
		var missing := _missing(user, r.get("needs", {}))
		out.append({
			"id": id, "r": r,
			"station_ok": st == "" or st in here,
			"skill_short": short,
			"missing": missing,
			"can": (st == "" or st in here) and short == "" and missing.is_empty(),
		})
	# Ordered by chain, not by name. Alphabetical put "Aether Beacon" above "Iron ingot",
	# which is exactly backwards: a bench list should read as a route. So it goes
	# makeable-first, then grouped by the skill that does the work, then by the level it
	# unlocks at — which is the order a player will actually learn them in.
	out.sort_custom(func(a, b):
		if a["can"] != b["can"]:
			return a["can"]
		var sa := String(a["r"].get("skill", ""))
		var sb := String(b["r"].get("skill", ""))
		if sa != sb:
			return sa < sb
		var la := int((a["r"].get("reqs", {}) as Dictionary).get(sa, 1))
		var lb := int((b["r"].get("reqs", {}) as Dictionary).get(sb, 1))
		if la != lb:
			return la < lb
		return String(a["r"]["name"]) < String(b["r"]["name"]))
	return out

static func _missing(user: Entity, needs: Dictionary) -> Array:
	var have := _tally(user)
	var out := []
	for k in needs:
		var n := int(needs[k])
		if n <= 0:
			continue
		var got := int(have.get(k, 0))
		if got < n:
			out.append("%s %d/%d" % [String(Proto.P.get(k, {}).get("name", k)), got, n])
	return out

## Everything in reach: hands, bags, and the tile you are standing on.
static func _tally(user: Entity) -> Dictionary:
	var out := {}
	if user == null:
		return out
	var inv: CInventory = user.c(&"inv")
	var pool := []
	if inv != null:
		pool = inv.all_items(true)
	for e in Game.at(user.root_cell()):
		if e.has_c(&"item"):
			pool.append(e)
		var st: CStorage = e.c(&"storage")
		if st != null:
			for inner in st.contents:
				pool.append(inner)
	for it in pool:
		if not is_instance_valid(it) or it.removed:
			continue
		var stk: CStack = it.c(&"stack")
		out[it.proto] = int(out.get(it.proto, 0)) + (stk.amount if stk != null else 1)
	return out

## Make one. Returns "" on success or the reason it did not happen.
static func craft(user: Entity, id: String) -> String:
	var r: Dictionary = RECIPES.get(id, {})
	if r.is_empty():
		return "no such recipe"
	var st := String(r.get("station", ""))
	if not at_station(user, st):
		return "You need %s for that." % String(STATIONS[st]["name"])
	var short := Skills.shortfall(user, r.get("reqs", {}))
	if short != "":
		return "You would need %s." % short
	var missing := _missing(user, r.get("needs", {}))
	if not missing.is_empty():
		return "Short: %s." % ", ".join(missing)
	var skill := String(r.get("skill", "construction"))
	var secs: float = float(r.get("time", 4.0)) * Skills.speed(user, skill)
	Game.tell(user, "You start on the %s..." % String(r["name"]).to_lower())
	DoAfter.start(user, null, secs, func(ok: bool):
		if not ok:
			return
		if not _missing(user, r.get("needs", {})).is_empty():
			Game.tell(user, "Something you needed has gone.", "warn")
			return
		_consume(user, r.get("needs", {}))
		var n := int(r.get("amount", 1))
		# a master wastes less and occasionally gets a second one out of the same stock
		if Game.rng.randf() < Skills.chance(user, skill, 0.0, 0.18):
			n += 1
			Game.tell(user, "[color=#6ad88a]That one came out well enough for two.[/color]", "good")
		var made: Entity = null
		for _i in n:
			made = Proto.spawn(String(r["out"]), user.root_cell())
			if made != null:
				Economy.deliver(user, made)
		Skills.add_xp(user, skill, float(r.get("xp", 10.0)))
		Sfx.play("ratchet", user.root_cell(), 0.6)
		if made != null:
			Game.tell(user, "[color=#6ad88a]%s.[/color]" % made.display_name.capitalize(), "good")
		Bus.stimulus.emit({"type": "crafted", "actor": user, "cell": user.root_cell(), "loud": 2.0}))
	return ""

static func _consume(user: Entity, needs: Dictionary) -> void:
	var inv: CInventory = user.c(&"inv")
	var pool := []
	if inv != null:
		pool = inv.all_items(true)
	for e in Game.at(user.root_cell()):
		if e.has_c(&"item"):
			pool.append(e)
		var st: CStorage = e.c(&"storage")
		if st != null:
			for inner in st.contents:
				pool.append(inner)
	for k in needs:
		var left := int(needs[k])
		for it in pool:
			if left <= 0:
				break
			if not is_instance_valid(it) or it.removed or it.proto != k:
				continue
			var stk: CStack = it.c(&"stack")
			if stk != null:
				var take: int = mini(left, stk.amount)
				stk.amount -= take
				left -= take
				if stk.amount <= 0:
					it.destroy()
			else:
				it.destroy()
				left -= 1
