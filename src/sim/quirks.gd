class_name Quirks extends RefCounted
## tg quirks (code/datums/quirks/, SSquirks): character traits picked at character
## creation, each with a point value. Negative quirks pay for positive ones (the total must
## be 0 or less, tg's default config) and you can have at most 6 positive ones; some can't
## be taken together (GLOB.quirk_blacklist). The crew get a random balanced set the way tg
## randomises them (SSquirks.randomise_quirks).
## Left out: quirks needing systems this game lacks (species, languages, prosthetics,
## skillchips, silicons, lockers to hide in, fishing, mail, the clown and mime).

## id -> [name, value, description]
const DEFS := {
	# positive_quirks/
	"alcohol_tolerance": ["Alcohol Tolerance", 4, "You become drunk more slowly and suffer fewer drawbacks from alcohol."],
	"drunkhealing": ["Drunken Resilience", 8, "Nothing like a good drink to make you feel on top of the world. Whenever you're drunk, you slowly recover from injuries."],
	"empath": ["Empath", 8, "Whether it's a sixth sense or careful study of body language, it only takes you a quick glance at someone to understand how they feel."],
	"freerunning": ["Freerunning", 8, "You're great at quick moves! You can climb tables more quickly and take no damage from short falls."],
	"friendly": ["Friendly", 2, "You give the best hugs, especially when you're in the right mood."],
	"jolly": ["Jolly", 4, "You sometimes just feel happy, for no reason at all."],
	"light_step": ["Light Step", 4, "You walk with a gentle step; footsteps and stepping on sharp objects is quieter and less painful. Also, your hands and clothes will not get messed in case of stepping in blood."],
	"selfaware": ["Self-Aware", 8, "You know your body well, and can accurately assess the extent of your wounds."],
	"strong_stomach": ["Strong Stomach", 4, "You can eat food discarded on the ground without getting sick, and vomiting affects you less."],
	"throwingarm": ["Throwing Arm", 7, "Your arms have a lot of heft to them! Objects that you throw just always seem to fly farther than everyone else's, and you never miss a toss."],
	"death_mimicry": ["Death Mimicry", 16, "You've mastered the art of faking your demise. Performing a death gasp knocks you unconscious and tricks anyone examining you into believing you've succumbed to your injuries for a short time."],
	# neutral_quirks/
	"bald": ["Smooth-Headed", 0, "You have no hair and are quite insecure about it! Keep your wig on, or at least your head covered up."],
	"deviant_tastes": ["Deviant Tastes", 0, "You dislike food that most people enjoy, and find delicious what they don't."],
	"gamer": ["Gamer", 0, "You are a hardcore gamer, and you have a need to game. You love winning and hate losing."],
	"monochromatic": ["Monochromacy", 0, "You suffer from full colorblindness, and perceive nearly the entire world in blacks and whites."],
	"no_taste": ["Ageusia", 0, "You can't taste anything! Toxic food will still poison you."],
	"phobia": ["Phobia", 0, "You are irrationally afraid of something."],
	"shifty_eyes": ["Shifty Eyes", 0, "Your eyes tend to wander all over the place, whether you mean to or not, causing people to sometimes think you're looking directly at them when you aren't."],
	"vegetarian": ["Vegetarian", 0, "You find the idea of eating meat morally and physically repulsive."],
	# negative_quirks/
	"all_nighter": ["All Nighter", -4, "You didn't get any sleep last night, and people can tell! You'll constantly be in a bad mood and will have a tendency to sleep longer. Stimulants or a nap might help, though."],
	"badback": ["Bad Back", -8, "Thanks to your poor posture, backpacks and other bags never sit right on your back. More evenly weighted objects are fine, though."],
	"blindness": ["Blind", -16, "You are completely blind, nothing can counteract this."],
	"blooddeficiency": ["Blood Deficiency", -8, "Your body can't produce enough blood to sustain itself."],
	"brainproblems": ["Brain Tumor", -12, "You have a little friend in your brain that is slowly destroying it. Better bring some mannitol!"],
	"deafness": ["Deaf", -8, "You are incurably deaf."],
	"depression": ["Depression", -3, "You sometimes just hate life."],
	"family_heirloom": ["Family Heirloom", -2, "You are the current owner of an heirloom, passed down for generations. You have to keep it safe!"],
	"frail": ["Frail", -6, "You have skin of paper and bones of glass! You suffer wounds much more easily than most."],
	"glass_jaw": ["Glass Jaw", -4, "You have a very fragile jaw. Any sufficiently hard blow to your head might knock you out."],
	"hypersensitive": ["Hypersensitive", -2, "For better or worse, everything seems to affect your mood more than it should."],
	"insanity": ["Reality Dissociation Syndrome", -8, "You suffer from a severe disorder that causes very vivid hallucinations and trouble expressing your ideas."],
	"light_drinker": ["Light Drinker", -2, "You just can't handle your drinks and get drunk very quickly."],
	"monophobia": ["Monophobia", -3, "You have an extreme fear of loneliness, and have always tried to stick to large groups."],
	"mute": ["Mute", -4, "For some reason you are completely unable to speak."],
	"narcolepsy": ["Narcolepsy", -8, "You feel drowsy often, and could fall asleep at any moment. Staying caffeinated, walking or even supressing symptoms with stimulants, prescribed or otherwise, can help you get through the shift."],
	"nearsighted": ["Nearsighted", -4, "You are nearsighted without prescription glasses, but spawn with a pair."],
	"nonviolent": ["Pacifist", -8, "The thought of violence makes you sick. So much so, in fact, that you can't hurt anyone."],
	"numb": ["Numb", -4, "You can't feel pain at all."],
	"nyctophobia": ["Nyctophobia", -3, "As far as you can remember, you've always been afraid of the dark. While in the dark without a light source, you constantly feel a sense of dread."],
	"photophobia": ["Photophobia", -4, "Bright lights seem to bother you more than others. Maybe it's a medical condition."],
	"poor_aim": ["Stormtrooper Aim", -4, "You've never hit anything you were aiming for in your life."],
	"prosopagnosia": ["Prosopagnosia", -4, "You have a mental disorder that prevents you from being able to recognize faces at all."],
	"pushover": ["Pushover", -8, "Your first instinct is always to let people push you around. Resisting out of grabs is noticeably more difficult."],
	"pyrophobia": ["Pyrophobia", -3, "You are terrified of fire and flames."],
	"social_anxiety": ["Social Anxiety", -3, "Talking to people is very difficult for you, and you often stutter or even lock up."],
	"softspoken": ["Soft-Spoken", -2, "You are soft-spoken, and your voice is hard to hear."],
	"unstable": ["Unstable", -10, "Due to past troubles, you are unable to recover your sanity if you lose it. Be very careful managing your mood!"],
	# addictions (Addiction): the smoker, alcoholic and junkie
	"smoker": ["Smoker", -4, "Sometimes you just really want a smoke. Probably not great for your lungs."],
	"alcoholic": ["Alcoholic", -4, "You just can't live without alcohol. Your liver is a machine that turns ethanol into acetaldehyde."],
	"junkie": ["Junkie", -6, "You can't get enough of hard drugs."],
}

