class_name Emotes extends RefCounted
## tg emotes (code/datums/emotes.dm, mob/emote.dm, mob/living/emote.dm,
## living/carbon/emote.dm, living/carbon/human/emote.dm): "*key" or "*key param" in chat,
## and the involuntary ones the body makes (screams from wounds and burns, gasps when
## suffocating, coughs, the deathgasp...). Messages, who can use them in what state,
## cooldowns and the audio cooldowns are tg's; sounds are synthesised (SfxVoice).
## Species, alien and item-handoff emotes (wag, hiss, kiss, slap, noogie...) are left out.

## Emote types (tg EMOTE_VISIBLE / EMOTE_AUDIBLE / EMOTE_IMPORTANT)
const V := 1
const A := 2
const IMPORTANT := 4
## can_use_flags (tg EMOTE_CANUSE_*)
const HANDS := 1
const UNCON := 2
const SOFT := 4
const HARD := 8

const DEFAULT_CD := 0.8 # tg /datum/emote cooldown
## tg audio cooldowns: manual general / specific, forced general / specific
const MANUAL_GENERAL := 2.0
const MANUAL_SPECIFIC := 5.0
const FORCED_GENERAL := 2.0
const FORCED_SPECIFIC := 2.0

## key: {m: message, p: message_param (%t), t: type, u: can_use_flags, cd: cooldown,
##       snd: sound, voice: the sound has a lower and a higher voice, mcd/fcd: manual /
##       forced specific audio cooldowns, fx: an extra effect (run_emote)}
const DEFS := {
	# ---- living/emote.dm
	"taunt": {"m": "taunts!", "cd": 1.6, "fx": "spin_short"},
	"tongue": {"m": "sticks their tongue out."},
	"blush": {"m": "blushes."},
	"tunesing": {"m": "sings a tune."},
	"bow": {"m": "bows.", "p": "bows to %t.", "u": HANDS},
	"burp": {"m": "burps.", "t": 3},
	"choke": {"m": "chokes!", "t": 3},
	"cross": {"m": "crosses their arms.", "u": HANDS},
	"chuckle": {"m": "chuckles.", "t": 3},
	"collapse": {"m": "collapses!", "t": 3, "fx": "collapse"},
	"dance": {"m": "dances around happily.", "u": HANDS},
	"deathgasp": {"m": "seizes up and falls limp, their eyes dead and lifeless...", "t": 7, "cd": 15.0, "u": UNCON | HARD | SOFT},
	"drool": {"m": "drools."},
	"faint": {"m": "faints.", "fx": "faint"},
	"frown": {"m": "frowns."},
	"gag": {"m": "gags.", "t": 3},
	"gasp": {"m": "gasps!", "t": 3, "u": UNCON | HARD | SOFT, "snd": "gasp", "voice": true},
	"gaspshock": {"m": "gasps in shock!", "t": 3, "u": SOFT},
	"giggle": {"m": "giggles.", "t": 3},
	"glare": {"m": "glares.", "p": "glares at %t."},
	"grin": {"m": "grins."},
	"groan": {"m": "groans!", "t": 3},
	"grimace": {"m": "grimaces."},
	"laugh": {"m": "laughs.", "t": 3, "snd": "laugh", "voice": true, "mcd": 8.0, "speak": true},
	"look": {"m": "looks.", "p": "looks at %t."},
	"nod": {"m": "nods.", "p": "nods at %t."},
	"point": {"m": "points.", "p": "points at %t.", "cd": 1.0, "fx": "point"},
	"sneeze": {"m": "sneezes.", "t": 3, "snd": "sneeze", "voice": true},
	"cough": {"m": "coughs!", "t": 3, "snd": "cough", "voice": true},
	"wheeze": {"m": "wheezes!", "t": A},
	"pout": {"m": "pouts."},
	"scream": {"m": "screams!", "t": 3, "snd": "scream", "voice": true, "mcd": 10.0, "fcd": 4.0, "pain": true},
	"scowl": {"m": "scowls."},
	"shake": {"m": "shakes their head."},
	"shiver": {"m": "shivers.", "fx": "shiver"},
	"sigh": {"m": "sighs.", "t": 3, "snd": "sigh", "voice": true},
	"sit": {"m": "sits down."},
	"smile": {"m": "smiles."},
	"smug": {"m": "grins smugly."},
	"sniff": {"m": "sniffs.", "t": 3, "snd": "sniff"},
	"snore": {"m": "snores.", "t": 3, "u": UNCON, "snd": "snore"},
	"stare": {"m": "stares.", "p": "stares at %t."},
	"stretch": {"m": "stretches their arms."},
	"sulk": {"m": "sulks down sadly."},
	"surrender": {"m": "puts their hands on their head and falls to the ground, they surrender%s!", "t": 3, "fx": "surrender"},
	"sway": {"m": "sways around dizzily.", "fx": "sway"},
	"tilt": {"m": "tilts their head to the side."},
	"tremble": {"m": "trembles!", "fx": "tremble"},
	"twitch": {"m": "twitches violently.", "fx": "twitch"},
	"twitch_s": {"m": "twitches.", "fx": "twitch_s"},
	"wave": {"m": "waves."},
	"whimper": {"m": "whimpers.", "t": 3},
	"wsmile": {"m": "smiles weakly."},
	"yawn": {"m": "yawns.", "t": 3, "cd": 5.0, "snd": "yawn", "voice": true, "fx": "yawn"},
	"gurgle": {"m": "makes an uncomfortable gurgle.", "t": 3},
	"me": {"m": "", "t": 3, "custom": true},
	"inhale": {"m": "breathes in.", "t": 3},
	"exhale": {"m": "breathes out.", "t": 3},
	"swear": {"m": "says a swear word!", "t": A},
	# ---- living/carbon/emote.dm
	"airguitar": {"m": "is strumming the air and headbanging like a safari chimp.", "u": HANDS},
	"clap": {"m": "claps.", "t": 3, "u": HANDS, "snd": "clap", "two_arms_sound": true},
	"crack": {"m": "cracks their knuckles.", "u": HANDS, "cd": 6.0, "snd": "crack", "two_hands": true},
	"cry": {"m": "cries.", "t": 3, "u": SOFT, "snd": "cry", "voice": true},
	"whistle": {"m": "whistles.", "t": 3, "snd": "whistle"},
	"moan": {"m": "moans!", "t": 3},
	"signal": {"m": "", "p": "raises %t fingers.", "u": HANDS},
	"snap": {"m": "snaps their fingers.", "p": "snaps their fingers at %t.", "t": 3, "u": HANDS, "snd": "snap"},
	"wink": {"m": "winks."},
	# ---- living/carbon/human/emote.dm
	"dap": {"m": "sadly can't find anybody to give daps to, and daps themself. Shameful.", "p": "gives daps to %t.", "u": HANDS},
	"eyebrow": {"m": "raises an eyebrow."},
	"glasses": {"m": "pushes up their glasses.", "glasses": true},
	"grumble": {"m": "grumbles!", "t": 3},
	"handshake": {"m": "shakes their own hands.", "p": "shakes hands with %t.", "t": 3, "u": HANDS},
	"hug": {"m": "hugs themself.", "p": "hugs %t.", "u": HANDS},
	"mumble": {"m": "mumbles!", "t": 3},
	"pale": {"m": "goes pale for a second."},
	"raise": {"m": "raises a hand.", "u": HANDS},
	"salute": {"m": "salutes.", "p": "salutes to %t.", "u": HANDS, "snd": "salute"},
	"slit": {"m": "drags a finger across their neck.", "u": HANDS},
	"scratchhead": {"m": "scratches their head.", "u": HANDS},
	"thumbsup": {"m": "gives a thumbs up.", "u": HANDS},
	"thumbsdown": {"m": "gives a thumbs down.", "u": HANDS},
	"time": {"m": "checks the time.", "u": HANDS},
	"tap": {"m": "taps their foot impatiently."},
	"halt": {"m": "holds up their palm, signaling to stop.", "u": HANDS},
	"shush": {"m": "holds a finger to their lips.", "u": HANDS},
	"listen": {"m": "cups a hand to their ear.", "u": HANDS},
	"think": {"m": "taps their head, thinking.", "u": HANDS},
	"beckon": {"m": "waves a hand for someone to come closer.", "u": HANDS},
	"airquote": {"m": "makes air quotes.", "u": HANDS},
	"crazy": {"m": "twirls a finger next to their head.", "u": HANDS},
	"squint": {"m": "squints."},
	"rub": {"m": "rubs their chin.", "u": HANDS},
	"shrug": {"m": "shrugs."},
	"clear": {"m": "clears their throat."},
	"blink": {"m": "blinks.", "eyes": true},
	"blink_r": {"m": "blinks rapidly.", "eyes": true},
	# ---- mob/emote.dm
	"flip": {"m": "flips.", "u": HANDS, "fx": "flip", "fall": 60.0},
	"backflip": {"m": "backflips.", "u": HANDS, "fx": "flip", "fall": 20.0},
	"spin": {"m": "spins.", "u": HANDS, "fx": "spin"},
	"jump": {"m": "jumps!", "snd": "jump", "fx": "jump"},
}

