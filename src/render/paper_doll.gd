class_name PaperDoll extends Node2D
## Layered, shader-recoloured character renderer. Layers come from mobs.png
## (see tools/artgen/mobs.py); colours are supplied per layer as 4 material bases.

## "tail" (monkeys) draws behind the body; "mutation" is tg MUTATIONS_LAYER (radiation
## glow, adaptation auras) and "front_mutation" FRONT_MUTATIONS_LAYER (antennae, laser eyes)
const ORDER := ["tail", "body", "mutation", "eyes", "facial", "uniform", "shoes", "gloves", "belt", "suit", "back", "mask", "glasses", "hair", "head", "front_mutation"]
const DIR_ROW := {Defs.DIR_S: 0, Defs.DIR_N: 1, Defs.DIR_E: 2, Defs.DIR_W: 3}

var layers := {} # slot -> Sprite2D
var layer_src := {} # slot -> sprite name in mobs sheet ("" = hidden)
var dir := Defs.DIR_S
var frame := 0
var held_l: Sprite2D
var held_r: Sprite2D
var flash := 0.0
var frost := 0.0
var animal_kind := ""
var psyker_head := false

func _draw() -> void:
	if psyker_head:
		# Original procedural head art, with an exposed crown and psychic fissures.
		draw_rect(Rect2(-5, -31, 10, 6), Color("#b68ab8"))
		draw_line(Vector2(-4, -28), Vector2(4, -28), Color("#503460"), 1.0)
		draw_line(Vector2(0, -31), Vector2(0, -25), Color("#503460"), 1.0)
		draw_circle(Vector2(-6, -28), 1.0, Color("#dfbbff"))
		draw_circle(Vector2(6, -28), 1.0, Color("#dfbbff"))
	if animal_kind == "": return
	var outline := Color("#25232a")
	if animal_kind == "crab":
		for side in [-1, 1]:
			for row in 3:
				draw_line(Vector2(side * 6, -10 + row * 2), Vector2(side * 12, -13 + row * 4), Color("#c34b3b"), 2)
			draw_circle(Vector2(side * 10, -16), 3, Color("#de6850"))
		draw_rect(Rect2(-7, -14, 14, 8), Color("#b84435"))
		draw_rect(Rect2(-5, -16, 2, 2), outline)
		draw_rect(Rect2(3, -16, 2, 2), outline)
	elif animal_kind == "gorilla":
		draw_rect(Rect2(-10, -25, 20, 20), Color("#45454b"))
		draw_rect(Rect2(-14, -21, 6, 20), Color("#37373f"))
		draw_rect(Rect2(8, -21, 6, 20), Color("#37373f"))
		draw_rect(Rect2(-6, -30, 12, 12), Color("#77777d"))
		draw_rect(Rect2(-4, -27, 2, 2), outline)
		draw_rect(Rect2(2, -27, 2, 2), outline)
	else:
		var side := -1 if dir == Defs.DIR_W else 1
		draw_rect(Rect2(-10, -14, 19, 9), Color("#bf8450"))
		draw_rect(Rect2(-8, -5, 4, 4), Color("#efddbb"))
		draw_rect(Rect2(4, -5, 4, 4), Color("#efddbb"))
		draw_rect(Rect2(side * 6 - 5, -23, 10, 12), Color("#dca267"))
		draw_rect(Rect2(side * 6 - 5, -27, 3, 5), Color("#9e663e"))
		draw_rect(Rect2(side * 6 + 2, -27, 3, 5), Color("#9e663e"))
		draw_rect(Rect2(side * 8 - 1, -20, 2, 2), outline)

func _init() -> void:
	for slot in ORDER:
		var s := Sprite2D.new()
		s.centered = true
		s.offset = Vector2(0, -16)
		s.region_enabled = true
		s.texture = Gfx.tex("mobs")
		var mat := ShaderMaterial.new()
		mat.shader = Gfx.paperdoll_shader
		s.material = mat
		s.visible = false
		add_child(s)
		layers[slot] = s
		layer_src[slot] = ""
	held_l = _make_held()
	held_r = _make_held()

func _make_held() -> Sprite2D:
	var s := Sprite2D.new()
	s.scale = Vector2(0.6, 0.6)
	s.region_enabled = true
	s.visible = false
	add_child(s)
	return s

## colors: Array of up to 4 Color (primary, secondary, accent, metal)
func set_layer(slot: String, sprite_name: String, colors: Array = []) -> void:
	var s: Sprite2D = layers[slot]
	if sprite_name == "" or not Gfx.has("mobs", sprite_name):
		s.visible = false
		layer_src[slot] = ""
		return
	layer_src[slot] = sprite_name
	(s.material as ShaderMaterial).set_shader_parameter("pal", Gfx.doll_palette(colors))
	s.visible = true
	_update_region(slot)

## Shift one layer (a monkey's hat sits lower on its head).
func set_layer_offset(slot: String, off: Vector2) -> void:
	layers[slot].position = off

## Hands sit lower on a smaller body.
var hand_offset := Vector2.ZERO

func set_facing(d: int, f: int) -> void:
	if d == dir and f == frame:
		return
	dir = d
	frame = f
	if animal_kind != "": queue_redraw()
	for slot in ORDER:
		_update_region(slot)
	_update_held_positions()

