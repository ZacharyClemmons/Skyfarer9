class_name CMob extends Component
## A living humanoid body in the world: identity, appearance, tile movement with
## SS13-style glide, facing, pulling, speech and radio. Player and NPC share this.

var real_name := "Unknown"
var job := "assistant"
var pronoun := "they" # they / she / he
var quirks: Array = [] # tg quirks (Quirks)
var appearance := {
	"skin": Color("#e0ac8a"), "hair": "short", "hair_color": Color("#4a2e1e"),
	"eyes": Color("#3a6ad8"), "facial": "", "underwear": Color("#3a4a6a"),
}
var dir := Defs.DIR_S
var buckled: Entity = null # the chair / bed we are strapped to (see Buckle)
var _buckle_note_t := 0.0
var _climb_note_t := 0.0
var doll: PaperDoll
var moving := false
var from_pos := Vector2.ZERO
var to_pos := Vector2.ZERO
var move_t := 1.0
var move_dur := 0.22
var step_parity := 0
var run := true
## tg intents: help, disarm, grab, harm. `combat` is true on anything but help (older
## code and the AI still flip that).
var _intent := "help"
var intent: String:
	get:
		return _intent
	set(v):
		_intent = v
var combat: bool:
	get:
		return _intent != "help"
	set(v):
		if v and _intent == "help":
			_intent = "harm"
		elif not v:
			_intent = "help"
## Burgerstation movement: sneaking is slow and quiet, and NPCs have to be close to
## notice you.
var sneak := false
## Set for one step when the mover means to go over the side (the player holding the jump
## modifier, or a script pushing someone off). Without it, walking into open sky is simply
## refused — you do not lose a character to a misread tile.
var allow_void := false
var auto_resist := false
## tg grab strength on whoever we're pulling: 0 passive, 1 aggressive, 2 neck.
var grab_state := 0
## Burgerstation's hotbar: six carried items bound to keys 5-9 and 0.
var hotbar: Array = [null, null, null, null, null, null]
var _resist_t := 0.0
var slur_t: float: # tg generic slurring (status "slurring" on the body)
	get: return health().status_left("slurring") if health() else 0.0
	set(v):
		if health():
			health().set_status("slurring", v)
var pulling: Entity = null
var pulled_by: Entity = null
var slide_dir := Vector2i.ZERO
var slide_left := 0
var flash_t := 0.0
var last_breath_fx := 0.0
var species_name := "human"
var xp := {} # skill -> experience (see Skills)
var attr_xp := {} # attribute -> experience
var internals := false
# combat (see Combat)
var zone := "chest" # body part you're aiming at (tg zone_selected), from `aim`
## Targeting: one point on the paper doll that both hands aim at, in three presets.
## Points are in doll pixels (32 x 48, see TargetDoll).
var aim := [Vector2(15, 18), Vector2(15, 6), Vector2(15, 37)]
var aim_preset := 0
var next_attack := 0.0
var last_area := -1
var trespass_t := 0.0
var breath_t := 0.0

func key() -> StringName:
	return &"mob"

func on_added() -> void:
	doll = PaperDoll.new()
	e.add_child(doll)
	refresh_doll()

func health() -> CHealth:
	return e.c(&"health")

func inv() -> CInventory:
	return e.c(&"inv")

func they() -> String:
	return pronoun

func their() -> String:
	return {"they": "their", "she": "her", "he": "his"}.get(pronoun, "their")

func them() -> String:
	return {"they": "them", "she": "her", "he": "him"}.get(pronoun, "them")

func can_move() -> bool:
	var h := health()
	return h == null or h.can_move()

func is_lying() -> bool:
	var h := health()
	return h != null and h.lying()

# ------------------------------------------------------------------ appearance
## tg COLOR_DARK_LIME / COLOR_ASSISTANT_OLIVE: the hulk and ork limb colour overrides
const HULK_SKIN := Color("#00aa00")
const ORK_SKIN := Color("#828163")
## what a monkey can show on its smaller body (tg: monkeys have their own worn icons for
## these; the rest don't fit)
const MONKEY_SLOTS := ["head", "mask", "back"]
const MONKEY_FUR := Color("#7a5230")
const MONKEY_FACE := Color("#e2b98c")

