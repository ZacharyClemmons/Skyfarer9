class_name WindowsShop extends RefCounted
## The counter.
##
## A shop window in this game is a conversation with somebody who has an opinion about
## what you are carrying, so it shows three things at once: what they have, what they
## will give you for yours, and what this port is short of. The last one is the only
## place a trade route is ever explained, and it is explained by the person who knows.
##
## The rule it is built on is the same one the bench list follows: **a price on its own
## teaches nobody anything.** So every module on the shelf is compared against the one
## already bolted to your ship — "+14 thrust, +25% burn, over your brass burner" — because
## that is the question the player is actually asking, and making them hold two stat
## blocks in their head to answer it is a tax, not a decision.
##
## It is also a place that should feel good to spend money in. The purse ticks down and up
## rather than snapping, prices are green when you can pay and red when you cannot, a row
## lights when the mouse is on it and the detail panel tells you about that item, the
## trader answers every deal in their own voice, and buttons chime.

static var tab := "buy"
static var cat_filter := "all"
static var search := ""
static var qty := {}              # proto id -> how many the stepper is set to
static var hover_id := ""         # the row the mouse is on, so a rebuild does not forget it
static var shown_purse := -1.0    # what the purse counter is currently displaying
static var _last_build := 0.0
static var _args_read := false

const GOLD := Color("#ffd970")
const COL_DIM := "#8aa0b4"

# ------------------------------------------------------------------ small controls
## A number that eases toward its target and ticks while it moves. Survives the window
## being rebuilt because the value it is showing lives in a static, not in the node.
class PurseLabel extends Label:
	var target := 0
	var _tick := 0.0
	var _flash := 0.0

	func _ready() -> void:
		if WindowsShop.shown_purse < 0.0:
			WindowsShop.shown_purse = float(target)
		text = Economy.money(int(round(WindowsShop.shown_purse)))
		if int(round(WindowsShop.shown_purse)) != target:
			UIFx.pop(self, 1.12, 0.2)

	func _process(delta: float) -> void:
		var cur := WindowsShop.shown_purse
		if absf(cur - float(target)) < 0.5:
			if int(round(cur)) != target:
				cur = float(target)
			WindowsShop.shown_purse = cur
			_flash = maxf(0.0, _flash - delta * 2.0)
		else:
			var diff := float(target) - cur
			cur += signf(diff) * minf(absf(diff), maxf(absf(diff) * delta * 6.0, delta * 150.0))
			if absf(float(target) - cur) < 1.0:
				cur = float(target)
			WindowsShop.shown_purse = cur
			_flash = 1.0
			_tick -= delta
			if _tick <= 0.0:
				_tick = 0.055
				Sfx.play_ui(&"ui_tick", 0.35, 1.25 if diff > 0.0 else 0.85)
		text = Economy.money(int(round(cur)))
		var up := float(target) > cur
		var c := GOLD.lerp(Color("#8dff9a") if up else Color("#ffb08a"), _flash * 0.85)
		add_theme_color_override("font_color", c)

## A small gold coin, so money reads as money and not as another number.
class Coin extends Control:
	var t := 0.0

	func _init(sz := 20.0) -> void:
		custom_minimum_size = Vector2(sz, sz)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5 - 1.0
		var c := size * 0.5
		draw_circle(c, r, Color("#5a3d0e"))
		draw_circle(c, r - 1.5, Color("#f0b83a"))
		draw_circle(c, r - 4.0, Color("#ffd970"))
		draw_arc(c, r - 3.0, 0.0, TAU, 20, Color("#c88a1e"), 1.0)
		# a glint that slides across every few seconds
		var g := fposmod(t * 0.55, 3.0)
		if g < 1.0:
			var gx := lerpf(-r, r, g)
			draw_line(c + Vector2(gx - 2.0, r * 0.7), c + Vector2(gx + 3.0, -r * 0.7), Color(1, 1, 0.9, 0.85 * sin(g * PI)), 2.0)

static func _coin(sz := 20.0) -> Coin:
	return Coin.new(sz)

