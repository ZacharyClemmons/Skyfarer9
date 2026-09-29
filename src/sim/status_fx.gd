class_name StatusFx extends RefCounted
## tg status effects with a duration (code/datums/status_effects/debuffs/*.dm), ticking on a
## CHealth's `status` dictionary (id -> seconds left):
##   stun, knockdown, immobilized, paralyzed, incapacitated, unconscious, sleeping
##       (debuffs.dm /incapacitating; CHealth turns them into tg's traits)
##   confusion   moves go astray (confusion.dm)
##   dizziness   the view sways (dizziness.dm); resting clears it 5x faster
##   jitter      you shake (jitteriness.dm); resting clears it 4 s/s faster
##   eye_blur    blurred sight (screen_blur.dm)
##   temp_blind  can't see (vision/blindness.dm)
##   drowsiness  blurs your eyes and nods you off (drowsiness.dm)
##   druggy      you're high (drugginess.dm)
##   staggered   slower (staggered.dm)
##   dazed       (staggered.dm)
##   slurring, stutter   speech (speech_debuffs.dm)
## plus tg sleeping's healing and knocked_out's stamina recovery.

const HEALING_SLEEP_DEFAULT := 0.2
const CONFUSION_FULL_THRESHOLD := 40.0
const CONFUSION_SIDEWAYS_MOVE_PROB_PER_SECOND := 1.5
const CONFUSION_DIAGONAL_MOVE_PROB_PER_SECOND := 3.0
const BLUR_DURATION_TO_INTENSITY := 0.05

## tg strings/slurring_drunk_text.json
const SLUR_COMMON := {"o": "u", "s": "ch", "a": "ah", "u": "oo", "c": "k"}
const SLUR_UNCOMMON := {" ": "...huuuhhh...", ".": "... *BURP*.", ",": ", *hic* "}

static func tick(h: CHealth, dt: float) -> void:
	if h.has_status("irradiated") and not h.dead:
		if h.chems.has("potass_iodide"):
			h.remove_status("irradiated")
		else:
			h.adjust("tox", 0.2 * dt)
	if h.drunk > 0.0:
		var da: float = h.get_meta("drunk_acc", 0.0) + dt
		while da >= 2.0:
			da -= 2.0
			_drunk_tick(h)
		h.set_meta("drunk_acc", da)
	var st := h.status
	if st.is_empty():
		_knocked_out_tick(h, dt)
		return
	# extra decay (tg remove_duration in each effect's tick)
	if h.resting:
		if st.has("dizziness"):
			st["dizziness"] -= 4.0 * dt # dizziness_strength 5: (5 - 1) extra per second
		if st.has("jitter"):
			st["jitter"] -= 4.0 * dt
		if st.has("drowsiness"):
			st["drowsiness"] -= 2.0 * dt
	if st.has("temp_blind") and _eyes_covered(h) and not h.dead:
		st["temp_blind"] -= dt
		if st["temp_blind"] <= dt:
			Game.tell(h.e, "Your eyes start to feel better!", "good")
	var acc: float = h.get_meta("status_acc", 0.0) + dt
	var ticks := 0
	while acc >= 2.0:
		acc -= 2.0
		ticks += 1
	h.set_meta("status_acc", acc)
	for i in ticks:
		_two_second_tick(h)
	_knocked_out_tick(h, dt)
	for sid in st.keys():
		var left: float = st[sid] - dt
		if left <= 0.0:
			# end it through set_status while it still counts as active, so the change is
			# seen (standing back up, waking, messages)
			st[sid] = maxf(st[sid], 0.001)
			h.set_status(sid, 0.0)
		else:
			st[sid] = left

static func _knocked_out_tick(h: CHealth, dt: float) -> void:
	# tg knocked_out: -3 stamina loss a second while out
	if h.knocked_out() and not h.dead:
		h.stamina = minf(100.0, h.stamina + 3.0 * dt)

## Effects that tick every 2 seconds in tg (tick_interval = 2 SECONDS).
static func _two_second_tick(h: CHealth) -> void:
	# drowsiness: blur, and now and then you nod off
	if h.has_status("drowsiness") and not h.knocked_out():
		h.set_status_if_lower("eye_blur", 4.0)
		if Body.prob(5):
			h.adjust_status("sleeping", 10.0)
	# sleeping: tg sleep quality heals a little
	if h.has_status("sleeping") or h.sleeping:
		_sleep_tick(h, 2.0)

