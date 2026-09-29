class_name Addiction extends RefCounted
## tg addiction (code/modules/reagents/withdrawal/): metabolising an addictive drug builds
## addiction points (gain threshold 600 / the reagent's threshold per unit metabolised, up
## to 1000). At 600 you're hooked; each second without it is a withdrawal cycle: stage 1
## from cycle 61, stage 2 from 121, stage 3 from 181, each with its moodlet and symptoms.
## Without the drug you lose points (0.5 / 0.5 / 1 / 1.5 a second by stage) and below 400
## you're over it. Enough of it in your blood (1u; nicotine 0.01u) ends the withdrawal.

const GAIN_THRESHOLD := 600.0
const LOSS_THRESHOLD := 400.0
const MAX_POINTS := 1000.0
const LOSS_PER_STAGE := [0.5, 0.5, 1.0, 1.5]

## tg addiction datums: name, stage messages, relief threshold, (nicotine) its own moodlets
const TYPES := {
	"alcohol": {"name": "alcohol", "msgs": ["I could use a drink...", "Maybe the bar is still open?..", "God I need a drink!"], "relief": 1.0},
	"nicotine": {"name": "nicotine", "msgs": ["Feel like having a smoke...", "Getting antsy. Really need a smoke now.", "I can't take it! Need a smoke NOW!"], "relief": 0.01,
		"moods": ["withdrawal_light", "nicotine_withdrawal_moderate", "nicotine_withdrawal_severe"]},
	"opioids": {"name": "opioid", "msgs": ["I feel aches in my bodies..", "I need some pain relief...", "It aches all over...I need some opioids!"], "relief": 1.0},
	"stimulants": {"name": "stimulant", "msgs": ["You feel a bit tired...You could really use a pick me up.", "You are getting a bit woozy...", "So...Tired..."], "relief": 1.0},
	"hallucinogens": {"name": "hallucinogen", "msgs": ["I feel so empty...", "I wonder what the machine elves are up to?..", "I need to see the beautiful colors again!!"], "relief": 1.0},
}

## reagent -> [addiction, tg threshold] (reagent addiction_types). Booze is
## max(50, round(150 - boozepwr, 5)).
const REAGENTS := {
	"ethanol": ["alcohol", 85.0], "vodka": ["alcohol", 85.0], "beer": ["alcohol", 125.0],
	"nicotine": ["nicotine", 10.0],
	"morphine": ["opioids", 30.0],
	"methamphetamine": ["stimulants", 75.0],
	"space_drugs": ["hallucinogens", 60.0], "mindbreaker": ["hallucinogens", 60.0],
}

## What the addict quirks start you hooked on (tg maxes the points out).
const QUIRK_ADDICTION := {"smoker": "nicotine", "alcoholic": "alcohol", "junkie": "opioids"}

static func _data(h: CHealth) -> Dictionary:
	if not h.has_meta("addiction"):
		h.set_meta("addiction", {"points": {}, "active": {}, "last_dose": {}, "stage": {}})
	return h.get_meta("addiction")

static func points(h: CHealth, type: String) -> float:
	return _data(h)["points"].get(type, 0.0)

static func addicted(h: CHealth, type: String) -> bool:
	return _data(h)["active"].has(type)

static func stage(h: CHealth, type: String) -> int:
	return _data(h)["stage"].get(type, 0) if h.has_meta("addiction") else 0

## tg holder/mob_life: points for what was metabolised this tick.
static func expose(h: CHealth, reagent: String, metabolized: float) -> void:
	if h == null or not REAGENTS.has(reagent):
		return
	var r: Array = REAGENTS[reagent]
	add_points(h, r[0], GAIN_THRESHOLD / (r[1] / maxf(metabolized, 0.0001)))
	_data(h)["last_dose"][r[0]] = Game.time

static func add_points(h: CHealth, type: String, amount: float) -> void:
	var d := _data(h)
	var last: float = d["points"].get(type, 0.0)
	var now := minf(last + amount, MAX_POINTS)
	d["points"][type] = now
	if now >= GAIN_THRESHOLD and last < GAIN_THRESHOLD and not d["active"].has(type):
		d["active"][type] = 1.0 # tg become_addicted: the first cycle

## tg addict quirk add()
static func quirk_start(h: CHealth, quirk: String) -> void:
	var type: String = QUIRK_ADDICTION.get(quirk, "")
	if type != "":
		add_points(h, type, MAX_POINTS)

