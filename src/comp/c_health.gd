class_name CHealth extends Component
## Carbon-based body, after tg's damage model: brute / burn / toxin / oxygen loss,
## health = 100 - total, crit at <= 0 (unconscious, suffocating), dead at <= -100.
## Also body temperature, stamina, bleeding, stuns, sleep and being on fire.

enum { CONSCIOUS, UNCONSCIOUS, DEAD, SOFT_CRIT }
const MAX_HEALTH := 100.0
const CRIT := 0.0
const HARD_CRIT := -30.0 # tg HEALTH_THRESHOLD_FULLCRIT
const DEAD_AT := -100.0
var max_health := MAX_HEALTH

func on_removed() -> void:
	for chip in SkillChips.list_of(e).duplicate():
		if is_instance_valid(chip) and not chip.removed: chip.destroy()
	if e.has_meta("rock_glow"):
		var glow: Entity = e.get_meta("rock_glow")
		if is_instance_valid(glow) and not glow.removed: glow.destroy()

var brute := 0.0
var burn := 0.0
var tox := 0.0
var oxy := 0.0
var stamina := 100.0
var bleeding := 0.0 # generic bleeding (surgery slips), u/s; tg generic_bleedstacks
var body_temp := Defs.BODYTEMP_NORMAL # tg bodytemperature (the skin)
var core_temp := Defs.BODYTEMP_NORMAL # tg coretemperature
# tg incapacitating status effects (status_procs.dm), kept in `status` below; these are the
# old names for them
var stun_t: float:
	get: return status.get("stun", 0.0)
	set(v): _set_timed("stun", v)
var knockdown_t: float:
	get: return status.get("knockdown", 0.0)
	set(v): _set_timed("knockdown", v)
var sleeping := false # asleep by choice (a bed at night); tg Sleeping() is status "sleeping"
var on_fire := 0.0 # seconds remaining
var cuffed := false
var dead := false
var time_of_death := 0.0
var last_damage_by: Entity = null
var last_damage_kind := ""
var breath_status := "ok" # ok, low_o2, toxic, no_air, internals
var breath_alerts := {} # tg lung alerts this breath: "co2", "plasma", "n2o", "smoke" -> true
var co2_over := 0.0 # when the CO2 overload started (tg co2overloadtime), 0 = not over
var breath_t := 0.0 # seconds to the next breath
var losebreath := 0.0 # tg losebreath: breaths about to be missed
var failed_last_breath := false
var low_pressure_t := 0.0 # tg seconds_in_low_pressure
var unconscious_t: float: # tg Unconscious()
	get: return status.get("unconscious", 0.0)
	set(v): _set_timed("unconscious", v)
var pressure_status := "ok"
var pain := 0.0
var disease = null # Disease or null
var limb := {} # zone -> brute+burn taken there (see Combat.ZONES)
var stagger_t: float: # tg /datum/status_effect/staggered
	get: return status.get("staggered", 0.0)
	set(v): _set_timed("staggered", v)