## tg /datum/status_effect/incapacitating/sleeping/tick
static func _sleep_tick(h: CHealth, dt: float) -> void:
	var quality := HEALING_SLEEP_DEFAULT
	var c := h.e.cell
	if Game.lighting and not Game.lighting.player_can_see(c) or _eyes_covered(h):
		quality += 0.1
	for x in Game.at(c):
		if x.has_c(&"furniture"):
			var k: String = x.c(&"furniture").kind
			if k == "bed":
				quality += 0.2
			elif k in ["table", "counter"]:
				quality += 0.1
		if x.proto == "bedsheet":
			quality += 0.1
	if quality > 0.0 and h.health() / CHealth.MAX_HEALTH > 0.8:
		h.adjust("brute", -0.4 * quality * dt)
		h.adjust("burn", -0.4 * quality * dt)
		h.adjust("tox", -0.2 * quality * dt)
	h.stamina = minf(100.0, h.stamina + maxf(0.4 * quality * dt, 0.4 * HEALING_SLEEP_DEFAULT * dt))
	if Body.prob(8) and h.health() > CHealth.CRIT:
		var m: CMob = h.e.c(&"mob")
		if m:
			m.do_emote("snore")

static func _eyes_covered(h: CHealth) -> bool:
	var inv: CInventory = h.e.c(&"inv")
	if inv == null:
		return false
	for s in ["eyes", "mask", "head"]:
		var it: Entity = inv.worn(s)
		if it and it.has_c(&"clothing") and it.c(&"clothing").covers_eyes:
			return true
	return false

## tg is_blind(): temporary blindness, knocked out, or no eyes.
static func blind(h: CHealth) -> bool:
	return h.has_status("temp_blind") or h.knocked_out() or h.eyes_removed or h.missing.has("head") or h.eye_damage >= EYES_MAX or (not h.traumas.is_empty() and Traumas.blind(h)) or h.traits.has("blind")

## tg screen_blur: blur strength from the time left (0.6 to 3 px of gaussian in tg).
static func blur_amount(h: CHealth) -> float:
	var t := h.status_left("eye_blur")
	if t <= 0.0:
		return 0.0
	return clampf(t * BLUR_DURATION_TO_INTENSITY, 0.6, 3.0) / 3.0

# ------------------------------------------------------------------ confusion
## tg confusion on_move: over 40 s left every step is random (unless resting); otherwise a
## chance to veer 90 degrees (1.5%/s left) or 45 degrees (3%/s left).
static func confused_step(h: CHealth, d: Vector2i) -> Vector2i:
	var t := h.status_left("confusion")
	if t <= 0.0 or d == Vector2i.ZERO:
		return d
	if t > CONFUSION_FULL_THRESHOLD and not h.resting:
		return Defs.DIRS8[Game.rng.randi() % 8]
	var i := Defs.DIRS8.find(d)
	if i < 0:
		return d
	if Body.prob(t * CONFUSION_SIDEWAYS_MOVE_PROB_PER_SECOND):
		return Defs.DIRS8[(i + (2 if Game.rng.randf() < 0.5 else 6)) % 8]
	if Body.prob(t * CONFUSION_DIAGONAL_MOVE_PROB_PER_SECOND):
		return Defs.DIRS8[(i + (1 if Game.rng.randf() < 0.5 else 7)) % 8]
	return d

# ------------------------------------------------------------------ visuals
## tg dizziness tick: the client's view swings on a sine; `time` in deciseconds.
static func dizzy_offset(h: CHealth, time_ds: float) -> Vector2:
	var amount := h.status_left("dizziness")
	if amount <= 0.0:
		return Vector2.ZERO
	# (BYOND's sin/cos take degrees)
	var ang := deg_to_rad(amount * time_ds)
	var amplitude := amount * (sin(ang) + 1.0)
	var view_range := 7.0 * 32.0
	return Vector2(clampf(amplitude * sin(ang), -view_range, view_range), clampf(amplitude * cos(ang), -view_range, view_range))

## tg do_jitter_animation: amplitude min(4, seconds/100 + 1) pixels.
static func jitter_offset(h: CHealth) -> Vector2:
	var t := h.status_left("jitter")
	if t <= 0.0:
		return Vector2.ZERO
	var amp := minf(4.0, t / 100.0 + 1.0)
	return Vector2(Game.rng.randf_range(-amp, amp), Game.rng.randf_range(-amp / 3.0, amp / 3.0))

