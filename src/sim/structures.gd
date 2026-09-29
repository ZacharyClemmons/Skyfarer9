class_name Structures extends RefCounted
## Tile structures taking damage: windows, grilles and girders. A port of tg's integrity
## (code/game/atom/atom_defense.dm take_damage / run_atom_armor) with the window and grille
## specifics from code/game/objects/structures/window.dm and grille.dm:
##   - armour by damage flag ("melee", "bullet", "laser", "energy", "bomb", "fire"); a flag of
##     "" means unarmoured damage (tg damage_flag 0, e.g. atmos heat)
##   - reinforced windows deflect melee hits under 11 damage outright (damage_deflection)
##   - windows show crack overlays at 75/50/25% integrity (window update_overlays)
##   - grilles break at 40% (integrity_failure): they bend out of the way, drop a rod,
##     and hold 20 more before falling apart

const DAMAGE_PRECISION := 0.1

static func max_hp(s: int) -> float:
	return Defs.STRUCTS[s]["hp"]

static func armor(s: int, flag: String) -> float:
	return float(Defs.STRUCTS[s]["armor"].get(flag, 0))

## tg PENETRATE_ARMOUR
static func penetrate(arm: float, ap: float) -> float:
	if ap >= 100.0:
		return 0.0
	return 100.0 * (arm - ap) / (100.0 - ap)

## tg run_atom_armor: what's left of a hit after deflection and armour.
static func run_armor(s: int, amount: float, damtype: String, flag: String, ap := 0.0) -> float:
	return reduce(amount, damtype, flag, Defs.STRUCTS[s]["armor"], Defs.STRUCTS[s]["deflect"], ap)

## run_atom_armor for any armour table (structures, doors, lockers, machines).
static func reduce(amount: float, damtype: String, flag: String, arm_table: Dictionary, deflect := 0.0, ap := 0.0) -> float:
	if flag == "melee" and amount < deflect:
		return 0.0
	if damtype != "brute" and damtype != "burn":
		return 0.0
	var arm := float(arm_table.get(flag, 0)) if flag != "" else 0.0
	if arm != 0.0:
		arm = clampf(penetrate(arm, ap), minf(arm, 0.0), 100.0)
	return snappedf(amount * (100.0 - arm) * 0.01, DAMAGE_PRECISION)

## tg window update_overlays: "damage75", "damage50", "damage25", or 0 for a clean pane.
static func crack_stage(hp: float, full: float) -> int:
	if full <= 0.0:
		return 0
	var ratio := int(ceil(hp / full * 4.0)) * 25
	return ratio if ratio <= 75 else 0

static func crack_at(cell: Vector2i) -> int:
	var map := Game.map
	var i := map.idx(cell)
	var s: int = map.structure[i]
	if not Defs.is_window(s):
		return 0
	return crack_stage(map.struct_hp[i], max_hp(s))

