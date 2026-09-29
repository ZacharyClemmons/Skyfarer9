class_name Hallucinations extends RefCounted
## tg hallucinations (code/modules/hallucination, datums/status_effects/debuffs/hallucination).
## The "hallucination" status is a duration; while it lasts, every 20-80 s (faster and wilder
## the more of it is left) a weighted-random hallucination from tg's pool starts. Most are
## only in the hallucinator's head, so their visuals and sounds are made for the player
## alone; the ones that do something to the body (shocks, freezing, fake death, bullets
## that knock the wind out of you) work on anyone.

const TIER_COMMON := 1
const TIER_UNCOMMON := 2
const TIER_RARE := 3
const TIER_VERYSPECIAL := 4

## id: [weight (tg random_hallucination_weight summed over its subtypes), tier]
const POOL := {
	"chat": [100.0, TIER_COMMON],
	"message": [60.0, TIER_COMMON],
	"sound": [67.0, TIER_COMMON], # 13 fake_sound/normal subtypes x5 + flash 2
	"health_doll": [12.0, TIER_COMMON],
	"fake_alert": [13.0, TIER_COMMON],
	"battle": [18.0, TIER_COMMON],
	"bolts": [7.0, TIER_COMMON],
	"screwy_hud": [12.0, TIER_COMMON],
	"body": [16.0, TIER_COMMON],
	"telepathy": [4.0, TIER_COMMON],
	"ice": [3.0, TIER_COMMON],
	"blood_flow": [3.0, TIER_COMMON],
	"eyes_in_dark": [2.0, TIER_COMMON],
	"shock": [1.0, TIER_COMMON],
	"malf_apc": [5.0, TIER_COMMON],
	"fake_flood": [7.0, TIER_UNCOMMON],
	"stray_bullet": [7.0, TIER_UNCOMMON],
	"hazard": [15.0, TIER_UNCOMMON],
	"delusion": [20.0, TIER_UNCOMMON],
	"fire": [3.0, TIER_UNCOMMON],
	"death": [1.0, TIER_UNCOMMON],
	"station_message": [7.0, TIER_RARE],
	"xeno_sound": [2.0, TIER_RARE],
}

const LOWER_TICK := 20.0
const UPPER_TICK := 80.0

static var _strings := {}

