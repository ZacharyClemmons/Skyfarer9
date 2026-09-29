class_name CVendor extends Component
## Somebody who will sell you something, and buy what you are carrying.
##
## A vendor is a person, not a machine. They have a trade, a stock list that restocks
## slowly, a mood about you that moves with how much you spend and whether you have done
## anything for them, and an opinion about what their port needs. Talking to them is how
## you find out what a trade route is worth, because the alternative is a wiki.
##
## Stock is generated from the vendor's trade and the port's tier rather than listed by
## hand, so a yard on a far island genuinely carries better engines than the one you
## started at, and you find that out by going there.

## trade -> what they deal in, and the tone they take about it
const TRADES := {
	"shipwright": {"name": "Shipwright", "cats": ["thruster", "propeller", "lift", "boiler", "dynamo", "bunker", "armor"],
		"greet": "Mind the sawdust. What is she missing?",
		"idle": ["Everything in here will make her faster or make her lighter. Not both.", "Anybody can bolt an engine on. Getting the trim right afterwards is the trade.", "You want the bigger thruster. Then you want the bunker to feed it."],
		"blurb": "Hulls, engines and everything that makes one go."},
	"rigger": {"name": "Sailmaker", "cats": ["mast", "utility"],
		"greet": "Canvas, cordage, or are you here to complain about the last lot?",
		"idle": ["Canvas is free speed, and free speed is the only free thing up here.", "A lateen rig sails closer to the wind than you will believe until you try it.", "Patch your cells before they need it. After is a different conversation."],
		"blurb": "Canvas, cordage, cells and the things that hold them on."},
	"gunsmith": {"name": "Gunsmith", "cats": ["gun"],
		"greet": "Whatever you shot at, it is not my fault you missed.",
		"idle": ["Guns bear on the beam. Point your side at them, not your nose.", "Scatter for anything with wings. Ball for anything with a hull.", "A long nine will reach somebody who has not noticed you yet."],
		"blurb": "Ship guns, hand guns, and opinions about both."},
	"artificer": {"name": "Artificer", "cats": ["nav", "helm"],
		"greet": "Do not touch the ones that are humming.",
		"idle": ["A sounder sees through fog. You do not.", "Aetherite wants to go up. The trade is persuading it to go up slowly.", "Storm glass hums before the weather turns. Listen to it."],
		"blurb": "Instruments, helms and aetherite work."},
	"quartermaster": {"name": "Quartermaster", "cats": [],
		"greet": "Tools, fuel, rations. If you want clever, that is three doors down.",
		"idle": ["Buy two fuel cans. Everybody comes back for the second one.", "A glider harness costs a great deal less than a funeral.", "Rations are not good. They are not meant to be good."],
		"blurb": "Tools, fuel, rations and the boring things that keep you alive."},
	"curiosity": {"name": "Curio dealer", "cats": [],
		"greet": "Everything here works. I did not say how.",
		"idle": ["No refunds, no explanations, and nothing returned after dark.", "That one belonged to somebody who is not using it any more.", "You are looking at the bell. Everybody looks at the bell. Do not ring the bell."],
		"blurb": "Objects of uncertain provenance and specific effect."},
	"broker": {"name": "Cargo broker", "cats": [],
		"greet": "Show me what you have got and I will tell you what it is worth here.",
		"idle": ["Buy where it is common, sell where it is not. That is the entire book.", "Every port wants something. Ask, then go and get it.", "Hold space is money sitting still. Fill it."],
		"blurb": "Buys anything. Pays what the port thinks it is worth, not what you do."},
}