## tg take_damage for a tile structure. Plays the hit sound off the raw hit (tg plays it before
## armour, so a deflected blow still clinks), applies armour, cracks/breaks the structure.
## `from` is where the blow came from (for which way the glass flies). Returns damage dealt.
static func take_damage(cell: Vector2i, amount: float, damtype := "brute", flag := "", cause: Entity = null, ap := 0.0, sound := true, from := Vector2i(-9999, -9999)) -> float:
	var map := Game.map
	if not map.inb(cell):
		return 0.0
	var i := map.idx(cell)
	var s: int = map.structure[i]
	if s == Defs.S_NONE:
		return 0.0
	if sound:
		play_attack_sound(cell, s, amount, damtype)
	var dealt := run_armor(s, amount, damtype, flag, ap)
	if dealt < DAMAGE_PRECISION:
		return 0.0
	var before: float = map.struct_hp[i]
	var full := max_hp(s)
	var hp := maxf(0.0, before - dealt)
	map.struct_hp[i] = hp
	var push := Vector2.ZERO
	if from.x > -9999:
		push = Vector2(cell - from)
	if Defs.is_window(s):
		if hp <= 0.0:
			break_window(cell, cause, push)
			return dealt
		Fx.pane_flash(cell, clampf(dealt / 20.0, 0.25, 0.8))
		Fx.glass_chips(cell, -push, clampi(int(dealt / 4.0) + 1, 1, 6))
		if crack_stage(hp, full) != crack_stage(before, full):
			Bus.tile_changed.emit(cell) # redraw with the new cracks
	elif s == Defs.S_GRILLE:
		Fx.glass_chips(cell, -push, 2, Color(0.6, 0.62, 0.68))
		if hp <= 0.0:
			break_grille(cell, cause)
		elif hp <= full * Defs.GRILLE_FAILURE and before > full * Defs.GRILLE_FAILURE:
			bend_grille(cell, cause)
		elif hp <= full * 0.5 and before > full * 0.5:
			Bus.tile_changed.emit(cell) # redraw it bent
	elif s == Defs.S_GRILLE_BROKEN:
		if hp <= 0.0:
			break_grille(cell, cause)
	elif s == Defs.S_GIRDER:
		if hp <= 0.0:
			map.set_structure(cell, Defs.S_NONE)
			Proto.spawn("sheet_metal", cell, {"comps": {"stack": {"amount": 2}}})
			Sfx.play("wall_hit", cell)
	return dealt

## tg play_attack_sound: window glasshit / grille grillehit on a real hit, a tap when the
## blow has no force, the welder hiss for burns.
static func play_attack_sound(cell: Vector2i, s: int, amount: float, damtype: String) -> void:
	if damtype == "burn":
		Sfx.play("welder", cell, 1.0)
		return
	if damtype != "brute":
		return
	if amount <= 0.0:
		Sfx.play("wall_tap", cell, 0.8)
	elif Defs.is_window(s):
		Sfx.play("glass_hit", cell, 1.3)
	elif Defs.is_grille(s):
		Sfx.play("grille_hit", cell, 1.3)
	else:
		Sfx.play("wall_hit", cell, 1.1)

## tg window atom_deconstruct(disassembled = FALSE): the pane shatters. Two shards (it's a
## full-tile window), a scatter of glass debris, and the rods out of a reinforced pane; the
## grille it sat on stays. `push` is the direction of the blow that broke it.
static func break_window(cell: Vector2i, cause: Entity, push := Vector2.ZERO) -> void:
	var map := Game.map
	var s: int = map.structure[map.idx(cell)]
	map.set_structure(cell, Defs.S_GRILLE)
	var dir := push.normalized() if push != Vector2.ZERO else Vector2.ZERO
	for k in 2:
		var sh := Proto.spawn("glass_shard", cell)
		_scatter(sh, cell, dir)
	if s == Defs.S_RWINDOW:
		var rods := Proto.spawn("rods", cell, {"comps": {"stack": {"amount": 2}}})
		_scatter(rods, cell, dir)
	_debris(cell)
	if dir != Vector2.ZERO:
		# the blow drives glass through to the far side too
		var past := cell + Vector2i(signi(roundi(dir.x)), signi(roundi(dir.y)))
		if map.inb(past) and not map.blocks_move_static(past):
			_debris(past)
	Sfx.play("shatter", cell, 1.2)
	Fx.glass_shatter(cell, dir * 1.0)
	if Game.view and Game.player and Game.player.cell.distance_to(cell) < 6.0:
		Game.view.shake(2.0)
	if Game.atmos:
		Game.atmos.wake(cell)
	Bus.stimulus.emit({"type": "window_broken", "actor": cause, "cell": cell, "loud": 10.0, "illegal": cause != null})
	Bus.chronicle.emit("A window shattered in %s." % map.area_at(cell).name, 1)

