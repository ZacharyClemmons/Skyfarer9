class_name CDecal extends Component
## Messes on the floor (blood, vomit, puddles, banana peels, scorch marks).
## Janitors clean them; wet ones and peels are slippery. Liquid decals carry a volume
## and are simulated by Liquids (spreading, freezing, burning, evaporating).

var kind := "blood"
var slippery := false
var cleanable := true
var dry_t := 0.0
var liquid := false
var volume := 0.0
var _spr := ""
# tg /obj/effect/decal/cleanable/blood (kind "blood", not liquid)
const BLOOD_AMOUNT_PER_DECAL := 50.0
const BLOOD_POOL_MAX := 300.0
const DRYING_TIME := 300.0 # tg 5 MINUTES
const DRIED_TINT := Color(0.42, 0.33, 0.33) # tg get_dried_color of wet red, as a multiplier
var blood := false # a tg blood decal (pool, splatter, drip, trail, gibs)
var blood_kind := "" # "pool", "splatter", "drip", "trail", "gibs"
var bloodiness := 0.0
var dried := false
var drying_time := DRYING_TIME
var total_dry_time := DRYING_TIME
var can_dry := true
var drops: Array = [] # drip: the drop sprites already on this tile

func key() -> StringName:
	return &"decal"

func setup(p: Dictionary) -> CDecal:
	kind = p.get("kind", kind)
	slippery = p.get("slippery", slippery)
	cleanable = p.get("cleanable", cleanable)
	dry_t = p.get("dry", 0.0)
	liquid = p.get("liquid", false)
	volume = p.get("volume", 20.0 if liquid else 0.0)
	blood_kind = p.get("blood", "")
	blood = blood_kind != ""
	if blood:
		bloodiness = p.get("bloodiness", {"pool": BLOOD_AMOUNT_PER_DECAL, "splatter": BLOOD_AMOUNT_PER_DECAL, "drip": 0.0, "trail": BLOOD_AMOUNT_PER_DECAL * 0.1, "gibs": BLOOD_AMOUNT_PER_DECAL}.get(blood_kind, BLOOD_AMOUNT_PER_DECAL))
		can_dry = p.get("can_dry", true)
		if p.get("dried", false):
			dried = true
			drying_time = 0.0
	return self

## tg adjust_bloodiness: up to BLOOD_POOL_MAX; new blood slows the drying (5 s a unit).
func adjust_bloodiness(by: float, ignore_timer := false) -> void:
	if by == 0.0 or e == null or e.removed:
		return
	bloodiness = clampf(bloodiness + by, 0.0, BLOOD_POOL_MAX)
	if bloodiness <= 0.0 and blood_kind != "drip":
		dry()
	elif not ignore_timer and by > 0.0:
		drying_time = minf(drying_time + 5.0 * by * 0.1, total_dry_time + 5.0 * by * 0.1)
		total_dry_time = maxf(total_dry_time, drying_time)
	_update_blood_color()

## tg drip stacking: another drop on the tile (up to 5 different ones).
func add_drop() -> bool:
	var used: Array = drops.duplicate()
	used.append(int(e.spr_name.get_slice("_", 2)) if e.spr_name.begins_with("blood_drop_") else -1)
	var free := []
	for i in 5:
		if not i in used:
			free.append(i)
	if free.is_empty():
		return false
	var v: int = free[Game.rng.randi() % free.size()]
	drops.append(v)
	var s := Sprite2D.new()
	s.texture = Gfx.tex("objects")
	s.region_enabled = true
	s.region_rect = Gfx.region("objects", "blood_drop_%d" % v)
	s.offset = e.spr.offset if e.spr else Vector2(0, -16)
	e.add_child(s)
	e.display_name = "drips of blood"
	return true

func dry() -> void:
	if dried:
		return
	dried = true
	drying_time = 0.0
	if e and e.display_name != "" and not e.display_name.begins_with("dried "):
		e.display_name = "dried " + e.display_name
	_update_blood_color()

## tg update_blood_color: wet red darkening toward the dried colour as it dries.
func _update_blood_color() -> void:
	if e == null:
		return
	var t := 1.0 if dried else clampf(1.0 - drying_time / maxf(1.0, total_dry_time), 0.0, 1.0)
	e.modulate = Color.WHITE.lerp(DRIED_TINT, t)

func add_volume(v: float) -> void:
	volume = minf(Liquids.MAX_VOLUME, volume + v)
	refresh_sprite()

func refresh_sprite() -> void:
	if not liquid:
		return
	var s := Liquids.sprite_for(kind, volume)
	if s != _spr:
		_spr = s
		e.set_sprite("objects", s)

func tick(dt: float) -> void:
	if liquid:
		Liquids.tick(self, dt)
		return
	if blood:
		# tg cleanable/blood/process: bloodiness decays as it dries over 5 minutes
		if dried or not can_dry:
			return
		if blood_kind != "trail":
			bloodiness = maxf(0.0, bloodiness - bloodiness / maxf(1.0, drying_time) * dt)
		drying_time -= dt
		if drying_time <= 0.0:
			dry()
		else:
			_update_blood_color()
		return
	if dry_t > 0:
		dry_t -= dt
		if dry_t <= 0:
			slippery = false
			if kind == "water":
				e.destroy()

func attackby(user: Entity, item: Entity) -> bool:
	if item.has_c(&"item") and item.c(&"item").tool == "mop" and cleanable:
		# tg: a dry mop does nothing; dip it in a bucket or a sink
		if not user.has_c(&"brain") and int(item.tags.get("wet", 0)) <= 0:
			Game.tell(user, "Your mop is dry!", "warn")
			return true
		DoAfter.start(user, e, 1.5, func(ok):
			if ok and is_instance_valid(e) and not e.removed:
				Bus.stimulus.emit({"type": "cleaned", "actor": user, "target": e, "cell": e.cell, "loud": 0.0})
				item.tags["wet"] = maxi(0, int(item.tags.get("wet", 0)) - 1)
				Janitor.wet_floor(e.cell)
				if liquid and volume > Liquids.MOP_VOLUME:
					volume -= Liquids.MOP_VOLUME
					refresh_sprite()
					Game.visible_message(e.cell, "%s mops up some of %s." % [user.display_name, e.the()])
				else:
					Game.visible_message(e.cell, "%s %s %s." % [user.display_name, "scrapes up" if kind == "ice" else "mops up", e.the()])
					e.destroy()
		)
		return true
	return false

func examine(_user: Entity, lines: Array) -> void:
	if blood and dried:
		lines.append("Looks like it's been here a while. Eew.")
	if liquid:
		lines.append("It looks %s." % ("like a thin film" if volume < 12 else ("like a sizeable puddle" if volume < 40 else "deep enough to splash in")))

func ai_tags(out: Dictionary) -> void:
	if cleanable:
		out["mess"] = true
	if slippery:
		out["slippery"] = true
	if liquid and kind == "fuel":
		out["fuel_spill"] = true
