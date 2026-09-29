class_name CFixture extends Component
## The station's everyday fixtures, one component with a `kind` each (tg paths in brackets):
##   sink        [structure/sink] wash your hands (cleans blood off them); fill beakers and
##               buckets; wet a mop
##   shower      [machinery/shower] turn it on: washes and puts out whoever stands under it,
##               warms them (a wrench sets normal / boiling / freezing), and puddles the floor
##   mirror      [structure/mirror] look yourself over, and restyle your hair
##   trash_bin   a bin to throw rubbish in; take it out again
##   disposal    [machinery/disposal/bin] put things in (or climb in), it pressurises while
##               powered, pull the handle to flush: the recycler pays cargo for the scrap
##   jukebox     [machinery/jukebox] a song for the room
##   arcade      [machinery/computer/arcade/battle] a turn-based fight; win for a prize
##   intercom    [item/radio/intercom] talk near it and it goes out on Common; its speaker
##               lets people nearby hear Common without a headset
##   iv_drip     [machinery/iv_drip] hang a beaker, hook up a patient, it drips into them
##   noticeboard [structure/noticeboard] pin papers to it, read what's pinned
##   clock       the station time
##   display     [structure/displaycase] a glass case for one prized possession
##   computer    [modular_computer] crew manifest, station status and news

var kind := ""
var on := false
var mode := "normal" # shower water temperature
var pressure := 0.0 # disposal, 0..100 %
var flush_handle := false
var patient: Entity = null # iv drip
var injecting := true
# arcade (tg battle arcade)
var enemy_name := ""
var enemy_hp := 0
var enemy_max := 0
var enemy_mp := 0
var player_hp := 100
var player_mp := 50
var feedback := ""
var wins := 0
var _tick_acc := 0.0

const ARCADE_PRIZES := ["glowstick", "cig_pack", "food_donut", "drink_soda", "lighter", "flashlight", "sunglasses", "food_berries"]
const BOSS_ADJ := ["the Evil", "the Hungry", "the Frozen", "the Terrible", "the Lazy", "the Unmaintained", "the Feckless", "the Foolish"]
const BOSS_NAME := ["Pete", "the Sky Bear", "Lord Frost", "the Aether Mouse", "Admiral Frostbite", "the Cloud Crawler", "the Rime Wraith"]
const SONGS := ["\"Frost on the Hull\"", "\"Ferry Blues\"", "\"Aether Nights\"", "\"Skyline Lounge\"", "\"The Long Watch\""]
var song := ""

func key() -> StringName:
	return &"fixture"

func setup(p: Dictionary) -> CFixture:
	kind = p.get("kind", kind)
	on = p.get("on", on)
	return self

func on_added() -> void:
	if kind == "arcade":
		_new_enemy()
	if kind == "intercom":
		Bus.speech.connect(_on_speech)

func on_removed() -> void:
	if kind == "intercom" and Bus.speech.is_connected(_on_speech):
		Bus.speech.disconnect(_on_speech)

## tg intercom: a hot microphone relays what's said beside it onto Common.
func _on_speech(speaker: Entity, text: String, cell: Vector2i, _radius: float) -> void:
	if not on or speaker == null or e.removed or not powered():
		return
	if maxi(absi(cell.x - e.cell.x), absi(cell.y - e.cell.y)) > 2:
		return
	Bus.radio.emit(speaker, "Common", text, {"speaker_name": speaker.display_name})

func _storage() -> CStorage:
	return e.c(&"storage")

func powered() -> bool:
	var m: CMachine = e.c(&"machine")
	return m == null or m.operable()

