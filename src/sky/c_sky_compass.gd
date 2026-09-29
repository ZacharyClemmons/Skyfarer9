class_name CSkyCompass extends Component
## An aether compass. The needle ignores north and points at the nearest land, which is
## the only bearing that matters when the cloud closes in.

## A liar's compass gets it wrong about one time in five, and the wrong answer is an
## island nobody has been to. Skyfarers keep them for exactly that reason.
var liar := false

func key() -> StringName:
	return &"skycompass"

func setup(p: Dictionary) -> CSkyCompass:
	liar = bool(p.get("liar", false))
	return self

func attack_self(user: Entity) -> bool:
	_read(user)
	return true

func _read(user: Entity) -> void:
	if Game.sky == null or Game.sky.gen == null:
		Game.tell(user, "The needle turns and turns and will not settle.")
		return
	var from := user.root_cell()
	var best: Dictionary = {}
	var bd := 1e9
	if liar and Game.rng.randf() < 0.2 and Game.sky.gen.islands.size() > 1:
		# it lies, confidently, and points somewhere worth going instead
		var pool: Array = Game.sky.gen.islands.filter(func(i): return not i.get("home", false))
		if not pool.is_empty():
			best = pool[Game.rng.randi() % pool.size()]
			bd = Vector2(best["area"].center - from).length()
			Game.tell(user, "[color=#c88ae8]The needle swings, settles, and looks perfectly certain.[/color]")
	for isl in Game.sky.gen.islands:
		if not best.is_empty():
			break
		var d: float = Vector2(isl["area"].center - from).length()
		if d < bd:
			bd = d
			best = isl
	if best.is_empty():
		Game.tell(user, "The needle spins. There is no land in this sky.")
		return
	var v := Vector2(best["area"].center - from)
	Game.tell(user, "[b]%s[/b] — %s, about %d tiles off. (%s)" % [
		best["name"], _bearing(v), int(bd), best["b"]["name"]])
	Sfx.play("ui_tick", user.cell, 0.4)
	Skills.add_xp(user, "navigation", 4.0)

static func _bearing(v: Vector2) -> String:
	if v.length() < 0.5:
		return "you are standing on it"
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return names[int(round(fposmod(rad_to_deg(v.angle()), 360.0) / 45.0)) % 8]

func examine(user: Entity, lines: Array) -> void:
	lines.append("[i]Use it in your hands to take a bearing.[/i]")
	if Game.sky != null:
		lines.append("Wind: %s from the %s." % [Game.sky.wind_name(), Game.sky._from(Game.sky.wind_dir_name())])
