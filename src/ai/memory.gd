class_name Memory extends RefCounted
## Episodic memory + relationships. Meaningful events are remembered with an emotional
## weight; they shape affinity/trust toward the people involved, mood, and what the NPC
## brings up in conversation ("Thanks again for pulling me out of that fire").

class Rel:
	var affinity := 0.0 # -100 .. 100 like/dislike
	var trust := 0.0 # -100 .. 100
	var respect := 0.0
	var familiarity := 0.0 # 0 .. 100

var episodes: Array = [] # {t, type, actor, target, valence, intensity, text, recalled}
var rels := {} # entity id -> Rel
const MAX_EPISODES := 60

## Built-in emotional weights for event types (from the rememberer's point of view).
## "self_" types are about things done to/for the rememberer.
const WEIGHTS := {
	"saved_me": [1.0, 1.0, 45.0, 40.0], # valence, intensity, affinity delta, trust delta
	"treated_me": [0.7, 0.6, 15.0, 15.0],
	"hurt_me": [-1.0, 0.9, -35.0, -30.0],
	"stole_from_me": [-0.8, 0.7, -25.0, -35.0],
	"hugged_me": [0.4, 0.2, 6.0, 3.0],
	"gave_me": [0.4, 0.2, 5.0, 4.0],
	"saw_assault": [-0.6, 0.6, -15.0, -20.0],
	"saw_theft": [-0.3, 0.4, -6.0, -15.0],
	"saw_crime": [-0.4, 0.5, -8.0, -15.0],
	"saw_rescue": [0.5, 0.5, 12.0, 10.0],
	"friend_died": [-1.0, 1.0, 0.0, 0.0],
	"saw_death": [-0.8, 0.8, 0.0, 0.0],
	"friend_hurt_by": [-0.8, 0.7, -30.0, -25.0],
	"workplace_destroyed": [-0.7, 0.6, 0.0, 0.0],
	"good_chat": [0.3, 0.15, 4.0, 2.0],
	"bad_chat": [-0.3, 0.15, -5.0, -2.0],
	"arrested_me": [-0.8, 0.8, -25.0, -10.0],
	"lied_to_me": [-0.6, 0.6, -15.0, -40.0],
	"ordered_me": [0.0, 0.1, 0.0, 0.0],
	"fed_me": [0.5, 0.3, 10.0, 6.0],
	"fixed_my_workplace": [0.4, 0.3, 6.0, 8.0],
	"survived_disaster": [-0.5, 0.8, 0.0, 0.0],
	"betrayed_me": [-1.0, 1.0, -60.0, -80.0],
	"joked": [0.3, 0.1, 3.0, 0.0],
	"helped_me": [0.6, 0.5, 18.0, 20.0],
	"insulted_me": [-0.5, 0.4, -10.0, -8.0],
}

func rel(id: int) -> Rel:
	if not rels.has(id):
		rels[id] = Rel.new()
	return rels[id]

func has_rel(id: int) -> bool:
	return rels.has(id)

func remember(type: String, actor: int, target: int, text: String, scale := 1.0) -> Dictionary:
	var w: Array = WEIGHTS.get(type, [0.0, 0.3, 0.0, 0.0])
	var ep := {"t": Game.time, "type": type, "actor": actor, "target": target, "valence": w[0], "intensity": w[1] * scale, "text": text, "recalled": 0}
	# merge repeats of the same thing
	for old in episodes:
		if old["type"] == type and old["actor"] == actor and Game.time - old["t"] < 60.0:
			old["t"] = Game.time
			old["intensity"] = minf(1.0, old["intensity"] + w[1] * 0.3 * scale)
			return old
	episodes.append(ep)
	if actor > 0 and (w[2] != 0.0 or w[3] != 0.0):
		var r := rel(actor)
		r.affinity = clampf(r.affinity + w[2] * scale, -100.0, 100.0)
		r.trust = clampf(r.trust + w[3] * scale, -100.0, 100.0)
		r.familiarity = minf(100.0, r.familiarity + 5.0)
	if episodes.size() > MAX_EPISODES:
		# forget the least intense old memory
		var worst := 0
		for i in episodes.size():
			if episodes[i]["intensity"] < episodes[worst]["intensity"]:
				worst = i
		episodes.remove_at(worst)
	return ep

func decay(dt: float) -> void:
	for ep in episodes:
		ep["intensity"] = maxf(0.02, ep["intensity"] - dt * 0.00015)

## Most emotionally significant memory involving `id` as actor.
func strongest_about(id: int) -> Dictionary:
	var best := {}
	var bv := 0.0
	for ep in episodes:
		if ep["actor"] == id:
			var v = absf(ep["valence"]) * ep["intensity"]
			if v > bv:
				bv = v
				best = ep
	return best

func recent(type: String, within: float) -> Array:
	var out := []
	for ep in episodes:
		if ep["type"] == type and Game.time - ep["t"] < within:
			out.append(ep)
	return out

## Net recent emotional load (used for mood/stress).
func emotional_load() -> float:
	var v := 0.0
	for ep in episodes:
		var age = Game.time - ep["t"]
		if age < 900.0:
			v += ep["valence"] * ep["intensity"] * (1.0 - age / 900.0)
	return v
