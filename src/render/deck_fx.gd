class_name DeckFx extends RefCounted
## Makes "which deck am I on" readable at a glance.
##
## The lower deck is a separate room stamped into the reserved rows below the region, so
## without help it looks like a few floor tiles floating in open sky. `Backdrop` boxes it
## in: dark ribbed timber behind the floor, portholes along the outboard wall, a warm cast
## over everything. `Indicator` is the label at the top of the screen — WEATHER DECK or
## BELOW DECK with the room's name and, when it matters, the water.

static func below(sh: Airship) -> bool:
	return sh != null and sh.present and Game.player != null and is_instance_valid(Game.player) \
		and Game.player.cell.y >= SkyGen.H and Game.fleet != null and Game.fleet.ship_of(Game.player) == sh

static func bounds_of(sh: Airship) -> Rect2i:
	var r := Rect2i(sh.lower_cells[0], Vector2i.ONE)
	for c in sh.lower_cells:
		r = r.expand(c)
		r = r.expand(c + Vector2i.ONE)
	return r

## Interior of the hull, drawn behind the tiles and in front of the sky.
class Backdrop extends Node2D:
	var sh: Airship
	var _rect := Rect2()
	var _wash := 0.0

	func setup(ship: Airship) -> Backdrop:
		sh = ship
		z_index = -11
		return self

	func _ready() -> void:
		var r := DeckFx.bounds_of(sh)
		var t := float(Defs.TILE)
		_rect = Rect2(Vector2(r.position) * t, Vector2(r.size) * t)
		visible = false

	func _process(_dt: float) -> void:
		var on := DeckFx.below(sh)
		if on != visible:
			visible = on
			if on:
				queue_redraw()

	func _draw() -> void:
		if sh == null or _rect.size == Vector2.ZERO:
			return
		var t := float(Defs.TILE)
		# the dark of the hold, well past the room so the camera never finds the edge
		draw_rect(_rect.grow(t * 16.0), Color("#0b0705"))
		var hull := _rect.grow(t * 1.5)
		draw_rect(hull, Color("#241810"))
		# planking seams and ribs
		var y := hull.position.y
		while y < hull.end.y:
			draw_line(Vector2(hull.position.x, y), Vector2(hull.end.x, y), Color("#2f2015"), 1.0)
			y += 7.0
		var x := hull.position.x
		while x < hull.end.x:
			draw_rect(Rect2(x, hull.position.y, 5.0, hull.size.y), Color("#170f08"))
			x += t * 2.0
		# portholes along the outboard wall, with the sky in them
		var day := 0.5
		if Game.sky != null:
			day = clampf(Game.sky.day_t, 0.0, 1.0)
		var glass := Color("#5b7d96").lerp(Color("#101a2a"), absf(day - 0.5) * 1.2)
		var px := _rect.position.x + t * 1.5
		while px < _rect.end.x - t:
			var at := Vector2(px, _rect.position.y + t * 0.5)
			draw_circle(at, 6.0, Color("#3a2a1a"))
			draw_circle(at, 4.5, glass)
			px += t * 3.0
		# lantern-warm floor of light under the whole room
		draw_rect(_rect, Color(0.9, 0.55, 0.2, 0.05))

## The label. One per ship; only shows for the ship the player is aboard.
class Indicator extends CanvasLayer:
	var sh: Airship
	var _lbl: Label
	var _last := ""

	func setup(ship: Airship) -> Indicator:
		sh = ship
		layer = 6
		_lbl = Label.new()
		_lbl.anchor_left = 0.5
		_lbl.anchor_right = 0.5
		_lbl.offset_left = -220.0
		_lbl.offset_right = 220.0
		_lbl.offset_top = 6.0
		_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lbl.add_theme_font_size_override("font_size", 14)
		_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_lbl.add_theme_constant_override("outline_size", 4)
		_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_lbl)
		_lbl.visible = false
		return self

	func _process(_dt: float) -> void:
		if sh == null or not sh.present or Game.player == null or not is_instance_valid(Game.player):
			_lbl.visible = false
			return
		var aboard := Game.fleet != null and Game.fleet.ship_of(Game.player) == sh
		if not aboard:
			_lbl.visible = false
			return
		var text: String
		var col: Color
		if Game.player.cell.y >= SkyGen.H:
			text = "BELOW DECK — GALLEY"
			col = Color("#e8b070")
			if sh.bilge > 0.1:
				text += "   ·   bilge %d%%" % int(sh.bilge * 100.0)
				col = Color("#8ac0e8")
		else:
			text = "WEATHER DECK"
			col = Color("#a8d4f0")
			var aw := ShipHazards.wind_strength(sh)
			if aw > ShipHazards.BREEZE:
				text += "   ·   %s" % ShipHazards.wind_word(aw)
		if text != _last:
			_last = text
			_lbl.text = text
		_lbl.add_theme_color_override("font_color", col)
		_lbl.visible = true