var stamcrit := false # tg /datum/status_effect/incapacitating/stamcrit
var last_stamina_dmg := -100.0 # tg timed_stamina_reset: when stamina damage last landed
var drunk := 0.0 # tg /datum/status_effect/inebriated drunk_value
var eye_damage := 0.0 # tg eyes organ damage, 0-50 (StatusFx): nearsighted from 20, blind at 50
var ear_damage := 0.0 # tg ears organ damage, 0-100: deaf at 100
var resting := false # tg resting (U): wants to lie down; not the same as being down
var body_lying := false # tg body_position == LYING_DOWN: actually on the floor
var get_up_t := -1.0 # tg get_up(): seconds left of the 1 s do_after, -1 = not getting up
const GET_UP_TIME := 1.0
# tg blood and bodyparts (see Body)
var blood_volume := Body.BLOOD_VOLUME_NORMAL
var blood_type := ""
var wounds: Array = [] # [{id, part, type, sev, flow, ...}] (Body.DEFS)
var missing := {} # bodypart -> true (dismembered)
var body_materials := {} # bodypart -> biological material; absent means flesh
var dismembered_by := {} # bodypart -> wounding type (tg body_zone_dismembered_by)
var limb_burn := {} # zone -> the burn part of limb[zone] (tg burn_dam)
var limb_maxed := {} # bodypart -> true once it hit max_damage (tg last_maxed)
var gauze := {} # bodypart -> the wrap on it (tg applied_items[LIMB_ITEM_GAUZE], Body.WRAPS)
var grasp := "" # the bodypart they're holding to slow its bleeding (tg self_grasp)
var scars: Array = [] # [{part, sev, desc, loc, vis}] (tg datum/scar)
var eviscerated := false
var eyes_removed := false # pulled out through a cranial fissure # tg chest dismember: the organs have spilled out
var determination := 0.0 # tg /datum/reagent/determination, units
var determined := false # tg /datum/status_effect/determined
var determined_big := false # the determination was "significant"
var bleed_msg_t := 0.0 # tg bleeding_message_cd
var status := {} # tg status effects with a duration: id -> seconds left
var chems := {} # the bloodstream: reagent -> units (Chem.metabolize)
var helium_voice := false # cleared by the next helium-free breath
var damageoverlaytemp := 0.0 # tg: brute/burn just taken, added to the hurt overlay until the next Life tick
var shock_jolts: Array[float] = [] # second electrocution jolts, in simulation seconds
var organs := Organs.fresh() # tg internal organs: slot -> state (Organs)
var embedded: Array = [] # tg embedded objects: [{part, name, proto, w, sharp, data, dropdel}] (Embeds)
var disgust := 0.0 # tg disgust, 0-150 (stomach/handle_disgust)
var traumas: Array = [] # tg brain traumas: [{id, group, res, ...}] (Traumas)
var terror := 0.0 # tg fearful terror_buildup, 0-1000 (Traumas._fear)
var last_terror := 0.0
var traits := {} # tg traits: name -> {source: true} (Traits)
## tg physiology coefficients (MODIFY_PHYSIOLOGY): burn_mod (fiery sweat halves it),
## cold_mod (hulks take double), bleed_mod and blood_regen_mod (hypermetabolic blood)
var burn_mod := 1.0

var brute_mod := 1.0
var cold_mod := 1.0
var bleed_mod := 1.0
var blood_regen_mod := 1.0
## set while a caller forces a stun through TRAIT_STUNIMMUNE (tg ignore_canstun)
var ignore_canstun := false

func key() -> StringName:
	return &"health"

func on_added() -> void:
	if blood_type == "":
		blood_type = Body.random_blood_type()

func total() -> float:
	return brute + burn + tox + oxy

func health() -> float:
	return max_health - total()

## tg TRAIT_NOSOFTCRIT / TRAIT_NOHARDCRIT (the tenacity trauma) keep you up past the lines.
func _soft_crit() -> bool:
	return health() <= crit_threshold() and (traumas.is_empty() or not Traumas.no_crit(self)) and not traits.has("nosoftcrit")

## tg crit_threshold: 0, raised by 5 (crazy) or 10 (insane) by low sanity (mood set_crit_threshold)
func crit_threshold() -> float:
	var md = e.c(&"mood") if e else null
	return CRIT + (md.insanity_effect if md else 0.0)

func _hard_crit() -> bool:
	return health() <= HARD_CRIT and (traumas.is_empty() or not Traumas.no_crit(self)) and not traits.has("nohardcrit")

## tg set_stat: DEAD; knocked out (unconscious, asleep, hard crit) is UNCONSCIOUS; soft crit
## (health 0 to -30) is awake but floored and helpless.
func stat() -> int:
	if dead:
		return DEAD
	if knocked_out():
		return UNCONSCIOUS
	if _soft_crit():
		return SOFT_CRIT
	return CONSCIOUS

func in_crit() -> bool:
	return not dead and _soft_crit()

## tg TRAIT_KNOCKEDOUT: unconscious, sleeping, hard crit, and 50+ oxygen loss
## (carbon/check_passout)
func knocked_out() -> bool:
	return dead or sleeping or has_status("unconscious") or has_status("sleeping") or _hard_crit() or (oxy >= Body.OXYLOSS_PASSOUT_THRESHOLD and not traits.has("no_oxyloss_passout"))

## tg TRAIT_INCAPACITATED: stun, paralysis, incapacitate, soft/hard crit, stamcrit
func incapacitated() -> bool:
	return knocked_out() or _soft_crit() or stamcrit or has_status("stun") or has_status("paralyzed") or has_status("incapacitated")

