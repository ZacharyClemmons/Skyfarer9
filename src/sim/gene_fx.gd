class_name GeneFx extends RefCounted
## What each tg mutation does (code/datums/mutations/*.dm): on_acquiring, on_losing,
## on_life, setup (chromosomes), speech, and the body hooks some of them register (moving,
## being flashed, the stat changing, attacking). Plus tg's something_horrible (instability
## meltdowns) and the monkeyize / humanize transformations (transform_procs.dm).
##
## Active powers (the action buttons) are GenePowers.

const CHAMELEON_DEFAULT_ALPHA := 204.0 / 255.0 # tg CHAMELEON_MUTATION_DEFAULT_TRANSPARENCY
const TRANSFORMATION_DURATION := 2.2 # tg TRANSFORMATION_DURATION 22 ds

static func _h(e: Entity) -> CHealth:
	return e.c(&"health")

static func _m(e: Entity) -> CMob:
	return e.c(&"mob")

static func _d(e: Entity) -> CDna:
	return e.c(&"dna")

## tg IS_UNCONSCIOUS_OR_CRIT
static func _out(e: Entity) -> bool:
	var h := _h(e)
	return h == null or h.stat() != CHealth.CONSCIOUS

## tg visible_message(message, self_message): the owner reads their own line.
static func _vis(e: Entity, others: String, self_msg: String, kind := "warn") -> void:
	if e == Game.player:
		Game.tell(e, self_msg, kind)
	else:
		Game.visible_message(e.root_cell(), others, kind)

static func _name(e: Entity) -> String:
	return e.display_name

# ================================================================== acquiring / losing
## tg /datum/mutation/proc/on_acquiring and every subtype's override.
static func on_acquiring(e: Entity, m: Mutation) -> bool:
	var h := _h(e)
	var d := _d(e)
	if h == null or d == null or h.dead or Traits.has(e, "animal_body") or m in d.mutations:
		return false
	var def := m.def()
	var sp: Array = def.get("species", [])
	if not sp.is_empty() and not d.species in sp:
		return false
	if def.get("health_req", 0) > 0 and h.health() < def["health_req"]:
		return false
	if def.get("limb_req", "") != "" and h.missing.has(def["limb_req"]):
		return false
	for other in d.mutations:
		if m.id in other.def().get("conflicts", []) or other.id in def.get("conflicts", []):
			return false
	if not can_acquire(e, m):
		return false
	m.owner = e
	d.mutations.append(m)
	if def.get("gain", "") != "" and m.id != "bad_dna":
		Game.tell(e, def["gain"], def.get("gain_k", "info"))
	GenePowers.grant(e, m)
	var tr: Array = def.get("traits", [])
	if not tr.is_empty():
		Traits.add_all(e, tr, "genetic")
	var mb := _m(e)
	var mid := m.id
	match mid:
		"epilepsy", "extrastun", "acromegaly", "aoe_moodlet", "aoe_moodlet_positive", "martyrdom", "inexorable":
			pass # handled by the body hooks below (on_moved, on_flashed, on_stat_changed...)
		"chameleon", "chameleon_changeling":
			if mb and mb.doll: mb.doll.modulate.a = CHAMELEON_DEFAULT_ALPHA
		"bad_dna":
			Game.tell(e, def["gain"], "bad")
			if Genetics.prob(95):
				match Game.rng.randi_range(1, 3):
					1: d.easy_random_mutate(Genetics.NEGATIVE + Genetics.MINOR_NEGATIVE)
					2: d.random_mutate_unique_identity()
					3: d.random_mutate_unique_features()
			else:
				d.easy_random_mutate(Genetics.POSITIVE)
			# tg: . = owner; on_losing(owner) - it takes itself straight back off
			d.mutations.erase(m)
			m.data["_removed"] = true
		"dwarfism":
			Traits.add(e, "dwarf", "genetic")
			_vis(e, "%s suddenly shrinks!" % _name(e), "Everything around you seems to grow..", "bad")
		"acromegaly":
			Traits.add(e, "too_tall", "genetic")
			_vis(e, "%s suddenly grows tall!" % _name(e), "You feel a small strange urge to fight small men with slingshots. Or maybe play some basketball.", "bad")
		"gigantism":
			Traits.add(e, "giant", "genetic")
			_vis(e, "%s suddenly grows!" % _name(e), "Everything around you seems to shrink..", "bad")
		"race":
			if not Traits.has(e, "lesser_humanoid"):
				m.data["original_species"] = d.species
				m.data["original_name"] = mb.real_name if mb else e.display_name
				monkeyize(e)
		"glow", "glow_anti":
			m.data["color"] = Color.BLACK if mid == "glow_anti" else Genetics.rand_pick([Color("#ff0000"), Color("#0000ff"), Color("#ffff00"), Color("#00ff00"), Color("#800080"), Color("#ffa500")])
			var l := CLight.new()
			l.kind = "item"
			l.on = true
			e.add(l)
			m.data["light"] = l
		"fire":
			h.burn_mod *= 0.5 # tg MODIFY_PHYSIOLOGY(owner, BURN, 0.5)
		"spastic":
			d.spasms += 1
		"mute":
			Traits.add(e, "mute", "genetic")
		"unintelligible":
			Traits.add(e, "unintelligible_speech", "genetic")
		"nearsight":
			Traits.add(e, "nearsighted", "genetic")
		"blind":
			Traits.add(e, "blind", "genetic")
		"xray":
			Traits.add(e, "xray_vision", "genetic")
		"illiterate":
			Traits.add(e, "illiterate", "genetic")
		"night_vision":
			Traits.add(e, "night_vision", "genetic")
		"clever":
			Traits.add_all(e, ["advancedtooluser", "literate"], "genetic")
		"webbing":
			Traits.add(e, "web_weaver", "genetic")
		"headless":
			_headless_gain(e, h)
		"bloodier":
			pass # setup() applies it
		"hulk", "hulk_ork", "hulk_wizardly", "hulk_superhuman":
			m.data["last_scream"] = -99.0
			CMood.event(e, "hulk", "hulk")
			h.cold_mod *= 2.0 # tg MODIFY_PHYSIOLOGY(owner, PHYS_COEFF_COLD, 2)
			if mb:
				mb.refresh_doll()
		"antenna":
			pass # the internal radio: CMob.radio checks for it
		"elastic_arms":
			pass # reach: Interact checks Traits / the mutation
		"venomous_strikes":
			pass
		"radioactive":
			m.data["rad_t"] = 0.0
		"chemical_allergy":
			m.data["allergic"] = false
		"stoner":
			pass # speech
		"biotechcompat":
			pass # SkillChips.capacity includes this mutation, without granting XP.
	if def.get("icon", "") != "" and mb:
		mb.refresh_doll()
	return true

