class_name PlayerController extends Node
## Turns keyboard/mouse input into the same Interact calls NPCs use.

var hold_t := 0.0
var zoom_levels := [1.0, 1.5, 2.0, 2.5, 3.0, 4.0]
var zoom_i := 2

func _init() -> void:
	process_priority = -30 # input precedes movement and the fleet
## tg's numpad targeting
## (pressing the head key again cycles head -> eyes -> mouth, the arms -> hands, the
## legs -> feet, like tg)
const ZONE_KEYS := {KEY_KP_8: ["head", "eyes", "mouth"], KEY_KP_5: ["chest"], KEY_KP_2: ["groin"], KEY_KP_4: ["r_arm", "r_hand"],
	KEY_KP_6: ["l_arm", "l_hand"], KEY_KP_1: ["r_leg", "r_foot"], KEY_KP_3: ["l_leg", "l_foot"]}

static func entities_under_mouse() -> Array:
	if Game.view == null:
		return []
	# the HUD's mouse is the one every other hover effect uses (and the one synthetic input
	# drives); the viewport's own can lag a frame behind or disagree with it
	if Game.hud:
		return pick(Game.view.get_viewport().get_canvas_transform().affine_inverse() * Game.hud.mouse)
	return pick(Game.view.get_global_mouse_position())

## What's under a point in the world, the way BYOND clicks work in tg: whatever has a
## visible pixel there, topmost first (drawn later = on top), then the rest of that tile's
## contents. Floor decals (rugs, lines, blood) aren't clickable, like tg's mouse_opacity 0.
static func pick(wp: Vector2) -> Array:
	var c := Vector2i(floori(wp.x / Defs.TILE), floori(wp.y / Defs.TILE))
	if Game.fleet != null:
		c = Game.fleet.cell_at_visual(wp)
	var hits := []
	# Tall fittings can reach across several simulation cells while the deck turns.
	# Test their displayed pixels directly, including parts just beyond the rail.
	if Game.fleet != null:
		for sh in Game.fleet.ships:
			if not sh.present or not is_instance_valid(sh.renderer):
				continue
			for e in sh.renderer._carried_entities.values():
				if is_instance_valid(e) and e.on_map() and e.visible and not e.has_meta("inside") and _pixel_hit(e, wp):
					hits.append(e)
	for dy in range(0, 3): # tall and wall-mounted sprites reach up from the tiles below
		for dx in range(-1, 2):
			for e in Game.at(c + Vector2i(dx, dy)):
				if e.holder == null and e.visible and not e.removed and not e.has_meta("inside") and not e in hits and _pixel_hit(e, wp):
					hits.append(e)
	hits.sort_custom(func(a, b): return PlayerController._drawn_after(a, b))
	# a click on bare wall or window is the wall itself (tg: you tap it), so fixtures
	# mounted there only count where their pixels are
	var solid := Game.map != null and Game.map.inb(c) and (Game.map.is_wall(c) or Game.map.structure[Game.map.idx(c)] != Defs.S_NONE)
	for e in entities_at(c):
		if solid and e.wall_mounted:
			continue
		if not e in hits and (not e.has_c(&"decal") or hits.is_empty()):
			hits.append(e)
	return hits

static func _pixel_hit(e: Entity, wp: Vector2) -> bool:
	if e.has_c(&"decal"):
		return false
	var local := e.to_local(wp)
	var m: CMob = e.c(&"mob")
	if m != null and m.doll != null:
		local -= m.doll.position
		var health: CHealth = e.c(&"health")
		var live_creature := (e.tags.has("beast") or m.doll.animal_kind != "") and (health == null or not health.dead)
		if m.is_lying() and not live_creature:
			return Rect2(-15, -12, 30, 12).has_point(local)
		return Rect2(-10, -31, 20, 31).has_point(local)
	var s := e.spr
	if s == null or s.texture == null or not s.visible or e.spr_sheet == "":
		return false
	local = s.to_local(wp)
	var r := s.region_rect
	var p := local - (s.offset - r.size * 0.5)
	if s.flip_h:
		p.x = r.size.x - 1.0 - p.x
	return Gfx.opaque_at(e.spr_sheet, r, p)

## Does a draw on top of b? (z index, then y-sort, then order in the scene)
static func _drawn_after(a: Entity, b: Entity) -> bool:
	if a.z_index != b.z_index:
		return a.z_index > b.z_index
	if not is_equal_approx(a.position.y, b.position.y):
		return a.position.y > b.position.y
	return a.get_index() > b.get_index()

