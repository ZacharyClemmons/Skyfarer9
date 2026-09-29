class_name MineralHand extends Component
var kind := "bluespace"
var held: Entity
var expires := 0.0
func key() -> StringName: return &"mineralhand"
static func create(user: Entity, mineral_kind: String, item: Entity) -> void:
	var inv: CInventory = user.c(&"inv")
	if mineral_kind == "bluespace" and item.has_c(&"stack") and item.c(&"stack").amount == 1 and item.holder == user: inv.drop(item)
	if mineral_kind == "gibtonite":
		Interact.detach(item)
		if inv.free_hand() < 0:
			for h in inv.hands.duplicate():
				if h: inv.drop(h)
	var hand := Proto.spawn("mineral_hand", user.cell)
	var mh: MineralHand = hand.c(&"mineralhand")
	mh.kind = mineral_kind
	hand.display_name = "aether finger" if mineral_kind == "bluespace" else "stabilised gibtonite fist"
	if not inv.put_in_hands(hand):
		hand.destroy()
		if mineral_kind == "gibtonite": item.place(user.cell)
		return
	if mineral_kind == "gibtonite":
		mh.held = item
		item.holder = hand
		mh.expires = Game.time + 120.0
		hand.set_meta("nodrop", true)
		Genetics.after(120.0, func():
			if is_instance_valid(hand) and not hand.removed: mh.release(user))
func use_on(user: Entity, cell: Vector2i) -> void:
	if kind == "bluespace":
		if maxi(absi(cell.x - user.cell.x), absi(cell.y - user.cell.y)) > 7 or not Game.map.is_passable(cell):
			Game.tell(user, "That destination is too far away or blocked.", "warn")
			return
		DoAfter.start(user, e, 2.0, func(ok):
			if not ok: return
			var landings := []
			for y in range(cell.y - 2, cell.y + 3):
				for x in range(cell.x - 2, cell.x + 3):
					var candidate := Vector2i(x, y)
					if Game.map.is_passable(candidate): landings.append(candidate)
			if landings.is_empty(): return
			var landing: Vector2i = Genetics.rand_pick(landings)
			for mob in Game.at_with(landing, &"health"): mob.c(&"health").knockdown(2.0)
			user.place(landing)
			Fx.smoke_puff(landing)
			e.destroy())
	else:
		var launch := held
		held = null
		if is_instance_valid(launch):
			launch.holder = null
			launch.visible = true
			Game.drop_to_map(launch, user.cell)
			launch.place(user.cell)
			Interact.throw_item(user, launch, cell, 10)
			prime(launch, user)
		e.destroy()
static func prime(ore: Entity, user: Entity, seconds := 2.0) -> void:
	Genetics.after(seconds, func():
		if is_instance_valid(ore) and not ore.removed:
			var radii: Array = {"high": [2, 4, 9], "medium": [1, 2, 5]}.get(ore.tags.get("quality", "low"), [-1, 1, 3])
			Explosion.explode(ore.root_cell(), radii[0], radii[1], radii[2], user if is_instance_valid(user) else null)
			ore.destroy())
func release(user: Entity) -> void:
	if is_instance_valid(held) and not held.removed:
		var at := e.root_cell()
		held.holder = null
		held.visible = true
		Game.drop_to_map(held, at)
		held.place(at)
		prime(held, user, 10.0)
		held = null
	e.destroy()
func on_removed() -> void:
	if is_instance_valid(held) and not held.removed: held.destroy()
	held = null
