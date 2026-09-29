class_name Body extends RefCounted
## tg bodies, ported from the source:
##   code/modules/surgery/bodyparts/_bodyparts.dm, wounds.dm, dismemberment.dm
##   code/datums/wounds/*.dm (slash, pierce, bones, burns, bruised, cranial_fissure, loss)
##   code/datums/wounds/scars/_scars.dm and strings/wounds/*.json
##   code/modules/mob/living/blood.dm, carbon/life.dm (handle_wounds, handle_blood)
##   code/game/objects/items/stacks/medical.dm, tape.dm (gauze, sutures, mesh, ...)
##   code/datums/status_effects/wound_effects.dm (determined, limp)
##   code/modules/mob/living/carbon/carbon_defense.dm (self-grasp)
##
## Wounds are dictionaries in CHealth.wounds: {id, part, type (the series), sev, flow, ...};
## their static data (tg /datum/wound + /datum/wound_pregen_data) is DEFS[id]. Each part can
## have one piece of gauze or tape on it (tg applied_items[LIMB_ITEM_GAUZE]) in CHealth.gauze.
##
## tg processes wounds and blood every 2 seconds (SSmobs); `handle` takes any dt and scales
## each per-tick probability and rate the way SPT_PROB and seconds_per_tick do.

# ------------------------------------------------------------------ tg defines
const WOUND_DAMAGE_EXPONENT := 1.4
const WOUND_MAX_CONSIDERED_DAMAGE := 25.0
const WOUND_MINIMUM_DAMAGE := 5.0
const DISMEMBER_MINIMUM_DAMAGE := 10.0
const WOUND_DISMEMBER_OUTRIGHT_THRESH := 150.0
const CANT_WOUND := -100.0
const WOUND_MAX_BLOODFLOW := 4.5
const WOUND_SLASH_DAMAGE_FLOW_COEFF := 0.025
const WOUND_BURN_SANITIZATION_RATE := 0.075
const WOUND_INFECTION_MODERATE := 4.0
const WOUND_INFECTION_SEVERE := 8.0
const WOUND_INFECTION_CRITICAL := 12.0
const WOUND_INFECTION_SEPTIC := 20.0
const WOUND_CRITICAL_BLUNT_DISMEMBER_BONUS := 15.0
const WOUND_DETERMINATION := [0.0, 1.0, 2.5, 5.0, 7.5] # by severity (moderate..loss)
const WOUND_DETERMINATION_SEVERE := 2.5
const WOUND_DETERMINATION_MAX := 10.0
const WOUND_DETERMINATION_BLEED_MOD := 0.85
const DETERMINATION_METABOLISM := 0.15 # 0.75 * REAGENTS_METABOLISM, per second
const BLEED_OVERLAY_LOW := 0.5
const BLEED_OVERLAY_MED := 1.5
const BLEED_OVERLAY_GUSH := 3.25
const BLEEDING_MESSAGE_BASE_CD := 10.0
const DISABLED_WOUND_PENALTY := 15.0
const SSMOBS_DT := 2.0 # tg's Life() period; wounds count their ticks in these

const BLOOD_VOLUME_NORMAL := 560.0
const BLOOD_VOLUME_SAFE := BLOOD_VOLUME_NORMAL * (1 - 0.15)
const BLOOD_VOLUME_OKAY := BLOOD_VOLUME_NORMAL * (1 - 0.30)
const BLOOD_VOLUME_RISKY := BLOOD_VOLUME_NORMAL * (1 - 0.45)
const BLOOD_VOLUME_BAD := BLOOD_VOLUME_NORMAL * (1 - 0.60)
const BLOOD_VOLUME_SURVIVE := BLOOD_VOLUME_NORMAL * (1 - 0.80)
const BLOOD_VOLUME_MAXIMUM := 2000.0
const BLOOD_VOLUME_EXCESS := BLOOD_VOLUME_MAXIMUM * 1.05
const BLOOD_VOLUME_MAX_LETHAL := BLOOD_VOLUME_MAXIMUM * 1.075
const BLOOD_REGEN_FACTOR := 0.25
const BLOOD_DRIP_RATE_MOD := 90.0
const BLOOD_STOP_TEMP := 225.0
const BLOOD_AMOUNT_PER_DECAL := 50.0
const OXYLOSS_PASSOUT_THRESHOLD := 50.0
const NUTRITION_LEVEL_WELL_FED := 450.0
const NUTRITION_LEVEL_FED := 350.0
const NUTRITION_SCALE := 6.0 # this game's needs run 0-100; tg's nutrition runs 0-600

## tg bodyparts (default_parts.dm, head.dm): targeting zones, max_damage, wound_resistance,
## throw_range when severed.
const PARTS := {
	"head": {"name": "head", "zones": ["head", "eyes", "mouth"], "max": 200.0, "resist": 5.0, "throw": 2},
	"chest": {"name": "chest", "zones": ["chest", "groin"], "max": 200.0, "resist": 10.0, "throw": 7},
	"l_arm": {"name": "left arm", "zones": ["l_arm", "l_hand"], "max": 50.0, "resist": 0.0, "throw": 7},
	"r_arm": {"name": "right arm", "zones": ["r_arm", "r_hand"], "max": 50.0, "resist": 0.0, "throw": 7},
	"l_leg": {"name": "left leg", "zones": ["l_leg", "l_foot"], "max": 50.0, "resist": 0.0, "throw": 7},
	"r_leg": {"name": "right leg", "zones": ["r_leg", "r_foot"], "max": 50.0, "resist": 0.0, "throw": 7},
}
const LIMBS := ["l_arm", "r_arm", "l_leg", "r_leg"]

## wounding type -> the wound series it rolls in (tg GLOB.wounding_types_to_series); the
## cranial fissure takes WOUND_ALL.
const SERIES_OF := {"slash": "slash", "pierce": "pierce", "blunt": "bone", "burn": "burn"}

## tg wound datums. thr = threshold_minimum, tp = threshold_penalty, stp =
## series_threshold_penalty, mangle = "ext"/"int" (MANGLES_EXTERIOR/INTERIOR), limp =
## limp_slowdown (deciseconds), limpc = limp_chance, eff = interaction_efficiency_penalty,
## dmul = damage_multiplier_penalty, ib/ibc = internal bleeding chance/coefficient,
## regen = regen_ticks_needed, w = pick weight, proj = only from projectiles (true) or never
## (false), demote = demotes_to.
const DEFS := {
	# --- slash.dm
	"abrasion": {"type": "slash", "sev": 1, "name": "Rough Abrasion", "undiag": "Cut", "thr": 20, "tp": 5, "stp": 10,
		"flow": 1.75, "min": 0.5, "clot": 0.04, "scar": "slashmoderate", "snd": "hit",
		"desc": "Patient's skin has been badly scraped, generating moderate blood loss.",
		"treat": "Apply bandaging or suturing to the wound. Follow up with food and a rest period.",
		"examine": "has an open cut", "occur": "is cut open, slowly leaking blood"},
	"laceration": {"type": "slash", "sev": 2, "name": "Open Laceration", "undiag": "Cut", "thr": 50, "tp": 5, "stp": 25,
		"flow": 2.75, "min": 2.0, "clot": 0.02, "demote": "abrasion", "scar": "slashsevere", "snd": "hit",
		"desc": "Patient's skin is ripped clean open, allowing significant blood loss.",
		"treat": "Swiftly apply bandaging or suturing to the wound, or make use of blood clotting agents or cauterization. Follow up with iron supplements or saline-glucose and a rest period.",
		"examine": "has a severe cut", "occur": "is ripped open, veins spurting blood"},
	"avulsion": {"type": "slash", "sev": 3, "name": "Weeping Avulsion", "undiag": "Cut", "thr": 80, "tp": 15, "stp": 0,
		"flow": 3.75, "min": 3.5, "clot": -0.012, "demote": "laceration", "mangle": "ext", "scar": "slashcritical", "snd": "hit",
		"desc": "Patient's skin is completely torn open, along with significant loss of tissue. Extreme blood loss will lead to quick death without intervention.",
		"treat": "Immediately apply bandaging or suturing to the wound, or make use of blood clotting agents or cauterization. Follow up supervised resanguination.",
		"examine": "is carved down to the bone, spraying blood wildly", "occur": "is torn open, spraying blood wildly"},
	# --- pierce.dm
	"breakage": {"type": "pierce", "sev": 1, "name": "Minor Skin Breakage", "undiag": "Puncture", "thr": 30, "tp": 5, "stp": 20, "proj": false,
		"flow": 1.25, "clot": 0.03, "gclot": 0.75, "ib": 30, "ibc": 1.5, "scar": "piercemoderate", "snd": "hit",
		"desc": "Patient's skin has been broken open, causing severe bruising and minor internal bleeding in affected area.",
		"treat": "Apply bandaging or suturing to the wound, make use of blood clotting agents, cauterization, or in extreme circumstances, exposure to extreme cold or vaccuum. Follow with food and a rest period.",
		"examine": "has a small, torn hole, gently bleeding", "occur": "spurts out a thin stream of blood"},
	"breakage_proj": {"type": "pierce", "sev": 1, "name": "Minor Skin Penetration", "undiag": "Puncture", "thr": 30, "tp": 5, "stp": 20, "proj": true,
		"flow": 1.25, "clot": 0.0, "gclot": 0.75, "ib": 30, "ibc": 1.5, "scar": "piercemoderate", "snd": "hit",
		"desc": "Patient's skin has been pierced through, causing severe bruising and minor internal bleeding in affected area.",
		"treat": "Apply bandaging or suturing to the wound, make use of blood clotting agents, cauterization, or in extreme circumstances, exposure to extreme cold or vaccuum. Follow with food and a rest period.",
		"examine": "has a small, circular hole, gently bleeding", "occur": "spurts out a thin stream of blood"},
	"puncture": {"type": "pierce", "sev": 2, "name": "Open Stab Puncture", "undiag": "Puncture", "thr": 50, "tp": 5, "stp": 35, "proj": false,
		"flow": 2.0, "clot": 0.02, "gclot": 0.5, "ib": 60, "ibc": 2.0, "scar": "piercesevere", "snd": "hit",
		"desc": "Patient's internal tissue is penetrated, causing sizeable internal bleeding and reduced limb stability.",
		"treat": "Swiftly apply bandaging or suturing to the wound, make use of blood clotting agents or saline-glucose, cauterization, or in extreme circumstances, exposure to extreme cold or vaccuum. Follow with iron supplements and a rest period.",
		"examine": "is pierced clear through, with bits of tissue obscuring the open hole", "occur": "looses a violent spray of blood, revealing a pierced wound"},
	"puncture_proj": {"type": "pierce", "sev": 2, "name": "Open Bullet Puncture", "undiag": "Puncture", "thr": 50, "tp": 5, "stp": 35, "proj": true,
		"flow": 2.0, "clot": 0.0, "gclot": 0.5, "ib": 60, "ibc": 2.0, "scar": "piercesevere", "snd": "hit",
		"desc": "Patient's internal tissue is penetrated, causing sizeable internal bleeding and reduced limb stability.",
		"treat": "Swiftly apply bandaging or suturing to the wound, make use of blood clotting agents or saline-glucose, cauterization, or in extreme circumstances, exposure to extreme cold or vaccuum. Follow with iron supplements and a rest period.",
		"examine": "is pierced clear through, with bits of tissue obscuring the cleanly torn hole", "occur": "looses a violent spray of blood, revealing a pierced wound"},
	"cavity": {"type": "pierce", "sev": 3, "name": "Ruptured Cavity", "undiag": "Puncture", "thr": 100, "tp": 15, "stp": 0,
		"flow": 2.5, "clot": 0.0, "gclot": 0.3, "ib": 80, "ibc": 2.5, "mangle": "ext", "scar": "piercecritical", "snd": "hit",
		"desc": "Patient's internal tissue and circulatory system is shredded, causing significant internal bleeding and damage to internal organs.",
		"treat": "Immediately apply bandaging or suturing to the wound, make use of blood clotting agents or saline-glucose, cauterization, or in extreme circumstances, exposure to extreme cold or vaccuum. Follow with supervised resanguination.",
		"examine": "is ripped clear through, barely held together by exposed bone", "occur": "blasts apart, sending chunks of viscera flying in all directions"},
	# --- bones.dm
	"dislocation": {"type": "bone", "sev": 1, "name": "Joint Dislocation", "undiag": "Dislocation", "thr": 35, "tp": 5, "stp": 15,
		"eff": 1.3, "limp": 3.0, "limpc": 50, "scar": "dislocate",
		"desc": "Patient's limb has been unset from socket, causing pain and reduced motor function.",
		"treat": "Apply Bonesetter to the affected limb. Manual relocation by via an aggressive grab and a tight hug to the affected limb may also suffice.",
		"examine": "is awkwardly janked out of place", "occur": "janks violently and becomes unseated"},
	"hairline": {"type": "bone", "sev": 2, "name": "Hairline Fracture", "undiag": "Hairline Fracture", "thr": 60, "tp": 5, "stp": 30,
		"eff": 2.0, "limp": 6.0, "limpc": 60, "ib": 40, "mangle": "int", "regen": 120, "trauma": "mild", "trauma_cd": 90.0, "scar": "bluntsevere",
		"desc": "Patient's bone has suffered a crack in the foundation, causing serious pain and reduced limb functionality.",
		"treat": "Repair surgically. In the event of an emergency, an application of bone gel over the affected area will fix over time. A splint or sling of medical gauze can also be used to prevent the fracture from worsening.",
		"examine": "appears grotesquely swollen, jagged bumps hinting at chips in the bone", "occur": "sprays chips of bone and develops a nasty looking bruise"},
	"compound": {"type": "bone", "sev": 3, "name": "Compound Fracture", "thr": 115, "tp": 15, "stp": 0,
		"eff": 2.5, "limp": 7.0, "limpc": 70, "ib": 60, "mangle": "int", "disabling": true, "regen": 240, "trauma": "severe", "trauma_cd": 150.0, "scar": "bluntcritical", "snd": "crack",
		"desc": "Patient's bones have suffered multiple fractures, couped with a break in the skin, causing significant pain and near uselessness of limb.",
		"treat": "Immediately bind the affected limb with gauze or a splint. Repair surgically. In the event of an emergency, bone gel and surgical tape can be applied to the affected area to fix over a long period of time.",
		"examine": "is thoroughly pulped and cracked, exposing shards of bone to open air", "occur": "cracks apart, exposing broken bones to open air"},
	# --- burns.dm
	"burn2": {"type": "burn", "sev": 1, "name": "Second Degree Burns", "undiag": "Burns", "a": "from", "thr": 40, "tp": 15, "stp": 30,
		"dmul": 1.1, "flesh": 5.0, "inf": 0.0, "scar": "burnmoderate", "snd": "sizzle",
		"desc": "Patient is suffering considerable burns with mild skin penetration, weakening limb integrity and increased burning sensations.",
		"treat": "Apply topical ointment or regenerative mesh to the wound.",
		"examine": "is badly burned and breaking out in blisters", "occur": "breaks out with violent red burns"},
	"burn3": {"type": "burn", "sev": 2, "name": "Third Degree Burns", "undiag": "Burns", "a": "from", "thr": 80, "tp": 15, "stp": 40,
		"dmul": 1.2, "flesh": 12.5, "inf": 0.07, "scar": "burnsevere", "snd": "sizzle",
		"desc": "Patient is suffering extreme burns with full skin penetration, creating serious risk of infection and greatly reduced limb integrity.",
		"treat": "Swiftly apply healing aids such as Synthflesh or regenerative mesh to the wound. Disinfect the wound and surgically debride any infected skin, and wrap in clean gauze / use ointment to prevent further infection. If the limb has locked up, it must be amputated, augmented or treated with cryogenics.",
		"examine": "appears seriously charred, with aggressive red splotches", "occur": "chars rapidly, exposing ruined tissue and spreading angry red burns"},
	"burn4": {"type": "burn", "sev": 3, "name": "Catastrophic Burns", "undiag": "Burns", "a": "from", "thr": 140, "tp": 25, "stp": 0,
		"dmul": 1.3, "flesh": 20.0, "inf": 0.075, "scar": "burncritical", "snd": "sizzle",
		"desc": "Patient is suffering near complete loss of tissue and significantly charred muscle and bone, creating life-threatening risk of infection and negligible limb integrity.",
		"treat": "Immediately apply healing aids such as Synthflesh or regenerative mesh to the wound. Disinfect the wound and surgically debride any infected skin, and wrap in clean gauze / use ointment to prevent further infection. If the limb has locked up, it must be amputated, augmented or treated with cryogenics.",
		"examine": "is a ruined mess of blanched bone, melted fat, and charred tissue", "occur": "vaporizes as flesh, bone, and fat melt together in a horrifying mess"},
	# --- bruised.dm (never rolled; the determined status gives it to fists)
	"bruise": {"type": "bruise", "sev": 0, "name": "Bruising", "undiag": "Bruising", "tp": 1, "stp": 0, "random": false, "noscar": true,
		"desc": "Patient's skin appears bruised, showing marks of resistance.", "treat": "Will treat itself overtime.",
		"examine": "", "occur": "gets bruised up"},
	# --- cranial_fissure.dm
	"fissure": {"type": "fissure", "sev": 3, "name": "Cranial Fissure", "thr": 110, "tp": 40, "stp": 0, "w": 10, "zones": ["head"], "all": true, "snd": "punch",
		"desc": "Patient's crown is agape, revealing severe damage to the skull.", "treat": "Surgical reconstruction of the skull is necessary.",
		"examine": "is split open", "occur": "is split into two separated chunks", "scar": "bluntcritical"},
}

