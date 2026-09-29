class_name CDnaConsole extends Component
## tg /obj/machinery/computer/dna_console (code/game/machinery/computer/dna_console.dm).
## Every ui_act action is here under tg's name (`act`); the window (WindowsDna) only reads
## this state and calls `act`, like tg's DnaConsole tgui.
##
## It links to a DNA scanner beside it. With someone viable inside you can sequence their
## eight genes (a pulse per letter, 1 genetic damage each), discover mutations, print
## activators and mutators, keep mutations in console or disk storage, combine them by
## recipe, apply chromosomes, scramble their DNA, pulse their identity and feature blocks
## with radiation, and save, print and transfer whole genetic makeups.

const MIN_ACTIVATOR_TIMEOUT := 5.0
const ACTIVATOR_COOLDOWN_MULTIPLIER := 0.25
const MIN_INJECTOR_TIMEOUT := 10.0
const INJECTOR_COOLDOWN_MULTIPLIER := 0.15
const MIN_ADVANCED_TIMEOUT := 15.0
const ADVANCED_COOLDOWN_MULTIPLIER := 0.1
const ADVANCED_INJECTOR_MAX_COOLDOWN := 90.0
const MISC_INJECTOR_TIMEOUT := 60.0
const NUMBER_OF_BUFFERS := 3
const SCRAMBLE_TIMEOUT := 60.0
const JOKER_TIMEOUT := 1200.0
const JOKER_UPGRADE := 300.0
const GENETIC_DAMAGE_STRENGTH_MAX := 15
const GENETIC_DAMAGE_STRENGTH_MULTIPLIER := 1.0
const GENETIC_DAMAGE_DURATION_MAX := 30
const GENETIC_DAMAGE_ACCURACY_MULTIPLIER := 3.0
const ENZYME_COPY_BASE_COOLDOWN := 60.0

const SEARCH_OCCUPANT := 1
const SEARCH_STORED := 2
const SEARCH_DISKETTE := 4
const SEARCH_ADV_INJ := 8

const CLEAR_GENE := 0
const NEXT_GENE := 1
const PREV_GENE := 2

const CLASS_ACTIVATOR := 1 # tg SCANNER_MUTATION_CLASS_ACTIVATOR
const CLASS_MUTATOR := 2
const CLASS_OTHER := 3

const STATUS_TRANSFORMING := 5
## tg subject status numbers (CONSCIOUS, SOFT_CRIT, UNCONSCIOUS, HARD_CRIT, DEAD)
const SUBJECT_CONSCIOUS := 0
const SUBJECT_SOFT_CRIT := 1
const SUBJECT_UNCONSCIOUS := 2
const SUBJECT_HARD_CRIT := 3
const SUBJECT_DEAD := 4

var pulse_duration := 2
var pulse_strength := 1
var genetic_makeup_buffer: Array = [null, null, null]
var stored_mutations: Array = [] # Mutation
var stored_chromosomes: Array = [] # chromosome kinds ("stabilizer", ...)
var injector_selection := {} # name -> Array of Mutation
var max_injector_selections := 2
var max_injector_mutations := 10
var max_injector_instability := 50.0
var injector_ready := 0.0
var joker_ready := 0.0
var scramble_ready := 0.0
var diskette: Entity = null
var delayed_action = null # {type, buffer_slot}
var pulse_index := 0 # 1-based, 0 = no pulse
var pulse_timer := 0.0
var pulse_type := ""
var pulse_subject: Entity = null
var pulse_started_at := 0.0
var pulse_seconds := 0.0
var enzyme_copy_ready := 0.0
var crispr_charges := 0
var view := {} # tg tgui_view_state
var connected_scanner: Entity = null
var scanner_occupant: Entity = null

func key() -> StringName:
	return &"dnaconsole"

func setup(_p: Dictionary) -> CDnaConsole:
	return self

## tg Initialize: link to a scanner, start the timers, the default view
func on_added() -> void:
	injector_ready = Game.time + MISC_INJECTOR_TIMEOUT
	scramble_ready = Game.time + SCRAMBLE_TIMEOUT
	joker_ready = Game.time + JOKER_TIMEOUT
	enzyme_copy_ready = Game.time + ENZYME_COPY_BASE_COOLDOWN
	set_default_state()

func set_default_state() -> void:
	view["consoleMode"] = "storage"
	view["storageMode"] = "console"
	view["storageConsSubMode"] = "mutations"
	view["storageDiskSubMode"] = "mutations"

func operable() -> bool:
	var m: CMachine = e.c(&"machine")
	return m == null or m.operable()

# ------------------------------------------------------------------ the scanner
func scanner() -> CDnaScanner:
	if connected_scanner == null or not is_instance_valid(connected_scanner) or connected_scanner.removed:
		connected_scanner = null
		return null
	return connected_scanner.c(&"dnascanner")

## tg connect_to_scanner: a working scanner in a cardinal direction, else a broken one
func connect_to_scanner() -> void:
	var broken: Entity = null
	for d in Defs.DIRS4:
		for x in Game.at(e.cell + d):
			if x.has_c(&"dnascanner"):
				if x.c(&"dnascanner").operational():
					set_connected_scanner(x)
					return
				broken = x
	if broken:
		set_connected_scanner(broken)

func set_connected_scanner(s: Entity) -> void:
	if connected_scanner != s:
		on_scanner_open()
	var old := scanner()
	if old and old.linked_console == e:
		old.linked_console = null
	connected_scanner = s
	if s:
		s.c(&"dnascanner").linked_console = e

## tg scanner_operational
func scanner_operational() -> bool:
	var s := scanner()
	return s != null and s.operational()

