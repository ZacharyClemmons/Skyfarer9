class_name SfxVoice extends RefCounted
## Synthesised body sounds for the tg emotes that have audio (scream, gasp, cough, laugh,
## sneeze, sigh, sniff, snore, cry, whistle, clap, snap, knuckle crack, salute, jump).
## Voices are a glottal pulse train through formant resonators (a source-filter model),
## with a lower and a higher voice (tg picks male/female sounds by physique). Built the
## first time each is played, so they cost nothing at startup.

const RATE := 22050
## Vowel formants [Hz, bandwidth, gain]
const AH := [[800.0, 90.0, 1.0], [1200.0, 110.0, 0.55], [2500.0, 160.0, 0.25]]
const EH := [[560.0, 80.0, 1.0], [1700.0, 110.0, 0.5], [2500.0, 160.0, 0.25]]
const UH := [[450.0, 80.0, 1.0], [900.0, 100.0, 0.45], [2400.0, 160.0, 0.2]]
const OO := [[330.0, 70.0, 1.0], [870.0, 100.0, 0.35], [2300.0, 160.0, 0.15]]
const HUM := [[280.0, 60.0, 1.0], [1000.0, 120.0, 0.2], [2200.0, 200.0, 0.08]]

## Base pitch of each voice, and how far its formants sit up (shorter vocal tract).
const VOICES := {"m": {"f0": 1.0, "form": 1.0}, "f": {"f0": 1.75, "form": 1.15}}

static var _rng := RandomNumberGenerator.new()

## Names this can make: "<sound>_m" / "<sound>_f" for voices, plain names for the rest.
static func can_make(name: String) -> bool:
	var base := name.trim_suffix("_m").trim_suffix("_f")
	return base in ["scream", "gasp", "cough", "laugh", "sneeze", "sigh", "sniff", "snore", "cry", "whistle", "clap", "snap", "crack", "salute", "jump", "yawn", "groan"]

