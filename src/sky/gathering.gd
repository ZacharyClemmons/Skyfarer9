class_name Gathering extends RefCounted
## Taking things out of the world: timber, fibre, hide, ore.
##
## Every gathering action in this game follows the same shape, because a player who has
## learned one has learned all of them: stand next to the thing, use the right tool on
## it, wait, and get more of it than you would have last week. What changes between them
## is which skill improves and what the yield feeds.
##
## The chains all converge on the ship, which is the point:
##   timber  -> planks    -> hull, and ironwood -> keels
##   fibre   -> rope      -> rigging, and canvas -> sails
##   hide    -> harness   -> gliders, and leather -> bunkers
##   chitin  -> plate     -> armour that does not conduct
##   ore     -> ingots    -> everything metal
##   sporecap-> tonics    -> the four minutes where you are better than you are

## What a prop gives up, keyed by prototype. [skill, tool, [drop, base amount], seconds]
## A prop not listed here is scenery: you can break it, but it is not a resource.
const HARVEST := {
	# ---- timber. A felling axe, or an ironwood axe for the hard woods.
	"sky_oak": ["woodcutting", "chop", [["sky_timber", 2.0]], 5.0, 1],
	"hearth_tree": ["woodcutting", "chop", [["sky_timber", 2.5], ["fibre_bundle", 0.5]], 5.0, 1],
	"thorn_tree": ["woodcutting", "chop", [["sky_timber", 2.0], ["fibre_bundle", 1.0]], 6.0, 1],
	"frost_pine": ["woodcutting", "chop", [["sky_timber", 2.0]], 6.0, 1],
	"glass_tree": ["woodcutting", "chop", [["ore_skyglass", 1.0], ["sheet_glass", 1.0]], 8.0, 3],
	"gloom_stalk": ["woodcutting", "chop", [["sky_timber", 1.5], ["pale_fungus_cap", 0.0]], 6.0, 3],
	"lightning_tree": ["woodcutting", "chop", [["sky_timber", 1.5], ["fulgurite", 0.8]], 9.0, 3],
	"cap_tower": ["woodcutting", "chop", [["sporecap", 2.0], ["sky_timber", 0.5]], 4.0, 1],
	"bog_stump": ["woodcutting", "chop", [["sky_timber", 1.0]], 4.0, 1],
	"burnt_stump": ["woodcutting", "chop", [["sky_timber", 0.6]], 3.0, 1],
	"ember_spire": ["woodcutting", "chop", [["storm_glass", 0.4], ["ore_skyglass", 1.0]], 9.0, 3],
	# ---- fibre and fungus. A knife, or your hands at a penalty.
	"tall_reed": ["foraging", "cut", [["fibre_bundle", 1.5]], 2.5, 1],
	"reed_bed": ["foraging", "cut", [["fibre_bundle", 2.0]], 3.0, 1],
	"vine_curtain": ["foraging", "cut", [["fibre_bundle", 2.0]], 3.0, 1],
	"fern_giant": ["foraging", "cut", [["fibre_bundle", 1.5]], 3.0, 1],
	"wildflowers": ["foraging", "cut", [["sporecap", 0.4], ["fibre_bundle", 0.6]], 2.0, 1],
	"moss_bed": ["foraging", "cut", [["fibre_bundle", 1.0]], 2.0, 1],
	"cliff_moss": ["foraging", "cut", [["fibre_bundle", 0.8]], 2.0, 1],
	"bush_berry": ["foraging", "cut", [["food_tomato", 1.5]], 2.0, 1],
	"spore_pod": ["foraging", "cut", [["sporecap", 1.5]], 3.0, 2],
	"puffball": ["foraging", "cut", [["sporecap", 1.5]], 2.5, 2],
	"mycelium_mat": ["foraging", "cut", [["sporecap", 1.0], ["fibre_bundle", 0.5]], 3.0, 2],
	"pale_fungus": ["foraging", "cut", [["sporecap", 2.0]], 3.0, 3],
	"aether_polyp": ["foraging", "cut", [["ore_aetherite", 0.6], ["sporecap", 1.0]], 4.0, 2],
	"reef_fan": ["foraging", "cut", [["fibre_bundle", 1.5], ["chitin_plate", 0.4]], 4.0, 2],
	"marrow_well": ["foraging", "cut", [["marrow_oil", 1.0], ["bone_meal", 1.0]], 5.0, 2],
	"bone_pile": ["foraging", "cut", [["bone_meal", 2.0]], 3.0, 1],
	"fumarole": ["foraging", "cut", [["ore_sulfur", 1.5]], 4.0, 2],
	"brine_pool": ["foraging", "cut", [["ore_sulfur", 0.8]], 3.0, 1],
	"fulgurite": ["foraging", "cut", [["fulgurite", 1.0], ["storm_glass", 0.3]], 4.0, 3],
	# ---- salvage. A crowbar, a saw, or a lot of patience.
	"hull_plate_heap": ["salvaging", "pry", [["sheet_metal", 2.0], ["salvage_scrap", 1.0]], 5.0, 1],
	"rust_spar": ["salvaging", "pry", [["salvage_scrap", 2.0], ["iron_ingot", 0.4]], 6.0, 2],
	"frozen_carcass": ["beastlore", "cut", [["beast_hide", 1.5], ["meat_raw", 1.0]], 5.0, 1],
	"dune_bone": ["foraging", "cut", [["bone_meal", 1.5]], 4.0, 1],
	"skull_huge": ["beastlore", "cut", [["bone_meal", 3.0], ["marrow_oil", 0.8]], 8.0, 2],
	"rib_arch": ["beastlore", "cut", [["bone_meal", 2.5]], 7.0, 2],
	"obsidian_shard": ["mining", "dig", [["ore_skyglass", 0.6], ["sheet_glass", 1.0]], 4.0, 2],
	"prism_shard": ["mining", "dig", [["ore_skyglass", 1.5]], 5.0, 2],
	"glass_shard": ["mining", "dig", [["sheet_glass", 1.0]], 3.0, 1],
	"salt_pillar": ["mining", "dig", [["ore_sulfur", 1.0]], 4.0, 1],
	"ice_spire": ["mining", "dig", [["ore_cryo", 1.0], ["ice_chunk", 1.0]], 5.0, 2],
	"boulder": ["mining", "dig", [["ore_iron", 0.8]], 5.0, 1],
	"wind_sculpt": ["mining", "dig", [["ore_iron", 1.0]], 6.0, 1],
	"storm_spire": ["mining", "dig", [["ore_iron", 1.5], ["storm_glass", 0.5]], 8.0, 3],
	"chalk_figure": ["mining", "dig", [["bone_meal", 1.0]], 6.0, 1],
}

