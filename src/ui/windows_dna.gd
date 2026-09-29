class_name WindowsDna extends RefCounted
## tg's DnaConsole tgui (tgui/interfaces/DnaConsole/*): the DNA scanner panel, the mode
## bar (Storage / Sequencer / Enzymes / Features), the genome sequencer with its paired
## letter buttons, mutation info with every print / save / combine / chromosome action,
## console, disk and advanced-injector storage, the enzyme pulse board and the genetic
## makeup buffers. It only reads CDnaConsole and calls its `act`, as tg's UI does.

# tg constants.ts GENE_COLORS / MUT_COLORS
const GENE_GREEN := Color("#1b9638")
const GENE_BLUE := Color("#1a6fb0")
const GENE_GREY := Color("#5c5c5c")
const MUT_EXTRA_COL := Color("#b87ae8")
const ORANGE := Color("#f2711c")

static func handles(kind: String) -> bool:
	return kind in ["dna_console", "dna_tutorial", "gene_list_target", "skill_station", "echo_focus", "gene_scent"]

static func title(kind: String, _t: Entity) -> String:
	if kind == "gene_scent": return "Choose a Scent"
	if kind == "echo_focus": return "Echolocation Focus"
	if kind == "skill_station": return "Lesson lectern"
	if kind == "dna_tutorial":
		return "Genetics: Getting started"
	return "Telepathy" if kind == "gene_list_target" else "DNA Console"

static func width(kind: String) -> int:
	if kind == "gene_scent": return 420
	if kind == "echo_focus": return 420
	if kind == "skill_station": return 580
	if kind == "dna_tutorial":
		return 580
	return 420 if kind == "gene_list_target" else 760

static func interval(kind: String) -> float:
	return 1.0 if kind == "gene_list_target" else 0.5

static func build(kind: String, t: Entity, body: VBoxContainer, w: UIWindow) -> void:
	if kind == "gene_scent":
		var player := Game.player
		var power := GenePowers.find(player, "olfaction") if is_instance_valid(player) else {}
		if power.is_empty():
			TGUI.notice(body, "You can no longer track scents.", "warn")
			return
		var choices: Array = power["data"].get("choices", [])
		if choices.is_empty(): TGUI.notice(body, "No scents to choose from.")
		for subject in choices:
			if not is_instance_valid(subject) or subject.removed: continue
			TGUI.button(body, subject.display_name, func():
				GenePowers.pick_scent(player, subject)
				if is_instance_valid(w): w.queue_free())
		return
	if kind == "echo_focus":
		if not Traits.has(t, "psyker"):
			TGUI.notice(body, "Echolocation is unavailable.", "warn")
			return
		TGUI.notice(body, "Choose what to highlight. Walls, doors and furniture remain visible.")
		for option in Psyker.ECHO_OPTIONS:
			var selected: bool = option in Psyker.echo_options(t)
			TGUI.button(body, ("Hide " if selected else "Show ") + option, func():
				Psyker.toggle_echo(t, option)
				if is_instance_valid(w): w._refresh_now.call_deferred())
		return
	if kind == "skill_station":
		_skill_station(t.c(&"skillstation"), body, w)
		return
	if kind == "dna_tutorial":
		_tutorial(t.c(&"dnaconsole"), body, w)
		return
	if kind == "gene_list_target":
		_list_target(t, body, w)
		return
	var con: CDnaConsole = t.c(&"dnaconsole")
	var p := Game.player
	if con == null:
		return
	if not con.operable():
		TGUI.notice(body, "The console is dark.", "bad")
		TGUI.button(body, "Getting started", func(): con.act("open_tutorial", {}, p))
		return
	var d := con.data(p)
	var act := func(action: String, params := {}):
		var ok := con.act(action, params, p)
		if w and is_instance_valid(w):
			w._refresh_now.call_deferred()
		return ok
	_scanner(con, d, body, act)
	_commands(con, d, body, act)
	match str(con.view.get("consoleMode", "storage")):
		"storage": _storage(con, d, body, act)
		"sequencer": _sequencer(con, d, body, act)
		"enzymes": _enzymes(con, d, body, act, str(d.get("subjectUNI", "")), "ui", "Enzymes")
		"features": _enzymes(con, d, body, act, str(d.get("subjectUF", "")), "uf", "Features")

# ------------------------------------------------------------------ DnaScanner.jsx
static func _skill_station(st: CSkillStation, body: VBoxContainer, w: UIWindow) -> void:
	if st.occupant != Game.player or st.state_open:
		TGUI.notice(body, "Enter the lectern to manage your lesson cards. Insert a card into it before entering.", "info")
		return
	var user := st.occupant
	body.set_meta("ui_identity", str([user.id, st.loaded.id if is_instance_valid(st.loaded) else 0, SkillChips.list_of(user).map(func(ch): return ch.id)]))
	var act := func(action: String, chip: Entity = null):
		st.act(user, action, chip)
		if w: w._refresh_now.call_deferred()
	TGUI.notice(body, "Implantation and removal take 15 seconds. Opening the lectern or losing power cancels the operation. Activation/deactivation starts a five-minute recharge.", "info")
	var sec := TGUI.section(body, "Brain capacity")
	var grid := TGUI.list(sec)
	TGUI.item(grid, "Slots", "%d / 5" % SkillChips.used_slots(user))
	TGUI.item(grid, "Active complexity", "%d / %d" % [SkillChips.used_complexity(user), SkillChips.capacity(user)])
	var busy := st.working != ""
	TGUI.notice(body, "%s: %ds remaining" % [st.working.capitalize(), maxi(0, ceili(st.finish_at - Game.time))] if busy else "Lectern ready.", "info")
	var inserted := TGUI.section(body, "Inserted chip")
	if is_instance_valid(st.loaded):
		inserted.add_child(UITheme.label(st.loaded.display_name, UITheme.BODY))
		var error := SkillChips.implant_error(user, st.loaded)
		if error != "": TGUI.notice(inserted, error, "warn")
		var buttons := TGUI.row(inserted)
		TGUI.button(buttons, "Implant", func(): act.call("implant"), false, busy or error != "" or not st.operational())
		TGUI.button(buttons, "Eject chip", func(): act.call("eject"), false, busy)
	else: inserted.add_child(UITheme.label("No chip inserted.", UITheme.SMALL))
	var installed := TGUI.section(body, "Implanted chips")
	for item in SkillChips.list_of(user):
		var chip: CSkillChip = item.c(&"skillchip")
		var row := TGUI.row(installed)
		var label := UITheme.label(item.display_name, UITheme.SMALL)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var locked := Game.time < chip.ready
		TGUI.button(row, "Deactivate" if chip.active else "Activate", func(): act.call("toggle", item), chip.active, busy or locked or not st.operational())
		TGUI.button(row, "Remove", func(): act.call("remove", item), false, busy or locked or not st.operational())
		if locked: installed.add_child(UITheme.label("Recharging: %ds" % ceili(chip.ready - Game.time), UITheme.SMALL, TGUI.AVERAGE))
	TGUI.button(body, "Open lectern / cancel", func(): st.open_machine())

