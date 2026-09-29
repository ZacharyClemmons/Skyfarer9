class_name Embeds extends RefCounted
## tg /datum/embedding (code/datums/embedding.dm): thrown spears and bullets that lodge in a
## bodypart, hurt while they're in, can fall out, jostle when you move, and have to be
## ripped out by hand or plucked with a hemostat or wirecutters.
##
## An embed is a dictionary in CHealth.embedded: {part, name, proto, w, sharp, data, dropdel}.
## Bullets leave tg /obj/item/shrapnel/bullet, which is DROPDEL: it's gone once out.

const EMBED_THROWSPEED_THRESHOLD := 4
const EMBED_CHANCE_SPEED_BONUS := 10
const RIPPING_OUT_HELP_TIME_MULTIPLIER := 0.75
const RIPPING_OUT_HELP_DAMAGE_MULTIPLIER := 0.75

## tg /datum/embedding defaults
const DEFAULT := {"embed_chance": 45.0, "fall_chance": 5.0, "pain_chance": 15.0, "pain_mult": 2.0, "impact_pain_mult": 4.0,
	"remove_pain_mult": 6.0, "rip_time": 3.0, "ignore_throwspeed": false, "jostle_chance": 5.0, "jostle_pain_mult": 1.0,
	"pain_stam_pct": 0.0, "stealthy": false}

## Per-type overrides (tg subtypes).
const TYPES := {
	"bullet": {"embed_chance": 20.0, "fall_chance": 2.0, "jostle_chance": 0.0, "ignore_throwspeed": true, "pain_stam_pct": 0.5,
		"pain_mult": 3.0, "rip_time": 1.0, "stealthy": true, "falloff": -3.0},
	"c38": {"embed_chance": 25.0, "fall_chance": 2.0, "jostle_chance": 2.0, "ignore_throwspeed": true, "pain_stam_pct": 0.4,
		"pain_mult": 3.0, "jostle_pain_mult": 5.0, "rip_time": 1.0, "stealthy": true, "falloff": -4.0},
	"spear": {"impact_pain_mult": 2.0, "remove_pain_mult": 4.0, "jostle_chance": 2.5},
	"shard": {"embed_chance": 65.0},
	"shrapnel": {"embed_chance": 70.0, "ignore_throwspeed": true, "fall_chance": 1.0, "stealthy": true},
	"combat_knife": {"pain_mult": 4.0, "embed_chance": 65.0, "fall_chance": 10.0, "ignore_throwspeed": true},
}

## Which items and rounds embed, and as what (tg embed_type on the item or projectile).
const ITEM_EMBED := {"spear": "spear", "glass_shard": "shard", "knife_combat": "combat_knife"}
const ROUND_EMBED := {"ammo_38": "c38", "shell_slug": "bullet", "shell_buckshot": "bullet"}
## tg throw_speed (default 2)
const THROW_SPEED := {"spear": 4, "knife_combat": 3}

static func data(kind: String) -> Dictionary:
	var d := DEFAULT.duplicate()
	d.merge(TYPES.get(kind, {}), true)
	return d

static func harmless(d: Dictionary, consider_stamina := false) -> bool:
	return d["pain_mult"] == 0.0 and d["jostle_pain_mult"] == 0.0 and (consider_stamina or d["pain_stam_pct"] < 1.0)

## tg can_embed + roll_embed_chance. `armor` is the better of bullet and bomb armour.
static func roll(h: CHealth, d: Dictionary, zone: String, speed: int, armor: float, weak_vs_armor := false) -> bool:
	if speed < EMBED_THROWSPEED_THRESHOLD and not d["ignore_throwspeed"]:
		return false
	var chance: float = d["embed_chance"]
	if harmless(d):
		return Body.prob(chance)
	var arm := armor * 0.5
	if arm <= 0.0:
		return Body.prob(chance)
	if weak_vs_armor:
		arm *= 1.5
	chance -= arm
	if chance < 0.0:
		Game.visible_message(h.e.cell, "It bounces off %s's armor, unable to embed!" % h.e.display_name, "warn")
		return false
	return Body.prob(chance)