## tg /datum/mutation/proc/can_acquire overrides
static func can_acquire(e: Entity, m: Mutation) -> bool:
	match m.id:
		"limb_regeneration":
			return not Traits.has(e, "nohunger")
	return true

## tg /datum/mutation/proc/on_losing (and overrides). The mutation leaves the body.
static func on_losing(e: Entity, m: Mutation) -> void:
	var h := _h(e)
	var d := _d(e)
	if d == null:
		return
	# tg race/on_losing: a dead monkey keeps its monkeyness
	if m.id == "race" and h and h.dead:
		return
	if not m in d.mutations:
		return
	d.mutations.erase(m)
	var def := m.def()
	var mb := _m(e)
	if def.get("lose", "") != "" and h and not h.dead:
		Game.tell(e, def["lose"], def.get("lose_k", "info"))
	var tr: Array = def.get("traits", [])
	if not tr.is_empty():
		Traits.remove_all(e, tr, "genetic")
	GenePowers.remove(e, m)
	match m.id:
		"dwarfism":
			Traits.remove(e, "dwarf", "genetic")
			_vis(e, "%s suddenly grows!" % _name(e), "Everything around you seems to shrink..", "bad")
		"acromegaly":
			Traits.remove(e, "too_tall", "genetic")
			_vis(e, "%s suddenly shrinks!" % _name(e), "You return to your usual height.", "bad")
		"gigantism":
			Traits.remove(e, "giant", "genetic")
			_vis(e, "%s suddenly shrinks!" % _name(e), "Everything around you seems to grow..", "bad")
		"race":
			if not is_instance_valid(e) or e.removed:
				return
			if mb and m.data.has("original_name"):
				mb.real_name = m.data["original_name"]
				e.display_name = mb.real_name
			humanize(e, m.data.get("original_species", "human"))
		"glow", "glow_anti":
			if e.has_c(&"light") and e.c(&"light") == m.data.get("light"):
				e.remove_comp(&"light")
		"fire":
			if h:
				h.burn_mod *= 2.0
		"spastic":
			d.spasms = maxi(0, d.spasms - 1)
		"mute":
			Traits.remove(e, "mute", "genetic")
		"unintelligible":
			Traits.remove(e, "unintelligible_speech", "genetic")
		"nearsight":
			Traits.remove(e, "nearsighted", "genetic")
		"blind":
			Traits.remove(e, "blind", "genetic")
		"thermal":
			Traits.remove(e, "thermal_vision", "genetic")
		"xray":
			Traits.remove(e, "xray_vision", "genetic")
		"illiterate":
			Traits.remove(e, "illiterate", "genetic")
		"night_vision":
			Traits.remove(e, "night_vision", "genetic")
		"clever":
			Traits.remove_all(e, ["advancedtooluser", "literate"], "genetic")
		"webbing":
			Traits.remove(e, "web_weaver", "genetic")
		"chameleon", "chameleon_changeling":
			if mb and mb.doll:
				mb.doll.modulate.a = 1.0
		"headless":
			_headless_lose(e, h)
		"bloodier":
			if h and m.data.get("physiology_modified", false):
				h.bleed_mod /= m.data["bleed_rate"]
				h.blood_regen_mod /= m.data["blood_regen_rate"]
				m.data["physiology_modified"] = false
		"hulk", "hulk_ork", "hulk_wizardly", "hulk_superhuman":
			CMood.clear_event(e, "hulk")
			if h:
				h.cold_mod *= 0.5
		"inexorable":
			Traits.remove(e, "force_whisper", "inexorable")
		"chemical_allergy":
			if m.data.get("allergic", false):
				m.instability *= 2.0
	if mb:
		mb.refresh_doll()

## tg /datum/mutation/proc/setup: after acquiring, and again when a chromosome is applied.
static func setup(e: Entity, m: Mutation) -> void:
	GenePowers.setup(e, m)
	var h := _h(e)
	match m.id:
		"glow", "glow_anti":
			var l = m.data.get("light")
			if l and is_instance_valid(e):
				# tg set_light_range_power_color(glow_range * power, glow_power, glow_color)
				l.radius = 2.5 * m.pwr()
				l.energy = -1.5 if m.id == "glow_anti" else 2.0 * 0.45
				l.color = m.data.get("color", Color.WHITE) if m.id != "glow_anti" else Color.WHITE
				if Game.lighting:
					Game.lighting.mark_dirty(l)
		"bloodier":
			if h == null:
				return
			if m.data.get("physiology_modified", false):
				h.bleed_mod /= m.data["bleed_rate"]
				h.blood_regen_mod /= m.data["blood_regen_rate"]
				m.data["physiology_modified"] = false
			m.data["bleed_rate"] = clampf(1.5 * m.sync() * m.pwr(), 1.0, 2.0)
			m.data["blood_regen_rate"] = clampf(6.0 * m.pwr(), 4.0, 12.0)
			h.bleed_mod *= m.data["bleed_rate"]
			h.blood_regen_mod *= m.data["blood_regen_rate"]
			m.data["physiology_modified"] = true

