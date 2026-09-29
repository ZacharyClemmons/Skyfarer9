class_name SkyStage extends Control
## The place the sign-on office stands: a timber quay at the edge of Port Meridian with a
## rail, a hurricane lantern on a post, a pennant snapping in the wind, and the sky
## behind it going about its business. The sky is the one you were raised under: pick an
## origin and the light eases over to that altitude (warm and low in the Deep, thin violet
## with aurora-ish stars in the Heights, near-black in the Anvil).
##
## Everything is drawn with 2D primitives and one soft puff texture, and redrawn every
## frame because everything moves. It costs a few hundred draw calls and no textures.

var origin := 1                 ## index into SkyLore.ORIGINS
var gust := 0.0                 ## 0..1, decays; a burst of wind (the reroll kicks one)
var pad_x := 0.0                ## where the character stands, in this control's pixels
var deck_top := 0.0             ## y of the far edge of the planking (set by layout)
var lantern_on := true
var feet_y := 0.0               ## where the character's feet are, for the shadow
var doll_scale := 6.0

var _t := 0.0
var _sky_top := Color.BLACK
var _sky_mid := Color.BLACK
var _sky_low := Color.BLACK
var _sun := Color.WHITE
var _cloud := Color.WHITE
var _stars := 0.0
var _haze := 0.2
var _clouds: Array = []
var _star_pts: Array = []
var _ships: Array = []
var _birds: Array = []
var _puff: GradientTexture2D

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for layer in 3:
		for i in 6 + layer * 2:
			var puffs := []
			for k in 6:
				puffs.append(Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.16, 0.10), rng.randf_range(0.35, 0.8)))
			_clouds.append({"layer": layer, "x": rng.randf(), "y": rng.randf(), "w": rng.randf_range(0.16, 0.30) * (1.0 + layer * 0.45),
				"puffs": puffs})
	for i in 110:
		_star_pts.append(Vector3(rng.randf(), rng.randf() * 0.7, rng.randf() * TAU))
	_ships.append({"x": 0.18, "y": 0.30, "s": 1.0, "v": 0.006, "kind": 0})
	_ships.append({"x": 0.72, "y": 0.42, "s": 0.55, "v": -0.004, "kind": 1})
	for i in 7:
		_birds.append({"x": rng.randf(), "y": rng.randf_range(0.18, 0.5), "v": rng.randf_range(0.012, 0.02), "ph": rng.randf() * TAU})
	_puff = GradientTexture2D.new()
	_puff.width = 96
	_puff.height = 96
	_puff.fill = GradientTexture2D.FILL_RADIAL
	_puff.fill_from = Vector2(0.5, 0.5)
	_puff.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.6))
	_puff.gradient = g
	_snap()

func set_origin(i: int) -> void:
	origin = clampi(i, 0, SkyLore.ORIGINS.size() - 1)

## Jump straight to the current origin's palette (first frame, and tests).
func _snap() -> void:
	var o := SkyLore.origin(origin)
	_sky_top = o["sky"][0]
	_sky_mid = o["sky"][1]
	_sky_low = o["sky"][2]
	_sun = o["sun"]
	_cloud = o["cloud"]
	_stars = o["stars"]
	_haze = o["haze"]

func _process(delta: float) -> void:
	_t += delta
	gust = maxf(0.0, gust - delta * 0.5)
	var o := SkyLore.origin(origin)
	var k := 1.0 - exp(-delta * 2.6)
	_sky_top = _sky_top.lerp(o["sky"][0], k)
	_sky_mid = _sky_mid.lerp(o["sky"][1], k)
	_sky_low = _sky_low.lerp(o["sky"][2], k)
	_sun = _sun.lerp(o["sun"], k)
	_cloud = _cloud.lerp(o["cloud"], k)
	_stars = lerpf(_stars, o["stars"], k)
	_haze = lerpf(_haze, o["haze"], k)
	queue_redraw()