## tg GLOB.quirk_blacklist (the entries that matter here)
const BLACKLIST := [
	["blindness", "nearsighted"],
	["jolly", "depression", "hypersensitive"],
	["no_taste", "vegetarian", "deviant_tastes", "gamer"],
	["alcohol_tolerance", "light_drinker"],
	["social_anxiety", "mute"],
	["mute", "softspoken"],
	["photophobia", "nyctophobia"],
	["numb", "selfaware"],
	["smoker", "alcoholic", "junkie"],
]
const MAX_POSITIVE := 6 # tg config max_positive_quirks
const DEFAULT_POINTS := 0 # tg config default_quirk_points
const RANDOM_QUIRK_BONUS := 3
const MINIMUM_RANDOM_QUIRKS := 3

static func has(e: Entity, id: String) -> bool:
	if e == null:
		return false
	var m: CMob = e.c(&"mob")
	return m != null and id in m.quirks

static func names(e: Entity) -> Array:
	var m: CMob = e.c(&"mob") if e else null
	var out := []
	if m:
		for q in m.quirks:
			out.append(DEFS[q][0] if DEFS.has(q) else q)
	return out

static func value(id: String) -> int:
	return DEFS[id][1] if DEFS.has(id) else 0

## tg filter_invalid_quirks: drop blacklisted pairs and extra positives, then, while the
## balance is positive, positives from the end.
static func filter_valid(ids: Array) -> Array:
	var out := []
	var positives := []
	var balance := -DEFAULT_POINTS
	for q in ids:
		if not DEFS.has(q) or q in out:
			continue
		var clash := false
		for bl in BLACKLIST:
			if q in bl:
				for other in bl:
					if other != q and other in out:
						clash = true
		if clash:
			continue
		var v := value(q)
		if v > 0:
			if positives.size() >= MAX_POSITIVE:
				continue
			positives.append(q)
		balance += v
		out.append(q)
	while balance > 0 and not positives.is_empty():
		var p: String = positives.pop_back()
		out.erase(p)
		balance -= value(p)
	return out

