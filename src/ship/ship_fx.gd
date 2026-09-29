extends RefCounted
## Small, cheap, self-freeing visual effects for ships: dust, steam, funnel smoke.
##
## They use a private random generator on purpose. Effects must never draw from `Game.rng`,
## or turning them on would change what the deterministic tests (and a player's world) see.

static var _rng := RandomNumberGenerator.new()
static var live := 0
const MAX_LIVE := 70

## A few puffs of smoke at a world-pixel position. `drift` is added over the puff's life,
## `tint` carries the colour (grey funnel smoke, white steam, tan dust).
static func puff(pos: Vector2, count := 3, spread := 10.0, rise := 22.0, life := 1.2,
		tint := Color(1, 1, 1, 0.7), grow := 1.5, scale0 := 0.6, drift := Vector2.ZERO) -> void:
	if Game.view == null or Game.view.fx_layer == null:
		return
	for i in count:
		if live >= MAX_LIVE:
			return
		var s := Fx._sprite("smoke_%d" % _rng.randi_range(0, 2),
			pos + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread) * 0.4))
		if s == null:
			continue
		s.modulate = tint
		s.scale = Vector2.ONE * scale0
		s.rotation = _rng.randf() * TAU
		live += 1
		var t := life * _rng.randf_range(0.8, 1.2)
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", s.position + drift + Vector2(_rng.randf_range(-8.0, 8.0), -rise), t) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(s, "modulate:a", 0.0, t).set_ease(Tween.EASE_IN)
		tw.tween_property(s, "scale", Vector2.ONE * grow, t)
		# count down when the sprite leaves the tree for any reason, so a cleared fx layer
		# can never leave the budget stuck at MAX_LIVE
		s.tree_exiting.connect(func(): live = maxi(0, live - 1), CONNECT_ONE_SHOT)
		tw.chain().tween_callback(s.queue_free)

## Dust thrown up around a hull when it touches down.
static func dust_ring(cells: Array, count_each := 2) -> void:
	for c in cells:
		puff(Entity.cell_to_pos(c) + Vector2(0, 8), count_each, 10.0, 10.0, 1.1,
			Color(0.86, 0.80, 0.70, 0.75), 2.0, 0.5,
			Vector2(_rng.randf_range(-14.0, 14.0), 0))

## A gout of white steam.
static func steam(pos: Vector2, count := 2) -> void:
	puff(pos, count, 5.0, 26.0, 0.9, Color(1, 1, 1, 0.65), 1.3, 0.45)

## Funnel smoke: darker, lazier, leaned downwind.
static func funnel(pos: Vector2, heavy := 0.5) -> void:
	var wind := Vector2.ZERO
	if Game.sky != null:
		wind = Game.sky.wind_vector() * 26.0
	puff(pos, 1, 3.0, 20.0 + heavy * 12.0, 1.6, Color(0.42, 0.42, 0.46, 0.35 + heavy * 0.3),
		1.5 + heavy, 0.4, wind)
