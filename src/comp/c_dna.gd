class_name CDna extends Component
## tg /datum/dna on a carbon (code/datums/dna/dna.dm), with the genetics status effects
## that live on the body: genetic damage, the DNA meltdown timer, muscle spasms, "go away"
## and the DNA injectors' temporary transformations.
##
##   unique_enzymes     md5 of the real name; blood carries it (Forensics.dna)
##   unique_identity    identity blocks built from the body (Genetics.UI_BLOCKS);
##                      fingerprints are its md5
##   unique_features    species feature blocks (Genetics.UF_BLOCKS)
##   mutation_index     the eight genes: mutation id -> its sequence in this body
##   default_mutation_genes  the sequences as they were (what the console highlights)
##   mutations          the Mutations on this body

var unique_enzymes := ""
var unique_identity := ""
var unique_features := ""
var real_name := ""
var species := "human" # tg dna.species: "human" or "monkey" (species come later)
var features := {} # tg dna.features: "mcolor" -> hex, accessory -> option index (1-based)
var mutation_index := {} # id -> sequence; the order is the gene order
var default_mutation_genes := {}
var mutations: Array = [] # Mutation
var stability := 100.0
var scrambled := false
## tg transformation_timer: seconds left of a monkeyize / humanize (0 = none)
var transform_t := 0.0
var _transform_cb := Callable()
## the brain it thinks with: a human brain lets it use tools and read (tg brain organ
## traits); a primate brain (born monkeys keep theirs when humanized) doesn't
var brain_kind := "human"

# tg status effects on the body
var genetic_damage := 0.0 # /datum/status_effect/genetic_damage total_damage (0 = none)
var _gd_tick := 0.0 # its 2 second tick
var melt_t := -1.0 # /datum/status_effect/dna_melt: seconds left, -1 = none
var melt_kill := false # kill_either_way
var spasms := 0 # /datum/status_effect/spasms (STATUS_EFFECT_MULTIPLE: how many)
var go_away_t := 0.0 # /datum/status_effect/go_away seconds left
var go_away_dir := Vector2i.ZERO
var _go_away_step := 0.0
var temp_transforms: Array = [] # /datum/status_effect/temporary_transformation/dna_injector [{t, new, old}]
var damage_resistance := 0.0 # tg physiology damage_resistance (%), the not-alright meltdown sets -20000
## the action buttons the mutations grant (GenePowers): [{id, mut, cd, ready_t, armed, data}]
var powers: Array = []
var tk_grab: Entity = null
var laser_ready := 0.0

const MINIMUM_BEFORE_TOX_DAMAGE := 500.0 # tg genetic_damage minimum_before_tox_damage
const GD_REMOVE_PER_SECOND := 1.0 / 3.0
const GD_TOX_PER_SECOND := 1.0 / 3.0
const GORILLA_MUTATION_MINIMUM_DAMAGE := 2500.0
const GORILLA_MUTATION_CHANCE_PER_SECOND := 0.25
const DNA_MELT_DURATION := 60.0 # tg dna_melt duration 600 ds

func key() -> StringName:
	return &"dna"

func health() -> CHealth:
	return e.c(&"health") if e else null

func mob() -> CMob:
	return e.c(&"mob") if e else null

# ------------------------------------------------------------------ setup
## tg initialize_dna: blood type, the mutation blocks, random features, then the identity.
func initialize_dna(create_mutation_blocks := true, randomize_features := true) -> void:
	Genetics.ensure()
	if create_mutation_blocks:
		generate_dna_blocks(["headless"])
	if randomize_features:
		for b in Genetics.UF_BLOCKS:
			if b[0] == "mcolor":
				features["mcolor"] = Genetics.random_hex(6)
			else:
				features[b[0]] = Game.rng.randi_range(1, Genetics.FEATURE_OPTIONS.get(b[0], 2))
	update_dna_identity()