# ------------------------------------------------------------------ hands
func attack_hand(user: Entity) -> bool:
	match kind:
		"sink":
			Game.visible_message(e.cell, "%s washes their hands using %s." % [user.display_name, e.the()])
			Sfx.play("pour", e.cell, 0.6)
			Blood.wash(user, false)
			return true
		"shower":
			on = not on
			Sfx.play("click", e.cell, 0.6)
			Game.visible_message(e.cell, "%s turns %s %s." % [user.display_name, e.the(), "on" if on else "off"])
			return true
		"mirror":
			Interact.check_self(user)
			var mob: CMob = user.c(&"mob")
			if mob and mob.has_method("cycle_hair"):
				mob.cycle_hair()
			return true
		"trash_bin", "noticeboard", "display":
			Bus.ui_open_window.emit("storage", e)
			return true
		"disposal":
			Bus.ui_open_window.emit("disposal", e)
			return true
		"jukebox":
			if not powered():
				Game.tell(user, "%s is dark." % e.the().capitalize(), "warn")
				return true
			on = not on
			song = SONGS[Game.rng.randi() % SONGS.size()] if on else ""
			Game.visible_message(e.cell, ("%s starts playing %s." % [e.the().capitalize(), song]) if on else "%s stops the music." % user.display_name)
			return true
		"arcade":
			if not powered():
				Game.tell(user, "The screen is dark.", "warn")
				return true
			Bus.ui_open_window.emit("arcade", e)
			return true
		"intercom":
			on = not on
			Game.tell(user, "You turn the intercom's microphone %s." % ("on" if on else "off"))
			Sfx.play("click", e.cell, 0.5)
			return true
		"iv_drip":
			if patient:
				Game.visible_message(e.cell, "%s detaches %s from %s." % [user.display_name, e.the(), patient.display_name])
				patient = null
			elif _storage() and not _storage().contents.is_empty():
				var b: Entity = _storage().contents[0]
				_storage().remove(b)
				user.c(&"inv").put_in_hands(b)
			return true
		"clock":
			Game.tell(user, "The clock reads %s." % Game.clock_string())
			return true
		"computer":
			Bus.ui_open_window.emit("console", e)
			return true
		"igniter":
			on = not on
			Sfx.play("click", e.cell, 0.6)
			e.set_sprite("objects", "igniter_on" if on else "igniter")
			Game.visible_message(e.cell, "%s turns %s %s." % [user.display_name, e.the(), "on" if on else "off"], "warn" if on else "info")
			return true
	return false

# ------------------------------------------------------------------ items
func attackby(user: Entity, item: Entity) -> bool:
	var it: CItem = item.c(&"item")
	if it == null:
		return false
	match kind:
		"sink":
			# tg sink attackby: washing exposes it to the water (a monkey cube expands)
			if item.tags.has("monkeycube"):
				Game.visible_message(e.cell, "%s washes %s using %s." % [user.display_name, item.the(), e.the()])
				Monkeys.expose_water(item)
				return true
			var r: CReagents = item.c(&"reagents")
			if r and r.is_open():
				r.add("water", r.volume - r.total(), user)
				Sfx.play("pour", e.cell, 0.6)
				Game.tell(user, "You fill %s from %s." % [item.the(), e.the()])
				return true
			if it.tool == "mop":
				item.tags["wet"] = 10
				Game.tell(user, "You wet %s in %s." % [item.the(), e.the()])
				return true
			Game.visible_message(e.cell, "%s washes %s using %s." % [user.display_name, item.the(), e.the()])
			return true
		"shower":
			if it.tool == "wrench":
				mode = {"normal": "boiling", "boiling": "freezing", "freezing": "normal"}[mode]
				Sfx.play("ratchet", e.cell, 0.6)
				Game.visible_message(e.cell, "%s adjusts %s with %s." % [user.display_name, e.the(), item.the()])
				Game.tell(user, "The water temperature seems to be %s." % mode)
				return true
		"trash_bin", "noticeboard", "display":
			if kind == "noticeboard" and item.proto != "paper":
				return false
			var st := _storage()
			if st and st.can_insert(item):
				user.c(&"inv").remove_ref(item)
				st.insert(item)
				Game.visible_message(e.cell, "%s %s %s." % [user.display_name, "pins" if kind == "noticeboard" else "puts", "%s %s %s" % [item.the(), "to" if kind == "noticeboard" else "in", e.the()]])
				return true
			if st:
				Game.tell(user, st.refusal(item), "warn")
				return true
		"disposal":
			var st2 := _storage()
			if st2:
				user.c(&"inv").remove_ref(item)
				st2.contents.append(item)
				item.holder = e
				item.visible = false
				Game.visible_message(e.cell, "%s places %s into %s." % [user.display_name, item.the(), e.the()])
				Sfx.play("drop", e.cell, 0.6)
				return true
		"iv_drip":
			var r2: CReagents = item.c(&"reagents")
			if r2 and (r2.is_open() or r2.kind == "blood_pack"):
				var st3 := _storage()
				if not st3.contents.is_empty():
					Game.tell(user, "There's already a reagent container loaded!", "warn")
					return true
				user.c(&"inv").remove_ref(item)
				st3.insert(item)
				Game.visible_message(e.cell, "%s attaches %s to %s." % [user.display_name, item.the(), e.the()])
				return true
	return false

