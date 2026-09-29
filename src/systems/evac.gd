class_name Evac extends Node
## The end of the shift, adapted from /tg/station's emergency shuttle (SSshuttle and
## /obj/docking_port/mobile/emergency). Here the "shuttle" is a relief ferry from
## the Consortium's home port. It's called from a Communications Console and can be
## recalled for the first part of its trip. It parks at the Departures Quay, waits for
## the crew to board, then drives off with whoever is aboard. The round ends when it
## reaches the base.
##
## Escape pods (tg: /obj/docking_port/mobile/pod) wait outside the West and Southeast
## airlocks all shift. They can be launched early at red alert or above, and all launch
## on their own when the ferry leaves. Anyone aboard escapes.
##
## Differences from tg: vehicles are stamped onto the glacier (see Vessel) and removed
## when they leave (no shuttle templates or transit z-level). The casualty autocall
## threshold is higher because the crew are NPCs. A crew-transfer crawler comes at shift
## end instead of a vote.

enum { IDLE, CALLED, RECALLED, DOCKED, ESCAPE, ENDED }
const MODE_NAMES := ["idle", "en route", "returning to port", "docked", "departed", "arrived"]

# tg: emergency_call_time / emergency_dock_time / emergency_escape_time
const CALL_TIME := 600.0
const DOCK_TIME := 180.0
const ESCAPE_TIME := 120.0
const ENGINE_START := 10.0 # tg ENGINE_START_TIME: engines spool up before departure
# tg security level shuttle_call_time_mod (ALERT_COEFF_GREEN/BLUE/RED/DELTA)
const ALERT_COEFF := [2.0, 1.0, 0.5, 0.25]
const COEFF_AUTOEVAC := 0.4 # tg ALERT_COEFF_AUTOEVAC_CRITICAL
# tg SHUTTLE_REFUEL_DELAY: nobody can call it in the first 20 minutes
const REFUEL_DELAY := 1200.0
# tg emergency_shuttle_autocall_threshold (config, 0.2 in the example config)
const AUTOEVAC_THRESHOLD := 0.4
# tg CALL_SHUTTLE_REASON_LENGTH: above green alert, a call needs a reason
const REASON_LENGTH := 12
# the Consortium's scheduled crew transfer (tg: the autotransfer vote)
const TRANSFER_AT := 3600.0

# The ferry (legend in vessel.gd). Laid out like tg's emergency shuttle: cockpit up front,
# a passenger cabin with benches facing the aisle and windows down the outer side, a brig
# and a medbay at the back, drive units against the aft wall.
const LAYOUT := [
	"##WWWWW##",
	"#,N,C,N,#",
	"#,,^,^,,#",
	"####D####",
	"#>.....<W",
	"#>.....<#",
	"#>.....<W",
	"#>.....<#",
	"#......oW",
	"H.......#",
	"#.......W",
	"#>.....<#",
	"#>.....<W",
	"#>.....<#",
	"###B#M###",
	"#,,,#,,b#",
	"#k,,#,,l#",
	"#EEE#EEE#",
	"#########",
]
const V0 := 9 # LAYOUT row of the hatch (v = 0)
const U_MAX := 8 # outer hull column; the treads run along u = U_MAX + 1
const V_MIN := -V0
const V_MAX := 9
# tg escape pod: six seats and a launch console, windows at the front
const POD := [
	"#####",
	"#vvvW",
	"H..LW",
	"#^^^W",
	"#####",
]
const POD_V0 := 2

var mode := IDLE
var timer := 0.0 # seconds until the current phase ends
var coeff := 1.0
var no_recall := false
var transfer := false # scheduled crew transfer, not an emergency
var reason := ""
var call_count := 0
var refuel_delay := REFUEL_DELAY
var dock: Dictionary = {} # {cell, dir} from mapgen
var crawler: Vessel = null # while it's parked at the station
var pods: Array = [] # Array[Vessel], still docked
var _left: Array = [] # roster entries for people who already got away in pods
var _ignited := false
var _autocalled := false
var _transfer_sent := false
var roster: Array = [] # [{name, job, status, player}] filled at departure
var ended := false

func _ready() -> void:
	Bus.mob_died.connect(func(_e): _check_autoevac())

