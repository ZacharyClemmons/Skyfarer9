class_name GasLayer extends Sprite2D
## Visible gases, drawn by gas.gdshader from a one-texel-per-tile data texture.
## Opacity follows tg's gas overlays (code/__DEFINES/atmospherics/atmos_helpers.dm GAS_OVERLAYS
## and gas_types.dm): a gas shows once it passes its moles_visible, and its overlay state is
## ceil(moles / 0.25) of 80, each state's alpha being log4((state + 32) / 28).
##   plasma, water vapour: visible over 0.25 mol;  nitrous oxide: over 0.5 mol
## Smoke isn't a tg gas; it uses the same curve from 0.25 mol.

const MOLES_GAS_VISIBLE := 0.25
const MOLES_GAS_VISIBLE_STEP := 0.25
const TOTAL_VISIBLE_STATES := 80.0
const VISIBLE_AT := {Defs.G_PLASMA: 0.25, Defs.G_N2O: 0.5, Defs.G_H2O: 0.25, Defs.G_SMOKE: 0.25}
const CHANNEL := {Defs.G_PLASMA: 0, Defs.G_N2O: 1, Defs.G_H2O: 2, Defs.G_SMOKE: 3}
const REFRESH := 0.4

const EASE_PER_SEC := 2.5 # how fast a tile's drawn opacity moves toward the real value

var map: StationMap
var img: Image # one texel per tile, what's drawn now
var tex: ImageTexture
var tint_img: Image # premultiplied colour + opacity of the other visible gases
var tint_tex: ImageTexture
var tint_target := {}
var mat: ShaderMaterial
var target := {} # tile index -> Color it's easing toward
var _t := 0.0

## tg overlay opacity for `moles` of a gas that shows from `visible_at`.
static func opacity(moles: float, visible_at: float) -> float:
	if moles <= visible_at:
		return 0.0
	var state := minf(TOTAL_VISIBLE_STATES, ceilf(moles / MOLES_GAS_VISIBLE_STEP))
	return clampf(log((state + 0.4 * TOTAL_VISIBLE_STATES) / (0.35 * TOTAL_VISIBLE_STATES)) / log(4.0), 0.0, 1.0)

func setup(m: StationMap) -> void:
	map = m
	name = "GasLayer"
	centered = false
	scale = Vector2(32, 32)
	# the sprite only gives us a map-sized quad; the data goes in through data_tex
	texture = ImageTexture.create_from_image(Image.create(m.w, m.h, false, Image.FORMAT_L8))
	img = Image.create(m.w, m.h, false, Image.FORMAT_RGBA8)
	tex = ImageTexture.create_from_image(img)
	tint_img = Image.create(m.w, m.h, false, Image.FORMAT_RGBA8)
	tint_tex = ImageTexture.create_from_image(tint_img)
	mat = ShaderMaterial.new()
	mat.shader = load("res://src/render/gas.gdshader")
	mat.set_shader_parameter("data_tex", tex)
	mat.set_shader_parameter("tint_tex", tint_tex)
	mat.set_shader_parameter("map_size", Vector2(m.w, m.h))
	material = mat

func _process(delta: float) -> void:
	if Game.atmos == null or map == null:
		return
	_t -= delta
	if _t <= 0.0:
		_t = REFRESH
		var dirty: Dictionary = Game.atmos.dirty_visual
		for i in dirty.keys():
			var v := _value(i)
			var c := map.cell_of(i)
			if target.has(i) or not img.get_pixel(c.x, c.y).is_equal_approx(v):
				target[i] = v
			var tint := _tint_value(i)
			if tint_target.has(i) or not tint_img.get_pixel(c.x, c.y).is_equal_approx(tint):
				tint_target[i] = tint
		dirty.clear()
	_ease_tints(delta)
	if target.is_empty():
		return
	# ease each changing tile toward its new value, so gas creeps rather than pops
	var step := EASE_PER_SEC * delta
	var done := []
	for i in target.keys():
		var c := map.cell_of(i)
		var want: Color = target[i]
		var cur := img.get_pixel(c.x, c.y)
		var nxt := Color(move_toward(cur.r, want.r, step), move_toward(cur.g, want.g, step),
			move_toward(cur.b, want.b, step), move_toward(cur.a, want.a, step))
		img.set_pixel(c.x, c.y, nxt)
		if nxt.is_equal_approx(want):
			done.append(i)
	for i in done:
		target.erase(i)
	tex.update(img)

