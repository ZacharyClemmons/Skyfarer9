class_name ShipHazards extends RefCounted
## What the sky does to a ship that is not properly closed up.
##
## Four linked mechanics, all driven off the real tile map and the real atmos rather than
## flags, so a hull you draw yourself is punished (or spared) for exactly what you drew:
##
##  * **Apparent wind.** The weather's wind minus the ship's own velocity. Flying fast into
##    a calm sky is a gale on deck.
##  * **Draughts.** Every opening from the weather deck into an inside room (a hole, a
##    window, a door somebody left open) pours that wind along the corridor behind it,
##    fading with distance. A draught steals heat from the room, gutters lanterns, chills
##    the people standing in it and fans any fire it reaches. Close the door, plank the
##    hole, put a bulkhead across the passage.
##  * **The weather deck.** In a real blow, anyone on open deck with nothing solid beside
##    them is buffeted and can be thrown down. A bulwark or a wall to lean on is the fix.
##  * **Fire and water.** Fire burns the hull it stands on and spreads downwind. Below
##    deck a sprung seam lets the bilge fill; wading slows you, lamps go out, and the
##    water is weight the ship has to carry. A pump and a plank are the answer.
##
## The companionway joins the two decks: warm air climbs it, and so does smoke.

const TICK := 0.5
const GALE := 2.2            # apparent wind at which open deck becomes dangerous
const BREEZE := 0.9
const MAX_DEPTH := 7

## ship id -> per-ship scratch: {"draught": {cell: 0..1}, "wind": float, "blown": [lights], ...}
static var _st := {}

static func reset() -> void:
	_st.clear()

static func state(sh: Airship) -> Dictionary:
	if not _st.has(sh.id):
		_st[sh.id] = {"draught": {}, "wind": 0.0, "scan_t": -99.0, "blown": [], "lit_bilge": 0,
			"openings": 0, "fires": 0, "note_t": {}, "worst": 0.0, "bilge_lvl": 0}
	return _st[sh.id]

## The wind a person on this deck feels, in tiles/s-ish units. Vector points where the
## air is going relative to the hull.
static func apparent_wind(sh: Airship) -> Vector2:
	var w := Vector2.ZERO
	if Game.sky != null:
		w = Game.sky.wind_vector()
	return w * 1.6 - sh.vel * 0.7

static func wind_strength(sh: Airship) -> float:
	return apparent_wind(sh).length()

static func wind_word(s: float) -> String:
	if s < 0.35: return "still air"
	if s < BREEZE: return "a light breeze"
	if s < 1.6: return "a stiff wind"
	if s < GALE: return "a hard blow"
	return "a howling gale"

## 0..1 draught in a world cell (0 where it is snug).
static func draught_at(sh: Airship, c: Vector2i) -> float:
	if sh == null or not _st.has(sh.id):
		return 0.0
	return float(state(sh)["draught"].get(c, 0.0))

## Openings from the weather into the inside of the ship.
static func openings(sh: Airship) -> Array:
	var out := []
	var map := Game.map
	for c in sh.inside_cells:
		if map.blocks_air(c):
			continue
		for d in Defs.DIRS4:
			var n: Vector2i = c + d
			if not map.inb(n) or map.blocks_air(n):
				continue
			if map.is_outdoor(n) or Defs.is_void_turf(map.get_turf(n)):
				out.append(c)
				break
	return out

# ------------------------------------------------------------------ the tick
static func tick(sh: Airship, dt: float) -> void:
	if sh == null or not sh.present or Game.map == null:
		return
	var st := state(sh)
	var aw := wind_strength(sh)
	st["wind"] = aw
	if Game.time - float(st["scan_t"]) > 2.0:
		st["scan_t"] = Game.time
		_scan_draughts(sh, st, aw)
	_apply_draughts(sh, st, aw, dt)
	_open_deck(sh, st, aw, dt)
	_fire(sh, st, aw, dt)
	_companionway(sh, dt)
	_bilge(sh, st, aw, dt)

# ------------------------------------------------------------------ draughts
static func _scan_draughts(sh: Airship, st: Dictionary, aw: float) -> void:
	var map := Game.map
	var force := clampf(aw / 2.0, 0.0, 1.0)
	var out := {}
	var ops := openings(sh)
	st["openings"] = ops.size()
	# a bigger hole passes more air than a keyhole: strength grows with how many there are
	var many := 1.0 + minf(float(ops.size()) - 1.0, 4.0) * 0.12
	for src in ops:
		var seen := {src: 0}
		var q: Array = [src]
		while not q.is_empty():
			var c: Vector2i = q.pop_front()
			var dist: int = seen[c]
			var s := force * many * (1.0 - float(dist) / float(MAX_DEPTH + 1))
			if s > float(out.get(c, 0.0)):
				out[c] = minf(s, 1.0)
			if dist >= MAX_DEPTH:
				continue
			for d in Defs.DIRS4:
				var n: Vector2i = c + d
				if seen.has(n) or not map.inb(n) or map.blocks_air(n) or map.is_outdoor(n):
					continue
				if not sh.inside_cells.has(n):
					continue
				seen[n] = dist + 1
				q.append(n)
	st["draught"] = out
	var worst := 0.0
	for c in out:
		worst = maxf(worst, float(out[c]))
	st["worst"] = worst

