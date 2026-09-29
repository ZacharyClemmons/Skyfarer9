class_name CFirelock extends Component
## tg firelock (/obj/machinery/door/firedoor). Sits open under doorways and at hallway
## joins, and drops shut when a tile beside it is on fire (FIRE_MINIMUM_TEMPERATURE_TO_EXIST),
## freezing (BODYTEMP_COLD_DAMAGE_LIMIT), or venting into a breach, or when someone pulls
## a fire alarm in one of its areas. It lifts again once every tile around it is safe.
##   hand:      knock on it (combat mode: bash it)
##   crowbar:   pry it open and hold it open while you stand beside it (tg try_to_crowbar);
##              on an open one, pull it shut
##   welder:    weld / unweld it
##   screwdriver + wrench on a welded one: unlock the floor bolts, then take it apart

enum { OPEN, CLOSING, CLOSED, OPENING }
var state := OPEN
var anim_t := 0.0
var alarm := "" # "", "hot", "cold", "pressure", "generic"
var welded := false
var boltslocked := true
var held_by: Entity = null
var _retry_close := false

const FRAMES := 3
const ANIM := 0.5

func key() -> StringName:
	return &"firelock"

func on_added() -> void:
	_refresh()

func is_closed() -> bool:
	return state == CLOSED or state == CLOSING

func areas() -> Array:
	var out := []
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = e.cell + d
		if not Game.map.inb(c) or Game.map.is_solid_turf(c):
			continue
		var a: Area = Game.map.area_at(c)
		if a and not out.has(a):
			out.append(a)
	return out

## tg check_atmos on each turf we share air with.
func _check_turfs() -> String:
	if Game.atmos == null:
		return ""
	var map := Game.map
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = e.cell + d
		if not map.inb(c) or map.is_solid_turf(c) or map.is_outdoor(c) or map.blocks_air(c):
			continue
		var i := map.idx(c)
		var t: float = Game.atmos.temp[i]
		if t >= Defs.FIRE_MIN_TEMP_TO_EXIST:
			return "hot"
		if Game.atmos.pressure(i) < Defs.HAZARD_LOW_PRESSURE:
			return "pressure"
		if t <= Defs.BODYTEMP_COLD_DAMAGE:
			return "cold"
	return ""

func tick(_dt: float) -> void:
	var was := alarm
	alarm = _check_turfs()
	if alarm == "":
		for a in areas():
			if a.fire_pulled or a.fire_alarm:
				alarm = "generic"
				break
	if held_by != null:
		if not is_instance_valid(held_by) or held_by.removed or not held_by.adjacent(e) or (held_by.has_c(&"mob") and held_by.c(&"mob").is_lying()):
			if is_instance_valid(held_by) and not held_by.removed:
				Game.visible_message(e.cell, "%s lets go of %s." % [held_by.display_name, e.the()])
			held_by = null
	if welded or not _powered():
		if was != alarm:
			_refresh()
		return
	if alarm != "" and state == OPEN and held_by == null:
		close()
	elif alarm == "" and state == CLOSED:
		open()
	elif _retry_close and state == OPEN and alarm != "" and held_by == null:
		close()
	if was != alarm:
		_refresh()

func _powered() -> bool:
	var a: Area = Game.map.area_at(e.cell)
	return a == null or a.powered("environ") or a.powered("equip")

func close() -> void:
	if state != OPEN:
		return
	# tg firelocks close on anything but a standing person; they wait for people to move
	for o in Game.at(e.cell):
		if o != e and o.has_c(&"mob") and not o.c(&"mob").is_lying():
			_retry_close = true
			return
	_retry_close = false
	state = CLOSING
	anim_t = 0.0
	(e.c(&"blocker") as CBlocker).set_state(true, true, true)
	Sfx.play("door", e.cell, 0.9)
	_refresh()

func open() -> void:
	if state != CLOSED:
		return
	state = OPENING
	anim_t = 0.0
	Sfx.play("door", e.cell, 0.9)
	_refresh()

func process(delta: float) -> void:
	if state == CLOSING or state == OPENING:
		anim_t += delta / ANIM
		if anim_t >= 1.0:
			if state == OPENING:
				state = OPEN
				(e.c(&"blocker") as CBlocker).set_state(false, false, false)
			else:
				state = CLOSED
		_refresh()