func wind() -> float:
	return 1.0 + gust * 5.0

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	var hor := deck_top if deck_top > 0.0 else h * 0.72
	# --- sky: three stops, drawn as two vertex-coloured quads
	var mid_y := hor * 0.55
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, mid_y), Vector2(0, mid_y)]),
		PackedColorArray([_sky_top, _sky_top, _sky_mid, _sky_mid]))
	draw_polygon(PackedVector2Array([Vector2(0, mid_y), Vector2(w, mid_y), Vector2(w, hor + 4), Vector2(0, hor + 4)]),
		PackedColorArray([_sky_mid, _sky_mid, _sky_low, _sky_low]))
	# --- stars fade in for the high skies, and twinkle
	if _stars > 0.02:
		for s in _star_pts:
			var tw := 0.5 + 0.5 * sin(_t * 1.7 + float(s.z))
			draw_rect(Rect2(floorf(s.x * w), floorf(s.y * hor), 2, 2), Color(1, 1, 1, _stars * (0.25 + 0.6 * tw)))
		# a slow aurora ribbon in the Heights
		for b in 3:
			var band := PackedVector2Array()
			for i in 25:
				var fx3 := i / 24.0
				band.append(Vector2(fx3 * w, hor * (0.20 + b * 0.035 + 0.05 * sin(fx3 * 5.0 + _t * 0.35 + b))))
			draw_polyline(band, Color(0.35, 1.0, 0.75, 0.16 * clampf((_stars - 0.4) * 3.0, 0.0, 1.0)), 10.0 - b * 2.5, true)
	# --- the sun and its light shafts
	var sun_p := Vector2(w * 0.74, hor * 0.36)
	var sun_r := hor * 0.55
	draw_texture_rect(_puff, Rect2(sun_p - Vector2(sun_r, sun_r), Vector2(sun_r, sun_r) * 2.0), false, Color(_sun, 0.42))
	draw_texture_rect(_puff, Rect2(sun_p - Vector2(sun_r, sun_r) * 0.28, Vector2(sun_r, sun_r) * 0.56), false, Color(_sun, 0.9))
	for i in 5:
		var an := 1.2 + i * 0.33 + sin(_t * 0.12 + i) * 0.05
		var dir := Vector2(cos(an), sin(an))
		var perp := Vector2(-dir.y, dir.x)
		var long_ := hor * 1.5
		draw_colored_polygon(PackedVector2Array([sun_p, sun_p + dir * long_ + perp * 34.0, sun_p + dir * long_ - perp * 34.0]),
			Color(_sun, 0.055))
	# --- clouds: three parallax banks, nearest last and fastest
	for c in _clouds:
		if c["layer"] == 2:
			continue
		_draw_cloud(c, w, hor, false)
	# --- distant airships, hazed into the sky
	for s in _ships:
		var sx: float = fposmod(float(s["x"]) + _t * float(s["v"]) * wind(), 1.3) - 0.15
		_draw_airship(Vector2(sx * w, hor * float(s["y"]) + sin(_t * 0.5 + sx * 6.0) * 3.0), float(s["s"]) * clampf(w / 1600.0, 0.7, 1.6), int(s["kind"]))
	for b in _birds:
		var bx: float = fposmod(float(b["x"]) + _t * float(b["v"]) * wind(), 1.2) - 0.1
		var by: float = hor * float(b["y"]) + sin(_t * 1.3 + float(b["ph"])) * 6.0
		var flap := sin(_t * 9.0 + float(b["ph"])) * 3.0
		var p := Vector2(bx * w, by)
		draw_polyline(PackedVector2Array([p + Vector2(-5, -flap), p, p + Vector2(5, -flap)]), Color(0.1, 0.1, 0.16, 0.55), 2.0)
	for c in _clouds:
		if c["layer"] == 2:
			_draw_cloud(c, w, hor, true)
	# --- warm haze at the horizon
	draw_rect(Rect2(0, hor - hor * 0.18, w, hor * 0.18 + 4), Color(_sky_low, 0.0))
	_draw_gradient_band(Rect2(0, hor - hor * 0.25, w, hor * 0.25 + 4), Color(_sky_low, 0.0), Color(_sky_low, 0.35 + _haze))
	_draw_deck(w, h, hor)

