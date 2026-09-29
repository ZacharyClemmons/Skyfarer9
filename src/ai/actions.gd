class_name Act extends RefCounted
## NPC action primitives. A plan is an Array of these, executed in order by CBrain.
## Every world-changing action routes through Interact, the same code the player uses.

const RUNNING := ActBase.RUNNING
const DONE := ActBase.DONE
const FAILED := ActBase.FAILED


# ============================================================================ movement
class GoTo extends ActBase:
	var cell := Vector2i.ZERO
	var ent: Entity = null
	var adjacent := false
	var run := true
	var path: Array = []
	var repaths := 0
	var stuck := 0.0
	var last_target := Vector2i(-999, -999)
	var wait_door := 0.0

	func _init(target, adj := false, running := true) -> void:
		if target is Entity:
			ent = target
		else:
			cell = target
		adjacent = adj
		run = running
		label = "walking"

	func _target() -> Vector2i:
		if ent != null:
			return ent.root_cell()
		return cell

	func _arrived(b) -> bool:
		var me: Vector2i = b.e.cell
		var t := _target()
		if adjacent:
			return absi(me.x - t.x) <= 1 and absi(me.y - t.y) <= 1
		return me == t

	func _repath(b) -> bool:
		repaths += 1
		if repaths > 6:
			return false
		var avoid: Array = b.avoid_cells()
		path = Game.ai.nav.path(b.e.cell, _target(), adjacent, avoid)
		last_target = _target()
		return not path.is_empty() or _arrived(b)

	var refuse := false

	func start(b) -> void:
		# nobody wanders out onto the glacier by accident: only goals meant for outside
		# (or people dressed for it) path out there
		var t := _target()
		if Game.map.is_outdoor(t) and not Game.map.is_outdoor(b.e.cell) and not b.goal.get("outdoor_ok", false) and not b.outdoor_ready():
			refuse = true
			return
		_repath(b)

	func tick(b, dt: float) -> int:
		if refuse:
			return FAILED
		if ent != null and (not is_instance_valid(ent) or ent.removed):
			return FAILED
		var mob: CMob = b.mob
		mob.run = run
		if _arrived(b):
			return DONE
		if mob.moving:
			return RUNNING
		if not mob.can_move():
			return RUNNING
		var t := _target()
		if ent != null and (absi(t.x - last_target.x) + absi(t.y - last_target.y)) > 1:
			if not _repath(b):
				return FAILED
		if path.is_empty():
			if not _repath(b):
				return FAILED
			if path.is_empty():
				return DONE if _arrived(b) else FAILED
		var nxt: Vector2i = path[0]
		if nxt == b.e.cell:
			path.pop_front()
			return RUNNING
		var d = nxt - b.e.cell
		if absi(d.x) > 1 or absi(d.y) > 1:
			path.clear()
			return RUNNING
		if mob.try_step(d):
			path.pop_front()
			stuck = 0.0
			return RUNNING
		# blocked: door? person? something new?
		for ent2 in Game.at(nxt):
			var door = ent2.c(&"door")
			if door and not door.is_open():
				if door.state == CDoor.OPENING:
					return RUNNING
				if not door.has_access(b.e) or not door.powered() or door.welded:
					if b.may_force(door):
						b.inject_front([Act.PryDoor.new(ent2)])
						return RUNNING
					b.block_cell(nxt)
					path.clear()
					if not _repath(b):
						return FAILED
				return RUNNING
		stuck += dt
		if stuck > 1.2:
			stuck = 0.0
			path.clear()
			if not _repath(b):
				return FAILED
		return RUNNING


class PryDoor extends ActBase:
	var door: Entity
	var started := false
	func _init(d: Entity) -> void:
		door = d
		label = "prying a door"
	func tick(b, _dt: float) -> int:
		if not is_instance_valid(door) or door.removed or door.c(&"door").is_open():
			return DONE
		if not started:
			var bar: Entity = b.ready_tool("crowbar")
			if bar == null:
				return FAILED
			Interact.use_item_on(b.e, bar, door)
			started = true
			return RUNNING
		if DoAfter.busy(b.e):
			return RUNNING
		return DONE if door.c(&"door").state != CDoor.CLOSED else FAILED


