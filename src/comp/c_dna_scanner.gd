class_name CDnaScanner extends Component
## tg /obj/machinery/dna_scannernew (code/game/machinery/dna_scanner.dm): a pod someone
## lies in while the DNA console next to it works on their genes.
##
## Open, it's an empty frame you can step onto; closing the door shuts whoever's standing
## there inside (or drag someone you're pulling in). The console can bolt it: a locked
## scanner can't be opened from inside except by kicking at the door for two minutes,
## and not at all by a primitive monkey. Unlocked, an occupant just walks out.

var state_open := true
var locked := false
var occupant: Entity = null
## tg RefreshParts: from the stock parts (T1 everywhere here)
var damage_coeff := 1.0 # micro laser tier
var precision_coeff := 1.0 # matter bin tier
var scan_level := 1 # scanning module tier
var breakout_time := 120.0
var linked_console: Entity = null
var _msg_cd := 0.0
var _breakout_t := -1.0
var panel_open := false
var parts := {"micro_laser": 1, "matter_bin": 1, "scanning_module": 1}

func key() -> StringName:
	return &"dnascanner"

func setup(p: Dictionary) -> CDnaScanner:
	for kind in parts:
		parts[kind] = clampi(int(p.get("parts", {}).get(kind, 1)), 1, 4)
	refresh_parts()
	return self

func refresh_parts() -> void:
	damage_coeff = float(parts["micro_laser"])
	precision_coeff = float(parts["matter_bin"])
	scan_level = int(parts["scanning_module"])

func on_added() -> void:
	_update_state()

func machine() -> CMachine:
	return e.c(&"machine")

## tg is_operational: powered and not broken
func operational() -> bool:
	var m := machine()
	return not panel_open and (m == null or m.operable())

# ------------------------------------------------------------------ the door
## tg toggle_open
func toggle_open(user: Entity) -> void:
	if panel_open:
		Game.tell(user, "Close the service panel first.", "warn")
		return
	if state_open:
		close_machine()
		return
	if locked:
		Game.tell(user, "The bolts are locked down, securing the door shut.")
		return
	open_machine()

## tg close_machine: shut the door on whoever's in the pod (or the one being put in).
func close_machine(target: Entity = null) -> bool:
	if not state_open or panel_open:
		return false
	if target != null:
		if not is_instance_valid(target) or target.removed or not target.has_c(&"dna") or target.has_meta("inside"):
			return false
		var tm: CMob = target.c(&"mob")
		if tm and tm.pulled_by:
			tm.pulled_by.c(&"mob").stop_pulling()
		target.place(e.cell)
	state_open = false
	occupant = target
	if occupant == null:
		for x in Game.at(e.cell):
			if x != e and x.has_c(&"dna") and x.has_c(&"health") and not x.has_meta("inside"):
				occupant = x
				break
	if occupant:
		_enclose(occupant)
	Sfx.play("machine_door", e.cell, 0.5)
	_update_state()
	# tg: DNA manipulators only care about carbons
	if occupant and occupant.has_c(&"dna") and linked_console and is_instance_valid(linked_console):
		linked_console.c(&"dnaconsole").on_scanner_close()
	return true

## tg open_machine: the occupant tumbles out
func open_machine() -> bool:
	if state_open or locked:
		return false
	state_open = true
	if occupant and is_instance_valid(occupant) and not occupant.removed:
		_release(occupant)
	occupant = null
	_breakout_t = -1.0
	Sfx.play("machine_door", e.cell, 0.5)
	_update_state()
	if linked_console and is_instance_valid(linked_console):
		linked_console.c(&"dnaconsole").on_scanner_open()
	return true

func _enclose(o: Entity) -> void:
	o.set_meta("inside", e.id)
	var m: CMob = o.c(&"mob")
	if m:
		m.stop_pulling()
		if is_instance_valid(m.pulled_by):
			m.pulled_by.c(&"mob").stop_pulling()
		m.moving = false
		o.place(e.cell)
		if m.doll:
			m.doll.visible = false

func _release(o: Entity) -> void:
	o.remove_meta("inside")
	var m: CMob = o.c(&"mob")
	if m and m.doll:
		m.doll.visible = true
		m.refresh_doll()

## tg update_icon_state
func _update_state() -> void:
	var b: CBlocker = e.c(&"blocker")
	if b:
		b.set_state(not state_open, b.air, b.opaque)
	var base := "dna_scanner"
	if not operational():
		e.set_sprite("objects", base + ("_open" if state_open else "") + "_unpowered")
	elif occupant != null:
		e.set_sprite("objects", base + "_occupied")
	else:
		e.set_sprite("objects", base + ("_open" if state_open else ""))

## Once a second (machines tick): the occupant who wandered off, power changes.
func tick(_dt: float) -> void:
	if occupant != null and (not is_instance_valid(occupant) or occupant.removed or occupant.cell != e.cell):
		if is_instance_valid(occupant) and not occupant.removed:
			_release(occupant)
		occupant = null
		if linked_console and is_instance_valid(linked_console):
			linked_console.c(&"dnaconsole").on_scanner_open()
		_update_state()
	_update_state()

