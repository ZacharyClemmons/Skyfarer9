class_name CReagents extends Component
## tg reagent containers (code/modules/reagents/reagent_containers) and machine holders.
##   beaker / bottle   open containers: pour into each other (transfer amount), drink (Z)
##   syringe           Z toggles draw / inject; on a person draws blood or injects 5 u
##   dropper           picks up and drops 1-5 u; on a person drips into their eyes / skin
##   pill              click yourself or someone to swallow it (goes in their blood)
##   patch             stuck on: touch reagents act at once, the rest soaks in
##   blood_pack        a bag of blood for an IV drip
##   dispenser         the chem dispenser (clicked with a beaker)
## Contents have a temperature; the chem heater changes it, and reactions with a minimum
## temperature only happen once it's warm enough.

var kind := "beaker"
var contents := {}
var volume := 50.0
var temp := Chem.ROOM_TEMP
var transfer := 10.0
var mode_inject := false # syringe: false = draw
var blood_type := "" # blood packs / drawn blood

func key() -> StringName:
	return &"reagents"

func setup(p: Dictionary) -> CReagents:
	kind = p.get("kind", kind)
	volume = p.get("volume", volume)
	contents = p.get("contents", {}).duplicate()
	transfer = p.get("transfer", {"syringe": 5.0, "dropper": 1.0, "bottle": 10.0}.get(kind, 10.0))
	blood_type = p.get("btype", "")
	if kind == "blood_pack" and contents.has("blood") and blood_type == "":
		blood_type = ["O-", "O+", "A+", "B+"][randi() % 4]
	return self

func on_added() -> void:
	_update_sprite()
	if blood_type != "" and kind == "blood_pack":
		e.display_name = "blood pack - %s" % blood_type

## Open containers you can pour, drink and splash from (tg: OPENCONTAINER).
func is_open() -> bool:
	return kind in ["beaker", "bottle", "bucket"]

func total() -> float:
	var t := 0.0
	for k in contents:
		t += contents[k]
	return t

func free_space() -> float:
	return maxf(0.0, volume - total())

func add(reagent: String, units: float, by: Entity = null) -> void:
	units = minf(units, free_space())
	if units <= 0:
		return
	contents[reagent] = contents.get(reagent, 0.0) + units
	_react(by)
	_update_sprite()

func _react(by: Entity) -> void:
	var fx := Chem.react(contents, temp)
	if not fx.is_empty():
		Chem.apply_effects(fx, e.root_cell(), by)
		# explosive mixes take the container with them
		for f in fx:
			if f["effect"] == "explosion" and f["amount"] >= 10.0 and not e.removed and e.has_c(&"item"):
				contents.clear()

## Remove `units` in proportion and return them as a dict.
func take(units: float) -> Dictionary:
	var t := total()
	var out := {}
	if t <= 0.0:
		return out
	var frac := minf(1.0, units / t)
	for k in contents.keys():
		var u: float = contents[k] * frac
		contents[k] -= u
		out[k] = u
		if contents[k] < 0.01:
			contents.erase(k)
	_update_sprite()
	return out

func put(stuff: Dictionary, by: Entity = null) -> void:
	for k in stuff:
		contents[k] = contents.get(k, 0.0) + stuff[k]
	var over := total() - volume
	if over > 0.01:
		take(over)
	_react(by)
	_update_sprite()

func pour_into(other: CReagents, units: float, by: Entity) -> float:
	var n := minf(units, minf(total(), other.free_space()))
	if n <= 0.0:
		return 0.0
	if blood_type != "" and other.blood_type == "":
		other.blood_type = blood_type
	other.temp = (other.temp * other.total() + temp * n) / maxf(0.01, other.total() + n)
	other.put(take(n), by)
	return n

func _update_sprite() -> void:
	var full := total() > 0.5
	match kind:
		"beaker": e.set_sprite("items", "beaker_filled" if full else "beaker")
		"bottle": e.set_sprite("items", "bottle_filled" if full else "bottle")
		"blood_pack": e.set_sprite("items", "blood_pack_full" if full else "blood_pack")
	if e.spr and kind in ["pill", "patch"] and full:
		e.spr.modulate = Chem.color_of(contents).lerp(Color.WHITE, 0.35)

func drink(mob: Entity) -> void:
	var t := total()
	if t <= 0:
		return
	var sip := minf(10.0, t)
	Chem.affect_mob(take(sip), mob, 1.0, blood_type)

