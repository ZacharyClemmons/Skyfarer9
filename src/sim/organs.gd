class_name Organs extends RefCounted
## tg internal organs (code/modules/surgery/organs/_organ.dm and internal/*, brain_item.dm).
## Each organ in `CHealth.organs` is {dmg, prev, failing, fail_t} plus its own state; an
## organ that isn't there (spilled, removed) simply has no entry. Eyes and ears keep their
## own damage (CHealth.eye_damage / ear_damage, StatusFx) but take liver failure like tg.
##
## tg runs Life every 2 s with seconds_per_tick 2; this runs once a second with dt 1, so
## tg's per-second rates and SPT_PROB chances carry over unchanged.

const STANDARD_ORGAN_THRESHOLD := 100.0
const STANDARD_ORGAN_HEALING := 50.0 / 100000.0 # fraction of max healed a second
const STANDARD_ORGAN_DECAY := 111.0 / 100000.0 # fraction of max lost a second, dead and warm
const BRAIN_DAMAGE_MILD := 20.0
const BRAIN_DAMAGE_ASYNC_BLINKING := 60.0
const BRAIN_DAMAGE_SEVERE := 100.0
const BRAIN_DAMAGE_DEATH := 200.0
const LIVER_DEFAULT_TOX_TOLERANCE := 3.0
const LIVER_DEFAULT_TOX_RESISTANCE := 1.0
const LIVER_FAILURE_STAGE_SECONDS := 60.0
const MAX_TOXIN_LIVER_DAMAGE := 2.0
const APPENDICITIS_PROB := 100.0 * (0.1 * (1.0 / 25.0) / 3600.0)
const INFLAMATION_ADVANCEMENT_PROB := 2.0
const T0C := 273.15
# tg DISGUST_LEVEL_*
const DISGUST_LEVEL_GROSS := 25.0
const DISGUST_LEVEL_VERYGROSS := 50.0
const DISGUST_LEVEL_DISGUSTED := 75.0
const DISGUST_LEVEL_MAXEDOUT := 150.0

## Processing order is tg's GLOB.organ_process_order (brain first, then the chest).
const ORDER := ["brain", "heart", "lungs", "liver", "stomach", "appendix"]

## max: maxHealth, low/high: thresholds, heal/decay: fractions of max a second.
const DEFS := {
	"brain": {"name": "brain", "max": BRAIN_DAMAGE_DEATH, "low": 45.0, "high": 120.0, "heal": 0.0, "decay": STANDARD_ORGAN_DECAY * 0.5,
		"zone": "head", "proto": "organ_brain"},
	"heart": {"name": "heart", "max": 100.0, "low": 10.0, "high": 45.0, "heal": STANDARD_ORGAN_HEALING, "decay": 2.5 * STANDARD_ORGAN_DECAY,
		"zone": "chest", "proto": "organ_heart",
		"low_passed": "Prickles of pain appear then die out from within your chest...",
		"high_passed": "Something inside your chest hurts, and the pain isn't subsiding. You notice yourself breathing far faster than before.",
		"now_fixed": "Your heart begins to beat again.",
		"high_cleared": "The pain in your chest has died down, and your breathing becomes more relaxed."},
	"lungs": {"name": "lungs", "max": 100.0, "low": 10.0, "high": 45.0, "heal": STANDARD_ORGAN_HEALING, "decay": STANDARD_ORGAN_DECAY * 0.9,
		"zone": "chest", "proto": "organ_lungs",
		"low_passed": "You feel short of breath.",
		"high_passed": "You feel some sort of constriction around your chest as your breathing becomes shallow and rapid.",
		"now_fixed": "Your lungs seem to once again be able to hold air.",
		"low_cleared": "You can breathe normally again.",
		"high_cleared": "The constriction around your chest loosens as your breathing calms down."},
	"liver": {"name": "liver", "max": 100.0, "low": 10.0, "high": 45.0, "heal": STANDARD_ORGAN_HEALING, "decay": STANDARD_ORGAN_DECAY,
		"zone": "chest", "proto": "organ_liver"},
	"stomach": {"name": "stomach", "max": 100.0, "low": 10.0, "high": 45.0, "heal": STANDARD_ORGAN_HEALING, "decay": STANDARD_ORGAN_DECAY * 1.15,
		"zone": "chest", "proto": "organ_stomach",
		"low_passed": "Your stomach flashes with pain before subsiding. Food doesn't seem like a good idea right now.",
		"high_passed": "Your stomach flares up with constant pain- you can hardly stomach the idea of food right now!",
		"high_cleared": "The pain in your stomach dies down for now, but food still seems unappealing.",
		"low_cleared": "The last bouts of pain in your stomach have died out."},
	"appendix": {"name": "appendix", "max": 100.0, "low": 10.0, "high": 45.0, "heal": STANDARD_ORGAN_HEALING, "decay": STANDARD_ORGAN_DECAY,
		"zone": "chest", "proto": "organ_appendix",
		"now_failing": "An explosion of pain erupts in your lower right abdomen!",
		"now_fixed": "The pain in your abdomen has subsided."},
}