## What the plain-goods traders carry, by tier. Modules come out of ShipParts instead.
const GOODS := {
	"quartermaster": [
		[0, ["fuel_can", "sheet_wood", "sheet_metal", "sheet_glass", "cable_coil", "rods",
			"rations_sky", "flashlight", "toolbox", "crowbar", "wrench", "screwdriver"]],
		[1, ["welder", "pickaxe", "axe_felling", "forage_knife", "skinning_knife", "sail_needle",
			"breathing_rig", "medkit", "glider_pack"]],
		[2, ["multitool", "salvage_saw", "artificers_kit", "sky_rod", "grapple_gun", "sky_compass",
			"ship_rig", "spyglass"]],
		[3, ["axe_ironwood", "pick_aether", "tonic_breath", "tonic_ironhide"]],
	],
	# a broker always has bulk trade goods on the shelf, whatever the port makes itself
	"broker": [
		[0, ["sky_timber", "fibre_bundle", "meat_raw", "fuel_can", "sheet_metal", "salvage_scrap"]],
		[1, ["ore_iron", "iron_ingot", "sporecap", "beast_hide", "sheet_glass"]],
		[2, ["ore_skyglass", "ore_sulfur", "marrow_oil", "canvas_bolt"]],
		[3, ["ore_aetherite", "skyglass_lens", "aether_ingot"]],
	],
	"curiosity": [
		[0, ["chart_scrap", "tin_of_stars"]],
		[1, ["liars_compass", "boiling_flask", "pocket_updraft", "tonic_lift", "tonic_wind"]],
		[2, ["shrieking_bell", "anchor_charm", "echo_shell", "ledger_of_owed", "tonic_clarity"]],
		[3, ["gravity_sink", "thinking_cap", "drowned_mans_lung", "cartographers_eye", "quiet_knife"]],
	],
	"gunsmith": [
		[0, ["harpoon", "boarding_axe"]],
		[1, ["scattergun", "aether_pistol"]],
		[2, ["cutlass_brine", "cinder_maul"]],
		[3, ["lance_carbine", "stormblade"]],
	],
}

## What each trader says when money changes hands. They answer every deal in their own
## voice: `buy` for an ordinary sale to you, `big` for a serious one, `sell` when you sell
## to them, `bulk` when you empty your pockets onto the counter, `deny` when you cannot pay
## and `regular` once you have spent real money across this counter.
const BARKS := {
	"shipwright": {
		"buy": ["Bolt it down tight.", "Mind the trim when she's loaded.", "Good iron. Treat it kindly.", "That will hold. I would not sell it otherwise."],
		"big": ["Now that is a proper refit. Bring her round and I will look it over.", "You have just made my week, and her hull's."],
		"sell": ["I can use that.", "Scrap today, a bulkhead tomorrow.", "Fair weight. Fair price."],
		"bulk": ["The whole lot? I will need a bigger bench."],
		"deny": ["Iron costs what iron costs.", "Come back with the rest of it."],
		"regular": ["Back again. Your hull is going to be the best in the Reach."]},
	"rigger": {
		"buy": ["Splice it before you stow it.", "Good canvas. Do not let it get damp.", "That will take a gale, and a bit more."],
		"big": ["That is a serious amount of cloth. Somebody is going places."],
		"sell": ["I will find a use for it.", "Thread is thread.", "Mm. It's a start."],
		"bulk": ["You are emptying the hold onto my counter, friend."],
		"deny": ["Canvas is not free, and neither is my time."],
		"regular": ["My best customer. Do not tell the others."]},
	"gunsmith": {
		"buy": ["Do not point it at me.", "Clean it after every use.", "It kicks. You have been warned."],
		"big": ["That is a lot of firepower. Try to use it on the right people."],
		"sell": ["Hm. Serviceable.", "I will strip it for parts.", "Not what I would call a bargain."],
		"bulk": ["I do not need this much of your scrap."],
		"deny": ["No credit. Not with what I sell."],
		"regular": ["The usual? Good. Come again."]},
	"artificer": {
		"buy": ["Do not shake it.", "It will hum. That is normal. Mostly.", "Calibrate it before you trust it."],
		"big": ["An excellent instrument, and a not inconsiderable purse."],
		"sell": ["Oh, that is interesting.", "Hmm. The wiring is shoddy, but the glass is good."],
		"bulk": ["Oh, everything at once. How thrilling."],
		"deny": ["The dials say you are short."],
		"regular": ["You have a good eye. Most people never come back."]},
	"quartermaster": {
		"buy": ["Two of those. Trust me.", "Rations are not good. They are not meant to be.", "Do not run the tank dry. Everybody does once."],
		"big": ["You have bought half my shelf. Good."],
		"sell": ["Always room for another sack.", "That will do the crew good."],
		"bulk": ["Right. Take a seat. This will take a while."],
		"deny": ["Not enough. Not nearly enough."],
		"regular": ["The usual, and a discount for a friend."]},
	"curiosity": {
		"buy": ["No refunds.", "I did not say how it works.", "It has been very quiet since it left the shelf. Good."],
		"big": ["Oh, you truly want that. Do be careful."],
		"sell": ["Fascinating. Where did you get it?", "It will look well on the shelf."],
		"bulk": ["A confession, is it? Leave it on the counter."],
		"deny": ["The bell says you are short."],
		"regular": ["The shelves know you. Do not let them tell you otherwise."]},
	"broker": {
		"buy": ["A pleasure.", "Always a good time to buy.", "That price will not hold till tomorrow."],
		"big": ["A fine transaction. Somebody has been working."],
		"sell": ["Pleasure doing business.", "I will see it moved on by tonight.", "The scales agree."],
		"bulk": ["A full clearance. Lovely, lovely."],
		"deny": ["The ledger disagrees with you."],
		"regular": ["My favourite client. Do not tell the others."]},
}