## tg embed_into: it lodges in the part, and the impact hurts (throwforce + w * impact_pain_mult).
static func embed_into(h: CHealth, part: String, name: String, proto: String, w: int, sharp: String, d: Dictionary, throwforce := 0.0, dropdel := false, source: Entity = null) -> Dictionary:
	if h.missing.has(part):
		part = "chest"
	var em := {"part": part, "name": name, "proto": proto, "w": w, "sharp": sharp, "data": d, "dropdel": dropdel}
	h.embedded.append(em)
	var pn := Body.pname(part)
	var verb := "sticks itself to" if harmless(d) else "embeds itself in"
	Game.visible_message(h.e.cell, "[b]The %s %s %s's %s![/b]" % [name, verb, h.e.display_name, pn], "bad")
	var damage := throwforce
	if not harmless(d, true):
		if not harmless(d):
			Sfx.play("hit", h.e.cell, 0.6)
		damage += w * d["impact_pain_mult"]
	if damage > 0.0:
		var arm := Combat.armor(h.e, Body.PARTS[part]["zones"][0])
		_hurt(h, part, damage * (1.0 - clampf(arm, 0.0, 100.0) / 100.0), d, sharp, source)
	Bus.mob_state_changed.emit(h.e)
	return em

## Brute to the part (tg apply_damage with pain_stam_pct split off as stamina).
static func _hurt(h: CHealth, part: String, damage: float, d: Dictionary, sharp: String, source: Entity = null, wound_bonus := -1000.0) -> void:
	var zone: String = Body.PARTS[part]["zones"][0]
	var brute: float = (1.0 - d["pain_stam_pct"]) * damage
	if brute > 0.0:
		h.hurt_zone(zone, brute, "brute", source, sharp, wound_bonus)
	var stam: float = d["pain_stam_pct"] * damage
	if stam > 0.0:
		h.adjust("stamina", stam, source)

## tg /datum/embedding/process, once a second per embed
static func tick(h: CHealth, dt: float) -> void:
	if h.embedded.is_empty() or h.dead:
		return
	for em in h.embedded.duplicate():
		if not em in h.embedded:
			continue
		if h.missing.has(em["part"]):
			_drop(h, em)
			continue
		var d: Dictionary = em["data"]
		var fall: float = (1.0 - pow(1.0 - d["fall_chance"] / 100.0, dt)) * 100.0
		if h.lying():
			fall *= 0.2
		if Body.prob(fall):
			fall_out(h, em)
			continue
		var damage: float = em["w"] * d["pain_mult"]
		var pain: float = (1.0 - pow(1.0 - d["pain_chance"] / 100.0, dt)) * 100.0
		if d["pain_stam_pct"] > 0.0 and h.stamcrit:
			pain *= 0.2
			damage *= 0.5
		elif h.lying():
			pain *= 0.2
		if harmless(d, true) or not Body.prob(pain):
			continue
		_hurt(h, em["part"], damage, d, em["sharp"])
		var pn := Body.pname(em["part"])
		if d["stealthy"]:
			Game.tell(h.e, "Something in your %s %s" % [pn, "hurts!" if d["pain_stam_pct"] < 1.0 else "weighs you down."], "bad")
		else:
			Game.tell(h.e, "[b]The %s embedded in your %s %s[/b]" % [em["name"], pn, "hurts!" if d["pain_stam_pct"] < 1.0 else "weighs you down."], "bad")

## tg owner_moved: moving about jostles what's stuck in you (half as likely walking or lying)
static func on_move(h: CHealth, walking: bool) -> void:
	if h.embedded.is_empty():
		return
	for em in h.embedded.duplicate():
		var d: Dictionary = em["data"]
		var chance: float = d["jostle_chance"]
		if walking or h.lying():
			chance *= 0.5
		if harmless(d, true) or not Body.prob(chance):
			continue
		_hurt(h, em["part"], em["w"] * d["jostle_pain_mult"], d, em["sharp"])
		var pn := Body.pname(em["part"])
		if d["stealthy"]:
			Game.tell(h.e, "Something in your %s jostles and stings!" % pn, "bad")
		else:
			Game.tell(h.e, "[b]The %s embedded in your %s jostles and stings![/b]" % [em["name"], pn], "bad")