## tg /datum/reagent/toxin toxpwr (and liver_damage_multiplier) for this game's toxins.
const TOXINS := {
	"cyanide": {"toxpwr": 1.25}, "plasma": {"toxpwr": 3.0}, "mutagen": {"toxpwr": 0.0},
	"lexorin": {"toxpwr": 0.0}, "chloralhydrate": {"toxpwr": 0.0, "silent": true}, "acid": {"toxpwr": 1.0},
}

static func fresh() -> Dictionary:
	var out := {}
	for k in ORDER:
		out[k] = new_organ(k)
	return out

static func new_organ(slot: String, dmg := 0.0) -> Dictionary:
	var o := {"dmg": dmg, "prev": dmg, "failing": dmg >= DEFS[slot]["max"], "fail_t": 0.0}
	if slot == "heart":
		o["beating"] = true
	if slot == "appendix":
		o["inflamation"] = 0
	if slot == "lungs":
		o["failed"] = false
	return o

static func has(h: CHealth, slot: String) -> bool:
	return h.organs.has(slot)

static func get_organ(h: CHealth, slot: String) -> Dictionary:
	return h.organs.get(slot, {})

static func damage(h: CHealth, slot: String) -> float:
	return h.organs[slot]["dmg"] if h.organs.has(slot) else 0.0

static func failing(h: CHealth, slot: String) -> bool:
	return h.organs.has(slot) and h.organs[slot]["failing"]

## tg adjustOrganLoss / apply_organ_damage: clamps to [0, maximum], checks the thresholds
## and tells the owner (when awake) what they crossed. Returns the net change (tg returns
## prev - damage, so negative when hurt).
static func apply_damage(h: CHealth, slot: String, amount: float, maximum := -1.0) -> float:
	if amount == 0.0 or not h.organs.has(slot):
		return 0.0
	var o: Dictionary = h.organs[slot]
	var d: Dictionary = DEFS[slot]
	var mx: float = d["max"]
	maximum = mx if maximum < 0.0 else clampf(maximum, 0.0, mx)
	if maximum < o["dmg"]:
		return 0.0
	o["dmg"] = clampf(o["dmg"] + amount, 0.0, maximum)
	var net: float = o["prev"] - o["dmg"]
	var msg := _check_thresholds(h, slot, o, d)
	o["prev"] = o["dmg"]
	if msg != "" and not h.knocked_out() and not h.dead:
		Game.tell(h.e, msg, "warn")
	if slot == "brain" and net < 0.0 and o["dmg"] > BRAIN_DAMAGE_MILD:
		_roll_for_brain_trauma(h, -net)
	return net

static func set_damage(h: CHealth, slot: String, amount: float) -> void:
	if h.organs.has(slot):
		apply_damage(h, slot, amount - h.organs[slot]["dmg"])

