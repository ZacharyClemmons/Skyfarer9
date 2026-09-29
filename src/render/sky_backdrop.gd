class_name SkyBackdrop extends CanvasLayer
## What is behind everything: the sky itself.
##
## Every tile of this world that is not an island is open air, and a tiled dark-blue
## sprite says nothing about it. This says all of it at once — the time of day, how far
## down "down" goes, which way the wind is blowing, and whether you are about to fly into
## a thunderhead — on one full-screen quad behind the terrain.
##
## It sits on a CanvasLayer rather than in world space so it never has to be as large as
## the region, and takes the camera position as a uniform instead, which is also what
## gives the cloud decks their parallax: three sheets drifting against you at different
## rates is the only thing telling a player that a hull pinned to the middle of the
## screen is moving at twelve knots.

var rect: ColorRect
var sub: SubViewport
var shown: TextureRect
var _sub_size := Vector2i(960, 540)
var mat: ShaderMaterial
var _t := 0.0
var flash := 0.0
var distant: DistantLife
var grade_rect: ColorRect
var grade_mat: ShaderMaterial

func _init() -> void:
	layer = -100
	follow_viewport_enabled = false
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://src/render/sky.gdshader")
	rect.material = mat
	# The sky is smooth, low-contrast and posterised, so it is shaded at half resolution
	# in its own viewport and scaled up: a quarter of the fragment work for the same look.
	sub = SubViewport.new()
	sub.size = Vector2i(960, 540)
	sub.disable_3d = true
	sub.transparent_bg = false
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.add_child(rect)
	add_child(sub)
	shown = TextureRect.new()
	shown.set_anchors_preset(Control.PRESET_FULL_RECT)
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_SCALE
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shown.texture = sub.get_texture()
	add_child(shown)
	# things that live in the far sky: skywhales and distant hulls, in screen space
	distant = DistantLife.new()
	add_child(distant)

## The warm grade and the soft vignette over the whole world, under the HUD.
const GRADE := """
shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform float warmth = 0.0;
uniform vec3 warm_col = vec3(1.0, 0.78, 0.5);
uniform vec2 sun_uv = vec2(0.5, 0.3);
uniform float vig = 0.20;
uniform float night = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	float d = length((uv - sun_uv) * vec2(1.6, 1.0));
	float near_sun = smoothstep(1.3, 0.05, d);
	float a = warmth * (0.045 + 0.09 * near_sun);
	vec3 c = warm_col;
	vec2 vc = uv - 0.5;
	float v = smoothstep(0.18, 0.62, length(vc * vec2(1.0, 1.15)));
	vec3 shade = mix(vec3(0.04, 0.05, 0.10), vec3(0.03, 0.03, 0.09), night);
	float av = v * (vig + night * 0.12);
	float ao = a + av * (1.0 - a);
	vec3 rgb = (c * a + shade * av * (1.0 - a)) / max(ao, 0.0001);
	COLOR = vec4(rgb, ao);
}
"""

func _ready() -> void:
	if Game.view != null:
		var cb := CloudBanks.new()
		cb.name = "CloudBanks"
		Game.view.add_child(cb)
		var pl := PortLife.new()
		pl.name = "PortLife"
		Game.view.add_child(pl)
	var gl := CanvasLayer.new()
	gl.layer = 2
	add_child(gl)
	grade_rect = ColorRect.new()
	grade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	grade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GRADE
	grade_mat.shader = sh
	grade_rect.material = grade_mat
	gl.add_child(grade_rect)

