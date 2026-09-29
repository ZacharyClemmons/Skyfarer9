class_name Traumas extends RefCounted
## tg brain traumas (code/datums/brain_damage) and the fear they can bring
## (datums/components/fearful). A trauma is {id, group, res, ...its own state} in
## CHealth.traumas. Brain damage rolls for them (Organs._roll_for_brain_trauma), head
## fractures cycle them (Body, TRAUMA_RESILIENCE_WOUND), and they're cured by resilience:
## neurine for basic ones, brain surgery for severe ones.
##
## Left out of the random pools because this game has nothing for them to act on: the
## special traumas that need ghosts, magic or bluespace (godwoken, bluespace prophet,
## quantum alignment, primal instincts, imaginary friend, split personality, obsession).

const RES_BASIC := 1
const RES_SURGERY := 2
const RES_LOBOTOMY := 3
const RES_WOUND := 4
const RES_MAGIC := 5
const RES_ABSOLUTE := 6
const LIMITS := {RES_BASIC: 3, RES_SURGERY: 2, RES_LOBOTOMY: 3, RES_WOUND: 2, RES_MAGIC: 3, RES_ABSOLUTE: 1 << 30}

# tg __DEFINES/mood.dm terror
const TERROR_MESSAGE_CD := 15.0
const TERROR_BUILDUP_PASSIVE_DECREASE := 15.0
const TERROR_BUILDUP_FEAR := 150.0
const TERROR_BUILDUP_TERROR := 300.0
const TERROR_BUILDUP_PANIC := 500.0
const TERROR_BUILDUP_PASSIVE_MAXIMUM := 600.0
const TERROR_BUILDUP_HEART_ATTACK := 800.0
const TERROR_BUILDUP_MAXIMUM := 1000.0
const PANIC_ATTACK_TERROR_AMOUNT := 50.0
const PHOBIA_CHECK_DELAY := 5.0
const PHOBIA_FREAKOUT_DELAY := 12.0
const PHOBIA_WORD_TERROR_BUILDUP := 40.0
const PHOBIA_FREAKOUT_TERROR_BUILDUP := 120.0
const TERROR_STARTLE_COOLDOWN := 12.0
const TERROR_STARTLE_MINIMUM_DIFFERENCE := 40.0

## name, scan (health analyzer), gain/lose text; group is the tg subtype.
const DEFS := {
	# --- mild (TRAUMA_RESILIENCE_BASIC)
	"hallucinations": {"group": "mild", "name": "Hallucinations", "scan": "schizophrenia",
		"gain": "You feel your grip on reality slipping...", "lose": "You feel more grounded."},
	"stuttering": {"group": "mild", "name": "Stuttering", "scan": "reduced mouth coordination",
		"gain": "Speaking clearly is getting harder.", "lose": "You feel in control of your speech."},
	"dumbness": {"group": "mild", "name": "Dumbness", "scan": "reduced brain activity",
		"gain": "You feel dumber.", "lose": "You feel smart again."},
	"speech_impediment": {"group": "mild", "name": "Speech Impediment", "scan": "communication disorder",
		"gain": "You can't seem to form any coherent thoughts!", "lose": "Your mind feels more clear."},
	"concussion": {"group": "mild", "name": "Concussion", "scan": "concussion",
		"gain": "Your head hurts!", "lose": "The pressure inside your head starts fading."},
	"healthy": {"group": "mild", "name": "Anosognosia", "scan": "self-awareness deficit",
		"gain": "You feel great!", "lose": "You no longer feel perfectly healthy."},
	"muscle_weakness": {"group": "mild", "name": "Muscle Weakness", "scan": "weak motor nerve signal",
		"gain": "Your muscles feel oddly faint.", "lose": "You feel in control of your muscles again."},
	"muscle_spasms": {"group": "mild", "name": "Muscle Spasms", "scan": "nervous fits",
		"gain": "Your muscles feel oddly faint.", "lose": "You feel in control of your muscles again."},
	"nervous_cough": {"group": "mild", "name": "Nervous Cough", "scan": "nervous cough",
		"gain": "Your throat itches incessantly...", "lose": "Your throat stops itching."},
	"expressive_aphasia": {"group": "mild", "name": "Expressive Aphasia", "scan": "inability to form complex sentences",
		"gain": "You lose your grasp on complex words.", "lose": "You feel your vocabulary returning to normal again."},
	"mind_echo": {"group": "mild", "name": "Mind Echo", "scan": "looping neural pattern",
		"gain": "You feel a faint echo of your thoughts...", "lose": "The faint echo fades away."},
	"color_blindness": {"group": "mild", "name": "Achromatopsia", "scan": "colorblindness",
		"gain": "The world around you seems to lose its color.", "lose": "The world feels bright and colorful again."},
	"possessive": {"group": "mild", "name": "Possessive", "scan": "possessiveness",
		"gain": "You start to worry about your belongings.", "lose": "You worry less about your belongings."},
	"phobia": {"group": "mild", "name": "Phobia", "scan": "phobia",
		"gain": "You start finding %s very unnerving...", "lose": "You no longer feel afraid of %s."},
	# --- severe (TRAUMA_RESILIENCE_SURGERY)
	"mute": {"group": "severe", "name": "Mutism", "scan": "extensive damage to the brain's speech center",
		"gain": "You forget how to speak!", "lose": "You suddenly remember how to speak."},
	"aphasia": {"group": "severe", "name": "Aphasia", "scan": "extensive damage to the brain's language center",
		"gain": "You have trouble forming words in your head...", "lose": "You suddenly remember how languages work."},
	"blindness": {"group": "severe", "name": "Cerebral Blindness", "scan": "extensive damage to the brain's occipital lobe",
		"gain": "You can't see!", "lose": "Your vision returns."},
	"paralysis": {"group": "severe", "name": "Paralysis", "scan": "cerebral paralysis",
		"gain": "You can't feel %s anymore!", "lose": "You can feel %s again!"},
	"narcolepsy": {"group": "severe", "name": "Narcolepsy", "scan": "traumatic narcolepsy",
		"gain": "You have a constant feeling of drowsiness...", "lose": "You feel awake and aware again."},
	"monophobia": {"group": "severe", "name": "Monophobia", "scan": "monophobia",
		"gain": "You feel really lonely...", "lose": "You feel like you could be safe on your own."},
	"discoordination": {"group": "severe", "name": "Discoordination", "scan": "extreme discoordination",
		"gain": "You can barely control your hands!", "lose": "You feel in control of your hands again."},
	"pacifism": {"group": "severe", "name": "Traumatic Non-Violence", "scan": "pacific syndrome",
		"gain": "You feel oddly peaceful.", "lose": "You no longer feel compelled to not harm."},
	"hypnotic_stupor": {"group": "severe", "name": "Hypnotic Stupor", "scan": "oneiric feedback loop",
		"gain": "You feel somewhat dazed.", "lose": "You feel like a fog was lifted from your mind."},
	"dyslexia": {"group": "severe", "name": "Dyslexia", "scan": "dyslexia",
		"gain": "You have trouble reading or writing...", "lose": "You suddenly remember how to read and write."},
	"kleptomaniac": {"group": "severe", "name": "Kleptomania", "scan": "kleptomania",
		"gain": "You feel a sudden urge to take that. Surely no one will notice.", "lose": "You no longer feel the urge to take things."},
	# --- special (TRAUMA_RESILIENCE_BASIC)
	"psychotic_brawling": {"group": "special", "name": "Violent Psychosis", "scan": "violent psychosis",
		"gain": "You feel unhinged...", "lose": "You feel more balanced."},
	"tenacity": {"group": "special", "name": "Tenacity", "scan": "traumatic neuropathy",
		"gain": "You suddenly stop feeling pain.", "lose": "You realize you can feel pain again."},
	"death_whispers": {"group": "special", "name": "Functional Cerebral Necrosis", "scan": "chronic functional necrosis",
		"gain": "You feel dead inside.", "lose": "You feel alive again."},
	"existential_crisis": {"group": "special", "name": "Existential Crisis", "scan": "existential crisis",
		"gain": "You feel less real.", "lose": "You feel more substantial again."},
}