# ================================================================== on_life
## tg /datum/mutation/proc/on_life(seconds_per_tick)
static func on_life(e: Entity, m: Mutation, dt: float) -> void:
	var h := _h(e)
	var d := _d(e)
	var mb := _m(e)
	match m.id:
		"epilepsy":
			if Genetics.spt_prob(0.5 * m.sync(), dt):
				seizure(e, m)
		"cough":
			if Genetics.spt_prob(2.5 * m.sync(), dt) and not _out(e):
				var inv: CInventory = e.c(&"inv")
				if inv:
					for it in inv.hands.duplicate():
						if it:
							inv.drop(it)
				Emotes.emote(e, "cough")
				if m.pwr() > 1.0 and mb:
					# tg: thrown backwards cough_range tiles
					_throw_back(e, int(m.pwr() * 4))
		"paranoia":
			if Genetics.spt_prob(2.5, dt) and not _out(e):
				Emotes.emote(e, "scream")
				if Genetics.prob(25):
					Hallucinations.adjust(h, 40.0)
		"tourettes":
			if Genetics.spt_prob(5.0 * m.sync(), dt) and not _out(e) and not h.has_status("stun"):
				match Game.rng.randi_range(1, 3):
					1: Emotes.emote(e, "twitch")
					_: if mb: mb.say("%s%s" % [";" if Genetics.prob(50) else "", Genetics.rand_pick(["SHIT", "PISS", "FUCK", "CUNT", "COCKSUCKER", "MOTHERFUCKER", "TITS"])])
				if mb and mb.doll:
					var off := Vector2(Game.rng.randi_range(-2, 2), Game.rng.randi_range(-1, 1))
					var tw := mb.doll.create_tween()
					tw.tween_property(mb.doll, "position", mb.doll.position + off, 0.1)
					tw.tween_property(mb.doll, "position", mb.doll.position, 0.1)
		"fire":
			if Genetics.spt_prob((0.05 + (100.0 - d.stability) / 19.5) * m.sync(), dt):
				h.ignite(fire_stacks_time(2.0 * m.pwr())) # tg adjust_fire_stacks(2 * power); ignite_mob()
		"badblink":
			var wc: float = m.data.get("warpchance", 0.0)
			if Genetics.spt_prob(wc, dt):
				_warp(e, m)
			else:
				m.data["warpchance"] = wc + 0.0625 * dt / m.nrg()
		"acidflesh":
			if Genetics.spt_prob(13.0, dt):
				if Game.time >= m.data.get("msg_cd", 0.0):
					Game.tell(e, "Your acid flesh bubbles...", "bad")
					m.data["msg_cd"] = Game.time + 20.0
				if Genetics.prob(15):
					acid_act(e, Game.rng.randi_range(30, 50), 10.0)
					_vis(e, "%s's skin bubbles and pops." % _name(e), "[b]Your bubbling flesh pops! It burns![/b]", "bad")
					Sfx.play("sizzle", e.cell, 0.5)
		"hulk", "hulk_ork", "hulk_wizardly":
			if h.health() < h.crit_threshold():
				# tg: on_losing(owner) then qdel - it's simply gone
				Game.tell(e, "You suddenly feel very weak.", "bad")
				d.remove_mutation(m, m.sources.duplicate())
		"inexorable":
			_inexorable_check(e, h)
			if h.health() > h.crit_threshold() or _out(e) or Traits.has(e, "stasis"):
				return
			if Traits.has(e, "toximmune") or Traits.has(e, "toxinlover"):
				h.adjust("brute", 1.0 * dt * m.sync())
			else:
				h.adjust("tox", 0.5 * dt * m.sync())
				h.adjust("brute", 0.5 * dt * m.sync())
			h.adjust("oxy", -0.5 * dt)
		"limb_regeneration":
			_limb_regen(e, m, h, dt)
		"chemical_allergy":
			_allergy(e, m, h, d, dt)
		"venomous_strikes":
			# tg: filters its own venom out of the blood
			if h.chems.has("toxin"):
				h.chems["toxin"] = maxf(0.0, h.chems["toxin"] - snappedf(3.0 * 0.33, 0.01) * dt)
				if h.chems["toxin"] <= 0.0:
					h.chems.erase("toxin")
		"nervousness":
			if Genetics.spt_prob(5.0, dt):
				h.set_status_if_lower("stutter", 20.0)
		"elvis":
			if Game.rng.randi_range(1, 2) == 1:
				if Genetics.spt_prob(7.5, dt):
					var moves: String = Genetics.rand_pick(["swinging", "fancy", "stylish", "20'th century", "jivin'", "rock and roller", "cool", "salacious", "bashing", "smashing"])
					Game.visible_message(e.cell, "[b]%s[/b] busts out some %s moves!" % [_name(e), moves], "emote")
			elif Genetics.spt_prob(7.5, dt):
				Game.visible_message(e.cell, "[b]%s[/b] %s!" % [_name(e), Genetics.rand_pick(["jiggles their hips", "rotates their hips", "gyrates their hips", "taps their foot", "dances to an imaginary song", "jiggles their legs", "snaps their fingers"])], "emote")
		"chameleon", "chameleon_changeling":
			if mb and mb.doll:
				mb.doll.modulate.a = maxf(mb.doll.modulate.a - 12.5 / 255.0 * m.pwr() * dt, 0.0)
		"aoe_moodlet", "aoe_moodlet_positive":
			if Traits.has(e, "face_covered"):
				return
			for other in Game.in_radius(e.root_cell(), 3, &"mob"):
				if other != e and other.has_c(&"mood") and Game.lighting and (e == Game.player or other == Game.player or true):
					_aoe_other(e, m, other)
		"radioactive":
			# tg radioactive_emitter: every 5 s, range 2 x power, threshold RAD_MEDIUM_INSULATION
			m.data["rad_t"] = m.data.get("rad_t", 0.0) - dt
			if m.data["rad_t"] <= 0.0:
				m.data["rad_t"] = 5.0
				Radiation.pulse(e.root_cell(), 1.0 * (m.pwr() * 2.0), 0.6)
		"void":
			pass # GenePowers: the cursed void rolls on life
	GenePowers.on_life(e, m, dt)

## tg fire stacks as this station's burn time: a stack burns about 5 seconds
## tg /datum/status_effect/spasms tick (the spastic mutation applies one stack)
static func spasm_tick(e: Entity) -> void:
	var h := _h(e)
	if h:
		Traumas._spasm(h, _m(e), e.c(&"inv"))

static func fire_stacks_time(stacks: float) -> float:
	return maxf(4.0, stacks * 5.0)

# ================================================================== the effects
## tg epilepsy/trigger_seizure
static func seizure(e: Entity, m: Mutation) -> void:
	var h := _h(e)
	if _out(e):
		return
	_vis(e, "%s starts having a seizure!" % _name(e), "[b]You have a seizure![/b]", "bad")
	h.knock_out(20.0 * m.pwr()) # Unconscious(200)
	h.set_status("jitter", 2000.0 * m.pwr())
	CMood.event(e, "epilepsy", "epilepsy")
	Genetics.after(9.0, func():
		if is_instance_valid(e) and not e.removed:
			_h(e).set_status("jitter", 20.0))

## COMSIG_MOB_FLASHED: an epileptic has a 30% chance of a seizure
static func on_flashed(e: Entity) -> void:
	var d := _d(e)
	if d == null:
		return
	var m := d.get_mutation("epilepsy")
	if m and Genetics.prob(30):
		seizure(e, m)

## COMSIG_MOVABLE_MOVED for the mutations that listen to it
static func on_moved(e: Entity) -> void:
	RockMetabolism.reveal(e)
	var d := _d(e)
	if d == null or d.mutations.is_empty():
		return
	var h := _h(e)
	var mb := _m(e)
	for m in d.mutations.duplicate():
		match m.id:
			"acromegaly":
				_head_bonk(e, m, h)
			"extrastun":
				if Genetics.prob(99.5):
					continue
				if (mb and mb.buckled) or h.lying() or h.immobilized():
					continue
				Game.tell(e, "You trip over your own feet.", "bad")
				h.knockdown(3.0)
			"chameleon", "chameleon_changeling":
				if mb and mb.doll:
					mb.doll.modulate.a = CHAMELEON_DEFAULT_ALPHA
			"aoe_moodlet", "aoe_moodlet_positive":
				for x in Game.at(e.cell):
					if x.proto == "mirror":
						CMood.event(e, m.id, "seen_pretty_self" if m.id == "aoe_moodlet_positive" else "seen_ugly_self")

## COMSIG_LIVING_UNARMED_ATTACK: chameleons flicker back into view
static func on_attack(e: Entity) -> void:
	RockMetabolism.reveal(e)
	var d := _d(e)
	if d == null:
		return
	for m in d.mutations:
		if m.id in ["chameleon", "chameleon_changeling"]:
			var mb := _m(e)
			if mb and mb.doll:
				mb.doll.modulate.a = CHAMELEON_DEFAULT_ALPHA