## tg check_damage_thresholds (and the brain's own messages on top).
static func _check_thresholds(h: CHealth, slot: String, o: Dictionary, d: Dictionary) -> String:
	var dmg: float = o["dmg"]
	var prev: float = o["prev"]
	if dmg == prev:
		return ""
	var msg := ""
	if dmg > prev:
		if dmg > d["low"] and prev <= d["low"]:
			msg = d.get("low_passed", "")
		if dmg > d["high"] and prev <= d["high"]:
			msg = d.get("high_passed", "")
		if dmg >= d["max"]:
			o["failing"] = true
			_on_begin_failure(h, slot)
			msg = d.get("now_failing", "")
	else:
		if prev == d["max"]:
			o["failing"] = false
			msg = d.get("now_fixed", "")
		if prev > d["high"] and dmg <= d["high"]:
			msg = d.get("high_cleared", "")
		if prev > d["low"] and dmg <= d["low"]:
			msg = d.get("low_cleared", "")
	if slot == "brain" and dmg > prev:
		var bm := ""
		if prev < BRAIN_DAMAGE_MILD and dmg >= BRAIN_DAMAGE_MILD:
			bm = "You feel lightheaded."
		elif prev < BRAIN_DAMAGE_SEVERE and dmg >= BRAIN_DAMAGE_SEVERE:
			bm = "You feel less in control of your thoughts."
		elif prev < BRAIN_DAMAGE_DEATH - 20.0 and dmg >= BRAIN_DAMAGE_DEATH - 20.0:
			bm = "You can feel your mind flickering on and off..."
		if bm != "":
			msg = (msg + "\n" + bm) if msg != "" else bm
	return msg

static func _on_begin_failure(_h: CHealth, _slot: String) -> void:
	pass

## tg brain/roll_for_brain_trauma: the hit's damage is the base percent chance.
static func _roll_for_brain_trauma(h: CHealth, delta: float) -> void:
	var dmg := damage(h, "brain")
	if Body.prob(delta * (1.0 + maxf(0.0, (dmg - BRAIN_DAMAGE_MILD) / 100.0))):
		Traumas.gain_type(h, "mild", -1, true)
	if dmg < BRAIN_DAMAGE_SEVERE:
		return
	if Body.prob(delta * (1.0 + maxf(0.0, (dmg - BRAIN_DAMAGE_SEVERE) / 100.0))):
		if Body.prob(20.0):
			Traumas.gain_type(h, "special", -1, true)
		else:
			Traumas.gain_type(h, "severe", -1, true)

# ------------------------------------------------------------------ life
## tg carbon/handle_organs + the organ on_life procs. Called every second, alive or dead.
static func tick(h: CHealth, dt: float) -> void:
	if h.dead:
		# tg organ/on_death: decay while the body is above freezing
		if h.body_temp > T0C:
			var f := minf((h.body_temp - T0C) / 20.0, 1.0)
			for slot in h.organs.keys():
				var d: Dictionary = DEFS[slot]
				apply_damage(h, slot, d["decay"] * d["max"] * dt * f)
		return
	for slot in ORDER:
		if not h.organs.has(slot):
			continue
		_on_life(h, slot, h.organs[slot], dt)
		if h.dead:
			return
	_no_liver(h, dt)
	_heart_attack(h, dt)
	_disgust(h, dt)