## tg can_modify_occupant: an operational scanner with someone with DNA in it
func can_modify_occupant() -> bool:
	scanner_occupant = null
	if not scanner_operational():
		return false
	var s := scanner()
	if s.state_open or not is_instance_valid(s.occupant) or s.occupant.removed or s.occupant.cell != s.e.cell:
		return false
	scanner_occupant = s.occupant
	return scanner_occupant.has_c(&"dna") and scanner_occupant.has_c(&"health") and not Traits.has(scanner_occupant, "animal_body") and (s.scan_level >= 3 or (not Traits.has(scanner_occupant, "geneless") and not Traits.has(scanner_occupant, "baddna")))

func occ_dna() -> CDna:
	return scanner_occupant.c(&"dna") if scanner_occupant else null

## tg on_scanner_close: the delayed makeup transfer happens now
func on_scanner_close() -> void:
	var s := scanner()
	scanner_occupant = s.occupant if s else null
	if delayed_action != null and can_modify_occupant() and Game.time >= enzyme_copy_ready:
		if apply_genetic_makeup(delayed_action["type"], delayed_action["buffer_slot"], null):
			Game.tell(s.occupant, "%s activates!" % e.the().capitalize())
		delayed_action = null

## tg on_scanner_open: an enzyme pulse in progress stops, like a microwave
func on_scanner_open() -> void:
	pulse_index = 0
	pulse_timer = 0.0
	pulse_type = ""
	pulse_subject = null
	scanner_occupant = null

## Once a second: the delayed enzyme pulse (tg process)
func tick(_dt: float) -> void:
	if not operable():
		on_scanner_open()
		return
	if scanner() == null:
		connect_to_scanner()
	if pulse_index > 0 and pulse_timer <= Game.time and pulse_type in ["ui", "uf"]:
		genetic_damage_pulse()

func _use_energy() -> void:
	var m: CMachine = e.c(&"machine")
	if m and m.has_method("use_power"):
		m.use_power(1000.0)

# ------------------------------------------------------------------ what the window reads
## tg ui_data (the parts the window needs as numbers and flags)
func data(user: Entity) -> Dictionary:
	var d := {}
	var op := scanner_operational()
	var viable := can_modify_occupant()
	d["isScannerConnected"] = op
	if op:
		var s := scanner()
		d["scannerOpen"] = s.state_open
		d["scannerLocked"] = s.locked
		d["stdDevStr"] = pulse_strength * GENETIC_DAMAGE_STRENGTH_MULTIPLIER
		var acc := GENETIC_DAMAGE_ACCURACY_MULTIPLIER / (pulse_duration + pow(s.precision_coeff, 2))
		if acc >= 0.0 and acc <= 0.25: d["stdDevAcc"] = ">95 %"
		elif acc >= 0.25 and acc <= 0.5: d["stdDevAcc"] = "68-95 %"
		elif acc >= 0.5 and acc <= 0.75: d["stdDevAcc"] = "55-68 %"
		else: d["stdDevAcc"] = "<38 %"
	d["isViableSubject"] = viable
	if viable:
		var h: CHealth = scanner_occupant.c(&"health")
		var dn := occ_dna()
		d["subjectName"] = scanner_occupant.display_name
		d["subjectStatus"] = STATUS_TRANSFORMING if dn.transforming() else subject_status(h)
		d["subjectHealth"] = h.health()
		d["subjectEnzymes"] = dn.unique_enzymes
		d["isMonkey"] = Traits.has(scanner_occupant, "lesser_humanoid")
		d["subjectUNI"] = dn.unique_identity
		d["subjectUF"] = dn.unique_features
		d["subjectDamage"] = dn.genetic_damage_percent()
	d["hasDelayedAction"] = delayed_action != null
	d["isScrambleReady"] = Game.time >= scramble_ready
	d["scrambleSeconds"] = maxi(0, int(ceil(scramble_ready - Game.time)))
	d["isJokerReady"] = Game.time >= joker_ready
	d["jokerSeconds"] = maxi(0, int(ceil(joker_ready - Game.time)))
	d["isInjectorReady"] = Game.time >= injector_ready
	d["injectorSeconds"] = maxi(0, int(ceil(injector_ready - Game.time)))
	d["isPulsing"] = pulse_index > 0
	d["timeToPulse"] = maxi(0, int(ceil(pulse_timer - Game.time)))
	d["pulseProgress"] = clampf((Game.time - pulse_started_at) / maxf(pulse_seconds, 0.001), 0.0, 1.0) if pulse_index > 0 else 0.0
	d["pulseTarget"] = ("Identity" if pulse_type == "ui" else "Features") + " #%02d" % pulse_index
	d["isCrisprReady"] = crispr_charges > 0
	d["crisprCharges"] = crispr_charges
	d["geneticMakeupCooldown"] = maxf(0.0, enzyme_copy_ready - Game.time)
	var dk := disk()
	d["hasDisk"] = dk != null
	d["diskCapacity"] = (dk.max_mutations - dk.mutations.size()) if dk else 0
	d["diskReadOnly"] = dk.read_only if dk else true
	d["diskHasMakeup"] = dk != null and not dk.genetic_makeup_buffer.is_empty()
	d["diskMakeupBuffer"] = dk.genetic_makeup_buffer.duplicate() if dk else {}
	d["heldScannerBuffer"] = {}
	d["heldScannerMakeup"] = _held_makeup_scanner(user) != null
	d["canScramble"] = scanner_occupant != null and not Traits.has(scanner_occupant, "no_dna_scramble")
	var inv: CInventory = user.c(&"inv") if user else null
	if inv:
		for it in inv.hands:
			if it and it.has_c(&"seqscanner") and not it.c(&"seqscanner").buffer.is_empty():
				var sb := {}
				for mid in it.c(&"seqscanner").buffer:
					sb[Genetics.alias(mid)] = it.c(&"seqscanner").buffer[mid]
				d["heldScannerBuffer"] = sb
	return d

func _held_makeup_scanner(user: Entity) -> CSeqScanner:
	var inv: CInventory = user.c(&"inv") if user else null
	if inv:
		for item in inv.hands:
			if item and item.has_c(&"seqscanner"):
				var pocket: CSeqScanner = item.c(&"seqscanner")
				if not pocket.genetic_makeup_buffer.is_empty():
					return pocket
	return null

