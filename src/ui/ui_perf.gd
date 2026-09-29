class_name UIPerf extends RefCounted
## --uiperf: cheap per-key microsecond accounting for UI code. Wrap a hot section with
##   var t := UIPerf.t0();  ...work...;  UIPerf.end("hud.status", t)
## and UIPerf.tick(delta) once a frame (the HUD does) prints a table every 5 s.
## With the flag off, t0() returns 0 and end() is a single branch.

static var on := OS.get_cmdline_user_args().has("--uiperf")
static var _us := {}
static var _n := {}
static var _acc := 0.0
static var _frames := 0
static var _last_frame := -1

static func t0() -> int:
	return Time.get_ticks_usec() if on else 0

static func end(key: String, t: int) -> void:
	if not on:
		return
	_us[key] = int(_us.get(key, 0)) + (Time.get_ticks_usec() - t)
	_n[key] = int(_n.get(key, 0)) + 1

static func tick(delta: float) -> void:
	if not on or Engine.get_process_frames() == _last_frame:
		return
	_last_frame = Engine.get_process_frames()
	_acc += delta
	_frames += 1
	if _acc < 5.0:
		return
	var keys := _us.keys()
	keys.sort_custom(func(a, b): return _us[a] > _us[b])
	var lines := ["UIPERF %.1fs %d frames  fps=%d process=%.2fms" % [_acc, _frames, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0]]
	for k in keys:
		lines.append("  %-28s %7.3f ms/frame  (%d calls)" % [k, float(_us[k]) / 1000.0 / _frames, _n[k]])
	print("\n".join(lines))
	_us.clear()
	_n.clear()
	_acc = 0.0
	_frames = 0