static func balance(ids: Array) -> int:
	var b := 0
	for q in ids:
		b += value(q)
	return b

## tg randomise_quirks: some quirks at random, then negatives until it balances, then
## positives while there are points to spend.
static func random_set(rng: RandomNumberGenerator) -> Array:
	var pool := DEFS.keys()
	var count := maxi(rng.randi_range(-RANDOM_QUIRK_BONUS, RANDOM_QUIRK_BONUS), MINIMUM_RANDOM_QUIRKS)
	var picked := []
	var score := 0
	var good := 0
	var tries := 0
	while picked.size() < count and tries < 200:
		tries += 1
		var q: String = pool[rng.randi() % pool.size()]
		if q in picked or _clashes(q, picked):
			continue
		if value(q) > 0:
			good += 1
		score += value(q)
		picked.append(q)
	tries = 0
	while score > 0 and tries < 200:
		tries += 1
		var q2: String = pool[rng.randi() % pool.size()]
		if value(q2) >= 0 or q2 in picked or _clashes(q2, picked):
			continue
		score += value(q2)
		picked.append(q2)
	tries = 0
	while score < 0 and good < MAX_POSITIVE and tries < 200:
		tries += 1
		var q3: String = pool[rng.randi() % pool.size()]
		if value(q3) <= 0 or q3 in picked or _clashes(q3, picked):
			continue
		if score + value(q3) > 0:
			continue
		good += 1
		score += value(q3)
		picked.append(q3)
	return filter_valid(picked)

static func _clashes(q: String, picked: Array) -> bool:
	for bl in BLACKLIST:
		if q in bl:
			for other in bl:
				if other != q and other in picked:
					return true
	return false

# ------------------------------------------------------------------ adding them
## tg add_quirk -> quirk/add + add_unique: traumas, items, mood modifiers.
static func apply(e: Entity, ids: Array, give_items := true) -> void:
	var m: CMob = e.c(&"mob")
	var h: CHealth = e.c(&"health")
	var mood: CMood = e.c(&"mood")
	if m == null or h == null:
		return
	for q in filter_valid(ids):
		if q in m.quirks:
			continue
		m.quirks.append(q)
		match q:
			"blindness": Traumas.gain(h, "blindness", Traumas.RES_ABSOLUTE)
			"mute": Traumas.gain(h, "mute", Traumas.RES_ABSOLUTE)
			"monophobia": Traumas.gain(h, "monophobia", Traumas.RES_ABSOLUTE)
			"narcolepsy": Traumas.gain(h, "narcolepsy", Traumas.RES_ABSOLUTE)
			"nonviolent": Traumas.gain(h, "pacifism", Traumas.RES_ABSOLUTE)
			"insanity": Traumas.gain(h, "hallucinations", Traumas.RES_ABSOLUTE)
			"monochromatic": Traumas.gain(h, "color_blindness", Traumas.RES_ABSOLUTE)
			"phobia": Traumas.gain(h, "phobia", Traumas.RES_ABSOLUTE)
			"pyrophobia": Traumas.gain(h, "phobia", Traumas.RES_ABSOLUTE, "fire")
			"hypersensitive":
				if mood: mood.mood_modifier += 0.5
			"unstable":
				if mood: mood.unstable = true
			"all_nighter":
				if mood: mood.add("all_nighter", "all_nighter")
			"bald":
				m.appearance["hair"] = "bald"
				m.refresh_doll()
			"smoker", "alcoholic", "junkie":
				Addiction.quirk_start(h, q)
		if give_items:
			_give_items(e, q)