## tg gauze and tape (medical.dm /wrap, tape.dm): what sits on the limb.
const WRAPS := {
	"gauze": {"name": "medical gauze", "cap": 5.0, "rate": 0.125, "splint": 0.7, "clean": 0.35, "san": 3.0, "regen": 5.0},
	"improvised_gauze": {"name": "improvised gauze", "cap": 4.0, "rate": 0.075, "splint": 0.85, "clean": 0.7, "san": 1.0, "regen": 3.0},
	"surgical_tape": {"name": "surgical tape", "cap": 0.0, "rate": 0.0, "splint": 0.5, "clean": 1.0, "san": 0.0, "regen": 0.0},
	"splint": {"name": "splint", "cap": 0.0, "rate": 0.0, "splint": 0.5, "clean": 1.0, "san": 0.0, "regen": 0.0},
}

## tg strings/wounds/flesh_scar_desc.json (human limbs are flesh and bone; flesh wins)
const SCAR_DESC := {
	"generic": ["general disfigurement"],
	"dislocate": ["light discoloring", "a slight blue tint", "a slightly deadened tint"],
	"bluntsevere": ["a faded, fist-sized bruise", "a vaguely triangular peel scar"],
	"bluntcritical": ["a section of janky skin lines and badly healed scars", "a large patch of uneven skin tone", "a cluster of calluses"],
	"slashmoderate": ["light, faded lines", "minor cut marks", "a small faded slit", "a series of small scars"],
	"slashsevere": ["a twisted line of faded gashes", "a gnarled sickle-shaped slice scar"],
	"slashcritical": ["a winding path of very badly healed scar tissue", "a series of peaks and valleys along a gruesome line of cut scar tissue", "a grotesque snake of indentations and stitching scars"],
	"piercemoderate": ["a small, faded bruise", "a small twist of reformed skin", "a thumb-sized puncture scar"],
	"piercesevere": ["an ink-splat shaped pocket of scar tissue", "a long-faded puncture wound", "a tumbling puncture hole with evidence of faded stitching"],
	"piercecritical": ["a rippling shockwave of scar tissue", "a wide, scattered cloud of shrapnel marks", "a gruesome multi-pronged puncture scar"],
	"burnmoderate": ["small amoeba-shaped skin-marks", "a faded streak of depressed skin"],
	"burnsevere": ["a large, jagged patch of faded skin", "random spots of shiny, smooth skin", "spots of taut, leathery skin"],
	"burncritical": ["massive, disfiguring keloid scars", "several long streaks of badly discolored and malformed skin", "unmistakable splotches of dead tissue from serious burns"],
	"dismember": ["is several skin tone shades paler than the rest of the body", "is a gruesome patchwork of artificial flesh", "has a large series of attachment scars at the articulation points"],
}
## tg strings/wounds/scar_loc.json
const SCAR_LOC := {
	"head": ["@left_right eyebrow", "@left_right cheekbone", "nose", "neck", "throat", "jawline", "entire face"],
	"chest": ["upper chest", "@upper_lower abdomen", "midsection", "collarbone", "lower back"],
	"l_arm": ["@inner_outer left forearm", "@inner_outer left wrist", "left elbow", "left bicep", "left shoulder", "left hand"],
	"r_arm": ["@inner_outer right forearm", "@inner_outer right wrist", "right elbow", "right bicep", "right shoulder", "right hand"],
	"l_leg": ["@inner_outer left thigh", "@free_move left calf", "@free_move left hip", "left kneecap", "@free_move left shin"],
	"r_leg": ["@inner_outer right thigh", "@free_move right calf", "@free_move right hip", "right kneecap", "@free_move right shin"],
}
const SCAR_PICK := {"inner_outer": ["inner ", "outer ", "", ""], "upper_lower": ["upper ", "lower ", "", ""],
	"free_move": ["inner ", "outer ", "upper ", "lower ", "", ""], "left_right": ["left ", "right "]}
## which worn slots hide a scar on each part (tg scar is_visible: clothing covering the zone)
const SCAR_COVER := {"head": ["mask"], "chest": ["uniform", "suit"], "l_arm": ["uniform", "suit"], "r_arm": ["uniform", "suit"], "l_leg": ["uniform"], "r_leg": ["uniform"]}

## tg blood types (datums/blood_types.dm) and how common they are
const BLOOD_TYPES := {"O-": 4, "O+": 36, "A-": 3, "A+": 28, "B-": 1, "B+": 20, "AB-": 1, "AB+": 5}
const COMPATIBLE := {
	"O-": ["O-"], "O+": ["O-", "O+"], "A-": ["O-", "A-"], "A+": ["O-", "O+", "A-", "A+"],
	"B-": ["O-", "B-"], "B+": ["O-", "O+", "B-", "B+"], "AB-": ["O-", "A-", "B-", "AB-"], "AB+": ["O-", "O+", "A-", "A+", "B-", "B+", "AB-", "AB+"],
}

static func random_blood_type() -> String:
	var total := 0
	for k in BLOOD_TYPES:
		total += BLOOD_TYPES[k]
	var r := Game.rng.randi_range(1, total)
	for k in BLOOD_TYPES:
		r -= BLOOD_TYPES[k]
		if r <= 0:
			return k
	return "O+"

static func prob(p: float) -> bool:
	return Game.rng.randf() * 100.0 < p

## tg SPT_PROB: a per-second probability over dt seconds
static func spt_prob(p: float, dt: float) -> bool:
	return Game.rng.randf() < 1.0 - pow(1.0 - clampf(p / 100.0, 0.0, 1.0), dt)

static func _tell(h: CHealth, msg: String, col := "warn") -> void:
	Game.tell(h.e, msg, col)

## tg visible_message(others, self): the victim reads the second-person line
static func _says(h: CHealth, others: String, self_msg: String, col := "bad") -> void:
	if h.e == Game.player:
		Game.tell(h.e, self_msg, col)
	else:
		Game.visible_message(h.e.cell, others, col)

# ------------------------------------------------------------------ bodypart queries
static func part_of(zone: String) -> String:
	for p in PARTS:
		if zone in PARTS[p]["zones"]:
			return p
	return "chest"

static func pname(part: String) -> String:
	return PARTS[part]["name"]

static func part_damage(h: CHealth, part: String) -> float:
	var d := 0.0
	for z in PARTS[part]["zones"]:
		d += h.limb.get(z, 0.0)
	return d

static func part_burn(h: CHealth, part: String) -> float:
	var d := 0.0
	for z in PARTS[part]["zones"]:
		d += h.limb_burn.get(z, 0.0)
	return d

static func wound_def(w: Dictionary) -> Dictionary:
	return DEFS[w["id"]]

static func wounds_on(h: CHealth, part: String) -> Array:
	return h.wounds.filter(func(w): return w["part"] == part)

## The wound of a series (slash, pierce, bone/blunt, burn, bruise, fissure) on a part.
static func wound_on(h: CHealth, part: String, type: String) -> Dictionary:
	if type == "blunt":
		type = "bone"
	for w in h.wounds:
		if w["part"] == part and w["type"] == type:
			return w
	return {}

