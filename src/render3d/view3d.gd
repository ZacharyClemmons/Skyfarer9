class_name View3D extends Node3D
## The first-person view.
##
## This is not a second game. It reads the same StationMap and the same entity registry as
## the top-down view, one frame behind nothing: the floor you walk on is the same turf
## array, the crate you see is the same Entity, and the light on both is the same lightmap.
## Pressing the toggle swaps which camera is drawing and nothing else.
##
## Everything is built the way Doom built it, because that is what suits a tile grid and a
## folder full of bottom-anchored 32px sprites:
##   - floors and ceilings are two triangles per tile, UV'd straight into terrain.png
##   - walls are quads on the faces that border open space, using the wall sprite's own
##     3/4 front face, which was drawn to be seen head-on
##   - everything else is a billboard of the exact sprite the 2D view would draw
##
## Per-tile light is baked into vertex colours and refreshed a few times a second, so a
## lantern on deck lights the planks around it in both views at once.

const TILE := 1.0
const WALL_H := 2.3
## A solid turf that does not block sight is a bulwark or a rail: waist-high, so standing
## at your own ship's side you look out over it rather than at it. This is the same
## distinction the 2D view makes with F_OPAQUE, seen from the deck instead of from above.
const RAIL_H := 0.95
const CEIL_H := 2.6
const EYE := 1.52
const CHUNK := 16
const SKY_R := 260.0
const DRAW_CHUNKS := 5 # radius in chunks around the player that stays built

var map: StationMap
var cam: Camera3D
var yaw := 0.0
var pitch := 0.0

var terrain_root: Node3D
var ent_root: Node3D
var sky_mesh: MeshInstance3D
var sky_mat: ShaderMaterial
var _sky_t := 0.0

var chunks := {} # Vector2i -> MeshInstance3D
var dirty := {}
var _billboards := {} # Entity id -> Node3D
var _light_t := 0.0
var _rebuild_t := 0.0
var _last_chunk := Vector2i(-999, -999)

var terrain_mat: StandardMaterial3D
var doll_shader: Shader

# ------------------------------------------------------------------ setup
func setup(m: StationMap) -> void:
	map = m
	terrain_root = Node3D.new()
	add_child(terrain_root)
	ent_root = Node3D.new()
	add_child(ent_root)

	terrain_mat = StandardMaterial3D.new()
	terrain_mat.albedo_texture = Gfx.tex("terrain")
	terrain_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	terrain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	terrain_mat.vertex_color_use_as_albedo = true
	terrain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	terrain_mat.alpha_scissor_threshold = 0.5
	terrain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	doll_shader = load("res://src/render3d/paperdoll3d.gdshader")

	cam = Camera3D.new()
	cam.fov = 74.0
	cam.near = 0.05
	cam.far = 400.0
	add_child(cam)
	_build_sky()

func _build_sky() -> void:
	sky_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = SKY_R
	sm.height = SKY_R * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	sky_mesh.mesh = sm
	sky_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled, fog_disabled;
