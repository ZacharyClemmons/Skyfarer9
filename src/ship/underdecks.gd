class_name Underdecks extends RefCounted
## Stacked ship rooms live in the reserved rows below the island region. They use the
## same map, movement, inventory, atmosphere and entity systems as the weather deck.
## A stair maps one local hull cell to one cell in its ship's lower-deck instance.

const SLOT := 32
const COLS := 16
const ROWS := 2
static var occupied := {} # atlas slot -> ship id
static var slots := {} # ship id -> atlas slot

class StairMark extends Node2D:
	var word := "UP"
	func _draw() -> void:
		Underdecks.paint_stair(self, Vector2(-Defs.TILE * 0.5, -Defs.TILE * 0.5), word)

static func reset() -> void:
	ShipHazards.reset()
	occupied.clear()
	slots.clear()

static func _upper_cell(sh: Airship) -> Vector2i:
	if sh.upper_stair_local.x < -9000:
		return Vector2i(-1, -1)
	return sh.cell(sh.upper_stair_local.x, sh.upper_stair_local.y)

static func stair_at(c: Vector2i) -> bool:
	if Game.fleet == null:
		return false
	for sh in Game.fleet.ships:
		if sh.present and not sh.lower_cells.is_empty() and near_stair(sh, c) != "":
			return true
	return false

## "down" if `c` is on or right beside the weather-deck end of the stair, "up" if it is on
## or right beside the lower end, "" otherwise. Being next to it is enough: nobody should
## have to land on one exact tile to be allowed to use a stair.
static func near_stair(sh: Airship, c: Vector2i) -> String:
	if sh == null or sh.lower_cells.is_empty():
		return ""
	var top := _upper_cell(sh)
	if c.y < SkyGen.H:
		if top.x >= 0 and absi(c.x - top.x) + absi(c.y - top.y) <= 1:
			return "down"
	elif sh.lower_stair.x >= 0 and absi(c.x - sh.lower_stair.x) + absi(c.y - sh.lower_stair.y) <= 1:
		return "up"
	return ""

## The ship's surface position for weather, fauna and traffic while somebody is below.
static func world_cell(p: Entity) -> Vector2i:
	if p == null:
		return Vector2i.ZERO
	if p.cell.y < SkyGen.H or Game.fleet == null:
		return p.root_cell()
	var sh: Airship = Game.fleet.ship_of(p)
	return _upper_cell(sh) if sh != null and not sh.lower_cells.is_empty() else p.root_cell()

