class_name CItem extends Component
## Anything that can be picked up. Tool qualities follow SS13's tool behaviours:
## "wrench", "screwdriver", "crowbar", "wirecutters", "welder", "multitool", "dig", "mop".

var icon := ""
var w_class := 2 # 1 tiny .. 5 huge
var slots: Array = [] # equip slots this item fits (besides hands)
var force := 0.0
var damtype := "brute"
var attack_verb := "hits"
var tool := ""
var tool_speed := 1.0
var category := "misc" # used by AI queries: tool, food, drink, medical, weapon, clothing, material, tank...
var value := 1.0
# tg melee stats (code/game/objects/items.dm)
var throwforce := 0.0
var sharpness := "" # "", "edged", "pointy"
var armour_penetration := 0.0
var wound_bonus := 0.0
var exposed_wound_bonus := 0.0 # tg exposed_wound_bonus: extra when the part is bare
var block_chance := 0.0
var attack_speed := 0.8 # CLICK_CD_MELEE
var force_wielded := 0.0 # two-handed weapons (tg two_handed component)
var is_wielded := false
var demolition := 1.0
var caltrop := 0.0 # tg caltrop component: stepping on this barefoot hurts (min damage)
var conducts := false # tg CONDUCTS_ELECTRICITY: metal things a live grille can shock you through

func key() -> StringName:
	return &"item"

func setup(p: Dictionary) -> CItem:
	icon = p.get("icon", icon)
	w_class = p.get("w", w_class)
	slots = p.get("slots", slots)
	force = p.get("force", force)
	damtype = p.get("damtype", damtype)
	attack_verb = p.get("verb", attack_verb)
	tool = p.get("tool", tool)
	tool_speed = p.get("tool_speed", tool_speed)
	category = p.get("cat", category)
	throwforce = p.get("throwforce", throwforce)
	sharpness = p.get("sharp", sharpness)
	armour_penetration = p.get("ap", armour_penetration)
	wound_bonus = p.get("wound", wound_bonus)
	exposed_wound_bonus = p.get("exposed", exposed_wound_bonus)
	block_chance = p.get("block", block_chance)
	attack_speed = p.get("cd", attack_speed)
	force_wielded = p.get("wield", force_wielded)
	demolition = p.get("demo", demolition)
	caltrop = p.get("caltrop", caltrop)
	conducts = p.get("conducts", tool != "" and tool != "mop" or category in ["tank", "extinguisher"])
	return self

## tg shard welder_act: a lit welder melts a glass shard back into a sheet of glass.
func attackby(user: Entity, item: Entity) -> bool:
	if e.proto != "glass_shard":
		return false
	var wd = item.c(&"welder")
	if wd == null or not wd.lit:
		return false
	var where := e.root_cell()
	var in_hand := e.holder == user
	e.destroy()
	var sheet := Proto.spawn("sheet_glass", where, {"comps": {"stack": {"amount": 1}}})
	if in_hand and user.has_c(&"inv"):
		user.c(&"inv").put_in_hands(sheet)
	Sfx.play("welder", where, 0.6)
	Game.tell(user, "You melt the glass shard down into a sheet of glass.")
	return true

## Two-handed weapons: Z wields and unwields (needs the other hand free).
func attack_self(user: Entity) -> bool:
	if force_wielded <= 0.0:
		return false
	var inv: CInventory = user.c(&"inv")
	if inv == null:
		return false
	if not is_wielded:
		if Traits.has(user, "no_twohanding"):
			Game.tell(user, "Your arms cannot grip a weapon with both hands.", "warn")
			return true
		var i := inv.hands.find(e)
		if i < 0 or inv.hands[1 - i] != null or not inv.hand_usable(1 - i):
			Game.tell(user, "You need your other hand free to wield %s." % e.the(), "warn")
			return true
		is_wielded = true
		Game.tell(user, "You grip %s with both hands." % e.the())
	else:
		is_wielded = false
		Game.tell(user, "You loosen your grip on %s." % e.the())
	return true

func examine(_user: Entity, lines: Array) -> void:
	var sizes := ["", "tiny", "small", "normal-sized", "bulky", "huge"]
	lines.append("It is a %s item." % sizes[clampi(w_class, 1, 5)])
	# tg's force_string
	var f := maxf(force, force_wielded)
	if f > 0:
		var s := "weak" if f < 7 else ("average" if f < 11 else ("robust" if f < 16 else ("strong" if f < 21 else ("exceptional" if f < 26 else "godlike"))))
		lines.append("[color=#8a9cb0]It looks like a %s weapon%s.%s[/color]" % [s, " when wielded in both hands" if force_wielded > force else "", " It could block attacks." if block_chance > 0 else ""])

func verbs(user: Entity, out: Array) -> void:
	if e.on_map() and user.has_c(&"inv") and user.adjacent(e):
		out.append({"name": "Pick up", "cb": Interact.pickup.bind(user, e), "priority": 10})

func ai_tags(out: Dictionary) -> void:
	out[category] = true
	if tool != "":
		out["tool_" + tool] = true
