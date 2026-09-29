class_name CGlider extends Component
## A folded glider in a back harness. Pull the ring and you stop falling and start
## flying — badly, downward, but under your own control, which in the Cloudsea is the
## whole difference between an accident and a manoeuvre.
##
## Deploying while falling is the save. Deploying on purpose off a rail is how you get
## down to an island your ship cannot moor at.

const GLIDE_TIME := 26.0 # seconds of canopy before the cane spars give up

var open := false
var left := 0.0

func key() -> StringName:
	return &"glider"

func wearer() -> Entity:
	var h := e.holder
	return h if h != null and h.has_c(&"mob") else null

func attack_self(user: Entity) -> bool:
	if open:
		_furl(user)
	else:
		_deploy(user)
	return true

func _deploy(user: Entity) -> void:
	var inv: CInventory = user.c(&"inv")
	if inv == null or inv.worn("back") != e:
		Game.tell(user, "You have to be wearing the harness to pull the ring.", "warn")
		return
	open = true
	left = GLIDE_TIME
	e.tags["glider_open"] = true
	e.display_name = "glider harness (deployed)"
	Game.tell(user, "[b]You pull the ring.[/b] Silk cracks open above you and the fall turns into a long, shallow slide.", "good")
	Game.visible_message(user.cell, "%s's glider snaps open." % user.display_name, "emote")
	Sfx.play("whoosh", user.cell, 0.9)
	Skills.add_xp(user, "evasion", 12.0)

func _furl(user: Entity) -> void:
	open = false
	left = 0.0
	e.tags.erase("glider_open")
	e.display_name = "glider harness"
	Game.tell(user, "You spill the canopy and gather the silk in.")

func process(delta: float) -> void:
	if not open:
		return
	left -= delta
	var w := wearer()
	if w == null:
		return
	# glide: you drift downwind while the canopy holds
	if Game.sky != null and Game.rng.randf() < delta * 1.4:
		var v: Vector2 = Game.sky.wind_vector()
		if v.length() > 0.15:
			var d := Vector2i(roundi(clampf(v.x, -1.0, 1.0)), roundi(clampf(v.y, -1.0, 1.0)))
			var m: CMob = w.c(&"mob")
			if m != null and d != Vector2i.ZERO:
				m.try_step(d)
	if left <= 0.0:
		open = false
		e.tags.erase("glider_open")
		e.display_name = "spent glider harness"
		Game.tell(w, "[color=#ff8a5a]The spars fold. The canopy goes limp.[/color]", "bad")
		Falling.check(w)

func examine(_user: Entity, lines: Array) -> void:
	if open:
		lines.append("[b]Deployed.[/b] About %d seconds of canopy left." % int(left))
	else:
		lines.append("Folded and ready. Use it in your hands, or while falling, to pull the ring.")
