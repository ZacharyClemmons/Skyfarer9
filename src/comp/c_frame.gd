class_name CFrame extends Component
## tg /obj/structure/frame (machine and computer frames). Build steps:
##   0 loose frame   wrench: bolt it down   welder: take it apart (5 metal)
##   1 anchored      5 cable: wire it       wrench: unbolt
##   2 wired         circuit board: slot it in   wirecutters: pull the cable
##   3 board in      screwdriver: finish the machine   crowbar: pop the board out

var kind := "machine"
var state := 0
var board: Entity = null

func key() -> StringName:
	return &"frame"

func setup(p: Dictionary) -> CFrame:
	kind = p.get("kind", kind)
	return self

func on_added() -> void:
	_refresh()

func _refresh() -> void:
	e.tags["anchored"] = state >= 1
	e.set_sprite("objects", "%s_frame_%d" % [kind, mini(state, 3)])

func use(user: Entity, item: Entity) -> bool:
	var it: CItem = item.c(&"item")
	var tool := it.tool if it else ""
	match state:
		0:
			if tool == "wrench":
				_step(user, 2.0, "bolts down", func(): state = 1)
				return true
			if tool == "welder" and item.has_c(&"welder") and item.c(&"welder").lit:
				_step(user, 3.0, "cuts apart", func():
					Proto.spawn("sheet_metal", e.cell, {"comps": {"stack": {"amount": 5}}})
					e.destroy())
				return true
		1:
			if tool == "wrench":
				_step(user, 2.0, "unbolts", func(): state = 0)
				return true
			var st: CStack = item.c(&"stack")
			if st and st.material == "cable":
				if st.amount < 5:
					Game.tell(user, "You need five lengths of cable to wire the frame.", "warn")
					return true
				_step(user, 2.0, "wires", func():
					if st.use(5):
						state = 2)
				return true
		2:
			if tool == "wirecutters":
				_step(user, 1.0, "cuts the wires out of", func():
					Proto.spawn("cable_coil", e.cell, {"comps": {"stack": {"amount": 5}}})
					state = 1)
				return true
			if item.proto == "circuit_board":
				var target: String = item.tags.get("board_for", "")
				if target == "" or Construction.DECONSTRUCTIBLE.get(target, "") != kind:
					Game.tell(user, "That board doesn't fit a %s frame." % kind, "warn")
					return true
				Interact.detach(item)
				item.holder = e
				item.visible = false
				board = item
				state = 3
				Sfx.play("click", e.cell, 0.6)
				Game.visible_message(e.cell, "%s slots %s into %s." % [user.display_name, item.the(), e.the()])
				_refresh()
				return true
		3:
			if tool == "crowbar" and board:
				var b := board
				board = null
				b.holder = null
				b.visible = true
				Game.drop_to_map(b, e.cell)
				b.place(e.cell)
				state = 2
				Game.visible_message(e.cell, "%s pries the circuit board out of %s." % [user.display_name, e.the()])
				_refresh()
				return true
			if tool == "screwdriver" and board:
				_step(user, 2.0, "finishes", func(): _complete(user))
				return true
	return false

func _step(user: Entity, t: float, verb: String, cb: Callable) -> void:
	DoAfter.start(user, e, t * Skills.speed(user, "construction"), func(ok):
		if ok and is_instance_valid(e) and not e.removed:
			cb.call()
			Sfx.play("ratchet", e.cell, 0.6)
			Game.visible_message(e.cell, "%s %s %s." % [user.display_name, verb, e.the()])
			Skills.add_xp(user, "construction", 3.0)
			if not e.removed:
				_refresh())

func _complete(_user: Entity) -> void:
	var proto: String = board.tags.get("board_for", "")
	var ov: Dictionary = board.tags.get("board_ov", {}).duplicate(true)
	var c := e.cell
	board.destroy()
	board = null
	var m := Proto.spawn(proto, c, ov)
	if m.has_c(&"light") and Game.lighting:
		Game.lighting.register(m.c(&"light"))
	e.destroy()

func examine(_user: Entity, lines: Array) -> void:
	lines.append(["It's a loose frame. [color=#8a93a3]Wrench it to the floor.[/color]",
		"It's bolted down. [color=#8a93a3]Wire it with five lengths of cable.[/color]",
		"It's wired. [color=#8a93a3]Slot in a circuit board.[/color]",
		"It has a circuit board in it. [color=#8a93a3]Screw it together to finish.[/color]"][state])