class Flee extends ActBase:
	var from := Vector2i.ZERO
	var dist := 8
	var inner: GoTo
	func _init(danger: Vector2i, distance := 8) -> void:
		from = danger
		dist = distance
		label = "fleeing"
	func start(b) -> void:
		var best: Vector2i = b.e.cell
		var bd := -1.0
		for k in 24:
			var c: Vector2i = b.e.cell + Vector2i(Game.rng.randi_range(-dist, dist), Game.rng.randi_range(-dist, dist))
			if not Game.map.is_passable(c) or Game.map.is_outdoor(c) and not Game.map.is_outdoor(b.e.cell):
				continue
			var d := Vector2(c - from).length()
			if b.cell_dangerous(c):
				continue
			if d > bd:
				bd = d
				best = c
		inner = GoTo.new(best, false, true)
		inner.start(b)
	func tick(b, dt: float) -> int:
		return inner.tick(b, dt)


class Wander extends ActBase:
	var cells: Array
	var inner: GoTo
	var pause := 0.0
	func _init(area_cells: Array) -> void:
		cells = area_cells
		label = "wandering"
	func start(b) -> void:
		if cells.is_empty():
			return
		for k in 8:
			var c: Vector2i = cells[Game.rng.randi() % cells.size()]
			if Game.map.is_passable(c):
				inner = GoTo.new(c, false, false)
				inner.start(b)
				return
	func tick(b, dt: float) -> int:
		if inner == null:
			return DONE
		var st := inner.tick(b, dt)
		if st != RUNNING:
			return DONE
		return RUNNING


class Follow extends ActBase:
	var who: Entity
	var t := 0.0
	var dur := 30.0
	var inner: GoTo
	func _init(target: Entity, duration := 30.0) -> void:
		who = target
		dur = duration
		label = "following"
	func tick(b, dt: float) -> int:
		t += dt
		if t > dur or not is_instance_valid(who) or who.removed:
			return DONE
		if b.e.dist_to(who) <= 1:
			return RUNNING
		if inner == null or inner.tick(b, dt) != RUNNING:
			inner = GoTo.new(who, true, true)
			inner.start(b)
		return RUNNING


# ============================================================================ items
class PickUp extends ActBase:
	var item: Entity
	func _init(it: Entity) -> void:
		item = it
		label = "picking something up"
	func tick(b, _dt: float) -> int:
		if not is_instance_valid(item) or item.removed:
			b.knowledge.forget("item:%d" % (item.id if is_instance_valid(item) else 0))
			return FAILED
		var inv: CInventory = b.inv
		if item.holder == b.e or (item.holder != null and item.holder.holder == b.e):
			return DONE
		if item.holder != null:
			# still inside a closed container
			var st = item.holder.c(&"storage")
			if st and st.kind == "closet" and not st.is_open and b.e.adjacent(item.holder):
				if st.locked and not st.toggle_lock(b.e):
					return FAILED
				if not st.open(b.e):
					return FAILED
				return RUNNING
			b.knowledge.forget("item:%d" % item.id)
			return FAILED
		if not b.e.adjacent(item):
			b.knowledge.forget("item:%d" % item.id)
			return FAILED
		if inv.free_hand() < 0:
			b.stash_active()
		if Interact.pickup(b.e, item):
			return DONE
		return FAILED


class Equip extends ActBase:
	var item: Entity
	func _init(it: Entity) -> void:
		item = it
		label = "getting dressed"
	func tick(b, _dt: float) -> int:
		if not is_instance_valid(item) or item.removed:
			return FAILED
		var inv: CInventory = b.inv
		for s in inv.slots:
			if inv.slots[s] == item:
				return DONE
		if b.ready_item(item) == null:
			return FAILED
		var it: CItem = item.c(&"item")
		if it:
			for s2 in it.slots:
				var cur: Entity = inv.worn(s2)
				if cur != null and cur != item:
					# swap out whatever is there (e.g. a scarf for a breath mask)
					inv.slots.erase(s2)
					var bag: Entity = inv.worn("back")
					if not (bag and bag.c(&"storage") and bag.c(&"storage").insert(cur)):
						cur.holder = null
						inv.drop(cur)
					break
		if inv.quick_equip(item):
			return DONE
		return FAILED


