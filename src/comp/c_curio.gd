class_name CCurio extends Component
## The interesting drawer, made real.
##
## One component covers every curio because the shape is always the same: a thing you
## activate, or wear, and a named effect. Keeping them together means each one is four
## lines rather than a file, and it means the list of what a curio can do is readable in
## one place — which is the only way to keep them feeling like a set rather than a pile.

var effect := ""
var uses := -1 # -1 for unlimited
var cooldown := 0.0
var _passive_t := 0.0

func key() -> StringName:
	return &"curio"

func setup(p: Dictionary) -> CCurio:
	effect = String(p.get("effect", ""))
	uses = int(p.get("uses", -1))
	return self

func examine(user: Entity, lines: Array) -> void:
	if uses >= 0:
		lines.append("[color=#7fd4ff]%d use%s left.[/color]" % [uses, "" if uses == 1 else "s"])
	if cooldown > 0.0:
		lines.append("[color=#e8a83a]Not ready for another %.0f seconds.[/color]" % cooldown)
	match effect:
		"shriek": lines.append("[i]Z rings it. Think first.[/i]")
		"sink": lines.append("[i]While it is in your hands you cannot fall and cannot run.[/i]")
		"boil": lines.append("[i]Use it on something raw.[/i]")
		"updraft": lines.append("[i]Z pulls the ring.[/i]")
		"echo": lines.append("[i]Z listens.[/i]")
		"stars": lines.append("[i]Z throws a pinch at your feet.[/i]")
		"anchor": lines.append("[i]Worn: the aether wind does not touch you.[/i]")
		"ledger": lines.append("[i]Z reads it. Carrying it shows every port's wants on the nav.[/i]")
		"thinking": lines.append("[i]Worn: you learn faster, and you cannot keep a thought to yourself.[/i]")
		"lung": lines.append("[i]Worn: bad air and thin air stop mattering.[/i]")
		"chart": lines.append("[i]Worn: what you look at is charted.[/i]")

# ------------------------------------------------------------------ passive effects
## Worn curios are ticked by LifeSystem through Game.all_with(&"curio"), so a charm in a
## crate on an island does nothing and the same charm round your neck does.
func process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	var wearer := _wearer()
	if wearer == null:
		return
	_passive_t -= delta
	if _passive_t > 0.0:
		return
	_passive_t = 2.0
	# Worn effects are re-applied on a short timer rather than set as a flag, so taking
	# the thing off puts the world back without anyone having to remember to.
	match effect:
		"sink":
			# not falling, at the price of not hurrying
			SkyBuffs.apply(wearer, "no_fall", 1.0, 3.0, "sink")
			SkyBuffs.apply(wearer, "slow", 0.7, 3.0, "sink")
		"anchor":
			SkyBuffs.apply(wearer, "wind_immune", 1.0, 3.0, "anchor")
		"thinking":
			SkyBuffs.apply(wearer, "xp", 1.25, 3.0, "cap")
			if Game.rng.randf() < 0.05:
				_blurt(wearer)
		"lung":
			SkyBuffs.apply(wearer, "good_air", 1.0, 3.0, "lung")
			SkyBuffs.apply(wearer, "altitude", 1.0, 3.0, "lung")
		"chart":
			SkyBuffs.apply(wearer, "sight", 4.0, 3.0, "eye")
			_chart_nearby(wearer)
		"ledger":
			SkyBuffs.apply(wearer, "luck", 0.1, 3.0, "ledger")

func _wearer() -> Entity:
	var h := e.holder
	if h == null:
		return null
	# only counts if it is actually worn or in hand, not buried in a crate on the deck
	if h.has_c(&"mob"):
		return h
	return null

const BLURTS = [
	"I could sell that.", "That is load-bearing and I do not like it.",
	"Three days of fuel. Four if the wind holds.", "Do not look at it, do not look at it.",
	"If I fell from here I would have about nine seconds.", "Somebody died making this.",
	"I should have bought the bigger bunker.", "That noise is new.",
]

