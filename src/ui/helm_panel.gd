class_name HelmPanel extends Control
## The readout you get when you have the wheel.
##
## It exists because flying a ship you cannot read is indistinguishable from a ship that
## does not work. Everything the pilot has to decide is on here and nothing else is: what
## the engines are doing, which way the bow is coming round, whether you are going up or
## down, and how much fuel and lift you have left to be wrong with.
##
## Every bar shows an eased value rather than the raw one, so needles have weight; the
## throttle bar carries a tick for what the engines are really doing behind the order, the
## steam bar is the thing you watch while she comes on the boil, and alarms breathe.

const W := 332.0
const H := 200.0
## Screen axes, so the rose agrees with the view: north is up, east is right, and +y is
## down and therefore south. Everything that names a direction in this game uses these.
const SCREEN_DIR := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]

var helm: CHelm = null
var _t := 0.0
# what is drawn eases toward what is true, so nothing snaps
var _thr := 0.0
var _spd := 0.0
var _trim := 0.0
var _fuel := 0.0
var _lift := 0.0
var _stm := 0.0
var _engine := 0.0      # what the thrusters are actually doing, behind the order
var _steam_was := false
var _flash := 0.0       # seconds of "steam up" celebration left
var _fresh := true      # first frame after taking the wheel: snap, do not sweep from zero