## Recompute everything now, no easing (after load, or for tests).
func refresh_all() -> void:
	for i in map.w * map.h:
		_write(i)
	tex.update(img)
	tint_tex.update(tint_img)

## Snap one tile to its current gas (tests, and anything that must show at once).
func _write(i: int) -> void:
	var c := map.cell_of(i)
	img.set_pixel(c.x, c.y, _value(i))
	tint_img.set_pixel(c.x, c.y, _tint_value(i))
	target.erase(i)
	tint_target.erase(i)

func _ease_tints(delta: float) -> void:
	if tint_target.is_empty():
		return
	for i in tint_target.keys():
		var c := map.cell_of(i)
		var want: Color = tint_target[i]
		var cur := tint_img.get_pixel(c.x, c.y)
		var next := cur.lerp(want, minf(1.0, EASE_PER_SEC * delta))
		# RGBA8 quantization otherwise prevents slow fades ever reaching zero.
		if maxf(absf(next.r - want.r), maxf(absf(next.g - want.g), maxf(absf(next.b - want.b), absf(next.a - want.a)))) < 0.01:
			next = want
			tint_target.erase(i)
		tint_img.set_pixel(c.x, c.y, next)
	tint_tex.update(tint_img)

func _tint_value(i: int) -> Color:
	var c := map.cell_of(i)
	var out := Color(0, 0, 0, 0)
	if map.is_outdoor(c) or map.is_solid_turf(c):
		return out
	var weight := 0.0
	for g in Defs.GAS_COUNT:
		if CHANNEL.has(g) or not Defs.GAS_VISIBLE[g]:
			continue
		var a := opacity(Game.atmos.gas[g][i], Defs.GAS_VISIBLE_AT[g])
		out.r += Defs.GAS_COLOR[g].r * a
		out.g += Defs.GAS_COLOR[g].g * a
		out.b += Defs.GAS_COLOR[g].b * a
		out.a = 1.0 - (1.0 - out.a) * (1.0 - a)
		weight += a
	if weight > 0.0:
		out.r *= out.a / weight
		out.g *= out.a / weight
		out.b *= out.a / weight
	return out

func _value(i: int) -> Color:
	var c := map.cell_of(i)
	var v := Color(0, 0, 0, 0)
	if not map.is_outdoor(c) and not map.is_solid_turf(c):
		var at: AtmosSystem = Game.atmos
		v.r = opacity(at.gas[Defs.G_PLASMA][i], VISIBLE_AT[Defs.G_PLASMA])
		v.g = opacity(at.gas[Defs.G_N2O][i], VISIBLE_AT[Defs.G_N2O])
		v.b = opacity(at.gas[Defs.G_H2O][i], VISIBLE_AT[Defs.G_H2O])
		v.a = opacity(at.gas[Defs.G_SMOKE][i], VISIBLE_AT[Defs.G_SMOKE])
	return v

## How visible a gas is on a tile right now (0-1), for tests and examine.
func visible_amount(c: Vector2i, g: int) -> float:
	if g < 0 or g >= Defs.GAS_COUNT or not Defs.GAS_VISIBLE[g] or map.is_outdoor(c) or map.is_solid_turf(c):
		return 0.0
	if CHANNEL.has(g):
		return img.get_pixel(c.x, c.y)[CHANNEL[g]]
	return opacity(Game.atmos.gas[g][map.idx(c)], Defs.GAS_VISIBLE_AT[g])