## COMSIG_ATOM_EXAMINE: seeing an unsightly (or comely) person
static func on_examined(e: Entity, examiner: Entity) -> void:
	var d := _d(e)
	if d == null or examiner == e or not examiner.has_c(&"mood"):
		return
	for m in d.mutations:
		if m.id in ["aoe_moodlet", "aoe_moodlet_positive"] and not Traits.has(e, "face_covered"):
			_aoe_other(e, m, examiner)

static func _aoe_other(e: Entity, m: Mutation, other: Entity) -> void:
	var hidden := _face_hidden(e)
	var ev := ""
	if m.id == "aoe_moodlet_positive":
		ev = "seen_pretty_weak" if hidden else "seen_pretty"
	else:
		ev = "seen_ugly_weak" if hidden else "seen_ugly"
	CMood.event(other, m.id, ev, _name(e))

static func _face_hidden(e: Entity) -> bool:
	var inv: CInventory = e.c(&"inv")
	if inv == null:
		return false
	for s in ["mask", "head"]:
		var it: Entity = inv.worn(s)
		if it and it.has_c(&"clothing") and (it.c(&"clothing").covers_eyes or s == "mask"):
			return true
	return false

## tg acromegaly/head_bonk: walking under a door header
static func _head_bonk(e: Entity, m: Mutation, h: CHealth) -> void:
	var door: Entity = null
	for x in Game.at(e.cell):
		if x.has_c(&"door") or x.has_c(&"firelock"):
			door = x
			break
	if door == null or Genetics.prob(100.0 - 8.0 * m.sync()):
		return
	Game.tell(e, "You hit your head on %s's header!" % door.the(), "bad")
	var blocked := false
	var inv: CInventory = e.c(&"inv")
	if inv:
		var hat: Entity = inv.worn("head")
		blocked = hat != null and hat.has_c(&"clothing") and hat.c(&"clothing").armor > 0.0 # tg TRAIT_HEAD_INJURY_BLOCKED
	h.hurt_zone("head", Game.rng.randi_range(1, 4) if blocked else Game.rng.randi_range(2, 9), "brute", null)
	var mb := _m(e)
	if mb:
		mb.lunge(door.cell)
	Sfx.play("bang", e.cell, 0.3)
	h.set_status("staggered", minf(h.status_left("staggered") + 3.0, maxf(10.0, h.status_left("staggered")))) # adjust_staggered_up_to(3 s, 10 s)

## tg badblink: displaced rand(10,15) x power tiles, nauseous
static func _warp(e: Entity, m: Mutation) -> void:
	var nm := _name(e)
	var their := _m(e).their() if _m(e) else "their"
	var msg: String = Genetics.rand_pick([
		"With a sickening 720-degree twist of %s back, %s vanishes into thin air." % [their, nm],
		"%s does some sort of strange backflip into another dimension. It looks pretty painful." % nm,
		"%s does a jump to the left, a step to the right, and warps out of reality." % nm,
		"%s's torso starts folding inside out until it vanishes from reality, taking %s with it." % [nm, nm],
		"One moment, you see %s. The next, %s is gone." % [nm, nm]])
	_vis(e, msg, "[b]You feel a wave of nausea as you fall through reality![/b]", "bad")
	var dist := int(Game.rng.randi_range(10, 15) * m.pwr())
	var to := teleport_target(e.root_cell(), dist)
	if to != e.root_cell():
		var mb := _m(e)
		if mb:
			mb.stop_pulling()
		e.place(to)
		Fx.sparks(to)
	var h := _h(e)
	h.disgust = clampf(h.disgust + m.sync() * (m.data.get("warpchance", 0.0) * dist), 0.0, 150.0)
	m.data["warpchance"] = 0.0
	Game.visible_message(e.cell, "%s appears out of nowhere!" % nm, "warn")

## tg do_teleport(precision): a random open tile within `radius`.
static func teleport_target(c: Vector2i, radius: int) -> Vector2i:
	var map := Game.map
	for tries in 40:
		var t := c + Vector2i(Game.rng.randi_range(-radius, radius), Game.rng.randi_range(-radius, radius))
		if map.inb(t) and not map.is_solid_turf(t) and not map.blocks_move_static(t) and map.dense_count[map.idx(t)] == 0:
			return t
	return c

## tg human/acid_act: every uncovered bodypart takes acidity brute and twice that burn
## (acidity = acidpwr x min(volume x 0.005, 0.1)); an uncovered face may be disfigured.
static func acid_act(e: Entity, acidpwr: float, volume: float) -> void:
	var h := _h(e)
	var inv: CInventory = e.c(&"inv")
	var acidity := acidpwr * minf(volume * 0.005, 0.1)
	var covered := func(slots: Array) -> bool:
		if inv == null:
			return false
		for s in slots:
			if inv.worn(s) != null:
				return true
		return false
	var parts := []
	if not covered.call(["head", "mask", "eyes"]):
		parts.append("head")
	if not covered.call(["uniform", "suit"]):
		parts.append("chest")
	if not covered.call(["gloves", "uniform", "suit"]):
		parts += ["r_arm", "l_arm"]
	if not covered.call(["shoes", "uniform", "suit"]):
		parts += ["r_leg", "l_leg"]
	for p in parts:
		if h.missing.has(p):
			continue
		var mod := 1.0
		if p == "head" and Genetics.prob(minf(acidpwr * volume * 0.1, 90.0)):
			mod = 2.0
			Emotes.emote(e, "scream")
			var mb := _m(e)
			if mb:
				mb.appearance["hair"] = "bald"
				mb.appearance["facial"] = ""
				mb.refresh_doll()
		var z: String = Body.PARTS[p]["zones"][0]
		h.hurt_zone(z, acidity * mod, "brute", null)
		h.hurt_zone(z, acidity * mod * 2.0, "burn", null)

## tg inexorable/check_health: whispers while pushing on in crit
static func _inexorable_check(e: Entity, h: CHealth) -> void:
	if h.health() > h.crit_threshold() or _out(e):
		Traits.remove(e, "force_whisper", "inexorable")
	else:
		Traits.add(e, "force_whisper", "inexorable")

