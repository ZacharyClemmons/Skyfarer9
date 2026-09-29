class_name SkyPolishTest extends Node
## --systemtest: real voyage controls with isolated tutorial and wildlife fixtures.

var checks := 0
var fails := 0

func _ready() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("SYSTEM %s %s" % ["PASS" if ok else "FAIL", label])

func _run() -> void:
	Game.running = false
	var p := Game.player
	var inv: CInventory = p.c(&"inv")
	var scene := get_tree().current_scene
	var controller: PlayerController
	for child in scene.get_children():
		if child is PlayerController:
			controller = child
	var mode: ViewMode = scene.get_node("ViewMode")
	var tool := Proto.spawn("wrench", p.cell)
	inv.active = 0
	if inv.active_item() != null:
		inv.drop(inv.active_item())
	inv.put_in_hands(tool)
	Game.running = true
	Game.paused = true
	Game.hud._action("drop")
	_check("paused HUD cannot drop held tools", inv.active_item() == tool)
	var drop := InputEventKey.new()
	drop.physical_keycode = KEY_Q
	drop.keycode = KEY_Q
	drop.pressed = true
	controller._unhandled_input(drop)
	_check("paused keyboard cannot drop held tools", inv.active_item() == tool)
	Game.hud._on_slot_clicked("hand_r", MOUSE_BUTTON_LEFT)
	_check("paused inventory slots cannot swap active hands", inv.active == 0)
	mode._use(false)
	_check("paused first-person interaction preserves inventory", inv.active_item() == tool)
	Game.paused = false
	Game.running = true
	mode.active = true
	var mob: CMob = p.c(&"mob")
	var old_cell := p.cell
	Input.action_press("move_up")
	controller._process(0.016)
	_check("overhead controller yields first-person walking", p.cell == old_cell and not mob.moving)
	var helm: CHelm = scene.player_ship.helm.c(&"helm")
	# Take the helm directly; movement must remain with the pilot controller in either view.
	p.place(helm.e.cell)
	helm.take(p)
	old_cell = p.cell
	mode._process(0.016)
	_check("first-person walking yields while at the helm", p.cell == old_cell and not mob.moving)
	var throttle: float = scene.player_ship.throttle
	controller._process(0.016)
	_check("first-person helm still accepts throttle", scene.player_ship.throttle > throttle)
	Input.action_release("move_up")
	helm.release(p, true)
	mode.active = false
	Game.running = false
	_tutorial(p)
	_wildlife()
	_log_filters()
	_opening(p)
	_ship_fx()
	print("SYSTEM DONE: %d checks, %d failed" % [checks, fails])
	get_tree().quit(0 if fails == 0 else 1)

func _tutorial(p: Entity) -> void:
	var tut := Tutorial.new()
	# Start moored, but without completing the first task.
	tut.steps = [{"test": func(): return false}, {"test": func(): return true}]
	Game.player = p
	Game.running = true
	tut._process(0.3)
	_check("later milestones cannot skip an unfinished tutorial task", tut.step == 0)
	tut.steps = [{"test": func(): return true}, {"test": func(): return false}, {"test": func(): return true}]
	tut._process(0.3)
	_check("tutorial advances through completed tasks in order", tut.step == 1)
	tut._was_ashore = true
	tut._start_facing = 2
	tut.muted = true
	tut.toggle()
	_check("restarted tutorial clears voyage milestones", tut.step == 0 and not tut._was_ashore and tut._start_facing == -1)
	Game.paused = true
	tut.steps = [{"test": func(): return true}]
	tut._process(0.3)
	_check("tutorial does not advance during pause", tut.step == 0)
	Game.paused = false
	Game.running = false
	tut.free()

func _wildlife() -> void:
	var original_map := Game.map
	var original_index: Dictionary = Game.cell_index
	var original_time := Game.time
	Game.cell_index = {}
	Game.map = StationMap.new(16, 16)
	Game.map.turf.fill(Defs.T_STEEL)
	var hunter := SkyMobs.spawn("frost_wolf", Vector2i(4, 4))
	# Wildlife hunts people, not each other (CBeastAI._look), so the quarry in these
	# sight checks has to be a person. A hare would be correctly ignored.
	var prey := Crew.spawn_human("assistant", Vector2i(8, 4), {"name": "Quarry"})
	var ai: CBeastAI = hunter.c(&"beastai")
	var mob: CMob = hunter.c(&"mob")
	var health: CHealth = hunter.c(&"health")
	health.knockdown(2.0)
	mob._update_pose()
	_check("living creatures retain upright artwork when floored", is_zero_approx(mob.doll.rotation))
	health.dead = true
	mob._update_pose()
	_check("dead creature bodies retain their lying pose", is_equal_approx(absf(mob.doll.rotation), PI * 0.5))
	health.dead = false
	health.remove_status("knockdown")
	mob._update_pose()
	ai.target = prey
	Game.time = 20.0
	ai.last_seen = 20.0
	ai._look()
	_check("visible wildlife target refreshes memory", ai.target == prey and ai.last_seen == 20.0)
	Game.map.set_turf(Vector2i(6, 4), Defs.T_WALL)
	Game.time = 25.0
	ai._look()
	_check("walls stop refreshing wildlife target memory", ai.last_seen == 20.0)
	Game.time = 34.0
	ai._look()
	_check("wildlife loses hidden targets after timeout", ai.target == null)
	ai.anomalous = true
	ai._look()
	_check("anomalous creatures retain their wall-ignoring sight", ai.target == prey)
	_check("wildlife attack effect exists in shipped art", Gfx.has("fx", "atk_smash"))
	hunter.destroy()
	prey.destroy()
	Game.map = original_map
	Game.cell_index = original_index
	Game.time = original_time