class UseOn extends ActBase:
	## Use a held item (found by tool quality / tag / entity) on a target entity.
	var tool := ""
	var item: Entity = null
	var target: Entity
	var started := false
	var timeout := 20.0
	func _init(tool_or_item, tgt: Entity) -> void:
		if tool_or_item is Entity:
			item = tool_or_item
		else:
			tool = tool_or_item
		target = tgt
		label = "working"
	func tick(b, dt: float) -> int:
		timeout -= dt
		if timeout <= 0:
			return FAILED
		if not is_instance_valid(target) or target.removed:
			return FAILED
		if not started:
			var it: Entity = item
			if it == null:
				it = b.ready_tool(tool)
			else:
				it = b.ready_item(it)
			if it == null:
				return FAILED
			if not b.e.adjacent(target):
				return FAILED
			var w = it.c(&"welder")
			if w and not w.lit:
				w.attack_self(b.e)
			Interact.use_item_on(b.e, it, target)
			started = true
			return RUNNING
		if DoAfter.busy(b.e):
			return RUNNING
		return DONE


class UseOnTile extends ActBase:
	var tool := ""
	var cell := Vector2i.ZERO
	var started := false
	var timeout := 25.0
	func _init(t: String, c: Vector2i) -> void:
		tool = t
		cell = c
		label = "repairing"
	func tick(b, dt: float) -> int:
		timeout -= dt
		if timeout <= 0:
			return FAILED
		if not started:
			var me: Vector2i = b.e.cell
			if absi(me.x - cell.x) > 1 or absi(me.y - cell.y) > 1:
				return FAILED
			var it: Entity = b.ready_tool(tool) if not tool.begins_with("stack:") else b.ready_stack(tool.substr(6))
			if it == null:
				return FAILED
			var w = it.c(&"welder")
			if w and not w.lit:
				w.attack_self(b.e)
			if cell != me:
				b.mob.face(Defs.dir_from_vec(cell - me))
			Interact.use_on_tile(b.e, it, cell)
			started = true
			return RUNNING
		if DoAfter.busy(b.e):
			return RUNNING
		return DONE


class Hand extends ActBase:
	var target: Entity
	var started := false
	func _init(t: Entity) -> void:
		target = t
		label = "using something"
	func tick(b, _dt: float) -> int:
		if not is_instance_valid(target) or target.removed:
			return FAILED
		if not started:
			if not b.e.adjacent(target):
				return FAILED
			b.stash_active_if_full()
			var inv: CInventory = b.inv
			if inv.active_item() != null:
				inv.active = 1 - inv.active
			if inv.active_item() != null:
				b.stash_active()
			Interact.hand_on(b.e, target)
			started = true
			return RUNNING
		if DoAfter.busy(b.e):
			return RUNNING
		return DONE


class Spray extends ActBase:
	var cell := Vector2i.ZERO
	var t := 0.0
	var shots := 0
	func _init(c: Vector2i) -> void:
		cell = c
		label = "fighting a fire"
	func tick(b, dt: float) -> int:
		var ext: Entity = b.ready_tag("extinguisher")
		if ext == null:
			return FAILED
		t -= dt
		if t > 0:
			return RUNNING
		t = 0.55
		var target := cell
		# aim at the nearest fire we can see
		var best := 99
		for c in Game.atmos.hotspots.keys():
			var d: int = maxi(absi(c.x - b.e.cell.x), absi(c.y - b.e.cell.y))
			if d < best and d <= 3:
				best = d
				target = c
		if best == 99 or shots > 24:
			return DONE
		b.mob.face(Defs.dir_from_vec(target - b.e.cell) if target != b.e.cell else b.mob.dir)
		if not ext.c(&"extinguisher").spray(b.e, target):
			return FAILED
		shots += 1
		return RUNNING


class Consume extends ActBase:
	var item: Entity
	var t := 0.0
	func _init(it: Entity) -> void:
		item = it
		label = "eating"
	func tick(b, dt: float) -> int:
		if not is_instance_valid(item) or item.removed:
			return DONE
		if item.holder != b.e:
			if b.ready_item(item) == null:
				return FAILED
		t -= dt
		if t <= 0:
			t = 1.6
			item.c(&"food").consume(b.e)
		return RUNNING


class Vend extends ActBase:
	var machine: Entity
	var proto := ""
	func _init(m: Entity, p: String) -> void:
		machine = m
		proto = p
		label = "buying"
	func tick(b, _dt: float) -> int:
		if not is_instance_valid(machine) or not b.e.adjacent(machine):
			return FAILED
		if b.inv.free_hand() < 0:
			b.stash_active()
		var got: Entity = machine.c(&"vending").vend(b.e, proto)
		if got == null:
			return FAILED
		b.last_acquired = got
		return DONE