## tg limb_regeneration/on_life: while asleep and fed, missing limbs and organs regrow.
static func _limb_regen(e: Entity, m: Mutation, h: CHealth, dt: float) -> void:
	if h.dead or h._hard_crit():
		return
	var notified: bool = m.data.get("notified", false)
	if not Genetics.spt_prob(5.0 * (4.0 if notified else 1.0) * pow(m.pwr(), 2), dt):
		return
	var missing_limbs := []
	for p in ["l_arm", "r_arm", "l_leg", "r_leg"]:
		if h.missing.has(p):
			missing_limbs.append(p)
	var missing_organs := []
	for slot in Organs.ORDER:
		if slot == "appendix" and m.pwr() <= 1.0:
			continue
		if slot == "brain":
			continue
		if not h.organs.has(slot):
			missing_organs.append(slot)
	if h.eyes_removed:
		missing_organs.append("eyes")
	if missing_limbs.is_empty() and missing_organs.is_empty():
		return
	var n: CNeeds = e.c(&"needs")
	var fed := n == null or n.nutrition > Body.NUTRITION_LEVEL_FED / Body.NUTRITION_SCALE * 0.85
	var asleep := h.stat() == CHealth.UNCONSCIOUS
	if not fed:
		if asleep and not notified:
			Game.tell(e, "You feel a strange tingling, as if your body is trying to do something - though you feel like you could use a meal first.", "good")
			m.data["notified"] = true
		return
	if not asleep:
		if not notified:
			Game.tell(e, "You feel a strange tingling, as if your body is trying to do something - though you feel like you could use a nap first.", "good")
			m.data["notified"] = true
		return
	m.data["notified"] = false
	if not missing_organs.is_empty() and (Genetics.prob(50) or missing_limbs.is_empty()):
		var slot: String = Genetics.rand_pick(missing_organs)
		if slot == "eyes":
			h.eyes_removed = false
			h.eye_damage = 0.0
			Game.tell(e, "The tingling feeling builds to a climax, until ultimately you feel some new eyes where your old ones were!", "good")
		else:
			h.organs[slot] = Organs.new_organ(slot, 0.0)
			Game.tell(e, "The tingling feeling builds to a climax, until ultimately you feel a new %s where your old one was!" % Organs.DEFS[slot]["name"], "good")
	else:
		var p: String = Genetics.rand_pick(missing_limbs)
		regenerate_limb(h, p)
		Game.tell(e, "The tingling feeling builds to a climax, until ultimately you feel a new %s where your old one was!" % Body.pname(p), "good")
		Game.visible_message(e.cell, "%s's %s reforms, making a loud, grotesque sound!" % [_name(e), Body.pname(p)], "warn")
	if n:
		n.nutrition = maxf(0.0, n.nutrition - 100.0 * 0.5 * m.sync()) # NUTRITION_LEVEL_FULL * 0.5
	Sfx.play("gore", e.cell, 0.4)

## tg regenerate_limb
static func regenerate_limb(h: CHealth, part: String) -> void:
	h.missing.erase(part)
	h.dismembered_by.erase(part)
	h.limb_maxed.erase(part)
	for z in Body.PARTS[part]["zones"]:
		h.limb.erase(z)
		h.limb_burn.erase(z)
	var m: CMob = h.e.c(&"mob")
	if m:
		m._update_pose()
		m.refresh_doll()

## tg chemical_allergy/on_life
const ALLERGY_SAFE := ["mannitol", "mutadone"]
static func _allergy(e: Entity, m: Mutation, h: CHealth, d: CDna, dt: float) -> void:
	var danger := false
	for k in h.chems:
		if h.chems[k] >= 1.0 and Chem.is_medicine_or_drug(k) and not k in ALLERGY_SAFE:
			danger = true
			break
	if not danger:
		if m.data.get("allergic", false):
			m.data["allergic"] = false
			m.instability *= 2.0
			d.update_instability()
		return
	if not Genetics.spt_prob(80.0, dt):
		return
	if not m.data.get("allergic", false):
		m.data["allergic"] = true
		m.instability *= 0.5 # halves the negative instability it rewards
		d.update_instability()
	if Genetics.spt_prob(66.0, dt):
		h.set_status_if_lower("stutter", 4.0)
	if Genetics.spt_prob(33.0, dt):
		h.disgust = minf(h.disgust + 24.0, maxf(h.disgust, 75.0)) # adjust_disgust(24, DISGUST_LEVEL_VERYDISGUSTED)
		h.adjust("tox", Genetics.rand_pick([2.0, 3.0, 4.0]))
	if Genetics.spt_prob(12.0, dt):
		h.set_status("jitter", minf(h.status_left("jitter") + 6.0, maxf(36.0, h.status_left("jitter"))))
		h.set_status("dizziness", minf(h.status_left("dizziness") + 6.0, maxf(36.0, h.status_left("dizziness"))))
		h.blood_volume = maxf(minf(h.blood_volume, Body.BLOOD_VOLUME_OKAY), h.blood_volume - Genetics.rand_pick([12.0, 16.0, 20.0, 24.0]))
	if Genetics.spt_prob(6.0, dt):
		h.set_status("confusion", minf(h.status_left("confusion") + 4.0, maxf(12.0, h.status_left("confusion"))))
		h.losebreath = maxf(h.losebreath, 4.0)

## tg martyrdom/bloody_shower and the stat change hook
static func on_stat_changed(e: Entity) -> void:
	var d := _d(e)
	if d == null:
		return
	var h := _h(e)
	for m in d.mutations.duplicate():
		match m.id:
			"martyrdom":
				if h.dead or h._hard_crit():
					_bloody_shower(e, h)
					return
			"inexorable":
				_inexorable_check(e, h)

static func _bloody_shower(e: Entity, h: CHealth) -> void:
	var c := e.root_cell()
	# tg: every organ in the head is deleted
	h.eyes_removed = true
	h.organs.erase("brain")
	Explosion.explode(c, 0, 0, 2, e)
	for other in Game.in_radius(c, 2, &"health"):
		if other == e or not other.has_c(&"mob"):
			continue
		if Game.lighting and not Game.lighting._los(c, other.root_cell()):
			continue
		var oh: CHealth = other.c(&"health")
		if not oh.eyes_removed:
			Game.tell(other, "[b]You are blinded by a shower of blood![/b]", "bad")
			StatusFx.damage_eyes(oh, 5.0)
		else:
			Game.tell(other, "[b]You are knocked down by a wave of... blood?![/b]", "bad")
		oh.stun(2.0)
		oh.set_status_if_lower("eye_blur", 40.0)
		oh.adjust_status("confusion", 3.0)
	if not e.removed:
		Body.gib(h)

## tg headless on_acquiring: the brain recedes into the chest, the head splatters
static func _headless_gain(e: Entity, h: CHealth) -> void:
	h.set_meta("brain_in_chest", true)
	if h.missing.has("head"):
		return
	if e != Game.player:
		Game.visible_message(e.cell, "%s's head splatters with a sickening crunch!" % _name(e), "bad")
	Body.splatter(e.cell, 50.0, false, h)
	h.eyes_removed = true
	h.missing["head"] = true
	h.dismembered_by["head"] = "blunt"
	var inv: CInventory = e.c(&"inv")
	if inv:
		for s in ["head", "mask", "eyes", "ears"]:
			var it: Entity = inv.worn(s)
			if it:
				inv.drop(it)
	var mb := _m(e)
	if mb:
		mb.refresh_doll()

