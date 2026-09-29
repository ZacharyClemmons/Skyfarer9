class_name CSkillBrain extends Component
func key() -> StringName: return &"skillbrain"
func on_removed() -> void:
	for chip in e.get_meta("skillchips", []).duplicate():
		if is_instance_valid(chip) and not chip.removed: chip.destroy()
func examine(_user: Entity, lines: Array) -> void:
	lines.append("Contains %d implanted skillchips." % e.get_meta("skillchips", []).size())
