class_name MessageLog extends RefCounted
## Bounded history independent of what the player currently chooses to display.

const LIMIT := 2000
const CATEGORIES := ["speech", "radio", "combat", "warnings", "events", "examine", "system"]
const LABELS := ["Speech & emotes", "Radio", "Combat", "Warnings", "Announcements & successes", "Examine", "System messages"]
var entries: Array = []
var enabled := {}
var search := ""
var preset := "all"
var timestamps := false
var collapse := true
var follow := true
var font_size := 20
var _tags := RegEx.new()

func _init() -> void:
	# Strip formatting while keeping literal labels such as [Engineering] searchable.
	_tags.compile("\\[/?(?:b|i|u|s|code|color|bgcolor|font|font_size|url|img|center|left|right|fill|indent|wave|shake|rainbow|pulse|fade)(?:[= ][^\\]]*)?\\]")
	for category in CATEGORIES:
		enabled[category] = true

static func category(kind: String) -> String:
	match kind:
		"say", "emote": return "speech"
		"radio": return "radio"
		"combat", "combat_warn": return "combat"
		"warn", "bad": return "warnings"
		"good", "announce": return "events"
		"examine": return "examine"
	return "system"

## What the last add() did, so a view can patch itself instead of rebuilding:
## "append" (one new entry at the end), "collapse" (the last entry's count went up) or
## "popped" (appended, and `popped` fell off the front).
var result := "append"
var popped: Dictionary = {}

## Returns true when the whole view needs rebuilding (never now: see `result`).
func add(bb: String, kind: String, at: float) -> bool:
	var plain := _tags.sub(bb, "", true)
	popped = {}
	if collapse and not entries.is_empty():
		var last: Dictionary = entries[-1]
		if last.bb == bb and last.kind == kind and at - float(last.time) <= 3.0:
			last.count += 1
			last.time = at
			result = "collapse"
			return false
	entries.append({"bb": bb, "plain": plain, "kind": kind, "category": category(kind), "time": at, "count": 1})
	result = "append"
	if entries.size() > LIMIT:
		popped = entries.pop_front()
		result = "popped"
	return false

func matches(entry: Dictionary) -> bool:
	if not enabled.get(entry.category, true):
		return false
	if preset == "radio" and entry.category != "radio": return false
	if preset == "chat" and entry.category not in ["speech", "radio"]: return false
	if preset in ["combat", "warnings", "system", "examine"] and entry.category != preset: return false
	if preset == "local" and entry.category not in ["speech", "examine", "system"]: return false
	if preset == "events" and entry.category not in ["combat", "warnings", "events"]: return false
	return search.strip_edges().is_empty() or search.strip_edges().to_lower() in String(entry.plain).to_lower()

static func clock(at: float) -> String:
	var seconds := maxi(0, int(at))
	return "%02d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]

func format_entry(entry: Dictionary, bbcode := true) -> String:
	var prefix := "[%s] " % clock(entry.time) if timestamps else ""
	if bbcode and timestamps:
		prefix = "[color=#8294a8]%s[/color]" % prefix
	var suffix := "  ×%d" % int(entry.count) if int(entry.count) > 1 else ""
	return prefix + String(entry.bb if bbcode else entry.plain) + suffix

func plain_text() -> String:
	var lines := PackedStringArray()
	for entry in entries:
		if matches(entry):
			lines.append(format_entry(entry, false))
	return "\n".join(lines)

func save_settings() -> void:
	var config := ConfigFile.new()
	for key in ["enabled", "timestamps", "collapse", "follow", "font_size"]:
		config.set_value("log", key, get(key))
	config.save("user://message_log.cfg")

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://message_log.cfg") != OK:
		return
	for cat in CATEGORIES:
		enabled[cat] = bool(config.get_value("log", "enabled", {}).get(cat, true))
	for key in ["timestamps", "collapse", "follow"]:
		set(key, bool(config.get_value("log", key, get(key))))
	# the text size is a player preference now (UITheme.log_px, set in the Settings menu or the
	# log's Options); the old 12-18 values saved here were too small to read at 1600x900
	font_size = UITheme.log_px
