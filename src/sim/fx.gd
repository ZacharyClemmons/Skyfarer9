class_name Fx extends RefCounted
## One-shot visual effects. Everything is pooled under Game.view.fx_layer and frees itself.

static func _layer() -> Node2D:
	return Game.view.fx_layer if Game.view else null

static func _anim(cell: Vector2i, frames: Array, fps: float, glow := 0.0, offset := Vector2.ZERO, size := 32) -> Sprite2D:
	var layer := _layer()
	if layer == null:
		return null
	var s := Sprite2D.new()
	s.texture = Gfx.tex("fx")
	s.region_enabled = true
	s.region_rect = Gfx.region("fx", frames[0])
	s.position = Vector2(cell.x * 32 + 16, cell.y * 32 + 16) + offset
	if glow > 0:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = mat
		s.modulate = Color(glow, glow, glow)
	layer.add_child(s)
	var tw := s.create_tween()
	for i in range(1, frames.size()):
		tw.tween_interval(1.0 / fps)
		tw.tween_callback(func(): s.region_rect = Gfx.region("fx", frames[i]))
	tw.tween_interval(1.0 / fps)
	tw.tween_callback(s.queue_free)
	return s

static func sparks(cell: Vector2i) -> void:
	_anim(cell, ["sparks_0", "sparks_1", "sparks_2", "sparks_3"], 14.0, 2.5)
	Sfx.play("spark", cell)
	if Game.lighting:
		Game.lighting.flash(cell, Color(1.0, 0.85, 0.5), 3.0, 0.25)

static func explosion(cell: Vector2i, scale := 1.0) -> void:
	var s := _anim(cell, ["explosion_0", "explosion_1", "explosion_2", "explosion_3", "explosion_4", "explosion_5"], 12.0, 1.8)
	if s:
		s.scale = Vector2(scale, scale)
	if Game.lighting:
		Game.lighting.flash(cell, Color(1.0, 0.7, 0.3), 5.0 + scale * 3.0, 0.6)
	if Game.view:
		Game.view.shake(6.0 * scale)

## tg /obj/effect/temp_visual/monkeyify (and /humanify): the body twists between forms
## over the 2.2 s transformation.
static func transform_swirl(cell: Vector2i, humanify := false) -> void:
	var base := "humanify_" if humanify else "monkeyify_"
	if Gfx.has("fx", base + "0"):
		var frames := []
		for i in 11:
			if Gfx.has("fx", base + str(i)):
				frames.append(base + str(i))
		_anim(cell, frames, frames.size() / 2.2, 0.0, Vector2(0, -8))
	else:
		smoke_puff(cell)
	if Game.lighting:
		Game.lighting.flash(cell, Color(0.4, 1.0, 0.5), 2.5, 0.4)

static func smoke_puff(cell: Vector2i) -> void:
	var layer := _layer()
	if layer == null:
		return
	for i in 3:
		var s := Sprite2D.new()
		s.texture = Gfx.tex("fx")
		s.region_enabled = true
		s.region_rect = Gfx.region("fx", "smoke_%d" % i)
		s.position = Vector2(cell.x * 32 + 16 + Game.rng.randf_range(-8, 8), cell.y * 32 + 16)
		s.modulate.a = 0.8
		layer.add_child(s)
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position:y", s.position.y - 24, 1.6)
		tw.tween_property(s, "modulate:a", 0.0, 1.6)
		tw.tween_property(s, "scale", Vector2(1.6, 1.6), 1.6)
		tw.chain().tween_callback(s.queue_free)

static func foam(cell: Vector2i) -> void:
	var layer := _layer()
	if layer == null:
		return
	var s := Sprite2D.new()
	s.texture = Gfx.tex("fx")
	s.region_enabled = true
	s.region_rect = Gfx.region("fx", "foam")
	s.position = Vector2(cell.x * 32 + 16, cell.y * 32 + 16)
	s.scale = Vector2(0.3, 0.3)
	layer.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2(1, 1), 0.2)
	tw.tween_interval(2.5)
	tw.tween_property(s, "modulate:a", 0.0, 1.5)
	tw.tween_callback(s.queue_free)

static func frost_burst(cell: Vector2i) -> void:
	for i in 6:
		var s := _anim(cell, ["flake_2", "flake_1", "flake_0"], 5.0, 1.5, Vector2(Game.rng.randf_range(-20, 20), Game.rng.randf_range(-20, 20)))
		if s:
			s.modulate = Color(1.2, 1.6, 2.0)