## tg key_third_person: "*screams" works as well as "*scream"
static var _third := {}

static func _key_for(word: String) -> String:
	if DEFS.has(word):
		return word
	if _third.is_empty():
		for k in DEFS:
			var m: String = DEFS[k]["m"]
			if m != "":
				_third[m.split(" ")[0].rstrip(".!,")] = k
	return _third.get(word, "")

## tg mob/emote: "*scream", "*nod Bob", "*me waves hello". Returns true if it ran.
static func emote(user: Entity, act: String, intentional := false, forced := false) -> bool:
	var param := ""
	var sp := act.find(" ")
	if sp >= 0:
		param = act.substr(sp + 1).strip_edges()
		act = act.substr(0, sp)
	act = act.to_lower()
	if act == "help":
		_help(user)
		return true
	var key := _key_for(act)
	if key == "":
		if intentional:
			Game.tell(user, "'%s' emote does not exist. Say *help for a list." % act)
		return false
	var d: Dictionary = DEFS[key]
	if not _check_cooldown(user, key, d, intentional):
		return false
	if not forced and not can_run(user, key, intentional):
		return false
	if key == "taunt" and not SkillChips.taunt(user, intentional):
		return false
	run(user, key, param, intentional)
	return true

## Every mob's emote cooldowns and audio cooldowns: id -> time it ends.
static func _cds(user: Entity) -> Dictionary:
	if not user.has_meta("emote_cds"):
		user.set_meta("emote_cds", {})
	return user.get_meta("emote_cds")

