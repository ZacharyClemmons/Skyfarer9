class_name UIWindow extends PanelContainer
## Draggable window (SS13's tgui windows, less clunky). Content is rebuilt by a
## refresh callable at a fixed rate so machine readouts stay live, but the new content
## only replaces the old when something actually changed, so buttons don't vanish from
## under the mouse. Windows come to the front when clicked, stay on screen, and each
## kind of window reopens where it was last left.

static var remembered := {} # kind -> position

## Windows you use across a counter rather than by touching the thing. These stay open
## while you are in the room and are not subject to the reach rule.
const COUNTER_KINDS := ["shop", "notices", "skycraft"]
const COUNTER_RANGE := 6

var title_label: Label
var body: VBoxContainer
var scroll: ScrollContainer
var refresh_fn: Callable
var refresh_t := 0.0
var interval := 0.5
var dragging := false
var target: Entity
var kind := ""
var _sig := ""
var _fit_t := 0.0
var _shadow: Node2D
var _want := Vector2.ZERO # where the window wants to be; clamping never forgets it

func _init(title: String, w := 460) -> void:
	add_theme_stylebox_override("panel", UITheme.panel_style(0.94))
	custom_minimum_size = Vector2(w, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	# a title bar (drag it to move the window)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UITheme.frame("panel_title", 10, 3))
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(bar)
	var head := HBoxContainer.new()
	bar.add_child(head)
	title_label = UITheme.label(title, UITheme.TITLE, UITheme.ACCENT)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_PASS
	title_label.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	head.add_child(title_label)
	var close := UITheme.icon_button("close", "Close (Esc)", 30)
	close.pressed.connect(func() -> void: UIFx.ease_close(self))
	close.set_meta("fx_sound", "ui_tick")
	head.add_child(close)
	# the content scrolls once it's taller than the screen has room for
	scroll = ScrollContainer.new()
	scroll.clip_contents = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(scroll)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	# a soft drop shadow (a Node2D so the container leaves it alone); it lifts while dragging
	_shadow = Node2D.new()
	_shadow.show_behind_parent = true
	_shadow.draw.connect(_draw_shadow)
	add_child(_shadow)
	resized.connect(_shadow.queue_redraw)

func _ready() -> void:
	UIFx.ease_open(self)

func _draw_shadow() -> void:
	var lift := 1.0 if dragging else 0.0
	var off := Vector2(4, 6) + Vector2(3, 6) * lift
	for i in 3:
		var g := float(3 - i) * (2.0 + lift * 2.0)
		_shadow.draw_rect(Rect2(off - Vector2(g, g), size + Vector2(g, g) * 2.0), Color(0, 0, 0, 0.10 + lift * 0.05))

## First placement: where this kind of window was last left, else cascaded to the right
## of the screen's centre.
func place_initial(n: int) -> void:
	var vs := get_parent_area_size()
	if remembered.has(kind):
		_want = remembered[kind]
	else:
		# below the top bar and the level-up toasts, cascading so they don't stack exactly
		_want = Vector2(vs.x * 0.5 - 40 + (n % 6) * 28, maxf(150.0, vs.y * 0.16) + (n % 6) * 28)
	position = _want
	_refresh_now()
	_clamp.call_deferred()

func _clamp() -> void:
	var vs := get_parent_area_size()
	position = _want.clamp(Vector2.ZERO, (vs - size - Vector2(0, 10)).max(Vector2.ZERO))

## Size the scroll area to the content, capped to what fits on screen under the title bar.
func _fit_height() -> void:
	var vs := get_parent_area_size()
	if vs.y <= 0:
		return
	var want := body.get_combined_minimum_size().y
	var room := maxf(160.0, minf(vs.y - 90.0, vs.y * 0.75))
	if kind == "settings":
		room = maxf(160.0, minf(room, vs.y - 200.0))
	# Genetics has live readouts and wrapped genome rows. Reserve a stable viewport
	# so deferred container layout cannot make the window jump on each update.
	var h := room if kind in ["dna_console", "skill_station"] else minf(want, room)
	if kind == "dna_tutorial":
		h = minf(room, 550.0)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if kind in ["dna_console", "dna_tutorial"] or want > h else ScrollContainer.SCROLL_MODE_DISABLED
	if absf(scroll.custom_minimum_size.y - h) > 0.5:
		scroll.custom_minimum_size.y = h
		reset_size()
		_clamp()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			move_to_front()
		dragging = ev.pressed and ev.position.y < 34
		if not ev.pressed:
			_want = position
			remembered[kind] = position
		accept_event()
	elif ev is InputEventMouseMotion and dragging:
		_want = position + ev.relative
		_clamp()
		accept_event()

func _process(delta: float) -> void:
	if target != null and (not is_instance_valid(target) or target.removed):
		queue_free()
		return
	# A shop counter is a counter: the customer stands on one side of it and the
	# shopkeeper on the other, which means you are never *adjacent* to them and the
	# reach rule below would shut the window on the frame it opened. Trading stays open
	# while you are in the same room, and shuts when you walk out of it.
	if kind in COUNTER_KINDS:
		if target != null and Game.player != null and Game.player.dist_to(target) > COUNTER_RANGE:
			queue_free()
		return
	if target != null and Game.player and target.root() != Game.player and not GeneInteraction.can_open(Game.player, target) and not kind in ["talk", "chronicle", "help", "dna_tutorial"]:
		queue_free()
		return
	refresh_t -= delta
	# layout upkeep is measured, not free (combined minimum size walks the tree): 10 Hz is plenty
	_fit_t -= delta
	if _fit_t <= 0.0 or dragging:
		_fit_t = 0.1
		_fit_height()
		_clamp()
		# shrink back to the content (containers only ever grow on their own)
		if size.y > get_combined_minimum_size().y + 1.0:
			reset_size()
	# don't rebuild the window out from under someone typing into it or mid-click
	var focus := get_viewport().gui_get_focus_owner()
	if (focus is LineEdit or focus is TextEdit) and body.is_ancestor_of(focus):
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and get_global_rect().has_point(get_global_mouse_position()):
		return
	if refresh_t <= 0.0 and refresh_fn.is_valid():
		refresh_t = interval
		_refresh_now()

func _refresh_now() -> void:
	if not refresh_fn.is_valid():
		return
	var nb := VBoxContainer.new()
	refresh_fn.call(nb)
	var sig := _signature(nb)
	if sig == _sig:
		nb.free()
		return
	_sig = sig
	if kind in ["dna_console", "skill_station"] and _live_structure(body) == _live_structure(nb):
		_patch_live(body, nb)
		nb.free()
		return
	var scroll_y := scroll.scroll_vertical
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	for c in nb.get_children():
		nb.remove_child(c)
		body.add_child(c)
	body.set_meta("ui_identity", nb.get_meta("ui_identity", ""))
	nb.free()
	_fit_height()
	reset_size()
	_clamp.call_deferred()
	scroll.set_deferred("scroll_vertical", scroll_y)

## Update genetics readouts without replacing hovered controls or their callbacks.
## Action controls and mutation identities must match; a new subject/selection or
## changed action rebuilds normally. Gene callbacks remain valid for the same alias/base.
static func _live_structure(n: Node) -> String:
	var parts := [n.get_class(), str(n.get_child_count())]
	if n is Control:
		parts.append(str(n.get_meta("ui_identity", "")))
		parts.append(str(n.visible))
	if n is Button and (n.get_meta("ui_live_gene", false) or n.get_meta("ui_live_caption", false)):
		parts.append(str(n.disabled))
	elif n is BaseButton or n is LineEdit or n is RichTextLabel or n is InvSlot:
		return _signature(n)
	elif not n is Label and not n is TGUI.Bar and "text" in n:
		parts.append(str(n.text))
	for child in n.get_children():
		parts.append(_live_structure(child))
	return "|".join(parts)

static func _patch_live(current: Node, fresh: Node) -> void:
	if current is Label:
		current.text = fresh.text
		current.add_theme_color_override("font_color", fresh.get_theme_color("font_color"))
	elif current is TGUI.Bar:
		current.frac = fresh.frac
		current.col = fresh.col
		current.text = fresh.text
		current.queue_redraw()
	elif current is Button and current.get_meta("ui_live_gene", false):
		current.text = fresh.text
		current.tooltip_text = fresh.tooltip_text
		current.set_meta("ui_selected", fresh.get_meta("ui_selected", false))
		for style in ["normal", "hover", "pressed", "disabled"]:
			current.add_theme_stylebox_override(style, fresh.get_theme_stylebox(style))
	elif current is Button and current.get_meta("ui_live_caption", false):
		current.text = fresh.text
		current.tooltip_text = fresh.tooltip_text
	elif current is ColorRect:
		current.color = fresh.color
	for i in current.get_child_count():
		_patch_live(current.get_child(i), fresh.get_child(i))

static func _signature(n: Node) -> String:
	var parts := [n.get_class()]
	if "text" in n:
		parts.append(str(n.text))
	if n is BaseButton:
		parts.append(str(n.disabled))
		parts.append(str(n.get_meta("ui_selected", n.button_pressed)))
	if n is Control:
		parts.append(str(n.get_meta("ui_identity", "")))
		parts.append(str(n.visible))
		parts.append(n.tooltip_text)
		parts.append(str(n.modulate))
	if n is Label:
		parts.append(str(n.get_theme_color("font_color")))
	if n is TGUI.Bar:
		parts.append(str(snappedf(n.frac, 0.001)))
		parts.append(str(n.col))
	if n is TGUI.GasBar:
		parts.append(str(n.parts))
	if n is ColorRect:
		parts.append(str(n.color))
	if n is InvSlot:
		parts.append(str(n.item.get_instance_id()) if n.item else "-")
		if is_instance_valid(n.item) and n.item.has_c(&"stack"):
			parts.append(str(n.item.c(&"stack").amount))
	for c in n.get_children():
		parts.append(_signature(c))
	return "|".join(parts)

func clear_body() -> void:
	for c in body.get_children():
		c.queue_free()
	_sig = ""
