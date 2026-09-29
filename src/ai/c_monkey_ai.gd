class_name CMonkeyAI extends Component
## tg /datum/ai_controller/monkey and its behaviour tree (code/datums/ai/monkey/*.bt.json,
## monkey_bt_nodes.dm, __DEFINES/monkeys.dm). In priority order each think:
##   1. escape captivity: buckled, grabbed or shut in something - resist
##   2. combat (a current target): drop it past 10 tiles; flee under 40 health; grab a
##      better weapon; a downed target gets dragged to a disposal bin and stuffed in;
##      otherwise shove them into walls or attack (bite, weapon, throw), dancing in and
##      out of reach, rallying nearby monkeys and screeching
##   3. hunger: eat the food it found
##   4. shenanigans: fiddle with what it holds, press things, hand things to people
##   5. idle: wander, screech and roar, sometimes scratch, jump, roll or wave its tail
## Every second, with no target, it picks one from its grudges (or anyone, if it's an
## angry monkey), or looks for things to press, people to give things to, food and
## better weapons.

const MONKEY_FLEE_HEALTH := 40.0
const MONKEY_ENEMY_VISION := 9
const MONKEY_FLEE_VISION := 4
const MONKEY_ITEM_SNATCH_DELAY := 2.5
const MONKEY_CUFF_RETALIATION_PROB := 20.0
const MONKEY_SYRINGE_RETALIATION_PROB := 20.0
const MONKEY_PULL_AGGRO_PROB := 5.0
const MONKEY_ATTACK_DISARM_PROB := 20.0
const MONKEY_RECRUIT_PROB := 25.0
const MONKEY_RETALIATE_PROB := 85.0
const MONKEY_HATRED_AMOUNT := 4
const MONKEY_RECRUIT_HATED_AMOUNT := 2
const MONKEY_HATRED_REDUCTION_PROB := 40.0
const NUTRITION_HUNGRY := 250.0 / 6.0 # tg NUTRITION_LEVEL_HUNGRY on this station's 0-100 scale
const COMMON_EMOTES := ["screech", "roar"]
const RARE_EMOTES := ["scratch", "jump", "roll", "tail"]

var aggressive := false # tg BB_MONKEY_AGGRESSIVE (angry monkeys)
var tamed := false # BB_MONKEY_TAMED
var target_monkeys := false # BB_MONKEY_TARGET_MONKEYS
var enemies := {} # entity id -> hatred (BB_MONKEY_ENEMIES)
var blacklist := {} # item id -> true (BB_MONKEY_BLACKLISTITEMS)
var best_force := 0.0
var gun_neurons := false
var target: Entity = null # BB_CURRENT_TARGET
var pickup_target: Entity = null
var pickup_is_pickpocket := false
var pickpocketing := false
var food_target: Entity = null
var next_hungry := 0.0
var give_target: Entity = null
var press_target: Entity = null
var wanna_press := false
var give_chance := 5.0
var disposal_target: Entity = null
var recruit_ready := 0.0
var screech_ready := 0.0
var _think := 0.0
var _secondary := 1.0
var _path: Array = []
var _path_to := Vector2i(-99999, -99999)
var _hold_until := 0.0
var _last_attack := 0.0

func key() -> StringName:
	return &"monkeyai"

func _h() -> CHealth:
	return e.c(&"health")

func _m() -> CMob:
	return e.c(&"mob")

func _inv() -> CInventory:
	return e.c(&"inv")

## tg get_able_to_run: incapacitated (ignoring restraints and grabs) monkeys don't think
func able() -> bool:
	var h := _h()
	return h != null and not h.dead and h.stat() == CHealth.CONSCIOUS and not h.has_status("stun") and not h.has_status("paralyzed") \
		and not Traits.has(e, "no_transform") and not DoAfter.busy(e)

