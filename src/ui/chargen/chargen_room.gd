class_name ChargenRoom extends Node2D
## The dark square room you make your character in, laid out like Burgerstation's
## character setup room: a 12x13 floor walled in rock, a pad in the middle where you
## stand, and a three-wide passage in the east wall that fades into solid black. Walking
## into the fade asks whether you're happy with how you look; walking on into the black
## starts the shift. Drawn with the game's own tiles, lit by a pool of light over the pad.
##
## The darkness is drawn on a layer above your character (`shade`), like Burgerstation's
## fake-lighting overlays, so stepping out of the light or into the passage really does
## swallow you: the passage floor stays visible at its mouth, then sinks into shadow, with
## dark wisps curling out of it.

const W := 18
const H := 15
const PAD := Vector2i(7, 7)
const GATE_X := 13 # entering this column asks "is this what you want to look like?"
const LEAVE_X := 15 # reaching this column starts the shift
const EXIT_ROWS := [6, 7, 8]

var t := 0.0
var motes: Array = [] # drifting dust in the light: [pos, vel, phase]
var wisps: Array = [] # shadow curling out of the passage: [pos, vel, radius, life, max_life]
var shade: Node2D # the darkness, drawn above the character
var _dark_tex: GradientTexture2D
var _puff_tex: GradientTexture2D
const DARK_R := 560.0
var _floor_var := {}
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 9
	for y in H:
		for x in W:
			_floor_var[Vector2i(x, y)] = _rng.randi() % 4
	for i in 26:
		motes.append([Vector2(_rng.randf_range(2, 12), _rng.randf_range(2, 13)) * 32.0, Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-5, -1)), _rng.randf() * TAU])
	for i in 14:
		wisps.append(_new_wisp(true))
	_dark_tex = GradientTexture2D.new()
	_dark_tex.width = 256
	_dark_tex.height = 256
	_dark_tex.fill = GradientTexture2D.FILL_RADIAL
	_dark_tex.fill_from = Vector2(0.5, 0.5)
	_dark_tex.fill_to = Vector2(1.0, 0.5)
	var dg := Gradient.new()
	dg.set_color(0, Color(0, 0.005, 0.02, 0.0))
	dg.set_color(1, Color(0, 0.005, 0.02, 0.75))
	dg.add_point(80.0 / DARK_R, Color(0, 0.005, 0.02, 0.0))
	dg.add_point(220.0 / DARK_R, Color(0, 0.005, 0.02, 0.3))
	dg.add_point(340.0 / DARK_R, Color(0, 0.005, 0.02, 0.5))
	_dark_tex.gradient = dg
	# cold light spilling across the passage's threshold, so you can see where the light
	# gives way to shadow (under the shade, so the shadow eats into it)
	var spill := Sprite2D.new()
	var st := GradientTexture2D.new()
	st.width = 128
	st.height = 128
	st.fill = GradientTexture2D.FILL_RADIAL
	st.fill_from = Vector2(0.5, 0.5)
	st.fill_to = Vector2(1.0, 0.5)
	var sg := Gradient.new()
	sg.set_color(0, Color(0.5, 0.7, 1.0, 0.42))
	sg.set_color(1, Color(0.3, 0.45, 0.8, 0.0))
	st.gradient = sg
	spill.texture = st
	spill.position = Vector2(GATE_X * 32.0 - 6.0, (EXIT_ROWS[1] + 0.5) * 32.0)
	spill.scale = Vector2(0.9, 1.35)
	var scm := CanvasItemMaterial.new()
	scm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spill.material = scm
	add_child(spill)
	_puff_tex = GradientTexture2D.new()
	_puff_tex.width = 64
	_puff_tex.height = 64
	_puff_tex.fill = GradientTexture2D.FILL_RADIAL
	_puff_tex.fill_from = Vector2(0.5, 0.5)
	_puff_tex.fill_to = Vector2(1.0, 0.5)
	var pg := Gradient.new()
	pg.set_color(0, Color(1, 1, 1, 1))
	pg.set_color(1, Color(1, 1, 1, 0))
	_puff_tex.gradient = pg
	shade = Node2D.new()
	shade.draw.connect(_draw_shade)
	add_child(shade)
	# a cold light hanging over the pad (additive, above the shade so it lifts the floor
	# and whoever stands in it)
	var light := Sprite2D.new()
	var gt := GradientTexture2D.new()
	gt.width = 256
	gt.height = 256
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(0.45, 0.62, 0.85, 0.5))
	g.set_color(1, Color(0.2, 0.3, 0.5, 0.0))
	g.add_point(0.45, Color(0.3, 0.45, 0.7, 0.22))
	gt.gradient = g
	light.texture = gt
	light.position = Vector2(PAD) * 32.0 + Vector2(16, 12)
	light.scale = Vector2(1.5, 1.3)
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light.material = cm
	shade.add_child(light)

