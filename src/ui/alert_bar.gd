class_name AlertBar extends HBoxContainer
## The status alerts (tg /atom/movable/screen/alert): one tile per thing that's wrong, each
## with its own icon, a short label so you can read it at a glance, a frame coloured by how
## bad it is, and the full tg name and advice on hover. Some can be clicked to deal with
## them, as in tg (resist out of cuffs, put out a fire, turn on internals).
## Tiles persist between refreshes, so hovering one keeps its tooltip up.

enum { INFO, WARN, BAD }

## id -> [title, description, click action or "", click hint]
const CATALOG := {
	"oxy": ["Choking (Thin Air)", "You're not getting enough oxygen. Find some good air before you pass out! A breath mask and a gas cylinder will keep you going.", "internals", "open your cylinder"],
	"co2": ["Choking (CO2)", "There's too much carbon dioxide in the air, and you're breathing it in! Find some good air before you pass out!", "internals", "open your cylinder"],
	"plasma": ["Choking (Plasma)", "There's highly flammable, toxic plasma in the air and you're breathing it in. Find some fresh air, or breathe from a cylinder.", "internals", "open your cylinder"],
	"n2o": ["Choking (N2O)", "There's sleeping gas in the air and you're breathing it in. Find some fresh air, or breathe from a cylinder.", "internals", "open your cylinder"],
	"smoke": ["Smoke", "Thick smoke is filling your lungs. Get out of it, or wear a gas mask.", "", ""],
	"internals": ["On Cylinder", "You're breathing from your gas cylinder.", "internals", "close the valve"],
	"cold": ["Too Cold", "You're freezing cold! Get somewhere warmer and put on warm clothes: a winter coat and hood hold the heat in.", "", ""],
	"hot": ["Too Hot", "You're flaming hot! Get somewhere cooler and take off any insulating clothing.", "", ""],
	"lowpressure": ["Low Pressure", "The air around you is hazardously thin.", "", ""],
	"highpressure": ["High Pressure", "The air around you is hazardously thick.", "", ""],
	"fire": ["On Fire", "You're on fire. Stop, drop and roll to put the fire out or get somewhere the air is thin.", "resist", "stop, drop and roll"],
	"cuffed": ["Handcuffed", "You're handcuffed and can't act. If anyone drags you, you won't be able to move.", "resist", "wriggle out of the cuffs"],
	"buckled": ["Buckled", "You've been buckled to something.", "resist", "unbuckle"],
	"pulled": ["Grabbed", "Someone has hold of you. You can't walk away while they do.", "resist", "break free"],
	"bleeding": ["Bleeding", "You're losing blood. Gauze clots it, sutures or a cautery close it; hold the wound (Ctrl+click yourself) or lie down to slow it.", "", ""],
	"determined": ["Determined", "The serious wounds you've sustained have put your body into fight-or-flight mode! Now's the time to look for an exit!", "", ""],
	"limp": ["Limping", "One or more of your legs has been wounded, slowing down steps with that leg! Get it fixed, or at least in a sling of gauze!", "", ""],
	"pain": ["In Pain", "Your injuries hurt. Painkillers or treatment will help.", "", ""],
	"sick": ["Sick", "You feel unwell. Sickbay can find out what you've caught.", "", ""],
	"hungry": ["Hungry", "Some food would be good right now.", "", ""],
	"starving": ["Starving", "You severely need food; you're growing weak and your body is starting to shut down.", "", ""],
	"thirsty": ["Thirsty", "You need something to drink.", "", ""],
	"tired": ["Exhausted", "You're running on empty. Find a bed and get some sleep before you drop.", "", ""],
	"winded": ["Winded", "You're out of breath. Rest a moment; you'll hit harder and move faster when you've recovered.", "", ""],
	"stunned": ["Stunned", "You're reeling and can't act.", "", ""],
	"floored": ["Knocked Down", "You've been knocked off your feet.", "", ""],
	"unconscious": ["Unconscious", "You're out cold.", "", ""],
	"asleep": ["Asleep", "You've fallen asleep. Wait a bit and you should wake up. Unless you don't, considering how helpless you are.", "", ""],
	"paralyzed": ["Paralyzed", "You can't move a muscle.", "", ""],
	"immobilized": ["Immobilized", "You can't move.", "", ""],
	"stamcrit": ["Exhausted", "You're too exhausted to keep going... Rest until you get your wind back.", "", ""],
	"softcrit": ["Critical", "You're in critical condition. You can only crawl and whisper; get help before you slip under.", "", ""],
	"deaf": ["Deaf", "You can't hear anything. It should pass if your ears aren't ruined; earmuffs protect them.", "", ""],
	"blind": ["Blind", "You can't see! This may be caused by a genetic defect, eye trauma, being unconscious, or something covering your eyes.", "", ""],
	"high": ["High", "Whoa man, you're tripping balls! Careful you don't get addicted... if you aren't already.", "", ""],
	"embedded": ["Embedded Item", "Something got lodged into your flesh. It might fall out with time; aim at the part and use your hand to pull it out, or have someone use a hemostat or wirecutters.", "", ""],
	"drunk": ["Drunk", "All that alcohol you've been drinking is impairing your speech, motor skills, and mental cognition. Make sure to act like it.", "", ""],
	"disgust": ["Grossed out", "That was kind of gross...", "", ""],
	"trance": ["Trance", "Everything feels so distant, and you can feel your thoughts forming loops inside your head...", "", ""],
	"blurry": ["Blurred Vision", "Your eyes are hurt and everything's blurry. It'll clear with time; torch goggles would have helped.", "", ""],
}

