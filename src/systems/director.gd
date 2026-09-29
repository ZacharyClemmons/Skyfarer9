class_name Director extends Node
## The storyteller. Combines tg's random-event scheduler (weights, earliest start,
## max occurrences, cooldowns - see code/modules/events) with a RimWorld-style tension
## curve: when the station is calm relative to where the story "should" be, it throws
## something at it; after a crisis it gives the crew room to breathe (or an aurora).
## Also runs the asteroid's day/night cycle and the weather.

const EVENTS := {
	"pipe_burst": {"w": 10.0, "earliest": 90.0, "cd": 240.0, "max": 6, "tension": 2.0, "name": "Pipe burst"},
	"electrical_short": {"w": 8.0, "earliest": 150.0, "cd": 300.0, "max": 5, "tension": 2.5, "name": "Electrical short"},
	"grid_check": {"w": 3.0, "earliest": 480.0, "cd": 900.0, "max": 2, "tension": 3.0, "name": "Lamp check"},
	"ice_storm": {"w": 6.0, "earliest": 300.0, "cd": 900.0, "max": 3, "tension": 3.0, "name": "Squall"},
	"ice_quake": {"w": 3.5, "earliest": 600.0, "cd": 1000.0, "max": 2, "tension": 3.5, "name": "Island tremor"},
	"vent_clog": {"w": 5.0, "earliest": 200.0, "cd": 400.0, "max": 4, "tension": 1.0, "name": "Vent clog"},
	"disease": {"w": 3.0, "earliest": 600.0, "cd": 1200.0, "max": 2, "tension": 2.0, "name": "Sickness aboard"},
	"reactor_surge": {"w": 3.0, "earliest": 700.0, "cd": 1200.0, "max": 2, "tension": 4.0, "name": "Reactor surge"},
	"machine_fault": {"w": 8.0, "earliest": 60.0, "cd": 150.0, "max": 10, "tension": 1.0, "name": "Machine fault"},
	"heater_failure": {"w": 6.0, "earliest": 180.0, "cd": 350.0, "max": 6, "tension": 1.5, "name": "Stove failure"},
	"electrical_storm": {"w": 4.0, "earliest": 250.0, "cd": 600.0, "max": 3, "tension": 1.5, "name": "Thunderhead"},
	"aurora": {"w": 3.0, "earliest": 300.0, "cd": 1500.0, "max": 2, "tension": -2.0, "name": "Aurora"},
	"supply_pod": {"w": 3.0, "earliest": 400.0, "cd": 900.0, "max": 3, "tension": -1.0, "name": "Supply drop"},
	"false_alarm": {"w": 2.0, "earliest": 300.0, "cd": 900.0, "max": 2, "tension": 0.5, "name": "False alarm"},
	"comms_blackout": {"w": 2.0, "earliest": 600.0, "cd": 1200.0, "max": 1, "tension": 2.0, "name": "Signal blackout"},
	"mice": {"w": 4.0, "earliest": 240.0, "cd": 700.0, "max": 3, "tension": 1.0, "name": "Bilge rats"},
	"traitor": {"w": 3.0, "earliest": 500.0, "cd": 1400.0, "max": 2, "tension": 3.0, "name": "Mutineer"},
}

var enabled := true
var history := {} # id -> {count, last}
var next_check := 45.0
var next_event_after := 100.0
var tension := 0.0
var target := 1.0
var storm := 0.0
var storm_target := 0.0
var storm_until := 0.0
var ext_temp_offset := 0.0
var aurora_until := 0.0
const DAY_PERIOD := 1440.0 # 24 real minutes per asteroid day
var events_log: Array = []

func _process(delta: float) -> void:
	var _pt := Perf.t0()
	_process_body(delta)
	Perf.add("director", _pt)

func _process_body(delta: float) -> void:
	if not Game.running or Game.paused:
		return
	var d := delta * Game.time_scale
	_weather(d)
	_daylight()
	next_check -= d
	if next_check <= 0.0:
		next_check = 10.0
		tension = measure_tension()
		target = target_tension()
		if enabled and Game.time >= next_event_after and tension < target - 0.4:
			var id := _pick(target - tension)
			if id != "":
				trigger(id)
				next_event_after = Game.time + randf_range(80.0, 200.0) * (1.4 if tension > 3.0 else 1.0)