static func _scanner(_con: CDnaConsole, d: Dictionary, body: Control, act: Callable) -> void:
	var btns := []
	if not d.get("isScannerConnected", false):
		btns.append(_mk_btn("Connect Scanner", func(): act.call("connect_scanner")))
	else:
		if d.get("hasDelayedAction", false):
			btns.append(_mk_btn("Cancel Delayed Action", func(): act.call("cancel_delay")))
		if d.get("isViableSubject", false):
			var ready: bool = d.get("isScrambleReady", false)
			var scramble := _mk_btn("Scramble DNA" + ("" if ready else " (%ds)" % d.get("scrambleSeconds", 0)), func(): act.call("scramble_dna"), false, not ready or d.get("isPulsing", false) or not d.get("canScramble", true))
			scramble.set_meta("ui_live_caption", true)
			scramble.set_meta("ui_identity", "scramble_dna")
			scramble.custom_minimum_size.x = 152
			scramble.tooltip_text = "Rerolls the genome and removes standard mutations, including Monkified. Living monkeys become human. Adds genetic damage (50 before scanner upgrades). Cooldown: 60 seconds."
			btns.append(scramble)
		var locked: bool = d.get("scannerLocked", false)
		var lk := _mk_btn("Locked" if locked else "Unlocked", func(): act.call("toggle_lock"), false, d.get("scannerOpen", false))
		if locked:
			lk.add_theme_color_override("font_color", TGUI.BAD)
		btns.append(lk)
		btns.append(_mk_btn("Close" if d.get("scannerOpen", false) else "Open", func(): act.call("toggle_door"), false, locked))
	var sec := TGUI.section(body, "DNA Scanner", btns)
	if not d.get("isScannerConnected", false):
		sec.add_child(UITheme.label("DNA Scanner is not connected.", UITheme.SMALL, TGUI.BAD))
		return
	if not d.get("isViableSubject", false):
		TGUI.notice(sec, "Drag yourself or a pulled patient onto the open scanner." if d.get("scannerOpen", false) else "No viable subject found. Open the scanner to insert a patient.", "info")
		return
	var g := TGUI.list(sec)
	var st := _status(int(d.get("subjectStatus", 0)))
	TGUI.item(g, "Status", "%s  ->  %s" % [d.get("subjectName", ""), st[0]], st[1])
	var hp: float = d.get("subjectHealth", 0.0)
	var hcol := TGUI.GOOD if hp >= 70 else (TGUI.AVERAGE if hp >= 30 else TGUI.BAD)
	TGUI.item_ctrl(g, "Health", TGUI.bar(clampf(hp, 0.0, 100.0), 100.0, "%d%%" % int(round(hp)), hcol))
	var gd: float = d.get("subjectDamage", 0.0)
	var gcol := TGUI.BAD if gd >= 71 else (TGUI.AVERAGE if gd >= 30 else TGUI.GOOD)
	var damage_bar := TGUI.bar(clampf(gd, 0.0, 100.0), 100.0, "%.1f%%" % gd, gcol)
	damage_bar.name = "GeneticDamageBar"
	damage_bar.tooltip_text = "Genetic damage accumulates from gene edits, scramble and makeup transfers. Toxin damage starts at 100%; it naturally clears over time."
	TGUI.item_ctrl(g, "Genetic Damage", damage_bar)
	var active: bool = d.get("isPulsing", false)
	var status := "%s: %ds remaining" % [d.get("pulseTarget", ""), d.get("timeToPulse", 0)] if active else "Ready - select an identity or feature base"
	var progress := TGUI.bar(d.get("pulseProgress", 0.0), 1.0, status, TGUI.AVERAGE if active else TGUI.GOOD)
	progress.name = "PulseProgress"
	TGUI.item_ctrl(g, "Pulse Emitter", progress)

## tg SubjectStatus
static func _status(s: int) -> Array:
	match s:
		CDnaConsole.SUBJECT_CONSCIOUS: return ["Conscious", TGUI.GOOD]
		CDnaConsole.SUBJECT_UNCONSCIOUS, CDnaConsole.SUBJECT_HARD_CRIT: return ["Unconscious", TGUI.AVERAGE]
		CDnaConsole.SUBJECT_SOFT_CRIT: return ["Critical", TGUI.AVERAGE]
		CDnaConsole.SUBJECT_DEAD: return ["Dead", TGUI.BAD]
		CDnaConsole.STATUS_TRANSFORMING: return ["Transforming", TGUI.BAD]
	return ["Unknown", UITheme.TEXT]

# ------------------------------------------------------------------ index.jsx DnaConsoleCommands
static func _commands(con: CDnaConsole, d: Dictionary, body: Control, act: Callable) -> void:
	var right := []
	if not d.get("isInjectorReady", false):
		right.append(UITheme.label("Injector on cooldown (%ds)" % d.get("injectorSeconds", 0), UITheme.SMALL, TGUI.LABEL))
	var sec := TGUI.section(body, "DNA Console", right)
	var g := TGUI.list(sec)
	var mode := str(con.view.get("consoleMode", "storage"))
	var r := TGUI.row(null, 3)
	TGUI.button(r, "Storage", func(): act.call("set_view", {"consoleMode": "storage"}), mode == "storage")
	TGUI.button(r, "Sequencer", func():
		act.call("all_check_discovery")
		act.call("set_view", {"consoleMode": "sequencer"}), mode == "sequencer", not d.get("isViableSubject", false))
	TGUI.button(r, "Enzymes", func(): act.call("set_view", {"consoleMode": "enzymes"}), mode == "enzymes")
	TGUI.button(r, "Features", func(): act.call("set_view", {"consoleMode": "features"}), mode == "features")
	TGUI.button(r, "Getting started", func(): act.call("open_tutorial"))
	TGUI.item_ctrl(g, "Mode", r)
	if d.get("hasDisk", false):
		var r2 := TGUI.row(null, 3)
		TGUI.button(r2, "Eject", func():
			act.call("eject_disk")
			act.call("set_view", {"storageMode": "console"}))
		TGUI.item_ctrl(g, "Disk", r2)