func _log_filters() -> void:
	var log := MessageLog.new()
	log.add("[b]Boiler ready[/b]", "info", 12.0)
	log.add("Wolf bites sailor", "combat", 13.0)
	log.add("Low fuel", "warn", 14.0)
	log.add("Captain says hello", "say", 15.0)
	log.search = "BOILER"
	_check("log search ignores formatting and case", log.plain_text() == "Boiler ready")
	log.search = ""
	log.enabled.combat = false
	_check("combat filter hides combat and retains history", not "Wolf" in log.plain_text() and log.entries.size() == 4)
	log.enabled.combat = true
	log.preset = "combat"
	_check("combat tab contains only combat messages", log.plain_text() == "Wolf bites sailor")
	log.preset = "chat"
	_check("chat tab separates conversation from system noise", log.plain_text() == "Captain says hello")
	log.preset = "warnings"
	_check("warnings tab contains only warnings", log.plain_text() == "Low fuel")
	log.preset = "system"
	_check("systems tab contains operational messages", log.plain_text() == "Boiler ready")
	log.preset = "events"
	_check("event preset includes warnings and combat", "Low fuel" in log.plain_text() and "Wolf" in log.plain_text() and not "Captain" in log.plain_text())
	log.preset = "all"
	log.add("Captain says hello", "say", 16.0)
	_check("consecutive repeats are counted", log.entries.size() == 4 and log.entries[-1].count == 2)
	log.add("Captain says hello", "say", 30.0)
	_check("separated messages retain individual timing", log.entries.size() == 5)
	log.timestamps = true
	_check("plain log export includes readable timestamps", log.plain_text().begins_with("[00:00:12] Boiler ready"))
	log.search = "NOT FOUND"
	_check("empty searches do not destroy history", log.plain_text().is_empty() and log.entries.size() == 5)
	log.search = ""
	log.collapse = false
	log.add("[color=#7ad87a][Engineering] Steam ready[/color]", "radio", 35.0)
	log.search = "Engineering"
	_check("radio channel labels survive search and plain export", "[Engineering] Steam ready" in log.plain_text())
	log.search = ""
	for i in MessageLog.LIMIT + 10:
		log.add("Message %d" % i, "info", float(i + 40))
	_check("both stored and displayed log remain bounded", log.entries.size() == MessageLog.LIMIT and not "Boiler ready" in log.plain_text())

## The cold-open card must tell each trade the truth about the skiff.
func _opening(p: Entity) -> void:
	var skiff := CShipyard.hull_price("skiff", p)
	var cheapest := 1 << 30
	for id in ShipPlan.all_ids():
		cheapest = mini(cheapest, CShipyard.hull_price(String(id), p))
	var poorest := 1 << 30
	for id in SkyClasses.CLASSES:
		var purse := SkyClasses.purse(String(id))
		poorest = mini(poorest, purse)
		var card := Intro.new().setup("Meridian", "Home Reach", "Ring 0", purse, false)
		var text := ""
		for e in card._entries:
			text += String(e["pre"]) + String(e["text"]) + String(e["post"]) + "
"
		var says_short := "short" in text
		_check("intro card for %s is honest about the skiff (purse %d, skiff %d)" % [id, purse, skiff],
			says_short == (purse < skiff) and (purse < skiff or "near enough" in text) and (purse >= skiff or not "near enough" in text))
		card.free()
	# Informational: open QA item, the poorest trade may not afford any hull at all.
	print("SYSTEM INFO poorest purse %d, cheapest hull %d, skiff %d" % [poorest, cheapest, skiff])

func _ship_fx() -> void:
	# the puff budget must count down with the sprite leaving the tree, not with a tween
	var fx = load("res://src/ship/ship_fx.gd")
	if Game.view == null or Game.view.fx_layer == null:
		print("SYSTEM SKIP ship fx budget (no fx layer)")
		return
	var layer: Node = Game.view.fx_layer
	var before := layer.get_children()
	var start: int = fx.live
	fx.puff(Vector2.ZERO, 5)
	_check("ship fx puffs are counted while alive", fx.live > start)
	for c in layer.get_children():
		if not before.has(c):
			c.free()
	_check("ship fx budget returns when sprites leave the tree", fx.live == start)