## tg generate_dna_blocks: the monkey gene plus seven from the good, bad and not-good pools
## (and the species' inert mutation, dwarfism for humans and monkeys), then shuffled.
func generate_dna_blocks(blacklist: Array = []) -> void:
	Genetics.ensure()
	var temp: Array = Genetics.good + Genetics.bad + Genetics.not_good
	if not "dwarfism" in temp:
		temp.append("dwarfism") # tg species inert_mutation
	for b in blacklist:
		temp.erase(b)
	if temp.is_empty():
		return
	mutation_index.clear()
	default_mutation_genes.clear()
	Genetics.shuffle(temp)
	var idx := {}
	idx["race"] = Genetics.create_sequence("race", false)
	default_mutation_genes["race"] = idx["race"]
	# tg: for(var/i in 2 to DNA_MUTATION_BLOCKS) mutations_temp[i] - the first pick is skipped
	for i in range(1, mini(Genetics.DNA_MUTATION_BLOCKS, temp.size())):
		var mid: String = temp[i]
		idx[mid] = Genetics.create_sequence(mid, false, Genetics.DEFS[mid].get("difficulty", 8))
		default_mutation_genes[mid] = idx[mid]
	var order: Array = idx.keys()
	Genetics.shuffle(order) # tg shuffle_inplace(mutation_index)
	for k in order:
		mutation_index[k] = idx[k]

## tg update_dna_identity
func update_dna_identity() -> void:
	unique_identity = generate_unique_identity()
	unique_enzymes = generate_unique_enzymes()
	unique_features = generate_unique_features()

func generate_unique_enzymes() -> String:
	var m := mob()
	if m:
		real_name = m.real_name
		return real_name.md5_text()
	return Genetics.random_hex(Genetics.DNA_UNIQUE_ENZYMES_LEN)

## tg generate_unique_identity: each identity block from the body.
func generate_unique_identity() -> String:
	var s := ""
	for b in Genetics.UI_BLOCKS:
		s += ui_block_from_body(b[0])
	return s

func generate_unique_features() -> String:
	var s := ""
	for b in Genetics.UF_BLOCKS:
		if not features.has(b[0]):
			s += Genetics.random_hex(b[1])
			continue
		if b[0] == "mcolor":
			s += str(features["mcolor"]).substr(0, 6).rpad(6, "0")
		else:
			s += Genetics.construct_block(int(features[b[0]]), Genetics.FEATURE_OPTIONS.get(b[0], 2))
	return s

## tg /datum/dna_block/identity/*/create_unique_block
func ui_block_from_body(id: String) -> String:
	var m := mob()
	var a: Dictionary = m.appearance if m else {}
	match id:
		"gender":
			var g := Genetics.G_PLURAL
			if m:
				g = {"he": Genetics.G_MALE, "she": Genetics.G_FEMALE, "it": Genetics.G_NEUTER}.get(m.pronoun, Genetics.G_PLURAL)
			return Genetics.construct_block(g, Genetics.GENDERS)
		"skin_tone":
			return Genetics.construct_block(_skin_index(a.get("skin", Color("#e0ac8a"))), Jobs.SKIN_TONES.size())
		"eye_colors":
			var l: Color = a.get("eyes", Color("#3a6ad8"))
			var r: Color = a.get("eyes_r", l)
			return Genetics.hex_color(l) + Genetics.hex_color(r)
		"hair_style":
			return Genetics.construct_block(Jobs.HAIR_STYLES.find(a.get("hair", "short")) + 1, Jobs.HAIR_STYLES.size())
		"hair_color":
			return Genetics.hex_color(a.get("hair_color", Color("#4a2e1e")))
		"facial_style":
			return Genetics.construct_block(Jobs.FACIAL_STYLES.find(a.get("facial", "")) + 1, Jobs.FACIAL_STYLES.size())
		"facial_color":
			return Genetics.hex_color(a.get("facial_color", a.get("hair_color", Color("#4a2e1e"))))
		"hair_gradient":
			return Genetics.construct_block(Genetics.GRADIENTS.find(a.get("hair_gradient", "none")) + 1, Genetics.GRADIENTS.size())
		"hair_gradient_color":
			return Genetics.hex_color(a.get("hair_gradient_color", Color.BLACK))
		"facial_gradient":
			return Genetics.construct_block(Genetics.GRADIENTS.find(a.get("facial_gradient", "none")) + 1, Genetics.GRADIENTS.size())
		"facial_gradient_color":
			return Genetics.hex_color(a.get("facial_gradient_color", Color.BLACK))
		"height":
			var hi := Genetics.HEIGHTS.find(a.get("height", "medium")) + 1
			if hi <= 0:
				hi = Genetics.HEIGHTS.find("medium") + 1
			return Genetics.construct_block(hi, Genetics.HEIGHTS.size())
	return ""

static func _skin_index(c: Color) -> int:
	var best := 3
	var bd := 99.0
	for i in Jobs.SKIN_TONES.size():
		var t := Color(Jobs.SKIN_TONES[i])
		var d := absf(t.r - c.r) + absf(t.g - c.g) + absf(t.b - c.b)
		if d < bd:
			bd = d
			best = i + 1
	return best