## tg jitter examine text
# ------------------------------------------------------------------ drunkenness
## tg /datum/status_effect/inebriated: tipsy under TIPSY_THRESHOLD (6), drunk over it.
const TIPSY_THRESHOLD := 6.0

## tg adjust_drunk_effect
static func adjust_drunk(h: CHealth, amount: float, down_to := 0.0, up_to := INF) -> void:
	var was_drunk := h.drunk >= TIPSY_THRESHOLD
	h.drunk = clampf(h.drunk + amount, down_to, up_to)
	if (h.drunk >= TIPSY_THRESHOLD) != was_drunk:
		Bus.mob_state_changed.emit(h.e)

## tg inebriated/tick (every 2 s): it wears off by 4% + 0.01 a tick, and a drunk (not
## tipsy) body suffers by how drunk it is.
static func _drunk_tick(h: CHealth) -> void:
	if h.dead:
		return
	adjust_drunk(h, -(0.01 + h.drunk * 0.04))
	var d := h.drunk
	if d < TIPSY_THRESHOLD:
		return
	if d >= 16.0:
		h.adjust_status("slurring", 4.0, 20.0)
	h.adjust_status("jitter", -6.0)
	if d >= 41.0:
		if Body.prob(30):
			h.adjust_status("confusion", 2.0)
		h.set_status_if_lower("dizziness", 20.0)
	if d >= 51.0:
		h.set_status_if_lower("dizziness", 50.0)
		if Body.prob(3):
			h.adjust_status("confusion", 15.0)
			Organs.vomit(h)
	if d >= 71.0:
		h.set_status_if_lower("eye_blur", d * 2.0 - 140.0)
	if d >= 81.0:
		h.adjust("tox", 1.0)
		if not (h.knocked_out() or h.in_crit()) and Body.prob(5):
			Game.tell(h.e, "Maybe you should lie down for a bit...", "warn")
	if d >= 91.0:
		h.adjust("tox", 1.0)
		Organs.apply_damage(h, "brain", 0.4)
		if not (h.knocked_out() or h.in_crit()):
			# tg attempt_to_blackout: the blackout personality needs a ghost to take over,
			# which this game hasn't got, so it's the deep sleep
			h.sleep_for(90.0)
	if d >= 101.0:
		h.adjust("tox", 2.0)

## tg TRAIT_FEARLESS while over 51 drunk
static func fearless(h: CHealth) -> bool:
	return h.drunk >= 51.0

## tg inebriated/get_examine_text
static func drunk_examine(h: CHealth) -> String:
	var d := h.drunk
	if h.dead or d < 11.0:
		return ""
	# having your face covered conceals it
	var inv: CInventory = h.e.c(&"inv")
	if inv and inv.worn("mask") != null:
		return ""
	if d <= 21.0:
		return "They are slightly flushed."
	if d <= 41.0:
		return "They are flushed."
	if d <= 51.0:
		return "They are quite flushed and their breath smells of alcohol."
	if d <= 61.0:
		return "They are very flushed and their movements jerky, with breath reeking of alcohol."
	if d <= 91.0:
		return "They look like a drunken mess."
	return "They are a shitfaced, slobbering wreck."

static func examine_lines(h: CHealth) -> Array:
	var out := []
	var dx := drunk_examine(h)
	if dx != "":
		out.append("[color=#ffb84a]%s[/color]" % dx)
	var j := h.status_left("jitter")
	if j >= 300.0:
		out.append("[color=#ff5a4a][b]They are convulsing violently![/b][/color]")
	elif j >= 180.0:
		out.append("[color=#ffb84a]They are extremely jittery.[/color]")
	elif j >= 60.0:
		out.append("[color=#ffb84a]They are twitching ever so slightly.[/color]")
	return out

# ------------------------------------------------------------------ speech
## tg speech_debuffs: stutter then slurring, word by word.
static func treat_message(h: CHealth, text: String) -> String:
	# tg brain traumas' handle_speech and speech traits (mute, aphasia, unintelligible)
	text = Traumas.treat_speech(h, text)
	if text == "":
		return ""
	if h.has_status("stutter"):
		text = _each_word(text, _stutter_word)
	if h.has_status("slurring"):
		text = _each_word(text, _slur_word)
	return text

static func _each_word(text: String, f: Callable) -> String:
	var words := text.split(" ")
	var out := []
	for w in words:
		out.append(f.call(w))
	return " ".join(out)