## What a tool tier is worth: a better axe is faster and yields more, and some things
## simply refuse a tool below their grade.
const TOOL_TIERS := {"": 0, "chop": 1, "cut": 1, "dig": 1, "pry": 1}

# ------------------------------------------------------------------ entry
## Called by the interaction layer when an item is used on a scenery prop. Returns true
## if this was a gathering action, whether or not it succeeded.
static func try_harvest(user: Entity, item: Entity, target: Entity) -> bool:
	var row: Array = HARVEST.get(target.proto, [])
	if row.is_empty():
		return false
	var skill := String(row[0])
	var want_tool := String(row[1])
	var drops: Array = row[2]
	var secs := float(row[3])
	var grade := int(row[4])
	var it: CItem = item.c(&"item") if item != null else null
	var tool := String(it.tool) if it != null else ""
	var tier := int(item.tags.get("tool_tier", 1)) if item != null else 0
	if tool != want_tool:
		# hands and the wrong tool both work on soft things, slowly, and not on hard ones
		if grade > 1:
			Game.tell(user, "You need %s for that." % _tool_word(want_tool), "warn")
			return true
		if tool == "":
			secs *= 2.4
			tier = 0
		else:
			secs *= 1.6
			tier = maxi(0, tier - 1)
	if tier < grade:
		Game.tell(user, "[color=#e8a83a]%s will not touch it. You need something better.[/color]" % (
			item.display_name.capitalize() if item != null else "Your hands"), "warn")
		return true
	var lvl := Skills.level(user, skill)
	var need_lvl := (grade - 1) * 25
	if lvl < need_lvl:
		Game.tell(user, "[color=#ff6a6a]You do not know how. %s %d would do it.[/color]" % [
			String(Skills.SKILLS[skill]["name"]), need_lvl], "warn")
		return true
	secs *= Skills.speed(user, skill)
	Sfx.play("dig" if want_tool == "dig" else "ratchet", target.cell, 0.5)
	DoAfter.start(user, target, secs, func(ok: bool):
		if not ok or not is_instance_valid(target) or target.removed:
			return
		_yield(user, target, skill, drops, grade))
	return true

