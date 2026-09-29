class_name CMood extends Component
## tg /datum/mood (code/datums/mood.dm) and its mood events (code/datums/mood_events/):
## moodlets, each with a category, a mood change and maybe a timeout, add up to a mood;
## the mood level (1 wishing you were dead .. 9 loving life) drags sanity (0-150) up or
## down over time. Low sanity slows you down and your hands, lowers your crit threshold
## and, at the bottom, makes you hallucinate; high sanity speeds your hands up.
## Numbers are tg's. Local additions: thirst moodlets (this game has thirst; tg doesn't).

# tg __DEFINES/mood.dm
const MOOD_HAPPY4 := 15.0
const MOOD_HAPPY3 := 10.0
const MOOD_HAPPY2 := 6.0
const MOOD_HAPPY1 := 2.0
const MOOD_SAD1 := -3.0
const MOOD_SAD2 := -7.0
const MOOD_SAD3 := -15.0
const MOOD_SAD4 := -20.0
enum { SAD4 = 1, SAD3, SAD2, SAD1, NEUTRAL, HAPPY1, HAPPY2, HAPPY3, HAPPY4 }
const SANITY_MAXIMUM := 150.0
const SANITY_GREAT := 125.0
const SANITY_NEUTRAL := 100.0
const SANITY_DISTURBED := 75.0
const SANITY_UNSTABLE := 50.0
const SANITY_CRAZY := 25.0
const SANITY_INSANE := 0.0
enum { S_GREAT = 1, S_NEUTRAL, S_DISTURBED, S_UNSTABLE, S_CRAZY, S_INSANE }
const MINOR_INSANITY_PEN := 5.0
const MAJOR_INSANITY_PEN := 10.0
## tg sanity colours on the mood face
const SANITY_COLORS := {S_GREAT: Color("#2eeb9a"), S_NEUTRAL: Color("#86d656"), S_DISTURBED: Color("#4b96c4"), S_UNSTABLE: Color("#dfa65b"), S_CRAZY: Color("#f38943"), S_INSANE: Color("#f15d36")}