static func mangled_state(h: CHealth, part: String) -> int:
	var s := 0
	for w in wounds_on(h, part):
		var m: String = wound_def(w).get("mangle", "")
		if m == "int":
			s |= 1
		elif m == "ext":
			s |= 2
	return s

## tg /datum/wound/set_disabling + update_inefficiencies: a disabling wound paralyses the
## limb unless it's splinted.
static func limb_disabled(h: CHealth, part: String) -> bool:
	if h.missing.has(part):
		return true
	# tg TRAIT_PARALYSIS_<limb> (the paralysis trauma)
	if not h.traumas.is_empty() and Traumas.paralyzed(h, part):
		return true
	for w in wounds_on(h, part):
		if w.get("disabling", false):
			return true
	return false

static func splint_factor(h: CHealth, part: String) -> float:
	var g: Dictionary = h.gauze.get(part, {})
	return g.get("splint", 1.0) if not g.is_empty() else 1.0

static func usable_legs(h: CHealth) -> int:
	var n := 0
	for p in ["l_leg", "r_leg"]:
		if not limb_disabled(h, p):
			n += 1
	return n

static func usable_hands(h: CHealth) -> int:
	var n := 0
	for p in ["l_arm", "r_arm"]:
		if not limb_disabled(h, p):
			n += 1
	return n

## tg limbless movespeed modifier (living.dm update_usable_leg_status), in seconds per step
static func limbless_slowdown(h: CHealth) -> float:
	var legs := usable_legs(h)
	if legs >= 2:
		return 0.0
	var s := (2 - legs) * 3.0
	if legs == 0:
		s += (2 - usable_hands(h)) * 3.0
	return s * 0.1

## tg limp status effect: each step on a wounded leg may add its limp_slowdown to the
## move delay. `parity` alternates legs like tg's next_leg.
static func limp_step(h: CHealth, parity: int) -> float:
	var part := "l_leg" if parity == 0 else "r_leg"
	if h.missing.has(part):
		return 0.0
	var slow := 0.0
	var chance := 0.0
	var sf := splint_factor(h, part)
	for w in wounds_on(h, part):
		var d := wound_def(w)
		slow += d.get("limp", 0.0) * sf
		chance = maxf(chance, d.get("limpc", 0.0) * sf)
	if slow <= 0.0:
		return 0.0
	var det := 0.5 if determined(h) else 1.0
	if prob(chance * det):
		return slow * det * 0.1
	return 0.0

## tg interaction_efficiency_penalty (actionspeed modifier) of the active hand's arm.
static func action_mult(user: Entity) -> float:
	var h: CHealth = user.c(&"health")
	var inv: CInventory = user.c(&"inv")
	if h == null or inv == null:
		return 1.0
	var part := "l_arm" if inv.active == 0 else "r_arm"
	var m := 1.0
	var sf := splint_factor(h, part)
	for w in wounds_on(h, part):
		var eff: float = wound_def(w).get("eff", 1.0)
		if sf < 1.0:
			eff = 1.0 + (eff - 1.0) * sf
		m *= eff
	var md: CMood = user.c(&"mood")
	if md:
		m *= md.action_mult() # tg /datum/actionspeed_modifier/low_sanity, high_sanity
	m *= Addiction.action_mult(h)
	return m

static func wound_damage_multiplier(h: CHealth, part: String) -> float:
	var m := 1.0
	for w in wounds_on(h, part):
		m *= wound_def(w).get("dmul", 1.0)
	return m

static func wounding_type(kind: String, sharp: String) -> String:
	if kind == "burn":
		return "burn"
	if sharp == "edged":
		return "slash"
	if sharp == "pointy":
		return "pierce"
	return "blunt"

## tg wound armour: every piece of clothing covering the part adds its armor[WOUND].
static func wound_armor(h: CHealth, part: String) -> float:
	var inv: CInventory = h.e.c(&"inv")
	if inv == null:
		return 0.0
	var a := 0.0
	var zone: String = PARTS[part]["zones"][0]
	for slot in Combat.COVERS:
		var w: Entity = inv.worn(slot)
		if w and w.has_c(&"clothing") and w.c(&"clothing").covers_zone(zone, slot):
			a += w.c(&"clothing").wound_armor
	return a

# ------------------------------------------------------------------ taking damage
## tg bodypart/receive_damage. Rolls wounds and dismemberment, then puts the damage on the
## part (capped at its max_damage). Returns the damage actually dealt, for the mob's
## totals. `from` is the attacker's cell (tg attack_direction), `proj` a projectile hit.
static func receive_damage(h: CHealth, zone: String, brute: float, burn: float, wound_bonus := 0.0, exposed_bonus := 0.0, sharp := "", from = null, proj := false) -> float:
	var part := part_of(zone)
	if (brute <= 0.0 and burn <= 0.0) or (Game.god_mode and h.e == Game.player):
		return 0.0
	var wmult := wound_damage_multiplier(h, part)
	brute *= wmult
	burn *= wmult
	var type := "blunt" if brute > burn else "burn"
	var dmg := maxf(brute, burn)
	if type == "blunt" and sharp != "":
		type = "slash" if sharp == "edged" else "pierce"
	var dir := _attack_dir(h, from)
	var mangled := mangled_state(h, part)
	# human limbs have skin and bone: once the skin is gone (critical cut/stab), sharp
	# weapons go on into the bone at reduced power
	if (mangled & 2) and not (mangled & 1) and sharp != "":
		if type == "slash":
			dmg *= 0.6
		elif type == "pierce":
			dmg *= 0.75
		type = "blunt"
	if mangled == 3 and _try_dismember(h, part, type, dmg, dir):
		return 0.0
	if dmg >= WOUND_MINIMUM_DAMAGE and wound_bonus != CANT_WOUND and not h.missing.has(part):
		check_wounding(h, part, type, dmg, wound_bonus, exposed_bonus, dir, proj)
	for w in wounds_on(h, part):
		_wound_receive_damage(h, w, type, dmg, wound_bonus, dir)
	# the part can only take so much (tg can_inflict)
	var can_inflict: float = PARTS[part]["max"] - part_damage(h, part)
	var total := brute + burn
	if can_inflict <= 0.0:
		return 0.0
	if total > can_inflict:
		brute *= can_inflict / total
		burn *= can_inflict / total
	h.limb[zone] = h.limb.get(zone, 0.0) + brute + burn
	if burn > 0.0:
		h.limb_burn[zone] = h.limb_burn.get(zone, 0.0) + burn
	# tg update_disabled with LIMB_NO_DISABLE: scream when the limb maxes out
	if part_damage(h, part) >= PARTS[part]["max"]:
		if not h.limb_maxed.has(part) and h.stat() == CHealth.CONSCIOUS:
			_scream(h)
		h.limb_maxed[part] = true
	return brute + burn

static func _attack_dir(h: CHealth, from) -> Vector2i:
	if from is Vector2i and from != h.e.cell:
		var d: Vector2i = h.e.cell - from
		return Vector2i(signi(d.x), signi(d.y))
	return Vector2i.ZERO

static func _scream(h: CHealth) -> void:
	if h.dead or h.stat() != CHealth.CONSCIOUS:
		return
	var m: CMob = h.e.c(&"mob")
	if m:
		m.do_emote("scream") # tg painful_scream (sound and all)

## tg bodypart/check_wounding + check_woundings_mods + check_series_wounding_mods.
static func check_wounding(h: CHealth, part: String, type: String, damage: float, wound_bonus: float, exposed_bonus: float, dir := Vector2i.ZERO, proj := false) -> Dictionary:
	damage = minf(damage, WOUND_MAX_CONSIDERED_DAMAGE * Quirks.wound_cap_mult(h.e)) # tg TRAIT_EASILY_WOUNDED
	var base_roll := Game.rng.randi_range(1, maxi(1, roundi(pow(damage, WOUND_DAMAGE_EXPONENT))))
	var injury := float(base_roll)
	# --- check_woundings_mods
	var ablation := wound_armor(h, part)
	injury += wound_bonus
	for w in wounds_on(h, part):
		injury += wound_def(w).get("tp", 0.0) * w.get("tp_mult", 1.0)
	if mangled_state(h, part) == 0:
		ablation += PARTS[part]["resist"]
	if part_damage(h, part) >= PARTS[part]["max"]:
		injury += DISABLED_WOUND_PENALTY
	if ablation <= 0.0:
		injury += exposed_bonus
	else:
		injury *= (100.0 - ablation) / 100.0
	var series_mods := {}
	for w in wounds_on(h, part):
		series_mods[w["type"]] = series_mods.get(w["type"], 0.0) + wound_def(w).get("stp", 0.0)
	# --- a huge roll on a hurt limb takes it right off
	if injury > WOUND_DISMEMBER_OUTRIGHT_THRESH and prob(part_damage(h, part) / PARTS[part]["max"] * 100.0) and can_dismember(h, part):
		_apply_dismember(h, part, type, true, dir)
		return {}
	var series: String = SERIES_OF.get(type, "")
	var possible := {}
	for id in DEFS:
		var d: Dictionary = DEFS[id]
		if d.get("random", true) == false:
			continue
		if d["type"] != series and not d.get("all", false):
			continue
		if not part in d.get("zones", PARTS.keys()):
			continue
		if injury + series_mods.get(d["type"], 0.0) < d["thr"]:
			continue
		if not _can_apply(h, part, id):
			continue
		var weight: float = d.get("w", 50.0)
		if d.has("proj") and d["proj"] != proj:
			weight = 0.0
		if id == "fissure" and h.health() > CHealth.HARD_CRIT:
			weight = 0.0 # tg: only while in hard crit
		possible[id] = weight
	# WOUND_COMPETITION_OVERPOWER_LESSERS: the worst possible wounds beat the lesser ones
	var top := 0
	for id in possible:
		top = maxi(top, DEFS[id]["sev"])
	var picks := {}
	for id in possible:
		if DEFS[id]["sev"] == top and possible[id] > 0.0:
			picks[id] = possible[id]
	if picks.is_empty():
		return {}
	var pick := _pick_weight(picks)
	return apply_wound(h, part, pick, dir)

## tg wound_pregen_data/can_be_applied_to: no sidegrades or downgrades within a series,
## no exact duplicates.
static func _can_apply(h: CHealth, part: String, id: String) -> bool:
	var d: Dictionary = DEFS[id]
	if h.missing.has(part):
		return false
	for w in wounds_on(h, part):
		if w["type"] == d["type"] and w["sev"] >= d["sev"]:
			return false
	return true

static func _pick_weight(opts: Dictionary) -> String:
	var total := 0.0
	for k in opts:
		total += opts[k]
	var r := Game.rng.randf() * total
	for k in opts:
		r -= opts[k]
		if r <= 0.0:
			return k
	return opts.keys()[0]

## tg force_wound_upwards / apply_wound / replace_wound: puts the wound on (replacing a
## lesser one of the same series) and announces it.
static func apply_wound(h: CHealth, part: String, id: String, dir := Vector2i.ZERO, silent := false) -> Dictionary:
	var d: Dictionary = DEFS[id]
	var old := {}
	for w in wounds_on(h, part):
		if w["type"] == d["type"]:
			if w["sev"] >= d["sev"]:
				return {}
			old = w
	var w := {"id": id, "part": part, "type": d["type"], "sev": d["sev"], "flow": 0.0}
	if not old.is_empty():
		# replace_wound: the old one goes without scarring
		h.wounds.erase(old)
		w["scar"] = old.get("scar", {})
		for k in ["infection", "sanit", "fheal", "strikes", "gel", "taped", "regen_t"]:
			if old.has(k):
				w[k] = old[k]
	h.wounds.append(w)
	var demoted: bool = not old.is_empty() and d["sev"] <= old["sev"]
	_wound_injury(h, w, old, dir)
	if d["sev"] == 0:
		return w
	if not silent and not demoted:
		var occur: String = d["occur"]
		if id == "compound" and part == "head":
			occur = "splits open, exposing a bare, cracked skull through the flesh and blood"
		var msg := "%s's %s %s!" % [h.e.display_name, pname(part), occur]
		if d["sev"] > 2:
			msg = "[b]%s[/b]" % msg
		_says(h, msg, "[b]Your %s %s![/b]" % [pname(part), occur])
		var snd: String = d.get("snd", "punch")
		Sfx.play(snd if snd in ["punch", "hit"] else "punch", h.e.cell, 0.5 + 0.2 * d["sev"])
	if not demoted:
		second_wind(h, d["sev"])
	return w

