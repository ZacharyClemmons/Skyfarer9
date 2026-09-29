class_name CAetherGun extends Component
## A held aether weapon: pistol, carbine, scattergun.
##
## It fires charge rather than cartridges, which is the only reason a skyfarer can carry
## a gun at all — powder does not keep at altitude and nobody wants an open flame on a
## wooden ship. A skyglass cell holds the shots; an aetherite ingot or a lightning strike
## refills it.
##
## Marksmanship decides whether the bolt goes where you pointed. At level one the spread
## is wide enough that a scattergun is the honest choice; at mastery a carbine will take
## the wing off a raptor at twelve tiles.

var damage := 24.0
var reach := 7
var reload := 3.4
var cost := 1
var pierce := 0
var pellets := 1

var cell_charge := 12
var cell_max := 12
var cool := 0.0

func key() -> StringName:
	return &"aethergun"

func setup(p: Dictionary) -> CAetherGun:
	damage = float(p.get("damage", damage))
	reach = int(p.get("reach", reach))
	reload = float(p.get("reload", reload))
	cost = int(p.get("cost", cost))
	pierce = int(p.get("pierce", pierce))
	pellets = int(p.get("pellets", pellets))
	cell_max = int(p.get("cell", 12))
	cell_charge = cell_max
	return self

func process(delta: float) -> void:
	if cool > 0.0:
		cool = maxf(0.0, cool - delta)

func examine(_user: Entity, lines: Array) -> void:
	lines.append("Charge: [b]%d / %d[/b].  %d damage, %d tiles.%s" % [
		cell_charge, cell_max, int(damage), reach,
		"  [color=#9ad8ff]Punches through %d.[/color]" % pierce if pierce > 0 else ""])
	if pellets > 1:
		lines.append("[color=#e8a83a]Throws %d pellets in a cone. Deadly close, useless far.[/color]" % pellets)
	if cell_charge < cost:
		lines.append("[color=#ff6a6a]Flat. Feed it an aetherite ingot or a skyglass lens.[/color]")

# ------------------------------------------------------------------ firing
func use_on_cell(user: Entity, c: Vector2i) -> bool:
	return fire(user, c)

func use_on(user: Entity, target: Entity) -> bool:
	return fire(user, target.root_cell())

func fire(user: Entity, at: Vector2i) -> bool:
	if cool > 0.0:
		Game.tell(user, "Still charging.", "warn")
		return true
	if cell_charge < cost:
		Game.tell(user, "[color=#ff6a6a]Flat.[/color]", "warn")
		Sfx.play("click", user.root_cell(), 0.5)
		return true
	var from := user.root_cell()
	var d := Vector2(at - from)
	if d.length() < 0.01:
		return true
	if d.length() > reach + 0.5:
		Game.tell(user, "Too far — it throws about %d tiles." % reach, "warn")
		return true
	cell_charge -= cost
	var skill := Skills.frac(user, "marksman")
	cool = reload * (1.0 - skill * 0.4)
	# spread: two thirds of it goes away between level 1 and mastery
	var spread := (0.30 if pellets > 1 else 0.16) * (1.0 - skill * 0.66)
	Sfx.play("gunshot", from, 0.55)
	Fx.sparks(from)
	Game.visible_message(from, "[b]%s fires %s.[/b]" % [user.display_name.capitalize(), e.the()], "combat")
	var base := d.angle()
	for _i in maxi(1, pellets):
		var a := base + Game.rng.randf_range(-spread, spread)
		var aim := from + Vector2i(Vector2(cos(a), sin(a)) * d.length())
		_bolt(user, from, aim)
	Skills.add_xp(user, "marksman", 9.0)
	Bus.stimulus.emit({"type": "gunshot", "actor": user, "cell": from, "loud": 16.0})
	return true

func _bolt(user: Entity, from: Vector2i, to: Vector2i) -> void:
	var through := 0
	var last := from
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	for k in range(1, steps + 1):
		var t := float(k) / float(maxi(1, steps))
		var c := Vector2i(roundi(lerpf(from.x, to.x, t)), roundi(lerpf(from.y, to.y, t)))
		if not Game.map.inb(c):
			break
		last = c
		var stopped := false
		for ent in Game.at(c).duplicate():
			if ent == user:
				continue
			var h: CHealth = ent.c(&"health")
			if h != null and not h.dead:
				var dealt := damage * Game.rng.randf_range(0.85, 1.15) / float(maxi(1, pellets))
				h.take_damage(dealt, "burn", user)
				Game.visible_message(c, "[b]The bolt takes %s.[/b]" % ent.display_name, "combat")
				Fx.sparks(c)
				through += 1
				if through > pierce:
					stopped = true
				break
		if stopped:
			break
		if Game.map.is_solid_turf(c) or Game.map.structure[Game.map.idx(c)] != Defs.S_NONE:
			Fx.sparks(c)
			break
	Fx.beam(from, last, Color("#9ad8ff"))

# ------------------------------------------------------------------ recharging
func attackby(user: Entity, item: Entity) -> bool:
	var give := 0
	match item.proto:
		"aether_ingot": give = cell_max
		"skyglass_lens": give = cell_max
		"ore_aetherite": give = maxi(2, cell_max / 3)
		"storm_glass": give = cell_max * 2
	if give <= 0:
		return false
	if cell_charge >= cell_max:
		Game.tell(user, "It is already full.")
		return true
	cell_charge = mini(cell_max, cell_charge + give)
	var st: CStack = item.c(&"stack")
	if st != null and st.amount > 1:
		st.amount -= 1
	else:
		item.destroy()
	Game.tell(user, "You feed the cell. Charge: %d / %d." % [cell_charge, cell_max])
	Sfx.play("shimmer", user.root_cell(), 0.5)
	Skills.add_xp(user, "artifice", 5.0)
	return true

## A charged storm tops up every aether cell aboard. Being in the weather has an upside.
func storm_charge(amount: int) -> void:
	cell_charge = mini(cell_max, cell_charge + amount)
