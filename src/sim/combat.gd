class_name Combat extends RefCounted
## Melee, punches, kicks, shoves and blocking, ported from /tg/station:
## _onclick/item_attack.dm (attacked_by, attack_effects), human_defense.dm (check_block),
## _species.dm (harm, stagger_combo, disarm), living_defense.dm (disarm/shove),
## mob_helpers.dm (ran_zone / get_random_valid_zone).
##
##  - attacks have a cooldown (CLICK_CD_MELEE = 0.8 s unless the item says otherwise)
##  - you hit the part you aim at 80% of the time (90% if they're lying down), otherwise
##    a weighted random part (limbs 4, head and chest 1)
##  - armour is per zone, added up over what covers it, capped at 90, and reduced by
##    armour penetration: 100 * (armour - pen) / (100 - pen)
##  - held items block with their block_chance, minus damage / 3, minus half of any
##    armour penetration above the blocker's own
##  - punches roll 5-10 (kicks at someone lying down 7-15), miss 20 - accuracy +
##    (own brute + burn) / 2 percent (capped at 80), and never miss someone staggered or
##    lying down; punching a staggered, hurt target rolls tg's stagger combo
##  - shoves: into a wall or someone knocks them down 2 s and dazes them; a dazed,
##    knocked-down target gets kicked onto their side; otherwise they stagger 3 s
##  - stamina: tg staminaloss up to 120, stamcrit at 100, and it all comes back 10 s
##    after the last stamina damage

## Body parts: Burgerstation's targetable organs (head, torso, groin, arms, hands, legs,
## feet) plus tg's precise eyes and mouth.
const ZONES := ["head", "eyes", "mouth", "chest", "groin", "l_arm", "r_arm", "l_hand", "r_hand", "l_leg", "r_leg", "l_foot", "r_foot"]
const ZONE_NAMES := {"head": "head", "eyes": "eyes", "mouth": "mouth", "chest": "chest", "groin": "groin", "l_arm": "left arm", "r_arm": "right arm",
	"l_hand": "left hand", "r_hand": "right hand", "l_leg": "left leg", "r_leg": "right leg", "l_foot": "left foot", "r_foot": "right foot"}
## Where a miss on a small part lands instead (tg: precise zones fall back to the head).
const ZONE_PARENT := {"eyes": "head", "mouth": "head", "l_hand": "l_arm", "r_hand": "r_arm", "l_foot": "l_leg", "r_foot": "r_leg"}
## Base chance to hit what you aim at: big parts are easy, small ones hard.
const ZONE_HIT := {"chest": 85.0, "groin": 75.0, "head": 72.0, "l_arm": 72.0, "r_arm": 72.0, "l_leg": 72.0, "r_leg": 72.0,
	"l_hand": 55.0, "r_hand": 55.0, "l_foot": 55.0, "r_foot": 55.0, "eyes": 40.0, "mouth": 45.0}
## Each part on the 32 x 48 paper doll (matches tools/artgen/ui.py DOLL_ZONES), small
## parts first so they win where they overlap their parent.
const ZONE_RECTS := [
	["eyes", Rect2(12, 4, 8, 4)], ["mouth", Rect2(13, 8, 6, 3)], ["head", Rect2(10, 1, 12, 11)],
	["r_hand", Rect2(4, 25, 6, 6)], ["l_hand", Rect2(22, 25, 6, 6)], ["r_foot", Rect2(8, 42, 8, 5)], ["l_foot", Rect2(16, 42, 8, 5)],
	["r_arm", Rect2(4, 12, 6, 13)], ["l_arm", Rect2(22, 12, 6, 13)], ["chest", Rect2(10, 12, 12, 14)], ["groin", Rect2(10, 26, 12, 4)],
	["r_leg", Rect2(10, 30, 6, 12)], ["l_leg", Rect2(16, 30, 6, 12)],
]
const ZONE_CENTER := {"head": Vector2(15.5, 3), "eyes": Vector2(15.5, 5.5), "mouth": Vector2(15.5, 9), "chest": Vector2(15.5, 18), "groin": Vector2(15.5, 27.5),
	"r_arm": Vector2(6.5, 18), "l_arm": Vector2(24.5, 18), "r_hand": Vector2(6.5, 27.5), "l_hand": Vector2(24.5, 27.5),
	"r_leg": Vector2(12.5, 36), "l_leg": Vector2(18.5, 36), "r_foot": Vector2(11.5, 44), "l_foot": Vector2(19.5, 44)}

static func zone_at(p: Vector2) -> String:
	for zr in ZONE_RECTS:
		if (zr[1] as Rect2).has_point(p):
			return zr[0]
	# outside the figure: the nearest part
	var best := "chest"
	var bd := 1e9
	for z in ZONE_CENTER:
		var d: float = p.distance_squared_to(ZONE_CENTER[z])
		if d < bd:
			bd = d
			best = z
	return best
const CLICK_CD_MELEE := 0.8
const ARMOR_MAX_BLOCK := 90.0
const STAGGER_TIME := 3.0
const SHOVE_KNOCKDOWN := 2.0

