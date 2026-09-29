class_name Economy extends RefCounted
## Marks, and what things are worth in them.
##
## The Cloudsea runs on the aether mark: a stamped disc of the same alloy the lift cells
## are rated in, which is a joke the ports stopped finding funny some centuries ago. You
## carry them in a purse rather than a bank account, because everything in this game that
## matters is a thing you can lose.
##
## Prices move. Every port has a mood — what it makes, what it has run out of, what it
## does not want — and a cargo of frost-pine is worth four times as much on a cinder isle
## as it is on the island it grew on. That, and nothing else, is the trading game: find
## the difference, survive the distance.

## What a second-hand skiff costs at the Meridian yard, and therefore the purse a new
## skyfarer is handed. The two numbers are meant to be the same to within a rounding
## error: the opening decision only works if buying the skiff and drawing your own hull
## cost the same, and the player is told the number out loud so they can check.
## `--gencheck` prints every hull's price against this, so it cannot quietly drift.
const STARTING_PURSE := 3300

## Trading skill haggles this far in your favour at each end of the counter.
const HAGGLE_BUY := 0.22   # pay this much less at mastery
const HAGGLE_SELL := 0.28  # get this much more at mastery

# ------------------------------------------------------------------ the purse
## Debug: the player can afford anything and nothing is ever deducted. Toggled from the
## F10 menu (or --rich on the command line) so shops and the yard can be tested freely.
static var infinite := false
const INFINITE_PURSE := 9999999

static func purse(who: Entity) -> int:
	if who == null or not is_instance_valid(who):
		return 0
	if infinite and who == Game.player:
		return INFINITE_PURSE
	return int(who.tags.get("marks", 0))

static func set_purse(who: Entity, v: int) -> void:
	if who == null:
		return
	who.tags["marks"] = maxi(0, v)
	if who == Game.player:
		Bus.powers_changed.emit() # the HUD's cheap "something about me changed" signal

static func give(who: Entity, v: int) -> void:
	if v == 0:
		return
	set_purse(who, purse(who) + v)
	if who == Game.player and v > 0:
		Game.tell(who, "[color=#e8c85a]+%s marks.[/color]" % money(v), "good")

static func can_afford(who: Entity, cost: int) -> bool:
	return purse(who) >= cost

static func take(who: Entity, cost: int) -> bool:
	if not can_afford(who, cost):
		return false
	if infinite and who == Game.player:
		return true
	set_purse(who, purse(who) - cost)
	return true