func _draw_gradient_band(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

func _draw_cloud(c: Dictionary, w: float, hor: float, front: bool) -> void:
	var layer: int = c["layer"]
	var speed := (0.004 + layer * 0.006) * wind()
	var cw: float = float(c["w"]) * w
	var x := fposmod(float(c["x"]) + _t * speed, 1.0 + float(c["w"]) * 2.0) - float(c["w"])
	var base_y := hor * lerpf(0.5, 0.97, float(c["y"])) if layer > 0 else hor * lerpf(0.12, 0.62, float(c["y"]))
	if layer == 2:
		base_y = hor * lerpf(0.86, 1.02, float(c["y"]))
	var alpha := (0.55 if layer == 0 else (0.8 if layer == 1 else 0.95))
	var top := _cloud
	var shade := _cloud.darkened(0.22).lerp(_sky_low, 0.35)
	for pf in c["puffs"]:
		var pr: float = float(pf.z) * cw * 0.55
		var pp := Vector2(x * w + float(pf.x) * cw, base_y + float(pf.y) * cw * 0.6)
		# underside first (darker), then the lit top over it
		draw_texture_rect(_puff, Rect2(pp + Vector2(-pr, -pr * 0.55 + pr * 0.22), Vector2(pr * 2.0, pr * 1.3)), false, Color(shade, alpha * 0.85))
		draw_texture_rect(_puff, Rect2(pp + Vector2(-pr, -pr * 0.75), Vector2(pr * 2.0, pr * 1.3)), false, Color(top, alpha * 0.8))

func _draw_airship(p: Vector2, k: float, kind: int) -> void:
	var haze := Color(_sky_mid.lerp(Color(0.1, 0.1, 0.2), 0.45), 0.85)
	var lit := Color(_sun, 0.35)
	if kind == 0:
		# a big rigid-hulled merchantman, seen from the side
		var env := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			env.append(p + Vector2(cos(a) * 92.0 * k, sin(a) * 24.0 * k))
		draw_colored_polygon(env, haze)
		draw_polyline(env, lit, 2.0)
		draw_rect(Rect2(p + Vector2(-38, 24) * k, Vector2(76, 12) * k), haze)
		draw_line(p + Vector2(-30, 22) * k, p + Vector2(-30, 26) * k, haze, 2.0)
		draw_line(p + Vector2(30, 22) * k, p + Vector2(30, 26) * k, haze, 2.0)
		draw_rect(Rect2(p + Vector2(-8, 28) * k, Vector2(16, 5) * k), Color(1.0, 0.8, 0.5, 0.75))
		# tail fins and a spinning screw
		draw_colored_polygon(PackedVector2Array([p + Vector2(-90, 0) * k, p + Vector2(-112, -22) * k, p + Vector2(-80, -10) * k]), haze)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-90, 0) * k, p + Vector2(-112, 22) * k, p + Vector2(-80, 10) * k]), haze)
		var sp := sin(_t * 22.0) * 11.0 * k
		draw_line(p + Vector2(-114.0 * k, -sp), p + Vector2(-114.0 * k, sp), haze, 2.0)
	else:
		# a small sailing skiff under a patched balloon
		var env2 := PackedVector2Array()
		for i in 21:
			var a2 := TAU * i / 20.0
			env2.append(p + Vector2(cos(a2) * 40.0 * k, sin(a2) * 30.0 * k))
		draw_colored_polygon(env2, haze)
		draw_line(p + Vector2(-20, 24) * k, p + Vector2(-12, 44) * k, haze, 1.0)
		draw_line(p + Vector2(20, 24) * k, p + Vector2(12, 44) * k, haze, 1.0)
		draw_rect(Rect2(p + Vector2(-16, 44) * k, Vector2(32, 9) * k), haze)
		draw_line(p + Vector2(0, 44) * k, p + Vector2(0, 26) * k, haze, 1.0)