func _process(delta: float) -> void:
	if Game.view == null or Game.view.camera == null:
		return
	_t += delta
	# keep the half-res target matched to the window (real pixels, not stretched units)
	var want := Vector2i(maxi(320, DisplayServer.window_get_size().x / 2), maxi(180, DisplayServer.window_get_size().y / 2))
	if want != _sub_size:
		_sub_size = want
		sub.size = want
	if grade_mat != null and Game.sky != null:
		var d: float = Game.sky.day_t
		var morning := smoothstep(0.17, 0.27, d) * (1.0 - smoothstep(0.40, 0.54, d))
		var evening := smoothstep(0.62, 0.72, d) * (1.0 - smoothstep(0.80, 0.88, d))
		grade_mat.set_shader_parameter("warmth", maxf(morning * 0.85, evening))
		grade_mat.set_shader_parameter("warm_col", Vector3(1.0, 0.78, 0.5) if morning >= evening else Vector3(1.0, 0.5, 0.32))
		grade_mat.set_shader_parameter("sun_uv", Vector2(fposmod(d + 0.25, 1.0), 0.42 - Game.sky.sun_elevation() * 0.34))
		grade_mat.set_shader_parameter("night", clampf(-Game.sky.sun_elevation(), 0.0, 1.0))
	if distant != null:
		distant.tick(delta, Game.view.camera.get_screen_center_position(), Game.sky)
	flash = maxf(0.0, flash - delta * 3.0)
	var cam: Vector2 = Game.view.camera.get_screen_center_position()
	mat.set_shader_parameter("cam", cam)
	mat.set_shader_parameter("t", _t)
	mat.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)
	mat.set_shader_parameter("flash", flash)

	var sky = Game.sky
	if sky == null:
		return
	mat.set_shader_parameter("top_color", sky.sky_top())
	mat.set_shader_parameter("bottom_color", sky.sky_bottom())
	mat.set_shader_parameter("time_of_day", sky.day_t)
	mat.set_shader_parameter("sun_elev", sky.sun_elevation())
	mat.set_shader_parameter("wind", sky.wind_vector().normalized() * clampf(sky.wind_strength(), 0.2, 3.0))
	# the deck below sits lower the higher you are, which is the whole altitude cue
	var band := Defs.band_index(sky.gen.altitude) if sky.gen != null else 1
	mat.set_shader_parameter("altitude", clampf(float(band) / 4.0, 0.0, 1.0))
	# the cloud floor and the haze both take the time of day with them
	var amb: Color = sky.ambient_color()
	mat.set_shader_parameter("deck_color", sky.sky_bottom().lightened(0.16) * Color(amb.r, amb.g, amb.b, 1.0))
	mat.set_shader_parameter("haze_color", sky.sky_bottom().lightened(0.06))
	mat.set_shader_parameter("warmth", _dusk(sky.day_t))
	mat.set_shader_parameter("sun_color",Color(1.0, 0.94, 0.78).lerp(Color(1.0, 0.72, 0.45), _dusk(sky.day_t)))

	var here: Vector2i = Game.player.root_cell() if Game.player != null else Vector2i.ZERO
	var worst: Array = sky.weather.worst_at(here)
	var kind: int = int(worst[0])
	var strength: float = float(worst[1])
	mat.set_shader_parameter("weather", clampf(strength * _weather_opacity(kind), 0.0, 0.92))
	var wc: Color = Weather.KINDS.get(kind, {}).get("col", Color(0.6, 0.66, 0.78))
	mat.set_shader_parameter("weather_color", wc)
	mat.set_shader_parameter("aurora", sky.weather.at(here, Weather.AURORA))
	var st: float = sky.weather.at(here, Weather.THUNDERHEAD)
	mat.set_shader_parameter("storm", st)
	# a real bolt somewhere in the cell, often enough to be unsettling and not so often
	# that it stops being an event
	if st > 0.25 and randf() < delta * st * 0.5:
		flash = 0.55 * st

## Fog blots the sky out; a thunderhead only darkens it; an aurora barely touches it.
static func _weather_opacity(kind: int) -> float:
	match kind:
		Weather.FOG: return 0.95
		Weather.ASHFALL: return 0.75
		Weather.THUNDERHEAD: return 0.62
		Weather.DOWNDRAFT: return 0.45
		Weather.SQUALL: return 0.38
		Weather.AURORA: return 0.12
	return 0.0

static func _dusk(day_t: float) -> float:
	# 1 at dawn and dusk, 0 at noon and midnight: how orange the light is
	return clampf(1.0 - absf(absf(day_t - 0.5) - 0.25) * 7.0, 0.0, 1.0)