static func _data() -> void:
	if not _strings.is_empty():
		return
	var f := FileAccess.open("res://assets/data/tg/hallucination.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else {}
	_strings = d if d is Dictionary else {"advice": ["..."]}

## tg pick_list_replacements(HALLUCINATION_FILE, key)
static func line(key: String, who: Entity = null) -> String:
	_data()
	var list: Array = _strings.get(key, [])
	if list.is_empty():
		return ""
	var s: String = list[Game.rng.randi() % list.size()]
	var re := RegEx.create_from_string("@pick\\(([a-z_]+)\\)")
	var m := re.search(s)
	var guard := 0
	while m and guard < 8:
		s = s.substr(0, m.get_start()) + line(m.get_string(1), who) + s.substr(m.get_end())
		m = re.search(s)
		guard += 1
	if who:
		s = s.replace("%TARGETNAME%", who.display_name.get_slice(" ", 0))
	return s

## tg adjust_hallucinations
static func adjust(h: CHealth, amount: float, max_t := 3600.0) -> void:
	h.adjust_status("hallucination", amount, max_t)

# ------------------------------------------------------------------ the status effect
## tg /datum/status_effect/hallucination/tick (every 2 s in tg; the cooldown is what matters)
static func tick(h: CHealth, _dt: float) -> void:
	_tick_active(h)
	if h.dead or not h.has_status("hallucination"):
		return
	if Game.time < h.get_meta("hallu_cd", 0.0):
		return
	var lower := LOWER_TICK
	var upper := UPPER_TICK
	var left := h.status_left("hallucination")
	var tier := TIER_COMMON
	if left <= 20.0:
		tier = TIER_COMMON
	elif left <= 60.0:
		tier = TIER_RARE if Body.prob(10) else TIER_UNCOMMON
	elif left <= 120.0:
		tier = TIER_RARE
		lower *= 0.75
		upper *= 0.75
	else:
		tier = TIER_VERYSPECIAL
		lower *= 0.5
		upper *= 0.5
	var id := _pick(tier)
	if not cause(h, id):
		lower *= 0.25
		upper *= 0.25
	h.set_meta("hallu_cd", Game.time + Game.rng.randf_range(lower, upper))

static func _pick(max_tier: int) -> String:
	var total := 0.0
	for id in POOL:
		if POOL[id][1] <= max_tier:
			total += POOL[id][0]
	var r := Game.rng.randf() * total
	for id in POOL:
		if POOL[id][1] <= max_tier:
			r -= POOL[id][0]
			if r <= 0.0:
				return id
	return "chat"

## tg cause_hallucination: start one. Returns false if it couldn't happen here.
static func cause(h: CHealth, id: String) -> bool:
	var e := h.e
	var player := e == Game.player
	match id:
		"chat": return _chat(h) if player else false
		"message": return _message(h) if player else false
		"sound": return _sound(h) if player else false
		"health_doll", "screwy_hud":
			if not player:
				return false
			var kinds := ["hurt"] if id == "health_doll" else ["crit", "dead", "healthy"]
			h.set_meta("screwy_hud", kinds[Game.rng.randi() % kinds.size()])
			h.set_meta("screwy_hud_until", Game.time + (50.0 if id == "health_doll" else Game.rng.randf_range(10.0, 25.0)))
			return true
		"fake_alert":
			if not player:
				return false
			var al: Array = [["oxy", "CHOKING (THIN AIR)"], ["plasma", "CHOKING (PLASMA)"], ["fire", "ON FIRE"], ["hot", "TOO HOT"], ["cold", "TOO COLD"], ["lowpressure", "LOW PRESSURE"], ["highpressure", "HIGH PRESSURE"]][Game.rng.randi() % 7]
			h.set_meta("fake_alert", al)
			h.set_meta("fake_alert_until", Game.time + Game.rng.randf_range(10.0, 25.0))
			return true
		"battle": return _battle(h) if player else false
		"bolts": return _bolts(h) if player else false
		"body": return _body(h) if player else false
		"telepathy":
			Game.tell(e, "[b]You hear a voice in your head...[/b] [i]%s[/i]" % line(["advice", "aggressive", "conversation", "didyouhearthat", "doubt", "escape", "getout", "greetings", "suspicion"][Game.rng.randi() % 9], e), "info")
			return true
		"ice":
			Game.tell(e, "[b]You become frozen in a cube![/b]", "bad")
			h.immobilize(6.0)
			h.set_status_if_lower("jitter", 12.0)
			h.set_status_if_lower("stutter", 12.0)
			if player:
				h.set_meta("fake_alert", ["cold", "TOO COLD"])
				h.set_meta("fake_alert_until", Game.time + 12.0)
				_ice_cube(e, 6.0)
			return true
		"blood_flow": return _blood_flow(h)
		"eyes_in_dark": return _eyes(h) if player else false
		"shock":
			Game.tell(e, "[b]You feel a powerful shock course through your body![/b]", "bad")
			Game.visible_message(e.cell, "%s falls to the ground, shaking!" % e.display_name, "warn")
			Sfx.play("spark", e.cell)
			h.adjust("stamina", 50.0)
			h.stun(4.0)
			h.adjust_status("jitter", 20.0)
			_later(h, 2.0, "shock_drop")
			return true
		"malf_apc": return _malf_apc(h) if player else false
		"fake_flood": return _flood(h) if player else false
		"stray_bullet": return _stray_bullet(h)
		"hazard": return _hazard(h) if player else false
		"delusion": return _delusion(h) if player else false
		"fire":
			Game.tell(e, "[b]You're set on fire![/b]", "bad")
			h.set_meta("fake_fire", Game.rng.randf_range(5.0, 15.0))
			h.set_meta("fake_fire_stam", Game.rng.randi_range(5, 10))
			if player:
				Fx.flame_on(e)
				h.set_meta("fake_alert", ["fire", "ON FIRE"])
				h.set_meta("fake_alert_until", Game.time + 15.0)
			return true
		"death":
			if h.knocked_out():
				return false
			h.paralyze(30.0)
			h.set_meta("screwy_hud", "dead")
			h.set_meta("screwy_hud_until", Game.time + 30.0)
			h.set_status("fake_death_mute", 9.0)
			if player:
				Game.hud.add_line("[color=#b8a8ff][b]%s[/b] has died at [b]%s[/b].[/color]" % [e.display_name, Game.map.area_at(e.cell).name], "announce")
			_later(h, Game.rng.randf_range(7.0, 9.0), "wake_from_death")
			return true
		"station_message": return _station_message(h) if player else false
		"xeno_sound":
			if not player:
				return false
			var c := _far_cell(e)
			for i in 3:
				_later_sound(h, "squeak", c, i * 0.8)
			return true
	return false

## Delayed parts of hallucinations (tg addtimer callbacks), run from tick.
static func _later(h: CHealth, delay: float, what: String) -> void:
	var q: Array = h.get_meta("hallu_later", [])
	q.append([Game.time + delay, what])
	h.set_meta("hallu_later", q)

static func _later_sound(h: CHealth, snd: String, c: Vector2i, delay: float) -> void:
	var q: Array = h.get_meta("hallu_later", [])
	q.append([Game.time + delay, "sound:" + snd, c])
	h.set_meta("hallu_later", q)

static func _tick_active(h: CHealth) -> void:
	var e := h.e
	# delayed steps
	if h.has_meta("hallu_later"):
		var q: Array = h.get_meta("hallu_later")
		var keep := []
		for it in q:
			if Game.time < it[0]:
				keep.append(it)
				continue
			var what: String = it[1]
			if what == "shock_drop":
				h.paralyze(6.0)
			elif what == "wake_from_death":
				h.remove_status("paralyzed")
				h.remove_meta("screwy_hud")
				h.remove_status("fake_death_mute")
			elif what.begins_with("sound:") and e == Game.player:
				Sfx.play(what.substr(6), it[2], 0.6)
		if keep.is_empty():
			h.remove_meta("hallu_later")
		else:
			h.set_meta("hallu_later", keep)
	# tg fire hallucination: the fake fire burns down, and knocks the wind out of you
	if h.has_meta("fake_fire"):
		var ff: float = h.get_meta("fake_fire") - 0.25
		var st: int = h.get_meta("fake_fire_stam", 0)
		if st > 0:
			h.adjust("stamina", 15.0)
			h.set_meta("fake_fire_stam", st - 1)
		if ff <= 0.0 or h.dead:
			h.remove_meta("fake_fire")
			h.remove_meta("fake_fire_stam")
			if e == Game.player and h.on_fire <= 0.0:
				Fx.flame_off(e)
		else:
			h.set_meta("fake_fire", ff)
	# tg blood_flow: the fake bleeding tires you out
	if h.has_meta("fake_bleed_until"):
		if Game.time > h.get_meta("fake_bleed_until"):
			h.remove_meta("fake_bleed_until")
			h.remove_meta("fake_bleed_part")
		elif Body.prob(40):
			h.adjust("stamina", 5.0)
	for k in ["screwy_hud", "fake_alert"]:
		if h.has_meta(k + "_until") and Game.time > h.get_meta(k + "_until"):
			h.remove_meta(k)
			h.remove_meta(k + "_until")
	if h.has_meta("delusion_until") and Game.time > h.get_meta("delusion_until"):
		_end_delusion(h)

## The HUD's view of the hallucinator's health (tg screwy_hud: fake crit, dead, healthy),
## or "" for the truth. Anosognosia always says healthy.
static func screwy(h: CHealth) -> String:
	if h.has_meta("screwy_hud"):
		return h.get_meta("screwy_hud")
	if (not h.traumas.is_empty() and Traumas.has(h, "healthy")) or Quirks.has(h.e, "numb"):
		return "healthy"
	return ""

# ------------------------------------------------------------------ the hallucinations
static func _others_in_view(e: Entity, r := 7) -> Array:
	return Game.in_radius(e.cell, r, &"mob").filter(func(x): return x != e and not x.removed and (Game.lighting == null or Game.lighting.player_can_see(x.cell)))

## tg /datum/hallucination/chat
static func _chat(h: CHealth) -> bool:
	if h.knocked_out():
		return false
	var e := h.e
	var living := []
	var corpses := []
	for x in _others_in_view(e):
		var xh: CHealth = x.c(&"health")
		if xh and xh.dead:
			corpses.append(x)
		elif xh:
			living.append(x)
	var speaker: Entity = null
	if not living.is_empty():
		speaker = living[Game.rng.randi() % living.size()]
	elif not corpses.is_empty():
		speaker = corpses[Game.rng.randi() % corpses.size()]
	var radio := speaker == null
	if radio:
		var crew := Game.all_with(&"mob").filter(func(x): return x != e and x.has_c(&"health") and not x.c(&"health").dead)
		if crew.is_empty():
			return false
		speaker = crew[Game.rng.randi() % crew.size()]
	var who := e.display_name.get_slice(" ", 0)
	var chosen := ""
	if radio:
		chosen = ["Help!", "Help %s%s" % [line("location"), "!" if Body.prob(50) else "!!"],
			"%s is %s!" % [line("people"), line("accusations")], "%s has %s!" % [line("people"), line("contraband")],
			"%s in %s%s" % [line("threat"), line("location"), "!" if Body.prob(50) else "!!"],
			["Where's %s?" % who, "Set %s to arrest!" % who][Game.rng.randi() % 2],
			"%sall the ferry!" % ["C", "Please, c", "Someone c", "Rec"][Game.rng.randi() % 4],
			"The boiler %s!!" % ["is rogue", "is dead"][Game.rng.randi() % 2], "Automatons rogue!"][Game.rng.randi() % 9]
	else:
		var k: String = ["suspicion", "conversation", "greetings", "getout", "weird", "didyouhearthat", "doubt", "aggressive", "help", "escape", "infection"][Game.rng.randi() % 11]
		match k:
			"greetings": chosen = line("greetings") + who + "!"
			"help": chosen = line("help") + "!!"
			"infection": chosen = "I'm infected, %s!" % line("infection_advice")
			_: chosen = line(k)
	chosen = chosen.replace("%TARGETNAME%", who)
	if chosen == "":
		return false
	chosen = chosen[0].to_upper() + chosen.substr(1)
	if radio:
		var col: Color = Defs.RADIO_COLORS.get("Common", Color("#7ad87a"))
		Game.hud.add_line("[color=#%s][Common] [b]%s[/b] (%s): %s[/color]" % [col.to_html(false), speaker.display_name, Jobs.title(speaker.c(&"mob").job) if speaker.has_c(&"mob") else "?", chosen], "radio")
		Sfx.play("radio", e.cell, 0.25)
	else:
		var verb := "asks" if chosen.ends_with("?") else ("exclaims" if chosen.ends_with("!") else "says")
		Game.hud.add_line("[color=#e8eef4][b]%s[/b] %s, \"%s\"[/color]" % [speaker.display_name, verb, chosen], "say")
		Game.hud.bubble(speaker, chosen)
	return true

## tg /datum/hallucination/message
static func _message(h: CHealth) -> bool:
	if h.knocked_out():
		return false
	var e := h.e
	var sus: Entity = null
	var adjacent := false
	var near := []
	for x in Game.in_radius(e.cell, 7, &"mob"):
		if x == e or not x.has_c(&"inv"):
			continue
		if e.dist_to(x) <= 1:
			sus = x
			adjacent = true
			break
		near.append(x)
	if sus == null and not near.is_empty():
		sus = near[Game.rng.randi() % near.size()]
	var pool := {}
	if sus:
		if adjacent:
			pool["You feel a tiny prick!"] = 5
		var bag: Entity = sus.c(&"inv").worn("back")
		if bag:
			var stash: String = ["blueprints", "flash", "master's spare passcard", "cryptographic sequencer", "circular saw", "C-4 charge", "six-shot revolver", "aether carbine", "antique aether pistol", "skip-charm", "stun baton", "energy sword", "hypospray"][Game.rng.randi() % 13]
			pool["%s puts the %s into %s." % [sus.display_name, stash, bag.display_name]] = 5
		pool["[b]%s[/b] %s." % [sus.display_name, ["sneezes", "coughs"][Game.rng.randi() % 2]]] = 1
	pool["You hear something squeezing through the ducts..."] = 1
	pool["Your %s itches." % ["arm", "leg", "back", "head"][Game.rng.randi() % 4]] = 1
	pool["You feel %s." % ["hot", "cold", "dry", "wet", "woozy", "faint"][Game.rng.randi() % 6]] = 1
	pool["Your stomach rumbles."] = 1
	pool["Your head hurts."] = 1
	pool["You hear a faint buzz in your head."] = 1
	if Body.prob(10):
		pool["Behind you."] = 1
		pool["You hear a faint laughter."] = 1
		pool["You hear skittering on the ceiling."] = 1
		pool["You see an inhumanly tall silhouette moving in the distance."] = 2
	if Body.prob(30):
		pool[line("advice", e)] = 4
	var total := 0.0
	for k in pool:
		total += pool[k]
	var r := Game.rng.randf() * total
	for k in pool:
		r -= pool[k]
		if r <= 0.0:
			Game.tell(e, k, "warn")
			return true
	return false

## A turf just out of sight (tg random_far_turf)
static func _far_cell(e: Entity) -> Vector2i:
	var a := Game.rng.randf() * TAU
	var r := Game.rng.randf_range(6.0, 10.0)
	return e.cell + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))

