class_name CShipNav extends Component
## The navigation table: a chart of the region with every island the crew has seen
## marked on it, plus the ship's own state. Reading it is how you decide where to go.

func key() -> StringName:
	return &"shipnav"

func ship() -> Airship:
	return Game.fleet.ship_at(e.cell) if Game.fleet else null

func attack_hand(user: Entity) -> bool:
	_read(user)
	return true

func _read(user: Entity) -> void:
	var lines := []
	var sh := ship()
	if sh != null:
		lines.append("[b]%s[/b]" % sh.status_text())
	if Game.sky != null:
		lines.append("%s — %s" % [Game.sky.gen.region_name.capitalize(), Game.sky.status_text()])
		lines.append("")
		var from: Vector2i = sh.center() if sh != null else user.root_cell()
		var rows := []
		for isl in Game.sky.gen.islands:
			var to: Vector2i = isl["area"].center
			rows.append([Vector2(to - from).length(), isl])
		rows.sort_custom(func(a, b): return a[0] < b[0])
		for r in rows:
			var isl: Dictionary = r[1]
			lines.append("  %-22s %-12s %-14s %4d tiles%s" % [
				isl["name"], isl["b"]["name"], CSkyCompass._bearing(Vector2(isl["area"].center - from)),
				int(r[0]), "   [color=#7ad87a](home)[/color]" if isl.get("home", false) else ""])
	Game.tell(user, "[b]Chart of this sky[/b]\n%s" % "\n".join(lines))
	Sfx.play("ui_select", e.cell, 0.4)

func examine(_user: Entity, lines: Array) -> void:
	lines.append("[i]Use it to read off the islands in this sky and where they lie.[/i]")

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Read the chart", "priority": 25, "cb": func(): _read(user)})
