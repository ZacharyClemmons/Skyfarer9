class_name GeneTest extends Node
## --genetest (with --autotest): tg genetics. DNA blocks and identity, mutation
## activation and instability, injectors, mutadone, meltdowns, monkeys (the race gene, born
## monkeys, cubes), the DNA scanner and console, speech mutations, and the Genetics lab on
## the map. Prints GENE PASS/FAIL lines and quits.

var fails := 0
var dir := ""

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_dna_core()
	_mutations()
	_instability()
	_injectors()
	_lifecycle_parity()
	await _mutadone()
	await _monkeys()
	await _cube()
	_console()
	_speech()
	_lab()
	_window()
	_powers()
	await _workflow()
	await _tg_parity()
	_expanded()
	await _body_systems()
	_tutorial()
	await _completion_mechanics()
	_catalog_lifecycle()
	if dir != "":
		await _screenshots()
	print("GENE DONE: %d failed" % fails)
	get_tree().quit(1 if fails else 0)

func _catalog_lifecycle() -> void:
	var running := Game.running
	Game.running = false
	for mid in Genetics.DEFS:
		var subject := _subject("Catalog " + mid)
		var dna := _dna(subject)
		var health: CHealth = subject.c(&"health")
		var original_traits := health.traits.duplicate(true)
		var acquired := dna.add_mutation(mid, Genetics.SRC_MUTATOR)
		_check("catalog mutation acquires: " + mid, acquired)
		if mid == "race": dna.process(GeneFx.TRANSFORMATION_DURATION + 0.1)
		if mid != "bad_dna":
			var mutation := dna.get_mutation(mid)
			_check("catalog acquisition grants declared traits: " + mid, mutation != null and Genetics.DEFS[mid].get("traits", []).all(func(tr): return Traits.has(subject, tr)))
		if mid in ["chameleon", "chameleon_changeling"]:
			var doll: PaperDoll = subject.c(&"mob").doll
			var mutation := dna.get_mutation(mid)
			_check("chameleon acquires TG initial transparency: " + mid, is_equal_approx(doll.modulate.a, GeneFx.CHAMELEON_DEFAULT_ALPHA))
			GeneFx.on_life(subject, mutation, 2.0)
			_check("chameleon fades at the source power-scaled rate: " + mid, is_equal_approx(doll.modulate.a, GeneFx.CHAMELEON_DEFAULT_ALPHA - 25.0 / 255.0 * mutation.pwr()))
			GeneFx.on_attack(subject)
			_check("chameleon attack resets transparency: " + mid, is_equal_approx(doll.modulate.a, GeneFx.CHAMELEON_DEFAULT_ALPHA))
		dna.remove_all_mutations()
		if mid in ["chameleon", "chameleon_changeling"]:
			_check("chameleon removal restores visible skin: " + mid, is_equal_approx(subject.c(&"mob").doll.modulate.a, 1.0))
		if mid == "race": dna.process(GeneFx.TRANSFORMATION_DURATION + 0.1)
		_check("catalog removal clears mutations powers and physiology: " + mid, dna.mutations.is_empty() and dna.powers.is_empty() and is_equal_approx(health.burn_mod, 1.0) and is_equal_approx(health.cold_mod, 1.0) and is_equal_approx(health.bleed_mod, 1.0) and is_equal_approx(health.blood_regen_mod, 1.0))
		_check("catalog removal preserves original trait sources: " + mid, health.traits == original_traits)
		subject.destroy()
	Game.running = running

func _completion_mechanics() -> void:
	var running := Game.running
	Game.running = false
	var p := _subject("Viral genetics")
	var dna := _dna(p)
	var h: CHealth = p.c(&"health")
	dna.mutation_index.clear()
	for mid in ["race", "clumsy", "strong", "stimmed", "insulated", "antenna", "geladikinesis", "olfaction"]:
		dna.mutation_index[mid] = Genetics.create_sequence(mid, false)
	var disease := Disease.make_genetic(false, {"resistance": 8, "stealth": 5, "stage_speed": 10})
	h.disease = disease
	disease.stage = 3
	disease.activate_genetics(p)
	_check("dormant DNA disease waits until stage four", dna.mutations.is_empty())
	disease.stage = 4
	disease.activate_genetics(p)
	var mutated := dna.get_mutation("clumsy")
	_check("resistant genetic disease creates unreadable symptom-owned genes", mutated != null and mutated.scrambled and Genetics.SRC_GENE_SYMPTOM in mutated.sources and disease.genetic_timer == 30.0)
	Mutadone.on_life(h)
	_check("mutadone cannot remove resistant viral sources", dna.has_mutation("clumsy"))
	var injector := Proto.spawn("dna_activator", p.cell)
	var inj: CDnaInjector = injector.c(&"dnainjector")
	inj.add_mutations.append(Mutation.make("clumsy"))
	inj._finish(p, p)
	_check("injecting a genetic disease patient collects a CRISPR charge", inj.used and inj.crispr_charge)
	var console := Proto.spawn("dna_console", p.cell, {"comps": {"machine": {"needs_power": false}}})
	console.c(&"dnaconsole").attackby(p, injector)
	_check("recycling the sampled activator transfers its CRISPR charge", console.c(&"dnaconsole").crispr_charges == 1 and injector.removed)
	dna.add_mutation("strong", Genetics.SRC_MUTATOR)
	disease.cure(p)
	_check("viral cure clears symptom and activated sources but preserves mutators", h.disease == null and not dna.has_mutation("clumsy") and dna.has_mutation("strong"))
	dna.remove_all_mutations()
	disease = Disease.make_genetic(false, {"resistance": 14, "stealth": 5})
	disease.stage = 4
	h.disease = disease
	disease.activate_genetics(p)
	disease.cure(p)
	_check("resistance fourteen preserves viral mutations after cure", dna.has_mutation("clumsy"))
	dna.remove_all_mutations([Genetics.SRC_GENE_SYMPTOM])
	var copy := disease.copy()
	copy.symptoms.clear()
	_check("disease copies retain thresholds without sharing symptom arrays", disease.is_genetic() and copy.resistance == 14 and copy.max_stage == 5)
	_check("viral acceleration is also a valid CRISPR sample", Disease.make_genetic(true).is_genetic())
	console.destroy()
	p.destroy()
	p = _subject("Stone limb absorption")
	h = p.c(&"health")
	dna = _dna(p)
	dna.add_mutation("rock_absorber", Genetics.SRC_MUTATOR)
	_check("human absorption starts at thirty seconds", is_equal_approx(RockMetabolism.duration(p), 30.0))
	for part in Body.PARTS: h.body_materials[part] = "stone"
	_check("six stone bodyparts grant five minute mineral absorption", is_equal_approx(RockMetabolism.duration(p), 300.0))
	h.missing["l_arm"] = true
	_check("missing stone limb no longer contributes to duration", is_equal_approx(RockMetabolism.duration(p), 255.0))
	var limb := Proto.spawn("severed_limb", p.cell)
	limb.tags["limb_part"] = "l_arm"
	limb.tags["limb_material"] = "stone"
	Surgery._apply("reattach", h, "l_arm", p, limb)
	_check("reattaching stone limb preserves its material and absorption bonus", not h.missing.has("l_arm") and limb.removed and is_equal_approx(RockMetabolism.duration(p), 300.0))
	var titanium := Proto.spawn("sheet_titanium", p.cell)
	RockMetabolism.consume(p, titanium)
	_check("consuming titanium uses the anatomy-based expiry", is_equal_approx(float(p.get_meta("rock_buff_until")) - Game.time, 300.0))
	var target := _subject("Mining bonus target")
	target.tags["factions"] = ["mining"]
	_check("titanium grants thirty bonus damage against standing mining targets", is_equal_approx(RockMetabolism.mining_bonus(p, target), 30.0))
	target.c(&"health").knockdown(2.0)
	_check("titanium bonus excludes prone targets", is_zero_approx(RockMetabolism.mining_bonus(p, target)))
	target.destroy()
	titanium.destroy()
	dna.remove_all_mutations()
	RockMetabolism.process(p, 0.0)
	dna.add_mutation("limb_regeneration", Genetics.SRC_MUTATOR)
	var regen := dna.get_mutation("limb_regeneration")
	h.missing["r_arm"] = true
	h.sleeping = true
	var n: CNeeds = p.c(&"needs")
	n.nutrition = 55.0
	for attempt in 200:
		if not h.missing.has("r_arm"): break
		GeneFx._limb_regen(p, regen, h, 1.0)
	_check("regeneration accepts TG's fed threshold after station nutrition scaling", not h.missing.has("r_arm") and n.nutrition < 55.0)
	p.destroy()
	p = _subject("Echolocation focus")
	Psyker.transform(p)
	var item := Proto.spawn("wrench", p.cell)
	_check("psyker exposes focus with default item highlighting", not GenePowers.find(p, "echo_focus").is_empty() and Psyker.echo_highlight(p, item))
	Psyker.toggle_echo(p, "Items")
	_check("echo focus can exclude items without disabling echo", not Psyker.echo_highlight(p, item) and Psyker.can_echo(p))
	var content := VBoxContainer.new()
	WindowsDna.build("echo_focus", p, content, null)
	var buttons := content.find_children("*", "Button", true, false)
	_check("echo focus renders all three filter controls", buttons.size() == 3)
	content.free()
	_check("psyker transformation has its own head appearance", p.c(&"mob").doll.psyker_head)
	Psyker.detach(p)
	_check("brain removal clears focus and psychic head appearance", GenePowers.find(p, "echo_focus").is_empty() and not p.c(&"mob").doll.psyker_head)
	item.destroy()
	p.destroy()
	p = _subject("Taunt chip")
	var chip := Proto.spawn("skillchip", p.cell, {"comps": {"skillchip": {"kind": "matrix_taunt"}}})
	SkillChips.implant(p, chip)
	chip.c(&"skillchip").toggle()
	_check("taunt chip gives projectile immunity at nineteen stamina cost", Emotes.emote(p, "taunt", true) and Traits.has(p, "unhittable_projectiles") and is_equal_approx(p.c(&"health").stamina, 81.0))
	chip.c(&"skillchip").toggle(true)
	_check("chip deactivation clears transient projectile immunity", not Traits.has(p, "unhittable_projectiles"))
	chip.destroy()
	p.destroy()
	_scent_flow()
	Game.running = running