# ------------------------------------------------------------------ build
static func build(t: Entity, body: VBoxContainer, w: UIWindow) -> void:
	var p := Game.player
	var v: CVendor = t.c(&"vendor") if t != null else null
	if v == null or p == null:
		Windows._rt(body, "[color=#8a9cb0]Nobody is serving.[/color]")
		return
	if not _args_read:
		_args_read = true
		var ua := OS.get_cmdline_user_args()
		if "--shoptab=sell" in ua:
			tab = "sell"
		if "--shopbuy" in ua:
			# a functional check of the whole transaction path: buy two, sell one back
			var before := Economy.purse(p)
			var row: Dictionary = v.stock[0] if not v.stock.is_empty() else {}
			if not row.is_empty():
				var ok := v.buy(p, String(row["proto"]), 2)
				var mid := Economy.purse(p)
				var inv0: CInventory = p.c(&"inv")
				var sold := false
				for it in inv0.all_items(true):
					if is_instance_valid(it) and not it.removed and v.offer(it) > 0:
						sold = v.sell(p, it)
						break
				print("SHOPTEST buy=%s spent=%d sold=%s back=%d line=\"%s\"" % [
					ok, before - mid, sold, Economy.purse(p) - mid, v.last_line])
			v.buy(p, "no_such_thing", 1)
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_build > 4.0:
		shown_purse = -1.0
		hover_id = ""
	_last_build = now
	var detail := _header(v, t, body, p, w)
	_tabs(v, body, w, p)
	if tab == "buy":
		_buy(v, body, p, w, detail)
	else:
		_sell(v, body, p, w, detail)

# ------------------------------------------------------------------ header
static func _header(v: CVendor, t: Entity, body: VBoxContainer, p: Entity, w: UIWindow) -> RichTextLabel:
	var i := v.info()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	body.add_child(top)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 1)
	top.add_child(left)
	left.add_child(UITheme.label(String(i["name"]).to_upper(), UITheme.BODY, UITheme.ACCENT))
	var blurb := UITheme.label(String(i["blurb"]), UITheme.SMALL, UITheme.DIM)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(blurb)
	var rep := "[color=#8aa0b4]They think you are %s.[/color]" % Reputation.word()
	var sk := Skills.level(p, "trading")
	if sk > 5:
		rep += "   [color=#6ad88a]Haggling: %d%% off.[/color]" % int(Skills.frac(p, "trading") * Economy.HAGGLE_BUY * 100.0)
	var repl := Windows._rt(left, rep)
	repl.add_theme_font_size_override("normal_font_size", UITheme.SMALL)

	# the purse, on the right, ticking
	var pbox := PanelContainer.new()
	pbox.add_theme_stylebox_override("panel", UITheme.frame("well", 12, 6))
	top.add_child(pbox)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	pbox.add_child(pv)
	pv.add_child(UITheme.caption("YOUR PURSE"))
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	pv.add_child(prow)
	prow.add_child(_coin(22.0))
	var pl := PurseLabel.new()
	pl.target = Economy.purse(p)
	pl.add_theme_font_size_override("font_size", 24)
	pl.custom_minimum_size = Vector2(110, 0)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pl.text = Economy.money(pl.target)
	prow.add_child(pl)
	pv.add_child(UITheme.caption("marks"))

	# what the trader has just said, in their own voice
	var say := PanelContainer.new()
	say.add_theme_stylebox_override("panel", UITheme.frame("slot_normal", 10, 5, 0.9))
	body.add_child(say)
	var line := v.last_line if v.last_line != "" else String(i["greet"])
	var q := Windows._rt(say, "[color=#e8c85a]“[/color][i]%s[/i][color=#e8c85a]”[/color]" % line)
	q.add_theme_font_size_override("normal_font_size", 16)
	q.add_theme_font_size_override("italics_font_size", 16)
	var hint := Economy.port_hint(String(v.biome))
	if hint != "":
		Windows._rt(body, "[color=#8aa0b4]The port wants:[/color] [i]%s[/i]" % hint)

	# item detail: filled in as the mouse moves over rows; a rebuild restores it
	var dwrap := PanelContainer.new()
	dwrap.add_theme_stylebox_override("panel", UITheme.frame("well", 10, 6))
	dwrap.custom_minimum_size = Vector2(0, 74)
	body.add_child(dwrap)
	var detail := RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.fit_content = true
	detail.scroll_active = false
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dwrap.add_child(detail)
	if hover_id != "":
		detail.text = _detail_text(v, p, hover_id)
	elif tab == "buy":
		detail.text = "[color=#8aa0b4]Point at anything on the shelf to see what it does, what it does for your ship and what the port thinks it is worth.[/color]"
	else:
		detail.text = "[color=#8aa0b4]Point at something of yours to see what they think of it. A broker pays properly for anything; a specialist only for their own trade.[/color]"
	return detail

