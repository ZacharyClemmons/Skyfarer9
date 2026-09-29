class_name CFlammable extends Component
## Things that burn: paper, wooden furniture, clothing piles, plants. Burning objects
## feed the tile's fire, heat the air and eventually turn to ash.

var ignite_temp := 480.0
var fuel := 30.0
var burning := 0.0

func key() -> StringName:
	return &"flammable"

func setup(p: Dictionary) -> CFlammable:
	ignite_temp = p.get("ignite", ignite_temp)
	fuel = p.get("fuel", fuel)
	return self

func ignite() -> void:
	if burning <= 0.0 and fuel > 0:
		burning = fuel
		Fx.flame_on(e)

## Called by AtmosSystem each atmos tick for burning objects. Returns heat released (J).
func burn_tick(dt: float) -> float:
	if burning <= 0:
		return 0.0
	burning -= dt
	fuel -= dt
	if fuel <= 0:
		burning = 0.0
		Fx.flame_off(e)
		if not e.has_c(&"mob"):
			Game.visible_message(e.cell, "%s burns away to ash." % e.the().capitalize())
			Proto.spawn("decal_scorch", e.root_cell())
			e.destroy()
		return 0.0
	return 60000.0 * dt

func ai_tags(out: Dictionary) -> void:
	if burning > 0:
		out["burning"] = true