func setup(map: StationMap) -> void:
	dock = map.evac_dock
	var n := 0
	for pd in map.pod_docks:
		n += 1
		var v := Vessel.new()
		v.name = "Escape Pod %d" % n
		v.kind = "pod"
		v.dock_cell = pd["cell"]
		v.dir = pd["dir"]
		v.layout = POD
		v.v0 = POD_V0
		v.area_names = {"main": v.name}
		v.lights = [Vector2i(2, 0)]
		v.stamp()
		pods.append(v)

## Everything a crew member could board right now (tg: the shuttle, plus pods).
func vessels() -> Array:
	var out := []
	if crawler != null and crawler.present:
		out.append(crawler)
	for p in pods:
		if p.present:
			out.append(p)
	return out

func vessel_at(c: Vector2i) -> Vessel:
	for v in vessels():
		if v.is_on(c):
			return v
	return null

# compatibility for callers that only care about the ferry
var interior: Array:
	get: return crawler.interior if crawler else []
var area: Area:
	get: return crawler.main if crawler else null

func _process(delta: float) -> void:
	var _pt := Perf.t0()
	_process_body(delta)
	Perf.add("evac", _pt)

func _process_body(delta: float) -> void:
	if not Game.running or Game.paused or ended:
		return
	var d := delta * Game.time_scale
	if not _transfer_sent and Game.time >= TRANSFER_AT and mode in [IDLE, RECALLED]:
		_transfer_sent = true
		transfer = true
		request(null, "Scheduled crew transfer. Your relief crew has arrived at the home port.", 1.0)
	if mode == IDLE:
		return
	timer -= d
	match mode:
		RECALLED:
			if timer <= 0.0:
				mode = IDLE
				timer = 0.0
		CALLED:
			if timer <= 0.0:
				_arrive()
		DOCKED:
			if not _ignited and timer <= ENGINE_START:
				_ignited = true
				Sfx.play("engine", dock["cell"], 1.0)
				Game.visible_message(dock["cell"], "The ferry's engine roars into life.", "warn")
				for p in pods:
					if p.present:
						Game.visible_message(p.dock_cell, "The escape pod's clamps release with a clunk.", "warn")
			if timer <= 0.0:
				_depart()
		ESCAPE:
			if timer <= 0.0:
				_end_round()

# ------------------------------------------------------------------ calling
func can_call() -> String:
	## "" if the ferry can be called now, else why not (tg: SSshuttle.canEvac).
	if Game.time < refuel_delay:
		return "The ferry is still being refuelled at the port. Try again in %s." % _mmss(refuel_delay - Game.time)
	match mode:
		RECALLED: return "The ferry can't be called while it's returning to port."
		CALLED: return "The ferry is already on its way."
		DOCKED: return "The ferry is already here."
		ESCAPE, ENDED: return "The ferry has already left."
	return ""

## A crewmember asks for evacuation at a comms console (tg: SSshuttle.requestEvac).
func request_by(user: Entity, why: String) -> bool:
	var err := can_call()
	if err != "":
		Game.tell(user, err, "warn")
		return false
	if why.strip_edges().length() < REASON_LENGTH and Game.alert_level > 0:
		Game.tell(user, "You must provide a reason.", "warn")
		return false
	request(user, why)
	Bus.chronicle.emit("%s called the relief ferry%s." % [user.display_name, ": \"%s\"" % why.strip_edges() if why.strip_edges() != "" else ""], 3)
	return true

## Dispatch the ferry. Pass a coefficient to override the alert level's (tg: emergency.request).
func request(_user: Entity, why := "", set_coeff := -1.0) -> void:
	if not mode in [IDLE, RECALLED, CALLED]:
		return
	coeff = set_coeff if set_coeff > 0.0 else ALERT_COEFF[Game.alert_level]
	mode = CALLED
	timer = CALL_TIME * coeff
	reason = why.strip_edges()
	call_count += 1
	var red := Game.alert_level >= 2 and set_coeff <= 0.0
	var text := "The relief ferry has been dispatched from the home port. %sIt will arrive at the Departures Quay in %s." % [
		"Battle stations confirmed: dispatching priority ferry. " if red else "", _minutes(timer)]
	if reason != "":
		text += "\nNature of emergency: " + reason
	if no_recall:
		text += "\nRecall signals are being jammed. Recall is not possible."
	Bus.announcement.emit("Crew Transfer" if transfer else "Relief Ferry Dispatched", text, 1)