## tg mood events used here: id -> [description, mood_change, timeout (s, 0 = until cleared), flags]
## flags: "pain" (skipped with painkillers, tg MOOD_EVENT_PAIN), "food", "hidden"
const EVENTS := {
	# needs_events.dm
	"too_wellfed": ["I think I've eaten too much.", 0, 0],
	"wellfed": ["I'm stuffed!", 8, 0],
	"fed": ["I have recently had some food.", 5, 0],
	"hungry": ["I'm getting a bit hungry.", -3, 0],
	"hungry_very": ["I'm hungry!", -6, 0],
	"starving": ["I'm starving!", -10, 0],
	"thirsty": ["I'm getting thirsty.", -3, 0], # local: thirst
	"thirsty_very": ["I'm parched!", -6, 0], # local
	"dehydrated": ["I need water, now!", -10, 0], # local
	"gross": ["I saw something gross.", -4, 0],
	"verygross": ["I think I'm going to puke...", -6, 0],
	"disgusted": ["Oh god, that's disgusting...", -8, 0],
	"shower": ["I have recently had a nice shower.", 4, 300],
	# generic_negative_events.dm
	"on_fire": ["I'M ON FIRE!!!", -12, 0],
	"suffocation": ["CAN'T... BREATHE...", -12, 0],
	"cold": ["It's way too cold in here.", -5, 0],
	"hot": ["It's getting hot in here.", -5, 0],
	"slipped": ["I slipped. I should be more careful next time...", -2, 180],
	"dismembered": ["AHH! MY LIMB! I WAS USING THAT!", -10, 480, "pain"],
	"embedded": ["Pull it out!", -7, 0, "pain"],
	"table": ["Someone threw me on a table!", -2, 120],
	"table_limbsmash": ["That fucking table, man that hurts...", -3, 180, "pain"],
	"brain_damage": ["I should have paid attention to the epilepsy warning.", -3, 300],
	"jittery": ["I'm nervous and on edge and I can't stand still!!", -2, 0],
	"vomit": ["I just threw up. Gross.", -2, 120],
	"vomitself": ["I just threw up all over myself. This is disgusting.", -4, 180],
	"startled": ["Hearing that word made me think about something scary.", -1, 60],
	"phobia": ["I saw something very frightening!", -4, 240],
	"surgery": ["THEY'RE CUTTING ME OPEN!!", -8, 0, "pain"],
	"surgery_success": ["That surgery really hurt... Glad it worked, I guess...", -8, 180, "pain"],
	"surgery_failure": ["AHHHHHGH! THEY FILLETED ME ALIVE!", -8, 600, "pain"],
	"splattered_with_blood": ["Eugh, I just got coated in blood!", -4, 240],
	"smoke_in_face": ["Cigarette smoke is disgusting.", -3, 30],
	"all_nighter": ["I didn't sleep at all last night. I'm exhausted.", -5, 0],
	"hang_over": ["I have a killer hang over!", -4, 60],
	# generic_positive_events.dm
	"hug": ["Hugs are nice.", 1, 120],
	"bear_hug": ["I got squeezed very tightly, but it was quite nice.", 1, 120],
	"warmhug": ["Warm cozy hugs are the best!", 1, 120],
	"betterhug": ["%s was very nice to me.", 3, 240],
	"besthug": ["%s is great to be around, they make me feel so happy!", 5, 240],
	"arcade": ["I beat the arcade game!", 3, 480],
	"saved_life": ["It feels good to save a life.", 6, 480],
	"goodmusic": ["There is something soothing about this music.", 3, 60],
	"helped_up": ["Helping them up felt good!", 2, 45],
	"jolly": ["I feel happy for no particular reason.", 6, 120],
	"book_nerd": ["I have recently read a book.", 1, 300],
	"enjoying_department_area": ["I love my job.", 1, 0],
	# death.dm
	"see_death": ["I just saw %s die. How horrible...", -8, 300],
	# food_events.dm / drink_events.dm / drug_events.dm
	"favorite_food": ["I really enjoyed eating that.", 5, 240, "food"],
	"gross_food": ["I really didn't like that food.", -2, 240, "food"],
	"disgusting_food": ["That food was disgusting!", -6, 240, "food"],
	"food": ["That food was %s.", 0, 300, "food"],
	"quality_revolting": ["That drink was the worst thing I've ever consumed.", -8, 420],
	"quality_nice": ["That drink wasn't bad at all.", 2, 420],
	"quality_good": ["That drink was pretty good.", 4, 420],
	"quality_verygood": ["That drink was great!", 6, 420],
	"quality_fantastic": ["That drink was amazing!", 8, 420],
	"sweetcoffee": ["The bitter sweet taste of coffee was not too bad", 2, 300],
	"drunk": ["Everything just feels better after a drink or two.", 3, 0],
	"drunk_after": ["The buzz might be gone, but I still feel good.", 2, 300],
	"smoked": ["I have had a smoke recently.", 2, 360],
	"high": ["Woooow duudeeeeee... I'm tripping baaalls...", 6, 0],
	"overdose": ["I think I took a bit too much of that %s!", -8, 300],
	"withdrawal_light": ["I could use some %s...", -2, 0],
	"withdrawal_medium": ["I really need %s.", -5, 0],
	"withdrawal_severe": ["Oh god, I need some of that %s!", -8, 0],
	"narcotic_medium": ["I feel comfortably numb.", 4, 180],
	"narcotic_heavy": ["I feel like I'm wrapped up in cotton!", 9, 180],
	"stimulant_medium": ["I have so much energy! I feel like I could do anything!", 4, 180],
	"stimulant_heavy": ["Eh ah AAAAH! HA HA HA HA HAA! Uuuh.", 6, 180],
	"nicotine_withdrawal_moderate": ["Haven't had a smoke in a while. Feeling a little on edge... ", -5, 0],
	"nicotine_withdrawal_severe": ["Head pounding. Cold sweating. Feeling anxious. Need a smoke to calm down!", -8, 0],
	"chemical_euphoria": ["Heh...hehehe...hehe...", 4, 0],
	"chemical_laughter": ["Laughter really is the best medicine! Or is it?", 4, 180],
	# beauty_events.dm
	"horridroom": ["This room looks terrible!", -5, 0],
	"badroom": ["This room looks really bad.", -3, 0],
	"decentroom": ["This room looks alright.", 1, 0],
	"goodroom": ["This room looks really pretty!", 3, 0],
	"greatroom": ["This room is beautiful!", 5, 0],
	# genetics: generic_negative_events.dm and mutations/aoe_moodlet.dm
	"hulk": ["HULK SMASH!", -4, 0],
	"epilepsy": ["I should have paid attention to the epilepsy warning.", -3, 300],
	"seen_ugly": ["Something is seriously wrong with %s!", -3, 120],
	"seen_ugly_weak": ["Something looks wrong about %s.", -1, 120],
	"seen_ugly_self": ["...Is THAT what I look like?!", -2, 300],
	"seen_pretty": ["%s looks pretty good - must be a new haircut or something.", 3, 120],
	"seen_pretty_weak": ["%s looks alright - it must be the lighting in here.", 1, 120],
	"seen_pretty_self": ["I look pretty good!", 2, 300],
	# quirks (their own moodlets)
	"depression": ["I can't even end it all!", -15, 60],
	"family_heirloom": ["My family heirloom is safe with me.", 1, 0],
	"family_heirloom_missing": ["I'm missing my family heirloom...", -4, 0],
	"photophobia": ["The lights are too bright...", -3, 0],
	"nyctophobia": ["It sure is dark around here...", -3, 0],
	"claustrophobia": ["Why do I feel trapped?! Let me out!!!", -7, 60],
	"bad_touch": ["I don't like when people touch me.", -3, 240],
	"bad_touch_bear_hug": ["I just got squeezed way too hard.", -1, 120],
	"bald": ["I need something to cover my head...", -3, 0],
	"back_pain": ["Bags never sit right on my back, this hurts like hell!", -15, 0],
	"gamer_withdrawal": ["I wish I was gaming right now...", -5, 0],
	"gamer_lost": ["If I'm not good at video games, can I truly call myself a gamer?", -6, 600],
	"gamer_won": ["I love winning video games!", 6, 300],
}

