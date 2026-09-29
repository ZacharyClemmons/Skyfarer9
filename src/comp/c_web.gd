class_name CWeb extends Component
## tg /obj/structure/spider/stickyweb/genetic (spiderwebs.dm): a web from the webbing
## mutation. Its weaver walks through; anyone else sticks half the time, losing 10-15
## stamina (or tripping over it when already exhausted). A web weaver can pull it apart
## again (2 s).

var stuck_chance := 50.0

func key() -> StringName:
	return &"web"

## tg on_entered
func on_entered(victim: Entity) -> void:
	if victim.id == e.tags.get("allowed", -1):
		return
	var vm: CMob = victim.c(&"mob")
	if vm and vm.pulled_by and vm.pulled_by.id == e.tags.get("allowed", -1):
		return
	var h: CHealth = victim.c(&"health")
	if h == null or not Genetics.prob(stuck_chance):
		return
	# tg stuck_react
	if h.stamina_loss() > 90.0:
		if not h.lying():
			Game.tell(victim, "You trip over %s due to exhaustion!" % e.the(), "warn")
		h.knockdown(3.0)
		return
	if Genetics.prob(25):
		Game.tell(victim, "Stuck in web!", "warn")
		Fx.jolt(victim, 1.0)
	h.adjust("stamina", float(Game.rng.randi_range(10, 15)))

func attack_hand(user: Entity) -> bool:
	if not Traits.has(user, "web_weaver"):
		return false
	Game.visible_message(e.cell, "%s begins weaving %s..." % [user.display_name, e.the()])
	DoAfter.start(user, e, 2.0, func(ok):
		if ok and is_instance_valid(e) and not e.removed:
			e.destroy())
	return true