## Interior floor, or the exit passage.
func is_floor(c: Vector2i) -> bool:
	if c.x >= 1 and c.x <= 12 and c.y >= 1 and c.y <= 13:
		return true
	return c.y in EXIT_ROWS and c.x >= GATE_X and c.x <= LEAVE_X + 3

func is_wall(c: Vector2i) -> bool:
	if is_floor(c):
		return false
	# the rock shell around the room and the passage
	return c.x >= 0 and c.y >= 0 and c.x <= 13 and c.y <= 14 or c.y >= 5 and c.y <= 9 and c.x <= LEAVE_X + 4

func _new_wisp(anywhere := false) -> Array:
	# born deep in the passage, drifting out toward the room and thinning as it goes
	var x := GATE_X * 32.0 + (_rng.randf_range(-8, 110) if anywhere else _rng.randf_range(70, 120))
	var y := _rng.randf_range(EXIT_ROWS[0] * 32.0 + 2.0, (EXIT_ROWS[-1] + 1) * 32.0 - 2.0)
	var life := _rng.randf_range(3.5, 6.5)
	return [Vector2(x, y), Vector2(_rng.randf_range(-9, -4), _rng.randf_range(-1.5, 1.5)), _rng.randf_range(7, 15), life * (_rng.randf() if anywhere else 1.0), life]

func _process(delta: float) -> void:
	t += delta
	for m in motes:
		m[0] += m[1] * delta
		if m[0].y < 40.0 or m[0].x < 40.0 or m[0].x > 400.0:
			m[0] = Vector2(randf_range(60, 380), randf_range(300, 420))
	for i in wisps.size():
		var w: Array = wisps[i]
		w[0] += w[1] * delta
		w[1].y += sin(t * 1.3 + i) * delta * 2.0
		w[3] -= delta
		if w[3] <= 0.0:
			wisps[i] = _new_wisp()
	queue_redraw()
	shade.queue_redraw()

func _draw() -> void:
	var terrain := Gfx.tex("terrain")
	var floor_mod := Color(0.66, 0.72, 0.86)
	var wall_mod := Color(0.62, 0.66, 0.78)
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var pos := Vector2(x, y) * 32.0
			if is_floor(c):
				draw_texture_rect_region(terrain, Rect2(pos, Vector2(32, 32)), Gfx.region("terrain", "floor_dark_%d" % _floor_var[c]), floor_mod)
			elif is_wall(c):
				var m := 0
				if is_wall(c + Vector2i(0, -1)): m |= 1
				if is_wall(c + Vector2i(1, 0)): m |= 2
				if is_wall(c + Vector2i(0, 1)): m |= 4
				if is_wall(c + Vector2i(-1, 0)): m |= 8
				draw_texture_rect_region(terrain, Rect2(pos, Vector2(32, 32)), Gfx.region("terrain", "rock_%d_%d" % [m, _floor_var[c] % 3]), wall_mod)
	_draw_pad()
	_draw_sign()

func _draw_pad() -> void:
	var cp := Vector2(PAD) * 32.0 + Vector2(16, 22)
	var pulse := 0.5 + 0.5 * sin(t * 1.7)
	# a low platform with glowing rings, squashed for perspective
	draw_set_transform(cp, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 22.0, Color(0.05, 0.08, 0.12, 0.9))
	draw_arc(Vector2.ZERO, 22.0, 0, TAU, 48, Color(0.35, 0.8, 1.0, 0.55 + 0.25 * pulse), 2.0)
	draw_arc(Vector2.ZERO, 16.0, 0, TAU, 48, Color(0.5, 1.2, 1.6, 0.35 + 0.3 * pulse), 1.0)
	draw_arc(Vector2.ZERO, 26.0 + pulse * 4.0, 0, TAU, 48, Color(0.35, 0.8, 1.0, 0.25 * (1.0 - pulse)), 1.0)
	draw_set_transform(Vector2.ZERO)