const PRACTICE_START := "AXXGXXCG"
const PRACTICE_SOLUTION := "ATCGTACG"
const TUTORIAL := [
	{"title": "1. What am I trying to do?", "body": "Each mutation has a secret letter code. Your job is to repair the missing letters. X means a missing letter.\n\nThe two letters stacked above each other are ONE pair. Read down each column, then move right. The mutation switches ON only when the entire code is correct.", "tip": "We will solve this tiny practice gene together. It has four pairs; a real gene has more. These buttons do not change your patient."},
	{"title": "2. One X? Use the letter you have", "body": "There are only two partner rules: A pairs with T. C pairs with G.\n\nFIRST column: A is above X. Click the bottom letter until it reads T.\nSECOND column: X is above G. Click the top letter until it reads C.\n\nEach click changes the letter once. Stop at the letter you need. Leave the third column alone for now.", "tip": "Left click cycles X → A → T → C → G → A. Right click goes backward. Hold Ctrl and click to erase a letter to X."},
	{"title": "3. X above X? You have to guess", "body": "In the THIRD column, both letters are missing. There is no partner to copy. The possibilities are AT, TA, CG, or GC.\n\nTry the AT button below. Its letters fit together, but our practice mutation stays OFF. Now try TA. That is the right guess for this example.", "tip": "This is the tricky part: fitting together does not mean a pair is correct. The game checks the WHOLE secret code, not each guess separately."},
	{"title": "4. Everything fits. Why is it still OFF?", "body": "A red connector means the two letters do not fit. Fix those first.\n\nIf there are no Xs or red connectors and the mutation is still OFF, a pair you guessed is wrong. Try another of AT, TA, CG, or GC in a pair that originally had X/X.\n\nIf several pairs started as X/X, you may need to try combinations of guesses. There is no per-pair 'correct!' indicator.", "tip": "Try changing our third pair back to AT, then TA again. Both fit. Only TA finishes this particular code. Real genes have their own different codes."},
	{"title": "5. Try it on a real gene", "body": "In Sequencer, choose an inactive Mutation # from the list. Fill any single X from its partner first. Then work on the X/X pairs.\n\nSuccess looks like this: the mutation activates and its real name appears. Click Save to Console to keep that discovery.\n\nStuck? When Use Joker is ready, click it and then click a letter. It reveals that ONE correct letter.", "tip": "Monkified works the same way: correct code = monkey; breaking it = human. Gene edits add genetic damage, so watch the patient's bar while experimenting."},
]

static func _tutorial(con: CDnaConsole, body: VBoxContainer, w: UIWindow) -> void:
	if con == null:
		return
	var page := clampi(int(con.view.get("tutorialPage", 0)), 0, TUTORIAL.size() - 1)
	var entry: Dictionary = TUTORIAL[page]
	var sec := TGUI.section(body, entry["title"])
	var content := UITheme.label(entry["body"], UITheme.BODY, UITheme.TEXT)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sec.add_child(content)
	_practice(con, body, w, page)
	TGUI.notice(body, entry["tip"], "info")
	var navigation := TGUI.row(body)
	var go := func(index: int):
		con.view["tutorialPage"] = clampi(index, 0, TUTORIAL.size() - 1)
		if w:
			w.scroll.scroll_vertical = 0
			w._refresh_now.call_deferred()
	TGUI.button(navigation, "Back", func(): go.call(page - 1), false, page == 0)
	var count := UITheme.label("%d / %d" % [page + 1, TUTORIAL.size()], UITheme.SMALL, TGUI.LABEL)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	navigation.add_child(count)
	TGUI.button(navigation, "Next" if page < TUTORIAL.size() - 1 else "Start over", func():
		if page == TUTORIAL.size() - 1:
			con.view["practiceSequence"] = PRACTICE_START
		go.call(page + 1 if page < TUTORIAL.size() - 1 else 0))
	if page == TUTORIAL.size() - 1:
		TGUI.button(body, "Show the real Sequencer", func():
			con.act("set_view", {"consoleMode": "sequencer"}, Game.player)
			con.act("all_check_discovery", {}, Game.player)
			if Game.hud:
				var existing: UIWindow = null
				for child in Game.hud.windows.get_children():
					if child is UIWindow and child.kind == "dna_console" and child.target == con.e:
						existing = child
				if existing:
					existing._refresh_now()
					existing.move_to_front()
				else:
					Game.hud.open_window("dna_console", con.e))

## A small, deterministic teaching puzzle. Uses the real gene button controls,
## but stores its letters only in UI state: no DNA edits, cooldowns or radiation.
static func _practice(con: CDnaConsole, body: Control, w: UIWindow, page: int) -> void:
	var seq := str(con.view.get("practiceSequence", PRACTICE_START))
	if seq.length() != PRACTICE_START.length():
		seq = PRACTICE_START
		con.view["practiceSequence"] = seq
	var sec := TGUI.section(body, "Practice only - your patient is unaffected")
	var row := TGUI.row(sec, 20)
	var update := func(next: String):
		con.view["practiceSequence"] = next
		if w:
			w._refresh_now.call_deferred()
	var act := func(_action: String, params: Dictionary):
		var pos: int = params["pos"] - 1
		var current := str(con.view.get("practiceSequence", PRACTICE_START))
		const LETTERS := "ATCG"
		var ch := "X"
		match params["pulseAction"]:
			CDnaConsole.NEXT_GENE: ch = LETTERS[(LETTERS.find(current[pos]) + 1) % 4]
			CDnaConsole.PREV_GENE: ch = LETTERS[posmod(LETTERS.find(current[pos]) - 1, 4)] if current[pos] != "X" else "G"
		update.call(current.substr(0, pos) + ch + current.substr(pos + 1))
	for pair in 4:
		var column := VBoxContainer.new()
		row.add_child(column)
		column.add_child(UITheme.label("Pair %d" % (pair + 1), UITheme.SMALL, TGUI.LABEL))
		for half in 2:
			var pos := pair * 2 + half
			var editable := pos in [1, 2] and page >= 1 or pos in [4, 5] and page >= 2
			var button := _gene_btn(seq[pos], pos, "practice", not editable, PRACTICE_START[pos] == "X", act)
			button.custom_minimum_size = Vector2(48, 32)
			column.add_child(button)
			if half == 0:
				var link := ColorRect.new()
				link.color = TGUI.LABEL if _pair_matched(seq, pos) else TGUI.BAD
				link.custom_minimum_size = Vector2(3, 8)
				link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				column.add_child(link)
	var on := seq == PRACTICE_SOLUTION
	var status := "ON - you solved the whole code!" if on else "OFF - the whole code is not correct yet."
	if page >= 1 and seq.substr(0, 2) != "AT":
		status = "OFF - first, click the bottom letter of pair 1 until it is T."
	elif page >= 1 and seq.substr(2, 2) != "CG":
		status = "OFF - pair 1 repaired! Now click the top letter of pair 2 until C."
	elif not on and seq == "ATCGXXCG":
		status = "OFF - first two pairs repaired! Next: guess the third pair."
	elif not on and not seq.contains("X") and _pair_matched(seq, 0) and _pair_matched(seq, 2) and _pair_matched(seq, 4) and _pair_matched(seq, 6):
		status = "OFF - the pairs fit, but a guess is wrong. Try another third pair."
	var feedback := UITheme.label(status, UITheme.BODY, TGUI.GOOD if on else TGUI.AVERAGE)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 44
	sec.add_child(feedback)
	if page >= 2:
		var choices := TGUI.row(sec)
		choices.add_child(UITheme.label("Try pair 3:", UITheme.SMALL, TGUI.LABEL))
		for guess in ["AT", "TA", "CG", "GC"]:
			TGUI.button(choices, guess, func():
				var current := str(con.view.get("practiceSequence", PRACTICE_START))
				update.call(current.substr(0, 4) + guess + current.substr(6)), seq.substr(4, 2) == guess)
	TGUI.button(sec, "Reset practice", func(): update.call(PRACTICE_START))

