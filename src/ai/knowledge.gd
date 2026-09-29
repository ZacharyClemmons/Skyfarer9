class_name Knowledge extends RefCounted
## What one NPC believes about the world. Facts only arrive through perception, hearing,
## radio, conversation, consoles/job training, or personal experience - never by peeking
## at the simulation. Facts can be stale, wrong, or lies someone told them.
##
## Fact dictionary:
##   key       unique id ("fire@12,40", "injured:31", "crime:theft:17")
##   type      fire, hazard_gas, pipe_leak, cable_damaged, breach, power_out, reactor_hot,
##             coolant_low, atmos_alarm, injured, person_down, body, burning_person,
##             broken_machine, mess, crime, wanted, item_at, person_seen, noise, order,
##             supply_request, air_low, sick, my_crime, cold_area
##   subject   entity id (or 0), actor (for crimes), cell, area, severity 0..5, data {}
##   t         time last confirmed, src SEEN/HEARD/TOLD/RADIO/JOB/FELT, from (teller id)
##   conf      0..1 confidence, reported (already passed on over radio)

enum { SEEN, HEARD, TOLD, RADIO, JOB, FELT }
const SRC_NAMES := ["saw", "heard", "was told", "heard on the voice-link", "learned on the job", "felt"]

const TTL := {
	"fire": 45.0, "hazard_gas": 60.0, "pipe_leak": 900.0, "cable_damaged": 900.0, "breach": 900.0,
	"power_out": 240.0, "reactor_hot": 240.0, "reactor_ok": 60.0, "coolant_low": 300.0, "atmos_alarm": 300.0,
	"injured": 150.0, "person_down": 200.0, "body": 1800.0, "burning_person": 20.0, "broken_machine": 900.0,
	"mess": 1200.0, "crime": 2400.0, "wanted": 3600.0, "item_at": 1200.0, "person_seen": 600.0, "noise": 60.0,
	"order": 300.0, "supply_request": 900.0, "air_low": 600.0, "sick": 400.0, "my_crime": 99999.0,
	"cold_area": 300.0, "alarm_clear": 30.0, "food_source": 3000.0,
}

var facts := {}
var owner_id := 0

func learn(f: Dictionary, src: int, conf := 1.0, from := 0) -> Dictionary:
	## Adds or refreshes a fact; returns the stored fact. Marks `new` if it was unknown.
	var key: String = f.get("key", "")
	if key == "":
		return {}
	var existing: Dictionary = facts.get(key, {})
	var nf := f.duplicate()
	nf["t"] = Game.time
	nf["src"] = src
	nf["conf"] = conf
	nf["from"] = from
	if not existing.is_empty():
		# keep firmer beliefs; firsthand beats hearsay
		if existing["conf"] > conf + 0.2 and Game.time - existing["t"] < 30.0 and src != SEEN:
			existing["t"] = Game.time
			return existing
		nf["reported"] = existing.get("reported", false)
		nf["t0"] = existing.get("t0", existing["t"]) # when we first heard of it
		nf["new"] = false
		nf["handled"] = existing.get("handled", false) and nf.get("severity", 0) <= existing.get("severity", 0)
	else:
		nf["reported"] = src == RADIO or src == JOB and nf["type"] in ["atmos_alarm", "reactor_hot"]
		nf["t0"] = Game.time
		nf["new"] = true
		nf["handled"] = false
	facts[key] = nf
	return nf

func forget(key: String) -> void:
	facts.erase(key)

func has(key: String) -> bool:
	return facts.has(key)

func get_fact(key: String) -> Dictionary:
	return facts.get(key, {})

func of_type(type: String) -> Array:
	var out := []
	for f in facts.values():
		if f["type"] == type:
			out.append(f)
	return out

func expire() -> void:
	for key in facts.keys():
		var f: Dictionary = facts[key]
		var ttl: float = TTL.get(f["type"], 600.0)
		if Game.time - f["t"] > ttl:
			facts.erase(key)

## How interesting a fact is to talk about.
func gossip_value(f: Dictionary) -> float:
	var v := {"crime": 6.0, "body": 7.0, "fire": 4.0, "reactor_hot": 5.0, "breach": 3.0, "power_out": 2.5,
		"person_down": 5.0, "wanted": 4.0, "sick": 2.0, "pipe_leak": 1.5, "atmos_alarm": 2.0, "air_low": 2.0}.get(f["type"], 0.0)
	if v <= 0:
		return 0.0
	if f["type"] == "crime" and f.get("data", {}).get("crime", "") == "trespass":
		v = 0.6 # someone was in the wrong room: barely worth mentioning
	var age := Game.time - float(f["t"])
	return v * f.get("conf", 1.0) * clampf(1.0 - age / 900.0, 0.1, 1.0)

func nearest(type: String, from: Vector2i, filter := Callable()) -> Dictionary:
	var best := {}
	var bd := 1e9
	for f in facts.values():
		if f["type"] != type:
			continue
		if filter.is_valid() and not filter.call(f):
			continue
		var c: Vector2i = f.get("cell", Vector2i.ZERO)
		var d := absi(c.x - from.x) + absi(c.y - from.y)
		if d < bd:
			bd = d
			best = f
	return best

## Best known location of an entity (last seen), or (-1,-1).
func where_is(id: int) -> Vector2i:
	var f: Dictionary = facts.get("seen:%d" % id, {})
	if f.is_empty():
		return Vector2i(-1, -1)
	return f["cell"]

func describe(f: Dictionary) -> String:
	var area := Game.map.area_at(f.get("cell", Vector2i.ZERO)).name
	match f["type"]:
		"fire": return "a fire in %s" % area
		"hazard_gas": return "bad air in %s" % area
		"pipe_leak": return "a leaking pipe in %s" % area
		"cable_damaged": return "burnt wiring in %s" % area
		"breach": return "a hull breach in %s" % area
		"power_out": return "no power in %s" % Game.map.areas[f.get("area", 0)].name
		"reactor_hot": return "the reactor overheating"
		"coolant_low": return "the coolant loop losing pressure"
		"injured": return "%s is hurt" % _name(f.get("subject", 0))
		"person_down": return "%s collapsed in %s" % [_name(f.get("subject", 0)), area]
		"body": return "%s is dead, in %s" % [_name(f.get("subject", 0)), area]
		"crime": return "%s %s" % [_name(f.get("data", {}).get("actor", 0)), _crime_text(f)]
		"wanted": return "%s is wanted by the Watch" % _name(f.get("subject", 0))
		"sick": return "%s is sick" % _name(f.get("subject", 0))
		"air_low": return "the air reserves are running low"
		"atmos_alarm": return "the air alarm going off in %s" % area
	return f["type"]

func _crime_text(f: Dictionary) -> String:
	var d: Dictionary = f.get("data", {})
	var area := Game.map.area_at(f.get("cell", Vector2i.ZERO)).name
	match d.get("crime", ""):
		"assault": return "attacked %s in %s" % [_name(d.get("victim", 0)), area]
		"theft": return "stole %s from %s" % [d.get("what", "something"), area]
		"break_in": return "broke into %s" % area
		"trespass": return "was sneaking around %s" % area
		"sabotage": return "sabotaged something in %s" % area
		"vandalism": return "was smashing things in %s" % area
		"murder": return "killed %s" % _name(d.get("victim", 0))
		"fire": return "started a fire in %s" % area
		"explosion": return "caused an explosion in %s" % area
	return "did something shady in %s" % area

static func _name(id: int) -> String:
	var e := Game.get_entity(id)
	if e:
		return e.display_name
	return "someone"