## tg updateappearance: every identity block back onto the body, then the feature blocks.
func updateappearance() -> void:
	var m := mob()
	if m == null:
		return
	var a: Dictionary = m.appearance
	for b in Genetics.UI_BLOCKS:
		var v := Genetics.get_block(unique_identity, Genetics.UI_BLOCKS, b[0])
		if v.length() < b[1]:
			continue
		match b[0]:
			"gender":
				if Traits.has(e, "agender"):
					m.pronoun = "they"
				else:
					m.pronoun = {Genetics.G_MALE: "he", Genetics.G_FEMALE: "she", Genetics.G_NEUTER: "it"}.get(Genetics.deconstruct_block(v, Genetics.GENDERS), "they")
					if m.pronoun == "it":
						m.pronoun = "they" # this station's pronouns: they / she / he
			"skin_tone":
				a["skin"] = Color(Jobs.SKIN_TONES[Genetics.deconstruct_block(v, Jobs.SKIN_TONES.size()) - 1])
			"eye_colors":
				a["eyes"] = Genetics.color_of(v.substr(0, 6))
				a["eyes_r"] = Genetics.color_of(v.substr(6, 6))
			"hair_style":
				a["hair"] = "bald" if Traits.has(e, "bald") else Jobs.HAIR_STYLES[Genetics.deconstruct_block(v, Jobs.HAIR_STYLES.size()) - 1]
			"hair_color":
				a["hair_color"] = Genetics.color_of(v)
			"facial_style":
				a["facial"] = "" if Traits.has(e, "shaved") else Jobs.FACIAL_STYLES[Genetics.deconstruct_block(v, Jobs.FACIAL_STYLES.size()) - 1]
			"facial_color":
				a["facial_color"] = Genetics.color_of(v)
			"hair_gradient":
				a["hair_gradient"] = Genetics.GRADIENTS[Genetics.deconstruct_block(v, Genetics.GRADIENTS.size()) - 1]
			"hair_gradient_color":
				a["hair_gradient_color"] = Genetics.color_of(v)
			"facial_gradient":
				a["facial_gradient"] = Genetics.GRADIENTS[Genetics.deconstruct_block(v, Genetics.GRADIENTS.size()) - 1]
			"facial_gradient_color":
				a["facial_gradient_color"] = Genetics.color_of(v)
			"height":
				a["height"] = Genetics.HEIGHTS[Genetics.deconstruct_block(v, Genetics.HEIGHTS.size()) - 1]
	for b in Genetics.UF_BLOCKS:
		if not features.has(b[0]):
			continue
		var fv := Genetics.get_block(unique_features, Genetics.UF_BLOCKS, b[0])
		if fv.length() < b[1]:
			continue
		if b[0] == "mcolor":
			features["mcolor"] = fv
		else:
			features[b[0]] = Genetics.deconstruct_block(fv, Genetics.FEATURE_OPTIONS.get(b[0], 2))
	m.refresh_doll()
	m.update_size()

# ------------------------------------------------------------------ mutations
## tg get_mutation
func get_mutation(mid: String) -> Mutation:
	for m in mutations:
		if m.id == mid:
			return m
	return null

func has_mutation(mid: String) -> bool:
	return get_mutation(mid) != null

## tg add_mutation(mutation, sources): a type or an instance to copy. Returns true if it
## took (or already had the sources).
func add_mutation(what, sources) -> bool:
	if sources is String:
		sources = [sources]
	var mid: String = what.id if what is Mutation else str(what)
	if not Genetics.DEFS.has(mid):
		return false
	var actual := get_mutation(mid)
	var to_add: Array = sources.duplicate()
	if actual == null:
		actual = (what as Mutation).make_copy() if what is Mutation else Mutation.make(mid)
	else:
		for s in actual.sources:
			to_add.erase(s)
		if to_add.is_empty():
			return false
	if actual.sources.is_empty():
		if not GeneFx.on_acquiring(e, actual):
			Game.tell(e, "You feel your genes resisting something.", "warn")
			return false
		GeneFx.setup(e, actual)
		if actual.data.get("_removed", false):
			return true # it acted and took itself back off (tg bad_dna)
	for s in sources:
		if not s in actual.sources:
			actual.sources.append(s)
	if Genetics.SRC_ACTIVATED in sources:
		set_se(true, actual)
	update_instability()
	return true