var on_click: Callable # func(action: String)
var tiles := {} # id -> AlertTile

func _init() -> void:
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## `list`: [{id, sev, label, extra}] in display order. `extra` is added to the hover text.
func set_alerts(list: Array) -> void:
	var seen := {}
	var order := 0
	for a in list:
		var id: String = a["id"]
		seen[id] = true
		var t: AlertTile = tiles.get(id)
		if t == null:
			t = AlertTile.new()
			t.bar = self
			t.id = id
			tiles[id] = t
			add_child(t)
			t.build()
			t.pop()
		t.apply(int(a.get("sev", WARN)), String(a.get("label", "")), String(a.get("extra", "")))
		move_child(t, order)
		order += 1
	for id in tiles.keys():
		if not seen.has(id):
			tiles[id].queue_free()
			tiles.erase(id)

func clicked(id: String) -> void:
	var act: String = CATALOG.get(id, ["", "", "", ""])[2]
	if act != "" and on_click.is_valid():
		on_click.call(act)


class AlertTile extends PanelContainer:
	var bar: AlertBar
	var id := ""
	var sev := -1
	var extra := ""
	var icon_rect: TextureRect
	var text: Label
	var pulse: Tween

	func build() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(52, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
		icon_rect = TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = Gfx.tex("fx")
		at.region = Gfx.region("fx", "ui_alert_" + id)
		icon_rect.texture = at
		icon_rect.custom_minimum_size = Vector2(36, 36)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(icon_rect)
		text = Label.new()
		text.add_theme_font_size_override("font_size", 13)
		text.add_theme_constant_override("outline_size", 4)
		text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(text)
		tooltip_text = " " # non-empty so Godot asks _make_custom_tooltip

	func apply(s: int, label: String, more: String) -> void:
		extra = more
		if label == "":
			label = AlertBar.CATALOG.get(id, [id])[0].to_upper()
		text.text = label
		if s == sev:
			return
		var worse := s > sev and sev >= 0
		sev = s
		add_theme_stylebox_override("panel", UITheme.frame(["slot_normal", "slot_hot", "slot_active"][s], 3, 2))
		text.add_theme_color_override("font_color", [UITheme.ACCENT, UITheme.WARN, UITheme.BAD][s])
		if pulse:
			pulse.kill()
			pulse = null
		self_modulate = Color.WHITE
		if s == AlertBar.BAD:
			# the dangerous ones throb, like tg's flashing alerts
			pulse = create_tween().set_loops()
			pulse.tween_property(self, "self_modulate", Color(1.6, 0.7, 0.7), 0.45).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(self, "self_modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)
		if worse:
			pop()

	## A new (or worse) alert flashes in so you notice it.
	func pop() -> void:
		modulate = Color(2.0, 2.0, 2.0, 0.0)
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color(1.6, 1.6, 1.6, 1.0), 0.12)
		tw.tween_property(self, "modulate", Color.WHITE, 0.35)
		Sfx.play_ui("ui_tick", 0.5, 0.8 if sev == AlertBar.BAD else 1.1)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			bar.clicked(id)
			accept_event()

	func _make_custom_tooltip(_for_text: String) -> Object:
		var info: Array = AlertBar.CATALOG.get(id, [id, "", "", ""])
		var col: Color = [UITheme.ACCENT, UITheme.WARN, UITheme.BAD][maxi(sev, 0)]
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.custom_minimum_size = Vector2(300, 0)
		r.add_theme_font_size_override("normal_font_size", 14)
		r.add_theme_font_size_override("bold_font_size", 16)
		var s := "[b][color=#%s]%s[/color][/b]\n%s" % [col.to_html(false), info[0], info[1]]
		if extra != "":
			s += "\n[color=#%s]%s[/color]" % [UITheme.DIM.to_html(false), extra]
		if info[2] != "":
			s += "\n[color=#%s]Click to %s.[/color]" % [UITheme.GOOD.to_html(false), info[3]]
		r.text = s
		return r