## tg remove_quirk for all of them: the permanent traumas, mood modifiers and addictions go.
static func remove_all(e: Entity) -> void:
	var m: CMob = e.c(&"mob")
	var h: CHealth = e.c(&"health")
	var mood: CMood = e.c(&"mood")
	if m == null or h == null:
		return
	Traumas.cure_all(h, Traumas.RES_ABSOLUTE)
	if mood:
		if "hypersensitive" in m.quirks:
			mood.mood_modifier -= 0.5
		mood.unstable = false
		for c in ["all_nighter", "jolly", "depression", "family_heirloom", "family_heirloom_missing", "back_pain", "bad_hair_day", "photophobia", "nyctophobia", "gamer_withdrawal"]:
			mood.clear(c)
	h.remove_meta("addiction")
	m.quirks.clear()

## tg item_quirk give_item_to_holder
static func _give_items(e: Entity, q: String) -> void:
	var inv: CInventory = e.c(&"inv")
	if inv == null:
		return
	var item := ""
	match q:
		"nearsighted": item = "prescription_glasses"
		"brainproblems": item = "pill_bottle_mannitol"
		"family_heirloom": item = ["lighter", "dice", "deck_of_cards"][Game.rng.randi() % 3]
		"narcolepsy": item = "coffee"
		"smoker": item = "cigarette_pack"
		"alcoholic": item = "flask"
	if item == "" or not Proto.P.has(item):
		return
	var it := Proto.spawn(item, e.cell)
	if q == "nearsighted" and inv.worn("eyes") == null:
		inv.equip(it, "eyes")
	elif not inv.store(it):
		inv.put_in_hands(it)
	if q == "family_heirloom":
		it.set_meta("heirloom_of", e.id)
		it.display_name = "%s family %s" % [e.display_name.split(" ")[-1], it.display_name]

# ------------------------------------------------------------------ what they do each second
## The quirks with a process() in tg (QUIRK_PROCESSES), once a second.
static func tick(e: Entity, dt: float) -> void:
	var m: CMob = e.c(&"mob")
	if m == null or m.quirks.is_empty():
		return
	var h: CHealth = e.c(&"health")
	var mood: CMood = e.c(&"mood")
	if h == null or h.dead:
		return
	for q in m.quirks:
		match q:
			"jolly":
				if mood and Body.spt_prob(0.416, dt):
					mood.add("jolly", "jolly")
			"depression":
				if mood and Body.spt_prob(0.416, dt):
					mood.add("depression", "depression")
			"drunkhealing":
				# tg: by how drunk you are
				var dk := h.drunk
				if dk >= 61.0:
					h.adjust("brute", -0.8 * dt); h.adjust("burn", -0.4 * dt)
				elif dk >= 41.0:
					h.adjust("brute", -0.4 * dt); h.adjust("burn", -0.2 * dt)
				elif dk >= 6.0:
					h.adjust("brute", -0.1 * dt); h.adjust("burn", -0.05 * dt)
			"brainproblems":
				Organs.apply_damage(h, "brain", 0.2 * dt) # tg degradation_speed
			"blooddeficiency":
				# tg species blood_deficiency_drain_rate: BLOOD_REGEN_FACTOR + BLOOD_DEFICIENCY_MODIFIER
				h.blood_volume = maxf(minf(h.blood_volume, Body.BLOOD_VOLUME_SAFE + 1.0), h.blood_volume - (0.25 + 0.025) * dt)
			"family_heirloom":
				if mood:
					if _holds_heirloom(e):
						mood.clear("family_heirloom_missing")
						mood.add("family_heirloom", "family_heirloom")
					else:
						mood.clear("family_heirloom")
						mood.add("family_heirloom_missing", "family_heirloom_missing")
			"badback":
				var inv: CInventory = e.c(&"inv")
				var bag: Entity = inv.worn("back") if inv else null
				if mood:
					if bag != null and bag.has_c(&"storage"):
						mood.add("back_pain", "back_pain")
					else:
						mood.clear("back_pain")
			"bald":
				var inv2: CInventory = e.c(&"inv")
				if mood:
					if inv2 and inv2.worn("head") != null:
						mood.clear("bad_hair_day")
					else:
						mood.add("bad_hair_day", "bald")
			"all_nighter":
				_all_nighter(e, h, mood, dt)
			"photophobia":
				if mood and not h.knocked_out():
					var bright: bool = Game.lighting != null and Game.lighting.light_at(e.cell) > 0.6 if Game.lighting.has_method("light_at") else false
					if bright and not _eyes_protected(e):
						mood.add("photophobia", "photophobia")
					else:
						mood.clear("photophobia")
			"nyctophobia":
				_nyctophobia(e, h, mood, dt)
			"gamer":
				# tg: 15 minutes without a game and you're in withdrawal
				if mood and Game.time - e.get_meta("last_gamed", 0.0) > 900.0:
					mood.add("gamer_withdrawal", "gamer_withdrawal")