func _scent_flow() -> void:
	var previous_player := Game.player
	var user := _subject("Scent tracker")
	var first := _subject("First scent")
	var second := _subject("Second scent")
	Game.player = user
	var dna := _dna(user)
	dna.add_mutation("olfaction", Genetics.SRC_MUTATOR)
	dna.add_mutation("mindreader", Genetics.SRC_MUTATOR)
	Traits.add(user, "antimagic", "test")
	var power := GenePowers.find(user, "olfaction")
	_check("antimagic permits the physical sense of smell", GenePowers.can_cast(user, power, false))
	_check("antimagic still blocks mind reading", not GenePowers.can_cast(user, GenePowers.find(user, "mindread"), false))
	var inv: CInventory = user.c(&"inv")
	for held in inv.hands.duplicate():
		if held: inv.drop(held)
	var item := Proto.spawn("wrench", user.cell)
	inv.put_in_hands(item)
	Forensics.touch(item, first, true)
	Forensics.touch(item, second, true)
	GenePowers.trigger(user, "olfaction")
	var content := VBoxContainer.new()
	WindowsDna.build("gene_scent", item, content, null)
	var buttons := content.find_children("*", "Button", true, false)
	_check("multi-scent prompt contains both available people", buttons.size() == 2 and power["data"].get("choices", []).size() == 2)
	if not buttons.is_empty(): buttons[0].pressed.emit()
	_check("scent selection works during the sniff cooldown", power["data"].get("tracking") == first and power["data"].get("choices", []).is_empty() and not GenePowers.ready(power))
	GenePowers.pick_scent(user, second)
	_check("resolved scent choices cannot change tracking again", power["data"].get("tracking") == first)
	content.free()
	for window in Game.hud.windows.get_children():
		if window is UIWindow and window.kind == "gene_scent": window.queue_free()
	Game.player = previous_player
	for entity in [user, first, second, item]: entity.destroy()

# ------------------------------------------------------------------ helpers
func _body_systems() -> void:
	var p := _subject("Mineral metabolism")
	var d := _dna(p)
	var h: CHealth = p.c(&"health")
	d.add_mutation("rock_absorber", Genetics.SRC_MUTATOR)
	var plasma := Proto.spawn("sheet_plasma", p.cell)
	var amount: int = plasma.c(&"stack").amount
	_check("mineral feeding consumes exactly one sheet", RockMetabolism.consume(p, plasma) and plasma.c(&"stack").amount == amount - 1)
	_check("absorbed plasma grants temporary heat and pressure resistance", Traits.has(p, "resistheat") and Traits.has(p, "resisthighpressure") and is_equal_approx(h.burn_mod, 0.05))
	h.adjust("burn", 20.0)
	_check("plasma absorption reduces burn damage to five percent", is_equal_approx(h.burn, 1.0))
	var titanium := Proto.spawn("sheet_titanium", p.cell)
	amount = titanium.c(&"stack").amount
	RockMetabolism.consume(p, titanium)
	_check("different mineral buffs cannot overwrite active absorption", titanium.c(&"stack").amount == amount and p.get_meta("rock_buff") == "plasma")
	p.set_meta("rock_buff_until", Game.time)
	RockMetabolism.process(p, 0.0)
	_check("mineral expiry clears traits and restores damage coefficients", not Traits.has(p, "resistheat") and is_equal_approx(h.burn_mod, 1.0))
	RockMetabolism.consume(p, titanium)
	_check("titanium absorption reduces brute damage", is_equal_approx(h.brute_mod, 0.8))
	d.remove_all_mutations()
	RockMetabolism.process(p, 0.0)
	_check("mutation loss clears mineral buffs", not p.has_meta("rock_buff") and is_equal_approx(h.brute_mod, 1.0))
	plasma.destroy()
	titanium.destroy()
	p.destroy()
	p = _subject("Skillchip capacity")
	d = _dna(p)
	var chips := []
	for kind in ["self_surgery", "entrails_reader", "musical", "useless_adapter"]:
		# A weighted fixture exercises admission of a fourth complexity unit.
		var chip := Proto.spawn("skillchip", p.cell, {"comps": {"skillchip": {"kind": kind, "complexity": 1, "slots": 1}}})
		_check("skillchip implants into brain: " + kind, SkillChips.implant(p, chip) == "")
		chips.append(chip)
	for i in 3:
		_check("skillchip activates within baseline capacity", chips[i].c(&"skillchip").toggle() == "")
	_check("three active complexity blocks a fourth skillchip", chips[3].c(&"skillchip").toggle() != "")
	d.add_mutation("biotechcompat", Genetics.SRC_MUTATOR)
	_check("Biotech Compatibility grants one active complexity", SkillChips.capacity(p) == 4 and chips[3].c(&"skillchip").toggle() == "")
	_check("activated chips grant their actual traits", Traits.has(p, "self_surgery") and Traits.has(p, "entrails_reader") and Traits.has(p, "musical_chip"))
	_check("skillchip activation enforces five minute recharge", chips[0].c(&"skillchip").toggle() != "" and SkillChips.remove(p, chips[0]) != "")
	d.remove_all_mutations()
	SkillChips.update(p)
	_check("capacity loss forces excess chip off even during recharge", SkillChips.used_complexity(p) == 3 and not chips[0].c(&"skillchip").active and not Traits.has(p, "self_surgery"))
	d.add_mutation("biotechcompat", Genetics.SRC_MUTATOR)
	SkillChips.update(p)
	_check("restoring capacity does not reactivate chips automatically", SkillChips.used_complexity(p) == 3 and not chips[0].c(&"skillchip").active)
	var brain := Organs.remove(p.c(&"health"), "brain", p.cell)
	_check("brain extraction carries all skillchips and removes active traits", SkillChips.list_of(p).is_empty() and brain.get_meta("skillchips").size() == 4 and not Traits.has(p, "entrails_reader"))
	_check("reinserted brain restores inactive chips", Organs.insert(p.c(&"health"), "brain", brain) and SkillChips.list_of(p).size() == 4 and SkillChips.used_complexity(p) == 0)
	for chip in chips: chip.destroy()
	var adapter := Proto.spawn("skillchip", p.cell, {"comps": {"skillchip": {"kind": "useless_adapter"}}})
	_check("TG useless adapters consume zero slots and zero complexity", adapter.c(&"skillchip").complexity == 0 and adapter.c(&"skillchip").slot_use == 0)
	adapter.destroy()
	p.destroy()
	p = _subject("Skillsoft patient")
	var station := Proto.spawn("skill_station", p.cell, {"comps": {"machine": {"needs_power": false}}})
	var st: CSkillStation = station.c(&"skillstation")
	var chip := Proto.spawn("skillchip", p.cell)
	st.attackby(p, chip)
	_check("skillsoft station loads a physical chip", st.loaded == chip and chip.holder == station)
	_check("skillsoft enclosure accepts its patient", st.close_machine(p))
	_check("skillsoft operation begins for occupant", st.act(p, "implant"))
	st.tick(1.0)
	_check("skillsoft operation does not implant immediately", SkillChips.list_of(p).is_empty() and st.working == "implant")
	st.open_machine()
	_check("opening skillsoft cancels implantation without losing chip", st.working == "" and st.loaded == chip and SkillChips.list_of(p).is_empty())
	st.close_machine(p)
	st.act(p, "implant")
	st.finish_at = Game.time
	st.tick(1.0)
	_check("skillsoft completion implants and clears the loaded slot", SkillChips.list_of(p).has(chip) and st.loaded == null and st.working == "")
	_check("skillsoft occupant can activate implanted chip", st.act(p, "toggle", chip) and Traits.has(p, "self_surgery"))
	st.open_machine()
	_check("skillsoft rejects controls outside the closed station", not st.act(p, "toggle", chip))
	station.destroy()
	chip.destroy()
	p.destroy()
	p = _subject("Petrification survivor")
	GeneFx.petrify(p)
	var statue: Entity = Game.get_entity(p.get_meta("inside"))
	_check("petrification encloses the original living body", statue.has_c(&"statue") and not p.c(&"health").dead and Traits.has(p, "godmode") and not p.c(&"health").can_use_hands())
	statue.c(&"statue").take_damage(10.0, "brute", null)
	statue.c(&"statue").process(480.0)
	_check("statue expiry releases the body with transferred damage", not p.has_meta("inside") and not Traits.has(p, "godmode") and is_equal_approx(p.c(&"health").brute, 10.0) and p.c(&"health").has_status("paralyzed"))
	p.destroy()
	for kind in ["corgi", "crab", "gorilla"]:
		p = _subject("Transformation " + kind)
		var id := p.id
		GeneFx.animalize(p, kind)
		_check("animal transformation preserves living identity: " + kind, p.id == id and not p.removed and not p.c(&"health").dead and Species.of(p) == kind and p.visible)
		_check("animal body has renderer and cannot use human tools: " + kind, p.c(&"mob").doll.animal_kind == kind and not p.c(&"health").can_use_hands() and p.has_c(&"animalai"))
		p.destroy()
	p = _subject("Psychic brain")
	_check("psyker transformation requires a living brain and head", Psyker.transform(p))
	_check("psyker has blindness, echo and three brain-linked powers", p.c(&"health").eyes_removed and Psyker.can_echo(p) and Psyker.POWERS.all(func(id): return not GenePowers.find(p, id).is_empty()))
	Traits.add(p, "deaf", "test")
	_check("deafness disables echolocation", not Psyker.can_echo(p))
	Traits.remove_source(p, "test")
	var victim := _subject("Psychic projection victim")
	_check("psychic projection applies ten seconds of actual status", Psyker.project(p, victim) and victim.c(&"health").status_left("psychic_projection") == 10.0)
	_check("psychic projection cannot stack on an affected target", not Psyker.project(p, victim))
	victim.c(&"health").remove_status("psychic_projection")
	Traits.add(victim, "mind_antimagic", "test")
	_check("psychic projection respects mind antimagic", not Psyker.project(p, victim))
	victim.destroy()
	var walls_before := Game.all_with(&"psychicwall").size()
	Psyker.wall(p)
	var walls: Array = Game.all_with(&"psychicwall").filter(func(wall): return wall.tags.get("owner", 0) == p.id)
	_check("psychic wall creates real blocking entities", Game.all_with(&"psychicwall").size() > walls_before and walls.all(func(wall): return wall.c(&"blocker").dense))
	for wall in walls: wall.destroy()
	brain = Organs.remove(p.c(&"health"), "brain", p.cell)
	_check("psyker brain extraction removes echo and all brain powers", brain.tags.get("variant", "") == "psyker" and not Traits.has(p, "psyker") and Psyker.POWERS.all(func(id): return GenePowers.find(p, id).is_empty()))
	brain.destroy()
	p.destroy()
	await get_tree().process_frame

