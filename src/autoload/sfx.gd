extends Node
## Procedural sound: every effect is synthesised at startup (no audio assets needed).
## Positional one-shots via a pool of AudioStreamPlayer2D, plus ambience loops
## (arctic wind outside, station hum inside, alarm when your area is on fire).

const RATE := 22050
const SfxUi := preload("res://src/autoload/sfx_ui.gd")
var streams := {}
var pool: Array = []
var wind: AudioStreamPlayer
var hum: AudioStreamPlayer
var alarm: AudioStreamPlayer
var master := 0.8
var _rng := RandomNumberGenerator.new()
var _ui_pool: Array = []
var _ui_last := {}
const _UI_GAPS := {"ui_hover": 50, "ui_tick": 30, "ui_click": 45, "ui_coin": 40, "ui_erase": 60, "ui_place": 45, "ui_launch": 800, "ui_stinger": 800}

func _ready() -> void:
	_rng.seed = 1337
	_build()
	_build_ambient()
	for i in 24:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 700.0
		p.attenuation = 1.6
		add_child(p)
		pool.append(p)
	wind = _loop_player("wind", -12.0)
	hum = _loop_player("hum_loop", -20.0)
	alarm = _loop_player("alarm", -14.0)
	# The lazily-built UI and body voices cost up to 185 ms each to synthesise in GDScript
	# (ui_launch, ui_stinger), which showed up as a hitch the first time a button was
	# clicked. Build them all on a worker thread instead, cheapest first.
	_warm = Thread.new()
	_warm.start(_prewarm)

var _warm: Thread
var _mtx := Mutex.new()

func _exit_tree() -> void:
	if _warm != null and _warm.is_started():
		_warm.wait_to_finish()

func _prewarm() -> void:
	var names: Array = []
	for n in SfxUi.NAMES:
		names.append(n)
	for base in ["scream", "gasp", "cough", "laugh", "sneeze", "sigh", "sniff", "snore", "cry", "whistle", "clap", "snap", "crack", "salute", "jump", "yawn", "groan"]:
		names.append(base + "_m")
		names.append(base + "_f")
	# the long ones first: they are the ones that hitch if they are built on demand,
	# while the short ones cost about a millisecond either way
	for heavy in ["ui_launch", "ui_stinger", "ui_purchase"]:
		names.erase(heavy)
		names.push_front(heavy)
	for n in names:
		_mtx.lock()
		var have := streams.has(n)
		_mtx.unlock()
		if have:
			continue
		var w: PackedFloat32Array
		if SfxUi.can_make(n):
			w = SfxUi.make(n)
		elif SfxVoice.can_make(n):
			w = SfxVoice.make(n)
		else:
			continue
		var st := _wav(w)
		_mtx.lock()
		if not streams.has(n):
			streams[n] = st
		_mtx.unlock()