## tg TRAIT_IMMOBILIZED: stun, paralysis, immobilize, knocked out, stamcrit, no limbs to crawl with
func immobilized() -> bool:
	return knocked_out() or stamcrit or has_status("stun") or has_status("paralyzed") or has_status("immobilized") or (Body.usable_legs(self) == 0 and Body.usable_hands(self) == 0)

## tg TRAIT_FLOORED: knockdown, paralysis, crit, stamcrit, no usable legs, buckled to
## something you lie on (a bed). Resting isn't floored: it's a choice (set_resting).
func floored() -> bool:
	return knocked_out() or _soft_crit() or stamcrit or has_status("knockdown") or has_status("paralyzed") or Body.usable_legs(self) == 0 or _buckled_lying()

func _buckled_lying() -> bool:
	var m = e.c(&"mob") if e else null
	if m == null or m.buckled == null or not is_instance_valid(m.buckled):
		return false
	var fu = m.buckled.c(&"furniture")
	return fu != null and fu.kind == "bed" # beds and operating tables

## tg TRAIT_HANDS_BLOCKED: stun, paralysis, crit, knocked out, cuffs
func hands_blocked() -> bool:
	return knocked_out() or _soft_crit() or has_status("stun") or has_status("paralyzed") or cuffed

## tg body_position == LYING_DOWN
func lying() -> bool:
	return body_lying

## tg set_resting (the rest button): lie down now, or get up when you can.
func set_resting(want: bool, silent := true, instant := false) -> void:
	if want == resting:
		return
	resting = want
	if want:
		if body_lying:
			if not silent:
				Game.tell(e, "You will now try to stay lying down on the floor.")
		else:
			if not silent:
				Game.tell(e, "You lay down.")
			_set_lying(true)
	else:
		if not body_lying:
			if not silent:
				Game.tell(e, "You will now try to remain standing up.")
		elif floored():
			if not silent:
				Game.tell(e, "You will now stand up as soon as you are able to.")
		else:
			if not silent:
				Game.tell(e, "You stand up.")
			get_up(instant)

## tg get_up: a 1 second do_after (interrupted by lying back down or being floored again).
func get_up(instant := false) -> void:
	if resting or not body_lying or floored():
		return
	if instant:
		_set_lying(false)
	elif get_up_t < 0.0:
		get_up_t = GET_UP_TIME

## tg set_body_position
func _set_lying(down: bool) -> void:
	get_up_t = -1.0
	if down == body_lying:
		return
	body_lying = down
	var m = e.c(&"mob") if e else null
	if m:
		m._update_pose()
	Bus.mob_state_changed.emit(e)

## tg stamina loss (this game keeps stamina as what's left, 100 = fresh)
func stamina_loss() -> float:
	return 100.0 - stamina

# ------------------------------------------------------------------ tg status effects
## Timed effects: incapacitating ones (stun, knockdown, immobilized, paralyzed,
## incapacitated, unconscious, sleeping) and debuffs (confusion, dizziness, jitter,
## eye_blur, temp_blind, drowsiness, druggy, staggered, dazed, slurring, stutter). tg's
## set_X_if_lower / adjust_X / set_X / remove_status_effect.
const INCAPACITATING := ["stun", "knockdown", "immobilized", "paralyzed", "incapacitated", "unconscious", "sleeping"]
const DEBUFF_MAX := {"confusion": 3600.0, "dizziness": 3600.0, "jitter": 600.0, "eye_blur": 3600.0}
const STUN_TYPES := ["stun", "knockdown", "paralyzed", "immobilized"]

func set_status_if_lower(id: String, t: float) -> void:
	if t > status.get(id, 0.0):
		_set_timed(id, t)

func adjust_status(id: String, t: float, max_t := INF) -> void:
	_set_timed(id, minf(status.get(id, 0.0) + t, max_t))

func set_status(id: String, t: float) -> void:
	_set_timed(id, t)

func remove_status(id: String) -> void:
	_set_timed(id, 0.0)

func has_status(id: String) -> bool:
	return status.get(id, 0.0) > 0.0

func status_left(id: String) -> float:
	return status.get(id, 0.0)

func _set_timed(id: String, t: float) -> void:
	var was := has_status(id)
	var before := stat()
	if t <= 0.0:
		status.erase(id)
	else:
		# tg: incapacitating effects don't stick to the dead; godmode ignores stuns
		if id in INCAPACITATING and (dead or (Game.god_mode and e == Game.player) or traits.has("godmode")):
			return
		# tg TRAIT_STUNIMMUNE (hulks): no stuns, knockdowns, paralysis or immobilising
		if id in STUN_TYPES and traits.has("stunimmune") and not ignore_canstun:
			return
		if id in ["jitter", "dizziness"] and dead:
			return
		status[id] = t
	if id in INCAPACITATING and was != has_status(id) and e != null:
		_sync_posture()
		_check_state(before)
		if id == "unconscious" and not was and not dead:
			pass