const GROUP_RES := {"mild": RES_BASIC, "severe": RES_SURGERY, "special": RES_BASIC}

## tg paralysis types -> the limbs they take and how the text names them
const PARALYSIS := {
	"full": [["l_arm", "r_arm", "l_leg", "r_leg"], "your body"],
	"left": [["l_arm", "l_leg"], "the left side of your body"],
	"right": [["r_arm", "r_leg"], "the right side of your body"],
	"arms": [["l_arm", "r_arm"], "your arms"],
	"legs": [["l_leg", "r_leg"], "your legs"],
	"r_arm": [["r_arm"], "your right arm"], "l_arm": [["l_arm"], "your left arm"],
	"r_leg": [["r_leg"], "your right leg"], "l_leg": [["l_leg"], "your left leg"],
}

static var _strings := {}
static var _common := {}
static var _phobias := {}
static var _hooked := false

static func _data() -> void:
	if not _strings.is_empty():
		return
	for pair in [["traumas", "res://assets/data/tg/traumas.json"], ["phobia", "res://assets/data/tg/phobia.json"]]:
		var f := FileAccess.open(pair[1], FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else {}
		if pair[0] == "traumas":
			_strings = d if d is Dictionary else {}
		else:
			_phobias = d if d is Dictionary else {}
	var w := FileAccess.open("res://assets/data/tg/common_words.txt", FileAccess.READ)
	if w:
		for line in w.get_as_text().split("\n"):
			if line.strip_edges() != "":
				_common[line.strip_edges().to_lower()] = true
	if _strings.is_empty():
		_strings = {"brain_damage": ["..."]}

## tg pick_list_replacements: @pick(key) expands to a random line of that list.
static func pick_line(key: String) -> String:
	_data()
	var list: Array = _strings.get(key, [])
	if list.is_empty():
		return ""
	var s: String = list[Game.rng.randi() % list.size()]
	var re := RegEx.create_from_string("@pick\\(([a-z_]+)\\)")
	var guard := 0
	var m := re.search(s)
	while m and guard < 8:
		s = s.substr(0, m.get_start()) + pick_line(m.get_string(1)) + s.substr(m.get_end())
		m = re.search(s)
		guard += 1
	return s

# ------------------------------------------------------------------ gaining and losing
## tg brain/can_gain_trauma
static func can_gain(h: CHealth, id: String, res := -1) -> bool:
	if not h.organs.has("brain"):
		return false
	if res < 0:
		res = GROUP_RES[DEFS[id]["group"]]
	var tier := 0
	for t in h.traumas:
		if t["id"] == id:
			return false
		if t["res"] == res:
			tier += 1
	return tier < LIMITS.get(res, 3)

## tg brain/gain_trauma_type: a random trauma from the group (mild, severe, special).
static func gain_type(h: CHealth, group: String, res := -1, _natural := false) -> Dictionary:
	var pool := []
	for id in DEFS:
		if DEFS[id]["group"] == group and can_gain(h, id, res):
			pool.append(id)
	if pool.is_empty():
		return {}
	return gain(h, pool[Game.rng.randi() % pool.size()], res)

## tg brain/gain_trauma
static func gain(h: CHealth, id: String, res := -1, arg = null) -> Dictionary:
	if not DEFS.has(id) or not can_gain(h, id, res):
		return {}
	var d: Dictionary = DEFS[id]
	var t := {"id": id, "group": d["group"], "res": res if res > 0 else GROUP_RES[d["group"]], "uid": Game.rng.randi()}
	var gain_text: String = d["gain"]
	match id:
		"phobia":
			_data()
			var types := _phobias.keys()
			t["what"] = arg if arg != null else (types[Game.rng.randi() % types.size()] if not types.is_empty() else "blood")
			gain_text = gain_text % t["what"]
		"paralysis":
			t["what"] = arg if arg != null else PARALYSIS.keys()[Game.rng.randi() % PARALYSIS.size()]
			gain_text = gain_text % PARALYSIS[t["what"]][1]
		"mind_echo":
			t["said"] = []
		"possessive":
			t["held"] = null
		"existential_crisis":
			t["cd"] = 0.0
	h.traumas.append(t)
	if gain_text != "":
		Game.tell(h.e, gain_text, "warn")
	if id == "phobia" or id == "monophobia":
		h.terror = maxf(h.terror, 0.0)
	_hook()
	Bus.mob_state_changed.emit(h.e)
	return t

static func lose(h: CHealth, t: Dictionary, silent := false) -> void:
	if not t in h.traumas:
		return
	h.traumas.erase(t)
	var d: Dictionary = DEFS[t["id"]]
	var text: String = d["lose"]
	match t["id"]:
		"phobia":
			text = text % t["what"]
		"paralysis":
			text = text % PARALYSIS[t["what"]][1]
		"hallucinations":
			h.remove_status("hallucination")
		"stuttering":
			h.remove_status("stutter")
		"dumbness":
			h.remove_status("derpspeech")
		"hypnotic_stupor":
			h.remove_status("trance")
		"existential_crisis":
			if t.get("faded", false):
				_fade_in(h, t)
	if not silent and text != "":
		Game.tell(h.e, text, "info")
	Bus.mob_state_changed.emit(h.e)

## tg cure_trauma_type: one random trauma of the group at or under the resilience.
static func cure_type(h: CHealth, group := "", res := RES_BASIC) -> bool:
	var pool := h.traumas.filter(func(t): return (group == "" or t["group"] == group) and t["res"] <= res)
	if pool.is_empty():
		return false
	lose(h, pool[Game.rng.randi() % pool.size()])
	return true

## tg cure_all_traumas(resilience)
static func cure_all(h: CHealth, res := RES_BASIC) -> int:
	var n := 0
	for t in h.traumas.duplicate():
		if t["res"] <= res:
			lose(h, t)
			n += 1
	return n

static func has(h: CHealth, id: String) -> bool:
	for t in h.traumas:
		if t["id"] == id:
			return true
	return false

static func find(h: CHealth, uid: int) -> Dictionary:
	for t in h.traumas:
		if t["uid"] == uid:
			return t
	return {}

# ------------------------------------------------------------------ what they do to you
## TRAIT_PARALYSIS_<limb>
static func paralyzed(h: CHealth, part: String) -> bool:
	for t in h.traumas:
		if t["id"] == "paralysis" and part in PARALYSIS[t["what"]][0]:
			return true
	return false

static func blind(h: CHealth) -> bool:
	return has(h, "blindness")

static func mute(h: CHealth) -> bool:
	return has(h, "mute") or h.has_status("trance") or h.has_status("fake_death_mute")

static func pacifist(h: CHealth) -> bool:
	return has(h, "pacifism")

static func discoordinated(h: CHealth) -> bool:
	return has(h, "discoordination")

static func illiterate(h: CHealth) -> bool:
	return has(h, "dyslexia") or h.traits.has("illiterate")

## TRAIT_NOSOFTCRIT + TRAIT_NOHARDCRIT (tenacity)
static func no_crit(h: CHealth) -> bool:
	return has(h, "tenacity")

static func colorblind(h: CHealth) -> bool:
	return has(h, "color_blindness") or h.has_status("trance")

## tg handle_speech of every trauma, then the speech traits. "" means nothing comes out.
static func treat_speech(h: CHealth, text: String) -> String:
	if h.traumas.is_empty() and not h.has_status("trance") and not h.has_status("fake_death_mute"):
		return text
	if mute(h):
		Game.tell(h.e, "You find yourself unable to speak!", "warn")
		return ""
	for t in h.traumas:
		match t["id"]:
			"expressive_aphasia":
				text = _expressive_aphasia(text)
			"mind_echo":
				var said: Array = t["said"]
				if said.size() >= 5 and Body.prob(25):
					var i := Game.rng.randi() % said.size()
					var old: String = said[i]
					said.remove_at(i)
					text = old
				elif said.size() >= 15:
					if Body.prob(50):
						said.pop_front()
						said.append(text)
				else:
					said.append(text)
			"phobia":
				var word := _phobia_word(t["what"], text)
				if word != "" and not h.knocked_out():
					if Body.prob(50):
						h.set_status_if_lower("stutter", 4.0)
						Game.tell(h.e, "You struggle to say the word \"%s\"!" % word, "warn")
	if has(h, "aphasia"):
		text = _gibber(text)
	elif has(h, "speech_impediment"):
		text = _unintelligize(text)
	if h.has_status("derpspeech"):
		text = _derpspeech(h, text)
	return text

## tg /datum/brain_trauma/mild/expressive_aphasia/handle_speech
static func _expressive_aphasia(text: String) -> String:
	_data()
	var words := text.split(" ", false)
	var out := []
	for w in words:
		var suffix := ""
		for s in [".", ",", ";", "!", ":", "?"]:
			if w.ends_with(s):
				suffix = s
				w = w.substr(0, w.length() - 1)
				break
		if _common.has(w.to_lower()):
			out.append(w + suffix)
		elif Body.prob(30) and words.size() > 2:
			out.append(["uh", "erm"][Game.rng.randi() % 2])
			break
		else:
			var chars := []
			for c in w:
				chars.append(c)
			chars.resize(roundi(chars.size() * 0.5))
			chars.shuffle()
			out.append("".join(chars) + suffix)
	return " ".join(out).strip_edges()

## tg unintelligize: the words, shuffled.
static func _unintelligize(text: String) -> String:
	var re := RegEx.create_from_string("\\b\\S+\\b")
	var words := []
	for m in re.search_all(text):
		words.append(m.get_string())
	words.shuffle()
	return " ".join(words)

## tg /datum/language/aphasia ("Gibbering"): syllables, nothing else.
static func _gibber(text: String) -> String:
	var syl := ["m", "n", "gh", "h", "l", "s", "r", "a", "e", "i", "o", "u"]
	var out := ""
	var n := maxi(1, text.length() / 2)
	for i in n:
		out += syl[Game.rng.randi() % syl.size()]
		if Body.prob(75) and i < n - 1:
			out += " "
	return out.capitalize() if out.length() > 0 else "..."

## tg /datum/status_effect/speech/stutter/derpspeech
static func _derpspeech(h: CHealth, text: String) -> String:
	for pair in [[" am ", " "], [" is ", " "], [" are ", " "], ["you", "u"], ["help", "halp"], ["grief", "grife"], ["space", "spess"], ["carp", "crap"], ["reason", "raisin"]]:
		text = text.replace(pair[0], pair[1])
	if Body.prob(50):
		text = text.to_upper() + ["!", "!!", "!!!"][Game.rng.randi() % 3]
	if not h.has_status("stutter") and Body.prob(15):
		text = StatusFx._each_word(text, StatusFx._stutter_word)
	return text

# ------------------------------------------------------------------ life
## tg carbon/handle_brain_damage: each trauma's on_life, then the fear they cause.
static func tick(h: CHealth, dt: float) -> void:
	if h.dead:
		return
	for t in h.traumas.duplicate():
		if t in h.traumas:
			_on_life(h, t, dt)
	_fear(h, dt)

static func _on_life(h: CHealth, t: Dictionary, dt: float) -> void:
	var e := h.e
	var m: CMob = e.c(&"mob")
	var inv: CInventory = e.c(&"inv")
	var out := h.knocked_out()
	match t["id"]:
		"hallucinations":
			if out:
				return
			h.adjust_status("hallucination", 5.0 * dt, 60.0)
		"stuttering":
			h.adjust_status("stutter", 5.0 * dt, 50.0)
		"dumbness":
			h.adjust_status("derpspeech", 5.0 * dt, 50.0)
			if Body.spt_prob(1.5, dt):
				_emote(h, "drool", true)
			elif not (out or h.in_crit()) and Body.spt_prob(1.5, dt) and m:
				m.say(pick_line("brain_damage"))
		"concussion":
			if Body.spt_prob(2.5, dt):
				match Game.rng.randi_range(1, 11):
					1: Organs.vomit(h)
					2, 3: h.adjust_status("dizziness", 20.0)
					4, 5:
						h.adjust_status("confusion", 10.0)
						h.set_status_if_lower("eye_blur", 20.0)
					6, 7, 8, 9: h.adjust_status("slurring", 60.0)
					10:
						Game.tell(e, "You forget for a moment what you were doing.", "info")
						h.stun(2.0)
					11:
						Game.tell(e, "You faint.", "warn")
						h.knock_out(8.0)
		"healthy":
			h.adjust("stamina", -6.0 * dt) # tg adjustStaminaLoss(-6): no pain, no fatigue
		"muscle_weakness":
			var fall := 1.0 + (2.0 if m and m.run else 0.0)
			var held: Entity = inv.active_item() if inv else null
			if Body.spt_prob(0.5 * fall, dt) and not h.lying():
				Game.tell(e, "Your leg gives out!", "warn")
				h.paralyze(3.5)
			elif held:
				var w: int = held.c(&"item").w_class if held.has_c(&"item") else 2
				if Body.spt_prob(0.5 * (1 + w), dt):
					inv.drop(held)
					Game.tell(e, "You drop %s!" % held.the(), "warn")
			elif Body.spt_prob(1.5, dt):
				Game.tell(e, "You feel a sudden weakness in your muscles!", "warn")
				h.adjust("stamina", 50.0)
		"muscle_spasms":
			_spasm(h, m, inv)
		"nervous_cough":
			if Body.spt_prob(6.0, dt):
				if Body.prob(5):
					Game.tell(e, ["You have a coughing fit!", "You can't stop coughing!"][Game.rng.randi() % 2], "warn")
					h.immobilize(2.0)
					_emote(h, "cough", true)
					_emote(h, "cough", true)
				_emote(h, "cough", true)
		"possessive":
			if not Body.spt_prob(5.0, dt) or inv == null:
				return
			var mine: Entity = inv.hands[Game.rng.randi() % 2]
			if mine == null or mine.get_meta("nodrop", false):
				return
			mine.set_meta("nodrop", true)
			mine.set_meta("nodrop_until", Game.time + Game.rng.randf_range(30.0, 180.0))
			t["held"] = mine
			Game.tell(e, "You feel a need to keep %s close..." % mine.the(), "warn")
		"narcolepsy":
			_narcolepsy(h, m, dt)
		"hypnotic_stupor":
			if Body.spt_prob(0.5, dt) and not h.has_status("trance"):
				trance(h, Game.rng.randf_range(10.0, 30.0))
		"kleptomaniac":
			_kleptomania(h, t, inv, dt)
		"death_whispers":
			if not t.get("active", false) and Body.prob(2):
				t["active"] = true
				t["until"] = Game.time + Game.rng.randf_range(5.0, 30.0)
				Game.tell(e, "[i]You hear faint whispers from somewhere beyond...[/i]", "info")
			elif t.get("active", false) and Game.time > t["until"]:
				t["active"] = false
		"existential_crisis":
			if t.get("faded", false):
				if Game.time > t["until"]:
					_fade_in(h, t)
			elif Game.time > t["cd"] and Body.spt_prob(1.5, dt) and e.holder == null:
				_fade_out(h, t)
		"psychotic_brawling":
			pass # acts in Combat (brawl_roll)
	# possessive: the grip relaxes after a while
	if t["id"] == "possessive" and t.get("held") != null:
		var it: Entity = t["held"]
		if not is_instance_valid(it) or it.removed or Game.time > it.get_meta("nodrop_until", 0.0) or it.holder != e:
			if is_instance_valid(it) and not it.removed:
				if it.holder == e:
					Game.tell(e, "You feel more comfortable letting go of %s." % it.the(), "info")
				it.remove_meta("nodrop")
				it.remove_meta("nodrop_until")
			t["held"] = null

## tg /datum/status_effect/spasms (15% a second of one of five fits)
static func _spasm(h: CHealth, m: CMob, inv: CInventory) -> void:
	if h.incapacitated() or h.hands_blocked() or h.immobilized() or not Body.prob(15):
		return
	var e := h.e
	match Game.rng.randi_range(1, 5):
		1:
			if m and e.holder == null:
				Game.tell(e, "Your leg spasms!", "warn")
				m.try_step(Defs.DIRS4[Game.rng.randi() % 4])
		2:
			var held: Entity = inv.active_item() if inv else null
			if held:
				Game.tell(e, "Your fingers spasm!", "warn")
				held.attack_self(e)
		3:
			var targets := Game.in_radius(e.cell, 1, &"mob").filter(func(x): return x != e)
			if not targets.is_empty():
				Game.tell(e, "Your arm spasms!", "warn")
				var held2: Entity = inv.active_item() if inv else null
				Combat.melee(e, targets[Game.rng.randi() % targets.size()], held2)
		4:
			Game.tell(e, "Your arm spasms!", "warn")
			var held3: Entity = inv.active_item() if inv else null
			Combat.melee(e, e, held3)
		5:
			var held4: Entity = inv.active_item() if inv else null
			if held4:
				Game.tell(e, "Your arm spasms!", "warn")
				inv.drop(held4)

## tg /datum/brain_trauma/severe/narcolepsy
static func _narcolepsy(h: CHealth, m: CMob, dt: float) -> void:
	if h.has_status("sleeping") or h.sleeping:
		return
	for med in ["modafinil", "synaptizine"]:
		if h.chems.has(med):
			return
	var drowsy := h.has_status("drowsiness")
	var chance := 1.0
	if m and m.run:
		chance += 2.0
	if drowsy:
		chance += 3.0
	if h.chems.has("coffee") or h.chems.has("methamphetamine"):
		chance *= 0.5
	if not Body.spt_prob(chance, dt):
		return
	if not drowsy:
		Game.tell(h.e, "You feel tired...", "warn")
		h.adjust_status("drowsiness", Game.rng.randf_range(20.0, 30.0))
		if Body.prob(50):
			_emote(h, "yawn", true)
		elif Body.prob(33):
			_emote(h, "rubs their eyes.")
	else:
		Game.tell(h.e, "You fall asleep.", "warn")
		h.sleep_for(6.0)
		if Body.prob(50):
			_emote(h, "snore", true)

## tg /datum/status_effect/trance: dizzy, mute and colourless; stunned in place.
static func trance(h: CHealth, dur: float, stun := true) -> void:
	h.set_status("trance", dur)
	h.set_meta("trance_stun", stun)
	if stun:
		Game.visible_message(h.e.cell, "%s stands still as their eyes seem to focus on a distant point." % h.e.display_name, "warn")
	Game.tell(h.e, ["You feel your thoughts slow down...", "You suddenly feel extremely dizzy...", "You feel like you're in the middle of a dream...", "You feel incredibly relaxed..."][Game.rng.randi() % 4], "warn")

static func trance_tick(h: CHealth) -> void:
	if not h.has_status("trance"):
		if h.get_meta("in_trance", false):
			h.set_meta("in_trance", false)
			h.remove_status("dizziness")
			Game.tell(h.e, "You snap out of your trance!", "warn")
		return
	h.set_meta("in_trance", true)
	if h.get_meta("trance_stun", true):
		h.set_status_if_lower("stun", 6.0)
	h.set_status("dizziness", 40.0)

## tg /datum/brain_trauma/severe/kleptomaniac/on_life
static func _kleptomania(h: CHealth, t: Dictionary, inv: CInventory, dt: float) -> void:
	if inv == null or Body.usable_hands(h) <= 0 or not Body.spt_prob(5.0, dt):
		return
	if Game.time < t.get("cd", 0.0) or inv.free_hand() < 0 or h.hands_blocked():
		return
	var stealables := []
	for d in Defs.DIRS8 + [Vector2i.ZERO]:
		for x in Game.at(h.e.cell + d):
			if x.has_c(&"item") and x.holder == null and not x.get_meta("anchored", false) and x.c(&"item").w_class < 4:
				stealables.append(x)
	if stealables.is_empty():
		return
	var it: Entity = stealables[Game.rng.randi() % stealables.size()]
	inv.put_in_hands(it, inv.free_hand())
	t["cd"] = Game.time + 8.0

## TRAUMA_TRAIT damage taken stops the stealing for 12 s (kleptomaniac/damage_taken)
static func on_damage(h: CHealth, amount: float, kind: String) -> void:
	if amount < 5.0 or not kind in ["brute", "burn", "stamina"]:
		return
	for t in h.traumas:
		if t["id"] == "kleptomaniac":
			t["cd"] = maxf(t.get("cd", 0.0), Game.time + 12.0)

static func _fade_out(h: CHealth, t: Dictionary) -> void:
	t["faded"] = true
	t["until"] = Game.time + Game.rng.randf_range(5.0, 45.0)
	t["cd"] = Game.time + 60.0
	Game.tell(h.e, ["Do you even exist?", "To be or not to be...", "Why exist?", "You simply fade away.", "You stop keeping it real.", "You stop thinking for a moment. Therefore you are not."][Game.rng.randi() % 6], "warn")
	h.e.visible = false
	h.set_status("existential_veil", 999.0)

static func _fade_in(h: CHealth, t: Dictionary) -> void:
	t["faded"] = false
	t["cd"] = Game.time + 60.0
	h.e.visible = true
	h.remove_status("existential_veil")
	Game.tell(h.e, "You fade back into reality.", "info")

## tg martial art psychotic_brawling: every blow is a gamble.
## Returns "help", "grab", "shove", "punch" (normal) or "brutal".
static func brawl_roll(h: CHealth) -> String:
	if not has(h, "psychotic_brawling"):
		return "punch"
	match Game.rng.randi_range(1, 4):
		1: return "help"
		2: return "grab"
		3: return "shove"
	return "brutal"

# ------------------------------------------------------------------ fear
## tg /datum/component/fearful: sources build terror, effects scale with it.
static func _fear(h: CHealth, dt: float) -> void:
	var sources := h.traumas.filter(func(t): return t["id"] in ["phobia", "monophobia"])
	if sources.is_empty():
		h.terror = 0.0
		return
	var before := h.terror
	var adj := 0.0
	for t in sources:
		adj += _source_tick(h, t, dt)
	h.terror = clampf(h.terror + adj, 0.0, TERROR_BUILDUP_MAXIMUM)
	adj += _effects(h, sources, dt, before)
	if adj > 0.0 or h.terror > h.last_terror:
		h.last_terror = h.terror
		return
	if h.terror > 0.0:
		h.terror = maxf(h.terror - TERROR_BUILDUP_PASSIVE_DECREASE * dt, 0.0)
	h.last_terror = h.terror

static func _source_tick(h: CHealth, t: Dictionary, dt: float) -> float:
	if h.knocked_out() or StatusFx.fearless(h):
		return 0.0
	match t["id"]:
		"monophobia":
			# simple_source/monophobia: 2.5 a second while nobody is in view
			var r := 1 if StatusFx.blind(h) else 7
			for x in Game.in_radius(h.e.cell, r, &"mob"):
				if x != h.e and not x.c(&"health").dead:
					return 0.0
			if Game.time > t.get("msg_cd", 0.0) and Body.spt_prob(10.0, dt):
				Game.tell(h.e, "You feel terribly lonely...", "warn")
				t["msg_cd"] = Game.time + TERROR_MESSAGE_CD
			if h.terror >= TERROR_BUILDUP_PASSIVE_MAXIMUM:
				return 0.0
			return minf(2.5 * dt, TERROR_BUILDUP_PASSIVE_MAXIMUM - h.terror)
		"phobia":
			if Game.time < t.get("scare_cd", 0.0):
				return 0.01
			if Game.time < t.get("check_cd", 0.0) or StatusFx.blind(h):
				return 0.0
			t["check_cd"] = Game.time + PHOBIA_CHECK_DELAY
			var seen := _phobia_sight(h, t["what"])
			if seen != "":
				return _freak_out(h, t, seen, false)
	return 0.0

## What of the phobia's things is in view (tg trigger_mobs / trigger_objs / trigger_turfs,
## mapped onto what this station has).
static func _phobia_sight(h: CHealth, what: String) -> String:
	var c := h.e.cell
	match what:
		"blood":
			for x in Game.in_radius(c, 5, &"decal"):
				if x.c(&"decal").blood and not x.c(&"decal").dried:
					return x.display_name
			for x in Game.in_radius(c, 7, &"mob"):
				if x != h.e and x.has_c(&"health") and not x.c(&"health").wounds.is_empty():
					return x.display_name
		"doctors", "security", "authority":
			var depts: Array = {"doctors": ["medical"], "security": ["security"], "authority": ["command", "security"]}[what]
			for x in Game.in_radius(c, 7, &"mob"):
				var xm: CMob = x.c(&"mob")
				if x != h.e and xm and Jobs.dept(xm.job) in depts:
					return x.display_name
		"guns":
			for x in Game.in_radius(c, 7, &"mob"):
				var xi: CInventory = x.c(&"inv")
				if x != h.e and xi:
					for it in xi.hands:
						if it and it.has_c(&"gun"):
							return it.display_name
		"strangers":
			for x in Game.in_radius(c, 7, &"mob"):
				if x != h.e:
					return x.display_name
		"space":
			if Game.map.is_outdoor(c):
				return "the open sky"
		"robots":
			for x in Game.in_radius(c, 7, &"mob"):
				if x.proto.contains("bot") or x.proto.contains("borg"):
					return x.display_name
	return ""

static func _phobia_word(what: String, text: String) -> String:
	_data()
	var low := text.to_lower()
	for w in _phobias.get(what, []):
		var re := RegEx.create_from_string("(?i)(\\b|\\W)(" + _regex_escape(String(w)) + ")(\\b|\\W|$)")
		if re.search(low):
			return w
	return ""

static func _regex_escape(s: String) -> String:
	var out := ""
	for ch in s:
		out += ("\\" + ch) if ch in ".^$*+?()[]{}|\\" else ch
	return out

## tg phobia_source/freak_out
static func _freak_out(h: CHealth, t: Dictionary, reason: String, heard: bool) -> float:
	t["scare_cd"] = Game.time + PHOBIA_FREAKOUT_DELAY
	var msg: String = ["spooks you to the bone", "shakes you up", "terrifies you", "sends you into a panic", "sends chills down your spine"][Game.rng.randi() % 5]
	var n: CNeeds = h.e.c(&"needs")
	if heard:
		Game.tell(h.e, "[b]Hearing %s %s![/b]" % [reason, msg], "bad")
		if n:
			n.add_stress(3.0)
		if h.terror < TERROR_BUILDUP_PASSIVE_MAXIMUM:
			h.terror = minf(h.terror + PHOBIA_WORD_TERROR_BUILDUP, TERROR_BUILDUP_PASSIVE_MAXIMUM)
		return 0.0
	if n:
		n.add_stress(8.0)
	Game.tell(h.e, "[b]Seeing %s %s![/b]" % [reason, msg], "bad")
	return PHOBIA_FREAKOUT_TERROR_BUILDUP

## Somebody near said something: phobias of it (tg phobia_source/handle_hearing).
static func _on_speech(speaker: Entity, text: String, cell: Vector2i, radius: float) -> void:
	for e in Game.in_radius(cell, int(ceil(radius)), &"health"):
		if e == speaker:
			continue
		var h: CHealth = e.c(&"health")
		if h.traumas.is_empty() or h.dead or h.knocked_out() or StatusFx.deaf(h) or StatusFx.fearless(h):
			continue
		for t in h.traumas:
			if t["id"] == "phobia" and Game.time >= t.get("scare_cd", 0.0):
				var w := _phobia_word(t["what"], text)
				if w != "":
					_freak_out(h, t, w, true)

static func _hook() -> void:
	if _hooked:
		return
	_hooked = true
	Bus.speech.connect(_on_speech)

## FEAR_SCALING(base, min, max)
static func _scale(h: CHealth, base: float, lo: float, hi: float) -> float:
	return clampf(base * (h.terror - lo) / (hi - lo), 0.0, base)

## tg terror handler effects: jittering, stuttering, heart problems, panic (the defaults),
## startle (phobias) and vomiting (monophobia).
static func _effects(h: CHealth, sources: Array, dt: float, before: float) -> float:
	if h.knocked_out():
		h.set_meta("panic_active", false)
		return 0.0
	var e := h.e
	var extra := 0.0
	var tr := h.terror
	if tr >= TERROR_BUILDUP_FEAR:
		# jittering
		if tr > TERROR_BUILDUP_TERROR:
			h.adjust_status("dizziness", 10.0 * dt, 10.0)
			h.adjust_status("jitter", 10.0 * dt, 10.0)
		elif Body.spt_prob(1.0 + _scale(h, 4.0, TERROR_BUILDUP_FEAR, TERROR_BUILDUP_TERROR), dt):
			if Game.time > h.get_meta("jitter_msg", 0.0) and not h.has_status("jitter"):
				Game.tell(e, "You can't stop shaking...", "warn")
				h.set_meta("jitter_msg", Game.time + TERROR_MESSAGE_CD)
			h.set_status_if_lower("jitter", 20.0)
			h.set_status_if_lower("dizziness", 20.0)
		# stuttering
		if tr > TERROR_BUILDUP_TERROR or Body.spt_prob(1.0 + _scale(h, 4.0, TERROR_BUILDUP_FEAR, TERROR_BUILDUP_TERROR), dt):
			h.set_status_if_lower("stutter", 10.0)
		# heart problems
		if Body.spt_prob(1.0 + _scale(h, 4.0, TERROR_BUILDUP_FEAR, TERROR_BUILDUP_PANIC), dt):
			if tr < TERROR_BUILDUP_HEART_ATTACK or not Body.prob(15):
				h.adjust("oxy", 8.0)
				if Game.time > h.get_meta("heart_msg", 0.0):
					h.set_meta("heart_msg", Game.time + TERROR_MESSAGE_CD)
					Game.tell(e, "[b]You feel your heart lurching in your chest...[/b]", "bad")
			else:
				Game.visible_message(e.cell, "%s clutches their chest for a moment, then collapses to the floor." % e.display_name, "bad")
				Game.tell(e, "The shadows begin to creep up from the corners of your vision, and then there is nothing...", "bad")
				Organs.set_heartattack(h, true)
				h.knock_out(20.0)
	# panic
	if tr < TERROR_BUILDUP_PANIC:
		if h.get_meta("panic_attack_until", 0.0) > Game.time:
			extra += TERROR_BUILDUP_PANIC - tr
		h.set_meta("panic_active", false)
	else:
		if not h.get_meta("panic_active", false):
			h.set_meta("panic_active", true)
			Game.tell(e, "[b]You feel your heart racing![/b]", "bad")
		if Body.spt_prob(5.0, dt):
			h.set_status_if_lower("eye_blur", 10.0)
		if h.get_meta("panic_attack_until", 0.0) > Game.time:
			h.losebreath += 0.25
		elif Body.spt_prob(2.0 + _scale(h, 3.0, TERROR_BUILDUP_PANIC, TERROR_BUILDUP_MAXIMUM), dt):
			h.set_meta("panic_attack_until", Game.time + Game.rng.randf_range(3.0, 5.0))
			_emote(h, "gasp", true)
			h.knockdown(0.5)
			Game.visible_message(e.cell, "%s drops to the floor for a moment, clutching their chest." % e.display_name, "warn")
			Game.tell(e, "Your heart lurches in your chest. You can't take much more of this!", "bad")
			extra += PANIC_ATTACK_TERROR_AMOUNT
	# startle (phobias)
	if sources.any(func(t): return t["id"] == "phobia") and Game.time > h.get_meta("startle_cd", 0.0):
		var jump := tr - before
		if tr >= TERROR_BUILDUP_FEAR and jump >= TERROR_STARTLE_MINIMUM_DIFFERENCE and Body.prob(15.0 * jump / TERROR_STARTLE_MINIMUM_DIFFERENCE * tr / TERROR_BUILDUP_FEAR):
			h.set_meta("startle_cd", Game.time + TERROR_STARTLE_COOLDOWN)
			match Game.rng.randi_range(1, 3):
				1:
					Game.tell(e, "You are startled!", "warn")
					_emote(h, "jump", true)
					h.immobilize(0.1 * tr / TERROR_BUILDUP_FEAR)
				2:
					_emote(h, "scream", true)
					var m: CMob = e.c(&"mob")
					if m:
						m.say("AAAAH!!")
					var inv: CInventory = e.c(&"inv")
					if inv and Body.prob(15.0 * tr / TERROR_BUILDUP_FEAR) and inv.active_item():
						var it := inv.active_item()
						inv.drop(it)
						Game.visible_message(e.cell, "%s drops %s!" % [e.display_name, it.the()], "warn")
				3:
					Game.tell(e, "You lose your balance!", "warn")
					h.adjust_status("staggered", 2.0 * tr / TERROR_BUILDUP_FEAR, 20.0)
	# vomiting (monophobia)
	if sources.any(func(t): return t["id"] == "monophobia") and tr >= TERROR_BUILDUP_TERROR:
		if Body.spt_prob(3.0 if tr >= TERROR_BUILDUP_PANIC else 1.0, dt):
			Game.tell(e, "You feel sick...", "warn")
			Organs.vomit(h, tr >= TERROR_BUILDUP_PASSIVE_MAXIMUM)
	h.terror = clampf(h.terror + extra, 0.0, TERROR_BUILDUP_MAXIMUM)
	return extra

## tg fearful/on_examine
static func examine(h: CHealth) -> String:
	if h.terror <= 0.0 or h.knocked_out():
		return ""
	var who := h.e.display_name
	if h.terror >= TERROR_BUILDUP_HEART_ATTACK:
		return "[color=#ff5a4a]%s is seizing up, about to collapse in fear![/color]" % who
	if h.terror > TERROR_BUILDUP_PANIC:
		return "[b]%s is trembling and shaking, barely standing upright![/b]" % who
	if h.terror >= TERROR_BUILDUP_TERROR:
		return "[b]%s is visibly trembling and twitching. They are clearly in distress![/b]" % who
	if h.terror >= TERROR_BUILDUP_FEAR:
		return "%s looks very worried about something. Are they alright?" % who
	return ""

## tg brain get_status_appendix: "Mental trauma: ..." for the analyzer.
static func analyzer_line(h: CHealth) -> String:
	if h.traumas.is_empty():
		return ""
	var parts := []
	for t in h.traumas:
		var pre: String = {RES_BASIC: "Mild ", RES_SURGERY: "Severe ", RES_LOBOTOMY: "Deep-rooted ", RES_WOUND: "Fracture-derived ", RES_MAGIC: "Persistent ", RES_ABSOLUTE: "Permanent "}.get(t["res"], "")
		var scan: String = DEFS[t["id"]]["scan"]
		if t["id"] == "phobia":
			scan += " of " + t["what"]
		parts.append(pre + scan)
	return "Mental trauma: %s." % ", and ".join(parts)

## A tg emote by key (`is_key`), else a free-text one.
static func _emote(h: CHealth, text: String, is_key := false) -> void:
	var m: CMob = h.e.c(&"mob")
	if m and is_key:
		m.do_emote(text) # Emotes checks what state you can do it in (snoring asleep...)
	elif m and not h.knocked_out():
		m.emote(text)
