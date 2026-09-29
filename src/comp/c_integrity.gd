class_name CIntegrity extends Component
## tg atom integrity for structures: hit something enough and it breaks. Machines have
## their own (CMachine); this is for doors, lockers, tables, chairs and the like.
## Each kind carries tg's max_integrity, armour, damage_deflection and integrity_failure
## (the point where it breaks: a locker bursts open, a table collapses, an airlock dies).

var hp := 100.0
var max_hp := 100.0
var armor: Dictionary = {}
var deflect := 0.0
var failure := 0.0 # fraction of max_hp; 0 = no special broken state
var broken := false

func key() -> StringName:
	return &"integrity"

## tg stats by kind of structure: {hp, armor, deflect, failure}.
##   airlock (door.dm, airlock.dm): 300, machinery_door armour, deflection 21, breaks at 25%
##   closet (closets.dm): 200, structure_closet armour, busts open at 25%
##   table (tables_racks.dm): 100, collapses at 33%;  chair: 100, 10%;  bed: 100, 35%
const DOOR_ARMOR := {"melee": 30, "bullet": 30, "laser": 20, "energy": 20, "bomb": 10, "fire": 80}
const CLOSET_ARMOR := {"melee": 20, "bullet": 10, "laser": 10, "bomb": 10, "fire": 70, "acid": 60}
const SECURE_CLOSET_ARMOR := {"melee": 30, "bullet": 50, "laser": 50, "energy": 100, "fire": 80, "acid": 80}

static func profile_for(e: Entity) -> Dictionary:
	if e.has_c(&"door"):
		return {"hp": 300.0, "armor": DOOR_ARMOR, "deflect": 21.0, "failure": 0.25}
	if e.has_c(&"storage") and e.c(&"storage").kind == "closet":
		if e.c(&"storage").secure:
			return {"hp": 250.0, "armor": SECURE_CLOSET_ARMOR, "deflect": 20.0, "failure": 0.25}
		return {"hp": 200.0, "armor": CLOSET_ARMOR, "deflect": 0.0, "failure": 0.25}
	if e.has_c(&"furniture"):
		match e.c(&"furniture").kind:
			"table", "counter": return {"hp": 100.0, "armor": {}, "deflect": 0.0, "failure": 0.33}
			"seat": return {"hp": 100.0, "armor": {}, "deflect": 0.0, "failure": 0.1}
			"bed": return {"hp": 100.0, "armor": {}, "deflect": 0.0, "failure": 0.35}
	return {"hp": 150.0, "armor": {}, "deflect": 0.0, "failure": 0.0}

static func default_for(e: Entity) -> float:
	return profile_for(e)["hp"]

func setup(p: Dictionary) -> CIntegrity:
	max_hp = float(p.get("hp", max_hp))
	hp = max_hp
	armor = p.get("armor", armor)
	deflect = p.get("deflect", deflect)
	failure = p.get("failure", failure)
	return self

## Proto hook: the tg profile for whatever this turned out to be, with any proto overrides.
static func for_entity(e: Entity, over: Dictionary) -> CIntegrity:
	var prof := profile_for(e).duplicate()
	prof.merge(over, true)
	return CIntegrity.new().setup(prof)

## tg run_atom_armor on this object (see Entity.take_damage).
func reduce(amount: float, kind: String, flag: String, ap: float) -> float:
	return Structures.reduce(amount, kind, flag, armor, deflect, ap)

func take_damage(amount: float, kind: String, source: Entity) -> float:
	if amount <= 0.0 or not kind in ["brute", "burn"]:
		return amount
	var before := hp
	hp -= amount
	Fx.jolt(e)
	if failure > 0.0 and not broken and before > max_hp * failure and hp <= max_hp * failure:
		_break(source)
		if e.removed:
			return 0.0
	if hp <= 0.0:
		Game.visible_message(e.cell, "%s breaks apart!" % e.display_name.capitalize(), "warn")
		Interact.spawn_debris(e.cell, 1)
		e.destroy()
	return 0.0

## tg atom_break for this kind of thing.
func _break(source: Entity) -> void:
	broken = true
	var st = e.c(&"storage")
	if st and st.kind == "closet":
		# tg closet bust_open: the lock gives, the door swings open
		st.bust_open()
		Game.visible_message(e.cell, "%s bursts open!" % e.the().capitalize(), "warn")
		Bus.stimulus.emit({"type": "break_in", "actor": source, "target": e, "cell": e.cell, "loud": 6.0, "illegal": source != null})
		return
	var door = e.c(&"door")
	if door:
		# tg airlock atom_break: the electronics die; it can only be forced now
		door.broken = true
		Fx.sparks(e.cell)
		Game.visible_message(e.cell, "%s sparks and its lights go dark!" % e.the().capitalize(), "warn")
		return
	var fu = e.c(&"furniture")
	if fu:
		# tg table/chair/bed atom_break: it collapses into parts (deconstruct(FALSE))
		Game.visible_message(e.cell, "%s collapses!" % e.the().capitalize(), "warn")
		Sfx.play("wall_hit", e.cell, 1.0)
		Interact.spawn_debris(e.cell, 1)
		Proto.spawn("sheet_metal", e.cell, {"comps": {"stack": {"amount": 1}}})
		e.destroy()

func repair(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	if broken and hp > max_hp * failure:
		broken = false
		var door = e.c(&"door")
		if door:
			door.broken = false

func examine(_user: Entity, lines: Array) -> void:
	# tg structure examine_status
	var pct := hp / max_hp * 100.0
	if broken and e.has_c(&"door"):
		lines.append("[color=#ffb84a]It appears to be broken.[/color]")
	elif pct < 25.0:
		lines.append("[color=#ff5a4a]It's falling apart![/color]")
	elif pct < 50.0:
		lines.append("[color=#ffb84a]It appears heavily damaged.[/color]")
	elif pct < 99.5:
		lines.append("It looks slightly damaged.")