static func _check_cooldown(user: Entity, key: String, d: Dictionary, intentional: bool) -> bool:
	if not intentional:
		return true
	var cds := _cds(user)
	var cd: float = d.get("cd", DEFAULT_CD)
	if Game.time < cds.get(key, -INF):
		if cd > DEFAULT_CD:
			Game.tell(user, "You must wait another %d seconds before using that emote." % ceili(cds[key] - Game.time), "warn")
		return false
	cds[key] = Game.time + cd
	return true

## tg can_run_emote
static func can_run(user: Entity, key: String, intentional := false) -> bool:
	var d: Dictionary = DEFS[key]
	var h: CHealth = user.c(&"health")
	if h == null:
		return false
	var flags: int = d.get("u", 0)
	# tg IS_UNCONSCIOUS is TRAIT_KNOCKEDOUT (asleep, out cold, hard crit)
	if h.knocked_out() and not h.dead and not (flags & UNCON):
		if intentional:
			Game.tell(user, "You cannot %s while unconscious!" % key, "warn")
		return false
	if h.hands_blocked() and (flags & HANDS):
		if intentional:
			Game.tell(user, "You cannot use your hands to %s right now!" % key, "warn")
		return false
	if h.dead:
		if intentional:
			Game.tell(user, "You cannot %s while dead!" % key, "warn")
		return false
	if h.in_crit():
		var hard := h.health() <= CHealth.HARD_CRIT
		if not (flags & (HARD if hard else SOFT)):
			if intentional:
				Game.tell(user, "You cannot %s while in a critical condition!" % key, "warn")
			return false
	# per-emote checks
	if d.get("speak", false) and not _can_speak(h):
		return false
	if d.get("two_hands", false) and Body.usable_hands(h) < 2:
		return false
	if d.get("eyes", false) and h.eyes_removed:
		return false
	if d.get("glasses", false):
		var g: Entity = user.c(&"inv").worn("eyes") if user.c(&"inv") else null
		if g == null or not (g.proto in ["glasses", "sunglasses", "prescription_glasses"]):
			return false
	if key == "cough" and h.has_status("soothed_throat"):
		return false
	if key == "me" and not intentional:
		return false
	return true