# ------------------------------------------------------------------ in hand
func attack_self(user: Entity) -> bool:
	match kind:
		"beaker", "bottle", "bucket":
			if total() > 0:
				Game.visible_message(user.cell, "%s drinks from %s." % [user.display_name, e.the()])
				drink(user)
				return true
		"syringe":
			mode_inject = not mode_inject
			Game.tell(user, "You set %s to %s." % [e.the(), "inject" if mode_inject else "draw"])
			return true
		"dropper":
			transfer = {1.0: 3.0, 3.0: 5.0, 5.0: 1.0}.get(transfer, 1.0)
			Game.tell(user, "%s will now transfer %d units." % [e.the().capitalize(), int(transfer)])
			return true
		"pill":
			swallow(user, user)
			return true
		"patch":
			stick(user, user)
			return true
		"medipen":
			return use_on_mob(user, user)
	return false

func attack_hand(_user: Entity) -> bool:
	if kind == "dispenser":
		Bus.ui_open_window.emit("chem", e)
		return true
	return false

## tg reagent_containers/attackby: pour between containers.
func attackby(user: Entity, item: Entity) -> bool:
	var mi: CItem = item.c(&"item")
	if mi and mi.tool == "mop" and is_open():
		if total() < 1.0:
			Game.tell(user, "%s is empty!" % e.the().capitalize(), "warn")
			return true
		var soak := minf(10.0, total())
		take(soak)
		item.tags["wet"] = int(item.tags.get("wet", 0)) + int(soak)
		Sfx.play("pour", user.cell, 0.4)
		Game.tell(user, "You wet %s in %s." % [item.the(), e.the()])
		return true
	var r: CReagents = item.c(&"reagents")
	if kind == "dispenser":
		if r and r.is_open():
			Bus.ui_open_window.emit("chem", e)
			return true
		return false
	if r == null:
		return false
	match r.kind:
		"beaker", "bottle", "bucket", "blood_pack":
			if is_open():
				if r.total() <= 0.0:
					Game.tell(user, "%s is empty." % item.the().capitalize(), "warn")
					return true
				var n := r.pour_into(self, r.transfer, user)
				Game.tell(user, "You transfer %d units of the solution to %s." % [int(n), e.the()] if n > 0.0 else "%s is full." % e.the().capitalize())
				Sfx.play("pour", user.cell, 0.4)
				return true
		"syringe", "dropper":
			if is_open() or kind == "blood_pack":
				if r.kind == "syringe" and r.mode_inject or r.kind == "dropper" and r.total() > 0.0:
					var n2 := r.pour_into(self, r.transfer, user)
					Game.tell(user, "You transfer %d units into %s." % [int(n2), e.the()])
				else:
					var n3 := pour_into(r, r.transfer, user)
					Game.tell(user, "You fill %s with %d units." % [item.the(), int(n3)])
				return true
	return false

# ------------------------------------------------------------------ on people
## Called from Interact before the generic item-on-mob path. True = handled.
func use_on_mob(user: Entity, target: Entity) -> bool:
	var h: CHealth = target.c(&"health")
	if h == null:
		return false
	match kind:
		"pill":
			swallow(user, target)
			return true
		"patch":
			stick(user, target)
			return true
		"syringe":
			_syringe(user, target)
			return true
		"medipen":
			# tg hypospray/medipen: instant, through clothing
			if total() <= 0.0:
				Game.tell(user, "%s is empty." % e.the().capitalize(), "warn")
				return true
			Chem.affect_mob(take(total()), target, 1.0)
			Sfx.play("click", target.cell, 0.5)
			Game.visible_message(target.cell, "%s injects %s with %s." % [user.display_name, "themselves" if user == target else target.display_name, e.the()])
			e.display_name = "used " + e.display_name if not e.display_name.begins_with("used") else e.display_name
			return true
		"dropper":
			if total() <= 0.0:
				return false
			var got := take(transfer)
			Chem.touch_mob(got, target, 1.0)
			Game.visible_message(target.cell, "%s squirts something into %s's eyes." % [user.display_name, target.display_name] if user != target else "%s squirts something into their eyes." % user.display_name, "warn")
			return true
		"beaker", "bottle", "bucket":
			if user.c(&"mob").combat and total() > 0.0:
				# tg: splash it on them
				Game.visible_message(target.cell, "%s splashes the contents of %s onto %s!" % [user.display_name, e.the(), target.display_name], "bad")
				Chem.touch_mob(take(total()), target, 0.5)
				return true
			if total() > 0.0 and target != user:
				Game.visible_message(target.cell, "%s is trying to feed %s from %s." % [user.display_name, target.display_name, e.the()], "warn")
				DoAfter.start(user, target, 3.0, func(ok):
					if ok and is_instance_valid(e) and not e.removed:
						drink(target)
						Game.visible_message(target.cell, "%s feeds %s from %s." % [user.display_name, target.display_name, e.the()])
				)
				return true
	return false

