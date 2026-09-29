class_name Reputation extends RefCounted
## What the sky thinks of you.
##
## Two numbers, because two is enough and three would be a spreadsheet:
##
##   standing  how the ports feel. It moves prices, it decides whether a patrol waves you
##             through or boards you, and at the top end it gets you work nobody else is
##             offered.
##   wanted    how much the revenue service would like a word. Shooting traders raises it,
##             hunting pirates lowers it, and above a threshold the patrols stop hailing
##             and start shooting.
##
## The point of keeping them separate is that they are not opposites. A famous pirate has
## a terrible standing and an enormous bounty; a smuggler everybody likes has a good
## standing and a quiet warrant. Both are playable and the game does not have an opinion
## about which one you are.

static var standing := 0.0   # -1 loathed .. 1 celebrated
static var _wanted := 0      # marks on your head
static var kills := {"pirate": 0, "trader": 0, "patrol": 0, "hermit": 0}
static var _last_warning := 0.0

## Above this, a patrol that sees you will engage rather than hail.
const HUNTED_AT := 600

static func reset() -> void:
	standing = 0.0
	_wanted = 0
	kills = {"pirate": 0, "trader": 0, "patrol": 0, "hermit": 0}

static func wanted() -> int:
	return _wanted

static func hunted() -> bool:
	return _wanted >= HUNTED_AT

# ------------------------------------------------------------------ events
static func on_pirate_killed() -> void:
	kills["pirate"] = int(kills["pirate"]) + 1
	standing = clampf(standing + 0.04, -1.0, 1.0)
	# hunting pirates works off a warrant, slowly. It does not wipe one.
	var before := _wanted
	_wanted = maxi(0, _wanted - 90)
	if before >= HUNTED_AT and _wanted < HUNTED_AT:
		Game.msg("[color=#6ad88a]Word gets to Meridian. The cutters stop looking for you.[/color]", "good")

static func on_innocent_killed(kind: String) -> void:
	kills[kind] = int(kills.get(kind, 0)) + 1
	var cost := {"trader": 420, "patrol": 900, "hermit": 260}.get(kind, 300)
	_wanted += int(cost)
	standing = clampf(standing - 0.12, -1.0, 1.0)
	Game.msg("[color=#ff6a6a]Somebody saw that. Your name is worth %s marks to the wrong people.[/color]" % Economy.money(_wanted), "bad")
	if _wanted >= HUNTED_AT and Game.time > _last_warning:
		_last_warning = Game.time + 60.0
		Game.msg("[b][color=#ff6a6a]The Meridian watch has issued a warrant. Revenue cutters will engage on sight.[/color][/b]", "bad")
		Bus.chronicle.emit("A warrant was issued for %s." % (Game.player.display_name if Game.player else "the pilot"), 3)

static func on_attacked_innocent(kind: String) -> void:
	_wanted += 60
	standing = clampf(standing - 0.02, -1.0, 1.0)

static func on_contract_done(pay: int) -> void:
	standing = clampf(standing + clampf(float(pay) / 12000.0, 0.01, 0.12), -1.0, 1.0)

static func on_contract_failed() -> void:
	standing = clampf(standing - 0.05, -1.0, 1.0)

## Paying it off at a port, which is always possible and always expensive.
static func fine() -> int:
	return int(_wanted * 1.6)

static func pay_fine(who: Entity) -> bool:
	var cost := fine()
	if cost <= 0:
		return false
	if not Economy.take(who, cost):
		Game.tell(who, "[color=#ff6a6a]You cannot cover it. %s marks.[/color]" % Economy.money(cost), "warn")
		return false
	_wanted = 0
	standing = clampf(standing + 0.05, -1.0, 1.0)
	Game.tell(who, "[color=#6ad88a]The warrant is discharged. The clerk does not look up.[/color]", "good")
	Bus.chronicle.emit("%s settled with the Meridian watch for %s marks." % [
		who.display_name, Economy.money(cost)], 2)
	return true

# ------------------------------------------------------------------ what it does
## The discount or surcharge a port applies on top of haggling.
static func price_shift() -> float:
	return clampf(standing, -0.3, 0.3)

## What a trader will say about you when you walk in.
static func word() -> String:
	if _wanted >= HUNTED_AT:
		return "[color=#ff6a6a]wanted[/color]"
	if _wanted > 0:
		return "[color=#e8a83a]known to the watch[/color]"
	if standing > 0.6:
		return "[color=#6ad88a]well thought of[/color]"
	if standing > 0.2:
		return "[color=#6ad88a]trusted[/color]"
	if standing < -0.4:
		return "[color=#ff6a6a]not welcome[/color]"
	if standing < -0.1:
		return "[color=#e8a83a]watched[/color]"
	return "[color=#8aa0b4]nobody in particular[/color]"

static func status_text() -> String:
	return "standing %+.2f, %s%s" % [standing, word(),
		("  warrant %s marks" % Economy.money(_wanted)) if _wanted > 0 else ""]