## tg remove_mutation
func remove_mutation(what, sources) -> bool:
	if sources is String:
		sources = [sources]
	var mid: String = what.id if what is Mutation else str(what)
	var actual := get_mutation(mid)
	if actual == null:
		return false
	var hit := false
	for s in sources:
		if s in actual.sources:
			hit = true
	if not hit:
		return false
	for s in sources:
		actual.sources.erase(s)
	if Genetics.SRC_ACTIVATED in sources:
		set_se(false, actual)
	if actual.sources.is_empty():
		GeneFx.on_losing(e, actual)
	update_instability(false)
	return true

## tg remove_all_mutations
func remove_all_mutations(sources: Array = Genetics.STANDARD_SOURCES) -> void:
	remove_mutation_group(mutations.duplicate(), sources)
	scrambled = false

func remove_mutation_group(group: Array, sources: Array = Genetics.STANDARD_SOURCES) -> void:
	for m in group:
		remove_mutation(m, sources)

## tg check_block
func check_block(mid: String) -> void:
	var m := get_mutation(mid)
	if check_block_string(mid):
		if m == null:
			add_mutation(mid, Genetics.SRC_ACTIVATED)
		return
	if m != null and Genetics.SRC_ACTIVATED in m.sources:
		remove_mutation(m, Genetics.SRC_ACTIVATED)

func check_block_string(mid: String) -> bool:
	if mutation_index.size() > Genetics.DNA_MUTATION_BLOCKS or not mutation_index.has(mid):
		return false
	return is_gene_active(mid)

func is_gene_active(mid: String) -> bool:
	return mutation_index.get(mid, "") == Genetics.sequence(mid)

## tg domutcheck: every gene that matches its true sequence is on; the rest are off.
func domutcheck() -> void:
	for mid in mutation_index.keys():
		if not is_instance_valid(e) or e.removed:
			return
		check_block(mid)
	var m := mob()
	if m:
		m.refresh_doll()

## tg set_se: complete (or re-scramble) a gene to match its mutation being on (or off).
func set_se(on: bool, m: Mutation) -> void:
	if m == null or not mutation_index.has(m.id) or mutation_index.size() < Genetics.DNA_MUTATION_BLOCKS:
		return
	if on:
		mutation_index[m.id] = Genetics.sequence(m.id)
		default_mutation_genes[m.id] = mutation_index[m.id]
	elif Genetics.sequence(m.id) == mutation_index[m.id]:
		mutation_index[m.id] = Genetics.create_sequence(m.id, false, Genetics.DEFS[m.id].get("difficulty", 8))
		default_mutation_genes[m.id] = mutation_index[m.id]

## tg activate_mutation: only what's in the sequence can be activated.
func activate_mutation(what) -> bool:
	var mid: String = what.id if what is Mutation else str(what)
	if not mutation_in_sequence(mid):
		return false
	add_mutation(what, Genetics.SRC_ACTIVATED)
	return true

func mutation_in_sequence(mid: String) -> bool:
	return mutation_index.has(mid)

## tg update_instability: 100 less the instability of every mutator-added or negative
## mutation (after its stabilizer chromosome). At 0 or below, the DNA starts melting down.
func update_instability(alert := true) -> void:
	var old := stability
	stability = 100.0
	for m in mutations:
		if Genetics.SRC_MUTATOR in m.sources or m.instability < 0:
			stability -= m.instability * m.stab()
	var msg := ""
	var k := "warn"
	if alert:
		# BYOND switch ranges include both ends; the first match wins
		if stability >= 70 and stability <= 90: msg = "You shiver."
		elif stability >= 60 and stability <= 69: msg = "You feel cold."
		elif stability >= 40 and stability <= 59: msg = "You feel sick."
		elif stability >= 20 and stability <= 39: msg = "It feels like your skin is moving."
		elif stability >= 1 and stability <= 19: msg = "You can feel your cells burning."
		elif stability <= 0:
			msg = "[b]You can feel your DNA exploding, we need to do something fast![/b]"
			k = "bad"
	if stability <= 0:
		apply_dna_melt()
	if msg != "" and stability < old:
		Game.tell(e, msg, k)

## tg random_mutate_unique_identity / features
func random_mutate_unique_identity() -> void:
	var b: Array = Genetics.rand_pick(Genetics.UI_BLOCKS)
	unique_identity = Genetics.modified_hash(unique_identity, Genetics.UI_BLOCKS, b[0], Genetics.random_hex(b[1]))
	updateappearance()