func measure_tension() -> float:
	var t := 0.0
	if Game.atmos:
		t += minf(Game.atmos.hotspots.size() * 0.3, 3.0)
	for m in Game.all_with(&"health"):
		var h: CHealth = m.c(&"health")
		if h.dead:
			t += 0.6 if Game.time - h.time_of_death < 600.0 else 0.1
		elif h.in_crit():
			t += 1.0
		elif h.health() < 60:
			t += 0.3
	for a in Game.map.areas:
		if a.apc and not a.power_light:
			t += 0.2
		if a.atmos_alarm:
			t += 0.3
	t += storm * 1.5
	t += StationAlerts.active.size() * 0.2
	for r in Game.all_with(&"reactor"):
		if r.c(&"reactor").core_temp > CReactor.WARN_T:
			t += 2.0
	return t

func target_tension() -> float:
	var tm := Game.time
	var wave := sin(tm / 600.0 * TAU) * 1.2 + sin(tm / 170.0 * TAU) * 0.4
	return clampf(1.4 + tm / 1500.0 + wave, 0.6, 6.5)

func _eligible(id: String) -> bool:
	var ev: Dictionary = EVENTS[id]
	var h: Dictionary = history.get(id, {"count": 0, "last": -1e9})
	if Game.time < ev["earliest"] or h["count"] >= ev["max"] or Game.time - h["last"] < ev["cd"]:
		return false
	match id:
		"ice_storm":
			return storm < 0.1
		"aurora":
			return aurora_until < Game.time
		"traitor":
			return Game.all_with(&"brain").size() >= 6
	return true

func _pick(gap: float) -> String:
	var total := 0.0
	var pool := []
	for id in EVENTS:
		if not _eligible(id):
			continue
		var ev: Dictionary = EVENTS[id]
		var w: float = ev["w"]
		# prefer events sized to the gap; relief events when things are already hot
		var fit := 1.0 / (1.0 + absf(ev["tension"] - gap))
		if ev["tension"] < 0 and tension > 3.0:
			fit = 1.5
		w *= fit
		pool.append([id, w])
		total += w
	if pool.is_empty():
		return ""
	var r := randf() * total
	for p in pool:
		r -= p[1]
		if r <= 0:
			return p[0]
	return pool[-1][0]

func trigger(id: String) -> void:
	var h: Dictionary = history.get(id, {"count": 0, "last": -1e9})
	h["count"] += 1
	h["last"] = Game.time
	history[id] = h
	events_log.append({"t": Game.time, "id": id})
	call("_ev_" + id)

func announce(title: String, text: String, severity := 1) -> void:
	Bus.announcement.emit(title, text, severity)

# ------------------------------------------------------------------ weather & light
func _weather(d: float) -> void:
	if storm_until > 0 and Game.time > storm_until:
		storm_target = 0.0
		storm_until = 0.0
		announce("Weather Advisory", "The squall has passed. Conditions on deck are returning to normal.", 0)
	storm = move_toward(storm, storm_target, d * 0.03)
	ext_temp_offset = -38.0 * storm
	if Game.atmos:
		Game.atmos.ext_temp = Defs.EXT_TEMP + ext_temp_offset
	if Game.view:
		var sn: Snowfall = Game.view.snow
		sn.intensity = 0.3 + storm * 0.7 + (0.1 if aurora_until > Game.time else 0.0)
		sn.wind = Vector2(-22.0 - storm * 160.0, 6.0 + storm * 40.0)
	if storm > 0.6 and randf() < d * 0.02:
		# the storm batters exterior windows
		var map := Game.map
		for k in 30:
			var c := Vector2i(randi() % map.w, randi() % map.h)
			if Defs.is_window(map.structure[map.idx(c)]):
				var exposed := false
				for dd in Defs.DIRS4:
					if map.is_outdoor(c + dd):
						exposed = true
				if exposed:
					Structures.take_damage(c, 30.0, "brute", "", null) # weather: unarmoured
					break

