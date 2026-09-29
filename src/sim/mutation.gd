class_name Mutation extends RefCounted
## One tg /datum/mutation instance. The type's data lives in Genetics.DEFS; this holds what
## differs per copy: its sources, the chromosome coefficients, whether it's scrambled, and
## the state its effect keeps while it's on someone (tg's per-mutation vars).
##
## A mutation stored on a console, a disk or an injector has no owner; one on a body has.

var id := ""
var owner: Entity = null
var sources: Array = [] # tg sources: "activated", "mutator", or anything else ("other")
var scrambled := false
var can_chromosome := Genetics.CHROMOSOME_NONE
var chromosome_name := ""
var stabilizer_coeff := 1.0
var synchronizer_coeff := Genetics.UNMODIFIABLE
var power_coeff := Genetics.UNMODIFIABLE
var energy_coeff := Genetics.UNMODIFIABLE
var instability := 0.0
var valid_chrom_list: Array = []
var data := {} # the effect's own vars (tg: warpchance, last_scream, the glow light...)
var uid := 0 # tg REF(mutation): how the console names this exact copy
static var _next_uid := 1

static func make(mid: String) -> Mutation:
	var m := Mutation.new()
	m.id = mid
	var d: Dictionary = Genetics.DEFS.get(mid, {})
	m.stabilizer_coeff = d.get("stabilizer", 1.0)
	m.synchronizer_coeff = d.get("sync", Genetics.UNMODIFIABLE)
	m.power_coeff = d.get("power_c", Genetics.UNMODIFIABLE)
	m.energy_coeff = d.get("energy", Genetics.UNMODIFIABLE)
	m.instability = d.get("instability", 0)
	m.can_chromosome = d.get("can_chromosome", Genetics.CHROMOSOME_NONE)
	m.uid = _next_uid
	_next_uid += 1
	m.update_valid_chromosome_list()
	return m

func def() -> Dictionary:
	return Genetics.DEFS.get(id, {})

func name() -> String:
	return def().get("name", id)

func quality() -> int:
	return def().get("quality", 0)

## tg make_copy
func make_copy() -> Mutation:
	var c := Mutation.make(id)
	c.chromosome_name = chromosome_name
	c.stabilizer_coeff = stabilizer_coeff
	c.synchronizer_coeff = synchronizer_coeff
	c.power_coeff = power_coeff
	c.energy_coeff = energy_coeff
	c.can_chromosome = can_chromosome
	c.valid_chrom_list = valid_chrom_list.duplicate()
	return c

## tg GET_MUTATION_STABILIZER / SYNCHRONIZER / POWER / ENERGY: -1 means "not modifiable", 1.
func stab() -> float:
	return 1.0 if stabilizer_coeff < 0.0 else stabilizer_coeff

func sync() -> float:
	return 1.0 if synchronizer_coeff < 0.0 else synchronizer_coeff

func pwr() -> float:
	return 1.0 if power_coeff < 0.0 else power_coeff

func nrg() -> float:
	return 1.0 if energy_coeff < 0.0 else energy_coeff

## tg update_valid_chromosome_list
func update_valid_chromosome_list() -> void:
	valid_chrom_list.clear()
	if can_chromosome == Genetics.CHROMOSOME_NEVER:
		valid_chrom_list.append("none")
		return
	if stabilizer_coeff != Genetics.UNMODIFIABLE:
		valid_chrom_list.append("Stabilizer")
	if synchronizer_coeff != Genetics.UNMODIFIABLE:
		valid_chrom_list.append("Synchronizer")
	if power_coeff != Genetics.UNMODIFIABLE:
		valid_chrom_list.append("Power")
	if energy_coeff != Genetics.UNMODIFIABLE:
		valid_chrom_list.append("Energetic")