## tg wound_injury (per type) run when the wound lands.
static func _wound_injury(h: CHealth, w: Dictionary, old: Dictionary, dir: Vector2i) -> void:
	var d := wound_def(w)
	var part: String = w["part"]
	match w["type"]:
		"slash":
			if not old.is_empty():
				w["flow"] = maxf(old.get("flow", 0.0), d["flow"])
			else:
				w["flow"] = d["flow"]
				if dir != Vector2i.ZERO and h.blood_volume > BLOOD_VOLUME_OKAY:
					spray_blood(h, dir, d["sev"])
			# tg highest_scar: a demoted cut keeps the worse cut's scar
			if old.is_empty() or old["sev"] <= d["sev"] or w.get("scar", {}).is_empty():
				w["scar"] = make_scar(part, d)
		"pierce":
			w["flow"] = d["flow"]
			if dir != Vector2i.ZERO and h.blood_volume > BLOOD_VOLUME_OKAY:
				spray_blood(h, dir, d["sev"])
		"bone":
			if part == "head" and d.has("trauma"):
				w["trauma_t"] = Game.time + Game.rng.randf_range(0.8, 1.2) * d["trauma_cd"]
				_head_trauma(h, w)
			# a broken arm drops what that hand held
			if part in ["l_arm", "r_arm"]:
				var inv: CInventory = h.e.c(&"inv")
				if inv:
					var held: Entity = inv.hands[0 if part == "l_arm" else 1]
					if held and (d.get("disabling", false) or prob(30.0 * d["sev"])):
						inv.drop(held)
						_says(h, "%s drops %s in shock!" % [h.e.display_name, held.the()], "[b]The force on your %s causes you to drop %s![/b]" % [pname(part), held.the()])
			w["disabling"] = d.get("disabling", false) and splint_factor(h, part) >= 1.0
		"burn":
			w["flesh"] = d["flesh"]
			w["infection"] = w.get("infection", 0.0)
			w["sanit"] = w.get("sanit", 0.0)
			w["fheal"] = w.get("fheal", 0.0)
			w["strikes"] = w.get("strikes", 3)
		"bruise":
			w["ticks"] = 25
		"fissure":
			pass

## tg /datum/wound/second_wind: fresh wounds dump determination into the blood.
static func second_wind(h: CHealth, sev: int) -> void:
	if sev <= 0 or sev >= WOUND_DETERMINATION.size():
		return
	h.determination = minf(WOUND_DETERMINATION_MAX, h.determination + WOUND_DETERMINATION[sev])

static func determined(h: CHealth) -> bool:
	return h.determined

## tg receive_damage per wound: more blood from cuts, internal bleeding from stabs and
## cracked ribs.
static func _wound_receive_damage(h: CHealth, w: Dictionary, type: String, dmg: float, wound_bonus: float, dir: Vector2i) -> void:
	var d := wound_def(w)
	match w["type"]:
		"slash":
			if not h.dead and wound_bonus != CANT_WOUND and type == "slash":
				adjust_flow(h, w, WOUND_SLASH_DAMAGE_FLOW_COEFF * dmg)
		"pierce":
			if h.dead or dmg < 5.0 or h.blood_volume <= 0.0 or not prob(d.get("ib", 0.0) + dmg):
				return
			var bled: float = sqrt(dmg) * d.get("ibc", 1.0) * splint_factor(h, w["part"]) * [0.75, 1.0, 1.25, 1.5][Game.rng.randi() % 4]
			var where := pname(w["part"])
			if bled >= 18.0:
				_says(h, "A spray of blood streams from the gash in %s's %s!" % [h.e.display_name, where], "You choke up on a spray of blood from the blow to your %s!" % where)
			elif bled >= 12.0:
				_says(h, "A small stream of blood spurts from the hole in %s's %s!" % [h.e.display_name, where], "You spit out a string of blood from the blow to your %s!" % where, "warn")
			elif bled >= 8.0:
				_says(h, "Blood droplets fly from the hole in %s's %s." % [h.e.display_name, where], "You cough up a bit of blood from the blow to your %s." % where, "warn")
			bleed(h, bled)
			if bled >= 18.0:
				spray_blood(h, dir, 3)
		"bone":
			if dmg < WOUND_MINIMUM_DAMAGE or w["part"] != "chest" or h.blood_volume <= 0.0 or not prob(d.get("ib", 0.0) + dmg):
				return
			var bled2 := float(Game.rng.randi_range(1, maxi(1, int(dmg * (2.0 if w["sev"] == 3 else 1.5)))))
			var who := h.e.display_name
			if bled2 >= 20.0:
				_says(h, "Blood spurts out of %s's mouth from the blow to their chest!" % who, "You choke up on a spray of blood from the blow to your chest!")
				bleed(h, bled2)
				splatter(h.e.cell, 10.0, false, h)
				var ahead: Vector2i = h.e.cell
				if h.e.has_c(&"mob"):
					ahead += Defs.DIRS4[h.e.c(&"mob").dir]
				splatter(ahead, 10.0, false, h)
			elif bled2 >= 14.0:
				_says(h, "Blood spews out of %s's mouth from the blow to their chest!" % who, "You spit out a string of blood from the blow to your chest!")
				splatter(h.e.cell, 10.0, false, h)
				bleed(h, bled2)
			elif bled2 >= 7.0:
				_says(h, "A thin stream of blood drips from %s's mouth from the blow to their chest." % who, "You cough up a bit of blood from the blow to your chest.", "warn")
				bleed(h, bled2, true)
			else:
				bleed(h, bled2, true)

## tg adjust_blood_flow for slashes and stabs: capped at WOUND_MAX_BLOODFLOW; a cut below
## its minimum_flow demotes to the lesser cut (or closes); a stab at 0 closes.
static func adjust_flow(h: CHealth, w: Dictionary, by: float) -> void:
	if by == 0.0 or not w in h.wounds:
		return
	var d := wound_def(w)
	w["flow"] = clampf(w["flow"] + by, 0.0, WOUND_MAX_BLOODFLOW)
	match w["type"]:
		"slash":
			if w["flow"] < d.get("min", 0.0):
				if d.has("demote"):
					var nw := {"id": d["demote"], "part": w["part"], "type": "slash", "sev": DEFS[d["demote"]]["sev"], "flow": w["flow"], "scar": w.get("scar", {})}
					h.wounds[h.wounds.find(w)] = nw
					nw["flow"] = maxf(w["flow"], DEFS[d["demote"]]["flow"])
				else:
					_tell(h, "The cut on your %s has stopped bleeding!" % pname(w["part"]), "good")
					remove_wound(h, w)
		"pierce":
			if w["flow"] <= 0.0:
				_tell(h, "The holes on your %s have stopped bleeding!" % pname(w["part"]), "good")
				remove_wound(h, w)

## tg remove_wound: leaves a scar (tg datum/scar/generate) unless replaced.
static func remove_wound(h: CHealth, w: Dictionary, scar := true) -> void:
	if not w in h.wounds:
		return
	h.wounds.erase(w)
	var d := wound_def(w)
	# tg bone/remove_wound: QDEL_NULL(active_trauma)
	if w.has("trauma_uid"):
		var t := Traumas.find(h, w["trauma_uid"])
		if not t.is_empty():
			Traumas.lose(h, t)
	if scar and not d.get("noscar", false) and not h.missing.has(w["part"]):
		var s: Dictionary = w.get("scar", {})
		if s.is_empty():
			s = make_scar(w["part"], d)
		if not s.is_empty():
			h.scars.append(s)
	if wounds_on(h, w["part"]).is_empty() and h.gauze.has(w["part"]) and not h.missing.has(w["part"]):
		var g: Dictionary = h.gauze[w["part"]]
		h.gauze.erase(w["part"])
		_says(h, "The %s on %s's %s falls away." % [g["name"], h.e.display_name, pname(w["part"])], "The %s on your %s falls away." % [g["name"], pname(w["part"])], "info")

static func make_scar(part: String, d: Dictionary) -> Dictionary:
	var key: String = d.get("scar", "generic")
	var opts: Array = SCAR_DESC.get(key, SCAR_DESC["generic"])
	var loc: String = SCAR_LOC[part][Game.rng.randi() % SCAR_LOC[part].size()]
	if loc.begins_with("@"):
		var sp := loc.substr(1).split(" ", true, 1)
		var pk: Array = SCAR_PICK[sp[0]]
		loc = pk[Game.rng.randi() % pk.size()] + sp[1]
	var sev: int = d.get("sev", 1)
	return {"part": part, "sev": sev, "desc": opts[Game.rng.randi() % opts.size()], "loc": loc, "vis": [0, 2, 3, 5, 7][clampi(sev, 0, 4)]}

# ------------------------------------------------------------------ dismemberment
## tg can_dismember: heads never come off from wounds (head.can_dismember = FALSE); the
## chest only "comes apart" (organs spill) in hard crit.
static func can_dismember(h: CHealth, part: String) -> bool:
	if h.missing.has(part):
		return false
	if part == "head":
		return false
	if part == "chest":
		return h.health() <= CHealth.HARD_CRIT and not h.eviscerated
	return true

## tg bodypart/try_dismember
static func _try_dismember(h: CHealth, part: String, type: String, dmg: float, dir: Vector2i) -> bool:
	if not can_dismember(h, part) or dmg < DISMEMBER_MINIMUM_DAMAGE:
		return false
	var chance: float = dmg + part_damage(h, part) / PARTS[part]["max"] * 50.0
	for w in wounds_on(h, part):
		if w["type"] == "bone" and w["sev"] >= 3:
			chance += WOUND_CRITICAL_BLUNT_DISMEMBER_BONUS
	if prob(chance):
		_apply_dismember(h, part, type, false, dir)
		return true
	return false

## tg /datum/wound/loss/apply_dismember + get_dismember_message
static func _apply_dismember(h: CHealth, part: String, type: String, outright: bool, dir: Vector2i) -> void:
	var occur := ""
	var self_msg := ""
	if part == "chest":
		occur = "is split open, causing their internal organs to spill out!"
		self_msg = "is split open, causing your internal organs to spill out!"
	elif outright:
		occur = {"blunt": "is outright smashed to a gross pulp, severing it completely!", "slash": "is outright slashed off, severing it completely!",
			"pierce": "is outright blasted apart, severing it completely!", "burn": "is outright incinerated, falling to dust!"}[type]
	else:
		occur = {"blunt": "is shattered through the last bone holding it together, severing it completely!", "slash": "is slashed through the last tissue holding it together, severing it completely!",
			"pierce": "is pierced through the last tissue holding it together, severing it completely!", "burn": "is completely incinerated, falling to dust!"}[type]
	_says(h, "[b]%s's %s %s[/b]" % [h.e.display_name, pname(part), occur], "[b]Your %s %s[/b]" % [pname(part), self_msg if self_msg != "" else occur])
	second_wind(h, 4)
	if type != "burn" and h.blood_volume > 0.0:
		spray_blood(h, dir, 4)
	dismember(h, part, type)

