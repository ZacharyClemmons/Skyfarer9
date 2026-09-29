class_name Buckle extends RefCounted
## tg buckling (/atom/movable/proc/buckle_mob): strap someone into a chair (they face
## the way it faces) or onto a bed / operating table (they lie down). A buckled mob can't
## walk off; resisting, or anyone clicking the furniture, unbuckles them.

static func can_hold(f: Entity) -> bool:
	var fu: CFurniture = f.c(&"furniture") if f else null
	return fu != null and fu.kind in ["seat", "bed"] and f.holder == null

static func can_buckle(user: Entity, m: Entity, f: Entity) -> bool:
	if not can_hold(f) or not m.has_c(&"mob") or m.c(&"mob").buckled != null:
		return false
	if not user.adjacent(f) or not (m == user or m.adjacent(f) or m.cell == f.cell):
		return false
	var fu: CFurniture = f.c(&"furniture")
	if fu.occupant != null and fu.occupant != m and is_instance_valid(fu.occupant) and fu.occupant.cell == f.cell:
		return false
	if m != user and not (user.adjacent(m) or user.cell == m.cell):
		return false
	var uh: CHealth = user.c(&"health")
	return uh == null or uh.can_use_hands()

static func buckle(user: Entity, m: Entity, f: Entity) -> bool:
	if not can_buckle(user, m, f):
		return false
	var mob: CMob = m.c(&"mob")
	var fu: CFurniture = f.c(&"furniture")
	if mob.pulled_by != null and mob.pulled_by.has_c(&"mob"):
		mob.pulled_by.c(&"mob").stop_pulling()
	if m.cell != f.cell:
		m.place(f.cell)
	mob.buckled = f
	fu.occupant = m
	# a bed floors you (tg buckle_lying); CHealth lies the body down
	if fu.kind != "bed":
		# sit facing the way the chair faces (its sprite ends in _n/_e/_s/_w)
		var d: String = f.spr_name.substr(f.spr_name.length() - 1) if f.spr_name.length() > 2 and f.spr_name[-2] == "_" else "s"
		mob.face({"n": Defs.DIR_N, "e": Defs.DIR_E, "s": Defs.DIR_S, "w": Defs.DIR_W}.get(d, Defs.DIR_S))
	mob._update_pose()
	if m == user:
		Game.visible_message(f.cell, "%s buckles themselves to %s." % [m.display_name, f.the()])
	else:
		Game.visible_message(f.cell, "%s buckles %s to %s!" % [user.display_name, m.display_name, f.the()], "warn")
	Sfx.play("pickup", f.cell, 0.5)
	return true

static func unbuckle(user: Entity, m: Entity) -> void:
	var mob: CMob = m.c(&"mob")
	if mob == null or mob.buckled == null:
		return
	var f: Entity = mob.buckled
	mob.buckled = null
	if is_instance_valid(f) and f.has_c(&"furniture"):
		var fu: CFurniture = f.c(&"furniture")
		if fu.occupant == m:
			fu.occupant = null
	mob._update_pose()
	if user == m:
		Game.visible_message(m.cell, "%s unbuckles themselves from %s." % [m.display_name, f.the() if is_instance_valid(f) else "the seat"])
	elif user != null:
		Game.visible_message(m.cell, "%s unbuckles %s." % [user.display_name, m.display_name])

## tg: a mob dragged onto a table is laid on it; with an aggressive grab it's slammed.
static func onto_table(user: Entity, m: Entity, table: Entity) -> bool:
	var um: CMob = user.c(&"mob")
	if um == null or um.pulling != m or not user.adjacent(table) or not m.has_c(&"health"):
		return false
	var h: CHealth = m.c(&"health")
	m.place(table.cell)
	if um.grab_state >= 1:
		h.hurt_zone("head", 10.0, "brute", user)
		h.knockdown(4.0)
		Game.visible_message(table.cell, "%s slams %s onto %s!" % [user.display_name, m.display_name, table.the()], "bad")
		CMood.event(m, "table", "table")
		Sfx.play("punch", table.cell, 0.8)
		Bus.stimulus.emit({"type": "assault", "actor": user, "target": m, "cell": table.cell, "loud": 6.0, "illegal": true})
	else:
		h.knockdown(2.0)
		Game.visible_message(table.cell, "%s places %s onto %s." % [user.display_name, m.display_name, table.the()])
	um.stop_pulling()
	return true
