class_name BuildInfo extends RefCounted
## What build this is, for the debug menu: the date/time stamped into
## assets/data/build_info.json when the commit was made (tools/stamp_build.sh), and the
## commit hash read from the checkout's .git when running from source.

static func stamp() -> Dictionary:
	var f := FileAccess.open("res://assets/data/build_info.json", FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

## The checked-out commit (short hash) and branch, or "" when there's no .git (exports).
static func git_head() -> Array:
	var root := ProjectSettings.globalize_path("res://")
	var head := FileAccess.open(root.path_join(".git/HEAD"), FileAccess.READ)
	if head == null:
		return ["", ""]
	var h := head.get_as_text().strip_edges()
	if not h.begins_with("ref: "):
		return [h.substr(0, 7), "(detached)"]
	var ref := h.substr(5)
	var branch := ref.trim_prefix("refs/heads/")
	var rf := FileAccess.open(root.path_join(".git").path_join(ref), FileAccess.READ)
	if rf:
		return [rf.get_as_text().strip_edges().substr(0, 7), branch]
	var packed := FileAccess.open(root.path_join(".git/packed-refs"), FileAccess.READ)
	if packed:
		for line in packed.get_as_text().split("\n"):
			if line.ends_with(" " + ref):
				return [line.substr(0, 7), branch]
	return ["", branch]

static func line() -> String:
	var s := stamp()
	var g := git_head()
	var out := "Build: %s" % s.get("date", "unknown date")
	if s.get("title", "") != "":
		out += " — %s" % s["title"]
	if g[0] != "":
		out += "\nCommit %s on %s" % [g[0], g[1]]
	return out
