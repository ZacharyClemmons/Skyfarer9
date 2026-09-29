class_name Experience extends RefCounted
## What an NPC learns over the shift, on top of the facts in Knowledge and the feelings
## in Memory:
##  - Outcomes: which of their goals work and which keep failing. A goal that fails over
##    and over loses its appeal (they stop banging their head on the locked door); one
##    that works gets a little favoured. Nothing is hard-coded: it's a running record.
##  - Places: rooms where they got hurt, saw a death, choked or froze feel dangerous and
##    they steer clear; rooms where good things happened become favourite haunts that they
##    drift to on breaks.
##  - Reputations: what they've seen (or heard) people do: violent, helpful, thieving,
##    skilled, funny, dishonest. It shapes trust, favours and what they tell others about
##    them. A player who punches people gets a reputation that spreads by gossip.
##  - Picked-up ideas: interests and tips passed on by friends.

## Reputation dimensions, -1..1 (well, 0..1 for most).
const REP_KEYS := ["violent", "helpful", "thief", "competent", "funny", "liar", "brave", "lazy", "kind", "creepy"]

var outcomes := {} # goal id -> {ok, fail, last}
var danger := {} # area id -> 0..1
var comfort := {} # area id -> 0..1
var danger_why := {} # area id -> short reason
var rep := {} # entity id -> {key: value}
var rep_src := {} # entity id -> {key: "saw" / "heard"}
var learned_tips := {} # skill -> times taught
var mentors := {} # entity id -> times they taught us
var picked_up := [] # interest ids learned from others
var seen_aurora := false
var arcade_best := 0
var arcade_plays := 0

# ------------------------------------------------------------------ outcomes
func record(goal_id: String, ok: bool) -> void:
	if goal_id == "" or goal_id in ["idle", "follow", "chat", "custody"]:
		return
	var o: Dictionary = outcomes.get(goal_id, {"ok": 0, "fail": 0, "last": 0.0})
	if ok:
		o["ok"] += 1
	else:
		o["fail"] += 1
	o["last"] = Game.time
	outcomes[goal_id] = o

## Score multiplier from past results. Recent failures sting; they fade with time.
func goal_bias(goal_id: String) -> float:
	var o: Dictionary = outcomes.get(goal_id, {})
	if o.is_empty():
		return 1.0
	var recent := clampf(1.0 - (Game.time - float(o["last"])) / 600.0, 0.0, 1.0)
	var fails: float = o["fail"] * (0.4 + recent * 0.6)
	return clampf(1.0 + o["ok"] * 0.03 - fails * 0.09, 0.45, 1.25)

func failures(goal_id: String) -> int:
	return outcomes.get(goal_id, {}).get("fail", 0)

# ------------------------------------------------------------------ places
func scare(area_id: int, amount: float, why: String) -> void:
	if area_id <= 0:
		return
	danger[area_id] = clampf(danger.get(area_id, 0.0) + amount, 0.0, 1.0)
	if amount >= 0.2 or not danger_why.has(area_id):
		danger_why[area_id] = why

func soothe(area_id: int, amount: float) -> void:
	if area_id <= 0:
		return
	comfort[area_id] = clampf(comfort.get(area_id, 0.0) + amount, 0.0, 1.0)

func danger_of(area_id: int) -> float:
	return danger.get(area_id, 0.0)

func decay(dt: float) -> void:
	for k in danger.keys():
		danger[k] = maxf(0.0, danger[k] - dt * 0.0006)
		if danger[k] <= 0.0:
			danger.erase(k)
			danger_why.erase(k)

## Favourite place to unwind, if they have one.
func favourite_area() -> int:
	var best := -1
	var bv := 0.25
	for k in comfort:
		var v: float = comfort[k] - danger.get(k, 0.0)
		if v > bv:
			bv = v
			best = k
	return best

func scariest_area() -> int:
	var best := -1
	var bv := 0.3
	for k in danger:
		if danger[k] > bv:
			bv = danger[k]
			best = k
	return best

# ------------------------------------------------------------------ reputations
func note(id: int, key: String, amount: float, firsthand := true) -> void:
	if id <= 0:
		return
	if not rep.has(id):
		rep[id] = {}
		rep_src[id] = {}
	var r: Dictionary = rep[id]
	r[key] = clampf(r.get(key, 0.0) + amount, -1.0, 1.0)
	if firsthand or not rep_src[id].has(key):
		rep_src[id][key] = "saw" if firsthand else "heard"

func rep_of(id: int, key: String) -> float:
	return rep.get(id, {}).get(key, 0.0)

## The most notable thing about someone, as [key, value, source], or [].
func headline(id: int) -> Array:
	var r: Dictionary = rep.get(id, {})
	var best := ""
	var bv := 0.18
	for k in r:
		if absf(r[k]) > bv:
			bv = absf(r[k])
			best = k
	if best == "":
		return []
	return [best, r[best], rep_src.get(id, {}).get(best, "heard")]

## Everything notable, strongest first.
func notable(id: int) -> Array:
	var r: Dictionary = rep.get(id, {})
	var out := []
	for k in r:
		if absf(r[k]) > 0.15:
			out.append([k, r[k]])
	out.sort_custom(func(a, b): return absf(a[1]) > absf(b[1]))
	return out

## How much this reputation makes us trust someone (-1..1).
func trust_mod(id: int) -> float:
	var r: Dictionary = rep.get(id, {})
	return clampf(r.get("helpful", 0.0) * 0.5 + r.get("kind", 0.0) * 0.4 + r.get("competent", 0.0) * 0.2
		- r.get("violent", 0.0) * 0.6 - r.get("thief", 0.0) * 0.6 - r.get("liar", 0.0) * 0.7 - r.get("creepy", 0.0) * 0.3, -1.0, 1.0)

## Share reputation second-hand (gossip): dampened, and only what the teller believes.
func hear_rep(id: int, key: String, value: float, trust: float) -> void:
	if absf(value) < 0.15:
		return
	var cur := rep_of(id, key)
	var delta := (value * 0.5 - cur) * clampf(trust, 0.0, 1.0) * 0.5
	if absf(delta) > 0.02:
		note(id, key, delta, false)

static func rep_word(key: String, v: float) -> String:
	if v < 0:
		return {"violent": "gentle", "helpful": "unhelpful", "thief": "honest", "competent": "useless", "funny": "dull",
			"liar": "honest", "brave": "a coward", "lazy": "hard-working", "kind": "cold", "creepy": "normal"}.get(key, key)
	return {"violent": "violent", "helpful": "helpful", "thief": "a thief", "competent": "good at their job", "funny": "funny",
		"liar": "a liar", "brave": "brave", "lazy": "lazy", "kind": "kind", "creepy": "creepy"}.get(key, key)