# ------------------------------------------------------------------ DnaConsoleSequencer.jsx
static func _sequencer(con: CDnaConsole, d: Dictionary, body: Control, act: Callable) -> void:
	if not d.get("isViableSubject", false):
		TGUI.notice(body, "No viable subject found in DNA Scanner.", "warn")
		return
	var muts := con.occupant_mutations()
	var sel := str(con.view.get("sequencerMutation", ""))
	var mut: Dictionary = {}
	for m in muts:
		if m["Alias"] == sel:
			mut = _occ_info(con, m)
	if mut.is_empty() and not muts.is_empty():
		var first: Dictionary = muts[0]
		if d.get("isMonkey", false):
			for candidate in muts:
				if candidate.get("Id", "") == "race":
					first = candidate
		sel = first["Alias"]
		mut = _occ_info(con, first)
		con.view["sequencerMutation"] = sel
	var held: Dictionary = d.get("heldScannerBuffer", {})
	var top := TGUI.row(body, 8)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(220, 0)
	top.add_child(left)
	var seqs := TGUI.section(left, "Sequences")
	var grid := GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	seqs.add_child(grid)
	for m in muts:
		var alias: String = m["Alias"]
		var txt := alias.replace("Mutation ", "#")
		if m["Discovered"]:
			txt = str(m.get("Name", alias))
		if held.has(alias):
			txt += " (M)"
		var col := TGUI.LABEL
		if m["Image"] == "extra":
			col = MUT_EXTRA_COL
		elif m["Discovered"]:
			col = _quality_col(int(m.get("Quality", 0)))
		var b := TGUI.button(grid, txt, func():
			act.call("set_view", {"sequencerMutation": alias})
			act.call("check_discovery", {"alias": alias}), alias == sel, false, col)
		b.custom_minimum_size = Vector2(204, 32)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.icon = UITheme.tex("icon_genome_" + str(m["Image"]))
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = str(m.get("Name", alias)) + "\n" + alias + (" (Active)" if m.get("Active", false) else " (Inactive)")
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(right)
	var info := TGUI.section(right, "Sequence Info")
	_mutation_info(con, d, info, act, mut)
	# corrupted subjects
	var st := int(d.get("subjectStatus", 0))
	if st == CDnaConsole.SUBJECT_DEAD:
		TGUI.notice(body, "Genetic sequence corrupted. Subject diagnostic report: DECEASED.", "bad")
		return
	if d.get("isMonkey", false) and mut.get("Id", "") != "race":
		TGUI.notice(body, "Genetic sequence corrupted. Subject diagnostic report: MONKEY.", "bad")
		return
	if st == CDnaConsole.STATUS_TRANSFORMING:
		TGUI.notice(body, "Genetic sequence corrupted. Subject diagnostic report: TRANSFORMING.", "bad")
		return
	var jr := []
	var joker := str(con.view.get("jokerActive", ""))
	if not d.get("isJokerReady", false):
		jr.append(UITheme.label("Joker on cooldown (%ds)" % d.get("jokerSeconds", 0), UITheme.SMALL, TGUI.LABEL))
	elif joker != "":
		jr.append(UITheme.label("Click on a gene to reveal it.", UITheme.SMALL, TGUI.LABEL))
		jr.append(_mk_btn("Cancel Joker", func(): act.call("set_view", {"jokerActive": ""})))
	else:
		jr.append(_mk_btn("Use Joker", func(): act.call("set_view", {"jokerActive": "1"}), false, false, Color("#c86ae8")))
	var gs := TGUI.section(right, "Genome Sequencer")
	if not jr.is_empty():
		var controls := _actions(gs)
		for control in jr:
			controls.add_child(control)
	var genome := mut.duplicate()
	genome["ReadOnly"] = d.get("isPulsing", false)
	_genome(gs, genome, act)
	if not mut.is_empty() and held.has(mut["Alias"]):
		var hs := TGUI.section(right, "Held Scanner")
		_genome(hs, {"Sequence": held[mut["Alias"]], "ReadOnly": true}, act)

## tg GenomeSequencer / GenomeSequencerReadOnly: 16 base pairs, a divider every 4.
static func _genome(parent: Control, mut: Dictionary, act: Callable) -> void:
	if mut.is_empty():
		parent.add_child(UITheme.label("No genome selected for sequencing.", UITheme.SMALL, TGUI.AVERAGE))
		return
	if mut.get("Scrambled", false):
		parent.add_child(UITheme.label("Sequence unreadable due to unpredictable mutation.", UITheme.SMALL, TGUI.AVERAGE))
		return
	var seq: String = mut["Sequence"]
	var ro: bool = mut.get("ReadOnly", false)
	var def_seq: String = mut.get("DefaultSeq", "")
	var locked: bool = ro or mut.get("Class", 1) != CDnaConsole.CLASS_ACTIVATOR
	var flow := GridContainer.new()
	flow.columns = 2
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 10)
	parent.add_child(flow)
	var i := 0
	var group: HBoxContainer
	while i < seq.length():
		if i % 8 == 0:
			var block := VBoxContainer.new()
			block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			flow.add_child(block)
			block.add_child(UITheme.label("Block %d" % (i / 8 + 1), UITheme.SMALL, TGUI.LABEL))
			group = TGUI.row(block, 3)
		var pair := VBoxContainer.new()
		pair.add_theme_constant_override("separation", 0)
		group.add_child(pair)
		var started_unknown := def_seq.length() > i + 1 and def_seq.substr(i, 2) == "XX"
		if not ro:
			var hint := UITheme.label("Guess" if started_unknown and not mut.get("Active", false) else "", UITheme.SMALL, TGUI.AVERAGE)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.custom_minimum_size = Vector2(38, 18)
			hint.tooltip_text = "Both letters originally started as X. This pair needs a guess: AT, TA, CG or GC."
			pair.add_child(hint)
		for k in 2:
			var idx := i + k
			if k == 1:
				var link := ColorRect.new()
				link.color = TGUI.LABEL if _pair_matched(seq, i) else Color("#db2828")
				link.custom_minimum_size = Vector2(3, 8)
				link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				pair.add_child(link)
			var ch := seq[idx]
			var outline: bool = not ro and def_seq.length() > idx and def_seq[idx] == "X" and not mut.get("Active", false)
			var button := _gene_btn(ch, idx, str(mut.get("Alias", "")), locked, outline, act)
			var partner := seq[idx + 1 if k == 0 else idx - 1]
			button.tooltip_text += "\nPair %d (%s letter). A pairs with T; C pairs with G." % [idx / 2 + 1, "top" if k == 0 else "bottom"]
			if started_unknown:
				button.tooltip_text += "\nBoth letters started as X. A fitting pair is still a guess until the whole code activates."
			if ch == "X" and partner in "ATCG":
				button.tooltip_text += "\nThe visible %s needs %s as its partner." % [partner, {"A": "T", "T": "A", "C": "G", "G": "C"}[partner]]
			elif ch == "X" and partner == "X":
				button.tooltip_text += "\nBoth letters are missing: try AT, TA, CG or GC. Fitting pairs can still be wrong."
			pair.add_child(button)
		i += 2
	if not ro:
		var tip := UITheme.label("Read pairs vertically: A ↔ T, C ↔ G. X is missing. Fill a lone X from its partner; guess X/X pairs. Fitting pairs can still be the wrong code.\nLeft click: next letter. Right click: previous. Ctrl+click: erase to X. Getting started has a practice puzzle.", UITheme.SMALL, TGUI.LABEL)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(tip)

