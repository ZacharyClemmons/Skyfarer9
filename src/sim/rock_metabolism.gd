class_name RockMetabolism extends RefCounted
## TG golem food/status effects, driven by the Rock Eater and Rock Absorber traits.
const NUTRITION := {"glass": 0.5, "iron": 3.0, "uranium": 5.0, "silver": 4.0, "plasma": 6.0, "plasteel": 7.0, "gold": 5.0, "diamond": 9.0, "titanium": 5.0, "bananium": 10.0, "lightbulb": 0.0, "bluespace": 10.0, "gibtonite": 5.0}
const EFFECT_TRAITS := {
	"uranium": ["nohunger"], "silver": ["antimagic", "holy"],
	"plasma": ["resisthighpressure", "resistheat", "ashstorm_immune"],
	"plasteel": ["resistlowpressure", "resistcold"], "gold": ["ricochet_shiny"],
	"bananium": ["waddling", "no_slip_water"],
}

## TG golem status duration: stone anatomy lengthens absorption. Large food
## portions use a diminishing exponent rather than a linear duration bonus.
static func duration(user: Entity, multiplier := 1.0, lightbulb := false) -> float:
	var h: CHealth = user.c(&"health")
	var factor := 0.1
	var exponent := 0.5
	if h:
		for part in Body.PARTS:
			if not h.missing.has(part) and h.body_materials.get(part, "flesh") == "stone":
				factor += 0.11 if lightbulb else 0.15
				exponent = maxf(0.2, exponent - 0.05)
	var base := 120.0 if lightbulb else 300.0
	return base * (pow(factor * multiplier, exponent) if multiplier > 1.0 else factor * multiplier)

static func mineral(item: Entity) -> String:
	if item == null or item.removed:
		return ""
	var stack: CStack = item.c(&"stack")
	var kind := stack.material if stack else item.proto.trim_prefix("ore_")
	if kind in ["metal", "rods"]: kind = "iron"
	if kind == "rglass": kind = "glass"
	if item.proto in ["light_bulb", "light_tube"]: kind = "lightbulb"
	return kind if NUTRITION.has(kind) else ""

static func can_eat(user: Entity, item: Entity) -> bool:
	return Traits.has(user, "rock_eater") and mineral(item) != "" and user.has_c(&"health") and user.c(&"health").can_use_hands() and (item.root() == user or Genetics.can_reach(user, item))

static func consume(user: Entity, item: Entity) -> bool:
	if not can_eat(user, item): return false
	var kind := mineral(item)
	process(user, 0.0)
	var existing := str(user.get_meta("rock_buff", ""))
	var exclusive := not kind in ["glass", "lightbulb", "bluespace", "gibtonite"]
	if exclusive and existing != "" and existing != kind:
		Game.tell(user, "You cannot absorb a different mineral until the %s effect expires." % existing, "warn")
		return true
	var n: CNeeds = user.c(&"needs")
	if n: n.nutrition = minf(100.0, n.nutrition + NUTRITION[kind] / 6.0)
	if Traits.has(user, "rock_metamorphic"):
		match kind:
			"glass": pass
			"iron":
				var h: CHealth = user.c(&"health")
				var heal := minf(3.0, h.brute)
				h.adjust("brute", -heal)
				h.adjust("burn", -(3.0 - heal))
			"lightbulb":
				user.set_meta("rock_glow_until", Game.time + duration(user, 1.0, true))
				if not user.has_meta("rock_glow"):
					var glow := Proto.spawn("rock_glow", user.cell)
					glow.holder = user
					Game.lift_from_map(glow)
					user.set_meta("rock_glow", glow)
			"bluespace", "gibtonite":
				MineralHand.create(user, kind, item)
			_:
				if existing == "":
					user.set_meta("rock_buff", kind)
					Traits.add_all(user, EFFECT_TRAITS.get(kind, []), "rock_metabolism")
					if kind == "plasma": user.c(&"health").burn_mod *= 0.05
					if kind == "titanium": user.c(&"health").brute_mod *= 0.8
				user.set_meta("rock_buff_until", Game.time + duration(user))
				Game.tell(user, "You absorb %s. Its effect lasts %ds in this body." % [kind, roundi(duration(user))], "info")

	Sfx.play("eat", user.cell)
	var stack: CStack = item.c(&"stack")
	if kind != "gibtonite" or not Traits.has(user, "rock_metamorphic"):
		if stack: stack.use(1)
		else: item.destroy()
	return true

static func mining_bonus(user: Entity, target: Entity) -> float:
	if user.get_meta("rock_buff", "") != "titanium" or not target.has_c(&"health") or target.c(&"health").lying():
		return 0.0
	var factions: Array = target.tags.get("factions", [])
	return 30.0 if "mining" in factions or "boss" in factions else 0.0

static func clear(user: Entity) -> void:
	var kind := str(user.get_meta("rock_buff", ""))
	var h: CHealth = user.c(&"health")
	if h:
		if kind == "plasma": h.burn_mod /= 0.05
		if kind == "titanium": h.brute_mod /= 0.8
	Traits.remove_source(user, "rock_metabolism")
	user.remove_meta("rock_buff")
	user.remove_meta("rock_buff_until")
	var m: CMob = user.c(&"mob")
	if kind == "diamond" and m and m.doll: m.doll.modulate.a = 1.0
	if kind != "": Game.tell(user, "The %s effect fades." % kind)

static func process(user: Entity, dt: float) -> void:
	if user.has_meta("rock_buff") and (not Traits.has(user, "rock_metamorphic") or Game.time >= user.get_meta("rock_buff_until", 0.0)):
		clear(user)
	if user.has_meta("rock_glow"):
		var glow: Entity = user.get_meta("rock_glow")
		if not Traits.has(user, "rock_metamorphic") or Game.time >= user.get_meta("rock_glow_until", 0.0):
			if is_instance_valid(glow) and not glow.removed: glow.destroy()
			user.remove_meta("rock_glow")
		else:
			if is_instance_valid(glow): glow.c(&"light").on_moved(user.cell, user.cell)
	if user.get_meta("rock_buff", "") == "diamond":
		var m: CMob = user.c(&"mob")
		if m and m.doll:
			m.doll.modulate.a = 200.0 / 255.0 if m.moving else maxf(0.0, m.doll.modulate.a - dt * 80.0 / 255.0)

static func reveal(user: Entity) -> void:
	if user.get_meta("rock_buff", "") == "diamond" and user.has_c(&"mob"):
		user.c(&"mob").doll.modulate.a = 200.0 / 255.0

static func on_burned(user: Entity, amount: float) -> void:
	if user.get_meta("rock_buff", "") != "plasma" or amount <= 0.0: return
	var area: Area = Game.map.area_at(user.root_cell())
	if area and is_instance_valid(area.apc) and area.apc.has_c(&"apc"):
		var apc: CApc = area.apc.c(&"apc")
		apc.charge = minf(apc.capacity, apc.charge + amount * apc.capacity * 0.005)
		Fx.beam(user.cell, area.apc.cell, Color("#b66aff"))