## Which zones each worn slot covers (tg: body_parts_covered).
const COVERS := {
	"head": ["head"], "mask": ["mouth"], "eyes": ["eyes"], "suit": ["chest", "groin", "l_arm", "r_arm"],
	"uniform": ["chest", "groin", "l_arm", "r_arm", "l_leg", "r_leg"], "gloves": ["l_hand", "r_hand"],
	"shoes": ["l_foot", "r_foot"],
}

# ------------------------------------------------------------------ helpers
static func _mob(e: Entity) -> CMob:
	return e.c(&"mob") if e else null

static func ready_to_attack(user: Entity) -> bool:
	var m := _mob(user)
	return m == null or Game.time >= m.next_attack

static func _set_cooldown(user: Entity, item: Entity) -> void:
	var m := _mob(user)
	if m == null:
		return
	var cd := CLICK_CD_MELEE
	if item and item.has_c(&"item"):
		cd = item.c(&"item").attack_speed
	m.next_attack = Game.time + cd

## The force an item hits with right now (two-handed weapons need both hands).
static func item_force(user: Entity, item: Entity) -> float:
	var it: CItem = item.c(&"item")
	var f := it.force
	if it.force_wielded > 0.0:
		f = it.force_wielded if wielded(user, item) else it.force
	var wd = item.c(&"welder")
	if wd and wd.lit:
		f = 15.0 # tg: a lit welder is a 15 force burn weapon
	return f

static func wielded(user: Entity, item: Entity) -> bool:
	var it: CItem = item.c(&"item")
	if not it.is_wielded or user == null or not user.has_c(&"inv"):
		return false
	var inv: CInventory = user.c(&"inv")
	var i := inv.hands.find(item)
	return i >= 0 and inv.hands[1 - i] == null

## tg get_demolition_modifier: how much harder (or softer) this hits objects and structures.
## The fire axe only gets its 1.25 wielded; swung one-handed it's 0.8 (fireaxe.dm).
static func demolition(user: Entity, item: Entity) -> float:
	if item == null or not item.has_c(&"item"):
		return 1.0
	var it: CItem = item.c(&"item")
	if item.proto == "fireaxe" and not wielded(user, item):
		return 0.8
	return it.demolition

static func damtype(item: Entity) -> String:
	var wd = item.c(&"welder")
	if wd and wd.lit:
		return "burn"
	return item.c(&"item").damtype

## Summed melee armour over everything covering `zone`, 0-100 (tg getarmor), with the
## Armor skill making the most of it.
## tg getarmor for BULLET or LASER: projectile armour over the zone, 0-100.
static func armor_vs(target: Entity, zone: String, kind: String) -> float:
	var inv: CInventory = target.c(&"inv")
	if inv == null:
		return 0.0
	var a := 0.0
	for slot in COVERS:
		var w: Entity = inv.worn(slot)
		if w and w.has_c(&"clothing") and w.c(&"clothing").covers_zone(zone, slot):
			var clothing: CClothing = w.c(&"clothing")
			a += clothing.bullet_armor if kind == "bullet" else (clothing.energy_armor if kind == "energy" else clothing.laser_armor)
	return minf(a, ARMOR_MAX_BLOCK)

static func armor(target: Entity, zone: String) -> float:
	var inv: CInventory = target.c(&"inv")
	if inv == null:
		return 0.0
	var a := 0.0
	for slot in COVERS:
		var w: Entity = inv.worn(slot)
		if w and w.has_c(&"clothing") and w.c(&"clothing").covers_zone(zone, slot):
			a += w.c(&"clothing").melee_armor()
	return a

static func penetrate(armour: float, pen: float) -> float:
	# tg PENETRATE_ARMOUR
	if pen >= 100.0:
		return 0.0
	return maxf(0.0, 100.0 * (armour - pen) / (100.0 - pen))

## tg get_random_valid_zone(zone_selected, 80 or 90 if they're lying down): the aimed zone,
## or a weighted random bodypart they still have (limbs 4, head and chest 1).
static func pick_zone(user: Entity, target: Entity, base_prob := 80.0) -> String:
	var um := _mob(user)
	var aimed: String = um.aimed_zone() if um else "chest"
	var tm := _mob(target)
	if tm and tm.is_lying() and base_prob == 80.0:
		base_prob = 90.0
	var th: CHealth = target.c(&"health")
	if Game.rng.randf() * 100.0 < base_prob and not (th and th.missing.has(Body.part_of(aimed))):
		return aimed
	var w := {}
	for p in Body.PARTS:
		if th and th.missing.has(p):
			continue
		w[Body.PARTS[p]["zones"][0]] = 1.0 if p in ["head", "chest"] else 4.0
	return Body._pick_weight(w)

