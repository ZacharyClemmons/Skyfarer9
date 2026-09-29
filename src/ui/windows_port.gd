class_name WindowsPort extends RefCounted
## The counter, and the board.
##
## A shop window in this game is a conversation with a person who has an opinion about
## what you are carrying, so it shows three things at once: what they have, what they
## will give you for yours, and what this port is short of. The last one is the important
## one — it is the only place a trade route is ever explained, and it is explained by the
## person who would know.

static func handles(kind: String) -> bool:
	return kind in ["shop", "notices", "skycraft"]

static func title(kind: String, t: Entity) -> String:
	match kind:
		"shop":
			return t.display_name.capitalize() if t != null else "The counter"
		"notices": return "The notice board"
		"skycraft": return WindowsCraft.title(kind)
	return kind

static func width(kind: String) -> int:
	if kind == "skycraft":
		return WindowsCraft.width(kind)
	return {"shop": 760, "notices": 700}.get(kind, 520)

static func interval(kind: String) -> float:
	return {"shop": 1.0, "notices": 4.0, "skycraft": 1.0}.get(kind, 1.0)

static func build(kind: String, t: Entity, body: VBoxContainer, w: UIWindow) -> void:
	match kind:
		"shop": WindowsShop.build(t, body, w)
		"notices": _notices(body, w)
		"skycraft": WindowsCraft.build(kind, t, body, w)

# ------------------------------------------------------------------ the board
static var board_tab := "primer"

static func _notices(body: VBoxContainer, w: UIWindow) -> void:
	var tabs := Windows._row(body)
	for pair in [["primer", "If you are new"], ["rings", "The rings"], ["ports", "Ports"], ["warn", "Warnings"]]:
		var b := Button.new()
		b.text = pair[1]
		b.toggle_mode = true
		b.button_pressed = board_tab == pair[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", UITheme.SMALL)
		var id: String = pair[0]
		b.pressed.connect(func():
			board_tab = id
			w._refresh_now())
		tabs.add_child(b)
	body.add_child(HSeparator.new())
	var text := ""
	match board_tab:
		"primer": text = CNoticeBoard.primer_text()
		"rings": text = CNoticeBoard.rings_text()
		"ports": text = CNoticeBoard.ports_text()
		"warn": text = CNoticeBoard.warnings_text()
	Windows._rt(body, text, 360)