static func ensure(sh: Airship) -> void:
	if sh == null or not sh.present or not sh.lower_cells.is_empty() or sh.cells_map.size() < 20:
		return
	var slot := -1
	for i in COLS * ROWS:
		if not occupied.has(i):
			slot = i
			break
	if slot < 0:
		push_warning("No free below-deck berth for " + sh.ship_name)
		return
	var map := Game.map
	if map == null or map.h < SkyGen.H + SLOT * ROWS:
		return
	var upper := Vector2i(-1, -1)
	var best := 1 << 30
	if sh.lower_plan.has(sh.lower_entry_local):
		var requested := sh.cell(sh.lower_entry_local.x, sh.lower_entry_local.y)
		if (sh.deck_cells.has(requested) or sh.inside_cells.has(requested)) and map.is_passable(requested) and map.dense_count[map.idx(requested)] == 0:
			upper = requested
	for c in sh.deck_cells:
		if upper.x >= 0:
			break
		if not map.is_passable(c) or map.dense_count[map.idx(c)] > 0:
			continue
		var k := sh.local_of(c)
		var score := absi(k.x) + absi(k.y)
		if score < best:
			best = score
			upper = c
	if upper.x < 0:
		return
	var custom := not sh.lower_plan.is_empty() and upper == sh.cell(sh.lower_entry_local.x, sh.lower_entry_local.y)
	var bounds := ShipPlan.bounds(sh.lower_plan if custom else sh.cells_map)
	var width := bounds.size.x if custom else clampi(bounds.size.x - 2, 8, 24)
	var height := bounds.size.y if custom else clampi(bounds.size.y - 2, 6, 22)
	if width > 30 or height > 30:
		return
	var base := Vector2i((slot % COLS) * SLOT + (SLOT - width) / 2,
		SkyGen.H + (slot / COLS) * SLOT + (SLOT - height) / 2)
	var area := map.new_area("%s — lower deck / galley" % sh.ship_name, "civilian")
	area.room_kind = "ship_lower"
	area.power_equip = true
	area.power_light = true
	area.power_environ = true
	area.outdoor = false
	sh.areas[area.id] = area
	var touched := []
	for y in height:
		for x in width:
			var local := bounds.position + Vector2i(x, y)
			if custom and not sh.lower_plan.has(local):
				continue
			var c := base + Vector2i(x, y)
			var idx := map.idx(c)
			var wall := String(sh.lower_plan.get(local, "")) == "#" if custom else x == 0 or y == 0 or x == width - 1 or y == height - 1
			map.turf[idx] = Defs.T_HULLWOOD if wall else Defs.T_DECK
			map.structure[idx] = Defs.S_NONE
			map.variant[idx] = (x + y * 3) % 4
			map.turf_hp[idx] = float(Defs.TURFS[map.turf[idx]].get("hp", 100))
			map.area[idx] = area.id
			area.cells.append(c)
			sh.lower_cells.append(c)
			touched.append(c)
	area.center = base + Vector2i(width / 2, height / 2)
	sh.lower_stair = base + (sh.lower_entry_local - bounds.position if custom else Vector2i(2, height / 2))
	sh.upper_stair_local = sh.local_of(upper)
	occupied[slot] = sh.id
	slots[sh.id] = slot
	# The furniture stays with this instance while the hull moves above it.
	for entry in ([] if custom else [["galley_stove", Vector2i(width - 3, 2)],
			["counter", Vector2i(width - 4, 2)], ["bed", Vector2i(width - 3, height - 3)],
			["deck_lantern", Vector2i(width / 2, height / 2)]]):
		if Proto.has(entry[0]):
			var part := Proto.spawn(entry[0], base + entry[1])
			part.tags["lower_ship"] = sh.id
			sh.lower_parts.append(part)
	var mark := StairMark.new()
	mark.position = Entity.cell_to_pos(sh.lower_stair)
	mark.z_index = 1
	Game.view.add_child(mark)
	sh.lower_parts.append(mark)
	var back := DeckFx.Backdrop.new().setup(sh)
	Game.view.add_child(back)
	sh.lower_parts.append(back)
	var tag := DeckFx.Indicator.new().setup(sh)
	Game.view.add_child(tag)
	sh.lower_parts.append(tag)
	var water := ShipHazards.WaterFx.new()
	water.sh = sh
	water.z_index = 1
	Game.view.add_child(water)
	sh.lower_parts.append(water)
	if Proto.has("bilge_pump"):
		# beside the stair, where somebody will trip over it at the wrong moment
		var pump := Proto.spawn("bilge_pump", sh.lower_stair + Vector2i(0, 1) if not custom else sh.lower_stair + Vector2i(1, 0))
		if pump != null:
			pump.tags["lower_ship"] = sh.id
			sh.lower_parts.append(pump)
	for c in touched:
		if Game.atmos != null and Game.atmos.map != null:
			Game.atmos.retile(c)
			if not map.is_solid_turf(c):
				var idx := map.idx(c)
				for gas in Defs.GAS_COUNT:
					Game.atmos.gas[gas][idx] = 0.0
				Game.atmos.gas[Defs.G_O2][idx] = Defs.MOLES_CELLSTANDARD * 0.21
				Game.atmos.gas[Defs.G_N2][idx] = Defs.MOLES_CELLSTANDARD * 0.79
				Game.atmos.temp[idx] = Defs.T20C
				Game.atmos.wake(c)
	if Game.view != null:
		Game.view.mark_cells_dirty(touched)
	if Game.lighting != null:
		Game.lighting.mark_ambient_dirty(touched)
	if Game.fleet != null:
		Game.fleet.claim_tiles(sh)
	if sh.renderer != null and is_instance_valid(sh.renderer):
		sh.renderer.queue_redraw()

