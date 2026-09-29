class_name Explosion extends RefCounted
## Explosions after tg's explosion() with devastation / heavy / light impact ranges.
## Tears walls down to girders or plating, shatters windows, severs cables and pipes,
## throws people and ignites things.

static func explode(center: Vector2i, dev: int, heavy: int, light: int, cause: Entity) -> void:
	var map := Game.map
	var r := maxi(light, 1)
	Fx.explosion(center, 1.0 + heavy * 0.35)
	Sfx.play("explosion", center, 8.0)
	Bus.stimulus.emit({"type": "explosion", "actor": cause, "cell": center, "loud": 30.0, "illegal": cause != null})
	Bus.chronicle.emit("An explosion rocked %s." % map.area_at(center).name, 3)
	for y in range(center.y - r, center.y + r + 1):
		for x in range(center.x - r, center.x + r + 1):
			var c := Vector2i(x, y)
			if not map.inb(c):
				continue
			var d := Vector2(c - center).length()
			if d > r + 0.5:
				continue
			var sev := 3 if d <= dev else (2 if d <= heavy else 1)
			_hit_tile(c, sev, cause)
			if sev >= 2 and Game.rng.randf() < 0.5:
				Fx.explosion(c, 0.5)
	if Game.atmos:
		Game.atmos.add_heat(map.idx(center), 800000.0 * (heavy + 1))
		if heavy >= 1:
			Game.atmos.ignite(center, cause)

static func _hit_tile(c: Vector2i, sev: int, cause: Entity) -> void:
	var map := Game.map
	var t := map.get_turf(c)
	var fl: int = Defs.TURFS[t]["flags"]
	if fl & Defs.F_WALL:
		if sev == 3 or (sev == 2 and t == Defs.T_WALL and Game.rng.randf() < 0.6):
			map.set_turf(c, Defs.T_PLATING)
			map.set_structure(c, Defs.S_GIRDER if Game.rng.randf() < 0.5 else Defs.S_NONE)
			Interact.spawn_debris(c, 2)
	elif fl & Defs.F_ROCK:
		if sev >= 2:
			map.set_turf(c, Defs.T_GRAVEL)
	else:
		if sev >= 2 and (fl & Defs.F_FLOOR):
			map.set_turf(c, Defs.T_PLATING)
		# tg obj/ex_act: devastation destroys windows and grilles, heavy/light are bomb damage
		Structures.ex_act(c, sev, cause)
		if sev >= 2 and map.cable[map.idx(c)] == 1 and Game.rng.randf() < 0.6:
			map.cable[map.idx(c)] = 2
			Bus.cables_changed.emit()
		for layer in StationMap.PIPE_LAYER_COUNT:
			if map.pipe_mask(layer, c) != 0 and Game.rng.randf() < 0.3 * sev:
				map.damage_pipe(layer, c, 30.0 * sev)
	for e in Game.at(c).duplicate():
		if e.removed:
			continue
		var dmg = [0.0, 15.0, 40.0, 90.0][sev]
		if e.has_c(&"health"):
			var eh: CHealth = e.c(&"health")
			if e.has_c(&"mob"):
				Explosion.human_ex_act(eh, sev, cause)
				continue
			e.take_damage(dmg * Game.rng.randf_range(0.7, 1.2), "brute", cause)
			e.take_damage(dmg * 0.4, "burn", cause)
			eh.knockdown(2.0 + sev)
		elif e.has_c(&"integrity") or e.has_c(&"machine"):
			# tg obj/ex_act: devastation deletes it, heavy is 100-250 and light 10-90
			# bomb damage through its armour
			if sev == 3:
				Interact.spawn_debris(c, 1)
				e.destroy()
			else:
				e.take_damage(Game.rng.randf_range(100.0, 250.0) if sev == 2 else Game.rng.randf_range(10.0, 90.0), "brute", cause, "bomb")
		elif e.has_c(&"light") or e.has_c(&"flammable"):
			e.take_damage(dmg, "brute", cause, "bomb")
	if Game.atmos:
		Game.atmos.wake(c)


## tg /mob/living/carbon/human/ex_act (no bomb armour in this game): devastation gibs;
## heavy is 60 brute + 60 burn, a 2 ds knockout and a 20 s knockdown; light is 30 brute
## and a 16 s knockdown. Then limbs come off: 30% each for up to 2 (light), 40% for up
## to 3 (heavy).
static func human_ex_act(h: CHealth, sev: int, cause: Entity) -> void:
	if sev >= 3:
		Body.gib(h)
		return
	var brute_loss := 60.0 if sev == 2 else 30.0
	var burn_loss := 60.0 if sev == 2 else 0.0
	if sev == 2:
		h.knock_out(0.2)
		h.knockdown(20.0)
	else:
		h.knockdown(16.0)
	h.take_overall_damage(brute_loss, burn_loss, cause)
	var max_limb_loss := 3 if sev == 2 else 2
	var probability := 40.0 if sev == 2 else 30.0
	for part in Body.LIMBS:
		if h.missing.has(part) or not Body.prob(probability):
			continue
		# tg: receive_damage(INFINITY) (capped at the limb's max), then dismember()
		h.hurt_zone(Body.PARTS[part]["zones"][0], Body.PARTS[part]["max"], "brute", cause, "", Body.CANT_WOUND)
		Body.dismember(h, part, "blunt")
		max_limb_loss -= 1
		if max_limb_loss <= 0:
			break