func process(delta: float) -> void:
	if e.removed or not able():
		return
	var m := _m()
	# a player or a crew mind in this body drives it instead (tg: the controller sleeps with a client)
	if e == Game.player or e.has_c(&"brain"):
		return
	_think -= delta
	_secondary -= delta
	if _secondary <= 0.0:
		_secondary = 1.0
		if target == null:
			_secondary_tree()
	_find_weapon()
	if _think > 0.0 or (m and m.moving):
		return
	_think = maxf(0.4, m.step_time() if m else 0.4) # tg movement_delay: the pawn's own speed
	_primary_tree(maxf(delta, 0.4))

# ------------------------------------------------------------------ reactions (tg signals)
## tg retaliate: a grudge of 4 against whoever
func retaliate(who: Entity) -> void:
	if who == null or not is_instance_valid(who) or who.removed or who == e:
		return
	enemies[who.id] = enemies.get(who.id, 0) + MONKEY_HATRED_AMOUNT

## COMSIG_ATOM_WAS_ATTACKED: 85% of the time it remembers
func on_attacked(attacker: Entity) -> void:
	if Genetics.prob(MONKEY_RETALIATE_PROB):
		retaliate(attacker)

## COMSIG_LIVING_START_PULL
func on_pulled(puller: Entity) -> void:
	var h := _h()
	if h and not h.incapacitated() and Genetics.prob(MONKEY_PULL_AGGRO_PROB):
		retaliate(puller)

func on_try_syringe(user: Entity) -> void:
	if Genetics.prob(MONKEY_SYRINGE_RETALIATION_PROB):
		retaliate(user)

func on_attempt_cuff(user: Entity) -> void:
	if Genetics.prob(MONKEY_CUFF_RETALIATION_PROB):
		retaliate(user)

# ------------------------------------------------------------------ the secondary branch (1 s)
func _secondary_tree() -> void:
	if _set_combat_target():
		return
	# pressing things: 0.2% a check to want to, then a thing within 2 tiles
	if wanna_press:
		if press_target == null:
			var objs := []
			for x in Game.in_radius(e.cell, 2):
				if x != e and not x.has_c(&"mob") and not x.has_c(&"decal") and x.holder == null and (x.has_c(&"machine") or x.has_c(&"fixture") or x.has_c(&"door") or x.has_c(&"item")):
					objs.append(x)
			press_target = Genetics.rand_pick(objs)
	elif Genetics.prob(0.2):
		wanna_press = true
	# someone to hand what it's holding to
	var held := _held()
	if held:
		var best: Entity = null
		for x in Game.in_radius(e.cell, 2, &"mob"):
			if x != e and x.has_c(&"inv") and (best == null or x.dist_to(e) < best.dist_to(e)):
				best = x
		give_target = best
	else:
		give_target = null
	# hungry: food in hand or within 2 tiles
	var n: CNeeds = e.c(&"needs")
	if n and n.nutrition < NUTRITION_HUNGRY and Game.time >= next_hungry and food_target == null:
		if held and held.has_c(&"food"):
			food_target = held
		else:
			for x in Game.in_radius(e.cell, 2):
				if x.has_c(&"food") and x.holder == null and not x.tags.has("monkeycube"):
					food_target = x
					break

## tg monkey_set_combat_target: grudges within 9 (or anyone, for an angry monkey),
## weighted to the nearest
func _set_combat_target() -> bool:
	var m := _m()
	var h := _h()
	if (not h.traumas.is_empty() and Traumas.pacifist(h)) or (enemies.is_empty() and not aggressive):
		if m:
			m.intent = "help"
		return false
	var weights := []
	var total := 0
	for other in Game.in_radius(e.cell, MONKEY_ENEMY_VISION, &"mob"):
		if other == e or not other.has_c(&"health") or other.c(&"health").dead:
			continue
		if Game.lighting and not Game.lighting._los(e.cell, other.cell):
			continue
		if not enemies.has(other.id):
			if not aggressive:
				continue
			if Genetics.is_monkey(other) and not target_monkeys:
				continue
			if other.c(&"health").incapacitated():
				continue
		var w := int(ceil(100.0 / maxf(1.0, float(other.dist_to(e)))))
		weights.append([other, w])
		total += w
	if weights.is_empty():
		if m:
			m.intent = "help"
		return false
	var r := Game.rng.randi_range(1, total)
	for pair in weights:
		r -= pair[1]
		if r <= 0:
			target = pair[0]
			break
	if m:
		m.intent = "harm"
	return true