## tg bodypart/dismember (+ chest/dismember, drop_limb and the arm/leg/head overrides).
static func dismember(h: CHealth, part: String, type := "slash") -> bool:
	if h.missing.has(part):
		return false
	var e := h.e
	if part == "chest":
		# tg chest/dismember: the organs come out; the chest stays
		if type != "burn":
			splatter(e.cell, 25.0, false, h)
		Sfx.play("punch", e.cell, 1.2)
		# every chest organ spills (heart, lungs, liver, stomach, appendix); without them
		# the heart stops and the lungs can't breathe, which does the rest
		for o in Organs.remove_zone(h, "chest", e.cell):
			if o:
				o.place(_near(e.cell))
		h.eviscerated = true
		return true
	# the chest takes a share of the limb's damage (tg: clamp(dam/2, 15, 50))
	var pb := part_burn(h, part)
	var pbr := part_damage(h, part) - pb
	var chest_brute := clampf(pbr / 2.0, 15.0, 50.0)
	var chest_burn := clampf(pb / 2.0, 0.0, 50.0)
	_scream(h)
	CMood.event(e, "dismembered", "dismembered")
	Sfx.play("punch", e.cell, 1.5)
	# drop_limb: its wounds and gauze go with it, its damage leaves the body
	for w in wounds_on(h, part):
		h.wounds.erase(w)
	h.gauze.erase(part)
	if h.grasp == part or (h.grasp != "" and part in ["l_arm", "r_arm"]):
		Interact.release_grasp(e)
	for z in PARTS[part]["zones"]:
		var dz: float = h.limb.get(z, 0.0)
		var bz: float = h.limb_burn.get(z, 0.0)
		h.brute = maxf(0.0, h.brute - (dz - bz))
		h.burn = maxf(0.0, h.burn - bz)
		h.limb.erase(z)
		h.limb_burn.erase(z)
	h.limb_maxed.erase(part)
	h.missing[part] = true
	h.dismembered_by[part] = type
	var inv: CInventory = e.c(&"inv")
	if inv:
		match part:
			"l_arm":
				if inv.hands[0]:
					inv.drop(inv.hands[0])
			"r_arm":
				if inv.hands[1]:
					inv.drop(inv.hands[1])
			"l_leg", "r_leg":
				var sh: Entity = inv.worn("shoes")
				if sh and h.missing.has("l_leg") and h.missing.has("r_leg"):
					inv.drop(sh)
			"head":
				for s in ["head", "mask", "eyes", "ears"]:
					var it: Entity = inv.worn(s)
					if it:
						inv.drop(it)
		if part in ["l_arm", "r_arm"] and h.cuffed:
			h.cuffed = false
	h.receive_chest(chest_brute, chest_burn)
	var m: CMob = e.c(&"mob")
	if m:
		m._update_pose()
	if part == "head" and not h.dead and not h.has_meta("brain_in_chest"): # tg H.A.R.S. keeps the brain in the chest
		h.die()
	if type == "burn":
		# tg bodypart/burn: it's ash
		if Proto.has("ash"):
			Proto.spawn("ash", e.cell)
		return true
	bleed(h, Game.rng.randf_range(20.0, 40.0))
	var spr := "limb_head" if part == "head" else ("limb_arm" if part.ends_with("arm") else "limb_leg")
	var nm := "%s's %s" % [e.display_name, pname(part)]
	var lim := Proto.spawn("severed_limb", e.cell, {"name": nm, "spr": spr})
	lim.tags["limb_part"] = part
	lim.tags["limb_material"] = h.body_materials.get(part, "flesh")
	h.body_materials.erase(part)
	lim.tags["limb_owner"] = e.display_name
	# thrown a few tiles in a random cardinal direction (tg throw_at)
	var d: Vector2i = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT][Game.rng.randi() % 4]
	var t_range := Game.rng.randi_range(2, maxi(PARTS[part]["throw"] / 2, 2))
	var to := e.cell
	for i in t_range - 1:
		var n: Vector2i = to + d
		if not Game.map.inb(n) or Game.map.blocks_move_static(n) or Game.map.is_solid_turf(n):
			break
		to = n
	Interact.glide(lim, to, 0.08 * maxi(1, (to - e.cell).length()), true)
	return true

static func _near(c: Vector2i) -> Vector2i:
	var opts := [c]
	for d in Defs.DIRS8:
		var n: Vector2i = c + d
		if Game.map.inb(n) and not Game.map.blocks_move_static(n):
			opts.append(n)
	return opts[Game.rng.randi() % opts.size()]

## tg gib(): the body bursts into gibs, organs and limbs. Anything they were carrying drops.
static func gib(h: CHealth) -> void:
	var e := h.e
	if e.removed:
		return
	var c := e.root_cell()
	Game.visible_message(c, "[b]%s explodes in a shower of gore![/b]" % e.display_name, "bad")
	Sfx.play("explosion", c, 0.6)
	if not h.dead:
		h.die()
	var inv: CInventory = e.c(&"inv")
	if inv:
		for hnd in inv.hands.duplicate():
			if hnd:
				inv.drop(hnd, _near(c))
		for s in inv.slots.keys():
			var it2: Entity = inv.slots[s]
			if it2:
				inv.drop(it2, _near(c))
	# tg /obj/effect/gibspawner/human: gibs up, down, body, limbs and the core, streaked
	# out in random directions
	var kinds := ["gore_gib_%d" % (Game.rng.randi() % 6), "gore_gib_%d" % (Game.rng.randi() % 6), "gore_gibtorso" if Game.rng.randf() < 0.5 else "gore_gibhead",
		"gore_gibarm" if Game.rng.randf() < 0.5 else "gore_gibleg", "gore_gibmid_%d" % (Game.rng.randi() % 3), "gore_gib_%d" % (Game.rng.randi() % 6)]
	Proto.spawn("gibs", c, {"spr": kinds[4]})
	for k in kinds.size():
		if k == 4:
			continue
		var d: Vector2i = Defs.DIRS8[Game.rng.randi() % 8]
		var to := c
		for step in Game.rng.randi_range(0, 2):
			var n2 := to + d
			if not Game.map.inb(n2) or Game.map.is_solid_turf(n2) or Game.map.blocks_move_static(n2):
				break
			to = n2
			splatter(to, 50.0, false, h) # tg gibs/streak leave splatters on the way
		var g := Proto.spawn("gibs", c, {"spr": kinds[k]})
		if to != c:
			Interact.glide(g, to, 0.1 * maxi(1, (to - c).length()))
	# tg DROP_ALL_REMAINS: organs and every remaining bodypart
	for slot in Organs.ORDER:
		if Organs.has(h, slot):
			Organs.remove(h, slot, _near(c))
	if not h.missing.has("head") and not h.eyes_removed:
		h.eyes_removed = true
		Proto.spawn("organ_eyes", _near(c))
	for p in LIMBS + ["head"]:
		if not h.missing.has(p):
			var lim := Proto.spawn("severed_limb", _near(c), {"name": "%s's %s" % [e.display_name, pname(p)], "spr": "limb_head" if p == "head" else ("limb_arm" if p.ends_with("arm") else "limb_leg")})
			lim.tags["limb_part"] = p
			lim.tags["limb_material"] = h.body_materials.get(p, "flesh")
			lim.tags["limb_owner"] = e.display_name
	splatter(c, 60.0, false, h)
	Bus.stimulus.emit({"type": "gibbed", "actor": h.last_damage_by, "target": e, "cell": c, "loud": 8.0})
	e.set_meta("gibbed", true)
	if e == Game.player:
		e.visible = false
		e.remove_comp(&"blocker")
		return
	e.destroy()

# ------------------------------------------------------------------ blood on the floor
## tg /datum/blood_type/proc/make_blood_splatter. A drip adds a drop to the drips on the
## tile (or a little to a wet splatter already there); a sixth drop turns the drips into a
## pool. Otherwise a wet pool gets bloodier, or a new pool is made. `volume` is unused
## (tg pools don't grow in size, only in bloodiness).
static func splatter(c: Vector2i, _volume := 50.0, small_drip := false, from: CHealth = null) -> Entity:
	var sp := _splatter(c, small_drip)
	if sp and from:
		Forensics.add_blood(sp, from) # tg: the pool carries whose blood it is
	return sp

static func _splatter(c: Vector2i, small_drip: bool) -> Entity:
	if not Game.map.inb(c) or Game.map.is_solid_turf(c) or Game.map.blocks_move_static(c):
		return null
	var drop: Entity = null
	var pool: Entity = null
	for d in Game.at(c):
		var dc: CDecal = d.c(&"decal")
		if dc == null or not dc.blood or dc.dried:
			continue
		if dc.blood_kind == "drip":
			drop = d
		elif dc.blood_kind in ["pool", "splatter"] and pool == null:
			pool = d
	if small_drip:
		if drop == null:
			if pool:
				return pool # adjust_bloodiness(drip::bloodiness = 0)
			return Proto.spawn("blood_drip", c, {"spr": "blood_drop_%d" % (Game.rng.randi() % 5)})
		if drop.c(&"decal").add_drop():
			return drop
		drop.destroy() # the drips become a bigger splatter
	if pool:
		pool.c(&"decal").adjust_bloodiness(CDecal.BLOOD_AMOUNT_PER_DECAL)
		return pool
	return Proto.spawn("blood", c, {"spr": "blood_floor_%d" % (Game.rng.randi() % 7)})

static func drip(c: Vector2i) -> void:
	splatter(c, 0.0, true)

## tg create_splatter: the temporary splash where a hit lands (visual only).
static func splash_fx(c: Vector2i, dir := Vector2i.ZERO) -> void:
	Fx.blood_hit(c, dir)

## tg spray_blood + /obj/effect/decal/cleanable/blood/hitsplatter: a splatter flies
## `strength` tiles away from the blow, leaving smears on the tiles it crosses, and paints
## the wall it hits (or makes a splatter where it lands).
static func spray_blood(h: CHealth, dir: Vector2i, strength := 3) -> void:
	var e := h.e
	if e.holder != null or h.blood_volume <= 0.0:
		return
	if dir == Vector2i.ZERO:
		dir = Defs.DIRS8[Game.rng.randi() % 8]
	var c := e.cell
	var path: Array = []
	var hit_wall := false
	for i in strength:
		var n := c + dir
		if not Game.map.inb(n):
			break
		if Game.map.is_solid_turf(n) or Game.map.blocks_move_static(n):
			hit_wall = true
			break
		c = n
		path.append(c)
	Fx.blood_fly(e.cell, c, 0.1 * maxi(1, path.size()))
	for k in path.size():
		var pc: Vector2i = path[k]
		if k < path.size() - 1 or hit_wall:
			# the fly trail: a light smear along the flight
			var sm := Proto.spawn("blood_trail", pc, {"spr": "blood_ltrails_%d_%s" % [Game.rng.randi() % 2, "h" if dir.y == 0 else "v"]})
			if dir.x != 0 and dir.y != 0 and sm.spr:
				sm.spr.rotation = PI * (0.25 if dir.x == dir.y else -0.25)
	if hit_wall:
		# splatter/over_window: on the wall, offset a tile toward it
		var w := Proto.spawn("blood_splatter", c, {"spr": "blood_splatter_%d" % (Game.rng.randi() % 5)})
		w.z_index = 1
		if w.spr:
			w.spr.position = Vector2(dir) * 20.0
			w.modulate.a = 0.85
		w.c(&"decal").can_dry = false
	elif c != e.cell:
		var sp := splatter(c, 50.0, false, h)
		if sp and sp.proto == "blood" and sp.c(&"decal").bloodiness <= CDecal.BLOOD_AMOUNT_PER_DECAL:
			sp.set_sprite("objects", "blood_splatter_%d" % (Game.rng.randi() % 5))
	if Sfx.streams.has("splat"):
		Sfx.play("splat", c, 0.5)

# ------------------------------------------------------------------ bleeding
## tg bodypart/refresh_bleed_rate, summed (carbon/get_bleed_rate). Gauze doesn't cut the
## rate: it clots the wounds under it. Lying down, grasping and tourniquets do.
static func part_bleed_rate(h: CHealth, part: String) -> float:
	if h.missing.has(part):
		return 0.0
	var r := 0.0
	for w in wounds_on(h, part):
		r += w.get("flow", 0.0)
	if r <= 0.0:
		return 0.0
	if h.lying():
		r *= 0.75
	if h.grasp == part:
		r *= 0.7
	return r

## tg bodypart/update_part_wound_overlay: BLEED_OVERLAY_LOW 0.5, MED 1.5, GUSH 3.25.
static func bleed_overlay_level(rate: float) -> int:
	if rate >= 3.25:
		return 3
	if rate >= 1.5:
		return 2
	if rate >= 0.5:
		return 1
	return 0

static func bleed_rate(h: CHealth) -> float:
	if h.blood_volume <= 0.0:
		return 0.0
	var r := h.bleeding # generic bleeding from surgery slips
	for p in PARTS:
		r += part_bleed_rate(h, p)
	if determined(h):
		r *= WOUND_DETERMINATION_BLEED_MOD
	return r * h.bleed_mod # tg physiology.bleed_mod (hypermetabolic blood)

## tg /mob/living/bleed: the blood goes, and the floor under them gets some of it.
static func bleed(h: CHealth, amount: float, _internal := false) -> void:
	if amount <= 0.0 or (Game.god_mode and h.e == Game.player):
		return
	var before := h.blood_volume
	h.blood_volume = maxf(0.0, h.blood_volume - amount)
	var bled := before - h.blood_volume
	if h.e.holder == null and bled > 0.0 and prob(sqrt(bled) * BLOOD_DRIP_RATE_MOD):
		splatter(h.e.cell, bled * 2.0, bled <= 10.0, h)

