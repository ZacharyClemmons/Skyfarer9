class_name ShipPlan extends RefCounted
## Deck plans. A plan is a list of equal-length strings read in the ship's own frame:
## +u runs toward the bow, +v runs to starboard, and the row holding the centreline is
## `keel_row`. Airship.stamp() lays one of these onto the region map.
##
## The legend is deliberately small, because a plan has to be readable as text — you
## should be able to see the shape of a ship in a diff. Anything more specific than the
## legend is added afterwards by a fitting function.
##
##   (space) outside the hull        #  hull planking (wall)
##   K  keel timber (heavy)          W  window          w  reinforced window
##   .  weather deck (open air)      ,  deck plating (open air, metal)
##   =  cabin deck (sealed)          I  interior bulkhead
##   +  interior door                A  hull hatch (airlock to open air)
##   h  ship's wheel (helm)          n  navigation table
##   r  rudder post                  m  mast and sail
##   p  propeller nacelle            E  aether thruster
##   B  boiler (burns fuel)          G  dynamo (power)        S  ship's APC
##   L  lift cell (aetherite)        T  fuel bunker           O  ballast tank
##   v  air supply vent              s  scrubber              *  deck lantern
##   c  chair                        b  bunk                  t  table
##   k  crate                        l  locker                o  emergency locker
##   g  gun mount                    C  cargo winch           d  workbench
##   f  galley stove                 M  medical bunk          ?  loot cache (wrecks)

const OUTSIDE := " "
const WALLS := ["#", "K"]
const WINDOWS := ["W", "w"]
const OPEN_DECK := [".", ","]
const SEALED := ["="]
## Everything that sits on a sealed cabin floor rather than the weather deck.
const INDOOR_FITTINGS := ["h", "n", "b", "t", "f", "M", "d", "G", "S", "v", "s", "?"]
## Characters that stop movement where they stand.
const DENSE := ["#", "K", "W", "w", "I", "E", "B", "G", "T", "O", "L", "l", "o", "g", "C", "d", "f", "M", "p", "m", "r"]