# ------------------------------------------------------------------ the primary branch
func _primary_tree(dt: float) -> void:
	if _escape_captivity():
		return
	if target != null:
		_combat(dt)
		return
	if _hunger():
		return
	if _shenanigans(dt):
		return
	_idle(dt)

## tg escape_captivity: buckled or shut in, resist
func _escape_captivity() -> bool:
	var m := _m()
	if m.buckled != null:
		Buckle.unbuckle(e, e)
		return true
	if e.has_meta("inside"):
		var box: Entity = Game.get_entity(e.get_meta("inside"))
		if box and box.has_c(&"dnascanner"):
			box.c(&"dnascanner").container_resist(e)
		elif box and box.has_c(&"storage"):
			box.c(&"storage").container_resist(e)
		return true
	if m.pulled_by != null and m.pulled_by.has_c(&"mob") and m.pulled_by.c(&"mob").grab_state >= 1:
		if Game.rng.randf() < m.resist_chance():
			m.pulled_by.c(&"mob").stop_pulling()
		return true
	return false

func _combat(dt: float) -> void:
	var h := _h()
	if target == null or not is_instance_valid(target) or target.removed or target.dist_to(e) > 10:
		target = null
		return
	var th: CHealth = target.c(&"health")
	# flee when hurt (run_away_from_target)
	if h.health() < MONKEY_FLEE_HEALTH:
		_step_away(target.cell)
		return
	if _weapon_subtree():
		return
	# the target is down: into the disposals with them
	if th.dead or th.stat() != CHealth.CONSCIOUS:
		_dispose_of(th)
		return
	# every 5 s: rally other monkeys (10 s cooldown); screech now and then
	if Game.time >= recruit_ready:
		recruit_ready = Game.time + 10.0
		_recruit()
	if Game.time >= screech_ready and Genetics.prob(25):
		screech_ready = Game.time + 5.0
		Emotes.emote(e, Genetics.rand_pick(["roar", "screech"]))
	# the attack loop, with agile movement around it
	if e.adjacent(target):
		if _can_shove_stun(target):
			Combat.shove(e, target)
			_hold_until = Game.time + 0.3
		else:
			_attack_mob(dt)
		return
	if Game.time < _hold_until:
		return
	_attack_mob(dt) # ranged: a gun, or throw what it holds
	_move_to(target.cell, true)

## tg target_can_be_shove_stunned: nothing behind them, so a shove floors them
func _can_shove_stun(t: Entity) -> bool:
	var tm: CMob = t.c(&"mob")
	if tm == null or tm.is_lying() or t.cell == e.cell:
		return false
	var d := t.cell - e.cell
	var behind := t.cell + Vector2i(signi(d.x), signi(d.y))
	return not Game.map.inb(behind) or Game.map.blocks_move_static(behind) or Game.map.dense_count[Game.map.idx(behind)] > 0