func _blurt(who: Entity) -> void:
	var m: CMob = who.c(&"mob")
	if m != null:
		m.say(BLURTS[Game.rng.randi() % BLURTS.size()])

func _chart_nearby(who: Entity) -> void:
	if Game.sky == null or Game.sky.gen == null:
		return
	for isl in Game.sky.gen.islands:
		if isl.get("charted", false):
			continue
		var c: Vector2i = isl["center"]
		if who.cell.distance_squared_to(c) < 42 * 42:
			isl["charted"] = true
			Game.tell(who, "[color=#7fd4ff]You add %s to your chart.[/color]" % isl["name"], "good")
			Skills.add_xp(who, "navigation", 45.0)

# ------------------------------------------------------------------ activation
func attack_self(user: Entity) -> bool:
	if cooldown > 0.0:
		Game.tell(user, "Not yet.", "warn")
		return true
	if uses == 0:
		Game.tell(user, "It is spent.", "warn")
		return true
	var used := true
	match effect:
		"shriek": _shriek(user)
		"updraft": _updraft(user)
		"echo": _echo(user)
		"stars": _stars(user)
		"ledger": _ledger(user)
		_: used = false
	if not used:
		return false
	if uses > 0:
		uses -= 1
		if uses == 0:
			Game.tell(user, "That was the last of it.")
	return true

## Everything on the island comes to look. There is a use for this.
func _shriek(user: Entity) -> void:
	cooldown = 90.0
	Game.visible_message(user.cell, "[b][color=#ff8a5a]The bell shrieks — a note you feel in your teeth.[/color][/b]", "bad")
	Sfx.play("alarm", user.cell, 1.0)
	if Game.view:
		Game.view.shake(4.0)
	var n := 0
	for other in Game.in_radius(user.cell, 34, &"beastai"):
		var ai: CBeastAI = other.c(&"beastai")
		if ai == null:
			continue
		ai.target = user
		ai.last_seen = Game.time
		ai.hidden = false
		ai.alert = 1.0
		other.modulate = Color.WHITE
		n += 1
	Bus.stimulus.emit({"type": "loud_noise", "actor": user, "cell": user.cell, "loud": 40.0})
	Game.tell(user, "[color=#e8a83a]%d thing%s heard that.[/color]" % [n, "" if n == 1 else "s"], "warn")
	Skills.add_xp(user, "beastlore", 20.0)

## Forty feet up, and then forty feet down.
func _updraft(user: Entity) -> void:
	cooldown = 12.0
	Sfx.play("spray", user.cell, 0.9)
	Fx.smoke_puff(user.cell)
	Game.visible_message(user.cell, "[b]The air under %s goes hard.[/b]" % user.display_name, "warn")
	# a launch is a rescue if you are falling and a jump if you are not
	if bool(user.tags.get("falling", false)):
		var to := _ground_near(user.cell, 8)
		if to.x > -9000:
			Falling.rescue(user, to)
			Game.tell(user, "[color=#6ad88a]The blast throws you clear and you land, hard.[/color]", "good")
			return
	var dir: Vector2i = Defs.DIRS4[user.c(&"mob").dir] if user.has_c(&"mob") else Vector2i.ZERO
	var land := user.cell
	for k in range(1, 5):
		var c: Vector2i = user.cell + dir * k
		if Game.map.inb(c) and Falling.supported(c) and Game.map.is_passable(c):
			land = c
	user.place(land)
	Skills.add_xp(user, "athletics", 14.0)

func _ground_near(from: Vector2i, r: int) -> Vector2i:
	for rad in range(1, r + 1):
		for y in range(-rad, rad + 1):
			for x in range(-rad, rad + 1):
				if maxi(absi(x), absi(y)) != rad:
					continue
				var c: Vector2i = from + Vector2i(x, y)
				if Falling.supported(c) and Game.map.is_passable(c):
					return c
	return Vector2i(-9999, -9999)