func refresh_doll() -> void:
	if doll == null:
		return
	# Sky creatures are one recoloured body layer rather than a dressed human skeleton.
	# The doll's facing and frame machinery still drives them, so they walk, turn and
	# take damage flashes exactly like anything else.
	if e.tags.has("beast"):
		_refresh_beast()
		return
	var a := appearance
	var monkey := Genetics.is_monkey(e)
	var skin: Color = a["skin"]
	var dn: CDna = e.c(&"dna")
	doll.visible = not e.has_meta("inside") and not (dn and dn.transforming())
	doll.animal_kind = dn.species if Traits.has(e, "animal_body") and dn else ""
	doll.psyker_head = Traits.has(e, "psyker")
	doll.queue_redraw()
	if doll.animal_kind != "":
		for slot in PaperDoll.ORDER:
			doll.set_layer(slot, "")
		doll.set_held(0, null)
		doll.set_held(1, null)
		_update_pose()
		return
	if dn:
		if dn.has_mutation("hulk_ork"):
			skin = ORK_SKIN
		elif dn.has_mutation("hulk") or dn.has_mutation("hulk_wizardly") or dn.has_mutation("hulk_superhuman"):
			skin = HULK_SKIN
	var hair_c: Color = a["hair_color"]
	var facial_c: Color = a.get("facial_color", hair_c)
	var under: Color = a["underwear"] if not Traits.has(e, "no_underwear") else Color(0, 0, 0, 0)
	if monkey:
		doll.set_layer("tail", "monkey_tail", [MONKEY_FUR])
		doll.set_layer("body", "monkey_body", [MONKEY_FUR, MONKEY_FACE, skin, Color("#1a1418")])
		doll.set_layer("eyes", "", [])
		doll.set_layer("facial", "", [])
		doll.hand_offset = Vector2(0, 5)
	else:
		doll.set_layer("tail", "", [])
		doll.set_layer("body", "body", [skin, under])
		doll.set_layer("eyes", "eyes", [a["eyes"], null, null, hair_c.darkened(0.3)])
		doll.set_layer("facial", ("facial_" + a["facial"]) if a["facial"] != "" else "", [facial_c])
		doll.hand_offset = Vector2.ZERO
	_mutation_overlays(dn)
	var hide_hair := monkey
	var inv_c := inv()
	for slot in ["uniform", "suit", "head", "mask", "gloves", "shoes", "back", "belt"]:
		var item: Entity = inv_c.worn(slot) if inv_c else null
		doll.set_layer_offset(slot, Vector2(0, 6) if monkey else Vector2.ZERO)
		if monkey and not slot in MONKEY_SLOTS:
			item = null
		if item and item.has_c(&"clothing"):
			var cl: CClothing = item.c(&"clothing")
			doll.set_layer(slot, cl.sprite, cl.colors)
			doll.set_stain(slot, Blood.bloody(item))
			if cl.hides_hair:
				hide_hair = true
		else:
			doll.set_layer(slot, "", [])
			doll.set_stain(slot, false)
	var gl: Entity = inv_c.worn("eyes") if inv_c else null
	if monkey:
		gl = null
	doll.set_layer("glasses", gl.c(&"clothing").sprite if gl and gl.has_c(&"clothing") else "", gl.c(&"clothing").colors if gl and gl.has_c(&"clothing") else [])
	doll.set_layer("hair", ("hair_" + a["hair"]) if (a["hair"] != "bald" and not hide_hair) else "", [hair_c])
	if inv_c:
		for k in 2:
			var held = inv_c.hands[k]
			if held != null and (not is_instance_valid(held) or held.removed):
				inv_c.hands[k] = null # destroyed while held without being let go
				held = null
			doll.set_held(k, held)
	_update_pose()
	update_size()

## tg mutation_icon_state overlays (MUTATIONS_LAYER and FRONT_MUTATIONS_LAYER), with the
## colours of tg's icons/effects/genetics.dmi states
## One body sprite per archetype, tinted by the creature's own four colours.
func _refresh_beast() -> void:
	var arch: String = str(e.tags.get("arch", "quad"))
	var pal: Array = e.tags.get("pal", ["#8a8a8a", "#5a5a5a", "#c0c0c0", "#303030"])
	var colors := []
	for c in pal:
		colors.append(Color(str(c)))
	for slot in PaperDoll.ORDER:
		doll.set_layer(slot, "", [])
	doll.set_layer("body", "beast_" + arch, colors)
	doll.animal_kind = ""
	doll.visible = true
	var sz: float = float(e.tags.get("size", 1.0))
	doll.scale = Vector2(sz, sz)
	doll.set_facing(dir, 0)
	_update_pose()

const MUT_COLORS := {"cold": [Color("#9ae0ff")], "fire": [Color("#ff8a2a"), Color("#ffd84a")],
	"pressure": [Color("#c8b8ff")], "radiation": [Color("#7aff5a")], "thermal": [Color("#ff5a3a"), Color("#5ab8ff")],
	"antenna": [Color("#9aa3b3"), Color("#ff3a3a")], "lasereyes": [Color("#ff2a2a")], "telekinesishead": [Color("#7ab8ff")]}
func _mutation_overlays(dn: CDna) -> void:
	var back := ""
	var front := ""
	if dn and not Genetics.is_monkey(e):
		for m in dn.mutations:
			var ic: String = m.def().get("icon", "")
			if ic == "":
				continue
			if m.id in ["antenna", "mindreader", "laser_eyes"]:
				front = "mut_" + ic
			else:
				back = "mut_" + ic
	doll.set_layer("mutation", back, MUT_COLORS.get(back.trim_prefix("mut_"), [Color.WHITE]))
	doll.set_layer("front_mutation", front, MUT_COLORS.get(front.trim_prefix("mut_"), [Color.WHITE]))

