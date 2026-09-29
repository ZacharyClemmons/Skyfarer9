class_name CClothing extends Component
## Wearable. `layer` names the paper-doll slot and `sprite` the mobs.png layer.
## Insulation (0..1) slows body heat exchange with the environment (arctic survival!).

var slot := "uniform"
var sprite := ""
var colors: Array = []
var insulation := 0.0
var heat_protection := 0.0 # vs fire
var armor := 0.0
var hides_hair := false
var hides_face := false
var breath_mask := false # can connect to internals
var gas_filter := false
var slowdown := 0.0
var insulated_gloves := false
# tg armour against projectiles, 0-100, and space-suit pressure sealing
var bullet_armor := 0.0
var laser_armor := 0.0
var energy_armor := 0.0
var covered_zones: Array = []
var pressure_proof := false
var covers_eyes := false # tg EYES_COVERED (blindfolds, welding masks down)
var vision_correction := false # tg glasses vision_correction: fixes nearsightedness
var wound_armor := 0.0 # tg armor[WOUND]: cuts the wound roll by this percentage

func key() -> StringName:
	return &"clothing"

## Melee armour, 0-100 like tg's armor datums (this game stored it as 0-1).
func melee_armor() -> float:
	return armor * 100.0

func setup(p: Dictionary) -> CClothing:
	slot = p.get("slot", slot)
	vision_correction = p.get("vision_correction", false)
	sprite = p.get("sprite", sprite)
	colors = []
	for c in p.get("colors", []):
		colors.append(Color(c))
	insulation = p.get("insulation", insulation)
	heat_protection = p.get("heat", heat_protection)
	armor = p.get("armor", armor)
	hides_hair = p.get("hides_hair", hides_hair)
	hides_face = p.get("hides_face", hides_face)
	breath_mask = p.get("breath", breath_mask)
	gas_filter = p.get("filter", gas_filter)
	slowdown = p.get("slow", slowdown)
	insulated_gloves = p.get("insulated", insulated_gloves)
	bullet_armor = p.get("bullet", bullet_armor)
	laser_armor = p.get("laser", laser_armor)
	energy_armor = p.get("energy", laser_armor)
	covered_zones = p.get("covers", []).duplicate()
	pressure_proof = p.get("pressure", pressure_proof)
	wound_armor = p.get("wound", wound_armor)
	covers_eyes = p.get("covers_eyes", covers_eyes)
	return self

func covers_zone(zone: String, worn_slot: String) -> bool:
	var coverage: Array = covered_zones if not covered_zones.is_empty() else Combat.COVERS.get(worn_slot, [])
	return zone in coverage or Body.part_of(zone) in coverage

func on_added() -> void:
	refresh_icon()

## Clothing lying around or in a hand shows its own icon in its own colours
## (tools/artgen/wear_icons.py), drawn with the same recolouring as the worn sprite.
func refresh_icon() -> void:
	var icon := "icon_" + sprite
	if e == null or not Gfx.has("mobs", icon):
		return
	e.set_sprite("mobs", icon)
	e.spr.material = Gfx.doll_material(colors)
	e.spr.modulate = Color.WHITE

func examine(_user: Entity, lines: Array) -> void:
	if insulation >= 0.3:
		lines.append("[color=#8ad8ff]It looks warm.[/color]")
	if insulated_gloves:
		lines.append("[color=#ffd84a]They are electrically insulated.[/color]")
	if armor > 0:
		lines.append("It offers some protection against blows.")

func ai_tags(out: Dictionary) -> void:
	out["clothing"] = true
	if insulation >= 0.3:
		out["warm_clothing"] = true
	if breath_mask:
		out["breath_mask"] = true
	if insulated_gloves:
		out["insulated_gloves"] = true