func can_recall() -> bool:
	## tg: SSshuttle.can_recall + past_restriction_point. Only the first part of the trip.
	if mode != CALLED or no_recall:
		return false
	var min_left: float = [1.0, 0.5, 0.25, 0.25][Game.alert_level] * CALL_TIME
	return timer >= min_left

func recall_by(user: Entity) -> bool:
	if not can_recall():
		Game.tell(user, "The ferry is too far along to be turned back." if mode == CALLED else "The ferry isn't on its way.", "warn")
		return false
	recall()
	Bus.chronicle.emit("%s recalled the relief ferry." % user.display_name, 3)
	return true

func recall() -> void:
	if mode != CALLED:
		return
	# tg invertTimer: the ferry drives back the way it came
	timer = maxf(0.0, CALL_TIME * coeff - timer)
	mode = RECALLED
	transfer = false
	reason = ""
	Bus.announcement.emit("Relief Ferry Recalled", "The relief ferry has been recalled and is returning to the home port.", 1)

## Alert level changed while the ferry is travelling: rescale the rest of the trip.
func on_alert_changed(level: int) -> void:
	if not mode in [CALLED, RECALLED] or transfer or _autocalled:
		return
	var nc: float = ALERT_COEFF[level]
	timer *= nc / coeff
	coeff = nc

func _check_autoevac() -> void:
	## tg SSshuttle.CheckAutoEvac: mass casualties dispatch an unrecallable crawler.
	if _autocalled or ended or not Game.running or mode in [DOCKED, ESCAPE, ENDED]:
		return
	var total := 0
	var alive := 0
	for m in Game.all_with(&"mob"):
		if m.c(&"mob").job == "":
			continue
		total += 1
		if not m.c(&"health").dead:
			alive += 1
	if total == 0 or float(alive) / total > AUTOEVAC_THRESHOLD:
		return
	_autocalled = true
	no_recall = true
	Bus.announcement.emit("Relief Ferry Dispatched", "Catastrophic casualties detected: crisis protocols activated. Locking out recall orders from the ship.", 2)
	Bus.chronicle.emit("With most of the crew dead, the Guild sent the ferry on its own.", 4)
	if mode != CALLED or timer > CALL_TIME * COEFF_AUTOEVAC:
		request(null, "", COEFF_AUTOEVAC)

# ------------------------------------------------------------------ the ferry
func _cell(u: int, v: int) -> Vector2i:
	var f: Vector2i = dock["dir"]
	return dock["cell"] + f * u + Vector2i(f.y, f.x) * v

func _arrive() -> void:
	crawler = Vessel.new()
	crawler.name = "Relief Ferry"
	crawler.dock_cell = dock["cell"]
	crawler.dir = dock["dir"]
	crawler.layout = LAYOUT
	crawler.v0 = V0
	crawler.area_names = {"main": "Relief Ferry", "cockpit": "Ferry Bridge", "brig": "Ferry Brig", "med": "Ferry Sickbay"}
	crawler.area_key = func(u, v): return "cockpit" if v < -3 else ("main" if v <= 4 else ("brig" if u < 4 else "med"))
	crawler.lights = [Vector2i(4, -8), Vector2i(4, -4), Vector2i(4, -1), Vector2i(4, 3), Vector2i(2, 6), Vector2i(6, 6)]
	crawler.treads = true
	crawler.stamp()
	mode = DOCKED
	timer = DOCK_TIME
	_ignited = false
	Sfx.play("engine", dock["cell"], 0.8)
	Bus.announcement.emit("Ferry Arrival", "The relief ferry has parked at the Departures Quay. You have %s to board it." % _minutes(DOCK_TIME), 1)
	Bus.chronicle.emit("The relief ferry arrived at the Departures Quay.", 2)

func is_aboard(e: Entity) -> bool:
	return e.holder == null and vessel_at(e.cell) != null

# ------------------------------------------------------------------ escape pods
func can_launch_pod() -> String:
	## tg: pods are locked until red alert, or until the shuttle has left.
	if Game.alert_level >= 2 or mode in [ESCAPE, ENDED]:
		return ""
	return "The launch clamps are locked. Lifeboats can only launch at battle stations or higher."