static func _can_speak(h: CHealth) -> bool:
	return not Traumas.mute(h) and not h.missing.has("head")

## tg run_emote: the message, its sound, and what it does.
static func run(user: Entity, key: String, param := "", intentional := false) -> void:
	var d: Dictionary = DEFS[key]
	var m: CMob = user.c(&"mob")
	var h: CHealth = user.c(&"health")
	var type: int = d.get("t", V)
	# tg scream: painkillers (TRAIT_ANALGESIA) stop the involuntary ones
	if key == "scream" and not intentional and _analgesic(h):
		return
	var msg: String = d["m"]
	var fx: String = d.get("fx", "")
	if key == "deathgasp" and not h.dead and Quirks.has(user, "death_mimicry"):
		h.knock_out(30.0) # tg death_mimicry: Unconscious(30 SECONDS) and TRAIT_FAKEDEATH
		h.set_status("fakedeath", 30.0)
	if key == "point" and param != "":
		msg = _point_message(user, h)
	if param != "":
		if d.has("p"):
			msg = (msg if key == "point" and msg.contains("%t") else d["p"]).replace("%t", param)
		else:
			msg = param
	if not d.get("custom", false):
		msg = _pronouns(m, msg)
	if msg == "":
		return
	# the sound, within the audio cooldowns
	var snd: String = d.get("snd", "")
	if snd != "" and _should_play_sound(user, h, d, key, intentional) and _audio_ok(user, key, d, intentional):
		if d.get("voice", false):
			snd += "_f" if m and m.pronoun == "she" else ("_m" if m and m.pronoun == "he" else ("_f" if user.id % 2 == 0 else "_m"))
		Sfx.play(snd, user.cell, 1.2 if key == "scream" else 0.8, _voice_pitch(user))
	_show(user, msg, type)
	_effect(user, h, m, key, fx, d, intentional)
	Bus.stimulus.emit({"type": "emote", "key": key, "actor": user, "target": null, "cell": user.cell, "loud": 6.0 if key == "scream" else 2.0})

## tg /mob/living/proc/painful_scream: a scream unless something numbs the pain.
static func pain(user: Entity) -> void:
	emote(user, "scream")

static func _analgesic(h: CHealth) -> bool:
	return h != null and (h.chems.has("morphine") or h.chems.has("mine_salve") or h.chems.has("miners_salve") or Quirks.has(h.e, "numb"))

## Each person's voice sits a little higher or lower than the next person's.
static func _voice_pitch(user: Entity) -> float:
	var h: CHealth = user.c(&"health")
	var pitch := 0.94 + float(hash(user.id) % 13) / 100.0
	if h and h.helium_voice:
		pitch *= 1.6
	return pitch

