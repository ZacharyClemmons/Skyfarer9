class_name CMelt extends Component
## Something frozen that melts when it's warm (glacier ice). Drips its volume out as
## liquid onto wherever it is, then disappears. Containers insulate it.

var into := "water"
var volume := 25.0
var time := 90.0 # seconds to fully melt at ~20C
var left := 0.0

func key() -> StringName:
	return &"melt"

func setup(p: Dictionary) -> CMelt:
	into = p.get("into", into)
	volume = p.get("volume", volume)
	time = p.get("time", time)
	left = volume
	return self

func tick(dt: float) -> void:
	if e.removed:
		return
	if e.holder != null and e.holder.has_c(&"storage"):
		return
	var c := e.root_cell()
	var t := Liquids.tile_temp(c)
	if t < 278.0:
		return
	var amt := volume / time * dt * clampf((t - 273.0) / 20.0, 0.1, 4.0)
	left -= amt
	Liquids.spill(c, into, amt)
	if left <= 0.0:
		var holder := e.root()
		if holder != e:
			Game.tell(holder, "%s melts away in your hands." % e.display_name.capitalize())
		e.destroy()

func examine(_user: Entity, lines: Array) -> void:
	if left < volume * 0.95:
		lines.append("It's %s." % ("dripping" if left > volume * 0.5 else "melting fast"))