# ------------------------------------------------------------------ melee
## tg /mob/living/attacked_by: an item hitting someone.
static func melee(user: Entity, target: Entity, item: Entity) -> void:
	if not ready_to_attack(user):
		return
	_set_cooldown(user, item)
	var th: CHealth = target.c(&"health")
	if th == null:
		_hit_object(user, target, item)
		return
	var um := _mob(user)
	# Skyfarer: you cannot hit the people who run a port. Not "they hit back", not "the
	# watch comes" — the swing does not happen. Meridian is the one place in this game
	# where nothing can go wrong, and an accidental click in a shop must never be the
	# thing that takes that away. They will tell you off for trying.
	if target.tags.get("protected", false):
		var vend2: CVendor = target.c(&"vendor")
		if vend2 != null:
			vend2.on_shoved(user)
		else:
			Game.tell(user, "[color=#8aa0b4]%s steps back out of reach. Not here.[/color]" % target.display_name, "warn")
		return
	# tg TRAIT_PACIFISM (the pacifism trauma): no hurting the living; psychotic brawling is
	# a pacifist_style martial art, so bare hands still gamble
	var uhp: CHealth = user.c(&"health")
	if uhp and not uhp.traumas.is_empty() and Traumas.pacifist(uhp) and not th.dead:
		if item != null and item_force(user, item) > 0.0:
			Game.tell(user, "You don't want to harm other living beings!", "warn")
			return
		if item == null and not Traumas.has(uhp, "psychotic_brawling"):
			Game.tell(user, "You don't want to harm %s!" % target.display_name, "warn")
			return
	if um and target.cell != user.cell:
		um.face(Defs.dir_from_vec(target.cell - user.cell))
	if user.has_c(&"mob"):
		user.c(&"mob").lunge(target.cell)
	if target != user:
		if item:
			Fx.item_flick(item, user.position + Vector2(0, -16), target.position + Vector2(0, -16))
		else:
			Fx.attack_effect(target.position + Vector2(0, -16), "punch")
	if item == null:
		_punch(user, target)
		return
	var it: CItem = item.c(&"item")
	var force := item_force(user, item)
	var zone := pick_zone(user, target) if user != target else (um.aimed_zone() if um else "chest")
	var kind := damtype(item)
	var verb := it.attack_verb
	Game.visible_message(target.cell, "%s %s %s in the %s with %s!" % [user.display_name, verb, target.display_name, _zone_of(target, zone), item.display_name], "combat")
	var arm := minf(penetrate(armor(target, zone), it.armour_penetration), ARMOR_MAX_BLOCK)
	if arm >= 1.0 and target == Game.player:
		Game.tell(target, "Your armor %s your %s!" % ["has protected" if arm >= 100.0 else "has softened a hit to", ZONE_NAMES[zone]], "warn")
	if force <= 0.0:
		return
	# tg check_block happens before the damage
	if user != target and check_block(target, item.display_name, force, it.armour_penetration):
		return
	var dealt := force * (1.0 - arm / 100.0)
	_apply_hit(user, target, dealt, kind, zone, it.sharpness, it.wound_bonus, force, arm, it.exposed_wound_bonus, item)
	# tg: a good swing of a baseball bat sends them flying back
	if item.proto == "baseball_bat" and dealt >= 8.0 and Game.rng.randf() < 0.35:
		var tm2 := _mob(target)
		if tm2:
			var away: Vector2i = target.cell - user.cell
			away = Vector2i(signi(away.x), signi(away.y))
			if tm2.push(away):
				tm2.push(away)
			Game.visible_message(target.cell, "%s is knocked back by the swing!" % target.display_name, "combat")
	Sfx.play("hit", target.cell)
	after_attack(user, item)
	Skills.add_xp(user, "melee", dealt)
	_crime(user, target)

## tg human/attack_hulk
static func _hulk_smash(user: Entity, target: Entity) -> bool:
	var th: CHealth = target.c(&"health")
	var uh: CHealth = user.c(&"health")
	if uh and not uh.traumas.is_empty() and Traumas.pacifist(uh):
		Game.tell(user, "You don't want to hurt %s!" % target.display_name, "warn")
		return true
	var dn: CDna = user.c(&"dna")
	var m: Mutation = null
	if dn:
		for mm in dn.mutations:
			if mm.id.begins_with("hulk"):
				m = mm
	if m:
		var delay := 2.5 if m.id == "hulk_wizardly" else 5.0
		if Game.time > m.data.get("last_scream", -99.0) + delay:
			m.data["last_scream"] = Game.time
			user.c(&"mob").say("WAAAAAAAAAAAAAAGH!")
	var verb: String = ["smash", "pummel"][Game.rng.randi() % 2]
	if check_block(target, "the %sing" % verb, 15.0, 0.0):
		return true
	Fx.attack_effect(target.position + Vector2(0, -16), "smash")
	Game.visible_message(target.cell, "[b]%s %sed %s![/b]" % [user.display_name, verb, target.display_name], "combat")
	Game.tell(user, "You %s %s!" % [verb, target.display_name], "bad")
	th.hurt_zone(pick_zone(user, target), 15.0, "brute", user, "", 10.0)
	Sfx.play("punch", target.cell, 1.2)
	_crime(user, target)
	return true