func verbs(user: Entity, out: Array) -> void:
	match kind:
		"disposal":
			out.append({"name": "Flush" if not flush_handle else "Disengage handle", "cb": func(): _toggle_flush(user), "priority": 6})
			out.append({"name": "Climb in", "cb": func(): _climb_in(user), "priority": 2})
			out.append({"name": "Eject contents", "cb": func(): _eject_all(), "priority": 2})
		"iv_drip":
			var near := Game.in_radius(e.cell, 1, &"health").filter(func(m): return m != user or true)
			for m in near:
				var mm: Entity = m
				if mm != patient:
					out.append({"name": "Hook up %s" % mm.display_name, "cb": func(): _hook(user, mm), "priority": 5})
			out.append({"name": "Mode: %s" % ("injecting" if injecting else "drawing"), "cb": func():
				injecting = not injecting
				Game.tell(user, "%s is now %s." % [e.the().capitalize(), "injecting" if injecting else "taking blood"]), "priority": 3})
		"shower":
			out.append({"name": "Turn %s" % ("off" if on else "on"), "cb": attack_hand.bind(user), "priority": 6})
		"jukebox":
			out.append({"name": "Stop music" if on else "Play music", "cb": attack_hand.bind(user), "priority": 6})
		"intercom":
			out.append({"name": "Microphone %s" % ("off" if on else "on"), "cb": attack_hand.bind(user), "priority": 6})
		"trash_bin":
			out.append({"name": "Empty it", "cb": func(): _eject_all(), "priority": 3})

# ------------------------------------------------------------------ per second
func tick(dt: float) -> void:
	match kind:
		"shower":
			if not on:
				return
			_tick_acc += dt
			for m in Game.at(e.cell):
				var h: CHealth = m.c(&"health")
				if h == null:
					continue
				if h.on_fire > 0:
					h.on_fire = 0.0
					Game.visible_message(e.cell, "The water puts out the flames on %s." % m.display_name, "good")
				Blood.wash(m, true)
				CMood.event(m, "shower", "shower")
				match mode:
					"normal": h.body_temp = move_toward(h.body_temp, Defs.BODYTEMP_NORMAL, 2.0 * dt)
					"boiling":
						h.body_temp = move_toward(h.body_temp, Defs.BODYTEMP_NORMAL + 30.0, 4.0 * dt)
						h.adjust("burn", 1.0 * dt)
					"freezing": h.body_temp = move_toward(h.body_temp, Defs.BODYTEMP_NORMAL - 40.0, 4.0 * dt)
			for d in Game.at_with(e.cell, &"decal"):
				if d.c(&"decal").cleanable and not d.removed:
					d.destroy()
			if _tick_acc >= 8.0:
				_tick_acc = 0.0
				Liquids.spill(e.cell, "water", 5.0)
		"disposal":
			if powered() and pressure < 100.0:
				pressure = minf(100.0, pressure + 5.0 * dt) # tg: charges in ~20 s
			if flush_handle and pressure >= 100.0 and not _storage().contents.is_empty():
				_flush()
		"iv_drip":
			if patient == null:
				return
			if not is_instance_valid(patient) or patient.removed or not patient.adjacent(e):
				if is_instance_valid(patient) and not patient.removed:
					Game.visible_message(e.cell, "The IV needle is ripped out of %s!" % patient.display_name, "bad")
					patient.take_damage(3.0, "brute", null)
				patient = null
				return
			var st := _storage()
			if st.contents.is_empty():
				return
			var r: CReagents = st.contents[0].c(&"reagents")
			if r == null:
				return
			# tg iv_drip: 5 units every couple of seconds in, or blood drawn out into the bag
			if injecting and r.total() > 0.0:
				Chem.affect_mob(r.take(2.5 * dt), patient, 1.0, r.blood_type)
			elif not injecting and r.free_space() > 0.0:
				var ph: CHealth = patient.c(&"health")
				if ph and ph.blood_volume > Body.BLOOD_VOLUME_OKAY:
					var n := minf(2.5 * dt, r.free_space())
					ph.blood_volume -= n
					r.put({"blood": n})
					r.blood_type = ph.blood_type
		"igniter":
			# tg igniter: while on, it sparks every tick and lights whatever gas is there
			var m: CMachine = e.c(&"machine")
			if m:
				m.active = on
			if on and powered() and Game.atmos:
				Fx.sparks(e.cell)
				Game.atmos.spark(e.cell)
		"intercom", "jukebox":
			pass

