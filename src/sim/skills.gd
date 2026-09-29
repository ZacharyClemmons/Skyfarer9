class_name Skills extends RefCounted
## Skills and attributes that level up with use, after Burgerstation's experience system
## (code/_core/datum/experience): every skill and attribute has XP, levels run 1-100 on a
## power curve, and doing things earns XP in the skill used. Each skill feeds a share of
## its XP to its attribute, so a brawler grows stronger and a chemist sharper.
## Levels scale how fast and how well you work, and how hard you hit and how well you
## defend. Your own character's XP is kept in their save slot between shifts.

const MAX_LEVEL := 100
## level L needs ((L-1) * mult) ^ power XP (Burgerstation: level_to_xp)
const SKILL_POWER := 1.6
const SKILL_MULT := 3.0
const ATTR_POWER := 1.6
const ATTR_MULT := 4.5
const ATTR_SHARE := 0.3 # of skill XP also goes to the skill's attribute

const ATTRIBUTES := {
	"strength": {"name": "Strength", "desc": "Melee and unarmed damage, dragging and prying."},
	"dexterity": {"name": "Dexterity", "desc": "Throwing accuracy, and working quickly with your hands."},
	"agility": {"name": "Agility", "desc": "Dodging, stamina recovery, and footwork."},
	"endurance": {"name": "Endurance", "desc": "Maximum stamina, and shrugging off cold and pain."},
	"intelligence": {"name": "Intelligence", "desc": "Science, medicine, chemistry and machines."},
	"charisma": {"name": "Charisma", "desc": "How much people like and listen to you."},
}

const SKILLS := {
	# ---------------------------------------------------------------- combat
	"melee": {"name": "Melee", "attr": "strength", "desc": "Fighting with weapons. More damage and faster recovery between swings."},
	"unarmed": {"name": "Unarmed", "attr": "strength", "desc": "Punching and shoving. Harder, more reliable punches."},
	"block": {"name": "Block", "attr": "endurance", "desc": "Turning a blow with a held shield or weapon."},
	"evasion": {"name": "Evasion", "attr": "agility", "desc": "Sidestepping attacks entirely."},
	"throwing": {"name": "Throwing", "attr": "dexterity", "desc": "Accuracy and force of thrown things - harpoons included."},
	"armor": {"name": "Armour", "attr": "endurance", "desc": "Making the most of the armour you wear instead of being slowed by it."},
	"marksman": {"name": "Marksmanship", "attr": "dexterity", "desc": "Held firearms: aim drift, reload speed and the odds of a clean hit."},
	# ---------------------------------------------------------------- the ship
	"airmanship": {"name": "Airmanship", "attr": "agility", "desc": "Flying her. Tighter turns, a higher cruise and less fuel burnt getting there."},
	"rigging": {"name": "Rigging", "attr": "dexterity", "desc": "Sails, lines and lift-cell envelopes. Better trim, faster set, patched envelopes."},
	"gunnery": {"name": "Gunnery", "attr": "dexterity", "desc": "Ship guns: reload, spread and how much of a broadside actually lands."},
	"navigation": {"name": "Navigation", "attr": "intelligence", "desc": "Charts and the weather. See further, read fronts earlier, chart what you find."},
	"shipwright": {"name": "Shipwright", "attr": "strength", "desc": "Hulls and fittings. Build faster, waste less, and fit the heavy modules at all."},
	# ---------------------------------------------------------------- gathering
	"mining": {"name": "Mining", "attr": "strength", "desc": "Breaking rock. Faster swings and more ore out of the same vein."},
	"woodcutting": {"name": "Woodcutting", "attr": "strength", "desc": "Felling sky-timber. Better yields, and the hard woods at all."},
	"foraging": {"name": "Foraging", "attr": "dexterity", "desc": "Herbs, fibre and fungus. Find more, and find the ones worth finding."},
	"skyfishing": {"name": "Skyfishing", "attr": "dexterity", "desc": "Trailing a line off the rail for whatever swims in open air."},
	"salvaging": {"name": "Salvaging", "attr": "intelligence", "desc": "Stripping wrecks. Deeper rolls, intact components, fewer things exploding."},
	"beastlore": {"name": "Beastlore", "attr": "intelligence", "desc": "Skinning and reading creatures. Better parts, and you know what a thing will do before it does it."},
	# ---------------------------------------------------------------- making
	"smithing": {"name": "Smithing", "attr": "strength", "desc": "Metal: plate, frames, barrels and blades."},
	"artifice": {"name": "Artifice", "attr": "intelligence", "desc": "Aetherite work - cells, cores, compasses and things that should not work."},
	"distilling": {"name": "Distilling", "attr": "intelligence", "desc": "Fuel, tonics, and the more interesting mistakes."},
	"cooking": {"name": "Cooking", "attr": "dexterity", "desc": "Better food, faster, and dishes that do something."},
	"construction": {"name": "Construction", "attr": "strength", "desc": "Building and taking apart walls, floors and windows ashore."},
	"engineering": {"name": "Engineering", "attr": "intelligence", "desc": "Repairing machines, wiring and pipes."},
	"atmos": {"name": "Air Works", "attr": "intelligence", "desc": "Gas systems, fires and air."},
	"botany": {"name": "Botany", "attr": "dexterity", "desc": "Growing things, aboard or ashore."},
	# ---------------------------------------------------------------- people and self
	"medical": {"name": "Medicine", "attr": "intelligence", "desc": "Treating wounds, burns and the dying."},
	"chemistry": {"name": "Chemistry", "attr": "intelligence", "desc": "Mixing reagents without incident."},
	"science": {"name": "Science", "attr": "intelligence", "desc": "Experiments, research, and identifying what you just found."},
	"social": {"name": "Social", "attr": "charisma", "desc": "Talking people round."},
	"trading": {"name": "Trading", "attr": "charisma", "desc": "Buying low. Every mark you do not spend is a mark you keep."},
	"athletics": {"name": "Athletics", "attr": "agility", "desc": "Climbing, ledge-grabs, sprinting, and not falling off things."},
	"survival": {"name": "Survival", "attr": "endurance", "desc": "Cold, thin air, hunger, and the long walk home."},
}

