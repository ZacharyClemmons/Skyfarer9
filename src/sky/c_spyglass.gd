class_name CSpyglass extends Component
## A brass spyglass. Using it pushes the camera out and reads off what is in range —
## islands, ships, and anything large enough to be worth knowing about before it knows
## about you.

const ZOOM := 1.15
var glassing := false

func key() -> StringName:
	return &"spyglass"

func attack_self(user: Entity) -> bool:
	glassing = not glassing
	if user == Game.player and Game.view != null:
		Game.view.zoom_level = ZOOM if glassing else 2.0
	if glassing:
		Game.tell(user, "You put the glass to your eye.")
		_survey(user)
	else:
		Game.tell(user, "You collapse the spyglass.")
	Sfx.play("click", user.cell, 0.4)
	return true

func _survey(user: Entity) -> void:
	var from := user.root_cell()
	var found := []
	if Game.fleet != null:
		for sh in Game.fleet.ships:
			if not sh.present:
				continue
			var d: float = Vector2(sh.center() - from).length()
			if d < 4.0 or d > 70.0:
				continue
			found.append("  [b]%s[/b] — a %s, %s, %d tiles off%s" % [
				sh.ship_name, sh.hull["name"].to_lower(), CSkyCompass._bearing(Vector2(sh.center() - from)),
				int(d), ", under way" if sh.speed() > 0.3 else ", lying to"])
	if Game.sky != null and Game.sky.gen != null:
		for isl in Game.sky.gen.islands:
			var d2: float = Vector2(isl["area"].center - from).length()
			if d2 > 80.0:
				continue
			found.append("  %s — %s, %s, %d tiles" % [
				isl["name"], isl["b"]["noun"], CSkyCompass._bearing(Vector2(isl["area"].center - from)), int(d2)])
	if found.is_empty():
		Game.tell(user, "Cloud, and more cloud.")
		return
	Game.tell(user, "[b]Through the glass:[/b]\n%s" % "\n".join(found))

func on_removed() -> void:
	if glassing and Game.view != null:
		Game.view.zoom_level = 2.0
	glassing = false

func examine(_user: Entity, lines: Array) -> void:
	lines.append("[i]Use it in your hands to glass the horizon.[/i]")