func random_mutate_unique_features() -> void:
	var b: Array = Genetics.rand_pick(Genetics.UF_BLOCKS)
	unique_features = Genetics.modified_hash(unique_features, Genetics.UF_BLOCKS, b[0], Genetics.random_hex(b[1]))
	updateappearance()

## tg get_random_mutation_path: a mutation in (by default) this body's sequence it
## doesn't already have, of the given qualities, not the monkey gene.
func get_random_mutation_path(quality := 7, sequence_only := true, excluded: Array = ["race"]) -> String:
	var pool: Array = []
	if quality & Genetics.POSITIVE:
		pool += Genetics.good
	if quality & Genetics.NEGATIVE:
		pool += Genetics.bad
	if quality & Genetics.MINOR_NEGATIVE:
		pool += Genetics.not_good
	var possible := []
	for mid in pool:
		if (not sequence_only or mutation_in_sequence(mid)) and get_mutation(mid) == null and not mid in excluded:
			possible.append(mid)
	return Genetics.rand_pick(possible) if not possible.is_empty() else ""

## tg easy_random_mutate
func easy_random_mutate(quality := 7, scrambled_ok := true, sequence_only := true, excluded: Array = ["race"]) -> void:
	var mid := get_random_mutation_path(quality, sequence_only, excluded)
	if mid == "":
		return
	add_mutation(mid, Genetics.SRC_ACTIVATED)
	if not scrambled_ok:
		return
	var m := get_mutation(mid)
	if m:
		m.scrambled = false

## tg random_mutate: a mutator-added mutation from the candidates
func random_mutate(candidates: Array) -> void:
	if candidates.is_empty():
		return
	add_mutation(Genetics.rand_pick(candidates), Genetics.SRC_MUTATOR)

## tg scramble_dna
func scramble(ui := false, se := false, uf := false, probability := 100.0) -> void:
	if Traits.has(e, "no_dna_scramble"):
		return
	if se:
		for i in Genetics.DNA_MUTATION_BLOCKS:
			if Genetics.prob(probability):
				generate_dna_blocks()
		domutcheck()
	if ui:
		for b in Genetics.UI_BLOCKS:
			if Genetics.prob(probability):
				unique_identity = Genetics.modified_hash(unique_identity, Genetics.UI_BLOCKS, b[0], Genetics.random_hex(b[1]))
	if uf:
		# tg writes the feature blocks into unique_identity here (a tg bug, kept)
		for b in Genetics.UF_BLOCKS:
			if Genetics.prob(probability):
				unique_identity = Genetics.modified_hash(unique_identity, Genetics.UF_BLOCKS, b[0], Genetics.random_hex(b[1]))
	if ui or uf:
		updateappearance()

## tg copy_dna into a plain dictionary (a stored copy: injectors, buffers)
func snapshot(with_se := true) -> Dictionary:
	var d := {"UE": unique_enzymes, "UI": unique_identity, "UF": unique_features, "name": real_name, "features": features.duplicate(),
		"species": species, "blood_type": health().blood_type if health() else ""}
	if with_se:
		d["index"] = mutation_index.duplicate()
		d["defaults"] = default_mutation_genes.duplicate()
	return d

# ------------------------------------------------------------------ tg status effects
## /datum/status_effect/genetic_damage (STATUS_EFFECT_REFRESH: more adds to the total)
func add_genetic_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	if genetic_damage <= 0.0:
		_gd_tick = 2.0
	genetic_damage += amount

## the console and health analyzers show it as a percentage of the toxin threshold
func genetic_damage_percent() -> float:
	return snappedf(genetic_damage / MINIMUM_BEFORE_TOX_DAMAGE * 100.0, 0.1)

## /datum/status_effect/dna_melt (STATUS_EFFECT_REPLACE: a new one restarts the minute)
func apply_dna_melt() -> void:
	if melt_t < 0.0:
		Game.tell(e, "[b]My body can't handle the mutations! I need to get my mutations removed fast![/b]", "bad")
	melt_t = DNA_MELT_DURATION

## /datum/status_effect/go_away: stunned, flying a random direction through walls for 10 s
func apply_go_away() -> void:
	go_away_t = 10.0
	go_away_dir = Defs.DIRS4[Game.rng.randi() % 4]
	_go_away_step = 0.0
	var m := mob()
	if m:
		m.face(Defs.dir_from_vec(go_away_dir))