## tg human/attack_paw: a monkey's bite (75% to land, 1-3 brute through armour; a mask
## over the mouth stops it)
static func _bite(user: Entity, target: Entity) -> void:
	var th: CHealth = target.c(&"health")
	var uh: CHealth = user.c(&"health")
	var uinv: CInventory = user.c(&"inv")
	if uh and uh.missing.has("head"):
		return
	if uinv and uinv.worn("mask") != null:
		Game.tell(user, "You can't bite with your mouth covered!", "warn")
		return
	if check_block(target, "%s's bite" % user.display_name, 1.0, 0.0):
		return
	Fx.attack_effect(target.position + Vector2(0, -16), "bite")
	if not Body.prob(75):
		Game.visible_message(target.cell, "%s's bite misses %s!" % [user.display_name, target.display_name], "combat_warn")
		return
	Sfx.play("bite", target.cell, 0.6)
	Game.visible_message(target.cell, "[b]%s bites %s![/b]" % [user.display_name, target.display_name], "combat")
	var zone: String = ["chest", "l_hand", "r_hand", "l_leg", "r_leg"][Game.rng.randi() % 5]
	if not ZONE_NAMES.has(zone):
		zone = ["chest", "l_arm", "r_arm", "l_leg", "r_leg"][Game.rng.randi() % 5]
	var dmg := float(Game.rng.randi_range(1, 3))
	var arm := minf(armor(target, zone), ARMOR_MAX_BLOCK)
	th.hurt_zone(zone, dmg * (1.0 - arm / 100.0), "brute", user)
	_venom(user, target)
	_crime(user, target)

## tg /datum/element/venomous (the venomous strikes mutation): 3 x power units of toxin
static func _venom(user: Entity, target: Entity) -> void:
	var dn: CDna = user.c(&"dna")
	if dn == null or target == user:
		return
	var m := dn.get_mutation("venomous_strikes")
	if m and target.has_c(&"health"):
		Chem.affect_mob({"toxin": 3.0 * m.pwr()}, target, 1.0)

static func _paw_disarm(user: Entity, target: Entity) -> void:
	var th: CHealth = target.c(&"health")
	var tinv: CInventory = target.c(&"inv")
	var held: Entity = tinv.active_item() if tinv else null
	user.c(&"mob").lunge(target.cell)
	if held:
		tinv.drop(held)
		Sfx.play("slash", target.cell, 0.4)
		Game.visible_message(target.cell, "[b]%s disarmed %s![/b]" % [user.display_name, target.display_name], "combat")
	elif user != Game.player or Body.prob(5):
		Sfx.play("pierce", target.cell, 0.4)
		if th.has_status("knockdown") and not th.has_status("paralyzed"):
			th.paralyze(4.0)
			Game.visible_message(target.cell, "[b]%s pins %s down![/b]" % [user.display_name, target.display_name], "combat")
		else:
			th.knockdown(3.0)
			Game.visible_message(target.cell, "[b]%s tackles %s down![/b]" % [user.display_name, target.display_name], "combat")
	_crime(user, target)

static func _zone_of(target: Entity, zone: String) -> String:
	return ZONE_NAMES.get(zone, zone)

## tg /datum/species/proc/harm: a punch, or a kick at someone lying down.
static func _punch(user: Entity, target: Entity) -> void:
	var th: CHealth = target.c(&"health")
	var uh: CHealth = user.c(&"health")
	GeneFx.on_attack(user) # tg COMSIG_LIVING_UNARMED_ATTACK (chameleons flicker back)
	var mineral_bonus := RockMetabolism.mining_bonus(user, target)
	if mineral_bonus > 0.0:
		th.adjust("brute", mineral_bonus, user)
	if Traits.has(user, "animal_body"):
		var damage := float(Game.rng.randi_range(15, 18)) if Species.of(user) == "gorilla" else 2.0
		if Species.of(user) == "corgi": damage = float(Game.rng.randi_range(5, 10))
		th.hurt_zone(pick_zone(user, target), damage, "brute", user)
		Game.visible_message(target.cell, "%s attacks %s!" % [user.display_name, target.display_name], "combat")
		return
	# tg hulk/on_attack_hand -> attack_hulk: 15 brute, and a WAAAGH every 5 s
	if target != user and Traits.has(user, "hulk") and _hulk_smash(user, target):
		return
	# tg primate brain get_attacking_limb: a monkey that can't use tools bites (attack_paw)
	if target != user and Genetics.is_monkey(user) and not Traits.has(user, "advancedtooluser"):
		_bite(user, target)
		return
	if uh and target != user and Traumas.has(uh, "psychotic_brawling") and psycho_attack(user, target, false):
		return
	var tm := _mob(target)
	var um := _mob(user)
	# tg brain get_attacking_limb: kick a downed target with a leg you still have
	var kicking: bool = tm != null and tm.is_lying() and uh and Body.usable_legs(uh) > 0
	var verb := "kick" if kicking else "punch"
	var lo := 7 if kicking else 5
	var hi := 15 if kicking else 10
	var accuracy := 15.0 if kicking else 10.0
	if Traits.has(user, "strength"):
		hi += 2 # tg TRAIT_STRENGTH raises the unarmed damage cap
	var damage := float(Game.rng.randi_range(lo, hi))
	if not kicking and user.get_meta("rock_buff", "") == "titanium": damage += 3.0
	var staggered := th.has_status("staggered")
	var tpm: CMob = tm.pulled_by.c(&"mob") if tm and tm.pulled_by and tm.pulled_by.has_c(&"mob") else null
	var grappled := tpm != null and tpm.grab_state >= 1
	if grappled and not kicking:
		damage = floorf(damage * 1.5) # arm unarmed_pummeling_bonus
		accuracy = floorf(accuracy * 1.5)
	var drunk := uh.drunk if uh else 0.0
	if drunk >= 60.0:
		accuracy = -accuracy
	elif drunk >= 30.0:
		accuracy *= 1.2
	var zone := pick_zone(user, target)
	var miss := 0.0
	if not (tm and tm.is_lying()) and not staggered:
		var own := (uh.brute + uh.burn) if uh else 0.0
		miss = clampf(20.0 - accuracy + own / 2.0, 0.0, 80.0)
	if Body.prob(miss):
		Game.visible_message(target.cell, "%s's %s misses %s!" % [user.display_name, verb, target.display_name], "combat_warn")
		Sfx.play("swing", user.cell)
		_crime(user, target)
		return
	if check_block(target, "%s's %s" % [user.display_name, verb], damage, 0.0):
		return
	var arm := minf(armor(target, zone), ARMOR_MAX_BLOCK)
	var tdrunk := th.drunk
	if tdrunk >= 60.0:
		arm *= 0.5
	elif tdrunk >= 30.0:
		arm += 10.0
	var final_arm := arm
	if kicking or grappled:
		final_arm -= accuracy # kicks and grappled punches bypass armour a little
	var verbs := "kicks" if kicking else ("pummels" if grappled else "punches")
	Game.visible_message(target.cell, "%s %s %s!" % [user.display_name, verbs, target.display_name], "combat")
	var target_hurt := th.brute + th.burn
	_apply_hit(user, target, damage * (1.0 - clampf(final_arm, 0.0, 100.0) / 100.0), "brute", zone, "", 0.0, damage)
	_venom(user, target)
	Sfx.play("punch", target.cell)
	Skills.add_xp(user, "unarmed", damage)
	_crime(user, target)
	# tg stagger_combo: a hurt, staggered target can be sent reeling
	if th.dead:
		return
	var effective_armor := maxf(arm, 40.0) - accuracy
	if staggered and target_hurt >= clampf(effective_armor, 0.0, 200.0):
		_stagger_combo(user, target, verb, accuracy, arm)