## tg /datum/status_effect/speech/stutter: 75% of words stutter their first sound.
static func _stutter_word(w: String) -> String:
	if not Body.prob(75):
		return w
	var re := RegEx.create_from_string("(?i)^([\\s\"'()\\[\\]{}.!?,:;_`~-]*\\b)([^aeoiuh\\d]h|qu|[^\\d])(.*)")
	var m := re.search(w)
	if m == null:
		return w
	var c := m.get_string(2)
	var st := c
	if Body.prob(10):
		st = "%s-%s-%s-%s" % [c, c, c, c]
	elif Body.prob(20):
		st = "%s-%s-%s" % [c, c, c]
	elif Body.prob(90):
		st = "%s-%s" % [c, c]
	return m.get_string(1) + st + m.get_string(3)

## tg /datum/status_effect/speech/slurring/generic (drunk text): common 33%, replacement 24%
## (no string replacements in the drunk file), doubletext 40%.
static func _slur_word(w: String) -> String:
	var out := ""
	var dupe := false
	for i in w.length():
		var ch := w[i]
		var mod := ch
		var allow := i != 0 and not ch in " \"'()[]{}.!?,:;_`~-"
		var low := ch.to_lower()
		if Body.prob(33) and SLUR_COMMON.has(low):
			mod = SLUR_COMMON[low]
			dupe = false
		elif allow:
			if not dupe and Body.prob(24):
				dupe = true # no string_replacements/additions in the drunk file
			elif Body.prob(40):
				mod += mod + ("" if Body.prob(50) else mod)
				dupe = false
		else:
			dupe = true
		out += mod
	return out

# ------------------------------------------------------------------ eyes, ears, flashes
## tg /obj/item/organ/eyes: 50 health, nearsighted from 20 (worse from 30), fails (blind)
## at 50; heals STANDARD_ORGAN_HEALING (0.05% of max a second) unless failing.
const EYES_MAX := 50.0
const EYES_LOW := 20.0
const EYES_HIGH := 30.0
const ORGAN_HEALING := 50.0 / 100000.0
## tg flash_protect of worn things (FLASH_PROTECTION_FLASH 1, _WELDER 2)
const FLASH_PROTECTION := {"sunglasses": 1, "welding_goggles": 2, "welding_helmet": 2}

static func eye_protection(h: CHealth) -> int:
	var inv: CInventory = h.e.c(&"inv")
	var p := 0
	if inv:
		for s in ["eyes", "head", "mask"]:
			var w: Entity = inv.worn(s)
			if w:
				p += FLASH_PROTECTION.get(w.proto, 0)
	return p

static func eyes_tick(h: CHealth, dt: float) -> void:
	if h.eye_damage > 0.0 and h.eye_damage < EYES_MAX and not h.dead:
		h.eye_damage = maxf(0.0, h.eye_damage - ORGAN_HEALING * EYES_MAX * dt)
	if h.ear_damage > 0.0 and h.ear_damage < 100.0 and not h.dead:
		h.ear_damage = maxf(0.0, h.ear_damage - ORGAN_HEALING * 100.0 * dt)

static func eyes_failing(h: CHealth) -> bool:
	return h.eye_damage >= EYES_MAX

## tg assign_nearsightedness: 0, 2 (from 20 damage) or 3 (from 30)
static func nearsight(h: CHealth) -> int:
	# tg: glasses with vision_correction clear the nearsighted overlay, whatever caused it
	var inv: CInventory = h.e.c(&"inv") if h.e else null
	var g: Entity = inv.worn("eyes") if inv else null
	if g and g.has_c(&"clothing") and g.c(&"clothing").vision_correction:
		return 0
	if h.eye_damage >= EYES_HIGH:
		return 3
	if h.eye_damage >= EYES_LOW or Quirks.has(h.e, "nearsighted") or h.traits.has("nearsighted"):
		return 2
	return 0

## tg eyes/apply_organ_damage with its threshold messages
static func damage_eyes(h: CHealth, amount: float) -> void:
	var before := h.eye_damage
	h.eye_damage = clampf(h.eye_damage + amount, 0.0, EYES_MAX)
	if before < EYES_LOW and h.eye_damage >= EYES_LOW:
		Game.tell(h.e, "Distant objects become somewhat less tangible.", "warn")
	if before < EYES_HIGH and h.eye_damage >= EYES_HIGH:
		Game.tell(h.e, "Everything starts to look a lot less clear.", "warn")
	if before < EYES_MAX and h.eye_damage >= EYES_MAX:
		Game.tell(h.e, "[b]Darkness envelopes you, as your eyes go blind![/b]", "bad")