## tg fall_out
static func fall_out(h: CHealth, em: Dictionary) -> void:
	var d: Dictionary = em["data"]
	var pn := Body.pname(em["part"])
	if harmless(d):
		Game.visible_message(h.e.cell, "The %s falls off of %s's %s!" % [em["name"], h.e.display_name, pn], "warn")
	else:
		_hurt(h, em["part"], em["w"] * d["remove_pain_mult"], d, em["sharp"])
		Game.visible_message(h.e.cell, "[b]The %s falls out of %s's %s![/b]" % [em["name"], h.e.display_name, pn], "bad")
	remove(h, em, null)

## tg damaging_removal_effect: tearing it out hurts, and can wound (always sharp)
static func _damaging_removal(h: CHealth, em: Dictionary, mult: float) -> void:
	var d: Dictionary = em["data"]
	var sharp: String = em["sharp"] if em["sharp"] != "" else "edged"
	_hurt(h, em["part"], em["w"] * d["remove_pain_mult"] * mult, d, sharp, null, 0.0)
	var m: CMob = h.e.c(&"mob")
	if m and not h.knocked_out():
		m.do_emote("scream")

## tg remove_embedding: out it comes, into the remover's hands (DROPDEL shrapnel just vanishes)
static func remove(h: CHealth, em: Dictionary, to_hands: Entity) -> void:
	h.embedded.erase(em)
	Bus.mob_state_changed.emit(h.e)
	if em["dropdel"] or em["proto"] == "":
		return
	var it := Proto.spawn(em["proto"], h.e.cell)
	if Blood.can_bleed(h):
		Blood.stain_item(it, h)
	if to_hands and to_hands.has_c(&"inv"):
		to_hands.c(&"inv").put_in_hands(it)

static func _drop(h: CHealth, em: Dictionary) -> void:
	remove(h, em, null)

static func on_part(h: CHealth, part: String) -> Array:
	return h.embedded.filter(func(em): return em["part"] == part)

## tg rip_out: by hand, rip_time * w (quicker and gentler when someone else does it)
static func rip_out(user: Entity, target: Entity, em: Dictionary) -> void:
	var h: CHealth = target.c(&"health")
	var d: Dictionary = em["data"]
	var t: float = d["rip_time"] * em["w"]
	var mult := 1.0
	var pn := Body.pname(em["part"])
	if user != target:
		t *= RIPPING_OUT_HELP_TIME_MULTIPLIER
		mult *= RIPPING_OUT_HELP_DAMAGE_MULTIPLIER
		Game.visible_message(target.cell, "%s attempts to remove the %s from %s's %s!" % [user.display_name, em["name"], target.display_name, pn], "warn")
	else:
		Game.visible_message(target.cell, "%s attempts to remove the %s from their %s." % [user.display_name, em["name"], pn])
	DoAfter.start(user, target, t, func(ok):
		if not ok or not em in h.embedded:
			return
		Game.visible_message(target.cell, "%s successfully rips the %s %s of %s %s!" % [user.display_name, em["name"], "off" if harmless(d) else "out", "their" if user == target else target.display_name + "'s", pn], "warn")
		if not harmless(d):
			_damaging_removal(h, em, mult)
		remove(h, em, user)
	)