# ------------------------------------------------------------------ stock hulls
## kind: the class name shown to the player
## plan / keel: the deck plan and which row is the centreline
## mass: empty displacement in tonnes-ish units; lift and thrust are sized against it
## crew: how many the ship is meant for
## tier: roughly how far into the game it belongs
static var HULLS := {
	# ---------------------------------------------------------------- tier 0
	"skiff": {
		"kind": "skiff", "name": "Skiff", "tier": 0, "crew": 2, "grade": 0,
		"desc": "An open-decked runabout: a boiler, one thruster and a wheel bolted to the deck. \
Nothing between you and the sky but your own sense of balance.",
		"plan": [
			"    ###    ",
			" ###.*.### ",
			"##L.....T##",
			"#EB.h.n..K#",
			"##L.....o##",
			" ###.c.### ",
			"    ###    ",
		],
		"keel": 3,
	},
	# ---------------------------------------------------------------- tier 1
	"cutter": {
		"kind": "cutter", "name": "Cutter", "tier": 1, "crew": 4, "grade": 1,
		"desc": "A sealed wheelhouse over a working deck. The standard hull of every small \
freight house in the Shelf, which is another way of saying it is cheap and everywhere.",
		"plan": [
			"     #####     ",
			"   ##T.*..##   ",
			"  #L..III..L#  ",
			" ##,.I=n=I.,## ",
			"#EB,.+=h=+.,AK#",
			" ##,.I=v=I.,## ",
			"  #L..III..L#  ",
			"   ##..c..##   ",
			"     #####     ",
		],
		"keel": 4,
	},
	"launch": {
		"kind": "launch", "name": "Salvage Launch", "tier": 1, "crew": 3, "grade": 1,
		"desc": "A stubby hull built round a cargo winch. Slow, ugly, and it will lift almost \
anything you can get a line around.",
		"plan": [
			"   #######   ",
			"  #,,,,,,,#  ",
			" #L,IIIII,L# ",
			"#EB,I=h=nI,K#",
			"#EB,I=+==I,C#",
			" #L,IIIII,L# ",
			"  #T,kk,,,#  ",
			"   #######   ",
		],
		"keel": 3,
	},
	# ---------------------------------------------------------------- tier 2
	"sloop": {
		"kind": "sloop", "name": "Sloop", "tier": 2, "crew": 6, "grade": 2,
		"desc": "A proper ship: wheelhouse forward, engine room aft, a hold you can stand up in, \
and bunks for a crew who expect to sleep aboard.",
		"plan": [
			"      #######      ",
			"    ##T,,*,,,##    ",
			"   #L,IIIII+I,L#   ",
			"  #m,I==b=b==I,m#  ",
			" ##,+=+IIIII+=+,## ",
			"#EGB,I=s=h=v=I,.AK#",
			" ##,+=+IIIII+=+,## ",
			"  #m,I==t=M==I,m#  ",
			"   #L,IIIII+I,L#   ",
			"    ##T,,c,,,##    ",
			"      #######      ",
		],
		"keel": 5,
	},
	"barque": {
		"kind": "barque", "name": "Barque", "tier": 2, "crew": 8, "grade": 2,
		"desc": "A long-haul trader. Two thirds of her displacement is hold, and the crew quarters \
are an afterthought wedged behind the wheelhouse.",
		"plan": [
			"        #,,,,,#        ",
			"     #,,,,,*,,,,,#     ",
			"   #L,,,,,,,,,,,,,L#   ",
			"  #m,,IIIIIIIIIII,,m#  ",
			" #,,,,I=kk===kk=I,,,,# ",
			"#EGBT,+=s=bhn=v=+,,,AK#",
			" #EGBTI=t=f=M=d=I,,,K# ",
			"  #m,,IIIIIIIIIII,,m#  ",
			"   #L,,,,,,,,,,,,,L#   ",
			"     #,,,,,C,,,,,#     ",
			"        #,,,,,#        ",
		],
		"keel": 5,
	},
	# ---------------------------------------------------------------- tier 3
	"frigate": {
		"kind": "frigate", "name": "Frigate", "tier": 3, "crew": 10, "grade": 2,
		"desc": "Built to take a hit and return one. Armoured keel, gun mounts to both beams, and \
enough thrust to be somewhere else afterwards.",
		"plan": [
			"       #,,,,,,,#       ",
			"    #,,,,,,g,,,,,,#    ",
			"  #L,,,,,,,,,,,,,,,L#  ",
			" #,,m,IIIIIIIIIII,m,,# ",
			"#,,,,,I=w==w==w=I,,,,K#",
			"#EGBT,+=M=bhn=s=+,,,AK#",
			"#EGBT,I=d=O=O=f=I,,,,K#",
			" #,,m,IIIIIIIIIII,m,,# ",
			"  #L,,,,,,,,,,,,,,,L#  ",
			"    #,,,g,,,,,g,,,#    ",
			"       #,,,,,,,#       ",
		],
		"keel": 5,
	},
}

## Derelicts found drifting or beached on islands. Salvage, or repair and fly home.
static var WRECKS := {
	"wreck_skiff": {
		"kind": "skiff", "name": "wrecked skiff", "tier": 0, "crew": 2, "grade": 0, "derelict": true,
		"desc": "A skiff that came down hard. The boiler is cold and the wheel is split, but the \
hull is mostly there.",
		"plan": [
			"    ## #  ",
			" ##..?.#  ",
			"##L..... #",
			"# B.h.n..K",
			"##..?..# #",
			" ### .##  ",
			"    #     ",
		],
		"keel": 3,
	},
	"wreck_cutter": {
		"kind": "cutter", "name": "gutted cutter", "tier": 1, "crew": 4, "grade": 0, "derelict": true,
		"desc": "Someone stripped her for parts and left the hull where it lay. Whatever they \
could not carry is still aboard.",
		"plan": [
			"     ## ##     ",
			"   ##..?..#    ",
			"  # ..III..L#  ",
			" ##,.I=?=I.,#  ",
			"#  ,.+=h=+.,AK#",
			" ##,.I=?=I., # ",
			"  #L..II ..L#  ",
			"   ## ..c.##   ",
			"     #####     ",
		],
		"keel": 4,
	},
}