static func _tool_word(t: String) -> String:
	return {"chop": "an axe", "cut": "a knife", "dig": "a pick", "pry": "a crowbar or a saw"}.get(t, "the right tool")

static func _yield(user: Entity, target: Entity, skill: String, drops: Array, grade: int) -> void:
	var total := 0
	var luck := SkyBuffs.value(user, "luck", 0.0)
	for row in drops:
		var proto_id := String(row[0])
		var base := float(row[1])
		if base <= 0.0 or not Proto.has(proto_id):
			continue
		var n := Skills.yield_roll(user, skill, base)
		if base < 1.0 and Game.rng.randf() > base + Skills.frac(user, skill) * 0.4 + luck:
			continue  # the occasional extra, not the guaranteed one
		for _i in n:
			var made := Proto.spawn(proto_id, user.root_cell())
			if made != null:
				Economy.deliver(user, made)
		total += n
	# what it was worth to learn from
	var xp := 12.0 + float(grade) * 14.0
	Skills.add_xp(user, skill, xp)
	Bus.stimulus.emit({"type": "harvested", "actor": user, "cell": target.cell, "loud": 3.0})
	if total > 0:
		Game.tell(user, "[color=#6ad88a]%s.[/color]" % _harvest_line(target, total), "good")
	else:
		Game.tell(user, "Nothing worth taking out of it.")
	Fx.smoke_puff(target.cell)
	target.destroy()

static func _harvest_line(target: Entity, n: int) -> String:
	var verb: String = ["You take", "You get", "You come away with"][Game.rng.randi() % 3]
	return "%s %d out of the %s" % [verb, n, target.display_name]

# ------------------------------------------------------------------ skinning
## A carcass, and a knife. Beastlore decides what comes off it; without a knife you get
## meat and nothing else, which is how you find out the skill exists.
static func try_skin(user: Entity, item: Entity, target: Entity) -> bool:
	if not target.tags.has("carcass"):
		return false
	var it: CItem = item.c(&"item") if item != null else null
	if it == null or it.tool != "cut":
		Game.tell(user, "You would need a knife.", "warn")
		return true
	var arch := String(target.tags.get("arch", "quad"))
	var power := float(target.tags.get("power", 1.0))
	var secs := 4.0 * Skills.speed(user, "beastlore")
	DoAfter.start(user, target, secs, func(ok: bool):
		if not ok or not is_instance_valid(target) or target.removed:
			return
		var skill := Skills.frac(user, "beastlore")
		var got := 0
		for row in SkyMobs._harvest_table(arch):
			var chance := float(row[1]) * (0.4 + skill) * (0.7 + power * 0.3)
			var n := 0
			while chance > 0.0:
				if Game.rng.randf() < minf(1.0, chance):
					n += 1
				chance -= 1.0
			for _i in n:
				if Proto.has(String(row[0])):
					var made := Proto.spawn(String(row[0]), user.root_cell())
					if made != null:
						Economy.deliver(user, made)
					got += 1
		Skills.add_xp(user, "beastlore", 18.0 * power)
		Game.tell(user, "[color=#6ad88a]You take %d thing%s off it.[/color]" % [got, "" if got == 1 else "s"] if got > 0
			else "There was nothing usable left.", "good" if got > 0 else "info")
		Fx.blood(target.cell)
		target.destroy())
	return true
