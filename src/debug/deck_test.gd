class_name DeckTest extends Node
## --decktest: enter a genuinely separate lower-deck tile layer and return.

var checks := 0
var fails := 0
var shot_dir := ""

func _ready() -> void:
	_run.call_deferred()

func _check(what: String, ok: bool) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("DECK %s %s" % ["PASS" if ok else "FAIL", what])

func _run() -> void:
	var p := Game.player
	var sh: Airship = Game.fleet.player_ship
	_check("player and ship exist", p != null and sh != null)
	if p == null or sh == null:
		get_tree().quit(1)
		return
	_check("lower deck has separate map cells", not sh.lower_cells.is_empty() and
		sh.lower_stair.y >= SkyGen.H and not sh.cells.has(sh.lower_stair))
	_check("galley area belongs to ship", sh.areas.has(Game.map.area[Game.map.idx(sh.lower_stair)]))
	_check("furniture is present below", sh.lower_parts.size() >= 3)
	var top: Vector2i = sh.cell(sh.upper_stair_local.x, sh.upper_stair_local.y)
	_check("upper stairs are walkable", Game.map.is_passable(top) and Falling.supported(top))
	p.place(top)
	_check("stairs are shown on the weather deck", Underdecks.stair_at(p.cell))
	_check("descend succeeds", Underdecks.use(p))
	_check("player is on the lower deck", p.cell == sh.lower_stair and Game.fleet.ship_of(p) == sh)
	await _shot("lower")
	_check("lower deck supports walking", Falling.supported(p.cell + Vector2i(1, 0)) and
		Game.map.is_passable(p.cell + Vector2i(1, 0)))
	_check("ascend succeeds", Underdecks.use(p))
	_check("player returns to same hull tile", p.cell == top and Game.fleet.ship_of(p) == sh)
	await _shot("upper")
	for c in sh.deck_cells:
		if absi(c.x - top.x) + absi(c.y - top.y) > 1 and Game.map.is_passable(c) and Game.map.dense_count[Game.map.idx(c)] == 0:
			p.place(c)
			break
	_check("ordinary deck tile is not a stair", not Underdecks.use(p))
	var builder := Shipyard.new()
	builder.cells = sh.cells_map.duplicate(true)
	builder._seed_lower()
	_check("yard sketches a lower room with stairs", not builder.lower_plan.is_empty() and builder.lower_plan.has(builder.lower_entry_local))
	if builder.lower_plan.has(builder.lower_entry_local):
		Underdecks.clear(sh)
		sh.lower_plan = builder.lower_plan.duplicate(true)
		sh.lower_entry_local = builder.lower_entry_local
		Underdecks.ensure(sh)
		var custom_top := sh.cell(sh.lower_entry_local.x, sh.lower_entry_local.y)
		_check("yard stair aligns with weather deck", sh.lower_stair.y >= SkyGen.H and sh.upper_stair_local == sh.lower_entry_local and Game.map.is_passable(custom_top))
		p.place(custom_top)
		_check("yard stairs descend", Underdecks.use(p) and p.cell == sh.lower_stair)
		_check("yard stairs ascend", Underdecks.use(p) and p.cell == custom_top)
	builder.queue_free()
	print("DECK DONE: %d checks, %d failed" % [checks, fails])
	get_tree().quit(0 if fails == 0 else 1)

func _shot(name: String) -> void:
	if shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s/deck_%s.png" % [shot_dir, name])