## ---------------------------------------------------------------- live layouts
## A stamped ship does not keep its ASCII plan. It keeps a `cells` dictionary of
## Vector2i(u, v) -> character, which is the same information in a form you can add a tile
## to. Everything below works on that, so a hull the player has extended is measured,
## sealed and flown by exactly the same code as one out of the book.

static func to_cells(plan: Array, keel: int) -> Dictionary:
	var out := {}
	for spec in occupied(plan, keel):
		out[Vector2i(spec[0], spec[1])] = spec[2]
	return out

## Bounding box of a live layout, in local (u, v).
static func bounds(cells: Dictionary) -> Rect2i:
	if cells.is_empty():
		return Rect2i()
	var lo := Vector2i(99999, 99999)
	var hi := Vector2i(-99999, -99999)
	for k in cells:
		lo = Vector2i(mini(lo.x, k.x), mini(lo.y, k.y))
		hi = Vector2i(maxi(hi.x, k.x), maxi(hi.y, k.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)

## Empty displacement of a live layout.
static func mass_of(cells: Dictionary) -> float:
	var m := 0.0
	for k in cells:
		var ch: String = cells[k]
		if ch == "K":
			m += 3.0
		elif ch in WALLS or ch in WINDOWS or ch == "I":
			m += 1.4
		elif ch in ["E", "B", "G", "g", "C"]:
			m += 5.0
		elif ch in ["T", "O", "L"]:
			m += 2.0
		else:
			m += 0.7
	return m

## Which cells of a live layout are sealed. Same rule as the plan version: "." and ","
## declare weather deck, everything else takes its answer from a flood fill that starts
## outside the hull and from every weather tile.
static func sealed_of(cells: Dictionary) -> Dictionary:
	var blocks := {}
	var inherit := {}
	var q: Array = []
	for k in cells:
		var ch: String = cells[k]
		if ch in WALLS or ch in WINDOWS or ch == "I" or ch == "+" or ch == "A":
			blocks[k] = true
		elif ch in OPEN_DECK:
			q.append(k)
		else:
			inherit[k] = true
	var b := bounds(cells)
	var lo := b.position - Vector2i.ONE
	var hi := b.end
	for x in range(lo.x, hi.x + 1):
		q.append(Vector2i(x, lo.y))
		q.append(Vector2i(x, hi.y))
	for y in range(lo.y, hi.y + 1):
		q.append(Vector2i(lo.x, y))
		q.append(Vector2i(hi.x, y))
	var open := {}
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		if open.has(c) or blocks.has(c):
			continue
		if c.x < lo.x or c.y < lo.y or c.x > hi.x or c.y > hi.y:
			continue
		open[c] = true
		for d in Defs.DIRS4:
			var n: Vector2i = c + d
			if not open.has(n) and not blocks.has(n):
				q.append(n)
	var sealed := {}
	for k in inherit:
		if not open.has(k):
			sealed[k] = true
	for k in blocks:
		if cells[k] != "+":
			continue
		var inner := 0
		for d in Defs.DIRS4:
			if sealed.has(k + d):
				inner += 1
		if inner >= 2:
			sealed[k] = true
	return sealed

## Cabin tiles the builder asked for but did not enclose: real holes. What the shipwright's
## rig reads out when it tells you why your cabin will not hold air.
static func leaks_of(cells: Dictionary) -> Array:
	var sealed := sealed_of(cells)
	var out := []
	for k in cells:
		if cells[k] in SEALED and not sealed.has(k):
			out.append(k)
	return out

static func get_hull(id: String) -> Dictionary:
	if HULLS.has(id):
		return HULLS[id]
	if WRECKS.has(id):
		return WRECKS[id]
	return HULLS["skiff"]

static func all_ids() -> Array:
	return HULLS.keys()

static func at(plan: Array, u: int, v: int, keel: int) -> String:
	var row := v + keel
	if row < 0 or row >= plan.size():
		return OUTSIDE
	var line: String = plan[row]
	if u < 0 or u >= line.length():
		return OUTSIDE
	return line[u]

static func extent(plan: Array) -> Vector2i:
	var w := 0
	for line in plan:
		w = maxi(w, String(line).length())
	return Vector2i(w, plan.size())

## Every (u, v, char) in a plan that is not empty sky.
static func occupied(plan: Array, keel: int) -> Array:
	var out := []
	for row in plan.size():
		var line: String = plan[row]
		for u in line.length():
			var ch := line[u]
			if ch != OUTSIDE:
				out.append([u, row - keel, ch])
	return out

static func is_wall(ch: String) -> bool:
	return ch in WALLS

static func is_window(ch: String) -> bool:
	return ch in WINDOWS

## Which plan cells are genuinely sealed spaces.
##
## Two things decide this, and they answer different questions. The character says what
## the builder *meant*: "." and "," are weather deck, open to the sky however much hull
## surrounds them, while "=" and the fittings that belong below decks mean a roofed cabin.
## The flood fill then says whether that intent actually holds — it starts from outside the
## hull *and* from every weather-deck tile, and anything it can reach is exposed. So a
## cabin with a missing bulkhead is correctly treated as open air rather than pretending to
## hold pressure, and a hull the player has built themselves seals the moment they close
## the last gap.
static func sealed_cells(plan: Array, keel: int) -> Dictionary:
	var ex := extent(plan)
	var blocks := {}
	var inherit := {}  # fittings: sealed or not according to where they stand
	var weather := []  # open to the sky by definition
	for spec in occupied(plan, keel):
		var key := Vector2i(spec[0], spec[1] + keel)
		var ch: String = spec[2]
		if ch in WALLS or ch in WINDOWS or ch == "I" or ch == "+" or ch == "A":
			blocks[key] = true
		elif ch in OPEN_DECK:
			weather.append(key)
		else:
			inherit[key] = true
	# flood the weather in from beyond the hull and from every open deck tile
	var open := {}
	var q: Array = weather.duplicate()
	for x in range(-1, ex.x + 1):
		q.append(Vector2i(x, -1))
		q.append(Vector2i(x, ex.y))
	for y in range(-1, ex.y + 1):
		q.append(Vector2i(-1, y))
		q.append(Vector2i(ex.x, y))
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		if open.has(c) or blocks.has(c):
			continue
		if c.x < -1 or c.y < -1 or c.x > ex.x or c.y > ex.y:
			continue
		open[c] = true
		for d in Defs.DIRS4:
			var n: Vector2i = c + d
			if not open.has(n) and not blocks.has(n):
				q.append(n)
	var sealed := {}
	for key in inherit:
		if not open.has(key):
			sealed[Vector2i(key.x, key.y - keel)] = true
	# a door with sealed space on both sides is part of that space
	for key in blocks:
		if String(at(plan, key.x, key.y - keel, keel)) != "+":
			continue
		var inner := 0
		for d in Defs.DIRS4:
			if sealed.has(Vector2i(key.x + d.x, key.y + d.y - keel)):
				inner += 1
		if inner >= 2:
			sealed[Vector2i(key.x, key.y - keel)] = true
	return sealed

## Sealed tiles the builder asked for but did not enclose: real holes in a cabin. Used by
## the hull validator and by the shipyard when it tells you why your cabin will not hold air.
static func leaks(plan: Array, keel: int) -> Array:
	var sealed := sealed_cells(plan, keel)
	var out := []
	for spec in occupied(plan, keel):
		var ch: String = spec[2]
		if ch in SEALED and not sealed.has(Vector2i(spec[0], spec[1])):
			out.append(Vector2i(spec[0], spec[1]))
	return out

static func is_sealed_floor(ch: String) -> bool:
	return ch in SEALED

static func is_dense(ch: String) -> bool:
	return ch in DENSE

## Empty displacement, counted off the plan: hull and fittings both weigh something, so a
## bigger ship needs more lift whether or not you load it.
static func hull_mass(plan: Array, keel: int) -> float:
	var m := 0.0
	for cell in occupied(plan, keel):
		var ch: String = cell[2]
		if ch == "K":
			m += 3.0
		elif ch in WALLS or ch in WINDOWS or ch == "I":
			m += 1.4
		elif ch in ["E", "B", "G", "g", "C"]:
			m += 5.0
		elif ch in ["T", "O", "L"]:
			m += 2.0
		else:
			m += 0.7
	return m

## How much lift the plan's lift cells make, and how much thrust its thrusters make.
static func count_char(plan: Array, keel: int, ch: String) -> int:
	var n := 0
	for cell in occupied(plan, keel):
		if cell[2] == ch:
			n += 1
	return n

## A short, honest summary for the shipyard list.
static func summary(id: String) -> String:
	var h := get_hull(id)
	var plan: Array = h["plan"]
	var keel: int = h["keel"]
	var ex := extent(plan)
	return "%-16s %2dx%-2d  mass %5.0f  lift %d  thrust %d  crew %d" % [
		h["name"], ex.x, ex.y, hull_mass(plan, keel),
		count_char(plan, keel, "L"), count_char(plan, keel, "E"), h["crew"]]

# ------------------------------------------------------------------ diagnosis
## Why can't I build this? Every problem with a layout, ranked worst first, in words a
## player can act on, with the cells to highlight.
##
##   ShipPlan.diagnose(cells, fittings, opts) -> Array of
##     {"severity": "error"|"warn"|"info", "rank": 2|1|0, "code": String,
##      "text": String, "cells": Array[Vector2i]}
##
## `error` means she will not fly (or cannot be built); `warn` means she flies badly or
## dangerously; `info` is advice. `cells` may be empty when the problem is an absence (no
## helm): the UI should then just show the text. Pass `opts.who` (an Entity) to also flag
## modules the builder lacks the skill to fit. `ShipPlan.can_build(issues)` is true when no
## entry is an error; `ShipPlan.diagnose_text(issues)` makes a tooltip.
const SEV_ERROR := "error"
const SEV_WARN := "warn"
const SEV_INFO := "info"

static func _issue(sev: String, code: String, text: String, at: Array = []) -> Dictionary:
	return {"severity": sev, "rank": {"error": 2, "warn": 1, "info": 0}[sev],
		"code": code, "text": text, "cells": at}

static func can_build(issues: Array) -> bool:
	for i in issues:
		if i["severity"] == SEV_ERROR:
			return false
	return true

## Connected components of a layout (4-neighbour), largest first.
static func components_of(cells: Dictionary) -> Array:
	var seen := {}
	var out := []
	for k in cells:
		if seen.has(k):
			continue
		var comp := [k]
		seen[k] = true
		var head := 0
		while head < comp.size():
			var c: Vector2i = comp[head]
			head += 1
			for d in Defs.DIRS4:
				var nb: Vector2i = c + d
				if cells.has(nb) and not seen.has(nb):
					seen[nb] = true
					comp.append(nb)
		out.append(comp)
	out.sort_custom(func(a, b): return a.size() > b.size())
	return out

static func diagnose(cells: Dictionary, fittings: Dictionary = {}, opts: Dictionary = {}) -> Array:
	var out: Array = []
	if cells.is_empty():
		out.append(_issue(SEV_ERROR, "empty", "Nothing drawn yet. Start with a hull outline and a deck."))
		return out
	var by := {}  # glyph -> [cells]
	for k in cells:
		var g := String(cells[k])
		if not by.has(g):
			by[g] = []
		by[g].append(k)
	# the effective module in each hole (stock fitting where none was chosen)
	var mods := {}
	for k in cells:
		var id := String(fittings.get(k, ShipParts.default_for(String(cells[k]))))
		if id != "":
			mods[k] = id
	var cnt := func(g: String) -> int:
		return (by[g] as Array).size() if by.has(g) else 0
	var listof := func(g: String) -> Array:
		return (by[g] as Array).duplicate() if by.has(g) else []
	# ---- structure
	var comps := components_of(cells)
	if comps.size() > 1:
		var stray := []
		for i in range(1, comps.size()):
			stray.append_array(comps[i])
		out.append(_issue(SEV_ERROR, "disconnected",
			"She is in %d pieces. Every tile has to touch the rest; the highlighted %s would be left behind." % [
				comps.size(), "tiles" if stray.size() != 1 else "tile"], stray))
	# ---- the wheel
	if cnt.call("h") == 0:
		out.append(_issue(SEV_ERROR, "no_helm", "No helm. Nobody can steer her: place a wheel (h) on the deck."))
	else:
		if cnt.call("h") > 1:
			out.append(_issue(SEV_WARN, "many_helms", "More than one wheel. Only the first will answer.", listof.call("h")))
		var boxed := []
		for k in by["h"]:
			var free := false
			for d in Defs.DIRS4:
				var nb: Vector2i = k + d
				if cells.has(nb) and not is_dense(String(cells[nb])):
					free = true
			if not free:
				boxed.append(k)
		if not boxed.is_empty():
			out.append(_issue(SEV_ERROR, "helm_boxed",
				"The wheel is walled in: nobody can stand next to it. Open a deck tile beside it.", boxed))
	# ---- lift
	var lift_units := 0.0
	for k in by.get("L", []):
		lift_units += ShipParts.stat(String(mods.get(k, "")), "lift", 1.0)
	if cnt.call("L") == 0 or lift_units <= 0.0:
		out.append(_issue(SEV_ERROR, "no_lift", "No lift cells. She is a shed with a wheel: add lift cells (L)."))
	elif cnt.call("L") == 1:
		out.append(_issue(SEV_WARN, "one_lift", "One lift cell. Lose it and she drops like a stone; fit at least two, one either side.", listof.call("L")))
	else:
		var lo := 99999
		var hi := -99999
		for k in by["L"]:
			lo = mini(lo, k.y)
			hi = maxi(hi, k.y)
		if lo > 0 or hi < 0:
			out.append(_issue(SEV_INFO, "lift_lopsided", "All the lift is on one side of the keel. She will lean.", listof.call("L")))
	# ---- propulsion, steam and fuel
	var thrust := 0.0
	var sail := 0.0
	for k in mods:
		thrust += ShipParts.stat(String(mods[k]), "thrust", 0.0)
		sail += ShipParts.stat(String(mods[k]), "sail", 0.0)
	if thrust <= 0.0 and sail <= 0.0:
		out.append(_issue(SEV_ERROR, "no_engine", "Nothing to move her. Fit a thruster (E) or a mast (m)."))
	var engines: int = cnt.call("E")
	if engines > 0 and cnt.call("B") == 0:
		out.append(_issue(SEV_ERROR, "no_boiler", "Thrusters and no boiler. The injectors need steam: add a boiler (B).", listof.call("E")))
	if (engines > 0 or cnt.call("B") > 0) and cnt.call("T") == 0:
		out.append(_issue(SEV_ERROR, "no_bunker", "No fuel bunker. Nowhere to keep the distillate: add a bunker (T).", listof.call("B") + listof.call("E")))
	if engines > 0 and cnt.call("B") > 0:
		var steam := 0.0
		for k in by["B"]:
			steam += ShipParts.stat(String(mods.get(k, "")), "steam", 1.0)
		if steam < float(engines) * 0.6:
			out.append(_issue(SEV_WARN, "weak_boiler",
				"%d thruster%s on %s. The boiler cannot keep up at full throttle: fit a bigger boiler or a second one." % [
					engines, "" if engines == 1 else "s", "one small boiler" if cnt.call("B") == 1 else "these boilers"], listof.call("B")))
	# ---- air
	var sealed := sealed_of(cells)
	var hot := []
	for g in ["E", "B"]:
		for k in by.get(g, []):
			if sealed.has(k):
				hot.append(k)
	if not hot.is_empty() and cnt.call("s") == 0 and cnt.call("v") == 0:
		out.append(_issue(SEV_WARN, "engine_indoors",
			"An engine in a sealed space with no scrubber or vent. It will cook and choke the crew: open it to the deck or add a scrubber (s).", hot))
	var leaks := leaks_of(cells)
	if not leaks.is_empty():
		out.append(_issue(SEV_WARN, "leaks", "%d cabin tile%s open to the weather. Close the highlighted gaps or it will not hold air." % [
			leaks.size(), "" if leaks.size() == 1 else "s"], leaks))
	var crowd := []
	for k in by.get("T", []):
		for d in Defs.DIRS8:
			if String(cells.get(k + d, "")) == "B":
				crowd.append(k)
				break
	if not crowd.is_empty():
		out.append(_issue(SEV_WARN, "bunker_boiler", "A fuel bunker against the boiler. This has been done before. It went badly.", crowd))
	# ---- fittings that do not belong
	var bad_mod := []
	var lacking := []
	var who = opts.get("who", null)
	for k in fittings:
		var fid := String(fittings[k])
		if not cells.has(k):
			continue
		if not ShipParts.exists(fid) or not ShipParts.fits_glyph(fid, String(cells[k])):
			bad_mod.append(k)
		elif who != null and is_instance_valid(who):
			var req: Dictionary = ShipParts.get_mod(fid).get("req", {})
			for sk in req:
				if Skills.level(who, String(sk)) < int(req[sk]):
					lacking.append(k)
					break
	if not bad_mod.is_empty():
		out.append(_issue(SEV_ERROR, "bad_module", "A module does not fit its hole. Swap it for one made for that slot.", bad_mod))
	if not lacking.is_empty():
		out.append(_issue(SEV_ERROR, "skill_gate", "You lack the skill to fit %s. Choose something plainer or train up." % (
			"this module" if lacking.size() == 1 else "these modules"), lacking))
	# ---- power draw
	var power := 0.0
	for k in mods:
		power += ShipParts.stat(String(mods[k]), "power", 0.0)
	if power < 0.0:
		out.append(_issue(SEV_WARN if cnt.call("p") > 0 else SEV_INFO, "power_short", "More electrical draw (%d W) than her generators make. Something will not run: add a dynamo (G)." % int(-power), listof.call("p")))
	# ---- crew comforts
	var walk := 0
	for k in cells:
		if not is_dense(String(cells[k])):
			walk += 1
	if walk < 3:
		out.append(_issue(SEV_WARN, "no_deck", "Almost nowhere to stand. A crew needs deck."))
	if cnt.call("*") == 0:
		out.append(_issue(SEV_INFO, "no_lantern", "No lantern. Night at altitude is very dark."))
	if cnt.call("b") == 0 and cnt.call("M") == 0 and walk >= 40:
		out.append(_issue(SEV_INFO, "no_bunk", "No bunks. The crew will sleep on the deck, and complain."))
	# worst first; stable within a rank
	var idx := 0
	for it in out:
		it["_i"] = idx
		idx += 1
	out.sort_custom(func(a, b): return a["rank"] > b["rank"] or (a["rank"] == b["rank"] and a["_i"] < b["_i"]))
	for it in out:
		it.erase("_i")
	return out

## One line per issue, worst first, for a tooltip or the message log.
static func diagnose_text(issues: Array) -> String:
	var lines := []
	for i in issues:
		lines.append("%s %s" % [{"error": "[X]", "warn": "[!]", "info": "[i]"}[i["severity"]], i["text"]])
	return "\n".join(lines)