static func _pair_matched(s: String, i: int) -> bool:
	var a := s[i]
	var b := s[i + 1] if i + 1 < s.length() else ""
	return (a == "A" and b == "T") or (a == "T" and b == "A") or (a == "G" and b == "C") or (a == "C" and b == "G")

## tg GeneCycler: click pulses to the next letter, right click the previous, ctrl+click X.
static func _gene_btn(ch: String, idx: int, alias: String, disabled: bool, outline: bool, act: Callable) -> Button:
	var col: Color = GENE_GREY if disabled else ({"A": GENE_GREEN, "T": GENE_GREEN, "G": GENE_BLUE, "C": GENE_BLUE}.get(ch, GENE_GREY))
	var b := Button.new()
	b.text = ch
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(28, 28)
	b.disabled = disabled
	b.button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.lightened(0.15) if st == "hover" else col
		if outline:
			sb.border_color = ORANGE
			sb.set_border_width_all(2)
		sb.content_margin_left = 2
		sb.content_margin_right = 2
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
	b.set_meta("ui_selected", outline)
	b.set_meta("ui_live_gene", true)
	b.set_meta("ui_identity", "gene:%s:%d" % [alias, idx])
	b.tooltip_text = "Base %d: %s\nLeft click: next ? Right click: previous ? Ctrl+click: clear" % [idx + 1, ch]
	if not disabled:
		b.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				if not ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
					return
				var action := CDnaConsole.NEXT_GENE
				if ev.button_index == MOUSE_BUTTON_RIGHT:
					action = CDnaConsole.PREV_GENE
				elif ev.ctrl_pressed:
					action = CDnaConsole.CLEAR_GENE
				act.call("pulse_gene", {"pos": idx + 1, "pulseAction": action, "alias": alias})
				b.accept_event())
	return b

# ------------------------------------------------------------------ MutationInfo.jsx
static func _quality_col(q: int) -> Color:
	match q:
		Genetics.POSITIVE: return TGUI.GOOD
		Genetics.NEGATIVE: return TGUI.BAD
		Genetics.MINOR_NEGATIVE: return TGUI.AVERAGE
	return UITheme.TEXT

## tg build_mutation_list data for a stored copy (console, disk or injector)
static func _stored_info(con: CDnaConsole, m: Mutation, source: String) -> Dictionary:
	return {"Alias": Genetics.alias(m.id), "Id": m.id, "Name": m.name(), "Description": m.def().get("desc", ""), "Quality": m.quality(),
		"Sequence": Genetics.sequence(m.id),
		"Instability": m.instability * m.stab(), "Active": true, "Scrambled": false, "Class": CDnaConsole.CLASS_ACTIVATOR, "Source": source,
		"Discovered": true, "ByondRef": m.uid, "CanChromo": m.can_chromosome, "ValidChromos": ", ".join(m.valid_chrom_list),
		"AppliedChromo": m.chromosome_name, "ValidStoredChromos": con.chrom_list(m)}

## the occupant's gene data plus the chromosome fields of its live mutation
static func _occ_info(con: CDnaConsole, md: Dictionary) -> Dictionary:
	var out := md.duplicate()
	var m: Mutation = md.get("Mut")
	out["ByondRef"] = m.uid if m else 0
	if m:
		out["CanChromo"] = m.can_chromosome
		out["ValidChromos"] = ", ".join(m.valid_chrom_list)
		out["AppliedChromo"] = m.chromosome_name
		out["ValidStoredChromos"] = con.chrom_list(m)
	else:
		out["CanChromo"] = Genetics.CHROMOSOME_NEVER
	return out

static func _same(a: Dictionary, b: Dictionary) -> bool:
	return a.get("Alias") == b.get("Alias") and a.get("AppliedChromo", "") == b.get("AppliedChromo", "")