func _refresh() -> void:
	var f := 0 # 0 = open (shutter up) .. FRAMES = shut
	match state:
		OPEN: f = 0
		CLOSED: f = FRAMES
		CLOSING: f = clampi(int(anim_t * FRAMES), 0, FRAMES)
		OPENING: f = clampi(FRAMES - int(anim_t * FRAMES), 0, FRAMES)
	var lit := alarm != "" and f == FRAMES
	e.set_sprite("objects", "firelock_%d%s" % [f, ("_" + ("cold" if alarm == "cold" else "hot")) if lit else ""])
	e.z_index = 1 if f > 0 else 0

func attack_hand(user: Entity) -> bool:
	if state != CLOSED:
		return false
	if not Combat.ready_to_attack(user):
		return true
	Combat._set_cooldown(user, null)
	var mob: CMob = user.c(&"mob")
	if mob and mob.combat:
		Game.visible_message(e.cell, "%s bashes %s!" % [user.display_name, e.the()], "warn")
		Sfx.play("wall_hit", e.cell, 1.2)
		mob.lunge(e.cell)
	else:
		Game.visible_message(e.cell, "%s knocks on %s." % [user.display_name, e.the()])
		Sfx.play("wall_tap", e.cell, 1.2)
	return true

func attackby(user: Entity, item: Entity) -> bool:
	var it: CItem = item.c(&"item")
	if it == null:
		return false
	match it.tool:
		"crowbar":
			if welded:
				Game.tell(user, "%s is welded shut; it refuses to budge!" % e.the().capitalize(), "warn")
				return true
			if state == CLOSED:
				Game.visible_message(e.cell, "%s pries open %s and holds it open." % [user.display_name, e.the()])
				held_by = user
				state = OPENING
				anim_t = 0.0
				Sfx.play("door", e.cell, 0.9)
				_refresh()
				Bus.stimulus.emit({"type": "break_in", "actor": user, "target": e, "cell": e.cell, "loud": 3.0, "illegal": false})
			elif state == OPEN:
				held_by = null
				Game.visible_message(e.cell, "%s pulls %s shut." % [user.display_name, e.the()])
				close()
			return true
		"welder":
			var wd = item.c(&"welder")
			if wd == null or not wd.lit or state != CLOSED:
				return false
			Interact.weld_flash(user)
			Game.visible_message(e.cell, "%s starts %s %s." % [user.display_name, "unwelding" if welded else "welding", e.the()])
			DoAfter.start(user, e, 4.0, func(ok):
				if ok and state == CLOSED and wd.use_fuel(1.0):
					welded = not welded
					Game.visible_message(e.cell, "%s %s %s." % [user.display_name, "welds" if welded else "unwelds", e.the()], "warn")
					_refresh()
			)
			return true
		"screwdriver":
			if not welded:
				return false
			boltslocked = not boltslocked
			Sfx.play("click", e.cell, 0.5)
			Game.visible_message(e.cell, "%s %s %s's floor bolts." % [user.display_name, "unlocks" if not boltslocked else "locks", e.the()])
			return true
		"wrench":
			if not welded:
				return false
			if boltslocked:
				Game.tell(user, "There are screws locking the bolts in place!", "warn")
				return true
			Game.visible_message(e.cell, "%s starts undoing %s's bolts..." % [user.display_name, e.the()])
			DoAfter.start(user, e, 5.0, func(ok):
				if ok and is_instance_valid(e) and not e.removed:
					Sfx.play("ratchet", e.cell)
					Game.visible_message(e.cell, "%s unfastens %s's bolts." % [user.display_name, e.the()])
					Proto.spawn("sheet_metal", e.cell, {"comps": {"stack": {"amount": 3}}})
					e.destroy()
			)
			return true
	return false

func examine(_user: Entity, lines: Array) -> void:
	match alarm:
		"hot": lines.append("[color=#ff5a4a]Its warning lights flash red: there's a fire on the other side.[/color]")
		"cold": lines.append("[color=#5ad0ff]Its warning lights flash blue: it's freezing on the other side.[/color]")
		"pressure": lines.append("[color=#ff5a4a]Its warning lights flash: the air on the other side is thin.[/color]")
		"generic": lines.append("[color=#ffb84a]A fire alarm has it locked down.[/color]")
	if welded:
		lines.append("[color=#ffb84a]It has been welded shut.[/color]%s" % (" The floor bolts are unlocked." if not boltslocked else ""))
	elif state == CLOSED:
		lines.append("[color=#8a93a3]A crowbar could pry it open.[/color]")

func verbs(user: Entity, out: Array) -> void:
	if state == CLOSED and user.adjacent(e):
		out.append({"name": "Knock", "cb": attack_hand.bind(user), "priority": 3})

func ai_tags(out: Dictionary) -> void:
	out["firelock"] = true
	if is_closed():
		out["firelock_closed"] = true
