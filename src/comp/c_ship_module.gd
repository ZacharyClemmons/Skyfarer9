class_name CShipModule extends Component
## A crated ship part, waiting to be fitted.
##
## You buy one of these at a yard, carry it aboard, and click the hole it goes in. That
## is deliberately a physical act: the module has weight, it takes up hold space on the
## way home, and a ship that is being refitted is a ship with its engine sitting on the
## deck. The shipyard panel can do the same job from a list when you are moored, because
## doing it by hand forty times would stop being interesting.

var mod := ""

func key() -> StringName:
	return &"shipmodule"

func setup(p: Dictionary) -> CShipModule:
	mod = String(p.get("mod", ""))
	return self

func info() -> Dictionary:
	return ShipParts.get_mod(mod)

func examine(user: Entity, lines: Array) -> void:
	var m := info()
	if m.is_empty():
		return
	lines.append("[color=%s]%s — %s[/color]" % [ShipParts.tier_color(mod),
		ShipParts.TIER_NAMES[clampi(ShipParts.tier_of(mod), 0, 4)].capitalize(),
		String(ShipParts.CATS.get(String(m["cat"]), {}).get("name", "part")).to_lower()])
	var req: Dictionary = m.get("req", {})
	if not req.is_empty():
		var short := Skills.shortfall(user, req)
		lines.append("%sNeeds %s.%s" % [
			"[color=#ff6a6a]" if short != "" else "[color=#6ad88a]",
			Skills.req_text(req), "[/color]"])

## Click a tile of your ship with this in hand.
func use_on_cell(user: Entity, c: Vector2i) -> bool:
	var sh: Airship = Game.fleet.ship_of(user) if Game.fleet else null
	if sh == null and Game.fleet != null:
		sh = Game.fleet.ship_at(c)
	if sh == null:
		Game.tell(user, "You have to be aboard the ship you are fitting.", "warn")
		return true
	if maxi(absi(c.x - user.root_cell().x), absi(c.y - user.root_cell().y)) > 1:
		Game.tell(user, "Out of reach. Stand next to the mounting.", "warn")
		return true
	return install(user, sh, sh.local_of(c))

## The shared path: the rig, the crate in hand and the shipyard panel all end up here.
func install(user: Entity, sh: Airship, local: Vector2i) -> bool:
	var m := info()
	if m.is_empty():
		return false
	if not sh.cells_map.has(local):
		Game.tell(user, "There is nothing of the ship there.", "warn")
		return true
	var glyph := String(sh.cells_map[local])
	if not ShipParts.fits_glyph(mod, glyph):
		var want := ShipParts.glyph_for(mod)
		Game.tell(user, "A %s does not go there. It needs a %s mounting." % [
			ShipParts.name_of(mod), _glyph_word(want)], "warn")
		return true
	var req: Dictionary = m.get("req", {})
	var short := Skills.shortfall(user, req)
	if short != "":
		Game.tell(user, "[color=#ff6a6a]You cannot make this fit. You would need %s.[/color]" % short, "warn")
		return true
	var old := sh.module_at(local)
	var secs: float = (2.4 + float(m.get("mass", 2.0)) * 0.5) * Skills.speed(user, "shipwright")
	Game.tell(user, "You start fitting the %s..." % ShipParts.name_of(mod))
	DoAfter.start(user, null, secs, func(ok: bool):
		if not ok or not is_instance_valid(e) or e.removed:
			return
		if not sh.set_module(local, mod):
			Game.tell(user, "It will not seat.", "warn")
			return
		Sfx.play("ratchet", sh.cell(local.x, local.y), 0.8)
		Game.tell(user, "[color=#6ad88a]%s, fitted.[/color]" % ShipParts.name_of(mod).capitalize(), "good")
		Skills.add_xp(user, "shipwright", 30.0 + float(ShipParts.tier_of(mod)) * 22.0)
		# the old part comes off in one piece if you knew what you were doing
		if old != "" and old != mod:
			var keep := Game.rng.randf() < 0.35 + Skills.frac(user, "shipwright") * 0.6
			if keep and Proto.has("mod_" + old):
				Proto.spawn("mod_" + old, user.root_cell())
				Game.tell(user, "The old %s comes off in one piece." % ShipParts.name_of(old))
			else:
				Game.tell(user, "[color=#8aa0b4]The old %s does not survive coming out.[/color]" % ShipParts.name_of(old))
		e.destroy())
	return true

static func _glyph_word(g: String) -> String:
	return {"E": "thruster", "p": "airscrew", "m": "mast", "L": "lift cell", "B": "boiler",
		"G": "dynamo", "T": "bunker", "g": "gun", "h": "helm", "n": "chart table",
		"C": "utility", "#": "hull"}.get(g, "different")