## What's under the mouse when it points at cell c, most interesting first.
static func entities_at(c: Vector2i) -> Array:
	var out := []
	for e in Game.at(c):
		if e.holder == null and e.visible and not e.removed and not e.has_meta("inside"):
			out.append(e)
	# wall-mounted fixtures sit on the floor tile below but are drawn on the wall
	if Game.map and Game.map.inb(c) and Game.map.is_wall(c):
		for e in Game.at(c + Vector2i(0, 1)):
			if e.wall_mounted:
				out.append(e)
	# multi-tile machines
	for d in [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(-1, 1)]:
		for e in Game.at(c + d):
			var b = e.c(&"blocker")
			if b and b.footprint.size() > 1 and c in b.cells() and not e in out:
				out.append(e)
	out.sort_custom(func(a, b): return PlayerController._prio(a) > PlayerController._prio(b))
	return out

static func _prio(e: Entity) -> int:
	if e == Game.player:
		return -5
	if e.has_c(&"mob"):
		return 50 if not e.c(&"mob").is_lying() else 45
	if e.has_c(&"item"):
		return 40
	if e.wall_mounted:
		return 35
	if e.has_c(&"door"):
		return 20
	if e.has_c(&"decal"):
		return 5
	return 30 - e.z_index

func _process(delta: float) -> void:
	var p := Game.player
	if p == null or not is_instance_valid(p) or not Game.running or Game.paused:
		return
	var hud: HUD = Game.hud
	if hud and hud.chat_active():
		var helm := Helm.of(p)
		if helm != null:
			helm.steer(0.0)
		return
	# With the wheel in your hands the movement keys fly the ship instead of walking you
	# around. Let go of the wheel and they are your feet again.
	var at_helm := Helm.of(p)
	if at_helm != null:
		_pilot(at_helm, minf(delta * Game.time_scale, 0.1))
		return
	if _first_person():
		return
	var d := Vector2i.ZERO
	if Input.is_action_pressed("move_up"): d.y -= 1
	if Input.is_action_pressed("move_down"): d.y += 1
	if Input.is_action_pressed("move_left"): d.x -= 1
	if Input.is_action_pressed("move_right"): d.x += 1
	if d != Vector2i.ZERO:
		var h: CHealth = p.c(&"health")
		if h.sleeping and not h.dead:
			h.wake()
			Game.tell(p, "You wake up.")
		if DoAfter.busy(p):
			DoAfter.cancel(p)
		var m: CMob = p.c(&"mob")
		# holding shift means you meant it: step off the rail, onto a rope, into the sky
		m.allow_void = Input.is_key_pressed(KEY_SHIFT)
		if not m.moving:
			if not m.try_step(d) and d.x != 0 and d.y != 0:
				# slide along walls when moving diagonally
				if not m.try_step(Vector2i(d.x, 0)):
					m.try_step(Vector2i(0, d.y))

## Flying. Throttle and trim ramp while held, because you set them and leave them; the
## rudder turns while held; releasing it eases the ship onto a steady heading.
const THROTTLE_RATE := 0.55
const TRIM_RATE := 0.5
func _pilot(helm: CHelm, delta: float) -> void:
	var sh := helm.ship()
	if sh == null:
		return
	if Input.is_action_pressed("move_up"):
		sh.throttle = clampf(sh.throttle + THROTTLE_RATE * delta, 0.0, 1.0)
	if Input.is_action_pressed("move_down"):
		sh.throttle = clampf(sh.throttle - THROTTLE_RATE * delta, 0.0, 1.0)
	# the rudder is held over, not tapped: the bow sweeps while you hold it
	var rud := 0.0
	if Input.is_action_pressed("move_left"):
		rud -= 1.0
	if Input.is_action_pressed("move_right"):
		rud += 1.0
	helm.steer(rud)
	if Input.is_key_pressed(KEY_Q):
		sh.ballast = clampf(sh.ballast + TRIM_RATE * delta, -1.0, 1.0)
	if Input.is_key_pressed(KEY_E):
		sh.ballast = clampf(sh.ballast - TRIM_RATE * delta, -1.0, 1.0)

func _pilot_key(helm: CHelm, key: int) -> bool:
	match key:
		KEY_X:
			helm.steady()
			return true
		KEY_SPACE:
			helm.all_stop()
			return true
		KEY_R:
			var sh := helm.ship()
			helm.sails(-1.0 if sh != null and sh.sails_set > 0.0 else 1.0)
			return true
	return false

