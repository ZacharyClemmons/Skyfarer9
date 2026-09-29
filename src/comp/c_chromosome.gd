class_name CChromosome extends Component
## tg /obj/item/chromosome (code/game/objects/items/chromosome.dm). Recycling a used
## research activator at the DNA console sometimes yields one; the console applies it to a
## mutation on the scanner's occupant (once per mutation).

const NAMES := {"stabilizer": "stabilizer chromosome", "synchronizer": "synchronizer chromosome", "power": "power chromosome", "energy": "energetic chromosome"}
const DESCS := {
	"stabilizer": "A chromosome that reduces mutation instability by 20%.",
	"synchronizer": "A chromosome that reduces mutation knockback and downsides by 50%.",
	"power": "A chromosome that increases mutation power by 50%.",
	"energy": "A chromosome that reduces action based mutation cooldowns by 50%.",
}
## the coefficient each sets, and its generate_chromosome weight
const COEFF := {"stabilizer": ["stabilizer_coeff", 0.8, 1], "synchronizer": ["synchronizer_coeff", 0.5, 5], "power": ["power_coeff", 1.5, 5], "energy": ["energy_coeff", 0.5, 5]}

var kind := "stabilizer"

func key() -> StringName:
	return &"chromosome"

func setup(p: Dictionary) -> CChromosome:
	kind = p.get("kind", kind)
	return self

## tg can_apply
static func can_apply(k: String, m: Mutation) -> bool:
	if m == null or m.owner == null or not is_instance_valid(m.owner) or m.owner.removed or m.can_chromosome != Genetics.CHROMOSOME_NONE:
		return false
	var field: String = COEFF[k][0]
	return m.get(field) != Genetics.UNMODIFIABLE

## tg apply: the coefficient is set, and the chromosome is spent
static func apply(k: String, m: Mutation) -> void:
	var field: String = COEFF[k][0]
	if m.get(field) != Genetics.UNMODIFIABLE:
		m.set(field, COEFF[k][1])
	m.can_chromosome = Genetics.CHROMOSOME_USED
	m.chromosome_name = NAMES[k]
	if m.owner:
		GeneFx.setup(m.owner, m)
		var d: CDna = m.owner.c(&"dna")
		if d:
			d.update_instability(false)

## tg generate_chromosome: pick_weight over the kinds (stabilizers are rarer)
static func generate() -> String:
	var total := 0
	for k in COEFF:
		total += COEFF[k][2]
	var r := Game.rng.randi_range(1, total)
	for k in COEFF:
		r -= COEFF[k][2]
		if r <= 0:
			return k
	return "power"
