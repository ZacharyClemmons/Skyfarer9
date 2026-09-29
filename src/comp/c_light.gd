class_name CLight extends Component
## Light emitter consumed by LightingSystem. Kinds:
##  "fixture"   wall tube, needs the area's lighting channel
##  "emergency" red lamp that turns on when the lighting channel is down
##  "always"    self powered (floodlights, glowing crystals, fires)
##  "item"      held flashlight etc. (on when `on`)
##  "machine"   small glow from screens (needs the owner machine operable)

var kind := "fixture"
var radius := 6.0
var color := Color(1.0, 0.95, 0.85)
var energy := 1.0
var on := true
var broken := false
var flicker := 0.0 # seconds of flickering left
var lit := false # computed state
var origin_offset := Vector2i.ZERO

func key() -> StringName:
	return &"light"

func setup(p: Dictionary) -> CLight:
	kind = p.get("kind", kind)
	radius = p.get("radius", radius)
	color = Color(p.get("color", color.to_html()))
	energy = p.get("energy", energy)
	on = p.get("on", on)
	if p.has("origin"):
		origin_offset = Vector2i(p["origin"][0], p["origin"][1])
	return self

func on_added() -> void:
	if Game.lighting:
		Game.lighting.register(self)

func on_removed() -> void:
	if Game.lighting:
		Game.lighting.unregister(self)

func on_moved(_f: Vector2i, _t: Vector2i) -> void:
	if lit and Game.lighting:
		Game.lighting.mark_dirty(self)

func origin() -> Vector2i:
	return e.root_cell() + origin_offset

func compute_lit() -> bool:
	if broken or not on:
		return false
	match kind:
		"fixture", "ceiling":
			return Game.map.area_at(origin()).powered("light")
		"emergency":
			# a real power cut (not someone flicking the light switch) or a fire alarm
			var a := Game.map.area_at(origin())
			return (not a.powered("light") and not a.lights_forced_off) or a.fire_alarm
		"machine":
			var m = e.c(&"machine")
			return m != null and m.operable()
		"item":
			return on
	return true

## Change the light's colour (e.g. an APC's charge lamp) and relight around it.
func set_color(c: Color) -> void:
	if c.is_equal_approx(color):
		return
	color = c
	if lit and Game.lighting:
		Game.lighting.mark_dirty(self)
	if e.glow_spr:
		e.glow_spr.modulate = c

func refresh() -> void:
	var l := compute_lit()
	if l != lit:
		lit = l
		if Game.lighting:
			Game.lighting.mark_dirty(self)
		_update_sprite()

func _update_sprite() -> void:
	if kind == "fixture":
		e.set_sprite("objects", "light_broken" if broken else ("light_on" if lit else "light_off"))
	elif kind == "emergency":
		e.set_glow_visible(lit)

func attack_hand(user: Entity) -> bool:
	return Construction.take_tube(user, e)

func attackby(user: Entity, item: Entity) -> bool:
	if kind == "fixture" and broken and item.proto == "light_tube":
		broken = false
		item.destroy()
		refresh()
		Game.tell(user, "You replace the light tube.")
		return true
	return false

func take_damage(amount: float, _kind: String, _source: Entity) -> float:
	if kind == "fixture" and amount > 8 and not broken:
		break_light()
		return 0.0
	return amount

func break_light() -> void:
	if broken:
		return
	broken = true
	Fx.glass(e.cell)
	Sfx.play("glass", e.cell)
	refresh()
	_update_sprite()

func examine(_user: Entity, lines: Array) -> void:
	if broken:
		lines.append("The tube is broken.")