func _tutorial() -> void:
	var con := _stage()
	var damage := con.occ_dna().genetic_damage
	var genes := con.occ_dna().mutation_index.duplicate()
	con.view["tutorialPage"] = 1
	con.view.erase("practiceSequence")
	var body := VBoxContainer.new()
	WindowsDna.build("dna_tutorial", con.e, body, null)
	var bases := body.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("ui_live_gene", false))
	_check("practice uses four visible vertical pairs", bases.size() == 8)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	for n in 2:
		bases[1].gui_input.emit(click)
	for n in 3:
		bases[2].gui_input.emit(click)
	_check("practice real controls repair single missing letters", con.view["practiceSequence"] == "ATCGXXCG")
	click.button_index = MOUSE_BUTTON_RIGHT
	bases[1].gui_input.emit(click)
	_check("practice right click cycles backward", con.view["practiceSequence"][1] == "A")
	click.button_index = MOUSE_BUTTON_LEFT
	click.ctrl_pressed = true
	bases[1].gui_input.emit(click)
	_check("practice ctrl click clears to X", con.view["practiceSequence"][1] == "X")
	body.free()
	con.view["practiceSequence"] = "ATCGXXCG"
	con.view["tutorialPage"] = 2
	body = VBoxContainer.new()
	WindowsDna.build("dna_tutorial", con.e, body, null)
	var guesses := body.find_children("*", "Button", true, false)
	guesses.filter(func(b): return b.text == "AT")[0].pressed.emit()
	_check("a complementary practice guess does not mean activation", con.view["practiceSequence"] == "ATCGATCG" and con.view["practiceSequence"] != WindowsDna.PRACTICE_SOLUTION)
	body.free()
	body = VBoxContainer.new()
	WindowsDna.build("dna_tutorial", con.e, body, null)
	var feedback := body.find_children("*", "Label", true, false).any(func(l): return "pairs fit, but a guess is wrong" in l.text)
	_check("practice explains fitting pairs versus correct code", feedback)
	body.find_children("*", "Button", true, false).filter(func(b): return b.text == "TA")[0].pressed.emit()
	_check("correct full practice code activates the example", con.view["practiceSequence"] == WindowsDna.PRACTICE_SOLUTION)
	body.free()
	body = VBoxContainer.new()
	WindowsDna.build("dna_tutorial", con.e, body, null)
	_check("practice visibly confirms success", body.find_children("*", "Label", true, false).any(func(l): return "ON - you solved" in l.text))
	body.find_children("*", "Button", true, false).filter(func(b): return b.text == "Reset practice")[0].pressed.emit()
	_check("practice can be reset independently", con.view["practiceSequence"] == WindowsDna.PRACTICE_START)
	_check("the complete lesson causes no DNA edits or genetic damage", con.occ_dna().genetic_damage == damage and con.occ_dna().mutation_index == genes)
	body.free()
	con.view["tutorialPage"] = 0

func _expanded() -> void:
	var p := _subject("Extended mutation operator")
	var d := _dna(p)
	var inv: CInventory = p.c(&"inv")
	for item in inv.hands.duplicate():
		if item: inv.drop(item)
	var cell := p.cell
	for candidate in _cells():
		if range(1, 5).all(func(offset): return Game.map.is_passable(candidate + Vector2i(offset, 0)) and Game.at_with(candidate + Vector2i(offset, 0), &"health").is_empty()):
			cell = candidate
			break
	p.place(cell)
	var wrench := Proto.spawn("wrench", cell + Vector2i(2, 0))
	_check("ordinary hands cannot pick up a tool two tiles away", not Interact.pickup(p, wrench))
	d.add_mutation("elastic_arms", Genetics.SRC_MUTATOR)
	_check("elastic arms reach and pick up tools two tiles away", Genetics.can_reach(p, wrench) and Interact.pickup(p, wrench))
	inv.drop(wrench)
	wrench.place(cell + Vector2i(3, 0))
	_check("elastic reach stops beyond two tiles", not Genetics.can_reach(p, wrench))
	d.remove_all_mutations()
	d.add_mutation("telekinesis", Genetics.SRC_MUTATOR)
	_check("telekinesis can focus a distant loose tool", GeneInteraction.click(p, wrench, wrench.cell, {}))
	var grab := inv.active_item()
	_check("telekinesis creates a hand proxy without picking up its focus", grab != null and grab.has_c(&"tkgrab") and wrench.holder == null and Traits.has(wrench, "telekinesis_controlled"))
	var bag := Proto.spawn("backpack", cell)
	_check("telekinetic proxies cannot be stored or equipped", not bag.c(&"storage").can_insert(grab) and not inv.can_equip(grab, "pocket_l"))
	inv.drop(grab)
	_check("dropping telekinetic grip releases focus and clears hand", inv.active_item() == null and not Traits.has(wrench, "telekinesis_controlled") and d.tk_grab == null)
	GeneInteraction.click(p, wrench, wrench.cell, {})
	d.remove_all_mutations()
	GeneInteraction.validate(p)
	_check("losing telekinesis immediately invalidates a remote grip", inv.active_item() == null and not Traits.has(wrench, "telekinesis_controlled"))
	var scanner := Proto.spawn("dna_scanner", cell + Vector2i.RIGHT, {"comps": {"machine": {"needs_power": false}}})
	var sc: CDnaScanner = scanner.c(&"dnascanner")
	var screwdriver := Proto.spawn("screwdriver", cell)
	sc.attackby(p, screwdriver)
	_check("scanner maintenance disables operation", sc.panel_open and not sc.operational())
	for kind in ["micro_laser", "matter_bin", "scanning_module"]:
		var part := CStockPart.spawn_part(kind, 4, cell)
		sc.attackby(p, part)
		_check("scanner installs tier 4 %s and consumes replacement" % kind, sc.parts[kind] == 4 and part.removed)
	var downgrade := CStockPart.spawn_part("matter_bin", 2, cell)
	sc.attackby(p, downgrade)
	_check("scanner rejects downgrades without consuming the part", sc.parts["matter_bin"] == 4 and not downgrade.removed)
	sc.attackby(p, screwdriver)
	_check("closing maintenance activates all upgraded coefficients", sc.operational() and sc.damage_coeff == 4.0 and sc.precision_coeff == 4.0 and sc.scan_level == 4)
	var con_entity := Proto.spawn("dna_console", cell, {"comps": {"machine": {"needs_power": false}}})
	var con: CDnaConsole = con_entity.c(&"dnaconsole")
	con.set_connected_scanner(scanner)
	sc.close_machine(p)
	Traits.add(p, "baddna", "test")
	_check("a tier 4 module permits the same bad DNA work as tier 3", con.can_modify_occupant())
	Traits.remove(p, "baddna", "test")
	sc.open_machine()
	var lathe := Proto.spawn("protolathe", cell, {"comps": {"machine": {"needs_power": false}}})
	lathe.c(&"lathe")._spawn_output(Research.DESIGNS["scanner_module_t3"])
	var printed := Game.at(lathe.c(&"lathe")._out_cell()).filter(func(it): return it.has_c(&"stockpart") and it.c(&"stockpart").kind == "scanning_module" and it.c(&"stockpart").tier == 3)
	_check("research fabrication preserves specific stock part type and tier", not printed.is_empty())
	scanner.destroy()
	con_entity.destroy()
	lathe.destroy()
	p.place(cell)
	var victim := _subject("Laser eyes target")
	victim.place(cell + Vector2i(4, 0))
	d.add_mutation("laser_eyes", Genetics.SRC_MUTATOR)
	p.c(&"mob").combat = true
	var h: CHealth = victim.c(&"health")
	var burn := h.burn
	GeneInteraction.click(p, victim, victim.cell, {})
	_check("combat laser eyes fire a damaging ranged beam", h.burn > burn)
	var after := h.burn
	GeneInteraction.click(p, victim, victim.cell, {})
	_check("laser eyes respect their firing cooldown", h.burn == after)
	d.remove_all_mutations()
	var pl := Game.player
	var player_dna := _dna(pl)
	var origin := pl.cell
	var lighting: LightingSystem = Game.lighting
	lighting.compute_fov(origin)
	var hidden := Vector2i(-1, -1)
	for y in range(origin.y - 8, origin.y + 9):
		for x in range(origin.x - 8, origin.x + 9):
			var c := Vector2i(x, y)
			if Game.map.inb(c) and not lighting.player_can_see(c): hidden = c
	_check("vision test has a tile occluded by station walls", hidden.x >= 0)
	player_dna.add_mutation("xray", Genetics.SRC_MUTATOR)
	lighting.compute_fov(origin)
	_check("X-ray mutation reveals occluded tiles", hidden.x >= 0 and lighting.player_can_see(hidden))
	player_dna.remove_mutation("xray", Genetics.SRC_MUTATOR)
	lighting.compute_fov(origin)
	_check("removing X-ray restores wall occlusion", hidden.x >= 0 and not lighting.player_can_see(hidden))
	wrench.destroy()
	bag.destroy()

func _cells() -> Array:
	var a: Area = Game.world.get_parent().mapgen.room_of("cafeteria")["area"]
	var out := []
	for c in a.cells:
		if Game.map.is_passable(c) and Game.at(c).is_empty():
			out.append(c)
	return out

var _used := 0
func _subject(nm: String) -> Entity:
	var cs := _cells()
	var c: Vector2i = cs[_used % cs.size()]
	_used += 3
	var d := Crew.spawn_human("assistant", c, {"name": nm})
	d.remove_comp(&"brain")
	Quirks.remove_all(d)
	return d

func _dna(e: Entity) -> CDna:
	return e.c(&"dna")

func _wait(seconds: float) -> void:
	var until := Game.time + seconds
	while Game.time < until:
		await get_tree().process_frame