static func _holds_heirloom(e: Entity) -> bool:
	var inv: CInventory = e.c(&"inv")
	if inv == null:
		return false
	for it in inv.all_items():
		if it.get_meta("heirloom_of", -1) == e.id:
			return true
	return false

static func _eyes_protected(e: Entity) -> bool:
	var inv: CInventory = e.c(&"inv")
	var g: Entity = inv.worn("eyes") if inv else null
	return g != null and g.proto in ["sunglasses", "welding_goggles"]

## tg all_nighter process: sleep banks "five more minutes" (x10), stimulants help.
static func _all_nighter(e: Entity, h: CHealth, mood: CMood, dt: float) -> void:
	var bank: float = e.get_meta("five_more_minutes", 0.0)
	var happy := true
	if h.sleeping or h.has_status("sleeping"):
		bank += 10.0 * dt
	elif bank > 0.0:
		bank -= dt
	else:
		happy = h.chems.has("coffee") or h.chems.has("methamphetamine") or h.chems.has("ephedrine")
	e.set_meta("five_more_minutes", bank)
	if mood:
		if mood.has("all_nighter") and happy:
			mood.clear("all_nighter")
		elif not mood.has("all_nighter") and not happy:
			mood.add("all_nighter", "all_nighter")
			Game.tell(e, "You start feeling tired again.", "bad")

## tg fearful component, nyctophobia handler: in the dark without a light, terror builds.
static func _nyctophobia(e: Entity, h: CHealth, mood: CMood, dt: float) -> void:
	if h.knocked_out() or h.has_status("fearless"):
		return
	var dark: bool = Game.lighting != null and Game.lighting.has_method("light_at") and Game.lighting.light_at(e.cell) < 0.2
	if dark and not _has_light(e):
		if mood:
			mood.add("nyctophobia", "nyctophobia")
		h.terror = minf(h.terror + 10.0 * dt, 600.0)
		if Body.spt_prob(5.0, dt):
			Game.tell(e, ["You feel a chill down your spine...", "The darkness presses in on you.", "You'd really like a light right now."][Game.rng.randi() % 3], "warn")
	elif mood:
		mood.clear("nyctophobia")

static func _has_light(e: Entity) -> bool:
	var inv: CInventory = e.c(&"inv")
	if inv == null:
		return false
	for it in inv.hands:
		if it and (it.has_c(&"toggle_light") or it.has_c(&"light")):
			return true
	return false

# ------------------------------------------------------------------ effects other code asks about
## tg TRAIT_ALCOHOL_TOLERANCE (x0.7) and TRAIT_LIGHT_DRINKER (x2) on booze power.
static func booze_mult(e: Entity) -> float:
	var k := 1.0
	if has(e, "alcohol_tolerance"): k *= 0.7
	if has(e, "light_drinker"): k *= 2.0
	return k

