class_name PowersBar extends PanelContainer
## tg action buttons for genetic powers (/datum/action/cooldown/spell/... granted by
## power_path): one button per power, the cooldown counting down on it, lit while a
## pointed or touch power is armed and waiting for your next click. Hidden with no powers.

## short button labels for the powers (tg shows an icon; the tooltip has tg's name)
const SHORT := {"thermal_vision": "Thermal", "snow": "Snow", "cryo": "Cryobeam", "ash": "Ash", "pyro": "Pyrobeam",
	"psychic_projection": "Project", "psychic_booster": "Boost", "psychic_wall": "Wall", "echo_focus": "Echo focus",
	"adrenaline": "Adrenaline", "self_amputation": "Drop limb", "farsight": "Farsight", "fire_breath": "Fire breath",
	"olfaction": "Scent", "telepathy": "Telepathy", "mindread": "Mindread", "tongue_spike": "Spike", "chem_spike": "Chem spike",
	"send_chems": "Send chems", "shock_touch": "Shock", "lay_on_hands": "Mend", "void_cursed": "Void", "lay_web": "Web"}

var row: HBoxContainer
var buttons := {} # power id -> Button

func _init() -> void:
	add_theme_stylebox_override("panel", UITheme.frame("panel", 8, 6, 0.86))
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	visible = false
	Bus.powers_changed.connect(rebuild)

func rebuild() -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	buttons.clear()
	var p := Game.player
	var list := GenePowers.list_of(p) if p and is_instance_valid(p) else []
	visible = not list.is_empty()
	for pw in list:
		var pid: String = pw["id"]
		var def: Dictionary = GenePowers.DEFS.get(pid, {})
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(78, 40)
		var icon_id: String = {"psychic_projection": "mindread", "psychic_booster": "adrenaline", "psychic_wall": "void_cursed"}.get(pid, pid)
		b.icon = UITheme.tex("icon_gp_" + icon_id)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", UITheme.SMALL)
		b.tooltip_text = "%s\n%s" % [def.get("name", pid), def.get("desc", "")]
		b.pressed.connect(func(): GenePowers.trigger(Game.player, pid))
		row.add_child(b)
		buttons[pid] = b
	_update()

var _acc := 0.0

func _process(dt: float) -> void:
	# cooldown text only changes once a second; 5 Hz is plenty
	_acc -= dt
	if visible and _acc <= 0.0:
		_acc = 0.2
		_update()

func _update() -> void:
	var p := Game.player
	for pw in GenePowers.list_of(p) if p and is_instance_valid(p) else []:
		var b: Button = buttons.get(pw["id"])
		if b == null:
			continue
		var left := GenePowers.cooldown_left(pw)
		var label: String = SHORT.get(pw["id"], pw["id"])
		var txt := label if left <= 0.0 else "%s\n%ds" % [label, int(ceil(left))]
		if b.text != txt:
			b.text = txt
			b.modulate = Color(1, 1, 1, 1) if left <= 0.0 else Color(0.6, 0.6, 0.65, 1)
		var armed: bool = pw.get("armed", false)
		if armed != b.get_meta("armed", false):
			b.set_meta("armed", armed)
			if armed:
				b.add_theme_color_override("font_color", UITheme.ACCENT)
				b.add_theme_color_override("font_hover_color", UITheme.ACCENT)
			else:
				b.remove_theme_color_override("font_color")
				b.remove_theme_color_override("font_hover_color")