func _unhandled_input(ev: InputEvent) -> void:
	var p := Game.player
	var hud: HUD = Game.hud
	# First-person owns its cursor and camera-relative movement.
	if not Game.paused and _first_person() and (ev is InputEventMouse or (ev is InputEventKey and ev.physical_keycode == KEY_ESCAPE)):
		return
	if Game.paused:
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.is_action("pause_menu"):
			if hud == null or not hud.close_front_window():
				Game.world.get_parent().toggle_pause()
			get_viewport().set_input_as_handled()
		return
	# piloting takes the movement-adjacent keys before anything else claims them
	if p != null and not Game.paused and ev is InputEventKey and ev.pressed and not ev.echo and (hud == null or not hud.chat_active()):
		if ev.physical_keycode == KEY_G:
			var mg := get_tree().current_scene
			if mg != null and mg.get("ship_panel") != null:
				mg.ship_panel.toggle()
			get_viewport().set_input_as_handled()
			return
		if ev.physical_keycode == KEY_F7:
			var mn := get_tree().current_scene
			if mn != null and mn.get("tutorial") != null:
				mn.tutorial.toggle()
			get_viewport().set_input_as_handled()
			return
		# J opens the bench: everything you could make, and for everything you cannot,
		# exactly what is stopping you
		if ev.physical_keycode == KEY_J and hud != null:
			hud.open_window("skycraft", null)
			get_viewport().set_input_as_handled()
			return
		# I opens the drawing board on the ship you are standing on, so a refit is never
		# further away than the deck you are already on
		if ev.physical_keycode == KEY_I:
			var sh: Airship = Game.fleet.ship_of(p) if Game.fleet != null else null
			if sh != null:
				Shipyard.open_refit(p, sh)
			else:
				Game.tell(p, "You would have to be aboard a ship to redraw one.", "warn")
			get_viewport().set_input_as_handled()
			return
		var helm := Helm.of(p)
		if helm != null and _pilot_key(helm, ev.physical_keycode):
			get_viewport().set_input_as_handled()
			return
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1)
			return
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(-1)
			return
	if p == null or not is_instance_valid(p) or not Game.running:
		return
	if ev is InputEventMouseButton and ev.pressed:
		var cell: Vector2i = Game.view.cell_at_screen(ev.position)
		var wpos: Vector2 = Game.view.get_viewport().get_canvas_transform().affine_inverse() * ev.position
		var ents := pick(wpos)
		if ev.button_index == MOUSE_BUTTON_LEFT:
			var target: Entity = null
			# the topmost thing actually under the cursor, which can be yourself (tg);
			# otherwise the most interesting thing on the tile, but not you
			if not ents.is_empty() and _pixel_hit(ents[0], wpos):
				target = ents[0]
			else:
				for e in ents:
					if e != p:
						target = e
						break
			if target == null and cell == p.cell and ev.shift_pressed:
				target = p
			if not Game.lighting.player_can_see(cell) and not ev.shift_pressed:
				return
			if not GenePowers.armed(p).is_empty() and GenePowers.click(p, target, cell):
				get_viewport().set_input_as_handled()
				return
			var mods := {"shift": ev.shift_pressed, "ctrl": ev.ctrl_pressed, "alt": ev.alt_pressed, "throw": hud.throw_mode, "wpos": wpos}
			var do_click := func():
				Interact.click(p, target, cell, mods)
				if hud.throw_mode and p.c(&"inv").active_item() == null:
					hud.throw_mode = false
				hud.refresh_inventory()
			# an item on the floor can be dragged into a hand, a slot or a bag, so its
			# click waits for the release
			var draggable: bool = target != null and target.holder == null and (target.has_c(&"item") or (target.has_c(&"mob") and (target == p or p.c(&"mob").pulling == target)))
			if draggable and not ev.shift_pressed and not ev.ctrl_pressed and not ev.alt_pressed and not hud.throw_mode:
				hud.drag_press(target, hud.mouse, do_click)
			else:
				do_click.call()
			get_viewport().set_input_as_handled()
		elif ev.button_index == MOUSE_BUTTON_MIDDLE:
			hud._action("swap") # tg MiddleClickOn: swap hands
			get_viewport().set_input_as_handled()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			var held: Entity = p.c(&"inv").active_item()
			if held and not ev.shift_pressed and not ents.is_empty() and ents[0].has_c(&"storage") and ents[0].c(&"storage").wrench_secondary(p, held):
				get_viewport().set_input_as_handled()
				return
			# tg: off help intent, right-clicking a person shoves them
			var pm: CMob = p.c(&"mob")
			if pm.combat and not ev.shift_pressed:
				for e in ents:
					if e != p and e.has_c(&"mob") and e.adjacent(p) and p.c(&"health").can_use_hands():
						Combat.shove(p, e)
						get_viewport().set_input_as_handled()
						return
			if Game.lighting.player_can_see(cell):
				hud.show_context_for(ents, false, cell)
			get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if hud.chat_active():
			if ev.physical_keycode == KEY_ESCAPE:
				hud.chat_input.visible = false
				var focus := get_viewport().gui_get_focus_owner()
				if focus:
					focus.release_focus()
			return
		if ev.physical_keycode == KEY_E and Underdecks.use(p):
			get_viewport().set_input_as_handled()
			return
		if ev.is_action("talk"):
			hud.open_chat()
		elif ev.is_action("radio_talk"):
			hud.open_chat(";")
		elif ev.is_action("drop"):
			hud._action("drop")
		elif ev.is_action("swap_hands"):
			hud._action("swap")
		elif ev.is_action("use_self"):
			hud._action("use")
		elif ev.is_action("equip"):
			hud._action("equip")
		elif ev.is_action("combat"):
			hud._action("combat")
		elif ev.is_action("throw"):
			hud._action("throw")
		elif ev.is_action("walk_toggle"):
			hud._action("run")
		elif ev.is_action("rest"):
			# tg rest (U): lie down / get back up
			var rh: CHealth = p.c(&"health")
			var rm: CMob = p.c(&"mob")
			if rm.buckled != null:
				Buckle.unbuckle(p, p)
			else:
				rh.set_resting(not rh.resting, false) # tg toggle_resting
		elif ev.is_action("resist"):
			hud._action("resist")
		elif ev.is_action("pull_stop"):
			hud._action("pull")
		elif ev.is_action("inventory"):
			hud.toggle_inventory()
		elif ev.is_action("chronicle"):
			hud.open_window("chronicle", null)
		elif ev.is_action("knowledge"):
			hud.open_window("crew", null)
		elif ev.is_action("help"):
			hud.open_window("help", null)
		elif ZONE_KEYS.has(ev.physical_keycode):
			var cyc: Array = ZONE_KEYS[ev.physical_keycode]
			var cur: String = p.c(&"mob").aimed_zone()
			var ni: int = (cyc.find(cur) + 1) % cyc.size() if cur in cyc else 0
			hud.set_zone(cyc[ni])
		elif ev.is_action("intent_help") or ev.is_action("intent_disarm") or ev.is_action("intent_grab") or ev.is_action("intent_harm"):
			for it in ["help", "disarm", "grab", "harm"]:
				if ev.is_action("intent_" + it):
					hud.set_intent(it)
		elif ev.is_action("hotbar_0") or ev.is_action("hotbar_1") or ev.is_action("hotbar_2") or ev.is_action("hotbar_3") or ev.is_action("hotbar_4") or ev.is_action("hotbar_5"):
			for hi in 6:
				if ev.is_action("hotbar_%d" % hi):
					hud.use_hotbar(hi)
		elif ev.is_action("aim_preset"):
			hud.set_aim_preset((p.c(&"mob").aim_preset + 1) % 3)
		elif ev.is_action("station_map"):
			hud.open_window("station_map", null)
		elif ev.is_action("crafting"):
			hud.open_window("crafting", null)
		elif ev.is_action("objectives"):
			hud.open_window("objectives", null)
		elif ev.is_action("skills"):
			hud.open_window("skills", null)
		elif ev.is_action("hud_layout"):
			hud.toggle_layout_mode()
		elif ev.is_action("debug_atmos"):
			hud.debug_atmos = not hud.debug_atmos
		elif ev.is_action("debug_ai"):
			hud.debug_ai = not hud.debug_ai
		elif ev.is_action("debug_menu"):
			hud.open_window("debug", null)
		elif ev.is_action("zoom_in"):
			_zoom(1)
		elif ev.is_action("zoom_out"):
			_zoom(-1)
		elif ev.is_action("time_fast"):
			Game.time_scale = 4.0 if Game.time_scale == 1.0 else 1.0
			Game.msg("Time scale x%d" % int(Game.time_scale), "warn")
		elif ev.is_action("pause_menu"):
			if not hud.close_front_window():
				Game.world.get_parent().toggle_pause()

func _zoom(dir: int) -> void:
	zoom_i = clampi(zoom_i + dir, 0, zoom_levels.size() - 1)
	if Game.view:
		Game.view.zoom_level = zoom_levels[zoom_i]

func _first_person() -> bool:
	var scene := get_tree().current_scene
	var mode := scene.get_node_or_null("ViewMode") if scene != null else null
	return mode is ViewMode and mode.active
