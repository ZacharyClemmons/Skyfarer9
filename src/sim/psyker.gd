class_name Psyker extends RefCounted
const POWERS := ["psychic_projection", "psychic_booster", "psychic_wall", "echo_focus"]
const ECHO_OPTIONS := ["Blood", "Items", "Floor Objects"]

static func echo_options(user: Entity) -> Array:
	if not user.has_meta("echo_options"):
		user.set_meta("echo_options", ["Blood", "Items"])
	return user.get_meta("echo_options")

static func toggle_echo(user: Entity, option: String) -> bool:
	if not Traits.has(user, "psyker") or not option in ECHO_OPTIONS:
		return false
	var selected := echo_options(user)
	if option in selected: selected.erase(option)
	else: selected.append(option)
	return true

static func echo_highlight(user: Entity, entity: Entity) -> bool:
	var selected := echo_options(user)
	if entity.has_c(&"door") or entity.has_c(&"furniture"):
		return true
	if "Items" in selected and entity.has_c(&"item"):
		return true
	if "Blood" in selected and entity.has_c(&"decal") and entity.c(&"decal").blood:
		return true
	return "Floor Objects" in selected and (entity.has_c(&"pipe") or entity.has_c(&"vent") or entity.has_c(&"scrubber"))

static func eligible(user: Entity) -> bool:
	return is_instance_valid(user) and not user.removed and user.has_c(&"health") and not user.c(&"health").dead and not user.c(&"health").missing.has("head") and Organs.has(user.c(&"health"), "brain")

static func transform(user: Entity) -> bool:
	if not eligible(user): return false
	var h: CHealth = user.c(&"health")
	var old_burn: float = h.limb_burn.get("head", 0.0)
	h.brute = maxf(0.0, h.brute - maxf(0.0, h.limb.get("head", 0.0) - old_burn))
	h.burn = maxf(0.0, h.burn - old_burn)
	h.limb.erase("head")
	h.limb_burn.erase("head")
	h.limb_maxed.erase("head")
	h.wounds = h.wounds.filter(func(wound): return wound.get("part", "") != "head")
	h.organs["brain"] = Organs.new_organ("brain")
	h.organs["brain"]["variant"] = "psyker"
	h.eyes_removed = true
	attach(user)
	return true

static func attach(user: Entity) -> void:
	Traits.add_all(user, ["psyker", "antimagic_no_selfblock", "mind_antimagic"], "psyker_brain")
	for power in POWERS: GenePowers.grant_plain(user, power)
	if user.has_c(&"mob"): user.c(&"mob").refresh_doll()

static func detach(user: Entity) -> void:
	Traits.remove_source(user, "psyker_brain")
	Traits.remove_source(user, "psychic_booster")
	for power in POWERS: GenePowers.remove_id(user, power)
	user.remove_meta("echo_options")
	if user.has_c(&"mob"): user.c(&"mob").refresh_doll()

static func can_echo(user: Entity) -> bool:
	return eligible(user) and Traits.has(user, "psyker") and not StatusFx.deaf(user.c(&"health")) and not user.c(&"health").knocked_out()

static func visible(user: Entity, cell: Vector2i) -> bool:
	if maxi(absi(cell.x - user.cell.x), absi(cell.y - user.cell.y)) > 5 or not Game.map.inb(cell): return false
	for point in GenePowers._line(user.cell, cell, 5):
		if point == cell: break
		if Game.map.is_opaque(point): return false
	return true

static func project(user: Entity, target: Entity) -> bool:
	if not is_instance_valid(target) or not target.has_c(&"health") or target.c(&"health").dead or target.c(&"health").has_status("psychic_projection"): return false
	if Traits.has(target, "mind_antimagic") or Traits.has(target, "antimagic"):
		Game.tell(user, "The spell had no effect!", "warn")
		return false
	target.c(&"health").set_status("psychic_projection", 10.0)
	target.set_meta("projection_next", Game.time)
	Emotes.emote(target, "scream")
	return true

static func booster(user: Entity, power: Dictionary) -> void:
	Game.tell(user, "You focus on your trigger fingers...")
	DoAfter.start(user, user, 5.0, func(ok):
		if not ok or not eligible(user) or not Traits.has(user, "psyker") or GenePowers.find(user, "psychic_booster") != power: return
		GenePowers._start_cd(power)
		Traits.add(user, "double_tap", "psychic_booster")
		Genetics.after(10.0, func():
			if is_instance_valid(user) and not user.removed: Traits.remove_source(user, "psychic_booster")))

static func process(user: Entity) -> void:
	var h: CHealth = user.c(&"health")
	if not h.has_status("psychic_projection") or Game.time < user.get_meta("projection_next", 0.0) or h.dead: return
	user.set_meta("projection_next", Game.time + 0.2)
	var inv: CInventory = user.c(&"inv")
	if not inv: return
	for item in inv.hands:
		if item and item.has_c(&"gadget"):
			var gun: CGadget = item.c(&"gadget")
			if not gun.kind in ["gun", "ballistic"]: continue
			gun.cooldown = 0.0
			var mob: CMob = user.c(&"mob")
			var target: Vector2i = user.cell + Defs.DIRS4[mob.dir] * 7 + Vector2i(Game.rng.randi_range(-1, 1), Game.rng.randi_range(-1, 1))
			gun.fire(user, target)
			break

static func wall(user: Entity) -> void:
	var forward: Vector2i = Defs.DIRS4[user.c(&"mob").dir]
	var side := Vector2i(-forward.y, forward.x)
	for offset in [-1, 0, 1]:
		var cell: Vector2i = user.cell + side * offset
		if not Game.map.inb(cell) or Game.map.is_solid_turf(cell): continue
		var barrier := Proto.spawn("psychic_wall", cell)
		barrier.tags["owner"] = user.id
		Genetics.after(10.0, func():
			if is_instance_valid(barrier) and not barrier.removed: barrier.destroy())