## tg process_addiction, every second
static func tick(h: CHealth, dt: float) -> void:
	if not h.has_meta("addiction") or h.dead:
		return
	var d := _data(h)
	for type in d["points"].keys():
		var info: Dictionary = TYPES[type]
		var on_drug := _on_drug(h, type, info["relief"], d["last_dose"])
		var cycle: float = d["active"].get(type, 0.0)
		if on_drug and cycle > 0.0:
			_end_withdrawal(h, type)
			cycle = 1.0
		var st := 0
		if cycle >= 181.0: st = 3
		elif cycle >= 121.0: st = 2
		elif cycle >= 61.0: st = 1
		if not on_drug:
			var before: float = d["points"][type]
			var after := maxf(before - LOSS_PER_STAGE[st] * dt, 0.0)
			d["points"][type] = after
			if before >= LOSS_THRESHOLD and after < LOSS_THRESHOLD and d["active"].has(type):
				# tg lose_addiction
				Game.tell(h.e, "You feel like you've gotten over your need for drugs.", "good")
				_end_withdrawal(h, type)
				d["active"].erase(type)
				if after <= 0.0:
					d["points"].erase(type)
				continue
			if after <= 0.0:
				d["points"].erase(type)
		if cycle <= 0.0:
			continue
		# tg withdrawal_enters_stage_N: the stage's moodlet
		if st > 0 and d["stage"].get(type, 0) != st:
			d["stage"][type] = st
			var moods: Array = info.get("moods", ["withdrawal_light", "withdrawal_medium", "withdrawal_severe"])
			CMood.event(h.e, type + "_addiction", moods[st - 1], info["name"])
		if st > 0:
			_symptoms(h, type, st, dt, info)
		if not on_drug:
			d["active"][type] = cycle + dt # next cycle

static func _on_drug(h: CHealth, type: String, relief: float, last_dose: Dictionary) -> bool:
	for r in REAGENTS:
		if REAGENTS[r][0] == type and h.chems.get(r, 0.0) >= relief:
			return true
	# nicotine comes from smoking rather than sitting in the blood here: a puff just now counts
	return type == "nicotine" and Game.time - last_dose.get("nicotine", -99.0) < 2.0

static func _end_withdrawal(h: CHealth, type: String) -> void:
	var d := _data(h)
	if d["active"].has(type):
		d["active"][type] = 1.0
	d["stage"].erase(type)
	CMood.clear_event(h.e, type + "_addiction")
	if type == "opioids":
		h.disgust *= 0.5

## tg withdrawal_stage_N_process
static func _symptoms(h: CHealth, type: String, st: int, dt: float, info: Dictionary) -> void:
	if Body.spt_prob([5.0, 10.0, 15.0][st - 1], dt):
		Game.tell(h.e, "[b]%s[/b]" % info["msgs"][st - 1], "bad")
	var m: CMob = h.e.c(&"mob")
	match type:
		"alcohol":
			h.set_status_if_lower("jitter", [10.0, 20.0, 30.0][st - 1] * dt)
			if st >= 2:
				h.set_status_if_lower("hallucination", 10.0)
			if st == 3 and Body.spt_prob(4.0, dt):
				seizure(h)
		"nicotine":
			h.set_status_if_lower("jitter", [10.0, 20.0, 30.0][st - 1] * dt)
			if st >= 2 and m and Body.spt_prob([0.0, 2.0, 5.0][st - 1], dt):
				m.do_emote("cough")
		"opioids":
			if st == 1 and m and Body.spt_prob(10.0, dt):
				m.do_emote("yawn")
			if st == 3 and h.disgust < 75.0 and Body.spt_prob(7.5, dt):
				h.disgust += 12.5 * dt
		"stimulants":
			if st >= 2:
				h.set_status_if_lower("dizziness", 4.0) # tg woozy
		"hallucinogens":
			if st >= 2:
				h.set_status_if_lower("eye_blur", 4.0) # tg: a blurry, wavy screen
			if st == 3:
				h.set_status_if_lower("hallucination", 10.0) # tg trance

## tg /datum/status_effect/seizure: down for 1-3 s, shaking.
static func seizure(h: CHealth) -> void:
	var t := Game.rng.randf_range(1.0, 3.0)
	h.set_status_if_lower("jitter", 100.0)
	h.paralyze(t)
	Game.visible_message(h.e.cell, "%s drops to the ground as they start seizing up." % h.e.display_name, "bad")
	Game.tell(h.e, ["You can't collect your thoughts...", "You suddenly feel extremely dizzy...", "You can't think straight...", "You can't move your face properly anymore..."][Game.rng.randi() % 4], "bad")

## tg stimulant withdrawal: +1 ds a step from stage 3 (/datum/movespeed_modifier/stimulants)
static func move_add(h: CHealth) -> float:
	return 0.1 if h.has_meta("addiction") and stage(h, "stimulants") >= 3 else 0.0

## tg stimulant withdrawal: +25% on actions from stage 1 (/datum/actionspeed_modifier/stimulants)
static func action_mult(h: CHealth) -> float:
	return 1.25 if h.has_meta("addiction") and stage(h, "stimulants") >= 1 else 1.0
