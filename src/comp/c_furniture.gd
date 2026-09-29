class_name CFurniture extends Component
## Beds, chairs, sleepers and wall cabinets: things people use in place.
##   "bed"      lie down / sleep (NPCs claim one as theirs)
##   "seat"     sit (comfort)
##   "sleeper"  medical pod: slowly heals whoever lies in it (needs power)
##   "cabinet"  wall cabinet holding one item (fire extinguishers)
##   "table"    items can be placed on it

var kind := "seat"
var occupant: Entity = null
var owner_id := 0
var stored: Entity = null
var cabinet_item := ""

func key() -> StringName:
	return &"furniture"

func setup(p: Dictionary) -> CFurniture:
	kind = p.get("kind", kind)
	cabinet_item = p.get("item", "")
	return self

func on_added() -> void:
	if kind == "cabinet" and cabinet_item != "":
		stored = Proto.spawn(cabinet_item, e.cell)
		Game.lift_from_map(stored)
		stored.holder = e
		stored.visible = false

func free_for(user: Entity) -> bool:
	if occupant != null and (occupant.removed or occupant.cell != e.cell or occupant == user):
		occupant = null
	return occupant == null

func occupy(user: Entity) -> void:
	occupant = user

func tick(dt: float) -> void:
	if occupant == null:
		return
	if occupant.removed or occupant.cell != e.cell:
		occupant = null
		return
	if kind == "sleeper":
		var m: CMachine = e.c(&"machine")
		if m and m.operable():
			var h: CHealth = occupant.c(&"health")
			if h and not h.dead:
				h.adjust("oxy", -2.0 * dt)
				h.adjust("tox", -0.6 * dt)
				h.adjust("brute", -0.35 * dt)
				h.adjust("burn", -0.35 * dt)
				h.body_temp = move_toward(h.body_temp, Defs.BODYTEMP_NORMAL, dt * 1.5)

func attack_hand(user: Entity) -> bool:
	# tg: clicking a chair or bed someone is buckled to unbuckles them
	if occupant != null and is_instance_valid(occupant) and occupant.has_c(&"mob") and occupant.c(&"mob").buckled == e:
		Buckle.unbuckle(user, occupant)
		return true
	match kind:
		"cabinet":
			if stored != null:
				var inv = user.c(&"inv")
				if inv and inv.put_in_hands(stored):
					stored = null
					e.set_sprite("objects", "extinguisher_cabinet_empty")
					Game.tell(user, "You take the extinguisher from the cabinet.")
				return true
		"bed", "sleeper":
			if user.cell == e.cell:
				var h: CHealth = user.c(&"health")
				if h and not h.sleeping:
					Game.tell(user, "You lie down and close your eyes. (Move to wake up.)")
					h.fall_asleep()
					occupy(user)
				return true
	return false

func attackby(user: Entity, item: Entity) -> bool:
	if kind == "cabinet" and stored == null and item.proto == cabinet_item:
		var inv = user.c(&"inv")
		inv.remove_ref(item)
		item.holder = e
		item.visible = false
		stored = item
		e.set_sprite("objects", "extinguisher_cabinet")
		return true
	if kind in ["table", "counter"]:
		# tg table_place_act: off combat mode you set it down where you clicked; in
		# combat mode you bash the table instead
		var m: CMob = user.c(&"mob")
		if m and m.combat:
			return false
		var inv = user.c(&"inv")
		if inv and inv.active_item() == item:
			inv.drop(item, e.cell)
			item.set_pixel_offset(CFurniture.table_offset(e, Interact.click_pos))
			return true
	return false

## Where on a table an item lands: centred on the click, kept on the table top (tg clamps
## the icon to within 16 px of the tile centre).
static func table_offset(table: Entity, click) -> Vector2:
	if click == null:
		return Vector2.ZERO
	# an item sprite's centre sits 16 px above its anchor (the tile's bottom centre)
	var off: Vector2 = click - (table.global_position + Vector2(0, -16))
	return Vector2(clampf(off.x, -11.0, 11.0), clampf(off.y, -12.0, 3.0)).round()

func verbs(user: Entity, out: Array) -> void:
	if kind in ["bed", "sleeper"] and user.cell == e.cell:
		out.append({"name": "Sleep", "cb": attack_hand.bind(user), "priority": 5})
	if kind == "cabinet" and stored != null and user.adjacent(e):
		out.append({"name": "Take extinguisher", "cb": attack_hand.bind(user), "priority": 6})
	# tg tables: wrench_act_secondary (right-click) takes them apart
	var held: Entity = user.c(&"inv").active_item() if user.c(&"inv") else null
	if held and held.has_c(&"item") and held.c(&"item").tool == "wrench" and Construction.FURNITURE_SHEETS.has(e.proto) and user.adjacent(e):
		out.append({"name": "Disassemble", "cb": func(): Construction.tool_act(user, held, e), "priority": 4})

func ai_tags(out: Dictionary) -> void:
	out[kind] = true
	if kind == "cabinet" and stored != null:
		out["has_extinguisher"] = true
