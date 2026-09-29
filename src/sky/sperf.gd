class_name SPerf extends RefCounted
## Cheap section timer for the sky/ship layer, live only under `--sperf`.
## SPerf.t0() / SPerf.end("name", t0) accumulate; SPerf.frame(delta) prints once a second.

static var on := false
static var _acc := {}      # name -> [total_us, calls, max_us]
static var _clock := 0.0
static var _frames := 0
static var _worst_frame := 0.0
static var _hitches := 0
static var _proc_max := 0.0
static var _phys_max := 0.0

static func t0() -> int:
	return Time.get_ticks_usec() if on else 0

static func end(name: String, start: int) -> void:
	if not on:
		return
	var us := Time.get_ticks_usec() - start
	var a = _acc.get(name)
	if a == null:
		_acc[name] = [us, 1, us]
		return
	a[0] += us
	a[1] += 1
	if us > a[2]:
		a[2] = us

static func frame(delta: float) -> void:
	if not on:
		return
	_frames += 1
	_clock += delta
	_proc_max = maxf(_proc_max, Performance.get_monitor(Performance.TIME_PROCESS))
	_phys_max = maxf(_phys_max, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	_worst_frame = maxf(_worst_frame, delta)
	if delta > 0.034:
		_hitches += 1
	if _clock < 1.0:
		return
	var keys := _acc.keys()
	keys.sort()
	var parts := []
	for k in keys:
		var a: Array = _acc[k]
		parts.append("%s %.2fms/f (n%d max %.2f)" % [k, a[0] / 1000.0 / maxf(1.0, _frames), a[1], a[2] / 1000.0])
	print("SPERF fps=%.0f worst=%.1fms hitches=%d procmax=%.1fms physmax=%.1fms draws=%d | %s" % [_frames / _clock, _worst_frame * 1000.0, _hitches,
		_proc_max * 1000.0, _phys_max * 1000.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), " | ".join(parts)])
	_proc_max = 0.0
	_phys_max = 0.0
	_acc.clear()
	_clock = 0.0
	_frames = 0
	_worst_frame = 0.0
	_hitches = 0

## Frame-slice probes: nodes at fixed process priorities that attribute wall time between
## them, so the cost of systems we do not own is visible (`--sperf` only).
class Probe extends Node:
	var label := ""
	static var last := 0
	func _process(_d: float) -> void:
		var now := Time.get_ticks_usec()
		if label == "start":
			last = now
			return
		SPerf.end("~" + label, last)
		last = now

static func install(host: Node) -> void:
	if not on:
		return
	for p in [[-100, "start"], [-25, "input+pre"], [-15, "life"], [-5, "fleet"], [5, "default0"], [15, "view"], [25, "light"], [40, "post"]]:
		var pr := Probe.new()
		pr.label = p[1]
		pr.process_priority = p[0]
		host.add_child(pr)
