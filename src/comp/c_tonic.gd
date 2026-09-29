class_name CTonic extends Component
## A draught you drink for a named effect and a known duration.
##
## Tonics are the distiller's output and the reason Foraging and Distilling are worth
## levelling. Every one of them has a cost written into it — the lifter's tonic leaves
## you exhausted, the thin-air draught leaves you gasping — because a buff with no bill
## at the end of it is just a number, and a bill you can plan around is a decision.

var effect := ""
var dur := 180.0
var strength := 1.0

func key() -> StringName:
	return &"tonic"

func setup(p: Dictionary) -> CTonic:
	effect = String(p.get("effect", ""))
	dur = float(p.get("dur", 180.0))
	strength = float(p.get("strength", 1.0))
	return self

const EFFECTS := {
	"strength": {"buff": "carry", "value": 1.0, "after": "You ache all over.", "cost": ["slow", 0.35, 90.0]},
	"speed": {"buff": "speed", "value": 0.55, "after": "Your legs go to water.", "cost": ["slow", 0.5, 60.0]},
	"learning": {"buff": "xp", "value": 1.45, "after": "The edges come back.", "cost": []},
	"armor": {"buff": "armor", "value": 12.0, "after": "Feeling comes back, all at once.", "cost": []},
	"altitude": {"buff": "altitude", "value": 1.0, "after": "You are suddenly very short of breath.", "cost": ["slow", 0.4, 45.0]},
}

func examine(_user: Entity, lines: Array) -> void:
	var d: Dictionary = EFFECTS.get(effect, {})
	if d.is_empty():
		return
	var b := String(d["buff"])
	lines.append("[color=%s]%s[/color] for %d seconds." % [
		String(SkyBuffs.COLORS.get(b, "#dbe8f4")), String(SkyBuffs.NAMES.get(b, b)).capitalize(), int(dur)])
	var cost: Array = d.get("cost", [])
	if not cost.is_empty():
		lines.append("[color=#e8a83a]And then %s for %d seconds.[/color]" % [
			String(SkyBuffs.NAMES.get(String(cost[0]), "tired")), int(cost[2])])

func attack_self(user: Entity) -> bool:
	return drink(user)

func drink(user: Entity) -> bool:
	var d: Dictionary = EFFECTS.get(effect, {})
	if d.is_empty():
		return false
	# skill makes your own brews last longer: a distiller knows how much to take
	var mine := 1.0 + Skills.frac(user, "distilling") * 0.5
	SkyBuffs.apply(user, String(d["buff"]), float(d["value"]) * strength, dur * mine, "tonic")
	Game.visible_message(user.root_cell(), "%s drains %s." % [user.display_name.capitalize(), e.the()], "emote")
	Sfx.play("drink", user.root_cell(), 0.6)
	Skills.add_xp(user, "distilling", 6.0)
	var cost: Array = d.get("cost", [])
	if not cost.is_empty():
		# the bill comes due exactly when the tonic runs out
		var tree: SceneTree = Game.hud.get_tree() if Game.hud != null else null
		if tree != null:
			var t: SceneTreeTimer = tree.create_timer(dur * mine)
			var after := String(d.get("after", ""))
			t.timeout.connect(func():
				if not is_instance_valid(user) or user.removed:
					return
				SkyBuffs.apply(user, String(cost[0]), float(cost[1]), float(cost[2]), "hangover")
				if after != "":
					Game.tell(user, "[color=#e8a83a]%s[/color]" % after, "warn"))
	e.destroy()
	return true
