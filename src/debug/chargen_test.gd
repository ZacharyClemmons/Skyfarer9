class_name ChargenTest extends Node
## --chargentest=DIR: steps through the sign-on office (skip the intro, pick an origin,
## a calling, a look, some habits, a name), signs on, and checks the shift starts with that
## character. Screenshots go to DIR. Prints CHARGEN PASS/FAIL.

var dir := ""
var fails := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var main := Game.world.get_parent()
	await _frames(10)
	var cc: CharCreator = main.creator
	_check("creator open", cc != null and is_instance_valid(cc))
	await _wait(1.2)
	await _shot("intro")
	cc._skip_intro()
	await _wait(1.6)
	await _shot("origin")
	cc.origin_btns[3].pressed.emit()
	_check("origin picked", cc.origin_i == 3)
	cc._go_step(1)
	await _frames(3)
	cc.calling_btns["navigator"].pressed.emit()
	_check("calling picked", cc.sky_class == "navigator")
	await _shot("calling")
	cc._go_step(2)
	await _frames(3)
	var hair0: String = cc.app["hair"]
	for t in cc.hair_tiles:
		if t[2] != hair0:
			t[0].pressed.emit()
			break
	_check("hair tile changes hair", cc.app["hair"] != hair0)
	await _shot("look")
	cc._go_step(3)
	await _frames(3)
	cc.quirks = ["alcohol_tolerance", "jolly", "light_drinker", "depression", "nearsighted", "bald"]
	cc._refresh()
	_check("quirk picks are balanced", Quirks.balance(Quirks.filter_valid(cc.quirks)) <= 0)
	await _shot("habits")
	cc._go_step(4)
	await _frames(3)
	cc.char_name = "Robin Test"
	cc._refresh()
	await _shot("papers")
	cc._sign_on()
	await _wait(0.6)
	await _shot("stamp")
	await _wait(2.6)
	var p := Game.player
	_check("shift started", p != null)
	if p:
		_check("with the chosen name", p.display_name == "Robin Test")
		_check("and class", String(p.tags.get("sky_class", "")) == "navigator")
	await _wait(0.5)
	await _shot("joined")
	print("CHARGEN DONE: %d failed" % fails)
	get_tree().quit(0 if fails == 0 else 1)

func _check(what: String, ok: bool) -> void:
	print("CHARGEN %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _shot(nm: String) -> void:
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/chargen_%s.png" % [dir, nm])