## tg food quality words (GLOB.food_quality_description)
const FOOD_QUALITY := ["", "okay", "nice", "good", "very good", "fantastic", "amazing", "divine"]

var mood := 0.0
var shown_mood := 0.0
var sanity := SANITY_NEUTRAL
var mood_level := NEUTRAL
var sanity_level := S_NEUTRAL
var insanity_effect := 0.0 # tg: how far the crit threshold has been raised
var mood_modifier := 1.0
var positive_mood_modifier := 1.0 # tg: quirks scale good / bad moodlets
var negative_mood_modifier := 1.0
var positive_length_modifier := 1.0
var negative_length_modifier := 1.0
var apathetic := false # tg TRAIT_APATHETIC
var unstable := false # tg TRAIT_UNSTABLE: sanity can only go down
## category -> {id, desc, change, until (Game.time, 0 = none), hidden, flags}
var events := {}
var _hallu_at := 0.0
var _beauty_t := 0.0

func key() -> StringName:
	return &"mood"

# ------------------------------------------------------------------ moodlets
## tg living/add_mood_event: does nothing for things without a mood.
static func event(who: Entity, category: String, id: String, arg = null) -> void:
	if who and is_instance_valid(who) and who.has_c(&"mood"):
		who.c(&"mood").add(category, id, arg)

static func clear_event(who: Entity, category: String) -> void:
	if who and is_instance_valid(who) and who.has_c(&"mood"):
		who.c(&"mood").clear(category)

## tg surgery_operation/update_surgery_mood: drink (up to 90%) or painkillers let you
## ignore it; the unconscious aren't traumatised unless it started while they were awake.
static func surgery(patient: Entity, state: String) -> void:
	var h: CHealth = patient.c(&"health")
	var md: CMood = patient.c(&"mood")
	if h == null or md == null:
		return
	if h.chems.has("morphine") or Quirks.has(patient, "numb") or Body.prob(clampf(h.drunk, 0.0, 90.0)):
		md.clear("surgery")
		return
	if h.knocked_out():
		var ev = md.events.get("surgery")
		if ev == null or ev["id"] != "surgery":
			return
	match state:
		"started": md.add("surgery", "surgery")
		"success": md.add("surgery", "surgery_success")
		"failure": md.add("surgery", "surgery_failure")

