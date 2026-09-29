class_name CShipyard extends Component
## The yard master's desk. Buy a hull out of the book, draw your own, or refit the one
## you have.
##
## This is the object the whole opening of the game hangs on: you arrive in Meridian with
## the price of a skiff in your purse and a choice about what to do with it. Buy the
## skiff and fly out in ninety seconds, or spend the same money on timber and draw
## something that is yours. Both are correct and the game does not have an opinion.

## Refitting is cheaper alongside than it is standing on a rock somewhere.
const YARD_DISCOUNT := 0.85

var berth := Vector2i.ZERO     # where a bought hull is laid down
var berth_dir := Defs.DIR_E
var port_tier := 1
var biome := "verdance"

func key() -> StringName:
	return &"shipyard"

func examine(user: Entity, lines: Array) -> void:
	lines.append("[color=#e8c85a]The yard.[/color] Hulls out of the book, hulls off a drawing, and refits.")
	var sh: Airship = Game.fleet.player_ship if Game.fleet else null
	if sh != null and sh.present:
		lines.append("[i]%s is on the register.[/i]" % sh.ship_name)
	lines.append("[i]Click the desk to open the yard.[/i]")

## Clicking the desk opens the board. Making this a verb only would mean a player who
## has not learned right-click yet can walk into the yard, see the desk, and leave again.
func attack_hand(user: Entity) -> bool:
	Shipyard.open(user, self)
	return true

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Open the yard", "priority": 100, "cb": func():
		Shipyard.open(user, self)})

# ------------------------------------------------------------------ hull pricing
## What a stock hull costs here. A hull's price is its material cost plus what the yard
## charges for putting it together, and the yard's mark-up falls as you become someone
## they know.
static func hull_price(hull_id: String, who: Entity, markup := 1.0) -> int:
	var h := ShipPlan.get_hull(hull_id)
	var cells: Dictionary = ShipPlan.to_cells(h["plan"], int(h["keel"]))
	var total := 0
	for key in cells:
		total += glyph_cost(String(cells[key]))
	var fit := Airship.default_fittings(cells, int(h.get("grade", 1)))
	for key in fit:
		total += int(ShipParts.stat(String(fit[key]), "cost", 0.0))
	total = int(total * 1.18) # the yard's labour
	return Economy.buy_price(total, who, markup)

## What one tile of hull costs in materials and labour, before any module in it.
static func glyph_cost(g: String) -> int:
	match g:
		"K": return 46
		"#": return 18
		"I": return 16
		"W": return 26
		"w": return 44
		"+": return 34
		"A": return 62
		"=": return 12
		".", ",": return 8
		"O": return 70
		"S": return 90
		"k", "l", "o", "c", "t", "b": return 22
		_: return 14

## What it costs to have the yard build a layout you drew, with every module in it.
static func plan_price(cells: Dictionary, fittings: Dictionary, who: Entity, markup := 1.0) -> int:
	var total := 0
	for key in cells:
		total += glyph_cost(String(cells[key]))
	for key in fittings:
		total += int(ShipParts.stat(String(fittings[key]), "cost", 0.0))
	return Economy.buy_price(int(total * 1.18), who, markup)

## Price a refit as a difference. Old layout/fittings are what she is now, new are what she
## would become. Returns {"build", "refund", "net", "price", "lines"}: `build` is what the
## yard charges for new tiles and modules, `refund` is 30% of the tile value and 40% of
## the module value taken off her (whether removed or replaced), `net` is the difference
## (may be negative), and `price` is what you actually hand over: never below zero, after
## the port's mark-up and your standing. `lines` is [[label, marks]] for a breakdown UI.
static func refit_quote(old_cells: Dictionary, old_fit: Dictionary, new_cells: Dictionary,
		new_fit: Dictionary, who: Entity, markup := YARD_DISCOUNT, grade := 1) -> Dictionary:
	var build := 0
	var refund := 0
	var lines := []
	var keys := {}
	for k in old_cells:
		keys[k] = true
	for k in new_cells:
		keys[k] = true
	for k in keys:
		var was := String(old_cells.get(k, ""))
		var now := String(new_cells.get(k, ""))
		var old_mod := String(old_fit.get(k, ShipParts.default_for(was, grade))) if was != "" else ""
		var new_mod := String(new_fit.get(k, ShipParts.default_for(now, grade))) if now != "" else ""
		if was != now:
			if now != "":
				build += glyph_cost(now)
			if was != "":
				refund += int(glyph_cost(was) * 0.3)
		if new_mod != old_mod or was != now:
			if new_mod != "" and (new_mod != old_mod or was != now):
				build += int(ShipParts.stat(new_mod, "cost", 0.0))
			if old_mod != "" and (new_mod != old_mod or was != now):
				refund += int(ShipParts.stat(old_mod, "cost", 0.0) * 0.4)
	lines.append(["New tiles and modules", build])
	lines.append(["Salvage credit", -refund])
	var net := build - refund
	return {"build": build, "refund": refund, "net": net, "lines": lines,
		"price": maxi(0, Economy.buy_price(maxi(0, net), who, markup))}