## Something small made of glass breaking (a light tube, a bottle): a little burst of slivers.
static func glass(cell: Vector2i) -> void:
	glass_shatter(cell, Vector2.ZERO, 6)

static func _sprite(frame: String, pos: Vector2) -> Sprite2D:
	var layer := _layer()
	if layer == null:
		return null
	var s := Sprite2D.new()
	s.texture = Gfx.tex("fx")
	s.region_enabled = true
	s.region_rect = Gfx.region("fx", frame)
	s.position = pos
	layer.add_child(s)
	return s

static func _center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * 32 + 16, cell.y * 32 + 16)

## One piece of debris on a ballistic arc: launched at `vel` px/s, pulled down by `grav`,
## spinning, then it settles and fades where it lands.
static func _fling(s: Sprite2D, vel: Vector2, grav: float, dur: float, spin: float, fade := 0.25) -> void:
	var p0 := s.position
	var r0 := s.rotation
	var step := func(t: float) -> void:
		s.position = p0 + vel * t + Vector2(0, 0.5 * grav * t * t)
		s.rotation = r0 + spin * t
	var tw := s.create_tween()
	tw.tween_method(step, 0.0, dur, dur)
	tw.tween_property(s, "modulate:a", 0.0, fade)
	tw.tween_callback(s.queue_free)

## A window pane bursting (tg window atom_deconstruct: the shatter). Slivers fly out from
## all over the pane, mostly away from whatever broke it (`push`: the direction of the blow),
## then rain down onto the floor and fade; the break flashes cold light around the tile.
static func glass_shatter(cell: Vector2i, push: Vector2, count := 16) -> void:
	if _layer() == null:
		return
	var c := _center(cell)
	var dir := push.normalized() if push != Vector2.ZERO else Vector2.ZERO
	for i in count:
		var s := _sprite("glass_frag_%d" % (Game.rng.randi() % 6), c + Vector2(Game.rng.randf_range(-13, 13), Game.rng.randf_range(-13, 13)))
		if s == null:
			return
		var out := (s.position - c).normalized() if s.position != c else Vector2.UP
		var vel := out * Game.rng.randf_range(30.0, 90.0) + dir * Game.rng.randf_range(40.0, 120.0) + Vector2(0, -Game.rng.randf_range(20.0, 70.0))
		s.rotation = Game.rng.randf() * TAU
		_fling(s, vel, 260.0, Game.rng.randf_range(0.35, 0.6), Game.rng.randf_range(-14.0, 14.0), Game.rng.randf_range(0.3, 0.8))
	glass_chips(cell, -push, 8)
	var glow := _sprite("light_soft", c)
	if glow:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = mat
		glow.modulate = Color(0.75, 0.9, 1.0, 0.8)
		glow.scale = Vector2(0.35, 0.35)
		var tw := glow.create_tween().set_parallel(true)
		tw.tween_property(glow, "scale", Vector2(0.6, 0.6), 0.25)
		tw.tween_property(glow, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(glow.queue_free)
	if Game.lighting:
		Game.lighting.flash(cell, Color(0.7, 0.85, 1.0), 2.5, 0.2)

## Glints knocked off a pane by a hit, spraying back toward the hitter (`toward`).
static func glass_chips(cell: Vector2i, toward: Vector2, count := 4, tint := Color.WHITE) -> void:
	var c := _center(cell)
	var dir := toward.normalized() if toward != Vector2.ZERO else Vector2.ZERO
	for i in count:
		var s := _sprite("glass_chip", c + dir * 10.0 + Vector2(Game.rng.randf_range(-6, 6), Game.rng.randf_range(-6, 6)))
		if s == null:
			return
		s.modulate = tint
		var vel := dir * Game.rng.randf_range(30.0, 80.0) + Vector2(Game.rng.randf_range(-40, 40), -Game.rng.randf_range(30.0, 80.0))
		_fling(s, vel, 300.0, Game.rng.randf_range(0.2, 0.35), 0.0, 0.15)

## Something solid takes a blow: its sprite knocks a couple of pixels and settles.
static func jolt(e: Entity, strength := 2.0) -> void:
	if e == null or e.spr == null or e.holder != null or e.has_meta(&"jolting"):
		return
	e.set_meta(&"jolting", true)
	var base := e.pixel_offset
	var tw := e.create_tween()
	for k in 3:
		var amp := strength * (1.0 - k / 3.0)
		var off := Vector2(Game.rng.randf_range(-amp, amp), Game.rng.randf_range(-amp * 0.5, amp * 0.5))
		tw.tween_property(e.spr, "position", base + off, 0.03)
	tw.tween_property(e.spr, "position", base, 0.04)
	tw.tween_callback(func():
		if is_instance_valid(e):
			e.remove_meta(&"jolting")
			if e.glow_spr:
				e.glow_spr.position = e.pixel_offset
	)

## A struck pane lights up for an instant.
static func pane_flash(cell: Vector2i, strength := 0.5) -> void:
	var s := _sprite("light_soft", _center(cell))
	if s == null:
		return
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = mat
	s.scale = Vector2(0.28, 0.28)
	s.modulate = Color(0.8, 0.95, 1.0, strength)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.18)
	tw.tween_callback(s.queue_free)