func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	custom_minimum_size = Vector2(W, H)
	position = Vector2(-W * 0.5, -H - 118.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _ready() -> void:
	Bus.helm_changed.connect(_on_helm)

func _on_helm(_ship) -> void:
	_set_helm(Helm.of(Game.player))

func _set_helm(h: CHelm) -> void:
	var was := visible
	helm = h
	visible = helm != null
	_fresh = true
	if visible and not was:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	queue_redraw()

var _place_t := 0.0

## Sit just above the hands panel, the examine bar and the alert row, wherever those end up
## (a folded bag row or a scaled HUD changes their height).
func _place() -> void:
	var hud: HUD = Game.hud
	if hud == null or not hud.panels.has("hands"):
		return
	var hp: Control = hud.panels["hands"]
	var clear := maxf(hp.size.y, hp.get_combined_minimum_size().y) + 12.0 + 6.0 + 34.0 + 44.0
	offset_left = -W * 0.5
	offset_right = W * 0.5
	offset_bottom = -clear
	offset_top = offset_bottom - H

func _process(delta: float) -> void:
	_place_t -= delta
	if _place_t <= 0.0:
		_place_t = 0.25
		_place()
	# the pilot can be shaken off the wheel by anything; re-check rather than trust a signal
	var now := Helm.of(Game.player)
	if now != helm:
		_set_helm(now)
	if not visible:
		return
	_t += delta
	_ease(delta)
	queue_redraw()

func _ease(delta: float) -> void:
	var sh := helm.ship() if helm != null else null
	if sh == null:
		return
	var top := maxf(0.6, sh.top_speed())
	var b := sh.buoyancy()
	var steam := 0.0
	for bo in sh.boilers:
		if is_instance_valid(bo) and not bo.removed and bo.has_c(&"boiler"):
			steam = maxf(steam, bo.c(&"boiler").pressure / CBoiler.SAFE_PRESSURE)
	var eng := 0.0
	for th in sh.thrusters:
		if is_instance_valid(th) and not th.removed and th.has_c(&"thruster"):
			eng = maxf(eng, th.c(&"thruster").output())
	var tt: float = sh.throttle
	var ts := clampf(sh.speed() / top, 0.0, 1.0)
	var ttrim := clampf((b - 1.0) * 4.0, -1.0, 1.0)
	var tf := clampf(sh.fuel() / 120.0, 0.0, 1.0)
	var tl := clampf(b / 1.6, 0.0, 1.0)
	var tst := clampf(steam, 0.0, 1.4)
	if _fresh:
		_thr = tt
		_spd = ts
		_trim = ttrim
		_fuel = tf
		_lift = tl
		_stm = tst
		_engine = eng
		_steam_was = sh.steam_up()
		_fresh = false
		return
	# the throttle lever is quick; speed and trim are heavy things and move like it
	var kq := 1.0 - exp(-delta * 12.0)
	var km := 1.0 - exp(-delta * 5.0)
	_thr = lerpf(_thr, tt, kq)
	_engine = lerpf(_engine, eng, kq)
	_spd = lerpf(_spd, ts, km)
	_trim = lerpf(_trim, ttrim, km)
	_fuel = lerpf(_fuel, tf, km)
	_lift = lerpf(_lift, tl, km)
	_stm = lerpf(_stm, tst, 1.0 - exp(-delta * 4.0))
	var up := sh.steam_up()
	if up and not _steam_was:
		_flash = 1.6
		Sfx.play_ui("ui_ding", 0.5, 1.2)
	_steam_was = up
	_flash = maxf(0.0, _flash - delta)

func _draw() -> void:
	if helm == null:
		return
	var sh := helm.ship()
	if sh == null:
		return
	var f := UITheme.font
	draw_style_box(UITheme.panel_style(0.90), Rect2(Vector2.ZERO, Vector2(W, H)))
	draw_string(f, Vector2(12, 23), sh.ship_name, HORIZONTAL_ALIGNMENT_LEFT, W - 90, 18, UITheme.ACCENT)
	_compass(f, Vector2(W - 38, 30), sh)

	# --- throttle (with a tick for what the engines are actually doing) and sails or steam
	_bar(f, 40, "THR", _thr, Color("#e8a83a"), "%d%%" % int(sh.throttle * 100.0), _engine)
	if not sh.masts.is_empty():
		_bar(f, 62, "SAIL", sh.sails_set, Color("#8ad8a0"), "%d%%" % int(sh.sails_set * 100.0))
	else:
		# no canvas to show, so the row shows boiler pressure: the thing you wait on at start-up
		var hot := _stm > 1.0
		_bar(f, 62, "STM", clampf(_stm, 0.0, 1.0), Color("#ff6a4a") if hot else Color("#e8c87a"),
			"%d%%" % int(_stm * 100.0), -1.0, hot, CBoiler.LIFT_PRESSURE / CBoiler.SAFE_PRESSURE)

	# --- speed
	_bar(f, 84, "SPD", _spd, Color("#7fd4ff"), "%.1f kt" % sh.speed())

	# --- trim: a bar centred on level, so you can see at a glance which way you are going
	var b := sh.buoyancy()
	var trim := clampf((b - 1.0) * 4.0, -1.0, 1.0)
	_centre_bar(f, 106, "TRIM", _trim,
		"%s %.2f km" % ["climbing" if trim > 0.06 else ("sinking" if trim < -0.06 else "level"), sh.altitude])

	# --- fuel and lift
	var fuel_frac := clampf(sh.fuel() / 120.0, 0.0, 1.0)
	var low := fuel_frac <= 0.2
	_bar(f, 128, "FUEL", _fuel, Color("#e8645a") if low else Color("#c8883a"), "%.0f" % sh.fuel(), -1.0, low)
	_bar(f, 150, "LIFT", _lift, Color("#9ad0ff"), "%d%%" % int(b * 100.0), -1.0, false, 0.96 / 1.6, 1.14 / 1.6)

	# --- what is wrong, in order of how soon it will kill you
	var warn := ""
	if sh.breaches() > 0:
		warn = "HULL BREACHED"
	elif not sh.steam_up():
		warn = "no steam - light the boiler"
	elif sh.fuel() <= 0.5:
		warn = "bunkers dry"
	elif sh.turning > 0.0:
		warn = "coming about..."
	var y := H - 10.0
	if _flash > 0.0:
		var a := clampf(_flash / 0.6, 0.0, 1.0)
		draw_string(f, Vector2(12, y), "STEAM UP - ready to sail", HORIZONTAL_ALIGNMENT_LEFT, W - 24, 15,
			Color(0.55, 0.95, 0.65, a))
	elif warn != "":
		# alarms blink; the slower advisories just sit there
		var urgent := warn.begins_with("HULL") or warn.begins_with("bunkers")
		var pulse := 0.6 + 0.4 * sin(_t * (9.0 if urgent else 3.0))
		var col := Color("#ff8a5a") if urgent else Color("#e8c87a")
		draw_string(f, Vector2(12, y), warn, HORIZONTAL_ALIGNMENT_LEFT, W - 24, 15, Color(col.r, col.g, col.b, pulse))
	else:
		var wind: String = "%s from the %s" % [Game.sky.wind_name(), Game.sky._from(Game.sky.wind_dir_name())] if Game.sky != null else ""
		draw_string(f, Vector2(12, y), wind, HORIZONTAL_ALIGNMENT_LEFT, W - 24, 15, UITheme.DIM)

## A compass rose drawn in screen space: the ring is fixed with N at the top, the solid
## needle is the bow, the hollow one is where the rudder is set, and the thin line is the
## wind. Because the overhead camera never rotates, what this shows is literally the
## direction the bow points on your screen.
func _compass(f: Font, at: Vector2, sh: Airship) -> void:
	var r := 17.0
	draw_arc(at, r, 0.0, TAU, 28, Color(1, 1, 1, 0.22), 1.0)
	for i in 4:
		var v: Vector2 = SCREEN_DIR[i]
		draw_line(at + v * (r - 4.0), at + v * r, Color(1, 1, 1, 0.3), 1.0)
	draw_string(f, at + Vector2(-4, -r - 2), "N", HORIZONTAL_ALIGNMENT_LEFT, 12, 12, UITheme.DIM)
	# where the rudder is asking her to go
	if absf(wrapf(sh.wanted_angle - sh.angle, -PI, PI)) > 0.01:
		var hv := Vector2(cos(sh.wanted_angle), sin(sh.wanted_angle))
		draw_line(at, at + hv * (r - 2.0), Color(0.9, 0.8, 0.4, 0.55), 1.0)
	# the wind, so you can see whether the sails will do anything
	if Game.sky != null:
		var w: Vector2 = Game.sky.wind_vector()
		if w.length() > 0.05:
			var wn := w.normalized()
			draw_line(at - wn * (r - 3.0), at + wn * (r - 3.0), Color(0.6, 0.8, 1.0, 0.35), 1.0)
	# the bow (angle is already continuous, so the needle sweeps rather than snapping)
	var bow := Vector2(cos(sh.angle), sin(sh.angle))
	var side := Vector2(-bow.y, bow.x)
	var tip := at + bow * (r - 1.0)
	draw_colored_polygon(PackedVector2Array([tip, at + side * 5.0 - bow * 3.0,
		at - side * 5.0 - bow * 3.0]), UITheme.ACCENT)
	draw_string(f, at + Vector2(-22, r + 14), ["north", "east", "south", "west"][sh.facing],
		HORIZONTAL_ALIGNMENT_CENTER, 44, 13, UITheme.DIM)

## `marker` draws a tick for what the machinery is really doing behind an order; `warn`
## makes the fill breathe; `band_lo`/`band_hi` shade the good range.
func _bar(f: Font, y: float, label: String, v: float, col: Color, text: String, marker := -1.0,
		warn := false, band_lo := -1.0, band_hi := 1.0) -> void:
	draw_string(f, Vector2(12, y + 11), label, HORIZONTAL_ALIGNMENT_LEFT, 44, 14, UITheme.DIM)
	var x := 58.0
	var w := W - x - 118.0
	draw_rect(Rect2(x, y + 1, w, 11), Color(0, 0, 0, 0.45))
	if band_lo >= 0.0:
		draw_rect(Rect2(x + w * band_lo, y + 1, maxf(2.0, w * (band_hi - band_lo)), 11), Color(0.36, 0.78, 0.52, 0.2))
	var c := col
	if warn:
		c = c.lerp(Color(1.0, 0.9, 0.75), (0.5 + 0.5 * sin(_t * 9.0)) * 0.45)
	var fill := w * clampf(v, 0.0, 1.0)
	draw_rect(Rect2(x, y + 1, fill, 11), c)
	if v > 0.02:
		draw_rect(Rect2(x + fill - 2.0, y + 1, 2, 11), c.lightened(0.4))
	if marker >= 0.0:
		draw_rect(Rect2(x + w * clampf(marker, 0.0, 1.0) - 1.0, y, 2, 13), Color(1, 1, 1, 0.8))
	draw_string(f, Vector2(x + w + 8, y + 11), text, HORIZONTAL_ALIGNMENT_LEFT, 110, 14, UITheme.TEXT)

## A bar that grows either side of centre: up for climbing, down for sinking.
func _centre_bar(f: Font, y: float, label: String, v: float, text: String) -> void:
	draw_string(f, Vector2(12, y + 11), label, HORIZONTAL_ALIGNMENT_LEFT, 44, 14, UITheme.DIM)
	var x := 58.0
	var w := W - x - 118.0
	var mid := x + w * 0.5
	draw_rect(Rect2(x, y + 1, w, 11), Color(0, 0, 0, 0.45))
	var half := w * 0.5 * absf(v)
	var col := Color("#8ad8a0") if v > 0.0 else Color("#d88a8a")
	if absf(v) < 0.06:
		col = UITheme.DIM
		half = 1.5
	if v >= 0.0:
		draw_rect(Rect2(mid, y + 1, half, 11), col)
	else:
		draw_rect(Rect2(mid - half, y + 1, half, 11), col)
	draw_line(Vector2(mid, y), Vector2(mid, y + 13), Color(1, 1, 1, 0.4), 1.0)
	draw_string(f, Vector2(x + w + 8, y + 11), text, HORIZONTAL_ALIGNMENT_LEFT, 118, 14, UITheme.TEXT)