## How the skills screen groups them.
const GROUPS := [
	["Combat", Color("#e8645a"), ["melee", "unarmed", "marksman", "throwing", "block", "evasion", "armor"]],
	["Airmanship", Color("#7fd4ff"), ["airmanship", "rigging", "gunnery", "navigation", "shipwright"]],
	["Gathering", Color("#6ad88a"), ["mining", "woodcutting", "foraging", "skyfishing", "salvaging", "beastlore"]],
	["Artisan", Color("#e8a83a"), ["smithing", "artifice", "distilling", "cooking", "construction", "engineering", "atmos", "botany"]],
	["Wits & Wind", Color("#c88ae8"), ["medical", "chemistry", "science", "social", "trading", "athletics", "survival"]],
]
const ATTR_COLORS := {"strength": Color("#e8645a"), "dexterity": Color("#e8c85a"), "agility": Color("#6ad88a"),
	"endurance": Color("#e8a83a"), "intelligence": Color("#5ab8e8"), "charisma": Color("#c88ae8")}

## Old saves and job data used a single "combat" skill, plus a couple of older names.
const ALIASES := {"combat": "melee", "shooting": "marksman", "piloting": "airmanship"}

static func level_to_xp(level: int, mult := SKILL_MULT, power := SKILL_POWER) -> float:
	return ceilf(pow(maxf(0.0, level - 1.0) * mult, power))

static func xp_to_level(xp: float, mult := SKILL_MULT, power := SKILL_POWER) -> int:
	return clampi(int(floor(pow(maxf(xp, 0.0), 1.0 / power) / mult)) + 1, 1, MAX_LEVEL)

static func _mob(ent: Entity) -> CMob:
	if ent == null or not is_instance_valid(ent):
		return null
	return ent.c(&"mob")

## Level 1-100.
static func level(ent: Entity, skill: String) -> int:
	var m := _mob(ent)
	if m == null:
		return 1
	skill = ALIASES.get(skill, skill)
	return xp_to_level(m.xp.get(skill, 0.0))

static func attr_level(ent: Entity, attr: String) -> int:
	var m := _mob(ent)
	if m == null:
		return 1
	return xp_to_level(m.attr_xp.get(attr, 0.0), ATTR_MULT, ATTR_POWER)

## 0-10, for the older formulas that were written against 0-10 skills.
static func get_skill(ent: Entity, skill: String) -> int:
	return int(level(ent, skill) / 10)

## Duration multiplier for a task: skilled people are faster (0.5x at 100, 1.5x at 1).
static func speed(ent: Entity, skill: String) -> float:
	var s := clampf(1.5 - level(ent, skill) * 0.01, 0.5, 1.5)
	var dex := attr_level(ent, "dexterity") if skill in ["engineering", "construction", "cooking", "botany", "medical"] else 1
	return s * (1.0 - dex * 0.001)

## Starting XP for a level (used for job baselines and NPCs).
static func set_level(ent: Entity, skill: String, lvl: int) -> void:
	var m := _mob(ent)
	if m == null:
		return
	skill = ALIASES.get(skill, skill)
	m.xp[skill] = maxf(m.xp.get(skill, 0.0), level_to_xp(lvl))

static func set_attr_level(ent: Entity, attr: String, lvl: int) -> void:
	var m := _mob(ent)
	if m:
		m.attr_xp[attr] = maxf(m.attr_xp.get(attr, 0.0), level_to_xp(lvl, ATTR_MULT, ATTR_POWER))

