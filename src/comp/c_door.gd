class_name CDoor extends Component
## Airlock (tg: /obj/machinery/door/airlock). Bump-opens for crew with access,
## needs power to cycle, can be pried open with a crowbar when unpowered, welded shut,
## and auto-closes. Closed doors block air and (unless glazed) sight.

enum { CLOSED, OPENING, OPEN, CLOSING }
var state := CLOSED
var dept := "generic"
var req_access: Array = []
var glass := true
var welded := false
var anim_t := 0.0
var open_timer := 0.0
var external := false
var denied_flash := 0.0
# tg airlock wires (/datum/wires/airlock): a screwdriver opens the panel; wirecutters cut
# or mend a wire, a multitool pulses it. Which colour does what differs door to door.
var panel_open := false
var wires := {} # colour -> function ("power", "bolts", "open", "shock", "safety", "dud")
var cut := {} # colour -> true
var bolted := false
var shock_t := 0.0 # electrified for this long (INF while the shock wire is cut)
var manual := false # a wooden ship door on hinges and a latch: works without any power
var power_off_t := 0.0 # a pulsed power wire drops power for a while
var broken := false # tg airlock atom_break (25% integrity): the electronics are dead
const WIRE_COLOURS := ["red", "blue", "green", "yellow", "orange", "purple", "pink", "white"]
const WIRE_FUNCS := ["power", "bolts", "open", "shock", "safety", "dud", "dud"]

func key() -> StringName:
	return &"door"

func setup(p: Dictionary) -> CDoor:
	dept = p.get("dept", dept)
	req_access = p.get("access", req_access).duplicate()
	glass = p.get("glass", dept not in ["maint", "ext", "sec"])
	external = dept == "ext"
	manual = p.get("manual", false)
	return self

func on_added() -> void:
	var cols := WIRE_COLOURS.duplicate()
	cols.shuffle()
	for i in WIRE_FUNCS.size():
		wires[cols[i]] = WIRE_FUNCS[i]
	_refresh()

func wire_cut(fn: String) -> bool:
	for c in wires:
		if wires[c] == fn and cut.has(c):
			return true
	return false

func electrified() -> bool:
	return shock_t > 0.0 and powered()

## Cut or mend (wirecutters) or pulse (multitool) one wire.
func wire_action(user: Entity, colour: String, act: String) -> void:
	if not panel_open or not wires.has(colour):
		return
	var fn: String = wires[colour]
	var inv: CInventory = user.c(&"inv")
	var tool: Entity = inv.active_item() if inv else null
	var need := "wirecutters" if act in ["cut", "mend"] else "multitool"
	if tool == null or not tool.has_c(&"item") or tool.c(&"item").tool != need:
		Game.tell(user, "You need %s in your hand." % ("wirecutters" if need == "wirecutters" else "a multitool"), "warn")
		return
	if electrified():
		Interact.shock(user, 20.0)
		return
	Sfx.play("click", e.cell, 0.5)
	match act:
		"cut":
			cut[colour] = true
			Game.visible_message(e.cell, "%s cuts a wire in %s." % [user.display_name, e.the()], "warn")
			match fn:
				"bolts":
					if not bolted:
						_set_bolts(true)
				"shock":
					shock_t = INF
				"power":
					if state == OPEN:
						pass
		"mend":
			cut.erase(colour)
			Game.visible_message(e.cell, "%s mends a wire in %s." % [user.display_name, e.the()])
			if fn == "shock":
				shock_t = 0.0
		"pulse":
			Game.visible_message(e.cell, "%s pulses a wire in %s." % [user.display_name, e.the()], "warn")
			if cut.has(colour):
				return
			match fn:
				"power":
					power_off_t = 30.0
				"bolts":
					if powered() or bolted:
						_set_bolts(not bolted)
				"open":
					if powered() and not bolted and not welded:
						if state == CLOSED:
							open()
						elif state == OPEN:
							close()
				"shock":
					if powered():
						shock_t = maxf(shock_t, 30.0)
				"safety":
					Fx.sparks(e.cell)
	var illegal: bool = not has_access(user)
	Bus.stimulus.emit({"type": "sabotage", "actor": user, "target": e, "cell": e.cell, "loud": 3.0, "illegal": illegal})

func _set_bolts(v: bool) -> void:
	bolted = v
	Sfx.play("ratchet" if v else "click", e.cell, 0.8)
	Game.visible_message(e.cell, "You hear a click from the bottom of %s." % e.the() if v else "%s's bolts rise." % e.display_name.capitalize())
	_refresh()

func is_open() -> bool:
	return state == OPEN

func powered() -> bool:
	if manual:
		return not broken
	if broken or power_off_t > 0.0 or wire_cut("power"):
		return false
	var a := Game.map.area_at(e.cell)
	return a.powered("environ") or a.powered("equip")

func has_access(user: Entity) -> bool:
	if req_access.is_empty():
		return true
	if SecurityRecords.escorting.has(user.id):
		return true # an officer is swiping them through
	# nobody gets locked inside a room they slipped into behind someone (exit is free),
	# except the brig, which is the point of a brig
	var here := Game.map.area_at(user.cell)
	if not here.restricted.is_empty() and here.room_kind != "brig" and not here.name.contains("Brig"):
		var inside := true
		for tag in here.restricted:
			var inv = user.c(&"inv")
			if inv != null and inv.has_access(tag):
				inside = false
		if inside:
			return true
	var inv = user.c(&"inv")
	if inv == null:
		return false
	for tag in req_access:
		if inv.has_access(tag):
			return true
	return false