func _draw_deck(w: float, h: float, hor: float) -> void:
	var u := clampf(h / 900.0, 0.7, 2.0) # pixel unit for chunky details
	var wood := Color("#5a3d28")
	var wood_hi := Color("#7a5636")
	var wood_lo := Color("#3a261a")
	var brass := Color("#d8a848")
	# --- planking, in perspective: rows get taller toward the viewer
	draw_rect(Rect2(0, hor, w, h - hor + 2), wood)
	var y := hor
	var row := 0
	var rh := 10.0 * u
	while y < h:
		var bright := 0.5 + 0.5 * sin(row * 2.7)
		draw_rect(Rect2(0, y, w, rh), wood.lerp(wood_hi, 0.10 + 0.18 * bright))
		draw_rect(Rect2(0, y + rh - maxf(2.0, u * 1.6), w, maxf(2.0, u * 1.6)), wood_lo)
		# butt joints, staggered
		var jx := fposmod(float(row) * 137.0, 260.0 * u)
		while jx < w:
			draw_rect(Rect2(jx, y, maxf(2.0, u * 1.6), rh), wood_lo)
			jx += 260.0 * u
		y += rh
		rh *= 1.12
		row += 1
	# the far lip of the quay, lit by the low sun
	draw_rect(Rect2(0, hor - 6 * u, w, 6 * u), wood_hi)
	draw_rect(Rect2(0, hor - 6 * u, w, 2 * u), brass.darkened(0.15))
	# --- rail: posts and two rope runs, drawn behind the lip so the sky shows through
	var post_gap := 210.0 * u
	var px := fposmod(-40.0, post_gap)
	while px < w + 20:
		draw_rect(Rect2(px, hor - 92 * u, 12 * u, 92 * u), wood_lo)
		draw_rect(Rect2(px, hor - 92 * u, 4 * u, 92 * u), wood)
		draw_rect(Rect2(px - 3 * u, hor - 98 * u, 18 * u, 8 * u), brass.darkened(0.25))
		px += post_gap
	for r in 2:
		var ry := hor - (34 + r * 40) * u
		var pts := PackedVector2Array()
		var n := 40
		for i in n + 1:
			var fx := i / float(n)
			pts.append(Vector2(fx * w, ry + absf(sin(fx * PI * (w / post_gap))) * 8.0 * u - 4.0 * u))
		draw_polyline(pts, Color("#c8b088"), 3.0 * u, true)
	# --- the lantern post, to the left of the character
	var lp := Vector2(pad_x - 250.0 * u, hor + 14 * u)
	if lp.x < 40:
		lp.x = 40
	var top := lp + Vector2(0, -300 * u)
	draw_rect(Rect2(lp.x - 6 * u, top.y, 12 * u, 300 * u), wood_lo)
	draw_rect(Rect2(lp.x - 6 * u, top.y, 4 * u, 300 * u), wood)
	draw_rect(Rect2(lp.x - 22 * u, top.y - 4 * u, 60 * u, 8 * u), wood_lo)
	var sway := sin(_t * 1.4) * 3.0 * u * (1.0 + gust * 3.0)
	var chain_end := top + Vector2(28 * u + sway, 44 * u)
	draw_line(top + Vector2(28 * u, 4 * u), chain_end, Color("#20242c"), 2.0 * u)
	var flick := 0.85 + 0.15 * sin(_t * 13.0) * sin(_t * 5.3) + sin(_t * 31.0) * 0.03
	if lantern_on:
		var gr := 240.0 * u * flick
		draw_texture_rect(_puff, Rect2(chain_end + Vector2(0, 14 * u) - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(1.0, 0.62, 0.25, 0.42))
		draw_texture_rect(_puff, Rect2(chain_end + Vector2(0, 14 * u) - Vector2(gr, gr) * 0.4, Vector2(gr, gr) * 0.8), false, Color(1.0, 0.85, 0.5, 0.35 * flick))
	draw_rect(Rect2(chain_end + Vector2(-10 * u, 0), Vector2(20 * u, 6 * u)), Color("#20242c"))
	draw_rect(Rect2(chain_end + Vector2(-8 * u, 6 * u), Vector2(16 * u, 22 * u)), Color(1.0, 0.86, 0.5, 0.95 if lantern_on else 0.2))
	draw_rect(Rect2(chain_end + Vector2(-10 * u, 28 * u), Vector2(20 * u, 5 * u)), Color("#20242c"))
	for gx in [-8.0, 0.0, 8.0]:
		draw_rect(Rect2(chain_end + Vector2(gx * u - u, 6 * u), Vector2(2 * u, 22 * u)), Color("#20242c", 0.85))
	# --- a pennant on the post, snapping in the wind
	var mast := top + Vector2(0, -6 * u)
	var flag := PackedVector2Array()
	var fl := 72.0 * u
	for i in 9:
		var fx2 := i / 8.0
		flag.append(mast + Vector2(fx2 * fl, sin(_t * (6.0 + gust * 8.0) - fx2 * 5.0) * 6.0 * u * fx2 + fx2 * 4.0 * u))
	for i in 9:
		var fx3 := 1.0 - i / 8.0
		flag.append(mast + Vector2(fx3 * fl * (0.85), 16.0 * u * (1.0 - fx3 * 0.6) + sin(_t * (6.0 + gust * 8.0) - fx3 * 5.0) * 6.0 * u * fx3 + fx3 * 4.0 * u))
	draw_colored_polygon(flag, Color("#c8483a"))
	draw_line(mast, mast + Vector2(0, -14 * u), brass, 2.0 * u)
	# --- warm light pooled on the boards where the character stands
	var pool := 300.0 * u
	draw_texture_rect(_puff, Rect2(Vector2(pad_x - pool, hor + (h - hor) * 0.42 - pool * 0.28), Vector2(pool * 2.0, pool * 0.56)), false, Color(1.0, 0.72, 0.4, 0.28 if lantern_on else 0.1))
	# --- her shadow on the boards
	if feet_y > 0.0:
		var sw := 15.0 * doll_scale
		draw_texture_rect(_puff, Rect2(pad_x - sw, feet_y - sw * 0.16, sw * 2.0, sw * 0.34), false, Color(0, 0, 0, 0.55))
	# --- a coil of rope and a couple of crates at the right edge, for scale
	var cx := pad_x + 300.0 * u
	draw_rect(Rect2(cx, hor + 30 * u, 46 * u, 34 * u), wood_lo)
	draw_rect(Rect2(cx + 3 * u, hor + 33 * u, 40 * u, 28 * u), wood.lightened(0.05))
	draw_rect(Rect2(cx, hor + 44 * u, 46 * u, 3 * u), wood_lo)
	draw_rect(Rect2(cx + 22 * u, hor + 30 * u, 3 * u, 34 * u), wood_lo)
	draw_circle(Vector2(cx + 78 * u, hor + 50 * u), 16 * u, Color("#a08a5c"))
	draw_circle(Vector2(cx + 78 * u, hor + 50 * u), 9 * u, wood)
	draw_arc(Vector2(cx + 78 * u, hor + 50 * u), 12.5 * u, 0, TAU, 20, Color("#7a6640"), 2.0 * u)
	# --- vignette
	_draw_gradient_band(Rect2(0, h * 0.75, w, h * 0.25 + 2), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.45))
