class_name CDAnalyzer extends Component
## tg destructive analyzer (code/modules/research/destructive_analyzer.dm). Load an item,
## then take it apart for research points. Each kind of thing only teaches the servers
## something the first time.

var loaded: Entity = null

func key() -> StringName:
	return &"danalyzer"

func operable() -> bool:
	var m: CMachine = e.c(&"machine")
	return m == null or m.operable()

func attackby(user: Entity, item: Entity) -> bool:
	if item.c(&"item") == null:
		return false
	if loaded != null:
		Game.tell(user, "There's already something inside!", "warn")
		return true
	if not operable():
		Game.tell(user, "%s is unpowered." % e.the().capitalize(), "warn")
		return true
	if item.has_c(&"idcard"):
		Game.tell(user, "The analyzer refuses the passcard.", "warn")
		return true
	Interact.detach(item)
	item.holder = e
	item.visible = false
	loaded = item
	Sfx.play("click", e.cell, 0.6)
	Game.visible_message(e.cell, "%s loads %s into %s." % [user.display_name, item.display_name, e.the()])
	return true

func attack_hand(_user: Entity) -> bool:
	Bus.ui_open_window.emit("danalyzer", e)
	return true

func eject(user: Entity) -> void:
	if loaded == null:
		return
	var it := loaded
	loaded = null
	it.holder = null
	it.visible = true
	var c := e.cell + Vector2i(0, 1)
	Game.drop_to_map(it, c)
	it.place(c)
	if user and user.c(&"inv"):
		user.c(&"inv").put_in_hands(it)

func destroy_item(user: Entity) -> void:
	if loaded == null or not operable():
		return
	var pts := Research.analyze_value(loaded)
	Research.analyzed[loaded.proto] = true
	Research.points += pts
	Research.experiments_run += 1
	var nm := loaded.display_name
	var it := loaded
	loaded = null
	it.holder = null
	it.destroy()
	Sfx.play("grille_hit", e.cell, 0.6)
	Fx.sparks(e.cell)
	if pts > 0.0:
		Game.visible_message(e.cell, "%s breaks down %s: +%.0f research points." % [e.the().capitalize(), nm, pts], "good")
		if user:
			Skills.add_xp(user, "science", pts)
	else:
		Game.visible_message(e.cell, "%s breaks down %s. Nothing new was learned." % [e.the().capitalize(), nm])

func examine(_user: Entity, lines: Array) -> void:
	if loaded:
		lines.append("%s is loaded." % loaded.display_name.capitalize())
	else:
		lines.append("[color=#8a93a3]Put something in it to analyze.[/color]")

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Use", "cb": attack_hand.bind(user), "priority": 7})
