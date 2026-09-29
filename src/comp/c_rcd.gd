class_name CRCD extends Component
## tg Rapid Construction Device (code/game/objects/items/rcd/RCD.dm). Z opens its radial;
## click an adjacent tile to build or take apart. Runs on matter (160 max): feed it metal
## sheets (4 each), glass (2) or a compressed matter cartridge (160).
##   floor/wall   plating or snow -> floor (1); floor -> wall (16, 2 s)
##   airlock      on a floor (16, 5 s)
##   window       a grille and a reinforced window (6, 2.5 s)
##   frame        a machine frame (20, 2 s) / computer frame (20, 2 s)
##   deconstruct  wall -> floor (26, 4 s), floor -> plating (16, 2 s), airlock (32, 5 s),
##                window/grille (8, 1 s), girder (8, 1.3 s)

var matter := 160.0
var max_matter := 160.0
var mode := "floorwall"
const MODES := ["floorwall", "airlock", "window", "machine_frame", "computer_frame", "deconstruct"]
const MODE_NAMES := {"floorwall": "Floors and walls", "airlock": "Bulkhead hatch", "window": "Reinforced window", "machine_frame": "Machine frame", "computer_frame": "Computer frame", "deconstruct": "Deconstruct"}
const REFILL := {"sheet_metal": 4.0, "sheet_glass": 2.0, "sheet_rglass": 6.0, "rcd_ammo": 160.0, "floor_tile": 1.0}

func key() -> StringName:
	return &"rcd"

func setup(p: Dictionary) -> CRCD:
	matter = p.get("matter", matter)
	return self

func attack_self(user: Entity) -> bool:
	Bus.ui_open_window.emit("rcd", e)
	return true

func set_mode(user: Entity, m: String) -> void:
	mode = m
	Sfx.play("click", user.cell, 0.5)
	Game.tell(user, "You change %s's mode to '%s'." % [e.the(), MODE_NAMES[m]])

## Feeding it matter (the RCD in hand, clicked on a stack... or the stack on the RCD)
func attackby(user: Entity, item: Entity) -> bool:
	return refill(user, item)

func refill(user: Entity, item: Entity) -> bool:
	if not REFILL.has(item.proto):
		return false
	var per: float = REFILL[item.proto]
	var st: CStack = item.c(&"stack")
	var want := int(ceilf((max_matter - matter) / per))
	if want <= 0:
		Game.tell(user, "%s can't hold any more matter." % e.the().capitalize(), "warn")
		return true
	var n := mini(want, st.amount if st else 1)
	matter = minf(max_matter, matter + n * per)
	if st:
		st.use(n)
	else:
		Interact.detach(item)
		item.destroy()
	Sfx.play("ratchet", user.cell, 0.5)
	Game.tell(user, "%s now holds %d/%d matter-units." % [e.the().capitalize(), int(matter), int(max_matter)])
	return true

func _use(user: Entity, cost: float) -> bool:
	if matter < cost:
		Game.tell(user, "The \"Low Matter\" light on %s blinks! It needs %d." % [e.the(), int(cost)], "warn")
		return false
	return true

## Click on a tile next to you.
func act(user: Entity, cell: Vector2i) -> bool:
	var map := Game.map
	if not map.inb(cell) or not Entity.cells_adjacent(user.cell, cell):
		return false
	var t := map.get_turf(cell)
	var fl: int = map.tflags(cell)
	var i := map.idx(cell)
	var s: int = map.structure[i]
	var cost := 0.0
	var dur := 0.0
	var what := ""
	var action := Callable()
	match mode:
		"floorwall":
			if (t == Defs.T_PLATING or fl & Defs.F_OUTDOOR) and s == Defs.S_NONE and not (fl & Defs.F_SOLID):
				cost = 1.0
				dur = 0.2
				what = "a floor"
				action = func(): map.set_turf(cell, Defs.T_STEEL)
			elif (fl & Defs.F_FLOOR) and s == Defs.S_NONE and _clear(cell):
				cost = 16.0
				dur = 2.0
				what = "a wall"
				action = func(): map.set_turf(cell, Defs.T_WALL)
		"airlock":
			if (fl & Defs.F_FLOOR or t == Defs.T_PLATING) and s == Defs.S_NONE and _clear(cell):
				cost = 16.0
				dur = 5.0
				what = "a bulkhead hatch"
				action = func():
					var d := Proto.spawn("airlock", cell, {"comps": {"door": {"dept": "generic", "access": []}}})
					d.display_name = "bulkhead hatch"
		"window":
			if (fl & Defs.F_FLOOR or t == Defs.T_PLATING) and s == Defs.S_NONE and _clear(cell):
				cost = 6.0
				dur = 2.5
				what = "a reinforced window"
				action = func():
					map.set_turf(cell, Defs.T_PLATING)
					map.set_structure(cell, Defs.S_RWINDOW)
		"machine_frame", "computer_frame":
			if (fl & Defs.F_FLOOR or t == Defs.T_PLATING) and s == Defs.S_NONE and _clear(cell):
				cost = 20.0
				dur = 2.0
				what = "a frame"
				var fproto := mode
				action = func():
					var f := Proto.spawn(fproto, cell)
					f.c(&"frame").state = 1
					f.c(&"frame")._refresh()
		"deconstruct":
			var door: Entity = null
			for x in Game.at(cell):
				if x.has_c(&"door") or x.has_c(&"frame"):
					door = x
			if door:
				cost = 32.0
				dur = 5.0
				what = "deconstructs %s" % door.display_name
				action = func(): door.destroy()
			elif fl & Defs.F_WALL:
				cost = 26.0
				dur = 4.0
				what = "deconstructs the wall"
				action = func(): map.set_turf(cell, Defs.T_STEEL)
			elif Defs.is_window(s) or Defs.is_grille(s) or s == Defs.S_GIRDER:
				cost = 8.0
				dur = 1.0
				what = "deconstructs the %s" % Defs.STRUCTS[s]["name"]
				action = func(): map.set_structure(cell, Defs.S_NONE)
			elif fl & Defs.F_FLOOR:
				cost = 16.0
				dur = 2.0
				what = "deconstructs the floor"
				action = func(): map.set_turf(cell, Defs.T_PLATING)
	var plan := {"cost": cost, "t": dur, "do": action, "what": what}
	if not action.is_valid():
		Game.tell(user, "%s can't do that there." % e.the().capitalize(), "warn")
		return true
	if not _use(user, plan["cost"]):
		return true
	Sfx.play("spark", cell, 0.4)
	Fx.sparks(cell)
	DoAfter.start(user, null, plan["t"], func(ok):
		if ok and is_instance_valid(e) and not e.removed and matter >= plan["cost"]:
			matter -= plan["cost"]
			plan["do"].call()
			if Game.atmos:
				Game.atmos.wake(cell)
			Sfx.play("ratchet", cell, 0.6)
			Game.visible_message(cell, "%s uses %s: %s." % [user.display_name, e.the(), plan["what"]])
			Skills.add_xp(user, "construction", 4.0)
	)
	return true

func _clear(cell: Vector2i) -> bool:
	for x in Game.at(cell):
		if x.has_c(&"mob") or (x.has_c(&"blocker") and x.c(&"blocker").dense) or x.has_c(&"door"):
			return false
	return true

func examine(_user: Entity, lines: Array) -> void:
	lines.append("It currently holds %d/%d matter-units. Mode: %s. (Z to change.)" % [int(matter), int(max_matter), MODE_NAMES[mode]])