## tg Stun/Knockdown/Immobilize/Paralyze/Unconscious/Sleeping: can't go below what's left.
func paralyze(t: float) -> void:
	set_status_if_lower("paralyzed", t)

func immobilize(t: float) -> void:
	set_status_if_lower("immobilized", t)

func incapacitate(t: float) -> void:
	set_status_if_lower("incapacitated", t)

func sleep_for(t: float) -> void:
	if chems.has("nitrosyl_plasmide"):
		return
	set_status_if_lower("sleeping", t * Quirks.sleep_mult(e)) # tg TRAIT_HEAVY_SLEEPER

## tg AllImmobility
func all_immobility(t: float) -> void:
	for id in ["paralyzed", "knockdown", "stun", "immobilized", "unconscious"]:
		set_status_if_lower(id, t)

func can_move() -> bool:
	return not immobilized() and not dead

func can_use_hands() -> bool:
	if Traits.has(e, "animal_body") or e.has_meta("petrified"):
		return false
	if Body.usable_hands(self) == 0:
		return false
	return not incapacitated() and not hands_blocked()

func move_mult() -> float:
	var m := 1.0
	if body_temp < Defs.BODYTEMP_COLD_DAMAGE + 20:
		m += clampf((Defs.BODYTEMP_COLD_DAMAGE + 20 - body_temp) / 40.0, 0.0, 1.0) * 0.8
	if chems.has("methamphetamine"):
		m *= 0.8
	return m

## tg movespeed modifiers that add to the move delay, in seconds (1 ds = 0.1 s):
## damage_slowdown (health deficiency >= 40: deficiency/75), carbon_crawling (+4 ds lying
## down), staggered (+0.85 ds).
func move_add() -> float:
	var a := 0.0
	var deficiency := maxf(MAX_HEALTH - health(), stamina_loss())
	if deficiency >= 40.0 and not chems.has("morphine") and not traits.has("hulk"): # tg: morphine (and hulks) ignore damage slowdown
		a += deficiency / 75.0 * 0.1
	if body_lying: # tg carbon_crawling, on body_position
		a += 0.4
	var md = e.c(&"mood") if e else null
	if md:
		a += md.move_add() # tg /datum/movespeed_modifier/sanity
	a += Addiction.move_add(self)
	if has_status("staggered"):
		a += 0.085
	if has_status("freezing_blast"):
		a += 0.1 # tg /datum/movespeed_modifier/freezing_blast
	if has_status("pepperspray"):
		a += 0.025 # tg /datum/movespeed_modifier/reagent/pepperspray
	if chems.has("freon"):
		a += 0.16
	if chems.has("halon"):
		a += 0.18
	if chems.has("nitrium"):
		a -= 0.065
	return a

func stagger(t: float) -> void:
	set_status_if_lower("staggered", t)

## Damage to one body zone (tg apply_damage with a def_zone -> bodypart/receive_damage):
## wounds and dismemberment are rolled on the bodypart, which caps what it can take.
## `exposed_bonus` is tg exposed_wound_bonus, `proj` marks a projectile.
func hurt_zone(zone: String, amount: float, kind: String, source: Entity, sharp := "", wound_bonus := 0.0, exposed_bonus := 0.0, proj := false) -> void:
	if amount > 0.0 and ((Game.god_mode and e == Game.player) or Traits.has(e, "godmode")): return
	# a missing limb can't be hit; the blow lands on the chest
	if missing.has(Body.part_of(zone)):
		zone = "chest"
	if kind != "brute" and kind != "burn":
		adjust(kind, amount, source)
		return
	if amount <= 0.0:
		adjust(kind, amount, source)
		return
	var from = source.cell if source != null and is_instance_valid(source) and source != e else null
	var dealt := Body.receive_damage(self, zone, amount if kind == "brute" else 0.0, amount if kind == "burn" else 0.0, wound_bonus, exposed_bonus, sharp, from, proj)
	if dealt > 0.0:
		_adjust_total(kind, dealt, source)
		Quirks.glass_jaw(self, zone, kind, dealt, sharp)