# ------------------------------------------------------------------ from inside
## tg relaymove: an occupant trying to walk out
func relaymove(user: Entity) -> void:
	var h: CHealth = user.c(&"health")
	if (h and h.stat() != CHealth.CONSCIOUS) or locked:
		if Game.time >= _msg_cd:
			_msg_cd = Game.time + 5.0
			Game.tell(user, "%s's door won't budge!" % e.the().capitalize(), "warn")
		return
	open_machine()

## tg container_resist_act: the resist key from inside
func container_resist(user: Entity) -> void:
	if occupant != user or DoAfter.busy(user):
		return
	var primitive: bool = Traits.has(user, "primitive") or user.has_c(&"monkeyai")
	if primitive:
		if locked:
			return # your primitive brain can't escape a DNA scanner
	elif not locked:
		open_machine()
		return
	if _breakout_t >= 0.0:
		return
	Game.visible_message(e.cell, "You see %s kicking against the door of %s!" % [user.display_name, e.the()], "warn")
	Game.tell(user, "You lean on the back of %s and start pushing the door open... (this will take about 2 minutes.)" % e.the())
	_breakout_t = breakout_time
	DoAfter.start(user, user, breakout_time, func(ok):
		_breakout_t = -1.0
		if not ok or not is_instance_valid(user) or user.removed or occupant != user or state_open or not locked:
			return
		var h: CHealth = user.c(&"health")
		if h and h.stat() != CHealth.CONSCIOUS:
			return
		locked = false
		Game.visible_message(e.cell, "%s successfully broke out of %s!" % [user.display_name, e.the()], "warn")
		open_machine())

# ------------------------------------------------------------------ hands
func attack_hand(user: Entity) -> bool:
	if occupant == user:
		relaymove(user)
		return true
	# tg interact -> toggle_open
	toggle_open(user)
	return true

func attackby(user: Entity, item: Entity) -> bool:
	var it: CItem = item.c(&"item")
	if it and it.tool == "screwdriver":
		if occupant != null or locked:
			Game.tell(user, "Empty and unlock the scanner before servicing.", "warn")
			return true
		panel_open = not panel_open
		Game.tell(user, "You %s the scanner's service panel." % ("open" if panel_open else "close"))
		return true
	var part: CStockPart = item.c(&"stockpart")
	if part:
		if not panel_open or occupant != null:
			Game.tell(user, "Open the empty scanner's service panel with a screwdriver first.", "warn")
			return true
		if not parts.has(part.kind) or part.tier <= parts[part.kind]:
			Game.tell(user, "The installed part is already as good or better.", "warn")
			return true
		var old := CStockPart.spawn_part(part.kind, parts[part.kind], e.cell)
		parts[part.kind] = part.tier
		item.destroy()
		refresh_parts()
		Game.tell(user, "You install the upgraded part and remove %s." % old.the())
		return true
	return false

func verbs(user: Entity, out: Array) -> void:
	var um: CMob = user.c(&"mob")
	if um and um.pulling and um.pulling.has_c(&"dna") and user.adjacent(e) and state_open:
		var who: Entity = um.pulling
		out.append({"name": "Put %s in %s" % [who.display_name, e.display_name], "cb": func(): put_in(user, who), "priority": 7})
	out.append({"name": "Close door" if state_open else "Open door", "cb": func(): toggle_open(user), "priority": 5})

## tg mouse_drop_receive: a carbon dragged onto the scanner goes in
func can_put_in(user: Entity, target: Entity) -> bool:
	if not is_instance_valid(user) or not is_instance_valid(target) or target.removed:
		return false
	if not state_open or not target.has_c(&"dna") or target.has_meta("inside"):
		return false
	var h: CHealth = user.c(&"health")
	return user.adjacent(e) and user.adjacent(target) and (h == null or h.can_use_hands())

func put_in(user: Entity, target: Entity) -> bool:
	if not can_put_in(user, target):
		return false
	Game.visible_message(e.cell, "%s puts %s into %s." % [user.display_name, target.display_name, e.the()])
	return close_machine(target)

func on_removed() -> void:
	if is_instance_valid(occupant) and not occupant.removed:
		_release(occupant)
	occupant = null
	if is_instance_valid(linked_console) and linked_console.has_c(&"dnaconsole"):
		linked_console.c(&"dnaconsole").set_connected_scanner(null)
	linked_console = null

func examine(user: Entity, lines: Array) -> void:
	if panel_open:
		lines.append("The service panel is open. Use upgraded stock parts on the scanner, then close it with a screwdriver.")
	if user.dist_to(e) <= 1:
		lines.append("[color=#8ad8a8]The status display reads: Radiation pulse accuracy increased by factor [b]%s[/b].\nRadiation pulse damage decreased by factor [b]%s[/b].[/color]" % [str(pow(precision_coeff, 2)), str(pow(damage_coeff, 2))])
	if occupant:
		lines.append("%s is inside." % occupant.display_name)
	if locked:
		lines.append("Its door bolts are down.")

func ai_tags(out: Dictionary) -> void:
	out["dna_scanner"] = true