static func _headless_lose(e: Entity, h: CHealth) -> void:
	if h == null or not h.missing.has("head"):
		return
	regenerate_limb(h, "head")
	h.remove_meta("brain_in_chest")
	h.eyes_removed = false
	h.eye_damage = 0.0
	h.hurt_zone("head", 50.0, "brute", null)
	_vis(e, "%s's head returns with a sickening crunch!" % _name(e), "Your head regrows with a sickening crack! Ouch.", "bad")
	Body.splatter(e.cell, 30.0, false, h)

## tg cough power > 1: thrown backwards
static func _throw_back(e: Entity, tiles: int) -> void:
	var mb := _m(e)
	var d: Vector2i = -Defs.DIRS4[mb.dir]
	var to := e.cell
	for i in tiles:
		var n := to + d
		if not Game.map.inb(n) or Game.map.blocks_move_static(n) or Game.map.is_solid_turf(n) or Game.map.dense_count[Game.map.idx(n)] > 0:
			break
		to = n
	if to != e.cell:
		e.place(to)

# ================================================================== speech (COMSIG_MOB_SAY)
static var _strings := {}

static func strings(file: String, key: String):
	var k := file + ":" + key
	if not _strings.has(k):
		var f := FileAccess.open("res://assets/data/strings/" + file, FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text()) if f else null
		_strings[k] = data.get(key, {}) if data is Dictionary else {}
	return _strings[k]

## Every speech-changing mutation on the body, in the order they came.
## Returns {text, sans, uppercase}.
static func treat_speech(e: Entity, text: String) -> Dictionary:
	var out := {"text": text, "sans": false, "uppercase": false}
	var d := _d(e)
	if d == null or text == "" or text.begins_with("*"):
		return out
	for m in d.mutations:
		var t: String = out["text"]
		match m.id:
			"wacky":
				out["sans"] = true
			"heckacious":
				t = heckacious(t)
			"swedish":
				t = speechmod(t, {"w": "v", "j": "y", "bo": "bjo", "a": ["å", "ä", "æ", "a"], "o": ["ö", "ø", "o"]}, ["", ", bork", ", bork, bork"], 30.0)
			"chav":
				t = speechmod(t, strings("chav_replacement.json", "chav"), ", mate", 30.0)
			"elvis":
				t = speechmod(t, strings("elvis_replacement.json", "elvis"), "", 100.0)
			"medieval":
				t = medieval(t)
			"piglatin":
				t = piglatin_sentence(t)
			"hulk", "hulk_wizardly", "hulk_superhuman":
				t = speechmod(t, {".": "!"}, "!!", 100.0)
				out["uppercase"] = true
			"hulk_ork":
				t = speechmod(t, strings("ork_replacement.json", "ork"), "!!", 100.0)
				out["uppercase"] = true
			"stoner":
				t = Species.beachbum(t)
		out["text"] = t
	if Traits.has(e, "unintelligible_speech"):
		out["text"] = Traumas._unintelligize(out["text"])
	if out["uppercase"]:
		out["text"] = str(out["text"]).to_upper()
	return out

## tg /datum/component/speechmod/handle_speech: replacetextEx over every key, then the
## end string (picked when it's a list) at its chance.
static func speechmod(msg: String, replacements: Dictionary, end_string, end_chance: float) -> String:
	for k in replacements:
		var r = replacements[k]
		if r is Array:
			r = Genetics.rand_pick(r)
		msg = msg.replace(str(k), str(r))
	msg = msg.strip_edges()
	if Genetics.prob(end_chance):
		msg += (Genetics.rand_pick(end_string) if end_string is Array else str(end_string))
	return msg.strip_edges()

## tg medieval/handle_speech: whole-word replacements keeping the case, then a starting.
static func medieval(message: String) -> String:
	var words: Dictionary = strings("medieval_replacement.json", "medieval")
	var startings: Array = strings("medieval_replacement.json", "startings")
	message = " %s " % message
	for key in words:
		var value = words[key]
		if value is Array:
			value = Genetics.rand_pick(value)
		value = str(value)
		var k := str(key)
		if k.to_upper() == k:
			value = value.to_upper()
		if k.capitalize() == k:
			value = value.capitalize()
		var re := RegEx.create_from_string("(?i)\\b%s\\b" % _regex_quote(k))
		message = re.sub(message, value, true)
	message = message.strip_edges()
	if not startings.is_empty():
		message = "%s %s" % [Genetics.rand_pick(startings), message]
	return message

static func _regex_quote(s: String) -> String:
	var out := ""
	for ch in s:
		if ch in ".^$*+?()[]{}|\\/":
			out += "\\"
		out += ch
	return out

const VOWELS := ["a", "e", "i", "o", "u"]
const CONSONANTS := ["b", "c", "d", "f", "g", "h", "j", "k", "l", "m", "n", "p", "q", "r", "s", "t", "v", "w", "x", "y", "z"]

## tg heckacious/handle_speech
static func heckacious(message: String) -> String:
	var wacky: Dictionary = strings("heckacious.json", "heckacious")
	var out := []
	for w in (" %s " % message).split(" "):
		if w == "":
			continue
		var og := w
		var edited := false
		for key in wacky:
			var value = wacky[key]
			if value is Array:
				value = Genetics.rand_pick(value)
			var k := str(key)
			var v := str(value)
			w = w.replace(k.to_upper(), v.to_upper())
			w = w.replace(k.capitalize(), v.capitalize())
			w = w.replace(k, v)
			if w != og:
				edited = true
		if Genetics.prob(10):
			w = w.to_upper() if Genetics.prob(85) else w.to_lower()
		if Genetics.prob(10):
			for i in Game.rng.randi_range(2, 8):
				w += "."
		if Genetics.prob(10):
			var em: String = Genetics.rand_pick(["+", "_", "|"])
			w = em + w + em
		if not edited:
			if Genetics.prob(65):
				w = w.replace(Genetics.rand_pick(VOWELS), Genetics.rand_pick(VOWELS))
			for i in Game.rng.randi_range(1, 2):
				w = w.replace(Genetics.rand_pick(CONSONANTS), Genetics.rand_pick(CONSONANTS))
			var patch := ""
			for ch in w:
				patch += ch if Genetics.prob(92) else ch + ch
			w = patch
		out.append(w)
	return " ".join(out).strip_edges()

## tg piglatin_sentence
static func piglatin_sentence(text: String) -> String:
	var n := text.length()
	text = text.to_lower()
	var punct := ""
	for i in range(n - 1, -1, -1):
		if not text[i] in ["!", "?", ".", "-"]:
			break
		punct = text[i] + punct
	text = text.substr(0, n - punct.length())
	var words := []
	for w in text.split(" "):
		words.append(piglatin_word(w))
	text = " ".join(words)
	return text.capitalize().substr(0, 1) + text.substr(1) + punct if text != "" else punct