## tg take_overall_damage: split evenly over the bodyparts that are there.
func take_overall_damage(brute_amt: float, burn_amt: float, source: Entity = null) -> void:
	var parts := Body.PARTS.keys().filter(func(p): return not missing.has(p))
	if parts.is_empty():
		return
	for p in parts:
		var z: String = Body.PARTS[p]["zones"][0]
		if brute_amt > 0.0:
			hurt_zone(z, brute_amt / parts.size(), "brute", source)
		if burn_amt > 0.0:
			hurt_zone(z, burn_amt / parts.size(), "burn", source)

## tg dismember: the chest takes some of a lost limb's damage (no wounds).
func receive_chest(brute_amt: float, burn_amt: float) -> void:
	if brute_amt > 0.0:
		_adjust_total("brute", Body.receive_damage(self, "chest", brute_amt, 0.0, Body.CANT_WOUND), null)
	if burn_amt > 0.0:
		_adjust_total("burn", Body.receive_damage(self, "chest", 0.0, burn_amt, Body.CANT_WOUND), null)

## Adds damage the bodyparts already took to the mob totals.
func _adjust_total(kind: String, amount: float, source: Entity) -> void:
	var saved := limb.duplicate()
	var saved_b := limb_burn.duplicate()
	adjust(kind, amount, source)
	limb = saved
	limb_burn = saved_b

## Severity bucket 0 fine .. 5 dead, for HUD doll and AI perception.
func severity() -> int:
	if dead:
		return 5
	var hp := health()
	if hp > 90: return 0
	if hp > 65: return 1
	if hp > 35: return 2
	if hp > 0: return 3
	return 4

## `raw`: tg adjust_*_loss straight onto the body, past the physiology modifiers that
## apply_damage uses (burn_mod, damage_resistance).
func adjust(kind: String, amount: float, source: Entity = null, raw := false) -> void:
	if dead and amount > 0 and kind != "brute":
		return
	if amount > 0 and ((Game.god_mode and e == Game.player) or traits.has("godmode")):
		return
	if amount > 0.0 and not raw:
		if kind == "burn":
			RockMetabolism.on_burned(e, amount)
			amount *= burn_mod # tg physiology.burn_mod
		elif kind == "brute":
			amount *= brute_mod
		var dn = e.c(&"dna") if e else null
		if dn and dn.damage_resistance != 0.0 and kind in ["brute", "burn", "tox", "oxy"]:
			amount *= (100.0 - dn.damage_resistance) / 100.0 # tg physiology.damage_resistance
	var before := stat()
	if amount > 0.0 and not traumas.is_empty():
		Traumas.on_damage(self, amount, kind)
	match kind:
		"brute", "burn":
			if amount > 0.0:
				damageoverlaytemp += amount # tg carbon/apply_damage: a brute or burn hit flashes the overlay
			var before_v := brute + burn
			if kind == "brute":
				brute = maxf(0.0, brute + amount)
			else:
				burn = maxf(0.0, burn + amount)
			# healing heals the zones too, in proportion
			if amount < 0.0 and before_v > 0.0 and not limb.is_empty():
				var f := (brute + burn) / before_v
				for z in limb:
					limb[z] *= f
				for z in limb_burn:
					limb_burn[z] *= f
				for p in limb_maxed.keys():
					if Body.part_damage(self, p) < Body.PARTS[p]["max"]:
						limb_maxed.erase(p)
		"tox": tox = maxf(0.0, tox + amount)
		"oxy": oxy = maxf(0.0, oxy + amount)
		"stamina":
			stamina = clampf(stamina - amount, -20.0, 100.0) # tg max_stamina 120 loss
			if amount > 0.0:
				last_stamina_dmg = Game.time
	if amount > 0 and kind != "oxy" and source != null and source != e and is_instance_valid(source) and e.has_c(&"monkeyai") and source.has_c(&"mob"):
		e.c(&"monkeyai").on_attacked(source) # tg COMSIG_ATOM_WAS_ATTACKED
	if amount > 0 and kind != "oxy":
		last_damage_by = source
		last_damage_kind = kind
		if not traits.has("analgesia"): # tg TRAIT_ANALGESIA: no pain
			pain = minf(100.0, pain + amount * 2.0)
		var m = e.c(&"mob")
		if m and amount >= 3:
			m.hurt_flash()
	_check_state(before)