## Earn XP by doing. Announces level-ups to the player.
static func add_xp(ent: Entity, skill: String, amount: float) -> void:
	var m := _mob(ent)
	if m == null or amount <= 0.0:
		return
	var h: CHealth = ent.c(&"health")
	if h and h.dead:
		return
	skill = ALIASES.get(skill, skill)
	if not SKILLS.has(skill):
		return
	var before := xp_to_level(m.xp.get(skill, 0.0))
	m.xp[skill] = m.xp.get(skill, 0.0) + amount
	var after := xp_to_level(m.xp[skill])
	if ent == Game.player:
		Bus.xp_gained.emit(ent, skill, amount)
	if after > before and ent == Game.player:
		Game.tell(ent, "[b]Your %s skill is now level %d.[/b]" % [SKILLS[skill]["name"], after], "good")
		Sfx.play_ui("ui_select", 0.5, 1.2)
		Bus.skill_up.emit(ent, skill, after)
	var attr: String = SKILLS[skill]["attr"]
	var ab := xp_to_level(m.attr_xp.get(attr, 0.0), ATTR_MULT, ATTR_POWER)
	m.attr_xp[attr] = m.attr_xp.get(attr, 0.0) + amount * ATTR_SHARE
	var aa := xp_to_level(m.attr_xp[attr], ATTR_MULT, ATTR_POWER)
	if aa > ab and ent == Game.player:
		Game.tell(ent, "[b]You feel your %s improve (%d).[/b]" % [ATTRIBUTES[attr]["name"].to_lower(), aa], "good")
		Bus.skill_up.emit(ent, attr, aa)

## Progress 0..1 through the current level, for the skills window.
static func progress(xp: float, mult := SKILL_MULT, power := SKILL_POWER) -> float:
	var l := xp_to_level(xp, mult, power)
	if l >= MAX_LEVEL:
		return 1.0
	var a := level_to_xp(l, mult, power)
	var b := level_to_xp(l + 1, mult, power)
	return clampf((xp - a) / maxf(1.0, b - a), 0.0, 1.0)

## XP for things the world already announces on the bus (connected by Main).
const STIMULUS_XP := {
	"repaired": ["engineering", 18.0], "deconstruct": ["construction", 10.0], "treated": ["medical", 16.0],
	"rescue": ["medical", 30.0], "cured": ["medical", 25.0], "mined": ["mining", 6.0], "cleaned": ["survival", 1.0],
	"chem_reaction": ["chemistry", 10.0], "cuffed": ["unarmed", 10.0], "vermin_killed": ["melee", 4.0], "hug": ["social", 3.0],
	"gift": ["social", 4.0],
}

# ------------------------------------------------------------------ mastery helpers
## The total of every skill level: the number a skyfarer quotes in a tavern.
static func total_level(ent: Entity) -> int:
	var t := 0
	for s in SKILLS:
		t += level(ent, s)
	return t

## Does this character meet a {skill: level} requirement? Returns "" or the first shortfall.
static func shortfall(ent: Entity, reqs: Dictionary) -> String:
	for s in reqs:
		var need := int(reqs[s])
		if level(ent, s) < need:
			return "%s %d" % [String(SKILLS.get(s, {}).get("name", s)), need]
	return ""

static func meets(ent: Entity, reqs: Dictionary) -> bool:
	return shortfall(ent, reqs) == ""

static func req_text(reqs: Dictionary) -> String:
	var parts := []
	for s in reqs:
		parts.append("%s %d" % [String(SKILLS.get(s, {}).get("name", s)), int(reqs[s])])
	return ", ".join(parts)

## 0..1 mastery, the shape most formulas want: level 1 is 0.0, level 100 is 1.0.
static func frac(ent: Entity, skill: String) -> float:
	return clampf((level(ent, skill) - 1) / 99.0, 0.0, 1.0)

## How many units a gathering action yields. Never below one, and the curve is deliberately
## gentle: a level-90 miner gets about three times a novice's ore, not thirty times.
static func yield_roll(ent: Entity, skill: String, base := 1.0) -> int:
	var expect := base * (1.0 + frac(ent, skill) * 2.0)
	var whole := int(floor(expect))
	if Game.rng.randf() < expect - float(whole):
		whole += 1
	return maxi(1, whole)

## A 0..1 chance that rises with skill, for "did you get the rare thing" rolls.
static func chance(ent: Entity, skill: String, at_one: float, at_hundred: float) -> float:
	return lerpf(at_one, at_hundred, frac(ent, skill))

static func on_stimulus(info: Dictionary) -> void:
	var a = info.get("actor")
	if a == null or not is_instance_valid(a) or not (a is Entity) or not a.has_c(&"mob"):
		return
	var r = STIMULUS_XP.get(info.get("type", ""))
	if r != null:
		add_xp(a, r[0], r[1])
