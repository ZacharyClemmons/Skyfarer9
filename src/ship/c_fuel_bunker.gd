class_name CFuelBunker extends Component
## A fuel bunker: where the ship keeps its distillate. Thrusters and the boiler draw from
## every bunker aboard, so adding a second one is the cheapest way to extend your range.
##
## Fill it with cans of distillate, or with raw sulfur and plasma if you have a still.
## It is full of flammable liquid in a wooden hull, which the game will remind you about
## at the worst possible moment.

const CAPACITY := 120.0

var mod := "bunker_small"
var amount := 0.0
var capacity := CAPACITY
var _condense_t := 0.0

func key() -> StringName:
	return &"fuelbunker"

func setup(p: Dictionary) -> CFuelBunker:
	capacity = p.get("capacity", capacity)
	amount = p.get("amount", capacity * 0.55)
	return self

func frac() -> float:
	return amount / maxf(1.0, capacity)

func draw(want: float) -> float:
	var got := minf(want, amount)
	amount -= got
	return got

func add(v: float) -> float:
	var room := capacity - amount
	var took := minf(room, v)
	amount += took
	return took

## An aether condenser slowly makes its own fuel out of the air, faster where the field
## runs thick. It will never make you fast; it will stop you ever being stranded.
func process(delta: float) -> void:
	if not ShipParts.has_quirk(mod, "condense"):
		return
	_condense_t += delta
	if _condense_t < 4.0:
		return
	var rate := 0.16
	if Game.sky != null and Game.sky.has_method("aether_density_at"):
		rate *= Game.sky.aether_density_at(e.cell)
	add(rate * _condense_t)
	_condense_t = 0.0

func examine(_user: Entity, lines: Array) -> void:
	var spec := ShipParts.get_mod(mod)
	if not spec.is_empty():
		lines.append("[color=%s]%s[/color] — %s" % [ShipParts.tier_color(mod),
			String(spec["name"]).capitalize(), "   ".join(ShipParts.stat_lines(mod))])
		var q := ShipParts.quirk_text(mod)
		if q != "":
			lines.append("[color=#e8a83a]%s[/color]" % q)
	lines.append("Distillate: [b]%.0f[/b] of %.0f units (%d%%)." % [amount, capacity, int(frac() * 100.0)])
	if frac() < 0.15:
		lines.append("[color=#e8a83a]Nearly dry.[/color]")

func attackby(user: Entity, item: Entity) -> bool:
	if item.proto == "fuel_can":
		var held: float = float(item.tags.get("fuel", 40.0))
		if held <= 0.0:
			Game.tell(user, "The can is empty.")
			return true
		var took := add(held)
		item.tags["fuel"] = held - took
		Game.tell(user, "You pour %.0f units of distillate into the bunker. (%d%%)" % [took, int(frac() * 100.0)])
		Sfx.play("pour", e.cell, 0.7)
		if float(item.tags["fuel"]) <= 0.01:
			item.display_name = "empty fuel can"
		return true
	return false

## Distillate in a wooden hull. A hit hot enough to light it, lights it.
func take_damage(amount_in: float, kind: String, _source: Entity) -> float:
	if ShipParts.has_quirk(mod, "no_cookoff"):
		return amount_in * 0.5
	if amount_in > 8.0 and (kind == "burn" or kind == "fire") and amount > 4.0:
		var spill := minf(amount, 40.0)
		amount -= spill
		Game.visible_message(e.cell, "[b][color=#ff6a6a]The bunker splits and the distillate catches![/color][/b]", "bad")
		if Game.atmos:
			var i := Game.map.idx(e.cell)
			Game.atmos.add_gas(i, Defs.G_PLASMA, spill * 0.3, Defs.T0C + 400.0)
			Game.atmos.add_heat(i, 260000.0)
	return amount_in

func ai_tags(out: Dictionary) -> void:
	out["fuel"] = true
	if frac() < 0.2:
		out["low_fuel"] = true