## tg organ/on_life: failing organs do their worst, the rest heal a little.
static func _on_life(h: CHealth, slot: String, o: Dictionary, dt: float) -> void:
	var d: Dictionary = DEFS[slot]
	if o["failing"]:
		o["fail_t"] += dt
		_organ_failure(h, slot, o, dt)
	else:
		if o["fail_t"] > 0.0:
			o["fail_t"] = maxf(0.0, o["fail_t"] - dt * 0.5) # tg: -1 a (2 s) tick
		if o["dmg"] > 0.0 and d["heal"] > 0.0:
			apply_damage(h, slot, -d["heal"] * d["max"] * dt, o["dmg"])
	match slot:
		"brain":
			if o["dmg"] >= BRAIN_DAMAGE_DEATH:
				Game.tell(h.e, "[b]The last spark of life in your brain fizzles out...[/b]", "bad")
				h.last_damage_kind = "brain"
				h.die()
		"heart":
			# tg heart/on_life: a failing (or stopped) heart gives out
			if not o["beating"] or o["failing"]:
				if o["beating"]:
					o["beating"] = false
					if not (h.knocked_out() or h.in_crit()):
						Game.visible_message(h.e.cell, "%s clutches at their chest as if their heart is stopping!" % h.e.display_name, "bad")
					Game.tell(h.e, "[b]You feel a terrible pain in your chest, as if your heart has stopped![/b]", "bad")
		"lungs":
			if o["failed"] and not o["failing"]:
				o["failed"] = false
				return
			if o["dmg"] >= d["low"]:
				if Body.spt_prob(2.5 if o["dmg"] < d["high"] else 5.0, dt):
					_emote(h, "cough", true)
			if o["failing"] and not (h.knocked_out() or h.in_crit()) and not o["failed"]:
				Game.visible_message(h.e.cell, "%s grabs their throat, struggling for breath!" % h.e.display_name, "bad")
				Game.tell(h.e, "[b]You suddenly feel like you can't breathe![/b]", "bad")
				o["failed"] = true
		"stomach":
			_stomach(h, o, d, dt)
		"appendix":
			if o["failing"]:
				h.adjust("tox", 2.0 * dt)
			elif o["inflamation"] > 0:
				_inflamation(h, o, dt)
			elif Body.spt_prob(APPENDICITIS_PROB, dt):
				o["inflamation"] = 1

static func _organ_failure(h: CHealth, slot: String, o: Dictionary, dt: float) -> void:
	if slot != "liver":
		return
	# tg liver/organ_failure: a new stage every minute
	var ft: float = o["fail_t"]
	var stage := int(ft / LIVER_FAILURE_STAGE_SECONDS)
	if int((ft - dt) / LIVER_FAILURE_STAGE_SECONDS) != stage:
		match stage:
			1: Game.tell(h.e, "[b]You feel stabbing pain in your abdomen![/b]", "bad")
			2:
				Game.tell(h.e, "[b]You feel a burning sensation in your gut![/b]", "bad")
				vomit(h)
			3:
				Game.tell(h.e, "[b]You feel painful acid in your throat![/b]", "bad")
				vomit(h, true)
			4:
				Game.tell(h.e, "[b]Overwhelming pain knocks you out![/b]", "bad")
				vomit(h, true, 10.0, Game.rng.randi_range(1, 2))
				_emote(h, "scream", true)
				h.adjust_status("unconscious", 2.5)
			5:
				Game.tell(h.e, "[b]You feel as if your guts are about to melt![/b]", "bad")
				vomit(h, true, 10.0, Game.rng.randi_range(1, 3))
				_emote(h, "scream", true)
				h.adjust_status("unconscious", 5.0)
	if stage == 1:
		h.adjust("tox", 0.2 * dt)
		h.disgust = clampf(h.disgust + 0.1 * dt, 0.0, DISGUST_LEVEL_MAXEDOUT)
	elif stage == 2:
		h.adjust("tox", 0.4 * dt)
		h.adjust_status("drowsiness", 0.5 * dt)
		h.disgust = clampf(h.disgust + 0.3 * dt, 0.0, DISGUST_LEVEL_MAXEDOUT)
	elif stage == 3:
		h.adjust("tox", 0.6 * dt)
		_random_organ_loss(h, 0.2 * dt)
		h.adjust_status("drowsiness", 1.0 * dt)
		h.disgust = clampf(h.disgust + 0.6 * dt, 0.0, DISGUST_LEVEL_MAXEDOUT)
		if Body.spt_prob(1.5, dt):
			_emote(h, "drool", true)
	elif stage >= 4:
		h.adjust("tox", 0.8 * dt)
		_random_organ_loss(h, 0.5 * dt)
		h.adjust_status("drowsiness", 1.6 * dt)
		h.disgust = clampf(h.disgust + 1.2 * dt, 0.0, DISGUST_LEVEL_MAXEDOUT)
		if Body.spt_prob(3.0, dt):
			_emote(h, "drool", true)