## tg /datum/hallucination/fake_sound/normal/* (the sounds this game has)
static func _sound(h: CHealth) -> bool:
	var e := h.e
	var c := _far_cell(e)
	match Game.rng.randi_range(1, 14):
		1: Sfx.play("door", c, 0.5)
		2:
			Sfx.play("ratchet", c, 0.8)
			_later_sound(h, "door", c, 5.0)
		3: Sfx.play("ui_tick", c, 0.4)
		4: Sfx.play("explosion", c, 0.8)
		5: Sfx.play("explosion", c + (c - e.cell) * 3, 0.3)
		6: Sfx.play("shatter", c, 0.7)
		7: Sfx.play("alarm", c, 0.7)
		8: Sfx.play("deny", c, 0.5)
		9:
			for i in Game.rng.randi_range(4, 9):
				_later_sound(h, "step_floor", c, i * 1.0)
		10:
			Sfx.play("welder", c, 0.6)
			_later_sound(h, "ratchet", c, 4.0)
		11:
			Sfx.play("ratchet", c, 0.6)
			_later_sound(h, "door", c, 3.0)
		12: Sfx.play("spray", c, 0.6)
		13: Sfx.play("stun", c, 0.7)
		14: Sfx.play("ding", c, 0.5)
	return true

## tg /datum/hallucination/battle/*: a fight you can hear but not see
static func _battle(h: CHealth) -> bool:
	var c := _far_cell(h.e)
	match Game.rng.randi_range(1, 6):
		1, 2, 3:
			var n := Game.rng.randi_range(3, 6)
			for i in n:
				_later_sound(h, "gunshot", c, i * Game.rng.randf_range(0.3, 0.8))
			_later_sound(h, "hit", c, n * 0.6)
		4:
			_later_sound(h, "stun", c, 0.0)
			_later_sound(h, "stun", c, 1.2)
		5:
			for i in 4:
				_later_sound(h, "hit", c, i * 0.7)
		6:
			_later_sound(h, "ding", c, 0.0)
			_later_sound(h, "explosion", c, 3.0)
	return true

