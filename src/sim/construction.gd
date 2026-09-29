class_name Construction extends RefCounted
## tg construction and deconstruction: what each tool does to furniture, closets, machines
## and wall fixtures, and building machines back up from frames.
##
##   furniture   wrench: take apart into its sheets (tables, chairs, stools, beds, benches)
##   closets     welder: weld a closed one shut / cut an open one apart; wrench: bolt it down
##               or free it
##   machines    screwdriver: open the maintenance panel (default_deconstruction_screwdriver);
##               crowbar with it open: pry it apart into a frame and its circuit board
##               (default_deconstruction_crowbar); wrench: unbolt it from the floor
##   frames      wrench to anchor, 5 cable to wire, the circuit board, screwdriver to finish
##               (tg /obj/structure/frame/machine); welder takes a bare frame apart
##   fixtures    screwdriver: unscrew a wall fixture into a wall frame you can hang again
##   lights      an empty hand takes the tube out (it burns if it's lit and you've no gloves)

## Machines that come apart into a frame and a board. value: "machine" or "computer" frame
const DECONSTRUCTIBLE := {
	"vending": "machine", "console": "computer", "microwave": "machine", "oven": "machine", "hydro_tray": "machine",
	"chem_dispenser": "machine", "protolathe": "machine", "destructive_analyzer": "machine", "server_rack": "machine",
	"autolathe": "machine", "recharger": "machine", "chem_master": "machine", "chem_heater": "machine", "jukebox": "machine",
	"arcade": "computer", "disposal": "machine", "coffee_machine": "machine", "water_cooler": "machine", "desk_computer": "computer",
	"generator": "machine", "thermo_heater": "machine", "thermo_freezer": "machine", "pipe_dispenser": "machine",
}
## Wall fixtures a screwdriver takes down (tg wallframes)
const WALL_FIXTURES := ["light_fixture", "light_fixture_cold", "emergency_light", "intercom", "status_display", "fire_alarm",
	"air_alarm", "ext_cabinet", "fireaxe_cabinet", "noticeboard", "mirror", "wall_clock", "sign_med", "sign_sec", "sign_eng",
	"sign_sci", "sign_cmd", "sign_srv", "sign_cargo", "sign_bar", "sign_danger", "sign_atmos", "med_cabinet"]
## What furniture gives back
const FURNITURE_SHEETS := {"table": ["sheet_metal", 1], "counter": ["sheet_metal", 1], "chair": ["sheet_metal", 1], "bar_stool": ["sheet_metal", 1],
	"bed": ["sheet_metal", 2], "bench": ["sheet_metal", 1], "op_table": ["sheet_metal", 2], "med_bed": ["sheet_metal", 2], "iv_drip": ["rods", 2],
	"wardrobe": ["sheet_wood", 4], "bookshelf": ["sheet_wood", 4], "display_case": ["sheet_glass", 2], "filing_cabinet": ["sheet_metal", 2],
	"trash_bin": ["sheet_metal", 1], "sink": ["sheet_metal", 1], "shower": ["sheet_metal", 1], "toilet": ["sheet_metal", 1], "pegboard": ["sheet_wood", 1]}

static func _tool(item: Entity) -> String:
	var it: CItem = item.c(&"item") if item else null
	return it.tool if it else ""

static func _lit_welder(item: Entity) -> bool:
	return item.has_c(&"welder") and item.c(&"welder").lit

