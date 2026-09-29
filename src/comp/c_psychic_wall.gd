class_name CPsychicWall extends Component
func key() -> StringName: return &"psychicwall"
func on_added() -> void:
	e.draw.connect(draw_wall)
	e.queue_redraw()
func draw_wall() -> void:
	e.draw_rect(Rect2(-14, -30, 28, 28), Color(0.55, 0.35, 0.85, 0.18))
	e.draw_rect(Rect2(-14, -30, 28, 28), Color(0.7, 0.55, 1.0, 0.85), false, 2)
	e.draw_line(Vector2(-10, -26), Vector2(10, -6), Color(0.65, 0.5, 0.9), 1)
func deflect(user: Entity, damage: float, kind: String) -> void:
	GeneInteraction.reflect_projectile(e, user, damage, kind)
