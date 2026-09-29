class_name Entity extends Node2D
## Everything that exists in the world beyond the tile grid: mobs, items, machines,
## doors, decals. An entity is a bag of components (see Component) plus a sprite.
## Position convention: the node sits at the bottom-centre of its tile so y-sorting
## by feet works; sprites are bottom-anchored.

var id := 0
var proto := ""
var display_name := "thing"
var desc := ""
var cell := Vector2i.ZERO
var comps := {}
var holder: Entity = null # the mob or container holding this entity
var removed := false
## The cell_index slot this entity is filed under (Game keeps it exact, so a stale `cell`
## can never leave a dangling reference behind). NO_CELL when off the map index.
var indexed_at := Vector2i(-99999, -99999)
var spr: Sprite2D
var spr_sheet := "" # which sprite set_sprite last showed (for in-hand variants)
var spr_name := ""
var glow_spr: Sprite2D
var wall_mounted := false
var tags := {}

func _init() -> void:
	y_sort_enabled = false

func c(k: StringName):
	return comps.get(k)

func has_c(k: StringName) -> bool:
	return comps.has(k)

func add(comp: Component) -> Component:
	comps[comp.key()] = comp
	comp.e = self
	Game.index_comp(self, comp.key())
	comp.on_added()
	return comp

func remove_comp(k: StringName) -> void:
	var comp = comps.get(k)
	if comp:
		comp.on_removed()
		comps.erase(k)
		Game.unindex_comp(self, k)

# ------------------------------------------------------------------ placement
static func cell_to_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * Defs.TILE + Defs.TILE * 0.5, c.y * Defs.TILE + Defs.TILE)

func on_map() -> bool:
	return holder == null and not removed

func place(new_cell: Vector2i, snap := true) -> void:
	var old := cell
	if holder == null:
		Game.cell_index_move(self, old, new_cell)
	cell = new_cell
	if snap:
		position = cell_to_pos(new_cell)
	for comp in comps.values():
		comp.on_moved(old, new_cell)
	if holder == null:
		Bus.entity_moved.emit(self, old, new_cell)

func center() -> Vector2:
	return Vector2(cell.x * Defs.TILE + 16, cell.y * Defs.TILE + 16)

## World cell of this entity even when held (uses the outermost holder).
func root_cell() -> Vector2i:
	var r: Entity = self
	var guard := 0
	while r.holder != null and guard < 8:
		r = r.holder
		guard += 1
	return r.cell

func root() -> Entity:
	var r: Entity = self
	var guard := 0
	while r.holder != null and guard < 8:
		r = r.holder
		guard += 1
	return r

func dist_to(other: Entity) -> int:
	var a := root_cell()
	var b := other.root_cell()
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func adjacent(other: Entity) -> bool:
	return Entity.cells_adjacent(root_cell(), other.root_cell())

## tg turf/Adjacent: same or neighbouring tile; diagonally only if you could reach round
## at least one of the two corners (they aren't both wall).
static func cells_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	if absi(d.x) > 1 or absi(d.y) > 1:
		return false
	if d.x != 0 and d.y != 0 and Game.map != null:
		if Game.map.is_solid_turf(a + Vector2i(d.x, 0)) and Game.map.is_solid_turf(a + Vector2i(0, d.y)):
			return false
	return true

# ------------------------------------------------------------------ visuals
func set_sprite(sheet: String, name: String) -> void:
	if spr == null:
		spr = Sprite2D.new()
		spr.centered = true
		add_child(spr)
	if name == "":
		return
	if not Gfx.has(sheet, name):
		push_warning("sprite missing %s/%s" % [sheet, name])
		return
	spr_sheet = sheet
	spr_name = name
	var r := Gfx.region(sheet, name)
	spr.texture = Gfx.tex(sheet)
	spr.region_enabled = true
	spr.region_rect = r
	spr.offset = Vector2(16.0 if int(r.size.x) == 64 else 0.0, -r.size.y * 0.5 + (-24 if wall_mounted else 0))
	var gname := name + "_glow"
	if Gfx.has(sheet, gname):
		set_glow(sheet, gname)
	elif glow_spr:
		glow_spr.visible = false

func set_glow(sheet: String, name: String, energy := 1.45) -> void:
	if glow_spr == null:
		glow_spr = Sprite2D.new()
		glow_spr.centered = true
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow_spr.material = mat
		add_child(glow_spr)
	var r := Gfx.region(sheet, name)
	glow_spr.texture = Gfx.tex(sheet)
	glow_spr.region_enabled = true
	glow_spr.region_rect = r
	glow_spr.offset = Vector2(16.0 if int(r.size.x) == 64 else 0.0, -r.size.y * 0.5 + (-24 if wall_mounted else 0))
	glow_spr.modulate = Color(energy, energy, energy, 1.0)
	glow_spr.visible = true
	_start_glow_idle(name, energy)

