class_name CloudBanks extends Node2D
## The cloud banks you can fly into, drawn as clouds.
##
## SkyGen leaves patches of `T_CLOUD` scattered about the region and TerrainChunk used to
## draw each one as a grey 32-pixel tile, which is how a bank ended up looking like a
## dithered rug laid over the sky. They are still real map cells (a bank you can fly into
## is a real thing) but here every one is drawn as overlapping soft puffs, sunlit on top
## and shaded underneath, which is what the eye actually reads as cloud.
##
## Retained drawing: the node only redraws when the view has moved a few cells, so the cost
## is a tile scan now and then rather than every frame.

static var active := true

var _key := Vector4i(-9999, 0, 0, 0)
var _sun := 0.5
var _last_sun := -1.0
var _t := 0.0

var _puff: GradientTexture2D

func _ready() -> void:
	z_index = -6
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	_puff = GradientTexture2D.new()
	_puff.gradient = g
	_puff.fill = GradientTexture2D.FILL_RADIAL
	_puff.fill_from = Vector2(0.5, 0.5)
	_puff.fill_to = Vector2(1.0, 0.5)
	_puff.width = 64
	_puff.height = 64
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _process(delta: float) -> void:
	if Game.map == null or Game.view == null:
		return
	_t += delta
	var inv: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var sz: Vector2 = get_viewport().get_visible_rect().size
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * sz
	var key := Vector4i(floori(minf(a.x, b.x) / 32.0 / 3.0), floori(minf(a.y, b.y) / 32.0 / 3.0),
		floori(maxf(a.x, b.x) / 32.0 / 3.0), floori(maxf(a.y, b.y) / 32.0 / 3.0))
	var sun := 0.5
	if Game.sky != null:
		sun = clampf(Game.sky.sun_elevation() * 0.5 + 0.5, 0.0, 1.0)
	if key != _key or absf(sun - _last_sun) > 0.02:
		_key = key
		_last_sun = sun
		_sun = sun
		queue_redraw()

func _draw() -> void:
	var map: StationMap = Game.map
	if map == null:
		return
	var x0 := maxi(0, _key.x * 3 - 3)
	var y0 := maxi(0, _key.y * 3 - 3)
	var x1 := mini(map.w - 1, _key.z * 3 + 5)
	var y1 := mini(map.h - 1, _key.w * 3 + 5)
	if (x1 - x0) * (y1 - y0) > 9000:
		return
	var warm := Color(1.0, 0.95, 0.88)
	var sky_c := Color(0.90, 0.94, 1.0)
	var lit := sky_c.lerp(warm, clampf(1.0 - absf(_sun - 0.5) * 2.4, 0.0, 1.0) * 0.5)
	var under := Color(0.66, 0.72, 0.86)
	var cloud_t := Defs.T_CLOUD
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if map.turf[map.idx(Vector2i(x, y))] != cloud_t:
				continue
			var h := absi(hash(Vector2i(x * 7 + 3, y * 13 + 5)))
			var r := 21.0 + float(h % 11)
			var jx := float((h >> 4) % 15) - 7.0
			var jy := float((h >> 8) % 11) - 5.0
			var c := Vector2(x * 32 + 16 + jx, y * 32 + 16 + jy)
			# is this cell on the rim of the bank? rims are softer and smaller
			var edge := false
			for d in Defs.DIRS4:
				var n: Vector2i = Vector2i(x, y) + d
				if map.inb(n) and map.turf[map.idx(n)] != cloud_t:
					edge = true
					break
			if edge:
				r *= 0.82
			# soft radial puffs, not discs: the falloff is what makes it cloud
			var rr := r * 1.9
			draw_texture_rect(_puff, Rect2(c + Vector2(0, 8) - Vector2(rr, rr), Vector2(rr, rr) * 2.0),
				false, Color(under.r, under.g, under.b, 0.30))
			draw_texture_rect(_puff, Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0),
				false, Color(lit.r * 0.94, lit.g * 0.96, lit.b, 0.36))
			var r2 := rr * 0.68
			draw_texture_rect(_puff, Rect2(c + Vector2(-3, -7) - Vector2(r2, r2), Vector2(r2, r2) * 2.0),
				false, Color(lit.r, lit.g, lit.b, 0.32))
