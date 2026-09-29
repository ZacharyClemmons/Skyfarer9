class_name CSkillChip extends Component
const DEFS := {
	"self_surgery": {"name": "Self Surgery", "traits": ["self_surgery"]},
	"entrails_reader": {"name": "Entrails Reader", "traits": ["entrails_reader"]},
	"musical": {"name": "Memory of a Musical", "traits": ["musical_chip"]},
	"useless_adapter": {"name": "Useless Adapter", "traits": [], "multiple": true, "complexity": 0, "slots": 0},
	"engineer": {"name": "Engineering Circuitry", "traits": ["know_engi_wires"], "category": "job", "slots": 2},
	"research_director": {"name": "True Strength", "traits": ["rod_suplex", "strength"]},
	"matrix_taunt": {"name": "Taunt 2 Dodge", "traits": ["matrix_taunt"]},
}
var kind := "self_surgery"
var active := false
var ready := 0.0
var owner: Entity
var complexity := 1
var slot_use := 1
var removable := true

func key() -> StringName: return &"skillchip"
func setup(p: Dictionary) -> CSkillChip:
	kind = p.get("kind", kind)
	complexity = maxi(0, int(p.get("complexity", DEFS.get(kind, {}).get("complexity", complexity))))
	slot_use = maxi(0, int(p.get("slots", DEFS.get(kind, {}).get("slots", slot_use))))
	removable = p.get("removable", removable)
	return self
func on_added() -> void:
	e.display_name = DEFS.get(kind, {}).get("name", kind) + " skillchip"
func toggle(force_off := false) -> String:
	if not is_instance_valid(owner) or not owner.has_c(&"health") or (not force_off and not Organs.has(owner.c(&"health"), "brain")):
		return "No brain detected."
	if not force_off and Game.time < ready: return "Chip is recharging for %ds." % ceili(ready - Game.time)
	if not active and not force_off and SkillChips.used_complexity(owner) + complexity > SkillChips.capacity(owner):
		return "Not enough complexity capacity."
	if force_off and not active: return ""
	active = not active
	var source := "skillchip:%d" % e.id
	if active: Traits.add_all(owner, DEFS.get(kind, {}).get("traits", []), source)
	else: Traits.remove_source(owner, source)
	if not active and kind == "matrix_taunt": Traits.remove(owner, "unhittable_projectiles", source)
	ready = Game.time + 300.0
	return ""
func on_removed() -> void:
	if is_instance_valid(owner):
		Traits.remove_source(owner, "skillchip:%d" % e.id)
		SkillChips.list_of(owner).erase(e)
func examine(_user: Entity, lines: Array) -> void:
	lines.append("Uses %d brain slots and %d complexity. Implant and activate it in a lesson lectern. Activation/deactivation recharges for five minutes." % [slot_use, complexity])