## tg ATTACK_EFFECT_PUNCH / KICK / SMASH (do_item_attack_animation with a visual effect icon):
## the impact mark pops up on what you hit, grows, and fades.
static func attack_effect(at: Vector2, kind: String) -> void:
	var s := _sprite("atk_" + kind, at + Vector2(Game.rng.randf_range(-4, 4), Game.rng.randf_range(-4, 4)))
	if s == null:
		return
	s.scale = Vector2(0.4, 0.4)
	s.rotation = Game.rng.randf() * TAU
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2(0.75, 0.75), 0.3)
	tw.parallel().tween_property(s, "modulate:a", 0.69, 0.3)
	tw.tween_interval(0.1)
	tw.tween_property(s, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(s.queue_free)

## tg obj/item/proc/animate_attack: a ghost of the weapon plays over what it hit, coming in
## from the attacker's side. Blunt things bonk in, edged things slash across, points thrust.
## `from`/`to` are world positions of the attacker and the target.
static func item_flick(item: Entity, from: Vector2, to: Vector2) -> void:
	var layer := _layer()
	if layer == null or item == null or item.spr == null or item.spr.texture == null:
		return
	var it: CItem = item.c(&"item")
	var s := Sprite2D.new()
	s.texture = item.spr.texture
	s.region_enabled = true
	s.region_rect = item.spr.region_rect
	s.scale = Vector2(0.5, 0.5)
	layer.add_child(s)
	# tg x_sign / y_sign: which side the attacker is on (screen space, y down)
	var d := from - to
	var sx := signf(d.x) if absf(d.x) > 4.0 else 0.0
	var sy := signf(d.y) if absf(d.y) > 4.0 else 0.0
	if sx == 0.0 and sy == 0.0:
		sy = 1.0
		sx = 0.25 * (1.0 if Game.rng.randf() < 0.5 else -1.0)
	var aim := Vector2(-sx, -sy).normalized() # the direction of the blow
	var kind := "blunt"
	if it and it.sharpness == "edged":
		kind = "slash"
	elif it and it.sharpness == "pointy":
		kind = "pierce"
	var tw := s.create_tween()
	match kind:
		"blunt":
			s.position = to + Vector2(14 * sx, 12 * sy)
			tw.set_parallel(true)
			tw.tween_property(s, "position", to + Vector2(4 * sx, 3 * sy), 0.2)
			tw.tween_property(s, "scale", Vector2(0.375, 0.375), 0.2)
			tw.tween_property(s, "modulate:a", 0.69, 0.2)
			tw.set_parallel(false)
			tw.tween_interval(0.1)
		"pierce":
			# item sprites point up-right, so turn that toward the target
			s.rotation = aim.angle() + PI * 0.25 + deg_to_rad(Game.rng.randf_range(-7, 7))
			var mult := 1.4 if sx != 0.0 and sy != 0.0 else 1.0
			var start := to + Vector2(22 * sx, 18 * sy) * mult
			s.position = start
			tw.tween_property(s, "position", start - aim * 12.0 * mult, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tw.tween_property(s, "position", start + aim * 26.0 * mult, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(s, "scale", Vector2(0.375, 0.375), 0.3)
			tw.parallel().tween_property(s, "modulate:a", 0.69, 0.3)
		"slash":
			var side := 1.0 if Game.rng.randf() < 0.5 else -1.0
			var perp := Vector2(-aim.y, aim.x) * side
			s.position = to + Vector2(18 * sx, 14 * sy) * 0.5 + perp * 10.0
			var base_rot := aim.angle() + PI * 0.25
			s.rotation = base_rot - deg_to_rad(45.0) * side
			tw.set_parallel(true)
			tw.tween_property(s, "rotation", base_rot + deg_to_rad(45.0) * side, 0.3).set_trans(Tween.TRANS_SINE)
			tw.tween_property(s, "position", to - perp * 8.0, 0.3).set_trans(Tween.TRANS_SINE)
			tw.tween_property(s, "scale", Vector2(0.375, 0.375), 0.3)
			tw.tween_property(s, "modulate:a", 0.69, 0.3)
			tw.set_parallel(false)
			tw.tween_interval(0.1)
	tw.tween_property(s, "modulate:a", 0.0, 0.1).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(s.queue_free)

static func flame_on(e: Entity) -> void:
	if e.get_node_or_null("Flame"):
		return
	var s := AnimatedFlame.new()
	s.name = "Flame"
	s.intensity = 0
	e.add_child(s)

static func flame_off(e: Entity) -> void:
	var n := e.get_node_or_null("Flame")
	if n:
		n.queue_free()

static func blood(cell: Vector2i) -> void:
	Body.drip(cell)

static func _obj_sprite(frame: String, pos: Vector2) -> Sprite2D:
	var layer := _layer()
	if layer == null or not Gfx.has("objects", frame):
		return null
	var s := Sprite2D.new()
	s.texture = Gfx.tex("objects")
	s.region_enabled = true
	s.region_rect = Gfx.region("objects", frame)
	s.position = pos
	s.z_index = 20
	layer.add_child(s)
	return s

## tg /obj/effect/temp_visual/dir_setting/bloodsplatter: the spurt where a hit lands,
## thrown out along the blow and gone in a moment.
static func blood_hit(cell: Vector2i, dir := Vector2i.ZERO) -> void:
	var d := Vector2(dir).normalized() if dir != Vector2i.ZERO else Vector2.from_angle(randf() * TAU)
	var s := _obj_sprite("blood_hitsplatter_%d" % (randi() % 3), _center(cell) + d * 4.0)
	if s == null:
		return
	s.rotation = d.angle()
	s.scale = Vector2(0.4, 0.4)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "position", s.position + d * 12.0, 0.25)
	tw.tween_property(s, "scale", Vector2(1.0, 1.0), 0.25)
	tw.tween_property(s, "modulate:a", 0.0, 0.2).set_delay(0.15)
	tw.chain().tween_callback(s.queue_free)

## tg /obj/effect/decal/cleanable/blood/hitsplatter in flight: a glob of blood flying
## from `from` to `to` over `dur` seconds.
static func blood_fly(from: Vector2i, to: Vector2i, dur: float) -> void:
	var s := _obj_sprite("blood_hitsplatter_%d" % (randi() % 3), _center(from))
	if s == null:
		return
	s.rotation = (_center(to) - _center(from)).angle()
	var tw := s.create_tween()
	tw.tween_property(s, "position", _center(to), maxf(0.05, dur))
	tw.tween_callback(s.queue_free)

## An energy bolt from one cell to another: a bright core with a soft glow, gone fast.
static func beam(from: Vector2i, to: Vector2i, color: Color) -> void:
	var layer := _layer()
	if layer == null:
		return
	var a := Vector2(from.x * 32 + 16, from.y * 32 + 12)
	var b := Vector2(to.x * 32 + 16, to.y * 32 + 12)
	var glow := Line2D.new()
	glow.points = PackedVector2Array([a, b])
	glow.width = 6.0
	glow.default_color = Color(color, 0.35)
	glow.z_index = 30
	layer.add_child(glow)
	var core := Line2D.new()
	core.points = PackedVector2Array([a, b])
	core.width = 2.0
	core.default_color = color.lightened(0.5)
	core.z_index = 31
	layer.add_child(core)
	for ln in [glow, core]:
		var tw: Tween = ln.create_tween()
		tw.tween_property(ln, "modulate:a", 0.0, 0.18)
		tw.tween_callback(ln.queue_free)
	if Game.lighting:
		Game.lighting.flash(to, color, 2.5, 0.15)

static func text_popup(cell: Vector2i, text: String, color := Color.WHITE) -> void:
	var layer := _layer()
	if layer == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 10)
	l.position = Vector2(cell.x * 32, cell.y * 32 - 8)
	layer.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 16, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 1.2)
	tw.chain().tween_callback(l.queue_free)