func _draw_sign() -> void:
	# neon sign on the north wall (Burgerstation hangs a bar sign here)
	var font := UITheme.font
	var text := "HARBOUR REGISTER"
	var fs := 11
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(7 * 32.0 - w * 0.5, 22.0)
	var flick := 1.0 if fmod(t, 7.3) > 0.12 else 0.35
	draw_rect(Rect2(pos - Vector2(5, 12), Vector2(w + 10, 16)), Color(0.02, 0.03, 0.05, 0.85))
	draw_rect(Rect2(pos - Vector2(5, 12), Vector2(w + 10, 16)), Color(0.4, 0.9, 1.3, 0.5 * flick), false, 1.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.55, 1.4, 1.9) * flick)

# ------------------------------------------------------------------ the shade layer
func _draw_shade() -> void:
	var s := shade
	var center := Vector2(PAD) * 32.0 + Vector2(16, 16)
	var gate_x := GATE_X * 32.0
	var top: float = EXIT_ROWS[0] * 32.0
	var bot: float = (EXIT_ROWS[-1] + 1) * 32.0
	# darkness everywhere except a pool of light around the pad
	s.draw_texture_rect(_dark_tex, Rect2(center - Vector2(DARK_R, DARK_R), Vector2(DARK_R, DARK_R) * 2.0), false)
	# then the passage sinks into shadow on top of that: a smooth fade that slowly
	# breathes, and solid black beyond it
	var breathe := sin(t * 0.7) * 5.0
	var fade_len := 88.0 + breathe
	var n := 40
	for i in n:
		var f := (i + 0.5) / n
		var a2 := smoothstep(0.0, 1.0, f)
		s.draw_rect(Rect2(gate_x - 6.0 + f * fade_len - fade_len / n * 0.5, top - 32.0, fade_len / n + 0.5, bot - top + 64.0), Color(0, 0.004, 0.015, a2))
	s.draw_rect(Rect2(gate_x - 6.0 + fade_len, top - 64.0, 32.0 * 10, bot - top + 128.0), Color(0, 0.004, 0.015, 1.0))
	# the passage's walls throw shadow onto its floor, top and bottom
	for i in 8:
		var a3 := 0.32 * (1.0 - i / 8.0)
		s.draw_rect(Rect2(gate_x, top + i * 1.5, fade_len, 1.5), Color(0, 0, 0, a3))
		s.draw_rect(Rect2(gate_x, bot - (i + 1) * 1.5, fade_len, 1.5), Color(0, 0, 0, a3))
	# a thin cold rim where the light gives out
	s.draw_rect(Rect2(gate_x - 1.0, top, 1.0, bot - top), Color(0.4, 0.6, 0.9, 0.06 + 0.03 * sin(t * 1.1)))
	# cold mist curling out of the dark: soft puffs, visible where the light gives out
	for w in wisps:
		var life: float = w[3] / w[4]
		var p: Vector2 = w[0]
		var edge := 1.0 - clampf(absf(p.x - (gate_x + 24.0)) / 70.0, 0.0, 1.0)
		var a4 := sin(life * PI) * edge * 0.16
		if a4 < 0.004:
			continue
		var r: float = w[2] * (1.6 - life * 0.6)
		s.draw_texture_rect(_puff_tex, Rect2(p - Vector2(r * 1.8, r), Vector2(r * 3.6, r * 2.0)), false, Color(0.62, 0.76, 1.0, a4))
	# dust motes drifting through the light
	for m in motes:
		var d: float = (m[0] - center).length()
		var a5 := clampf(1.0 - d / 190.0, 0.0, 1.0) * (0.5 + 0.5 * sin(t * 1.3 + m[2]))
		if a5 > 0.02:
			s.draw_rect(Rect2(m[0], Vector2(1, 1)), Color(0.8, 0.9, 1.0, a5 * 0.6))