# ============================================================================ bodies
class Pull extends ActBase:
	var target: Entity
	func _init(t: Entity) -> void:
		target = t
		label = "grabbing"
	func tick(b, _dt: float) -> int:
		if not is_instance_valid(target) or not b.e.adjacent(target):
			return FAILED
		b.mob.start_pulling(target)
		return DONE


class StopPull extends ActBase:
	func tick(b, _dt: float) -> int:
		b.mob.stop_pulling()
		return DONE


class Attack extends ActBase:
	var target: Entity
	var t := 0.0
	var dur := 20.0
	var inner: GoTo
	func _init(tgt: Entity) -> void:
		target = tgt
		label = "fighting"
	func tick(b, dt: float) -> int:
		dur -= dt
		if dur <= 0 or not is_instance_valid(target) or target.removed:
			return DONE
		var h: CHealth = target.c(&"health")
		if h == null or h.stat() != CHealth.CONSCIOUS or h.lying():
			return DONE
		if not b.e.adjacent(target):
			if inner == null or inner.tick(b, dt) != RUNNING:
				inner = GoTo.new(target, true, true)
				inner.start(b)
			return RUNNING
		t -= dt
		if t > 0:
			return RUNNING
		t = 0.9
		b.mob.combat = true
		var weapon: Entity = b.ready_tag("weapon")
		if weapon:
			Interact.use_item_on(b.e, weapon, target)
		else:
			Interact.attack(b.e, target, b.inv.active_item())
		return RUNNING


# ============================================================================ misc
class Wait extends ActBase:
	var t := 1.0
	func _init(sec: float) -> void:
		t = sec
		label = "waiting"
	func tick(_b, dt: float) -> int:
		t -= dt
		return DONE if t <= 0 else RUNNING


class Say extends ActBase:
	var text := ""
	var channel := ""
	var fact := {}
	func _init(txt: String, ch := "", f := {}) -> void:
		text = txt
		channel = ch
		fact = f
		label = "talking"
	func tick(b, _dt: float) -> int:
		if channel != "":
			b.radio_say(channel, text, fact)
		else:
			b.say(text)
		return DONE


class Do extends ActBase:
	## Arbitrary step: callable(brain, dt) -> status (or null = DONE)
	var fn: Callable
	func _init(f: Callable, lbl := "busy") -> void:
		fn = f
		label = lbl
	func tick(b, dt: float) -> int:
		var r = fn.call(b, dt)
		if r == null:
			return DONE
		return int(r)


class Sleep extends ActBase:
	func _init() -> void:
		label = "sleeping"
	func start(b) -> void:
		b.health.fall_asleep()
	func tick(b, _dt: float) -> int:
		var n: CNeeds = b.needs
		if not b.health.sleeping:
			return DONE
		if n.energy >= 97.0:
			b.health.wake()
			return DONE
		return RUNNING


class Talk extends ActBase:
	## Walk up to someone and start a conversation, then stay in it until it's over.
	var other: Entity
	var topic := ""
	var t := 0.0
	var inner: GoTo
	var conv: Conversation = null
	var started := false
	func _init(o: Entity, tp := "") -> void:
		other = o
		topic = tp
		label = "chatting"
	func tick(b, dt: float) -> int:
		if not is_instance_valid(other) or other.removed:
			return FAILED
		var oh: CHealth = other.c(&"health")
		if oh == null or oh.stat() != CHealth.CONSCIOUS:
			return FAILED
		if not started:
			if b.e.dist_to(other) > 2:
				if inner == null or inner.tick(b, dt) != RUNNING:
					inner = GoTo.new(other, true, false)
					inner.start(b)
				t += dt
				return RUNNING if t < 25.0 else FAILED
			started = true
			b.mob.face(Defs.dir_from_vec(other.cell - b.e.cell) if other.cell != b.e.cell else b.mob.dir)
			if not b.start_conversation(other, topic):
				return FAILED
			conv = b.convo
			t = 0.0
			return RUNNING
		t += dt
		if conv == null or conv.done or b.convo != conv:
			return DONE
		if t > 60.0:
			conv.abort()
			return DONE
		if b.e.dist_to(other) > 1.5 and not b.mob.moving and b.mob.can_move():
			# drift back into earshot if they moved a step
			if inner == null or inner.tick(b, dt) != RUNNING:
				inner = GoTo.new(other, true, false)
				inner.start(b)
		return RUNNING


