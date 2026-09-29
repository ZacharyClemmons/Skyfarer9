class_name CNoticeBoard extends Component
## The board by the gangway. Everything a new skyfarer needs to know about this sky, in
## the voice of the people who wrote it rather than a tutorial box.
##
## It is also the game's index: the rings and what is in them, which ports carry what,
## what the weather has been doing, and a standing list of things somebody will pay for.
## A player who reads one object in this game should read this one.

func key() -> StringName:
	return &"noticeboard"

func examine(_user: Entity, lines: Array) -> void:
	lines.append("[i]Read it. Click the board.[/i]")

func attack_hand(user: Entity) -> bool:
	_open()
	return true

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Read the board", "priority": 100, "cb": func():
		_open()})

## Reading it is what dismisses the "!" hovering over it (see PortLife).
func _open() -> void:
	PortLife.board_seen = true
	Game.hud.open_window("notices", e)

## The rings, written the way a harbourmaster would write them.
static func rings_text() -> String:
	var out := "[b]THE CLOUDSEA, IN RINGS[/b]\n"
	out += "[i]Posted by the Meridian harbourmaster. Amended in three hands since.[/i]\n\n"
	for t in 5:
		out += "[color=%s][b]%s[/b][/color]\n%s\n" % [
			["#6ad88a", "#a8d86a", "#e8c85a", "#e8883a", "#e8545a"][t],
			Biomes.RING_NAMES[t].capitalize(), Biomes.RING_BLURB[t]]
		if Game.sky != null and Game.sky.gen != null:
			var n := 0
			var known := 0
			for isl in Game.sky.gen.islands:
				if int(isl.get("tier", 0)) == t:
					n += 1
					if isl.get("charted", false):
						known += 1
			out += "[color=#8aa0b4]%d islands, %d of them on your chart.[/color]\n" % [n, known]
		out += "\n"
	return out

## Every port anyone here has heard of, and what it wants.
static func ports_text() -> String:
	if Game.sky == null or Game.sky.gen == null:
		return "[color=#8aa0b4]No chart posted.[/color]"
	var out := "[b]PORTS AND WHAT THEY ARE SHORT OF[/b]\n\n"
	var ports: Array = Game.sky.gen.ports
	if ports.is_empty():
		out += "[color=#8aa0b4]Nobody trades out of this sky but us.[/color]\n"
	var here: Vector2i = Game.player.cell if Game.player != null else Game.sky.gen.hub_center
	var sorted := ports.duplicate()
	sorted.sort_custom(func(a, b): return int(a.get("tier", 0)) < int(b.get("tier", 0)))
	for isl in sorted:
		var d := int(Vector2(isl["area"].center - here).length())
		var hint := Economy.port_hint(String(isl["biome"]))
		out += "[b]%s[/b]  [color=#8aa0b4]%s, %d tiles %s[/color]\n" % [
			isl["name"], Biomes.ring_name(int(isl.get("tier", 0))), d,
			CSkyCompass._bearing(Vector2(isl["area"].center - here))]
		if hint != "":
			out += "  [i]%s[/i]\n" % hint
	return out

## What is actually dangerous out there, learned from people who came back.
static func warnings_text() -> String:
	var out := "[b]WARNINGS[/b]\n\n"
	out += "[color=#e8a83a]The sky is the hazard.[/color] Walking off an edge is refused unless you \
hold Shift, and then it is not refused. A glider harness turns a fall into a landing; without one \
you have about nine seconds and nothing to do with them.\n\n"
	out += "[color=#e8a83a]Weather is not scenery.[/color] A thunderhead will charge everything you \
own and tear canvas off a mast. Fog blinds a sounder. An aether squall will lift a badly trimmed \
hull straight out of the band. Watch the glass and reef in time.\n\n"
	out += "[color=#e8a83a]Night is different.[/color] Things come out at dusk that are not there by \
day, and a lit deck is visible for a very long way.\n\n"
	out += "[color=#e8a83a]Thin air.[/color] Above the Reaches you want a mask. Above the Heights you \
want a sealed hull and a scrubber, and you want to have checked both.\n"
	if Game.sky != null:
		out += "\n[b]Now:[/b] %s\n" % Game.sky.status_text()
		var w: String = Game.sky.weather_text() if Game.sky.has_method("weather_text") else ""
		if w != "":
			out += "[color=#7fd4ff]%s[/color]\n" % w
	return out

## How the place works, for somebody who has just arrived.
static func primer_text() -> String:
	return """[b]IF YOU ARE NEW[/b]

[color=#7fd4ff]1. Get a ship.[/color] The yard at the end of the quay will sell you a skiff out of the \
book, or hand you a drawing board and let you spend the same money on something of your own. \
Neither is wrong. A bought skiff flies in a minute; a drawn hull is yours.

[color=#7fd4ff]2. Light the boiler before you touch the wheel.[/color] Thrusters run on steam. Cold \
boiler, cold engines, and a lot of standing about looking at the throttle.

[color=#7fd4ff]3. Trim her.[/color] Lift against weight decides whether you climb or sink. Ballast \
moves it forty per cent either way and it is the pilot's job, continuously.

[color=#7fd4ff]4. Everything you do makes you better at it.[/color] Cutting timber, breaking rock, \
patching a cell, haggling, flying — all of it counts, and most of it feeds something else. \
The ore you dig becomes the plate you smith becomes the hull you fit.

[color=#7fd4ff]5. Go outward slowly.[/color] The Home Reach will not kill you. The Rim will, and \
it has the only voidsteel in this sky, which is the entire argument."""