## tg bleed_drag_amount (carbon): cuts smear blood when the body is dragged.
static func drag_bleed_amount(h: CHealth) -> float:
	var amt := 0.0
	for w in h.wounds:
		if w["type"] != "slash":
			continue
		var b := minf(w.get("flow", 0.0) * 0.1, 1.0)
		if seep_gauze(h, w["part"], b * 0.33):
			continue
		amt += b
	return amt

## tg make_blood_trail threshold: only when actually bleeding (humans).
static func leaves_trail(h: CHealth) -> bool:
	var br := bleed_rate(h)
	if br <= 0.0 or h.blood_volume <= 0.0:
		return false
	var brute_ratio := snappedf(h.brute / (CHealth.MAX_HEALTH * 4.0), 0.1)
	var bleeding_rate := snappedf(br / 4.0, 0.1)
	return h.blood_volume >= maxf(BLOOD_VOLUME_NORMAL * (1.0 - maxf(bleeding_rate, brute_ratio)), 0.0)

## tg bodypart/seep_gauze: gauze soaks up blood or pus until it falls away in rags.
static func seep_gauze(h: CHealth, part: String, amt: float) -> bool:
	var g: Dictionary = h.gauze.get(part, {})
	if g.is_empty() or g["cap"] <= 0.0:
		return false
	g["cap"] -= amt
	if g["cap"] <= 0.0:
		h.gauze.erase(part)
		_says(h, "The %s on %s's %s falls away in rags." % [g["name"], h.e.display_name, pname(part)], "The %s on your %s falls away in rags." % [g["name"], pname(part)], "warn")
	return true

# ------------------------------------------------------------------ Life()
## tg carbon Life: handle_wounds (every wound's handle_process), then handle_blood while
## alive, plus the determination reagent.
static func handle(h: CHealth, dt: float) -> void:
	for w in h.wounds.duplicate():
		if w in h.wounds:
			_process_wound(h, w, dt)
	_process_determination(h, dt)
	if not h.dead:
		handle_blood(h, dt)

static func _process_wound(h: CHealth, w: Dictionary, dt: float) -> void:
	var d := wound_def(w)
	var part: String = w["part"]
	var g: Dictionary = h.gauze.get(part, {})
	match w["type"]:
		"slash":
			var clot: float = d["clot"]
			if clot > 0.0:
				adjust_flow(h, w, -clot * dt)
				if not w in h.wounds:
					return
			# (tg only applies a positive clot_rate, so a weeping avulsion holds steady)
			if not g.is_empty() and g["rate"] > 0.0:
				seep_gauze(h, part, g["rate"] * dt)
				adjust_flow(h, w, -g["rate"] * dt)
		"pierce":
			if h.body_temp < Defs.BODYTEMP_NORMAL - 10.0:
				adjust_flow(h, w, -0.1 * dt)
				if not w in h.wounds:
					return
				if spt_prob(2.5, dt):
					_tell(h, "You feel the %s in your %s firming up from the cold!" % [d.get("undiag", d["name"]).to_lower(), pname(part)], "info")
			if not g.is_empty() and g["rate"] > 0.0:
				seep_gauze(h, part, g["rate"] * dt)
				adjust_flow(h, w, -d["clot"] * dt - g["rate"] * d["gclot"] * dt)
			else:
				adjust_flow(h, w, -d["clot"] * dt)
		"bone":
			if part == "head" and d.has("trauma") and Game.time > w.get("trauma_t", 0.0):
				_head_trauma(h, w)
				w["trauma_t"] = Game.time + Game.rng.randf_range(0.8, 1.2) * d["trauma_cd"]
			if not (w.get("gel", false) and w.get("taped", false)):
				return
			# regen_ticks count tg Life() ticks (2 s); resting and sleeping speed it
			var ticks := dt / SSMOBS_DT
			if h.lying():
				if spt_prob(30.0, dt):
					ticks += 1.0
				if h.sleeping and spt_prob(30.0, dt):
					ticks += 1.0
			w["regen_t"] = w.get("regen_t", 0.0) + ticks
			if spt_prob(d["sev"] * 1.5, dt):
				var hit := Game.rng.randi_range(1, d["sev"] * 2)
				h.hurt_zone(PARTS[part]["zones"][0], hit, "brute", null, "", CANT_WOUND)
				h.adjust("stamina", Game.rng.randf_range(2.0, d["sev"] * 2.5))
				if prob(33):
					_tell(h, "You feel a sharp pain in your body as your bones are reforming!", "bad")
			if w["regen_t"] > d["regen"] * w.get("regen_mult", 1.0):
				_tell(h, "Your %s has recovered from its %s!" % [pname(part), d.get("undiag", d["name"]).to_lower()], "good")
				remove_wound(h, w)
		"burn":
			_process_burn(h, w, d, g, dt)
		"bruise":
			if h.dead:
				return
			w["ticks"] = w.get("ticks", 25) - dt / SSMOBS_DT
			if w["ticks"] <= 0:
				remove_wound(h, w)

## tg burns.dm handle_process: infection, sanitisation, flesh healing and sepsis.
static func _process_burn(h: CHealth, w: Dictionary, d: Dictionary, g: Dictionary, dt: float) -> void:
	var part: String = w["part"]
	if w["strikes"] <= 0:
		h.adjust("tox", 0.25 * dt)
		if spt_prob(0.5, dt):
			_says(h, "The infection on the remnants of %s's %s shift and bubble nauseatingly!" % [h.e.display_name, pname(part)], "You can feel the infection on the remnants of your %s coursing through your veins!" % pname(part))
		return
	# reagents that work on burn wounds (tg REAGENT_AFFECTS_WOUNDS)
	if h.chems.get("spaceacillin", 0.0) > 0.0:
		w["sanit"] += 0.9 * dt / SSMOBS_DT
	if h.chems.get("sterilizine", 0.0) > 0.0:
		w["sanit"] += 0.9 * dt / SSMOBS_DT
	if h.chems.get("synthflesh", 0.0) > 0.0:
		w["fheal"] += 0.5 * dt
	if not g.is_empty():
		seep_gauze(h, part, WOUND_BURN_SANITIZATION_RATE * dt)
	var bandage_factor: float = g.get("clean", 1.0) if not g.is_empty() else 1.0
	if w["fheal"] > 0.0:
		w["flesh"] = maxf(w["flesh"] - 0.5 * dt, 0.0)
		w["fheal"] = maxf(w["fheal"] - 0.5 * bandage_factor * dt, 0.0)
	var nut := 0.0
	var n: CNeeds = h.e.c(&"needs")
	nut = n.nutrition * NUTRITION_SCALE if n else NUTRITION_LEVEL_FED
	if w["infection"] <= WOUND_INFECTION_MODERATE and part_burn(h, part) < 5.0 and nut >= NUTRITION_LEVEL_FED:
		w["fheal"] += 0.2 * dt / SSMOBS_DT
	if w["flesh"] <= 0.0 and w["infection"] <= WOUND_INFECTION_MODERATE:
		_tell(h, "The burns on your %s have cleared up!" % pname(part), "good")
		remove_wound(h, w)
		return
	if w["sanit"] > 0.0:
		w["infection"] = maxf(w["infection"] - WOUND_BURN_SANITIZATION_RATE * dt, 0.0)
		w["sanit"] = maxf(w["sanit"] - WOUND_BURN_SANITIZATION_RATE * bandage_factor * dt, 0.0)
		return
	w["infection"] += d["inf"] * dt
	var inf: float = w["infection"]
	var pn := pname(part)
	if inf <= WOUND_INFECTION_MODERATE:
		return
	elif inf <= WOUND_INFECTION_SEVERE:
		if spt_prob(15, dt):
			h.adjust("tox", 0.2)
			if prob(6):
				_tell(h, "The blisters on your %s ooze a strange pus..." % pn)
	elif inf <= WOUND_INFECTION_CRITICAL:
		if not w.get("disabling", false):
			if spt_prob(1, dt):
				_tell(h, "[b]Your %s completely locks up, as you struggle for control against the infection![/b]" % pn, "bad")
				w["disabling"] = true
				return
		elif spt_prob(4, dt):
			_tell(h, "You regain sensation in your %s, but it's still in terrible shape!" % pn, "info")
			w["disabling"] = false
			return
		if spt_prob(10, dt):
			h.adjust("tox", 0.5)
	elif inf <= WOUND_INFECTION_SEPTIC:
		if not w.get("disabling", false):
			if spt_prob(1.5, dt):
				_tell(h, "[b]You suddenly lose all sensation of the festering infection in your %s![/b]" % pn, "bad")
				w["disabling"] = true
				return
		elif spt_prob(1.5, dt):
			_tell(h, "You can barely feel your %s again, and you have to strain to retain motor control!" % pn, "info")
			w["disabling"] = false
			return
		if spt_prob(2.48, dt):
			if prob(20):
				_tell(h, "You contemplate life without your %s..." % pn)
				h.adjust("tox", 0.75)
			else:
				h.adjust("tox", 1.0)
	else:
		if spt_prob(0.5 * inf, dt):
			w["strikes"] -= 1
			match w["strikes"]:
				2: _tell(h, "[b]The infection in your %s is literally dripping off, you feel horrible![/b]" % pn, "bad")
				1: _tell(h, "[b]Infection has just about completely claimed your %s![/b]" % pn, "bad")
				0:
					_tell(h, "[b]The last of the nerve endings in your %s wither away, as the infection completely paralyzes your joint connector.[/b]" % pn, "bad")
					w["tp_mult"] = 2.0
					w["disabling"] = true

## tg cranial_fissure on_owner_slipped: the brain spills out of a split skull.
static func on_slipped(h: CHealth) -> void:
	if h == null or h.dead or wound_on(h, "head", "fissure").is_empty():
		return
	_says(h, "[b]%s's brain spills right out of their head![/b]" % h.e.display_name, "[b]Your brain spills right out of your head![/b]")
	Organs.remove(h, "brain", h.e.cell) # ORGAN_VITAL: that kills them

## tg bone wound head traumas: a hairline fracture of the skull cycles mild brain traumas,
## a compound one severe ones (TRAUMA_RESILIENCE_WOUND): each cycle the active one goes,
## or a new one comes.
static func _head_trauma(h: CHealth, w: Dictionary) -> void:
	var active := Traumas.find(h, w.get("trauma_uid", -1))
	if not active.is_empty():
		Traumas.lose(h, active)
		w.erase("trauma_uid")
		return
	var t := Traumas.gain_type(h, wound_def(w)["trauma"], Traumas.RES_WOUND)
	if not t.is_empty():
		w["trauma_uid"] = t["uid"]

## tg /datum/reagent/determination and /datum/status_effect/determined
static func _process_determination(h: CHealth, dt: float) -> void:
	if h.determination <= 0.0:
		return
	if h.dead:
		h.determination = 0.0
		h.determined = false
		return
	if not h.determined_big and h.determination >= WOUND_DETERMINATION_SEVERE:
		h.determined_big = true
		h.determined = true
		_says(h, "%s's body tenses up noticeably, gritting against their pain!" % h.e.display_name, "[b]Your senses sharpen as your body tenses up from the wounds you've sustained![/b]", "warn")
	h.determination = minf(h.determination, WOUND_DETERMINATION_MAX)
	for w in h.wounds:
		heal_part(h, w["part"], 0.167 * dt, 0.25 * dt)
		h.adjust("stamina", -0.67 * dt)
	h.determination -= DETERMINATION_METABOLISM * dt
	if h.determination <= 0.0:
		h.determination = 0.0
		if h.determined_big:
			var crash := 0.0
			for w in h.wounds:
				crash += (w["sev"] + 1) * 3.0
			h.adjust("stamina", crash)
			_says(h, "%s's body slackens noticeably!" % h.e.display_name, "[b]Your adrenaline rush dies off, and the pain from your wounds come aching back in...[/b]", "warn")
		h.determined = false
		h.determined_big = false