## tg subject status: CONSCIOUS 0, SOFT_CRIT 1, UNCONSCIOUS 2, HARD_CRIT 3, DEAD 4
static func subject_status(h: CHealth) -> int:
	if h.dead:
		return SUBJECT_DEAD
	if h._hard_crit():
		return SUBJECT_HARD_CRIT
	if h.stat() == CHealth.UNCONSCIOUS:
		return SUBJECT_UNCONSCIOUS
	if h.stat() == CHealth.SOFT_CRIT:
		return SUBJECT_SOFT_CRIT
	return SUBJECT_CONSCIOUS

func disk() -> CDnaDisk:
	if diskette == null or not is_instance_valid(diskette) or diskette.removed:
		diskette = null
		return null
	return diskette.c(&"dnadisk")

func discovered(mid: String) -> bool:
	return Genetics.discovered.has(mid)

## tg build_mutation_list: the occupant's genes, then mutations they have outside them
func occupant_mutations() -> Array:
	var out := []
	if not can_modify_occupant():
		return out
	var dn := occ_dna()
	for mid in dn.mutation_index:
		var disc := discovered(mid)
		var md := {"Alias": Genetics.alias(mid), "Id": mid, "Sequence": dn.mutation_index[mid], "DefaultSeq": dn.default_mutation_genes.get(mid, ""),
			"Discovered": disc, "Source": "occupant"}
		var st := dn.get_mutation(mid)
		if disc:
			md["Name"] = Genetics.DEFS[mid]["name"]
			md["Description"] = Genetics.DEFS[mid]["desc"]
			md["Instability"] = (st.instability * st.stab()) if st else Genetics.DEFS[mid]["instability"]
			md["Quality"] = Genetics.DEFS[mid]["quality"]
		var cls := CLASS_ACTIVATOR
		if st:
			md["Active"] = true
			md["Scrambled"] = st.scrambled
			cls = mutation_class(st)
			md["Mut"] = st
		else:
			md["Active"] = false
			md["Scrambled"] = false
		md["Class"] = cls
		md["Image"] = "extra" if cls == CLASS_MUTATOR else ("discovered" if disc else "undiscovered")
		out.append(md)
	for m in dn.mutations:
		if dn.mutation_index.has(m.id):
			continue
		var cls2 := mutation_class(m)
		out.append({"Alias": Genetics.alias(m.id), "Id": m.id, "Sequence": Genetics.sequence(m.id), "Discovered": true, "Quality": m.quality(), "Source": "occupant",
			"Name": m.name(), "Description": m.def()["desc"], "Instability": m.instability * m.stab(), "Active": true, "Scrambled": m.scrambled, "Class": cls2,
			"Mut": m, "Image": "extra" if cls2 == CLASS_MUTATOR else "discovered"})
	return out

## tg get_mutation_class
static func mutation_class(m: Mutation) -> int:
	for s in m.sources:
		if not s in Genetics.STANDARD_SOURCES:
			return CLASS_OTHER
	if Genetics.SRC_ACTIVATED in m.sources:
		return CLASS_ACTIVATOR
	if Genetics.SRC_MUTATOR in m.sources:
		return CLASS_MUTATOR
	return 0

## tg build_chrom_list: the stored chromosomes that fit this mutation
func chrom_list(m: Mutation) -> Array:
	var out := []
	for c in stored_chromosomes:
		var nm: String = CChromosome.NAMES[c]
		if CChromosome.can_apply(c, m) and not nm in out:
			out.append(nm)
	return out

## tg get_mut_by_ref
func get_mut_by_ref(uid: int, flags: int) -> Mutation:
	if flags & SEARCH_OCCUPANT and scanner_occupant and occ_dna():
		for m in occ_dna().mutations:
			if m.uid == uid:
				return m
	if flags & SEARCH_STORED:
		for m in stored_mutations:
			if m.uid == uid:
				return m
	var dk := disk()
	if dk and flags & SEARCH_DISKETTE:
		for m in dk.mutations:
			if m.uid == uid:
				return m
	if flags & SEARCH_ADV_INJ:
		for k in injector_selection:
			for m in injector_selection[k]:
				if m.uid == uid:
					return m
	return null

func _search_flags(source: String, allow_occ := true) -> int:
	match source:
		"occupant":
			return SEARCH_OCCUPANT if allow_occ and can_modify_occupant() else 0
		"console":
			return SEARCH_STORED
		"disk":
			return SEARCH_DISKETTE
	return 0

func _say(text: String) -> void:
	Game.visible_message(e.cell, "[b]%s[/b] beeps, \"%s\"" % [e.display_name, text], "info")
	Bus.speech.emit(e, text, e.cell, 5.0)