## tg try_pluck: tweezing it out with a hemostat (hurts) or wirecutters (safe but slow)
static func try_pluck(user: Entity, target: Entity, em: Dictionary, tool: Entity) -> void:
	var h: CHealth = target.c(&"health")
	var d: Dictionary = em["data"]
	var self_pluck := user == target
	var safe := tool.proto != "hemostat" or harmless(d)
	var t: float = d["rip_time"] * (em["w"] * 0.3)
	if self_pluck:
		t *= 1.5
	if safe:
		t *= 1.5
	var pn := Body.pname(em["part"])
	Game.visible_message(target.cell, "%s begins plucking the %s from %s %s with %s..." % [user.display_name, em["name"], "their" if self_pluck else target.display_name + "'s", pn, tool.the()], "warn")
	DoAfter.start(user, target, t, func(ok):
		if not ok or not em in h.embedded:
			Game.tell(user, "You fail to pluck the %s from %s %s." % [em["name"], "your" if self_pluck else target.display_name + "'s", pn], "warn")
			return
		if not safe:
			var tw: int = tool.c(&"item").w_class if tool.has_c(&"item") else 2
			_damaging_removal(h, em, minf(1.0 if self_pluck else RIPPING_OUT_HELP_DAMAGE_MULTIPLIER, 0.4 * tw))
		Game.tell(user, "You pluck the %s from %s %s%s" % [em["name"], "your" if self_pluck else target.display_name + "'s", pn, "." if safe else ", but it hurts like hell"], "info")
		remove(h, em, user)
	)

## tg carbon examine: "[He] has \a [embedded] embedded in [his] [part]!" (not the stealthy ones)
static func examine_lines(h: CHealth) -> Array:
	var out := []
	for em in h.embedded:
		if em["data"]["stealthy"]:
			continue
		out.append("[color=#ff5a4a][b]They have a %s %s their %s![/b][/color]" % [em["name"], "stuck to" if harmless(em["data"]) else "embedded in", Body.pname(em["part"])])
	return out

## tg health analyzer: every foreign object, stealthy or not
static func analyzer_line(h: CHealth) -> String:
	if h.embedded.is_empty():
		return ""
	var parts := []
	for em in h.embedded:
		parts.append("%s in the %s" % [em["name"], Body.pname(em["part"])])
	return "Foreign objects detected: %s. Remove by hand, or with a hemostat or wirecutters." % ", ".join(parts)

# ------------------------------------------------------------------ sources
## A thrown item hits someone (tg COMSIG_MOVABLE_IMPACT_ZONE -> try_embed). Returns true if
## it lodged (the item is used up: it's inside them now).
static func try_thrown(user: Entity, item: Entity, target: Entity, zone: String) -> bool:
	if not ITEM_EMBED.has(item.proto) or not target.has_c(&"health"):
		return false
	var h: CHealth = target.c(&"health")
	var d := data(ITEM_EMBED[item.proto])
	var speed: int = THROW_SPEED.get(item.proto, 2)
	var arm := Combat.armor_vs(target, zone, "bullet") # tg: the better of bullet and bomb (this game has no bomb armour)
	if not roll(h, d, zone, speed, arm):
		return false
	var it: CItem = item.c(&"item")
	Interact.detach(item)
	embed_into(h, Body.part_of(zone), item.display_name, item.proto, it.w_class, it.sharpness, d, it.throwforce, false, user)
	item.destroy()
	return true

## A bullet hits (tg try_embed_projectile): the round's shrapnel may lodge, less likely the
## further it flew (embed_falloff_tile).
static func try_projectile(round_id: String, target: Entity, zone: String, tiles: int, armor: float) -> bool:
	if not ROUND_EMBED.has(round_id) or not target.has_c(&"health"):
		return false
	var h: CHealth = target.c(&"health")
	if armor >= 100.0:
		return false
	var d := data(ROUND_EMBED[round_id])
	d["embed_chance"] = d["embed_chance"] + d.get("falloff", 0.0) * tiles
	if not roll(h, d, zone, 10, armor):
		return false
	var nm: String = CGadget.ROUNDS[round_id]["name"].replace(" round", " bullet").replace(" shell", "")
	embed_into(h, Body.part_of(zone), nm, "", 1, "pointy", d, 0.0, true)
	return true
