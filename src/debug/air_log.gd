class_name AirLog extends Node
## --airlog (with --autotest): every 20 s of sim time, the station's room air and any open
## door that touches the outside, to find where the air goes.

var t := 0.0

func _process(delta: float) -> void:
	if not Game.running:
		return
	t += delta * Game.time_scale
	if t < 20.0:
		return
	t = 0.0
	var n2 := 0.0
	for ar in Game.map.areas:
		if ar.outdoor or ar.room_kind == "gas_chamber":
			continue
		for c in ar.cells:
			n2 += Game.atmos.gas[Defs.G_N2][Game.map.idx(c)]
	var open := []
	for d in Game.all_with(&"door"):
		var dc: CDoor = d.c(&"door")
		if not dc.is_open():
			continue
		for dd in Defs.DIRS4:
			if Game.map.is_outdoor(d.cell + dd):
				var who := []
				for m in Game.in_radius(d.cell, 2, &"mob"):
					who.append(m.display_name.split(" ")[0] + ":" + (m.c(&"brain").goal.get("id", "") if m.has_c(&"brain") else "player"))
				open.append("%s %s" % [Game.map.area_at(d.cell).name, who])
				break
	var pumps := []
	for m in Game.all_with(&"pipemachine"):
		var pm: CPipeMachine = m.c(&"pipemachine")
		if pm.display in ["Air to Distro", "O2 to Airmix", "N2 to Airmix"]:
			var mm: CMachine = m.c(&"machine")
			pumps.append("%s:%s%s moved %.0f" % [pm.display.split(" ")[0], "on" if pm.on else "OFF", "" if mm == null or mm.operable() else " UNPOWERED", pm.moved_last])
	print("AIR %s N2 %d | %s | open to outside: %s" % [Game.clock_string(), int(n2), ", ".join(pumps), open])