## tg TRAIT_HEAVY_SLEEPER (all nighter): sleep and unconsciousness last 25-30% longer.
static func sleep_mult(e: Entity) -> float:
	return Game.rng.randf_range(1.25, 1.30) if has(e, "all_nighter") else 1.0

## tg TRAIT_EASILY_WOUNDED (frail): the wound roll considers 1.5x the damage cap.
static func wound_cap_mult(e: Entity) -> float:
	return 1.5 if has(e, "frail") else 1.0

## tg glass jaw: a brute hit of 5+ to the head has prob(damage, x0.65 if sharp) to knock you out 3 s.
static func glass_jaw(h: CHealth, zone: String, kind: String, dealt: float, sharp: String) -> void:
	if not has(h.e, "glass_jaw") or kind != "brute" or Body.part_of(zone) != "head" or dealt < 5.0:
		return
	if Body.prob(ceilf(dealt * (0.65 if sharp != "" else 1.0))):
		if not h.knocked_out():
			Game.visible_message(h.e.cell, "%s gets knocked out!" % h.e.display_name, "bad")
			Game.tell(h.e, "[b]You get knocked out![/b]", "bad")
		h.knock_out(3.0)

## tg poor_aim: +10 to +35 degrees of spread on every shot.
static func extra_spread(e: Entity) -> float:
	if not has(e, "poor_aim"):
		return 0.0
	return deg_to_rad(Game.rng.randf_range(10.0, 35.0)) * (1.0 if Game.rng.randf() < 0.5 else -1.0)

## tg social_anxiety handle_speech: filler words ("uh," "erm," "um,") and freezing up,
## worse around more people and in a better mood. Returns the new message ("" if you froze).
static func anxious_speech(e: Entity, text: String) -> String:
	if not has(e, "social_anxiety"):
		return text
	var h: CHealth = e.c(&"health")
	if h and h.has_status("fearless"):
		return text
	var near := 0
	for o in Game.in_radius(e.cell, 3, &"mob"):
		if o != e and o.has_c(&"health") and not o.c(&"health").dead:
			near += 1
	var mood: CMood = e.c(&"mood")
	var mod := 1.0
	if mood:
		mod = 1.0 + 0.02 * (50.0 - maxf(50.0, mood.mood_level * (CMood.S_INSANE + 1 - mood.sanity_level)))
	var moodmod := mod * near * 12.5
	var words := text.split(" ")
	var out := PackedStringArray()
	for i in words.size():
		if i > 0 and Body.prob(maxf(5.0, moodmod)):
			out.append(["uh,", "erm,", "um,"][Game.rng.randi() % 3])
			if Body.prob(minf(5.0, moodmod)):
				h.set_status_if_lower("silence", 6.0)
				Game.tell(e, "[b]You feel self-conscious and stop talking. You need a moment to recover![/b]", "bad")
				break
		out.append(words[i])
	return " ".join(out)

## tg prosopagnosia: people you look at are "Unknown" (or their ID's name with a "?").
static func seen_name(viewer: Entity, who: Entity) -> String:
	if viewer == null or who == viewer or not who.has_c(&"mob") or not has(viewer, "prosopagnosia"):
		return who.display_name
	var inv: CInventory = who.c(&"inv")
	var idc: Entity = inv.worn("id") if inv else null
	if idc and idc.has_c(&"idcard") and idc.c(&"idcard").get("owner") != null and str(idc.c(&"idcard").owner) != "":
		return "%s?" % idc.c(&"idcard").owner
	return "Unknown"

## tg deviant_tastes / vegetarian / no_taste / liked foods: how good a food seems to you.
## `base` is the food's own quality (tg recipe complexity); meat is -2 each for vegetarians.
static func food_quality(e: Entity, base: int, meaty: bool, favourite: bool) -> int:
	if has(e, "no_taste"):
		return 0
	var q := base
	if favourite:
		q += 2 # tg LIKED_FOOD_QUALITY_CHANGE
	if meaty and has(e, "vegetarian"):
		q -= 2 * 2 # tg: meat is a disliked food type (and raw meat gore)
	if has(e, "deviant_tastes"):
		q = -q
	return mini(q, 7)