## tg bodypart/heal_damage on one part (keeps the mob totals in step)
static func heal_part(h: CHealth, part: String, brute: float, burn: float) -> float:
	var healed := 0.0
	for z in PARTS[part]["zones"]:
		var tot: float = h.limb.get(z, 0.0)
		if tot <= 0.0:
			continue
		var bz: float = h.limb_burn.get(z, 0.0)
		var br := tot - bz
		var hb := minf(brute, br)
		var hu := minf(burn, bz)
		brute -= hb
		burn -= hu
		h.limb[z] = tot - hb - hu
		h.limb_burn[z] = bz - hu
		h.brute = maxf(0.0, h.brute - hb)
		h.burn = maxf(0.0, h.burn - hu)
		healed += hb + hu
	if part_damage(h, part) < PARTS[part]["max"]:
		h.limb_maxed.erase(part)
	return healed

## tg handle_blood (human): regeneration from nutrition, bleeding, the effects of low blood,
## and oxygen damage tracking the missing blood.
static func handle_blood(h: CHealth, dt: float) -> void:
	if h.body_temp < BLOOD_STOP_TEMP:
		return
	var e := h.e
	# tg get_heart_blood_regeneration_multiplier: no (or a stopped) heart, no new blood
	var heart_mult := Organs.blood_regeneration_multiplier(h)
	if h.blood_volume < BLOOD_VOLUME_NORMAL and heart_mult > 0.0:
		var n: CNeeds = e.c(&"needs")
		var nutrition := n.nutrition * NUTRITION_SCALE if n else NUTRITION_LEVEL_WELL_FED
		var ratio := snappedf(nutrition / NUTRITION_LEVEL_WELL_FED, 0.2)
		var restore := BLOOD_REGEN_FACTOR * heart_mult * ratio * h.blood_regen_mod * dt # tg PHYS_COEFF_BLOOD_REGEN
		if restore > 0.0:
			h.blood_volume = minf(BLOOD_VOLUME_NORMAL, h.blood_volume + restore)
			if n:
				n.nutrition = maxf(0.0, n.nutrition - ratio * 0.05 * dt / NUTRITION_SCALE)
	var br := bleed_rate(h)
	if br > 0.0:
		bleed(h, br * dt)
		bleed_warn(h, br)
	h.bleeding = maxf(0.0, h.bleeding - 0.5 * dt / SSMOBS_DT) # tg generic_bleedstacks: -1 per tick
	var v := get_blood_volume(h)
	var det := 0.5 if determined(h) else 1.0
	var word: String = ["dizzy", "woozy", "faint"][Game.rng.randi() % 3]
	if v >= BLOOD_VOLUME_EXCESS:
		if spt_prob(7.5, dt):
			_tell(h, "[b]Blood starts to tear your skin apart. You're going to burst![/b]", "bad")
			gib(h)
			return
	elif v >= BLOOD_VOLUME_MAXIMUM:
		if spt_prob(5, dt):
			_tell(h, "You feel terribly bloated.")
	elif v < BLOOD_VOLUME_SAFE and v >= BLOOD_VOLUME_OKAY:
		if spt_prob(2.5, dt):
			h.set_status_if_lower("eye_blur", 2.0 * det)
			if prob(50):
				_tell(h, "You feel %s. It's getting a bit hard to breathe." % word, "bad")
				h.losebreath += 0.5 * det * dt
			elif h.stamina_loss() < 25.0 * det:
				_tell(h, "You feel %s. It's getting a bit hard to focus." % word, "bad")
				h.adjust("stamina", 5.0 * det * dt)
	elif v < BLOOD_VOLUME_OKAY and v >= BLOOD_VOLUME_RISKY:
		if spt_prob(5, dt):
			h.set_status_if_lower("eye_blur", 2.0 * det)
			h.set_status_if_lower("dizzy", 2.0 * det)
			if prob(50):
				_tell(h, "[b]You feel very %s. It's getting hard to breathe![/b]" % word, "bad")
				h.losebreath += 1.0 * det
			elif h.stamina_loss() < 40.0 * det:
				_tell(h, "[b]You feel very %s. It's getting hard to stay awake![/b]" % word, "bad")
				h.adjust("stamina", 7.5 * det)
	elif v < BLOOD_VOLUME_RISKY and v >= BLOOD_VOLUME_BAD:
		if spt_prob(5, dt):
			h.set_status_if_lower("eye_blur", 4.0 * det)
			h.set_status_if_lower("dizzy", 4.0 * det)
			if prob(50):
				_tell(h, "[b]You feel extremely %s! It's getting very hard to breathe![/b]" % word, "bad")
				h.losebreath += 1.5 * det
			elif h.stamina_loss() < 80.0 * det:
				_tell(h, "[b]You feel extremely %s! It's getting very hard to stay awake![/b]" % word, "bad")
				h.adjust("stamina", 10.0 * det)
	elif v < BLOOD_VOLUME_BAD and v >= BLOOD_VOLUME_SURVIVE:
		if spt_prob(7.5, dt):
			h.knock_out(Game.rng.randf_range(1.0, 2.0))
			_tell(h, "[b]You black out for a moment![/b]", "bad")
	elif v < BLOOD_VOLUME_SURVIVE:
		h.die()
		return
	var target_oxy := maxf((1.0 - v / BLOOD_VOLUME_NORMAL) * 100.0, 0.0)
	if target_oxy > 0.0 and (h.oxy < target_oxy or (target_oxy >= OXYLOSS_PASSOUT_THRESHOLD and h.stat() == CHealth.UNCONSCIOUS)):
		h.adjust("oxy", snappedf(0.01 * (BLOOD_VOLUME_NORMAL - v), 0.25) * dt)

## tg get_blood_volume(apply_modifiers): saline-glucose stands in for missing blood.
static func get_blood_volume(h: CHealth) -> float:
	var v := h.blood_volume
	var saline: float = h.chems.get("salglu_solution", 0.0)
	if saline > 0.0 and v < BLOOD_VOLUME_SAFE:
		v = minf(v + saline * 3.0, BLOOD_VOLUME_NORMAL)
	return v

## tg carbon/bleed_warn: what bleeding feels like, and whether it's getting better.
static func bleed_warn(h: CHealth, br: float) -> void:
	if h.e != Game.player or Game.time < h.bleed_msg_t:
		return
	var sev := ""
	var cd := BLEEDING_MESSAGE_BASE_CD
	if br <= 1.0:
		sev = "You feel light trickles of blood across your skin"
		cd *= 2.5
	elif br <= 3.0:
		sev = "You feel a small stream of blood running across your body"
		cd *= 2.0
	elif br <= 5.0:
		sev = "You skin feels clammy from the flow of blood leaving your body"
		cd *= 1.7
	elif br <= 7.0:
		sev = "Your body grows more and more numb as blood streams out"
		cd *= 1.5
	else:
		sev = "Your heartbeat thrashes wildly trying to keep up with your bloodloss"
	var roc := ", but it's getting better."
	for w in h.wounds:
		if w.get("flow", 0.0) <= 0.0:
			continue
		var r := _bleed_rate_of_change(h, w)
		if r > 0:
			roc = ", [b]and it's getting worse![/b]"
			break
		if r == 0:
			roc = ", and it's holding steady."
	_tell(h, sev + roc, "warn")
	h.bleed_msg_t = Game.time + cd

static func _bleed_rate_of_change(h: CHealth, w: Dictionary) -> int:
	var d := wound_def(w)
	if h.gauze.has(w["part"]) or d.get("clot", 0.0) > 0.0:
		return -1
	if d.get("clot", 0.0) < 0.0:
		return 1
	return 0

# ------------------------------------------------------------------ treatment
## tg /obj/item/stack/medical/wrap: can it go on (a wound that accepts gauze, and the new
## wrap is 20% better than what's there)?
static func can_gauze(h: CHealth, part: String, kind: String) -> String:
	if wounds_on(h, part).filter(func(w): return w["type"] != "fissure").is_empty():
		return "can't gauze!" if not wounds_on(h, part).is_empty() else "no wounds!"
	var cur: Dictionary = h.gauze.get(part, {})
	if not cur.is_empty() and cur["cap"] * 1.2 > WRAPS[kind]["cap"]:
		return "already bandaged!"
	return ""

## tg on_gauze_limb: wrap the part; burns under clean gauze are sanitised and start healing.
static func apply_gauze(h: CHealth, part: String, kind := "gauze") -> bool:
	var g: Dictionary = WRAPS[kind].duplicate()
	h.gauze[part] = g
	for w in wounds_on(h, part):
		if w["type"] == "burn":
			w["sanit"] += g["san"] * (0.2 if w["infection"] > 0.1 else 1.0)
			w["fheal"] += g["regen"] * (0.0 if w["infection"] > 0.1 else 1.0)
		if w["type"] == "bone" and DEFS[w["id"]].get("disabling", false):
			w["disabling"] = false # update_inefficiencies: splinted
	return true

## tg heal_carbon's stop_bleeding: one bleeding wound at a time; 70% as good on yourself.
static func stop_bleeding(h: CHealth, part: String, amount: float) -> bool:
	for w in wounds_on(h, part):
		if w.get("flow", 0.0) > 0.0:
			adjust_flow(h, w, -amount)
			return true
	return false

## tg burn wound can_be_ointmented_or_meshed
static func burn_treatable(w: Dictionary) -> bool:
	if w["type"] != "burn":
		return false
	if w["infection"] > 0.0 and w["sanit"] < w["infection"]:
		return true
	if w["flesh"] > 0.0 and w["fheal"] <= w["flesh"]:
		return true
	return false

## tg heal_carbon's flesh_regeneration/sanitization: one burn wound at a time.
static func treat_burn(h: CHealth, part: String, regen: float, san: float) -> bool:
	for w in wounds_on(h, part):
		if burn_treatable(w):
			w["fheal"] += regen
			w["sanit"] += san
			return true
	return false

## tg slash/pierce tool_cauterize: 0.6 flow per go (worse improvised or on yourself), and it
## burns 2 + severity.
static func cauterize(h: CHealth, part: String, improvised := false, on_self := false) -> bool:
	var did := false
	for w in wounds_on(h, part):
		if w["type"] in ["slash", "pierce"] and w.get("flow", 0.0) > 0.0:
			var mult := (1.25 if improvised else 1.0) * (1.5 if on_self else 1.0)
			var sev: int = w["sev"]
			adjust_flow(h, w, -0.6 / mult)
			h.hurt_zone(PARTS[part]["zones"][0], 2.0 + sev, "burn", null, "", CANT_WOUND)
			if prob(30):
				_scream(h)
			did = true
			break
	return did

## tg bone/moderate treat (bonesetter): 15 brute doing it yourself, 10 for someone else.
static func set_bone(h: CHealth, part: String, on_self := false) -> bool:
	var w := wound_on(h, part, "bone")
	if w.is_empty() or w["sev"] != 1:
		return false
	h.hurt_zone(PARTS[part]["zones"][0], 15.0 if on_self else 10.0, "brute", null, "", CANT_WOUND)
	_scream(h)
	remove_wound(h, w)
	return true

## tg bone/gel: 25 brute and 100 stamina; self-application can knock you out.
static func bone_gel(h: CHealth, part: String, on_self := false) -> String:
	var w := wound_on(h, part, "bone")
	if w.is_empty() or w["sev"] < 2:
		return "no fractures!"
	if w.get("gel", false):
		return "already coated with bone gel!"
	_scream(h)
	if on_self and prob(25.0 + 20.0 * (w["sev"] - 2)):
		h.knock_out(5.0)
		return "passed out"
	h.hurt_zone(PARTS[part]["zones"][0], 25.0, "brute", null, "", CANT_WOUND)
	h.adjust("stamina", 100.0)
	w["gel"] = true
	return ""

## tg bone/tape: on a gelled fracture, starts the bones reforming (1.5x slower on yourself).
static func surgical_tape(h: CHealth, part: String, on_self := false) -> String:
	var w := wound_on(h, part, "bone")
	if w.is_empty() or w["sev"] < 2:
		return "no fractures!"
	if not w.get("gel", false):
		return "must be coated with bone gel first!"
	if w.get("taped", false):
		return "already wrapped and reforming!"
	if on_self:
		w["regen_mult"] = 1.5
	w["taped"] = true
	return ""