static func _mutation_info(con: CDnaConsole, d: Dictionary, parent: Control, act: Callable, mut: Dictionary) -> void:
	# Identical-looking mutations may have different references after deleting, copying,
	# or swapping patients. The window must replace their action callbacks too.
	parent.set_meta("ui_identity", [mut.get("Source", ""), mut.get("ByondRef", 0), con.scanner_occupant.get_instance_id() if is_instance_valid(con.scanner_occupant) else 0])
	if mut.is_empty():
		parent.add_child(UITheme.label("Nothing to show.", UITheme.SMALL, TGUI.LABEL))
		return
	var src: String = mut.get("Source", "")
	if src == "occupant" and not mut.get("Discovered", false):
		var g0 := TGUI.list(parent)
		TGUI.item(g0, "Name", mut["Alias"])
		TGUI.item(g0, "Mutation", "OFF - code incomplete", TGUI.AVERAGE)
		TGUI.notice(parent, "Complete the sequence to activate and discover this mutation. Each edit adds genetic damage; red links mark mismatched base pairs.", "info")
		return
	var g := TGUI.list(parent)
	TGUI.item(g, "Name", str(mut.get("Name", "")), _quality_col(int(mut.get("Quality", 0))))
	var desc := TGUI.item(g, "Description", str(mut.get("Description", "")))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(230, 0)
	TGUI.item(g, "Instability", str(snappedf(float(mut.get("Instability", 0)), 0.01)))
	var console_list := []
	for m in con.stored_mutations:
		console_list.append(_stored_info(con, m, "console"))
	var disk_list := []
	var dk := con.disk()
	if dk:
		for m in dk.mutations:
			disk_list.append(_stored_info(con, m, "disk"))
	var active: bool = mut.get("Active", false)
	if src == "occupant":
		TGUI.item(g, "Mutation", "ON - active" if active else "OFF - code incomplete", TGUI.GOOD if active else TGUI.AVERAGE)
	var cls := int(mut.get("Class", 1))
	var ref := int(mut.get("ByondRef", 0))
	# combine (tg MutationCombiner): other stored mutations by name
	if src in ["console", "disk"]:
		var names := {}
		for x in disk_list + console_list:
			if x["Name"] != mut["Name"] and not names.has(x["Name"]):
				names[x["Name"]] = x["ByondRef"]
		var cr := _actions(parent)
		cr.add_child(UITheme.label("Combine with:", UITheme.SMALL, TGUI.LABEL))
		var cdis: bool = src == "disk" and (not d.get("hasDisk", false) or int(d.get("diskCapacity", 0)) <= 0 or d.get("diskReadOnly", true))
		if names.is_empty():
			cr.add_child(UITheme.label("nothing stored", UITheme.SMALL, TGUI.LABEL))
		for nm in names:
			var first: int = names[nm]
			TGUI.button(cr, nm, func(): act.call("combine_" + src, {"firstref": first, "secondref": ref}), false, cdis)
	if src in ["occupant", "disk", "console"]:
		# add to an advanced injector
		if not con.injector_selection.is_empty():
			var ar := _actions(parent)
			ar.add_child(UITheme.label("Add to injector:", UITheme.SMALL, TGUI.LABEL))
			for inj in con.injector_selection:
				var nm2: String = inj
				TGUI.button(ar, nm2, func(): act.call("add_advinj_mut", {"mutref": ref, "advinj": nm2, "source": src}), false, not active)
		var pr := _actions(parent)
		var inj_ok: bool = d.get("isInjectorReady", false) and active and cls != CDnaConsole.CLASS_OTHER
		TGUI.button(pr, "Print Activator", func(): act.call("print_injector", {"mutref": ref, "is_activator": 1, "source": src}), false, not inj_ok)
		TGUI.button(pr, "Print Mutator", func(): act.call("print_injector", {"mutref": ref, "is_activator": 0, "source": src}), false, not inj_ok)
		if src == "occupant":
			TGUI.button(pr, "CRISPR [%d]" % int(d.get("crisprCharges", 0)), func(): act.call("set_view", {"crisprMutationRef": ref}), false, not active or not d.get("isCrisprReady", false) or not con.occ_dna().mutation_index.has(mut["Id"]))
			if int(con.view.get("crisprMutationRef", 0)) == ref and ref != 0:
				_crispr_editor(con, parent, act, ref, d.get("isCrisprReady", false))
	var sr := _actions(parent)
	if src in ["disk", "occupant"]:
		var saved := console_list.any(func(x): return _same(x, mut))
		TGUI.button(sr, "Save to Console", func(): act.call("save_console", {"mutref": ref, "source": src}), false, saved or not active or cls == CDnaConsole.CLASS_OTHER)
	if src in ["console", "occupant"]:
		var saved2 := disk_list.any(func(x): return _same(x, mut))
		var ddis: bool = saved2 or not d.get("hasDisk", false) or int(d.get("diskCapacity", 0)) <= 0 or d.get("diskReadOnly", true) or not active or cls == CDnaConsole.CLASS_OTHER
		TGUI.button(sr, "Save to Disk", func(): act.call("save_disk", {"mutref": ref, "source": src}), false, ddis)
	if src in ["console", "disk", "injector"]:
		TGUI.button(sr, "Delete from %s" % src, func(): act.call("delete_%s_mut" % src, {"mutref": ref}), false, false, TGUI.BAD)
	if cls == CDnaConsole.CLASS_MUTATOR or (mut.get("Scrambled", false) and src == "occupant"):
		TGUI.button(sr, "Nullify", func(): act.call("nullify", {"mutref": ref}))
	_chromosome_info(parent, mut, src != "occupant", act)
	if src in ["console", "disk", "injector"]:
		var sequence := TGUI.section(parent, "Stored sequence")
		_genome(sequence, {"Sequence": mut["Sequence"], "ReadOnly": true}, act)

## tg ChromosomeInfo
static func _chromosome_info(parent: Control, mut: Dictionary, disabled: bool, act: Callable) -> void:
	var line := ColorRect.new()
	line.color = Color(TGUI.LABEL, 0.25)
	line.custom_minimum_size = Vector2(0, 1)
	parent.add_child(line)
	match int(mut.get("CanChromo", Genetics.CHROMOSOME_NEVER)):
		Genetics.CHROMOSOME_NEVER:
			parent.add_child(UITheme.label("No compatible chromosomes", UITheme.SMALL, TGUI.LABEL))
		Genetics.CHROMOSOME_NONE:
			if disabled:
				parent.add_child(UITheme.label("No chromosome applied.", UITheme.SMALL, TGUI.LABEL))
				return
			var valid: Array = mut.get("ValidStoredChromos", [])
			var r := _actions(parent)
			if valid.is_empty():
				r.add_child(UITheme.label("No Suitable Chromosomes", UITheme.SMALL, TGUI.LABEL))
			for c in valid:
				var cn: String = c
				TGUI.button(r, "Apply " + cn, func(): act.call("apply_chromo", {"chromo": cn, "mutref": mut["ByondRef"]}))
			parent.add_child(UITheme.label("Compatible with: %s" % mut.get("ValidChromos", ""), UITheme.SMALL, TGUI.LABEL))
		Genetics.CHROMOSOME_USED:
			parent.add_child(UITheme.label("Applied chromosome: %s" % mut.get("AppliedChromo", ""), UITheme.SMALL, TGUI.LABEL))

# ------------------------------------------------------------------ DnaConsoleStorage.jsx
static func _storage(con: CDnaConsole, d: Dictionary, body: Control, act: Callable) -> void:
	var mode := str(con.view.get("storageMode", "console"))
	var cons_sub := str(con.view.get("storageConsSubMode", "mutations"))
	var disk_sub := str(con.view.get("storageDiskSubMode", "mutations"))
	var btns := []
	if mode == "console":
		btns.append(_mk_btn("Mutations", func(): act.call("set_view", {"storageConsSubMode": "mutations"}), cons_sub == "mutations"))
		btns.append(_mk_btn("Chromosomes", func(): act.call("set_view", {"storageConsSubMode": "chromosomes"}), cons_sub == "chromosomes"))
	elif mode == "disk":
		btns.append(_mk_btn("Mutations", func(): act.call("set_view", {"storageDiskSubMode": "mutations"}), disk_sub == "mutations"))
		btns.append(_mk_btn("Enzymes", func(): act.call("set_view", {"storageDiskSubMode": "diskenzymes"}), disk_sub == "diskenzymes"))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	btns.append(gap)
	btns.append(_mk_btn("Console", func(): act.call("set_view", {"storageMode": "console", "storageConsSubMode": "mutations"}), mode == "console"))
	btns.append(_mk_btn("Disk", func(): act.call("set_view", {"storageMode": "disk", "storageDiskSubMode": "mutations"}), mode == "disk", not d.get("hasDisk", false)))
	btns.append(_mk_btn("Adv. Injector", func(): act.call("set_view", {"storageMode": "injector"}), mode == "injector"))
	var sec := TGUI.section(body, "Storage", btns)
	match mode:
		"console":
			if cons_sub == "chromosomes":
				_chromosomes(con, sec, act)
			else:
				var list := []
				for m in con.stored_mutations:
					list.append(_stored_info(con, m, "console"))
				_storage_mutations(con, d, sec, act, list, "console")
		"disk":
			var dk := con.disk()
			if dk == null:
				sec.add_child(UITheme.label("No disk inserted.", UITheme.SMALL, TGUI.LABEL))
			elif disk_sub == "diskenzymes":
				_makeup_info(sec, dk.genetic_makeup_buffer)
				TGUI.button(sec, "Delete", func(): act.call("del_makeup_disk"), false, not d.get("diskHasMakeup", false) or d.get("diskReadOnly", true), TGUI.BAD)
			else:
				var list2 := []
				for m in dk.mutations:
					list2.append(_stored_info(con, m, "disk"))
				_storage_mutations(con, d, sec, act, list2, "disk")
		"injector":
			_adv_injectors(con, d, sec, act)