## tg living/flash_act + carbon/flash_act. Returns true if they were flashed.
static func flash_act(h: CHealth, intensity := 1, override_blindness := false, visual := false) -> bool:
	if h.dead or h.eyes_removed or h.missing.has("head"):
		return false
	var protection := eye_protection(h)
	var damage := intensity - protection
	if protection >= intensity:
		if damage == 0 and Body.prob(20):
			Game.tell(h.e, "Something bright flashes in the corner of your vision!", "info")
		return false
	if blind(h) and not override_blindness:
		return false
	h.set_status("flash_overlay", 2.5)
	GeneFx.on_flashed(h.e) # tg COMSIG_MOB_FLASHED (epilepsy)
	if visual:
		return true
	if damage == 1:
		Game.tell(h.e, "Your eyes sting a little.", "warn")
		if Body.prob(40):
			damage_eyes(h, 1.0)
	elif damage == 2:
		Game.tell(h.e, "Your eyes burn.", "warn")
		damage_eyes(h, Game.rng.randf_range(2.0, 4.0))
	elif damage >= 3:
		Game.tell(h.e, "Your eyes itch and burn severely!", "bad")
		damage_eyes(h, Game.rng.randf_range(12.0, 16.0))
	if h.eye_damage > 10.0:
		h.adjust_status("temp_blind", damage * 2.0)
		h.set_status_if_lower("eye_blur", damage * Game.rng.randf_range(6.0, 12.0))
		if h.eye_damage > EYES_LOW:
			if nearsight(h) == 0 and Body.prob(h.eye_damage - EYES_LOW):
				Game.tell(h.e, "Your eyes start to burn badly!", "bad")
				damage_eyes(h, EYES_LOW)
			elif not blind(h) and Body.prob(h.eye_damage - EYES_HIGH):
				Game.tell(h.e, "You can't see anything!", "bad")
				damage_eyes(h, EYES_MAX)
		else:
			Game.tell(h.e, "Your eyes are really starting to hurt. This can't be good for you!", "warn")
	return true

## tg get_ear_protection: earmuffs and the like (none in this game but sec helmets? no)
static func ear_protection(h: CHealth) -> int:
	var inv: CInventory = h.e.c(&"inv")
	if inv:
		for s in ["ears", "head"]:
			var w: Entity = inv.worn(s)
			if w and w.proto in ["earmuffs", "helmet_riot"]:
				return 1
	return 0

## tg living/soundbang_act: stun from a loud bang, ear damage and deafness.
static func soundbang_act(h: CHealth, intensity := 1, stun_pwr := 2.0, damage_pwr := 5.0, deafen_pwr := 1.5) -> float:
	var protection := ear_protection(h)
	if protection >= intensity or h.dead:
		return 0.0
	var effect := 1.0 - float(protection) / intensity if protection > 0 else 1.0 - protection
	if stun_pwr > 0.0:
		h.paralyze(stun_pwr * effect * 0.1)
		h.knockdown(stun_pwr * effect)
	if damage_pwr > 0.0 or deafen_pwr > 0.0:
		h.ear_damage = minf(100.0, h.ear_damage + damage_pwr * effect)
		h.adjust_status("deaf", deafen_pwr * effect)
		if h.ear_damage >= 15.0 and Body.prob(h.ear_damage - 5.0):
			Game.tell(h.e, "[b]You can't hear anything![/b]", "bad")
			h.ear_damage = 100.0
		elif h.ear_damage >= 5.0:
			Game.tell(h.e, "Your ears start to ring%s" % (" badly!" if h.ear_damage >= 15.0 else "!"), "warn")
	return effect

static func deaf(h: CHealth) -> bool:
	return Quirks.has(h.e, "deafness") or h.traits.has("deaf") or h.has_status("deaf") or h.ear_damage >= 100.0 or h.knocked_out() and h.health() <= CHealth.HARD_CRIT

## tg /obj/item/assembly/flash/proc/calculate_deviation: 0 facing, 1 sideways, 2 facing away
static func flash_deviation(victim: Entity, from_cell: Vector2i) -> int:
	if victim.cell == from_cell:
		return 1
	var vm: CMob = victim.c(&"mob")
	if vm == null:
		return 0
	var to := from_cell - victim.cell
	var toward := Vector2i(signi(to.x), signi(to.y))
	var facing: Vector2i = Defs.DIRS4[vm.dir]
	# within 45 degrees of where they face
	if (facing.x != 0 and toward.x == facing.x) or (facing.y != 0 and toward.y == facing.y):
		return 0
	if (facing.x != 0 and toward.x == -facing.x) or (facing.y != 0 and toward.y == -facing.y):
		return 2
	return 1