## tg send_death_moodlets: everyone who sees it happen (awake and not blind) is shaken.
static func saw_death(dead: Entity, gibbed := false) -> void:
	for o in Game.in_radius(dead.cell, 7, &"mood"):
		if o == dead:
			continue
		var oh: CHealth = o.c(&"health")
		if oh == null or oh.dead or oh.knocked_out() or StatusFx.blind(oh):
			continue
		if Game.lighting and o.cell.distance_to(dead.cell) > 1.5 and not Game.lighting._los(o.cell, dead.cell):
			continue
		var md: CMood = o.c(&"mood")
		md.add("saw_death", "see_death", dead.display_name)
		if gibbed:
			md.events["saw_death"]["change"] = floorf(md.events["saw_death"]["change"] * 1.2)
			md.events["saw_death"]["desc"] = "%s just exploded in front of me!!" % dead.display_name
			md._update()

## tg add_mood_event. `arg` fills a %s in the description (a name, a drug...). A moodlet
## of the same type already there is refreshed (its timeout restarts), not stacked.
func add(category: String, id: String, arg = null) -> void:
	if not EVENTS.has(id):
		push_warning("unknown mood event %s" % id)
		return
	var d: Array = EVENTS[id]
	var flags: String = d[3] if d.size() > 3 else ""
	var h: CHealth = e.c(&"health")
	# tg MOOD_EVENT_PAIN: painkillers (TRAIT_ANALGESIA) keep the painful ones away
	if flags == "pain" and h and (h.chems.has("morphine") or h.chems.has("miners_salve") or Quirks.has(e, "numb")):
		return
	var change: float = d[1]
	var timeout: float = d[2]
	var desc: String = d[0]
	if id == "food":
		var q: int = clampi(int(arg), 1, 7)
		change = ceilf(1.0 + 1.5 * q) # tg calculate_mood_change
		desc = desc % FOOD_QUALITY[q]
	elif desc.contains("%s"):
		desc = desc % (str(arg) if arg != null else "someone")
	var ex = events.get(category)
	if ex != null and ex["id"] == id:
		# tg be_refreshed: the timeout restarts; seeing more deaths makes it worse (x1.5)
		if timeout > 0.0:
			ex["until"] = Game.time + timeout * _length_mod(ex["change"])
		if id == "see_death":
			ex["change"] = floorf(ex["change"] * 1.5)
			_update()
		elif id == "food" and change > ex["change"]:
			ex["change"] = change
			ex["desc"] = desc
			_update()
		return
	change = floorf(change)
	events[category] = {"id": id, "desc": desc, "change": change, "until": (Game.time + timeout * _length_mod(change)) if timeout > 0.0 else 0.0, "hidden": flags == "hidden"}
	_update()

func _length_mod(change: float) -> float:
	return maxf(positive_length_modifier if change > 0.0 else negative_length_modifier, 0.1)

## tg clear_mood_event
func clear(category: String) -> void:
	if events.erase(category):
		_update()

func has(category: String) -> bool:
	return events.has(category)

## tg update_mood: the sum, then the level it falls in.
func _update() -> void:
	mood = 0.0
	shown_mood = 0.0
	if not apathetic:
		for c in events:
			var ev: Dictionary = events[c]
			var m: float = ev["change"] * maxf(positive_mood_modifier if ev["change"] > 0.0 else negative_mood_modifier, 0.0)
			mood += m
			if not ev["hidden"]:
				shown_mood += m
		mood *= maxf(mood_modifier, 0.0)
		shown_mood *= maxf(mood_modifier, 0.0)
	# tg switch(mood): ranges include both ends, the first match wins
	if mood <= MOOD_SAD4: mood_level = SAD4
	elif mood <= MOOD_SAD3: mood_level = SAD3
	elif mood <= MOOD_SAD2: mood_level = SAD2
	elif mood <= MOOD_SAD1: mood_level = SAD1
	elif mood <= MOOD_HAPPY1: mood_level = NEUTRAL
	elif mood <= MOOD_HAPPY2: mood_level = HAPPY1
	elif mood <= MOOD_HAPPY3: mood_level = HAPPY2
	elif mood <= MOOD_HAPPY4: mood_level = HAPPY3
	else: mood_level = HAPPY4

