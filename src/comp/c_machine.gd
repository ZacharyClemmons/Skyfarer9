class_name CMachine extends Component
## Generic machinery: durability, breakdowns, area power draw (tg: /obj/machinery
## use_power + power_channel). Specific behaviour lives in sibling components.

var hp := 100.0
var max_hp := 100.0
var broken := false
var channel := "equip" # equip / light / environ
var idle_w := 20.0
var active_w := 0.0
var active := false
var needs_power := true
var spark_t := 0.0
var flammable_when_broken := false
## tg /datum/armor/obj_machinery
const ARMOR := {"melee": 25, "bullet": 10, "laser": 10, "fire": 50}

func key() -> StringName:
	return &"machine"

func setup(p: Dictionary) -> CMachine:
	max_hp = p.get("hp", max_hp)
	hp = max_hp
	channel = p.get("channel", channel)
	idle_w = p.get("idle", idle_w)
	active_w = p.get("active_w", active_w)
	needs_power = p.get("needs_power", needs_power)
	return self

func area() -> Area:
	return Game.map.area_at(e.cell)

func powered() -> bool:
	return not needs_power or area().powered(channel)

func operable() -> bool:
	return powered() and not broken

func load_w() -> float:
	if broken or not needs_power:
		return 0.0
	return idle_w + (active_w if active else 0.0)

func reduce(amount: float, kind: String, flag: String, ap: float) -> float:
	return Structures.reduce(amount, kind, flag, ARMOR, 0.0, ap)

func take_damage(amount: float, kind: String, source: Entity) -> float:
	if amount <= 0:
		return 0.0
	hp = maxf(0.0, hp - amount)
	Fx.jolt(e)
	if hp <= max_hp * 0.4 and not broken:
		set_broken(true, source)
	if hp <= 0:
		Game.visible_message(e.cell, "%s is smashed apart!" % e.display_name.capitalize(), "warn")
		Fx.sparks(e.cell)
		Interact.spawn_debris(e.cell, 2)
		e.destroy()
	return 0.0

func set_broken(v: bool, source: Entity = null) -> void:
	if broken == v:
		return
	broken = v
	if v:
		Fx.sparks(e.cell)
		Game.visible_message(e.cell, "%s sparks and shudders to a halt." % e.the().capitalize(), "warn")
		Bus.stimulus.emit({"type": "machine_broken", "actor": source, "target": e, "cell": e.cell, "loud": 4.0})
		spark_t = 20.0
	e.set_glow_visible(not v and powered())
	for comp in e.comps.values():
		if comp.has_method("on_power_change"):
			comp.on_power_change()

## Called about once per second by MachineSystem.
func tick(_dt: float) -> void:
	if e.glow_spr:
		e.glow_spr.visible = operable()
	if broken and spark_t > 0:
		spark_t -= 1.0
		if Game.rng.randf() < 0.15:
			Fx.sparks(e.cell)
			if Game.atmos:
				Game.atmos.spark(e.cell)

func attackby(user: Entity, item: Entity) -> bool:
	var it: CItem = item.c(&"item")
	if it == null:
		return false
	if broken and it.tool == "multitool":
		var skill := Skills.get_skill(user, "engineering")
		DoAfter.start(user, e, 7.0 - skill * 0.45, func(ok):
			if ok:
				if Game.rng.randf() < 0.25 + skill * 0.1:
					set_broken(false)
					hp = maxf(hp, max_hp * 0.6)
					Game.visible_message(e.cell, "%s repairs the wiring of %s." % [user.display_name, e.the()], "good")
					Bus.stimulus.emit({"type": "repaired", "actor": user, "target": e, "cell": e.cell, "loud": 1.0})
				else:
					Game.tell(user, "You fumble with the wiring. Try again.", "warn")
					if Game.rng.randf() < 0.2 and powered():
						Interact.shock(user, 15.0)
		)
		return true
	if it.tool == "welder" and item.c(&"welder") and item.c(&"welder").lit and hp < max_hp and not broken:
		DoAfter.start(user, e, 3.0, func(ok):
			if ok:
				hp = max_hp
				Game.visible_message(e.cell, "%s welds the dents out of %s." % [user.display_name, e.the()])
		)
		return true
	return false

func examine(_user: Entity, lines: Array) -> void:
	if broken:
		lines.append("[color=#ffb84a]It's broken. The wiring needs work (multitool).[/color]")
	elif hp < max_hp * 0.8:
		lines.append("It looks dented (blowtorch).")
	if needs_power and not powered():
		lines.append("It seems to be unpowered.")

func ai_tags(out: Dictionary) -> void:
	out["machine"] = true
	if broken:
		out["broken_machine"] = true
