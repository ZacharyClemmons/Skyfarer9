class_name CSkillStation extends CDnaScanner
## Uses the scanner's enclosure/door rules, with TG's occupant-only chip controls.
var loaded: Entity
var working := ""
var finish_at := 0.0
var operation_chip: Entity
var operation_subject: Entity
func key() -> StringName: return &"skillstation"
func attackby(user: Entity, item: Entity) -> bool:
	if not item.has_c(&"skillchip"): return super.attackby(user, item)
	if item.c(&"skillchip").owner != null: return true
	if loaded or working != "":
		Game.tell(user, "The lectern already contains a card or is working.", "warn")
		return true
	Interact.detach(item)
	item.holder = e
	item.visible = false
	loaded = item
	return true
func close_machine(target: Entity = null) -> bool:
	var closed := super.close_machine(target)
	if closed and occupant == Game.player: Game.hud.open_window("skill_station", e)
	return closed
func attack_hand(user: Entity) -> bool:
	if occupant == user: Bus.ui_open_window.emit("skill_station", e)
	else: toggle_open(user)
	return true
func open_machine() -> bool:
	var opened := super.open_machine()
	if opened: cancel_operation()
	return opened
func cancel_operation() -> void:
	working = ""
	operation_chip = null
	operation_subject = null
func act(user: Entity, action: String, chip: Entity = null) -> bool:
	if user != occupant or state_open or not operational() or working != "": return false
	match action:
		"implant":
			if not is_instance_valid(loaded) or SkillChips.implant_error(user, loaded) != "": return false
			chip = loaded
		"remove":
			if not is_instance_valid(chip) or not chip in SkillChips.list_of(user) or chip.c(&"skillchip").ready > Game.time: return false
		"toggle":
			if not is_instance_valid(chip) or not chip in SkillChips.list_of(user): return false
			var error: String = chip.c(&"skillchip").toggle()
			if error != "": Game.tell(user, error, "warn")
			return error == ""
		"eject":
			if is_instance_valid(loaded):
				loaded.holder = null
				loaded.visible = true
				Game.drop_to_map(loaded, e.cell)
				loaded.place(e.cell)
				loaded = null
			return true
		_: return false
	working = action
	operation_chip = chip
	operation_subject = user
	finish_at = Game.time + 15.0
	return true
func tick(dt: float) -> void:
	super.tick(dt)
	if not is_instance_valid(loaded) or loaded.removed: loaded = null
	if working == "": return
	if not operational() or state_open or occupant != operation_subject or not is_instance_valid(operation_chip) or operation_chip.removed or (working == "implant" and operation_chip != loaded):
		cancel_operation()
		return
	if Game.time < finish_at: return
	var error := SkillChips.implant(occupant, operation_chip) if working == "implant" else SkillChips.remove(occupant, operation_chip)
	if error == "" and working == "implant": loaded = null
	Game.tell(occupant, "Operation complete." if error == "" else "Operation failed: " + error)
	cancel_operation()
func on_removed() -> void:
	cancel_operation()
	if is_instance_valid(loaded) and not loaded.removed:
		loaded.holder = null
		loaded.visible = true
		Game.drop_to_map(loaded, e.cell)
		loaded.place(e.cell)
	loaded = null
	super.on_removed()