## Once a second (LifeSystem.life_tick).
func tick(dt: float) -> void:
	var h := health()
	if h == null:
		return
	# genetic damage: 2 second ticks
	if genetic_damage > 0.0:
		_gd_tick -= dt
		while _gd_tick <= 0.0 and genetic_damage > 0.0:
			_gd_tick += 2.0
			if Traits.has(e, "simian") and genetic_damage >= GORILLA_MUTATION_MINIMUM_DAMAGE and Genetics.spt_prob(GORILLA_MUTATION_CHANCE_PER_SECOND, 2.0):
				GeneFx.gorillize(e)
				genetic_damage = 0.0
				break
			if genetic_damage >= MINIMUM_BEFORE_TOX_DAMAGE and not h.dead:
				h.adjust("tox", GD_TOX_PER_SECOND * 2.0)
			genetic_damage -= GD_REMOVE_PER_SECOND * 2.0
			if genetic_damage <= 0.0:
				genetic_damage = 0.0
	# the meltdown timer runs out: something horrible (unless it was fixed in time)
	if melt_t >= 0.0:
		melt_t -= dt
		if melt_t < 0.0:
			GeneFx.something_horrible(e, melt_kill)
			if not is_instance_valid(e) or e.removed:
				return
	# spasms: a 1 s tick each
	for i in spasms:
		GeneFx.spasm_tick(e)
	# temporary transformations from DNA injectors
	for i in range(temp_transforms.size() - 1, -1, -1):
		var tt: Dictionary = temp_transforms[i]
		tt["t"] -= dt
		if tt["t"] <= 0.0:
			end_temp_transform(tt)
	# the mutations act (tg carbon/Life: mutation.on_life)
	if not h.dead:
		for m in mutations.duplicate():
			if m in mutations and is_instance_valid(e) and not e.removed:
				GeneFx.on_life(e, m, dt)

## Per frame: the monkeyize / humanize animation and "go away" flight.
func process(delta: float) -> void:
	GeneInteraction.validate(e)
	RockMetabolism.process(e, delta)
	SkillChips.update(e)
	if transform_t > 0.0:
		transform_t -= delta
		if transform_t <= 0.0:
			transform_t = 0.0
			var cb := _transform_cb
			_transform_cb = Callable()
			if cb.is_valid():
				cb.call()
	if go_away_t > 0.0:
		go_away_t -= delta
		_go_away_step -= delta
		var h := health()
		if h:
			h.set_status_if_lower("stun", 0.3) # tg AdjustStun(1, ignore_canstun)
		if _go_away_step <= 0.0:
			_go_away_step = 0.2 # tg tick_interval 0.2 s: forceMove a tile
			var to := e.cell + go_away_dir
			if not Game.map.inb(to):
				go_away_t = 0.0
			else:
				e.place(to)

func start_transform(seconds: float, cb: Callable) -> void:
	transform_t = seconds
	_transform_cb = cb

func transforming() -> bool:
	return transform_t > 0.0

# ------------------------------------------------------------------ DNA injector transformations
## tg temporary_transformation/dna_injector: become the stored DNA for a while (name,
## looks, features, blood type), then change back.
func start_temp_transform(stored: Dictionary, duration: float) -> void:
	var old: Dictionary
	if not temp_transforms.is_empty():
		old = temp_transforms[0]["old"].duplicate() # tg: copy the original from the first
	else:
		old = snapshot(false)
	var nd := snapshot(false)
	for k in ["name", "UE", "UI", "UF", "blood_type"]:
		if stored.get(k, "") != "":
			nd[k] = stored[k]
	var tt := {"t": duration, "new": nd, "old": old}
	temp_transforms.append(tt)
	_apply_stored(nd)
	domutcheck()

func end_temp_transform(tt: Dictionary) -> void:
	temp_transforms.erase(tt)
	_apply_stored(tt["old"])
	domutcheck()
	for other in temp_transforms:
		_apply_stored(other["new"])
		domutcheck()

func _apply_stored(d: Dictionary) -> void:
	if d.get("UE", "") != "":
		unique_enzymes = d["UE"]
	if d.get("UI", "") != "":
		unique_identity = d["UI"]
	if d.get("UF", "") != "":
		unique_features = d["UF"]
	var h := health()
	if h and d.get("blood_type", "") != "":
		h.blood_type = d["blood_type"]
	if d.get("name", "") != "":
		real_name = d["name"]
		var m := mob()
		if m:
			m.real_name = real_name
			e.display_name = real_name
	updateappearance()

# ------------------------------------------------------------------ examine
func examine(_user: Entity, lines: Array) -> void:
	GeneFx.examine(e, lines)
