class_name Disease extends RefCounted
## Simple symptomatic disease (tg: /datum/disease). Progresses through stages, spreads by
## coughing (airborne, short range) or contact, cured by spaceacillin / toxin kits.

var name := "Glacial Flu"
var stage := 1
var max_stage := 4
var progress := 0.0
var cure_progress := 0.0
var spread := "airborne"
var contagious := true
var symptoms := ["cough", "shiver", "fever", "vomit"]
var resistance := 0
var stealth := 0
var stage_speed := 0
var genetic_timer := 45.0

## TG advance/symptoms/genetics.dm and viral.dm. Genetic disease statistics
## control source ownership, cure persistence, selection and symptom cadence.
static func make_genetic(viral_only := false, stats: Dictionary = {}) -> Disease:
	var d := Disease.new()
	d.name = "Accelerating Virus" if viral_only else "Dormant DNA Activator"
	d.max_stage = 5
	d.symptoms = ["cough", "viralevolution" if viral_only else "genetic_mutation"]
	d.resistance = int(stats.get("resistance", 0))
	d.stealth = int(stats.get("stealth", 0))
	d.stage_speed = int(stats.get("stage_speed", 0))
	d.genetic_timer = 30.0 if d.stage_speed >= 10 else 45.0
	return d

func is_genetic() -> bool:
	return "genetic_mutation" in symptoms or "viralevolution" in symptoms

func activate_genetics(host: Entity) -> void:
	if stage < 4 or not "genetic_mutation" in symptoms or not Genetics.can_mutate(host):
		return
	var dna := Genetics.dna(host)
	var qualities := Genetics.NEGATIVE | Genetics.MINOR_NEGATIVE
	if stealth < 5:
		qualities |= Genetics.POSITIVE
	var mid := dna.get_random_mutation_path(qualities)
	if mid == "":
		return
	var quality: int = Genetics.DEFS[mid]["quality"]
	var proof := resistance >= 8 and quality & (Genetics.NEGATIVE | Genetics.MINOR_NEGATIVE)
	dna.add_mutation(mid, Genetics.SRC_GENE_SYMPTOM if proof else Genetics.SRC_ACTIVATED)
	var mutation := dna.get_mutation(mid)
	if mutation:
		mutation.scrambled = true

func cure(host: Entity) -> void:
	var dna := Genetics.dna(host)
	if dna and "genetic_mutation" in symptoms and resistance < 14:
		dna.remove_all_mutations([Genetics.SRC_GENE_SYMPTOM, Genetics.SRC_ACTIVATED])
	var h: CHealth = host.c(&"health")
	if h and h.disease == self:
		h.disease = null

static func make_random(allow_genetic := true) -> Disease:
	var d := Disease.new()
	var names := [["Glacial Flu", "airborne"], ["Rimefever", "airborne"], ["Permafrost Pox", "contact"], ["Aurora Syndrome", "airborne"], ["Dormant DNA Activator", "airborne"], ["Accelerating Virus", "airborne"]]
	if not allow_genetic:
		names.resize(4)
	var pick: Array = names[Game.rng.randi() % names.size()]
	d.name = pick[0]
	d.spread = pick[1]
	if d.name in ["Dormant DNA Activator", "Accelerating Virus"]:
		return make_genetic(d.name == "Accelerating Virus")
	return d

## tg /datum/disease/advance/random(max_symptoms, max_level) caught by contact (the DNA
## console's CRISPR risk): a random illness, its stage cap from the level.
static func contract_random(host: Entity, level: int) -> void:
	var h: CHealth = host.c(&"health") if host else null
	if h == null or h.disease != null:
		return
	var d := make_random(false) # CRISPR level 2/3 excludes level 4/7 genetic symptoms
	d.max_stage = clampi(level + 1, 2, 5)
	h.disease = d

func copy() -> Disease:
	var d := Disease.new()
	d.name = name
	d.spread = spread
	d.symptoms = symptoms.duplicate()
	d.max_stage = max_stage
	d.contagious = contagious
	d.resistance = resistance
	d.stealth = stealth
	d.stage_speed = stage_speed
	d.genetic_timer = 30.0 if stage_speed >= 10 else 45.0
	return d

## Called once per life tick (1 s).
func tick(host: Entity) -> void:
	var h: CHealth = host.c(&"health")
	if cure_progress >= 1.0:
		cure(host)
		Game.tell(host, "You feel much better.", "good")
		Bus.stimulus.emit({"type": "cured", "actor": host, "target": host, "cell": host.cell, "loud": 0.0})
		return
	cure_progress = maxf(0.0, cure_progress - 0.001)
	progress += 0.004 * (1.5 if "viralevolution" in symptoms else 1.0)
	if progress >= 1.0 and stage < max_stage:
		progress = 0.0
		stage += 1
	if "genetic_mutation" in symptoms:
		genetic_timer -= 1.0
		if genetic_timer <= 0.0:
			genetic_timer = 30.0 if stage_speed >= 10 else 45.0
			activate_genetics(host)
	if Game.rng.randf() < 0.04 * stage:
		_symptom(host, h)

func _symptom(host: Entity, h: CHealth) -> void:
	if symptoms.is_empty():
		return
	var s: String = symptoms[Game.rng.randi() % mini(stage, symptoms.size())]
	var m: CMob = host.c(&"mob")
	match s:
		"cough":
			m.do_emote("cough")
			if contagious and spread == "airborne":
				for other in Game.in_radius(host.cell, 2, &"health"):
					if other != host and other.c(&"health").disease == null and not _protected(other) and Game.rng.randf() < 0.25:
						infect(other)
		"shiver":
			m.do_emote("shiver")
			h.body_temp -= 1.5
		"fever":
			h.adjust("tox", 1.0)
			h.body_temp += 1.0
		"vomit":
			m.emote("vomits!")
			Liquids.spill(host.cell, "vomit", 12.0)
			var n: CNeeds = host.c(&"needs")
			if n:
				n.nutrition = maxf(0.0, n.nutrition - 15)
			h.adjust("tox", 3.0)
			Bus.stimulus.emit({"type": "vomit", "actor": host, "cell": host.cell, "loud": 4.0})

func _protected(other: Entity) -> bool:
	var inv = other.c(&"inv")
	if inv:
		var mk: Entity = inv.worn("mask")
		if mk and mk.has_c(&"clothing") and mk.c(&"clothing").gas_filter:
			return true
	return false

func infect(target: Entity) -> void:
	var h: CHealth = target.c(&"health")
	if h == null or h.dead or h.disease != null:
		return
	h.disease = copy()
	Bus.chronicle.emit("%s contracted %s." % [target.display_name, name], 1)
