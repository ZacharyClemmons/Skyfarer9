class_name Perf
## Lightweight per-system frame timing, enabled with `--perf`. Systems wrap their tick with
## `var t := Perf.t0()` ... `Perf.add("name", t)`. Game._process calls Perf.frame() which
## prints ms/frame averages and worst single-frame spikes every few seconds.

static var on := false
static var acc := {}    # name -> usec this window
static var cur := {}    # name -> usec this frame
static var worst := {}  # name -> worst single frame usec this window
static var frames := 0
static var win_start := 0
static var worst_frame := 0
static var frame_t := 0

static func t0() -> int:
	return Time.get_ticks_usec() if on else 0

static func add(key: String, t: int) -> void:
	if not on:
		return
	cur[key] = cur.get(key, 0) + (Time.get_ticks_usec() - t)

static func frame(delta: float) -> void:
	if win_start == 0:
		win_start = Time.get_ticks_usec()
	frames += 1
	var total := 0
	for k in cur.keys():
		var v: int = cur[k]
		acc[k] = acc.get(k, 0) + v
		if v > worst.get(k, 0):
			worst[k] = v
		total += v
	cur.clear()
	if delta * 1e6 > worst_frame:
		worst_frame = int(delta * 1e6)
	if Time.get_ticks_usec() - win_start >= 5000000:
		report()

static func report() -> void:
	var n := maxi(frames, 1)
	var keys := acc.keys()
	keys.sort_custom(func(a, b): return acc[a] > acc[b])
	var s := "[perf] fps=%d frames=%d worstdt=%.1fms proc=%.2fms objs=%d res=%d nodes=%d orph=%d draws=%d |" % [
		Performance.get_monitor(Performance.TIME_FPS), frames, worst_frame / 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	for k in keys:
		s += " %s=%.2f/%.1f" % [k, acc[k] / 1000.0 / n, worst.get(k, 0) / 1000.0]
	print(s)
	acc.clear()
	worst.clear()
	frames = 0
	worst_frame = 0
	win_start = Time.get_ticks_usec()