func _daylight() -> void:
	if Game.lighting == null:
		return
	var phase := fposmod(Game.time / DAY_PERIOD + 0.22, 1.0) # shift starts early morning
	var sun := sin(phase * TAU - PI * 0.5) * 0.5 + 0.5 # 0 midnight .. 1 noon
	var night := Color(0.13, 0.17, 0.32)
	var dusk := Color(0.55, 0.38, 0.48)
	var day := Color(0.78, 0.84, 0.95)
	var col: Color
	if sun < 0.35:
		col = night.lerp(dusk, sun / 0.35)
	else:
		col = dusk.lerp(day, clampf((sun - 0.35) / 0.4, 0.0, 1.0))
	col = col.lerp(Color(0.5, 0.55, 0.62), storm * 0.6) * (1.0 - storm * 0.25)
	Game.lighting.ambient = col
	var au := 0.0
	if aurora_until > Game.time:
		au = clampf((aurora_until - Game.time) / 30.0, 0.0, 1.0) * (1.0 - sun * 0.7)
	Game.lighting.aurora = au

# ------------------------------------------------------------------ events
func _random_pipe(layers: Array) -> Array:
	var map := Game.map
	for k in 400:
		var c := Vector2i(randi() % map.w, randi() % map.h)
		for l in layers:
			if map.pipe_mask(l, c) != 0 and not map.is_outdoor(c):
				return [l, c]
	return []

func _ev_pipe_burst() -> void:
	var layers := [StationMap.PL_SUPPLY, StationMap.PL_SCRUB]
	if randf() < 0.3:
		layers = [StationMap.PL_HOT]
	var p := _random_pipe(layers)
	if p.is_empty():
		return
	Game.map.damage_pipe(p[0], p[1], randf_range(55.0, 80.0))
	Bus.stimulus.emit({"type": "pipe_burst", "cell": p[1], "loud": 14.0})
	Sfx.play("explosion", p[1], 0.4)
	Bus.chronicle.emit("A %s pipe burst in %s." % [StationMap.PIPE_LAYER_NAMES[p[0]], Game.map.area_at(p[1]).name], 2)

func _ev_electrical_short() -> void:
	var map := Game.map
	for k in 400:
		var i := randi() % map.cable.size()
		var c := map.cell_of(i)
		if map.cable[i] == 1 and not map.is_outdoor(c) and map.area[i] != 0:
			map.cable[i] = 2
			Bus.cables_changed.emit()
			Fx.sparks(c)
			if randf() < 0.55 and Game.atmos:
				Game.atmos.ignite(c, null, 12.0)
			Bus.chronicle.emit("An electrical short sparked in %s." % map.area_at(c).name, 2)
			return

func _ev_grid_check() -> void:
	announce("Lamp Check", "Irregular load on the ship's power lines. Power will be interrupted while the boiler crew checks the lines. Sorry for the inconvenience.", 1)
	Game.power.grid_check_t = randf_range(45.0, 90.0)

func _ev_ice_storm() -> void:
	announce("Weather Advisory", "A hard squall is bearing down on the ship. All hands are advised to get below decks immediately. Exterior temperatures will drop sharply.", 2)
	await get_tree().create_timer(45.0).timeout
	storm_target = 1.0
	storm_until = Game.time + randf_range(160.0, 300.0)
	Bus.chronicle.emit("A squall hit the ship.", 2)
	for b in Game.all_with(&"brain"):
		b.c(&"brain").knowledge.learn({"key": "storm", "type": "noise", "cell": b.cell, "severity": 1}, Knowledge.RADIO)