var last_line := ""    # what they last said, for the counter window
var _last_bark_kind := ""

const RESTOCK := 420.0 # seconds between restocks

var trade := "quartermaster"
var tier := 1 # how good this port's stock gets
var biome := "verdance"
var stock: Array = [] # [{proto, count, price}]
var standing := 0.0 # -1 .. 1, how they feel about you
## Set when somebody swings at them. A shopkeeper has a long memory and a short counter.
var refuse_until := 0.0
var _idle_t := 6.0
var _greeted := {}
var spent := 0 # marks you have put across this counter
var _restock_t := 0.0
var _seeded := false

func key() -> StringName:
	return &"vendor"

func setup(p: Dictionary) -> CVendor:
	trade = String(p.get("trade", trade))
	tier = int(p.get("tier", tier))
	biome = String(p.get("biome", biome))
	return self

func info() -> Dictionary:
	return TRADES.get(trade, TRADES["quartermaster"])

func on_added() -> void:
	if not _seeded:
		restock(true)

func process(delta: float) -> void:
	_restock_t -= delta
	if _restock_t <= 0.0:
		_restock_t = RESTOCK
		restock(false)

# ------------------------------------------------------------------ stock
func restock(full: bool) -> void:
	_seeded = true
	if full:
		stock.clear()
	var rng := Game.rng
	var want := _catalogue()
	# top existing lines back up first
	for row in stock:
		row["count"] = mini(int(row.get("max", 3)), int(row["count"]) + rng.randi_range(0, 2))
	if not full and rng.randf() < 0.5:
		return
	var have := {}
	for row in stock:
		have[row["proto"]] = true
	var adds: int = want.size() if full else rng.randi_range(1, 3)
	want.shuffle()
	for id in want:
		if adds <= 0:
			break
		if have.has(id):
			continue
		var n := rng.randi_range(1, 4) if not id.begins_with("mod_") else rng.randi_range(1, 2)
		stock.append({"proto": id, "count": n, "max": n + 2})
		adds -= 1
	stock.sort_custom(func(a, b): return _price_of(String(a["proto"])) < _price_of(String(b["proto"])))

## Everything this vendor could carry at this port's tier.
func _catalogue() -> Array:
	var out := []
	var cats: Array = info().get("cats", [])
	for cat in cats:
		for mid in ShipParts.in_cat(String(cat)):
			if ShipParts.tier_of(mid) <= tier:
				out.append("mod_" + mid)
	for row in GOODS.get(trade, []):
		if int(row[0]) <= tier:
			for id in row[1]:
				if Proto.has(String(id)):
					out.append(String(id))
	# every port keeps a little of what it makes
	var t: Dictionary = Economy.BIOME_TRADE.get(biome, {})
	for id in t.get("makes", []):
		if Proto.has(String(id)) and trade in ["quartermaster", "broker"]:
			out.append(String(id))
	return out

