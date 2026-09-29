extends Node
## Sprite atlas access. The art generator (tools/artgen) writes packed sheets plus
## assets/gfx/manifest.json describing where every named sprite lives.

const T := 32
var manifest: Dictionary = {}
var sheets := {}
var _atlas_cache := {}
var paperdoll_shader: Shader

func _ready() -> void:
	var f := FileAccess.open("res://assets/gfx/manifest.json", FileAccess.READ)
	manifest = JSON.parse_string(f.get_as_text())
	for s in ["terrain", "objects", "items", "mobs", "fx", "ui"]:
		sheets[s] = load("res://assets/gfx/%s.png" % s)
	paperdoll_shader = load("res://src/render/paperdoll.gdshader")

func tex(sheet: String) -> Texture2D:
	return sheets[sheet]

var _images := {}

## CPU copy of a sheet, for pixel-accurate clicking (see PlayerController.pick).
func image(sheet: String) -> Image:
	if not _images.has(sheet):
		var img: Image = sheets[sheet].get_image()
		if img and img.is_compressed():
			img.decompress()
		_images[sheet] = img
	return _images[sheet]

## Is the pixel at `p` (in region coordinates) of a sprite visible?
func opaque_at(sheet: String, region: Rect2, p: Vector2) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= region.size.x or p.y >= region.size.y:
		return false
	var img := image(sheet)
	if img == null:
		return true
	return img.get_pixel(int(region.position.x + p.x), int(region.position.y + p.y)).a > 0.2

func has(sheet: String, name: String) -> bool:
	return manifest.has(sheet) and manifest[sheet].has(name)

func region(sheet: String, name: String) -> Rect2:
	var r = manifest[sheet].get(name)
	if r == null:
		push_warning("missing sprite %s/%s" % [sheet, name])
		return Rect2(0, 0, 0, 0)
	if sheet == "terrain":
		return Rect2(r[0] * T, r[1] * T, T, T)
	return Rect2(r[0], r[1], r[2], r[3])

func atlas(sheet: String, name: String) -> AtlasTexture:
	var key := sheet + "/" + name
	if _atlas_cache.has(key):
		return _atlas_cache[key]
	var a := AtlasTexture.new()
	a.atlas = sheets[sheet]
	a.region = region(sheet, name)
	_atlas_cache[key] = a
	return a

## Palette uniform for the paper-doll shader: 4 materials (primary, secondary, accent,
## metal) x 6 shades. Missing colours fall back to neutral greys.
static func doll_palette(colors: Array) -> PackedColorArray:
	var pal := PackedColorArray()
	var defaults := [Color("#8a93a3"), Color("#5f6878"), Color("#3a3a40"), Color("#b0b8c4")]
	for m in 4:
		var col: Color = colors[m] if m < colors.size() and colors[m] != null else defaults[m]
		pal.append_array(ramp6(col))
	return pal

## A recolouring material for a palette-encoded sprite from mobs.png (worn layers and
## clothing icons).
func doll_material(colors: Array) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = paperdoll_shader
	mat.set_shader_parameter("pal", doll_palette(colors))
	return mat

## Hue-shifted six step ramp (outline..highlight) used by the paper-doll shader.
static func ramp6(base: Color) -> PackedColorArray:
	var out := PackedColorArray()
	var outline := _shift(base, -0.75).lerp(Color("#14121c"), 0.5)
	out.append(outline)
	out.append(_shift(base, -0.45))
	out.append(_shift(base, -0.22))
	out.append(base)
	out.append(_shift(base, 0.2))
	out.append(_shift(base, 0.42))
	return out

static func _shift(c: Color, amt: float) -> Color:
	var h := c.h
	var s := c.s
	var v := c.v
	if amt < 0:
		var target := 0.68
		if absf(target - h) < 0.5:
			h = h + (target - h) * minf(1.0, -amt * 0.35)
		v = maxf(0.0, v * (1.0 + amt))
		s = minf(1.0, s * (1.0 - amt * 0.25))
	else:
		var dh := 0.14 - h
		if dh > 0.5: dh -= 1.0
		if dh < -0.5: dh += 1.0
		h = fposmod(h + dh * minf(1.0, amt * 0.25), 1.0)
		v = minf(1.0, v + (1.0 - v) * amt)
		s = maxf(0.0, s * (1.0 - amt * 0.35))
	return Color.from_hsv(h, s, v, c.a)