func _ev_ice_quake() -> void:
	announce("Tremor Warning", "The island below is shifting. Brace for tremors.", 2)
	await get_tree().create_timer(8.0).timeout
	if Game.view:
		Game.view.shake(9.0)
	Sfx.play("explosion", Game.player.cell if Game.player else Vector2i.ZERO, 0.6)
	var map := Game.map
	var hits := 0
	for k in 3000:
		if hits >= 9:
			break
		var c := Vector2i(randi() % map.w, randi() % map.h)
		var i := map.idx(c)
		if map.area[i] == 0:
			continue
		var s := map.structure[i]
		if Defs.is_window(s):
			Structures.take_damage(c, 50.0, "brute", "", null) # the frame twists: unarmoured
			hits += 1
		elif map.pipe_mask(StationMap.PL_SUPPLY, c) != 0 and randf() < 0.3:
			map.damage_pipe(StationMap.PL_SUPPLY, c, 60.0)
			hits += 1
		elif map.cable[i] == 1 and randf() < 0.2:
			map.cable[i] = 2
			Bus.cables_changed.emit()
			hits += 1
	for m in Game.all_with(&"health"):
		if randf() < 0.35 and not Game.map.is_outdoor(m.cell):
			m.c(&"health").knockdown(1.5)
	Bus.chronicle.emit("A tremor shook the ship.", 3)

func _ev_vent_clog() -> void:
	var vents := Game.all_with(&"vent").filter(func(v): return v.c(&"vent").mode == "vent")
	if vents.is_empty():
		return
	var v: Entity = vents[randi() % vents.size()]
	v.c(&"vent").clogged = 30.0
	Bus.stimulus.emit({"type": "noise", "cell": v.cell, "loud": 6.0})
	Bus.chronicle.emit("A vent in %s started belching smoke." % Game.map.area_at(v.cell).name, 1)

func _ev_disease() -> void:
	var crew := Game.all_with(&"brain").filter(func(x): return not x.c(&"health").dead)
	if crew.is_empty():
		return
	var p: Entity = crew[randi() % crew.size()]
	var d := Disease.make_random()
	d.infect(p)
	Game.chronicle.add_secret("Patient zero of %s: %s." % [d.name, p.display_name])

func _ev_reactor_surge() -> void:
	for r in Game.all_with(&"reactor"):
		var rc: CReactor = r.c(&"reactor")
		rc.core_temp += randf_range(250.0, 400.0)
		rc.rod_target = maxf(0.2, rc.rod_target - 0.2)
		Bus.chronicle.emit("The reactor surged.", 3)

func _ev_machine_fault() -> void:
	var ms := Game.all_with(&"machine").filter(func(m): return not m.c(&"machine").broken and m.c(&"machine").needs_power and not m.has_c(&"apc"))
	if ms.is_empty():
		return
	var m: Entity = ms[randi() % ms.size()]
	m.c(&"machine").set_broken(true)
	if m.has_c(&"cooker") and randf() < 0.5 and Game.atmos:
		Game.atmos.ignite(m.cell, null, 10.0)

func _ev_heater_failure() -> void:
	var hs := Game.all_with(&"heater").filter(func(h): return not h.c(&"machine").broken)
	if hs.is_empty():
		return
	var h: Entity = hs[randi() % hs.size()]
	h.c(&"machine").set_broken(true)
	Bus.chronicle.emit("The heater in %s broke down." % Game.map.area_at(h.cell).name, 1)

func _ev_electrical_storm() -> void:
	announce("Thunderhead", "A thunderhead has been sighted close to the ship. Please check the lamps for damage.", 1)
	var lights := Game.all_with(&"light").filter(func(l): return l.c(&"light").kind == "fixture")
	lights.shuffle()
	for k in mini(10, lights.size()):
		lights[k].c(&"light").break_light()

func _ev_aurora() -> void:
	announce("Aurora", "An aurora is lighting the sky. Crew are encouraged to take a moment at the nearest rail.", 0)
	aurora_until = Game.time + 260.0
	for m in Game.all_with(&"needs"):
		var n: CNeeds = m.c(&"needs")
		n.stress = maxf(0.0, n.stress - 15.0)
		n.fun = minf(100.0, n.fun + 20.0)
	Bus.chronicle.emit("An aurora lit up the sky.", 1)

