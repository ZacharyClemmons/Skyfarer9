class_name TargetDoll extends Control
## Burgerstation's targeting doll, with tg's precise parts: left click a *point* on the
## body to aim there; both hands attack where you aim. Three aim presets (the tabs below,
## or H to cycle) let you flip between, say, "eyes" and "legs" without re-clicking. Each
## part is tinted by how hurt yours is (green -> yellow -> red); hover one for its name,
## its state and what armour covers it, or right click to print that to the chat.

signal aim_changed

const DOLL := Vector2(32, 48) # the doll art in ui.png, at 1x
const TAB_H := 22.0
const AIM_COL := Color("#ffb84a")

var mob: CMob
var health: CHealth
var inv: CInventory
var hot := ""
var hot_tab := -1
var _pulse := 0.0
var _acc := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(112, 176)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 2.2, TAU)
	# a slow shimmer on the aimed zone: 20 Hz is indistinguishable from every frame
	_acc += delta
	if _acc >= 0.05 and is_visible_in_tree():
		_acc = 0.0
		queue_redraw()

## Where the doll is drawn and at what scale.
func _doll_rect() -> Rect2:
	var area := Vector2(size.x - 8.0, size.y - TAB_H - 10.0)
	var s := floorf(minf(area.x / DOLL.x, area.y / DOLL.y) * 2.0) / 2.0
	var sz := DOLL * s
	return Rect2(Vector2((size.x - sz.x) * 0.5, 4.0 + (area.y - sz.y) * 0.5), sz)

func _to_doll(p: Vector2) -> Vector2:
	var r := _doll_rect()
	return (p - r.position) / (r.size.x / DOLL.x)

func _from_doll(d: Vector2) -> Vector2:
	var r := _doll_rect()
	return r.position + (d + Vector2(0.5, 0.5)) * (r.size.x / DOLL.x)

func _tab_rect(i: int) -> Rect2:
	var w := (size.x - 8.0 - 8.0) / 3.0
	return Rect2(4.0 + i * (w + 4.0), size.y - TAB_H - 2.0, w, TAB_H)

func _on_doll(p: Vector2) -> bool:
	return _doll_rect().grow(4.0).has_point(p)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := Combat.zone_at(_to_doll(ev.position)) if _on_doll(ev.position) else ""
		var t := -1
		for i in 3:
			if _tab_rect(i).has_point(ev.position):
				t = i
		if h != hot or t != hot_tab:
			hot = h
			hot_tab = t
			tooltip_text = _tip()
	elif ev is InputEventMouseButton and ev.pressed and mob:
		if ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			for i in 3:
				if _tab_rect(i).has_point(ev.position):
					mob.set_aim_preset(i)
					Sfx.play_ui("click")
					aim_changed.emit()
					accept_event()
					return
			if _on_doll(ev.position):
				var d := _to_doll(ev.position).clamp(Vector2.ZERO, DOLL - Vector2.ONE)
				if ev.button_index == MOUSE_BUTTON_LEFT:
					mob.set_aim(d.floor())
					Sfx.play_ui("click")
					aim_changed.emit()
					tooltip_text = _tip()
				elif hot != "" and Game.player:
					# right click: this part's state, printed where it can be read at leisure
					Game.tell(Game.player, ".  ".join(_tip().split("\n")))
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hot = ""
		hot_tab = -1