static func piglatin_word(word: String) -> String:
	if word.length() <= 1:
		return word
	var first := word.substr(0, 1)
	var first_two := word.substr(0, 2)
	var v1 := first in VOWELS
	var v2 := word.substr(1, 1) in VOWELS
	if v1:
		return word + Genetics.rand_pick(["yay", "way", "hay"])
	if v2:
		return word.substr(1) + first + "ay"
	return word.substr(2) + first_two + "ay"

# ================================================================== meltdowns
## tg human/something_horrible
static func something_horrible(e: Entity, ignore_stability := false) -> void:
	var d := _d(e)
	if d == null:
		return
	if not ignore_stability and d.stability > 0:
		return
	var instability := -d.stability
	d.remove_all_mutations()
	d.stability = 100.0
	var nonfatal := Genetics.prob(maxf(70.0 - instability, 0.0))
	meltdown(e, Genetics.pick_meltdown(not nonfatal))

static func meltdown(e: Entity, kind: String) -> void:
	var h := _h(e)
	var d := _d(e)
	match kind:
		"monkey":
			monkeyize(e)
		"paraplegic":
			Traumas.gain(h, "paraplegic", Traumas.RES_SURGERY)
			if Proto.has("wheelchair"):
				Proto.spawn("wheelchair", e.root_cell())
			Game.tell(e, "My flesh turned into a wheelchair and I can't feel my legs.", "bad")
		"corgi":
			animalize(e, "corgi")
		"alright":
			Game.tell(e, "Oh, I actually feel quite alright!")
		"not_alright":
			Game.tell(e, "Oh, I actually feel quite alright!")
			d.damage_resistance -= 20000.0
		"slime":
			Game.tell(e, "Oh, I actually feel quite alright!")
			Chem.affect_mob({"aslimetoxin": 10.0}, e, 1.0)
		"yeet":
			d.apply_go_away()
		"decloning":
			Game.tell(e, "Oh, I actually feel quite alright!")
			h.set_meta("decloning", true) # tg /datum/disease/decloning: slow cellular decay
		"organ_vomit":
			_organ_vomit(e, h)
		"snail":
			Game.tell(e, "Oh, I actually feel quite alright!")
			h.set_meta("gastrolosis", 0.0) # tg /datum/disease/gastrolosis
		"crab":
			Game.tell(e, "Your DNA mutates into the ultimate biological form!")
			animalize(e, "crab")
		"gib":
			Body.gib(h)
		"dust":
			dust(e)
		"petrify":
			h.die()
			petrify(e)
		"dismember":
			var part: String = Genetics.rand_pick(["chest", "head"])
			if not h.missing.has(part) and (part != "chest" or not h.eviscerated):
				Body.dismember(h, part)
			else:
				Body.gib(h)
		"skeletonize":
			_vis(e, "%s's skin melts off!" % _name(e), "[b]Your skin melts off![/b]", "bad")
			Body.splatter(e.cell, 60.0, false, h)
			Species.set_species(e, "skeleton")
			if Genetics.prob(90):
				Genetics.after(3.0, func():
					if is_instance_valid(e) and not e.removed:
						_h(e).die())
		"ceiling":
			Game.tell(e, "[b]LOOK UP![/b]", "bad")
			Genetics.after(3.0, func(): if is_instance_valid(e) and not e.removed: something_horrible_mindmelt(e))
		"psyker":
			slow_psykerize(e)

## tg something_horrible_mindmelt: the eyes melt away and the brain follows
static func something_horrible_mindmelt(e: Entity) -> void:
	var h := _h(e)
	if StatusFx.blind(h) or h.eyes_removed:
		return
	h.eyes_removed = true
	_vis(e, "%s looks up and their eyes melt away!" % _name(e), "[b]I understand now.[/b]", "bad")
	Genetics.after(2.0, func():
		if is_instance_valid(e) and not e.removed:
			Organs.apply_damage(_h(e), "brain", 200.0))

## tg slow_psykerize: the head slowly turns into a psyker's (blind, but they can echolocate)
static func slow_psykerize(e: Entity) -> void:
	if not Psyker.eligible(e) or Traits.has(e, "psyker") or e.get_meta("psyker_transforming", false): return
	e.set_meta("psyker_transforming", true)
	Game.tell(e, "[b]You feel unwell...[/b]", "bad")
	Genetics.after(5.0, func():
		if not Psyker.eligible(e):
			if is_instance_valid(e): e.remove_meta("psyker_transforming")
			return
		Game.tell(e, "[b]You feel your skin ripping off![/b]", "bad")
		Emotes.emote(e, "scream")
		_h(e).hurt_zone("head", 30.0, "brute", null)
		Genetics.after(5.0, func():
			if is_instance_valid(e): e.remove_meta("psyker_transforming")
			if not Psyker.transform(e): return
			_h(e).hurt_zone("head", 50.0, "brute", null)
			Game.tell(e, "[b]Your head splits open! Your brain mutates![/b]", "bad")
			Emotes.emote(e, "scream")))

static func _organ_vomit(e: Entity, h: CHealth) -> void:
	var opts := []
	for slot in Organs.ORDER:
		if h.organs.has(slot):
			opts.append(slot)
	Emotes.emote(e, "gag")
	var n: CNeeds = e.c(&"needs")
	if n:
		n.nutrition = maxf(0.0, n.nutrition - 10.0)
	if opts.is_empty():
		return
	var slot: String = Genetics.rand_pick(opts)
	var nm: String = Organs.DEFS[slot]["name"]
	var it := Organs.remove(h, slot, e.root_cell())
	_vis(e, "%s vomits up %s %s!" % [_name(e), _m(e).their() if _m(e) else "their", nm], "You vomit up your %s" % nm, "bad")
	if it and Genetics.prob(20):
		it.tags["animated"] = true

## tg dust(): the body crumbles to ash; what was carried falls
static func dust(e: Entity) -> void:
	var h := _h(e)
	var c := e.root_cell()
	_vis(e, "%s turns to dust!" % _name(e), "[b]You turn to dust![/b]", "bad")
	if not h.dead:
		h.die()
	var inv: CInventory = e.c(&"inv")
	if inv:
		for hnd in inv.hands.duplicate():
			if hnd:
				inv.drop(hnd, c)
		for s in inv.slots.keys():
			if inv.slots[s]:
				inv.drop(inv.slots[s], c)
	if Proto.has("ash"):
		Proto.spawn("ash", c)
	e.set_meta("dusted", true)
	if e == Game.player:
		e.visible = false
		e.remove_comp(&"blocker")
		return
	e.destroy()

## tg petrify: a statue of what they were
static func petrify(e: Entity) -> void:
	if e.has_meta("petrified"):
		return
	var statue := Proto.spawn("petrified_statue", e.root_cell())
	var component: CStatue = statue.c(&"statue")
	component.enclose(e)