static func _should_play_sound(user: Entity, h: CHealth, d: Dictionary, key: String, intentional: bool) -> bool:
	var type: int = d.get("t", V)
	if type & A:
		if _analgesic(h) and key == "scream" and not intentional:
			return false
		if not _can_speak(h) and not d.get("u", 0) & HANDS:
			return false
	if d.get("two_arms_sound", false) and (h.missing.has("l_arm") or h.missing.has("r_arm")):
		return false
	if key == "deathgasp" and (not _can_speak(h) or h.oxy >= 50.0):
		return false
	return true

## tg's four audio cooldowns: a manual emote waits on all four, a forced one on the forced two.
static func _audio_ok(user: Entity, key: String, d: Dictionary, intentional: bool) -> bool:
	var cds := _cds(user)
	var now := Game.time
	if intentional:
		for id in ["a_mg", "a_ms_" + key, "a_fg", "a_fs_" + key]:
			if now < cds.get(id, -INF):
				return false
	else:
		for id in ["a_fg", "a_fs_" + key]:
			if now < cds.get(id, -INF):
				return false
	cds["a_ms_" + key] = now + d.get("mcd", MANUAL_SPECIFIC)
	cds["a_mg"] = now + MANUAL_GENERAL
	cds["a_fs_" + key] = now + d.get("fcd", FORCED_SPECIFIC)
	cds["a_fg"] = now + FORCED_GENERAL
	return true

## tg replace_pronoun
static func _pronouns(m: CMob, msg: String) -> String:
	if m == null:
		return msg
	if msg.contains("their"):
		msg = msg.replace("their", m.their())
	if msg.contains("them"):
		msg = msg.replace("them", m.them())
	if msg.contains("they"):
		msg = msg.replace("they", m.they())
	if msg.contains("%s"):
		msg = msg.replace("%s", "" if m.pronoun == "they" else "s")
	return msg

## tg run_emote's messages: the audible part if you can hear it, else the visible part
## ("You see how X coughs!"), else nothing. Important ones (the deathgasp) always show.
## You always see your own. Also a runechat bubble above them.
static func _show(user: Entity, msg: String, type: int) -> void:
	var p := Game.player
	if p == null:
		return
	var line := "[i][b]%s[/b] %s[/i]" % [user.display_name, msg]
	var shown := false
	if user == p or (type & IMPORTANT):
		shown = Game.lighting == null or Game.lighting.player_can_see(user.cell) or user == p
	else:
		var ph: CHealth = p.c(&"health")
		var can_see: bool = (Game.lighting == null or Game.lighting.player_can_see(user.cell)) and not (ph and StatusFx.blind(ph))
		var can_hear: bool = p.dist_to(user) <= 7 and not (ph and (StatusFx.deaf(ph) or ph.knocked_out()))
		if (type & A) and can_hear:
			shown = true
		elif (type & V) and can_see:
			if (type & A) and not can_hear:
				line = "[i]You see how [b]%s[/b] %s[/i]" % [user.display_name, msg]
			shown = true
	if shown:
		Bus.chat.emit(line, "emote")
		if Game.hud and Game.hud.has_method("bubble_emote"):
			Game.hud.bubble_emote(user, msg)