func _ev_supply_pod() -> void:
	var map := Game.map
	for k in 200:
		var c := Vector2i(randi_range(MapGen.SX - 10, MapGen.SX + MapGen.SW + 10), randi_range(MapGen.SY - 10, MapGen.SY + MapGen.SH + 10))
		if map.is_outdoor(c) and map.is_outdoor(c + Vector2i(1, 0)) and Game.at(c).is_empty():
			var pod := Proto.spawn("supply_pod", c)
			for it in ["food_ration", "food_ration", "food_ration", "medkit", "sheet_metal", "sheet_glass", "cable_coil", "tank_o2", "winter_coat"]:
				pod.c(&"storage").insert(Proto.spawn(it, c))
			Fx.explosion(c, 0.6)
			announce("Supply Drop", "A Guild supply drop has landed on the island near the ship.", 0)
			Bus.chronicle.emit("A supply drop landed outside %s." % map.area_at(c).name, 1)
			return

func _ev_false_alarm() -> void:
	var fakes := [["Weather Advisory", "A hard squall is bearing down on the ship. All hands are advised to get below decks immediately."],
		["Tremor Warning", "The island below is shifting. Brace for tremors."],
		["Sickness Alert", "Confirmed outbreak of a sky-fever aboard the ship."]]
	var f: Array = fakes[randi() % fakes.size()]
	announce(f[0], f[1], 1)

func _ev_comms_blackout() -> void:
	announce("Voice-link", "Aether interference detected. Temporary link failu#e appr%#_ lik3ly...", 1)
	Game.power.blackout_t = randf_range(90.0, 160.0)
	Bus.chronicle.emit("Voice-link communications went down.", 2)

func _ev_mice() -> void:
	if CVermin.infest(Game.rng.randi_range(3, 6)) > 0:
		Bus.chronicle.emit("Rats crept up out of the ship's bilges.", 1)

static func _traitor_ok(x: Entity) -> bool:
	var b: CBrain = x.c(&"brain")
	return not b.health.dead and b.antag.is_empty() and b.tv("honesty") + b.tv("lawfulness") < 0.9

func _ev_traitor() -> void:
	var cands := Game.all_with(&"brain").filter(func(x): return Director._traitor_ok(x))
	if cands.is_empty():
		return
	var t: Entity = cands[randi() % cands.size()]
	var b: CBrain = t.c(&"brain")
	var obj := {}
	var ruthless: bool = b.tv("aggression") > 0.55 and b.tv("empathy") < 0.5
	if ruthless and randf() < 0.6:
		var marks := Game.all_with(&"brain").filter(func(x): return x != t and not x.c(&"health").dead)
		if Game.player and is_instance_valid(Game.player) and not Game.player.c(&"health").dead and randf() < 0.3:
			marks.append(Game.player)
		if not marks.is_empty():
			# someone they already can't stand, if there is one
			var foe: Entity = b._disliked_person()
			var mark: Entity = foe if foe and foe in marks and randf() < 0.6 else marks[randi() % marks.size()]
			obj = {"kind": "kill", "target": mark.id, "name": mark.display_name}
	if not obj.is_empty():
		pass
	elif randf() < 0.6:
		var p := _random_pipe([StationMap.PL_HOT, StationMap.PL_SUPPLY])
		if p.is_empty():
			return
		obj = {"kind": "sabotage", "cell": p[1]}
	else:
		var loot := Game.all_with(&"item").filter(func(i): return i.proto in ["health_analyzer", "multitool", "baton", "drink_booze", "insulated_gloves"] and i.root() != t and not i.root().has_c(&"mob"))
		if loot.is_empty():
			return
		obj = {"kind": "steal", "target": loot[randi() % loot.size()].id}
	# tg: most mutineers must also get away alive and free on the ferry
	obj["escape"] = randf() < 0.8
	if obj["kind"] == "steal":
		obj["item"] = Game.get_entity(obj["target"]).display_name
	elif obj["kind"] == "sabotage":
		obj["where"] = Game.map.area_at(obj["cell"]).name
	b.antag = obj
	var what := {"sabotage": "sabotage the pipes", "steal": "steal a valuable item", "kill": "assassinate %s" % obj.get("name", "someone")}.get(obj["kind"], "cause trouble")
	Game.chronicle.add_secret("%s (%s) was a mutineer: %s%s." % [t.display_name, Jobs.title(b.job), what, ", then escape" if obj["escape"] else ""])
	b.remember_thought("They've given me a job. %s. Nobody can know." % Dialogue.cap(what))
