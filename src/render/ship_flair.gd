class_name ShipFlair extends Node2D
## The cheap, always-moving dressing on a hull: an ensign at the stern and a jack at the
## bow that stream downwind, a soft shadow cast down onto the cloud floor, and a rope's
## worth of sag on the rail. It is a child of ShipRenderer and draws in the hull's frame,
## then counter-rotates its cloth so a flag streams the way the wind blows, not the way the
## hull happens to point.
##
## Cost: two small polygons a frame per ship. The shadow is a retained draw on its own
## node, redrawn only when the hull's layout changes.

const FLAG_COLS := [Color("#e8524a"), Color("#f2c14e"), Color("#3aa6c8"), Color("#f0ece0"), Color("#6fbf6a"), Color("#d6784a")]
const SHADOW_OFFSET := Vector2(16, 34)

var ship: Airship
var _shadow: Node2D
var _t := 0.0
var _col := Color.WHITE
var _stern := Vector2.ZERO
var _bow := Vector2.ZERO
var _bounds_n := -1

func setup(sh: Airship) -> void:
	ship = sh
	_col = FLAG_COLS[absi(hash(sh.ship_name)) % 3]

func _exit_tree() -> void:
	if is_instance_valid(_shadow):
		_shadow.queue_free()

func _ready() -> void:
	# above the deck fittings but under the lightmap
	z_index = 12
	_shadow = Node2D.new()
	# a sibling of the hull, drawn before it, so the hull lies on top of its own shadow
	_shadow.show_behind_parent = true
	_shadow.draw.connect(_draw_shadow)
	get_parent().add_child.call_deferred(_shadow)

func _process(delta: float) -> void:
	if ship == null or not ship.present:
		return
	_t += delta
	if ship.cells_map.size() != _bounds_n:
		_bounds_n = ship.cells_map.size()
		_refit()
		_shadow.queue_redraw()
	# the shadow keeps its world-space offset however the hull turns (it turns with the hull)
	var pr: float = (get_parent() as Node2D).rotation
	_shadow.position = SHADOW_OFFSET.rotated(-pr)
	queue_redraw()

func _refit() -> void:
	var mid := ship.local_pivot()
	var b := ship.shape_bounds()
	var ymid := float(b.position.y) + float(b.size.y - 1) * 0.5
	var tile := float(Defs.TILE)
	# a flagstaff a little aft of the stern rail and a jack on the bow, on the centreline
	_stern = (Vector2(float(b.position.x) + 0.5, ymid) - mid) * tile
	_bow = (Vector2(float(b.position.x + b.size.x) - 0.5, ymid) - mid) * tile

func _wind() -> Vector2:
	if Game.sky != null:
		return Game.sky.wind_vector()
	return Vector2(1, 0.2)

func _draw() -> void:
	if ship == null or not ship.present:
		return
	var w := _wind()
	var strength := clampf(w.length(), 0.3, 2.0)
	var heading := w.angle() if w.length() > 0.02 else 0.0
	# each flag is drawn under a counter-rotation, so its frame is the world's
	var local_a := heading
	_flag(_stern, local_a, strength, _col, 28.0, 0.0)
	_flag(_bow, local_a, strength, _col.lightened(0.25), 17.0, 1.7)
	_rail_rope(strength)

func _flag(pole: Vector2, ang: float, strength: float, col: Color, length: float, seed_f: float) -> void:
	draw_set_transform(pole, -global_rotation)
	var h := 26.0 if length > 20.0 else 18.0
	draw_line(Vector2(0, 2), Vector2(0, -h), Color(0.72, 0.62, 0.45), 2.0)
	draw_rect(Rect2(-1, -h - 1, 3, 2), Color(0.9, 0.75, 0.3))
	# the cloth: a strip whose spine runs downwind and ripples travelling along it
	var dirv := Vector2.from_angle(ang)
	var perp := dirv.orthogonal()
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var segs := 5
	for i in range(0, segs + 1):
		var f := float(i) / float(segs)
		var wave := sin(_t * 5.0 * strength + seed_f - f * 5.0) * (0.6 + f * 2.6) * strength * 0.7
		var half := (1.0 - f) * length * 0.24 + 1.0
		var spine := Vector2(0, -h + 3.0) + dirv * (f * length) + perp * wave
		top.append(spine + perp * -half)
		bot.append(spine + perp * half)
	var poly := PackedVector2Array()
	for p in top:
		poly.append(p)
	for i in range(bot.size() - 1, -1, -1):
		poly.append(bot[i])
	draw_colored_polygon(poly, col)
	draw_polyline(top, col.lightened(0.3), 1.0)
	draw_polyline(bot, col.darkened(0.3), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0)

## A stay from the ensign staff to the jack, sagging and shivering a little.
func _rail_rope(strength: float) -> void:
	var a := _stern + Vector2(0, -20)
	var b := _bow + Vector2(0, -13)
	if a.distance_to(b) < 24.0:
		return
	var n := 14
	var pts := PackedVector2Array()
	for i in n + 1:
		var f := float(i) / float(n)
		var p := a.lerp(b, f)
		p.y += sin(f * PI) * 6.0 + sin(_t * 2.1 * strength + f * 7.0) * 0.7 * sin(f * PI)
		pts.append(p)
	draw_polyline(pts, Color(0.22, 0.17, 0.12, 0.85), 1.0)

func _draw_shadow() -> void:
	if ship == null or not ship.present:
		return
	var mid := ship.local_pivot()
	var tile := float(Defs.TILE)
	var col := Color(0.03, 0.05, 0.12, 0.15)
	for key in ship.cells_map:
		var rel := (Vector2(key) - mid - Vector2(0.5, 0.5)) * tile
		_shadow.draw_rect(Rect2(rel, Vector2(tile, tile)), col)