static func _apply_draughts(sh: Airship, st: Dictionary, aw: float, dt: float) -> void:
	var dr: Dictionary = st["draught"]
	var atmos = Game.atmos
	var outside := Defs.sky_temp(sh.altitude)
	var blown: Array = st["blown"]
	# heat goes out of the room down the draught: the more wind, the faster
	if atmos != null:
		for c in dr:
			var s: float = dr[c]
			if s < 0.08:
				continue
			var i: int = Game.map.idx(c)
			if atmos.temp[i] > outside + 2.0:
				atmos.add_heat(i, -2400.0 * s * (0.5 + aw * 0.5) * dt)
	# people in it
	for c in dr:
		var s2: float = dr[c]
		if s2 < 0.2:
			continue
		for ent in Game.at(c):
			if not ent.has_c(&"mob") or SkyBuffs.has(ent, "wind_immune"):
				continue
			SkyBuffs.apply(ent, "draught", s2, 3.0, "draught")
			var h: CHealth = ent.c(&"health")
			if h != null and not h.dead and sh.altitude > 1.0 and h.body_temp > Defs.BODYTEMP_NORMAL - 25.0:
				h.body_temp -= 0.35 * s2 * (sh.altitude / 4.0) * dt * 2.0
			_note(st, ent, "draught", 25.0,
				"[color=#9ad8ff]A draught cuts through here — wind is finding a way in from outside.[/color]")
	# lamps: flicker in a draught, go out in a strong one, come back when it eases
	for ent in Game.all_with(&"light"):
		var l: CLight = ent.c(&"light")
		if l == null or l.kind != "always" or not sh.is_aboard(ent):
			continue
		var s3 := float(dr.get(ent.cell, 0.0))
		if ent.cell.y < SkyGen.H:
			s3 = maxf(s3, clampf((aw - BREEZE) / 2.0, 0.0, 1.0)) if _exposed(ent.cell) else s3
		if s3 > 0.3:
			l.flicker = maxf(l.flicker, 1.0)
		if s3 > 0.75 and l.on and Game.rng.randf() < dt * 0.5:
			l.on = false
			blown.append(ent)
			Game.visible_message(ent.cell, "[color=#c8b88a]The wind gutters a lamp out.[/color]", "warn")
	for ent in blown.duplicate():
		if not is_instance_valid(ent) or ent.removed:
			blown.erase(ent)
		elif float(dr.get(ent.cell, 0.0)) < 0.3 and (ent.cell.y >= SkyGen.H or not _exposed(ent.cell) or aw < GALE * 0.8):
			var l2: CLight = ent.c(&"light")
			if l2 != null:
				l2.on = true
			blown.erase(ent)

static func _exposed(c: Vector2i) -> bool:
	return Game.map.is_outdoor(c)

# ------------------------------------------------------------------ the open deck
static func _open_deck(sh: Airship, st: Dictionary, aw: float, dt: float) -> void:
	if aw < BREEZE:
		return
	for ent in sh.occupants():
		if ent.cell.y >= SkyGen.H or not _exposed(ent.cell) or SkyBuffs.has(ent, "wind_immune"):
			continue
		# lee: a wall or bulwark upwind of you takes the worst of it
		var lee := false
		for d in Defs.DIRS4:
			var n: Vector2i = ent.cell + d
			if Game.map.is_wall(n) or Game.map.blocks_air(n):
				lee = true
				break
		var force := aw * (0.45 if lee else 1.0)
		if force > BREEZE * 1.4:
			SkyBuffs.apply(ent, "slow", clampf((force - BREEZE * 1.4) * 0.12, 0.0, 0.5), 2.0, "wind")
		if force > GALE and Game.rng.randf() < dt * (force - GALE + 0.3) * 0.12:
			var h: CHealth = ent.c(&"health")
			if h != null and not h.dead and h.has_method("knockdown"):
				h.knockdown(10.0)
				Game.tell(ent, "[color=#e8a83a]A gust slams you into the deck! Get to the lee of something.[/color]", "warn")
		elif not lee and force > BREEZE * 1.4:
			_note(st, ent, "exposed", 40.0,
				"[color=#9ad8ff]The wind is %s up here — there's nothing to shelter behind.[/color]" % wind_word(force))