func _loop_player(name: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _stream_of(name)
	p.volume_db = db
	add_child(p)
	return p

func play(name: String, cell: Vector2i, vol := 1.0, pitch := 1.0) -> void:
	if Game.player == null:
		return
	if not _have(name):
		if not SfxVoice.can_make(name):
			return
		_store(name, _wav(SfxVoice.make(name))) # voices are built on first use
	var pc := Game.player.cell
	if absi(pc.x - cell.x) > 16 or absi(pc.y - cell.y) > 12:
		return
	for p in pool:
		if not p.playing:
			p.stream = _stream_of(name)
			p.position = Vector2(cell.x * 32 + 16, cell.y * 32 + 16)
			p.volume_db = linear_to_db(clampf(vol * master, 0.01, 4.0))
			p.pitch_scale = _rng.randf_range(0.93, 1.07) * pitch
			p.play()
			return

const _UI_ALIAS := {"ui_ding": "ui_confirm", "ui_select": "ui_tick"}

func _have(name: String) -> bool:
	_mtx.lock()
	var h := streams.has(name)
	_mtx.unlock()
	return h

func _stream_of(name: String) -> AudioStream:
	_mtx.lock()
	var st: AudioStream = streams.get(name)
	_mtx.unlock()
	return st

func _store(name: String, st: AudioStream) -> void:
	_mtx.lock()
	if not streams.has(name):
		streams[name] = st
	_mtx.unlock()

## Non-positional one-shot (menus, the character setup room).
func play_ui(name: String, vol := 1.0, pitch := 1.0) -> void:
	name = _UI_ALIAS.get(name, name)
	if not _have(name):
		var w: PackedFloat32Array
		if SfxUi.can_make(name):
			w = SfxUi.make(name)
		elif SfxVoice.can_make(name):
			w = SfxVoice.make(name)
		else:
			return # unknown name: fail quietly
		_store(name, _wav(w))
	# per-name rate limiter so spam can't stack up and clip
	var now := Time.get_ticks_msec()
	var gap: int = int(_UI_GAPS.get(name, 35))
	if now - int(_ui_last.get(name, -100000)) < gap:
		return
	_ui_last[name] = now
	var p: AudioStreamPlayer = null
	for q in _ui_pool:
		if not q.playing:
			p = q
			break
	if p == null:
		if _ui_pool.size() >= 14:
			return
		p = AudioStreamPlayer.new()
		add_child(p)
		_ui_pool.append(p)
	p.stream = _stream_of(name)
	p.volume_db = linear_to_db(clampf(vol * master, 0.01, 4.0))
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.play()

## Called by the HUD each frame to steer ambience.
func update_ambience(outdoors: float, storm: float, alarm_on: bool, powered: bool) -> void:
	if not wind.playing:
		wind.play()
		hum.play()
	_ambient_life(outdoors, storm)
	var tsec := Time.get_ticks_msec() / 1000.0
	var gust := 1.0 + 0.22 * sin(tsec * 0.37) + 0.14 * sin(tsec * 0.91 + 1.7) + 0.08 * sin(tsec * 2.3)
	var wvol := (lerpf(0.08, 0.6, outdoors) + storm * 0.5) * gust
	wind.volume_db = linear_to_db(clampf(wvol * master, 0.001, 2.0))
	wind.pitch_scale = 1.0 + storm * 0.25
	hum.volume_db = linear_to_db(clampf((0.18 if powered else 0.0) * (1.0 - outdoors) * master, 0.0001, 1.0))
	if alarm_on and not alarm.playing:
		alarm.play()
	elif not alarm_on and alarm.playing:
		alarm.stop()

## Occasional timber / rope creaks and far-off gull-like whistles over the wind bed.
var _amb_next := 0
var _amb_players: Array = []
func _ambient_life(outdoors: float, storm: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _amb_next:
		return
	_amb_next = now + int(_rng.randf_range(2200, 7500))
	if _amb_players.is_empty():
		for i in 3:
			var ap := AudioStreamPlayer.new()
			add_child(ap)
			_amb_players.append(ap)
	var pick := _rng.randf()
	var nm := ""
	var db := -22.0
	if outdoors > 0.5 and storm < 0.4 and pick < 0.3:
		nm = "amb_gull"
		db = -26.0 - _rng.randf() * 8.0
	elif pick < 0.65:
		nm = "amb_creak"
		db = -24.0 + outdoors * 3.0
	else:
		nm = "amb_rope"
		db = -27.0
	if not _have(nm):
		return
	for ap in _amb_players:
		if not ap.playing:
			ap.stream = _stream_of(nm)
			ap.volume_db = db + linear_to_db(master)
			ap.pitch_scale = _rng.randf_range(0.85, 1.2)
			ap.play()
			return

func _build_ambient() -> void:
	var b := _buf(0.9)
	var ph := 0.0
	var y := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		ph += (95.0 + 55.0 * sin(t * 5.0) + 30.0 * t) / RATE
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		y += (saw - y) * 0.09
		b[i] = y * sin(t * PI) * (0.55 + 0.45 * sin(t * TAU * 17.0 + sin(t * 9.0))) * 0.9
	streams["amb_creak"] = _wav(b)
	b = _buf(0.5)
	ph = 0.0
	y = 0.0
	for i in b.size():
		var t := float(i) / b.size()
		ph += (240.0 + 70.0 * sin(t * 7.0)) / RATE
		var v := 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		y += (v - y) * 0.06
		b[i] = y * sin(t * PI) * (0.5 + 0.5 * sin(t * TAU * 31.0)) * 0.8
	streams["amb_rope"] = _wav(b)
	b = _buf(1.1)
	ph = 0.0
	for i in b.size():
		var t := float(i) / b.size()
		var seg := fmod(t * 3.0, 1.0)
		var f := 1500.0 + 700.0 * sin(seg * PI) * (1.0 - t * 0.5) + 30.0 * sin(t * 260.0)
		ph += f / RATE
		var env := sin(seg * PI) * sin(t * PI)
		b[i] = (sin(ph * TAU) + 0.3 * sin(ph * TAU * 2.0)) * env * 0.4
	streams["amb_gull"] = _wav(b)

# ------------------------------------------------------------------ synthesis
func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b

func _noise(b: PackedFloat32Array, amp: float, lp: float, env: Callable, start := 0, len := -1) -> void:
	var y := 0.0
	var n := b.size() if len < 0 else mini(len, b.size() - start)
	for i in n:
		var t := float(i) / n
		y += (_rng.randf_range(-1, 1) - y) * lp
		b[start + i] += y * amp * env.call(t)

func _tone(b: PackedFloat32Array, f0: float, f1: float, amp: float, env: Callable, shape := "sine", start := 0, len := -1) -> void:
	var ph := 0.0
	var n := b.size() if len < 0 else mini(len, b.size() - start)
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		ph += f / RATE
		var v := sin(ph * TAU)
		if shape == "square":
			v = 1.0 if v > 0 else -1.0
		elif shape == "saw":
			v = fmod(ph, 1.0) * 2.0 - 1.0
		b[start + i] += v * amp * env.call(t)

func _build() -> void:
	var dec := func(t): return pow(1.0 - t, 2.0)
	var dec_fast := func(t): return pow(1.0 - t, 5.0)
	var bell := func(t): return sin(t * PI)
	var flat := func(_t): return 1.0
	var b: PackedFloat32Array

	b = _buf(0.45)
	_noise(b, 0.5, 0.25, func(t): return sin(t * PI) * (1.0 - t * 0.5))
	_tone(b, 90, 60, 0.4, dec_fast, "sine", int(0.33 * RATE), int(0.12 * RATE))
	streams["door"] = _wav(b)

	b = _buf(0.35)
	_tone(b, 180, 180, 0.25, func(t): return 1.0 if fmod(t * 4.0, 1.0) < 0.6 else 0.0, "square")
	streams["deny"] = _wav(b)

	b = _buf(0.4)
	_noise(b, 0.6, 0.6, dec_fast, 0, int(0.05 * RATE))
	_tone(b, 420, 400, 0.3, dec)
	_tone(b, 710, 700, 0.18, dec)
	streams["locker"] = _wav(b)

	b = _buf(0.6)
	for k in 7:
		var st := int(_rng.randf_range(0, 0.35) * RATE)
		_noise(b, 0.35, 0.9, dec_fast, st, int(0.08 * RATE))
		_tone(b, _rng.randf_range(2500, 5000), _rng.randf_range(2500, 5000), 0.08, dec_fast, "sine", st, int(0.15 * RATE))
	streams["glass"] = _wav(b)
	# tg SFX_SHATTER: a whole pane going. A heavy crash, then shards raining on the floor.
	b = _buf(1.1)
	_noise(b, 0.9, 0.55, func(t): return pow(1.0 - t, 3.0), 0, int(0.18 * RATE))
	_noise(b, 0.5, 0.95, dec_fast, 0, int(0.05 * RATE))
	_tone(b, 210, 90, 0.45, dec_fast, "sine", 0, int(0.2 * RATE))
	for k in 22:
		var st := int(pow(_rng.randf(), 1.6) * 0.85 * RATE)
		var f := _rng.randf_range(2200, 6200)
		_noise(b, 0.22, 0.92, dec_fast, st, int(0.03 * RATE))
		_tone(b, f, f * 0.97, 0.1 * (1.0 - float(st) / (0.9 * RATE)), dec_fast, "sine", st, int(0.14 * RATE))
	streams["shatter"] = _wav(b)
	# tg glass_step.ogg: boots crunching over broken glass
	b = _buf(0.22)
	_noise(b, 0.45, 0.6, dec_fast, 0, int(0.05 * RATE))
	for k in 6:
		var st := int(_rng.randf_range(0.0, 0.12) * RATE)
		var f := _rng.randf_range(2600, 5200)
		_tone(b, f, f * 0.98, 0.07, dec_fast, "sine", st, int(0.07 * RATE))
		_noise(b, 0.12, 0.95, dec_fast, st, int(0.012 * RATE))
	streams["glass_step"] = _wav(b)
	# tg welder.ogg: a burning hiss (fire damage on a structure, welding a repair)
	b = _buf(0.6)
	_noise(b, 0.35, 0.7, func(t): return minf(t * 12.0, 1.0) * (1.0 - t) * (0.8 + 0.2 * sin(t * 140.0)))
	_tone(b, 3100, 2900, 0.04, bell)
	streams["welder"] = _wav(b)

	# tg genhit: knuckles on a wall, "tap tap". A bright click on top of a hollow knock,
	# kept above ~300 Hz so it carries on laptop speakers too.
	b = _buf(0.28)
	for k in 2:
		var st := int(k * 0.11 * RATE)
		_noise(b, 0.9, 0.95, dec_fast, st, int(0.008 * RATE))
		_tone(b, 1250, 900, 0.35, dec_fast, "sine", st, int(0.05 * RATE))
		_tone(b, 520, 380, 0.6, dec_fast, "sine", st, int(0.1 * RATE))
		_noise(b, 0.35, 0.4, dec_fast, st, int(0.05 * RATE))
	streams["wall_tap"] = _wav(b)
	# something solid hitting a wall: a thud and a short metal ring
	b = _buf(0.3)
	_noise(b, 0.6, 0.35, dec_fast, 0, int(0.06 * RATE))
	_tone(b, 150, 80, 0.55, dec_fast)
	_tone(b, 720, 700, 0.12, dec)
	_tone(b, 1130, 1100, 0.06, dec_fast)
	streams["wall_hit"] = _wav(b)
	# tg glassknock: two quick raps on a pane, glassy ring
	b = _buf(0.34)
	for k in 2:
		var st := int(k * 0.13 * RATE)
		_noise(b, 0.9, 0.97, dec_fast, st, int(0.008 * RATE))
		_tone(b, 780, 600, 0.5, dec_fast, "sine", st, int(0.09 * RATE))
		_tone(b, 2300, 2250, 0.22, dec_fast, "sine", st, int(0.16 * RATE))
		_tone(b, 3400, 3350, 0.08, dec_fast, "sine", st, int(0.12 * RATE))
	streams["glass_knock"] = _wav(b)
	# tg glassbash: a palm slammed on the pane, the glass shivers
	b = _buf(0.45)
	_noise(b, 0.6, 0.3, dec_fast, 0, int(0.08 * RATE))
	_tone(b, 170, 90, 0.5, dec_fast)
	_tone(b, 1400, 1350, 0.1, func(t): return (1.0 - t) * (0.6 + 0.4 * sin(t * 90.0)))
	_tone(b, 2100, 2050, 0.05, dec)
	streams["glass_bash"] = _wav(b)
	# tg glasshit: something hard on glass
	b = _buf(0.4)
	_noise(b, 0.5, 0.75, dec_fast, 0, int(0.03 * RATE))
	_tone(b, 300, 180, 0.35, dec_fast)
	_tone(b, 1900, 1850, 0.12, dec)
	_tone(b, 2900, 2850, 0.06, dec_fast)
	streams["glass_hit"] = _wav(b)
	# a grille rattling
	b = _buf(0.35)
	for k in 4:
		var st := int(k * 0.045 * RATE)
		_noise(b, 0.3 / (k + 1), 0.8, dec_fast, st, int(0.03 * RATE))
		_tone(b, 820 - k * 60, 800 - k * 60, 0.12 / (k + 1), dec_fast, "sine", st, int(0.12 * RATE))
	_tone(b, 180, 110, 0.3, dec_fast, "sine", 0, int(0.1 * RATE))
	streams["grille_hit"] = _wav(b)

	b = _buf(0.22)
	_tone(b, 500, 1400, 0.3, bell)
	streams["slip"] = _wav(b)

	b = _buf(0.5)
	_noise(b, 0.45, 0.3, func(t): return (1.0 - t) * min(1.0, t * 20.0))
	streams["spray"] = _wav(b)

	b = _buf(0.3)
	_tone(b, 880, 880, 0.2, dec, "square", 0, int(0.06 * RATE))
	_noise(b, 0.5, 0.15, dec_fast, int(0.15 * RATE), int(0.1 * RATE))
	streams["vend"] = _wav(b)

	b = _buf(0.8)
	_tone(b, 1320, 1320, 0.25, dec)
	_tone(b, 2640, 2640, 0.06, dec_fast)
	streams["ding"] = _wav(b)

	b = _buf(0.35)
	for k in 3:
		_noise(b, 0.3, 0.7, dec_fast, int(k * 0.1 * RATE), int(0.06 * RATE))
	streams["eat"] = _wav(b)

	b = _buf(0.4)
	_tone(b, 220, 120, 0.3, bell, "sine", 0, int(0.15 * RATE))
	_tone(b, 200, 110, 0.3, bell, "sine", int(0.2 * RATE), int(0.15 * RATE))
	streams["drink"] = _wav(b)

	b = _buf(0.03)
	_noise(b, 0.5, 0.9, dec_fast)
	streams["click"] = _wav(b)

	b = _buf(0.12)
	_noise(b, 0.25, 0.4, dec_fast)
	streams["pickup"] = _wav(b)

	b = _buf(0.15)
	_tone(b, 120, 70, 0.4, dec_fast)
	_noise(b, 0.2, 0.2, dec_fast)
	streams["drop"] = _wav(b)

	b = _buf(0.35)
	_tone(b, 60, 60, 0.25, dec, "square")
	_noise(b, 0.3, 0.8, dec)
	streams["stun"] = _wav(b)

	b = _buf(1.0)
	_tone(b, 120, 120, 0.12, bell)
	_tone(b, 240, 240, 0.05, bell)
	streams["hum"] = _wav(b)

	b = _buf(0.18)
	for k in 4:
		_noise(b, 0.4, 0.95, dec_fast, int(_rng.randf_range(0, 0.12) * RATE), int(0.03 * RATE))
	streams["spark"] = _wav(b)

	b = _buf(1.6)
	_noise(b, 0.9, 0.08, func(t): return pow(1.0 - t, 1.5) * min(1.0, t * 60.0))
	_tone(b, 55, 30, 0.6, dec)
	streams["explosion"] = _wav(b)

	b = _buf(0.18)
	_noise(b, 0.6, 0.2, dec_fast)
	_tone(b, 90, 50, 0.4, dec_fast)
	streams["punch"] = _wav(b)

	b = _buf(0.35)
	_noise(b, 0.95, 0.6, func(t): return pow(1.0 - t, 4.0))
	_tone(b, 140, 40, 0.5, dec_fast)
	streams["gunshot"] = _wav(b)
	b = _buf(0.2)
	_noise(b, 0.5, 0.5, dec_fast)
	_tone(b, 300, 200, 0.2, dec_fast)
	streams["hit"] = _wav(b)
	b = _buf(0.18)
	_noise(b, 0.3, 0.15, bell)
	streams["swing"] = _wav(b)

	b = _buf(0.3)
	for k in 5:
		_noise(b, 0.35, 0.5, dec_fast, int(k * 0.05 * RATE), int(0.05 * RATE))
	streams["dig"] = _wav(b)

	b = _buf(0.14)
	for k in 6:
		_noise(b, 0.16, 0.55, dec_fast, int(_rng.randf_range(0, 0.1) * RATE), int(0.025 * RATE))
	streams["step_snow"] = _wav(b)
	b = _buf(0.08)
	_noise(b, 0.12, 0.35, dec_fast)
	_tone(b, 160, 120, 0.08, dec_fast)
	streams["step_floor"] = _wav(b)

	b = _buf(0.2)
	_tone(b, 1800, 1800, 0.08, flat, "square", 0, int(0.04 * RATE))
	_tone(b, 2400, 2400, 0.08, flat, "square", int(0.07 * RATE), int(0.04 * RATE))
	streams["radio"] = _wav(b)

	b = _buf(1.6)
	_tone(b, 780, 780, 0.2, flat, "saw", 0, int(0.8 * RATE))
	_tone(b, 580, 580, 0.2, flat, "saw", int(0.8 * RATE), int(0.8 * RATE))
	streams["alarm"] = _wav(b, true)

	# mouse squeak: two quick high chirps
	b = _buf(0.18)
	_tone(b, 2600, 3400, 0.25, bell, "sine", 0, int(0.07 * RATE))
	_tone(b, 2900, 3600, 0.22, bell, "sine", int(0.09 * RATE), int(0.08 * RATE))
	streams["squeak"] = _wav(b)

	# liquid pour: gurgling low-passed noise with a wobble
	b = _buf(0.6)
	_noise(b, 0.35, 0.12, func(t): return sin(t * PI) * (0.6 + 0.4 * sin(t * TAU * 9.0)))
	streams["pour"] = _wav(b)

	# ratchet: a few sharp clicks
	b = _buf(0.3)
	for k in 4:
		_noise(b, 0.5, 0.9, dec_fast, int(k * 0.07 * RATE), int(0.025 * RATE))
	streams["ratchet"] = _wav(b)

	# shuttle / crawler engine rumble for the evacuation
	b = _buf(2.5)
	_noise(b, 0.6, 0.03, bell)
	_tone(b, 45, 70, 0.3, bell, "saw")
	streams["engine"] = _wav(b)

	# wind: slowly swelling filtered noise, loops seamlessly (amplitude uses full periods)
	b = _buf(6.0)
	var y := 0.0
	var y2 := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		var gust := 0.55 + 0.3 * sin(t * TAU * 2.0) + 0.15 * sin(t * TAU * 5.0 + 1.3)
		y += (_rng.randf_range(-1, 1) - y) * (0.04 + 0.03 * gust)
		y2 += (y - y2) * 0.2
		b[i] = y2 * 2.2 * gust
	streams["wind"] = _wav(b, true)

	b = _buf(3.0)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = 0.1 * sin(t * TAU * 60.0) + 0.05 * sin(t * TAU * 120.0) + 0.02 * sin(t * TAU * 180.0 + 0.5)
	streams["hum_loop"] = _wav(b, true)

	# --- character setup room ---
	# drone: low detuned pad with a slow swell and a breath of air. Every frequency fits a
	# whole number of cycles into the 8 s loop so it loops without a click.
	b = _buf(8.0)
	var ya := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var swell := 0.75 + 0.25 * sin(t * TAU * 0.125)
		var v := 0.16 * sin(t * TAU * 55.0) + 0.1 * sin(t * TAU * 55.25 + 0.7) + 0.07 * sin(t * TAU * 82.5)
		v += 0.035 * sin(t * TAU * 110.0 + sin(t * TAU * 0.25) * 2.0) + 0.02 * sin(t * TAU * 164.875)
		ya += (_rng.randf_range(-1, 1) - ya) * 0.02
		b[i] = (v + ya * 0.25) * swell
	streams["room_drone"] = _wav(b, true)

	b = _buf(0.22)
	_tone(b, 660, 660, 0.16, dec, "sine", 0, int(0.1 * RATE))
	_tone(b, 990, 990, 0.14, dec, "sine", int(0.07 * RATE), int(0.15 * RATE))
	streams["ui_select"] = _wav(b)

	b = _buf(0.9)
	for k in 6:
		_tone(b, 1800.0 + k * 310.0, 2100.0 + k * 290.0, 0.05, bell, "sine", int(k * 0.06 * RATE), int(0.5 * RATE))
	streams["shimmer"] = _wav(b)

	b = _buf(1.4)
	var yw := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		var lp := lerpf(0.02, 0.35, sin(t * PI))
		yw += (_rng.randf_range(-1, 1) - yw) * lp
		b[i] = yw * 0.9 * sin(t * PI)
	_tone(b, 90, 40, 0.3, dec)
	streams["whoosh"] = _wav(b)

	b = _buf(1.6)
	_tone(b, 110, 104, 0.3, bell)
	_tone(b, 165, 156, 0.18, bell)
	_tone(b, 220, 208, 0.08, bell)
	streams["uneasy"] = _wav(b)