## Called from Interact.use_item_on when the target's own components didn't use the item
## (and not in combat mode). True if a tool did something.
static func tool_act(user: Entity, item: Entity, target: Entity) -> bool:
	var tool := _tool(item)
	# frames
	var fr: CFrame = target.c(&"frame")
	if fr:
		return fr.use(user, item)
	# closets and crates
	var st: CStorage = target.c(&"storage")
	if st and st.kind == "closet":
		if tool == "welder" and _lit_welder(item):
			_weld_closet(user, item, target, st)
			return true
		if tool == "wrench":
			_toggle_anchor(user, target, 2.0)
			return true
	# machines
	if DECONSTRUCTIBLE.has(target.proto):
		match tool:
			"screwdriver":
				var open: bool = not target.tags.get("panel_open", false)
				target.tags["panel_open"] = open
				Sfx.play("click", target.cell, 0.6)
				Game.visible_message(target.cell, "%s %s the service hatch of %s." % [user.display_name, "opens" if open else "closes", target.the()])
				return true
			"crowbar":
				if not target.tags.get("panel_open", false):
					Game.tell(user, "Open the service panel with a screwdriver first.", "warn")
					return true
				Game.visible_message(target.cell, "%s starts prying apart %s." % [user.display_name, target.the()])
				DoAfter.start(user, target, 3.0 * Skills.speed(user, "construction"), func(ok):
					if ok and is_instance_valid(target) and not target.removed:
						deconstruct_machine(user, target))
				return true
			"wrench":
				if DECONSTRUCTIBLE[target.proto] == "machine":
					_toggle_anchor(user, target, 2.0)
					return true
	# wall fixtures
	if target.proto in WALL_FIXTURES and tool == "screwdriver":
		Game.visible_message(target.cell, "%s starts unscrewing %s from the wall." % [user.display_name, target.the()])
		DoAfter.start(user, target, 3.0, func(ok):
			if ok and is_instance_valid(target) and not target.removed:
				var wf := Proto.spawn("wallframe", target.cell, {"name": "%s frame" % Proto.P.get(target.proto, {}).get("name", target.proto)})
				wf.tags["wall_proto"] = target.proto
				Sfx.play("ratchet", target.cell, 0.6)
				Game.visible_message(target.cell, "%s takes down %s." % [user.display_name, target.the()])
				target.destroy())
		return true
	# furniture
	if FURNITURE_SHEETS.has(target.proto) and tool == "wrench":
		Game.visible_message(target.cell, "%s starts disassembling %s." % [user.display_name, target.the()])
		DoAfter.start(user, target, 2.0 * Skills.speed(user, "construction"), func(ok):
			if ok and is_instance_valid(target) and not target.removed:
				var give: Array = FURNITURE_SHEETS[target.proto]
				var sheet: String = give[0]
				if target.proto == "table" and target.spr_name.begins_with("table_wood"):
					sheet = "sheet_wood"
				elif target.proto == "table" and target.spr_name.begins_with("table_glass"):
					sheet = "sheet_glass"
				var stg: CStorage = target.c(&"storage")
				if stg:
					for it in stg.contents.duplicate():
						stg.remove(it)
						Game.drop_to_map(it, target.cell)
						it.place(target.cell)
				Proto.spawn(sheet, target.cell, {"comps": {"stack": {"amount": give[1]}}})
				Sfx.play("ratchet", target.cell, 0.6)
				Game.visible_message(target.cell, "%s disassembles %s." % [user.display_name, target.the()])
				Skills.add_xp(user, "construction", 3.0)
				target.destroy())
		return true
	return false

static func _toggle_anchor(user: Entity, target: Entity, t: float) -> void:
	var anchored: bool = target.tags.get("anchored", true)
	Game.visible_message(target.cell, "%s starts %s %s." % [user.display_name, "unfastening" if anchored else "securing", target.the()])
	DoAfter.start(user, target, t, func(ok):
		if ok and is_instance_valid(target) and not target.removed:
			target.tags["anchored"] = not anchored
			Sfx.play("ratchet", target.cell, 0.7)
			Game.visible_message(target.cell, "%s %s %s." % [user.display_name, "unfastens" if anchored else "secures", target.the()]))

## tg closet welder_act: closed = weld shut, open = cut it apart.
static func _weld_closet(user: Entity, item: Entity, target: Entity, st: CStorage) -> void:
	if user in st.occupants or item.c(&"welder").fuel < 1.0:
		Game.tell(user, "You can't weld this from here or without enough fuel.", "warn")
		return
	Interact.weld_flash(user)
	if st.is_open:
		Game.visible_message(target.cell, "%s begins cutting %s apart." % [user.display_name, target.the()], "warn")
		DoAfter.start(user, target, 4.0, func(ok):
			if ok and is_instance_valid(target) and not target.removed and st.is_open and item.c(&"welder").lit and item.c(&"welder").use_fuel(1.0):
				for it in st.contents.duplicate():
					st.contents.erase(it)
					it.holder = null
					it.visible = true
					Game.drop_to_map(it, target.cell)
					it.place(target.cell)
				Proto.spawn("sheet_metal", target.cell, {"comps": {"stack": {"amount": 2}}})
				Game.visible_message(target.cell, "%s cuts %s apart." % [user.display_name, target.the()])
				target.destroy())
		return
	var welded: bool = target.tags.get("welded", false)
	Game.visible_message(target.cell, "%s begins %s %s." % [user.display_name, "unwelding" if welded else "welding shut", target.the()], "warn")
	DoAfter.start(user, target, 4.0, func(ok):
		if ok and is_instance_valid(target) and not target.removed and not st.is_open and target.tags.get("welded", false) == welded and item.c(&"welder").lit and item.c(&"welder").use_fuel(1.0):
			target.tags["welded"] = not welded
			Game.visible_message(target.cell, "%s %s %s." % [user.display_name, "unwelds" if welded else "welds shut", target.the()]))

