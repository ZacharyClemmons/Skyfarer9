class_name Chronicle extends Node
## The station's story log: every notable happening, timestamped. Viewable in-game (L),
## and summarised at the end of a life. Secret entries (traitors) are revealed at the end.

var entries: Array = [] # {t, clock, text, importance, secret}

func _ready() -> void:
	Bus.chronicle.connect(_on_entry)

func _on_entry(text: String, importance: int) -> void:
	# de-duplicate identical lines within a short window
	for k in range(entries.size() - 1, maxi(-1, entries.size() - 6), -1):
		if entries[k]["text"] == text and Game.time - entries[k]["t"] < 30.0:
			return
	entries.append({"t": Game.time, "clock": Game.clock_string(), "text": text, "importance": importance, "secret": false})

func add_secret(text: String) -> void:
	entries.append({"t": Game.time, "clock": Game.clock_string(), "text": text, "importance": 3, "secret": true})

func as_bbcode(show_secrets := false) -> String:
	var lines := []
	for en in entries:
		if en["secret"] and not show_secrets:
			continue
		var col = ["#9aa8b8", "#c8d4e0", "#ffd48a", "#ff9a6a", "#ff6a5a", "#ff4a8a"][clampi(en["importance"], 0, 5)]
		lines.append("[color=#6a7a8a]%s[/color]  [color=%s]%s[/color]" % [en["clock"], col, en["text"]])
	if lines.is_empty():
		return "[color=#6a7a8a]Nothing of note has happened... yet.[/color]"
	return "\n".join(lines)