## tg adjustOrganLoss(pick(HEART, LUNGS, STOMACH, EYES, EARS), amount)
static func _random_organ_loss(h: CHealth, amount: float) -> void:
	match ["heart", "lungs", "stomach", "eyes", "ears"][Game.rng.randi() % 5]:
		"eyes":
			if not h.eyes_removed:
				StatusFx.damage_eyes(h, amount)
		"ears":
			h.ear_damage = clampf(h.ear_damage + amount, 0.0, 100.0)
		var slot:
			apply_damage(h, slot, amount)

## tg carbon/handle_liver: no liver, and the toxins build up and eat the other organs.
static func _no_liver(h: CHealth, dt: float) -> void:
	if h.organs.has("liver"):
		return
	h.adjust("tox", 0.6 * dt)
	_random_organ_loss(h, 0.5 * dt)

## tg human/handle_heart: cardiac arrest (a stopped heart, or none) starves you of oxygen
## and knocks you out; the tissues die without circulation.
static func _heart_attack(h: CHealth, dt: float) -> void:
	if not undergoing_cardiac_arrest(h):
		return
	h.adjust("oxy", 4.0 * dt)
	h.set_status_if_lower("unconscious", 8.0)
	h.adjust("brute", 1.0 * dt)

static func undergoing_cardiac_arrest(h: CHealth) -> bool:
	var ht := get_organ(h, "heart")
	return ht.is_empty() or not ht["beating"]

## tg set_heartattack
static func set_heartattack(h: CHealth, on: bool) -> bool:
	var ht := get_organ(h, "heart")
	if ht.is_empty():
		return false
	if ht["beating"] == (not on):
		return false
	ht["beating"] = not on
	return true

## tg heart/get_blood_regeneration_multiplier: a damaged heart makes blood more slowly,
## a stopped or failing one not at all.
static func blood_regeneration_multiplier(h: CHealth) -> float:
	var ht := get_organ(h, "heart")
	if ht.is_empty() or not ht["beating"] or ht["failing"]:
		return 0.0
	return clampf((DEFS["heart"]["max"] - ht["dmg"]) / DEFS["heart"]["max"], 0.0, 1.0)

## tg carbon/handle_breathing: breathe every 4th tick, one sooner each for lungs and a
## heart past their high thresholds.
static func breath_interval(h: CHealth) -> float:
	var n := 4
	var l := get_organ(h, "lungs")
	if not l.is_empty() and l["dmg"] > DEFS["lungs"]["high"]:
		n -= 1
	var ht := get_organ(h, "heart")
	if not ht.is_empty() and ht["dmg"] > DEFS["heart"]["high"]:
		n -= 1
	return n * 2.0

## tg carbon/breathe: failing lungs miss the breath.
static func lungs_failing(h: CHealth) -> bool:
	return failing(h, "lungs")

# ------------------------------------------------------------------ stomach
## tg stomach/on_life: a damaged stomach can't hold down food (nutriment in the blood here,
## since this game digests straight into the bloodstream).
static func _stomach(h: CHealth, o: Dictionary, d: Dictionary, dt: float) -> void:
	if o["dmg"] < d["low"]:
		return
	var nutri: float = h.chems.get("nutriment", 0.0)
	if nutri <= 0.0:
		return
	if Body.spt_prob(0.0125 * o["dmg"] * nutri * nutri, dt):
		vomit(h, false, o["dmg"])
		Game.tell(h.e, "Your stomach reels in pain as you're incapable of holding down all that food!", "warn")
		return
	if o["dmg"] > d["high"] and Body.spt_prob(0.05 * o["dmg"] * nutri * nutri, dt):
		vomit(h, false, o["dmg"])
		Game.tell(h.e, "Your stomach reels in pain as you're incapable of holding down all that food!", "warn")

