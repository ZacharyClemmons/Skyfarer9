class_name CChemMachine extends Component
## tg chemistry machines, one component with a `kind`:
##   master   ChemMaster 3000 (code/modules/reagents/chemistry/machinery/chem_master.dm):
##            load a beaker, move reagents into its buffer, and press pills (up to 50 u
##            each), patches (up to 40 u) or bottles (up to 30 u) out of the buffer
##   heater   chem heater: load a beaker, set a target temperature, and it heats or
##            cools the beaker toward it (reactions with a minimum temperature kick off)

var kind := "master"
var beaker: Entity = null
var buffer := {}
var on := false
var target_temp := 300.0
var per_item := 10.0

const HEAT_RATE := 25.0 # K per second, tg's heater at base parts

func key() -> StringName:
	return &"chemmachine"

func setup(p: Dictionary) -> CChemMachine:
	kind = p.get("kind", kind)
	return self

func operable() -> bool:
	var m: CMachine = e.c(&"machine")
	return m == null or m.operable()

func beaker_r() -> CReagents:
	return beaker.c(&"reagents") if beaker and is_instance_valid(beaker) and not beaker.removed else null

func attackby(user: Entity, item: Entity) -> bool:
	var r: CReagents = item.c(&"reagents")
	if r == null or not (r.is_open() or r.kind == "blood_pack"):
		return false
	if beaker != null:
		Game.tell(user, "There's already a container loaded.", "warn")
		return true
	Interact.detach(item)
	item.holder = e
	item.visible = false
	beaker = item
	Sfx.play("click", e.cell, 0.6)
	Game.tell(user, "You load %s into %s." % [item.the(), e.the()])
	return true

func attack_hand(_user: Entity) -> bool:
	Bus.ui_open_window.emit("chemmachine", e)
	return true

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Use", "cb": attack_hand.bind(user), "priority": 7})
	if beaker:
		out.append({"name": "Eject %s" % beaker.display_name, "cb": eject.bind(user), "priority": 5})

func eject(user: Entity) -> void:
	if beaker == null:
		return
	var b := beaker
	beaker = null
	b.holder = null
	b.visible = true
	var c := e.cell + Vector2i(0, 1)
	Game.drop_to_map(b, c)
	b.place(c)
	if user and user.c(&"inv"):
		user.c(&"inv").put_in_hands(b)
	on = false
	_sprite()

# ------------------------------------------------------------------ ChemMaster
func to_buffer(reagent: String, units: float) -> void:
	var r := beaker_r()
	if r == null or not r.contents.has(reagent):
		return
	var n := minf(units, r.contents[reagent])
	r.contents[reagent] -= n
	if r.contents[reagent] < 0.01:
		r.contents.erase(reagent)
	buffer[reagent] = buffer.get(reagent, 0.0) + n
	r._update_sprite()

func from_buffer(reagent: String, units: float, discard := false) -> void:
	if not buffer.has(reagent):
		return
	var n := minf(units, buffer[reagent])
	buffer[reagent] -= n
	if buffer[reagent] < 0.01:
		buffer.erase(reagent)
	var r := beaker_r()
	if r and not discard:
		r.put({reagent: n})

func buffer_total() -> float:
	var t := 0.0
	for k in buffer:
		t += buffer[k]
	return t

func _take_buffer(units: float) -> Dictionary:
	var t := buffer_total()
	var out := {}
	if t <= 0.0:
		return out
	var f := minf(1.0, units / t)
	for k in buffer.keys():
		out[k] = buffer[k] * f
		buffer[k] -= out[k]
		if buffer[k] < 0.01:
			buffer.erase(k)
	return out

## tg chem_master "create": pills, patches or bottles, `count` of them, split evenly.
func produce(user: Entity, what: String, count: int) -> void:
	if not operable() or buffer_total() <= 0.0:
		return
	var cap: float = {"pill": 50.0, "patch": 40.0, "bottle": 30.0}[what]
	count = clampi(count, 1, 20)
	var each := minf(cap, buffer_total() / count)
	var main := ""
	var best := 0.0
	for k in buffer:
		if buffer[k] > best:
			best = buffer[k]
			main = k
	var made := 0
	for i in count:
		if buffer_total() < 0.05:
			break
		var stuff := _take_buffer(each)
		var proto: String = {"pill": "pill", "patch": "patch", "bottle": "bottle"}[what]
		var it := Proto.spawn(proto, e.cell + Vector2i(0, 1), {"name": "%s (%s %du)" % [proto, Chem.rname(main).to_lower(), int(each)]})
		it.c(&"reagents").put(stuff)
		made += 1
	Sfx.play("vend", e.cell, 0.5)
	Game.tell(user, "%s dispenses %d %s%s." % [e.the().capitalize(), made, what, "" if made == 1 else "es" if what == "patch" else "s"])

# ------------------------------------------------------------------ heater
func tick(dt: float) -> void:
	var m: CMachine = e.c(&"machine")
	if kind != "heater":
		return
	if m:
		m.active = on
	var r := beaker_r()
	if not on or r == null or not operable():
		return
	r.temp = move_toward(r.temp, target_temp, HEAT_RATE * dt)
	var fx := Chem.react(r.contents, r.temp)
	if not fx.is_empty():
		Chem.apply_effects(fx, e.cell, null)
	r._update_sprite()

func toggle(user: Entity) -> void:
	on = not on
	Sfx.play("click", e.cell, 0.5)
	Game.tell(user, "You turn %s %s." % [e.the(), "on" if on else "off"])
	_sprite()

func _sprite() -> void:
	if kind == "heater":
		e.set_sprite("objects", "chem_heater_on" if on and beaker else "chem_heater")

func examine(_user: Entity, lines: Array) -> void:
	if beaker:
		lines.append("%s is loaded." % beaker.display_name.capitalize())
	if kind == "heater":
		lines.append("It's %s, set to %d K." % ["on" if on else "off", int(target_temp)])

func ai_tags(out: Dictionary) -> void:
	out["chem_" + kind] = true
