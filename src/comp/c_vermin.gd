class_name CVermin extends Component
## Station mice (tg: /mob/living/basic/mouse). They scurry through maintenance, flee
## from people, nibble food left on the floor and chew cables - live ones sometimes
## chew back. Stomp or swat them; janitors will.

const MAX_MICE := 14

var hp := 5.0
var dir := Defs.DIR_E
var think_t := 0.0
var moving := false
var squeak_t := 0.0
var tail := 0
var chewed := 0

func key() -> StringName:
	return &"vermin"

func on_added() -> void:
	think_t = Game.rng.randf_range(0.2, 1.5)
	e.spr.modulate = [Color(1, 1, 1), Color(0.78, 0.66, 0.55), Color(0.62, 0.6, 0.6), Color(1.08, 1.08, 1.08)][Game.rng.randi() % 4]

## Per-frame (LifeSystem).
func process(delta: float) -> void:
	if e.removed:
		return
	think_t -= delta
	if think_t > 0.0:
		return
	think_t = Game.rng.randf_range(0.25, 0.6)
	_think()

func _think() -> void:
	var c := e.cell
	# the cold kills them quickly
	if Liquids.tile_temp(c) < 250.0:
		hp -= 0.6
		if hp <= 0:
			die(null, "froze")
			return
	# scared of people
	var threat: Entity = null
	var best := 99
	for m in Game.in_radius(c, 3, &"mob"):
		var h: CHealth = m.c(&"health")
		if h and h.stat() == CHealth.CONSCIOUS:
			var d: int = m.dist_to(e)
			if d < best:
				best = d
				threat = m
	if threat:
		if squeak_t <= Game.time:
			squeak_t = Game.time + Game.rng.randf_range(4.0, 9.0)
			Sfx.play("squeak", c, 0.5)
			Bus.stimulus.emit({"type": "vermin", "target": e, "cell": c, "loud": 3.0})
		_step_away(threat.cell)
		return
	# food on the floor
	for it in Game.at(c):
		if it != e and it.has_c(&"food") and it.holder == null and Game.rng.randf() < 0.25:
			Game.visible_message(c, "The mouse nibbles on %s." % it.the())
			if Game.rng.randf() < 0.3:
				it.destroy()
			think_t = 2.0
			return
	# cables
	var map := Game.map
	var i := map.idx(c)
	if map.cable[i] == 1 and Game.rng.randf() < 0.035:
		_chew(c)
		return
	if Game.rng.randf() < 0.3:
		think_t = Game.rng.randf_range(1.0, 3.0) # sit and twitch
		return
	_wander()

func _chew(c: Vector2i) -> void:
	var map := Game.map
	map.cable[map.idx(c)] = 2
	Bus.cables_changed.emit()
	chewed += 1
	Bus.stimulus.emit({"type": "cable_burnt", "cell": c, "loud": 0.0})
	if Game.power and Game.power.cell_powered(c) and Game.rng.randf() < 0.5:
		Fx.sparks(c)
		Game.visible_message(c, "The mouse chews through a live cable and is fried!", "warn")
		Bus.chronicle.emit("A mouse chewed through a power cable in %s." % map.area_at(c).name, 1)
		die(null, "shock")
	else:
		Game.visible_message(c, "The mouse gnaws on a cable.")
		think_t = 2.5

func _passable(c: Vector2i) -> bool:
	var map := Game.map
	if not map.inb(c) or map.blocks_move_static(c) or map.dense_count[map.idx(c)] > 0:
		return false
	for x in Game.at(c):
		if x.has_c(&"door") and not x.c(&"door").is_open():
			return false
	return true