## tg stomach/handle_disgust
static func _disgust(h: CHealth, dt: float) -> void:
	if h.disgust <= 0.0:
		return
	if not h.organs.has("stomach"):
		h.disgust = maxf(0.0, h.disgust - 0.25 * dt)
		return
	var pukeprob := 2.5 + 0.025 * h.disgust
	if h.disgust >= DISGUST_LEVEL_GROSS:
		if Body.spt_prob(5.0, dt):
			h.adjust_status("stutter", 2.0)
			h.adjust_status("confusion", 2.0)
		if Body.spt_prob(5.0, dt) and not (h.knocked_out() or h.in_crit()):
			Game.tell(h.e, "You feel kind of iffy...", "warn")
		h.adjust_status("jitter", -6.0)
	if h.disgust >= DISGUST_LEVEL_VERYGROSS:
		if Body.spt_prob(pukeprob, dt):
			h.adjust_status("confusion", 2.5)
			h.adjust_status("stutter", 2.0)
			vomit(h, false, 10.0, 0, true)
			h.disgust = maxf(0.0, h.disgust - 50.0)
		h.set_status_if_lower("dizziness", 10.0)
	if h.disgust >= DISGUST_LEVEL_DISGUSTED:
		if Body.spt_prob(13.0, dt):
			h.set_status_if_lower("eye_blur", 6.0)
	h.disgust = maxf(0.0, h.disgust - 0.25 * dt)

## tg carbon/vomit. `blood` (VOMIT_CATEGORY_BLOOD) splatters blood instead of vomit and
## hurts; `knockdown` (VOMIT_CATEGORY_KNOCKDOWN) floors instead of stunning. Nutrition is
## tg's (0-600), so this game's 0-100 is scaled.
static func vomit(h: CHealth, blood := false, lost_nutrition := 10.0, distance := 1, knockdown := false) -> bool:
	var e := h.e
	var strong := Quirks.has(e, "strong_stomach") # tg TRAIT_STRONG_STOMACH
	if strong:
		lost_nutrition *= 0.5
	var n: CNeeds = e.c(&"needs")
	var nutrition := n.nutrition * Body.NUTRITION_SCALE if n else 300.0
	if not blood and nutrition < 100.0:
		Game.visible_message(e.cell, "%s dry heaves!" % e.display_name, "warn")
		Game.tell(e, "[b]You try to throw up, but there's nothing in your stomach![/b]", "bad")
		if knockdown:
			h.knockdown(20.0)
		else:
			h.stun(10.0 if strong else 20.0)
		return true
	var covered := false
	var inv: CInventory = e.c(&"inv")
	if inv:
		var mask: Entity = inv.worn("mask")
		covered = mask != null
	if covered:
		Game.visible_message(e.cell, "%s throws up all over themself!" % e.display_name, "bad")
		distance = 0
		CMood.event(e, "vomit", "vomitself")
	else:
		Game.visible_message(e.cell, "%s throws up!" % e.display_name, "bad")
		CMood.event(e, "vomit", "vomit")
	if knockdown:
		h.knockdown(8.0)
	else:
		h.stun(8.0)
	Sfx.play("splat" if Sfx.streams.has("splat") else "punch", e.cell, 0.4)
	if not blood:
		if n:
			n.nutrition = maxf(0.0, n.nutrition - lost_nutrition / Body.NUTRITION_SCALE)
		h.adjust("tox", -3.0)
	var m: CMob = e.c(&"mob")
	var dir: Vector2i = Defs.DIRS4[m.dir] if m else Vector2i.ZERO
	var c := e.cell
	for i in distance + 1:
		if blood:
			Body.splatter(c, 50.0, false, h)
			h.adjust("brute", 3.0)
		else:
			Liquids.spill(c, "vomit", 12.0)
		c += dir
		if dir == Vector2i.ZERO or Game.map.blocks_move_static(c) or Game.map.is_solid_turf(c):
			break
	Bus.stimulus.emit({"type": "vomit", "actor": e, "cell": e.cell, "loud": 4.0})
	return true

# ------------------------------------------------------------------ appendix
## tg appendix/inflamation
static func _inflamation(h: CHealth, o: Dictionary, dt: float) -> void:
	if o["inflamation"] < 3 and Body.spt_prob(INFLAMATION_ADVANCEMENT_PROB, dt):
		o["inflamation"] += 1
	match o["inflamation"]:
		1:
			if Body.spt_prob(2.5, dt):
				_emote(h, "cough", true)
		2:
			if Body.spt_prob(1.5, dt):
				Game.tell(h.e, "You feel a stabbing pain in your abdomen!", "warn")
				apply_damage(h, "appendix", 5.0)
				h.stun(Game.rng.randf_range(4.0, 6.0))
				h.adjust("tox", 1.0)
		3:
			if Body.spt_prob(0.5, dt):
				vomit(h, false, 95.0)
				apply_damage(h, "appendix", 15.0)