## tg monkey_attack_mob / monkey_attack
func _attack_mob(dt: float) -> void:
	if not Combat.ready_to_attack(e):
		return
	var th: CHealth = target.c(&"health")
	var holding: Entity = null
	var tinv: CInventory = target.c(&"inv")
	if tinv:
		for it in tinv.hands:
			if it:
				holding = it
				break
	var disarm := holding != null and Genetics.spt_prob(MONKEY_ATTACK_DISARM_PROB, dt)
	var weapon := _held()
	var m := _m()
	if target.cell != e.cell:
		m.face(Defs.dir_from_vec(target.cell - e.cell))
	var attacked := false
	if e.adjacent(target):
		if weapon == null:
			m.intent = "disarm" if disarm else "harm"
			Interact.click(e, target, target.cell)
			m.intent = "harm"
			if disarm and holding and blacklist.has(holding.id):
				blacklist.erase(holding.id)
		else:
			_active_hand_to(weapon)
			m.intent = "harm"
			Interact.click(e, target, target.cell)
		attacked = true
	elif weapon != null:
		var at := target.cell
		if Genetics.prob(10): # an artificial miss
			at += Vector2i(Game.rng.randi_range(-2, 2), Game.rng.randi_range(-2, 2))
		var gd: CGadget = weapon.c(&"gadget")
		if gd and gd.ranged() and Genetics.prob(95):
			gd.fire(e, at)
			gun_neurons = true
		else:
			Interact.throw_item(e, weapon, at)
		attacked = true
	if attacked and not aggressive:
		var hate: int = enemies.get(target.id, 1)
		if Genetics.prob(MONKEY_HATRED_REDUCTION_PROB):
			hate -= 1
			if hate <= 0:
				enemies.erase(target.id)
				target = null
				return
		enemies[target.id] = hate

## tg recruit_monkeys: 75% of the monkeys in view take up the grudge
func _recruit() -> void:
	for other in Game.in_radius(e.cell, MONKEY_ENEMY_VISION, &"monkeyai"):
		if other == e or Genetics.prob(MONKEY_RECRUIT_PROB):
			continue
		var ai: CMonkeyAI = other.c(&"monkeyai")
		ai.enemies[target.id] = ai.enemies.get(target.id, 0) + MONKEY_RECRUIT_HATED_AMOUNT

## tg: grab the downed target, drag it to a disposal bin within 9, stuff it in
func _dispose_of(th: CHealth) -> void:
	var m := _m()
	if disposal_target == null or not is_instance_valid(disposal_target) or disposal_target.removed:
		disposal_target = null
		for x in Game.in_radius(e.cell, 9, &"fixture"):
			if x.c(&"fixture").kind == "disposal":
				disposal_target = x
				break
	if disposal_target == null:
		target = null
		return
	if m.pulling != target:
		if not e.adjacent(target):
			_move_to(target.cell, true)
			return
		m.start_pulling(target)
		return
	if not e.adjacent(disposal_target):
		_move_to(disposal_target.cell, true)
		return
	var fx: CFixture = disposal_target.c(&"fixture")
	if fx.has_method("stuff_mob_in"):
		fx.stuff_mob_in(target, e)
	m.stop_pulling()
	target = null
	disposal_target = null

## tg generic_hunger / consume (a bite every 2 s, done when it's gone or 10% of the time)
func _hunger() -> bool:
	if food_target == null:
		return false
	if not is_instance_valid(food_target) or food_target.removed:
		food_target = null
		next_hungry = Game.time + Game.rng.randf_range(12.0, 60.0)
		return true
	var inv := _inv()
	if food_target in inv.hands:
		var f: CFood = food_target.c(&"food")
		if f:
			f.consume(e)
		if not is_instance_valid(food_target) or food_target.removed or Genetics.prob(10):
			next_hungry = Game.time + Game.rng.randf_range(12.0, 60.0)
			if is_instance_valid(food_target) and not food_target.removed and food_target in inv.hands:
				inv.drop(food_target)
			food_target = null
		_think = 2.0
		return true
	if food_target.holder != null:
		food_target = null
		return false
	if not e.adjacent(food_target):
		_move_to(food_target.cell, true)
		return true
	# pick_up with drop_held
	var held := _held()
	if held:
		inv.drop(held)
	Interact.pickup(e, food_target)
	return true