static func _storage_mutations(con: CDnaConsole, d: Dictionary, parent: Control, act: Callable, muts: Array, mode: String) -> void:
	var key := "storage%sMutationRef" % mode
	var ref := int(con.view.get(key, 0))
	var mut: Dictionary = {}
	for m in muts:
		if int(m["ByondRef"]) == ref:
			mut = m
	if mut.is_empty() and not muts.is_empty():
		mut = muts[0]
		ref = int(mut["ByondRef"])
	var r := TGUI.row(parent, 8)
	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size = Vector2(140, 0)
	tabs.add_theme_constant_override("separation", 2)
	r.add_child(tabs)
	if muts.is_empty():
		tabs.add_child(UITheme.label("Empty.", UITheme.SMALL, TGUI.LABEL))
	for m in muts:
		var mr: int = m["ByondRef"]
		var b := TGUI.button(tabs, m["Name"], func(): act.call("set_view", {key: mr}), mr == ref, false, _quality_col(int(m.get("Quality", 0))))
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(right)
	var info := TGUI.section(right, "Mutation Info")
	_mutation_info(con, d, info, act, mut)

## tg StorageChromosomes
static func _chromosomes(con: CDnaConsole, parent: Control, act: Callable) -> void:
	var sel := str(con.view.get("storageChromoName", ""))
	var counts := {}
	for c in con.stored_chromosomes:
		var nm: String = CChromosome.NAMES[c]
		counts[nm] = counts.get(nm, 0) + 1
	var r := TGUI.row(parent, 8)
	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size = Vector2(140, 0)
	r.add_child(tabs)
	if counts.is_empty():
		tabs.add_child(UITheme.label("No chromosomes.", UITheme.SMALL, TGUI.LABEL))
	for nm in counts:
		var n2: String = nm
		TGUI.button(tabs, n2, func(): act.call("set_view", {"storageChromoName": n2}), n2 == sel)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(right)
	var info := TGUI.section(right, "Chromosome Info")
	if not counts.has(sel):
		info.add_child(UITheme.label("Nothing to show.", UITheme.SMALL, TGUI.LABEL))
		return
	var kind := ""
	for k in CChromosome.NAMES:
		if CChromosome.NAMES[k] == sel:
			kind = k
	var g := TGUI.list(info)
	TGUI.item(g, "Name", sel)
	var dl := TGUI.item(g, "Description", CChromosome.DESCS.get(kind, ""))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TGUI.item(g, "Amount", str(counts[sel]))
	TGUI.button(info, "Eject Chromosome", func(): act.call("eject_chromo", {"chromo": sel}))

## tg DnaConsoleAdvancedInjectors
static func _adv_injectors(con: CDnaConsole, d: Dictionary, parent: Control, act: Callable) -> void:
	var i := 0
	for nm in con.injector_selection:
		var n2: String = nm
		var right := [_mk_btn("Print", func(): act.call("print_adv_inj", {"name": n2}), false, not d.get("isInjectorReady", false) or con.injector_selection[nm].is_empty()),
			_mk_btn("X", func(): act.call("del_adv_inj", {"name": n2}), false, false, TGUI.BAD)]
		var sec := TGUI.section(parent, n2, right)
		var instability := 0.0
		for m in con.injector_selection[nm]:
			instability += m.instability * m.stab()
		sec.add_child(UITheme.label("%d/%d mutations ? %.1f/%.0f instability" % [con.injector_selection[nm].size(), con.max_injector_mutations, instability, con.max_injector_instability], UITheme.SMALL, TGUI.LABEL))
		var list := []
		for m in con.injector_selection[nm]:
			list.append(_stored_info(con, m, "injector"))
		_storage_mutations(con, d, sec, act, list, "injectoradvinj%d" % i)
		i += 1
	var r := TGUI.row(parent, 4)
	var le := LineEdit.new()
	le.placeholder_text = "injector name"
	le.custom_minimum_size = Vector2(200, 0)
	var full := con.injector_selection.size() >= con.max_injector_selections
	le.editable = not full
	r.add_child(le)
	var mk := func():
		if le.text.strip_edges() != "":
			act.call("new_adv_inj", {"name": le.text})
	le.text_submitted.connect(func(_t): mk.call())
	TGUI.button(r, "Create new injector", mk, false, full)

# ------------------------------------------------------------------ DnaConsoleEnzymes.jsx
static func _enzymes(con: CDnaConsole, d: Dictionary, body: Control, act: Callable, block: String, type: String, nm: String) -> void:
	if not d.get("isScannerConnected", false):
		TGUI.notice(body, "DNA Scanner is not connected.", "bad")
		return
	var top := TGUI.row(body, 8)
	var col1 := VBoxContainer.new()
	top.add_child(col1)
	# PulseSettings
	var ps := TGUI.section(col1, "Emitter Configuration")
	var g := TGUI.list(ps)
	TGUI.item_ctrl(g, "Output level", TGUI.stepper(null, con.pulse_strength, [["-", -1], ["+", 1]], "%d",
		func(dv): act.call("set_pulse_strength", {"val": clampi(con.pulse_strength + dv, 1, CDnaConsole.GENETIC_DAMAGE_STRENGTH_MAX)}), d.get("isPulsing", false)))
	TGUI.item_ctrl(g, "Pulse duration", TGUI.stepper(null, con.pulse_duration, [["-", -1], ["+", 1]], "%d",
		func(dv): act.call("set_pulse_duration", {"val": clampi(con.pulse_duration + dv, 1, CDnaConsole.GENETIC_DAMAGE_DURATION_MAX)}), d.get("isPulsing", false)))
	# PulseEmitterProbs
	var pp := TGUI.section(col1, "Probabilities")
	var g2 := TGUI.list(pp)
	var sd: float = d.get("stdDevStr", 1.0)
	TGUI.item(g2, "Accuracy", str(d.get("stdDevAcc", "")))
	TGUI.item(g2, "P(±%s)" % str(sd), "68 %")
	TGUI.item(g2, "P(±%s)" % str(sd * 2.0), "95 %")
	# PulseBoard
	var col2 := VBoxContainer.new()
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(col2)
	var pb := TGUI.section(col2, "Unique %s" % nm)
	if block == "":
		pb.add_child(UITheme.label("No viable subject found in DNA Scanner.", UITheme.SMALL, TGUI.AVERAGE))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 4)
	pb.add_child(flow)
	var i := 0
	while i < block.length():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		flow.add_child(col)
		for k in 3:
			if i + k >= block.length():
				break
			var idx := i + k
			var b := TGUI.button(col, block[idx], func(): act.call("makeup_pulse", {"index": idx + 1, "type": type}), con.pulse_index == idx + 1 and con.pulse_type == type and d.get("isPulsing", false), d.get("isPulsing", false) or not d.get("isViableSubject", false))
			b.custom_minimum_size = Vector2(22, 20)
		i += 3
	_makeup_buffers(con, d, body, act)