// The Cloudsea's own sky, seen from the deck: the gradient SkySystem is ramping through,
// a sun or moon with a glow, stars at night, a lit cloud ceiling overhead and the
// cloud floor a long way below. Everything is banded and dithered to sit with the art.
uniform vec3 top_col : source_color = vec3(0.2, 0.4, 0.7);
uniform vec3 bot_col : source_color = vec3(0.7, 0.85, 0.95);
uniform vec3 deck_col : source_color = vec3(0.85, 0.9, 0.95);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_col : source_color = vec3(1.0, 0.94, 0.78);
uniform float sun_elev = 0.6;
uniform float warmth = 0.0;
uniform float t = 0.0;
uniform vec2 drift = vec2(0.0);
varying vec3 wdir;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p = p * 2.05 + 11.0;
		a *= 0.5;
	}
	return v;
}
float bayer(vec2 p) {
	ivec2 q = ivec2(mod(floor(p), 4.0));
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[q.x + q.y * 4]) + 0.5) / 16.0;
}
void vertex() {
	wdir = VERTEX;
}
void fragment() {
	vec3 dir = normalize(wdir);
	float h = dir.y;
	float day = smoothstep(-0.28, 0.32, sun_elev);
	float night = smoothstep(0.08, 0.6, -sun_elev);
	float dith = bayer(FRAGCOORD.xy) - 0.5;
	// the body of the sky
	vec3 c = mix(bot_col, top_col, pow(clamp(h * 0.5 + 0.5, 0.0, 1.0), 1.4));
	float sd = max(dot(dir, normalize(sun_dir)), 0.0);
	// horizon glow leaning toward the sun, hot at dawn and dusk
	float hz = exp(-abs(h) * 5.0);
	c = mix(c, mix(vec3(0.86, 0.34, 0.50), vec3(1.0, 0.52, 0.26), hz), warmth * hz * (0.35 + 0.5 * pow(sd, 3.0)));
	c += sun_col * pow(sd, 8.0) * 0.16 * day + sun_col * pow(sd, 60.0) * 0.35 * day;
	// stars
	if (night > 0.02 && h > -0.05) {
		vec2 sp = dir.xz / (abs(h) + 0.6) * 170.0;
		vec2 sc = floor(sp);
		float s = hash(sc);
		float tw = 0.7 + 0.3 * sin(t * 2.0 + s * 60.0);
		c += vec3(0.85, 0.9, 1.0) * step(0.992, s) * tw * night;
	}
	// the cloud ceiling overhead: banded, sun-lit on the near edge
	if (h > 0.02) {
		vec2 p = dir.xz / (h + 0.22) * 1.3 + drift;
		float n = fbm(p);
		float ns = fbm(p + normalize(sun_dir.xz + 0.001) * 0.12);
		float cl = smoothstep(0.52, 0.68, n + dith * 0.05) * smoothstep(0.02, 0.22, h);
		float rim = clamp((n - ns) * 8.0 + 0.4, 0.0, 1.0);
		float b = floor((0.55 + 0.45 * rim - 0.2 * clamp((n - 0.55) * 4.0, 0.0, 1.0) * (1.0 - rim)) * 4.0 + 0.5) / 4.0;
		vec3 lit = mix(vec3(0.42, 0.46, 0.68), mix(vec3(1.0), sun_col, warmth * 0.7), day);
		vec3 shd = mix(vec3(0.10, 0.12, 0.26), mix(bot_col * 0.6 + 0.06, vec3(0.55, 0.38, 0.52), warmth * 0.7), day);
		c = mix(c, mix(shd, lit, b), cl * 0.9);
	}
	// the cloud floor a long way below: a lit sea of cloud
	if (h < 0.0) {
		vec2 p = dir.xz / (-h + 0.12) * 0.7 + drift * 0.5;
		float n = fbm(p);
		float ns = fbm(p + normalize(sun_dir.xz + 0.001) * 0.12);
		float rim = clamp((n - ns) * 8.0 + 0.4, 0.0, 1.0);
		float b = floor((0.5 + 0.5 * rim) * 4.0 + 0.5) / 4.0;
		vec3 lit = mix(vec3(0.42, 0.46, 0.68), mix(vec3(1.0), sun_col, warmth * 0.7), day);
		vec3 shd = mix(vec3(0.12, 0.14, 0.28), mix(deck_col * 0.7, vec3(0.6, 0.45, 0.55), warmth * 0.6), day);
		vec3 fl = mix(shd, lit, b * (0.4 + n * 0.7));
		float fade = smoothstep(0.0, -0.10, h);
		c = mix(c, mix(deck_col, fl, 0.7), fade);
	}
	// the disc itself
	float disc = smoothstep(0.9988, 0.9993, sd);
	vec3 body = sun_elev > -0.05 ? sun_col : vec3(0.86, 0.9, 1.0);
	c = mix(c, body, disc * (h > -0.02 ? 1.0 : 0.0));
	c = floor(c * 22.0 + dith * 0.9 + 0.5) / 22.0;
	ALBEDO = c;
}
"""
	sky_mat.shader = sh
	sky_mesh.material_override = sky_mat
	sky_mesh.extra_cull_margin = SKY_R
	add_child(sky_mesh)

# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	if map == null or not visible:
		return
	var p := Game.player
	if p == null or not is_instance_valid(p):
		return
	_place_camera(p, delta)
	_sky_colours()
	var here := Vector2i(p.cell.x / CHUNK, p.cell.y / CHUNK)
	if here != _last_chunk:
		_last_chunk = here
		_cull_chunks(here)
	_rebuild_t -= delta
	if _rebuild_t <= 0.0:
		_rebuild_t = 0.1
		_build_pending(here)
	_light_t -= delta
	if _light_t <= 0.0:
		_light_t = 0.22
		_relight()
	_billboard_pass(p)

func _place_camera(p: Entity, delta: float) -> void:
	# Stand where the player stands, in the same sub-tile position the 2D view uses, so
	# stepping between tiles glides instead of snapping.
	var pos := p.position / float(Defs.TILE)
	if Game.fleet != null:
		var sh: Airship = Game.fleet.ship_of(p)
		if sh != null:
			# 3D terrain uses simulation tiles, independently of the overhead transform.
			pos = sh.simulation_position(p) / float(Defs.TILE)
	var target := Vector3(pos.x, EYE, pos.y - 0.5)
	cam.position = cam.position.lerp(target, minf(1.0, delta * 18.0))
	var roll: float = Game.fleet.turn_roll if Game.fleet != null else 0.0
	cam.rotation = Vector3(pitch, yaw - roll, 0.0)
	sky_mesh.position = cam.position

func _sky_colours() -> void:
	if Game.sky == null:
		return
	sky_mat.set_shader_parameter("top_col", Game.sky.sky_top())
	sky_mat.set_shader_parameter("bot_col", Game.sky.sky_bottom())
	var amb: Color = Game.sky.ambient_color()
	sky_mat.set_shader_parameter("deck_col", Color(0.92, 0.95, 1.0) * amb)
	var el: float = Game.sky.sun_elevation()
	var az: float = fposmod(Game.sky.day_t + 0.25, 1.0) * TAU
	var ce: float = cos(asin(clampf(el, -1.0, 1.0)))
	# by night the same direction carries the moon, opposite in the sky
	var sdir := Vector3(sin(az) * ce, el, -cos(az) * ce)
	if el < -0.05:
		sdir = Vector3(-sdir.x, -el, -sdir.z)
	var dusk := clampf(1.0 - absf(absf(Game.sky.day_t - 0.5) - 0.25) * 7.0, 0.0, 1.0)
	sky_mat.set_shader_parameter("sun_dir", sdir)
	sky_mat.set_shader_parameter("sun_elev", el)
	sky_mat.set_shader_parameter("warmth", dusk)
	sky_mat.set_shader_parameter("sun_col", Color(1.0, 0.94, 0.78).lerp(Color(1.0, 0.72, 0.45), dusk))
	_sky_t += get_process_delta_time()
	sky_mat.set_shader_parameter("t", _sky_t)
	var wv: Vector2 = Game.sky.wind_vector().normalized() * 0.004
	sky_mat.set_shader_parameter("drift", wv * _sky_t)

## When the ship you are on comes about, your heading comes with her: the yaw is carried
## by the same quarter turn so you keep looking at whatever you were looking at relative to
## the deck.
func carry_turn(step: int) -> void:
	yaw = fposmod(yaw - step * PI * 0.5, TAU)

## Look around. Yaw also drives the character's facing, so every existing interaction,
## attack and sprite that cares which way you are pointing keeps working.
func look(rel: Vector2, sensitivity := 0.0028) -> void:
	yaw = fposmod(yaw - rel.x * sensitivity, TAU)
	pitch = clampf(pitch - rel.y * sensitivity, -1.35, 1.35)
	var p := Game.player
	if p != null and is_instance_valid(p) and p.has_c(&"mob"):
		p.c(&"mob").face(facing_dir())

## Which of the four cardinal directions the camera is pointing down.
func facing_dir() -> int:
	var a := fposmod(yaw, TAU)
	if a < PI * 0.25 or a >= PI * 1.75:
		return Defs.DIR_N
	if a < PI * 0.75:
		return Defs.DIR_W
	if a < PI * 1.25:
		return Defs.DIR_S
	return Defs.DIR_E

## Turn a movement intent in screen space into a tile step in world space.
func move_vector(input: Vector2) -> Vector2i:
	if input == Vector2.ZERO:
		return Vector2i.ZERO
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	var v := fwd * -input.y + right * input.x
	if absf(v.x) > absf(v.y) * 1.6:
		return Vector2i(signi(roundi(v.x * 2.0)), 0)
	if absf(v.y) > absf(v.x) * 1.6:
		return Vector2i(0, signi(roundi(v.y * 2.0)))
	return Vector2i(signi(roundi(v.x * 2.0)), signi(roundi(v.y * 2.0)))

## The tile the crosshair is on: step forward until something stops the ray.
func aimed_cell() -> Vector2i:
	var p := Game.player
	if p == null:
		return Vector2i.ZERO
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var at := Vector2(p.cell) + Vector2(0.5, 0.5)
	for _k in 6:
		at += fwd * 0.9
		var c := Vector2i(floori(at.x), floori(at.y))
		if not map.inb(c):
			break
		if map.is_solid_turf(c) or not Game.at(c).is_empty():
			return c
	return Vector2i(floori(at.x), floori(at.y))

# ------------------------------------------------------------------ terrain meshes
func mark_dirty(cells: Array) -> void:
	for c in cells:
		dirty[Vector2i(c.x / CHUNK, c.y / CHUNK)] = true

func _cull_chunks(here: Vector2i) -> void:
	for k in chunks.keys():
		if maxi(absi(k.x - here.x), absi(k.y - here.y)) > DRAW_CHUNKS:
			chunks[k].queue_free()
			chunks.erase(k)
	for dy in range(-DRAW_CHUNKS, DRAW_CHUNKS + 1):
		for dx in range(-DRAW_CHUNKS, DRAW_CHUNKS + 1):
			var k := here + Vector2i(dx, dy)
			if k.x < 0 or k.y < 0 or k.x * CHUNK >= map.w or k.y * CHUNK >= map.h:
				continue
			if not chunks.has(k):
				dirty[k] = true

## Build a couple of chunks per tick so entering a new area never stalls a frame.
func _build_pending(here: Vector2i) -> void:
	if dirty.is_empty():
		return
	var keys: Array = dirty.keys()
	keys.sort_custom(func(a, b):
		return maxi(absi(a.x - here.x), absi(a.y - here.y)) < maxi(absi(b.x - here.x), absi(b.y - here.y)))
	for i in mini(2, keys.size()):
		var k: Vector2i = keys[i]
		dirty.erase(k)
		if maxi(absi(k.x - here.x), absi(k.y - here.y)) > DRAW_CHUNKS:
			continue
		_build_chunk(k)

func _build_chunk(k: Vector2i) -> void:
	if chunks.has(k):
		chunks[k].queue_free()
		chunks.erase(k)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	var tex_size := Gfx.tex("terrain").get_size()
	for y in range(k.y * CHUNK, mini(k.y * CHUNK + CHUNK, map.h)):
		for x in range(k.x * CHUNK, mini(k.x * CHUNK + CHUNK, map.w)):
			var c := Vector2i(x, y)
			if _emit_tile(st, c, tex_size):
				any = true
	if not any:
		return
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = terrain_mat
	terrain_root.add_child(mi)
	chunks[k] = mi

func _emit_tile(st: SurfaceTool, c: Vector2i, tex_size: Vector2) -> bool:
	var i := map.idx(c)
	var t: int = map.turf[i]
	var info: Dictionary = Defs.TURFS[t]
	var fl: int = info["flags"]
	var col := _light_of(c)
	var any := false
	if fl & Defs.F_VOID:
		return false # open sky: nothing to stand on and nothing to draw
	if fl & (Defs.F_SOLID):
		# a wall or a rock face: quads on the sides that face open space
		var face := _region("%s_%d" % [info["spr"], _wall_mask(c)], tex_size)
		if face.size == Vector2.ZERO:
			face = _region("%s_%d" % [info["spr"], 0], tex_size)
		var h: float = WALL_H if (fl & Defs.F_OPAQUE) != 0 else RAIL_H
		for d in 4:
			var n: Vector2i = c + Defs.DIRS4[d]
			if map.inb(n) and map.is_solid_turf(n):
				continue
			_quad_wall(st, c, d, face, _light_of(n if map.inb(n) else c), h)
			any = true
		# a cap on top, so you never see into a solid block from above
		_quad_flat(st, c, h, _region_ground(c, tex_size), col, false)
		return true
	# floor
	_quad_flat(st, c, 0.0, _region_ground(c, tex_size), col, false)
	any = true
	# ceiling over sealed interiors only: a weather deck must stay open to the sky
	if (fl & Defs.F_OUTDOOR) == 0:
		_quad_flat(st, c, CEIL_H, _region("plating_0", tex_size), col * 0.55, true)
	return any

func _wall_mask(c: Vector2i) -> int:
	var m := 0
	for d in 4:
		var n: Vector2i = c + Defs.DIRS4[d]
		var solid := not map.inb(n) or (map.tflags(n) & (Defs.F_WALL | Defs.F_ROCK)) != 0
		if solid:
			m |= 1 << d
	return m

func _region_ground(c: Vector2i, tex_size: Vector2) -> Rect2:
	var i := map.idx(c)
	var info: Dictionary = Defs.TURFS[map.turf[i]]
	var v: int = map.variant[i] % maxi(1, int(info["var"]))
	return _region("%s_%d" % [info["spr"], v], tex_size)

func _region(name: String, tex_size: Vector2) -> Rect2:
	var r = Gfx.manifest["terrain"].get(name)
	if r == null:
		return Rect2()
	return Rect2(r[0] * 32.0 / tex_size.x, r[1] * 32.0 / tex_size.y, 32.0 / tex_size.x, 32.0 / tex_size.y)

func _quad_flat(st: SurfaceTool, c: Vector2i, h: float, uv: Rect2, col: Color, down: bool) -> void:
	if uv.size == Vector2.ZERO:
		return
	var x := float(c.x)
	var z := float(c.y)
	var p := [Vector3(x, h, z), Vector3(x + 1, h, z), Vector3(x + 1, h, z + 1), Vector3(x, h, z + 1)]
	var u := [uv.position, uv.position + Vector2(uv.size.x, 0), uv.position + uv.size, uv.position + Vector2(0, uv.size.y)]
	var order := [0, 2, 1, 0, 3, 2] if not down else [0, 1, 2, 0, 2, 3]
	st.set_color(col)
	for k in order:
		st.set_uv(u[k])
		st.add_vertex(p[k])

func _quad_wall(st: SurfaceTool, c: Vector2i, d: int, uv: Rect2, col: Color, h := WALL_H) -> void:
	if uv.size == Vector2.ZERO:
		return
	var x := float(c.x)
	var z := float(c.y)
	# the outward-facing edge of this tile, in the direction d (N, E, S, W)
	var a: Vector3
	var b: Vector3
	match d:
		Defs.DIR_N:
			a = Vector3(x + 1, 0, z); b = Vector3(x, 0, z)
		Defs.DIR_E:
			a = Vector3(x + 1, 0, z + 1); b = Vector3(x + 1, 0, z)
		Defs.DIR_S:
			a = Vector3(x, 0, z + 1); b = Vector3(x + 1, 0, z + 1)
		_:
			a = Vector3(x, 0, z); b = Vector3(x, 0, z + 1)
	var up := Vector3(0, h, 0)
	var p := [a, b, b + up, a + up]
	# only the lower part of a 3/4 wall sprite is its front face
	var uv2 := Rect2(uv.position + Vector2(0, uv.size.y * 0.55), Vector2(uv.size.x, uv.size.y * 0.45))
	var u := [uv2.position + Vector2(0, uv2.size.y), uv2.position + uv2.size,
		uv2.position + Vector2(uv2.size.x, 0), uv2.position]
	st.set_color(col)
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_uv(u[k])
		st.add_vertex(p[k])

# ------------------------------------------------------------------ light
func _light_of(c: Vector2i) -> Color:
	if Game.lighting == null or not map.inb(c):
		return Color(0.5, 0.5, 0.6)
	# light_at already folds the ambient's brightness in, so only its hue is wanted here
	var l: float = Game.lighting.light_at(c)
	var amb := Color(0.85, 0.85, 0.9)
	if Game.sky != null:
		amb = Game.sky.ambient_color()
	var v: float = maxf(0.001, maxf(amb.r, maxf(amb.g, amb.b)))
	return Color(amb.r / v * l, amb.g / v * l, amb.b / v * l).clamp(
		Color(0.06, 0.06, 0.10), Color(1.3, 1.3, 1.3))

## Light moves (lanterns, fires, dusk), so chunks near the player get their vertex colours
## refreshed. Rebuilding the geometry would be wasteful, so only the colours are redone.
func _relight() -> void:
	var p := Game.player
	if p == null:
		return
	var here := Vector2i(p.cell.x / CHUNK, p.cell.y / CHUNK)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			dirty[here + Vector2i(dx, dy)] = true

# ------------------------------------------------------------------ billboards
func _billboard_pass(p: Entity) -> void:
	var seen := {}
	for e in Game.in_radius(p.root_cell(), 22):
		if e == p or e.removed or e.holder != null or not e.visible:
			continue
		if e.has_c(&"decal"):
			continue
		seen[e.id] = true
		var node = _billboards.get(e.id)
		if node == null or not is_instance_valid(node):
			node = _make_billboard(e)
			if node == null:
				continue
			ent_root.add_child(node)
			_billboards[e.id] = node
		_update_billboard(e, node)
	for id in _billboards.keys():
		if not seen.has(id):
			if is_instance_valid(_billboards[id]):
				_billboards[id].queue_free()
			_billboards.erase(id)

func _make_billboard(e: Entity) -> Node3D:
	var m: CMob = e.c(&"mob")
	if m != null and m.doll != null:
		return _make_doll(e, m)
	if e.spr == null or e.spr.texture == null or e.spr_sheet == "":
		return null
	var s := Sprite3D.new()
	s.texture = e.spr.texture
	s.region_enabled = true
	s.region_rect = e.spr.region_rect
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.pixel_size = 1.0 / 32.0
	s.centered = false
	s.offset = Vector2(-e.spr.region_rect.size.x * 0.5, 0)
	return s

## A character: one quad per paper-doll layer, all using the spatial port of the same
## palette shader, so what you see here is exactly what the 2D view draws.
func _make_doll(e: Entity, m: CMob) -> Node3D:
	var root := Node3D.new()
	var sheet_size := Gfx.tex("mobs").get_size()
	for slot in PaperDoll.ORDER:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.0, 1.0)
		qm.center_offset = Vector3(0, 0.5, 0)
		q.mesh = qm
		var mat := ShaderMaterial.new()
		mat.shader = doll_shader
		mat.set_shader_parameter("tex", Gfx.tex("mobs"))
		mat.set_shader_parameter("sheet_size", sheet_size)
		mat.set_shader_parameter("region_size", Vector2(32, 32))
		q.material_override = mat
		q.set_meta("slot", slot)
		q.visible = false
		root.add_child(q)
	return root

func _update_billboard(e: Entity, node: Node3D) -> void:
	var cell := e.cell
	var pos := e.position / float(Defs.TILE)
	if Game.fleet != null:
		var sh: Airship = Game.fleet.ship_of(e)
		if sh != null:
			pos = sh.simulation_position(e) / float(Defs.TILE)
	node.position = Vector3(pos.x, 0.02, pos.y - 0.5)
	var lit := _light_of(cell)
	var m: CMob = e.c(&"mob")
	if m != null and m.doll != null:
		node.rotation.y = yaw
		var scale_v: float = float(e.tags.get("size", 1.0))
		node.scale = Vector3(scale_v, scale_v, scale_v)
		for q in node.get_children():
			var slot: String = q.get_meta("slot")
			var src: String = m.doll.layer_src.get(slot, "")
			if src == "" or not m.doll.layers[slot].visible:
				q.visible = false
				continue
			var base := Gfx.region("mobs", src)
			var row: int = PaperDoll.DIR_ROW[_relative_dir(m.dir)]
			var mat: ShaderMaterial = q.material_override
			mat.set_shader_parameter("region_pos", Vector2(base.position.x + m.doll.frame * 32, base.position.y + row * 32))
			var src_mat: ShaderMaterial = m.doll.layers[slot].material
			if src_mat != null:
				mat.set_shader_parameter("pal", src_mat.get_shader_parameter("pal"))
			mat.set_shader_parameter("tint", lit)
			q.visible = true
			q.position = Vector3(0, 0, 0.001 * float(PaperDoll.ORDER.find(slot)))
		return
	if node is Sprite3D:
		node.modulate = lit

## Which doll row to show: a character seen from behind should show their back, so the
## sprite's facing is taken relative to where the camera is standing, not to world north.
func _relative_dir(mob_dir: int) -> int:
	var world: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][mob_dir]
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	var f: float = world.dot(fwd)
	var r: float = world.dot(right)
	if absf(f) > absf(r):
		return Defs.DIR_S if f > 0.0 else Defs.DIR_N
	return Defs.DIR_W if r > 0.0 else Defs.DIR_E

func rebuild_all() -> void:
	for k in chunks.keys():
		chunks[k].queue_free()
	chunks.clear()
	dirty.clear()
	_last_chunk = Vector2i(-999, -999)