static func _tabs(v: CVendor, body: VBoxContainer, w: UIWindow, p: Entity) -> void:
	var tabs := Windows._row(body)
	var sellable := 0
	var inv: CInventory = p.c(&"inv")
	if inv != null:
		for it in inv.all_items(true):
			if is_instance_valid(it) and not it.removed and v.offer(it) > 0:
				sellable += 1
	for pair in [["buy", "What they have  (%d)" % v.stock.size()], ["sell", "What you have  (%d)" % sellable]]:
		var b := Button.new()
		b.text = pair[1]
		b.toggle_mode = true
		b.button_pressed = tab == pair[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("fx_sound", "ui_click")
		var id: String = pair[0]
		b.pressed.connect(func():
			tab = id
			hover_id = ""
			w._refresh_now())
		tabs.add_child(b)

# ------------------------------------------------------------------ buying
## The categories a shop's stock falls into. Derived from what is actually on the shelf,
## so a chandlery does not show an empty "Thrusters" tab.
static func _categories(v: CVendor) -> Array:
	var seen := {"all": true}
	for row in v.stock:
		seen[_cat_of(String(row["proto"]))] = true
	var out := seen.keys()
	out.sort()
	out.erase("all")
	out.push_front("all")
	return out

static func _cat_of(proto_id: String) -> String:
	var mid := String(Proto.P.get(proto_id, {}).get("tags", {}).get("module", ""))
	if mid != "":
		return String(ShipParts.CATS.get(ShipParts.cat_of(mid), {}).get("name", "Parts"))
	var pd: Dictionary = Proto.P.get(proto_id, {})
	var comps: Dictionary = pd.get("comps", {})
	if comps.has("tonic"):
		return "Tonics"
	if comps.has("curio"):
		return "Curios"
	if comps.has("aethergun") or comps.has("quirkweapon"):
		return "Weapons"
	var cat: String = Proto.category(proto_id)
	return {"tool": "Tools", "material": "Materials", "food": "Provisions",
		"clothing": "Clothing", "weapon": "Weapons"}.get(cat, "Sundries")

## How many of each proto the player is carrying, stacks counted.
static func _owned(p: Entity) -> Dictionary:
	var out := {}
	var inv: CInventory = p.c(&"inv")
	if inv == null:
		return out
	for it in inv.all_items(true):
		if not is_instance_valid(it) or it.removed:
			continue
		var n := 1
		var st: CStack = it.c(&"stack")
		if st != null:
			n = st.amount
		out[it.proto] = int(out.get(it.proto, 0)) + n
	return out

static func _buy(v: CVendor, body: VBoxContainer, p: Entity, w: UIWindow, detail: RichTextLabel) -> void:
	if v.stock.is_empty():
		Windows._rt(body, "[color=#8a9cb0]Cleaned out. Come back in a while.[/color]")
		return
	var cats := _categories(v)
	if not cats.has(cat_filter):
		cat_filter = "all"
	if cats.size() > 2:
		var bar := HFlowContainer.new()
		bar.add_theme_constant_override("h_separation", 3)
		bar.add_theme_constant_override("v_separation", 3)
		body.add_child(bar)
		for c in cats:
			var b := Button.new()
			var n := 0
			for row in v.stock:
				if c == "all" or _cat_of(String(row["proto"])) == c:
					n += 1
			b.text = "%s  %d" % ["Everything" if c == "all" else String(c), n]
			b.toggle_mode = true
			b.button_pressed = cat_filter == c
			b.add_theme_font_size_override("font_size", UITheme.SMALL)
			b.set_meta("fx_sound", "ui_tick")
			var id: String = c
			b.pressed.connect(func():
				cat_filter = id
				w._refresh_now())
			bar.add_child(b)
	var owned := _owned(p)
	var shown := 0
	for row in v.stock:
		var id := String(row["proto"])
		if cat_filter != "all" and _cat_of(id) != cat_filter:
			continue
		shown += 1
		_stock_row(v, body, p, w, row, owned, detail)
	if shown == 0:
		Windows._rt(body, "[color=#8a9cb0]Nothing of that sort today.[/color]")

## One line of the shelf: icon, name, what it does, what you already have, the price in the
## colour of whether you can pay it, a quantity stepper and the buy button.
static func _stock_row(v: CVendor, body: VBoxContainer, p: Entity, w: UIWindow, row: Dictionary,
		owned: Dictionary, detail: RichTextLabel) -> void:
	var id := String(row["proto"])
	var pd: Dictionary = Proto.P.get(id, {})
	var price := v.price(id)
	var have := int(row["count"])
	var n: int = clampi(int(qty.get(id, 1)), 1, maxi(1, have))
	var total := price * n
	var purse := Economy.purse(p)
	var afford := purse >= total
	var afford_one := purse >= price

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.frame("slot_hot" if hover_id == id else "slot_normal", 8, 6))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(card)
	card.mouse_entered.connect(func():
		hover_id = id
		card.add_theme_stylebox_override("panel", UITheme.frame("slot_hot", 8, 6))
		if is_instance_valid(detail):
			detail.text = _detail_text(v, p, id))
	card.mouse_exited.connect(func():
		# a child button under the mouse counts as still being on the row
		if card.get_global_rect().has_point(card.get_global_mouse_position()):
			return
		if hover_id == id:
			hover_id = ""
		card.add_theme_stylebox_override("panel", UITheme.frame("slot_normal", 8, 6)))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(line)

	var icon := TextureRect.new()
	var spr := String(pd.get("spr", ""))
	var sheet := String(pd.get("sheet", "items"))
	if spr != "" and Gfx.has(sheet, spr):
		icon.texture = Gfx.atlas(sheet, spr)
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1, 1, 1, 1.0 if afford_one else 0.55)
	line.add_child(icon)

	var txt := RichTextLabel.new()
	txt.bbcode_enabled = true
	txt.fit_content = true
	txt.scroll_active = false
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.custom_minimum_size = Vector2(230, 30)
	txt.add_theme_font_size_override("normal_font_size", 16)
	txt.add_theme_font_size_override("bold_font_size", 16)
	var mid := String(pd.get("tags", {}).get("module", ""))
	var col := ShipParts.tier_color(mid) if mid != "" else "#dbe8f4"
	var body_txt := "[color=%s][b]%s[/b][/color]  [color=#8aa0b4]%d on the shelf[/color]" % [
		col, String(pd.get("name", id)), have]
	var carried := int(owned.get(id, 0))
	if carried > 0:
		body_txt += "  [color=#7fd4ff]you carry %d[/color]" % carried
	if mid != "":
		body_txt += "\n[color=#8aa0b4]%s[/color]" % "   ".join(ShipParts.stat_lines(mid))
		var cmp := _compare(mid)
		if cmp != "":
			body_txt += "\n%s" % cmp
		var req: Dictionary = ShipParts.get_mod(mid).get("req", {})
		var short := Skills.shortfall(p, req)
		if short != "":
			body_txt += "\n[color=#ff6a6a]You could not fit this yet — needs %s.[/color]" % short
	else:
		var d := _plain(String(pd.get("desc", "")))
		if d.length() > 88:
			d = d.substr(0, 85).strip_edges() + "..."
		if d != "":
			body_txt += "\n[color=#8aa0b4]%s[/color]" % d
	txt.text = body_txt
	line.add_child(txt)

	# price, green when you can pay and red when you cannot
	var pcol := UITheme.GOOD if afford_one else UITheme.BAD
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.custom_minimum_size = Vector2(88, 0)
	line.add_child(pv)
	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_END
	prow.add_theme_constant_override("separation", 4)
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(prow)
	prow.add_child(_coin(16.0))
	var pl := UITheme.label(Economy.money(price), 17, pcol)
	prow.add_child(pl)
	if not afford_one:
		var sh := UITheme.label("%s short" % Economy.money(price - purse), 12, UITheme.BAD)
		sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pv.add_child(sh)
	elif n > 1:
		var tl := UITheme.label("x%d = %s" % [n, Economy.money(total)], 12, pcol if afford else UITheme.BAD)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pv.add_child(tl)

	# quantity stepper (a spacer where there is none, so the columns stay in line)
	if have <= 1:
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(78, 0)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(sp)
	if have > 1:
		var st := HBoxContainer.new()
		st.add_theme_constant_override("separation", 2)
		line.add_child(st)
		var minus := Button.new()
		minus.text = "-"
		minus.custom_minimum_size = Vector2(26, 0)
		minus.disabled = n <= 1
		minus.set_meta("fx_sound", "ui_tick")
		minus.pressed.connect(func():
			qty[id] = maxi(1, n - 1)
			w._refresh_now())
		st.add_child(minus)
		var nl := UITheme.label(str(n), 16, UITheme.TEXT)
		nl.custom_minimum_size = Vector2(22, 0)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.add_child(nl)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(26, 0)
		plus.disabled = n >= have
		plus.set_meta("fx_sound", "ui_tick")
		plus.pressed.connect(func():
			qty[id] = mini(have, n + 1)
			w._refresh_now())
		st.add_child(plus)

	var buy := Button.new()
	buy.text = "Buy" if n == 1 else "Buy %d" % n
	buy.custom_minimum_size = Vector2(76, 0)
	buy.disabled = not afford
	buy.add_theme_color_override("font_color", UITheme.GOOD if afford else UITheme.BAD)
	buy.set_meta("fx_sound", "ui_purchase")
	buy.tooltip_text = "Buy %s for %s marks." % ["one" if n == 1 else str(n), Economy.money(total)] if afford \
		else "%s marks short." % Economy.money(total - purse)
	buy.pressed.connect(func():
		if v.buy(p, id, n):
			qty[id] = 1
		w._refresh_now())
	line.add_child(buy)

