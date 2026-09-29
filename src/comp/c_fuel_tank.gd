class_name CFuelTank extends Component
## Welding fuel tank (tg: /obj/structure/reagent_dispensers/fueltank). Refills welders.
## A wrench opens the tap and fuel pours onto the floor. Fire, a lit welder or enough
## damage and it goes up.

var fuel := 1000.0
var max_fuel := 1000.0
var leaking := false
var hp := 60.0
var heat := 0.0
var last_touch: Entity = null

func key() -> StringName:
	return &"fueltank"

func tick(dt: float) -> void:
	if e.removed:
		return
	if leaking and fuel > 0.0:
		var amt := minf(fuel, 4.0 * dt)
		fuel -= amt
		Liquids.spill(e.cell, "fuel", amt)
	if Game.atmos and (Game.atmos.hotspots.has(e.cell) or Liquids.tile_temp(e.cell) > 480.0):
		heat += dt
		if heat > 3.0:
			explode(last_touch)
	else:
		heat = maxf(0.0, heat - dt)

func set_leaking(v: bool) -> void:
	leaking = v
	e.set_sprite("objects", "fuel_tank_open" if leaking else "fuel_tank")

func attackby(user: Entity, item: Entity) -> bool:
	last_touch = user
	var w: CWelder = item.c(&"welder")
	if w:
		if w.lit:
			Game.visible_message(e.cell, "%s holds a lit blowtorch to %s. That was a mistake." % [user.display_name, e.the()], "bad")
			Game.chronicle.add_secret("%s blew up a fuel tank with a lit blowtorch in %s." % [user.display_name, Game.map.area_at(e.cell).name])
			explode(user)
			return true
		var want := minf(w.max_fuel - w.fuel, fuel)
		if want <= 0.0:
			Game.tell(user, "The blowtorch is already full." if fuel > 0 else "The tank is empty.")
			return true
		w.fuel += want
		fuel -= want
		Game.tell(user, "You refill the blowtorch.")
		Sfx.play("pour", e.cell)
		return true
	var it = item.c(&"item")
	if it and it.tool == "wrench":
		set_leaking(not leaking)
		Game.visible_message(e.cell, "%s %s the tap on %s." % [user.display_name, "opens" if leaking else "closes", e.the()], "warn" if leaking else "info")
		if leaking:
			Bus.stimulus.emit({"type": "sabotage", "actor": user, "target": e, "cell": e.cell, "loud": 3.0, "illegal": true})
		Sfx.play("ratchet", e.cell)
		return true
	return false

func take_damage(amount: float, kind: String, source: Entity) -> float:
	if source:
		last_touch = source
	hp -= amount * (2.0 if kind == "burn" else 1.0)
	if hp <= 0.0:
		explode(source)
	elif hp < 30.0 and not leaking:
		set_leaking(true)
		Game.visible_message(e.cell, "%s springs a leak!" % e.the().capitalize(), "warn")
	return 0.0

func explode(cause: Entity) -> void:
	if e.removed:
		return
	var c := e.cell
	var f := fuel
	e.destroy()
	if f < 50.0:
		Fx.explosion(c, 0.5)
		return
	Explosion.explode(c, 0, 1 if f > 300.0 else 0, 2 + int(f / 350.0), cause)
	for d in Defs.DIRS4:
		Liquids.spill(c + d, "fuel", f * 0.02)

func examine(_user: Entity, lines: Array) -> void:
	lines.append("It holds %d units of fuel.%s" % [int(fuel), " [color=#ffb84a]The tap is open and fuel is pouring out![/color]" if leaking else ""])