## tg grille atom_break at 40%: bent out of the way, one rod falls off.
static func bend_grille(cell: Vector2i, _cause: Entity) -> void:
	var map := Game.map
	map.set_structure(cell, Defs.S_GRILLE_BROKEN) # 20 hp left, like tg's atom_integrity = 20
	var rod := Proto.spawn("rods", cell, {"comps": {"stack": {"amount": 1}}})
	_scatter(rod, cell, Vector2.ZERO)
	Game.visible_message(cell, "The grille bends apart!", "warn")
	Sfx.play("grille_hit", cell, 1.4)
	if Game.atmos:
		Game.atmos.wake(cell)

## tg grille atom_deconstruct: it falls apart into its rods (2 whole, 1 if it was broken).
static func break_grille(cell: Vector2i, _cause: Entity = null) -> void:
	var map := Game.map
	var was_broken: bool = map.structure[map.idx(cell)] == Defs.S_GRILLE_BROKEN
	map.set_structure(cell, Defs.S_NONE)
	var rods := Proto.spawn("rods", cell, {"comps": {"stack": {"amount": 1 if was_broken else 2}}})
	_scatter(rods, cell, Vector2.ZERO)
	Sfx.play("grille_hit", cell, 1.0)
	if Game.atmos:
		Game.atmos.wake(cell)

## Debris pops off the break and lands a little way off, rather than appearing in a heap.
static func _scatter(item: Entity, cell: Vector2i, dir: Vector2) -> void:
	if item == null:
		return
	var off := Vector2(Game.rng.randi_range(-8, 8), Game.rng.randi_range(-6, 6)) + dir * 6.0
	off = off.clamp(Vector2(-12, -10), Vector2(12, 10))
	item.set_pixel_offset(off)
	if item.spr:
		var land := item.spr.position
		item.spr.position = land - off + Vector2(0, -6)
		var tw := item.create_tween()
		tw.tween_property(item.spr, "position", land, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## tg /obj/effect/decal/cleanable/glass: glittering bits on the floor (one per tile).
static func _debris(cell: Vector2i) -> void:
	for d in Game.at(cell):
		if d.proto == "decal_glass":
			return
	Proto.spawn("decal_glass", cell, {"spr": "glass_debris_%d" % (Game.rng.randi() % 3)})

## tg window welder_act: 4 seconds with a lit welder brings a damaged pane back to full.
static func weld_repair(user: Entity, cell: Vector2i) -> void:
	var map := Game.map
	var i := map.idx(cell)
	var s: int = map.structure[i]
	if map.struct_hp[i] >= max_hp(s):
		Game.tell(user, "The %s is already in good condition!" % Defs.STRUCTS[s]["name"], "warn")
		return
	Game.tell(user, "You begin repairing the %s..." % Defs.STRUCTS[s]["name"])
	Sfx.play("welder", cell)
	DoAfter.start(user, null, 4.0 * Skills.speed(user, "construction"), func(ok):
		if ok and map.structure[i] == s:
			map.struct_hp[i] = max_hp(s)
			Bus.tile_changed.emit(cell)
			Sfx.play("welder", cell)
			Skills.add_xp(user, "construction", 6.0)
			Game.tell(user, "You repair the %s." % Defs.STRUCTS[s]["name"], "good")
	)

## tg obj/ex_act for a tile structure: devastation destroys it, heavy is 100-250 and light
## 10-90 bomb damage (reinforced windows have bomb 25, grilles 10).
static func ex_act(cell: Vector2i, severity: int, cause: Entity) -> void:
	var map := Game.map
	var s: int = map.structure[map.idx(cell)]
	if s == Defs.S_NONE:
		return
	match severity:
		3:
			if Defs.is_window(s):
				break_window(cell, cause)
				s = map.structure[map.idx(cell)]
			if Defs.is_grille(s):
				break_grille(cell, cause)
			elif s == Defs.S_GIRDER:
				take_damage(cell, 9999.0, "brute", "", cause, 0.0, false)
		2:
			take_damage(cell, Game.rng.randf_range(100.0, 250.0), "brute", "bomb", cause, 0.0, false)
		1:
			take_damage(cell, Game.rng.randf_range(10.0, 90.0), "brute", "bomb", cause, 0.0, false)