func take_damage(amount: float, kind: String, source: Entity) -> float:
	var inv = e.c(&"inv")
	var a := amount
	if inv and kind == "brute":
		a *= 1.0 - inv.armor()
	if inv and kind == "burn":
		a *= 1.0 - inv.heat_protection() * 0.8
	adjust(kind, a, source)
	return 0.0

func _check_state(before: int) -> void:
	if not dead and health() <= (0.0 if Traits.has(e, "animal_body") else DEAD_AT):
		die()
		return
	if e != null:
		_sync_posture()
	var now := stat()
	if now != before:
		GeneFx.on_stat_changed(e) # tg COMSIG_MOB_STATCHANGE (martyrdom, inexorable)
		var m = e.c(&"mob")
		if m:
			m._update_pose()
			if now == UNCONSCIOUS and before in [CONSCIOUS, SOFT_CRIT]:
				m.stop_pulling()
				_drop_held()
		Bus.mob_state_changed.emit(e)
		if (now == UNCONSCIOUS or now == SOFT_CRIT) and before == CONSCIOUS and in_crit():
			Bus.stimulus.emit({"type": "collapse", "actor": e, "target": e, "cell": e.cell, "loud": 3.0})
			Game.visible_message(e.cell, "%s collapses!" % e.display_name, "bad")

func _drop_held() -> void:
	var inv = e.c(&"inv")
	if inv:
		for h in inv.hands.duplicate():
			if h:
				inv.drop(h)

func die() -> void:
	if dead:
		return
	dead = true
	time_of_death = Game.time
	on_fire = 0.0
	var m = e.c(&"mob")
	if m:
		m.stop_pulling()
		m._update_pose()
	_drop_held()
	Emotes.emote(e, "deathgasp", false, true) # tg death(): carbons always deathgasp
	if Surgery.state(e).is_empty():
		CMood.saw_death(e) # tg send_death_moodlets (not for patients mid-surgery)
	var cause := {"brute": "blunt trauma", "burn": "severe burns", "tox": "poisoning", "oxy": "suffocation", "cold": "hypothermia", "blood": "blood loss", "head": "decapitation"}.get(_dominant(), "unknown causes")
	Bus.stimulus.emit({"type": "death", "actor": last_damage_by, "target": e, "cell": e.cell, "loud": 2.0, "cause": cause})
	Bus.chronicle.emit("%s (%s) died of %s in %s." % [e.display_name, SkyClasses.title_of(e) if m else "?", cause, Game.map.area_at(e.cell).name], 3)
	Bus.mob_died.emit(e)
	Bus.mob_state_changed.emit(e)
	GeneFx.on_stat_changed(e) # tg COMSIG_MOB_STATCHANGE to DEAD

func _dominant() -> String:
	if missing.has("head"):
		return "head"
	if blood_volume < Body.BLOOD_VOLUME_BAD:
		return "blood"
	if body_temp < Defs.BODYTEMP_COLD_DAMAGE - 30:
		return "cold"
	var best := "brute"
	var v := brute
	for k in [["burn", burn], ["tox", tox], ["oxy", oxy]]:
		if k[1] > v:
			best = k[0]
			v = k[1]
	return best

func revive_check() -> void:
	pass

## Back from the dead (a defibrillator): the heart restarts with the body just into crit,
## so they still need treatment.
func revive(defibrillated := false) -> void:
	if not dead or (missing.has("head") and not has_meta("brain_in_chest")) or blood_volume < Body.BLOOD_VOLUME_SURVIVE or Organs.defib_block(self) != "":
		return
	Organs.set_heartattack(self, false)
	if defibrillated:
		# TG HALFWAYCRITDEATH is -50. Keep the damage types proportional when
		# healing a badly injured body; add oxygen loss to a repaired body.
		var target_loss := max_health + 50.0
		var damage := total()
		if damage < target_loss:
			oxy += target_loss - damage
		elif damage > 0.0:
			var heal_fraction := 1.0 - target_loss / damage
			for kind in ["brute", "burn", "tox", "oxy"]:
				adjust(kind, -float(get(kind)) * heal_fraction)
	else:
		oxy = 0.0
		tox = minf(tox, 20.0)
		var over := total() - (MAX_HEALTH - CRIT + 30.0)
		if over > 0.0:
			var t := brute + burn
			if t > 0.0:
				brute -= over * brute / t
				burn -= over * burn / t
		body_temp = maxf(body_temp, Defs.BODYTEMP_NORMAL - 4.0)
	dead = false
	_sync_posture()
	var m = e.c(&"mob")
	if m:
		m._update_pose()
	Bus.mob_state_changed.emit(e)