# ------------------------------------------------------------------ tg ui_act
func act(action: String, params: Dictionary, user: Entity) -> bool:
	if action == "open_tutorial":
		if user == Game.player and Game.hud:
			Game.hud.open_window("dna_tutorial", e)
		return true
	if not operable():
		return false
	Forensics.touch(e, user)
	match action:
		"connect_scanner":
			connect_to_scanner()
		"toggle_door":
			if scanner_operational():
				scanner().toggle_open(user)
		"toggle_lock":
			if scanner_operational() and not scanner().state_open:
				scanner().locked = not scanner().locked
		"scramble_dna":
			if not can_modify_occupant() or Game.time < scramble_ready or pulse_index > 0 or Traits.has(scanner_occupant, "no_dna_scramble"):
				return false
			var dn := occ_dna()
			dn.remove_all_mutations()
			dn.generate_dna_blocks()
			scramble_ready = Game.time + SCRAMBLE_TIMEOUT
			Game.tell(user, "DNA scrambled.")
			dn.add_genetic_damage(GENETIC_DAMAGE_STRENGTH_MULTIPLIER * 50.0 / pow(scanner().damage_coeff, 2))
			_use_energy()
		"check_discovery":
			if can_modify_occupant() and scanner_occupant == scanner().occupant:
				check_discovery(params.get("alias", ""))
		"all_check_discovery":
			if can_modify_occupant() and scanner_occupant == scanner().occupant:
				for mid in occ_dna().mutation_index.keys():
					check_discovery(Genetics.alias(mid))
		"pulse_gene":
			return _pulse_gene(params, user)
		"apply_chromo":
			if not can_modify_occupant() or scanner_occupant != scanner().occupant:
				return false
			var m := get_mut_by_ref(int(params.get("mutref", 0)), SEARCH_OCCUPANT)
			if m == null:
				return false
			for c in stored_chromosomes.duplicate():
				if CChromosome.can_apply(c, m) and CChromosome.NAMES[c] == params.get("chromo", ""):
					stored_chromosomes.erase(c)
					CChromosome.apply(c, m)
					break
			_use_energy()
		"crispr":
			return _crispr(params, user)
		"print_injector":
			return _print_injector(params, user)
		"save_console":
			var m2 := get_mut_by_ref(int(params.get("mutref", 0)), _search_flags(params.get("source", ""))) if params.get("source", "") != "console" else null
			if m2 == null:
				return false
			if not m2.sources.is_empty() and mutation_class(m2) == CLASS_OTHER:
				_say("ERROR: This mutation is anomalous, and cannot be saved.")
				return false
			stored_mutations.append(m2.make_copy())
			Game.tell(user, "Mutation successfully stored.")
		"save_disk":
			var dk := disk()
			if dk == null:
				return false
			if dk.mutations.size() >= dk.max_mutations:
				Game.tell(user, "Disk storage is full.", "warn")
				return false
			if dk.read_only:
				Game.tell(user, "Disk is set to read only mode.", "warn")
				return false
			var src: String = params.get("source", "")
			var m3 := get_mut_by_ref(int(params.get("mutref", 0)), _search_flags(src) if src != "disk" else 0)
			if m3 == null:
				return false
			if not m3.sources.is_empty() and mutation_class(m3) == CLASS_OTHER:
				_say("ERROR: This mutation is anomalous, and cannot be saved.")
				return false
			dk.mutations.append(m3.make_copy())
			Game.tell(user, "Mutation successfully stored to disk.")
		"nullify":
			if not can_modify_occupant():
				return false
			var m4 := get_mut_by_ref(int(params.get("mutref", 0)), SEARCH_OCCUPANT)
			if m4 == null or (not m4.scrambled and not Genetics.SRC_MUTATOR in m4.sources):
				return false
			var types := [Genetics.SRC_MUTATOR]
			if m4.scrambled:
				types.append(Genetics.SRC_ACTIVATED)
			occ_dna().remove_mutation(m4.id, types)
			m4.scrambled = false
		"delete_console_mut":
			var m5 := get_mut_by_ref(int(params.get("mutref", 0)), SEARCH_STORED)
			if m5:
				stored_mutations.erase(m5)
		"delete_disk_mut":
			var dk2 := disk()
			if dk2 == null:
				return false
			if dk2.read_only:
				Game.tell(user, "Disk is set to read only mode.", "warn")
				return false
			var m6 := get_mut_by_ref(int(params.get("mutref", 0)), SEARCH_DISKETTE)
			if m6:
				dk2.mutations.erase(m6)
		"eject_chromo":
			for c in stored_chromosomes:
				if CChromosome.NAMES[c] == params.get("chromo", ""):
					stored_chromosomes.erase(c)
					Proto.spawn("chromosome_" + c, _drop_cell())
					break
		"combine_console", "combine_disk":
			return _combine(action == "combine_disk", params, user)
		"set_pulse_strength":
			if pulse_index > 0:
				return false
			pulse_strength = _wrap(int(round(float(params.get("val", 1)))), 1, GENETIC_DAMAGE_STRENGTH_MAX + 1)
		"set_pulse_duration":
			if pulse_index > 0:
				return false
			pulse_duration = _wrap(int(round(float(params.get("val", 1)))), 1, GENETIC_DAMAGE_DURATION_MAX + 1)
		"save_makeup_disk":
			var dk3 := disk()
			if dk3 == null:
				return false
			if dk3.read_only:
				Game.tell(user, "Disk is set to read only mode.", "warn")
				return false
			var slot = genetic_makeup_buffer[clampi(int(params.get("index", 1)), 1, NUMBER_OF_BUFFERS) - 1]
			if not slot is Dictionary:
				return false
			dk3.genetic_makeup_buffer = slot.duplicate()
		"load_makeup_disk":
			var dk4 := disk()
			if dk4 == null or dk4.genetic_makeup_buffer.is_empty():
				return false
			genetic_makeup_buffer[clampi(int(params.get("index", 1)), 1, NUMBER_OF_BUFFERS) - 1] = dk4.genetic_makeup_buffer.duplicate()
		"del_makeup_disk":
			var dk5 := disk()
			if dk5 == null:
				return false
			if dk5.read_only:
				Game.tell(user, "Disk is set to read only mode.", "warn")
				return false
			dk5.genetic_makeup_buffer.clear()
		"save_makeup_console":
			if not can_modify_occupant():
				return false
			var bi := clampi(int(params.get("index", 1)), 1, NUMBER_OF_BUFFERS)
			var dn2 := occ_dna()
			var om: CMob = scanner_occupant.c(&"mob")
			var oh: CHealth = scanner_occupant.c(&"health")
			genetic_makeup_buffer[bi - 1] = {"label": "Slot %d:%s" % [bi, om.real_name if om else scanner_occupant.display_name],
				"UI": dn2.unique_identity, "UE": dn2.unique_enzymes, "UF": dn2.unique_features,
				"name": om.real_name if om else scanner_occupant.display_name, "blood_type": oh.blood_type if oh else ""}
		"import_scanner_makeup":
			var pocket := _held_makeup_scanner(user)
			var index := int(params.get("index", 0))
			if pocket == null or index < 1 or index > NUMBER_OF_BUFFERS:
				return false
			genetic_makeup_buffer[index - 1] = pocket.genetic_makeup_buffer.duplicate(true)
			Game.tell(user, "You export the genetic makeup to slot %d." % index)
		"del_makeup_console":
			var bi2 := clampi(int(params.get("index", 1)), 1, NUMBER_OF_BUFFERS)
			if not genetic_makeup_buffer[bi2 - 1] is Dictionary:
				return false
			genetic_makeup_buffer[bi2 - 1] = null
		"eject_disk":
			eject_disk(user)
		"makeup_injector":
			if Game.time < enzyme_copy_ready:
				return false
			var bi3 := clampi(int(params.get("index", 1)), 1, NUMBER_OF_BUFFERS)
			if not make_cosmetic_dna_injector(str(params.get("type", "")), genetic_makeup_buffer[bi3 - 1]):
				Game.tell(user, "Genetic data corrupted, unable to create injector.", "warn")
				return false
			injector_ready = Game.time + MISC_INJECTOR_TIMEOUT
			_use_energy()
		"makeup_apply":
			if not can_modify_occupant() or Game.time < enzyme_copy_ready:
				return false
			var slot2 = genetic_makeup_buffer[clampi(int(params.get("index", 1)), 1, NUMBER_OF_BUFFERS) - 1]
			if not slot2 is Dictionary:
				return false
			if not apply_genetic_makeup(str(params.get("type", "")), slot2, user):
				return false
			_use_energy()
		"makeup_delay":
			var slot3 = genetic_makeup_buffer[clampi(int(params.get("index", 1)), 1, NUMBER_OF_BUFFERS) - 1]
			if not slot3 is Dictionary:
				return false
			delayed_action = {"type": str(params.get("type", "")), "buffer_slot": slot3.duplicate()}
		"makeup_pulse":
			if not can_modify_occupant() or pulse_index > 0:
				return false
			var ty := str(params.get("type", ""))
			if not ty in ["ui", "uf"] or occ_dna().transforming():
				return false
			var ln := occ_dna().unique_identity.length() if ty == "ui" else occ_dna().unique_features.length()
			var idx := int(params.get("index", 0))
			if idx < 1 or idx > ln:
				return false
			pulse_type = ty
			pulse_subject = scanner_occupant
			pulse_timer = Game.time + pulse_duration
			pulse_started_at = Game.time
			pulse_seconds = pulse_duration
			pulse_index = idx
			_use_energy()
		"cancel_delay":
			delayed_action = null
		"new_adv_inj":
			if injector_selection.size() >= max_injector_selections:
				return false
			var nm := str(params.get("name", "")).strip_edges().replace("[", "(").replace("]", ")")
			if nm == "" or injector_selection.has(nm):
				return false
			injector_selection[nm] = []
		"del_adv_inj":
			var nm2 := str(params.get("name", ""))
			if nm2 == "" or not injector_selection.has(nm2):
				return false
			injector_selection.erase(nm2)
		"print_adv_inj":
			return _print_adv(params, user)
		"add_advinj_mut":
			return _add_advinj(params, user)
		"delete_injector_mut":
			var m7 := get_mut_by_ref(int(params.get("mutref", 0)), SEARCH_ADV_INJ)
			if m7 == null:
				return false
			for k in injector_selection:
				if m7 in injector_selection[k]:
					injector_selection[k].erase(m7)
					break
		"set_view":
			for k in params:
				view[k] = params[k]
		_:
			return false
	return true