func bump(user: Entity) -> bool:
	## Returns true if the door is (now) passable for user.
	if state != OPEN:
		Forensics.touch(e, user) # tg door/try_to_activate_door: add_fingerprint
	if state == OPEN:
		open_timer = 6.0
		return true
	if state == OPENING:
		return false
	if welded:
		Game.tell(user, "The %s is welded shut." % e.display_name, "warn")
		return false
	if electrified() and user.has_c(&"health"):
		Interact.shock(user, 25.0)
		return false
	if bolted:
		Game.tell(user, "The %s is bolted shut." % e.display_name, "warn")
		denied_flash = 0.4
		return false
	if not powered():
		Game.tell(user, "The %s doesn't respond. It has no power." % e.display_name, "warn")
		return false
	if not has_access(user):
		denied_flash = 0.6
		Game.tell(user, "Access denied.", "bad")
		if Game.lighting and Game.lighting.player_can_see(e.cell):
			Sfx.play("deny", e.cell)
		return false
	open()
	return false

func open() -> void:
	if state == OPEN or state == OPENING:
		return
	state = OPENING
	anim_t = 0.0
	Sfx.play("door", e.cell)

func close() -> bool:
	if state != OPEN:
		return false
	# don't crush things standing in the doorway
	for other in Game.at(e.cell):
		if other != e and (other.has_c(&"mob") or other.has_c(&"item")):
			open_timer = 2.0
			return false
	state = CLOSING
	anim_t = 0.0
	(e.c(&"blocker") as CBlocker).set_state(true, true, not glass)
	Sfx.play("door", e.cell)
	return true

func process(delta: float) -> void:
	if denied_flash > 0:
		denied_flash -= delta
	if power_off_t > 0.0:
		power_off_t -= delta
	if shock_t > 0.0 and shock_t != INF:
		shock_t -= delta
	match state:
		OPENING:
			anim_t += delta / 0.35
			if anim_t >= 1.0:
				state = OPEN
				open_timer = 6.0
				(e.c(&"blocker") as CBlocker).set_state(false, false, false)
			_refresh()
		CLOSING:
			anim_t += delta / 0.35
			if anim_t >= 1.0:
				state = CLOSED
			_refresh()
		OPEN:
			open_timer -= delta
			if open_timer <= 0 and powered() and not bolted:
				close()

func _refresh() -> void:
	var f := 0
	match state:
		CLOSED: f = 0
		OPEN: f = 3
		OPENING: f = clampi(int(anim_t * 3.0) + 1, 1, 3)
		CLOSING: f = clampi(3 - int(anim_t * 3.0), 0, 2)
	e.set_sprite("objects", "airlock_%s_%d" % [dept, f])

func attack_hand(user: Entity) -> bool:
	if state == CLOSED:
		bump(user)
		return true
	if state == OPEN:
		if powered() and has_access(user):
			close()
		return true
	return false

func attackby(user: Entity, item: Entity) -> bool:
	var it: CItem = item.c(&"item")
	if it == null:
		return false
	if it.tool == "screwdriver":
		panel_open = not panel_open
		Sfx.play("click", e.cell, 0.5)
		Game.visible_message(e.cell, "%s %s the service panel on %s." % [user.display_name, "opens" if panel_open else "closes", e.the()])
		if panel_open:
			Bus.ui_open_window.emit("airlock_wires", e)
		return true
	if panel_open and it.tool in ["wirecutters", "multitool"]:
		Bus.ui_open_window.emit("airlock_wires", e)
		return true
	if it.tool == "crowbar":
		if state == CLOSED and bolted:
			Game.tell(user, "The bolts are down; it won't budge.", "warn")
			return true
		if state == CLOSED:
			if welded:
				Game.tell(user, "It's welded shut.", "warn")
				return true
			if powered() and has_access(user):
				open()
				return true
			var forced := powered()
			var dur := 6.0 if forced else 2.5
			Game.visible_message(e.cell, "%s starts prying open %s." % [user.display_name, e.the()])
			DoAfter.start(user, e, dur, func(ok):
				if ok and state == CLOSED:
					open()
					if forced or not has_access(user):
						Bus.stimulus.emit({"type": "break_in", "actor": user, "target": e, "cell": e.cell, "loud": 6.0, "illegal": not has_access(user) and not Interact.on_emergency_duty(user)})
			)
			return true
		if state == OPEN and not powered():
			close()
			return true
	if it.tool == "welder":
		var wd = item.c(&"welder")
		if wd and wd.lit and state == CLOSED:
			Interact.weld_flash(user)
			DoAfter.start(user, e, 4.0, func(ok):
				if ok:
					welded = not welded
					Game.visible_message(e.cell, "%s %s %s." % [user.display_name, "welds shut" if welded else "unwelds", e.the()])
			)
			return true
	return false

func examine(_user: Entity, lines: Array) -> void:
	if bolted:
		lines.append("[color=#ff5a4a]Its bolt lights are on: it's bolted down.[/color]")
	if panel_open:
		lines.append("Its service panel is open.")
	if welded:
		lines.append("[color=#ffb84a]It has been welded shut.[/color]")
	if not powered():
		lines.append("Its status lights are dark.")
	if not req_access.is_empty():
		lines.append("Access: %s" % ", ".join(req_access))

func verbs(user: Entity, out: Array) -> void:
	if user.adjacent(e):
		if state == CLOSED:
			out.append({"name": "Open", "cb": attack_hand.bind(user), "priority": 5})
		elif state == OPEN:
			out.append({"name": "Close", "cb": attack_hand.bind(user), "priority": 5})

func ai_tags(out: Dictionary) -> void:
	out["door"] = true