func _price_of(proto_id: String) -> int:
	var rates := Economy.port_rates(biome, proto_id)
	return Economy.buy_price(Economy.base_value(proto_id), Game.player, float(rates[0]), standing)

# ------------------------------------------------------------------ the counter
## What it costs the player, right now, with haggling and the port's mood applied.
func price(proto_id: String) -> int:
	return _price_of(proto_id)

## What they will give you for one of yours.
func offer(item: Entity) -> int:
	if item == null or item.removed:
		return 0
	var rates := Economy.port_rates(biome, item.proto)
	var base := Economy.value_of(item)
	var demand := float(rates[1])
	# a specialist pays properly for their own trade and badly for everything else
	if not _interested(item):
		demand *= 0.55
	return Economy.sell_price(base, Game.player, demand, standing)

func _interested(item: Entity) -> bool:
	if trade == "broker":
		return true
	var mid := String(item.tags.get("module", ""))
	if mid != "":
		return ShipParts.cat_of(mid) in info().get("cats", [])
	var cat: String = Proto.category(item.proto)
	match trade:
		"quartermaster": return cat in ["tool", "material", "food", "clothing"]
		"curiosity": return item.has_c(&"curio") or item.has_c(&"tonic")
		"gunsmith": return cat == "weapon"
		"artificer": return item.proto.begins_with("ore_") or item.proto in ["skyglass_lens", "aether_ingot", "storm_glass"]
		"rigger": return item.proto in ["canvas_bolt", "fibre_bundle", "skysilk_thread", "beast_hide"]
		"shipwright": return item.proto in ["sky_timber", "ironwood_beam", "iron_ingot", "sheet_metal", "salvage_scrap"]
	return false

func buy(user: Entity, proto_id: String, count := 1) -> bool:
	var row: Dictionary = _row(proto_id)
	if row.is_empty():
		Game.tell(user, "They are out of those.", "warn")
		return false
	count = mini(count, int(row["count"]))
	if count <= 0:
		Game.tell(user, "They are out of those.", "warn")
		return false
	var each := price(proto_id)
	var total := each * count
	if not Economy.can_afford(user, total):
		Game.tell(user, "[color=#ff6a6a]You cannot afford that. %s marks short.[/color]" % Economy.money(total - Economy.purse(user)), "warn")
		_bark("deny")
		Sfx.play_ui(&"ui_deny", 0.8)
		return false
	Economy.take(user, total)
	spent += total
	standing = clampf(standing + float(total) / 4000.0, -1.0, 1.0)
	row["count"] -= count
	if int(row["count"]) <= 0:
		stock.erase(row)
	var where := "your hands"
	for _i in count:
		var it := Proto.spawn(proto_id, user.root_cell())
		if it != null:
			where = Economy.deliver(user, it)
	Sfx.play("vend", e.cell, 0.6)
	_coins(total)
	# a big spend gets its own line, a regular gets recognised, everything else a nod
	var kind := "buy"
	if total >= 1000:
		kind = "big"
	elif spent >= 3000 and Game.rng.randf() < 0.35:
		kind = "regular"
	_bark(kind)
	PortLife.floater("-%s" % Economy.money(total), user, Color("#ffb08a"))
	Game.tell(user, "[color=#6ad88a]Bought %s%s for %s marks.[/color] It goes in %s." % [
		String(Proto.P.get(proto_id, {}).get("name", proto_id)),
		"" if count == 1 else " x%d" % count, Economy.money(total), where], "good")
	Skills.add_xp(user, "trading", 4.0 + float(total) * 0.01)
	return true