# ------------------------------------------------------------------ sanity
## tg /datum/mood/process (SSmood, every second)
func tick(dt: float) -> void:
	var h: CHealth = e.c(&"health")
	if h == null or h.dead:
		return
	# timeouts
	var gone := []
	for c in events:
		var u: float = events[c]["until"]
		if u > 0.0 and Game.time >= u:
			gone.append(c)
	for c in gone:
		events.erase(c)
	if not gone.is_empty():
		_update()
	_conditions(h)
	match mood_level:
		SAD4: _adjust_sanity(-0.3 * dt, SANITY_INSANE)
		SAD3: _adjust_sanity(-0.15 * dt, SANITY_CRAZY)
		SAD2: _adjust_sanity(-0.1 * dt, SANITY_UNSTABLE)
		SAD1: _adjust_sanity(-0.05 * dt, SANITY_UNSTABLE)
		NEUTRAL: _adjust_sanity(0.0, SANITY_UNSTABLE)
		HAPPY1: _adjust_sanity(0.2 * dt, SANITY_UNSTABLE)
		HAPPY2: _adjust_sanity(0.3 * dt, SANITY_UNSTABLE)
		HAPPY3: _adjust_sanity(0.4 * dt, SANITY_NEUTRAL, SANITY_MAXIMUM)
		HAPPY4: _adjust_sanity(0.6 * dt, SANITY_NEUTRAL, SANITY_MAXIMUM)
	# tg /datum/status_effect/hallucination/sanity: crazy every 4-8 min, insane every 2-4
	if sanity_level >= S_CRAZY and not h.has_status("fearless"):
		if _hallu_at <= 0.0:
			_hallu_at = Game.time + _hallu_interval()
		elif Game.time >= _hallu_at:
			_hallu_at = Game.time + _hallu_interval()
			Hallucinations.cause(h, Hallucinations._pick(Hallucinations.TIER_UNCOMMON))
	else:
		_hallu_at = 0.0

func _hallu_interval() -> float:
	return Game.rng.randf_range(120.0, 240.0) if sanity_level == S_INSANE else Game.rng.randf_range(240.0, 480.0)

## tg set_sanity: below `minimum` it only creeps back up (+0.7); above `maximum` it's capped.
func _adjust_sanity(amount: float, minimum := SANITY_INSANE, maximum := SANITY_GREAT, override := false) -> void:
	set_sanity(sanity + amount, minimum, maximum, override)

func set_sanity(amount: float, minimum := SANITY_INSANE, maximum := SANITY_GREAT, override := false) -> void:
	if amount < minimum and sanity < minimum:
		amount = sanity + 0.7
	if not override and unstable:
		amount = minf(sanity, amount)
	if amount > maximum:
		amount = minf(amount, maximum)
	if apathetic:
		amount = SANITY_NEUTRAL
	if is_equal_approx(amount, sanity):
		return
	sanity = amount
	if sanity <= SANITY_CRAZY: sanity_level = S_INSANE
	elif sanity <= SANITY_UNSTABLE: sanity_level = S_CRAZY
	elif sanity <= SANITY_DISTURBED: sanity_level = S_UNSTABLE
	elif sanity <= SANITY_NEUTRAL: sanity_level = S_DISTURBED
	elif sanity <= SANITY_GREAT + 1.0: sanity_level = S_NEUTRAL
	else: sanity_level = S_GREAT
	# tg set_crit_threshold: going crazy raises the crit line
	insanity_effect = MAJOR_INSANITY_PEN if sanity_level == S_INSANE else (MINOR_INSANITY_PEN if sanity_level == S_CRAZY else 0.0)

## tg /datum/movespeed_modifier/sanity: insane +1, crazy +0.5, unstable +0.25 ds a step.
func move_add() -> float:
	match sanity_level:
		S_INSANE: return 0.1
		S_CRAZY: return 0.05
		S_UNSTABLE: return 0.025
	return 0.0

## tg /datum/actionspeed_modifier/low_sanity (+25%) and high_sanity (-10%) on do_afters.
func action_mult() -> float:
	if sanity_level in [S_INSANE, S_CRAZY, S_UNSTABLE]:
		return 1.25
	if sanity_level in [S_NEUTRAL, S_GREAT]:
		return 0.9
	return 1.0