static func _stagger_combo(user: Entity, target: Entity, verb: String, accuracy: float, armor_block: float) -> void:
	var th: CHealth = target.c(&"health")
	var roll := Game.rng.randi_range(-20, 20) + accuracy - armor_block
	var who := target.display_name
	if roll <= 0:
		th.adjust_status("staggered", 1.0, 10.0)
		Game.visible_message(target.cell, "%s's %s briefly winds %s!" % [user.display_name, verb, who], "combat_warn")
	elif roll <= 10:
		th.adjust_status("eye_blur", 5.0, 10.0)
		Game.visible_message(target.cell, "%s's %s hits %s so hard, their eyes water! Ouch!" % [user.display_name, verb, who], "combat_warn")
	elif roll <= 30:
		th.adjust_status("dizziness", 5.0, 10.0)
		th.adjust_status("eye_blur", 5.0, 10.0)
		th.adjust_status("confusion", 5.0, 10.0)
		Game.visible_message(target.cell, "%s's %s hits %s so hard, they are sent reeling in agony! Damn!" % [user.display_name, verb, who], "combat")
	elif roll <= 40:
		th.adjust_status("dizziness", 5.0, 10.0)
		th.adjust_status("confusion", 5.0, 10.0)
		th.adjust_status("temp_blind", 5.0, 10.0)
		Game.visible_message(target.cell, "%s's %s hits %s so hard, they are sent reeling blindly in agony! Goddamn!" % [user.display_name, verb, who], "combat")
	elif roll <= 45:
		th.knockdown(4.0 * (100.0 - clampf(armor_block, 0.0, 100.0)) / 100.0)
		Game.visible_message(target.cell, "%s's %s hits %s so hard, you knock them off their feet! Holy shit!" % [user.display_name, verb, who], "combat")
	else:
		th.knockdown(4.0 * (100.0 - clampf(armor_block, 0.0, 100.0)) / 100.0)
		th.hurt_zone(pick_zone(user, target), 5.0 * (100.0 - clampf(armor_block, 0.0, 100.0)) / 100.0, "brute", user, "", accuracy * 2.0)
		Game.visible_message(target.cell, "%s's %s hits %s so hard, you hit them off their feet with a loud crunch! Fucking hell!" % [user.display_name, verb, who], "combat")

## tg /mob/living/carbon/human/check_block: any held item with a block_chance can block,
## at block_chance - (pen - its own pen) / 2 - damage / 3.
static func check_block(target: Entity, what: String, damage: float, pen: float, pass_glass := false) -> bool:
	var inv: CInventory = target.c(&"inv")
	var th: CHealth = target.c(&"health")
	if inv == null or th == null or th.dead:
		return false
	var modifier := roundf(damage / -3.0)
	for h in inv.hands:
		if h == null or not h.has_c(&"item") or h.has_c(&"clothing"):
			continue
		if pass_glass and h.tags.get("shield_transparent", false): continue
		var ci: CItem = h.c(&"item")
		var bc := ci.block_chance - clampf((pen - ci.armour_penetration) / 2.0, 0.0, 100.0) + modifier
		if Body.prob(bc):
			Game.visible_message(target.cell, "%s blocks %s with %s!" % [target.display_name, what, h.the()], "combat_warn")
			Sfx.play("hit", target.cell, 0.4)
			Skills.add_xp(target, "block", damage)
			return true
	return false