## tg /datum/hallucination/bolts: nearby airlocks drop their bolts (red lights) one by one
static func _bolts(h: CHealth) -> bool:
	var doors := Game.in_radius(h.e.cell, 7, &"door").filter(func(d): return d.c(&"door").is_closed() if d.c(&"door").has_method("is_closed") else true)
	if doors.is_empty():
		return false
	var n := Game.rng.randi_range(0, 4)
	if n > 0:
		doors = doors.slice(0, n)
	var i := 0
	for d in doors:
		var tw: Tween = d.create_tween()
		tw.tween_interval(i * 0.6)
		tw.tween_callback(func():
			d.modulate = Color(1.0, 0.55, 0.55)
			Sfx.play("click", d.cell, 0.5))
		tw.tween_interval(10.0 + i * 0.6)
		tw.tween_callback(func(): d.modulate = Color.WHITE)
		i += 1
	return true

## tg /datum/hallucination/body: a body lying where there is none
static func _body(h: CHealth) -> bool:
	var e := h.e
	var layer := Fx._layer()
	var m: CMob = e.c(&"mob")
	if layer == null or m == null or m.doll == null:
		return false
	var spots := []
	for dx in range(-5, 6):
		for dy in range(-4, 5):
			var c := e.cell + Vector2i(dx, dy)
			if abs(dx) + abs(dy) >= 2 and Game.map.inb(c) and not Game.map.blocks_move_static(c) and Game.at(c).is_empty():
				spots.append(c)
	if spots.is_empty():
		return false
	var c: Vector2i = spots[Game.rng.randi() % spots.size()]
	var d: Node2D = m.doll.duplicate()
	var kind: int = Game.rng.randi_range(0, 3)
	d.position = Vector2(c.x * 32 + 16, c.y * 32 + 28)
	if kind <= 1:
		d.rotation = PI * 0.5 # a husk, lying there
		d.modulate = Color(0.35, 0.33, 0.3)
	elif kind == 2:
		d.modulate = Color(0.85, 0.9, 1.0, 0.45) # a ghost
	else:
		d.modulate = Color(0.05, 0.05, 0.05) # a hole in the shape of a man
	layer.add_child(d)
	var tw := d.create_tween()
	tw.tween_interval(Game.rng.randf_range(30.0, 60.0))
	tw.tween_property(d, "modulate:a", 0.0, 1.0)
	tw.tween_callback(d.queue_free)
	return true