## What is about to be here.
func _echo(user: Entity) -> void:
	cooldown = 30.0
	var threats := []
	for other in Game.in_radius(user.cell, 22, &"beastai"):
		var ai: CBeastAI = other.c(&"beastai")
		if ai != null and ai.damage > 0.0:
			threats.append(other)
	if threats.is_empty():
		Game.tell(user, "[i]Wind. Only wind, and a long way down.[/i]")
		return
	threats.sort_custom(func(a, b): return user.cell.distance_squared_to(a.cell) < user.cell.distance_squared_to(b.cell))
	var t: Entity = threats[0]
	var d := Vector2(t.cell - user.cell)
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	var word: String = names[int(round(fposmod(rad_to_deg(d.angle()), 360.0) / 45.0)) % 8]
	Game.tell(user, "[color=#c88ae8]You hear it before it happens: %s, to the %s, %d paces.[/color]" % [
		t.display_name, word, int(d.length())], "warn")
	if threats.size() > 1:
		Game.tell(user, "[color=#c88ae8]And %d more behind it.[/color]" % (threats.size() - 1), "warn")
	Skills.add_xp(user, "beastlore", 12.0)

## Light, thrown.
func _stars(user: Entity) -> void:
	cooldown = 2.0
	var c := user.cell
	var lit := Proto.spawn("star_dust", c) if Proto.has("star_dust") else null
	if lit == null:
		var g := Entity.new()
		g.proto = "star_dust"
		g.display_name = "scattered starlight"
		g.cell = c
		g.position = Entity.cell_to_pos(c)
		g.z_index = -1
		Game.ents_node.add_child(g)
		Game.register(g)
		var l := CLight.new().setup({"kind": "always", "radius": 5.5, "color": "#d8e8ff", "energy": 0.95})
		g.add(l)
		if Game.lighting:
			Game.lighting.register(l)
		lit = g
	Sfx.play("spray", c, 0.4)
	Game.visible_message(c, "The flakes catch and hold, burning cold.", "info")
	# it fades
	var tree: SceneTree = Game.hud.get_tree() if Game.hud != null else null
	if tree != null and is_instance_valid(lit):
		var t: SceneTreeTimer = tree.create_timer(60.0)
		t.timeout.connect(func():
			if is_instance_valid(lit) and not lit.removed:
				lit.destroy())

## The accounts.
func _ledger(user: Entity) -> void:
	cooldown = 4.0
	if Game.sky == null or Game.sky.gen == null:
		return
	var lines := []
	for isl in Game.sky.gen.islands:
		if not isl.has("port"):
			continue
		var b: String = isl["biome"]
		var hint := Economy.port_hint(b)
		if hint != "":
			lines.append("[b]%s[/b] — %s" % [isl["name"], hint])
	if lines.is_empty():
		Game.tell(user, "[i]Every page in it is about ports that are not in this sky.[/i]")
		return
	Game.tell(user, "[color=#e8c85a]The ledger says:[/color]", "info")
	for l in lines.slice(0, 8):
		Game.tell(user, "  " + l, "info")
	Skills.add_xp(user, "trading", 16.0)

# ------------------------------------------------------------------ used on things
func use_on(user: Entity, target: Entity) -> bool:
	if effect != "boil":
		return false
	var f: CFood = target.c(&"food")
	if f == null:
		Game.tell(user, "The flask does nothing interesting to that.")
		return true
	if target.proto.begins_with("food_") and not target.proto.ends_with("_raw") and not target.proto == "meat_raw":
		Game.tell(user, "It is already cooked.")
		return true
	DoAfter.start(user, target, 1.0, func(ok: bool):
		if not ok:
			return
		var out := "food_meat" if target.proto == "meat_raw" else target.proto
		var made := Proto.spawn(out, user.root_cell()) if Proto.has(out) else null
		if made != null:
			target.destroy()
			Game.tell(user, "It boils, instantly, and smells rather better than it did.")
			Skills.add_xp(user, "cooking", 12.0)
		Sfx.play("pour", user.root_cell(), 0.6))
	return true