func _update_region(slot: String) -> void:
	var name: String = layer_src[slot]
	if name == "":
		return
	var base := Gfx.region("mobs", name)
	var s: Sprite2D = layers[slot]
	s.region_rect = Rect2(base.position.x + frame * 32, base.position.y + DIR_ROW[dir] * 32, 32, 32)
	var mat := s.material as ShaderMaterial
	mat.set_shader_parameter("origin", s.region_rect.position)
	mat.set_shader_parameter("facing", DIR_ROW[dir])
	# the back layer draws behind the body when facing south
	if slot == "back":
		s.z_index = -1 if dir == Defs.DIR_S else 0
	elif slot == "hair" and dir == Defs.DIR_N:
		s.z_index = 0

## What each hand shows: the held item's sheet and icon name ("" = empty hand).
var held_src := ["", ""]
var held_sheet := ["", ""]
var held_region := [Rect2(), Rect2()]

func set_held(hand: int, item: Entity) -> void:
	var s := held_l if hand == 0 else held_r
	if item == null or item.spr == null:
		s.visible = false
		held_src[hand] = ""
		return
	s.texture = item.spr.texture
	s.region_rect = item.spr.region_rect
	s.material = item.spr.material # recoloured clothing icons
	s.modulate = item.spr.modulate
	s.centered = true
	held_src[hand] = item.spr_name
	held_sheet[hand] = item.spr_sheet
	held_region[hand] = item.spr.region_rect
	s.visible = true
	_update_held_positions()

## tg in-hands: a held view per facing (tools/artgen/handheld.py) with the grip at its
## centre; the west view is the east one mirrored, and a hand on the viewer's left side
## mirrors the south/north view so the item points outward.
func _held_view(s: Sprite2D, hand: int, screen_left: bool) -> void:
	var nm: String = held_src[hand]
	var sheet: String = held_sheet[hand]
	if nm == "":
		return
	var v := "s"
	match dir:
		Defs.DIR_N: v = "n"
		Defs.DIR_E, Defs.DIR_W: v = "e"
	var view := "ih_%s_%s" % [nm, v]
	if sheet != "" and Gfx.has(sheet, view):
		s.region_rect = Gfx.region(sheet, view)
		s.scale = Vector2.ONE
		s.flip_h = (dir == Defs.DIR_W) if v == "e" else screen_left
		return
	# no held view (clothing icons): the shrunken icon, or the icon itself
	var held := "held_" + nm
	if sheet != "" and Gfx.has(sheet, held):
		s.region_rect = Gfx.region(sheet, held)
		s.scale = Vector2.ONE
	else:
		s.region_rect = held_region[hand]
		s.scale = Vector2(0.6, 0.6)
	s.flip_h = dir == Defs.DIR_W

func _update_held_positions() -> void:
	# hand 0 = left hand (viewer's right when facing south). Positions are the hands.
	var pos_l := Vector2(8, -9)
	var pos_r := Vector2(-8, -9)
	match dir:
		Defs.DIR_N:
			pos_l = Vector2(-8, -9); pos_r = Vector2(8, -9)
		Defs.DIR_E:
			pos_l = Vector2(1, -10); pos_r = Vector2(3, -9)
		Defs.DIR_W:
			pos_l = Vector2(-3, -9); pos_r = Vector2(-1, -10)
	held_l.position = pos_l + hand_offset
	held_r.position = pos_r + hand_offset
	_held_view(held_l, 0, pos_l.x < 0)
	_held_view(held_r, 1, pos_r.x < 0)
	var behind := dir == Defs.DIR_N
	# behind the body = drawn before the doll layers (a negative z would sink under the floor)
	_layer_held(held_l, behind or dir == Defs.DIR_E)
	_layer_held(held_r, behind or dir == Defs.DIR_W)

func _layer_held(s: Sprite2D, behind: bool) -> void:
	s.z_index = 0
	move_child(s, 0 if behind else get_child_count() - 1)

func set_flash(v: float) -> void:
	flash = v
	for slot in ORDER:
		(layers[slot].material as ShaderMaterial).set_shader_parameter("flash", v)

func set_frost(v: float) -> void:
	if absf(v - frost) < 0.02:
		return
	frost = v
	for slot in ORDER:
		(layers[slot].material as ShaderMaterial).set_shader_parameter("frost", v)

## tg bodypart overlays: missing limbs vanish from every layer (with a raw stump), and
## bleeding limbs get tg's bleed overlay (levels 1-3 by BLEED_OVERLAY_LOW/MED/GUSH).
var gore_key := ""

func set_gore(cut: int, bleed: Vector4, bleed2: Vector2) -> void:
	var k := "%d|%s|%s" % [cut, bleed, bleed2]
	if k == gore_key:
		return
	gore_key = k
	for slot in ORDER:
		var mat := layers[slot].material as ShaderMaterial
		mat.set_shader_parameter("cut", cut)
		mat.set_shader_parameter("bleed", bleed)
		mat.set_shader_parameter("bleed2", bleed2)
	for pair in [[held_l, 1], [held_r, 2]]:
		if cut & pair[1]:
			pair[0].visible = false

## tg blood-stained clothing on one layer
func set_stain(slot: String, on: bool) -> void:
	(layers[slot].material as ShaderMaterial).set_shader_parameter("stain", 1.0 if on else 0.0)