func _check(what: String, ok: bool) -> void:
	print("GENE %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1

# ------------------------------------------------------------------ the DNA datum
func _workflow() -> void:
	var running := Game.running
	Game.running = false
	var p := _subject("Workflow operator")
	var target := _subject("Workflow patient")
	var console := Proto.spawn("dna_console", p.cell, {"comps": {"machine": {"needs_power": false}}})
	var pod := Proto.spawn("dna_scanner", p.cell + Vector2i.RIGHT, {"comps": {"machine": {"needs_power": false}}})
	var con: CDnaConsole = console.c(&"dnaconsole")
	var sc: CDnaScanner = pod.c(&"dnascanner")
	con.set_connected_scanner(pod)
	target.place(p.cell)
	p.c(&"mob").pulling = target
	target.c(&"mob").pulled_by = p
	var dst := {"kind": "world", "cell": pod.cell, "ents": [pod]}
	_check("drag preview accepts a pulled patient on an open scanner", DragDrop.apply(p, target, dst, true) and sc.state_open)
	_check("dragging inserts the selected patient", DragDrop.apply(p, target, dst, false) and sc.occupant == target and target.has_meta("inside"))
	_check("inserting stops the pull", p.c(&"mob").pulling == null)
	p.c(&"mob").start_pulling(target)
	_check("closed scanner occupant cannot be pulled again", p.c(&"mob").pulling == null and target.c(&"mob").pulled_by == null)
	_check("closed scanner occupant is not a world click target", target not in PlayerController.entities_at(pod.cell))
	var enclosed_cell := target.cell
	target.c(&"mob")._begin_move(p.cell, false)
	_check("forced pull movement cannot move a scanner occupant", target.cell == enclosed_cell and sc.occupant == target)
	var dn := _dna(target)
	con.view["consoleMode"] = "sequencer"
	con.view["sequencerMutation"] = "missing alias"
	var body := VBoxContainer.new()
	WindowsDna.build("dna_console", console, body, null)
	_check("sequencer falls back from a stale selection", con.view["sequencerMutation"] != "missing alias")
	body.free()
	var gene: String = dn.mutation_index.keys().filter(func(k): return k != "race")[0]
	var pos: int = dn.mutation_index[gene].find("X")
	var act := func(action: String, params: Dictionary): return con.act(action, params, p)
	var button := WindowsDna._gene_btn("X", pos, Genetics.alias(gene), false, false, act)
	add_child(button)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	button.gui_input.emit(click)
	_check("gene button left click cycles forward", dn.mutation_index[gene][pos] == "A")
	click.button_index = MOUSE_BUTTON_RIGHT
	button.gui_input.emit(click)
	_check("gene button right click cycles backward", dn.mutation_index[gene][pos] == "G")
	click.button_index = MOUSE_BUTTON_LEFT
	click.ctrl_pressed = true
	button.gui_input.emit(click)
	_check("gene button ctrl click clears the base", dn.mutation_index[gene][pos] == "X")
	click.button_index = MOUSE_BUTTON_WHEEL_UP
	var damage := dn.genetic_damage
	button.gui_input.emit(click)
	_check("ctrl scrolling over a gene cannot edit DNA", dn.genetic_damage == damage)
	button.queue_free()
	var m1 := Mutation.make("strong")
	var m2 := Mutation.make("strong")
	var panel1 := VBoxContainer.new()
	var panel2 := VBoxContainer.new()
	WindowsDna._mutation_info(con, con.data(p), panel1, act, WindowsDna._stored_info(con, m1, "console"))
	WindowsDna._mutation_info(con, con.data(p), panel2, act, WindowsDna._stored_info(con, m2, "console"))
	_check("identical-looking mutation copies refresh their button references", UIWindow._signature(panel1) != UIWindow._signature(panel2))
	var stored_genes := panel1.find_children("*", "Button", true, false).filter(func(b): return b.text.length() == 1 and b.text in "ATCG")
	_check("stored mutations expose all 32 bases for reference without editing", stored_genes.size() == 32 and stored_genes.all(func(b): return b.disabled))
	panel1.free()
	panel2.free()
	con.scramble_ready = Game.time
	con.injector_ready = Game.time
	con.joker_ready = Game.time
	var data := con.data(p)
	_check("cooldown flags become ready exactly at expiry", data["isScrambleReady"] and data["isInjectorReady"] and data["isJokerReady"])
	con.injector_ready = Game.time - 60
	_check("expired cooldowns never show negative seconds", con.data(p)["injectorSeconds"] == 0)
	var original := dn.unique_identity
	_check("identity pulse starts", con.act("makeup_pulse", {"type": "ui", "index": 1}, p))
	_check("a second pulse cannot replace one in progress", not con.act("makeup_pulse", {"type": "uf", "index": 2}, p) and con.pulse_type == "ui" and con.pulse_index == 1)
	con.genetic_damage_pulse()
	_check("identity pulse completes and changes one hex digit", dn.unique_identity != original and con.pulse_index == 0)
	_check("invalid pulse types and positions are rejected", not con.act("makeup_pulse", {"type": "bogus", "index": 1}, p) and not con.act("makeup_pulse", {"type": "ui", "index": 0}, p))
	con.act("makeup_pulse", {"type": "ui", "index": 1}, p)
	sc.open_machine()
	_check("opening scanner cancels the pulse and restores the patient", con.pulse_index == 0 and not target.has_meta("inside") and target.c(&"mob").doll.visible)
	_check("scanner cannot fetch a distant patient", not sc.put_in(p, _subject("Distant patient")))
	# Explicit insertion must take the target, even if another mob is on the tile.
	var bystander := _subject("Scanner bystander")
	bystander.place(pod.cell)
	sc.close_machine(target)
	_check("explicit scanner target takes priority over a bystander", sc.occupant == target)
	con.act("makeup_pulse", {"type": "ui", "index": 1}, p)
	var before := _dna(bystander).unique_identity
	sc.occupant = bystander
	con.genetic_damage_pulse()
	_check("a pending pulse cannot mutate a replacement subject", _dna(bystander).unique_identity == before and con.pulse_index == 0)
	sc.occupant = target
	con.act("save_makeup_console", {"index": 1}, p)
	con.enzyme_copy_ready = Game.time + 30
	body = VBoxContainer.new()
	con.view["consoleMode"] = "enzymes"
	WindowsDna.build("dna_console", console, body, null)
	var buttons := body.find_children("*", "Button", true, false)
	_check("makeup print and transfer controls reflect the cooldown", buttons.filter(func(b): return b.text in ["Print", "Transfer"]).all(func(b): return b.disabled))
	body.free()
	con.enzyme_copy_ready = Game.time
	con.injector_ready = Game.time
	_check("makeup injector prints when both cooldowns are ready", con.act("makeup_injector", {"index": 1, "type": "ui"}, p))
	_check("TG makeup printing uses the enzyme copy guard", con.act("makeup_injector", {"index": 1, "type": "ui"}, p))
	con.enzyme_copy_ready = Game.time
	_check("invalid makeup transfer reports failure", not con.act("makeup_apply", {"index": 1, "type": "invalid"}, p))
	con.act("new_adv_inj", {"name": "Workflow"}, p)
	con.injector_ready = Game.time
	_check("empty advanced injectors cannot be printed", not con.act("print_adv_inj", {"name": "Workflow"}, p))
	var stored := Mutation.make("strong")
	stored.instability = 60
	stored.stabilizer_coeff = 0.8
	con.stored_mutations.append(stored)
	_check("TG admits new advanced mutations at raw instability", not con.act("add_advinj_mut", {"advinj": "Workflow", "source": "console", "mutref": stored.uid}, p))
	stored.instability = 40
	_check("an admissible advanced mutation is copied", con.act("add_advinj_mut", {"advinj": "Workflow", "source": "console", "mutref": stored.uid}, p))
	_check("advanced injector rejects duplicate mutations", not con.act("add_advinj_mut", {"advinj": "Workflow", "source": "console", "mutref": stored.uid}, p) and con.injector_selection["Workflow"].size() == 1)
	# Use the actual CRISPR form and submit button, not a direct act call.
	var mid: String = dn.mutation_index.keys().filter(func(k): return k != "race")[0]
	dn.activate_mutation(mid)
	Genetics.discovered[mid] = true
	var mut := dn.get_mutation(mid)
	con.crispr_charges = 1
	con.view["consoleMode"] = "sequencer"
	con.view["sequencerMutation"] = Genetics.alias(mid)
	con.view["crisprMutationRef"] = mut.uid
	con.view["crisprSequence"] = ""
	body = VBoxContainer.new()
	WindowsDna.build("dna_console", console, body, null)
	var input := body.find_child("CrisprSequence", true, false) as LineEdit
	var apply: Button = null
	for b in body.find_children("*", "Button", true, false):
		if b.text == "Apply replacement":
			apply = b
	_check("CRISPR opens a sequence editor with validation", input != null and apply != null and apply.disabled)
	if input and apply:
		input.text = "X".repeat(32)
		input.text_changed.emit(input.text)
		_check("CRISPR rejects invalid bases before submission", apply.disabled)
		var code := ""
		for i in range(0, 32, 2):
			code += Genetics.sequence(mid)[i] + Genetics.sequence("strong")[i]
		input.text = code.to_lower()
		input.text_changed.emit(input.text)
		_check("CRISPR accepts a valid lowercase code", not apply.disabled)
		apply.pressed.emit()
		_check("CRISPR submit rewrites the selected gene and spends one charge", dn.mutation_index.has("strong") and dn.has_mutation("strong") and con.crispr_charges == 0)
	body.free()
	var code := "A".repeat(32)
	con.crispr_charges = 1
	_check("stale CRISPR references cannot spend charges", not con.act("crispr", {"source": "occupant", "mutref": -1, "sequence": code}, p) and con.crispr_charges == 1)
	var disk := Proto.spawn("dna_disk", p.cell)
	p.c(&"inv").put_in_hands(disk)
	con.attackby(p, disk)
	console.destroy()
	_check("destroying console releases its disk and disconnects scanner", disk.holder == null and sc.linked_console == null)
	sc.locked = false
	sc.open_machine()
	var enclosed_monkey := Monkeys.spawn_monkey(p.cell)
	p.c(&"mob").start_pulling(enclosed_monkey)
	_check("dragging a monkey closes it inside the genetics pod", DragDrop.apply(p, enclosed_monkey, dst, false) and sc.occupant == enclosed_monkey)
	sc.locked = true
	p.c(&"mob").start_pulling(enclosed_monkey)
	_check("a closed genetics pod cannot have its monkey pulled out", p.c(&"mob").pulling == null and enclosed_monkey.cell == pod.cell and enclosed_monkey.has_meta("inside"))
	sc.locked = false
	sc.open_machine()
	enclosed_monkey.destroy()
	sc.close_machine(target)
	pod.destroy()
	_check("destroying scanner restores visible, movable occupant", not target.has_meta("inside") and target.c(&"mob").doll.visible)
	for e in [p, target, bystander, disk]:
		if is_instance_valid(e) and not e.removed:
			e.destroy()
	Game.running = running
	await get_tree().process_frame

func _tg_parity() -> void:
	var running := Game.running
	Game.running = false
	var p := _subject("TG parity operator")
	var patient := _subject("TG parity patient")
	var console := Proto.spawn("dna_console", p.cell, {"comps": {"machine": {"needs_power": false}}})
	var pod := Proto.spawn("dna_scanner", p.cell + Vector2i.RIGHT, {"comps": {"machine": {"needs_power": false}}})
	var con: CDnaConsole = console.c(&"dnaconsole")
	var sc: CDnaScanner = pod.c(&"dnascanner")
	con.set_connected_scanner(pod)
	patient.place(pod.cell)
	sc.close_machine(patient)
	sc.locked = true
	var dn := _dna(patient)
	dn.activate_mutation("race")
	dn.process(2.3)
	_check("monkeyizing inside a scanner keeps the body concealed", Genetics.is_monkey(patient) and not patient.c(&"mob").doll.visible)
	_check("monkeyizing preserves scanner occupancy and lock", sc.occupant == patient and patient.has_meta("inside") and sc.locked and not sc.state_open)
	dn.add_mutation("strong", "external_test")
	var ui := dn.unique_identity
	var ue := dn.unique_enzymes
	var damage := dn.genetic_damage
	con.scramble_ready = Game.time
	_check("TG scramble succeeds on a living monkey", con.act("scramble_dna", {}, p))
	_check("scramble starts the human transformation without releasing the subject", dn.transforming() and sc.occupant == patient and not sc.state_open)
	dn.process(2.3)
	_check("scramble removes Monkified and restores the original human", dn.species == "human" and not dn.has_mutation("race") and patient.display_name == "TG parity patient")
	_check("humanizing in the scanner stays concealed and locked", not patient.c(&"mob").doll.visible and patient.has_meta("inside") and sc.locked)
	_check("scramble rerolls eight genes while retaining identity and enzymes", dn.mutation_index.size() == 8 and dn.unique_identity == ui and dn.unique_enzymes == ue)
	_check("scramble preserves mutations from nonstandard sources", dn.has_mutation("strong"))
	_check("scramble adds 50 genetic damage and a 60 second cooldown", is_equal_approx(dn.genetic_damage - damage, 50.0) and is_equal_approx(con.scramble_ready - Game.time, 60.0))
	_check("scramble cannot be repeated during cooldown", not con.act("scramble_dna", {}, p))
	patient.c(&"mob").refresh_doll()
	_check("appearance refresh cannot expose an enclosed subject", not patient.c(&"mob").doll.visible)
	sc.locked = false
	sc.open_machine()
	_check("opening the scanner explicitly restores visibility", not patient.has_meta("inside") and patient.c(&"mob").doll.visible)
	# A born monkey also humanizes, but keeps its original primate brain (TG).
	var monkey := Monkeys.spawn_monkey(pod.cell)
	sc.close_machine(monkey)
	Genetics.discovered.erase("race")
	var commands := VBoxContainer.new()
	var action := func(a: String, args := {}): return con.act(a, args, p)
	WindowsDna._commands(con, con.data(p), commands, action)
	for b in commands.find_children("*", "Button", true, false):
		if b.text == "Sequencer":
			b.pressed.emit()
	_check("opening Sequencer discovers a monkey's active Monkified gene", Genetics.discovered.has("race"))
	commands.free()
	con.view["sequencerMutation"] = "stale"
	commands = VBoxContainer.new()
	WindowsDna._sequencer(con, con.data(p), commands, action)
	_check("a monkey defaults to its editable Monkified sequence", con.view["sequencerMutation"] == Genetics.alias("race"))
	commands.free()
	con.scramble_ready = Game.time
	con.act("scramble_dna", {}, p)
	_dna(monkey).process(2.3)
	_check("scramble humanizes a born monkey without ejecting it", not Genetics.is_monkey(monkey) and sc.occupant == monkey and monkey.has_meta("inside") and not monkey.c(&"mob").doll.visible)
	_check("humanized born monkeys retain their primate brain", not Species.advanced_tool_user(monkey))
	sc.open_machine()
	var dead_monkey := Monkeys.spawn_monkey(pod.cell)
	dead_monkey.c(&"health").dead = true
	sc.close_machine(dead_monkey)
	con.scramble_ready = Game.time
	con.act("scramble_dna", {}, p)
	_dna(dead_monkey).process(2.3)
	_check("TG scramble does not humanize a dead monkey", Genetics.is_monkey(dead_monkey) and not _dna(dead_monkey).transforming())
	sc.open_machine()
	sc.close_machine(patient)
	dn.genetic_damage = 0.0
	var mid: String = dn.mutation_index.keys().filter(func(k): return k != "race" and dn.get_mutation(k) == null)[0]
	_check("single-dose fixture selects an editable gene", con.act("pulse_gene", {"alias": Genetics.alias(mid), "pos": 1, "pulseAction": CDnaConsole.NEXT_GENE}, p))
	_check("a gene edit adds exactly one damage at baseline upgrades (damage %s, occupied %s, open %s, dead %s)" % [dn.genetic_damage, sc.occupant == patient, sc.state_open, patient.c(&"health").dead], is_equal_approx(dn.genetic_damage, 1.0))
	_check("the console exposes a single edit as 0.2 percent", is_equal_approx(con.data(p)["subjectDamage"], 0.2))
	var body := VBoxContainer.new()
	con.view["consoleMode"] = "enzymes"
	WindowsDna.build("dna_console", console, body, null)
	var bar := body.find_child("GeneticDamageBar", true, false) as TGUI.Bar
	_check("the damage bar does not round a small gene dose to zero", bar != null and bar.text == "0.2%" and bar.frac > 0)
	add_child(body)
	await get_tree().process_frame
	var idle_height := body.get_combined_minimum_size().y
	var before := dn.genetic_damage
	con.act("makeup_pulse", {"type": "ui", "index": 1}, p)
	_check("running pulses reject emitter setting changes", not con.act("set_pulse_strength", {"val": 10}, p) and not con.act("set_pulse_duration", {"val": 10}, p))
	var active_body := VBoxContainer.new()
	WindowsDna.build("dna_console", console, active_body, null)
	add_child(active_body)
	await get_tree().process_frame
	_check("pulse activation preserves the UI minimum height", is_equal_approx(idle_height, active_body.get_combined_minimum_size().y))
	var progress := active_body.find_child("PulseProgress", true, false) as TGUI.Bar
	_check("pulse status occupies the existing emitter row", progress != null and progress.text.contains("Identity #01"))
	con.genetic_damage_pulse()
	_check("TG identity pulses edit makeup without adding genetic damage", is_equal_approx(dn.genetic_damage, before))
	var h: CHealth = patient.c(&"health")
	var tox := h.tox
	dn.genetic_damage = 499.0
	dn._gd_tick = 2.0
	dn.tick(2.0)
	_check("genetic damage below 100 percent does not poison", is_equal_approx(h.tox, tox))
	dn.genetic_damage = 500.0
	dn._gd_tick = 2.0
	dn.tick(2.0)
	_check("100 percent genetic damage causes toxin damage", is_equal_approx(h.tox - tox, CDna.GD_TOX_PER_SECOND * 2.0))
	_check("genetic damage naturally decays on its two second tick", is_equal_approx(dn.genetic_damage, 500.0 - CDna.GD_REMOVE_PER_SECOND * 2.0))
	body.free()
	active_body.free()
	var handheld := Proto.spawn("sequence_scanner", p.cell)
	p.c(&"inv").put_in_hands(handheld)
	var pocket: CSeqScanner = handheld.c(&"seqscanner")
	pocket.gene_scan(patient, p)
	pocket.display_sequence(p, mid)
	_check("handheld sequence analysis starts TG's 20 second recharge", not pocket.ready and is_equal_approx(pocket.ready_at - Game.time, 20.0))
	var timers := Genetics._timers.size()
	pocket.display_sequence(p, mid)
	_check("repeated analysis does not restart or bypass recharge", Genetics._timers.size() == timers)
	pocket.recharge()
	_check("recharge restores handheld analysis", pocket.ready)
	pocket.makeup_scan(patient, p)
	pocket.makeup_mode = true
	con.genetic_makeup_buffer[0] = {"name": "Do not overwrite"}
	pocket.link(p, con)
	_check("handheld export asks for a slot without overwriting existing data", con.genetic_makeup_buffer[0]["name"] == "Do not overwrite" and con.genetic_makeup_buffer[1] == null)
	_check("held makeup is exposed to the console UI", con.data(p)["heldScannerMakeup"])
	_check("handheld export copies only the chosen slot", con.act("import_scanner_makeup", {"index": 2}, p) and con.genetic_makeup_buffer[1]["name"] == "TG parity patient" and con.genetic_makeup_buffer[0]["name"] == "Do not overwrite")
	body = VBoxContainer.new()
	WindowsDna._makeup_buffers(con, con.data(p), body, action)
	var imports := body.find_children("*", "Button", true, false).filter(func(b): return b.text == "Import from handheld")
	_check("makeup UI offers three explicit handheld destinations", imports.size() == 3)
	if imports.size() == 3:
		imports[2].pressed.emit()
	_check("the handheld import button writes its displayed slot", con.genetic_makeup_buffer[2] is Dictionary and con.genetic_makeup_buffer[2]["name"] == "TG parity patient")
	body.free()
	_check("handheld export rejects invalid slots", not con.act("import_scanner_makeup", {"index": 0}, p))
	p.c(&"inv").drop(handheld)
	_check("handheld import requires the scanner to still be held", not con.act("import_scanner_makeup", {"index": 3}, p))
	for ent in [console, pod, handheld, monkey, dead_monkey, patient, p]:
		if is_instance_valid(ent) and not ent.removed:
			ent.destroy()
	Game.running = running

func _dna_core() -> void:
	var p := _subject("Dana Core")
	var d := _dna(p)
	_check("a crew member has DNA", d != null)
	_check("unique enzymes: 32 hex (md5 of the real name)", d.unique_enzymes.length() == Genetics.DNA_UNIQUE_ENZYMES_LEN and d.unique_enzymes == p.c(&"mob").real_name.md5_text())
	_check("unique identity is the length of the UI blocks", d.unique_identity.length() == Genetics.hash_len(Genetics.UI_BLOCKS))
	_check("8 genes in the mutation index", d.mutation_index.size() == Genetics.DNA_MUTATION_BLOCKS)
	_check("the monkey gene is one of them", d.mutation_index.has("race"))
	_check("stability starts at 100", is_equal_approx(d.stability, 100.0))
	_check("a gene is 32 letters (4 blocks x 4 pairs)", Genetics.sequence("hulk").length() == 32)
	var inactive := 0
	for mid in d.mutation_index:
		if not d.is_gene_active(mid):
			inactive += 1
	_check("genes start inactive (X'd out)", inactive == d.mutation_index.size())
	_check("block round trip: construct/deconstruct", Genetics.deconstruct_block(Genetics.construct_block(3, 5), 5) == 3)
	_check("blood DNA is the unique enzymes", Forensics.dna(p) == d.unique_enzymes)
	_check("fingerprints are md5(unique identity)", Forensics.fingerprint(p) == d.unique_identity.md5_text())
	# an identity change changes the prints (tg)
	var old := Forensics.fingerprint(p)
	d.random_mutate_unique_identity()
	var tries := 0
	while Forensics.fingerprint(p) == old and tries < 10:
		d.random_mutate_unique_identity()
		tries += 1
	_check("mutating the identity changes the fingerprints", Forensics.fingerprint(p) != old)

# ------------------------------------------------------------------ mutations
func _mutations() -> void:
	var p := _subject("Muta Tion")
	var d := _dna(p)
	# complete a gene in the index: it switches on (domutcheck)
	var mid := ""
	for k in d.mutation_index:
		if k != "race":
			mid = k
			break
	d.mutation_index[mid] = Genetics.sequence(mid)
	d.domutcheck()
	_check("a completed gene activates its mutation (%s)" % mid, d.has_mutation(mid))
	_check("an activated mutation's source is 'activated'", Genetics.SRC_ACTIVATED in d.get_mutation(mid).sources)
	d.remove_mutation(mid, Genetics.SRC_ACTIVATED)
	_check("removing it re-scrambles the gene", not d.is_gene_active(mid) and not d.has_mutation(mid))
	# a mutator adds genes that aren't in the sequence
	d.add_mutation("strong", Genetics.SRC_MUTATOR)
	_check("a mutator adds a gene outside the sequence", d.has_mutation("strong"))
	_check("strength gives TRAIT_STRENGTH", Traits.has(p, "strength"))
	d.add_mutation("radioactive", Genetics.SRC_MUTATOR)
	_check("strong + radioactive: both on", d.has_mutation("radioactive"))
	d.remove_all_mutations()
	_check("remove_all_mutations clears them", d.mutations.is_empty() and not Traits.has(p, "strength"))
	d.add_mutation("hulk", Genetics.SRC_MUTATOR)
	_check("hulk: TRAIT_HULK", Traits.has(p, "hulk"))
	d.remove_mutation("hulk", Genetics.SRC_MUTATOR)
	_check("hulk off: trait gone", not Traits.has(p, "hulk"))
	d.add_mutation("mute", Genetics.SRC_MUTATOR)
	_check("mute: TRAIT_MUTE", Traits.has(p, "mute"))
	d.remove_all_mutations()
	# combined recipes
	var found := false
	for r in Genetics.RECIPES:
		if r[0] == "strong" and r[1] == "radioactive" and r[2] == "hulk":
			found = true
	_check("recipe: strong + radioactive = hulk", found)

# ------------------------------------------------------------------ stability
func _instability() -> void:
	var p := _subject("Stab Ility")
	var d := _dna(p)
	d.add_mutation("strong", Genetics.SRC_MUTATOR)
	_check("a positive mutator costs its instability (100 - 10 = %.0f)" % d.stability, is_equal_approx(d.stability, 90.0))
	d.add_mutation("clumsy", Genetics.SRC_MUTATOR)
	_check("a negative mutation gives stability back (+40: %.0f)" % d.stability, is_equal_approx(d.stability, 130.0))
	d.remove_all_mutations()
	_check("clean again: 100", is_equal_approx(d.stability, 100.0))
	# stack positive mutators until stability hits 0: the DNA starts to melt
	for mid in Genetics.DEFS:
		if d.stability <= 0:
			break
		var def: Dictionary = Genetics.DEFS[mid]
		if def.get("quality", 0) == Genetics.POSITIVE and def.get("instability", 0) > 0 and not def.get("locked", false):
			d.add_mutation(mid, Genetics.SRC_MUTATOR)
	_check("stability at or below 0 (%.0f)" % d.stability, d.stability <= 0)
	_check("dna_melt starts: 60 s to fix it", d.melt_t > 0.0 and d.melt_t <= CDna.DNA_MELT_DURATION)
	d.remove_all_mutations()
	d.melt_t = -1.0
	# genetic damage decays
	d.add_genetic_damage(30.0)
	_check("genetic damage accumulates", d.genetic_damage >= 30.0)

# ------------------------------------------------------------------ injectors
func _injectors() -> void:
	var p := _subject("Inje Ctor")
	var d := _dna(p)
	var mid := ""
	for k in d.mutation_index:
		if k != "race":
			mid = k
			break
	# an activator only works on genes in the sequence
	var act := Proto.spawn("dna_activator", p.cell)
	var aj: CDnaInjector = act.c(&"dnainjector")
	aj.add_mutations.append(Mutation.make(mid))
	aj._finish(p, p)
	_check("an activator switches on a gene in the sequence", d.has_mutation(mid) and d.is_gene_active(mid))
	_check("the injector is used up", aj.used)
	var act2 := Proto.spawn("dna_activator", p.cell)
	var aj2: CDnaInjector = act2.c(&"dnainjector")
	var outside := ""
	for k in Genetics.DEFS:
		if not d.mutation_index.has(k) and not Genetics.DEFS[k].get("locked", false) and Genetics.DEFS[k].get("quality", 0) == Genetics.POSITIVE:
			outside = k
			break
	aj2.add_mutations.append(Mutation.make(outside))
	aj2._finish(p, p)
	_check("an activator does nothing for a gene they don't have (%s)" % outside, not d.has_mutation(outside))
	# a mutator forces it
	var mut := Proto.spawn("dna_activator", p.cell)
	var mj: CDnaInjector = mut.c(&"dnainjector")
	mj.force_mutate = true
	mj.add_mutations.append(Mutation.make(outside))
	mj._finish(p, p)
	_check("a mutator adds it anyway", d.has_mutation(outside) and Genetics.SRC_MUTATOR in d.get_mutation(outside).sources)
	d.remove_all_mutations()
	# the premade timed hulk injector
	var hk := Proto.spawn("dna_injector_hulk", p.cell)
	hk.c(&"dnainjector")._finish(p, p)
	_check("the Hulk injector hulks", d.has_mutation("hulk"))
	d.remove_all_mutations()

func _lifecycle_parity() -> void:
	var p := _subject("Species mutation lifecycle")
	var d := _dna(p)
	d.add_mutation("hulk", [Genetics.SRC_MUTATOR, "test_external"])
	d.add_mutation("strong", Genetics.SRC_MUTATOR)
	Species.set_species(p, "monkey")
	_check("species change removes every source of human-only mutations", not d.has_mutation("hulk") and not Traits.has(p, "hulk") and not Traits.has(p, "stunimmune"))
	_check("species change restores Hulk physiology and retains unrestricted genes", is_equal_approx(p.c(&"health").cold_mod, 1.0) and d.has_mutation("strong"))
	d.remove_all_mutations()
	d.transform_t = 0.0
	d._transform_cb = Callable()
	Species.set_species(p, "skeleton")
	_check("skeleton DNA cannot be mutated", not Genetics.can_mutate(p))
	var injector := Proto.spawn("dna_activator", p.cell)
	injector.c(&"dnainjector").force_mutate = true
	injector.c(&"dnainjector").add_mutations.append(Mutation.make("strong"))
	injector.c(&"dnainjector")._finish(p, p)
	_check("skeleton rejects mutators without consuming them", not injector.c(&"dnainjector").used and not d.has_mutation("strong"))
	injector.destroy()
	p.destroy()
	p = _subject("Cosmetic transformation lifecycle")
	d = _dna(p)
	var original := d.snapshot(false)
	# Keep a completed native gene without calling domutcheck, to observe the apply hook.
	var keys: Array = d.mutation_index.keys()
	if not d.mutation_index.has("strong"):
		d.mutation_index.erase(keys[0] if keys[0] != "race" else keys[1])
	d.mutation_index["strong"] = Genetics.sequence("strong")
	d.start_temp_transform({"name": "First disguise", "UE": "1".repeat(32), "blood_type": "AB+"}, 10.0)
	_check("cosmetic transformation rechecks native genes on application", d.has_mutation("strong"))
	_check("cosmetic transformation changes blood forensic identity", Forensics.dna(p) == "1".repeat(32) and p.c(&"health").blood_type == "AB+")
	d.start_temp_transform({"name": "Second disguise", "UE": "2".repeat(32)}, 2.0)
	d.tick(2.0)
	_check("shorter overlapping disguise expires back to remaining disguise", p.display_name == "First disguise" and d.unique_enzymes == "1".repeat(32) and d.temp_transforms.size() == 1)
	d.tick(8.0)
	_check("last disguise restores original name enzymes and blood", p.display_name == original["name"] and d.unique_enzymes == original["UE"] and p.c(&"health").blood_type == original["blood_type"] and d.temp_transforms.is_empty())
	d.start_temp_transform({"name": "Short disguise"}, 2.0)
	d.start_temp_transform({"name": "Long disguise"}, 10.0)
	d.tick(2.0)
	_check("longer overlapping disguise survives expiry of first disguise", p.display_name == "Long disguise" and d.temp_transforms.size() == 1)
	d.tick(8.0)
	_check("overlapping disguises always restore original identity", p.display_name == original["name"] and d.unique_identity == original["UI"] and d.unique_features == original["UF"])
	p.destroy()

# ------------------------------------------------------------------ mutadone
func _mutadone() -> void:
	var p := _subject("Muta Done")
	var d := _dna(p)
	var h: CHealth = p.c(&"health")
	d.add_mutation("strong", Genetics.SRC_MUTATOR)
	d.add_mutation("clumsy", Genetics.SRC_MUTATOR)
	h.chems["mutadone"] = 5.0
	var until := Game.time + 10.0
	while Game.time < until and not d.mutations.is_empty():
		await get_tree().process_frame
	_check("mutadone strips mutator mutations", d.mutations.is_empty())
	h.chems.erase("mutadone")

# ------------------------------------------------------------------ monkeys
func _monkeys() -> void:
	var p := _subject("Bubbles Human")
	var d := _dna(p)
	d.add_mutation("race", Genetics.SRC_MUTATOR)
	var until := Game.time + 6.0
	while Game.time < until and not Genetics.is_monkey(p):
		await get_tree().process_frame
	_check("the monkey gene monkeyizes (after the transformation)", Genetics.is_monkey(p))
	_check("monkeys are the monkey species", d.species == "monkey" and Species.of(p) == "monkey")
	_check("a monkey is simian", Traits.has(p, "simian"))
	_check("a monkeyized human keeps their brain, and their tool use (tg)", Species.advanced_tool_user(p))
	var said := Species.scramble("monkey", "hello there friend")
	_check("monkeys speak Chimpanzee (%s)" % said, said != "hello there friend")
	d.remove_mutation("race", Genetics.STANDARD_SOURCES)
	until = Game.time + 6.0
	while Game.time < until and Genetics.is_monkey(p):
		await get_tree().process_frame
	_check("losing the gene humanizes them", not Genetics.is_monkey(p) and d.species == "human")
	_check("and they keep their name", p.display_name == "Bubbles Human")
	# a born monkey
	var m := Monkeys.spawn_monkey(_cells()[1])
	_check("a born monkey: born_monkey trait, monkey species, monkey AI", Traits.has(m, "born_monkey") and Genetics.is_monkey(m) and m.has_c(&"monkeyai"))
	_check("a born monkey's primate brain can't use complex tools", not Species.advanced_tool_user(m))
	_check("its doll uses the monkey body", m.c(&"mob").doll.layer_src.get("body", "") == "monkey_body")
	_check("with a tail", m.c(&"mob").doll.layer_src.get("tail", "") == "monkey_tail")
	# mutadone can't humanize a born monkey
	var mh: CHealth = m.c(&"health")
	Mutadone.on_metabolize(mh)
	Mutadone.on_life(mh)
	_check("mutadone doesn't humanize a born monkey", Genetics.is_monkey(m))

func _cube() -> void:
	var c: Vector2i = _cells()[2]
	var cube := Proto.spawn("monkey_cube", c)
	var before := Monkeys.cube_count()
	Monkeys.expose_water(cube)
	await _wait(0.2)
	_check("water on a monkey cube makes a monkey", Monkeys.cube_count() == before + 1)
	_check("and the cube is gone", not is_instance_valid(cube) or cube.removed)

# ------------------------------------------------------------------ the scanner and console
func _console() -> void:
	var consoles := Game.all_with(&"dnaconsole")
	_check("the station has DNA consoles (%d)" % consoles.size(), consoles.size() >= 2)
	if consoles.is_empty():
		return
	var con: CDnaConsole = consoles[0].c(&"dnaconsole")
	con.connect_to_scanner()
	_check("the console links to the scanner beside it", con.scanner() != null)
	if con.scanner() == null:
		return
	var sc := con.scanner()
	var p := _subject("Scan Ner")
	p.place(sc.e.cell + Vector2i(0, 1))
	if not sc.state_open:
		sc.open_machine()
	sc.close_machine(p)
	_check("a person can be shut in the scanner", sc.occupant == p)
	_check("the console sees the occupant", con.scanner_occupant == p and con.can_modify_occupant())
	var d := _dna(p)
	var mid := ""
	for k in d.mutation_index:
		if k != "race":
			mid = k
			break
	var before: String = d.mutation_index[mid]
	var gd := d.genetic_damage
	var pos := before.find("X") + 1
	if pos <= 0:
		pos = 1
	con.act("pulse_gene", {"alias": Genetics.alias(mid), "pos": pos, "pulseAction": CDnaConsole.NEXT_GENE}, p)
	_check("pulsing a letter changes the gene", d.mutation_index[mid] != before)
	_check("and costs genetic damage", d.genetic_damage > gd)
	# solve the gene letter by letter, as a player would
	var truth := Genetics.sequence(mid)
	for i in truth.length():
		var tries := 0
		while d.mutation_index[mid][i] != truth[i] and tries < 5:
			con.act("pulse_gene", {"alias": Genetics.alias(mid), "pos": i + 1, "pulseAction": CDnaConsole.NEXT_GENE}, p)
			tries += 1
	_check("solving every letter activates it", d.has_mutation(mid))
	_check("and the mutation is discovered", Genetics.discovered.has(mid))
	sc.open_machine()
	_check("opening the scanner lets them out", sc.occupant == null and p.holder == null)
	var data := con.data(p)
	_check("the console builds its UI data", data is Dictionary and not data.is_empty())

# ------------------------------------------------------------------ speech
func _speech() -> void:
	var p := _subject("Swe Dish")
	var d := _dna(p)
	d.add_mutation("swedish", Genetics.SRC_MUTATOR)
	var t: String = GeneFx.treat_speech(p, "we were away")["text"]
	_check("swedish: w -> v (%s)" % t, t.begins_with("ve vere"))
	d.remove_all_mutations()
	d.add_mutation("hulk", Genetics.SRC_MUTATOR)
	var t2: String = GeneFx.treat_speech(p, "hello.")["text"]
	_check("hulk speech shouts (%s)" % t2, t2 == t2.to_upper() and t2.ends_with("!!"))
	d.remove_all_mutations()

# ------------------------------------------------------------------ the lab
func _lab() -> void:
	var mg = Game.world.get_parent().mapgen
	var lab = mg.room_of("genetics")
	_check("the station has a Genetics lab", lab != null and not lab.is_empty())
	var pen = mg.room_of("monkey_pen")
	_check("with a monkey pen", pen != null and not pen.is_empty())
	var monkeys := 0
	for m in Game.all_with(&"monkeyai"):
		if pen and Game.map.area_at(m.cell) == pen["area"]:
			monkeys += 1
	_check("monkeys in the pen (%d)" % monkeys, monkeys >= 2)
	var linked := 0
	for c in Game.all_with(&"dnaconsole"):
		c.c(&"dnaconsole").connect_to_scanner()
		if c.c(&"dnaconsole").scanner() != null:
			linked += 1
	_check("both consoles are linked to scanners (%d)" % linked, linked >= 2)
	_check("Geneticist is a medical job", Jobs.dept("geneticist") == "medical")
	_check("Geneticists start in Genetics", Jobs.START_ROOM.get("geneticist", "") == "genetics")
	var lockers := 0
	for l in Game.all_with(&"storage"):
		if l.get_meta("job_locker", "") == "geneticist":
			lockers += 1
	_check("Geneticist lockers in the lab (%d)" % lockers, lockers >= 1)

# ------------------------------------------------------------------ the console window
## A subject in the first scanner with a discovered gene, stored mutations, a chromosome
## and a makeup buffer: what a geneticist mid-shift would be looking at.
var _staged: CDnaConsole = null
func _stage() -> CDnaConsole:
	if _staged:
		return _staged
	# the second pair: the scanner test used the first
	var con: CDnaConsole = Game.all_with(&"dnaconsole")[-1].c(&"dnaconsole")
	con.connect_to_scanner()
	var sc := con.scanner()
	var p := _subject("Window Subject")
	if not sc.state_open:
		sc.open_machine()
	p.place(sc.e.cell + Vector2i(0, 1))
	sc.close_machine(p)
	var d := _dna(p)
	var keys := d.mutation_index.keys().filter(func(k): return k != "race")
	for k in keys.slice(0, 3):
		d.mutation_index[k] = Genetics.sequence(k)
	d.domutcheck()
	for k in keys.slice(0, 3):
		Genetics.discovered[k] = true
	con.view["sequencerMutation"] = Genetics.alias(keys[3])
	con.stored_mutations.clear()
	con.stored_mutations.append(Mutation.make("strong"))
	con.stored_mutations.append(Mutation.make("radioactive"))
	con.stored_chromosomes = ["power", "stabilizer"]
	con.act("save_makeup_console", {"index": 1}, Game.player)
	_staged = con
	return con

func _window() -> void:
	var con := _stage()
	for mode in ["storage", "sequencer", "enzymes", "features"]:
		con.view["consoleMode"] = mode
		var body := VBoxContainer.new()
		WindowsDna.build("dna_console", con.e, body, null)
		_check("the console window builds its %s mode (%d parts)" % [mode, body.get_child_count()], body.get_child_count() >= 3)
		body.free()
	# the sequencer lays out 16 base pairs of the selected gene
	con.view["consoleMode"] = "sequencer"
	var body2 := VBoxContainer.new()
	WindowsDna.build("dna_console", con.e, body2, null)
	var genes := body2.find_children("*", "Button", true, false).filter(func(b): return b.text.length() == 1 and b.text in "ATCGX")
	_check("the sequencer shows all 32 letters (%d)" % genes.size(), genes.size() >= 32)
	body2.free()
	con.view["consoleMode"] = "storage"

func _screenshots() -> void:
	var running := Game.running
	Game.running = false
	DirAccess.make_dir_recursive_absolute(dir)
	Game.lighting.full_bright = true
	var con := _stage()
	var pl := Game.player
	pl.place(con.e.cell + Vector2i.UP)
	con.view["sequencerMutation"] = Genetics.alias(con.occ_dna().mutation_index.keys().filter(func(k): return k != "race")[3])
	Game.view.camera.position = Entity.cell_to_pos(con.e.cell)
	Game.view.camera.reset_smoothing()
	var idle_size := Vector2.ZERO
	for mode in ["sequencer", "storage", "enzymes", "enzymes_pulsing"]:
		con.view["consoleMode"] = "enzymes" if mode == "enzymes_pulsing" else mode
		if mode == "enzymes_pulsing":
			con.pulse_duration = 10
			con.act("makeup_pulse", {"type": "ui", "index": 1}, pl)
			con.pulse_started_at -= 3.0
			con.pulse_timer -= 3.0
		for w in Game.hud.windows.get_children():
			w.queue_free()
		await get_tree().process_frame
		Game.hud.open_window("dna_console", con.e)
		for k in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var window := Game.hud.windows.get_child(0) as UIWindow
		_check("rendered %s window stays within the viewport" % mode, window.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y + 1.0)
		_check("rendered %s content clips to its scroll viewport" % mode, window.scroll.clip_contents)
		if mode == "enzymes":
			idle_size = window.size
		elif mode == "enzymes_pulsing":
			_check("the rendered pulse window keeps its idle size", window.size.is_equal_approx(idle_size))
		get_viewport().get_texture().get_image().save_png(dir.path_join("dna_console_%s.png" % mode))
		var before_pos := window.position
		var before_size := window.size
		var bar := window.body.find_child("GeneticDamageBar", true, false)
		var before_text: String = bar.text
		con.occ_dna().add_genetic_damage(1.0)
		window._refresh_now()
		_check("%s damage updates retain the visible bar" % mode, window.body.find_child("GeneticDamageBar", true, false) == bar and bar.text != before_text)
		await get_tree().process_frame
		_check("%s readout refresh preserves window position and size" % mode, window.position.is_equal_approx(before_pos) and window.size.is_equal_approx(before_size))
		if mode == "enzymes_pulsing":
			var pulse := window.body.find_child("PulseProgress", true, false)
			var old_text: String = pulse.text
			var old_scroll := window.scroll.scroll_vertical
			con.pulse_timer -= 1.0
			con.pulse_started_at -= 1.0
			con.scramble_ready -= 1.0
			window._refresh_now()
			_check("countdown refresh preserves pulse control and scroll position", window.body.find_child("PulseProgress", true, false) == pulse and pulse.text != old_text and window.scroll.scroll_vertical == old_scroll)
		if mode == "sequencer":
			var genes := window.body.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("ui_live_gene", false) and not b.disabled)
			if not genes.is_empty():
				var gene: Button = genes[0]
				var old: String = gene.text
				var alias: String = con.view["sequencerMutation"]
				con.act("pulse_gene", {"alias": alias, "pos": 1, "pulseAction": CDnaConsole.NEXT_GENE}, pl)
				window._refresh_now()
				_check("editing an inactive gene retains its hovered base button", is_instance_valid(gene) and gene.is_inside_tree() and gene.text != old)
				var click := InputEventMouseButton.new()
				click.pressed = true
				click.button_index = MOUSE_BUTTON_LEFT
				gene.gui_input.emit(click)
				_check("a refreshed gene button still edits the correct base", con.occ_dna().mutation_index[Genetics.alias_to_id[alias]][0] != gene.text)
	con.on_scanner_open()
	for w in Game.hud.windows.get_children():
		w.queue_free()
	await get_tree().process_frame
	con.view["tutorialPage"] = 0
	con.view["practiceSequence"] = WindowsDna.PRACTICE_START
	Game.hud.open_window("dna_tutorial", con.e)
	var guide := Game.hud.windows.get_child(0) as UIWindow
	var guide_size := Vector2.ZERO
	for page in WindowsDna.TUTORIAL.size():
		if page > 0:
			guide.body.find_children("*", "Button", true, false).filter(func(b): return b.text == "Next")[0].pressed.emit()
			await get_tree().process_frame
			_check("beginner Next button advances to lesson %d" % page, con.view["tutorialPage"] == page)
		con.view["practiceSequence"] = "ATCGATCG" if page == 2 else (WindowsDna.PRACTICE_SOLUTION if page >= 3 else WindowsDna.PRACTICE_START)
		guide._refresh_now()
		for k in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_check("beginner lesson %d stays within the viewport" % page, guide.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y + 1)
		if page == 0:
			guide_size = guide.size
		else:
			_check("beginner lesson %d keeps a stable window size" % page, guide.size.is_equal_approx(guide_size))
		get_viewport().get_texture().get_image().save_png(dir.path_join("genetics_lesson_%d.png" % (page + 1)))
	var show := guide.body.find_children("*", "Button", true, false).filter(func(b): return b.text == "Show the real Sequencer")[0] as Button
	show.pressed.emit()
	await get_tree().process_frame
	var console_windows: Array = Game.hud.windows.get_children().filter(func(child): return child is UIWindow and child.kind == "dna_console")
	_check("the lesson opens the real Sequencer without closing itself", console_windows.size() == 1 and con.view["consoleMode"] == "sequencer" and not guide.is_queued_for_deletion())
	show.pressed.emit()
	_check("showing an existing Sequencer does not toggle it closed", console_windows.size() == 1 and not console_windows[0].is_queued_for_deletion())
	guide.body.find_children("*", "Button", true, false).filter(func(b): return b.text == "Start over")[0].pressed.emit()
	await get_tree().process_frame
	_check("starting over resets both the lesson and practice puzzle", con.view["tutorialPage"] == 0 and con.view["practiceSequence"] == WindowsDna.PRACTICE_START)
	for console_window in console_windows:
		console_window.queue_free()
	# Reading the lesson while fetching a patient should not close it.
	pl.place(con.e.cell + Vector2i(4, 0))
	await get_tree().process_frame
	_check("beginner lesson stays open when walking away from the console", is_instance_valid(guide) and not guide.is_queued_for_deletion())
	guide.queue_free()
	# the lab and its pen
	Game.view.camera.position = Entity.cell_to_pos(con.e.cell + Vector2i(3, -4))
	Game.view.camera.reset_smoothing()
	Game.hud.root.visible = false
	for k in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("genetics_lab.png"))
	Game.hud.root.visible = true
	for window in Game.hud.windows.get_children(): window.queue_free()
	await get_tree().process_frame
	var station := Proto.spawn("skill_station", pl.cell, {"comps": {"machine": {"needs_power": false}}})
	var st: CSkillStation = station.c(&"skillstation")
	var chip := Proto.spawn("skillchip", pl.cell, {"comps": {"skillchip": {"kind": "musical"}}})
	st.attackby(pl, chip)
	st.close_machine(pl)
	for frame in 15: await get_tree().process_frame
	var window: UIWindow = Game.hud.windows.get_children().filter(func(child): return child is UIWindow and child.kind == "skill_station")[0]
	var implant: Button = window.body.find_children("*", "Button", true, false).filter(func(button): return button.text == "Implant")[0]
	implant.pressed.emit()
	await get_tree().process_frame
	_check("rendered Skillsoft implant button starts the operation", st.working == "implant")
	_check("Skillsoft window fits inside the viewport", window.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y + 1.0)
	var size_before := window.size
	var button_before: Button = window.body.find_children("*", "Button", true, false).filter(func(button): return button.text == "Implant")[0]
	st.finish_at -= 1.0
	window._refresh_now()
	await get_tree().process_frame
	_check("Skillsoft countdown preserves controls and window size", is_instance_valid(button_before) and button_before.is_inside_tree() and size_before.is_equal_approx(window.size))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("skillsoft_station.png"))
	st.open_machine()
	station.destroy()
	chip.destroy()
	for opened in Game.hud.windows.get_children(): opened.queue_free()
	await get_tree().process_frame
	Game.hud.root.visible = false
	for kind in ["corgi", "crab", "gorilla", "psyker"]:
		var body := _subject("Rendered " + kind)
		Game.player = body
		if kind == "psyker": Psyker.transform(body)
		else: GeneFx.animalize(body, kind)
		Game.view.camera.position = Entity.cell_to_pos(body.cell)
		Game.view.camera.reset_smoothing()
		for frame in 12: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("genetics_body_%s.png" % kind))
		Game.player = pl
		body.destroy()
	Game.hud.root.visible = true
	Game.running = running