func swallow(user: Entity, target: Entity) -> void:
	var go := func():
		Chem.affect_mob(contents, target, 1.0)
		Game.visible_message(target.cell, "%s swallows %s." % [target.display_name, e.the()] if user == target else "%s forces %s to swallow %s." % [user.display_name, target.display_name, e.the()])
		Sfx.play("eat", target.cell, 0.5)
		contents.clear()
		Interact.detach(e)
		e.destroy()
	if user == target:
		go.call()
		return
	Game.visible_message(target.cell, "%s attempts to force %s to swallow %s." % [user.display_name, target.display_name, e.the()], "warn")
	DoAfter.start(user, target, 3.0, func(ok):
		if ok and is_instance_valid(e) and not e.removed:
			go.call())

func stick(user: Entity, target: Entity) -> void:
	var go := func():
		Chem.touch_mob(contents, target, 1.0)
		Game.visible_message(target.cell, "%s applies %s to %s." % [user.display_name, e.the(), "themselves" if user == target else target.display_name])
		contents.clear()
		Interact.detach(e)
		e.destroy()
	if user == target:
		go.call()
		return
	DoAfter.start(user, target, 2.0, func(ok):
		if ok and is_instance_valid(e) and not e.removed:
			go.call())

## tg syringe: draw blood (or chems) out of someone, or inject into them.
func _syringe(user: Entity, target: Entity) -> void:
	var h: CHealth = target.c(&"health")
	var t := 0.5 if user == target else 3.0
	if mode_inject:
		if total() <= 0.0:
			Game.tell(user, "%s is empty." % e.the().capitalize(), "warn")
			return
		if user != target:
			Game.visible_message(target.cell, "%s is trying to inject %s!" % [user.display_name, target.display_name], "warn")
		DoAfter.start(user, target, t, func(ok):
			if ok and is_instance_valid(e) and not e.removed:
				var got := take(transfer)
				Chem.affect_mob(got, target, 1.0, blood_type)
				Game.visible_message(target.cell, "%s injects %s with %s." % [user.display_name, "themselves" if user == target else target.display_name, e.the()], "warn" if user != target else "info")
				if user != target:
					Bus.stimulus.emit({"type": "assault", "actor": user, "target": target, "cell": target.cell, "loud": 1.0, "illegal": false})
		)
		return
	if free_space() <= 0.0:
		Game.tell(user, "%s is full." % e.the().capitalize(), "warn")
		return
	Game.visible_message(target.cell, "%s is trying to take a blood sample from %s." % [user.display_name, target.display_name], "warn")
	DoAfter.start(user, target, t, func(ok):
		if ok and is_instance_valid(e) and not e.removed and h.blood_volume > 0.0:
			var n := minf(transfer, free_space())
			h.blood_volume -= n
			contents["blood"] = contents.get("blood", 0.0) + n
			blood_type = h.blood_type
			_update_sprite()
			Game.visible_message(target.cell, "%s takes a blood sample from %s." % [user.display_name, target.display_name])
	)

func examine(_user: Entity, lines: Array) -> void:
	if kind == "dispenser":
		return
	if contents.is_empty():
		lines.append("It is empty.")
	else:
		lines.append("It contains: %s." % Chem.describe(contents))
		if absf(temp - Chem.ROOM_TEMP) > 10.0:
			lines.append("It's %s (%d K)." % ["warm" if temp > Chem.ROOM_TEMP else "cold", int(temp)])
	if blood_type != "":
		lines.append("The label says the blood type is %s." % blood_type)
	if kind == "syringe":
		lines.append("It's set to %s." % ("inject" if mode_inject else "draw"))

func ai_tags(out: Dictionary) -> void:
	out["chem_" + kind] = true