## tg /datum/hallucination/blood_flow: blood sprays from a part of you that isn't hurt
static func _blood_flow(h: CHealth) -> bool:
	if h.blood_volume <= 0.0:
		return false
	var parts := Body.PARTS.keys().filter(func(p): return not h.missing.has(p))
	if parts.is_empty():
		return false
	var p: String = parts[Game.rng.randi() % parts.size()]
	Game.tell(h.e, "Your %s looses a spray of blood!" % Body.pname(p), "bad")
	h.set_meta("fake_bleed_part", p)
	h.set_meta("fake_bleed_until", Game.time + Game.rng.randf_range(16.0, 40.0))
	return true

## tg /datum/hallucination/eyes_in_dark
static func _eyes(h: CHealth) -> bool:
	var layer := Fx._layer()
	if layer == null or Game.lighting == null:
		return false
	var e := h.e
	var dark := []
	for dx in range(-6, 7):
		for dy in range(-5, 6):
			var c := e.cell + Vector2i(dx, dy)
			if abs(dx) + abs(dy) >= 3 and Game.map.inb(c) and not Game.map.blocks_move_static(c) and not Game.lighting.player_can_see(c):
				dark.append(c)
	if dark.is_empty():
		return false
	var c: Vector2i = dark[Game.rng.randi() % dark.size()]
	var node := Node2D.new()
	node.position = Vector2(c.x * 32 + 16, c.y * 32 + 10)
	node.z_index = 40
	for x in [-4, 3]:
		var r := ColorRect.new()
		r.color = Color(1.0, 0.1, 0.1)
		r.size = Vector2(2, 1)
		r.position = Vector2(x, 0)
		node.add_child(r)
	layer.add_child(node)
	var tw := node.create_tween()
	tw.tween_interval(Game.rng.randf_range(10.0, 25.0))
	tw.tween_property(node, "modulate:a", 0.0, 0.5)
	tw.tween_callback(node.queue_free)
	return true

