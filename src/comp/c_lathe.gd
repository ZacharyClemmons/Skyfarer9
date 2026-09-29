class_name CLathe extends Component
## tg autolathe / protolathe (code/game/machinery/autolathe.dm,
## code/modules/research/machinery/_production.dm). Feed it sheets (or raw ore, which it
## smelts at half value) and it prints designs out of the stored materials. The autolathe
## has a fixed catalogue; the protolathe prints whatever the techweb has unlocked.

var kind := "autolathe"
var mats := {"iron": 0.0, "glass": 0.0, "plasma": 0.0, "gold": 0.0}
var queue: Array = [] # [{"id", "left"}]
var busy_t := 0.0
var panel_open := false

## tg SHEET_MATERIAL_AMOUNT per sheet. Ore is smelted in-machine at half the value.
const SHEET := 100.0
const INTAKE := {
	"sheet_metal": {"iron": 100.0}, "sheet_glass": {"glass": 100.0}, "sheet_rglass": {"iron": 50.0, "glass": 100.0},
	"sheet_plasma": {"plasma": 100.0}, "rods": {"iron": 50.0},
	"ore_iron": {"iron": 50.0}, "ore_plasma": {"plasma": 50.0}, "ore_gold": {"gold": 50.0}, "glass_shard": {"glass": 50.0},
}
const MAT_NAMES := {"iron": "Iron", "glass": "Glass", "plasma": "Plasma", "gold": "Gold"}
const MAT_SHEET := {"iron": "sheet_metal", "glass": "sheet_glass", "plasma": "sheet_plasma"}
const CAPACITY := 20000.0

func key() -> StringName:
	return &"lathe"

func setup(p: Dictionary) -> CLathe:
	kind = p.get("kind", kind)
	for m in p.get("mats", {}):
		mats[m] = float(p["mats"][m])
	return self

func title() -> String:
	return "Autolathe" if kind == "autolathe" else "Protolathe"

func operable() -> bool:
	var m: CMachine = e.c(&"machine")
	return m == null or m.operable()

func can_afford(id: String, n := 1) -> bool:
	var d: Dictionary = Research.DESIGNS[id]
	for m in d["mats"]:
		if mats.get(m, 0.0) < float(d["mats"][m]) * n:
			return false
	return true

func print_design(user: Entity, id: String, n := 1) -> void:
	if not operable():
		Game.tell(user, "%s is unpowered." % e.the().capitalize(), "warn")
		return
	if not id in Research.designs_for(kind):
		return
	if not can_afford(id, n):
		Game.tell(user, "Not enough materials for that.", "warn")
		return
	var d: Dictionary = Research.DESIGNS[id]
	for m in d["mats"]:
		mats[m] -= float(d["mats"][m]) * n
	queue.append({"id": id, "left": n})
	Sfx.play("click", e.cell, 0.5)

func tick(dt: float) -> void:
	var m: CMachine = e.c(&"machine")
	if m:
		m.active = not queue.is_empty()
	if queue.is_empty() or not operable():
		return
	busy_t += dt
	var job: Dictionary = queue[0]
	var d: Dictionary = Research.DESIGNS[job["id"]]
	# build time scales with the material in the design: a second for small things
	var need := clampf(1.0 + _mat_sum(d) / 400.0, 1.0, 6.0)
	if busy_t < need:
		if e.spr_name != _spr(true):
			e.set_sprite("objects", _spr(true))
		return
	busy_t = 0.0
	_spawn_output(d)
	job["left"] -= 1
	if job["left"] <= 0:
		queue.pop_front()
	if queue.is_empty():
		e.set_sprite("objects", _spr(false))
		Sfx.play("ding", e.cell, 0.5)

func _spr(on: bool) -> String:
	if kind == "autolathe":
		return "autolathe_on" if on else "autolathe"
	return "rnd_protolathe"

func _mat_sum(d: Dictionary) -> float:
	var t := 0.0
	for k in d["mats"]:
		t += float(d["mats"][k])
	return t

func _spawn_output(d: Dictionary) -> void:
	var ov := {"nofill": d.get("empty", false)}
	if d.has("comps"):
		ov["comps"] = d["comps"].duplicate(true)
	if d.has("amount"):
		if not ov.has("comps"):
			ov["comps"] = {}
		ov["comps"]["stack"] = {"amount": d["amount"]}
	elif String(d["proto"]).begins_with("sheet_"):
		ov["comps"] = {"stack": {"amount": 1}}
	var it := Proto.spawn(d["proto"], _out_cell(), ov)
	if d.get("empty", false) and it.has_c(&"tank"):
		it.c(&"tank").moles = 0.0
	Sfx.play("vend", e.cell, 0.6)

## tg drops prints on the lathe's own turf; ours is dense, so the free tile beside it.
func _out_cell() -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var c: Vector2i = e.cell + d
		if Game.map.inb(c) and not Game.map.blocks_move_static(c) and Game.map.dense_count[Game.map.idx(c)] == 0:
			return c
	return e.cell

## tg material container: insert sheets / ore.
func insert(user: Entity, item: Entity) -> bool:
	var intake: Dictionary = INTAKE.get(item.proto, {})
	if intake.is_empty():
		return false
	if not operable():
		Game.tell(user, "%s is unpowered." % e.the().capitalize(), "warn")
		return true
	var st: CStack = item.c(&"stack")
	var n := st.amount if st else 1
	for m in intake:
		n = mini(n, int((CAPACITY - mats.get(m, 0.0)) / float(intake[m])))
	if n <= 0:
		Game.tell(user, "%s is full." % e.the().capitalize(), "warn")
		return true
	for m in intake:
		mats[m] = mats.get(m, 0.0) + float(intake[m]) * n
	var nm := item.display_name
	if st:
		st.use(n)
	else:
		Interact.detach(item)
		item.destroy()
	Sfx.play("ratchet", e.cell, 0.5)
	Game.visible_message(e.cell, "%s inserts %d %s into %s." % [user.display_name, n, nm, e.the()])
	return true

func eject(user: Entity, m: String, sheets: int) -> void:
	if not MAT_SHEET.has(m):
		return
	var n := mini(sheets, int(mats.get(m, 0.0) / SHEET))
	if n <= 0:
		return
	mats[m] -= n * SHEET
	var it := Proto.spawn(MAT_SHEET[m], _out_cell(), {"comps": {"stack": {"amount": n}}})
	Game.tell(user, "%s ejects %d %s." % [e.the().capitalize(), n, it.display_name])

func attackby(user: Entity, item: Entity) -> bool:
	return insert(user, item)

func attack_hand(user: Entity) -> bool:
	if not operable():
		Game.tell(user, "%s is dark." % e.the().capitalize(), "warn")
		return true
	Bus.ui_open_window.emit("lathe", e)
	return true

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Use", "cb": attack_hand.bind(user), "priority": 7})

func examine(_user: Entity, lines: Array) -> void:
	var parts := []
	for m in mats:
		if mats[m] > 0:
			parts.append("%s %.0f" % [MAT_NAMES[m], mats[m]])
	lines.append("Materials: %s." % (", ".join(parts) if not parts.is_empty() else "empty"))
	lines.append("[color=#8a93a3]Insert sheets or ore to load it.[/color]")
	if not queue.is_empty():
		lines.append("It's busy printing.")

func ai_tags(out: Dictionary) -> void:
	out["lathe"] = true