## The panel above the shelf: everything worth knowing about the thing under the mouse.
static func _detail_text(v: CVendor, p: Entity, id: String) -> String:
	if id == "":
		return ""
	var pd: Dictionary = Proto.P.get(id, {})
	if pd.is_empty():
		return ""
	var mid := String(pd.get("tags", {}).get("module", ""))
	var col := ShipParts.tier_color(mid) if mid != "" else "#dbe8f4"
	var s := "[color=%s][b]%s[/b][/color]\n" % [col, String(pd.get("name", id))]
	var d := _plain(String(pd.get("desc", "")))
	if d != "":
		s += "%s\n" % d
	if mid != "":
		s += "[color=#8aa0b4]%s[/color]\n" % "   ".join(ShipParts.stat_lines(mid))
		var q := ShipParts.quirk_text(mid)
		if q != "":
			s += "[color=#e8a83a]%s[/color]\n" % q
		var cmp := _compare(mid)
		if cmp != "":
			s += "%s\n" % cmp
	var rates := Economy.port_rates(String(v.biome), id)
	var r0 := float(rates[0])
	if r0 > 1.08:
		s += "[color=#e8a83a]Dear here: this port pays %d%% over the going rate to have it.[/color]" % int(round((r0 - 1.0) * 100.0))
	elif r0 < 0.92:
		s += "[color=#6ad88a]Cheap here: %d%% under the going rate. Worth buying to sell elsewhere.[/color]" % int(round((1.0 - r0) * 100.0))
	else:
		s += "[color=#8aa0b4]About the going rate.[/color]"
	return s.strip_edges()