static func make(name: String) -> PackedFloat32Array:
	_rng.seed = hash(name)
	var v := "m"
	var base := name
	if name.ends_with("_m") or name.ends_with("_f"):
		v = name.right(1)
		base = name.left(name.length() - 2)
	var p: float = VOICES[v]["f0"]
	var fm: float = VOICES[v]["form"]
	var b: PackedFloat32Array
	match base:
		"scream":
			# a strained "aah": rising, then held with a ragged vibrato
			b = _voiced(1.05, func(t): return 150.0 * p * (1.0 + 0.55 * minf(t * 4.0, 1.0) - 0.2 * t) * (1.0 + 0.035 * sin(t * 38.0)),
				_shift(AH, fm * 1.08), func(t): return minf(t * 12.0, 1.0) * pow(1.0 - t, 0.6), 0.25, 0.03)
		"groan":
			b = _voiced(0.9, func(t): return 95.0 * p * (1.0 - 0.15 * t), _shift(UH, fm), func(t): return sin(t * PI), 0.2, 0.02)
		"gasp":
			# a sharp breath in: mostly air, a little voice at the end
			b = _breath(0.4, _shift(AH, fm), func(t): return minf(t * 8.0, 1.0) * pow(1.0 - t, 1.5), 0.9)
			_mix(b, _voiced(0.4, func(t): return 180.0 * p * (1.0 + 0.3 * t), _shift(AH, fm), func(t): return 0.25 * sin(t * PI), 0.6, 0.02))
		"cough":
			b = _buf(0.55)
			for k in 2:
				var s := int((0.03 + k * 0.26) * RATE)
				var burst := _breath(0.2, _shift(AH, fm * 0.9), func(t): return minf(t * 40.0, 1.0) * pow(1.0 - t, 2.5), 1.0)
				_mix(burst, _voiced(0.2, func(t): return 110.0 * p * (1.0 - 0.3 * t), _shift(AH, fm), func(t): return minf(t * 40.0, 1.0) * pow(1.0 - t, 3.0) * 0.8, 0.5, 0.05))
				_mix(b, burst, s)
		"laugh":
			b = _buf(0.95)
			for k in 5:
				var s2 := int(k * 0.17 * RATE)
				var syl := _breath(0.14, _shift(AH, fm), func(t): return 0.5 * minf(t * 30.0, 1.0) * pow(1.0 - t, 3.0), 0.8)
				var f0k := 170.0 * p * (1.0 - 0.06 * k)
				_mix(syl, _voiced(0.14, func(t): return f0k * (1.0 - 0.1 * t), _shift(AH, fm), func(t): return minf(t * 25.0, 1.0) * pow(1.0 - t, 1.5), 0.3, 0.02))
				_mix(b, syl, s2)
		"sneeze":
			# "ah-" (a rising breath in) then a hard "choo"
			b = _voiced(0.4, func(t): return 160.0 * p * (1.0 + 0.4 * t), _shift(AH, fm), func(t): return 0.5 * t, 0.5, 0.02)
			var choo := _hiss(0.28, 3200.0 * fm, func(t): return minf(t * 60.0, 1.0) * pow(1.0 - t, 2.0))
			_mix(choo, _voiced(0.28, func(t): return 190.0 * p * (1.0 - 0.3 * t), _shift(OO, fm), func(t): return minf(t * 40.0, 1.0) * pow(1.0 - t, 2.0) * 0.7, 0.3, 0.03))
			var out := _buf(0.7)
			_mix(out, b)
			_mix(out, choo, int(0.4 * RATE))
			b = out
		"sigh":
			b = _breath(0.95, _shift(AH, fm * 0.95), func(t): return sin(t * PI) * pow(1.0 - t, 0.5), 0.8)
			_mix(b, _voiced(0.95, func(t): return 140.0 * p * (1.0 - 0.35 * t), _shift(AH, fm), func(t): return 0.3 * sin(t * PI), 0.8, 0.02))
		"yawn":
			b = _voiced(1.3, func(t): return 150.0 * p * (1.0 + 0.3 * sin(t * PI) - 0.3 * t), _shift(AH, fm), func(t): return sin(t * PI), 0.6, 0.02)
		"sniff":
			b = _buf(0.45)
			for k in 2:
				_mix(b, _hiss(0.12, 2600.0, func(t): return minf(t * 30.0, 1.0) * pow(1.0 - t, 2.0) * 0.6), int(k * 0.2 * RATE))
		"snore":
			b = _breath(1.3, _shift(UH, 0.7), func(t): return sin(t * PI) * (0.6 + 0.4 * sin(t * TAU * 38.0)), 0.9)
			_mix(b, _voiced(1.3, func(t): return 48.0 * (1.0 + 0.1 * sin(t * 9.0)), _shift(UH, 0.8), func(t): return 0.6 * sin(t * PI), 0.4, 0.15))
		"cry":
			b = _buf(1.2)
			for k in 3:
				var f0c := 230.0 * p * (1.0 + 0.05 * k)
				_mix(b, _voiced(0.32, func(t): return f0c * (1.0 + 0.2 * sin(t * PI) - 0.25 * t) * (1.0 + 0.05 * sin(t * 60.0)), _shift(UH, fm), func(t): return sin(t * PI) * 0.8, 0.5, 0.04), int(k * 0.38 * RATE))
		"whistle":
			b = _buf(0.7)
			var ph := 0.0
			for i in b.size():
				var t := float(i) / b.size()
				ph += 1500.0 * (1.0 + 0.25 * t + 0.02 * sin(t * 40.0)) / RATE
				b[i] = sin(ph * TAU) * sin(t * PI) * 0.5 + (_rng.randf() - 0.5) * 0.03
		"clap":
			b = _hiss(0.12, 1800.0, func(t): return pow(1.0 - t, 6.0))
		"snap":
			b = _hiss(0.06, 3500.0, func(t): return pow(1.0 - t, 8.0))
		"crack":
			b = _buf(0.45)
			for k in 4:
				_mix(b, _hiss(0.03, 2400.0 + k * 300.0, func(t): return pow(1.0 - t, 10.0) * 0.8), int((0.02 + k * 0.1 + _rng.randf() * 0.03) * RATE))
		"salute":
			# a heel click
			b = _hiss(0.08, 1500.0, func(t): return pow(1.0 - t, 7.0))
			_mix(b, _tone(0.08, 120.0, func(t): return pow(1.0 - t, 5.0) * 0.5))
		"jump":
			# tg thudswoosh: a whoosh, then landing
			b = _buf(0.45)
			_mix(b, _breath(0.25, [[900.0, 400.0, 1.0]], func(t): return sin(t * PI) * 0.6, 1.0))
			_mix(b, _tone(0.15, 70.0, func(t): return pow(1.0 - t, 4.0) * 0.8), int(0.28 * RATE))
			_mix(b, _hiss(0.1, 600.0, func(t): return pow(1.0 - t, 5.0) * 0.5), int(0.28 * RATE))
	return _normalise(b, 0.9)