## Damage to a zone (tg apply_damage -> bodypart receive_damage, which rolls the wounds),
## then tg /mob/living/carbon/human/attack_effects (item_attack.dm).
static func _apply_hit(user: Entity, target: Entity, dmg: float, kind: String, zone: String, sharp: String, wound_bonus: float, _raw: float, armor_block := 0.0, exposed_bonus := 0.0, item: Entity = null) -> void:
	var th: CHealth = target.c(&"health")
	var before := th.brute + th.burn
	th.hurt_zone(zone, dmg, kind, user, sharp, wound_bonus, exposed_bonus)
	var done := maxf(0.0, th.brute + th.burn - before)
	if target.removed:
		return
	attack_effects(user, target, done, kind, zone, sharp, armor_block, item)

## tg /mob/living/carbon/human/attack_effects (item_attack.dm): blood on the weapon, the
## floor, the attacker's gloves and clothes and the victim's; blunt blows to the head hurt
## the brain (and may concuss), to the chest knock you down.
static func attack_effects(user: Entity, target: Entity, done: float, kind: String, zone: String, sharp: String, armor_block: float, item: Entity = null) -> void:
	if item == null:
		return # tg: attack_effects is the item attack chain; fists have their own (_punch)
	var th: CHealth = target.c(&"health")
	var part := Body.part_of(zone)
	var bled := false
	if done > 0.0 and kind == "brute" and Blood.can_bleed(th) and not th.missing.has(part) and Body.prob(25.0 + done * 2.0):
		bled = true
		if item:
			Blood.stain_item(item, th)
		Body.splatter(target.cell, 10.0, false, th)
		if user and user.dist_to(target) <= 1 and user != target:
			var things := ["gloves"]
			if done >= 20.0 or (done >= 15.0 and Body.prob(25)):
				things += ["iclothing", "oclothing"]
				if Body.prob(33) and done >= 10.0:
					things.append("feet")
				if Body.prob(33) and done >= 24.0:
					things.append("mask")
				if Body.prob(33) and done >= 30.0:
					things.append("head")
			Blood.add_to_items(user, things, th)
	var out := th.stat() != CHealth.CONSCIOUS or th.in_crit()
	match part:
		"head":
			if bled:
				var things := ["mask", "head"]
				if Body.prob(33):
					things.append("eyes")
				Blood.add_to_items(target, things, th)
			if sharp == "" and kind == "brute":
				if Body.prob(done):
					Organs.apply_damage(th, "brain", 20.0)
					if not out:
						Game.visible_message(target.cell, "%s is knocked senseless!" % target.display_name, "combat")
						Game.tell(target, "[b]You're knocked senseless![/b]", "bad")
						th.set_status_if_lower("confusion", 20.0)
						th.adjust_status("eye_blur", 20.0)
					if Body.prob(10):
						Traumas.gain(th, "concussion")
				else:
					Organs.apply_damage(th, "brain", done * 0.2)
		"chest":
			if bled:
				Blood.add_to_items(target, ["iclothing", "oclothing"], th)
			if not out and sharp == "" and kind == "brute" and Body.prob(done):
				Game.visible_message(target.cell, "%s is knocked down!" % target.display_name, "combat")
				Game.tell(target, "[b]You're knocked down![/b]", "bad")
				th.knockdown(6.0 * (100.0 - clampf(armor_block, 0.0, 100.0)) / 100.0)

static func _hit_object(user: Entity, target: Entity, item: Entity) -> void:
	strike_object(user, target, item)

## tg attack_atom -> obj/attacked_by: hit a door, locker, table or machine. The item's force
## (wielded, if two-handed) times its demolition modifier goes through the object's melee
## armour and deflection; a bare hand is a 5 force punch. Returns the damage dealt.
static func strike_object(user: Entity, target: Entity, item: Entity) -> float:
	var at := target.position + Vector2(0, -16)
	var force := item_force(user, item) if item else 5.0
	var demo := demolition(user, item) if item else 1.0
	# tg obj/attack_hulk: a hulk's bare hands do hulk_damage() (150; grilles 60)
	if item == null and Traits.has(user, "hulk") and user.has_c(&"mob") and user.c(&"mob").combat:
		force = 150.0
		Sfx.play("meteor" if target.has_c(&"blocker") and target.c(&"blocker").dense else "bang", target.cell, 0.8)
	var kind := damtype(item) if item else "brute"
	var ap: float = item.c(&"item").armour_penetration if item else 0.0
	if item:
		Fx.item_flick(item, user.position + Vector2(0, -16), at)
	else:
		Fx.attack_effect(at, "punch")
	object_hit_sound(target, force * demo, kind)
	var where := target.cell
	var nm := target.the()
	var dealt := target.take_damage(force * demo, kind, user, "melee", ap)
	# tg obj/attacked_by message
	var verb: String = item.c(&"item").attack_verb if item else "punches"
	if demo > 1.0 and Game.rng.randf() < dealt * 0.05:
		verb = "pulverises"
	elif demo < 1.0:
		verb = "ineffectively " + verb
	var with := (" with " + item.the()) if item else ""
	Game.visible_message(where, "%s %s %s%s%s" % [user.display_name, verb, nm, with, "." if dealt > 0.0 else ", without leaving a mark!"], "combat_warn")
	if item:
		after_attack(user, item)
	if target.has_c(&"machine") or target.has_c(&"door"):
		Bus.stimulus.emit({"type": "vandalism", "actor": user, "target": target, "cell": where, "loud": 5.0, "illegal": true})
	return dealt