static func _ice_cube(e: Entity, dur: float) -> void:
	var layer := Fx._layer()
	if layer == null:
		return
	var r := ColorRect.new()
	r.color = Color(0.7, 0.9, 1.0, 0.45)
	r.size = Vector2(26, 32)
	r.position = e.position + Vector2(-13, -34)
	r.z_index = 30
	layer.add_child(r)
	var tw := r.create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(r.queue_free)

## tg /datum/hallucination/malf_apc: the APC in the room sparks and hums wrong
static func _malf_apc(h: CHealth) -> bool:
	var apcs := Game.in_radius(h.e.cell, 7, &"apc")
	if apcs.is_empty():
		return false
	var a: Entity = apcs[0]
	for i in 3:
		_later_sound(h, "spark", a.cell, i * 0.8)
	Fx.sparks(a.cell)
	return true

## tg /datum/hallucination/fake_flood: plasma pours out of the nearest vent
static func _flood(h: CHealth) -> bool:
	var vents := Game.in_radius(h.e.cell, 7, &"vent")
	var layer := Fx._layer()
	if vents.is_empty() or layer == null:
		return false
	var center: Vector2i = vents[0].cell
	var node := Node2D.new()
	node.z_index = 25
	layer.add_child(node)
	var tw := node.create_tween()
	for radius in range(0, 11):
		tw.tween_callback(func():
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					if abs(dx) + abs(dy) != radius:
						continue
					var c := center + Vector2i(dx, dy)
					if not Game.map.inb(c) or Game.map.blocks_move_static(c):
						continue
					var r := ColorRect.new()
					r.color = Color(0.85, 0.3, 0.95, 0.28)
					r.size = Vector2(32, 32)
					r.position = Vector2(c.x * 32, c.y * 32)
					node.add_child(r))
		tw.tween_interval(2.0)
	tw.tween_callback(func():
		if is_instance_valid(h) and h.e == Game.player:
			h.set_meta("fake_alert", ["plasma", "CHOKING (PLASMA)"])
			h.set_meta("fake_alert_until", Game.time + 10.0))
	tw.tween_interval(10.0)
	tw.tween_property(node, "modulate:a", 0.0, 2.0)
	tw.tween_callback(node.queue_free)
	return true