func _wander() -> void:
	# mice like to hug walls and stay near cable runs
	var opts := []
	var map := Game.map
	for k in 4:
		var d: Vector2i = Defs.DIRS4[k]
		var n := e.cell + d
		if not _passable(n):
			continue
		var w := 1.0
		if map.cable[map.idx(n)] == 1:
			w += 1.5
		if k == dir:
			w += 2.0
		if map.is_outdoor(n):
			w *= 0.05
		opts.append([d, w])
	if opts.is_empty():
		return
	var total := 0.0
	for o in opts:
		total += o[1]
	var r := Game.rng.randf() * total
	for o in opts:
		r -= o[1]
		if r <= 0:
			_move(o[0])
			return

func _step_away(from: Vector2i) -> void:
	var best_d := Vector2i.ZERO
	var best := -1.0
	for d in Defs.DIRS4:
		var n: Vector2i = e.cell + d
		if not _passable(n):
			continue
		var s := Vector2(n - from).length() + Game.rng.randf() * 0.4
		if s > best:
			best = s
			best_d = d
	if best_d != Vector2i.ZERO:
		think_t = 0.12
		_move(best_d, 0.12)

func _move(d: Vector2i, dur := 0.22) -> void:
	dir = Defs.dir_from_vec(d)
	tail ^= 1
	var nm: String = ["mouse_n", "mouse_e", "mouse_s", "mouse_w"][dir]
	if (dir == Defs.DIR_E or dir == Defs.DIR_W) and tail == 1:
		nm += "_1"
	e.set_sprite("objects", nm)
	Interact.glide(e, e.cell + d, dur)

func take_damage(amount: float, kind: String, source: Entity) -> float:
	hp -= amount
	if hp <= 0:
		die(source, kind)
	return 0.0

func die(killer: Entity, how := "") -> void:
	if e.removed:
		return
	var c := e.cell
	Sfx.play("squeak", c, 0.8)
	if how != "shock" and how != "froze" and killer:
		Game.visible_message(c, "%s squashes the mouse." % killer.display_name, "info")
	Bus.stimulus.emit({"type": "vermin_killed", "actor": killer, "cell": c, "loud": 0.0})
	var corpse := Proto.spawn("mouse_dead", c)
	corpse.spr.modulate = e.spr.modulate
	e.destroy()

func attack_hand(user: Entity) -> bool:
	var m: CMob = user.c(&"mob")
	if m and m.combat:
		die(user)
		return true
	if Game.rng.randf() < 0.6:
		Game.tell(user, "The mouse slips out of your grasp!")
		_step_away(user.cell)
	else:
		Game.tell(user, "You pet the mouse. It squeaks indignantly.")
	return true

func attackby(user: Entity, item: Entity) -> bool:
	var it = item.c(&"item")
	if it and it.force >= 3.0:
		if Game.rng.randf() < 0.7:
			die(user)
		else:
			Game.visible_message(e.cell, "%s swings at the mouse and misses!" % user.display_name)
			_step_away(user.cell)
		return true
	return false

func examine(_user: Entity, lines: Array) -> void:
	if chewed > 0:
		lines.append("Its whiskers are singed.")

func ai_tags(out: Dictionary) -> void:
	out["vermin"] = true

## Spawns `n` mice in maintenance-ish areas, respecting the population cap.
static func infest(n: int) -> int:
	var have := Game.all_with(&"vermin").size()
	var spots := []
	for a in Game.map.areas:
		if a.name.begins_with("Maintenance") or a.name.begins_with("Custodial") or a.name.contains("Storage"):
			for c in a.cells:
				if Game.map.is_passable(c):
					spots.append(c)
	if spots.is_empty():
		return 0
	var made := 0
	var origin: Vector2i = spots[Game.rng.randi() % spots.size()]
	for k in n:
		if have + made >= MAX_MICE:
			break
		var c: Vector2i = origin
		for tries in 10:
			var cand := origin + Vector2i(Game.rng.randi_range(-3, 3), Game.rng.randi_range(-3, 3))
			if Game.map.is_passable(cand):
				c = cand
				break
		Proto.spawn("mouse", c)
		made += 1
	return made
