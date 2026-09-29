class_name SecurityRecords extends RefCounted
## Crew records: who is wanted and why. Security NPCs set warrants from crimes they
## witness or have reported to them; the records console exposes them.

static var wanted := {} # entity id -> {id, name, crime, t}
static var brig_until := {} # entity id -> release time
static var escorting := {} # prisoner id -> officer id: being taken to the crawler brig (doors let them through)
static var status := {} # entity id -> tg criminal status (WANTED_* in tg's security records)

## tg /datum/record/crew wanted_status
const STATUSES := ["None", "Arrest", "Search", "Monitor", "Incarcerated", "Paroled", "Discharged", "Suspected"]
const STATUS_COLORS := {"None": "#8a9cb0", "Arrest": "#ff5a4a", "Search": "#ffb84a", "Monitor": "#e8d84a", "Incarcerated": "#d88a4a", "Paroled": "#6ab8e8", "Discharged": "#6ae88a", "Suspected": "#e8a84a"}

static func status_of(id: int) -> String:
	if wanted.has(id):
		return "Arrest"
	return status.get(id, "None")

## The security records console: setting Arrest makes them wanted (officers go after
## them); anything else clears the warrant.
static func set_status(target: Entity, st: String, by: Entity) -> void:
	if target == null or not st in STATUSES:
		return
	if st == "Arrest":
		status.erase(target.id)
		if not wanted.has(target.id):
			set_wanted(target, "set to arrest by %s" % (by.display_name if by else "the Watch"), by)
		return
	wanted.erase(target.id)
	status[target.id] = st
	StationAlerts.radio_system("Watch Records", "Security", "%s set %s's status to %s." % [by.display_name if by else "the Watch", target.display_name, st.to_upper()], {"type": "status", "key": "status:%d" % target.id, "subject": target.id, "cell": target.root_cell(), "severity": 0})

static func set_wanted(target: Entity, crime: String, by: Entity) -> void:
	if target == null or target.removed:
		return
	if wanted.has(target.id):
		return
	wanted[target.id] = {"id": target.id, "name": target.display_name, "crime": crime, "t": Game.time}
	var who := by.display_name if by else "the Watch"
	StationAlerts.radio_system("Watch Records", "Security", "%s set %s to WANTED: %s." % [who, target.display_name, crime], {"type": "wanted", "key": "wanted:%d" % target.id, "subject": target.id, "cell": target.root_cell(), "severity": 2, "data": {"crime": crime}})
	Bus.chronicle.emit("%s was declared wanted for %s." % [target.display_name, crime], 2)

static func clear(target_id: int) -> void:
	wanted.erase(target_id)

static func is_wanted(id: int) -> bool:
	return wanted.has(id)
