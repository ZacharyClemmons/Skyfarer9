class_name CStatusDisplay extends Component
## Wall screen (tg: /obj/machinery/status_display/evac). Shows the crawler's timer while
## it's called, docked or leaving, otherwise flips between the station clock and the alert level.

var label: Label
var _t := 0.0
var _page := 0

func key() -> StringName:
	return &"statusdisplay"

func on_added() -> void:
	label = Label.new()
	label.add_theme_font_override("font", UITheme.mono)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_constant_override("line_spacing", -3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-11, -52)
	label.size = Vector2(22, 12)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.z_index = 1
	e.add_child(label)
	refresh()

func tick(dt: float) -> void:
	_t += dt
	if _t >= 3.0:
		_t = 0.0
		_page += 1
	refresh()

func refresh() -> void:
	if label == null:
		return
	var ev = Game.evac
	var col := Color("#7fe8ff")
	var text := ""
	if ev and ev.mode in [Evac.CALLED, Evac.DOCKED, Evac.ESCAPE]:
		var head: String = {Evac.CALLED: "ETA", Evac.DOCKED: "DEPART", Evac.ESCAPE: "EN ROUTE"}[ev.mode]
		text = "%s\n%s" % [head, Evac._mmss(ev.timer)]
		col = Color("#ffb84a") if ev.mode == Evac.CALLED else Color("#ff6a5a")
	elif ev and ev.mode == Evac.RECALLED:
		text = "RECALLED"
	elif _page % 2 == 0:
		text = "TIME\n" + Game.clock_string()
	else:
		text = "ALERT\n" + Game.ALERT_NAMES[Game.alert_level]
		col = Game.ALERT_COLORS[Game.alert_level]
	label.text = text
	label.add_theme_color_override("font_color", col)
