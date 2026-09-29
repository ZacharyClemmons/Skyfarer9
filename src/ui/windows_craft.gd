class_name WindowsCraft extends RefCounted
## The workbench list: everything you could make, and for the things you cannot, exactly
## what is stopping you.
##
## The design rule here is that a greyed-out recipe teaches more than a hidden one. A
## player who sees "Vashti turbine — needs Smithing 40, you have 12" at hour two has been
## given a goal, a number and a route to it, which is the entire reason the skill system
## exists. So nothing is hidden: the list shows the whole game, sorted by what you can do
## about it today.

static func handles(kind: String) -> bool:
	return kind == "skycraft"

static func title(_kind: String) -> String:
	return "The bench"

static func width(_kind: String) -> int:
	return 700

static func interval(_kind: String) -> float:
	return 1.0

static var filter := "all"
static var search := ""

const FILTERS = [
	["all", "Everything"], ["can", "Can make now"], ["mod", "Ship parts"],
	["gear", "Tools & gear"], ["mat", "Materials"],
]

static func build(_kind: String, _t: Entity, body: VBoxContainer, w: UIWindow) -> void:
	var p := Game.player
	if p == null:
		return
	var here := SkyCrafting.station_at(p).split(",")
	var words := []
	for sid in here:
		if sid != "":
			words.append(String(SkyCrafting.STATIONS[sid]["name"]))
	Windows._rt(body, "[b]Here you have:[/b] %s" % (
		", ".join(words) if not words.is_empty() else "[color=#8aa0b4]nothing but your hands. A workbench, a forge, a still or a loft opens most of this list.[/color]"))

	var bar := Windows._row(body)
	for pair in FILTERS:
		var b := Button.new()
		b.text = pair[1]
		b.toggle_mode = true
		b.button_pressed = filter == pair[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", UITheme.SMALL)
		var id: String = pair[0]
		b.pressed.connect(func():
			filter = id
			w._refresh_now())
		bar.add_child(b)
	var find := LineEdit.new()
	find.placeholder_text = "Search..."
	find.text = search
	find.text_changed.connect(func(t):
		search = t
		w._refresh_now())
	body.add_child(find)
	body.add_child(HSeparator.new())

	var rows := SkyCrafting.available(p)
	var shown := 0
	for row in rows:
		if not _passes(row):
			continue
		shown += 1
		if shown > 70:
			Windows._rt(body, "[color=#8aa0b4]...and %d more. Narrow the search.[/color]" % (rows.size() - shown))
			break
		_recipe_row(body, row, p, w)
	if shown == 0:
		Windows._rt(body, "[color=#8aa0b4]Nothing matches.[/color]")

static func _passes(row: Dictionary) -> bool:
	var r: Dictionary = row["r"]
	if search != "" and not String(r["name"]).to_lower().contains(search.to_lower()):
		return false
	match filter:
		"can": return bool(row["can"])
		"mod": return bool(r.get("module", false))
		"gear": return not bool(r.get("module", false)) and String(r.get("skill", "")) in ["artifice", "rigging", "shipwright"]
		"mat": return not bool(r.get("module", false)) and String(r.get("skill", "")) in ["smithing", "woodcutting", "distilling"]
	return true

static func _recipe_row(body: VBoxContainer, row: Dictionary, p: Entity, w: UIWindow) -> void:
	var r: Dictionary = row["r"]
	var can: bool = row["can"]
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	body.add_child(line)

	var out_id := String(r["out"])
	var pd: Dictionary = Proto.P.get(out_id, {})
	var icon := TextureRect.new()
	var spr := String(pd.get("spr", ""))
	var sheet := String(pd.get("sheet", "items"))
	if spr != "" and Gfx.has(sheet, spr):
		icon.texture = Gfx.atlas(sheet, spr)
	icon.custom_minimum_size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1, 1, 1, 1.0 if can else 0.4)
	line.add_child(icon)

	var txt := RichTextLabel.new()
	txt.bbcode_enabled = true
	txt.fit_content = true
	txt.scroll_active = false
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.custom_minimum_size = Vector2(340, 32)
	txt.add_theme_font_size_override("normal_font_size", 17)
	var head := "[b]%s[/b]" % String(r["name"])
	if bool(r.get("module", false)):
		var mid := out_id.substr(4)
		head = "[color=%s][b]%s[/b][/color]" % [ShipParts.tier_color(mid), String(r["name"])]
	# the skill and level this belongs to, so the list reads as a ladder rather than a pile
	var skill := String(r.get("skill", ""))
	var lvl := int((r.get("reqs", {}) as Dictionary).get(skill, 1))
	if skill != "":
		head += "  [color=#8aa0b4]%s %d[/color]" % [String(Skills.SKILLS.get(skill, {}).get("name", skill)), lvl]
	var note := ""
	if not bool(row["station_ok"]):
		note = "  [color=#e8a83a]needs %s[/color]" % String(SkyCrafting.STATIONS[String(r["station"])]["name"])
	elif String(row["skill_short"]) != "":
		note = "  [color=#ff6a6a]needs %s[/color]" % String(row["skill_short"])
	elif not (row["missing"] as Array).is_empty():
		note = "  [color=#e8a83a]short: %s[/color]" % ", ".join(row["missing"])
	else:
		note = "  [color=#6ad88a]ready[/color]"
	var bill := []
	for k in r.get("needs", {}):
		if int(r["needs"][k]) <= 0:
			continue
		bill.append("%s x%d" % [String(Proto.P.get(k, {}).get("name", k)), int(r["needs"][k])])
	txt.text = "%s%s\n[color=#8aa0b4]%s[/color]" % [head, note, ", ".join(bill)]
	txt.tooltip_text = "%s\n\n%s XP into %s." % [String(r.get("desc", "")),
		int(r.get("xp", 0)), String(Skills.SKILLS.get(String(r.get("skill", "")), {}).get("name", "?"))]
	line.add_child(txt)

	var make := Button.new()
	make.text = "Make"
	make.custom_minimum_size = Vector2(86, 0)
	make.disabled = not can
	var id: String = row["id"]
	make.pressed.connect(func():
		var why := SkyCrafting.craft(p, id)
		if why != "":
			Game.tell(p, "[color=#e8a83a]%s[/color]" % why, "warn")
		w._refresh_now())
	line.add_child(make)
