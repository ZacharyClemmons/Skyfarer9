class_name CStack extends Component
## Stackable materials: metal/glass/plasteel/plasma sheets, cable coils.

var amount := 10
var max_amount := 50
var material := "metal"

func key() -> StringName:
	return &"stack"

func setup(p: Dictionary) -> CStack:
	amount = p.get("amount", amount)
	material = p.get("material", material)
	return self

func use(n: int) -> bool:
	if amount < n:
		return false
	amount -= n
	if amount <= 0:
		e.destroy()
	return true

## tg item_interaction: using a stack on a stack of the same thing pours this one into it.
func attackby(user: Entity, item: Entity) -> bool:
	var other: CStack = item.c(&"stack")
	if other == null or item == e:
		return false
	# tg sheet/glass attackby rods: a rod and a sheet of glass make a sheet of reinforced glass
	if (material == "glass" and other.material == "rods") or (material == "rods" and other.material == "glass"):
		return _reinforce(user, self if material == "glass" else other, other if material == "glass" else self)
	if item.proto != e.proto:
		return false
	var n := mini(amount, other.max_amount - other.amount)
	if n <= 0:
		Game.tell(user, "Your %s stack is full." % item.display_name, "warn")
		return true
	other.amount += n
	Game.tell(user, "Your %s stack now contains %d." % [item.display_name, other.amount])
	use(n)
	return true

static func _reinforce(user: Entity, glass: CStack, rods: CStack) -> bool:
	var where := user.cell
	glass.use(1)
	rods.use(1)
	var inv: CInventory = user.c(&"inv")
	# add it to reinforced glass already in hand, like tg's merge into the held stack
	if inv:
		for h in inv.hands:
			if h and h.proto == "sheet_rglass" and h.c(&"stack").amount < h.c(&"stack").max_amount:
				h.c(&"stack").amount += 1
				Game.tell(user, "You reinforce a sheet of glass with a rod. You now have %d sheets of reinforced glass." % h.c(&"stack").amount)
				return true
	var rg := Proto.spawn("sheet_rglass", where)
	if inv == null or not inv.put_in_hands(rg):
		rg.place(where)
	Game.tell(user, "You reinforce a sheet of glass with a rod.")
	return true

## tg split_n_take: peel `n` off into the user's free hand.
func split_into_hand(user: Entity, n: int) -> Entity:
	n = clampi(n, 1, amount)
	var inv: CInventory = user.c(&"inv")
	if inv == null or inv.free_hand() < 0 or n >= amount and e.holder == user:
		return null
	var part := Proto.spawn(e.proto, user.cell, {"comps": {"stack": {"amount": n}}})
	amount -= n
	if not inv.put_in_hands(part, inv.active if inv.active_item() == null else -1):
		part.place(user.cell)
	if amount <= 0:
		e.destroy()
	Game.tell(user, "You take %d %s out of the stack." % [n, "piece" if n == 1 else "pieces"])
	return part

func verbs(user: Entity, out: Array) -> void:
	if RockMetabolism.can_eat(user, e):
		out.append({"name": "Eat one mineral", "cb": RockMetabolism.consume.bind(user, e), "priority": 6})
	if amount > 1 and user.has_c(&"inv") and user.c(&"inv").free_hand() >= 0 and (e.root() == user or user.adjacent(e)):
		out.append({"name": "Take one", "cb": split_into_hand.bind(user, 1), "priority": 5})
		out.append({"name": "Split in half", "cb": split_into_hand.bind(user, amount / 2), "priority": 5})

func examine(_user: Entity, lines: Array) -> void:
	lines.append("There are %d in the stack." % amount)
	if Traits.has(_user, "rock_eater") and RockMetabolism.mineral(e) != "":
		lines.append("You can eat this mineral. Z eats one piece; Rock Absorber also grants its properties.")

func attack_self(user: Entity) -> bool:
	return RockMetabolism.consume(user, e)

func ai_tags(out: Dictionary) -> void:
	out["mat_" + material] = true