func sell(user: Entity, item: Entity, bulk := false) -> bool:
	if item == null or item.removed:
		return false
	var got := offer(item)
	if got <= 0:
		_say("That is worth nothing to me.")
		Sfx.play_ui(&"ui_deny", 0.7)
		return false
	Economy.give(user, got)
	standing = clampf(standing + float(got) / 8000.0, -1.0, 1.0)
	Game.tell(user, "[color=#e8c85a]Sold %s for %s marks.[/color]" % [item.display_name, Economy.money(got)], "good")
	Skills.add_xp(user, "trading", 3.0 + float(got) * 0.012)
	Sfx.play("vend", e.cell, 0.5)
	item.destroy()
	if not bulk:
		after_sale(got, false)
	return true

## The flourish after a sale: coins, a floating figure over the player, a line from them.
## A bulk sale calls this once for the whole lot rather than once per item.
func after_sale(got: int, bulk: bool) -> void:
	if got <= 0:
		return
	_coins(got)
	_bark("bulk" if bulk else "sell")
	PortLife.floater("+%s" % Economy.money(got), Game.player, Color("#ffd970"))

## Coins on the counter: a clink, or a run of them, scaled with the money.
func _coins(total: int) -> void:
	var n := clampi(1 + total / 600, 1, 4)
	var tree := Game.get_tree()
	if tree == null:
		return
	for i in n:
		var d := 0.10 + 0.09 * float(i)
		var pitch := 1.0 + 0.06 * float(i % 2) - 0.03 * float(i)
		tree.create_timer(d).timeout.connect(func(): Sfx.play_ui(&"ui_coin", 0.9, pitch))

## Something to say for an event, in this trader's own voice. The line is remembered so the
## counter window can quote it, and spoken so everybody in the room hears it too.
func _bark(kind: String) -> void:
	var table: Dictionary = BARKS.get(trade, BARKS["quartermaster"])
	var pool: Array = table.get(kind, table.get("buy", []))
	if pool.is_empty():
		return
	var line := String(pool[Game.rng.randi() % pool.size()])
	# never the same line twice running
	if pool.size() > 1 and line == last_line:
		line = String(pool[(pool.find(line) + 1) % pool.size()])
	_last_bark_kind = kind
	_say(line)

func _row(proto_id: String) -> Dictionary:
	for r in stock:
		if String(r["proto"]) == proto_id:
			return r
	return {}

func _say(text: String) -> void:
	last_line = text
	var m: CMob = e.c(&"mob")
	if m != null:
		m.say(text)

# ------------------------------------------------------------------ presentation
# ------------------------------------------------------------------ being a person
## Opening the counter. Routed here rather than straight to the window so that one place
## decides whether this trader is willing to serve you at all.
func open_counter(user: Entity) -> bool:
	if refuse_until > Game.time:
		_say(_refusal())
		Game.tell(user, "[color=#e8a83a]%s will not serve you.[/color]" % e.display_name.split(",")[0], "warn")
		return false
	var h: CHealth = e.c(&"health")
	if h != null and h.stat() != CHealth.CONSCIOUS:
		Game.tell(user, "They are in no state to sell you anything.", "warn")
		return false
	if not _greeted.has(user.id):
		_greeted[user.id] = true
		_say(String(info()["greet"]))
	WindowsShop.hover_id = ""
	Game.hud.open_window("shop", e)
	return true

## Swinging at a shopkeeper does not land — Combat.melee refuses it outright for anybody
## tagged `protected`, which is everyone who works a port. What it does instead is this:
## they step back, say something, and get on with their day. No damage, no warrant, no
## ruined save because a click went astray in a crowded room.
func on_shoved(by: Entity) -> void:
	if by == null:
		return
	_say(["Hands. Hands!", "Do that again and you can buy your rope elsewhere.",
		"We are all very tired, friend.", "Careful."][Game.rng.randi() % 4])
	if by == Game.player:
		Game.tell(by, "[color=#8aa0b4]%s steps back out of reach. Nobody starts a fight in a port and gets to finish it.[/color]" % e.display_name.split(",")[0], "warn")