static func _wrap(v: int, lo: int, hi: int) -> int:
	# tg WRAP(val, min, max): into [min, max)
	var d := hi - lo
	return ((v - lo) % d + d) % d + lo

func _drop_cell() -> Vector2i:
	# tg drop_location: in front of the console
	for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		var c: Vector2i = e.cell + d
		if Game.map.inb(c) and not Game.map.blocks_move_static(c) and Game.map.dense_count[Game.map.idx(c)] == 0:
			return c
	return e.cell

## tg pulse_gene: X out, next or previous letter (or the joker's reveal)
func _pulse_gene(params: Dictionary, user: Entity) -> bool:
	const LETTERS := ["A", "T", "C", "G"]
	if not can_modify_occupant() or scanner_occupant != scanner().occupant:
		return false
	var dn := occ_dna()
	if scanner_occupant.c(&"health").dead or pulse_index > 0:
		return false
	if dn.transforming():
		Game.tell(user, "Gene pulse failed: The scanner occupant undergoing a transformation.", "warn")
		return false
	var alias: String = params.get("alias", "")
	var mid: String = Genetics.alias_to_id.get(alias, "")
	if mid == "" or not dn.mutation_index.has(mid):
		return false
	if Genetics.is_monkey(scanner_occupant) and mid != "race":
		return false
	var active_mut := dn.get_mutation(mid)
	if active_mut and (active_mut.scrambled or mutation_class(active_mut) != CLASS_ACTIVATOR):
		return false
	var sequence: String = dn.mutation_index[mid]
	var pos := int(params.get("pos", 0))
	if pos < 1 or pos > sequence.length():
		return false
	var newgene := ""
	match int(params.get("pulseAction", NEXT_GENE)):
		CLEAR_GENE:
			newgene = "X"
			var ds: String = dn.default_mutation_genes.get(mid, sequence)
			dn.default_mutation_genes[mid] = ds.substr(0, pos - 1) + "X" + ds.substr(pos)
		NEXT_GENE:
			if str(view.get("jokerActive", "")) != "" and Game.time >= joker_ready:
				newgene = Genetics.sequence(mid)[pos - 1]
				joker_ready = Game.time + JOKER_TIMEOUT - JOKER_UPGRADE * (scanner().precision_coeff - 1.0)
				view["jokerActive"] = ""
			else:
				var cur := LETTERS.find(sequence[pos - 1]) + 1 # BYOND Find: 0 = not found
				newgene = LETTERS[0] if cur == LETTERS.size() else LETTERS[cur]
		PREV_GENE:
			var cur2 := LETTERS.find(sequence[pos - 1]) + 1
			if cur2 == 0:
				cur2 = 1
			newgene = LETTERS[LETTERS.size() - 1] if cur2 == 1 else LETTERS[cur2 - 2]
		_:
			return false
	dn.mutation_index[mid] = sequence.substr(0, pos - 1) + newgene + sequence.substr(pos)
	dn.add_genetic_damage(GENETIC_DAMAGE_STRENGTH_MULTIPLIER / scanner().damage_coeff)
	dn.domutcheck()
	if not can_modify_occupant():
		return true
	check_discovery(alias)
	_use_energy()
	return true