func stun(t: float) -> void:
	set_status_if_lower("stun", t)

func knockdown(t: float, daze := 0.0) -> void:
	set_status_if_lower("knockdown", t)
	if daze > 0.0:
		set_status_if_lower("dazed", daze)

func wake() -> void:
	if sleeping:
		sleeping = false
		var m = e.c(&"mob")
		if m:
			m._update_pose()
		Bus.mob_state_changed.emit(e)

## tg Unconscious(): out cold for at least `t` seconds.
func knock_out(t: float) -> void:
	set_status_if_lower("unconscious", t * Quirks.sleep_mult(e)) # tg TRAIT_HEAVY_SLEEPER

func fall_asleep() -> void:
	if not sleeping:
		sleeping = true
		var m = e.c(&"mob")
		if m:
			m._update_pose()
		Bus.mob_state_changed.emit(e)

func ignite(t := 12.0) -> void:
	if dead:
		return
	if on_fire <= 0:
		Game.visible_message(e.cell, "%s catches fire!" % e.display_name, "bad")
		Bus.stimulus.emit({"type": "on_fire", "actor": e, "target": e, "cell": e.cell, "loud": 6.0})
	on_fire = maxf(on_fire, t)

## tg carbon/update_damage_hud: the stepped full-screen overlays, as severities.
## brute 0-6 (brute + burn + damageoverlaytemp), oxy 0-7, crit 0-10, critvision 0 or 4-10
## (only below hard crit's line; hard crit is blacked out by unconsciousness instead).
## BYOND switch ranges include both ends and the first match wins, hence the >= / <=.
func damage_hud() -> Dictionary:
	var out := {"brute": 0, "oxy": 0, "crit": 0, "critvision": 0}
	if dead:
		return out
	var hp := health()
	if hp <= crit_threshold():
		out["crit"] = _falling(hp, -10.0, 0, [[-20.0, 1], [-30.0, 2], [-40.0, 3], [-50.0, 4], [-60.0, 6], [-70.0, 7], [-90.0, 8], [-95.0, 9]], 10)
		if stat() != UNCONSCIOUS:
			out["critvision"] = _falling(hp, -4.0, 4, [[-8.0, 5], [-12.0, 6], [-16.0, 7], [-20.0, 8], [-24.0, 9]], 10)
	if oxy > 0.0:
		out["oxy"] = _rising(oxy, 10.0, [[20.0, 1], [25.0, 2], [30.0, 3], [35.0, 4], [40.0, 5], [45.0, 6]], 7)
	var hurt := brute + burn + damageoverlaytemp
	if hurt > 0.0 and not Quirks.has(e, "numb"): # tg TRAIT_NO_DAMAGE_OVERLAY
		out["brute"] = _rising(hurt, 5.0, [[15.0, 1], [30.0, 2], [45.0, 3], [70.0, 4], [85.0, 5]], 6)
	return out

## tg switch(v) with falling ranges "if(low to high)": above `first` nothing matches (the
## default); otherwise the first range whose low end v reaches. [[low, severity]...]
static func _falling(v: float, first: float, default: int, ranges: Array, last: int) -> int:
	if v > first:
		return default
	for r in ranges:
		if v >= r[0]:
			return r[1]
	return last

## The same with rising ranges: below `first` nothing matches (0). [[high, severity]...]
static func _rising(v: float, first: float, ranges: Array, last: int) -> int:
	if v < first:
		return 0
	for r in ranges:
		if v <= r[0]:
			return r[1]
	return last

## Timers that must run smoothly (called every frame by LifeSystem).
func process(delta: float) -> void:
	StatusFx.eyes_tick(self, delta)
	StatusFx.tick(self, delta)
	for i in range(shock_jolts.size() - 1, -1, -1):
		shock_jolts[i] -= delta
		if shock_jolts[i] <= 0.0:
			paralyze(maxf(0.0, 6.0 + shock_jolts[i]))
			shock_jolts.remove_at(i)
	# tg timed_stamina_reset: stamina loss clears 10 s after the last stamina damage
	if stamina < 100.0 and not dead and Game.time - last_stamina_dmg >= 10.0:
		stamina = 100.0
	_update_stamcrit()
	# tg on_floored_start / on_floored_end, whatever caused it (a status running out,
	# healing out of crit, a leg fixed, unbuckling from a bed)
	_sync_posture()
	if get_up_t >= 0.0:
		if resting or floored() or not body_lying:
			get_up_t = -1.0 # tg rest_checks_callback
		else:
			get_up_t -= delta
			if get_up_t <= 0.0:
				_set_lying(false)

