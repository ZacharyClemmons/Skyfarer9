extends RefCounted
## Procedural UI voices: soft, short, warm (wood / brass / brass-bell) with rounded edges.
## Everything is built lazily by Sfx.play_ui through make(name).

const RATE := 22050
const NAMES := ["ui_hover", "ui_click", "ui_confirm", "ui_deny", "ui_open", "ui_close", "ui_tick", "ui_place",
	"ui_erase", "ui_purchase", "ui_launch", "ui_coin", "ui_stinger", "ui_whoosh", "ui_pop", "ui_toast"]

static var _rng := RandomNumberGenerator.new()

static func can_make(name: String) -> bool:
	return name in NAMES

static func make(name: String) -> PackedFloat32Array:
	_rng.seed = hash(name)
	var b := PackedFloat32Array()
	match name:
		"ui_hover":
			b = _buf(0.05)
			_note(b, 0.0, 0.05, 1900.0, 1800.0, 0.5, [1.0, 0.25], 0.004, 2.0)
			_norm(b, 0.10)
		"ui_click":
			b = _buf(0.10)
			_note(b, 0.0, 0.10, 340.0, 230.0, 0.8, [1.0, 0.3], 0.003, 2.5)
			_note(b, 0.0, 0.04, 1500.0, 1200.0, 0.25, [1.0], 0.002, 2.5)
			_norm(b, 0.30)
		"ui_confirm":
			b = _buf(0.34)
			_note(b, 0.0, 0.14, 523.0, 523.0, 0.7, [1.0, 0.4, 0.15], 0.008, 1.6)
			_note(b, 0.08, 0.26, 784.0, 784.0, 0.7, [1.0, 0.4, 0.15], 0.008, 1.8)
			_norm(b, 0.34)
		"ui_deny":
			b = _buf(0.24)
			_note(b, 0.0, 0.22, 150.0, 96.0, 0.9, [1.0, 0.5, 0.25], 0.006, 1.6)
			_noise(b, 0.0, 0.06, 0.25, 0.12, 2.0)
			_norm(b, 0.34)
		"ui_open":
			b = _buf(0.22)
			_noise(b, 0.0, 0.22, 0.6, 0.0, 1.0, 0.03, 0.30, true)
			_note(b, 0.0, 0.2, 380.0, 720.0, 0.3, [1.0, 0.2], 0.03, 1.4)
			_norm(b, 0.24)
		"ui_close":
			b = _buf(0.20)
			_noise(b, 0.0, 0.2, 0.6, 0.0, 1.0, 0.30, 0.03, true)
			_note(b, 0.0, 0.18, 640.0, 320.0, 0.3, [1.0, 0.2], 0.02, 1.8)
			_norm(b, 0.22)
		"ui_tick":
			b = _buf(0.05)
			_note(b, 0.0, 0.05, 1500.0, 1250.0, 0.6, [1.0, 0.2], 0.003, 2.5)
			_norm(b, 0.16)
		"ui_pop":
			b = _buf(0.12)
			_note(b, 0.0, 0.11, 300.0, 700.0, 0.8, [1.0, 0.3], 0.004, 2.5)
			_norm(b, 0.24)
		"ui_toast":
			b = _buf(0.40)
			_bell(b, 0.0, 988.0, 0.6, 0.30)
			_bell(b, 0.09, 1319.0, 0.5, 0.30)
			_norm(b, 0.22)
		"ui_place":
			b = _buf(0.22)
			_note(b, 0.0, 0.14, 190.0, 85.0, 0.9, [1.0, 0.4], 0.003, 2.6)
			_noise(b, 0.0, 0.05, 0.4, 0.25, 2.5)
			_bell(b, 0.03, 2350.0, 0.16, 0.16)
			_norm(b, 0.38)
		"ui_erase":
			b = _buf(0.24)
			var t0 := 0.0
			for k in 5:
				_noise(b, t0, 0.05, 0.5 - k * 0.05, 0.35 + _rng.randf() * 0.2, 1.6, 0.02, 0.03)
				t0 += 0.03 + _rng.randf() * 0.015
			_norm(b, 0.24)
		"ui_purchase":
			b = _buf(0.95)
			_bell(b, 0.0, 1319.0, 0.6, 0.45)
			_bell(b, 0.10, 1760.0, 0.6, 0.6)
			for k in 4:
				_bell(b, 0.28 + k * 0.07 + _rng.randf() * 0.02, 2400.0 + _rng.randf() * 900.0, 0.25, 0.14)
			_norm(b, 0.36)
		"ui_launch":
			b = _buf(2.2)
			_noise(b, 0.0, 1.5, 0.5, 0.0, 1.0, 0.02, 0.32, true)
			# brass swell chord (F2 C3 F3 A3) with a slow bloom
			for f in [87.3, 130.8, 174.6, 220.0]:
				_note(b, 0.25, 1.9, f, f * 1.01, 0.32, [1.0, 0.6, 0.35, 0.2], 0.55, 1.4)
			_note(b, 0.0, 1.4, 90.0, 320.0, 0.25, [1.0, 0.3], 0.3, 1.3)
			# steam hiss tail
			_noise(b, 1.0, 1.15, 0.28, 0.6, 1.5, 0.15, 0.4)
			_norm(b, 0.5)
		"ui_coin":
			b = _buf(0.36)
			_bell(b, 0.0, 1976.0, 0.6, 0.20)
			_bell(b, 0.06, 2637.0, 0.6, 0.28)
			_norm(b, 0.26)
		"ui_stinger":
			b = _buf(1.7)
			for k in 3:
				var f: float = [262.0, 330.0, 392.0][k]
				_note(b, k * 0.2, 0.5, f, f, 0.6, [1.0, 0.6, 0.4, 0.2], 0.03, 1.5)
			for f in [131.0, 196.0, 262.0, 330.0, 392.0]:
				_note(b, 0.6, 1.1, f, f, 0.4, [1.0, 0.5, 0.3, 0.15], 0.06, 1.3)
			_noise(b, 0.6, 0.5, 0.05, 0.1, 2.0, 0.1, 0.1)
			_norm(b, 0.42)
		"ui_whoosh":
			b = _buf(0.5)
			_noise(b, 0.0, 0.5, 0.6, 0.0, 1.0, 0.04, 0.30, true, 0.45)
			_norm(b, 0.24)
		_:
			b = _buf(0.02)
	_edges(b)
	return b