## tg check_discovery: an active, readable mutation the station hasn't seen is discovered
func check_discovery(alias: String) -> bool:
	var mid: String = Genetics.alias_to_id.get(alias, "")
	if mid == "" or scanner_occupant == null:
		return false
	var m := occ_dna().get_mutation(mid)
	if m == null or m.scrambled:
		return false
	if not Genetics.discovered.has(mid):
		Genetics.discovered[mid] = true
		_say("Successfully discovered %s." % Genetics.DEFS[mid]["name"])
		Bus.stimulus.emit({"type": "discovery", "actor": null, "cell": e.cell, "loud": 0.0, "text": Genetics.DEFS[mid]["name"]})
		return true
	return false

## tg print_injector: an activator (research: recycles into chromosomes) or a mutator
func _print_injector(params: Dictionary, user: Entity) -> bool:
	if Game.time < injector_ready:
		return false
	var src: String = params.get("source", "")
	var m := get_mut_by_ref(int(params.get("mutref", 0)), _search_flags(src))
	if m == null:
		return false
	if not m.sources.is_empty() and mutation_class(m) == CLASS_OTHER:
		_say("ERROR: This mutation is anomalous, and cannot be printed.")
		return false
	var inj := Proto.spawn("dna_activator", _drop_cell())
	var dj: CDnaInjector = inj.c(&"dnainjector")
	dj.add_mutations.append(m.make_copy())
	var is_activator := int(params.get("is_activator", 0)) == 1
	if is_activator:
		inj.display_name = "%s activator" % m.name()
		dj.research = true
		var mult := 1.0 + ACTIVATOR_COOLDOWN_MULTIPLIER
		var base := maxf(MIN_ACTIVATOR_TIMEOUT, absf(m.instability))
		if scanner_operational():
			dj.damage_coeff = scanner().damage_coeff * 4.0
			mult -= ACTIVATOR_COOLDOWN_MULTIPLIER * scanner().precision_coeff
		injector_ready = Game.time + base * mult
	else:
		inj.display_name = "%s mutator" % m.name()
		dj.force_mutate = true
		var mult2 := 1.0 + INJECTOR_COOLDOWN_MULTIPLIER
		var base2 := maxf(MIN_INJECTOR_TIMEOUT, absf(m.instability) * 1.0)
		if scanner_operational():
			dj.damage_coeff = scanner().damage_coeff * 4.0
			mult2 -= INJECTOR_COOLDOWN_MULTIPLIER * scanner().precision_coeff
		injector_ready = Game.time + base2 * mult2
	Sfx.play("print", e.cell, 0.5)
	_use_energy()
	return true

## tg crispr: an in-vitro rewrite of an active gene from a 32 letter code whose odd
## letters spell the old sequence and even letters the new one. Viruses may follow.
func _crispr(params: Dictionary, user: Entity) -> bool:
	if not can_modify_occupant() or scanner_occupant != scanner().occupant or crispr_charges < 1:
		return false
	if params.get("source", "") != "occupant":
		return false
	var target := get_mut_by_ref(int(params.get("mutref", 0)), SEARCH_OCCUPANT)
	if target == null or not occ_dna().mutation_index.has(target.id):
		return false
	var input: String = str(params.get("sequence", "")).strip_edges().to_upper()
	if input.length() != 32:
		return false
	var old_seq := ""
	var new_seq := ""
	for i in input.length():
		var ch := input[i]
		var pair := ""
		if ch == "A" or ch == "T":
			pair = "AT"
		elif ch == "C" or ch == "G":
			pair = "CG"
		if pair == "":
			return false
		var np := ch + (pair[1] if pair[0] == ch else pair[0])
		if (i + 1) % 2 == 0:
			new_seq += np
		else:
			old_seq += np
	crispr_charges -= 1
	if new_seq != "":
		var matched := ""
		for mid in Genetics.DEFS:
			if Genetics.sequence(mid) == new_seq:
				matched = mid
		if Genetics.prob(60):
			Disease.contract_random(scanner_occupant, 2)
		elif Genetics.prob(30):
			Disease.contract_random(scanner_occupant, 3)
		var result := "acidflesh" # BAD END is the natural state if things go wrong
		if matched != "" and target and old_seq == Genetics.sequence(target.id):
			result = matched
		var dn := occ_dna()
		dn.remove_all_mutations([Genetics.SRC_ACTIVATED])
		dn.add_mutation(result, Genetics.SRC_ACTIVATED)
		var data := {}
		for mid2 in dn.mutation_index:
			if target and mid2 == target.id:
				data[result] = new_seq
			else:
				data[mid2] = dn.mutation_index[mid2]
		dn.mutation_index = data
		dn.domutcheck()
	_use_energy()
	return true

