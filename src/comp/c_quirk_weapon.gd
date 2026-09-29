class_name CQuirkWeapon extends Component
## A melee weapon that does one specific thing besides hurt people.
##
## The whole reason this component exists is that "+3 damage" is not a reason to carry a
## different sword. A blade that arcs to everything touching your target is a reason to
## fight in a corridor; a maul that sets things alight is a reason not to fight in your
## own engine room. Each effect here is a tactic with a drawback attached.

var effect := ""
var charge := 0 # for effects that build up over several blows

func key() -> StringName:
	return &"quirkweapon"

func setup(p: Dictionary) -> CQuirkWeapon:
	effect = String(p.get("effect", ""))
	return self

const NOTES := {
	"salt": "Wounds it opens will not close on their own — they keep bleeding until treated.",
	"arc": "Every third blow arcs to everything else touching your target.",
	"ignite": "Sets what it hits alight. Including, on a bad day, what you are standing on.",
	"silent": "Draws and strikes without a sound. Nothing hears the fight start.",
}

func examine(_user: Entity, lines: Array) -> void:
	var n := String(NOTES.get(effect, ""))
	if n != "":
		lines.append("[color=#e8a83a]%s[/color]" % n)
	if effect == "arc":
		lines.append("[color=#7fd4ff]Charge: %d / 3.[/color]" % charge)

## Called by the combat layer after a successful melee hit with this weapon.
func on_hit(user: Entity, target: Entity, dealt: float) -> void:
	match effect:
		"salt": _salt(user, target)
		"arc": _arc(user, target, dealt)
		"ignite": _ignite(user, target)
		"silent": pass # handled by suppressing the stimulus, below

func _salt(_user: Entity, target: Entity) -> void:
	SkyBuffs.apply(target, "bleed", 1.6, 45.0, "brinesteel")
	var h: CHealth = target.c(&"health")
	if h != null and h.has_method("add_bleed"):
		h.add_bleed(1.2)
	Game.visible_message(target.cell, "[color=#ff8a5a]The salt in the wound keeps it open.[/color]", "combat_warn")

func _arc(user: Entity, target: Entity, dealt: float) -> void:
	charge += 1
	if charge < 3:
		return
	charge = 0
	var hit := 0
	for other in Game.in_radius(target.cell, 1, &"health"):
		if other == target or other == user:
			continue
		var h: CHealth = other.c(&"health")
		if h == null or h.dead:
			continue
		h.take_damage(dealt * 0.55, "burn", user)
		Fx.beam(target.cell, other.cell, Color("#9ad8ff"))
		hit += 1
	if hit > 0:
		Game.visible_message(target.cell, "[b][color=#9ad8ff]The blade discharges — the arc jumps to %d other%s.[/color][/b]" % [
			hit, "" if hit == 1 else "s"], "combat")
		Sfx.play("spark", target.cell, 0.8)
	else:
		Game.visible_message(target.cell, "[color=#9ad8ff]The blade discharges with a crack and nothing to jump to.[/color]", "combat")

func _ignite(user: Entity, target: Entity) -> void:
	if Game.rng.randf() > 0.55:
		return
	var f = target.c(&"flammable")
	if f != null and f.has_method("ignite"):
		f.ignite()
	var h: CHealth = target.c(&"health")
	if h != null:
		h.take_damage(6.0, "burn", user)
	SkyBuffs.apply(target, "scorch", 1.0, 12.0, "cinder maul")
	Fx.flame_on(target)
	Game.visible_message(target.cell, "[b][color=#ff8a5a]%s catches light.[/color][/b]" % target.display_name.capitalize(), "combat")
	# and the tile, which is how people lose their own engine room
	if Game.atmos != null and not Game.map.is_outdoor(target.cell):
		Game.atmos.add_heat(Game.map.idx(target.cell), 90000.0)

## A silent weapon suppresses the noise a fight makes. Everything that listens for
## `attack` stimuli — every hunting creature on the island — simply never hears it.
func silences() -> bool:
	return effect == "silent"