## tg mob height and transform: dwarfism (TRAIT_DWARF), acromegaly (TRAIT_TOO_TALL),
## gigantism (TRAIT_GIANT, x1.25) and the DNA height block.
const HEIGHT_SCALE := {"shortest": 0.88, "short": 0.94, "medium": 1.0, "tall": 1.06, "taller": 1.12}
func update_size() -> void:
	if doll == null:
		return
	var sx := 1.0
	var sy: float = HEIGHT_SCALE.get(appearance.get("height", "medium"), 1.0)
	if Genetics.is_monkey(e):
		sy = 1.0
	if Traits.has(e, "dwarf"):
		sy = 0.8
	if Traits.has(e, "too_tall"):
		sy = 1.18
	if Traits.has(e, "giant"):
		sx *= 1.25
		sy *= 1.25
	doll.scale = Vector2(sx, sy)

func _update_pose() -> void:
	var h := health()
	if h:
		h._sync_posture() # tg: being floored lies the body down, and it gets up after
	if doll == null:
		return
	# Creature art already depicts its natural stance. A live creature can still crawl
	# while floored, so the humanoid sideways pose makes its walk look flipped.
	var live_creature := (e.tags.has("beast") or doll.animal_kind != "") and (h == null or not h.dead)
	if is_lying() and not live_creature:
		doll.rotation = PI * 0.5
		doll.position = Vector2(-2, -8)
	else:
		doll.rotation = 0.0
		doll.position = Vector2.ZERO

func face(d: int) -> void:
	if dir != d:
		dir = d
		doll.set_facing(dir, 0 if not moving else 1 + step_parity)

# ------------------------------------------------------------------ movement
func step_time() -> float:
	var t := 0.21 if run else 0.38
	if e.get_meta("rock_buff", "") == "diamond": t -= 0.02
	var map := Game.map
	var fl := map.tflags(e.cell)
	if fl & Defs.F_SLOW:
		t *= 1.7
	var h := health()
	if h:
		t *= h.move_mult()
		t += Body.limbless_slowdown(h) # tg limbless movespeed modifier
		t += h.move_add() # tg damage slowdown, crawling, staggered
		if h.grasp != "":
			t += 0.05 # tg self_grasp slowdown 0.5
	var i := inv()
	if i:
		t *= 1.0 + i.slowdown()
	if pulling:
		t *= 1.25 if not pulling.has_c(&"mob") else 1.4
	if sneak:
		t *= 1.6
	# Skyfarer: tonics, curios, webbing and the weather all push on how fast you walk,
	# and they all go through one table so nothing has to remember to clear a flag.
	t *= SkyBuffs.step_mult(e)
	return t

## The body part this mob is aiming at.
func aimed_zone() -> String:
	return Combat.zone_at(aim[aim_preset])

func set_aim(point: Vector2) -> void:
	aim[aim_preset] = point
	zone = aimed_zone()

func set_aim_preset(i: int) -> void:
	aim_preset = clampi(i, 0, aim.size() - 1)
	zone = aimed_zone()

## Aim at the middle of a body part (the numpad keys).
func aim_at_zone(z: String) -> void:
	aim[aim_preset] = Combat.ZONE_CENTER.get(z, Vector2(15, 18))
	zone = z