## tg /datum/hallucination/stray_bullet: a shot from out of sight, straight at you
static func _stray_bullet(h: CHealth) -> bool:
	var e := h.e
	var from := _far_cell(e)
	var kind: String = ["bullet", "laser", "disabler"][Game.rng.randi() % 3]
	var col: Color = {"bullet": Color(1, 0.9, 0.5), "laser": Color(1, 0.2, 0.2), "disabler": Color(0.4, 0.8, 1)}[kind]
	if e == Game.player:
		Sfx.play("gunshot" if kind == "bullet" else "stun", from, 0.8)
		Fx.beam(from, e.cell, col)
		Game.tell(e, "[b]You're hit by a %s in the chest![/b]" % kind, "bad")
	h.adjust("stamina", {"bullet": 60.0, "laser": 20.0, "disabler": 30.0}[kind])
	return true

## tg /datum/hallucination/hazard: lava, a chasm or an anomaly appears nearby
static func _hazard(h: CHealth) -> bool:
	var e := h.e
	var layer := Fx._layer()
	if layer == null:
		return false
	var c: Vector2i = e.cell + Defs.DIRS8[Game.rng.randi() % 8] * Game.rng.randi_range(1, 3)
	if not Game.map.inb(c) or Game.map.blocks_move_static(c):
		return false
	var kind: String = ["lava", "chasm", "anomaly"][Game.rng.randi() % 3]
	var r := ColorRect.new()
	r.size = Vector2(32, 32)
	r.position = Vector2(c.x * 32, c.y * 32)
	r.z_index = -1
	r.color = {"lava": Color(1.0, 0.35, 0.05, 0.85), "chasm": Color(0.0, 0.0, 0.0, 0.95), "anomaly": Color(0.5, 0.8, 1.0, 0.6)}[kind]
	layer.add_child(r)
	h.set_meta("hazard", [c, kind])
	var tw := r.create_tween()
	tw.tween_interval(Game.rng.randf_range(20.0, 40.0))
	tw.tween_callback(func():
		r.queue_free()
		if is_instance_valid(h) and h.has_meta("hazard"):
			h.remove_meta("hazard"))
	return true