# ------------------------------------------------------------------ liver and chems
## tg reagents/metabolize, the liver's part: small amounts of toxin under its tolerance are
## filtered harmlessly (returns the reagents it filtered so the caller skips their effects),
## the rest damages the liver. A failing (or missing) liver metabolises nothing.
static func liver_filter(h: CHealth, dt: float) -> Dictionary:
	var skip := {}
	var liver := get_organ(h, "liver")
	if liver.is_empty() or h.dead:
		return skip
	var tolerance: float = LIVER_DEFAULT_TOX_TOLERANCE * (DEFS["liver"]["max"] - liver["dmg"]) / DEFS["liver"]["max"]
	var liver_damage := 0.0
	var pain := false
	for k in h.chems.keys():
		if not TOXINS.has(k):
			continue
		var amount: float = h.chems[k]
		if amount <= tolerance:
			h.chems[k] = maxf(0.0, amount - Chem.REAGENTS_METABOLISM * dt)
			if h.chems[k] <= 0.01:
				h.chems.erase(k)
			skip[k] = true
			continue
		if liver["failing"]:
			continue
		liver_damage += (amount / 15.0) * TOXINS[k]["toxpwr"] / LIVER_DEFAULT_TOX_RESISTANCE
		if not TOXINS[k].get("silent", false):
			pain = true
	if liver_damage > 0.0:
		apply_damage(h, "liver", minf(liver_damage * dt, MAX_TOXIN_LIVER_DAMAGE * dt))
	if pain and liver["dmg"] > 10.0 and Body.spt_prob(liver["dmg"] / 6.0, dt):
		Game.tell(h.e, "You feel a dull pain in your abdomen.", "warn")
	return skip

## tg liver/on_life: a failing or missing liver only lets self-consuming reagents work.
static func liver_works(h: CHealth) -> bool:
	var liver := get_organ(h, "liver")
	return not liver.is_empty() and not liver["failing"]

# ------------------------------------------------------------------ bodies
## Organs that come out with a part (tg chest/dismember drops every chest organ).
static func remove_zone(h: CHealth, zone: String, at: Vector2i) -> Array:
	var out := []
	for slot in ORDER:
		if h.organs.has(slot) and DEFS[slot]["zone"] == zone:
			out.append(remove(h, slot, at))
	return out

## tg organ/Remove + forceMove: the organ item carries its damage out with it.
static func remove(h: CHealth, slot: String, at: Vector2i) -> Entity:
	if not h.organs.has(slot):
		return null
	var o: Dictionary = h.organs[slot]
	h.organs.erase(slot)
	var spr: String = DEFS[slot]["proto"]
	var it := Proto.spawn(spr, at)
	it.tags["organ_dmg"] = o["dmg"]
	if slot == "appendix" and o.get("inflamation", 0) > 0:
		it.tags["inflamation"] = o["inflamation"]
		it.display_name = "inflamed appendix"
		it.set_sprite("items", "organ_appendix_inflamed")
	if o["failing"]:
		it.desc = it.desc + " It has decayed for too long, and has turned a sickly color. It probably won't work without repairs."
	if slot == "brain":
		if o.get("variant", "") == "psyker":
			it.tags["variant"] = "psyker"
			it.display_name = "psyker brain"
			Psyker.detach(h.e)
		SkillChips.detach_brain(h.e, it)
		h.last_damage_kind = "brain"
		h.die()
	return it

## tg organ/Insert: an organ item goes back in (organ manipulation surgery).
static func insert(h: CHealth, slot: String, item: Entity) -> bool:
	if h.organs.has(slot):
		return false
	var o := new_organ(slot, item.tags.get("organ_dmg", 0.0))
	if slot == "appendix":
		o["inflamation"] = item.tags.get("inflamation", 0)
	h.organs[slot] = o
	if slot == "brain":
		SkillChips.restore_brain(h.e, item)
		if item.tags.get("variant", "") == "psyker":
			o["variant"] = "psyker"
			Psyker.attach(h.e)
	item.destroy()
	return true