## Preserve the controlling entity while replacing its body, like TG's mind transfer.
static func animalize(e: Entity, kind: String) -> void:
	if not kind in ["corgi", "crab", "gorilla"] or Traits.has(e, "no_transform") or _h(e).dead:
		return
	var c := e.root_cell()
	var h := _h(e)
	var d := _d(e)
	d.start_transform(0.0, Callable())
	d.remove_all_mutations()
	d.start_transform(0.0, Callable())
	Traits.remove_source(e, "temporary_transformation")
	if e.has_meta("inside"):
		var enclosure: Entity = Game.get_entity(e.get_meta("inside"))
		if is_instance_valid(enclosure):
			var scanner: CDnaScanner = enclosure.c(&"dnascanner") if enclosure.has_c(&"dnascanner") else enclosure.c(&"skillstation")
			if scanner:
				scanner.occupant = null
				scanner._release(e)
				scanner._update_state()
	var inv: CInventory = e.c(&"inv")
	if inv:
		for hnd in inv.hands.duplicate():
			if hnd:
				inv.drop(hnd, c)
		for s in inv.slots.keys():
			if inv.slots[s]:
				inv.drop(inv.slots[s], c)
	Fx.smoke_puff(c)
	Game.visible_message(c, "%s turns into a %s!" % [_name(e), kind], "bad")
	d.brain_kind = "animal"
	Psyker.detach(e)
	for chip in SkillChips.list_of(e).duplicate(): chip.destroy()
	d.genetic_damage = 0.0
	d.damage_resistance = 0.0
	d.melt_t = -1.0
	d.temp_transforms.clear()
	RockMetabolism.clear(e)
	Species.set_species(e, kind)
	h.max_health = 180.0 if kind == "gorilla" else 20.0
	h.brute = 0.0
	h.burn = 0.0
	h.tox = 0.0
	h.oxy = 0.0
	h.status.clear()
	h.limb.clear()
	h.limb_burn.clear()
	h.limb_maxed.clear()
	h.missing.clear()
	h.wounds.clear()
	h.scars.clear()
	h.embedded.clear()
	h.eviscerated = false
	h.eyes_removed = false
	h.eye_damage = 0.0
	h.ear_damage = 0.0
	h.bleeding = 0.0
	h.blood_volume = Body.BLOOD_VOLUME_NORMAL
	h.organs = Organs.fresh()
	e.set_meta("transformed", kind)
	e.display_name = kind
	e.visible = true
	var mb := _m(e)
	if mb:
		mb.refresh_doll()
	e.remove_comp(&"brain")
	e.remove_comp(&"monkeyai")
	if e != Game.player:
		e.add(CAnimalAI.new())

## tg gorillize (genetics_gorilla): a simian overloaded with genetic damage
static func gorillize(e: Entity) -> void:
	animalize(e, "gorilla")

# ================================================================== monkeys
## tg carbon/monkeyize: a 2.2 s transformation (stunned, invisible), then the monkey species.
static func monkeyize(e: Entity, instant := false) -> void:
	var d := _d(e)
	if d == null or d.transforming() or Traits.has(e, "no_transform"):
		return
	if d.species == "monkey":
		return
	if instant:
		finish_monkeyize(e)
		return
	Traits.add(e, "no_transform", "temporary_transformation")
	var h := _h(e)
	h.set_status_if_lower("stun", TRANSFORMATION_DURATION) # Stun(ignore_canstun)
	_transform_fx(e, false)
	d.start_transform(TRANSFORMATION_DURATION, func(): finish_monkeyize(e))

static func finish_monkeyize(e: Entity) -> void:
	if not is_instance_valid(e) or e.removed:
		return
	Traits.remove(e, "no_transform", "temporary_transformation")
	var mb := _m(e)
	if mb and mb.doll:
		mb.doll.visible = not e.has_meta("inside")
	Species.set_species(e, "monkey")
	Game.tell(e, "[b]You are now a Monkey.[/b]")
	e.display_name = "monkey"
	if mb:
		mb.refresh_doll()
	var h := _h(e)
	if h.cuffed:
		h.cuffed = false # tg uncuff()

## tg carbon/humanize
static func humanize(e: Entity, species := "human", instant := false) -> void:
	var d := _d(e)
	if d == null or d.transforming() or Traits.has(e, "no_transform"):
		return
	if d.species != "monkey":
		return
	if instant:
		finish_humanize(e, species)
		return
	Traits.add(e, "no_transform", "temporary_transformation")
	var h := _h(e)
	h.set_status_if_lower("stun", TRANSFORMATION_DURATION)
	_transform_fx(e, true)
	d.start_transform(TRANSFORMATION_DURATION, func(): finish_humanize(e, species))

static func finish_humanize(e: Entity, species := "human") -> void:
	if not is_instance_valid(e) or e.removed:
		return
	Traits.remove(e, "no_transform", "temporary_transformation")
	var mb := _m(e)
	if mb:
		if mb.doll:
			mb.doll.visible = not e.has_meta("inside")
		mb.appearance["underwear"] = Color(0, 0, 0, 0) # tg: underwear = "Nude"
	Species.set_species(e, species)
	Game.tell(e, "[b]You are now a %s.[/b]" % Species.name_of(species))
	if mb:
		if mb.real_name != "" and not mb.real_name.begins_with("monkey"):
			e.display_name = mb.real_name
		mb.refresh_doll()

## tg /obj/effect/temp_visual/monkeyify (and /humanify): the body vanishes into a swirl
static func _transform_fx(e: Entity, humanify: bool) -> void:
	var mb := _m(e)
	if mb and mb.doll:
		mb.doll.visible = false
	if not e.has_meta("inside"):
		Fx.transform_swirl(e.root_cell(), humanify)
	Sfx.play("dna_transform", e.root_cell(), 0.6)

# ================================================================== examine
static func examine(e: Entity, lines: Array) -> void:
	var d := _d(e)
	if d == null:
		return
	for m in d.mutations:
		match m.id:
			"hulk", "hulk_ork", "hulk_wizardly", "hulk_superhuman":
				lines.append("[color=#8ad86a]%s has huge, bulging green muscles.[/color]" % (_m(e).they().capitalize() if _m(e) else "They"))
			"antenna", "mindreader":
				lines.append("An antenna sticks out of %s forehead." % (_m(e).their() if _m(e) else "their"))
			"radioactive":
				lines.append("[color=#8ae84a]%s is glowing a faint, sickly green.[/color]" % (_m(e).they().capitalize() if _m(e) else "They"))
			"telekinesis":
				lines.append("A faint blue halo hangs over %s head." % (_m(e).their() if _m(e) else "their"))
			"laser_eyes":
				lines.append("[color=#ff5a4a]%s eyes are glowing red.[/color]" % (_m(e).their().capitalize() if _m(e) else "Their"))
