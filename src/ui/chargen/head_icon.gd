class_name HeadIcon extends Control
## Your head, drawn with a given hairstyle / facial hair, for the setup room's carousels
## (Burgerstation shows the neighbouring hairstyles on your own head the same way).

const CROP := Rect2(4, 0, 24, 21) # the head's corner of the south-facing idle frame
var parts := {} # layer -> TextureRect

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["body", "eyes", "facial", "hair"]:
		var tr := TextureRect.new()
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		var mat := ShaderMaterial.new()
		mat.shader = Gfx.paperdoll_shader
		tr.material = mat
		add_child(tr)
		parts[k] = tr

func set_look(app: Dictionary, hair: String, facial: String) -> void:
	_part("body", "body", [app["skin"], app["underwear"]])
	_part("eyes", "eyes", [app["eyes"], null, null, Color(app["hair_color"]).darkened(0.3)])
	_part("facial", "facial_" + facial if facial != "" else "", [app["hair_color"]])
	_part("hair", "hair_" + hair if hair != "bald" else "", [app["hair_color"]])

func _part(k: String, sprite: String, colors: Array) -> void:
	var tr: TextureRect = parts[k]
	if sprite == "" or not Gfx.has("mobs", sprite):
		tr.visible = false
		return
	var at := AtlasTexture.new()
	at.atlas = Gfx.tex("mobs")
	var base := Gfx.region("mobs", sprite)
	at.region = Rect2(base.position + CROP.position, CROP.size)
	tr.texture = at
	(tr.material as ShaderMaterial).set_shader_parameter("pal", Gfx.doll_palette(colors))
	tr.visible = true