# ------------------------------------------------------------------ fire
static func _fire(sh: Airship, st: Dictionary, aw: float, dt: float) -> void:
	var atmos = Game.atmos
	if atmos == null:
		return
	var map := Game.map
	var wv := apparent_wind(sh)
	var down := Vector2i(signi(int(signf(-wv.x) * ceilf(absf(wv.x)))), signi(int(signf(-wv.y) * ceilf(absf(wv.y)))))
	var own := {}
	for c in sh.cells:
		own[c] = true
	for c in sh.lower_cells:
		own[c] = true
	# a flame on the stove that the wind reaches jumps to whatever is beside it
	for ent in Game.all_with(&"cooker"):
		if ent.proto != "galley_stove" or not own.has(ent.cell):
			continue
		var ck: CCooker = ent.c(&"cooker")
		if ck != null and ck.cooking > 0.0:
			atmos.add_heat(map.idx(ent.cell), 1400.0 * dt)
			if float(st["draught"].get(ent.cell, 0.0)) > 0.35 and Game.rng.randf() < dt * 0.04:
				var d: Vector2i = Defs.DIRS4[Game.rng.randi() % 4]
				if not map.blocks_air(ent.cell + d):
					Game.visible_message(ent.cell, "[b][color=#ff8a3a]The draught throws a flame off the stove![/color][/b]", "bad")
					atmos.ignite(ent.cell + d, null, 6.0)
	var fires := 0
	for c in atmos.hotspots.keys():
		if not own.has(c):
			continue
		fires += 1
		var idx := map.idx(c)
		var lower: bool = c.y >= SkyGen.H
		# planking burns
		var t := map.turf[idx]
		if t == Defs.T_HULLWOOD or t == Defs.T_DECK or t == Defs.T_DECK_OPEN:
			map.turf_hp[idx] -= 3.0 * dt * 2.0
			if map.turf_hp[idx] <= 0.0 and not lower and t != Defs.T_DECK_OPEN:
				sh.breach(c)
				Game.visible_message(c, "[b][color=#ff6a3a]The burnt planking gives way![/color][/b]", "bad")
				map.turf_hp[idx] = 30.0
		# wind: fans it downwind, snuffs it on open deck in a gale
		var draught := float(st["draught"].get(c, 0.0))
		var blow := clampf(aw / 2.0, 0.0, 1.5) * (1.0 if not lower else 0.0) + draught
		if blow > 0.4 and Game.rng.randf() < dt * blow * 0.5:
			var n: Vector2i = c + down
			if down != Vector2i.ZERO and own.has(n) and not map.blocks_air(n):
				atmos.ignite(n, null, 5.0)
		if not lower and _exposed(c) and aw > GALE * 1.3 and Game.rng.randf() < dt * 0.25:
			atmos.extinguish(c)
			Game.visible_message(c, "[color=#c8b88a]The gale tears the flames off the deck and away.[/color]", "info")
	if fires > int(st["fires"]) and sh.is_aboard(Game.player):
		Game.msg("[b][color=#ff8a3a]FIRE aboard %s![/color][/b] [i]Extinguisher, water — or starve it of air.[/i]" % sh.ship_name, "bad")
	st["fires"] = fires

# ------------------------------------------------------------------ the companionway
## Heat and smoke climb the stairs. The deck below is a separate room, so this is the only
## way a galley fire reaches the weather deck, and the only way a cold deck gets warmed.
static func _companionway(sh: Airship, dt: float) -> void:
	var atmos = Game.atmos
	if atmos == null or sh.lower_cells.is_empty() or sh.lower_stair.x < 0 or sh.hatch_shut:
		return
	var top := Vector2i(sh.cell(sh.upper_stair_local.x, sh.upper_stair_local.y))
	var map := Game.map
	if not map.inb(top) or not map.inb(sh.lower_stair):
		return
	var lo := map.idx(sh.lower_stair)
	var hi := map.idx(top)
	# a stair that comes up under a roof shares its air; one that comes up on open deck
	# just lets the smoke out into the sky, where it is seen but not breathed
	var roofed: bool = not map.is_outdoor(top) and not map.blocks_air(top)
	var tl: float = atmos.temp[lo]
	if roofed:
		var th: float = atmos.temp[hi]
		if tl > th + 4.0:
			var j := (tl - th) * 260.0 * dt
			atmos.add_heat(hi, j)
			atmos.add_heat(lo, -j * 0.6)
	var smoke_lo: float = atmos.gas[Defs.G_SMOKE][lo]
	if smoke_lo > 0.3:
		var moved: float = smoke_lo * 0.25 * dt
		atmos.gas[Defs.G_SMOKE][lo] = maxf(0.0, smoke_lo - moved)
		if roofed:
			atmos.add_gas(hi, Defs.G_SMOKE, moved, maxf(atmos.temp[hi], Defs.T20C))
			atmos.mark_present(Defs.G_SMOKE)
		elif Game.rng.randf() < dt * 0.8:
			Fx.smoke_puff(top)
		if sh.is_aboard(Game.player) and Game.player.cell.y < SkyGen.H and Game.rng.randf() < dt * 0.1:
			Game.msg("[color=#b8a890]Smoke is rolling up out of the companionway hatch.[/color]", "warn")