# ------------------------------------------------------------------ blocks
static func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b

## A soft tone: sliding pitch, harmonic stack, attack ramp and power-law decay.
static func _note(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, amp: float, harm: Array, attack: float, decay_pow: float) -> void:
	var s := int(start * RATE)
	var n := mini(int(dur * RATE), b.size() - s)
	var ph := 0.0
	var att := maxf(attack * RATE, 1.0)
	for i in n:
		var t := float(i) / maxf(n, 1)
		ph += lerpf(f0, f1, t) / RATE
		var v := 0.0
		for h in harm.size():
			v += sin(ph * TAU * (h + 1)) * float(harm[h])
		var env := minf(float(i) / att, 1.0) * pow(1.0 - t, decay_pow)
		b[s + i] += v * amp * env * 0.5

## Bell / ting: a sine with inharmonic partials and a fast exponential decay.
static func _bell(b: PackedFloat32Array, start: float, f: float, amp: float, dur: float) -> void:
	var s := int(start * RATE)
	var n := mini(int(dur * RATE), b.size() - s)
	for i in n:
		var t := float(i) / maxf(n, 1)
		var tt := float(i) / RATE
		var v := sin(TAU * f * tt) + 0.35 * sin(TAU * f * 2.76 * tt) * (1.0 - t) + 0.2 * sin(TAU * f * 5.4 * tt) * pow(1.0 - t, 3.0)
		b[s + i] += v * amp * minf(float(i) / 40.0, 1.0) * pow(1.0 - t, 2.2) * 0.5

## Low-passed noise. lp0/lp1 slide the filter (0..1 coefficient); swell = bell envelope.
static func _noise(b: PackedFloat32Array, start: float, dur: float, amp: float, lp0: float, decay_pow: float, lp_a := -1.0, lp_b := -1.0, swell := false, _unused := 0.0) -> void:
	var s := int(start * RATE)
	var n := mini(int(dur * RATE), b.size() - s)
	var y := 0.0
	var y2 := 0.0
	for i in n:
		var t := float(i) / maxf(n, 1)
		var lp := lp0 if lp_a < 0.0 else lerpf(lp_a, lp_b, t)
		lp = clampf(lp, 0.01, 0.9)
		y += (_rng.randf_range(-1.0, 1.0) - y) * lp
		y2 += (y - y2) * 0.5
		var env := sin(t * PI) if swell else pow(1.0 - t, decay_pow) * minf(float(i) / 30.0, 1.0)
		b[s + i] += y2 * amp * env * 1.6

static func _norm(b: PackedFloat32Array, peak: float) -> void:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var k := peak * 1.55 / m
	for i in b.size():
		b[i] *= k

## Fade both edges so nothing clicks; also soft-clip protection.
static func _edges(b: PackedFloat32Array) -> void:
	var fade := mini(int(0.004 * RATE), b.size() / 3)
	for i in b.size():
		b[i] = clampf(b[i], -0.95, 0.95)
	for i in fade:
		var k := float(i) / maxf(fade, 1)
		b[i] *= k
		b[b.size() - 1 - i] *= k