func _hook(user: Entity, m: Entity) -> void:
	if not m.adjacent(e):
		return
	patient = m
	Game.visible_message(e.cell, "%s attaches %s to %s." % [user.display_name, e.the(), m.display_name])

func _toggle_flush(user: Entity) -> void:
	flush_handle = not flush_handle
	Sfx.play("click", e.cell, 0.6)
	Game.visible_message(e.cell, "%s %s the handle of %s." % [user.display_name, "pulls" if flush_handle else "releases", e.the()])

func _climb_in(user: Entity) -> void:
	DoAfter.start(user, e, 2.0, func(ok):
		if ok and is_instance_valid(e) and not e.removed:
			Game.visible_message(e.cell, "%s climbs into %s." % [user.display_name, e.the()], "warn")
			user.place(e.cell)
	)

func _eject_all() -> void:
	var st := _storage()
	for it in st.contents.duplicate():
		st.contents.erase(it)
		it.holder = null
		it.visible = true
		Game.drop_to_map(it, e.cell)
		it.place(e.cell)
	Sfx.play("drop", e.cell, 0.6)

## tg disposal flush: the contents go down the pipes to the recycler; cargo gets a cut.
func _flush() -> void:
	var st := _storage()
	var credits := 0
	for it in st.contents.duplicate():
		st.contents.erase(it)
		if is_instance_valid(it) and not it.removed:
			credits += maxi(1, Cargo.value_of(it) / 2)
			it.holder = null
			it.destroy()
	for m in Game.at(e.cell).duplicate():
		if m.has_c(&"mob"):
			# people ride the pipes out to the cargo bay's disposal outlet
			var out := _outlet()
			Game.visible_message(e.cell, "%s is flushed down %s!" % [m.display_name, e.the()], "warn")
			m.place(out)
			m.take_damage(5.0, "brute", null)
	Cargo.points += credits
	pressure = 0.0
	flush_handle = false
	Sfx.play("whoosh", e.cell, 1.0)
	Game.visible_message(e.cell, "%s flushes with a whoosh." % e.the().capitalize())

func _outlet() -> Vector2i:
	for a in Game.map.areas:
		if a.room_kind == "cargo_bay" and not a.cells.is_empty():
			return a.cells[0]
	return e.cell

# ------------------------------------------------------------------ arcade
func _new_enemy() -> void:
	enemy_name = "%s %s" % [BOSS_NAME[Game.rng.randi() % BOSS_NAME.size()], BOSS_ADJ[Game.rng.randi() % BOSS_ADJ.size()]]
	enemy_hp = Game.rng.randi_range(90, 125)
	enemy_max = enemy_hp
	enemy_mp = Game.rng.randi_range(20, 30)