## tg bone/moderate chiropractice: 65% it snaps back (20 brute), else 10 brute and again.
## malpractice (combat mode) breaks it instead.
static func wrench_joint(h: CHealth, part: String, malpractice := false) -> int:
	var w := wound_on(h, part, "bone")
	if w.is_empty() or w["sev"] != 1:
		return -1
	var z: String = PARTS[part]["zones"][0]
	if prob(65):
		_scream(h)
		if malpractice:
			h.hurt_zone(z, 25.0, "brute", null, "", 30.0)
		else:
			h.hurt_zone(z, 20.0, "brute", null, "", CANT_WOUND)
			remove_wound(h, w)
		return 1
	h.hurt_zone(z, 10.0, "brute", null, "", CANT_WOUND)
	return 0

## tg splint (no such item in tg now; gauze and tape splint): kept as a wrap with tape's
## splint_factor.
static func splint(h: CHealth, part: String) -> bool:
	if wounds_on(h, part).is_empty():
		return false
	return apply_gauze(h, part, "splint")

## tg carbon grabbedby(self): hold a bleeding part to slow it (x0.7).
static func can_be_grasped(h: CHealth, part: String) -> bool:
	if h.missing.has(part):
		return false
	if part_bleed_rate(h, part) > 0.0:
		return true
	return wounds_on(h, part).any(func(w): return w["type"] in ["slash", "pierce"])

## tg transfer_blood_to: incompatible blood gives half its volume as toxin instead.
static func transfuse(h: CHealth, units: float, btype: String) -> void:
	if btype != "" and not btype in COMPATIBLE.get(h.blood_type, [h.blood_type]):
		h.chems["toxin"] = h.chems.get("toxin", 0.0) + units * 0.5
		return
	h.blood_volume = minf(BLOOD_VOLUME_MAX_LETHAL, h.blood_volume + units)

## tg coagulant_effect: the bloodiest wound clots by `amount`.
static func coagulant(h: CHealth, amount: float) -> bool:
	var best := {}
	for w in h.wounds:
		if w.get("flow", 0.0) > best.get("flow", 0.0):
			best = w
	if best.is_empty():
		return false
	adjust_flow(h, best, -absf(amount))
	return true

# ------------------------------------------------------------------ reading
static func _gauze_word(cap: float, burn := false) -> String:
	if cap <= 1.25:
		return "nearly ruined "
	if cap <= 2.75:
		return "badly worn "
	if cap <= 4.0:
		return "slightly stained " if burn else "slightly bloodied "
	return "clean "

## tg wound get_wound_description (per type), for examine.
static func wound_examine(h: CHealth, w: Dictionary) -> String:
	var d := wound_def(w)
	var part: String = w["part"]
	var g: Dictionary = h.gauze.get(part, {})
	var their := "Their %s" % pname(part)
	var desc := ""
	match w["type"]:
		"slash":
			if not g.is_empty():
				return "[b]The cuts on their %s are wrapped with %s%s![/b]" % [pname(part), _gauze_word(g["cap"]), g["name"]]
		"burn":
			if w["strikes"] <= 0:
				return "[color=#8a6ab8][b]%s has locked up completely and is non-functional.[/b][/color]" % their
			var cond := "%s %s" % [their, d["examine"]]
			if not g.is_empty():
				cond += " underneath a dressing of %s%s." % [_gauze_word(g["cap"], true), g["name"]]
			else:
				var inf: float = w["infection"]
				if inf > WOUND_INFECTION_SEPTIC:
					return "[color=#8a6ab8][b]%s is a mess of charred skin and infected rot![/b][/color]" % their
				elif inf > WOUND_INFECTION_CRITICAL:
					cond += ", [color=#8a6ab8]with streaks of rotten infection![/color]"
				elif inf > WOUND_INFECTION_SEVERE:
					cond += ", [color=#8a6ab8]with growing clouds of infection.[/color]"
				elif inf > WOUND_INFECTION_MODERATE:
					cond += ", [color=#8a6ab8]with early signs of infection.[/color]"
				else:
					cond += "!"
			return "[b]%s[/b]" % cond
		"bruise":
			return ""
	if not g.is_empty():
		desc = "%s is %sfastened in a sling of %s" % [their, _gauze_word(g["cap"]).replace("nearly ruined ", "just barely ").replace("badly worn ", "loosely ").replace("slightly bloodied ", "mostly ").replace("clean ", "tightly "), g["name"]]
	else:
		desc = "%s %s" % [their, d["examine"]]
		if w["type"] == "bone":
			if w.get("taped", false):
				desc += ", [color=#8ab8ff]and appears to be reforming itself under some surgical tape![/color]"
			elif w.get("gel", false):
				desc += ", [color=#8ab8ff]with fizzing flecks of blue bone gel sparking off the bone![/color]"
		if w["id"] == "compound" and part == "head":
			desc = "%s has an unsettling indent, with bits of skull poking out" % their
	if d["sev"] > 1:
		return "[b]%s![/b]" % desc
	return desc + "."

## Examine lines (tg human/examine: missing parts, wounds, bleeding, pale skin, scars).
static func describe(h: CHealth, viewer: Entity = null) -> Array:
	var out := []
	for p in ["head", "l_arm", "r_arm", "l_leg", "r_leg"]:
		if h.missing.has(p):
			out.append("[color=#ff5a4a][b]Their %s is missing![/b][/color]" % pname(p))
	for w in h.wounds:
		var line := wound_examine(h, w)
		if line != "":
			out.append("[color=%s]%s[/color]" % ["#ff5a4a" if w["sev"] >= 2 else "#ffb84a", line])
	var bleeding := []
	for p in PARTS:
		if part_bleed_rate(h, p) > 0.0:
			bleeding.append(pname(p))
	if not bleeding.is_empty() and not h.dead:
		var br := bleed_rate(h)
		var how := "is bleeding" if br < BLEED_OVERLAY_MED else ("is bleeding heavily" if br < BLEED_OVERLAY_GUSH else "is bleeding profusely")
		out.append("[color=#ff5a4a][b]They %s from their %s![/b][/color]" % [how.substr(3), " and ".join(bleeding)])
	if h.grasp != "":
		out.append("They're holding their %s tightly." % pname(h.grasp))
	if h.blood_volume < BLOOD_VOLUME_SAFE and not h.dead:
		out.append("[color=#c8b8b8]Their skin is %s.[/color]" % ("deathly pale" if h.blood_volume < BLOOD_VOLUME_OKAY else "pale"))
	var inv: CInventory = h.e.c(&"inv")
	var dist := 0
	if viewer:
		dist = maxi(absi(viewer.cell.x - h.e.cell.x), absi(viewer.cell.y - h.e.cell.y))
	for s in h.scars:
		if h.missing.has(s["part"]):
			continue
		if dist > s["vis"]:
			continue
		var covered := false
		if inv:
			for slot in SCAR_COVER.get(s["part"], []):
				if inv.worn(slot):
					covered = true
		if covered:
			continue
		var sz: String = ["#9a9a9a", "#9a9a9a", "#b0b0b0", "#c8c8c8", "#e0e0e0"][clampi(s["sev"], 0, 4)]
		if s["sev"] >= 4:
			out.append("[color=%s][i][b]Their %s %s.[/b][/i][/color]" % [sz, pname(s["part"]), s["desc"]])
		else:
			out.append("[color=%s][i]They have %s on their %s.[/i][/color]" % [sz, s["desc"], s["loc"]])
	return out

## tg health analyzer wound section (get_scanner_description), plus blood.
static func analyzer_lines(h: CHealth) -> Array:
	var out := []
	var pct := int(h.blood_volume / BLOOD_VOLUME_NORMAL * 100.0)
	var col := "#6ae88a" if h.blood_volume >= BLOOD_VOLUME_SAFE else ("#ffb84a" if h.blood_volume >= BLOOD_VOLUME_OKAY else "#ff5a4a")
	out.append("Blood level: [color=%s]%d%%, %d cl[/color], type: %s" % [col, pct, int(h.blood_volume), h.blood_type])
	var br := bleed_rate(h)
	if br > 0.0:
		out.append("[color=#ff5a4a]Subject is bleeding at a rate of %.1f u/s.[/color]" % br)
	var parts := []
	for p in PARTS:
		if h.missing.has(p):
			parts.append("[color=#ff5a4a]%s: MISSING[/color]" % pname(p))
			continue
		var pd := part_damage(h, p)
		if pd >= 1.0:
			var pb := part_burn(h, p)
			parts.append("%s: [color=#ff8a8a]%d[/color]/[color=#ffb84a]%d[/color]" % [pname(p), int(pd - pb), int(pb)])
	if not parts.is_empty():
		out.append("Limbs: " + ", ".join(parts))
	for w in h.wounds:
		var d := wound_def(w)
		if d["sev"] == 0:
			continue
		var sevt: String = ["Trivial", "Moderate", "[b]Severe[/b]", "[b]Critical[/b]"][d["sev"]]
		if w["type"] == "burn":
			var inf: float = w["infection"]
			sevt += " Burn / " + ("No" if inf <= WOUND_INFECTION_MODERATE else ("Moderate" if inf <= WOUND_INFECTION_SEVERE else ("[b]Severe[/b]" if inf <= WOUND_INFECTION_CRITICAL else ("[b]Critical[/b]" if inf <= WOUND_INFECTION_SEPTIC else "[b]Total[/b]")))) + " Infection"
		var s := "[color=#ffb84a]%s[/color] (%s) on %s: %s\n    Recommended Treatment: %s" % [d["name"], sevt, pname(w["part"]), d["desc"], d["treat"]]
		match w["type"]:
			"bone":
				if d["sev"] > 1:
					if not w.get("gel", false):
						s += "\n    Alternative Treatment: Apply bone gel directly to injured limb, then apply surgical tape to begin bone regeneration. This is both excruciatingly painful and slow, and only recommended in dire circumstances."
					elif not w.get("taped", false):
						s += "\n    Continue Alternative Treatment: Apply surgical tape directly to injured limb to begin bone regeneration. Note, this is both excruciatingly painful and slow, though sleep or laying down will speed recovery."
					else:
						s += "\n    Note: Bone regeneration in effect. Bone is %d%% regenerated." % int(w.get("regen_t", 0.0) * 100.0 / (d["regen"] * w.get("regen_mult", 1.0)))
				if w["part"] == "head":
					s += "\n    Cranial Trauma Detected: Patient will suffer random bouts of %s brain traumas until bone is repaired." % ("mild" if d["sev"] == 2 else "severe")
				elif w["part"] == "chest":
					s += "\n    Ribcage Trauma Detected: Further trauma to chest is likely to worsen internal bleeding until bone is repaired."
			"burn":
				if w["strikes"] <= 0:
					s = "[color=#ffb84a]%s[/color] on %s:\n    Infection Level: [color=#8a6ab8]The body part has suffered complete sepsis and must be removed. Amputate or augment limb immediately, or place the patient in a cryotube.[/color]" % [d["name"], pname(w["part"])]
				elif w["infection"] <= w["sanit"] and w["flesh"] <= w["fheal"]:
					s += "\n    No further treatment required: Burns will heal shortly."
				else:
					if w["infection"] > w["sanit"]:
						s += "\n    Surgical debridement, antibiotics/sterilizers, or regenerative mesh will rid infection. Paramedic UV penlights are also effective."
					if w["flesh"] > 0.0:
						s += "\n    Flesh damage detected: Application of ointment, regenerative mesh, Synthflesh, or ingestion of \"Miner's Salve\" will repair damaged flesh. Good nutrition, rest, and keeping the wound clean can also slowly repair flesh."
		out.append(s)
	if h.determination > 0.0:
		out.append("[color=#b8d8ff]Determination: %.1fu[/color]" % h.determination)
	return out

## tg self-check (carbon/check_self_for_injuries) wound lines.
static func self_check_lines(h: CHealth) -> Array:
	var out := []
	for w in h.wounds:
		var d := wound_def(w)
		var nm: String = d.get("undiag", d["name"]).to_lower()
		var a: String = d.get("a", "a")
		var line := ""
		if w["id"] == "dislocation":
			line = "It feels dislocated!"
		elif w["type"] in ["slash", "pierce"]:
			line = ["It's leaking blood from a small %s.", "It's leaking blood from a %s.", "It's leaking blood from a serious %s!", "It's leaking blood from a major %s!!"][d["sev"]] % nm
		else:
			line = ["It's suffering %s %s.", "It's suffering %s %s.", "It's suffering %s %s!", "It's suffering %s %s!!"][d["sev"]] % [a, nm]
		out.append("[color=%s]Your %s: %s[/color]" % ["#ff5a4a" if d["sev"] >= 2 else "#ffb84a", pname(w["part"]), line])
	return out