# ------------------------------------------------------------------ bilge
static func _bilge(sh: Airship, st: Dictionary, aw: float, dt: float) -> void:
	if sh.lower_cells.is_empty():
		sh.bilge = 0.0
		return
	# a hull that is flogged in a blow works its seams; a crash does worse (see Airship)
	if aw > GALE:
		sh.seam = minf(1.0, sh.seam + (aw - GALE) * 0.0006 * dt * 2.0)
	# water finds its way in through the seams; nothing bails itself
	sh.bilge = clampf(sh.bilge + sh.seam * 0.012 * dt * 2.0, 0.0, 1.0)
	var lvl := 0
	if sh.bilge > 0.85: lvl = 4
	elif sh.bilge > 0.6: lvl = 3
	elif sh.bilge > 0.3: lvl = 2
	elif sh.bilge > 0.1: lvl = 1
	var aboard := sh.is_aboard(Game.player)
	if lvl != int(st["bilge_lvl"]):
		if aboard and lvl > int(st["bilge_lvl"]):
			Game.msg(["", "[color=#8ac0e8]Damp is creeping across the galley floor.[/color]",
				"[color=#8ac0e8]There's water in the bilge — ankle deep and rising. Find the pump.[/color]",
				"[b][color=#e8a83a]Knee-deep below decks! Stores are floating, lamps sputtering.[/color][/b]",
				"[b][color=#ff6a6a]She is settling — the deck below is nearly flooded![/color][/b]"][lvl], "warn" if lvl < 3 else "bad")
		st["bilge_lvl"] = lvl
	if sh.bilge > 0.1:
		for c in sh.lower_cells:
			for ent in Game.at(c):
				if ent.has_c(&"mob"):
					SkyBuffs.apply(ent, "slow", sh.bilge * 0.7, 2.0, "wading")
	if sh.bilge > 0.5:
		for ent in Game.all_with(&"light"):
			var l: CLight = ent.c(&"light")
			if l != null and l.kind == "always" and ent.cell.y >= SkyGen.H and sh.lower_cells.has(ent.cell):
				l.flicker = maxf(l.flicker, 1.0)

static func _note(st: Dictionary, ent: Entity, key: String, every: float, text: String) -> void:
	if ent != Game.player:
		return
	var nt: Dictionary = st["note_t"]
	if Game.time - float(nt.get(key, -999.0)) < every:
		return
	nt[key] = Game.time
	Game.msg(text, "info")

## A line for the ship panel.
static func report(sh: Airship) -> String:
	if sh == null:
		return ""
	var st := state(sh)
	var bits := ["deck wind: %s" % wind_word(float(st["wind"]))]
	var n := int(st["openings"])
	if n > 0:
		bits.append("%d opening%s to the weather" % [n, "" if n == 1 else "s"])
	if sh.seam > 0.05:
		bits.append("seams %s" % ("sprung" if sh.seam > 0.5 else "weeping"))
	if sh.bilge > 0.05:
		bits.append("bilge %d%%" % int(sh.bilge * 100.0))
	if int(st["fires"]) > 0:
		bits.append("[color=#ff8a3a]%d fire%s[/color]" % [int(st["fires"]), "" if int(st["fires"]) == 1 else "s"])
	return ", ".join(bits)

## Draws the water over the lower deck. Lives in the world view like the stair mark.
class WaterFx extends Node2D:
	var sh: Airship
	var _last := -1.0
	func _process(_dt: float) -> void:
		if sh == null or not sh.present:
			return
		if absf(sh.bilge - _last) > 0.01:
			_last = sh.bilge
			queue_redraw()
	func _draw() -> void:
		if sh == null or sh.bilge < 0.05:
			return
		var a := clampf(0.12 + sh.bilge * 0.5, 0.0, 0.62)
		var half := Vector2(Defs.TILE, Defs.TILE) * 0.5
		var col := Color(0.16, 0.34, 0.5, a)
		for c in sh.lower_cells:
			if Game.map.is_solid_turf(c):
				continue
			draw_rect(Rect2(Entity.cell_to_pos(c) - half, Vector2(Defs.TILE, Defs.TILE)), col)