func arcade_act(user: Entity, act: String) -> void:
	user.set_meta("last_gamed", Game.time) # tg COMSIG_MOB_PLAYED_VIDEOGAME
	CMood.clear_event(user, "gamer_withdrawal")
	if player_hp <= 0:
		if act == "restart":
			player_hp = 100
			player_mp = 50
			wins = 0
			feedback = "A new challenger approaches!"
			_new_enemy()
		return
	var dmg := 0
	var defend := false
	var counter := false
	match act:
		"attack":
			dmg = Game.rng.randi_range(5, 15)
		"magic":
			if player_mp < 10:
				feedback = "Not enough MP!"
				return
			player_mp -= 10
			dmg = Game.rng.randi_range(15, 25)
		"counter":
			if player_mp < 10:
				feedback = "Not enough MP!"
				return
			player_mp -= 10
			counter = true
			feedback = "You prepare to counterattack!"
		"defend":
			defend = true
			player_mp = mini(50, player_mp + 10)
			player_hp = mini(100, player_hp + 5)
			feedback = "You pull up your shield!"
	if dmg > 0:
		enemy_hp -= dmg
		feedback = "%s took %d damage!" % [enemy_name, dmg]
		Sfx.play("hit", e.cell, 0.3)
	if enemy_hp <= 0:
		_arcade_win(user)
		return
	# tg perform_enemy_turn
	var chance := maxi((enemy_max - enemy_hp) / 2, 75)
	if enemy_hp != enemy_max and Game.rng.randi_range(1, 100) <= chance:
		if enemy_mp >= 10:
			var heal := Game.rng.randi_range(10, 20)
			enemy_hp = mini(enemy_max, enemy_hp + heal)
			enemy_mp -= 10
			feedback += " %s healed for %d health points!" % [enemy_name, heal]
			return
		if player_mp >= 5:
			var steal := Game.rng.randi_range(5, 10)
			player_mp = maxi(0, player_mp - steal)
			enemy_mp += steal
			feedback += " %s stole %d MP from you!" % [enemy_name, steal]
			return
	if counter and Game.rng.randi_range(1, 100) <= 45:
		var cd := Game.rng.randi_range(20, 30)
		enemy_hp -= cd
		feedback = "You counterattacked for %d damage!" % cd
		if enemy_hp <= 0:
			_arcade_win(user)
		return
	var hit := Game.rng.randi_range(5, 10) if defend else Game.rng.randi_range(15, 20)
	player_hp -= hit
	feedback += " You took %d damage!" % hit
	if player_hp <= 0:
		feedback = "You have been crushed! GAME OVER."
		Sfx.play("deny", e.cell, 0.5)
		if Quirks.has(user, "gamer"):
			# tg gamer lost_game: a heated gamer moment on the radio
			CMood.event(user, "gamer_lost", "gamer_lost")
			user.c(&"mob").say(";%s!!" % ["SHIT", "PISS", "FUCK", "CUNT", "COCKSUCKER", "MOTHERFUCKER"][Game.rng.randi() % 6])

func _arcade_win(user: Entity) -> void:
	wins += 1
	CMood.event(user, "arcade", "arcade") # tg arcade: beating the game
	if Quirks.has(user, "gamer"):
		CMood.event(user, "gamer_won", "gamer_won")
	var prize: String = ARCADE_PRIZES[Game.rng.randi() % ARCADE_PRIZES.size()]
	var it := Proto.spawn(prize, e.cell + Vector2i(0, 1))
	feedback = "%s has fallen! Rejoice! %s dispenses %s." % [enemy_name, e.the().capitalize(), it.display_name]
	Sfx.play("ding", e.cell, 0.8)
	Game.visible_message(e.cell, "%s dispenses %s!" % [e.the().capitalize(), it.display_name], "good")
	Bus.stimulus.emit({"type": "fun", "actor": user, "cell": e.cell, "loud": 1.0})
	_new_enemy()
	player_hp = mini(100, player_hp + 25)

# ------------------------------------------------------------------ misc
func examine(_user: Entity, lines: Array) -> void:
	match kind:
		"clock":
			lines.append("It reads [b]%s[/b]." % Game.clock_string())
		"shower":
			lines.append("It's %s. The water is set to %s." % ["running" if on else "off", mode])
		"disposal":
			lines.append("Pressure: %d%%.%s" % [int(pressure), " The handle is pulled." if flush_handle else ""])
		"jukebox":
			if on:
				lines.append("It's playing %s." % song)
		"noticeboard", "display", "trash_bin":
			var st := _storage()
			if st:
				var names := []
				for it in st.contents:
					names.append(it.display_name)
				lines.append(("Inside: %s." % ", ".join(names)) if not names.is_empty() else "It's empty.")
		"iv_drip":
			if patient:
				lines.append("It's hooked up to %s, %s." % [patient.display_name, "injecting" if injecting else "drawing"])
			var st2 := _storage()
			if st2 and not st2.contents.is_empty():
				lines.append("%s is attached." % st2.contents[0].display_name.capitalize())
		"intercom":
			lines.append("The microphone is %s." % ("on" if on else "off"))

func ai_tags(out: Dictionary) -> void:
	out["fixture_" + kind] = true
