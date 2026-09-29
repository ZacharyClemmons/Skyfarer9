class_name CSecurityGear extends Component
## Stun batons and handcuffs.

var kind := "baton"
var on := true
var charge := 20
var next_stun := 0.0
# tg /obj/item/melee/baton/security
const STAMINA_DAMAGE := 60.0
const KNOCKDOWN := 5.0
const COOLDOWN := 2.5

func key() -> StringName:
	return &"secgear"

func setup(p: Dictionary) -> CSecurityGear:
	kind = p.get("kind", kind)
	return self

func attack_self(user: Entity) -> bool:
	if kind == "baton":
		on = not on
		Game.tell(user, "You turn the baton %s." % ("on" if on else "off"))
		return true
	return false

## Returns true if the hit was handled as a stun.
func stun_hit(user: Entity, target: Entity) -> bool:
	if kind != "baton" or not on or charge <= 0:
		return false
	var h: CHealth = target.c(&"health")
	if h == null:
		return false
	if Game.time < next_stun:
		# tg: the baton needs 2.5 s to recharge between stuns; until then it's a club
		return false
	next_stun = Game.time + COOLDOWN
	charge -= 1
	# tg check_block: a held shield can stop it
	if Combat.check_block(target, "the stun baton", 10.0, 15.0):
		return true
	# tg baton_effect: stamina through ENERGY armour (15 pen), knockdown, then
	# additional_effects_non_cyborg: jitter 40 s, confusion 10 s, stutter 16 s, and 2 s later
	# the muscles seize again
	var armour := maxf(0.0, Combat.armor_vs(target, "chest", "laser") - 15.0)
	h.adjust("stamina", STAMINA_DAMAGE * (100.0 - armour) / 100.0, user)
	h.knockdown(KNOCKDOWN)
	h.set_status_if_lower("jitter", 40.0)
	h.set_status_if_lower("confusion", 10.0)
	h.set_status_if_lower("stutter", 16.0)
	Sfx.play("stun", target.cell)
	Game.visible_message(target.cell, "%s stuns %s with the stun baton!" % [user.display_name, target.display_name], "bad")
	Game.tell(target, "[b]%s stuns you with the stun baton![/b]" % user.display_name, "bad")
	target.get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(target) and not target.removed and not h.dead:
			if not h.has_status("knockdown"):
				Game.tell(target, "Your muscles seize, making you collapse!", "bad")
			h.knockdown(KNOCKDOWN))
	return true

func cuff(user: Entity, target: Entity) -> void:
	if target.has_c(&"monkeyai"):
		target.c(&"monkeyai").on_attempt_cuff(user) # tg COMSIG_CARBON_CUFF_ATTEMPTED
	var h: CHealth = target.c(&"health")
	if h == null or h.cuffed:
		return
	Game.visible_message(target.cell, "%s is trying to put handcuffs on %s!" % [user.display_name, target.display_name], "warn")
	DoAfter.start(user, target, 3.5, func(ok):
		if ok and not h.cuffed:
			h.cuffed = true
			var inv = user.c(&"inv")
			if inv:
				inv.remove_ref(e)
			e.holder = target
			e.visible = false
			Game.visible_message(target.cell, "%s handcuffs %s." % [user.display_name, target.display_name], "warn")
			Bus.stimulus.emit({"type": "cuffed", "actor": user, "target": target, "cell": target.cell, "loud": 4.0})
	)

func examine(_user: Entity, lines: Array) -> void:
	if kind == "baton":
		lines.append("It is %s. Charge: %d." % ["on" if on else "off", charge])

func ai_tags(out: Dictionary) -> void:
	out[kind] = true
	out["weapon"] = kind == "baton"
