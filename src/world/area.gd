class_name Area extends RefCounted
## A named region of the station (tg: /area). Owns power channel state (via its APC),
## climate targets and alarm state.

var id := 0
var name := "Unknown"
var dept := "civilian"
var outdoor := false
var restricted: Array = [] # access tags needed to enter legally
var cells: Array = [] # Array[Vector2i]
var apc: Entity = null
var air_alarm: Entity = null
# power channels (tg: APC equipment / lighting / environment)
var power_equip := false
var power_light := false
var power_environ := false
var heating_ok := true
var target_temp := Defs.T20C
var fire_alarm := false
var fire_pulled := false # tg fire alarm pulled by hand: every firelock in the area drops
var atmos_alarm := false
var lights_forced_off := false
var center := Vector2i.ZERO
var room_kind := ""
var power_parent: Area = null # small areas with no APC of their own run off a neighbour's

func powered(channel: String) -> bool:
	if outdoor:
		return false
	if apc == null and power_parent != null:
		return power_parent.powered(channel)
	match channel:
		"equip": return power_equip
		"light": return power_light and not lights_forced_off
		"environ": return power_environ
	return false

func random_cell(rng: RandomNumberGenerator) -> Vector2i:
	if cells.is_empty():
		return center
	return cells[rng.randi() % cells.size()]