class Chat extends ActBase:
	## The other side of a conversation: face them and listen (the Conversation talks).
	var conv: Conversation
	var t := 0.0
	func _init(c: Conversation) -> void:
		conv = c
		label = "chatting"
	func tick(b, dt: float) -> int:
		t += dt
		if conv == null or conv.done or b.convo != conv or t > 60.0:
			return DONE
		var other: Entity = conv.b if conv.a == b.e else conv.a
		if is_instance_valid(other) and other.cell != b.e.cell:
			b.mob.face(Defs.dir_from_vec(other.cell - b.e.cell))
		return RUNNING


class Subdue extends ActBase:
	## Security taking someone down the tg way: disabler shots from range, then a flash,
	## a baton or a shove once they're close, until the suspect is on the floor, worn out
	## or out cold. Shouts a warning first.
	var target: Entity
	var t := 0.0
	var dur := 45.0
	var inner: GoTo
	var warned := false
	func _init(tgt: Entity) -> void:
		target = tgt
		label = "subduing"
	func _down(h: CHealth) -> bool:
		return h.dead or h.cuffed or h.lying() or h.stamcrit or h.stat() != CHealth.CONSCIOUS or h.incapacitated()
	func tick(b, dt: float) -> int:
		dur -= dt
		t -= dt
		if dur <= 0.0 or not is_instance_valid(target) or target.removed:
			return FAILED if dur <= 0.0 else DONE
		var h: CHealth = target.c(&"health")
		if h == null or _down(h):
			b.mob.combat = false
			return DONE
		var d: float = b.e.dist_to(target)
		var los: bool = b._los(b.e.cell, target.cell)
		if not warned and d <= 7 and los:
			warned = true
			b.say(Dialogue.fill(Dialogue.pick(Dialogue.LINES["arrest"]), {"name": Dialogue.call_name(b, target)}), {"excited": true})
		var gun: Entity = b.inv.find_item(func(x): return x.has_c(&"gadget") and x.c(&"gadget").kind == "gun" and x.c(&"gadget").charges > 0 and x.c(&"gadget").sub in ["disabler", "egun"])
		if gun and d >= 2.0 and d <= 7.0 and los:
			if t <= 0.0:
				t = 0.9
				b.ready_item(gun)
				var g: CGadget = gun.c(&"gadget")
				if g.sub == "egun":
					g.mode = "disable"
				b.mob.face(Defs.dir_from_vec(target.cell - b.e.cell))
				b.mob.combat = true
				g.fire(b.e, target.cell)
			return RUNNING
		if not b.e.adjacent(target):
			if inner == null or inner.tick(b, dt) != RUNNING:
				inner = GoTo.new(target, true, true)
				inner.start(b)
			return RUNNING
		if t > 0.0:
			return RUNNING
		t = 1.0
		b.mob.face(Defs.dir_from_vec(target.cell - b.e.cell) if target.cell != b.e.cell else b.mob.dir)
		var flash: Entity = b.inv.find_item(func(x): return x.has_c(&"gadget") and x.c(&"gadget").kind == "flash" and not x.c(&"gadget").burnt_out)
		var baton: Entity = b.inv.find_item(func(x): return x.has_c(&"secgear") and x.c(&"secgear").kind == "baton" and x.c(&"secgear").charge > 0)
		if flash and randf() < 0.5:
			b.ready_item(flash)
			Interact.use_item_on(b.e, flash, target)
		elif baton:
			b.ready_item(baton)
			var sg: CSecurityGear = baton.c(&"secgear")
			if not sg.on:
				sg.attack_self(b.e)
			b.mob.combat = true
			Interact.use_item_on(b.e, baton, target)
		else:
			# a shove puts them on the floor, unless it would send them into a bystander:
			# then a firm grab holds them for the cuffs instead
			var push: Vector2i = target.cell - b.e.cell
			var behind: Vector2i = target.cell + Vector2i(signi(push.x), signi(push.y))
			if Game.at(behind).any(func(x): return x.has_c(&"mob")):
				if b.mob.pulling != target:
					b.mob.intent = "grab"
					Interact.grab(b.e, target)
				else:
					return DONE # held: cuff them
			else:
				b.mob.intent = "disarm"
				Combat.shove(b.e, target)
		return RUNNING