## tg flash/flash_mob. Returns true if it worked.
static func flash_mob(victim: Entity, user: Entity, confusion := 15.0, targeted := true, from_cell = null) -> bool:
	var h: CHealth = victim.c(&"health")
	if h == null or h.dead:
		return false
	var src_cell: Vector2i = from_cell if from_cell != null else (user.cell if user else victim.cell)
	var deviation := flash_deviation(victim, src_cell)
	if deviation == 2:
		return false
	if not flash_act(h, 1, targeted):
		if targeted and user:
			Game.visible_message(victim.cell, "%s fails to blind %s with the flash!" % [user.display_name, victim.display_name], "warn")
		return false
	# adjust_confusion_up_to(confusion, confusion * CONFUSION_STACK_MAX_MULTIPLIER)
	h.adjust_status("confusion", confusion, confusion * 2.0)
	if not targeted:
		return true
	h.adjust("stamina", Game.rng.randf_range(80.0, 120.0) * (1.0 - deviation * 0.5), user)
	h.knockdown(Game.rng.randf_range(2.5, 5.0) * (1.0 - deviation * 0.5))
	if user:
		Game.visible_message(victim.cell, "%s blinds %s with the flash!" % [user.display_name, victim.display_name], "bad")
		Game.tell(victim, "[b]%s blinds you with the flash![/b]" % user.display_name, "bad")
	return true

## tg condensedcapsaicin expose_mob (TOUCH/VAPOR): pepper spray.
static func pepper(h: CHealth) -> bool:
	var inv: CInventory = h.e.c(&"inv")
	# is_pepper_proof: eyes and mouth both covered
	var eyes := false
	var mouth := false
	if inv:
		var mask: Entity = inv.worn("mask")
		if mask and mask.proto == "gas_mask":
			eyes = true
			mouth = true
		for s in ["eyes", "head"]:
			var w: Entity = inv.worn(s)
			if w and (w.proto in FLASH_PROTECTION or (w.has_c(&"clothing") and w.c(&"clothing").covers_eyes)):
				eyes = true
		if mask:
			mouth = true
	if eyes and mouth:
		return false
	var m: CMob = h.e.c(&"mob")
	if m:
		if Body.prob(5):
			m.do_emote("scream")
		m.do_emote("cry")
	h.set_status_if_lower("eye_blur", 10.0)
	h.set_status_if_lower("temp_blind", 6.0)
	h.set_status_if_lower("confusion", 5.0)
	h.knockdown(3.0)
	h.set_status_if_lower("pepperspray", 10.0) # the movespeed modifier
	return true

## tg flashbang/bang (flashbang_range 7, sweetspot 3).
static func flashbang(h: CHealth, at: Vector2i) -> void:
	if h.dead:
		return
	var e := h.e
	Game.tell(e, "BANG", "bad")
	var distance := maxi(absi(e.cell.x - at.x), absi(e.cell.y - at.y))
	var sweetspot := 3
	var flashed := flash_act(h, 1)
	if flashed:
		if distance <= sweetspot:
			h.paralyze(maxf(2.0 / maxi(1, distance), 0.5))
			h.knockdown(maxf(20.0 / maxi(1, distance), 6.0))
		else:
			h.adjust_status("dizziness", maxf(20.0 / maxi(1, distance), 0.5), 20.0)
		_drop_both(e)
	if distance == 0:
		soundbang_act(h, 4, 20.0, 10.0, 15.0)
		return
	if distance <= 1:
		soundbang_act(h, 2, 3.0, 5.0)
		return
	if distance <= sweetspot:
		soundbang_act(h, 1, maxf(20.0 / maxi(1, distance), 6.0), Game.rng.randf_range(0.0, 5.0))
		return
	if soundbang_act(h, 1, 0.0, Game.rng.randf_range(0.0, 2.0)) <= 0.0:
		return
	h.adjust_status("staggered", maxf(20.0 / maxi(1, distance), 0.5), 10.0)
	_drop_both(e)

static func _drop_both(e: Entity) -> void:
	var inv: CInventory = e.c(&"inv")
	if inv:
		for it in inv.hands.duplicate():
			if it and not it.tags.has("self_grasp"):
				inv.drop(it)