## tg GeneticMakeupBuffers
static func _makeup_buffers(con: CDnaConsole, d: Dictionary, body: Control, act: Callable) -> void:
	var sec := TGUI.section(body, "Genetic Makeup Buffers")
	var cd: float = d.get("geneticMakeupCooldown", 0.0)
	if cd > 0.0:
		TGUI.notice(sec, "Genetic makeup transfer ready in... %ds" % int(ceil(cd)), "warn")
	var viable: bool = d.get("isViableSubject", false)
	for i in range(1, CDnaConsole.NUMBER_OF_BUFFERS + 1):
		var slot = con.genetic_makeup_buffer[i - 1]
		var idx := i
		var right := []
		if d.get("hasDisk", false) and d.get("diskHasMakeup", false):
			right.append(_mk_btn("Import from disk", func(): act.call("load_makeup_disk", {"index": idx})))
		right.append(_mk_btn("Save", func(): act.call("save_makeup_console", {"index": idx}), false, not viable))
		right.append(_mk_btn("X", func(): act.call("del_makeup_console", {"index": idx}), false, not slot is Dictionary, TGUI.BAD))
		var title: String = (slot.get("label", slot.get("name", "")) if slot is Dictionary else "Slot %d" % i)
		var s := TGUI.section(sec, title, right)
		if d.get("heldScannerMakeup", false):
			TGUI.button(s, "Import from handheld", func(): act.call("import_scanner_makeup", {"index": idx}))
		if not slot is Dictionary:
			s.add_child(UITheme.label("No stored subject data.", UITheme.SMALL, TGUI.AVERAGE))
			continue
		_makeup_info(s, slot)
		s.add_child(UITheme.label("Makeup Actions", UITheme.SMALL, TGUI.LABEL))
		var apply_action := "makeup_apply" if viable else "makeup_delay"
		var g := TGUI.list(s)
		for row in [["Enzymes", "ue"], ["Identity", "ui"], ["Features", "uf"], ["Full Makeup", "mixed"]]:
			var ty: String = row[1]
			var r := TGUI.row(null, 3)
			TGUI.button(r, "Print", func(): act.call("makeup_injector", {"index": idx, "type": ty}), false, not d.get("isInjectorReady", false) or cd > 0.0)
			TGUI.button(r, "Transfer" + ("" if viable else " (Delayed)"), func(): act.call(apply_action, {"index": idx, "type": ty}), false, viable and cd > 0.0)
			TGUI.item_ctrl(g, row[0], r)
		TGUI.button(s, "Export To Disk", func(): act.call("save_makeup_disk", {"index": idx}), false, not d.get("hasDisk", false) or d.get("diskReadOnly", true))

## tg GeneticMakeupInfo
static func _makeup_info(parent: Control, mk: Dictionary) -> void:
	var s := TGUI.section(parent, "Enzyme Information")
	var g := TGUI.list(s)
	for row in [["Name", "name"], ["Blood Type", "blood_type"], ["Unique Enzyme", "UE"], ["Unique Identifier", "UI"], ["Unique Features", "UF"]]:
		var v := TGUI.item(g, row[0], str(mk.get(row[1], "")) if str(mk.get(row[1], "")) != "" else "None")
		v.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		v.custom_minimum_size = Vector2(300, 0)

# ------------------------------------------------------------------ helpers
static func _actions(parent: Control) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	parent.add_child(flow)
	return flow

static func _crispr_editor(con: CDnaConsole, parent: Control, act: Callable, ref: int, ready: bool) -> void:
	var sec := TGUI.section(parent, "CRISPR replacement")
	TGUI.notice(sec, "Enter 32 bases (A/T/C/G), alternating original and replacement base pairs. An incorrect code can cause a harmful mutation and disease.", "warn")
	var le := LineEdit.new()
	le.name = "CrisprSequence"
	le.placeholder_text = "32-base replacement code"
	le.max_length = 32
	le.text = str(con.view.get("crisprSequence", ""))
	sec.add_child(le)
	var row := _actions(sec)
	var submit := TGUI.button(row, "Apply replacement", func():
		if act.call("crispr", {"mutref": ref, "source": "occupant", "sequence": le.text}):
			act.call("set_view", {"crisprMutationRef": 0, "crisprSequence": ""})
		else:
			Game.tell(Game.player, "Replacement failed. Check the selected patient and CRISPR charges.", "warn"), false, not ready or not _valid_crispr(le.text))
	TGUI.button(row, "Cancel", func(): act.call("set_view", {"crisprMutationRef": 0, "crisprSequence": ""}))
	le.text_changed.connect(func(text):
		con.view["crisprSequence"] = text
		submit.disabled = not ready or not _valid_crispr(text))
	le.text_submitted.connect(func(_text):
		if not submit.disabled:
			submit.pressed.emit())

static func _valid_crispr(text: String) -> bool:
	if text.length() != 32:
		return false
	for ch in text.to_upper():
		if not ch in "ATCG":
			return false
	return true

static func _mk_btn(text: String, cb: Callable, selected := false, disabled := false, tone := Color(0, 0, 0, 0)) -> Button:
	var holder := Control.new()
	var b := TGUI.button(holder, text, cb, selected, disabled, tone)
	holder.remove_child(b)
	holder.free()
	return b

# ------------------------------------------------------------------ telepathy (tg list_target spell)
## Who you can reach (in view, within range), and the message to send them.
static func _list_target(caster: Entity, body: VBoxContainer, w: UIWindow) -> void:
	var r: int = GenePowers.DEFS["telepathy"].get("range", 7)
	var le := LineEdit.new()
	le.placeholder_text = "What do you wish to whisper to them?"
	body.add_child(le)
	var targets := []
	for m in Game.in_radius(caster.cell, r, &"mob"):
		if m != caster and m.has_c(&"health") and not m.c(&"health").dead and Game.lighting.player_can_see(m.cell):
			targets.append(m)
	if targets.is_empty():
		TGUI.notice(body, "There's no one in view to reach.", "warn")
		return
	var g := TGUI.list(body)
	for m in targets:
		var who: Entity = m
		var btn := TGUI.row(null, 3)
		TGUI.button(btn, "Send", func():
			GenePowers.telepathy(caster, who, le.text)
			if w and is_instance_valid(w):
				w.queue_free())
		TGUI.item_ctrl(g, who.display_name, btn)