func _tip() -> String:
	if hot_tab >= 0:
		return "Aim preset %d (H cycles)\nEach preset remembers its own aim." % (hot_tab + 1)
	if hot == "":
		return "Aim: left click a body part to attack there. Right click one to read its state.\nNumpad 8 / 4 5 6 / 1 2 3 aims too (press again for eyes, mouth, hands, feet)."
	var lines := [Combat.ZONE_NAMES[hot].capitalize()]
	var dmg := _damage(hot)
	lines.append(["Unhurt", "Bruised", "Hurt", "Badly hurt", "Mangled"][clampi(int(dmg / 12.0), 0, 4)] + ("  (%d)" % int(dmg) if dmg >= 1.0 else ""))
	if health and hot == "eyes" and health.eye_damage > 5.0:
		lines.append("Your vision is blurred.")
	var hit: float = Combat.ZONE_HIT.get(hot, 75.0)
	lines.append("Base chance to land: %d%%" % int(hit))
	if inv:
		var cover := []
		for slot in Combat.COVERS:
			if hot in Combat.COVERS[slot]:
				var w: Entity = inv.worn(slot)
				if w:
					cover.append(w.display_name)
		lines.append("Covered by: " + (", ".join(cover) if not cover.is_empty() else "nothing"))
	lines.append("Left click to aim here.")
	return "\n".join(lines)

func _damage(z: String) -> float:
	if health == null:
		return 0.0
	var d: float = health.limb.get(z, 0.0)
	# the small parts share their parent's hurt
	if Combat.ZONE_PARENT.has(z):
		d = maxf(d, health.limb.get(Combat.ZONE_PARENT[z], 0.0) * 0.8)
	if z == "eyes":
		d = maxf(d, health.eye_damage * 0.5)
	return d

static func hurt_color(dmg: float) -> Color:
	var f := clampf(dmg / 45.0, 0.0, 1.0)
	var ok := Color("#7fb896")
	var mid := Color("#e8c83a")
	var bad := Color("#e8483a")
	return ok.lerp(mid, clampf(f * 2.0, 0.0, 1.0)).lerp(bad, clampf(f * 2.0 - 1.0, 0.0, 1.0))

func _draw() -> void:
	draw_style_box(UITheme.frame("well", 0, 0), Rect2(Vector2.ZERO, Vector2(size.x, size.y - TAB_H - 6.0)))
	var r := _doll_rect()
	var aimed := mob.aimed_zone() if mob else "chest"
	# faint floor shadow
	draw_rect(Rect2(r.position.x + r.size.x * 0.2, r.end.y - r.size.y * 0.03, r.size.x * 0.6, r.size.y * 0.025), Color(0, 0, 0, 0.35))
	for z in Combat.ZONES:
		var col := hurt_color(_damage(z))
		if z == aimed:
			col = col.lerp(Color.WHITE, 0.25 + 0.15 * sin(_pulse))
		elif z == hot:
			col = col.lightened(0.3)
		else:
			col = col.darkened(0.12)
		draw_texture_rect(UITheme.tex("doll_" + z), r, false, col)
	draw_texture_rect(UITheme.tex("doll_outline"), r, false)
	if mob:
		_marker(_from_doll(mob.aim[mob.aim_preset]), AIM_COL)
	# preset tabs
	for i in 3:
		var tr := _tab_rect(i)
		var on := mob != null and mob.aim_preset == i
		draw_style_box(UITheme.frame("tab_active" if on else "tab", 0, 0), tr)
		if i == hot_tab and not on:
			draw_rect(tr.grow(-3), Color(1, 1, 1, 0.06))
		var txt := str(i + 1)
		var fs := UITheme.SMALL
		var tw := UITheme.font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(UITheme.font, Vector2(tr.get_center().x - tw * 0.5, tr.position.y + tr.size.y * 0.5 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.ACCENT if on else UITheme.DIM)

func _marker(p: Vector2, col: Color) -> void:
	var rad := 6.0
	var a := 1.0
	var shadow := Color(0, 0, 0, 0.7 * a)
	for pass_i in 2:
		var c := shadow if pass_i == 0 else Color(col, a)
		var o := Vector2(1, 1) if pass_i == 0 else Vector2.ZERO
		var w := 3.0 if pass_i == 0 else 1.5
		draw_arc(p + o, rad, 0.0, TAU, 16, c, w)
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(p + o + d * (rad - 2.0), p + o + d * (rad + 4.0), c, w)
