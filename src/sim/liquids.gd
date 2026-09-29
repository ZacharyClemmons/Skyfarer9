class_name Liquids extends RefCounted
## Spreading puddles. Each tile holds at most one puddle per liquid kind (a CDecal with
## `liquid` set and a `volume` in units). Above SPREAD_AT a puddle sheds half its excess
## into lower neighbours it can flow into (anything that doesn't block air, so closed
## doors hold a flood back). Water freezes on cold tiles and ice melts on warm ones,
## fuel burns, most things slowly evaporate. Mops soak up a swipe's worth.

const SPREAD_AT := 30.0
const MAX_VOLUME := 150.0
const MOP_VOLUME := 45.0

## slip: slippery; evap: units/s at room temperature; freeze/melt: kelvin thresholds.
const KINDS := {
	"water": {"name": "puddle of water", "desc": "Water. Slippery, and it will freeze if it gets cold.", "slip": true, "evap": 0.12, "freeze": 271.0, "into": "ice"},
	"ice": {"name": "ice sheet", "desc": "Frozen water. Treacherous underfoot.", "slip": true, "evap": 0.0, "melt": 276.0, "into": "water"},
	"fuel": {"name": "welding fuel", "desc": "A puddle of welding fuel. Keep flames well away.", "slip": true, "evap": 0.04, "burns": true},
	"oil": {"name": "oil slick", "desc": "Engine oil.", "slip": true, "evap": 0.0},
	"coolant": {"name": "coolant", "desc": "Reactor coolant. It smells faintly of antifreeze.", "slip": true, "evap": 0.08},
	"vomit": {"name": "vomit", "desc": "Gross.", "slip": true, "evap": 0.03},
	"blood": {"name": "pool of blood", "desc": "Someone lost a lot of blood here.", "slip": false, "evap": 0.02},
}

static func find(c: Vector2i, kind: String) -> Entity:
	for e in Game.at(c):
		var d = e.c(&"decal")
		if d and d.liquid and d.kind == kind and not e.removed:
			return e
	return null

static func volume_at(c: Vector2i, kind: String) -> float:
	var e := find(c, kind)
	return e.c(&"decal").volume if e else 0.0

static func total_at(c: Vector2i) -> float:
	var t := 0.0
	for e in Game.at(c):
		var d = e.c(&"decal")
		if d and d.liquid:
			t += d.volume
	return t

static func can_hold(c: Vector2i) -> bool:
	var map := Game.map
	return map != null and map.inb(c) and not map.is_solid_turf(c) and not map.blocks_air(c)

## Pours `vol` units of `kind` onto cell `c`, merging with a puddle already there.
static func spill(c: Vector2i, kind: String, vol: float) -> Entity:
	if vol <= 0.0 or not KINDS.has(kind) or not can_hold(c):
		return null
	var ex := find(c, kind)
	if ex:
		ex.c(&"decal").add_volume(vol)
		return ex
	var e := Proto.spawn("liquid_" + kind, c)
	var d: CDecal = e.c(&"decal")
	d.volume = 0.0
	d.add_volume(vol)
	return e

static func sprite_for(kind: String, volume: float) -> String:
	var sz := 0 if volume < 12.0 else (1 if volume < 40.0 else 2)
	return "liquid_%s_%d" % [kind, sz]

static func tile_temp(c: Vector2i) -> float:
	if Game.atmos == null:
		return Defs.T20C
	if Game.map.is_outdoor(c):
		return Game.atmos.ext_temp
	return Game.atmos.temp_at(c)

## One second of life for a liquid puddle. Called from CDecal.tick.
static func tick(d: CDecal, dt: float) -> void:
	var e := d.e
	if e.holder != null:
		return
	var info: Dictionary = KINDS.get(d.kind, {})
	var c := e.cell
	var t := tile_temp(c)
	# phase changes
	if info.has("freeze") and t < info["freeze"]:
		var amt := minf(d.volume, (4.0 + (info["freeze"] - t) * 0.15) * dt)
		d.volume -= amt
		spill(c, info["into"], amt)
	elif info.has("melt") and t > info["melt"]:
		var amt2 := minf(d.volume, (1.0 + (t - info["melt"]) * 0.12) * dt)
		d.volume -= amt2
		spill(c, info["into"], amt2)
	# evaporation (faster when warm)
	var ev: float = info.get("evap", 0.0)
	if ev > 0.0:
		d.volume -= ev * dt * clampf((t - 250.0) / 43.0, 0.2, 4.0)
	# fire
	if info.get("burns", false) and Game.atmos:
		var hot: bool = Game.atmos.hotspots.has(c)
		if not hot:
			for dd in Defs.DIRS4:
				if Game.atmos.hotspots.has(c + dd):
					hot = Game.rng.randf() < 0.6
					break
		if hot:
			var burn := minf(d.volume, 6.0 * dt)
			d.volume -= burn
			Game.atmos.ignite(c, null, 4.0 + burn)
			Game.atmos.add_heat(Game.map.idx(c), burn * 30000.0)
	# spreading
	if d.volume > SPREAD_AT and d.kind != "ice":
		var targets := []
		for dd in Defs.DIRS4:
			var n: Vector2i = c + dd
			if can_hold(n) and volume_at(n, d.kind) < d.volume - 4.0:
				targets.append(n)
		if not targets.is_empty():
			var excess := (d.volume - SPREAD_AT) * 0.5
			var share := excess / targets.size()
			d.volume -= excess
			for n in targets:
				spill(n, d.kind, share)
	if d.volume < 0.8:
		e.destroy()
	else:
		d.refresh_sprite()