func launch_pod(p: Vessel, by: Entity = null) -> bool:
	if not p.present:
		return false
	if by != null:
		var err := can_launch_pod()
		if err != "":
			Game.tell(by, err, "warn")
			return false
	var recs := _records(p.occupants(), p, "pod")
	var player_left := Game.player != null and recs.any(func(r): return r["player"])
	_left.append_array(recs)
	Sfx.play("engine", p.dock_cell, 0.9)
	p.remove()
	pods.erase(p)
	var alive := recs.filter(func(r): return r["status"] in ["escaped", "custody"]).size()
	if by != null or alive > 0:
		if by != null:
			Bus.chronicle.emit("%s launched %s early, with %d aboard." % [by.display_name, p.name, alive], 3)
		else:
			Bus.chronicle.emit("%s launched as the ferry pulled away, with %d aboard." % [p.name, alive], 2)
	if player_left:
		Game.msg("[b]The lifeboat's rockets kick you into your seat.[/b] It falls away through the clouds toward the port.", "info")
		if Game.hud:
			roster = _snapshot()
			Game.hud.show_round_end(true)
	return true

func pod_of(e: Entity) -> Vessel:
	for p in pods:
		if p.is_on(e.cell):
			return p
	return null

# ------------------------------------------------------------------ departure
func _depart() -> void:
	# tg: the pods go when the shuttle does
	for p in pods.duplicate():
		launch_pod(p)
	var recs := _records(crawler.occupants(), crawler, "crawler")
	if OS.get_cmdline_user_args().has("--evacdebug"):
		var aboard := crawler.occupants()
		for m in Game.all_with(&"brain"):
			if not m in aboard and not m.c(&"health").dead:
				print("EVACDEBUG left behind: %s at %s (%s) - %s" % [m.display_name, m.cell, Game.map.area_at(m.cell).name, m.c(&"brain").status_text()])
	var player_aboard := recs.any(func(r): return r["player"])
	_left.append_array(recs)
	mode = ESCAPE
	timer = ESCAPE_TIME
	roster = _snapshot()
	crawler.remove()
	Sfx.play("engine", dock["cell"], 1.0)
	var n_alive := recs.filter(func(r): return r["status"] in ["escaped", "custody"]).size()
	Bus.announcement.emit("Ferry Departure", "The relief ferry has cast off from the ship with %d crew aboard. Estimated %s to the home port." % [n_alive, _minutes(ESCAPE_TIME)], 1)
	Bus.chronicle.emit("The relief ferry left with %d survivors aboard." % n_alive, 3)
	if player_aboard:
		Game.msg("[b]The ferry lurches forward and slides out across the sky.[/b] The ship shrinks to a smear of light behind you.", "info")
		if Game.hud:
			Game.hud.show_round_end(true)

func _records(mobs: Array, v: Vessel, via: String) -> Array:
	var out := []
	for m in mobs:
		var mob: CMob = m.c(&"mob")
		if mob == null or mob.job == "":
			continue
		var dead: bool = m.c(&"health").dead
		var st := "body_recovered" if dead else ("custody" if m.cell in v.brig_cells else "escaped")
		out.append({"name": m.display_name, "job": Jobs.title(mob.job), "status": st, "player": m == Game.player, "via": via, "id": m.id, "antag": _antag_result(m, st)})
	return out

## tg roundend: each traitor's objectives, judged as they leave (or at the end, if they
## never do). A stolen item only counts if it's still on them.
func _antag_result(m: Entity, status: String) -> Dictionary:
	var b: CBrain = m.c(&"brain")
	if b == null or b.antag.is_empty():
		return {}
	var obj: Dictionary = b.antag
	var lines := []
	match obj.get("kind", ""):
		"sabotage":
			lines.append(["Sabotage the pipes in %s." % obj.get("where", "the ship"), obj.get("done", false)])
		"steal":
			var t := Game.get_entity(obj.get("target", 0))
			lines.append(["Steal the %s." % obj.get("item", "item"), t != null and t.root() == m])
		"kill":
			var v = Game.entities.get(obj.get("target", 0))
			var dead: bool = v == null or not is_instance_valid(v) or v.c(&"health").dead
			lines.append(["Assassinate %s." % obj.get("name", "the target"), dead])
	if obj.get("escape", false):
		lines.append(["Escape alive and free.", status == "escaped"])
	return {"objectives": lines, "win": lines.all(func(l): return l[1])}