# ------------------------------------------------------------------ building blocks
static func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b

static func _shift(formants: Array, k: float) -> Array:
	var out := []
	for f in formants:
		out.append([f[0] * k, f[1] * k, f[2]])
	return out

## A voiced sound: glottal pulses at f0(t) (with jitter), plus some breath, through the
## formant resonators; env(t) shapes the loudness.
static func _voiced(sec: float, f0: Callable, formants: Array, env: Callable, breath: float, jitter: float) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var src := PackedFloat32Array()
	src.resize(n)
	var ph := 0.0
	var jit := 0.0
	for i in n:
		var t := float(i) / n
		if i % 200 == 0:
			jit = _rng.randf_range(-jitter, jitter)
		ph += f0.call(t) * (1.0 + jit) / RATE
		var p := fmod(ph, 1.0)
		# Rosenberg-style glottal pulse: open, close, then shut
		var g := 0.0
		if p < 0.4:
			g = 0.5 * (1.0 - cos(PI * p / 0.4))
		elif p < 0.56:
			g = cos(PI * (p - 0.4) / 0.32)
		src[i] = (g - 0.35 + breath * _rng.randf_range(-0.6, 0.6)) * env.call(t)
	return _formant(src, formants)

## Air through the vocal tract: noise shaped by the formants.
static func _breath(sec: float, formants: Array, env: Callable, amp: float) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var src := PackedFloat32Array()
	src.resize(n)
	for i in n:
		src[i] = _rng.randf_range(-1.0, 1.0) * env.call(float(i) / n) * amp
	return _formant(src, formants)

## Band-passed noise (claps, snaps, "ch" and "s" sounds).
static func _hiss(sec: float, centre: float, env: Callable) -> PackedFloat32Array:
	return _breath(sec, [[centre, centre * 0.6, 1.0]], env, 1.0)

static func _tone(sec: float, f: float, env: Callable) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		b[i] = sin(TAU * f * i / RATE * (1.0 - 0.4 * float(i) / n)) * env.call(float(i) / n)
	return b

## Parallel two-pole resonators.
static func _formant(src: PackedFloat32Array, formants: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(src.size())
	for f in formants:
		var r := exp(-PI * float(f[1]) / RATE)
		var c1 := 2.0 * r * cos(TAU * float(f[0]) / RATE)
		var c2 := -r * r
		var g: float = (1.0 - r) * float(f[2])
		var y1 := 0.0
		var y2 := 0.0
		for i in src.size():
			var y := g * src[i] + c1 * y1 + c2 * y2
			y2 = y1
			y1 = y
			out[i] += y
	return out

static func _mix(into: PackedFloat32Array, b: PackedFloat32Array, at := 0) -> void:
	for i in b.size():
		if at + i >= into.size():
			return
		into[at + i] += b[i]

static func _normalise(b: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in b.size():
		b[i] *= k
	# soften the very start and end
	var fade := mini(80, b.size() / 4)
	for i in fade:
		b[i] *= float(i) / fade
		b[b.size() - 1 - i] *= float(i) / fade
	return b
