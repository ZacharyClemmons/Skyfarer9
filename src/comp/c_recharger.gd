class_name CRecharger extends Component
## tg's weapon recharger: put an energy gun (or a defibrillator) in the cradle and it
## charges while the room has power. Click it to take the weapon back.

var held: Entity = null
var _t := 0.0

func key() -> StringName:
	return &"recharger"

func attackby(user: Entity, item: Entity) -> bool:
	var g: CGadget = item.c(&"gadget")
	if g == null or not g.kind in ["gun", "defib"]:
		return false
	if held:
		Game.tell(user, "There's already something charging in it.", "warn")
		return true
	Interact.detach(item)
	held = item
	_t = 0.0
	item.visible = false
	item.holder = e
	e.set_sprite("objects", "recharger_on")
	Game.visible_message(e.cell, "%s puts %s in the recharger." % [user.display_name, item.the()])
	Sfx.play("click", e.cell, 0.5)
	return true

func attack_hand(user: Entity) -> bool:
	if held == null:
		return false
	var it := held
	held = null
	_t = 0.0
	var machine: CMachine = e.c(&"machine")
	if machine: machine.active = false
	it.holder = null
	it.visible = true
	Game.drop_to_map(it, e.cell)
	it.place(e.cell)
	var inv: CInventory = user.c(&"inv")
	if inv: inv.put_in_hands(it, inv.active)
	e.set_sprite("objects", "recharger")
	var g: CGadget = it.c(&"gadget")
	Game.tell(user, "You take %s out. (%d/%d)" % [it.the(), g.charges, g.max_charges])
	return true

func tick(dt: float) -> void:
	var m: CMachine = e.c(&"machine")
	if not is_instance_valid(held) or held.removed:
		held = null
		_t = 0.0
		if m: m.active = false
		return
	if m and not m.operable():
		m.active = false
		return
	var g: CGadget = held.c(&"gadget")
	if g.charges >= g.max_charges:
		_t = 0.0
		if m: m.active = false
		return
	if m: m.active = true
	_t += dt
	if _t >= 1.5:
		var charge_steps := floori(_t / 1.5)
		_t -= charge_steps * 1.5
		g.charges = mini(g.max_charges, g.charges + charge_steps)
		if g.charges >= g.max_charges and m:
			m.active = false

func on_removed() -> void:
	if not is_instance_valid(held) or held.removed: return
	var item := held
	held = null
	item.holder = null
	item.visible = true
	Game.drop_to_map(item, e.root_cell())
	item.place(e.root_cell())

func examine(_user: Entity, lines: Array) -> void:
	if held:
		var g: CGadget = held.c(&"gadget")
		lines.append("%s is charging: %d/%d." % [held.display_name.capitalize(), g.charges, g.max_charges])
