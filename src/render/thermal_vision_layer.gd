class_name ThermalVisionLayer extends Node2D
## Thermal vision reveals living heat signatures without illuminating walls or
## objects behind them. Draw above the lightmap, only while the action is active.
var refresh := 0.0
var _on := false # redraw only while the trait is held (plus once to clear)

func _init() -> void:
	z_index = 12

func _process(dt: float) -> void:
	refresh -= dt
	if refresh <= 0.0:
		refresh = 0.1
		var has: bool = Game.player != null and is_instance_valid(Game.player) and Traits.has(Game.player, "thermal_vision")
		if has or _on:
			queue_redraw()
		_on = has

func _draw() -> void:
	var user := Game.player
	if user == null or not Traits.has(user, "thermal_vision") or StatusFx.blind(user.c(&"health")):
		return
	for mob in Game.in_radius(user.root_cell(), 7, &"health"):
		if mob == user or mob.has_meta("inside") or mob.c(&"health").dead or not mob.has_c(&"mob"):
			continue
		var p: Vector2 = mob.position + Vector2(0, -17)
		var warmth := Color(1.0, 0.3, 0.04, 0.65)
		draw_circle(p + Vector2(0, -7), 4, warmth)
		draw_rect(Rect2(p + Vector2(-4, -3), Vector2(8, 13)), warmth)
		draw_circle(p, 13, Color(1.0, 0.25, 0.02, 0.15))