# ------------------------------------------------------------------ run_emote extras
static func _effect(user: Entity, h: CHealth, m: CMob, key: String, fx: String, d: Dictionary, intentional: bool) -> void:
	match fx:
		"collapse":
			h.knock_out(4.0) # tg Unconscious(4 SECONDS)
		"faint":
			h.set_status("sleeping", 20.0) # tg SetSleeping(20 SECONDS)
		"surrender":
			h.paralyze(20.0) # tg Paralyze(20 SECONDS)
		"yawn":
			_spread_yawn(user)
		"flip":
			if m:
				m.emote_anim("flip" if key == "flip" else "backflip")
			# tg flip check_cooldown: flipping again too soon, you may fall on your face
			var last: float = _cds(user).get("flip_last", -INF)
			if intentional and Game.time - last < 0.8:
				if Body.prob(d.get("fall", 60.0)):
					h.knockdown(1.0)
					Game.visible_message(user.cell, "%s attempts to do a flip and falls over, what a doofus!" % user.display_name)
					if Body.prob(d.get("fall", 60.0) / 2.0):
						h.adjust("brute", 1.0)
				else:
					Game.visible_message(user.cell, "%s stumbles a bit after their flip." % user.display_name)
			_cds(user)["flip_last"] = Game.time
		"spin":
			if m:
				m.emote_anim("spin")
			# tg beyblade: spinning while confused makes you sick; sometimes dizzy
			if h.status_left("confusion") > 30.0:
				Organs.vomit(h, false, 60.0, 0, true) # tg VOMIT_CATEGORY_KNOCKDOWN, 60 nutrition
			elif Body.prob(20):
				Game.tell(user, "You feel woozy from spinning.", "warn")
				h.set_status_if_lower("dizziness", 20.0)
				h.adjust_status("confusion", 10.0, 40.0)
		"spin_short", "shiver", "tremble", "twitch", "twitch_s", "sway", "jump":
			if m:
				m.emote_anim(fx)

## tg yawn propagation: people nearby may catch it (20% - 4% per tile), after a delay.
static func _spread_yawn(user: Entity) -> void:
	var cds := _cds(user)
	if Game.time < cds.get("yawn_prop", -INF):
		return
	cds["yawn_prop"] = Game.time + 15.0 # cooldown * 3
	var inv: CInventory = user.c(&"inv")
	if inv and inv.worn("mask") != null:
		return # tg: a covered face doesn't spread it
	var reach := 5 if user == Game.player else 2
	for o in Game.in_radius(user.cell, reach, &"mob"):
		if o == user or not o.has_c(&"health"):
			continue
		var oh: CHealth = o.c(&"health")
		if oh.dead or oh.incapacitated() or Game.time < _cds(o).get("yawn_prop", -INF):
			continue
		var dist: float = o.dist_to(user)
		if not Body.prob(20.0 - 4.0 * dist):
			continue
		var delay: float = Game.rng.randf_range(0.2, 0.7) * dist
		Game.get_tree().create_timer(maxf(delay, 0.05) / maxf(Game.time_scale, 0.01)).timeout.connect(func():
			if is_instance_valid(o) and not o.removed and Game.time >= _cds(o).get("yawn_prop", -INF):
				emote(o, "yawn"))

## tg point run_emote: no hands to point with, you point with a foot, a glance, your tongue...
static func _point_message(user: Entity, h: CHealth) -> String:
	if Body.usable_hands(h) > 0 and not h.hands_blocked():
		return "points at %t."
	var legs := Body.usable_legs(h)
	if legs > 0:
		var inv: CInventory = user.c(&"inv")
		var shoes := inv != null and inv.worn("shoes") != null
		var one := legs == 1
		var chance := 65.0 - (40.0 if one else 0.0)
		if Body.prob(chance):
			return "%spoints at %%t with their %s!" % ["jumps into the air and " if one else "", "leg" if shoes else "toes"]
		h.paralyze(2.0)
		return "%stries to point at %%t with their %s, falling down in the process!" % ["jumps into the air and " if one else "", "leg" if shoes else "toes"]
	if not h.eyes_removed:
		return "gives a meaningful glance at %t!"
	return "motions their tongue towards %t!"

## tg *help: every emote you can use (the ones with a sound in bold).
static func _help(user: Entity) -> void:
	var keys := DEFS.keys()
	keys.sort()
	var out := []
	for k in keys:
		out.append(("[b]%s[/b]" % k) if DEFS[k].has("snd") else k)
	Game.tell(user, "Available emotes, you can use them with say \"*emote\" (bold ones make a sound):\n" + ", ".join(out))