## tg monkey_shenanigans
func _shenanigans(dt: float) -> bool:
	var held := _held()
	if held and Genetics.spt_prob(5.0, dt):
		held.attack_self(e) # use_in_hand
		return true
	if press_target != null:
		if not is_instance_valid(press_target) or press_target.removed or press_target.holder != null:
			press_target = null
			return false
		if not e.adjacent(press_target):
			_move_to(press_target.cell, true)
			return true
		_m().intent = "help"
		Interact.click(e, press_target, press_target.cell)
		press_target = null
		wanna_press = false
		return true
	if give_target != null and held and Genetics.spt_prob(give_chance, dt):
		if not is_instance_valid(give_target) or give_target.removed:
			give_target = null
			return false
		if not e.adjacent(give_target):
			_move_to(give_target.cell, true)
			return true
		var ginv: CInventory = give_target.c(&"inv")
		if ginv and (ginv.hands[0] == null or ginv.hands[1] == null):
			_inv().remove_ref(held)
			Game.visible_message(e.cell, "%s hands %s to %s." % [e.display_name, held.the(), give_target.display_name])
			ginv.put_in_hands(held)
		give_target = null
		return true
	if tamed:
		return _weapon_subtree()
	return false

## tg monkey_idle: 25% a second to wander, 5% a common emote, 1% a rare one
func _idle(dt: float) -> void:
	var m := _m()
	if Genetics.spt_prob(25.0, dt) and m.pulled_by == null:
		var d: Vector2i = Defs.DIRS8[Game.rng.randi() % 8]
		m.try_step(d)
	elif Genetics.spt_prob(5.0, dt):
		Emotes.emote(e, Genetics.rand_pick(COMMON_EMOTES))
	elif Genetics.spt_prob(1.0, dt):
		Emotes.emote(e, Genetics.rand_pick(RARE_EMOTES))

# ------------------------------------------------------------------ weapons
func _held() -> Entity:
	var inv := _inv()
	if inv == null:
		return null
	for it in inv.hands:
		if it:
			return it
	return null

func _active_hand_to(it: Entity) -> void:
	var inv := _inv()
	var i := inv.hands.find(it)
	if i >= 0 and inv.active != i:
		inv.active = i

static func _force(it: Entity) -> float:
	var ci: CItem = it.c(&"item") if it else null
	return ci.force if ci else 0.0

## tg monkey_find_weapon (acquire_target/update_interaction_target): the strongest thing
## within 5, lying about or in someone's hand, better than what it holds
func _find_weapon() -> void:
	if tamed and target == null and pickup_target != null:
		return
	if _held() == null:
		best_force = 0.0
	if pickup_target != null and (not is_instance_valid(pickup_target) or pickup_target.removed):
		pickup_target = null
	var top := 0.0
	var inv := _inv()
	for it in inv.hands:
		if it and not blacklist.has(it.id) and not (it.has_c(&"item") and it.c(&"item").force_wielded > 0.0):
			top = maxf(top, _force(it))
	var best: Entity = null
	var cands := []
	for x in Game.in_radius(e.cell, 5):
		if x.has_c(&"item") and x.holder == null:
			cands.append(x)
		elif x != e and x.has_c(&"mob") and x.has_c(&"inv") and not Genetics.is_monkey(x):
			for it2 in x.c(&"inv").hands:
				if it2:
					cands.append(it2)
	for c in cands:
		if blacklist.has(c.id) or _force(c) < 2.0:
			continue
		if c.has_c(&"item") and c.c(&"item").force_wielded > 0.0:
			continue # tg TRAIT_NEEDS_TWO_HANDS
		if gun_neurons and c.has_c(&"gadget") and c.c(&"gadget").ranged():
			best = c
			break
		if _force(c) > top:
			best = c
			top = _force(c)
	if best != null and best != pickup_target:
		pickup_target = best
		pickup_is_pickpocket = best.holder != null

