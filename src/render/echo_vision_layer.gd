class_name EchoVisionLayer extends Node2D
## Steady, monochrome geometry on black; no flashing refresh animation.
var refresh := 0.0
var _on := false # redraw only while the trait is held (plus once to clear)
func _init() -> void: z_index = 15
func _process(dt: float) -> void:
	refresh -= dt
	if refresh <= 0.0:
		refresh = 0.1
		var has: bool = Game.player != null and is_instance_valid(Game.player) and Traits.has(Game.player, "psyker")
		if has or _on:
			queue_redraw()
		_on = has
func _draw() -> void:
	var user := Game.player
	if not is_instance_valid(user) or not Traits.has(user, "psyker"): return
	draw_rect(Rect2(0, 0, Game.map.w * Defs.TILE, Game.map.h * Defs.TILE), Color.BLACK)
	if not Psyker.can_echo(user): return
	for y in range(user.cell.y - 5, user.cell.y + 6):
		for x in range(user.cell.x - 5, user.cell.x + 6):
			var cell := Vector2i(x, y)
			if not Psyker.visible(user, cell): continue
			var rectangle := Rect2(Vector2(cell) * Defs.TILE + Vector2(2, 2), Vector2.ONE * (Defs.TILE - 4))
			if Game.map.is_solid_turf(cell):
				draw_rect(rectangle, Color(0.65, 0.65, 0.7), false, 2.0)
			else:
				draw_rect(rectangle, Color(0.13, 0.13, 0.17), false, 1.0)
			for entity in Game.at(cell):
				if Psyker.echo_highlight(user, entity):
					draw_rect(rectangle.grow(-3), Color(0.75, 0.75, 0.8), false, 2.0)
	draw_circle(user.position + Vector2(0, -15), 7, Color(0.85, 0.85, 0.95), false, 2)