## Stepping onto a hallucinated hazard (tg hazard on_entered)
static func on_step(h: CHealth, c: Vector2i) -> void:
	if not h.has_meta("hazard"):
		return
	var hz: Array = h.get_meta("hazard")
	if hz[0] != c:
		return
	match hz[1]:
		"lava":
			Game.tell(h.e, "[b]You fall into the lava![/b]", "bad")
			h.paralyze(6.0)
			h.adjust("stamina", 30.0)
		"chasm":
			Game.tell(h.e, "[b]You fall into the chasm![/b]", "bad")
			h.paralyze(4.0)
		"anomaly":
			Game.tell(h.e, "[b]You feel a strange energy pass through you...[/b]", "warn")
			h.adjust_status("jitter", 10.0)
	h.remove_meta("hazard")

## tg /datum/hallucination/delusion/preset: everyone else looks like something else
static func _delusion(h: CHealth) -> bool:
	var what: String = ["nothing", "curse", "monkey", "corgi", "carp", "skeleton", "zombie", "demon", "cyborg", "ghost"][Game.rng.randi() % 10]
	var tint: Color = {"nothing": Color(1, 1, 1, 0.0), "curse": Color(0.7, 0.4, 1.0), "monkey": Color(0.75, 0.55, 0.35), "corgi": Color(1.0, 0.8, 0.5),
		"carp": Color(0.6, 0.3, 1.0), "skeleton": Color(2.0, 2.0, 2.0), "zombie": Color(0.5, 0.9, 0.5), "demon": Color(1.4, 0.3, 0.3),
		"cyborg": Color(0.7, 0.75, 0.85), "ghost": Color(1, 1, 1, 0.35)}[what]
	var who := []
	for x in Game.in_radius(h.e.cell, 12, &"mob"):
		if x != h.e and x.has_c(&"mob") and x.c(&"mob").doll:
			x.c(&"mob").doll.modulate = tint
			who.append(x)
	if who.is_empty():
		return false
	h.set_meta("delusion", who)
	h.set_meta("delusion_until", Game.time + 30.0)
	if what != "nothing":
		Game.tell(h.e, "Everyone around you looks like a %s..." % what if what != "curse" else "Something is wrong with everyone's faces...", "warn")
	return true

static func _end_delusion(h: CHealth) -> void:
	for x in h.get_meta("delusion", []):
		if is_instance_valid(x) and not x.removed and x.c(&"mob") and x.c(&"mob").doll:
			x.c(&"mob").doll.modulate = Color.WHITE
	h.remove_meta("delusion")
	h.remove_meta("delusion_until")

## tg /datum/hallucination/station_message/*: announcements only you hear
static func _station_message(h: CHealth) -> bool:
	var msg: Array = [
		["Hail Warning", "A hailstorm has been sighted on a collision course with the ship."],
		["Hail Warning", "A hailstorm has been sighted on a collision course with the ship."],
		["Sickness Alert", "Confirmed outbreak of a deadly fever aboard the ship. All hands must contain the outbreak."],
		["Priority Announcement", "The relief ferry has docked alongside the ship. You have 3 minutes to board."],
		["Anomaly Alert", "Hostile resonance detected in all ship systems, please quiet your aether cells to prevent possible damage."],
		["Attention", "Figments of an elder sky-god are being summoned somewhere on the ship. Disrupt the ritual at all costs."],
	][Game.rng.randi() % 6]
	Game.hud.add_line("[color=#ffe07a][b]%s[/b]: %s[/color]" % [msg[0], msg[1]], "announce")
	Sfx.play("alarm", h.e.cell, 0.4)
	return true