## Idle life for lit things: lamps and fires waver, the boiler breathes. A looping tween
## per glow (started once), with a random phase so a row of lamps does not pulse in step.
func _start_glow_idle(gname: String, energy: float) -> void:
	var amp := 0.0
	var per := 1.0
	for k in ["lantern", "lamp", "candle", "torch", "fire", "hearth", "ember", "forge", "brazier"]:
		if gname.contains(k):
			amp = 0.13
			per = 0.28
	if gname.contains("boiler") or gname.contains("burner"):
		amp = 0.10
		per = 0.6
	if amp <= 0.0 or glow_spr == null or glow_spr.has_meta("idle_tw"):
		return
	glow_spr.set_meta("idle_tw", true)
	var start := func() -> void:
		if glow_spr == null or not is_instance_valid(glow_spr):
			return
		var tw := glow_spr.create_tween().set_loops()
		tw.tween_interval(randf() * per)
		tw.tween_property(glow_spr, "modulate", Color(energy * (1.0 - amp), energy * (1.0 - amp), energy * (1.0 - amp * 1.3), 1.0), per * (0.7 + randf() * 0.6))
		tw.tween_property(glow_spr, "modulate", Color(energy * (1.0 + amp * 0.5), energy * (1.0 + amp * 0.4), energy, 1.0), per * (0.7 + randf() * 0.6))
	if glow_spr.is_inside_tree():
		start.call()
	else:
		glow_spr.tree_entered.connect(start, CONNECT_ONE_SHOT)

## tg pixel_x / pixel_y: nudge how an item sits on its tile (things set down on tables).
var pixel_offset := Vector2.ZERO

func set_pixel_offset(v: Vector2) -> void:
	pixel_offset = v
	if spr:
		spr.position = v
	if glow_spr:
		glow_spr.position = v

func set_glow_visible(v: bool) -> void:
	if glow_spr:
		glow_spr.visible = v

# ------------------------------------------------------------------ interaction plumbing
func examine_text(user: Entity) -> String:
	if tags.has("text") and str(tags["text"]).strip_edges() != "":
		return _examine_text(user) + "\n[color=#e8e0c8]It reads:[/color]\n[i]%s[/i]" % str(tags["text"]).replace("[", "(")
	return _examine_text(user)

func _examine_text(user: Entity) -> String:
	var lines := ["This is [b]%s[/b]." % display_name]
	if desc != "":
		lines.append(desc)
	for comp in comps.values():
		comp.examine(user, lines)
	return "\n".join(lines)

func get_verbs(user: Entity) -> Array:
	var out := []
	for comp in comps.values():
		comp.verbs(user, out)
	out.sort_custom(func(a, b): return a.get("priority", 0) > b.get("priority", 0))
	return out

func attack_hand(user: Entity) -> bool:
	for comp in comps.values():
		if comp.attack_hand(user):
			return true
	return false

func attackby(user: Entity, item: Entity) -> bool:
	for comp in comps.values():
		if comp.attackby(user, item):
			return true
	return false

func attack_self(user: Entity) -> bool:
	for comp in comps.values():
		if comp.attack_self(user):
			return true
	return false

## Damage this thing. `flag` is tg's damage flag ("melee", "bullet", "laser", "bomb", "fire",
## or "" for unarmoured): objects with integrity run it through their armour first.
## Returns what got through the armour.
func take_damage(amount: float, kind: String, source: Entity = null, flag := "", ap := 0.0) -> float:
	var prof = c(&"integrity") if has_c(&"integrity") else c(&"machine")
	if prof != null and not has_c(&"health"):
		amount = prof.reduce(amount, kind, flag, ap)
		if amount <= 0.0:
			return 0.0
	var dealt := amount
	var rem := amount
	for comp in comps.values():
		rem = comp.take_damage(rem, kind, source)
		if rem <= 0.0:
			return dealt
	return dealt

func ai_tags() -> Dictionary:
	var out := {}
	for comp in comps.values():
		comp.ai_tags(out)
	return out

func destroy() -> void:
	if removed:
		return
	var spill_cell := root_cell()
	if holder != null and is_instance_valid(holder):
		Interact.detach(self)
	removed = true
	var st = c(&"storage")
	if st:
		for it in st.contents.duplicate():
			if not is_instance_valid(it) or it.removed:
				continue # destroyed inside without being taken out
			it.holder = null
			it.visible = true
			Game.drop_to_map(it, spill_cell)
			it.place(spill_cell)
		st.contents.clear()
	for comp in comps.values():
		comp.on_removed()
	Game.unregister(self)
	Bus.entity_removed.emit(self)
	queue_free()

func the() -> String:
	return display_name if has_c(&"mob") else "the " + display_name
