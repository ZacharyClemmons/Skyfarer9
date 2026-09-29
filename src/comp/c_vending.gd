class_name CVending extends Component
## Vending machines: free rations for crew, as on most SS13 stations. Stock runs out;
## cargo can restock with supply crates.

var products: Array = [] # [{proto, count}]

func key() -> StringName:
	return &"vending"

func setup(p: Dictionary) -> CVending:
	products = []
	for pr in p.get("products", []):
		products.append({"proto": pr[0], "count": pr[1]})
	return self

func vend(user: Entity, proto: String) -> Entity:
	var m: CMachine = e.c(&"machine")
	if m and not m.operable():
		Game.tell(user, "%s is dark and unresponsive." % e.the().capitalize(), "warn")
		return null
	for p in products:
		if p["proto"] == proto and p["count"] > 0:
			p["count"] -= 1
			var it := Proto.spawn(proto, e.cell)
			var inv = user.c(&"inv")
			if inv:
				inv.put_in_hands(it)
			Sfx.play("vend", e.cell)
			Game.visible_message(e.cell, "%s vends %s." % [e.the().capitalize(), it.display_name])
			return it
	return null

func has_stock(cat: String = "") -> bool:
	for p in products:
		if p["count"] > 0 and (cat == "" or Proto.category(p["proto"]) == cat):
			return true
	return false

func first_in_stock(cat: String) -> String:
	for p in products:
		if p["count"] > 0 and Proto.category(p["proto"]) == cat:
			return p["proto"]
	return ""

func attack_hand(_user: Entity) -> bool:
	Bus.ui_open_window.emit("vending", e)
	return true

func restock() -> void:
	for p in products:
		p["count"] += 6

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Browse", "cb": attack_hand.bind(user), "priority": 7})

func ai_tags(out: Dictionary) -> void:
	out["vending"] = true
	for p in products:
		if p["count"] > 0:
			out["sells_" + Proto.category(p["proto"])] = true