## Shift+E on the stair. A shut hatch keeps smoke, heat and draught where they are and
## starves a galley fire of air, at the price of everyone below being shut in with it.
static func toggle_hatch(p: Entity) -> bool:
	if p == null or Game.fleet == null:
		return false
	var sh: Airship = Game.fleet.ship_of(p)
	if sh == null or sh.lower_cells.is_empty() or near_stair(sh, p.cell) == "":
		return false
	sh.hatch_shut = not sh.hatch_shut
	Sfx.play("ratchet", p.cell, 0.7)
	Game.tell(p, "You dog the companionway hatch shut. The galley is sealed off." if sh.hatch_shut
		else "You throw the hatch open. Air moves between the decks again.", "info")
	return true

static func use(p: Entity) -> bool:
	if p == null or Game.fleet == null:
		return false
	var sh: Airship = Game.fleet.ship_of(p)
	if sh == null or sh.lower_cells.is_empty():
		return false
	var way := near_stair(sh, p.cell)
	if way == "":
		return false
	if sh.hatch_shut:
		Game.tell(p, "The hatch is dogged shut. (Shift+E to open it.)", "warn")
		return true
	var descending := way == "down"
	var dest := sh.lower_stair if descending else _upper_cell(sh)
	if dest.x < 0 or not Game.map.is_passable(dest) or Game.map.dense_count[Game.map.idx(dest)] > 0:
		Game.tell(p, "Something is in the way at the bottom of the stair." if descending else "Something is blocking the top of the stair.", "warn")
		return true
	p.place(dest)
	if p == Game.player:
		Game.view.camera.position = p.position
		Game.view.camera.reset_smoothing()
		Game.tell(p, "You go below deck, into the galley." if descending else "You climb back onto the weather deck.", "info")
	return true

static func clear(sh: Airship) -> void:
	if sh == null or sh.lower_cells.is_empty():
		return
	for part in sh.lower_parts:
		if is_instance_valid(part):
			if part is Entity:
				if not part.removed:
					part.destroy()
			else:
				part.queue_free()
	sh.lower_parts.clear()
	var touched := sh.lower_cells.duplicate()
	var map := Game.map
	var area_id: int = map.area[map.idx(sh.lower_stair)]
	for c in touched:
		if not map.inb(c):
			continue
		var idx := map.idx(c)
		map.turf[idx] = Defs.T_SKY
		map.structure[idx] = Defs.S_NONE
		map.area[idx] = 0
		map.dense_count[idx] = 0
	if sh.areas.has(area_id):
		sh.areas[area_id].cells.clear()
		sh.areas.erase(area_id)
	sh.lower_cells.clear()
	sh.lower_stair = Vector2i(-1, -1)
	sh.upper_stair_local = Vector2i(-9999, -9999)
	if slots.has(sh.id):
		occupied.erase(slots[sh.id])
		slots.erase(sh.id)
	if Game.view != null:
		Game.view.mark_cells_dirty(touched)

static func paint_stair(canvas: CanvasItem, at: Vector2, word: String) -> void:
	var tile := float(Defs.TILE)
	canvas.draw_rect(Rect2(at + Vector2(3, 3), Vector2(tile - 6, tile - 6)), Color("#30291f"))
	canvas.draw_rect(Rect2(at + Vector2(4, 4), Vector2(tile - 8, tile - 8)), Color("#b78b52"), false, 2.0)
	for i in 3:
		canvas.draw_line(at + Vector2(7, 10 + i * 5), at + Vector2(tile - 7, 10 + i * 5), Color("#ead5a5"), 2.0)
	canvas.draw_string(ThemeDB.fallback_font, at + Vector2(5, tile - 3), word,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#f6e5b9"))
