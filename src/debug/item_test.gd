class_name ItemTest extends Node
## --itemtest (with --autotest): every item prototype is spawned, put in the player's hand,
## used in hand, on themselves, on the floor next to them, on a dummy and examined, then
## thrown away. Script errors show up in the log against the item; items where nothing at
## all happened are listed at the end.

var quiet: Array = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	await _wait(0.5)
	var p: Entity = Game.player
	if p == null:
		get_tree().quit()
		return
	for m in Game.all_with(&"brain"):
		m.remove_comp(&"brain")
	var h: CHealth = p.c(&"health")
	var inv: CInventory = p.c(&"inv")
	var dummy: Entity = null
	for m in Game.all_with(&"mob"):
		if m != p:
			dummy = m
			break
	var n := 0
	for id in Proto.P.keys():
		var d: Dictionary = Proto.P[id]
		if not d.get("comps", {}).has("item"):
			continue
		n += 1
		print("ITEMTEST %s" % id)
		# fresh start each item: standing, healthy, hands empty
		h.adjust("brute", -h.brute)
		h.adjust("burn", -h.burn)
		h.stun_t = 0.0
		h.knockdown_t = 0.0
		h.cuffed = false
		for hh in inv.hands.duplicate():
			if hh:
				inv.drop(hh)
				hh.destroy()
		var floor := p.cell + Vector2i(1, 0)
		if Game.map.blocks_move_static(floor):
			floor = p.cell + Vector2i(-1, 0)
		if dummy:
			dummy.place(p.cell + Vector2i(0, 1) if not Game.map.blocks_move_static(p.cell + Vector2i(0, 1)) else p.cell + Vector2i(0, -1))
		var it := Proto.spawn(id, p.cell)
		if not inv.put_in_hands(it, inv.active):
			print("ITEMTEST can't hold %s" % id)
			it.destroy()
			continue
		it.attack_self(p)
		if is_instance_valid(it) and not it.removed and it.holder == p:
			Interact.use_item_on(p, it, p)
		await _wait(0.1)
		if is_instance_valid(it) and not it.removed and it.holder == p:
			Interact.use_on_tile(p, it, floor)
		await _wait(0.1)
		if dummy and is_instance_valid(it) and not it.removed and it.holder == p:
			p.c(&"mob").combat = false
			Interact.use_item_on(p, it, dummy)
		await _wait(0.2)
		if is_instance_valid(it) and not it.removed:
			it.examine_text(p)
			if it.holder == p:
				inv.drop(it)
			it.destroy()
		for x in Game.at(floor).duplicate():
			if x.has_c(&"item") or x.has_c(&"holosign"):
				x.destroy()
	print("ITEMTEST DONE: %d items" % n)
	get_tree().quit()

func _wait(sec: float) -> void:
	var until := Game.time + sec
	while Game.time < until:
		await get_tree().process_frame