func _refusal() -> String:
	return ["I said out.", "Not to you.", "Try the next door along. Or the sky.",
		"We are closed. To you, permanently."][Game.rng.randi() % 4]

## Idle life. A shopkeeper who never moves or speaks is a vending machine with a face, and
## the whole point of putting people in the hub is that the systems get explained by
## somebody standing behind a counter rather than by a tooltip.
func idle(delta: float) -> void:
	_idle_t -= delta
	if _idle_t > 0.0:
		return
	_idle_t = Game.rng.randf_range(16.0, 38.0)
	if Game.player == null or e.dist_to(Game.player) > 7:
		return
	if refuse_until > Game.time:
		return
	var pitch: Array = info().get("idle", [])
	var hint := Economy.port_hint(biome)
	if hint != "" and Game.rng.randf() < 0.28:
		_say(hint)
	elif not pitch.is_empty():
		_say(String(pitch[Game.rng.randi() % pitch.size()]))

func examine(user: Entity, lines: Array) -> void:
	var i := info()
	lines.append("[color=#e8c85a]%s.[/color] %s" % [String(i["name"]), String(i["blurb"])])
	var hint := Economy.port_hint(biome)
	if hint != "":
		lines.append("[i]\"%s\"[/i]" % hint)
	if refuse_until > Game.time:
		lines.append("[color=#ff6a6a]They will not serve you. (%d seconds of it left.)[/color]" % int(refuse_until - Game.time))
	elif standing > 0.35:
		lines.append("[color=#6ad88a]They are pleased to see you.[/color]")
	elif standing < -0.2:
		lines.append("[color=#e8a83a]They are not pleased to see you.[/color]")
	lines.append("[color=#8aa0b4]They think you are %s.[/color]" % Reputation.word())
	lines.append("[i]Click them to open the counter. Right-click for everything else.[/i]")

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Trade", "priority": 100, "cb": func(): open_counter(user)})
	out.append({"name": "Ask what the port is short of", "priority": 90, "cb": func():
		var hint := Economy.port_hint(biome)
		_say(hint if hint != "" else "We want for nothing and we sell nothing. Good day.")
		Skills.add_xp(user, "trading", 4.0)})
	out.append({"name": "Ask about the sky out there", "priority": 80, "cb": func():
		_say(_rumour())
		Skills.add_xp(user, "social", 5.0)})
	if Reputation.wanted() > 0 and trade in ["broker", "quartermaster"]:
		out.append({"name": "Settle the warrant (%s marks)" % Economy.money(Reputation.fine()),
			"priority": 70, "cb": func():
				if Reputation.pay_fine(user):
					_say("Nothing was ever said. Nothing ever is.")})

## What a trader knows that you do not: where the good ore is, what the weather has been
## doing, and which way the last ship that did not come back was headed.
func _rumour() -> String:
	if Game.sky == null or Game.sky.gen == null:
		return "Same as it ever is. Windy."
	var gen: SkyGen = Game.sky.gen
	var far := []
	for isl in gen.islands:
		if int(isl.get("tier", 0)) >= 2:
			far.append(isl)
	if far.is_empty():
		return "Nothing out there but weather."
	var isl: Dictionary = far[Game.rng.randi() % far.size()]
	var b: Dictionary = isl["b"]
	var bearing := CSkyCompass._bearing(Vector2(isl["area"].center - e.cell))
	var t: int = int(isl.get("tier", 2))
	match Game.rng.randi() % 4:
		0:
			return "%s. %s way, out in %s. They say the rock there is half %s." % [
				isl["name"], bearing.capitalize(), Biomes.ring_name(t), String(b["name"]).to_lower()]
		1:
			return "Do not put down on %s after dark. That is the whole of my advice about %s." % [
				isl["name"], isl["name"]]
		2:
			return "A hull went out toward %s last month. The chart came back. The hull did not." % isl["name"]
	return "If you are flying %s, mind the weather. It has a way of finding people." % bearing