var _was_floored := false

## tg on_floored_start / on_floored_end (the trait's signals fire as it changes)
func _sync_posture() -> void:
	var fl := floored()
	if fl != _was_floored:
		_was_floored = fl
		if fl:
			_set_lying(true)
		elif not resting:
			get_up()
	elif resting and not body_lying:
		_set_lying(true)


## tg stamcrit: at 100 stamina loss you drop (floored, immobile, helpless) and take 30
## more; it ends when the loss falls back under 100.
func _update_stamcrit() -> void:
	if not stamcrit and stamina <= 0.0 and not dead:
		stamcrit = true
		if not knocked_out() and health() > CRIT:
			Game.tell(e, "You're too exhausted to keep going...", "warn")
		stamina = maxf(-20.0, stamina - 30.0)
		var m = e.c(&"mob")
		if m:
			m._update_pose()
		Bus.mob_state_changed.emit(e)
	elif stamcrit and (stamina > 0.0 or dead):
		stamcrit = false
		var m2 = e.c(&"mob")
		if m2:
			m2._update_pose()
		Bus.mob_state_changed.emit(e)

func describe_injuries(viewer: Entity = null) -> String:
	if dead or has_status("fakedeath"):
		var dl := "[color=#ff5a4a]%s is limp and unresponsive; there are no signs of life.[/color]" % e.display_name
		for line in Body.describe(self, viewer):
			dl += "\n" + line
		return dl
	var out := []
	if brute > 60: out.append("[color=#ff5a4a]severely wounded[/color]")
	elif brute > 25: out.append("[color=#ffb84a]bruised and bleeding[/color]")
	elif brute > 5: out.append("a little bruised")
	if burn > 50: out.append("[color=#ff5a4a]covered in severe burns[/color]")
	elif burn > 15: out.append("[color=#ffb84a]burned[/color]")
	if tox > 30: out.append("sickly pale")
	if oxy > 30: out.append("[color=#8ab8ff]blue in the lips[/color]")
	if body_temp < 270: out.append("[color=#8ad8ff]shivering violently, frost in their hair[/color]")
	if on_fire > 0: out.append("[color=#ff7a1a]ON FIRE[/color]")
	for jl in StatusFx.examine_lines(self):
		out.append(jl)
	var s := ""
	if not out.is_empty():
		s = "They look %s." % ", ".join(out)
	for line in Body.describe(self, viewer):
		s += ("\n" if s != "" else "") + line
	# tg liver/on_owner_examine (jaundice), fearful/on_examine and embedded objects
	for extra in [Organs.jaundice(self), Traumas.examine(self)] + Embeds.examine_lines(self):
		if extra != "":
			s += ("\n" if s != "" else "") + extra
	if stat() == UNCONSCIOUS:
		s += (" " if s != "" else "") + ("They are asleep." if sleeping and health() > 0 else "[color=#ffb84a]They aren't responding to anything around them.[/color]")
	return s

func examine(_user: Entity, lines: Array) -> void:
	if Traits.has(_user, "entrails_reader"):
		for slot in organs:
			lines.append("%s: %.1f damage%s." % [slot.capitalize(), organs[slot]["dmg"], " (failing)" if organs[slot]["failing"] else ""])
	if e.has_meta("rock_buff"):
		lines.append("Mineral effect: %s (%ds remaining)." % [e.get_meta("rock_buff"), maxi(0, ceili(e.get_meta("rock_buff_until", 0.0) - Game.time))])
	var op := Surgery.describe(e)
	if op != "":
		lines.append(op)
	var d := describe_injuries(_user)
	if d != "":
		lines.append(d)
	if cuffed:
		lines.append("[color=#ffb84a]They are handcuffed.[/color]")

func ai_tags(out: Dictionary) -> void:
	if dead:
		out["corpse"] = true
	elif in_crit():
		out["critical"] = true
	elif health() < 70:
		out["injured"] = true
	if on_fire > 0:
		out["burning"] = true
