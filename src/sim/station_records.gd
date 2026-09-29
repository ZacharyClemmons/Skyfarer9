class_name StationAlerts extends RefCounted
## tg's station alert console: area alarms get relayed to Engineering (and fire alarms to
## everyone) over radio as the "Ship Alert Bell". NPCs with the right headset learn
## about the problem this way, not by magic.

static var active := {} # key -> {text, fact, area}

static func raise(area: Area, kind: String, text: String) -> void:
	var key := "%s:%d" % [kind, area.id]
	if active.has(key):
		return
	var cell: Vector2i = area.center
	var fact := {"type": "fire" if kind == "fire" else "atmos_alarm", "key": key, "cell": cell, "area": area.id, "severity": 2}
	active[key] = {"text": text, "fact": fact, "area": area.id}
	radio_system("Ship Alert Bell", "Engineering", text, fact)
	if kind == "fire":
		radio_system("Ship Alert Bell", "Common", text, fact)
	Bus.chronicle.emit(text, 1)

static func clear(area: Area) -> void:
	var cleared := false
	for key in active.keys():
		if active[key]["area"] == area.id:
			active.erase(key)
			cleared = true
	if cleared:
		radio_system("Ship Alert Bell", "Engineering", "Alarm cleared in %s." % area.name, {"type": "alarm_clear", "key": "clear:%d" % area.id, "area": area.id, "cell": area.center, "severity": 0})

static func radio_system(speaker_name: String, channel: String, text: String, fact: Dictionary) -> void:
	if Game.power != null and not Game.power.telecomms_ok():
		return
	var f := fact.duplicate()
	f["speaker_name"] = speaker_name
	Bus.radio.emit(null, channel, text, f)