# ------------------------------------------------------------------ what the body is going through
## The moodlets tg keeps up to date as things change: hunger (update_nutrition_moodlets),
## body temperature (body_temperature_alerts), jitters, disgust (stomach), drunkenness,
## being on fire, embedded objects, brain damage, and how nice the room is.
func _conditions(h: CHealth) -> void:
	var n: CNeeds = e.c(&"needs")
	if n:
		var nut := n.nutrition * Body.NUTRITION_SCALE
		if nut >= 550.0: add("nutrition", "too_wellfed")
		elif nut >= 450.0: add("nutrition", "wellfed")
		elif nut >= 350.0: add("nutrition", "fed")
		elif nut >= 250.0: clear("nutrition")
		elif nut >= 200.0: add("nutrition", "hungry")
		elif nut >= 150.0: add("nutrition", "hungry_very")
		else: add("nutrition", "starving")
		# local: the same steps for thirst
		var hyd := n.hydration * Body.NUTRITION_SCALE
		if hyd >= 250.0: clear("thirst")
		elif hyd >= 200.0: add("thirst", "thirsty")
		elif hyd >= 150.0: add("thirst", "thirsty_very")
		else: add("thirst", "dehydrated")
	if h.body_temp > Defs.BODYTEMP_HEAT_DAMAGE_LIMIT:
		clear("cold")
		add("hot", "hot")
	elif h.body_temp < Defs.BODYTEMP_COLD_DAMAGE_LIMIT and h.drunk <= 0.0:
		clear("hot")
		add("cold", "cold")
	else:
		clear("cold")
		clear("hot")
	if h.on_fire > 0.0:
		add("on_fire", "on_fire")
	else:
		clear("on_fire")
	if h.has_status("jitter"):
		add("jittery", "jittery")
	else:
		clear("jittery")
	# tg stomach handle_disgust: DISGUST_LEVEL_GROSS 25, VERYGROSS 50, DISGUSTED 75
	if h.disgust >= 75.0:
		add("disgust", "disgusted")
	elif h.disgust >= 50.0:
		add("disgust", "verygross")
	elif h.disgust >= 25.0:
		add("disgust", "gross")
	else:
		clear("disgust")
	if h.drunk > 0.0:
		add("drunk", "drunk")
	elif has("drunk"):
		# tg inebriated on_remove: the afterglow
		clear("drunk")
		add("drunk", "drunk_after")
	if not h.embedded.is_empty():
		add("embedded", "embedded")
	else:
		clear("embedded")
	var brain: float = h.organs.get("brain", {}).get("dmg", 0.0)
	if brain >= 60.0:
		add("brain_damage", "brain_damage")
	# area beauty, every few seconds
	_beauty_t -= 1.0
	if _beauty_t <= 0.0:
		_beauty_t = 5.0
		_room_beauty()

## tg update_beauty: average beauty per tile of the room you're in (not outdoors, not in
## rooms of 150+ tiles). Dirt and blood count against it; plants, posters and clocks for it.
const BEAUTY := {"blood": -100.0, "blood_trail": -50.0, "vomit": -150.0, "glass": -100.0, "fuel": -50.0, "oil": -100.0, "scorch": -50.0, "peel": -50.0}
const BEAUTY_PROTOS := {"potted_plant": 500.0, "wall_clock": 200.0}

func _room_beauty() -> void:
	var ar := Game.map.area_at(e.cell)
	if ar == null or Game.map.is_outdoor(e.cell) or ar.cells.size() >= 150 or ar.cells.is_empty():
		clear("area_beauty")
		return
	var total := 0.0
	for c in ar.cells:
		for x in Game.at(c):
			if x.has_c(&"decal"):
				var d: CDecal = x.c(&"decal")
				var k := d.kind
				if d.blood and d.blood_kind in ["trail", "drip"]:
					k = "blood_trail"
				total += BEAUTY.get(k, 0.0)
			elif BEAUTY_PROTOS.has(x.proto):
				total += BEAUTY_PROTOS[x.proto]
			elif x.proto.begins_with("poster"):
				total += 300.0
	var beauty := total / ar.cells.size()
	if beauty <= -66.0: add("area_beauty", "horridroom")
	elif beauty <= -33.0: add("area_beauty", "badroom")
	elif beauty < 33.0: clear("area_beauty")
	elif beauty < 66.0: add("area_beauty", "decentroom")
	elif beauty < 100.0: add("area_beauty", "goodroom")
	else: add("area_beauty", "greatroom")