## tg play_attack_sound for objects: a glass door clinks, anything else smashes; a blow with
## no force taps, burns hiss like a welder.
static func object_hit_sound(target: Entity, raw: float, kind: String) -> void:
	if kind == "burn":
		Sfx.play("welder", target.cell)
	elif raw <= 0.0:
		Sfx.play("wall_tap", target.cell, 0.8)
	elif target.has_c(&"door") and target.c(&"door").glass:
		Sfx.play("glass_hit", target.cell, 1.2)
	else:
		Sfx.play("wall_hit", target.cell, 1.2)

## tg afterattack hooks that matter here: a bare-handed glass shard cuts your palm
## (shard afterattack: force x 0.5 to the hand holding it, unless your hands are covered).
static func after_attack(user: Entity, item: Entity) -> void:
	if item == null or item.proto != "glass_shard" or not user.has_c(&"inv") or not user.has_c(&"health"):
		return
	var inv: CInventory = user.c(&"inv")
	if inv.worn("gloves") != null:
		return
	var hand := "l_hand" if inv.hands.find(item) == 0 else "r_hand"
	Game.tell(user, "%s cuts into your hand!" % item.the().capitalize(), "bad")
	user.c(&"health").hurt_zone(hand, item.c(&"item").force * 0.5, "brute", user)

static func _crime(user: Entity, target: Entity) -> void:
	if target.has_c(&"mob"):
		Bus.stimulus.emit({"type": "assault", "actor": user, "target": target, "cell": target.cell, "loud": 6.0, "illegal": not _lawful_force(user, target)})

## Security bringing in a wanted person or breaking up a fight, or someone hitting back at
## whoever is hitting them, isn't a crime.
static func _lawful_force(user: Entity, target: Entity) -> bool:
	var um := _mob(user)
	var ub = user.c(&"brain")
	if um and Jobs.dept(um.job) == "security":
		if SecurityRecords.is_wanted(target.id):
			return true
		if ub and String(ub.goal.get("claim", "")) == "arrest:%d" % target.id:
			return true
	if ub and ub.memory.recent("hurt_me", 20.0).any(func(ep): return ep["actor"] == target.id):
		return true
	return false

# ------------------------------------------------------------------ shove (tg disarm)
## tg /mob/living/proc/disarm: push them a tile. Blocked (wall, table, machine): knocked
## down 2 s and dazed 3 s. Into someone: both go down (them 2 s, the other 1 ds).
## Knocked down and dazed: kicked onto their side, paralysed 3 s. Otherwise staggered 3 s;
## a staggered target drops a gun, a downed one drops whatever they hold.
static func shove(user: Entity, target: Entity) -> void:
	if not ready_to_attack(user) or not user.adjacent(target) or target == user or user.cell == target.cell:
		return
	var uh: CHealth = user.c(&"health")
	if uh and uh.floored():
		return # can_disarm: you have to be standing
	_set_cooldown(user, null)
	var th: CHealth = target.c(&"health")
	var tm := _mob(target)
	if th == null or tm == null:
		return
	if uh and Traumas.has(uh, "psychotic_brawling") and psycho_attack(user, target, false):
		return
	if target.has_c(&"monkeyai"):
		target.c(&"monkeyai").on_attacked(user)
	# tg human/attack_paw right click: a monkey's paws knock the item out of your hand, or
	# (natural monkeys, and 5% of the time for anyone else) tackle you down or pin you
	if Genetics.is_monkey(user) and not Traits.has(user, "advancedtooluser"):
		_paw_disarm(user, target)
		return
	# tg TRAIT_PUSHIMMUNE (hulks): shoves don't move them
	if Traits.has(target, "pushimmune"):
		user.c(&"mob").lunge(target.cell)
		Game.visible_message(target.cell, "%s tries to shove %s, but %s doesn't budge!" % [user.display_name, target.display_name, target.display_name], "combat_warn")
		return
	user.c(&"mob").lunge(target.cell)
	Sfx.play("punch", target.cell, 0.6)
	var d: Vector2i = target.cell - user.cell
	var step := Vector2i(signi(d.x), signi(d.y))
	var dest: Vector2i = target.cell + step
	var map := Game.map
	var into: Entity = null
	for e in Game.at(dest):
		if e.has_c(&"mob") and not e.c(&"mob").is_lying() and e.has_c(&"health"):
			into = e
	var table := false
	for e in Game.at(dest):
		if e.has_c(&"furniture") and e.c(&"furniture").kind == "table":
			table = true
	var blocked := into != null or table or map.blocks_move_static(dest) or map.dense_count[map.idx(dest)] > 0 or tm.buckled != null
	var who := target.display_name
	if not blocked:
		tm.push(step)
	elif into and tm.buckled == null:
		# tg human disarm_collision
		th.knockdown(SHOVE_KNOCKDOWN, 3.0)
		into.c(&"health").knockdown(0.1, 3.0) # SHOVE_KNOCKDOWN_COLLATERAL (1 ds)
		Game.visible_message(target.cell, "%s shoves %s into %s!" % [user.display_name, who, into.display_name], "combat")
		_crime(user, target)
		return
	elif table and tm.buckled == null:
		# tg table: shoved onto it
		if not map.blocks_move_static(dest):
			tm.push(step)
		th.knockdown(SHOVE_KNOCKDOWN, 3.0)
		Game.visible_message(target.cell, "%s shoves %s onto the table!" % [user.display_name, who], "combat")
		_crime(user, target)
		return
	elif tm.buckled == null:
		th.knockdown(SHOVE_KNOCKDOWN, 3.0)
		Game.visible_message(target.cell, "%s shoves %s, knocking them down!" % [user.display_name, who], "combat")
		_crime(user, target)
		return
	# SHOVE_CAN_KICK_SIDE: knocked down, dazed, not paralysed
	if th.has_status("knockdown") and th.has_status("dazed") and not th.has_status("paralyzed") and not th.has_status("no_side_kick"):
		th.paralyze(3.0)
		th.set_status("no_side_kick", 3.6)
		Game.visible_message(target.cell, "%s kicks %s onto their side!" % [user.display_name, who], "combat")
		user.get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(target) and not target.removed:
				th.set_status("knockdown", 0.0))
		_crime(user, target)
		return
	var inv: CInventory = target.c(&"inv")
	var held: Entity = inv.active_item() if inv else null
	var dropped := false
	if held and ((th.has_status("staggered") and held.has_c(&"gadget") and held.c(&"gadget").ranged()) or tm.is_lying()):
		inv.drop(held)
		dropped = true
	if dropped:
		Game.visible_message(target.cell, "%s shoves %s, causing them to drop %s!" % [user.display_name, who, held.the()], "combat")
	else:
		Game.visible_message(target.cell, "%s shoves %s!" % [user.display_name, who], "combat_warn")
	th.adjust_status("staggered", STAGGER_TIME, 10.0)
	Skills.add_xp(user, "unarmed", 3.0)
	_crime(user, target)

