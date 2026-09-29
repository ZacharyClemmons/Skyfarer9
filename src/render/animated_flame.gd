class_name AnimatedFlame extends Sprite2D
## Looping fire sprite (0..2 intensity) with an additive HDR glow twin.

var intensity := 1
var t := 0.0
var frame_i := 0
var glow: Sprite2D

func _ready() -> void:
	texture = Gfx.tex("fx")
	region_enabled = true
	offset = Vector2(0, -16)
	glow = Sprite2D.new()
	glow.texture = texture
	glow.region_enabled = true
	glow.offset = offset
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.modulate = Color(1.6, 1.2, 0.8, 0.8)
	add_child(glow)
	z_index = 2
	frame_i = randi() % 4
	_apply()

func _process(delta: float) -> void:
	t += delta
	if t > 0.11:
		t = 0.0
		frame_i = (frame_i + 1) % 4
		_apply()

func _apply() -> void:
	var r := Gfx.region("fx", "fire_%d_%d" % [clampi(intensity, 0, 2), frame_i])
	region_rect = r
	glow.region_rect = r