# ------------------------------------------------------------------ genetic powers
func _powers() -> void:
	var pl := Game.player
	var d := _dna(pl)
	if d == null:
		_check("the player has DNA", false)
		return
	var hud: HUD = Game.hud
	d.add_mutation("geladikinesis", Genetics.SRC_MUTATOR)
	_check("geladikinesis grants Create Snow", not GenePowers.find(pl, "snow").is_empty())
	_check("the HUD shows the powers bar", hud.powers_bar.visible and hud.powers_bar.buttons.has("snow"))
	var before := Game.at(pl.cell).filter(func(x): return x.proto == "sheet_snow").size()
	var held_before: int = pl.c(&"inv").all_items().filter(func(x): return x.proto == "sheet_snow").size()
	hud.powers_bar.buttons["snow"].pressed.emit()
	var after: int = Game.at(pl.cell).filter(func(x): return x.proto == "sheet_snow").size() + pl.c(&"inv").all_items().filter(func(x): return x.proto == "sheet_snow").size()
	_check("pressing it makes snow", after > before + held_before)
	_check("and starts its cooldown", GenePowers.cooldown_left(GenePowers.find(pl, "snow")) > 0.0)
	d.add_mutation("cryokinesis", Genetics.SRC_MUTATOR)
	var cryo := GenePowers.find(pl, "cryo")
	_check("cryokinesis grants Cryobeam", not cryo.is_empty())
	GenePowers.trigger(pl, "cryo")
	_check("a pointed power arms on press", cryo.get("armed", false))
	var used := GenePowers.click(pl, null, pl.cell + Vector2i(2, 0))
	_check("the next click fires it", used and not cryo.get("armed", false) and GenePowers.cooldown_left(cryo) > 0.0)
	d.remove_all_mutations()
	_check("losing the mutations takes the powers", GenePowers.list_of(pl).is_empty())
	_check("and hides the bar", not hud.powers_bar.visible)