static func slot_of(proto: String) -> String:
	for slot in DEFS:
		if DEFS[slot]["proto"] == proto:
			return slot
	return ""

## tg can_defib (the organ half): no heart or a failing one, no brain or a failing one.
static func defib_block(h: CHealth) -> String:
	if not h.organs.has("heart"):
		return "no_heart"
	if h.organs["heart"]["failing"]:
		return "failing_heart"
	if not h.organs.has("brain"):
		return "no_brain"
	if h.organs["brain"]["failing"]:
		return "failing_brain"
	return ""

## tg organ get_status_text for the health analyzer.
static func status_text(h: CHealth, slot: String) -> String:
	if not h.organs.has(slot):
		return "Missing"
	var o: Dictionary = h.organs[slot]
	var d: Dictionary = DEFS[slot]
	if slot == "heart" and not o["beating"] and not o["failing"] and not h.dead:
		return "Cardiac Arrest"
	if slot == "appendix" and not o["failing"] and o.get("inflamation", 0) > 0:
		return "Inflamed"
	if o["failing"]:
		return "Non-Functional"
	if o["dmg"] > d["high"]:
		return "Severely Damaged"
	if o["dmg"] > d["low"]:
		return "Mildly Damaged"
	return ""

## tg organ/feel_for_damage (self-examination)
static func feel(h: CHealth, slot: String) -> String:
	if not h.organs.has(slot):
		return ""
	var o: Dictionary = h.organs[slot]
	var d: Dictionary = DEFS[slot]
	var dmg: float = o["dmg"]
	match slot:
		"heart":
			if not o["beating"] or o["failing"]:
				return "Your heart is not beating!"
			if dmg < d["low"]:
				return ""
			return "Your heart hurts." if dmg < d["high"] else "Your heart seriously hurts!"
		"lungs":
			if o["failing"]:
				return "Your lungs hurt madly, and you can't breathe!"
			if dmg < d["low"]:
				return ""
			return "Your lungs feel tight, and breathing is harder." if dmg < d["high"] else "Your lungs feel extremely tight, and every breath is a struggle."
		"liver":
			if dmg < d["low"]:
				return ""
			return "Your liver feels sore." if dmg < d["high"] else "Your liver feels like it's on fire!"
		"stomach":
			if dmg < d["low"]:
				return ""
			return "Your stomach feels sore." if dmg < d["high"] else "Your stomach feels like it's on fire!"
		"brain":
			if dmg < d["low"]:
				return ""
			return "Your brain hurts a bit." if dmg < d["high"] else "Your brain hurts a lot."
		"appendix":
			var stage := floori(o.get("inflamation", 0) + dmg / d["max"])
			match stage:
				1: return "Your appendix feels a little off."
				2: return "Your appendix feels sore."
				_:
					if stage >= 3:
						return "Your appendix feels like it's on fire!"
	return ""

## tg liver/on_owner_examine: the jaundice of a failing liver.
static func jaundice(h: CHealth) -> String:
	if not failing(h, "liver") or h.eyes_removed:
		return ""
	var ft: float = h.organs["liver"]["fail_t"]
	var who := h.e.display_name
	if ft < 3.0 * LIVER_FAILURE_STAGE_SECONDS:
		return "%s's eyes are slightly yellow." % who
	if ft < 4.0 * LIVER_FAILURE_STAGE_SECONDS:
		return "%s's eyes are completely yellow, and they are visibly suffering." % who
	return "[color=#ff5a4a]%s's eyes are completely yellow and swelling with pus. They don't look like they will be alive for much longer.[/color]" % who

## A tg emote by key (`is_key`), else a free-text one.
static func _emote(h: CHealth, text: String, is_key := false) -> void:
	var m: CMob = h.e.c(&"mob")
	if m and is_key:
		m.do_emote(text) # Emotes checks what state you can do it in (snoring asleep...)
	elif m and not h.knocked_out():
		m.emote(text)
