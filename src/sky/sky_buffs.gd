class_name SkyBuffs extends RefCounted
## Timed effects on a person: tonics drunk, curios worn, weather stood in, a dish eaten.
##
## One table rather than a flag on every component, because almost everything in this
## game that changes how a person works wants the same three questions answered — what,
## how much, and for how long — and because a worn item can then simply re-apply its
## effect on a short timer and have removal handled for it. Take the charm off and two
## seconds later the wind can reach you again, with nobody having to remember to clear
## a flag.
##
## Values stack by taking the strongest, not by summing, so drinking four tonics is a
## waste of three tonics and the numbers stay inside a range the rest of the game can
## reason about.

## entity id -> {key: [value, expires_at, source]}
static var _buffs := {}

## What each key means, so the status readout can name it.
const NAMES := {
	"speed": "quick", "slow": "burdened", "carry": "strong", "xp": "clear-headed",
	"armor": "hardened", "altitude": "deep-breathing", "no_fall": "anchored",
	"wind_immune": "unmoved", "good_air": "untroubled", "quiet": "unheard",
	"sight": "far-sighted", "luck": "fortunate", "bleed": "bleeding", "chill": "freezing",
	"scorch": "scorched", "static": "charged", "blind": "dazzled", "sticky": "mired",
}
const COLORS := {
	"speed": "#6ad88a", "carry": "#e8a83a", "xp": "#c88ae8", "armor": "#7fd4ff",
	"altitude": "#6ad88a", "no_fall": "#e8c85a", "wind_immune": "#7fd4ff",
	"good_air": "#6ad88a", "quiet": "#8aa0b4", "sight": "#7fd4ff", "luck": "#e8c85a",
	"slow": "#e8a83a", "bleed": "#ff6a6a", "chill": "#9ad8ff", "scorch": "#ff8a5a",
	"static": "#9ad8ff", "blind": "#ff8a5a", "sticky": "#8a7a5a",
}

static func apply(ent: Entity, key: String, value: float, dur: float, source := "") -> void:
	if ent == null or not is_instance_valid(ent) or ent.removed:
		return
	var id := ent.id
	if not _buffs.has(id):
		_buffs[id] = {}
	var cur = _buffs[id].get(key)
	var until := Game.time + dur
	# strongest wins; an equal-strength refresh extends it
	if cur != null and float(cur[0]) > value and float(cur[1]) > until:
		return
	var was := cur != null and float(cur[1]) > Game.time
	_buffs[id][key] = [maxf(value, float(cur[0]) if cur != null else value), until, source]
	if not was and ent == Game.player and NAMES.has(key):
		Game.tell(ent, "[color=%s]You feel %s.[/color]" % [COLORS.get(key, "#dbe8f4"), NAMES[key]],
			"bad" if key in ["bleed", "chill", "scorch", "blind", "slow", "sticky"] else "good")

static func clear(ent: Entity, key: String) -> void:
	if ent == null or not _buffs.has(ent.id):
		return
	_buffs[ent.id].erase(key)

static func clear_all(ent: Entity) -> void:
	if ent != null:
		_buffs.erase(ent.id)

static func has(ent: Entity, key: String) -> bool:
	return value(ent, key, 0.0) != 0.0

## The current strength of a buff, or `dflt` if it is not running.
static func value(ent: Entity, key: String, dflt := 0.0) -> float:
	if ent == null or not is_instance_valid(ent) or not _buffs.has(ent.id):
		return dflt
	var rec = _buffs[ent.id].get(key)
	if rec == null:
		return dflt
	if float(rec[1]) <= Game.time:
		_buffs[ent.id].erase(key)
		return dflt
	return float(rec[0])

## A multiplier-shaped buff: 1.0 when nothing is running.
static func mult(ent: Entity, key: String) -> float:
	return value(ent, key, 1.0)

## How fast this person walks, as a multiplier on their step time. Lower is faster.
static func step_mult(ent: Entity) -> float:
	var m := 1.0
	var q := value(ent, "speed", 0.0)
	if q > 0.0:
		m *= 1.0 / (1.0 + q)
	var s := value(ent, "slow", 0.0)
	if s > 0.0:
		m *= 1.0 + s
	if has(ent, "sticky"):
		m *= 1.0 + value(ent, "sticky", 0.0)
	return clampf(m, 0.35, 4.0)

## Everything currently running on a person, for the status bar.
static func active(ent: Entity) -> Array:
	var out := []
	if ent == null or not _buffs.has(ent.id):
		return out
	var t := Game.time
	for key in _buffs[ent.id].keys():
		var rec = _buffs[ent.id][key]
		if float(rec[1]) <= t:
			_buffs[ent.id].erase(key)
			continue
		out.append({"key": key, "name": String(NAMES.get(key, key)),
			"color": String(COLORS.get(key, "#dbe8f4")), "left": float(rec[1]) - t,
			"value": float(rec[0])})
	out.sort_custom(func(a, b): return a["left"] < b["left"])
	return out

## Housekeeping: drop expired rows and entities that have gone. Called by SkySystem.
static func tick() -> void:
	var t := Game.time
	for id in _buffs.keys():
		var ent := Game.get_entity(id)
		if ent == null:
			_buffs.erase(id)
			continue
		var tbl: Dictionary = _buffs[id]
		for key in tbl.keys():
			if float(tbl[key][1]) <= t:
				tbl.erase(key)
				if ent == Game.player and NAMES.has(key):
					Game.tell(ent, "[color=#8aa0b4]You stop feeling %s.[/color]" % NAMES[key], "info")
		if tbl.is_empty():
			_buffs.erase(id)

## Wiped between voyages.
static func reset() -> void:
	_buffs.clear()