## Everyone's fate so far: those who got away, then the people still on the ship.
func _snapshot() -> Array:
	var out := _left.duplicate()
	var gone := {}
	for r in _left:
		gone[r["id"]] = true
	for m in Game.all_with(&"mob"):
		var mob: CMob = m.c(&"mob")
		if mob.job == "" or gone.has(m.id):
			continue
		var dead: bool = m.c(&"health").dead
		var alive_st := "stranded" if mode in [ESCAPE, ENDED] else "on_station"
		var st := "dead" if dead else alive_st
		out.append({"name": m.display_name, "job": Jobs.title(mob.job), "status": st, "player": m == Game.player, "via": "", "id": m.id, "antag": _antag_result(m, st)})
	return out

func _end_round() -> void:
	mode = ENDED
	ended = true
	roster = _snapshot()
	Bus.chronicle.emit("The ferry reached the home port. The voyage is over.", 3)
	if Game.hud:
		Game.hud.show_round_end(false)

# ------------------------------------------------------------------ reporting
func status_text() -> String:
	match mode:
		IDLE:
			return "Ferry: at the home port" + ("" if Game.time >= refuel_delay else " (refuelling, %s)" % _mmss(refuel_delay - Game.time))
		CALLED: return "Ferry ETA %s" % _mmss(timer)
		RECALLED: return "Ferry returning to port"
		DOCKED: return "Ferry DEPARTS in %s" % _mmss(timer)
		ESCAPE: return "Ferry en route to port (%s)" % _mmss(timer)
	return "Shift over"

func summary() -> Dictionary:
	var counts := {"escaped": 0, "custody": 0, "body_recovered": 0, "on_station": 0, "stranded": 0, "dead": 0}
	for r in roster:
		counts[r["status"]] += 1
	return counts

func report_bbcode() -> String:
	var lines := []
	var col := {"escaped": "#6ae88a", "custody": "#8ab8ff", "body_recovered": "#b8a0d8", "on_station": "#c8d4e0", "stranded": "#ffb84a", "dead": "#ff5a4a"}
	var label := {"escaped": "escaped", "custody": "in custody", "body_recovered": "body recovered", "on_station": "on board", "stranded": "left behind", "dead": "died aboard"}
	var s := summary()
	var total := roster.size()
	lines.append("[b]%d of %d crew escaped alive.[/b]  %s%d %s, %d dead." % [s["escaped"] + s["custody"], total, ("%d in custody, " % s["custody"]) if s["custody"] > 0 else "",
		s["stranded"] + s["on_station"], "still on the ship" if s["on_station"] > 0 else "left behind", s["dead"] + s["body_recovered"]])
	lines.append("")
	for st in ["escaped", "custody", "body_recovered", "on_station", "stranded", "dead"]:
		for r in roster:
			if r["status"] == st:
				var how := " [color=#8a9cb0](escape pod)[/color]" if r.get("via", "") == "pod" else ""
				lines.append("[color=%s]%-14s[/color] %s, %s%s%s" % [col[st], label[st], r["name"], r["job"], how, "  [b](you)[/b]" if r["player"] else ""])
	var traitors := roster.filter(func(r): return not r.get("antag", {}).is_empty())
	if not traitors.is_empty():
		lines.append("")
		lines.append("[b]Traitors[/b]")
		for r in traitors:
			var a: Dictionary = r["antag"]
			lines.append("%s, %s: %s" % [r["name"], r["job"], "[color=#6ae88a]SUCCESS[/color]" if a["win"] else "[color=#ff5a4a]FAILED[/color]"])
			for o in a["objectives"]:
				lines.append("   %s %s" % ["[color=#6ae88a]• done[/color]  " if o[1] else "[color=#ff5a4a]• failed[/color]", o[0]])
	var stories := CrewStories.lines()
	if not stories.is_empty():
		lines.append("")
		lines.append("[b]Crew stories[/b]")
		lines.append_array(stories)
	return "\n".join(lines)

static func _mmss(t: float) -> String:
	var s := maxi(0, int(ceil(t)))
	return "%d:%02d" % [s / 60, s % 60]

static func _minutes(t: float) -> String:
	var m := maxi(1, int(round(t / 60.0)))
	return "%d minute%s" % [m, "" if m == 1 else "s"]