## A quick lunge toward what you're hitting (visual only).
func lunge(at: Vector2i) -> void:
	if doll == null or moving or is_lying():
		return
	# tg do_attack_animation: 8 px toward the target with a 15 degree tilt, then back
	var dv := at - e.cell
	var d := Vector2(signi(dv.x), signi(dv.y)) * 8.0
	var tw := doll.create_tween()
	tw.tween_property(doll, "position", d, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(doll, "position", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_update_pose) # if they fell over mid-swing, lie down properly
	if is_zero_approx(doll.rotation):
		var turn := deg_to_rad(15.0) * (-1.0 if dv.x < 0 or (dv.x == 0 and Game.rng.randf() < 0.5) else 1.0)
		var rt := doll.create_tween()
		rt.tween_property(doll, "rotation", turn, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		rt.tween_property(doll, "rotation", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
		rt.tween_callback(_update_pose)

## tg caltrop component (glass shards): walking over glass crunches; a bare foot on it takes
## the shard's force to a leg and is paralysed for 2 seconds. Lying down or strapped in, you
## don't step on anything.
var _caltropped_t := -99.0
func _step_on(c: Vector2i) -> void:
	if is_lying() or buckled != null:
		return
	var sharp: Array = Game.at(c).filter(func(x): return x.has_c(&"item") and x.c(&"item").caltrop > 0.0)
	if sharp.is_empty():
		return
	Sfx.play("glass_step", c, 0.7)
	var h: CHealth = e.c(&"health")
	var inv: CInventory = e.c(&"inv")
	if h == null or inv == null or inv.worn("shoes") != null:
		return
	for s in sharp:
		var zone: String = ["l_leg", "r_leg"][Game.rng.randi() % 2]
		var light := Quirks.has(e, "light_step") # tg TRAIT_LIGHT_STEP
		h.hurt_zone(zone, s.c(&"item").caltrop * (0.75 if light else 1.0), "brute", null)
		if Game.time - _caltropped_t > 1.0: # tg /datum/status_effect/caltropped: one message a second
			_caltropped_t = Game.time
			Game.visible_message(c, "%s steps on %s." % [e.display_name, s.the()], "bad")
			Game.tell(e, "You step on %s!" % s.the(), "bad")
		if light:
			h.knockdown(2.0)
		else:
			h.paralyze(2.0) # tg caltrop paralyze_duration

func try_step(d: Vector2i) -> bool:
	if moving or d == Vector2i.ZERO:
		return false
	# tg relaymove: inside a machine, trying to walk out tries the door
	if e.has_meta("inside"):
		var box: Entity = Game.get_entity(e.get_meta("inside"))
		if box and box.has_c(&"dnascanner"):
			box.c(&"dnascanner").relaymove(e)
			return false
		if box and box.has_c(&"skillstation"):
			box.c(&"skillstation").relaymove(e)
			return false
		if box and box.has_c(&"storage"):
			box.c(&"storage").relaymove(e)
			return false
		if box and box.has_c(&"statue"): return false
		e.remove_meta("inside")
	if not can_move():
		return false
	var ch := health()
	if ch and ch.has_status("confusion"):
		d = StatusFx.confused_step(ch, d) # tg confusion: moves go astray
	if buckled != null:
		if not is_instance_valid(buckled) or buckled.removed or buckled.cell != e.cell:
			Buckle.unbuckle(null, e)
		else:
			if e == Game.player and Game.time > _buckle_note_t:
				_buckle_note_t = Game.time + 3.0
				Game.tell(e, "You're buckled to %s. Resist (B) to get up." % buckled.the(), "warn")
			return false
	if pulled_by != null and pulled_by.c(&"mob") != null:
		# resisting a pull: short tug (much harder against a tight grab)
		if Game.rng.randf() < resist_chance():
			Game.tell(e, "You break free of %s's grip." % pulled_by.display_name)
			pulled_by.c(&"mob").stop_pulling()
		return false
	face(Defs.dir_from_vec(d))
	var target := e.cell + d
	var map := Game.map
	if not map.inb(target):
		return false
	# diagonal: both orthogonals must be open (no corner cutting through walls)
	if d.x != 0 and d.y != 0:
		if map.blocks_move_static(e.cell + Vector2i(d.x, 0)) or map.blocks_move_static(e.cell + Vector2i(0, d.y)):
			return false
	for ent in Game.at(target):
		var door = ent.c(&"door")
		if door and not door.is_open():
			door.bump(e)
			return false
	if map.blocks_move_static(target) or map.dense_count[map.idx(target)] > 0:
		# A bulwark is waist-high — it stops you walking off, it does not stop you climbing.
		# This is how you get ashore, and it is the same rule the 3D view draws as a rail.
		if Climb.can_climb(e, target):
			Climb.start(e, target)
		elif e == Game.player and Game.time > _climb_note_t:
			var why := Climb.refusal(e, target)
			if why != "":
				_climb_note_t = Game.time + Climb.NOTE_GAP
				Game.tell(e, why, "warn")
		return false
	for ent in Game.at(target):
		if ent != e and ent != pulling and ent.has_c(&"mob") and not ent.c(&"mob").is_lying():
			if not _try_swap(ent):
				return false
			return true
	# Open sky. You do not walk off a ledge by accident in this game: a plain step into
	# nothing is refused with a warning, and only a deliberate jump, a shove, a throw or
	# an explosion actually puts you over.
	if not Falling.supported(target) and not Falling.airborne(e):
		if not allow_void:
			if e == Game.player:
				Game.tell(e, "[color=#e8a83a]That is open sky.[/color] Hold [b]Shift[/b] to step off deliberately.", "warn")
			return false
		allow_void = false
		_begin_move(target)
		Falling.check(e, true)
		return true
	_begin_move(target)
	return true

func _try_swap(other: Entity) -> bool:
	var om: CMob = other.c(&"mob")
	if combat or om.combat or om.moving or om.pulled_by != null or not om.can_move():
		return false
	# passengers keep their seats on the evacuation crawler
	if Game.evac and Game.evac.is_aboard(other):
		return false
	var mine := e.cell
	_begin_move(other.cell)
	om._begin_move(mine, false)
	return true

func _begin_move(target: Vector2i, drag_pulled := true) -> void:
	if e.has_meta("inside"):
		return
	var old := e.cell
	from_pos = e.position
	if Game.fleet != null:
		var sh: Airship = Game.fleet.ship_of(e)
		if sh != null:
			from_pos = sh.simulation_position(e)
	e.place(target, false)
	_step_on(target)
	to_pos = Entity.cell_to_pos(target)
	move_t = 0.0
	move_dur = step_time()
	moving = true
	step_parity ^= 1
	var lh := health()
	if lh:
		move_dur += Body.limp_step(lh, step_parity) # tg limp: a wounded leg drags
	doll.set_facing(dir, 1 + step_parity)
	if drag_pulled and pulling != null:
		if not is_instance_valid(pulling) or pulling.removed or pulling.holder != null or pulling.has_meta("inside") or pulling.dist_to(e) > 2:
			stop_pulling()
		elif pulling.cell != old and pulling.cell != target:
			var pm = pulling.c(&"mob")
			if pm:
				pm.face(Defs.dir_from_vec(old - pulling.cell))
				pm._begin_move(old, false)
			else:
				Interact.glide(pulling, old, move_dur)
	if Game.view:
		Game.view.on_step(e, old, target)

var _jitter_t := 0.0
var _gore_t := 0.0

## tg update_body_parts/update_wound_overlays: missing limbs and bleed overlays on the doll.
func _update_gore(h: CHealth) -> void:
	var cut := 0
	var bits := {"l_arm": 1, "r_arm": 2, "l_leg": 4, "r_leg": 8}
	for p in bits:
		if h.missing.has(p):
			cut |= bits[p]
	var fake: String = h.get_meta("fake_bleed_part", "") if e == Game.player else ""
	var lv := func(p: String) -> float: return 3.0 if p == fake else float(Body.bleed_overlay_level(Body.part_bleed_rate(h, p)))
	doll.set_gore(cut, Vector4(lv.call("l_arm"), lv.call("r_arm"), lv.call("l_leg"), lv.call("r_leg")), Vector2(lv.call("chest"), lv.call("head")))

## The ground under this mob moved (a ship restamped beneath them). Carry the step they
## are part-way through along with it, so they glide on from where they now are instead of
## being yanked back toward a tile that is no longer there.
func carry_by(offset: Vector2) -> void:
	if not moving:
		return
	from_pos += offset
	to_pos += offset

func process(delta: float) -> void:
	# tg jitter: the body shakes (do_jitter_animation, 0.2 s steps)
	var jh := health()
	if jh and doll:
		var base := Vector2(-2, -8) if is_lying() else Vector2.ZERO
		if jh.has_status("jitter"):
			_jitter_t -= delta
			if _jitter_t <= 0.0:
				_jitter_t = 0.2
				doll.position = base + StatusFx.jitter_offset(jh)
		elif doll.position != base:
			doll.position = base
	if flash_t > 0:
		flash_t = maxf(0.0, flash_t - delta * 3.0)
		doll.set_flash(flash_t)
	if jh and doll:
		_gore_t -= delta
		if _gore_t <= 0.0:
			_gore_t = 0.5
			_update_gore(jh)
	# Burgerstation auto-resist: struggle against grabs and put yourself out on your own
	if auto_resist and pulled_by != null:
		_resist_t -= delta
		if _resist_t <= 0.0:
			_resist_t = 1.5
			if Game.rng.randf() < resist_chance():
				Game.visible_message(e.cell, "%s breaks free of %s's grip!" % [e.display_name, pulled_by.display_name], "warn")
				pulled_by.c(&"mob").stop_pulling()
	if not moving:
		return
	move_t += delta / move_dur
	if move_t >= 1.0:
		move_t = 1.0
		moving = false
		e.position = to_pos
		doll.set_facing(dir, 0)
		_on_arrive()
	else:
		e.position = from_pos.lerp(to_pos, move_t)
		if move_t > 0.55:
			doll.set_facing(dir, 0)

func _on_arrive() -> void:
	if Falling.check(e):
		return
	var hh := health()
	if hh and hh.has_meta("hazard"):
		Hallucinations.on_step(hh, e.cell)
	if hh and not hh.embedded.is_empty():
		Embeds.on_move(hh, not run)
	GeneFx.on_moved(e) # tg COMSIG_MOVABLE_MOVED (acromegaly, two left feet, chameleon)
	if e.removed:
		return
	for x in Game.at(e.cell):
		if x.has_c(&"web"):
			x.c(&"web").on_entered(e) # tg stickyweb on_entered
		if x != e and x.get_meta("rock_buff", "") == "bananium" and x.has_c(&"health") and x.c(&"health").lying() and run and not Traits.has(e, "no_slip_water"):
			health().knockdown(12.0)
	var fl := Game.map.tflags(e.cell)
	# tg TRAIT_NO_SLIP_ICE (cold adaptation): sure-footed on ice
	if fl & Defs.F_SLIPPERY and run and slide_left == 0 and not Traits.has(e, "no_slip_ice") and Game.rng.randf() < 0.55:
		slide_dir = Defs.DIRS4[dir]
		slide_left = Game.rng.randi_range(1, 3)
		Game.tell(e, "You slip on the slick footing!", "warn")
		CMood.event(e, "slipped", "slipped")
	elif slide_left > 0:
		slide_left -= 1
		if slide_left == 0 and Game.rng.randf() < 0.3:
			health().knockdown(2.0)
			Game.visible_message(e.cell, "%s falls over on the slick footing." % e.display_name)
	if slide_left > 0:
		var d := slide_dir
		if not try_step(d):
			slide_left = 0
	# slippery puddles / banana peels (tg: /datum/component/slippery)
	for ent in Game.at(e.cell):
		var dec = ent.c(&"decal")
		# tg /datum/plant_gene/trait/slip: the fruit itself is the hazard
		if dec == null and ent.get_meta("slippery", false) and not is_lying() and ent.holder == null:
			Game.tell(e, "You slipped on %s!" % ent.the(), "warn")
			CMood.event(e, "slipped", "slipped")
			health().knockdown(6.0)
			Body.on_slipped(health())
			Game.visible_message(e.cell, "%s slips on %s!" % [e.display_name, ent.display_name], "warn")
			Bus.stimulus.emit({"type": "slip", "actor": e, "target": ent, "cell": e.cell, "loud": 4.0})
			Sfx.play("slip", e.cell)
			Botany.on_slipped_on(ent, e)
			break
		# tg wet_floor / slippery intensities: water 6 s (not while walking), ice 12 s,
		# soap 8 s, banana peel 6 s, oil 8 s
		var slip_kd: float = {"water": 6.0, "ice": 12.0, "soap": 8.0, "peel": 6.0, "oil": 8.0}.get(dec.kind if dec else "", 6.0)
		if dec and dec.slippery and dec.kind == "ice" and Traits.has(e, "no_slip_ice"):
			continue
		if dec and dec.slippery and not is_lying() and (run or dec.kind != "water"):
			Game.tell(e, "You slipped on %s!" % ent.the(), "warn")
			CMood.event(e, "slipped", "slipped")
			health().knockdown(slip_kd)
			Body.on_slipped(health())
			Game.visible_message(e.cell, "%s slips on %s!" % [e.display_name, ent.display_name], "warn")
			Bus.stimulus.emit({"type": "slip", "actor": e, "target": ent, "cell": e.cell, "loud": 4.0})
			Sfx.play("slip", e.cell)
			break

## Forced movement (wind, being shoved). Ignores can_move.
func push(d: Vector2i) -> bool:
	if moving:
		return false
	var target := e.cell + d
	var map := Game.map
	if map.blocks_move_static(target) or map.dense_count[map.idx(target)] > 0:
		return false
	for ent in Game.at(target):
		if ent.has_c(&"door") and not ent.c(&"door").is_open():
			return false
	_begin_move(target, false)
	return true

# ------------------------------------------------------------------ pulling (ctrl+click)
func start_pulling(target: Entity) -> void:
	if not is_instance_valid(target) or target.removed or target.has_meta("inside") or e.has_meta("inside") or not e.adjacent(target):
		return
	var dn: CDna = e.c(&"dna")
	if dn and dn.has_mutation("elastic_arms"):
		var it: CItem = target.c(&"item")
		if (it and it.w_class > 4) or Traits.has(target, "giant"):
			Game.tell(e, "Your arms are too floppy to pull that!", "warn")
			return
	if target == e or target.holder != null:
		return
	if target.has_c(&"blocker") and target.c(&"blocker").dense and not target.has_c(&"mob"):
		if target.tags.get("anchored", true):
			Game.tell(e, "It won't budge.")
			return
	stop_pulling()
	pulling = target
	var tm = target.c(&"mob")
	if tm:
		tm.pulled_by = e
	if target.has_c(&"monkeyai"):
		target.c(&"monkeyai").on_pulled(e) # tg COMSIG_LIVING_START_PULL
	Game.tell(e, "You start pulling %s." % target.the())

## The chance a struggle breaks the grip we're in.
func resist_chance() -> float:
	if pulled_by == null:
		return 1.0
	var gm: CMob = pulled_by.c(&"mob")
	var st: int = gm.grab_state if gm else 0
	if Quirks.has(e, "pushover"):
		st += 1 # tg TRAIT_GRABWEAKNESS
	var base: float = [0.4, 0.15, 0.05, 0.0][mini(st, 3)]
	return base + Skills.attr_level(e, "strength") * 0.002

func stop_pulling() -> void:
	grab_state = 0
	if is_instance_valid(pulling):
		var tm = pulling.c(&"mob")
		if tm and tm.pulled_by == e:
			tm.pulled_by = null
	pulling = null

# ------------------------------------------------------------------ speech
func say(text: String) -> void:
	text = text.strip_edges()
	if text == "":
		return
	var h := health()
	if h and h.stat() != CHealth.CONSCIOUS and h.stat() != CHealth.SOFT_CRIT:
		return
	if h and h.has_status("silence"):
		return
	var channel := ""
	if text.begins_with(";"):
		channel = "Common"
		text = text.substr(1).strip_edges()
	elif text.begins_with(":") and text.length() > 1:
		var k := text.substr(1, 1).to_lower()
		for d in Defs.DEPARTMENTS.values():
			if d["key"] == k:
				channel = d["radio"]
		text = text.substr(2).strip_edges()
	if text == "":
		return
	# tg TRAIT_MUTE (the mute mutation): can_speak fails
	if Traits.has(e, "mute"):
		Game.tell(e, "You find yourself unable to speak!", "warn")
		return
	# tg COMSIG_MOB_SAY: the mutations' speech (hulk, swedish, medieval, stoner...), then
	# the species' language (monkeys only speak Chimpanzee)
	var gs := GeneFx.treat_speech(e, text)
	text = gs["text"]
	if Traits.has(e, "musical_chip"): text = SkillChips.sing(text)
	if Species.language(e) == "monkey":
		text = Species.scramble("monkey", text)
	if text == "":
		return
	if h:
		text = StatusFx.treat_message(h, text)
		if text == "":
			return
	# what a mind reader can pick up (tg copy_recent_speech)
	var said: Array = e.get_meta("recent_speech", [])
	said.append(text)
	if said.size() > 10:
		said.pop_front()
	e.set_meta("recent_speech", said)
	text = Quirks.anxious_speech(e, text) # tg social_anxiety
	if text == "" or (h and h.has_status("silence")):
		return
	# tg TRAIT_FORCE_WHISPER in soft crit (or pushing on through it, inexorable), or soft-spoken
	if h and (h.stat() == CHealth.SOFT_CRIT or Quirks.has(e, "softspoken") or Traits.has(e, "force_whisper")):
		Bus.speech.emit(e, text, e.cell, 1.0)
		return
	if channel != "":
		radio(channel, text, {})
		return
	Bus.speech.emit(e, text, e.cell, 2.0 if sneak else 7.0)

func radio(channel: String, text: String, fact: Dictionary) -> bool:
	var hs := inv().headset() if inv() else null
	if has_antenna() and channel == "Common" and (hs == null or not hs.enabled or not channel in hs.channels):
		# tg /obj/item/implant/radio/antenna: an internal radio on the common channel
		Bus.speech.emit(e, text, e.cell, 2.0)
		if Game.power == null or Game.power.telecomms_ok():
			Bus.radio.emit(e, channel, text, fact)
		return true
	if hs == null or not hs.enabled or not channel in hs.channels:
		Bus.speech.emit(e, text, e.cell, 7.0)
		return false
	Bus.speech.emit(e, text, e.cell, 2.0) # muttered into the headset
	if Game.power == null or Game.power.telecomms_ok():
		Bus.radio.emit(e, channel, text, fact)
	else:
		Game.tell(e, "Your headset crackles with static.", "warn")
	return true

## tg antenna mutation: an internal radio implant
func has_antenna() -> bool:
	var dn: CDna = e.c(&"dna")
	return dn != null and dn.has_mutation("antenna")

## A free-text emote ("reads the notices"), like tg manual_emote: seen, not heard.
func emote(text: String) -> void:
	Game.visible_message(e.cell, "[i]%s %s[/i]" % [e.display_name, text], "emote")

## A tg emote by key ("scream", "cough", "nod Bob"). Involuntary unless `intentional`.
func do_emote(act: String, intentional := false) -> bool:
	return Emotes.emote(e, act, intentional)

## tg emote animations (animate() on pixel_w / transform in the emote datums).
func emote_anim(kind: String) -> void:
	if doll == null:
		return
	var base := doll.position
	var tw := doll.create_tween()
	match kind:
		"flip", "backflip":
			# tg SpinAnimation over FLIP_EMOTE_DURATION (0.7 s)
			var r0 := doll.rotation
			tw.tween_property(doll, "rotation", r0 + (TAU if kind == "flip" else -TAU), 0.7)
			tw.tween_callback(_update_pose)
		"spin", "spin_short":
			# tg spin(): turn through the four directions every 0.1 s
			var steps := 20 if kind == "spin" else 4
			for i in steps:
				tw.tween_callback(face.bind([Defs.DIR_N, Defs.DIR_E, Defs.DIR_S, Defs.DIR_W][(dir + i + 1) % 4]))
				tw.tween_interval(0.1)
		"shiver", "tremble":
			var amp := 1.0 if kind == "shiver" else 2.0
			var step := 0.1 if kind == "shiver" else 0.2
			for i in (5 if kind == "shiver" else 11):
				tw.tween_property(doll, "position:x", base.x - amp, step)
				tw.tween_property(doll, "position:x", base.x + amp, step)
			tw.tween_property(doll, "position:x", base.x, step)
		"twitch":
			for x in [1.0, -1.0, -1.0, 1.0, 0.0]:
				tw.tween_property(doll, "position:x", base.x + x, 0.1)
		"twitch_s":
			tw.tween_property(doll, "position:x", base.x - 1.0, 0.1)
			tw.tween_property(doll, "position:x", base.x, 0.1)
		"sway":
			tw.tween_property(doll, "position:x", base.x + 2.0, 0.5)
			for i in 2:
				tw.tween_property(doll, "position:x", base.x - 4.0, 1.0)
				tw.tween_property(doll, "position:x", base.x + 2.0, 1.0)
			tw.tween_property(doll, "position:x", base.x, 0.5)
		"jump":
			tw.tween_property(doll, "position:y", base.y - 4.0, 0.1)
			tw.tween_property(doll, "position:y", base.y, 0.1)

func hurt_flash() -> void:
	flash_t = 0.8

func examine(user: Entity, lines: Array) -> void:
	lines[0] = "This is [b]%s[/b]%s." % [Quirks.seen_name(user, e), (", the " + SkyClasses.title_of(e)) if job != "" and not Quirks.has(user, "prosopagnosia") else ""]
	# tg /datum/component/empathy (the Empath quirk)
	if user != e and Quirks.has(user, "empath"):
		var th: CHealth = health()
		if th and not th.dead and not th.has_status("fakedeath"):
			var they := self.they().capitalize()
			var s := "" if pronoun == "they" else "s"
			if combat: lines.append("%s seem%s to be on guard." % [they, s])
			if th.oxy >= 10.0: lines.append("%s seem%s winded." % [they, s])
			if th.tox >= 10.0: lines.append("%s seem%s sickly." % [they, s])
			var md: CMood = e.c(&"mood")
			if md and md.sanity <= CMood.SANITY_DISTURBED: lines.append("%s seem%s distressed." % [they, s])
			if StatusFx.blind(th): lines.append("%s appear%s to be staring off into space." % [they, s])
			if StatusFx.deaf(th): lines.append("%s appear%s to not be responding to noises." % [they, s])
			if th.body_temp > Defs.BODYTEMP_HEAT_DAMAGE_LIMIT: lines.append("%s %s flushed and wheezing." % [they, "are" if pronoun == "they" else "is"])
			if th.body_temp < Defs.BODYTEMP_COLD_DAMAGE_LIMIT: lines.append("%s %s shivering." % [they, "are" if pronoun == "they" else "is"])
	if user != e and user.has_c(&"brain") == false and e.has_c(&"brain"):
		var br = e.c(&"brain")
		var rel = br.rel_to(user)
		if rel != null:
			var att := "seems indifferent toward you"
			if rel.affinity > 40:
				att = "looks at you warmly"
			elif rel.affinity > 15:
				att = "seems friendly toward you"
			elif rel.affinity < -40:
				att = "glares at you"
			elif rel.affinity < -15:
				att = "seems wary of you"
			lines.append("[color=#9ab8d8]%s %s.[/color]" % [they().capitalize(), att])
		var mood: String = br.mood_word()
		if mood != "":
			lines.append("[color=#9ab8d8]%s %s.[/color]" % [they().capitalize(), mood])
		var hint := _persona_hint(br)
		if hint != "":
			lines.append("[color=#8a9cb0]%s[/color]" % hint)

## Little things you'd notice about someone.
func _persona_hint(br) -> String:
	var p = br.persona
	if p == null:
		return ""
	var hints := []
	if p.has_quirk("smoker"):
		hints.append("%s smell%s faintly of cigarettes." % [they().capitalize(), "" if pronoun == "they" else "s"])
	if p.has_interest("knitting"):
		hints.append("%s a lumpy hand-knitted scarf." % ("They wear" if pronoun == "they" else they().capitalize() + " wears"))
	if p.has_quirk("neat_freak"):
		hints.append("Not a speck of dirt on %s." % them())
	if p.has_quirk("daydreamer"):
		hints.append("%s look%s miles away." % [they().capitalize(), "" if pronoun == "they" else "s"])
	if p.has_interest("fitness"):
		hints.append("%s look%s like %s work%s out." % [they().capitalize(), "" if pronoun == "they" else "s", they(), "" if pronoun == "they" else "s"])
	if p.has_quirk("coffee"):
		hints.append("There's a cocoa stain on %s sleeve." % their())
	if p.has_interest("religion"):
		hints.append("A small charm hangs around %s neck." % their())
	if p.has_interest("geology") or p.has_quirk("collector"):
		hints.append("%s pockets rattle with pebbles." % their().capitalize())
	if hints.is_empty():
		return ""
	return hints[hash(e.id) % hints.size()]

func verbs(user: Entity, out: Array) -> void:
	if user == e:
		return
	if user.adjacent(e):
		if pulled_by == user:
			out.append({"name": "Stop pulling", "cb": user.c(&"mob").stop_pulling, "priority": 3})
		else:
			out.append({"name": "Pull", "cb": user.c(&"mob").start_pulling.bind(e), "priority": 3})
		if health() and health().stat() != CHealth.CONSCIOUS and health().stat() != CHealth.DEAD:
			out.append({"name": "Perform CPR", "cb": Interact.cpr.bind(user, e), "priority": 8})
		out.append({"name": "Shake / help up", "cb": Interact.help_hand.bind(user, e), "priority": 4})
	if e.has_c(&"brain") and user.dist_to(e) <= 3:
		out.append({"name": "Talk to", "cb": func(): Bus.ui_open_window.emit("talk", e), "priority": 9})
	if e.has_c(&"brain") and Game.hud and Game.hud.debug_ai:
		out.append({"name": "Read mind (debug)", "cb": func(): Bus.ui_open_window.emit("mind", e), "priority": 1})

func ai_tags(out: Dictionary) -> void:
	if Genetics.is_monkey(e):
		out["monkey"] = true # tg TRAIT_LESSER_HUMANOID: not somebody to talk to
		return
	out["person"] = true
