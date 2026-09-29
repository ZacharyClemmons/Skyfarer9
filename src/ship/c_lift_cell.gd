class_name CLiftCell extends Component
## An aetherite lift cell: a braced bladder of rock-gas that wants to go up.
##
## Lift is the one number a skyfarer never stops thinking about. A cell holds a charge of
## aetherite vapour, and how much it lifts falls off with both charge and damage. Cells
## bleed slowly all the time, faster when punctured, and they are the first thing anything
## intelligent goes for when it wants your ship on the ground.
##
## Recharge by feeding it raw aetherite ore, or from a condenser fed off the boiler.

const BLEED := 0.0016 # charge lost per second, intact
const PUNCTURE_BLEED := 0.05 # per second, per point of damage fraction
const ORE_CHARGE := 0.34 # charge one lump of aetherite ore restores

var ship_id := -1
## Which cell this is (ShipParts): how much of the hull's designed lift it carries, and
## whether it does anything unusual about it.
var mod := "lift_std"
var charge := 1.0
var integrity := 1.0
var venting := false # deliberately dumped, to descend fast
var _hiss_t := 0.0

func key() -> StringName:
	return &"liftcell"

## 0..1 fraction of this cell's rated lift that it is actually making.
func output() -> float:
	if venting:
		return charge * integrity * 0.15
	return charge * integrity

func on_added() -> void:
	_refresh()

func process(delta: float) -> void:
	var bleed := BLEED
	if integrity < 1.0:
		bleed += PUNCTURE_BLEED * (1.0 - integrity)
	if venting:
		bleed += 0.14
	if bleed > 0.0 and charge > 0.0:
		charge = maxf(0.0, charge - bleed * delta)
		if bleed > 0.01:
			_hiss_t -= delta
			if _hiss_t <= 0.0:
				_hiss_t = 1.6
				Sfx.play("spray", e.cell, 0.35)
				# escaping aetherite is not toxic, but it does displace the air
				if Game.atmos and not Game.map.is_outdoor(e.cell):
					Game.atmos.add_gas(Game.map.idx(e.cell), Defs.G_HELIUM, 1.2, Defs.T20C)
		_refresh()

func _refresh() -> void:
	var stage := 0
	if charge < 0.25: stage = 2
	elif charge < 0.7: stage = 1
	var nm := "lift_cell_%d" % stage
	if e.spr_name != nm and Gfx.has("objects", nm):
		e.set_sprite("objects", nm)

func examine(_user: Entity, lines: Array) -> void:
	var spec := ShipParts.get_mod(mod)
	if not spec.is_empty():
		lines.append("[color=%s]%s[/color] — %s" % [ShipParts.tier_color(mod),
			String(spec["name"]).capitalize(), "   ".join(ShipParts.stat_lines(mod))])
		var q := ShipParts.quirk_text(mod)
		if q != "":
			lines.append("[color=#e8a83a]%s[/color]" % q)
	lines.append("Charge: [b]%d%%[/b]. Envelope integrity: [b]%d%%[/b]." % [int(charge * 100.0), int(integrity * 100.0)])
	if integrity < 0.98:
		lines.append("[color=#e8a83a]It is hissing. Patch it with a blowtorch, or it will keep bleeding off.[/color]")
	if venting:
		lines.append("[color=#ff8a5a]The vent is open.[/color]")
	if charge < 0.2:
		lines.append("[color=#ff6a6a]All but flat. Feed it aetherite.[/color]")

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Close vent" if venting else "Open vent", "priority": 20,
		"cb": func(): _toggle_vent(user)})

func _toggle_vent(u: Entity) -> void:
	venting = not venting
	Game.tell(u, "You %s the lift cell's vent." % ("open" if venting else "close"))
	Sfx.play("ratchet", e.cell, 0.6)

func attackby(user: Entity, item: Entity) -> bool:
	# feed it ore
	if item.proto == "ore_aetherite":
		if charge >= 0.999:
			Game.tell(user, "It is already full.")
			return true
		var st: CStack = item.c(&"stack")
		charge = minf(1.0, charge + ORE_CHARGE * (1.0 + Skills.frac(user, "artifice") * 0.6))
		_refresh()
		Game.tell(user, "You crack the aetherite into the cell's hopper. Charge: %d%%." % int(charge * 100.0))
		Sfx.play("dig", e.cell, 0.5)
		Skills.add_xp(user, "rigging", 10.0)
		if st != null and st.amount > 1:
			st.amount -= 1
		else:
			item.destroy()
		return true
	# patch a puncture
	var it: CItem = item.c(&"item")
	if it != null and it.tool == "welder" and integrity < 1.0:
		var w = item.c(&"welder")
		if w != null and not w.lit:
			Game.tell(user, "Light the blowtorch first.")
			return true
		var patch: float = 0.28 + Skills.frac(user, "rigging") * 0.5
		DoAfter.start(user, e, 2.4 * Skills.speed(user, "rigging"), func(ok: bool):
			if not ok:
				return
			integrity = minf(1.0, integrity + patch)
			Game.tell(user, "You weld a patch over the tear. Integrity: %d%%." % int(integrity * 100.0))
			Skills.add_xp(user, "rigging", 22.0)
			Skills.add_xp(user, "engineering", 6.0)
			Sfx.play("welder", e.cell, 0.7))
		return true
	return false

func take_damage(amount: float, kind: String, _source: Entity) -> float:
	if amount <= 0.0:
		return 0.0
	integrity = maxf(0.0, integrity - amount * 0.012)
	if kind == "burn" or kind == "fire":
		charge = maxf(0.0, charge - amount * 0.01)
	Game.visible_message(e.cell, "[b]The lift cell tears open, hissing.[/b]" if integrity < 0.6 else "The lift cell takes a hit.", "warn")
	Fx.sparks(e.cell)
	_refresh()
	return 0.0

func ai_tags(out: Dictionary) -> void:
	out["lift_cell"] = true
	if integrity < 0.9 or charge < 0.5:
		out["broken"] = true