static func _plain(t: String) -> String:
	return t.replace("[b]", "").replace("[/b]", "").replace("[i]", "").replace("[/i]", "").replace("\n", " ")

## How this module measures up against the one already bolted to your ship. The answer a
## player is actually after, worked out for them rather than left as two stat blocks to
## hold in their head.
static func _compare(mid: String) -> String:
	var sh: Airship = Game.fleet.ship_of(Game.player) if Game.fleet != null else null
	if sh == null:
		sh = Game.fleet.player_ship if Game.fleet != null else null
	if sh == null:
		return ""
	var cat := ShipParts.cat_of(mid)
	# the worst one of this kind she is currently carrying: that is what you would swap
	var worst := ""
	var worst_tier := 99
	for pair in sh.module_list():
		var have := String(pair[1])
		if ShipParts.cat_of(have) != cat:
			continue
		if ShipParts.tier_of(have) < worst_tier:
			worst_tier = ShipParts.tier_of(have)
			worst = have
	if worst == "":
		return "[color=#7fd4ff]She has no %s at all.[/color]" % cat
	if worst == mid:
		return "[color=#8aa0b4]Same as the one she has.[/color]"
	var deltas := []
	for key in ["thrust", "lift", "sail", "turn", "fuel_cap", "armor", "steam", "gun_damage"]:
		var a := ShipParts.stat(mid, key, 0.0)
		var b := ShipParts.stat(worst, key, 0.0)
		if absf(a - b) < 0.01:
			continue
		var scale: float = 100.0 if key == "lift" else 1.0
		deltas.append("%s %+.0f%s" % [key.replace("_", " "), (a - b) * scale, "%" if key == "lift" else ""])
	for key in ["fuel_mul", "drag_mul", "heat_mul"]:
		var a2 := ShipParts.stat(mid, key, 1.0)
		var b2 := ShipParts.stat(worst, key, 1.0)
		if absf(a2 - b2) < 0.01:
			continue
		deltas.append("%s %+.0f%%" % [key.replace("_mul", ""), (a2 - b2) * 100.0])
	if deltas.is_empty():
		return "[color=#8aa0b4]No better than her %s.[/color]" % ShipParts.name_of(worst)
	var better := ShipParts.tier_of(mid) > worst_tier
	return "[color=%s]%s — over her %s.[/color]" % [
		"#6ad88a" if better else "#e8a83a", ", ".join(deltas), ShipParts.name_of(worst)]

