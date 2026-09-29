class_name CToggleLight extends Component
## Flashlights and glowsticks: Z toggles the attached CLight.

var spr_on := ""
var spr_off := ""

func key() -> StringName:
	return &"togglelight"

func setup(p: Dictionary) -> CToggleLight:
	spr_on = p.get("on", "")
	spr_off = p.get("off", "")
	return self

func attack_self(user: Entity) -> bool:
	var l: CLight = e.c(&"light")
	if l == null:
		return false
	l.on = not l.on
	l.refresh()
	if spr_on != "":
		e.set_sprite("items", spr_on if l.on else spr_off)
	Sfx.play("click", user.cell)
	var m = user.c(&"mob")
	if m:
		m.refresh_doll()
	return true
