class_name TRayLayer extends Node2D
## What a switched-on T-ray scanner shows its carrier: the pipes and cables under the floor
## within CTray.RANGE tiles, drawn half see-through and fading between scans like tg's
## flick_overlay (a fresh scan every 0.8 s).

const PERIOD := 0.8
var _t := 0.0
var _origin := Vector2i(-9999, -9999)
var _obj_tex: Texture2D

func _ready() -> void:
	_obj_tex = Gfx.tex("objects")

func _process(delta: float) -> void:
	var o := CTray.player_scan_origin()
	_t += delta
	if o != _origin or _t >= PERIOD:
		if _t >= PERIOD:
			_t = 0.0
		_origin = o
	if _origin.x > -9000 or o.x > -9000:
		queue_redraw()

func _o(name: String, pos: Vector2, mod: Color) -> void:
	var r = Gfx.manifest["objects"].get(name)
	if r == null:
		return
	draw_texture_rect_region(_obj_tex, Rect2(pos, Vector2(r[2], r[3])), Rect2(r[0], r[1], r[2], r[3]), mod)

func _draw() -> void:
	if _origin.x < -9000 or Game.map == null:
		return
	var map := Game.map
	var a := 0.62 * (1.0 - _t / PERIOD * 0.55)
	var rr := CTray.RANGE
	for y in range(_origin.y - rr, _origin.y + rr + 1):
		for x in range(_origin.x - rr, _origin.x + rr + 1):
			var c := Vector2i(x, y)
			if not map.inb(c) or c == _origin and false:
				continue
			if Vector2(c - _origin).length() > rr + 0.5:
				continue
			var i := map.idx(c)
			var fl: int = Defs.TURFS[map.turf[i]]["flags"]
			var covered := (fl & Defs.F_FLOOR) != 0 or (fl & Defs.F_WALL) != 0
			if not covered:
				continue # already on show
			var pos := Vector2(c) * Defs.TILE
			if map.cable[i] > 0:
				var m := 0
				for d in 4:
					var nc: Vector2i = c + Defs.DIRS4[d]
					if map.inb(nc) and map.cable[map.idx(nc)] > 0:
						m |= 1 << d
				_o("cable_%d" % m, pos, Color(1, 1, 1, a))
			for layer in StationMap.PIPE_LAYER_COUNT:
				if map.pipe_mask(layer, c) == 0:
					continue
				var key := map.pipe_key(layer, c)
				if map.pipe_shown.has(key):
					continue
				var col = map.pipe_color.get(key)
				for g in map.pipe_groups_at(layer, c):
					if col != null:
						var cc: Color = col
						_o("pipe_t%d_%d" % [StationMap.PIPE_TG_LAYER[layer], g], pos, Color(cc.r, cc.g, cc.b, a))
					else:
						_o("pipe_%s_%d" % [StationMap.PIPE_LAYER_NAMES[layer], g], pos, Color(1, 1, 1, a))
	# the scan ring
	draw_arc(Vector2(_origin) * Defs.TILE + Vector2(16, 16), (rr + 0.5) * Defs.TILE * (0.3 + 0.7 * _t / PERIOD), 0, TAU, 48, Color(0.4, 0.9, 1.0, 0.25 * (1.0 - _t / PERIOD)), 2.0)