# ------------------------------------------------------------------ selling
static func _sell(v: CVendor, body: VBoxContainer, p: Entity, w: UIWindow, detail: RichTextLabel) -> void:
	var inv: CInventory = p.c(&"inv")
	if inv == null:
		return
	var rows := []
	var total := 0
	for it in inv.all_items(true):
		if not is_instance_valid(it) or it.removed:
			continue
		var got := v.offer(it)
		if got <= 0:
			continue
		rows.append({"item": it, "price": got, "keen": v._interested(it)})
		total += got
	if rows.is_empty():
		Windows._rt(body, "[color=#8a9cb0]Nothing you are carrying is worth anything to them.[/color]\n[i]Try the Exchange — a broker buys anything.[/i]")
		return
	# their own trade first, then by what it is worth
	rows.sort_custom(func(a, b):
		if a["keen"] != b["keen"]:
			return a["keen"]
		return int(a["price"]) > int(b["price"]))
	for row in rows:
		_sell_row(v, body, p, w, row, detail)
	body.add_child(HSeparator.new())
	var all := Button.new()
	all.text = "Sell everything they will take  —  %s marks" % Economy.money(total)
	all.add_theme_color_override("font_color", GOLD)
	all.set_meta("fx_sound", "ui_coin")
	all.tooltip_text = "Clears out everything on this list. There is no confirmation."
	all.pressed.connect(func():
		var sold := 0
		for r in rows:
			var it: Entity = r["item"]
			if is_instance_valid(it) and not it.removed:
				if v.sell(p, it, true):
					sold += int(r["price"])
		v.after_sale(sold, true)
		w._refresh_now())
	body.add_child(all)

static func _sell_row(v: CVendor, body: VBoxContainer, p: Entity, w: UIWindow, row: Dictionary, detail: RichTextLabel) -> void:
	var it: Entity = row["item"]
	var pd: Dictionary = Proto.P.get(it.proto, {})
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.frame("slot_normal", 8, 5))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(card)
	card.mouse_entered.connect(func():
		card.add_theme_stylebox_override("panel", UITheme.frame("slot_hot", 8, 5))
		if is_instance_valid(detail) and is_instance_valid(it) and not it.removed:
			detail.text = "[b]%s[/b]\n%s\n[color=%s]%s[/color]" % [it.display_name.capitalize(),
				_plain(String(pd.get("desc", ""))),
				"#6ad88a" if row["keen"] else "#8aa0b4",
				"Their own trade: they pay properly." if row["keen"] else "Not their trade: they pay about half. A broker would do better."])
	card.mouse_exited.connect(func():
		if card.get_global_rect().has_point(card.get_global_mouse_position()):
			return
		card.add_theme_stylebox_override("panel", UITheme.frame("slot_normal", 8, 5)))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(line)
	var icon := TextureRect.new()
	var spr := String(pd.get("spr", ""))
	if spr != "" and Gfx.has(String(pd.get("sheet", "items")), spr):
		icon.texture = Gfx.atlas(String(pd.get("sheet", "items")), spr)
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	var txt := RichTextLabel.new()
	txt.bbcode_enabled = true
	txt.fit_content = true
	txt.scroll_active = false
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.custom_minimum_size = Vector2(260, 26)
	txt.add_theme_font_size_override("normal_font_size", 16)
	var st: CStack = it.c(&"stack")
	txt.text = "%s%s%s" % [it.display_name.capitalize(),
		"  [color=#8aa0b4]x%d[/color]" % st.amount if st != null and st.amount > 1 else "",
		"  [color=#6ad88a](their trade)[/color]" if row["keen"] else "  [color=#8aa0b4](not their trade)[/color]"]
	line.add_child(txt)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 4)
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(prow)
	prow.add_child(_coin(16.0))
	prow.add_child(UITheme.label(Economy.money(int(row["price"])), 17, GOLD))
	var sell := Button.new()
	sell.text = "Sell"
	sell.custom_minimum_size = Vector2(70, 0)
	sell.add_theme_color_override("font_color", GOLD)
	sell.set_meta("fx_sound", "ui_coin")
	sell.pressed.connect(func():
		v.sell(p, it)
		w._refresh_now())
	line.add_child(sell)