## tg /datum/martial_art/psychotic_brawling/psycho_attack: every unarmed move is a gamble.
## Returns false when the normal attack goes ahead (tg MARTIAL_ATTACK_INVALID).
static func psycho_attack(user: Entity, target: Entity, grab_attack: bool) -> bool:
	var th: CHealth = target.c(&"health")
	var uh: CHealth = user.c(&"health")
	var um := _mob(user)
	var tm := _mob(target)
	match Game.rng.randi_range(1, 8):
		1:
			Interact.help_hand(user, target)
			return true
		2:
			if um:
				um.do_emote("cry")
			uh.stun(2.0)
			Game.visible_message(target.cell, "%s cried looking at %s." % [user.display_name, target.display_name], "combat_warn")
			return true
		3:
			if check_block(target, "%s's grab" % user.display_name, 0.0, 0.0):
				return true
			if uh.lying():
				return false
			if um:
				um.start_pulling(target)
				if um.pulling == target:
					var tinv: CInventory = target.c(&"inv")
					if tinv:
						for it in tinv.hands.duplicate():
							if it:
								tinv.drop(it)
					if tm:
						tm.stop_pulling()
					if grab_attack:
						Game.visible_message(target.cell, "%s violently grabs %s!" % [user.display_name, target.display_name], "combat")
						um.grab_state = 1
			return true
		4:
			var dd := float(Game.rng.randi_range(5, 10))
			if check_block(target, "%s's headbutt" % user.display_name, dd, 0.0):
				return true
			if um:
				um.do_emote("flip")
			Game.visible_message(target.cell, "%s headbutts %s!" % [user.display_name, target.display_name], "combat")
			Sfx.play("punch", target.cell)
			th.hurt_zone("head", dd, "brute", user)
			uh.hurt_zone("head", float(Game.rng.randi_range(5, 10)), "brute", user)
			var tinv2: CInventory = target.c(&"inv")
			var hat: Entity = tinv2.worn("head") if tinv2 else null
			if hat == null or not (hat.proto.contains("helmet") or hat.proto.contains("hardhat")):
				Organs.apply_damage(th, "brain", 5.0)
			uh.stun(Game.rng.randf_range(1.0, 4.5))
			th.stun(Game.rng.randf_range(0.5, 3.0))
			return true
		5, 6:
			var verb: String = ["kick", "hit", "slam"][Game.rng.randi() % 3]
			if check_block(target, "%s's %s" % [user.display_name, verb], 0.0, 0.0):
				return true
			Game.visible_message(target.cell, "%s %ss %s with such inhuman strength that it sends them flying backwards!" % [user.display_name, verb, target.display_name], "combat")
			th.hurt_zone(pick_zone(user, target), float(Game.rng.randi_range(15, 30)), "brute", user)
			Sfx.play("hit", target.cell)
			if tm:
				var away: Vector2i = target.cell - user.cell
				away = Vector2i(signi(away.x), signi(away.y))
				for i in 4:
					if not tm.push(away):
						break
			th.paralyze(6.0)
			return true
	return false
