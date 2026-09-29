class_name ViewMode extends Node
## Owns the 2D ⇄ first-person toggle.
##
## Both views are always looking at the same world; this only decides which one is drawing
## and where input goes. Switching is instant and changes nothing about the simulation, so
## you can fight in one view, flip to the other to read a gauge, and flip back.
##
## In first person the mouse looks, WASD walks relative to where you are facing, and the
## crosshair stands in for the mouse cursor: the tile ahead of you is what you interact
## with. Everything past that point is the game's ordinary interaction code.

const KEY_TOGGLE := KEY_F5

var view3d: View3D
var sub: SubViewport
var screen: TextureRect
var layer: CanvasLayer
var crosshair: Control
var active := false
var captured := false

func setup(map: StationMap) -> void:
	layer = CanvasLayer.new()
	layer.layer = -1 # under the HUD, over nothing
	layer.visible = false
	add_child(layer)

	sub = SubViewport.new()
	sub.size = Vector2i(1280, 800)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.transparent_bg = false
	sub.msaa_3d = Viewport.MSAA_DISABLED
	sub.positional_shadow_atlas_size = 0
	add_child(sub)

	view3d = View3D.new()
	view3d.setup(map)
	sub.add_child(view3d)

	screen = TextureRect.new()
	screen.texture = sub.get_texture()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)

	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(_draw_crosshair)
	layer.add_child(crosshair)

	get_viewport().size_changed.connect(_resize)
	_resize()
	Bus.tile_changed.connect(_on_tile)

func _resize() -> void:
	var s := get_viewport().get_visible_rect().size
	if sub != null and s.x > 16 and s.y > 16:
		# render at half resolution: the art is 32px pixel art, so this reads as intended
		# rather than as a blurry compromise, and it costs a quarter of the fill rate
		sub.size = Vector2i(maxi(320, int(s.x / 2)), maxi(200, int(s.y / 2)))
	if crosshair != null:
		crosshair.queue_redraw()

func _on_tile(c: Vector2i) -> void:
	if view3d != null:
		view3d.mark_dirty([c])

## The airship rewrites a lot of terrain at once; take the bulk notification too.
func mark_cells(cells: Array) -> void:
	if view3d != null:
		view3d.mark_dirty(cells)

# ------------------------------------------------------------------ switching
func toggle() -> void:
	set_active(not active)

func set_active(v: bool) -> void:
	if v == active:
		return
	active = v
	layer.visible = v
	if Game.view != null:
		Game.view.visible = not v
	if v:
		view3d.rebuild_all()
		var p := Game.player
		if p != null and p.has_c(&"mob"):
			# start looking the way the character already faces
			view3d.yaw = [0.0, -PI * 0.5, PI, PI * 0.5][p.c(&"mob").dir]
		_capture(true)
		Game.msg("[color=#9ad8ff]First-person view.[/color] Mouse looks, [b]F5[/b] returns to the overhead view, [b]Escape[/b] frees the cursor.", "info")
	else:
		_capture(false)
		Game.msg("[color=#9ad8ff]Overhead view.[/color]", "info")

func _capture(v: bool) -> void:
	captured = v
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if v else Input.MOUSE_MODE_VISIBLE

# ------------------------------------------------------------------ input
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_TOGGLE:
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	if Game.paused or not Game.running or (Game.hud != null and Game.hud.chat_active()):
		if captured:
			_capture(false)
		return
	if ev is InputEventMouseMotion and captured:
		view3d.look(ev.relative)
		return
	if ev is InputEventKey and ev.pressed and ev.physical_keycode == KEY_ESCAPE:
		_capture(not captured)
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseButton and ev.pressed:
		if not captured:
			_capture(true)
			get_viewport().set_input_as_handled()
			return
		if ev.button_index == MOUSE_BUTTON_LEFT:
			_use(false)
			get_viewport().set_input_as_handled()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			_use(true)
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active or not Game.running or Game.paused:
		return
	var p := Game.player
	if p == null or not is_instance_valid(p):
		return
	var hud: HUD = Game.hud
	if hud != null and hud.chat_active():
		return
	if Helm.of(p) != null:
		return
	var input := Vector2.ZERO
	if Input.is_action_pressed("move_up"): input.y -= 1
	if Input.is_action_pressed("move_down"): input.y += 1
	if Input.is_action_pressed("move_left"): input.x -= 1
	if Input.is_action_pressed("move_right"): input.x += 1
	if input == Vector2.ZERO:
		return
	var m: CMob = p.c(&"mob")
	if m == null or m.moving:
		return
	var h: CHealth = p.c(&"health")
	if h != null and h.sleeping and not h.dead:
		h.wake()
		Game.tell(p, "You wake up.")
	if DoAfter.busy(p):
		DoAfter.cancel(p)
	var d := view3d.move_vector(input)
	if d == Vector2i.ZERO:
		return
	m.allow_void = Input.is_key_pressed(KEY_SHIFT)
	# keep facing where the camera looks, not where the feet went
	var want := view3d.facing_dir()
	if not m.try_step(d) and d.x != 0 and d.y != 0:
		if not m.try_step(Vector2i(d.x, 0)):
			m.try_step(Vector2i(0, d.y))
	m.face(want)
	crosshair.queue_redraw()

## Left click uses what is ahead; right click examines it. Both hand straight over to the
## same Interact calls the overhead view makes.
func _use(examine: bool) -> void:
	var p := Game.player
	if p == null or Game.paused or not Game.running:
		return
	var c := view3d.aimed_cell()
	var targets := PlayerController.entities_at(c)
	var target: Entity = targets[0] if not targets.is_empty() else null
	if examine:
		Interact.click(p, target, c, {"shift": true})
		return
	Interact.click(p, target, c)

func _draw_crosshair() -> void:
	if not active:
		return
	var r := crosshair.get_rect()
	var mid := r.size * 0.5
	var col := Color(0.85, 0.95, 1.0, 0.55)
	for v in [Vector2(6, 0), Vector2(-6, 0), Vector2(0, 6), Vector2(0, -6)]:
		crosshair.draw_line(mid + v * 0.45, mid + v, col, 1.0)
	# what the crosshair is on, named under it
	var c := view3d.aimed_cell() if view3d != null else Vector2i.ZERO
	var label := ""
	var targets := PlayerController.entities_at(c)
	if not targets.is_empty():
		label = targets[0].display_name
	elif Game.map != null and Game.map.inb(c):
		label = String(Defs.TURFS[Game.map.get_turf(c)]["name"])
	if label != "":
		var f := ThemeDB.fallback_font
		crosshair.draw_string(f, mid + Vector2(-100, 26), label, HORIZONTAL_ALIGNMENT_CENTER, 200, 14,
			Color(0.9, 0.95, 1.0, 0.8))
