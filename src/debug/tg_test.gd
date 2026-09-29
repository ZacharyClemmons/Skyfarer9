class_name TgTest extends Node
## --tgtest=DIR (with --autotest): exercises the tg machines/atmos pass and checks the
## results: research + lathes, cargo ordering and the supply crawler, firelocks sealing a
## breach, the holofan, fixtures. Prints PASS/FAIL lines; with a window it also saves
## screenshots to DIR.

var dir := ""
var n := 0
var fails := 0

func _ready() -> void:
	_run.call_deferred()

func _ok(cond: bool, what: String) -> void:
	print("%s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		fails += 1

func _run() -> void:
	await get_tree().process_frame
	await _wait(1.0)
	var p: Entity = Game.player
	if p == null:
		print("TGTEST: no player")
		get_tree().quit()
		return
	var inv: CInventory = p.c(&"inv")
	# NPCs stand still for the test (they'd wander into the tiles being worked on)
	for m in Game.all_with(&"brain"):
		m.remove_comp(&"brain")
	# the crew's random quirks (blind, numb, pacifist...) would get in the way of the checks
	for m in Game.all_with(&"mob"):
		Quirks.remove_all(m)
	var id: Entity = inv.worn("id")
	if id == null:
		id = Proto.spawn("id_card", p.cell)
		inv.equip(id, "id")
	id.c(&"idcard").access = ["captain", "command", "security", "brig", "engineering", "atmos", "supply", "cargo", "research", "science", "medical", "maint", "external", "mining"]

	# --- research + lathes
	Research.points = 500.0
	_ok(Research.available("energy_manipulation"), "energy manipulation researchable")
	_ok(Research.research("energy_manipulation", p), "research energy manipulation")
	_ok(Research.research("holographics", p), "research holographics")
	_ok("holofan" in Research.designs_for("protolathe"), "holofan on the protolathe")
	var proto: Entity = Game.all_with(&"lathe").filter(func(x): return x.c(&"lathe").kind == "protolathe").front() if not Game.all_with(&"lathe").is_empty() else null
	_ok(proto != null, "a protolathe exists")
	if proto:
		var pl: CLathe = proto.c(&"lathe")
		var sheets := Proto.spawn("sheet_metal", p.cell, {"comps": {"stack": {"amount": 10}}})
		pl.insert(p, sheets)
		pl.insert(p, Proto.spawn("sheet_glass", p.cell, {"comps": {"stack": {"amount": 5}}}))
		_ok(pl.mats["iron"] >= 1000.0, "sheets go into the lathe")
		pl.print_design(p, "holofan")
		await _wait(4.0)
		var made := false
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			for x in Game.at(proto.cell + d):
				if x.proto == "holofan":
					made = true
		_ok(made, "protolathe printed a holofan")
	var al := Game.all_with(&"lathe").filter(func(x): return x.c(&"lathe").kind == "autolathe")
	_ok(not al.is_empty(), "an autolathe exists")
	var da := Game.all_with(&"danalyzer")
	_ok(not da.is_empty(), "a destructive analyzer exists")
	if not da.is_empty():
		var before := Research.points
		var w := Proto.spawn("multitool", p.cell)
		inv.put_in_hands(w)
		da[0].c(&"danalyzer").attackby(p, w)
		da[0].c(&"danalyzer").destroy_item(p)
		_ok(Research.points > before, "analyzer gives points")

	# --- firelocks
	var fl := Game.all_with(&"firelock")
	_ok(fl.size() > 10, "firelocks placed (%d)" % fl.size())
	var fas := Game.all_with(&"firealarm")
	_ok(fas.size() > 10, "fire alarms placed (%d)" % fas.size())
	var hall_lock: Entity = null
	for f in fl:
		if not Game.at(f.cell).any(func(x): return x.has_c(&"door")) and Game.map.area_at(f.cell).room_kind == "hall":
			hall_lock = f
			break
	if hall_lock == null and not fl.is_empty():
		hall_lock = fl[0]
	if hall_lock:
		# vent the air on one side to space (tg: a breach)
		var side: Vector2i = hall_lock.cell + Vector2i(1, 0)
		if Game.map.blocks_move_static(side):
			side = hall_lock.cell + Vector2i(0, 1)
		var i := Game.map.idx(side)
		var until := Game.time + 3.0
		var detected_breach := false
		while Game.time < until:
			for g in Defs.GAS_COUNT:
				Game.atmos.gas[g][i] = 0.0
			Game.atmos.wake(side)
			# Sample while the breach exists, before diffusion refills this one tile.
			# At high speed several atmos ticks can run before the next machine tick.
			hall_lock.c(&"firelock").tick(1.0)
			detected_breach = detected_breach or hall_lock.c(&"firelock").is_closed()
			await get_tree().process_frame
		_ok(detected_breach, "firelock drops while the adjacent tile is breached")
		p.place(hall_lock.cell + (hall_lock.cell - side))
		Game.view.zoom_level = 3.0
		await _wait(1.0)
		await _shot("firelock")
	# --- fire alarm
	if not fas.is_empty():
		var fa: Entity = fas[0]
		fa.c(&"firealarm").attack_hand(p)
		await _wait(2.5)
		var closed := 0
		for f in fl:
			if fa.c(&"firealarm").area_ref in f.c(&"firelock").areas() and f.c(&"firelock").is_closed():
				closed += 1
		_ok(closed > 0, "pulled fire alarm drops its firelocks (%d)" % closed)
		fa.c(&"firealarm").attack_hand(p)

	# --- cargo
	var pts := Cargo.points
	_ok(Cargo.order("metal50", p), "order a crate")
	_ok(Cargo.points < pts, "order costs credits")
	Cargo.call_shuttle(p)
	Cargo.shuttle_eta = 1.0
	await _wait(3.0)
	_ok(Cargo.state == Cargo.DOCKED and Cargo.crawler != null, "supply crawler docked")
	if Cargo.crawler:
		var crates := 0
		for c in Cargo.crawler.interior:
			for x in Game.at(c):
				if x.proto == "crate":
					crates += 1
		_ok(crates == 1, "the order arrived in the hold")
		p.place(Cargo.crawler.dock_cell - Cargo.crawler.dir * 2)
		Game.view.zoom_level = 2.0
		await _wait(1.0)
		await _shot("supply_crawler")
		Proto.spawn("ore_plasma", Cargo.crawler.interior[3])
		var before2 := Cargo.points
		Cargo.send_shuttle(p)
		_ok(Cargo.points > before2 and Cargo.state == Cargo.OUTBOUND, "sending the crawler sells the hold")

	# --- holofan
	var hf := Proto.spawn("holofan", p.cell)
	inv.put_in_hands(hf)
	var tc := p.cell + Vector2i(1, 0)
	hf.c(&"gadget").project(p, tc)
	_ok(Game.at(tc).any(func(x): return x.has_c(&"holosign")), "holofan projects a barrier")

	# --- fixtures
	var arc := Game.all_with(&"fixture").filter(func(x): return x.c(&"fixture").kind == "arcade")
	if not arc.is_empty():
		var f: CFixture = arc[0].c(&"fixture")
		for k in 40:
			if f.player_hp <= 0:
				break
			f.arcade_act(p, "attack")
		_ok(f.wins > 0 or f.player_hp <= 0, "arcade plays out")
	await _construction(p)
	await _rcd_rpd(p)
	await _guns(p)
	await _status(p)
	await _emotes(p)
	await _mood_quirks(p)
	await _forensics(p)
	await _damage_overlays(p)
	await _medical(p)
	print("TGTEST DONE: %d failures, %d shots" % [fails, n])
	get_tree().quit()

func _shot(name: String) -> void:
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png("%s/%02d_%s.png" % [dir, n, name])
	n += 1

func _wait(sec: float) -> void:
	var until := Game.time + sec
	while Game.time < until:
		await get_tree().process_frame

func _victim(at: Vector2i) -> Entity:
	for m in Game.all_with(&"mob"):
		if m != Game.player and not m.c(&"health").dead:
			m.place(at)
			return m
	return null

func _medical(p: Entity) -> void:
	var inv: CInventory = p.c(&"inv")
	var spot := p.cell + Vector2i(0, 1)
	if Game.map.blocks_move_static(spot):
		spot = p.cell + Vector2i(1, 0)
	var v := _victim(spot)
	_ok(v != null, "got a test patient")
	if v == null:
		return
	var h: CHealth = v.c(&"health")
	_fresh(h)
	_ok(h.blood_type != "" and h.blood_volume == Body.BLOOD_VOLUME_NORMAL, "patient has blood (%s)" % h.blood_type)
	await _gore(p, v, h)
	if v.removed:
		return
	_fresh(h)
	h.dead = false
	h.status.clear()
	_organs(v, h)
	_traumas(v, h)
	_organ_surgery(p, v, h)
	_fresh(h)
	h.status.clear()
	_drunk(v, h)
	_hallucinations(p, v, h)
	_fresh(h)
	h.status.clear()
	await _embeds(p, v, h)
	_blood_stains(p, v, h)
	_fresh(h)
	h.status.clear()
	_fresh(h)
	h.dead = false
	h.status.clear()
	# chemistry: make libital from dispenser chems and feed it
	var bk := Proto.spawn("beaker_large", p.cell)
	var r: CReagents = bk.c(&"reagents")
	for pair in [["fuel", 10.0], ["carbon", 10.0], ["hydrogen", 10.0], ["water", 10.0], ["chlorine", 10.0], ["oxygen", 10.0], ["nitrogen", 10.0]]:
		r.add(pair[0], pair[1], p)
	_ok(r.contents.get("libital", 0.0) > 5.0, "libital synthesised: %s" % Chem.describe(r.contents))
	h.adjust("brute", 40.0)
	var br := h.brute
	Chem.affect_mob(r.take(20.0), v, 1.0)
	await _wait(4.0)
	_ok(h.brute < br - 5.0, "libital heals brute (%.0f -> %.0f)" % [br, h.brute])
	# heater-gated reaction: morphine needs 480 K
	var bk2 := Proto.spawn("beaker", p.cell)
	var r2: CReagents = bk2.c(&"reagents")
	for pair in [["carbon", 10.0], ["hydrogen", 10.0], ["ethanol", 5.0], ["oxygen", 5.0]]:
		r2.add(pair[0], pair[1], p)
	_ok(not r2.contents.has("morphine"), "morphine won't form at room temperature")
	var heaters := Game.all_with(&"chemmachine").filter(func(x): return x.c(&"chemmachine").kind == "heater")
	_ok(not heaters.is_empty(), "a chem heater exists")
	if not heaters.is_empty():
		var hc: CChemMachine = heaters[0].c(&"chemmachine")
		inv.put_in_hands(bk2)
		hc.attackby(p, bk2)
		hc.target_temp = 500.0
		hc.on = true
		await _wait(10.0)
		_ok(r2.contents.has("morphine"), "heated to %d K: %s" % [int(r2.temp), Chem.describe(r2.contents)])
	# ChemMaster pills
	var masters := Game.all_with(&"chemmachine").filter(func(x): return x.c(&"chemmachine").kind == "master")
	_ok(not masters.is_empty(), "a ChemMaster exists")
	if not masters.is_empty():
		var cm: CChemMachine = masters[0].c(&"chemmachine")
		inv.put_in_hands(bk)
		cm.attackby(p, bk)
		cm.to_buffer("libital", 9999.0)
		cm.produce(p, "pill", 2)
		var pills := 0
		for x in Game.at(cm.e.cell + Vector2i(0, 1)):
			if x.proto == "pill":
				pills += 1
		_ok(pills == 2, "ChemMaster pressed 2 pills")
	# gibbing
	Body.gib(h)
	_ok(v.removed, "gibbed body is gone")
	var gibs := 0
	for d in [Vector2i.ZERO] + Defs.DIRS8:
		for x in Game.at(spot + d):
			if x.proto == "gibs":
				gibs += 1
	_ok(gibs >= 3, "gibs everywhere (%d)" % gibs)
	Game.view.zoom_level = 3.0
	await _wait(0.5)
	await _shot("gore")

## tg emotes (datums/emotes.dm and the living/carbon/human emote files)
func _emotes(p: Entity) -> void:
	var spot := p.cell + Vector2i(0, 1)
	if Game.map.blocks_move_static(spot):
		spot = p.cell + Vector2i(1, 0)
	var v := _victim(spot)
	if v == null:
		_ok(false, "emote subject")
		return
	var h: CHealth = v.c(&"health")
	var vm: CMob = v.c(&"mob")
	_calm(h)
	var lines: Array = []
	var grab := func(t, _k): lines.append(t)
	Bus.chat.connect(grab)
	v.remove_meta("emote_cds")
	_ok(Emotes.emote(v, "scream", true), "*scream runs")
	_ok(lines.any(func(l): return l.contains("screams!")), "and everyone nearby hears it")
	_ok(not Emotes.emote(v, "scream", true), "the same emote again at once is on cooldown (0.8 s)")
	_ok(not Emotes.emote(v, "notanemote", true), "an unknown emote is refused")
	_ok(Emotes.emote(v, "smiles", true), "the third-person form works (*smiles)")
	lines.clear()
	Emotes.emote(v, "nod Bob", true)
	_ok(lines.any(func(l): return l.contains("nods at Bob.")), "a parameter fills message_param (nods at Bob.)")
	var was_pronoun := vm.pronoun
	vm.pronoun = "she"
	lines.clear()
	Emotes.emote(v, "cross", true)
	_ok(lines.any(func(l): return l.contains("crosses her arms.")), "pronouns follow the person (crosses her arms.)")
	lines.clear()
	Emotes.emote(v, "surrender", true)
	_ok(lines.any(func(l): return l.contains("they surrenders!") == false and l.contains("she surrenders!")), "surrender%s conjugates (she surrenders!)")
	_ok(h.has_status("paralyzed"), "surrendering paralyses you (20 s)")
	vm.pronoun = was_pronoun
	_calm(h)
	v.remove_meta("emote_cds")
	Emotes.emote(v, "collapse", true)
	_ok(h.has_status("unconscious"), "collapse: unconscious for 4 s")
	_ok(not Emotes.emote(v, "smile", true), "unconscious: can't smile")
	_ok(Emotes.emote(v, "snore", true), "unconscious: can snore")
	_calm(h)
	v.remove_meta("emote_cds")
	h.brute = 110.0 # soft crit
	_ok(not Emotes.emote(v, "scream", true), "soft crit: can't scream")
	_ok(Emotes.emote(v, "gasp", true) and Emotes.emote(v, "cry", true), "soft crit: can gasp and cry")
	_calm(h)
	v.remove_meta("emote_cds")
	h.cuffed = true
	_ok(not Emotes.emote(v, "clap", true), "cuffed: can't clap (needs hands)")
	h.cuffed = false
	h.chems["morphine"] = 5.0
	lines.clear()
	Emotes.emote(v, "scream")
	_ok(lines.is_empty(), "painkillers stop the involuntary screams (TRAIT_ANALGESIA)")
	h.chems.erase("morphine")
	# every emote runs without errors, and every voice builds
	var ran := 0
	for k in Emotes.DEFS:
		if k in ["collapse", "faint", "surrender", "me", "deathgasp", "flip", "backflip", "spin"]:
			continue
		_calm(h)
		v.remove_meta("emote_cds")
		if Emotes.emote(v, k, true, true):
			ran += 1
	_ok(ran >= Emotes.DEFS.size() - 10, "every emote runs (%d)" % ran)
	var built := 0
	for snd in ["scream", "gasp", "cough", "laugh", "sneeze", "sigh", "cry", "yawn"]:
		for vv in ["_m", "_f"]:
			var b := SfxVoice.make(snd + vv)
			if b.size() > 1000 and not is_nan(b[b.size() / 2]):
				built += 1
	for snd in ["sniff", "snore", "whistle", "clap", "snap", "crack", "salute", "jump"]:
		var b2 := SfxVoice.make(snd)
		if b2.size() > 500:
			built += 1
	_ok(built == 24, "all 24 emote sounds synthesise (%d)" % built)
	# death: tg carbons always deathgasp
	_calm(h)
	lines.clear()
	Emotes.emote(v, "deathgasp", false, true)
	_ok(lines.any(func(l): return l.contains("seizes up and falls limp")), "the deathgasp (forced at death)")
	Bus.chat.disconnect(grab)
	_calm(h)

## tg mood (datums/mood.dm), quirks (datums/quirks) and addiction (reagents/withdrawal)
func _mood_quirks(p: Entity) -> void:
	var spot := p.cell + Vector2i(0, 1)
	if Game.map.blocks_move_static(spot):
		spot = p.cell + Vector2i(1, 0)
	var v := _victim(spot)
	if v == null:
		_ok(false, "mood subject")
		return
	var h: CHealth = v.c(&"health")
	var vm: CMob = v.c(&"mob")
	var md: CMood = v.c(&"mood")
	_ok(md != null and p.has_c(&"mood"), "everyone has a mood")
	_calm(h)
	md.events.clear()
	md._update()
	md.set_sanity(100.0, 0.0, 150.0, true)
	_ok(md.mood_level == CMood.NEUTRAL, "no moodlets: neutral")
	md.add("x", "wellfed")
	_ok(md.mood == 8.0 and md.mood_level == CMood.HAPPY2, "wellfed +8: happy level 2 (tg MOOD_HAPPY2 to MOOD_HAPPY3)")
	md.add("y", "see_death", "Bob")
	_ok(md.mood == 0.0 and md.events["y"]["desc"] == "I just saw Bob die. How horrible...", "see_death -8 with the name")
	md.add("y", "see_death", "Bob")
	_ok(md.events["y"]["change"] == -12.0, "seeing another death makes it worse (x1.5)")
	md.events.clear()
	for pair in [["a", "gamer_lost"], ["b", "dismembered"], ["c", "disgusting_food"], ["d", "surgery_failure"], ["f", "gross_food"]]:
		md.add(pair[0], pair[1])
	_ok(md.mood_level == CMood.SAD4, "a terrible day: wish I was dead")
	var s0 := md.sanity
	md.tick(10.0)
	_ok(is_equal_approx(md.sanity, s0 - 3.0), "sad4 drains sanity 0.3/s (%.1f -> %.1f)" % [s0, md.sanity])
	md.set_sanity(10.0, 0.0, 150.0, true)
	_ok(md.sanity_level == CMood.S_INSANE and h.crit_threshold() == 10.0, "insane: crit threshold raised to 10")
	_ok(is_equal_approx(md.move_add(), 0.1) and is_equal_approx(md.action_mult(), 1.25), "insane: +1 ds a step, actions 25% slower")
	md.set_sanity(130.0, 0.0, 150.0, true)
	_ok(md.sanity_level == CMood.S_GREAT and is_equal_approx(md.action_mult(), 0.9), "great sanity: actions 10% faster")
	md.events.clear()
	md.add("t", "slipped")
	md.events["t"]["until"] = Game.time - 1.0
	md.tick(1.0)
	_ok(not md.has("t"), "moodlets time out")
	_ok(md.report().contains("My current mood"), "the mood report reads")
	md.set_sanity(100.0, 0.0, 150.0, true)
	md.events.clear()
	md._update()
	# painful moodlets need you to feel pain (tg MOOD_EVENT_PAIN)
	h.chems["morphine"] = 5.0
	md.add("dis", "dismembered")
	_ok(not md.has("dis"), "painkillers keep pain moodlets away")
	h.chems.erase("morphine")
	# quirks: tg's rules
	_ok(Quirks.filter_valid(["depression", "jolly"]) == ["depression"], "blacklisted pairs can't be taken together")
	_ok(Quirks.filter_valid(["death_mimicry"]).is_empty(), "a positive balance drops positives")
	var rng := RandomNumberGenerator.new()
	var good := true
	for sd in 60:
		rng.seed = sd
		var qs := Quirks.random_set(rng)
		if Quirks.balance(qs) > 0 or qs.filter(func(q): return Quirks.value(q) > 0).size() > 6:
			good = false
	_ok(good, "random crew quirks are always balanced (tg randomise_quirks)")
	var had: Array = vm.quirks.duplicate()
	vm.quirks.clear()
	Quirks.apply(v, ["light_drinker", "numb", "nearsighted", "glass_jaw"], false)
	_ok(is_equal_approx(Quirks.booze_mult(v), 2.0), "light drinker: booze hits twice as hard")
	h.brute = 30.0
	_ok(h.damage_hud()["brute"] == 0 and Hallucinations.screwy(h) == "healthy", "numb: no hurt overlay, the HUD says healthy")
	h.brute = 0.0
	_ok(StatusFx.nearsight(h) == 2, "nearsighted without glasses")
	var gl := Proto.spawn("prescription_glasses", v.cell)
	v.c(&"inv").equip(gl, "eyes")
	_ok(StatusFx.nearsight(h) == 0, "prescription glasses fix it")
	v.c(&"inv").unequip("eyes")
	gl.destroy()
	var ko := 0
	# A small sample occasionally failed despite the correct damage-based chance.
	# Hold the RNG stream stable and use enough hits to check a meaningful range.
	var prior_rng_state := Game.rng.state
	var prior_rng_seed := Game.rng.seed
	Game.rng.seed = 314159
	for i in 80:
		_calm(h)
		h.wounds.clear()
		h.limb_maxed.clear()
		h.hurt_zone("head", 40.0, "brute", null)
		if h.has_status("unconscious"):
			ko += 1
	Game.rng.seed = prior_rng_seed
	Game.rng.state = prior_rng_state
	_ok(ko >= 10 and ko <= 65, "glass jaw: hard head hits knock you out (%d/80)" % ko)
	_calm(h)
	vm.quirks = had
	# addiction
	h.remove_meta("addiction")
	for i in 60:
		Addiction.expose(h, "morphine", 0.5)
	_ok(Addiction.addicted(h, "opioids"), "enough morphine and you're hooked on opioids")
	h.chems.erase("morphine")
	Addiction.tick(h, 125.0)
	Addiction.tick(h, 1.0)
	_ok(Addiction.stage(h, "opioids") == 2 and md.has("opioids_addiction"), "two minutes without: stage 2 withdrawal and its moodlet")
	h.chems["morphine"] = 2.0
	Addiction.tick(h, 1.0)
	_ok(Addiction.stage(h, "opioids") == 0 and not md.has("opioids_addiction"), "a dose ends the withdrawal")
	h.chems.erase("morphine")
	h.remove_meta("addiction")
	# hugs (tg help_shake_act)
	_calm(h)
	md.events.clear()
	p.place(v.cell + Vector2i(1, 0)) if not Game.map.blocks_move_static(v.cell + Vector2i(1, 0)) else null
	Interact.help_hand(p, v)
	_ok(md.has("hug"), "a hug lifts their mood")
	h.knockdown(20.0)
	Interact.help_hand(p, v)
	_ok(h.status_left("knockdown") <= 14.1, "shaking someone up takes 6 s off a knockdown (tg)")
	_calm(h)
	md.events.clear()

## tg /datum/forensics and the detective scanner
func _forensics(p: Entity) -> void:
	var inv: CInventory = p.c(&"inv")
	# empty hands first: unequip needs a free hand to take the gloves off into
	for it in inv.hands.duplicate():
		if it:
			inv.drop(it)
	var had_gloves: Entity = inv.unequip("gloves")
	if had_gloves:
		inv.drop(had_gloves)
	var cup := Proto.spawn("paper", p.cell)
	Interact.pickup(p, cup)
	_ok(Forensics.fingerprint(p) in Forensics.prints_on(cup), "bare hands leave prints (tg add_fingerprint)")
	inv.drop(cup)
	var gl := Proto.spawn("insulated_gloves", p.cell)
	inv.equip(gl, "gloves")
	var cup2 := Proto.spawn("paper", p.cell)
	Interact.pickup(p, cup2)
	_ok(Forensics.prints_on(cup2).is_empty() and Forensics.fingerprint(p) in Forensics.prints_on(gl), "gloves take the print instead")
	inv.drop(cup2)
	inv.unequip("gloves")
	gl.destroy()
	# blood DNA on a weapon (bare hands to the end: the prints and bloody-hand checks need them)
	var v := _victim(p.cell + Vector2i(1, 0) if not Game.map.blocks_move_static(p.cell + Vector2i(1, 0)) else p.cell + Vector2i(0, 1))
	if v:
		_calm(v.c(&"health"))
		var knife := Proto.spawn("toolbox", p.cell)
		Blood.stain_item(knife, v.c(&"health"))
		_ok(Forensics.blood_on(knife).get(Forensics.dna(v), "") == v.c(&"health").blood_type, "blood carries the victim's DNA and type")
		# scan it
		var sc := Proto.spawn("forensic_scanner", p.cell)
		for it in inv.hands.duplicate():
			if it:
				inv.drop(it)
		inv.put_in_hands(sc, inv.active)
		Interact.pickup(p, knife)
		var gd: CGadget = sc.c(&"gadget")
		gd.forensic_scan(p, knife)
		await _wait(3.5)
		_ok(gd.scan_logs.size() == 1 and gd.scan_logs[0]["data"].has("Blood") and gd.scan_logs[0]["data"].has("Fingerprints"), "the scanner logs prints and blood after 3 s")
		var vb := VBoxContainer.new()
		WindowsTG.build("forensic_scanner", sc, vb, null)
		_ok(vb.get_child_count() >= 2, "the scanner window lists the scan")
		vb.free()
		var vb2 := VBoxContainer.new()
		WindowsTG.build("secrecords", null, vb2, null)
		vb2.free()
		gd.forensic_print(p)
		# hands full: tg put_in_hands drops it at your feet
		var paper: Entity = null
		for x in inv.hands + Game.at(p.cell):
			if x and x.display_name.begins_with("FR-"):
				paper = x
		_ok(paper != null and str(paper.tags.get("text", "")).contains(Forensics.dna(v)), "and prints a Forensic Record")
		Blood.clean_item(knife)
		_ok(Forensics.blood_on(knife).is_empty() and Forensics.prints_on(knife).is_empty(), "washing wipes blood and prints (CLEAN_WASH)")
		for it in inv.hands.duplicate():
			if it:
				inv.drop(it)
				it.destroy()
		# bloody hands leave blood where they touch
		Blood.add_to_items(p, ["hands"], v.c(&"health"))
		var door_like := Proto.spawn("paper", p.cell)
		Forensics.touch(door_like, p)
		_ok(Forensics.blood_on(door_like).has(Forensics.dna(v)), "bloody bare hands leave the blood on what they touch")
		door_like.destroy()
		Blood.wash(p, true)
	if had_gloves and is_instance_valid(had_gloves) and not had_gloves.removed:
		inv.equip(had_gloves, "gloves")

## tg update_damage_hud on the player's screen: hurt, suffocating, soft crit, deep crit.
func _damage_overlays(p: Entity) -> void:
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	var ph: CHealth = p.c(&"health")
	var was_god := Game.god_mode
	Game.god_mode = false
	for sample in [["hurt_20", 20.0, 0.0], ["hurt_75", 75.0, 0.0], ["oxy_40", 0.0, 40.0], ["softcrit_-12", 112.0, 0.0], ["crit_-25", 125.0, 0.0]]:
		_calm(ph)
		ph.damageoverlaytemp = 0.0
		ph.brute = sample[1]
		ph.oxy = sample[2]
		for i in 3:
			await get_tree().process_frame
		await _shot("overlay_" + sample[0])
	_calm(ph)
	Game.god_mode = was_god

func _calm(h: CHealth) -> void:
	h.status.clear()
	h.stamina = 100.0
	h.stamcrit = false
	h.sleeping = false
	h.resting = false
	h.get_up(true) # tests: on their feet at once
	h.eye_damage = 0.0
	h.ear_damage = 0.0
	h.oxy = 0.0
	h.brute = 0.0
	h.burn = 0.0
	h.limb.clear()
	h.limb_burn.clear()
	h.cuffed = false

## tg status effects (status_procs.dm, datums/status_effects/debuffs, flash.dm, baton.dm)
func _status(p: Entity) -> void:
	var spot := p.cell + Vector2i(0, 1)
	if Game.map.blocks_move_static(spot):
		spot = p.cell + Vector2i(1, 0)
	var v := _victim(spot)
	if v == null:
		_ok(false, "status patient")
		return
	var h: CHealth = v.c(&"health")
	var vm: CMob = v.c(&"mob")
	_calm(h)
	# stun: upright but helpless
	h.stun(3.0)
	_ok(not h.can_move() and not h.can_use_hands() and not h.floored(), "stun: can't move or act, still standing")
	_calm(h)
	# knockdown: floored, but can crawl and use hands (tg TRAIT_FLOORED only)
	h.knockdown(3.0)
	_ok(h.floored() and h.can_move() and h.can_use_hands(), "knockdown: floored, can crawl and use hands")
	_ok(h.move_add() >= 0.4, "crawling adds 4 ds a step")
	_calm(h)
	# getting back up: when the knockdown runs out they stand, sprite and all
	h.knockdown(8.0)
	await _wait(0.2)
	_ok(not is_zero_approx(vm.doll.rotation), "knocked down: drawn lying (floored %s, rot %.2f, status %s)" % [h.floored(), vm.doll.rotation, h.status])
	while h.floored():
		await get_tree().process_frame
	_ok(h.lying() and h.get_up_t > 0.0, "knockdown wears off: still down while getting up (tg get_up, 1 s)")
	await _wait(1.6)
	_ok(not h.floored() and is_zero_approx(vm.doll.rotation), "knockdown wears off: back on their feet (rot %.2f)" % vm.doll.rotation)
	_calm(h)
	# resting: pressing rest while knocked down doesn't pin you there (tg set_resting)
	h.knockdown(4.0)
	h.set_resting(true)
	h.set_resting(false)
	await _wait(6.0)
	_ok(not h.lying() and not h.resting, "rest toggled while knocked down: still stand up after")
	h.set_resting(true)
	_ok(h.lying() and h.can_move() and not h.floored(), "resting: lying, can crawl, not floored")
	h.set_resting(false)
	_ok(h.lying(), "getting up from rest takes a second")
	await _wait(1.6)
	_ok(not h.lying(), "up after a second")
	_calm(h)
	# tg update_damage_hud severities
	h.damageoverlaytemp = 0.0
	h.brute = 10.0
	_ok(h.damage_hud()["brute"] == 1, "brute overlay 1 at 10 damage")
	h.adjust("brute", 1.0)
	_ok(h.damage_hud()["brute"] == 1 and is_equal_approx(h.damageoverlaytemp, 1.0), "a hit adds what it dealt to the flash (tg damageoverlaytemp)")
	h.brute = 15.0
	h.damageoverlaytemp = 0.0
	_ok(h.damage_hud()["brute"] == 1, "15 is still severity 1 (BYOND ranges include both ends)")
	h.brute = 120.0
	_ok(h.damage_hud()["crit"] == 1, "exactly -20: crit 1, not 2")
	h.brute = 104.0
	var dh := h.damage_hud()
	_ok(dh["crit"] == 0 and dh["critvision"] == 5, "soft crit at -4: critvision 5")
	h.brute = 125.0
	dh = h.damage_hud()
	_ok(dh["crit"] == 2 and dh["critvision"] == 10, "at -25: crit 2, critvision 10")
	h.brute = 135.0
	_ok(h.damage_hud()["critvision"] == 0, "hard crit: no critvision (blacked out)")
	_calm(h)
	h.oxy = 27.0
	_ok(h.damage_hud()["oxy"] == 3, "oxy overlay 3 at 27")
	_calm(h)
	h.damageoverlaytemp = 0.0
	h.paralyze(3.0)
	_ok(h.floored() and not h.can_move() and not h.can_use_hands(), "paralysis: floored, immobile, helpless")
	_calm(h)
	h.immobilize(3.0)
	_ok(not h.can_move() and h.can_use_hands() and not h.floored(), "immobilized: can't move, can act")
	_calm(h)
	# the longer one wins (Can't go below remaining duration)
	h.stun(5.0)
	h.stun(2.0)
	_ok(is_equal_approx(h.stun_t, 5.0), "Stun() doesn't shorten a longer stun")
	_calm(h)
	# soft crit / hard crit
	h.brute = 110.0
	_ok(h.stat() == CHealth.SOFT_CRIT and h.floored() and h.can_move() and not h.can_use_hands(), "soft crit: awake, floored, crawling, hands blocked")
	h.brute = 135.0
	_ok(h.stat() == CHealth.UNCONSCIOUS and h.knocked_out(), "hard crit (-30): knocked out")
	_calm(h)
	h.oxy = 55.0
	_ok(h.knocked_out(), "50 oxygen loss knocks you out (check_passout)")
	_calm(h)
	# stamcrit
	h.adjust("stamina", 110.0)
	h._update_stamcrit()
	_ok(h.stamcrit and h.floored() and not h.can_move(), "stamcrit: floored and immobile at 100 stamina loss")
	_calm(h)
	# confusion over 40 s: every step random
	h.set_status("confusion", 50.0)
	var strays := 0
	for i in 50:
		if StatusFx.confused_step(h, Vector2i(1, 0)) != Vector2i(1, 0):
			strays += 1
	_ok(strays > 30, "heavy confusion sends steps anywhere (%d/50 strayed)" % strays)
	_calm(h)
	# speech
	h.set_status("stutter", 10.0)
	var said := StatusFx.treat_message(h, "please stop hitting me right now")
	_ok(said.contains("-"), "stutter: %s" % said)
	_calm(h)
	# flash: facing the flasher knocks them down and confuses; facing away does nothing
	var fc := v.cell + Vector2i(1, 0)
	vm.dir = Defs.DIR_E
	_ok(StatusFx.flash_mob(v, p, 5.0, true, fc), "a flash to the face works")
	_ok(h.has_status("knockdown") and h.has_status("confusion") and h.stamina < 60.0, "and knocks down, confuses and drains stamina (%.0f)" % h.stamina)
	_calm(h)
	vm.dir = Defs.DIR_W
	_ok(not StatusFx.flash_mob(v, p, 5.0, true, fc), "a flash behind them does nothing (deviation full)")
	_calm(h)
	var sg := Proto.spawn("sunglasses", v.cell)
	var vinv: CInventory = v.c(&"inv")
	var old_eyes: Entity = vinv.worn("eyes")
	if old_eyes:
		vinv.drop(old_eyes)
	vinv.equip(sg, "eyes")
	vm.dir = Defs.DIR_E
	_ok(not StatusFx.flash_mob(v, p, 5.0, true, fc), "sunglasses stop a flash")
	vinv.drop(sg)
	sg.destroy()
	_calm(h)
	# pepper spray: blind 6 s, blur 10 s, confusion 5 s, knockdown 3 s
	StatusFx.pepper(h)
	_ok(StatusFx.blind(h) and h.has_status("eye_blur") and h.has_status("confusion") and h.has_status("knockdown"), "pepper spray blinds, blurs, confuses and floors")
	_calm(h)
	# eyes: repeated welding flashes (intensity 2) hurt, and past 10 blind you briefly
	for i in 6:
		StatusFx.flash_act(h, 2)
	_ok(h.eye_damage > 10.0, "welding flashes hurt bare eyes (%.1f)" % h.eye_damage)
	_calm(h)
	# flashbang at close range
	StatusFx.flashbang(h, v.cell + Vector2i(1, 0))
	_ok(h.has_status("paralyzed") and h.has_status("knockdown") and StatusFx.deaf(h), "a close flashbang paralyses, floors and deafens")
	_calm(h)
	# baton
	var baton := Proto.spawn("baton", p.cell)
	if baton and baton.has_c(&"secgear"):
		baton.c(&"secgear").stun_hit(p, v)
		_ok(h.has_status("jitter") and h.has_status("stutter") and h.has_status("confusion") and h.has_status("knockdown"), "a stun baton: knockdown, jitter, stutter, confusion")
		baton.destroy()
	_calm(h)
	# electrocution: stunned upright, then paralysed 2 s later
	Interact.shock(v, 10.0)
	_ok(h.has_status("stun") and h.has_status("jitter"), "a shock stuns and jitters")
	await _wait(2.3)
	_ok(h.has_status("paralyzed"), "and the second jolt paralyses")
	_calm(h)
	vm._update_pose()

func _fresh(h: CHealth) -> void:
	h.wounds.clear()
	h.gauze.clear()
	h.scars.clear()
	h.bleeding = 0.0
	h.brute = 0.0
	h.burn = 0.0
	h.oxy = 0.0
	h.tox = 0.0
	h.limb.clear()
	h.limb_burn.clear()
	h.limb_maxed.clear()
	h.determination = 0.0
	h.blood_volume = Body.BLOOD_VOLUME_NORMAL
	h.organs = Organs.fresh()
	h.eviscerated = false
	Traumas.cure_all(h, Traumas.RES_ABSOLUTE)
	h.terror = 0.0

func _limb_near(c: Vector2i, part: String) -> Entity:
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			for x in Game.at(c + Vector2i(dx, dy)):
				if x.proto == "severed_limb" and x.tags.get("limb_part", "") == part:
					return x
	return null

## tg wounds, blood and dismemberment (code/datums/wounds, blood.dm, dismemberment.dm)
func _gore(p: Entity, v: Entity, h: CHealth) -> void:
	# --- a laceration: tg flow 2.75, clots 0.02/s; gauze clots it 0.125/s more
	var w := Body.apply_wound(h, "l_arm", "laceration")
	_ok(not w.is_empty() and is_equal_approx(w["flow"], 2.75), "open laceration bleeds 2.75 (tg initial_flow)")
	_ok(h.determination >= 2.5, "a severe wound gives determination (%.1fu)" % h.determination)
	var before := h.blood_volume
	await _wait(3.0)
	_ok(h.blood_volume < before, "blood drains (%.0f -> %.0f)" % [before, h.blood_volume])
	var blood_on_floor := false
	for c in [v.cell] + Defs.DIRS8.map(func(d): return v.cell + d):
		if Game.at(c).any(func(x): return x.has_c(&"decal") and x.c(&"decal").kind == "blood"):
			blood_on_floor = true
	_ok(blood_on_floor, "bleeding leaves blood on the floor")
	_blood_decals(v)
	Body.apply_gauze(h, "l_arm")
	var f0: float = w["flow"]
	Body._process_wound(h, w, 2.0)
	_ok(is_equal_approx(f0 - w["flow"], 0.29), "gauze clots 0.125/s on top of the 0.02/s (%.3f)" % (f0 - w["flow"]))
	_ok(h.gauze["l_arm"]["cap"] < 5.0, "the gauze soaks up blood (%.2f left)" % h.gauze["l_arm"]["cap"])
	# --- demotion: a laceration under its minimum_flow becomes an abrasion
	Body.adjust_flow(h, w, -(w["flow"] - 1.9))
	var ab := Body.wound_on(h, "l_arm", "slash")
	_ok(ab.get("id", "") == "abrasion", "laceration under 2.0 flow demotes to a rough abrasion")
	Body.adjust_flow(h, ab, -5.0)
	_ok(Body.wound_on(h, "l_arm", "slash").is_empty(), "the abrasion closes")
	_ok(h.scars.size() == 1 and h.scars[0]["desc"] in Body.SCAR_DESC["slashsevere"], "it scars like the laceration it was (%s)" % (h.scars[0]["desc"] if not h.scars.is_empty() else "none"))
	_ok(not h.gauze.has("l_arm"), "the gauze falls away with no wounds left")
	# --- rolling wounds: blunt 25 damage with a huge bonus is a compound fracture
	_fresh(h)
	Body.check_wounding(h, "r_arm", "blunt", 25.0, 300.0, 0.0)
	var cf := Body.wound_on(h, "r_arm", "bone")
	_ok(cf.get("id", "") == "compound", "a huge blunt roll is a compound fracture (%s)" % cf.get("id", "none"))
	_ok(Body.limb_disabled(h, "r_arm"), "a compound fracture disables the arm")
	Body.apply_gauze(h, "r_arm")
	_ok(not Body.limb_disabled(h, "r_arm"), "gauze splints it (tg update_inefficiencies)")
	Body.check_wounding(h, "r_arm", "blunt", 25.0, 0.0, 0.0)
	_ok(Body.wound_on(h, "r_arm", "bone")["id"] == "compound", "no sidegrades or downgrades")
	# --- wound armour: a 20 wound armour vest cuts the roll 20%
	_ok(Body.wound_armor(h, "chest") >= 5.0, "jumpsuit wound armour on the chest (%d)" % Body.wound_armor(h, "chest"))
	# --- mangled limb comes off from edged hits (tg try_dismember)
	_fresh(h)
	Body.apply_wound(h, "l_leg", "avulsion")
	Body.apply_wound(h, "l_leg", "hairline")
	_ok(Body.mangled_state(h, "l_leg") == 3, "avulsion + hairline fracture = mangled inside and out")
	for i in 20:
		if h.missing.has("l_leg"):
			break
		h.hurt_zone("l_leg", 20.0, "brute", p, "edged")
	_ok(h.missing.has("l_leg"), "the mangled leg comes off")
	_ok(h.dismembered_by.get("l_leg", "") == "slash", "an edged blow severs it as a slash (%s)" % h.dismembered_by.get("l_leg", ""))
	# tg: with only the skin gone, a sharp weapon goes into the bone as blunt at 60%
	_fresh(h)
	Body.apply_wound(h, "r_leg", "avulsion")
	for i in 30:
		if not Body.wound_on(h, "r_leg", "bone").is_empty():
			break
		h.hurt_zone("r_leg", 20.0, "brute", p, "edged", 30.0)
	_ok(not Body.wound_on(h, "r_leg", "bone").is_empty(), "edged hits on skinned flesh break the bone")
	var leg := _limb_near(v.cell, "l_leg")
	_ok(leg != null, "the severed leg is thrown clear")
	_ok(h.brute >= 15.0, "the chest takes some of the loss (%.0f brute)" % h.brute)
	# --- heads don't come off (tg head can_dismember = FALSE)
	_fresh(h)
	Body.apply_wound(h, "head", "avulsion")
	Body.apply_wound(h, "head", "hairline")
	for i in 20:
		h.hurt_zone("head", 20.0, "brute", p, "edged")
	_ok(not h.missing.has("head"), "a mangled head stays on")
	# --- cranial fissure: only in hard crit
	h.dead = false
	_fresh(h)
	h.oxy = 140.0
	h.dead = false
	var got_fissure := false
	for i in 60:
		Body.check_wounding(h, "head", "blunt", 25.0, 150.0, 0.0)
		if not Body.wound_on(h, "head", "fissure").is_empty():
			got_fissure = true
			break
		for ww in Body.wounds_on(h, "head"):
			h.wounds.erase(ww)
	_ok(got_fissure, "a skull hit in hard crit can split it (cranial fissure)")
	# --- the chest spills its organs in hard crit
	_fresh(h)
	h.oxy = 140.0
	h.dead = false
	Body.apply_wound(h, "chest", "avulsion")
	Body.apply_wound(h, "chest", "hairline")
	for i in 20:
		if h.eviscerated:
			break
		h.hurt_zone("chest", 20.0, "brute", p, "edged")
	_ok(h.eviscerated and not Organs.has(h, "heart") and not Organs.has(h, "lungs") and not Organs.has(h, "liver"), "a mangled chest in hard crit spills its organs")
	_ok(Organs.undergoing_cardiac_arrest(h), "no heart is cardiac arrest (tg undergoing_cardiac_arrest)")
	var heart := false
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			for x in Game.at(v.cell + Vector2i(dx, dy)):
				if x.proto == "organ_heart":
					heart = true
	_ok(heart, "the heart is on the floor")
	# revive for the rest of the test
	h.dead = false
	h.eviscerated = false
	h.missing.clear()
	_fresh(h)
	# --- burns: third degree infects, mesh sanitises
	var bw := Body.apply_wound(h, "r_leg", "burn3")
	for i in 10:
		Body._process_wound(h, bw, 2.0)
	_ok(bw["infection"] > 1.0, "untreated third degree burns get infected (%.2f)" % bw["infection"])
	Body.treat_burn(h, "r_leg", 3.0, 0.75)
	_ok(bw["sanit"] > 0.0 and bw["fheal"] > 0.0, "mesh sanitises and regenerates it")
	# --- bone gel + tape knits a fracture
	var hf := Body.apply_wound(h, "l_arm", "hairline")
	Body.bone_gel(h, "l_arm")
	Body.surgical_tape(h, "l_arm")
	_ok(hf.get("gel", false) and hf.get("taped", false), "bone gel then surgical tape")
	hf["regen_t"] = 119.5
	Body._process_wound(h, hf, 2.0)
	_ok(Body.wound_on(h, "l_arm", "bone").is_empty(), "the fracture knits after 120 ticks")
	# --- dislocation: bonesetter
	Body.apply_wound(h, "r_arm", "dislocation")
	_ok(Body.action_mult(v) >= 1.0, "a dislocated arm slows actions")
	_ok(Body.set_bone(h, "r_arm"), "bonesetter pops the dislocation back")
	# --- pierce internal bleeding and blood types
	_fresh(h)
	Body.apply_wound(h, "chest", "cavity")
	var bv := h.blood_volume
	for i in 10:
		Body._wound_receive_damage(h, Body.wound_on(h, "chest", "pierce"), "pierce", 25.0, 0.0, Vector2i.ZERO)
	_ok(h.blood_volume < bv, "hits on a ruptured cavity bleed internally (%.0f -> %.0f)" % [bv, h.blood_volume])
	# --- reattach by surgery
	_fresh(h)
	Body.dismember(h, "l_arm", "slash")
	_ok(h.missing.has("l_arm"), "arm comes off")
	var lim := _limb_near(v.cell, "l_arm")
	_ok(lim != null, "severed limb drops")
	if lim:
		h.knockdown(60.0)
		p.c(&"mob").zone = "l_arm"
		v.set_meta("surgery", {"proc": "reattach", "zone": "l_arm", "step": 3})
		Surgery._apply("reattach", h, "l_arm", p, lim)
		_ok(not h.missing.has("l_arm"), "surgery reattaches the arm")
		v.remove_meta("surgery")
	_fresh(h)

func _tool(p: Entity, proto: String) -> Entity:
	var inv: CInventory = p.c(&"inv")
	for h in inv.hands.duplicate():
		if h:
			inv.drop(h)
	var t := Proto.spawn(proto, p.cell)
	inv.put_in_hands(t, inv.active)
	if proto == "welder":
		t.c(&"welder").fuel = 50.0 if "fuel" in t.c(&"welder") else 0.0
		t.attack_self(p)
	return t

func _construction(p: Entity) -> void:
	_open_spot(p)
	p.c(&"mob").combat = false
	var spot := p.cell + Vector2i(1, 0)
	if Game.map.blocks_move_static(spot):
		spot = p.cell + Vector2i(-1, 0)
	for x in Game.at(spot).duplicate():
		if not x.has_c(&"mob") and not x.has_c(&"door"):
			x.destroy()
	# a vending machine: screwdriver, crowbar -> frame + board
	var vm := Proto.spawn("vending", spot, {"spr": "vending_snack", "comps": {"vending": {"products": [["food_donut", 3]]}}})
	Interact.use_item_on(p, _tool(p, "screwdriver"), vm)
	_ok(vm.tags.get("panel_open", false), "screwdriver opens a machine's panel")
	Interact.use_item_on(p, _tool(p, "crowbar"), vm)
	await _wait(9.0)
	var frame: Entity = null
	var board: Entity = null
	for x in Game.at(spot):
		if x.proto == "machine_frame":
			frame = x
		if x.proto == "circuit_board":
			board = x
	_ok((not is_instance_valid(vm) or vm.removed) and frame != null and board != null, "crowbar pries it into a frame and a board")
	if frame and board:
		frame.c(&"frame").state = 0
		frame.c(&"frame")._refresh()
		Interact.use_item_on(p, _tool(p, "wrench"), frame)
		await _wait(3.0)
		var cable := _tool(p, "cable_coil")
		cable.c(&"stack").amount = 10
		Interact.use_item_on(p, cable, frame)
		await _wait(3.0)
		var inv: CInventory = p.c(&"inv")
		inv.drop(inv.active_item())
		inv.put_in_hands(board, inv.active)
		Interact.use_item_on(p, board, frame)
		Interact.use_item_on(p, _tool(p, "screwdriver"), frame)
		await _wait(3.0)
		var rebuilt: Entity = null
		for x in Game.at(spot):
			if x.proto == "vending":
				rebuilt = x
		_ok(rebuilt != null and rebuilt.c(&"vending").products[0]["proto"] == "food_donut", "frame + wrench + cable + board + screwdriver rebuilds the same machine")
		if rebuilt:
			rebuilt.destroy()
	# furniture: wrench a table apart
	var tbl := Proto.spawn("table", spot)
	Construction.tool_act(p, _tool(p, "wrench"), tbl)
	await _wait(7.0)
	_ok((not is_instance_valid(tbl) or tbl.removed) and Game.at(spot).any(func(x): return x.proto == "sheet_metal"), "wrench takes a table apart")
	for x in Game.at(spot).duplicate():
		if x.has_c(&"item"):
			x.destroy()
	# closets: weld shut
	var lk := Proto.spawn("locker", spot)
	var w := _tool(p, "welder")
	Interact.use_item_on(p, w, lk)
	await _wait(4.0)
	_ok(lk.tags.get("welded", false) and not lk.c(&"storage").open(p), "welder welds a locker shut")
	lk.destroy()
	# floors: crowbar gives a tile, the tile lays a floor
	var fc := spot
	if Game.map.tflags(fc) & Defs.F_FLOOR:
		Interact.use_on_tile(p, _tool(p, "crowbar"), fc)
		await _wait(2.5)
		var tile: Entity = null
		for x in Game.at(fc):
			if x.proto == "floor_tile":
				tile = x
		_ok(Game.map.get_turf(fc) == Defs.T_PLATING and tile != null, "crowbar pries up a floor tile")
		if tile:
			var inv2: CInventory = p.c(&"inv")
			inv2.drop(inv2.active_item())
			inv2.put_in_hands(tile, inv2.active)
			Interact.use_on_tile(p, tile, fc)
			_ok(Game.map.get_turf(fc) == Defs.T_STEEL, "a floor tile lays a floor")

func _rcd_rpd(p: Entity) -> void:
	_open_spot(p)
	var map := Game.map
	var rcd := _tool(p, "rcd")
	var r: CRCD = rcd.c(&"rcd")
	var spot := Vector2i(-1, -1)
	for d in Defs.DIRS4:
		var c: Vector2i = p.cell + d
		if (map.tflags(c) & Defs.F_FLOOR) and Game.at(c).is_empty() and map.structure[map.idx(c)] == Defs.S_NONE:
			spot = c
			break
	_ok(spot.x >= 0, "found a free floor tile for the RCD")
	if spot.x < 0:
		return
	r.mode = "floorwall"
	r.act(p, spot)
	await _wait(3.0)
	_ok(map.get_turf(spot) == Defs.T_WALL and r.matter == 144.0, "RCD builds a wall for 16 matter")
	r.mode = "deconstruct"
	r.act(p, spot)
	await _wait(5.0)
	_ok(not (map.tflags(spot) & Defs.F_WALL), "RCD deconstructs the wall")
	r.mode = "airlock"
	_open_spot(p)
	for d4 in Defs.DIRS4:
		if Game.at(p.cell + d4).is_empty():
			spot = p.cell + d4
			break
	r.act(p, spot)
	await _wait(6.0)
	var door := Game.at(spot).filter(func(x): return x.has_c(&"door"))
	_ok(not door.is_empty(), "RCD builds an airlock")
	for d2 in door:
		d2.destroy()
	# RPD: extend a supply pipe and fit a pump on a straight run
	var rpd := _tool(p, "rpd")
	var rp: CRPD = rpd.c(&"rpd")
	var target := Vector2i(-1, -1)
	var stand := Vector2i(-1, -1)
	for i in map.pipe_layers[StationMap.PL_SUPPLY].size():
		var c2 := map.cell_of(i)
		var m := map.pipe_mask(StationMap.PL_SUPPLY, c2)
		if m == 0 or Game.pipes.inline[StationMap.PL_SUPPLY].has(i):
			continue
		for k in 4:
			var n: Vector2i = c2 + Defs.DIRS4[k]
			if not (m & (1 << k)) and map.pipe_mask(StationMap.PL_SUPPLY, n) == 0 and map.is_passable(n) and not map.is_outdoor(n) and map.area_at(n).id != 0:
				for d3 in Defs.DIRS4:
					var st: Vector2i = n + d3
					if map.is_passable(st) and st != c2 and not map.is_outdoor(st) and Game.at(st).is_empty():
						target = n
						stand = st
						break
			if target.x >= 0:
				break
		if target.x >= 0:
			break
	_ok(target.x >= 0, "found a spot to extend the supply pipe")
	if target.x < 0:
		return
	p.place(stand)
	rp.layer = StationMap.PL_SUPPLY
	rp.category = "pipe"
	rp.act(p, target)
	await _wait(1.5)
	_ok(map.pipe_mask(StationMap.PL_SUPPLY, target) != 0, "RPD lays a smart pipe")
	rp.mode = "destroy"
	rp.act(p, target)
	await _wait(2.0)
	_ok(map.pipe_mask(StationMap.PL_SUPPLY, target) == 0, "RPD removes the pipe")

## Stand the player in a clear 3x3 patch of hallway floor.
func _open_spot(p: Entity) -> void:
	var map := Game.map
	for a in map.areas:
		if a.room_kind != "hall":
			continue
		for c in a.cells:
			var ok := true
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var n: Vector2i = c + Vector2i(dx, dy)
					if not (map.tflags(n) & Defs.F_FLOOR) or map.structure[map.idx(n)] != Defs.S_NONE or not Game.at(n).is_empty() or map.area_at(n) != a:
						ok = false
			if ok:
				p.place(c)
				return

func _guns(p: Entity) -> void:
	_open_spot(p)
	var v: Entity = null
	for m in Game.all_with(&"mob"):
		if m != p and not m.c(&"health").dead:
			v = m
			break
	if v == null:
		return
	var tc := p.cell + Vector2i(2, 0)
	if not Game.map.is_passable(tc):
		tc = p.cell + Vector2i(-2, 0)
	v.place(tc)
	var h: CHealth = v.c(&"health")
	h.stamina = 100.0
	var sg := _tool(p, "shotgun")
	var g: CGadget = sg.c(&"gadget")
	_ok(g.chamber.size() == 6 and g.chamber[0] == "shell_rubbershot" and g.chamber_ready(), "riot shotgun starts with six rubber-shot shells and a live chamber")
	g.fire(p, tc)
	_ok(h.stamina < 100.0 and g.pump_needed, "rubber shot winds them and leaves the shotgun needing a pump")
	g.unload(p)
	var beanbag := Proto.spawn("shell_beanbag", p.cell, {"comps": {"stack": {"amount": 1}}})
	g.load_ammo(p, beanbag)
	g.pump(p)
	g.cooldown = 0.0
	_calm(h)
	g.fire(p, tc)
	_ok(h.stamina < 60.0, "a separately loaded beanbag winds them (stamina %.0f)" % h.stamina)
	var rv := _tool(p, "revolver")
	var rg: CGadget = rv.c(&"gadget")
	rg.unload(p)
	_ok(rg.chamber.is_empty(), "revolver unloads")
	var box := Proto.spawn("ammo_38", p.cell)
	rv.attackby(p, box)
	_ok(rg.chamber.size() == 6 and rg.chamber[0] == "ammo_38", "loading a box of .38")
	var br := h.brute
	rg.cooldown = 0.0
	rg.fire(p, tc)
	_ok(h.brute > br, "a .38 round hurts (%.0f)" % (h.brute - br))
	var vest := Proto.spawn("armor_vest", v.cell)
	_ok(vest.c(&"clothing").bullet_armor == 30.0, "armor vest has tg bullet armour 30")

## tg /obj/effect/decal/cleanable/blood: drips stack, pools grow to 300 and dry.
func _blood_decals(v: Entity) -> void:
	var c := v.cell + Vector2i(0, 2)
	for x in Game.at(c):
		if x.has_c(&"decal"):
			x.destroy()
	var d := Body.splatter(c, 0.0, true)
	_ok(d != null and d.proto == "blood_drip", "a small bleed makes drips (%s)" % (d.proto if d else "none"))
	for i in 4:
		Body.splatter(c, 0.0, true)
	_ok(d.c(&"decal").drops.size() == 4, "drips stack on the tile, 5 max (%d extra)" % d.c(&"decal").drops.size())
	var sp := Body.splatter(c, 0.0, true)
	_ok(d.removed and sp != null and sp.proto == "blood", "a sixth drop turns the drips into a splatter")
	for i in 10:
		Body.splatter(c, 50.0)
	var pools := Game.at(c).filter(func(x): return x.proto == "blood")
	_ok(pools.size() == 1 and pools[0].c(&"decal").bloodiness == CDecal.BLOOD_POOL_MAX, "more blood grows one pool, capped at 300 (%s)" % [pools.map(func(x): return x.c(&"decal").bloodiness)])
	var dc: CDecal = pools[0].c(&"decal")
	dc.drying_time = 0.01
	await _wait(1.1) # Decals process on the one-second machine tick.
	_ok(dc.dried, "a pool dries in time (tg DRYING_TIME)")
	var s2 := Body.splatter(c, 50.0)
	_ok(s2 != pools[0], "dried blood takes no more: new blood is a new decal")
	for x in Game.at(c):
		if x.has_c(&"decal"):
			x.destroy()

## tg organs (surgery/organs/internal, brain_item.dm)
func _organs(v: Entity, h: CHealth) -> void:
	# heart: a failing heart stops, and cardiac arrest is oxygen loss and unconsciousness
	Organs.apply_damage(h, "heart", 100.0)
	_ok(Organs.failing(h, "heart"), "a heart at 100 damage is failing")
	var oxy0 := h.oxy
	Organs.tick(h, 1.0)
	_ok(Organs.undergoing_cardiac_arrest(h), "a failing heart stops (heart/on_life)")
	_ok(h.oxy >= oxy0 + 4.0 and h.has_status("unconscious"), "cardiac arrest: +4 oxy a second and out cold (%.0f)" % (h.oxy - oxy0))
	_ok(Organs.defib_block(h) == "failing_heart", "a failing heart can't be defibbed")
	Organs.set_damage(h, "heart", 0.0)
	_ok(not Organs.failing(h, "heart"), "a repaired heart stops failing")
	Organs.set_heartattack(h, false)
	_ok(not Organs.undergoing_cardiac_arrest(h), "and can be restarted")
	# healing: STANDARD_ORGAN_HEALING is 0.05% of max a second
	Organs.set_damage(h, "heart", 50.0)
	Organs.tick(h, 10.0)
	_ok(is_equal_approx(Organs.damage(h, "heart"), 49.5), "organs heal 0.05/s (%.2f)" % Organs.damage(h, "heart"))
	_ok(is_equal_approx(Organs.blood_regeneration_multiplier(h), 0.505), "a damaged heart makes blood slower (x%.3f)" % Organs.blood_regeneration_multiplier(h))
	_ok(is_equal_approx(Organs.breath_interval(h), 6.0), "a heart past its high threshold quickens breathing (every %.0f s)" % Organs.breath_interval(h))
	Organs.set_damage(h, "heart", 0.0)
	# lungs: failing lungs miss breaths
	Organs.apply_damage(h, "lungs", 100.0)
	_ok(Organs.lungs_failing(h), "failed lungs")
	Organs.set_damage(h, "lungs", 0.0)
	# liver: toxins over its tolerance hurt it; a failing liver poisons you by stages
	h.chems = {"cyanide": 20.0}
	var l0 := Organs.damage(h, "liver")
	Organs.liver_filter(h, 1.0)
	_ok(is_equal_approx(Organs.damage(h, "liver") - l0, minf(20.0 / 15.0 * 1.25, 2.0)), "20u cyanide: (20/15)*1.25 liver damage a second (%.3f)" % (Organs.damage(h, "liver") - l0))
	h.chems = {"cyanide": 2.0}
	var skip := Organs.liver_filter(h, 1.0)
	_ok(skip.has("cyanide"), "2u of toxin is under the liver's tolerance and filtered")
	h.chems.clear()
	Organs.apply_damage(h, "liver", 100.0)
	h.organs["liver"]["fail_t"] = 59.5
	var tox0 := h.tox
	Organs.tick(h, 1.0)
	_ok(h.tox > tox0, "liver failure stage 1 after a minute: toxin damage")
	_ok(Organs.jaundice(h).contains("yellow"), "a failing liver yellows the eyes (%s)" % Organs.jaundice(h))
	_ok(not Organs.liver_works(h), "a failing liver doesn't metabolise")
	Organs.set_damage(h, "liver", 0.0)
	# brain: damage past 20 rolls for traumas; 200 kills
	Organs.set_damage(h, "brain", 90.0)
	var got := false
	for i in 40:
		Organs.apply_damage(h, "brain", 2.0)
		Organs.apply_damage(h, "brain", -2.0)
		if not h.traumas.is_empty():
			got = true
			break
	_ok(got, "brain damage rolls for brain traumas (%s)" % [h.traumas.map(func(t): return t["id"])])
	Traumas.cure_all(h, Traumas.RES_ABSOLUTE)
	Organs.apply_damage(h, "brain", 200.0)
	Organs.tick(h, 1.0)
	_ok(h.dead, "200 brain damage: the last spark fizzles out")
	h.dead = false
	h.status.clear()
	Organs.set_damage(h, "brain", 0.0)
	# dead organs decay while warm: the heart fails ~6 minutes after death
	h.organs = Organs.fresh()
	h.dead = true
	h.body_temp = 310.0
	Organs.tick(h, 100.0)
	_ok(is_equal_approx(Organs.damage(h, "heart"), 2.5 * 111.0 / 100000.0 * 100.0 * 100.0), "a dead heart decays 2.5x STANDARD_ORGAN_DECAY (%.2f)" % Organs.damage(h, "heart"))
	h.body_temp = 250.0
	var hd := Organs.damage(h, "heart")
	Organs.tick(h, 100.0)
	_ok(Organs.damage(h, "heart") == hd, "a frozen body doesn't decay")
	h.dead = false
	h.body_temp = Defs.BODYTEMP_NORMAL
	h.organs = Organs.fresh()

## tg brain traumas (datums/brain_damage)
func _traumas(v: Entity, h: CHealth) -> void:
	Traumas.cure_all(h, Traumas.RES_ABSOLUTE)
	Traumas.gain(h, "mute")
	_ok(Traumas.mute(h) and StatusFx.treat_message(h, "hello") == "", "mutism: no words come out")
	Traumas.gain(h, "paralysis", -1, "l_leg")
	_ok(Body.limb_disabled(h, "l_leg") and not Body.limb_disabled(h, "r_leg"), "paralysis of the left leg disables it")
	_ok(not Traumas.can_gain(h, "blindness"), "only two severe traumas at once (TRAUMA_LIMIT_SURGERY)")
	var basic_cured := Traumas.cure_all(h, Traumas.RES_BASIC)
	_ok(basic_cured == 0, "neurine-level cures don't touch severe traumas (%d cured, %s)" % [basic_cured, h.traumas.map(func(t): return [t["id"], t["res"]])])
	_ok(Traumas.cure_all(h, Traumas.RES_SURGERY) == 2, "brain surgery cures them")
	Traumas.gain(h, "tenacity")
	h.brute = 110.0
	_ok(not h.in_crit() and not h.floored(), "tenacity: no soft crit at -10 health")
	h.brute = 0.0
	Traumas.gain(h, "expressive_aphasia")
	var said := Traumas._expressive_aphasia("the incomprehensible cat")
	_ok(said.begins_with("the "), "expressive aphasia keeps common words (%s)" % said)
	Traumas.cure_all(h, Traumas.RES_ABSOLUTE)
	# a hairline skull fracture cycles mild traumas (TRAUMA_RESILIENCE_WOUND)
	var w := Body.apply_wound(h, "head", "hairline")
	var wt := h.traumas.filter(func(t): return t["res"] == Traumas.RES_WOUND)
	_ok(wt.size() == 1 and wt[0]["group"] == "mild", "a skull fracture brings a mild trauma (%s)" % [wt.map(func(t): return t["id"])])
	Body.remove_wound(h, w)
	_ok(h.traumas.is_empty(), "and it goes with the fracture")
	# monophobia: alone, the terror builds
	Traumas.gain(h, "monophobia")
	h.terror = 0.0
	Traumas._fear(h, 1.0)
	_ok(true, "fear ticks (terror %.1f)" % h.terror)
	Traumas.cure_all(h, Traumas.RES_ABSOLUTE)
	# neurine cures a mild trauma now and then
	Traumas.gain(h, "stuttering")
	h.chems = {"neurine": 30.0}
	for i in 60:
		Chem.metabolize(h, 1.0)
		if h.traumas.is_empty():
			break
	_ok(h.traumas.is_empty(), "neurine cures a basic trauma (8%/s)")
	h.chems.clear()

## tg organ surgeries (operation_organ_repair.dm, organ manipulation)
func _organ_surgery(p: Entity, v: Entity, h: CHealth) -> void:
	h.organs = Organs.fresh()
	Organs.set_damage(h, "heart", 80.0)
	_ok("coronary_bypass" in Surgery.options("chest", v), "a heart at 80 damage can have a bypass")
	v.set_meta("surgery", {"proc": "coronary_bypass", "zone": "chest", "step": 4})
	Surgery._apply("repair_organ", h, "chest", p)
	_ok(is_equal_approx(Organs.damage(h, "heart"), 60.0), "the bypass repairs it to 60 percent (%.0f)" % Organs.damage(h, "heart"))
	_ok(not "coronary_bypass" in Surgery.options("chest", v), "only once per heart")
	v.remove_meta("surgery")
	Organs.set_damage(h, "brain", 100.0)
	Traumas.gain(h, "mute")
	Surgery._apply("fix_brain", h, "head", p)
	_ok(is_equal_approx(Organs.damage(h, "brain"), 50.0) and h.traumas.is_empty(), "brain surgery heals 50 and cures severe traumas (%.0f, %d)" % [Organs.damage(h, "brain"), h.traumas.size()])
	# appendectomy through organ manipulation
	var pinv: CInventory = p.c(&"inv")
	for it in pinv.hands.duplicate():
		if it:
			pinv.drop(it)
	h.organs["appendix"]["inflamation"] = 2
	Surgery._manip(h, "chest", p, null)
	_ok(not Organs.has(h, "appendix"), "organ manipulation takes out the inflamed appendix first")
	var app: Entity = p.c(&"inv").active_item()
	_ok(app != null and app.proto == "organ_appendix" and app.tags.get("inflamation", 0) == 2, "and the surgeon holds it (%s)" % (app.display_name if app else "nothing"))
	if app:
		Surgery._manip(h, "chest", p, app)
		_ok(Organs.has(h, "appendix"), "an organ can be put back in")
	h.organs = Organs.fresh()

## tg /datum/status_effect/inebriated and ethanol/on_mob_life
func _drunk(v: Entity, h: CHealth) -> void:
	h.drunk = 0.0
	h.chems = {"vodka": 30.0}
	var l0 := Organs.damage(h, "liver")
	for i in 10:
		Chem.metabolize(h, 1.0)
	_ok(h.drunk > 0.5, "vodka gets you drunk: sqrt(u)*65*0.005 a second (%.2f)" % h.drunk)
	_ok(Organs.damage(h, "liver") > l0, "and hurts the liver a little (%.3f)" % (Organs.damage(h, "liver") - l0))
	h.chems.clear()
	h.drunk = 55.0
	StatusFx._drunk_tick(h)
	_ok(is_equal_approx(h.drunk, 55.0 - (0.01 + 55.0 * 0.04)), "drunkenness wears off 4%% + 0.01 a tick (%.2f)" % h.drunk)
	_ok(h.status_left("dizziness") >= 50.0 and h.has_status("slurring"), "over 51: dizzy and slurring")
	_ok(StatusFx.fearless(h), "over 51: fearless")
	_ok(StatusFx.drunk_examine(h).contains("flushed"), "and it shows (%s)" % StatusFx.drunk_examine(h))
	h.drunk = 95.0
	h.status.clear()
	StatusFx._drunk_tick(h)
	_ok(h.has_status("sleeping") and h.tox > 0.0, "over 91: toxins and blacking out")
	h.drunk = 0.0
	h.status.clear()
	h.tox = 0.0
	# the bottle carries it
	var bottle := Proto.spawn("drink_booze", v.cell)
	bottle.c(&"food").consume(v)
	_ok(h.chems.get("vodka", 0.0) > 15.0, "a sip from a bottle of vodka is 20u (%.0f)" % h.chems.get("vodka", 0.0))
	bottle.destroy()
	h.chems.clear()

## tg hallucinations
func _hallucinations(p: Entity, v: Entity, h: CHealth) -> void:
	var bad := false
	for i in 300:
		var id := Hallucinations._pick(Hallucinations.TIER_COMMON)
		if Hallucinations.POOL[id][1] > Hallucinations.TIER_COMMON:
			bad = true
	_ok(not bad, "a short hallucination only picks common ones")
	_ok(Hallucinations.cause(h, "shock") and h.has_status("stun") and h.stamina <= 50.0, "a hallucinated shock: stunned and winded")
	h.set_meta("hallu_later", [[Game.time - 1.0, "shock_drop"]])
	Hallucinations._tick_active(h)
	_ok(h.has_status("paralyzed"), "then drops you")
	h.status.clear()
	h.stamina = 100.0
	_ok(Hallucinations.cause(h, "death") and h.has_status("paralyzed") and Traumas.mute(h), "a fake death: floored and mute")
	h.status.clear()
	h.remove_meta("hallu_later")
	h.remove_meta("screwy_hud")
	# every kind at least runs for the player
	var ph: CHealth = p.c(&"health")
	var ok := true
	for id in Hallucinations.POOL:
		Hallucinations.cause(ph, id)
	Hallucinations._tick_active(ph)
	_ok(ok, "all %d hallucination kinds run" % Hallucinations.POOL.size())
	ph.status.clear()
	ph.stamina = 100.0
	for k in ["hallu_later", "screwy_hud", "screwy_hud_until", "fake_alert", "fake_alert_until", "fake_fire", "fake_fire_stam", "fake_bleed_part", "fake_bleed_until", "hazard"]:
		ph.remove_meta(k)
	if ph.has_meta("delusion"):
		Hallucinations._end_delusion(ph)
	Fx.flame_off(p)
	# the status effect starts them on its own
	h.set_status("hallucination", 100.0)
	h.remove_meta("hallu_cd")
	Hallucinations.tick(h, 1.0)
	_ok(h.get_meta("hallu_cd", 0.0) > Game.time, "the hallucination status schedules the next one")
	h.status.clear()
	h.stamina = 100.0
	h.remove_meta("hallu_later")

## tg /datum/embedding
func _embeds(p: Entity, v: Entity, h: CHealth) -> void:
	h.embedded.clear()
	h.resting = false
	h.get_up(true) # standing: lying cuts fall and pain chances (tg)
	var before := h.brute
	var em := Embeds.embed_into(h, "l_arm", "spear", "spear", 4, "pointy", Embeds.data("spear"), 20.0)
	_ok(h.embedded.size() == 1 and h.brute > before, "a spear embeds in the arm, hurting on impact (%.0f)" % (h.brute - before))
	_ok(Embeds.examine_lines(h).size() == 1, "and shows on examine")
	# it falls out (tg fall_out), and the spear is left on the floor
	em["data"]["fall_chance"] = 100.0
	Embeds.tick(h, 1.0)
	_ok(h.embedded.is_empty(), "embedded things fall out now and then")
	var spear := false
	for x in Game.at(v.cell):
		if x.proto == "spear":
			spear = true
			x.destroy()
	_ok(spear, "the spear falls on the floor")
	# bullets lodge as DROPDEL shrapnel, 25% for a .38
	var got := 0
	for i in 200:
		if Embeds.try_projectile("ammo_38", v, "chest", 0, 0.0):
			got += 1
		h.embedded.clear()
		h.brute = 0.0
		h.limb.clear()
		h.wounds.clear()
	_ok(got > 25 and got < 80, ".38 rounds embed about a quarter of the time (%d/200)" % got)
	_ok(not Embeds.try_projectile("ammo_38_rubber", v, "chest", 0, 0.0), "rubber rounds never embed")
	# ripping it out by hand
	var b := Embeds.embed_into(h, "chest", ".38 bullet", "", 1, "pointy", Embeds.data("c38"), 0.0, true)
	Embeds.rip_out(p, v, b)
	await _wait(1.5)
	_ok(h.embedded.is_empty(), "someone can rip it out (tg rip_out)")
	h.embedded.clear()
	_fresh(h)

## tg add_blood_DNA_to_items and attack_effects
func _blood_stains(p: Entity, v: Entity, h: CHealth) -> void:
	var vinv: CInventory = v.c(&"inv")
	Blood.add_to_items(v, ["iclothing", "oclothing"])
	var worn: Entity = vinv.worn("suit") if vinv.worn("suit") else vinv.worn("uniform")
	_ok(worn == null or Blood.bloody(worn), "blood gets on the outermost clothes (%s)" % (Blood.title(worn) if worn else "naked"))
	var lines := []
	vinv.examine(p, lines)
	_ok(worn == null or lines.any(func(l): return "blood-stained" in l), "and shows on examine")
	Blood.wash(v, true)
	_ok(worn == null or not Blood.bloody(worn), "a shower washes it off")
	# a good hit bloodies the weapon
	var knife := Proto.spawn("knife_kitchen", p.cell)
	for i in 30:
		Combat.attack_effects(p, v, 25.0, "brute", "chest", "edged", 0.0, knife)
		if Blood.bloody(knife):
			break
	_ok(Blood.bloody(knife), "the weapon that drew blood is blood-stained")
	knife.destroy()
	Blood.wash(p, true)
	Blood.wash(v, true)