## tg combine_console / combine_disk
func _combine(to_disk: bool, params: Dictionary, user: Entity) -> bool:
	var dk := disk()
	if to_disk:
		if dk == null:
			return false
		if dk.mutations.size() >= dk.max_mutations:
			Game.tell(user, "Disk storage is full.", "warn")
			return false
		if dk.read_only:
			Game.tell(user, "Disk is set to read only mode.", "warn")
			return false
	var a := get_mut_by_ref(int(params.get("firstref", 0)), SEARCH_STORED | SEARCH_DISKETTE)
	var b := get_mut_by_ref(int(params.get("secondref", 0)), SEARCH_STORED | SEARCH_DISKETTE)
	if a == null or b == null:
		return false
	var result := Genetics.mixed(a.id, b.id)
	if result == "":
		return false
	if to_disk:
		dk.mutations.append(Mutation.make(result))
		Game.tell(user, "[b]Success! New mutation has been added to the disk.[/b]")
	else:
		stored_mutations.append(Mutation.make(result))
		Game.tell(user, "[b]Success! New mutation has been added to console storage.[/b]")
	if Genetics.discovered.has(result):
		return true
	Genetics.discovered[result] = true
	_say("Successfully mutated %s." % Genetics.DEFS[result]["name"])
	_use_energy()
	return true

## tg print_adv_inj
func _print_adv(params: Dictionary, user: Entity) -> bool:
	if Game.time < injector_ready:
		return false
	var nm := str(params.get("name", ""))
	if nm == "" or not injector_selection.has(nm) or injector_selection[nm].is_empty():
		return false
	var inj := Proto.spawn("dna_activator", _drop_cell())
	var dj: CDnaInjector = inj.c(&"dnainjector")
	var total := 0.0
	for m in injector_selection[nm]:
		dj.add_mutations.append(m.make_copy())
		total += m.instability
	dj.force_mutate = true
	inj.display_name = "Advanced %s injector" % nm
	var mult := 1.0 + ADVANCED_COOLDOWN_MULTIPLIER
	var base := maxf(MIN_ADVANCED_TIMEOUT, absf(total))
	if scanner_operational():
		dj.damage_coeff = scanner().damage_coeff * 4.0
		mult -= ADVANCED_COOLDOWN_MULTIPLIER * scanner().precision_coeff
	injector_ready = Game.time + minf(ADVANCED_INJECTOR_MAX_COOLDOWN, base * mult)
	Sfx.play("print", e.cell, 0.5)
	return true

## tg add_advinj_mut: within 10 mutations and 50 total instability
func _add_advinj(params: Dictionary, user: Entity) -> bool:
	if not scanner_operational():
		return false
	var adv := str(params.get("advinj", ""))
	if not injector_selection.has(adv):
		return false
	if injector_selection[adv].size() >= max_injector_mutations:
		Game.tell(user, "Advanced injector mutation storage is full.", "warn")
		return false
	var flag := 0
	match str(params.get("source", "")):
		"disk": flag = SEARCH_DISKETTE
		"occupant": flag = SEARCH_OCCUPANT
		"console": flag = SEARCH_STORED
	if flag == 0:
		return false
	if flag & SEARCH_OCCUPANT and not can_modify_occupant():
		return false
	var original := get_mut_by_ref(int(params.get("mutref", 0)), flag)
	if original == null:
		return false
	# TG admits a new mutation at its raw instability; existing entries use stab().
	var total := original.instability
	for m in injector_selection[adv]:
		if m.id == original.id and m.chromosome_name == original.chromosome_name:
			Game.tell(user, "This mutation is already in the advanced injector.", "warn")
			return false
		total += m.instability * m.stab()
	if total > max_injector_instability:
		Game.tell(user, "Extra mutation would make the advanced injector too instable.", "warn")
		return false
	injector_selection[adv].append(original.make_copy())
	Game.tell(user, "Mutation successfully added to advanced injector.")
	_use_energy()
	return true

## tg apply_genetic_makeup: ui, uf, ue or mixed onto the occupant, with 100-250 genetic
## damage (less with better lasers)
func apply_genetic_makeup(type: String, slot: Dictionary, user) -> bool:
	var dc := scanner().damage_coeff
	var dmg := Game.rng.randf_range(100.0 / pow(dc, 2), 250.0 / pow(dc, 2))
	var dn := occ_dna()
	var om: CMob = scanner_occupant.c(&"mob")
	var oh: CHealth = scanner_occupant.c(&"health")
	match type:
		"ui":
			if str(slot.get("UI", "")) == "":
				_corrupt(user)
				return false
			enzyme_copy_ready = Game.time + ENZYME_COPY_BASE_COOLDOWN
			dn.unique_identity = slot["UI"]
			dn.updateappearance()
		"uf":
			if str(slot.get("UF", "")) == "":
				_corrupt(user)
				return false
			enzyme_copy_ready = Game.time + ENZYME_COPY_BASE_COOLDOWN
			dn.unique_features = slot["UF"]
			dn.updateappearance()
		"ue":
			if str(slot.get("name", "")) == "" or str(slot.get("UE", "")) == "" or str(slot.get("blood_type", "")) == "":
				_corrupt(user)
				return false
			enzyme_copy_ready = Game.time + ENZYME_COPY_BASE_COOLDOWN
			_set_name(om, slot["name"])
			dn.unique_enzymes = slot["UE"]
			oh.blood_type = slot["blood_type"]
		"mixed":
			for k in ["UI", "name", "UE", "UF", "blood_type"]:
				if str(slot.get(k, "")) == "":
					_corrupt(user)
					return false
			enzyme_copy_ready = Game.time + ENZYME_COPY_BASE_COOLDOWN
			dn.unique_identity = slot["UI"]
			dn.unique_features = slot["UF"]
			dn.updateappearance()
			_set_name(om, slot["name"])
			dn.unique_enzymes = slot["UE"]
			oh.blood_type = slot["blood_type"]
		_:
			return false
	dn.add_genetic_damage(dmg)
	dn.domutcheck()
	return true

func _corrupt(user) -> void:
	if user:
		Game.tell(user, "Genetic data corrupted, unable to apply genetic data.", "warn")

func _set_name(om: CMob, nm: String) -> void:
	if om:
		om.real_name = nm
		om.e.display_name = nm
		var dn: CDna = om.e.c(&"dna")
		if dn:
			dn.real_name = nm

