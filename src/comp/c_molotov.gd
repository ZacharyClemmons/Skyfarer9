class_name CMolotov extends Component
## A bottle of spirits with a rag in the neck. Light the rag with a lit welder (hold it
## in your other hand and press Z, or use the welder on the bottle), then throw it: it
## shatters where it lands and sets the floor alight. Held too long, it goes off in
## your hands.

var lit := false
var burn := 0.0

func key() -> StringName:
	return &"molotov"

func attack_self(user: Entity) -> bool:
	if lit:
		Game.tell(user, "The rag is already burning. Throw it!", "warn")
		return true
	var inv: CInventory = user.c(&"inv")
	if inv:
		for h in inv.hands:
			if h and h != e and ((h.c(&"welder") and h.c(&"welder").lit) or (h.c(&"gadget") and h.c(&"gadget").kind == "lighter" and h.c(&"gadget").lit)):
				light(user)
				return true
	Game.tell(user, "You need a flame to light the rag. Hold a lit lighter or blowtorch in your other hand.")
	return true

func attackby(user: Entity, item: Entity) -> bool:
	var wd = item.c(&"welder")
	if wd and wd.lit and not lit:
		light(user)
		return true
	return false

func light(user: Entity) -> void:
	lit = true
	burn = 0.0
	e.set_sprite("items", "molotov_lit")
	Game.visible_message(e.root_cell(), "%s lights the rag on %s!" % [user.display_name, e.the()], "bad")
	Sfx.play("spark", e.root_cell(), 0.6)
	var m = user.c(&"mob")
	if m:
		m.refresh_doll()

func tick(dt: float) -> void:
	if not lit:
		return
	burn += dt
	if Game.atmos and fmod(burn, 1.0) < dt:
		Game.atmos.spark(e.root_cell(), 0.1)
	if burn > 12.0:
		# it's been lit too long: it goes off wherever it is
		var who: Entity = e.holder
		while who and who.holder:
			who = who.holder
		if who and who.has_c(&"health"):
			who.c(&"health").ignite(8.0)
		shatter(e.root_cell(), who)

## Smash: fire on the tile and the ones around it.
func shatter(at: Vector2i, cause: Entity) -> void:
	Sfx.play("glass", at)
	Fx.glass(at)
	Game.visible_message(at, "%s shatters and bursts into flame!" % e.display_name.capitalize(), "bad")
	if Game.atmos:
		Game.atmos.ignite(at, cause, 14.0)
		for d in Defs.DIRS4:
			if Game.map.is_passable(at + d) and Game.rng.randf() < 0.6:
				Game.atmos.ignite(at + d, cause, 8.0)
	for m in Game.at_with(at, &"health"):
		m.c(&"health").ignite(10.0)
	Proto.spawn("glass_shard", at)
	e.destroy()