## tg default_deconstruction_crowbar: a frame, the board (remembering what it was), and
## whatever was inside.
static func deconstruct_machine(user: Entity, target: Entity) -> void:
	var c := target.cell
	var frame_kind: String = DECONSTRUCTIBLE.get(target.proto, "machine")
	var board := Proto.spawn("circuit_board", c, {"name": "circuit board (%s)" % target.display_name})
	board.tags["board_for"] = target.proto
	board.tags["board_ov"] = board_overrides(target)
	var fr := Proto.spawn("machine_frame" if frame_kind == "machine" else "computer_frame", c)
	fr.c(&"frame").state = 1
	fr.c(&"frame")._refresh()
	for comp_name in [&"storage", &"lathe"]:
		var stg = target.c(comp_name)
		if comp_name == &"storage" and stg:
			for it in stg.contents.duplicate():
				stg.contents.erase(it)
				it.holder = null
				it.visible = true
				Game.drop_to_map(it, c)
				it.place(c)
		if comp_name == &"lathe" and stg:
			for m in CLathe.MAT_SHEET:
				var n := int(stg.mats.get(m, 0.0) / CLathe.SHEET)
				if n > 0:
					Proto.spawn(CLathe.MAT_SHEET[m], c, {"comps": {"stack": {"amount": n}}})
	Proto.spawn("cable_coil", c, {"comps": {"stack": {"amount": 5}}})
	Sfx.play("ratchet", c, 0.8)
	Game.visible_message(c, "%s pries %s apart." % [user.display_name, target.the()])
	Skills.add_xp(user, "construction", 8.0)
	target.destroy()

## What the rebuilt machine needs to be the same machine again.
static func board_overrides(target: Entity) -> Dictionary:
	var ov := {"name": target.display_name, "spr": target.spr_name}
	var comps := {}
	var con: CConsole = target.c(&"console")
	if con:
		comps["console"] = {"kind": con.kind, "tank": con.tank}
	var vd: CVending = target.c(&"vending")
	if vd:
		var prods := []
		for pr in vd.products:
			prods.append([pr["proto"], pr["count"]])
		comps["vending"] = {"products": prods}
	var la: CLathe = target.c(&"lathe")
	if la:
		comps["lathe"] = {"kind": la.kind}
	var cm: CChemMachine = target.c(&"chemmachine")
	if cm:
		comps["chemmachine"] = {"kind": cm.kind}
	if not comps.is_empty():
		ov["comps"] = comps
	return ov

## Hang a wall frame back up: use it on a floor tile under a wall.
static func place_wallframe(user: Entity, item: Entity, cell: Vector2i) -> bool:
	var proto: String = item.tags.get("wall_proto", "")
	if proto == "":
		return false
	if not Game.map.is_wall(cell + Vector2i(0, -1)) or Game.map.blocks_move_static(cell):
		Game.tell(user, "It needs a wall to hang on (stand it on the floor just below one).", "warn")
		return true
	for x in Game.at(cell):
		if x.wall_mounted:
			Game.tell(user, "There's already something mounted there.", "warn")
			return true
	DoAfter.start(user, null, 2.0, func(ok):
		if ok and is_instance_valid(item) and not item.removed:
			var fx := Proto.spawn(proto, cell)
			if fx.has_c(&"light") and Game.lighting:
				Game.lighting.register(fx.c(&"light"))
			Interact.detach(item)
			item.destroy()
			Sfx.play("ratchet", cell, 0.6)
			Game.visible_message(cell, "%s mounts %s on the wall." % [user.display_name, fx.the()]))
	return true

## tg light/attack_hand: take the tube out (and burn your hand on a lit one).
static func take_tube(user: Entity, target: Entity) -> bool:
	var l: CLight = target.c(&"light")
	if l == null or l.kind != "fixture" or l.broken:
		return false
	if l.lit:
		var inv: CInventory = user.c(&"inv")
		var g: Entity = inv.worn("gloves") if inv else null
		if g == null:
			user.c(&"health").hurt_zone("r_hand" if inv.active == 1 else "l_hand", 5.0, "burn", null)
			Game.tell(user, "You try to remove the light tube, but you burn your hand on it!", "bad")
			return true
	l.broken = true
	l.refresh()
	l._update_sprite()
	var tube := Proto.spawn("light_tube", user.cell)
	user.c(&"inv").put_in_hands(tube)
	Game.visible_message(target.cell, "%s removes the light tube from %s." % [user.display_name, target.the()])
	return true