## tg monkey_find_weapon subtree: go to it, then take it off the floor or out of a hand
func _weapon_subtree() -> bool:
	if pickup_target == null:
		return false
	if not is_instance_valid(pickup_target) or pickup_target.removed:
		pickup_target = null
		return false
	var where := pickup_target.root()
	if not e.adjacent(where):
		_move_to(where.cell, true)
		return true
	if pickup_is_pickpocket and pickup_target.holder != null:
		_pickpocket()
	else:
		_equip(pickup_target)
		pickup_target = null
	return true

## tg monkey_equip/pickpocket: 2.5 s to snatch it
func _pickpocket() -> void:
	if pickpocketing:
		return
	var it := pickup_target
	var victim: Entity = it.holder
	if victim == null or not victim.has_c(&"inv"):
		_equip_failed(it)
		return
	Game.visible_message(victim.cell, "%s starts trying to take %s from %s!" % [e.display_name, it.the(), victim.display_name], "warn")
	pickpocketing = true
	DoAfter.start(e, victim, MONKEY_ITEM_SNATCH_DELAY, func(ok):
		pickpocketing = false
		pickup_target = null
		if not ok or not is_instance_valid(it) or it.removed or it.holder != victim or not e.adjacent(victim):
			_equip_failed(it)
			return
		var vinv: CInventory = victim.c(&"inv")
		if not it in vinv.hands:
			_equip_failed(it)
			return
		Game.visible_message(victim.cell, "[b]%s snatches %s from %s.[/b]" % [e.display_name, it.the(), victim.display_name], "bad")
		vinv.drop(it, victim.cell)
		if not _equip(it):
			pass)

func _equip_failed(it: Entity) -> void:
	if it and is_instance_valid(it):
		blacklist[it.id] = true
	pickup_target = null
	pickup_is_pickpocket = false

## tg monkey_equip/equip_item: a better weapon goes in hand; wearables get worn
func _equip(it: Entity) -> bool:
	var inv := _inv()
	if it == null or not is_instance_valid(it) or it.removed or it.tags.get("anchored", false):
		_equip_failed(it)
		return false
	if _force(it) > best_force:
		for h in inv.hands.duplicate():
			if h:
				inv.drop(h)
		if Interact.pickup(e, it):
			best_force = _force(it)
			return true
	var cl: CClothing = it.c(&"clothing")
	if cl and not (cl.slot in Species.DEFS["monkey"].get("no_equip", [])):
		if Interact.pickup(e, it) and inv.equip(it, cl.slot):
			return true
	if inv.hands[0] == null or inv.hands[1] == null:
		if Interact.pickup(e, it):
			return true
	_equip_failed(it)
	return false

# ------------------------------------------------------------------ movement
func _move_to(to: Vector2i, adjacent := true) -> void:
	var m := _m()
	if m.moving:
		return
	if _path.is_empty() or _path_to != to:
		_path = Game.ai.nav.path(e.cell, to, adjacent) if Game.ai else []
		_path_to = to
	if _path.is_empty():
		var d := to - e.cell
		m.try_step(Vector2i(signi(d.x), signi(d.y)))
		return
	var nxt: Vector2i = _path[0]
	if m.try_step(nxt - e.cell):
		_path.pop_front()
	else:
		_path.clear()

func _step_away(from: Vector2i) -> void:
	var m := _m()
	var best := Vector2i.ZERO
	var bd := -1.0
	for d in Defs.DIRS8:
		var n: Vector2i = e.cell + d
		if Game.map.blocks_move_static(n) or Game.map.dense_count[Game.map.idx(n)] > 0:
			continue
		var s := Vector2(n - from).length() + Game.rng.randf() * 0.3
		if s > bd:
			bd = s
			best = d
	if best != Vector2i.ZERO:
		m.try_step(best)

func ai_tags(out: Dictionary) -> void:
	out["monkey"] = true
	if target != null:
		out["hostile"] = true