## tg make_cosmetic_dna_injector: a timed injector of the buffer's name / blood / looks
func make_cosmetic_dna_injector(type: String, slot) -> bool:
	if not slot is Dictionary or slot.is_empty():
		return false
	var flags := {"ui": ["UI"], "ue": ["UE", "name", "blood_type"], "uf": ["UF", "name"], "mixed": ["UI", "UE", "UF", "name", "blood_type"]}
	if not flags.has(type):
		return false
	var stored := {}
	for k in flags[type]:
		if str(slot.get(k, "")) == "":
			return false
		stored[k] = slot[k]
	var inj := Proto.spawn("dna_injector_timed", _drop_cell())
	var dj: CDnaInjector = inj.c(&"dnainjector")
	dj.stored_dna = stored
	dj.duration = 60.0
	dj.damage_coeff = scanner().damage_coeff if scanner_operational() else 1.0
	Sfx.play("print", e.cell, 0.5)
	return true

## tg randomize_GENETIC_DAMAGE_accuracy: a gaussian around the chosen block
func _random_accuracy(position: int, duration: float, blocks: int) -> int:
	var val := int(round(_gaussian(0.0, GENETIC_DAMAGE_ACCURACY_MULTIPLIER / duration) + position))
	return _wrap(val, 1, blocks + 1)

## tg scramble(input, rs): nudge a hex digit by a gaussian step
func _scramble_hex(input: String, rs: float) -> String:
	var ln := input.length()
	var ran := _gaussian(0.0, rs * GENETIC_DAMAGE_STRENGTH_MULTIPLIER)
	var step := 0
	if ran == 0.0:
		step = [-1, 1][Game.rng.randi() % 2]
	elif ran < 0.0:
		step = int(floor(ran))
	else:
		step = int(ceil(ran))
	var top := int(pow(16, ln))
	return Genetics.num2hex(((Genetics.hex2num(input) + step) % top + top) % top, ln)

static func _gaussian(mean: float, sd: float) -> float:
	return Game.rng.randfn(mean, sd)

## tg genetic_damage_pulse: the delayed radiation pulse on one identity/feature letter
func genetic_damage_pulse() -> void:
	if not operable() or not can_modify_occupant() or scanner_occupant != pulse_subject or not pulse_type in ["ui", "uf"]:
		on_scanner_open()
		return
	var dn := occ_dna()
	var s: String = dn.unique_identity if pulse_type == "ui" else dn.unique_features
	var num := _random_accuracy(pulse_index, pulse_duration + pow(scanner().precision_coeff, 2), s.length())
	var hex := _scramble_hex(s.substr(num - 1, 1), pulse_strength)
	s = s.substr(0, num - 1) + hex + s.substr(num)
	if pulse_type == "ui":
		dn.unique_identity = s
	else:
		dn.unique_features = s
	dn.updateappearance()
	pulse_index = 0
	pulse_type = ""
	pulse_subject = null
	pulse_timer = 0.0

func on_removed() -> void:
	set_connected_scanner(null)
	if disk() != null:
		eject_disk(null)

## tg eject_disk
func eject_disk(user: Entity) -> void:
	if diskette == null:
		return
	Game.tell(user, "You eject %s from %s." % [diskette.the(), e.the()])
	view["storageMode"] = "console"
	var dk := diskette
	diskette = null
	dk.holder = null
	dk.visible = true
	Game.drop_to_map(dk, _drop_cell())
	dk.place(_drop_cell())
	var inv: CInventory = user.c(&"inv") if user else null
	if inv and user.adjacent(e):
		inv.put_in_hands(dk)

# ------------------------------------------------------------------ items (tg item_interaction)
func attackby(user: Entity, item: Entity) -> bool:
	if item.has_c(&"chromosome"):
		user.c(&"inv").remove_ref(item)
		stored_chromosomes.append(item.c(&"chromosome").kind)
		Game.tell(user, "You insert %s." % item.the())
		item.destroy()
		return true
	if item.has_c(&"dnadisk"):
		Interact.detach(item)
		var old := diskette
		item.holder = e
		item.visible = false
		if old:
			diskette = old
			eject_disk(user)
		diskette = item
		Game.tell(user, "You insert %s." % item.the())
		return true
	if item.has_c(&"seqscanner"):
		item.c(&"seqscanner").link(user, self)
		return true
	var dj: CDnaInjector = item.c(&"dnainjector")
	if dj and item.proto == "dna_activator":
		if not dj.used:
			user.c(&"inv").remove_ref(item)
			Game.tell(user, "Recycled unused %s." % item.display_name)
			item.destroy()
			return true
		if dj.research and dj.filled:
			if Genetics.prob(60):
				var c := CChromosome.generate()
				stored_chromosomes.append(c)
				Game.tell(user, "%s added to storage." % CChromosome.NAMES[c].capitalize())
			else:
				Game.tell(user, "There was not enough genetic data to extract a viable chromosome.")
		if dj.crispr_charge:
			crispr_charges += 1
			Game.tell(user, "CRISPR charge added.")
		user.c(&"inv").remove_ref(item)
		Game.tell(user, "Recycled %s." % item.display_name)
		item.destroy()
		return true
	return false

func attack_hand(user: Entity) -> bool:
	if not operable():
		Game.tell(user, "%s is dark." % e.the().capitalize(), "warn")
		return true
	if not Species.advanced_tool_user(user):
		Game.tell(user, "You don't have the dexterity to do this!", "warn")
		return true
	if connected_scanner == null:
		connect_to_scanner()
	Bus.ui_open_window.emit("dna_console", e)
	return true

func verbs(user: Entity, out: Array) -> void:
	if diskette != null:
		out.append({"name": "Eject disk", "cb": func(): eject_disk(user), "priority": 4})

func examine(_user: Entity, lines: Array) -> void:
	if diskette:
		lines.append("There's a data disk in the drive.")

func ai_tags(out: Dictionary) -> void:
	out["dna_console"] = true