# ------------------------------------------------------------------ reading it
const MOOD_WORDS := {SAD4: "I wish I was dead!", SAD3: "I feel terrible...", SAD2: "I feel very upset.", SAD1: "I'm a bit sad.", NEUTRAL: "I'm alright.", HAPPY1: "I feel pretty okay.", HAPPY2: "I feel pretty good.", HAPPY3: "I feel amazing!", HAPPY4: "I love life!"}

## tg print_mood (clicking the mood face)
func report() -> String:
	var lines := ["[b]My current mental status:[/b]"]
	var n: CNeeds = e.c(&"needs")
	if n:
		var nut := n.nutrition * Body.NUTRITION_SCALE
		var hs := "I'm completely stuffed!" if nut >= 550 else ("I'm well fed!" if nut >= 450 else ("I'm not hungry." if nut >= 350 else ("I could use a bite to eat." if nut >= 250 else ("[color=#ffb84a]I'm feeling hungry.[/color]" if nut >= 200 else ("[color=#ffb84a]I feel quite hungry.[/color]" if nut >= 150 else "[color=#ff5a4a][b]I'm starving![/b][/color]")))))
		lines.append("My hunger: " + hs)
	var h: CHealth = e.c(&"health")
	if h and h.drunk >= 1.0:
		var dk := h.drunk
		lines.append("My current drunkenness: " + ("I'm feeling a little tipsy." if dk <= 10 else ("I'm feeling a bit drunk." if dk <= 21 else ("I'm feeling quite drunk." if dk <= 41 else ("I'm feeling very drunk." if dk <= 61 else ("[color=#ffb84a]I'm feeling like a mess.[/color]" if dk <= 81 else "[color=#ff5a4a][b]I'm completely wasted.[/b][/color]"))))))
	if apathetic:
		lines.append("My mood: [color=#8a9cb0]I don't feel anything.[/color]")
	else:
		var s := sanity
		var st := "[color=#6ae88a][b]My mind feels like a temple![/b][/color]" if s >= SANITY_GREAT else ("[color=#6ae88a]I have been feeling great lately![/color]" if s >= SANITY_NEUTRAL else ("[color=#6ae88a]I have felt quite decent lately.[/color]" if s >= SANITY_DISTURBED else ("[color=#ffb84a]I'm feeling a little bit unhinged...[/color]" if s >= SANITY_UNSTABLE else ("[color=#ffb84a]I'm freaking out!![/color]" if s >= SANITY_CRAZY else "[color=#ff5a4a][b]AHAHAHAHAHAHAHAHAHAH!![/b][/color]"))))
		lines.append("My current sanity: " + st)
		var mc := "#6ae88a" if mood_level > NEUTRAL else ("#8a9cb0" if mood_level == NEUTRAL else ("#ffb84a" if mood_level == SAD1 else "#ff5a4a"))
		lines.append("My current mood: [color=%s]%s[/color]" % [mc, MOOD_WORDS[mood_level]])
	lines.append("Moodlets:")
	if events.is_empty():
		lines.append("• [color=#8a9cb0]I don't have much of a reaction to anything right now.[/color]")
	for c in events:
		var ev: Dictionary = events[c]
		var ch: float = ev["change"]
		var col := "#ff5a4a" if ch <= MOOD_SAD2 else ("#ffb84a" if ch <= MOOD_SAD1 else ("#8a9cb0" if ch <= 0.0 else ("#9ad8ff" if ch <= MOOD_HAPPY1 else "#6ae88a")))
		lines.append("• [color=%s]%s[/color]" % [col, ev["desc"]])
	var qs: Array = Quirks.names(e)
	if not qs.is_empty():
		lines.append("You have these quirks: %s." % ", ".join(qs))
	return "\n".join(lines)
