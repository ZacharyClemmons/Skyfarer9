class_name SkillsPanel extends VBoxContainer
## The skills screen (P): six attribute cards, then every skill grouped by field with a
## level badge and an XP bar. Everything updates live as XP comes in, and a bar that
## just gained XP glows for a moment.

var ent: Entity
var header: Label
var sub: Label
var total_badge: Badge
var rows := {} # id -> {bar: XPBar, badge: Badge, attr: bool}
var _last_xp := {}

func _init(e: Entity) -> void:
	ent = e
	add_theme_constant_override("separation", 10)
	custom_minimum_size = Vector2(760, 0)
	# header: name, job, and a "total level" badge
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	add_child(top)
	total_badge = Badge.new(62, UITheme.ACCENT)
	total_badge.tooltip_text = "Total level: every skill and attribute level added up."
	top.add_child(total_badge)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	header = UITheme.label("", 22, Color.WHITE)
	tv.add_child(header)
	sub = UITheme.label("", 14, UITheme.DIM)
	tv.add_child(sub)
	tv.add_child(UITheme.label("You get better at what you do. Levels go to 100 and are kept between shifts.", 13, Color(UITheme.DIM, 0.8)))
	# attributes
	add_child(_section("Attributes", UITheme.ACCENT))
	var ag := GridContainer.new()
	ag.columns = 3
	ag.add_theme_constant_override("h_separation", 8)
	ag.add_theme_constant_override("v_separation", 8)
	add_child(ag)
	for a in Skills.ATTRIBUTES:
		ag.add_child(_attr_card(a))
	# skills, two columns of groups
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	add_child(cols)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for c in [left, right]:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_theme_constant_override("separation", 4)
		cols.add_child(c)
	for gi in Skills.GROUPS.size():
		var g: Array = Skills.GROUPS[gi]
		var col := left if gi % 2 == 0 else right
		col.add_child(_section(g[0], g[1]))
		for s in g[2]:
			col.add_child(_skill_row(s, g[1]))
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, 6)
		col.add_child(sp)
	_refresh(true)

func _section(text: String, col: Color) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var dot := ColorRect.new()
	dot.color = col
	dot.custom_minimum_size = Vector2(4, 16)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	h.add_child(UITheme.label(text.to_upper(), 14, col))
	return h

func _attr_card(a: String) -> Control:
	var col: Color = Skills.ATTR_COLORS[a]
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.14, 0.95)
	sb.border_color = Color(col, 0.55)
	sb.border_width_top = 3
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(240, 0)
	pc.tooltip_text = Skills.ATTRIBUTES[a]["desc"]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	pc.add_child(h)
	var badge := Badge.new(40, col)
	h.add_child(badge)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	h.add_child(v)
	v.add_child(UITheme.label(Skills.ATTRIBUTES[a]["name"], 16, Color.WHITE))
	var bar := XPBar.new(col)
	v.add_child(bar)
	rows[a] = {"bar": bar, "badge": badge, "attr": true}
	return pc

func _skill_row(s: String, col: Color) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.tooltip_text = Skills.SKILLS[s]["desc"] + "\n(grows %s)" % Skills.ATTRIBUTES[Skills.SKILLS[s]["attr"]]["name"].to_lower()
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	var badge := Badge.new(30, col)
	h.add_child(badge)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)
	v.add_child(UITheme.label(Skills.SKILLS[s]["name"], 15, UITheme.TEXT))
	var bar := XPBar.new(col)
	bar.custom_minimum_size = Vector2(0, 13)
	v.add_child(bar)
	rows[s] = {"bar": bar, "badge": badge, "attr": false}
	return h

func _process(_dt: float) -> void:
	if Engine.get_process_frames() % 10 == 0:
		_refresh(false)

func _refresh(first: bool) -> void:
	if ent == null or not is_instance_valid(ent):
		return
	var m: CMob = ent.c(&"mob")
	if m == null:
		return
	header.text = ent.display_name
	sub.text = Jobs.title(m.job)
	var total := 0
	for id in rows:
		var r: Dictionary = rows[id]
		var attr: bool = r["attr"]
		var xp: float = (m.attr_xp if attr else m.xp).get(id, 0.0)
		var mult := Skills.ATTR_MULT if attr else Skills.SKILL_MULT
		var pw := Skills.ATTR_POWER if attr else Skills.SKILL_POWER
		var lvl := Skills.xp_to_level(xp, mult, pw)
		total += lvl
		r["badge"].value = lvl
		var bar: XPBar = r["bar"]
		bar.frac = Skills.progress(xp, mult, pw)
		var nxt := Skills.level_to_xp(mini(lvl + 1, Skills.MAX_LEVEL), mult, pw)
		bar.text = "MAX" if lvl >= Skills.MAX_LEVEL else "%d / %d xp" % [int(xp), int(nxt)]
		if not first and _last_xp.get(id, xp) < xp:
			bar.flash = 1.0
		_last_xp[id] = xp
		bar.queue_redraw()
		r["badge"].queue_redraw()
	total_badge.value = total
	total_badge.queue_redraw()


## Round level badge: a ring filled in the skill's colour with the level in the middle.
class Badge extends Control:
	var value := 1
	var col := Color.WHITE
	func _init(sz: float, c: Color) -> void:
		col = c
		custom_minimum_size = Vector2(sz, sz)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_PASS
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		draw_circle(c, r, Color(0.03, 0.05, 0.08))
		draw_circle(c, r - 3.0, Color(col, 0.18))
		# a ring that fills with the level, out of 100
		draw_arc(c, r - 1.5, 0, TAU, 40, Color(col, 0.25), 3.0)
		draw_arc(c, r - 1.5, -PI * 0.5, -PI * 0.5 + TAU * clampf(value / 100.0, 0.0, 1.0), 40, col, 3.0)
		var fs := int(r * 0.9)
		var t := str(value)
		var w := UITheme.font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(UITheme.font, c + Vector2(-w * 0.5, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## XP bar with a soft gradient fill, a highlight line, the numbers on it, and a glow
## that fades after it gains XP.
class XPBar extends Control:
	var frac := 0.0
	var col := Color.WHITE
	var text := ""
	var flash := 0.0
	func _init(c: Color) -> void:
		col = c
		custom_minimum_size = Vector2(0, 14)
		mouse_filter = Control.MOUSE_FILTER_PASS
	func _process(delta: float) -> void:
		if flash > 0.0:
			flash = maxf(0.0, flash - delta * 0.8)
			queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.02, 0.03, 0.05, 0.95))
		var w := size.x * frac
		if w > 0.5:
			var steps := 12
			for i in steps:
				var f := float(i) / steps
				draw_rect(Rect2(f * w, 0, w / steps + 0.5, size.y), col.darkened(0.45 - f * 0.35))
			draw_rect(Rect2(0, 0, w, 1), Color(1, 1, 1, 0.25))
			if flash > 0.0:
				draw_rect(Rect2(0, 0, w, size.y), Color(1, 1, 1, flash * 0.35))
		draw_rect(r, Color(col, 0.35), false, 1.0)
		if text != "" and size.y >= 12:
			var fs := int(size.y) + 3
			var tw := UITheme.mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(UITheme.mono, Vector2(size.x - tw - 4, size.y - 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.75))