## 12,400 rather than 12400, because the number is read at a glance in a shop list.
static func money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	var n := s.length()
	for i in n:
		if i > 0 and (n - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("-" if v < 0 else "") + out

# ------------------------------------------------------------------ what things are worth
## Base value of one unit of a prototype, before any port's mood is applied. Anything not
## listed falls back to its `value` tag, then to a floor, so a new item is never free.
const BASE := {
	# raw materials
	"ore_aetherite": 46, "ore_skyglass": 72, "ore_sulfur": 18, "ore_iron": 14, "ore_gold": 90,
	"ore_plasma": 58, "ore_cryo": 40,
	"sheet_metal": 9, "sheet_glass": 7, "sheet_wood": 5, "cable_coil": 3, "rods": 4,
	"salvage_scrap": 26, "sky_timber": 12, "iron_ingot": 26, "skyglass_lens": 88,
	"aether_ingot": 110, "chitin_plate": 34, "beast_hide": 22, "skysilk_thread": 64,
	"fibre_bundle": 6, "bone_meal": 9, "marrow_oil": 38, "sporecap": 11,
	# consumables
	"fuel_can": 34, "meat_raw": 7, "ice_chunk": 2,
	# tools and gear
	"toolbox": 60, "welder": 48, "multitool": 55, "pickaxe": 42, "flashlight": 20,
	"glider_pack": 340, "grapple_gun": 290, "sky_compass": 180, "spyglass": 260,
	"breathing_rig": 210, "ship_rig": 320, "chart_scrap": 70,
	# paper
	"spacecash": 1,
}

## Every port pays this fraction of an item's value when you sell to it. Shops mark up on
## the way out and down on the way in, which is why they are shops.
const SELL_FRACTION := 0.55

static func base_value(proto_id: String) -> int:
	if BASE.has(proto_id):
		return int(BASE[proto_id])
	if ShipParts.exists(proto_id):
		return int(ShipParts.stat(proto_id, "cost", 100.0))
	if proto_id.begins_with("mod_") and ShipParts.exists(proto_id.substr(4)):
		return int(ShipParts.stat(proto_id.substr(4), "cost", 100.0))
	var p: Dictionary = Proto.P.get(proto_id, {})
	var tags: Dictionary = p.get("tags", {})
	if tags.has("value"):
		return int(tags["value"])
	var comps: Dictionary = p.get("comps", {})
	if comps.has("item"):
		return maxi(4, int(comps["item"].get("w", 2)) * 5)
	return 6

## What one entity is worth, counting its stack size and its condition.
static func value_of(e: Entity) -> int:
	if e == null or e.removed:
		return 0
	var v := base_value(e.proto)
	var st: CStack = e.c(&"stack")
	if st != null:
		v *= st.amount
	var storage: CStorage = e.c(&"storage")
	if storage != null:
		for inner in storage.contents:
			v += value_of(inner)
	return v

# ------------------------------------------------------------------ haggling
## What the player actually pays. Trading skill is a real discount, and it compounds with
## a good standing at that particular counter.
static func buy_price(base: int, who: Entity, markup := 1.0, standing := 0.0) -> int:
	var skill := Skills.frac(who, "trading")
	var f := markup * (1.0 - skill * HAGGLE_BUY) * (1.0 - clampf(standing, -0.3, 0.3) * 0.25)
	return maxi(1, int(round(base * f)))

static func sell_price(base: int, who: Entity, demand := 1.0, standing := 0.0) -> int:
	var skill := Skills.frac(who, "trading")
	var f := SELL_FRACTION * demand * (1.0 + skill * HAGGLE_SELL) * (1.0 + clampf(standing, -0.3, 0.3) * 0.25)
	return maxi(1, int(round(base * f)))

# ------------------------------------------------------------------ port moods
## A port's mood: what it produces (cheap to buy there, worthless to sell there) and what
## it wants (expensive to buy, excellent to sell). Ports are seeded from their island's
## biome, so a frost isle always wants timber and always has cryonite to spare, and a
## player who learns that has learned a trade route.
const BIOME_TRADE := {
	"verdance": {"makes": ["sky_timber", "meat_raw", "fibre_bundle"], "wants": ["ore_iron", "sheet_metal", "fuel_can"]},
	"thornwild": {"makes": ["sky_timber", "fibre_bundle", "sporecap"], "wants": ["iron_ingot", "fuel_can", "toolbox"]},
	"fenmoor": {"makes": ["ore_sulfur", "sporecap", "marrow_oil"], "wants": ["sky_timber", "sheet_glass", "meat_raw"]},
	"bloomrot": {"makes": ["sporecap", "marrow_oil", "fibre_bundle"], "wants": ["ore_iron", "sheet_metal", "fuel_can"]},
	"cinderpeak": {"makes": ["ore_sulfur", "ore_plasma", "iron_ingot"], "wants": ["sky_timber", "ice_chunk", "meat_raw"]},
	"ashveil": {"makes": ["ore_sulfur", "bone_meal"], "wants": ["sky_timber", "fuel_can", "fibre_bundle"]},
	"dunebank": {"makes": ["ore_skyglass", "sheet_glass", "skyglass_lens"], "wants": ["sky_timber", "meat_raw", "fibre_bundle"]},
	"saltmere": {"makes": ["ore_skyglass", "meat_raw"], "wants": ["sky_timber", "ore_iron", "fuel_can"]},
	"hoarfrost": {"makes": ["ore_cryo", "beast_hide"], "wants": ["sky_timber", "fuel_can", "sporecap"]},
	"cragspire": {"makes": ["ore_aetherite", "ore_iron", "iron_ingot"], "wants": ["sky_timber", "meat_raw", "fibre_bundle"]},
	"glasswaste": {"makes": ["ore_skyglass", "skyglass_lens", "sheet_glass"], "wants": ["sky_timber", "meat_raw", "iron_ingot"]},
	"boneyard": {"makes": ["bone_meal", "marrow_oil", "ore_aetherite"], "wants": ["sky_timber", "fuel_can", "meat_raw"]},
	"stormcrown": {"makes": ["ore_aetherite", "aether_ingot"], "wants": ["sky_timber", "meat_raw", "iron_ingot"]},
	"mirrormere": {"makes": ["skyglass_lens", "ore_skyglass"], "wants": ["sky_timber", "fuel_can", "beast_hide"]},
	"rustfall": {"makes": ["salvage_scrap", "iron_ingot", "sheet_metal"], "wants": ["sky_timber", "meat_raw", "sporecap"]},
	"vergegloom": {"makes": ["marrow_oil", "ore_aetherite"], "wants": ["sky_timber", "fuel_can", "ice_chunk"]},
}

## Multipliers a port applies to one prototype. Returns [buy_markup, sell_demand].
static func port_rates(biome: String, proto_id: String) -> Array:
	var t: Dictionary = BIOME_TRADE.get(biome, {})
	if t.is_empty():
		return [1.0, 1.0]
	if proto_id in t.get("makes", []):
		return [0.62, 0.45]  # plentiful here: cheap to buy, nobody wants yours
	if proto_id in t.get("wants", []):
		return [1.55, 1.85]  # scarce here: dear to buy, and they will pay for yours
	return [1.0, 1.0]

## The one-line hint a port gives you at the counter, so a trade route is discoverable by
## talking to people rather than by reading a wiki.
static func port_hint(biome: String) -> String:
	var t: Dictionary = BIOME_TRADE.get(biome, {})
	if t.is_empty():
		return ""
	var makes: Array = t.get("makes", [])
	var wants: Array = t.get("wants", [])
	if makes.is_empty() or wants.is_empty():
		return ""
	return "We have %s coming out of our ears. What we never have enough of is %s." % [
		_pretty(String(makes[0])), _pretty(String(wants[0]))]

static func _pretty(proto_id: String) -> String:
	var p: Dictionary = Proto.P.get(proto_id, {})
	return String(p.get("name", proto_id.replace("_", " ")))

# ------------------------------------------------------------------ handing things over
## Put a bought item somewhere sensible: a free hand, then any bag or pocket, then the
## floor at their feet. A purchase should never quietly vanish and never refuse to
## happen because both hands were full.
static func deliver(who: Entity, item: Entity) -> String:
	if who == null or item == null or item.removed:
		return "nowhere"
	var inv: CInventory = who.c(&"inv")
	if inv == null:
		return "the deck"
	if inv.put_in_hands(item):
		return "your hands"
	for slot in ["back", "belt", "pocket_l", "pocket_r", "suit"]:
		var bag: Entity = inv.worn(slot)
		if bag == null:
			continue
		var st: CStorage = bag.c(&"storage")
		if st != null and st.insert(item):
			return bag.display_name
	inv.drop(item, who.root_cell())
	return "the deck at your feet"
