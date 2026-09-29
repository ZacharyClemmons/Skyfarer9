class_name CCooker extends Component
## Microwave / oven. Insert ingredients, then cook. Recipes are unordered ingredient sets.

const RECIPES := [
	{"out": "food_pizza", "in": ["food_flour", "food_tomato", "food_meat"]},
	{"out": "food_burger", "in": ["food_flour", "food_meat"]},
	{"out": "food_sandwich", "in": ["food_flour", "food_tomato"]},
	{"out": "food_soup", "in": ["food_potato", "food_tomato"]},
	{"out": "food_donut", "in": ["food_flour", "food_egg"]},
	{"out": "food_soup", "in": ["food_potato"]},
	{"out": "food_sandwich", "in": ["food_flour"]},
	{"out": "food_burger", "in": ["food_meat"]},
]

var contents: Array = []
var cooking := 0.0
var capacity := 4

func key() -> StringName:
	return &"cooker"

func attackby(user: Entity, item: Entity) -> bool:
	var f = item.c(&"food")
	if f == null or not f.ingredient:
		return false
	if contents.size() >= capacity or cooking > 0:
		Game.tell(user, "It's full.", "warn")
		return true
	Interact.detach(item)
	item.holder = e
	item.visible = false
	contents.append(item)
	Game.tell(user, "You put %s in %s." % [item.the(), e.the()])
	return true

func attack_hand(user: Entity) -> bool:
	if cooking > 0:
		return true
	if contents.is_empty():
		Game.tell(user, "It's empty.")
		return true
	start(user)
	return true

func start(user: Entity) -> bool:
	var m: CMachine = e.c(&"machine")
	if m and not m.operable():
		Game.tell(user, "It has no power.", "warn")
		return false
	cooking = 8.0
	m.active = true
	if e.proto == "microwave":
		e.set_sprite("objects", "microwave_on")
	Sfx.play("hum", e.cell)
	return true

func tick(dt: float) -> void:
	if cooking <= 0:
		return
	cooking -= dt
	if cooking <= 0:
		_finish()

func _finish() -> void:
	var m: CMachine = e.c(&"machine")
	if m:
		m.active = false
	if e.proto == "microwave":
		e.set_sprite("objects", "microwave")
	var have := []
	for it in contents:
		have.append(it.proto)
	var result := ""
	for r in RECIPES:
		var ok := true
		var pool := have.duplicate()
		for need in r["in"]:
			if need in pool:
				pool.erase(need)
			else:
				ok = false
				break
		if ok:
			result = r["out"]
			break
	var skill_mess := false
	for it in contents:
		it.destroy()
	contents.clear()
	if result == "" or skill_mess:
		Fx.smoke_puff(e.cell)
		Game.visible_message(e.cell, "%s dings. Something smells burnt." % e.the().capitalize())
		if Game.atmos:
			Game.atmos.add_gas(Game.map.idx(e.cell), Defs.G_SMOKE, 3.0, 330.0)
		return
	var food := Proto.spawn(result, e.cell)
	Sfx.play("ding", e.cell)
	Game.visible_message(e.cell, "%s dings. %s is ready." % [e.the().capitalize(), food.display_name.capitalize()])

func ai_tags(out: Dictionary) -> void:
	out["cooker"] = true
